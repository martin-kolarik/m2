IMPLEMENTATION MODULE helper;

(*===========================================================================*)

CLASS IMPLEMENTATION AObject;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Library GET : iobject.TPLibrary;
   BEGIN
      RETURN _Library;
   END Library;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Library SET( Value : iobject.TPLibrary );
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

   PUBLIC VIRTUAL PROPERTY Type GET : iobject.TObjectType;
   BEGIN
      RETURN iobject.otSingleton;
   END Type;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY Library GET : iobject.TPLibrary;
   BEGIN
      RETURN SUPER.Library;
   END Library;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY Library SET( Value : iobject.TPLibrary );
   BEGIN
      SUPER.Library := Value;
   END Library;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
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

   PUBLIC PROCEDURE Factory( CONST QName : ARRAY OF WCHAR; OUT Object : iobject.TPObject ) : iobject.TResult;
   VAR
      Result : iobject.TResult;
   BEGIN
      IF EQUALS( QName, iobject.cidLibrary ) THEN
         Object := ADR( ILibrary );
         Result := iobject.lrSuccess;
      ELSE
         Result := OnFactory( QName, OUT Object );
      END;
      IF Result = iobject.lrSuccess THEN
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

END helper.