IMPLEMENTATION MODULE Project;

(*# call( o_a_copy => off ) *)

FROM Storage IMPORT
  ALLOCATE;

FROM Strings IMPORT
  LowerizeW, CapitalizeW;

IMPORT
  winerror;

IMPORT
  FIO,
  lists,
  Storage,
  Strings;

IMPORT
  err,
  Console,
  DOM,
  Generator,
  Types;

//============================================================

CLASS CProject;
  GEnv       : DOM.TEnvironment;
  GMEnv      : DOM.CModuleEnvironment;
  Component  : ARRAY [0..63] OF WCHAR;

  TEC        : CARDINAL; // total error count
  CurrentM   : DOM.TPModule; // compiled module

  CmdLine    : DOM.CSymbols;
  Units      : DOM.CSymbols;
  Inputs     : lists.CStringList;
  OutputPath : ARRAY TOutputPath OF FIO.PathStrW;

  PROCEDURE EnterSymbols( c : DOM.TPModule );
  PROCEDURE LeaveSymbols( c : DOM.TPModule );

  PROCEDURE AddOption( Option : DOM.TEnvironmentOptionsItem );
  PROCEDURE RemoveOption( Option : DOM.TEnvironmentOptionsItem );
  PROCEDURE SetDefaultAccessMode( AccessMode : DOM.TAccessModifier );
  PROCEDURE SuppressWarning( Warning : CARDINAL );

  PROCEDURE AddFileToCompile( FilePath : ARRAY OF WCHAR ) : DOM.TPModule;
  PROCEDURE ImportModule( CallerCU : DOM.TPModule; CONST Name : StringsO.CString; CompileImmediatelly : BOOLEAN ) : DOM.TPModule;
  PROCEDURE AssignFoundCompiledModuleName( CallerCU : DOM.TPModule; CONST Name : StringsO.CString );

  PROCEDURE ExpandPath( VAR FilePath : ARRAY OF WCHAR ) : CARDINAL;
  PROCEDURE AddInputPath( Path : ARRAY OF WCHAR );
  PROCEDURE AddOutputPath( WhatOutput : TOutputPath; Path : ARRAY OF WCHAR );
  PROCEDURE AddComponentName( Name : ARRAY OF WCHAR );
  PROCEDURE CmdLineSymbol( Name, Value : ARRAY OF WCHAR );
  PROCEDURE Compile() : CARDINAL;
  PROCEDURE SemErr( n : CARDINAL );

  PROCEDURE Generate( GenerateAll : BOOLEAN );
  PROCEDURE Current() : DOM.TPModule;
  PROCEDURE GetComponentName( VAR Name : ARRAY OF WCHAR; OutputCPPSymbol : BOOLEAN ) : BOOLEAN;
END CProject;

//------------------------------------------------------------

CLASS IMPLEMENTATION CProject;

  PROCEDURE EnterSymbols( c : DOM.TPModule );
  BEGIN
    c^.EnterSymbols( CmdLine, FALSE, FALSE, NIL );
    c^.EnterSymbols( Units, FALSE, FALSE, NIL );
  END EnterSymbols;

  PROCEDURE LeaveSymbols( c : DOM.TPModule );
  BEGIN
    c^.LeaveSymbols( FALSE );
    c^.LeaveSymbols( FALSE );
  END LeaveSymbols;

  PROCEDURE AddOption( Option : DOM.TEnvironmentOptionsItem );
  BEGIN
    INCL( GEnv.Options, Option );
    IF Option = DOM.eoLeakChecking THEN
      CmdLineSymbol( L"LEAKCHECK", L"" );
    END;
  END AddOption;
  
  PROCEDURE SetDefaultAccessMode( AccessMode : DOM.TAccessModifier );
  BEGIN
    GMEnv.ClassAM := AccessMode;
  END SetDefaultAccessMode;

  PROCEDURE SuppressWarning( Warning : CARDINAL );
  BEGIN
  END SuppressWarning;

  PROCEDURE RemoveOption( Option : DOM.TEnvironmentOptionsItem );
  BEGIN
    EXCL( GEnv.Options, Option );
  END RemoveOption;

  PROCEDURE AddFileToCompile( FilePath : ARRAY OF WCHAR ) : DOM.TPModule;
  VAR
    c : DOM.TPModule;
    ext : ARRAY [0..7] OF WCHAR;
    i : CARDINAL;
    s : ARRAY [0..511] OF WCHAR;
  BEGIN
    NEW( c );
    c^.Emit := TRUE;

    i := Strings.LastIndexOfCharW( FilePath, L'\', 0 );
    IF i = MAX( CARDINAL ) THEN
      ASSIGN( s, FilePath );
    ELSE
      Strings.SubstringW( FilePath, i + 1, MAX( CARDINAL ), OUT s );
    END;
    ext[0] := WCHAR( 0 );
    i := Strings.LastIndexOfCharW( s, L'.', 0 );
    IF i <> MAX( CARDINAL ) THEN
      Strings.SubstringW( s, i + 1, MAX( CARDINAL ), OUT ext );
      ext[3] := WCHAR( 0 );
      LOW( ext );
      s[i] := WCHAR( 0C );
    END;
    c^.N.FromOA( s );
    c^.Name.FromOA( s );
    c^.FilePath.FromOA( FilePath );
    IF EQUALS( ext, L'mod' ) THEN
      c^.OI := c;
      c^.N.PrependOA( L'i:' );
    ELSE
    END;
    c^.OD := c;
    c^.CU := c;

    IF Units.Knows( c ) THEN
      // Console.WriteLineS( L"Module name redefined -- {0}", s );
      c^.DoneAndFree();
      RETURN NIL;
    ELSE
      Units.Add( c );
      RETURN c;
    END;
  END AddFileToCompile;

  PROCEDURE ImportModule( CallerCU : DOM.TPModule; CONST Name : StringsO.CString; CompileImmediatelly : BOOLEAN ) : DOM.TPModule;
  VAR
    LModule : DOM.TPModule;
    n1, n2 : ARRAY [0..63] OF WCHAR;
    PreviousCC : DOM.TPModule;
    FileNotFound : BOOLEAN := FALSE;
  BEGIN
    IF NOT Units.GetCI( Name, LModule ) THEN
      NEW( LModule );
      LModule^.N.Assign( Name );
      LModule^.Name.Assign( Name );
      LModule^.FilePath.Assign( Name ); LModule^.FilePath.AppendOA( L'.def' );
      LModule^.CU := LModule;
      LModule^.OD := LModule;
      Units.Add( LModule );
    END;
    IF ( CallerCU <> LModule ) AND ( LModule^.CompileState = DOM.csPending ) THEN
      ASSIGN( n1, OA( CallerCU^.Name.Length, CallerCU^.Name.szData ));
      ASSIGN( n2, OA( LModule^.Name.Length, LModule^.Name.szData ));
      CallerCU^.M2^.SemErrForcedSNS( err._CircularImport, n1, err._CircularImportIsCompiled, n2 );
    ELSIF CompileImmediatelly AND ( LModule^.CompileState = DOM.csUnknown ) THEN
      PreviousCC := CurrentM;
      CurrentM := LModule;

      Console.WriteLineCS( L"  {0}.def", CurrentM^.Name );

      CurrentM^.Options := GEnv.Options;
      CurrentM^.CurE^ := GEnv;
      CurrentM^.MEnv := GMEnv;
      INC( TEC, CurrentM^.Compile());
      FileNotFound := DOM.coFileNotFound IN CurrentM^.Options;

      CurrentM := PreviousCC;
    END;
    IF DOM.coSolveTimestamps IN GEnv.Options THEN
      // pass out
    ELSIF LModule^.CompileState <> DOM.csUnknown THEN
      IF FileNotFound THEN
        CallerCU^.SemErrCS( err._FileNotFound, Name );
      ELSIF LModule^.UnitKind <> DOM.ukDefinition THEN
        CallerCU^.SemErr( err._ModuleIsNotDEF );
      END;
    END;
    RETURN LModule;
  END ImportModule;

  PROCEDURE AssignFoundCompiledModuleName( CallerCU : DOM.TPModule; CONST Name : StringsO.CString );
  BEGIN
    IF CallerCU^.UnitKind <> DOM.ukImplementation THEN
      Units.Forget( CallerCU );
      CallerCU^.N.Assign( Name );
      IF Units.Knows( CallerCU ) THEN
        CallerCU^.SemErr( err._DEFAlreadyKnown );
      ELSE
        Units.Add( CallerCU );
      END;
    END;
    CallerCU^.Name.Assign( Name );
  END AssignFoundCompiledModuleName;

  PROCEDURE ExpandPath( VAR FilePath : ARRAY OF WCHAR ) : CARDINAL;
  VAR
    LP : FIO.PathStrW;
  BEGIN
    IF FIO.ExistsW( FilePath ) THEN
      RETURN 0;
    END;
    Inputs.Reset();
    WHILE Inputs.MoveNext() DO
      Inputs.Current^.ToOA( OUT LP );
      Strings.AppendW( REF LP, FilePath );
      IF FIO.ExistsW( LP ) THEN
        ASSIGN( FilePath, LP );
        RETURN 0;
      END;
    END; // WHILE
    RETURN winerror.ERROR_FILE_NOT_FOUND;
  END ExpandPath;

  PROCEDURE AddInputPath( Path : ARRAY OF WCHAR );
  VAR
    c : CARDINAL;
    LP : FIO.PathStrW;
  BEGIN
    ASSIGN( LP, Path );
    c := LENGTH( LP );
    IF ( LP[c-1] <> L'/' ) AND ( LP[c-1] <> L'\' ) THEN
      Strings.AppendW( REF LP, L'\' );
    END;
    Inputs.AddOA( LP, 0 );
  END AddInputPath;

  PROCEDURE AddOutputPath( WhatOutput : TOutputPath; Path : ARRAY OF WCHAR );
  VAR
    c : CARDINAL;
  BEGIN
    ASSIGN( OutputPath[WhatOutput], Path );
    c := LENGTH( OutputPath[WhatOutput] );
    IF ( OutputPath[WhatOutput][c-1] <> L'/' ) AND ( OutputPath[WhatOutput][c-1] <> L"\" ) THEN
      Strings.AppendW( REF OutputPath[WhatOutput], L'\' );
    END;
  END AddOutputPath;

  PROCEDURE AddComponentName( Name : ARRAY OF WCHAR );
  BEGIN
    ASSIGN( Component, Name );
    LOW( Component );
    CmdLineSymbol( Component, L"" );
    CmdLineSymbol( "LIBRARY", Component );
  END AddComponentName;

  PROCEDURE CmdLineSymbol( Name, Value : ARRAY OF WCHAR );
  VAR
    Constant : DOM.TPConstant;
    LValue : ARRAY [0..31] OF WCHAR;
  BEGIN
    NEW( Constant );
    ASSIGN( LValue, Value );
    CAP( LValue );
    IF EQUALS( LValue, L"" ) THEN
      Constant^.Init2( Types.TBOOLEAN, L'TRUE' );
    ELSIF EQUALS( LValue, L'ON' ) THEN
      Constant^.Init2( Types.TBOOLEAN, L'TRUE' );
    ELSIF EQUALS( LValue, L'OFF' ) THEN
      Constant^.Init2( Types.TBOOLEAN, L'FALSE' );
    ELSE
      Constant^.Init2( Types.TWString, Value );
    END;
    Constant^.N.FromOA( Name );
    Constant^.UnitKind := DOM.ukCmdLineConstDecl;
    CmdLine.Add( Constant );
  END CmdLineSymbol;

  PROCEDURE Compile() : CARDINAL;
  BEGIN
    IF OutputPath[opHeader][0] = WCHAR( 0 ) THEN
      ASSIGN( OutputPath[opHeader], OutputPath[opAll] );
    END;
    IF OutputPath[opCPP][0] = WCHAR( 0 ) THEN
      ASSIGN( OutputPath[opCPP], OutputPath[opAll] );
    END;
    IF OutputPath[opTimestamp][0] = WCHAR( 0 ) THEN
      ASSIGN( OutputPath[opTimestamp], OutputPath[opAll] );
    END;
  
    TEC := 0;
    Units.Reset();
    WHILE Units.MoveNext() DO
      CurrentM := DOM.TPModule( Units.Current );
      IF CurrentM^.CompileState = DOM.csUnknown THEN
        Console.WriteStringCS( L"{0}", CurrentM^.Name );
        IF CurrentM^.OI = CurrentM THEN
          Console.WriteString( L".mod" );
        ELSE
          Console.WriteString( L".def" );
        END;
        Console.WriteEOL();

        CurrentM^.Options := GEnv.Options;
        CurrentM^.CurE^ := GEnv;
        CurrentM^.MEnv := GMEnv;
        INC( TEC, CurrentM^.Compile());
        IF DOM.coFileNotFound IN CurrentM^.Options THEN
          IF CurrentM^.OI = CurrentM THEN
            CurrentM^.M2^.SemErrForcedCS( err._MODFileNotFound, CurrentM^.Name );
          ELSE
            CurrentM^.M2^.SemErrForcedCS( err._DEFFileNotFound, CurrentM^.Name );
          END;
        END;

        Units.Reset();
      END;
    END; // WHILE
    
    Units.Reset();
    WHILE Units.MoveNext() DO
      DOM.TPModule( Units.Current )^.CheckSemantics( TRUE ); // check only DEFinitions module without MOD module
    END; // WHILE
    
    RETURN TEC;
  END Compile;

  PROCEDURE SemErr( n : CARDINAL );
  BEGIN
    CurrentM^.SemErr( n );
  END SemErr;

  PROCEDURE Generate( GenerateAll : BOOLEAN );
  VAR
    DF : FIO.File;
    MF : FIO.File;
    Path : FIO.PathStrW;
    PathA : ARRAY [0..511] OF CHAR;
    HeadEmitted : BOOLEAN := FALSE;
  BEGIN
    Console.WriteEOL();

    IF ( DOM.coSolveTimestamps IN GEnv.Options ) AND ( OutputPath[opTimestamp][0] <> WCHAR( 0 )) THEN
      IF OutputPath[opTimestampDEF][0] = WCHAR( 0 ) THEN
        Strings.ConcatW( OUT Path, OutputPath[opTimestamp], L'OutOfDate.DEF.log' );
      ELSE
        Strings.ConcatW( OUT Path, OutputPath[opTimestamp], OutputPath[opTimestampDEF] );
      END;
      DF := FIO.CreateW( Path, FIO.TFileShare{} );
      IF OutputPath[opTimestampIMPL][0] = WCHAR( 0 ) THEN
        Strings.ConcatW( OUT Path, OutputPath[opTimestamp], L'OutOfDate.MOD.log' );
      ELSE
        Strings.ConcatW( OUT Path, OutputPath[opTimestamp], OutputPath[opTimestampIMPL] );
      END;
      MF := FIO.CreateW( Path, FIO.TFileShare{} );
    END;

    Units.Reset();
    WHILE Units.MoveNext() DO
      CurrentM := DOM.TPModule( Units.Current );
      IF CurrentM^.MEnv.Header AND ( CurrentM^.Emit OR GenerateAll ) AND ( CurrentM^.CompileState = DOM.csCompiled ) THEN
        IF NOT( DOM.coSolveTimestamps IN GEnv.Options ) THEN
          IF HeadEmitted THEN
            Console.WriteString( L", " );
          ELSE
            HeadEmitted := TRUE;
            Console.WriteString( L"Generating code: " );
          END;
          IF CurrentM^.UnitKind = DOM.ukDefinition THEN
            Console.WriteStringCS( L"{0}.def", CurrentM^.Name );
            Generator.Generate( OutputPath[opHeader], Generator.genCPP, Generator.TGenerateOptions{}, Current());
          ELSE
            Console.WriteStringCS( L"{0}.mod", CurrentM^.Name );
            Generator.Generate( OutputPath[opCPP], Generator.genCPP, Generator.TGenerateOptions{}, Current());
          END;
        ELSIF DOM.coDependsOnNewerDEF IN Current()^.Options THEN
          CurrentM^.FilePath.ToOA( OUT Path );
          Strings.ToA( Path, 0, OUT PathA );
          IF OutputPath[opTimestamp][0] = WCHAR( 0 ) THEN
            Console.WriteLineCS( L'"{0}" is older to some imported modules', CurrentM^.Name );
          ELSIF CurrentM^.UnitKind = DOM.ukDefinition THEN
            FIO.WrStrA( DF, PathA ); FIO.WrLnA( DF );
          ELSE
            FIO.WrStrA( MF, PathA ); FIO.WrLnA( MF );
          END;
        END;
      END;
    END; // WHILE
    IF HeadEmitted THEN
      Console.WriteEOL();
      Console.WriteEOL();
    END;

    IF ( DOM.coSolveTimestamps IN GEnv.Options ) AND ( OutputPath[opTimestamp][0] <> WCHAR( 0 )) THEN
      FIO.Flush( DF ); FIO.Close( DF );
      FIO.Flush( MF ); FIO.Close( MF );
    END;
  END Generate;
  
  PROCEDURE Current() : DOM.TPModule;
  BEGIN
    RETURN CurrentM;
  END Current;

  PROCEDURE GetComponentName( VAR Name : ARRAY OF WCHAR; OutputCPPSymbol : BOOLEAN ) : BOOLEAN;
  BEGIN
    IF EQUALS( Component, L"" ) THEN
      RETURN FALSE;
    ELSE
      ASSIGN( Name, Component );
    END;
    IF OutputCPPSymbol THEN
      Strings.AppendW( REF Name, L"_LN" );
    END;
    RETURN TRUE;
  END GetComponentName;

BEGIN
  TEC := 0;
  Storage.Fill( ADR( OutputPath ), SIZE( OutputPath ), 0 );
  WITH GEnv DO
    Packing := 8;
    Options := DOM.TEnvironmentOptions{DOM.coOASize, DOM.coResultOptional, DOM.coParamsInFrame, DOM.cpUndefined};
  END; // WITH
  Component := L"";
  CurrentM := NIL;
END CProject;

//============================================================

VAR
  Project : CProject;

PROCEDURE EnterSymbols( c : DOM.TPModule );
BEGIN
  Project.EnterSymbols( c );
END EnterSymbols;

PROCEDURE LeaveSymbols( c : DOM.TPModule );
BEGIN
  Project.LeaveSymbols( c );
END LeaveSymbols;

PROCEDURE GenerateSymbolTable( CONST File : ARRAY OF WCHAR );
VAR
  Buffer : Generator.CBuffer;
  Indent : CARDINAL;
  IndentBuffer : ARRAY [0..511] OF WCHAR;
  S : DOM.TPSymbol;
  SS : DOM.TPSymbols;
  T : DOM.TPType;
BEGIN
  FOR Indent := 0 TO HIGH( IndentBuffer ) DO
    IndentBuffer[Indent] := L" ";
  END; // FOR
  Indent := 0;

  Buffer.Create( File, FALSE );
  
  SS := ADR( Project.Units );
  SS^.Reset();
  LOOP
    WHILE SS^.MoveNext() DO
      S := SS^.Current;

      Buffer.WriteS( OA( Indent*2-1, ADR( IndentBuffer )));
      Buffer.WriteCS( S^.N );
      IF S^.T <> Types.TUnknown THEN
        T := S^.T^.Unwrap();

        Buffer.WriteS( L" : " );
        Buffer.WriteCS( T^.N );
      END;
      Buffer.WriteS( 13W + 10W );
         
      IF S^.Symbols <> NIL THEN
        SS := S^.Symbols;
        SS^.Reset();
        INC( Indent );
      END;
    END; // WHILE
    IF SS = ADR( Project.Units ) THEN
      EXIT;
    ELSIF SS^.OfSymbol^.OfSymbol = NIL THEN
      DEC( Indent );
      SS := ADR( Project.Units );
    ELSE
      DEC( Indent );
      SS := SS^.OfSymbol^.OfSymbol^.Symbols;
    END;
  END; // LOOP
  
  Buffer.Close();
END GenerateSymbolTable;

PROCEDURE AddOption( Option : DOM.TEnvironmentOptionsItem );
BEGIN
  Project.AddOption( Option );
END AddOption;

PROCEDURE RemoveOption( Option : DOM.TEnvironmentOptionsItem );
BEGIN
  Project.RemoveOption( Option );
END RemoveOption;

PROCEDURE SetDefaultAccessMode( AccessMode : DOM.TAccessModifier );
BEGIN
  Project.SetDefaultAccessMode( AccessMode );
END SetDefaultAccessMode;

PROCEDURE SuppressWarning( Warning : CARDINAL );
BEGIN
  Project.SuppressWarning( Warning );
END SuppressWarning;

PROCEDURE AddFileToCompile( FilePath : ARRAY OF WCHAR ) : DOM.TPModule;
BEGIN
  RETURN Project.AddFileToCompile( FilePath );
END AddFileToCompile;

PROCEDURE ImportModule( CallerCU : DOM.TPModule; CONST Name : StringsO.CString; CompileImmediatelly : BOOLEAN ) : DOM.TPModule;
BEGIN
  RETURN Project.ImportModule( CallerCU, Name, CompileImmediatelly );
END ImportModule;

PROCEDURE AssignFoundCompiledModuleName( CallerCU : DOM.TPModule; CONST Name : StringsO.CString );
BEGIN
  Project.AssignFoundCompiledModuleName( CallerCU, Name );
END AssignFoundCompiledModuleName;

PROCEDURE ExpandPath( VAR FilePath : ARRAY OF WCHAR ) : CARDINAL;
BEGIN
  RETURN Project.ExpandPath( FilePath );
END ExpandPath;

PROCEDURE AddInputPath( Path : ARRAY OF WCHAR );
BEGIN
  Project.AddInputPath( Path );
END AddInputPath;

PROCEDURE AddOutputPath( WhatOutput : TOutputPath; Path : ARRAY OF WCHAR );
BEGIN
  Project.AddOutputPath( WhatOutput, Path );
END AddOutputPath;

PROCEDURE AddComponentName( Name : ARRAY OF WCHAR );
BEGIN
  Project.AddComponentName( Name );
END AddComponentName;

PROCEDURE CmdLineSymbol( Name, Value : ARRAY OF WCHAR );
BEGIN
  Project.CmdLineSymbol( Name, Value );
END CmdLineSymbol;

PROCEDURE Compile() : CARDINAL;
BEGIN
  RETURN Project.Compile();
END Compile;

PROCEDURE SemErr( n : CARDINAL );
BEGIN
  Project.SemErr( n );
END SemErr;

PROCEDURE Generate( GenerateAll : BOOLEAN );
BEGIN
  Project.Generate( GenerateAll );
END Generate;

PROCEDURE Current() : DOM.TPModule;
BEGIN
  RETURN Project.Current();
END Current;

PROCEDURE GetComponentName( VAR Name : ARRAY OF WCHAR; OutputCPPSymbol : BOOLEAN ) : BOOLEAN;
BEGIN
  RETURN Project.GetComponentName( Name, OutputCPPSymbol );
END GetComponentName;

INITIALLY __I();
BEGIN
END __I;

END Project.