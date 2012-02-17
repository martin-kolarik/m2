MODULE knxsvc;

(*================================================================================*)

FROM Debug IMPORT
   AssertionW;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   adviser,
   cllv,
   compositedatasource,
   Debug,
   device,
   deviceimpl,
   EquithermicCurve,
   FIO,
   FIOO,
   INIfile,
   inetaddr,
   io,
   IOO,
   iovalue,
   knxcore,
   KnxSvcWeb,
   lec,
   lists,
   Log,
   LogConfig,
   msgqueuethread,
   netinit,
   ns,
   nsimpl,
   PersistentStorage,
   Registry,
   scinit,
   sdap,
   Service,
   Strings,
   StringsO,
   Sync,
   threadcall,
   WeekCalendar,
   xmlsocket;
   
IMPORT
   httpsrv,
   MVC;   
   
(*================================================================================*)

CONST
   keyStorage = L"Storage";
   keyDefaultConfiguration = L"Default configuration";
   defaultConfiguration = L"default.cfg";
   defaultStorageName = L"SmartServer";
   
   nameSDAP = L'name.SDAP';
   nameXMLSocket = L'name.XMLSocket';
   nameStorage = L'name.Storage';
   nameEqCurve = L'name.EqCurve';
   nameWeekCalendar = L'name.WeekCalendar';

CONST
   nameSystem = L"System";
      nameLicensingSuspend = L"Licensing.Suspend";
      nameLicensingSerialNumber = L"Licensing.SerialNumber";
      nameConfigurationError = L"Configuration.Error";
      nameConfigurationFile = L"Configuration.File";
      nameProject = L"Project";

TYPE
   TControlledDeviceInfo = RECORD
                              Names : ARRAY [0..4] OF PWCHAR;
                              Devices : ARRAY [0..4] OF io.TPStartStopControl;
                           END; // RECORD

(*--------------------------------------------------------------------------------*)

TYPE  
   TCommand = (
      cmdStart,
      cmdContinue,
      cmdPause,
      cmdStop
   );

(*================================================================================*)

CONST
   itemSystemSerialNumber = 1;
   itemSystemSuspend = 2;
      suspendKey = L"suspend";
      suspendValue = L"true";


CLASS CSuspendableResult( lec.CResult ) IMPLEMENTS ns.IValueIO;

   // IValueIO
   PUBLIC VIRTUAL PROCEDURE ValueIO( CONST Originator : ns.TPOriginator; CONST NameValuePairs : ns.TPNameValuePairs; Direction : IOO.TDirection; REF Value : iovalue.Value ) : Sync.TAsyncResult;

   // CResult
   PUBLIC VIRTUAL READONLY PROPERTY
      Expired : BOOLEAN;

   // SELF
   PUBLIC READONLY PROPERTY
      Suspended : BOOLEAN;
   PUBLIC PROCEDURE QuerySuspension();

   // private
   PRIVATE PROCEDURE LoadData();

   PRIVATE VAR
      _Suspended : BOOLEAN;

END CSuspendableResult;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CSuspendableResult;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE ValueIO( CONST Originator : ns.TPOriginator; CONST NameValuePairs : ns.TPNameValuePairs; Direction : IOO.TDirection; REF Value : iovalue.Value ) : Sync.TAsyncResult;
   VAR
      key : StringsO.CString;
      licences : lists.CStringList;
      p : PTR;
      s : FIO.PathStrW;
      value : StringsO.CString;
   BEGIN
      //-----
      IF NameValuePairs^.Data = itemSystemSerialNumber THEN
         IF Direction = IOO.dirWrite THEN
            RETURN Sync.arUnsupportedDirection;
         ELSE
            GetLicences( OUT licences );
            IF NOT licences.GetFirst( OUT value, OUT p ) THEN
               value.Clear();
            END;
            Value.String := value;
            RETURN Sync.arCompleted;
         END;

      //-----
      ELSIF NameValuePairs^.Data = itemSystemSuspend THEN
         IF Direction = IOO.dirRead THEN
            RETURN Sync.arUnsupportedDirection;
         ELSE
            // TODO
            FIO.GetModuleDirW( L"", OUT s );
            key.FromOA( suspendKey );
            value := Value.String;
            lec.StoreInfo( s, ADR( cllv.data ), cllv.length, key, value ); // shall be synchronized???
            lec.QueryData( s, L"", ADR( cllv.data ), cllv.length, REF SELF );
            QuerySuspension();
            RETURN Sync.arCompleted;
         END;

      //-----
      ELSE
         RETURN Sync.arCannotStart;
      END;
   END ValueIO;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Expired GET : BOOLEAN;
   BEGIN
      IF _Suspended THEN
         RETURN TRUE;
      ELSE
         RETURN SUPER.Expired;
      END;
   END Expired;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Suspended GET : BOOLEAN;
   BEGIN
      RETURN _Suspended;
   END Suspended;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE QuerySuspension();
   VAR
      value : StringsO.CString;
   BEGIN
      ProductsLock();
      ProductsReset();
      WHILE ProductsMoveNext() DO
         IF CurrentProduct^.Info^.GetOA( suspendKey, OUT value ) THEN
            _Suspended := value.EqualsOA( suspendValue );
         END;
      END;
      ProductsUnlock();
   END QuerySuspension;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE LoadData();
   VAR
      s : FIO.PathStrW;
   BEGIN
      Reset( lec.bhBestCase );
      FIO.GetModuleDirW( L"", OUT s );
      lec.QueryData( s, L"", ADR( cllv.data ), cllv.length, REF SELF );
      QuerySuspension();
   END LoadData;

(*--------------------------------------------------------------------------------*)

BEGIN
   _Suspended := FALSE;
   LoadData();
END CSuspendableResult;

(*================================================================================*)

CONST
   ServiceName = ProductId;

CLASS CKnxSvc( Service.AService ) IMPLEMENTS threadcall.IThreadProcedureCallTarget;
   LOCAL VIRTUAL READONLY PROPERTY
      Name : PWCHAR;
      
   PRIVATE VAR
      Result : POINTER TO CSuspendableResult := NIL;
      LogAppenders : lists.CPtrList;
      ConfigLogger : Log.CBufferedLogger;
      DataLogger : Log.CBufferedLogger; 
      HttpLogger : Log.CLogger;
      NetworkLogger : Log.CLogger; 
      RootDataSource : compositedatasource.TPCompositeDataSource := NIL;
      SystemDataSource : compositedatasource.TPCompositeDataSource := NIL;
      KNX : knxcore.TPKNXServer := NIL;
      Adviser : adviser.TPAdvisedDataSource := NIL;
      SDAP : sdap.TPSDAPServer := NIL;
      XMLS : xmlsocket.TPXMLSocketServer := NIL;
      Web : KnxSvcWeb.CKnxSvcWeb;
      CDI : TControlledDeviceInfo;
      Storage : PersistentStorage.TPPersistentStorageFunction := NIL;
      EqCurve : EquithermicCurve.TPEquithermicCurveFunction := NIL;
      WeekCal : WeekCalendar.TPWeekCalendarFunction := NIL;

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

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CKnxSvc;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROPERTY Name GET : PWCHAR;
   BEGIN
      RETURN PWCHAR( ADR( ServiceName ));
   END Name;

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
   CONST
      snProject = L"project";
         knName = L"name";
      snClientInterface = L"client_interface";
         knSdapPort = L"sdap_port";
         knXmlsPort = L"xml_socket_port";
   VAR
      cfg : INIfile.CINIFile;
      configuration : ARRAY [0..0] OF device.TConfigureItem;
      Data : ARRAY [0..511] OF WCHAR;
      GlobalResult : Sync.TAsyncResult := Sync.arCompleted;
      IA : inetaddr.INETADDR;
      line : CARDINAL;
      LocalResult : Sync.TAsyncResult := Sync.arCompleted;
      pairs : ns.TPNameValuePairs;
      Path : ARRAY [0..260] OF WCHAR;
      port : CARDINAL;
      project : StringsO.CString;
      RS : Registry.CRegistry;
      s1, s2 : StringsO.CString;
      sdapPort : CARDINAL := 6007;
      v : iovalue.Value;
      xmlsPort : CARDINAL := 6006;
   BEGIN
      Debug.WaitUsingLoop();

      // CONFIGURATION
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

      // load listening ports
      IF cfg.SetSection( snClientInterface ) THEN
         IF cfg.GetKeyInt( knSdapPort, OUT line, OUT port ) THEN
            sdapPort := port;
         END;
         IF cfg.GetKeyInt( knXmlsPort, OUT line, OUT port ) THEN
            xmlsPort := port;
         END;
      END; // client interface configuration

      // load project name
      IF NOT cfg.SetSection( snProject ) OR NOT cfg.GetKeyStr( knName, OUT line, OUT project ) THEN
         project.FromOA( L"SmartServer Project" );
      END;

      LogConfig.ConfigureLog( cfg, L"", REF Log.logger()^, REF LogAppenders, OUT line );
      Log.logger()^.LocalTime := TRUE;
      Log.logger()^.SeparateTimeBrackets := TRUE;

      LogConfig.ConfigureLog( cfg, L"datalog", REF DataLogger, REF LogAppenders, OUT line );
      DataLogger.LocalTime := TRUE;
      DataLogger.SeparateTimeBrackets := TRUE;
      
      Log.ConfigureByAppender( REF HttpLogger, Log.logger()^ );
      LogConfig.ConfigureLog( cfg, L"httplog", REF HttpLogger, REF LogAppenders, OUT line );
      HttpLogger.TimeStamps := FALSE;
      HttpLogger.Levels := FALSE;
      HttpLogger.Names := FALSE;

      Log.ConfigureByAppender( REF NetworkLogger, Log.logger()^ );
      LogConfig.ConfigureLog( cfg, L"networklog", REF NetworkLogger, REF LogAppenders, OUT line );
      NetworkLogger.LocalTime := TRUE;
      NetworkLogger.SeparateTimeBrackets := TRUE;
      
      // CONSTRUCTION
      ASSERT( Result = NIL );
      NEW( Result );

      ASSERT( RootDataSource = NIL );
      NEW( RootDataSource );
      RootDataSource^.Init( StringsO.FromOA( L"SmartServer" ));

      ASSERT( KNX = NIL );
      NEW( KNX );
      KNX^.Init( TRUE );
      KNX^.EXEFlag := TRUE;
      KNX^.DataLogger := ADR( DataLogger );
      KNX^.Result := Result;
      configuration[0].Type := device.citIString;
      configuration[0].iString := ADR( s1 );
      LocalResult := KNX^.Configure( configuration, ADR( ConfigLogger ));
      IF GlobalResult = Sync.arCompleted THEN
         GlobalResult := LocalResult;
      END;
      
      ASSERT( Adviser = NIL );
      NEW( Adviser );
      Adviser^.DataSource := RootDataSource;
      Adviser^.Start();

      ASSERT( SDAP = NIL );
      NEW( SDAP );
      SDAP^.DataSource := Adviser;
      IA.Port := sdapPort;
      SDAP^.ListenAddress := IA;
      SDAP^.Init( TRUE );
      SDAP^.CommonLogger := Log.logger();
      SDAP^.ConfigurationLogger := ADR( ConfigLogger );
      SDAP^.NetworkLogger := ADR( NetworkLogger );
      SDAP^.DefaultContext := StringsO.FromOA( L"KNX" );
      
      ASSERT( XMLS = NIL );
      NEW( XMLS );
      XMLS^.DataSource := Adviser;
      IA.Port := xmlsPort;
      XMLS^.ListenAddress := IA;
      XMLS^.Init( TRUE );
      XMLS^.CommonLogger := Log.logger();
      XMLS^.NetworkLogger := ADR( NetworkLogger );
      XMLS^.DefaultContext := StringsO.FromOA( L"KNX" );
      
      ASSERT( Storage = NIL );
      NEW( Storage );
      Storage^.Init( TRUE );
      Storage^.DataSource := Adviser;
      Storage^.Logger := Log.logger();
      Storage^.DefaultStorageFolder := StringsO.FromOA( defaultStorageName );
      KNX^.EventSinks.Subscribe( ADR( Storage^.IKNXServerSink ));
      configuration[0].Type := device.citINIFile;
      configuration[0].iniFile := ADR( cfg );
      LocalResult := Storage^.Configure( configuration, ADR( ConfigLogger ));
      IF GlobalResult = Sync.arCompleted THEN
         GlobalResult := LocalResult;
      END;
      
      ASSERT( EqCurve = NIL );
      NEW( EqCurve );
      EqCurve^.Init( TRUE );
      EqCurve^.DataSource := Adviser;
      EqCurve^.Logger := Log.logger();
      LocalResult := EqCurve^.Configure( configuration, ADR( ConfigLogger ));
      IF LocalResult = Sync.arCompleted THEN
         EqCurve^.Start();
      END;
      IF GlobalResult = Sync.arCompleted THEN
         GlobalResult := LocalResult;
      END;

      ASSERT( WeekCal = NIL );
      NEW( WeekCal );
      WeekCal^.Init( TRUE );
      WeekCal^.DataSource := Adviser;
      WeekCal^.Logger := Log.logger();
      LocalResult := WeekCal^.Configure( configuration, ADR( ConfigLogger ));
      IF LocalResult = Sync.arCompleted THEN
         WeekCal^.Start();
      END;
      IF GlobalResult = Sync.arCompleted THEN
         GlobalResult := LocalResult;
      END;

      // WEB & GLOBAL START
      CDI.Names[0] := PWCHAR( ADR( nameSDAP ));
      CDI.Names[1] := PWCHAR( ADR( nameXMLSocket ));
      CDI.Names[2] := PWCHAR( ADR( nameStorage ));
      CDI.Names[3] := PWCHAR( ADR( nameEqCurve ));
      CDI.Names[4] := PWCHAR( ADR( nameWeekCalendar ));
      CDI.Devices[0] := SDAP;
      CDI.Devices[1] := XMLS;
      CDI.Devices[2] := Storage;
      CDI.Devices[3] := EqCurve;
      CDI.Devices[4] := WeekCal;

      // NAMESPACE
      ASSERT( SystemDataSource = NIL );
      NEW( SystemDataSource );
      SystemDataSource^.Init( StringsO.FromOA( nameSystem ));
      v.Dispose();
      v.Boolean := GlobalResult <> Sync.arCompleted;
      SystemDataSource^.NS()^.DefineStorageValue( StringsO.FromOA( nameConfigurationError ), iovalue.vtBoolean, iovalue.flagsDefaultSWRO, ADR( v ), 0, NIL, NIL, OUT pairs );

      v.Dispose();
      v.String := s1;
      SystemDataSource^.NS()^.DefineStorageValue( StringsO.FromOA( nameConfigurationFile ), iovalue.vtString, iovalue.flagsDefaultSWRO, ADR( v ), 0, NIL, NIL, OUT pairs );

      v.Dispose();
      v.String := project;
      SystemDataSource^.NS()^.DefineStorageValue( StringsO.FromOA( nameProject ), iovalue.vtString, iovalue.flagsDefaultSWRO, ADR( v ), 0, NIL, NIL, OUT pairs );

      SystemDataSource^.NS()^.DefineIOValue( StringsO.FromOA( nameLicensingSerialNumber ), REF Result^, itemSystemSerialNumber, NIL, OUT pairs );
      SystemDataSource^.NS()^.DefineIOValue( StringsO.FromOA( nameLicensingSuspend ), REF Result^, itemSystemSuspend, NIL, OUT pairs );

      RootDataSource^.JoinDataSource( SystemDataSource );
      RootDataSource^.JoinDataSource( KNX ); // SmartServer.KNX.1/5/8

      // START
      IF Web.Init( L"/SmartServer", cfg, Result, RootDataSource, KNX, CDI.Names, CDI.Devices, ADR( ConfigLogger ), ADR( DataLogger ), ADR( HttpLogger )) THEN
         Web.Run();
      END;
      IF GlobalResult = Sync.arCompleted THEN
         KNX^.Start();
      END;

      Storage^.Start();
      SDAP^.Start();
      XMLS^.Start();

      SetServiceState( Service.ssRunning, 0 );
   END _OnStart;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE _OnPause();
   BEGIN
      IF KNX = NIL THEN
         LogEvent( -1, L"Svc.OnPause called for KNX = NIL" );
      ELSE
         XMLS^.Stop();
         SDAP^.Stop();
         WeekCal^.Stop();
         Storage^.Stop();
         KNX^.Stop();
         EqCurve^.Stop();
      END;

      SetServiceState( Service.ssPaused, 0 );
   END _OnPause;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE _OnContinue();
   BEGIN
      IF KNX = NIL THEN
         LogEvent( -1, L"Svc.OnContinue called for KNX = NIL" );
      ELSE
         EqCurve^.Start();
         KNX^.Start();
         Storage^.Start();
         WeekCal^.Start();
         SDAP^.Start();
         XMLS^.Start();
      END;

      SetServiceState( Service.ssRunning, 0 );
   END _OnContinue;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE _OnStop();
   BEGIN
      Web.Stop();
   
      IF SDAP <> NIL THEN
         SDAP^.Stop();
         DISPOSE( SDAP );
      END;
   
      IF XMLS <> NIL THEN
         XMLS^.Stop();
         DISPOSE( XMLS );
      END;
   
      IF Storage <> NIL THEN
         KNX^.EventSinks.Unsubscribe( ADR( Storage^.IKNXServerSink ));
         Storage^.Stop();
         DISPOSE( Storage );
      END;

      IF KNX <> NIL THEN
         IF RootDataSource <> NIL THEN
            RootDataSource^.LeaveDataSource( KNX );
         END;
         KNX^.Stop();
         KNX^.Dispose();
         DISPOSE( KNX );
      END;

      IF WeekCal <> NIL THEN
         WeekCal^.Stop();
         WeekCal^.Dispose();
         DISPOSE( WeekCal );
      END;

      IF EqCurve <> NIL THEN
         EqCurve^.Stop();
         EqCurve^.Dispose();
         DISPOSE( EqCurve );
      END;

      IF Adviser <> NIL THEN
         Adviser^.DataSource := NIL;
         Adviser^.Stop();
         DISPOSE( Adviser );
      END;

      IF SystemDataSource <> NIL THEN
         IF RootDataSource <> NIL THEN
            RootDataSource^.LeaveDataSource( SystemDataSource );
         END;
         SystemDataSource^.Dispose();
         DISPOSE( SystemDataSource );
      END;

      IF RootDataSource <> NIL THEN
         RootDataSource^.Dispose();
         DISPOSE( RootDataSource );
      END;

      IF Result <> NIL THEN
         Result^.Release();
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
