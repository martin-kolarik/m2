MODULE Program;

(*===========================================================================*)

FROM Storage IMPORT
  ALLOCATE;

IMPORT
 windows,
 winnls;

IMPORT
  FIO,
  Strings;

IMPORT
  Console,
  DOM,
  Project,
  Types;

(*===========================================================================*)

TYPE
  TParamString       = ARRAY[0..511] OF WCHAR;
  TPParamString      = POINTER TO TParamString;
  TParamStringArray  = ARRAY [0..0] OF TPParamString;
  TPParamStringArray = POINTER TO TParamStringArray;

(*# save, call( convention=>cdecl ) *)
PROCEDURE wmain( argc : INTEGER; argp : TPParamStringArray; enpv : TPParamStringArray ); FORWARD;
(*# restore *)

(*===========================================================================*)

PROCEDURE wmain( argc : INTEGER; argp : TPParamStringArray; enpv : TPParamStringArray );

(*----------*)

  PROCEDURE TrimQuotes( VAR Path : ARRAY OF WCHAR );
  VAR
    c : CARDINAL;
  BEGIN
    IF Path[0] = L'"' THEN
      Strings.RemoveW( REF Path, 0, 1 );
    END;
    c := LENGTH( Path ) - 1;
    IF Path[c] = L'"' THEN
      Path[c] := WCHAR( 0 );
    END;
  END TrimQuotes;

(*----------*)

LABEL
  Error, Finish;
VAR
  c : CARDINAL;
  ErrorLevel : CARDINAL;
  i, j : CARDINAL;
  Parameter : ARRAY [0..511] OF WCHAR;
  TotalErrorCount : CARDINAL;
  Value : ARRAY [0..31] OF WCHAR;
  GenerateAll : BOOLEAN;
  GenerateSymbolTable : BOOLEAN;
  IgnoreBadOptions : BOOLEAN;
BEGIN
  ErrorLevel := 0;
  GenerateAll := FALSE;
  GenerateSymbolTable := FALSE;
  IgnoreBadOptions := FALSE;

  IF argc <= 1 THEN
    GOTO Error;
  END;

  FOR i := 1 TO argc - 1 DO
    IF ( argp^[i]^[0] = L'/' ) OR ( argp^[i]^[0] = L'-' ) THEN
      CASE argp^[i]^[1] OF
      | L'B' : // ignores bad options
        IgnoreBadOptions := TRUE;
      | L'C' : // how to convert TCHARs
        CASE argp^[i]^[2] OF
        | L'B' : Project.RemoveOption( DOM.eoWCHAR );
        | L'W' : Project.AddOption( DOM.eoWCHAR );
        END;
      | L'D' : // define
        Strings.SubstringW( argp^[i]^, 2, MAX( CARDINAL ), OUT Parameter );
        j := Strings.LastIndexOfW( Parameter, L':', 0 );
        IF j = MAX( CARDINAL ) THEN
          Value := L'';
        ELSE
          Strings.SubstringW( Parameter, j + 1, MAX( CARDINAL ), OUT Value );
          Parameter[j] := WCHAR( 0 );
        END;
        Project.CmdLineSymbol( Parameter, Value );
      | L'G' : // generate all includes
        GenerateAll := TRUE;
      | L'I' : // include (DEF) directory
        Strings.SubstringW( argp^[i]^, 2, MAX( CARDINAL ), OUT Parameter );
        Strings.TrimW( REF Parameter );
        IF Parameter[0] = L'"' THEN
          Strings.RemoveW( REF Parameter, 0, 1 );
          c := LENGTH( Parameter )-1;
          IF Parameter[c] = L'"' THEN
            Parameter[c] := WCHAR( 0C );
          END;
        END;
        Project.AddInputPath( Parameter );
      | L'L' : // libraries
        CASE argp^[i]^[2] OF
        | L'D' : Project.AddOption( DOM.eoPublishExports );
                 Project.CmdLineSymbol( L"DLL_EXPORT", L"" );
        | L'N' : Strings.SubstringW( argp^[i]^, 3, MAX( CARDINAL ), OUT Parameter );
                 Project.AddComponentName( Parameter );
        END;
      | L'N' : // names
        GenerateSymbolTable := TRUE;
      | L'O' : // output directory
        Strings.SubstringW( argp^[i]^, 2, MAX( CARDINAL ), OUT Parameter );
        Project.AddOutputPath( Project.opAll, Parameter );
      | L'o' : // output directory specified for different groups
        Strings.SubstringW( argp^[i]^, 3, MAX( CARDINAL ), OUT Parameter );
        CASE argp^[i]^[2] OF
        | L'H' : Project.AddOutputPath( Project.opHeader, Parameter );
        | L'C' : Project.AddOutputPath( Project.opCPP, Parameter );
        | L'T' : Project.AddOutputPath( Project.opTimestamp, Parameter );
        | L'd' : Project.AddOutputPath( Project.opTimestampDEF, Parameter );
        | L'i' : Project.AddOutputPath( Project.opTimestampIMPL, Parameter );
        END; // CASE
      | L'S' : // compatibility issues, switches
        CASE argp^[i]^[2] OF
        | L'A' :
          CASE argp^[i]^[3] OF
          | L'X' : Project.SetDefaultAccessMode( DOM.amPrivate );
          | L'I' : Project.SetDefaultAccessMode( DOM.amInternal );
          | L'P' : Project.SetDefaultAccessMode( DOM.amPublic );
          END;      
        | L'C' : Project.AddOption( DOM.eoCOMExtensionAllowed );
        | L'D' : Project.AddOption( DOM.eoDebuggedAllowed );
        | L'I' : Project.AddOption( DOM.eoISOClassImplementation );
        | L'M' : Project.AddOption( DOM.eoLeakChecking );
        | L'R' : Project.AddOption( DOM.eoRegion );
        | L'S' : Project.AddOption( DOM.eoAssertAllowed );
        END;
      | L'T' : // solve timestamps
        Project.AddOption( DOM.coSolveTimestamps );
      | L'Q' : // quiet
        CASE argp^[i]^[2] OF
        | L'A' : Console.SetQuiet( Console.quietAll );
        | L'I' : Console.SetQuiet( Console.quietInfo );
        END;
      | L'W' : // suppress warnings
        IF ( i+1 < CARDINAL( argc )) AND Strings.ToCARD32W( OAsz( argp^[i+1] ), 10, OUT c ) THEN
          Project.SuppressWarning( c );
        ELSE
          Console.WriteString( L'-- missing or bad warning number' ); Console.WriteEOL();
        END;
      ELSE
        IF NOT IgnoreBadOptions THEN
          Console.WriteString( L'-- unknown option: ' ); Console.WriteString( argp^[i]^ ); Console.WriteEOL();
          ErrorLevel := 2;
          GOTO Error;
        END;
      END;
    ELSE // path
      ASSIGN( Parameter, argp^[i]^ );
      TrimQuotes( Parameter );
      Project.AddFileToCompile( Parameter );
    END;
  END; // FOR

  TotalErrorCount := Project.Compile();
  IF TotalErrorCount = 1 THEN
    ErrorLevel := 1;
    Console.WriteLineS( L"-- 1 error detected", L'' );
  ELSIF TotalErrorCount = 0 THEN
    Console.WriteLineS( L"-- 0 errors detected", L'' );
  ELSE
    ErrorLevel := 1;
    Strings.FromCARD32W( TotalErrorCount, 10, OUT Value );
    Console.WriteLineS( L"-- {0} errors detected", Value );
  END;
  Project.Generate( GenerateAll );
  IF GenerateSymbolTable THEN
    Project.GenerateSymbolTable( L"symboltable.txt" );
  END;

  GOTO Finish;

Error:
  Console.WriteEOL();
  Console.WriteString( L'Usage: m2cpp <input file> [<input file>] [-D]' ); Console.WriteEOL();
  Console.WriteString( L'  -D<symbol>[:(on|off)] defines symbol' ); Console.WriteEOL();
  Console.WriteEOL();

Finish:
  windows.ExitProcess( ErrorLevel );
END wmain;

(*===========================================================================*)

BEGIN
END Program.