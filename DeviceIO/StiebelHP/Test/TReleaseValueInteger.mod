MODULE TReleaseValueInteger;
// problem was in ConfigurationName=Release

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   IOValue,
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
      I : INTEGER := 0;
      Result : BOOLEAN := TRUE;
      Value : IOValue.Value;
   BEGIN
      SELF.Host := Host;
   
      Host^.StartPhase( L"I := Value(Float).Integer" );
      
      Value.Type := IOValue.vtFloat;
      Value.Float := 3.14;
      I := Value.Integer;

      Host^.StopPhase();

      IF Result THEN
         RETURN test.trSuccess;
      ELSE      
         RETURN test.trFailure;
      END;
   END Run;
   
(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"TReleaseValueInteger", ADR( Test ));
END CTest;

(*===========================================================================*)

END TReleaseValueInteger.