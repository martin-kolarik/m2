MODULE operatoris;

CLASS A;
   VIRTUAL PROCEDURE P();
   PUBLIC OPERATOR NEW( size : CARDINAL ) : ADDRESS;
   PUBLIC OPERATOR DISPOSE( a : ADDRESS );
END A;

CLASS IMPLEMENTATION A;
   VIRTUAL PROCEDURE P();
   BEGIN
   END P;
   PUBLIC OPERATOR NEW( size : CARDINAL ) : ADDRESS;
   BEGIN
      RETURN NIL;
   END NEW;
   PUBLIC OPERATOR DISPOSE( a : ADDRESS );
   BEGIN
   END DISPOSE;
END A;

CLASS B;
   PUBLIC OPERATOR NEW( size : CARDINAL ) : ADDRESS;
   PUBLIC OPERATOR DISPOSE( a : ADDRESS );
END B;
CLASS IMPLEMENTATION B;
   PUBLIC OPERATOR NEW( size : CARDINAL ) : ADDRESS;
   BEGIN
      RETURN NIL;
   END NEW;
   PUBLIC OPERATOR DISPOSE( a : ADDRESS );
   BEGIN
   END DISPOSE;
END B;

CLASS C( A ); END C;
CLASS IMPLEMENTATION C; END C;

CLASS D( A ); END D;
CLASS IMPLEMENTATION D; END D;

PROCEDURE X( V : POINTER TO A );
VAR
   b : BOOLEAN;
BEGIN
   b := V^ IS A;
   b := V^ IS D;
END X;

PROCEDURE wmain() : INTEGER;
VAR
   VA : A;
   VB : B;
   VC : C;
   VD : D;
   b : BOOLEAN;
BEGIN
   b := VA IS C'A'; // true

   b := VA IS A; // true
   b := VA IS B; // false
   b := VA IS C; // false
   b := VA IS D; // false

   //b := VB IS A; // false
   //b := VB IS B; // true
   //b := VB IS C; // false
   //b := VB IS D; // false

   b := VC IS A; // false
   b := VC IS B; // false
   b := VC IS C; // true
   b := VC IS D; // false

   b := VD IS A; // false
   b := VD IS B; // false
   b := VD IS C; // false
   b := VD IS D; // true
   
   b := VA INHERITS C'A';

   b := VA INHERITS A;
   b := VA INHERITS B;
   b := VA INHERITS C;
   b := VA INHERITS D;

   b := VB INHERITS A;
   b := VB INHERITS B;
   b := VB INHERITS C;
   b := VB INHERITS D;

   b := VC INHERITS A;
   b := VC INHERITS B;
   b := VC INHERITS C;
   b := VC INHERITS D;

   b := VD INHERITS A;
   b := VD INHERITS B;
   b := VD INHERITS C;
   b := VD INHERITS D;
   
   X( ADR( VD ));

   RETURN 0;
END wmain;

END operatoris.