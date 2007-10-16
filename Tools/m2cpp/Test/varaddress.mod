MODULE varaddress;

TYPE
  TPC = POINTER TO CARDINAL;

PROCEDURE A( VAR a : ADDRESS );
BEGIN
  A( a );
END A;

PROCEDURE B( VAR a : TPC );
BEGIN
  A( a );
END B;

VAR
  PC1 : POINTER TO ARRAY [0..0] OF BITSET8;
  PC2 : TPC;
  PC3 : POINTER TO RECORD V : BITSET8; END;

BEGIN
  A( PC1 );
  A( PC2 );
  A( PC3 );
END varaddress.