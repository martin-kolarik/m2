MODULE dnsstress;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   dns,
   inetaddr,
   log,
   msghandler,
   netinit,
   netsocket,
   Strings,
   StringsO,
   sync,
   test,
   testimpl,
   threadpool,
   SCmsgqueuethread,
   winsock;
  
(*===========================================================================*)

CONST
   LIMIT = 16;

(*---------------------------------------------------------------------------*)

TYPE
   TPTest = POINTER TO CTest;

(*---------------------------------------------------------------------------*)

CLASS CDNS( dns.ADNSNotifier );
   PUBLIC VAR
      Test : TPTest;

   LOCAL VIRTUAL PROCEDURE OnAddressFound( RequestId : PTR; Result : CARDINAL; CONST Address : ARRAY OF inetaddr.INETADDR );
   LOCAL VIRTUAL PROCEDURE OnNameFound( RequestId : PTR; Result : CARDINAL; CONST Name : StringsO.CString );
END CDNS;

(*---------------------------------------------------------------------------*)

CLASS CTest IMPLEMENTS test.ITest;
   PUBLIC VAR
      Host : test.TPHost := NIL;
      Notifier : CDNS;
      Results : ARRAY [0..63] OF TRISTATE;
      Limit : CARDINAL := 0;

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
END CTest;

(*===========================================================================*)

CLASS IMPLEMENTATION CDNS;

(*---------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnAddressFound( RequestId : PTR; Result : CARDINAL; CONST Address : ARRAY OF inetaddr.INETADDR );
   VAR
      i : CARDINAL;
      s : ARRAY [0..255] OF WCHAR := L"";
      request : ARRAY [0..15] OF WCHAR;
   BEGIN
      Strings.FromCARD64W( CARD64( RequestId ), 10, OUT request );
      Strings.AppendW( REF request, L": " );
      IF Result = 0 THEN
         Test^.Results[ CARDINAL( LOPTRLONGWORD( RequestId )) ] := 1;
         Test^.Host^.Log^.LogSS( log.lcInfo, 0, L"", L"Success: ", request );   
         FOR i := 0 TO HIGH( Address ) DO
            Address[i].ToOA( TRUE, OUT s );
            Test^.Host^.Log^.LogSS( log.lcInfo, 0, L"", L"  found: ", s );   
         END;
      ELSE
         Test^.Results[ CARDINAL( LOPTRLONGWORD( RequestId )) ] := 0;
         Strings.FromErrorW( Result, OUT s );
         Test^.Host^.Log^.LogSSS( log.lcError, 0, L"", L"Failure: ", request, s );   
      END;
  END OnAddressFound;
  
(*---------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnNameFound( RequestId : PTR; Result : CARDINAL; CONST Name : StringsO.CString );
   VAR
      s : ARRAY [0..255] OF WCHAR;
      request : ARRAY [0..15] OF WCHAR;
   BEGIN
      Strings.FromCARD64W( CARD64( RequestId ), 10, OUT request );
      Strings.AppendW( REF request, L": " );
      IF Result = 0 THEN
         Test^.Results[ CARDINAL( LOPTRLONGWORD( RequestId )) ] := 1;
         Name.ToOA( OUT s );
         Test^.Host^.Log^.LogSSS( log.lcInfo, 0, L"", L"Success: ", request, s );   
      ELSE
         Test^.Results[ CARDINAL( LOPTRLONGWORD( RequestId )) ] := 0;
         Strings.FromErrorW( Result, OUT s );
         Test^.Host^.Log^.LogSSS( log.lcError, 0, L"", L"Failure: ", request, s );   
      END;
   END OnNameFound;

(*---------------------------------------------------------------------------*)

BEGIN
   Test := NIL;
END CDNS;

(*===========================================================================*)

VAR
   Test : CTest;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CTest;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   VAR
      A : inetaddr.INETADDR;
      av4 : CARDINAL;
      Completed : BOOLEAN;
      h : PTR;
      i : CARDINAL;
      Failure1, Failure2 : BOOLEAN;
   BEGIN
      SELF.Host := Host;
      Notifier.Test := ADR( SELF );
      
      IF Host^.FastEvaluation THEN
         Limit := LIMIT DIV 8;
      ELSE
         Limit := LIMIT;
      END;

      SCmsgqueuethread.Startup();
      threadpool.Startup();
      netinit.Startup();

      Host^.StartPhase( L"First 16 addresses of AVONET" );
      // init
      FOR i := 0 TO HIGH( Results ) DO
         Results[i] := -1;
      END;
      // run
      // FOR j := 1 TO 255 DO
         FOR i := 1 TO Limit DO
            av4 := winsock.htonl( 217 << 24 + 112 << 16 + 162 << 8 + i );
            A.FromV4( av4 );
            A.Port := 110;
            dns.AddressToName( ADR( Notifier ), i, A, i MOD 2 = 1, OUT h );
         END;
      // END;
      // wait
      REPEAT
         sync.Sleep( 100 );
         Completed := TRUE;
         FOR i := 1 TO Limit DO
            IF Results[i] = -1 THEN
               Completed := FALSE;
               EXIT;
            END;
         END;
      UNTIL Completed;
      // check
      Failure1 := FALSE;
      FOR i := 1 TO Limit DO
         Failure1 := Failure1 OR ( Results[i] = 0 );
      END;      
      IF Failure1 THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      Host^.StartPhase( L"Forward Queries" );
      // init
      FOR i := 0 TO HIGH( Results ) DO
         Results[i] := -1;
      END;
      // run
      dns.NameToAddress( ADR( Notifier ), 1, L"www.smartcontrol.cz:1213", 0, OUT h );
      dns.NameToAddress( ADR( Notifier ), 2, L"home.smartcontrol.cz", 0, OUT h );
      dns.NameToAddress( ADR( Notifier ), 3, L"none.smartcontrol.cz", 0, OUT h );
      dns.NameToAddress( ADR( Notifier ), 4, L"iris.smartcontrol.cz:80", 0, OUT h );
      // wait
      REPEAT
         sync.Sleep( 100 );
         Completed := TRUE;
         FOR i := 1 TO 3 DO
            IF Results[i] = -1 THEN
               Completed := FALSE;
               EXIT;
            END;
         END;
      UNTIL Completed;
      // check
      Failure2 := ( Results[1] = 0 ) OR ( Results[2] = 0 ) OR ( Results[3] = 1 );
      IF Failure2 THEN
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
   Results[0] := 0;
   testimpl.tests()^.AddTest( L"Network::DNS", ADR( Test ));
END CTest;

(*===========================================================================*)

END dnsstress.
