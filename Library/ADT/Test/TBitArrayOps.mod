MODULE TBitArrayOps;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE, Zero;

IMPORT
   bitarray,
   log,
   test,
   testimpl;
  
(*===========================================================================*)

CLASS CTest IMPLEMENTS test.ITest;
   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR );
END CTest;

(*===========================================================================*)

VAR
   TestBitArrayOps : CTest;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CTest;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR );
   TYPE
      TCardinalArray = ARRAY [0..11] OF CARDINAL;
   CONST
      BA = TCardinalArray( 055555555H, 0AAAAAAAAH, 088888888H, 044444444H, 022222222H, 011111111H, 055555555H, 0AAAAAAAAH, 088888888H, 044444444H, 022222222H, 011111111H );
   VAR
      ba1 : bitarray.CBitArray;
      ba2 : bitarray.CBitArray;
      filled : CARDINAL;
      va : TCardinalArray;
   BEGIN
      //-----
      Host^.StartPhase( L"Or" );

      ba1.FromOA( 0, BA );
      ba2.FromOA( 16, BA );
      ba1.Or( ba2 );
      ba1.ToOA( 0, OUT va, OUT filled );

      IF ( va[0] = 055555555H ) AND ( va[1] = 0AAAAFFFFH ) AND ( va[11] = 011113333H ) AND
         ( ba1.Count = 176 ) THEN
         Host^.StopPhaseWithResult( TRUE );
      ELSE
         Host^.StopPhaseWithResult( FALSE );
      END;

      //-----
      Host^.StartPhase( L"Xor" );

      ba1.FromOA( 0, BA );
      ba2.FromOA( 16, BA );
      ba1.Xor( ba2 );
      ba1.ToOA( 0, OUT va, OUT filled );

      IF ( va[0] = 000005555H ) AND ( va[1] = 00000FFFFH ) AND ( va[11] = 000003333H ) AND
         ( ba1.Count = 100 ) THEN
         Host^.StopPhaseWithResult( TRUE );
      ELSE
         Host^.StopPhaseWithResult( FALSE );
      END;

      //-----
      Host^.StartPhase( L"And" );

      ba1.FromOA( 0, BA );
      ba2.FromOA( 16, BA );
      ba1.And( ba2 );
      ba1.ToOA( 0, OUT va, OUT filled );

      IF ( va[0] = 055550000H ) AND ( va[1] = 0AAAA0000H ) AND ( va[11] = 011110000H ) AND
         ( ba1.Count = 76 ) THEN
         Host^.StopPhaseWithResult( TRUE );
      ELSE
         Host^.StopPhaseWithResult( FALSE );
      END;

      //-----
      Host^.StartPhase( L"Invert" );

      ba1.FromOA( 0, BA );
      ba1.Invert();
      ba1.ToOA( 0, OUT va, OUT filled );

      IF ( va[0] = 0AAAAAAAAH ) AND ( va[1] = 055555555H ) AND ( va[11] = 0EEEEEEEEH ) AND
         ( ba1.Count = 256 ) THEN
         Host^.StopPhaseWithResult( TRUE );
      ELSE
         Host^.StopPhaseWithResult( FALSE );
      END;
   END Run;

(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"BitArrayOps", ADR( TestBitArrayOps ));
END CTest;

(*===========================================================================*)

END TBitArrayOps.