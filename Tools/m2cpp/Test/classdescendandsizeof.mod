MODULE classdescendandsizeof;

CLASS C0;
  PROCEDURE M0();
END C0;

CLASS C1;
  PROCEDURE M1();
  PROCEDURE M2();
END C1;

CLASS C2( C1 );
  PROCEDURE M2();
END C2;

CLASS IMPLEMENTATION C0;

  PROCEDURE C0.M0();
  BEGIN
  END C0.M0;

END C0;

CLASS IMPLEMENTATION C1;

  PROCEDURE C1.M1();
  BEGIN
    // IF SIZE( C0 ) = 0 THEN END;
    // IF SIZE( C1 ) = 0 THEN END;
    // IF SIZE( C2 ) = 0 THEN END;
  END C1.M1;

  PROCEDURE C1.M2();
  BEGIN
  END C1.M2;

BEGIN
END C1;

CLASS IMPLEMENTATION C2;

  PROCEDURE C2.M2();
  BEGIN
    // IF SIZE( C0 ) = 0 THEN END;
    // IF SIZE( C1 ) = 0 THEN END;
    // IF SIZE( C2 ) = 0 THEN END;
    // C0.M0();
    C1.M1();
    C2.M1();
    C2.M2();
  END C2.M2;

BEGIN
  C1.M1();
END C2;

END classdescendandsizeof.