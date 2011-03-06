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
      d : CARDINAL;
      dt : datetime.DateTime;
      dtdst : datetime.DateTime;
      Failure : BOOLEAN := FALSE;
      m : CARDINAL;
      jd : datetime.JulianDate;
      ts : datetime.TimeSpan;
      y : INTEGER;
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

(*
   PUBLIC OPERATOR =( CONST Comperand : DateTime ) : BOOLEAN;
   PUBLIC OPERATOR <>( CONST Comperand : DateTime ) : BOOLEAN;
   PUBLIC OPERATOR <( CONST Comperand : DateTime ) : BOOLEAN;
   PUBLIC OPERATOR <=( CONST Comperand : DateTime ) : BOOLEAN;
   PUBLIC OPERATOR >( CONST Comperand : DateTime ) : BOOLEAN;
   PUBLIC OPERATOR >=( CONST Comperand : DateTime ) : BOOLEAN;
*)

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

(*
   PUBLIC OPERATOR +( CONST Addend : TimeSpan ) : DateTime;
   PUBLIC OPERATOR -( CONST Addend : TimeSpan ) : DateTime;
        
   PUBLIC PROCEDURE TrimDate();
   PUBLIC PROCEDURE TrimTime();
   PUBLIC PROCEDURE SetZoneToLocal();
   PUBLIC PROCEDURE SetZoneToUTC();
   PUBLIC PROCEDURE SetZone( UTCBias, DSTBias : INTEGER ); // sets both biases in single call
   PUBLIC PROCEDURE FromJDToLocal( CONST JD : datetime.JulianDate ); // JD is missing time zone information, local one will be set
   PUBLIC PROCEDURE FromJD( CONST JD : datetime.JulianDate; UTCBias, DSTBias : INTEGER ); // JD is missing time zone information
   
   PUBLIC PROCEDURE Add( Addend : TimeSpan );
   PUBLIC PROCEDURE Subtract( Addend : TimeSpan );
   PUBLIC PROCEDURE Difference( CONST Operand : DateTime ) : TimeSpan;
   
   PUBLIC PROCEDURE FromStringOA( CONST String, Format : ARRAY OF WCHAR ) : BOOLEAN;
   PUBLIC PROCEDURE FromLanguageStringOA( Language : Languages.TLanguage; CONST String, Format : ARRAY OF WCHAR ) : BOOLEAN;
   PUBLIC PROCEDURE ToStringOA( Format : ARRAY OF WCHAR; FormatDate : BOOLEAN; FormatTime : BOOLEAN; OUT String : ARRAY OF WCHAR ) : BOOLEAN;
   PUBLIC PROCEDURE ToLanguageStringOA( Language : Languages.TLanguage; Format : ARRAY OF WCHAR; FormatDate : BOOLEAN; FormatTime : BOOLEAN; OUT String : ARRAY OF WCHAR ) : BOOLEAN;
*)

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
   testimpl.tests()^.AddTest( L"DateTime", ADR( Test ));
END CTest;

(*===========================================================================*)

END TDateTime.