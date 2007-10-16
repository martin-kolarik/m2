IMPLEMENTATION MODULE astro;

IMPORT
  Storage;

IMPORT
  astro_p;

(*===========================================================================*)

PROCEDURE sqrt3( r : LONGREAL ) : LONGREAL;
BEGIN
  IF r < 0.0 THEN
    RETURN - exp( ln( - r ) / 3.0 );
  ELSE
    RETURN   exp( ln(   r ) / 3.0 );
  END;
END sqrt3;

(*---------------------------------------------------------------------------*)

PROCEDURE frac( r : LONGREAL ) : LONGREAL;
BEGIN
  r := r - LONGREAL( LONGINT( r ));
  RETURN r;
END frac;

(*---------------------------------------------------------------------------*)

PROCEDURE rmod( r, d : LONGREAL ) : LONGINT;
VAR
  li : LONGINT;
BEGIN
  li := LONGINT( d * frac( r / d ) + 0.00000000001 );
  RETURN li;
END rmod;

(*---------------------------------------------------------------------------*)

PROCEDURE normalizeAngle( VAR a : LONGREAL );
VAR
  k : LONGREAL;
BEGIN
  k := LONGREAL( TRUNC( a / pi2 ));
  IF k < 0.0 THEN
    k := k - 1.0;
  ELSIF k > 0.0 THEN
    k := k + 1.0;
  END;
  a := a - k * pi2;
  IF a < 0.0 THEN
    a := pi2 + a;
  END;
END normalizeAngle;

(*---------------------------------------------------------------------------*)

PROCEDURE eval( x : LONGREAL; CONST Polynom : TPolynom ) : LONGREAL;
VAR
  i : CARDINAL;
  y : LONGREAL;
BEGIN
  WITH Polynom DO
    y := a[order];
    FOR i := CARDINAL( order ) - 1 TO 0 BY - 1 DO
      y := x * y + a[i];
    END;
  END;

  RETURN y;
END eval;

(*---------------------------------------------------------------------------*)

PROCEDURE RadToDE( angle : LONGREAL; VAR    degrees, minutes : INTEGER;
                                     VAR arcsec, minutesfrac : LONGREAL );
BEGIN
  normalizeAngle( angle );
  IF angle > pi THEN
    angle := angle - pi2;
  END;

  angle := angle * radToDeg;

  degrees     := INTEGER( angle );
  minutesfrac := ( angle - LONGREAL( degrees )) * 60.0;
  IF minutesfrac < 0.0 THEN
    minutesfrac := -minutesfrac;
  END;
  minutes     := INTEGER( minutesfrac );
  arcsec      := ( minutesfrac - LONGREAL( minutes )) * 60.0;
END RadToDE;

(*---------------------------------------------------------------------------*)

PROCEDURE RadToRA( angle : LONGREAL; VAR      hours, minutes : INTEGER;
                                     VAR arcsec, minutesfrac : LONGREAL );
BEGIN
  normalizeAngle( angle );

  angle := angle * radToH;

  hours       := INTEGER( angle );
  minutesfrac := ( angle - LONGREAL( hours )) * 60.0;
  minutes     := INTEGER( minutesfrac );
  arcsec      := ( minutesfrac - LONGREAL( minutes )) * 60.0;
END RadToRA;

(*---------------------------------------------------------------------------*)

PROCEDURE JDToH( jd : LONGREAL; VAR      hours, minutes : INTEGER;
                                VAR arcsec, minutesfrac : LONGREAL );
BEGIN
  jd := frac( jd );
  IF jd > 0.5 THEN
    jd := jd - 0.5;
  ELSE
    jd := jd + 0.5;
  END;

  jd := jd * 24.0;

  hours       := INTEGER( jd );
  minutesfrac := ( jd - LONGREAL( hours )) * 60.0;
  minutes     := INTEGER( minutesfrac );
  arcsec      := ( minutesfrac - LONGREAL( minutes )) * 60.0;
END JDToH;

(*===========================================================================*)

PROCEDURE Kepler( M, e : LONGREAL ) : LONGREAL;
CONST
  epsilon = 1.0E-12;
VAR
  E     : LONGREAL;
  lE    : LONGREAL;

(*----------*)

  PROCEDURE eKepler() : LONGREAL;
  BEGIN
    lE := 0.0;
    E  := M + e * sin( M );
    WHILE ABS( E - lE ) > epsilon DO
      lE := E;
      E  := M + e * sin( lE );
    END;

    RETURN E;
  END eKepler;

(*----------*)

  PROCEDURE hKepler() : LONGREAL;
  VAR
    d, llE : LONGREAL;
  BEGIN
    lE := 0.0;
    E  := e * math.sinh( M ) - M;
    WHILE ABS( E - lE ) > epsilon DO
      lE  := E;
      llE := E;

      normalizeAngle( llE );
      IF llE > pi THEN
        llE := llE - pi2;
      END;

      E  := e * math.sinh( llE ) - M;

      d  := E - lE;
    END;

    RETURN E;
  END hKepler;

(*----------*)

BEGIN
  (* e determines path - elliptic, parabolic, hyperbolic *)
  IF e < 1.0 THEN
    RETURN eKepler();
  ELSIF e > 1.0 THEN
    RETURN hKepler();
  ELSE
    RETURN M;
  END;
END Kepler;

(*===========================================================================*)

CLASS IMPLEMENTATION CCelestialMechanic;

(*---------------------------------------------------------------------------*)

  PROCEDURE SetJD( jd : TJD );
  BEGIN
    IF jd <> JD THEN
      memo.Counted := {};
      JD := jd;
      dT := ( JD - jd2000 ) / julianCentury;

      fd := frac( JD );
      IF fd < 0.5 THEN
        fd := fd + 0.5;
      ELSE
        fd := fd - 0.5;
      END;
      JD0 := JD - fd;
      dT0 := ( JD0 - jd2000 ) / julianCentury;

    END;
  END SetJD;

(*---------------------------------------------------------------------------*)

  PROCEDURE EquinoxEquation( S0_Hours : LONGREAL ) : LONGREAL;
  VAR
    dpsi, a : LONGREAL;
  BEGIN
    Nutation( dpsi, a );

    RETURN S0_Hours + dpsi * radToH * cos( Epsilon() );
  END EquinoxEquation;

(*---------------------------------------------------------------------------*)

PROCEDURE SideralTimeUT() : LONGREAL;
VAR
  k : LONGREAL;
  S0 : LONGREAL;
BEGIN
  IF NOT( memoSideralTime IN memo.Counted ) THEN
    S0 := secToH * eval( dT0, astro_p.MeanGrenwichSideralTime );
    S0 := EquinoxEquation( S0 );

    k  := eval( dT, astro_p.UT1toMeanGrenwichSideralTimeRatio );
    S0 := S0 + k * fd * 24.0;

    k := LONGREAL( LONGINT( S0 / 24.0 ));
    IF k < 0.0 THEN
      k := k - 1.0;
    ELSIF k > 0.0 THEN
      k := k + 1.0;
    END;
    S0 := S0 - k * 24.0;
    IF S0 < 0.0 THEN
      S0 := 24.0 + S0;
    END;

    memo.SideralTime := S0;
    INCL( memo.Counted, memoSideralTime );
  END;

  RETURN memo.SideralTime;
END SideralTimeUT;

(*===========================================================================*)

PROCEDURE DelaunayMonthParameters( VAR l, L, f, d, o : LONGREAL );
BEGIN
  d := eval( dT, astro_p.DelaunayD  );
  l := eval( dT, astro_p.DelaunayL );
  L := eval( dT, astro_p.DelaunayLL );
  f := eval( dT, astro_p.DelaunayF );
  o := eval( dT, astro_p.DelaunayO );

  d := d * arcSecToRad;
  l := l * arcSecToRad;
  L := L * arcSecToRad;
  f := f * arcSecToRad;
  o := o * arcSecToRad;
END DelaunayMonthParameters;

(*---------------------------------------------------------------------------*)

PROCEDURE Epsilon() : LONGREAL;
BEGIN
  IF NOT( memoEpsilon IN memo.Counted ) THEN
    memo.Epsilon := arcSecToRad * eval( dT, astro_p.EclipticInclination );
    INCL( memo.Counted, memoEpsilon );
  END;

  RETURN memo.Epsilon;
END Epsilon;

(*---------------------------------------------------------------------------*)

PROCEDURE Nutation( VAR dpsi, deps : LONGREAL );
VAR
  l, L, f, d, o  : LONGREAL;
  f2, d2, o2, rt : LONGREAL;
BEGIN
  IF memoNutation IN memo.Counted THEN
    dpsi := memo.dpsi;
    dpsi := memo.deps;
  ELSE
    DelaunayMonthParameters( l, L, f, d, o );

    (* [1], 19 *)

    f2 := 2.0*f; d2 := 2.0*d; o2 := 2.0*o;
    rt := f2 - d2 + o2;

    dpsi := - 17.20 * sin( o      ) - 1.32 * sin( rt     ) - 0.23 * sin( f2 + o2     )
            +  0.21 * sin( o2     ) + 0.14 * sin( L      ) + 0.07 * sin( l           )
            -  0.05 * sin( L + rt ) - 0.04 * sin( f2 + o ) - 0.03 * sin( l + f2 + o2 );
    deps := +  9.20 * cos( o      ) + 0.57 * cos( rt     ) + 0.10 * cos( f2 + o2     )
            -  0.09 * cos( o2     ) + 0.01 * cos( L      ) + 0.00 * cos( l           )
            +  0.02 * cos( L + rt ) + 0.02 * cos( f2 + o ) + 0.01 * cos( l + f2 + o2 );

    dpsi := dpsi * arcSecToRad;
    deps := deps * arcSecToRad;

    memo.dpsi := dpsi;
    memo.deps := deps;
    INCL( memo.Counted, memoNutation );
  END;
END Nutation;

(*---------------------------------------------------------------------------*)

PROCEDURE Precession( VAR ddzeta, dz, dny : LONGREAL );
BEGIN
  IF memoPrecession IN memo.Counted THEN
    ddzeta := memo.ddzeta;
    dz     := memo.dz;
    dny    := memo.dny;
  ELSE
    (* [1], 17 *)
    ddzeta := arcSecToRad * eval( dT, astro_p.PrecessionDzeta );
    dz     := arcSecToRad * eval( dT, astro_p.PrecessionZ     );
    dny    := arcSecToRad * eval( dT, astro_p.PrecessionNy    );

    memo.ddzeta := ddzeta;
    memo.dz     := dz;
    memo.dny    := dny;
    INCL( memo.Counted, memoPrecession );
  END;
END Precession;

(*---------------------------------------------------------------------------*)

PROCEDURE Refraction( VAR params : TRefractionParameters;
                      z, r : LONGREAL; VAR R : LONGREAL );
VAR
  B, _tan, H, f, _tan2 : LONGREAL;
  a, b, c, t : LONGREAL;
BEGIN
  IF memoRefraction IN memo.Counted THEN
    R := memo.R;
  ELSE
  (* [1], 27 *)
    B := params.phPa;  (* p  vzduchu hPa *)
    t := params.tC;    (* t  vzduchu C   *)
    H := params.fipc;  (* fi vzduchu %   *)

    f := 1.0E-4 * H * eval( t, astro_p.WaterSteamPressure );

    _tan := tan( z );
    _tan2 := _tan*_tan;

    a := ( 60.236 - 0.070 * _tan2 ) * arcSecToRad;
    b := B / 1013.25;    (* p vzduchu *)
    c := 1.0 +
         f * ( - 0.000152 - f * 0.00000550 ) / ( 1.0 + 0.00368 * t );

    R := a * b * c * _tan;

    IF r <> 0.0 THEN (* zmenseni o paralaktickou refrakci *)
      r := arcSecToRad * 474.0 / r * ( 1.0 + _tan2 ) * sin( z );
      R := R - r;
    END;

    memo.R := R;
    INCL( memo.Counted, memoRefraction );
  END;
END Refraction;

(*---------------------------------------------------------------------------*)

PROCEDURE CountGeoMonthBarycentricDifference( rB, rM : LONGREAL; VAR dl, dr : LONGREAL );
VAR
  a : LONGREAL;
  d : LONGREAL;
  k : LONGREAL;
BEGIN
  (* [1], 32 *)
  IF rM = 0.0 THEN
    rM := 384747.981;
  END;
  IF rB = 0.0 THEN
    rB := 1.00000101778;
  END;
  rB := rB * aU;

  k := atan( rM / ( 1.0 + 81.3 ) / rB );

  DelaunayMonthParameters( a, a, a, d, a );

  dl := k * sin( d );
  dr := k * cos( d );
END CountGeoMonthBarycentricDifference;

(*---------------------------------------------------------------------------*)

PROCEDURE Correct( correctionType : TCorrection; VAR coord : TCoord );

(*----------*)

  PROCEDURE CorrectNutation ( VAR coord : TCoord );
  VAR
    src, dst        : TCoord;
    x, y, z         : LONGREAL;
    dpsi, deps, eps : LONGREAL;
    sindeps, cosdeps,
    sineps, coseps,
    sindpsi, cosdpsi,
    sinepsdeps,
    cosepsdeps      : LONGREAL;
  BEGIN
    src := coord;
    dst.ReferencePoint := src.ReferencePoint;
    dst.CoordSystem    := csEquator;
    dst.CoordType      := ctRect;
    ConvertCoordLocal( JD, src, dst );

    Nutation( dpsi, deps );
    eps := Epsilon();

    sindeps    := sin( deps );
    cosdeps    := cos( deps );
    sineps     := sin( eps );
    coseps     := cos( eps );
    sinepsdeps := sin( eps + deps );
    cosepsdeps := cos( eps + deps );
    sindpsi    := sin( dpsi );
    cosdpsi    := cos( dpsi );

    src := dst;

    x := cosdpsi;
    y := - sindpsi * coseps;
    z := - sindpsi * sineps;

    dst.x := x * src.x + y * src.y + z * src.z;

    x := sindpsi * cosepsdeps;
    y :=   sinepsdeps * sineps + cosdpsi * cosepsdeps * coseps;
    z := - sinepsdeps * coseps + cosdpsi * cosepsdeps * sineps;

    dst.y := x * src.x + y * src.y + z * src.z;

    x := sindpsi * sinepsdeps;
    y := - cosepsdeps * sineps + cosdpsi * sinepsdeps * coseps;
    z :=   cosepsdeps * coseps + cosdpsi * sinepsdeps * sineps;

    dst.z := x * src.x + y * src.y + z * src.z;

    src.x := dst.x;
    src.y := dst.y;
    src.z := dst.z;

    dst := coord;
    ConvertCoordLocal( JD, src, dst );

    coord := dst;

    INCL( coord.Corrected, corNutation );
  END CorrectNutation;

(*----------*)

  PROCEDURE CorrectPrecession( VAR coord : TCoord );
  VAR
    src, dst        : TCoord;
    x, y, z         : LONGREAL;
    ddz, dz, dny    : LONGREAL;
    cosdz, sindz,
    cosz, sinz,
    cosny, sinny    : LONGREAL;
  BEGIN
    src := coord;
    dst.ReferencePoint := src.ReferencePoint;
    dst.CoordSystem    := csEquator;
    dst.CoordType      := ctRect;
    ConvertCoordLocal( JD, src, dst );

    Precession( ddz, dz, dny );

    sindz    := sin( ddz );
    cosdz    := cos( ddz );
    sinz     := sin( dz );
    cosz     := cos( dz );
    sinny    := sin( dny );
    cosny    := cos( dny );

    src := dst;

    x :=   cosdz * cosny * cosz - sindz * sinz;
    y := - sindz * cosny * cosz - cosdz * sinz;
    z := - sinny * cosz;

    dst.x := x * src.x + y * src.y + z * src.z;

    x :=   cosdz * cosny * sinz + sindz * cosz;
    y := - sindz * cosny * sinz + cosdz * cosz;
    z := - sinny * sinz;

    dst.y := x * src.x + y * src.y + z * src.z;

    x :=   cosdz * sinny;
    y := - sindz * sinny;
    z := cosny;

    dst.z := x * src.x + y * src.y + z * src.z;

    src.x := dst.x;
    src.y := dst.y;
    src.z := dst.z;
    dst := coord;
    ConvertCoordLocal( JD, src, dst );

    coord := dst;

    INCL( coord.Corrected, corPrecession );
  END CorrectPrecession;

(*----------*)

  PROCEDURE CorrectParalax( VAR coord : TCoord );
  VAR
    dst                  : TCoord;
    x, y, z              : LONGREAL;
    a, c, s              : LONGREAL;
    st                   : LONGREAL;
    cosfi, sinfi, sin2fi : LONGREAL;
  BEGIN
    dst := coord;
    dst.CoordSystem    := csEquator;
    dst.CoordType      := ctSphera;
    ConvertCoordLocal( JD, coord, dst );

    st := SideralTimeUT() * hToRad + dst.longitude;

    cosfi  := cos( dst.latitude );
    sinfi  := sin( dst.latitude );
    sin2fi := sinfi * sinfi;
    a      := 1.0 / sqrt( 1.0 - 0.006694 * sin2fi );
    c      := cosfi * ( a + 1.568E-7 * dst.altitude );;
    s      := sinfi * ( 0.993306 * a + 1.568E-7 * dst.altitude );

    dst.r  := dst.r * aU / rE;

    x := dst.r * cos( dst.delta ) * cos( st - dst.alfa ) - c;
    y := dst.r * cos( dst.delta ) * sin( st - dst.alfa );
    z := dst.r * sin( dst.delta ) - s;

    dst.r     := sqrt( x*x + y*y + z*z ) * rE / aU;
    dst.alfa  := st - atan2( y, x ); normalizeAngle( dst.alfa );
    dst.delta := atan( z / sqrt( x*x + y*y ));

    ConvertCoordLocal( JD, dst, coord );

    INCL( coord.Corrected, corParalax );
  END CorrectParalax;

(*----------*)

  PROCEDURE CorrectRefraction( VAR coord : TCoord );

    PROCEDURE sec( r : LONGREAL ) : LONGREAL;
    BEGIN
      RETURN 1.0 / cos( r );
    END sec;

    PROCEDURE cosec( r : LONGREAL ) : LONGREAL;
    BEGIN
      RETURN 1.0 / sin( r );
    END cosec;
  
  VAR
    src, dst   : TCoord;
    r, z, R    : LONGREAL;
    sinq, cosq : LONGREAL;
    st         : LONGREAL;
  BEGIN
    dst := coord;
    dst.CoordSystem    := csEquator;
    dst.CoordType      := ctSphera;
    ConvertCoordLocal( JD, coord, dst );
  
    IF dst.r < 0.01 * aU THEN
      r := dst.r * aU;
    ELSE
      r := 0.0;
    END;

    src := dst;
    src.CoordSystem := csAzimuth;
    ConvertCoordLocal( JD, dst, src );
    z := pib2 - src.h;
  
    Refraction( coord.refraction, z, r, R );
  
    st := SideralTimeUT() * hToRad + dst.longitude;
  
    sinq := cos( dst.latitude ) * cos( st - dst.alfa ) * cosec( z );
    cosq := cos( asin( sinq ));
    dst.alfa  := dst.alfa  - R * sinq * sec( dst.delta );
    dst.delta := dst.delta + R * cosq;

    ConvertCoordLocal( JD, dst, coord );

    INCL( coord.Corrected, corRefraction );
  END CorrectRefraction;

(*----------*)

  PROCEDURE CorrectBarycentricDifference( VAR coord : TCoord );
  VAR
    dst    : TCoord;
    dl, dr : LONGREAL;
  BEGIN
    dst := coord;
    dst.CoordSystem    := csEclip;
    dst.CoordType      := ctSphera;
    ConvertCoordLocal( JD, coord, dst );
  
    CountGeoMonthBarycentricDifference( dst.r, dM, dl, dr );
    dst.l := dst.l + dl;
    dst.r := dst.r + dr;

    ConvertCoordLocal( JD, dst, coord );

    INCL( coord.Corrected, corBarycenter );
  END CorrectBarycentricDifference;

(*----------*)

VAR
  dst : TCoord;
BEGIN
  IF coord.ReferencePoint.Kind <> rpGeocenter THEN
    RETURN;
  END;

  dst := coord;
  dst.CoordType := ctSphera;
  dst.CoordSystem := csEquator;

  ConvertCoordLocal( JD, coord, dst );

  CASE correctionType OF
  | corPrecession :
    CorrectPrecession( dst );
  | corNutation :
    CorrectNutation( dst );
  | corParalax :
    CorrectParalax( dst );
  | corRefraction :
    CorrectRefraction( dst );
  | corBarycenter :
    CorrectBarycentricDifference( dst );
  END;

  ConvertCoordLocal( JD, dst, coord );
END Correct;

(*---------------------------------------------------------------------------*)

PROCEDURE Uncorrect( correctionType : TCorrection; VAR coord : TCoord );

(*----------*)

  (* ?OK *) PROCEDURE UncorrectNutation ( VAR coord : TCoord );
  VAR
    src, dst        : TCoord;
    x, y, z         : LONGREAL;
    dpsi, deps, eps : LONGREAL;
    sindeps, cosdeps,
    sineps, coseps,
    sindpsi, cosdpsi,
    sinepsdeps,
    cosepsdeps      : LONGREAL;
  BEGIN
    src := coord;
    dst.ReferencePoint := src.ReferencePoint;
    dst.CoordSystem    := csEquator;
    dst.CoordType      := ctRect;
    ConvertCoordLocal( JD, src, dst );

    Nutation( dpsi, deps );
    eps := Epsilon();

    dpsi := - dpsi;
    deps := - deps;

    sindeps    := sin( deps );
    cosdeps    := cos( deps );
    sineps     := sin( eps );
    coseps     := cos( eps );
    sinepsdeps := sin( eps + deps );
    cosepsdeps := cos( eps + deps );
    sindpsi    := sin( dpsi );
    cosdpsi    := cos( dpsi );

    src := dst;

    x := cosdpsi;
    y := - sindpsi * coseps;
    z := - sindpsi * sineps;

    dst.x := x * src.x + y * src.y + z * src.z;

    x := sindpsi * cosepsdeps;
    y :=   sinepsdeps * sineps + cosdpsi * cosepsdeps * coseps;
    z := - sinepsdeps * coseps + cosdpsi * cosepsdeps * sineps;

    dst.y := x * src.x + y * src.y + z * src.z;

    x := sindpsi * sinepsdeps;
    y := - cosepsdeps * sineps + cosdpsi * sinepsdeps * coseps;
    z :=   cosepsdeps * coseps + cosdpsi * sinepsdeps * sineps;

    dst.z := x * src.x + y * src.y + z * src.z;

    src.x := dst.x;
    src.y := dst.y;
    src.z := dst.z;

    dst := coord;
    ConvertCoordLocal( JD, src, dst );

    coord := dst;

    INCL( coord.Corrected, corNutation );
  END UncorrectNutation;

(*----------*)

  (* ?OK *) PROCEDURE UncorrectPrecession( VAR coord : TCoord );
  VAR
    src, dst        : TCoord;
    x, y, z         : LONGREAL;
    ddz, dz, dny    : LONGREAL;
    cosdz, sindz,
    cosz, sinz,
    cosny, sinny    : LONGREAL;
  BEGIN
    src := coord;
    dst.ReferencePoint := src.ReferencePoint;
    dst.CoordSystem    := csEquator;
    dst.CoordType      := ctRect;
    ConvertCoordLocal( JD, src, dst );

    Precession( ddz, dz, dny );

    ddz := - ddz;
    dz  := - dz;
    dny := - dny;

    sindz    := sin( ddz );
    cosdz    := cos( ddz );
    sinz     := sin( dz );
    cosz     := cos( dz );
    sinny    := sin( dny );
    cosny    := cos( dny );

    src := dst;

    x :=   cosdz * cosny * cosz - sindz * sinz;
    y := - sindz * cosny * cosz - cosdz * sinz;
    z := - sinny * cosz;

    dst.x := x * src.x + y * src.y + z * src.z;

    x :=   cosdz * cosny * sinz + sindz * cosz;
    y := - sindz * cosny * sinz + cosdz * cosz;
    z := - sinny * sinz;

    dst.y := x * src.x + y * src.y + z * src.z;

    x :=   cosdz * sinny;
    y := - sindz * sinny;
    z := cosny;

    dst.z := x * src.x + y * src.y + z * src.z;

    src.x := dst.x;
    src.y := dst.y;
    src.z := dst.z;
    dst := coord;
    ConvertCoordLocal( JD, src, dst );

    coord := dst;

    INCL( coord.Corrected, corPrecession );
  END UncorrectPrecession;

(*----------*)

  (* NOK *) PROCEDURE UncorrectParalax( VAR coord : TCoord );
  VAR
    dst                  : TCoord;
    x, y, z              : LONGREAL;
    a, c, s              : LONGREAL;
    st                   : LONGREAL;
    cosfi, sinfi, sin2fi : LONGREAL;
  BEGIN
    dst := coord;
    dst.CoordSystem    := csEquator;
    dst.CoordType      := ctSphera;
    ConvertCoordLocal( JD, coord, dst );

    st := SideralTimeUT() * hToRad + dst.longitude;

    cosfi  := cos( dst.latitude );
    sinfi  := sin( dst.latitude );
    sin2fi := sinfi * sinfi;
    a      := 1.0 / sqrt( 1.0 - 0.006694 * sin2fi );
    c      := cosfi * ( a + 1.568E-7 * dst.altitude );;
    s      := sinfi * ( 0.993306 * a + 1.568E-7 * dst.altitude );

    dst.r  := dst.r * aU / rE;

    x := dst.r * cos( dst.delta ) * cos( st - dst.alfa ) - c;
    y := dst.r * cos( dst.delta ) * sin( st - dst.alfa );
    z := dst.r * sin( dst.delta ) - s;

    dst.r     := sqrt( x*x + y*y + z*z ) * rE / aU;
    dst.alfa  := st - atan2( y, x ); normalizeAngle( dst.alfa );
    dst.delta := atan( z / sqrt( x*x + y*y ));

    ConvertCoordLocal( JD, dst, coord );

    INCL( coord.Corrected, corParalax );
  END UncorrectParalax;

(*----------*)

  (* NOK *) PROCEDURE UncorrectRefraction( VAR coord : TCoord );

    PROCEDURE sec( r : LONGREAL ) : LONGREAL;
    BEGIN
      RETURN 1.0 / cos( r );
    END sec;

    PROCEDURE cosec( r : LONGREAL ) : LONGREAL;
    BEGIN
      RETURN 1.0 / sin( r );
    END cosec;

  VAR
    src, dst   : TCoord;
    r, z, R    : LONGREAL;
    sinq, cosq : LONGREAL;
    st         : LONGREAL;
  BEGIN
    dst := coord;
    dst.CoordSystem    := csEquator;
    dst.CoordType      := ctSphera;
    ConvertCoordLocal( JD, coord, dst );

    IF dst.r < 0.01 * aU THEN
      r := dst.r * aU;
    ELSE
      r := 0.0;
    END;

    src := dst;
    src.CoordSystem := csAzimuth;
    ConvertCoordLocal( JD, dst, src );
    z := pib2 - src.h;

    Refraction( coord.refraction, z, r, R );

    st := SideralTimeUT() * hToRad + dst.longitude;

    sinq := cos( dst.latitude ) * cos( st - dst.alfa ) * cosec( z );
    cosq := cos( asin( sinq ));
    dst.alfa  := dst.alfa  - R * sinq * sec( dst.delta );
    dst.delta := dst.delta + R * cosq;

    ConvertCoordLocal( JD, dst, coord );

    INCL( coord.Corrected, corRefraction );
  END UncorrectRefraction;

(*----------*)
  (*OK*)PROCEDURE UncorrectBarycentricDifference( VAR coord : TCoord );
  VAR
    dst    : TCoord;
    dl, dr : LONGREAL;
  BEGIN
    dst := coord;
    dst.CoordSystem    := csEclip;
    dst.CoordType      := ctSphera;
    ConvertCoordLocal( JD, coord, dst );

    CountGeoMonthBarycentricDifference( dst.r, dM, dl, dr );
    dst.l := dst.l - dl;
    dst.r := dst.r - dr;

    ConvertCoordLocal( JD, dst, coord );

    EXCL( coord.Corrected, corBarycenter );
  END UncorrectBarycentricDifference;

(*----------*)

VAR
  dst : TCoord;
BEGIN
  IF coord.ReferencePoint.Kind <> rpGeocenter THEN
    RETURN;
  END;

  dst := coord;
  dst.CoordType := ctSphera;
  dst.CoordSystem := csEquator;

  ConvertCoordLocal( JD, coord, dst );

  CASE correctionType OF
  | corPrecession :
    UncorrectPrecession( dst );
  | corNutation :
    UncorrectNutation( dst );
  | corParalax :
    UncorrectParalax( dst );
  | corRefraction :
    UncorrectRefraction( dst );
  | corBarycenter :
    UncorrectBarycentricDifference( dst );
  END;

  ConvertCoordLocal( JD, dst, coord );
END Uncorrect;

(*---------------------------------------------------------------------------*)

PROCEDURE GeomToZdanlive( jd : TJD; nestedCorrections : TCorrections; VAR coord : TCoord );
VAR
  dst : TCoord;
BEGIN
  IF coord.ReferencePoint.Kind <> rpGeocenter THEN
    RETURN;
  END;
  SetJD( jd );

  dst := coord;
  dst.CoordType := ctSphera;
  dst.CoordSystem := csEquator;

  ConvertCoordLocal( jd, coord, dst );

  IF corPrecession IN nestedCorrections THEN
    Correct( corPrecession, dst );
  END;
  IF corNutation IN nestedCorrections THEN
    Correct( corNutation, dst );
  END;
  IF corParalax IN nestedCorrections THEN
    Correct( corParalax, dst );
  END;
  IF corRefraction IN nestedCorrections THEN
    Correct( corRefraction, dst );
  END;

  ConvertCoordLocal( jd, dst, coord );
END GeomToZdanlive;

(*---------------------------------------------------------------------------*)

PROCEDURE ZdanliveToGeom( jd : TJD; VAR coord : TCoord );
BEGIN
  SetJD( jd );
  (* not implemented yet *)
END ZdanliveToGeom;

(*---------------------------------------------------------------------------*)

PROCEDURE ConvertCoordLocal( jd : TJD; src : TCoord; VAR dst : TCoord );
VAR
  b   : BOOLEAN;
  eps : LONGREAL;
  st  : LONGREAL;

  PROCEDURE ConvertSpherical(     D, L, e : LONGREAL;
                              VAR d, l    : LONGREAL );
  BEGIN
    d := asin( cos( e ) * sin( D ) - sin( e ) * cos( D ) * sin( L ));
    l := atan2( sin( e ) * sin( D ) + cos( e ) * cos( D ) * sin( L ),
                cos( D ) * cos( L ) );
    normalizeAngle( l );
  END ConvertSpherical;

  PROCEDURE iiSimpleConvertCoord();
  BEGIN
    CASE src.CoordType OF
    | ctRect :
      CASE dst.CoordType OF
      | ctRect :
        IF ( src.CoordSystem = csCommon ) OR
           ( dst.CoordSystem = csCommon ) THEN
          dst.x := src.x;
          dst.y := src.y;
          dst.z := src.z;
        ELSE
          CASE src.CoordSystem OF
          | csEquator :
            IF dst.CoordSystem = csEclip THEN
              dst.x := src.x;
              dst.y := src.z * sin( eps ) + src.y * cos( eps );
              dst.z := src.z * cos( eps ) - src.y * sin( eps );
            ELSE (* csAzimuth *)
              st := st + dst.longitude * radToH;
              st := st * hToRad;
              (* to EquatorI *)
              dst.x := src.x * cos( st ) + src.y * sin( st );
              dst.y := src.x * sin( st ) - src.y * cos( st );
              dst.z := src.z;
              (* to Azimuth *)
              src.x := dst.x; src.y := dst.y; src.z := dst.z;
              dst.x := src.x * sin( dst.latitude ) - src.z * cos( dst.latitude );
              dst.z := src.x * cos( dst.latitude ) + src.z * sin( dst.latitude );
            END;
          | csEclip :
            IF dst.CoordSystem = csEquator THEN
              dst.x := src.x;
              dst.y := src.y * cos( eps ) - src.z * sin( eps );
              dst.z := src.y * sin( eps ) + src.z * cos( eps );
            ELSE (* csAzimuth *)
              dst.CoordSystem := csEquator;
              iiSimpleConvertCoord();
              src := dst;
              dst.CoordSystem := csAzimuth;
              iiSimpleConvertCoord();
            END;
          | csAzimuth :
            IF dst.CoordSystem = csEquator THEN
              st := st + src.longitude * radToH;
              st := st * hToRad;
              (* to EquatorI *)
              dst.x := src.x * sin( src.latitude ) + src.z * cos( src.latitude );
              dst.y := src.y;
              dst.z := src.x * cos( src.latitude ) - src.z * sin( src.latitude );
              (* to EquatorII *)
              src.x := dst.x; src.y := dst.y; src.z := dst.z;
              dst.x := src.x * cos( st ) + src.y * sin( st );
              dst.y := src.x * sin( st ) - src.y * cos( st );
            ELSE (* csEclip *)
              dst.CoordSystem := csEquator;
              iiSimpleConvertCoord();
              src := dst;
              dst.CoordSystem := csEclip;
              iiSimpleConvertCoord();
            END;
          END;
        END;
      | ctSphera :
        IF src.CoordSystem <> dst.CoordSystem THEN
          dst.CoordType := ctRect;
          iiSimpleConvertCoord();
          src := dst;
          dst.CoordType := ctSphera;
        END;

        dst.r      := sqrt( src.x * src.x + src.y * src.y + src.z * src.z );
        dst.beta   := asin( src.z / dst.r );
        dst.lambda := atan2( src.y, src.x );

        normalizeAngle( dst.lambda );
      END;
    | ctSphera :
      CASE dst.CoordType OF
      | ctRect :
        IF src.CoordSystem <> dst.CoordSystem THEN
          dst.CoordType := ctSphera;
          iiSimpleConvertCoord();
          src := dst;
          dst.CoordType := ctRect;
        END;

        dst.x := src.r * cos( src.beta ) * cos( src.lambda );
        dst.y := src.r * cos( src.beta ) * sin( src.lambda );
        dst.z := src.r * sin( src.beta );
      | ctSphera :
        IF ( src.CoordSystem = csCommon ) OR
           ( dst.CoordSystem = csCommon ) THEN
          dst.r      := src.r;
          dst.beta   := src.beta;
          dst.lambda := src.lambda;
        ELSE
          CASE src.CoordSystem OF
          | csEquator :
            IF dst.CoordSystem = csEclip THEN
              ConvertSpherical( src.beta, src.lambda,
                                + eps,
                                dst.beta, dst.lambda );
            ELSE (* csAzimuth *)
              st := st * hToRad;
              st := st + dst.longitude;
              ConvertSpherical( src.delta, pib2 - st + src.alfa,
                                dst.latitude - pib2,
                                dst.h, dst.A );
              dst.A := pib2 - dst.A;
              normalizeAngle( dst.A );
            END;
          | csEclip :
            IF dst.CoordSystem = csEquator THEN
              ConvertSpherical( src.beta, src.lambda,
                                - eps,
                                dst.beta, dst.lambda );
            ELSE (* csAzimuth *)
              dst.CoordSystem := csEquator;
              iiSimpleConvertCoord();
              src := dst;
              dst.CoordSystem := csAzimuth;
              iiSimpleConvertCoord();
            END;
          | csAzimuth :
            IF dst.CoordSystem = csEquator THEN
              st := st * hToRad;
              st := st + src.longitude;
              ConvertSpherical( src.h, pib2 - src.A,
                                pib2 - src.latitude,
                                dst.delta, dst.alfa );
              dst.alfa := st - pib2 + dst.alfa;
              normalizeAngle( dst.alfa );
            ELSE (* csEclip *)
              dst.CoordSystem := csEquator;
              iiSimpleConvertCoord();
              src := dst;
              dst.CoordSystem := csEclip;
              iiSimpleConvertCoord();
            END;
          END;
        END;
      END;
    END;
  END iiSimpleConvertCoord;

BEGIN
  IF src.ReferencePoint <> dst.ReferencePoint THEN
    RETURN;
  END;

  IF ( src.CoordType = dst.CoordType ) AND
     ( src.CoordSystem = dst.CoordSystem ) THEN
    dst := src;
    RETURN;
  END;

  b := dst.CoordSystem = csAzimuth;
  IF b AND ( dst.ReferencePoint.Kind <> rpGeocenter ) THEN
    RETURN;
  END;

  SetJD( jd );

  eps := Epsilon();
  st  := SideralTimeUT();

  iiSimpleConvertCoord();
END ConvertCoordLocal;

(*---------------------------------------------------------------------------*)

PROCEDURE ConvertCoord( jdBody, jdEarth : TJD;
                        psrcBody, pdstBody : TPAbstractBody;
                        src : TCoord; VAR dst : TCoord );
VAR
  srcH, dstH : TCoord;
  dst1, dst2 : TCoord;
  jd         : TJD;
BEGIN
  IF ( src.ReferencePoint.Kind = rpPlanetocenter ) AND
     ( src.ReferencePoint.Planet = 3 ) THEN
    src.ReferencePoint.Kind := rpGeocenter;
  END;
  IF ( dst.ReferencePoint.Kind = rpPlanetocenter ) AND
     ( dst.ReferencePoint.Planet = 3 ) THEN
    dst.ReferencePoint.Kind := rpGeocenter;
  END;

  IF src.ReferencePoint <> dst.ReferencePoint THEN
    IF src.ReferencePoint.Kind <> rpHeliocenter THEN
      IF src.ReferencePoint.Kind = rpGeocenter THEN
        ZdanliveToGeom( jdEarth, src );
        src.ReferencePoint.Planet := 3;
      END;

      IF src.ReferencePoint.Kind = rpGeocenter THEN
        jd := jdEarth;
      ELSE
        jd := jdBody;
      END;

      SetJD( jd );
      psrcBody^.CountEphemerisHeliocentricGeometric( jd );
      srcH := psrcBody^.CoordsHeliocentricGeometric;
      IF src.ReferencePoint.Kind = rpGeocenter THEN
        Correct( corBarycenter, srcH );
      END;

      dst1 := srcH;
      dst1.CoordType := ctRect;
      ConvertCoordLocal( jd, srcH, dst1 );

      IF src.CoordType <> ctRect THEN
        dst2 := src;
        dst2.CoordType := ctRect;
        dst2.CoordSystem := csEclip;
        ConvertCoordLocal( jd, src, dst2 );
      ELSE
        dst2 := src;
      END;

      dst1.x := dst1.x + dst2.x;
      dst1.y := dst1.y + dst2.y;
      dst1.z := dst1.z + dst2.z;

      srcH := dst1;
    END;

    IF dst.ReferencePoint.Kind <> rpHeliocenter THEN
      IF dst.ReferencePoint.Kind = rpGeocenter THEN
        dst.ReferencePoint.Planet := 3;
      END;

      IF dst.ReferencePoint.Kind = rpGeocenter THEN
        jd := jdEarth;
      ELSE
        jd := jdBody;
      END;

      SetJD( jd );
      pdstBody^.CountEphemerisHeliocentricGeometric( jd );
      dstH := pdstBody^.CoordsHeliocentricGeometric;
      IF dst.ReferencePoint.Kind = rpGeocenter THEN
        Correct( corBarycenter, dstH );
      END;

      dst1 := dstH;
      dst1.CoordType := ctRect;
      ConvertCoordLocal( jd, dstH, dst1 );

      dstH := dst1;
    END;

    src := dst;
    src.CoordType := ctRect;
    src.CoordSystem := csEclip;

    src.x := srcH.x - dstH.x;
    src.y := srcH.y - dstH.y;
    src.z := srcH.z - dstH.z;
  END;

  ConvertCoordLocal( jd, src, dst );
  dst.rSun := srcH.rSun;
END ConvertCoord;

(*===========================================================================*)

PROCEDURE EphemerisHeliocentricGeometric( pBody : TPAbstractBody );
VAR
  coord : TCoord;
  q, d,
  M, E, v, u, s : LONGREAL;
BEGIN
  WITH pBody^.Elements DO
    IF FKnownPerihelDistance THEN
      IF e < 1.0 (* elliptic   *) THEN
        a := p * ( 1.0 - e );
      ELSIF e > 1.0 (* hyperbolic *) THEN
        a := p * ( e - 1.0 );
      ELSIF e = 1.0 (* parabolic  *) THEN
      END;
    END;

    IF e <> 1.0 THEN
      IF FKnownT0 THEN
        IF FKnownPeriod THEN
          M := pi2 * ( JD - T0 ) / P;
        ELSE
          n := gaussGravit * math.pow( a, -1.5 );
          M := n * ( JD - T0 );
        END;
      ELSIF FKnownM0 THEN
			M := M0 + n * ( JD - Epoch );
      ELSE
        IF FOmegaInPath THEN
          M := L - omega2;
        ELSE
          M := L - omega1 - Omega;
        END;
      END;

      normalizeAngle( M );
    END;

    IF e = 1.0 THEN (* parabolic *)
      (* E = W *)
      (* [2], 40 *)

      n := 2.0 * p * sqrt( 2.0 * p );
      E := 3.0 * gaussGravit / n * ( JD - T0 );

      (* v = s *)
      (* solve s^3 + 3s - W = 0 *)
      (* q := - W / 2.0, 3p = 3 *)
      q := E / 2.0;
      d := sqrt( 1.0 + q * q ); (* d = sqrt( - ( - p^3 - q^2 )) *)
      s := sqrt3( q + d );

      s := s + sqrt3( q - d );
      v := 2.0 * atan( s );
    ELSIF e > 1.0 THEN (* hyperbolic *)
      (* n/f yet
      E := Kepler( M, e );
      v := 2.0 * atan( tan( E / 2.0 ) * sqrt(( e + 1.0 ) / ( e - 1.0 )));
      *)
      E := M;
    ELSE
      E := Kepler( M, e );
      v := 2.0 * atan( tan( E / 2.0 ) * sqrt(( 1.0 + e ) / ( 1.0 - e )));
    END;

    IF FOmegaInPath THEN
      u := v + omega2 - Omega;
    ELSE
      u := v + omega1;
    END;

    normalizeAngle( u );

    coord.CoordType           := ctSphera;
    coord.CoordSystem         := csEclip;
    coord.ReferencePoint.Kind := rpHeliocenter;
    coord.Epoch               := JD;
    coord.Corrected           := {};

    coord.l    := atan2( cos( i ) * sin( u ), cos( u ) ) + Omega;
    coord.b    := asin( sin( i ) * sin( u ) );
    IF e = 1.0 THEN
      coord.r := p * ( 1.0 + s * s );
    ELSIF e > 1.0 THEN
      coord.r := a * ( e * e - 1.0 ) / ( 1.0 + e * cos( v ));
    ELSE
      coord.r := a * ( 1.0 - e * cos( E ));
    END;
    coord.rSun := coord.r;

    normalizeAngle( coord.l );

		pBody^.CoordsHeliocentricGeometric := coord;
		pBody^.CoordsHeliocentricGeometric.CoordType := ctRect;
		ConvertCoordLocal( JD, coord, pBody^.CoordsHeliocentricGeometric );

  END;
END EphemerisHeliocentricGeometric;

(*---------------------------------------------------------------------------*)

PROCEDURE Ephemeris( pBody : TPAbstractBody );
VAR
  coord, src, dst : TCoord;
  jdt             : TJD;
BEGIN
  src.ReferencePoint.Kind := rpBodyCenter;
  src.CoordSystem         := csCommon;
  src.CoordType           := ctRect;
  src.x := 0.0;
  src.y := 0.0;
  src.z := 0.0;

  dst                     := src;
  dst.ReferencePoint.Kind := rpGeocenter;
  dst.Epoch               := JD;
  dst.CoordType           := ctSphera;
  dst.CoordSystem         := csEquator;
  dst.Corrected           := {};

  ConvertCoord( JD, JD, pBody, PEarth, src, dst );

  IF corAberation IN pBody^.Corrections THEN
    jdt := dst.r * 499.005; (* aberation deviation *)
    jdt := jdt / 86400.0;

    ConvertCoord( JD - jdt, JD, pBody, PEarth, src, dst );
  END;

  GeomToZdanlive( JD, pBody^.Corrections, dst );

  coord := dst;
  coord.Corrected := pBody^.Corrections;

  WITH pBody^ DO
    CoordsEquatoreal := coord;
    CoordsAzimutal := coord;
    CoordsAzimutal.CoordSystem := astro.csAzimuth;
    ConvertCoordLocal( JD, coord, CoordsAzimutal );
  END;
END Ephemeris;

(*---------------------------------------------------------------------------*)

BEGIN
  PEarth := NIL;

  SetJD( jd2000 );
END CCelestialMechanic;

(*===========================================================================*)

CLASS IMPLEMENTATION CAbstractBody;

(*---------------------------------------------------------------------------*)

  PROCEDURE Init( alt, longitude, latitude : LONGREAL;
                  VAR refractionParameters : TRefractionParameters );
  BEGIN
    CoordsEquatoreal.longitude  := longitude;
    CoordsEquatoreal.latitude   := latitude;
    CoordsEquatoreal.altitude   := alt;
    CoordsEquatoreal.refraction := refractionParameters;

    CoordsAzimutal              := CoordsEquatoreal;
    CoordsHeliocentricGeometric := CoordsEquatoreal;
  END Init;

(*---------------------------------------------------------------------------*)

  VIRTUAL PROCEDURE FillElements( jd : TJD );
  BEGIN
  END FillElements;

(*---------------------------------------------------------------------------*)

  VIRTUAL PROCEDURE CountEphemerisHeliocentricGeometric( jd : TJD );
  BEGIN
    FillElements( jd );

    WITH PMechanic^ DO
      SetJD( jd );
      EphemerisHeliocentricGeometric( ADR( SELF ));
    END;
  END CountEphemerisHeliocentricGeometric;

(*---------------------------------------------------------------------------*)

  VIRTUAL PROCEDURE CountEphemeris( jd : TJD );
  BEGIN
    FillElements( jd );

    WITH PMechanic^ DO
      SetJD( jd );
      Ephemeris( ADR( SELF ));
    END;
  END CountEphemeris;

(*---------------------------------------------------------------------------*)

BEGIN
  PNext := NIL;
  PMechanic := NIL;

  Id := '';
  Storage.Zero( ADR( Elements ), SIZE( Elements ));

  Storage.Zero( ADR( CoordsHeliocentricGeometric ), SIZE( TCoord ));
  Storage.Zero( ADR( CoordsEquatoreal ), SIZE( TCoord ));
  Storage.Zero( ADR( CoordsAzimutal ), SIZE( TCoord ));
  
  Corrections := {};
END CAbstractBody;

(*===========================================================================*)

CLASS IMPLEMENTATION CPlanet;

(*---------------------------------------------------------------------------*)

  VIRTUAL PROCEDURE FillElements( jd : TJD );
  VAR
    _k, _h, _p, _q : LONGREAL;
  BEGIN
    ef82_def.GetVSOP82Elements( jd, Planet, Elements.a, Elements.L, _k, _h, _p, _q );

    WITH Elements DO
      FKnownPeriod := FALSE;
      FOmegaInPath := TRUE;

      e      := sqrt( _k*_k + _h*_h );
      omega2 := atan2( _h, _k );
      i      := 2.0 * asin( sqrt( _p*_p + _q*_q ));
      Omega  := atan2( _p, _q );
    END;
  END FillElements;

(*---------------------------------------------------------------------------*)

  VIRTUAL PROCEDURE CountEphemerisHeliocentricGeometric( jd : TJD );

  (*----------*)

  BEGIN
    CASE Planet OF
    | 10, 11 :  (* Moon *)
      RETURN;
    | 9 :  (* Pluto *)
      CountEHGPluto( jd );
    ELSE
      CAbstractBody.CountEphemerisHeliocentricGeometric( jd );
    END;
  END CountEphemerisHeliocentricGeometric;

(*---------------------------------------------------------------------------*)

  PROCEDURE CountEHGPluto( jd : TJD );
  BEGIN
    WITH CoordsHeliocentricGeometric DO
      l := 0.0; b := 0.0; r := 0.0;

      efPl_def.GetPlutoElements( jd, l, b, r );

      normalizeAngle( l );
      rSun := r;

      CoordType           := ctSphera;
      CoordSystem         := csEclip;
      ReferencePoint.Kind := rpHeliocenter;
      Epoch               := jd;
    END;
  END CountEHGPluto;

(*---------------------------------------------------------------------------*)

  VIRTUAL PROCEDURE CountEphemeris( jd : TJD );

  (*----------*)

  BEGIN
    CASE Planet OF
    | 10 : (* Moon *)
      CountEMoon( jd );
    | 11 : (* Sun  *)
      CountESun( jd );
    ELSE
      CAbstractBody.CountEphemeris( jd );
    END;
  END CountEphemeris;

(*---------------------------------------------------------------------------*)

  PROCEDURE CountESun( jd : TJD );
  VAR
    coord, src : TCoord;
    jdt        : TJD;
  BEGIN
    WITH PMechanic^ DO
      SetJD( jd );

      PEarth^.CountEphemerisHeliocentricGeometric( jd );
      coord := PEarth^.CoordsHeliocentricGeometric;
      Correct( corBarycenter, coord );

      IF corAberation IN Corrections THEN
        jdt := coord.r * 499.005;
        jdt := jdt / 86400.0;

        SetJD( jd - jdt );

        PEarth^.CountEphemerisHeliocentricGeometric( jd - jdt );
        coord := PEarth^.CoordsHeliocentricGeometric;
        Correct( corBarycenter, coord );
      END;

      coord.ReferencePoint.Kind := rpGeocenter;
      src := coord;

      src.l := src.l + pi;
      normalizeAngle( src.l );
      src.b := - src.b;

      coord.CoordSystem := csEquator;
      ConvertCoordLocal( jd, src, coord );

      GeomToZdanlive( jd, Corrections, coord );

      coord.rSun := coord.r;

      CoordsEquatoreal := coord;
      CoordsAzimutal.CoordSystem := astro.csAzimuth;
      ConvertCoordLocal( jd, coord, CoordsAzimutal );
    END;
  END CountESun;

(*---------------------------------------------------------------------------*)

  PROCEDURE CountEMoon( jd : TJD );
  VAR
    jdt      : LONGREAL;
    src, dst : TCoord;

    PROCEDURE iEfemerida();
    VAR
      dt                      : LONGREAL;
      l, ll, f, d, o, O, L, a : LONGREAL;
      l2, l3                  : LONGREAL;
      al, ab, ar              : LONGREAL;

    BEGIN
      WITH PMechanic^ DO
        SetJD( jd - jdt );
        DelaunayMonthParameters( l, ll, f, d, O );

        efMo_def.CountCorrections( l, ll, f, d, al, ab, ar );
        efMo_def.GetOrbitalElements( jd, a, L, o );

        dt := ( jd - jdt - jd2000 ) / julianCentury;
        // WITH ef82_def.solarSystem[2].orbit DO
        //   l2 := L[0] + dt * ( L[1] + dt * ( L[2] + dt * L[3] ));
        // END;
        l2 := ef82_def.solarSystem[2].orbit.L[0] +
					dt * ( ef82_def.solarSystem[2].orbit.L[1] +
					dt * ( ef82_def.solarSystem[2].orbit.L[2] +
					dt * ef82_def.solarSystem[2].orbit.L[3] ));
        // WITH ef82_def.solarSystem[3].orbit DO
        //   l3 := L[0] + dt * ( L[1] + dt * ( L[2] + dt * L[3] ));
        // END;
        l3 := ef82_def.solarSystem[3].orbit.L[0] +
					dt * ( ef82_def.solarSystem[3].orbit.L[1] +
					dt * ( ef82_def.solarSystem[3].orbit.L[2] +
					dt * ef82_def.solarSystem[3].orbit.L[3] ));

        src := CoordsEquatoreal;
        src.ReferencePoint.Kind := rpGeocenter;
        src.Epoch               := jd;
        src.CoordType           := ctSphera;
        src.CoordSystem         := csEclip;
        src.Corrected           := {corNutation, corPrecession};
        src.l :=   arcSecToRad * 14.0 * sin( 18.0 * l2 - 16.0 * l3 - l + 26.54 * degToRad )
                 + arcSecToRad * 7.0 * sin( O );
        src.l := src.l + L + al;

        src.b := ab - arcSecToRad * 8.0 * sin( L );
        src.r := ( a + ar ) / astro.aU;

        dst             := src;
        dst.CoordType   := ctSphera;
        dst.CoordSystem := csEquator;

        ConvertCoordLocal( jd, src, dst );
      END;
    END iEfemerida;

  BEGIN
    WITH PMechanic^ DO
      jdt := 0.0;
      iEfemerida();

      IF corAberation IN Corrections THEN
        jdt := dst.r * 499.005; (* aberation deviation *)
        jdt := jdt / 86400.0;

        iEfemerida();
      END;

      SetJD( jd );
      GeomToZdanlive( jd, Corrections, dst );

      CoordsEquatoreal := dst;
      CoordsAzimutal.CoordSystem := astro.csAzimuth;
      ConvertCoordLocal( jd, dst, CoordsAzimutal );
    END;
  END CountEMoon;

(*---------------------------------------------------------------------------*)

BEGIN
  Planet := 1;
END CPlanet;

(*===========================================================================*)

BEGIN
END astro.
