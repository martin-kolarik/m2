MODULE discover;

(*================================================================================*)

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   winsock, // must be the first
   arrays,
   browser,
   INIFile,
   lists,
   msgqueuethread,
   netinit,
   Resources,
   Strings,
   StringsO,
   Sync,
   Texts,
   TextWriter;
   
(*================================================================================*)

VAR
   R : Resources.CResources;

(*--------------------------------------------------------------------------------*)

TYPE
   TPThread = POINTER TO CThread;

(*--------------------------------------------------------------------------------*)

CLASS CResult( browser.CBrowserDelegate );
   LOCAL VAR
      Thread : TPThread;
      IPs : lists.CStringList;
   LOCAL VIRTUAL PROCEDURE OnCompleted( Result : Sync.TAsyncResult; CONST Servers : arrays.CPtrArray );
END CResult;

(*--------------------------------------------------------------------------------*)

CLASS CThread( msgqueuethread.MsgQueueThread );
   LOCAL VAR
      ShowDots : CARDINAL := 1; // sync
      Browser : browser.CBrowser;  
      Result : CResult;
   INTERNAL VIRTUAL PROCEDURE OnStart();
   INTERNAL VIRTUAL PROCEDURE OnExit();
END CThread;

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
      Sync.IExchg( REF Thread^.ShowDots, 0 ); // stop to show dots
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
            
            Strings.FromIPV4( server^.Address.s_addr, OUT s );
            S.FromOA( s );
            S.AppendOA( L":" );
            Strings.FromCARD32W( server^.Port, 10, OUT s );
            S.AppendOA( s );
            IPs.Add( S, 0 );

            stdout^.WriteOA( L", IP: ", FALSE ); stdout^.Write( S, TRUE );
         END;
      END;
      Thread^.Stop( FALSE );
   END OnCompleted;

(*--------------------------------------------------------------------------------*)

BEGIN
   Thread := NIL;
END CResult;

(*================================================================================*)

CLASS IMPLEMENTATION CThread;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnStart();
   BEGIN
      Browser.Init();
      CASE Browser.Browse( ADR( Result ), 0 ) OF
      | Sync.arCompleted, Sync.arPending : // OK
      ELSE
         TextWriter.errout()^.WriteOA( OAsz( R[Texts._UnableToStartDiscovery] ), TRUE );
         Stop( FALSE );
      END;
   END OnStart;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnExit();
   BEGIN
      Browser.Dispose();
   END OnExit;

(*--------------------------------------------------------------------------------*)

BEGIN
   Result.Thread := ADR( SELF );
END CThread;

(*================================================================================*)

TYPE
   TParamStringArray  = ARRAY [0..0] OF POINTER TO ARRAY [0..511] OF WCHAR;
   TPParamStringArray = POINTER TO TParamStringArray;
  
# save, call( convention => cdecl )
PROCEDURE wmain( argc : INTEGER; argp : TPParamStringArray; enpv : TPParamStringArray ) : INTEGER;
# restore
LABEL
   Error, Stop;
VAR
   ConfigFile : StringsO.CString;
   errout : TextWriter.TPTextWriter := TextWriter.errout();
   First : BOOLEAN := TRUE;
   ForceFlag : BOOLEAN := FALSE;
   i : INTEGER;
   Id : StringsO.CString;
   Thread : CThread;
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

   errout^.WriteOA( OAsz( R[Texts._Searching] ), FALSE );
   Thread.Run( FALSE );
   WHILE ( Sync.IGet( REF Thread.ShowDots ) = 1 ) AND ( Thread.WaitStop( 250 ) = Sync.arTimeout ) DO
      errout^.WriteOA( L".", FALSE );
   END; // WHILE
   
   IF NOT ConfigFile.Empty THEN
      TS.LoadPath( OA( ConfigFile.Length-1, ConfigFile.rawData ));
      TS.CreateSection( L"device", FALSE );
      IF Thread.Result.IPs.Empty THEN
         TS.SetKeyStr( L"id", Id, FALSE );
      ELSE
         Thread.Result.IPs.Reset();
         WHILE Thread.Result.IPs.MoveNext() DO
            Id.FromOA( L"eibnet:" );
            Id.Append( Thread.Result.IPs.Current^ );
            IF ForceFlag AND First THEN
               TS.SetKeyStr( L"id", Id, NOT First );
               First := FALSE;
            ELSE
               TS.SetKeyStr( L"scanned.id", Id, NOT First );
            END;
         END; // WHILE
      END;
      IF NOT TS.SavePath( OA( ConfigFile.Length-1, ConfigFile.rawData )) THEN
         errout^.WriteOA( OAsz( R[Texts._UnableToSaveConfigFile] ), TRUE );
         GOTO Stop;
      END;
   END;

   RETURN 0;

Error:
   errout^.WriteOA( OAsz( R[Texts._UsageInfo] ), TRUE );

Stop:
   RETURN -1;
END wmain;
  
(*================================================================================*)

BEGIN
   netinit.Startup();
FINALLY
   netinit.Cleanup();
END discover.