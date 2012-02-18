MODULE TClientStress;

FROM Debug IMPORT
   AssertionW;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   adviser,
   device,
   inetaddr,
   IOO,
   io,
   iovalue,
   iplugin,
   log,
   netsocket,
   ns,
   rawconnection,
   scinit,
   sdap,
   StringsO,
   sync,
   test,
   testimpl,
   thread;
   
IMPORT
   windows;   
  
(*===========================================================================*)

TYPE
   TPTest = POINTER TO CTest;

(*---------------------------------------------------------------------------*)

CLASS CClient IMPLEMENTS thread.IRunnable;
   LOCAL VAR
      Test : TPTest;
   // IRunnable
   INTERNAL VIRTUAL PROCEDURE OnRun( Restarted : BOOLEAN; CONST Helper : thread.IRunnableHelper ) : CARDINAL;
   // SELF
   PRIVATE VAR
      Connection : rawconnection.ClientTCPConnection;
END CClient;

(*---------------------------------------------------------------------------*)

CLASS CTest IMPLEMENTS test.ITest, device.IDataSource;

   PUBLIC VAR
      Host : test.TPHost := NIL;
      Server : sdap.CSDAPServer;
      DataSource : adviser.CAdvisedDataSource;
      Clients : ARRAY [0..9] OF CClient;
      Threads : ARRAY [0..9] OF thread.Thread;

   // ITest
   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;

   // IDevice
   PUBLIC VIRTUAL READONLY PROPERTY
      DataSourceCapabilities : device.TCapabilities;

   PUBLIC VIRTUAL PROCEDURE Configure( CONST Source : ARRAY OF device.TConfigureItem; CONST Log : log.TPLogger ) : sync.TAsyncResult;

   PUBLIC VIRTUAL PROCEDURE NS() : ns.TPNamespace;
   PUBLIC VIRTUAL PROCEDURE AdviseSource() : ns.TPAdviseSource;
   
   // IMapper
   PUBLIC VIRTUAL PROCEDURE NameToHash( CONST Name : StringsO.IString; OUT Hash : ns.THash ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE HashToName( CONST Hash : ns.THash; OUT Name : StringsO.IString ) : BOOLEAN;

   // self
   PRIVATE PROCEDURE WaitForMessages( count : CARDINAL );
END CTest;

(*===========================================================================*)

CLASS IMPLEMENTATION CClient;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnRun( Restarted : BOOLEAN; CONST Helper : thread.IRunnableHelper ) : CARDINAL;
   CONST
      LIMIT = 10000000;
   VAR
      count : INTEGER; 
      l : INTEGER;
      limit : INTEGER;
   BEGIN
      IF Test^.Host^.FastEvaluation THEN
         limit := 100;
      ELSE
         limit := LIMIT;
      END;
   
      FOR count := 0 TO limit-1 DO
         IF Connection.Open( "10.78.0.251:6007", 6007, TRUE, netsocket.FORSAFETY ) = sync.arCompleted THEN
         // IF Connection.Open( "127.0.0.1:3007", 3007, TRUE, netsocket.FORSAFETY ) = sync.arCompleted THEN
            Connection.Stream^.WriteOA( C"advise all" + 13C + 10C, OUT l, netsocket.FORSAFETY );
            Connection.Stream^.WriteOA( C"set 3/3/1 true" + 13C + 10C, OUT l, netsocket.FORSAFETY );
            Connection.Stream^.WriteOA( C"set 3/3/2 true" + 13C + 10C, OUT l, netsocket.FORSAFETY );
            Connection.Stream^.WriteOA( C"set 3/3/3 true" + 13C + 10C, OUT l, netsocket.FORSAFETY );
            Connection.Stream^.WriteOA( C"set 3/3/4 true" + 13C + 10C, OUT l, netsocket.FORSAFETY );
            Connection.Stream^.WriteOA( C"set 3/3/5 true" + 13C + 10C, OUT l, netsocket.FORSAFETY );
            Connection.Stream^.WriteOA( C"set 3/3/6 true" + 13C + 10C, OUT l, netsocket.FORSAFETY );
            Connection.Stream^.WriteOA( C"set 3/3/7 true" + 13C + 10C, OUT l, netsocket.FORSAFETY );
            Connection.Stream^.WriteOA( C"set 3/3/8 true" + 13C + 10C, OUT l, netsocket.FORSAFETY );
            Connection.Stream^.WriteOA( C"set 3/3/9 true" + 13C + 10C, OUT l, netsocket.FORSAFETY );
            Connection.Stream^.WriteOA( C"set 3/3/0 true" + 13C + 10C, OUT l, netsocket.FORSAFETY );
            IF count MOD 2 = 1 THEN
              sync.Sleep( 10 );
            END;
            Connection.Close();
         END;
         sync.Sleep( 25 + ( count MOD 4 ) * 30 );
      END; // FOR
      RETURN 0;
   END OnRun;

(*---------------------------------------------------------------------------*)

END CClient;

(*===========================================================================*)

VAR
   Test : CTest;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CTest;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   VAR
      ia : inetaddr.INETADDR;
      Failure : BOOLEAN := FALSE;
      i : CARDINAL;
   BEGIN
      SELF.Host := Host;

      scinit.Startup();

      DataSource.DataSource := ADR( SELF );
      
      ia.FromOA( L"0.0.0.0:3007", 0 );
      Server.Init( TRUE );      
      Server.ListenAddress := ia;
      Server.DataSource := ADR( DataSource );
      Server.Start();
      
      Host^.StartPhase( L"Stress connections to SDAP port" );
      
      FOR i := 0 TO HIGH( Clients ) DO
         Clients[i].Test := ADR( SELF );
         Threads[i].RunWithRunnable( ADR( Clients[i] ));
      END;
      
      WaitForMessages( 2500 );
      
      FOR i := 0 TO HIGH( Clients ) DO
         Threads[i].Stop( FALSE );
      END;
      FOR i := 0 TO HIGH( Clients ) DO
         Threads[i].WaitStop( sync.FOREVER );
      END;

      Host^.StopPhaseWithResult( TRUE );

      Server.Stop();

      scinit.Cleanup();

      IF Failure THEN
         RETURN test.trFailure;
      ELSE
         RETURN test.trSuccess;
      END;
   END Run;
   
(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY DataSourceCapabilities GET : device.TCapabilities;
   BEGIN
      RETURN device.TCapabilities{};
   END DataSourceCapabilities;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Configure( CONST Source : ARRAY OF device.TConfigureItem; CONST Log : log.TPLogger ) : sync.TAsyncResult;
   BEGIN
      RETURN sync.arCannotStart;
   END Configure;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE NS() : ns.TPNamespace;
   BEGIN
      RETURN NIL;
   END NS;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE AdviseSource() : ns.TPAdviseSource;
   BEGIN
      RETURN NIL;
   END AdviseSource;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE NameToHash( CONST Name : StringsO.IString; OUT Hash : ns.THash ) : BOOLEAN;
   BEGIN
      Hash := 1;
      RETURN TRUE;
   END NameToHash;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE HashToName( CONST Hash : ns.THash; OUT Name : StringsO.IString ) : BOOLEAN;
   BEGIN
      Name.FromOA( L"1" );
      RETURN TRUE;
   END HashToName;

(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE WaitForMessages( count : CARDINAL );
   VAR
      i : CARDINAL := count;
      msg : windows.MSG;
   BEGIN
      WHILE i > 0 DO
         WHILE windows.PeekMessage( ADR( msg ), NIL, 0, 0, windows.PM_REMOVE ) = windows.True DO
            windows.DispatchMessage( ADR( msg ));
         END; // WHILE
         DEC( i );
         windows.Sleep( 1 );
      END; // WHILE
   END WaitForMessages;

(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"KnxSvc::ClientStress", ADR( Test ));
END CTest;

(*===========================================================================*)

END TClientStress.
