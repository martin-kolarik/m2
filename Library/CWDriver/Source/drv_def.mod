IMPLEMENTATION MODULE drv_def;

////////////////////////////////////////////////////////////////
// Control Web Administrator                                  //
//    basic CW stuff, used in Remote/Local client and cw_main //
//                              (C) 2001 Moravian Instruments //
////////////////////////////////////////////////////////////////

(*# call( o_a_copy => off ) *)
(*# warn ( 4554 => off ) *) // check >> operator precedence

FROM Storage IMPORT
  ALLOCATE, DEALLOCATE;

FROM Strings IMPORT
  LowerizeW;

IMPORT
  drv_str,
  Storage,
  time;

//-----------------------------------------------------------------------------

CONST
  kwFALSE = L'false';
  kwTRUE = L'true';

//-----------------------------------------------------------------------------

PROCEDURE InitValue( VAR Value : TValue );
// sets vtNothing, does not check dynamic string
// used to initialize new values
BEGIN
  Value.Type := vtNothing;
END InitValue;

//--------------------------------------------------------------

// sets vtNothing but checks for possible dynamic string and frees it
PROCEDURE DoneValue( VAR Value : TValue );
BEGIN
  IF ( Value.Type = vtPString256 ) AND ( Value.ValPString256W <> NIL ) THEN
    DISPOSE( Value.ValPString256W );
  ELSIF ( Value.Type = vtDString ) AND ( Value.ValDStringW <> NIL ) THEN
    DISPOSE( Value.ValDStringW );
  ELSIF ( Value.Type = vtBuffer ) AND ( Value.PBuffer <> NIL ) THEN
    DISPOSE( Value.PBuffer );
  ELSIF ( Value.Type = vtData ) AND ( Value.ValPData <> NIL ) THEN
    DISPOSE( Value.ValPData );
  END;
  Value.Type := vtNothing;
END DoneValue;

//--------------------------------------------------------------

PROCEDURE ValueDataLength( Type : TValueType ) : CARDINAL;
BEGIN
  CASE Type OF
  | vtNothing, vtError, vtUnknown :
    RETURN 0;
  | vtBoolean, vtShortInt, vtShortCard :
    RETURN 1;
  | vtCardinal, vtInteger :
    RETURN 4;
  | vtLongCard, vtLongInt, vtPString256, vtDString :
    RETURN 4;
  | vtLongReal :
    RETURN 8;
  ELSE
    RETURN 0;
  END;
END ValueDataLength;

//--------------------------------------------------------------

PROCEDURE IsValidValue( CONST Value : TValue ) : BOOLEAN;// all types except vtError (including vtUnknown) // ( CONST Value : TValue ) : BOOLEAN;
BEGIN
  CASE Value.Type OF
  | vtBoolean,
    vtShortCard,
    vtCardinal,
    vtLongCard,
    vtShortInt,
    vtInteger,
    vtLongInt,
    vtLongReal,
    vtPString256,
    vtDString,
    vtUnknown :
    RETURN TRUE;
  ELSE
    RETURN FALSE;
  END;
END IsValidValue;

//--------------------------------------------------------------

PROCEDURE IsKnownValue( CONST Value : TValue ) : BOOLEAN;// all types except both vtError and vtUnknown // ( CONST Value : TValue ) : BOOLEAN;
BEGIN
  CASE Value.Type OF
  | vtBoolean,
    vtShortCard,
    vtCardinal,
    vtLongCard,
    vtShortInt,
    vtInteger,
    vtLongInt,
    vtLongReal,
    vtPString256,
    vtDString :
    RETURN TRUE;
  ELSE
    RETURN FALSE;
  END;
END IsKnownValue;

//--------------------------------------------------------------

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
   | iovalue.vtData :
      RETURN vtData;
   END;
   RETURN vtUnknown;
END IOTypeToCWType;

//==============================================================

PROCEDURE SetValuePString256StringW( VAR Value : TValue; ValueUFlag : BOOLEAN; s : ARRAY OF WCHAR );
BEGIN
  IF (Value.Type = vtDString) AND (Value.ValDStringW <> NIL) THEN
    DISPOSE( Value.ValDStringW );
  ELSIF (Value.Type = vtData) AND (Value.ValPData <> NIL) THEN
    DISPOSE( Value.ValPData );
  END;
  IF Value.Type <> vtPString256 THEN
    Value.Type := vtPString256;
    Value.ValPString256W := NIL; // ValPString256A shares place
  END;
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

//--------------------------------------------------------------

PROCEDURE SetValueStringW( VAR Value : TValue; ValueUFlag : BOOLEAN; s : ARRAY OF WCHAR );
VAR
  SW : drv_str.TPDStringW := NIL;
BEGIN
  IF (Value.Type = vtPString256) AND (Value.ValPString256W <> NIL) THEN
    DISPOSE( Value.ValPString256W );
  ELSIF (Value.Type = vtData) AND (Value.ValPData <> NIL) THEN
    DISPOSE( Value.ValPData );
  END;
  IF Value.Type <> vtDString THEN
    Value.Type := vtDString;
    Value.ValDStringW := NIL; // ValDStringA shares place
  END;
  IF s[0] = 0W THEN
    DISPOSE( Value.ValDStringW ); // ValDStringA shares place
  ELSE
    drv_str.CopyStrToDStrW( SW, s );
    IF ValueUFlag THEN
      Value.ValDStringW := SW;
    ELSE
      #if #not UNICODE #then
        ASSERT( FALSE );
      #endif
      drv_str.CreateAFromTW( Value.ValDStringA, SW );
      DISPOSE( SW );
    END;
  END;
END SetValueStringW;

//--------------------------------------------------------------

PROCEDURE SetValueDStringW( VAR Value : TValue; ValueUFlag : BOOLEAN; S : drv_str.TPDStringW );
BEGIN
  IF (Value.Type = vtPString256) AND (Value.ValPString256W <> NIL) THEN
    DISPOSE( Value.ValPString256W );
  ELSIF ( Value.Type = vtData ) AND ( Value.ValPData <> NIL ) THEN
    DISPOSE( Value.ValPData );
  END;
  IF S = NIL THEN
    IF Value.Type <> vtDString THEN
      Value.Type := vtDString;
      Value.ValDStringW := NIL;
    ELSIF Value.ValDStringW <> NIL THEN
      DISPOSE( Value.ValDStringW ); // ValDStringA shares place
    END;
    RETURN;
  END;
  IF Value.Type <> vtDString THEN
    Value.Type := vtDString;
    IF ValueUFlag THEN
      drv_str.AllocDStrW( Value.ValDStringW, S^.Len + 1 );
    ELSE
      drv_str.AllocDStrA( Value.ValDStringA, S^.Len + 1 );
    END;
  END;
  IF ValueUFlag THEN
    drv_str.CopyDStrToDStrW( Value.ValDStringW, S );
  ELSE
    #if #not UNICODE #then
      ASSERT( FALSE );
    #endif
    drv_str.CreateAFromTW( Value.ValDStringA, S );
  END;
END SetValueDStringW;

//==============================================================
// helpers preserving value's type

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
    | vtDString    : SetValueStringW( Value, ValueUFlag, kwTRUE );
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
    | vtDString    : SetValueStringW( Value, ValueUFlag, kwFALSE );
    | vtDriverString
                   : AssignDrvValueStringW( Value, ValueUFlag, FALSE, kwFALSE );
    END;
  END;
END AssignValueBoolean;

//--------------------------------------------------------------

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
  | vtDString    : Strings.FromCARD32W( CARDINAL( v ), 10, OUT n );
                   SetValueStringW( Value, ValueUFlag, n );
  | vtDriverString
                 : Strings.FromCARD32W( CARDINAL( v ), 10, OUT n );
                   AssignDrvValueStringW( Value, ValueUFlag, FALSE, n );
  END;
END AssignValueCard8;

//--------------------------------------------------------------

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
  | vtDString    : Strings.FromCARD32W( CARDINAL( v ), 10, OUT n );
                   SetValueStringW( Value, ValueUFlag, n );
  | vtDriverString
                 : Strings.FromCARD32W( CARDINAL( v ), 10, OUT n );
                   AssignDrvValueStringW( Value, ValueUFlag, FALSE, n );
  ELSE
    ASSERT( FALSE );
  END;
END AssignValueCard32;

//--------------------------------------------------------------

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
  | vtDString    : Strings.FromINT32W( INTEGER( v ), 10, OUT n );
                   SetValueStringW( Value, ValueUFlag, n );
  | vtDriverString
                 : Strings.FromINT32W( INTEGER( v ), 10, OUT n );
                   AssignDrvValueStringW( Value, ValueUFlag, FALSE, n );
  END;
END AssignValueInt8;

//--------------------------------------------------------------

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
  | vtDString    : Strings.FromINT32W( INTEGER( v ), 10, OUT n );
                   SetValueStringW( Value, ValueUFlag, n );
  | vtDriverString
                 : Strings.FromINT32W( INTEGER( v ), 10, OUT n );
                   AssignDrvValueStringW( Value, ValueUFlag, FALSE, n );
  END;
END AssignValueInt32;

//--------------------------------------------------------------

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
  | vtDString    : Strings.FromLONGREALW( v, FALSE, OUT n );
                   SetValueStringW( Value, ValueUFlag, n );
  | vtDriverString
                 : Strings.FromLONGREALW( v, FALSE, OUT n );
                   AssignDrvValueStringW( Value, ValueUFlag, FALSE, n );
  ELSE
    ASSERT( FALSE );
  END;
END AssignValueLongReal;

//--------------------------------------------------------------

PROCEDURE AssignValueStringW( VAR Value : TValue; ValueUFlag, Saturate : BOOLEAN; sw : ARRAY OF WCHAR );
VAR
  lr : LONGREAL;
  lsw : ARRAY [0..7] OF WCHAR;
BEGIN
  CASE Value.Type OF
  | vtBoolean :
    ASSIGN( lsw, sw );
    LOW( lsw );
    IF EQUALS( lsw, kwFALSE ) THEN
      Value.ValBoolean := FALSE;
    ELSIF EQUALS( lsw, kwTRUE ) THEN
      Value.ValBoolean := TRUE;
    ELSIF EQUALS( lsw, L'0' ) THEN
      Value.ValBoolean := FALSE;
    ELSIF EQUALS( lsw, L'1' ) THEN
      Value.ValBoolean := TRUE;
    ELSE
      Value.ValBoolean := TRUE;
    END;
  | vtPString256 :
    SetValuePString256StringW( Value, ValueUFlag, sw );
  | vtDString :
    SetValueStringW( Value, ValueUFlag, sw );
  | vtDriverString :
    AssignDrvValueStringW( Value, ValueUFlag, FALSE, sw );
  ELSE
    IF Strings.ToLONGREALW( sw, OUT lr ) THEN
      AssignValueLongReal( Value, ValueUFlag, Saturate, lr );
    ELSE
      AssignValueLongReal( Value, ValueUFlag, Saturate, 0.0 );
    END;
  END;
END AssignValueStringW;

PROCEDURE AssignValueCStringW( VAR Value : TValue; ValueUFlag, Saturate : BOOLEAN; CONST CS : StringsO.CString );
VAR
  lsw : ARRAY [0..7] OF WCHAR;
BEGIN
  CASE Value.Type OF
  | vtBoolean :
    CS.ToOA( OUT lsw );
    LOW( lsw );
    IF EQUALS( lsw, kwFALSE ) THEN
      Value.ValBoolean := FALSE;
    ELSIF EQUALS( lsw, kwTRUE ) THEN
      Value.ValBoolean := TRUE;
    ELSIF EQUALS( lsw, L'0' ) THEN
      Value.ValBoolean := FALSE;
    ELSIF EQUALS( lsw, L'1' ) THEN
      Value.ValBoolean := TRUE;
    ELSE
      Value.ValBoolean := TRUE;
    END;
  | vtPString256 :
    SetValuePString256StringW( Value, ValueUFlag, OA( CS.Length, CS.szData ));
  | vtDString :
    SetValueStringW( Value, ValueUFlag, OA( CS.Length, CS.szData ));
  | vtDriverString :
    AssignDrvValueCStringW( REF Value, ValueUFlag, FALSE, CS );
  ELSE
    TRY
      AssignValueLongReal( Value, ValueUFlag, Saturate, CS.ToLONGREAL() );
    CATCH : StringsO.CStringException DO
      AssignValueLongReal( Value, ValueUFlag, Saturate, 0.0 );
    END;
  END;
END AssignValueCStringW;

//==============================================================
// helpers converting value

PROCEDURE ValueToBoolean( CONST Value : TValue; ValueUFlag, Saturate : BOOLEAN ) : BOOLEAN;
LABEL
  String;
VAR
  lsw : ARRAY [0..31] OF WCHAR;
  n : ARRAY [0..31] OF TCHAR;
  r : LONGREAL;
BEGIN
  CASE Value.Type OF
  | vtBoolean    : RETURN Value.ValBoolean;
  | vtShortCard  : RETURN Value.ValShortCard <> 0;
  | vtCardinal   : RETURN Value.ValCardinal  <> 0;
  | vtLongCard   : RETURN Value.ValLongCard  <> 0;
  | vtShortInt   : RETURN Value.ValShortInt  <> 0;
  | vtInteger    : RETURN Value.ValInteger   <> 0;
  | vtLongInt    : RETURN Value.ValLongInt   <> 0;
  | vtLongReal   : RETURN Value.ValLongReal  <> 0.0;
  | vtPString256,
    vtDString    : ValueToStringW( Value, ValueUFlag, n );
    String:
                   lsw := n;
                   LOW( lsw );
                   IF EQUALS( n, kwTRUE ) THEN
                      RETURN TRUE;
                   ELSIF EQUALS( n, kwFALSE ) THEN
                      RETURN FALSE;
                   ELSE
                      Strings.ToLONGREALW( n, OUT r );
                      RETURN r <> 0.0;
                   END;
  | vtDriverString
                 : DrvValueToStringW( Value, ValueUFlag, n );
                   GOTO String;
  ELSE
    RETURN FALSE;
  END;
END ValueToBoolean;

//--------------------------------------------------------------

PROCEDURE ValueToCard8( CONST Value : TValue; ValueUFlag, Saturate : BOOLEAN ) : CARD8;
LABEL
  LLongReal;
VAR
  lr : LONGREAL;
  n : ARRAY [0..31] OF TCHAR;
BEGIN
  CASE Value.Type OF
  | vtBoolean    : IF Value.ValBoolean THEN RETURN 1; ELSE RETURN 0; END;
  | vtShortCard  : RETURN Value.ValShortCard;
  | vtCardinal   : IF NOT Saturate THEN
                     RETURN CARD8( Value.ValCardinal );
                   ELSIF Value.ValCardinal > MAX( CARD8 ) THEN
                     RETURN MAX( CARD8 );
                   ELSE
                     RETURN CARD8( Value.ValCardinal );
                   END;
  | vtLongCard   : IF NOT Saturate THEN
                     RETURN CARD8( Value.ValLongCard );
                   ELSIF Value.ValLongCard > MAX( CARD8 ) THEN
                     RETURN MAX( CARD8 );
                   ELSE
                     RETURN CARD8( Value.ValLongCard );
                   END;
  | vtShortInt   : IF NOT Saturate THEN
                     RETURN CARD8( Value.ValShortInt );
                   ELSIF Value.ValShortInt < 0 THEN
                     RETURN 0;
                   ELSE
                     RETURN CARD8( Value.ValShortInt );
                   END;
  | vtInteger    : IF NOT Saturate THEN
                     RETURN CARD8( Value.ValInteger );
                   ELSIF Value.ValInteger < 0 THEN
                     RETURN 0;
                   ELSIF Value.ValInteger > MAX( CARD8 ) THEN
                     RETURN MAX( CARD8 );
                   ELSE
                     RETURN CARD8( Value.ValInteger );
                   END;
  | vtLongInt    : IF NOT Saturate THEN
                     RETURN CARD8( Value.ValLongInt );
                   ELSIF Value.ValLongInt < 0 THEN
                     RETURN 0;
                   ELSIF Value.ValLongInt > MAX( CARD8 ) THEN
                     RETURN MAX( CARD8 );
                   ELSE
                     RETURN CARD8( Value.ValLongInt );
                   END;
  | vtLongReal  :  lr := Value.ValLongReal;
    LLongReal:     IF NOT Saturate THEN
                     RETURN CARD8( lr );
                   ELSIF lr < 0.0 THEN
                     RETURN 0;
                   ELSIF lr > LONGREAL( MAX( CARD8 )) THEN
                     RETURN MAX( CARD8 );
                   ELSE
                     RETURN CARD8( lr );
                   END;
  | vtPString256,
    vtDString :    ValueToStringW( Value, ValueUFlag, n );
                   Strings.ToLONGREALW( n, OUT lr );
                   GOTO LLongReal;
  | vtDriverString
                 : DrvValueToStringW( Value, ValueUFlag, n );
                   Strings.ToLONGREALW( n, OUT lr );
                   GOTO LLongReal;
  ELSE
    RETURN 0;
  END;
END ValueToCard8;

//--------------------------------------------------------------

PROCEDURE ValueToCard32( CONST Value : TValue; ValueUFlag, Saturate : BOOLEAN ) : CARD32;
LABEL
  LLongReal;
VAR
  lr : LONGREAL;
  n : ARRAY [0..31] OF TCHAR;
BEGIN
  CASE Value.Type OF
  | vtBoolean   : IF Value.ValBoolean THEN RETURN 1; ELSE RETURN 0; END;
  | vtShortCard : RETURN CARD32( Value.ValShortCard );
  | vtCardinal  : RETURN CARD32( Value.ValCardinal );
  | vtLongCard  : RETURN Value.ValLongCard;
  | vtShortInt  : IF NOT Saturate THEN
                    RETURN CARD32( Value.ValShortInt );
                  ELSIF Value.ValShortInt < 0 THEN
                    RETURN 0;
                  ELSE
                    RETURN CARD32( Value.ValShortInt );
                  END;
  | vtInteger   : IF NOT Saturate THEN
                    RETURN CARD32( Value.ValInteger );
                  ELSIF Value.ValInteger < 0 THEN
                    RETURN 0;
                  ELSE
                    RETURN CARD32( Value.ValInteger );
                  END;
  | vtLongInt   : IF NOT Saturate THEN
                    RETURN CARD32( Value.ValLongInt );
                  ELSIF Value.ValLongInt < 0 THEN
                    RETURN 0;
                  ELSE
                    RETURN CARD32( Value.ValLongInt );
                  END;
  | vtLongReal  : lr := Value.ValLongReal;
    LLongReal:    IF NOT Saturate THEN
                    RETURN CARD32( lr );
                  ELSIF lr < 0.0 THEN
                    RETURN 0;
                  ELSIF lr > LONGREAL( MAX( CARD32 )) THEN
                    RETURN MAX( CARD32 );
                  ELSE
                    RETURN CARD32( lr );
                  END;
  | vtPString256,
    vtDString :   ValueToStringW( Value, ValueUFlag, n );
                  Strings.ToLONGREALW( n, OUT lr );
                  GOTO LLongReal;
  | vtDriverString
                : DrvValueToStringW( Value, ValueUFlag, n );
                  Strings.ToLONGREALW( n, OUT lr );
                  GOTO LLongReal;
  ELSE
    RETURN 0;
  END;
END ValueToCard32;

//--------------------------------------------------------------

PROCEDURE ValueToInt8( CONST Value : TValue; ValueUFlag, Saturate : BOOLEAN ) : INT8;
LABEL
  LLongReal;
VAR
  lr : LONGREAL;
  n : ARRAY [0..31] OF TCHAR;
BEGIN
  CASE Value.Type OF
  | vtBoolean   : IF Value.ValBoolean THEN RETURN 1; ELSE RETURN 0; END;
  | vtShortCard : IF NOT Saturate THEN
                    RETURN INT8( Value.ValShortCard );
                  ELSIF Value.ValShortCard > MAX( INT8 ) THEN
                    RETURN MAX( INT8 );
                  ELSE
                    RETURN INT8( Value.ValShortCard );
                  END;
  | vtCardinal  : IF NOT Saturate THEN
                    RETURN INT8( Value.ValCardinal );
                  ELSIF Value.ValCardinal > MAX( INT8 ) THEN
                    RETURN MAX( INT8 );
                  ELSE
                    RETURN INT8( Value.ValCardinal );
                  END;
  | vtLongCard  : IF NOT Saturate THEN
                    RETURN INT8( Value.ValLongCard );
                  ELSIF Value.ValLongCard > MAX( INT8 ) THEN
                    RETURN MAX( INT8 );
                  ELSE
                    RETURN INT8( Value.ValLongCard );
                  END;
  | vtShortInt  : RETURN Value.ValShortInt;
  | vtInteger   : IF NOT Saturate THEN
                    RETURN INT8( Value.ValInteger );
                  ELSIF Value.ValInteger > MAX( INT8 ) THEN
                    RETURN MAX( INT8 );
                  ELSIF Value.ValInteger < MIN( INT8 ) THEN
                    RETURN MIN( INT8 );
                  ELSE
                    RETURN INT8( Value.ValInteger );
                  END;
  | vtLongInt   : IF NOT Saturate THEN
                    RETURN INT8( Value.ValLongInt );
                  ELSIF Value.ValLongInt > MAX( INT8 ) THEN
                    RETURN MAX( INT8 );
                  ELSIF Value.ValLongInt < MIN( INT8 ) THEN
                    RETURN MIN( INT8 );
                  ELSE
                    RETURN INT8( Value.ValLongInt );
                  END;
  | vtLongReal  : lr := Value.ValLongReal;
    LLongReal:    IF NOT Saturate THEN
                    RETURN INT8( lr );
                  ELSIF lr < LONGREAL( MIN( INT8 )) THEN
                    RETURN MIN( INT8 );
                  ELSIF lr > LONGREAL( MAX( INT8 )) THEN
                    RETURN MAX( INT8 );
                  ELSE
                    RETURN INT8( lr );
                  END;
  | vtPString256,
    vtDString :   ValueToStringW( Value, ValueUFlag, n );
                  Strings.ToLONGREALW( n, OUT lr );
                  GOTO LLongReal;
  | vtDriverString
                : DrvValueToStringW( Value, ValueUFlag, n );
                  Strings.ToLONGREALW( n, OUT lr );
                  GOTO LLongReal;
  ELSE
    RETURN 0;
  END;
END ValueToInt8;

//--------------------------------------------------------------

PROCEDURE ValueToInt32( CONST Value : TValue; ValueUFlag, Saturate : BOOLEAN ) : INT32;
LABEL
  LLongReal;
VAR
  lr : LONGREAL;
  n : ARRAY [0..31] OF TCHAR;
BEGIN
  CASE Value.Type OF
  | vtBoolean   : IF Value.ValBoolean THEN RETURN 1; ELSE RETURN 0; END;
  | vtShortCard : RETURN INT32( Value.ValShortCard );
  | vtCardinal  : RETURN INT32( Value.ValCardinal );
  | vtLongCard  : IF NOT Saturate THEN
                    RETURN INT32( Value.ValLongCard );
                  ELSIF Value.ValLongCard > MAX( INT32 ) THEN
                    RETURN MAX( INT32 );
                  ELSE
                    RETURN INT32( Value.ValLongCard );
                  END;
  | vtShortInt  : RETURN INT32( Value.ValShortInt );
  | vtInteger   : RETURN INT32( Value.ValInteger );
  | vtLongInt   : RETURN Value.ValLongInt;
  | vtLongReal  : lr := Value.ValLongReal;
    LLongReal:    IF NOT Saturate THEN
                    RETURN INT32( lr );
                  ELSIF lr < LONGREAL( MIN( INT32 )) THEN
                    RETURN MIN( INT32 );
                  ELSIF lr > LONGREAL( MAX( INT32 )) THEN
                    RETURN MAX( INT32 );
                  ELSE
                    RETURN INT32( lr );
                  END;
  | vtPString256,
    vtDString :   ValueToStringW( Value, ValueUFlag, n );
                  Strings.ToLONGREALW( n, OUT lr );
                  GOTO LLongReal;
  | vtDriverString
                : DrvValueToStringW( Value, ValueUFlag, n );
                  Strings.ToLONGREALW( n, OUT lr );
                  GOTO LLongReal;
  ELSE
    RETURN 0;
  END;
END ValueToInt32;

//--------------------------------------------------------------

PROCEDURE ValueToLongReal( CONST Value : TValue; ValueUFlag, Saturate : BOOLEAN ) : LONGREAL;
VAR
  lr : LONGREAL;
  n : ARRAY [0..31] OF TCHAR;
BEGIN
  CASE Value.Type OF
  | vtBoolean   : IF Value.ValBoolean THEN RETURN 1.0; ELSE RETURN 0.0; END;
  | vtShortCard : RETURN LONGREAL( Value.ValShortCard );
  | vtCardinal  : RETURN LONGREAL( Value.ValCardinal );
  | vtLongCard  : RETURN LONGREAL( Value.ValLongCard );
  | vtShortInt  : RETURN LONGREAL( Value.ValShortInt );
  | vtInteger   : RETURN LONGREAL( Value.ValInteger );
  | vtLongInt   : RETURN LONGREAL( Value.ValLongInt );
  | vtLongReal  : RETURN Value.ValLongReal;
  | vtPString256,
    vtDString :   ValueToStringW( Value, ValueUFlag, n );
                  Strings.ToLONGREALW( n, OUT lr );
                  RETURN lr;
  | vtDriverString
                : DrvValueToStringW( Value, ValueUFlag, n );
                  Strings.ToLONGREALW( n, OUT lr );
                  RETURN lr;
  ELSE
    RETURN 0.0;
  END;
END ValueToLongReal;

//--------------------------------------------------------------

PROCEDURE ValueToStringW( CONST Value : TValue; ValueUFlag : BOOLEAN; VAR sw : ARRAY OF WCHAR );
VAR
  SA : drv_str.TPDStringA;
  SW : drv_str.TPDStringW := NIL;
BEGIN
  CASE Value.Type OF
  | vtBoolean   : IF Value.ValBoolean THEN
                    ASSIGN( sw, kwTRUE );
                  ELSE
                    ASSIGN( sw, kwFALSE );
                  END;
  | vtShortCard : Strings.FromCARD32W( CARD32( Value.ValShortCard ), 10, OUT sw );
  | vtCardinal  : Strings.FromCARD32W( CARD32( Value.ValCardinal ), 10, OUT sw );
  | vtLongCard  : Strings.FromCARD32W( Value.ValLongCard, 10, OUT sw );
  | vtShortInt  : Strings.FromINT32W( INT32( Value.ValShortInt ), 10, OUT sw );
  | vtInteger   : Strings.FromINT32W( INT32( Value.ValInteger ), 10, OUT sw );
  | vtLongInt   : Strings.FromINT32W( Value.ValLongInt, 10, OUT sw );
  | vtLongReal  : Strings.FromLONGREALW( Value.ValLongReal, FALSE, OUT sw );
  | vtPString256: IF ValueUFlag THEN
                    ASSIGN( sw, OA( 255, Value.ValPString256W ));
                  ELSE
                    Strings.ToW( OA( 255, Value.ValPString256A ), 0, OUT sw );
                  END;
  | vtDString   : IF ValueUFlag THEN
                    drv_str.CopyDStrToStrW( sw, drv_str.TPDStringW( Value.ValDStringW ));
                  ELSE
                    #if #not UNICODE #then
                      ASSERT( FALSE );
                    #endif
                    SA := Value.ValDStringA;
                    drv_str.CreateTFromA( SW, SA );
                    drv_str.CopyDStrToStrW( sw, SW );
                    DISPOSE( SW );
                  END;
  | vtDriverString
                : DrvValueToStringW( Value, ValueUFlag, sw );
  ELSE
    sw := L'';
  END;
END ValueToStringW;

//--------------------------------------------------------------

PROCEDURE ValueToStringDecPlaces( CONST Value : TValue; ValueUFlag : BOOLEAN; DecPlaces : INTEGER; VAR s : ARRAY OF WCHAR );

  PROCEDURE AdjustNumber();
  VAR
    c : CARDINAL;
  BEGIN
    c := Strings.IndexOfCharW( s, L'.', 0 );
    IF DecPlaces = 0 THEN
      IF c <> MAX( CARDINAL ) THEN
        s[c] := WCHAR( 0 );
      END;
    ELSIF DecPlaces > 0 THEN
      IF c = MAX( CARDINAL ) THEN
        c := LENGTH( s );
      ELSE
        INC( c );
      END;
      LOOP
        IF c > HIGH( s ) THEN
          RETURN;
        ELSIF DecPlaces = 0 THEN
          IF c <= HIGH( s ) THEN
            s[c] := WCHAR( 0 );
          END;
          RETURN;
        END;
        IF s[c] = WCHAR( 0 ) THEN
          // IF AppendNonSignificantZeros THEN
          //   s[c] := '0';
          //   IF c = HIGH( s ) THEN
          //     RETURN;
          //   ELSE
          //     s[c+1] := 0C;
          //   END;
          // ELSE
            RETURN;
          // END;
        END;
        INC( c );
        DEC( DecPlaces );
      END; // LOOP
    ELSE // DecPlaces < 0 THEN
      IF c = MAX( CARDINAL ) THEN
        c := LENGTH( s );
      ELSE
        s[c] := WCHAR( 0 );
        DEC( c );
      END;
      IF CARDINAL( -DecPlaces ) > c THEN
        ASSIGN( s, L'0' );
        RETURN;
      END;
      LOOP
        IF INTEGER( c ) < 0 THEN
          RETURN;
        ELSIF DecPlaces = 0 THEN
          RETURN;
        END;
        s[c] := L'0';
        INC( DecPlaces );
        DEC( c );
      END;
    END;
  END AdjustNumber;

BEGIN
  CASE Value.Type OF
  | vtBoolean   : IF Value.ValBoolean THEN
                    ASSIGN( s, kwTRUE );
                  ELSE
                    ASSIGN( s, kwFALSE );
                  END;
  | vtShortCard : Strings.FromCARD32W( CARDINAL( Value.ValShortCard ), 10, OUT s ); AdjustNumber();
  | vtCardinal  : Strings.FromCARD32W( CARDINAL( Value.ValCardinal ), 10, OUT s ); AdjustNumber();
  | vtLongCard  : Strings.FromCARD32W( CARDINAL( Value.ValLongCard ), 10, OUT s ); AdjustNumber();
  | vtShortInt  : Strings.FromINT32W( INTEGER( Value.ValShortInt ), 10, OUT s ); AdjustNumber();
  | vtInteger   : Strings.FromINT32W( INTEGER( Value.ValInteger ), 10, OUT s ); AdjustNumber();
  | vtLongInt   : Strings.FromINT32W( INTEGER( Value.ValLongInt ), 10, OUT s ); AdjustNumber();
  | vtLongReal  : Strings.FromLONGREALExtW( Value.ValLongReal, -1, DecPlaces, FALSE, 0W, OUT s );
                  AdjustNumber();
  | vtDriverString
                : DrvValueToStringW( Value, ValueUFlag, s );
  ELSE
    s := L'';
  END;
END ValueToStringDecPlaces;

//--------------------------------------------------------------

PROCEDURE FormatNumber( Number : LONGREAL; Format : ARRAY OF WCHAR; VAR Result : ARRAY OF WCHAR );
TYPE
  TRoundUp = ARRAY [0..15] OF LONGREAL;
CONST
  roundUp = TRoundUp (
    0.5000000000000000,
    0.0500000000000000,
    0.0050000000000000,
    0.0005000000000000,
    0.0000500000000000,
    0.0000050000000000,
    0.0000005000000000,
    0.0000000500000000,
    0.0000000050000000,
    0.0000000005000000,
    0.0000000000500000,
    0.0000000000050000,
    0.0000000000005000,
    0.0000000000000500,
    0.0000000000000050,
    0.0000000000000005
  );
LABEL
  Failure;
VAR
  f, i, r, v : CARDINAL;
  FormatDot, FormatLeft, FormatLen, FormatRight, FormatSign, FormatSignBeforeZero : CARDINAL;
  Previous : CARDINAL;
  s : ARRAY [0..255] OF TCHAR;
  Value : ARRAY [0..255] OF TCHAR;
  ValueDot, ValueLen : CARDINAL;
  Negative : BOOLEAN;
BEGIN
  // shortcut
  IF Format[0] = 0W THEN
    Strings.FromLONGREALW( Number, FALSE, OUT Result );
    RETURN;
  END;
  // scan format
  i := 0;
  f := 0;
  FormatLeft := MAX( CARDINAL );
  FormatRight := 0;
  FormatDot := MAX( CARDINAL );
  FormatSign := MAX( CARDINAL );
  FormatSignBeforeZero := MAX( CARDINAL ); // first left zero in mask
  Previous := MAX( CARDINAL );
  LOOP
    IF i > HIGH( Format ) THEN
      FormatLen := MIN2( i, HIGH( Result ) + 1 );
      EXIT;
    END;
    CASE Format[i] OF
    | L'*', L'#' :
      INC( f ); // counter of mask fields
      Previous := i;
    | L'@' :
      INC( f ); // counter of mask fields
      IF ( FormatLeft = MAX( CARDINAL )) AND ( FormatSignBeforeZero = MAX( CARDINAL )) THEN
        FormatSignBeforeZero := Previous;
      END;
      Previous := i;
    | L'+', L'-' :
      IF FormatSign = MAX( CARDINAL ) THEN
        FormatSign := i;
      END;
// (*%T CZECH *)
    | L'.' :
      IF FormatLeft = MAX( CARDINAL ) THEN
        FormatDot := i;
        FormatLeft := f;
        f := 0;
      END;
    | L',', 0W :
// (*%E CZECH *)
// (*%F CZECH *)
//     | L'.', 0W :
// (*%E CZECH *)
      IF FormatLeft = MAX( CARDINAL ) THEN
        FormatDot := i;
        FormatLeft := f;
        f := 0;
      ELSE
        FormatRight := f;
      END;
      IF Format[i] = 0W THEN
        FormatLen := MIN2( i, HIGH( Result ) + 1 );
        EXIT;
      END;
    END; // CASE
    INC( i );
  END; // LOOP
  IF FormatLeft = MAX( CARDINAL ) THEN
    ASSIGN( Result, Format );
    RETURN;
  END;

  // prepare sign, round and get string
  IF Number >= 0.0 THEN
    Negative := FALSE;
    FormatSignBeforeZero := MAX( CARDINAL );
  ELSIF ( FormatSign = MAX( CARDINAL )) AND ( FormatSignBeforeZero = MAX( CARDINAL )) THEN // no @ found
    Negative := TRUE;
  ELSE // some @ found
    Negative := TRUE;
    Number := -Number;
  END;
  IF FormatSign <> MAX( CARDINAL ) THEN
    FormatSignBeforeZero := MAX( CARDINAL );
  END;

  // round and get string
  IF FormatRight < 16 THEN
    IF Number > 0.0 THEN // not Negative, there Negative and SGN( Number ) can differ
      Number := Number + roundUp[FormatRight];
    ELSIF Number < 0.0 THEN // not NOT Negative, see comment above
      Number := Number - roundUp[FormatRight];
    END;
  END;
  IF NOT Strings.FromLONGREALW( Number, FALSE, OUT Value ) THEN
    // total failure
    GOTO Failure;
  END;
  ValueDot := Strings.IndexOfCharW( Value, L'.', 0 );

  // expand too small or big numbers into plain string
  IF ( ABS( Number ) > 1.0E+14 ) OR ( ABS( Number ) < 1.0E-14 ) THEN
    i := Strings.IndexOfCharW( Value, L'E', 0 );
    IF i <> MAX( CARDINAL ) THEN
      // trim E, dot
      Strings.SubstringW( Value, i + 2, MAX( CARDINAL ), OUT s ); // + 1 for E, +1 for SIGN
      Value[i] := 0W; // trim on E
      Strings.RemoveW( REF Value, ValueDot, 1 ); // delete DOT
      // expand by exponent
      Strings.ToCARD32W( s, 10, OUT i ); // exponent
      IF ABS( Number ) < 1.0E-14 THEN
        s[0] := 0W;
        IF Value[0] = L'-' THEN
          ValueDot := 2;
          Value[0] := L'0';
          Strings.PadLeftW( REF s, i - 2, L'0' );
          Strings.PrependW( REF Value, s );
          Strings.PrependW( REF Value, L'-0.' );
        ELSE
          ValueDot := 1;
          Strings.PadLeftW( REF s, i - 1, L'0' );
          Strings.PrependW( REF Value, s );
          Strings.PrependW( REF Value, L'0.' );
        END;
      ELSE 
        ValueDot := MAX( CARDINAL );
        Strings.PadRightW( REF Value, i + 1, L'0' );
      END;
    END;
  END;

  // main lengths
  ValueLen := LENGTH( Value );
  IF ValueDot = MAX( CARDINAL ) THEN
    ValueDot := ValueLen; // dot is at the end of the string
  END;

  // place number into the result -- loop indexes
  f := 0;
  r := 0;
  v := 0;
  Previous := MAX( CARDINAL );
  // special cases and rounding
  IF ( FormatLeft < ValueDot ) OR (( FormatSignBeforeZero <> MAX( CARDINAL )) AND ( FormatLeft < ValueDot + 1 )) THEN
    // mask is shorter than number
    IF ( ValueDot = 1 ) AND ( Value[0] = L'0' ) THEN
      // special case, when then number has form '0.xxxx' and the masks start with '.xxxxx' -- zero can be mapped into empty place
      v := 1; // skip the leading value zero
    ELSE
      GOTO Failure;
    END;
  END;
  // formatting loop
  LOOP
    IF f >= FormatLen THEN
      EXIT;
    ELSIF f = FormatDot THEN
      Result[r] := Format[f];
      INC( v ); // dot is in the number too
      INC( r );
    ELSIF f = FormatSign THEN
      IF Negative THEN
        Result[r] := L'-';
      ELSE
        Result[r] := L'+';
      END;
      INC( r );
    ELSIF ( FormatLeft > ValueDot ) AND ( f = FormatSignBeforeZero ) THEN
      FormatSignBeforeZero := MAX( CARDINAL );
      Result[r] := L'-';
      INC( r );
      DEC( FormatLeft );
    ELSIF v < ValueDot THEN // left part of number
      CASE Format[f] OF
      | L'#' :
        IF FormatLeft <= ValueDot THEN // number has a normal cipher here
          IF FormatSignBeforeZero <> MAX( CARDINAL ) THEN
            FormatSignBeforeZero := MAX( CARDINAL );
            Result[Previous] := L'-';
          END;
          Result[r] := Value[v];
          INC( r );
          INC( v );
        ELSE // number is shorter
          Previous := r;
          Result[r] := ' ';
          INC( r );
          DEC( FormatLeft );
        END;
      | L'*' :
        IF FormatLeft <= ValueDot THEN // number has a normal cipher here
          IF FormatSignBeforeZero <> MAX( CARDINAL ) THEN
            FormatSignBeforeZero := MAX( CARDINAL );
            Strings.InsertW( REF Result, Previous, L'-' );
          END;
          Result[r] := Value[v];
          INC( r );
          INC( v );
        ELSE // number is shorter
          Previous := r;
          DEC( FormatLeft );
        END;
      | L'@' :
        IF FormatLeft <= ValueDot THEN // number has a normal cipher here
          IF FormatSignBeforeZero <> MAX( CARDINAL ) THEN
            FormatSignBeforeZero := MAX( CARDINAL );
            Result[Previous] := '-';
          END;
          Result[r] := Value[v];
          INC( r );
          INC( v );
        ELSE // number is shorter
          Previous := r;
          Result[r] := L'0';
          INC( r );
          DEC( FormatLeft );
        END;
      ELSE
        Result[r] := Format[f];
        INC( r );
      END; // CASE
    ELSE // right part of number
      CASE Format[f] OF
      | L'#' :
        IF v < ValueLen THEN
          Result[r] := Value[v];
          INC( r );
          INC( v );
        ELSE
          Result[r] := L'0';
          INC( r );
        END;
      | L'*' :
        IF v < ValueLen THEN
          Result[r] := Value[v];
          INC( r );
          INC( v );
        END;
      | L'@' :
        IF v < ValueLen THEN
          Result[r] := Value[v];
          INC( r );
          INC( v );
        ELSE
          Result[r] := L'0';
          INC( r );
        END;
      ELSE
        Result[r] := Format[f];
        INC( r );
        INC( v );
      END; // CASE
    END;
    INC( f ); 
  END; // LOOP

  // place 0C into the result
  IF r < HIGH( Result ) THEN
    Result[r] := 0W;
  END;
  RETURN;

Failure:
  // replace mask characters with '*'
  i := 0;
  LOOP
    IF i >= FormatLen THEN
      EXIT;
    ELSIF i = FormatSign THEN
      IF Negative THEN
        Result[i] := L'-';
      ELSE
        Result[i] := L'+';
      END;
    ELSE
      CASE Format[i] OF
      | L'#', L'*', L'@' :
        Result[i] := L'*';
      ELSE
        Result[i] := Format[i];
      END;
    END;
    INC( i );
  END; // LOOP

  // place 0C into the result
  IF i < HIGH( Result ) THEN
    Result[i] := 0W;
  END;
END FormatNumber;

//--------------------------------------------------------------

PROCEDURE ValueToStringFormat( CONST Value : TValue; ValueUFlag : BOOLEAN; Format : ARRAY OF TCHAR; VAR s : ARRAY OF WCHAR );
BEGIN
  IF Value.Type = vtBoolean THEN
    IF Value.ValBoolean THEN
      ASSIGN( s, kwTRUE );
    ELSE
      ASSIGN( s, kwFALSE );
    END;
  ELSIF Value.Type = vtDriverString THEN
    DrvValueToStringW( Value, ValueUFlag, s );
  ELSIF Format[0] <> 0W THEN
    FormatNumber( ValueToLongReal( Value, ValueUFlag, TRUE ), Format, s );
  ELSE
    CASE Value.Type OF
    | vtShortCard : Strings.FromCARD32W( CARDINAL( Value.ValShortCard ), 10, OUT s );
    | vtCardinal  : Strings.FromCARD32W( CARDINAL( Value.ValCardinal ), 10, OUT s );
    | vtLongCard  : Strings.FromCARD32W( CARDINAL( Value.ValLongCard ), 10, OUT s );
    | vtShortInt  : Strings.FromINT32W( INTEGER( Value.ValShortInt ), 10, OUT s );
    | vtInteger   : Strings.FromINT32W( INTEGER( Value.ValInteger ), 10, OUT s );
    | vtLongInt   : Strings.FromINT32W( INTEGER( Value.ValLongInt ), 10, OUT s );
    | vtLongReal  : Strings.FromLONGREALW( Value.ValLongReal, FALSE, OUT s );
    ELSE // CASE
      s := L'';
    END; // CASE
  END; // IF ELSE
END ValueToStringFormat;

//--------------------------------------------------------------

PROCEDURE CopyValue( VAR RValue : TValue; CONST SValue : TValue );
BEGIN
  RValue := SValue;
END CopyValue;

//---------------------------------------------------------------------------

PROCEDURE CompareValues( CONST Value1, Value2 : TValue ) : BOOLEAN;
BEGIN
  CASE Value1.Type OF
  | vtNothing, vtUnknown, vtError :
    RETURN FALSE;
  | vtBoolean :
    RETURN ( Value2.Type = vtBoolean ) AND ( Value1.ValBoolean = Value2.ValBoolean );
  ELSE
    RETURN ValueToLongReal( Value1, UNICODE, FALSE ) = ValueToLongReal( Value2, UNICODE, FALSE );
  END; // CASE
END CompareValues;

//--------------------------------------------------------------

PROCEDURE CopyDrvValueToValue( VAR Value : TValue; ValueUFlag, String256Flag : BOOLEAN; CONST DrvValue : TValue; DrvValueUFlag : BOOLEAN );
VAR
  S : ARRAY [0..255] OF WCHAR;
  PDS : drv_str.TPDStringW := NIL;
  PDSA : drv_str.TPDStringA;
BEGIN
  IF DrvValue.Type <> vtDriverString THEN
    CopyValue( Value, DrvValue );
  ELSIF DrvValue.ValDriverStringCharLength = 0 THEN
    // fall down
  ELSIF DrvValueUFlag THEN
    drv_str.CopyStrToDStrW( PDS, OA( DrvValue.ValDriverStringCharLength-1, PWCHAR( DrvValue.ValDriverStringAddress )));
  ELSE
    PDSA := NIL;
    drv_str.CopyStrToDStrA( PDSA, OA( DrvValue.ValDriverStringCharLength-1, PCHAR( DrvValue.ValDriverStringAddress )));
    drv_str.A2U( PDSA, PDS );
    IF PDSA <> NIL THEN
      DISPOSE( PDSA );
    END;
  END;
  DoneValue( Value );
  IF String256Flag THEN
    Value.Type := vtPString256;
    NEW( Value.ValPString256W );
    drv_str.CopyDStrToStrW( S, PDS );
    IF NOT ValueUFlag THEN
      ASSIGN( OA( 255, Value.ValPString256W ), S );
    ELSE
      Strings.ToA( S, 0, OUT OA( 255, Value.ValPString256A ));
    END;
    IF PDS <> NIL THEN
      DISPOSE( PDS );
    END;
  ELSE
    Value.Type := vtDString;
    Value.ValDStringW := PDS;
  END;
END CopyDrvValueToValue;

//--------------------------------------------------------------

PROCEDURE CopyValueToDrvValue( VAR DrvValue : TValue; DrvValueUFlag, TrimFlag : BOOLEAN; CONST Value : TValue; ValueUFlag : BOOLEAN ) : BOOLEAN;
VAR
  a : ADDRESS;
  l : CARDINAL;
BEGIN
  IF ( Value.Type <> vtDString ) AND ( Value.Type <> vtPString256 ) THEN
    CopyValue( DrvValue, Value );
  ELSIF Value.Type = vtDString THEN
    IF ( Value.ValDStringW = NIL ) OR ( Value.ValDStringW^.Len = 0 ) THEN
      DrvValue.ValDriverStringCharLength := 0;
      RETURN TRUE;
    END;
    l := Value.ValDStringW^.Len;
    DrvValue.ValDriverStringCharLength := l;
    a := ADR( Value.ValDStringW^.Chars );
  ELSE
    IF Value.ValPString256W = NIL THEN
      l := 0;
    ELSE
      l := LENGTH( OA( 255, Value.ValPString256W ));
    END;
    DrvValue.ValDriverStringCharLength := l;
    IF l = 0 THEN
      RETURN TRUE;
    END;
    a := Value.ValPString256W;
  END;
  IF ( l > DrvValue.ValDriverStringCharLength ) AND NOT TrimFlag THEN
    // request to allocate more space
    DrvValue.ValDriverStringAddress := NIL;
    RETURN FALSE;
  ELSIF DrvValueUFlag THEN
    Strings.MoveW( a, DrvValue.ValDriverStringAddress, l );
  ELSE
    Strings.ToA( OA( l-1, PWCHAR( a )), 0, OUT OA( l-1, PCHAR( DrvValue.ValDriverStringAddress )));
  END;
  RETURN TRUE;
END CopyValueToDrvValue;

//--------------------------------------------------------------

PROCEDURE DrvValueToStringW( CONST DrvValue : TValue; DrvValueUFlag : BOOLEAN; VAR s : ARRAY OF WCHAR );
VAR
  l : CARDINAL;
BEGIN
  IF DrvValue.Type <> vtDriverString THEN
    ValueToStringW( DrvValue, DrvValueUFlag, s );
    RETURN;
  END;
  l := MIN2( DrvValue.ValDriverStringCharLength, HIGH( s ) + 1 );
  IF l > 0 THEN
    IF DrvValueUFlag THEN
      Strings.MoveW( DrvValue.ValDriverStringAddress, ADR( s ), l );
    ELSE
      Strings.ToW( OA( l-1, PCHAR( DrvValue.ValDriverStringAddress )), 0, OUT OA( l-1, ADR( s )) );
    END;
  END;
  IF l < HIGH( s ) THEN
    s[l] := WCHAR( 0 );
  END;
END DrvValueToStringW;

//--------------------------------------------------------------

PROCEDURE DrvValueToCStringW( CONST DrvValue : TValue; DrvValueUFlag : BOOLEAN; OUT CS : StringsO.CString );
VAR
  s : ARRAY [0..63] OF WCHAR;
BEGIN
  IF DrvValue.Type <> vtDriverString THEN
    ValueToStringW( DrvValue, DrvValueUFlag, s );
    CS.FromOA( s );
    RETURN;
  END;
  IF DrvValue.ValDriverStringCharLength = 0 THEN
    CS.Clear();
  ELSIF DrvValueUFlag THEN
    CS.FromOA( OA( DrvValue.ValDriverStringCharLength-1, PWCHAR( DrvValue.ValDriverStringAddress )));
  ELSE
    CS.FromOAA( 0, OA( DrvValue.ValDriverStringCharLength-1, PCHAR( DrvValue.ValDriverStringAddress )));
  END;
END DrvValueToCStringW;

//--------------------------------------------------------------

PROCEDURE AssignDrvValueStringW( VAR DrvValue : TValue; DrvValueUFlag, TrimFlag : BOOLEAN; s : ARRAY OF WCHAR ): BOOLEAN;
VAR
  l : CARDINAL;
BEGIN
  IF DrvValue.Type = vtPString256 THEN
    IF DrvValue.ValPString256A = NIL THEN
      NEW( DrvValue.ValPString256W ); // create bigger one with reserve for ANSI characters
    END;
    IF DrvValueUFlag THEN
      ASSIGN( DrvValue.ValPString256W^, s );
    ELSE
      Strings.ToA( s, 0, OUT DrvValue.ValPString256A^ );
    END;
    RETURN TRUE;
  ELSIF DrvValue.Type <> vtDriverString THEN
    RETURN TRUE;
  ELSE
    l := LENGTH( s );
  END;
  IF l = 0 THEN
    DrvValue.ValDriverStringCharLength := 0;
  ELSIF ( l > DrvValue.ValDriverStringCharLength ) AND NOT TrimFlag THEN
    DrvValue.ValDriverStringCharLength := l;
    DrvValue.ValDriverStringAddress := NIL;
    RETURN FALSE;
  ELSIF DrvValueUFlag THEN
    DrvValue.ValDriverStringCharLength := l;
    Strings.MoveW( ADR( s ), DrvValue.ValDriverStringAddress, l );
  ELSE
    DrvValue.ValDriverStringCharLength := l;
    Strings.ToA( OA( l-1, ADR( s )), 0, OUT OA( l-1, PCHAR( DrvValue.ValDriverStringAddress )));
  END;
  RETURN TRUE;
END AssignDrvValueStringW;

//--------------------------------------------------------------

PROCEDURE AssignDrvValueCStringW( REF DrvValue : TValue; DrvValueUFlag, TrimFlag : BOOLEAN; CONST CS : StringsO.CString ): BOOLEAN;
VAR
  l : CARDINAL;
BEGIN
  IF DrvValue.Type = vtPString256 THEN
    IF DrvValue.ValPString256A = NIL THEN
      NEW( DrvValue.ValPString256W ); // create bigger one with reserve for ANSI characters
    END;
    IF DrvValueUFlag THEN
      CS.ToOA( OUT DrvValue.ValPString256W^ );
    ELSE
      CS.ToOAA( 0, OUT DrvValue.ValPString256A^, OUT l );
    END;
    RETURN TRUE;
  ELSIF DrvValue.Type <> vtDriverString THEN
    RETURN TRUE;
  ELSE
    l := CS.Length;
  END;
  IF l = 0 THEN
    DrvValue.ValDriverStringCharLength := 0;
  ELSIF ( l > DrvValue.ValDriverStringCharLength ) AND NOT TrimFlag THEN
    DrvValue.ValDriverStringCharLength := l;
    DrvValue.ValDriverStringAddress := NIL;
    RETURN FALSE;
  ELSIF DrvValueUFlag THEN
    DrvValue.ValDriverStringCharLength := l;
    CS.ToOA( OUT OA( l-1, PWCHAR( DrvValue.ValDriverStringAddress )));
  ELSE
    DrvValue.ValDriverStringCharLength := l;
    CS.ToOAA( 0, OUT OA( l-1, PCHAR( DrvValue.ValDriverStringAddress )), OUT l );
  END;
  RETURN TRUE;
END AssignDrvValueCStringW;

//==============================================================

PROCEDURE IOValueToCWValue( CONST IOValue : iovalue.Value; CWValueUFlag, TrimFlag : BOOLEAN; REF CWValue : TValue ) : BOOLEAN;
BEGIN
   CASE IOValue.Type OF
   | iovalue.vtBoolean :
      AssignValueBoolean( CWValue, CWValueUFlag, TRUE, IOValue.Boolean );

   | iovalue.vtTristate :
      AssignValueInt8( CWValue, CWValueUFlag, TRUE, INT8( IOValue.Tristate ));

   | iovalue.vtInteger :
      AssignValueInteger( CWValue, CWValueUFlag, TRUE, IOValue.Integer );

   | iovalue.vtLong :
      AssignValueLongReal( CWValue, CWValueUFlag, TRUE, LONGREAL( IOValue.Long ));

   | iovalue.vtFloat :
      AssignValueLongReal( CWValue, CWValueUFlag, TRUE, IOValue.Float );

   | iovalue.vtString :
      RETURN AssignDrvValueCStringW( REF CWValue, CWValueUFlag, TrimFlag, IOValue.String );

   | iovalue.vtDate :
      AssignValueLongReal( CWValue, CWValueUFlag, TRUE, time.ToSJD( IOValue.Date ));

   | iovalue.vtData : // TODO
      ASSERT( FALSE );

   END; // CASE
   RETURN TRUE;
END IOValueToCWValue;

//--------------------------------------------------------------

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

   | vtDriverString :
      DrvValueToCStringW( CWValue, DrvValueUFlag, OUT IOValue.String );

   | vtData :
     // TODO
     ASSERT( FALSE );
   END;
END CWValueToIOValue;

//==============================================================

END drv_def.