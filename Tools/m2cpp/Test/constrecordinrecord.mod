MODULE constrecordinrecord;

TYPE
  R0 = RECORD
         CASE : CARDINAL OF
         | 0 :
           A : CARDINAL;
           B : CARDINAL;
         | 1 :
           C : BOOLEAN;
         END;
       END;
  R1 = R0;
  R2 = RECORD
         R : R1;
         C : CARDINAL;
       END;
  A0 = ARRAY [0..1] OF CHAR;

CONST
  C2 = R2( R1( 0, 0, 0 ), CARDINAL( 0 ));
  C0 = A0( C'a', C'b' );
  C1 = A0( CHAR( 13 ), CHAR( 10 ));

BEGIN
END constrecordinrecord.