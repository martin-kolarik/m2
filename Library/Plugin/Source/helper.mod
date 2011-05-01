IMPLEMENTATION MODULE helper;

FROM Debug IMPORT
   Assertion, LogAssertionW;

IMPORT
   baseobject;

(*===========================================================================*)

CLASS IMPLEMENTATION APluginObject;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY OfPlugin GET : iplugin.TPPlugin;
   BEGIN
      RETURN _OfPlugin;
   END OfPlugin;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY OwnerHandle GET : PTR;
   BEGIN
      RETURN ADR( SELF );
   END OwnerHandle;

(*---------------------------------------------------------------------------*)

   LOCAL PROCEDURE SetOfPlugin( CONST _OfPlugin : iplugin.TPPlugin );
   BEGIN
      SELF._OfPlugin := _OfPlugin;
   END SetOfPlugin;

(*---------------------------------------------------------------------------*)

BEGIN
   _OfPlugin := NIL;
END APluginObject;

(*===========================================================================*)

CLASS IMPLEMENTATION APlugin;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Type GET : iplugin.TObjectType;
   BEGIN
      RETURN iplugin.otSingleton;
   END Type;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY OfPlugin GET : iplugin.TPPlugin;
   BEGIN
      RETURN SUPER.OfPlugin;
   END OfPlugin;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY OwnerHandle GET : PTR;
   BEGIN
      RETURN SUPER.OwnerHandle;
   END OwnerHandle;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROCEDURE HostInfo( CONST Host, HostVersionString : ARRAY OF WCHAR ); // usually product id/product version
   BEGIN
      _Host.FromOA( Host );
      _HostVersion.FromOA( HostVersionString );
   END HostInfo;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY HostHandle GET : PTR;
   BEGIN
      RETURN _HostHandle;
   END HostHandle;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY HostHandle SET( Value : PTR );
   BEGIN
      _HostHandle := Value;
   END HostHandle;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Factory( CONST QName : ARRAY OF WCHAR; OUT Object : iplugin.TPPluginObject ) : iplugin.TLoadResult;
   VAR
      Result : iplugin.TLoadResult;
   BEGIN
      IF EQUALS( QName, iplugin.cidPlugin ) THEN
         Object := OfPlugin; // return SELF
         Result := iplugin.lrSuccess;
      ELSE
         Result := CreateObject( QName, OUT Object );
      END;
      RETURN Result;
   END Factory;

(*---------------------------------------------------------------------------*)

BEGIN
   SetOfPlugin( ADR( IPlugin ));
   _HostHandle := NIL;
END APlugin;

(*===========================================================================*)

END helper.