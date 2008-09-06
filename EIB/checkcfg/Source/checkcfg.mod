MODULE checkcfg;

(*================================================================================*)

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   winsock,
   FSO,
   lists,
   Resources,
   scinit,
   srvcore,
   Strings,
   StringsO,
   Texts,
   TextWriter;
   
(*================================================================================*)

TYPE
   TParamStringArray  = ARRAY [0..0] OF POINTER TO ARRAY [0..511] OF WCHAR;
   TPParamStringArray = POINTER TO TParamStringArray;
  
# save, call( convention => cdecl )
PROCEDURE wmain( argc : INTEGER; argp : TPParamStringArray; enpv : TPParamStringArray ) : INTEGER;
# restore
LABEL
   Error;
VAR
   Args : lists.CStringList;
   DI : FSO.CDirectoryInfo;
   errout : TextWriter.TPTextWriter := TextWriter.errout();
   EIB : srvcore.CEIBServer;
   ErrorText : StringsO.CString;
   i : INTEGER;
   Line : CARDINAL;
   R : Resources.CResources;
   stdout : TextWriter.TPTextWriter := TextWriter.stdout();
BEGIN
   EIB.EXEFlag := TRUE;
   R.LoadRES2( EMIT( %exe ), L"checkcfg.Texts" );

   i := 1;
   WHILE i < argc DO
      IF ( argp^[i]^[0] = L'/' ) OR ( argp^[i]^[0] = L'-' ) THEN // option
         CASE argp^[i]^[1] OF
         | 'h' :
           GOTO Error;
         ELSE
            errout^.WriteOA( OAsz( R[Texts._InvalidOption] ), FALSE ); errout^.WriteOA( argp^[i]^, TRUE );
            GOTO Error;
         END;
      ELSE // file/mask/dir
         Args.AddOA( argp^[i]^, 0 );
      END;
      INC( i );
   END; // WHILE

   Args.Reset();
   WHILE Args.MoveNext() DO
      IF DI.StartFromPathOA( OA( Args.Current^.Length-1, Args.Current^.rawData ), FSO.soTopDirectoryOnly, FALSE, TRUE ) THEN
         REPEAT
            stdout^.WriteOA( L"  ", FALSE ); stdout^.Write( DI.Path, FALSE ); stdout^.WriteOA( 9W, FALSE );

            EIB.Dispose();
            ErrorText.Clear();
            IF EIB.LoadConfiguration( DI.Path, OUT ErrorText, OUT Line ) THEN
               stdout^.WriteOA( OAsz( R[Texts._Success] ), FALSE ); stdout^.WriteOA( 9W, FALSE ); stdout^.WriteINT32( EIB.Objects.Count, 10, FALSE ); stdout^.WriteOA( OAsz( R[Texts._Objects] ), TRUE );
            ELSE
               stdout^.WriteOA( OAsz( R[Texts._Failed] ), TRUE );
               stdout^.WriteOA( OAsz( R[Texts._Line] ), FALSE ); stdout^.WriteINT32( Line, 10, FALSE ); stdout^.WriteOA( L": ", FALSE );
               stdout^.Write( ErrorText, TRUE );
            END;

         UNTIL NOT DI.MoveNext();
      END; // IF DI
   END; // WHILE
   EIB.Dispose();

   RETURN 0;

Error:
   errout^.WriteOA( OAsz( R[Texts._UsageInfo] ), TRUE );

   RETURN -1;
END wmain;
  
(*================================================================================*)

BEGIN
   scinit.Startup();
FINALLY
   scinit.Cleanup();
END checkcfg.