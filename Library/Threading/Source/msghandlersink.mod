IMPLEMENTATION MODULE msghandlersink;

(*===========================================================================*)

CLASS IMPLEMENTATION SinkMessageHandler;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnMessage( CONST MSG : msghandler.IMessage; OUT Result : PTR ) : BOOLEAN;
   BEGIN
      IF MessageSink = NIL THEN
         RETURN FALSE;
      ELSE
         RETURN MessageSink^.OnMessage( MSG, OUT Result );
      END;
   END OnMessage;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnTimer( TimerId : PTR );
   BEGIN
      IF TimerSink <> NIL THEN
         TimerSink^.OnTimer( TimerId );
      END;
   END OnTimer;

(*---------------------------------------------------------------------------*)

BEGIN
   MessageSink := NIL;
   TimerSink := NIL;
END SinkMessageHandler;

(*===========================================================================*)

END msghandlersink.
