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
      
      ia.SetAddressOA( L"192.169.1.2", 0 );
      AL.AddRule( AccessList.actAllow, ia, 14 );

      AL.AddRuleOA( AccessList.actDeny, L"192.168.0.63/26" );
      
      ia.SetAddressOA( L"192.168.0.100", 0 ); // allowed
      IF NOT AL.AllowedForAddress( ia ) THEN
         Failure := TRUE;
      END;

      ia.SetAddressOA( L"192.168.1.128", 0 ); // allowed
      IF NOT AL.AllowedForAddress( ia ) THEN
         Failure := TRUE;
      END;

      ia.SetAddressOA( L"192.169.1.128", 0 ); // allowed
      IF NOT AL.AllowedForAddress( ia ) THEN
         Failure := TRUE;
      END;

      ia.SetAddressOA( L"192.172.1.128", 0 ); // disallowed
      IF AL.AllowedForAddress( ia ) THEN
         Failure := TRUE;
      END;

      ia.SetAddressOA( L"192.168.0.1", 0 ); // disallowed
      IF AL.AllowedForAddress( ia ) THEN
         Failure := TRUE;
      END;

      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      netinit.Cleanup();
      threadpool.Cleanup();
      SCmsgqueuethread.Cleanup();

      IF Failure THEN
         RETURN test.trFailure;
      ELSE
         RETURN test.trSuccess;
      END;
   END Run;
   
(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"Network::AccessList", ADR( Test ));
END CTest;

(*===========================================================================*)

END TAccessList.
