IMPLEMENTATION MODULE bitarray;

//==============================================================

FROM Storage IMPORT
  ALLOCATE, REALLOCATE, DEALLOCATE;
  
IMPORT
  Storage;

//==============================================================

CONST
  bcGs = 6;         // bit counts granularity shift
  bcGb = bcGs - 3;  // bit counts granularity bytes shift
  bcGi = 1 << bcGs; // bit counts granularity items
  bcGm = bcGi - 1;  // bit counts granularity mask

TYPE
  TBitsOfByteCount = ARRAY [0..255] OF CARD8;
CONST
  bitsCount = TBitsOfByteCount(
    0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4, //   0.. 15  
    1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5, //  15.. 31 
    1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5, //  32.. 47 
    2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6, //  48.. 63

    1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5, //  64.. 79
    2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6, //  80.. 95
    2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6, //  96..111
    3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7, // 112..127
                                                    
    1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5, // 128..143
    2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6, // 144..159
    2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6, // 160..175
    3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7, // 176..191

    2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6, // 192..207
    3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7, // 208..223
    3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7, // 224..239
    4, 5, 5, 6, 5, 6, 6, 7, 5, 6, 6, 7, 6, 7, 7, 8  // 240..255
  );
  
TYPE
  TAData = ARRAY [0..0] OF BITSET32;
  TData = POINTER TO TAData;
  TABitsCount = ARRAY [0..0] OF CARDINAL;
  TBitsCount = POINTER TO TABitsCount;

//==============================================================

CLASS IMPLEMENTATION CBitArray;

//--------------------------------------------------------------

  PUBLIC PROPERTY CBitArray.Count GET : CARDINAL;
  BEGIN
    RETURN _Allocated;
  END CBitArray.Count;
  
//--------------------------------------------------------------

  PUBLIC PROPERTY CBitArray.Count SET( Value : CARDINAL );
  VAR
    L1, L2 : CARDINAL;
    LBA : CBitArray;
  BEGIN
    IF Value = 0 THEN
      _Allocated := 0;
      Occupied := 0;
      IF _Data <> NIL THEN
        DISPOSE( _Data );
      END;
      // done in AdjustBitsCount
      // IF PBitsCount <> NIL THEN
      //   DISPOSE( PBitsCount );
      // END;
    ELSE
      L1 := CountToBytes( _Allocated );
      _Allocated := Value;
      L2 := CountToBytes( _Allocated );
      IF L1 > L2 THEN
        LBA._Data := _Data@[L1];
        LBA._Allocated := L2-L1;
        LBA.Occupied := -1;
        LBA.CountBits := TRUE;
        DEC( Occupied, LBA.AdjustBitsCount());
        LBA._Data := NIL; // deny deallocating mine data
        REALLOCATE( _Data, L2 );
      ELSE
        REALLOCATE( _Data, L2 );
        Storage.Fill( _Data@[L1], L2-L1, 0 );
      END;
    END;
    AdjustBitsCount();
  END CBitArray.Count;

//--------------------------------------------------------------

  PUBLIC PROPERTY CBitArray.CountBits GET : BOOLEAN;
  BEGIN
    RETURN _CountBits;
  END CBitArray.CountBits;

//--------------------------------------------------------------

  PUBLIC PROPERTY CBitArray.CountBits SET( Value : BOOLEAN );
  BEGIN
    IF _CountBits <> Value THEN
      AdjustBitsCount();
    END;
  END CBitArray.CountBits;

//--------------------------------------------------------------

  PUBLIC INDEX CBitArray GET( Index : INTEGER ) : BOOLEAN;
  BEGIN
    IF Index >= INTEGER( Occupied ) THEN
      RETURN FALSE;
    ELSE
      RETURN ( Index AND 31 ) IN _Data^[ Index >> 5 ];
    END;
  END CBitArray;

//--------------------------------------------------------------

  PUBLIC INDEX CBitArray SET( Index : INTEGER; Value : BOOLEAN );
  VAR
    hi : CARDINAL;
    i : CARDINAL;
    b : BOOLEAN;
  BEGIN
    IF Index >= INTEGER( Occupied ) THEN
      IF ExpandOnSet THEN
        Count := ( Index + 31 ) << 5 >> 5;
      ELSE
        RETURN;
      END;
    END;

    b := SELF[Index];
    IF Value AND NOT b THEN
      INCL( _Data^[ Index >> 5 ], Index AND 31 );
      INC( Occupied );
    ELSIF NOT Value AND b THEN
      EXCL( _Data^[ Index >> 5 ], Index AND 31 );
      DEC( Occupied );
    ELSE
      RETURN;
    END;

    IF _CountBits THEN
      i := Index >> 5;
      hi := CountToBytes( _Allocated ) - 1;
      LOOP
        IF i > hi THEN
          EXIT;
        END;
        INC( _BitsCount^[i] );
        INC( i );
      END; // LOOP
    END; // IF PBitsCount <> NIL
  END CBitArray;

//--------------------------------------------------------------

  PRIVATE VIRTUAL PROCEDURE __VMT();
  BEGIN
  END __VMT;

//--------------------------------------------------------------

  PUBLIC PROCEDURE InclAll();
  VAR
    hi : CARDINAL;
    i  : CARDINAL;
  BEGIN
    Storage.Fill( _Data, CountToBytes( _Allocated ), 0FFH );
    Occupied := _Allocated;

    IF _CountBits THEN
      i := 0;
      hi := CountToBytes( _Allocated ) - 1;
      LOOP
        IF i >= hi THEN
          EXIT;
        END;
        _BitsCount^[i] := MIN2(( i + 1 ) * 32, Occupied );
        INC( i );
      END; // LOOP
    END;
  END InclAll;

//--------------------------------------------------------------

  PUBLIC PROCEDURE Incl( Bit : INTEGER );
  BEGIN
    SELF[Bit] := TRUE;
  END Incl;

//--------------------------------------------------------------

  PUBLIC PROCEDURE In( Bit : INTEGER ) : BOOLEAN;
  BEGIN
    RETURN SELF[Bit];
  END In;

//--------------------------------------------------------------

  PUBLIC PROCEDURE ExclAll();
  BEGIN
    Storage.Fill( _Data, CountToBytes( _Allocated ), 0 );
    Occupied := 0;
    IF _CountBits THEN
      Storage.Fill( _BitsCount, CountToBytes( _Allocated ), 0 );
    END;
  END ExclAll;

//--------------------------------------------------------------

  PUBLIC PROCEDURE Excl( Bit : INTEGER );
  BEGIN
    SELF[Bit] := FALSE;
  END Excl;

//--------------------------------------------------------------

  PUBLIC PROCEDURE GetFirst( OUT Bit : INTEGER ) : BOOLEAN;
  BEGIN
    IF Occupied = 0 THEN
      Bit := -1;
      RETURN FALSE;
    ELSE
      RETURN NextOf( -1, OUT Bit );
    END;
  END GetFirst;

//--------------------------------------------------------------

  PUBLIC PROCEDURE NextOf( FromBit : INTEGER; OUT Bit : INTEGER ) : BOOLEAN;
  TYPE
    TMasks = ARRAY [0..31] OF BITSET;
  CONST
    masks = TMasks(
      BITSET( 0FFFFFFFEH ), BITSET( 0FFFFFFFCH ), BITSET( 0FFFFFFF8H ), BITSET( 0FFFFFFF0H ),
      BITSET( 0FFFFFFE0H ), BITSET( 0FFFFFFC0H ), BITSET( 0FFFFFF80H ), BITSET( 0FFFFFF00H ),
      BITSET( 0FFFFFE00H ), BITSET( 0FFFFFC00H ), BITSET( 0FFFFF800H ), BITSET( 0FFFFF000H ),
      BITSET( 0FFFFE000H ), BITSET( 0FFFFC000H ), BITSET( 0FFFF8000H ), BITSET( 0FFFF0000H ),
      BITSET( 0FFFE0000H ), BITSET( 0FFFC0000H ), BITSET( 0FFF80000H ), BITSET( 0FFF00000H ),
      BITSET( 0FFE00000H ), BITSET( 0FFC00000H ), BITSET( 0FF800000H ), BITSET( 0FF000000H ),
      BITSET( 0FE000000H ), BITSET( 0FC000000H ), BITSET( 0F8000000H ), BITSET( 0F0000000H ),
      BITSET( 0E0000000H ), BITSET( 0C0000000H ), BITSET( 080000000H ), BITSET( 000000000H )
    );
  VAR
    FromIndex : CARDINAL;
  BEGIN
    Bit := -1;
    INC( FromBit );
    FromIndex := FromBit >> 5;
    LOOP
      IF FromBit >= INTEGER( _Allocated ) THEN
        RETURN FALSE;
      ELSIF FromBit AND 31 IN _Data^[ FromIndex ] THEN
        Bit := FromBit;
        RETURN TRUE;
      ELSIF masks[ FromBit AND 31 ] * _Data^[ FromIndex ] = {} THEN
        INC( FromIndex );
        FromBit := FromIndex << 5;
      ELSE
        INC( FromBit );
      END;
    END; // LOOP
  END NextOf;

//--------------------------------------------------------------

  PUBLIC PROCEDURE OrderOfSetBit( Bit : INTEGER; OUT Order : INTEGER ) : BOOLEAN;
  VAR
    h  : CARDINAL;
    l  : CARDINAL;
    pb : PBYTE;
  BEGIN
    Order := -1;
    IF NOT _CountBits THEN
      RETURN FALSE;
    END; // IF PBitsCount = 0

    h := Bit >> bcGs;
    IF h > 0 THEN
      Order := _BitsCount^[h-1]; // round Bit to whole 64bit block
    ELSE
      Order := 0;
    END;
    l := Bit AND bcGm;

    pb := PBYTE( ADR( _Data^[h] ));
    LOOP
      IF l = 0 THEN
        // exactly in byte order, counted
        EXIT;
      ELSIF l < 8 THEN
        INC( Order, CARDINAL( bitsCount[ CARDINAL( pb^ ) AND ( 1 << l - 1 ) ] ));
        EXIT;
      ELSE
        INC( Order, CARDINAL( bitsCount[ CARDINAL( pb^ ) ] ));
        INC( pb );
        DEC( l, 8 );
      END;
    END;

    RETURN TRUE;
  END OrderOfSetBit;

//--------------------------------------------------------------

   PUBLIC PROCEDURE Dispose();
   BEGIN
      _Allocated := 0;
      Occupied := 0;
      IF _Data <> NIL THEN
        DISPOSE( _Data );
      END;
      AdjustBitsCount();
   END Dispose;

//--------------------------------------------------------------

  INTERNAL INLINE PROCEDURE CountToBytes( Count : CARDINAL ) : CARDINAL;
  BEGIN
    RETURN ( Count + 31 ) >> 5 << 2;
  END CountToBytes;

//--------------------------------------------------------------

  INTERNAL PROCEDURE AdjustBitsCount() : CARDINAL;
  VAR
    Count : CARDINAL;
    i     : CARDINAL;
    Len   : CARDINAL;
    pb    : PBYTE;
  BEGIN
    IF NOT _CountBits OR ( _Allocated = 0 ) THEN
      IF _BitsCount <> NIL THEN
        DISPOSE( _BitsCount );
      END;
      RETURN 0;
    END;

    i := ( _Allocated + bcGi + bcGm ) >> bcGs << 3; // BITSETS converted to GRANULARITY BYTES
    REALLOCATE( _BitsCount, i );
    Storage.Fill( _BitsCount, i, 0 );

    Count := 0;
    pb := PBYTE( ADR( _Data^[0] ));
    Len := CountToBytes( _Allocated ); // items converted to BYTES
    i := 0;
    LOOP
      IF i = Len THEN
        EXIT;
      END;

      INC( Count, CARDINAL( bitsCount[ CARDINAL( pb^ ) ] ));
      IF Count > Occupied THEN
        Count := Occupied;
        _BitsCount^[ i >> bcGb ] := Count;
        EXIT;
      END;

      INC( pb );
      INC( i );
      IF i AND ( 1 << bcGb - 1 ) = 0 THEN
        _BitsCount^[ i >> bcGb - 1 ] := Count;
      END;
    END;
    
    RETURN Count;
  END AdjustBitsCount;

//--------------------------------------------------------------

BEGIN
  _Data := NIL;
  _Allocated := 0;
  _BitsCount := NIL;
  Occupied := 0;
FINALLY
  Dispose();
END CBitArray;

//==============================================================

END bitarray.
