IMPLEMENTATION MODULE Console;

IMPORT
  windows,
  FIO;
  
IMPORT
  Strings;

VAR
  ErrOutF : FIO.File;
  QuietMode : TQuietMode := quietNone;

//============================================================

PROCEDURE iWriteEOL();
BEGIN
  FIO.WrLnA( ErrOutF );
END iWriteEOL;

PROCEDURE iWriteString( Data : ARRAY OF WCHAR );
VAR
  DataA : ARRAY [0..1023] OF CHAR;
BEGIN
  Strings.ToA( Data, 0, OUT DataA );
  FIO.WrStrA( ErrOutF, DataA );
END iWriteString;

PROCEDURE WriteEOL();
BEGIN
  IF QuietMode >= quietInfo THEN
    RETURN;
  END;
  iWriteEOL();
END WriteEOL;

PROCEDURE WriteString( Data : ARRAY OF WCHAR );
BEGIN
  IF QuietMode >= quietInfo THEN
    RETURN;
  END;
  iWriteString( Data );
END WriteString;

PROCEDURE WriteStringS( Mask, Data : ARRAY OF WCHAR );
VAR
  String : ARRAY [0..1023] OF WCHAR;
BEGIN
  IF QuietMode >= quietInfo THEN
    RETURN;
  END;
  ASSIGN( String, Mask );
  Strings.ReplaceW( REF String, L'{0}', Data );
  iWriteString( String );
END WriteStringS;

PROCEDURE WriteStringS2( Mask, Data1, Data2 : ARRAY OF WCHAR );
VAR
  String : ARRAY [0..1023] OF WCHAR;
BEGIN
  IF QuietMode >= quietInfo THEN
    RETURN;
  END;
  ASSIGN( String, Mask );
  Strings.ReplaceW( REF String, L'{0}', Data1 );
  Strings.ReplaceW( REF String, L'{1}', Data2 );
  iWriteString( String );
END WriteStringS2;

PROCEDURE WriteStringCS( Mask : ARRAY OF WCHAR; CONST Data : StringsO.CString );
BEGIN
  IF QuietMode >= quietInfo THEN
    RETURN;
  END;
  WriteStringS( Mask, OA( Data.Length, Data.szData ));
END WriteStringCS;

PROCEDURE WriteLineS( Mask, Data : ARRAY OF WCHAR );
BEGIN
  IF QuietMode >= quietInfo THEN
    RETURN;
  END;
  WriteStringS( Mask, Data );
  FIO.WrLnA( ErrOutF );
END WriteLineS;

PROCEDURE WriteLineCS( Mask : ARRAY OF WCHAR; CONST Data : StringsO.CString );
BEGIN
  IF QuietMode >= quietInfo THEN
    RETURN;
  END;
  WriteLineS( Mask, OA( Data.Length, Data.szData ));
END WriteLineCS;

PROCEDURE WriteLineCS2( Mask : ARRAY OF WCHAR; CONST Data1, Data2 : StringsO.CString );
BEGIN
  IF QuietMode >= quietInfo THEN
    RETURN;
  END;
  WriteStringS2( Mask, OA( Data1.Length, Data1.szData ), OA( Data2.Length, Data2.szData ));
  iWriteEOL();
END WriteLineCS2;

PROCEDURE WriteLineError( Number : CARDINAL; Mask : ARRAY OF WCHAR; CONST Path : StringsO.CString; Line, Col : CARDINAL; Data : ARRAY OF WCHAR );
VAR
  a : POINTER TO WCHAR;
  LPath : ARRAY [0..260] OF WCHAR;
  sC, sL, sN : ARRAY [0..15] OF WCHAR;
  sName : ARRAY [0..255] OF WCHAR;
  String : ARRAY [0..1023] OF WCHAR;
BEGIN
  IF QuietMode = quietAll THEN
    RETURN;
  END;
  ASSIGN( sName, OA( Path.Length, Path.szData ));
  IF windows.SearchPathW( NIL, ADR( sName ), NIL, SIZE( LPath ) >> 1, ADR( LPath ), a ) = 0 THEN
    ASSIGN( LPath, sName );
  END;
  Strings.FromCARD32W( Number, 10, OUT sN ); Strings.PadLeftW( REF sN, 4, L'0' );
  Strings.FromCARD32W( Line, 10, OUT sL );
  Strings.FromCARD32W( Col, 10, OUT sC );
  ASSIGN( String, Mask );
  Strings.ReplaceW( REF String, L'{0}', sN );
  Strings.ReplaceW( REF String, L'{1}', LPath );
  Strings.ReplaceW( REF String, L'{2}', sL );
  Strings.ReplaceW( REF String, L'{3}', sC );
  Strings.ReplaceW( REF String, L'{4}', L"error M" );
  Strings.ReplaceW( REF String, L'{5}', Data );
  iWriteString( String );
  iWriteEOL();
END WriteLineError;

PROCEDURE WriteLineWarning( Number : CARDINAL; Mask : ARRAY OF WCHAR; CONST Path : StringsO.CString; Line, Col : CARDINAL; Data : ARRAY OF WCHAR );
VAR
  a : ADDRESS;
  LPath : ARRAY [0..260] OF WCHAR;
  sC, sL, sN : ARRAY [0..15] OF WCHAR;
  sName : ARRAY [0..255] OF WCHAR;
  String : ARRAY [0..1023] OF WCHAR;
BEGIN
  IF QuietMode = quietAll THEN
    RETURN;
  END;
  ASSIGN( sName, OA( Path.Length, Path.szData ));
  IF windows.SearchPathW( NIL, ADR( sName ), NIL, SIZE( LPath ) >> 1, ADR( LPath ), a ) = 0 THEN
    ASSIGN( LPath, sName );
  END;
  Strings.FromCARD32W( Number, 10, OUT sN ); Strings.PadLeftW( REF sN, 4, L'0' );
  Strings.FromCARD32W( Line, 10, OUT sL );
  Strings.FromCARD32W( Col, 10, OUT sC );
  ASSIGN( String, Mask );
  Strings.ReplaceW( REF String, L'{0}', sN );
  Strings.ReplaceW( REF String, L'{1}', LPath );
  Strings.ReplaceW( REF String, L'{2}', sL );
  Strings.ReplaceW( REF String, L'{3}', sC );
  Strings.ReplaceW( REF String, L'{4}', L"warning M" );
  Strings.ReplaceW( REF String, L'{5}', Data );
  iWriteString( String );
  iWriteEOL();
END WriteLineWarning;

//============================================================

PROCEDURE SetQuiet( _QuietMode : TQuietMode );
BEGIN
  QuietMode := _QuietMode;
END SetQuiet;

//============================================================

INITIALLY __I();
BEGIN
  ErrOutF := windows.GetStdHandle( windows.STD_OUTPUT_HANDLE );
END __I;

END Console.