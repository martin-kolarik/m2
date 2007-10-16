MODULE accessingstructuredconsts;

TYPE
  TA = ARRAY [0..7] OF BYTE;
  TR = RECORD
         CASE : BOOLEAN OF
         | TRUE :
           A1 : BOOLEAN;
         | FALSE :
           A2 : ADDRESS;
         END;
         B : CARDINAL;
         C : TA;
       END;

CONST
  v1 = 4;
  v2 = 8;

CONST
  C1 = TA( 0, 1, 2, 3, 4, 5, 6, 7 );
  C2 = C1[4];
  C3 = TR( TRUE, FALSE, 0, C1 );
  C4 = C3.A1;
  // C5 = C3.A2; -- error accessing not first part
  C6 = C3.C[1];
  C7 = BITSET{ 0, 1 };
  C8 = BITSET{ CARDINAL( C3.C[0] ), CARDINAL( C3.C[1] ) };
  
CONST
  b1 = {v1};
  b2 = {v2};
  b3 = {v2, CARDINAL( C2 )};
  
PROCEDURE X();
VAR
  A : CARDINAL := 5;
BEGIN
  CASE A OF
  | CARDINAL( C2 ) :
  | CARDINAL( C4 ) :
  | CARDINAL( C6 ) :
  END;
  CASE A OF
  | CARDINAL( b1 ) :
  | CARDINAL( b2 ) :
  | CARDINAL( b3 ) :
  END;
END X;

END accessingstructuredconsts.
