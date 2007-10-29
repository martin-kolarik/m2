MODULE gettingpropertyfromconstparameter;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

CLASS A;
   VAR
      B : BOOLEAN := FALSE;
   PUBLIC READONLY PROPERTY P : BOOLEAN;
END A;

CLASS IMPLEMENTATION A;

   PUBLIC PROPERTY P GET : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END P;

BEGIN
END A;

PROCEDURE P( CONST a : ARRAY OF A );
BEGIN
   IF a[0].P THEN END;
END P;

END gettingpropertyfromconstparameter.
