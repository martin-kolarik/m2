MODULE StartupCleanup;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   inetaddr,
   log,
   netinit,
   netpool,
   netsocket,
   netsrv,
   sync,
   test,
   testimpl,
   threadpool,
   windows;
  
(*===========================================================================*)

CLASS CTest IMPLEMENTS test.ITest;
   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
END CTest;

(*===========================================================================*)

VAR
   TestStartup : CTest;
   TestCleanup : CTest;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CTest;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   BEGIN
      IF ADR( TestStartup ) = ADR( SELF ) THEN
         threadpool.Startup();
         netinit.Startup();
      ELSE
         threadpool.Cleanup();
         netinit.Cleanup();
      END;
      RETURN test.trSuccess;
   END Run;

(*---------------------------------------------------------------------------*)

BEGIN
   IF ADR( TestStartup ) = ADR( SELF ) THEN
      testimpl.tests()^.AddTest( L"Network::Startup", ADR( TestStartup ));
   ELSE
      testimpl.tests()^.AddTest( L"Network::Cleanup", ADR( TestCleanup ));
   END;
END CTest;

(*===========================================================================*)

END StartupCleanup.