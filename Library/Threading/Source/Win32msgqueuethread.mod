IMPLEMENTATION MODULE Win32msgqueuethread;

(*---------------------------------------------------------------------------*)
  
FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;
  
IMPORT
   msghandler,
   Sync,
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
      Return : CARDINAL := -1;
      Status : CARDINAL;
      Target : OSALmsg.TPMessageTarget;
   BEGIN
      OnStart();
      LOOP
         Status := windows.MsgWaitForMultipleObjectsEx( waitHandles, ADR( _HExit ), windows.INFINITE, windows.QS_ALLINPUT, windows.MWMO_INPUTAVAILABLE OR windows.MWMO_ALERTABLE );
         CASE Status OF
         //-----
         | CARDINAL( windows.WAIT_FAILED ), windows.WAIT_ABANDONED : // some handle failed, this MUST not occur
            Status := windows.GetLastError();
            ASSERT( FALSE );
            EXIT;

         //-----
         | windows.WAIT_OBJECT_0 : // graceful EXIT
            Return := 0;
            EXIT;

         //-----
         | windows.WAIT_IO_COMPLETION :

         //-----
         | windows.WAIT_OBJECT_0 + waitHandles : // a message received
            WHILE windows.PeekMessage( ADR( msg ), NIL, 0, 0, windows.PM_REMOVE ) <> 0 DO
               windows.TranslateMessage( ADR( msg ));

               IF MessageToTarget( ADR( msg ), OUT Target ) THEN
                  Msg.Source := ADR( SELF );
                  Msg.Target := Target;
                  Msg.Message := msg.message;
                  Msg[ Win32msg.MI_WPARAM ] := msg.wParam;
                  Msg[ Win32msg.MI_LPARAM ] := PTR( msg.lParam );
                  Target^.Message( Msg, msghandler.delSynchronous, NIL );

               ELSE
                  windows.DispatchMessage( ADR( msg ));

               END;
            END; // MessageLoop

         END; // CASE
      END; // LOOP

      OnExit();
      RETURN Return;
   END OnRun;
   
(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROCEDURE ThreadCall( Target : threadcall.TPIThreadProcedureCallTarget; Operation : CARDINAL; CONST Parameters : ARRAY OF PTR; PReturnValue : POINTER TO PTR;
                                      WaitForResult : BOOLEAN; WaitTimeoutMS : CARDINAL ) : Sync.TAsyncResult;
   BEGIN
      RETURN Support^.ThreadCall( Target, Operation, Parameters, PReturnValue, WaitForResult, WaitTimeoutMS );
   END ThreadCall;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnMessage( CONST Msg : msghandler.IMessage; OUT Result : PTR ) : BOOLEAN; // thread targetted messages
   BEGIN
      RETURN FALSE;
   END OnMessage;

(*---------------------------------------------------------------------------*)
  
   INTERNAL VIRTUAL PROCEDURE OnTimer( TimerId : PTR ); // thread targetted timer
   BEGIN
   END OnTimer;

(*---------------------------------------------------------------------------*)
  
   INTERNAL VIRTUAL PROPERTY Root GET : msghandler.TPIMessageHandler;
   BEGIN
      RETURN NIL;
   END Root;
  
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
            IF Msg.Message = windows.WM_TIMER THEN
               ASSERT( FALSE ); // not implemented yet
            ELSE
               RETURN OnMessage( Msg, OUT Result^ );
            END;
         END;
      ELSE
         windows.PostThreadMessage( _Thread, Msg.Message, windows.WPARAM( Msg[ Win32msg.MI_WPARAM ] ), windows.LPARAM( Msg[ Win32msg.MI_LPARAM ] ));
      END;
      RETURN TRUE;
   END Message;

(*---------------------------------------------------------------------------*)
  
   PUBLIC VIRTUAL PROCEDURE StartTimer( CONST Target : msghandler.IMessageTarget; TimerId : PTR; PeriodMS : CARDINAL; Repeat : BOOLEAN );
   BEGIN
      ASSERT( FALSE ); // not implemented yet
   END StartTimer;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE StopTimer( CONST Target : msghandler.IMessageTarget; TimerId : PTR );
   BEGIN
      ASSERT( FALSE ); // not implemented yet
   END StopTimer;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE TimerRunning( CONST Target : msghandler.IMessageTarget; TimerId : PTR ) : BOOLEAN;
   BEGIN
      ASSERT( FALSE ); // not implemented yet
      RETURN FALSE;
   END TimerRunning;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnStart();
   BEGIN
   END OnStart;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnExit();
   BEGIN
   END OnExit;

(*---------------------------------------------------------------------------*)
  
   INTERNAL VIRTUAL PROCEDURE MessageToTarget( CONST Msg : PTR; OUT Target : msghandler.TPMessageTarget ) : BOOLEAN;
   BEGIN
      IF windows.PMSG( Msg )^.hwnd = NIL THEN // mine thread message
         Target := ADR( SELF );
         RETURN TRUE;
      ELSIF Win32msg.HandleToTarget( windows.PMSG( Msg )^.hwnd, OUT Target ) THEN
         RETURN TRUE;
      ELSIF Root <> NIL THEN
         Target := Root;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END MessageToTarget;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Join( Handler : OSALmsg.TPMessageHandler; CallOnJoinInThread : BOOLEAN );
   BEGIN
      Support^.Join( Handler, CallOnJoinInThread );
   END Join;

(*---------------------------------------------------------------------------*)
  
   PUBLIC VIRTUAL PROCEDURE Leave( Handler : OSALmsg.TPMessageHandler; CallOnLeaveInThread : BOOLEAN );
   BEGIN
      Support^.Leave( Handler, CallOnLeaveInThread );
   END Leave;

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

VAR
   GMQT : POINTER TO Win32MessageQueueThread := NIL;

PROCEDURE Win32GlobalMessageQueueThread() : POINTER TO OSALmsg.IMessageQueueThread;
BEGIN
   ASSERT( GMQT <> NIL );
   RETURN GMQT;
END Win32GlobalMessageQueueThread;

PROCEDURE Startup();
BEGIN
   IF GMQT = NIL THEN
      NEW( GMQT );
      // GMQT^.Run( TRUE ); -- for Win32 global thread MUST not be run, because default thread runs in Win32 process context
   END;
END Startup;

PROCEDURE Cleanup();
BEGIN
   IF GMQT <> NIL THEN
      // GMQT^.Stop( TRUE ); -- for Win32 global thread MUST not be stopped, because default thread runs in Win32 process context
      DISPOSE( GMQT );
   END;
END Cleanup;

(*===========================================================================*)

END Win32msgqueuethread.