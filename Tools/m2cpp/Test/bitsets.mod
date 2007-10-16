MODULE bitsets;

  PROCEDURE Test;
  TYPE
    TS8 = SET OF [0..7];
    TS16 = SET OF [0..15];
    TS32 = SET OF [0..31];
    TS64 = SET OF [0..63];
    TSL = SET OF [0..127];
  VAR
    B8 : BITSET8 := {};
    B16 : BITSET16 := {};
    B32 : BITSET32 := {};
    B64 : BITSET64 := {};
    S8 : TS8 := {};
    S16 : TS16 := {};
    S32 : TS32 := {};
    S64 : TS64 := {};
    SL : TSL := {};
    SLx : TSL := TSL{};
    SB1 : SET OF BYTE := BYTE{};
    SB2 : SET OF BYTE := {};
  BEGIN
    SL := {};
    SL := TSL{3};
    INCL( B8, 4 );
    INCL( B16, 4 );
    INCL( B32, 4 );
    INCL( B64, 4 );
    EXCL( B8, 4 );
    EXCL( B16, 4 );
    EXCL( B32, 4 );
    EXCL( B64, 4 );
    IF 5 IN B8 THEN END;
    IF 5 IN B16 THEN END;
    IF 5 IN B32 THEN END;
    IF 5 IN B64 THEN END;
    INCL( S8, 4 );
    INCL( S16, 4 );
    INCL( S32, 4 );
    INCL( S64, 4 );
    INCL( SL, 4 );
    EXCL( S8, 4 );
    EXCL( S16, 4 );
    EXCL( S32, 4 );
    EXCL( S64, 4 );
    EXCL( SL, 4 );
    IF 5 IN S8 THEN END;
    IF 5 IN S16 THEN END;
    IF 5 IN S32 THEN END;
    IF 5 IN S64 THEN END;
    IF 5 IN SL THEN END;
  END Test;
  
  #save, call( convention => cdecl )
  PROCEDURE wmain();
  BEGIN
		Test();
  END wmain;
  #restore

END bitsets.