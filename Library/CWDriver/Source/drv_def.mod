IMPLEMENTATION MODULE drv_def;

(*================================================================================*)

FROM Debug IMPORT
   Assertion;

FROM Storage IMPORT
  ALLOCATE, DEALLOCATE;

IMPORT
  time;

(*================================================================================*)

CONST
   kwFALSE = L'false';
   kwTRUE = L'true';

(*================================================================================*)

PROCEDURE InitValue( VAR Value : TValue );
// sets vtNothing, does not check dynamic string
// used to initialize new values
BEGIN
  Value.Type := vtNothing;
END InitValue;

(*--------------------------------------------------------------------------------*)

// sets vtNothing but checks for possible dynamic string and frees it
PROCEDURE DoneValue( VAR Value : TValue );
BEGIN
  IF ( Value.Type = vtPString256 ) AND ( Value.ValPString256W <> NIL ) THEN
    DISPOSE( Value.ValPString256W );
  ELSIF ( Value.Type = vtBuffer ) AND ( Value.PBuffer <> NIL ) THEN
    DISPOSE( Value.PBuffer );
  END;
  Value.Type := vtNothing;
END DoneValue;

(*--------------------------------------------------------------------------------*)

PROCEDURE ValueDataLength( Type : TValueType ) : CARDINAL;
BEGIN
   CASE Type OF
   | vtNothing, vtError, vtUnknown :
      RETURN 0;
   | vtBoolean, vtShortInt, vtShortCard :
      RETURN 1;
   | vtCardinal, vtInteger :
      RETURN 4;
   | vtLongCard, vtLongInt, vtPString256 :
      RETURN 4;
   | vtLongReal :
      RETURN 8;
   ELSE
      RETURN 0;
   END;
END ValueDataLength;

(*--------------------------------------------------------------------------------*)

PROCEDURE IOTypeToCWType( IOType : iovalue.TValueType ) : TValueType;
BEGIN
   CASE IOType OF
   | iovalue.vtBoolean :
      RETURN vtBoolean;
   | iovalue.vtTristate :
      RETURN vtShortInt;
   | iovalue.vtInteger :
      RETURN vtLongInt;
   | iovalue.vtLong :
      RETURN vtLongReal;
   | iovalue.vtFloat :
      RETURN vtLongReal;
   | iovalue.vtString :
      RETURN vtDString;
   | iovalue.vtDate :
      RETURN vtLongReal;
   END;
   RETURN vtUnknown;
END IOTypeToCWType;

(*================================================================================*)

PROCEDURE CWTypeToIOType( CWType : TValueType ) : iovalue.TValueType;
BEGIN
   CASE CWType OF
   | vtBoolean :
      RETURN iovalue.vtBoolean;
   | vtShortCard :
      RETURN iovalue.vtInteger;
   | vtCardinal :
      RETURN iovalue.vtInteger;
   | vtLongCard :
      RETURN iovalue.vtLong;
   | vtShortInt :
      RETURN iovalue.vtInteger;
   | vtInteger :
      RETURN iovalue.vtInteger;
   | vtLongInt :
      RETURN iovalue.vtInteger;
   | vtLongReal :
      RETURN iovalue.vtFloat;
   | vtPString256 :
      RETURN iovalue.vtString;
   | vtDriverString :
      RETURN iovalue.vtString;
   END; // CASE
   RETURN iovalue.vtUnknown;
END CWTypeToIOType;

(*================================================================================*)

PROCEDURE AssignDrvValueStringMW( VAR DrvValue : TValue; DrvValueUFlag, TrimFlag : BOOLEAN; l : CARDINAL; s : PWCHAR ): BOOLEAN;
VAR
   I32 : INT32;
BEGIN
   IF DrvValue.Type = vtBoolean THEN
      IF l = 0 THEN
         DrvValue.ValBoolean := FALSE;
      ELSIF ( s^ = L"1" ) OR ( s^ = L"t" ) OR ( s^ = L"T" ) THEN
         DrvValue.ValBoolean := TRUE;
      ELSIF ( s^ = L"0" ) OR ( s^ = L"f" ) OR ( s^ = L"F" ) THEN
         DrvValue.ValBoolean := FALSE;
      ELSIF EQUALS( OA( l-1, s ), kwTRUE ) OR EQUALS( OA( l-1, s ), L"TRUE" ) THEN
         DrvValue.ValBoolean := TRUE;
      ELSE
         DrvValue.ValBoolean := FALSE;
      END;

   ELSIF DrvValue.Type = vtPString256 THEN
      IF l = 0 THEN
         IF DrvValue.ValPString256A <> NIL THEN
            IF DrvValueUFlag THEN
               DrvValue.ValPString256A^[0] := 0C;
            ELSE
               DrvValue.ValPString256W^[0] := 0W;
            END;
         END;
      ELSE
         IF DrvValue.ValPString256A = NIL THEN
            NEW( DrvValue.ValPString256W ); // create bigger one with reserve for ANSI characters
         END;
         IF DrvValueUFlag THEN
            ASSIGN( DrvValue.ValPString256W^, OA( l-1, s ));
         ELSE
            Strings.ToA( OA( l-1, s ), 0, OUT DrvValue.ValPString256A^ );
         END;
      END;
      RETURN TRUE;

   ELSIF DrvValue.Type = vtDriverString THEN
      IF l = 0 THEN
         DrvValue.ValDriverStringCharLength := 0;
      ELSIF ( l > DrvValue.ValDriverStringCharLength ) AND NOT TrimFlag THEN
         DrvValue.ValDriverStringCharLength := l;
         DrvValue.ValDriverStringAddress := NIL;
         RETURN FALSE;
      ELSIF DrvValueUFlag THEN
         DrvValue.ValDriverStringCharLength := l;
         Strings.MoveW( s, DrvValue.ValDriverStringAddress, l );
      ELSE
         DrvValue.ValDriverStringCharLength := l;
         Strings.ToA( OA( l-1, s ), 0, OUT OA( l, PCHAR( DrvValue.ValDriverStringAddress )));
      END;

   ELSIF DrvValue.Type = vtLongReal THEN
      IF l = 0 THEN
         DrvValue.ValLongReal := 0.0;
      ELSIF NOT Strings.ToLONGREALW( OA( l-1, s ), OUT DrvValue.ValLongReal ) THEN
         DrvValue.ValLongReal := 0.0;
      END;
      
   ELSIF l = 0 THEN
      DrvValue.ValLongCard := 0;

   ELSE
      IF NOT Strings.ToCARD32W( OA( l-1, s ), 10, OUT I32 ) THEN
         I32 := 0;
      END;
      CASE DrvValue.Type OF
      | vtShortCard : DrvValue.ValShortCard := CARD8( I32 );
      | vtCardinal :  DrvValue.ValCardinal  := CARD16( I32 );
      | vtLongCard :  DrvValue.ValLongCard  := CARD32( I32 );
      | vtShortInt :  DrvValue.ValShortInt  := INT8( I32 );
      | vtInteger :   DrvValue.ValInteger   := INT16( I32 );
      | vtLongInt :   DrvValue.ValLongInt   := INT32( I32 );
      END; // CASE

   END; // IF
   RETURN TRUE;
END AssignDrvValueStringMW;

(*--------------------------------------------------------------------------------*)

PROCEDURE AssignDrvValueStringW( VAR DrvValue : TValue; DrvValueUFlag, TrimFlag : BOOLEAN; s : ARRAY OF WCHAR ): BOOLEAN;
BEGIN
   RETURN AssignDrvValueStringMW( DrvValue, DrvValueUFlag, TrimFlag, LENGTH( s ), ADR( s ));
END AssignDrvValueStringW;

(*--------------------------------------------------------------------------------*)

PROCEDURE AssignDrvValueCStringW( REF DrvValue : TValue; DrvValueUFlag, TrimFlag : BOOLEAN; CONST CS : StringsO.CString ): BOOLEAN;
BEGIN
   RETURN AssignDrvValueStringMW( DrvValue, DrvValueUFlag, TrimFlag, CS.Length, PWCHAR( CS.rawData ));
END AssignDrvValueCStringW;

(*================================================================================*)

PROCEDURE SetValuePString256StringW( VAR Value : TValue; ValueUFlag : BOOLEAN; s : ARRAY OF WCHAR );
BEGIN
  ASSERT( Value.Type = vtPString256 );
  IF s[0] = 0W THEN
    DISPOSE( Value.ValPString256W ); // ValPString256A shares place
  ELSE
    IF Value.ValPString256W = NIL THEN
      NEW( Value.ValPString256W ); // allocate WCHARs even if I can be A string. Simplify...
    END;
    IF ValueUFlag THEN
      ASSIGN( OA( 255, Value.ValPString256W ), s );
    ELSE
      Strings.ToA( s, 0, OUT OA( 255, Value.ValPString256A ));
    END;
  END;
END SetValuePString256StringW;

(*--------------------------------------------------------------------------------*)

PROCEDURE AssignValueBoolean( VAR Value : TValue; ValueUFlag, Saturate : BOOLEAN; v : BOOLEAN );
BEGIN
  IF v THEN
    CASE Value.Type OF
    | vtBoolean    : Value.ValBoolean   := TRUE;
    | vtShortCard  : Value.ValShortCard := 1;
    | vtCardinal   : Value.ValCardinal  := 1;
    | vtLongCard   : Value.ValLongCard  := 1;
    | vtShortInt   : Value.ValShortInt  := 1;
    | vtInteger    : Value.ValInteger   := 1;
    | vtLongInt    : Value.ValLongInt   := 1;
    | vtLongReal   : Value.ValLongReal  := 1.0;
    | vtPString256 : SetValuePString256StringW( Value, ValueUFlag, kwTRUE );
    | vtDriverString
                   : AssignDrvValueStringW( Value, ValueUFlag, FALSE, kwTRUE );
    END;
  ELSE
    CASE Value.Type OF
    | vtBoolean    : Value.ValBoolean   := FALSE;
    | vtShortCard  : Value.ValShortCard := 0;
    | vtCardinal   : Value.ValCardinal  := 0;
    | vtLongCard   : Value.ValLongCard  := 0;
    | vtShortInt   : Value.ValShortInt  := 0;
    | vtInteger    : Value.ValInteger   := 0;
    | vtLongInt    : Value.ValLongInt   := 0;
    | vtLongReal   : Value.ValLongReal  := 0.0;
    | vtPString256 : SetValuePString256StringW( Value, ValueUFlag, kwFALSE );
    | vtDriverString
                   : AssignDrvValueStringW( Value, ValueUFlag, FALSE, kwFALSE );
    END;
  END;
END AssignValueBoolean;

(*--------------------------------------------------------------------------------*)

PROCEDURE AssignValueCard8( VAR Value : TValue; ValueUFlag, Saturate : BOOLEAN; v : CARD8 );
VAR
  n : ARRAY [0..31] OF TCHAR;
BEGIN
  CASE Value.Type OF
  | vtBoolean    : Value.ValBoolean   := v <> 0;
  | vtShortCard  : Value.ValShortCard := v;
  | vtCardinal   : Value.ValCardinal  := CARD16( v );
  | vtLongCard   : Value.ValLongCard  := CARD32( v );
  | vtShortInt   : IF NOT Saturate THEN
                     Value.ValShortInt := INT8( v );
                   ELSIF v > MAX( INT8 ) THEN
                     Value.ValShortInt := MAX( INT8 );
                   ELSE
                     Value.ValShortInt := INT8( v );
                   END;
  | vtInteger    : Value.ValInteger   := INT16( v );
  | vtLongInt    : Value.ValLongInt   := INT32( v );
  | vtLongReal   : Value.ValLongReal  := LONGREAL( v );
  | vtPString256 : Strings.FromCARD32W( CARDINAL( v ), 10, OUT n );
                   SetValuePString256StringW( Value, ValueUFlag, n );
  | vtDriverString
                 : Strings.FromCARD32W( CARDINAL( v ), 10, OUT n );
                   AssignDrvValueStringW( Value, ValueUFlag, FALSE, n );
  END;
END AssignValueCard8;

(*--------------------------------------------------------------------------------*)

PROCEDURE AssignValueCard32( VAR Value : TValue; ValueUFlag, Saturate : BOOLEAN; v : CARD32 );
VAR
  n : ARRAY [0..31] OF TCHAR;
BEGIN
  CASE Value.Type OF
  | vtBoolean    : Value.ValBoolean := v <> 0;
  | vtShortCard  : IF NOT Saturate THEN
                     Value.ValShortCard := CARD8( v );
                   ELSIF v > MAX( CARD8 ) THEN
                     Value.ValShortCard := MAX( CARD8 );
                   ELSE
                     Value.ValShortCard := CARD8( v );
                   END;
  | vtCardinal   : IF NOT Saturate THEN
                     Value.ValCardinal := CARD16( v );
                   ELSIF v > MAX( CARD16 ) THEN
                     Value.ValCardinal := MAX( CARD16 );
                   ELSE
                     Value.ValCardinal := CARD16( v );
                   END;
  | vtLongCard   : Value.ValLongCard := v;
  | vtShortInt   : IF NOT Saturate THEN
                     Value.ValShortInt := INT8( v );
                   ELSIF v > MAX( INT8 ) THEN
                     Value.ValShortInt := MAX( INT8 );
                   ELSE
                     Value.ValShortInt := INT8( v );
                   END;
  | vtInteger    : IF NOT Saturate THEN
                     Value.ValInteger := INT16( v );
                   ELSIF v > MAX( INT16 ) THEN
                     Value.ValInteger := MAX( INT16 );
                   ELSE
                     Value.ValInteger := INT16( v );
                   END;
  | vtLongInt    : IF NOT Saturate THEN
                     Value.ValLongInt := INT32( v );
                   ELSIF v > MAX( INT32 ) THEN
                     Value.ValLongInt := MAX( INT32 );
                   ELSE
                     Value.ValLongInt := INT32( v );
                   END;
  | vtLongReal   : Value.ValLongReal := LONGREAL( v );
  | vtPString256 : Strings.FromCARD32W( CARDINAL( v ), 10, OUT n );
                   SetValuePString256StringW( Value, ValueUFlag, n );
  | vtDriverString
                 : Strings.FromCARD32W( CARDINAL( v ), 10, OUT n );
                   AssignDrvValueStringW( Value, ValueUFlag, FALSE, n );
  ELSE
    ASSERT( FALSE );
  END;
END AssignValueCard32;

(*--------------------------------------------------------------------------------*)

PROCEDURE AssignValueInt8( VAR Value : TValue; ValueUFlag, Saturate : BOOLEAN; v : INT8 );
VAR
  n : ARRAY [0..31] OF TCHAR;
BEGIN
  CASE Value.Type OF
  | vtBoolean    : Value.ValBoolean := v <> 0;
  | vtShortCard  : IF NOT Saturate THEN
                     Value.ValShortCard := CARD8( v );
                   ELSIF v < 0 THEN
                     Value.ValShortCard := 0;
                   ELSE
                     Value.ValShortCard := CARD8( v );
                   END;
  | vtCardinal   : IF NOT Saturate THEN
                     Value.ValCardinal := CARD16( v );
                   ELSIF v < 0 THEN
                     Value.ValCardinal := 0;
                   ELSE
                     Value.ValCardinal := CARD16( v );
                   END;
  | vtLongCard   : IF NOT Saturate THEN
                     Value.ValLongCard := CARD32( v );
                   ELSIF v < 0 THEN
                     Value.ValLongCard := 0;
                   ELSE
                     Value.ValLongCard := CARD32( v );
                   END;
  | vtShortInt   : Value.ValShortInt := v;
  | vtInteger    : Value.ValInteger := INT16( v );
  | vtLongInt    : Value.ValLongInt := INT32( v );
  | vtLongReal   : Value.ValLongReal := LONGREAL( v );
  | vtPString256 : Strings.FromINT32W( INTEGER( v ), 10, OUT n );
                   SetValuePString256StringW( Value, ValueUFlag, n );
  | vtDriverString
                 : Strings.FromINT32W( INTEGER( v ), 10, OUT n );
                   AssignDrvValueStringW( Value, ValueUFlag, FALSE, n );
  END;
END AssignValueInt8;

(*--------------------------------------------------------------------------------*)

PROCEDURE AssignValueInt32( VAR Value : TValue; ValueUFlag, Saturate : BOOLEAN; v : INT32 );
VAR
  n : ARRAY [0..31] OF TCHAR;
BEGIN
  CASE Value.Type OF
  | vtBoolean    : Value.ValBoolean := v <> 0;
  | vtShortCard  : IF NOT Saturate THEN
                     Value.ValShortCard := CARD8( v );
                   ELSIF v < 0 THEN
                     Value.ValShortCard := 0;
                   ELSIF v > MAX( CARD8 ) THEN
                     Value.ValShortCard := MAX( CARD8 );
                   ELSE
                     Value.ValShortCard := CARD8( v );
                   END;
  | vtCardinal   : IF NOT Saturate THEN
                     Value.ValCardinal := CARD16( v );
                   ELSIF v < 0 THEN
                     Value.ValCardinal := 0;
                   ELSIF v > MAX( CARD16 ) THEN
                     Value.ValCardinal := MAX( CARD16 );
                   ELSE
                     Value.ValCardinal := CARD16( v );
                   END;
  | vtLongCard   : IF NOT Saturate THEN
                     Value.ValLongCard := CARD32( v );
                   ELSIF v < 0 THEN
                     Value.ValLongCard := 0;
                   ELSE
                     Value.ValLongCard := CARD32( v );
                   END;
  | vtShortInt   : IF NOT Saturate THEN
                     Value.ValShortInt := INT8( v );
                   ELSIF v < MIN( INT8 ) THEN
                     Value.ValShortInt := MIN( INT8 );
                   ELSIF v > MAX( INT8 ) THEN
                     Value.ValShortInt := MAX( INT8 );
                   ELSE
                     Value.ValShortInt := INT8( v );
                   END;
  | vtInteger    : IF NOT Saturate THEN
                     Value.ValInteger := INT16( v );
                   ELSIF v < MIN( INT16 ) THEN
                     Value.ValInteger := MIN( INT16 );
                   ELSIF v > MAX( INT16 ) THEN
                     Value.ValInteger := MAX( INT16 );
                   ELSE
                     Value.ValInteger := INT16( v );
                   END;
  | vtLongInt    : Value.ValLongInt := INT32( v );
  | vtLongReal   : Value.ValLongReal := LONGREAL( v );
  | vtPString256 : Strings.FromINT32W( INTEGER( v ), 10, OUT n );
                   SetValuePString256StringW( Value, ValueUFlag, n );
  | vtDriverString
                 : Strings.FromINT32W( INTEGER( v ), 10, OUT n );
                   AssignDrvValueStringW( Value, ValueUFlag, FALSE, n );
  END;
END AssignValueInt32;

(*--------------------------------------------------------------------------------*)

PROCEDURE AssignValueLongReal( VAR Value : TValue; ValueUFlag, Saturate : BOOLEAN; v : LONGREAL );
VAR
  n : ARRAY [0..31] OF TCHAR;
BEGIN
  CASE Value.Type OF
  | vtBoolean    : Value.ValBoolean   := v <> 0.0;
  | vtShortCard  : IF NOT Saturate THEN
                     Value.ValShortCard := CARD8( v );
                   ELSIF v < 0.0 THEN
                     Value.ValShortCard := 0;
                   ELSIF v > LONGREAL( MAX( CARD8 )) THEN
                     Value.ValShortCard := MAX( CARD8 );
                   ELSE
                     Value.ValShortCard := CARD8( v );
                   END;
  | vtCardinal   : IF NOT Saturate THEN
                     Value.ValCardinal := CARD16( v );
                   ELSIF v < 0.0 THEN
                     Value.ValCardinal := 0;
                   ELSIF v > LONGREAL( MAX( CARD16 )) THEN
                     Value.ValCardinal := MAX( CARD16 );
                   ELSE
                     Value.ValCardinal := CARD16( v );
                   END;
  | vtLongCard   : IF NOT Saturate THEN
                     Value.ValLongCard := CARD32( v );
                   ELSIF v < 0.0 THEN
                     Value.ValLongCard := 0;
                   ELSIF v > LONGREAL( MAX( CARD32 )) THEN
                     Value.ValLongCard := MAX( CARD32 );
                   ELSE
                     Value.ValLongCard := CARD32( v );
                   END;
  | vtShortInt   : IF NOT Saturate THEN
                     Value.ValShortInt := INT8( v );
                   ELSIF v < LONGREAL( MIN( INT8 )) THEN
                     Value.ValShortInt := MIN( INT8 );
                   ELSIF v > LONGREAL( MAX( INT8 )) THEN
                     Value.ValShortInt := MAX( INT8 );
                   ELSE
                     Value.ValShortInt := INT8( v );
                   END;
  | vtInteger    : IF NOT Saturate THEN
                     Value.ValInteger := INT16( v );
                   ELSIF v < LONGREAL( MIN( INT16 )) THEN
                     Value.ValInteger := MIN( INT16 );
                   ELSIF v > LONGREAL( MAX( INT16 )) THEN
                     Value.ValInteger := MAX( INT16 );
                   ELSE
                     Value.ValInteger := INT16( v );
                   END;
  | vtLongInt    : IF NOT Saturate THEN
                     Value.ValLongInt := INT32( v );
                   ELSIF v < LONGREAL( MIN( INT32 )) THEN
                     Value.ValLongInt := MIN( INT32 );
                   ELSIF v > LONGREAL( MAX( INT32 )) THEN
                     Value.ValLongInt := MAX( INT32 );
                   ELSE
                     Value.ValLongInt := INT32( v );
                   END;
  | vtLongReal   : Value.ValLongReal  := v;
  | vtPString256 : Strings.FromLONGREALW( v, FALSE, OUT n );
                   SetValuePString256StringW( Value, ValueUFlag, n );
  | vtDriverString
                 : Strings.FromLONGREALW( v, FALSE, OUT n );
                   AssignDrvValueStringW( Value, ValueUFlag, FALSE, n );
  ELSE
    ASSERT( FALSE );
  END;
END AssignValueLongReal;

(*--------------------------------------------------------------------------------*)

PROCEDURE DrvValueToCStringW( CONST DrvValue : TValue; DrvValueUFlag : BOOLEAN; OUT CS : StringsO.CString );
BEGIN
   CASE DrvValue.Type OF
   | vtBoolean :
      IF DrvValue.ValBoolean THEN
         CS.FromOA( kwTRUE );
      ELSE
         CS.FromOA( kwFALSE );
      END;

   | vtShortCard :
      CS.FromCARD32( CARD32( DrvValue.ValShortCard ), 10 );

   | vtCardinal :
      CS.FromCARD32( CARD32( DrvValue.ValCardinal ), 10 );

   | vtLongCard :
      CS.FromCARD32( DrvValue.ValLongCard, 10 );

   | vtShortInt :
      CS.FromINT32( INT32( DrvValue.ValShortInt ), 10 );

   | vtInteger :
      CS.FromINT32( INT32( DrvValue.ValInteger ), 10 );

   | vtLongInt :
      CS.FromINT32( DrvValue.ValLongInt, 10 );

   | vtLongReal :
      CS.FromLONGREAL( DrvValue.ValLongReal, FALSE );

   | vtPString256 :
      IF DrvValue.ValPString256W = NIL THEN
         CS.Clear();
      ELSIF DrvValueUFlag THEN
         CS.FromOA( OA( 255, DrvValue.ValPString256W ));
      ELSE
         CS.FromOAA( 0, OA( 255, DrvValue.ValPString256A ));
      END;

   | vtDriverString :
      IF DrvValue.ValDriverStringCharLength = 0 THEN
         CS.Clear();
      ELSIF DrvValueUFlag THEN
         CS.FromOA( OA( DrvValue.ValDriverStringCharLength-1, PWCHAR( DrvValue.ValDriverStringAddress )));
      ELSE
         CS.FromOAA( 0, OA( DrvValue.ValDriverStringCharLength-1, PCHAR( DrvValue.ValDriverStringAddress )));
      END;

   ELSE
      CS.Clear();
   END;
END DrvValueToCStringW;

(*================================================================================*)

PROCEDURE IOValueToCWValue( CONST IOValue : iovalue.Value; CWValueUFlag, TrimFlag : BOOLEAN; REF CWValue : TValue ) : BOOLEAN;
BEGIN
   CASE IOValue.Type OF
   | iovalue.vtBoolean :
      AssignValueBoolean( CWValue, CWValueUFlag, TRUE, IOValue.Boolean );

   | iovalue.vtTristate :
      AssignValueInt8( CWValue, CWValueUFlag, TRUE, INT8( IOValue.Tristate ));

   | iovalue.vtInteger :
      AssignValueInt32( CWValue, CWValueUFlag, TRUE, IOValue.Integer );

   | iovalue.vtLong :
      AssignValueLongReal( CWValue, CWValueUFlag, TRUE, LONGREAL( IOValue.Long ));

   | iovalue.vtFloat :
      AssignValueLongReal( CWValue, CWValueUFlag, TRUE, IOValue.Float );

   | iovalue.vtString :
      RETURN AssignDrvValueCStringW( REF CWValue, CWValueUFlag, TrimFlag, IOValue.String );

   | iovalue.vtDate :
      AssignValueLongReal( CWValue, CWValueUFlag, TRUE, time.ToSJD( IOValue.Date ));

   ELSE
      RETURN AssignDrvValueStringW( REF CWValue, CWValueUFlag, TrimFlag, L"" );

   END; // CASE
   RETURN TRUE;
END IOValueToCWValue;

(*--------------------------------------------------------------------------------*)

PROCEDURE CWValueToIOValue( CONST CWValue : TValue; DrvValueUFlag : BOOLEAN; REF IOValue : iovalue.Value );
BEGIN
   CASE CWValue.Type OF
   | vtBoolean :
      IOValue.Boolean := CWValue.ValBoolean;

   | vtShortCard :
      IOValue.Integer := INT32( CWValue.ValShortCard );

   | vtCardinal :
      IOValue.Integer := INT32( CWValue.ValCardinal );

   | vtLongCard :
      IOValue.Integer := INT32( CWValue.ValLongCard );

   | vtShortInt :
      IOValue.Integer := INT32( CWValue.ValShortInt );

   | vtInteger :
      IOValue.Integer := INT32( CWValue.ValInteger );

   | vtLongInt :
      IOValue.Integer := CWValue.ValLongInt;

   | vtLongReal :
      IOValue.Float := CWValue.ValLongReal;
   
   | vtPString256, vtDriverString :
      DrvValueToCStringW( CWValue, DrvValueUFlag, OUT IOValue.String );

   END;
END CWValueToIOValue;

(*================================================================================*)

END drv_def.