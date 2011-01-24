MODULE TTimeSpan;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   log,
   test,
   testimpl,
   tls;
  
(*===========================================================================*)

CLASS CTest IMPLEMENTS test.ITest;
   PRIVATE VAR
      Host : test.TPHost := NIL;

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;

END CTest;

(*---------------------------------------------------------------------------*)

TYPE
   TPTest = POINTER TO CTest;
VAR
   Test : CTest;

(*===========================================================================*)

CLASS IMPLEMENTATION CTest;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   VAR
      Failure : BOOLEAN := FALSE;
      ts : datetime.TimeSpan;
   BEGIN
      SELF.Host := Host;

      Host^.StartPhase( L"Construction & getters" );

      ts := datetime.TimeSpanZero();
      Failure := ( ts.Value <> 0 ) OR
                 ( ts.Microseconds <> 0.0 ) OR
                 ( ts.Milliseconds <> 0.0 ) OR
                 ( ts.Seconds <> 0.0 ) OR
                 ( ts.Minutes <> 0.0 ) OR
                 ( ts.Hours <> 0.0 ) OR
                 ( ts.Days <> 0.0 );
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      ts := datetime.TimeSpanMS32( 333 );
      Failure := ( ts.Value <> 3330000 ) OR
                 ( ts.Microseconds <> 333000.0 ) OR
                 ( ts.Milliseconds <> 333.0 ) OR
                 ( ts.Seconds <> 0.333 ) OR
                 ( ts.Minutes <> 0.333 / 60.0 ) OR
                 ( ts.Hours <> 0.333 / 60.0 / 60.0 ) OR
                 ( ts.Days <> 0.333 / 60.0 / 60.0 / 24.0 );
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      ts := datetime.TimeSpanMS32( -333 );
      Failure := ( ts.Value <> -3330000 ) OR
                 ( ts.Microseconds <> -333000.0 ) OR
                 ( ts.Milliseconds <> -333.0 ) OR
                 ( ts.Seconds <> -0.333 ) OR
                 ( ts.Minutes <> -0.333 / 60.0 ) OR
                 ( ts.Hours <> -0.333 / 60.0 / 60.0 ) OR
                 ( ts.Days <> -0.333 / 60.0 / 60.0 / 24.0 );
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      ts := datetime.TimeSpanS( 7200 );
      Failure := ( ts.Value <> INT64( 72000000000 )) OR
                 ( ts.Microseconds <> 7200000000.0 ) OR
                 ( ts.Milliseconds <> 7200000.0 ) OR
                 ( ts.Seconds <> 7200.0 ) OR
                 ( ts.Minutes <> 7200.0 / 60.0 ) OR
                 ( ts.Hours <> 7200.0 / 60.0 / 60.0 ) OR
                 ( ts.Days <> 7200.0 / 60.0 / 60.0 / 24.0 );
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      ts := datetime.TimeSpanS( -7200 );
      Failure := ( ts.Value <> INT64( -72000000000 )) OR
                 ( ts.Microseconds <> -7200000000.0 ) OR
                 ( ts.Milliseconds <> -7200000.0 ) OR
                 ( ts.Seconds <> -7200.0 ) OR
                 ( ts.Minutes <> -7200.0 / 60.0 ) OR
                 ( ts.Hours <> -7200.0 / 60.0 / 60.0 ) OR
                 ( ts.Days <> -7200.0 / 60.0 / 60.0 / 24.0 );
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      ts := datetime.TimeSpanD( 0.8 );
      Failure := ( ts.Value <> INT64( 691200000000 )) OR
                 ( ts.Microseconds <> 69120000000.0 ) OR
                 ( ts.Milliseconds <> 69120000.0 ) OR
                 ( ts.Seconds <> 69120.0 ) OR
                 ( ts.Minutes <> 0.8 * 24.0 * 60.0 ) OR
                 ( ts.Hours <> 0.8 * 24.0 ) OR
                 ( ts.Days <> 0.8 );
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      ts := datetime.TimeSpanD( -0.8 );
      Failure := ( ts.Value <> INT64( -691200000000 )) OR
                 ( ts.Microseconds <> -69120000000.0 ) OR
                 ( ts.Milliseconds <> -69120000.0 ) OR
                 ( ts.Seconds <> -69120.0 ) OR
                 ( ts.Minutes <> -0.8 * 24.0 * 60.0 ) OR
                 ( ts.Hours <> -0.8 * 24.0 ) OR
                 ( ts.Days <> -0.8 );
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      Host^.StartPhase( L"Raw & setters" );

      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      ts.Value := 123;
      Failure := ( ts.Value <> 123 OR
                 ( ts.Microseconds <> 12.3 ) OR
                 ( ts.Milliseconds <> 0.0123 ) OR
                 ( ts.Seconds <> 0.0000123 ) OR
                 ( ts.Minutes <> 0.0000123 / 60.0 ) OR
                 ( ts.Hours <> 0.0000123 / 60.0 / 60.0 ) OR
                 ( ts.Days <> 0.0000123 / 60.0 / 60.0 / 24.0 );
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      ts.Microseconds := -587.0;
      Failure := ( ts.Value <> -5870 OR
                 ( ts.Microseconds <> -587.0 ) OR
                 ( ts.Milliseconds <> -0.587 ) OR
                 ( ts.Seconds <> -0.000587 ) OR
                 ( ts.Minutes <> -0.000587 / 60.0 ) OR
                 ( ts.Hours <> -0.000587 / 60.0 / 60.0 ) OR
                 ( ts.Days <> -0.000587 / 60.0 / 60.0 / 24.0 );
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      ts.Milliseconds := 55.0;
      Failure := ( ts.Value <> 550000 OR
                 ( ts.Microseconds <> 55000.0 ) OR
                 ( ts.Milliseconds <> 55.0 ) OR
                 ( ts.Seconds <> 0.055 ) OR
                 ( ts.Minutes <> 0.055 / 60.0 ) OR
                 ( ts.Hours <> 0.055 / 60.0 / 60.0 ) OR
                 ( ts.Days <> 0.055 / 60.0 / 60.0 / 24.0 );
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      Host^.StartPhase( L"Operation" );

      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      IF Failure THEN
         RETURN test.trFailure;
      ELSE
         RETURN test.trSuccess;
      END;
   END Run;
   
(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"TimeSpan", ADR( Test ));
END CTest;

(*===========================================================================*)

END TTimeSpan.