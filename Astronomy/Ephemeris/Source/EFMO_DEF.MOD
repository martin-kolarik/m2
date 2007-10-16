IMPLEMENTATION MODULE efMo_def;

IMPORT
  math;

(*---------------------------------------------------------------------------*)

CONST
  sin   ::= math.sin;
  cos   ::= math.cos;
  tan   ::= math.tan;
  asin  ::= math.asin;
  acos  ::= math.acos;
  atan  ::= math.atan;
  sqrt  ::= math.sqrt;

(*---------------------------------------------------------------------------*)

  pi               = 3.141592653589793240;
  arcSecToRad      = pi / 648000.0;

  jd2000           = 2451545.0;   (* 12h UT *)
  julianCentury    = 36525.0;

(*===========================================================================*)

  PROCEDURE CountCorrections(     l, ll, f, d : LONGREAL;
                              VAR al, ab, ar  : LONGREAL );
  VAR
    i : CARDINAL;
    a : LONGREAL;
  BEGIN
    al := 0.0;
    ab := 0.0;
    ar := 0.0;

    FOR i := 0 TO 36 DO // WITH errorsPolynom[ i ] DO
      a := LONGREAL( errorsPolynom[ i ].k[ 0 ] ) * l  +
           LONGREAL( errorsPolynom[ i ].k[ 1 ] ) * ll +
           LONGREAL( errorsPolynom[ i ].k[ 2 ] ) * f  +
           LONGREAL( errorsPolynom[ i ].k[ 3 ] ) * d;

      al := al + LONGREAL( errorsPolynom[ i ].eal ) * sin( a     );

      ab := ab + LONGREAL( errorsPolynom[ i ].abm ) * sin( a - f );
      ab := ab + LONGREAL( errorsPolynom[ i ].abp ) * sin( a + f );

      ar := ar + LONGREAL( errorsPolynom[ i ].ear ) * cos( a     );
    END; // END;

    al := arcSecToRad * al;
    ab := arcSecToRad * ab;
  END CountCorrections;

(*---------------------------------------------------------------------------*)

  PROCEDURE GetOrbitalElements( jd : LONGREAL; VAR a, L, o : LONGREAL );
  VAR
    dT : LONGREAL;
  BEGIN
    dT  := ( jd - jd2000 ) / julianCentury;
    L := arcSecToRad * ( 785939.956 + dT * ( 1732564372.833 - 4.776  * dT ));
    o := arcSecToRad * ( 300071.675 + dT * (   14648449.360 - 37.166 * dT ));
    a := 384747.981;
  END GetOrbitalElements;

(*---------------------------------------------------------------------------*)

END efMo_def.
