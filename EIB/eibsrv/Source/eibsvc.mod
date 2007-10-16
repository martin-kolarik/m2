MODULE eibsvc;

(*================================================================================*)

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;
   
IMPORT
   eibsrv,
   FIO,
   netinit,
   Registry,
   Service,
   Strings,
   StringsO;
   
IMPORT
  windows;

(*================================================================================*)

CONST
   keyStorage = L"Storage";
   keyDefaultConfiguration = L"Default configuration";
   defaultConfiguration = L"default.cfg";

(*================================================================================*)

CLASS CEibSvc( Service.AService );
   LOCAL VIRTUAL READONLY PROPERTY
      Name : PWCHAR;
      
   PRIVATE VAR
      EIB : eibsrv.TPEIBServer := NIL;

   INTERNAL VIRTUAL PROCEDURE OnStart();
   INTERNAL VIRTUAL PROCEDURE OnPause();
   INTERNAL VIRTUAL PROCEDURE OnContinue();
   INTERNAL VIRTUAL PROCEDURE OnStop();
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

   INTERNAL VIRTUAL PROCEDURE OnStart();
   VAR
      Data : ARRAY [0..511] OF WCHAR;
      line : CARDINAL;
      Path : ARRAY [0..255] OF WCHAR;
      RS : Registry.CRegistry;
      s1, s2 : StringsO.CString;
   BEGIN
      netinit.Startup();
      
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
         FIO.GetModuleDirW( EMIT( %exe ), OUT Data );
         s1.FromOA( Data );
      END;
      IF s2.Empty THEN
         s2.FromOA( defaultConfiguration );
      END;
      
      ASSERT( EIB = NIL );
      NEW( EIB ); // ^.Init();
      EIB^.Init( L"EibSrv", NIL, NIL );

      s1.AppendOA( L"\" ); s1.Append( s2 );
      IF EIB^.ReadParameters( s1, OUT s2, OUT line ) THEN
         EIB^.Run( TRUE, TRUE );
      ELSE
         s2.AppendOA( L", line: " ); s1.FromCARD32( line, 10 ); s2.Append( s1 );
         LogEvent( -1, OA( s2.Length-1, s2.rawData ));
         EIB^.Run( FALSE, TRUE );
      END;

      SetServiceState( Service.ssRunning, 0 );
   END OnStart;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnPause();
   BEGIN
      IF EIB = NIL THEN
         LogEvent( -1, L"Svc.OnPause called for EIB = NIL" );
      ELSE
         EIB^.Stop( TRUE, TRUE );
      END;

      SetServiceState( Service.ssPaused, 0 );
   END OnPause;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnContinue();
   BEGIN
      IF EIB = NIL THEN
         LogEvent( -1, L"Svc.OnContinue called for EIB = NIL" );
      ELSE
         EIB^.Run( TRUE, TRUE );
      END;

      SetServiceState( Service.ssRunning, 0 );
   END OnContinue;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnStop();
   BEGIN
      IF EIB <> NIL THEN
         EIB^.Stop( TRUE, TRUE );
         EIB^.Dispose();
         DISPOSE( EIB );
      END;

      netinit.Cleanup();

      SetServiceState( Service.ssStopped, 0 );
   END OnStop;

(*--------------------------------------------------------------------------------*)

BEGIN
   Threaded := TRUE;
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

END eibsvc.