IMPLEMENTATION MODULE Sync;

FROM Storage IMPORT
  ALLOCATE, DEALLOCATE, Zero;
  
IMPORT
   Time,
   windows;

(*================================================================================*)

PROCEDURE ResultToName( Result : TAsyncResult; OUT Name : ARRAY OF WCHAR ) : BOOLEAN;
BEGIN
   CASE Result OF
   | arUnknown :
      Name := L"!unknown";
   | arCompleted :
      Name := L"completed";
   | arPartCompleted :
      Name := L"completed partialy";
   | arNoData :
      Name := L"no data";
   | arPending :
      Name := L"pending";
   | arTimeout :
      Name := L"timeout";
   | arAborted :
      Name := L"aborted";
   | arAlreadyPending :
      Name := L"already pending (busy)";
   | arCannotStart :
      Name := L"cannot start";
   ELSE
      RETURN FALSE;
   END; // CASE
   RETURN TRUE;
END ResultToName;
  
(*================================================================================*)

CONST
   SPIN_UNLOCKED = ADDRESS( 1 );
   SPIN_LOCKED = ADDRESS( 0 );
   SPIN_SET = SPIN_LOCKED; // respect logic to allow SET/RESET work with SpinLockAcquire procedure
   SPIN_NOTSET = SPIN_UNLOCKED;

VAR
   NumOfProcessors : CARDINAL := 1;

(*--------------------------------------------------------------------------------*)

PROCEDURE Sleep( Time : CARDINAL );
BEGIN
   windows.Sleep( Time );
END Sleep;

(*--------------------------------------------------------------------------------*)

PROCEDURE SpinLockAcquire( REF Data : PTR; SpinCount : CARDINAL; Timeout : CARDINAL ) : TAsyncResult;
VAR
   StartTime : CARDINAL;
BEGIN
   // prepare logic of while
   IF NumOfProcessors = 1 THEN
      SpinCount := 0;
   END;
   IF ( Timeout <> 0 ) AND ( Timeout <> FOREVER ) THEN
      StartTime := Time.UptimeMS();
   END;

   WHILE IExchgPtr( REF Data, SPIN_LOCKED ) = SPIN_LOCKED DO
      IF NumOfProcessors = 1 THEN
         windows.Sleep( 0 );
      ELSIF SpinCount > 0 THEN
         DEC( SpinCount );
      ELSE
         windows.Sleep( 0 );
      END;
      IF ( SpinCount > 0 ) OR ( Timeout = FOREVER ) THEN
         CONTINUE;
      ELSIF Timeout = 0 THEN // only tick or spincount wait allowed
         RETURN arTimeout;
      ELSIF INTEGER( Time.UptimeMS() - StartTime ) > INTEGER( Timeout ) THEN
         RETURN arTimeout;
      ELSE
         CONTINUE;
      END;
   END; // WHILE
   
   RETURN arCompleted;
END SpinLockAcquire;

(*--------------------------------------------------------------------------------*)

PROCEDURE SpinLockLeave( REF Data : PTR );
BEGIN
   IExchgPtr( REF Data, SPIN_UNLOCKED );
END SpinLockLeave;

(*================================================================================*)

CLASS IMPLEMENTATION LOCK;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY WaitHandle GET : WAITABLE;
  BEGIN
    IF Type = ltMutex THEN
      RETURN Data;
    ELSE
      RETURN NIL;
    END;
  END WaitHandle;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Init( Type : TLockType; CONST Name : ARRAY OF WCHAR; InitiallyLocked : BOOLEAN );
  BEGIN
    Dispose();
    SELF.Type := Type;
    IF Type = ltCS THEN
      Data := NEW( windows.CRITICAL_SECTION );
      windows.InitializeCriticalSection( windows.PCRITICAL_SECTION( Data ));
    ELSIF Type = ltMutex THEN
      IF Name[0] = 0W THEN
        Data := windows.CreateMutexW( NIL, windows.BOOL( InitiallyLocked ), NIL );
      ELSE
        Data := windows.CreateMutexW( NIL, windows.BOOL( InitiallyLocked ), ADR( Name ));
      END;
    END;
    IF InitiallyLocked THEN
      Lock();
    END;
  END Init;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Lock();
  VAR
    LSpin : CARDINAL := Spin;
  BEGIN
    IF Type = ltSpin THEN
      SpinLockAcquire( REF Data, Spin, FOREVER );
    ELSIF Type = ltCS THEN
      windows.EnterCriticalSection( windows.PCRITICAL_SECTION( Data ));
    ELSIF Type = ltMutex THEN
      windows.WaitForSingleObject( Data, windows.INFINITE );
    END;
  END Lock;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Unlock();
  BEGIN
    IF Type = ltSpin THEN
      SpinLockLeave( REF Data );
    ELSIF Type = ltCS THEN
      windows.LeaveCriticalSection( windows.PCRITICAL_SECTION( Data ));
    ELSIF Type = ltMutex THEN
      windows.ReleaseMutex( Data );
    END;
  END Unlock;

(*--------------------------------------------------------------------------------*)
  
  PUBLIC PROCEDURE Get( REF Operand : LONGWORD ) : CARDINAL; // current value
  VAR
    L : CARDINAL;
  BEGIN
    IF Type = ltILock THEN
      RETURN IExchgAdd( REF Operand, 0 );
    ELSE
      Lock();
      L := Operand;
      Unlock();
      RETURN L;
    END;
  END Get;

(*--------------------------------------------------------------------------------*)
  
  PUBLIC PROCEDURE GetPtr( REF Operand : ADDRESS ) : ADDRESS; // current value
  VAR
    L : ADDRESS;
  BEGIN
    IF Type = ltILock THEN
      RETURN ICmpExchgPtr( REF Operand, NIL, NIL );
    ELSE
      Lock();
      L := Operand;
      Unlock();
      RETURN L;
    END;
  END GetPtr;

(*--------------------------------------------------------------------------------*)
  
  PUBLIC PROCEDURE Inc( REF Operand : LONGWORD; Increment : CARDINAL ) : CARDINAL; // resulting value
  VAR
    L : CARDINAL;
  BEGIN
    IF Type = ltILock THEN
      IF Increment = 1 THEN
        RETURN IInc( REF Operand );
      ELSE
        RETURN IExchgAdd( REF Operand, Increment ) + INT32( Increment );
      END;
    ELSE
      Lock();
      INC( Operand, Increment );
      L := Operand;
      Unlock();
      RETURN L;
    END;
  END Inc;
  
(*--------------------------------------------------------------------------------*)
  
  PUBLIC PROCEDURE Dec( REF Operand : LONGWORD; Decrement : CARDINAL ) : CARDINAL; // resulting value
  VAR
    L : CARDINAL;
  BEGIN
    IF Type = ltILock THEN
      IF Decrement = 1 THEN
        RETURN IDec( REF Operand );
      ELSE
        RETURN IExchgAdd( REF Operand, - Decrement ) - INT32( Decrement );
      END;
    ELSE
      Lock();
      DEC( Operand, Decrement );
      L := Operand;
      Unlock();
      RETURN L;
    END;
  END Dec;
  
(*--------------------------------------------------------------------------------*)
  
  PUBLIC PROCEDURE Exchg( REF Operand : LONGWORD; Value : LONGWORD ) : CARDINAL; // previous value
  VAR
    L : CARDINAL;
  BEGIN
    IF Type = ltILock THEN
      RETURN IExchg( REF Operand, Value );
    ELSE
      Lock();
      L := Operand;
      Operand := Value;
      Unlock();
      RETURN L;
    END;
  END Exchg;
  
(*--------------------------------------------------------------------------------*)
  
  PUBLIC PROCEDURE ExchgPtr( REF Operand : ADDRESS; Value : ADDRESS ) : ADDRESS; // previous value
  VAR
    L : ADDRESS;
  BEGIN
    IF Type = ltILock THEN
      RETURN IExchgPtr( REF Operand, Value );
    ELSE
      Lock();
      L := Operand;
      Operand := Value;
      Unlock();
      RETURN L;
    END;
  END ExchgPtr;
  
(*--------------------------------------------------------------------------------*)
  
  PUBLIC PROCEDURE ExchgAdd( REF Operand : LONGWORD; Addition : INTEGER ) : CARDINAL; // previous value
  VAR
    L : CARDINAL;
  BEGIN
    IF Type = ltILock THEN
      RETURN IExchgAdd( REF Operand, Addition );
    ELSE
      Lock();
      L := Operand;
      INC( Operand, Addition );
      Unlock();
      RETURN L;
    END;
  END ExchgAdd;
  
(*--------------------------------------------------------------------------------*)
  
  PUBLIC PROCEDURE CmpExchg( REF Operand : LONGWORD; Value : LONGWORD; Comparand : LONGWORD ) : CARDINAL; // previous value
  VAR
    L : CARDINAL;
  BEGIN
    IF Type = ltILock THEN
      RETURN ICmpExchg( REF Operand, Value, Comparand );
    ELSE
      Lock();
      L := Operand;
      IF Operand = Comparand THEN
        Operand := Value;
      END;
      Unlock();
      RETURN L;
    END;
  END CmpExchg;
  
(*--------------------------------------------------------------------------------*)
  
  PUBLIC PROCEDURE CmpExchgPtr( REF Operand : ADDRESS; Value : ADDRESS; Comparand : ADDRESS ) : ADDRESS; // previous value
  VAR
    L : ADDRESS;
  BEGIN
    IF Type = ltILock THEN
      RETURN ICmpExchgPtr( REF Operand, Value, Comparand );
    ELSE
      Lock();
      L := Operand;
      IF Operand = Comparand THEN
        Operand := Value;
      END;
      Unlock();
      RETURN L;
    END;
  END CmpExchgPtr;
  
(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Incl( REF Operand : LONGWORD; IncludedBit : LONGWORD ) : BITSET32; // previous value
   VAR
      L : BITSET32;
   BEGIN
      IF Type = ltILock THEN
         ASSERT( FALSE );
         RETURN {};
      ELSE
         Lock();
         L := Operand;
         Operand := Operand OR ( 1 << IncludedBit );
         Unlock();
         RETURN L;
      END;
   END Incl;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Excl( REF Operand : LONGWORD; ExcludedBit : LONGWORD ) : BITSET32; // previous value
   VAR
      L : BITSET32;
   BEGIN
      IF Type = ltILock THEN
         ASSERT( FALSE );
         RETURN {};
      ELSE
         Lock();
         L := Operand;
         Operand := Operand AND NOT( 1 << ExcludedBit );
         Unlock();
         RETURN L;
      END;
   END Excl;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE InclExcl( REF Operand : LONGWORD; IncludedSet, ExcludedSet : BITSET32 ) : BITSET32; // previous value
   VAR
      L : BITSET32;
   BEGIN
      IF Type = ltILock THEN
         ASSERT( FALSE );
         RETURN {};
      ELSE
         Lock();
         L := Operand;
         Operand := Operand AND NOT LONGWORD( ExcludedSet ) OR LONGWORD( IncludedSet );
         Unlock();
         RETURN L;
      END;
   END InclExcl;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE In( REF Operand : LONGWORD; TestBit : LONGWORD ) : BOOLEAN;
   VAR
      L : BOOLEAN;
   BEGIN
      IF Type = ltILock THEN
         ASSERT( FALSE );
         RETURN FALSE;
      ELSE
         Lock();
         L := Operand AND ( 1 << TestBit ) <> 0;
         Unlock();
         RETURN L;
      END;
   END In;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE InSet( REF Operand : LONGWORD; TestSet : BITSET32 ) : BOOLEAN;
   VAR
      L : BOOLEAN;
   BEGIN
      IF Type = ltILock THEN
         ASSERT( FALSE );
         RETURN FALSE;
      ELSE
         Lock();
         L := Operand AND LONGWORD( TestSet ) = LONGWORD( TestSet );
         Unlock();
         RETURN L;
      END;
   END InSet;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE NotInSet( REF Operand : LONGWORD; TestSet : BITSET32 ) : BOOLEAN;
   VAR
      L : BOOLEAN;
   BEGIN
      IF Type = ltILock THEN
         ASSERT( FALSE );
         RETURN FALSE;
      ELSE
         Lock();
         L := Operand AND LONGWORD( TestSet ) = 0;
         Unlock();
         RETURN L;
      END;
   END NotInSet;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE AndCmp( REF Operand : LONGWORD; AndSet, CmpSet : BITSET32 ) : BOOLEAN;
   VAR
      L : BOOLEAN;
   BEGIN
      IF Type = ltILock THEN
         ASSERT( FALSE );
         RETURN FALSE;
      ELSE
         Lock();
         L := Operand AND LONGWORD( AndSet ) = LONGWORD( CmpSet );
         Unlock();
         RETURN L;
      END;
   END AndCmp;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Dispose();
   BEGIN
      Unlock();
      IF Type = ltSpin THEN
         // do nothing
      ELSIF Data = 0 THEN
         // already clear
      ELSIF Type = ltCS THEN
         windows.DeleteCriticalSection( windows.PCRITICAL_SECTION( Data ));
         DISPOSE( Data );
      ELSIF Type = ltMutex THEN
         windows.CloseHandle( Data );
         Data := 0;
      END;
   END Dispose;
  
(*--------------------------------------------------------------------------------*)

BEGIN
   Spin := 256;
   Data := SPIN_UNLOCKED;
FINALLY
   Dispose();
END LOCK;

(*--------------------------------------------------------------------------------*)

PROCEDURE ICmpExchg( REF Destination : INT32; Exchange : INT32; Comperand : INT32 ) : INT32;
BEGIN
   RETURN windows.InterlockedCompareExchange( REF Destination, Exchange, Comperand );
END ICmpExchg;

(*--------------------------------------------------------------------------------*)

PROCEDURE ICmpExchgPtr( REF Destination : ADDRESS; Exchange : ADDRESS; Comperand : ADDRESS ) : ADDRESS;
BEGIN
   RETURN windows.InterlockedCompareExchangePointer( REF Destination, Exchange, Comperand );
END ICmpExchgPtr;

(*--------------------------------------------------------------------------------*)

PROCEDURE IDec( REF Addend : INT32 ) : INT32;
BEGIN
   RETURN windows.InterlockedDecrement( REF Addend );
END IDec;

(*--------------------------------------------------------------------------------*)

PROCEDURE IExchg( REF Target : INT32; Value : INT32 ) : INT32;
BEGIN
   RETURN windows.InterlockedExchange( REF Target, Value );
END IExchg;

(*--------------------------------------------------------------------------------*)

PROCEDURE IExchgAdd( REF Addend : INT32; Value : INT32 ) : INT32;
BEGIN
   RETURN windows.InterlockedExchangeAdd( REF Addend, Value );
END IExchgAdd;

(*--------------------------------------------------------------------------------*)
  
PROCEDURE IExchgPtr( REF Destination : ADDRESS; Value : ADDRESS ) : ADDRESS;
BEGIN
   RETURN windows.InterlockedExchangePointer( REF Destination, Value );
END IExchgPtr;

(*--------------------------------------------------------------------------------*)
  
PROCEDURE IInc( REF Addend : INT32 ): INT32;
BEGIN
   RETURN windows.InterlockedIncrement( REF Addend );
END IInc;

(*--------------------------------------------------------------------------------*)
  
PROCEDURE IGet( REF Value : INT32 ) : INT32;
BEGIN
  RETURN IExchgAdd( REF Value, 0 );
END IGet;

(*--------------------------------------------------------------------------------*)
  
PROCEDURE IGetPtr( REF Value : ADDRESS ) : ADDRESS;
BEGIN
  RETURN ICmpExchgPtr( REF Value, NIL, NIL );
END IGetPtr;

(*================================================================================*)
// signalling

PROCEDURE RawCreateSignal( InitiallySignalled : BOOLEAN; CONST Name : ARRAY OF WCHAR ) : RAWSIGNAL;
VAR
   Signal : RAWSIGNAL;
BEGIN
  IF Name[0] = 0W THEN
    Signal := windows.CreateEventW( NIL, windows.True, windows.BOOL( InitiallySignalled ), NIL );
  ELSE
    Signal := windows.CreateEventW( NIL, windows.True, windows.BOOL( InitiallySignalled ), ADR( Name ));
  END;
  LeakALLOCATE( Signal, 1 );
  RETURN Signal;
END RawCreateSignal;

PROCEDURE RawCreateAutoresetSignal( InitiallySignalled : BOOLEAN; CONST Name : ARRAY OF WCHAR ) : RAWSIGNAL;
VAR
   Signal : RAWSIGNAL;
BEGIN
  IF Name[0] = 0W THEN
    Signal := windows.CreateEventW( NIL, windows.False, windows.BOOL( InitiallySignalled ), NIL );
  ELSE
    Signal := windows.CreateEventW( NIL, windows.False, windows.BOOL( InitiallySignalled ), ADR( Name ));
  END;
  LeakALLOCATE( Signal, 1 );
  RETURN Signal;
END RawCreateAutoresetSignal;

PROCEDURE RawDeleteSignal( REF S : RAWSIGNAL );
BEGIN
  IF S <> NIL THEN
    LeakDEALLOCATE( S );
    windows.CloseHandle( S );
    S := NIL;
  END;
END RawDeleteSignal;

PROCEDURE RawSignal( S : RAWSIGNAL );
BEGIN
  IF S = NIL THEN
    RETURN;
  END;
  windows.SetEvent( S );
END RawSignal;

PROCEDURE RawSignalAndReset( S : RAWSIGNAL );
BEGIN
  IF S = NIL THEN
    RETURN;
  END;
  windows.PulseEvent( S );
END RawSignalAndReset;

PROCEDURE RawReset( S : RAWSIGNAL );
BEGIN
  IF S = NIL THEN
    RETURN;
  END;
  windows.ResetEvent( S );
END RawReset;

(*================================================================================*)
// waiting

PROCEDURE RawWait( W : WAITABLE; Timeout : CARDINAL ) : TAsyncResult;
BEGIN
  IF W = NIL THEN
    RETURN arCannotStart;
  END;
  CASE CARDINAL( windows.WaitForSingleObject( W, Timeout )) OF
  | windows.WAIT_OBJECT_0 :
    RETURN arCompleted;
  | windows.WAIT_TIMEOUT :
    RETURN arTimeout;
  ELSE
    RETURN arAborted;
  END;
END RawWait;

PROCEDURE RawState( W : WAITABLE ) : BOOLEAN; // TRUE = Signalled, FALSE = Nonsignalled
BEGIN
  RETURN windows.WaitForSingleObject( W, 0 ) <> windows.WAIT_TIMEOUT;
END RawState;

(*================================================================================*)
// atomic signalling

CLASS IMPLEMENTATION SIGNAL;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY State GET : BOOLEAN;
   BEGIN
      IF Type = stSpin THEN
         RETURN IGetPtr( REF Data ) = ADDRESS( 1 );
      ELSE
         RETURN RawState( Data );
      END;
   END State;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY State SET( Value : BOOLEAN );
   BEGIN
      IF Type = stSpin THEN
         IF Value THEN
            IExchgPtr( REF Data, SPIN_SET );
         ELSE
            IExchgPtr( REF Data, SPIN_NOTSET );
         END;
      ELSE
         IF Value THEN
            RawSignal( Data );
         ELSE
            RawReset( Data );
         END;
      END;
   END State;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY WaitHandle GET : WAITABLE;
  BEGIN
    IF Type = stSpin THEN
      RETURN NIL;
    ELSE
      RETURN Data;
    END;
  END WaitHandle;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( Type : TStateType; CONST Name : ARRAY OF WCHAR; InitiallySignaled : BOOLEAN );
   BEGIN
     Dispose();
     SELF.Type := Type;
     IF Type = stSpin THEN
       Lock.Init( ltSpin, L"", FALSE );
     ELSE
       Lock.Init( ltCS, L"", FALSE );
     END;
     IF Type = stSetReset THEN
       Data := RawCreateSignal( InitiallySignaled, Name );
     ELSIF Type = stAutoReset THEN
       Data := RawCreateAutoresetSignal( InitiallySignaled, Name );
     END;
   END Init;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE InitForeign( EventHandle : WAITABLE; InitiallySignalled : BOOLEAN ); // EventHandle will not be closed
   BEGIN
      Dispose();
      Type := stForeign;
      Data := EventHandle;
      IF InitiallySignalled THEN
         Signal();
      ELSE
         Reset();
      END;
   END InitForeign;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Signal() : BOOLEAN;
   VAR
      b : BOOLEAN;
   BEGIN
      IF Type = stSpin THEN
         RETURN IExchgPtr( REF Data, SPIN_SET ) = SPIN_NOTSET;
      ELSE
         Lock.Lock();
         b := RawState( Data );
         RawSignal( Data );
         Lock.Unlock();
         RETURN NOT b;
      END;
   END Signal;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SignalAndReset();
   BEGIN
      IF Type = stSpin THEN
         Lock.Lock();
         IExchgPtr( REF Data, SPIN_SET );
         IExchgPtr( REF Data, SPIN_NOTSET );
         Lock.Unlock();
      ELSE
         // Lock.Lock(); -- for atomic os SignalAndReset there is no need to lock
         RawSignalAndReset( Data );
         // Lock.Unlock();
      END;
   END SignalAndReset;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Reset() : BOOLEAN;
   VAR
      b : BOOLEAN;
   BEGIN
      IF Type = stSpin THEN
         RETURN IExchgPtr( REF Data, SPIN_NOTSET ) = SPIN_SET;
      ELSE
         Lock.Lock();
         b := RawState( Data );
         RawReset( Data );
         Lock.Unlock();
         RETURN b;
      END;
   END Reset;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Test() : BOOLEAN;
   BEGIN
      RETURN State;
   END Test;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Wait( Timeout : CARDINAL ) : TAsyncResult;
  BEGIN
    IF Type = stSpin THEN
      RETURN SpinLockAcquire( REF Data, Spin, Timeout );
    ELSE
      RETURN RawWait( Data, Timeout );
    END;
  END Wait;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Dispose();
   BEGIN
      Signal();
      IF Type = stSpin THEN
         // do nothing
      ELSIF Data = 0 THEN
         // already clear
      ELSIF Type = stForeign THEN
         Data := 0;
      ELSE
         RawDeleteSignal( REF Data );
      END;
   END Dispose;
  
(*--------------------------------------------------------------------------------*)

BEGIN
   Data := SPIN_NOTSET;
   Spin := 256;
FINALLY
   Dispose();
END SIGNAL;

(*================================================================================*)

PROCEDURE ToPowerOf2( Size : CARDINAL ) : CARDINAL;
TYPE
   TPower = ARRAY [0..32] OF CARDINAL;
CONST
   power = TPower(
      1, 2, 4, 8, 16, 32, 64, 128,
      256, 512, 1024, 2048, 4096, 8192, 16384, 32768,
      65536, 2*65536, 4*65536, 8*65536, 16*65536, 32*65536, 64*65536, 128*65536,
      256*65536, 512*65536, 1024*65536, 2048*65536, 4096*65536, 8192*65536, 16384*65536, 32768*65536,
      0
   );
VAR
   i : CARDINAL := 0;
BEGIN
   WHILE Size > power[i] DO
      INC( i );
   END;
   ASSERT( i < 32 );
   RETURN power[i];
END ToPowerOf2;

(*================================================================================*)

CLASS IMPLEMENTATION OneToOneQueue;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY OneToOneQueue.Count GET : CARDINAL;
  VAR
    LHead : CARDINAL;
    LTail : CARDINAL;
  BEGIN
    // order is significant, first LTail
    LTail := IExchgAdd( REF _Tail, 0 );
    LHead := IExchgAdd( REF _Head, 0 );
    RETURN LTail-LHead;
  END OneToOneQueue.Count;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY OneToOneQueue.Empty GET : BOOLEAN;
  BEGIN
    RETURN Count = 0;
  END OneToOneQueue.Empty;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY OneToOneQueue.Full GET : BOOLEAN;
  BEGIN
    RETURN Count = _Size;
  END OneToOneQueue.Full;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROPERTY OneToOneQueue.Size GET : CARDINAL;
  BEGIN
    RETURN _Size;
  END OneToOneQueue.Size;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROPERTY OneToOneQueue.Size SET( Value : CARDINAL );
  BEGIN
    _Size := ToPowerOf2( Value );
    _Head := 0;
    _Tail := 0;
  END OneToOneQueue.Size;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Clear();
  BEGIN
    CommitConsuming( Count );
  END Clear;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE StartProducing( LengthToProduce : CARDINAL; OUT ProduceTo : CARDINAL; OUT AllowedToProduce : CARDINAL ) : BOOLEAN;
   VAR
      LHead, Space : CARDINAL;
   BEGIN
      // Space = H + S - T
      LHead := IExchgAdd( REF _Head, 0 );
      // compute space as minimum from inbound and outboud pieces -- only these assures the area will be continuous
      Space := MIN2( LHead + _Size - _Tail, _Size - ToOutIndex( _Tail ));
      IF Space = 0 THEN
         RETURN FALSE;
      END;

      AllowedToProduce := MIN2( LengthToProduce, Space );
      ProduceTo := ToOutIndex( _Tail );
      RETURN TRUE;
   END StartProducing;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE CommitProducing( Produced : CARDINAL );
  VAR
    LHead, LSpace : CARDINAL;
  BEGIN
    // Space = H + S - T;
    LHead := IExchgAdd( REF _Head, 0 );
    LSpace := LHead + _Size - _Tail;
    ASSERT( Produced <= LSpace );
    IExchgAdd( REF _Tail, Produced );

    IF LSpace = _Size THEN // if queue becomes being occupied, signalize
      Signal( pcqProduced );
    END;
  END CommitProducing;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE StartConsuming( LengthToConsume : CARDINAL; OUT ConsumeFrom : CARDINAL; OUT AllowedToConsume : CARDINAL ) : BOOLEAN;
  VAR
    LTail, Occupied : CARDINAL;
  BEGIN
    // order is significant, first *cache LTail
    LTail := IExchgAdd( REF _Tail, 0 );
    // compute occupation as minimum from inbound and outboud pieces -- only these assures the area will be continuous
    Occupied := MIN2( LTail - _Head, _Size - ToOutIndex( _Head ));
    // continue consumation with *cached data
    IF Occupied > 0 THEN
      AllowedToConsume := MIN2( Occupied, LengthToConsume );
      ConsumeFrom := ToOutIndex( _Head );
      RETURN TRUE;
    ELSE
      RETURN FALSE;
    END;
  END StartConsuming;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE CommitConsuming( Consumed : CARDINAL );
  VAR
    LCount, LTail : CARDINAL;
  BEGIN
    // order is significant, first LTail
    LTail := IExchgAdd( REF _Tail, 0 );
    LCount := LTail - _Head;
    ASSERT( Consumed <= LCount );
    IExchgAdd( REF _Head, Consumed );
    
    IF Consumed = LCount THEN // if queue becomes being empty, signalize
      Signal( pcqConsumed );
    END;
  END CommitConsuming;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE Signal( What : TpcqSignal ); // when produced, next producing SHOULD NOT be done (until signalling consumed)
  BEGIN
  END Signal;

(*--------------------------------------------------------------------------------*)

  INTERNAL INLINE PROCEDURE ToOutIndex( Index : CARDINAL ) : CARDINAL;
  BEGIN
    RETURN Index AND ( _Size - 1 );
  END ToOutIndex;

(*--------------------------------------------------------------------------------*)

BEGIN
  _Head := 0;
  _Tail := 0;
END OneToOneQueue;

(*================================================================================*)

CLASS IMPLEMENTATION WriteBuffer;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY WriteBuffer.Count GET : CARDINAL;
   VAR
      count : CARDINAL; 
   BEGIN
      _Lock.Lock();
      count := _Tail - _Head;
      _Lock.Unlock();
      RETURN count;
   END WriteBuffer.Count;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY WriteBuffer.Empty GET : BOOLEAN;
   BEGIN
      RETURN Count = 0;
   END WriteBuffer.Empty;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY WriteBuffer.Full GET : BOOLEAN;
   BEGIN
      RETURN Count = _Size;
   END WriteBuffer.Full;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY WriteBuffer.Size GET : CARDINAL;
   BEGIN
      RETURN _Size;
   END WriteBuffer.Size;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY WriteBuffer.Size SET( Value : CARDINAL );
   BEGIN
      _Size := ToPowerOf2( Value );
      _Head := 0;
      _Tail := 0;
   END WriteBuffer.Size;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Clear();
   BEGIN
      _Lock.Lock(); // can be called every time from any client
      _Head := 0;
      _Tail := 0;
      _Lock.Unlock();
   END Clear;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE StartProducing( Overwrite : BOOLEAN; OUT ProduceTo : CARDINAL ) : BOOLEAN;
   BEGIN
      _Lock.Lock();
      IF _Head + _Size = _Tail THEN
         IF Overwrite THEN
            INC( _Head );
         ELSE
            // leave lock
            _Lock.Unlock();
            RETURN FALSE;
         END;
      END;
      INC( _Tail );
      ProduceTo := ToOutIndex( _Tail );
      // stay in lock
      RETURN TRUE;
   END StartProducing;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CommitProducing();
   BEGIN
      // release lock
      _Lock.Unlock();   
   END CommitProducing;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE StartReading( Index : CARDINAL; OUT ReadFrom : CARDINAL ) : BOOLEAN;
   VAR
      readFrom : CARDINAL;
   BEGIN
      _Lock.Lock();
      readFrom := _Head + Index;
      IF INTEGER( readFrom - _Tail ) > 0 THEN
         _Lock.Unlock();
         RETURN FALSE;
      END;
      ReadFrom := ToOutIndex( readFrom );
      // stay in lock
      RETURN TRUE;
   END StartReading;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CommitReading();
   BEGIN
      // release lock
      _Lock.Unlock();
   END CommitReading;

(*--------------------------------------------------------------------------------*)

   INTERNAL INLINE PROCEDURE ToOutIndex( Index : CARDINAL ) : CARDINAL;
   BEGIN
     RETURN Index AND ( _Size - 1 );
   END ToOutIndex;

(*--------------------------------------------------------------------------------*)

BEGIN
   _Head := 0;
   _Tail := 0;
END WriteBuffer;

(*================================================================================*)

CLASS IMPLEMENTATION NToOneQueue;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY NToOneQueue.Count GET : CARDINAL;
  VAR
    LHead : CARDINAL;
    LTail : CARDINAL;
  BEGIN
    // order is significant, first LTail
    LTail := IExchgAdd( REF _Tail, 0 );
    LHead := IExchgAdd( REF _Head, 0 );
    RETURN LTail-LHead;
  END NToOneQueue.Count;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY NToOneQueue.Empty GET : BOOLEAN;
  BEGIN
    RETURN Count = 0;
  END NToOneQueue.Empty;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY NToOneQueue.Full GET : BOOLEAN;
  BEGIN
    RETURN Count = _Size;
  END NToOneQueue.Full;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROPERTY NToOneQueue.Size GET : CARDINAL;
  BEGIN
    RETURN _Size;
  END NToOneQueue.Size;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROPERTY NToOneQueue.Size SET( Value : CARDINAL );
  BEGIN
    _Size := ToPowerOf2( Value );
    _Head := 0;
    _Tail := 0;
  END NToOneQueue.Size;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Clear();
  VAR
    LHead, LTail : CARDINAL;
  BEGIN
    // get current indexes, Tail first
    LTail := IExchgAdd( REF _Tail, 0 );
    LHead := IExchgAdd( REF _Head, 0 );
    WHILE LHead < LTail DO
      Invalidate( ToOutIndex( LHead ));
      LHead := IExchgAdd( REF _Head, 1 );
    END;
    Signal( pcqConsumed );
  END Clear;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE StartProducing( OUT ProduceTo : CARDINAL ) : BOOLEAN;
   VAR
      LHead, LTail : CARDINAL;
      Spin : CARDINAL := 10;
   BEGIN
      // lock threads between self
      WHILE IExchg( REF _Lock, 1 ) = 1 DO
         IF Spin > 0 THEN
            DEC( Spin );
         ELSE
            RETURN FALSE;
         END;
      END; // WHILE
      // Space = H + L - T;
      LTail := IExchgAdd( REF _Tail, 1 ); // allocate speculatively
      LHead := IExchgAdd( REF _Head, 0 );
      IF INTEGER( LHead + _Size - LTail ) > 0 THEN // space found, allocated
         ProduceTo := ToOutIndex( LTail );
         IExchg( REF _Lock, 0 );
         RETURN TRUE;
      ELSE // space not found, revert speculative allocation
         IDec( REF _Tail );
         IExchg( REF _Lock, 0 );
         RETURN FALSE;
      END;
   END StartProducing;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CommitProducing( Produced : CARDINAL ); // Produced is get from StartProducing
   VAR
      LHead : CARDINAL;
   BEGIN
      ASSERT( Produced < _Size );   
      Validate( Produced );

      LHead := IExchgAdd( REF _Head, 0 );
      IF Produced - ToOutIndex( LHead ) = 0 THEN // now first item into empty queue was added, signal production
         Signal( pcqProduced );
      END;
   END CommitProducing;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE StartConsuming( OUT ConsumeFrom : CARDINAL ) : BOOLEAN;
   VAR
      LHead, LTail : CARDINAL;
   BEGIN
      // get current indexes, Tail first
      LTail := IExchgAdd( REF _Tail, 0 );
      LHead := IExchgAdd( REF _Head, 0 );
      // continue with snapshoted data
      IF LHead = LTail THEN
         RETURN FALSE;
      ELSIF IsValid( ToOutIndex( LHead )) THEN // OK, slot is occupied
         ConsumeFrom := ToOutIndex( LHead );
         RETURN TRUE;
      ELSE // slot is not marked as occupied yet
         RETURN FALSE;
       END;
   END StartConsuming;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CommitConsuming();
   VAR
      LTail : CARDINAL;
   BEGIN
      Invalidate( ToOutIndex( _Head ));
      IInc( REF _Head );
    
      LTail := IExchgAdd( REF _Tail, 0 );
      IF LTail = _Head THEN // if queue becomes empty, signalize
         Signal( pcqConsumed );
      END;
   END CommitConsuming;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE Signal( What : TpcqSignal );
   BEGIN
   END Signal;

(*--------------------------------------------------------------------------------*)

   INTERNAL INLINE PROCEDURE ToOutIndex( Index : CARDINAL ) : CARDINAL;
   BEGIN
     RETURN Index AND ( _Size - 1 );
   END ToOutIndex;

(*--------------------------------------------------------------------------------*)

BEGIN
  _Head := 0;
  _Tail := 0;
  _Lock := 0;
END NToOneQueue;

(*================================================================================*)

INITIALLY Sync;
VAR
	si : windows.SYSTEM_INFO;
BEGIN
	Zero( ADR( si ), SIZE( si ));
	windows.GetSystemInfo( ADR( si ));
	NumOfProcessors := MAX2( 1, si.dwNumberOfProcessors ); // do not to decrease to zero, even if erroneous count is returned
END Sync;

(*--------------------------------------------------------------------------------*)

END Sync.
