IMPLEMENTATION MODULE log;

//=========================================================

FROM Strings IMPORT
  LowerizeW;

IMPORT
  FIO,
  Strings,
  time,
  windows,
  winreg;

//=========================================================

CLASS IMPLEMENTATION CLogger;

//---------------------------------------------------------

   PUBLIC PROPERTY Method GET : TDebugMethod;
   BEGIN
      IF rsDebugKernel IN RStatus THEN
         RETURN dmKernel;
      ELSIF rsDebugFile IN RStatus THEN
         RETURN dmFile;
      ELSE
         RETURN dmNone;
      END;
   END Method;

//---------------------------------------------------------

   PUBLIC PROPERTY Method SET( Value : TDebugMethod );
   BEGIN
      RStatus := RStatus - TRStatus{rsDebugKernel, rsDebugFile};
      IF Value = dmNone THEN
         // do nothing
      ELSIF Value = dmFile THEN
         ASSERT( DebugFile[0] <> 0W );
         INCL( RStatus, rsDebugFile );
      ELSE
         INCL( RStatus, rsDebugKernel );
      END;
   END Method;

//---------------------------------------------------------

   PUBLIC PROPERTY Level GET : TDebugLevel;
   BEGIN
      RETURN DebugLevel;
   END Level;

//---------------------------------------------------------

   PUBLIC PROPERTY Level SET( Value : TDebugLevel );
   BEGIN
      DebugLevel := Value;
   END Level;

//---------------------------------------------------------

   PUBLIC PROPERTY TimeStamps GET : BOOLEAN;
   BEGIN
      RETURN rsTimeStamps IN RStatus;
   END TimeStamps;

//---------------------------------------------------------

   PUBLIC PROPERTY TimeStamps SET( Value : BOOLEAN );
   BEGIN
      IF Value THEN
         INCL( RStatus, rsTimeStamps );
      ELSE
         EXCL( RStatus, rsTimeStamps );
      END;
   END TimeStamps;

//---------------------------------------------------------

   PUBLIC PROCEDURE SetLogName( CONST Name : ARRAY OF WCHAR );
   BEGIN
      ASSIGN( SELF.Name, Name );
   END SetLogName;

//---------------------------------------------------------

   PUBLIC PROCEDURE GetLogName( OUT Name : ARRAY OF WCHAR ) : BOOLEAN;
   BEGIN
      IF Name[0] = 0W THEN
         RETURN FALSE;
      END;
      ASSIGN( Name, SELF.Name );
      RETURN TRUE;
   END GetLogName;

//---------------------------------------------------------

   PUBLIC PROCEDURE SetLogFile( CONST LogFile : ARRAY OF WCHAR );
   BEGIN
      ASSIGN( DebugFile, LogFile );
      IF DebugFile[0] = 0W THEN
         RStatus := RStatus - TRStatus{rsDebugFile} + TRStatus{rsDebugKernel};
      END;
   END SetLogFile;

//---------------------------------------------------------

   PUBLIC PROCEDURE GetLogFile( OUT LogFile : ARRAY OF WCHAR ) : BOOLEAN;
   BEGIN
      IF DebugFile[0] = 0W THEN
         RETURN FALSE;
      END;
      ASSIGN( LogFile, DebugFile );
      RETURN TRUE;
   END GetLogFile;

//---------------------------------------------------------

   PUBLIC PROCEDURE SetUpByRegistry( CONST LibraryName : ARRAY OF WCHAR ) : BOOLEAN;
   BEGIN
      RETURN LoadByRegistry( LibraryName );
   END SetUpByRegistry;

//---------------------------------------------------------

   PUBLIC PROCEDURE Filtered( Level : TDebugLevel ) : BOOLEAN;
   BEGIN
      IF TRStatus{rsDebugFile, rsDebugKernel} * RStatus = TRStatus{} THEN
         RETURN TRUE;
      ELSE
         RETURN Level > DebugLevel;
      END;
   END Filtered;

//---------------------------------------------------------

  PUBLIC PROCEDURE LogS( Level : TDebugLevel; Prefix, S : ARRAY OF WCHAR );
  BEGIN
    IF Filtered( Level ) THEN
      RETURN;
    END;
    Log( Level, Prefix, S );
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
    Log( Level, Prefix, S );
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
    Log( Level, Prefix, S );
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
    Log( Level, Prefix, S );
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
    Log( Level, Prefix, S );
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
    Log( Level, Prefix, S );
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
    Log( Level, Prefix, S );
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
    Log( Level, Prefix, S );
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
    Log( Level, Prefix, S );
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
    Log( Level, Prefix, S );
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
    Log( Level, Prefix, S );
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
	   Log( Level, Prefix, S );
	END LogExc;

//---------------------------------------------------------

  INTERNAL VIRTUAL PROCEDURE Log( LoggedLevel : TDebugLevel; CONST Prefix, S : ARRAY OF WCHAR );
  VAR
    dt : time.TDateTime;
    f : FIO.File;
    SW : ARRAY [0..511] OF WCHAR;
    SA : ARRAY [0..511] OF CHAR;
  BEGIN
    IF rsTimeStamps IN RStatus THEN
      time.GetCurrentUTCDateTime( dt );
      time.DateTimeToString( dt, L"[yyyy-MM-dd HH:mm:ss.f] ", TRUE, TRUE, OUT SW );
    ELSE
      SW := L"";
    END;
    CASE LoggedLevel OF
    | dl1 : Strings.AppendW( REF SW, L"F " );
    | dl2 : Strings.AppendW( REF SW, L"E " );
    | dl3 : Strings.AppendW( REF SW, L"W " );
    | dl4 : Strings.AppendW( REF SW, L"I " );
    END;
    IF Name[0] <> 0W THEN
      Strings.AppendW( REF SW, Name );
    END;
    IF Prefix[0] <> 0W THEN
      Strings.AppendW( REF SW, L"/" ); Strings.AppendW( REF SW, Prefix );
    END;
    Strings.AppendW( REF SW, L": " ); 
    Strings.AppendW( REF SW, S ); 

    OnLogOutputString( SW );
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

   INTERNAL VIRTUAL PROCEDURE OnLogOutputString( CONST OutputString : ARRAY OF WCHAR );
   BEGIN
   END OnLogOutputString;

//---------------------------------------------------------

   PRIVATE PROCEDURE LoadByRegistry( CONST LibraryName : ARRAY OF WCHAR ) : BOOLEAN;
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
      keyTimeStamps = L"timestamps";
         valTrue = L"true";
         valFalse = L"false";
   VAR
      DataSize : CARDINAL;
      Dir : FIO.PathStrW;
      hkey : winreg.HKEY;
      Key, Data : ARRAY [0..511] OF WCHAR;
      LLibraryName : ARRAY [0..255] OF WCHAR;
      PData : PBYTE := PBYTE( ADR( Data ));
      RegType : CARDINAL;
      res : CARDINAL;
   BEGIN
      LLibraryName := LibraryName;

      // defaults
      RStatus := TRStatus{rsDebugKernel, rsTimeStamps};
      Strings.ConcatW( OUT DebugFile, LibraryName, L".log" );
      #if DEBUG #then
         DebugLevel := dl3;
      #else
         DebugLevel := dl1;
      #endif

      LOOP
         Strings.ConcatW( OUT Key, L"SOFTWARE\" + Manufacturer + "\Log\", LLibraryName );
         res := winreg.RegOpenKeyExW( winreg.HKEY_CURRENT_USER, ADR( Key ), 0, windows.KEY_READ, ADR( hkey ));
         IF res <> 0 THEN // key does not exists, try HKLM
            res := winreg.RegOpenKeyExW( winreg.HKEY_LOCAL_MACHINE, ADR( Key ), 0, windows.KEY_READ, ADR( hkey ));
         END;
         IF res <> 0 THEN // key not found
            RETURN FALSE;
         END;

         // read data
         DataSize := SIZE( Data );
         IF ( winreg.RegQueryValueExW( hkey, keyJoin, NIL, ADR( RegType ), PData, ADR( DataSize )) = 0 ) AND ( RegType = windows.REG_SZ ) THEN
            // redirect to another settings
            ASSIGNsz( LLibraryName, PWCHAR( PData ));

            winreg.RegCloseKey( hkey );
            CONTINUE;
         END;

         DataSize := SIZE( Data );
         IF ( winreg.RegQueryValueExW( hkey, keyTarget, NIL, ADR( RegType ), PData, ADR( DataSize )) = 0 ) AND ( RegType = windows.REG_SZ ) THEN
            LOW( OAsz( PWCHAR( PData )));
            IF EQUALS( OAsz( PWCHAR( PData )), valKernel ) THEN
               RStatus := RStatus - TRStatus{rsDebugFile} + TRStatus{rsDebugKernel};
            ELSIF EQUALS( OAsz( PWCHAR( PData )), valFile ) THEN
               RStatus := RStatus - TRStatus{rsDebugKernel} + TRStatus{rsDebugFile};
            END;
         END;

         DataSize := SIZE( Data );
         IF ( winreg.RegQueryValueExW( hkey, keyTarget, NIL, ADR( RegType ), PData, ADR( DataSize )) = 0 ) AND ( RegType = windows.REG_SZ ) THEN
            LOW( OAsz( PWCHAR( PData )));
            IF EQUALS( OAsz( PWCHAR( PData )), valTrue ) THEN
               RStatus := RStatus + TRStatus{rsTimeStamps};
            ELSIF EQUALS( OAsz( PWCHAR( PData )), valFalse ) THEN
               RStatus := RStatus - TRStatus{rsTimeStamps};
            END;
         END;

         DataSize := SIZE( Data );
         IF ( winreg.RegQueryValueExW( hkey, keyFile, NIL, ADR( RegType ), PData, ADR( DataSize )) = 0 ) AND ( RegType = windows.REG_SZ ) THEN
            ASSIGNsz( DebugFile, PWCHAR( PData ));
         ELSE
            FIO.GetModuleDirW( EMITW( %dll ), OUT Dir );
            IF Dir[0] = 0W THEN
               FIO.GetModuleDirW( L"", OUT Dir );
            END;
            FIO.MakePathW( Dir, DebugFile, OUT DebugFile );
         END;

         DataSize := SIZE( Data );
         IF ( winreg.RegQueryValueExW( hkey, keyLevel, NIL, ADR( RegType ), PData, ADR( DataSize )) = 0 ) AND ( RegType = windows.REG_SZ ) THEN
            LOW( OAsz( PWCHAR( PData )));
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
         RETURN TRUE;
      END; // LOOP
   END LoadByRegistry;

//---------------------------------------------------------

BEGIN
   DebugLock.Init( Sync.ltCS, L"", FALSE );

   RStatus := TRStatus{rsDebugKernel, rsTimeStamps};
   #if DEBUG #then
      DebugLevel := dl3;
   #else
      DebugLevel := dl1;
   #endif
   Name[0] := 0W;
   DebugFile := 0W;

   #if #defined LIBRARY #then
      LoadByRegistry( LIBRARY );
   #endif
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