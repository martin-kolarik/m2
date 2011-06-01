MODULE TTls;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   log,
   test,
   testimpl,
   tls;
  
(*===========================================================================*)

CLASS CTest IMPLEMENTS test.ITest;
   PRIVATE VAR
      Host : test.TPHost := NIL;
      Tlss : ARRAY [0..255] OF tls.TPIThreadLocalStorage;

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR );

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

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR );
   VAR
      i : CARDINAL;
   BEGIN
      SELF.Host := Host;

      Host^.StartPhase( L"Exhausting and releasing" );

      // try to exhaust resources
      i := 0;
      WHILE ( i <= HIGH( Tlss )) AND tls.Create( OUT Tlss[i] ) DO
         INC( i );
      END;
      Host^.Log^.LogSC( log.lcError, 0, L"", L"Created count: ", i );
      // and release them
      WHILE i > 0 DO
         DEC( i );
         tls.Dispose( REF Tlss[i] );
      END;

      // now it must succeds
      Host^.StopPhaseWithResult( tls.Create( OUT Tlss[0] ) );

      Host^.StartPhase( L"Set/Get" );

      // set/get data
      Host^.StartParticle();
      Tlss[0]^.Value := 14;
      Host^.StopParticleWithResult( Tlss[0]^.Value = 14 );

      Host^.StartParticle();
      Tlss[0]^.Value := 0;
      Host^.StopParticleWithResult( Tlss[0]^.Value = 0 );

      Host^.StopPhase();
   END Run;
   
(*---------------------------------------------------------------------------*)

   INITIALLY CTest;
   VAR
      i : CARDINAL;
   BEGIN
      FOR i := 0 TO HIGH( Tlss ) DO
         Tlss[i] := NIL;
      END; // FOR

      testimpl.tests()^.AddTest( L"TLS", ADR( Test ));
   END CTest;
      
(*---------------------------------------------------------------------------*)

END CTest;

(*===========================================================================*)

END TTls.