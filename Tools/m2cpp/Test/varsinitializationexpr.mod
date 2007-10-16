MODULE varsinitializationexpr;

PROCEDURE X();
TYPE
  TCHS = SET OF WCHAR;
VAR
  LCHS1 : TCHS := {};
  LCHS2 : TCHS := TCHS{};
  LCHS3 : TCHS := TCHS( 0 );
BEGIN
END X;

END varsinitializationexpr.