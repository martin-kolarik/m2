MODULE TDateTime;

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
      dt : datetime.DateTime;
      dtdst : datetime.DateTime;
      Failure : BOOLEAN := FALSE;
      jd : datetime.JulianDate;
      ts : datetime.TimeSpan;
   BEGIN
      SELF.Host := Host;

      Host^.StartPhase( L"Construction" );

      dt := datetime.NowUTC();
      dtdst := datetime.NowLocal();
      Failure := dt.JulianDate.Difference( dtdst.JulianDate ) <> datetime.TimeSpanD( LONGREAL( datetime.GetCurrentUTCBias()) / 60.0 / 24.0 );
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      Host^.StartPhase( L"Properties" );
      dt.Clear();
      jd.Scientific := 2453193.5;
      dt.JulianDate := jd;
      Failure := ( dt.Millisecond <> 0 ) OR ( dt.Second <> 0 ) OR ( dt.Minute <> 0 ) OR ( dt.Hour <> 0 ) OR
                 ( dt.Day <> 7 ) OR ( dt.Month <> 7 ) OR ( dt.Year <> 2004 ) OR
                 ( dt.UTCBias <> 0 ) OR ( dt.DSTBias <> 0 ) OR
                 ( dt.Empty ) OR NOT( dt.DstActive ) OR ( dt.DayOfWeek <> datetime.Wednesday ) OR ( dt.JulianDate.Scientific <> 2453193.5 );
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      dt.Clear();
      dt.Millisecond := 1;
      dt.Second := 2;
      dt.Minute := 3;
      dt.Hour := 4;
      dt.Day := 7;
      dt.Month := 7;
      dt.Year := 2004;
      dt.UTCBias := -60;
      dt.DSTBias := -120;
      Failure := ( dt.Millisecond <> 1 ) OR ( dt.Second <> 2 ) OR ( dt.Minute <> 3 ) OR ( dt.Hour <> 7 ) OR
                 ( dt.Day <> 7 ) OR ( dt.Month <> 7 ) OR ( dt.Year <> 2004 ) OR
                 ( dt.UTCBias <> -60 ) OR ( dt.DSTBias <> -120 ) OR
                 ( dt.Empty ) OR NOT( dt.DstActive ) OR ( dt.DayOfWeek <> datetime.Wednesday ) OR ( dt.JulianDate.Scientific <> 2453193.6687731599 ); // = 2453193.5 + 1.0 / 86400000.0 + 2.0 / 86400.0 + 3.0 / 1440.0 + 4.0 / 24.0 );
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      dt.Clear();
      Failure := NOT( dt.Empty );
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      dt.Millisecond := 0;
      Failure := dt.Empty;
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      dt.SetNowUTC();
      dt.Month := 1;
      Failure := dt.DstActive;
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      dt.SetNowUTC();
      dt.Month := 7;
      Failure := NOT dt.DstActive;
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      dt.SetNowLocal();
      jd.SetNow();
      dt.JulianDate := jd;
      Failure := ( dt.UTCBias <> 0 ) OR ( dt.DSTBias <> 0 );
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      Host^.StartPhase( L"Operators" );
      dt.Clear();
      jd.Scientific := 2453193.5;
      dt.JulianDate := jd;
      dt.Millisecond := 678;
      dt.Second := 13;
      dt.Minute := 14;
      dt.Hour := 17;
      dtdst := dt;
      Failure := ( dtdst.Empty ) OR ( dtdst.Millisecond <> 678 ) OR ( dtdst.Second <> 13 ) OR ( dtdst.Minute <> 14 ) OR ( dtdst.Hour <> 17 ) OR
                 ( dtdst.Day <> 7 ) OR ( dtdst.Month <> 7 ) OR ( dtdst.Year <> 2004 ) OR
                 NOT( dtdst.DstActive ) OR ( dtdst.DayOfWeek <> datetime.Wednesday );
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      jd.Scientific := 2453193.5;
      dt.JulianDate := jd;
      jd.Scientific := 2463193.5;
      dtdst.JulianDate := jd;
      Failure :=    ( dt = dtdst ) OR NOT( dt <> dtdst ) OR
                 NOT( dt < dtdst ) OR NOT( dt <= dtdst ) OR
                    ( dt > dtdst ) OR    ( dt >= dtdst );
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      jd.Scientific := 2463193.5;
      dt.JulianDate := jd;
      jd.Scientific := 2453193.5;
      dtdst.JulianDate := jd;
      Failure :=    ( dt = dtdst ) OR NOT( dt <> dtdst ) OR
                    ( dt < dtdst ) OR    ( dt <= dtdst ) OR
                 NOT( dt > dtdst ) OR NOT( dt >= dtdst );
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      jd.Scientific := 2453193.5;
      dt.JulianDate := jd;
      jd.Scientific := 2453193.5;
      dtdst.JulianDate := jd;
      Failure := NOT( dt = dtdst ) OR    ( dt <> dtdst ) OR
                    ( dt < dtdst ) OR NOT( dt <= dtdst ) OR
                    ( dt > dtdst ) OR NOT( dt >= dtdst );
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      Host^.StartPhase( L"Operations" );
      dt.Clear();
      Failure := ( dt.Millisecond <> 0 ) OR ( dt.Second <> 0 ) OR ( dt.Minute <> 0 ) OR ( dt.Hour <> 0 ) OR
                 ( dt.Day <> 0 ) OR ( dt.Month <> 0 ) OR ( dt.Year <> 0 ) OR
                 ( dt.UTCBias <> 0 ) OR ( dt.DSTBias <> 0 ) OR
                 NOT( dt.Empty ) OR ( dt.DstActive ) OR ( dt.DayOfWeek <> datetime.UnknownDay ) OR ( dt.JulianDate.Scientific <> 0.0 );
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      dt.Clear();
      dt.Day := 1;
      dt.Month := 1;
      dt.Year := 1;
      Failure := ( dt.Millisecond <> 0 ) OR ( dt.Second <> 0 ) OR ( dt.Minute <> 0 ) OR ( dt.Hour <> 0 ) OR
                 ( dt.Day <> 1 ) OR ( dt.Month <> 1 ) OR ( dt.Year <> 1 ) OR
                 ( dt.UTCBias <> 0 ) OR ( dt.DSTBias <> 0 ) OR
                 ( dt.Empty ) OR ( dt.DstActive ) OR ( dt.DayOfWeek <> datetime.Saturday ) OR ( dt.JulianDate.Scientific <> 1721423.5 );
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      jd.Scientific := 2453193.5;
      dt.JulianDate := jd;
      dtdst := dt + datetime.TimeSpanD( 0.5 );
      Failure := ( dtdst.Empty ) OR ( dtdst.Millisecond <> 0 ) OR ( dtdst.Second <> 0 ) OR ( dtdst.Minute <> 0 ) OR ( dtdst.Hour <> 12 ) OR
                 ( dtdst.Day <> 7 ) OR ( dtdst.Month <> 7 ) OR ( dtdst.Year <> 2004 ) OR
                 NOT( dtdst.DstActive ) OR ( dtdst.DayOfWeek <> datetime.Wednesday );
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      jd.Scientific := 2453193.5;
      dt.JulianDate := jd;
      dtdst := dt - datetime.TimeSpanD( 7.5 );
      Failure := ( dtdst.Empty ) OR ( dtdst.Millisecond <> 0 ) OR ( dtdst.Second <> 0 ) OR ( dtdst.Minute <> 0 ) OR ( dtdst.Hour <> 12 ) OR
                 ( dtdst.Day <> 29 ) OR ( dtdst.Month <> 6 ) OR ( dtdst.Year <> 2004 ) OR
                 NOT( dtdst.DstActive ) OR ( dtdst.DayOfWeek <> datetime.Tuesday );
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      jd.Scientific := 2453193.5;
      dtdst.JulianDate := jd;
      dtdst.Add( datetime.TimeSpanD( 0.5 ));
      Failure := ( dtdst.Empty ) OR ( dtdst.Millisecond <> 0 ) OR ( dtdst.Second <> 0 ) OR ( dtdst.Minute <> 0 ) OR ( dtdst.Hour <> 12 ) OR
                 ( dtdst.Day <> 7 ) OR ( dtdst.Month <> 7 ) OR ( dtdst.Year <> 2004 ) OR
                 NOT( dtdst.DstActive ) OR ( dtdst.DayOfWeek <> datetime.Wednesday );
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      jd.Scientific := 2453193.5;
      dtdst.JulianDate := jd;
      dtdst.Subtract( datetime.TimeSpanD( 7.5 ));
      Failure := ( dtdst.Empty ) OR ( dtdst.Millisecond <> 0 ) OR ( dtdst.Second <> 0 ) OR ( dtdst.Minute <> 0 ) OR ( dtdst.Hour <> 12 ) OR
                 ( dtdst.Day <> 29 ) OR ( dtdst.Month <> 6 ) OR ( dtdst.Year <> 2004 ) OR
                 NOT( dtdst.DstActive ) OR ( dtdst.DayOfWeek <> datetime.Tuesday );
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      jd.Scientific := 2453193.5;
      dt.JulianDate := jd;
      jd.Scientific := 2453100.0;
      dtdst.JulianDate := jd;
      ts := dt.Difference( dtdst );
      Failure := ts.Days <> 93.5;
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      jd.Scientific := 2453194.123456;
      dt.JulianDate := jd;
      dt.TrimTime();
      Failure := ( dt.Hour <> 0 ) OR ( dt.Minute <> 0 ) OR ( dt.Second <> 0 ) OR ( dt.Millisecond <> 0 );
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      jd.Scientific := 2453194.123456;
      dt.JulianDate := jd;
      dt.TrimDate();
      Failure := ( dt.Year <> 0 ) OR ( dt.Month <> 0 ) OR ( dt.Day <> 0 );
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      jd.Scientific := 2453193.0;
      dt.JulianDate := jd;
      dtdst.JulianDate := jd;
      dtdst.SetZoneToLocal();
      Failure := ( datetime.GetCurrentUTCBias() <> 0 ) AND (( INTEGER( dt.Hour - dtdst.Hour ) * 60 <> datetime.GetCurrentUTCBias()) OR ( dtdst.UTCBias = 0 ));
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      dtdst.SetZoneToUTC();
      Failure := dt.Hour <> dtdst.Hour;
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      dtdst.SetZone( 60, 60 );
      Failure := ( dt.Hour - dtdst.Hour ) <> 2;
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      jd.Scientific := 2453193.0;
      dt.FromJDToLocal( jd );
      Failure := ( datetime.GetCurrentUTCBias() <> 0 ) AND ( dt.UTCBias = 0 );
      dt.SetZoneToUTC();
      Failure := Failure OR ( dt.UTCBias <> 0 ) OR ( dt.DSTBias <> 0 );
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      jd.Scientific := 2453193.5;
      dt.FromJD( jd, 0, 0 );
      Failure := ( dt.Empty ) OR ( dt.Millisecond <> 0 ) OR ( dt.Second <> 0 ) OR ( dt.Minute <> 0 ) OR ( dt.Hour <> 0 ) OR
                 ( dt.Day <> 7 ) OR ( dt.Month <> 7 ) OR ( dt.Year <> 2004 ) OR
                 NOT( dt.DstActive ) OR ( dt.DayOfWeek <> datetime.Wednesday );
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      jd.Scientific := 2453193.5;
      dt.FromJD( jd, 60, 60 );
      Failure := ( dt.Empty ) OR ( dt.Millisecond <> 0 ) OR ( dt.Second <> 0 ) OR ( dt.Minute <> 0 ) OR ( dt.Hour <> 22 ) OR
                 ( dt.Day <> 6 ) OR ( dt.Month <> 7 ) OR ( dt.Year <> 2004 ) OR
                 NOT( dt.DstActive ) OR ( dt.DayOfWeek <> datetime.Tuesday );
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

(*
   PUBLIC PROCEDURE FromStringOA( CONST String, Format : ARRAY OF WCHAR ) : BOOLEAN;
   PUBLIC PROCEDURE FromLanguageStringOA( Language : Languages.TLanguage; CONST String, Format : ARRAY OF WCHAR ) : BOOLEAN;
   PUBLIC PROCEDURE ToStringOA( Format : ARRAY OF WCHAR; FormatDate : BOOLEAN; FormatTime : BOOLEAN; OUT String : ARRAY OF WCHAR ) : BOOLEAN;
   PUBLIC PROCEDURE ToLanguageStringOA( Language : Languages.TLanguage; Format : ARRAY OF WCHAR; FormatDate : BOOLEAN; FormatTime : BOOLEAN; OUT String : ARRAY OF WCHAR ) : BOOLEAN;

      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;
*)

      IF Failure THEN
         RETURN test.trFailure;
      ELSE
         RETURN test.trSuccess;
      END;
   END Run;
   
(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"DateTime", ADR( Test ));
END CTest;

(*===========================================================================*)

END TDateTime.