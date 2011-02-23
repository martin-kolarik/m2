MODULE TTimeSpan;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   datetime,
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
      D, H, M, S, MS : CARDINAL;
      Failure : BOOLEAN := FALSE;
      ts : datetime.TimeSpan;
      tsdst : datetime.TimeSpan;
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
      Failure := ( ts.Negative ) OR
                 ( ts.Value <> 3330000 ) OR
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
      Failure := ( NOT ts.Negative ) OR
                 ( ts.Value <> -3330000 ) OR
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

      ts := datetime.TimeSpanS( 7200.0 );
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

      ts := datetime.TimeSpanS( -7200.0 );
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
      Failure := ( ts.Value <> 123 ) OR
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
      Failure := ( ts.Value <> -5870 ) OR
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
      Failure := ( ts.Value <> 550000 ) OR
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

      ts.Seconds := 55.0;
      Failure := ( ts.Value <> 550000000 ) OR
                 ( ts.Microseconds <> 55000000.0 ) OR
                 ( ts.Milliseconds <> 55000.0 ) OR
                 ( ts.Seconds <> 55.0 ) OR
                 ( ts.Minutes <> 55.0 / 60.0 ) OR
                 ( ts.Hours <> 55.0 / 60.0 / 60.0 ) OR
                 ( ts.Days <> 55.0 / 60.0 / 60.0 / 24.0 );
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      ts.Minutes := 55.0;
      Failure := ( ts.Value <> 55 * 60 * ts.Precision ) OR
                 ( ts.Microseconds <> 55.0 * 60.0 * 1000000.0 ) OR
                 ( ts.Milliseconds <> 55.0 * 60.0 * 1000.0 ) OR
                 ( ts.Seconds <> 55.0 * 60.0 ) OR
                 ( ts.Minutes <> 55.0 ) OR
                 ( ts.Hours <> 55.0 / 60.0 ) OR
                 ( ts.Days <> 55.0 / 60.0 / 24.0 );
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      ts.Hours := 17.0;
      Failure := ( ts.Value <> 17 * 60 * 60 * ts.Precision ) OR
                 ( ts.Microseconds <> 17.0 * 60.0 * 60.0 * 1000000.0 ) OR
                 ( ts.Milliseconds <> 17.0 * 60.0 * 60.0 * 1000.0 ) OR
                 ( ts.Seconds <> 17.0 * 60.0 * 60.0 ) OR
                 ( ts.Minutes <> 17.0 * 60.0 ) OR
                 ( ts.Hours <> 55.0 ) OR
                 ( ts.Days <> 55.0 / 24.0 );
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      ts.Days := 17.0;
      Failure := ( ts.Value <> 17 * 24 * 60 * 60 * ts.Precision ) OR
                 ( ts.Microseconds <> 17.0 * 24.0 * 60.0 * 60.0 * 1000000.0 ) OR
                 ( ts.Milliseconds <> 17.0 * 24.0 * 60.0 * 60.0 * 1000.0 ) OR
                 ( ts.Seconds <> 17.0 * 24.0 * 60.0 * 60.0 ) OR
                 ( ts.Minutes <> 17.0 * 24.0 * 60.0 ) OR
                 ( ts.Hours <> 55.0 * 24.0 ) OR
                 ( ts.Days <> 55.0 );
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      Host^.StartPhase( L"Operations" );

      ts.Days := 17.0;
      tsdst := ts;
      Failure := tsdst.Value <> 17 * 24 * 60 * 60 * tsdst.Precision;
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      ts.Days := 17.0;
      tsdst := ts + ts;
      Failure := tsdst.Value <> 2 * 17 * 24 * 60 * 60 * tsdst.Precision;
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      ts.Days := 17.0;
      tsdst := tsdst - ts;
      Failure := tsdst.Value <> 17 * 24 * 60 * 60 * tsdst.Precision;
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      ts.Days := 17.0;
      tsdst.Days := 17.0;
      ts.Add( tsdst );
      Failure := ts.Value <> 2 * 17 * 24 * 60 * 60 * tsdst.Precision;
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      ts.Days := 33.0;
      tsdst.Days := 17.0;
      ts.Subtract( tsdst );
      Failure := ts.Value <> 16 * 24 * 60 * 60 * tsdst.Precision;
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      Host^.StartPhase( L"Conversions" );

      ts.FromDHMS( 1, 1, 1, 1, 234 );
      Failure := ts.Value <> (((( 1 * 24 + 1 ) * 60 + 1 ) * 60 + 1 ) * 1000 + 234 ) * 100000;
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      ts.Subtract( datetime.TimeSpanD( 12.0 ));
      ts.ToDHMS( OUT D, OUT H, OUT M, OUT S, OUT MS ); // returns always positive values, even if the span is negative
      Failure := ( D <> 0 ) OR ( H <> 13 ) OR ( M <> 60 ) OR
                 ( S <> 60 ) OR ( MS <> 234 );
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