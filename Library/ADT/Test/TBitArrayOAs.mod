MODULE TBitArrayOAs;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

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
   BEGIN
      //-----
      Host^.StartPhase( L"From byte array (to 0)" );

      ba.FromOA( 0, BA );

      IF     ba.In( 00 ) AND NOT ba.In( 01 ) AND
         NOT ba.In( 32 ) AND     ba.In( 33 ) THEN
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
         NOT ba.In( 48 ) AND     ba.In( 49 ) THEN
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