IMPLEMENTATION MODULE Event;

FROM Debug IMPORT
   AssertionW;

IMPORT
   baseobject,
   lists;

(*================================================================================*)

CLASS CEventIterator( lists.CPtrListIterator ) IMPLEMENTS IEventIterator;

   // collection.IIterator
   PUBLIC VIRTUAL READONLY PROPERTY
      colCurrent : baseobject.PBASE;

   PUBLIC VIRTUAL PROCEDURE Reset();
   PUBLIC VIRTUAL PROCEDURE MoveNext() : BOOLEAN;

   PUBLIC VIRTUAL READONLY PROPERTY
      Implementor : baseobject.TPDisposable; // the object to be disposed, when TPIterator is to be disposed (interface cannot be disposed)
      OfCollection : collection.TPCollection;

   // IEventIterator
   PUBLIC VIRTUAL READONLY PROPERTY
      Listener : ADDRESS;

END CEventIterator;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CEventIterator;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY colCurrent GET : baseobject.PBASE;
   BEGIN
      RETURN SUPER.colCurrent;
   END colCurrent;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Reset();
   BEGIN
      SUPER.Reset();
   END Reset;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE MoveNext() : BOOLEAN;
   BEGIN
      RETURN SUPER.MoveNext();
   END MoveNext;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Implementor GET : baseobject.TPDisposable; // the object to be disposed, when TPIterator is to be disposed (interface cannot be disposed)
   BEGIN
      RETURN SUPER.Implementor;
   END Implementor;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY OfCollection GET : collection.TPCollection;
   BEGIN
      RETURN SUPER.OfCollection;
   END OfCollection;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Listener GET : ADDRESS;
   BEGIN
      RETURN Value;
   END Listener;

(*---------------------------------------------------------------------------*)

END CEventIterator;

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

   INTERNAL PROCEDURE GetIterator() : TPIEventIterator;
   VAR
      iterator : POINTER TO CEventIterator;
   BEGIN
      NEW( iterator );
      iterator^.Init( _Listeners, collection.dirForward );
      RETURN iterator;
   END GetIterator;

(*--------------------------------------------------------------------------------*)

BEGIN
END AEvent;

(*================================================================================*)

END Event.