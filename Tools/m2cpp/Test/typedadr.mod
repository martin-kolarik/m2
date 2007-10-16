MODULE typedadr;

TYPE
  TA = ARRAY [0..7] OF BYTE;
  TPA = POINTER TO TA;
  TB = ARRAY [0..7] OF BYTE;
CONST
  C = TA( 0, 1, 2, 3, 4, 5, 6, 7 );
VAR
  B : TB;
  A : ADDRESS;
  
PROCEDURE PT( A : ADDRESS; PA : TPA );
BEGIN
END PT;

BEGIN
  A := ADR( C );
  (*# save, option( typed_adr => off ) *)
  A := ADR( C );
  (*# restore *)

  // PT( ADR( B ), ADR( B )); error
  PT( NIL, NIL ); 

  (*# save, option( typed_adr => off ) *)
  PT( ADR( B ), ADR( B )); 
  PT( NIL, NIL ); 
  (*# restore *)
END typedadr.
