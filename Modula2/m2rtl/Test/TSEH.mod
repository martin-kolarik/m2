MODULE TSEH;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   log,
   Sync,
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
      Result : BOOLEAN := TRUE;
      i : CARDINAL := 0;
      a : ADDRESS := NIL;
   BEGIN
      SELF.Host := Host;
   
      Host^.StartPhase( L"C0000005H" );

      TRY
         a^ := 0;
         Result := FALSE;
         Host^.Log^.LogS( log.dlcError, L"", "Not thrown" );
      EXCEPT TRISTATE( 1 ) DO
         Host^.Log^.LogS( log.dlcInfo, L"", "OK, thrown" );
      END;

      Host^.StopPhase();

      Host^.StartPhase( L"Divide by zero" );

      TRY
         i := i / 0;
         Result := FALSE;
         Host^.Log^.LogS( log.dlcError, L"", "Not thrown" );
      EXCEPT TRISTATE( 1 ) DO
         Host^.Log^.LogS( log.dlcInfo, L"", "OK, thrown" );
      END;

      Host^.StopPhase();

      IF Result THEN
         RETURN test.trSuccess;
      ELSE      
         RETURN test.trFailure;
      END;
   END Run;
   
(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"TSEH", ADR( Test ));
END CTest;

(*===========================================================================*)

END TSEH.