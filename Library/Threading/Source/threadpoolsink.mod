IMPLEMENTATION MODULE threadpoolsink;

//================================================================================

CLASS IMPLEMENTATION APoolDelegate;

  PUBLIC VIRTUAL PROCEDURE OnTimeout( Result : Sync.TAsyncResult; PoolHandle : TPoolHandle; UserId : PTR );
  BEGIN
  END OnTimeout;

  PUBLIC VIRTUAL PROCEDURE OnMessage( Result : Sync.TAsyncResult; PoolHandle : TPoolHandle; UserId : PTR; CONST MSG : OSALmsg.IMessage );
  BEGIN
  END OnMessage;

  PUBLIC VIRTUAL PROCEDURE OnHandle( Result : Sync.TAsyncResult; PoolHandle : TPoolHandle; UserId : PTR );
  BEGIN
  END OnHandle;

  PUBLIC VIRTUAL PROCEDURE OnWorker( Result : Sync.TAsyncResult; PoolHandle : TPoolHandle; UserId : PTR );
  BEGIN
  END OnWorker;

END APoolDelegate;

//================================================================================

CLASS IMPLEMENTATION CSinkDelegate;

//---------------------------------------------------------------------------

   PUBLIC FINAL PROCEDURE OnTimeout( Result : Sync.TAsyncResult; PoolHandle : TPoolHandle; UserId : PTR );
   BEGIN
      IF TimeoutSink <> NIL THEN
         TimeoutSink^.OnTimeout( Result, PoolHandle, UserId );
      END;
   END OnTimeout;

//---------------------------------------------------------------------------

   PUBLIC FINAL PROCEDURE OnMessage( Result : Sync.TAsyncResult; PoolHandle : TPoolHandle; UserId : PTR; CONST MSG : OSALmsg.IMessage );
   BEGIN
      IF MessageSink <> NIL THEN
         MessageSink^.OnMessage( Result, PoolHandle, UserId, MSG );
      END;
   END OnMessage;

//---------------------------------------------------------------------------

   PUBLIC FINAL PROCEDURE OnHandle( Result : Sync.TAsyncResult; PoolHandle : TPoolHandle; UserId : PTR );
   BEGIN
      IF HandleSink <> NIL THEN
         HandleSink^.OnHandle( Result, PoolHandle, UserId );
      END;
   END OnHandle;

//---------------------------------------------------------------------------

   PUBLIC FINAL PROCEDURE OnWorker( Result : Sync.TAsyncResult; PoolHandle : TPoolHandle; UserId : PTR );
   BEGIN
      IF WorkerSink <> NIL THEN
         WorkerSink^.OnWorker( Result, PoolHandle, UserId );
      END;
   END OnWorker;

//---------------------------------------------------------------------------

BEGIN
   TimeoutSink := NIL;
   MessageSink := NIL;
   HandleSink := NIL;
   WorkerSink := NIL;
END CSinkDelegate;

//================================================================================

CLASS IMPLEMENTATION CMessageHandlerDelegate;

   PUBLIC FINAL PROCEDURE OnMessage( Result : Sync.TAsyncResult; PoolHandle : TPoolHandle; UserId : PTR; CONST MSG : OSALmsg.IMessage );
   BEGIN
      IF Handler = NIL THEN
        RETURN;
      ELSIF Result = Sync.arCompleted THEN
        Handler^.Message( MSG, Delivery, NIL );
      END;
   END OnMessage;
  
BEGIN
   Handler := NIL;
END CMessageHandlerDelegate;

//================================================================================

END threadpoolsink.
