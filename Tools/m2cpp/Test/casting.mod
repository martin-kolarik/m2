MODULE casting;

TYPE
  TN = CARDINAL;
  TA = ARRAY [0..1] OF CHAR;
  TR = RECORD
         C, D : CARDINAL;
       END;

  TPN = POINTER TO TN;
  TPA = POINTER TO TA;
  TPR = POINTER TO TR;
  
  PROCEDURE PN1( N : TN );
  BEGIN
  END PN1;

  PROCEDURE PN2( PN : TPN );
  BEGIN
  END PN2;

  PROCEDURE PA1( A : TA );
  BEGIN
  END PA1;

  PROCEDURE PA2( PA : TPA );
  BEGIN
  END PA2;

  PROCEDURE PR1( R : TR );
  BEGIN
  END PR1;

  PROCEDURE PR2( PR : TPR );
  BEGIN
  END PR2;

VAR
  N : TN;
  A : TA;
  R : TR;

BEGIN
  PN1( TN( 0 ));
  PN2( TPN( 0 ));
  // PA1( TA( 0 )); // o, n
  PA2( TPA( 0 ));
  // PR1( TR( 0 )); // n
  PR2( TPR( 0 ));

  PN1( TN( R ));
  PN2( TPN( R ));
  PA1( TA( R ));
  PA2( TPA( R ));
  PR1( TR( R ));
  PR2( TPR( R ));

  PN1( TN( '  ' ));
  PN2( TPN( '  ' )); // o
  PA1( TA( '  ' )); // o, n for CARDINAL
  PA2( TPA( '  ' )); // o
  // PR1( TR( '  ' )); // n
  PR2( TPR( '  ' )); // o

  PN2( TPN( ' ' ));
END casting.