MODULE entrypoint;

PROCEDURE A() : CARDINAL;
BEGIN
  RETURN 0;
END A;

#save, call( entry_point => on )
PROCEDURE B() : CARDINAL;
BEGIN
  RETURN 0;
END B;
#restore

#save, call( entry_point => on )
INITIALLY C();
BEGIN
// return should not be here, but the error should be reported in definitin RETURN 0;
END C;
#restore

FINALLY D();
BEGIN
END D;

END entrypoint.