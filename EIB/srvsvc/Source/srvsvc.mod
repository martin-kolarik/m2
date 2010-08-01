MODULE srvsvc;

(*================================================================================*)

FROM Debug IMPORT
   Assertion;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   adviser,
   cllv,
   device,
   EibSrvWeb,
   FIO,
   FIOO,
   io,
   INIfile,
   inetaddr,
   Log,
   LogConfig,
   LogFilter,
   msgqueuethread,
   netinit,
   Registry,
   scinit,
   sdap,
   Service,
   srvcore,
   Strings,
   StringsO,
   Sync,
   threadcall,
   xmlsocket;
   
IMPORT
   httpsrv,
   MVC;   
   
(*================================================================================*)

CONST
   keyStorage = L"Storage";
   keyDefaultConfiguration = L"Default configuration";
   defaultConfiguration = L"default.cfg";
   
   nameSDAP = L'name.SDAP';
   nameXMLSocket = L'name.XMLSocket';
   
TYPE
   TControlledDeviceInfo = RECORD
                              Names : ARRAY [0..1] OF PWCHAR;
                              Devices : ARRAY [0..1] OF io.TPIStartStopControl;
                           END; // RECORD

(*================================================================================*)

TYPE  
   TCommand = (
      cmdStart,
      cmdContinue,
      cmdPause,
      cmdStop
   );

(*---------------------------------------------------------------------------*)

CLASS CEibSvc( Service.AService ) IMPLEMENTS threadcall.IThreadProcedureCallTarget;
   LOCAL VIRTUAL READONLY PROPERTY
      Name : PWCHAR;
      Configuration : StringsO.TPString;
      
   PRIVATE VAR
      CommonFilter : LogFilter.CLogFilter;
      ConfigLogger : Log.CBufferedLogger;
      DataLogger : Log.CBufferedLogger; 
      HttpLogger : Log.CLogger; 
      NetworkLogger : Log.CLogger; 
      NetworkFilter : LogFilter.CLogFilter;
      EIB : srvcore.TPEIBServer := NIL;
      Adviser : adviser.TPAdvisedDevice := NIL;
      SDAP : sdap.TPSDAPServer := NIL;
      XMLS : xmlsocket.TPXMLSocketServer := NIL;
      Web : EibSrvWeb.CEibSrvWeb;
      CDI : TControlledDeviceInfo;

   // service, OS thread
   LOCAL VIRTUAL PROCEDURE OnStart();
   LOCAL VIRTUAL PROCEDURE OnPause();
   LOCAL VIRTUAL PROCEDURE OnContinue();
   LOCAL VIRTUAL PROCEDURE OnStop();
   
   // IThreadProcedureCallTarget
   PUBLIC VIRTUAL PROCEDURE Invoke( Operation : CARDINAL; CONST Parameters : ARRAY OF PTR ) : PTR;
   
   // self message thread
   PRIVATE PROCEDURE _OnStart();
   PRIVATE PROCEDURE _OnPause();
   PRIVATE PROCEDURE _OnContinue();
   PRIVATE PROCEDURE _OnStop();
END CEibSvc;

(*================================================================================*)

CONST
   ServiceName = ProductId;

CLASS IMPLEMENTATION CEibSvc;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROPERTY Name GET : PWCHAR;
   BEGIN
      RETURN PWCHAR( ADR( ServiceName ));
   END Name;

(*--------------------------------------------------------------------------------*)

   LOCAL PROPERTY Configuration GET : StringsO.TPString;
   BEGIN
      IF EIB = NIL THEN
         RETURN NIL;
      ELSE
         RETURN EIB^.Configuration;
      END;
   END Configuration;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnStart();
   BEGIN
      scinit.Startup();
      msgqueuethread.global()^.ThreadCall( ADR( SELF ), CARDINAL( cmdStart ), OA( -1, NIL ), NIL, TRUE, Sync.FORSAFETY );
   END OnStart;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnPause();
   BEGIN
      msgqueuethread.global()^.ThreadCall( ADR( SELF ), CARDINAL( cmdPause ), OA( -1, NIL ), NIL, TRUE, Sync.FORSAFETY );
   END OnPause;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnContinue();
   BEGIN
      msgqueuethread.global()^.ThreadCall( ADR( SELF ), CARDINAL( cmdContinue ), OA( -1, NIL ), NIL, TRUE, Sync.FORSAFETY );
   END OnContinue;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnStop();
   BEGIN
      msgqueuethread.global()^.ThreadCall( ADR( SELF ), CARDINAL( cmdStop ), OA( -1, NIL ), NIL, TRUE, Sync.FORSAFETY );

      Sync.Sleep( 1000 ); // give some time to message thread to stop self -- it should be solve by some polling (e.g. netinit.CleanedUp), but this is sufficient now

      scinit.Cleanup();
   END OnStop;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Invoke( Operation : CARDINAL; CONST Parameters : ARRAY OF PTR ) : PTR;
   BEGIN
      CASE TCommand( Operation ) OF
      | cmdStart : _OnStart();
      | cmdContinue : _OnContinue();
      | cmdPause : _OnPause();
      | cmdStop : _OnStop();
      END; // CASE
      RETURN 0;
   END Invoke;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE _OnStart();
   VAR
      cfg : INIfile.CINIFile;
      configuration : ARRAY [0..0] OF device.TConfigureItem;
      Data : ARRAY [0..511] OF WCHAR;
      IA : inetaddr.INETADDR;
      line : CARDINAL;
      Path : ARRAY [0..260] OF WCHAR;
      Result : Sync.TAsyncResult := Sync.arCannotStart;
      RS : Registry.CRegistry;
      s1, s2 : StringsO.CString;
   BEGIN
      // ASSERT( FALSE );
   
      // get confiuration file path
      Strings.ConcatW( OUT Path, L"SOFTWARE\", Manufacturer ); Strings.AppendW( REF Path, L"\" ); Strings.AppendW( REF Path, ProductId );
      IF RS.OpenRead( L"", Registry.LOCAL_MACHINE, Path ) THEN
         IF RS.GetKeyStr( keyStorage, OUT Data ) THEN
            s1.FromOA( Data );
         END;
         IF RS.GetKeyStr( keyDefaultConfiguration, OUT Data ) THEN
            s2.FromOA( Data );
         END;
      END;
      RS.Close();
      
      IF s1.Empty THEN
         FIO.GetModuleDirW( L"", OUT Data );
         s1.FromOA( Data );
      END;
      IF s2.Empty THEN
         s2.FromOA( defaultConfiguration );
      END;
      FIOO.PathAdd( REF s1, s2 );
      cfg.LoadPath( OA( s1.Length-1, s1.Data ));
      
      LogConfig.ConfigureLog( cfg, L"", REF Log.logger()^, OUT line );
      Log.logger()^.LocalTime := TRUE;
      LogConfig.ConfigureLogFilter( cfg, L"", REF CommonFilter, OUT line );
      Log.logger()^.Filter := ADR( CommonFilter );

      LogConfig.ConfigureLog( cfg, L"datalog", REF DataLogger, OUT line );
      DataLogger.LocalTime := TRUE;
      
      Log.ConfigureByAppender( REF HttpLogger, Log.logger()^ );
      LogConfig.ConfigureLog( cfg, L"httplog", REF HttpLogger, OUT line );
      HttpLogger.TimeStamps := FALSE;
      HttpLogger.Levels := FALSE;
      HttpLogger.Names := FALSE;

      Log.ConfigureByAppender( REF NetworkLogger, Log.logger()^ );
      LogConfig.ConfigureLog( cfg, L"networklog", REF NetworkLogger, OUT line );
      NetworkLogger.LocalTime := TRUE;
      LogConfig.ConfigureLogFilter( cfg, L"", REF NetworkFilter, OUT line );
      NetworkLogger.Filter := ADR( NetworkFilter );
      
      ASSERT( EIB = NIL );
      NEW( EIB );
      EIB^.Init( TRUE );
      EIB^.EXEFlag := TRUE;
      EIB^.cllvData := ADR( cllv.data );
      EIB^.cllvLength := cllv.length;
      EIB^.DataLogger := ADR( DataLogger );
      
      configuration[0].Type := device.citIString;
      configuration[0].iString := ADR( s1 );
      Result := EIB^.Configure( configuration, ADR( ConfigLogger ));
      
      ASSERT( Adviser = NIL );
      NEW( Adviser );
      Adviser^.Device := EIB;
      Adviser^.Start();

      ASSERT( SDAP = NIL );
      NEW( SDAP );
      SDAP^.Device := Adviser;
      IA.Port := 6007;
      SDAP^.ListenAddress := IA;
      SDAP^.Init( TRUE );
      SDAP^.CommonLogger := Log.logger();
      SDAP^.ConfigurationLogger := ADR( ConfigLogger );
      SDAP^.NetworkLogger := ADR( NetworkLogger );
      SDAP^.Start();
      
      ASSERT( XMLS = NIL );
      NEW( XMLS );
      XMLS^.Device := Adviser;
      IA.Port := 6006;
      XMLS^.ListenAddress := IA;
      XMLS^.Init( TRUE );
      XMLS^.CommonLogger := Log.logger();
      XMLS^.NetworkLogger := ADR( NetworkLogger );
      XMLS^.Start();
      
      CDI.Names[0] := PWCHAR( ADR( nameSDAP ));
      CDI.Names[1] := PWCHAR( ADR( nameXMLSocket ));
      CDI.Devices[0] := SDAP;
      CDI.Devices[1] := XMLS;
      
      IF Web.Init( 6005, L"/SmartServer", cfg, EIB, CDI.Names, CDI.Devices, ADR( ConfigLogger ), ADR( DataLogger ), ADR( HttpLogger )) THEN
         Web.Run();
      END;
      IF Result = Sync.arCompleted THEN
         EIB^.Start();
      END;

      SetServiceState( Service.ssRunning, 0 );
   END _OnStart;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE _OnPause();
   BEGIN
      IF EIB = NIL THEN
         LogEvent( -1, L"Svc.OnPause called for EIB = NIL" );
      ELSE
         EIB^.Stop();
      END;

      SetServiceState( Service.ssPaused, 0 );
   END _OnPause;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE _OnContinue();
   BEGIN
      IF EIB = NIL THEN
         LogEvent( -1, L"Svc.OnContinue called for EIB = NIL" );
      ELSE
         EIB^.Start();
      END;

      SetServiceState( Service.ssRunning, 0 );
   END _OnContinue;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE _OnStop();
   BEGIN
      Web.Stop();
   
      IF XMLS <> NIL THEN
         XMLS^.Stop();
         DISPOSE( XMLS );
      END;
   
      IF SDAP <> NIL THEN
         SDAP^.Stop();
         DISPOSE( SDAP );
      END;
   
      IF Adviser <> NIL THEN
         Adviser^.Stop();
         DISPOSE( Adviser );
      END;

      IF EIB <> NIL THEN
         EIB^.Stop();
         EIB^.Dispose();
         DISPOSE( EIB );
      END;

      ConfigLogger.BufferClear();      
      DataLogger.BufferClear();

      // do this sooner than scinit.Cleanup, because scinit.Cleanup is called from different thread
      netinit.Cleanup();

      SetServiceState( Service.ssStopped, 0 );
   END _OnStop;

(*--------------------------------------------------------------------------------*)

BEGIN
   CDI.Names[0] := NIL;
   
   Log.logger()^.BufferSize := 1000;

   DataLogger.TimeStamps := TRUE;
   DataLogger.Levels := FALSE;
   DataLogger.Names := FALSE;
   DataLogger.Output := Log.outsNone;
   DataLogger.BufferSize := 1000;

   ConfigLogger.TimeStamps := TRUE;
   ConfigLogger.Levels := FALSE;
   ConfigLogger.Names := FALSE;
   ConfigLogger.Output := Log.outsNone;
   ConfigLogger.Level := Log.ldTrace;
   ConfigLogger.BufferSize := 16;
   ConfigLogger.BufferMode := Log.bmStoreFirst;
END CEibSvc;

(*================================================================================*)

VAR
   EibSvc : CEibSvc;

# save, call( convention => cdecl )
PROCEDURE Main( argc : INTEGER; argp : ADDRESS ) : INTEGER;
# restore
VAR
   PService : Service.TPService := ADR( EibSvc );
BEGIN
   Service.Run( OA( 0, ADR( PService )), FALSE, 0 );
   RETURN 0;
END Main;

(*================================================================================*)

END srvsvc.