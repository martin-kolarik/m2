IMPLEMENTATION MODULE objlib;

(*===========================================================================*)

CLASS IMPLEMENTATION AObject;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Library GET : TPLibrary;
   BEGIN
      RETURN _Library;
   END Library;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Library SET( Value : TPLibrary );
   BEGIN
      _Library := Value;
   END Library;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   BEGIN
   END Dispose;

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

   PUBLIC FINAL PROPERTY Library GET : TPLibrary;
   BEGIN
      RETURN SUPER.Library;
   END Library;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY Library SET( Value : TPLibrary );
   BEGIN
      SUPER.Library := Value;
   END Library;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROCEDURE Dispose();
   BEGIN
      SUPER.Dispose();
   END Dispose;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY Loader GET : ADDRESS;
   BEGIN
      RETURN _Loader;
   END Loader;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY LoaderLibraryHandle GET : PTR;
   BEGIN
      RETURN _LoaderLibraryHandle;
   END LoaderLibraryHandle;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROCEDURE HostInfo( Loader : ADDRESS; LoaderLibraryHandle : PTR; CONST Host, HostVersionString : ARRAY OF WCHAR ); // usually product id/product version
   BEGIN
      _Loader := Loader;
      _LoaderLibraryHandle := LoaderLibraryHandle;
      _Host.FromOA( Host );
      _HostVersion.FromOA( HostVersionString );
   END HostInfo;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Factory( CONST QName : ARRAY OF WCHAR; OUT Object : TPObject ) : TResult;
   VAR
      Result : TResult;
   BEGIN
      IF EQUALS( QName, nLibrary ) THEN
         Object := ADR( ILibrary );
         Result := lrSuccess;
      ELSE
         Result := OnFactory( QName, OUT Object );
      END;
      IF Result = lrSuccess THEN
         Object^.Library := ADR( ILibrary );
      END;
      RETURN Result;
   END Factory;

(*---------------------------------------------------------------------------*)

BEGIN
   _Loader := NIL;
   _LoaderLibraryHandle := NIL;
END ACreator;

(*===========================================================================*)

END objlib.