MODULE BridgeSvc;

(*================================================================================*)

FROM Debug IMPORT
   Assertion;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   device,
   DeviceIOSDAPBridge,
   FIO,
   FIOO,
   INIfile,
   Log,
   msgqueuethread,
   netinit,
   Registry,
   scinit,
   sdap,
   Service,
   Strings,
   StringsO,
   Sync,
   threadcall;
   
(*================================================================================*)

CONST
   keyStorage = L"Storage";
   keyDefaultConfiguration = L"Default configuration";
   defaultConfiguration = L"default.cfg";
   
(*================================================================================*)

TYPE  
   TCommand = (
      cmdStart,
      cmdContinue,
      cmdPause,
      cmdStop
   );

(*---------------------------------------------------------------------------*)

CLASS CBridgeSvc( Service.AService ) IMPLEMENTS threadcall.IThreadProcedureCallTarget;
   LOCAL VIRTUAL READONLY PROPERTY
      Name : PWCHAR;
      
   PRIVATE VAR
      ConfigLogger : Log.CLogger;
      Bridge : DeviceIOSDAPBridge.TPBridge := NIL;

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
END CBridgeSvc;

(*================================================================================*)

CONST
   ServiceName = ProductId;

CLASS IMPLEMENTATION CBridgeSvc;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROPERTY Name GET : PWCHAR;
   BEGIN
      RETURN PWCHAR( ADR( ServiceName ));
   END Name;

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
      line : CARDINAL;
      Path : ARRAY [0..260] OF WCHAR;
      RS : Registry.CRegistry;
      s1, s2 : StringsO.CString;
   BEGIN
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
      
      INIfile.ConfigureLog( cfg, L"", REF Log.logger()^, OUT line );
      ConfigLogger.SetUpByLogger( Log.logger()^ );
      
      ASSERT( Bridge = NIL );
      DeviceIOSDAPBridge.newDeviceIOSDAPBridge( OUT Bridge );
      
      configuration[0].Type := device.citINIFile;
      configuration[0].iniFile := ADR( cfg );
      IF Bridge^.Configure( configuration, ADR( ConfigLogger )) = Sync.arCompleted THEN
         Bridge^.Start();
      ELSE
         LogEvent( -1, L"Svc.OnStart, configuration was not loaded" );
      END;
      
      SetServiceState( Service.ssRunning, 0 );
   END _OnStart;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE _OnPause();
   BEGIN
      IF Bridge = NIL THEN
         LogEvent( -1, L"Svc.OnPause called for Bridge = NIL" );
      ELSE
         Bridge^.Stop();
      END;

      SetServiceState( Service.ssPaused, 0 );
   END _OnPause;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE _OnContinue();
   BEGIN
      IF Bridge = NIL THEN
         LogEvent( -1, L"Svc.OnContinue called for Bridge = NIL" );
      ELSE
         Bridge^.Start();
      END;

      SetServiceState( Service.ssRunning, 0 );
   END _OnContinue;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE _OnStop();
   BEGIN
      IF Bridge <> NIL THEN
         Bridge^.Stop();
         Bridge^.Dispose();
         DISPOSE( Bridge );
      END;

      // do this sooner than scinit.Cleanup, because scinit.Cleanup is called from different thread
      netinit.Cleanup();

      SetServiceState( Service.ssStopped, 0 );
   END _OnStop;

(*--------------------------------------------------------------------------------*)

BEGIN
END CBridgeSvc;

(*================================================================================*)

VAR
   BridgeSvc : CBridgeSvc;

#save, call( convention => cdecl )
PROCEDURE Main( argc : CARDINAL; argp : ADDRESS ) : CARDINAL;
#restore
VAR
   PService : Service.TPService := ADR( BridgeSvc );
BEGIN
   Service.Run( OA( 0, ADR( PService )), FALSE, 0 );
   RETURN 0;
END Main;

(*================================================================================*)

END BridgeSvc.