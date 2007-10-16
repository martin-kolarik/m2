MODULE bitsetincl;

  PROCEDURE Test;
  VAR
    B : BITSET;
  BEGIN
    INCL( B, 4 ); // BITSET*.T nebyl TOrdinalType
  END Test;

BEGIN
END bitsetincl.