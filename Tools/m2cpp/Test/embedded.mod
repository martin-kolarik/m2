MODULE embedded;

(*===========================================================================*)

TYPE
  TParamString       = ARRAY[0..511] OF WCHAR;
  TPParamString      = POINTER TO TParamString;
  TParamStringArray  = ARRAY [0..0] OF TPParamString;
  TPParamStringArray = POINTER TO TParamStringArray;

(*# save,   call( entry_point => on,
                  prefix      => cdecl ),
          option( export      => on ) *)
PROCEDURE wmain( argc : INTEGER; argp : TPParamStringArray; enpv : TPParamStringArray ) : CARDINAL;
(*# restore *)
BEGIN
  RETURN 0;
END wmain;

(*===========================================================================*)

PROCEDURE TestOAAssign( S : ARRAY OF WCHAR );
VAR
  L : ARRAY [0..63] OF WCHAR;
BEGIN
  ASSIGN( L, S );
END TestOAAssign;

INITIALLY X;
TYPE
  TRECORD = RECORD
              A : BOOLEAN;
              B : ARRAY [0..1338] OF WORD;
              C : LONGREAL;
              D : BOOLEAN;
            END;
TYPE
  TENUM = ( CUP, CAT, ITEM, CAR );
VAR
  a : ADDRESS;
  b : BOOLEAN;
  bt : BITSET;
  c : CARDINAL;
  i : INTEGER;
  r : LONGREAL;
  R : TRECORD;
  cht : TCHAR;
  chb : BCHAR;
  chw : WCHAR;
  st : ARRAY [0..7] OF TCHAR;
  sb : ARRAY [0..7] OF BCHAR;
  sw : ARRAY [0..7] OF WCHAR;
BEGIN
  // ABS
  r := ABS( -1.0 );
  i := ABS( -1 );
  // ADR
  a := ADR( cht );
  // CAP & LOW function
  chb := CAP( C'a' );
  chw := CAP( L'w' );
  cht := CAP( 'a' );
  chb := LOW( C'a' );
  chw := LOW( L'w' );
  cht := LOW( 'a' );
  // DEC & INC function
  i := DEC( i );
  i := INC( i );
  i := DEC( i, 5 );
  i := INC( i, 5 );
  i := DEC( 5, 4 );
  i := INC( 5, 4 );
  // EQUALS
  b := EQUALS( L'ahoj', L'ahoj' );
  b := EQUALS( 'a', 'b' );
  // ODD & EVEN
  b := ODD( 14 );
  b := EVEN( 14 );
  // FIELDOFS
  c := FIELDOFS( TRECORD.D );
  // FRAC
  r := FRAC( -155878.1458647 );
  // HIGH
  // LENGTH
  c := LENGTH( L'ahoj' );
  c := LENGTH( '' );
  c := LENGTH( chb );
  // MIN & MAX
  c := MAX( CARD16 );
  i := MIN( INT8 );
  c := MAX2( 156, 118 );
  i := MIN2( -14, -158 );
  // ORD
  c := ORD( TRUE );
  c := ORD( 14 );
  c := ORD( L'5' );
  c := ORD( ITEM );
  // SIZE
  c := SIZE( TRECORD );
  c := SIZE( c );
  // TRUNC
  i := TRUNC( -14.1548487878 );
  // VAL
  b := VAL( BOOLEAN, 1 );
  chw := VAL( WCHAR, 66 );
  // ASSIGN
  ASSIGN( sb, 'vole' );
  // CAP & LOW procedures
  CAP( sb );
  CAP( sw );
  CAP( st );
  LOW( sb );
  LOW( sw );
  LOW( st );
  // DEC & INC procedures
  DEC( a, 5 );
  DEC( i, 2 );
  DEC( c );
  DEC( b );
  INC( a, 5 );
  INC( i, 2 );
  INC( c );
  INC( b );
  // EXCL & INCL procedures
  INCL( bt, 14 );
  EXCL( bt, 14 );
END X;

END embedded.