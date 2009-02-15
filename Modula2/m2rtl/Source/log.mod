IMPLEMENTATION MODULE log;

//=========================================================

FROM Debug IMPORT
   Assertion;

FROM Storage IMPORT
   REALLOCATE;

FROM Strings IMPORT
   LowerizeW;

IMPORT
   FIO,
   Strings,
   time,
   windows,
   winreg;

//=========================================================

CONST
   strlen = 512;
TYPE
   TString = ARRAY [0..strlen-1] OF WCHAR;
   TNum = ARRAY [0..31] OF WCHAR;

//=========================================================

CLASS CBuffer;
   PRIVATE VAR
      _W : Sync.WriteBuffer;
      _Data : POINTER TO ARRAY [0..0] OF TString := NIL;

   LOCAL PROPERTY
      Size : CARDINAL;
   LOCAL READONLY PROPERTY
      Count : CARDINAL;
   LOCAL PROCEDURE GetItem( Index : CARDINAL; OUT S : ARRAY OF WCHAR ) : BOOLEAN; // Index = 0 means first
   LOCAL PROCEDURE Clear();
   
   LOCAL PROCEDURE Store( OverWrite : BOOLEAN; CONST S : ARRAY OF WCHAR );
END CBuffer;

//=========================================================

CLASS IMPLEMENTATION CBuffer;

//---------------------------------------------------------

   LOCAL PROPERTY Size GET : CARDINAL;
   BEGIN
      RETURN _W.Size;
   END Size;

//---------------------------------------------------------

   LOCAL PROPERTY Size SET( Value : CARDINAL );
   BEGIN
      _W.Size := Value;
      REALLOCATE( _Data, _W.Size * SIZE( TString )); 
   END Size;

//---------------------------------------------------------

   LOCAL PROPERTY Count GET : CARDINAL;
   BEGIN
      RETURN _W.Count;
   END Count;

//---------------------------------------------------------

   LOCAL PROCEDURE GetItem( Index : CARDINAL; OUT S : ARRAY OF WCHAR ) : BOOLEAN; // Index = 0 means first
   VAR
      ReadFrom : CARDINAL;
   BEGIN
      IF NOT _W.StartReading( Index, OUT ReadFrom ) THEN
         RETURN FALSE;
      END;
      S := _Data^[ ReadFrom ];
      _W.CommitReading();
      RETURN TRUE;
   END GetItem;

//---------------------------------------------------------

   LOCAL PROCEDURE Clear();
   BEGIN
      _W.Clear();
   END Clear;

//---------------------------------------------------------

   LOCAL PROCEDURE Store( Overwrite : BOOLEAN; CONST S : ARRAY OF WCHAR );
   VAR
      ProduceTo : CARDINAL;
   BEGIN
      IF _Data = NIL THEN
         ASSERT( FALSE );
      ELSIF _W.StartProducing( Overwrite, OUT ProduceTo ) THEN
         _Data^[ ProduceTo ] := S;
         _W.CommitProducing();
      END;
   END Store;

//---------------------------------------------------------

BEGIN
FINALLY
   DISPOSE( _Data );
END CBuffer;

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

   PUBLIC PROPERTY Levels GET : BOOLEAN;
   BEGIN
      RETURN rsLevelInfo IN RStatus;
   END Levels;

//---------------------------------------------------------

   PUBLIC PROPERTY Levels SET( Value : BOOLEAN );
   BEGIN
      IF Value THEN
         INCL( RStatus, rsLevelInfo );
      ELSE
         EXCL( RStatus, rsLevelInfo );
      END;
   END Levels;

//---------------------------------------------------------

   PUBLIC PROPERTY Names GET : BOOLEAN;
   BEGIN
      RETURN rsNameInfo IN RStatus;
   END Names;

//---------------------------------------------------------

   PUBLIC PROPERTY Names SET( Value : BOOLEAN );
   BEGIN
      IF Value THEN
         INCL( RStatus, rsNameInfo );
      ELSE
         EXCL( RStatus, rsNameInfo );
      END;
   END Names;

//---------------------------------------------------------

   PUBLIC PROPERTY Buffered GET : BOOLEAN;
   BEGIN
      RETURN Buffer = NIL;
   END Buffered;

//---------------------------------------------------------

   PUBLIC PROPERTY Buffered SET( Value : BOOLEAN );
   BEGIN
      IF Value = ( Buffer = NIL ) THEN
         IF Value THEN
            BufferSize := 100;
         ELSE
            DISPOSE( Buffer );
         END;
      END;
   END Buffered;

//---------------------------------------------------------

   PUBLIC PROPERTY BufferSize GET : CARDINAL;
   BEGIN
      IF Buffer = NIL THEN
         RETURN 0;
      ELSE
         RETURN Buffer^.Size;
      END;
   END BufferSize;

//---------------------------------------------------------

   PUBLIC PROPERTY BufferSize SET( Value : CARDINAL );
   BEGIN
      IF Buffer = NIL THEN
         NEW( Buffer );
      END;
      Buffer^.Size := Value;
   END BufferSize;

//---------------------------------------------------------

   PUBLIC PROPERTY BufferMode GET : TBufferMode;
   BEGIN
      RETURN _BufferMode;
   END BufferMode;

//---------------------------------------------------------

   PUBLIC PROPERTY BufferMode SET( Value : TBufferMode );
   BEGIN
      _BufferMode := Value;
   END BufferMode;

//---------------------------------------------------------

   PUBLIC PROPERTY RedirectTo GET : TPLogger;
   BEGIN
      RETURN _RedirectTo;
   END RedirectTo;

//---------------------------------------------------------

   PUBLIC PROPERTY RedirectTo SET( Value : TPLogger );
   BEGIN
      _RedirectTo := Value;
   END RedirectTo;

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

   PUBLIC PROCEDURE SetUpByLogger( CONST Logger : CLogger ) : BOOLEAN; // gets config from another existing logger
   BEGIN
      RETURN LoadByLogger( Logger );
   END SetUpByLogger;

//---------------------------------------------------------

   PUBLIC PROCEDURE Filtered( Level : TDebugLevel ) : BOOLEAN;
   BEGIN
      RETURN Level > DebugLevel;
   END Filtered;

//---------------------------------------------------------

  PUBLIC PROCEDURE LogS( Level : TDebugLevel; Prefix, S : ARRAY OF WCHAR );
  BEGIN
    IF Filtered( Level ) THEN
      RETURN;
    END;
    Log( Level, Name, Prefix, S );
  END LogS;

//---------------------------------------------------------

  PUBLIC PROCEDURE LogSS( Level : TDebugLevel; Prefix, S1, S2 : ARRAY OF WCHAR );
  VAR
    S : TString;
  BEGIN
    IF Filtered( Level ) THEN
      RETURN;
    END;
    Strings.ConcatW( OUT S, S1, S2 );
    Log( Level, Name, Prefix, S );
  END LogSS;

//---------------------------------------------------------

  PUBLIC PROCEDURE LogSE( Level : TDebugLevel; Prefix, S1 : ARRAY OF WCHAR; ErrorCode : CARDINAL );
  VAR
    E : TString;
    S : TString;
  BEGIN
    IF Filtered( Level ) THEN
      RETURN;
    END;
    Strings.FromErrorW( ErrorCode, OUT E );
    Strings.ConcatW( OUT S, S1, E );
    Log( Level, Name, Prefix, S );
  END LogSE;

//---------------------------------------------------------

  PUBLIC PROCEDURE LogSR( Level : TDebugLevel; Prefix, S1 : ARRAY OF WCHAR; Result : Sync.TAsyncResult );
  VAR
    S : TString;
  BEGIN
    IF Filtered( Level ) THEN
      RETURN;
    ELSIF NOT Sync.ResultToName( Result, OUT S ) THEN
      ASSERT( FALSE );
      RETURN;
    END;
    Log( Level, Name, Prefix, S );
  END LogSR;

//---------------------------------------------------------

  PUBLIC PROCEDURE LogSC( Level : TDebugLevel; Prefix, S1 : ARRAY OF WCHAR; C : CARDINAL );
  VAR
    N : TNum;
    S : TString;
  BEGIN
    IF Filtered( Level ) THEN
      RETURN;
    END;
    Strings.FromCARD32W( C, 10, OUT N );
    Strings.ConcatW( OUT S, S1, N );
    Log( Level, Name, Prefix, S );
  END LogSC;

//---------------------------------------------------------

  PUBLIC PROCEDURE LogSH( Level : TDebugLevel; Prefix, S1 : ARRAY OF WCHAR; C : CARDINAL );
  VAR
    N : TNum;
    S : TString;
  BEGIN
    IF Filtered( Level ) THEN
      RETURN;
    END;
    Strings.FromCARD32W( C, 16, OUT N );
    Strings.ConcatW( OUT S, S1, N );
    Log( Level, Name, Prefix, S );
  END LogSH;

//---------------------------------------------------------

  PUBLIC PROCEDURE LogSP( Level : TDebugLevel; Prefix, S1 : ARRAY OF WCHAR; P : PTR );
  VAR
    N : TNum;
    S : TString;
  BEGIN
    IF Filtered( Level ) THEN
      RETURN;
    END;
    Strings.FromCARD64W( CARD64( P ), 16, OUT N );
    Strings.ConcatW( OUT S, S1, N );
    Log( Level, Name, Prefix, S );
  END LogSP;

//---------------------------------------------------------

  PUBLIC PROCEDURE LogSCP( Level : TDebugLevel; Prefix, S1 : ARRAY OF WCHAR; C : CARDINAL; P : PTR );
  VAR
    N : TNum;
    S : TString;
  BEGIN
    IF Filtered( Level ) THEN
      RETURN;
    END;
    Strings.FromCARD32W( C, 10, OUT N );
    Strings.ConcatW( OUT S, S1, N );
    Strings.AppendW( REF S, L" " );
    Strings.FromCARD64W( CARD64( P ), 16, OUT N );
    Strings.AppendW( REF S, N );
    Log( Level, Name, Prefix, S );
  END LogSCP;

//---------------------------------------------------------

  PUBLIC PROCEDURE LogSHP( Level : TDebugLevel; Prefix, S1 : ARRAY OF WCHAR; C : CARDINAL; P : PTR );
  VAR
    N : TNum;
    S : TString;
  BEGIN
    IF Filtered( Level ) THEN
      RETURN;
    END;
    Strings.FromCARD32W( C, 16, OUT N );
    Strings.ConcatW( OUT S, S1, N );
    Strings.AppendW( REF S, L" " );
    Strings.FromCARD64W( CARD64( P ), 16, OUT N );
    Strings.AppendW( REF S, N );
    Log( Level, Name, Prefix, S );
  END LogSHP;

//---------------------------------------------------------

  PUBLIC PROCEDURE LogSB( Level : TDebugLevel; Prefix, S1 : ARRAY OF WCHAR; A : ADDRESS; Bytes : CARDINAL );
  TYPE
    TPC8 = POINTER TO CARD8;
  VAR
    c : CARDINAL;
    c8 : CARD8;
    S : TString;
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
    Log( Level, Name, Prefix, S );
  END LogSB;

//---------------------------------------------------------

  PUBLIC PROCEDURE LogSCB( Level : TDebugLevel; Prefix, S1 : ARRAY OF WCHAR; C : CARDINAL; A : ADDRESS; Bytes : CARDINAL );
  TYPE
    TPC8 = POINTER TO CARD8;
  VAR
    c : CARDINAL;
    c8 : CARD8;
    N : TNum;
    S : TString;
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
    Log( Level, Name, Prefix, S );
  END LogSCB;

//---------------------------------------------------------

  PUBLIC PROCEDURE LogSSS( Level : TDebugLevel; Prefix, S1, S2, S3 : ARRAY OF WCHAR );
  VAR
    S : TString;
  BEGIN
    IF Filtered( Level ) THEN
      RETURN;
    END;
    Strings.ConcatW( OUT S, S1, S2 );
    Strings.AppendW( REF S, S3 );
    Log( Level, Name, Prefix, S );
  END LogSSS;

//---------------------------------------------------------

  PUBLIC PROCEDURE LogSSSS( Level : TDebugLevel; Prefix, S1, S2, S3, S4 : ARRAY OF WCHAR );
  VAR
    S : TString;
  BEGIN
    IF Filtered( Level ) THEN
      RETURN;
    END;
    Strings.ConcatW( OUT S, S1, S2 );
    Strings.AppendW( REF S, S3 );
    Strings.AppendW( REF S, S4 );
    Log( Level, Name, Prefix, S );
  END LogSSSS;

//---------------------------------------------------------

   PUBLIC PROCEDURE LogExc( Level : TDebugLevel; Prefix : ARRAY OF WCHAR; CONST e : Exceptions.CException );
	VAR
		S : TString;
	BEGIN
      IF Filtered( Level ) THEN
         RETURN;
      END;
	   e.ToString( OUT S );
	   Log( Level, Name, Prefix, S );
	END LogExc;

//---------------------------------------------------------

   PUBLIC PROCEDURE LogFilePos( Level : TDebugLevel; Prefix : ARRAY OF WCHAR; Path, S1 : ARRAY OF WCHAR; Line, Col : CARDINAL ); // Line, Col = 0/-1 means unused, unknown
	VAR
	   colFlag, lineFlag : BOOLEAN;
		S : TString;
      N : TNum;
   BEGIN
      IF Filtered( Level ) THEN
         RETURN;
      END;

      S := Path;
      lineFlag := ( Line <> 0 ) AND ( Line <> -1 );
      colFlag := ( Col <> 0 ) AND ( Col <> -1 );
      IF colFlag OR lineFlag THEN
         Strings.AppendW( REF S, L"(" );
         IF lineFlag THEN
            Strings.FromCARD32W( Line, 10, OUT N );
            Strings.AppendW( REF S, N );
            IF colFlag THEN
               Strings.AppendW( REF S, L"," );
            END;
         END;
         IF colFlag THEN
            Strings.FromCARD32W( Col, 10, OUT N );
            Strings.AppendW( REF S, N );
         END;
         Strings.AppendW( REF S, L"): " );
      ELSE
         Strings.AppendW( REF S, L": " );
      END;
      Strings.AppendW( REF S, S1 );
      
      Log( Level, Name, Prefix, S );
   END LogFilePos;

//---------------------------------------------------------

   PUBLIC PROPERTY BufferCount GET : CARDINAL;
   BEGIN
      IF Buffer = NIL THEN
         RETURN 0;
      ELSE
         RETURN Buffer^.Count;
      END;
   END BufferCount;

//---------------------------------------------------------

   PUBLIC PROCEDURE BufferGetItem( Index : CARDINAL; OUT S : ARRAY OF WCHAR ) : BOOLEAN; // Index = 0 means first
   BEGIN
      IF Buffer = NIL THEN
         RETURN FALSE;
      ELSE
         RETURN Buffer^.GetItem( Index, OUT S );
      END;
   END BufferGetItem;

//---------------------------------------------------------

   PUBLIC PROCEDURE BufferClear();
   BEGIN
      IF Buffer <> NIL THEN
         Buffer^.Clear();
      END;
   END BufferClear;

//---------------------------------------------------------

  INTERNAL VIRTUAL PROCEDURE Log( LoggedLevel : TDebugLevel; CONST _Name, Prefix, S : ARRAY OF WCHAR );
  VAR
    dt : time.TDateTime;
    f : FIO.File;
    leading : BOOLEAN := FALSE;
    SW : TString;
    SA : ARRAY [0..strlen-1] OF CHAR;
  BEGIN
    IF _RedirectTo <> NIL THEN
      _RedirectTo^.Log( LoggedLevel, _Name, Prefix, S );
      RETURN;
    END;

    SW := L"";
    IF rsTimeStamps IN RStatus THEN
      leading := TRUE;
      time.GetCurrentUTCDateTime( dt );
      time.DateTimeToString( dt, L"[yyyy-MM-dd HH:mm:ss.fff] ", TRUE, TRUE, OUT SW );
    END;
    IF rsLevelInfo IN RStatus THEN
      leading := TRUE;
      CASE LoggedLevel OF
      | dlcSysError : Strings.AppendW( REF SW, L"F " );
      | dldError : Strings.AppendW( REF SW, L"e " );
      | dlcError : Strings.AppendW( REF SW, L"E " );
      | dldMessage : Strings.AppendW( REF SW, L"m " );
      | dlcWarning : Strings.AppendW( REF SW, L"W " );
      | dldTrace : Strings.AppendW( REF SW, L"t " );
      | dlcInfo : Strings.AppendW( REF SW, L"I " );
      | dldDebug : Strings.AppendW( REF SW, L"d " );
      END;
    END;
    IF rsNameInfo IN RStatus THEN
      leading := TRUE;
      IF _Name[0] <> 0W THEN
        Strings.AppendW( REF SW, _Name );
      END;
      IF Prefix[0] <> 0W THEN
        Strings.AppendW( REF SW, L"/" ); Strings.AppendW( REF SW, Prefix );
      END;
    END;
    IF leading THEN
      Strings.AppendW( REF SW, L": " ); 
    END;
    Strings.AppendW( REF SW, S ); 

    IF Buffer <> NIL THEN
      Buffer^.Store( _BufferMode = bmStoreLast, SW );
    END;
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
      Key, Data : TString;
      LLibraryName : TString;
      PData : PBYTE := PBYTE( ADR( Data ));
      RegType : CARDINAL;
      res : CARDINAL;
   BEGIN
      LLibraryName := LibraryName;

      // defaults
      RStatus := TRStatus{rsDebugKernel, rsTimeStamps, rsNameInfo, rsLevelInfo};
      Strings.ConcatW( OUT DebugFile, LibraryName, L".log" );
      #if DEBUG #then
         DebugLevel := dldTrace;
      #else
         DebugLevel := dldError;
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
         IF ( winreg.RegQueryValueExW( hkey, keyTimeStamps, NIL, ADR( RegType ), PData, ADR( DataSize )) = 0 ) AND ( RegType = windows.REG_SZ ) THEN
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
               DebugLevel := dldError;
            ELSIF EQUALS( OAsz( PWCHAR( PData )), valError ) THEN
               DebugLevel := dldMessage;
            ELSIF EQUALS( OAsz( PWCHAR( PData )), valWarning ) THEN
               DebugLevel := dldTrace;
            ELSIF EQUALS( OAsz( PWCHAR( PData )), valInfo ) THEN
               DebugLevel := dldDebug;
            END;
         END;

         winreg.RegCloseKey( hkey );
         RETURN TRUE;
      END; // LOOP
   END LoadByRegistry;

//---------------------------------------------------------

   PRIVATE PROCEDURE LoadByLogger( CONST Logger : CLogger ) : BOOLEAN;
   VAR
      bufferSize : CARDINAL;
   BEGIN
      SELF.RStatus := Logger.RStatus;
      SELF.Name := Logger.Name;
      SELF.DebugLevel := Logger.DebugLevel;
      SELF.DebugFile := Logger.DebugFile;
      bufferSize := Logger.BufferSize;
      IF bufferSize > 0 THEN
         SELF.BufferSize := bufferSize;
      END;
      RETURN TRUE;
   END LoadByLogger;

//---------------------------------------------------------

BEGIN
   DebugLock.Init( Sync.ltSpin, L"", FALSE );

   RStatus := TRStatus{rsDebugKernel, rsTimeStamps, rsLevelInfo, rsNameInfo};
   #if DEBUG #then
      DebugLevel := dldTrace;
   #else
      DebugLevel := dldError;
   #endif
   Name := L"sys";
   DebugFile := 0W;
   Buffer := NIL;

   #if #defined LIBRARY #then
      LoadByRegistry( LIBRARY );
   #endif
FINALLY
   DISPOSE( Buffer );
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
