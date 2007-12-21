IMPLEMENTATION MODULE Generator;

(*# call( o_a_copy => off ) *)

FROM Storage IMPORT
  DEALLOCATE;

IMPORT
  Storage,
  Strings;

IMPORT
  Console,
  DOM;
  
//============================================================

CLASS IMPLEMENTATION CBuffer;

  PROCEDURE Create( Path : ARRAY OF WCHAR; UFlag : BOOLEAN ) : BOOLEAN;
  VAR
    ES : ARRAY [0..511] OF WCHAR;
    TM : ARRAY [0..511] OF WCHAR := L'';
  BEGIN
    Close();
    windows.SetLastError( 0 );
    HFile := windows.CreateFileW(
      windows.PCWSTR( ADR( Path )),
      windows.GENERIC_READ OR windows.GENERIC_WRITE,
      0,
      NIL,
      windows.CREATE_ALWAYS,
      windows.FILE_ATTRIBUTE_NORMAL OR windows.FILE_FLAG_OVERLAPPED,
      NIL );
    IF HFile = windows.INVALID_HANDLE_VALUE THEN
      Strings.ConcatW( OUT ES, L'Unable to create output file (', Path ); Strings.AppendW( REF ES, L'): {0}' );
      // vcom.GetErrorMessageW( windows.GetLastError(), TM );
      Console.WriteLineS( ES, TM );
      RETURN FALSE;
    ELSE
      RETURN TRUE;
    END;
  END Create;

  PROCEDURE Close();
  BEGIN
    IF HFile <> windows.INVALID_HANDLE_VALUE THEN
      Sync();
      Sync();
      windows.FlushFileBuffers( HFile );
      windows.CloseHandle( HFile );
      HFile := windows.INVALID_HANDLE_VALUE;
    END;
  END Close;

  PROCEDURE ResetWrap();
  BEGIN
    WrapStart := Data[CurrentData].Pos;
  END ResetWrap;

  PROCEDURE CheckWrap() : BOOLEAN;
  BEGIN
    IF Data[CurrentData].Pos > WrapStart + 256 THEN
      ResetWrap();
      RETURN TRUE;
    ELSE
      RETURN FALSE;
    END;
  END CheckWrap;

  PROCEDURE WriteB( A : ADDRESS; CharLen : CARDINAL );
  BEGIN
    IF CharLen = 0 THEN
      RETURN;
    ELSIF Data[CurrentData].Pos + CharLen > DataSize THEN
      Sync();
    END;
    WITH Data[CurrentData] DO
      Strings.MoveW( A, ADR( __X )@[Pos * SIZE( WCHAR )], CharLen );
      INC( Pos, CharLen );
    END; // WITH
  END WriteB;

  PROCEDURE WriteS( S : ARRAY OF WCHAR );
  BEGIN
    WriteB( ADR( S ), LENGTH( S ));
  END WriteS;

  PROCEDURE WriteCS( CONST S : StringsO.CString );
  BEGIN
    WriteB( S.rawData, S.Length );
  END WriteCS;

  PROCEDURE Sync();
  VAR
    Count : CARDINAL;
  BEGIN
    windows.GetOverlappedResult( HFile, ADR( Overlapped ), ADR( Count ), windows.True );
    INC( Overlapped.Offset, Count );
    Overlapped.OffsetHigh := 0;

    IF Data[CurrentData].Pos = 0 THEN
      RETURN;
    END;

    IF Unicode THEN
      windows.WriteFile( HFile, ADR( Data[CurrentData].__X ), Data[CurrentData].Pos * SIZE( WCHAR ), NIL, ADR( Overlapped ));
    ELSE
      Strings.ToA( OA( Data[CurrentData].Pos-1, ADR( Data[CurrentData].__X )), 0, OUT OA( Data[CurrentData].Pos-1, ADR( AData ) ));
      windows.WriteFile( HFile, ADR( AData ), Data[CurrentData].Pos, NIL, ADR( Overlapped ));
    END;

    CurrentData := ( CurrentData + 1 ) AND 1;
    Data[CurrentData].Pos := 0;
    ResetWrap();
  END Sync;

BEGIN
  HFile := windows.INVALID_HANDLE_VALUE;
  CurrentData := 0;
  Storage.Fill( ADR( Overlapped ), SIZE( windows.OVERLAPPED ), 0 );
  Unicode := FALSE;
  Overlapped.hEvent := windows.CreateEvent( NIL, windows.True, windows.True, NIL );
  WrapStart := 0;
  Storage.Fill( ADR( Data ), SIZE( Data ), 0 );
  Storage.Fill( ADR( AData ), SIZE( AData ), 0 );
END CBuffer;

//============================================================

CLASS IMPLEMENTATION CGenerator;

  PUBLIC PROCEDURE Init( IndentChar : WCHAR; IndentUnitLen : CARDINAL );
  VAR
    i : CARDINAL;
  BEGIN
    FOR i := 0 TO SIZE( IndentData ) DIV SIZE( WCHAR ) - 1 DO
      IndentData[i] := IndentChar;
    END;
    IndentCount := IndentUnitLen;
  END Init;

  PUBLIC PROCEDURE Mode() : TGenerate;
  BEGIN
    RETURN GenerateMode;
  END Mode;

  PUBLIC PROCEDURE Enter();
  BEGIN
    INC( IndentDepth );
  END Enter;

  PUBLIC PROCEDURE Leave();
  BEGIN
    DEC( IndentDepth );
  END Leave;

  PUBLIC PROCEDURE Indent();
  BEGIN
    Buffer.WriteB( ADR( IndentData ), IndentDepth * IndentCount );
  END Indent;

  PUBLIC PROCEDURE OutSP();
  CONST
    Space = L' ' + WCHAR( 0 );
  BEGIN
    Buffer.WriteB( ADR( Space ), 1 );
    IF Buffer.CheckWrap() THEN
      EOL(); Indent();
    END;
  END OutSP;

  PUBLIC PROCEDURE OutSC();
  CONST
    Semicolon = L';' + WCHAR( 0 );
  BEGIN
    Buffer.WriteB( ADR( Semicolon ), 1 );
  END OutSC;


  PUBLIC PROCEDURE OutLP();
  CONST
    LPar = L'(' + WCHAR( 0 );
  BEGIN
    Buffer.WriteB( ADR( LPar ), 1 );
  END OutLP;

  PUBLIC PROCEDURE OutLPSP();
  CONST
    LParSP = L'( ' + WCHAR( 0 );
  BEGIN
    Buffer.WriteB( ADR( LParSP ), 2 );
  END OutLPSP;

  PUBLIC PROCEDURE OutLPRPSCEOL();
  CONST
    LParRParSCEOL = L'();' + WCHAR( 13 ) + WCHAR( 10 ) + WCHAR( 0 );
  BEGIN
    Buffer.WriteB( ADR( LParRParSCEOL ), 5 );
    IF Buffer.CheckWrap() THEN
      EOL(); Indent();
    END;
  END OutLPRPSCEOL;

  PUBLIC PROCEDURE OutRP();
  CONST
    RPar = L')' + WCHAR( 0 );
  BEGIN
    Buffer.WriteB( ADR( RPar ), 1 );
  END OutRP;

  PUBLIC PROCEDURE OutSPRP();
  CONST
    SPRPar = L' )' + WCHAR( 0 );
  BEGIN
    Buffer.WriteB( ADR( SPRPar ), 2 );
  END OutSPRP;

  PUBLIC PROCEDURE OutSPRPSC();
  CONST
    SPRParSC = L' );' + WCHAR( 0 );
  BEGIN
    Buffer.WriteB( ADR( SPRParSC ), 3 );
  END OutSPRPSC;

  PUBLIC PROCEDURE OutLB();
  CONST
    LBracket = L'{' + WCHAR( 0 );
  BEGIN
    Buffer.WriteB( ADR( LBracket ), 1 );
  END OutLB;

  PUBLIC PROCEDURE OutRB();
  CONST
    RBracket = L'}' + WCHAR( 0 );
  BEGIN
    Buffer.WriteB( ADR( RBracket ), 1 );
    IF Buffer.CheckWrap() THEN
      EOL(); Indent();
    END;
  END OutRB;

  PUBLIC PROCEDURE OutAST();
  CONST
    Asterisk = L'*' + WCHAR( 0 );
  BEGIN
    Buffer.WriteB( ADR( Asterisk ), 1 );
  END OutAST;

  PUBLIC PROCEDURE OutCmSP();
  CONST
    CommaSP = L', ' + WCHAR( 0 );
  BEGIN
    Buffer.WriteB( ADR( CommaSP ), 2 );
    IF Buffer.CheckWrap() THEN
      EOL(); Indent();
    END;
  END OutCmSP;

  PUBLIC PROCEDURE OutCoSP();
  CONST
    ColonSP = L': ' + WCHAR( 0 );
  BEGIN
    Buffer.WriteB( ADR( ColonSP ), 2 );
  END OutCoSP;

  PUBLIC PROCEDURE OutN( N : CARDINAL );
  VAR
    SN : ARRAY [0..15] OF WCHAR;
  BEGIN
    Strings.FromCARD32W( N, 10, OUT SN );
    OutS( SN );
  END OutN;

  PUBLIC PROCEDURE OutNH( N : CARDINAL );
  VAR
    SN : ARRAY [0..15] OF WCHAR;
  BEGIN
    OutS( L'0x' );
    Strings.FromCARD32W( N, 16, OUT SN );
    OutS( SN );
  END OutNH;

  PUBLIC PROCEDURE OutNL( N : CARD64 );
  VAR
    SN : ARRAY [0..31] OF WCHAR;
  BEGIN
    Strings.FromCARD64W( N, 10, OUT SN );
    OutS( SN );
  END OutNL;

  PUBLIC PROCEDURE OutNLH( N : CARD64 );
  VAR
    SN : ARRAY [0..23] OF WCHAR;
  BEGIN
    OutS( L'0x' );
    Strings.FromCARD64W( N, 16, OUT SN );
    OutS( SN );
  END OutNLH;

  PUBLIC PROCEDURE OutNI( N : INTEGER );
  VAR
    SN : ARRAY [0..15] OF WCHAR;
  BEGIN
    Strings.FromINT32W( N, 10, OUT SN );
    OutS( SN );
  END OutNI;

  PUBLIC PROCEDURE OutNLI( N : INT64 );
  VAR
    SN : ARRAY [0..31] OF WCHAR;
  BEGIN
    Strings.FromINT64W( N, 10, OUT SN );
    OutS( SN );
  END OutNLI;

  PUBLIC PROCEDURE OutS( S : ARRAY OF WCHAR );
  BEGIN
    Buffer.WriteS( S );
  END OutS;

  PUBLIC PROCEDURE OutCS( CONST S : StringsO.CString );
  BEGIN
    Buffer.WriteCS( S );
  END OutCS;

  PUBLIC PROCEDURE OutANSIEscapeCS( SW : StringsO.CString; ByChars : BOOLEAN );
  TYPE
    TPC8 = POINTER TO CARD8;
  CONST
    bl = 1024;
    hn = L'0123456789ABCDEF'; 
  VAR
    A : ARRAY [0..bl-1] OF CHAR;
    I, i, L, l : CARDINAL;
    U : ARRAY [0..bl-1] OF WCHAR;
  BEGIN
    I := 0;
    L := SW.Length;

    LOOP
      l := MIN2( bl, L );
      SW.SubstringOA( I, l, OUT U ); Strings.ToA( U, 0, OUT A );
      i := 0;

      WHILE i < l DO
        IF ByChars THEN
          Buffer.WriteS( L"'" );
        END;
        CASE CARDINAL( A[i] ) OF
        | 7 : Buffer.WriteS( L'\a' );
        | 8 : Buffer.WriteS( L'\b' );
        | 9 : Buffer.WriteS( L'\t' );
        | 10 : Buffer.WriteS( L'\n' );
        | 11 : Buffer.WriteS( L'\v' );
        | 12 : Buffer.WriteS( L'\f' );
        | 13 : Buffer.WriteS( L'\r' );
        | 32..33 : Buffer.WriteB( ADR( U[i] ), 1 );
        | 34 : Buffer.WriteS( L'\"' );
        | 35..38 : Buffer.WriteB( ADR( U[i] ), 1 );
        | 39 : Buffer.WriteS( L"\'" );
        | 40..62 : Buffer.WriteB( ADR( U[i] ), 1 );
        | 63 : Buffer.WriteS( L'\?' );
        | 64..91 : Buffer.WriteB( ADR( U[i] ), 1 );
        | 92 : Buffer.WriteS( L'\\' );
        | 93..255 : Buffer.WriteB( ADR( U[i] ), 1 );
        ELSE // escape character
          Buffer.WriteS( L'\x' );
          Buffer.WriteS( hn[ CARDINAL( A[i] ) AND 000F0H >>  4 ] );
          Buffer.WriteS( hn[ CARDINAL( A[i] ) AND 0000FH       ] );
          IF NOT ByChars THEN // terminate escape
            Buffer.WriteS( L'"L"' );
          END;
        END;
        IF ByChars THEN
          IF L = 1 THEN
            Buffer.WriteS( L"'" );
          ELSE
            Buffer.WriteS( L"', " );
          END;
        END;
        INC( i );
      END;
      
      INC( I, i );
      IF I >= L THEN
        EXIT;
      END;
    END; // LOOP
  END OutANSIEscapeCS;

  PUBLIC PROCEDURE OutUNICODEEscapeCS( S : StringsO.CString; ByChars : BOOLEAN );
  TYPE
    TPC16 = POINTER TO CARD16;
  CONST
    hn = L'0123456789ABCDEF'; 
  VAR
    C : CARDINAL;
    I : CARDINAL := 0;
    L : CARDINAL := S.Length;
  BEGIN
    WHILE I < L DO
      C := CARDINAL( S[I] );
      IF ByChars THEN
        Buffer.WriteS( L"L'" );
      END;
      CASE C OF
      | 7 : Buffer.WriteS( L'\a' );
      | 8 : Buffer.WriteS( L'\b' );
      | 9 : Buffer.WriteS( L'\t' );
      | 10 : Buffer.WriteS( L'\n' );
      | 11 : Buffer.WriteS( L'\v' );
      | 12 : Buffer.WriteS( L'\f' );
      | 13 : Buffer.WriteS( L'\r' );
      | 32..33 : Buffer.WriteB( ADR( C ), 1 );
      | 34 : Buffer.WriteS( L'\"' );
      | 35..38 : Buffer.WriteB( ADR( C ), 1 );
      | 39 : Buffer.WriteS( L"\'" );
      | 40..62 : Buffer.WriteB( ADR( C ), 1 );
      | 63 : Buffer.WriteS( L'\?' );
      | 64..91 : Buffer.WriteB( ADR( C ), 1 );
      | 92 : Buffer.WriteS( L'\\' );
      | 93..255 : Buffer.WriteB( ADR( C ), 1 );
      ELSE // escape character
        Buffer.WriteS( L'\x' );
        Buffer.WriteS( hn[ C AND 0F000H >> 12 ] );
        Buffer.WriteS( hn[ C AND 00F00H >>  8 ] );
        Buffer.WriteS( hn[ C AND 000F0H >>  4 ] );
        Buffer.WriteS( hn[ C AND 0000FH       ] );
        IF NOT ByChars THEN // terminate escape
          Buffer.WriteS( L'"L"' );
        END;
      END;
      IF ByChars THEN
        IF L = 1 THEN
          Buffer.WriteS( L"'" );
        ELSE
          Buffer.WriteS( L"', " );
        END;
      END;
      INC( I );
    END;
  END OutUNICODEEscapeCS;

  PUBLIC PROCEDURE LineS( S : ARRAY OF WCHAR );
  BEGIN
    Indent();
    OutS( S );
    EOL();
  END LineS;

  PUBLIC PROCEDURE LineSCS( S : ARRAY OF WCHAR; CONST CS : StringsO.CString );
  BEGIN
    Indent();
    OutS( S );
    OutCS( CS );
    EOL();
  END LineSCS;

  PUBLIC PROCEDURE LineLB();
  BEGIN
    Indent();
    OutLB();
    EOL();
  END LineLB;

  PUBLIC PROCEDURE LineRB();
  BEGIN
    Indent();
    OutRB();
    EOL();
  END LineRB;

  PUBLIC PROCEDURE LineRBS( S : ARRAY OF WCHAR ); // for commenting
  BEGIN
    Indent();
    OutRB();
    OutS( L' // ' );
    OutS( S );
    EOL();
  END LineRBS;

  PUBLIC PROCEDURE LineRBSC();
  BEGIN
    Indent();
    OutRB();
    OutSC();
    EOL();
  END LineRBSC;

  PUBLIC PROCEDURE LineRBSCCS( CONST S : StringsO.CString ); // for commenting name
  BEGIN
    Indent();
    OutRB();
    OutSC();
    OutS( L' // ' );
    OutCS( S );
    EOL();
  END LineRBSCCS;

  PUBLIC PROCEDURE EOL();
  CONST
    Ln = WCHAR( 13 ) + WCHAR( 10 );
  BEGIN
    Buffer.WriteB( ADR( Ln ), 2 );
    Buffer.ResetWrap();
  END EOL;

  PUBLIC PROCEDURE goManaged() : BOOLEAN;
  BEGIN
    RETURN goManagedCPP IN GenerateOptions;
  END goManaged;

  PUBLIC PROCEDURE SetPacking( Packing : CARDINAL );
  BEGIN
    IF Packing <> GlobalPacking THEN
      Indent();
        OutS( L'#pragma pack(push, ' );
        OutN( Packing );
        OutRP();
      EOL();
    END;
  END SetPacking;

  PUBLIC PROCEDURE ResetPacking( Packing : CARDINAL );
  BEGIN
    IF Packing <> GlobalPacking THEN
      LineS( L'#pragma pack(pop)' );
    END;
  END ResetPacking;

  PUBLIC PROCEDURE Generate( OutputPath : ARRAY OF WCHAR; GM : TGenerate; GO : TGenerateOptions; M : ADDRESS );
  VAR
    c : CARDINAL;
    P : FIO.PathStrW;
  BEGIN
    GenerateMode := GM;
    GenerateOptions := GO;
    GlobalPacking := DOM.TPModule( M )^.EStack.PeekBottom()^.Packing;
    ASSIGN( P, OA( DOM.TPModule( M )^.FilePath.Length, DOM.TPModule( M )^.FilePath.szData ));
    c := Strings.LastIndexOfCharW( P, L'.', 0 );
    IF c <> MAX( CARDINAL ) THEN
      Strings.RemoveW( REF P, c, MAX( CARDINAL ));
      IF DOM.TPModule( M )^.UnitKind = DOM.ukDefinition THEN
        Strings.AppendW( REF P, L'.h' );
      ELSE
        Strings.AppendW( REF P, L'.cpp' );
      END;
    END;
    c := Strings.LastIndexOfCharW( P, L'/', 0 );
    IF c = MAX( CARDINAL ) THEN
      c := Strings.LastIndexOfCharW( P, L'\', 0 );
    END;
    IF c <> MAX( CARDINAL ) THEN
      Strings.RemoveW( REF P, 0, c + 1 );
    END;
    IF OutputPath[0] <> WCHAR( 0 ) THEN
      Strings.PrependW( REF P, OutputPath );
    END;
    IF Buffer.Create( P, FALSE ) THEN
      DOM.TPModule( M )^.Generate( ADR( SELF ), DOM.gcsDefault );
      Buffer.Close();
    END;
  END Generate;

BEGIN
  IndentDepth := 0;
  IndentCount := 2;
  Storage.Fill( ADR( IndentData ), SIZE( IndentData ), 0 );
  GenerateMode := genUnknown;
  GenerateOptions := TGenerateOptions{};
  GlobalPacking := 1;
END CGenerator;

PROCEDURE Generate( OutputPath : ARRAY OF WCHAR; GM : TGenerate; GO : TGenerateOptions; M : ADDRESS );
VAR
  Gen : CGenerator;
BEGIN
  // Gen.Init( L' ', 2 );
  Gen.Init( WCHAR( 9 ), 1 );
  Gen.Generate( OutputPath, GM, GO, M );
END Generate;

INITIALLY __I();
BEGIN
END __I;

END Generator.