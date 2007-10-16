IMPLEMENTATION MODULE SyncQueue;

(*================================================================================*)

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE, REALLOCATE, Move;

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
    ToProcess : CARDINAL := HIGH( Data ) + 1;
  BEGIN
    WHILE ToProcess > 0 DO
      IF Read( A, ToProcess, OUT Processed ) THEN
        INC( A, Processed );
        DEC( ToProcess, Processed );
      ELSE
        Sync.Sleep( 0 );
      END;
    END;
  END ReadOA;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE WriteOA( CONST Data : ARRAY OF BYTE );
  VAR
    A : ADDRESS := ADR( Data );
    Processed : CARDINAL;
    ToProcess : CARDINAL := HIGH( Data ) + 1;
  BEGIN
    WHILE ToProcess > 0 DO
      IF Write( A, ToProcess, OUT Processed ) THEN
        INC( A, Processed );
        DEC( ToProcess, Processed );
      // Sleep is not needed here as Flush should be implemented
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
    LTail := LTail MOD _Size;
    LHead := _Head MOD _Size;
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
      Length := ( LTail-LHead+_Size ) MOD _Size;
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
    LTail := LTail MOD _Size;
    LHead := _Head MOD _Size;
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

   INTERNAL VIRTUAL PROCEDURE Flush() : Sync.TAsyncResult;
   BEGIN
      IF Empty THEN
         RETURN Sync.arCompleted;
      ELSIF Consume = NIL THEN
         RETURN Sync.arAborted;
      ELSE
         Sync.Signal( Consume );
         Sync.Sleep( 0 );
      END;
      IF Produce <> NIL THEN
         Sync.Wait( Produce, Sync.INFINITE_TIME );
      END;
      RETURN Sync.arCompleted;
   END Flush;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE Signal( What : Sync.TpcqSignal ); // when produced, next producing SHOULD NOT be signalled (until signalling consumed)
  BEGIN
    CASE What OF
    | Sync.pcqProduced :
      Sync.SignalAndReset( Consume );
    | Sync.pcqConsumed :
      Sync.SignalAndReset( Produce );
    END; // CASE
  END Signal;

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

   PUBLIC PROCEDURE Queue( I : INTEGER; Wait : BOOLEAN; Timeout : CARDINAL ) : BOOLEAN;
   VAR
      allowed : CARDINAL;
      commit : CARDINAL;
      dst : PBYTE;
      src : PBYTE := PBYTE( ADR( I ));
      len : CARDINAL := SIZE( INTEGER );
   BEGIN
      LOOP
         IF Count + SIZE( INTEGER ) <= Size THEN // space is sufficient
            EXIT;
         ELSIF NOT Wait OR ( Sync.Wait( Produce, Timeout ) <> Sync.arCompleted ) THEN
            RETURN FALSE;
         END;
      END; // LOOP

      // first part
      IF NOT StartWriting( len, OUT dst, OUT allowed ) THEN
         ASSERT( FALSE );
         RETURN FALSE;
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
         RETURN TRUE;
      END;

      // second part
      IF NOT StartWriting( len, OUT dst, OUT allowed ) THEN // should never occur
         ASSERT( FALSE );
         RETURN FALSE;
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
         RETURN TRUE;
      ELSE
         ASSERT( FALSE );
         RETURN FALSE;
      END;
   END Queue;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Dequeue( OUT I : INTEGER; Wait : BOOLEAN; Timeout : CARDINAL ) : BOOLEAN;
   VAR
      allowed : CARDINAL;
      commit : CARDINAL;
      dst : PBYTE := PBYTE( ADR( I ));
      src : PBYTE;
      len : CARDINAL := SIZE( INTEGER );
   BEGIN
      LOOP
         IF Count >= SIZE( INTEGER ) THEN // data is sufficient
            EXIT;
         ELSIF NOT Wait OR ( Sync.Wait( Consume, Timeout ) <> Sync.arCompleted ) THEN
            RETURN FALSE;
         END;
      END; // LOOP

      // first part
      IF NOT StartReading( len, OUT src, OUT allowed ) THEN
         ASSERT( FALSE );
         RETURN FALSE;
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
         RETURN TRUE;
      END;

      // second part
      IF NOT StartReading( len, OUT src, OUT allowed ) THEN // should never occur
         ASSERT( FALSE );
         RETURN FALSE;
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
         RETURN TRUE;
      ELSE
         ASSERT( FALSE );
         RETURN FALSE;
      END;
   END Dequeue;

(*--------------------------------------------------------------------------------*)

BEGIN
   Consume := Sync.CreateSignal( FALSE, L"" );
   Produce := Sync.CreateSignal( TRUE, L"" );
FINALLY
   Sync.DeleteSignal( REF Consume );
   Sync.DeleteSignal( REF Produce );
END IntegerQueue;

(*================================================================================*)

CLASS IMPLEMENTATION QuadwordQueue;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Queue( CONST Q : QUADWORD; Wait : BOOLEAN; Timeout : CARDINAL ) : BOOLEAN;
   VAR
      allowed : CARDINAL;
      commit : CARDINAL;
      dst : PBYTE;
      src : PBYTE := PBYTE( ADR( Q ));
      len : CARDINAL := SIZE( QUADWORD );
   BEGIN
      LOOP
         IF Count + SIZE( QUADWORD ) <= Size THEN // space is sufficient
            EXIT;
         ELSIF NOT Wait OR ( Sync.Wait( Produce, Timeout ) <> Sync.arCompleted ) THEN
            RETURN FALSE;
         END;
      END; // LOOP

      // first part
      IF NOT StartWriting( len, OUT dst, OUT allowed ) THEN
         ASSERT( FALSE );
         RETURN FALSE;
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
         RETURN TRUE;
      END;

      // second part
      IF NOT StartWriting( len, OUT dst, OUT allowed ) THEN // should never occur
         ASSERT( FALSE );
         RETURN FALSE;
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
         RETURN TRUE;
      ELSE
         ASSERT( FALSE );
         RETURN FALSE;
      END;
   END Queue;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Dequeue( OUT Q : QUADWORD; Wait : BOOLEAN; Timeout : CARDINAL ) : BOOLEAN;
   VAR
      allowed : CARDINAL;
      commit : CARDINAL;
      dst : PBYTE := PBYTE( ADR( Q ));
      src : PBYTE;
      len : CARDINAL := SIZE( QUADWORD );
   BEGIN
      LOOP
         IF Count >= SIZE( QUADWORD ) THEN // data is sufficient
            EXIT;
         ELSIF NOT Wait OR ( Sync.Wait( Consume, Timeout ) <> Sync.arCompleted ) THEN
            RETURN FALSE;
         END;
      END; // LOOP

      // first part
      IF NOT StartReading( len, OUT src, OUT allowed ) THEN
         ASSERT( FALSE );
         RETURN FALSE;
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
         RETURN TRUE;
      END;

      // second part
      IF NOT StartReading( len, OUT src, OUT allowed ) THEN // should never occur
         ASSERT( FALSE );
         RETURN FALSE;
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
         RETURN TRUE;
      ELSE
         ASSERT( FALSE );
         RETURN FALSE;
      END;
   END Dequeue;

(*--------------------------------------------------------------------------------*)

BEGIN
   Consume := Sync.CreateSignal( FALSE, L"" );
   Produce := Sync.CreateSignal( TRUE, L"" );
FINALLY
   Sync.DeleteSignal( REF Consume );
   Sync.DeleteSignal( REF Produce );
END QuadwordQueue;

(*================================================================================*)

END SyncQueue.