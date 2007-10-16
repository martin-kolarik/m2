MODULE day;

IMPORT
  IO,
  Lib,
  Str;

  PROCEDURE JulianDate( y, m, d : INTEGER ) : LONGREAL;
  VAR
    a, b : LONGINT;
    c    : LONGREAL;

    PROCEDURE MakeJulian() : LONGREAL;
    BEGIN
      a := LONGINT( 365.25  * LONGREAL( y ) - c ) +
           LONGINT( 30.6001 * LONGREAL( m )     ) +
           LONGINT( d ) + b;
      RETURN LONGREAL( a ) + 1720994.5;
    END MakeJulian;

  BEGIN
    IF m < 3 THEN
      DEC( y );
      INC( m, 13 );
    ELSE
      INC( m );
    END;
    IF y < 0 THEN
      c := -0.75;
    ELSE
      c := 0.0;
    END;
    a := LONGINT( y ) DIV 100;
    b := a DIV 4 - a + 2;
    IF ( y > 1582 ) THEN
      RETURN MakeJulian();
    ELSIF( y < 1582 ) THEN
      b := 0;
      RETURN MakeJulian();
    ELSIF m > 11 THEN
      RETURN MakeJulian();
    ELSIF d >= 15 THEN
      RETURN MakeJulian();
    END;
    b := 0;
    RETURN MakeJulian();
  END JulianDate;

  PROCEDURE Frac( r : LONGREAL ) : LONGREAL;
  BEGIN
    r := r - LONGREAL( LONGINT( r ));
    RETURN r;
  END Frac;

  PROCEDURE RMod( r, d : LONGREAL ) : LONGINT;
  VAR
    li : LONGINT;
  BEGIN
    li := LONGINT( d * Frac( r / d ) + 0.00000000001 );
    RETURN li;
  END RMod;

TYPE
  TArray = ARRAY [0..8] OF LONGINT;
  TStr   = ARRAY [0..15] OF CHAR;
  TDays  = ARRAY [0..6] OF TStr;

CONST
  Days   = TDays( TStr( 'Monday' ),
                  TStr( 'Tuesday' ),
                  TStr( 'Wednesday' ),
                  TStr( 'Thursday' ),
                  TStr( 'Friday' ),
                  TStr( 'Saturday' ),
                  TStr( 'Sunday' ));

VAR
  a      : TArray;
  a5     : LONGREAL;
  b      : BOOLEAN;
  fdays  : LONGREAL;
  days   : LONGREAL;
  djd    : LONGREAL;
  dy     : Lib.DayType;
  fmore  : BOOLEAN;
  i      : CARDINAL;
  jd     : LONGREAL;
  params : CARDINAL;
  s      : ARRAY [0..79] OF CHAR;
  week   : CARDINAL;
  y, mo,
  d, h, m: CARDINAL;

BEGIN
  IO.WrStr( 'Day info  [ params = y m d h m s.s fy fm fd ]' ); IO.WrLn();

  params := Lib.ParamCount();

  fmore := params > 6;

  a[ 0 ] := 0; a[ 1 ] := 1; a[ 2 ] := 1;   (* y, mO, d *)
  a[ 6 ] := 0; a[ 7 ] := 1; a[ 8 ] := 1;   (* from y, from mO, from d *)
  a[ 3 ] := 0; a[ 4 ] := 0; a5     := 0.0; (* h, m, s.s *)

  IF params = 0 THEN
    Lib.GetDate( y, mo, d, dy );
    Lib.GetTime( h, m, i, i );
    DEC( h, 2 );                           (* utCorr *)

    a[ 0 ] := LONGINT( y );
    a[ 1 ] := LONGINT( mo );
    a[ 2 ] := LONGINT( d );
    a[ 3 ] := LONGINT( h );
    a[ 4 ] := LONGINT( m );

    a[ 6 ] := 1995;
    a[ 7 ] := 10;
    a[ 8 ] := 31;
  ELSIF params > 9 THEN
    IO.WrStr( 'Sorry, too many parameters.' ); IO.WrLn();
    HALT;
  END;

  IF params > 0 THEN
    i := 0;
    LOOP
      Lib.ParamStr( s, i + 1 );
      IF i = 5 THEN
        a5 := Str.StrToReal( s, b );
      ELSE
        a[ i ] := Str.StrToInt( s, 10, b );
      END;

      INC( i );

      DEC( params );
      IF params = 0 THEN
        EXIT;
      END;
    END;
  END;

  jd := JulianDate( INTEGER( a[ 0 ] ),           (* now *)
                    INTEGER( a[ 1 ] ),
                    INTEGER( a[ 2 ] ));
  djd := JulianDate( INTEGER( a[ 0 ] ), 1, 1 );  (* first day of year *)

  days  := jd - djd;                             (* days from begin of year *)
  fdays := LONGREAL( RMod( djd + 0.5, 7.0 ));    (* days in first week *)
  days  := days + fdays + 6.0;                   (* round for DIV *)
  week  := CARDINAL( days ) DIV 7;

  jd := jd +                                     (* jd + hours *)
        LONGREAL( a[ 3 ] ) / 24.0 +
        LONGREAL( a[ 4 ] ) / 1440.0 +
        LONGREAL( a5     ) / 86400.0;

  IO.WrLn();
  IO.WrStr( 'Julian date: ' ); IO.WrFixReal( REAL( jd ), 6, 14 );                        IO.WrLn();
  IO.WrStr( 'day of week: ' ); IO.WrStr(     Days[ CARDINAL( RMod( jd + 0.5, 7.0 )) ] ); IO.WrLn();
  IO.WrStr( 'week:        ' ); IO.WrCard(    week, -1 );                                 IO.WrLn();

  IF fmore THEN
    djd := JulianDate( INTEGER( a[ 6 ] ), INTEGER( a[ 7 ] ), INTEGER( a[ 8 ] ));
    IO.WrLn();
    IO.WrStr( 'days from:   ' ); IO.WrLngInt( LONGINT( jd - djd ), 6 ); IO.WrLn();
    IO.WrStr( 'weeks from:  ' ); IO.WrLngInt( LONGINT( jd - djd ) DIV 7, 6 ); IO.WrStr( ', rest days:  ' ); IO.WrLngInt( LONGINT( jd - djd ) MOD 7, 6 ); IO.WrLn();
    IO.WrStr( 'years from:  ' ); IO.WrLngInt( LONGINT( jd - djd ) DIV 365, 6 ); IO.WrStr( ', rest weeks: ' ); IO.WrLngInt(( LONGINT( jd - djd ) MOD 365 ) DIV 7, 6 ); IO.WrStr( ', rest days: ' ); IO.WrLngInt(( LONGINT( jd - djd ) MOD 365 ) MOD 7, 6 );
  END;

  IO.WrLn();
END day.
