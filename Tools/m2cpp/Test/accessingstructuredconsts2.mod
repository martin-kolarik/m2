MODULE accessingstructuredconsts2;

TYPE
  TA = ARRAY [0..7] OF CARDINAL;

CONST
  C1 = TA( 0, 1, 2, 3, 4, 5, 6, 7 );
  C2 = BITSET{ C1[1] };
  C3 = BITSET{ C1[0] };
  
END accessingstructuredconsts2.
