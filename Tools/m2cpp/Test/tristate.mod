MODULE tristate;

  INITIALLY X;
  VAR
    A, B : TRISTATE;
    
  BEGIN
    A := B;
    CASE A OF
    | -1 :
    | 0 :
    | 1 :
    END; // CASE
  END X;

END tristate.