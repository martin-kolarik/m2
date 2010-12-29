IMPLEMENTATION MODULE DateTimeWin32;

(*===========================================================================*)

PROCEDURE SystemTimeToJD( CONST SystemTime : windows.SYSTEMTIME ) : datetime.TJD;
BEGIN
  RETURN datetime.JD( INTEGER( SystemTime.wYear ),
             INTEGER( SystemTime.wMonth ),
             INTEGER( SystemTime.wDay ),
             datetime.HMS2fd( CARDINAL( SystemTime.wHour ), CARDINAL( SystemTime.wMinute ), CARDINAL( SystemTime.wSecond ), CARDINAL( SystemTime.wMilliseconds )));
END SystemTimeToJD;

(*---------------------------------------------------------------------------*)

PROCEDURE JDToSystemTime( JD : datetime.TJD; OUT SystemTime : windows.SYSTEMTIME );
VAR
  C1, C2, C3, C4 : CARDINAL;
  FD             : CARDINAL;
  I1, I2, I3     : INTEGER;
BEGIN
  datetime.iJD( JD, OUT I1, OUT I2, OUT I3, OUT FD );
  WITH SystemTime DO
    wYear := WORD( I1 );
    wMonth := WORD( I2 ); 
    wDay := WORD( I3 );
    wDayOfWeek := WORD( CARDINAL( datetime.ToSJD( JD ) + 1.5 ) MOD 7 ); // ( JD + 0.5 ) MOD 7 gives 0 = Monday

    datetime.fd2HMS( FD, OUT C1, OUT C2, OUT C3, OUT C4 );
    wHour := WORD( C1 );
    wMinute := WORD( C2 );
    wSecond := WORD( C3 );
    wMilliseconds := WORD( C4 );
  END; // WITH
END JDToSystemTime;

(*===========================================================================*)

PROCEDURE DateTimeToSystemTime( CONST DateTime : datetime.DateTime; OUT SystemTime : windows.SYSTEMTIME );
BEGIN
  SystemTime.wYear := WORD( MAX2( 1601, DateTime.Year ));
  SystemTime.wMonth := WORD( DateTime.Month );
  SystemTime.wDay := WORD( DateTime.Day );
  SystemTime.wHour := WORD( DateTime.Hour );
  SystemTime.wMinute := WORD( DateTime.Minute );
  SystemTime.wSecond := WORD( DateTime.Second );
  SystemTime.wMilliseconds := WORD( DateTime.Millisecond );
  SystemTime.wDayOfWeek := 0;
END DateTimeToSystemTime;

(*--------------------------------------------------------------------------*)

PROCEDURE SystemTimeToDateTime( CONST SystemTime : windows.SYSTEMTIME; OUT DateTime : datetime.DateTime );
BEGIN
	DateTime.Year := INTEGER( SystemTime.wYear );
	DateTime.Month := CARDINAL( SystemTime.wMonth );
	DateTime.Day := CARDINAL( SystemTime.wDay );
	DateTime.Hour := CARDINAL( SystemTime.wHour );
	DateTime.Minute := CARDINAL( SystemTime.wMinute );
	DateTime.Second := CARDINAL( SystemTime.wSecond );
	DateTime.Millisecond := CARDINAL( SystemTime.wMilliseconds );
END SystemTimeToDateTime;

(*===========================================================================*)

END DateTimeWin32.
