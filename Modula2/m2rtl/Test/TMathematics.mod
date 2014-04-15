MODULE TMathematics;

FROM Debug IMPORT
   AssertionW;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   Mathematics,
   test,
   testimpl;
  
(*===========================================================================*)

CLASS CTest IMPLEMENTS test.ITest;
   PRIVATE VAR
      Host : test.TPHost := NIL;

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   
   INITIALLY CTest;
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
      lr : LONGREAL;
   BEGIN
      SELF.Host := Host;

      //---------------
      Host^.StartPhase( "Power" );
      lr := Mathematics.Power( 10.0, 3.0 );
      Host^.StopPhase();

      IF Failure THEN
         RETURN test.trFailure;
      ELSE
         RETURN test.trSuccess;
      END;
   END Run;
   
(*---------------------------------------------------------------------------*)

   INITIALLY CTest;
   BEGIN
      testimpl.tests()^.AddTest( L"Mathematics::Primitives", ADR( Test ));
   END CTest;
      
(*---------------------------------------------------------------------------*)

END CTest;

(*===========================================================================*)

END TMathematics.