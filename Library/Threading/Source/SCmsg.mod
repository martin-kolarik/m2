IMPLEMENTATION MODULE SCmsg;

(*================================================================================*)

FROM Storage IMPORT
  ALLOCATE;

IMPORT
  msghandler,
  msgqueuethread,
  threadpool;

(*================================================================================*)

#if DEBUG #then
IMPORT
  lists;
 
CLASS CChecker;
END CChecker;

VAR
  Handlers : lists.CPtrList;
  Checked : CChecker;

CLASS IMPLEMENTATION CChecker;
BEGIN FINALLY
  ASSERT( Handlers.Empty );
END CChecker;
#endif

(*================================================================================*)

TYPE
   TTimerParameter = RECORD
      Timer : PTR;
      PeriodMS : CARDINAL;
      Repeat : BOOLEAN;
      Signal : Sync.SIGNAL;
   END; // RECORD
   TPTimerParameter = POINTER TO TTimerParameter;

(*--------------------------------------------------------------------------------*)

PROCEDURE HandleToRecipient( CONST Handle : PTR; OUT Handler : OSALmsg.TPMessageRecipient ) : BOOLEAN;
BEGIN
   Handler := OSALmsg.TPMessageRecipient( Handle );
   RETURN TRUE;
END HandleToRecipient;

(*================================================================================*)

CLASS IMPLEMENTATION SCMessage;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY SCMessage.Source GET : ADDRESS;
   BEGIN
      RETURN source;
   END SCMessage.Source;
  
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY SCMessage.Source SET( Value : ADDRESS );
   BEGIN
      source := Value;
   END SCMessage.Source;
  
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY SCMessage.Target GET : OSALmsg.TPMessageRecipient;
   BEGIN
      RETURN target;
   END SCMessage.Target;
  
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY SCMessage.Target SET( Value : OSALmsg.TPMessageRecipient );
   BEGIN
      target := Value;
   END SCMessage.Target;
  
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY SCMessage.Message GET : CARDINAL;
   BEGIN
      RETURN message;
   END SCMessage.Message;
  
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY SCMessage.Message SET( Value : CARDINAL );
   BEGIN
      message := Value;
   END SCMessage.Message;
  
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY SCMessage.Parameter GET : PTR;
   BEGIN
      RETURN param1;
   END SCMessage.Parameter;
  
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY SCMessage.Parameter SET( Value : PTR );
   BEGIN
      param1 := Value;
   END SCMessage.Parameter;
  
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL READONLY PROPERTY SCMessage.ParameterCount GET : CARDINAL;
   BEGIN
      RETURN 7;
   END SCMessage.ParameterCount;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL INDEX SCMessage GET( ParameterIndex : CARDINAL ) : PTR;
   BEGIN
      CASE ParameterIndex OF
      | OSALmsg.MI_SOURCE : RETURN source;
      | OSALmsg.MI_TARGET : RETURN target;
      | OSALmsg.MI_MESSAGE : RETURN message;
      | MI_PARAM_1 : RETURN param1;
      | MI_PARAM_2 : RETURN param2;
      | MI_PARAM_3 : RETURN param3;
      | MI_PARAM_4 : RETURN param4;
      ELSE
         ASSERT( FALSE );
         RETURN 0;
      END;
   END SCMessage;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL INDEX SCMessage SET( ParameterIndex : CARDINAL; Value : PTR );
   BEGIN
      CASE ParameterIndex OF
      | OSALmsg.MI_SOURCE : source := Value;
      | OSALmsg.MI_TARGET : target := Value;
      | OSALmsg.MI_MESSAGE : message := CARDINAL( LOPTRLONGWORD( Value ));
      | MI_PARAM_1 : param1 := Value;
      | MI_PARAM_2 : param2 := Value;
      | MI_PARAM_3 : param3 := Value;
      | MI_PARAM_4 : param4 := Value;
      END;
   END SCMessage;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Clone() : POINTER TO OSALmsg.IMessage;
   VAR
      Message : POINTER TO SCMessage;
   BEGIN
      NEW( Message );
      Message^ := SELF;
      RETURN Message;
   END Clone;

(*--------------------------------------------------------------------------------*)

   PUBLIC OPERATOR :=( CONST MSG : SCMessage );
   BEGIN
      source := MSG.source;
      target := MSG.target;
      message := MSG.message;
      param1 := MSG.param1;
      param2 := MSG.param2;
      param3 := MSG.param3;
      param4 := MSG.param4;
   END :=;

(*--------------------------------------------------------------------------------*)

BEGIN
   source := NIL;
   target := NIL;
   message := 0;
   param1 := 0;
   param2 := 0;
   param3 := 0;
   param4 := 0;
END SCMessage;

(*================================================================================*)

CLASS IMPLEMENTATION SCMessageHandler;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY JoinedTo GET : OSALmsg.TPMessageQueueThread;
   BEGIN
      RETURN joinedTo;
   END JoinedTo;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL READONLY PROPERTY SCMessageHandler.SelfContext GET : BOOLEAN;
   BEGIN
      RETURN ( joinedTo <> NIL ) AND joinedTo^.SelfContext;
   END SCMessageHandler.SelfContext;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL READONLY PROPERTY SCMessageHandler.Handle GET : PTR;
   BEGIN
      RETURN ADR( SELF );
   END SCMessageHandler.Handle;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SCMessageHandler.Init( AutomaticJoin : BOOLEAN );
   BEGIN
      IF AutomaticJoin THEN
         JoinMessageThread( NIL );
      END;
   END SCMessageHandler.Init;
  
(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Dispose();
   BEGIN
      LeaveMessageThread();
   END Dispose;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Message( CONST MSG : OSALmsg.IMessage; Delivery : OSALmsg.TDelivery; Result : PPTR ) : BOOLEAN;
   VAR
      b : BOOLEAN;
      LResult : PTR;
      parameter : TPTimerParameter;
      PoolHandle : threadpoolsink.TPoolHandle;
   BEGIN
      OSALmsg.TPMessage( ADR( MSG ))^.Target := ADR( SELF );
      IF ( Delivery = OSALmsg.delSynchronous ) OR ( Delivery = OSALmsg.delSynchronousIfInThread ) AND SelfContext THEN
      
         CASE MSG.Message OF
         //-----
         | msghandler.RAW_MSG_BASE + OSALmsg.RAW_MESSAGE_SETTIMER :
            parameter := TPTimerParameter( MSG.Parameter );
            IF Timers.Get( parameter^.Timer, OUT PoolHandle ) THEN
               Timers.Remove( parameter^.Timer );
               threadpool.pool()^.Abort( REF PoolHandle );
            END;
            b := threadpool.pool()^.WaitTimeout( ADR( PoolSink ), parameter^.Timer, parameter^.PeriodMS, NOT parameter^.Repeat, FALSE, OUT PoolHandle );
            ASSERT( b );
            Timers.Add( parameter^.Timer, PoolHandle );
            Sync.Signal( parameter^.Signal );
            DISPOSE( parameter );

         //-----
         | msghandler.RAW_MSG_BASE + OSALmsg.RAW_MESSAGE_RESETTIMER :
            parameter := TPTimerParameter( MSG.Parameter );
            IF Timers.Get( parameter^.Timer, OUT PoolHandle ) THEN
               Timers.Remove( parameter^.Timer );
               threadpool.pool()^.Abort( REF PoolHandle );
            END;
            Sync.Signal( parameter^.Signal );
            DISPOSE( parameter );

         //-----
         | msghandler.RAW_MSG_BASE + OSALmsg.RAW_MESSAGE_ONTIMER :
            IF Timers.Contains( MSG.Parameter ) THEN
               OnTimer( MSG.Parameter );
            END;

         //-----
         ELSE
            IF Result = NIL THEN
               Result := ADR( LResult );
            END;
            RETURN OnMessage( MSG, OUT Result^ );
         END; // CASE
         
      ELSE // deffer message
         ASSERT( joinedTo <> NIL );
         joinedTo^.Message( MSG, OSALmsg.delAsynchronous, Result );
      END;

      IF Result <> NIL THEN
         Result^ := 0;
      END;
      RETURN TRUE;
   END Message;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnMessage( CONST MSG : OSALmsg.IMessage; OUT Result : PTR ) : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END SCMessageHandler.OnMessage;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE StartTimer( Timer : PTR; PeriodMS : CARDINAL; Repeat : BOOLEAN );
   VAR
      MSG : msghandler.Message;
      parameter : POINTER TO TTimerParameter;
      Result : Sync.TAsyncResult;
      SelfContext : BOOLEAN := SELF.SelfContext;
      Signal : Sync.SIGNAL;
   BEGIN
      ASSERT( joinedTo <> NIL );
      IF SelfContext THEN
         Signal := NIL;
      ELSE
         Signal := Sync.CreateSignal( FALSE, L"" );
      END;
 
      NEW( parameter );
      parameter^.Timer := Timer;
      parameter^.PeriodMS := PeriodMS;
      parameter^.Repeat := Repeat;
      parameter^.Signal := Signal;

      MSG.Source := ADR( SELF );
      MSG.Target := ADR( SELF );
      MSG.Message := msghandler.RAW_MSG_BASE + OSALmsg.RAW_MESSAGE_SETTIMER;
      MSG.Parameter := parameter;
      
      Message( MSG, OSALmsg.delSynchronousIfInThread, NIL );
      
      Result := Sync.Wait( Signal, Sync.FORSAFETY );
      ASSERT( Result <> Sync.arTimeout );
      Sync.DeleteSignal( REF Signal );
   END StartTimer;
  
(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE TimerRunning( Timer : PTR ) : BOOLEAN;
   BEGIN
      RETURN Timers.Contains( Timer );
   END TimerRunning;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE StopTimer( Timer : PTR );
   VAR
      MSG : msghandler.Message;
      parameter : POINTER TO TTimerParameter;
      Result : Sync.TAsyncResult;
      SelfContext : BOOLEAN := SELF.SelfContext;
      Signal : Sync.SIGNAL;
   BEGIN
      ASSERT( joinedTo <> NIL );
      IF SelfContext THEN
         Signal := Sync.CreateSignal( FALSE, L"" );
      ELSE  
         Signal := NIL;
      END;
 
      NEW( parameter );
      parameter^.Timer := Timer;
      parameter^.Signal := Signal;

      MSG.Source := ADR( SELF );
      MSG.Target := ADR( SELF );
      MSG.Message := msghandler.RAW_MSG_BASE + OSALmsg.RAW_MESSAGE_RESETTIMER;
      MSG.Parameter := parameter;
      
      Message( MSG, OSALmsg.delSynchronousIfInThread, NIL );
      
      Result := Sync.Wait( Signal, Sync.FORSAFETY );
      ASSERT( Result <> Sync.arTimeout );
      Sync.DeleteSignal( REF Signal );
   END StopTimer;
  
(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnTimer( Timer : PTR );
   BEGIN
   END OnTimer;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnJoin( JoinTo : OSALmsg.TPMessageQueueThread );
   BEGIN
      IF joinedTo = NIL THEN
         joinedTo := JoinTo;
         #if DEBUG #then
            Handlers.Add( ADR( SELF ), 0 );
         #endif
      END;
   END OnJoin;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnLeave();
   BEGIN
      IF joinedTo <> NIL THEN
         joinedTo := NIL;
         #if DEBUG #then
            Handlers.Remove( ADR( SELF ));
         #endif
      END;
   END OnLeave;
  
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE JoinMessageThread( JoinTo : OSALmsg.TPMessageQueueThread );
   BEGIN
      IF JoinTo = NIL THEN
         JoinTo := msgqueuethread.global();
      END;
      JoinTo^.Join( ADR( SELF ));
   END JoinMessageThread;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE LeaveMessageThread();
   BEGIN
      IF joinedTo <> NIL THEN
         joinedTo^.Leave( ADR( SELF ));
      END;
   END LeaveMessageThread;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnTimeout( Result : Sync.TAsyncResult; PoolHandle : threadpoolsink.TPoolHandle; UserId : PTR );
   VAR
      MSG : msghandler.Message;
   BEGIN
      MSG.Source := ADR( SELF );
      MSG.Target := ADR( SELF );
      MSG.Message := msghandler.RAW_MSG_BASE + OSALmsg.RAW_MESSAGE_ONTIMER;
      MSG.Parameter := UserId;
      Message( MSG, OSALmsg.delAsynchronous, NIL ); // we are in pool thread here
   END OnTimeout;

(*--------------------------------------------------------------------------------*)

BEGIN
   joinedTo := NIL;
   PoolSink.TimeoutSink := ADR( SELF );
FINALLY
   Dispose();
END SCMessageHandler;

(*================================================================================*)

END SCmsg.