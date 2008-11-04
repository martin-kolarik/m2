IMPLEMENTATION MODULE msgqueue;

FROM Debug IMPORT
   Assertion, LogAssertionW;

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
    IF Value <> NIL THEN
      Msg := msghandler.TPMessage( Value^.Clone());
    END;
  END ConsumerMsg;
  
(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE Signal( What : Sync.TpcqSignal ); // when produced, next producing SHOULD NOT be done (until signalling consumed)
   // keep in sync with CPtrQueue.Signal
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
         NEW( msghandler.TPMessage( Msg ));
         Msg^.Message := MSG_PROCESS_QUEUE;
      END;
      IF What = Sync.pcqProducedFlush THEN
         IF Consumer^.SelfContext THEN // consumer is in my thread, allow flushing by forcible read
            Delivery := msghandler.delSynchronous;
         ELSE // consumer is not in my thread, do not exhaust queue with next and next messages (one message is already sent from pcqProduced)
            RETURN;
         END;
      ELSE // consumer is in the other thread or I am signalled to have new data
         Delivery := msghandler.delAsynchronous;
      END; // CASE

      IF NOT Consumer^.Message( Msg^, Delivery, NIL ) THEN
         ASSERTLOG( FALSE );
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

CLASS IMPLEMENTATION CPtrQueue;

(*--------------------------------------------------------------------------------*)

   PUBLIC READONLY PROPERTY Count GET : CARDINAL;
   VAR
      c : CARDINAL;
   BEGIN
      Lock.Lock();
      c := _Queue.Count;
      Lock.Unlock();
      RETURN c;
   END Count;

(*--------------------------------------------------------------------------------*)

   PUBLIC READONLY PROPERTY Empty GET : BOOLEAN;
   VAR
      b : BOOLEAN;
   BEGIN
      Lock.Lock();
      b := _Queue.Empty;
      Lock.Unlock();
      RETURN b;
   END Empty;

(*--------------------------------------------------------------------------------*)

   PUBLIC READONLY PROPERTY Full GET : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END Full;

(*--------------------------------------------------------------------------------*)

   PUBLIC READONLY PROPERTY Size GET : CARDINAL;
   BEGIN
      RETURN -1;
   END Size;

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
      IF Value <> NIL THEN
         Msg := msghandler.TPMessage( Value^.Clone());
      END;
   END ConsumerMsg;
  
(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Clear();
   BEGIN
      Lock.Lock();
      _Queue.Dispose();
      Lock.Unlock();
   END Clear;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Dequeue( OUT Message : PTR ) : BOOLEAN;
   VAR
      b : BOOLEAN;
      data : PTR;
   BEGIN
      Lock.Lock();
      b := _Queue.Dequeue( OUT Message, OUT data );
      IF b AND _Queue.Empty THEN
         Signal( Sync.pcqConsumed );
      END;
      Lock.Unlock();
      RETURN b;
   END Dequeue;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Peek( OUT Message : PTR ) : BOOLEAN;
   VAR
      b : BOOLEAN;
      data : PTR;
   BEGIN
      Lock.Lock();
      b := _Queue.GetFirst( OUT Message, OUT data );
      Lock.Unlock();
      RETURN b;
   END Peek;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Enqueue( CONST Message : PTR );
   BEGIN
      Lock.Lock();
      _Queue.Enqueue( Message, 0 );
      IF _Queue.Count = 1 THEN
         Signal( Sync.pcqProduced );
      END;
      Lock.Unlock();
   END Enqueue;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE Signal( What : Sync.TpcqSignal ); // when produced, next producing SHOULD NOT be signalled (until signalling consumed)
   // keep in sync with CMessageQueue.Signal
   VAR
      Delivery : msghandler.TDelivery;
   BEGIN
      CASE What OF
      | Sync.pcqProduced, Sync.pcqProducedFlush : Sync.SafeSignal( Consume );
      | Sync.pcqConsumed, Sync.pcqConsumedFlush : Sync.SafeSignal( Produce );
      END; // CASE

      CASE What OF
      | Sync.pcqProduced, Sync.pcqProducedFlush :
         IF Consumer = NIL THEN
            RETURN;
         END;
      ELSE
         RETURN;
      END;

      IF Msg = NIL THEN
         NEW( msghandler.TPMessage( Msg ));
         Msg^.Message := MSG_PROCESS_QUEUE;
      END;
      IF What = Sync.pcqProducedFlush THEN
         IF Consumer^.SelfContext THEN // consumer is in my thread, allow flushing by forcible read
            Delivery := msghandler.delSynchronous;
         ELSE // consumer is not in my thread, do not exhaust queue with next and next messages (one message is already sent from pcqProduced)
            RETURN;
         END;
      ELSE // consumer is in the other thread or I am signalled to have new data
         Delivery := msghandler.delAsynchronous;
      END; // CASE

      IF NOT Consumer^.Message( Msg^, Delivery, NIL ) THEN
         ASSERTLOG( FALSE );
      END;
   END Signal;

(*--------------------------------------------------------------------------------*)

BEGIN
   Consumer := NIL;
   Msg := NIL;
FINALLY
   IF Msg <> NIL THEN
      DISPOSE( Msg );
   END;
END CPtrQueue;

(*================================================================================*)

END msgqueue.