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
      Failure1 : BOOLEAN := FALSE;
      String : ARRAY [0..511] OF WCHAR;
   BEGIN
      SELF.Host := Host;

      SCmsgqueuethread.Startup();
      threadpool.Startup();
      netinit.Startup();

      Host^.StartPhase( L"Special addresses V4" );
      
      Expect := L"0.0.0.0";
      ia.SetV4( inetaddr.saEmpty );
      ia.ToOA( TRUE, OUT String );
      Host^.Log^.LogSSS( log.lcInfo, 0, L"", Expect, L": ", String );

      Expect := L"127.0.0.1";
      ia.SetV4( inetaddr.saLoopback );
      ia.ToOA( TRUE, OUT String );
      Host^.Log^.LogSSS( log.lcInfo, 0, L"", Expect, L": ", String );

      ia.SetV4( inetaddr.saLocalLink );
      ia.ToOA( TRUE, OUT String );
      Host^.Log^.LogSSS( log.lcInfo, 0, L"", Expect, L": ", String );

      ia.SetV4( inetaddr.saLocalLinkRandom );
      ia.ToOA( TRUE, OUT String );
      Host^.Log^.LogSSS( log.lcInfo, 0, L"", Expect, L": ", String );

      Host^.StopPhaseWithResult( NOT Failure1 );

      Host^.StartPhase( L"Special addresses V6" );
      
      Expect := L"::";
      ia.SetV6( inetaddr.saEmpty );
      ia.ToOA( TRUE, OUT String );
      Host^.Log^.LogSSS( log.lcInfo, 0, L"", Expect, L": ", String );

      Expect := L"::1";
      ia.SetV6( inetaddr.saLoopback );
      ia.ToOA( TRUE, OUT String );
      Host^.Log^.LogSSS( log.lcInfo, 0, L"", Expect, L": ", String );

      Expect := L"fe80::1";
      ia.SetV6( inetaddr.saLocalLink );
      ia.ToOA( TRUE, OUT String );
      Host^.Log^.LogSSS( log.lcInfo, 0, L"", Expect, L": ", String );

      Expect := L"fe80::abcd:abcd";
      ia.SetV6( inetaddr.saLocalLinkRandom );
      ia.ToOA( TRUE, OUT String );
      Host^.Log^.LogSSS( log.lcInfo, 0, L"", Expect, L": ", String );

      Expect := L"fc00::1";
      ia.SetV6( inetaddr.saPrivateRandom );
      ia.ToOA( TRUE, OUT String );
      Host^.Log^.LogSSS( log.lcInfo, 0, L"", Expect, L": ", String );

      Host^.StopPhaseWithResult( NOT Failure1 );

      Host^.StartPhase( L"Some other addresses" );
      
      Expect := L"10.0.1.132:1111";
      ia.FromOA( Expect, 0 );
      ia.ToOA( TRUE, OUT String );
      Host^.Log^.LogSSS( log.lcInfo, 0, L"", Expect, L": ", String );
      ia.ToOA( FALSE, OUT String );
      Host^.Log^.LogSSS( log.lcInfo, 0, L"", Expect, L": ", String );
      Host^.Log^.LogSC( log.lcInfo, 0, L"", L"  port: ", ia.Port );

      Expect := L"[2001:1:1::a0:80]:1023";
      ia.FromOA( Expect, 0 );
      ia.ToOA( TRUE, OUT String );
      Host^.Log^.LogSSS( log.lcInfo, 0, L"", Expect, L": ", String );
      ia.ToOA( FALSE, OUT String );
      Host^.Log^.LogSSS( log.lcInfo, 0, L"", Expect, L": ", String );
      Host^.Log^.LogSC( log.lcInfo, 0, L"", L"  port: ", ia.Port );

      Host^.StopPhaseWithResult( NOT Failure1 );

      netinit.Cleanup();
      threadpool.Cleanup();
      SCmsgqueuethread.Cleanup();

      RETURN test.trUnknown;
   END Run;
   
(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"Network::INETADDR", ADR( Test ));
END CTest;

(*===========================================================================*)

END TINETADDR.
