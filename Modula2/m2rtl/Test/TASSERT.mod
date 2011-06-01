MODULE TASSERT;

FROM Debug IMPORT
   Assertion, LogAssertionW;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   log,
   test,
   testimpl;
  
(*===========================================================================*)

CLASS CTest IMPLEMENTS test.ITest;
   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR );
END CTest;

(*---------------------------------------------------------------------------*)

TYPE
   TPTest = POINTER TO CTest;
VAR
   Test : CTest;

(*===========================================================================*)

CLASS IMPLEMENTATION CTest;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR );
   BEGIN
      Host^.StartPhase( L"Do ASSERT" );

      // ASSERT( FALSE );
      // ASSERTLOG( FALSE );
      // ASSERTLOG( FALSE, L"Je to blbe" );
   
      Host^.StopPhase();
   END Run;
   
(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"ASSERT", ADR( Test ));
END CTest;

(*===========================================================================*)

END TASSERT.