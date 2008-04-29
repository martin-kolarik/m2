MODULE TINETADDR;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   log,
   netinit,
   netsocket,
   Strings,
   StringsO,
   sync,
   test,
   testimpl;
  
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
      Expect : ARRAY [0..511] OF WCHAR;
      ia : netsocket.INETADDR;
      Failure1, Failure2 : BOOLEAN := FALSE;
      String : ARRAY [0..511] OF WCHAR;
   BEGIN
      SELF.Host := Host;
      netinit.Startup();

      Host^.StartPhase( L"Special addresses V4" );
      
      Expect := L"0.0.0.0";
      ia.SetV4( netsocket.saEmpty );
      ia.GetAddressOA( TRUE, OUT String );
      Host^.Log^.LogSSS( log.dlcInfo, L"", Expect, L": ", String );

      Expect := L"127.0.0.1";
      ia.SetV4( netsocket.saLoopback );
      ia.GetAddressOA( TRUE, OUT String );
      Host^.Log^.LogSSS( log.dlcInfo, L"", Expect, L": ", String );

      ia.SetV4( netsocket.saLocalLink );
      ia.GetAddressOA( TRUE, OUT String );
      Host^.Log^.LogSSS( log.dlcInfo, L"", Expect, L": ", String );

      ia.SetV4( netsocket.saLocalLinkRandom );
      ia.GetAddressOA( TRUE, OUT String );
      Host^.Log^.LogSSS( log.dlcInfo, L"", Expect, L": ", String );

      IF Failure1 THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      Host^.StartPhase( L"Special addresses V6" );
      
      Expect := L"::";
      ia.SetV6( netsocket.saEmpty );
      ia.GetAddressOA( TRUE, OUT String );
      Host^.Log^.LogSSS( log.dlcInfo, L"", Expect, L": ", String );

      Expect := L"::1";
      ia.SetV6( netsocket.saLoopback );
      ia.GetAddressOA( TRUE, OUT String );
      Host^.Log^.LogSSS( log.dlcInfo, L"", Expect, L": ", String );

      Expect := L"fe80::1";
      ia.SetV6( netsocket.saLocalLink );
      ia.GetAddressOA( TRUE, OUT String );
      Host^.Log^.LogSSS( log.dlcInfo, L"", Expect, L": ", String );

      Expect := L"fe80::abcd:abcd";
      ia.SetV6( netsocket.saLocalLinkRandom );
      ia.GetAddressOA( TRUE, OUT String );
      Host^.Log^.LogSSS( log.dlcInfo, L"", Expect, L": ", String );

      Expect := L"fc00::1";
      ia.SetV6( netsocket.saPrivateRandom );
      ia.GetAddressOA( TRUE, OUT String );
      Host^.Log^.LogSSS( log.dlcInfo, L"", Expect, L": ", String );

      IF Failure1 THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      Host^.StartPhase( L"Some other addresses" );
      
      Expect := L"10.0.1.132:1111";
      ia.SetAddressOA( Expect, 0 );
      ia.GetAddressOA( TRUE, OUT String );
      Host^.Log^.LogSSS( log.dlcInfo, L"", Expect, L": ", String );
      ia.GetAddressOA( FALSE, OUT String );
      Host^.Log^.LogSSS( log.dlcInfo, L"", Expect, L": ", String );
      Host^.Log^.LogSC( log.dlcInfo, L"", L"  port: ", ia.Port );

      Expect := L"[2001:1:1::a0:80]:1023";
      ia.SetAddressOA( Expect, 0 );
      ia.GetAddressOA( TRUE, OUT String );
      Host^.Log^.LogSSS( log.dlcInfo, L"", Expect, L": ", String );
      ia.GetAddressOA( FALSE, OUT String );
      Host^.Log^.LogSSS( log.dlcInfo, L"", Expect, L": ", String );
      Host^.Log^.LogSC( log.dlcInfo, L"", L"  port: ", ia.Port );

      IF Failure1 THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      netinit.Cleanup();
      IF Failure1 OR Failure2 THEN
         RETURN test.trFailure;
      ELSE
         RETURN test.trSuccess;
      END;
   END Run;
   
(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"Network::INETADDR", ADR( Test ));
END CTest;

(*===========================================================================*)

END TINETADDR.
