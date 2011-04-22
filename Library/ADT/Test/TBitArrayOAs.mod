MODULE TBitArrayOAs;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE, Zero;

IMPORT
   bitarray,
   log,
   test,
   testimpl;
  
(*===========================================================================*)

CLASS CTest IMPLEMENTS test.ITest;
   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
END CTest;

(*===========================================================================*)

VAR
   TestBitArrayOAs : CTest;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CTest;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   TYPE
      TCardinalArray = ARRAY [0..11] OF CARDINAL;
   CONST
      BA = TCardinalArray( 055555555H, 0AAAAAAAAH, 088888888H, 044444444H, 022222222H, 011111111H, 055555555H, 0AAAAAAAAH, 088888888H, 044444444H, 022222222H, 011111111H );
   VAR
      ba : bitarray.CBitArray;
      filled : CARDINAL;
      va : TCardinalArray;
   BEGIN
      //-----
      Host^.StartPhase( L"From byte array (to 0)" );

      ba.FromOA( 0, BA );

      IF     ba.In( 00 ) AND NOT ba.In( 01 ) AND
         NOT ba.In( 32 ) AND     ba.In( 33 ) AND
           ( ba.Count = 128 ) THEN
         Host^.StopPhaseWithResult( test.trSuccess );
      ELSE
         Host^.StopPhaseWithResult( test.trFailure );
      END;

      //-----
      Host^.StartPhase( L"From byte array (to 16)" );

      ba.Clear();
      ba.FromOA( 16, BA );

      IF NOT ba.In( 00 ) AND NOT ba.In( 01 ) AND
             ba.In( 16 ) AND NOT ba.In( 17 ) AND
         NOT ba.In( 48 ) AND     ba.In( 49 ) AND
           ( ba.Count = 128 ) THEN
         Host^.StopPhaseWithResult( test.trSuccess );
      ELSE
         Host^.StopPhaseWithResult( test.trFailure );
      END;

      //-----
      Host^.StartPhase( L"From byte array (to 128, no allocation)" );

      ba.Clear();
      ba.ResizeOnSet := FALSE;
      ba.FromOA( 128, BA );

      IF NOT ba.In(  00 ) AND NOT ba.In(  01 ) AND
             ba.In( 128 ) AND NOT ba.In( 129 ) AND
         NOT ba.In( 382 ) AND     ba.In( 383 ) AND
           ( ba.Count = 104 ) THEN
         Host^.StopPhaseWithResult( test.trSuccess );
      ELSE
         Host^.StopPhaseWithResult( test.trFailure );
      END;

      //-----
      Host^.StartPhase( L"From byte array (to 1024, no allocation)" );

      ba.Clear();
      ba.ResizeOnSet := FALSE;
      ba.FromOA( 1024, BA );

      IF NOT ba.In(  00 ) AND NOT ba.In(  01 ) AND
         NOT ba.In( 128 ) AND NOT ba.In( 129 ) AND
         NOT ba.In( 382 ) AND NOT ba.In( 383 ) AND
           ( ba.Count = 0 ) THEN
         Host^.StopPhaseWithResult( test.trSuccess );
      ELSE
         Host^.StopPhaseWithResult( test.trFailure );
      END;

      //-----
      Host^.StartPhase( L"To whole byte array" );

      Zero( ADR( va ), SIZE( va ));
      ba.Incl( 5 );
      ba.Incl( 128 );
      ba.Incl( 382 );
      ba.Incl( 383 );
      ba.ToOA( 0, OUT va, OUT filled );

      IF ( filled = 4*12 ) AND ( va[0] = 020H ) AND ( va[4] = 01H ) AND ( va[11] = 0C0000000H ) THEN
         Host^.StopPhaseWithResult( test.trSuccess );
      ELSE
         Host^.StopPhaseWithResult( test.trFailure );
      END;

      //-----
      Host^.StartPhase( L"To byte array (from 16th bit)" );

      Zero( ADR( va ), SIZE( va ));
      ba.Incl( 5 );
      ba.Incl( 128 );
      ba.Incl( 382 );
      ba.Incl( 383 );
      ba.ToOA( 16, OUT va, OUT filled );

      IF ( filled = 46 ) AND ( va[0] = 0H ) AND ( va[3] = 010000H ) AND ( va[11] = 0C000H ) THEN
         Host^.StopPhaseWithResult( test.trSuccess );
      ELSE
         Host^.StopPhaseWithResult( test.trFailure );
      END;

      //-----
      Host^.StartPhase( L"To byte array (from 1024th bit)" );

      Zero( ADR( va ), SIZE( va ));
      ba.Incl( 5 );
      ba.Incl( 128 );
      ba.Incl( 382 );
      ba.Incl( 383 );
      ba.ToOA( 1024, OUT va, OUT filled );

      IF ( filled = 0 ) AND ( va[0] = 0H ) AND ( va[3] = 0H ) AND ( va[11] = 0H ) THEN
         Host^.StopPhaseWithResult( test.trSuccess );
      ELSE
         Host^.StopPhaseWithResult( test.trFailure );
      END;

      RETURN test.trSuccess;
   END Run;

(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"BitArrayOAs", ADR( TestBitArrayOAs ));
END CTest;

(*===========================================================================*)

END TBitArrayOAs.