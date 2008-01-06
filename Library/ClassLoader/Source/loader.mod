IMPLEMENTATION MODULE loader;

IMPORT
   FIO,
   Strings,
   StringsO,
   windows;

(*===========================================================================*)

TYPE
   TPLibrary = POINTER TO CLibrary;

CLASS CLibrary;
   LOCAL VAR
      Path : StringsO.CString;
      State : TState;
      Loader : TPLoader;
      RefCount : CARDINAL;
   PRIVATE VAR
      LibraryHandle : windows.HANDLE;
      LibraryInfo : objlib.TPLibrary;
      Factory : objlib.TFactory;
   LOCAL READONLY PROPERTY
      Name : StringsO.CString;

   LOCAL PROCEDURE CreateObject( CONST ClassName : ARRAY OF WCHAR; OUT Object : objlib.TPObject ) : objlib.TResult;
   LOCAL PROCEDURE ReleaseObject( Object : objlib.TPObject );
   
   PRIVATE PROCEDURE LoadLibrary() : objlib.TResult;
   PRIVATE PROCEDURE UnloadLibrary();
END CLibrary;

(*===========================================================================*)

CLASS IMPLEMENTATION CLibrary;

(*---------------------------------------------------------------------------*)

   LOCAL PROPERTY Name GET : StringsO.CString;
   VAR
      FileName : FIO.PathStrW;
      S : StringsO.CString;
   BEGIN
      FIO.PathTailW( OA( Path.Length-1, Path.rawData ), OUT FileName );
      FIO.ChangeExtensionW( REF FileName, L"" );
      S.FromOA( FileName );
      RETURN S;
   END Name;

(*---------------------------------------------------------------------------*)

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
      Result := Factory( ClassName, OUT Object );
      IF Result = objlib.lrSuccess THEN
         INC( RefCount );
      END;
      RETURN Result;
   END CreateObject;

(*---------------------------------------------------------------------------*)

   LOCAL PROCEDURE ReleaseObject( Object : objlib.TPObject );
   BEGIN
      ASSERT(( LibraryHandle <> NIL ) AND ( RefCount > 0 ));
      Object^.Dispose();
      DEC( RefCount );
      IF RefCount = 1 THEN // the last one is LibraryInfo
         UnloadLibrary();
      END;
   END ReleaseObject;
   
(*---------------------------------------------------------------------------*)

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

      Factory := windows.GetProcAddress( LibraryHandle, C"Factory" );
      IF Factory = NIL THEN
         UnloadLibrary();
         RETURN objlib.lrLibraryFoundButIsUnloadable;
      END;
      Result := Factory( objlib.nLibrary, OUT LibraryInfo );
      IF Result = objlib.lrSuccess THEN
         INC( RefCount );
      ELSE
         UnloadLibrary();
         RETURN objlib.lrLibraryFoundButIsUnloadable;
      END;

      LibraryInfo^.HostInfo( Loader, ADR( SELF ), OA( Loader^.Host^.Length-1, Loader^.Host^.rawData ), OA( Loader^.HostVersionString^.Length-1, Loader^.HostVersionString^.rawData ));

      RETURN objlib.lrSuccess;
   END LoadLibrary;
   
(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE UnloadLibrary();
   BEGIN
      IF LibraryHandle <> NIL THEN
         ASSERT(( RefCount = 1 ) OR ( LibraryInfo = NIL )); // the last one is LibraryInfo, LibraryInfo = NIL in case of unloadability of library

         IF LibraryInfo <> NIL THEN
            ReleaseObject( LibraryInfo );
         END;
         windows.FreeLibrary( LibraryHandle );
         LibraryHandle := NIL;
         Factory := NIL;
      END;
   END UnloadLibrary;

(*---------------------------------------------------------------------------*)

BEGIN
   State := TState{lsEnabled};
   Loader := NIL;
   RefCount := 0;
   LibraryHandle := NIL;
   LibraryInfo := NIL;
   Factory := NIL;
FINALLY
   UnloadLibrary();
END CLibrary;

(*===========================================================================*)

CLASS IMPLEMENTATION CLoader;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Host GET : StringsO.TPString;
   BEGIN
      RETURN ADR( _Host );
   END Host;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY HostVersionString GET : StringsO.TPString;
   BEGIN
      RETURN ADR( _HostVersionString );
   END HostVersionString;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SetHostInfo( CONST Host, HostVersionString : ARRAY OF WCHAR );
   BEGIN
      SELF._Host.FromOA( Host );
      SELF._HostVersionString.FromOA( HostVersionString );
   END SetHostInfo;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE AddLibrary( CONST LibraryPath : ARRAY OF WCHAR ) : objlib.TResult;
   VAR
      Library : TPLibrary;
      LPath : FIO.PathStrW;
   BEGIN
      FIO.ExpandPathW( LibraryPath, OUT LPath );
      IF NOT LookupLibrary( LPath, OUT Library ) THEN
         NEW( Library );
         Library^.Path.FromOA( LPath );
         Library^.Loader := ADR( SELF );
         Libraries.Add( Library, 0 );
      END;
      BuildNames();
      RETURN objlib.lrSuccess;
   END AddLibrary;

(*---------------------------------------------------------------------------*)

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

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ScanPath( CONST Path, LibraryNamePattern : ARRAY OF WCHAR; OUT Found : CARDINAL ) : objlib.TResult;
   BEGIN
      RETURN objlib.lrSuccess;
   END ScanPath;

(*---------------------------------------------------------------------------*)

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
   
(*---------------------------------------------------------------------------*)

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

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE EnumerateLibraries( REF EnumerateState : PTR; OUT LibraryName, LibraryPath : ARRAY OF WCHAR; OUT State : TState ) : BOOLEAN;
   VAR
      b : BOOLEAN;
      Data : PTR;
      Library : TPLibrary;
   BEGIN
      IF EnumerateState = 0 THEN
         b := Libraries.GetFirst( OUT Library, OUT Data );
      ELSE
         b := Libraries.NextOf( EnumerateState, OUT Library, OUT Data );
      END;
      IF NOT b THEN
         RETURN FALSE;
      END;
      
      Library^.Name.ToOA( OUT LibraryName );
      Library^.Path.ToOA( OUT LibraryPath );
      
      EnumerateState := Library;
      RETURN TRUE;
   END EnumerateLibraries;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE EnumerateClasses( REF EnumerateState : PTR; CONST LibraryName : ARRAY OF WCHAR; FullClassPathFlag : BOOLEAN; OUT ClassNameOrPath : ARRAY OF WCHAR ) : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END EnumerateClasses;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CreateObject( CONST ClassPath : ARRAY OF WCHAR; OUT Object : objlib.TPObject ) : objlib.TResult;
   VAR
      i : INTEGER;
      Library : TPLibrary;
      s : FIO.PathStrW;
   BEGIN
      i := Strings.ItemSW( ClassPath, Strings.WCHARS{L"/"}, 0, 0, FALSE, OUT s );
      IF s[0] = 0W THEN
         RETURN objlib.lrLibraryNotFound;
      ELSIF NOT Names.GetOA( s, OUT Library ) THEN
         RETURN objlib.lrLibraryNotFound;
      ELSE
         Strings.SubstringW( ClassPath, i, -1, OUT s );
         RETURN Library^.CreateObject( s, OUT Object );
      END;
   END CreateObject;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ReleaseObject( REF Object : objlib.TPObject );
   BEGIN
      IF ( Object = NIL ) OR ( Object^.Library = NIL ) THEN
         ASSERT( FALSE );
         RETURN;
      ELSIF Object^.Library^.Loader <> ADR( SELF ) THEN
         ASSERT( FALSE );
         RETURN;
      END;
      TPLibrary( Object^.Library^.LoaderLibraryHandle )^.ReleaseObject( Object );
      Object := NIL;
   END ReleaseObject;
   
(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Dispose();
   VAR
      Library : TPLibrary;
   BEGIN
      Libraries.Reset();
      WHILE Libraries.MoveNext() DO
         Library := TPLibrary( Libraries.Current );
         ASSERT( Library^.RefCount = 0 );
         DISPOSE( Library );
      END; // WHILE
      Libraries.Dispose();
      Names.Dispose();
   END Dispose;

(*---------------------------------------------------------------------------*)

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
   
(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE BuildNames();
   VAR
      Library : TPLibrary;
      Name : StringsO.CString;
   BEGIN
      Names.Dispose();
      Libraries.Reset();
      WHILE Libraries.MoveNext() DO
         Library := TPLibrary( Libraries.Current );
         Name := Library^.Name;
         Name.Lowerize();
         IF ( lsEnabled IN Library^.State ) AND NOT Names.Contains( Name ) THEN
            Names.Add( Name, Library );
         END;
      END; // WHILE
   END BuildNames;

(*---------------------------------------------------------------------------*)

BEGIN
   _Host.FromOA( ProductId );
   _HostVersionString.FromOA( ProductVersion );
FINALLY
   Dispose();
END CLoader;

(*===========================================================================*)

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

(*---------------------------------------------------------------------------*)

BEGIN FINALLY
   IF PLoader <> NIL THEN
      DISPOSE( PLoader );
   END;
END loader.