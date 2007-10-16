MODULE newfollowedbycall;

FROM Storage IMPORT ALLOCATE;

INITIALLY __I();
BEGIN
END __I;

CLASS C;
  PUBLIC PROCEDURE Init() : CARDINAL;
END C;

CLASS IMPLEMENTATION C;
  PUBLIC PROCEDURE Init() : CARDINAL;
  BEGIN
    RETURN 0;
  END Init;
END C;

PROCEDURE X();
VAR
  CC : CARDINAL;
  PC : POINTER TO C;
BEGIN
  __I();
  NEW( PC )^.Init();
  NEW( C )^.Init();
  CC := NEW( C )^.Init();
END X;

END newfollowedbycall.