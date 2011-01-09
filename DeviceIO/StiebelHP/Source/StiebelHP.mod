IMPLEMENTATION MODULE StiebelHP;

(*================================================================================*)

FROM Debug IMPORT
   Assertion, LogAssertionW;

IMPORT
    datetime,
	FIO,
	iobject,
	IOO,
	LogConfig,
	resources,
	StorageO,
	StringsO,
	Sync,
	Texts;

(*================================================================================*)

VAR
   R : resources.CResources;

(*================================================================================*)

CONST
   DEFAULT_PORT = 10001;

TYPE
	TDeviceType = INT8(
		dtController = 0DH,
		dtModul      = 03H,
		dtTank       = 06H
	);

	TTelegramType = INT8(
		ttSet,
		ttGet,
		ttResponse
	);

#save, option( pack => 1 )
CLASS CBE;
	PRIVATE VAR
		_Data : WORD;
	PUBLIC PROPERTY
		BS : INT16; // big endian
		LS : INT16; // little endian
		LU : CARD16; // little endian
END CBE;

TYPE
	TPBE = POINTER TO CBE;

TYPE
	TPacket   = RECORD
								SenderType   : TDeviceType;
								Address      : BYTE; // ???
								ReceiverType : TDeviceType;
								Telegram     : TTelegramType;
								D1, D2       : BYTE;
								PointNumber  : CBE;
								CASE : CARD8 OF
								| 0 : bValue : BYTE;
								| 1 : wValue : CBE;
								END; // CASE
								CRC          : WORD;
							END; // RECORD
#restore

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CBE;

	PUBLIC PROPERTY BS GET : INT16;
	BEGIN
		RETURN INT16( _Data );
	END BS;

	PUBLIC PROPERTY BS SET( Value : INT16 );
	BEGIN
		_Data := Value;
	END BS;

	PUBLIC PROPERTY LS GET : INT16;
	BEGIN
		RETURN INT16( ( _Data AND 0FFH << 8 ) OR ( _Data >> 8 ) );
	END LS;

	PUBLIC PROPERTY LS SET( Value : INT16 );
	BEGIN
		_Data := ( WORD( Value ) AND 0FFH << 8 ) OR ( WORD( Value ) >> 8 );
	END LS;

	PUBLIC PROPERTY LU GET : CARD16;
	BEGIN
		RETURN ( _Data AND 0FFH << 8 ) OR ( _Data >> 8 );
	END LU;

	PUBLIC PROPERTY LU SET( Value : CARD16 );
	BEGIN
		_Data := ( Value AND 0FFH << 8 ) OR ( Value >> 8 );
	END LU;

BEGIN
	_Data := 0;
END CBE;

(*===========================================================================*)

CLASS CNSI( nsitem.CnsItem );
	LOCAL VAR
      Value : iovalue.Value;
		Multiplier : CARDINAL;
END CNSI;

CLASS IMPLEMENTATION CNSI;
BEGIN
	Multiplier := 1;
END CNSI;

(*---------------------------------------------------------------------------*)

TYPE
   TErrorItem = (
      eiHour = 0,
      eiMinute = 1,
      eiDay = 0,
      eiMonth = 1,
      eiYear = 2
   );

CLASS CErrorNSI( nsitem.CnsItem );
   LOCAL VAR
      Items : ARRAY [eiDay..eiYear] OF TPNSI; // indexes are of TErrorItem type
      Peer : POINTER TO CErrorNSI;
END CErrorNSI;

CLASS IMPLEMENTATION CErrorNSI;
BEGIN
   Items[eiDay] := NIL;
   Items[eiMonth] := NIL;
   Items[eiYear] := NIL;
   Peer := NIL;
END CErrorNSI;

(*===========================================================================*)

CLASS IMPLEMENTATION CNS;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE HashToName( CONST Hash : ns.THash; OUT Name : StringsO.IString ) : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END HashToName;

(*---------------------------------------------------------------------------*)

	INTERNAL VIRTUAL PROCEDURE CreateRoot() : ns.TPnsItem;
	BEGIN
		RETURN CreateNewItem( L"StiebelHP", ns.ntName, iovalue.vtString, 0 );
	END CreateRoot;

(*---------------------------------------------------------------------------*)

	INTERNAL VIRTUAL PROCEDURE CreateStructure();
	VAR
	  D : nsitem.TPnsItem;
	  E1, E2 : TPErrorNSI; // error
	  H : nsitem.TPnsItem;
	  I : TPNSI;
	BEGIN
		Root^.AddChild( CreateNewItem( L"Control", ns.ntName, iovalue.vtString, 0 ));

		D := nsitem.TPnsItem( CreateNewItem( L"Data", ns.ntName, iovalue.vtString, 0 ));
		Root^.AddChild( D );

		H := nsitem.TPnsItem( CreateNewItem( L".Hidden", ns.ntName, iovalue.vtString, 0 ));
		Root^.AddChild( H );

		I := TPNSI( CreateNewItem( L"Reset",                         ns.ntValue, iovalue.vtInteger, 098000H )); D^.AddChild( I ); I^.Multiplier := 1000;
		I := TPNSI( CreateNewItem( L"OperatingMode",                 ns.ntValue, iovalue.vtInteger, 030112H )); D^.AddChild( I ); I^.Multiplier := 1;
		I := TPNSI( CreateNewItem( L"EquithermicCurve",              ns.ntValue, iovalue.vtFloat,   03010EH )); D^.AddChild( I ); I^.Multiplier := 100;
		// I := TPNSI( CreateNewItem( L"T setpoint",        iovalue.vtFloat,   030008H )); D^.AddChild( I );

		I := TPNSI( CreateNewItem( L"Inner T",                       ns.ntValue, iovalue.vtFloat,   060011H )); D^.AddChild( I ); I^.Multiplier := 10;
		I := TPNSI( CreateNewItem( L"Inner T setpoint",              ns.ntValue, iovalue.vtFloat,   060005H )); D^.AddChild( I ); I^.Multiplier := 10;
		I := TPNSI( CreateNewItem( L"Outer T",                       ns.ntValue, iovalue.vtFloat,   03000CH )); D^.AddChild( I ); I^.Multiplier := 10;
		I := TPNSI( CreateNewItem( L"Return T",                      ns.ntValue, iovalue.vtFloat,   030016H )); D^.AddChild( I ); I^.Multiplier := 10;
		I := TPNSI( CreateNewItem( L"Return T setpoint",             ns.ntValue, iovalue.vtFloat,   060004H )); D^.AddChild( I ); I^.Multiplier := 10;
		I := TPNSI( CreateNewItem( L"Output T",                      ns.ntValue, iovalue.vtFloat,   0301D6H )); D^.AddChild( I ); I^.Multiplier := 10;

		I := TPNSI( CreateNewItem( L"Water T",                       ns.ntValue, iovalue.vtFloat,   03000EH )); D^.AddChild( I ); I^.Multiplier := 10;
		I := TPNSI( CreateNewItem( L"Water T setpoint",              ns.ntValue, iovalue.vtFloat,   030013H )); D^.AddChild( I ); I^.Multiplier := 10;

		I := TPNSI( CreateNewItem( L"Pump 1 Service Hours",          ns.ntValue, iovalue.vtInteger, 0301C4H )); D^.AddChild( I );
		I := TPNSI( CreateNewItem( L"Pump 2 Service Hours",          ns.ntValue, iovalue.vtInteger, 0301C5H )); D^.AddChild( I );
		I := TPNSI( CreateNewItem( L"Bivalent Supply Service Hours", ns.ntValue, iovalue.vtInteger, 0301CBH )); D^.AddChild( I );
		
		// errors, create composite values together with their composite parts -- these are in hidden part of namespace
		I := TPNSI( CreateNewItem( L"Error occurred",                ns.ntValue, iovalue.vtBoolean, 000000H )); D^.AddChild( I ); I^.Multiplier := 0;
		
		E1 := CreateErrorItem( L"Error 01 Time" ); D^.AddChild( E1 );
		   I := TPNSI( CreateNewItem( L"01m", ns.ntValue, iovalue.vtInteger, 030B00H )); H^.AddChild( I ); E1^.Items[eiMinute] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"01H", ns.ntValue, iovalue.vtInteger, 030B01H )); H^.AddChild( I ); E1^.Items[eiHour] := I; I^.Multiplier := 2; // special code for dword type
		E2 := CreateErrorItem( L"Error 01 Date" ); D^.AddChild( E2 );
		   I := TPNSI( CreateNewItem( L"01D", ns.ntValue, iovalue.vtInteger, 030B02H )); H^.AddChild( I ); E2^.Items[eiDay] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"01M", ns.ntValue, iovalue.vtInteger, 030B03H )); H^.AddChild( I ); E2^.Items[eiMonth] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"01Y", ns.ntValue, iovalue.vtInteger, 030B04H )); H^.AddChild( I ); E2^.Items[eiYear] := I; I^.Multiplier := 2; // special code for dword type
		I := TPNSI( CreateNewItem( L"Error 01 Code", ns.ntValue, iovalue.vtInteger, 030B05H )); D^.AddChild( I ); I^.Multiplier := 2; // special code for dword type
		E1^.Peer := E2; E2^.Peer := E1;
		// 6 empty
		
		E1 := CreateErrorItem( L"Error 02 Time" ); D^.AddChild( E1 );
		   I := TPNSI( CreateNewItem( L"02m", ns.ntValue, iovalue.vtInteger, 030B07H )); H^.AddChild( I ); E1^.Items[eiMinute] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"02H", ns.ntValue, iovalue.vtInteger, 030B08H )); H^.AddChild( I ); E1^.Items[eiHour] := I; I^.Multiplier := 2; // special code for dword type
		E2 := CreateErrorItem( L"Error 02 Date" ); D^.AddChild( E2 );
		   I := TPNSI( CreateNewItem( L"02D", ns.ntValue, iovalue.vtInteger, 030B09H )); H^.AddChild( I ); E2^.Items[eiDay] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"02M", ns.ntValue, iovalue.vtInteger, 030B0AH )); H^.AddChild( I ); E2^.Items[eiMonth] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"02Y", ns.ntValue, iovalue.vtInteger, 030B0BH )); H^.AddChild( I ); E2^.Items[eiYear] := I; I^.Multiplier := 2; // special code for dword type
		I := TPNSI( CreateNewItem( L"Error 02 Code", ns.ntValue, iovalue.vtInteger, 030B0CH )); D^.AddChild( I ); I^.Multiplier := 2; // special code for dword type
		E1^.Peer := E2; E2^.Peer := E1;
		// D empty

		E1 := CreateErrorItem( L"Error 03 Time" ); D^.AddChild( E1 );
		   I := TPNSI( CreateNewItem( L"03m", ns.ntValue, iovalue.vtInteger, 030B0EH )); H^.AddChild( I ); E1^.Items[eiMinute] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"03H", ns.ntValue, iovalue.vtInteger, 030B0FH )); H^.AddChild( I ); E1^.Items[eiHour] := I; I^.Multiplier := 2; // special code for dword type
		E2 := CreateErrorItem( L"Error 03 Date" ); D^.AddChild( E2 );
		   I := TPNSI( CreateNewItem( L"03D", ns.ntValue, iovalue.vtInteger, 030B10H )); H^.AddChild( I ); E2^.Items[eiDay] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"03M", ns.ntValue, iovalue.vtInteger, 030B11H )); H^.AddChild( I ); E2^.Items[eiMonth] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"03Y", ns.ntValue, iovalue.vtInteger, 030B12H )); H^.AddChild( I ); E2^.Items[eiYear] := I; I^.Multiplier := 2; // special code for dword type
		I := TPNSI( CreateNewItem( L"Error 03 Code", ns.ntValue, iovalue.vtInteger, 030B13H )); D^.AddChild( I ); I^.Multiplier := 2; // special code for dword type
		E1^.Peer := E2; E2^.Peer := E1;
		// 14 empty

		E1 := CreateErrorItem( L"Error 04 Time" ); D^.AddChild( E1 );
		   I := TPNSI( CreateNewItem( L"04m", ns.ntValue, iovalue.vtInteger, 030B15H )); H^.AddChild( I ); E1^.Items[eiMinute] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"04H", ns.ntValue, iovalue.vtInteger, 030B16H )); H^.AddChild( I ); E1^.Items[eiHour] := I; I^.Multiplier := 2; // special code for dword type
		E2 := CreateErrorItem( L"Error 04 Date" ); D^.AddChild( E2 );
		   I := TPNSI( CreateNewItem( L"04D", ns.ntValue, iovalue.vtInteger, 030B17H )); H^.AddChild( I ); E2^.Items[eiDay] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"04M", ns.ntValue, iovalue.vtInteger, 030B18H )); H^.AddChild( I ); E2^.Items[eiMonth] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"04Y", ns.ntValue, iovalue.vtInteger, 030B19H )); H^.AddChild( I ); E2^.Items[eiYear] := I; I^.Multiplier := 2; // special code for dword type
		I := TPNSI( CreateNewItem( L"Error 04 Code", ns.ntValue, iovalue.vtInteger, 030B1AH )); D^.AddChild( I ); I^.Multiplier := 2; // special code for dword type
		E1^.Peer := E2; E2^.Peer := E1;
		// 1B empty

		E1 := CreateErrorItem( L"Error 05 Time" ); D^.AddChild( E1 );
		   I := TPNSI( CreateNewItem( L"05m", ns.ntValue, iovalue.vtInteger, 030B1CH )); H^.AddChild( I ); E1^.Items[eiMinute] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"05H", ns.ntValue, iovalue.vtInteger, 030B1DH )); H^.AddChild( I ); E1^.Items[eiHour] := I; I^.Multiplier := 2; // special code for dword type
		E2 := CreateErrorItem( L"Error 05 Date" ); D^.AddChild( E2 );
		   I := TPNSI( CreateNewItem( L"05D", ns.ntValue, iovalue.vtInteger, 030B1EH )); H^.AddChild( I ); E2^.Items[eiDay] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"05M", ns.ntValue, iovalue.vtInteger, 030B1FH )); H^.AddChild( I ); E2^.Items[eiMonth] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"05Y", ns.ntValue, iovalue.vtInteger, 030B20H )); H^.AddChild( I ); E2^.Items[eiYear] := I; I^.Multiplier := 2; // special code for dword type
		I := TPNSI( CreateNewItem( L"Error 05 Code", ns.ntValue, iovalue.vtInteger, 030B21H )); D^.AddChild( I ); I^.Multiplier := 2; // special code for dword type
		E1^.Peer := E2; E2^.Peer := E1;
		// 22 empty

		E1 := CreateErrorItem( L"Error 06 Time" ); D^.AddChild( E1 );
		   I := TPNSI( CreateNewItem( L"06m", ns.ntValue, iovalue.vtInteger, 030B23H )); H^.AddChild( I ); E1^.Items[eiMinute] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"06H", ns.ntValue, iovalue.vtInteger, 030B24H )); H^.AddChild( I ); E1^.Items[eiHour] := I; I^.Multiplier := 2; // special code for dword type
		E2 := CreateErrorItem( L"Error 06 Date" ); D^.AddChild( E2 );
		   I := TPNSI( CreateNewItem( L"06D", ns.ntValue, iovalue.vtInteger, 030B25H )); H^.AddChild( I ); E2^.Items[eiDay] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"06M", ns.ntValue, iovalue.vtInteger, 030B26H )); H^.AddChild( I ); E2^.Items[eiMonth] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"06Y", ns.ntValue, iovalue.vtInteger, 030B27H )); H^.AddChild( I ); E2^.Items[eiYear] := I; I^.Multiplier := 2; // special code for dword type
		I := TPNSI( CreateNewItem( L"Error 06 Code", ns.ntValue, iovalue.vtInteger, 030B28H )); D^.AddChild( I ); I^.Multiplier := 2; // special code for dword type
		E1^.Peer := E2; E2^.Peer := E1;
		// 29 empty

		E1 := CreateErrorItem( L"Error 07 Time" ); D^.AddChild( E1 );
		   I := TPNSI( CreateNewItem( L"07m", ns.ntValue, iovalue.vtInteger, 030B2AH )); H^.AddChild( I ); E1^.Items[eiMinute] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"07H", ns.ntValue, iovalue.vtInteger, 030B2BH )); H^.AddChild( I ); E1^.Items[eiHour] := I; I^.Multiplier := 2; // special code for dword type
		E2 := CreateErrorItem( L"Error 07 Date" ); D^.AddChild( E2 );
		   I := TPNSI( CreateNewItem( L"07D", ns.ntValue, iovalue.vtInteger, 030B2CH )); H^.AddChild( I ); E2^.Items[eiDay] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"07M", ns.ntValue, iovalue.vtInteger, 030B2DH )); H^.AddChild( I ); E2^.Items[eiMonth] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"07Y", ns.ntValue, iovalue.vtInteger, 030B2EH )); H^.AddChild( I ); E2^.Items[eiYear] := I; I^.Multiplier := 2; // special code for dword type
		I := TPNSI( CreateNewItem( L"Error 07 Code", ns.ntValue, iovalue.vtInteger, 030B2FH )); D^.AddChild( I ); I^.Multiplier := 2; // special code for dword type
		E1^.Peer := E2; E2^.Peer := E1;
		// 30 empty

		E1 := CreateErrorItem( L"Error 08 Time" ); D^.AddChild( E1 );
		   I := TPNSI( CreateNewItem( L"08m", ns.ntValue, iovalue.vtInteger, 030B31H )); H^.AddChild( I ); E1^.Items[eiMinute] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"08H", ns.ntValue, iovalue.vtInteger, 030B32H )); H^.AddChild( I ); E1^.Items[eiHour] := I; I^.Multiplier := 2; // special code for dword type
		E2 := CreateErrorItem( L"Error 08 Date" ); D^.AddChild( E2 );
		   I := TPNSI( CreateNewItem( L"08D", ns.ntValue, iovalue.vtInteger, 030B33H )); H^.AddChild( I ); E2^.Items[eiDay] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"08M", ns.ntValue, iovalue.vtInteger, 030B34H )); H^.AddChild( I ); E2^.Items[eiMonth] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"08Y", ns.ntValue, iovalue.vtInteger, 030B35H )); H^.AddChild( I ); E2^.Items[eiYear] := I; I^.Multiplier := 2; // special code for dword type
		I := TPNSI( CreateNewItem( L"Error 08 Code", ns.ntValue, iovalue.vtInteger, 030B36H )); D^.AddChild( I ); I^.Multiplier := 2; // special code for dword type
		E1^.Peer := E2; E2^.Peer := E1;
		// 37 empty

		E1 := CreateErrorItem( L"Error 09 Time" ); D^.AddChild( E1 );
		   I := TPNSI( CreateNewItem( L"09m", ns.ntValue, iovalue.vtInteger, 030B38H )); H^.AddChild( I ); E1^.Items[eiMinute] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"09H", ns.ntValue, iovalue.vtInteger, 030B39H )); H^.AddChild( I ); E1^.Items[eiHour] := I; I^.Multiplier := 2; // special code for dword type
		E2 := CreateErrorItem( L"Error 09 Date" ); D^.AddChild( E2 );
		   I := TPNSI( CreateNewItem( L"09D", ns.ntValue, iovalue.vtInteger, 030B3AH )); H^.AddChild( I ); E2^.Items[eiDay] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"09M", ns.ntValue, iovalue.vtInteger, 030B3BH )); H^.AddChild( I ); E2^.Items[eiMonth] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"09Y", ns.ntValue, iovalue.vtInteger, 030B3CH )); H^.AddChild( I ); E2^.Items[eiYear] := I; I^.Multiplier := 2; // special code for dword type
		I := TPNSI( CreateNewItem( L"Error 09 Code", ns.ntValue, iovalue.vtInteger, 030B3DH )); D^.AddChild( I ); I^.Multiplier := 2; // special code for dword type
		E1^.Peer := E2; E2^.Peer := E1;
		// 3E empty

		E1 := CreateErrorItem( L"Error 10 Time" ); D^.AddChild( E1 );
		   I := TPNSI( CreateNewItem( L"10m", ns.ntValue, iovalue.vtInteger, 030B3FH )); H^.AddChild( I ); E1^.Items[eiMinute] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"10H", ns.ntValue, iovalue.vtInteger, 030B40H )); H^.AddChild( I ); E1^.Items[eiHour] := I; I^.Multiplier := 2; // special code for dword type
		E2 := CreateErrorItem( L"Error 10 Date" ); D^.AddChild( E2 );
		   I := TPNSI( CreateNewItem( L"10D", ns.ntValue, iovalue.vtInteger, 030B41H )); H^.AddChild( I ); E2^.Items[eiDay] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"10M", ns.ntValue, iovalue.vtInteger, 030B42H )); H^.AddChild( I ); E2^.Items[eiMonth] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"10Y", ns.ntValue, iovalue.vtInteger, 030B43H )); H^.AddChild( I ); E2^.Items[eiYear] := I; I^.Multiplier := 2; // special code for dword type
		I := TPNSI( CreateNewItem( L"Error 10 Code", ns.ntValue, iovalue.vtInteger, 030B44H )); D^.AddChild( I ); I^.Multiplier := 2; // special code for dword type
		E1^.Peer := E2; E2^.Peer := E1;
		// 45 empty

		E1 := CreateErrorItem( L"Error 11 Time" ); D^.AddChild( E1 );
		   I := TPNSI( CreateNewItem( L"11m", ns.ntValue, iovalue.vtInteger, 030B46H )); H^.AddChild( I ); E1^.Items[eiMinute] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"11H", ns.ntValue, iovalue.vtInteger, 030B47H )); H^.AddChild( I ); E1^.Items[eiHour] := I; I^.Multiplier := 2; // special code for dword type
		E2 := CreateErrorItem( L"Error 11 Date" ); D^.AddChild( E2 );
		   I := TPNSI( CreateNewItem( L"11D", ns.ntValue, iovalue.vtInteger, 030B48H )); H^.AddChild( I ); E2^.Items[eiDay] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"11M", ns.ntValue, iovalue.vtInteger, 030B49H )); H^.AddChild( I ); E2^.Items[eiMonth] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"11Y", ns.ntValue, iovalue.vtInteger, 030B4AH )); H^.AddChild( I ); E2^.Items[eiYear] := I; I^.Multiplier := 2; // special code for dword type
		I := TPNSI( CreateNewItem( L"Error 11 Code", ns.ntValue, iovalue.vtInteger, 030B4BH )); D^.AddChild( I ); I^.Multiplier := 2; // special code for dword type
		E1^.Peer := E2; E2^.Peer := E1;
		// 4C empty

		E1 := CreateErrorItem( L"Error 12 Time" ); D^.AddChild( E1 );
		   I := TPNSI( CreateNewItem( L"12m", ns.ntValue, iovalue.vtInteger, 030B4DH )); H^.AddChild( I ); E1^.Items[eiMinute] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"12H", ns.ntValue, iovalue.vtInteger, 030B4EH )); H^.AddChild( I ); E1^.Items[eiHour] := I; I^.Multiplier := 2; // special code for dword type
		E2 := CreateErrorItem( L"Error 12 Date" ); D^.AddChild( E2 );
		   I := TPNSI( CreateNewItem( L"12D", ns.ntValue, iovalue.vtInteger, 030B4FH )); H^.AddChild( I ); E2^.Items[eiDay] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"12M", ns.ntValue, iovalue.vtInteger, 030B50H )); H^.AddChild( I ); E2^.Items[eiMonth] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"12Y", ns.ntValue, iovalue.vtInteger, 030B51H )); H^.AddChild( I ); E2^.Items[eiYear] := I; I^.Multiplier := 2; // special code for dword type
		I := TPNSI( CreateNewItem( L"Error 12 Code", ns.ntValue, iovalue.vtInteger, 030B52H )); D^.AddChild( I ); I^.Multiplier := 2; // special code for dword type
		E1^.Peer := E2; E2^.Peer := E1;
		// 53 empty

		E1 := CreateErrorItem( L"Error 13 Time" ); D^.AddChild( E1 );
		   I := TPNSI( CreateNewItem( L"13m", ns.ntValue, iovalue.vtInteger, 030B54H )); H^.AddChild( I ); E1^.Items[eiMinute] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"13H", ns.ntValue, iovalue.vtInteger, 030B55H )); H^.AddChild( I ); E1^.Items[eiHour] := I; I^.Multiplier := 2; // special code for dword type
		E2 := CreateErrorItem( L"Error 13 Date" ); D^.AddChild( E2 );
		   I := TPNSI( CreateNewItem( L"13D", ns.ntValue, iovalue.vtInteger, 030B56H )); H^.AddChild( I ); E2^.Items[eiDay] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"13M", ns.ntValue, iovalue.vtInteger, 030B57H )); H^.AddChild( I ); E2^.Items[eiMonth] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"13Y", ns.ntValue, iovalue.vtInteger, 030B58H )); H^.AddChild( I ); E2^.Items[eiYear] := I; I^.Multiplier := 2; // special code for dword type
		I := TPNSI( CreateNewItem( L"Error 13 Code", ns.ntValue, iovalue.vtInteger, 030B59H )); D^.AddChild( I ); I^.Multiplier := 2; // special code for dword type
		E1^.Peer := E2; E2^.Peer := E1;
		// 5A empty

		E1 := CreateErrorItem( L"Error 14 Time" ); D^.AddChild( E1 );
		   I := TPNSI( CreateNewItem( L"14m", ns.ntValue, iovalue.vtInteger, 030B5BH )); H^.AddChild( I ); E1^.Items[eiMinute] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"14H", ns.ntValue, iovalue.vtInteger, 030B5CH )); H^.AddChild( I ); E1^.Items[eiHour] := I; I^.Multiplier := 2; // special code for dword type
		E2 := CreateErrorItem( L"Error 14 Date" ); D^.AddChild( E2 );
		   I := TPNSI( CreateNewItem( L"14D", ns.ntValue, iovalue.vtInteger, 030B5DH )); H^.AddChild( I ); E2^.Items[eiDay] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"14M", ns.ntValue, iovalue.vtInteger, 030B5EH )); H^.AddChild( I ); E2^.Items[eiMonth] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"14Y", ns.ntValue, iovalue.vtInteger, 030B5FH )); H^.AddChild( I ); E2^.Items[eiYear] := I; I^.Multiplier := 2; // special code for dword type
		I := TPNSI( CreateNewItem( L"Error 14 Code", ns.ntValue, iovalue.vtInteger, 030B60H )); D^.AddChild( I ); I^.Multiplier := 2; // special code for dword type
		E1^.Peer := E2; E2^.Peer := E1;
		// 61 empty

		E1 := CreateErrorItem( L"Error 15 Time" ); D^.AddChild( E1 );
		   I := TPNSI( CreateNewItem( L"15m", ns.ntValue, iovalue.vtInteger, 030B62H )); H^.AddChild( I ); E1^.Items[eiMinute] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"15H", ns.ntValue, iovalue.vtInteger, 030B63H )); H^.AddChild( I ); E1^.Items[eiHour] := I; I^.Multiplier := 2; // special code for dword type
		E2 := CreateErrorItem( L"Error 15 Date" ); D^.AddChild( E2 );
		   I := TPNSI( CreateNewItem( L"15D", ns.ntValue, iovalue.vtInteger, 030B64H )); H^.AddChild( I ); E2^.Items[eiDay] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"15M", ns.ntValue, iovalue.vtInteger, 030B65H )); H^.AddChild( I ); E2^.Items[eiMonth] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"15Y", ns.ntValue, iovalue.vtInteger, 030B66H )); H^.AddChild( I ); E2^.Items[eiYear] := I; I^.Multiplier := 2; // special code for dword type
		I := TPNSI( CreateNewItem( L"Error 15 Code", ns.ntValue, iovalue.vtInteger, 030B67H )); D^.AddChild( I ); I^.Multiplier := 2; // special code for dword type
		E1^.Peer := E2; E2^.Peer := E1;
		// 68 empty

		E1 := CreateErrorItem( L"Error 16 Time" ); D^.AddChild( E1 );
		   I := TPNSI( CreateNewItem( L"16m", ns.ntValue, iovalue.vtInteger, 030B69H )); H^.AddChild( I ); E1^.Items[eiMinute] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"16H", ns.ntValue, iovalue.vtInteger, 030B6AH )); H^.AddChild( I ); E1^.Items[eiHour] := I; I^.Multiplier := 2; // special code for dword type
		E2 := CreateErrorItem( L"Error 16 Date" ); D^.AddChild( E2 );
		   I := TPNSI( CreateNewItem( L"16D", ns.ntValue, iovalue.vtInteger, 030B6BH )); H^.AddChild( I ); E2^.Items[eiDay] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"16M", ns.ntValue, iovalue.vtInteger, 030B6CH )); H^.AddChild( I ); E2^.Items[eiMonth] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"16Y", ns.ntValue, iovalue.vtInteger, 030B6DH )); H^.AddChild( I ); E2^.Items[eiYear] := I; I^.Multiplier := 2; // special code for dword type
		I := TPNSI( CreateNewItem( L"Error 16 Code", ns.ntValue, iovalue.vtInteger, 030B6EH )); D^.AddChild( I ); I^.Multiplier := 2; // special code for dword type
		E1^.Peer := E2; E2^.Peer := E1;
		// 6F empty

		E1 := CreateErrorItem( L"Error 17 Time" ); D^.AddChild( E1 );
		   I := TPNSI( CreateNewItem( L"17m", ns.ntValue, iovalue.vtInteger, 030B70H )); H^.AddChild( I ); E1^.Items[eiMinute] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"17H", ns.ntValue, iovalue.vtInteger, 030B71H )); H^.AddChild( I ); E1^.Items[eiHour] := I; I^.Multiplier := 2; // special code for dword type
		E2 := CreateErrorItem( L"Error 17 Date" ); D^.AddChild( E2 );
		   I := TPNSI( CreateNewItem( L"17D", ns.ntValue, iovalue.vtInteger, 030B72H )); H^.AddChild( I ); E2^.Items[eiDay] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"17M", ns.ntValue, iovalue.vtInteger, 030B73H )); H^.AddChild( I ); E2^.Items[eiMonth] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"17Y", ns.ntValue, iovalue.vtInteger, 030B74H )); H^.AddChild( I ); E2^.Items[eiYear] := I; I^.Multiplier := 2; // special code for dword type
		I := TPNSI( CreateNewItem( L"Error 17 Code", ns.ntValue, iovalue.vtInteger, 030B75H )); D^.AddChild( I ); I^.Multiplier := 2; // special code for dword type
		E1^.Peer := E2; E2^.Peer := E1;
		// 76 empty

		E1 := CreateErrorItem( L"Error 18 Time" ); D^.AddChild( E1 );
		   I := TPNSI( CreateNewItem( L"18m", ns.ntValue, iovalue.vtInteger, 030B77H )); H^.AddChild( I ); E1^.Items[eiMinute] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"18H", ns.ntValue, iovalue.vtInteger, 030B78H )); H^.AddChild( I ); E1^.Items[eiHour] := I; I^.Multiplier := 2; // special code for dword type
		E2 := CreateErrorItem( L"Error 18 Date" ); D^.AddChild( E2 );
		   I := TPNSI( CreateNewItem( L"18D", ns.ntValue, iovalue.vtInteger, 030B79H )); H^.AddChild( I ); E2^.Items[eiDay] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"18M", ns.ntValue, iovalue.vtInteger, 030B7AH )); H^.AddChild( I ); E2^.Items[eiMonth] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"18Y", ns.ntValue, iovalue.vtInteger, 030B7BH )); H^.AddChild( I ); E2^.Items[eiYear] := I; I^.Multiplier := 2; // special code for dword type
		I := TPNSI( CreateNewItem( L"Error 18 Code", ns.ntValue, iovalue.vtInteger, 030B7CH )); D^.AddChild( I ); I^.Multiplier := 2; // special code for dword type
		E1^.Peer := E2; E2^.Peer := E1;
		// 7D empty

		E1 := CreateErrorItem( L"Error 19 Time" ); D^.AddChild( E1 );
		   I := TPNSI( CreateNewItem( L"19m", ns.ntValue, iovalue.vtInteger, 030B7EH )); H^.AddChild( I ); E1^.Items[eiMinute] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"19H", ns.ntValue, iovalue.vtInteger, 030B7FH )); H^.AddChild( I ); E1^.Items[eiHour] := I; I^.Multiplier := 2; // special code for dword type
		E2 := CreateErrorItem( L"Error 19 Date" ); D^.AddChild( E2 );
		   I := TPNSI( CreateNewItem( L"19D", ns.ntValue, iovalue.vtInteger, 030B80H )); H^.AddChild( I ); E2^.Items[eiDay] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"19M", ns.ntValue, iovalue.vtInteger, 030B81H )); H^.AddChild( I ); E2^.Items[eiMonth] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"19Y", ns.ntValue, iovalue.vtInteger, 030B82H )); H^.AddChild( I ); E2^.Items[eiYear] := I; I^.Multiplier := 2; // special code for dword type
		I := TPNSI( CreateNewItem( L"Error 19 Code", ns.ntValue, iovalue.vtInteger, 030B83H )); D^.AddChild( I ); I^.Multiplier := 2; // special code for dword type
		E1^.Peer := E2; E2^.Peer := E1;
		// 84 empty

		E1 := CreateErrorItem( L"Error 20 Time" ); D^.AddChild( E1 );
		   I := TPNSI( CreateNewItem( L"20m", ns.ntValue, iovalue.vtInteger, 030B85H )); H^.AddChild( I ); E1^.Items[eiMinute] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"20H", ns.ntValue, iovalue.vtInteger, 030B86H )); H^.AddChild( I ); E1^.Items[eiHour] := I; I^.Multiplier := 2; // special code for dword type
		E2 := CreateErrorItem( L"Error 20 Date" ); D^.AddChild( E2 );
		   I := TPNSI( CreateNewItem( L"20D", ns.ntValue, iovalue.vtInteger, 030B87H )); H^.AddChild( I ); E2^.Items[eiDay] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"20M", ns.ntValue, iovalue.vtInteger, 030B88H )); H^.AddChild( I ); E2^.Items[eiMonth] := I; I^.Multiplier := 2; // special code for dword type
		   I := TPNSI( CreateNewItem( L"20Y", ns.ntValue, iovalue.vtInteger, 030B89H )); H^.AddChild( I ); E2^.Items[eiYear] := I; I^.Multiplier := 2; // special code for dword type
		I := TPNSI( CreateNewItem( L"Error 20 Code", ns.ntValue, iovalue.vtInteger, 030B8AH )); D^.AddChild( I ); I^.Multiplier := 2; // special code for dword type
		E1^.Peer := E2; E2^.Peer := E1;
		// 8B empty

	END CreateStructure;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE CreateNewItem( CONST Name : ARRAY OF WCHAR; NType : ns.TNameType; VType : iovalue.TValueType; Data : PTR ) : ns.TPnsItem;
	VAR
		R : nsitem.TPnsItem;
	BEGIN
		NEW( TPNSI( R ))^.Init( Name, ConstNames, NType, VType, Data );
		RETURN R;
	END CreateNewItem;

(*---------------------------------------------------------------------------*)

	PRIVATE PROCEDURE CreateErrorItem( CONST Name : ARRAY OF WCHAR ) : TPErrorNSI;
	VAR
		R : TPErrorNSI;
	BEGIN
		NEW( R )^.Init( Name, ConstNames, ns.ntValue, iovalue.vtDate, 0 );
		RETURN R;
	END CreateErrorItem;

(*---------------------------------------------------------------------------*)

BEGIN
	Initialize();
END CNS;

(*===========================================================================*)

CLASS IMPLEMENTATION CDeviceCommunicator;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Running GET : BOOLEAN;
   BEGIN
      RETURN Connection.Connected;
   END Running;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Start() : Sync.TAsyncResult;
   BEGIN
   	_PoolDelegate.TimeoutSink := ADR( SELF );

      Logger.LogS( log.ldMessage, 0, L"StiebelHP", L"Started" );
      RETURN Connection.OpenS( _DeviceAddress, DEFAULT_PORT, TRUE, 500 );
   END Start;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Stop();
   BEGIN
   	_PoolDelegate.TimeoutSink := NIL;

      StopTimeout( REF _TxTimeoutHandle );
      StopTimeout( REF _RxTimeoutHandle );

      Connection.Close();
      Logger.LogS( log.ldMessage, 0, L"StiebelHP", L"Stopped" );

   	  LogConfig.DisposeAppenderList( REF _AppenderList );
   END Stop;

(*---------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnTimeout( Result : Sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR );
   VAR
      EmptyData : StorageO.CMemoryBuffer;
   BEGIN
      IF PoolHandle = _TxTimeoutHandle THEN
	      Logger.LogS( log.ldTrace, 0, L"", L"Tx timeout" );
         OnTx( Sync.arTimeout );
      ELSIF PoolHandle = _RxTimeoutHandle THEN
	      Logger.LogS( log.ldTrace, 0, L"", L"Rx timeout" );
         OnRx( Sync.arTimeout, EmptyData );
      END;
   END OnTimeout;

(*---------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnConnect( Result : CARDINAL; CONST Socket : netsocket.TPDSocket; Local : BOOLEAN ); 
   BEGIN
      IF Result = 0 THEN
         Connection.BufferedStream^.StartReading();
      END;
   END OnConnect;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnReadable( Length : CARDINAL; Source : ADDRESS );
   VAR
      Data : StorageO.CMemoryBuffer;
   BEGIN
      Connection.Stream^.ReadBuffer( 2048, REF Data, 0 );
      HandleRx( Sync.arCompleted, REF Data );
      Connection.BufferedStream^.StartReading();
   END OnReadable;

(*---------------------------------------------------------------------------*)

	INTERNAL VIRTUAL PROCEDURE DataComplete( CONST Data : StorageO.AMemoryBuffer; OUT FirstIndexAfterData, FirstIndexAfterFrame : CARDINAL; OUT ApplyCheckSum : BOOLEAN ) : BOOLEAN;
	BEGIN
		IF Data.Length < SIZE( TPacket ) THEN
			RETURN FALSE;
		END;
		FirstIndexAfterData := SIZE( TPacket );
		FirstIndexAfterFrame := SIZE( TPacket );
		ApplyCheckSum := TRUE;
		RETURN TRUE;
	END DataComplete;

(*---------------------------------------------------------------------------*)

	INTERNAL VIRTUAL PROCEDURE TestChkSum( CONST Data : StorageO.AMemoryBuffer ) : BOOLEAN;
	VAR
		CRC : CARD16 := 0;
		i : CARDINAL;
		l : CARDINAL := Data.Length-2;
	BEGIN
		FOR i := 0 TO l-1 DO // omit last two bytes
			INC( CRC, PCARD8( Data.Data@[i] )^ );
		END; // FOR
		RETURN TPBE( Data.Data@[l] )^.LU = CRC;
	END TestChkSum;

(*---------------------------------------------------------------------------*)

	INTERNAL VIRTUAL PROCEDURE OnRx( Result : Sync.TAsyncResult; CONST Data : StorageO.AMemoryBuffer );
	BEGIN
      StopTimeout( REF _TxTimeoutHandle );
		IF Result <> Sync.arCompleted THEN
		   StopTimeout( REF _RxTimeoutHandle );
			PIO^.OnRx( Result, NIL );
		ELSIF PLONGWORD( Data.Data )^ = 055555555H THEN
   		StopTimeout( REF _RxTimeoutHandle ); // no need to wait for Rx timeout, when data was written
			PIO^.OnTxCON( Sync.arCompleted );
		ELSE
		   StopTimeout( REF _RxTimeoutHandle );
			PIO^.OnRx( Sync.arCompleted, TPPacket( Data.Data ));
		END;
	END OnRx;

(*---------------------------------------------------------------------------*)

	INTERNAL VIRTUAL PROCEDURE AddChkSum( REF Data : StorageO.AMemoryBuffer );
	VAR
		CRC : CARD16 := 0;
		i : CARDINAL;
		l : CARDINAL := Data.Length-2;
	BEGIN
		FOR i := 0 TO l-1 DO // omit last two bytes
			INC( CRC, PCARD8( Data.Data@[i] )^ );
		END; // FOR
		TPBE( Data.Data@[l] )^.LU := CRC;
	END AddChkSum;

(*---------------------------------------------------------------------------*)

	INTERNAL VIRTUAL PROCEDURE OnTx( Result : Sync.TAsyncResult );
	BEGIN
		IF Result <> Sync.arCompleted THEN
			PIO^.OnTxCON( Result );
		END;
	END OnTx;

(*---------------------------------------------------------------------------*)

	PUBLIC PROCEDURE Configure( CONST iniFile : INIFile.CINIFile; CONST iniFileSection : StringsO.IString; CONST Log : log.TPLogger ) : Sync.TAsyncResult;
   CONST
      keyDateFormat = L"date_format";
      keyHost = L"host";
      keyTimeFormat = L"time_format";
   VAR
      Result : Sync.TAsyncResult := Sync.arCompleted;

	   (*----------*)

	   PROCEDURE LogError( line : CARDINAL; errorText : CARDINAL; CONST addonText : StringsO.TPString );
	   VAR
	      msg : StringsO.CString;
	   BEGIN
	      Result := Sync.arAborted;

	      msg.FromOA( OAsz( R[errorText] ));
	      IF addonText <> NIL THEN
	         msg.Append( addonText^ );
	      END;
	      Log^.LogFilePos( log.lcError, 0, L"StiebelHP", L"", OA( msg.Length-1, msg.Data ), line, 0 );
	   END LogError;

	   (*----------*)

   VAR
      l : CARDINAL;
	BEGIN
	   IF iniFile.SetSection( OA( iniFileSection.Length-1, iniFileSection.Data )) THEN
         LogConfig.ConfigureLog( iniFile, OA( iniFileSection.Length-1, iniFileSection.Data ), REF Logger, REF _AppenderList, OUT l );

         // mandatory keys
         IF NOT iniFile.GetKeyStr( keyHost, OUT l, OUT _DeviceAddress ) THEN
            LogError( l, Texts._HostKeyMissing, NIL );
         END;

         // optional keys
         IF NOT iniFile.GetKeyStr( keyTimeFormat, OUT l, OUT PIO^.TimeFormat ) THEN
            PIO^.TimeFormat .Clear();
         END;
         IF NOT iniFile.GetKeyStr( keyDateFormat, OUT l, OUT PIO^.DateFormat ) THEN
            PIO^.DateFormat .Clear();
         END;

	   ELSE
         LogError( 0, Texts._ConfigurationSectionMissing, ADR( iniFileSection ));
      END;
      RETURN Result;
	END Configure;

(*---------------------------------------------------------------------------*)

	PUBLIC PROCEDURE Tx( CONST Data : ARRAY OF BYTE; _SendAsIs : BOOLEAN; _RepeatCount : CARDINAL; _TxTimeout, _RxTimeout : CARDINAL );
	VAR
	   c : CARDINAL;
	   Result : Sync.TAsyncResult;
	   TxBuffer : StorageO.CMemoryBuffer;
	BEGIN
	   IF NOT Connection.Connected THEN
	      Logger.LogS( log.ldTrace, 0, L"", L"Disconnected, trying to reconnect" );
         Connection.OpenS( _DeviceAddress, DEFAULT_PORT, TRUE, 500 );
	   END;
	
		IF INTEGER( HIGH( Data )) >= 0 THEN // HACK
   	   TxBuffer.Size := 1024;
			TxBuffer.AppendOA( Data );
			IF NOT _SendAsIs THEN
				AddChkSum( REF TxBuffer );
			END;
		END;
		
		IF _TxTimeout > 0 THEN
		   StartTimeout( _TxTimeout, REF _TxTimeoutHandle );
		END;
		IF _RxTimeout > 0 THEN
		   StartTimeout( _RxTimeout, REF _RxTimeoutHandle );
		END;

		Logger.LogSCB( log.ldDebug, 0, L'', L'tx start of ', TxBuffer.Length, TxBuffer.Data, TxBuffer.Length );
		Result := Connection.Stream^.WriteBuffer( TxBuffer, OUT c, netsocket.FORSAFETY );
		IF Result = Sync.arTimeout THEN
		   ASSERTLOG( FALSE );
		END;
	END Tx;

//---------------------------------------------------------

   PUBLIC PROCEDURE Abort();
   BEGIN
      StopTimeout( REF _TxTimeoutHandle );
      StopTimeout( REF _RxTimeoutHandle );
		Connection.Stream^.AbortWriting();
   END Abort;

//---------------------------------------------------------

	PRIVATE PROCEDURE HandleRx( Result : Sync.TAsyncResult; REF Data : StorageO.AMemoryBuffer ) : BOOLEAN;
	VAR
		LDI, LI : CARDINAL := 0; // TODO
		LRxBuffer : StorageO.CMemoryBuffer;
		TDI, TI : CARDINAL;
		AC : BOOLEAN; // apply checksum
		ChkSumOK : BOOLEAN := TRUE;
	BEGIN
		IF Result <> Sync.arCompleted THEN
			Logger.LogSC( log.ldError, 0, L'', L'rx error: ', CARDINAL( Result ));
			OnRx( Result, LRxBuffer );
			RxBuffer.Clear();
			RETURN FALSE;
		ELSIF NOT Data.Empty THEN
			RxBuffer.Append( Data );
			Logger.LogSCB( log.ldDebug, 0, L'', L'rx success, len: ', Data.Length, Data.Data, Data.Length );
		END;

      (* // TODO
		IF NOT DetectDataStart( RxBuffer, OUT LI, OUT LDI ) THEN
			RETURN FALSE;
		ELSIF LI > 0 THEN
			RxBuffer.RemoveStart( LI );
			DEC( LDI, LI );
			LI := 0;
		END;
		*)

		IF NOT DataComplete( RxBuffer, OUT TDI, OUT TI, OUT AC ) THEN
			RETURN FALSE;
		END;

		IF AC THEN
			RxBuffer.Subbuffer( LI, TI - LI, OUT LRxBuffer );
			ChkSumOK := TestChkSum( LRxBuffer );
		END;
		IF ChkSumOK THEN
			RxBuffer.Subbuffer( LDI, TDI - LDI, OUT LRxBuffer );
		   OnRx( Result, LRxBuffer );
		END;

		IF RxBuffer.Length = TI THEN
			RxBuffer.Clear();
		ELSE
			RxBuffer.RemoveStart( TI );
		END;
		RETURN NOT RxBuffer.Empty;
	END HandleRx;

//---------------------------------------------------------

   PRIVATE PROCEDURE StartTimeout( TimeoutMS : CARDINAL; REF Handle : threadpool.TPoolHandle );
   BEGIN
      IF Handle <> NIL THEN
         StopTimeout( REF Handle );
         ASSERTLOG( FALSE );
      END;

      threadpool.pool()^.WaitTimeout( ADR( _PoolDelegate ), 0, TimeoutMS, TRUE, FALSE, OUT Handle );
   END StartTimeout;

//---------------------------------------------------------

   PRIVATE PROCEDURE StopTimeout( REF Handle : threadpool.TPoolHandle );
   BEGIN
      IF Handle = NIL THEN
         RETURN;
      END;
      threadpool.pool()^.Abort( REF Handle );
   END StopTimeout;

//---------------------------------------------------------

BEGIN
   Connection.Notifier := ADR( SELF );
	PIO := NIL;
	_RxTimeoutHandle := 0;
	_TxTimeoutHandle := 0;
END CDeviceCommunicator;

(*===========================================================================*)

CLASS IMPLEMENTATION CIO;

(*---------------------------------------------------------------------------*)

	PUBLIC PROCEDURE Dispose();
	BEGIN
	END Dispose;

(*---------------------------------------------------------------------------*)

	PUBLIC PROPERTY Running GET : BOOLEAN;
	BEGIN
	   RETURN DeviceCommunicator.Running;
	END Running;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Start() : Sync.TAsyncResult;
   BEGIN
      _LastError.SetNowLocal();
      RETURN DeviceCommunicator.Start();
   END Start;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Stop();
   BEGIN
      DeviceCommunicator.Stop();
   END Stop;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY IOCapabilities GET : io.TCapabilities;
   BEGIN
      RETURN io.TCapabilities{};
   END IOCapabilities;

(*---------------------------------------------------------------------------*)

	PUBLIC PROPERTY Pending GET : BOOLEAN;
	BEGIN
		RETURN _Pending <> IOO.dirUnknown;
	END Pending;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Advise GET : io.TAdvise;
   BEGIN
      RETURN io.advNone;
   END Advise;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Advise SET( Value : io.TAdvise );
   BEGIN
      ASSERT( FALSE );
   END Advise;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY AdviseListener GET : io.TPIAdviseInfo;
   BEGIN
      RETURN NIL;
   END AdviseListener;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY AdviseListener SET( Value : io.TPIAdviseInfo );
   BEGIN
      ASSERT( FALSE );
   END AdviseListener;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE IOh( CONST Originator : io.TPOriginator; Direction : IOO.TDirection; Item : ns.THash; REF Value : iovalue.Value; Delegate : io.TPDataInfo ) : Sync.TAsyncResult;
	VAR
		Packet : TPacket;
		Result : Sync.TAsyncResult;
	BEGIN
		IF _Pending <> IOO.dirUnknown THEN
			RETURN Sync.arAlreadyPending;
		ELSIF ns.TPnsItem( Item )^ IS CErrorNSI THEN // composite item, which must be communicated by parts
		   RETURN CompositeIO( Direction, Item, Delegate );
		ELSIF ADDRESS( Item ) = _ErrorOccurred THEN
		   IF Direction = IOO.dirWrite THEN
		      TPNSI( Item )^.Multiplier := INTEGER( Value.Boolean ); // Multiplier used as local storage of value (a new error occured)
		   ELSE
		      Value.Boolean := BOOLEAN( TPNSI( Item )^.Multiplier ); // Multiplier used as local storage of value (a new error occured)
		   END;
		   Result := Sync.arCompleted;
         Delegate^.OnIO( Direction, ADR( SELF ), OA( 0, ADR( Result )), OA( 0, ADR( Item )), OA( -1, NIL ), OA( 0, ADR( Value )));
		   RETURN Sync.arCompleted;
		END;

		_Pending := Direction;
		_Item := Item;
		_Callback := Delegate;
		
		Packet.Address := 0; // m2cpp error
		WITH Packet DO
			SenderType := dtController;
			Address := 0;
			ReceiverType := TDeviceType( LOPTRLONGWORD( nsitem.TPnsItem( Item )^.Data ) >> 16 );
			IF Direction = IOO.dirWrite THEN
				Telegram := ttSet;
			ELSE
				Telegram := ttGet;
			END;
			D1 := 0; // ??
			D2 := 0FAH; // ??
			PointNumber.LU := LOWORD( LOPTRLONGWORD( nsitem.TPnsItem( Item )^.Data ));
			IF Direction = IOO.dirWrite THEN
				IF TPNSI( Item )^.Multiplier = 1000 THEN
					D2 := 0FBH; // ??
					wValue.LU := 0;
				ELSIF TPNSI( Item )^.Multiplier = 1 THEN
					bValue := BYTE( Value.Integer );
				ELSE
					wValue.LS := INT16( Value.Float * LONGREAL( TPNSI( Item )^.Multiplier ));
				END;
			END;
		END;
		
		DeviceCommunicator.Tx( Packet, FALSE, 1, 150, 500 );
		// Serial.Tx( Packet, FALSE, 1, 0, 0 );

		RETURN Sync.arPending;
	END IOh;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE AbortAll();
	BEGIN
		DeviceCommunicator.Abort();
	END AbortAll;

(*---------------------------------------------------------------------------*)

   LOCAL PROCEDURE SetErrorOccurred( ErrorOccurred : TPNSI );
   BEGIN
      _ErrorOccurred := ErrorOccurred;
   END SetErrorOccurred;

(*---------------------------------------------------------------------------*)

	LOCAL PROCEDURE OnRx( Result : Sync.TAsyncResult; PPacket : TPPacket );
	VAR
		V : iovalue.Value;
	BEGIN
		IF _AbortFlag THEN
			_AbortFlag := FALSE;
			_Pending := IOO.dirUnknown;
			RETURN;
		ELSIF ( _Pending = IOO.dirWrite ) AND ( Result = Sync.arTimeout ) THEN
			// TODO
		   // tiemouted write
		ELSIF ( _Pending <> IOO.dirRead ) OR ( _Callback = NIL ) THEN
			RETURN;
		ELSE
			_Pending := IOO.dirUnknown;
		END;
		IF Result = Sync.arCompleted THEN
			IF _Item^.Multiplier = 1 THEN
				V.Float := LONGREAL( PPacket^.bValue );
			ELSIF _Item^.Multiplier = 2 THEN
				V.Float := LONGREAL( PPacket^.wValue.LS );
			ELSE
				V.Float := LONGREAL( PPacket^.wValue.LS ) / LONGREAL( _Item^.Multiplier );
			END;
			_Callback^.OnIO( IOO.dirRead, ADR( SELF ), OA( 0, ADR( Result )), OA( 0, ADR( _Item )), OA( -1, NIL ), OA( 0, ADR( V )));
		ELSIF _Pending = IOO.dirWrite THEN
			// TODO
			_Pending := IOO.dirUnknown;
			// TODO
			_Callback^.OnIO( IOO.dirWrite, ADR( SELF ), OA( 0, ADR( Result )), OA( 0, ADR( _Item )), OA( -1, NIL ), OA( 0, iovalue.TPValue( NIL )));
			_Callback^.OnError( IOO.dirWrite, ADR( SELF ), OA( 0, ADR( Result )), OA( 0, ADR( _Item )), OA( -1, NIL ));
		ELSE
			_Callback^.OnIO( IOO.dirRead, ADR( SELF ), OA( 0, ADR( Result )), OA( 0, ADR( _Item )), OA( -1, NIL ), OA( 0, iovalue.TPValue( NIL )));
			_Callback^.OnError( IOO.dirRead, ADR( SELF ), OA( 0, ADR( Result )), OA( 0, ADR( _Item )), OA( -1, NIL ));
		END;
	END OnRx;

(*---------------------------------------------------------------------------*)

	LOCAL PROCEDURE OnTxCON( Result : Sync.TAsyncResult );
	BEGIN
		IF _AbortFlag THEN
			_AbortFlag := FALSE;
			_Pending := IOO.dirUnknown;
			RETURN;
		ELSIF _Pending <> IOO.dirWrite THEN
			RETURN;
		END;
		_Pending := IOO.dirUnknown;
		IF Result = Sync.arCompleted THEN
			_Callback^.OnIO( IOO.dirWrite, ADR( SELF ), OA( 0, ADR( Result )), OA( 0, ADR( _Item )), OA( -1, NIL ), OA( 0, iovalue.TPValue( NIL )));
		ELSE
			_Callback^.OnIO( IOO.dirWrite, ADR( SELF ), OA( 0, ADR( Result )), OA( 0, ADR( _Item )), OA( -1, NIL ), OA( 0, iovalue.TPValue( NIL )));
			_Callback^.OnError( IOO.dirWrite, ADR( SELF ), OA( 0, ADR( Result )), OA( 0, ADR( _Item )), OA( -1, NIL ));
		END;
	END OnTxCON;

(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE CompositeIO( Direction : IOO.TDirection; Item : TPErrorNSI; Delegate : io.TPDataInfo ) : Sync.TAsyncResult;
   VAR
      b : BOOLEAN;
      delegate : io.CCompletionDataInfo;
      dt : datetime.DateTime;
      item : TErrorItem;
      itemFor : INTEGER;
      Result : Sync.TAsyncResult := Sync.arCompleted;
      s : ARRAY [0..255] OF WCHAR;
      V : iovalue.Value;
   BEGIN
      IF Direction = IOO.dirWrite THEN
         _Pending := IOO.dirWrite;
         _Callback := Delegate;
         OnTxCON( Sync.arCannotStart );
         RETURN Sync.arCannotStart;
      END;
      
      FOR itemFor := 0 TO 2 DO
         item := TErrorItem( itemFor );
         IF Item^.Items[item] <> NIL THEN
            delegate.Reset();
            Result := IOh( NIL, Direction, Item^.Items[item], REF Item^.Items[item]^.Value, ADR( delegate ));
            IF Result <> Sync.arPending THEN
               _Callback := Delegate; // change delegate used for reporting back
               OnRx( Result, NIL );
               RETURN Result;
            END;
            Result := delegate.WaitCompletion( Sync.FORSAFETY, OUT Item^.Items[item]^.Value );
            IF Result <> Sync.arCompleted THEN
               _Callback := Delegate; // change delegate used for reporting back
               OnRx( Result, NIL );
               RETURN Result;
            END;
         END;
      END; // FOR

      IF Item^.Items[eiYear] = NIL THEN // item is time
         dt.Minute := Item^.Items[eiMinute]^.Value.Integer;
         dt.Hour := Item^.Items[eiHour]^.Value.Integer;
         IF TimeFormat.Empty THEN // use default format
            b := dt.ToStringOA( L"HH:mm:ss", FALSE, TRUE, OUT s );
            IF NOT b THEN
               DeviceCommunicator.Logger.LogS( log.ldTrace, 0, L"StiebelHP", L"Conversion to date string failed, format: HH:mm:ss" );
            END;
         ELSE
            b := dt.ToStringOA( OA( TimeFormat.Length-1, TimeFormat.Data ), FALSE, TRUE, OUT s );
            IF NOT b THEN
               DeviceCommunicator.Logger.LogSS( log.ldTrace, 0, L"StiebelHP", L"Conversion to time string failed, format:", OA( TimeFormat.Length-1, TimeFormat.Data ));
            END;
         END;
         dt.Day := Item^.Peer^.Items[eiDay]^.Value.Integer;
         dt.Month := Item^.Peer^.Items[eiMonth]^.Value.Integer;
         dt.Year := Item^.Peer^.Items[eiYear]^.Value.Integer;
      ELSE
         dt.Day := Item^.Items[eiDay]^.Value.Integer;
         dt.Month := Item^.Items[eiMonth]^.Value.Integer;
         dt.Year := Item^.Items[eiYear]^.Value.Integer + 2000;
         IF DateFormat.Empty THEN
            b := dt.ToStringOA( L"yyyy-MM-dd", TRUE, FALSE, OUT s );
            IF NOT b THEN
               DeviceCommunicator.Logger.LogS( log.ldTrace, 0, L"StiebelHP", L"Conversion to date string failed, format: yyyy-MM-dd" );
            END;
         ELSE
            b := dt.ToStringOA( OA( DateFormat.Length-1, DateFormat.Data ), TRUE, FALSE, OUT s );
            IF NOT b THEN
               DeviceCommunicator.Logger.LogSS( log.ldTrace, 0, L"StiebelHP", L"Conversion to date string failed, format:", OA( DateFormat.Length-1, DateFormat.Data ));
            END;
         END;
         dt.Minute := Item^.Peer^.Items[eiMinute]^.Value.Integer;
         dt.Hour := Item^.Peer^.Items[eiHour]^.Value.Integer;
      END;
      IF b THEN
         V.FromStringOA( s, FALSE );
      ELSE
         Result := Sync.arAborted;
      END;

      // change delegate used for reporting back
      _Callback := Delegate;
      _Callback^.OnIO( IOO.dirRead, ADR( SELF ), OA( 0, ADR( Result )), OA( 0, ADR( Item )), OA( -1, NIL ), OA( 0, ADR( V )));
      
      IF ( _ErrorOccurred <> NIL ) AND ( dt > _LastError ) THEN
         _ErrorOccurred^.Multiplier := 1; // Multiplier used as local storage of value (a new error occured)
         _LastError := dt;
      END;

      RETURN Result;
   END CompositeIO;

(*---------------------------------------------------------------------------*)

BEGIN
	DeviceCommunicator.PIO := ADR( SELF );
	_AbortFlag := FALSE;
	_Pending := IOO.dirUnknown;
	_Callback := NIL;
	_Item := NIL;
   _ErrorOccurred := NIL;
FINALLY
	Dispose();
END CIO;

(*===========================================================================*)

CLASS IMPLEMENTATION CStiebelHPDevice;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY Type GET : iobject.TObjectType;
   BEGIN
      RETURN iobject.otEphemeral;
   END Type;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY Library GET : iobject.TPLibrary;
   BEGIN
      RETURN SUPER.Library;
   END Library;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY Library SET( Value : iobject.TPLibrary );
   BEGIN
      SUPER.Library := Value;
   END Library;

(*---------------------------------------------------------------------------*)

	PUBLIC FINAL PROCEDURE OnDispose();
	BEGIN
		_IO.Dispose();
	END OnDispose;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY DeviceCapabilities GET : device.TCapabilities;
   BEGIN
      RETURN device.TCapabilities{device.capNamespace};
   END DeviceCapabilities;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Mapper() : ns.TPMapper;
   BEGIN
      RETURN ADR( _NS );
   END Mapper;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE NS() : ns.TPns;
	BEGIN
		RETURN ADR( _NS );
	END NS;
	
(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE IO() : io.TPIO;
	BEGIN
		RETURN ADR( _IO );
	END IO;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE Configure( CONST Source : ARRAY OF device.TConfigureItem; CONST Log : log.TPLogger ) : Sync.TAsyncResult;
	VAR
	   hash : ns.THash;
	   name : StringsO.CString;
   BEGIN
      IF HIGH( Source ) < 0 THEN
         RETURN Sync.arCannotStart;
      ELSIF Source[0].Type <> device.citINIFileSection THEN
         RETURN Sync.arCannotStart;
      END;
      
      // set error element
      name.FromOA( L"StiebelHP.Data.Error occurred" );
      IF _NS.NameToHash( name, OUT hash ) THEN
         _IO.SetErrorOccurred( TPNSI( hash ));
      END;
      
      RETURN _IO.DeviceCommunicator.Configure( Source[0]._iniFile^, Source[0].section^, Log );
   END Configure;
   
(*---------------------------------------------------------------------------*)

BEGIN FINALLY
   _IO.Stop();
	OnDispose();
END CStiebelHPDevice;

(*===========================================================================*)

BEGIN
   R.LoadRES2( EMIT( %dll ), L"StiebelHP.Texts" );
END StiebelHP.
