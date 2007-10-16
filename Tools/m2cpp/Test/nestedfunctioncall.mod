MODULE nestedfunctioncall;

VAR
  d : INTEGER;
  
PROCEDURE F( I1, I2 : INTEGER ) : INTEGER;
BEGIN
  RETURN 0;
END F;

BEGIN
  d := 0 + F( F( 0 + 0, 0 + 0 ), 0 + 0 ) + (*2*) 0 + 2 * 0;
END nestedfunctioncall.