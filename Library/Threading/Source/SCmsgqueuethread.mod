IMPLEMENTATION MODULE SCmsgqueuethread;

(*---------------------------------------------------------------------------*)
  
FROM Debug IMPORT
   Assertion, LogAssertionW;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;
  
IMPORT
   msghandler,
   SCmsg,
   Sync,
   time,
   windows;

(*===========================================================================*)

CLASS IMPLEMENTATION SCMessageQueueThread;

(*---------------------------------------------------------------------------*)
  
   INTERNAL VIRTUAL PROCEDURE OnRun() : CARDINAL;
   CONST
      waitHandles = 2;
   VAR
      CurrentTime : CARDINAL;
      Msg : SCmsg.SCMessage;
      Target : msghandler.TPIMessageTarget;
      Timeout : CARDINAL;
      Timer : PTR;
      Status : CARDINAL;
      WaitHandles : ARRAY [0..1] OF Sync.WAITABLE;
   BEGIN
      WaitHandles[0] := _HExit.RawHandle;
      WaitHandles[1] := Queue.Consume^.RawHandle;
   
      OnStart();
      LOOP
         Timeout := Support^.GetTimeoutToFirstElapsed( time.UptimeMS());
         Status := windows.WaitForMultipleObjectsEx( waitHandles, ADR( WaitHandles ), windows.False, Timeout, windows.True );

         CASE Status OF
         //-----
         | CARDINAL( windows.WAIT_FAILED ), windows.WAIT_ABANDONED : // some handle failed, this MUST not occur
            Status := windows.GetLastError();
            ASSERTLOG( FALSE );
            OnExit();
            RETURN -1;

         //-----
         | windows.WAIT_OBJECT_0 : // graceful EXIT
            OnExit();
            RETURN 0;

         //-----
         | windows.WAIT_OBJECT_0 + 1 : // queue
            WHILE Queue.DequeueOA( OUT Msg, FALSE, 0 ) = Sync.arCompleted DO

               IF MessageToTarget( ADR( Msg ), OUT Target ) THEN
                  Target^.Message( Msg, msghandler.delSynchronous, NIL );
               END;

            END; // WHILE

         //-----
         | windows.WAIT_IO_COMPLETION :

         //-----
         | windows.WAIT_TIMEOUT :
            CurrentTime := time.UptimeMS();
            WHILE Support^.GetFirstElapsed( CurrentTime, OUT Target, OUT Timer ) DO
               
               Msg.Source := ADR( SELF );
               Msg.Target := Target;
               Msg.Message := msghandler.MSG_ON_TIMER;
               Msg.Parameter := Timer;
               Target^.Message( Msg, msghandler.delSynchronous, NIL );

            END; // WHILE

         //-----         
         END; // CASE
      END; // LOOP
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
  
   INTERNAL VIRTUAL PROCEDURE OnTimer( Timer : PTR ); // thread targetted timers
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
      AResult : Sync.TAsyncResult;
      i : CARDINAL;
      LResult : PTR;
      message : SCmsg.SCMessage;
   BEGIN
      IF ( Delivery = msghandler.delSynchronous ) OR ( Delivery = msghandler.delSynchronousIfInThread ) AND SelfContext THEN
         IF Result = NIL THEN
            Result := ADR( LResult );
         END;
         IF NOT Support^.HandleSupportMessage( Msg ) THEN
            IF Msg.Message = msghandler.MSG_ON_TIMER THEN
               Msg.Target^.OnTimer( Msg.Parameter );
            ELSE
               IF Result = NIL THEN
                  Result := ADR( LResult );
               END;
               RETURN OnMessage( Msg, OUT Result^ );
            END;
         END;
      ELSE
         FOR i := 0 TO MIN2( Msg.ParameterCount, message.ParameterCount )-1 DO
            message[i] := Msg[i];
         END; // FOR
         AResult := Queue.EnqueueOA( message, TRUE, Sync.FORSAFETY );
         ASSERTLOG( AResult <> Sync.arTimeout );
      END;
      RETURN TRUE;
   END Message;

(*---------------------------------------------------------------------------*)
  
   PUBLIC VIRTUAL PROCEDURE StartTimer( CONST Target : msghandler.IMessageTarget; TimerId : PTR; PeriodMS : CARDINAL; Repeat : BOOLEAN );
   BEGIN
      Support^.StartTimer( msghandler.TPIMessageTarget( ADR( Target )), TimerId, PeriodMS, Repeat );
   END StartTimer;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE StopTimer( CONST Target : msghandler.IMessageTarget; TimerId : PTR );
   BEGIN
      Support^.StopTimer( msghandler.TPIMessageTarget( ADR( Target )), TimerId );
   END StopTimer;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE TimerRunning( CONST Target : msghandler.IMessageTarget; TimerId : PTR ) : BOOLEAN;
   BEGIN
      RETURN Support^.TimerRunning( msghandler.TPIMessageTarget( ADR( Target )), TimerId );
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
  
   INTERNAL VIRTUAL PROCEDURE MessageToTarget( CONST Msg : PTR; OUT Target : msghandler.TPIMessageTarget ) : BOOLEAN;
   VAR
      target : msghandler.TPIMessageTarget := SCmsg.TPMessage( Msg )^.Target;
   BEGIN
      IF target = NIL THEN // message for me, realize about delivery
         IF Root <> NIL THEN
            Target := Root;
         ELSE
            Target := ADR( SELF );
         END;
      ELSE
         IF target = ADR( IMessageTarget ) THEN // self
            Target := ADR( SELF );
         ELSIF Support^.IsJoined( msghandler.TPMessageHandler( target )) THEN
            Target := target;
         ELSE
            RETURN FALSE; // target is not known, e.g. deallocated
         END;
      END;
      RETURN TRUE;
   END MessageToTarget;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Join( Handler : msghandler.TPIMessageHandler; CallOnJoinInThread : BOOLEAN );
   BEGIN
      Support^.Join( Handler, CallOnJoinInThread );
   END Join;

(*---------------------------------------------------------------------------*)
  
   PUBLIC VIRTUAL PROCEDURE Leave( Handler : msghandler.TPIMessageHandler; CallOnLeaveInThread : BOOLEAN );
   BEGIN
      Support^.Leave( Handler, CallOnLeaveInThread );
   END Leave;

(*---------------------------------------------------------------------------*)
  
BEGIN
   NEW( Support );
   Support^.Init( ADR( SELF ));
   
   Queue.Init( 2048, SIZE( msghandler.Message ));
   Queue.Consume := Sync.CreateSignal( Sync.stEventAutoreset, L"", FALSE );
   Queue.Produce := Sync.CreateSignal( Sync.stEvent, L"", TRUE );
FINALLY
   Sync.DeleteSignal( REF Queue.Consume );
   Sync.DeleteSignal( REF Queue.Produce );

   Support^.Dispose();
   DISPOSE( Support );
END SCMessageQueueThread;

(*===========================================================================*)

VAR
   GMQT : POINTER TO SCMessageQueueThread := NIL;

PROCEDURE SCGlobalMessageQueueThread() : POINTER TO SCMessageQueueThread;
BEGIN
   ASSERTLOG( GMQT <> NIL );
   RETURN GMQT;
END SCGlobalMessageQueueThread;

(*---------------------------------------------------------------------------*)

PROCEDURE Startup();
BEGIN
   IF GMQT = NIL THEN
      NEW( GMQT );
      GMQT^.Run( TRUE );
   END;
END Startup;

(*---------------------------------------------------------------------------*)

PROCEDURE Cleanup();
BEGIN
   IF GMQT <> NIL THEN
      GMQT^.Stop( TRUE );
      DISPOSE( GMQT );
   END;
END Cleanup;

(*===========================================================================*)

END SCmsgqueuethread.