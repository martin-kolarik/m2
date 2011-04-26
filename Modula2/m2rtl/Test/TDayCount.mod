MODULE TDayCount;

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
      dc : datetime.DayCount;
      dcdst : datetime.DayCount;
      Failure : BOOLEAN := FALSE;
      m : CARDINAL;
      ts : datetime.TimeSpan;
      y : INTEGER;
   BEGIN
      SELF.Host := Host;

      Host^.StartPhase( L"Construction" );

      dc := datetime.DayCountYMD( 2011, 2, 24 );
      Failure := dc.JulianDate <> 2455616.5;
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      dc := datetime.DayCountYMDfd( 1973, 8, 7, datetime.TimeSpanD( 0.75 ));
      Failure := dc.JulianDate <> 2441902.25;
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      Host^.StartPhase( L"Properties" );

      dc := datetime.DayCountYMDfd( 1973, 8, 7, datetime.TimeSpanD( 0.75 ));
      Failure := dc.DayOfWeek <> datetime.Tuesday;
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      dc := datetime.DayCountYMDfd( 1999, 7, 14, datetime.TimeSpanD( 10.0/24.0 ));
      Failure := dc.DayOfWeek <> datetime.Wednesday;
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      dc := datetime.DayCountYMDfd( 1973, 8, 7, datetime.TimeSpanD( 0.75 ));
      Failure := dc.FractionOfTheDay <> datetime.TimeSpanD( 0.75 );
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      dc.FractionOfTheDay := datetime.TimeSpanD( 0.25 );
      Failure := dc.JulianDate <> 2441901.75;
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      dc.JulianDate := 2441901.5;
      Failure := ( dc.JulianDate <> 2441901.5 ) OR ( dc <> datetime.DayCountYMDfd( 1973, 8, 7, datetime.TimeSpanZero()));
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      Host^.StartPhase( L"Operators" );

      dc.JulianDate := 2450000.5;
      dcdst := dc;
      Failure := NOT( dc = dcdst ) OR    ( dc <> dcdst ) OR
                    ( dc < dcdst ) OR NOT( dc <= dcdst ) OR
                    ( dc > dcdst ) OR NOT( dc >= dcdst );
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      dc.JulianDate := 2450000.5;
      dcdst := dc;
      dcdst.Add( datetime.TimeSpanMS32( 1 ));
      Failure :=    ( dc = dcdst ) OR NOT( dc <> dcdst ) OR
                 NOT( dc < dcdst ) OR NOT( dc <= dcdst ) OR
                    ( dc > dcdst ) OR    ( dc >= dcdst );
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      dcdst.JulianDate := 2450000.5;
      dc := dcdst;
      dc.Add( datetime.TimeSpanMS32( 1 ));
      Failure :=    ( dc = dcdst ) OR NOT( dc <> dcdst ) OR
                    ( dc < dcdst ) OR    ( dc <= dcdst ) OR
                 NOT( dc > dcdst ) OR NOT( dc >= dcdst );
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      Host^.StartPhase( L"Operations" );
      dc.JulianDate := 2440000.5;
      dcdst := dc + datetime.TimeSpanD( 1.5 );
      Failure := dcdst.JulianDate <> 2440002.0;
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      dc.JulianDate := 2440000.5;
      dcdst := dc - datetime.TimeSpanD( 10.123 );
      Failure := dcdst.JulianDate <> 2440000.5 - 10.123;
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      dc.JulianDate := 2440000.5;
      dc.Add( datetime.TimeSpanD( 0.2 ));
      Failure := dc.JulianDate <> 2440000.7;
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      dc.JulianDate := 2440000.5;
      dc.Subtract( datetime.TimeSpanD( 1010.2 ));
      Failure := dc.JulianDate <> 2440000.5 - 1010.2;
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      dc.JulianDate := 2440000.5;
      dcdst.JulianDate := 2450000.0;
      ts := dcdst.Difference( dc );
      Failure := ts.Days <> 9999.5;
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      Host^.StartPhase( L"Conversions" );
      dc.FromYMD( 1999, 7, 14, datetime.TimeSpanZero());
      Failure := dc.JulianDate <> 2451373.5;
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      dc.JulianDate := 2453193.5;
      dc.ToYMD( OUT y, OUT m, OUT d, OUT ts );
      Failure := ( y <> 2004 ) OR ( m <> 7 ) OR ( d <> 7 ) OR ( ts.Days <> 0.0 );
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      dc.JulianDate := 2453193.75;
      dc.ToYMD( OUT y, OUT m, OUT d, OUT ts );
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
   testimpl.tests()^.AddTest( L"DayCount", ADR( Test ));
END CTest;

(*===========================================================================*)

END TDayCount.