MODULE xrsc;

FROM Storage IMPORT
  ALLOCATE;

IMPORT
  com,
  FIO,
  lists,
  Resources,
  Strings,
  windows;

TYPE
  TParamString       = ARRAY[0..0] OF WCHAR;
  TPParamString      = POINTER TO TParamString;
  TParamStringArray  = ARRAY [0..0] OF TPParamString;
  TPParamStringArray = POINTER TO TParamStringArray;

  # save, call( convention => cdecl )
  PROCEDURE Main( argc : INTEGER; argp : TPParamStringArray ) : INTEGER;
  VAR
    DefIdPrefix : ARRAY [0..63] OF WCHAR := L'';
    ErrF : windows.HANDLE := windows.GetStdHandle( windows.STD_ERROR_HANDLE );
    ErrorFlag : BOOLEAN := FALSE;
    ErrorText : ARRAY [0..255] OF WCHAR;
    i : INTEGER;
    Input : FIO.PathStrW;
    Inputs : lists.CStringList;
    Line : ARRAY [0..511] OF WCHAR;
    LineA : ARRAY [0..511] OF CHAR;
    ModuleName : ARRAY [0..255] OF WCHAR;
    Output : FIO.PathStrW;
    OutputBin : BOOLEAN := FALSE;
    OutputDef : BOOLEAN := FALSE;
    OutputDirBin : FIO.PathStrW := L'';
    OutputDirDef : FIO.PathStrW := L'';
    OutputPrefix : FIO.PathStrW := L'';
    R : Resources.CResourcesCreator;
  BEGIN
    IF argc <= 1 THEN
      FIO.WrStrA( ErrF, C'Missing parameters' ); FIO.WrLnA( ErrF );
    END;

    FOR i := 1 TO argc - 1 DO
      IF ( argp^[i]^[0] = L'/' ) OR ( argp^[i]^[0] = L'-' ) THEN
        CASE argp^[i]^[1] OF
        | 'B' : OutputBin := TRUE;
        | 'D' : OutputDef := TRUE;
        | 'N' : // DEF identifier prefix
          ASSIGNsz( DefIdPrefix, ADR( argp^[i]^[2] ));
        | 'O' : // output directory
          ASSIGNsz( OutputDirBin, ADR( argp^[i]^[2] ));
          ASSIGNsz( OutputDirDef, ADR( argp^[i]^[2] ));
        | 'o' : // output directory differentiated by destination
          CASE argp^[i]^[2] OF
          | 'B' : ASSIGNsz( OutputDirBin, ADR( argp^[i]^[3] ));
          | 'D' : ASSIGNsz( OutputDirDef, ADR( argp^[i]^[3] ));
          END; // CASE
        | 'P' : // output prefix
          ASSIGNsz( OutputPrefix, ADR( argp^[i]^[2] ));
        END;
      ELSE
        Inputs.AddOA( OAsz( argp^[i] ), 0 );
      END;
    END; // FOR
    
    IF ( OutputDirBin[0] <> 0W ) AND ( OutputDirBin[ LENGTH( OutputDirBin ) - 1 ] <> L'\' ) THEN
      Strings.AppendW( REF OutputDirBin, L'\' );
    END;
    IF ( OutputDirDef[0] <> 0W ) AND ( OutputDirDef[ LENGTH( OutputDirDef ) - 1 ] <> L'\' ) THEN
      Strings.AppendW( REF OutputDirDef, L'\' );
    END;
    
    Inputs.Reset();
    WHILE Inputs.MoveNext() DO
      Inputs.Current^.ToOA( OUT Input );
      IF NOT R.LoadXML( Input, OUT ErrorText ) THEN
        Strings.ConcatW( OUT Line, Input, L'(1,1): error X:' );
        Strings.AppendW( REF Line, ErrorText );
        Strings.ToA( Line, 0, OUT LineA );
        FIO.WrStrA( ErrF, LineA ); FIO.WrLnA( ErrF );
        CONTINUE;
      END;

      IF OutputBin THEN
        FIO.PathTailW( Input, OUT Output );
        FIO.ChangeExtensionW( REF Output, L'brs' );
        Strings.PrependW( REF Output, OutputPrefix );
        Strings.PrependW( REF Output, OutputDirBin );

        R.SaveBIN( Output );
      END;
      IF OutputDef THEN
        FIO.PathTailW( Input, OUT Output );
        ASSIGN( ModuleName, Output );
        FIO.ChangeExtensionW( REF Output, L'def' );
        FIO.ChangeExtensionW( REF ModuleName, L'' );
        Strings.PrependW( REF Output, OutputDirDef );

        R.SaveDEF( ModuleName, Output, DefIdPrefix );
      END;
    END; // WHILE
    
    IF ErrorFlag THEN
      RETURN -1;
    ELSE
      RETURN 0;
    END;
  END Main;
  # restore
  
BEGIN
  com.COMInit();
FINALLY
  com.COMDone();
END xrsc.

