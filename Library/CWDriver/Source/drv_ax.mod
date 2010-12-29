IMPLEMENTATION MODULE drv_ax;

(*# call( o_a_copy => off ) *)
(*# option( pack => 8 ) *)

////////////////////////////////////////////////////////////////
// Control Web Driver ActiveX Control                         //
//                                            the code itself //
//                              (C) 2004 Moravian Instruments //
////////////////////////////////////////////////////////////////

FROM Storage IMPORT
  ALLOCATE, DEALLOCATE;

IMPORT
  guiddef,
  oaidl,
  oleauto,
  unknwn,
  windows,
  winerror,
  wtypes;

IMPORT
  FIO,
  iovalue,
  msghandler,
  Storage,
  list;

IMPORT
  ax_automation;

IMPORT
  drv_def,
  drv_wrapper;

IMPORT
  drv_ax_;

(*===========================================================================*)

(*/* OBSOLETE
CONST
  // typelib indexes
  tiliDrvAx_Native    = 2;
  tiliDrvAx_Event     = 3;
  tiliDrvAx_Object    = 4;
  
  // uuid(DDD00C7B-78C3-405D-AC0C-748DD46A61DD),
  // helpstring("Native IDispatch Interface of Control Web Driver ActiveX Control"),
  IID_DrvAx_Native    = TMyGUID( 0DDD00C7BH,
                                 078C3H,
                                 0405DH,
                                 0ACH, 00CH, 074H, 08DH, 0D4H, 06AH, 061H, 0DDH );

  // uuid(585C78D8-5E57-485B-9CAF-189AB8D09315),
  // helpstring("Event IDispatch Interface of Control Web Driver ActiveX Control"),
  IID_DrvAx_Event     = TMyGUID( 0585C78D8H,
                                 05E57H,
                                 0485BH,
                                 09CH, 0AFH, 018H, 09AH, 0B8H, 0D0H, 093H, 015H );

  // uuid( 2DF843F3-8729-4DB3-B84F-B23ECE982B6D ),
  // helpstring("Control Web Driver ActiveX Control")
  IID_DrvAx_Control   = TMyGUID( 02DF843F3H,
                                 08729H,
                                 04DB3H,
                                 0B8H, 04FH, 0B2H, 03EH, 0CEH, 098H, 02BH, 06DH );

	// uuid(5D8864F7-4F93-4379-BE5A-4F832B39D1C6),
	// version(1.0),
	// helpstring("Control Web Driver ActiveX Control 1.0 Type Library")
  IID_DrvAx_TypeLib   = TMyGUID( 05D8864F7H,
                                 04F93H,
                                 04379H,
                                 0BEH, 05AH, 04FH, 083H, 02BH, 039H, 0D1H, 0C6H );
OBSOLETE */*)

(*===========================================================================*)

TYPE
  TPDriverActiveX = POINTER TO CDriverActiveX;
  TPIDrvAx_Native = POINTER TO CIDrvAx_Native;
  TPIDrvAx_Event  = POINTER TO CIDrvAx_Event;

TYPE
  TCommunicationState = (
    csSuccess = 0,
  	 csPending = 1,
	 csFailure = 2,
    csNotRunning = 3,
    csBadIndex = 4,
    csBadDirection = 5
  );

(*===========================================================================*)

(*# save,
    call( o_a_size=>off,
          o_a_copy=>off,
          convention=>stdcall ) *)

CLASS CIDrvAx_Native( ax_automation.CActiveXDispatch );
  PActiveX : TPDriverActiveX;

  // DrvAx_Native
  VIRTUAL PROCEDURE LoadPARFile( PPARPath : wtypes.BSTR; VAR PErrorMessage : wtypes.BSTR; VAR Success : wtypes.VARIANT_BOOL ) : wtypes.HRESULT;
  VIRTUAL PROCEDURE Run() : wtypes.HRESULT;
  VIRTUAL PROCEDURE Stop() : wtypes.HRESULT;

  VIRTUAL PROCEDURE MarkInput( InputIndex : windows.LONG; VAR CommunicationState : TCommunicationState ) : wtypes.HRESULT;
  VIRTUAL PROCEDURE ReadInputs( VAR CommunicationState : TCommunicationState ) : wtypes.HRESULT;

  VIRTUAL PROCEDURE MarkOutput( OutputIndex : windows.LONG; PValue : wtypes.BSTR; VAR CommunicationState : TCommunicationState ) : wtypes.HRESULT;
  VIRTUAL PROCEDURE WriteOutputs( VAR CommunicationState : TCommunicationState ) : wtypes.HRESULT;
END CIDrvAx_Native;

(*---------------------------------------------------------------------------*)

CLASS CIDrvAx_Event( ax_automation.CActiveXDispatch );
  // DrvAx_Event
  VIRTUAL PROCEDURE OnInputRead( CommunicationState : TCommunicationState; InputIndex, ErrorCode : windows.LONG; PValue : wtypes.BSTR ) : wtypes.HRESULT;
  VIRTUAL PROCEDURE OnOutputWritten( CommunicationState : TCommunicationState; OutputIndex, ErrorCode : windows.LONG ) : wtypes.HRESULT;
END CIDrvAx_Event;

(*# restore *)

(*---------------------------------------------------------------------------*)

CLASS CAXDriver( drv_wrapper.CDriver );
  PActiveX : TPDriverActiveX;
  PUBLIC VIRTUAL PROCEDURE DriverCallBackA( Func : CARDINAL; Param : ADDRESS ) : CARDINAL;
  PUBLIC VIRTUAL PROCEDURE DriverCallBackW( Func : CARDINAL; Param : ADDRESS ) : CARDINAL;
END CAXDriver;

(*---------------------------------------------------------------------------*)

CONST
  WM_INPUT_FINALIZED  = windows.WM_USER + 1024 + 0;
  WM_OUTPUT_FINALIZED = windows.WM_USER + 1024 + 1;
  WM_OOB_DATA_ADVICE  = windows.WM_USER + 1024 + 2;

CLASS CAXMessageHandler( msghandler.MessageHandler );
  PActiveX : TPDriverActiveX;
  INTERNAL VIRTUAL PROCEDURE OnMessage( CONST Message : msghandler.IMessage; OUT Result : PTR ) : BOOLEAN;
END CAXMessageHandler;

(*---------------------------------------------------------------------------*)

TYPE
  TPPendingItem = POINTER TO CPendingItem;

CLASS CPendingItem( list.CListElem );
  Index   : CARDINAL;
  Value   : iovalue.Value;
  Pending : BOOLEAN;
  PUBLIC VIRTUAL PROCEDURE Done();
END CPendingItem;

(*---------------------------------------------------------------------------*)

TYPE
  TDispatchId = (
    eidNone,
    eidRead, // = 1
    eidWritten   // = 2
  );

  TDriverState = (
    dstBegin,
    dstInitialized,
    dstHasPAR,
    dstRun
  );

  TActionItem = (
    actInputRequest, // only for detecting ReadInputs call inside NotifyInputFinalized
    actInputPending,
    actOutputRequest, // only for detecting WriteOutputs call inside NotifyOutputFinalized
    actOutputPending
  );
  TAction = SET OF TActionItem;

(*# save,
    call( o_a_copy=>off,
          convention=>stdcall ) *)

CLASS CDriverActiveX( ax_automation.CActiveXControl );
  State       : TDriverState;
  Driver      : CAXDriver;
  Messager    : CAXMessageHandler;
  HModule     : windows.HANDLE;
  Map         : drv_wrapper.CChannelMap;
  UsesRunStop : BOOLEAN;

  Inputs      : list.CList;
  Outputs     : list.CList;
  Action      : TAction;

  PUBLIC PROCEDURE Init( UsesRunStop : BOOLEAN ) : BOOLEAN;
  PUBLIC VIRTUAL PROCEDURE Release() : windows.ULONG;

  PUBLIC PROCEDURE LoadPar( PARPath : ARRAY OF WCHAR; VAR ErrorMessage : ARRAY OF WCHAR ) : BOOLEAN;

  PUBLIC VIRTUAL PROCEDURE Run() : BOOLEAN;
  PUBLIC VIRTUAL PROCEDURE Stop() : BOOLEAN;

  PUBLIC VIRTUAL PROCEDURE MarkInput( InputIndex : CARDINAL; VAR CommunicationState : TCommunicationState );
  PUBLIC VIRTUAL PROCEDURE ReadInputs( VAR CommunicationState : TCommunicationState );
  PUBLIC VIRTUAL PROCEDURE MarkOutput( OutputIndex : CARDINAL; Value : ARRAY OF WCHAR; VAR CommunicationState : TCommunicationState );
  PUBLIC VIRTUAL PROCEDURE WriteOutputs( VAR CommunicationState : TCommunicationState );

  LOCAL VIRTUAL PROCEDURE NotifyInputFinalized();
  LOCAL VIRTUAL PROCEDURE NotifyOutputFinalized();
  LOCAL VIRTUAL PROCEDURE NotifyOOBDataAdvice();

  INTERNAL PROCEDURE InputRead( Status : TCommunicationState; Index : CARDINAL; EC : CARDINAL );
  INTERNAL PROCEDURE OutputWritten( Status : TCommunicationState; Index : CARDINAL; EC : CARDINAL );

  INTERNAL VIRTUAL PROCEDURE CreateNativeIDispatch( VAR PIDispatch : ax_automation.TPActiveXDispatch ) : BOOLEAN; // must call AddRef to PIDispatch
  LOCAL VIRTUAL PROCEDURE EnumerateEventIDispatch( VAR EnumerateState : LONGWORD; VAR IID : guiddef.IID ) : BOOLEAN;
END CDriverActiveX;

(*# restore *)

(*===========================================================================*)

CLASS IMPLEMENTATION CIDrvAx_Native;

(*---------------------------------------------------------------------------*)

  VIRTUAL PROCEDURE LoadPARFile( PPARPath : wtypes.BSTR; VAR PErrorMessage : wtypes.BSTR; VAR Success : wtypes.VARIANT_BOOL ) : wtypes.HRESULT;
  VAR
    ES : ARRAY [0..511] OF WCHAR;
    PAR : FIO.PathStrW;
  BEGIN
    IF PPARPath = NIL THEN
      PAR := L'';
    ELSE
      ASSIGN( PAR, OA( 259, PPARPath ));
    END;
    IF PActiveX^.LoadPar( PAR, ES ) THEN
      Success := 1;
      RETURN winerror.S_OK;
    END;
    IF PErrorMessage <> NIL THEN
      oleauto.SysFreeString( PErrorMessage );
    END;
    PErrorMessage := oleauto.SysAllocString( ADR( ES ));
    Success := 0;
    RETURN winerror.S_OK;
  END LoadPARFile;

(*---------------------------------------------------------------------------*)

  VIRTUAL PROCEDURE Run() : wtypes.HRESULT;
  BEGIN
    PActiveX^.Run();
    RETURN winerror.S_OK;
  END Run;

(*---------------------------------------------------------------------------*)

  VIRTUAL PROCEDURE Stop() : wtypes.HRESULT;
  BEGIN
    PActiveX^.Stop();
    RETURN winerror.S_OK;
  END Stop;

(*---------------------------------------------------------------------------*)

  VIRTUAL PROCEDURE MarkInput( InputIndex : windows.LONG; VAR CommunicationState : TCommunicationState ) : wtypes.HRESULT;
  BEGIN
    PActiveX^.MarkInput( InputIndex, CommunicationState );
    RETURN winerror.S_OK;
  END MarkInput;

(*---------------------------------------------------------------------------*)

  VIRTUAL PROCEDURE ReadInputs( VAR CommunicationState : TCommunicationState ) : wtypes.HRESULT;
  BEGIN
    PActiveX^.ReadInputs( CommunicationState );
    RETURN winerror.S_OK;
  END ReadInputs;

(*---------------------------------------------------------------------------*)

  VIRTUAL PROCEDURE MarkOutput( OutputIndex : windows.LONG; PValue : wtypes.BSTR; VAR CommunicationState : TCommunicationState ) : wtypes.HRESULT;
  VAR
    Value : ARRAY [0..255] OF WCHAR;
  BEGIN
    IF PValue = NIL THEN
      Value[0] := WCHAR( 0 );
    ELSE
      ASSIGN( Value, OA( 255, PValue ));
    END;
    PActiveX^.MarkOutput( OutputIndex, Value, CommunicationState );
    RETURN winerror.S_OK;
  END MarkOutput;

(*---------------------------------------------------------------------------*)

  VIRTUAL PROCEDURE WriteOutputs( VAR CommunicationState : TCommunicationState ) : wtypes.HRESULT;
  BEGIN
    PActiveX^.WriteOutputs( CommunicationState );
    RETURN winerror.S_OK;
  END WriteOutputs;

(*---------------------------------------------------------------------------*)

BEGIN
  PActiveX := NIL;
END CIDrvAx_Native;

(*===========================================================================*)

CLASS IMPLEMENTATION CIDrvAx_Event;

(*---------------------------------------------------------------------------*)

  VIRTUAL PROCEDURE OnInputRead( CommunicationState : TCommunicationState; InputIndex, ErrorCode : windows.LONG; PValue : wtypes.BSTR ) : wtypes.HRESULT;
  BEGIN
    RETURN winerror.S_OK;
  END OnInputRead;

(*---------------------------------------------------------------------------*)

  VIRTUAL PROCEDURE OnOutputWritten( CommunicationState : TCommunicationState; OutputIndex, ErrorCode : windows.LONG ) : wtypes.HRESULT;
  BEGIN
    RETURN winerror.S_OK;
  END OnOutputWritten;

(*---------------------------------------------------------------------------*)

BEGIN
END CIDrvAx_Event;

(*===========================================================================*)

CLASS IMPLEMENTATION CAXDriver;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE DriverCallBackA( Func : CARDINAL; Param : ADDRESS ) : CARDINAL;
  BEGIN
    RETURN DriverCallBackW( Func, Param );
  END DriverCallBackA;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE DriverCallBackW( Func : CARDINAL; Param : ADDRESS ) : CARDINAL;
  TYPE
    TPA = POINTER TO ADDRESS;
    TPC = POINTER TO CARDINAL;
  VAR
    MSG : msghandler.Message;
    Result : CARDINAL;
  BEGIN
    Result := SUPER.DriverCallBackW( Func, Param );
    IF Result <> drv_def.erNoFunction THEN
      RETURN Result;
    END;
      
    CASE Func OF
    //----------
    | drv_def.dcfInputFinalized :
      IF PActiveX <> NIL THEN
        MSG[1] := WM_INPUT_FINALIZED;
        PActiveX^.Messager.Message( MSG, msghandler.delDefault, NIL );
        RETURN drv_def.erOK;
      ELSE
        RETURN drv_def.erNoApplication;
      END;
    //----------
    | drv_def.dcfOutputFinalized :
      IF PActiveX <> NIL THEN
        MSG[1] := WM_OUTPUT_FINALIZED;
        PActiveX^.Messager.Message( MSG, msghandler.delDefault, NIL );
        RETURN drv_def.erOK;
      ELSE
        RETURN drv_def.erNoApplication;
      END;
    //----------
    | drv_def.dcfOOBDataAdvise :
      IF PActiveX <> NIL THEN
        MSG[1] := WM_OOB_DATA_ADVICE;
        PActiveX^.Messager.Message( MSG, msghandler.delDefault, NIL );
        RETURN drv_def.erOK;
      ELSE
        RETURN drv_def.erNoApplication;
      END;

    ELSE
      RETURN drv_def.erNoFunction;
    END; // CASE
  END DriverCallBackW;

(*---------------------------------------------------------------------------*)

BEGIN
  PActiveX := NIL;
END CAXDriver;

(*===========================================================================*)

CLASS IMPLEMENTATION CAXMessageHandler;

(*---------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE CAXMessageHandler.OnMessage( CONST Message : msghandler.IMessage; OUT Result : PTR ) : BOOLEAN;
  BEGIN
    IF SUPER.OnMessage( Message, OUT Result ) THEN
      RETURN TRUE;
    END;

    CASE Message.Message OF
    | WM_INPUT_FINALIZED :
      PActiveX^.NotifyInputFinalized();
    | WM_OUTPUT_FINALIZED :
      PActiveX^.NotifyOutputFinalized();
    | WM_OOB_DATA_ADVICE :
      PActiveX^.NotifyOOBDataAdvice();
    ELSE
      RETURN FALSE;
    END;

    Result := 0;
    RETURN TRUE;
  END CAXMessageHandler.OnMessage;

(*---------------------------------------------------------------------------*)

BEGIN
  PActiveX := NIL;
END CAXMessageHandler;

(*===========================================================================*)

CLASS IMPLEMENTATION CPendingItem;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE Done();
  BEGIN
    Value.Dispose();
  END Done;

(*---------------------------------------------------------------------------*)

BEGIN
  Index := -1;
  Pending := FALSE;
END CPendingItem;

(*===========================================================================*)

CLASS IMPLEMENTATION CDriverActiveX;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Init( _UsesRunStop : BOOLEAN ) : BOOLEAN;
  VAR
    c : CARDINAL;
    DLLName : ARRAY [0..255] OF WCHAR;
    es : ARRAY [0..3] OF WCHAR; 
    s : ARRAY [0..3] OF WCHAR;
  BEGIN
    IF State <> dstBegin THEN
      RETURN FALSE;
    END;
  
    SUPER.Init();
    UsesRunStop := _UsesRunStop;

    ax_automation.GetClientConstructor()^.QueryControlNames( DLLName, s, s, c );
    HModule := windows.LoadLibraryW( ADR( DLLName )); // DLLName
    IF HModule = NIL THEN
      RETURN FALSE;
    ELSE
      Driver.Init( HModule );
    END;
    IF NOT Driver.Version( c ) THEN
      RETURN FALSE;
    END;
    IF NOT Driver.Initialize( es, drv_def.drmRun, L'ActiveX' ) THEN
      RETURN FALSE;
    END;

    State := dstInitialized;
    RETURN TRUE;
  END Init;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE Release() : windows.ULONG;
  BEGIN
    IF ReferenceCount = 1 THEN
      Stop();
      Map.Dispose();
      Driver.Done();
      IF HModule <> NIL THEN
        windows.FreeLibrary( HModule );
        HModule := NIL;
      END;
    END;
    RETURN SUPER.Release();
  END Release;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE LoadPar( PARPath : ARRAY OF WCHAR; VAR ErrorMessage : ARRAY OF WCHAR ) : BOOLEAN;
  VAR
    c : CARDINAL;
    HoH : ARRAY [0..3] OF WCHAR;
  BEGIN
    CASE State OF
    | dstInitialized, dstHasPAR :
    | dstRun :
      IF UsesRunStop THEN
        ASSIGN( ErrorMessage, drv_ax_._E_AlreadyRunnning );
        RETURN FALSE;
      END;
    ELSE
      ASSIGN( ErrorMessage, drv_ax_._E_NotInitialized );
      RETURN FALSE;
    END;

    Driver.Done();
    Driver.Initialize( ErrorMessage, drv_def.drmRun, 'ActiveX' );

    IF NOT Driver.ReadParameters( PARPath, ErrorMessage, c, c, HoH ) THEN
      RETURN FALSE;
    END;
    IF NOT Driver.AbleToEnumerateChannels( FALSE ) THEN
      ASSIGN( ErrorMessage, drv_ax_._E_UnableToGetConfiguration );
      RETURN FALSE;
    END;
    IF NOT Map.LoadFromDriver( ErrorMessage, ADR( Driver )) THEN
      RETURN FALSE;
    END;

    State := dstHasPAR;   
    RETURN TRUE;
  END LoadPar;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE Run() : BOOLEAN;
  BEGIN
    CASE State OF
    | dstHasPAR :
      Driver.Run();
      State := dstRun;
    | dstRun :
    ELSE
      RETURN FALSE;
    END;
    RETURN TRUE;
  END Run;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE Stop() : BOOLEAN;
  VAR
    PPending : TPPendingItem;
  BEGIN
    CASE State OF
    | dstRun :
      Driver.Stop();

      WHILE Inputs.GetFirst( OUT PPending ) DO
        Inputs.Remove( PPending );
        InputRead( csNotRunning, PPending^.Index, 0 );
        PPending^.Done();
        DISPOSE( PPending );
      END; // WHILE
      WHILE Outputs.GetFirst( OUT PPending ) DO
        Outputs.Remove( PPending );
        OutputWritten( csNotRunning, PPending^.Index, 0 );
        PPending^.Done();
        DISPOSE( PPending );
      END; // WHILE

      State := dstHasPAR;
    | dstHasPAR :
      IF NOT UsesRunStop THEN
        State := dstRun;
        Stop();
      END;

    ELSE
      RETURN FALSE;
    END;
    RETURN TRUE;
  END Stop;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE MarkInput( InputIndex : CARDINAL; VAR CommunicationState : TCommunicationState );
  VAR
    Direction : drv_def.TDirection;
    ES : ARRAY [0..3] OF WCHAR;
    PInput : TPPendingItem;
    Type : drv_def.TValueType;
    b : BOOLEAN;
  BEGIN
    IF     UsesRunStop AND ( State <> dstRun ) OR
       NOT UsesRunStop AND ( State <> dstHasPAR ) THEN
      CommunicationState := csNotRunning;
    ELSIF NOT Map.Get( ES, InputIndex, Type, Direction ) THEN
      CommunicationState := csBadIndex;
    ELSIF NOT( drv_def.dirInput IN Direction ) THEN
      CommunicationState := csBadDirection;
    ELSE
      b := Inputs.GetFirst( OUT PInput );
      WHILE b AND ( PInput^.Index <> InputIndex ) DO
        b := Inputs.NextOf( PInput, OUT PInput );
      END; // WHILE
      IF b AND NOT PInput^.Pending THEN // found and still not pending
        CommunicationState := csSuccess;

      ELSIF b THEN // found and pending
        CommunicationState := csPending;

      ELSE // not found
        CommunicationState := csSuccess;

        NEW( PInput );
        PInput^.Index := InputIndex;
        Inputs.Append( PInput );
      END;
    END;   
  END MarkInput;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE ReadInputs( VAR CommunicationState : TCommunicationState );
  VAR
    PInput : TPPendingItem;
    b : BOOLEAN;
  BEGIN
    IF     UsesRunStop AND ( State <> dstRun ) OR
       NOT UsesRunStop AND ( State <> dstHasPAR ) THEN
      CommunicationState := csNotRunning;
      RETURN; // not to set actInputRequest
    ELSIF actInputPending IN Action THEN
      CommunicationState := csPending;
    ELSIF Inputs.Empty THEN
      CommunicationState := csSuccess;
    ELSE
      INCL( Action, actInputPending );
      CommunicationState := csPending;

      Driver.InputRequestStart();
      b := Inputs.GetFirst( OUT PInput );
      WHILE b DO
        Driver.InputRequest( PInput^.Index );
        PInput^.Pending := TRUE;
        b := Inputs.NextOf( PInput, OUT PInput );
      END;
      Driver.InputRequestCompleted();
      Driver.DriverCallBackW( drv_def.dcfInputFinalized, NIL );
    END;
    INCL( Action, actInputRequest );
  END ReadInputs;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE MarkOutput( OutputIndex : CARDINAL; Value : ARRAY OF WCHAR; VAR CommunicationState : TCommunicationState );
  VAR
    ES : ARRAY [0..3] OF WCHAR;
    Direction : drv_def.TDirection;
    POutput : TPPendingItem;
    Type : drv_def.TValueType;
    b : BOOLEAN;
  BEGIN
    IF     UsesRunStop AND ( State <> dstRun ) OR
       NOT UsesRunStop AND ( State <> dstHasPAR ) THEN
      CommunicationState := csNotRunning;
    ELSIF NOT Map.Get( ES, OutputIndex, Type, Direction ) THEN
      CommunicationState := csBadIndex;
    ELSIF NOT( drv_def.dirOutput IN Direction ) THEN
      CommunicationState := csBadDirection;
    ELSE
      b := Outputs.GetFirst( OUT POutput );
      WHILE b AND ( POutput^.Index <> OutputIndex ) DO
        b := Outputs.NextOf( POutput, OUT POutput );
      END; // WHILE
      IF b AND NOT POutput^.Pending THEN
        CommunicationState := csSuccess;

        POutput^.Value.FromStringOA( Value, FALSE );

      ELSIF b THEN // found and pending
        CommunicationState := csPending;

      ELSE // not found
        CommunicationState := csSuccess;

        NEW( POutput );
        POutput^.Index := OutputIndex;
        POutput^.Value.Type := drv_def.CWTypeToIOType( Type );
        // not needed, POutput^.Value is filled with 0 here -- POutput^.Value.ValDString := NIL;
        Outputs.Append( POutput );

        POutput^.Value.FromStringOA( Value, FALSE );
      END;

    END;   
  END MarkOutput;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE WriteOutputs( VAR CommunicationState : TCommunicationState );
  VAR
    EC : CARDINAL;
    POutput, PNext : TPPendingItem;
    TS : drv_def.TUTCStamp;
    b : BOOLEAN;
  BEGIN
    IF     UsesRunStop AND ( State <> dstRun ) OR
       NOT UsesRunStop AND ( State <> dstHasPAR ) THEN
      CommunicationState := csNotRunning;
      RETURN; // not to set actOutputRequest
    ELSIF actOutputPending IN Action THEN
      CommunicationState := csPending;
    ELSIF Outputs.Empty THEN
      CommunicationState := csSuccess;
    ELSE
      INCL( Action, actOutputPending );
      CommunicationState := csPending;
      Storage.Fill( ADR( TS ), SIZE( TS ),  0 );

      Driver.OutputRequestStart();
      b := Outputs.GetFirst( OUT POutput );
      WHILE b DO
        b := Outputs.NextOf( POutput, OUT PNext );
        
        IF Driver.OutputRequest( EC, POutput^.Index, POutput^.Value, drv_def.qosGood, TS ) THEN
          POutput^.Pending := TRUE;
        ELSE
          Outputs.Remove( POutput );

          OutputWritten( csFailure, POutput^.Index, EC );

          POutput^.Done();
          DISPOSE( POutput );
        END;

        POutput := PNext;
      END; // WHILE

      Driver.OutputRequestCompleted();
      Driver.DriverCallBackW( drv_def.dcfOutputFinalized, NIL );
    END;    
    INCL( Action, actOutputRequest );
  END WriteOutputs;

(*---------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE NotifyInputFinalized();
  VAR
    CS : TCommunicationState;
    EC : CARDINAL;
    PInput, PNext : TPPendingItem;
    b : BOOLEAN;
    StillPending : BOOLEAN;
  BEGIN
    IF     UsesRunStop AND ( State <> dstRun ) OR
       NOT UsesRunStop AND ( State <> dstHasPAR ) THEN
      RETURN;
    END;

    EXCL( Action, actInputRequest );
    StillPending := FALSE;

    b := Inputs.GetFirst( OUT PInput );
    WHILE b DO
      b := Inputs.NextOf( PInput, OUT PNext );
      IF NOT PInput^.Pending THEN // new item, which communication has not been started yet, after this item NO next should be processed now
        b := FALSE;  
      ELSIF Driver.InputFinalized( PInput^.Index, EC ) THEN
        Inputs.Remove( PInput );

        InputRead( csSuccess, PInput^.Index, EC ); // the call can append new items to be read

        PInput^.Done();
        DISPOSE( PInput );
      ELSE
        StillPending := TRUE;
      END;
      PInput := PNext;
    END; // WHILE;

    IF NOT StillPending THEN
      EXCL( Action, actInputPending );
    END;
    IF actInputRequest IN Action THEN
      ReadInputs( CS );
    END;
  END NotifyInputFinalized;

(*---------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE NotifyOutputFinalized();
  VAR
    CS : TCommunicationState;
    EC : CARDINAL;
    POutput, PNext : TPPendingItem;
    b : BOOLEAN;
    StillPending : BOOLEAN;
  BEGIN
    IF     UsesRunStop AND ( State <> dstRun ) OR
       NOT UsesRunStop AND ( State <> dstHasPAR ) THEN
      RETURN;
    END;

    EXCL( Action, actOutputRequest );
    StillPending := FALSE;

    b := Outputs.GetFirst( OUT POutput );
    WHILE b DO
      b := Outputs.NextOf( POutput, OUT PNext );
      IF NOT POutput^.Pending THEN // new item, which communication has not been started yet, after this item NO next should be processed now
        b := FALSE;
      ELSIF Driver.OutputFinalized( POutput^.Index, EC ) THEN
        Outputs.Remove( POutput );

        OutputWritten( csSuccess, POutput^.Index, EC ); // the call can append new items to be written

        POutput^.Done();
        DISPOSE( POutput );
      ELSE
        StillPending := TRUE;
      END;
      POutput := PNext;
    END; // WHILE;

    IF NOT StillPending THEN
      EXCL( Action, actOutputPending );
    END;
    IF actOutputRequest IN Action THEN
      WriteOutputs( CS );
    END;
  END NotifyOutputFinalized;

(*---------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE NotifyOOBDataAdvice();
  VAR
    ES : LONGWORD;
    Index : CARDINAL;
  BEGIN
    IF     UsesRunStop AND ( State <> dstRun ) OR
       NOT UsesRunStop AND ( State <> dstHasPAR ) THEN
      RETURN;
    END;
    ES := 0;
    WHILE Driver.InputOOBDataQuery( ES, Index ) DO
      InputRead( csSuccess, Index, drv_def.ecSuccess );
    END; // WHILE
  END NotifyOOBDataAdvice;

(*---------------------------------------------------------------------------*)

  INTERNAL PROCEDURE InputRead( CommunicationState : TCommunicationState; Index : CARDINAL; EC : CARDINAL );
  VAR
    CWType : drv_def.TValueType;
    Direction : drv_def.TDirection;
    ES : ARRAY [0..3] OF WCHAR;
    IID, IIDx : guiddef.IID;
    QOS : CARDINAL;
    Parameters : ARRAY [0..3] OF oaidl.VARIANTARG;
    Value : iovalue.Value;
    TS : drv_def.TUTCStamp;
  BEGIN
    IF ( CommunicationState = csSuccess ) AND ( EC <> drv_def.ecSuccess ) THEN
      CommunicationState := csFailure;
    ELSIF Map.Get( ES, Index, CWType, Direction ) THEN
       Value.Type := drv_def.CWTypeToIOType( CWType );
       IF NOT Driver.GetInput( EC, Index, Value, QOS, TS ) THEN
         CommunicationState := csFailure;
       END;
    ELSE
      EC := drv_def.ecUnknownElement;
      CommunicationState := csFailure;
    END;

    // parameters are of reveresed order
    oleauto.VariantInit( ADR( Parameters[3] ));
    Parameters[3].vt := wtypes.VT_I4;
    Parameters[3].lVal := windows.LONG( CommunicationState );

    oleauto.VariantInit( ADR( Parameters[2] ));
    Parameters[2].vt := wtypes.VT_I4;
    Parameters[2].lVal := windows.LONG( Index );

    oleauto.VariantInit( ADR( Parameters[1] ));
    Parameters[1].vt := wtypes.VT_I4;
    Parameters[1].lVal := windows.LONG( EC );

    oleauto.VariantInit( ADR( Parameters[0] ));
    Parameters[0].vt := wtypes.VT_BSTR;
    Parameters[0].bstrVal := oleauto.SysAllocString( Value.String.Data );

    ax_automation.GetClientConstructor()^.QueryControlIIDs( IIDx, IIDx, IIDx, IID );
    DispatchEvent( IID, LONGWORD( eidRead ), Parameters );

    oleauto.VariantClear( ADR( Parameters[0] ));
    oleauto.VariantClear( ADR( Parameters[1] ));
    oleauto.VariantClear( ADR( Parameters[2] ));
    oleauto.VariantClear( ADR( Parameters[3] ));
  END InputRead;

(*---------------------------------------------------------------------------*)

  INTERNAL PROCEDURE OutputWritten( CommunicationState : TCommunicationState; Index : CARDINAL; EC : CARDINAL );
  VAR
    IID, IIDx : guiddef.IID;
    Parameters : ARRAY [0..2] OF oaidl.VARIANTARG;
  BEGIN
    IF ( CommunicationState = csSuccess ) AND ( EC <> drv_def.ecSuccess ) THEN
      CommunicationState := csFailure;
    END;

    // parameters are of reveresed order
    oleauto.VariantInit( ADR( Parameters[2] ));
    Parameters[2].vt := wtypes.VT_I4;
    Parameters[2].lVal := windows.LONG( CommunicationState );

    oleauto.VariantInit( ADR( Parameters[1] ));
    Parameters[1].vt := wtypes.VT_I4;
    Parameters[1].lVal := windows.LONG( Index );

    oleauto.VariantInit( ADR( Parameters[0] ));
    Parameters[0].vt := wtypes.VT_I4;
    Parameters[0].lVal := windows.LONG( EC );

    ax_automation.GetClientConstructor()^.QueryControlIIDs( IIDx, IIDx, IIDx, IID );
    DispatchEvent( IID, LONGWORD( eidWritten ), Parameters );

    oleauto.VariantClear( ADR( Parameters[0] ));
    oleauto.VariantClear( ADR( Parameters[1] ));
    oleauto.VariantClear( ADR( Parameters[2] ));
  END OutputWritten;

(*---------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE CreateNativeIDispatch( VAR PIDispatch : ax_automation.TPActiveXDispatch ) : BOOLEAN; // must call AddRef to PIDispatch
  VAR
    IID, IIDx : guiddef.IID;
    HR : wtypes.HRESULT;
  BEGIN
    NEW( TPIDrvAx_Native( PIDispatch ));
    PIDispatch^.AddRef();
    TPIDrvAx_Native( PIDispatch )^.PActiveX := ADR( SELF );

    ax_automation.GetClientConstructor()^.QueryControlIIDs( IIDx, IIDx, IID, IIDx );
    HR := PIDispatch^.Init( IID, ADR( SELF ));

    IF HR = winerror.S_OK THEN
      RETURN TRUE;
    ELSE
      RETURN FALSE;
    END;
  END CreateNativeIDispatch;

(*---------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE EnumerateEventIDispatch( VAR EnumerateState : LONGWORD; VAR IID : guiddef.IID ) : BOOLEAN;
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

(*---------------------------------------------------------------------------*)

BEGIN
  HModule := NIL;
  State := dstBegin;
  Action := TAction{};
  UsesRunStop := FALSE;
  Driver.PActiveX := ADR( SELF );
  Messager.PActiveX := ADR( SELF );
  Messager.Init( TRUE ); 
END CDriverActiveX;

(*===========================================================================*)

CLASS IMPLEMENTATION CClientConstructor;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE CreateInstance( VAR PInstance : ax_automation.TPActiveXControl ) : wtypes.HRESULT;
  VAR
    ControlIID, IIDx : guiddef.IID;
    PAX : TPDriverActiveX;
    b : BOOLEAN;
  BEGIN
    QueryControlIIDs( ControlIID, IIDx, IIDx, IIDx );
    QueryUsesRunStop( b );

    NEW( PAX );
    PAX^.IID := ControlIID;
    PAX^.AddRef();
    PAX^.Init( b );

    PInstance := PAX;
    RETURN winerror.S_OK;
  END CreateInstance;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE QueryControlIIDs( VAR ControlIID, TypeLibIID, IDispatch_Native_IID, IDispatch_Event_IID : guiddef.IID );
  BEGIN
    ControlIID := guiddef.IID_NULL;
    TypeLibIID := guiddef.IID_NULL;
    IDispatch_Native_IID := guiddef.IID_NULL;
    IDispatch_Event_IID := guiddef.IID_NULL;
  END QueryControlIIDs;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE QueryControlNames( VAR DLLName, ControlName, ProgId : ARRAY OF WCHAR; VAR ProgIdCurrentVersion : CARDINAL );
  BEGIN
    ASSIGN( DLLName, L'drv_ax_EXAMPLE.dll' );
    ASSIGN( ControlName, L'Control Web Example Driver ActiveX Control' );
    ASSIGN( ProgId, L'ControlWeb.DrvAxEXA' );
    ProgIdCurrentVersion := 1;
  END QueryControlNames;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE QueryTypeLibIndexes( VAR IControl, IDispatch_Native, IDispatch_Event : CARDINAL );
  BEGIN
    IControl := 0;
    IDispatch_Native := 0;
    IDispatch_Event := 0;
  END QueryTypeLibIndexes;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE QueryUsesRunStop( VAR UsesRunStop : BOOLEAN );
  BEGIN
    UsesRunStop := FALSE;
  END QueryUsesRunStop;

(*---------------------------------------------------------------------------*)

BEGIN
END CClientConstructor;

(*===========================================================================*)

END drv_ax.