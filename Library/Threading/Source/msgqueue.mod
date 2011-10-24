IMPLEMENTATION MODULE msgqueue;

FROM Debug IMPORT
   Assertion, LogAssertionW;

FROM Storage IMPORT
  ALLOCATE, DEALLOCATE, REALLOCATE;

IMPORT
   collection,
   StorageO;

(*================================================================================*)

CLASS IMPLEMENTATION CMessageQueue;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY ConsumerMsg GET : msghandler.TPIMessage;
  BEGIN
    RETURN Msg;
  END ConsumerMsg;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY ConsumerMsg SET( Value : msghandler.TPIMessage );
  BEGIN
    IF Msg <> NIL THEN
      Msg^.Release();
      Msg := NIL;
    END;
    IF Value <> NIL THEN
      Msg := Value^.Clone();
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
    Msg^.Release();
    Msg := NIL;
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

   PUBLIC PROPERTY ConsumerMsg GET : msghandler.TPIMessage;
   BEGIN
      RETURN Msg;
   END ConsumerMsg;
  
(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY ConsumerMsg SET( Value : msghandler.TPIMessage );
   BEGIN
      IF Msg <> NIL THEN
         Msg^.Release();
         Msg := NIL;         
      END;
      IF Value <> NIL THEN
         Msg := Value^.Clone();
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
      iterator : lists.CPtrListIterator;
   BEGIN
      Lock.Lock();
      iterator.Init( _Queue, collection.dirForward );
      b := iterator.MoveNext();
      IF b THEN
         Message := iterator.Value;
      END;
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
   _Queue.Dispose();
   IF Msg <> NIL THEN
      Msg^.Release();
      Msg := NIL;
   END;
END CPtrQueue;

(*================================================================================*)

CLASS IMPLEMENTATION CBufferQueue;

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

   PUBLIC PROPERTY ItemSize GET : CARDINAL;
   BEGIN
      CASE _Queue.ItemType OF
      | lists.blitDynamic :
         RETURN -1;
      | lists.blitSlot256 :
         RETURN 256;
      | lists.blitSlot64 :
         RETURN 64;
      | lists.blitSlot32 :
         RETURN 32;
      END; // CASE
      ASSERT( FALSE );
      RETURN 0;
   END ItemSize;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY ItemSize SET( Value : CARDINAL ); // if -1 or 0 size will be dynamic
   BEGIN
      IF ( INTEGER( Value ) <= 0 ) OR ( Value > 256 ) THEN
         _Queue.ItemType := lists.blitDynamic;
      ELSIF Value > 64 THEN
         _Queue.ItemType := lists.blitSlot256;
      ELSIF Value > 32 THEN
         _Queue.ItemType := lists.blitSlot64;
      ELSE
         _Queue.ItemType := lists.blitSlot32;
      END;
   END ItemSize;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY ConsumerMsg GET : msghandler.TPIMessage;
   BEGIN
      RETURN Msg;
   END ConsumerMsg;
  
(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY ConsumerMsg SET( Value : msghandler.TPIMessage );
   BEGIN
      IF Msg <> NIL THEN
         Msg^.Release();
         Msg := NIL;         
      END;
      IF Value <> NIL THEN
         Msg := Value^.Clone();
      END;
   END ConsumerMsg;
  
(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( SingleBufferSize : CARDINAL ); // if -1 or 0 size will be dynamic
   BEGIN
      ItemSize := SingleBufferSize;
   END Init;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Clear();
   BEGIN
      Lock.Lock();
      _Queue.Dispose();
      Lock.Unlock();
   END Clear;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Dequeue( Buffer : ADDRESS; BufferSize : CARDINAL; Wait : BOOLEAN; Timeout : CARDINAL ) : Sync.TAsyncResult; // Wait/Timeout unused yet
   BEGIN
      RETURN DequeueOA( OUT OA( BufferSize-1, Buffer ), Wait, Timeout );
   END Dequeue;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE DequeueOA( OUT Buffer : ARRAY OF BYTE; Wait : BOOLEAN; Timeout : CARDINAL ) : Sync.TAsyncResult; // if HIGH is less than MessageLen the message is trimmed, Wait/Timeout unused yet
   VAR
      b : BOOLEAN;
      buffer : StorageO.CMemoryBuffer;
      data : PTR;
      filled : CARDINAL;
   BEGIN
      Lock.Lock();
      b := _Queue.Dequeue( OUT buffer, OUT data );
      IF b AND _Queue.Empty THEN
         Signal( Sync.pcqConsumed );
      END;
      Lock.Unlock();
      IF b THEN
         buffer.ToOA( OUT Buffer, OUT filled );
         RETURN Sync.arCompleted;
      ELSE
         RETURN Sync.arNoData;
      END;
   END DequeueOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Enqueue( Buffer : ADDRESS; BufferSize : CARDINAL; Wait : BOOLEAN; Timeout : CARDINAL ) : Sync.TAsyncResult; // Wait/Timeout unused yet
   BEGIN
      RETURN EnqueueOA( OA( BufferSize-1, Buffer ), Wait, Timeout );
   END Enqueue;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE EnqueueOA( CONST Buffer : ARRAY OF BYTE; Wait : BOOLEAN; Timeout : CARDINAL ) : Sync.TAsyncResult; // Wait/Timeout unused yet
   BEGIN
      Lock.Lock();
      _Queue.EnqueueOA( Buffer, 0 );
      IF _Queue.Count = 1 THEN
         Signal( Sync.pcqProduced );
      END;
      Lock.Unlock();
      RETURN Sync.arCompleted;
   END EnqueueOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE PushToConsumer( Wait : BOOLEAN; Timeout : CARDINAL ) : Sync.TAsyncResult; // not implemented yet
   BEGIN
      ASSERT( FALSE );
      RETURN Sync.arCannotStart;
   END PushToConsumer;

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
   _Queue.Dispose();
   IF Msg <> NIL THEN
      Msg^.Release();
      Msg := NIL;
   END;
END CBufferQueue;

(*================================================================================*)

END msgqueue.