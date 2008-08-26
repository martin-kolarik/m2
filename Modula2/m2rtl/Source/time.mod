IMPLEMENTATION MODULE Time;

IMPORT
  windows,
  winnls;
  
IMPORT
  Storage,
  Strings,
  Sync;

//===========================================================================

PROCEDURE UptimeMS(): CARDINAL;
BEGIN
  RETURN CARDINAL( windows.GetTickCount() );
END UptimeMS;

(*----------------------------------------------------------------------*)

VAR
  LastTicks    : CARDINAL;
  LastTimeMS64 : TTime64;
  TimeLock     : Sync.LOCK;

PROCEDURE UptimeMS64(): TTime64;  // returns time from system startup in ms
VAR
  ticks : CARDINAL;
BEGIN
  TimeLock.Lock();
  ticks := windows.GetTickCount();
  INC( LastTimeMS64, ticks - LastTicks );
  LastTicks := ticks;
  TimeLock.Unlock();
  RETURN LastTimeMS64;
END UptimeMS64;

(*======================================================================*)
// high resolution timer

VAR
  FHaveHiResTimer : BOOLEAN;
  HiResTimerHz    : TTime64;

(*----------------------------------------------------------------------*)

PROCEDURE InitHiResTimer();
VAR
  li : windows.LARGE_INTEGER;
BEGIN
  FHaveHiResTimer := windows.QueryPerformanceFrequency( li ) = windows.True;
  IF FHaveHiResTimer THEN
    HiResTimerHz := TTime64( li );
  ELSE
    HiResTimerHz := 1000;
  END;
END InitHiResTimer;

(*----------------------------------------------------------------------*)

PROCEDURE HiResTimerExists() : BOOLEAN;
BEGIN
  RETURN FHaveHiResTimer;
END HiResTimerExists;

(*----------------------------------------------------------------------*)

PROCEDURE GetHiResHz() : TTime64;
BEGIN
  RETURN HiResTimerHz;
END GetHiResHz;

(*----------------------------------------------------------------------*)

PROCEDURE GetHiResTicks() : TTime64;
VAR
  li : windows.LARGE_INTEGER;
BEGIN
  IF FHaveHiResTimer THEN
    windows.QueryPerformanceCounter( li );
    RETURN TTime64( li );
  ELSE
    RETURN UptimeMS64();
  END;
END GetHiResTicks;

(*----------------------------------------------------------------------*)

PROCEDURE GetHiResDifference( REF fromTick : TTime64 ) : TTime64;
VAR
  ticks : TTime64;
BEGIN
  ticks := fromTick;
  fromTick := GetHiResTicks();
  RETURN fromTick - ticks;
END GetHiResDifference;

(*----------------------------------------------------------------------*)

PROCEDURE HiResTicksToMS( ticks : TTime64 ) : TTime64;
CONST
  secToMS = 1000;
BEGIN
  RETURN ( secToMS * ticks ) DIV HiResTimerHz;
END HiResTicksToMS;

(*----------------------------------------------------------------------*)

PROCEDURE HiResTicksToLRMS( ticks : TTime64 ) : LONGREAL;
CONST
  secToMS = 1000;
BEGIN
  RETURN LONGREAL( secToMS * ticks ) / LONGREAL( HiResTimerHz );
END HiResTicksToLRMS;

(*----------------------------------------------------------------------*)

PROCEDURE HiResTicksToLRS( ticks : TTime64 ) : LONGREAL;
BEGIN
  RETURN LONGREAL( ticks ) / LONGREAL( HiResTimerHz );
END HiResTicksToLRS;

(*----------------------------------------------------------------------*)

PROCEDURE difftime( CONST StopTime, StartTime : TTime64 ) : LONGREAL; // seconds
BEGIN
  RETURN LONGREAL( StopTime - StartTime ) / LONGREAL( HiResTimerHz );
END difftime;

(*===========================================================================*)
// by mk

CONST
  scale = TJD( 864000000 ); // 100 ns
  scaleLR = 864000000.0;

(*---------------------------------------------------------------------------*)

PROCEDURE fd( ri : TJD ) : CARDINAL;
BEGIN
   RETURN CARDINAL( ri MOD scale );
END fd;

(*---------------------------------------------------------------------------*)

PROCEDURE HMS2fd( H, M, S, MS : CARDINAL ) : CARDINAL;
BEGIN
   RETURN ((( H * 60 + M ) * 60 + S ) * 1000 + MS ) * 10;
END HMS2fd;

(*---------------------------------------------------------------------------*)

PROCEDURE fd2HMS( fd : CARDINAL; OUT H, M, S, MS : CARDINAL ) : BOOLEAN;
BEGIN
   fd := fd DIV 10;
   MS := fd MOD 1000;
   fd := fd DIV 1000;
   S := fd MOD 60;
   fd := fd DIV 60;
   M := fd MOD 60;
   H := fd DIV 60;

   IF MS = 1000 THEN
      INC( S );
      MS := 0;
   END;
   IF S = 60 THEN
      INC( M );
      S := 0;
   END;
   IF M = 60 THEN
       INC( H );
      M := 0;
   END;

   RETURN H = 24;
END fd2HMS;

(*---------------------------------------------------------------------------*)

// speed up of julian months
// julianMonth = 306001; -- multiples converted to table
TYPE
   TMonths = ARRAY [0..15] OF INTEGER;
CONST
   months = TMonths( 0,  30,  61,  91, 122, 153, 183, 214, 244, 275, 306, 336, 367, 397, 428, 459 );

PROCEDURE JD( y : INTEGER; m, d, fd : CARDINAL ) : TJD;
// JD ver 1.7 by mk - synchronized to day.mod utility
// JD ver 1.8 by mk - scaled to INT64
CONST
   julianYear = 2922; // scaled by 8 (<< 3)
VAR
  a, c : INTEGER;
BEGIN
  IF m > 12 THEN // to be sure
    INC( y, m DIV 12 );
    m := m MOD 12 + 1;
  END;
  IF m < 3 THEN
    DEC( y );
    INC( m, 13 );
  ELSE
    INC( m );
  END;

  IF y > 1582 THEN
    a := y DIV 100;
    c := 0;
    d := INTEGER( d ) + a DIV 4 - a + 2;
  ELSIF ( y = 1582 ) AND (( m > 11 ) OR ( m = 11 ) AND ( d >= 15 )) THEN
    a := y DIV 100;
    c := 0;
    d := INTEGER( d ) + a DIV 4 - a + 2;
  ELSIF y < 0 THEN
    c := 6; // scaled by 8
  END;

  RETURN scale * (
            ( julianYear * y - c ) DIV 8 + // years
            months[m] + // months
            d // scale
         ) +
         TJD( 1486939248000000 ) + // year 0 boundary, 1720994.5
         TJD( fd ); // fraction
END JD;

(*---------------------------------------------------------------------------*)

PROCEDURE iJD( CONST jd : TJD; OUT y : INTEGER; OUT m, d, fd : CARDINAL );
CONST
   gregorianCentury = 3652425; // scaled by 100
   julianYear = 36525; // scaled by 100
   julianMonth = 306001; // scaled by 10000
VAR
   a, b, alfa, z : INTEGER;
   jdl, jdx : TJD;
BEGIN
   // works up to cca +/- 64000 years, see assert
   jdl := jd + TJD( 432000000 );

   // separate fd, rescale to days
   jdx := jdl DIV scale;
   fd := CARDINAL( jdl - scale * jdx );
   z := INTEGER( jdx );
   ASSERT( z < MAX( INTEGER ) DIV 100 ); 

   IF z < 2299161 THEN
      a := z;
   ELSE
      alfa := ( 100 * z - 186721625 ) DIV gregorianCentury; // 1867216.25
      a := z + 1 + alfa - alfa DIV 4;
   END;

   b := a + 1524;
   y := ( 100 * b - 12210 ) DIV julianYear; // 122.1, years
   b := b - ( julianYear * y ) DIV 100;

   m := ( 10000 * b ) DIV julianMonth;
   d := b - months[m];

   IF m > 13 THEN
      m := m - 13;
   ELSE
      m := m - 1;
   END;
   IF m > 2 THEN
      y := y - 4716;
   ELSE
      y := y - 4715;
   END;
END iJD;

(*---------------------------------------------------------------------------*)

PROCEDURE DayOfWeek( CONST jd : TJD ) : CARDINAL;
BEGIN
   RETURN JDCToDays( jd + scale DIV 2 ) MOD 7;
END DayOfWeek;

(*---------------------------------------------------------------------------*)

PROCEDURE TrimFD( CONST jd : TJD ) : TJD;
BEGIN
   RETURN jd - jd MOD scale;
END TrimFD;

(*---------------------------------------------------------------------------*)

PROCEDURE JDCToMS( CONST jd : TJDC ) : CARDINAL;
BEGIN
   RETURN CARDINAL( jd DIV 10 );
END JDCToMS;

(*---------------------------------------------------------------------------*)

PROCEDURE MSToJDC( ms : CARDINAL ) : TJDC;
BEGIN
   RETURN TJDC( ms ) * 10;
END MSToJDC;

(*---------------------------------------------------------------------------*)

PROCEDURE JDCToDays( CONST jd : TJDC ) : CARDINAL;
BEGIN
   RETURN CARDINAL( jd DIV scale );
END JDCToDays;

(*---------------------------------------------------------------------------*)

PROCEDURE DaysToJDC( days : CARDINAL ) : TJDC;
BEGIN
   RETURN TJD( days ) * scale;
END DaysToJDC;

(*---------------------------------------------------------------------------*)

PROCEDURE JDCToDaysLR( CONST jd : TJDC ) : LONGREAL;
BEGIN
   RETURN LONGREAL( jd ) / scaleLR;
END JDCToDaysLR;

(*---------------------------------------------------------------------------*)

PROCEDURE DaysLRToJDC( days : LONGREAL ) : TJDC;
BEGIN
   RETURN TJD( days * scaleLR );
END DaysLRToJDC;

(*---------------------------------------------------------------------------*)

PROCEDURE ToSJD( CONST jd : TJD ) : LONGREAL;
BEGIN
   RETURN LONGREAL( jd ) / LONGREAL( scale );
END ToSJD;

(*---------------------------------------------------------------------------*)

PROCEDURE FromSJD( jd : LONGREAL ) : TJD;
BEGIN
   RETURN TJD(( jd + 0.5 / 864000000.0 ) * LONGREAL( scale ));
END FromSJD;

(*===========================================================================*)

TYPE
  TCWZoneInfo = RECORD
                  // Biases are always in MINUTES
                  SystemZoneInfo : windows.TIME_ZONE_INFORMATION;

                  DSTBias        : INTEGER; // DST bias respecting current DST state (if DST is off Current_DST_Bias = 0)
                  UTCDSTBias     : INTEGER; // SystemZoneInfo.Bias + CurrentDSTBias = both two biases in single element
                END;

VAR
  ZoneInfo : TCWZoneInfo;

//--------------------------------------------------------------

PROCEDURE InitDateTime( OUT DateTime : TDateTime );
BEGIN
  Storage.Zero( ADR( DateTime ), SIZE( DateTime ));
END InitDateTime;

//--------------------------------------------------------------

PROCEDURE TrimDate( REF DateTime : TDateTime );
BEGIN
   DateTime.Year := 0;
   DateTime.Month := 0;
   DateTime.Day := 0;
   DateTime.DayOfWeek := 0;
END TrimDate;

//--------------------------------------------------------------

PROCEDURE TrimTime( REF DateTime : TDateTime );
BEGIN
   DateTime.Hour := 0;
   DateTime.Minute := 0;
   DateTime.Second := 0;
   DateTime.Millisecond := 0;
   DateTime.DSTBias := 0;
   DateTime.UTCBias := 0;
END TrimTime;

//--------------------------------------------------------------

PROCEDURE Less( CONST Origin, Comperand : TDateTime ) : BOOLEAN;
BEGIN
   IF Comperand.Year > Origin.Year THEN
      RETURN FALSE;
   ELSIF Comperand.Year < Origin.Year THEN
      RETURN TRUE;
   ELSIF Comperand.Month > Origin.Month THEN
      RETURN FALSE;
   ELSIF Comperand.Month < Origin.Month THEN
      RETURN TRUE;
   ELSIF Comperand.Day > Origin.Day THEN
      RETURN FALSE;
   ELSIF Comperand.Day < Origin.Day THEN
      RETURN TRUE;
   ELSIF Comperand.Hour > Origin.Hour THEN
      RETURN FALSE;
   ELSIF Comperand.Hour < Origin.Hour THEN
      RETURN TRUE;
   ELSIF Comperand.Minute > Origin.Minute THEN
      RETURN FALSE;
   ELSIF Comperand.Minute < Origin.Minute THEN
      RETURN TRUE;
   ELSIF Comperand.Second > Origin.Second THEN
      RETURN FALSE;
   ELSIF Comperand.Second < Origin.Second THEN
      RETURN TRUE;
   ELSIF Comperand.Millisecond >= Origin.Millisecond THEN
      RETURN FALSE;
   END;
   RETURN TRUE;
END Less;

//--------------------------------------------------------------

PROCEDURE Greater( CONST Origin, Comperand : TDateTime ) : BOOLEAN;
BEGIN
   IF Comperand.Year < Origin.Year THEN
      RETURN FALSE;
   ELSIF Comperand.Year > Origin.Year THEN
      RETURN TRUE;
   ELSIF Comperand.Month < Origin.Month THEN
      RETURN FALSE;
   ELSIF Comperand.Month > Origin.Month THEN
      RETURN TRUE;
   ELSIF Comperand.Day < Origin.Day THEN
      RETURN FALSE;
   ELSIF Comperand.Day > Origin.Day THEN
      RETURN TRUE;
   ELSIF Comperand.Hour < Origin.Hour THEN
      RETURN FALSE;
   ELSIF Comperand.Hour > Origin.Hour THEN
      RETURN TRUE;
   ELSIF Comperand.Minute < Origin.Minute THEN
      RETURN FALSE;
   ELSIF Comperand.Minute > Origin.Minute THEN
      RETURN TRUE;
   ELSIF Comperand.Second < Origin.Second THEN
      RETURN FALSE;
   ELSIF Comperand.Second > Origin.Second THEN
      RETURN TRUE;
   ELSIF Comperand.Millisecond <= Origin.Millisecond THEN
      RETURN FALSE;
   END;
   RETURN TRUE;
END Greater;

//--------------------------------------------------------------

PROCEDURE GetZonalUTCBias() : INTEGER; // MINUTES!!
BEGIN
  RETURN INTEGER( ZoneInfo.SystemZoneInfo.Bias );
END GetZonalUTCBias;

//--------------------------------------------------------------

PROCEDURE GetZonalDSTBias() : INTEGER; // MINUTES!!
BEGIN
  RETURN INTEGER( ZoneInfo.SystemZoneInfo.DaylightBias );
END GetZonalDSTBias;

//--------------------------------------------------------------

PROCEDURE GetCurrentUTCBias() : INTEGER; // MINUTES!! 
BEGIN
  RETURN ZoneInfo.UTCDSTBias;
END GetCurrentUTCBias;

//--------------------------------------------------------------

PROCEDURE GetCurrentDSTBias() : INTEGER; // MINUTES!! 
BEGIN
  RETURN ZoneInfo.DSTBias;
END GetCurrentDSTBias;

//--------------------------------------------------------------

PROCEDURE GetCurrentJD() : TJD;
VAR
  DateTime : TDateTime;
BEGIN
  GetCurrentUTCDateTime( DateTime );
  RETURN ZonalDateTimeToJD( DateTime, 0, 0 );
END GetCurrentJD;

//--------------------------------------------------------------

PROCEDURE GetCurrentUTCDateTime( VAR DateTime : TDateTime );
VAR
  st : windows.SYSTEMTIME;
BEGIN
  WITH DateTime DO
    windows.GetSystemTime( ADR( st ));
    Millisecond := CARDINAL( st.wMilliseconds );
    Second      := CARDINAL( st.wSecond );
    Minute      := CARDINAL( st.wMinute );
    Hour        := CARDINAL( st.wHour );
    Day         := CARDINAL( st.wDay );
    Month       := CARDINAL( st.wMonth );
    Year        := CARDINAL( st.wYear );
    DayOfWeek   := CARDINAL( st.wDayOfWeek );
    UTCBias     := 0;
    DSTBias     := 0;
  END; // WITH
END GetCurrentUTCDateTime;

//--------------------------------------------------------------

PROCEDURE GetCurrentZonalDateTime( VAR DateTime : TDateTime; UTCBias, DSTBias : INTEGER );
BEGIN
  GetCurrentUTCDateTime( DateTime );
  ZonalDateTimeToZonalDateTime( DateTime, 0, 0, DateTime, UTCBias, DSTBias );
END GetCurrentZonalDateTime;

//--------------------------------------------------------------

PROCEDURE GetCurrentLocalDateTime( VAR DateTime : TDateTime );
VAR
  st : windows.SYSTEMTIME;
BEGIN
  WITH DateTime DO
    windows.GetLocalTime( ADR( st ));
    Millisecond := CARDINAL( st.wMilliseconds );
    Second      := CARDINAL( st.wSecond );
    Minute      := CARDINAL( st.wMinute );
    Hour        := CARDINAL( st.wHour );
    Day         := CARDINAL( st.wDay );
    Month       := CARDINAL( st.wMonth );
    Year        := CARDINAL( st.wYear );
    DayOfWeek   := CARDINAL( st.wDayOfWeek );
    UTCBias     := GetZonalUTCBias();
    DSTBias     := GetCurrentDSTBias();
  END; // WITH
END GetCurrentLocalDateTime;

//--------------------------------------------------------------

PROCEDURE JDToZonalDateTime( JD : TJD; VAR DateTime : TDateTime; _UTCBias, _DSTBias : INTEGER );
VAR
  FD : CARDINAL;
  Y, M, D : INTEGER;
BEGIN
  WITH DateTime DO
    JD := JD - TJD( _UTCBias + _DSTBias ) * 36000000;

    iJD( JD, OUT Y, OUT M, OUT D, OUT FD );
    UTCBias := _UTCBias;
    DSTBias := _DSTBias;

    Year := CARDINAL( Y );
    Month := CARDINAL( M );
    Day := CARDINAL( D );
    DayOfWeek := CARDINAL( ToSJD( JD ) + 1.5 ) MOD 7; // ( JD + 0.5 ) MOD 7 gives 0 = Monday
    fd2HMS( FD, OUT Hour, OUT Minute, OUT Second, OUT Millisecond );
  END;
END JDToZonalDateTime;

//--------------------------------------------------------------

PROCEDURE JDToLocalDateTime( JD : TJD; VAR DateTime : TDateTime );
BEGIN
  JDToZonalDateTime( JD, DateTime, GetZonalUTCBias(), 0 );
  IF dstActive( DateTime ) THEN
    JDToZonalDateTime( JD, DateTime, GetZonalUTCBias(), GetZonalDSTBias());
  END;
END JDToLocalDateTime;

//--------------------------------------------------------------

PROCEDURE ZonalDateTimeToJD( CONST DateTime : TDateTime; _UTCBias, _DSTBias : INTEGER ) : TJD;
BEGIN
  WITH DateTime DO
    RETURN JD(
             INTEGER( Year ),
             INTEGER( Month ),
             INTEGER( Day ),
             HMS2fd( Hour, Minute, Second, Millisecond ) + CARDINAL( _UTCBias + _DSTBias ) * 36000000
           );
  END;
END ZonalDateTimeToJD;

//--------------------------------------------------------------

PROCEDURE LocalDateTimeToJD( CONST DateTime : TDateTime ) : TJD;
BEGIN
  IF dstActive( DateTime ) THEN
    RETURN ZonalDateTimeToJD( DateTime, GetZonalUTCBias(), GetZonalDSTBias());
  ELSE
    RETURN ZonalDateTimeToJD( DateTime, GetZonalUTCBias(), 0 );
  END;
END LocalDateTimeToJD;

//--------------------------------------------------------------

PROCEDURE DateTimeToJD( CONST DateTime : TDateTime ) : TJD;
BEGIN
  RETURN ZonalDateTimeToJD( DateTime, DateTime.UTCBias, DateTime.DSTBias );
END DateTimeToJD;

//--------------------------------------------------------------

PROCEDURE LocalDateTimeToZonalDateTime( CONST DateTime1 : TDateTime; VAR DateTime2 : TDateTime; UTCBias, DSTBias : INTEGER );
BEGIN
  IF dstActive( DateTime1 ) THEN
    ZonalDateTimeToZonalDateTime( DateTime1, GetZonalUTCBias(), GetZonalDSTBias(), DateTime2, UTCBias, DSTBias );
  ELSE
    ZonalDateTimeToZonalDateTime( DateTime1, GetZonalUTCBias(), 0, DateTime2, UTCBias, DSTBias );
  END;
END LocalDateTimeToZonalDateTime;

//--------------------------------------------------------------

PROCEDURE ZonalDateTimeToLocalDateTime( CONST DateTime1 : TDateTime; UTCBias, DSTBias : INTEGER; VAR DateTime2 : TDateTime );
VAR
  JD : TJD;
BEGIN
  JD := ZonalDateTimeToJD( DateTime1, UTCBias, DSTBias );
  JDToLocalDateTime( JD, DateTime2 );
END ZonalDateTimeToLocalDateTime;

//--------------------------------------------------------------

PROCEDURE ZonalDateTimeToZonalDateTime( CONST DateTime1 : TDateTime; UTCBias1, DSTBias1 : INTEGER; VAR DateTime2 : TDateTime; UTCBias2, DSTBias2 : INTEGER );
VAR
  JD : TJD;
BEGIN
  IF ( UTCBias1 = UTCBias2 ) AND ( DSTBias1 = DSTBias2 ) THEN
    // no conversion is needed
    DateTime2 := DateTime1;
  ELSE
    // full converting is needed
    JD := ZonalDateTimeToJD( DateTime1, UTCBias1, DSTBias1 );
    JDToZonalDateTime( JD, DateTime2, UTCBias2, DSTBias2 );
  END;
END ZonalDateTimeToZonalDateTime;

//--------------------------------------------------------------

PROCEDURE DateTimeToLocalDateTime( CONST DateTime1 : TDateTime; VAR DateTime2 : TDateTime );
BEGIN
  ZonalDateTimeToLocalDateTime( DateTime1, DateTime1.UTCBias, DateTime1.DSTBias, DateTime2 );
END DateTimeToLocalDateTime;

//--------------------------------------------------------------

PROCEDURE DateTimeToZonalDateTime( CONST DateTime1 : TDateTime; VAR DateTime2 : TDateTime; UTCBias2, DSTBias2 : INTEGER );
BEGIN
  ZonalDateTimeToZonalDateTime( DateTime1, DateTime1.UTCBias, DateTime1.DSTBias, DateTime2, UTCBias2, DSTBias2 );
END DateTimeToZonalDateTime;

//--------------------------------------------------------------

PROCEDURE dstActive( CONST DateTime : TDateTime ) : BOOLEAN;
CONST
  fromYear1 = 1916; 
  toYear1   = 1918;
  fromYear2 = 1940;
  toYear2   = 1949;
  fromYear3 = 1979;
  toYear3   = 2002;
TYPE
  TDSTInterval  = RECORD
                    FromDay   : CARDINAL;
                    FromMonth : CARDINAL;
                    FromHour  : CARDINAL;
                    ToDay     : CARDINAL;
                    ToMonth   : CARDINAL;
                    ToHour    : CARDINAL;
                  END;
  TPDSTInterval = POINTER TO TDSTInterval;
  TczBiasTable1 = ARRAY [fromYear1..toYear1] OF TDSTInterval;
  TczBiasTable2 = ARRAY [fromYear2..toYear2] OF TDSTInterval;
  TczBiasTable3 = ARRAY [fromYear3..toYear3] OF TDSTInterval;
CONST
  czBiasTable1 = TczBiasTable1(
    TDSTInterval( 30,  4, 23,  1, 10,  1 ), // 1916
    TDSTInterval( 16,  4,  2, 17,  9,  3 ), // 1917
    TDSTInterval( 15,  4,  2, 16,  9,  3 )  // 1918
  );
  czBiasTable2 = TczBiasTable2(
    TDSTInterval(  1,  4,  2, 31, 12, 24 ), // 1940
    TDSTInterval(  1,  1,  0, 31, 12, 24 ), // 1941
    TDSTInterval(  1,  1,  0,  2, 11,  3 ), // 1942
    TDSTInterval( 29,  3,  2,  4, 10,  3 ), // 1943
    TDSTInterval(  3,  4,  2,  2, 10,  3 ), // 1944
    TDSTInterval(  2,  4,  2,  2, 10,  3 ), // 1945
    TDSTInterval(  6,  5,  2,  7, 10,  2 ), // 1946
    TDSTInterval( 20,  4,  2,  5, 10,  3 ), // 1947
    TDSTInterval( 18,  4,  2,  3, 10,  3 ), // 1948
    TDSTInterval( 10,  4,  2,  2, 10,  3 )  // 1949
  );
  czBiasTable3 = TczBiasTable3(
    TDSTInterval(  1,  4,  0, 30,  9,  1 ), // 1979
    TDSTInterval(  6,  4,  0, 28,  9,  1 ), // 1980
    TDSTInterval( 29,  3,  0, 27,  9,  1 ), // 1981
    TDSTInterval( 28,  3,  0, 26,  9,  1 ), // 1982
    TDSTInterval( 27,  3,  2, 25,  9,  3 ), // 1983
    TDSTInterval( 25,  3,  2, 30,  9,  3 ), // 1984
    TDSTInterval( 31,  3,  2, 29,  9,  3 ), // 1985
    TDSTInterval( 30,  3,  2, 28,  9,  3 ), // 1986
    TDSTInterval( 29,  3,  2, 27,  9,  3 ), // 1987
    TDSTInterval( 27,  3,  2, 25,  9,  3 ), // 1988
    TDSTInterval( 26,  3,  2, 24,  9,  3 ), // 1989
    TDSTInterval( 25,  3,  2, 30,  9,  3 ), // 1990
    TDSTInterval( 31,  3,  2, 29,  9,  3 ), // 1991
    TDSTInterval( 29,  3,  2, 27,  9,  3 ), // 1992
    TDSTInterval( 28,  3,  2, 26,  9,  3 ), // 1993
    TDSTInterval( 27,  3,  2, 25,  9,  3 ), // 1994
    TDSTInterval( 26,  3,  2, 24,  9,  3 ), // 1995
    TDSTInterval( 31,  3,  2, 27, 10,  3 ), // 1996
    TDSTInterval( 30,  3,  2, 26, 10,  3 ), // 1997
    TDSTInterval( 29,  3,  2, 25, 10,  3 ), // 1998
    TDSTInterval( 28,  3,  2, 31, 10,  3 ), // 1999
    TDSTInterval( 26,  3,  2, 29, 10,  3 ), // 2000
    TDSTInterval( 25,  3,  2, 28, 10,  3 ), // 2001
    TDSTInterval( 31,  3,  2, 27, 10,  3 )  // 2002
  );
VAR
  DayOfWeek : CARDINAL;
  Interval  : TDSTInterval;
  JD_       : TJD;
  PInterval : POINTER TO CONST TDSTInterval;
BEGIN
  IF ( DateTime.Year >= fromYear3 ) AND ( DateTime.Year <= toYear3 ) THEN
    PInterval := ADR( czBiasTable3[ DateTime.Year ] );
  ELSIF ( DateTime.Year >= fromYear2 ) AND ( DateTime.Year <= toYear2 ) THEN
    PInterval := ADR( czBiasTable2[ DateTime.Year ] );
  ELSIF ( DateTime.Year >= fromYear1 ) AND ( DateTime.Year <= toYear1 ) THEN
    PInterval := ADR( czBiasTable1[ DateTime.Year ] );
  ELSIF DateTime.Year > toYear3 THEN
    // get last march sunday
    JD_ := JD( INTEGER( DateTime.Year ), 3, 31, 0 );
    DayOfWeek := CARDINAL( ToSJD( JD_ ) + 1.5 ) MOD 7; // 0 is sunday
    Interval.FromDay := 31 - DayOfWeek;
    Interval.FromMonth := 3;
    Interval.FromHour := 2;
    // get last october sunday
    JD_ := JD( INTEGER( DateTime.Year ), 10, 31, 0 );
    DayOfWeek := CARDINAL( ToSJD( JD_ ) + 1.5 ) MOD 7; // 0 is sunday
    Interval.ToDay := 31 - DayOfWeek;
    Interval.ToMonth := 10;
    Interval.ToHour := 2;
    PInterval := ADR( Interval );
  ELSE
    RETURN FALSE;
  END;
  WITH PInterval^ DO
    IF ( DateTime.Month < FromMonth ) OR ( DateTime.Month > ToMonth ) THEN
      RETURN FALSE;
    ELSIF DateTime.Month = FromMonth THEN
      IF DateTime.Day < FromDay THEN
        RETURN FALSE;
      ELSIF DateTime.Day > FromDay THEN
        RETURN TRUE;
      ELSE
        RETURN DateTime.Hour >= FromHour;
      END;
    ELSIF DateTime.Month = ToMonth THEN
      IF DateTime.Day > ToDay THEN
        RETURN FALSE;
      ELSIF DateTime.Day < ToDay THEN
        RETURN TRUE;
      ELSE
        RETURN DateTime.Hour < ToHour;
      END;
    END;
  END;
  RETURN TRUE;
END dstActive;

//==============================================================
// extended formatting helpers

CONST
  formatDelimiters = Strings.WCHARS{ '.', ':', ',', ';', '-', '_', '(', '[', '{', '}', ']', ')', '/', '\' };
TYPE
  TApostropheState = ( astGetFirstApostrophe, astCheckSecondApostrophe );

//--------------------------------------------------------------

VAR
  SNLSCallback : ARRAY [0..63] OF WCHAR;

(*# save, call( convention => stdcall ) *)
PROCEDURE NLSCallback( PStr : PWCHAR ) : windows.BOOL;
BEGIN
  IF PStr = NIL THEN
    SNLSCallback := L'';
  ELSE
    ASSIGN( SNLSCallback, PStr^ );
  END;
  RETURN windows.False;
END NLSCallback;
(*# restore *)

//--------------------------------------------------------------

PROCEDURE StringToDateTime( String, Format : ARRAY OF WCHAR; VAR DateTime : TDateTime ) : BOOLEAN;
BEGIN
   RETURN StringToDateTimeLang( Languages.GetDefaultLanguage( Languages.dlUser ), String, Format, DateTime );
END StringToDateTime;

//--------------------------------------------------------------

PROCEDURE StringToDateTimeLang( Language : Languages.TLanguage; String, Format : ARRAY OF WCHAR; VAR DateTime : TDateTime ) : BOOLEAN;
  // returns FALSE if String does not match Format
TYPE
  TExpectInString = (
    eisStop, // special meaning
    eisError,        eisBlank,          eisLiteral,      eisDelimiter,
    eisDayDigit,     eisDayDigitLZ,     eisDayAbbr,      eisDayName,
    eisMonthDigit,   eisMonthDigitLZ,   eisMonthAbbr,    eisMonthName,
    eisYearTwoDigit, eisYearTwoDigitLZ, eisYearFourDigit,
    eisEra,
    eisFractionD,    eisFractionC,      eisFractionM,    // deci, centi, milli
    eisSecondDigit,  eisSecondDigitLZ,
    eisMinuteDigit,  eisMinuteDigitLZ,
    eisHour12,       eisHour12LZ,       eisHour24,       eisHour24LZ,
    eisAMPMShort,    eisAMPM
  );
  TLeadings = (
    leadDay, leadMonth, leadYear,
    leadEra,
    leadFraction, leadSecond, leadMinute, leadHour12, leadHour24,
    leadAMPM,
    leadSpace, leadLiteral, leadDelimiter
  );
  TLeadingsOccurencesToExpect = ARRAY [0..4] OF TExpectInString;
  TLeadingsToExpect = ARRAY TLeadings OF TLeadingsOccurencesToExpect;
CONST
  leadingsToExpect = TLeadingsToExpect(
    TLeadingsOccurencesToExpect( eisDayDigit, eisDayDigitLZ, eisDayAbbr, eisDayName, eisStop ), // leadDay
    TLeadingsOccurencesToExpect( eisMonthDigit, eisMonthDigitLZ, eisMonthAbbr, eisMonthName, eisStop ), // leadMonth
    TLeadingsOccurencesToExpect( eisYearTwoDigit, eisYearTwoDigitLZ, eisError, eisYearFourDigit, eisStop ), // leadYear
    TLeadingsOccurencesToExpect( eisError, eisEra, eisStop, eisError, eisError ), // leadEra
    TLeadingsOccurencesToExpect( eisFractionD, eisFractionC, eisFractionM, eisStop, eisError ), // leadFraction
    TLeadingsOccurencesToExpect( eisSecondDigit, eisSecondDigitLZ, eisStop, eisError, eisError ), // leadSecond
    TLeadingsOccurencesToExpect( eisMinuteDigit, eisMinuteDigitLZ, eisStop, eisError, eisError ), // leadMinute
    TLeadingsOccurencesToExpect( eisHour12, eisHour12LZ, eisStop, eisError, eisError ), // leadHour12
    TLeadingsOccurencesToExpect( eisHour24, eisHour24LZ, eisStop, eisError, eisError ), // leadHour24
    TLeadingsOccurencesToExpect( eisAMPMShort, eisAMPM, eisStop, eisError, eisError ), // leadAMPM
    TLeadingsOccurencesToExpect( eisBlank, eisStop, eisError, eisError, eisError ), // leadSpace
    TLeadingsOccurencesToExpect( eisLiteral, eisStop, eisError, eisError, eisError ), // leadLiteral
    TLeadingsOccurencesToExpect( eisStop, eisError, eisError, eisError, eisError ) // leadDelimiter, this case is irregular and Expect is assigned directly
  );
CONST // leading characters
  charDay      = W'd';
  charMonth    = W'M';
  charYear     = W'y';
  charEra      = W'g';
  charSecond   = W's';
  charFraction = W'f';
  charMinute   = W'm';
  charHour12   = W'h';
  charHour24   = W'H';
  charAMPM     = W't';
  charSpace    = W' ';
  charLiteral  = W"'";
  charEmpty    = 0W;
  charTab      = 9W;
TYPE
  TLeadingCharacters = ARRAY TLeadings OF WCHAR;
CONST
  leadingCharacters = TLeadingCharacters(
    charDay, charMonth, charYear,
    charEra,
    charFraction, charSecond, charMinute, charHour12, charHour24,
    charAMPM,
    charSpace, charLiteral, charEmpty
  );
TYPE
  TMinimalStringLen = ARRAY TExpectInString OF CARDINAL;
CONST
  minimalStringLen = TMinimalStringLen(
    0, // eisStop
    0, 1, 2, 1, // eisError, eisBlank, eisLiteral, eisDelimiter
    1, 2, 3, 3, // eisDayDigit, eisDayDigitLZ, eisDayAbbr, eisDayName,
    1, 2, 3, 3, // eisMonthDigit, eisMonthDigitLZ, eisMonthAbbr, eisMonthName,
    1, 2, 4, // eisYearTwoDigit, eisYearTwoDigitLZ, eisYearFourDigit,
    2, // eisEra,
    1, 2, 3, // eisFractionD, eisFractionC, eisFractionM,
    1, 2, // eisSecondDigit, eisSecondDigitLZ,
    1, 2, // eisMinuteDigit, eisMinuteDigitLZ,
    1, 2, 1, 2, // eisHour12, eisHour12LZ, eisHour24, eisHour24LZ,
    1, 2 // eisAMPMShort, eisAMPM
  );
TYPE
  TExpect2NLS = ARRAY [0..13] OF CARDINAL;
CONST
  expect2NLSMonthAbbr = TExpect2NLS(
    winnls.CAL_SABBREVMONTHNAME1,
    winnls.CAL_SABBREVMONTHNAME2,
    winnls.CAL_SABBREVMONTHNAME3,
    winnls.CAL_SABBREVMONTHNAME4,
    winnls.CAL_SABBREVMONTHNAME5,
    winnls.CAL_SABBREVMONTHNAME6,
    winnls.CAL_SABBREVMONTHNAME7,
    winnls.CAL_SABBREVMONTHNAME8,
    winnls.CAL_SABBREVMONTHNAME9,
    winnls.CAL_SABBREVMONTHNAME10,
    winnls.CAL_SABBREVMONTHNAME11,
    winnls.CAL_SABBREVMONTHNAME12,
    winnls.CAL_SABBREVMONTHNAME13,
    0
  );
  expect2NLSMonthName = TExpect2NLS(
    winnls.CAL_SMONTHNAME1,
    winnls.CAL_SMONTHNAME2,
    winnls.CAL_SMONTHNAME3,
    winnls.CAL_SMONTHNAME4,
    winnls.CAL_SMONTHNAME5,
    winnls.CAL_SMONTHNAME6,
    winnls.CAL_SMONTHNAME7,
    winnls.CAL_SMONTHNAME8,
    winnls.CAL_SMONTHNAME9,
    winnls.CAL_SMONTHNAME10,
    winnls.CAL_SMONTHNAME11,
    winnls.CAL_SMONTHNAME12,
    winnls.CAL_SMONTHNAME13,
    0
  );

//----------

  PROCEDURE FillDateTime( VAR DateTime : TDateTime; Expect : TExpectInString; n : CARDINAL );
  BEGIN
    CASE Expect OF
    | eisDayDigit, eisDayDigitLZ :
      DateTime.Day := n;
    | eisMonthDigit, eisMonthDigitLZ, eisMonthAbbr, eisMonthName :
      DateTime.Month := n;
    | eisYearTwoDigit, eisYearTwoDigitLZ, eisYearFourDigit :
      DateTime.Year := n;
    | eisFractionD :
      DateTime.Millisecond := 100 * n;
    | eisFractionC :
      DateTime.Millisecond := 10 * n;
    | eisFractionM :
      DateTime.Millisecond := n;
    | eisSecondDigit, eisSecondDigitLZ :
      DateTime.Second := n;
    | eisMinuteDigit, eisMinuteDigitLZ :
      DateTime.Minute := n;
    | eisHour12, eisHour12LZ :
      DateTime.Hour := n;
    | eisHour24, eisHour24LZ :
      DateTime.Hour := n;
    END; // CASE
  END FillDateTime;

//----------

  PROCEDURE ConvertStringItem( Expect : TExpectInString; S : ARRAY OF TCHAR; VAR LocalDateTime : TDateTime );
  VAR
    i : CARDINAL;
    PE2NLS : POINTER TO CONST TExpect2NLS;
  BEGIN
    CASE Expect OF
    | eisEra, eisDayAbbr, eisDayName : RETURN;
    | eisMonthAbbr : PE2NLS := ADR( expect2NLSMonthAbbr ); 
    | eisMonthName : PE2NLS := ADR( expect2NLSMonthName ); 
    END;
    i := 0;
    WHILE PE2NLS^[i] <> 0 DO
      winnls.EnumCalendarInfo( winnls.CALINFO_ENUMPROC( NLSCallback ), Language, winnls.ENUM_ALL_CALENDARS, PE2NLS^[i] );
      IF Strings.EqualsIgnoreCaseW( SNLSCallback, S ) THEN
        FillDateTime( LocalDateTime, Expect, i + 1 );
        RETURN;
      END;
      INC( i );
    END; // WHILE
  END ConvertStringItem;

//----------

LABEL
  CheckEnd;
VAR
  Delimiter : TCHAR;
  Expect : TExpectInString;
  fi : CARDINAL;
  i : CARDINAL;
  Leading : TLeadings;
  LocalDateTime : TDateTime;
  n : CARDINAL;
  S : ARRAY [0..63] OF WCHAR;
  si : CARDINAL;
  PMFlag : BOOLEAN;
  TwelveFlag : BOOLEAN;
BEGIN
  IF ( HIGH( String ) = -1 ) OR ( ADR( String ) = NIL ) THEN
    RETURN FALSE;
  END;

  fi := 0;
  si := 0;
  PMFlag := FALSE;
  TwelveFlag := FALSE;
  InitDateTime( OUT LocalDateTime );

  LOOP
    IF ( si > HIGH( String )) OR ( String[0] = 0W ) THEN
    CheckEnd:
      IF ( fi+1 > HIGH( Format )) OR // limit check
         ( Format[fi] = WCHAR( 0 )) OR // regular end
         ( Format[fi+1] = WCHAR( 0 )) THEN // GOTOed end
        EXIT;
      ELSE
        RETURN FALSE;
      END;
    ELSIF ( fi > HIGH( Format )) OR ( Format[fi] = WCHAR( 0 )) THEN
      EXIT;
    END; // IF inside Format

    // detect format piece
    CASE Format[fi] OF
    | charDay      : Leading := leadDay;
    | charMonth    : Leading := leadMonth;
    | charYear     : Leading := leadYear;
    | charEra      : Leading := leadEra;
    | charFraction : Leading := leadFraction;
    | charSecond   : Leading := leadSecond;
    | charMinute   : Leading := leadMinute;
    | charHour12   : Leading := leadHour12;
    | charHour24   : Leading := leadHour24;
    | charAMPM     : Leading := leadAMPM;
    | charSpace    : Leading := leadSpace;
    | charLiteral  : Leading := leadLiteral;
    ELSE // try delimiter
      IF Format[fi] IN formatDelimiters THEN
        Delimiter := Format[fi];
      ELSE
        Delimiter := 0W;
      END;
      Leading := leadDelimiter;
    END; // CASE

    // detect range of piece
    IF Leading = leadDelimiter THEN
      Expect := eisDelimiter;
      INC( fi );
    ELSE
      i := 0;
      Expect := eisError;
      LOOP
        IF leadingsToExpect[Leading][i] = eisStop THEN
          EXIT;
        ELSIF ( fi > HIGH( Format )) OR ( Format[0] = WCHAR( 0 )) THEN
          EXIT;
        ELSIF Format[fi] = leadingCharacters[Leading] THEN
          Expect := leadingsToExpect[Leading][i];
          INC( fi );
          INC( i );
        ELSE
          EXIT;
        END;
      END; // loop over leading characters
    END;

    // check is String contains required characters
    i := si + minimalStringLen[Expect] - 1; // si now points to the first unprocessed character
    IF ( i > HIGH( String )) OR ( String[0] = WCHAR( 0 )) THEN
      RETURN FALSE;
    END;

    // try accept expected data
    CASE Expect OF
    | eisError :
      RETURN FALSE;
    
    | eisBlank :
      LOOP
        IF ( String[si] = ' ' ) OR ( String[si] = charTab ) THEN // Space or Tab
          INC( si )
        ELSE
          EXIT;
        END;
        IF ( si > HIGH( String )) OR ( String[0] = WCHAR( 0 )) THEN
          GOTO CheckEnd;
        END;
      END; // LOOP over blanks
    
    | eisDayDigit, eisMonthDigit, eisYearTwoDigit,
      eisSecondDigit, eisMinuteDigit,
      eisHour12, eisHour24 :
      CASE String[si] OF
      | '0' :
        IF ( Expect = eisDayDigit ) OR ( Expect = eisMonthDigit ) THEN
          // these cannot start with 0
          RETURN FALSE;
        END;
      | '1'..'9' :
        // pass down
      ELSE
        RETURN FALSE;
      END;
      n := ORD( String[si] ) - ORD( '0' );
      INC( si );
      IF ( si > HIGH( String )) OR ( String[0] = WCHAR( 0 )) THEN
        FillDateTime( LocalDateTime, Expect, n );
        GOTO CheckEnd;
      END;
      CASE String[si] OF
      | L'0'..L'9' :
        n := n * 10 + ORD( String[si] ) - ORD( '0' );
        INC( si );
      // ELSE not accepted, not incremented
      END;
      FillDateTime( LocalDateTime, Expect, n );

    | eisDayDigitLZ, eisMonthDigitLZ, eisYearTwoDigitLZ,
      eisSecondDigitLZ, eisMinuteDigitLZ, eisHour12LZ, eisHour24LZ :
      n := 0;
      FOR i := 0 TO 1 DO
        CASE String[si] OF
        | '0'..'9' :
          n := n * 10 + ORD( String[si] ) - ORD( '0' );
        ELSE
          RETURN FALSE;
        END; // case of first digit
        INC( si );
      END; // two digits
      FillDateTime( LocalDateTime, Expect, n );

    // | eisDayAbbr, eisMonthAbbr : // blindly skip
    //   INC( si, 3 );
    // czech has 'V' for May and 'po' for Monday, they are NOT three characters length...

    | eisDayAbbr, eisMonthAbbr, // joined from above
      eisDayName, eisMonthName, eisEra : // blindly skip
      S[0] := 0W;
      i := 0;
      LOOP
        CASE String[si] OF
        | charTab, ' ',
          TCHAR(  33 )..'9', // delimiters, 0..9
          TCHAR(  91 )..TCHAR(  95 ), // delimiters between Z..a
          TCHAR( 123 )..TCHAR( 127 ) : // delimiters after Z..z
          S[i] := 0W;
          ConvertStringItem( Expect, S, LocalDateTime );
          EXIT;
        ELSE
          S[i] := String[si];
          INC( i );
          INC( si )
        END; // CASE of accepted characters
        IF ( si > HIGH( String )) OR ( String[0] = WCHAR( 0 )) THEN
          S[i] := 0W;
          ConvertStringItem( Expect, S, LocalDateTime );
          GOTO CheckEnd;
        END;
      END; // LOOP over blanks

    | eisFractionD, eisFractionC, eisFractionM :
      n := 0;
      FOR i := 0 TO CARDINAL( Expect ) - CARDINAL( eisFractionD ) DO
        CASE String[si] OF
        | '0'..'9' :
          n := n * 10 + ORD( String[si] ) - ORD( '0' );
        ELSE
          RETURN FALSE;
        END; // case of first digit
        INC( si );
      END; // four digits
      FillDateTime( LocalDateTime, Expect, n );

    | eisYearFourDigit :
      n := 0;
      FOR i := 0 TO 3 DO
        CASE String[si] OF
        | '0'..'9' :
          n := n * 10 + ORD( String[si] ) - ORD( '0' );
        ELSE
          RETURN FALSE;
        END; // case of first digit
        INC( si );
      END; // four digits
      FillDateTime( LocalDateTime, Expect, n );

    | eisAMPMShort, eisAMPM :
      CASE String[si] OF
      | 'A' :
      | 'P' : 
        PMFlag := TRUE;
      ELSE
        RETURN FALSE;
      END; // CASE
      IF Expect = eisAMPMShort THEN
        INC( si );
      ELSE
        INC( si, 2 );
      END;

    | eisLiteral : // match against literal
      LOOP
        IF Format[fi] = "'" THEN
          INC( fi );
          EXIT;
        END;
        IF Format[fi] = String[si] THEN
          INC( fi );
          INC( si );
        ELSE
          RETURN FALSE;
        END;
        IF ( fi > HIGH( Format )) OR ( Format[0] = WCHAR( 0 )) THEN
          RETURN FALSE;
        END;
        IF ( si > HIGH( String )) OR ( String[0] = WCHAR( 0 )) THEN
          GOTO CheckEnd;
        END;
      END; // LOOP over blanks

    | eisDelimiter : // match single character
      IF String[si] = Delimiter THEN
        INC( si );
      ELSE
        RETURN FALSE;
      END;

    END; // CASE of Expect

    CASE Expect OF
    | eisHour12, eisHour12LZ :
      TwelveFlag := TRUE;
    | eisHour24, eisHour24LZ :
      TwelveFlag := FALSE;
    END; // Expect

  END; // LOOP

  IF PMFlag AND TwelveFlag AND ( LocalDateTime.Hour > 0 ) AND ( LocalDateTime.Hour < 13 ) THEN
    INC( LocalDateTime.Hour, 12 );
  END;
  DateTime := LocalDateTime;
  RETURN TRUE;
END StringToDateTimeLang;

//--------------------------------------------------------------

PROCEDURE PrepareSingleFormattedString( Format : ARRAY OF WCHAR; VAR Result : ARRAY OF WCHAR; VAR HaveFraction : BOOLEAN );
LABEL
  Prepared;
VAR
  ApostropheState : TApostropheState;
  di : CARDINAL;
  si : CARDINAL;
  PrecedingLiteral : BOOLEAN;
BEGIN
  HaveFraction := FALSE;
  PrecedingLiteral := FALSE;
  si := 0;
  di := 0;
  LOOP
    IF ( si > HIGH( Format )) OR ( Format[si] = WCHAR( 0 )) OR ( di + 3 > HIGH( Result )) THEN
    Prepared:
      Result[di] := 0W;
      EXIT;
    ELSIF Format[si] = L"'" THEN // opening apostrophe
      // enter literal
      IF PrecedingLiteral THEN
        DEC( di );
      ELSE
        Result[di] := L"'"; // opening apostrophe
        INC( di );
      END;

      ApostropheState := astGetFirstApostrophe;
      LOOP
        INC( si );
        IF ( si > HIGH( Format )) OR ( Format[si] = WCHAR( 0 )) OR (( di + 2 ) > HIGH( Result )) THEN
          GOTO Prepared;
        END;
        CASE ApostropheState OF
        | astGetFirstApostrophe :
          IF Format[si] = L"'" THEN
            ApostropheState := astCheckSecondApostrophe;
          ELSE
            Result[di] := Format[si];
            INC( di );
          END;
        | astCheckSecondApostrophe :
          IF Format[si] = L"'" THEN // escaped apostrophe found, double it --
            Result[di] := L"'"; // -- escaped apostrophe
            INC( di );
            ApostropheState := astGetFirstApostrophe;
          ELSE // literal terminated
            DEC( si );
            EXIT; // LOOP
          END;
        END;
      END; // LOOP
      // leave literal
      Result[di] := L"'"; // escape for resulting apostrophe --
      INC( di );

      PrecedingLiteral := TRUE;

    ELSIF Format[si] IN formatDelimiters THEN
      // simple delimiter must be enclosed into apostrophes explicitely
      IF PrecedingLiteral THEN
        DEC( di );
      ELSE
        Result[di] := L"'"; // escape for resulting apostrophe --
        INC( di );
      END;
      Result[di] := Format[si]; // -- escaped apostrophe
      Result[di+1] := L"'"; // -- escaped apostrophe
      INC( di, 2 );

      PrecedingLiteral := TRUE;

    ELSE
      Result[di] := Format[si];
      HaveFraction := HaveFraction OR ( Result[di] = 'f' ) OR ( Result[di] = 'F' );
      INC( di );

      PrecedingLiteral := FALSE;
    END;
    INC( si );
  END;
END PrepareSingleFormattedString;

//--------------------------------------------------------------

PROCEDURE PrepareTwiceFormattedStringProtectDate( Format : ARRAY OF WCHAR; VAR Result : ARRAY OF WCHAR; VAR HaveFraction : BOOLEAN );
VAR
  ApostropheState : TApostropheState;
  di : CARDINAL;
  si : CARDINAL;
  PrecedingLiteral : BOOLEAN;
BEGIN
  HaveFraction := FALSE;
  PrecedingLiteral := FALSE;
  si := 0;
  di := 0;
  LOOP
    IF ( si > HIGH( Format )) OR ( Format[si] = WCHAR( 0 )) OR ( di + 9 > HIGH( Result )) THEN
      Result[di] := 0W;
      EXIT;
    ELSIF Format[si] = L"'" THEN // opening apostrophe
      // enter literal
      IF PrecedingLiteral THEN
        DEC( di, 2 );
      END;
      Result[di  ] := L"'"; // opening apostrophe
      Result[di+1] := L"'"; // escape for resulting apostrophe --
      Result[di+2] := L"'"; // -- escaped apostrophe
      INC( di, 3 );

      ApostropheState := astGetFirstApostrophe;
      LOOP
        INC( si );
        IF ( si > HIGH( Format )) OR ( Format[si] = WCHAR( 0 )) OR (( di + 5 ) > HIGH( Result )) THEN
          EXIT;
        END;
        CASE ApostropheState OF
        | astGetFirstApostrophe :
          IF Format[si] = L"'" THEN
            ApostropheState := astCheckSecondApostrophe;
          ELSE
            Result[di] := Format[si];
            INC( di );
          END;
        | astCheckSecondApostrophe :
          IF Format[si] = L"'" THEN // escaped apostrophe found, double it
            Result[di  ] := L"'"; // escape for resulting apostrophe --
            Result[di+1] := L"'"; // -- escaped apostrophe
            Result[di+2] := L"'"; // escape for resulting apostrophe --
            Result[di+3] := L"'"; // -- escaped apostrophe
            INC( di, 4 );
            ApostropheState := astGetFirstApostrophe;
          ELSE // literal terminated
            DEC( si );
            EXIT; // LOOP
          END;
        END;
      END; // LOOP
      // leave literal
      Result[di  ] := L"'"; // escape for resulting apostrophe --
      Result[di+1] := L"'"; // -- escaped apostrophe
      Result[di+2] := L"'"; // closing apostrophe
      INC( di, 3 );

      PrecedingLiteral := TRUE;

    ELSIF Format[si] IN formatDelimiters THEN
      // simple delimiter must be enclosed into apostrophes explicitely
      IF PrecedingLiteral THEN
        DEC( di, 2 );
      END;

      Result[di  ] := L"'"; // escape for resulting apostrophe --
      Result[di+1] := L"'"; // -- escaped apostrophe
      Result[di+2] := L"'"; // escape for resulting apostrophe --
      Result[di+3] := L"'"; // -- escaped apostrophe
      Result[di+4] := Format[si]; // -- escaped apostrophe
      Result[di+5] := L"'"; // escape for resulting apostrophe --
      Result[di+6] := L"'"; // -- escaped apostrophe
      Result[di+7] := L"'"; // escape for resulting apostrophe --
      Result[di+8] := L"'"; // -- escaped apostrophe
      INC( di, 9 );

      PrecedingLiteral := TRUE;

    ELSIF Format[si] IN Strings.WCHARS{L'd', L'M', L'y', L'g'} THEN // date format characters
      // wrap date to protect it
      Result[di  ] := L" ";
      Result[di+1] := L"'";
      Result[di+2] := WCHAR( 1 );
      Result[di+3] := Format[si];
      Result[di+4] := WCHAR( 1 );
      Result[di+5] := L"'";
      Result[di+6] := L" ";
      INC( di, 7 );

      PrecedingLiteral := FALSE;
    ELSE
      Result[di] := Format[si];
      HaveFraction := HaveFraction OR ( Result[di] = L'f' ) OR ( Result[di] = L'F' );
      INC( di );

      PrecedingLiteral := FALSE;
    END;
    INC( si );
  END;
END PrepareTwiceFormattedStringProtectDate;

//--------------------------------------------------------------

PROCEDURE UnwrapDateProtection( CONST Wrapped : ARRAY OF TCHAR; VAR Unwrapped : ARRAY OF TCHAR );
TYPE
  TLS = ARRAY [0..4095] OF TCHAR;
VAR
  di : CARDINAL;
  si : CARDINAL;
  UW : TLS;
BEGIN
  si := 0;
  di := 0;
  LOOP
    IF ( Wrapped[si] = 0W ) OR ( si + 5 > HIGH( Wrapped )) OR ( di + 1 >= SIZE( UW ) DIV SIZE( TCHAR )) THEN
      UW[di] := 0W;
      EXIT;
    ELSIF ( Wrapped[si  ] = WCHAR( 1 )) AND
          ( Wrapped[si+1] IN Strings.WCHARS{L'd', L'M', L'y', L'g'} ) AND
          ( Wrapped[si+2] = WCHAR( 1 )) AND
          ( Wrapped[si+3] = L' ' ) THEN
      DEC( di );
      IF UW[di-1] = WCHAR( 1 ) THEN
        DEC( di );
      ELSE
        UW[di] := WCHAR( 1 );
        INC( di );
      END;
      UW[di] := Wrapped[si+1];
      UW[di+1] := WCHAR( 1 );
      INC( di, 2 );
      INC( si, 4 );
    ELSIF Wrapped[si] = "'" THEN
      INC( si );
    ELSE
      UW[di] := Wrapped[si];
      INC( si );
      INC( di );
    END;
  END;
  si := 0;
  di := 0;
  LOOP
    IF ( UW[si] = 0W ) OR ( di + 2 >= HIGH( Unwrapped )) THEN
      IF di = 0 THEN
        Unwrapped[di] := 0W;
      ELSIF Unwrapped[di-1] = L"'" THEN
        Unwrapped[di-1] := 0W;
      ELSE
        Unwrapped[di] := L"'";
        Unwrapped[di+1] := 0W;
      END;
      EXIT;
    END;
    IF UW[si] = WCHAR( 1 ) THEN
      INC( si );
      IF di > 0 THEN
        Unwrapped[di] := L"'";
        INC( di );
      END;
      LOOP
        IF UW[si] = WCHAR( 1 ) THEN
          Unwrapped[di] := L"'";
          INC( si );
          INC( di );
          EXIT;
        ELSE
          Unwrapped[di] := UW[si];
          INC( si );
          INC( di );
        END;
      END; // LOOP
    ELSIF di = 0 THEN
      Unwrapped[di] := L"'";
      INC( di );
    ELSE
      Unwrapped[di] := UW[si];
      INC( si );
      INC( di );
    END;
  END;
END UnwrapDateProtection;

//--------------------------------------------------------------

PROCEDURE DateTimeToString( CONST DateTime : TDateTime;
                                    Format : ARRAY OF WCHAR;
                                FormatDate : BOOLEAN;
                                FormatTime : BOOLEAN;
                                VAR String : ARRAY OF WCHAR ) : BOOLEAN;
BEGIN
   RETURN DateTimeToStringLang( Languages.GetDefaultLanguage( Languages.dlUser ), DateTime, Format, FormatDate, FormatTime, String );
END DateTimeToString;

//--------------------------------------------------------------

PROCEDURE DateTimeToStringLang( Language : Languages.TLanguage;
                      CONST DateTime : TDateTime;
                              Format : ARRAY OF WCHAR;
                          FormatDate : BOOLEAN;
                          FormatTime : BOOLEAN;
                          VAR String : ARRAY OF WCHAR ) : BOOLEAN;
TYPE
  TLS = ARRAY [0..4095] OF WCHAR;
  TPLS = POINTER TO TLS;
VAR
  i, l : CARDINAL;
  Intermediate : TLS;
  PPrepared : TPLS;
  Prepared : TLS;
  st : windows.SYSTEMTIME;
  HaveFraction : BOOLEAN;
  FFlag : BOOLEAN;
BEGIN
  // inlined DateTimeToSystemTime( DateTime, OUT st ):
  st.wYear := WORD( MAX2( 1601, DateTime.Year ));
  st.wMonth := WORD( DateTime.Month );
  st.wDay := WORD( DateTime.Day );
  st.wHour := WORD( DateTime.Hour );
  st.wMinute := WORD( DateTime.Minute );
  st.wSecond := WORD( DateTime.Second );
  st.wMilliseconds := WORD( DateTime.Millisecond );
  st.wDayOfWeek := 0;

  IF FormatDate AND FormatTime THEN
    IF Format[0] = WCHAR( 0 ) THEN
      PPrepared := NIL;
      IF ( winnls.GetDateFormatW( Language, 0, ADR( st ), PPrepared, ADR( String ),       HIGH( String )) = 0 ) OR
         ( winnls.GetTimeFormatW( Language, 0, ADR( st ), PPrepared, ADR( Intermediate ), SIZE( Intermediate ) >> 1 ) = 0 ) THEN
        RETURN FALSE;
      END;
      Strings.AppendW( REF String, L' ' );
      Strings.AppendW( REF String, Intermediate );
    ELSE
      PrepareTwiceFormattedStringProtectDate( Format, Prepared, HaveFraction );
      IF winnls.GetTimeFormatW( Language, 0, ADR( st ), ADR( Prepared ), ADR( Intermediate ), SIZE( Intermediate ) >> 1 ) = 0 THEN
        RETURN FALSE;
      END;
      UnwrapDateProtection( Intermediate, Prepared );
      IF winnls.GetDateFormatW( Language, 0, ADR( st ), ADR( Prepared ), ADR( String ), HIGH( String )) = 0 THEN
        RETURN FALSE;
      END;
    END;
  ELSE
    IF Format[0] = WCHAR( 0 ) THEN
      PPrepared := NIL;
    ELSE
      PPrepared := ADR( Prepared );
      PrepareSingleFormattedString( Format, Prepared, HaveFraction );
    END;
       IF FormatDate AND
          ( winnls.GetDateFormatW( Language, 0, ADR( st ), PPrepared, ADR( String ), HIGH( String )) = 0 ) THEN
      RETURN FALSE;
    ELSIF FormatTime AND
          ( winnls.GetTimeFormatW( Language, 0, ADR( st ), PPrepared, ADR( String ), HIGH( String )) = 0 ) THEN
      RETURN FALSE;
    END;
  END;
  IF NOT HaveFraction THEN
    RETURN TRUE;
  END;

  // expand and format 'f', 'ff', and 'fff' for fraction of second
  i := 0;
  l := LENGTH( String );
  LOOP
    IF i >= l THEN
      EXIT;
    END;
    CASE String[i] OF
    | L"'" :
      // skip literal
      WHILE ( i < l ) AND ( String[i] <> L"'" ) DO
        INC( i );
      END;
      IF i = l THEN
        EXIT;
      END;
    | L'"' :
      // skip another literal
      WHILE ( i < l ) AND ( String[i] <> L'"' ) DO
        INC( i );
      END;
      IF i = l THEN
        EXIT;
      END;
    | 'f', 'F' :
      FFlag := String[i] = L'F';
      String[i] := WCHAR( ORD( L'0' ) + DateTime.Millisecond DIV 100 );
      INC( i );
      IF i = l THEN
        IF FFlag AND ( DateTime.Millisecond MOD 100 > 50 ) THEN
          INC( String[i-1] );
        END;
        EXIT;
      ELSIF ( String[i] <> L'f' ) AND ( String[i] <> L'F' ) THEN
        IF FFlag AND ( DateTime.Millisecond MOD 100 > 50 ) THEN
          INC( String[i] );
        END;
        DEC( i );
      ELSE
        FFlag := String[i] = L'F';
        String[i] := TCHAR( ORD( L'0' ) + ( DateTime.Millisecond DIV 10 ) MOD 10 );
        INC( i );
        IF i = l THEN
          IF FFlag AND ( DateTime.Millisecond MOD 100 > 50 ) THEN
            INC( String[i-1] );
          END;
          EXIT;
        ELSIF ( String[i] <> L'f' ) AND ( String[i] <> L'F' ) THEN
          IF FFlag AND ( DateTime.Millisecond MOD 10 > 5 ) THEN
            INC( String[i] );
          END;
          DEC( i );
        ELSE
          String[i] := WCHAR( ORD( L'0' ) + DateTime.Millisecond MOD 10 );
        END;
      END;
    END; // CASE
    INC( i );
  END; // LOOP

  RETURN TRUE;
END DateTimeToStringLang;

//==============================================================

INITIALLY __I();
BEGIN
  LastTicks := 0;
  LastTimeMS64 := 0;
  TimeLock.Init( Sync.ltSpin, L"", FALSE );
  InitHiResTimer();
  //----
  IF windows.GetTimeZoneInformation( ADR( ZoneInfo.SystemZoneInfo )) = windows.TIME_ZONE_ID_DAYLIGHT THEN
    ZoneInfo.DSTBias := INTEGER( ZoneInfo.SystemZoneInfo.DaylightBias );
  ELSE
    ZoneInfo.DSTBias := 0; // if daylight time is not active the bias should (for CW) be 0
  END;
  ZoneInfo.UTCDSTBias := INTEGER( ZoneInfo.SystemZoneInfo.Bias ) + ZoneInfo.DSTBias;
END __I;

//==============================================================

END Time.
