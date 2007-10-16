MODULE assignandpasstostorageandaddress;

TYPE
  TA = ARRAY [0..1] OF CARDINAL;
  TPC = POINTER TO CARDINAL;
  TPR = POINTER TO RECORD
                     A, B : CARDINAL;
                   END;

PROCEDURE X1( A : ADDRESS ); BEGIN END X1;
PROCEDURE X2( VAR A : ADDRESS ); BEGIN END X2;
PROCEDURE X3( B : BYTE ); BEGIN END X3;
PROCEDURE X4( VAR B : BYTE ); BEGIN END X4;
PROCEDURE X5( A : TPC ); BEGIN END X5;
PROCEDURE X6( VAR A : TPC ); BEGIN END X6;

VAR
  A : ADDRESS;
  PC : POINTER TO TPC;
  PR : POINTER TO TPR;
  B : BYTE;
  I8 : INT8;
  IA : TA;

CONST
  CA = TA( 0, 1 );  
  CS = L"Ahoj";

BEGIN
  X1( PC );
  X2( PC );
  X3( I8 );
  X4( I8 );
  X5( A );
  X6( A );
  X5( PC^ );
  X6( PC^ );
  X1( ADR( IA )); // no cast
  X1( ADR( CA )); // cast
  X1( ADR( CS )); // cast
  X1( PR );
  X2( PR );
  X1( ADR( CS[0] ));
  // X2( ADR( I8 )^ );
  A := PC;
  B := I8;
  PC := A;
  I8 := B;
  A := ADR( IA ); // no cast
  A := ADR( CA ); // cast
  A := ADR( CS ); // cast
  PC := A;
END assignandpasstostorageandaddress.