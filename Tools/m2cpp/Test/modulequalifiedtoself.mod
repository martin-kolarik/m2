IMPLEMENTATION MODULE modulequalifiedtoself;

TYPE
  TPC = POINTER TO C;

CLASS IMPLEMENTATION C;

  VIRTUAL PROCEDURE M();
  VAR
    PC : modulequalifiedtoself.TPC;
  BEGIN  
  END M;

END C;

BEGIN
END modulequalifiedtoself.