MODULE TJulianDate;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   datetime,
   log,
   test,
   testimpl;
  
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
      d : CARDINAL;
      Failure : BOOLEAN := FALSE;
      m : CARDINAL;
      jd : datetime.JulianDate;
      jddst : datetime.JulianDate;
      ts : datetime.TimeSpan;
      y : INTEGER;
   BEGIN
      SELF.Host := Host;

      Host^.StartPhase( L"Construction" );

      jd := datetime.JulianDateYMD( 2011, 2, 24 );
      Failure := jd.Scientific <> 2455616.5;
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      jd := datetime.JulianDateYMDfd( 1973, 8, 7, datetime.TimeSpanD( 0.75 ));
      Failure := jd.Scientific <> 2441902.25;
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      Host^.StartPhase( L"Properties" );

      jd := datetime.JulianDateYMDfd( 1973, 8, 7, datetime.TimeSpanD( 0.75 ));
      Failure := jd.DayOfWeek <> datetime.Tuesday;
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      jd := datetime.JulianDateYMDfd( 1999, 7, 14, datetime.TimeSpanD( 10.0/24.0 ));
      Failure := jd.DayOfWeek <> datetime.Wednesday;
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      jd := datetime.JulianDateYMDfd( 1973, 8, 7, datetime.TimeSpanD( 0.75 ));
      Failure := jd.FractionOfTheDay <> datetime.TimeSpanD( 0.75 );
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      jd.FractionOfTheDay := datetime.TimeSpanD( 0.25 );
      Failure := jd.Scientific <> 2441901.75;
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      jd.Scientific := 2441901.5;
      Failure := ( jd.Scientific <> 2441901.5 ) OR ( jd <> datetime.JulianDateYMDfd( 1973, 8, 7, datetime.TimeSpanZero()));
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      Host^.StartPhase( L"Operators" );

      jd.Scientific := 2450000.5;
      jddst := jd;
      Failure := NOT( jd = jddst ) OR    ( jd <> jddst ) OR
                    ( jd < jddst ) OR NOT( jd <= jddst ) OR
                    ( jd > jddst ) OR NOT( jd >= jddst );
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      jd.Scientific := 2450000.5;
      jddst := jd;
      jddst.Add( datetime.TimeSpanMS32( 1 ));
      Failure :=    ( jd = jddst ) OR NOT( jd <> jddst ) OR
                 NOT( jd < jddst ) OR NOT( jd <= jddst ) OR
                    ( jd > jddst ) OR    ( jd >= jddst );
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      jddst.Scientific := 2450000.5;
      jd := jddst;
      jd.Add( datetime.TimeSpanMS32( 1 ));
      Failure :=    ( jd = jddst ) OR NOT( jd <> jddst ) OR
                    ( jd < jddst ) OR    ( jd <= jddst ) OR
                 NOT( jd > jddst ) OR NOT( jd >= jddst );
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      Host^.StartPhase( L"Operations" );
      jd.Scientific := 2440000.5;
      jddst := jd + datetime.TimeSpanD( 1.5 );
      Failure := jddst.Scientific <> 2440001.0;
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      jd.Scientific := 2440000.5;
      jddst := jd - datetime.TimeSpanD( 10.123 );
      Failure := jddst.Scientific <> 2440000.5 - 10.123;
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      jd.Scientific := 2440000.5;
      jd.Add( datetime.TimeSpanD( 0.2 ));
      Failure := jd.Scientific <> 2440000.7;
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      jd.Scientific := 2440000.5;
      jd.Subtract( datetime.TimeSpanD( 1010.2 ));
      Failure := jd.Scientific <> 2440000.5 - 1010.2;
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      jd.Scientific := 2440000.5;
      jddst.Scientific := 245000.0;
      ts := jddst.Difference( jd );
      Failure := ts.Days <> 9999.5;
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      Host^.StartPhase( L"Conversions" );
      jd.FromYMD( 1999, 7, 14, datetime.TimeSpanZero());
      Failure := jd.Scientific <> 2451373.5;
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      jd.Scientific := 2453193.5;
      jd.ToYMD( OUT y, OUT m, OUT d, OUT ts );
      Failure := ( y <> 2004 ) OR ( m <> 7 ) OR ( d <> 7 ) OR ( ts.Days <> 0.0 );
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      jd.Scientific := 2453193.75;
      jd.ToYMD( OUT y, OUT m, OUT d, OUT ts );
      Failure := ( y <> 2004 ) OR ( m <> 7 ) OR ( d <> 7 ) OR ( ts.Days <> 0.25 );
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
   testimpl.tests()^.AddTest( L"JulianDate", ADR( Test ));
END CTest;

(*===========================================================================*)

END TJulianDate.