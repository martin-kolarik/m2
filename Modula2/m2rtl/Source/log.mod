IMPLEMENTATION MODULE log;

(*===========================================================================*)

FROM Debug IMPORT
   Assertion, LogAssertionW;

FROM Storage IMPORT
   REALLOCATE;

FROM Strings IMPORT
   LowerizeW;

IMPORT
   FIO,
   folders,
   Strings,
   time,
   windows,
   winreg;

(*===========================================================================*)

CONST
   strlen = 1023;
TYPE
   TString = ARRAY [0..strlen-1] OF WCHAR;
   TNum = ARRAY [0..31] OF WCHAR;

(*===========================================================================*)

CLASS IMPLEMENTATION CLevelAndBitsFilter;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE FilteredFastCheck( Level : TLevel ) : BOOLEAN;
   BEGIN
      RETURN Level > _Level;
   END FilteredFastCheck;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE FilteredFullCheck( Level : TLevel; FilterData : PTR; CONST Logger, Prefix, Message : ARRAY OF WCHAR ) : BOOLEAN;
   BEGIN
      IF Level > _Level THEN
         RETURN TRUE;
      ELSIF FilterData = 0 THEN
         RETURN FALSE;
      ELSIF FilterData AND _AllowedFilterDataBits = 0 THEN
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END FilteredFullCheck;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Level GET : TLevel;
   BEGIN
      RETURN _Level;
   END Level;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Level SET( Value : TLevel );
   BEGIN
      _Level := Value;
   END Level;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY AllowedFilterDataBits GET : PTR;
   BEGIN
      RETURN _AllowedFilterDataBits;
   END AllowedFilterDataBits;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY AllowedFilterDataBits SET( Value : PTR );
   BEGIN
      _AllowedFilterDataBits := Value;
   END AllowedFilterDataBits;

(*---------------------------------------------------------------------------*)

BEGIN
   #if DEBUG #then
      _Level := ldTrace;
   #else
      _Level := ldMessage;
   #endif
   _AllowedFilterDataBits := -1;
END CLevelAndBitsFilter;

(*===========================================================================*)

CLASS IMPLEMENTATION AFormatter;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Append( Level : TLevel; FilterData : PTR; CONST Logger, Prefix, Message : ARRAY OF WCHAR );
   VAR
      dt : time.DateTime;
      leading : BOOLEAN := FALSE;
      S : TString;
   BEGIN
      S := L"";
      IF TimeStamps THEN
         leading := TRUE;
         IF LocalTime THEN
            dt.SetNowLocal();
         ELSE
            dt.SetNowUTC();
         END;
         dt.ToStringOA( L"[yyyy-MM-dd HH:mm:ss.fff] ", TRUE, TRUE, OUT S );
      END;
      IF Levels THEN
         leading := TRUE;
         CASE Level OF
         | lcSysError : Strings.AppendW( REF S, L"F " );
         | ldError : Strings.AppendW( REF S, L"e " );
         | lcError : Strings.AppendW( REF S, L"E " );
         | ldMessage : Strings.AppendW( REF S, L"m " );
         | lcWarning : Strings.AppendW( REF S, L"W " );
         | ldTrace : Strings.AppendW( REF S, L"t " );
         | lcInfo : Strings.AppendW( REF S, L"I " );
         | ldDebug : Strings.AppendW( REF S, L"d " );
         END;
      END;
      IF Names THEN
         leading := TRUE;
         IF Logger[0] <> 0W THEN
            Strings.AppendW( REF S, Logger );
         END;
         IF Prefix[0] <> 0W THEN
            Strings.AppendW( REF S, L"/" ); Strings.AppendW( REF S, Prefix );
         END;
      END;
      IF leading THEN
         Strings.AppendW( REF S, L": " ); 
      END;
      Strings.AppendW( REF S, Message );

      Output( S );
   END Append;
   
(*---------------------------------------------------------------------------*)

BEGIN
END AFormatter;

(*===========================================================================*)

CLASS IMPLEMENTATION CKernelOutput;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE Output( CONST Message : ARRAY OF WCHAR );
   VAR
      S : TString;
      i : CARDINAL;
      h : CARDINAL := MIN2( HIGH( Message ), HIGH( S ) - 2 ); // -2 reserves space for CR + LF
   BEGIN
      i := 0;
      WHILE i <= h DO
         S[i] := Message[i];
         INC( i );
      END; // WHILE
      S[i+0] := 13W;
      S[i+1] := 10W;
      S[i+2] := 0W; // we are always on safe index
      windows.OutputDebugStringW( ADR( S ));
   END Output;

(*---------------------------------------------------------------------------*)

END CKernelOutput;

(*===========================================================================*)

CONST
   DEFAULT_FILE = L"system.log";

CLASS IMPLEMENTATION CFileOutput;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE Output( CONST Message : ARRAY OF WCHAR );
   VAR
      f : FIO.File;
      messageA : ARRAY [0..strlen-1] OF CHAR;
   BEGIN
      _Lock.Lock();
      IF ( _FileName = NIL ) OR ( _FileName^ = 0W ) THEN
         TrySetFileToDefault();
      END;
      f := FIO.AppendW( OAsz( _FileName ), FIO.TFileShare{FIO.fsRead} );
      IF f = NIL THEN
         f := FIO.CreateW( OAsz( _FileName ), FIO.TFileShare{FIO.fsRead} );
      END; // IF
      IF f <> NIL THEN
         Strings.ToA( Message, 0, OUT messageA );
         FIO.WrStrA( f, messageA ); 
         FIO.WrLnA( f );
         FIO.Flush( f );
         FIO.Close( f );
      END; // IF 
      _Lock.Unlock();
   END Output;
   
(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SetFile( CONST File : ARRAY OF WCHAR );
   BEGIN
      _FileNameLength := LENGTH( File ) + FIO.LongPathPrefixLength + 1;
      REALLOCATE( REF _FileName, _FileNameLength ); // +1 for zero end
      FIO.GetLongPathW( File, OUT OA( _FileNameLength-1, _FileName ));
   END SetFile;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE GetFile( OUT File : ARRAY OF WCHAR ) : BOOLEAN;
   BEGIN
      IF _FileNameLength = 0 THEN
         RETURN FALSE;
      END;
      ASSIGN( File, OA( _FileNameLength-1, _FileName ));
      RETURN TRUE;
   END GetFile;

(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE TrySetFileToDefault();
   VAR
      path : FIO.PathStrW := L"";
   BEGIN
      IF folders.GetManufacturerSpecialFolderW( folders.sfAppDataCommon, TRUE, OUT path ) THEN
         FIO.PathAddW( REF path, DEFAULT_FILE );
      ELSE
         path := DEFAULT_FILE;
      END;
      SetFile( path );
   END TrySetFileToDefault;

(*---------------------------------------------------------------------------*)

BEGIN
   _FileName := NIL;
   _FileNameLength := 0;
END CFileOutput;

(*===========================================================================*)

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

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CBuffer;

(*---------------------------------------------------------------------------*)

   LOCAL PROPERTY Size GET : CARDINAL;
   BEGIN
      RETURN _W.Size;
   END Size;

(*---------------------------------------------------------------------------*)

   LOCAL PROPERTY Size SET( Value : CARDINAL );
   BEGIN
      _W.Size := Value;
      REALLOCATE( REF _Data, _W.Size * SIZE( TString )); 
   END Size;

(*---------------------------------------------------------------------------*)

   LOCAL PROPERTY Count GET : CARDINAL;
   BEGIN
      RETURN _W.Count;
   END Count;

(*---------------------------------------------------------------------------*)

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

(*---------------------------------------------------------------------------*)

   LOCAL PROCEDURE Clear();
   BEGIN
      _W.Clear();
   END Clear;

(*---------------------------------------------------------------------------*)

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

(*---------------------------------------------------------------------------*)

BEGIN
FINALLY
   DISPOSE( _Data );
END CBuffer;

(*===========================================================================*)

CLASS IMPLEMENTATION CBufferOutput;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE Output( CONST Message : ARRAY OF WCHAR );
   BEGIN
      _Buffer^.Store( _Mode = bmStoreLast, Message );
   END Output;
   
(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Size GET : CARDINAL;
   BEGIN
      RETURN _Buffer^.Size;
   END Size;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Size SET( Value : CARDINAL );
   BEGIN
      _Buffer^.Size := Value;
   END Size;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Mode GET : TBufferMode;
   BEGIN
      RETURN _Mode;
   END Mode;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Mode SET( Value : TBufferMode );
   BEGIN
      _Mode := Value;
   END Mode;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Count GET : CARDINAL;
   BEGIN
      RETURN _Buffer^.Count;
   END Count;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE GetItem( Index : CARDINAL; OUT S : ARRAY OF WCHAR ) : BOOLEAN; // Index = 0 means first
   BEGIN
      RETURN _Buffer^.GetItem( Index, OUT S );
   END GetItem;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Clear();
   BEGIN
      _Buffer^.Clear();
   END Clear;

(*---------------------------------------------------------------------------*)

BEGIN
   NEW( _Buffer );
FINALLY
   DISPOSE( _Buffer );
END CBufferOutput;

(*===========================================================================*)

CLASS IMPLEMENTATION CAppenderOutput;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Append( Level : TLevel; FilterData : PTR; CONST Logger, Prefix, Message : ARRAY OF WCHAR );
   BEGIN
      IF _Appender <> NIL THEN
         _Appender^.Append( Level, FilterData, Logger, Prefix, Message );
      END;
   END Append;
   
(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Appender GET : iLog.TPIAppender;
   BEGIN
      RETURN _Appender;
   END Appender;
   
(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Appender SET( Value : iLog.TPIAppender );
   BEGIN
      _Appender := Value;
   END Appender;
   
(*---------------------------------------------------------------------------*)

BEGIN
   _Appender := NIL;
END CAppenderOutput;

(*===========================================================================*)

// inside CSimplePtrArray also only IOutputs are stored, which is not too clean. Keep it on mind!!
// DO NOT LOCK anything inside, the class is fully locked from outside
CLASS CSimplePtrArray;

   PUBLIC PROCEDURE Clear();
   PUBLIC PROCEDURE Add( Data : iLog.TPIOutput );
   PUBLIC PROCEDURE Remove( Appender : iLog.TPIOutput );

   PUBLIC PROCEDURE Get( CONST Name : ARRAY OF WCHAR; OUT Appender : iLog.TPIAppender ) : BOOLEAN;
   PUBLIC READONLY INDEX( Index : CARDINAL ) : iLog.TPIAppender;
   
   PUBLIC PROCEDURE LockRead();
   PUBLIC PROCEDURE UnlockRead();

   PUBLIC PROCEDURE LockWrite();
   PUBLIC PROCEDURE UnlockWrite();
   
   PUBLIC READONLY PROPERTY
      Count : CARDINAL;
      Empty : BOOLEAN;

   PRIVATE VAR
      _Lock : Sync.RWLOCK;
      _Appenders : POINTER TO ARRAY [0..0] OF iLog.TPIOutput := NIL;
      _Size : CARDINAL := 0;
      _Count : CARDINAL := 0;

END CSimplePtrArray;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CSimplePtrArray;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Clear();
   BEGIN
      _Count := 0;
      _Size := 0;
      DEALLOCATE( OUT _Appenders );
   END Clear;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Add( Appender : iLog.TPIOutput );
   VAR
      i : CARDINAL;
   BEGIN
      IF _Count > 0 THEN
         FOR i := 0 TO _Count-1 DO
            IF _Appenders^[i] = Appender THEN
               RETURN;
            END;
         END;
      END;
      IF _Count = _Size THEN
         INC( _Size, 16 );
         REALLOCATE( REF _Appenders, _Size * SIZE( iLog.TPIOutput ));
      END;
      _Appenders^[_Count] := Appender;
      INC( _Count );
   END Add;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Remove( Appender : iLog.TPIOutput );
   VAR
      i : CARDINAL;
      move : BOOLEAN := FALSE;
   BEGIN
      IF _Count = 0 THEN
         RETURN;
      END;
      FOR i := 0 TO _Count-2 DO // -1 for HIGH, next -1 for accesing next index inside the loop
         IF NOT move AND ( _Appenders^[i] = Appender ) THEN
            move := TRUE;
         END;
         IF move THEN
            _Appenders^[i] := _Appenders^[i+1];
         END;
      END; // FOR
      DEC( _Count );
   END Remove;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Get( CONST Name : ARRAY OF WCHAR; OUT Appender : iLog.TPIAppender ) : BOOLEAN;
   VAR
      i : CARDINAL;
      s : TString;
   BEGIN
      IF _Count > 0 THEN
         FOR i := 0 TO _Count-1 DO
            iLog.TPIAppender( _Appenders^[i] )^.GetName( OUT s );
            IF EQUALS( s, Name ) THEN
               Appender := iLog.TPIAppender( _Appenders^[i] );
               RETURN TRUE;
            END;
         END; // FOR
      END;
      Appender := NIL;
      RETURN FALSE;
   END Get;

(*---------------------------------------------------------------------------*)

   PUBLIC INDEX CSimplePtrArray GET( Index : CARDINAL ) : iLog.TPIAppender;
   BEGIN
      IF Index >= _Count THEN
         RETURN NIL;
      ELSE
         RETURN iLog.TPIAppender( _Appenders^[Index] );
      END;
   END CSimplePtrArray;
   
(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE LockRead();
   VAR
      Result : Sync.TAsyncResult;
   BEGIN
      Result := _Lock.LockRead( Sync.FORSAFETY );
      ASSERTLOG( Result <> Sync.arTimeout, L"Unable to gain read access to appender list" );
   END LockRead;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE UnlockRead();
   BEGIN
      _Lock.UnlockRead();
   END UnlockRead;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE LockWrite();
   VAR
      Result : Sync.TAsyncResult;
   BEGIN
      Result := _Lock.LockWrite( Sync.FORSAFETY );
      ASSERTLOG( Result <> Sync.arTimeout, L"Unable to gain write access to appender list" );
   END LockWrite;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE UnlockWrite();
   BEGIN
      _Lock.UnlockWrite();
   END UnlockWrite;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Count GET : CARDINAL;
   BEGIN
      RETURN _Count;
   END Count;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Empty GET : BOOLEAN;
   BEGIN
      RETURN _Count = 0;
   END Empty;

(*---------------------------------------------------------------------------*)

BEGIN
END CSimplePtrArray;

(*===========================================================================*)

CLASS IMPLEMENTATION CBaseLogger;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE LogS( Level : TLevel; FilterData : PTR; CONST Prefix, S : ARRAY OF WCHAR );
   BEGIN
      IF Filtered( Level ) THEN
         RETURN;
      END;
      Append( Level, FilterData, _Name, Prefix, S );
   END LogS;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE LogSS( Level : TLevel; FilterData : PTR; CONST Prefix, S1, S2 : ARRAY OF WCHAR );
   VAR
      S : TString;
   BEGIN
      IF Filtered( Level ) THEN
        RETURN;
      END;
      Strings.ConcatW( OUT S, S1, L" " );
      Strings.AppendW( REF S, S2 );
      Append( Level, FilterData, _Name, Prefix, S );
   END LogSS;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE LogSSC( Level : TLevel; FilterData : PTR; CONST Prefix, S1, S2 : ARRAY OF WCHAR; C : CARDINAL );
   VAR
      N : TNum;
      S : TString;
   BEGIN
      IF Filtered( Level ) THEN
         RETURN;
      END;
      Strings.ConcatW( OUT S, S1, L" " );
      Strings.AppendW( REF S, S2 );
      Strings.AppendW( REF S, L" " );
      Strings.FromCARD32W( C, 10, OUT N );
      Strings.AppendW( REF S, N );
      Append( Level, FilterData, _Name, Prefix, S );
   END LogSSC;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE LogSC( Level : TLevel; FilterData : PTR; CONST Prefix, S1 : ARRAY OF WCHAR; C : CARDINAL );
   VAR
      N : TNum;
      S : TString;
   BEGIN
      IF Filtered( Level ) THEN
         RETURN;
      END;
      Strings.ConcatW( OUT S, S1, L" " );
      Strings.FromCARD32W( C, 10, OUT N );
      Strings.AppendW( REF S, N );
      Append( Level, FilterData, _Name, Prefix, S );
   END LogSC;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE LogSCC( Level : TLevel; FilterData : PTR; CONST Prefix, S1 : ARRAY OF WCHAR; C1, C2 : CARDINAL );
   VAR
      N : TNum;
      S : TString;
   BEGIN
      IF Filtered( Level ) THEN
         RETURN;
      END;
      Strings.ConcatW( OUT S, S1, L" " );
      Strings.FromCARD32W( C1, 10, OUT N );
      Strings.AppendW( REF S, N );
      Strings.AppendW( REF S, L" " );
      Strings.FromCARD32W( C2, 10, OUT N );
      Strings.AppendW( REF S, N );
      Append( Level, FilterData, _Name, Prefix, S );
   END LogSCC;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE LogSH( Level : TLevel; FilterData : PTR; CONST Prefix, S1 : ARRAY OF WCHAR; C : CARDINAL );
   VAR
      N : TNum;
      S : TString;
   BEGIN
      IF Filtered( Level ) THEN
         RETURN;
      END;
      Strings.ConcatW( OUT S, S1, L" " );
      Strings.FromCARD32W( C, 16, OUT N );
      Strings.AppendW( REF S, N );
      Append( Level, FilterData, _Name, Prefix, S );
   END LogSH;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE LogSP( Level : TLevel; FilterData : PTR; CONST Prefix, S1 : ARRAY OF WCHAR; P : PTR );
   VAR
      N : TNum;
      S : TString;
   BEGIN
      IF Filtered( Level ) THEN
         RETURN;
      END;
      Strings.ConcatW( OUT S, S1, L" " );
      Strings.FromCARD64W( CARD64( P ), 16, OUT N );
      Strings.AppendW( REF S, N );
      Append( Level, FilterData, _Name, Prefix, S );
   END LogSP;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE LogSCP( Level : TLevel; FilterData : PTR; CONST Prefix, S1 : ARRAY OF WCHAR; C : CARDINAL; P : PTR );
   VAR
      N : TNum;
      S : TString;
   BEGIN
      IF Filtered( Level ) THEN
         RETURN;
      END;
      Strings.ConcatW( OUT S, S1, L" " );
      Strings.FromCARD32W( C, 10, OUT N );
      Strings.AppendW( REF S, N );
      Strings.AppendW( REF S, L" " );
      Strings.FromCARD64W( CARD64( P ), 16, OUT N );
      Strings.AppendW( REF S, N );
      Append( Level, FilterData, _Name, Prefix, S );
   END LogSCP;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE LogSHP( Level : TLevel; FilterData : PTR; CONST Prefix, S1 : ARRAY OF WCHAR; C : CARDINAL; P : PTR );
   VAR
      N : TNum;
      S : TString;
   BEGIN
      IF Filtered( Level ) THEN
         RETURN;
      END;
      Strings.ConcatW( OUT S, S1, L" " );
      Strings.FromCARD32W( C, 16, OUT N );
      Strings.AppendW( REF S, N );
      Strings.AppendW( REF S, L" " );
      Strings.FromCARD64W( CARD64( P ), 16, OUT N );
      Strings.AppendW( REF S, N );
      Append( Level, FilterData, _Name, Prefix, S );
   END LogSHP;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE LogSB( Level : TLevel; FilterData : PTR; CONST Prefix, S1 : ARRAY OF WCHAR; A : ADDRESS; Bytes : CARDINAL );
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
      Append( Level, FilterData, _Name, Prefix, S );
   END LogSB;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE LogSCB( Level : TLevel; FilterData : PTR; CONST Prefix, S1 : ARRAY OF WCHAR; C : CARDINAL; A : ADDRESS; Bytes : CARDINAL );
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
      Strings.ConcatW( OUT S, S1, L" " );
      Strings.FromCARD32W( C, 10, OUT N );
      Strings.AppendW( REF S, N );
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
      Append( Level, FilterData, _Name, Prefix, S );
   END LogSCB;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE LogSSS( Level : TLevel; FilterData : PTR; CONST Prefix, S1, S2, S3 : ARRAY OF WCHAR );
   VAR
      S : TString;
   BEGIN
      IF Filtered( Level ) THEN
         RETURN;
      END;
      Strings.ConcatW( OUT S, S1, L" " );
      Strings.AppendW( REF S, S2 );
      Strings.AppendW( REF S, L" " );
      Strings.AppendW( REF S, S3 );
      Append( Level, FilterData, _Name, Prefix, S );
   END LogSSS;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE LogSSSS( Level : TLevel; FilterData : PTR; CONST Prefix, S1, S2, S3, S4 : ARRAY OF WCHAR );
   VAR
      S : TString;
   BEGIN
      IF Filtered( Level ) THEN
         RETURN;
      END;
      Strings.ConcatW( OUT S, S1, L" " );
      Strings.AppendW( REF S, S2 );
      Strings.AppendW( REF S, L" " );
      Strings.AppendW( REF S, S3 );
      Strings.AppendW( REF S, L" " );
      Strings.AppendW( REF S, S4 );
      Append( Level, FilterData, _Name, Prefix, S );
   END LogSSSS;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE LogSE( Level : TLevel; FilterData : PTR; CONST Prefix, S1 : ARRAY OF WCHAR; ErrorCode : CARDINAL );
   VAR
      E : TString;
      S : TString;
   BEGIN
      IF Filtered( Level ) THEN
         RETURN;
      END;
      Strings.ConcatW( OUT S, S1, L" " );
      Strings.FromErrorW( ErrorCode, OUT E );
      Strings.AppendW( REF S, E );
      Append( Level, FilterData, _Name, Prefix, S );
   END LogSE;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE LogSR( Level : TLevel; FilterData : PTR; CONST Prefix, S1 : ARRAY OF WCHAR; Result : Sync.TAsyncResult );
   VAR
      R : TString;
      S : TString;
   BEGIN
      IF Filtered( Level ) THEN
         RETURN;
      ELSIF NOT Sync.ResultToName( Result, OUT R ) THEN
         ASSERT( FALSE );
         RETURN;
      ELSE
         Strings.ConcatW( OUT S, S1, L" (" );
         Strings.AppendW( REF S, R );
         Strings.AppendW( REF S, L")" );
      END;
      Append( Level, FilterData, _Name, Prefix, S );
   END LogSR;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE LogExc( Level : TLevel; FilterData : PTR; CONST Prefix : ARRAY OF WCHAR; CONST e : Exceptions.Exception );
	VAR
		S : TString;
	BEGIN
      IF Filtered( Level ) THEN
         RETURN;
      END;
	   e.ToString( OUT S );
      Append( Level, FilterData, _Name, Prefix, S );
	END LogExc;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE LogFilePos( Level : TLevel; FilterData : PTR; CONST Prefix : ARRAY OF WCHAR; CONST Path, S1 : ARRAY OF WCHAR; Line, Col : CARDINAL ); // Line, Col = 0/-1 means unused, unknown
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
      
      Append( Level, FilterData, _Name, Prefix, S );
   END LogFilePos;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Append( Level : TLevel; FilterData : PTR; CONST Logger, Prefix, Message : ARRAY OF WCHAR );
   VAR
      i : CARDINAL;
   BEGIN
      _Outputs^.LockRead();
      IF NOT _Outputs^.Empty THEN // although it was already tested, anybody could change it after the check
         FOR i := 0 TO _Outputs^.Count-1 DO
            _Outputs^[i]^.Append( Level, FilterData, Logger, Prefix, Message );
         END;
      END;
      _Outputs^.UnlockRead();
   END Append;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE AddOutput( Output : TPIOutput );
   BEGIN
      _Outputs^.LockWrite();
      _Outputs^.Add( Output );
      _Outputs^.UnlockWrite();
   END AddOutput;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE RemoveOutput( Output : TPIOutput );
   BEGIN
      _Outputs^.LockWrite();
      _Outputs^.Remove( Output );
      _Outputs^.UnlockWrite();
   END RemoveOutput;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE SetName( CONST Name : ARRAY OF WCHAR );
   BEGIN
      _Name := Name;
   END SetName;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE GetName( OUT Name : ARRAY OF WCHAR );
   BEGIN
      Name := _Name;
   END GetName;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Filter GET : TPIFilter;
   BEGIN
      RETURN Sync.IGetPtr( REF _Filter );
   END Filter;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Filter SET( Value : TPIFilter );
   BEGIN
      Sync.IExchgPtr( REF _Filter, Value );
   END Filter;

(*---------------------------------------------------------------------------*)

   PRIVATE INLINE PROCEDURE Filtered( Level : TLevel ) : BOOLEAN;
   VAR
      b : BOOLEAN;
      filter : iLog.TPIFilter := Sync.IGetPtr( REF _Filter );
   BEGIN
      IF ( filter <> NIL ) AND filter^.FilteredFastCheck( Level ) THEN
         b := TRUE;
      ELSE
         _Outputs^.LockRead();
         b := _Outputs^.Empty;
         _Outputs^.UnlockRead();
      END;
      RETURN b;
   END Filtered;

(*---------------------------------------------------------------------------*)

BEGIN
   NEW( _Outputs );
   _Name[0] := 0W;
   _Filter := NIL;
   RegisterAppender( ADR( SELF ));
FINALLY
   ForgetAppender( ADR( SELF ));
   DISPOSE( _Outputs );
END CBaseLogger;

(*===========================================================================*)

CLASS IMPLEMENTATION CPlainLogger;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Output GET : TOutput;
   BEGIN
      RETURN _Output;
   END Output;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Output SET( Value : TOutput );
   VAR
      b : BOOLEAN;
   BEGIN
      b := outKernel IN Value;
      IF b <> ( outKernel NOT IN _Output ) THEN
         IF b THEN
            AddOutput( ADR( _KernelOutput ));
         ELSE
            RemoveOutput( ADR( _KernelOutput ));
         END;
      END;
      b := outFile IN Value;
      IF b <> ( outFile NOT IN _Output ) THEN
         IF b THEN
            AddOutput( ADR( _FileOutput ));
         ELSE
            RemoveOutput( ADR( _FileOutput ));
         END;
      END;
      _Output := Value;
   END Output;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Level GET : TLevel;
   BEGIN
      RETURN _LevelFilter.Level;
   END Level;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Level SET( Value : TLevel );
   BEGIN
      _LevelFilter.Level := Value;
   END Level;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY AllowedFilterDataBits GET : PTR;
   BEGIN
      RETURN _LevelFilter.AllowedFilterDataBits;
   END AllowedFilterDataBits;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY AllowedFilterDataBits SET( Value : PTR );
   BEGIN
      _LevelFilter.AllowedFilterDataBits := Value;
   END AllowedFilterDataBits;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY TimeStamps GET : BOOLEAN;
   BEGIN
      RETURN _KernelOutput.TimeStamps;
   END TimeStamps;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY TimeStamps SET( Value : BOOLEAN );
   BEGIN
      _KernelOutput.TimeStamps := Value;
      _FileOutput.TimeStamps := Value;
   END TimeStamps;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Levels GET : BOOLEAN;
   BEGIN
      RETURN _KernelOutput.TimeStamps;
   END Levels;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Levels SET( Value : BOOLEAN );
   BEGIN
      _KernelOutput.Levels := Value;
      _FileOutput.Levels := Value;
   END Levels;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Names GET : BOOLEAN;
   BEGIN
      RETURN _KernelOutput.Names;
   END Names;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Names SET( Value : BOOLEAN );
   BEGIN
      _KernelOutput.Names := Value;
      _FileOutput.Names := Value;
   END Names;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY LocalTime GET : BOOLEAN;
   BEGIN
      RETURN _KernelOutput.LocalTime;
   END LocalTime;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY LocalTime SET( Value : BOOLEAN );
   BEGIN
      _KernelOutput.Names := LocalTime;
      _FileOutput.Names := LocalTime;
   END LocalTime;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SetLogFile( CONST LogFile : ARRAY OF WCHAR );
   BEGIN
      _FileOutput.SetFile( LogFile );
      IF LogFile[0] = 0W THEN
         Output := _Output - TOutput{outFile};
      END;
   END SetLogFile;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE GetLogFile( OUT LogFile : ARRAY OF WCHAR ) : BOOLEAN;
   BEGIN
      RETURN _FileOutput.GetFile( OUT LogFile ); 
   END GetLogFile;

(*---------------------------------------------------------------------------*)

BEGIN
   _Output := TOutput{};
   Output := TOutput{outKernel};

   #if #defined LIBRARY #then
      ConfigureByRegistry( REF SELF, LIBRARY );
   #endif
END CPlainLogger;

(*===========================================================================*)

CLASS IMPLEMENTATION CBufferedLogger;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY BufferSize GET : CARDINAL;
   BEGIN
      RETURN _BufferOutput.Size;
   END BufferSize;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY BufferSize SET( Value : CARDINAL );
   BEGIN
      _BufferOutput.Size := Value;
   END BufferSize;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY BufferMode GET : TBufferMode;
   BEGIN
      RETURN _BufferOutput.Mode;
   END BufferMode;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY BufferMode SET( Value : TBufferMode );
   BEGIN
      _BufferOutput.Mode := Value;
   END BufferMode;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY BufferCount GET : CARDINAL;
   BEGIN
      RETURN _BufferOutput.Count;
   END BufferCount;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE BufferGetItem( Index : CARDINAL; OUT S : ARRAY OF WCHAR ) : BOOLEAN; // Index = 0 means first
   BEGIN
      RETURN _BufferOutput.GetItem( Index, OUT S );
   END BufferGetItem;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE BufferClear();
   BEGIN
      _BufferOutput.Clear();
   END BufferClear;

(*---------------------------------------------------------------------------*)

BEGIN
   AddOutput( ADR( _BufferOutput ));
FINALLY
   RemoveOutput( ADR( _BufferOutput ));
END CBufferedLogger;

(*===========================================================================*)

PROCEDURE ConfigureByRegistry( REF _logger : CBaseLogger; CONST SectionName : ARRAY OF WCHAR ) : BOOLEAN; // loads also all outputs
VAR
   AllowedBits : CARD64;
   Cached : CARDINAL;
   DataSize : CARDINAL;
   Dir : FIO.PathStrW;
   hkey : winreg.HKEY;
   Key, Data : TString;
   LSectionName : TString;
   logger : TPPlainLogger;
   PData : PBYTE := PBYTE( ADR( Data ));
   RegType : CARDINAL;
   res : CARDINAL;
BEGIN
   Data[0] := 0W;
   LSectionName := SectionName;
   // defaults are not set here, they come from constructor or from previous CLog property settings

   LOOP
      Strings.ConcatW( OUT Key, L"SOFTWARE\" + Manufacturer + "\Log\", LSectionName );
      res := winreg.RegOpenKeyExW( winreg.HKEY_CURRENT_USER, ADR( Key ), 0, windows.KEY_READ, ADR( hkey ));
      IF res <> 0 THEN // key does not exists, try HKLM
         res := winreg.RegOpenKeyExW( winreg.HKEY_LOCAL_MACHINE, ADR( Key ), 0, windows.KEY_READ, ADR( hkey ));
      END;
      IF res <> 0 THEN // key not found
         RETURN FALSE;
      END;

      // read data
      DataSize := SIZE( Data );
      IF ( winreg.RegQueryValueExW( hkey, GetKeyword( ckkJoin ), NIL, ADR( RegType ), PData, ADR( DataSize )) = 0 ) AND ( RegType = windows.REG_SZ ) THEN
         // redirect to another settings
         LSectionName := Data;

         winreg.RegCloseKey( hkey );
         CONTINUE;
      END;

      IF NOT( _logger INHERITS CPlainLogger ) THEN
         CONTINUE;
      END;
      logger := TPPlainLogger( ADR( _logger ));

      DataSize := SIZE( Data );
      IF ( winreg.RegQueryValueExW( hkey, GetKeyword( ckkTarget ), NIL, ADR( RegType ), PData, ADR( DataSize )) = 0 ) AND ( RegType = windows.REG_SZ ) OR
         ( winreg.RegQueryValueExW( hkey, GetKeyword( ckkOutput ), NIL, ADR( RegType ), PData, ADR( DataSize )) = 0 ) AND ( RegType = windows.REG_SZ ) THEN
         LOW( Data );
         IF EQUALS( Data, OAsz( GetKeyword( ckvKernel )) ) THEN
            logger^.Output := outsKernel;
         ELSIF EQUALS( Data, OAsz( GetKeyword( ckvFile )) ) THEN
            logger^.Output := outsFile;
         END;
      END;

      DataSize := SIZE( Data );
      IF ( winreg.RegQueryValueExW( hkey, GetKeyword( ckkTimeStamps ), NIL, ADR( RegType ), PData, ADR( DataSize )) = 0 ) AND ( RegType = windows.REG_SZ ) THEN
         LOW( Data );
         logger^.TimeStamps := EQUALS( Data, OAsz( GetKeyword( ckvTrue )) );
      END;

      DataSize := SIZE( Data );
      IF ( winreg.RegQueryValueExW( hkey, GetKeyword( ckkLevels ), NIL, ADR( RegType ), PData, ADR( DataSize )) = 0 ) AND ( RegType = windows.REG_SZ ) THEN
         LOW( Data );
         logger^.Levels := EQUALS( Data, OAsz( GetKeyword( ckvTrue )) );
      END;

      DataSize := SIZE( Data );
      IF ( winreg.RegQueryValueExW( hkey, GetKeyword( ckkNames ), NIL, ADR( RegType ), PData, ADR( DataSize )) = 0 ) AND ( RegType = windows.REG_SZ ) THEN
         LOW( Data );
         logger^.Names := EQUALS( Data, OAsz( GetKeyword( ckvTrue )) );
      END;

      DataSize := SIZE( Data );
      IF ( winreg.RegQueryValueExW( hkey, GetKeyword( ckkLocalTime ), NIL, ADR( RegType ), PData, ADR( DataSize )) = 0 ) AND ( RegType = windows.REG_SZ ) THEN
         LOW( Data );
         logger^.LocalTime := EQUALS( Data, OAsz( GetKeyword( ckvTrue )) );
      END;

      DataSize := SIZE( Data );
      IF ( winreg.RegQueryValueExW( hkey, GetKeyword( ckkFile ), NIL, ADR( RegType ), PData, ADR( DataSize )) <> 0 ) OR ( RegType <> windows.REG_SZ ) THEN
         logger^.GetLogFile( OUT Data );
         IF Data[0] = 0W THEN
            FIO.GetModuleDirW( EMITW( %dll ), OUT Dir );
            IF Dir[0] = 0W THEN
               FIO.GetModuleDirW( L"", OUT Dir );
            END;
            Strings.ConcatW( OUT Data, SectionName, L".log" ); // use client's name, not processing LLibrary
            FIO.MakePathW( Dir, Data, OUT Data );
         END;
      END;
      logger^.SetLogFile( Data );

      DataSize := SIZE( Data );
      IF ( winreg.RegQueryValueExW( hkey, GetKeyword( ckkLevel ), NIL, ADR( RegType ), PData, ADR( DataSize )) = 0 ) AND ( RegType = windows.REG_SZ ) OR
         ( winreg.RegQueryValueExW( hkey, GetKeyword( ckkFilter ), NIL, ADR( RegType ), PData, ADR( DataSize )) = 0 ) AND ( RegType = windows.REG_SZ ) THEN
         LOW( Data );
         IF EQUALS( Data, OAsz( GetKeyword( ckvError )) ) OR EQUALS( Data, OAsz( GetKeyword( ckvDebugFailure )) ) THEN
            logger^.Level := ldError;
         ELSIF EQUALS( Data, OAsz( GetKeyword( ckvError )) ) OR EQUALS( Data, OAsz( GetKeyword( ckvDebugMessage )) ) THEN
            logger^.Level := ldMessage;
         ELSIF EQUALS( Data, OAsz( GetKeyword( ckvWarning )) ) OR EQUALS( Data, OAsz( GetKeyword( ckvDebugTrace )) ) THEN
            logger^.Level := ldTrace;
         ELSIF EQUALS( Data, OAsz( GetKeyword( ckvInfo )) ) OR EQUALS( Data, OAsz( GetKeyword( ckvDebugAll )) ) THEN
            logger^.Level := ldDebug;
         END;
      END;
      
      DataSize := SIZE( Data );
      IF ( winreg.RegQueryValueExW( hkey, GetKeyword( ckkAllowedFilterBits ), NIL, ADR( RegType ), PData, ADR( DataSize )) = 0 ) AND ( RegType = windows.REG_SZ ) AND
         Strings.ToCARD64W( Data, 16, OUT AllowedBits ) THEN
         IF SIZE( PTR ) = SIZE( LONGWORD ) THEN
            logger^.AllowedFilterDataBits := CARD32( AllowedBits );
         ELSE
            logger^.AllowedFilterDataBits := AllowedBits;
         END;
      END;

      IF NOT( _logger INHERITS CBufferedLogger ) THEN
         CONTINUE;
      END;

      DataSize := SIZE( Data );
      IF ( winreg.RegQueryValueExW( hkey, GetKeyword( ckkCached ), NIL, ADR( RegType ), PData, ADR( DataSize )) = 0 ) AND ( RegType = windows.REG_SZ ) AND
         Strings.ToCARD32W( Data, 10, OUT Cached ) THEN
         TPBufferedLogger( logger )^.BufferSize := Cached;
      END;

      winreg.RegCloseKey( hkey );
      RETURN TRUE;
   END; // LOOP
END ConfigureByRegistry;

(*---------------------------------------------------------------------------*)

PROCEDURE ConfigureByLogger( REF logger : CBaseLogger; CONST sourceLogger : CBaseLogger ); // DOES NOT LOAD any output
VAR
   s : TString;
BEGIN
   sourceLogger.GetName( OUT s ); logger.SetName( s );

   IF ( logger IS CPlainLogger ) AND ( sourceLogger IS CPlainLogger ) THEN
      TPPlainLogger( ADR( logger ))^.Level := TPPlainLogger( ADR( sourceLogger ))^.Level;
      TPPlainLogger( ADR( logger ))^.AllowedFilterDataBits := TPPlainLogger( ADR( sourceLogger ))^.AllowedFilterDataBits;
      TPPlainLogger( ADR( logger ))^.TimeStamps := TPPlainLogger( ADR( sourceLogger ))^.TimeStamps;
      TPPlainLogger( ADR( logger ))^.Levels := TPPlainLogger( ADR( sourceLogger ))^.Levels;
      TPPlainLogger( ADR( logger ))^.Names := TPPlainLogger( ADR( sourceLogger ))^.Names;
      TPPlainLogger( ADR( logger ))^.LocalTime := TPPlainLogger( ADR( sourceLogger ))^.LocalTime;
      TPPlainLogger( ADR( logger ))^.GetLogFile( OUT s ); TPPlainLogger( ADR( sourceLogger ))^.SetLogFile( s );
   END;

   IF ( logger IS CBufferedLogger ) AND ( sourceLogger IS CBufferedLogger ) THEN
      TPBufferedLogger( ADR( logger ))^.BufferMode := TPBufferedLogger( ADR( sourceLogger ))^.BufferMode;
      TPBufferedLogger( ADR( logger ))^.BufferSize := TPBufferedLogger( ADR( sourceLogger ))^.BufferSize;
   END;
END ConfigureByLogger;

(*===========================================================================*)

CLASS CLoggerRegistry;

   PRIVATE VAR
      _Loggers : CSimplePtrArray;
      
   PUBLIC PROCEDURE Clear();
      
   PUBLIC PROCEDURE Register( Appender : TPIAppender );
   PUBLIC PROCEDURE Forget( Appender : TPIAppender );
   PUBLIC PROCEDURE Get( CONST Name : ARRAY OF WCHAR; OUT Appender : TPIAppender ) : BOOLEAN;

END CLoggerRegistry;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CLoggerRegistry;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Clear();
   BEGIN
      _Loggers.LockWrite();
      _Loggers.Clear();
      _Loggers.UnlockWrite();
   END Clear;
      
(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Register( Appender : TPIAppender );
   BEGIN
      _Loggers.LockWrite();
      _Loggers.Add( Appender );
      _Loggers.UnlockWrite();
   END Register;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Forget( Appender : TPIAppender );
   BEGIN
      _Loggers.LockWrite();
      _Loggers.Remove( Appender );
      _Loggers.UnlockWrite();
   END Forget;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Get( CONST Name : ARRAY OF WCHAR; OUT Appender : TPIAppender ) : BOOLEAN;
   VAR
      b : BOOLEAN;
   BEGIN
      _Loggers.LockRead();
      b := _Loggers.Get( Name, OUT Appender );      
      _Loggers.UnlockRead();
      RETURN b;
   END Get;

(*---------------------------------------------------------------------------*)

BEGIN
FINALLY
   Clear();
END CLoggerRegistry;

(*===========================================================================*)

VAR
   Logger : CBufferedLogger; // default logger

PROCEDURE logger() : TPBufferedLogger;
BEGIN
   RETURN ADR( Logger );
END logger;

(*---------------------------------------------------------------------------*)

VAR
   Registry : CLoggerRegistry;   

(*---------------------------------------------------------------------------*)

PROCEDURE RegisterAppender( Appender : iLog.TPIAppender );
BEGIN
   Registry.Register( Appender );
END RegisterAppender;

(*---------------------------------------------------------------------------*)

PROCEDURE ForgetAppender( Appender : iLog.TPIAppender );
BEGIN
   Registry.Forget( Appender );
END ForgetAppender;

(*---------------------------------------------------------------------------*)

PROCEDURE GetAppender( CONST Name : ARRAY OF WCHAR; OUT Appender : iLog.TPIAppender ) : BOOLEAN;
BEGIN
   RETURN Registry.Get( Name, OUT Appender );
END GetAppender;

(*===========================================================================*)

// for configuration purposes, not exported out of DLL
PROCEDURE GetKeyword( keyword : TConfigKeyword ) : PWCHAR; // zero terminated
BEGIN
   CASE keyword OF
   | cksLog : RETURN L'log';
   | ckkOutput : RETURN L'output';
   | ckkTarget : RETURN L'target';
   | ckvFile : RETURN L'file';
   | ckvKernel : RETURN L'kernel';
   | ckkFile : RETURN L'file';
   | ckkFilter : RETURN L'filter';
   | ckvDeny : RETURN L'deny';
   | ckvAllow : RETURN L'allow';
   | ckkLevel : RETURN L'level';
   | ckvFatal : RETURN L'fatal'; 
   | ckvError : RETURN L'error'; 
   | ckvWarning : RETURN L'warning'; 
   | ckvInfo : RETURN L'info'; 
   | ckvDebugFailure : RETURN L'failure';
   | ckvDebugMessage : RETURN L'message';
   | ckvDebugTrace : RETURN L'trace';
   | ckvDebugAll : RETURN L'all';
   | ckkCached : RETURN L'cached';
   | ckkAllowedFilterBits : RETURN L"allowed_filter_bits";
   | ckkTimeStamps : RETURN L"timestamps";
   | ckkLevels : RETURN L"levels";
   | ckkNames : RETURN L"names";
   | ckkLocalTime : RETURN L"localtime";
   | ckvTrue : RETURN L"true";
   | ckvFalse : RETURN L"false";
   ELSE
      RETURN L"<unknown>";
   END; // CASE
END GetKeyword;

(*---------------------------------------------------------------------------*)

BEGIN
FINALLY
   Registry.Clear();
END log.
