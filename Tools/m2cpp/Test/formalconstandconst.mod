MODULE formalconstandconst;

TYPE
  TPC = POINTER TO CARDINAL;
  TPCC = POINTER TO CONST CARDINAL;

  PROCEDURE P1( VAR A : CARDINAL );
  BEGIN
  END P1;

  PROCEDURE P2( CONST A : CARDINAL );
  BEGIN
  END P2;

  PROCEDURE P3( A : TPC );
  BEGIN
  END P3;

  PROCEDURE P4( A : TPCC );
  BEGIN
  END P4;

  PROCEDURE P5( CONST A : ADDRESS );
  BEGIN
  END P5;
  
  PROCEDURE P6( CONST PC : TPC );
  BEGIN
    P5( PC );
  END P6;

  PROCEDURE PC1( CONST A : CARDINAL );
  BEGIN
    // P1( A ); // error
    P2( A ); // OK
    // P3( ADR( A )); // error
    P4( ADR( A )); // OK
    // A := 0; // error
  END PC1;

  PROCEDURE PC2( VAR A : CARDINAL );
  BEGIN
    P1( A ); // OK
    P2( A ); // OK
    P3( ADR( A )); // OK
    P4( ADR( A )); // OK
    A := 0; // OK
  END PC2;

  PROCEDURE PC3( A : TPCC );
  BEGIN
    // P1( A^ ); // error
    P2( A^ ); // OK
    // P3( A ); // error
    P4( A ); // OK
    // A := NIL; // error
    // A^ := 0; // error
  END PC3;

BEGIN
END formalconstandconst.