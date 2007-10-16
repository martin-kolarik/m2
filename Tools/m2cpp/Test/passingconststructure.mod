MODULE passingconststructure;

  TYPE
    TR = RECORD
           A : CARDINAL;
           P : POINTER TO CARDINAL;
         END;
    TPCC = POINTER TO CONST CARDINAL;
    
  CLASS TC;
    A : CARDINAL;
    P : POINTER TO CARDINAL;
  END TC;
  
  CLASS IMPLEMENTATION TC;
  END TC;
  
  TYPE
    TPC = POINTER TO TC;

  PROCEDURE Test( R : TR; CONST RR : TR; D : CARDINAL; CONST CC : CARDINAL; CONST C : TC; CONST PC : TPC );
  BEGIN
    D := RR.A;
    D := RR.P^;
    D := C.A;
    D := C.P^;
    D := PC^.A;
    D := PC^.P^;
  END Test;

  VAR
    C : TC;
    D : CARDINAL;
    PCC : TPCC;
    R : TR;

BEGIN
  Test( R, R, 5, 6, C, ADR( C ));
  Test( R, R, 5, D, C, ADR( C ));
  Test( R, R, 5, PCC^, C, ADR( C ));
END passingconststructure.