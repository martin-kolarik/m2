MODULE castofparameters;

  CLASS CREAL;
  END CREAL;
  
  CLASS IMPLEMENTATION CREAL;
  BEGIN
  END CREAL;  

  TYPE
    T = CREAL;
    TPT = POINTER TO T;

  PROCEDURE Test( I : CARDINAL; VAR T : TPT );
  BEGIN
    Test( 0, T );
  END Test;

BEGIN
END castofparameters.