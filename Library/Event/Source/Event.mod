IMPLEMENTATION MODULE Event;

FROM Debug IMPORT
   AssertionW;

(*================================================================================*)

CLASS IMPLEMENTATION AEvent;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Empty GET : BOOLEAN;
   BEGIN
      RETURN _Listeners.Empty;
   END Empty;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY SinkType GET : Rtti.CLASSTYPE;
   BEGIN
      RETURN _SinkType;
   END SinkType;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY SinkType SET( Value : Rtti.CLASSTYPE );
   BEGIN
      IF Empty THEN
         _SinkType := Value;
      ELSE
         ASSERTLOG( FALSE, L"Unable to change SinkType when listeners exist" );
      END;
   END SinkType;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Subscribe( Listener : ADDRESS );
   BEGIN
      _Listeners.Add( Listener, 0 );
   END Subscribe;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Unsubscribe( Listener : ADDRESS );
   BEGIN
      _Listeners.Remove( Listener );
   END Unsubscribe;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   BEGIN
      UnsubscribeAll();
   END Dispose;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL FINALLY AEvent();
   BEGIN
      Dispose();
   END AEvent;

(*--------------------------------------------------------------------------------*)

   INTERNAL PROCEDURE UnsubscribeAll();
   BEGIN
      _Listeners.Dispose();
   END UnsubscribeAll;

(*--------------------------------------------------------------------------------*)

   INTERNAL PROCEDURE Reset();
   BEGIN
      _Listeners.Reset();
   END Reset;

(*--------------------------------------------------------------------------------*)

   INTERNAL PROCEDURE MoveNext() : BOOLEAN;
   BEGIN
      RETURN _Listeners.MoveNext();
   END MoveNext;

(*--------------------------------------------------------------------------------*)

   INTERNAL PROPERTY Listener GET : ADDRESS;
   BEGIN
      RETURN _Listeners.Current;
   END Listener;

(*--------------------------------------------------------------------------------*)

BEGIN
END AEvent;

(*================================================================================*)

END Event.