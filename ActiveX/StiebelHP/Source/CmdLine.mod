MODULE CmdLine;

// setpoint process.value control.value

FROM Storage IMPORT
	ALLOCATE, DEALLOCATE;
	
IMPORT
	FIO,
	IOO,
	Log,
	StorageO,
	StringsO,
	Sync,
	threadinit,
	windows;

IMPORT
	nsitem,
	device,
	io,
	iplugin,
	ns,
	iovalue,
	serial;
	
(*===========================================================================*)

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
		BE : WORD; // big endian
		LE : WORD; // little endian
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
	TPPacket  = POINTER TO TPacket;
#restore

CLASS IMPLEMENTATION CBE;

	PUBLIC PROPERTY BE GET : WORD;
	BEGIN
		RETURN _Data;
	END BE;

	PUBLIC PROPERTY BE SET( Value : WORD );
	BEGIN
		_Data := Value;
	END BE;

	PUBLIC PROPERTY LE GET : WORD;
	BEGIN
		RETURN ( _Data AND 0FFH << 8 ) OR ( _Data >> 8 );
	END LE;

	PUBLIC PROPERTY LE SET( Value : WORD );
	BEGIN
		_Data := ( Value AND 0FFH << 8 ) OR ( Value >> 8 );
	END LE;

BEGIN
	_Data := 0;
END CBE;

(*===========================================================================*)

TYPE
	TPNSI = POINTER TO CNSI;

CLASS CNSI( nsitem.CnsItem );
	LOCAL VAR
		Multiplier : CARDINAL;
END CNSI;

CLASS IMPLEMENTATION CNSI;
BEGIN
	Multiplier := 10;
END CNSI;

(*===========================================================================*)

CLASS CNS( nsitem.Ans );
	INTERNAL VIRTUAL PROCEDURE CreateRoot() : ns.TPnsItem;
	INTERNAL VIRTUAL PROCEDURE CreateStructure();
   PUBLIC VIRTUAL PROCEDURE HashToName( CONST Hash : ns.THash; OUT Name : StringsO.IString ) : BOOLEAN;
	PUBLIC VIRTUAL PROCEDURE CreateNewItem( CONST Name : ARRAY OF WCHAR; NameType : ns.TNameType; ValueType : iovalue.TValueType; Data : PTR ) : ns.TPnsItem;
END CNS;

TYPE
	TPIO = POINTER TO CIO;

CLASS CSerial( serial.CSerialHandler );
	LOCAL VAR
		PIO : TPIO;

	INTERNAL VIRTUAL PROCEDURE DataComplete( CONST Data : StorageO.AMemoryBuffer; OUT FirstIndexAfterData, FirstIndexAfterFrame : CARDINAL; OUT ApplyCheckSum : BOOLEAN ) : BOOLEAN;
	INTERNAL VIRTUAL PROCEDURE TestChkSum( CONST Data : StorageO.AMemoryBuffer ) : BOOLEAN;
	INTERNAL VIRTUAL PROCEDURE OnRx( Result : Sync.TAsyncResult; CONST Data : StorageO.AMemoryBuffer );

	INTERNAL VIRTUAL PROCEDURE AddChkSum( REF Data : StorageO.AMemoryBuffer );
	INTERNAL VIRTUAL PROCEDURE OnTx( Result : Sync.TAsyncResult );
END CSerial;

CLASS CIO( io.AItemizedIO );
	LOCAL VAR
		Serial : CSerial;
	PRIVATE VAR
		_AbortFlag : BOOLEAN;
		_Pending : IOO.TDirection;
		_Item : TPNSI;
		_Callback : io.TPDataInfo;

   PUBLIC VIRTUAL READONLY PROPERTY
      IOCapabilities : io.TCapabilities;
      Pending : BOOLEAN;
      Running : BOOLEAN;
   PUBLIC VIRTUAL PROPERTY
      Advise : io.TAdvise;
      AdviseListener : io.TPIAdviseInfo; // for Advise <> advNone

   PUBLIC VIRTUAL PROCEDURE Run() : Sync.TAsyncResult;
   PUBLIC VIRTUAL PROCEDURE Stop();
   PUBLIC VIRTUAL PROCEDURE AbortAll();

	PUBLIC VIRTUAL PROCEDURE IOh( Direction : IOO.TDirection; Item : ns.THash; REF Value : iovalue.Value; Delegate : io.TPDataInfo ) : Sync.TAsyncResult;
	PUBLIC VIRTUAL PROCEDURE Abort();

	LOCAL PROCEDURE OnRx( Result : Sync.TAsyncResult; PPacket : TPPacket );
	LOCAL PROCEDURE OnTxCON( Result : Sync.TAsyncResult );
END CIO;

CLASS IMPLEMENTATION CNS;

	INTERNAL VIRTUAL PROCEDURE CreateRoot() : ns.TPnsItem;
	BEGIN
		RETURN CreateNewItem( L"StiebelHP", ns.ntName, iovalue.vtUnknown, 0 );
	END CreateRoot;

	INTERNAL VIRTUAL PROCEDURE CreateStructure();
	VAR
	  D : nsitem.TPnsItem;
	  I : TPNSI;
	BEGIN
		Root^.AddChild( CreateNewItem( L"Control", ns.ntName, iovalue.vtUnknown, 0 ));

		D := nsitem.TPnsItem( CreateNewItem( L"Data", ns.ntName, iovalue.vtUnknown, 0 ));
		Root^.AddChild( D );

		I := TPNSI( CreateNewItem( L"OperatingMode",     ns.ntValue, iovalue.vtInteger, 030112H )); D^.AddChild( I ); I^.Multiplier := 1;
		I := TPNSI( CreateNewItem( L"EquithermicCurve",  ns.ntValue, iovalue.vtFloat,   03010EH )); D^.AddChild( I ); I^.Multiplier := 100;
		// I := TPNSI( CreateNewItem( L"T setpoint",        iovalue.vtFloat,   030008H )); D^.AddChild( I );

		I := TPNSI( CreateNewItem( L"Inner T",           ns.ntValue, iovalue.vtFloat,   060011H )); D^.AddChild( I );
		I := TPNSI( CreateNewItem( L"Inner T setpoint",  ns.ntValue, iovalue.vtFloat,   060005H )); D^.AddChild( I );
		I := TPNSI( CreateNewItem( L"Outer T",           ns.ntValue, iovalue.vtFloat,   03000CH )); D^.AddChild( I );
		I := TPNSI( CreateNewItem( L"Return T",          ns.ntValue, iovalue.vtFloat,   030016H )); D^.AddChild( I );
		I := TPNSI( CreateNewItem( L"Return T setpoint", ns.ntValue, iovalue.vtFloat,   060004H )); D^.AddChild( I );
		I := TPNSI( CreateNewItem( L"Output T",          ns.ntValue, iovalue.vtFloat,   0301D6H )); D^.AddChild( I );

		I := TPNSI( CreateNewItem( L"Water T",           ns.ntValue, iovalue.vtFloat,   03000EH )); D^.AddChild( I );
		I := TPNSI( CreateNewItem( L"Water T setpoint",  ns.ntValue, iovalue.vtFloat,   030003H )); D^.AddChild( I );
	END CreateStructure;

	PUBLIC VIRTUAL PROCEDURE CreateNewItem( CONST Name : ARRAY OF WCHAR; NameType : ns.TNameType; ValueType : iovalue.TValueType; Data : PTR ) : ns.TPnsItem;
	VAR
		R : nsitem.TPnsItem;
	BEGIN
		NEW( TPNSI( R ))^.Init( Name, ConstNames, NameType, ValueType, Data );
		RETURN R;
	END CreateNewItem;

   PUBLIC VIRTUAL PROCEDURE HashToName( CONST Hash : ns.THash; OUT Name : StringsO.IString ) : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END HashToName;

BEGIN
	Initialize();
END CNS;

CLASS IMPLEMENTATION CSerial;

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

	INTERNAL VIRTUAL PROCEDURE TestChkSum( CONST Data : StorageO.AMemoryBuffer ) : BOOLEAN;
	VAR
		CRC : CARD16 := 0;
		i : CARDINAL;
		l : CARDINAL := Data.Length-2;
	BEGIN
		FOR i := 0 TO l-1 DO // omit last two bytes
			INC( CRC, PCARD8( Data.Data@[i] )^ );
		END; // FOR
		RETURN TPBE( Data.Data@[l] )^.LE = CRC;
	END TestChkSum;

	INTERNAL VIRTUAL PROCEDURE OnRx( Result : Sync.TAsyncResult; CONST Data : StorageO.AMemoryBuffer );
	BEGIN
		IF Result <> Sync.arCompleted THEN
			PIO^.OnRx( Result, NIL );
		ELSIF PLONGWORD( Data.Data )^ = 055555555H THEN
			PIO^.OnTxCON( Sync.arCompleted );
		ELSE
			PIO^.OnRx( Sync.arCompleted, TPPacket( Data.Data ));
		END;
	END OnRx;

	INTERNAL VIRTUAL PROCEDURE AddChkSum( REF Data : StorageO.AMemoryBuffer );
	VAR
		CRC : CARD16 := 0;
		i : CARDINAL;
		l : CARDINAL := Data.Length-2;
	BEGIN
		FOR i := 0 TO l-1 DO // omit last two bytes
			INC( CRC, PCARD8( Data.Data@[i] )^ );
		END; // FOR
		TPBE( Data.Data@[l] )^.LE := CRC;
	END AddChkSum;

	INTERNAL VIRTUAL PROCEDURE OnTx( Result : Sync.TAsyncResult );
	BEGIN
		IF Result <> Sync.arCompleted THEN
			PIO^.OnTxCON( Result );
		END;
	END OnTx;

BEGIN
	PIO := NIL;
END CSerial;

CLASS IMPLEMENTATION CIO;

   PUBLIC VIRTUAL PROPERTY IOCapabilities GET : io.TCapabilities;
   BEGIN
      RETURN io.TCapabilities{};
   END IOCapabilities;
   
   PUBLIC VIRTUAL PROPERTY Running GET : BOOLEAN;
   BEGIN
      RETURN TRUE;
   END Running;

	PUBLIC VIRTUAL PROPERTY Pending GET : BOOLEAN;
	BEGIN
		RETURN _Pending <> IOO.dirUnknown;
	END Pending;

   PUBLIC VIRTUAL PROPERTY Advise GET : io.TAdvise;
   BEGIN
      RETURN io.advNone;
   END Advise;

   PUBLIC VIRTUAL PROPERTY Advise SET( Value : io.TAdvise );
   BEGIN
   END Advise;

   PUBLIC VIRTUAL PROPERTY AdviseListener GET : io.TPIAdviseInfo;
   BEGIN
      RETURN NIL;
   END AdviseListener;

   PUBLIC VIRTUAL PROPERTY AdviseListener SET( Value : io.TPIAdviseInfo );
   BEGIN
   END AdviseListener;

   PUBLIC VIRTUAL PROCEDURE Run() : Sync.TAsyncResult;
   BEGIN
      RETURN Sync.arCompleted;
   END Run;

   PUBLIC VIRTUAL PROCEDURE Stop();
   BEGIN
   END Stop;

   PUBLIC VIRTUAL PROCEDURE AbortAll();
   BEGIN
   END AbortAll;

	PUBLIC VIRTUAL PROCEDURE IOh( Direction : IOO.TDirection; Item : ns.THash; REF Value : iovalue.Value; Callback : io.TPDataInfo ) : Sync.TAsyncResult;
	VAR
		Packet : TPacket;
	BEGIN
		IF _Pending <> IOO.dirUnknown THEN
			RETURN Sync.arPending;
		END;

		_Pending := Direction;
		_Item := Item;
		_Callback := Callback;

		Packet.Address := 0; // m2cpp error
		WITH Packet DO
			SenderType := dtController;
			Address := 0;
			ReceiverType := TDeviceType( nsitem.TPnsItem( Item )^.Data >> 16 );
			IF Direction = IOO.dirWrite THEN
				Telegram := ttSet;
			ELSE
				Telegram := ttGet;
			END;
			D1 := 0; // ??
			D2 := 0FAH; // ??
			PointNumber.LE := WORD( nsitem.TPnsItem( Item )^.Data );
			IF Direction = IOO.dirWrite THEN
				IF TPNSI( Item )^.Multiplier = 1 THEN
					bValue := BYTE( Value.Integer );
				ELSE
					wValue.LE := WORD( Value.Float * LONGREAL( TPNSI( Item )^.Multiplier ));
				END;
			END;
		END;
		
		Serial.Tx( Packet, FALSE, 1, 150, 500 );
		// Serial.Tx( Packet, FALSE, 1, 0, 0 );

		RETURN Sync.arCannotStart;
	END IOh;

	PUBLIC VIRTUAL PROCEDURE Abort();
	BEGIN
		_AbortFlag := TRUE;
	END Abort;

	LOCAL PROCEDURE OnRx( Result : Sync.TAsyncResult; PPacket : TPPacket );
	VAR
		V : iovalue.Value;
	BEGIN
	   V.Type := iovalue.vtFloat;
		IF _AbortFlag THEN
			_AbortFlag := FALSE;
			_Pending := IOO.dirUnknown;
			RETURN;
		ELSIF ( _Pending <> IOO.dirRead ) OR ( _Callback = NIL ) THEN
			RETURN;
		ELSE
			_Pending := IOO.dirUnknown;
		END;
		IF Result = Sync.arCompleted THEN
			IF _Item^.Multiplier = 1 THEN
				V.Float := LONGREAL( PPacket^.bValue );
			ELSE
				V.Float := LONGREAL( PPacket^.wValue.LE ) / LONGREAL( _Item^.Multiplier );
			END;
			_Callback^.OnIO( IOO.dirRead, ADR( SELF ), OA( 0, ADR( Result )), OA( 0, ADR( _Item )), OA( -1, NIL ), OA( 0, ADR( V )));
		ELSE
			_Callback^.OnError( IOO.dirRead, ADR( SELF ), OA( 0, ADR( Result )), OA( 0, ADR( _Item )), OA( -1, NIL ));
		END;
	END OnRx;

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
			_Callback^.OnError( IOO.dirWrite, ADR( SELF ), OA( 0, ADR( Result )), OA( 0, ADR( _Item )), OA( -1, NIL ));
		END;
	END OnTxCON;

BEGIN
	Serial.PIO := ADR( SELF );
	_AbortFlag := FALSE;
	_Pending := IOO.dirUnknown;
	_Callback := NIL;
	_Item := NIL;
END CIO;

CLASS CCallback( io.CDataInfo );
END CCallback;

CLASS CStiebelHPDevice IMPLEMENTS device.IDevice, io.IDataInfo;
	PRIVATE VAR
		HConsole : FIO.File;
		_NS : CNS;
		_IO : CIO;
	PUBLIC VIRTUAL PROCEDURE NS() : ns.TPns;
	PUBLIC VIRTUAL PROCEDURE IO() : io.TPIO;

	PUBLIC PROCEDURE Init( File : ARRAY OF WCHAR );
	
	PUBLIC VIRTUAL READONLY PROPERTY
      Type : iplugin.TObjectType;
      OfPlugin : iplugin.TPPlugin;
      OwnerHandle : PTR;

   PUBLIC VIRTUAL READONLY PROPERTY
      DeviceCapabilities : device.TCapabilities;

	PUBLIC VIRTUAL PROCEDURE Configure( CONST Source : ARRAY OF device.TConfigureItem; CONST log : Log.TPLogger ) : Sync.TAsyncResult;
	PUBLIC VIRTUAL PROCEDURE Mapper() : ns.TPMapper;

   PUBLIC VIRTUAL PROCEDURE OnAdvise( Source : io.TPIO; CONST Result : ARRAY OF Sync.TAsyncResult; CONST Item : ARRAY OF ns.THash; CONST Value : ARRAY OF iovalue.Value );
   PUBLIC VIRTUAL PROCEDURE OnError( Direction : IOO.TDirection; Source : io.TPIO; CONST Result : ARRAY OF Sync.TAsyncResult; CONST Item : ARRAY OF ns.THash; CONST DeviceSpecificError : ARRAY OF CARDINAL );
   PUBLIC VIRTUAL PROCEDURE OnIO( Direction : IOO.TDirection; Source : io.TPIO; CONST Result : ARRAY OF Sync.TAsyncResult; CONST Item : ARRAY OF ns.THash; CONST DSE : ARRAY OF CARDINAL; CONST Value : ARRAY OF iovalue.Value );

END CStiebelHPDevice;

CLASS IMPLEMENTATION CStiebelHPDevice;

	PUBLIC VIRTUAL PROCEDURE NS() : ns.TPns;
	BEGIN
		RETURN ADR( _NS );
	END NS;
	
	PUBLIC VIRTUAL PROCEDURE IO() : io.TPIO;
	BEGIN
		RETURN ADR( _IO );
	END IO;

	PUBLIC PROCEDURE Init( File : ARRAY OF WCHAR );
	VAR
		L : Log.CLogger;
	BEGIN
		_IO.Serial.Init( L"SS", L"COM1", L"SerialWin32.DLL", File, ADR( L ));
		_IO.Serial.Run();
	END Init;

	PUBLIC VIRTUAL PROPERTY Type GET : iplugin.TObjectType;
	BEGIN
	   RETURN iplugin.otEphemeral;
	END Type;

   PUBLIC VIRTUAL PROPERTY OfPlugin GET : iplugin.TPPlugin;
   BEGIN
      RETURN NIL;
   END OfPlugin;

   PUBLIC VIRTUAL PROPERTY OwnerHandle GET : PTR;
   BEGIN
      RETURN NIL;
   END OwnerHandle;

   PUBLIC VIRTUAL PROPERTY DeviceCapabilities GET : device.TCapabilities;
   BEGIN
      RETURN device.TCapabilities{};
   END DeviceCapabilities;

	PUBLIC VIRTUAL PROCEDURE Configure( CONST Source : ARRAY OF device.TConfigureItem; CONST log : Log.TPLogger ) : Sync.TAsyncResult;
	BEGIN
	   RETURN Sync.arCannotStart;
	END Configure;
	
	PUBLIC VIRTUAL PROCEDURE Mapper() : ns.TPMapper;
	BEGIN
	   RETURN NIL;
	END Mapper;

  PUBLIC VIRTUAL PROCEDURE OnAdvise( Source : io.TPIO; CONST Result : ARRAY OF Sync.TAsyncResult; CONST Item : ARRAY OF ns.THash; CONST Value : ARRAY OF iovalue.Value );
  BEGIN
  END OnAdvise;

  PUBLIC VIRTUAL PROCEDURE OnError( Direction : IOO.TDirection; Source : io.TPIO; CONST Result : ARRAY OF Sync.TAsyncResult; CONST Item : ARRAY OF ns.THash; CONST DeviceSpecificError : ARRAY OF CARDINAL );
  BEGIN
  END OnError;

  PUBLIC VIRTUAL PROCEDURE OnIO( Direction : IOO.TDirection; Source : io.TPIO; CONST Result : ARRAY OF Sync.TAsyncResult; CONST Item : ARRAY OF ns.THash; CONST DSE : ARRAY OF CARDINAL; CONST Value : ARRAY OF iovalue.Value );
  VAR
      l : CARDINAL;
		s : StringsO.CString;
		sa : ARRAY [0..63] OF CHAR;
  BEGIN
		TPNSI( Item[0] )^.Name^.ToOAA( 0, OUT sa, OUT l );
		FIO.WrStrA( HConsole, sa ); FIO.WrStrA( HConsole, C": " );

		IF Direction = IOO.dirRead THEN
			// m2cpp error Value[0].ToString( OUT s );
			iovalue.TPValue( ADR( Value[0] ))^.ToString( OUT s, FALSE );
			s.ToOAA( 0, OUT sa, OUT l );
			FIO.WrStrA( HConsole, sa ); FIO.WrLnA( HConsole );
		ELSE
			FIO.WrStrA( HConsole, C"OK" ); FIO.WrLnA( HConsole );
		END;
  END OnIO;

BEGIN
	HConsole := windows.GetStdHandle( windows.STD_OUTPUT_HANDLE );
END CStiebelHPDevice;

CLASS IMPLEMENTATION CCallback;
BEGIN
END CCallback;

VAR
	StiebelHPDevice : CStiebelHPDevice;
	CB : CCallback;

PROCEDURE Wait( i : CARDINAL );
VAR
	msg : windows.MSG;
BEGIN
	LOOP
    WHILE windows.PeekMessage( ADR( msg ), NIL, 0, 0, windows.PM_REMOVE ) = windows.True DO
			windows.DispatchMessage( ADR( msg ));
		END;
		windows.Sleep( 10 );
		IF i > 0 THEN
			DEC( i );
			IF i = 0 THEN
				EXIT;
			END;
		END;
	END; // LOOP
END Wait;

#save, call( convention => cdecl )
PROCEDURE wmain();
#restore
VAR
	h : ns.THash;
	r : Sync.TAsyncResult;
	S : StringsO.CString;
	V : iovalue.Value;
	b : BOOLEAN;
BEGIN
   threadinit.Startup();
   CB.Sink := ADR( StiebelHPDevice );
   V.Type := iovalue.vtFloat;

	StiebelHPDevice.Init( L"D:\Work\SmartControl\Code\ActiveX\StiebelHP\~Debug\comst.par" );
	Wait( 65 );
	
	LOOP

   S.FromOA( L"StiebelHP.Data.Inner T" );
	b := StiebelHPDevice.NS()^.NameToHash( S, OUT h );
	LOOP
		r := StiebelHPDevice.IO()^.IOh( IOO.dirRead, h, REF V, ADR( CB ));
		IF r <> Sync.arPending THEN
			EXIT;
		END;
		Wait( 2 );
	END;

   S.FromOA( L"StiebelHP.Data.Inner T setpoint" );
	b := StiebelHPDevice.NS()^.NameToHash( S, OUT h );
	LOOP
		r := StiebelHPDevice.IO()^.IOh( IOO.dirRead, h, REF V, ADR( CB ));
		IF r <> Sync.arPending THEN
			EXIT;
		END;
		Wait( 2 );
	END;

   S.FromOA( L"StiebelHP.Data.Outer T" );
	b := StiebelHPDevice.NS()^.NameToHash( S, OUT h );
	LOOP
		r := StiebelHPDevice.IO()^.IOh( IOO.dirRead, h, REF V, ADR( CB ));
		IF r <> Sync.arPending THEN
			EXIT;
		END;
		Wait( 2 );
	END;

   S.FromOA( L"StiebelHP.Data.Outer T" );
	b := StiebelHPDevice.NS()^.NameToHash( S, OUT h );
	LOOP
		r := StiebelHPDevice.IO()^.IOh( IOO.dirRead, h, REF V, ADR( CB ));
		IF r <> Sync.arPending THEN
			EXIT;
		END;
		Wait( 2 );
	END;

   S.FromOA( L"StiebelHP.Data.Return T setpoint" );
	b := StiebelHPDevice.NS()^.NameToHash( S, OUT h );
	LOOP
		r := StiebelHPDevice.IO()^.IOh( IOO.dirRead, h, REF V, ADR( CB ));
		IF r <> Sync.arPending THEN
			EXIT;
		END;
		Wait( 2 );
	END;

   S.FromOA( L"StiebelHP.Data.Water T" );
	b := StiebelHPDevice.NS()^.NameToHash( S, OUT h );
	LOOP
		r := StiebelHPDevice.IO()^.IOh( IOO.dirRead, h, REF V, ADR( CB ));
		IF r <> Sync.arPending THEN
			EXIT;
		END;
		Wait( 2 );
	END;

   S.FromOA( L"StiebelHP.Data.Water T setpoint" );
	b := StiebelHPDevice.NS()^.NameToHash( S, OUT h );
	LOOP
		r := StiebelHPDevice.IO()^.IOh( IOO.dirRead, h, REF V, ADR( CB ));
		IF r <> Sync.arPending THEN
			EXIT;
		END;
		Wait( 2 );
	END;

   S.FromOA( L"StiebelHP.Data.Output T" );
	b := StiebelHPDevice.NS()^.NameToHash( S, OUT h );
	LOOP
		r := StiebelHPDevice.IO()^.IOh( IOO.dirRead, h, REF V, ADR( CB ));
		IF r <> Sync.arPending THEN
			EXIT;
		END;
		Wait( 2 );
	END;

(*
	V.Value := 20.0;
	b := StiebelHPDevice.NS()^.NameToHash( L"StiebelHP.Data.T setpoint", OUT h );
	LOOP
		r := StiebelHPDevice.IO()^.IOh( IOO.dirWrite, h, REF V, ADR( CB ));
		IF r <> Sync.arPending THEN
			EXIT;
		END;
		Wait( 2 );
	END;

	V.Value := 2.0;
	b := StiebelHPDevice.NS()^.NameToHash( L"StiebelHP.Data.OperatingMode", OUT h );
	LOOP
		r := StiebelHPDevice.IO()^.IOh( IOO.dirWrite, h, REF V, ADR( CB ));
		IF r <> Sync.arPending THEN
			EXIT;
		END;
		Wait( 2 );
	END;

   S.FromOA( L"StiebelHP.Data.EquithermicCurve" );
	V.Value := 0.77;
	b := StiebelHPDevice.NS()^.NameToHash( S, OUT h );
	LOOP
		r := StiebelHPDevice.IO()^.IOh( IOO.dirWrite, h, REF V, ADR( CB ));
		IF r <> Sync.arPending THEN
			EXIT;
		END;
		Wait( 2 );
	END;
*)	

   S.FromOA( L"StiebelHP.Data.T setpoint" );
	b := StiebelHPDevice.NS()^.NameToHash( S, OUT h );
	LOOP
		r := StiebelHPDevice.IO()^.IOh( IOO.dirRead, h, REF V, ADR( CB ));
		IF r <> Sync.arPending THEN
			EXIT;
		END;
		Wait( 2 );
	END;

   S.FromOA( L"StiebelHP.Data.OperatingMode" );
	b := StiebelHPDevice.NS()^.NameToHash( S, OUT h );
	LOOP
		r := StiebelHPDevice.IO()^.IOh( IOO.dirRead, h, REF V, ADR( CB ));
		IF r <> Sync.arPending THEN
			EXIT;
		END;
		Wait( 2 );
	END;
	
	S.FromOA( L"StiebelHP.Data.EquithermicCurve" );
	b := StiebelHPDevice.NS()^.NameToHash( S, OUT h );
	LOOP
		r := StiebelHPDevice.IO()^.IOh( IOO.dirRead, h, REF V, ADR( CB ));
		IF r <> Sync.arPending THEN
			EXIT;
		END;
		Wait( 2 );
	END;
	
		Wait( 400 );
	END; // LOOP

	Wait( 0 );
END wmain;

END CmdLine.