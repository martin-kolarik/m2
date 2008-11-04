IMPLEMENTATION MODULE FIO;

IMPORT
  Strings,
  windows;
  
PROCEDURE ChangeExtensionW( REF Path : ARRAY OF WCHAR; CONST Extension : ARRAY OF WCHAR ); // if Ext = '' removes it, if Path is without appends it
VAR
  i : CARDINAL;
BEGIN
  i := Strings.LastIndexOfCharW( Path, L'.', 0 );
  IF i <> -1 THEN
    Path[i] := 0W;
  END;
  IF Extension[0] <> 0W THEN
    Strings.AppendW( REF Path, L'.' );
    Strings.AppendW( REF Path, Extension );
  END;
END ChangeExtensionW;  

PROCEDURE IsUNCW( CONST Path : ARRAY OF WCHAR ) : BOOLEAN;
BEGIN
  // the shortest UNC is: \\x\y, which is HIGH = 4
  IF INTEGER( HIGH( Path )) < 4 THEN
    RETURN FALSE;
  ELSE
    RETURN ( Path[0] = '\' ) AND ( Path[1] = '\' );
  END;
END IsUNCW;

PROCEDURE IsDriveW( CONST Path : ARRAY OF WCHAR ) : BOOLEAN;
BEGIN
  // the shortest volume path is: d:\, which is HIGH = 2
  IF HIGH( Path ) < 2 THEN
    RETURN FALSE;
  ELSE
    RETURN Path[1] = L':';
  END;
END IsDriveW;

(*================================================================================*)

PROCEDURE CreateDirectoryW( CONST Directory : ARRAY OF WCHAR ) : BOOLEAN;
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
      IF ExistsDirectoryW( work ) THEN
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
END CreateDirectoryW;

PROCEDURE ExistsDirectoryW( CONST Name: ARRAY OF WCHAR ): BOOLEAN;
VAR
  attr : CARDINAL;
  ln : PathStrW;
BEGIN
  ln := Name;
  attr := windows.GetFileAttributesW( ADR( ln ));
  IF attr = MAX( CARDINAL ) THEN
    RETURN FALSE;
  ELSE
    RETURN windows.FILE_ATTRIBUTE_DIRECTORY AND attr <> 0;
  END;
END ExistsDirectoryW;

(*================================================================================*)

PROCEDURE FullPathToVolumeAndPathW( CONST FullPath : ARRAY OF WCHAR; OUT Volume, Path : ARRAY OF WCHAR );
VAR
  i : CARDINAL;
  LPath : PathStrW;
BEGIN
  LPath := FullPath;
  IF IsUNCW( LPath ) THEN
    i := Strings.IndexOfCharW( LPath, L'\', 3 );
    IF i <> -1 THEN
      i := Strings.IndexOfCharW( LPath, L'\', i+1 );
    END;
    IF i = -1 THEN
      ASSIGN( Volume, LPath );
      Path := L'';
    ELSE
      Strings.SubstringW( LPath, 0, i, OUT Volume );
      Strings.SubstringW( LPath, i+1, -1, OUT Path );
    END;
  ELSIF IsDriveW( LPath ) THEN
    IF LPath[2] = L'\' THEN
      Strings.SubstringW( LPath, 0, 2, OUT Volume );
      Strings.SubstringW( LPath, 3, -1, OUT Path );
    ELSE
      Volume := L'';
      ASSIGN( Path, LPath );
    END;
  ELSE
    Volume := L'';
    ASSIGN( Path, LPath );
  END;    
END FullPathToVolumeAndPathW;

PROCEDURE ShortPathToHeadAndTailW( CONST ShortPath : ARRAY OF WCHAR; OUT Head, Tail : ARRAY OF WCHAR );
VAR
  i : CARDINAL;
BEGIN
  i := Strings.LastIndexOfCharW( ShortPath, L'\', 0 );
  IF i = -1 THEN
    ASSIGN( Tail, ShortPath );
    Head := L'';
  ELSE
    Strings.SubstringW( ShortPath, 0, i, OUT Head );
    Strings.SubstringW( ShortPath, i+1, -1, OUT Tail );
  END;
END ShortPathToHeadAndTailW;

PROCEDURE NormalizePathW( REF Path : ARRAY OF WCHAR ) : BOOLEAN;
BEGIN
  RETURN FALSE;
END NormalizePathW;

PROCEDURE MakePathW( CONST Head, Tail : ARRAY OF WCHAR; OUT Path : ARRAY OF WCHAR );
VAR
   LPath : PathStrW;
BEGIN
   IF HIGH( Head ) = -1 THEN
      ASSIGN( LPath, Tail );
   ELSIF Head[ LENGTH( Head ) - 1 ] = '\' THEN
      Strings.ConcatW( OUT LPath, Head, Tail );
   ELSIF Head[0] = 0W THEN
      ASSIGN( LPath, Tail );
   ELSE
      Strings.ConcatW( OUT LPath, Head, L'\' );
      Strings.AppendW( REF LPath, Tail );
   END;
   Path := LPath;
END MakePathW;

PROCEDURE SplitPathW( CONST FullPath : ARRAY OF WCHAR; OUT Head, Tail : ARRAY OF WCHAR );
VAR
  H, P, V : PathStrW;
BEGIN
  FullPathToVolumeAndPathW( FullPath, OUT V, OUT P );
  ShortPathToHeadAndTailW( P, OUT H, OUT Tail );
  IF H[0] = 0W THEN
    ASSIGN( Head, V );
  ELSIF V[0] = 0W THEN
    ASSIGN( Head, H );
  ELSE
    Strings.ConcatW( OUT Head, V, L'\' );
    Strings.AppendW( REF Head, H );
  END;
END SplitPathW;

PROCEDURE PathHeadW( CONST FullPath : ARRAY OF WCHAR; OUT Head : ARRAY OF WCHAR );
VAR
  H, P, V, T : PathStrW;
BEGIN
  FullPathToVolumeAndPathW( FullPath, OUT V, OUT P );
  ShortPathToHeadAndTailW( P, OUT H, OUT T );
  IF H[0] = 0W THEN
    ASSIGN( Head, V );
  ELSIF V[0] = 0W THEN
    ASSIGN( Head, H );
  ELSE
    Strings.ConcatW( OUT Head, V, L'\' );
    Strings.AppendW( REF Head, H );
  END;
END PathHeadW;

PROCEDURE PathTailW( CONST FullPath : ARRAY OF WCHAR; OUT Tail : ARRAY OF WCHAR );
VAR
  H, P, V : PathStrW;
BEGIN
  FullPathToVolumeAndPathW( FullPath, OUT V, OUT P );
  ShortPathToHeadAndTailW( P, OUT H, OUT Tail );
END PathTailW;

PROCEDURE PathAddW( REF Path : ARRAY OF WCHAR; CONST AddedPath : ARRAY OF WCHAR );
BEGIN
   MakePathW( Path, AddedPath, OUT Path );
END PathAddW;

PROCEDURE ExpandPathW( CONST Path : ARRAY OF WCHAR; OUT ExpandedPath : ARRAY OF WCHAR ); // expands or canonizes path
VAR
   Ch : windows.PWSTR;
   In : PathStrW;
BEGIN
   In := Path;
   IF windows.GetFullPathNameW( ADR( In ), HIGH( ExpandedPath )+1, ADR( ExpandedPath ), OUT Ch ) = 0 THEN
      ExpandedPath[0] := 0W;
   END;
END ExpandPathW;

PROCEDURE IOresult(): CARDINAL;
BEGIN
  RETURN CARDINAL( windows.GetLastError());
END IOresult;

PROCEDURE OpenW( CONST Name: ARRAY OF WCHAR; ShareMode: TFileShare ) : File;
VAR
   f : File;
   fs : CARDINAL := 0;
   ln : PathStrW;
BEGIN
   ln := Name;
   IF fsRead IN ShareMode THEN
      fs := fs OR windows.FILE_SHARE_READ;
   END;
   IF fsWrite IN ShareMode THEN
      fs := fs OR windows.FILE_SHARE_WRITE;
   END;
   IF fsDelete IN ShareMode THEN
      fs := fs OR windows.FILE_SHARE_DELETE;
   END;
   f := windows.CreateFileW(
      ADR( ln ),
      windows.GENERIC_READ OR windows.GENERIC_WRITE,
      fs,
      NIL,
      windows.OPEN_EXISTING,
      windows.FILE_ATTRIBUTE_NORMAL,
      NIL );
   IF f = windows.INVALID_HANDLE_VALUE THEN
      RETURN NIL;
   ELSE
      RETURN f;
   END;
END OpenW;

PROCEDURE OpenReadW( CONST Name: ARRAY OF WCHAR; ShareMode: TFileShare ) : File;
VAR
   f : File;
   fs : CARDINAL := 0;
   ln : PathStrW;
BEGIN
   ln := Name;
   IF fsRead IN ShareMode THEN
      fs := fs OR windows.FILE_SHARE_READ;
   END;
   IF fsWrite IN ShareMode THEN
      fs := fs OR windows.FILE_SHARE_WRITE;
   END;
   f := windows.CreateFileW(
      ADR( ln ),
      windows.GENERIC_READ,
      fs,
      NIL,
      windows.OPEN_EXISTING,
      windows.FILE_ATTRIBUTE_NORMAL,
      NIL );
   IF f = windows.INVALID_HANDLE_VALUE THEN
      RETURN NIL;
   ELSE
      RETURN f;
   END;
END OpenReadW;

PROCEDURE CreateW( CONST Name: ARRAY OF WCHAR; ShareMode: TFileShare ) : File;
VAR
   f : File;
   fs : CARDINAL := 0;
   ln : PathStrW;
BEGIN
   ln := Name;
   IF fsRead IN ShareMode THEN
      fs := fs OR windows.FILE_SHARE_READ;
   END;
   IF fsWrite IN ShareMode THEN
      fs := fs OR windows.FILE_SHARE_WRITE;
   END;
   f := windows.CreateFileW(
      ADR( ln ),
      windows.GENERIC_READ OR windows.GENERIC_WRITE,
      fs,
      NIL,
      windows.CREATE_ALWAYS,
      windows.FILE_ATTRIBUTE_NORMAL,
      NIL );
   IF f = windows.INVALID_HANDLE_VALUE THEN
      RETURN NIL;
   ELSE
      RETURN f;
   END;
END CreateW;

PROCEDURE AppendW( CONST Name: ARRAY OF WCHAR; ShareMode: TFileShare ) : File;
VAR
   f : File;
   fs : CARDINAL := 0;
   ln : PathStrW;
BEGIN
   ln := Name;
   IF fsRead IN ShareMode THEN
      fs := fs OR windows.FILE_SHARE_READ;
   END;
   IF fsWrite IN ShareMode THEN
      fs := fs OR windows.FILE_SHARE_WRITE;
   END;
   f := windows.CreateFileW( ADR( ln ),
                             windows.GENERIC_READ OR windows.GENERIC_WRITE,
                             fs,
                             NIL,
                             windows.OPEN_EXISTING,
                             windows.FILE_ATTRIBUTE_NORMAL,
                             NIL );
   IF f = windows.INVALID_HANDLE_VALUE THEN
      RETURN NIL;
   ELSE
      windows.SetFilePointer( f, 0, NIL, windows.FILE_END );
      RETURN f;
   END;
END AppendW;

PROCEDURE ExistsW( CONST Name: ARRAY OF WCHAR ): BOOLEAN;
VAR
  attr : CARDINAL;
  ln : PathStrW;
BEGIN
  ln := Name;
  attr := windows.GetFileAttributesW( ADR( ln ));
  IF attr = MAX( CARDINAL ) THEN
    RETURN FALSE;
  ELSE
    RETURN windows.FILE_ATTRIBUTE_DIRECTORY AND attr = 0;
  END;
END ExistsW;

PROCEDURE DeleteW( CONST Name: ARRAY OF WCHAR );
VAR
  ln : PathStrW;
BEGIN
  ln := Name;
  windows.DeleteFileW( ADR( ln ));
END DeleteW;

PROCEDURE RenameW( CONST Name, NewName: ARRAY OF WCHAR );
VAR
  ln1, ln2 : PathStrW;
BEGIN
  ln1 := Name;
  ln2 := NewName;
  windows.MoveFileW( ADR( ln1 ), ADR( ln2 ));
END RenameW;

PROCEDURE IsUnicodeFile( F : File ) : BOOLEAN;
CONST
  unicodeMagic = WCHAR( 0FEFFH );
VAR
  UnicodeMagic : WCHAR;
  IsUnicode    : BOOLEAN;
BEGIN
  Seek( F, 0 );
  IF RdBin( F, UnicodeMagic, 2 ) < 2 THEN
    IsUnicode := FALSE;
    Seek( F, 0 );
  ELSE
    IF UnicodeMagic = unicodeMagic THEN
      IsUnicode := TRUE;
    ELSIF CARDINAL( UnicodeMagic ) AND 0FF00H = 0 THEN
      IsUnicode := TRUE;
      Seek( F, 0 );
    ELSE
      IsUnicode := FALSE;
      Seek( F, 0 );
    END;
  END;
  RETURN IsUnicode;
END IsUnicodeFile;

PROCEDURE Close( F: File );
BEGIN
  windows.CloseHandle( F );
END Close;

PROCEDURE Size( F: File ): CARDINAL;
BEGIN
  RETURN CARDINAL( windows.GetFileSize( F, NIL ));
END Size;

PROCEDURE GetPos( F: File ): CARDINAL;
BEGIN
  RETURN CARDINAL( windows.SetFilePointer( F, 0, NIL, windows.FILE_CURRENT ));
END GetPos;

PROCEDURE Seek( F: File; Pos: CARDINAL );
BEGIN
  windows.SetFilePointer( F, Pos, NIL, windows.FILE_BEGIN );
END Seek;

PROCEDURE Truncate( F: File );
BEGIN
  windows.SetEndOfFile( F );
END Truncate;

PROCEDURE Flush( F: File );
BEGIN
  windows.FlushFileBuffers( F );
END Flush;

PROCEDURE EndOfFile( F: File ): BOOLEAN;
BEGIN
  RETURN windows.SetFilePointer( F, 0, NIL, windows.FILE_CURRENT ) = windows.GetFileSize( F, NIL );
END EndOfFile;

PROCEDURE GetFileTime( F : File ): FileTime;
VAR
  ct, at, wt : windows.FILETIME;
BEGIN
  windows.GetFileTime( F, ADR( ct ), ADR( at ), ADR( wt ));
  RETURN FileTime(wt);
END GetFileTime;

PROCEDURE SetFileTime( F : File; Time : FileTime );
VAR
  ct : windows.FILETIME;
BEGIN
  ct := windows.FILETIME( Time );
  windows.SetFileTime( F, ADR( ct ), ADR( ct ), ADR( ct ));
END SetFileTime;

PROCEDURE WrBin( F : File; Buf : ARRAY OF BYTE; Count : CARDINAL ) : CARDINAL;
VAR
  WrittenCount : CARDINAL;
BEGIN
  windows.WriteFile( F, ADR( Buf ), Count, ADR( WrittenCount ), NIL );
  RETURN WrittenCount;
END WrBin;

PROCEDURE WrStrW( F : File; Buf : ARRAY OF WCHAR);
BEGIN
  WrBin( F, Buf, LENGTH( Buf ) * SIZE( WCHAR ));
END WrStrW;

PROCEDURE WrLnW( F : File );
CONST
  EOL = WCHAR( 13 ) + WCHAR( 10 );
BEGIN
  WrBin( F, EOL, 2 * SIZE( WCHAR ));
END WrLnW;

PROCEDURE WrStrA( F : File; Buf : ARRAY OF CHAR );
BEGIN
  WrBin( F, Buf, LENGTH( Buf ));
END WrStrA;

PROCEDURE WrLnA( F: File );
CONST
  EOL = CHAR( 13 ) + CHAR( 10 );
BEGIN
  WrBin( F, EOL, 2 );
END WrLnA;

PROCEDURE RdBin( F: File; VAR Buf: ARRAY OF BYTE; Count: CARDINAL ): CARDINAL;
VAR 
  ReadCount : CARDINAL;
BEGIN
  windows.ReadFile( F, ADR( Buf ), Count, ADR( ReadCount ), NIL );
  RETURN ReadCount;
END RdBin;

PROCEDURE RdCharW( F : File ) : WCHAR;
VAR 
  c : WCHAR;
  ReadCount : CARDINAL;
BEGIN
  windows.ReadFile( F, ADR( c ), SIZE( WCHAR ), ADR( ReadCount ), NIL );
  IF ReadCount = 0 THEN
    RETURN WCHAR( 0 );
  ELSE
    RETURN c;
  END;
END RdCharW;

PROCEDURE RdStrW( F : File; VAR Buf: ARRAY OF WCHAR );
VAR
  i, h : CARDINAL;
  c : WCHAR;
BEGIN
  i := 0;
  h := HIGH( Buf );
  LOOP
    IF i > h THEN
      RETURN
    END;
    c := RdCharW( F );
    CASE c OF
    | WCHAR( 26 ): Buf[i] := WCHAR( 0 ); RETURN;
    | WCHAR( 10 ): Buf[i] := WCHAR( 0 ); RETURN;
    END;
    IF c <> WCHAR( 13 ) THEN // skip CR
      Buf[i] := c;
      INC( i );
    END;
  END;
END RdStrW;

PROCEDURE RdCharA( F : File ) : CHAR;
VAR 
  c : CHAR;
  ReadCount : CARDINAL;
BEGIN
  windows.ReadFile( F, ADR( c ), SIZE( CHAR ), ADR( ReadCount ), NIL );
  IF ReadCount = 0 THEN
    RETURN CHAR( 0 );
  ELSE
    RETURN c;
  END;
END RdCharA;

PROCEDURE RdStrA( F: File; VAR Buf: ARRAY OF CHAR );
VAR
  i, h : CARDINAL;
  c : CHAR;
BEGIN
  i := 0;
  h := HIGH( Buf );
  LOOP
    IF i > h THEN
      RETURN
    END;
    c := RdCharA( F );
    CASE c OF
    | CHAR( 26 ): Buf[i] := CHAR( 0 ); RETURN;
    | CHAR( 10 ): Buf[i] := CHAR( 0 ); RETURN;
    END;
    IF c <> CHAR( 13 ) THEN // skip CR
      Buf[i] := c;
      INC( i );
    END;
  END;
END RdStrA;

PROCEDURE GetModulePathW( CONST ModuleName : ARRAY OF WCHAR; OUT ModulePath : ARRAY OF WCHAR ) : BOOLEAN;
VAR
   c : CARDINAL;
   HModule : windows.HANDLE;
   lm : PathStrW;
BEGIN
   lm := ModuleName;
   IF lm[0] = 0W THEN
      HModule := windows.GetModuleHandleW( NIL );
   ELSE
      HModule := windows.GetModuleHandleW( ADR( ModuleName ));
   END;
   IF HModule = NIL THEN
      RETURN FALSE;
   END;
   c := windows.GetModuleFileNameW( HModule, ADR( ModulePath ), HIGH( ModulePath )+1 );
   IF c = 0 THEN
      RETURN FALSE;
   ELSIF c <= HIGH( ModulePath ) THEN
      ModulePath[c] := 0W;
   END;
   RETURN TRUE;
END GetModulePathW;

PROCEDURE GetModuleDirW( CONST ModuleName : ARRAY OF WCHAR; OUT ModuleDir : ARRAY OF WCHAR ) : BOOLEAN;
VAR
   lpath : FIO.PathStrW;
BEGIN
   IF NOT GetModulePathW( ModuleName, OUT lpath ) THEN
      RETURN FALSE;
   END;
   PathHeadW( lpath, OUT ModuleDir );
   RETURN TRUE;
END GetModuleDirW;

END FIO.
