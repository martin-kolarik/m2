IMPLEMENTATION MODULE StiebelHP;

(*===========================================================================*)

FROM Storage IMPORT
	ALLOCATE;
	
IMPORT
	FIO,
	IOO,
	StorageO,
	StringsO,
	Sync;

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
#restore

(*---------------------------------------------------------------------------*)

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

CLASS CNSI( nsitem.CnsItem );
	LOCAL VAR
		Multiplier : CARDINAL;
END CNSI;

CLASS IMPLEMENTATION CNSI;
BEGIN
	Multiplier := 10;
END CNSI;

(*===========================================================================*)

CLASS IMPLEMENTATION CNS;

(*---------------------------------------------------------------------------*)

	INTERNAL VIRTUAL PROCEDURE CreateRoot() : sdns.TPSDNSItem;
	BEGIN
		RETURN CreateNewItem( L"StiebelHP", sdvalue.sdtName, 0 );
	END CreateRoot;

(*---------------------------------------------------------------------------*)

	INTERNAL VIRTUAL PROCEDURE CreateStructure();
	VAR
	  D : nsitem.TPnsItem;
	  I : TPNSI;
	BEGIN
		Root^.AddChild( CreateNewItem( L"Control", sdvalue.sdtName, 0 ));

		D := nsitem.TPnsItem( CreateNewItem( L"Data", sdvalue.sdtName, 0 ));
		Root^.AddChild( D );

		I := TPNSI( CreateNewItem( L"Reset",             sdvalue.sdtInteger, 098000H )); D^.AddChild( I ); I^.Multiplier := 1000;
		I := TPNSI( CreateNewItem( L"OperatingMode",     sdvalue.sdtInteger, 030112H )); D^.AddChild( I ); I^.Multiplier := 1;
		I := TPNSI( CreateNewItem( L"EquithermicCurve",  sdvalue.sdtFloat,   03010EH )); D^.AddChild( I ); I^.Multiplier := 100;
		// I := TPNSI( CreateNewItem( L"T setpoint",        sdvalue.sdtFloat,   030008H )); D^.AddChild( I );

		I := TPNSI( CreateNewItem( L"Inner T",           sdvalue.sdtFloat,   060011H )); D^.AddChild( I );
		I := TPNSI( CreateNewItem( L"Inner T setpoint",  sdvalue.sdtFloat,   060005H )); D^.AddChild( I );
		I := TPNSI( CreateNewItem( L"Outer T",           sdvalue.sdtFloat,   03000CH )); D^.AddChild( I );
		I := TPNSI( CreateNewItem( L"Return T",          sdvalue.sdtFloat,   030016H )); D^.AddChild( I );
		I := TPNSI( CreateNewItem( L"Return T setpoint", sdvalue.sdtFloat,   060004H )); D^.AddChild( I );
		I := TPNSI( CreateNewItem( L"Output T",          sdvalue.sdtFloat,   0301D6H )); D^.AddChild( I );

		I := TPNSI( CreateNewItem( L"Water T",           sdvalue.sdtFloat,   03000EH )); D^.AddChild( I );
		I := TPNSI( CreateNewItem( L"Water T setpoint",  sdvalue.sdtFloat,   030003H )); D^.AddChild( I );
	END CreateStructure;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE CreateNewItem( CONST Name : ARRAY OF WCHAR; Type : sdvalue.TSDType; Data : PTR ) : sdns.TPSDNSItem;
	VAR
		R : nsitem.TPnsItem;
	BEGIN
		NEW( TPNSI( R ))^.Init( Name, ConstNames, Type, Data );
		RETURN R;
	END CreateNewItem;

(*---------------------------------------------------------------------------*)

BEGIN
	Initialize();
END CNS;

(*===========================================================================*)

CLASS IMPLEMENTATION CSerial;

(*---------------------------------------------------------------------------*)

	INTERNAL VIRTUAL PROCEDURE DataComplete( CONST Data : StorageO.CMemoryBuffer; OUT FirstIndexAfterData, FirstIndexAfterFrame : CARDINAL; OUT ApplyCheckSum : BOOLEAN ) : BOOLEAN;
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

	INTERNAL VIRTUAL PROCEDURE TestChkSum( CONST Data : StorageO.CMemoryBuffer ) : BOOLEAN;
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

(*---------------------------------------------------------------------------*)

	INTERNAL VIRTUAL PROCEDURE OnRx( Result : Sync.TAsyncResult; CONST Data : StorageO.CMemoryBuffer );
	BEGIN
		IF Result <> Sync.arCompleted THEN
			PIO^.OnRx( Result, NIL );
		ELSIF PLONGWORD( Data.Data )^ = 055555555H THEN
			PIO^.OnTxCON( Sync.arCompleted );
		ELSE
			PIO^.OnRx( Sync.arCompleted, TPPacket( Data.Data ));
		END;
	END OnRx;

(*---------------------------------------------------------------------------*)

	INTERNAL VIRTUAL PROCEDURE AddChkSum( REF Data : StorageO.CMemoryBuffer );
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

(*---------------------------------------------------------------------------*)

	INTERNAL VIRTUAL PROCEDURE OnTx( Result : Sync.TAsyncResult );
	BEGIN
		IF Result <> Sync.arCompleted THEN
			PIO^.OnTxCON( Result );
		END;
	END OnTx;

(*---------------------------------------------------------------------------*)

BEGIN
	PIO := NIL;
END CSerial;

(*===========================================================================*)

CLASS IMPLEMENTATION CIO;

(*---------------------------------------------------------------------------*)

	PUBLIC PROPERTY Pending GET : BOOLEAN;
	BEGIN
		RETURN _Pending <> IOO.dirUnknown;
	END Pending;

(*---------------------------------------------------------------------------*)

	PUBLIC PROCEDURE Dispose();
	BEGIN
		Serial.Dispose();
	END Dispose;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE IOh( Direction : IOO.TDirection; Item : ns.THash; REF Value : iovalue.Value; Callback : sdio.TPSDCallback ) : Sync.TAsyncResult;
	VAR
		Packet : TPacket;
	BEGIN
		IF _Pending <> IOO.dirUnknown THEN
			RETURN Sync.arAlreadyPending;
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
				IF TPNSI( Item )^.Multiplier = 1000 THEN
					D2 := 0FBH; // ??
					wValue.LE := 0;
				ELSIF TPNSI( Item )^.Multiplier = 1 THEN
					bValue := BYTE( Value.Integer );
				ELSE
					wValue.LE := WORD( Value.Float * LONGREAL( TPNSI( Item )^.Multiplier ));
				END;
			END;
		END;
		
		Serial.Tx( Packet, FALSE, 1, 150, 500 );
		// Serial.Tx( Packet, FALSE, 1, 0, 0 );

		RETURN Sync.arPending;
	END IOh;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE Abort();
	BEGIN
		_AbortFlag := TRUE;
	END Abort;

(*---------------------------------------------------------------------------*)

	LOCAL PROCEDURE OnRx( Result : Sync.TAsyncResult; PPacket : TPPacket );
	VAR
		V : sdvalue.CSDFloat;
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
				V.Value := LONGREAL( PPacket^.bValue );
			ELSE
				V.Value := LONGREAL( PPacket^.wValue.LE ) / LONGREAL( _Item^.Multiplier );
			END;
			_Callback^.OnIO( IOO.dirRead, ADR( SELF ), OA( 0, ADR( Result )), OA( 0, ADR( _Item )), OA( 0, ADR( V )));
		ELSIF _Pending = IOO.dirWrite THEN
			// TODO
			_Pending := IOO.dirUnknown;
			// TODO
			_Callback^.OnIO( IOO.dirWrite, ADR( SELF ), OA( 0, ADR( Result )), OA( 0, ADR( _Item )), OA( 0, sdvalue.TPSDValue( NIL )));
			_Callback^.OnError( IOO.dirWrite, ADR( SELF ), OA( 0, PCARDINAL( ADR( Result ))), OA( 0, ADR( _Item )));
		ELSE
			_Callback^.OnIO( IOO.dirRead, ADR( SELF ), OA( 0, ADR( Result )), OA( 0, ADR( _Item )), OA( 0, sdvalue.TPSDValue( NIL )));
			_Callback^.OnError( IOO.dirRead, ADR( SELF ), OA( 0, PCARDINAL( ADR( Result ))), OA( 0, ADR( _Item )));
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
			_Callback^.OnIO( IOO.dirWrite, ADR( SELF ), OA( 0, ADR( Result )), OA( 0, ADR( _Item )), OA( 0, sdvalue.TPSDValue( NIL )));
		ELSE
			_Callback^.OnIO( IOO.dirWrite, ADR( SELF ), OA( 0, ADR( Result )), OA( 0, ADR( _Item )), OA( 0, sdvalue.TPSDValue( NIL )));
			_Callback^.OnError( IOO.dirWrite, ADR( SELF ), OA( 0, PCARDINAL( ADR( Result ))), OA( 0, ADR( _Item )));
		END;
	END OnTxCON;

(*---------------------------------------------------------------------------*)

BEGIN
	Serial.PIO := ADR( SELF );
	_AbortFlag := FALSE;
	_Pending := IOO.dirUnknown;
	_Callback := NIL;
	_Item := NIL;
FINALLY
	Dispose();
END CIO;

(*===========================================================================*)

CLASS IMPLEMENTATION CStiebelHPDevice;

(*---------------------------------------------------------------------------*)

	PUBLIC PROCEDURE Dispose();
	BEGIN
		_IO.Dispose();
	END Dispose;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE NS() : sdns.TPSDNS;
	BEGIN
		RETURN ADR( _NS );
	END NS;
	
(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE IO() : sdio.TPSDIO;
	BEGIN
		RETURN ADR( _IO );
	END IO;

(*---------------------------------------------------------------------------*)

	PUBLIC PROCEDURE Init( COMDevice, File : ARRAY OF WCHAR; OUT ErrorString : ARRAY OF WCHAR ) : BOOLEAN;
	BEGIN
		RETURN _IO.Serial.Init( L"SS", COMDevice, L"SerialWin32.DLL", File, OUT ErrorString );
	END Init;
	
(*---------------------------------------------------------------------------*)

	PUBLIC PROCEDURE Run();
	BEGIN
		_IO.Serial.Run();
	END Run;

(*---------------------------------------------------------------------------*)

	PUBLIC PROCEDURE Stop();
	BEGIN
		_IO.Serial.Stop();
	END Stop;

(*---------------------------------------------------------------------------*)

BEGIN FINALLY
	Stop();
	Dispose();
END CStiebelHPDevice;

(*===========================================================================*)

END StiebelHP.