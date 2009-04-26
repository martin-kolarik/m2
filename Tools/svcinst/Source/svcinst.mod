MODULE svcinst;

FROM Storage IMPORT
  ALLOCATE;

IMPORT
   ServiceControl,
   Strings,
   TextWriter;

TYPE
  TParamStringArray  = ARRAY [0..0] OF POINTER TO ARRAY [0..511] OF WCHAR;
  TPParamStringArray = POINTER TO TParamStringArray;

# save, call( convention => cdecl )
PROCEDURE wmain( argc : INTEGER; argp : TPParamStringArray; enpv : TPParamStringArray ) : INTEGER;
# restore
LABEL
   Error;
CONST
   defaultDependency = L"lanmanworkstation";
TYPE
   TActionItem = ( acCreate, acRun, acStop, acDelete );
   TAction = SET OF TActionItem;
VAR
   Action : TAction := TAction{};
   eo : TextWriter.TPTextWriter := TextWriter.errout();
   Message : ARRAY [0..255] OF WCHAR;
   Dependency : ARRAY [0..31] OF WCHAR;
   DisplayName, Name : ARRAY [0..255] OF WCHAR := 0W;
   Description, Path : ARRAY [0..511] OF WCHAR := 0W;
   Result : CARDINAL := 0;
BEGIN
   eo^.WriteOA( L'Service instal and control tool', TRUE );
   eo^.WriteOA( L"(c) ", FALSE ); eo^.WriteOA( Manufacturer, FALSE ); eo^.WriteOA( L" 2009", TRUE );
   eo^.LineEnd();

   IF argc < 3 THEN
      eo^.WriteOA( L'  missing parameters', TRUE );
      RETURN 100;
   ELSIF argc > 6 THEN
      eo^.WriteOA( L'  too many parameters', TRUE );
      RETURN 101;
   END;

   IF ( argp^[1]^[0] = L'/' ) OR ( argp^[1]^[0] = L'-' ) THEN
      CASE argp^[1]^[1] OF
      | L'c' :
         IF acDelete IN Action THEN
            eo^.WriteOA( '  error: -c option cannot be used together with -d option', TRUE );
            RETURN 200;
         END;
         INCL( Action, acCreate );
      | L'd' :
         IF TAction{acCreate, acRun} * Action <> TAction{} THEN
            eo^.WriteOA( '  error: -d option cannot be used together with -[cr] options', TRUE );
            RETURN 201;
         END;
         INCL( Action, acDelete );
      | L'h', L'?' :
         Result := 103;
         GOTO Error;
      | L'r' :
         IF acDelete IN Action THEN
            eo^.WriteOA( '  error: -r option cannot be used together with -d option', TRUE );
            RETURN 202;
         END;
         INCL( Action, acRun );
      | L's' :
         INCL( Action, acStop );
      ELSE
         eo^.WriteOA( '  error: unknown option: ', FALSE ); eo^.WriteOA( OAsz( argp^[1] ), TRUE );
         Result := 203;
         GOTO Error;
      END;
   ELSE
      eo^.WriteOA( '  error: unknown option: ', FALSE ); eo^.WriteOA( OAsz( argp^[1] ), TRUE );
      Result := 203;
      GOTO Error;
   END;

   // service name
   ASSIGN( Name, argp^[2]^ );

   // path to exe file
   IF acCreate IN Action THEN
      IF argc < 4 THEN
         eo^.WriteOA( '  error: missing path to service EXE', TRUE );
         RETURN 102;
      END;
      ASSIGN( Path, argp^[3]^ );
      IF argc > 4 THEN
         ASSIGN( DisplayName, argp^[4]^ );
      END;
      IF argc > 5 THEN
         ASSIGN( Description, argp^[5]^ );
      END;
   END;

   IF acStop IN Action THEN    
      ServiceControl.Stop( Name, TRUE, 10000, OUT Result );
      Strings.FromErrorW( Result, OUT Message );
      eo^.WriteOA( '  STOP   result: ', FALSE ); eo^.WriteOA( Message, TRUE );
   END;
   IF acDelete IN Action THEN
      ServiceControl.Delete( Name, OUT Result );
      Strings.FromErrorW( Result, OUT Message );
      eo^.WriteOA( '  DELETE result: ', FALSE ); eo^.WriteOA( Message, TRUE );
   END;
   IF acCreate IN Action THEN
      Dependency := defaultDependency; 
      Dependency[HIGH(defaultDependency)+1] := 0W;
      Dependency[HIGH(defaultDependency)+2] := 0W;

      ServiceControl.Create( Name, DisplayName, Path, Dependency, Description, OUT Result );
      Strings.FromErrorW( Result, OUT Message );
      eo^.WriteOA( '  CREATE result: ', FALSE ); eo^.WriteOA( Message, TRUE );
   END;
   IF acRun IN Action THEN
      ServiceControl.Start( Name, L"", TRUE, 10000, OUT Result );
      Strings.FromErrorW( Result, OUT Message );
      eo^.WriteOA( '  RUN    result: ', FALSE ); eo^.WriteOA( Message, TRUE );
   END;

   RETURN 0;

Error:
   eo^.LineEnd();
   eo^.WriteOA( '  Usage: svcinst [-cdhrs] service_name <exepath> <displayname> <description>', TRUE );
   eo^.WriteOA( '    -c  creates service', TRUE );
   eo^.WriteOA( '    -d  deletes service', TRUE );
   eo^.WriteOA( '    -h  shows this help', TRUE );
   eo^.WriteOA( '    -r  starts service', TRUE );
   eo^.WriteOA( '    -s  stops service', TRUE );

   RETURN Result;
END wmain;
  
END svcinst.

