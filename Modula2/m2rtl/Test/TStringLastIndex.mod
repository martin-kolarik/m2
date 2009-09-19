MODULE TStringLastIndex;

FROM Debug IMPORT
   Assertion, LogAssertionW;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   log,
   Strings,
   test,
   testimpl;
  
(*===========================================================================*)

CLASS CTest IMPLEMENTS test.ITest;
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
   CONST
      TEMPLATE = L"ahaj ahaj ahahajhaj ahaj ahaj ahaj ahaj";
      ITEM = L"ahaj";
   VAR
      Failure : BOOLEAN := FALSE;
      i : INTEGER;
   BEGIN
      Host^.StartPhase( L"FirstIndex" );
      
      i := Strings.IndexOfW( TEMPLATE, ITEM, 0 );
      IF i <> 0 THEN
         Failure := Failure OR TRUE;
      END;

      i := Strings.IndexOfW( TEMPLATE, ITEM, 2 );
      IF i <> 5 THEN
         Failure := Failure OR TRUE;
      END;

      i := Strings.IndexOfW( TEMPLATE, ITEM, 9 );
      IF i <> 12 THEN
         Failure := Failure OR TRUE;
      END;

      i := Strings.IndexOfW( TEMPLATE, ITEM, 10 );
      IF i <> 12 THEN
         Failure := Failure OR TRUE;
      END;

      i := Strings.IndexOfW( TEMPLATE, ITEM, 40 );
      IF i <> -1 THEN
         Failure := Failure OR TRUE;
      END;

      i := Strings.IndexOfW( TEMPLATE, ITEM, 35 );
      IF i <> 35 THEN
         Failure := Failure OR TRUE;
      END;

      i := Strings.IndexOfW( TEMPLATE, ITEM, 34 );
      IF i <> 35 THEN
         Failure := Failure OR TRUE;
      END;

      i := Strings.IndexOfW( TEMPLATE, ITEM, 36 );
      IF i <> -1 THEN
         Failure := Failure OR TRUE;
      END;

      i := Strings.IndexOfW( TEMPLATE, ITEM, 70 );
      IF i <> -1 THEN
         Failure := Failure OR TRUE;
      END;

      i := Strings.IndexOfW( ITEM, TEMPLATE, 0 );
      IF i <> -1 THEN
         Failure := Failure OR TRUE;
      END;

      i := Strings.IndexOfW( TEMPLATE, TEMPLATE, 0 );
      IF i <> 0 THEN
         Failure := Failure OR TRUE;
      END;

      i := Strings.IndexOfW( TEMPLATE, TEMPLATE, -1 );
      IF i <> -1 THEN
         Failure := Failure OR TRUE;
      END;

      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      Host^.StartPhase( L"LastIndex" );

      Failure := FALSE;
      
      i := Strings.LastIndexOfW( TEMPLATE, ITEM, -1 );
      IF i <> -1 THEN
         Failure := Failure OR TRUE;
      END;

      i := Strings.LastIndexOfW( TEMPLATE, ITEM, 0 );
      IF i <> 35 THEN
         Failure := Failure OR TRUE;
      END;

      i := Strings.LastIndexOfW( TEMPLATE, ITEM, 2 );
      IF i <> 30 THEN
         Failure := Failure OR TRUE;
      END;

      i := Strings.LastIndexOfW( TEMPLATE, ITEM, 40 );
      IF i <> -1 THEN
         Failure := Failure OR TRUE;
      END;

      i := Strings.LastIndexOfW( TEMPLATE, ITEM, 20 );
      IF i <> 12 THEN
         Failure := Failure OR TRUE;
      END;

      i := Strings.LastIndexOfW( TEMPLATE, ITEM, 21 );
      IF i <> 12 THEN
         Failure := Failure OR TRUE;
      END;

      i := Strings.LastIndexOfW( TEMPLATE, ITEM, 35 );
      IF i <> 0 THEN
         Failure := Failure OR TRUE;
      END;

      i := Strings.LastIndexOfW( TEMPLATE, ITEM, 34 );
      IF i <> 0 THEN
         Failure := Failure OR TRUE;
      END;

      i := Strings.LastIndexOfW( TEMPLATE, ITEM, 36 );
      IF i <> -1 THEN
         Failure := Failure OR TRUE;
      END;

      i := Strings.LastIndexOfW( TEMPLATE, ITEM, 70 );
      IF i <> -1 THEN
         Failure := Failure OR TRUE;
      END;

      i := Strings.LastIndexOfW( ITEM, TEMPLATE, 0 );
      IF i <> -1 THEN
         Failure := Failure OR TRUE;
      END;

      i := Strings.LastIndexOfW( TEMPLATE, TEMPLATE, 0 );
      IF i <> 0 THEN
         Failure := Failure OR TRUE;
      END;

      i := Strings.LastIndexOfW( TEMPLATE, TEMPLATE, -1 );
      IF i <> -1 THEN
         Failure := Failure OR TRUE;
      END;

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
   testimpl.tests()^.AddTest( L"StringLastIndex", ADR( Test ));
END CTest;

(*===========================================================================*)

END TStringLastIndex.