MODULE classcasting;

CLASS C1;
END C1;

CLASS IMPLEMENTATION C1;
BEGIN
END C1;

CLASS C2( C1 );
END C2;

CLASS IMPLEMENTATION C2;
BEGIN
END C2;

TYPE
  TP1 = POINTER TO C1;
  TP2 = POINTER TO C2;
  
  PROCEDURE X1( P1 : TP1 ); BEGIN END X1;
  PROCEDURE X2( VAR P1 : TP1 ); BEGIN END X2;
  PROCEDURE X3( P2 : TP2 ); BEGIN END X3;
  PROCEDURE X4( VAR PP : TP2 ); BEGIN END X4;
  
VAR
  V1 : TP1;
  V2 : TP2; 
  
BEGIN
  X1( V1 );
  X2( V1 );
  // X3( V1 );
  // X4( V1 );
  X1( V2 );
  X2( V2 );
  X3( V2 );
  X4( V2 );
  
  V1 := V1;
  V1 := V2;
  // V2 := V1;
  V2 := V2;
END classcasting.