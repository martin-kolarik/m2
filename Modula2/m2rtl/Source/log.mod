IMPLEMENTATION MODULE log;

//=========================================================

IMPORT
  FIO,
  Strings,
  windows,
  winreg;

//=========================================================

CLASS IMPLEMENTATION CLogger;

//---------------------------------------------------------

  PUBLIC PROCEDURE Init( _Name : ARRAY OF WCHAR ) : CARDINAL;
  BEGIN
    ASSIGN( Name, _Name );
    RETURN 0;
  END Init;

//---------------------------------------------------------

  PUBLIC PROCEDURE Set( Method : TDebugMethod; Level : TDebugLevel; File : ARRAY OF WCHAR );
  BEGIN
    RStatus := RStatus - TRStatus{rsDebugKernel, rsDebugFile};
    DebugLevel := Level;
    IF Method = dmNone THEN
      // do nothing
    ELSIF Method = dmFile THEN
      INCL( RStatus, rsDebugFile );
      ASSIGN( DebugFile, File );
    ELSE
      INCL( RStatus, rsDebugKernel );
    END;
  END Set;

//---------------------------------------------------------

  PUBLIC PROCEDURE LogS( Level : TDebugLevel; Prefix, S : ARRAY OF WCHAR );
  BEGIN
    IF Filtered( Level ) THEN
      RETURN;
    END;
    Log( Prefix, S );
  END LogS;

//---------------------------------------------------------

  PUBLIC PROCEDURE LogSS( Level : TDebugLevel; Prefix, S1, S2 : ARRAY OF WCHAR );
  VAR
    S : ARRAY [0..511] OF WCHAR;
  BEGIN
    IF Filtered( Level ) THEN
      RETURN;
    END;
    Strings.ConcatW( OUT S, S1, S2 );
    Log( Prefix, S );
  END LogSS;

//---------------------------------------------------------

  PUBLIC PROCEDURE LogSC( Level : TDebugLevel; Prefix, S1 : ARRAY OF WCHAR; C : CARDINAL );
  VAR
    N : ARRAY [0..15] OF WCHAR;
    S : ARRAY [0..511] OF WCHAR;
  BEGIN
    IF Filtered( Level ) THEN
      RETURN;
    END;
    Strings.FromCARD32W( C, 10, OUT N );
    Strings.ConcatW( OUT S, S1, N );
    Log( Prefix, S );
  END LogSC;

//---------------------------------------------------------

  PUBLIC PROCEDURE LogSH( Level : TDebugLevel; Prefix, S1 : ARRAY OF WCHAR; C : CARDINAL );
  VAR
    N : ARRAY [0..15] OF WCHAR;
    S : ARRAY [0..511] OF WCHAR;
  BEGIN
    IF Filtered( Level ) THEN
      RETURN;
    END;
    Strings.FromCARD32W( C, 16, OUT N );
    Strings.ConcatW( OUT S, S1, N );
    Log( Prefix, S );
  END LogSH;

//---------------------------------------------------------

  PUBLIC PROCEDURE LogSP( Level : TDebugLevel; Prefix, S1 : ARRAY OF WCHAR; P : PTR );
  VAR
    N : ARRAY [0..31] OF WCHAR;
    S : ARRAY [0..511] OF WCHAR;
  BEGIN
    IF Filtered( Level ) THEN
      RETURN;
    END;
    Strings.FromCARD64W( CARD64( P ), 16, OUT N );
    Strings.ConcatW( OUT S, S1, N );
    Log( Prefix, S );
  END LogSP;

//---------------------------------------------------------

  PUBLIC PROCEDURE LogSCP( Level : TDebugLevel; Prefix, S1 : ARRAY OF WCHAR; C : CARDINAL; P : PTR );
  VAR
    N : ARRAY [0..31] OF WCHAR;
    S : ARRAY [0..511] OF WCHAR;
  BEGIN
    IF Filtered( Level ) THEN
      RETURN;
    END;
    Strings.FromCARD32W( C, 10, OUT N );
    Strings.ConcatW( OUT S, S1, N );
    Strings.AppendW( REF S, L" " );
    Strings.FromCARD64W( CARD64( P ), 16, OUT N );
    Strings.AppendW( REF S, N );
    Log( Prefix, S );
  END LogSCP;

//---------------------------------------------------------

  PUBLIC PROCEDURE LogSHP( Level : TDebugLevel; Prefix, S1 : ARRAY OF WCHAR; C : CARDINAL; P : PTR );
  VAR
    N : ARRAY [0..31] OF WCHAR;
    S : ARRAY [0..511] OF WCHAR;
  BEGIN
    IF Filtered( Level ) THEN
      RETURN;
    END;
    Strings.FromCARD32W( C, 16, OUT N );
    Strings.ConcatW( OUT S, S1, N );
    Strings.AppendW( REF S, L" " );
    Strings.FromCARD64W( CARD64( P ), 16, OUT N );
    Strings.AppendW( REF S, N );
    Log( Prefix, S );
  END LogSHP;

//---------------------------------------------------------

  PUBLIC PROCEDURE LogSB( Level : TDebugLevel; Prefix, S1 : ARRAY OF WCHAR; A : ADDRESS; Bytes : CARDINAL );
  TYPE
    TPC8 = POINTER TO CARD8;
  VAR
    c : CARDINAL;
    c8 : CARD8;
    S : ARRAY [0..511] OF WCHAR;
  BEGIN
    IF Filtered( Level ) THEN
      RETURN;
    END;
    ASSIGN( S, S1 );
    Strings.AppendW( REF S, L'[' );
    c := LENGTH( S );
    WHILE ( Bytes > 0 ) AND ( c < SIZE( S ) DIV SIZE( WCHAR ) - 4 ) DO // 3 characters + trailing zero
      c8 := TPC8( A )^ >> 4;
      IF c8 < 10 THEN
        S[c] := WCHAR( 48 + c8 );
      ELSE
        S[c] := WCHAR( 65 + c8 - 10 );
      END;
      INC( c );
      c8 := TPC8( A )^ AND 0FH;
      IF c8 < 10 THEN
        S[c] := WCHAR( 48 + c8 );
      ELSE
        S[c] := WCHAR( 65 + c8 - 10 );
      END;
      INC( c );
      S[c] := L' ';
      INC( c );
      INC( A );
      DEC( Bytes );
    END;
    S[c] := WCHAR( 0 );
    Strings.AppendW( REF S, L']' );
    Log( Prefix, S );
  END LogSB;

//---------------------------------------------------------

  PUBLIC PROCEDURE LogSCB( Level : TDebugLevel; Prefix, S1 : ARRAY OF WCHAR; C : CARDINAL; A : ADDRESS; Bytes : CARDINAL );
  TYPE
    TPC8 = POINTER TO CARD8;
  VAR
    c : CARDINAL;
    c8 : CARD8;
    N : ARRAY [0..15] OF WCHAR;
    S : ARRAY [0..511] OF WCHAR;
  BEGIN
    IF Filtered( Level ) THEN
      RETURN;
    END;
    Strings.FromCARD32W( C, 10, OUT N );
    Strings.ConcatW( OUT S, S1, N );
    Strings.AppendW( REF S, L' [' );
    c := LENGTH( S );
    WHILE ( Bytes > 0 ) AND ( c < SIZE( S ) DIV SIZE( WCHAR ) - 4 ) DO // 3 characters + trailing zero
      c8 := TPC8( A )^ >> 4;
      IF c8 < 10 THEN
        S[c] := WCHAR( 48 + c8 );
      ELSE
        S[c] := WCHAR( 65 + c8 - 10 );
      END;
      INC( c );
      c8 := TPC8( A )^ AND 0FH;
      IF c8 < 10 THEN
        S[c] := WCHAR( 48 + c8 );
      ELSE
        S[c] := WCHAR( 65 + c8 - 10 );
      END;
      INC( c );
      S[c] := L' ';
      INC( c );
      INC( A );
      DEC( Bytes );
    END;
    S[c] := WCHAR( 0 );
    Strings.AppendW( REF S, L']' );
    Log( Prefix, S );
  END LogSCB;

//---------------------------------------------------------

  PUBLIC PROCEDURE LogSSS( Level : TDebugLevel; Prefix, S1, S2, S3 : ARRAY OF WCHAR );
  VAR
    S : ARRAY [0..511] OF WCHAR;
  BEGIN
    IF Filtered( Level ) THEN
      RETURN;
    END;
    Strings.ConcatW( OUT S, S1, S2 );
    Strings.AppendW( REF S, S3 );
    Log( Prefix, S );
  END LogSSS;

//---------------------------------------------------------

  PUBLIC PROCEDURE LogSSSS( Level : TDebugLevel; Prefix, S1, S2, S3, S4 : ARRAY OF WCHAR );
  VAR
    S : ARRAY [0..511] OF WCHAR;
  BEGIN
    IF Filtered( Level ) THEN
      RETURN;
    END;
    Strings.ConcatW( OUT S, S1, S2 );
    Strings.AppendW( REF S, S3 );
    Strings.AppendW( REF S, S4 );
    Log( Prefix, S );
  END LogSSSS;

//---------------------------------------------------------

   PUBLIC PROCEDURE LogExc( Level : TDebugLevel; Prefix : ARRAY OF WCHAR; CONST e : Exceptions.CException );
	VAR
		S : ARRAY [0..511] OF WCHAR;
	BEGIN
      IF Filtered( Level ) THEN
         RETURN;
      END;
	   e.ToString( OUT S );
	   Log( Prefix, S );
	END LogExc;

//---------------------------------------------------------

   PRIVATE INLINE PROCEDURE Filtered( Level : TDebugLevel ) : BOOLEAN;
   BEGIN
      IF TRStatus{rsDebugFile, rsDebugKernel} * RStatus = TRStatus{} THEN
         RETURN TRUE;
      ELSE
         RETURN Level > DebugLevel;
      END;
   END Filtered;

//---------------------------------------------------------

  PRIVATE PROCEDURE Log( Prefix, S : ARRAY OF WCHAR );
  VAR
    f : FIO.File;
    SW : ARRAY [0..511] OF WCHAR;
    SA : ARRAY [0..511] OF CHAR;
    XW : ARRAY [0..63] OF WCHAR;
  BEGIN
    ASSIGN( SW, S );
    IF Prefix[0] = WCHAR( 0 ) THEN
      IF Name[0] = WCHAR( 0 ) THEN
        Strings.PrependW( REF SW, L': ' );
      ELSE
        ASSIGN( XW, Name );
        Strings.AppendW( REF XW, L']: ' );
        Strings.PrependW( REF XW, L'[' );
        Strings.PrependW( REF SW, XW );
      END;
    ELSE
      ASSIGN( XW, Prefix );
      Strings.AppendW( REF XW, L': ' );
      Strings.PrependW( REF SW, XW );
    END;
    IF rsDebugFile IN RStatus THEN
      DebugLock.Lock();
      f := FIO.AppendW( DebugFile, FIO.TFileShare{FIO.fsRead} );
      IF f = NIL THEN
        f := FIO.CreateW( DebugFile, FIO.TFileShare{FIO.fsRead} );
      END; // IF
      IF f <> NIL THEN
        Strings.ToA( SW, 0, OUT SA );
        FIO.WrStrA( f, SA ); 
        FIO.WrLnA( f );
        FIO.Flush( f );
        FIO.Close( f );
      END; // IF 
      DebugLock.Unlock();
    END;
    IF rsDebugKernel IN RStatus THEN
      Strings.AppendW( REF SW, WCHAR( 13 ) + WCHAR( 10 ));
      windows.OutputDebugStringW( ADR( SW ));
    END;
  END Log;

//---------------------------------------------------------

   INITIALLY CLogger;
   CONST
      keyJoin   = L"join";
      keyTarget = L"target";
         valKernel = L"kernel";
         valFile   = L"file";
      keyFile   = L"file";
      keyLevel  = L"level";
         valSystemError = L"fatal";
         valError       = L"error";
         valWarning     = L"warning";
         valInfo        = L"info";
   VAR
      DataSize : CARDINAL;
      DLLName : ARRAY [0..255] OF WCHAR;
      hkey : winreg.HKEY;
      Key, Data : ARRAY [0..511] OF WCHAR;
      PData : PBYTE := PBYTE( ADR( Data ));
      RegType : CARDINAL;
      res : CARDINAL;
   BEGIN
      DebugLock.Init( Sync.ltCS, L"", FALSE );

      RStatus := TRStatus{rsDebugFile};
      #if DEBUG #then
         DebugLevel := dl3;
      #else
         DebugLevel := dl1;
      #endif
      Name[0] := 0W;

      #if #not #defined LIBRARY #then
         RStatus := TRStatus{rsDebugKernel};
      #else
         DebugFile := LIBRARY + L".log";
         DLLName := LIBRARY;

         // try to overwrite defaults
         LOOP
            Strings.ConcatW( OUT Key, L"SOFTWARE\" + Manufacturer + "\Log\", DLLName );
            res := winreg.RegOpenKeyExW( winreg.HKEY_CURRENT_USER, ADR( Key ), 0, windows.KEY_READ, ADR( hkey ));
            IF res <> 0 THEN // key does not exists, try HKLM
               res := winreg.RegOpenKeyExW( winreg.HKEY_LOCAL_MACHINE, ADR( Key ), 0, windows.KEY_READ, ADR( hkey ));
            END;
            IF res <> 0 THEN // key not found
               EXIT;
            END;

            // read data
            DataSize := SIZE( Data );
            IF ( winreg.RegQueryValueExW( hkey, keyJoin, NIL, ADR( RegType ), PData, ADR( DataSize )) = 0 ) AND ( RegType = windows.REG_SZ ) THEN
               // redirect to another settings
               ASSIGNsz( DLLName, PWCHAR( PData ));

               winreg.RegCloseKey( hkey );
               CONTINUE;
            END;
            DataSize := SIZE( Data );
            IF ( winreg.RegQueryValueExW( hkey, keyTarget, NIL, ADR( RegType ), PData, ADR( DataSize )) = 0 ) AND ( RegType = windows.REG_SZ ) THEN
               IF EQUALS( OAsz( PWCHAR( PData )), valKernel ) THEN
                  RStatus := TRStatus{rsDebugKernel};
               ELSIF EQUALS( OAsz( PWCHAR( PData )), valFile ) THEN
                  RStatus := TRStatus{rsDebugFile};
               END;
            END;
            DataSize := SIZE( Data );
            IF ( winreg.RegQueryValueExW( hkey, keyFile, NIL, ADR( RegType ), PData, ADR( DataSize )) = 0 ) AND ( RegType = windows.REG_SZ ) THEN
               ASSIGNsz( DebugFile, PWCHAR( PData ));
            END;
            DataSize := SIZE( Data );
            IF ( winreg.RegQueryValueExW( hkey, keyLevel, NIL, ADR( RegType ), PData, ADR( DataSize )) = 0 ) AND ( RegType = windows.REG_SZ ) THEN
               IF EQUALS( OAsz( PWCHAR( PData )), valSystemError ) THEN
                  DebugLevel := dl1;
               ELSIF EQUALS( OAsz( PWCHAR( PData )), valError ) THEN
                  DebugLevel := dl2;
               ELSIF EQUALS( OAsz( PWCHAR( PData )), valWarning ) THEN
                  DebugLevel := dl3;
               ELSIF EQUALS( OAsz( PWCHAR( PData )), valInfo ) THEN
                  DebugLevel := dl4;
               END;
            END;

            winreg.RegCloseKey( hkey );
            EXIT;
         END; // LOOP
      #endif
   END CLogger;

END CLogger;

//=========================================================

VAR
   Logger : CLogger; // default logger

PROCEDURE logger() : TPLogger;
BEGIN
   RETURN ADR( Logger );
END logger;


//=========================================================

END log.