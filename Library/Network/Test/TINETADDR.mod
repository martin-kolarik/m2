MODULE TINETADDR;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
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
      Expect : ARRAY [0..511] OF WCHAR;
      ia : inetaddr.INETADDR;
      Failure1, Failure2 : BOOLEAN := FALSE;
      String : ARRAY [0..511] OF WCHAR;
   BEGIN
      SELF.Host := Host;

      SCmsgqueuethread.Startup();
      threadpool.Startup();
      netinit.Startup();

      Host^.StartPhase( L"Special addresses V4" );
      
      Expect := L"0.0.0.0";
      ia.SetV4( inetaddr.saEmpty );
      ia.GetAddressOA( TRUE, OUT String );
      Host^.Log^.LogSSS( log.dlcInfo, L"", Expect, L": ", String );

      Expect := L"127.0.0.1";
      ia.SetV4( inetaddr.saLoopback );
      ia.GetAddressOA( TRUE, OUT String );
      Host^.Log^.LogSSS( log.dlcInfo, L"", Expect, L": ", String );

      ia.SetV4( inetaddr.saLocalLink );
      ia.GetAddressOA( TRUE, OUT String );
      Host^.Log^.LogSSS( log.dlcInfo, L"", Expect, L": ", String );

      ia.SetV4( inetaddr.saLocalLinkRandom );
      ia.GetAddressOA( TRUE, OUT String );
      Host^.Log^.LogSSS( log.dlcInfo, L"", Expect, L": ", String );

      IF Failure1 THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      Host^.StartPhase( L"Special addresses V6" );
      
      Expect := L"::";
      ia.SetV6( inetaddr.saEmpty );
      ia.GetAddressOA( TRUE, OUT String );
      Host^.Log^.LogSSS( log.dlcInfo, L"", Expect, L": ", String );

      Expect := L"::1";
      ia.SetV6( inetaddr.saLoopback );
      ia.GetAddressOA( TRUE, OUT String );
      Host^.Log^.LogSSS( log.dlcInfo, L"", Expect, L": ", String );

      Expect := L"fe80::1";
      ia.SetV6( inetaddr.saLocalLink );
      ia.GetAddressOA( TRUE, OUT String );
      Host^.Log^.LogSSS( log.dlcInfo, L"", Expect, L": ", String );

      Expect := L"fe80::abcd:abcd";
      ia.SetV6( inetaddr.saLocalLinkRandom );
      ia.GetAddressOA( TRUE, OUT String );
      Host^.Log^.LogSSS( log.dlcInfo, L"", Expect, L": ", String );

      Expect := L"fc00::1";
      ia.SetV6( inetaddr.saPrivateRandom );
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
      threadpool.Cleanup();
      SCmsgqueuethread.Cleanup();

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
