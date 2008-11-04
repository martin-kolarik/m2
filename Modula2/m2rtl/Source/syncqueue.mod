IMPLEMENTATION MODULE SyncQueue;

(*================================================================================*)

FROM Debug IMPORT
   Assertion, LogAssertionW;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE, REALLOCATE, Move, Zero;
   
IMPORT
   time;

(*================================================================================*)

CLASS IMPLEMENTATION RingBuffer;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROPERTY Size GET : CARDINAL;
  BEGIN
    RETURN SUPER.Size;
  END Size;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROPERTY Size SET( Value : CARDINAL );
  BEGIN
    SUPER.Size := Value;
    DataDoubled := FALSE;
    IF Data <> NIL THEN
      REALLOCATE( Data, _Size );
    END;
  END Size;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE StartReading( WantsRead : CARDINAL; OUT BufferToReadFrom : ADDRESS; OUT AllowedToRead : CARDINAL ) : BOOLEAN;
  VAR
    Length : CARDINAL;
    Offset : CARDINAL;
  BEGIN
    IF Data = NIL THEN
      REALLOCATE( Data, _Size );
    END;
    IF StartConsuming( WantsRead, OUT Offset, OUT Length ) THEN
      BufferToReadFrom := Data@[Offset];
      AllowedToRead := Length;
      RETURN TRUE;
    ELSE
      RETURN FALSE;
    END;
  END StartReading;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE CommitReading( Read : CARDINAL );
  BEGIN
    CommitConsuming( Read );
  END CommitReading;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE StartWriting( WantsWrite : CARDINAL; OUT BufferToWriteTo : ADDRESS; OUT AllowedToWrite : CARDINAL ) : BOOLEAN;
  VAR
    Length : CARDINAL;
    Offset : CARDINAL;
  BEGIN
    IF Data = NIL THEN
      REALLOCATE( Data, _Size );
    END;
    IF StartProducing( WantsWrite, OUT Offset, OUT Length ) THEN
      BufferToWriteTo := Data@[Offset];
      AllowedToWrite := Length;
      RETURN TRUE;
    ELSE
      RETURN FALSE;
    END;
  END StartWriting;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE CommitWriting( Written : CARDINAL );
  BEGIN
    CommitProducing( Written );
  END CommitWriting;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Read( BufferToWriteTo : ADDRESS; BufferLength : CARDINAL; OUT _Read : CARDINAL ) : BOOLEAN;
  VAR
    Allowed : CARDINAL;
    QBuffer : ADDRESS;
  BEGIN
    IF NOT StartReading( BufferLength, OUT QBuffer, OUT Allowed ) THEN
      RETURN FALSE;
    END;
    Move( QBuffer, BufferToWriteTo, Allowed );
    CommitReading( Allowed );
    _Read := Allowed;
    DEC( BufferLength, Allowed );
    IF ( BufferLength > 0 ) AND StartReading( BufferLength, OUT QBuffer, OUT Allowed ) THEN
      Move( QBuffer, BufferToWriteTo@[_Read], Allowed );
      CommitReading( Allowed );
      INC( _Read, Allowed );
    END;
    RETURN TRUE;
  END Read;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Write( BufferToReadFrom : ADDRESS; BufferLength : CARDINAL; OUT _Written : CARDINAL ) : BOOLEAN;
  VAR
    Allowed : CARDINAL;
    QBuffer : ADDRESS;
  BEGIN
    IF NOT StartWriting( BufferLength, OUT QBuffer, OUT Allowed ) THEN
      RETURN FALSE;
    END;
    Move( BufferToReadFrom, QBuffer, Allowed );
    CommitWriting( Allowed );
    _Written := Allowed;
    DEC( BufferLength, Allowed );
    IF ( BufferLength > 0 ) AND StartWriting( BufferLength, OUT QBuffer, OUT Allowed ) THEN
      Move( BufferToReadFrom@[_Written], QBuffer, Allowed );
      CommitWriting( Allowed );
      INC( _Written, Allowed );
    END;
    RETURN TRUE;
  END Write;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE ReadOA( OUT Data : ARRAY OF BYTE );
  VAR
    A : ADDRESS := ADR( Data );
    Processed : CARDINAL;
    Spent : CARDINAL;
    ToProcess : CARDINAL := HIGH( Data ) + 1;
  BEGIN
    WHILE ToProcess > 0 DO
      IF Read( A, ToProcess, OUT Processed ) THEN
        INC( A, Processed );
        DEC( ToProcess, Processed );
      ELSE
        Flush( Sync.pcqConsumed, TRUE, Sync.FOREVER, OUT Spent );
      END;
    END;
  END ReadOA;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE WriteOA( CONST Data : ARRAY OF BYTE );
  VAR
    A : ADDRESS := ADR( Data );
    Processed : CARDINAL;
    Spent : CARDINAL;
    ToProcess : CARDINAL := HIGH( Data ) + 1;
  BEGIN
    WHILE ToProcess > 0 DO
      IF Write( A, ToProcess, OUT Processed ) THEN
        INC( A, Processed );
        DEC( ToProcess, Processed );
      ELSE
        Flush( Sync.pcqProduced, TRUE, Sync.FOREVER, OUT Spent );
      END;
    END;
  END WriteOA;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Peek( OUT Data : ADDRESS; OUT Length : CARDINAL ) : BOOLEAN;
  VAR
    LHead, LTail : CARDINAL;
  BEGIN
    IF SELF.Data = NIL THEN
      RETURN FALSE;
    END;
    LTail := Sync.IExchgAdd( REF _Tail, 0 );
    IF LTail = _Head THEN
      RETURN FALSE;
    END;
    LTail := ToOutIndex( LTail );
    LHead := ToOutIndex( _Head );
    IF LTail <= LHead THEN // move is necessary, buffer is splitted
      IF NOT DataDoubled THEN
        DataDoubled := TRUE;
        REALLOCATE( SELF.Data, 2*_Size );
      END;
      Move( SELF.Data, SELF.Data@[_Size], LTail );
    END;
    Data := SELF.Data@[LHead];
    IF LTail = LHead THEN
      Length := _Size;
    ELSE
      Length := ToOutIndex( LTail-LHead+_Size );
    END;
    RETURN TRUE;
  END Peek;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Peek2( OUT Data1 : ADDRESS; OUT Length1 : CARDINAL; OUT Data2 : ADDRESS; OUT Length2 : CARDINAL ) : BOOLEAN;
  VAR
    LHead, LTail : CARDINAL;
  BEGIN
    IF SELF.Data = NIL THEN
      RETURN FALSE;
    END;
    LTail := Sync.IExchgAdd( REF _Tail, 0 );
    IF LTail = _Head THEN
      RETURN FALSE;
    END;
    LTail := ToOutIndex( LTail );
    LHead := ToOutIndex( _Head );
    IF LTail > LHead THEN // return single part
      Data1 := SELF.Data@[LHead];
      Length1 := LTail - LHead;
      Data2 := NIL;
      Length2 := 0;
    ELSE // return two parts
      Data1 := SELF.Data@[LHead];
      Length1 := _Size - LHead;
      Data2 := SELF.Data;
      Length2 := LTail;
    END;
    RETURN TRUE;
  END Peek2;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE Signal( What : Sync.TpcqSignal ); // when produced, next producing SHOULD NOT be signalled (until signalling consumed)
   BEGIN
      CASE What OF
      | Sync.pcqProduced, Sync.pcqProducedFlush : Sync.SafeSignal( Consume );
      | Sync.pcqConsumed, Sync.pcqConsumedFlush : Sync.SafeSignal( Produce );
      END; // CASE
   END Signal;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE Flush( ForWhat : Sync.TpcqSignal; Wait : BOOLEAN; Timeout : CARDINAL; OUT SpentTime : CARDINAL ) : Sync.TAsyncResult;
   VAR
      Result : Sync.TAsyncResult;
      Start : CARDINAL;
   BEGIN
      SpentTime := 0;
      CASE ForWhat OF
      | Sync.pcqProduced :   
         IF Empty THEN
            RETURN Sync.arCompleted;
         END;
         Signal( Sync.pcqProducedFlush );
         IF NOT Wait THEN
            RETURN Sync.arPending;
         END;
         Start := time.UptimeMS();
         IF Produce = NIL THEN
            LOOP
               Sync.Sleep( FlushSleep );
               IF Empty THEN
                  Result := Sync.arCompleted; EXIT;
               ELSIF time.UptimeMS() - Start > Timeout THEN
                  Result := Sync.arTimeout; EXIT;
               END;
            END; // LOOP
         ELSE
            Result := Produce^.Wait( Timeout );
         END;
         SpentTime := time.UptimeMS() - Start;
      | Sync.pcqConsumed :   
         IF NOT Empty THEN // asymmetric, but it is safer than using Full (state change empty/not empty is more frequent than state empty/full
            RETURN Sync.arCompleted;
         END;
         Signal( Sync.pcqConsumedFlush );
         IF NOT Wait THEN
            RETURN Sync.arPending;
         END;
         Start := time.UptimeMS();
         IF Consume = NIL THEN
            Start := time.UptimeMS();
            LOOP
               Sync.Sleep( FlushSleep );
               IF NOT Empty THEN
                  Result := Sync.arCompleted; EXIT;
               ELSIF time.UptimeMS() - Start > Timeout THEN
                  Result := Sync.arTimeout; EXIT;
               END;
            END; // LOOP
         ELSE
            Result := Consume^.Wait( Timeout );
         END;
         SpentTime := time.UptimeMS() - Start;
      END;
      RETURN Result;
   END Flush;

(*--------------------------------------------------------------------------------*)

BEGIN
   Data := NIL;
   DataDoubled := FALSE;
FINALLY
   IF Data <> NIL THEN
     DISPOSE( Data );
   END;
END RingBuffer;

(*================================================================================*)

CLASS IMPLEMENTATION IntegerQueue;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Enqueue( I : INTEGER; Wait : BOOLEAN; Timeout : CARDINAL ) : Sync.TAsyncResult;
   VAR
      allowed : CARDINAL;
      commit : CARDINAL;
      dst : PBYTE;
      src : PBYTE := PBYTE( ADR( I ));
      len : CARDINAL := SIZE( INTEGER );
      Result : Sync.TAsyncResult;
      Spent : CARDINAL;
   BEGIN
      LOOP
         IF Count + SIZE( INTEGER ) <= Size THEN // space is sufficient
            EXIT;
         END;
         Result := Flush( Sync.pcqProduced, Wait, Timeout, OUT Spent );
         IF NOT Wait THEN
            // fall down
         ELSIF Timeout > Spent THEN
            DEC( Timeout, Spent );
         ELSE
            RETURN Sync.arTimeout;
         END;
         IF Result = Sync.arCompleted THEN
            CONTINUE;
         ELSE
            RETURN Result;
         END;
      END; // LOOP

      // first part
      IF NOT StartWriting( len, OUT dst, OUT allowed ) THEN
         ASSERTLOG( FALSE );
         RETURN Sync.arAborted;
      END;
      commit := allowed;
      WHILE allowed > 0 DO
        dst^ := src^;
        INC( dst );
        INC( src );
        DEC( allowed );
        DEC( len );
      END;
      CommitWriting( commit );
      IF len = 0 THEN
         RETURN Sync.arCompleted;
      END;

      // second part
      IF NOT StartWriting( len, OUT dst, OUT allowed ) THEN // should never occur
         ASSERTLOG( FALSE );
         RETURN Sync.arAborted;
      END;
      commit := allowed;
      WHILE allowed > 0 DO
        dst^ := src^;
        INC( dst );
        INC( src );
        DEC( allowed );
        DEC( len );
      END;
      CommitWriting( commit );
      IF len = 0 THEN
         RETURN Sync.arCompleted;
      ELSE
         ASSERTLOG( FALSE );
         RETURN Sync.arAborted;
      END;
   END Enqueue;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Dequeue( OUT I : INTEGER; Wait : BOOLEAN; Timeout : CARDINAL ) : Sync.TAsyncResult;
   VAR
      allowed : CARDINAL;
      commit : CARDINAL;
      dst : PBYTE := PBYTE( ADR( I ));
      src : PBYTE;
      len : CARDINAL := SIZE( INTEGER );
      Result : Sync.TAsyncResult;
      Spent : CARDINAL;
   BEGIN
      LOOP
         IF Count >= SIZE( INTEGER ) THEN // data is sufficient
            EXIT;
         END;   
         Result := Flush( Sync.pcqConsumed, Wait, Timeout, OUT Spent );
         IF NOT Wait THEN
            // fall down
         ELSIF Timeout > Spent THEN
            DEC( Timeout, Spent );
         ELSE
            RETURN Sync.arTimeout;
         END;
         IF Result = Sync.arPending THEN
            RETURN Sync.arNoData;
         ELSIF Result = Sync.arCompleted THEN
            CONTINUE;
         ELSE
            RETURN Result;
         END;
      END; // LOOP

      // first part
      IF NOT StartReading( len, OUT src, OUT allowed ) THEN
         ASSERTLOG( FALSE );
         RETURN Sync.arAborted;
      END;
      commit := allowed;
      WHILE allowed > 0 DO
        dst^ := src^;
        INC( dst );
        INC( src );
        DEC( allowed );
        DEC( len );
      END;
      CommitReading( commit );
      IF len = 0 THEN
         RETURN Sync.arCompleted;
      END;

      // second part
      IF NOT StartReading( len, OUT src, OUT allowed ) THEN // should never occur
         ASSERTLOG( FALSE );
         RETURN Sync.arAborted;
      END;
      commit := allowed;
      WHILE allowed > 0 DO
        dst^ := src^;
        INC( dst );
        INC( src );
        DEC( allowed );
        DEC( len );
      END;
      CommitReading( commit );
      IF len = 0 THEN
         RETURN Sync.arCompleted;
      ELSE
         ASSERTLOG( FALSE );
         RETURN Sync.arAborted;
      END;
   END Dequeue;

(*--------------------------------------------------------------------------------*)

BEGIN
   Consume := Sync.CreateSignal( Sync.stEvent, L"", FALSE );
   Produce := Sync.CreateSignal( Sync.stEvent, L"", TRUE );
FINALLY
   Sync.DeleteSignal( REF Consume );
   Sync.DeleteSignal( REF Produce );
END IntegerQueue;

(*================================================================================*)

CLASS IMPLEMENTATION QuadwordQueue;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Enqueue( CONST Q : QUADWORD; Wait : BOOLEAN; Timeout : CARDINAL ) : Sync.TAsyncResult;
   VAR
      allowed : CARDINAL;
      commit : CARDINAL;
      dst : PBYTE;
      src : PBYTE := PBYTE( ADR( Q ));
      len : CARDINAL := SIZE( QUADWORD );
      Result : Sync.TAsyncResult;
      Spent : CARDINAL;
   BEGIN
      LOOP
         IF Count + SIZE( QUADWORD ) <= Size THEN // space is sufficient
            EXIT;
         END;
         Result := Flush( Sync.pcqProduced, Wait, Timeout, OUT Spent );
         IF NOT Wait THEN
            // fall down
         ELSIF Timeout > Spent THEN
            DEC( Timeout, Spent );
         ELSE
            RETURN Sync.arTimeout;
         END;
         IF Result = Sync.arCompleted THEN
            CONTINUE;
         ELSE
            RETURN Result;
         END;
      END; // LOOP

      // first part
      IF NOT StartWriting( len, OUT dst, OUT allowed ) THEN
         ASSERTLOG( FALSE );
         RETURN Sync.arAborted;
      END;
      commit := allowed;
      WHILE allowed > 0 DO
        dst^ := src^;
        INC( dst );
        INC( src );
        DEC( allowed );
        DEC( len );
      END;
      CommitWriting( commit );
      IF len = 0 THEN
         RETURN Sync.arCompleted;
      END;

      // second part
      IF NOT StartWriting( len, OUT dst, OUT allowed ) THEN // should never occur
         ASSERTLOG( FALSE );
         RETURN Sync.arAborted;
      END;
      commit := allowed;
      WHILE allowed > 0 DO
        dst^ := src^;
        INC( dst );
        INC( src );
        DEC( allowed );
        DEC( len );
      END;
      CommitWriting( commit );
      IF len = 0 THEN
         RETURN Sync.arCompleted;
      ELSE
         ASSERTLOG( FALSE );
         RETURN Sync.arAborted;
      END;
   END Enqueue;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Dequeue( OUT Q : QUADWORD; Wait : BOOLEAN; Timeout : CARDINAL ) : Sync.TAsyncResult;
   VAR
      allowed : CARDINAL;
      commit : CARDINAL;
      dst : PBYTE := PBYTE( ADR( Q ));
      src : PBYTE;
      len : CARDINAL := SIZE( QUADWORD );
      Result : Sync.TAsyncResult;
      Spent : CARDINAL;
   BEGIN
      LOOP
         IF Count >= SIZE( QUADWORD ) THEN // data is sufficient
            EXIT;
         END;
         Result := Flush( Sync.pcqConsumed, Wait, Timeout, OUT Spent );
         IF NOT Wait THEN
            // fall down
         ELSIF Timeout > Spent THEN
            DEC( Timeout, Spent );
         ELSE
            RETURN Sync.arTimeout;
         END;
         IF Result = Sync.arPending THEN
            RETURN Sync.arNoData;
         ELSIF Result = Sync.arCompleted THEN
            CONTINUE;
         ELSE
            RETURN Result;
         END;
      END; // LOOP

      // first part
      IF NOT StartReading( len, OUT src, OUT allowed ) THEN
         ASSERTLOG( FALSE );
         RETURN Sync.arAborted;
      END;
      commit := allowed;
      WHILE allowed > 0 DO
        dst^ := src^;
        INC( dst );
        INC( src );
        DEC( allowed );
        DEC( len );
      END;
      CommitReading( commit );
      IF len = 0 THEN
         RETURN Sync.arCompleted;
      END;

      // second part
      IF NOT StartReading( len, OUT src, OUT allowed ) THEN // should never occur
         ASSERTLOG( FALSE );
         RETURN Sync.arAborted;
      END;
      commit := allowed;
      WHILE allowed > 0 DO
        dst^ := src^;
        INC( dst );
        INC( src );
        DEC( allowed );
        DEC( len );
      END;
      CommitReading( commit );
      IF len = 0 THEN
         RETURN Sync.arCompleted;
      ELSE
         ASSERTLOG( FALSE );
         RETURN Sync.arAborted;
      END;
   END Dequeue;

(*--------------------------------------------------------------------------------*)

BEGIN
   Consume := Sync.CreateSignal( Sync.stEvent, L"", FALSE );
   Produce := Sync.CreateSignal( Sync.stEvent, L"", TRUE );
FINALLY
   Sync.DeleteSignal( REF Consume );
   Sync.DeleteSignal( REF Produce );
END QuadwordQueue;

(*================================================================================*)

CLASS IMPLEMENTATION CDatagramQueue;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROPERTY Size GET : CARDINAL;
  BEGIN
    RETURN SUPER.Size;
  END Size;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROPERTY Size SET( Value : CARDINAL );
  BEGIN
    SUPER.Size := Value;
    IF ItemISize * _Size > 0 THEN
      REALLOCATE( Data, ItemISize * _Size );
      Zero( Data, ItemISize * _Size );
    END;
  END Size;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROPERTY ItemSize GET : CARDINAL;
  BEGIN
    IF ItemISize = 0 THEN
      RETURN 0;
    ELSE
      RETURN ItemISize - SIZE( CARDINAL );
    END;
  END ItemSize;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROPERTY ItemSize SET( Value : CARDINAL );
  BEGIN
    ItemISize := ( Value + SIZE( CARDINAL ) + 7 ) AND NOT 7;
    IF ItemISize * _Size > 0 THEN
      REALLOCATE( Data, ItemISize * _Size );
      Zero( Data, ItemISize * _Size );
    END;
  END ItemSize;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Init( QueueSize, MessageSize : CARDINAL );
  BEGIN
    Size := QueueSize;
    ItemSize := MessageSize;
  END Init;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Dequeue( MessageBuffer : ADDRESS; MessageBufferLen : CARDINAL; Wait : BOOLEAN; Timeout : CARDINAL ) : Sync.TAsyncResult;
   VAR
      Block : CARDINAL;
      Result : Sync.TAsyncResult;
      Spent : CARDINAL;
   BEGIN
      WHILE NOT StartConsuming( OUT Block ) DO
         Result := Flush( Sync.pcqConsumed, Wait, Timeout, OUT Spent );
         IF NOT Wait THEN
            // fall down
         ELSIF Timeout > Spent THEN
            DEC( Timeout, Spent );
         ELSE
            RETURN Sync.arTimeout;
         END;
         IF Result = Sync.arPending THEN
            RETURN Sync.arNoData;
         ELSIF Result = Sync.arCompleted THEN
            CONTINUE;
         ELSE
            RETURN Result;
         END;
      END; // WHILE

      Move( Data@[ Block*ItemISize + SIZE( CARDINAL )], MessageBuffer, MIN2( ItemISize-SIZE( CARDINAL ), MessageBufferLen ));
      CommitConsuming();

      RETURN Sync.arCompleted;
   END Dequeue;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE DequeueOA( OUT Message : ARRAY OF BYTE; Wait : BOOLEAN; Timeout : CARDINAL ) : Sync.TAsyncResult;
  BEGIN
    RETURN Dequeue( ADR( Message ), HIGH( Message )+1, Wait, Timeout );
  END DequeueOA;
  
(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Enqueue( Message : ADDRESS; MessageLen : CARDINAL; Wait : BOOLEAN; Timeout : CARDINAL ) : Sync.TAsyncResult;
   VAR
      Block : CARDINAL;
      Result : Sync.TAsyncResult;
      Spent : CARDINAL;
   BEGIN
      IF MessageLen > ItemISize - SIZE( CARDINAL ) THEN
         RETURN Sync.arAborted;
      ELSIF MessageLen = 0 THEN
         RETURN Sync.arAborted;
      END;

      WHILE NOT StartProducing( OUT Block ) DO
         Result := Flush( Sync.pcqProduced, Wait, Timeout, OUT Spent );
         IF NOT Wait THEN
            // fall down
         ELSIF Timeout > Spent THEN
            DEC( Timeout, Spent );
         ELSE
            RETURN Sync.arTimeout;
         END;
         IF Result = Sync.arCompleted THEN
            CONTINUE;
         ELSE
            RETURN Result;
         END;
      END; // WHILE
    
      Move( Message, Data@[ Block*ItemISize + SIZE( CARDINAL )], MessageLen );
      CommitProducing( Block );

      RETURN Sync.arCompleted;
   END Enqueue;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE EnqueueOA( CONST Message : ARRAY OF BYTE; Wait : BOOLEAN; Timeout : CARDINAL ) : Sync.TAsyncResult;
  BEGIN
    RETURN Enqueue( ADR( Message ), MIN2( ItemISize-SIZE( CARDINAL ), HIGH( Message )+1 ), Wait, Timeout );
  END EnqueueOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE PushToConsumer( Wait : BOOLEAN; Timeout : CARDINAL ) : Sync.TAsyncResult;
   VAR
      Spent : CARDINAL;
   BEGIN
      RETURN Flush( Sync.pcqProduced, Wait, Timeout, OUT Spent );
   END PushToConsumer;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE Validate( Block : CARDINAL );
   BEGIN
      Sync.IExchg( REF PCARD32( INC( Data, Block*ItemISize ))^, 1 );
   END Validate;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE IsValid( Block : CARDINAL ) : BOOLEAN;
   BEGIN
      RETURN Sync.IExchgAdd( REF PCARD32( INC( Data, Block*ItemISize ))^, 0 ) = 1;
   END IsValid;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE Invalidate( Block : CARDINAL );
   BEGIN
      Sync.IExchg( REF PCARD32( INC( Data, Block*ItemISize ))^, 0 );
   END Invalidate;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE Signal( What : Sync.TpcqSignal ); // when produced, next producing SHOULD NOT be signalled (until signalling consumed)
   BEGIN
      CASE What OF
      | Sync.pcqProduced, Sync.pcqProducedFlush : Sync.SafeSignal( Consume );
      | Sync.pcqConsumed, Sync.pcqConsumedFlush : Sync.SafeSignal( Produce );
      END; // CASE
   END Signal;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE Flush( ForWhat : Sync.TpcqSignal; Wait : BOOLEAN; Timeout : CARDINAL; OUT SpentTime : CARDINAL ) : Sync.TAsyncResult;
   VAR
      Result : Sync.TAsyncResult;
      Start : CARDINAL;
   BEGIN
      SpentTime := 0;
      CASE ForWhat OF
      | Sync.pcqProduced :   
         IF Empty THEN
            RETURN Sync.arCompleted;
         END;
         Signal( Sync.pcqProducedFlush );
         IF NOT Wait THEN
            RETURN Sync.arPending;
         END;
         Start := time.UptimeMS();
         IF Produce = NIL THEN
            LOOP
               Sync.Sleep( FlushSleep );
               IF Empty THEN
                  Result := Sync.arCompleted; EXIT;
               ELSIF time.UptimeMS() - Start > Timeout THEN
                  Result := Sync.arTimeout; EXIT;
               END;
            END; // LOOP
         ELSE
            Result := Produce^.Wait( Timeout );
         END;
         SpentTime := time.UptimeMS() - Start;
      | Sync.pcqConsumed :   
         IF NOT Empty THEN // asymmetric, but it is safer than using Full (state change empty/not empty is more frequent than state empty/full
            RETURN Sync.arCompleted;
         END;
         Signal( Sync.pcqConsumedFlush );
         IF NOT Wait THEN
            RETURN Sync.arPending;
         END;
         Start := time.UptimeMS();
         IF Consume = NIL THEN
            Start := time.UptimeMS();
            LOOP
               Sync.Sleep( FlushSleep );
               IF NOT Empty THEN
                  Result := Sync.arCompleted; EXIT;
               ELSIF time.UptimeMS() - Start > Timeout THEN
                  Result := Sync.arTimeout; EXIT;
               END;
            END; // LOOP
         ELSE
            Result := Consume^.Wait( Timeout );
         END;
         SpentTime := time.UptimeMS() - Start;
      END;
      RETURN Result;
   END Flush;

(*--------------------------------------------------------------------------------*)

BEGIN
   Data := NIL;
   ItemISize := 0;
FINALLY
  IF Data <> NIL THEN
    DISPOSE( Data );
  END;
END CDatagramQueue;

(*================================================================================*)

END SyncQueue.