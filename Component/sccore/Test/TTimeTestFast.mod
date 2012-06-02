MODULE TTimeTestFast;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;
FROM Exceptions IMPORT
   TestIfCatched, RetrieveException;

IMPORT
  FIOO,
  FSO,
  IOO,
  Languages,
  log,
  Strings,
  Sync,
  test,
  testimpl,
  TextReader,
  TextWriter,
  windows;

(*===========================================================================*)

(*----------*)

  PROCEDURE GetViewsTimeMS() : INT64;
  BEGIN
    RETURN INT64( windows.GetTickCount());
  END GetViewsTimeMS;

(*----------*)

  PROCEDURE GetTimeMS() : INT64;
  VAR
    ft : windows.FILETIME;
  BEGIN
    windows.GetSystemTimeAsFileTime( ADR( ft ));
    RETURN INT64( ft );
  END GetTimeMS;

(*----------*)

CLASS CTimeTestFast IMPLEMENTS test.ITest;
   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
END CTimeTestFast;

(*---------------------------------------------------------------------------*)

VAR
   TimeTestFast : CTimeTestFast;

(*===========================================================================*)

CLASS IMPLEMENTATION CTimeTestFast;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   TYPE
      TSamples = ARRAY [0..4] OF INT64;
      TArray = ARRAY [0..14] OF INTEGER;
   CONST
      hns2ms = 0.0001; // converts 100-ns to ms
      // SAMPLES = TSamples( 997, 1249, 1499, 1747, 1999 );
      // SAMPLES = TSamples( 151, 211, 457, 631, 751 );
      SAMPLES = TSamples( 60000, 60015, 60030, 60045, 60060 );
   VAR
      i : INTEGER;
      n : ARRAY [0..31] OF WCHAR;
      s : ARRAY [0..255] OF WCHAR;
      sWTime, s0WTime : INT64;
      sDTime, s0DTime : INT64;
      dWTime : INT64;
      dDTime : INT64;
      diff : INTEGER := 0;
      measureDelay : CARDINAL;
      nsAbout : CARDINAL;
      nsPeriod : CARDINAL;
      msPeriod : CARDINAL := 100;
      nsDisabled : windows.BOOL;
      q : INTEGER;
      b : BOOLEAN;

      val, sval, atr, satr : TArray;
      count, falsetickers, found, gcount, high, j, low, max, maxa, maxj, nintrv, sum : INTEGER;
      diffsum : INT64 := 0;
   BEGIN
      IF HIGH( Parameters ) > -1 THEN
         b := Strings.ToCARD32W( Parameters[0]^, 10, OUT measureDelay );
      ELSE
         b := FALSE;
      END;
      IF NOT b THEN
         measureDelay := 200;
      END;

      Host^.Log^.LogSC( log.lcInfo, 0, L"", L'Measure period: ', measureDelay );

      IF windows.GetSystemTimeAdjustment( ADR( nsAbout ), ADR( nsPeriod ), ADR( nsDisabled )) = windows.True THEN
         Host^.Log^.LogS( log.lcInfo, 0, L"", L'TickAdjustment settings:' );

         msPeriod := nsPeriod DIV 10000;
         Strings.FromLONGREALW( LONGREAL( nsPeriod ) * hns2ms, FALSE, OUT n );
         Host^.Log^.LogSS( log.lcInfo, 0, L"", L'  clock-irq period: ', n );

         IF nsDisabled = windows.False THEN
            Strings.FromLONGREALW( LONGREAL( nsAbout ) * hns2ms, FALSE, OUT n );
            Host^.Log^.LogSS( log.lcInfo, 0, L"", L'  adjustment is: ', n );
         ELSE
            Host^.Log^.LogS( log.lcInfo, 0, L"", L'  adjustment is: <undefined>' );
         END;
      ELSE
         Host^.Log^.LogS( log.lcInfo, 0, L"", L'TickAdjustment settings: <unknown>' );
      END;

      s0DTime := GetTimeMS();
      s0WTime := GetViewsTimeMS();

      gcount := 1;
      sum := 0;
      LOOP
         windows.Sleep( measureDelay );

         // measure new quanta
         FOR i := 0 TO HIGH( SAMPLES ) DO

            // wait for quantum exhaustion
            sWTime := GetViewsTimeMS();
            LOOP
               dWTime := GetViewsTimeMS();
               IF dWTime - sWTime > 0 THEN
                  sWTime := dWTime;
                  EXIT;
               END;
            END;

            sDTime := GetTimeMS();
            sWTime := GetViewsTimeMS();
            windows.Sleep( CARDINAL( SAMPLES[i] ));
            dDTime := ( GetTimeMS() - sDTime + 500 ) DIV 1000;
            dWTime := ( GetViewsTimeMS() - sWTime ) * 10;

            diff := INTEGER( SAMPLES[0] * ( dWTime - dDTime ) DIV SAMPLES[i] );

            s := L'dQPC ('; Strings.FromINT32W( INTEGER( SAMPLES[i] ), 10, OUT n ); Strings.AppendW( REF s, n ); Strings.AppendW( REF s, L"):" );
            q := 86400000 DIV 10 DIV SAMPLES[0];
            Strings.AppendW( REF s, L' diff (100us): ' ); Strings.FromINT32W( diff - 150, 10, OUT n ); Strings.AppendW( REF s, n ); Strings.AppendW( REF s, L".." ); Strings.FromINT32W( diff + 150, 10, OUT n ); Strings.AppendW( REF s, n );
            Strings.AppendW( REF s, L' act (ms/day): ' ); Strings.FromINT32W( q * diff, 10, OUT n ); Strings.AppendW( REF s, n );
            Strings.AppendW( REF s, L' dTic (100us): ' ); Strings.FromINT32W( INT32( dWTime ), 10, OUT n ); Strings.AppendW( REF s, n );
            Strings.AppendW( REF s, L' dDay (100us): ' ); Strings.FromINT32W( INT32( dDTime ), 10, OUT n ); Strings.AppendW( REF s, n );
            Host^.Log^.LogS( log.lcInfo, 0, L"", s );

            val[i*3+0] := diff - 150;
            atr[i*3+0] := -1;
            val[i*3+1] := diff;
            atr[i*3+1] := 0;
            val[i*3+2] := diff + 150;
            atr[i*3+2] := +1;

         END;

         // sort
         FOR i := HIGH( val ) TO 0 BY -1 DO
            max := MIN( INT32 );
            maxa := max;
            FOR j := 0 TO HIGH( val ) DO
               IF atr[j] = -2 THEN
                  CONTINUE;
               ELSIF val[j] > max THEN
                  maxa := atr[j];
                  max := val[j];
                  maxj := j;
               ELSIF atr[j] > maxa THEN
                  maxa := atr[j];
                  maxj := j;
               END;
            END;
            sval[i] := val[maxj];
            satr[i] := atr[maxj];
            atr[maxj] := -2;
         END;

         // apply algorithm
         low := MAX( INT32 );
         high := MIN( INT32 );
         falsetickers := 0;
         count := HIGH( SAMPLES ) + 1;
         WHILE 2 * falsetickers < count DO

		      // Bound the interval (low, high) as the largest
		      // interval containing points from presumed truechimers.
            found := 0;
            nintrv := 0;
            FOR i := 0 TO HIGH( sval ) DO
			      low := sval[i];
			      DEC( nintrv, satr[i] );
			      IF nintrv >= count - falsetickers THEN
                  EXIT;
               ELSIF satr[i] = 0 THEN
				      INC( found );
               END;
		      END; // FOR

		      nintrv := 0;
            FOR j := HIGH( sval ) TO 0 BY -1 DO
			      high := sval[j];
			      INC( nintrv, satr[j] );
			      IF nintrv >= count - falsetickers THEN
                  EXIT;
               ELSIF satr[j] = 0 THEN
                  INC( found );
               END;
		      END;

		      // If the number of candidates found outside the
		      // interval is greater than the number of falsetickers,
		      // then at least one truechimer is outside the interval,
		      // so go around again. This is what makes this algorithm
		      // different than Marzullo's.
		      IF found > falsetickers THEN
               INC( falsetickers );
               CONTINUE;
            END;

		      // If an interval containing truechimers is found, stop.
		      // If not, increase the number of falsetickers and go
		      // around again.
		      IF  high > low THEN
               EXIT; // OK
            END;

            INC( falsetickers );
         END; // while

         IF high > low THEN // OK
            i := low + (high-low) DIV 2;
            INC( sum, i );

            s := L'**    (xxx):';
            Strings.AppendW( REF s, L' diff (100us): ' ); Strings.FromINT32W( low, 10, OUT n ); Strings.AppendW( REF s, n ); Strings.AppendW( REF s, L".." ); Strings.FromINT32W( i, 10, OUT n ); Strings.AppendW( REF s, n ); Strings.AppendW( REF s, L".." ); Strings.FromINT32W( high, 10, OUT n ); Strings.AppendW( REF s, n );
            Strings.AppendW( REF s, L' act (ms/day): ' ); Strings.FromINT32W( q * i, 10, OUT n ); Strings.AppendW( REF s, n );
            Strings.AppendW( REF s, L' tot (ms/day): ' ); Strings.FromINT32W( q * (sum DIV gcount), 10, OUT n ); Strings.AppendW( REF s, n );
            Host^.Log^.LogS( log.lcInfo, 0, L"", s );

            i := INTEGER( LONGREAL(( sDTime - s0DTime ) / 10000 - sWTime + s0WTime ) / LONGREAL( sDTime - s0DTime ) * 864000000000.0 );
            INC( diffsum, i );

            s := L'**    (tot):';
            Strings.AppendW( REF s, L' diff W  (ms): ' ); Strings.FromINT32W( INTEGER( sWTime - s0WTime ), 10, OUT n ); Strings.AppendW( REF s, n );
            Strings.AppendW( REF s, L' diff D (ms): ' ); Strings.FromINT32W( INTEGER(( sDTime - s0DTime ) / 10000 ), 10, OUT n ); Strings.AppendW( REF s, n );
            Strings.AppendW( REF s, L' tot (ms/day): ' ); Strings.FromINT32W( i, 10, OUT n ); Strings.AppendW( REF s, n );
            Strings.AppendW( REF s, L' avg (ms/day): ' ); Strings.FromINT32W( INTEGER( diffsum / INT64( gcount )), 10, OUT n ); Strings.AppendW( REF s, n );
            Host^.Log^.LogS( log.lcInfo, 0, L"", s );
            Host^.Log^.LogS( log.lcInfo, 0, L"", L"" );

         ELSE // FAIL
            Host^.Log^.LogS( log.lcInfo, 0, L"", L"** FAIL" );
         END;

         INC( gcount );

         IF gcount > 100 THEN
           gcount := 1;
           diffsum := 0;
         END;
      END; // LOOP
   END Run;

(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"TimeTestFast", ADR( TimeTestFast ));
END CTimeTestFast;
   
(*===========================================================================*)

END TTimeTestFast.
