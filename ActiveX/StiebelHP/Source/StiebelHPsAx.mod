IMPLEMENTATION MODULE StiebelHPsAx;

//================================================================================
(*/* changes:

*/*)
//================================================================================

FROM Storage IMPORT
	REALLOCATE, ALLOCATE, DEALLOCATE;

IMPORT
	guiddef,
	windows,
	winerror,
	winnls,
	wtypes,
	oaidl,
	oleauto;

IMPORT
	IOO,
	StringsO,
	Storage,
	Sync;

IMPORT
	sdio,
	sdns,
	sdvalue;

IMPORT
	ax_automation,
	com,
	StiebelHP,
	TypeLib;

//================================================================================

TYPE
	TPIStiebelHPsAx_Control = POINTER TO CIStiebelHPsAx_Control;
	TPIStiebelHPsAx_Events  = POINTER TO CIStiebelHPsAx_Events;
	TPStiebelHPsAx          = POINTER TO CStiebelHPsAx;

CLASS CClientConstructor( ax_automation.CAbstractClientConstructor );
	VIRTUAL PROCEDURE CreateInstance( VAR PInstance : ax_automation.TPActiveXControl ) : wtypes.HRESULT;
	VIRTUAL PROCEDURE QueryControlIIDs( VAR ControlIID, TypeLibIID, IDispatch_Native_IID, IDispatch_Event_IID : guiddef.IID );
	VIRTUAL PROCEDURE QueryControlNames( VAR DLLName, ControlName, ProgId : ARRAY OF WCHAR; VAR ProgIdCurrentVersion : CARDINAL );
	VIRTUAL PROCEDURE QueryTypeLibIndexes( VAR IControl, IDispatch_Native, IDispatch_Event : CARDINAL );
END CClientConstructor;

//--------------------------------------------------------------------------------

(*# save, call( convention=>stdcall ) *)

CLASS CIStiebelHPsAx_Control( ax_automation.CActiveXDispatch );
	PAX : TPStiebelHPsAx;

	PUBLIC VIRTUAL PROCEDURE InitDevice( COMDevice, PARFilePath : com.BSTR; OUT ErrorMessage : com.BSTR; OUT Result : com.VARIANT_BOOL ) : com.HRESULT;
	PUBLIC VIRTUAL PROCEDURE DoneDevice() : com.HRESULT;
	PUBLIC VIRTUAL PROCEDURE Map( ItemName : com.BSTR; OUT ItemHandle : windows.LONG; OUT Found : com.VARIANT_BOOL ) : com.HRESULT; 
	PUBLIC VIRTUAL PROCEDURE IO( Direction : IOO.TDirection; ItemHandle : windows.LONG; DataValue : com.BSTR; OUT Result : Sync.TAsyncResult ) : com.HRESULT; 

END CIStiebelHPsAx_Control;

//--------------------------------------------------------------------------------

TYPE
	TEventDispatchId = (
		eidNone,
		eidOnIO
	);

CLASS CIStiebelHPsAx_Events( ax_automation.CActiveXDispatch );

	PUBLIC VIRTUAL PROCEDURE OnIO( Direction : IOO.TDirection; Result : Sync.TAsyncResult; Value : com.BSTR ) : com.HRESULT;

END CIStiebelHPsAx_Events;

(*# restore *)

//--------------------------------------------------------------------------------

CLASS CCallback( sdio.CSDCallback );
	PAX : TPStiebelHPsAx;
	PUBLIC VIRTUAL PROCEDURE OnIO( Direction : IOO.TDirection; Source : sdio.TPSDIO; Result : ARRAY OF Sync.TAsyncResult; Item : ARRAY OF sdns.THash; CONST Value : ARRAY OF sdvalue.ASDValue );
END CCallback;

//--------------------------------------------------------------------------------

VAR
	AXConstructor : CClientConstructor;
	RefCount : CARDINAL;

(*# save, call( convention=>stdcall ) *)

CLASS CStiebelHPsAx( ax_automation.CActiveXControl );
	DEV : StiebelHP.CStiebelHPDevice;
	CB : CCallback;

	// ActiveX inherited
	VIRTUAL PROCEDURE Release() : windows.ULONG;
	VIRTUAL PROCEDURE CreateNativeIDispatch( VAR PIDispatch : ax_automation.TPActiveXDispatch ) : BOOLEAN;
	VIRTUAL PROCEDURE EnumerateEventIDispatch( VAR EnumerateState : LONGWORD; VAR IID : guiddef.IID ) : BOOLEAN;

	// IO handling
	LOCAL PROCEDURE InitDevice( CONST COMDevice, Path : ARRAY OF WCHAR; OUT ErrorString : ARRAY OF WCHAR ) : BOOLEAN;
	LOCAL PROCEDURE DoneDevice();
	LOCAL PROCEDURE Map( CONST Name : ARRAY OF WCHAR; OUT ItemHash : sdns.THash ) : BOOLEAN;
	LOCAL PROCEDURE IO( Direction : IOO.TDirection; ItemHash : sdns.THash; CONST ValueData : ARRAY OF WCHAR ) : Sync.TAsyncResult;
	LOCAL PROCEDURE OnIO( Direction : IOO.TDirection; Result : Sync.TAsyncResult; CONST Value : sdvalue.ASDValue );
END CStiebelHPsAx;

(*# restore *)

//================================================================================

CLASS IMPLEMENTATION CClientConstructor;

//--------------------------------------------------------------------------------

	VIRTUAL PROCEDURE CreateInstance( VAR PInstance : ax_automation.TPActiveXControl ) : wtypes.HRESULT;
	VAR
		ControlIID, IIDx : guiddef.IID;
		PAX : TPStiebelHPsAx;
	BEGIN
		QueryControlIIDs( ControlIID, IIDx, IIDx, IIDx );

		NEW( PAX );
		PAX^.IID := ControlIID;
		PAX^.AddRef();
		PAX^.Init();

		PInstance := PAX;
		RETURN winerror.S_OK;
	END CreateInstance;

(*---------------------------------------------------------------------------*)

	VIRTUAL PROCEDURE QueryControlIIDs( VAR ControlIID, TypeLibIID, IDispatch_Native_IID, IDispatch_Event_IID : guiddef.IID );
	BEGIN
		ControlIID := TypeLib.CLSID_StiebelHPsAx;
		TypeLibIID := TypeLib.LIBID_StiebelHPsAx;
		IDispatch_Native_IID := TypeLib.IID_StiebelHPsAx_Control;
		IDispatch_Event_IID := TypeLib.DIID_StiebelHPsAx_Events;
	END QueryControlIIDs;

//--------------------------------------------------------------------------------

	VIRTUAL PROCEDURE QueryControlNames( VAR DLLName, ControlName, ProgId : ARRAY OF WCHAR; VAR ProgIdCurrentVersion : CARDINAL );
	BEGIN
		ASSIGN( DLLName, EMITW( %dll ));
		ASSIGN( ControlName, L"SmartControl Stiebel Heat Pump Simple ActiveX Control" );
		ASSIGN( ProgId, L"SmartControl.StiebelHPSimple" );
		ProgIdCurrentVersion := 1;
	END QueryControlNames;

//--------------------------------------------------------------------------------

	VIRTUAL PROCEDURE QueryTypeLibIndexes( VAR IControl, IDispatch_Native, IDispatch_Event : CARDINAL );
	BEGIN
		IControl := 6;
		IDispatch_Native := 4;
		IDispatch_Event := 5;
	END QueryTypeLibIndexes;

//--------------------------------------------------------------------------------

BEGIN
END CClientConstructor;

//================================================================================

CLASS IMPLEMENTATION CIStiebelHPsAx_Control;

//--------------------------------------------------------------------------------

	PUBLIC VIRTUAL PROCEDURE InitDevice( COMDevice, PARFilePath : com.BSTR; OUT ErrorMessage : com.BSTR; OUT Result : com.VARIANT_BOOL ) : com.HRESULT;
	VAR
		errorMessage : ARRAY [0..255] OF WCHAR;
	BEGIN
		IF PAX^.InitDevice( OAsz( COMDevice ), OAsz( PARFilePath ), OUT errorMessage ) THEN
			Result := windows.True;
		ELSE
			com.ToBSRef( errorMessage, REF ErrorMessage );
			Result := windows.False;
		END;
		RETURN winerror.S_OK;
	END InitDevice;

//--------------------------------------------------------------------------------

	PUBLIC VIRTUAL PROCEDURE DoneDevice() : com.HRESULT;
	BEGIN
		PAX^.DoneDevice();
		RETURN winerror.S_OK;
	END DoneDevice;

//--------------------------------------------------------------------------------

	PUBLIC VIRTUAL PROCEDURE Map( ItemName : com.BSTR; OUT ItemHandle : windows.LONG; OUT Found : com.VARIANT_BOOL ) : com.HRESULT; 
	VAR
		Handle : PTR;
	BEGIN
		IF PAX^.Map( OAsz( ItemName ), OUT Handle ) THEN
			ItemHandle := windows.LONG( Handle );
			Found := windows.True;
		ELSE
			Found := windows.False;
		END;
		RETURN winerror.S_OK;
	END Map;

//--------------------------------------------------------------------------------

	PUBLIC VIRTUAL PROCEDURE IO( Direction : IOO.TDirection; ItemHandle : windows.LONG; DataValue : com.BSTR; OUT Result : Sync.TAsyncResult ) : com.HRESULT; 
	BEGIN
		Result := PAX^.IO( Direction, PTR( ItemHandle ), OAsz( DataValue ));
		RETURN winerror.S_OK;
	END IO;

//--------------------------------------------------------------------------------
 
BEGIN
	PAX := NIL;
END CIStiebelHPsAx_Control;

//================================================================================

CLASS IMPLEMENTATION CIStiebelHPsAx_Events;

//--------------------------------------------------------------------------------

	PUBLIC VIRTUAL PROCEDURE OnIO( Direction : IOO.TDirection; Result : Sync.TAsyncResult; Value : com.BSTR ) : com.HRESULT;
	BEGIN
		RETURN winerror.E_NOTIMPL;
	END OnIO;

//--------------------------------------------------------------------------------

BEGIN
END CIStiebelHPsAx_Events;

//================================================================================

CLASS IMPLEMENTATION CStiebelHPsAx;

//--------------------------------------------------------------------------------

	VIRTUAL PROCEDURE Release() : windows.ULONG;
	BEGIN
		IF ReferenceCount = 1 THEN
			DEV.Dispose();
		END;
		RETURN SUPER.Release();
	END Release;

//--------------------------------------------------------------------------------

	VIRTUAL PROCEDURE CreateNativeIDispatch( VAR PIDispatch : ax_automation.TPActiveXDispatch ) : BOOLEAN; // must call AddRef to PIDispatch
	VAR
		IID, IIDx : guiddef.IID;
		HR : com.HRESULT;
	BEGIN
		NEW( TPIStiebelHPsAx_Control( PIDispatch ));
		PIDispatch^.AddRef();
		TPIStiebelHPsAx_Control( PIDispatch )^.PAX := ADR( SELF );

		ax_automation.GetClientConstructor()^.QueryControlIIDs( IIDx, IIDx, IID, IIDx );
		HR := PIDispatch^.Init( IID, ADR( SELF ));

		IF HR = winerror.S_OK THEN
			RETURN TRUE;
		ELSE
			RETURN FALSE;
		END;
	END CreateNativeIDispatch;

(*---------------------------------------------------------------------------*)

	VIRTUAL PROCEDURE EnumerateEventIDispatch( VAR EnumerateState : LONGWORD; VAR IID : guiddef.IID ) : BOOLEAN;
	VAR
		IIDx : guiddef.IID;
	BEGIN
		IF EnumerateState = LONGWORD( 0 ) THEN
			EnumerateState := 1;
			ax_automation.GetClientConstructor()^.QueryControlIIDs( IIDx, IIDx, IIDx, IID );
		ELSE
			RETURN FALSE;
		END;
		RETURN TRUE;
	END EnumerateEventIDispatch;

//--------------------------------------------------------------------------------

	LOCAL PROCEDURE InitDevice( CONST COMDevice, Path : ARRAY OF WCHAR; OUT ErrorString : ARRAY OF WCHAR ) : BOOLEAN;
	BEGIN
		IF NOT DEV.Init( COMDevice, Path, OUT ErrorString ) THEN
			RETURN FALSE;
		END;
		DEV.Run();
		RETURN TRUE;
	END InitDevice;

//--------------------------------------------------------------------------------

	LOCAL PROCEDURE DoneDevice();
	BEGIN
		DEV.Stop();
		DEV.Dispose();
	END DoneDevice;

//--------------------------------------------------------------------------------

	LOCAL PROCEDURE Map( CONST Name : ARRAY OF WCHAR; OUT ItemHash : sdns.THash ) : BOOLEAN;
	BEGIN
		RETURN DEV.NS()^.Map( Name, OUT ItemHash );
	END Map;

//--------------------------------------------------------------------------------

	LOCAL PROCEDURE IO( Direction : IOO.TDirection; ItemHash : sdns.THash; CONST ValueData : ARRAY OF WCHAR ) : Sync.TAsyncResult;
	VAR
		Value : sdvalue.CSDFloat;
	BEGIN
		Value.FromStringOA( ValueData );
		RETURN DEV.IO()^.IOh( Direction, ItemHash, REF Value, ADR( CB ));
	END IO;

//--------------------------------------------------------------------------------

	LOCAL PROCEDURE OnIO( Direction : IOO.TDirection; Result : Sync.TAsyncResult; CONST Value : sdvalue.ASDValue );
	VAR
		IID, IIDx : guiddef.IID;
		Parameters : ARRAY [0..2] OF oaidl.VARIANT;
		String : StringsO.CString;
	BEGIN
		// parameters are of reveresed order
		oleauto.VariantInit( ADR( Parameters[2] ));
		Parameters[2].vt := wtypes.VT_I4;
		Parameters[2].lVal := windows.LONG( Direction );

		oleauto.VariantInit( ADR( Parameters[1] ));
		Parameters[1].vt := wtypes.VT_I4;
		Parameters[1].lVal := windows.LONG( Result );

		oleauto.VariantInit( ADR( Parameters[0] ));
		Parameters[0].vt := wtypes.VT_BSTR;
		IF ( Direction = IOO.dirRead ) AND ( Result = Sync.arCompleted ) THEN
			Value.ToString( OUT String );
			Parameters[0].bstrVal := com.ToBS( OAsz( String.szData ));
		ELSE
			Parameters[0].bstrVal := com.ToBS( L"" );
		END;

		ax_automation.GetClientConstructor()^.QueryControlIIDs( IIDx, IIDx, IIDx, IID );
		DispatchEvent( IID, LONGWORD( eidOnIO ), Parameters );

		oleauto.VariantClear( ADR( Parameters[0] ));
		oleauto.VariantClear( ADR( Parameters[1] ));
		oleauto.VariantClear( ADR( Parameters[2] ));
	END OnIO;

//--------------------------------------------------------------------------------

BEGIN
	CB.PAX := ADR( SELF );
FINALLY
	DEV.Dispose();
END CStiebelHPsAx;

//================================================================================

CLASS IMPLEMENTATION CCallback;

//--------------------------------------------------------------------------------

  PUBLIC VIRTUAL PROCEDURE OnIO( Direction : IOO.TDirection; Source : sdio.TPSDIO; Result : ARRAY OF Sync.TAsyncResult; Item : ARRAY OF sdns.THash; CONST Value : ARRAY OF sdvalue.ASDValue );
  BEGIN
		PAX^.OnIO( Direction, Result[0], Value[0] );
  END OnIO;

//--------------------------------------------------------------------------------

BEGIN
	PAX := NIL;
END CCallback;

//================================================================================
// procedural interface

INITIALLY __I();
BEGIN
	RefCount := 0;
	ax_automation.RegisterClientConstructor( ADR( AXConstructor ));
END __I;

FINALLY __F();
BEGIN
	ax_automation.ForgetClientConstructor();
END __F;

//================================================================================

END StiebelHPsAx.