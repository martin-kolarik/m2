MODULE classesvsrecords;

CLASS C1;
  PUBLIC VIRTUAL PROCEDURE M1();
END C1;

CLASS IMPLEMENTATION C1;
  PUBLIC VIRTUAL PROCEDURE C1.M1();
  BEGIN
  END C1.M1;
END C1;

TYPE
  R1 = RECORD
         R1C1 : C1;
       END;
  R2 = RECORD
         CASE : BOOLEAN OF
         | TRUE:
         | FALSE : R1C1 : C1;
         END;
       END;

CLASS C2;
  C2R1 : R1;
  C2R2 : R2;
END C2;

CLASS IMPLEMENTATION C2;
END C2;

CLASS C3;
  C3R3 : RECORD
           R1C1 : C1;
         END;
END C3;

CLASS IMPLEMENTATION C3;
END C3;

PROCEDURE main();
VAR
  V2 : C2;
BEGIN
  V2.C2R1.R1C1.M1();
  V2.C2R2.R1C1.M1();
END main;

END classesvsrecords.