MODULE SetOfTypes;

TYPE
   TEnum = ( e1, e2 );
   TSE = SET OF TEnum;

VAR
  S1 : SET OF CARD8;
  S2 : SET OF BYTE;
  S3 : TSE;
  S6 : BITSET16;
  
PROCEDURE X( S4 : SET OF BYTE; S5 : SET OF CARD8 );
BEGIN
(*
  S1 := CARD8{0};
  S2 := BYTE{0};
  S1 := {0};
  S2 := {0};
  // S3 := {0}; // error
  S3 := TSE{e1};
  S6 := {0};
*)
  IF {} = {} THEN
  END;
  IF {}*{} = {} THEN
  END;
END X;

END SetOfTypes.