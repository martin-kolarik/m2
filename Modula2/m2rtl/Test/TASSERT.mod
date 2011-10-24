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
   BEGIN
      Host^.StartPhase( L"Do ASSERT" );

      // ASSERT( FALSE );
      // Host^.ParticleWithAssert( L"Simple assert" );

      // ASSERTLOG( FALSE );
      // Host^.ParticleWithAssert( L"Assert with log and no text" );

      // ASSERTLOG( FALSE, L"Je to blbe" );
      // Host^.ParticleWithAssert( L"Assert with log and text" );
   
      Host^.StopPhase();

      RETURN test.trSuccess;
   END Run;
   
(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"ASSERT", ADR( Test ));
END CTest;

(*===========================================================================*)

END TASSERT.