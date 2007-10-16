MODULE ptrtype;

TYPE
  TPC = POINTER TO CARDINAL;

VAR
  A : TPC;
  B : CARDINAL;
  C : PTR;
  
PROCEDURE P( X : PTR );
BEGIN
END P;

PROCEDURE Q;
BEGIN
  IF C + C = C THEN END;
  IF C + 1 = C THEN END;
  IF C + 2 = 2 THEN END;
  INC( C );
  
  C := A;
  // C := B; // bad
  C := ADR( B );
  C := PTR( B ); // warning
  C := C;
  
  A := A;
  // A := C; // bad
  A := TPC( C );
  A := TPC( B ); // warning

  B := CARDINAL( A ); // warning
  // B := C; // bad
  B := CARDINAL( C ); // warning
  
  P( A );
END Q;
  
END ptrtype.