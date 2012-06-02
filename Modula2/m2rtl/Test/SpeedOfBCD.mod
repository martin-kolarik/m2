MODULE SpeedOfBCD;

IMPORT
  windows,
  Storage,
  Strings;

TYPE
  PackedBcd = ARRAY[0..9] OF CARD8;

  PROCEDURE LongToBcd( A: LONGREAL ): PackedBcd;
  TYPE
    r = RECORD
          CASE : CARD16 OF
          | 0: w0, w1, w2, w3 : CARD16;
          | 1: l0, l1 : CARD32;
	        END;
        END;
  VAR 
    res : PackedBcd;
    exp : CARD16;
    buf : r;
    shf : CARDINAL;
    rem : ARRAY [0..4] OF CARD16;
    buf2 : r;
    tmp : RECORD
            CASE : CARD16 OF
            | 0: w0, w1 : CARD16;
            | 1: l0 : CARD32;
            END;
          END;
  BEGIN
    IF A < 0.0 THEN
      res[9] := 80H;
      A := -A;
    ELSE
      res[9] := 00H;
    END;
    IF A >= 1.15E18 THEN
      Storage.Fill( ADR( res ), SIZE( res ) - 1, 99H );
      RETURN res;
    END;
    IF A < 1.0 THEN
      Storage.Fill( ADR( res ), SIZE( res ) - 1, 0 );
      RETURN res;
    END;

  (* convert to longlong (64 bit) integer *)
  (* extract exponent, build mantisa and calc shift *)
    buf := r( A );
    exp := ( buf.w3 (* A always positive AND 7FF0H *) ) >> 4 - 3FFH;  (* get exponent *)
    buf.w3 := buf.w3 AND 000FH OR 0010H;  (* clear exponent and add leading 1 *)
    shf := 52 - CARDINAL( exp );
  (* shift mantisa right *)
    IF shf >= 32 THEN
      buf.l0 := buf.l1;
      buf.l1 := 0;
      DEC( shf, 32 );
    END;
    buf.l0 := ( buf.l0 >> shf ) OR ( buf.l1 << ( 32 - shf ));
    buf.l1 := buf.l1 >> shf;

  (* divide *)
    buf2.w3 := 0;
    buf2.w2 := CARD16( buf.l1 DIV 10000 );
    tmp.w1 := CARD16( buf.l1 MOD 10000 );
    tmp.w0 := buf.w1;
    buf2.w1 := CARD16( tmp.l0 DIV 10000 );
    tmp.w1 := CARD16( tmp.l0 MOD 10000 );
    tmp.w0 := buf.w0;
    buf2.w0 := CARD16( tmp.l0 DIV 10000 );
    rem[0] := CARD16( tmp.l0 MOD 10000 );
    buf := buf2;

    buf2.w2 := CARD16( buf.l1 DIV 10000 );
    tmp.w1 := CARD16( buf.l1 MOD 10000 );
    tmp.w0 := buf.w1;
    buf2.w1 := CARD16( tmp.l0 DIV 10000 );
    tmp.w1 := CARD16( tmp.l0 MOD 10000 );
    tmp.w0 := buf.w0;
    buf2.w0 := CARD16( tmp.l0 DIV 10000 );
    rem[1] := CARD16( tmp.l0 MOD 10000 );
    buf := buf2;

    tmp.w1 := buf.w2;
    tmp.w0 := buf.w1;
    buf2.w1 := CARD16( tmp.l0 DIV 10000 );
    tmp.w1 := CARD16( tmp.l0 MOD 10000 );
    tmp.w0 := buf.w0;
    buf2.w0 := CARD16( tmp.l0 DIV 10000 );
    rem[2] := CARD16( tmp.l0 MOD 10000 );

    rem[4] := CARD16( buf2.l0 DIV 10000 );
    rem[3] := CARD16( buf2.l0 MOD 10000 );

    FOR shf := 0 TO 4 DO
      res[2*shf+1] := CARD8( rem[shf] DIV 1000 ) << 4;
      rem[shf] := rem[shf] MOD 1000;
      res[2*shf+1] := res[2*shf+1] OR CARD8( rem[shf] DIV 100 );
      rem[shf] := rem[shf] MOD 100;
      res[2*shf] := CARD8( rem[shf] DIV 10 ) << 4;
      res[2*shf] := res[2*shf] OR CARD8( rem[shf] MOD 10 );
    END;
    RETURN res;
  END LongToBcd;

  TYPE
    TBCD = ARRAY [0..19] OF CARD8;

  PROCEDURE LONGREALToBCD( R : LONGREAL ) : TBCD;
  TYPE
    T2BCD = ARRAY [0..39] OF CARD8;
    TPBCD = POINTER TO TBCD;
    TPC8 = POINTER TO CARD8;
    #if #not( Platform #startswith L"x86" ) #then
      TC = RECORD
             L, H : CARD32;
           END;
      TPC = POINTER TO TC;
    #endif
  CONST
    BCInit = T2BCD( 0 BY 40 );
  VAR
    BCD : T2BCD := BCInit;
    PB : TPC8;
    #if Platform #startswith L"x86" #then
      FBCD : TBCD;
      PB2 : TPC8;
    #else
      C : TC;
      Shf : CARD32;
      VH : CARD32;
      VL : CARD32;
    #endif
  BEGIN
    #if Platform #startswith L"x86" #then
      ASM
        fld    qword ptr [R]
        fbstp  tbyte ptr [FBCD]
      END;
      // expand reverse packed BCD to forward unpacked one
      PB := ADR( BCD[18] );
      PB^ := 255;
      DEC( PB );
      PB2 := ADR( FBCD );
      WHILE PB2^ <> 0 DO
        PB^ := PB2^ AND 0FH; DEC( PB );
        PB^ := PB2^ >> 4; DEC( PB );
        INC( PB2 );
      END;
      RETURN TPBCD( PB )^;
    #else
      C := TC( R );
      WITH C DO
        Shf := 52 - H >> 20 + 03FFH;
        L := L >> Shf;
        L := L OR ( H << ( 32 - Shf ));
        H := ( H AND 0FFFFFH OR 100000H ) >> Shf;
      END; // WITH
      
      VH := CARD32( CARD64( C ) DIV 1000000000 );
      VL := CARD32( CARD64( C ) MOD 1000000000 );

      PB := ADR( BCD[18] );
      PB^ := 255;
      DEC( PB );
      LOOP
        IF VL = 0 THEN
          EXIT;
        END;
        PB^ := CARD8( VL MOD 10 );
        VL := VL DIV 10;
        DEC( PB );
      END; // LOOP
      IF VH = 0 THEN
        RETURN TPBCD( PB )^;
      END;

      PB := ADR( BCD[8] );
      LOOP
        PB^ := CARD8( VH MOD 10 );
        VH := VH DIV 10;
        IF VH = 0 THEN
          EXIT;
        END;
        DEC( PB );
      END; // LOOP
      RETURN TPBCD( PB )^;
    #endif
  END LONGREALToBCD;
  
  #save, call( convention => cdecl )
  PROCEDURE wmain06() : INTEGER;
  #restore
  CONST
    sp = C'  ';
    BN = CARD64( 0101010101010101010101010101010101010101010101010101010101010101010101010101010101L );
  VAR
    i : CARDINAL;
    r : LONGREAL := 1178.0*LONGREAL( BN );
    B : TBCD;
    P : PackedBcd;
    s : ARRAY [0..19] OF WCHAR;

    f : windows.HANDLE;
    t : CARDINAL;
  BEGIN
    f := windows.GetStdHandle( windows.STD_ERROR_HANDLE );
    
    t := windows.GetTickCount();
    FOR i := 0 TO 5000000 DO
      P := LongToBcd( r );
    END;
    t := windows.GetTickCount() - t;
    Strings.FromCARD32W( t, 10, OUT s );
    windows.WriteFile( f, ADR( s ), 2*LENGTH( s ), ADR( i ), NIL );
    windows.WriteFile( f, ADR( sp ), LENGTH( sp ), ADR( i ), NIL );

    t := windows.GetTickCount();
    FOR i := 0 TO 5000000 DO
      B := LONGREALToBCD( r );
    END;
    t := windows.GetTickCount() - t;
    Strings.FromCARD32W( t, 10, OUT s );
    windows.WriteFile( f, ADR( s ), 2*LENGTH( s ), ADR( i ), NIL );
    
    RETURN 0;
  END wmain06;

BEGIN
END SpeedOfBCD.