MODULE a;

IMPORT
  IO,
  FIO,
  Graph,
  Lib,
  Str,
  Window;

IMPORT
  astro;

(*===========================================================================*)

PROCEDURE GetTime( VAR H, M, S, HS : INTEGER );
VAR
  h, m, s, hs : CARDINAL;
BEGIN
  Lib.GetTime( h, m, s, hs );
  H  := INTEGER( h );
  M  := INTEGER( m );
  S  := INTEGER( s );
  HS := INTEGER( hs );
END GetTime;

(*---------------------------------------------------------------------------*)

PROCEDURE GetDate( VAR Y, M, D : INTEGER );
VAR
  y, m, d : CARDINAL;
  a       : Lib.DayType;
BEGIN
  Lib.GetDate( y, m, d, a );
  Y  := INTEGER( y );
  M  := INTEGER( m );
  D  := INTEGER( d );
END GetDate;

(*===========================================================================*)

CONST
  zlinLat  = ( 49.0 + 13.0 / 60.0 +  7.66 / 3600.0 ) * astro.degToRad;
  zlinLong = ( 17.0 + 41.0 / 60.0 + 53.49 / 3600.0 ) * astro.degToRad;
  zlinAlt  = 333.0;
  rpfi     = 10.0;
  rpp      = 975.0;
  rpt      = -5.0;

TYPE
  TmagParams = ARRAY [0..3] OF LONGREAL;
  TmagArray  = ARRAY [1..9] OF TmagParams;

CONST
  magArray  = TmagArray(
                TmagParams( -0.42,  0.038  , -0.000273,  0.000002   ),
                TmagParams( -4.40,  0.0009 ,  0.000239,  0.00000065 ),
                TmagParams(  0.0 ,  0.0    ,  0.0     ,  0.0        ),
                TmagParams( -1.52,  0.01486,  0.0     ,  0.0        ),
                TmagParams( -9.40,  0.0    ,  0.0     ,  0.0        ),
                TmagParams( -8.88,  0.044  ,  0.0     ,  0.0        ),
                TmagParams( -7.19,  0.0    ,  0.0     ,  0.0        ),
                TmagParams( -6.87,  0.0    ,  0.0     ,  0.0        ),
                TmagParams( -1.01,  0.0    ,  0.0     ,  0.0        )
                       );

VAR
  SideralTime         : LONGREAL;
  LocalSideralTime    : LONGREAL;
  Longitude, Latitude : LONGREAL;  LLongitude, LLatitude : LONGREAL;
  FCountExtended      : BOOLEAN;
  FPainted            : BOOLEAN;
  jd                  : LONGREAL;
  D, Mo, Y            : INTEGER;   LD, LMo, LY           : INTEGER;
  lH, H, Mi, S, HS    : INTEGER;   LlH, LH, LMi, LS, LHS : INTEGER;
  stH, stM            : INTEGER;   LstH, LstM            : INTEGER;
  stS                 : LONGREAL;  LstS                  : LONGREAL;
  lstH, lstM          : INTEGER;   LlstH, LlstM          : INTEGER;
  lstS                : LONGREAL;  LlstS                 : LONGREAL;
  dUT                 : INTEGER;   LdUT                  : INTEGER;
  DSTOn               : BOOLEAN;   LDSTOn                : BOOLEAN;
  BodyElements        : astro.TElements;
  MaxBody             : CARDINAL;
  Planets             : ARRAY [1..10] OF RECORD
                                           Coord  : astro.TCoord;
                                           LCoord : astro.TCoord;
                                           jdRise,
                                           jdSet,
                                           jdMax  : LONGREAL;
                                           ARise,
                                           ASet   : LONGREAL;
                                           hMax   : LONGREAL;
                                         END;
  Moon                : astro.TCoord;
  LMoon               : astro.TCoord;
  MoonJDRise, MoonJDSet, MoonJDMax,
  MoonARise, MoonASet, MoonHMax
                      : LONGREAL;
  Sun                 : astro.TCoord;
  LSun                : astro.TCoord;
  Corrected           : BITSET;    LCorrected            : BITSET;

  c                   : CARDINAL;
  ch                  : CHAR;
  i                   : CARDINAL;
  lr                  : LONGREAL;
  src                 : astro.TCoord;
  DataLocked          : BOOLEAN;
  LDataLocked         : BOOLEAN;
  dMo, dMi,
  dY, dH,
  dS, dD              : LONGINT;
  sMo, sMi,
  sY, sH,
  sS, sD              : INTEGER;
  ActivePage          : CARDINAL;

(*---------------------------------------------------------------------------*)

  PROCEDURE ReadElementsFromFile( fname : ARRAY OF CHAR; VAR elements : astro.TElements ) : BOOLEAN;
  VAR
    b           : BOOLEAN;
    f           : FIO.File;
    checkBitset : BITSET;
    ok          : BOOLEAN;
    r           : LONGREAL;
    s           : ARRAY [0..79] OF CHAR;
  BEGIN
    f := FIO.Open( fname );
    IF f = MAX( CARDINAL ) THEN
      RETURN FALSE;
    END;

    Lib.Fill( ADR( elements ), SIZE( astro.TElements ), 0 );
    checkBitset := {};
    ok := FALSE;

    FIO.EOF := FALSE;
    WHILE NOT FIO.EOF DO
      FIO.RdStr( f, s );

      CASE s[ 0 ] OF
      | 'a' :
        Str.ItemS( s, s, ' ', 1 );
        IF Str.Compare( s, '' ) # 0 THEN
          r := Str.StrToReal( s, b );
          IF b THEN
            INCL( checkBitset, 1 );
            elements.a := r;
          END;
        END;
      | 'i' :
        Str.ItemS( s, s, ' ', 1 );
        IF Str.Compare( s, '' ) # 0 THEN
          r := Str.StrToReal( s, b );
          IF b THEN
            INCL( checkBitset, 2 );
            elements.i := r;
          END;
        END;
      | 'e' :
        Str.ItemS( s, s, ' ', 1 );
        IF Str.Compare( s, '' ) # 0 THEN
          r := Str.StrToReal( s, b );
          IF b THEN
            INCL( checkBitset, 3 );
            elements.e := r;
          END;
        END;
      | 'o' :
        b := TRUE;
        CASE s[1] OF
        | '1' :
          elements.FOmegaInPath := TRUE;
        | '2' :
          elements.FOmegaInPath := FALSE;
        ELSE
          b := FALSE;
        END;
        IF b THEN
          Str.ItemS( s, s, ' ', 1 );
          IF Str.Compare( s, '' ) # 0 THEN
            r := Str.StrToReal( s, b );
            IF b THEN
              INCL( checkBitset, 4 );
              IF elements.FOmegaInPath THEN
                elements.omega1 := r;
              ELSE
                elements.omega2 := r;
              END;
            END;
          END;
        END;
      | 'O' :
        Str.ItemS( s, s, ' ', 1 );
        IF Str.Compare( s, '' ) # 0 THEN
          r := Str.StrToReal( s, b );
          IF b THEN
            INCL( checkBitset, 5 );
            elements.Omega := r;
          END;
        END;
      | 'L' :
        Str.ItemS( s, s, ' ', 1 );
        IF Str.Compare( s, '' ) # 0 THEN
          r := Str.StrToReal( s, b );
          IF b THEN
            INCL( checkBitset, 6 );
            elements.L := r;
          END;
        END;
      | 'P' :
        Str.ItemS( s, s, ' ', 1 );
        IF Str.Compare( s, '' ) # 0 THEN
          r := Str.StrToReal( s, b );
          IF b THEN
            INCL( checkBitset, 7 );
            elements.P := r;
          END;
        END;
      | 'T' :
        Str.ItemS( s, s, ' ', 1 );
        IF Str.Compare( s, '' ) # 0 THEN
          r := Str.StrToReal( s, b );
          IF b THEN
            INCL( checkBitset, 8 );
            elements.T := r;
          END;
        END;
      END;

      IF ( checkBitset = {1,2,3,4,5,6} ) OR
         ( checkBitset = {1,2,3,4,5,8} ) THEN
        IF 8 IN checkBitset THEN
          elements.FIsPeriod := TRUE;
          elements.FKnownPeriod := 7 IN checkBitset;
        END;
        ok := TRUE;
        FIO.EOF := TRUE;
      END;
    END;

    FIO.Close( f );

    RETURN ok;
  END ReadElementsFromFile;

(*---------------------------------------------------------------------------*)

  PROCEDURE PutScreen( header : BOOLEAN );
  BEGIN
    Window.TextColor( Window.LightGray );
    IF header THEN
      Window.GotoXY( 1, 1 );

      IO.WrStr( '--------------------------------------------------------------------------------' );
      IO.WrStr( 'Date: XX.XX.XXXX  |   UT time      : XX:XX:XX.X  |  Local time     : XX:XX:XX.X' ); IO.WrLn();
      IO.WrStr( 'dUT : sXX DST off |   UT star time : XX:XX:XX.X  |  Local star time: XX:XX:XX.X' ); IO.WrLn();
      IO.WrStr( '--------------------------------------------------------------------------------' );
      IO.WrStr( 'Date & Time Lock off | d(s) Ins/Del, mo(mi) Home/End, y(h) PgUp/PgDn (Ctrl)' ); IO.WrLn();
      IO.WrStr( '--------------------------------------------------------------------------------' );
      IO.WrStr( 'Longitude: sXX XX XX, sXXX.XXXXX | Precesion off  Aberation off  Refraction off' ); IO.WrLn();
      IO.WrStr( 'Latitude : sXX XX XX, s XX.XXXXX | Nutation  off  Paralax   off  Extended   off' ); IO.WrLn();
      IO.WrStr( '--------------------------------------------------------------------------------' );
    ELSE
      Window.GotoXY( 1, 10 );
    END;

    CASE ActivePage OF
    | 1 :
      IO.WrStr( '          alfa          delta       A          h           rEarth     rSun      ' );
      IO.WrStr( 'Sun       XX XX XX.XX   sXX XX.XX   XXX.XXXX   sXX XX.XX   XX.XXXXXX  XX.XXXXXX' ); IO.WrLn();
      IO.WrStr( 'Moon      XX XX XX.XX   sXX XX.XX   XXX.XXXX   sXX XX.XX   XX.XXXXXX  XX.XXXXXX' ); IO.WrLn();
      IO.WrStr( '--------------------------------------------------------------------------------' );
      IO.WrStr( 'Mercury   XX XX XX.XX   sXX XX.XX   XXX.XXXX   sXX XX.XX   XX.XXXXXX  XX.XXXXXX' ); IO.WrLn();
      IO.WrStr( 'Venus     XX XX XX.XX   sXX XX.XX   XXX.XXXX   sXX XX.XX   XX.XXXXXX  XX.XXXXXX' ); IO.WrLn();
      IO.WrStr( 'Earth     XX XX XX.XX   sXX XX.XX   XXX.XXXX   sXX XX.XX   XX.XXXXXX  XX.XXXXXX' ); IO.WrLn();
      IO.WrStr( 'Mars      XX XX XX.XX   sXX XX.XX   XXX.XXXX   sXX XX.XX   XX.XXXXXX  XX.XXXXXX' ); IO.WrLn();
      IO.WrStr( 'Jupiter   XX XX XX.XX   sXX XX.XX   XXX.XXXX   sXX XX.XX   XX.XXXXXX  XX.XXXXXX' ); IO.WrLn();
      IO.WrStr( 'Saturn    XX XX XX.XX   sXX XX.XX   XXX.XXXX   sXX XX.XX   XX.XXXXXX  XX.XXXXXX' ); IO.WrLn();
      IO.WrStr( 'Uranus    XX XX XX.XX   sXX XX.XX   XXX.XXXX   sXX XX.XX   XX.XXXXXX  XX.XXXXXX' ); IO.WrLn();
      IO.WrStr( 'Neptune   XX XX XX.XX   sXX XX.XX   XXX.XXXX   sXX XX.XX   XX.XXXXXX  XX.XXXXXX' ); IO.WrLn();
      IO.WrStr( 'Pluto     XX XX XX.XX   sXX XX.XX   XXX.XXXX   sXX XX.XX   XX.XXXXXX  XX.XXXXXX' ); IO.WrLn();
      IO.WrStr( '--------------------------------------------------------------------------------' );
      IF MaxBody > 9 THEN
        IO.WrStr( 'body      XX XX XX.XX   sXX XX.XX   XXX.XXXX   sXX XX.XX   XX.XXXXXX  XX.XXXXXX' ); IO.WrLn();
      END;

      Window.TextColor( Window.Red );
      Window.GotoXY( 1,  2 ); IO.WrChar( 'D' );   Window.GotoXY( 24, 2 ); IO.WrChar( 'T' );   Window.GotoXY( 60, 2 ); IO.WrChar( 'i' );
      Window.GotoXY( 2,  3 ); IO.WrChar( 'U' );   Window.GotoXY( 12, 3 ); IO.WrChar( 'S' );
      Window.GotoXY( 13, 5 ); IO.WrChar( 'L' );   Window.GotoXY( 29, 5 ); IO.WrStr( 'Ins' );  Window.GotoXY( 33, 5 ); IO.WrStr( 'Del' );
      Window.GotoXY( 45, 5 ); IO.WrStr( 'Home' ); Window.GotoXY( 50, 5 ); IO.WrStr( 'End' );
      Window.GotoXY( 60, 5 ); IO.WrStr( 'PgUp' ); Window.GotoXY( 65, 5 ); IO.WrStr( 'PgDn' ); Window.GotoXY( 71, 5 ); IO.WrStr( 'Ctrl' );
      (* dow.GotoXY( 3,  7 ); IO.WrChar( 'n' *)   Window.GotoXY( 36, 7 ); IO.WrChar( 'P' );   Window.GotoXY( 51, 7 ); IO.WrChar( 'A' );
      Window.GotoXY( 66, 7 ); IO.WrChar( 'R' );
      (* dow.GotoXY( 3,  8 ); IO.WrChar( 't' *)   Window.GotoXY( 36, 8 ); IO.WrChar( 'N' );   Window.GotoXY( 57, 8 ); IO.WrChar( 'x' );
      Window.GotoXY( 66, 8 ); IO.WrChar( 'E' );
    | 2 :
      IO.WrStr( '          mag     rise time rise A     max h time   max h    set time  set A    ' );
      IO.WrStr( 'Sun       sXX.X   XX XX XX  XXX.XXXX   XX XX XX  sXX XX.XX   XX XX XX  XXX.XXXX ' );
      IO.WrStr( 'Moon      sXX.X   XX XX XX  XXX.XXXX   XX XX XX  sXX XX.XX   XX XX XX  XXX.XXXX ' );
      IO.WrStr( '--------------------------------------------------------------------------------' );
      IO.WrStr( 'Mercury   sXX.X   XX XX XX  XXX.XXXX   XX XX XX  sXX XX.XX   XX XX XX  XXX.XXXX ' );
      IO.WrStr( 'Venus     sXX.X   XX XX XX  XXX.XXXX   XX XX XX  sXX XX.XX   XX XX XX  XXX.XXXX ' );
      IO.WrStr( 'Earth     sXX.X   XX XX XX  XXX.XXXX   XX XX XX  sXX XX.XX   XX XX XX  XXX.XXXX ' );
      IO.WrStr( 'Mars      sXX.X   XX XX XX  XXX.XXXX   XX XX XX  sXX XX.XX   XX XX XX  XXX.XXXX ' );
      IO.WrStr( 'Jupiter   sXX.X   XX XX XX  XXX.XXXX   XX XX XX  sXX XX.XX   XX XX XX  XXX.XXXX ' );
      IO.WrStr( 'Saturn    sXX.X   XX XX XX  XXX.XXXX   XX XX XX  sXX XX.XX   XX XX XX  XXX.XXXX ' );
      IO.WrStr( 'Uranus    sXX.X   XX XX XX  XXX.XXXX   XX XX XX  sXX XX.XX   XX XX XX  XXX.XXXX ' );
      IO.WrStr( 'Neptune   sXX.X   XX XX XX  XXX.XXXX   XX XX XX  sXX XX.XX   XX XX XX  XXX.XXXX ' );
      IO.WrStr( 'Pluto     sXX.X   XX XX XX  XXX.XXXX   XX XX XX  sXX XX.XX   XX XX XX  XXX.XXXX ' );
      IO.WrStr( '--------------------------------------------------------------------------------' );
      IF MaxBody > 9 THEN
        IO.WrStr( 'body      sXX.X   XX XX XX  XXX.XXXX   XX XX XX  sXX XX.XX   XX XX XX  XXX.XXXX ' );
      END;
    END;
  END PutScreen;

(*---------------------------------------------------------------------------*)

  PROCEDURE PutToCoord( FRepaint : BOOLEAN );
  VAR
    b, d   : BOOLEAN;
    dst    : astro.TCoord;
    h, m   : INTEGER;
    s, mag : LONGREAL;
    y      : CARDINAL;
  BEGIN
    (* long, lat *)
    Window.TextColor( Window.LightGray );
    Window.CursorOff();

    IF FRepaint OR ( Longitude # LLongitude ) THEN
      lr := Longitude * astro.radToDeg;
      IF lr < 0.0 THEN lr := -1.0 * lr; END;
      Window.GotoXY( 24, 7 ); IO.WrFixLngReal( lr, 5, 9 );
      astro.RadToD( lr * astro.degToRad, h, m, s, lr );
      Window.GotoXY( 13, 7 ); IO.WrCard( h, 2 );
      Window.GotoXY( 16, 7 ); IO.WrCard( m, 2 );
      Window.GotoXY( 19, 7 ); IO.WrFixLngReal( s, 0, 2 );
      IF Longitude < 0.0 THEN
        Window.GotoXY( 23, 7 ); IO.WrChar( '-' );
        Window.GotoXY( 12, 7 ); IO.WrChar( '-' );
      ELSE
        Window.GotoXY( 23, 7 ); IO.WrChar( '+' );
        Window.GotoXY( 12, 7 ); IO.WrChar( '+' );
      END;
      LLongitude := Longitude;
    END;
    IF FRepaint OR ( Latitude # LLatitude ) THEN
      lr := Latitude * astro.radToDeg;
      IF lr < 0.0 THEN lr := -1.0 * lr; END;
      Window.GotoXY( 24, 8 ); IO.WrFixLngReal( lr, 5, 9 );
      astro.RadToD( lr * astro.degToRad, h, m, s, lr );
      Window.GotoXY( 13, 8 ); IO.WrCard( h, 2 );
      Window.GotoXY( 16, 8 ); IO.WrCard( m, 2 );
      Window.GotoXY( 19, 8 ); IO.WrFixLngReal( s, 0, 2 );
      IF Latitude < 0.0 THEN
        Window.GotoXY( 23, 8 ); IO.WrChar( '-' );
        Window.GotoXY( 12, 8 ); IO.WrChar( '-' );
      ELSE
        Window.GotoXY( 23, 8 ); IO.WrChar( '+' );
        Window.GotoXY( 12, 8 ); IO.WrChar( '+' );
      END;
      LLatitude := Latitude;
    END;
  
    Window.TextColor( Window.White );
  
  (* UT & local time *)
    IF FRepaint OR ( LH # H ) THEN
      Window.GotoXY( 38, 2 ); IO.WrInt( H, 2 );
      Window.GotoXY( 70, 2 ); IO.WrInt( lH, 2 );
      LH := H;
    END;
    IF FRepaint OR ( LMi # Mi ) THEN
      Window.GotoXY( 41, 2 ); IO.WrInt( Mi, 2 );
      Window.GotoXY( 73, 2 ); IO.WrInt( Mi, 2 );
      LMi := Mi;
    END;
    IF FRepaint OR ( LS # S ) OR ( LHS # HS ) THEN
      Window.GotoXY( 44, 2 ); IO.WrFixLngReal( LONGREAL( 100 * S + HS ) / 100.0, 1, 4 );
      Window.GotoXY( 76, 2 ); IO.WrFixLngReal( LONGREAL( 100 * S + HS ) / 100.0, 1, 4 );
      LS := S; LHS := HS;
    END;
  (* UT star time *)
    IF FRepaint OR ( stH # LstH ) THEN
      Window.GotoXY( 38, 3 ); IO.WrInt( stH, 2 );
      LstH := stH;
    END;
    IF FRepaint OR ( stM # LstM ) THEN
      Window.GotoXY( 41, 3 ); IO.WrInt( stM, 2 );
      LstM := stM;
    END;
    IF FRepaint OR ( stS # LstS ) THEN
      Window.GotoXY( 44, 3 ); IO.WrFixLngReal( stS, 1, 4 );
      LstS := stS;
    END;
  (* local star time *)
    IF FRepaint OR ( lstH # LlstH ) THEN
      Window.GotoXY( 70, 3 ); IO.WrInt( lstH, 2 );
      LlstH := lstH;
    END;
    IF FRepaint OR ( lstM # LlstM ) THEN
      Window.GotoXY( 73, 3 ); IO.WrInt( lstM, 2 );
      LlstM := lstM;
    END;
    IF FRepaint OR ( lstS # LlstS ) THEN
      Window.GotoXY( 76, 3 ); IO.WrFixLngReal( lstS, 1, 4 );
      LlstS := lstS;
    END;
  (* DST *)
    IF FRepaint OR ( DSTOn # LDSTOn ) THEN
      Window.GotoXY( 15, 3 );
      IF DSTOn THEN
        IO.WrStr( 'on ' );
      ELSE
        IO.WrStr( 'off' );
      END;
      LDSTOn := DSTOn;
    END;
    IF FRepaint OR ( DataLocked # LDataLocked ) THEN
      Window.GotoXY( 18, 5 );
      IF DataLocked THEN
        IO.WrStr( 'on ' );
      ELSE
        IO.WrStr( 'off' );
      END;
      LDataLocked := DataLocked;
    END;
  (* dUT *)
    IF FRepaint OR ( dUT # LdUT ) THEN
      Window.GotoXY( 7, 3 ); IO.WrInt( ABS( dUT ), 3 );
      IF dUT > 0 THEN
        Window.GotoXY( 7, 3 ); IO.WrChar( '+' );
      ELSE
        Window.GotoXY( 7, 3 ); IO.WrChar( '-' );
      END;
      LdUT := dUT;
    END;
  (* date *)
    IF FRepaint OR ( D # LD ) THEN
      Window.GotoXY( 7, 2 ); IO.WrInt( D, 2 );
      LD := D;
    END;
    IF FRepaint OR ( Mo # LMo ) THEN
      Window.GotoXY( 10, 2 ); IO.WrInt( Mo, 2 );
      LMo := Mo;
    END;
    IF FRepaint OR ( Y # LY ) THEN
      Window.GotoXY( 13, 2 ); IO.WrInt( Y, 4 );
      LY := Y;
    END;

  (* corrections *)
    IF FRepaint OR ( Corrected # LCorrected ) THEN
      Window.GotoXY( 61, 7 );
      IF astro.corAberation IN Corrected THEN
        IO.WrStr( 'on ' );
      ELSE
        IO.WrStr( 'off' );
      END;
      Window.GotoXY( 77, 7 );
      IF astro.corRefraction IN Corrected THEN
        IO.WrStr( 'on ' );
      ELSE
        IO.WrStr( 'off' );
      END;
      Window.GotoXY( 46, 8 );
      IF astro.corNutation IN Corrected THEN
        IO.WrStr( 'on ' );
      ELSE
        IO.WrStr( 'off' );
      END;
      Window.GotoXY( 46, 7 );
      IF astro.corPrecession IN Corrected THEN
        IO.WrStr( 'on ' );
      ELSE
        IO.WrStr( 'off' );
      END;
      Window.GotoXY( 61, 8 );
      IF astro.corParalax IN Corrected THEN
        IO.WrStr( 'on ' );
      ELSE
        IO.WrStr( 'off' );
      END;

      LCorrected := Corrected;
    END;
    Window.GotoXY( 77, 8 );
    IF FCountExtended THEN
      IO.WrStr( 'on ' );
    ELSE
      IO.WrStr( 'off' );
    END;

    CASE ActivePage OF
    | 1 :
    (* planets *)
      i := 1;
      WHILE i <= MaxBody DO
        IF i = 10 THEN
          y := i + 1;
        ELSE
          y := i;
        END;

        IF i # 3 THEN
          b := FRepaint OR ( ABS( Planets[ i ].Coord.delta - Planets[ i ].LCoord.delta ) > 2.5E-6 );
          d := FRepaint OR ( ABS( Planets[ i ].Coord.alfa  - Planets[ i ].LCoord.alfa  ) > 2.0E-7 );
          IF b THEN
            astro.RadToD( Planets[ i ].Coord.delta, h, m, s, lr );
            Window.GotoXY( 26, 13 + y ); IO.WrInt( ABS( h ), 2 );
            IF Planets[ i ].Coord.delta < 0.0 THEN
              Window.GotoXY( 25, 13 + y ); IO.WrChar( '-' );
            ELSE
              Window.GotoXY( 25, 13 + y ); IO.WrChar( '+' );
            END;
            Window.GotoXY( 29, 13 + y ); IO.WrFixLngReal( lr, 2, 5 );
          END;

          IF d THEN
            astro.RadToRA( Planets[ i ].Coord.alfa, h, m, s, lr );
            Window.GotoXY( 11, 13 + y ); IO.WrInt( h, 2 );
            Window.GotoXY( 14, 13 + y ); IO.WrInt( m, 2 );
            Window.GotoXY( 17, 13 + y ); IO.WrFixLngReal( s, 2, 5 );
          END;

          IF FRepaint OR ( ABS( Planets[ i ].Coord.r - Planets[ i ].LCoord.r ) > 1.0E-6 ) THEN
            Window.GotoXY( 60, 13 + y ); IO.WrFixLngReal( Planets[ i ].Coord.r, 6, 9 );
          END;
        END;

        IF FRepaint OR ( ABS( Planets[ i ].Coord.rSun - Planets[ i ].LCoord.rSun ) > 1.0E-6 ) THEN
          Window.GotoXY( 71, 13 + y ); IO.WrFixLngReal( Planets[ i ].Coord.rSun, 6, 9 );
        END;

        IF i # 3 THEN
          IF b OR d THEN
            Planets[ i ].LCoord := Planets[ i ].Coord;
          END;

          dst := Planets[ i ].Coord;
          dst.CoordSystem := astro.csAzimuth;
          dst.longitude := Longitude;
          dst.latitude := Latitude;
          astro.SimpleConvertCoord( dst.Ekvinokcium, Planets[ i ].Coord, dst );

          Window.GotoXY( 37, 13 + y ); IO.WrFixLngReal( dst.A * astro.radToDeg, 4, 8 );
          astro.RadToD( dst.h, h, m, s, lr );
          Window.GotoXY( 49, 13 + y ); IO.WrInt( ABS( h ), 2 );
          IF dst.h < 0.0 THEN
            Window.GotoXY( 48, 13 + y ); IO.WrChar( '-' );
          ELSE
            Window.GotoXY( 48, 13 + y ); IO.WrChar( '+' );
          END;
          Window.GotoXY( 52, 13 + y ); IO.WrFixLngReal( lr, 2, 5 );
        END;

        INC( i );
      END;

    (* Sun *)
      b := ( ABS( Sun.delta - LSun.delta ) > 2.5E-6 );
      d := ( ABS( Sun.alfa  - LSun.alfa  ) > 2.0E-7 );
      IF FRepaint OR b THEN
        astro.RadToD( Sun.delta, h, m, s, lr );
        Window.GotoXY( 26, 11 ); IO.WrInt( ABS( h ), 2 );
        IF Sun.delta < 0.0 THEN
          Window.GotoXY( 25, 11 ); IO.WrChar( '-' );
        ELSE
          Window.GotoXY( 25, 11 ); IO.WrChar( '+' );
        END;
        Window.GotoXY( 29, 11 ); IO.WrFixLngReal( lr, 2, 5 );
      END;

      IF FRepaint OR d THEN
        astro.RadToRA( Sun.alfa, h, m, s, lr );
        Window.GotoXY( 11, 11 ); IO.WrInt( h, 2 );
        Window.GotoXY( 14, 11 ); IO.WrInt( m, 2 );
        Window.GotoXY( 17, 11 ); IO.WrFixLngReal( s, 2, 5 );
      END;

      IF FRepaint OR ( ABS( Sun.r - LSun.r ) > 1.0E-6 ) THEN
        b := TRUE;
        Window.GotoXY( 60, 11 ); IO.WrFixLngReal( Sun.r, 6, 9 );
      END;

      IF b OR d THEN
        LSun := Sun;
      END;

      dst := Sun;
      dst.CoordSystem := astro.csAzimuth;
      dst.longitude := Longitude;
      dst.latitude := Latitude;
      astro.SimpleConvertCoord( dst.Ekvinokcium, Sun, dst );

      Window.GotoXY( 37, 11 ); IO.WrFixLngReal( dst.A * astro.radToDeg, 4, 8 );
      astro.RadToD( dst.h, h, m, s, lr );
      Window.GotoXY( 49, 11 ); IO.WrInt( ABS( h ), 2 );
      IF dst.h < 0.0 THEN
        Window.GotoXY( 48, 11 ); IO.WrChar( '-' );
      ELSE
        Window.GotoXY( 48, 11 ); IO.WrChar( '+' );
      END;
      Window.GotoXY( 52, 11 ); IO.WrFixLngReal( lr, 2, 5 );

    (* Moon *)
      b := ( ABS( Moon.delta - LMoon.delta ) > 2.5E-6 );
      d := ( ABS( Moon.alfa  - LMoon.alfa  ) > 2.0E-7 );
      IF FRepaint OR b THEN
        astro.RadToD( Moon.delta, h, m, s, lr );
        Window.GotoXY( 26, 12 ); IO.WrInt( ABS( h ), 2 );
        IF Moon.delta < 0.0 THEN
          Window.GotoXY( 25, 12 ); IO.WrChar( '-' );
        ELSE
          Window.GotoXY( 25, 12 ); IO.WrChar( '+' );
        END;
        Window.GotoXY( 29, 12 ); IO.WrFixLngReal( lr, 2, 5 );
      END;

      IF FRepaint OR d THEN
        astro.RadToRA( Moon.alfa, h, m, s, lr );
        Window.GotoXY( 11, 12 ); IO.WrInt( h, 2 );
        Window.GotoXY( 14, 12 ); IO.WrInt( m, 2 );
        Window.GotoXY( 17, 12 ); IO.WrFixLngReal( s, 2, 5 );
      END;

      IF FRepaint OR ( ABS( Moon.r - LMoon.r ) > 1.0E-06 ) THEN
        b := TRUE;
        Window.GotoXY( 60, 12 ); IO.WrFixLngReal( astro.aU * 1.0E-6 * Moon.r, 6, 9 );
      END;

      IF b OR d THEN
        LMoon := Moon;
      END;

      dst := Moon;
      dst.CoordSystem := astro.csAzimuth;
      dst.longitude := Longitude;
      dst.latitude := Latitude;
      astro.SimpleConvertCoord( dst.Ekvinokcium, Moon, dst );

      Window.GotoXY( 37, 12 ); IO.WrFixLngReal( dst.A * astro.radToDeg, 4, 8 );
      astro.RadToD( dst.h, h, m, s, lr );
      Window.GotoXY( 49, 12 ); IO.WrInt( ABS( h ), 2 );
      IF dst.h < 0.0 THEN
        Window.GotoXY( 48, 12 ); IO.WrChar( '-' );
      ELSE
        Window.GotoXY( 48, 12 ); IO.WrChar( '+' );
      END;
      Window.GotoXY( 52, 12 ); IO.WrFixLngReal( lr, 2, 5 );

      Window.CursorOn();
    | 2 :
      IF FPainted THEN
        RETURN;
      END;

      FPainted := TRUE;

      i := 1;
      WHILE i <= MaxBody DO
        IF i = 10 THEN
          y := i + 1;
        ELSE
          y := i;
        END;

        IF ( i # 3 ) AND ( i # 10 ) THEN
          WITH Planets[ i ].Coord DO
            s := astro.acos(( rSun * rSun + r * r - Sun.r * Sun.r ) /
                            ( 2.0 * rSun * r )
                           );
            mag := astro.eval3( s, magArray[i,0], magArray[i,1], magArray[i,2], magArray[i,3] );
            mag := mag + 5.0 * astro.log( r * rSun );
          END;

          Window.GotoXY( 12, 13 + y ); IO.WrFixLngReal( ABS( mag ), 1, 4 );
          IF mag < 0.0 THEN
            Window.GotoXY( 11, 13 + y ); IO.WrChar( '-' );
          ELSE
            Window.GotoXY( 11, 13 + y ); IO.WrChar( '+' );
          END;
        END;

        IF i = 3 THEN
          y := -2;
        END;

        astro.JDToHours( Planets[ i ].jdRise, h, m, s, lr );
        h := h - dUT;
        IF DSTOn THEN
          h := h + 1;
        END;
        IF h > 23 THEN
          h := 24 - h;
        ELSIF h < 0 THEN
          h := 24 + h;
        END;
        Window.GotoXY( 19, 13 + y ); IO.WrInt( h, 2 );
        Window.GotoXY( 22, 13 + y ); IO.WrInt( m, 2 );
        Window.GotoXY( 25, 13 + y ); IO.WrFixLngReal( s, 0, 2 );

        astro.JDToHours( Planets[ i ].jdSet, h, m, s, lr );
        h := h - dUT;
        IF DSTOn THEN
          h := h + 1;
        END;
        IF h > 23 THEN
          h := 24 - h;
        ELSIF h < 0 THEN
          h := 24 + h;
        END;
        Window.GotoXY( 62, 13 + y ); IO.WrInt( h, 2 );
        Window.GotoXY( 65, 13 + y ); IO.WrInt( m, 2 );
        Window.GotoXY( 68, 13 + y ); IO.WrFixLngReal( s, 0, 2 );

        astro.JDToHours( Planets[ i ].jdMax, h, m, s, lr );
        h := h - dUT;
        IF DSTOn THEN
          h := h + 1;
        END;
        IF h > 23 THEN
          h := 24 - h;
        ELSIF h < 0 THEN
          h := 24 + h;
        END;
        Window.GotoXY( 40, 13 + y ); IO.WrInt( h, 2 );
        Window.GotoXY( 43, 13 + y ); IO.WrInt( m, 2 );
        Window.GotoXY( 46, 13 + y ); IO.WrFixLngReal( s, 0, 2 );

        Window.GotoXY( 29, 13 + y ); IO.WrFixLngReal( Planets[ i ].ARise * astro.radToDeg, 4, 8 );
        Window.GotoXY( 72, 13 + y ); IO.WrFixLngReal( Planets[ i ].ASet  * astro.radToDeg, 4, 8 );

        astro.RadToD( Planets[ i ].hMax, h, m, s, lr );
        Window.GotoXY( 51, 13 + y ); IO.WrInt( ABS( h ), 2 );
        IF Planets[ i ].hMax < 0.0 THEN
          Window.GotoXY( 50, 13 + y ); IO.WrChar( '-' );
        ELSE
          Window.GotoXY( 50, 13 + y ); IO.WrChar( '+' );
        END;
        Window.GotoXY( 54, 13 + y ); IO.WrFixLngReal( lr, 2, 5 );

        INC( i );
      END;

      (* Moon *)
      astro.JDToHours( MoonJDRise, h, m, s, lr );
      h := h - dUT;
      IF DSTOn THEN
        h := h + 1;
      END;
      IF h > 23 THEN
        h := 24 - h;
      ELSIF h < 0 THEN
        h := 24 + h;
      END;
      Window.GotoXY( 19, 12 ); IO.WrInt( h, 2 );
      Window.GotoXY( 22, 12 ); IO.WrInt( m, 2 );
      Window.GotoXY( 25, 12 ); IO.WrFixLngReal( s, 0, 2 );

      astro.JDToHours( MoonJDSet, h, m, s, lr );
      h := h - dUT;
      IF DSTOn THEN
        h := h + 1;
      END;
      IF h > 23 THEN
        h := 24 - h;
      ELSIF h < 0 THEN
        h := 24 + h;
      END;
      Window.GotoXY( 62, 12 ); IO.WrInt( h, 2 );
      Window.GotoXY( 65, 12 ); IO.WrInt( m, 2 );
      Window.GotoXY( 68, 12 ); IO.WrFixLngReal( s, 0, 2 );

      astro.JDToHours( MoonJDMax, h, m, s, lr );
      h := h - dUT;
      IF DSTOn THEN
        h := h + 1;
      END;
      IF h > 23 THEN
        h := 24 - h;
      ELSIF h < 0 THEN
        h := 24 + h;
      END;
      Window.GotoXY( 40, 12 ); IO.WrInt( h, 2 );
      Window.GotoXY( 43, 12 ); IO.WrInt( m, 2 );
      Window.GotoXY( 46, 12 ); IO.WrFixLngReal( s, 0, 2 );

      Window.GotoXY( 29, 12 ); IO.WrFixLngReal( MoonARise * astro.radToDeg, 4, 8 );
      Window.GotoXY( 72, 12 ); IO.WrFixLngReal( MoonASet  * astro.radToDeg, 4, 8 );

      astro.RadToD( MoonHMax, h, m, s, lr );
      Window.GotoXY( 51, 12 ); IO.WrInt( ABS( h ), 2 );
      IF MoonHMax < 0.0 THEN
        Window.GotoXY( 50, 12 ); IO.WrChar( '-' );
      ELSE
        Window.GotoXY( 50, 12 ); IO.WrChar( '+' );
      END;
      Window.GotoXY( 54, 12 ); IO.WrFixLngReal( lr, 2, 5 );
    END;
  END PutToCoord;

(*---------------------------------------------------------------------------*)

  PROCEDURE CountRises( jd : LONGREAL );
  CONST
    bdBody   = 1;
    bdPlanet = 2;
    bdSun    = 3;
    bdMoon   = 4;

  VAR
    jdt1, jdt2, jdt : LONGREAL;

    PROCEDURE CountH( body : CARDINAL;
                      fRise : BOOLEAN;
                      planet : CARDINAL;
                      jdt1, jdt2 : LONGREAL;
                      VAR A : LONGREAL ) : LONGREAL;
    VAR
      coord     : astro.TCoord;
      corrected : BITSET;
      dst       : astro.TCoord;
      h0        : LONGREAL;
      i         : CARDINAL;
      jd        : LONGREAL;
    BEGIN
      i := 0;
      Lib.Fill( ADR( coord ), SIZE( coord ), 0 );
      coord.longitude := zlinLong;
      coord.latitude := zlinLat;
      coord.altitude := zlinAlt;
      corrected := {astro.corPrecession, astro.corNutation, astro.corParalax};

      CASE body OF
      | bdPlanet, bdBody :
        h0 := -0.00989020 - astro.sqrt( coord.altitude ) * astro.degToRad * ( 1.8 / 60.0 );
      | bdSun :
        h0 := -0.01454441 - astro.sqrt( coord.altitude ) * astro.degToRad * ( 1.8 / 60.0 );
        planet := 3;
      | bdMoon :
        h0 := -0.01454441 - astro.sqrt( coord.altitude ) * astro.degToRad * ( 1.8 / 60.0 );
      END;

      WHILE i < 15 DO
        jd := ( jdt1 + jdt2 ) / 2.0;

        CASE body OF
        | bdPlanet, bdSun :
          astro.PEfemerida( planet, jd, corrected, coord );
        | bdBody :
          astro.Efemerida( jd, BodyElements, corrected, coord );
        | bdMoon :
          astro.MEfemerida( jd, corrected, coord );
        END;

        dst := coord;
        dst.CoordSystem := astro.csAzimuth;
        astro.SimpleConvertCoord( dst.Ekvinokcium, coord, dst );

        IF dst.h < h0 THEN
          IF fRise THEN
            jdt1 := jd;
          ELSE
            jdt2 := jd;
          END;
        ELSE
          IF fRise THEN
            jdt2 := jd;
          ELSE
            jdt1 := jd;
          END;
        END;

        INC( i );
      END;

      A := dst.A;
      RETURN jd;
    END CountH;

    PROCEDURE CountA( body : CARDINAL;
                      planet : CARDINAL;
                      jdt1, jdt2 : LONGREAL;
                      VAR h : LONGREAL ) : LONGREAL;
    VAR
      coord     : astro.TCoord;
      corrected : BITSET;
      dst       : astro.TCoord;
      h0        : LONGREAL;
      i         : CARDINAL;
      jd        : LONGREAL;
    BEGIN
      IF body = bdSun THEN
        planet := 3;
      END;

      i := 0;
      Lib.Fill( ADR( coord ), SIZE( coord ), 0 );
      coord.longitude := zlinLong;
      coord.latitude := zlinLat;
      coord.altitude := zlinAlt;
      corrected := {astro.corPrecession, astro.corNutation, astro.corParalax};

      WHILE i < 15 DO
        jd := ( jdt1 + jdt2 ) / 2.0;
        CASE body OF
        | bdPlanet, bdSun :
          astro.PEfemerida( planet, jd, corrected, coord );
        | bdBody :
          astro.Efemerida( jd, BodyElements, corrected, coord );
        | bdMoon :
          astro.MEfemerida( jd, corrected, coord );
        END;

        dst := coord;
        dst.CoordSystem := astro.csAzimuth;
        astro.SimpleConvertCoord( dst.Ekvinokcium, coord, dst );

        IF dst.A > astro.pi (* culmination *) THEN
          jdt1 := jd;
        ELSE
          jdt2 := jd;
        END;

        INC( i );
      END;

      h := dst.h;
      RETURN jd;
    END CountA;

  BEGIN
    jdt := astro.frac( jd );
    IF jdt > 0.5 THEN
      jdt := jd - jdt + 0.5;
    ELSE
      jdt := jd - jdt - 0.5;
    END;

    FOR i := 5 TO 5 DO
      jdt1 := jdt;
      jdt2 := jdt1 + 1.0;

      IF i < 11 THEN
        IF i = 3 THEN
          Planets[ i ].jdRise := CountH( bdSun, TRUE, i, jdt1, jdt2, Planets[ i ].ARise );
        ELSIF i = 10 THEN
          Planets[ i ].jdRise := CountH( bdBody, TRUE, i, jdt1, jdt2, Planets[ i ].ARise );
        ELSE
          Planets[ i ].jdRise := CountH( bdPlanet, TRUE, i, jdt1, jdt2, Planets[ i ].ARise );
        END;

        jdt1 := Planets[ i ].jdRise + 0.0007; (* 1 MIN *)
        jdt2 := jdt1 + 1.00;                  (* cca 1 day *)

        IF i = 3 THEN
          Planets[ i ].jdSet  := CountH( bdSun, FALSE, i, jdt1, jdt2, Planets[ i ].ASet );
        ELSIF i = 10 THEN
          Planets[ i ].jdSet  := CountH( bdBody, FALSE, i, jdt1, jdt2, Planets[ i ].ASet );
        ELSE
          Planets[ i ].jdSet  := CountH( bdPlanet, FALSE, i, jdt1, jdt2, Planets[ i ].ASet );
        END;

        IF i = 3 THEN
          Planets[ i ].jdMax := CountA( bdSun, i, Planets[i].jdRise, Planets[i].jdSet, Planets[ i ].hMax );
        ELSIF i = 10 THEN
          Planets[ i ].jdMax := CountA( bdBody, i, Planets[i].jdRise, Planets[i].jdSet, Planets[ i ].hMax );
        ELSE
          Planets[ i ].jdMax := CountA( bdPlanet, i, Planets[i].jdRise, Planets[i].jdSet, Planets[ i ].hMax );
        END;
      ELSE
        MoonJDRise := CountH( bdMoon, TRUE, i, jdt1, jdt2, MoonARise );

        jdt1 := MoonJDRise + 0.0007; (* 1 min *)
        jdt2 := jdt1 + 1.0;          (* due to Moon's movement *)

        MoonJDSet := CountH( bdMoon, FALSE, i, jdt1, jdt2, MoonASet );
        MoonJDMax := CountA( bdMoon, i, MoonJDRise, MoonJDSet, MoonHMax );
      END;
    END;
  END CountRises;

(*---------------------------------------------------------------------------*)

  PROCEDURE PaintScreen();
  BEGIN
  END PaintScreen;

(*---------------------------------------------------------------------------*)

VAR
  b        : BOOLEAN;
  dd       : LONGINT;
  s        : ARRAY [0..79] OF CHAR;
  sXYZ     : astro.TCoord;

BEGIN
  WITH astro.RefractionParameters DO
    tC := rpt;
    phPa := rpp;
    fipc := rpfi;
  END;

  ActivePage := 1;
  MaxBody := 9;
  jd := 0.0;
  FCountExtended := FALSE;
  FPainted := FALSE;

  IF Lib.ParamCount() = 1 THEN
    Lib.ParamStr( s, 1 );
    IF ReadElementsFromFile( s, BodyElements ) THEN
      MaxBody := 10;
    END;
  END;

  Longitude := zlinLong;
  Latitude  := zlinLat;
  dUT       := - 1;
  DSTOn     := FALSE;
  dH  := 0; dY  := 0;
  dMi := 0; dMo := 0;
  dS  := 0; dD  := 0;
  DataLocked := FALSE; LDataLocked := TRUE;
  Corrected := {astro.corBarycenter, astro.corPrecession, astro.corNutation, astro.corAberation};
  LCorrected := {astro.corBarycenter};

  FOR i := 1 TO MaxBody DO
    Planets[ i ].Coord.altitude  := zlinAlt;
    Planets[ i ].Coord.longitude := zlinLong;
    Planets[ i ].Coord.latitude  := zlinLat;
  END;
  Moon.altitude  := zlinAlt;
  Moon.longitude := zlinLong;
  Moon.latitude  := zlinLat;

  PutScreen( TRUE );

  H := 40; Mi := 70; S := 70;
  D := 50; Mo := 13; Y := 1900;
  REPEAT
    IF IO.KeyPressed() THEN
      ch := IO.RdKey();
      CASE CAP( ch ) OF
      | CHAR( 0 ) :
        ch := IO.RdKey();
        CASE ch OF
        | CHAR( 75 ) : (* LArr *)
(*
          CASE ActivePage OF
          | 1 :
            ActivePage := 3;

            Graph.GraphMode();
            PaintScreen();
          | 2 :
            ActivePage := 1;

            PutScreen( FALSE );
            PutToCoord( TRUE );
            FPainted := FALSE;
          | 3 :
            IF FCountExtended THEN
              ActivePage := 2;
            ELSE
              ActivePage := 1;
            END;

            Graph.TextMode();

            PutScreen( TRUE );
            PutToCoord( TRUE );
            FPainted := FALSE;
          END;
*)
          CASE ActivePage OF
          | 1 :
            IF FCountExtended THEN
              ActivePage := 2;
            END;
          | 2 :
            ActivePage := 1;
          END;

          PutScreen( FALSE );
          PutToCoord( TRUE );
          FPainted := FALSE;
        | CHAR( 77 ) : (* RArr *)
(*
          CASE ActivePage OF
          | 3 :
            ActivePage := 1;

            Graph.TextMode();

            PutScreen( TRUE );
            PutToCoord( TRUE );
            FPainted := FALSE;
          | 2 :
            ActivePage := 3;

            Graph.GraphMode();
            PaintScreen();
          | 1 :
            IF FCountExtended THEN
              ActivePage := 2;

              PutScreen( FALSE );
              PutToCoord( TRUE );
              FPainted := FALSE;
            ELSE
              ActivePage := 3;

              Graph.GraphMode();
              PaintScreen();
            END;
          END;
*)
          CASE ActivePage OF
          | 1 :
            IF FCountExtended THEN
              ActivePage := 2;
            END;
          | 2 :
            ActivePage := 1;
          END;

          PutScreen( FALSE );
          PutToCoord( TRUE );
          FPainted := FALSE;
        | CHAR( 81 ) : (* PgDn *)
          IF DataLocked THEN
            DEC( dY );
          END;
        | CHAR( 73 ) : (* PgUp *)
          IF DataLocked THEN
            INC( dY );
          END;
        | CHAR( 71 ) : (* Home *)
          IF DataLocked THEN
            INC( dMo );
          END;
        | CHAR( 83 ) : (* Del *)
          IF DataLocked THEN
            DEC( dD );
          END;
        | CHAR( 79 ) : (* End  *)
          IF DataLocked THEN
            DEC( dMo );
          END;
        | CHAR( 82 ) : (* Ins *)
          IF DataLocked THEN
            INC( dD );
          END;
        | CHAR( 117 ) : (* Ctrl+End  *)
          IF DataLocked THEN
            DEC( dMi );
          END;
        | CHAR( 147 ) : (* Ctrl+Del  *)
          IF DataLocked THEN
            DEC( dS );
          END;
        | CHAR( 118 ) : (* Ctrl+PgDn *)
          IF DataLocked THEN
            DEC( dH );
          END;
        | CHAR( 119 ) : (* Ctrl+Home *)
          IF DataLocked THEN
            INC( dMi );
          END;
        | CHAR( 146 ) : (* Ctrl+Ins  *)
          IF DataLocked THEN
            INC( dS );
          END;
        | CHAR( 132 ) : (* Ctrl+PgUp *)
          IF DataLocked THEN
            INC( dH );
          END;
        ELSE
          Lib.Speaker( 1000, 10 );
        END;
      | CHAR( 21 ) :
        DEC( dUT );
      | CHAR( 27 ) :
      | 'E' :
        FCountExtended := NOT FCountExtended;
        IF FCountExtended THEN
          LD := 0;
        END;
      | 'A' :
        IF astro.corAberation IN Corrected THEN
          EXCL( Corrected, astro.corAberation );
        ELSE
          INCL( Corrected, astro.corAberation );
        END;
      | 'N' :
        IF astro.corNutation IN Corrected THEN
          EXCL( Corrected, astro.corNutation );
        ELSE
          INCL( Corrected, astro.corNutation );
        END;
      | 'P' :
        IF astro.corPrecession IN Corrected THEN
          EXCL( Corrected, astro.corPrecession );
        ELSE
          INCL( Corrected, astro.corPrecession );
        END;
      | 'R' :
        IF astro.corRefraction IN Corrected THEN
          EXCL( Corrected, astro.corRefraction );
        ELSE
          INCL( Corrected, astro.corRefraction );
        END;
      | 'X' :
        IF astro.corParalax IN Corrected THEN
          EXCL( Corrected, astro.corParalax );
        ELSE
          INCL( Corrected, astro.corParalax );
        END;
      | 'L' :
        DataLocked := NOT DataLocked;
        dH  := 0;  dY  := 0;
        dMi := 0;  dMo := 0;
        dS  := 0;  dD  := 0;
        sH  := lH; sY  := Y;
        sMi := Mi; sMo := Mo;
        sS  := S;  sD  := D;
      | 'S' :
        DSTOn := NOT DSTOn;
      | 'U' :
        INC( dUT );
      ELSE
        Lib.Speaker( 1000, 10 );
      END;
    END;

    IF NOT DataLocked THEN
      GetDate( Y, Mo, D );
      GetTime( lH, Mi, S, HS );
    ELSE
      Y  := sY; Mo := sMo; D := sD;
      lH := sH; Mi := sMi; S := sS; HS := 0;
    END;

    H  := lH + dUT;
    IF DSTOn THEN
      H := H - 1;
    END;
    astro.IncTime( H, Mi, S, dH, dMi, dS, dd );
    astro.IncDate( Y, Mo, D, dY, dMo, dD + dd );

    lH := H - dUT;
    IF DSTOn THEN
      lH := lH + 1;
    END;
    IF lH > 23 THEN
      lH := 24 - lH;
    ELSIF lH < 0 THEN
      lH := 24 + lH;
    END;

    jd := LONGREAL( H  ) / 24.0 +
          LONGREAL( Mi ) / 1440.0 +
          LONGREAL( S  ) / 86400.0 +
          LONGREAL( HS ) / 8640000.0;
    jd := astro.JD( Y, Mo, D, jd );

    IF FCountExtended AND
       (( D # LD ) OR ( Mo # LMo ) OR ( Y # LY )) THEN
      CountRises( jd );

      FPainted := FALSE;
    END;

    SideralTime := astro.SideralTimeUT( jd );
    astro.RadToRA( SideralTime * astro.hToRad,
                   stH, stM, stS, lr );
    astro.RadToRA( SideralTime * astro.hToRad + Longitude,
                   lstH, lstM, lstS, lr );

    FOR i := 1 TO MaxBody DO
      IF i <= 9 THEN
        astro.PEfemerida( i, jd, Corrected, Planets[ i ].Coord );
      ELSE
        astro.Efemerida( jd, BodyElements, Corrected, Planets[ i ].Coord );
      END;

      IF i = 3 THEN
        Sun := Planets[ i ].Coord;
      END;
    END;
    astro.MEfemerida( jd, Corrected, Moon );

    PutToCoord( FALSE );
  UNTIL ch = CHAR( 27 ); (* Esc *)

  Window.Clear();
END a.

(*===========================================================================*)

