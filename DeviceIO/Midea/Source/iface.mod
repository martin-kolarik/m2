IMPLEMENTATION MODULE iface;

(*===========================================================================*)

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   device,
   helper,
   Midea;

(*===========================================================================*)

CONST
   nDeviceIO = L"IO.Device";

(*===========================================================================*)

CLASS CPlugin( helper.APlugin );
   
   // ILibrary
   PUBLIC VIRTUAL PROCEDURE PluginInfo( OUT Plugin, PluginVersionString : ARRAY OF WCHAR );
   PUBLIC VIRTUAL PROCEDURE EnumerateClasses( REF EnumerateState : PTR; OUT ClassName : ARRAY OF WCHAR ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE GetLECData( OUT cllvData : iplugin.TcllvData; OUT cllvPath : ARRAY OF WCHAR ) : BOOLEAN;

   // ACreator
   PUBLIC VIRTUAL PROCEDURE CreateObject( CONST QName : ARRAY OF WCHAR; OUT Object : iplugin.TPPluginObject ) : iplugin.TLoadResult;
   PUBLIC VIRTUAL PROCEDURE DestroyObject( REF Object : iplugin.TPPluginObject ) : iplugin.TLoadResult;

END CPlugin;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CPlugin;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE PluginInfo( OUT Plugin, PluginVersionString : ARRAY OF WCHAR );
   BEGIN
      Plugin := ProductId;
      PluginVersionString := ProductVersion;
   END PluginInfo;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE EnumerateClasses( REF EnumerateState : PTR; OUT ClassName : ARRAY OF WCHAR ) : BOOLEAN;
   BEGIN
      IF EnumerateState > 0 THEN
         RETURN FALSE;
      END;
      ClassName := nDeviceIO;
      RETURN TRUE;
   END EnumerateClasses;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE GetLECData( OUT cllvData : iplugin.TcllvData; OUT cllvPath : ARRAY OF WCHAR ) : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END GetLECData;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CreateObject( CONST QName : ARRAY OF WCHAR; OUT Object : iplugin.TPPluginObject ) : iplugin.TLoadResult;
   BEGIN
      IF EQUALS( QName, iplugin.cidPlugin ) THEN
         Object := OfPlugin; // return SELF
      ELSIF EQUALS( QName, nDeviceIO ) THEN
         Object := ADR( NEW( Midea.CMideaDevice )^.IDevice );
      ELSE
         RETURN iplugin.lrClassNotFound;
      END;
      RETURN iplugin.lrSuccess;
   END CreateObject;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE DestroyObject( REF Object : iplugin.TPPluginObject ) : iplugin.TLoadResult;
   VAR
      implementor : helper.TPAPluginObject := Object^.OwnerHandle;
   BEGIN
      IF Object = OfPlugin THEN
         // fall down, do nothing, cannot deallocate static global class
      ELSIF implementor^ IS Midea.CMideaDevice THEN // ok
         DISPOSE( implementor );
      ELSE
         RETURN iplugin.lrClassNotFound;
      END;
      Object := NIL;
      RETURN iplugin.lrSuccess;
   END DestroyObject;

(*---------------------------------------------------------------------------*)

END CPlugin;

(*===========================================================================*)

VAR
   Plugin : CPlugin;

PROCEDURE Factory( CONST ClassPath : ARRAY OF WCHAR; OUT Object : iplugin.TPPluginObject ) : iplugin.TLoadResult;
BEGIN
   RETURN Plugin.Factory( ClassPath, OUT Object );
END Factory;

(*===========================================================================*)

END iface.