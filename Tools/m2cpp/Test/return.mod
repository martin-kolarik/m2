MODULE return;

  PROCEDURE Return() : BOOLEAN;
  BEGIN
    IF FALSE THEN
    ELSIF TRUE THEN
    END;

    IF FALSE THEN
      RETURN TRUE;
    ELSIF FALSE THEN
      IF FALSE THEN
        RETURN FALSE;
      ELSIF FALSE THEN
        RETURN FALSE;
      ELSE
        RETURN FALSE;
      END;
    ELSE
      IF FALSE THEN
        RETURN FALSE;
      ELSE
        RETURN FALSE;
      END;
    END;
  END Return;

  PROCEDURE Return2() : BOOLEAN;
  VAR
    A, B : CARDINAL;
  BEGIN
    B := 1;
    LOOP
      IF FALSE THEN
        RETURN TRUE;
      ELSIF TRUE THEN
        RETURN TRUE;
      ELSE
        EXIT;
      END;
      A := B;
    END;
    RETURN TRUE;
  END Return2;

  PROCEDURE Return3() : BOOLEAN;
  BEGIN
    REPEAT
      RETURN TRUE;
    UNTIL FALSE;
    RETURN TRUE;
  END Return3;

  PROCEDURE Return4() : BOOLEAN;
  BEGIN
    IF FALSE THEN
      RETURN FALSE;
    ELSIF FALSE THEN
      RETURN FALSE;
    ELSE
      RETURN TRUE;
    END;
  END Return4;

  PROCEDURE Return5() : BOOLEAN;
  BEGIN
    IF FALSE THEN
      RETURN FALSE;
    ELSE
      IF FALSE THEN
        RETURN TRUE;
      ELSE
        RETURN TRUE;
      END;
    END;
  END Return5;

  PROCEDURE Return6() : BOOLEAN;
  BEGIN
    LOOP
      IF FALSE THEN
        EXIT;
      END;
    END;
    RETURN FALSE;
  END Return6;

  PROCEDURE Return7() : BOOLEAN;
  VAR
    A : CARDINAL;
  BEGIN
    LOOP
      IF FALSE THEN
        EXIT;
      ELSE
      END;
    END;
    RETURN FALSE;
  END Return7;

  PROCEDURE Return8() : BOOLEAN;
  VAR
    A : CARDINAL;
  BEGIN
    CASE A OF
    | 0, // procedures are not passed as parameters
      1 : // nor frames nor class are passed as parameters, the are not added into frame too
      RETURN FALSE;
    ELSE
      RETURN TRUE;
    END;
  END Return8;
  
  PROCEDURE Return9() : BOOLEAN;
  BEGIN
    LOOP
      IF FALSE THEN
        IF FALSE THEN
          RETURN FALSE;
        END;
      ELSE
        EXIT;
      END;
    END;
    RETURN FALSE;
  END Return9;

  PROCEDURE Return10() : BOOLEAN;
  VAR
    A : CARDINAL;
  BEGIN
    LOOP
      IF FALSE THEN
        RETURN FALSE;
      ELSE
        CASE A OF
        | 0, 1 :
          RETURN FALSE;
        | 2 :
          IF FALSE THEN
            EXIT;
          ELSE
            IF FALSE THEN
              EXIT;
            END;
          END;
        ELSE
          IF FALSE THEN
            EXIT;
          ELSE
            IF FALSE THEN
              EXIT;
            END;
          END;
        END;
      END;
    END;
    RETURN FALSE;
  END Return10;

  PROCEDURE Return11() : BOOLEAN;
  VAR
    A : CARDINAL;
  BEGIN
    LOOP
      CASE A OF
      | 0, 1 :
        IF FALSE THEN
          RETURN FALSE;
        END;
      | 2 :
        IF FALSE THEN
          EXIT;
        ELSE
          IF FALSE THEN
            EXIT;
          END;
        END;
      END;
    END;
    RETURN FALSE;
  END Return11;

BEGIN
END return.