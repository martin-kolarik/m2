MODULE castonref;

CLASS C;
END C;

CLASS IMPLEMENTATION C;
END C;

TYPE
  TPC = POINTER TO C;

PROCEDURE P( OUT PC : TPC );
BEGIN
  PC := NIL;
END P;

PROCEDURE Test();
VAR
  A : ADDRESS := NIL;
  PC : TPC := NIL;
  V : PTR;
BEGIN
  V := PC;
  PC := V;
  PC := A;
  P( OUT V );
  P( OUT TPC( V ));
END Test;

END castonref.