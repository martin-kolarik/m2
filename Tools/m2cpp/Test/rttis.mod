MODULE rttis;

CLASS A;
   PRIVATE VAR
      V : INTEGER;
   PUBLIC OPERATOR NEW( s : CARDINAL ) : ADDRESS;
   PUBLIC OPERATOR DISPOSE( a : ADDRESS );
END A;

CLASS IMPLEMENTATION A;

   PUBLIC OPERATOR NEW( s : CARDINAL ) : ADDRESS;
   BEGIN
      RETURN NIL;
   END NEW;

   PUBLIC OPERATOR DISPOSE( a : ADDRESS );
   BEGIN
   END DISPOSE;

BEGIN
   V := 0;
END A;

PROCEDURE X();
VAR
   a : ADDRESS;
   c : A;
   l : CARDINAL;
BEGIN
   IF c IS A THEN END;
   IF c IS c THEN END;
   a := RTTI( A );
   l := RTTI_SIZE( A );
   a := RTTI( c );
   l := RTTI_SIZE( c );
   // a := RTTI( ADR( c ));
   // l := RTTI_SIZE( ADR( c ));
END X;

END rttis.