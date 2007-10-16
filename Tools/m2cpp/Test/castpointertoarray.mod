MODULE castpointertoarray;

  TYPE
    TPCH = POINTER TO CHAR;
    TString = ARRAY [0..7] OF CHAR;
    TPString = POINTER TO TString;

  PROCEDURE F() : TPCH;
  BEGIN
    RETURN NIL;
  END F;

  PROCEDURE P( C : ARRAY OF CHAR );
  BEGIN
  END P;

BEGIN
  P( TPString( F() )^ );
END castpointertoarray.