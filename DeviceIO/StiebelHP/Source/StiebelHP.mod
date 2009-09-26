IMPLEMENTATION MODULE StiebelHP;

(*================================================================================*)

FROM Debug IMPORT
   Assertion, LogAssertionW;

IMPORT
	FIO,
	iobject,
	IOO,
	resources,
	StorageO,
	StringsO,
	Sync,
	Texts;

(*================================================================================*)

VAR
   R : resources.CResources;

(*================================================================================*)

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
	  I : TPNSI;
	BEGIN
		Root^.AddChild( CreateNewItem( L"Control", ns.ntName, iovalue.vtString, 0 ));

		D := nsitem.TPnsItem( CreateNewItem( L"Data", ns.ntName, iovalue.vtString, 0 ));
		Root^.AddChild( D );

		I := TPNSI( CreateNewItem( L"Reset",                         ns.ntValue, iovalue.vtInteger, 098000H )); D^.AddChild( I ); I^.Multiplier := 1000;
		I := TPNSI( CreateNewItem( L"OperatingMode",                 ns.ntValue, iovalue.vtInteger, 030112H )); D^.AddChild( I ); I^.Multiplier := 1;
		I := TPNSI( CreateNewItem( L"EquithermicCurve",              ns.ntValue, iovalue.vtFloat,   03010EH )); D^.AddChild( I ); I^.Multiplier := 100;
		// I := TPNSI( CreateNewItem( L"T setpoint",        iovalue.vtFloat,   030008H )); D^.AddChild( I );

		I := TPNSI( CreateNewItem( L"Inner T",                       ns.ntValue, iovalue.vtFloat,   060011H )); D^.AddChild( I );
		I := TPNSI( CreateNewItem( L"Inner T setpoint",              ns.ntValue, iovalue.vtFloat,   060005H )); D^.AddChild( I );
		I := TPNSI( CreateNewItem( L"Outer T",                       ns.ntValue, iovalue.vtFloat,   03000CH )); D^.AddChild( I );
		I := TPNSI( CreateNewItem( L"Return T",                      ns.ntValue, iovalue.vtFloat,   030016H )); D^.AddChild( I );
		I := TPNSI( CreateNewItem( L"Return T setpoint",             ns.ntValue, iovalue.vtFloat,   060004H )); D^.AddChild( I );
		I := TPNSI( CreateNewItem( L"Output T",                      ns.ntValue, iovalue.vtFloat,   0301D6H )); D^.AddChild( I );

		I := TPNSI( CreateNewItem( L"Water T",                       ns.ntValue, iovalue.vtFloat,   03000EH )); D^.AddChild( I );
		I := TPNSI( CreateNewItem( L"Water T setpoint",              ns.ntValue, iovalue.vtFloat,   030003H )); D^.AddChild( I );

		I := TPNSI( CreateNewItem( L"Pump 1 Service Hours",          ns.ntValue, iovalue.vtInteger, 0301C4H )); D^.AddChild( I );
		I := TPNSI( CreateNewItem( L"Pump 2 Service Hours",          ns.ntValue, iovalue.vtInteger, 0301C5H )); D^.AddChild( I );
		I := TPNSI( CreateNewItem( L"Bivalent Supply Service Hours", ns.ntValue, iovalue.vtInteger, 0301CBH )); D^.AddChild( I );
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
      Logger.LogS( log.dldMessage, L"StiebelHP", L"Started" );
      RETURN Connection.OpenS( _DeviceAddress, TRUE, 500 );
   END Start;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Stop();
   BEGIN
      Connection.Close();
      Logger.LogS( log.dldMessage, L"StiebelHP", L"Stopped" );
   END Stop;

(*---------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnTimeout( Result : Sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR );
   VAR
      EmptyData : StorageO.CMemoryBuffer;
   BEGIN
      IF PoolHandle = _TxTimeoutHandle THEN
	      Logger.LogS( log.dldTrace, L"", L"Tx timeout" );
         OnTx( Sync.arTimeout );
      ELSIF PoolHandle = _RxTimeoutHandle THEN
	      Logger.LogS( log.dldTrace, L"", L"Rx timeout" );
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
		RETURN TPBE( Data.Data@[l] )^.LE = CRC;
	END TestChkSum;

(*---------------------------------------------------------------------------*)

	INTERNAL VIRTUAL PROCEDURE OnRx( Result : Sync.TAsyncResult; CONST Data : StorageO.AMemoryBuffer );
	BEGIN
      StopTimeout( REF _TxTimeoutHandle );
		IF Result <> Sync.arCompleted THEN
		   StopTimeout( REF _RxTimeoutHandle );
			PIO^.OnRx( Result, NIL );
		ELSIF PLONGWORD( Data.Data )^ = 055555555H THEN
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

	PUBLIC PROCEDURE Configure( CONST iniFile : INIFile.CINIFile; CONST iniFileSection : StringsO.IString; CONST Log : log.TPLogger ) : Sync.TAsyncResult;
   CONST
      keyHost = L"host";
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
	      Log^.LogFilePos( log.dlcError, L"StiebelHP", L"", OA( msg.Length-1, msg.rawData ), line, 0 );
	   END LogError;

	   (*----------*)

   VAR
      l : CARDINAL;
	BEGIN
	   IF iniFile.SetSection( OA( iniFileSection.Length-1, iniFileSection.rawData )) THEN
         INIFile.ConfigureLog( iniFile, OA( iniFileSection.Length-1, iniFileSection.rawData ), REF Logger, OUT l );
         IF NOT iniFile.GetKeyStr( keyHost, OUT l, OUT _DeviceAddress ) THEN
            LogError( l, Texts._HostKeyMissing, NIL );
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
	      Logger.LogS( log.dldTrace, L"", L"Disconnected, trying to reconnect" );
         Connection.OpenS( _DeviceAddress, TRUE, 500 );
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

		Logger.LogSCB( log.dldDebug, L'', L'tx start of ', TxBuffer.Length, TxBuffer.Data, TxBuffer.Length );
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
			Logger.LogSC( log.dldError, L'', L'rx error: ', CARDINAL( Result ));
			OnRx( Result, LRxBuffer );
			RxBuffer.Clear();
			RETURN FALSE;
		ELSIF NOT Data.Empty THEN
			RxBuffer.Append( Data );
			Logger.LogSCB( log.dldDebug, L'', L'rx success, len: ', Data.Length, Data.Data, Data.Length );
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
      ASSERTLOG( Handle = NIL );
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
	_PoolDelegate.TimeoutSink := ADR( SELF );
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

   PUBLIC VIRTUAL PROCEDURE IOh( Direction : IOO.TDirection; Item : ns.THash; REF Value : iovalue.Value; Delegate : io.TPDataInfo ) : Sync.TAsyncResult;
	VAR
		Packet : TPacket;
	BEGIN
		IF _Pending <> IOO.dirUnknown THEN
			RETURN Sync.arAlreadyPending;
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
			PointNumber.LE := LOWORD( LOPTRLONGWORD( nsitem.TPnsItem( Item )^.Data ));
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
			ELSE
				V.Float := LONGREAL( PPacket^.wValue.LE ) / LONGREAL( _Item^.Multiplier );
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

BEGIN
	DeviceCommunicator.PIO := ADR( SELF );
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
   BEGIN
      IF HIGH( Source ) < 0 THEN
         RETURN Sync.arCannotStart;
      ELSIF Source[0].Type <> device.citINIFileSection THEN
         RETURN Sync.arCannotStart;
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