MODULE allocateinttocard;

  PROCEDURE XALLOCATE( VAR a : ADDRESS; l : CARDINAL );
  BEGIN
  END XALLOCATE;

  PROCEDURE Test;
  VAR
    c : CARDINAL;
    r : INTEGER;
    sa : ADDRESS;
  BEGIN
    r := 1;
    c := r;
    XALLOCATE( sa, r );
  END Test;

BEGIN
END allocateinttocard.