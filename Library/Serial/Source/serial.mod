IMPLEMENTATION MODULE serial;

FROM Storage IMPORT
	ALLOCATE, DEALLOCATE, Zero;

IMPORT
	FIO,
	Strings;

//=========================================================

TYPE
	TFocusedCBToLinkEvent = ARRAY TFocusedCB OF CARDINAL;
CONST
	cbToLink = TFocusedCBToLinkEvent(
		SerialLink.comfRxDataQueued,
		SerialLink.comfRxTimeout,
		SerialLink.comfTxTimeout,
		SerialLink.comfTxEmpty
	);
	
TYPE
	TTimeout = (
		tiTransmit,
		tiReceive,
		tiTransaction
	);

//=========================================================

(*# save, call( convention => cdecl ) *)
PROCEDURE LinkCallback( ObjectId : ADDRESS; Event, Param : CARDINAL );
FORWARD;
(*# restore *)

CONST // for timeouts
	tiTx = 1;
	tiRx = 2;

CLASS IMPLEMENTATION CSerialHandler;

//---------------------------------------------------------

  PUBLIC PROPERTY Running GET : BOOLEAN;
  BEGIN
		RETURN rsRun IN RStatus;
	END Running;

//---------------------------------------------------------

  PUBLIC PROPERTY ReadBack GET : BOOLEAN;
  BEGIN
		RETURN rsReadBack IN RStatus;
  END ReadBack;

//---------------------------------------------------------

  PUBLIC PROPERTY ReadBack SET( Value : BOOLEAN );
  BEGIN
		IF Value THEN
			Logger.LogS( Log.dlpAll, L'', L'tx/rx read back activated' );
			INCL( RStatus, rsReadBack );
		ELSE
			Logger.LogS( Log.dlpAll, L'', L'tx/rx read back stopped' );
			EXCL( RStatus, rsReadBack );
			ReadBackLen := 0;
		END;
  END ReadBack;

//---------------------------------------------------------

	PUBLIC PROPERTY RxW GET : BOOLEAN;
	BEGIN
		RETURN rsRxW IN RStatus;
	END RxW;

//---------------------------------------------------------

	PUBLIC PROPERTY RxW SET( Value : BOOLEAN );
	BEGIN
		IF Value THEN
			INCL( RStatus, rsRxW );
		ELSE
			EXCL( RStatus, rsRxW );
		END;
	END RxW;

//---------------------------------------------------------

	PUBLIC PROCEDURE Init( Name, Channel, Driver, Parameters : ARRAY OF WCHAR; OUT ErrorString : ARRAY OF WCHAR ) : BOOLEAN;
	VAR
		ChannelA, DriverA : ARRAY [0..63] OF CHAR;
		ParametersA : FIO.PathStrA;
		ErrorStringA : ARRAY [0..255] OF CHAR;
	BEGIN
		SUPER.Init();
		SELF.Name.FromOA( Name );
		Strings.ToA( Channel, 0, OUT ChannelA );
		Strings.ToA( Driver, 0, OUT DriverA );
		Strings.ToA( Parameters, 0, OUT ParametersA );
		IF SerialLink.OpenLinkEx( DriverA, ChannelA, ParametersA, FALSE, FALSE, ErrorStringA, ComLink, ComSession ) THEN
			Logger.LogSS( Log.dlpIO, L'', L'init success on ', Channel );
			RETURN TRUE;
		ELSE
			Strings.ToW( ErrorStringA, 0, OUT ErrorString );
			Logger.LogSSSS( Log.dlpIO, L'', L'init failed on ', Channel, L': ', ErrorString );
			RETURN FALSE;
		END;
	END Init;

//---------------------------------------------------------

	PUBLIC PROCEDURE Dispose();
	BEGIN
		Stop();
		IF ComLink <> NIL THEN
			SerialLink.CloseLink( ComLink, ComSession );
			Logger.LogS( Log.dlpIO, L'', L'channel closed' );
			ComLink := NIL;
		END;
		TxBuffer.Dispose();
		RxBuffer.Dispose();
		SUPER.Dispose();
	END Dispose;

//---------------------------------------------------------

	PUBLIC PROCEDURE SetInBoundaryStrings( Leading, Trailing : ARRAY OF WCHAR );
	BEGIN
		Strings.ToA( Leading, 0, OUT IBLS );
		Strings.ToA( Trailing, 0, OUT IBTS );
		IBLSLen := LENGTH( IBLS );
		IBTSLen := LENGTH( IBTS );
	END SetInBoundaryStrings;

//---------------------------------------------------------

	PUBLIC PROCEDURE SetOutBoundaryStrings( Leading, Trailing : ARRAY OF WCHAR );
	BEGIN
		Strings.ToA( Leading, 0, OUT OBLS );
		Strings.ToA( Trailing, 0, OUT OBTS );
		OBLSLen := LENGTH( OBLS );
		OBTSLen := LENGTH( OBTS );
	END SetOutBoundaryStrings;

//---------------------------------------------------------

	PUBLIC PROCEDURE Run();
	VAR
		CB : TFocusedCB;
		CM : BITSET;
	BEGIN
		IF rsRun IN RStatus THEN
			RETURN;
		END;
		CM := {};
		CB := fcbRxData;
		LOOP
			SerialLink.GetCommCallback( ComLink, cbToLink[CB], CBStorage[CB].Proc, CBStorage[CB].Id, CBStorage[CB].hSession );
			SerialLink.SetCommCallback( ComLink, ComSession, cbToLink[CB], SerialLink.TCommCallback( LinkCallback ), ADR( SELF ), FALSE, FALSE );
			INCL( CM, cbToLink[CB] );
			IF CB = fcbTxTimeout THEN
				EXIT;
			ELSE
				INC( CB );
			END;
		END; // LOOP
		SerialLink.SetCommFocusMask( ComLink, CM );
		INCL( RStatus, rsRun );
		Logger.LogS( Log.dlpAll, L'', L'listening on callbacks' );
	END Run;

//---------------------------------------------------------

	PUBLIC PROCEDURE Stop();
	VAR
		CB : TFocusedCB;
	BEGIN
		IF TRStatus{rsRun} * RStatus = TRStatus{} THEN
			RETURN;
		END;
		SerialLink.SetCommFocusMask( ComLink, {} );
		CB := fcbRxData;
		LOOP
			SerialLink.SetCommCallback( ComLink, CBStorage[CB].hSession, cbToLink[CB], SerialLink.TCommCallback( CBStorage[CB].Proc ), CBStorage[CB].Id, FALSE, FALSE );
			IF CB = fcbTxTimeout THEN
				EXIT;
			ELSE
				INC( CB );
			END;
		END; // LOOP
		EXCL( RStatus, rsRun );
		Logger.LogS( Log.dlpAll, L'', L'stop listening on callbacks' );
	END Stop;

//---------------------------------------------------------

	LOCAL PROCEDURE _RxTick();
	BEGIN
		OnRxTick();
	END _RxTick;

//---------------------------------------------------------

	LOCAL PROCEDURE _OnRx( Result : Sync.TAsyncResult; REF Data : StorageO.AMemoryBuffer ) : BOOLEAN;
	VAR
		LDI, LI : CARDINAL;
		LRxBuffer : StorageO.CMemoryBuffer;
		LRxBufferW : StringsO.CString;
		TDI, TI : CARDINAL;
		AC : BOOLEAN; // apply checksum
		ChkSumOK : BOOLEAN := TRUE;
	BEGIN
		IF Result <> Sync.arCompleted THEN
			_ResetRxTimeout();
			Logger.LogSC( Log.dlpIO, L'', L'rx error: ', CARDINAL( Result ));
			OnRx( Result, LRxBuffer );
			IF rsRxW IN RStatus THEN
				OnRxW( Result, LRxBufferW );
			END;
			RxBuffer.Clear();
			RETURN FALSE;
		ELSIF NOT Data.Empty THEN
			RxBuffer.Append( Data );
			Logger.LogSCB( Log.dlpAll, L'', L'rx success, len: ', Data.Length, Data.Data, Data.Length );
		END;

		IF NOT DetectDataStart( RxBuffer, OUT LI, OUT LDI ) THEN
			RETURN FALSE;
		ELSIF LI > 0 THEN
			RxBuffer.RemoveStart( LI );
			DEC( LDI, LI );
			LI := 0;
		END;
		IF NOT DataComplete( RxBuffer, OUT TDI, OUT TI, OUT AC ) THEN
			RETURN FALSE;
		END;
		_ResetRxTimeout();

		IF AC THEN
			RxBuffer.Subbuffer( LI, TI - LI, OUT LRxBuffer );
			ChkSumOK := TestChkSum( LRxBuffer );
		END;
		IF ChkSumOK THEN
			RxBuffer.Subbuffer( LDI, TDI - LDI, OUT LRxBuffer );

		   OnRx( Result, LRxBuffer );
		   IF ( rsRxW IN RStatus ) AND NOT LRxBuffer.Empty THEN
			   LRxBufferW.FromOAA( 0, OA( LRxBuffer.Length-1, PCHAR( LRxBuffer.Data )));
			   OnRxW( Result, LRxBufferW );
		   END;
		END;

		IF RxBuffer.Length = TI THEN
			RxBuffer.Clear();
		ELSE
			RxBuffer.RemoveStart( TI );
		END;
		RETURN NOT RxBuffer.Empty;
	END _OnRx;

//---------------------------------------------------------

	INTERNAL VIRTUAL PROCEDURE OnRxTick();
	BEGIN
	END OnRxTick;

//---------------------------------------------------------

	INTERNAL VIRTUAL PROCEDURE DetectDataStart( CONST Data : StorageO.AMemoryBuffer; OUT FrameStart, DataStart : CARDINAL ) : BOOLEAN;
	BEGIN
		IF IBLSLen = 0 THEN
			FrameStart := 0;
			DataStart := 0;
			RETURN TRUE;
		END;

		FrameStart := Data.IndexOfOA( IBLS, 0 );
		IF FrameStart = MAX( CARDINAL ) THEN
			RETURN FALSE;
		END;
		DataStart := FrameStart + IBLSLen;

		RETURN TRUE;
	END DetectDataStart;

//---------------------------------------------------------

	INTERNAL VIRTUAL PROCEDURE DataComplete( CONST Data : StorageO.AMemoryBuffer; OUT FirstIndexAfterData, FirstIndexAfterFrame : CARDINAL; OUT ApplyCheckSum : BOOLEAN ) : BOOLEAN;
	BEGIN
		ApplyCheckSum := FALSE;
		IF IBTSLen = 0 THEN
			FirstIndexAfterData := Data.Length;
			FirstIndexAfterFrame := Data.Length;
			RETURN TRUE;
		END;
		FirstIndexAfterData := Data.IndexOfOA( IBTS, 0 );
		IF FirstIndexAfterData = MAX( CARDINAL ) THEN
			RETURN FALSE;
		END;
		FirstIndexAfterFrame := FirstIndexAfterData + IBTSLen;
		RETURN TRUE;
	END DataComplete;

//---------------------------------------------------------

	INTERNAL VIRTUAL PROCEDURE OnRx( Result : Sync.TAsyncResult; CONST Data : StorageO.AMemoryBuffer );
	BEGIN
	END OnRx;

//---------------------------------------------------------

	INTERNAL VIRTUAL PROCEDURE OnRxW( Result : Sync.TAsyncResult; CONST Data : StringsO.IString );
	BEGIN
	END OnRxW;

//---------------------------------------------------------

	LOCAL PROCEDURE _OnRxTimeout();
	VAR
		LB : StorageO.CMemoryBuffer;
	BEGIN
		IF NOT TimerRunning( tiRx ) THEN
			Logger.LogS( Log.dlpCtrl, L'', L'rx timeout unexpected' );
			RETURN;
		END;
		_ResetRxTimeout();
		SerialLink.PurgeRxBuffer( ComLink );
		_OnRx( Sync.arTimeout, REF LB );
	END _OnRxTimeout;

//---------------------------------------------------------

	PRIVATE PROCEDURE _SetRxTimeout( _RxTimeout : CARDINAL );
	BEGIN
		_ResetRxTimeout();
		RxTimeout := _RxTimeout;
		IF RxTimeout = 0 THEN
			RETURN;
		END;
		Logger.LogSC( Log.dlpCtrl, L'', L'rx timeout set to: ', RxTimeout );
		StartTimer( tiRx, RxTimeout, FALSE );
	END _SetRxTimeout;

//---------------------------------------------------------

	PRIVATE PROCEDURE _ResetRxTimeout();
	BEGIN
		IF TimerRunning( tiRx ) THEN
			StopTimer( tiRx );
			Logger.LogS( Log.dlpCtrl, L'', L'rx timeout reset' );
		END;
	END _ResetRxTimeout;

//---------------------------------------------------------

	LOCAL PROCEDURE _QueryRxSkip( AbleToReceive : CARDINAL; OUT SkipCount : CARDINAL ) : BOOLEAN;
	BEGIN
		IF ReadBackLen = 0 THEN
			RETURN FALSE;
		END;
		SkipCount := MIN2( AbleToReceive, ReadBackLen );
		DEC( ReadBackLen, SkipCount );
		Logger.LogSC( Log.dlpAll, L'', L'tx/rx read back skipped, now: ', ReadBackLen );
		RETURN TRUE;
	END _QueryRxSkip;

//---------------------------------------------------------

	PUBLIC PROCEDURE Tx( CONST Data : ARRAY OF BYTE; _SendAsIs : BOOLEAN; _RepeatCount : CARDINAL; _TxTimeout, _RxTimeout : CARDINAL );
	VAR
		A : ADDRESS;
		L : CARDINAL;
	BEGIN
		IF INTEGER( HIGH( Data )) >= 0 THEN // HACK
			IF OBLSLen > 0 THEN
				TxBuffer.FromOA( OA( OBLSLen-1, ADR( OBLS )), TRUE );
			END;
			TxBuffer.AppendOA( Data );
			IF OBTS[0] <> 0C THEN
				TxBuffer.AppendOA( OA( OBTSLen-1, ADR( OBTS )));
			END;
			IF NOT _SendAsIs THEN
				AddChkSum( REF TxBuffer );
			END;
		END;

		A := TxBuffer.Data;
		L := TxBuffer.Length;
		IF rsReadBack IN RStatus THEN
			INC( ReadBackLen, L );
			Logger.LogSC( Log.dlpAll, L'', L'tx/rx read back now: ', ReadBackLen );
		END;

		// cwxlink.PurgeRxBuffer( ComLink );
		RepeatCount := _RepeatCount;
		IF _TxTimeout = 0 THEN
			_SetTxTimeout( 0 );
		ELSE
			_SetTxTimeout( _TxTimeout + L );
		END;
		IF _RxTimeout = 0 THEN
			_SetRxTimeout( 0 );
		ELSIF rsReadBack IN RStatus THEN
			_SetRxTimeout( _RxTimeout + 2 * L );
		ELSE
			_SetRxTimeout( _RxTimeout + L );
		END;

		Logger.LogSCB( Log.dlpAll, L'', L'tx start of ', L, A, L );
		SerialLink.Send( ComLink, A, L );
	END Tx;

//---------------------------------------------------------

	PUBLIC PROCEDURE TxW( CONST Data : ARRAY OF WCHAR; _SendAsIs : BOOLEAN; _RepeatCount : CARDINAL; _TxTimeout, _RxTimeout : CARDINAL );
	VAR
		D : StorageO.CMemoryBuffer;
		S : StringsO.CString;
	BEGIN
		S.FromOA( Data );
		IF S.Empty THEN
			RETURN;
		END;
		D.Size := S.Length;
		D.Length := S.Length;
		S.ToOAA( 0, OUT OA( D.Length-1, PCHAR( D.Data )));
		Tx( OA( D.Length-1, PCHAR( D.Data )), _SendAsIs, _RepeatCount, _TxTimeout, _RxTimeout );
	END TxW;

//---------------------------------------------------------

	LOCAL PROCEDURE _OnTx( Result : Sync.TAsyncResult );
	BEGIN
		_ResetTxTimeout();
		IF Result = Sync.arCompleted THEN
			Logger.LogSC( Log.dlpCtrl, L'', L'tx success, len: ', TxBuffer.Length );
		ELSE
			Logger.LogSC( Log.dlpIO, L'', L'tx error: ', CARDINAL( Result ));
		END;
		TxBuffer.Clear();
		OnTx( Result );
	END _OnTx;

//---------------------------------------------------------

	INTERNAL VIRTUAL PROCEDURE OnTx( Result : Sync.TAsyncResult );
	BEGIN
	END OnTx;

//---------------------------------------------------------

	LOCAL PROCEDURE _OnTxTimeout();
	BEGIN
		IF NOT TimerRunning( tiTx ) THEN
			Logger.LogS( Log.dlpCtrl, L'', L'tx timeout unexpected' );
			_OnTx( Sync.arTimeout );
			RETURN;
		END;
		_ResetTxTimeout();
		SerialLink.PurgeTxBuffer( ComLink );
		IF RepeatCount > 1 THEN
			Logger.LogS( Log.dlpCtrl, L'', L'tx will repeat' );
			DEC( RepeatCount );
		ELSE
			_OnTx( Sync.arTimeout );
			RETURN;
		END;
		Tx( OA( -1, NIL ), TRUE, RepeatCount, TxTimeout, RxTimeout );
	END _OnTxTimeout;

//---------------------------------------------------------

	PROCEDURE _SetTxTimeout( _TxTimeout : CARDINAL );
	BEGIN
		_ResetTxTimeout();
		TxTimeout := _TxTimeout;
		IF TxTimeout = 0 THEN
			RETURN;
		END;
		Logger.LogSC( Log.dlpCtrl, L'', L'tx timeout set to: ', TxTimeout );
		StartTimer( tiTx, TxTimeout, FALSE );
	END _SetTxTimeout;

//---------------------------------------------------------

	PROCEDURE _ResetTxTimeout();
	BEGIN
		IF TimerRunning( tiTx ) THEN
			StopTimer( tiTx );
			Logger.LogS( Log.dlpCtrl, L'', L'tx timeout reset' );
		END;
	END _ResetTxTimeout;

//---------------------------------------------------------

	INTERNAL VIRTUAL PROCEDURE AddChkSum( REF Data : StorageO.AMemoryBuffer );
	BEGIN
	END AddChkSum;

//---------------------------------------------------------

	INTERNAL VIRTUAL PROCEDURE TestChkSum( CONST Data : StorageO.AMemoryBuffer ) : BOOLEAN;
	BEGIN
		RETURN TRUE;
	END TestChkSum;

//---------------------------------------------------------

	INTERNAL VIRTUAL PROCEDURE OnTimer( TimerId : PTR );
	BEGIN
		CASE TimerId OF
		| tiRx :
			_OnRxTimeout();
		| tiTx :
			_OnTxTimeout();
		END;
	END OnTimer;

//---------------------------------------------------------

BEGIN
	RStatus := TRStatus{};
	Name[0] := WCHAR( 0 );
	TxTimeout := 0;
	ReadBackLen := 0;
	RepeatCount := 0;
	RxTimeout := 0;
	IBLS[0] := CHAR( 0 );
	IBLSLen := 0;
	IBTS[0] := CHAR( 0 );
	IBTSLen := 0;
	OBLS[0] := CHAR( 0 );
	OBLSLen := 0;
	OBTS[0] := CHAR( 0 );
	OBTSLen := 0;
	Zero( ADR( CBStorage ), SIZE( CBStorage ));
END CSerialHandler;

//=========================================================

(*# save, call( convention => cdecl ) *)
PROCEDURE LinkCallback( ObjectId : ADDRESS; Event, Param : CARDINAL );
(*# restore *)
CONST
  sdsLen = 8192;
VAR
	Buffer : ARRAY [0..sdsLen-1] OF BYTE;
	L : CARDINAL;
	D : StorageO.CMemoryBuffer;
	PSH : TPSerialHandler;
	Skip : CARDINAL;
BEGIN
	PSH := TPSerialHandler( ObjectId );
	IF NOT PSH^.Running THEN
		RETURN;
	END;
	Buffer[0] := 0;
	D.FromOA( Buffer, FALSE ); // create reference only

	CASE Event OF
	//-----
	| SerialLink.comfTxTimeout :
		PSH^._OnTxTimeout();
	//-----
	| SerialLink.comfRxTimeout :
		PSH^._OnRxTimeout();
	//-----
	| SerialLink.comfRxDataQueued :
		L := MIN2( SerialLink.RxCount( PSH^.ComLink ), sdsLen );
		IF L = 0 THEN
			RETURN;
		ELSIF PSH^._QueryRxSkip( L, OUT Skip ) THEN
			SerialLink.Receive( PSH^.ComLink, D.Data, Skip, FALSE );
			DEC( L, Skip );
		END;
		PSH^._RxTick();
		IF L = 0 THEN
		   RETURN;
		END;
		SerialLink.Receive( PSH^.ComLink, D.Data, L, FALSE );
		D.Length := L;
		WHILE PSH^._OnRx( Sync.arCompleted, REF D ) DO
		   D.Clear();
		END;
	//-----
	| SerialLink.comfTxEmpty:
		PSH^._OnTx( Sync.arCompleted );
	END; // CASE
END LinkCallback;

//=========================================================

END serial.