IMPLEMENTATION MODULE loader;

FROM Debug IMPORT
   Assertion, LogAssertionW;

FROM Strings IMPORT
   LowerizeW;

IMPORT
   FIO,
   Strings,
   StringsO,
   winerror,
   windows;

(*===========================================================================*)

TYPE
   TPPlugin = POINTER TO CPlugin;

CLASS CPlugin( baseobject.BASE );
   LOCAL VAR
      Path : StringsO.CString;
      State : TState;
      Loader : TPLoader;
      RefCount : INTEGER;
   PRIVATE VAR
      DllHandle : windows.HANDLE;
      Plugin : iplugin.TPPlugin;
      Factory : iplugin.TFactory;
   LOCAL READONLY PROPERTY
      Name : StringsO.CString;

   LOCAL PROCEDURE CreateObject( CONST ClassName : ARRAY OF WCHAR; OUT Object : iplugin.TPPluginObject ) : iplugin.TLoadResult;
   LOCAL PROCEDURE ReleaseObject( REF Object : iplugin.TPPluginObject );
   
   PRIVATE PROCEDURE LoadDll() : iplugin.TLoadResult;
   PRIVATE PROCEDURE UnloadDll();
END CPlugin;

(*===========================================================================*)

CLASS IMPLEMENTATION CPlugin;

(*---------------------------------------------------------------------------*)

   LOCAL PROPERTY Name GET : StringsO.CString;
   VAR
      FileName : FIO.PathStrW;
      S : StringsO.CString;
   BEGIN
      FIO.PathTailW( OA( Path.Length-1, Path.Data ), OUT FileName );
      FIO.ChangeExtensionW( REF FileName, L"" );
      S.FromOA( FileName );
      RETURN S;
   END Name;

(*---------------------------------------------------------------------------*)

   LOCAL PROCEDURE CreateObject( CONST ClassName : ARRAY OF WCHAR; OUT Object : iplugin.TPPluginObject ) : iplugin.TLoadResult;
   VAR
      Result : iplugin.TLoadResult;
   BEGIN
      IF DllHandle = NIL THEN
         Result := LoadDll();
         IF Result <> iplugin.lrSuccess THEN
            RETURN Result;
         END;
      END;
      Result := Plugin^.CreateObject( ClassName, OUT Object );
      IF Result = iplugin.lrSuccess THEN
         INC( RefCount );
      END;
      RETURN Result;
   END CreateObject;

(*---------------------------------------------------------------------------*)

   LOCAL PROCEDURE ReleaseObject( REF Object : iplugin.TPPluginObject );
   BEGIN
      IF ( DllHandle = NIL ) OR ( RefCount <= 0 ) THEN
         ASSERT( FALSE );
         RETURN;
      END;   
      Plugin^.DestroyObject( REF Object );
      DEC( RefCount );
      IF RefCount = 1 THEN // the last one is IPlugin
         UnloadDll();
      END;
   END ReleaseObject;
   
(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE LoadDll() : iplugin.TLoadResult;
   VAR
      ErrorMode : CARDINAL;
      Error : CARDINAL := 0;
      Result : iplugin.TLoadResult;
   BEGIN
      ASSERT( DllHandle = NIL );
      ErrorMode := windows.SetErrorMode( windows.SEM_FAILCRITICALERRORS );
      DllHandle := windows.LoadLibrary( Path.Data );
      IF DllHandle = NIL THEN
         Error := windows.GetLastError();
      END;
      windows.SetErrorMode( ErrorMode );
      IF DllHandle = NIL THEN
         IF Error = winerror.ERROR_MOD_NOT_FOUND THEN
            RETURN iplugin.lrPluginNotFound;
         ELSE
            RETURN iplugin.lrPluginFoundButIsUnloadable;
         END;
      END;

      Factory := windows.GetProcAddress( DllHandle, iplugin.FACTORY_PROC_NAME );
      IF Factory = NIL THEN
         UnloadDll();
         RETURN iplugin.lrPluginFoundButIsUnloadable;
      END;
      Result := Factory( iplugin.cidPlugin, OUT Plugin );
      IF Result = iplugin.lrSuccess THEN
         INC( RefCount );
      ELSE
         UnloadDll();
         RETURN iplugin.lrPluginFoundButIsUnloadable;
      END;

      // internal info
      Plugin^.HostHandle := ADR( SELF ); // I will use it later to deallocate the object
      // public info
      Plugin^.HostInfo( OA( Loader^.Host^.Length-1, Loader^.Host^.Data ), OA( Loader^.HostVersionString^.Length-1, Loader^.HostVersionString^.Data ));

      IF Loader^.LoadAuthorizer = NIL THEN
         RETURN iplugin.lrSuccess; // loaded
      ELSIF Loader^.LoadAuthorizer^.AuthorizedToLoad( Plugin ) THEN
         RETURN iplugin.lrSuccess; // loaded
      ELSE
         UnloadDll();
         RETURN iplugin.lrPluginFoundButLoadUnauthorized; // unauthorized, unloaded
      END;
   END LoadDll;
   
(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE UnloadDll();
   BEGIN
      IF DllHandle <> NIL THEN
         ASSERT(( RefCount = 1 ) OR ( DllHandle = NIL )); // the last one is Plugin, Plugin = NIL is for the case of unloadability of library

         IF Plugin <> NIL THEN
            ReleaseObject( REF Plugin );
         END;
         windows.FreeLibrary( DllHandle );
         DllHandle := NIL;
         Factory := NIL;
      END;
   END UnloadDll;

(*---------------------------------------------------------------------------*)

BEGIN
   State := TState{lsEnabled};
   Loader := NIL;
   RefCount := 0;
   DllHandle := NIL;
   Plugin := NIL;
   Factory := NIL;
FINALLY
   UnloadDll();
END CPlugin;

(*===========================================================================*)

CLASS IMPLEMENTATION CLoader;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Host GET : StringsO.TPString;
   BEGIN
      RETURN ADR( _Host );
   END Host;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY HostVersionString GET : StringsO.TPString;
   BEGIN
      RETURN ADR( _HostVersionString );
   END HostVersionString;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY LoadAuthorizer GET : TPPluginLoadAuthorizer;
   BEGIN
      RETURN _LoadAuthorizer;
   END LoadAuthorizer;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY LoadAuthorizer SET( Value : TPPluginLoadAuthorizer );
   BEGIN
      _LoadAuthorizer := Value;
   END LoadAuthorizer;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SetHostInfo( CONST Host, HostVersionString : ARRAY OF WCHAR );
   BEGIN
      SELF._Host.FromOA( Host );
      SELF._HostVersionString.FromOA( HostVersionString );
   END SetHostInfo;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE AddPlugin( CONST PluginPath : ARRAY OF WCHAR; PluginName : StringsO.TPString ) : iplugin.TLoadResult;
   VAR
      Plugin : TPPlugin;
      LPath : FIO.PathStrW;
   BEGIN
      FIO.ExpandPathW( PluginPath, OUT LPath );
      IF NOT LookupPlugin( LPath, OUT Plugin ) THEN
         NEW( Plugin );
         Plugin^.Path.FromOA( LPath );
         Plugin^.Loader := ADR( SELF );
         _Plugins.Add( Plugin, 0 );
      END;
      BuildNames();
      IF PluginName <> NIL THEN
         PluginName^.Assign( Plugin^.Name );
      END;
      RETURN iplugin.lrSuccess;
   END AddPlugin;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE RemovePlugin( CONST PluginPath : ARRAY OF WCHAR );
   VAR
      LPath : FIO.PathStrW;
      NL : lists.CPtrList;
   BEGIN
      FIO.ExpandPathW( PluginPath, OUT LPath );
      _Plugins.Reset();
      WHILE _Plugins.MoveNext() DO
         IF NOT TPPlugin( _Plugins.Current )^.Path.EqualsOA( LPath ) THEN
           NL.Add( _Plugins.Current, 0 );
         END;
      END; // WHILE
      _Plugins.Dispose();
      _Plugins.AppendList( REF NL );
      BuildNames();
   END RemovePlugin;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ScanPath( CONST Path, PluginNamePattern : ARRAY OF WCHAR; OUT Found : CARDINAL ) : iplugin.TLoadResult;
   BEGIN
      RETURN iplugin.lrSuccess;
   END ScanPath;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE DisablePlugin( CONST PluginPath : ARRAY OF WCHAR );
   VAR
      Plugin : TPPlugin;
      LPath : FIO.PathStrW;
   BEGIN
      FIO.ExpandPathW( PluginPath, OUT LPath );
      IF LookupPlugin( LPath, OUT Plugin ) THEN
         EXCL( Plugin^.State, lsEnabled );
         BuildNames();
      END;
   END DisablePlugin;
   
(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE EnablePlugin( CONST PluginPath : ARRAY OF WCHAR );
   VAR
      Plugin : TPPlugin;
      LPath : FIO.PathStrW;
   BEGIN
      FIO.ExpandPathW( PluginPath, OUT LPath );
      IF LookupPlugin( LPath, OUT Plugin ) THEN
         INCL( Plugin^.State, lsEnabled );
         BuildNames();
      END;
   END EnablePlugin;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE EnumeratePlugins( REF EnumerateState : PTR; OUT PluginName, PluginPath : ARRAY OF WCHAR; OUT State : TState ) : BOOLEAN;
   VAR
      b : BOOLEAN;
      Data : PTR;
      Plugin : TPPlugin;
   BEGIN
      IF EnumerateState = 0 THEN
         b := _Plugins.GetFirst( OUT Plugin, OUT Data );
      ELSE
         b := _Plugins.NextOf( EnumerateState, OUT Plugin, OUT Data );
      END;
      IF NOT b THEN
         RETURN FALSE;
      END;
      
      Plugin^.Name.ToOA( OUT PluginName );
      Plugin^.Path.ToOA( OUT PluginPath );
      
      EnumerateState := Plugin;
      RETURN TRUE;
   END EnumeratePlugins;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE EnumerateClasses( REF EnumerateState : PTR; CONST PluginName : ARRAY OF WCHAR; FullClassPathFlag : BOOLEAN; OUT ClassNameOrPath : ARRAY OF WCHAR ) : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END EnumerateClasses;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CreateObject( CONST ClassPath : ARRAY OF WCHAR; OUT Object : iplugin.TPPluginObject ) : iplugin.TLoadResult;
   VAR
      i : INTEGER;
      plugin : TPPlugin;
      s : FIO.PathStrW;
   BEGIN
      i := Strings.ItemSW( ClassPath, Strings.WCHARS{L"/"}, 0, 0, FALSE, OUT s );
      LOW( s );
      IF s[0] = 0W THEN
         RETURN iplugin.lrPluginNotFound;
      ELSIF NOT _Names.GetOA( s, OUT plugin ) THEN
         RETURN iplugin.lrPluginNotFound;
      ELSE
         Strings.SubstringW( ClassPath, i, -1, OUT s );
         RETURN plugin^.CreateObject( s, OUT Object );
      END;
   END CreateObject;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ReleaseObject( REF Object : iplugin.TPPluginObject );
   BEGIN
      IF ( Object = NIL ) OR ( Object^.OfPlugin = NIL ) OR ( Object^.OfPlugin^.HostHandle = NIL ) THEN
         ASSERTLOG( FALSE, L"Trial to release nonexisting or damaged object" );
         RETURN;
      END;
      TPPlugin( Object^.OfPlugin^.HostHandle )^.ReleaseObject( REF Object );
   END ReleaseObject;
   
(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   VAR
      Plugin : TPPlugin;
   BEGIN
      _Plugins.Reset();
      WHILE _Plugins.MoveNext() DO
         Plugin := TPPlugin( _Plugins.Current );
         ASSERT( Plugin^.RefCount = 0 );
         DISPOSE( Plugin );
      END; // WHILE
      _Plugins.Dispose();
      _Names.Dispose();
   END Dispose;

(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE LookupPlugin( CONST PluginPath : ARRAY OF WCHAR; OUT Plugin : ADDRESS ) : BOOLEAN;
   BEGIN
      _Plugins.Reset();
      WHILE _Plugins.MoveNext() DO
         IF TPPlugin( _Plugins.Current )^.Path.EqualsOA( PluginPath ) THEN
            Plugin := _Plugins.Current;
            RETURN TRUE;
         END;
      END; // WHILE
      RETURN FALSE;
   END LookupPlugin;
   
(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE BuildNames();
   VAR
      Plugin : TPPlugin;
      Name : StringsO.CString;
   BEGIN
      _Names.Dispose();
      _Plugins.Reset();
      WHILE _Plugins.MoveNext() DO
         Plugin := TPPlugin( _Plugins.Current );
         Name := Plugin^.Name;
         Name.Lowerize();
         IF lsEnabled IN Plugin^.State THEN
            IF _Names.Contains( Name ) THEN
               ASSERTLOG( FALSE );
            ELSE
               _Names.Add( Name, Plugin );
            END;
         END;
      END; // WHILE
   END BuildNames;

(*---------------------------------------------------------------------------*)

BEGIN
   _LoadAuthorizer := NIL;
   _Host.FromOA( ProductId );
   _HostVersionString.FromOA( ProductVersion );
FINALLY
   Dispose();
END CLoader;

(*===========================================================================*)

// global loader
VAR
  PLoader : TPLoader := NIL;

PROCEDURE ldr() : TPLoader;
BEGIN
   IF PLoader = NIL THEN
      NEW( PLoader );
   END;
   RETURN PLoader;
END ldr;

(*---------------------------------------------------------------------------*)

BEGIN FINALLY
   IF PLoader <> NIL THEN
      DISPOSE( PLoader );
   END;
END loader.
