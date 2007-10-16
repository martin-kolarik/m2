MODULE classproperty;

CLASS A;
  V1 : CARDINAL;
  VAR
    V2 : CARDINAL;
  PROPERTY
    A : CARDINAL;
END A;

CLASS IMPLEMENTATION A;

  PROPERTY A GET : CARDINAL;
  BEGIN
    RETURN 0;
  END A;

  PROPERTY A SET( Value : CARDINAL );
  BEGIN
  END A;

END A;

TYPE
  TR = RECORD
         RA : A;
       END;

CLASS C;
  PROPERTY
    A : CARDINAL;
    R : TR;
END C;

CLASS IMPLEMENTATION C;

  PROPERTY A GET : CARDINAL;
  BEGIN
    RETURN 0;
  END A;

  PROPERTY A SET( Value : CARDINAL );
  BEGIN
  END A;

  PROPERTY R GET : TR;
  VAR
    LR : TR;
  BEGIN
    LR := LR;
    RETURN LR;
  END R;

  PROPERTY R SET( Value : TR );
  BEGIN
  END R;

END C;

PROCEDURE P( D : CARDINAL );
BEGIN
END P;

VAR
  V : C;

PROCEDURE X();
BEGIN
  IF V.A = 0 THEN END;
  V.A := 14;
  P( V.A );

  IF V.R.RA.A = 0 THEN END;
  V.R.RA.A := 14;
  P( V.R.RA.A );
END X;
  
END classproperty.