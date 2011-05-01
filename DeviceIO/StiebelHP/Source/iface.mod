IMPLEMENTATION MODULE iface;

(*===========================================================================*)

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   device,
   helper,
   StiebelHP;

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
      IF NOT EQUALS( QName, nDeviceIO ) THEN
         RETURN iplugin.lrClassNotFound;
      END;
      Object := ADR( NEW( StiebelHP.CStiebelHPDevice )^.IDevice );
      RETURN iplugin.lrSuccess;
   END CreateObject;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE DestroyObject( REF Object : iplugin.TPPluginObject ) : iplugin.TLoadResult;
   VAR
      implementor : helper.TPAPluginObject := Object^.OwnerHandle;
   BEGIN
      IF implementor^ IS StiebelHP.CStiebelHPDevice THEN // ok
         DISPOSE( implementor );
         RETURN iplugin.lrSuccess;
      ELSE
         RETURN iplugin.lrClassNotFound;
      END;
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