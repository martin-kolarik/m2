IMPLEMENTATION MODULE msgthreadsupport;

(*===========================================================================*)

IMPORT
   msghandler,
   time;
   
(*===========================================================================*)

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
   VAR
      MSG : msghandler.Message;
      Result : Sync.TAsyncResult;
      Signal : Sync.SIGNAL;
   BEGIN
      ASSERT( OfThread <> NIL );

      IF OfThread^.SelfContext OR NOT CallOnJoinInThread THEN
         DoJoin( Handler );
      ELSE
         Signal := Sync.CreateSignal( FALSE, L"" );

         MSG.Source := Handler;
         MSG.Target := OfThread;
         MSG.Message := msghandler.RAW_MSG_BASE + OSALmsg.RAW_MESSAGE_JOIN;
         MSG[ OSALmsg.MI_PARAMETER ] := Signal;

         OfThread^.Message( MSG, OSALmsg.delAsynchronous, NIL );
         
         Result := Sync.Wait( Signal, Sync.FORSAFETY );
         ASSERT( Result <> Sync.arTimeout );
         Sync.DeleteSignal( REF Signal );
      END;
   END Join;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Leave( Handler : OSALmsg.TPMessageHandler; CallOnLeaveInThread : BOOLEAN );
   VAR
      MSG : msghandler.Message;
      Result : Sync.TAsyncResult;
      Signal : Sync.SIGNAL;
   BEGIN
      ASSERT( OfThread <> NIL );

      IF OfThread^.SelfContext OR NOT CallOnLeaveInThread THEN
         DoLeave( Handler );
      ELSE
         Signal := Sync.CreateSignal( FALSE, L"" );

         MSG.Source := Handler;
         MSG.Target := OfThread;
         MSG.Message := msghandler.RAW_MSG_BASE + OSALmsg.RAW_MESSAGE_LEAVE;
         MSG[ OSALmsg.MI_PARAMETER ] := Signal;

         OfThread^.Message( MSG, OSALmsg.delAsynchronous, NIL );

         Result := Sync.Wait( Signal, Sync.FORSAFETY );
         ASSERT( Result <> Sync.arTimeout );
         Sync.DeleteSignal( REF Signal );
      END;
   END Leave;
   
(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE StartTimer( Target : OSALmsg.TPMessageTarget; TimerId : PTR; PeriodMS : CARDINAL; Repeat : BOOLEAN );
   VAR
      MSG : msghandler.Message;
      parameter : TPTimerParameter;
      Result : Sync.TAsyncResult;
      Signal : Sync.SIGNAL;
   BEGIN
      ASSERT( OfThread <> NIL );

      IF OfThread^.SelfContext THEN
         DoStartTimer( Target, TimerId, PeriodMS, Repeat );
      ELSE
         Signal := Sync.CreateSignal( FALSE, L"" );

         NEW( parameter );
         parameter^.Timer := TimerId;
         parameter^.PeriodMS := PeriodMS;
         parameter^.Repeat := Repeat;
         parameter^.Signal := Signal;

         MSG.Source := Target;
         MSG.Target := OfThread;
         MSG.Message := msghandler.RAW_MSG_BASE + OSALmsg.RAW_MESSAGE_SETTIMER;
         MSG.Parameter := parameter;
         
         OfThread^.Message( MSG, OSALmsg.delAsynchronous, NIL );
         
         Result := Sync.Wait( Signal, Sync.FORSAFETY );
         ASSERT( Result <> Sync.arTimeout );
         
         DISPOSE( parameter );
         Sync.DeleteSignal( REF Signal );
      END;
   END StartTimer;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE StopTimer( Target : OSALmsg.TPMessageTarget; TimerId : PTR );
   VAR
      MSG : msghandler.Message;
      parameter : TPTimerParameter;
      Result : Sync.TAsyncResult;
      Signal : Sync.SIGNAL;
   BEGIN
      ASSERT( OfThread <> NIL );

      IF OfThread^.SelfContext THEN
         DoStopTimer( Target, TimerId );
      ELSE
         Signal := Sync.CreateSignal( FALSE, L"" );

         NEW( parameter );
         parameter^.Timer := TimerId;
         parameter^.Signal := Signal;

         MSG.Source := Target;
         MSG.Target := OfThread;
         MSG.Message := msghandler.RAW_MSG_BASE + OSALmsg.RAW_MESSAGE_RESETTIMER;
         MSG.Parameter := parameter;
         
         OfThread^.Message( MSG, OSALmsg.delAsynchronous, NIL );
         
         Result := Sync.Wait( Signal, Sync.FORSAFETY );
         ASSERT( Result <> Sync.arTimeout );

         DISPOSE( parameter );
         Sync.DeleteSignal( REF Signal );
      END;
   END StopTimer;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE HandleSupportMessage( CONST Message : OSALmsg.IMessage ) : BOOLEAN; // if it is not join logic message it returns FALSE
   VAR
      message : CARDINAL := Message.Message;
      parameter : TPTimerParameter;
   BEGIN
      CASE message OF
      //-----
      | msghandler.RAW_MSG_BASE + OSALmsg.RAW_MESSAGE_JOIN :
         DoJoin( OSALmsg.TPMessageHandler( Message.Source ));
         Sync.Signal( Sync.SIGNAL( Message[ OSALmsg.MI_PARAMETER ] ));

      //-----
      | msghandler.RAW_MSG_BASE + OSALmsg.RAW_MESSAGE_LEAVE :
         DoLeave( OSALmsg.TPMessageHandler( Message.Source ));
         Sync.Signal( Sync.SIGNAL( Message[ OSALmsg.MI_PARAMETER ] ));

      //-----
      | msghandler.RAW_MSG_BASE + OSALmsg.RAW_MESSAGE_SETTIMER :
         parameter := TPTimerParameter( Message.Parameter );
         DoStartTimer( OSALmsg.TPMessageTarget( Message.Source ), parameter^.Timer, parameter^.PeriodMS, parameter^.Repeat );
         Sync.Signal( parameter^.Signal );

      //-----
      | msghandler.RAW_MSG_BASE + OSALmsg.RAW_MESSAGE_RESETTIMER :
         parameter := TPTimerParameter( Message.Parameter );
         DoStopTimer( OSALmsg.TPMessageTarget( Message.Source ), parameter^.Timer );
         Sync.Signal( parameter^.Signal );

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