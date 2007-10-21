IMPLEMENTATION MODULE Languages;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

FROM Strings IMPORT
  LowerizeW;
  
IMPORT
   Strings,
   windows,
   wincon,
   winerror,
   winnls;
  
//===========================================================================

PROCEDURE cp_Console() : CARDINAL;
BEGIN
   RETURN wincon.GetConsoleOutputCP();
END cp_Console;

//===========================================================================

CONST
  LCID_EN = ( windows.SORT_DEFAULT << 16 ) OR ( windows.SUBLANG_ENGLISH_US << 10 ) OR windows.LANG_ENGLISH;
  LCID_CS = ( windows.SORT_DEFAULT << 16 ) OR ( windows.SUBLANG_DEFAULT << 10 ) OR windows.LANG_CZECH;
#save, call( convention => stdcall )
TYPE
  TToRFC1766 = PROCEDURE( winnls.LCID, PWCHAR, CARDINAL ) : CARDINAL;
  TFromRFC1766 = PROCEDURE( VAR winnls.LCID, PWCHAR ) : CARDINAL;
  TToWStream = PROCEDURE( windows.PDWORD, windows.DWORD, windows.PCSTR, windows.PINT, windows.PWSTR, windows.PINT ) : CARDINAL;
  TToAStream = PROCEDURE( windows.PDWORD, windows.DWORD, windows.PCWSTR, windows.PINT, windows.PSTR, windows.PINT ) : CARDINAL;
#restore

CLASS MLangWrapper;
  PRIVATE VAR
    DLLHandle : windows.HANDLE;
    ToRFC1766 : TToRFC1766;
    FromRFC1766 : TFromRFC1766;
    ToW : TToWStream;
    ToA : TToAStream;
    
  PUBLIC PROCEDURE RFC1766ToLanguage( CONST RFC1766 : ARRAY OF WCHAR; OUT Language : TLanguage ) : BOOLEAN;
  PUBLIC PROCEDURE LanguageToRFC1766( Language : TLanguage; OUT RFC1766 : ARRAY OF WCHAR ) : BOOLEAN;
  PUBLIC PROCEDURE ToWStream( CONST Source : ARRAY OF BYTE; CodePage : CARDINAL; OUT Destination : ARRAY OF WCHAR; OUT Consumed, Produced : CARDINAL ) : BOOLEAN; // returns if something consumed
  PUBLIC PROCEDURE ToAStream( CONST Source : ARRAY OF WCHAR; CodePage : CARDINAL; OUT Destination : ARRAY OF BYTE; OUT Consumed, Produced : CARDINAL ) : BOOLEAN; // returns if something consumed
  
  PRIVATE PROCEDURE LoadDLL() : BOOLEAN;
END MLangWrapper;

//---------------------------------------------------------------------------

CLASS IMPLEMENTATION MLangWrapper;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE RFC1766ToLanguage( CONST RFC1766 : ARRAY OF WCHAR; OUT Language : TLanguage ) : BOOLEAN;
  VAR
    LS : ARRAY [0..31] OF WCHAR;
  BEGIN
    IF LoadDLL() THEN
      RETURN winerror.SUCCEEDED( FromRFC1766( Language, PWCHAR( ADR( RFC1766 ))));
    ELSE
      ASSIGN( LS, RFC1766 );
      LOW( LS );
      IF EQUALS( OA( 1, ADR( LS )), 'cs' ) THEN
        Language := LCID_CS;
      ELSIF EQUALS( OA( 1, ADR( LS )), 'en' ) THEN
        Language := LCID_EN; 
      ELSE
        RETURN FALSE;
      END;
      RETURN TRUE;
    END;
  END RFC1766ToLanguage;
  
//---------------------------------------------------------------------------

  PUBLIC PROCEDURE LanguageToRFC1766( Language : TLanguage; OUT RFC1766 : ARRAY OF WCHAR ) : BOOLEAN;
  BEGIN
    IF LoadDLL() THEN
      RETURN winerror.SUCCEEDED( ToRFC1766( Language, ADR( RFC1766 ), HIGH( RFC1766 ) + 1 ));
    ELSE
      IF Language = LCID_EN THEN
        ASSIGN( RFC1766, L'en-US' );
      ELSIF Language = LCID_CS THEN
        ASSIGN( RFC1766, L'cs-CZ' );
      ELSE
        RETURN FALSE;
      END;
      RETURN TRUE;
    END;
  END LanguageToRFC1766;
  
//---------------------------------------------------------------------------

  PUBLIC PROCEDURE ToWStream( CONST Source : ARRAY OF BYTE; CodePage : CARDINAL; OUT Destination : ARRAY OF WCHAR; OUT Consumed, Produced : CARDINAL ) : BOOLEAN; // returns if something consumed
  VAR
    dw : windows.DWORD := 0;
    min, max : CARDINAL;
    sl : CARDINAL := HIGH( Source )+1;
    dl : CARDINAL := HIGH( Destination )+1;
    b : BOOLEAN;
  BEGIN
    IF CodePage = 0 THEN
      CodePage := winnls.GetACP();
    END;
    IF NOT LoadDLL() THEN
      RETURN FALSE;
    END;
    BytesPerCharacter( CodePage, OUT b, OUT min, OUT max ); // for both MCBS and UNICODE
    // adjust parameters for ToW, ToW reuires target buffer greater than input source
    dl := MIN2( dl, sl DIV min );
    sl := MIN2( sl, dl * min );
    IF ToW( ADR( dw ), CodePage, windows.PCSTR( ADR( Source )), ADR( sl ), ADR( Destination ), ADR( dl )) = winerror.S_OK THEN
      Consumed := sl;
      Produced := dl;
      RETURN TRUE;
    ELSE
      RETURN FALSE;
    END;
  END ToWStream;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE ToAStream( CONST Source : ARRAY OF WCHAR; CodePage : CARDINAL; OUT Destination : ARRAY OF BYTE; OUT Consumed, Produced : CARDINAL ) : BOOLEAN; // returns if something consumed
  VAR
    dw : windows.DWORD := 0;
    min, max : CARDINAL;
    sl : CARDINAL := HIGH( Source )+1;
    dl : CARDINAL := HIGH( Destination )+1;
    b : BOOLEAN;
  BEGIN
    IF CodePage = 0 THEN
      CodePage := winnls.GetACP();
    END;
    IF NOT LoadDLL() THEN
      RETURN FALSE;
    END;
    BytesPerCharacter( CodePage, OUT b, OUT min, OUT max ); // for both MCBS and UNICODE
    // adjust parameters for ToA, ToA reuires target buffer greater than input source
    dl := MIN2( dl, sl * max );
    sl := MIN2( sl, dl DIV max );
    IF ToA( ADR( dw ), CodePage, ADR( Source ), ADR( sl ), windows.PCSTR( ADR( Destination )), ADR( dl )) = winerror.S_OK THEN
      Consumed := sl;
      Produced := dl;
      RETURN TRUE;
    ELSE
      RETURN FALSE;
    END;
  END ToAStream;

//---------------------------------------------------------------------------

  PRIVATE PROCEDURE LoadDLL() : BOOLEAN;
  CONST
    _ToRFC1766 = C'LcidToRfc1766W';
    _FromRFC1766 = C'Rfc1766ToLcidW';
    _ToW = C'ConvertINetMultiByteToUnicode';
    _ToA = C'ConvertINetUnicodeToMultiByte';
  BEGIN
    IF DLLHandle = NIL THEN
      RETURN FALSE;
    ELSIF DLLHandle <> windows.INVALID_HANDLE_VALUE THEN
      RETURN TRUE;
    END;
    DLLHandle := windows.LoadLibrary( L'mlang.dll' );
    IF DLLHandle = NIL THEN
      RETURN FALSE;
    END;
    ToRFC1766 := windows.GetProcAddress( DLLHandle, _ToRFC1766 );
    FromRFC1766 := windows.GetProcAddress( DLLHandle, _FromRFC1766 );
    ToW := windows.GetProcAddress( DLLHandle, _ToW );
    ToA := windows.GetProcAddress( DLLHandle, _ToA );
    IF ( ToRFC1766 = NIL ) OR ( FromRFC1766 = NIL ) OR ( ToW = NIL ) OR ( ToA = NIL ) THEN
      windows.FreeLibrary( DLLHandle );
      DLLHandle := NIL;
      RETURN FALSE;
    ELSE
      RETURN TRUE;
    END;
  END LoadDLL;

//---------------------------------------------------------------------------

BEGIN
  DLLHandle := windows.INVALID_HANDLE_VALUE;
  ToRFC1766 := NIL;
  FromRFC1766 := NIL;
  ToW := NIL;
  ToA := NIL;
FINALLY
  IF ( DLLHandle <> windows.INVALID_HANDLE_VALUE ) AND ( DLLHandle <> NIL ) THEN
    windows.FreeLibrary( DLLHandle );
  END;
END MLangWrapper;

VAR
  MLang : MLangWrapper;

//===========================================================================

PROCEDURE RFC1766ToLanguage( CONST RFC1766 : ARRAY OF WCHAR; OUT Language : TLanguage ) : BOOLEAN;
BEGIN
  RETURN MLang.RFC1766ToLanguage( RFC1766, OUT Language );
END RFC1766ToLanguage;

PROCEDURE LanguageToRFC1766( Language : TLanguage; OUT RFC1766 : ARRAY OF WCHAR ) : BOOLEAN;
BEGIN
  RETURN MLang.LanguageToRFC1766( Language, OUT RFC1766 );
END LanguageToRFC1766;

PROCEDURE CodePageToLanguage( CodePage : CARDINAL; OUT Language : TLanguage ) : BOOLEAN;
BEGIN
  RETURN FALSE;
END CodePageToLanguage;

PROCEDURE LanguageToCodePage( Language : TLanguage; OUT CodePage : CARDINAL ) : BOOLEAN;
BEGIN
  RETURN FALSE;
END LanguageToCodePage;

PROCEDURE BytesPerCharacter( CodePage : CARDINAL; OUT FixedCount : BOOLEAN; OUT MinimalCount, MaximalCount : CARDINAL ); // for both MCBS and UNICODE
VAR
  CPI : winnls.CPINFO;
BEGIN
  CASE CodePage OF
  | cp_UTF16, cp_UTF16_BIG_ENDIAN :
    FixedCount := TRUE;
    MinimalCount := 2;
    MaximalCount := 2;
  | 437, 850, 852, 857, 860..869, 874, 1250..1258, 28591..28599 :
    FixedCount := TRUE;
    MinimalCount := 1;
    MaximalCount := 1;
  | cp_UTF8 :
    FixedCount := FALSE;
    MinimalCount := 1;
    MaximalCount := 4;
  ELSE
    IF winnls.GetCPInfo( CodePage, ADR( CPI )) = windows.True THEN
      FixedCount := CPI.MaxCharSize = 1;
      MinimalCount := 1;
      MaximalCount := CPI.MaxCharSize;
    ELSE
      FixedCount := TRUE;
      MinimalCount := 1;
      MaximalCount := 1;
    END;
  END;
END BytesPerCharacter;

PROCEDURE ToWStream( CONST Source : ARRAY OF BYTE; CodePage : CARDINAL; OUT Destination : ARRAY OF WCHAR; OUT Consumed, Produced : CARDINAL ) : BOOLEAN; // returns if something consumed
VAR
  i, l : CARDINAL;
BEGIN
  IF ( CodePage = cp_UTF16 ) OR ( CodePage = cp_UTF16_BIG_ENDIAN ) THEN
    IF HIGH( Source ) = 0 THEN
      RETURN FALSE;
    END;
    Produced := ( HIGH(Source)+1 ) >> 1;
    Consumed := Produced << 1;
    l := MIN2( Produced, HIGH( Destination )+1 );
    Strings.MoveW( ADR( Source ), ADR( Destination ), l );
    IF l <= HIGH( Destination ) THEN
      Destination[l] := 0W;
    END;
    IF CodePage = cp_UTF16_BIG_ENDIAN THEN
      FOR i := 0 TO l-1 DO
        Destination[i] := WCHAR( WORD( Destination[i] ) AND 0FFH << 8 OR WORD( Destination[i] ) >> 8 );
      END; // FOR
    END; // IF
    RETURN TRUE;
  ELSE
    RETURN MLang.ToWStream( Source, CodePage, OUT Destination, OUT Consumed, OUT Produced );
  END;
END ToWStream;

//===========================================================================

PROCEDURE ToAStream( CONST Source : ARRAY OF WCHAR; CodePage : CARDINAL; OUT Destination : ARRAY OF BYTE; OUT Consumed, Produced : CARDINAL ) : BOOLEAN; // returns if something consumed
VAR
  i, l : CARDINAL;
BEGIN
  IF ( CodePage = cp_UTF16 ) OR ( CodePage = cp_UTF16_BIG_ENDIAN ) THEN
    Produced := ( HIGH(Source)+1 ) << 1;
    Consumed := Produced >> 1;
    l := MIN2( Produced, HIGH( Destination )+1 );
    Strings.MoveW( ADR( Source ), ADR( Destination ), l );
    IF l <= HIGH( Destination ) THEN
      Destination[l] := 0;
    END;
    IF CodePage = cp_UTF16_BIG_ENDIAN THEN
      FOR i := 0 TO l-1 BY 2 DO
        PWCHAR( ADR( Destination[i] ))^ := WCHAR( WORD( Destination[i] ) AND 0FFH << 8 OR WORD( Destination[i] ) >> 8 );
      END; // FOR
    END; // IF
    RETURN TRUE;
  ELSE
    RETURN MLang.ToAStream( Source, CodePage, OUT Destination, OUT Consumed, OUT Produced );
  END;
END ToAStream;

//===========================================================================

PROCEDURE GetDefaultLanguage( Default : TDefaultLanguage ) : TLanguage;
BEGIN
  CASE Default OF
  | dlThread : RETURN winnls.GetThreadLocale();
  | dlUser : RETURN winnls.GetUserDefaultLCID();
  | dlSystem : RETURN winnls.GetSystemDefaultLCID();
  END;
  RETURN windows.LOCALE_SYSTEM_DEFAULT;
END GetDefaultLanguage;

//===========================================================================

END Languages.
