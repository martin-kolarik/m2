MODULE addressingoffset;

TYPE
  TPC = POINTER TO CARDINAL;
  TREC1 = RECORD
           R : CARDINAL;
         END;
  TPREC1 = POINTER TO TREC1;
  TREC2 = RECORD
           PR : TPREC1;
         END;
  TA = ARRAY [0..125] OF WCHAR;
  
VAR
  C : CARDINAL;
  PC : TPC;
  A : ADDRESS;
  R : TREC2;
  X : ARRAY [0..125] OF WCHAR;
  XA : TA;
  PXR : POINTER TO RECORD
                     I1, I2 : CARDINAL;
                   END;
  XR : RECORD
         I1, I2 : CARDINAL;
       END;

BEGIN
  PC^ := 0;
  A^ := 0;
  PC@[4]^ := 0;
  A@[0]^ := 0;
  R.PR@[1]^.R := 0;
  
  C := PC^;
  C := A^;
  C := PC@[4]^;
  C := A@[0]^;
  C := R.PR@[1]^.R;
  
  IF ADR( X )@[4] = A THEN END;
  IF ADR( X )@[4]^ = X THEN END;
  IF ADR( XA )@[4] = A THEN END;
  IF ADR( XA )@[4]^ = XA THEN END;

  IF PXR@[4] = PXR THEN END;
  IF ADR( XR )@[4]^ = XR THEN END;
END addressingoffset.