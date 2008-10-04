IMPLEMENTATION MODULE FSO;

FROM Storage IMPORT
   ALLOCATE;

IMPORT
   FIO,
   FIOO,
   Storage,
   Strings,
   Sync,
   timeWin32;

(*================================================================================*)

CLASS IMPLEMENTATION CDirectoryInfo; // 0W or '*' are equivalent in SearchPattern

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE StartOA( CONST Path, Pattern : ARRAY OF WCHAR; SearchOptions : TSearchOption; GetDirectories, GetFiles : BOOLEAN ) : BOOLEAN;
   VAR
      LPath : ARRAY [0..511] OF WCHAR;
   BEGIN
      Stop();
      IF Strings.IndexOfCharW( Path, L"*", 0 ) <> -1 THEN
         RETURN FALSE;
      END;
      IF EQUALS( Path, L"" ) THEN
         LPath := L".\*";
      ELSIF Strings.EndsWithW( Path, L"\" ) THEN
         ASSIGN( _path, Path );
         Strings.ConcatW( OUT LPath, Path, L"*" );
      ELSE
         Strings.ConcatW( OUT _path, Path, L"\" );
         Strings.ConcatW( OUT LPath, _path, L"*" );
      END;
      _handle := windows.FindFirstFileW( ADR( LPath ), ADR( _current ));
      IF _handle = windows.INVALID_HANDLE_VALUE THEN
         RETURN FALSE;
      ELSE
         ASSIGN( _pattern, Pattern );
         _directories := GetDirectories;
         _files := GetFiles;
         RETURN CheckMatch( FALSE );
      END;
   END StartOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE StartFromPath( CONST PathWithPattern : StringsO.IString; SearchOptions : TSearchOption; GetDirectories, GetFiles : BOOLEAN ) : BOOLEAN;
   VAR
      head, path, tail : FIO.PathStrW;
   BEGIN
      PathWithPattern.ToOA( OUT path );
      FIO.SplitPathW( path, OUT head, OUT tail );
      IF head[0] <> 0W THEN
         RETURN StartOA( head, tail, SearchOptions, GetDirectories, GetFiles );
      ELSIF EQUALS( tail, L"." ) THEN
         RETURN StartOA( L".", L"*", SearchOptions, GetDirectories, GetFiles );
      ELSIF EQUALS( tail, L".." ) THEN
         RETURN StartOA( L"..", L"*", SearchOptions, GetDirectories, GetFiles );
      ELSE
         RETURN StartOA( head, tail, SearchOptions, GetDirectories, GetFiles );
      END;
   END StartFromPath;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE StartFromPathOA( CONST PathWithPattern : ARRAY OF WCHAR; SearchOptions : TSearchOption; GetDirectories, GetFiles : BOOLEAN ) : BOOLEAN;
   VAR
      head, tail : FIO.PathStrW;
   BEGIN
      FIO.SplitPathW( PathWithPattern, OUT head, OUT tail );
      RETURN StartOA( head, tail, SearchOptions, GetDirectories, GetFiles );
   END StartFromPathOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Stop();
   BEGIN
      IF _handle <> windows.INVALID_HANDLE_VALUE THEN
         windows.FindClose( _handle );
         _handle := windows.INVALID_HANDLE_VALUE;
      END;
   END Stop;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE MoveNext() : BOOLEAN;
   BEGIN
      IF _handle = windows.INVALID_HANDLE_VALUE THEN
         RETURN FALSE;
      ELSE
         RETURN CheckMatch( TRUE );
      END;
   END MoveNext;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Name GET : StringsO.CString;
   VAR
      S : StringsO.CString;
   BEGIN
      S.FromOA( _current.cFileName );
      RETURN S;
   END Name;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Path GET : StringsO.CString;
   VAR
      S : StringsO.CString;
   BEGIN
      IF _handle <> windows.INVALID_HANDLE_VALUE THEN
         S.FromOA( _path ); S.AppendOA( _current.cFileName );
      END;
      RETURN S;
   END Path;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Attributes GET: TFileAttributes;
   VAR
      FA : TFileAttributes := TFileAttributes{};
   BEGIN
      IF _handle = windows.INVALID_HANDLE_VALUE THEN
         RETURN TFileAttributes{};
      END;
      IF _current.dwFileAttributes AND windows.FILE_ATTRIBUTE_ARCHIVE <> 0 THEN
         INCL( FA, faArchive );
      END;
      IF _current.dwFileAttributes AND windows.FILE_ATTRIBUTE_COMPRESSED <> 0 THEN
         INCL( FA, faCompressed );
      END;
      IF _current.dwFileAttributes AND windows.FILE_ATTRIBUTE_ENCRYPTED <> 0 THEN
         INCL( FA, faEncrypted );
      END;
      IF _current.dwFileAttributes AND windows.FILE_ATTRIBUTE_HIDDEN <> 0 THEN
         INCL( FA, faHidden );
      END;
      IF _current.dwFileAttributes AND windows.FILE_ATTRIBUTE_NORMAL <> 0 THEN
         INCL( FA, faNormal );
      END;
      IF _current.dwFileAttributes AND windows.FILE_ATTRIBUTE_OFFLINE <> 0 THEN
         INCL( FA, faOffline );
      END;
      IF _current.dwFileAttributes AND windows.FILE_ATTRIBUTE_READONLY <> 0 THEN
         INCL( FA, faReadOnly );
      END;
      IF _current.dwFileAttributes AND windows.FILE_ATTRIBUTE_REPARSE_POINT <> 0 THEN
         INCL( FA, faReparsePoint );
      END;
      IF _current.dwFileAttributes AND windows.FILE_ATTRIBUTE_SPARSE_FILE <> 0 THEN
         INCL( FA, faSparseFile );
      END;
      IF _current.dwFileAttributes AND windows.FILE_ATTRIBUTE_SYSTEM <> 0 THEN
         INCL( FA, faSystem );
      END;
      IF _current.dwFileAttributes AND windows.FILE_ATTRIBUTE_TEMPORARY <> 0 THEN
         INCL( FA, faTemporary );
      END;
      RETURN FA;
   END Attributes;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Size GET : CARD64;
   BEGIN
      IF _handle = windows.INVALID_HANDLE_VALUE THEN
         RETURN 0;
      END;
      RETURN ( CARD64( _current.nFileSizeHigh ) << 32 ) OR CARD64( _current.nFileSizeLow );
   END Size;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY CreationTime GET : time.TDateTime;
   VAR
      t : time.TDateTime;
      st : windows.SYSTEMTIME;
   BEGIN
      IF _handle = windows.INVALID_HANDLE_VALUE THEN
         time.InitDateTime( OUT t );
      ELSE
         windows.FileTimeToSystemTime( ADR( _current.ftCreationTime ), ADR( st ));
         timeWin32.SystemTimeToDateTime( st, OUT t );
      END;
      RETURN t;
   END CreationTime;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY LastAccessTime GET : time.TDateTime;
   VAR
      t : time.TDateTime;
      st : windows.SYSTEMTIME;
   BEGIN
      IF _handle = windows.INVALID_HANDLE_VALUE THEN
         time.InitDateTime( OUT t );
      ELSE
         windows.FileTimeToSystemTime( ADR( _current.ftLastAccessTime ), ADR( st ));
         timeWin32.SystemTimeToDateTime( st, OUT t );
      END;
      RETURN t;
   END LastAccessTime;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE CheckMatch( Feed : BOOLEAN ) : BOOLEAN;
   VAR
      havefile : BOOLEAN;
   BEGIN
      IF Feed AND ( windows.FindNextFileW( _handle, ADR( _current )) = windows.False ) THEN
         Stop();
         RETURN FALSE;
      END;
      LOOP
         havefile := _current.dwFileAttributes AND windows.FILE_ATTRIBUTE_DIRECTORY = 0;
         IF NOT(( _files AND havefile ) OR ( _directories AND NOT havefile )) THEN
            // continue
         ELSIF NOT havefile AND ( EQUALS( _current.cFileName, L'.' ) OR EQUALS( _current.cFileName, L'..' )) THEN
            // continue, omit . and .. directory names
         ELSIF ( _pattern[0] <> 0W ) AND NOT Strings.MatchW( _current.cFileName, _pattern, FALSE ) THEN
            // continue
         ELSE
            RETURN TRUE;
         END;
         IF windows.FindNextFileW( _handle, ADR( _current )) = windows.False THEN
            Stop();
            RETURN FALSE;
         END;
      END; // LOOP
   END CheckMatch;

(*--------------------------------------------------------------------------------*)

BEGIN
   _handle := windows.INVALID_HANDLE_VALUE;
   _current.dwFileAttributes := 0;
   _path := L'';
   _pattern := L'';
   _directories := FALSE;
   _files := FALSE;
FINALLY
   Stop();
END CDirectoryInfo;

(*================================================================================*)
(*

PROCEDURE GetFiles( SearchPattern : ARRAY OF WCHAR; SearchOption : TSearchOption; OUT Files : lists.CStringList );
BEGIN
END GetFiles;

(*--------------------------------------------------------------------------------*)

PROCEDURE GetDirectories( SearchPattern : ARRAY OF WCHAR; SearchOption : TSearchOption; OUT Directories : lists.CStringList );
BEGIN
END GetDirectories;

*)

(*================================================================================*)

PROCEDURE CreateDirectory( CONST Directory : StringsO.CString ) : BOOLEAN;
BEGIN
   RETURN CreateDirectoryOA( OA( Directory.Length - 1, Directory.rawData ));
END CreateDirectory;

(*--------------------------------------------------------------------------------*)

PROCEDURE CreateDirectoryOA( CONST Directory : ARRAY OF WCHAR ) : BOOLEAN;
VAR
   i : INTEGER;
   idx : INTEGER := -1;
   idxs : ARRAY [0..FIO.MaxPath DIV 2] OF CARDINAL;
   work : ARRAY [0..FIO.MaxPath] OF WCHAR;
BEGIN
   IF LENGTH( Directory ) = 0 THEN
      RETURN FALSE;
   END;
   ASSIGN( work, Directory );
   idxs[0] := 0;
   
   // backward run
   i := LENGTH( Directory ) - 1;
   LOOP
      IF FIO.ExistsDirW( work ) THEN
         IF idx < 0 THEN
            RETURN TRUE;
         ELSE
            work[idxs[idx]] := '\';
            DEC( idx );
         END;
         EXIT;
      END;
      WHILE ( i >= 0 ) AND ( work[i] <> '\' ) DO
         DEC( i );
      END;
      IF i = -1 THEN
         EXIT;
      END;
      INC( idx );
      idxs[idx] := i;
      work[i] := 0W;
   END; // LOOP
   
   // forward run
   LOOP
      IF windows.CreateDirectoryW( ADR( work ), NIL ) = windows.False THEN
         RETURN FALSE;
      END;
      IF idx < 0 THEN
         EXIT;
      END;
      work[idxs[idx]] := '\';
      DEC( idx );
   END; // WHILE
   
   RETURN TRUE;
END CreateDirectoryOA;

(*================================================================================*)

PROCEDURE GetEnvVariable( CONST Variable : ARRAY OF WCHAR; OUT Data : StringsO.CString ) : BOOLEAN;
VAR
   chars : CARDINAL;
BEGIN
   chars := windows.GetEnvironmentVariableW( ADR( Variable ), NIL, 0 );
   IF chars = 0 THEN
      RETURN FALSE;
   END;
   Data.Size := chars;
   Data.Length := chars;
   Data.Length := windows.GetEnvironmentVariableW( ADR( Variable ), Data.rawData, chars );
   RETURN Data.Length > 0;
END GetEnvVariable;

(*================================================================================*)

PROCEDURE PrepareStdHandles( REF SI : windows.STARTUPINFO; OUT hWriteInto, hReadBack, hErrorReadBack : windows.HANDLE; OUT ErrorCode : CARDINAL ) : BOOLEAN;
LABEL
   Error;
VAR
   hChildError : windows.HANDLE;
   hChildInput : windows.HANDLE;
   hChildOutput : windows.HANDLE;
   hTemp : windows.HANDLE;
   SA : windows.SECURITY_ATTRIBUTES;
BEGIN
   hChildInput := windows.INVALID_HANDLE_VALUE;
   hChildOutput := windows.INVALID_HANDLE_VALUE;
   hChildError := windows.INVALID_HANDLE_VALUE;
   hWriteInto := windows.INVALID_HANDLE_VALUE;
   hReadBack := windows.INVALID_HANDLE_VALUE;
   hErrorReadBack := windows.INVALID_HANDLE_VALUE;

   SI.dwFlags := SI.dwFlags OR windows.STARTF_USESTDHANDLES;

   SA.nLength := SIZE( SA );
   SA.lpSecurityDescriptor := NIL;
   SA.bInheritHandle := windows.True;

   // create child input pipe
   IF windows.CreatePipe( ADR( hChildInput ), ADR( hTemp ), ADR( SA ), 0 ) = windows.False THEN
      GOTO Error;
   END;
   // hTemp must be made NOT inheritable as child must not inherit it
   IF windows.DuplicateHandle(
        windows.GetCurrentProcess(), hTemp, windows.GetCurrentProcess(), ADR( hWriteInto ),
        0, windows.False, windows.DUPLICATE_SAME_ACCESS OR windows.DUPLICATE_CLOSE_SOURCE ) = windows.False THEN
      GOTO Error;
   END;

   // create child output pipe
   IF windows.CreatePipe( ADR( hTemp ), ADR( hChildOutput ), ADR( SA ), 0 ) = windows.False THEN
      GOTO Error;
   END;
   // hTemp must be made NOT inheritable as child must not inherit it
   IF windows.DuplicateHandle(
        windows.GetCurrentProcess(), hTemp, windows.GetCurrentProcess(), ADR( hReadBack ),
        0, windows.False, windows.DUPLICATE_SAME_ACCESS OR windows.DUPLICATE_CLOSE_SOURCE ) = windows.False THEN
      GOTO Error;
   END;

   // create child error output pipe
   IF windows.CreatePipe( ADR( hTemp ), ADR( hChildError ), ADR( SA ), 0 ) = windows.False THEN
      GOTO Error;
   END;
   // hTemp must be made NOT inheritable as child must not inherit it
   IF windows.DuplicateHandle(
        windows.GetCurrentProcess(), hTemp, windows.GetCurrentProcess(), ADR( hErrorReadBack ),
        0, windows.False, windows.DUPLICATE_SAME_ACCESS OR windows.DUPLICATE_CLOSE_SOURCE ) = windows.False THEN
      GOTO Error;
   END;

   SI.hStdInput := hChildInput;
   SI.hStdOutput := hChildOutput;
   SI.hStdError := hChildError;

   RETURN TRUE;

 Error:
   ErrorCode := windows.GetLastError();
   IF hChildInput <> windows.INVALID_HANDLE_VALUE THEN
      windows.CloseHandle( hChildInput );
   END;
   IF hChildOutput <> windows.INVALID_HANDLE_VALUE THEN
      windows.CloseHandle( hChildOutput );
   END;
   IF hChildError <> windows.INVALID_HANDLE_VALUE THEN
      windows.CloseHandle( hChildError );
   END;
   IF hWriteInto <> windows.INVALID_HANDLE_VALUE THEN
      windows.CloseHandle( hWriteInto );
   END;
   IF hReadBack <> windows.INVALID_HANDLE_VALUE THEN
      windows.CloseHandle( hReadBack );
   END;

   RETURN FALSE;
END PrepareStdHandles;

(*--------------------------------------------------------------------------------*)

PROCEDURE RunProgramInPipe( CONST Path, Parameters : ARRAY OF WCHAR; CONST InStream : IOO.TPStream; OUT OutStream : IOO.TPStream ) THROWS IOO.CIOException;
LABEL
   Error, ErrorCodeKnown;
VAR
   Buffer : ARRAY [0..16383] OF BYTE;
   ErrorCode : CARDINAL;
   Filled : CARDINAL;
   fs : FIOO.CFileStream;
   hErrorReadBack : windows.HANDLE;
   hReadBack : windows.HANDLE;
   hWriteInto : windows.HANDLE;
   PI : windows.PROCESS_INFORMATION;
   Written : CARDINAL;
   Result : Sync.TAsyncResult;
   S : StringsO.CString;
   SI : windows.STARTUPINFO;
   Success : BOOLEAN;
BEGIN
   Storage.Fill( ADR( SI ), SIZE( SI ), 0 );
   Storage.Fill( ADR( PI ), SIZE( PI ), 0 );
   SI.cb := SIZE( SI );
   OutStream := NIL;

   IF NOT PrepareStdHandles( REF SI, OUT hWriteInto, OUT hReadBack, OUT hErrorReadBack, OUT ErrorCode ) THEN
      THROW IOO.IOException( NIL, L"RunProgramInPipe", L"PrepareHandles", ErrorCode );
   END;

   S.FromOA( L'"' ); S.AppendOA( Path );
   IF Parameters[0] = 0W THEN
      S.AppendOA( L'"' );
   ELSE
      S.AppendOA( L'" ' );
      S.AppendOA( Parameters );
   END;
   Success := windows.CreateProcessW( NIL, S.szData, NIL, NIL, windows.True, windows.CREATE_NO_WINDOW, NIL, NIL, ADR( SI ), ADR( PI )) = windows.True;

   // close inherited handles
   windows.CloseHandle( SI.hStdInput );
   windows.CloseHandle( SI.hStdOutput );
   windows.CloseHandle( SI.hStdError );

   IF Success THEN // sucessfully created
      windows.WaitForInputIdle( PI.hProcess, windows.INFINITE );
   
      IF InStream <> NIL THEN
         // write data into program input
         fs.FromHandle( hWriteInto, FALSE, IOO.accWrite );
         LOOP
            CASE InStream^.ReadOA( REF Buffer, OUT Filled, Sync.FOREVER ) OF
            | Sync.arNoData :
               EXIT;
            | Sync.arCompleted : // OK
               Result := fs.WriteOA( OA( Filled-1, ADR( Buffer )), OUT Written, Sync.FOREVER );
            ELSE // error
               GOTO Error;
            END;
         END; // LOOP
         fs.Close( FALSE );
      END;

      // read data from program output
      OutStream := NEW( FIOO.CFileStream );
      FIOO.TPFileStream( OutStream )^.FromHandle( hReadBack, TRUE, IOO.accRead );
      hReadBack := windows.INVALID_HANDLE_VALUE;
     
      windows.CloseHandle( PI.hThread );
      windows.CloseHandle( PI.hProcess );
   END;

 Error:
   ErrorCode := windows.GetLastError();

   // close handles
   IF hWriteInto <> windows.INVALID_HANDLE_VALUE THEN
      windows.CloseHandle( hWriteInto );
   END;
   IF hReadBack <> windows.INVALID_HANDLE_VALUE THEN
      windows.CloseHandle( hReadBack );
   END;
   IF hErrorReadBack <> windows.INVALID_HANDLE_VALUE THEN
      windows.CloseHandle( hErrorReadBack );
   END;

   IF ErrorCode <> 0 THEN
      THROW IOO.IOException( NIL, L"RunProgramInPipe", L"RunAndCopy", ErrorCode );
   END;
END RunProgramInPipe;

(*================================================================================*)

END FSO.