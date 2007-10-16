MODULE operatoris;

CLASS A;
   VIRTUAL PROCEDURE P();
END A;
CLASS IMPLEMENTATION A;
   VIRTUAL PROCEDURE P();
   BEGIN
   END P;
END A;

CLASS B; END B;
CLASS IMPLEMENTATION B; END B;

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

#save, call( entry_point => on )
PROCEDURE wmain() : INTEGER;
#restore
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
   
   X( ADR( VD ));

   RETURN 0;
END wmain;

END operatoris.