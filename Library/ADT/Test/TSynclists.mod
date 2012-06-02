MODULE TSynclists;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   baseobject,
   log,
   sync,
   synclists,
   test,
   testimpl;
  
(*===========================================================================*)

TYPE
   TPTest = POINTER TO CTest;

(*---------------------------------------------------------------------------*)

CLASS CTest IMPLEMENTS test.ITest;
   PUBLIC VAR
      Host : test.TPHost := NIL;

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
END CTest;

(*===========================================================================*)

VAR
   Test : CTest;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CTest;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   VAR
      ba : ARRAY [0..9] OF baseobject.BASE;
      Failure : BOOLEAN := FALSE;
      c : CARDINAL;
      list : synclists.CPtrSyncList;
   BEGIN
      SELF.Host := Host;

      // fill in the list
      FOR c := 0 TO HIGH( ba ) DO
         list.Add( ADR( ba[c] ), 0 );
      END; // FOR

      Host^.StartPhase( L"Various operations with read locked list" );

      list.Lock^.LockRead( sync.FORSAFETY );
      
      Host^.StopPhaseWithResult( NOT Failure );

      RETURN test.trUnknown;
   END Run;
   
(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"Synclists", ADR( Test ));
END CTest;

(*===========================================================================*)

END TSynclists.
