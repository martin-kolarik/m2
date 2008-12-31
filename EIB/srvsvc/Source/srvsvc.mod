MODULE srvsvc;

(*================================================================================*)

FROM Debug IMPORT
   Assertion;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   adviser,
   cllv,
   EibSrvWeb,
   FIO,
   FIOO,
   inetaddr,
   Log,
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
      
   PRIVATE VAR
      EIB : srvcore.TPEIBServer := NIL;
      Adviser : adviser.TPAdvisedDevice := NIL;
      SDAP : sdap.TPSDAPServer := NIL;
      XMLS : xmlsocket.TPXMLSocketServer := NIL;
      Web : EibSrvWeb.CEibSrvWeb;

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
      Data : ARRAY [0..511] OF WCHAR;
      IA : inetaddr.INETADDR;
      line : CARDINAL;
      Path : ARRAY [0..255] OF WCHAR;
      RS : Registry.CRegistry;
      s1, s2 : StringsO.CString; 
   BEGIN
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
      
      ASSERT( EIB = NIL );
      NEW( EIB );
      EIB^.Init( TRUE );
      EIB^.EXEFlag := TRUE;
      EIB^.cllvData := ADR( cllv.data );
      EIB^.cllvLength := cllv.length;

      FIOO.PathAdd( REF s1, s2 );
      IF EIB^.LoadConfiguration( s1, OUT s2, OUT line ) THEN
         EIB^.Run();
      ELSE
         s2.AppendOA( L", line: " ); s1.FromCARD32( line, 10 ); s2.Append( s1 );
         LogEvent( -1, OA( s2.Length-1, s2.rawData ));
      END;
      
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
      SDAP^.Start();
      
      ASSERT( XMLS = NIL );
      NEW( XMLS );
      XMLS^.Device := Adviser;
      IA.Port := 6006;
      XMLS^.ListenAddress := IA;
      XMLS^.Init( TRUE );
      XMLS^.Start();
      
      Web.Init( 6005, L"/SmartServer", EIB );
      Web.Run();

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
         EIB^.Run();
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

      // do this sooner than scinit.Cleanup, because scinit.Cleanup is called from different thread
      netinit.Cleanup();

      SetServiceState( Service.ssStopped, 0 );
   END _OnStop;

(*--------------------------------------------------------------------------------*)

BEGIN
END CEibSvc;

(*================================================================================*)

VAR
   EibSvc : CEibSvc;

#save, call( convention => cdecl )
PROCEDURE wmain( argc : CARDINAL; argp, envp : ADDRESS ) : CARDINAL;
#restore
VAR
   PService : Service.TPService := ADR( EibSvc );
BEGIN
   Service.Run( OA( 0, ADR( PService )), FALSE, 0 );
   RETURN 0;
END wmain;

(*================================================================================*)

END srvsvc.