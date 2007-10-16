MODULE classindexer;

CLASS C;
  INDEX( Index : INTEGER ) : CARDINAL;
END C;

CLASS IMPLEMENTATION C;

  INDEX C GET( Index : INTEGER ) : CARDINAL;
  BEGIN
    RETURN 0;
  END C;

  INDEX C SET( Index : INTEGER; V : CARDINAL );
  BEGIN
  END C;

END C;

PROCEDURE P( D : CARDINAL );
BEGIN
END P;

VAR
  V : C;

PROCEDURE X();
BEGIN
  IF V[0] = 1 THEN END;
  V[-1] := 0;
  V[-1] := V[-2];
END X;
  
END classindexer.