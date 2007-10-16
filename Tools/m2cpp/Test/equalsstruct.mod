MODULE equalsstruct;

TYPE
  TR = RECORD
         R : CARDINAL;
       END;
  TA = ARRAY [0..125] OF WCHAR;
  TS = SET OF CARD16;
  
VAR
  R1, R2 : TR;
  A1, A2 : TA;
  S1, S2 : TS;

BEGIN
  IF R1 = R2 THEN END;
  IF A1 = A2 THEN END;
  IF S1 = S2 THEN END;
  IF R1 <> R2 THEN END;
  IF A1 <> A2 THEN END;
  IF S1 <> S2 THEN END;
END equalsstruct.