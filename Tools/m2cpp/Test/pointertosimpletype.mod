MODULE pointertosimpletype;

CONST
  S = 'String';

TYPE
  TA = POINTER TO CHAR;
  TB = POINTER TO TCHAR;
  
VAR
  A : TA;
  B : TB;
  C : POINTER TO CARDINAL;

BEGIN
  A := ADR( S );
  B := ADR( S );
  C := ADR( S );
END pointertosimpletype.