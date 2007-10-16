MODULE framesconstandvar;

TYPE
  TR = RECORD
         A : CARDINAL;
       END;

PROCEDURE P0( VAR VC : CARDINAL; VAR VA : ADDRESS; CONST CC : CARDINAL; CONST CA : ADDRESS; VAR VR : TR; CONST CR : TR );

  PROCEDURE P1;
  VAR
    LC : CARDINAL;
    LR : TR;
  BEGIN
    VC := CC;
    VA := CA;
    VR := CR;
    LC := LC;
    LC := VC;
    LC := CC;
    LR := VR;
    LR := CR;
  END P1;

BEGIN
  P1();
END P0;

BEGIN
END framesconstandvar.