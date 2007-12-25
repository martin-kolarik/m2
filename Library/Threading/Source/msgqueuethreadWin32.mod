IMPLEMENTATION MODULE msgqueuethreadWin32;

(*---------------------------------------------------------------------------*)
  
FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;
  
IMPORT
   windows;

(*===========================================================================*)

CLASS IMPLEMENTATION Win32MsgQueueThread;

(*---------------------------------------------------------------------------*)
  
   INTERNAL FINAL PROCEDURE OnRun() : CARDINAL;
   CONST
      waitHandles = 1;
   VAR
      Handler : msghandler.TPMessageHandler;
      msg : windows.MSG;
      Msg : msghandler.Message;
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
                  Msg.Target := NIL;
                  Msg.Message := msg.message;
                  Msg[2] := msg.wParam;
                  Msg[3] := PTR( msg.lParam );
                  Message( Msg, msghandler.delSynchronous, NIL );
                  CONTINUE;
               END; // IF process thread's messages

               // continue Win32 message loop
               windows.TranslateMessage( ADR( msg ));

               IF MessageToHandler( ADR( msg ), OUT Handler ) THEN
                  Msg.Target := Handler;
                  Msg.Message := msg.message;
                  Msg[2] := msg.wParam;
                  Msg[3] := PTR( msg.lParam );
                  IF Root = NIL THEN
                     Handler^.Message( Msg, msghandler.delSynchronous, NIL );
                  ELSE
                     Root^.Message( Msg, msghandler.delSynchronous, NIL );
                  END;

               ELSIF Root <> NIL THEN
                  Msg.Message := msg.message;
                  Msg[2] := msg.wParam;
                  Msg[3] := PTR( msg.lParam );
                  Root^.Message( Msg, msghandler.delSynchronous, NIL );

               ELSE
                  windows.DispatchMessage( ADR( msg ));

               END;
            END; // MessageLoop

         END; // CASE
      END; // LOOP
   END OnRun;
   
(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROPERTY Root GET : msghandler.TPMessageHandler;
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
  
   INTERNAL VIRTUAL PROCEDURE MessageToHandler( CONST Msg : PTR; OUT Handler : msghandler.TPMessageHandler ) : BOOLEAN;
   BEGIN
      RETURN msghandler.HandleToHandler( windows.PMSG( Msg )^.hwnd, OUT Handler );
   END MessageToHandler;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY SelfContext GET : BOOLEAN;
   BEGIN
      RETURN _Thread = windows.GetCurrentThreadId();
   END SelfContext;
  
(*---------------------------------------------------------------------------*)
  
   PUBLIC VIRTUAL PROCEDURE Message( CONST Msg : msghandler.IMessage; Delivery : msghandler.TDelivery; Result : PPTR ) : BOOLEAN; // if Msg.Target = NIL then the message must be processed by thread itself; Delivery is possible only delSynchronousInThread and delAsynchronous
   VAR
      LResult : PTR;
   BEGIN
      IF ( Delivery = msghandler.delSynchronous ) OR
         ( Delivery = msghandler.delSynchronousInThread ) AND SelfContext THEN
         IF Result = NIL THEN
            Result := ADR( LResult );
         END;
         RETURN OnMessage( Msg, OUT Result^ );
      ELSE
         windows.PostThreadMessage( _Thread, Msg.Message, windows.WPARAM( Msg[2] ), windows.LPARAM( Msg[3] ));
      END;
      RETURN TRUE;
   END Message;

(*---------------------------------------------------------------------------*)
  
   INTERNAL VIRTUAL PROCEDURE OnMessage( CONST Msg : msghandler.IMessage; OUT Result : PTR ) : BOOLEAN; // thread targetted messages
   BEGIN
      RETURN FALSE;
   END OnMessage;

(*---------------------------------------------------------------------------*)
  
BEGIN
   WithMessages := TRUE;
END Win32MsgQueueThread;

(*===========================================================================*)

END msgqueuethreadWin32.