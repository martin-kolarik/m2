MODULE assigntooa;

  PROCEDURE P2( VAR A : ARRAY OF CHAR ); FORWARD;

  PROCEDURE P1( A : ARRAY OF CHAR );
  BEGIN
    // P2( A ); // error
    // A := ""; // error
  END P1;

  PROCEDURE P2( VAR A : ARRAY OF CHAR );
  BEGIN
    P1( A ); // OK
    A := "";
  END P2;
  
  PROCEDURE P3( VAR A : ARRAY OF CHAR );
  TYPE
    T1 = ARRAY [0..7] OF CHAR;
  CONST
    C1 = "Klikkos";
  VAR
    S1 : ARRAY [0..15] OF CHAR;
    S2 : ARRAY [0..31] OF CHAR;
    S3 : T1;
  BEGIN
    S1 := C1;
    S2 := C1;
    S3 := C1;
    A := C1;
    A := S1;
    A := S3;
    S1 := A;
    S1 := S2;
    S1 := S3;
    S1 := 'AA';
    S1 := 'A';
  END P3;

END assigntooa.