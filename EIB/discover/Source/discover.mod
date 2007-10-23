MODULE discover;

(*================================================================================*)

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   winsock, // must be the first
   arrays,
   browser,
   msgqueuethread,
   netinit,
   Resources,
   srvcore,
   StringsO,
   Sync,
   Texts,
   TextWriter;
   
(*================================================================================*)

VAR
   R : Resources.CResources;

CLASS CResult( browser.CBrowserDelegate );
   LOCAL VAR
      Thread : msgqueuethread.TPMsgQueueThread;
   LOCAL VIRTUAL PROCEDURE OnCompleted( Result : Sync.TAsyncResult; CONST Servers : arrays.CPtrArray );
END CResult;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CResult;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnCompleted( Result : Sync.TAsyncResult; CONST Servers : arrays.CPtrArray );
   VAR
      i : CARDINAL;
      server : browser.TPServer;
      stdout : TextWriter.TPTextWriter := TextWriter.stdout();
   BEGIN
      stdout^.LineEnd();

      IF Servers.Empty THEN
         stdout^.WriteOA( OAsz( R[Texts._NoDevicesFound] ), TRUE );
      ELSE
         stdout^.WriteOA( OAsz( R[Texts._FoundCount] ), FALSE ); stdout^.WriteINT32( Servers.Count, 10, FALSE ); stdout^.WriteOA( OAsz( R[Texts._devices] ), TRUE );
         FOR i := 0 TO Servers.Count-1 DO
            server := browser.TPServer( Servers[i] );
            stdout^.WriteOA( L"  ", FALSE ); stdout^.Write( server^.Description, TRUE );
         END;
      END;
      Thread^.Stop( FALSE );
   END OnCompleted;

(*--------------------------------------------------------------------------------*)

BEGIN
   Thread := NIL;
END CResult;

(*================================================================================*)

CLASS CThread( msgqueuethread.MsgQueueThread );
   VAR
      Browser : browser.CBrowser;  
      Result : CResult;
   INTERNAL VIRTUAL PROCEDURE OnStart();
   INTERNAL VIRTUAL PROCEDURE OnExit();
END CThread;

(*--------------------------------------------------------------------------------*)

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
   i : INTEGER;
   Thread : CThread;
BEGIN
   netinit.Startup();
   R.LoadRES2( EMIT( %exe ), L"discover.Texts" );

   i := 1;
   WHILE i < argc DO
      IF ( argp^[i]^[0] = L'/' ) OR ( argp^[i]^[0] = L'-' ) THEN // option
         CASE argp^[i]^[1] OF
         | 'h' :
            GOTO Error;
         | 'u' : // update cfg file
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

   errout^.WriteOA( L"  ", FALSE );
   Thread.Run( FALSE );
   WHILE Thread.WaitStop( 250 ) = Sync.arTimeout DO
      errout^.WriteOA( L".", FALSE );
   END; // WHILE

   netinit.Cleanup();
   RETURN 0;

Error:
   errout^.WriteOA( OAsz( R[Texts._UsageInfo] ), TRUE );

Stop:
   netinit.Cleanup();
   RETURN -1;
END wmain;
  
(*================================================================================*)

END discover.