MODULE selfsuperetc;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

INTERFACE I;
   PROCEDURE Q() : BOOLEAN;
END I;

INTERFACE J( I );
   PROCEDURE Q() : BOOLEAN;
END J;

CLASS A;
   PROCEDURE P() : BOOLEAN;
END A;

CLASS B( A );
   PROCEDURE P() : BOOLEAN;
END B;

CLASS C IMPLEMENTS I;
   PUBLIC VIRTUAL PROCEDURE Q() : BOOLEAN;
   PROCEDURE P() : BOOLEAN;
END C;

CLASS D( C ) IMPLEMENTS J;
   PUBLIC VIRTUAL PROCEDURE Q() : BOOLEAN;
   PROCEDURE P() : BOOLEAN;
END D;

CLASS IMPLEMENTATION A;

   PROCEDURE P() : BOOLEAN;
   BEGIN
      SELF.P();
      // SUPER.P(); -- no ancestor
      A.P();
      
      IF ADR( SELF )^.P() THEN END;
      // IF ADR( SUPER )^.P() THEN END;
      IF ADR( A )^.P() THEN END;

      RETURN FALSE;
   END P;

END A;

CLASS IMPLEMENTATION B;

   PROCEDURE P() : BOOLEAN;
   BEGIN
      SELF.P();
      SUPER.P();
      A.P();
      B.P();

      IF ADR( SELF )^.P() THEN END;
      IF ADR( SUPER )^.P() THEN END;
      IF ADR( A )^.P() THEN END;
      IF ADR( B )^.P() THEN END;

      RETURN FALSE;
   END P;

END B;

CLASS IMPLEMENTATION C;

   PUBLIC VIRTUAL PROCEDURE Q() : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END Q;

   PROCEDURE P() : BOOLEAN;
   BEGIN
      SELF.P();
      // SUPER.P(); -- no ancestor
      C.P();
      I.Q();

      IF ADR( SELF )^.P() THEN END;
      // IF ADR( SUPER )^.P() THEN END;
      IF ADR( C )^.P() THEN END;
      IF ADR( I )^.Q() THEN END;

      RETURN FALSE;
   END P;

END C;

CLASS IMPLEMENTATION D;

   PUBLIC VIRTUAL PROCEDURE Q() : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END Q;

   PROCEDURE P() : BOOLEAN;
   BEGIN
      SELF.P();
      SUPER.P();
      C.P();
      D.P();
      C.I.Q();
      J.Q();
      J.I.Q();
      SELF.C.I.Q();

      IF ADR( SELF )^.P() THEN END;
      IF ADR( SUPER )^.P() THEN END;
      IF ADR( C )^.P() THEN END;
      IF ADR( D )^.P() THEN END;
      IF ADR( C.I )^.Q() THEN END;
      IF ADR( J )^.Q() THEN END;
      IF ADR( J.I )^.Q() THEN END;

      RETURN FALSE;
   END P;

END D;

END selfsuperetc.