IMPLEMENTATION MODULE ef82_def;

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

(*===========================================================================*)

CONST
  jd2000  = 2451545.0;   (* 12h UT *)

CONST
  julianCentury    = 36525.0;

(*---------------------------------------------------------------------------*)

PROCEDURE CountErrors82( dT : LONGREAL; planeta : CARDINAL; VAR da, dL, dk, dh, dp, dq : LONGREAL );
TYPE
  TPIndexArray = POINTER TO ARRAY [1..1] OF TValueArray;
VAR
  dT2      : LONGREAL;
  i, j     : CARDINAL;
  LArray   : ARRAY [1..8] OF LONGREAL;
  nErrElem : CARDINAL;
  nLines   : CARDINAL;
  PIndex   : TPIndexArray;
  sL       : LONGREAL;
BEGIN
  nErrElem := errPolynoms.Info[ planeta ].nElem;
  nLines   := errPolynoms.Info[ planeta ].nErrors;
  dT2      := dT * dT;

  // WITH errPolynoms.Info[ planeta ] DO
    FOR i := 1 TO nErrElem DO
      // WITH solarSystem[ indexes[ i ] ] DO
        LArray[ i ] :=   solarSystem[ errPolynoms.Info[ planeta ].indexes[ i ] ].orbit.L[ 0 ]
                       + solarSystem[ errPolynoms.Info[ planeta ].indexes[ i ] ].orbit.L[ 1 ] * dT
                       + solarSystem[ errPolynoms.Info[ planeta ].indexes[ i ] ].orbit.L[ 2 ] * dT2
                       + solarSystem[ errPolynoms.Info[ planeta ].indexes[ i ] ].orbit.L[ 3 ] * dT2 * dT;
      // END; // WITH
    END;
  // END;

  // WITH errPolynoms DO
    CASE planeta OF
    | 1 :
      PIndex := TPIndexArray( ADR( errPolynoms.jedna ));
    | 2 :
      PIndex := TPIndexArray( ADR( errPolynoms.dva ));
    | 3 :
      PIndex := TPIndexArray( ADR( errPolynoms.tri ));
    | 4 :
      PIndex := TPIndexArray( ADR( errPolynoms.ctyri ));
    | 5 :
      PIndex := TPIndexArray( ADR( errPolynoms.pet ));
    | 6 :
      PIndex := TPIndexArray( ADR( errPolynoms.sest ));
    | 7 :
      PIndex := TPIndexArray( ADR( errPolynoms.sedm ));
    | 8 :
      PIndex := TPIndexArray( ADR( errPolynoms.osm ));
    END;

    da := 0.0; dL := 0.0; dk := 0.0; dh := 0.0; dp := 0.0; dq := 0.0;

    FOR i := 1 TO nLines DO
      sL := 0.0;
      FOR j := 1 TO nErrElem DO
        sL := sL + LArray[ j ] * LONGREAL( PIndex^[ i, j ] );
      END;

      IF planeta < 6 THEN
        da := da + LONGREAL( PIndex^[ i,  9 ] ) * 1.0E-7 * sin( sL )
                 + LONGREAL( PIndex^[ i, 10 ] ) * 1.0E-7 * cos( sL );
        dL := dL + LONGREAL( PIndex^[ i, 11 ] ) * 1.0E-7 * sin( sL )
                 + LONGREAL( PIndex^[ i, 12 ] ) * 1.0E-7 * cos( sL );
        dk := dk + LONGREAL( PIndex^[ i, 13 ] ) * 1.0E-7 * sin( sL )
                 + LONGREAL( PIndex^[ i, 14 ] ) * 1.0E-7 * cos( sL );
        dh := dh + LONGREAL( PIndex^[ i, 15 ] ) * 1.0E-7 * sin( sL )
                 + LONGREAL( PIndex^[ i, 16 ] ) * 1.0E-7 * cos( sL );
      ELSE
        da := da + LONGREAL( PIndex^[ i,  9 ] ) * 1.0E-6 * sin( sL )
                 + LONGREAL( PIndex^[ i, 10 ] ) * 1.0E-6 * cos( sL );
        dL := dL + LONGREAL( PIndex^[ i, 11 ] ) * 1.0E-6 * sin( sL )
                 + LONGREAL( PIndex^[ i, 12 ] ) * 1.0E-6 * cos( sL );
        dk := dk + LONGREAL( PIndex^[ i, 13 ] ) * 1.0E-6 * sin( sL )
                 + LONGREAL( PIndex^[ i, 14 ] ) * 1.0E-6 * cos( sL );
        dh := dh + LONGREAL( PIndex^[ i, 15 ] ) * 1.0E-6 * sin( sL )
                 + LONGREAL( PIndex^[ i, 16 ] ) * 1.0E-6 * cos( sL );
      END;

      CASE planeta OF
      | 4 :
        IF i = 1 THEN
          dL := dL + dT * LONGREAL( 32 ) * 1.0E-7 * sin( sL )
                   + dT * LONGREAL(  1 ) * 1.0E-7 * cos( sL );
        END;
      | 5 :
        IF i = 1 THEN
          da := da + dT * LONGREAL(    98 ) * 1.0E-7 * sin( sL )
                   + dT * LONGREAL(    28 ) * 1.0E-7 * cos( sL );
          dL := dL + dT * LONGREAL(   646 ) * 1.0E-7 * sin( sL )
                   + dT * LONGREAL( -2196 ) * 1.0E-7 * cos( sL );
          dk := dk + dT * LONGREAL(   -31 ) * 1.0E-7 * sin( sL )
                   + dT * LONGREAL(   -98 ) * 1.0E-7 * cos( sL );
          dk := dh + dT * LONGREAL(    97 ) * 1.0E-7 * sin( sL )
                   + dT * LONGREAL(   -31 ) * 1.0E-7 * cos( sL );

          sL := 2.0 * LArray[ 3 ] - 5.0 * LArray[ 4 ];
          dq := dq - 75.0 * 1.0E-7 * sin( sL )
                   + 41.0 * 1.0E-7 * cos( sL );
          dp := dp - 33.0 * 1.0E-7 * sin( sL )
                   - 78.0 * 1.0E-7 * cos( sL );
        ELSIF i = 2 THEN
          da := da + dT * LONGREAL(    22 ) * 1.0E-7 * sin( sL )
                   + dT * LONGREAL(   -18 ) * 1.0E-7 * cos( sL );
          dL := dL + dT * LONGREAL(    38 ) * 1.0E-7 * sin( sL )
                   + dT * LONGREAL(    44 ) * 1.0E-7 * cos( sL );
        END;
      | 6 :
        IF i = 1 THEN
          da := da + dT * LONGREAL(  -111 ) * 1.0E-6 * sin( sL )
                   + dT * LONGREAL(   -32 ) * 1.0E-6 * cos( sL );
          dL := dL + dT * LONGREAL(  -159 ) * 1.0E-6 * sin( sL )
                   + dT * LONGREAL(   540 ) * 1.0E-6 * cos( sL );
          dk := dk + dT * LONGREAL(    12 ) * 1.0E-6 * sin( sL )
                   + dT * LONGREAL(    40 ) * 1.0E-6 * cos( sL );
          dk := dh + dT * LONGREAL(   -40 ) * 1.0E-6 * sin( sL )
                   + dT * LONGREAL(    12 ) * 1.0E-6 * cos( sL );

          sL := 2.0 * LArray[ 3 ] - 5.0 * LArray[ 4 ];
          dq := dq + 182.0 * 1.0E-7 * sin( sL )
                   -  97.0 * 1.0E-7 * cos( sL );
          dp := dp +  87.0 * 1.0E-7 * sin( sL )
                   + 187.0 * 1.0E-7 * cos( sL );
        ELSIF i = 2 THEN
          dL := dL + dT * LONGREAL(    -9 ) * 1.0E-6 * sin( sL )
                   + dT * LONGREAL(   -11 ) * 1.0E-6 * cos( sL );
        END;
      | 7 :
        IF i = 1 THEN
          dL := dL + dT * LONGREAL(     7 ) * 1.0E-6 * sin( sL )
                   + dT * LONGREAL(   -23 ) * 1.0E-6 * cos( sL );

          sL := LArray[ 5 ] - LArray[ 3 ];
          da := da + 488.0 * 1.0E-6 * cos( sL );
          dL := dL +  25.0 * 1.0E-6 * sin( sL );

          sL := sL - LArray[ 3 ];
          dk := dk +   6.0 * 1.0E-6 * cos( sL );
          dh := dh -   6.0 * 1.0E-6 * sin( sL );

          sL := LArray[ 6 ] - LArray[ 3 ];
          da := da + 518.0 * 1.0E-6 * cos( sL );
          dL := dL +  26.0 * 1.0E-6 * sin( sL );

          sL := sL - LArray[ 3 ];
          dk := dk +   7.0 * 1.0E-6 * cos( sL );
          dh := dh -   7.0 * 1.0E-6 * sin( sL );

          dk := dk +  19.0 * 1.0E-6 * cos( LArray[ 5 ] )
                   +  20.0 * 1.0E-6 * cos( LArray[ 6 ] );
          dh := dh +  19.0 * 1.0E-6 * sin( LArray[ 5 ] )
                   +  20.0 * 1.0E-6 * sin( LArray[ 6 ] );
        END;
      | 8 :
        IF i = 1 THEN
          dL := dL + dT * LONGREAL(    -5 ) * 1.0E-6 * sin( sL )
                   + dT * LONGREAL(   +16 ) * 1.0E-6 * cos( sL );

          sL := LArray[ 5 ] - LArray[ 4 ];
          da := da + 955.0 * 1.0E-6 * cos( sL );
          dL := dL +  32.0 * 1.0E-6 * sin( sL );

          sL := sL - LArray[ 4 ];
          dk := dk +   8.0 * 1.0E-6 * cos( sL );
          dh := dh -   8.0 * 1.0E-6 * sin( sL );

          sL := LArray[ 6 ] - LArray[ 4 ];
          da := da +1012.0 * 1.0E-6 * cos( sL );
          dL := dL +  33.0 * 1.0E-6 * sin( sL );

          sL := sL - LArray[ 4 ];
          dk := dk +   8.0 * 1.0E-6 * cos( sL );
          dh := dh -   8.0 * 1.0E-6 * sin( sL );

          dk := dk +  24.0 * 1.0E-6 * cos( LArray[ 5 ] )
                   +  25.0 * 1.0E-6 * cos( LArray[ 6 ] );
          dh := dh +  24.0 * 1.0E-6 * sin( LArray[ 5 ] )
                   +  25.0 * 1.0E-6 * sin( LArray[ 6 ] );
        END;
      END;
    END;
  // END;
END CountErrors82;

(*---------------------------------------------------------------------------*)

PROCEDURE GetVSOP82Elements( jd : LONGREAL; planeta : CARDINAL;
                             VAR a, L, k, h, p, q : LONGREAL );
VAR
  dT, dT2                : LONGREAL;
  da, dL, dk, dh, dp, dq : LONGREAL;
BEGIN
  dT  := ( jd - jd2000 ) / julianCentury;
  dT2 := dT * dT;

  CountErrors82( dT, planeta, da, dL, dk, dh, dp, dq );

  // WITH solarSystem[ planeta ] DO
    a := solarSystem[ planeta ].orbit.a[0] +
			solarSystem[ planeta ].orbit.a[1] * dT +
			solarSystem[ planeta ].orbit.a[2] * dT2 +
			da;
    L := solarSystem[ planeta ].orbit.L[0] +
			solarSystem[ planeta ].orbit.L[1] * dT +
			solarSystem[ planeta ].orbit.L[2] * dT2 +
			dL;
    k := solarSystem[ planeta ].orbit.k[0] +
			solarSystem[ planeta ].orbit.k[1] * dT +
			solarSystem[ planeta ].orbit.k[2] * dT2 +
			dk;
    h := solarSystem[ planeta ].orbit.h[0] +
			solarSystem[ planeta ].orbit.h[1] * dT +
			solarSystem[ planeta ].orbit.h[2] * dT2 +
			dh;
    q := solarSystem[ planeta ].orbit.q[0] +
			solarSystem[ planeta ].orbit.q[1] * dT +
			solarSystem[ planeta ].orbit.q[2] * dT2 +
			dq;
    p := solarSystem[ planeta ].orbit.p[0] +
			solarSystem[ planeta ].orbit.p[1] * dT +
			solarSystem[ planeta ].orbit.p[2] * dT2 +
			dp;
  // END;
END GetVSOP82Elements;

(*===========================================================================*)

BEGIN
END ef82_def.
