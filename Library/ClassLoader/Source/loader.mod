IMPLEMENTATION MODULE loader;

IMPORT
   FIO,
   Strings,
   StringsO,
   windows;

TYPE
   TPLibrary = POINTER TO CLibrary;

CLASS CLibrary;
   LOCAL VAR
      Path : StringsO.CString;
      State : TState;
      Loader : objlib.TPLoader;
      RefCount : CARDINAL;
   PRIVATE VAR
      LibraryHandle : windows.HANDLE;
      GetObject : objlib.TGetObject;
      Library : objlib.TPLibrary;
   LOCAL READONLY PROPERTY
      Name : StringsO.CString;

   LOCAL PROCEDURE CreateObject( CONST ClassName : ARRAY OF WCHAR; OUT Object : objlib.TPObject ) : objlib.TResult;
   LOCAL PROCEDURE ReleaseObject( Object : objlib.TPObject );
   
   PRIVATE PROCEDURE LoadLibrary() : objlib.TResult;
   PRIVATE PROCEDURE UnloadLibrary();
END CLibrary;

CLASS IMPLEMENTATION CLibrary;

   LOCAL PROPERTY Name GET : StringsO.CString;
   VAR
      FileName : FIO.PathStrW;
      S : StringsO.CString;
   BEGIN
      FIO.PathTailW( OA( Path.Length-1, Path.rawData ), OUT FileName );
      S.FromOA( FileName );
      RETURN S;
   END Name;

   LOCAL PROCEDURE CreateObject( CONST ClassName : ARRAY OF WCHAR; OUT Object : objlib.TPObject ) : objlib.TResult;
   VAR
      Result : objlib.TResult;
   BEGIN
      IF LibraryHandle = NIL THEN
         Result := LoadLibrary();
         IF Result <> objlib.lrSuccess THEN
            RETURN Result;
         END;
      END;
      Result := GetObject( ClassName, OUT Object );
      IF Result = objlib.lrSuccess THEN
         INC( RefCount );
      END;
      RETURN Result;
   END CreateObject;

   LOCAL PROCEDURE ReleaseObject( Object : objlib.TPObject );
   BEGIN
      ASSERT(( LibraryHandle <> NIL ) AND ( RefCount > 0 ));
      DEC( RefCount );
      IF RefCount = 0 THEN
         UnloadLibrary();
      END;
   END ReleaseObject;
   
   PRIVATE PROCEDURE LoadLibrary() : objlib.TResult;
   VAR
      EM : CARDINAL;
      Result : objlib.TResult;
   BEGIN
      ASSERT( LibraryHandle = NIL );
      EM := windows.SetErrorMode( windows.SEM_FAILCRITICALERRORS );
      LibraryHandle := windows.LoadLibrary( Path.szData );
      windows.SetErrorMode( EM );
      IF LibraryHandle = NIL THEN
         RETURN objlib.lrLibraryNotFound;
      END;

      GetObject := windows.GetProcAddress( LibraryHandle, C"_GetObject" );
      IF GetObject = NIL THEN
         UnloadLibrary();
         RETURN objlib.lrLibraryFoundButIsUnloadable;
      END;
      Result := GetObject( objlib.nLibrary, OUT Library );
      IF Result <> objlib.lrSuccess THEN
         UnloadLibrary();
         RETURN objlib.lrLibraryFoundButIsUnloadable;
      END;

      Library^.Loader := Loader;
      Library^.HostInfo( ProductId, L"" ); // TODO

      RETURN objlib.lrSuccess;
   END LoadLibrary;
   
   PRIVATE PROCEDURE UnloadLibrary();
   BEGIN
      ASSERT( RefCount = 0 );
      IF LibraryHandle <> NIL THEN
         IF Library <> NIL THEN
            Library^.Release();
            Library := NIL;
         END;
         windows.FreeLibrary( LibraryHandle );
         LibraryHandle := NIL;
         GetObject := NIL;
      END;
   END UnloadLibrary;

BEGIN
   State := TState{lsEnabled};
   Loader := NIL;
   RefCount := 0;
   LibraryHandle := NIL;
   GetObject := NIL;
   Library := NIL;
END CLibrary;

CLASS IMPLEMENTATION CLoader;

   PUBLIC PROCEDURE AddLibrary( CONST LibraryPath : ARRAY OF WCHAR ) : objlib.TResult;
   VAR
      Library : TPLibrary;
      LPath : FIO.PathStrW;
   BEGIN
      FIO.ExpandPathW( LibraryPath, OUT LPath );
      IF NOT LookupLibrary( LPath, OUT Library ) THEN
         NEW( Library );
         Library^.Path.FromOA( LPath );
         Library^.Loader := ADR( ILoader );
         Libraries.Add( Library, 0 );
      END;
      BuildNames();
      RETURN objlib.lrSuccess;
   END AddLibrary;

   PUBLIC PROCEDURE RemoveLibrary( CONST LibraryPath : ARRAY OF WCHAR );
   VAR
      LPath : FIO.PathStrW;
      NL : lists.CPtrList;
   BEGIN
      FIO.ExpandPathW( LibraryPath, OUT LPath );
      Libraries.Reset();
      WHILE Libraries.MoveNext() DO
         IF NOT TPLibrary( Libraries.Current )^.Path.EqualsOA( LPath ) THEN
           NL.Add( Libraries.Current, 0 );
         END;
      END; // WHILE
      Libraries.Dispose();
      Libraries.AppendList( REF NL );
      BuildNames();
   END RemoveLibrary;

   PUBLIC PROCEDURE EnumerateLibraryClasses( REF EnumerateState : PTR; CONST LibraryPath : ARRAY OF WCHAR; OUT ClassName : ARRAY OF WCHAR ) : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END EnumerateLibraryClasses;

   PUBLIC PROCEDURE ScanPath( CONST Path, LibraryNamePattern : ARRAY OF WCHAR; OUT Found : CARDINAL ) : objlib.TResult;
   BEGIN
      RETURN objlib.lrSuccess;
   END ScanPath;

   PUBLIC PROCEDURE DisableLibrary( CONST LibraryPath : ARRAY OF WCHAR );
   VAR
      Library : TPLibrary;
      LPath : FIO.PathStrW;
   BEGIN
      FIO.ExpandPathW( LibraryPath, OUT LPath );
      IF LookupLibrary( LPath, OUT Library ) THEN
         EXCL( Library^.State, lsEnabled );
         BuildNames();
      END;
   END DisableLibrary;
   
   PUBLIC PROCEDURE EnableLibrary( CONST LibraryPath : ARRAY OF WCHAR );
   VAR
      Library : TPLibrary;
      LPath : FIO.PathStrW;
   BEGIN
      FIO.ExpandPathW( LibraryPath, OUT LPath );
      IF LookupLibrary( LPath, OUT Library ) THEN
         INCL( Library^.State, lsEnabled );
         BuildNames();
      END;
   END EnableLibrary;

   PUBLIC PROCEDURE EnumerateLibraries( REF EnumerateState : PTR; OUT LibraryPath : ARRAY OF WCHAR; OUT State : TState ) : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END EnumerateLibraries;

   PUBLIC PROCEDURE EnumerateClasses( REF EnumerateState : PTR; CONST LibraryName : ARRAY OF WCHAR; OUT ClassName : ARRAY OF WCHAR ) : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END EnumerateClasses;

   PUBLIC PROCEDURE CreateObject( CONST ClassPath : ARRAY OF WCHAR; OUT Object : objlib.TPObject ) : objlib.TResult;
   VAR
      i : INTEGER;
      Library : TPLibrary;
      s : FIO.PathStrW;
   BEGIN
      i := Strings.ItemSW( ClassPath, Strings.WCHARS{L"."}, 0, 0, FALSE, OUT s );
      IF s[0] = 0W THEN
         RETURN objlib.lrLibraryNotFound;
      ELSIF NOT Names.GetOA( s, OUT Library ) THEN
         RETURN objlib.lrLibraryNotFound;
      ELSE
         Strings.SubstringW( ClassPath, i, -1, OUT s );
         RETURN Library^.CreateObject( s, OUT Object );
      END;
   END CreateObject;

   LOCAL PROCEDURE Dispose();
   VAR
      Library : TPLibrary;
   BEGIN
      Libraries.Reset();
      WHILE Libraries.MoveNext() DO
         Library := TPLibrary( Libraries.Current );
         ASSERT( Library^.RefCount = 0 );
         DISPOSE( Library );
      END; // WHILE
      Names.Dispose();
   END Dispose;

   // ILoader
   LOCAL VIRTUAL PROCEDURE ReleaseObject( LibraryHandle : PTR; Object : objlib.TPObject );
   BEGIN
      TPLibrary( LibraryHandle )^.ReleaseObject( Object );
   END ReleaseObject;

   PRIVATE PROCEDURE LookupLibrary( CONST LibraryPath : ARRAY OF WCHAR; OUT Library : ADDRESS ) : BOOLEAN;
   BEGIN
      Libraries.Reset();
      WHILE Libraries.MoveNext() DO
         IF TPLibrary( Libraries.Current )^.Path.EqualsOA( LibraryPath ) THEN
            Library := Libraries.Current;
            RETURN TRUE;
         END;
      END; // WHILE
      RETURN FALSE;
   END LookupLibrary;
   
   PRIVATE PROCEDURE BuildNames();
   BEGIN
     // TODO
   END BuildNames;

BEGIN FINALLY
   Dispose();
END CLoader;

// global loader
VAR
  PLoader : TPLoader := NIL;

PROCEDURE ldr() : TPLoader;
BEGIN
   IF PLoader = NIL THEN
      NEW( PLoader );
   END;
   RETURN PLoader;
END ldr;

BEGIN FINALLY
   IF PLoader <> NIL THEN
      DISPOSE( PLoader );
   END;
END loader.