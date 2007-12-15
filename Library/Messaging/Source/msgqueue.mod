IMPLEMENTATION MODULE msgqueue;

FROM Storage IMPORT
  ALLOCATE, DEALLOCATE, REALLOCATE;
IMPORT
  Storage,
  windows;

(*================================================================================*)

CLASS IMPLEMENTATION CMessageQueue;
  
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
      ASSERT( Consumer <> NIL );
      IF msghandler.CurrentThread() = Consumer^.OfThread THEN // consumer is in my thread
         IF Msg = NIL THEN
            NEW( msghandler.TPMessage( Msg )); Msg^.Message := WM_MQ_PROCESS;
         END;
         Sync.IExchg( REF LeaveLock, 1 ); // lock over thread is safe ad here consumer/producer shares thread
         IF NOT Consumer^.Message( Msg^, msghandler.delSynchronous, NIL ) THEN
            ASSERT( FALSE );
         END;
         Sync.IExchg( REF LeaveLock, 0 );
      ELSE // consumer is in the other thread
         windows.Sleep( 0 );
      END;
      RETURN Sync.arCompleted;
   END Flush;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE Signal( What : Sync.TpcqSignal ); // when produced, next producing SHOULD NOT be done (until signalling consumed)
   BEGIN
      ASSERT( Consumer <> NIL );
      CASE What OF
      | Sync.pcqProduced :
         IF Sync.IExchg( REF Consuming, 1 ) = 0 THEN
            IF Msg = NIL THEN
               NEW( msghandler.TPMessage( Msg )); Msg^.Message := WM_MQ_PROCESS;
            END;
            IF NOT Consumer^.Message( Msg^, msghandler.delAsynchronous, NIL ) THEN
               ASSERT( FALSE );
            END;
         END;
      | Sync.pcqStartingConsumation :
         IF Sync.IGet( REF LeaveLock ) = 1 THEN
            // skip, do nothing
         ELSE
            Sync.IExchg( REF Consuming, 0 );
         END;
      END; // CASE
  END Signal;

(*--------------------------------------------------------------------------------*)

BEGIN
  Consuming := 0;
  LeaveLock := 0;
  Msg := NIL;
  Consumer := NIL;
FINALLY
  IF Msg <> NIL THEN
    DISPOSE( Msg );
  END;
END CMessageQueue;

(*================================================================================*)

END msgqueue.