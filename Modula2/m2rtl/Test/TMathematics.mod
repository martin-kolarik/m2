MODULE TMathematics;

FROM Debug IMPORT
   AssertionW;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   lr,
   Mathematics,
   test,
   testimpl;
  
(*===========================================================================*)

CLASS CTest IMPLEMENTS test.ITest;
   PRIVATE VAR
      Host : test.TPHost := NIL;

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;

   PRIVATE PROCEDURE PhaseLR() : BOOLEAN;
   PRIVATE PROCEDURE PhaseFunctions() : BOOLEAN;
   
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
      Success : BOOLEAN := FALSE;
   BEGIN
      SELF.Host := Host;

      //---------------
      Host^.StartPhase( "LR" );
      Success := PhaseLR();
      Host^.StopPhaseWithResult( Success );
      Failure := Failure OR NOT Success;

      //---------------
      Host^.StartPhase( "Functions" );
      Success := PhaseFunctions();
      Host^.StopPhaseWithResult( Success );
      Failure := Failure OR NOT Success;

      IF Failure THEN
         RETURN test.trFailure;
      ELSE
         RETURN test.trSuccess;
      END;
   END Run;
   
(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE PhaseLR() : BOOLEAN;

      PROCEDURE LR( CONST bits : CARD64 ) : LONGREAL;
      TYPE
         #save, option( pack => 1 )
         LR2B  = RECORD
                    CASE : CARDINAL OF
                    | 0 : lr : LONGREAL;
                    | 1 : bits : CARD64;
                    END; // CASE
                 END; // RECORD
         PLR2B = POINTER TO LR2B;
         #restore
      BEGIN
         RETURN PLR2B( ADR( bits ))^.lr;
      END LR;

   CONST
      NAN1 = CARD64( 07FF0000000000001H );
      NAN2 = CARD64( 07FF0001000000000H );
      EXP1 = CARD64( 04060001000000001H );
      EXP2 = CARD64( 03F70001100000011H );
      EQ10 = CARD64( 03FE0001100000000H );
      EQ11 = CARD64( 03FE0001100000001H );
      EQ12 = CARD64( 03FE0001100000002H );
      EQ13 = CARD64( 03FE0001100000003H );
      EQ14 = CARD64( 03FE0001100000004H );
      EQ15 = CARD64( 03FE0001100000005H );
      EQ16 = CARD64( 03FE0001100000006H );
      EQ20 = CARD64( 0C210001100000000H );
      EQ21 = CARD64( 0C210001100000001H );
      EQ22 = CARD64( 0C210001100000002H );
      EQ23 = CARD64( 0C210001100000003H );
      EQ24 = CARD64( 0C210001100000004H );
      EQ25 = CARD64( 0C210001100000005H );
      EQ26 = CARD64( 0C210001100000006H );
      EQ30 = CARD64( 03FF0001100000001H );
      EQ31 = CARD64( 0BFF0001100000001H );
      EQ40 = CARD64( 00000000000000001H );
      EQ41 = CARD64( 08000000000000001H );
   VAR
      Success : BOOLEAN := TRUE;
   BEGIN
      Success := lr.IsNaN( LR( NAN1 )) AND Success;
      Success := lr.IsNaN( LR( NAN2 )) AND Success;

      Success := ( lr.TwoExponent( LR( EXP1 )) = 0406H-03FFH ) AND Success;
      Success := ( lr.TwoExponent( LR( EXP2 )) = 03F7H-03FFH ) AND Success;
      Success := ( lr.TenExponent( LR( EXP1 )) = +2 ) AND Success;
      Success := ( lr.TenExponent( LR( EXP2 )) = -3 ) AND Success;

      Success := lr.Equals( LR( EQ10 ), LR( EQ10 ), 0 ) AND Success;
      Success := lr.Equals( LR( EQ11 ), LR( EQ11 ), 0 ) AND Success;
      Success := lr.Equals( LR( EQ12 ), LR( EQ12 ), 0 ) AND Success;
      Success := lr.Equals( LR( EQ13 ), LR( EQ13 ), 0 ) AND Success;
      Success := lr.Equals( LR( EQ14 ), LR( EQ14 ), 0 ) AND Success;
      Success := lr.Equals( LR( EQ15 ), LR( EQ15 ), 0 ) AND Success;
      Success := lr.Equals( LR( EQ16 ), LR( EQ16 ), 0 ) AND Success;
      Success := lr.Equals( LR( EQ10 ), LR( EQ10 ), 3 ) AND Success;
      Success := lr.Equals( LR( EQ11 ), LR( EQ11 ), 3 ) AND Success;
      Success := lr.Equals( LR( EQ12 ), LR( EQ12 ), 3 ) AND Success;
      Success := lr.Equals( LR( EQ13 ), LR( EQ13 ), 3 ) AND Success;
      Success := lr.Equals( LR( EQ14 ), LR( EQ14 ), 3 ) AND Success;
      Success := lr.Equals( LR( EQ15 ), LR( EQ15 ), 3 ) AND Success;
      Success := lr.Equals( LR( EQ16 ), LR( EQ16 ), 3 ) AND Success;

      Success := lr.Equals( LR( EQ10 ), LR( EQ11 ), 1 ) AND Success;
      Success := lr.Equals( LR( EQ10 ), LR( EQ12 ), 2 ) AND Success;
      Success := lr.Equals( LR( EQ10 ), LR( EQ13 ), 3 ) AND Success;
      Success := lr.Equals( LR( EQ10 ), LR( EQ14 ), 4 ) AND Success;
      Success := lr.Equals( LR( EQ10 ), LR( EQ15 ), 5 ) AND Success;
      Success := lr.Equals( LR( EQ10 ), LR( EQ16 ), 6 ) AND Success;
      Success := lr.Equals( LR( EQ10 ), LR( EQ11 ), 3 ) AND Success;
      Success := lr.Equals( LR( EQ10 ), LR( EQ12 ), 4 ) AND Success;
      Success := lr.Equals( LR( EQ10 ), LR( EQ13 ), 5 ) AND Success;
      Success := lr.Equals( LR( EQ10 ), LR( EQ14 ), 6 ) AND Success;
      Success := lr.Equals( LR( EQ10 ), LR( EQ15 ), 7 ) AND Success;
      Success := lr.Equals( LR( EQ10 ), LR( EQ16 ), 8 ) AND Success;
      Success := NOT lr.Equals( LR( EQ10 ), LR( EQ11 ), 0 ) AND Success;
      Success := NOT lr.Equals( LR( EQ10 ), LR( EQ12 ), 1 ) AND Success;
      Success := NOT lr.Equals( LR( EQ10 ), LR( EQ13 ), 2 ) AND Success;
      Success := NOT lr.Equals( LR( EQ10 ), LR( EQ14 ), 3 ) AND Success;
      Success := NOT lr.Equals( LR( EQ10 ), LR( EQ15 ), 4 ) AND Success;
      Success := NOT lr.Equals( LR( EQ10 ), LR( EQ16 ), 5 ) AND Success;

      Success := lr.Equals( LR( EQ20 ), LR( EQ20 ), 0 ) AND Success;
      Success := lr.Equals( LR( EQ21 ), LR( EQ21 ), 0 ) AND Success;
      Success := lr.Equals( LR( EQ22 ), LR( EQ22 ), 0 ) AND Success;
      Success := lr.Equals( LR( EQ23 ), LR( EQ23 ), 0 ) AND Success;
      Success := lr.Equals( LR( EQ24 ), LR( EQ24 ), 0 ) AND Success;
      Success := lr.Equals( LR( EQ25 ), LR( EQ25 ), 0 ) AND Success;
      Success := lr.Equals( LR( EQ26 ), LR( EQ26 ), 0 ) AND Success;
      Success := lr.Equals( LR( EQ20 ), LR( EQ20 ), 3 ) AND Success;
      Success := lr.Equals( LR( EQ21 ), LR( EQ21 ), 3 ) AND Success;
      Success := lr.Equals( LR( EQ22 ), LR( EQ22 ), 3 ) AND Success;
      Success := lr.Equals( LR( EQ23 ), LR( EQ23 ), 3 ) AND Success;
      Success := lr.Equals( LR( EQ24 ), LR( EQ24 ), 3 ) AND Success;
      Success := lr.Equals( LR( EQ25 ), LR( EQ25 ), 3 ) AND Success;
      Success := lr.Equals( LR( EQ26 ), LR( EQ26 ), 3 ) AND Success;

      Success := lr.Equals( LR( EQ20 ), LR( EQ21 ), 1 ) AND Success;
      Success := lr.Equals( LR( EQ20 ), LR( EQ22 ), 2 ) AND Success;
      Success := lr.Equals( LR( EQ20 ), LR( EQ23 ), 3 ) AND Success;
      Success := lr.Equals( LR( EQ20 ), LR( EQ24 ), 4 ) AND Success;
      Success := lr.Equals( LR( EQ20 ), LR( EQ25 ), 5 ) AND Success;
      Success := lr.Equals( LR( EQ20 ), LR( EQ26 ), 6 ) AND Success;
      Success := lr.Equals( LR( EQ20 ), LR( EQ21 ), 3 ) AND Success;
      Success := lr.Equals( LR( EQ20 ), LR( EQ22 ), 4 ) AND Success;
      Success := lr.Equals( LR( EQ20 ), LR( EQ23 ), 5 ) AND Success;
      Success := lr.Equals( LR( EQ20 ), LR( EQ24 ), 6 ) AND Success;
      Success := lr.Equals( LR( EQ20 ), LR( EQ25 ), 7 ) AND Success;
      Success := lr.Equals( LR( EQ20 ), LR( EQ26 ), 8 ) AND Success;
      Success := NOT lr.Equals( LR( EQ20 ), LR( EQ21 ), 0 ) AND Success;
      Success := NOT lr.Equals( LR( EQ20 ), LR( EQ22 ), 1 ) AND Success;
      Success := NOT lr.Equals( LR( EQ20 ), LR( EQ23 ), 2 ) AND Success;
      Success := NOT lr.Equals( LR( EQ20 ), LR( EQ24 ), 3 ) AND Success;
      Success := NOT lr.Equals( LR( EQ20 ), LR( EQ25 ), 4 ) AND Success;
      Success := NOT lr.Equals( LR( EQ20 ), LR( EQ26 ), 5 ) AND Success;

      Success := NOT lr.Equals( LR( EQ30 ), LR( EQ31 ), 3 ) AND Success;
      Success := NOT lr.Equals( LR( EQ30 ), LR( EQ31 ), 4 ) AND Success;

      Success := NOT lr.Equals( LR( EQ40 ), LR( EQ41 ), 0 ) AND Success;
      Success := NOT lr.Equals( LR( EQ40 ), LR( EQ41 ), 1 ) AND Success;
      Success := lr.Equals( LR( EQ40 ), LR( EQ41 ), 2 ) AND Success;
      Success := lr.Equals( LR( EQ40 ), LR( EQ41 ), 3 ) AND Success;

      RETURN Success;
   END PhaseLR;
   
(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE PhaseFunctions() : BOOLEAN;
   VAR
      Success : BOOLEAN := TRUE;
   BEGIN
      Success := Mathematics.EqualsUlps( Mathematics.Power( 10.0, 3.0, 0.0 ), 1000.0, 10 ) AND Success;
      Success := Mathematics.EqualsUlps( Mathematics.Power( 10.0, -3.0, 0.0 ), 0.001, 10 ) AND Success;
      Success := Mathematics.EqualsUlps( Mathematics.Power( 3.0, 3.0, 0.0 ), 27.0, 10 ) AND Success;
      Success := Mathematics.EqualsUlps( Mathematics.Power( 3.0, -3.0, 0.0 ), 1.0/27.0, 10 ) AND Success;
      Success := Mathematics.EqualsUlps( Mathematics.Power( 3.0, 1.0/3.0, 0.0 ), 1.4422495703074083823216383054985, 10 ) AND Success;
      Success := Mathematics.EqualsUlps( Mathematics.Power( 3.0, -1.0/3.0, 0.0 ), 0.69336127435063470484335227478596, 10 ) AND Success;
      Success := Mathematics.EqualsUlps( Mathematics.Power( -3.0, 1.0/3.0, -2.3 ), -2.3, 10 ) AND Success;
      Success := Mathematics.EqualsUlps( Mathematics.Power( -3.0, -1.0/3.0, -1.0 ), -1.0, 10 ) AND Success;

      RETURN Success;
   END PhaseFunctions;

(*---------------------------------------------------------------------------*)

   INITIALLY CTest;
   BEGIN
      testimpl.tests()^.AddTest( L"Mathematics::Primitives", ADR( Test ));
   END CTest;
      
(*---------------------------------------------------------------------------*)

END CTest;

(*===========================================================================*)

END TMathematics.