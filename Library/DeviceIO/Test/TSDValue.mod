MODULE TSDValue;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   datetime,
   iovalue,
   log,
   StringsO,
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
	   s : StringsO.CString;
	   t : iovalue.TValueType;
	   v1, v2, v3 : iovalue.Value;
   BEGIN
      SELF.Host := Host;

      Host^.StartPhase( L"Construction & getters" );

	   FOR t := iovalue.vtVoid TO iovalue.vtDate DO
	      IF t <> iovalue.vtObject THEN
	         v1.Type := t;

            s.FromOA( L"2007.02.02 17.13.00" );
	         v1.Boolean := TRUE;
	         v1.Tristate := 1;
	         v1.Integer := 1034;
	         v1.Long := -257;
	         v1.Float := 14.0;
	         v1.String := s;
	         v1.Date := datetime.NowDC();

	         v1.Undefined := FALSE;
	      END;
	   END; // FOR

	   v2 := v1;

	   v1.Type := iovalue.vtLong;
	   v1.Long := 10;

      s.FromOA( L"10" );
	   v2.Type := iovalue.vtString;
	   v2.String := s;
	   
	   IF v1 > v2 THEN END;
	   IF v1 < v2 THEN END;
	   
	   v3.Type := iovalue.vtLong;
	   v3 := v1 + v1;
	   v3.Type := iovalue.vtString;
	   v3 := v2 + v2;
	   v3 := v1 + v2;

	   v3.Type := iovalue.vtLong;
	   v3 := v1 - v1;
	   v3.Type := iovalue.vtString;
	   v3 := v2 - v2;
	   v3 := v1 - v2;
	   
	   v3.Type := iovalue.vtLong;
	   v1.Long := 10;

	   v3 := v1 * v1;
	   v3 := v2 * v2;
	   v3 := v1 * v2;

	   v3 := v1 / v1;
	   v3 := v2 / v2;
	   v3 := v1 / v2;

	   v1.Long := 0FFFFFFFFFFFFFFFFH;
	   v1.Limit( 8, TRUE, TRUE );

	   v1.Long := 0FFFFFFFFFFFFFFFFH;
	   v1.Limit( 16, TRUE, FALSE );

	   v1.Long := -300;
	   v1.Limit( 8, TRUE, TRUE );

	   v1.Long := -300;
	   v1.Limit( 8, TRUE, FALSE );

	   v1.Long := -300;
	   v1.Limit( 8, FALSE, TRUE );

	   v1.Long := -300;
	   v1.Limit( 8, FALSE, FALSE );

	   v1.Long := 300;
	   v1.Limit( 8, TRUE, FALSE );

      Host^.StopPhaseWithResult( NOT Failure );

      IF Failure THEN
         RETURN test.trFailure;
      ELSE
         RETURN test.trSuccess;
      END;
   END Run;
   
(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"IOValue", ADR( Test ));
END CTest;

(*===========================================================================*)

END TSDValue.