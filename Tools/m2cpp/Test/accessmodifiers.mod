MODULE accessmodifiers;

CLASS C1;
  PRIVATE VAR
    VP : CARDINAL;

  INTERNAL READONLY VAR
    VI : CARDINAL;

  PUBLIC READONLY VAR
    VA : CARDINAL;
    
  PRIVATE PROCEDURE PP();
  
  INTERNAL PROCEDURE PI();
  
  PUBLIC PROCEDURE PA();

  PROCEDURE Test();
END C1;

CLASS C2( C1 );
  PRIVATE VAR
    VP2 : CARDINAL;

  PROCEDURE Test();
END C2;

CLASS C3;
  PRIVATE VAR
    VP3 : CARDINAL;

  PROCEDURE Test();
END C3;

CLASS IMPLEMENTATION C1;

  PRIVATE PROCEDURE PP();
  BEGIN
  END PP;

  INTERNAL PROCEDURE PI();
  BEGIN
  END PI;

  PUBLIC PROCEDURE PA();
  BEGIN
  END PA;

  PROCEDURE Test();
  BEGIN
    IF VP = 0 THEN // OK
      //VP := 0; // OK
    END;

    IF VI = 0 THEN // OK
      //VI := 0; // OK
    END;

    IF VA = 0 THEN // OK
      VA := 0; // OK
    END;
    
    PP();
    PI();
    PA();
  END Test;

BEGIN
  VP := 0;
  VI := 0; // OK
  VA := 0;
END C1;
    
CLASS IMPLEMENTATION C2;

  PROCEDURE Test();
  BEGIN
    // IF VP = 0 THEN // error
    //  VP := 0; // error
    // END;

    IF VI = 0 THEN // OK
      // VI := 0; // error
    END;

    IF VA = 0 THEN // OK
      VA := 0; // OK
    END;

    IF VP2 = 0 THEN // OK
      //VP2 := 0; // OK
    END;
    
    // PP(); // error
    PI();
    PA();
  END Test;

BEGIN
  //VP2 := 0;
END C2;
  
CLASS IMPLEMENTATION C3;

  PROCEDURE Test();
  VAR
    C : C2;
  BEGIN
    // IF C.VP = 0 THEN // error
    //   C.VP := 0; // error
    // END;

    // IF C.VI = 0 THEN // error
    //   C.VI := 0; // error
    // END;

    IF C.VA = 0 THEN // OK
      // C.VA := 0; // error
    END;

    // IF C.VP2 = 0 THEN // error
    //   C.VP2 := 0; // error
    // END;
    
    IF VP3 = 0 THEN // OK
      VP3 := 0; // OK
    END;

    // C.PP(); // error
    // C.PI(); // error
    C.PA();
  END Test;

BEGIN
  VP3 := 0;
END C3;

PROCEDURE P;
VAR
  V1 : C1;
  V2 : C2;
  V3 : C3;
BEGIN
  // IF V1.VP = 0 THEN // error
  //   V1.VP := 0; // error
  // END;

  // IF V1.VI = 0 THEN // error
  //   V1.VI := 0; // error
  // END;

  IF V1.VA = 0 THEN // OK
    // V1.VA := 0; // error
  END;

  // IF V2.VP2 = 0 THEN // error
  //   V2.VP2 := 0; // error
  // END;

  // IF V3.VP3 = 0 THEN // error
  //   V3.VP3 := 0; // error
  // END;
  
  // V2.PP(); // error
  // V2.PI(); // error
  V2.PA();
END P;

END accessmodifiers.