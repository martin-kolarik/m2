IMPLEMENTATION MODULE SCmsg;

(*================================================================================*)

FROM Debug IMPORT
   AssertionW;

IMPORT
   msghandler,
   msgqueuethread,
   SCmsgqueuethread,
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
  ASSERTLOG( Handlers.Empty );
END CChecker;
#endif

TYPE
   TPSCMessageQueueThread = POINTER TO SCmsgqueuethread.SCMessageQueueThread;

(*================================================================================*)

PROCEDURE HandleToTarget( CONST Handle : PTR; OUT Target : msghandler.TPIMessageTarget ) : BOOLEAN;
BEGIN
   Target := msghandler.TPIMessageTarget( Handle );
   RETURN TRUE;
END HandleToTarget;

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

   PUBLIC VIRTUAL PROPERTY SCMessage.Target GET : msghandler.TPIMessageTarget;
   BEGIN
      RETURN target;
   END SCMessage.Target;
  
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY SCMessage.Target SET( Value : msghandler.TPIMessageTarget );
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

   PUBLIC VIRTUAL PROCEDURE Release();
   VAR
      Message : POINTER TO SCMessage := ADR( SELF );
   BEGIN
      DISPOSE( Message );
   END Release;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Send( Target : OSALmsg.TPMessageTarget; Delivery : OSALmsg.TDelivery; Result : PPTR ) : BOOLEAN;
   BEGIN
      target := Target;
      RETURN target^.Message( SELF, Delivery, Result );
   END Send;

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

(*--------------------------------------------------------------------------------*)

PROCEDURE FromMessage( Source : ADDRESS; Message : CARDINAL; Parameter : PTR ) : SCMessage;
VAR
   msg : SCMessage;
BEGIN
   msg.Source := Source;
   msg.Message := Message;
   msg.Parameter := Parameter;
   RETURN msg;
END FromMessage;

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
         JoinMessageThread( SCmsgqueuethread.SCGlobalMessageQueueThread()^, TRUE );
      END;
   END SCMessageHandler.Init;
  
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   BEGIN
      LeaveMessageThread( TRUE );
   END Dispose;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Message( CONST MSG : OSALmsg.IMessage; Delivery : OSALmsg.TDelivery; Result : PPTR ) : BOOLEAN;
   VAR
      i : CARDINAL;
      message : SCMessage;
      msg : OSALmsg.TPMessage;
      LResult : PTR;
   BEGIN
      IF MSG.Target = NIL THEN // no target, set self as it
         FOR i := 0 TO MIN2( MSG.ParameterCount, message.ParameterCount )-1 DO
            message[i] := MSG[i];
         END; // FOR
         message.Target := ADR( SELF );
         msg := ADR( message );
      ELSE
         msg := OSALmsg.TPMessage( ADR( MSG ));
      END;

      IF ( Delivery = OSALmsg.delSynchronous ) OR ( Delivery = OSALmsg.delSynchronousIfInThread ) AND SelfContext THEN
      
         IF msg^.Message = msghandler.MSG_ON_TIMER THEN
            OnTimer( msg^.Parameter );
         ELSE
            IF Result = NIL THEN
               Result := ADR( LResult );
            END;
            RETURN OnMessage( msg^, OUT Result^ );
         END;
         
      ELSIF joinedTo <> NIL THEN // deffer message
         joinedTo^.Message( msg^, OSALmsg.delAsynchronous, Result );

      ELSE
         ASSERT( FALSE );
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

   PUBLIC VIRTUAL PROCEDURE StartTimer( Timer : PTR; PeriodMS : CARDINAL; Repeat : BOOLEAN );
   BEGIN
      IF joinedTo = NIL THEN
         ASSERT( FALSE );
      ELSE
         TPSCMessageQueueThread( joinedTo )^.StartTimer( SELF, Timer, PeriodMS, Repeat );
      END;
   END StartTimer;
  
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE TimerRunning( Timer : PTR ) : BOOLEAN;
   BEGIN
      IF joinedTo = NIL THEN
         ASSERTLOG( FALSE );
         RETURN FALSE;
      ELSE
         RETURN TPSCMessageQueueThread( joinedTo )^.TimerRunning( SELF, Timer );
      END;
   END TimerRunning;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE StopTimer( Timer : PTR );
   BEGIN
      IF joinedTo = NIL THEN
         ASSERTLOG( FALSE );
      ELSE
         TPSCMessageQueueThread( joinedTo )^.StopTimer( SELF, Timer );
      END;
   END StopTimer;
  
(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnTimer( Timer : PTR );
   BEGIN
   END OnTimer;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnJoin( CONST JoinTo : OSALmsg.IMessageQueueThread );
   BEGIN
      IF joinedTo = NIL THEN
         joinedTo := OSALmsg.TPMessageQueueThread( ADR( JoinTo ));
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

   PUBLIC VIRTUAL PROCEDURE JoinMessageThread( CONST JoinTo : OSALmsg.IMessageQueueThread; CallOnJoinInThread : BOOLEAN );
   BEGIN
      JoinTo.Join( ADR( SELF ), CallOnJoinInThread );
   END JoinMessageThread;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE LeaveMessageThread( CallOnLeaveInThread : BOOLEAN );
   BEGIN
      IF joinedTo <> NIL THEN
         joinedTo^.Leave( ADR( SELF ), CallOnLeaveInThread );
      END;
   END LeaveMessageThread;

(*--------------------------------------------------------------------------------*)

BEGIN
   joinedTo := NIL;
END SCMessageHandler;

(*================================================================================*)

END SCmsg.