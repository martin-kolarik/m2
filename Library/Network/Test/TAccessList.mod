MODULE TAccessList;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   AccessList,
   inetaddr,
   log,
   netinit,
   Strings,
   StringsO,
   sync,
   test,
   testimpl,
   threadpool,
   SCmsgqueuethread;
  
(*===========================================================================*)

TYPE
   TPTest = POINTER TO CTest;

(*---------------------------------------------------------------------------*)

CLASS CTest IMPLEMENTS test.ITest;
   PUBLIC VAR
      Host : test.TPHost := NIL;

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
END CTest;

(*===========================================================================*)

VAR
   Test : CTest;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CTest;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   VAR
      AL : AccessList.CAccessList;
      Failure : BOOLEAN := FALSE;
      ia : inetaddr.INETADDR;
   BEGIN
      SELF.Host := Host;

      SCmsgqueuethread.Startup();
      threadpool.Startup();
      netinit.Startup();

      Host^.StartPhase( L"Filter IP addresses" );
      
      AL.Reset();
      AL.Policy := AccessList.actDeny;
      
      ia.FromOA( L"192.169.1.2", 0 );
      AL.AddRule( AccessList.actAllow, ia, 14 );

      AL.AddRuleOA( AccessList.actDeny, L"192.168.0.63/26" );
      
      ia.FromOA( L"192.168.0.100", 0 ); // allowed
      IF NOT AL.AllowedForAddress( ia ) THEN
         Failure := TRUE;
      END;

      ia.FromOA( L"192.168.1.128", 0 ); // allowed
      IF NOT AL.AllowedForAddress( ia ) THEN
         Failure := TRUE;
      END;

      ia.FromOA( L"192.169.1.128", 0 ); // allowed
      IF NOT AL.AllowedForAddress( ia ) THEN
         Failure := TRUE;
      END;

      ia.FromOA( L"192.172.1.128", 0 ); // disallowed
      IF AL.AllowedForAddress( ia ) THEN
         Failure := TRUE;
      END;

      ia.FromOA( L"192.168.0.1", 0 ); // disallowed
      IF AL.AllowedForAddress( ia ) THEN
         Failure := TRUE;
      END;

      Host^.StopPhaseWithResult( NOT Failure );

      netinit.Cleanup();
      threadpool.Cleanup();
      SCmsgqueuethread.Cleanup();

      RETURN test.trUnknown;
   END Run;
   
(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"Network::AccessList", ADR( Test ));
END CTest;

(*===========================================================================*)

END TAccessList.
