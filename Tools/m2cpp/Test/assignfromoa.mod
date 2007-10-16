MODULE assignfromoa;

TYPE
  TA = ARRAY [0..1] OF CHAR;
  TPA = POINTER TO TA;
VAR
  VA : TPA;

  PROCEDURE P( A : ARRAY OF CHAR );
  BEGIN
    VA := ADR( A );
  END P;

BEGIN
END assignfromoa.