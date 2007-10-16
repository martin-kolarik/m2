MODULE ptrtoarray;

  PROCEDURE Test;
  TYPE
    TAWCH = ARRAY [0..0] OF WCHAR;
    TPAWCH = POINTER TO TAWCH;
    TPX = POINTER TO COpaque; // allowing BoundType = TypeDenoter complicates creation of opaque types
    TPA1 = POINTER TO ARRAY [0..0] OF BITSET8;
    TPA3 = POINTER TO ARRAY [0..0] OF ARRAY [1..2] OF ARRAY [1..3] OF BITSET8;
  VAR
    CH : WCHAR;
    sa1 : TPA1;
    sa3 : TPA3;
  BEGIN
    CH := TPAWCH( 0 )^[1];
    INCL( sa1^[1], 4 );
    INCL( sa3^[1][2][3], 4 );
  END Test;

BEGIN
END ptrtoarray.