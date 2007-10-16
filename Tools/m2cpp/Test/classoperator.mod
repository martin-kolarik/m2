MODULE classoperator;

CLASS A;
  OPERATOR = ( Operand : CARDINAL ) : BOOLEAN;
END A;

CLASS IMPLEMENTATION A;

  OPERATOR =( Operand : CARDINAL ) : BOOLEAN;
  BEGIN
    RETURN FALSE;
  END =;
   
END A;

TYPE
  TR = RECORD
         VA : A;
       END;

CLASS C;
  OPERATOR = ( Operand : TR ) : BOOLEAN;
END C;

CLASS IMPLEMENTATION C;

  OPERATOR =( Operand : TR ) : BOOLEAN;
  BEGIN
    RETURN FALSE;
  END =;
   
END C;

VAR
  VA : A;
  VC : C;
  R : TR;

BEGIN
  IF (VA = 3+(4+4)+4) OR (VC = R) THEN END;
END classoperator.