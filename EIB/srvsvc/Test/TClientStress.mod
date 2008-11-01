MODULE TClientStress;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   log,
   netsocket,
   rawconnection,
   scinit,
   sync,
   test,
   testimpl,
   thread;
  
(*===========================================================================*)

TYPE
   TPTest = POINTER TO CTest;

(*---------------------------------------------------------------------------*)

CLASS CClient IMPLEMENTS thread.IRunnable;
   // IRunnable
   INTERNAL VIRTUAL PROCEDURE OnRun() : CARDINAL;
   // SELF
   PRIVATE VAR
      Connection : rawconnection.TCPConnection;
END CClient;

(*---------------------------------------------------------------------------*)

CLASS CTest IMPLEMENTS test.ITest;
   PUBLIC VAR
      Host : test.TPHost := NIL;
      Clients : ARRAY [0..9] OF CClient;
      Threads : ARRAY [0..9] OF thread.Thread;
   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
END CTest;

(*===========================================================================*)

CLASS IMPLEMENTATION CClient;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnRun() : CARDINAL;
   CONST
      COUNT = 10000000;
   VAR
      count : INTEGER; 
      l : INTEGER;
   BEGIN
      FOR count := 0 TO COUNT-1 DO
         IF Connection.Open( "10.0.1.129:6007", TRUE, netsocket.FORSAFETY ) = sync.arCompleted THEN
            Connection.Stream^.WriteOA( L"set 3/3/3 true" + 13W + 10W, OUT l, netsocket.FORSAFETY );
            Connection.Close();
         END;
         sync.Sleep( 150 + ( count MOD 4 ) * 50 );
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
      Failure : BOOLEAN := FALSE;
      i : CARDINAL;
   BEGIN
      SELF.Host := Host;

      scinit.Startup();

      Host^.StartPhase( L"Stress connections to SDAP port" );
      
      FOR i := 0 TO HIGH( Clients ) DO
         Threads[i].RunWithRunnable( ADR( Clients[i] ));
      END;
      FOR i := 0 TO HIGH( Clients ) DO
         Threads[i].WaitStop( sync.FOREVER );
      END;

      Host^.StopPhaseWithResult( test.trSuccess );

      scinit.Cleanup();

      IF Failure THEN
         RETURN test.trFailure;
      ELSE
         RETURN test.trSuccess;
      END;
   END Run;
   
(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"EibSrv::ClientStress", ADR( Test ));
END CTest;

(*===========================================================================*)

END TClientStress.