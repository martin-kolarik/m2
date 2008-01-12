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

   INTERNAL VIRTUAL PROCEDURE Signal( What : Sync.TpcqSignal ); // when produced, next producing SHOULD NOT be done (until signalling consumed)
   VAR
      Delivery : msghandler.TDelivery;
   BEGIN
      SUPER.Signal( What );
      CASE What OF
      | Sync.pcqProduced, Sync.pcqProducedFlush :
         IF Consumer = NIL THEN
            RETURN;
         END;
      ELSE
         RETURN;
      END;

      IF Msg = NIL THEN
         NEW( msghandler.TPMessage( Msg )); Msg^.Message := WM_MQ_PROCESS;
      END;
      IF ( What = Sync.pcqProducedFlush ) AND Consumer^.SelfContext THEN // consumer is in my thread
         Delivery := msghandler.delSynchronous;
      ELSE // consumer is in the other thread or I am signalled to have new data
         Delivery := msghandler.delAsynchronous;
      END; // CASE

      IF NOT Consumer^.Message( Msg^, Delivery, NIL ) THEN
         ASSERT( FALSE );
      END;
  END Signal;

(*--------------------------------------------------------------------------------*)

BEGIN
  Msg := NIL;
  Consumer := NIL;
FINALLY
  IF Msg <> NIL THEN
    DISPOSE( Msg );
  END;
END CMessageQueue;

(*================================================================================*)

END msgqueue.