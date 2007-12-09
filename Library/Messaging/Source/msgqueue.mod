IMPLEMENTATION MODULE msgqueue;

FROM Storage IMPORT
  ALLOCATE, DEALLOCATE, REALLOCATE;
IMPORT
  Storage,
  windows;

(*================================================================================*)

CLASS IMPLEMENTATION CMessageQueue;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY FlushIfFull GET : BOOLEAN;
  BEGIN
    RETURN moFlushIfFull IN Options;
  END FlushIfFull;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY FlushIfFull SET( Value : BOOLEAN );
  BEGIN
    IF Value THEN
      INCL( Options, moFlushIfFull )
    ELSE
      EXCL( Options, moFlushIfFull )
    END;
  END FlushIfFull;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY ConsumerMsg GET : POINTER TO msghandler.Message;
  BEGIN
    RETURN Msg;
  END ConsumerMsg;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY ConsumerMsg SET( Value : POINTER TO msghandler.Message );
  BEGIN
    IF Msg <> NIL THEN
      DISPOSE( Msg );
    END;
    Msg := msghandler.TPMessage( Value^.Clone());
  END ConsumerMsg;
  
(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE Flush() : Sync.TAsyncResult; // completed, timeout, aborted
   VAR
      Result : Sync.TAsyncResult;
   BEGIN
      Result := SUPER.Flush();
      IF Consumer = NIL THEN
         RETURN Result;
      ELSIF NOT( moFlushIfFull IN Options ) THEN
         RETURN Sync.arCompleted;
      ELSIF msghandler.CurrentThread() = Consumer^.OfThread THEN // consumer is in my thread
         IF Msg = NIL THEN
            NEW( msghandler.TPMessage( Msg )); Msg^.Message := WM_MQ_PROCESS;
         END;
         INCL( Options, moLeaveLock );
         IF NOT Consumer^.Message( Msg^, msghandler.delSynchronous, NIL ) THEN
            ASSERT( FALSE );
         END;
         EXCL( Options, moLeaveLock );
      ELSE // consumer is in the other thread
         windows.Sleep( 0 );
      END;
      RETURN Sync.arCompleted;
   END Flush;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE Signal( What : Sync.TpcqSignal ); // when produced, next producing SHOULD NOT be done (until signalling consumed)
   BEGIN
      CASE What OF
      | Sync.pcqProduced : // overwrite SUPER
         IF Sync.IExchg( REF Consuming, 1 ) = 0 THEN
            IF Consumer <> NIL THEN
               IF Msg = NIL THEN
                  NEW( msghandler.TPMessage( Msg )); Msg^.Message := WM_MQ_PROCESS;
               END;
               IF NOT Consumer^.Message( Msg^, msghandler.delAsynchronous, NIL ) THEN
                  ASSERT( FALSE );
               END;
            END;
            Sync.Signal( Consume );
         END;
      | Sync.pcqStartingConsumation : // overwrite SUPER
         IF moLeaveLock IN Options THEN
            // skip, do nothing
         ELSIF Sync.IExchg( REF Consuming, 0 ) = 1 THEN
            Sync.Reset( Consume );
         END;
      ELSE // use default
         SUPER.Signal( What );
      END; // CASE
  END Signal;

(*--------------------------------------------------------------------------------*)

BEGIN
  Consuming := 0;
  Options := TMQOptions{};
  Msg := NIL;
  Consumer := NIL;
FINALLY
  IF Msg <> NIL THEN
    DISPOSE( Msg );
  END;
END CMessageQueue;

(*================================================================================*)

END msgqueue.