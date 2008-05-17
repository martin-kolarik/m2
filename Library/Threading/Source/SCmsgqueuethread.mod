IMPLEMENTATION MODULE SCmsgqueuethread;

(*---------------------------------------------------------------------------*)
  
FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;
  
IMPORT
   msghandler,
   SCmsg,
   Sync,
   windows;

(*===========================================================================*)

CLASS IMPLEMENTATION SCMsgQueueThread;

(*---------------------------------------------------------------------------*)
  
   INTERNAL FINAL PROCEDURE OnRun() : CARDINAL;
   CONST
      waitHandles = 2;
   VAR
      WaitHandles : ARRAY [0..1] OF Sync.WAITABLE;
      Msg : SCmsg.SCMessage;
      Target : OSALmsg.TPMessageRecipient;
      Status : CARDINAL;
   BEGIN
      WaitHandles[0] := _HExit;
      WaitHandles[1] := queue.Consume;
   
      OnStart();
      LOOP
         Status := windows.WaitForMultipleObjectsEx( waitHandles, ADR( WaitHandles ), windows.False, windows.INFINITE, windows.True );
         CASE Status OF
         //-----
         | CARDINAL( windows.WAIT_FAILED ), windows.WAIT_ABANDONED : // some handle failed, this MUST not occur
            Status := windows.GetLastError();
            ASSERT( FALSE );
            OnExit();
            RETURN -1;

         //-----
         | windows.WAIT_OBJECT_0 : // graceful EXIT
            OnExit();
            RETURN 0;

         //-----
         | windows.WAIT_OBJECT_0 + 1 : // queue
            WHILE queue.DequeueOA( OUT Msg, FALSE, 0 ) = Sync.arCompleted DO

               IF Msg.Target <> NIL THEN // self or root
                  Target := Msg.Target;
               ELSIF Root <> NIL THEN
                  Target := Root;
               ELSE
                  Target := ADR( SELF );
               END;
               Target^.Message( Msg, msghandler.delSynchronous, NIL );

            END; // WHILE

         //-----
         | windows.WAIT_IO_COMPLETION :

         //-----
         END; // CASE
      END; // LOOP
   END OnRun;
   
(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROPERTY Root GET : msghandler.TPMessageRecipient;
   BEGIN
      RETURN NIL;
   END Root;
  
(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnStart();
   BEGIN
   END OnStart;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnExit();
   BEGIN
   END OnExit;

(*---------------------------------------------------------------------------*)
  
   INTERNAL VIRTUAL PROCEDURE MessageToRecipient( CONST Msg : PTR; OUT Recipient : msghandler.TPMessageRecipient ) : BOOLEAN;
   BEGIN
      RETURN SCmsg.HandleToRecipient( SCmsg.TPMessage( Msg )^.Target, OUT Recipient );
   END MessageToRecipient;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY SelfContext GET : BOOLEAN;
   BEGIN
      RETURN _Thread = windows.GetCurrentThreadId();
   END SelfContext;
  
(*---------------------------------------------------------------------------*)
  
   PUBLIC VIRTUAL PROCEDURE Message( CONST Msg : msghandler.IMessage; Delivery : msghandler.TDelivery; Result : PPTR ) : BOOLEAN; // if Msg.Target = NIL then the message must be processed by thread itself; Delivery is possible only delSynchronousInThread and delAsynchronous
   VAR
      AResult : Sync.TAsyncResult;
      LResult : PTR;
   BEGIN
      IF ( Delivery = msghandler.delSynchronous ) OR ( Delivery = msghandler.delSynchronousIfInThread ) AND SelfContext THEN
         IF Result = NIL THEN
            Result := ADR( LResult );
         END;
         IF NOT support^.HandleSupportMessage( Msg ) THEN
            RETURN OnMessage( Msg, OUT Result^ );
         END;
      ELSE
         AResult := queue.QueueOA( Msg, TRUE, Sync.FORSAFETY );
         ASSERT( AResult <> Sync.arTimeout );
      END;
      RETURN TRUE;
   END Message;

(*---------------------------------------------------------------------------*)
  
   INTERNAL VIRTUAL PROCEDURE OnMessage( CONST Msg : msghandler.IMessage; OUT Result : PTR ) : BOOLEAN; // thread targetted messages
   BEGIN
      RETURN FALSE;
   END OnMessage;

(*---------------------------------------------------------------------------*)
  
   PUBLIC VIRTUAL PROCEDURE Join( Recipient : OSALmsg.TPMessageRecipient );
   BEGIN
      support^.Join( Recipient );
   END Join;

(*---------------------------------------------------------------------------*)
  
   PUBLIC VIRTUAL PROCEDURE Leave( Recipient : OSALmsg.TPMessageRecipient );
   BEGIN
      support^.Leave( Recipient );
   END Leave;

(*---------------------------------------------------------------------------*)
  
   PUBLIC FINAL PROPERTY JoinedTo GET : OSALmsg.TPMessageQueueThread;
   BEGIN
      ASSERT( FALSE );
      RETURN NIL;
   END JoinedTo;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROCEDURE JoinMessageThread( JoinTo : OSALmsg.TPMessageQueueThread );
   BEGIN
      ASSERT( FALSE );
   END JoinMessageThread;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROCEDURE LeaveMessageThread();
   BEGIN
      ASSERT( FALSE );
   END LeaveMessageThread;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROCEDURE OnJoin( JoinedTo : OSALmsg.TPMessageQueueThread );
   BEGIN
      ASSERT( FALSE );
   END OnJoin;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROCEDURE OnLeave();
   BEGIN
      ASSERT( FALSE );
   END OnLeave;

(*---------------------------------------------------------------------------*)

BEGIN
   NEW( support );
   support^.Init( ADR( SELF ));
   queue.Consume := Sync.CreateAutoresetSignal( FALSE, L"" );
   queue.Size := 2048;
FINALLY
   support^.Dispose();
   DISPOSE( support );
END SCMsgQueueThread;

(*===========================================================================*)

VAR
   GMQT : SCMsgQueueThread;

PROCEDURE SCGlobalMsgQueueThread() : POINTER TO OSALmsg.IMessageQueueThread;
BEGIN
   RETURN ADR( GMQT );
END SCGlobalMsgQueueThread;

(*===========================================================================*)

BEGIN
   GMQT.Run( TRUE );
FINALLY
   GMQT.Stop( TRUE );
END SCmsgqueuethread.