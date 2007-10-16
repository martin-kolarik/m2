IMPLEMENTATION MODULE efPl_def;

IMPORT
	math;

CONST
  pi = 3.14159265358979324;

(*---------------------------------------------------------------------------*)

PROCEDURE GetPlutoElements( jd : LONGREAL; VAR l, b, r : LONGREAL );
VAR
  dT : LONGREAL;
  i  : CARDINAL;
BEGIN
  dT := ( jd - 2451545.0 ) / 365.25;

  l :=  + 860205.103    + 5275.67422     * dT;
  b :=  -  14129.118    -    1.23903     * dT;
  r :=  +     40.668607 -    0.000431433 * dT;

  FOR i := 1 TO 24 DO
    l := l + efemPluto[ i, 1 ] * math.sin( 0.025333 * LONGREAL( i ) * dT + efemPluto[ i, 2 ] );
    b := b + efemPluto[ i, 3 ] * math.sin( 0.025333 * LONGREAL( i ) * dT + efemPluto[ i, 4 ] );
    r := r + efemPluto[ i, 5 ] * math.sin( 0.025333 * LONGREAL( i ) * dT + efemPluto[ i, 6 ] );
  END;

  l := l / 3600.0 * pi / 180.0; (* from arcSec to radians *)
  b := b / 3600.0 * pi / 180.0;
END GetPlutoElements;

(*---------------------------------------------------------------------------*)

BEGIN
END efPl_def.
