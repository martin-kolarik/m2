IMPLEMENTATION MODULE msgthreadsupport;

(*===========================================================================*)

IMPORT
   msghandler,
   time;
   
(*===========================================================================*)

CONST
   OP_JOIN = 1;
   OP_LEAVE = 2;
   OP_START_TIMER = 3;
   OP_STOP_TIMER = 4;

TYPE
   TTimerParameter = RECORD
      Timer : PTR;
      PeriodMS : CARDINAL;
      Repeat : BOOLEAN;
      Signal : Sync.SIGNAL;
   END; // RECORD
   TPTimerParameter = POINTER TO TTimerParameter;

(*===========================================================================*)

CLASS IMPLEMENTATION CSupport;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( OfThread : OSALmsg.TPMessageQueueThread );
   BEGIN
      SELF.OfThread := OfThread;
   END Init;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Dispose();
   BEGIN
      ASSERT( Joined.Empty );
      Joined.Dispose();
      OfThread := NIL;
   END Dispose;
   
(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Join( Handler : OSALmsg.TPMessageHandler; CallOnJoinInThread : BOOLEAN );
   BEGIN
      ThreadCall( ADR( SELF ), OP_JOIN, OA( 0, ADR( Handler )), NIL, TRUE, Sync.FORSAFETY );
   END Join;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Leave( Handler : OSALmsg.TPMessageHandler; CallOnLeaveInThread : BOOLEAN );
   BEGIN
      ThreadCall( ADR( SELF ), OP_LEAVE, OA( 0, ADR( Handler )), NIL, TRUE, Sync.FORSAFETY );
   END Leave;
   
(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE StartTimer( Target : OSALmsg.TPMessageTarget; TimerId : PTR; PeriodMS : CARDINAL; Repeat : BOOLEAN );
   VAR
      Parameters : ARRAY [0..3] OF PTR;
   BEGIN
      Parameters[0] := Target;
      Parameters[1] := TimerId;
      Parameters[2] := PeriodMS;
      Parameters[3] := PTR( Repeat );
      ThreadCall( ADR( SELF ), OP_START_TIMER, Parameters, NIL, TRUE, Sync.FORSAFETY );
   END StartTimer;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE StopTimer( Target : OSALmsg.TPMessageTarget; TimerId : PTR );
   VAR
      Parameters : ARRAY [0..1] OF PTR;
   BEGIN
      Parameters[0] := Target;
      Parameters[1] := TimerId;
      ThreadCall( ADR( SELF ), OP_STOP_TIMER, Parameters, NIL, TRUE, Sync.FORSAFETY );
   END StopTimer;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ThreadCall( Target : threadcall.TPIThreadProcedureCallTarget; Operation : CARDINAL; CONST Parameters : ARRAY OF PTR; PReturnValue : POINTER TO PTR;
                                WaitForResult : BOOLEAN; WaitTimeoutMS : CARDINAL ) : Sync.TAsyncResult;
   VAR
      Call : threadcall.TPThreadProcedureCall;
      MSG : msghandler.Message;
      Result : Sync.TAsyncResult;
      ReturnValue : PTR;
   BEGIN
      ASSERT( OfThread <> NIL );

      IF OfThread^.SelfContext THEN
         ReturnValue := Target^.Invoke( Operation, Parameters );

      ELSE
         NEW( Call );
         Call^.Init( Target, Operation, Parameters );
         Call^.AddRef();
         
         MSG.Source := Target;
         MSG.Target := OfThread;
         MSG.Message := msghandler.MSG_TPC;
         MSG.Parameter := Call;
         OfThread^.Message( MSG, OSALmsg.delAsynchronous, NIL );

         Result := Call^.WaitCompletion( WaitForResult, WaitTimeoutMS );
         IF Result <> Sync.arCompleted THEN
            RETURN Result;
         END;
         
         ReturnValue := Call^.ReturnValue;
         Call^.Release();
      END;

      IF PReturnValue <> NIL THEN
         PReturnValue^ := ReturnValue;
      END;
      RETURN Sync.arCompleted;
   END ThreadCall;                         

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE HandleSupportMessage( CONST Message : OSALmsg.IMessage ) : BOOLEAN; // if it is not join logic message it returns FALSE
   VAR
      message : CARDINAL := Message.Message;
   BEGIN
      CASE message OF
      //-----
      | msghandler.MSG_TPC :
         threadcall.TPThreadProcedureCall( Message.Parameter )^.Do();
         threadcall.TPThreadProcedureCall( Message.Parameter )^.Release();
      ELSE
         RETURN FALSE;
      END;
      RETURN TRUE;
   END HandleSupportMessage;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE IsJoined( Handler : OSALmsg.TPMessageHandler ) : BOOLEAN;
   VAR
      joined : BOOLEAN;
   BEGIN
      JoinedLock.Lock();
      joined := Joined.Contains( Handler );
      JoinedLock.Unlock();
      RETURN joined;
   END IsJoined;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE TimerRunning( Target : OSALmsg.TPMessageTarget; TimerId : PTR ) : BOOLEAN;
   VAR
      running : BOOLEAN;
   BEGIN
      TimersLock.Lock();
      running := Timers.Contains( Target, TimerId );
      TimersLock.Unlock();
      RETURN running;
   END TimerRunning;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE GetTimeoutToFirstElapsed( CurrentTime : CARDINAL ) : CARDINAL;
   VAR
      Timeout : CARDINAL;
   BEGIN
      TimersLock.Lock();
      Timeout := Timers.GetTimeoutToFirstElapsed( CurrentTime );
      TimersLock.Unlock();
      RETURN Timeout;
   END GetTimeoutToFirstElapsed;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE GetFirstElapsed( CurrentTime : CARDINAL; OUT Target : OSALmsg.TPMessageTarget; OUT TimerId : PTR ) : BOOLEAN;
   VAR
      b : BOOLEAN;
      ElapsedOn : CARDINAL;
      PeriodMS : CARDINAL;
      RepeatPTR : PTR;
   BEGIN
      TimersLock.Lock();
      b := Timers.GetFirstElapsed( CurrentTime, TRUE, OUT Target, OUT TimerId, OUT RepeatPTR, OUT PeriodMS, OUT ElapsedOn );
      IF b AND ( RepeatPTR = 1 ) THEN
         Timers.Add( ElapsedOn, Target, TimerId, RepeatPTR, PeriodMS );
      END;
      TimersLock.Unlock();
      RETURN b;
   END GetFirstElapsed;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Invoke( Operation : CARDINAL; CONST Parameters : ARRAY OF PTR ) : PTR;
   BEGIN
      CASE Operation OF
      | OP_JOIN :
         DoJoin( OSALmsg.TPMessageHandler( Parameters[0] ));
      | OP_LEAVE :
         DoLeave( OSALmsg.TPMessageHandler( Parameters[0] ));
      | OP_START_TIMER :
         DoStartTimer( OSALmsg.TPMessageTarget( Parameters[0] ), Parameters[1], CARDINAL( LOPTRLONGWORD( Parameters[2] )), BOOLEAN( LOPTRLONGWORD( Parameters[3] )));
      | OP_STOP_TIMER :
         DoStopTimer( OSALmsg.TPMessageTarget( Parameters[0] ), Parameters[1] );
      END;
      RETURN 0;
   END Invoke;

(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE DoJoin( Handler : OSALmsg.TPMessageHandler );
   BEGIN
      ASSERT( NOT IsJoined( Handler ));

      JoinedLock.Lock();
      Joined.Add( Handler, 0 );
      JoinedLock.Unlock();

      Handler^.OnJoin( OfThread^ );
   END DoJoin;

(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE DoLeave( Handler : OSALmsg.TPMessageHandler );
   BEGIN
      ASSERT( IsJoined( Handler ));

      JoinedLock.Lock();
      Joined.Remove( Handler );
      JoinedLock.Unlock();

      Handler^.OnLeave();
   END DoLeave;

(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE DoStartTimer( Target : OSALmsg.TPMessageTarget; TimerId : PTR; PeriodMS : CARDINAL; Repeat : BOOLEAN );
   VAR
      CurrentTime : CARDINAL;
      Data : PTR;
      RepeatPTR : PTR;
   BEGIN
      CurrentTime := time.UptimeMS();
      IF Repeat THEN
         RepeatPTR := 1;
      ELSE
         RepeatPTR := 0;
      END;
      TimersLock.Lock();
      IF Timers.Get( Target, TimerId, OUT Data ) THEN
         Timers.Remove( Target, TimerId );
      END;
      Timers.Add( CurrentTime, Target, TimerId, RepeatPTR, PeriodMS );
      TimersLock.Unlock();
   END DoStartTimer;

(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE DoStopTimer( Target : OSALmsg.TPMessageTarget; TimerId : PTR );
   VAR
      Data : PTR;
   BEGIN
      TimersLock.Lock();
      Timers.Remove( Target, TimerId );
      TimersLock.Unlock();
   END DoStopTimer;

(*---------------------------------------------------------------------------*)

BEGIN
   OfThread := NIL;
FINALLY
   Dispose();
END CSupport;

(*===========================================================================*)

END msgthreadsupport.