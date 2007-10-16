MODULE initializevars;

  PROCEDURE WithVAR( VAR A : CARDINAL );
  BEGIN
  END WithVAR;

  PROCEDURE UseVAR( A : CARDINAL );
  VAR
    B : CARDINAL;
  BEGIN
    WithVAR( B );
    UseVAR( B );
  END UseVAR;

  PROCEDURE TestNEW();
  TYPE
    TPC = POINTER TO CARDINAL;
  VAR
    A : ADDRESS;
  BEGIN
    NEW( TPC( A ));
    IF A = NIL THEN
    END;
  END TestNEW;

BEGIN
END initializevars.