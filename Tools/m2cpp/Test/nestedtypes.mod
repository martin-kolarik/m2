MODULE nestedtypes;

PROCEDURE P1();

  TYPE
    TW = RECORD
           Y : INTEGER;
         END;
    TY = POINTER TO TW;
    TX = RECORD
           I : INTEGER;
           W : TW;
         END;
    TZ = ARRAY [0..1] OF TW;
  CONST
    C = TX( 14, TW( 13 ));
  TYPE
    T1 = ( A, B );

  PROCEDURE P2( P : T1 );
  VAR
    // Y : TY;
    // Z : TZ;
  BEGIN
    P := A;
    IF C.I = 13 THEN
    END;
  END P2;

BEGIN
END P1;

END nestedtypes.