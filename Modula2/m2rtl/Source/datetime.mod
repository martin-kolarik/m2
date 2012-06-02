IMPLEMENTATION MODULE datetime;

(*================================================================================================*)

FROM Debug IMPORT
   AssertionW;

IMPORT
   windows,
   winnls;
  
IMPORT
   Storage,
   Strings,
   Sync;

(*================================================================================================*)

PROCEDURE UptimeMS32() : CARD32;
BEGIN
   RETURN CARD32( windows.GetTickCount());
END UptimeMS32;

(*------------------------------------------------------------------------------------------------*)

VAR
   LastTicks32 : CARD32 := 0;
   LastTimeMS64 : CARD64 := 0;
   TimeLock : Sync.LOCK;

PROCEDURE UptimeMS64() : CARD64;  // returns time from system startup in ms
VAR
   ticks32 : CARD32;
BEGIN
   TimeLock.Lock();
   ticks32 := UptimeMS32();
   INC( LastTimeMS64, ticks32 - LastTicks32 );
   LastTicks32 := ticks32;
   TimeLock.Unlock();
   RETURN LastTimeMS64;
END UptimeMS64;

(*------------------------------------------------------------------------------------------------*)

PROCEDURE UptimeMS16() : CARD16; // overflows each 65 seconds
BEGIN
   RETURN CARD16( UptimeMS());
END UptimeMS16;

(*================================================================================================*)
// time span

CLASS IMPLEMENTATION TimeSpan; // unit is 100 ns, CANNNOT be negative

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Precision GET : CARD64; // hertz
   BEGIN
      RETURN 1000 * 1000 * 10;
   END Precision;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Negative GET : BOOLEAN;
   BEGIN
      RETURN _Value < 0;
   END Negative;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Value GET : INT64; // raw value, e.g. for transport purposes
   BEGIN
      RETURN _Value;
   END Value;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Value SET( _Value : INT64 ); // raw value, e.g. for transport purposes
   BEGIN
      SELF._Value := _Value;
   END Value;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Microseconds GET : LONGREAL;
   BEGIN
      RETURN LONGREAL( _Value ) / 10.0;
   END Microseconds;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Microseconds SET( Value : LONGREAL );
   BEGIN
      IF Value = 0.0 THEN
         _Value := 0;
      ELSIF Value > 0.0 THEN
         _Value := INT64( Value * 10.0 + 0.5 );
      ELSE
         _Value := INT64( Value * 10.0 - 0.5 );
      END;
   END Microseconds;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Milliseconds GET : LONGREAL;
   BEGIN
      RETURN LONGREAL( _Value ) / 10000.0;
   END Milliseconds;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Milliseconds SET( Value : LONGREAL );
   BEGIN
      IF Value = 0.0 THEN
         _Value := 0;
      ELSIF Value > 0.0 THEN
         _Value := INT64( Value * 10000.0 + 0.5 );
      ELSE
         _Value := INT64( Value * 10000.0 - 0.5 );
      END;
   END Milliseconds;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Seconds GET : LONGREAL;
   BEGIN
      RETURN LONGREAL( _Value ) / 10000000.0;
   END Seconds;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Seconds SET( Value : LONGREAL );
   BEGIN
      IF Value = 0.0 THEN
         _Value := 0;
      ELSIF Value > 0.0 THEN
         _Value := INT64( Value * 10000000.0 + 0.5 );
      ELSE
         _Value := INT64( Value * 10000000.0 - 0.5 );
      END;
   END Seconds;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Minutes GET : LONGREAL;
   BEGIN
      RETURN LONGREAL( _Value ) / 600000000.0;
   END Minutes;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Minutes SET( Value : LONGREAL );
   BEGIN
      IF Value = 0.0 THEN
         _Value := 0;
      ELSIF Value > 0.0 THEN
         _Value := INT64( Value * 600000000.0 + 0.5 );
      ELSE
         _Value := INT64( Value * 600000000.0 - 0.5 );
      END;
   END Minutes;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Hours GET : LONGREAL;
   BEGIN
      RETURN LONGREAL( _Value ) / 36000000000.0;
   END Hours;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Hours SET( Value : LONGREAL );
   BEGIN
      IF Value = 0.0 THEN
         _Value := 0;
      ELSIF Value > 0.0 THEN
         _Value := INT64( Value * 36000000000.0 + 0.5 );
      ELSE
         _Value := INT64( Value * 36000000000.0 - 0.5 );
      END;
   END Hours;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Days GET : LONGREAL; // usable for a fraction of the day too, of course
   BEGIN
      RETURN LONGREAL( _Value ) / 864000000000.0;
   END Days;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Days SET( Value : LONGREAL );
   BEGIN
      IF Value = 0.0 THEN
         _Value := 0;
      ELSIF Value > 0.0 THEN
         _Value := INT64( Value * 864000000000.0 + 0.5 );
      ELSE
         _Value := INT64( Value * 864000000000.0 - 0.5 );
      END;
   END Days;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC INLINE OPERATOR :=( CONST Source : TimeSpan );
   BEGIN
      _Value := Source._Value;
   END :=;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC OPERATOR =( CONST Comperand : TimeSpan ) : BOOLEAN;
   BEGIN
      RETURN _Value = Comperand._Value;
   END =;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC OPERATOR <>( CONST Comperand : TimeSpan ) : BOOLEAN;
   BEGIN
      RETURN _Value <> Comperand._Value;
   END <>;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC OPERATOR <( CONST Comperand : TimeSpan ) : BOOLEAN;
   BEGIN
      RETURN _Value < Comperand._Value;
   END <;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC OPERATOR <=( CONST Comperand : TimeSpan ) : BOOLEAN;
   BEGIN
      RETURN _Value <= Comperand._Value;
   END <=;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC OPERATOR >( CONST Comperand : TimeSpan ) : BOOLEAN;
   BEGIN
      RETURN _Value > Comperand._Value;
   END >;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC OPERATOR >=( CONST Comperand : TimeSpan ) : BOOLEAN;
   BEGIN
      RETURN _Value >= Comperand._Value;
   END >=;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC OPERATOR +( CONST Addend : TimeSpan ) : TimeSpan;
   VAR
      ts : TimeSpan;
   BEGIN
      ts._Value := _Value + Addend._Value;
      RETURN ts;
   END +;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC OPERATOR -( CONST Addend : TimeSpan ) : TimeSpan;
   VAR
      ts : TimeSpan;
   BEGIN
      ts._Value := _Value - Addend._Value;
      RETURN ts;
   END -;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Add( CONST Addend : TimeSpan );
   BEGIN
      INC( _Value, Addend._Value );
   END Add;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Subtract( CONST Addend : TimeSpan );
   BEGIN
      DEC( _Value, Addend._Value );
   END Subtract;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE FromDHMS( D, H, M, S, MS : CARDINAL );
   BEGIN
      _Value := ( INT64((( D * 24 + H ) * 60 + M ) * 60 + S ) * 1000 + INT64( MS )) * 10000;
   END FromDHMS;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ToDHMS( OUT D, H, M, S, MS : CARDINAL );
   VAR
      fd : INT64;
   BEGIN
      IF _Value >= 0 THEN
         fd := _Value;
      ELSE
         fd := -_Value;
      END;
      fd := fd DIV 10000;

      MS := CARDINAL( fd MOD 1000 );
      fd := fd DIV 1000;
      S := CARDINAL( fd MOD 60 );
      fd := fd DIV 60;
      M := CARDINAL( fd MOD 60 );
      fd := fd DIV 60;
      H := CARDINAL( fd MOD 24 );
      D := CARDINAL( fd DIV 24 );

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
      IF H = 24 THEN
         INC( D );
         H := 0;
      END;
   END ToDHMS;

(*------------------------------------------------------------------------------------------------*)

BEGIN
END TimeSpan;

(*------------------------------------------------------------------------------------------------*)

PROCEDURE TimeSpanZero() : TimeSpan;
VAR
   ts : TimeSpan;
BEGIN
   RETURN ts;
END TimeSpanZero;

(*------------------------------------------------------------------------------------------------*)

PROCEDURE TimeSpanMS32( Milliseconds : INT32 ) : TimeSpan;
VAR
   ts : TimeSpan;
BEGIN
   ts.Milliseconds := LONGREAL( Milliseconds );
   RETURN ts;
END TimeSpanMS32;

(*------------------------------------------------------------------------------------------------*)

PROCEDURE TimeSpanS( Seconds : LONGREAL ) : TimeSpan;
VAR
   ts : TimeSpan;
BEGIN
   ts.Seconds := Seconds;
   RETURN ts;
END TimeSpanS;

(*------------------------------------------------------------------------------------------------*)

PROCEDURE TimeSpanD( Days : LONGREAL ) : TimeSpan;
VAR
   ts : TimeSpan;
BEGIN
   ts.Days := Days;
   RETURN ts;
END TimeSpanD;

(*================================================================================================*)
// high resolution timer

VAR
   HRTimeFound : BOOLEAN := FALSE;
   HRTimeFrequency : CARD64;

(*------------------------------------------------------------------------------------------------*)

PROCEDURE InitHRTime();
VAR
   li : windows.LARGE_INTEGER;
BEGIN
   HRTimeFound := windows.QueryPerformanceFrequency( li ) = windows.True;
   IF HRTimeFound THEN
      HRTimeFrequency := CARD64( li );
   ELSE
      HRTimeFrequency := 1000;
   END;
END InitHRTime;

(*------------------------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION HighResolutionTime; // unit is 1/Frequency
   
(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Precision GET : CARD64; // hertz
   BEGIN
      RETURN HRTimeFrequency;
   END Precision;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Value GET : CARD64; // hertz
   BEGIN
      RETURN _Value;
   END Value;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC INLINE OPERATOR :=( CONST Source : HighResolutionTime );
   BEGIN
      _Value := Source._Value;
   END :=;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC OPERATOR -( CONST Addend : HighResolutionTime ) : TimeSpan;
   VAR
      ts : TimeSpan;
   BEGIN
      ts.Seconds := LONGREAL( _Value - Addend._Value ) / LONGREAL( HRTimeFrequency );
      RETURN ts;
   END -;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SetNow();
   TYPE
      PLARGE_INTEGER = POINTER TO windows.LARGE_INTEGER;
   VAR
      pli : PLARGE_INTEGER := PLARGE_INTEGER( ADR( _Value ));
   BEGIN
      IF HRTimeFound THEN
         windows.QueryPerformanceCounter( pli^ );
      ELSE
         _Value := UptimeMS64();
      END;
   END SetNow;

(*------------------------------------------------------------------------------------------------*)

BEGIN
END HighResolutionTime;

(*------------------------------------------------------------------------------------------------*)

PROCEDURE NowHR() : HighResolutionTime;
VAR
   hr : HighResolutionTime;
BEGIN
   hr.SetNow();
   RETURN hr;
END NowHR;

(*================================================================================================*)
// julian date

CONST
   scale = INT64( 864000000 ); // 100 us

// speed up of julian months
// julianMonth = 306001; -- multiples converted to table
TYPE
   TMonths = ARRAY [0..15] OF INTEGER;
CONST
   months = TMonths( 0,  30,  61,  91, 122, 153, 183, 214, 244, 275, 306, 336, 367, 397, 428, 459 );

(*------------------------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION DayCount;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Precision GET : CARD64;
   BEGIN
      RETURN 1000 * 10;
   END Precision;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY DayOfWeek GET : TDayOfWeek;
   BEGIN
      RETURN TDayOfWeek((( _Value + scale DIV 2 ) DIV scale ) MOD 7 + 1 );
   END DayOfWeek;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY IsLowBound GET : BOOLEAN;
   BEGIN
      RETURN _Value = MIN( INT64 );
   END IsLowBound;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY IsHighBound GET : BOOLEAN;
   BEGIN
      RETURN _Value = MAX( INT64 );
   END IsHighBound;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Value GET : INT64; // e.g. for transport purposes
   BEGIN
      RETURN _Value;
   END Value;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Value SET( _Value : INT64 );
   BEGIN
      SELF._Value := _Value;
   END Value;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY FractionOfTheDay GET : TimeSpan; // values greater than 1 D are trimmed (only the fraction is used)
   VAR
      ts : TimeSpan;
      valueReducedToMidnight : INT64;
   BEGIN
      valueReducedToMidnight := _Value - INT64( 432000000 );
      ts.Value := 1000 * ( valueReducedToMidnight MOD scale ); // possible expected "-" is correct too, because 432... is a half of the interval and +/- has the same sense (here)
      RETURN ts;
   END FractionOfTheDay;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY FractionOfTheDay SET( CONST Value : TimeSpan ); // values greater than 1 D are trimmed (only the fraction is used)
   VAR
      valueReducedToMidnight : INT64;
   BEGIN
      valueReducedToMidnight := _Value - INT64( 432000000 );
      DEC( _Value, valueReducedToMidnight MOD scale ); // remove existing fraction
      INC( _Value, ( Value.Value DIV 1000 ) MOD scale ); // add scale from the span
   END FractionOfTheDay;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY JulianDate GET : LONGREAL;
   BEGIN
      RETURN LONGREAL( _Value ) / LONGREAL( scale );
   END JulianDate;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY JulianDate SET( Value : LONGREAL );
   BEGIN
      _Value := INT64(( Value + 0.5 / 864000000.0 ) * LONGREAL( scale ));
   END JulianDate;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC OPERATOR =( CONST Comperand : DayCount ) : BOOLEAN;
   BEGIN
      RETURN _Value = Comperand._Value;
   END =;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC OPERATOR <>( CONST Comperand : DayCount ) : BOOLEAN;
   BEGIN
      RETURN _Value <> Comperand._Value;
   END <>;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC OPERATOR <( CONST Comperand : DayCount ) : BOOLEAN;
   BEGIN
      RETURN _Value < Comperand._Value;
   END <;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC OPERATOR <=( CONST Comperand : DayCount ) : BOOLEAN;
   BEGIN
      RETURN _Value <= Comperand._Value;
   END <=;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC OPERATOR >( CONST Comperand : DayCount ) : BOOLEAN;
   BEGIN
      RETURN _Value > Comperand._Value;
   END >;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC OPERATOR >=( CONST Comperand : DayCount ) : BOOLEAN;
   BEGIN
      RETURN _Value >= Comperand._Value;
   END >=;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC INLINE OPERATOR :=( CONST Source : DayCount );
   BEGIN
      _Value := Source._Value;
   END :=;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC OPERATOR +( CONST Addend : TimeSpan ) : DayCount;
   VAR
      dc : DayCount;
   BEGIN
      dc._Value := INC( _Value, Addend.Value DIV 1000 );
      RETURN dc;
   END +;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC OPERATOR -( CONST Addend : TimeSpan ) : DayCount;
   VAR
      dc : DayCount;
   BEGIN
      dc._Value := DEC( _Value, Addend.Value DIV 1000 );
      RETURN dc;
   END -;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SetNow();
   BEGIN
      _Value := NowDC()._Value;
   END SetNow;
   
(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SetLowBound(); // pair to IsLowBound
   BEGIN
      _Value := MIN( INT64 );
   END SetLowBound;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SetHighBound(); // pair to IsHighBound
   BEGIN
      _Value := MAX( INT64 );
   END SetHighBound;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Add( CONST Addend : TimeSpan );
   BEGIN
      INC( _Value, Addend.Value DIV 1000 );
   END Add;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Subtract( CONST Addend : TimeSpan );
   BEGIN
      DEC( _Value, Addend.Value DIV 1000 );
   END Subtract;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Difference( CONST Operand : DayCount ) : TimeSpan; // SELF - Operand
   VAR
      ts : TimeSpan;
   BEGIN
      ts.Value := 1000 * ( _Value - Operand._Value );
      RETURN ts;
   END Difference;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE FromYMD( y : INTEGER; m, d : CARDINAL; CONST fd : TimeSpan );
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

      _Value := scale * (
                  ( julianYear * y - c ) DIV 8 + // years
                  months[m] + // months
                  d // scale
                ) +
                INT64( 1486939248000000 ) + // year 0 boundary, 1720994.5
                fd.Value DIV 1000; // fraction
   END FromYMD;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ToYMD( OUT y : INTEGER; OUT m, d : CARDINAL; OUT fd : TimeSpan );
   CONST
      gregorianCentury = 3652425; // scaled by 100
      julianYear = 36525; // scaled by 100
      julianMonth = 306001; // scaled by 10000
   VAR
      a, b, alfa, z : INTEGER;
      dcl, dcx : INT64;
   BEGIN
      // works up to cca +/- 64000 years, see assert
      dcl := _Value + INT64( 432000000 );

      // separate fd, rescale to days
      dcx := dcl DIV scale;
      fd.Value := 1000 * ( dcl - scale * dcx );
      z := INTEGER( dcx );
      IF z >= MAX( INTEGER ) DIV 100 THEN
         ASSERTLOG( FALSE );
         z := MAX( INTEGER ) DIV 100 - 1;
      END;

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
   END ToYMD;

(*------------------------------------------------------------------------------------------------*)

BEGIN
END DayCount;

(*------------------------------------------------------------------------------------------------*)

PROCEDURE NowDC() : DayCount;
VAR
   dateTime : DateTime;
BEGIN
   dateTime.SetNowUTC();
   RETURN dateTime.DayCount;
END NowDC;

(*------------------------------------------------------------------------------------------------*)

PROCEDURE NowDCDayOnly() : DayCount;
VAR
   dateTime : DateTime;
BEGIN
   dateTime.SetNowUTC();
   dateTime.TrimTime();
   RETURN dateTime.DayCount;
END NowDCDayOnly;

(*------------------------------------------------------------------------------------------------*)

PROCEDURE DayCountYMD( y : INTEGER; m, d : CARDINAL ) : DayCount;
VAR
   dc : DayCount;
BEGIN
   dc.FromYMD( y, m, d, TimeSpanZero());
   RETURN dc;
END DayCountYMD;

(*------------------------------------------------------------------------------------------------*)

PROCEDURE DayCountYMDfd( y : INTEGER; m, d : CARDINAL; CONST fd : TimeSpan ) : DayCount;
VAR
   dc : DayCount;
BEGIN
   dc.FromYMD( y, m, d, fd );
   RETURN dc;
END DayCountYMDfd;

(*================================================================================================*)

TYPE
   TZoneInfo = RECORD
                  // Biases are always in MINUTES
                  SystemZoneInfo : windows.TIME_ZONE_INFORMATION;

                  DSTBias        : INTEGER; // DST bias respecting current DST state (if DST is off Current_DST_Bias = 0)
                  UTCDSTBias     : INTEGER; // SystemZoneInfo.Bias + CurrentDSTBias = both two biases in single element
               END;

VAR
   ZoneInfo : TZoneInfo;
   ZoneInfoUpdated : CARDINAL;

(*------------------------------------------------------------------------------------------------*)

PROCEDURE CheckUpdateZoneInfo();
VAR
   now : CARDINAL := UptimeMS();
BEGIN
   IF ( ZoneInfoUpdated <> 0 ) AND ( now - ZoneInfoUpdated < 15*60*1000 ) THEN
      RETURN;
   ELSE
      ZoneInfoUpdated := now;
   END;
   IF windows.GetTimeZoneInformation( ADR( ZoneInfo.SystemZoneInfo )) = windows.TIME_ZONE_ID_DAYLIGHT THEN
      ZoneInfo.DSTBias := INTEGER( ZoneInfo.SystemZoneInfo.DaylightBias );
   ELSE
      ZoneInfo.DSTBias := 0; // if daylight time is not active the bias should be 0
   END;
   ZoneInfo.UTCDSTBias := INTEGER( ZoneInfo.SystemZoneInfo.Bias ) + ZoneInfo.DSTBias;
END CheckUpdateZoneInfo;

(*------------------------------------------------------------------------------------------------*)

PROCEDURE GetZonalUTCBias() : INTEGER; // MINUTES!!
VAR
   i : INTEGER;
BEGIN
   TimeLock.Lock();
   CheckUpdateZoneInfo();
   i := INTEGER( ZoneInfo.SystemZoneInfo.Bias );
   TimeLock.Unlock();
   RETURN i;
END GetZonalUTCBias;

(*------------------------------------------------------------------------------------------------*)

PROCEDURE GetZonalDSTBias() : INTEGER; // MINUTES!!
VAR
   i : INTEGER;
BEGIN
   TimeLock.Lock();
   CheckUpdateZoneInfo();
   i := INTEGER( ZoneInfo.SystemZoneInfo.DaylightBias );
   TimeLock.Unlock();
   RETURN i;
END GetZonalDSTBias;

(*------------------------------------------------------------------------------------------------*)

PROCEDURE GetCurrentUTCBias() : INTEGER; // MINUTES!! 
VAR
   i : INTEGER;
BEGIN
   TimeLock.Lock();
   CheckUpdateZoneInfo();
   i := ZoneInfo.UTCDSTBias;
   TimeLock.Unlock();
   RETURN i;
END GetCurrentUTCBias;

(*------------------------------------------------------------------------------------------------*)

PROCEDURE GetCurrentDSTBias() : INTEGER; // MINUTES!! 
VAR
   i : INTEGER;
BEGIN
   TimeLock.Lock();
   CheckUpdateZoneInfo();
   i := ZoneInfo.DSTBias;
   TimeLock.Unlock();
   RETURN i;
END GetCurrentDSTBias;

(*================================================================================================*)
// local procedures needed for DateTime

CONST
  formatDelimiters = Strings.WCHARS{ '.', ':', ',', ';', '-', '_', '(', '[', '{', '}', ']', ')', '/', '\' };
TYPE
  TApostropheState = ( astGetFirstApostrophe, astCheckSecondApostrophe );

VAR
  SNLSCallback : ARRAY [0..63] OF WCHAR;

(*# save, call( convention => stdcall ) *)
PROCEDURE NLSCallback( PStr : PWCHAR ) : windows.BOOL;
BEGIN
  IF PStr = NIL THEN
    SNLSCallback := L'';
  ELSE
    ASSIGNsz( SNLSCallback, PStr );
  END;
  RETURN windows.False;
END NLSCallback;
(*# restore *)

(*------------------------------------------------------------------------------------------------*)

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
      Result[di] := Format[si]; // -- escaped delimiter
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

(*------------------------------------------------------------------------------------------------*)

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

(*------------------------------------------------------------------------------------------------*)

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
      IF di > 0 THEN
         DEC( di );
      END;
      IF ( di > 0 ) AND ( UW[di-1] = WCHAR( 1 )) THEN
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

(*================================================================================================*)
// DateTime itself

CLASS IMPLEMENTATION DateTime;
        
(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Precision GET : CARD64;
   BEGIN
      RETURN 1000;
   END Precision;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Millisecond GET : CARDINAL;
   BEGIN
      IF _Empty THEN
         RETURN 0;
      ELSE
         RETURN _Millisecond;
      END;
   END Millisecond;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Millisecond SET( Value : CARDINAL );
   BEGIN
      _Empty := FALSE;
      _DayOfWeekDirty := _DayOfWeekDirty OR ( _Millisecond <> Value );
      _Millisecond := Value;
   END Millisecond;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Second GET : CARDINAL;
   BEGIN
      IF _Empty THEN
         RETURN 0;
      ELSE
         RETURN _Second;
      END;
   END Second;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Second SET( Value : CARDINAL );
   BEGIN
      _Empty := FALSE;
      _DayOfWeekDirty := _DayOfWeekDirty OR ( _Second <> Value );
      _Second := Value;
   END Second;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Minute GET : CARDINAL;
   BEGIN
      IF _Empty THEN
         RETURN 0;
      ELSE
         RETURN _Minute;
      END;
   END Minute;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Minute SET( Value : CARDINAL );
   BEGIN
      _Empty := FALSE;
      _DayOfWeekDirty := _DayOfWeekDirty OR ( _Minute <> Value );
      _Minute := Value;
   END Minute;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Hour GET : CARDINAL;
   BEGIN
      IF _Empty THEN
         RETURN 0;
      ELSE
         RETURN _Hour;
      END;
   END Hour;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Hour SET( Value : CARDINAL );
   BEGIN
      _Empty := FALSE;
      _DayOfWeekDirty := _DayOfWeekDirty OR ( _Hour <> Value );
      _Hour := Value;
   END Hour;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Day GET : CARDINAL;
   BEGIN
      IF _Empty THEN
         RETURN 0;
      ELSE
         RETURN _Day;
      END;
   END Day;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Day SET( Value : CARDINAL );
   BEGIN
      _Empty := FALSE;
      _DayOfWeekDirty := _DayOfWeekDirty OR ( _Day <> Value );
      _Day := Value;
   END Day;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Month GET : CARDINAL;
   BEGIN
      IF _Empty THEN
         RETURN 0;
      ELSE
         RETURN _Month;
      END;
   END Month;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Month SET( Value : CARDINAL );
   BEGIN
      _Empty := FALSE;
      _DayOfWeekDirty := _DayOfWeekDirty OR ( _Month <> Value );
      _Month := Value;
   END Month;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Year GET : INTEGER;
   BEGIN
      IF _Empty THEN
         RETURN 0;
      ELSE
         RETURN _Year;
      END;
   END Year;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Year SET( Value : INTEGER );
   BEGIN
      _Empty := FALSE;
      _DayOfWeekDirty := _DayOfWeekDirty OR ( _Year <> Value );
      _Year := Value;
   END Year;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY UTCBias GET : INTEGER;
   BEGIN
      IF _Empty THEN
         RETURN 0;
      ELSE
         RETURN _UTCBias;
      END;
   END UTCBias;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY UTCBias SET( Value : INTEGER );
   BEGIN
      _Empty := FALSE;
      IF _UTCBias <> Value THEN
         FromDC( DayCount, Value, _DSTBias );
      END;
   END UTCBias;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY DSTBias GET : INTEGER;
   BEGIN
      IF _Empty THEN
         RETURN 0;
      ELSE
         RETURN _DSTBias;
      END;
   END DSTBias;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY DSTBias SET( Value : INTEGER );
   BEGIN
      _Empty := FALSE;
      IF _DSTBias <> Value THEN
         FromDC( DayCount, _UTCBias, Value );
      END;
   END DSTBias;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Empty GET : BOOLEAN;
   BEGIN
      RETURN _Empty;
   END Empty;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY DstActive GET : BOOLEAN;
   CONST
      fromYear1 = 1916; 
      toYear1   = 1918;
      fromYear2 = 1940;
      toYear2   = 1949;
      fromYear3 = 1979;
      toYear3   = 2002;
   TYPE
      TDSTInterval = RECORD
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
      Interval  : TDSTInterval;
      dc_ : datetime.DayCount;
      PInterval : POINTER TO CONST TDSTInterval;
   BEGIN
      IF _Empty THEN
         RETURN FALSE;
      END;

      IF ( _Year >= fromYear3 ) AND ( _Year <= toYear3 ) THEN
         PInterval := ADR( czBiasTable3[ _Year ] );
      ELSIF ( _Year >= fromYear2 ) AND ( _Year <= toYear2 ) THEN
         PInterval := ADR( czBiasTable2[ _Year ] );
      ELSIF ( _Year >= fromYear1 ) AND ( _Year <= toYear1 ) THEN
         PInterval := ADR( czBiasTable1[ _Year ] );
      ELSIF _Year > toYear3 THEN
         // get last march sunday
         dc_ := DayCountYMD( INTEGER( _Year ), 3, 31 );
         Interval.FromDay := 31 - CARDINAL( dc_.DayOfWeek ) - 1;
         Interval.FromMonth := 3;
         Interval.FromHour := 2;
         // get last october sunday
         dc_ := DayCountYMD( INTEGER( _Year ), 10, 31 );
         Interval.ToDay := 31 - CARDINAL( dc_.DayOfWeek ) - 1;
         Interval.ToMonth := 10;
         Interval.ToHour := 2;
         PInterval := ADR( Interval );
      ELSE
         RETURN FALSE;
      END;
      WITH PInterval^ DO
         IF ( _Month < FromMonth ) OR ( _Month > ToMonth ) THEN
            RETURN FALSE;
         ELSIF _Month = FromMonth THEN
            IF _Day < FromDay THEN
               RETURN FALSE;
            ELSIF _Day > FromDay THEN
               RETURN TRUE;
            ELSE
               RETURN _Hour >= FromHour;
            END;
         ELSIF _Month = ToMonth THEN
            IF _Day > ToDay THEN
               RETURN FALSE;
            ELSIF _Day < ToDay THEN
               RETURN TRUE;
            ELSE
               RETURN _Hour < ToHour;
            END;
         END;
      END;
      RETURN TRUE;
   END DstActive;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY DayOfWeek GET : TDayOfWeek;
   BEGIN
      IF _Empty THEN
         RETURN UnknownDay;
      ELSIF _DayOfWeekDirty THEN
         _DayOfWeekDirty := FALSE;
         _DayOfWeek := DayCount.DayOfWeek;
      END;
      RETURN _DayOfWeek;
   END DayOfWeek;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY DayCount GET : datetime.DayCount;
   VAR
      dc : datetime.DayCount;
      ts : TimeSpan;
   BEGIN
      IF NOT _Empty THEN
         ts.FromDHMS( 0, _Hour, _Minute + CARDINAL( _UTCBias + _DSTBias ), _Second, _Millisecond );
         dc.FromYMD( INTEGER( _Year ), INTEGER( _Month ), INTEGER( _Day ), ts );
      END;
      RETURN dc;
   END DayCount;
      
(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROPERTY DayCount SET( CONST Value : datetime.DayCount );
   BEGIN
      FromDC( Value, 0, 0 );
   END DayCount;
      
(*------------------------------------------------------------------------------------------------*)

   PUBLIC OPERATOR :=( CONST Source : DateTime );
   BEGIN
      Storage.Move( ADR( Source ), ADR( SELF ), SIZE( SELF ));
   END :=;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC OPERATOR = ( CONST Comperand : DateTime ) : BOOLEAN;
   BEGIN
      IF ( Comperand._UTCBias <> _UTCBias ) OR ( Comperand._DSTBias <> _DSTBias ) THEN
         RETURN Comperand.DayCount = DayCount;
      ELSIF Comperand._Year <> _Year THEN
         RETURN FALSE;
      ELSIF Comperand._Month <> _Month THEN
         RETURN FALSE;
      ELSIF Comperand._Day <> _Day THEN
         RETURN FALSE;
      ELSIF Comperand._Hour <> _Hour THEN
         RETURN FALSE;
      ELSIF Comperand._Minute <> _Minute THEN
         RETURN FALSE;
      ELSIF Comperand._Second <> _Second THEN
         RETURN FALSE;
      ELSIF Comperand._Millisecond <> _Millisecond THEN
         RETURN FALSE;
      END;
      RETURN TRUE;
   END =;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC OPERATOR <> ( CONST Comperand : DateTime ) : BOOLEAN;
   BEGIN
      RETURN NOT( SELF = Comperand );
   END <>;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC OPERATOR < ( CONST Comperand : DateTime ) : BOOLEAN;
   BEGIN
      IF ( Comperand._UTCBias <> _UTCBias ) OR ( Comperand._DSTBias <> _DSTBias ) THEN
         RETURN Comperand.DayCount > DayCount;
      ELSIF Comperand._Year < _Year THEN
         RETURN FALSE;
      ELSIF Comperand._Year > _Year THEN
         RETURN TRUE;
      ELSIF Comperand._Month < _Month THEN
         RETURN FALSE;
      ELSIF Comperand._Month > _Month THEN
         RETURN TRUE;
      ELSIF Comperand._Day < _Day THEN
         RETURN FALSE;
      ELSIF Comperand._Day > _Day THEN
         RETURN TRUE;
      ELSIF Comperand._Hour < _Hour THEN
         RETURN FALSE;
      ELSIF Comperand._Hour > _Hour THEN
         RETURN TRUE;
      ELSIF Comperand._Minute < _Minute THEN
         RETURN FALSE;
      ELSIF Comperand._Minute > _Minute THEN
         RETURN TRUE;
      ELSIF Comperand._Second < _Second THEN
         RETURN FALSE;
      ELSIF Comperand._Second > _Second THEN
         RETURN TRUE;
      ELSIF Comperand._Millisecond <= _Millisecond THEN
         RETURN FALSE;
      END;
      RETURN TRUE;
   END <;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC OPERATOR <= ( CONST Comperand : DateTime ) : BOOLEAN;
   BEGIN
      RETURN NOT( SELF > Comperand );
   END <=;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC OPERATOR > ( CONST Comperand : DateTime ) : BOOLEAN;
   BEGIN
      IF ( Comperand._UTCBias <> _UTCBias ) OR ( Comperand._DSTBias <> _DSTBias ) THEN
         RETURN Comperand.DayCount < DayCount;
      ELSIF Comperand._Year > _Year THEN
         RETURN FALSE;
      ELSIF Comperand._Year < _Year THEN
         RETURN TRUE;
      ELSIF Comperand._Month > _Month THEN
         RETURN FALSE;
      ELSIF Comperand._Month < _Month THEN
         RETURN TRUE;
      ELSIF Comperand._Day > _Day THEN
         RETURN FALSE;
      ELSIF Comperand._Day < _Day THEN
         RETURN TRUE;
      ELSIF Comperand._Hour > _Hour THEN
         RETURN FALSE;
      ELSIF Comperand._Hour < _Hour THEN
         RETURN TRUE;
      ELSIF Comperand._Minute > _Minute THEN
         RETURN FALSE;
      ELSIF Comperand._Minute < _Minute THEN
         RETURN TRUE;
      ELSIF Comperand._Second > _Second THEN
         RETURN FALSE;
      ELSIF Comperand._Second < _Second THEN
         RETURN TRUE;
      ELSIF Comperand._Millisecond >= _Millisecond THEN
         RETURN FALSE;
      END;
      RETURN TRUE;
   END >;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC OPERATOR >= ( CONST Comperand : DateTime ) : BOOLEAN;
   BEGIN
      RETURN NOT( SELF < Comperand );
   END >=;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC OPERATOR + ( CONST Addend : TimeSpan ) : DateTime;
   VAR
      dt : DateTime := SELF;
   BEGIN
      dt.Add( Addend );
      RETURN dt;
   END +;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC OPERATOR - ( CONST Addend : TimeSpan ) : DateTime;
   VAR
      dt : DateTime := SELF;
   BEGIN
      dt.Subtract( Addend );
      RETURN dt;
   END -;
        
(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Clear();
   VAR
      dt : DateTime;
   BEGIN
      SELF := dt;
   END Clear;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE TrimDate();
   BEGIN
      _DayOfWeekDirty := TRUE;
      _Year := 0;
      _Month := 0;
      _Day := 0;
   END TrimDate;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE TrimTime();
   BEGIN
      _DayOfWeekDirty := TRUE;
      _Hour := 0;
      _Minute := 0;
      _Second := 0;
      _Millisecond := 0;
      _DSTBias := 0;
      _UTCBias := 0;
   END TrimTime;
   
(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SetNowLocal();
   VAR
      st : windows.SYSTEMTIME;
   BEGIN
      _Empty := FALSE;
      windows.GetLocalTime( ADR( st ));
      _Millisecond := CARDINAL( st.wMilliseconds );
      _Second      := CARDINAL( st.wSecond );
      _Minute      := CARDINAL( st.wMinute );
      _Hour        := CARDINAL( st.wHour );
      _Day         := CARDINAL( st.wDay );
      _Month       := CARDINAL( st.wMonth );
      _Year        := CARDINAL( st.wYear );
      _DayOfWeek   := TDayOfWeek(( CARDINAL( st.wDayOfWeek ) + 6 ) MOD 7 + 1 );
      _UTCBias     := 0;
      _DSTBias     := 0;
   END SetNowLocal;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SetNowUTC();
   VAR
      st : windows.SYSTEMTIME;
   BEGIN
      _Empty := FALSE;
      windows.GetSystemTime( ADR( st ));
      _Millisecond := CARDINAL( st.wMilliseconds );
      _Second      := CARDINAL( st.wSecond );
      _Minute      := CARDINAL( st.wMinute );
      _Hour        := CARDINAL( st.wHour );
      _Day         := CARDINAL( st.wDay );
      _Month       := CARDINAL( st.wMonth );
      _Year        := CARDINAL( st.wYear );
      _DayOfWeek   := TDayOfWeek(( CARDINAL( st.wDayOfWeek ) + 6 ) MOD 7 + 1 );
      _UTCBias     := 0;
      _DSTBias     := 0;
   END SetNowUTC;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SetZoneToLocal();
   BEGIN
      IF DstActive THEN
         SetZone( GetZonalUTCBias(), GetZonalDSTBias());
      ELSE
         SetZone( GetZonalUTCBias(), 0 );
      END;
   END SetZoneToLocal;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SetZoneToUTC();
   BEGIN
      SetZone( 0, 0 );
   END SetZoneToUTC;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SetZone( utcBias, dstBias : INTEGER ); // sets both biases in single call
   BEGIN
      IF ( _UTCBias = utcBias ) AND ( _DSTBias = dstBias ) THEN
         RETURN;
      END;
      FromDC( DayCount, utcBias, dstBias );
   END SetZone;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE FromDC( CONST dc : datetime.DayCount; utcBias, dstBias : INTEGER );
   VAR
      FD : CARDINAL;
      ldc : datetime.DayCount := dc;
      Y, M, D : INTEGER;
      ts : TimeSpan;
   BEGIN
      ts.Minutes := LONGREAL( dstBias + dstBias );
      ldc.Subtract( ts );
      ldc.ToYMD( OUT Y, OUT M, OUT D, OUT ts );

      _Empty := FALSE;
      _Year := CARDINAL( Y );
      _Month := CARDINAL( M );
      _Day := CARDINAL( D );
      _DayOfWeek := ldc.DayOfWeek;
      _DayOfWeekDirty := FALSE;
      _UTCBias := utcBias;
      _DSTBias := dstBias;

      ts.ToDHMS( OUT D, OUT _Hour, OUT _Minute, OUT _Second, OUT _Millisecond );
   END FromDC;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE FromDCToLocal( CONST dc : datetime.DayCount );
   BEGIN
      FromDC( dc, GetZonalUTCBias(), GetZonalDSTBias());
   END FromDCToLocal;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Add( Addend : TimeSpan );
   BEGIN
      DayCount := DayCount + Addend;
   END Add;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Subtract( Addend : TimeSpan );
   BEGIN
      DayCount := DayCount - Addend;
   END Subtract;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Difference( CONST Operand : DateTime ) : TimeSpan;
   BEGIN
      RETURN DayCount.Difference( Operand.DayCount );
   END Difference;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE FromStringOA( CONST String, Format : ARRAY OF WCHAR ) : BOOLEAN;
   BEGIN
      RETURN FromLanguageStringOA( Languages.GetDefaultLanguage( Languages.dlUser ), String, Format );
   END FromStringOA;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE FromLanguageStringOA( Language : Languages.TLanguage; CONST String, Format : ARRAY OF WCHAR ) : BOOLEAN;
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

      PROCEDURE FillDateTime( REF dateTime : DateTime; Expect : TExpectInString; n : CARDINAL );
      BEGIN
         CASE Expect OF
         | eisDayDigit, eisDayDigitLZ :
            dateTime._Day := n;
         | eisMonthDigit, eisMonthDigitLZ, eisMonthAbbr, eisMonthName :
            dateTime._Month := n;
         | eisYearTwoDigit, eisYearTwoDigitLZ, eisYearFourDigit :
            dateTime._Year := n;
         | eisFractionD :
            dateTime._Millisecond := 100 * n;
         | eisFractionC :
            dateTime._Millisecond := 10 * n;
         | eisFractionM :
            dateTime._Millisecond := n;
         | eisSecondDigit, eisSecondDigitLZ :
            dateTime._Second := n;
         | eisMinuteDigit, eisMinuteDigitLZ :
            dateTime._Minute := n;
         | eisHour12, eisHour12LZ :
            dateTime._Hour := n;
         | eisHour24, eisHour24LZ :
            dateTime._Hour := n;
         END; // CASE
      END FillDateTime;

   //----------

      PROCEDURE ConvertStringItem( Expect : TExpectInString; S : ARRAY OF TCHAR; REF LocalDateTime : DateTime );
      VAR
         i : CARDINAL;
         PE2NLS : POINTER TO CONST TExpect2NLS;
      BEGIN
         CASE Expect OF
         | eisEra, eisDayAbbr, eisDayName : RETURN;
         | eisMonthAbbr : PE2NLS := ADR( expect2NLSMonthAbbr ); 
         | eisMonthName : PE2NLS := ADR( expect2NLSMonthName ); 
         END;
         TimeLock.Lock();
         i := 0;
         WHILE PE2NLS^[i] <> 0 DO
            winnls.EnumCalendarInfo( winnls.CALINFO_ENUMPROC( NLSCallback ), Language, winnls.ENUM_ALL_CALENDARS, PE2NLS^[i] );
            IF Strings.EqualsIgnoreCaseW( SNLSCallback, S ) THEN
               FillDateTime( REF LocalDateTime, Expect, i + 1 );
               EXIT;
            END;
            INC( i );
         END; // WHILE
         TimeLock.Unlock();
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
      LocalDateTime : DateTime;
      n : CARDINAL;
      S : ARRAY [0..63] OF WCHAR;
      si : CARDINAL;
      PMFlag : BOOLEAN;
      TwelveFlag : BOOLEAN;
      Year2Flag : BOOLEAN;
   BEGIN
      IF ( HIGH( String ) = -1 ) OR ( ADR( String ) = NIL ) THEN
         RETURN FALSE;
      END;

      fi := 0;
      si := 0;
      PMFlag := FALSE;
      TwelveFlag := FALSE;
      Year2Flag := FALSE;

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
         Year2Flag := Year2Flag OR ( Expect = eisYearTwoDigit ) OR ( Expect = eisYearTwoDigitLZ );

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
               FillDateTime( REF LocalDateTime, Expect, n );
               GOTO CheckEnd;
            END;
            CASE String[si] OF
            | L'0'..L'9' :
               n := n * 10 + ORD( String[si] ) - ORD( '0' );
               INC( si );
            // ELSE not accepted, not incremented
            END;
            FillDateTime( REF LocalDateTime, Expect, n );

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
            FillDateTime( REF LocalDateTime, Expect, n );

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
                  ConvertStringItem( Expect, S, REF LocalDateTime );
                  EXIT;
               ELSE
                  S[i] := String[si];
                  INC( i );
                  INC( si )
               END; // CASE of accepted characters
               IF ( si > HIGH( String )) OR ( String[0] = WCHAR( 0 )) THEN
                  S[i] := 0W;
                  ConvertStringItem( Expect, S, REF LocalDateTime );
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
            FillDateTime( REF LocalDateTime, Expect, n );

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
            FillDateTime( REF LocalDateTime, Expect, n );

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

      IF PMFlag AND TwelveFlag AND ( LocalDateTime._Hour > 0 ) AND ( LocalDateTime._Hour < 13 ) THEN
         INC( LocalDateTime._Hour, 12 );
      END;
      IF Year2Flag THEN
         INC( LocalDateTime._Year, 2000 );
      END;
     
      SELF := LocalDateTime;
      _Empty := FALSE;
      _DayOfWeekDirty := TRUE;

      RETURN TRUE;
   END FromLanguageStringOA;

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ToStringOA( Format : ARRAY OF WCHAR; FormatDate : BOOLEAN; FormatTime : BOOLEAN; OUT String : ARRAY OF WCHAR ) : BOOLEAN;
   BEGIN
      RETURN ToLanguageStringOA( Languages.GetDefaultLanguage( Languages.dlUser ), Format, FormatDate, FormatTime, OUT String );
   END ToStringOA;   

(*------------------------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ToLanguageStringOA( Language : Languages.TLanguage; Format : ARRAY OF WCHAR; FormatDate : BOOLEAN; FormatTime : BOOLEAN; OUT String : ARRAY OF WCHAR ) : BOOLEAN;
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
      IF NOT FormatDate THEN
         // prefill date to assure GetDate/TimeFormat does not fail
         st.wYear := 2000;
         st.wMonth := 1;
         st.wDay := 1;
      ELSIF _Year < 1601 THEN // for lower values GetDate/TimeFormat fails
         RETURN FALSE;
      ELSE
         st.wYear := WORD( _Year );
         st.wMonth := WORD( _Month );
         st.wDay := WORD( _Day );
      END;

      st.wHour := WORD( _Hour );
      st.wMinute := WORD( _Minute );
      st.wSecond := WORD( _Second );
      st.wMilliseconds := WORD( _Millisecond );
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
            String[i] := WCHAR( ORD( L'0' ) + _Millisecond DIV 100 );
            INC( i );
            IF i = l THEN
               IF FFlag AND ( _Millisecond MOD 100 > 50 ) THEN
                  INC( String[i-1] );
               END;
               EXIT;
            ELSIF ( String[i] <> L'f' ) AND ( String[i] <> L'F' ) THEN
               IF FFlag AND ( _Millisecond MOD 100 > 50 ) THEN
                  INC( String[i] );
               END;
               DEC( i );
            ELSE
               FFlag := String[i] = L'F';
               String[i] := TCHAR( ORD( L'0' ) + ( _Millisecond DIV 10 ) MOD 10 );
               INC( i );
               IF i = l THEN
                  IF FFlag AND ( _Millisecond MOD 100 > 50 ) THEN
                     INC( String[i-1] );
                  END;
                  EXIT;
               ELSIF ( String[i] <> L'f' ) AND ( String[i] <> L'F' ) THEN
                  IF FFlag AND ( _Millisecond MOD 10 > 5 ) THEN
                     INC( String[i] );
                  END;
                  DEC( i );
               ELSE
                  String[i] := WCHAR( ORD( L'0' ) + _Millisecond MOD 10 );
               END;
            END;
         END; // CASE
         INC( i );
      END; // LOOP

      RETURN TRUE;
   END ToLanguageStringOA;

(*------------------------------------------------------------------------------------------------*)

BEGIN
   _Empty := TRUE;
   _Millisecond := 0;
   _Second := 0;
   _Minute := 0;
   _Hour := 0;
   _Day := 0;
   _Month := 0;
   _Year := 0;
   _DayOfWeek := UnknownDay;
   _DayOfWeekDirty := FALSE;
   _UTCBias := 0;
   _DSTBias := 0;
END DateTime;

(*================================================================================================*)

PROCEDURE NowLocal() : DateTime;
VAR
   dt : DateTime;
BEGIN
   dt.SetNowLocal();
   RETURN dt;
END NowLocal;

(*------------------------------------------------------------------------------------------------*)

PROCEDURE NowUTC() : DateTime;
VAR
   dt : DateTime;
BEGIN
   dt.SetNowUTC();
   RETURN dt;
END NowUTC;

(*================================================================================================*)

INITIALLY __I();
BEGIN
   ZoneInfoUpdated := 0;
   TimeLock.Init( Sync.ltSpin, L"", FALSE );
   InitHRTime();
END __I;

(*================================================================================================*)

END datetime.
