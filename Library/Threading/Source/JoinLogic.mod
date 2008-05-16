IMPLEMENTATION MODULE JoinLogic;

(*===========================================================================*)

IMPORT
   msghandler;
   
(*===========================================================================*)

CLASS IMPLEMENTATION CJoinLogic;

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

   PUBLIC PROCEDURE HandleJoinLogicMessage( CONST Message : OSALmsg.IMessage ) : BOOLEAN; // if it is not join logic message it returns FALSE
   VAR
      message : CARDINAL := Message.Message;
   BEGIN
      IF message = msghandler.RawMsgBase() + OSALmsg.RAW_MESSAGE_JOIN THEN
         ASSERT( NOT IsJoined( OSALmsg.TPMessageRecipient( Message.Source )));

         Lock.Lock();
         Joined.Add( Message.Source, 0 );
         Lock.Unlock();

         OSALmsg.TPMessageRecipient( Message.Source )^.OnJoin( OfThread );
         Sync.Signal( Sync.SIGNAL( Message[ OSALmsg.MI_PARAMETER ] ));

      ELSIF message = msghandler.RawMsgBase() + OSALmsg.RAW_MESSAGE_LEAVE THEN
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
   END HandleJoinLogicMessage;

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
END CJoinLogic;

(*===========================================================================*)

END JoinLogic.