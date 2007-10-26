IMPLEMENTATION MODULE objlib;

(*===========================================================================*)

CLASS IMPLEMENTATION AObject;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY Loader SET( Value : TPLoader );
   BEGIN
      _Loader := Value;
   END Loader;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROCEDURE Release();
   VAR
      self1 : ADDRESS := ADR( SELF );
      self2 : ADDRESS := ADR( SELF );
   BEGIN
      IF Type = otEphemeral THEN
         DISPOSE( self1 );
      END;
      IF _Loader <> NIL THEN
         _Loader^.ReleaseObject( self2 );
      END;
   END Release;

(*---------------------------------------------------------------------------*)

BEGIN
   _Loader := NIL;
END AObject;

(*===========================================================================*)

CLASS IMPLEMENTATION ACreator;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Type GET : TObjectType;
   BEGIN
      RETURN otSingleton;
   END Type;

(*---------------------------------------------------------------------------*)

   LOCAL PROCEDURE GetObject( CONST QName : ARRAY OF WCHAR; OUT Object : TPObject ) : TResult;
   TYPE
      TPAObject = POINTER TO AObject;
   BEGIN
      IF EQUALS( QName, nLibrary ) THEN
         Object := ADR( ILibrary );
         RETURN lrSuccess;
      ELSE
         RETURN OnGetObject( QName, OUT Object );
      END;
   END GetObject;

(*---------------------------------------------------------------------------*)

END ACreator;

(*===========================================================================*)

END objlib.