MODULE loops;

PROCEDURE P();
VAR
  I : INTEGER;
BEGIN
  LOOP
  END;
  
  WHILE TRUE DO
  END;

  REPEAT
  UNTIL TRUE;
  
  FOR I := 0 TO 0 DO
  END;

  LOOP
    CONTINUE;
    EXIT;
  END;
  
  WHILE TRUE DO
    CONTINUE;
    EXIT;
  END;

  REPEAT
    CONTINUE;
    EXIT;
  UNTIL TRUE;
  
  FOR I := 0 TO 0 DO
    CONTINUE;
    EXIT;
  END;

END P;

END loops.