MODULE moduleinitfinal;

CLASS C;
  INITIALLY C();
  FINALLY C();
END C;

CLASS IMPLEMENTATION C;

  INITIALLY C();
  BEGIN
  END C;

  FINALLY C();
  VAR
    CA : BOOLEAN;
  BEGIN
    IF CA THEN
    END;
  END C;

END C;

FINALLY Finit();
VAR
  A : REAL;
BEGIN
  IF A = 0.0  THEN
  END;
END Finit;

BEGIN
  Finit();
  IF FALSE THEN
  END;
END moduleinitfinal.