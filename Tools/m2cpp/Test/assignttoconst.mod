MODULE assignttoconst;

TYPE
  TR = RECORD
         A : CARDINAL;
       END;
  TPR = POINTER TO TR;
  TPC = POINTER TO CARDINAL;
  TPCC = POINTER TO CONST CARDINAL;
  
PROCEDURE P( CONST A : CARDINAL; CONST B : ARRAY OF CHAR; CONST R : TR; CONST PR : TPR; C : ARRAY OF CHAR; PCC : TPCC; PC : TPC );
CONST
  CC = 14;
VAR
  LR : TR;
  LPR : TPR;
BEGIN
  // R.A := 0; // error
  // A := 0; // error
  // B[10] := 'A'; // error
  // LPR := PR; // error
  LR := PR^; // OK
  // C := 'A'; // error
  // PCC^ := 1; // error
  PCC := ADR( A ); // OK
  PCC := ADR( CC ); // OK
  PC := TPC( ADR( A )); // OK after cast
  PC := TPC( ADR( CC )); // OK after cast
END P;

BEGIN
END assignttoconst.