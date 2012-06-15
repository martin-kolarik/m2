MODULE discover;

(*================================================================================*)

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   arrays,
   browser,
   collection,
   INIFile,
   lists,
   Resources,
   scinit,
   Strings,
   StringsO,
   Sync,
   Texts,
   TextWriter;
   
(*================================================================================*)

VAR
   R : Resources.CResources;

(*--------------------------------------------------------------------------------*)

CLASS CResult( browser.CBrowserDelegate );
   LOCAL VAR
      ShowDots : Sync.SIGNAL;
      InfoDone : Sync.SIGNAL;
      IPs : lists.CStringList;
   LOCAL VIRTUAL PROCEDURE OnCompleted( Result : Sync.TAsyncResult; CONST Servers : arrays.CPtrArray );
END CResult;

(*================================================================================*)

CLASS IMPLEMENTATION CResult;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnCompleted( Result : Sync.TAsyncResult; CONST Servers : arrays.CPtrArray );
   VAR
      i : CARDINAL;
      s : ARRAY [0..31] OF WCHAR;
      S : StringsO.CString;
      server : browser.TPServer;
      stdout : TextWriter.TPTextWriter := TextWriter.stdout();
   BEGIN
      ShowDots.Reset();
      stdout^.LineEnd();

      IF Servers.Empty THEN
         stdout^.WriteOA( OAsz( R[Texts._NoDevicesFound] ), TRUE );
      ELSE
         stdout^.WriteOA( OAsz( R[Texts._FoundCount] ), FALSE ); stdout^.WriteINT32( Servers.Count, 10, FALSE ); stdout^.WriteOA( OAsz( R[Texts._devices] ), TRUE );
         FOR i := 0 TO Servers.Count-1 DO
            server := browser.TPServer( Servers[i] );

            Strings.FromCARD32W( i+1, 10, OUT s );
            IF i < 10 THEN
               stdout^.WriteOA( L"     ", FALSE );
            ELSE
               stdout^.WriteOA( L"    ", FALSE );
            END;
            stdout^.WriteOA( s, FALSE ); stdout^.WriteOA( L". ", FALSE ); stdout^.Write( server^.Description, TRUE );

            stdout^.WriteOA( L"        MAC: ", FALSE ); stdout^.Write( server^.MAC, FALSE );
            
            server^.Address.ToOA( TRUE, NIL, OUT s );
            S.FromOA( s );
            IPs.Add( S, 0 );

            stdout^.WriteOA( L", IP: ", FALSE ); stdout^.Write( S, TRUE );
         END;
      END;

      InfoDone.Signal();
   END OnCompleted;

(*--------------------------------------------------------------------------------*)

BEGIN
   ShowDots.Signal();
   InfoDone.Reset();
END CResult;

(*================================================================================*)

TYPE
   TParamStringArray  = ARRAY [0..0] OF POINTER TO ARRAY [0..511] OF WCHAR;
   TPParamStringArray = POINTER TO TParamStringArray;
  
# save, call( convention => cdecl )
PROCEDURE Main( argc : INTEGER; argp : TPParamStringArray ) : INTEGER;
# restore
LABEL
   Error, Stop;
VAR
   Browser : browser.CBrowser;  
   ConfigFile : StringsO.CString;
   errout : TextWriter.TPTextWriter := TextWriter.errout();
   First : BOOLEAN := TRUE;
   ForceFlag : BOOLEAN := FALSE;
   i : INTEGER;
   it : lists.CStringListIterator;
   Id : StringsO.CString;
   Result : CResult;
   TS : INIFile.CINIFile;
BEGIN
   R.LoadRES2( EMIT( %exe ), L"discover.Texts" );

   i := 1;
   WHILE i < argc DO
      IF ( argp^[i]^[0] = L'/' ) OR ( argp^[i]^[0] = L'-' ) THEN // option
         CASE argp^[i]^[1] OF
         | 'h' :
            GOTO Error;
         | 'u', 'U' : // update cfg file
            ForceFlag := argp^[i]^[1] = 'U';
            INC( i );
            IF i >= argc THEN
               errout^.WriteOA( OAsz( R[Texts._MissingConfigurationFile] ), TRUE );
               GOTO Error;
            END;
            ConfigFile.FromOA( OAsz( argp^[i] ));
         ELSE
            errout^.WriteOA( OAsz( R[Texts._InvalidOption] ), FALSE ); errout^.WriteOA( argp^[i]^, TRUE );
            GOTO Error;
         END;
      END;
      INC( i );
   END; // WHILE

   CASE Browser.Browse( ADR( Result ), 0 ) OF
   | Sync.arCompleted, Sync.arPending : // OK
   ELSE
      TextWriter.errout()^.WriteOA( OAsz( R[Texts._UnableToStartDiscovery] ), TRUE );
      GOTO Stop;
   END;

   // browsing runs in separate thread
   errout^.WriteOA( OAsz( R[Texts._Searching] ), FALSE );
   WHILE Result.ShowDots.State DO
      errout^.WriteOA( L".", FALSE );
      Sync.Sleep( 250 );
   END; // WHILE
   
   // wait for emit informations
   WHILE NOT Result.InfoDone.State DO
      Sync.Sleep( 10 );
   END;
   
   IF NOT ConfigFile.Empty THEN
      TS.LoadPath( OA( ConfigFile.Length-1, ConfigFile.Data ));
      TS.CreateSection( L"device", FALSE );
      IF Result.IPs.Empty THEN
         TS.SetKeyStr( L"id", Id, FALSE );
      ELSE
         it.Init( Result.IPs, collection.dirForward );
         WHILE it.MoveNext() DO
            Id.FromOA( L"knxnet:" );
            Id.Append( it.Value^ );
            IF ForceFlag AND First THEN
               TS.SetKeyStr( L"id", Id, NOT First );
               First := FALSE;
            ELSE
               TS.SetKeyStr( L"scanned.id", Id, NOT First );
            END;
         END; // WHILE
      END;
      IF NOT TS.SavePath( OA( ConfigFile.Length-1, ConfigFile.Data )) THEN
         errout^.WriteOA( OAsz( R[Texts._UnableToSaveConfigFile] ), TRUE );
         GOTO Stop;
      END;
   END;

   RETURN 0;

Error:
   errout^.WriteOA( OAsz( R[Texts._UsageInfo] ), TRUE );

Stop:
   RETURN -1;
END Main;
  
(*================================================================================*)

BEGIN
   scinit.Startup();
FINALLY
   scinit.Cleanup();
END discover.