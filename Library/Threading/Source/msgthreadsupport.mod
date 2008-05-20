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

   PUBLIC PROCEDURE Join( Recipient : OSALmsg.TPMessageRecipient; CallOnJoinInThread : BOOLEAN );
   VAR
      MSG : msghandler.Message;
      Result : Sync.TAsyncResult;
      Signal : Sync.SIGNAL;
   BEGIN
      ASSERT( OfThread <> NIL );

      IF OfThread^.SelfContext OR NOT CallOnJoinInThread THEN
         DoJoin( Recipient );
      ELSE
         Signal := Sync.CreateSignal( FALSE, L"" );

         MSG.Source := Recipient;
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

   PUBLIC PROCEDURE Leave( Recipient : OSALmsg.TPMessageRecipient; CallOnLeaveInThread : BOOLEAN );
   VAR
      MSG : msghandler.Message;
      Result : Sync.TAsyncResult;
      Signal : Sync.SIGNAL;
   BEGIN
      ASSERT( OfThread <> NIL );

      IF OfThread^.SelfContext OR NOT CallOnLeaveInThread THEN
         DoLeave( Recipient );
      ELSE
         Signal := Sync.CreateSignal( FALSE, L"" );

         MSG.Source := Recipient;
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

   PUBLIC PROCEDURE StartTimer( Recipient : OSALmsg.TPMessageRecipient; TimerId : PTR; PeriodMS : CARDINAL; Repeat : BOOLEAN );
   VAR
      MSG : msghandler.Message;
      parameter : TPTimerParameter;
      Result : Sync.TAsyncResult;
      Signal : Sync.SIGNAL;
   BEGIN
      ASSERT( OfThread <> NIL );

      IF OfThread^.SelfContext THEN
         DoStartTimer( Recipient, TimerId, PeriodMS, Repeat );
      ELSE
         Signal := Sync.CreateSignal( FALSE, L"" );

         NEW( parameter );
         parameter^.Timer := TimerId;
         parameter^.PeriodMS := PeriodMS;
         parameter^.Repeat := Repeat;
         parameter^.Signal := Signal;

         MSG.Source := Recipient;
         MSG.Target := OfThread;
         MSG.Message := msghandler.RAW_MSG_BASE + OSALmsg.RAW_MESSAGE_SETTIMER;
         MSG.Parameter := parameter;
         
         OfThread^.Message( MSG, OSALmsg.delAsynchronous, NIL );
         
         Result := Sync.Wait( Signal, Sync.FORSAFETY );
         ASSERT( Result <> Sync.arTimeout );
         Sync.DeleteSignal( REF Signal );
      END;
   END StartTimer;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE StopTimer( Recipient : OSALmsg.TPMessageRecipient; TimerId : PTR );
   VAR
      MSG : msghandler.Message;
      parameter : TPTimerParameter;
      Result : Sync.TAsyncResult;
      Signal : Sync.SIGNAL;
   BEGIN
      ASSERT( OfThread <> NIL );

      IF OfThread^.SelfContext THEN
         DoStopTimer( Recipient, TimerId );
      ELSE
         Signal := Sync.CreateSignal( FALSE, L"" );

         NEW( parameter );
         parameter^.Timer := TimerId;
         parameter^.Signal := Signal;

         MSG.Source := Recipient;
         MSG.Target := OfThread;
         MSG.Message := msghandler.RAW_MSG_BASE + OSALmsg.RAW_MESSAGE_RESETTIMER;
         MSG.Parameter := parameter;
         
         OfThread^.Message( MSG, OSALmsg.delAsynchronous, NIL );
         
         Result := Sync.Wait( Signal, Sync.FORSAFETY );
         ASSERT( Result <> Sync.arTimeout );
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
         DoJoin( OSALmsg.TPMessageRecipient( Message.Source ));
         Sync.Signal( Sync.SIGNAL( Message[ OSALmsg.MI_PARAMETER ] ));

      //-----
      | msghandler.RAW_MSG_BASE + OSALmsg.RAW_MESSAGE_LEAVE :
         DoLeave( OSALmsg.TPMessageRecipient( Message.Source ));
         Sync.Signal( Sync.SIGNAL( Message[ OSALmsg.MI_PARAMETER ] ));

      //-----
      | msghandler.RAW_MSG_BASE + OSALmsg.RAW_MESSAGE_SETTIMER :
         parameter := TPTimerParameter( Message.Parameter );
         DoStartTimer( OSALmsg.TPMessageRecipient( Message.Source ), parameter^.Timer, parameter^.PeriodMS, parameter^.Repeat );
         Sync.Signal( parameter^.Signal );
         DISPOSE( parameter );

      //-----
      | msghandler.RAW_MSG_BASE + OSALmsg.RAW_MESSAGE_RESETTIMER :
         parameter := TPTimerParameter( Message.Parameter );
         DoStopTimer( OSALmsg.TPMessageRecipient( Message.Source ), parameter^.Timer );
         Sync.Signal( parameter^.Signal );
         DISPOSE( parameter );

      ELSE
         RETURN FALSE;
      END;
      RETURN TRUE;
   END HandleSupportMessage;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE IsJoined( Recipient : OSALmsg.TPMessageRecipient ) : BOOLEAN;
   VAR
      joined : BOOLEAN;
   BEGIN
      JoinedLock.Lock();
      joined := Joined.Contains( Recipient );
      JoinedLock.Unlock();
      RETURN joined;
   END IsJoined;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE TimerRunning( Recipient : OSALmsg.TPMessageRecipient; TimerId : PTR ) : BOOLEAN;
   VAR
      running : BOOLEAN;
   BEGIN
      TimersLock.Lock();
      running := Timers.Contains( Recipient, TimerId );
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

   PUBLIC PROCEDURE GetFirstElapsed( CurrentTime : CARDINAL; OUT Recipient : OSALmsg.TPMessageRecipient; OUT TimerId : PTR ) : BOOLEAN;
   VAR
      b : BOOLEAN;
      ElapsedOn : CARDINAL;
      PeriodMS : CARDINAL;
      RepeatPTR : PTR;
   BEGIN
      TimersLock.Lock();
      b := Timers.GetFirstElapsed( CurrentTime, TRUE, OUT Recipient, OUT TimerId, OUT RepeatPTR, OUT PeriodMS, OUT ElapsedOn );
      IF b AND ( RepeatPTR = 1 ) THEN
         Timers.Add( ElapsedOn, Recipient, TimerId, RepeatPTR, PeriodMS );
      END;
      TimersLock.Unlock();
      RETURN b;
   END GetFirstElapsed;

(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE DoJoin( Recipient : OSALmsg.TPMessageRecipient );
   BEGIN
      ASSERT( NOT IsJoined( Recipient ));

      JoinedLock.Lock();
      Joined.Add( Recipient, 0 );
      JoinedLock.Unlock();

      Recipient^.OnJoin( OfThread );
   END DoJoin;

(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE DoLeave( Recipient : OSALmsg.TPMessageRecipient );
   BEGIN
      ASSERT( IsJoined( Recipient ));

      JoinedLock.Lock();
      Joined.Remove( Recipient );
      JoinedLock.Unlock();

      Recipient^.OnLeave();
   END DoLeave;

(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE DoStartTimer( Recipient : OSALmsg.TPMessageRecipient; TimerId : PTR; PeriodMS : CARDINAL; Repeat : BOOLEAN );
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
      IF Timers.Get( Recipient, TimerId, OUT Data ) THEN
         Timers.Remove( Recipient, TimerId );
      END;
      Timers.Add( CurrentTime, Recipient, TimerId, RepeatPTR, PeriodMS );
      TimersLock.Unlock();
   END DoStartTimer;

(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE DoStopTimer( Recipient : OSALmsg.TPMessageRecipient; TimerId : PTR );
   VAR
      Data : PTR;
   BEGIN
      TimersLock.Lock();
      Timers.Remove( Recipient, TimerId );
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