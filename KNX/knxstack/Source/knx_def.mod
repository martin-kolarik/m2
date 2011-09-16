IMPLEMENTATION MODULE knx_def;

(*===========================================================================*)

FROM Debug IMPORT
   Assertion, LogAssertionW;

IMPORT
  Storage,
  Strings;

(*===========================================================================*)

CLASS IMPLEMENTATION CAddress;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetAddressType( AddressType : TAddressType );
  BEGIN
    Type := AddressType;
  END SetAddressType;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetAddressType() : TAddressType;
  BEGIN
    IF Type = addressUnknown THEN
      RETURN addressUnknown;
    ELSIF Type = addressPhysical THEN
      RETURN addressPhysical;
    ELSE
      RETURN addressGroup;
    END;
  END GetAddressType;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetBroadcast();
  BEGIN
    SetGroupAddress1( 0 );
  END SetBroadcast;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE IsBroadcast() : BOOLEAN;
  BEGIN
    RETURN ( Type <> addressPhysical ) AND ( Address.dw = 0 );
  END IsBroadcast;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetPacketAddress( CONST PacketAddress : TPacketAddress );
  BEGIN
    Address := PacketAddress;
  END SetPacketAddress;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetPacketAddress() : TPacketAddress;
  BEGIN
    RETURN Address;
  END GetPacketAddress;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetPhysicalAddress1( dw : CARDINAL );
  BEGIN
    Type := addressPhysical;
    Address.dw := CARD16( dw );
  END SetPhysicalAddress1;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetPhysicalAddress1() : CARDINAL;
  BEGIN
    RETURN CARDINAL( Address.dw );
  END GetPhysicalAddress1;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetPhysicalAddress2( Area, Line, Device : CARDINAL );
  BEGIN
    Type := addressPhysical;
    Address.APILo := CARD8( Device );
    Address.APIHi := CARD8(( Area << 4 ) OR ( Line AND 0FH ));
  END SetPhysicalAddress2;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetPhysicalAddress2( VAR Area, Line, Device : CARDINAL );
  BEGIN
    Area := CARDINAL( Address.APIHi >> 4 );
    Line := CARDINAL( Address.APIHi AND 0FH );
    Device := CARDINAL( Address.APILo );
  END GetPhysicalAddress2;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetPhysicalAddress3( CONST s : ARRAY OF WCHAR ) : BOOLEAN;
  VAR
    A, L, D : CARDINAL;
    n : ARRAY [0..3] OF WCHAR;
  BEGIN
    Strings.ItemSW( s, WCHAR{L'.'}, 0, 3, TRUE, OUT n );
    IF n[0] <> WCHAR( 0 ) THEN
      RETURN FALSE;
    END;
    Strings.ItemSW( s, WCHAR{L'.'}, 0, 0, TRUE, OUT n );
    IF NOT Strings.ToCARD32W( n, 10, OUT A ) OR ( A > 15 ) THEN
      RETURN FALSE;
    END;
    Strings.ItemSW( s, WCHAR{L'.'}, 0, 1, TRUE, OUT n );
    IF NOT Strings.ToCARD32W( n, 10, OUT L ) OR ( L > 15 ) THEN
      RETURN FALSE;
    END;
    Strings.ItemSW( s, WCHAR{L'.'}, 0, 2, TRUE, OUT n );
    IF NOT Strings.ToCARD32W( n, 10, OUT D ) OR ( D > 255 ) THEN
      RETURN FALSE;
    END;
    SetPhysicalAddress2( A, L, D );
    RETURN TRUE;
  END SetPhysicalAddress3;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetPhysicalAddress3( VAR s : ARRAY OF WCHAR );
  VAR
    A, L, D : CARDINAL;
    n : ARRAY [0..3] OF WCHAR;
  BEGIN
    GetPhysicalAddress2( A, L, D );
    Strings.FromCARD32W( A, 10, OUT s ); Strings.AppendW( REF s, L'.' );
    Strings.FromCARD32W( L, 10, OUT n ); Strings.AppendW( REF s, n ); Strings.AppendW( REF s, L'.' );
    Strings.FromCARD32W( D, 10, OUT n ); Strings.AppendW( REF s, n );
  END GetPhysicalAddress3;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetGroupAddress1( dw : CARDINAL );
  BEGIN
    Type := addressGroup;
    Address.dw := CARD16( dw );
  END SetGroupAddress1;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetGroupAddress1() : CARDINAL;
  BEGIN
    RETURN CARDINAL( Address.dw );
  END GetGroupAddress1;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetGroupAddress2( MainGroup, MiddleGroup, SubGroup : CARDINAL );
  BEGIN
    Type := addressGroup3;
    Address.APILo := CARD8( SubGroup );
    Address.APIHi := ( CARD8( MainGroup AND 01FH ) << 3 ) OR CARD8( MiddleGroup AND 07H );
  END SetGroupAddress2;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetGroupAddress2( VAR MainGroup, MiddleGroup, SubGroup : CARDINAL );
  BEGIN
    MainGroup := CARDINAL( Address.APIHi >> 3 );
    MiddleGroup := CARDINAL( Address.APIHi AND 07H );
    SubGroup := CARDINAL( Address.APILo );
  END GetGroupAddress2;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetGroupAddress3( CONST s : ARRAY OF WCHAR ) : BOOLEAN; // */*/* and */* forms are detected
  VAR
    MA, MI, S : CARDINAL;
    n : ARRAY [0..3] OF WCHAR;
  BEGIN
    Strings.ItemSW( s, WCHAR{L'/'}, 0, 3, TRUE, OUT n );
    IF n[0] <> WCHAR( 0 ) THEN
      RETURN FALSE;
    END;
    Strings.ItemSW( s, WCHAR{L'/'}, 0, 0, TRUE, OUT n );
    IF NOT Strings.ToCARD32W( n, 10, OUT MA ) OR ( MA > 15 ) THEN
      RETURN FALSE;
    END;
    Strings.ItemSW( s, WCHAR{L'/'}, 0, 1, TRUE, OUT n );
    IF NOT Strings.ToCARD32W( n, 10, OUT MI ) OR ( MI > 2047 ) THEN 
      RETURN FALSE;
    END;
    Strings.ItemSW( s, WCHAR{L'/'}, 0, 2, TRUE, OUT n );
    IF n[0] = WCHAR( 0 ) THEN
      SetGroupAddress4( MA, MI );
    ELSIF MI > 7 THEN
      RETURN FALSE;
    ELSE
      IF NOT Strings.ToCARD32W( n, 10, OUT S ) OR ( S > 255 ) THEN
        RETURN FALSE;
      END;
      SetGroupAddress2( MA, MI, S );
    END;
    RETURN TRUE;
  END SetGroupAddress3;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetGroupAddress3( MiddleGroupForm : BOOLEAN; VAR s : ARRAY OF WCHAR );
  VAR
    MA, MI, S : CARDINAL;
    n : ARRAY [0..3] OF WCHAR;
  BEGIN
    IF MiddleGroupForm THEN
      GetGroupAddress2( MA, MI, S );
    ELSE
      GetGroupAddress4( MA, MI );
    END;
    Strings.FromCARD32W( MA, 10, OUT s ); Strings.AppendW( REF s, L'/' );
    Strings.FromCARD32W( MI, 10, OUT n ); Strings.AppendW( REF s, n );
    IF MiddleGroupForm THEN
      Strings.AppendW( REF s, L'/' );
      Strings.FromCARD32W( S, 10, OUT n );
      Strings.AppendW( REF s, n );
    END;
  END GetGroupAddress3;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetGroupAddress4( MainGroup, SubGroup : CARDINAL );
  BEGIN
    Type := addressGroup2;
    Address.APILo := CARD8( SubGroup );
    Address.APIHi := ( CARD8( MainGroup AND 01FH ) << 3 ) OR ( CARD8(( SubGroup AND 0700H ) >> 8 ));
  END SetGroupAddress4;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetGroupAddress4( VAR MainGroup, SubGroup : CARDINAL );
  BEGIN
    MainGroup := CARDINAL( Address.APIHi >> 3 );
    SubGroup := CARDINAL( Address.APIHi AND 07H ) OR CARDINAL( Address.APILo );
  END GetGroupAddress4;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Equals( CONST _Address : CAddress ) : BOOLEAN;
  BEGIN
    RETURN Address.dw = _Address.Address.dw;
  END Equals;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE InLine( Line : CARDINAL ) : BOOLEAN;
  VAR
    A, L, D : CARDINAL;
  BEGIN
    GetPhysicalAddress2( A, L, D );
    RETURN L = Line;
  END InLine;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE InArea( Area : CARDINAL ) : BOOLEAN;
  VAR
    A, L, D : CARDINAL;
  BEGIN
    GetPhysicalAddress2( A, L, D );
    RETURN A = Area;
  END InArea;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE ToCrId() : CARDINAL;
  BEGIN
    RETURN CARDINAL( Address.dw );
  END ToCrId;

(*---------------------------------------------------------------------------*)

BEGIN
  Type := addressGroup;
  Address.dw := 0;
END CAddress;

(*===========================================================================*)

PROCEDURE TypeToString( type : TKNXType; VAR string : ARRAY OF WCHAR ); // returns symbolic names
BEGIN
  CASE type OF
  | eitSwitch : ASSIGN( string, L'switch' );
  | eitIncrease : ASSIGN( string, L'increase' );
  | eitTime : ASSIGN( string, L'time' );
  | eitDate : ASSIGN( string, L'date' );
  | eitValue, eitValueRange : ASSIGN( string, L'value' );
  | eitScaling : ASSIGN( string, L'scaling' );
  | eitScaling255 : ASSIGN( string, L'scaling255' );
  | eitMove : ASSIGN( string, L'updown' );
  | eitPriority : ASSIGN( string, L'priority' );
  | eitFloat : ASSIGN( string, L'float' );
  | eit16bit : ASSIGN( string, L'counter16' );
  | eit32bit : ASSIGN( string, L'counter32' );
  | eitChar : ASSIGN( string, L'char' );
  | eit8bit : ASSIGN( string, L'counter8' );
  | eitString : ASSIGN( string, L'string' );
  END;
END TypeToString;

(*---------------------------------------------------------------------------*)

PROCEDURE NumberToType( number : INTEGER; VAR type : TKNXType ) : BOOLEAN;
BEGIN
  CASE number OF
  | 1 : type := eis1;
  | 2 : type := eis2Increase;
  | 3 : type := eis3;
  | 4 : type := eis4;
  | 5 : type := eis5;
  | 6 : type := eis6;
  | 7 : type := eis7Move;
  | 9 : type := eis9;
  | 10 : type := eis10;
  | 11 : type := eis11;
  | 13 : type := eis13;
  | 14 : type := eis14;
  | 15 : type := eis15;
  ELSE
    RETURN FALSE;
  END;
  RETURN TRUE;
END NumberToType;

(*---------------------------------------------------------------------------*)

PROCEDURE StringToType( String : ARRAY OF WCHAR; VAR EIT : TKNXType ) : BOOLEAN;
VAR
  i : CARDINAL;
  b : BOOLEAN;
BEGIN
  IF String[0] = WCHAR( 0 ) THEN
    RETURN FALSE;
  END;
  IF ( String[0] >= L'0' ) AND ( String[0] <= L'9' ) THEN // try numerical form
    b := Strings.ToCARD32W( String, 10, OUT i );
  ELSE
    b := FALSE;
  END;
  IF b AND NOT NumberToType( i, EIT ) THEN
    RETURN FALSE;
  ELSIF EQUALS( String, L'eis1'  ) OR EQUALS( String, L'switch'     ) THEN
    EIT := eitSwitch;
  ELSIF EQUALS( String, L'eis2'  ) OR EQUALS( String, L'increase'   ) THEN
    EIT := eitIncrease;
  ELSIF EQUALS( String, L'eis3'  ) OR EQUALS( String, L'time'       ) THEN
    EIT := eitTime;
  ELSIF EQUALS( String, L'eis4'  ) OR EQUALS( String, L'date'       ) THEN
    EIT := eitDate;
  ELSIF EQUALS( String, L'eis5'  ) OR EQUALS( String, L'value'      ) THEN
    EIT := eitValue;
  ELSIF EQUALS( String, L'eis6'  ) OR EQUALS( String, L'scaling'    ) THEN
    EIT := eitScaling;
  ELSIF                               EQUALS( String, L'scaling255' ) THEN
    EIT := eitScaling255;
  ELSIF EQUALS( String, L'eis7'  ) OR EQUALS( String, L'updown'     ) THEN
    EIT := eitMove;        
  ELSIF EQUALS( String, L'eis8'  ) OR EQUALS( String, L'priority'   ) THEN
    EIT := eitPriority;        
  ELSIF EQUALS( String, L'eis9'  ) OR EQUALS( String, L'float'      ) THEN
    EIT := eitFloat;
  ELSIF EQUALS( String, L'eis10' ) OR EQUALS( String, L'counter16'  ) THEN
    EIT := eit16bit;
  ELSIF EQUALS( String, L'eis11' ) OR EQUALS( String, L'counter32'  ) THEN
    EIT := eit32bit;
  ELSIF EQUALS( String, L'eis13' ) OR EQUALS( String, L'char'       ) THEN
    EIT := eitChar;
  ELSIF EQUALS( String, L'eis14' ) OR EQUALS( String, L'counter8'   ) THEN
    EIT := eit8bit;
  ELSIF EQUALS( String, L'eis15' ) OR EQUALS( String, L'string'     ) THEN
    EIT := eitString;
  ELSE
    RETURN FALSE;
  END;
  RETURN TRUE;
END StringToType;

(*===========================================================================*)

TYPE
  TIncrease    = (
    incrStop,
    incrUp,
    incrDown
  );

  // variant for accessing CValue.Data
  TVariantData = RECORD
                   CASE : TKNXType OF
                   | eitUnknown:    Data       : TKNXValueData;
                   | eitSwitch:     State      : BOOLEAN;
                   | eitIncrease:   How        : TIncrease;
                                    Amount     : CARDINAL; // percent
                   | eitTime:       Day        : TDay;
                                    H, Mi, S   : CARDINAL;
                   | eitDate:       D, Mo, Y   : CARDINAL;
                   | eitValue:      Value      : LONGREAL;
                   | eitValueRange: _Dummy     : LONGREAL;
                                    LoRange    : LONGREAL;
                                    HiRange    : LONGREAL;
                   | eitScaling:    Percent    : CARDINAL;
                   | eitScaling255: Scaling    : CARD8;
                   | eitMove:       Up         : BOOLEAN;
                   | eitPriority:   Priority   : CARD8;
                   | eitFloat:      Float      : LONGREAL;
                   | eit16bit:      Count16    : CARD16;
                   | eit32bit:      Count32    : CARD32;
                   | eitAccess:     AccessCode : CARDINAL;
                                    Flags      : TAccessFlagSet;
                                    Index      : CARDINAL;
                   | eitChar:       Char       : WCHAR;
                   | eit8bit:       Count8     : CARD8;
                   | eitString:     String     : TEISStringW;
                   END; // CASE
                 END; // TVariantData
  TPVariantData = POINTER TO TVariantData;

(*===========================================================================*)

CLASS IMPLEMENTATION CValue;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetType( Type : TKNXType );
  BEGIN
    SELF.Type := Type;
  END SetType;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetType() : TKNXType;
  BEGIN
    RETURN Type;
  END GetType;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE CopyFrom( CONST Value : CValue );
  BEGIN
    Type := Value.Type;
    Data := Value.Data;
  END CopyFrom;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Equals( CONST Value : CValue ) : BOOLEAN;
  VAR
    PSD, PVD : TPVariantData;
  BEGIN
    IF Value.Type = Type THEN
      PSD := TPVariantData( ADR( Data ));
      PVD := TPVariantData( ADR( Value.Data ));
    ELSE
      RETURN FALSE;
    END;
    CASE Type OF
    | eitUnknown:    RETURN TRUE;
    | eitSwitch:     RETURN ( PVD^.State      = PSD^.State );
    | eitIncrease:   RETURN ( PVD^.How        = PSD^.How )        AND ( PVD^.Amount  = PSD^.Amount );
    | eitTime:       RETURN ( PVD^.Day        = PSD^.Day )        AND ( PVD^.H       = PSD^.H  )       AND ( PVD^.Mi      = PSD^.Mi ) AND ( PVD^.S = PSD^.S );
    | eitDate:       RETURN ( PVD^.Y          = PSD^.Y )          AND ( PVD^.Mo      = PSD^.Mo )       AND ( PVD^.D       = PSD^.D  );
    | eitValue:      RETURN ( PVD^.Value      = PSD^.Value );
    | eitValueRange: RETURN ( PVD^.Value      = PSD^.Value )      AND ( PVD^.LoRange = PSD^.LoRange ) AND ( PVD^.HiRange = PSD^.HiRange );
    | eitScaling:    RETURN ( PVD^.Percent    = PSD^.Percent );
    | eitScaling255: RETURN ( PVD^.Scaling    = PSD^.Scaling );
    | eitMove:       RETURN ( PVD^.Up         = PSD^.Up );
    | eitPriority:   RETURN ( PVD^.Priority   = PSD^.Priority );
    | eitFloat:      RETURN ( PVD^.Float      = PSD^.Float );
    | eit16bit:      RETURN ( PVD^.Count16    = PSD^.Count16 );
    | eit32bit:      RETURN ( PVD^.Count32    = PSD^.Count32 );
    | eitAccess:     RETURN ( PVD^.AccessCode = PSD^.AccessCode ) AND ( PVD^.Flags   = PSD^.Flags )   AND ( PVD^.Index   = PSD^.Index );
    | eitChar:       RETURN ( PVD^.Char       = PSD^.Char );
    | eit8bit:       RETURN ( PVD^.Count8     = PSD^.Count8 );
    | eitString:     RETURN EQUALS( PVD^.String, PSD^.String );
    END; // CASE
    RETURN FALSE;
  END Equals;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetSwitch( State : BOOLEAN );
  BEGIN
    Type := eitSwitch;
    TPVariantData( ADR( Data ))^.State := State;
  END SetSwitch;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetIncrease( Up, Down : BOOLEAN; LevelPercent : CARDINAL );
  BEGIN
    Type := eitIncrease;
    IF Up THEN
      TPVariantData( ADR( Data ))^.How := incrUp;
      TPVariantData( ADR( Data ))^.Amount := LevelPercent;
    ELSIF Down THEN
      TPVariantData( ADR( Data ))^.How := incrDown;
      TPVariantData( ADR( Data ))^.Amount := LevelPercent;
    ELSE
      TPVariantData( ADR( Data ))^.How := incrStop;
    END;
  END SetIncrease;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetTime( Day : TDay; H, M, S : CARDINAL );
  BEGIN
    Type := eitTime;
    TPVariantData( ADR( Data ))^.Day := Day;
    TPVariantData( ADR( Data ))^.H := H;
    TPVariantData( ADR( Data ))^.Mi := M;
    TPVariantData( ADR( Data ))^.S := S;
  END SetTime;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetDate( Y, M, D : CARDINAL );
  BEGIN
    Type := eitDate;
    TPVariantData( ADR( Data ))^.Y := Y;
    TPVariantData( ADR( Data ))^.Mo := M;
    TPVariantData( ADR( Data ))^.D := D;
  END SetDate;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetValue( Value : LONGREAL );
  BEGIN
    Type := eitValue;
    TPVariantData( ADR( Data ))^.Value := Value;
  END SetValue;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetValueRange( Value : LONGREAL; LoRange, HiRange : LONGREAL );
  BEGIN
    Type := eitValueRange;
    TPVariantData( ADR( Data ))^.Value := Value;
    TPVariantData( ADR( Data ))^.LoRange := LoRange;
    TPVariantData( ADR( Data ))^.HiRange := HiRange;
  END SetValueRange;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetScaling( ValuePercent : CARDINAL );
  BEGIN
    Type := eitScaling;
    TPVariantData( ADR( Data ))^.Percent := ValuePercent;
  END SetScaling;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetScaling255( Value : CARD8 );
  BEGIN
    Type := eitScaling255;
    TPVariantData( ADR( Data ))^.Scaling := Value;
  END SetScaling255;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetMove( Open : BOOLEAN );
  BEGIN
    Type := eitMove;
    TPVariantData( ADR( Data ))^.Up := Open;
  END SetMove;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetStep( Up : BOOLEAN );
  BEGIN
    Type := eitMove;
    TPVariantData( ADR( Data ))^.Up := Up;
  END SetStep;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetPriority( Priority : CARDINAL );
  BEGIN
    Type := eitPriority;
    TPVariantData( ADR( Data ))^.Priority := MIN2( 3, Priority );
  END SetPriority;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetFloat( Value : LONGREAL );
  BEGIN
    Type := eitFloat;
    TPVariantData( ADR( Data ))^.Float := Value;
  END SetFloat;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Set16bit( Value : CARDINAL );
  BEGIN
    Type := eit16bit;
    TPVariantData( ADR( Data ))^.Count16 := CARD16( Value );
  END Set16bit;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Set32bit( Value : CARDINAL );
  BEGIN
    Type := eit32bit;
    TPVariantData( ADR( Data ))^.Count32 := CARD32( Value );
  END Set32bit;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetAccess( AccessCode : CARDINAL; Flags : TAccessFlagSet; Index : CARDINAL );
  BEGIN
    Type := eitAccess;
    TPVariantData( ADR( Data ))^.AccessCode := AccessCode;
    TPVariantData( ADR( Data ))^.Flags := Flags;
    TPVariantData( ADR( Data ))^.Index := Index;
  END SetAccess;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetChar( Char : WCHAR );
  BEGIN
    Type := eitChar;
    TPVariantData( ADR( Data ))^.Char := Char;
  END SetChar;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Set8bit( Value : CARDINAL );
  BEGIN
    Type := eit8bit;
    TPVariantData( ADR( Data ))^.Count8 := CARD8( Value );
  END Set8bit;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetString( String : ARRAY OF WCHAR );
  BEGIN
    Type := eitString;
    ASSIGN( TPVariantData( ADR( Data ))^.String, String );
  END SetString;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetSwitch() : BOOLEAN;
  BEGIN
    ASSERT( Type = eitSwitch );
    RETURN TPVariantData( ADR( Data ))^.State;
  END GetSwitch;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetIncrease( VAR Up, Down : BOOLEAN ) : CARDINAL;
  BEGIN
    ASSERT( Type = eitIncrease );
    Up := TPVariantData( ADR( Data ))^.How = incrUp;
    Down := TPVariantData( ADR( Data ))^.How = incrDown;
    RETURN TPVariantData( ADR( Data ))^.Amount;
  END GetIncrease;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetTime( VAR Day : TDay; VAR H, M, S : CARDINAL );
  BEGIN
    ASSERT( Type = eitTime );
    Day := TPVariantData( ADR( Data ))^.Day;
    H := TPVariantData( ADR( Data ))^.H;
    M := TPVariantData( ADR( Data ))^.Mi;
    S := TPVariantData( ADR( Data ))^.S;
  END GetTime;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetDate( VAR Y, M, D : CARDINAL );
  BEGIN
    ASSERT( Type = eitDate );
    Y := TPVariantData( ADR( Data ))^.Y;
    M := TPVariantData( ADR( Data ))^.Mo;
    D := TPVariantData( ADR( Data ))^.D;
  END GetDate;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetValue() : LONGREAL;
  BEGIN
    ASSERT( Type = eitValue );
    RETURN TPVariantData( ADR( Data ))^.Value;
  END GetValue;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetValueRange( VAR LoRange, HiRange : LONGREAL ) : LONGREAL;
  BEGIN
    ASSERT( Type = eitValueRange );
    LoRange := TPVariantData( ADR( Data ))^.LoRange;
    HiRange := TPVariantData( ADR( Data ))^.HiRange;
    RETURN TPVariantData( ADR( Data ))^.Value;
  END GetValueRange;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetScaling() : CARDINAL;
  BEGIN
    ASSERT( Type = eitScaling );
    RETURN TPVariantData( ADR( Data ))^.Percent;
  END GetScaling;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetScaling255() : CARDINAL;
  BEGIN
    ASSERT( Type = eitScaling255 );
    RETURN CARDINAL( TPVariantData( ADR( Data ))^.Scaling );
  END GetScaling255;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetMove() : BOOLEAN;
  BEGIN
    ASSERT( Type = eitMove );
    RETURN TPVariantData( ADR( Data ))^.Up;
  END GetMove;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetStep() : BOOLEAN;
  BEGIN
    ASSERT( Type = eitMove );
    RETURN TPVariantData( ADR( Data ))^.Up;
  END GetStep;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetPriority() : CARDINAL;
  BEGIN
    ASSERT( Type = eitPriority );
    RETURN CARDINAL( TPVariantData( ADR( Data ))^.Priority );
  END GetPriority;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetFloat() : LONGREAL;
  BEGIN
    ASSERT( Type = eitFloat );
    RETURN TPVariantData( ADR( Data ))^.Float;
  END GetFloat;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Get16bit() : CARDINAL;
  BEGIN
    ASSERT( Type = eit16bit );
    RETURN CARDINAL( TPVariantData( ADR( Data ))^.Count16 );
  END Get16bit;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Get32bit() : CARDINAL;
  BEGIN
    ASSERT( Type = eit32bit );
    RETURN CARDINAL( TPVariantData( ADR( Data ))^.Count32 );
  END Get32bit;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetAccess( VAR AccessCode : CARDINAL; VAR Flags : TAccessFlagSet; VAR Index : CARDINAL );
  BEGIN
    ASSERT( Type = eitAccess );
    AccessCode := TPVariantData( ADR( Data ))^.AccessCode;
    Flags := TPVariantData( ADR( Data ))^.Flags;
    Index := TPVariantData( ADR( Data ))^.Index;
  END GetAccess;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetChar() : WCHAR;
  BEGIN
    ASSERT( Type = eitChar );
    RETURN TPVariantData( ADR( Data ))^.Char;
  END GetChar;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Get8bit() : CARDINAL;
  BEGIN
    ASSERT( Type = eit8bit );
    RETURN CARDINAL( TPVariantData( ADR( Data ))^.Count8 );
  END Get8bit;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetString( VAR String : ARRAY OF WCHAR );
  BEGIN
    ASSERT( Type = eitString );
    ASSIGN( String, TPVariantData( ADR( Data ))^.String );
  END GetString;

(*---------------------------------------------------------------------------*)

BEGIN
  Type := eitUnknown;
  Storage.Fill( ADR( Data ), SIZE( Data ), 0 );
END CValue;

(*===========================================================================*)

CLASS IMPLEMENTATION EMIPacket;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Length GET : CARDINAL;
   BEGIN
      RETURN 7 + CARDINAL( NetworkControl * ncmDataLength );
   END Length;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Clear();
  BEGIN
    TransportControl := TransportControl - acmEISData;
    Storage.Fill( ADR( Data ), SIZE( Data ), 0 );
  END Clear;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE CopyFrom( CONST Packet : EMIPacket );
  BEGIN
    LinkControl      := Packet.LinkControl;
    Source           := Packet.Source;
    Destination      := Packet.Destination;
    NetworkControl   := Packet.NetworkControl;
    TransportControl := Packet.TransportControl;
    Data             := Packet.Data;
  END CopyFrom;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE ValidCheckSum() : BOOLEAN;
  BEGIN
    RETURN FALSE;
  END ValidCheckSum;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetError( State : BOOLEAN );
  BEGIN
    IF State THEN
      INCL( LinkControl, lcError );
    ELSE
      EXCL( LinkControl, lcError );
    END;
  END SetError;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetError() : BOOLEAN;
  BEGIN
    RETURN lcError IN LinkControl;
  END GetError;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetRepeated( State : BOOLEAN );
  BEGIN
    IF State THEN
      EXCL( LinkControl, lcNotRepeated );
    ELSE
      INCL( LinkControl, lcNotRepeated );
    END;
  END SetRepeated;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetRepeated() : BOOLEAN;
  BEGIN
    RETURN NOT( lcNotRepeated IN LinkControl );
  END GetRepeated;

(*---------------------------------------------------------------------------*)
     
  PUBLIC PROCEDURE SetPriority( Priority : TPriority );
  BEGIN
    CASE Priority OF
    | priorityNormal :
      LinkControl := LinkControl - lcmPriority + lcsPriorityNormal;
    | priorityHigh :
      LinkControl := LinkControl - lcmPriority + lcsPriorityHigh;
    | priorityAlarm :
      LinkControl := LinkControl - lcmPriority + lcsPriorityAlarm;
    | prioritySystem :
      LinkControl := LinkControl - lcmPriority + lcsPrioritySystem;
    END;
  END SetPriority;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetPriority() : TPriority;
  BEGIN
    IF lcPriority1 IN LinkControl THEN
      IF lcPriority0 IN LinkControl THEN
        RETURN priorityNormal;
      ELSE
        RETURN priorityHigh;
      END;
    ELSIF lcPriority0 IN LinkControl THEN
      RETURN priorityAlarm;
    ELSE
      RETURN prioritySystem;
    END;
  END GetPriority;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetSourceAddress( CONST Address : CAddress );
  BEGIN
    IF Address.Type = addressPhysical THEN
      Source.KNXHi := Address.Address.APIHi;
      Source.KNXLo := Address.Address.APILo;
    END;
  END SetSourceAddress;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetSourceAddress() : CAddress;
  VAR
    Address : CAddress;
  BEGIN
    Address.Type := addressPhysical;
    Address.Address.APIHi := Source.KNXHi;
    Address.Address.APILo := Source.KNXLo;
    RETURN Address;
  END GetSourceAddress;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetDestinationAddressType( Type : TAddressType );
  BEGIN
    CASE Type OF
    | addressPhysical :
      EXCL( NetworkControl, ncLogicalAddress );
    | addressGroup2, addressGroup3 :
      INCL( NetworkControl, ncLogicalAddress );
    END;
  END SetDestinationAddressType;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetDestinationAddressType() : TAddressType;
  BEGIN
    IF ncLogicalAddress IN NetworkControl THEN
      RETURN addressGroup;
    ELSE
      RETURN addressPhysical;
    END;
  END GetDestinationAddressType;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetDestinationAddress( CONST Address : CAddress );
  BEGIN
    SetDestinationAddressType( Address.Type );
    Destination.KNXHi := Address.Address.APIHi;
    Destination.KNXLo := Address.Address.APILo;
  END SetDestinationAddress;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetDestinationAddress() : CAddress;
  VAR
    Address : CAddress;
  BEGIN
    Address.Type := GetDestinationAddressType();
    Address.Address.APIHi := Destination.KNXHi;
    Address.Address.APILo := Destination.KNXLo;
    RETURN Address;
  END GetDestinationAddress;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetDataLength( Length : CARDINAL );
  BEGIN
    NetworkControl := NetworkControl - ncmDataLength + BITSET8( Length AND 15 );
  END SetDataLength;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetDataLength() : CARDINAL;
  BEGIN
    RETURN CARDINAL( NetworkControl * ncmDataLength );
  END GetDataLength;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetRoutingCounter( Counter : CARDINAL );
  BEGIN
    NetworkControl := NetworkControl - ncmRoutingCounter + BITSET8(( Counter AND 7 ) << ncShiftRoutingCounter );
  END SetRoutingCounter;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetRoutingCounter() : CARDINAL;
  BEGIN
    RETURN CARDINAL( NetworkControl * ncmRoutingCounter ) >> ncShiftRoutingCounter;
  END GetRoutingCounter;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetPacketNumber( Number : CARDINAL );
  BEGIN
    TransportControl := TransportControl - tcmPacketNumber + TTransportControl(( Number AND 15 ) << tcShiftPacketNumber );
  END SetPacketNumber;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetPacketNumber() : CARDINAL;
  BEGIN
    RETURN CARDINAL( TransportControl * tcmPacketNumber ) >> tcShiftPacketNumber;
  END GetPacketNumber;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetPacketType( Type : TPacketType );
  BEGIN
    CASE Type OF
    | packetDatagramData :
      TransportControl := TransportControl - tcmPacketType + BITSET16{};
    | packetReliableControl :
      TransportControl := TransportControl - tcmPacketType + BITSET16{tcControlPacket};
    | packetReliableDataReq :
      TransportControl := TransportControl - tcmPacketType + BITSET16{tcNumberedPacket};
    | packetReliableDataACK :
      TransportControl := TransportControl - tcmPacketType + BITSET16{tcControlPacket, tcNumberedPacket};
    END;
  END SetPacketType;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetPacketType() : TPacketType;
  BEGIN
    IF tcControlPacket IN TransportControl THEN
      IF tcNumberedPacket IN TransportControl THEN
        RETURN packetReliableDataACK;
      ELSE
        RETURN packetReliableControl;
      END;
    ELSIF tcNumberedPacket IN TransportControl THEN
      RETURN packetReliableDataReq;
    ELSE
      RETURN packetDatagramData;
    END;
  END GetPacketType;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetValueDirection( Direction : TValueDirection );
  BEGIN
    CASE Direction OF
    | directionRead :
      TransportControl := TransportControl - acmValueDirection + acsValueRead;
    | directionResponse :
      TransportControl := TransportControl - acmValueDirection + acsValueResponse;
    | directionWrite :
      TransportControl := TransportControl - acmValueDirection + acsValueWrite;
    END;
  END SetValueDirection;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetValueDirection() : TValueDirection;
  BEGIN
    CASE CARDINAL( TransportControl * acmValueDirection ) OF
    | CARDINAL( acsValueRead ) :
      RETURN directionRead;
    | CARDINAL( acsValueResponse ) :
      RETURN directionRead;
    END;
    RETURN directionWrite;
  END GetValueDirection;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE ToValue( OUT Value : CValue );
  TYPE
    T4B = RECORD b0, b1, b2, b3 : BYTE; END;
  VAR
    EISString : TEISString;
    EISStringW : TEISStringW;
    Float : REAL;
    i : INTEGER;
    LR : LONGREAL;
    sa : ARRAY [0..3] OF CHAR;
    sw : ARRAY [0..1] OF WCHAR;
    V : CARDINAL;
    b : BOOLEAN;
  BEGIN
    CASE Value.Type OF
    //-----
    | eitUnknown:
      ASSERT( FALSE );
    //-----
    | eitSwitch:
      Value.SetSwitch( le2be[0] IN TransportControl );
    //-----
    | eitIncrease:
      IF TransportControl * TTransportControl{ le2be[0], le2be[1], le2be[2] } = TTransportControl{} THEN
        Value.SetIncrease( FALSE, FALSE, 0 );
      ELSIF le2be[3] IN TransportControl THEN
        b := TRUE; // Up
      ELSE
        b := FALSE; // NOT Up
      END;
      CASE CARDINAL( TransportControl * TTransportControl{ le2be[0], le2be[1], le2be[2] } ) >> 8 OF
      | 1 : Value.SetIncrease( b, NOT b, 100 );
      | 2 : Value.SetIncrease( b, NOT b, 50 );
      | 3 : Value.SetIncrease( b, NOT b, 25 );
      | 4 : Value.SetIncrease( b, NOT b, 13 );
      | 5 : Value.SetIncrease( b, NOT b, 6 );
      | 6 : Value.SetIncrease( b, NOT b, 3 );
      | 7 : Value.SetIncrease( b, NOT b, 2 );
      END; // CASE
    //-----
    | eitTime:
      Value.SetTime( TDay(( CARDINAL( Data[0] ) AND 0E0H ) >> 5 ), CARDINAL( Data[0] ) AND 01FH, CARDINAL( Data[1] ), CARDINAL( Data[2] ));
    //-----
    | eitDate:
      IF CARDINAL( Data[2] ) < 90 THEN
        Value.SetDate( 2000 + CARDINAL( Data[2] ), CARDINAL( Data[1] ), CARDINAL( Data[0] ));
      ELSE
        Value.SetDate( 1900 + CARDINAL( Data[2] ), CARDINAL( Data[1] ), CARDINAL( Data[0] ));
      END;
    //-----
    | eitValue, eitValueRange:
      V := ( CARDINAL( Data[0] ) << 8 ) AND 0700H + CARDINAL( Data[1] );
      IF CARD8( Data[0] ) AND 080H <> 0 THEN
        V := V OR 0FFFFF800H;
      END;
      LR := 0.01 * LONGREAL( INTEGER( V ));
      i := ( INTEGER( Data[0] ) >> 3 ) AND 0FH;
      WHILE i > 0 DO
        LR := LR * 2.0;
        DEC( i );
      END;
      Value.SetValue( LR );
    //-----
    | eitScaling:
      Value.SetScaling( CARDINAL(( 100 * CARDINAL( Data[0] ) + 127 ) DIV 255 ));
    //-----
    | eitScaling255:
      Value.SetScaling255( CARD8( Data[0] ));
    //-----
    | eitMove :
      Value.SetMove( NOT( le2be[0] IN TransportControl ));
    //-----
    | eitPriority :
      Value.SetPriority( CARDINAL( TransportControl * TTransportControl{ le2be[0], le2be[1] } ) >> 8 );
    //-----
    | eitFloat:
      T4B( Float ).b3 := Data[0];
      T4B( Float ).b2 := Data[1];
      T4B( Float ).b1 := Data[2];
      T4B( Float ).b0 := Data[3];
      Value.SetFloat( LONGREAL( Float ));
    //-----
    | eit16bit:
      Value.Set16bit( 256 * CARDINAL( Data[0] ) + CARDINAL( Data[1] ));
    //-----
    | eit32bit:
      Value.Set32bit( 256 * ( 256 * ( 256 * CARDINAL( Data[0] ) + CARDINAL( Data[1] )) + CARDINAL( Data[2] )) + CARDINAL( Data[3] ));
    //-----
    | eitAccess:
      Value.SetAccess( 
        CARDINAL(( Data[0] ) << 16 ) OR ( CARDINAL( Data[1] ) << 8 ) OR CARDINAL( Data[2] ),
        TAccessFlagSet( CARDINAL( Data[3] ) >> 4 ),
        CARDINAL( Data[3] ) AND 0FH
      );
    //-----
    | eitChar:
      sa[0] := Data[0];
      sa[1] := CHAR( 0 );
      Strings.ToW( sa, 0, OUT sw );
      Value.SetChar( sw[0] );
    //-----
    | eit8bit:
      Value.Set8bit( CARDINAL( Data[0] ));
    //-----
    | eitString:
      FOR i := 0 TO 13 DO
        EISString[i] := CHAR( Data[i] );
      END;
      Strings.ToW( EISString, 0, OUT EISStringW );
      Value.SetString( EISStringW );
    END; // CASE
  END ToValue;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE FromValue( CONST Value : CValue );
  TYPE
    T4B = RECORD b0, b1, b2, b3 : BYTE; END;
  VAR
    Day : TDay;
    EISString : knx_def.TEISString;
    EISStringW : knx_def.TEISStringW;
    Exp : CARD8;
    Flags : TAccessFlagSet;
    i : CARDINAL;
    Index : CARDINAL;
    H, M, S, D, Y : CARDINAL;
    LR : LONGREAL;
    sa : ARRAY [0..3] OF CHAR;
    sw : ARRAY [0..1] OF WCHAR;
    b : BOOLEAN;
    Up, Down : BOOLEAN;
    ValueInt : INTEGER;
  BEGIN
    CASE Value.Type OF
    //-----
    | eitUnknown:
      ASSERT( FALSE );
    //-----
    | eitSwitch:
      NetworkControl := NetworkControl - ncmDataLength + ncsDataLength1;
      IF Value.GetSwitch() THEN
        TransportControl := TransportControl - acmEISData + BITSET16{ le2be[0] };
      ELSE
        TransportControl := TransportControl - acmEISData;
      END;
    //-----
    | eitIncrease:
      NetworkControl := NetworkControl - ncmDataLength + ncsDataLength1;
      i := Value.GetIncrease( Up, Down );
      IF i = 0 THEN // Stop
        TransportControl := TransportControl - acmEISData;
        RETURN;
      ELSIF Up THEN
        TransportControl := TransportControl - acmEISData + BITSET16{ le2be[3] };
      ELSIF Down THEN
        TransportControl := TransportControl - acmEISData;
      ELSE // Stop
        TransportControl := TransportControl - acmEISData;
        RETURN;
      END;
      // add increment
      i := 1000 DIV i;
         IF i >= 500 THEN
        TransportControl := TransportControl + BITSET16( 7 << 8 ); // 1--2
      ELSIF i >= 250 THEN
        TransportControl := TransportControl + BITSET16( 6 << 8 ); // 3--4
      ELSIF i >= 125 THEN
        TransportControl := TransportControl + BITSET16( 5 << 8 ); // 5--8
      ELSIF i >=  58 THEN
        TransportControl := TransportControl + BITSET16( 4 << 8 ); // 9--17
      ELSIF i >=  30 THEN
        TransportControl := TransportControl + BITSET16( 3 << 8 ); // 18--33
      ELSIF i >=  15 THEN
        TransportControl := TransportControl + BITSET16( 2 << 8 ); // 34--66
      ELSE
        TransportControl := TransportControl + BITSET16( 1 << 8 ); // 67--100
      END;
    //-----
    | eitTime:
      NetworkControl := NetworkControl - ncmDataLength + ncsDataLength4;
      TransportControl := TransportControl - acmEISData;
      Value.GetTime( Day, H, M, S );
      Data[0] := BYTE(( CARDINAL( Day ) << 5 ) OR H );
      Data[1] := BYTE( M );
      Data[2] := BYTE( S );
    //-----
    | eitDate:
      NetworkControl := NetworkControl - ncmDataLength + ncsDataLength4;
      TransportControl := TransportControl - acmEISData;
      Value.GetDate( Y, M, D );
      Data[0] := BYTE( D );
      Data[1] := BYTE( M );
      IF Y < 2000 THEN
        Data[2] := BYTE( Y - 1900 );
      ELSE
        Data[2] := BYTE( Y - 2000 );
      END;
    //-----
    | eitValue:
      NetworkControl := NetworkControl - ncmDataLength + ncsDataLength3;
      TransportControl := TransportControl - acmEISData;
      LR := Value.GetValue();
      IF LR = 0.0 THEN
        Data[0] := 0; Data[2] := 0;
        RETURN;
      ELSIF LR < 0.0 THEN
        Data[0] := 080H;
      ELSE
        Data[0] := 0;
      END;
      LR := LR * 100.0;
      Exp := 0;
      WHILE ABS( LR ) > 2047.0 DO
        INC( Exp );
        LR := LR / 2.0;
      END;
      ValueInt := INTEGER( LR );
      IF Exp > 15 THEN
        Data[0] := BYTE( CARD8( Data[1] ) OR 07FH );
        Data[1] := 0FFH;
      ELSE
        Data[0] := BYTE( CARD8( Data[0] ) OR ( Exp << 3 ) OR CARD8(( ValueInt >> 8 ) AND 07H ));
        Data[1] := BYTE( ValueInt AND 0FFH );
      END;
    //-----
    | eitValueRange:
      // not implemented
      ASSERTLOG( FALSE );
    //-----
    | eitScaling:
      NetworkControl := NetworkControl - ncmDataLength + ncsDataLength2;
      TransportControl := TransportControl - acmEISData;
      Data[0] := BYTE(( 255 * Value.GetScaling() + 50 ) DIV 100 );
    //-----
    | eitScaling255:
      NetworkControl := NetworkControl - ncmDataLength + ncsDataLength2;
      TransportControl := TransportControl - acmEISData;
      Data[0] := BYTE( Value.GetScaling255() );
    //-----
    | eitMove :
      NetworkControl := NetworkControl - ncmDataLength + ncsDataLength1;
      IF Value.GetMove() THEN
        TransportControl := TransportControl - acmEISData;
      ELSE
        TransportControl := TransportControl - acmEISData + BITSET16{ le2be[0] };
      END;
    //-----
    | eitPriority :
      NetworkControl := NetworkControl - ncmDataLength + ncsDataLength1;
      TransportControl := TransportControl + BITSET16( Value.GetPriority() << 8 );
    //-----
    | eitFloat:
      NetworkControl := NetworkControl - ncmDataLength + ncsDataLength5;
      TransportControl := TransportControl - acmEISData;
      LR := LONGREAL( Value.GetFloat());
      Data[0] := T4B( LR ).b3;
      Data[1] := T4B( LR ).b2;
      Data[2] := T4B( LR ).b1;
      Data[3] := T4B( LR ).b0;
    //-----
    | eit16bit:
      NetworkControl := NetworkControl - ncmDataLength + ncsDataLength3;
      TransportControl := TransportControl - acmEISData;
      i := Value.Get16bit();
      Data[0] := BYTE( i DIV 256 );
      Data[1] := BYTE( i AND 255 );
    //-----
    | eit32bit:
      NetworkControl := NetworkControl - ncmDataLength + ncsDataLength5;
      TransportControl := TransportControl - acmEISData;
      i := Value.Get32bit();
      Data[0] := BYTE( i DIV ( 65536 * 256 ));
      Data[1] := BYTE(( i DIV 65536 ) AND 255 );
      Data[2] := BYTE(( i DIV 256 ) AND 255 );
      Data[3] := BYTE( i AND 255 );
    //-----
    | eitAccess:
      NetworkControl := NetworkControl - ncmDataLength + ncsDataLength5;
      TransportControl := TransportControl - acmEISData;
      Value.GetAccess( i, Flags, Index );
      Data[0] := BYTE( i >> 16 );
      Data[1] := BYTE(( i >> 8 ) AND 0FFH );
      Data[2] := BYTE( i AND 0FFH );
      Data[3] := BYTE( CARDINAL( Flags ) << 4 OR ( Index AND 0FH ));
    //-----
    | eitChar:
      sw[0] := Value.GetChar();
      sw[1] := WCHAR( 0 );
      Strings.ToA( sw, 0, OUT sa );
      NetworkControl := NetworkControl - ncmDataLength + ncsDataLength2;
      TransportControl := TransportControl - acmEISData;
      Data[0] := sa[0];
    //-----
    | eit8bit:
      NetworkControl := NetworkControl - ncmDataLength + ncsDataLength2;
      TransportControl := TransportControl - acmEISData;
      Data[0] := BYTE( Value.Get8bit() );
    //-----
    | eitString:
      Value.GetString( EISStringW );
      Strings.ToA( EISStringW, 0, OUT EISString );
      NetworkControl := NetworkControl - ncmDataLength + ncsDataLength15;
      TransportControl := TransportControl - acmEISData;
      b := FALSE; // ZeroFlag
      FOR i := 0 TO 13 DO
        IF b THEN
          Data[i] := CHAR( 0 );
        ELSIF EISString[i] = CHAR( 0 ) THEN
          b := TRUE;
          Data[i] := CHAR( 0 );
        ELSE
          Data[i] := EISString[i];
        END;
      END; // FOR
    END; // CASE
  END FromValue;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE FromDataArray( LData : ARRAY OF BYTE; Len : CARDINAL ); // rough, handling of length is not intuitive
  BEGIN
    IF Len = 0 THEN
      RETURN;
    END;
    NetworkControl := NetworkControl - ncmDataLength + BITSET8( Len ) * ncmDataLength;
    IF Len = 1 THEN
      TransportControl := TransportControl + BITSET16( LData[0] << 8 ) * acmEISData; // for ACPI encoded values
    ELSE
      TransportControl := TransportControl - acmEISData;
      DEC( Len );
      Storage.Move( ADR( LData ), ADR( Data ), Len );
    END;
  END FromDataArray;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE ToDataArray( VAR LData : ARRAY OF BYTE; VAR Len : CARDINAL ); // rough, handling of length is not intuitive
  BEGIN
    Len := CARDINAL( NetworkControl * ncmDataLength );
    IF Len = 0 THEN
      RETURN;
    ELSIF Len = 1 THEN
      LData[0] := CARD8( CARD16( TransportControl * acmEISData ) >> 8 );
    ELSE
      Storage.Move( ADR( Data ), ADR( LData ), Len-1 );
    END;
  END ToDataArray;

(*---------------------------------------------------------------------------*)

BEGIN
  Code := L_Data_REQ;
  LinkControl := lcsDefault;
  Source.dw := 0;
  Destination.dw := 0;
  NetworkControl := ncsDefault;
  TransportControl := BITSET16{};
  Data[0] := 0;
END EMIPacket;

(*===========================================================================*)

CLASS IMPLEMENTATION cEMIPacket;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Length GET : CARDINAL;
   BEGIN
      RETURN 10 + ACPILength;
   END Length;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY DataLength GET : CARDINAL;
   BEGIN
      RETURN CARDINAL( ACPILength );
   END DataLength;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY DataLength SET( Value : CARDINAL );
   BEGIN
      ACPILength := CARD8( MIN2( 255, Value ));
   END DataLength;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Long GET : BOOLEAN;
   BEGIN
      RETURN lcStandardFrame NOT IN LinkControl;
   END Long;
   
(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Long SET( Value : BOOLEAN );
   BEGIN
      IF Value THEN
         EXCL( LinkControl, lcStandardFrame );
      ELSE
         INCL( LinkControl, lcStandardFrame );
      END;
   END Long;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY FrameType GET : TFrameType;
   VAR
      EFF : CARD8 := DAFAndRouting AND 0FH;
   BEGIN
      IF EFF = 0 THEN
         RETURN ftStandard;
      ELSIF EFF AND 0CH = 4 THEN
         RETURN ftLTE;
      ELSE
         RETURN ftUser;
      END;
   END FrameType;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY FrameType SET( Value : TFrameType );
   BEGIN
      CASE Value OF
      | ftStandard :
         DAFAndRouting := DAFAndRouting AND 0F0H;
      | ftLTE :
         DAFAndRouting := DAFAndRouting AND 0F3H OR 04H;
      | ftUser :
         DAFAndRouting := DAFAndRouting OR 0FH;
      ELSE
         ASSERTLOG( FALSE );
      END;
   END FrameType;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE FromEMI( CONST EMI : EMIPacket );
   VAR
      data : TData;
      i : INTEGER;
   BEGIN
      CASE EMI.Code OF
      | L_Data_REQ :
         Code := L_Data_REQ;
      | L_Data_CON, L_Data_CON_EMI2 :
         Code := L_Data_CON;
      | L_Data_IND, L_Data_IND_EMI2 :
         Code := L_Data_IND;
      ELSE
         ASSERT( FALSE );
         RETURN;
      END;
      LinkControl := EMI.LinkControl;
      DAFAndRouting := CARD8( EMI.NetworkControl ) AND 0F0H;
      Source := EMI.Source;
      Destination := EMI.Destination;
      ACPILength := CARD8( EMI.NetworkControl ) AND 00FH;
      Data[0] := CARD8( EMI.TransportControl );
      Data[1] := CARD8( CARD16( EMI.TransportControl ) >> 8 );

      data := EMI.Data;
      FOR i := 2 TO INTEGER( ACPILength )-3 DO
         Data[i] := data[i-2];
      END;
   END FromEMI;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ToEMI( OUT EMI : EMIPacket );
   VAR
      data : TData;
      i : INTEGER;
   BEGIN
      EMI.Code := Code;
      EMI.LinkControl := LinkControl;
      EMI.Source := Source;
      EMI.Destination := Destination;
      EMI.TransportControl := TTransportControl( Data[0] OR ( Data[1] << 8 ));

      IF Long OR ( FrameType <> ftStandard ) THEN
         EMI.NetworkControl := BITSET8( DAFAndRouting );
      ELSE
         EMI.NetworkControl := BITSET8( DAFAndRouting OR ACPILength );
         FOR i := 2 TO INTEGER( ACPILength )-3 DO
            data[i-2] := Data[i];
         END;
         EMI.Data := data;
      END;
   END ToEMI;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ToDataArray( VAR LData : ARRAY OF BYTE; VAR Len : CARDINAL ); // rough, handling of length is not intuitive
   VAR
      TransportControl : TTransportControl;
   BEGIN
      Len := CARDINAL( ACPILength );
      IF Len = 0 THEN
         RETURN;
      ELSIF Len = 1 THEN
         TransportControl := TTransportControl( Data[0] OR ( Data[1] << 8 ));
         LData[0] := CARD8( CARD16( TransportControl * acmEISData ) >> 8 );
      ELSE
         Storage.Move( ADR( Data[2] ), ADR( LData ), Len-1 );
      END;
   END ToDataArray;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE GetDestinationAddress( OUT s : ARRAY OF WCHAR );
   VAR
      address : CAddress;
      i : CARDINAL;
      naddress : CARDINAL;
      n : ARRAY [0..15] OF WCHAR;
   BEGIN
      address.Address.APIHi := Destination.KNXHi;
      address.Address.APILo := Destination.KNXLo;

      CASE FrameType OF
      //-----
      | knx_def.ftStandard :
         IF ncLogicalAddress IN BITSET8( DAFAndRouting ) THEN
            address.Type := addressGroup;
            address.GetGroupAddress3( TRUE, s );
         ELSE
            address.Type := addressPhysical;
            address.GetPhysicalAddress3( s );
         END;
      
      //-----
      | knx_def.ftLTE :
         address.Type := addressPhysical;
         naddress := CARDINAL( address.GetPhysicalAddress1());

         IF 1 IN BITSET8( DAFAndRouting ) THEN // application or peripheral tags
            IF 0 IN BITSET8( DAFAndRouting ) THEN // peripheral tags
               ASSIGN( s, L"P/" );
               // group
               i := naddress >> 12;
               Strings.FromCARD32W( i, 10, OUT n );
               Strings.AppendW( REF s, n ); Strings.AppendW( REF s, L"/" );
               // subgroup
               i := naddress AND 0FFFH;
               Strings.FromCARD32W( i, 10, OUT n );
               Strings.AppendW( REF s, n );

            ELSE // application tags
               // domain
               i := naddress >> 12;
               IF i = 0 THEN
                  ASSIGN( s, L"A/HVAC/" );
               ELSE
                  ASSIGN( s, L"A/????/" );
               END;
               // segments
               i := ( naddress AND 0FFFH ) >> 9;
               IF i = 0 THEN // distribution segment
                  i := ( naddress AND 01FFH ) >> 5;
                  CASE i OF
                  | 1 :
                     Strings.AppendW( REF s, L"dH/" );
                  | 2 :
                     Strings.AppendW( REF s, L"dC/" );
                  | 3 :
                     Strings.AppendW( REF s, L"dV/" );
                  | 4 :
                     Strings.AppendW( REF s, L"dW/" );
                  | 5 :
                     Strings.AppendW( REF s, L"dO/" );
                  | 6 :
                     Strings.AppendW( REF s, L"dD/" );
                  END; // CASE
                  // distributor number
                  i := naddress AND 01FH;
                  Strings.FromCARD32W( i, 10, OUT n );
                  Strings.AppendW( REF s, n );

               ELSE // producer segment
                  IF i > 2 THEN
                     Strings.AppendW( REF s, L"p?/" );
                  ELSIF i = 2 THEN
                     Strings.AppendW( REF s, L"pC/" );
                  ELSIF i = 1 THEN
                     Strings.AppendW( REF s, L"pH/" );
                  END;
                  // segment number
                  i := ( naddress AND 01FFH ) >> 5;
                  Strings.FromCARD32W( i, 10, OUT n );
                  Strings.AppendW( REF s, n ); Strings.AppendW( REF s, L"/" );
                  // producer number
                  i := naddress AND 01FH;
                  Strings.FromCARD32W( i, 10, OUT n );
                  Strings.AppendW( REF s, n );
               
               END;
            END;

         ELSE // geographical addresses
            IF naddress = 0 THEN
               ASSIGN( s, L"G/*" );

            ELSE
               ASSIGN( s, L"G/" );
               // apartement/floor
               IF 0 IN BITSET8( DAFAndRouting ) THEN
                  i := naddress >> 10 + 64;
               ELSE
                  i := naddress >> 10;
               END;
               Strings.FromCARD32W( i, 10, OUT n );
               Strings.AppendW( REF s, n ); Strings.AppendW( REF s, L"/" );
               // room
               i := ( naddress AND 03FFH ) >> 4;
               Strings.FromCARD32W( i, 10, OUT n );
               Strings.AppendW( REF s, n ); Strings.AppendW( REF s, L"/" );
               // subzone
               i := naddress AND 0FH;
               Strings.FromCARD32W( i, 10, OUT n );
               Strings.AppendW( REF s, n );

            END;
         END;

      ELSE
         ASSIGN( s, L"<user>" );
      END;
   END GetDestinationAddress;

(*---------------------------------------------------------------------------*)

BEGIN
   Code := L_Data_REQ;
   AdditionalLength := 0;
   LinkControl := lcsDefault;
   DAFAndRouting := 0;
   ACPILength := 0;
   Data[0] := 0;
END cEMIPacket;

(*===========================================================================*)

END knx_def.