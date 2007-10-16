MODULE withtorefclass;

  CLASS CREAL;
    A : REAL;
  END CREAL;
  
  CLASS IMPLEMENTATION CREAL;
  BEGIN
  END CREAL;  

  TYPE
    TPCR = POINTER TO CREAL;

  PROCEDURE Test( PCR : TPCR );
  BEGIN
  (*
     WITH PCR^ DO
        A := A;
     END;
  *)
  END Test;
  
  TYPE
    TR1 = RECORD
            V1 : BOOLEAN;
            V2 : BOOLEAN;
          END;
    TR2 = RECORD
            V3 : TR1;
          END;
    TR3 = RECORD
            V4 : TR2;
            V5 : POINTER TO TR2;
          END;

   CONST
      C1 = TR2( TR1( FALSE, FALSE ));
  
   PROCEDURE TestConst();
   BEGIN
   (*
     WITH C1.V3 DO
     END;
   *)
   END TestConst;

   PROCEDURE TestInitVar();
   VAR
      V : TR2;
      V3 : TR3;
      V3P : POINTER TO TR3;
   BEGIN
   (*
      WITH V DO // test na const TR*
      END;
      IF V.V3.V1 THEN // test na mark V as initialized
      END;
      WITH C1.V3 DO // test if V1 is inaccesible
         // V1 := V2; -- must not pass
      END;
    *)
      WITH V3 DO WITH V4 DO
        IF V3.V1 THEN
        END;
      END; END;
      WITH V3P^ DO WITH V4 DO
        IF V3.V1 THEN
        END;
      END; END;
      WITH V3 DO WITH V5^ DO
        IF V3.V1 THEN
        END;
      END; END;
      WITH V3P^ DO WITH V5^ DO
        IF V3.V1 THEN
        END;
      END; END;
   END TestInitVar;

END withtorefclass.