IMPLEMENTATION MODULE Win32msgqueuethread;

(*---------------------------------------------------------------------------*)
  
FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;
  
IMPORT
   msghandler,
   Win32msg,
   windows;

(*===========================================================================*)

CLASS IMPLEMENTATION Win32MessageQueueThread;

(*---------------------------------------------------------------------------*)
  
   INTERNAL VIRTUAL PROCEDURE OnRun() : CARDINAL;
   CONST
      waitHandles = 1;
   VAR
      msg : windows.MSG;
      Msg : Win32msg.Win32Message;
      Recipient : OSALmsg.TPMessageRecipient;
      Status : CARDINAL;
   BEGIN
      OnStart();
      LOOP
         Status := windows.MsgWaitForMultipleObjectsEx( waitHandles, ADR( _HExit ), windows.INFINITE, windows.QS_ALLINPUT, windows.MWMO_INPUTAVAILABLE OR windows.MWMO_ALERTABLE );
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
         | windows.WAIT_IO_COMPLETION :

         //-----
         | windows.WAIT_OBJECT_0 + waitHandles : // a message received
            WHILE windows.PeekMessage( ADR( msg ), NIL, 0, 0, windows.PM_REMOVE ) <> 0 DO

               IF msg.hwnd = NIL THEN // a thread message
                  Msg.Source := ADR( SELF );
                  Msg.Target := ADR( SELF );
                  Msg.Message := msg.message;
                  Msg[ Win32msg.MI_WPARAM ] := msg.wParam;
                  Msg[ Win32msg.MI_LPARAM ] := PTR( msg.lParam );
                  Message( Msg, msghandler.delSynchronous, NIL );
                  CONTINUE;
               END; // IF process thread's messages

               // continue Win32 message loop
               windows.TranslateMessage( ADR( msg ));

               IF MessageToRecipient( ADR( msg ), OUT Recipient ) THEN
                  Msg.Source := ADR( SELF );
                  Msg.Target := Recipient;
                  Msg.Message := msg.message;
                  Msg[ Win32msg.MI_WPARAM ] := msg.wParam;
                  Msg[ Win32msg.MI_LPARAM ] := PTR( msg.lParam );
                  IF Root = NIL THEN
                     Recipient^.Message( Msg, msghandler.delSynchronous, NIL );
                  ELSE
                     Root^.Message( Msg, msghandler.delSynchronous, NIL );
                  END;

               ELSIF Root <> NIL THEN
                  Msg.Source := ADR( SELF );
                  Msg.Target := Root;
                  Msg.Message := msg.message;
                  Msg[ Win32msg.MI_WPARAM ] := msg.wParam;
                  Msg[ Win32msg.MI_LPARAM ] := PTR( msg.lParam );
                  Root^.Message( Msg, msghandler.delSynchronous, NIL );

               ELSE
                  windows.DispatchMessage( ADR( msg ));

               END;
            END; // MessageLoop

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
      RETURN Win32msg.HandleToRecipient( windows.PMSG( Msg )^.hwnd, OUT Recipient );
   END MessageToRecipient;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY SelfContext GET : BOOLEAN;
   BEGIN
      RETURN _Thread = windows.GetCurrentThreadId();
   END SelfContext;
  
(*---------------------------------------------------------------------------*)
  
   PUBLIC VIRTUAL PROCEDURE Message( CONST Msg : msghandler.IMessage; Delivery : msghandler.TDelivery; Result : PPTR ) : BOOLEAN; // if Msg.Target = NIL then the message must be processed by thread itself; Delivery is possible only delSynchronousInThread and delAsynchronous
   VAR
      LResult : PTR;
   BEGIN
      IF ( Delivery = msghandler.delSynchronous ) OR ( Delivery = msghandler.delSynchronousIfInThread ) AND SelfContext THEN
         IF Result = NIL THEN
            Result := ADR( LResult );
         END;
         IF NOT Support^.HandleSupportMessage( Msg ) THEN
            RETURN OnMessage( Msg, OUT Result^ );
         END;
      ELSE
         windows.PostThreadMessage( _Thread, Msg.Message, windows.WPARAM( Msg[ Win32msg.MI_WPARAM ] ), windows.LPARAM( Msg[ Win32msg.MI_LPARAM ] ));
      END;
      RETURN TRUE;
   END Message;

(*---------------------------------------------------------------------------*)
  
   INTERNAL VIRTUAL PROCEDURE OnMessage( CONST Msg : msghandler.IMessage; OUT Result : PTR ) : BOOLEAN; // thread targetted messages
   BEGIN
      RETURN FALSE;
   END OnMessage;

(*---------------------------------------------------------------------------*)
  
   PUBLIC VIRTUAL PROCEDURE Join( Recipient : OSALmsg.TPMessageRecipient; CallOnJoinInThread : BOOLEAN );
   BEGIN
      Support^.Join( Recipient, CallOnJoinInThread );
   END Join;

(*---------------------------------------------------------------------------*)
  
   PUBLIC VIRTUAL PROCEDURE Leave( Recipient : OSALmsg.TPMessageRecipient; CallOnLeaveInThread : BOOLEAN );
   BEGIN
      Support^.Leave( Recipient, CallOnLeaveInThread );
   END Leave;

(*---------------------------------------------------------------------------*)
  
   PUBLIC FINAL PROPERTY JoinedTo GET : OSALmsg.TPMessageQueueThread;
   BEGIN
      RETURN ADR( SELF );
   END JoinedTo;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROCEDURE JoinMessageThread( JoinTo : OSALmsg.TPMessageQueueThread; CallOnJoinInThread : BOOLEAN );
   BEGIN
      ASSERT( FALSE );
   END JoinMessageThread;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROCEDURE LeaveMessageThread( CallOnLeaveInThread : BOOLEAN );
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
   NEW( Support );
   Support^.Init( ADR( SELF ));
   WithMessages := TRUE;
FINALLY
   Support^.Dispose();
   DISPOSE( Support );
END Win32MessageQueueThread;

(*===========================================================================*)

PROCEDURE Win32GlobalMessageQueueThread() : POINTER TO OSALmsg.IMessageQueueThread;
BEGIN
   RETURN NIL; // there is no global thread, the default one is used
END Win32GlobalMessageQueueThread;

PROCEDURE Startup();
BEGIN
END Startup;

PROCEDURE Cleanup();
BEGIN
END Cleanup;

(*===========================================================================*)

END Win32msgqueuethread.