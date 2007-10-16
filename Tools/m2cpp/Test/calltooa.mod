MODULE calltooa;

  TYPE
    TPDWORD = POINTER TO LONGCARD;

  PROCEDURE WriteB( S : ARRAY OF BYTE; DW : TPDWORD );
  BEGIN
  END WriteB;

  PROCEDURE WriteW( S : ARRAY OF WORD; DW : TPDWORD );
  BEGIN
  END WriteW;

  PROCEDURE WriteS( S : ARRAY OF WCHAR; DW : TPDWORD );
  BEGIN
    WriteS( S, DW ); // must not be casted, Tf(S) = Ta(S)
    WriteB( S, DW ); // must be casted
    WriteW( S, DW ); // need not be casted
  END WriteS;

  PROCEDURE WriteRB( REF S : ARRAY OF BYTE; DW : TPDWORD );
  BEGIN
  END WriteRB;

  PROCEDURE WriteRW( REF S : ARRAY OF WORD; DW : TPDWORD );
  BEGIN
  END WriteRW;

  PROCEDURE WriteRS( REF S : ARRAY OF WCHAR; DW : TPDWORD );
  BEGIN
    WriteRS( REF S, DW ); // must not be casted, Tf(S) = Ta(S)
    WriteRB( REF S, DW ); // must be casted
    WriteRW( REF S, DW ); // need not be casted
  END WriteRS;

  PROCEDURE X;
  TYPE
    TPC16 = POINTER TO CARD16;
  CONST
    hn = L"abcd";
  VAR 
    A : ARRAY [0..7] OF CARDINAL;
    BA : ARRAY [0..7] OF BYTE;
    C : CARDINAL;
    CA : ARRAY [0..7] OF WCHAR;
  BEGIN
    WriteS( L'a', ADR( C ));
    WriteS( L'aa', ADR( C ));
    WriteS( hn[ CARDINAL( TPC16( 0 )^ AND 0F000H >> 12 ) ] , ADR( C ));
    WriteS( WCHAR( 0 ), ADR( C ));
    WriteS( CA, ADR( C ));

    WriteS( CA, ADR( C ));
    WriteB( CA, ADR( C ));
    WriteW( CA, ADR( C ));
    
    WriteB( C, ADR( C ));
    WriteB( TPC16( 0 )^, ADR( C ));
    WriteB( CARDINAL( 0 ), ADR( C ));
    WriteB( A, ADR( C ));
    WriteB( BA, ADR( C ));

    WriteRS( REF CA, ADR( C ));
    WriteRB( REF CA, ADR( C ));
    WriteRW( REF CA, ADR( C ));
  END X;

BEGIN
END calltooa.