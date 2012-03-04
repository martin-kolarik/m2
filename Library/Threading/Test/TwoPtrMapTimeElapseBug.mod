MODULE TwoPtrMapTimeElapseBug;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   datetime,
   log,
   sync,
   test,
   testimpl,
   threadcall,
   TimeoutableTwoPtrMap;
  
(*===========================================================================*)

TYPE
   TPTest = POINTER TO CTest;

(*---------------------------------------------------------------------------*)

CLASS CTest IMPLEMENTS test.ITest;

   PUBLIC VAR
      Host : test.TPHost := NIL;
      Map : TimeoutableTwoPtrMap.CTimeoutableTwoPtrMapSimplified;

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;

END CTest;

(*---------------------------------------------------------------------------*)

VAR
   Test : CTest;

(*===========================================================================*)

CLASS IMPLEMENTATION CTest;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   VAR
      currentTime : CARD16;
      Failure : BOOLEAN := FALSE;
      i : CARDINAL;
      key : PTR;
      ptr : PTR;
      timeout : CARDINAL;
   BEGIN
      SELF.Host := Host;

      // the test requires GetUptimeMS overflow after 8192 milliseconds
      currentTime := datetime.UptimeMS16();

      FOR i := 1 TO 10 DO
         Map.Add( CARDINAL( currentTime ), i, 0, i * 100 );
      END;

      LOOP
         timeout := Map.GetTimeoutToFirstElapsed( CARDINAL( currentTime ));

         Host^.Log^.LogSC( log.ldError, 0, L"", L"Timeout:", timeout );
         
         sync.Sleep( timeout );
         currentTime := datetime.UptimeMS16();

         Host^.Log^.LogSC( log.ldError, 0, L"", L"Time:", CARDINAL( currentTime ));

         WHILE Map.GetFirstElapsed( CARDINAL( currentTime ), TRUE, OUT key, OUT ptr ) DO
            i := CARDINAL( key );
            Host^.Log^.LogSC( log.ldError, 0, L"", L"  tick: ", i );

            Map.Add( CARDINAL( currentTime ), i, 0, i * 100 );
         END; // DO
      END;

      IF Failure THEN
         RETURN test.trFailure;
      ELSE
         RETURN test.trSuccess;
      END;
   END Run;
   
(*---------------------------------------------------------------------------*)

BEGIN
   // TO RUN THE TEST CHANGE TStorage and TDifference in TimeoutableTwoPtrMap types to 16 bits
   // testimpl.tests()^.AddTest( L"TiemoutableTwoPtrMap::TimeElapseBug", ADR( Test ));
END CTest;

(*===========================================================================*)

END TwoPtrMapTimeElapseBug.
