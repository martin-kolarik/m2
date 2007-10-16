MODULE reportingoaerrors;

PROCEDURE OAP( CONST S : ARRAY OF CHAR; OUT T : ARRAY OF WCHAR );
BEGIN
  T := L'';
END OAP;

PROCEDURE X();
VAR
  A : ADDRESS := NIL;
  B : POINTER TO RECORD
                   A : POINTER TO RECORD
                                    B : CARDINAL;
                                  END;
                 END;
  C : CARDINAL := 0;
  D : POINTER TO CARDINAL;
  R : RECORD
        B : CARDINAL;
      END;
BEGIN
  OAP( OA( 1, PCHAR( A )), OUT OA( 1, PWCHAR( A )));
  B := C;
  D := C;
  R := C;
  IF B = C THEN END;
  IF D = C THEN END;
  IF R = C THEN END;
END X;

END reportingoaerrors.