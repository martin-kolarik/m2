MODULE dnsstress;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   dns,
   log,
   msghandler,
   netinit,
   netsocket,
   Strings,
   StringsO,
   sync,
   test,
   testimpl,
   winsock;
  
(*===========================================================================*)

TYPE
   TPTest = POINTER TO CTest;

(*---------------------------------------------------------------------------*)

CLASS CDNS( dns.ADNSNotifier );
   PUBLIC VAR
      Test : TPTest;

   LOCAL VIRTUAL PROCEDURE OnAddressFound( RequestId : PTR; Result : CARDINAL; CONST Address : ARRAY OF netsocket.INETADDR );
   LOCAL VIRTUAL PROCEDURE OnNameFound( RequestId : PTR; Result : CARDINAL; CONST Name : StringsO.CString );
END CDNS;

(*---------------------------------------------------------------------------*)

CLASS CTest IMPLEMENTS test.ITest;
   PUBLIC VAR
      Host : test.TPHost := NIL;
      Notifier : CDNS;
      Results : ARRAY [0..63] OF TRISTATE;

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
END CTest;

(*===========================================================================*)

CLASS IMPLEMENTATION CDNS;

(*---------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnAddressFound( RequestId : PTR; Result : CARDINAL; CONST Address : ARRAY OF netsocket.INETADDR );
   VAR
      i : CARDINAL;
      s : ARRAY [0..255] OF WCHAR := L"";
      request : ARRAY [0..15] OF WCHAR;
   BEGIN
      Strings.FromCARD32W( CARDINAL( RequestId ), 10, OUT request );
      Strings.AppendW( REF request, L": " );
      IF Result = 0 THEN
         Test^.Results[ CARDINAL( LOPTRLONGWORD( RequestId )) ] := 1;
         Test^.Host^.Log^.LogSS( log.dlcInfo, L"", L"Success: ", request );   
         FOR i := 0 TO HIGH( Address ) DO
            Address[i].GetAddressOA( TRUE, OUT s );
            Test^.Host^.Log^.LogSS( log.dlcInfo, L"", L"  found: ", s );   
         END;
      ELSE
         Test^.Results[ CARDINAL( LOPTRLONGWORD( RequestId )) ] := 0;
         Strings.FromErrorW( Result, OUT s );
         Test^.Host^.Log^.LogSSS( log.dlcError, L"", L"Failure: ", request, s );   
      END;
  END OnAddressFound;
  
(*---------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnNameFound( RequestId : PTR; Result : CARDINAL; CONST Name : StringsO.CString );
   VAR
      s : ARRAY [0..255] OF WCHAR;
      request : ARRAY [0..15] OF WCHAR;
   BEGIN
      Strings.FromCARD32W( CARDINAL( RequestId ), 10, OUT request );
      Strings.AppendW( REF request, L": " );
      IF Result = 0 THEN
         Test^.Results[ CARDINAL( LOPTRLONGWORD( RequestId )) ] := 1;
         Name.ToOA( OUT s );
         Test^.Host^.Log^.LogSSS( log.dlcInfo, L"", L"Success: ", request, s );   
      ELSE
         Test^.Results[ CARDINAL( LOPTRLONGWORD( RequestId )) ] := 0;
         Strings.FromErrorW( Result, OUT s );
         Test^.Host^.Log^.LogSSS( log.dlcError, L"", L"Failure: ", request, s );   
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
      A : netsocket.INETADDR;
      av4 : CARDINAL;
      Completed : BOOLEAN;
      h : PTR;
      i : CARDINAL;
      Failure1, Failure2 : BOOLEAN;
   BEGIN
      SELF.Host := Host;
      Notifier.Test := ADR( SELF );
      netinit.Startup();

      Host^.StartPhase( L"First 16 addresses of AVONET" );
      // init
      FOR i := 0 TO HIGH( Results ) DO
         Results[i] := -1;
      END;
      // run
      FOR i := 1 TO 16 DO
         av4 := winsock.htonl( 217 << 24 + 112 << 16 + 162 << 8 + i );
         A.FromV4( av4 );
         dns.AddressToName( ADR( Notifier ), i, A, FALSE, i*750, OUT h );
      END;
      // wait
      REPEAT
         sync.Sleep( 100 );
         Completed := TRUE;
         FOR i := 1 TO 16 DO
            IF Results[i] = -1 THEN
               Completed := FALSE;
               EXIT;
            END;
         END;
      UNTIL Completed;
      // check
      Failure1 := FALSE;
      FOR i := 1 TO 16 DO
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
      dns.NameToAddress( ADR( Notifier ), 1, L"www.smartcontrol.cz", 0, 1*2000, OUT h );
      dns.NameToAddress( ADR( Notifier ), 2, L"home.smartcontrol.cz", 0, 2*2000, OUT h );
      dns.NameToAddress( ADR( Notifier ), 3, L"none.smartcontrol.cz", 0, 3*2000, OUT h );
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
      IF Failure1 OR Failure2 THEN
         RETURN test.trFailure;
      ELSE
         RETURN test.trSuccess;
      END;
   END Run;
   
(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"Network::DNS", ADR( Test ));
END CTest;

(*===========================================================================*)

END dnsstress.
