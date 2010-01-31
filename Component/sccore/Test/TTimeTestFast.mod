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

  PROCEDURE GetViewsTimeMS() : INTEGER;
  BEGIN
    RETURN windows.GetTickCount();
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
   CONST
      hns2ms = 0.0001; // converts 100-ns to ms
   VAR
      count : INTEGER := 1;
      n : ARRAY [0..31] OF WCHAR;
      s : ARRAY [0..255] OF WCHAR;
      sWTime : INTEGER;
      sDTime : INT64;
      dWTime : INTEGER;
      dDTime : INT64;
      dPTime : INTEGER;
      diff, sdiff : INTEGER := 0;
      freq, lqc, qc: windows.LARGE_INTEGER;
      measureDelay : CARDINAL;
      nsAbout : CARDINAL;
      nsPeriod : CARDINAL;
      msPeriod : CARDINAL := 100;
      nsDisabled : windows.BOOL;
      b : BOOLEAN;
   BEGIN
      IF HIGH( Parameters ) > -1 THEN
         b := Strings.ToCARD32W( Parameters[0]^, 10, OUT measureDelay );
      ELSE
         b := FALSE;
      END;
      IF NOT b THEN
         measureDelay := 200;
      END;

      Host^.Log^.LogSC( log.dlcInfo, L"", L'Measure period: ', measureDelay );
      IF windows.QueryPerformanceFrequency( freq ) = windows.True THEN
         Host^.Log^.LogSC( log.dlcInfo, L"", L'Performance counter frequency: ', CARDINAL( freq ));
      ELSE
         Host^.Log^.LogS( log.dlcInfo, L"", L'Performance counter frequency: <counter undefined>' );
      END;

      IF windows.GetSystemTimeAdjustment( ADR( nsAbout ), ADR( nsPeriod ), ADR( nsDisabled )) = windows.True THEN
         Host^.Log^.LogS( log.dlcInfo, L"", L'TickAdjustment settings:' );

         msPeriod := nsPeriod DIV 10000;
         Strings.FromLONGREALW( LONGREAL( nsPeriod ) * hns2ms, FALSE, OUT n );
         Host^.Log^.LogSS( log.dlcInfo, L"", L'  clock-irq period: ', n );

         IF nsDisabled = windows.False THEN
            Strings.FromLONGREALW( LONGREAL( nsAbout ) * hns2ms, FALSE, OUT n );
            Host^.Log^.LogSS( log.dlcInfo, L"", L'  adjustment is: ', n );
         ELSE
            Host^.Log^.LogS( log.dlcInfo, L"", L'  adjustment is: <undefined>' );
         END;
      ELSE
         Host^.Log^.LogS( log.dlcInfo, L"", L'TickAdjustment settings: <unknown>' );
      END;

      LOOP
         windows.Sleep( measureDelay );

         // wait for quantum exhaustion
         sWTime := GetViewsTimeMS();
         LOOP
            dWTime := GetViewsTimeMS();
            IF dWTime - sWTime > 0 THEN
               sWTime := dWTime;
               EXIT;
            END;
         END;

         // measure new quantum
         windows.QueryPerformanceCounter( lqc );
         sDTime := GetTimeMS();
         sWTime := GetViewsTimeMS();
         windows.Sleep(10000);
         dDTime := GetTimeMS() - sDTime;
         dWTime := GetViewsTimeMS() - sWTime;
         windows.QueryPerformanceCounter( qc );

         dPTime := INTEGER( INT64( qc ) - INT64( lqc ));
         diff := dWTime - INTEGER( dDTime DIV 10000 );
         sdiff := sdiff + diff;

         s := L'dQPC: '; Strings.FromINT32W( dPTime, 10, OUT n ); Strings.AppendW( REF s, n );
         Strings.AppendW( REF s, L' dQPCms: ' ); Strings.FromINT32W( INTEGER( LONGREAL( dPTime ) / LONGREAL( INT64( freq )) * 1000.0 ), 10, OUT n ); Strings.AppendW( REF s, n );
         Strings.AppendW( REF s, L' total (ms/day): ' ); Strings.FromINT32W( 8640 * sdiff DIV count, 10, OUT n ); Strings.AppendW( REF s, n );
         Strings.AppendW( REF s, L' dDTime: ' ); Strings.FromINT32W( INT32( dDTime ), 10, OUT n ); Strings.AppendW( REF s, n );
         Host^.Log^.LogS( log.dlcInfo, L"", s );

         INC( count )
      END; // LOOP
     
      RETURN test.trSuccess;
   END Run;

(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"TimeTestFast", ADR( TimeTestFast ));
END CTimeTestFast;
   
(*===========================================================================*)

END TTimeTestFast.
