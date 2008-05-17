IMPLEMENTATION MODULE msgthreadsupport;

(*===========================================================================*)

IMPORT
   msghandler;
   
(*===========================================================================*)

TYPE
   TTimerParameter = RECORD
      Timer : PTR;
      Repeat : BOOLEAN;
      Signal : Sync.SIGNAL;
   END;

(*===========================================================================*)

CLASS IMPLEMENTATION CSupport;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( OfThread : OSALmsg.TPMessageQueueThread );
   BEGIN
      SELF.OfThread := OfThread;
   END Init;

   PUBLIC PROCEDURE Dispose();
   BEGIN
      ASSERT( Joined.Empty );
      Joined.Dispose();
      OfThread := NIL;
   END Dispose;
   
(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Join( Recipient : OSALmsg.TPMessageRecipient );
   VAR
      MSG : msghandler.Message;
      Result : Sync.TAsyncResult;
      Signal : Sync.SIGNAL := Sync.CreateSignal( FALSE, L"" );
   BEGIN
      ASSERT( OfThread <> NIL );

      MSG.Source := Recipient;
      MSG.Target := OfThread;
      MSG.Message := msghandler.RawMsgBase() + OSALmsg.RAW_MESSAGE_JOIN;
      MSG[ OSALmsg.MI_PARAMETER ] := Signal;
      
      OfThread^.Message( MSG, OSALmsg.delSynchronousIfInThread, NIL );
      
      Result := Sync.Wait( Signal, Sync.FORSAFETY );
      ASSERT( Result <> Sync.arTimeout );
      
      Sync.DeleteSignal( REF Signal );
   END Join;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Leave( Recipient : OSALmsg.TPMessageRecipient );
   VAR
      MSG : msghandler.Message;
      Result : Sync.TAsyncResult;
      Signal : Sync.SIGNAL := Sync.CreateSignal( FALSE, L"" );
   BEGIN
      ASSERT( OfThread <> NIL );

      MSG.Source := Recipient;
      MSG.Target := OfThread;
      MSG.Message := msghandler.RawMsgBase() + OSALmsg.RAW_MESSAGE_LEAVE;
      MSG[ OSALmsg.MI_PARAMETER ] := Signal;

      OfThread^.Message( MSG, OSALmsg.delSynchronousIfInThread, NIL );

      Result := Sync.Wait( Signal, Sync.FORSAFETY );
      ASSERT( Result <> Sync.arTimeout );
      
      Sync.DeleteSignal( REF Signal );
   END Leave;
   
(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SetTimer( Recipient : OSALmsg.TPMessageRecipient; Timer : PTR; Repeat : BOOLEAN );
   VAR
      MSG : msghandler.Message;
      parameter : POINTER TO TimerParameter;
      Result : Sync.TAsyncResult;
      Signal : Sync.SIGNAL := Sync.CreateSignal( FALSE, L"" );
   BEGIN
      ASSERT( OfThread <> NIL );

      MSG.Source := Recipient;
      MSG.Target := Recipient;
      MSG.Message := msghandler.RawMsgBase() + OSALmsg.RAW_MESSAGE_SETTIMER;

      NEW( parameter );
      parameter^.Timer := Timer;
      parameter^.Repeat := Repeat;
      parameter^.Signal := Signal;

      MSG.Parameter := parameter;
      
      OfThread^.Message( MSG, OSALmsg.delSynchronousIfInThread, NIL );
      
      Result := Sync.Wait( Signal, Sync.FORSAFETY );
      ASSERT( Result <> Sync.arTimeout );
      
      Sync.DeleteSignal( REF Signal );
   END SetTimer;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ResetTimer( Recipient : OSALmsg.TPMessageRecipient; Timer : PTR );
   VAR
      MSG : msghandler.Message;
      parameter : POINTER TO TimerParameter;
      Result : Sync.TAsyncResult;
      Signal : Sync.SIGNAL := Sync.CreateSignal( FALSE, L"" );
   BEGIN
      ASSERT( OfThread <> NIL );

      MSG.Source := Recipient;
      MSG.Target := OfThread;
      MSG.Message := msghandler.RawMsgBase() + OSALmsg.RAW_MESSAGE_RESETTIMER;

      NEW( parameter );
      parameter^.Timer := Timer;
      parameter^.Signal := Signal;

      MSG.Parameter := parameter;

      OfThread^.Message( MSG, OSALmsg.delSynchronousIfInThread, NIL );

      Result := Sync.Wait( Signal, Sync.FORSAFETY );
      ASSERT( Result <> Sync.arTimeout );
      
      Sync.DeleteSignal( REF Signal );
   END ResetTimer;
   
(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE HandleSupportMessage( CONST Message : OSALmsg.IMessage ) : BOOLEAN; // if it is not join logic message it returns FALSE
   VAR
      message : CARDINAL := Message.Message;
      parameter : 
   BEGIN
      CASE message OF
      //-----
      | msghandler.RAW_MSG_BASE + OSALmsg.RAW_MESSAGE_JOIN :
         ASSERT( NOT IsJoined( OSALmsg.TPMessageRecipient( Message.Source )));

         Lock.Lock();
         Joined.Add( Message.Source, 0 );
         Lock.Unlock();

         OSALmsg.TPMessageRecipient( Message.Source )^.OnJoin( OfThread );
         Sync.Signal( Sync.SIGNAL( Message[ OSALmsg.MI_PARAMETER ] ));

      //-----
      | msghandler.RAW_MSG_BASE + OSALmsg.RAW_MESSAGE_LEAVE :
         ASSERT( IsJoined( OSALmsg.TPMessageRecipient( Message.Source )));

         Lock.Lock();
         Joined.Remove( Message.Source );
         Lock.Unlock();

         OSALmsg.TPMessageRecipient( Message.Source )^.OnLeave();
         Sync.Signal( Sync.SIGNAL( Message[ OSALmsg.MI_PARAMETER ] ));

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
      Lock.Lock();
      joined := Joined.Contains( Recipient );
      Lock.Unlock();
      RETURN joined;
   END IsJoined;

(*---------------------------------------------------------------------------*)

BEGIN
   OfThread := NIL;
FINALLY
   Dispose();
END CSupport;

(*===========================================================================*)

END msgthreadsupport.