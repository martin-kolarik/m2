MODULE checkofclassinitialization;

  CLASS C;
    A : CARDINAL;
    B : BOOLEAN;
    INITIALLY X();
  END C;
  
  CLASS IMPLEMENTATION C;

    INITIALLY C();
    BEGIN
      A := 0;
    END C;

  END C;

BEGIN
END checkofclassinitialization.