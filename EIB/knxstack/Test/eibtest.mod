MODULE eibTest;
(*# module( init_code => off ) *)

(*===========================================================================*)

IMPORT
  windows;

IMPORT
  FIO,
  Str;

IMPORT
  eib_def;

(*===========================================================================*)

PROCEDURE FWrLn( File : FIO.File );
BEGIN
  FIO.WrLnA( File );
END FWrLn;

PROCEDURE FWrStr( File : FIO.File; String : ARRAY OF CHAR );
BEGIN
  FIO.WrStrA( File, String );
END FWrStr;

PROCEDURE FDumpPacket( Head : ARRAY OF CHAR; File : FIO.File; CONST EIB : eib_def.CEIBPacket );
TYPE
  TBC8 = ARRAY [0..SIZE( eib_def.CEIBPacket ) - 1] OF CARD8;
  TPC8A = POINTER TO TBC8;
VAR
  i : CARDINAL;
  b : CARD8;
BEGIN
  IF Head[0] <> 0C THEN
    FIO.WrLn( File );
    FIO.WrStrA( File, Head );
    FIO.WrLn( File );
  END;
  FIO.WrStrA( File, '  ' );
  FOR i := 0 TO SIZE( eib_def.CEIBPacket ) - 1 DO
    b := TPC8A( ADR( EIB ))^[i];
    IF b < 16 THEN
      FIO.WrCharA( File, '0' );
      FIO.WrHex8A( File, b, 1 );
    ELSE
      FIO.WrHex8A( File, b, 2 );
    END;
    CASE i OF
    | 0, 2, 4, 5, 6, 7 :
      FIO.WrCharA( File, ' ' );
    END;
  END;
  FWrLn( File );
END FDumpPacket;

PROCEDURE FWrResult( File : FIO.File; OK : BOOLEAN );
BEGIN
  IF OK THEN
    FIO.WrStrA( File, '  ..ok' );
  ELSE
    FIO.WrStrA( File, '  ..!! FAILURE' );
  END;
  FIO.WrLnA( File );
END FWrResult;

(*===========================================================================*)

TYPE
  TParamString = ARRAY[0..255] OF CHAR;
  TPParamString = POINTER TO TParamString;
  TParamStringArray = ARRAY [0..0] OF TPParamString;
  TPParamStringArray = POINTER TO TParamStringArray;

(*# save, call( o_a_copy=>off, 
                prefix=>cdecl,
                c_conv=>on ),
          option( export => on ) *)
PROCEDURE main( argc : INTEGER; argp : TPParamStringArray; enpv : TPParamStringArray ); FORWARD;
(*# restore *)

(*===========================================================================*)

PROCEDURE main( argc : INTEGER; argp : TPParamStringArray; enpv : TPParamStringArray );

(*----------*)

  PROCEDURE TrimQuotes( VAR Path : FIO.PathStrA );
  VAR
    c : CARDINAL;
  BEGIN
    IF Path[0] = '"' THEN
      Str.Delete( Path, 0, 1 );
    END;
    c := Str.Length( Path ) - 1;
    IF Path[c] = '"' THEN
      Path[c] := 0C;
    END;
  END TrimQuotes;

(*----------*)

  PROCEDURE ExtractNumber( String : ARRAY OF CHAR ) : CARDINAL;
  VAR
    nStr : ARRAY [0..31] OF CHAR;
    idx  : CARDINAL;
    b    : BOOLEAN;
  BEGIN
    nStr := '';
    idx := 2;
    LOOP
      IF ( String[idx] = 0C ) OR (( idx-2 ) > SIZE( nStr )) THEN
        EXIT;
      END;
      IF ( String[idx] >= '0' ) AND ( String[idx] <= '9' ) THEN
        nStr[idx-2] := String[idx];
      ELSE
        EXIT;
      END;
      INC( idx );
    END;
    INC(idx);
    nStr[idx-2] := 0C;
    IF idx > 3 THEN
      idx := Str.StrToCard( nStr, 10, b );
    ELSE
      idx := MAX( CARDINAL );
    END;
    RETURN idx;
  END ExtractNumber;

(*----------*)

LABEL
  Error, Finish;
VAR
  ErrorLevel : CARDINAL;
  ErrOutF    : FIO.File;
  i          : CARDINAL;
VAR
  access     : eib_def.TAccessFlagSet;
  c1, c2, c3 : CARDINAL;
  day        : eib_def.TDay;
  dadr       : eib_def.TAddress;
  EIB        : eib_def.CEIBPacket;
  sadr       : eib_def.TAddress;
  up, down   : BOOLEAN;
BEGIN
  ErrorLevel := 0;
  ErrOutF := windows.GetStdHandle( windows.STD_ERROR_HANDLE );

  FOR i := 1 TO argc - 1 DO
    IF ( argp^[i]^[0] = '/' ) OR ( argp^[i]^[0] = '-' ) THEN
    END;
  END; // FOR

  sadr.SetGroupAddress1( 0AFFEH );
  dadr.SetGroupAddress1( 02FFEH );

  EIB.InitToDefault();
  EIB.SetSourceAddress( sadr );
  EIB.SetDestinationAddress( dadr );
  EIB.SetValueDirection( eib_def.directionWrite );

  EIB.SetEIS1( TRUE );
  FDumpPacket( 'EIS1', ErrOutF, EIB );
  FWrResult( ErrOutF, EIB.GetEIS1() );

  EIB.SetEIS2Position( TRUE );
  FDumpPacket( 'EIS2Position', ErrOutF, EIB );
  FWrResult( ErrOutF, EIB.GetEIS2Position() );

  EIB.SetEIS2Value( 50 );
  FDumpPacket( 'EIS2Value set to 50 %', ErrOutF, EIB );
  FWrResult( ErrOutF, EIB.GetEIS2Value() = 50 );

  FOR i := 0 TO 100 DO
    EIB.SetEIS2Value( i );
    IF EIB.GetEIS2Value() <> i THEN
      FIO.WrHex32A( ErrOutF, i, 3 );
    END;
  END;
  EIB.ClearData();

  EIB.SetEIS2Control( TRUE, FALSE, 51 );
  FDumpPacket( 'EIS2Control about 51 %', ErrOutF, EIB );
  FWrResult( ErrOutF, EIB.GetEIS2Control( up, down ) = 100 );
  FWrResult( ErrOutF, up = TRUE );
  FWrResult( ErrOutF, down = FALSE );

  EIB.SetEIS2Control( TRUE, FALSE, 10 );
  FDumpPacket( 'EIS2Control about 10 %', ErrOutF, EIB );
  FWrResult( ErrOutF, EIB.GetEIS2Control( up, down ) = 13 );
  FWrResult( ErrOutF, up = TRUE );
  FWrResult( ErrOutF, down = FALSE );

  EIB.SetEIS3( eib_def.dayMonday, 21, 32, 32 );
  FDumpPacket( 'EIS3', ErrOutF, EIB );
  EIB.GetEIS3( day, c1, c2, c3 );
  FWrResult( ErrOutF, day = eib_def.dayMonday );
  FWrResult( ErrOutF, c1 = 21 );
  FWrResult( ErrOutF, c2 = 32 );
  FWrResult( ErrOutF, c3 = 32 );
  EIB.ClearData();

  EIB.SetEIS4( 1966, 3, 12 );
  FDumpPacket( 'EIS4', ErrOutF, EIB );
  EIB.GetEIS4( c1, c2, c3 );
  FWrResult( ErrOutF, c1 = 1966 );
  FWrResult( ErrOutF, c2 = 3 );
  FWrResult( ErrOutF, c3 = 12 );
  EIB.ClearData();

  EIB.SetEIS5( 20.0 );
  FDumpPacket( 'EIS5 20.0 W/O range', ErrOutF, EIB );
  FWrResult( ErrOutF, EIB.GetEIS5() = 20.0 );
  EIB.ClearData();

  EIB.SetEIS5Range( 20.0, -100.0, 100.0 );
  FDumpPacket( 'EIS5 20.0 W/I range', ErrOutF, EIB );
  FWrResult( ErrOutF, EIB.GetEIS5() = 20.0 );
  EIB.ClearData();

  EIB.SetEIS6( 40 );
  FDumpPacket( 'EIS6 40 %', ErrOutF, EIB );
  FWrResult( ErrOutF, EIB.GetEIS6() = 40 );
  EIB.ClearData();

  EIB.SetEIS7Move( FALSE );
  FDumpPacket( 'EIS7Move', ErrOutF, EIB );
  FWrResult( ErrOutF, EIB.GetEIS7Move() = FALSE );

  EIB.SetEIS7Step( TRUE );
  FDumpPacket( 'EIS7Step', ErrOutF, EIB );
  FWrResult( ErrOutF, EIB.GetEIS7Move() = TRUE );

  EIB.SetEIS9( -0.47 );
  FDumpPacket( 'EIS9 -0.47', ErrOutF, EIB );
  FWrResult( ErrOutF, ABS( EIB.GetEIS9() + 0.47 ) < 0.001 );
  EIB.ClearData();

  EIB.SetEIS10( 5000 );
  FDumpPacket( 'EIS10', ErrOutF, EIB );
  FWrResult( ErrOutF, EIB.GetEIS10() = 5000 );
  EIB.ClearData();

  EIB.SetEIS11( 789456123 );
  FDumpPacket( 'EIS11', ErrOutF, EIB );
  FWrResult( ErrOutF, EIB.GetEIS11() = 789456123 );
  EIB.ClearData();

  EIB.SetEIS12( 0123456H, eib_def.TAccessFlagSet{eib_def.accessPermission, eib_def.accessDirection}, 1 );
  FDumpPacket( 'EIS12', ErrOutF, EIB );
  EIB.GetEIS12( c1, access, c2 );
  FWrResult( ErrOutF, c1 = 0123456H );
  FWrResult( ErrOutF, access = eib_def.TAccessFlagSet{eib_def.accessPermission, eib_def.accessDirection} );
  FWrResult( ErrOutF, c2 = 1 );
  EIB.ClearData();

  EIB.SetEIS13( CHAR( 27 ));
  FDumpPacket( 'EIS13', ErrOutF, EIB );
  FWrResult( ErrOutF, EIB.GetEIS13() = CHAR( 27 ));
  EIB.ClearData();

  EIB.SetEIS14( 50 );
  FDumpPacket( 'EIS14', ErrOutF, EIB );
  FWrResult( ErrOutF, EIB.GetEIS14() = 50 );
  EIB.ClearData();

  EIB.SetEIS15( 'EIB ist OK' );
  FDumpPacket( 'EIS15', ErrOutF, EIB );
  FWrResult( ErrOutF, EIB.GetEIS15() = eib_def.TEISString( 'EIB ist OK' ));
  EIB.ClearData();

Error:
  FWrLn( ErrOutF );

Finish:
  windows.ExitProcess( ErrorLevel );
END main;

(*===========================================================================*)

END eibTest.