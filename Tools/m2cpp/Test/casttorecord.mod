MODULE casttorecord;
TYPE
  TA = ARRAY [0..7] OF BYTE;
  TR = RECORD
         CASE : SHORTCARD OF
         | 0 : A : TA;
         END;
       END;
  TPR = POINTER TO TR;
  
  PROCEDURE P( VAR R : TR );
  BEGIN
  END P;
       
VAR
  A : LONGREAL;
  R : TR;

BEGIN
  R := TR( A );
  P( TR( TPR( A )^.A[0] ));
END casttorecord.