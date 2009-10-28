MODULE TClientStress;

FROM Debug IMPORT
   Assertion;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   adviser,
   device,
   inetaddr,
   io,
   iobject,
   log,
   netsocket,
   ns,
   rawconnection,
   scinit,
   sdap,
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
   // IRunnable
   INTERNAL VIRTUAL PROCEDURE OnRun( CONST Helper : thread.IRunnableHelper ) : CARDINAL;
   // SELF
   PRIVATE VAR
      Connection : rawconnection.TCPConnection;
END CClient;

(*---------------------------------------------------------------------------*)

CLASS CTest IMPLEMENTS test.ITest, device.IDevice;

   PUBLIC VAR
      Host : test.TPHost := NIL;
      Server : sdap.CSDAPServer;
      Device : adviser.CAdvisedDevice;
      Clients : ARRAY [0..9] OF CClient;
      Threads : ARRAY [0..9] OF thread.Thread;

   // ITest
   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;

   // IDevice.IObject
   PUBLIC VIRTUAL READONLY PROPERTY
      Type : iobject.TObjectType;
   PUBLIC VIRTUAL PROPERTY
      Library : iobject.TPLibrary;
   PUBLIC VIRTUAL PROCEDURE OnDispose(); // meant not as Command, but as Callback, usually, destroying of object is done with ReleaseObject of some loader.
   
   // IDevice
   PUBLIC VIRTUAL READONLY PROPERTY
      DeviceCapabilities : device.TCapabilities;

	PUBLIC VIRTUAL PROCEDURE Configure( CONST Source : ARRAY OF device.TConfigureItem; CONST Log : log.TPLogger ) : sync.TAsyncResult;

   PUBLIC VIRTUAL PROCEDURE Mapper() : ns.TPMapper;
	PUBLIC VIRTUAL PROCEDURE NS() : ns.TPns;

	PUBLIC VIRTUAL PROCEDURE IO() : io.TPIO;

   // self
   PRIVATE PROCEDURE WaitForMessages( count : CARDINAL );
END CTest;

(*===========================================================================*)

CLASS IMPLEMENTATION CClient;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnRun( CONST Helper : thread.IRunnableHelper ) : CARDINAL;
   CONST
      COUNT = 10000000;
   VAR
      count : INTEGER; 
      l : INTEGER;
   BEGIN
      FOR count := 0 TO COUNT-1 DO
         // IF Connection.Open( "192.168.1.10:6007", TRUE, netsocket.FORSAFETY ) = sync.arCompleted THEN
         IF Connection.Open( "127.0.0.1:3007", TRUE, netsocket.FORSAFETY ) = sync.arCompleted THEN
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
      
      i := 0; WHILE i = 0 DO END;
      
      ia.FromOA( L"0.0.0.0:3007", 0 );
      Server.ListenAddress := ia;
      Server.Start();

      Host^.StartPhase( L"Stress connections to SDAP port" );
      
      FOR i := 0 TO HIGH( Clients ) DO
         Threads[i].RunWithRunnable( ADR( Clients[i] ));
      END;
      
      WaitForMessages( -1 );
      
      FOR i := 0 TO HIGH( Clients ) DO
         Threads[i].Stop( FALSE );
      END;
      FOR i := 0 TO HIGH( Clients ) DO
         Threads[i].WaitStop( sync.FOREVER );
      END;

      Host^.StopPhaseWithResult( test.trSuccess );

      Server.Stop();

      scinit.Cleanup();

      IF Failure THEN
         RETURN test.trFailure;
      ELSE
         RETURN test.trSuccess;
      END;
   END Run;
   
(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Type GET : iobject.TObjectType;
   BEGIN
      RETURN iobject.otSingleton;
   END Type;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Library GET : iobject.TPLibrary;
   BEGIN
      RETURN NIL;
   END Library;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Library SET( Value : iobject.TPLibrary );
   BEGIN
   END Library;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnDispose(); // meant not as Command, but as Callback, usually, destroying of object is done with ReleaseObject of some loader.
   BEGIN
   END OnDispose;
   
(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY DeviceCapabilities GET : device.TCapabilities;
   BEGIN
      RETURN device.TCapabilities{};
   END DeviceCapabilities;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE Configure( CONST Source : ARRAY OF device.TConfigureItem; CONST Log : log.TPLogger ) : sync.TAsyncResult;
	BEGIN
	   RETURN sync.arCannotStart;
	END Configure;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Mapper() : ns.TPMapper;
   BEGIN
      RETURN NIL;
   END Mapper;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE NS() : ns.TPns;
   BEGIN
      RETURN NIL;
   END NS;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE IO() : io.TPIO;
   BEGIN
      RETURN NIL;
   END IO;

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
   testimpl.tests()^.AddTest( L"EibSrv::ClientStress", ADR( Test ));
END CTest;

(*===========================================================================*)

END TClientStress.