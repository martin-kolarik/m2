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
      Failure : BOOLEAN := FALSE;
      jd : datetime.JulianDate;
      jddst : datetime.JulianDate;
   BEGIN
      SELF.Host := Host;

      Host^.StartPhase( L"Construction" );

(*
   PUBLIC PROPERTY
      FractionOfTheDay : TimeSpan; // values greater than 1 D are trimmed (only the fraction is used)
      Scientific : LONGREAL;

   PUBLIC INLINE OPERATOR :=( CONST Source : JulianDate );

   PUBLIC OPERATOR =( CONST Comperand : JulianDate ) : BOOLEAN;
   PUBLIC OPERATOR <>( CONST Comperand : JulianDate ) : BOOLEAN;
   PUBLIC OPERATOR <( CONST Comperand : JulianDate ) : BOOLEAN;
   PUBLIC OPERATOR <=( CONST Comperand : JulianDate ) : BOOLEAN;
   PUBLIC OPERATOR >( CONST Comperand : JulianDate ) : BOOLEAN;
   PUBLIC OPERATOR >=( CONST Comperand : JulianDate ) : BOOLEAN;
   PUBLIC OPERATOR +( CONST Addend : TimeSpan ) : JulianDate;
   PUBLIC OPERATOR -( CONST Addend : TimeSpan ) : JulianDate;

   PUBLIC PROCEDURE SetNow();
   
   PUBLIC PROCEDURE Less( CONST Comperand : JulianDate ) : BOOLEAN;
   PUBLIC PROCEDURE Greater( CONST Comperand : JulianDate ) : BOOLEAN;
   PUBLIC PROCEDURE Equals( CONST Comperand : JulianDate ) : BOOLEAN;
   PUBLIC PROCEDURE Add( CONST Addend : TimeSpan );
   PUBLIC PROCEDURE Subtract( CONST Addend : TimeSpan );
   PUBLIC PROCEDURE Difference( CONST Operand : JulianDate ) : TimeSpan; // SELF - Operand

   PUBLIC PROCEDURE FromYMD( y : INTEGER; m, d : CARDINAL; CONST fd : TimeSpan );
   PUBLIC PROCEDURE ToYMD( OUT y : INTEGER; OUT m, d : CARDINAL; OUT fd : TimeSpan );
*)

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