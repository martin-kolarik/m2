MODULE emit;

PROCEDURE n( d : CARDINAL );
BEGIN
END n;

PROCEDURE s( d : ARRAY OF CHAR );
BEGIN
END s;

CLASS C;
  PROCEDURE M;
END C;

CLASS IMPLEMENTATION C;

  PROCEDURE C.M;
  
    PROCEDURE LP;
    BEGIN
      s( EMIT( entry ) + "A" );
      s( EMIT( sprocedure ));
      s( EMIT( lprocedure ));
      s( EMIT( smodule ));
      s( EMIT( lmodule ));
      s( EMIT( class ));
      n( EMIT( line ));
      s( EMIT( exit ));
    END LP;

  BEGIN
    s( EMIT( entry ));
    s( EMIT( sprocedure ));
    s( EMIT( lprocedure ));
    s( EMIT( smodule ));
    s( EMIT( lmodule ));
    s( EMIT( class ));
    n( EMIT( line ));
    s( EMIT( exit ));
  END C.M;

BEGIN
END C;

FINALLY
VAR
  A : REAL;
BEGIN
  s( EMIT( entry ));
  s( EMIT( lprocedure ));
  s( EMIT( smodule ));
  s( EMIT( lmodule ));
  s( EMIT( class ));
  n( EMIT( line ));
  IF A = 0.0  THEN
  END;
  s( EMIT( exit ));
END FINALLY;

BEGIN
  s( EMIT( entry ));
  s( EMIT( lprocedure ));
  n( EMIT( line ));
  s( EMIT( exit ));
END emit.