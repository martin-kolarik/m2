MODULE bitwiseonstorage;

CONST
  c = LONGINT( 1 );
  
VAR
  lw : LONGCARD;

BEGIN
  IF c = LONGINT( lw ) THEN END;
  IF c AND lw = 0 THEN END;
END bitwiseonstorage.