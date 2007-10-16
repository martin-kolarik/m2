MODULE pointertotypeandarray;

  PROCEDURE P1( P : ARRAY OF CARDINAL );
  TYPE
    TPC = POINTER TO CARDINAL;
    TA = ARRAY [0..0] OF CARDINAL;
  VAR
    PC : TPC;
    A : TA;

    PROCEDURE X( PC : TPC );
    BEGIN
    END X;

  BEGIN
    PC := ADR( P ); // ok
    PC := ADR( A ); // ok
    X( ADR( P ));
    X( ADR( A ));
  END P1;

  PROCEDURE P2( P : ARRAY OF CHAR );
  TYPE
    TPC = POINTER TO CHAR;
    TA = ARRAY [0..0] OF CHAR;
  VAR
    PC : TPC;
    A : TA;

    PROCEDURE X( PC : TPC );
    BEGIN
    END X;

  BEGIN
    PC := ADR( P ); // ok
    PC := ADR( A ); // ok
    PC := C'  '; // ok
    X( ADR( P ));
    X( ADR( A ));
    X( C'  ' );
  END P2;

BEGIN
END pointertotypeandarray.