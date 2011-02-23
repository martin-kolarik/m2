MODULE timetest;

IMPORT
   datetime,
   testimpl,
   windows,
   Strings;

(*===========================================================================*)
// LR VARIANT

   CONST
     julianCentury    = 36525.0;
     gregorianCentury = 36524.25;
     julianYear       = 365.25;
     gregorianYear    = 365.2425;

(*---------------------------------------------------------------------------*)

   PROCEDURE frac( r : LONGREAL ) : LONGREAL;
   BEGIN
     RETURN r - LONGREAL( INT64( r ));
   END frac;

(*---------------------------------------------------------------------------*)

   PROCEDURE JD( y, m, d : INTEGER; fd : LONGREAL ) : LONGREAL;
   // JD ver 1.7 by mk - synchronized to day.mod utility
   VAR
     a, b : LONGINT;
     c    : LONGREAL;

     PROCEDURE MakeJulian() : LONGREAL;
     BEGIN
       a := LONGINT( 365.25  * LONGREAL( y ) - c ) +
            LONGINT( 30.6001 * LONGREAL( m )     ) +
            LONGINT( d ) + b;
       RETURN LONGREAL( a ) + 1720994.5 + fd;
     END MakeJulian;

   BEGIN
     IF m < 3 THEN
       DEC( y );
       INC( m, 13 );
     ELSE
       INC( m );
     END;

     IF y < 0 THEN
   //???    c := -0.75;
       c := 0.75;
     ELSE
       c := 0.0;
     END;

     a := y DIV 100;
     b := a DIV 4 - a + 2;

     IF y > 1582 THEN
       // shortcut
     ELSIF y < 1582 THEN
       b := 0;
     ELSIF y = 1582 THEN
       IF m < 11 THEN // should be m <= 10 !!, but m is already incremented from the begin of procedure !!
         b := 0;
       ELSIF ( m = 11 ) AND ( d < 15 ) THEN
         b := 0;
       END;
     END;

     RETURN MakeJulian();
   END JD;

(*---------------------------------------------------------------------------*)

   PROCEDURE iJD( jd : LONGREAL; VAR y, m, d : INTEGER; VAR fd : LONGREAL );
   VAR
     A, Z, alfa : INTEGER;
     B, C, X, E : LONGREAL;
   BEGIN
     Z  := INTEGER( jd + 0.5 );
     fd := frac( jd + 0.5 );
     IF ( 1.0 - fd ) < 1.0 / 86400000.0 THEN // msec correction
       fd := 0.0;
       INC( Z );
     END;

     IF Z < 2299161 THEN
       A    := Z;
     ELSE
       alfa := INTEGER(( LONGREAL( Z ) - 1867216.25 ) / gregorianCentury );
       A    := Z + 1 + alfa - alfa DIV 4;
     END;

     B := LONGREAL( A ) + 1524.0;
     C := LONGREAL( INTEGER( ( B - 122.1 ) / julianYear ));
     X := LONGREAL( INTEGER( C * julianYear ));
     E := LONGREAL( INTEGER(( B - X ) / 30.6001 ));

     IF E > 13.0 THEN
       m := INTEGER( E - 13.0 );
     ELSE
       m := INTEGER( E - 1.0 );
     END;
     IF m > 2 THEN
       y := INTEGER( C - 4716.0 );
     ELSE
       y := INTEGER( C - 4715.0 );
     END;
     d := INTEGER( B - X - LONGREAL( INTEGER( 30.6001 * E )));
   END iJD;

(*===========================================================================*)

PROCEDURE OJD( i : CARDINAL ) : LONGREAL;
BEGIN
   RETURN JD( 2007, 10, i MOD 2, 0.3 );
END OJD;

PROCEDURE NJD( i : CARDINAL ) : datetime.JulianDate;
VAR
   ts : datetime.TimeSpan;
BEGIN
   ts.Days := 0.3;
   RETURN datetime.JulianDateYMDfd( 2007, 10, i MOD 2, ts );
END NJD;

(*===========================================================================*)

   #save, call( convention => cdecl )
   PROCEDURE wmain04() : INTEGER;
   #restore
   CONST
      crlf = 13W + 10W;
   VAR
      jd : datetime.JulianDate;
      fd : datetime.TimeSpan;
      r : LONGREAL;
      y, M, d : INTEGER;

      diff : datetime.TimeSpan;
      S : ARRAY [0..255] OF WCHAR;
      t : datetime.HighResolutionTime;
      i : CARDINAL;
   BEGIN
      // conversion to
      t.SetNow();
      FOR i := 0 TO 99999999 DO
         r := OJD( i );
      END;
      diff := t - datetime.NowHR();

      Strings.FromLONGREALW( diff.Seconds, FALSE, OUT S );
      windows.OutputDebugStringW( L"  OS  jd: " );
      windows.OutputDebugStringW( ADR( S ));
      windows.OutputDebugStringW( ADR( crlf ));

      t.SetNow();
      FOR i := 0 TO 99999999 DO
         jd := NJD( i );
      END;
      diff := t - datetime.NowHR();

      Strings.FromLONGREALW( diff.Seconds, FALSE, OUT S );
      windows.OutputDebugStringW( L"time  jd: " );
      windows.OutputDebugStringW( ADR( S ));
      windows.OutputDebugStringW( ADR( crlf ));

      // conversion from
      r := JD( 2007, 10, 1, 0.3 );
      jd := datetime.JulianDateYMDfd( 2007, 10, 1, datetime.TimeSpanD( 0.3 ));

      t.SetNow();
      FOR i := 0 TO 99999999 DO
         iJD( r, OUT y, OUT M, OUT d, OUT r );
      END;
      diff := t - datetime.NowHR();

      Strings.FromLONGREALW( diff.Seconds, FALSE, OUT S );
      windows.OutputDebugStringW( L"  OS ijd: " );
      windows.OutputDebugStringW( ADR( S ));
      windows.OutputDebugStringW( ADR( crlf ));

      t.SetNow();
      FOR i := 0 TO 99999999 DO
         jd.ToYMD( OUT y, OUT M, OUT d, OUT fd );
      END;
      diff := t - datetime.NowHR();

      Strings.FromLONGREALW( diff.Seconds, FALSE, OUT S );
      windows.OutputDebugStringW( L"time ijd: " );
      windows.OutputDebugStringW( ADR( S ));
      windows.OutputDebugStringW( ADR( crlf ));

      RETURN 0;
   END wmain04;

BEGIN
   // testimpl.tests()^.AddTest( L"IntJD", NIL );
END timetest.