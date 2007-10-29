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
   READONLY INDEX( i : INTEGER ) : BOOLEAN;
END C;

CLASS D( C ) IMPLEMENTS J;
   VAR
      V : BOOLEAN;
      W : C;
   PUBLIC VIRTUAL PROCEDURE Q() : BOOLEAN;
   PROCEDURE AP( _D : ARRAY OF D );
   PROCEDURE P( _D : D ): BOOLEAN;
END D;

CLASS IMPLEMENTATION A;

   PROCEDURE P() : BOOLEAN;
   BEGIN
      SELF.P();
      // SUPER.P(); -- no ancestor
      A.P();
      
      IF ADR( SELF )^.P() THEN END;
      // IF ADR( SUPER )^.P() THEN END;
      // IF ADR( A )^.P() THEN END;

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
      // IF ADR( SUPER )^.P() THEN END;
      // IF ADR( A )^.P() THEN END;
      // IF ADR( B )^.P() THEN END;

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
      // IF ADR( C )^.P() THEN END;
      // IF ADR( I )^.Q() THEN END;

      RETURN FALSE;
   END P;

   INDEX C GET( i : INTEGER ) : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END C;

END C;

CLASS IMPLEMENTATION D;

   PUBLIC VIRTUAL PROCEDURE Q() : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END Q;

   PROCEDURE AP( _D : ARRAY OF D );
   BEGIN
      IF _D[0].V THEN END;
   END AP;

   PROCEDURE P( _D : D ) : BOOLEAN;
   TYPE
      TPC = POINTER TO C;
      TPD = POINTER TO D;
   VAR
      PI : POINTER TO I;
      PC : POINTER TO C;
      PD : POINTER TO D := NIL;
      VC : C;
      VD : D;
   BEGIN
      SELF.V := TRUE;
   
      SELF.P( VD );
      SUPER.P();
      C.P();
      D.P( VD );
      _D.P( VD );
      VD.W.P();
      // I.Q();
      C.I.Q();
      J.Q();
      J.I.Q();
      SELF.C.I.Q();
      
      PC := ADR( NEW( D )^.D );
      PI := ADR( NEW( D )^.C.I );

      // IF ADR( SELF )^.I.Q() THEN END;
      
      IF SELF[1] THEN END;
      IF SUPER[1] THEN END;
      IF C[1] THEN END;
      IF ADR( SELF )^[1] THEN END;
      IF PD^.C[1] THEN END;

      IF VD[1] THEN END;
      VD.V := TRUE;
      IF VD.V THEN END;

      IF _D[1] THEN END;
      
      VC := D.W;
      VC := VD.W;
      PC := ADR( TPD( 0 )^.W );
      PI := ADR( TPD( 0 )^.J.I );

      IF ADR( SELF )^.P( VD ) THEN END;
      IF ADR( SUPER )^.P() THEN END;
      IF ADR( C )^.P() THEN END;
      IF ADR( D )^.P( VD ) THEN END;
      IF ADR( C.I )^.Q() THEN END;
      IF ADR( J )^.Q() THEN END;
      IF ADR( J.I )^.Q() THEN END;
      
      IF ADR( SELF )^.C.I.Q() THEN END;
      PD^.C.I.Q();

      RETURN FALSE;
   END P;

END D;

END selfsuperetc.