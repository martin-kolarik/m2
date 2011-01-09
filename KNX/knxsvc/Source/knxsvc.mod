MODULE knxsvc;

(*================================================================================*)

FROM Debug IMPORT
   Assertion;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   adviser,
   cllv,
   device,
   FIO,
   FIOO,
   io,
   INIfile,
   inetaddr,
   knxcore,
   KnxSvcWeb,
   lists,
   Log,
   LogConfig,
   msgqueuethread,
   netinit,
   Registry,
   scinit,
   sdap,
   Service,
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

CLASS CKnxSvc( Service.AService ) IMPLEMENTS threadcall.IThreadProcedureCallTarget;
   LOCAL VIRTUAL READONLY PROPERTY
      Name : PWCHAR;
      Configuration : StringsO.TPString;
      
   PRIVATE VAR
      LogAppenders : lists.CPtrList;
      ConfigLogger : Log.CBufferedLogger;
      DataLogger : Log.CBufferedLogger; 
      HttpLogger : Log.CLogger; 
      NetworkLogger : Log.CLogger; 
      KNX : knxcore.TPKNXServer := NIL;
      Adviser : adviser.TPAdvisedDevice := NIL;
      SDAP : sdap.TPSDAPServer := NIL;
      XMLS : xmlsocket.TPXMLSocketServer := NIL;
      Web : KnxSvcWeb.CKnxSvcWeb;
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
END CKnxSvc;

(*================================================================================*)

CONST
   ServiceName = ProductId;

CLASS IMPLEMENTATION CKnxSvc;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROPERTY Name GET : PWCHAR;
   BEGIN
      RETURN PWCHAR( ADR( ServiceName ));
   END Name;

(*--------------------------------------------------------------------------------*)

   LOCAL PROPERTY Configuration GET : StringsO.TPString;
   BEGIN
      IF KNX = NIL THEN
         RETURN NIL;
      ELSE
         RETURN KNX^.Configuration;
      END;
   END Configuration;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnStart();
   BEGIN
      scinit.Startup();
      msgqueuethread.global()^.DispatchCall( ADR( SELF ), CARDINAL( cmdStart ), OA( -1, NIL ), NIL, TRUE, Sync.FORSAFETY );
   END OnStart;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnPause();
   BEGIN
      msgqueuethread.global()^.DispatchCall( ADR( SELF ), CARDINAL( cmdPause ), OA( -1, NIL ), NIL, TRUE, Sync.FORSAFETY );
   END OnPause;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnContinue();
   BEGIN
      msgqueuethread.global()^.DispatchCall( ADR( SELF ), CARDINAL( cmdContinue ), OA( -1, NIL ), NIL, TRUE, Sync.FORSAFETY );
   END OnContinue;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnStop();
   BEGIN
      msgqueuethread.global()^.DispatchCall( ADR( SELF ), CARDINAL( cmdStop ), OA( -1, NIL ), NIL, TRUE, Sync.FORSAFETY );

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
      
      LogConfig.ConfigureLog( cfg, L"", REF Log.logger()^, REF LogAppenders, OUT line );
      Log.logger()^.LocalTime := TRUE;

      LogConfig.ConfigureLog( cfg, L"datalog", REF DataLogger, REF LogAppenders, OUT line );
      DataLogger.LocalTime := TRUE;
      
      Log.ConfigureByAppender( REF HttpLogger, Log.logger()^ );
      LogConfig.ConfigureLog( cfg, L"httplog", REF HttpLogger, REF LogAppenders, OUT line );
      HttpLogger.TimeStamps := FALSE;
      HttpLogger.Levels := FALSE;
      HttpLogger.Names := FALSE;

      Log.ConfigureByAppender( REF NetworkLogger, Log.logger()^ );
      LogConfig.ConfigureLog( cfg, L"networklog", REF NetworkLogger, REF LogAppenders, OUT line );
      NetworkLogger.LocalTime := TRUE;
      
      ASSERT( KNX = NIL );
      NEW( KNX );
      KNX^.Init( TRUE );
      KNX^.EXEFlag := TRUE;
      KNX^.cllvData := ADR( cllv.data );
      KNX^.cllvLength := cllv.length;
      KNX^.DataLogger := ADR( DataLogger );
      
      configuration[0].Type := device.citIString;
      configuration[0].iString := ADR( s1 );
      Result := KNX^.Configure( configuration, ADR( ConfigLogger ));
      
      ASSERT( Adviser = NIL );
      NEW( Adviser );
      Adviser^.Device := KNX;
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
      
      IF Web.Init( 6005, L"/SmartServer", cfg, KNX, CDI.Names, CDI.Devices, ADR( ConfigLogger ), ADR( DataLogger ), ADR( HttpLogger )) THEN
         Web.Run();
      END;
      IF Result = Sync.arCompleted THEN
         KNX^.Start();
      END;

      SetServiceState( Service.ssRunning, 0 );
   END _OnStart;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE _OnPause();
   BEGIN
      IF KNX = NIL THEN
         LogEvent( -1, L"Svc.OnPause called for KNX = NIL" );
      ELSE
         KNX^.Stop();
      END;

      SetServiceState( Service.ssPaused, 0 );
   END _OnPause;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE _OnContinue();
   BEGIN
      IF KNX = NIL THEN
         LogEvent( -1, L"Svc.OnContinue called for KNX = NIL" );
      ELSE
         KNX^.Start();
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

      IF KNX <> NIL THEN
         KNX^.Stop();
         KNX^.Dispose();
         DISPOSE( KNX );
      END;

      ConfigLogger.BufferClear();      
      DataLogger.BufferClear();
      LogConfig.DisposeAppenderList( REF LogAppenders );

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
END CKnxSvc;

(*================================================================================*)

VAR
   KnxSvc : CKnxSvc;

# save, call( convention => cdecl )
PROCEDURE Main( argc : INTEGER; argp : ADDRESS ) : INTEGER;
# restore
VAR
   PService : Service.TPService := ADR( KnxSvc );
BEGIN
   Service.Run( OA( 0, ADR( PService )), FALSE, 0 );
   RETURN 0;
END Main;

(*================================================================================*)

END knxsvc.