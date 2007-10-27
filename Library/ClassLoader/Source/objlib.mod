IMPLEMENTATION MODULE objlib;

(*===========================================================================*)

CLASS IMPLEMENTATION AObject;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Library SET( Value : TPLibrary );
   BEGIN
      _Library := Value;
   END Library;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Release();
   VAR
      self1 : ADDRESS := ADR( SELF );
      self2 : ADDRESS := ADR( SELF );
   BEGIN
      IF Type = otEphemeral THEN
         DISPOSE( self1 );
      END;
      IF _Library <> NIL THEN
         _Library^.Loader^.ReleaseObject( _Library^.LibraryHandle, self2 );
      END;
   END Release;

(*---------------------------------------------------------------------------*)

BEGIN
   _Library := NIL;
END AObject;

(*===========================================================================*)

CLASS IMPLEMENTATION ACreator;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Type GET : TObjectType;
   BEGIN
      RETURN otSingleton;
   END Type;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY Library SET( Value : TPLibrary );
   BEGIN
      SUPER.Library := Value;
   END Library;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROCEDURE Release();
   BEGIN
      SUPER.Release();
   END Release;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY Loader GET : TPLoader;
   BEGIN
      RETURN _Loader;
   END Loader;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY Loader SET( Value : TPLoader );
   BEGIN
      _Loader := Value;
   END Loader;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY LibraryHandle GET : PTR;
   BEGIN
      RETURN _Handle;
   END LibraryHandle;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY LibraryHandle SET( Value : PTR );
   BEGIN
      _Handle := Value;
   END LibraryHandle;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROCEDURE HostInfo( CONST Host, HostVersionString : ARRAY OF WCHAR ); // usually product id/product version
   BEGIN
      _Host.FromOA( Host );
      _HostVersion.FromOA( HostVersionString );
   END HostInfo;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE GetObject( CONST QName : ARRAY OF WCHAR; OUT Object : TPObject ) : TResult;
   VAR
      Result : TResult;
   BEGIN
      IF EQUALS( QName, nLibrary ) THEN
         Object := ADR( ILibrary );
         Result := lrSuccess;
      ELSE
         Result := OnGetObject( QName, OUT Object );
      END;
      IF Result = lrSuccess THEN
         Object^.Library := ADR( ILibrary );
      END;
      RETURN Result;
   END GetObject;

(*---------------------------------------------------------------------------*)

BEGIN
   _Loader := NIL;
   _Handle := NIL;
END ACreator;

(*===========================================================================*)

END objlib.