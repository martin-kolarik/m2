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
      Host^.ParticleWithResult( L"DayCountYMD", NOT Failure );

      dc := datetime.DayCountYMDfd( 1973, 8, 7, datetime.TimeSpanD( 0.75 ));
      Failure := dc.JulianDate <> 2441902.25;
      Host^.ParticleWithResult( L"DayCountYMDfd", NOT Failure );

      Host^.StartPhase( L"Properties" );

      dc := datetime.DayCountYMDfd( 1973, 8, 7, datetime.TimeSpanD( 0.75 ));
      Failure := dc.DayOfWeek <> datetime.Tuesday;
      Host^.ParticleWithResult( L"DayOfWeek", NOT Failure );

      dc := datetime.DayCountYMDfd( 1999, 7, 14, datetime.TimeSpanD( 10.0/24.0 ));
      Failure := dc.DayOfWeek <> datetime.Wednesday;
      Host^.ParticleWithResult( L"DayOfWeek", NOT Failure );

      dc := datetime.DayCountYMDfd( 1973, 8, 7, datetime.TimeSpanD( 0.75 ));
      Failure := dc.FractionOfTheDay <> datetime.TimeSpanD( 0.75 );
      Host^.ParticleWithResult( L"FractionOfTheDay", NOT Failure );

      dc.FractionOfTheDay := datetime.TimeSpanD( 0.25 );
      Failure := dc.JulianDate <> 2441901.75;
      Host^.ParticleWithResult( L"FractionOfTheDay change", NOT Failure );

      dc.JulianDate := 2441901.5;
      Failure := ( dc.JulianDate <> 2441901.5 ) OR ( dc <> datetime.DayCountYMDfd( 1973, 8, 7, datetime.TimeSpanZero()));
      Host^.ParticleWithResult( L"JulianDate", NOT Failure );

      Host^.StartPhase( L"Operators" );

      dc.JulianDate := 2450000.5;
      dcdst := dc;
      Failure := NOT( dc = dcdst ) OR    ( dc <> dcdst ) OR
                    ( dc < dcdst ) OR NOT( dc <= dcdst ) OR
                    ( dc > dcdst ) OR NOT( dc >= dcdst );
      Host^.ParticleWithResult( L"comparison of equal", NOT Failure );

      dc.JulianDate := 2450000.5;
      dcdst := dc;
      dcdst.Add( datetime.TimeSpanMS32( 1 ));
      Failure :=    ( dc = dcdst ) OR NOT( dc <> dcdst ) OR
                 NOT( dc < dcdst ) OR NOT( dc <= dcdst ) OR
                    ( dc > dcdst ) OR    ( dc >= dcdst );
      Host^.ParticleWithResult( L"comparison of lower", NOT Failure );

      dcdst.JulianDate := 2450000.5;
      dc := dcdst;
      dc.Add( datetime.TimeSpanMS32( 1 ));
      Failure :=    ( dc = dcdst ) OR NOT( dc <> dcdst ) OR
                    ( dc < dcdst ) OR    ( dc <= dcdst ) OR
                 NOT( dc > dcdst ) OR NOT( dc >= dcdst );
      Host^.ParticleWithResult( L"comparison of greater", NOT Failure );

      Host^.StartPhase( L"Operations" );
      dc.JulianDate := 2440000.5;
      dcdst := dc + datetime.TimeSpanD( 1.5 );
      Failure := dcdst.JulianDate <> 2440002.0;
      Host^.ParticleWithResult( L"+", NOT Failure );

      dc.JulianDate := 2440000.5;
      dcdst := dc - datetime.TimeSpanD( 10.123 );
      Failure := dcdst.JulianDate <> 2440000.5 - 10.123;
      Host^.ParticleWithResult( L"-", NOT Failure );

      dc.JulianDate := 2440000.5;
      dc.Add( datetime.TimeSpanD( 0.2 ));
      Failure := dc.JulianDate <> 2440000.7;
      Host^.ParticleWithResult( L"Add", NOT Failure );

      dc.JulianDate := 2440000.5;
      dc.Subtract( datetime.TimeSpanD( 1010.2 ));
      Failure := dc.JulianDate <> 2440000.5 - 1010.2;
      Host^.ParticleWithResult( L"Subtract", NOT Failure );

      dc.JulianDate := 2440000.5;
      dcdst.JulianDate := 2450000.0;
      ts := dcdst.Difference( dc );
      Failure := ts.Days <> 9999.5;
      Host^.ParticleWithResult( L"Difference", NOT Failure );

      Host^.StartPhase( L"Conversions" );
      dc.FromYMD( 1999, 7, 14, datetime.TimeSpanZero());
      Failure := dc.JulianDate <> 2451373.5;
      Host^.ParticleWithResult( L"FromYMD", NOT Failure );

      dc.JulianDate := 2453193.5;
      dc.ToYMD( OUT y, OUT m, OUT d, OUT ts );
      Failure := ( y <> 2004 ) OR ( m <> 7 ) OR ( d <> 7 ) OR ( ts.Days <> 0.0 );
      Host^.ParticleWithResult( L"ToYMD", NOT Failure );

      dc.JulianDate := 2453193.75;
      dc.ToYMD( OUT y, OUT m, OUT d, OUT ts );
      Failure := ( y <> 2004 ) OR ( m <> 7 ) OR ( d <> 7 ) OR ( ts.Days <> 0.25 );
      Host^.ParticleWithResult( L"ToYMDts", NOT Failure );

      RETURN test.trUnknown;
   END Run;
   
(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"DayCount", ADR( Test ));
END CTest;

(*===========================================================================*)

END TDayCount.