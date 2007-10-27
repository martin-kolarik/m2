IMPLEMENTATION MODULE drv_wrapper;

(*# call( o_a_copy => off ) *)
(*# option( pack => 4 ) *)
(*# warn ( 4554 => off ) *) // check >> operator precedence

(*----------------------------------------------------------------------*)
(*                                                                      *)
(*                         Control Web v.3.0                            *)
(*                                                                      *)
(*                              CW_DRV                                  *)
(*                                                                      *)
(*           (c) 1992 - 1997 Alcor - Moravian Instruments               *)
(*                                                                      *)
(*----------------------------------------------------------------------*)

IMPORT
  windows,
  Storage,
  Strings;

FROM Storage IMPORT
  ALLOCATE, DEALLOCATE;
  
IMPORT
  drv_wrapper_;

CONST
#if PlatformName #startswith L"WinCE" #then
  // ANSI-procedure names
  procVersionA                   = L'Version';
  procCheckA                     = L'Check';
  procGetDriverInfoA             = L'GetDriverInfo';
  procSystemEnvironmentA         = L'SystemEnvironment';
  procMakeDriverA                = L'MakeDriver';
  procDisposeDriverA             = L'DisposeDriver';
  procInitA                      = L'Init';
  procInit3A                     = L'Init3';
  procReadParametersA            = L'ReadParameters';
  procQueryErrorCodeA            = L'QueryErrorCode';
  procQueryErrorCodeA            = L'QueryErrorCode';
  procEnumerateChannelsA         = L'EnumerateChannels';
  procRunA                       = L'Run';
  procStopA                      = L'Stop';
  procDoneA                      = L'Done';
  procBufferInfoA                = L'BufferInfo';
  procSetBufferAddrA             = L'SetBufferAddr';
  procQueryChannelTypeA          = L'QueryChannelType';
  procQueryChannelTypeCompletedA = L'QueryChannelTypeCompleted';
  procInputRequestStartA         = L'InputRequestStart';
  procInputRequestA              = L'InputRequest';
  procInputRequestCompletedA     = L'InputRequestCompleted';
  procInputFinalizedA            = L'InputFinalized';
  procInputOOBDataQueryA         = L'InputOOBDataQuery';
  procGetInput1A                 = L'GetInput';
  procGetInput2A                 = L'GetInput2';
  procGetInput3A                 = L'GetInput3';
  procOutputRequestStartA        = L'OutputRequestStart';
  procOutputRequest1A            = L'OutputRequest';
  procOutputRequest2A            = L'OutputRequest2';
  procOutputRequest3A            = L'OutputRequest3';
  procOutputRequestCompletedA    = L'OutputRequestCompleted';
  procOutputFinalizedA           = L'OutputFinalized';
  procDriverProcA                = L'DriverProc';
  procQueryProc1A                = L'QueryProc';
  procQueryProc3A                = L'QueryProc3';
  // UNICODE-procedure names
  procVersionW                   = L'VersionW';
  procCheckW                     = L'CheckW';
  procGetDriverInfoW             = L'GetDriverInfoW';
  procSystemEnvironmentW         = L'SystemEnvironmentW';
  procMakeDriverW                = L'MakeDriverW';
  procDisposeDriverW             = L'DisposeDriverW';
  procInitW                      = L'InitW';
  procInit3W                     = L'Init3W';
  procReadParametersW            = L'ReadParametersW';
  procQueryErrorCodeW            = L'QueryErrorCodeW';
  procEnumerateChannelsW         = L'EnumerateChannelsW';
  procGetChannelDescriptionW     = L'GetChannelDescriptionW';
  procRunW                       = L'RunW';
  procStopW                      = L'StopW';
  procDoneW                      = L'DoneW';
  procBufferInfoW                = L'BufferInfoW';
  procSetBufferAddrW             = L'SetBufferAddrW';
  procQueryChannelTypeW          = L'QueryChannelTypeW';
  procQueryChannelTypeCompletedW = L'QueryChannelTypeCompletedW';
  procInputRequestStartW         = L'InputRequestStartW';
  procInputRequestW              = L'InputRequestW';
  procInputRequestCompletedW     = L'InputRequestCompletedW';
  procInputFinalizedW            = L'InputFinalizedW';
  procInputOOBDataQueryW         = L'InputOOBDataQueryW';
  procGetInput1W                 = L'GetInputW';
  procGetInput2W                 = L'GetInput2W';
  procGetInput3W                 = L'GetInput3W';
  procOutputRequestStartW        = L'OutputRequestStartW';
  procOutputRequest1W            = L'OutputRequestW';
  procOutputRequest2W            = L'OutputRequest2W';
  procOutputRequest3W            = L'OutputRequest3W';
  procOutputRequestCompletedW    = L'OutputRequestCompletedW';
  procOutputFinalizedW           = L'OutputFinalizedW';
  procDriverProcW                = L'DriverProcW';
  procQueryProc1W                = L'QueryProcW';
  procQueryProc3W                = L'QueryProc3W';
#else
  // ANSI-procedure names
  procVersionA                   = C'Version';
  procCheckA                     = C'Check';
  procGetDriverInfoA             = C'GetDriverInfo';
  procSystemEnvironmentA         = C'SystemEnvironment';
  procMakeDriverA                = C'MakeDriver';
  procDisposeDriverA             = C'DisposeDriver';
  procInitA                      = C'Init';
  procInit3A                     = C'Init3';
  procReadParametersA            = C'ReadParameters';
  procQueryErrorCodeA            = C'QueryErrorCode';
  procEnumerateChannelsA         = C'EnumerateChannels';
  procInputParametersA           = C'InputParameters';
  procGetChannelDescriptionA     = C'GetChannelDescription';
  procRunA                       = C'Run';
  procStopA                      = C'Stop';
  procDoneA                      = C'Done';
  procBufferInfoA                = C'BufferInfo';
  procSetBufferAddrA             = C'SetBufferAddr';
  procQueryChannelTypeA          = C'QueryChannelType';
  procQueryChannelTypeCompletedA = C'QueryChannelTypeCompleted';
  procInputRequestStartA         = C'InputRequestStart';
  procInputRequestA              = C'InputRequest';
  procInputRequestCompletedA     = C'InputRequestCompleted';
  procInputFinalizedA            = C'InputFinalized';
  procInputOOBDataQueryA         = C'InputOOBDataQuery';
  procGetInput1A                 = C'GetInput';
  procGetInput2A                 = C'GetInput2';
  procGetInput3A                 = C'GetInput3';
  procOutputRequestStartA        = C'OutputRequestStart';
  procOutputRequest1A            = C'OutputRequest';
  procOutputRequest2A            = C'OutputRequest2';
  procOutputRequest3A            = C'OutputRequest3';
  procOutputRequestCompletedA    = C'OutputRequestCompleted';
  procOutputFinalizedA           = C'OutputFinalized';
  procDriverProcA                = C'DriverProc';
  procQueryProc1A                = C'QueryProc';
  procQueryProc3A                = C'QueryProc3';
  // UNICODE-procedure names
  procVersionW                   = C'VersionW';
  procCheckW                     = C'CheckW';
  procGetDriverInfoW             = C'GetDriverInfoW';
  procSystemEnvironmentW         = C'SystemEnvironmentW';
  procMakeDriverW                = C'MakeDriverW';
  procDisposeDriverW             = C'DisposeDriverW';
  procInitW                      = C'InitW';
  procInit3W                     = C'Init3W';
  procReadParametersW            = C'ReadParametersW';
  procQueryErrorCodeW            = C'QueryErrorCodeW';
  procEnumerateChannelsW         = C'EnumerateChannelsW';
  procInputParametersW           = C'InputParametersW';
  procGetChannelDescriptionW     = C'GetChannelDescriptionW';
  procRunW                       = C'RunW';
  procStopW                      = C'StopW';
  procDoneW                      = C'DoneW';
  procBufferInfoW                = C'BufferInfoW';
  procSetBufferAddrW             = C'SetBufferAddrW';
  procQueryChannelTypeW          = C'QueryChannelTypeW';
  procQueryChannelTypeCompletedW = C'QueryChannelTypeCompletedW';
  procInputRequestStartW         = C'InputRequestStartW';
  procInputRequestW              = C'InputRequestW';
  procInputRequestCompletedW     = C'InputRequestCompletedW';
  procInputFinalizedW            = C'InputFinalizedW';
  procInputOOBDataQueryW         = C'InputOOBDataQueryW';
  procGetInput1W                 = C'GetInputW';
  procGetInput2W                 = C'GetInput2W';
  procGetInput3W                 = C'GetInput3W';
  procOutputRequestStartW        = C'OutputRequestStartW';
  procOutputRequest1W            = C'OutputRequestW';
  procOutputRequest2W            = C'OutputRequest2W';
  procOutputRequest3W            = C'OutputRequest3W';
  procOutputRequestCompletedW    = C'OutputRequestCompletedW';
  procOutputFinalizedW           = C'OutputFinalizedW';
  procDriverProcW                = C'DriverProcW';
  procQueryProc1W                = C'QueryProcW';
  procQueryProc3W                = C'QueryProc3W';
#endif

(*============================================================*)

CONST
	CZECH = TRUE;
	ENGLISH = FALSE;

(*%T CZECH *)
  _DLLHasBadInterface     = 'DLL ovladaè nevyváží požadované rozhraní: ';
  _ProcedureNotFoundInDLL = ' procedura nebyla nalezena v souboru ';
  _UnableCreateData       = ' : Nelze vytvoøit ovladaè.';
(*%E CZECH *)

(*%T ENGLISH *)
  _DLLHasBadInterface     = 'Driver DLL does not export required interface: ';
  _ProcedureNotFoundInDLL = ' procedure not found in file ';
  _UnableCreateData       = ' : Make driver error.';
(*%E ENGLISH *)

(*# save, call( convention => cdecl ) *)

PROCEDURE CWDriverCallback( PDriver : ADDRESS; Func : CARDINAL; Param : ADDRESS ) : CARDINAL;
BEGIN
  IF PDriver <> NIL THEN
    RETURN TPDriver( PDriver )^.DriverCallBackA( Func, Param  );
  ELSE
    RETURN drv_def.erNoFunction;
  END;
END CWDriverCallback;

PROCEDURE CWDriverCallbackW( PDriver : ADDRESS; Func : CARDINAL; Param : ADDRESS ) : CARDINAL;
BEGIN
  IF PDriver <> NIL THEN
    RETURN TPDriver( PDriver )^.DriverCallBackW( Func, Param  );
  ELSE
    RETURN drv_def.erNoFunction;
  END;
END CWDriverCallbackW;

(*# restore *)

(*============================================================================*)

CONST
  initialBufferSize = 1024;

(*----------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CDriver;

(*----------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Init( _DLLHandle : windows.HANDLE );
  VAR
    es : ARRAY [0..3] OF WCHAR;
  BEGIN
    DLLHandle := _DLLHandle;
    ComponentHelper.Init( es, DLLHandle );
  END Init;

(*----------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE Version( VAR DLLVersion : CARDINAL ) : BOOLEAN;
  BEGIN
    IF ComponentHelper.Version( DLLVersion ) THEN
      DriverDLLVersion := DLLVersion;
      RETURN TRUE;
    ELSE
      RETURN FALSE;
    END;
  END Version;

(*----------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE GetDriverInfo( VAR DriverInfo : ARRAY OF WCHAR ) : BOOLEAN;
  BEGIN
    RETURN ComponentHelper.GetDriverDescription( DriverInfo );
  END GetDriverInfo;

(*----------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE Initialize( 
                                       VAR ErrorString     : ARRAY OF WCHAR;
                                       _DriverRunMode      : CARDINAL;
                                       _SymbolicDriverName : ARRAY OF WCHAR
                                      ) : BOOLEAN;

  (*----------*)

    PROCEDURE InitializeDLLA( VAR ErrorString : ARRAY OF WCHAR ) : BOOLEAN;
    BEGIN
      __SystemEnvironment := TSystemEnvironment( windows.GetProcAddress( DLLHandle, procSystemEnvironmentA ));

      __MakeDriver := TMakeDriver( windows.GetProcAddress( DLLHandle, procMakeDriverA ));
      IF ADDRESS( __MakeDriver ) = NIL THEN
        Strings.ConcatW( OUT ErrorString, L'MakeDriver', _ProcedureNotFoundInDLL );
        RETURN FALSE;
      END;

      __DisposeDriver := TDisposeDriver( windows.GetProcAddress( DLLHandle, procDisposeDriverA ));
      IF ADDRESS( __DisposeDriver ) = NIL THEN
        Strings.ConcatW( OUT ErrorString, L'DisposeDriver', _ProcedureNotFoundInDLL );
        RETURN FALSE;
      END;

      __Init := TInit( windows.GetProcAddress( DLLHandle, procInitA ));
      __Init3 := TInit3( windows.GetProcAddress( DLLHandle, procInit3A ));
      IF ( ADDRESS( __Init ) = NIL ) AND
         ( ADDRESS( __Init3 ) = NIL ) THEN
        Strings.ConcatW( OUT ErrorString, L'Init, Init3', _ProcedureNotFoundInDLL );
        RETURN FALSE;
      END;

      __ReadParameters := TReadParameters( windows.GetProcAddress( DLLHandle, procReadParametersA ));
      __QueryErrorCode := TQueryErrorCode( windows.GetProcAddress( DLLHandle, procQueryErrorCodeA ));
      __EnumerateChannels := TEnumerateChannels( windows.GetProcAddress( DLLHandle, procEnumerateChannelsA ));
      __InputParameters := TInputParameters( windows.GetProcAddress( DLLHandle, procInputParametersA ));
      __GetChannelDescription := TGetChannelDescription( windows.GetProcAddress( DLLHandle, procGetChannelDescriptionA ));

      __Run := TRun( windows.GetProcAddress( DLLHandle, procRunA ));
      __Stop := TStop( windows.GetProcAddress( DLLHandle, procStopA ));

      __Done := TDone( windows.GetProcAddress( DLLHandle, procDoneA ));
      IF ADDRESS( __Done ) = NIL THEN
        Strings.ConcatW( OUT ErrorString, L'Done', _ProcedureNotFoundInDLL );
        RETURN FALSE;
      END;

      __BufferInfo := TBufferInfo( windows.GetProcAddress( DLLHandle, procBufferInfoA ));
      __SetBufferAddr := TSetBufferAddr( windows.GetProcAddress( DLLHandle, procSetBufferAddrA ));
      __InputRequestStart := TInputRequestStart( windows.GetProcAddress( DLLHandle, procInputRequestStartA ));

      __InputRequest := TInputRequest( windows.GetProcAddress( DLLHandle, procInputRequestA ));
      IF ADDRESS( __InputRequest ) = NIL THEN
        Strings.ConcatW( OUT ErrorString, L'InputRequest', _ProcedureNotFoundInDLL );
        RETURN FALSE;
      END;

      __InputRequestCompleted := TInputRequestCompleted( windows.GetProcAddress( DLLHandle, procInputRequestCompletedA ));
      IF ADDRESS( __InputRequestCompleted ) = NIL THEN
        Strings.ConcatW( OUT ErrorString, L'InputRequestCompleted', _ProcedureNotFoundInDLL );
        RETURN FALSE;
      END;

      __InputFinalized := TInputFinalized( windows.GetProcAddress( DLLHandle, procInputFinalizedA ));
      IF ADDRESS( __InputFinalized ) = NIL THEN
        Strings.ConcatW( OUT ErrorString, L'InputFinalized', _ProcedureNotFoundInDLL );
        RETURN FALSE;
      END;

      __InputOOBDataQuery := TInputOOBDataQuery( windows.GetProcAddress( DLLHandle, procInputOOBDataQueryA ));

      __GetInput1 := TGetInput1( windows.GetProcAddress( DLLHandle, procGetInput1A ));
      __OutputRequest1 := TOutputRequest1( windows.GetProcAddress( DLLHandle, procOutputRequest1A ));
      __OutputRequestStart := TOutputRequestStart( windows.GetProcAddress( DLLHandle, procOutputRequestStartA ));

      __OutputRequestCompleted := TOutputRequestCompleted( windows.GetProcAddress( DLLHandle, procOutputRequestCompletedA ));
      IF ADDRESS( __OutputRequestCompleted ) = NIL THEN
        Strings.ConcatW( OUT ErrorString, L'OutputRequestCompleted', _ProcedureNotFoundInDLL );
        RETURN FALSE;
      END;

      __OutputFinalized := TOutputFinalized( windows.GetProcAddress( DLLHandle, procOutputFinalizedA ));
      IF ADDRESS( __OutputFinalized ) = NIL THEN
        Strings.ConcatW( OUT ErrorString, L'OutputFinalized', _ProcedureNotFoundInDLL );
        RETURN FALSE;
      END;

      __DriverProc := TDriverProc( windows.GetProcAddress( DLLHandle, procDriverProcA ));
      IF ADDRESS( __DriverProc ) = NIL THEN
        Strings.ConcatW( OUT ErrorString, L'DriverProc', _ProcedureNotFoundInDLL );
        RETURN FALSE;
      END;

      __QueryProc1 := TQueryProc1( windows.GetProcAddress( DLLHandle, procQueryProc1A ));

      __GetInput2 := TGetInput2( windows.GetProcAddress( DLLHandle, procGetInput2A ));
      __OutputRequest2 := TOutputRequest2( windows.GetProcAddress( DLLHandle, procOutputRequest2A ));

      __GetInput3 := TGetInput3( windows.GetProcAddress( DLLHandle, procGetInput3A ));
      __OutputRequest3 := TOutputRequest3( windows.GetProcAddress( DLLHandle, procOutputRequest3A ));
      __QueryProc3 := TQueryProc3( windows.GetProcAddress( DLLHandle, procQueryProc3A ));

      IF ( ADDRESS( __GetInput1 ) = NIL ) AND
         ( ADDRESS( __GetInput2 ) = NIL ) AND
         ( ADDRESS( __GetInput3 ) = NIL ) THEN
        Strings.ConcatW( OUT ErrorString, L'GetInput, GetInput2, GetInput3', _ProcedureNotFoundInDLL );
        RETURN FALSE;
      END;
      IF ( ADDRESS( __OutputRequest1 ) = NIL ) AND
         ( ADDRESS( __OutputRequest2 ) = NIL ) AND
         ( ADDRESS( __OutputRequest3 ) = NIL ) THEN
        Strings.ConcatW( OUT ErrorString, L'OutputRequest, OutputRequest2, OutputRequest3', _ProcedureNotFoundInDLL );
        RETURN FALSE;
      END;

      RETURN TRUE;
    END InitializeDLLA;

  (*----------*)

    PROCEDURE InitializeDriverA( VAR ErrorString : ARRAY OF WCHAR ) : BOOLEAN;
    VAR
      LocalName : ARRAY [0..63] OF CHAR;
    BEGIN;
      PObjectData := __MakeDriver();
      IF PObjectData = NIL THEN
        Strings.ConcatW( OUT ErrorString, DriverAppName, _UnableCreateData );
        RETURN FALSE;
      END;
      (*?*) // system environment...
      IF ADDRESS( __Init3 ) <> NIL THEN
        Strings.ToA( DriverAppName, 0, OUT LocalName );
        __Init3( PObjectData, DriverRunMode, LocalName, ADR( SELF ), TDriverCallback( CWDriverCallback ));
      END;
      RETURN TRUE;
    END InitializeDriverA;

  (*----------*)

    PROCEDURE InitializeDLLW( VAR ErrorString : ARRAY OF WCHAR ) : BOOLEAN;
    BEGIN
      __SystemEnvironmentW := TSystemEnvironmentW( windows.GetProcAddress( DLLHandle, procSystemEnvironmentW ));

      __MakeDriverW := TMakeDriverW( windows.GetProcAddress( DLLHandle, procMakeDriverW ));
      IF ADDRESS( __MakeDriverW ) = NIL THEN
        Strings.ConcatW( OUT ErrorString, L'MakeDriverW', _ProcedureNotFoundInDLL );
        RETURN FALSE;
      END;

      __DisposeDriverW := TDisposeDriverW( windows.GetProcAddress( DLLHandle, procDisposeDriverW ));
      IF ADDRESS( __DisposeDriverW ) = NIL THEN
        Strings.ConcatW( OUT ErrorString, L'DisposeDriverW', _ProcedureNotFoundInDLL );
        RETURN FALSE;
      END;

      __InitW := TInitW( windows.GetProcAddress( DLLHandle, procInitW ));
      __Init3W := TInit3W( windows.GetProcAddress( DLLHandle, procInit3W ));
      IF ( ADDRESS( __InitW ) = NIL ) AND
         ( ADDRESS( __Init3W ) = NIL ) THEN
        Strings.ConcatW( OUT ErrorString, L'InitW, Init3W', _ProcedureNotFoundInDLL );
        RETURN FALSE;
      END;

      __ReadParametersW := TReadParametersW( windows.GetProcAddress( DLLHandle, procReadParametersW ));
      __QueryErrorCodeW := TQueryErrorCodeW( windows.GetProcAddress( DLLHandle, procQueryErrorCodeW ));
      __EnumerateChannelsW := TEnumerateChannelsW( windows.GetProcAddress( DLLHandle, procEnumerateChannelsW ));
      __InputParametersW := TInputParametersW( windows.GetProcAddress( DLLHandle, procInputParametersW ));
      __GetChannelDescriptionW := TGetChannelDescriptionW( windows.GetProcAddress( DLLHandle, procGetChannelDescriptionW ));

      __RunW := TRunW( windows.GetProcAddress( DLLHandle, procRunW ));
      __StopW := TStopW( windows.GetProcAddress( DLLHandle, procStopW ));

      __DoneW := TDoneW( windows.GetProcAddress( DLLHandle, procDoneW ));
      IF ADDRESS( __DoneW ) = NIL THEN
        Strings.ConcatW( OUT ErrorString, L'DoneW', _ProcedureNotFoundInDLL );
        RETURN FALSE;
      END;

      __BufferInfoW := TBufferInfoW( windows.GetProcAddress( DLLHandle, procBufferInfoW ));
      __SetBufferAddrW := TSetBufferAddrW( windows.GetProcAddress( DLLHandle, procSetBufferAddrW ));
      __InputRequestStartW := TInputRequestStartW( windows.GetProcAddress( DLLHandle, procInputRequestStartW ));

      __InputRequestW := TInputRequestW( windows.GetProcAddress( DLLHandle, procInputRequestW ));
      IF ADDRESS( __InputRequestW ) = NIL THEN
        Strings.ConcatW( OUT ErrorString, 'InputRequestW', _ProcedureNotFoundInDLL );
        RETURN FALSE;
      END;

      __InputRequestCompletedW := TInputRequestCompletedW( windows.GetProcAddress( DLLHandle, procInputRequestCompletedW ));
      IF ADDRESS( __InputRequestCompletedW ) = NIL THEN
        Strings.ConcatW( OUT ErrorString, L'InputRequestCompletedW', _ProcedureNotFoundInDLL );
        RETURN FALSE;
      END;

      __InputFinalizedW := TInputFinalizedW( windows.GetProcAddress( DLLHandle, procInputFinalizedW ));
      IF ADDRESS( __InputFinalizedW ) = NIL THEN
        Strings.ConcatW( OUT ErrorString, L'InputFinalizedW', _ProcedureNotFoundInDLL );
        RETURN FALSE;
      END;

      __InputOOBDataQueryW := TInputOOBDataQueryW( windows.GetProcAddress( DLLHandle, procInputOOBDataQueryW ));

      __GetInput1W := TGetInput1W( windows.GetProcAddress( DLLHandle, procGetInput1W ));
      __OutputRequest1W := TOutputRequest1W( windows.GetProcAddress( DLLHandle, procOutputRequest1W ));
      __OutputRequestStartW := TOutputRequestStartW( windows.GetProcAddress( DLLHandle, procOutputRequestStartW ));

      __OutputRequestCompletedW := TOutputRequestCompletedW( windows.GetProcAddress( DLLHandle, procOutputRequestCompletedW ));
      IF ADDRESS( __OutputRequestCompletedW ) = NIL THEN
        Strings.ConcatW( OUT ErrorString, L'OutputRequestCompletedW', _ProcedureNotFoundInDLL );
        RETURN FALSE;
      END;

      __OutputFinalizedW := TOutputFinalizedW( windows.GetProcAddress( DLLHandle, procOutputFinalizedW ));
      IF ADDRESS( __OutputFinalizedW ) = NIL THEN
        Strings.ConcatW( OUT ErrorString, L'OutputFinalizedW', _ProcedureNotFoundInDLL );
        RETURN FALSE;
      END;

      __DriverProcW := TDriverProcW( windows.GetProcAddress( DLLHandle, procDriverProcW ));
      IF ADDRESS( __DriverProcW ) = NIL THEN
        Strings.ConcatW( OUT ErrorString, 'DriverProcW', _ProcedureNotFoundInDLL );
        RETURN FALSE;
      END;

      __QueryProc1W := TQueryProc1W( windows.GetProcAddress( DLLHandle, procQueryProc1W ));

      __GetInput2W := TGetInput2W( windows.GetProcAddress( DLLHandle, procGetInput2W ));
      __OutputRequest2W := TOutputRequest2W( windows.GetProcAddress( DLLHandle, procOutputRequest2W ));

      __GetInput3W := TGetInput3W( windows.GetProcAddress( DLLHandle, procGetInput3W ));
      __OutputRequest3W := TOutputRequest3W( windows.GetProcAddress( DLLHandle, procOutputRequest3W ));
      __QueryProc3W := TQueryProc3W( windows.GetProcAddress( DLLHandle, procQueryProc3W ));

      IF ( ADDRESS( __GetInput1W ) = NIL ) AND
         ( ADDRESS( __GetInput2W ) = NIL ) AND
         ( ADDRESS( __GetInput3W ) = NIL ) THEN
        Strings.ConcatW( OUT ErrorString, L'GetInputW, GetInput2W, GetInput3W', _ProcedureNotFoundInDLL );
        RETURN FALSE;
      END;
      IF ( ADDRESS( __OutputRequest1W ) = NIL ) AND
         ( ADDRESS( __OutputRequest2W ) = NIL ) AND
         ( ADDRESS( __OutputRequest3W ) = NIL ) THEN
        Strings.ConcatW( OUT ErrorString, L'OutputRequestW, OutputRequest2W, OutputRequest3W', _ProcedureNotFoundInDLL );
        RETURN FALSE;
      END;

      RETURN TRUE;
    END InitializeDLLW;

  (*----------*)

    PROCEDURE InitializeDriverW( VAR ErrorString : ARRAY OF WCHAR ) : BOOLEAN;
    VAR
      LocalName : ARRAY [0..63] OF WCHAR;
    BEGIN;
      PObjectData := __MakeDriverW();
      IF PObjectData = NIL THEN
        Strings.ConcatW( OUT ErrorString, DriverAppName, _UnableCreateData );
        RETURN FALSE;
      END;
      (*?*) // system environment...
      IF ADDRESS( __Init3W ) <> NIL THEN
        ASSIGN( LocalName, DriverAppName );
        __Init3W( PObjectData, DriverRunMode, LocalName, ADR( SELF ), TDriverCallbackW( CWDriverCallbackW ));
      END;
      RETURN TRUE;
    END InitializeDriverW;

  (*----------*)

  LABEL
    DLLFailure,
    DLLInitFailure;
  VAR
    a : ADDRESS;
    l : CARDINAL;
    uf : BOOLEAN;
  BEGIN
    DriverRunMode := _DriverRunMode;
    ASSIGN( DriverAppName, _SymbolicDriverName );
    IF NOT ComponentHelper.IsUNICODE( uf ) THEN
      ASSIGN( ErrorString, _DLLHasBadInterface );
      GOTO DLLFailure;
    END;

    IF uf THEN
      IF NOT InitializeDLLW( ErrorString ) THEN
        GOTO DLLFailure;
      END;
      IF NOT InitializeDriverW( ErrorString ) THEN
        GOTO DLLInitFailure;
      END;
      drv_str.EnsureDStrLenW( PBufferW, initialBufferSize, a, l );
    ELSE
      IF NOT InitializeDLLA( ErrorString ) THEN
        GOTO DLLFailure;
      END;
      IF NOT InitializeDriverA( ErrorString ) THEN
        GOTO DLLInitFailure;
      END;
      drv_str.EnsureDStrLenA( PBufferA, initialBufferSize, a, l );
    END;

    RETURN TRUE;

DLLFailure:
    Strings.AppendW( REF ErrorString, DriverAppName );
DLLInitFailure:
    RETURN FALSE;
  END Initialize;

(*----------------------------------------------------------------------------*)
 
  PUBLIC VIRTUAL PROCEDURE ReadParameters(
                                          _ParFilePath       : ARRAY OF WCHAR;
                                          VAR ErrorString    : ARRAY OF WCHAR;
                                          VAR ErrorLine      : CARDINAL;
                                          VAR ErrorColumn    : CARDINAL;
                                          VAR HintOrHelp     : ARRAY OF WCHAR
                                         ) : BOOLEAN;

  (*----------*)

    PROCEDURE ReadParametersA( VAR ErrorString : ARRAY OF WCHAR ) : BOOLEAN;
    VAR
      LocalPath : ARRAY [0..260] OF CHAR;
      LocalText1 : ARRAY [0..255] OF CHAR;
      LocalText2 : ARRAY [0..255] OF CHAR;
    BEGIN;
      Strings.ToA( ParFilePath, 0, OUT LocalPath );

      IF ADDRESS( __Init3 ) = NIL THEN // __Init will be called
        Strings.ToA( DriverAppName, 0, OUT LocalText1 );

        IF NOT __Init( PObjectData,                        // PData
                       LocalPath,                          // ParamFileName
                       LocalText1,                         // SymbolicDriverName/InitMessage
                       0,                                  // Level
                       DriverRunMode = drv_def.drmRun,     // RunFlag
                       ADR( SELF ),                        // PDriver
                       TDriverCallback( CWDriverCallback ) // CWDriverCallback
                     ) THEN
          Strings.ToW( LocalText1, 0, OUT ErrorString );
          RETURN FALSE;
        END;

      ELSE
        LocalText1[0] := CHAR( 0 );
        LocalText2[0] := CHAR( 0 );

        IF ( ADDRESS( __ReadParameters ) <> NIL ) AND
           NOT __ReadParameters( PObjectData,
                                 LocalPath,
                                 LocalText1,
                                 ErrorLine,
                                 ErrorColumn,
                                 LocalText2 ) THEN
          Strings.ToW( LocalText1, 0, OUT ErrorString );
          Strings.ToW( LocalText2, 0, OUT HintOrHelp );
          RETURN FALSE;
        END;

      END; // IF Init3

      RETURN TRUE;
    END ReadParametersA;

  (*----------*)

    PROCEDURE ReadParametersW( VAR ErrorString : ARRAY OF WCHAR ) : BOOLEAN;
    VAR
      LocalPath : FIO.PathStrW;
      LocalText1 : ARRAY [0..255] OF WCHAR;
      LocalText2 : ARRAY [0..255] OF WCHAR;
    BEGIN;
      ASSIGN( LocalPath, ParFilePath );

      IF ADDRESS( __Init3W ) = NIL THEN // __Init will be called
        ASSIGN( LocalText1, DriverAppName );

        IF NOT __InitW( PObjectData,                        // PData
                        LocalPath,                          // ParamFileName
                        LocalText1,                         // SymbolicDriverName/InitMessage
                        0,                                  // Level
                        DriverRunMode = drv_def.drmRun,     // RunFlag
                        ADR( SELF ),                        // PDriver
                        TDriverCallback( CWDriverCallback ) // CWDriverCallback
                      ) THEN
          ASSIGN( ErrorString, LocalText1 );
          RETURN FALSE;
        END;

      ELSE
        LocalText1[0] := WCHAR( 0 );
        LocalText2[0] := WCHAR( 0 );

        IF ( ADDRESS( __ReadParametersW ) <> NIL ) AND
           NOT __ReadParametersW( PObjectData,
                                  LocalPath,
                                  LocalText1,
                                  ErrorLine,
                                  ErrorColumn,
                                  LocalText2 ) THEN
          ASSIGN( ErrorString, LocalText1 );
          ASSIGN( HintOrHelp, LocalText2 );
          RETURN FALSE;
        END;

      END; // IF Init3W

      RETURN TRUE;
    END ReadParametersW;

  (*----------*)

  VAR
    uf : BOOLEAN;
  BEGIN
    ASSIGN( ParFilePath, _ParFilePath );
    // fall back safety
    ErrorLine := 0;
    ErrorColumn := 0;
    HintOrHelp[0] := 0W;
    ComponentHelper.IsUNICODE( uf );
    IF uf THEN
      IF NOT ReadParametersW( ErrorString ) THEN
        RETURN FALSE;
      END;
    ELSE
      IF NOT ReadParametersA( ErrorString ) THEN
        RETURN FALSE;
      END;
    END;
    RETURN TRUE;
  END ReadParameters;

(*----------------------------------------------------------------------------*)
 
  PUBLIC VIRTUAL PROCEDURE QueryErrorCode( ErrorCode : CARDINAL; VAR ErrorText : ARRAY OF WCHAR ) : BOOLEAN;
  VAR
    ErrorTextA : ARRAY [0..255] OF CHAR;
    ErrorTextW : ARRAY [0..255] OF WCHAR;
    b : BOOLEAN;
  BEGIN
    b := FALSE;
    IF ADDRESS( __QueryErrorCodeW ) <> NIL THEN
      IF __QueryErrorCodeW( PObjectData, ErrorCode, ErrorTextW ) THEN
        b := TRUE;
        ASSIGN( ErrorText, ErrorTextW );
      END;
    ELSIF ADDRESS( __QueryErrorCode ) <> NIL THEN
      IF __QueryErrorCode( PObjectData, ErrorCode, ErrorTextA ) THEN
        b := TRUE;
        Strings.ToW( ErrorTextA, 0, OUT ErrorText );
      END;
    END;
    RETURN b;
  END QueryErrorCode;

(*----------------------------------------------------------------------------*)
 
  PUBLIC VIRTUAL PROCEDURE AbleToEnumerateChannels( ForceInit3 : BOOLEAN ) : BOOLEAN;
  BEGIN
    IF ( ADDRESS( __EnumerateChannels ) = NIL ) AND ( ADDRESS( __EnumerateChannelsW ) = NIL ) THEN
      RETURN FALSE;
    ELSIF NOT ForceInit3 THEN
      RETURN TRUE;
    END;
    RETURN ( ADDRESS( __Init3 ) <> NIL ) OR ( ADDRESS( __Init3W ) <> NIL );
  END AbleToEnumerateChannels;

(*----------------------------------------------------------------------------*)
 
  PUBLIC VIRTUAL PROCEDURE EnumerateChannels( VAR EnumerateState : LONGWORD; VAR Type : CARDINAL; VAR Direction : drv_def.TDirection; VAR DriverIndex, Count : CARDINAL; VAR HaveDescription : BOOLEAN ) : BOOLEAN;
  VAR
    dir : CARDINAL;
    b : BOOLEAN;
  BEGIN
    IF ADDRESS( __EnumerateChannelsW ) <> NIL THEN
      b := __EnumerateChannelsW( PObjectData, EnumerateState, Type, dir, DriverIndex, Count, HaveDescription );
    ELSIF ADDRESS( __EnumerateChannels ) <> NIL THEN
      b := __EnumerateChannels( PObjectData, EnumerateState, Type, dir, DriverIndex, Count, HaveDescription );
    ELSE
      b := FALSE;
    END;
    IF b THEN
      Direction := drv_def.TDirection( dir );
    END;
    RETURN b;
  END EnumerateChannels;

(*----------------------------------------------------------------------------*)
 
  PUBLIC VIRTUAL PROCEDURE InputParameters( DriverIndex : CARDINAL; Active : BOOLEAN );
  BEGIN
    IF ADDRESS( __InputParametersW ) <> NIL THEN
      __InputParametersW( PObjectData, DriverIndex, Active );
    ELSIF ADDRESS( __EnumerateChannels ) <> NIL THEN
      __InputParameters( PObjectData, DriverIndex, Active );
    END;
  END InputParameters;

(*----------------------------------------------------------------------------*)
 
  PUBLIC VIRTUAL PROCEDURE GetChannelDescription( DriverIndex : CARDINAL; VAR Description, Id : ARRAY OF WCHAR ) : BOOLEAN;
  VAR
    DescriptionA : ARRAY [0..255] OF CHAR;
    DescriptionW : ARRAY [0..255] OF WCHAR;
    IdA : ARRAY [0..63] OF CHAR;
    IdW : ARRAY [0..63] OF WCHAR;
    b : BOOLEAN;
  BEGIN
    b := FALSE;
    IF ADDRESS( __GetChannelDescriptionW ) <> NIL THEN
      IdW[0] := WCHAR( 0 );
      IF __GetChannelDescriptionW( PObjectData, DriverIndex, DescriptionW, IdW ) THEN
        b := TRUE;
        ASSIGN( Description, DescriptionW );
        ASSIGN( Id, IdW );
      END;
    ELSIF ADDRESS( __GetChannelDescription ) <> NIL THEN
      IdA[0] := CHAR( 0 );
      IF __GetChannelDescription( PObjectData, DriverIndex, DescriptionA, IdA ) THEN
        b := TRUE;
        Strings.ToW( DescriptionA, 0, OUT Description );
        Strings.ToW( IdA, 0, OUT Id );
      END;
    END;
    RETURN b;
  END GetChannelDescription;

(*----------------------------------------------------------------------------*)
 
  PUBLIC VIRTUAL PROCEDURE Run();
  BEGIN
    IF ADDRESS( __RunW ) <> NIL THEN
      __RunW( PObjectData );
    ELSIF ADDRESS( __Run ) <> NIL THEN
      __Run( PObjectData );
    END;
  END Run;

(*----------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE Stop();
  BEGIN
    IF ADDRESS( __StopW ) <> NIL THEN
      __StopW( PObjectData );
    ELSIF ADDRESS( __Stop ) <> NIL THEN
      __Stop( PObjectData );
    END;
  END Stop;

(*----------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE Done();
  BEGIN
    IF DLLHandle <> NIL THEN
      IF ( ADDRESS( __DoneW ) <> NIL ) AND ( PObjectData <> NIL ) THEN
        __DoneW( PObjectData );
      ELSIF ( ADDRESS( __Done ) <> NIL ) AND ( PObjectData <> NIL ) THEN
        __Done( PObjectData );
      END;
    END;

    IF ( ADDRESS( __DisposeDriverW ) <> NIL ) AND ( PObjectData <> NIL ) THEN
      __DisposeDriverW( PObjectData );
    ELSIF ( ADDRESS( __DisposeDriver ) <> NIL ) AND ( PObjectData <> NIL ) THEN
      __DisposeDriver( PObjectData );
    END;

    IF PBufferA <> NIL THEN
      DISPOSE( PBufferA );
    END;
    IF PBufferW <> NIL THEN
      DISPOSE( PBufferW );
    END;
  END Done;

(*----------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE InputRequestStart();
  BEGIN
    IF ADDRESS( __InputRequestStartW ) <> NIL THEN
      __InputRequestStartW( PObjectData );
    ELSIF ADDRESS( __InputRequestStart ) <> NIL THEN
      __InputRequestStart( PObjectData );
    END;
  END InputRequestStart;

(*----------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE InputRequest( ChannelNumber : CARDINAL );
  BEGIN
    IF ADDRESS( __InputRequestW ) <> NIL THEN
      __InputRequestW( PObjectData, ChannelNumber );
    ELSIF ADDRESS( __InputRequest ) <> NIL THEN
      __InputRequest( PObjectData, ChannelNumber );
    END;
  END InputRequest;

(*----------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE InputRequestCompleted();
  BEGIN
    IF ADDRESS( __InputRequestCompletedW ) <> NIL THEN
      __InputRequestCompletedW( PObjectData );
    ELSIF ADDRESS( __InputRequestCompleted ) <> NIL THEN
      __InputRequestCompleted( PObjectData );
    END;
  END InputRequestCompleted;

(*----------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE InputFinalized( ChannelNumber : CARDINAL; 
                                           VAR ErrorCode : CARDINAL ) : BOOLEAN;
  VAR
    ok : BOOLEAN;
  BEGIN
    IF ADDRESS( __InputFinalizedW ) <> NIL THEN
      ok := __InputFinalizedW( PObjectData, ChannelNumber, ErrorCode );
      RETURN ok;
    ELSIF ADDRESS( __InputFinalized ) <> NIL THEN
      ok := __InputFinalized( PObjectData, ChannelNumber, ErrorCode );
      RETURN ok;
    ELSE
      ErrorCode := drv_def.ecDriverBadInputFinalizedRoutine;
      RETURN FALSE;
    END;
  END InputFinalized;

(*----------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE InputOOBDataQuery( VAR QueryEnumerateState : LONGWORD; VAR ChannelNumber : CARDINAL ) : BOOLEAN;
  BEGIN
    IF ADDRESS( __InputOOBDataQueryW ) <> NIL THEN
      RETURN __InputOOBDataQueryW( PObjectData, QueryEnumerateState, ChannelNumber );
    ELSIF ADDRESS( __InputRequest ) <> NIL THEN
      RETURN __InputOOBDataQuery( PObjectData, QueryEnumerateState, ChannelNumber );
    END;
    RETURN FALSE;
  END InputOOBDataQuery;

(*----------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE GetInput( VAR ErrorCode : CARDINAL;
                                     ChannelNumber : CARDINAL; 
                                     VAR ChannelValue : drv_def.TValue; 
                                     VAR QOS : CARDINAL; 
                                     VAR TimeStamp : drv_def.TUTCStamp ) : BOOLEAN;

  (*---------*)
   
    PROCEDURE GetString3W() : BOOLEAN;
    LABEL
      GoAgain;
    VAR
      BL         : CARDINAL;
      LocalValue : drv_def.TValue;
      PB         : ADDRESS;
      PBuffer    : drv_str.TPDStringW;
      FirstPass  : BOOLEAN;
      FreeFlag   : BOOLEAN;
    BEGIN
      drv_str.GetDStrAddrLenW( PBufferW, PB, BL );
      LocalValue.Type := drv_def.vtDriverString;

      FirstPass := TRUE;
    GoAgain:
      BL := PBufferW^.Size;
      LocalValue.ValDriverStringCharLength := BL;
      LocalValue.ValDriverStringAddress := PB;

      __GetInput3W( PObjectData, ChannelNumber, LocalValue, QOS, TimeStamp, ErrorCode );
      IF ErrorCode <> drv_def.ecSuccess THEN
        RETURN FALSE;
      END;
      IF LocalValue.ValDriverStringAddress = NIL THEN
        // driver requests more data
        IF NOT FirstPass THEN
          ErrorCode := drv_def.ecDriverSecondRequestForAllocation;
          RETURN FALSE;
        ELSIF ( LocalValue.ValDriverStringCharLength <= BL ) THEN // error, driver cannot requested less than is allocated
          ErrorCode := drv_def.ecDriverRequestForLessMemory;
          RETURN FALSE;
        ELSE
          FirstPass := FALSE;
          drv_str.EnsureDStrLenW( PBufferW, ( LocalValue.ValDriverStringCharLength + 31 ) >> 5 << 5, PB, BL );
          GOTO GoAgain;
        END;
      ELSIF LocalValue.ValDriverStringAddress <> PB THEN
        ErrorCode := drv_def.ecDriverOverwrittenString;
        RETURN FALSE;
      END;

      PBufferW^.Len := LocalValue.ValDriverStringCharLength;
      PBuffer := NIL;
      FreeFlag := drv_str.CreateTFromU( PBuffer, PBufferW );
      IF FreeFlag THEN
        drv_def.SetValueDString( ChannelValue, PBuffer );
        DISPOSE( PBuffer );
      ELSE
        drv_def.SetValueDString( ChannelValue, PBuffer );
      END;

      RETURN TRUE;
    END GetString3W;

  (*---------*)
   
    PROCEDURE GetString2W() : BOOLEAN;
    VAR
      BL         : CARDINAL;
      LocalValue : drv_def.TValue;
      PBuffer    : drv_str.TPDStringW;
      PB         : ADDRESS;
      FreeFlag   : BOOLEAN;
    BEGIN
      drv_str.GetDStrAddrLenW( PBufferW, PB, BL );
      LocalValue.Type := drv_def.vtPString256;
      LocalValue.ValPString256W := PB;

      __GetInput2W( PObjectData, ChannelNumber, LocalValue, QOS, TimeStamp );
      IF LocalValue.ValPString256W <> PB THEN
        ErrorCode := drv_def.ecDriverOverwrittenString;
        RETURN FALSE;
      END;

      PBufferW^.Len := LENGTH( OA( 255, LocalValue.ValPString256W ) );
      PBuffer := NIL;
      FreeFlag := drv_str.CreateTFromU( PBuffer, PBufferW );
      IF FreeFlag THEN
        drv_def.SetValueDString( ChannelValue, PBuffer );
        DISPOSE( PBuffer );
      ELSE
        drv_def.SetValueDString( ChannelValue, PBuffer );
      END;

      RETURN TRUE;
    END GetString2W;

  (*---------*)

    PROCEDURE GetString1W() : BOOLEAN;
    VAR
      BL         : CARDINAL;
      LocalValue : drv_def.TValue;
      PBuffer    : drv_str.TPDStringW;
      PB         : ADDRESS;
      FreeFlag   : BOOLEAN;
    BEGIN
      drv_str.GetDStrAddrLenW( PBufferW, PB, BL );
      LocalValue.Type := drv_def.vtPString256;
      LocalValue.ValPString256W := PB;

      __GetInput1W( PObjectData, ChannelNumber, LocalValue );
      IF LocalValue.ValPString256W <> PB THEN
        ErrorCode := drv_def.ecDriverOverwrittenString;
        RETURN FALSE;
      END;

      PBufferW^.Len := LENGTH( OA( 255, LocalValue.ValPString256W ));
      PBuffer := NIL;
      FreeFlag := drv_str.CreateTFromU( PBuffer, PBufferW );
      IF FreeFlag THEN
        drv_def.SetValueDString( ChannelValue, PBuffer );
        DISPOSE( PBuffer );
      ELSE
        drv_def.SetValueDString( ChannelValue, PBuffer );
      END;

      RETURN TRUE;
    END GetString1W;

  (*---------*)

    PROCEDURE GetString3() : BOOLEAN;
    LABEL
      GoAgain;
    VAR
      BL         : CARDINAL;
      LocalValue : drv_def.TValue;
      PB         : ADDRESS;
      PBuffer    : drv_str.TPDStringW;
      FirstPass  : BOOLEAN;
      FreeFlag   : BOOLEAN;
    BEGIN
      drv_str.GetDStrAddrLenA( PBufferA, PB, BL ); BL := PBufferA^.Size;
      LocalValue.Type := drv_def.vtDriverString;

      FirstPass := TRUE;
    GoAgain:
      BL := PBufferA^.Size;
      LocalValue.ValDriverStringCharLength := BL;
      LocalValue.ValDriverStringAddress := PB;

      __GetInput3( PObjectData, ChannelNumber, LocalValue, QOS, TimeStamp, ErrorCode );
      IF ErrorCode <> drv_def.ecSuccess THEN
        RETURN FALSE;
      END;
      IF LocalValue.ValDriverStringAddress = NIL THEN
        // driver requests more data
        IF NOT FirstPass THEN
          ErrorCode := drv_def.ecDriverSecondRequestForAllocation;
          RETURN FALSE;
        ELSIF ( LocalValue.ValDriverStringCharLength <= BL ) THEN // error, driver cannot requested less than is allocated
          ErrorCode := drv_def.ecDriverRequestForLessMemory;
          RETURN FALSE;
        ELSE
          FirstPass := FALSE;
          drv_str.EnsureDStrLenA( PBufferA, ( LocalValue.ValDriverStringCharLength + 31 ) >> 5 << 5, PB, BL );
          GOTO GoAgain;
        END;
      ELSIF LocalValue.ValDriverStringAddress <> PB THEN
        ErrorCode := drv_def.ecDriverOverwrittenString;
        RETURN FALSE;
      END;

      PBufferA^.Len := LocalValue.ValDriverStringCharLength;
      PBuffer := NIL;
      FreeFlag := drv_str.CreateTFromA( PBuffer, PBufferA );
      IF FreeFlag THEN
        drv_def.SetValueDString( ChannelValue, PBuffer );
        DISPOSE( PBuffer );
      ELSE
        drv_def.SetValueDString( ChannelValue, PBuffer );
      END;

      RETURN TRUE;
    END GetString3;

  (*---------*)
   
    PROCEDURE GetString2() : BOOLEAN;
    VAR
      BL         : CARDINAL;
      LocalValue : drv_def.TValue;
      PBuffer    : drv_str.TPDStringW;
      PB         : ADDRESS;
      FreeFlag   : BOOLEAN;
    BEGIN
      drv_str.GetDStrAddrLenA( PBufferA, PB, BL );
      LocalValue.Type := drv_def.vtPString256;
      LocalValue.ValPString256A := PB;

      __GetInput2( PObjectData, ChannelNumber, LocalValue, QOS, TimeStamp );
      IF LocalValue.ValPString256A <> PB THEN
        ErrorCode := drv_def.ecDriverOverwrittenString;
        RETURN FALSE;
      END;

      PBufferA^.Len := LENGTH( OA( 255, LocalValue.ValPString256A ) );
      PBuffer := NIL;
      FreeFlag := drv_str.CreateTFromA( PBuffer, PBufferA );
      IF FreeFlag THEN
        drv_def.SetValueDString( ChannelValue, PBuffer );
        DISPOSE( PBuffer );
      ELSE
        drv_def.SetValueDString( ChannelValue, PBuffer );
      END;

      RETURN TRUE;
    END GetString2;

  (*---------*)

    PROCEDURE GetString1() : BOOLEAN;
    VAR
      BL         : CARDINAL;
      LocalValue : drv_def.TValue;
      PBuffer    : drv_str.TPDStringW;
      PB         : ADDRESS;
      FreeFlag   : BOOLEAN;
    BEGIN
      drv_str.GetDStrAddrLenA( PBufferA, PB, BL );
      LocalValue.Type := drv_def.vtPString256;
      LocalValue.ValPString256A := PB;

      __GetInput1( PObjectData, ChannelNumber, LocalValue );
      IF LocalValue.ValPString256A <> PB THEN
        ErrorCode := drv_def.ecDriverOverwrittenString;
        RETURN FALSE;
      END;

      PBufferA^.Len := LENGTH( OA( 255, LocalValue.ValPString256A ) );
      PBuffer := NIL;
      FreeFlag := drv_str.CreateTFromA( PBuffer, PBufferA );
      IF FreeFlag THEN
        drv_def.SetValueDString( ChannelValue, PBuffer );
        DISPOSE( PBuffer );
      ELSE
        drv_def.SetValueDString( ChannelValue, PBuffer );
      END;

      RETURN TRUE;
    END GetString1;

  (*---------*)

    PROCEDURE GetBuffer3W() : BOOLEAN;
    VAR
      PBuffer : ADDRESS;
    BEGIN
      PBuffer := ChannelValue.PBuffer;
      __GetInput3W( PObjectData, ChannelNumber, ChannelValue, QOS, TimeStamp, ErrorCode );
      IF ChannelValue.PBuffer <> PBuffer THEN
        ErrorCode := drv_def.ecDriverOverwrittenBuffer;
        RETURN FALSE;
      END;
      RETURN TRUE;
    END GetBuffer3W;

  (*---------*)

    PROCEDURE GetBuffer2W() : BOOLEAN;
    VAR
      PBuffer : ADDRESS;
    BEGIN
      PBuffer := ChannelValue.PBuffer;
      __GetInput2W( PObjectData, ChannelNumber, ChannelValue, QOS, TimeStamp );
      IF ChannelValue.PBuffer <> PBuffer THEN
        ErrorCode := drv_def.ecDriverOverwrittenBuffer;
        RETURN FALSE;
      END;
      RETURN TRUE;
    END GetBuffer2W;

  (*---------*)

    PROCEDURE GetBuffer1W() : BOOLEAN;
    VAR
      PBuffer : ADDRESS;
    BEGIN
      PBuffer := ChannelValue.PBuffer;
      __GetInput1W( PObjectData, ChannelNumber, ChannelValue );
      IF ChannelValue.PBuffer <> PBuffer THEN
        ErrorCode := drv_def.ecDriverOverwrittenBuffer;
        RETURN FALSE;
      END;
      RETURN TRUE;
    END GetBuffer1W;

  (*---------*)

    PROCEDURE GetBuffer3() : BOOLEAN;
    VAR
      PBuffer : ADDRESS;
    BEGIN
      PBuffer := ChannelValue.PBuffer;
      __GetInput3( PObjectData, ChannelNumber, ChannelValue, QOS, TimeStamp, ErrorCode );
      IF ChannelValue.PBuffer <> PBuffer THEN
        ErrorCode := drv_def.ecDriverOverwrittenBuffer;
        RETURN FALSE;
      END;
      RETURN TRUE;
    END GetBuffer3;

  (*---------*)

    PROCEDURE GetBuffer2() : BOOLEAN;
    VAR
      PBuffer : ADDRESS;
    BEGIN
      PBuffer := ChannelValue.PBuffer;
      __GetInput2( PObjectData, ChannelNumber, ChannelValue, QOS, TimeStamp );
      IF ChannelValue.PBuffer <> PBuffer THEN
        ErrorCode := drv_def.ecDriverOverwrittenBuffer;
        RETURN FALSE;
      END;
      RETURN TRUE;
    END GetBuffer2;

  (*---------*)

    PROCEDURE GetBuffer1() : BOOLEAN;
    VAR
      PBuffer : ADDRESS;
    BEGIN
      PBuffer := ChannelValue.PBuffer;
      __GetInput1( PObjectData, ChannelNumber, ChannelValue );
      IF ChannelValue.PBuffer <> PBuffer THEN
        ErrorCode := drv_def.ecDriverOverwrittenBuffer;
        RETURN FALSE;
      END;
      RETURN TRUE;
    END GetBuffer1;

  (*---------*)

  LABEL
    Fail;
  BEGIN
    ErrorCode := drv_def.ecSuccess;

    IF ADDRESS( __GetInput3W ) <> NIL THEN
      CASE ChannelValue.Type OF
      | drv_def.vtBuffer :
        IF NOT GetBuffer3W() THEN GOTO Fail; END;
      | drv_def.vtDString :
        IF NOT GetString3W() THEN GOTO Fail; END;
      ELSE
        __GetInput3W( PObjectData, ChannelNumber, ChannelValue, QOS, TimeStamp, ErrorCode );
      END;
    ELSIF ADDRESS( __GetInput2W ) <> NIL THEN
      CASE ChannelValue.Type OF
      | drv_def.vtBuffer :
        IF NOT GetBuffer2W() THEN GOTO Fail; END;
      | drv_def.vtDString :
        IF NOT GetString2W() THEN GOTO Fail; END;
      ELSE
        __GetInput2W( PObjectData, ChannelNumber, ChannelValue, QOS, TimeStamp );
      END;
    ELSIF ADDRESS( __GetInput1W ) <> NIL THEN
      CASE ChannelValue.Type OF
      | drv_def.vtBuffer :
        IF NOT GetBuffer1W() THEN GOTO Fail; END;
      | drv_def.vtDString :
        IF NOT GetString1W() THEN GOTO Fail; END;
      ELSE
        QOS := drv_def.qosGood;
        __GetInput1W( PObjectData, ChannelNumber, ChannelValue );
      END;
    ELSIF ADDRESS( __GetInput3 ) <> NIL THEN
      CASE ChannelValue.Type OF
      | drv_def.vtBuffer :
        IF NOT GetBuffer3() THEN GOTO Fail; END;
      | drv_def.vtDString :
        IF NOT GetString3() THEN GOTO Fail; END;
      ELSE
        __GetInput3( PObjectData, ChannelNumber, ChannelValue, QOS, TimeStamp, ErrorCode );
      END;
    ELSIF ADDRESS( __GetInput2 ) <> NIL THEN
      CASE ChannelValue.Type OF
      | drv_def.vtBuffer :
        IF NOT GetBuffer2() THEN GOTO Fail; END;
      | drv_def.vtDString :
        IF NOT GetString2() THEN GOTO Fail; END;
      ELSE
        __GetInput2( PObjectData, ChannelNumber, ChannelValue, QOS, TimeStamp );
      END;
    ELSIF ADDRESS( __GetInput1 ) <> NIL THEN
      CASE ChannelValue.Type OF
      | drv_def.vtBuffer :
        IF NOT GetBuffer1() THEN GOTO Fail; END;
      | drv_def.vtDString :
        IF NOT GetString1() THEN GOTO Fail; END;
      ELSE
        QOS := drv_def.qosGood;
        __GetInput1( PObjectData, ChannelNumber, ChannelValue );
      END;
    ELSE
      ErrorCode := drv_def.ecDriverBadInputRoutine;
Fail:
      Storage.Fill( ADR( ChannelValue ), SIZE( drv_def.TValue ), 0 );
      RETURN FALSE;
    END;

    RETURN ErrorCode = drv_def.ecSuccess;
  END GetInput;

(*----------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE OutputRequestStart();
  BEGIN
    IF ADDRESS( __OutputRequestStartW ) <> NIL THEN
      __OutputRequestStartW( PObjectData );
    ELSIF ADDRESS( __OutputRequestStart ) <> NIL THEN
      __OutputRequestStart( PObjectData );
    END;
  END OutputRequestStart;

(*----------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE OutputRequest( VAR ErrorCode : CARDINAL; 
                                          ChannelNumber : CARDINAL;  
                                          ChannelValue : drv_def.TValue; 
                                          QOS : CARDINAL; 
                                          VAR TimeStamp : drv_def.TUTCStamp ) : BOOLEAN;

  (*---------*)
   
    PROCEDURE OutputString3W() : BOOLEAN;
    VAR
      a, as      : ADDRESS;
      l          : CARDINAL;
      LocalValue : drv_def.TValue;
      PLBufferW  : drv_str.TPDStringW;
      FreeFlag   : BOOLEAN;
    BEGIN
      PLBufferW := NIL;
      FreeFlag := drv_str.CreateUFromT( PLBufferW, ChannelValue.ValDStringW );
      drv_str.GetDStrAddrLenW( PLBufferW, a, l );

      LocalValue.Type := drv_def.vtDriverString;
      LocalValue.ValDriverStringCharLength := l;
      LocalValue.ValDriverStringAddress := a;
      as := LocalValue.ValDriverStringAddress;

      __OutputRequest3W( PObjectData, ChannelNumber, LocalValue, QOS, TimeStamp );
      IF FreeFlag THEN
        DISPOSE( PLBufferW );
      END;

      IF as = LocalValue.ValDriverStringAddress THEN
        RETURN TRUE;
      ELSE
        ErrorCode := drv_def.ecDriverOverwrittenString;
        RETURN FALSE;
      END;
    END OutputString3W;

  (*---------*)

    PROCEDURE OutputString2W() : BOOLEAN;
    VAR
      as         : ADDRESS;
      LocalValue : drv_def.TValue;
      PLBufferW  : drv_str.TPDStringW;
      s          : ARRAY [0..255] OF WCHAR;
      FreeFlag   : BOOLEAN;
    BEGIN
      PLBufferW := NIL;
      FreeFlag := drv_str.CreateUFromT( PLBufferW, ChannelValue.ValDStringW );
      drv_str.CopyDStrToStrW( s, PLBufferW );

      LocalValue.Type := drv_def.vtPString256;
      LocalValue.ValPString256W := ADR( s );
      as := LocalValue.ValPString256W;

      __OutputRequest2W( PObjectData, ChannelNumber, LocalValue, QOS, TimeStamp );
      IF FreeFlag THEN
        DISPOSE( PLBufferW );
      END;

      IF as = LocalValue.ValPString256W THEN
        RETURN TRUE;
      ELSE
        ErrorCode := drv_def.ecDriverOverwrittenString;
        RETURN FALSE;
      END;
    END OutputString2W;

  (*---------*)

    PROCEDURE OutputString1W() : BOOLEAN;
    VAR
      as         : ADDRESS;
      LocalValue : drv_def.TValue;
      PLBufferW  : drv_str.TPDStringW;
      s          : ARRAY [0..255] OF WCHAR;
      FreeFlag   : BOOLEAN;
    BEGIN
      PLBufferW := NIL;
      FreeFlag := drv_str.CreateUFromT( PLBufferW, ChannelValue.ValDStringW );
      drv_str.CopyDStrToStrW( s, PLBufferW );

      LocalValue.Type := drv_def.vtPString256;
      LocalValue.ValPString256W := ADR( s );
      as := LocalValue.ValPString256W;

      __OutputRequest1W( PObjectData, ChannelNumber, LocalValue );
      IF FreeFlag THEN
        DISPOSE( PLBufferW );
      END;

      IF as = LocalValue.ValPString256W THEN
        RETURN TRUE;
      ELSE
        ErrorCode := drv_def.ecDriverOverwrittenString;
        RETURN FALSE;
      END;
    END OutputString1W;

  (*---------*)

    PROCEDURE OutputString3() : BOOLEAN;
    VAR
      a, as      : ADDRESS;
      l          : CARDINAL;
      LocalValue : drv_def.TValue;
      PLBufferA  : drv_str.TPDStringA;
      FreeFlag   : BOOLEAN;
    BEGIN
      PLBufferA := NIL;
      FreeFlag := drv_str.CreateAFromT( PLBufferA, ChannelValue.ValDStringW );
      drv_str.GetDStrAddrLenA( PLBufferA, a, l );

      LocalValue.Type := drv_def.vtDriverString;
      LocalValue.ValDriverStringCharLength := l;
      LocalValue.ValDriverStringAddress := a;
      as := LocalValue.ValDriverStringAddress;

      __OutputRequest3( PObjectData, ChannelNumber, LocalValue, QOS, TimeStamp );
      IF FreeFlag THEN
        DISPOSE( PLBufferA );
      END;

      IF as = LocalValue.ValDriverStringAddress THEN
        RETURN TRUE;
      ELSE
        ErrorCode := drv_def.ecDriverOverwrittenString;
        RETURN FALSE;
      END;
    END OutputString3;

  (*---------*)

    PROCEDURE OutputString2() : BOOLEAN;
    VAR
      as         : ADDRESS;
      LocalValue : drv_def.TValue;
      PLBufferA  : drv_str.TPDStringA;
      s          : ARRAY [0..255] OF CHAR;
      FreeFlag   : BOOLEAN;
    BEGIN
      PLBufferA := NIL;
      FreeFlag := drv_str.CreateAFromT( PLBufferA, ChannelValue.ValDStringW );
      drv_str.CopyDStrToStrA( s, PLBufferA );

      LocalValue.Type := drv_def.vtPString256;
      LocalValue.ValPString256A := ADR( s );
      as := LocalValue.ValPString256A;

      __OutputRequest2( PObjectData, ChannelNumber, LocalValue, QOS, TimeStamp );
      IF FreeFlag THEN
        DISPOSE( PLBufferA );
      END;

      IF as = LocalValue.ValPString256A THEN
        RETURN TRUE;
      ELSE
        ErrorCode := drv_def.ecDriverOverwrittenString;
        RETURN FALSE;
      END;
    END OutputString2;

  (*---------*)

    PROCEDURE OutputString1() : BOOLEAN;
    VAR
      as         : ADDRESS;
      LocalValue : drv_def.TValue;
      PLBufferA  : drv_str.TPDStringA;
      s          : ARRAY [0..255] OF CHAR;
      FreeFlag   : BOOLEAN;
    BEGIN
      PLBufferA := NIL;
      FreeFlag := drv_str.CreateAFromT( PLBufferA, ChannelValue.ValDStringW );
      drv_str.CopyDStrToStrA( s, PLBufferA );

      LocalValue.Type := drv_def.vtPString256;
      LocalValue.ValPString256A := ADR( s );
      as := LocalValue.ValPString256A;

      __OutputRequest1( PObjectData, ChannelNumber, LocalValue );
      IF FreeFlag THEN
        DISPOSE( PLBufferA );
      END;

      IF as = LocalValue.ValPString256A THEN
        RETURN TRUE;
      ELSE
        ErrorCode := drv_def.ecDriverOverwrittenString;
        RETURN FALSE;
      END;
    END OutputString1;

  (*---------*)

  LABEL
    Fail;
  BEGIN
    IF ADDRESS( __OutputRequest3W ) <> NIL THEN
      IF ChannelValue.Type <> drv_def.vtDString THEN
        __OutputRequest3W( PObjectData, ChannelNumber, ChannelValue, QOS, TimeStamp );
      ELSIF NOT OutputString3W() THEN
        GOTO Fail;
      END;
    ELSIF ADDRESS( __OutputRequest2W ) <> NIL THEN
      IF ChannelValue.Type <> drv_def.vtDString THEN
        __OutputRequest2W( PObjectData, ChannelNumber, ChannelValue, QOS, TimeStamp );
      ELSIF NOT OutputString2W() THEN
        GOTO Fail;
      END;
    ELSIF ADDRESS( __OutputRequest1W ) <> NIL THEN
      IF ChannelValue.Type <> drv_def.vtDString THEN
        __OutputRequest1W( PObjectData, ChannelNumber, ChannelValue );
      ELSIF NOT OutputString1W() THEN
        GOTO Fail;
      END;
    ELSIF ADDRESS( __OutputRequest3 ) <> NIL THEN
      IF ChannelValue.Type <> drv_def.vtDString THEN
        __OutputRequest3( PObjectData, ChannelNumber, ChannelValue, QOS, TimeStamp );
      ELSIF NOT OutputString3() THEN // converts string from UNICODE if needed
        GOTO Fail;
      END;
    ELSIF ADDRESS( __OutputRequest2 ) <> NIL THEN
      IF ChannelValue.Type <> drv_def.vtDString THEN
        __OutputRequest2( PObjectData, ChannelNumber, ChannelValue, QOS, TimeStamp );
      ELSIF NOT OutputString2() THEN // converts string from UNICODE if needed
        GOTO Fail;
      END;
    ELSIF ADDRESS( __OutputRequest1 ) <> NIL THEN
      IF ChannelValue.Type <> drv_def.vtDString THEN
        __OutputRequest1( PObjectData, ChannelNumber, ChannelValue );
      ELSIF NOT OutputString1() THEN // converts string from UNICODE if needed
        GOTO Fail;
      END;
    ELSE
      ErrorCode := drv_def.ecDriverBadOutputRoutine;
Fail:
      RETURN FALSE;
    END;
    RETURN TRUE;
  END OutputRequest;

(*----------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE OutputRequestCompleted();
  BEGIN
    IF ADDRESS( __OutputRequestCompletedW ) <> NIL THEN
      __OutputRequestCompletedW( PObjectData );
    ELSIF ADDRESS( __OutputRequestCompleted ) <> NIL THEN
      __OutputRequestCompleted( PObjectData );
    END;
  END OutputRequestCompleted;

(*----------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE OutputFinalized( ChannelNumber : CARDINAL; 
                                     VAR ErrorCode : CARDINAL ) : BOOLEAN;
  VAR
    ok : BOOLEAN;
  BEGIN
    IF ADDRESS( __OutputFinalizedW ) <> NIL THEN
      ok := __OutputFinalizedW( PObjectData, ChannelNumber, ErrorCode );
      RETURN ok;
    ELSIF ADDRESS( __OutputFinalized ) <> NIL THEN
      ok := __OutputFinalized( PObjectData, ChannelNumber, ErrorCode );
      RETURN ok;
    ELSE
      ErrorCode := drv_def.ecDriverBadOutputFinalizedRoutine;
      RETURN FALSE;
    END;
  END OutputFinalized;

(*----------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE BufferInfo( VAR ErrorCode : CARDINAL;
                                ChannelNumber : CARDINAL;
                                BType : CARD8;
                                BLen : CARDINAL ) : BOOLEAN;
  BEGIN
    ErrorCode := drv_def.ecDriverBufferInfoFailure;
    IF ADDRESS( __BufferInfoW ) <> NIL THEN
      RETURN __BufferInfoW( PObjectData, ChannelNumber, BType, BLen );
    ELSIF ADDRESS( __BufferInfo ) <> NIL THEN
      RETURN __BufferInfo( PObjectData, ChannelNumber, BType, BLen );
    ELSE
      ErrorCode := drv_def.ecDriverMissingBufferInfo;
      RETURN FALSE;
    END;
  END BufferInfo;

(*----------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE SetBufferAddr( VAR ErrorCode : CARDINAL; ChannelNumber : CARDINAL; PBuffer : ADDRESS ) : BOOLEAN;
  BEGIN
    IF ADDRESS( __SetBufferAddrW ) <> NIL THEN
      __SetBufferAddrW( PObjectData, ChannelNumber, PBuffer );
    ELSIF ADDRESS( __SetBufferAddr ) <> NIL THEN
      __SetBufferAddr( PObjectData, ChannelNumber, PBuffer );
    ELSE
      ErrorCode := drv_def.ecDriverMissingSetBufferAddr;
      RETURN FALSE;
    END;
    RETURN TRUE;
  END SetBufferAddr;

(*----------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE DriverProc( Func, Param1, Param2, Param3, Param4 : CARDINAL );
  BEGIN
    IF ADDRESS( __DriverProcW ) <> NIL THEN
      __DriverProcW( PObjectData, Func, Param1, Param2, Param3, Param4 );
    ELSIF ADDRESS( __DriverProc ) <> NIL THEN
      __DriverProc( PObjectData, Func, Param1, Param2, Param3, Param4 );
    END;
  END DriverProc;

(*----------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE QueryProc( VAR ErrorCode : CARDINAL; Param1 : drv_def.TValue; VAR Param2 : drv_def.TValue ) : BOOLEAN;

  (*----------*)

    PROCEDURE QueryProcString3W() : BOOLEAN;
    LABEL
      Fail, GoAgain;
    VAR
      as1, as2       : ADDRESS;
      l              : CARDINAL;
      LocalValue1    : drv_def.TValue;
      LocalValue2    : drv_def.TValue;
      Param2IN       : drv_def.TValue;
      PBuffer        : drv_str.TPDStringW;
      PLBufferW1     : drv_str.TPDStringW;
      PLBufferW2     : drv_str.TPDStringW;
      PLocalValue1   : drv_def.TPValue;
      PLocalValue2IN : drv_def.TPValue;
      PLocalValue2   : drv_def.TPValue;
      FirstPass      : BOOLEAN;
      FreeFlag1      : BOOLEAN;
      FreeFlag2      : BOOLEAN;
      FreeFlag3      : BOOLEAN;
    BEGIN
      ErrorCode := drv_def.ecSuccess;

      IF Param1.Type = drv_def.vtDString THEN
        PLBufferW1 := NIL;
        FreeFlag1 := drv_str.CreateUFromT( PLBufferW1, Param1.ValDStringW );
        drv_str.GetDStrAddrLenW( PLBufferW1, as1, l );
        LocalValue1.Type := drv_def.vtDriverString;
        LocalValue1.ValDriverStringCharLength := l;
        LocalValue1.ValDriverStringAddress := as1;
        PLocalValue1 := ADR( LocalValue1 );
      ELSE
        FreeFlag1 := FALSE;
        PLocalValue1 := ADR( Param1 );
      END;
      IF Param2.Type = drv_def.vtDString THEN
        PLBufferW2 := NIL;
        FreeFlag2 := drv_str.CreateUFromT( PLBufferW2, Param2.ValDStringW );
        drv_str.GetDStrAddrLenW( PLBufferW2, as2, l );
        Param2IN.Type := drv_def.vtDriverString;
        Param2IN.ValDriverStringCharLength := l;
        Param2IN.ValDriverStringAddress := as2;
        PLocalValue2IN := ADR( Param2IN );

        drv_str.GetDStrAddrLenW( PBufferW, as2, l );
        PLocalValue2 := ADR( LocalValue2 );
        LocalValue2.Type := drv_def.vtDriverString;

        FirstPass := TRUE;
      GoAgain:
        l := PBufferW^.Size;
        LocalValue2.ValDriverStringCharLength := l;
        LocalValue2.ValDriverStringAddress := as2;
      ELSE
        FreeFlag2 := FALSE;
        PLocalValue2 := ADR( Param2 );
        PLocalValue2IN := ADR( Param2 );
      END;

      FirstPass := TRUE;
      __QueryProc3W( PObjectData, PLocalValue1^, PLocalValue2IN^, PLocalValue2^ );

      IF ( Param1.Type = drv_def.vtDString ) AND ( as1 <> PLocalValue1^.ValDriverStringAddress ) THEN
        ErrorCode := drv_def.ecDriverOverwrittenString;
      ELSIF Param2.Type = drv_def.vtDString THEN // convert string back
        IF PLocalValue2^.ValDriverStringAddress = NIL THEN
          // driver requests more data
          IF NOT FirstPass THEN
            ErrorCode := drv_def.ecDriverSecondRequestForAllocation;
            GOTO Fail;
          ELSIF ( PLocalValue2^.ValDriverStringCharLength <= l ) THEN // error, driver cannot requested less than is allocated
            ErrorCode := drv_def.ecDriverRequestForLessMemory;
            GOTO Fail;
          ELSE
            FirstPass := FALSE;
            drv_str.EnsureDStrLenW( PBufferW, ( PLocalValue2^.ValDriverStringCharLength + 31 ) >> 5 << 5, as2, l );
            GOTO GoAgain;
          END;
        ELSIF PLocalValue2^.ValDriverStringAddress <> as2 THEN
          ErrorCode := drv_def.ecDriverOverwrittenString;
          RETURN FALSE;
        ELSE // convert string back
          PBufferW^.Len := PLocalValue2^.ValDriverStringCharLength;
          PBuffer := NIL;
          FreeFlag3 := drv_str.CreateTFromU( PBuffer, PBufferW );
          IF FreeFlag3 THEN
            drv_def.SetValueDString( Param2, PBuffer );
            IF PBuffer <> NIL THEN
              DISPOSE( PBuffer );
            END;
          ELSE
            drv_def.SetValueDString( Param2, PBuffer );
          END;
        END;
      END;

    Fail:
      IF FreeFlag1 AND ( PLBufferW1 <> NIL ) THEN
        DISPOSE( PLBufferW1 );
      END;
      IF FreeFlag2 AND ( PLBufferW2 <> NIL ) THEN
        DISPOSE( PLBufferW2 );
      END;

      RETURN ErrorCode = drv_def.ecSuccess;
    END QueryProcString3W;

  (*----------*)

    PROCEDURE QueryProcString1W() : BOOLEAN;
    VAR
      as1, as2     : ADDRESS;
      LocalValue1  : drv_def.TValue;
      LocalValue2  : drv_def.TValue;
      PBuffer      : drv_str.TPDStringW;
      PLBufferW1   : drv_str.TPDStringW;
      PLBufferW2   : drv_str.TPDStringW;
      PLocalValue1 : drv_def.TPValue;
      PLocalValue2 : drv_def.TPValue;
      s1           : ARRAY [0..255] OF WCHAR;
      s2           : ARRAY [0..255] OF WCHAR;
      b            : BOOLEAN;
      FreeFlag1    : BOOLEAN;
      FreeFlag2    : BOOLEAN;
    BEGIN
      ErrorCode := drv_def.ecSuccess;

      IF Param1.Type = drv_def.vtDString THEN
        PLBufferW1 := NIL;
        FreeFlag1 := drv_str.CreateUFromT( PLBufferW1, Param1.ValDStringW );
        drv_str.CopyDStrToStrW( s1, PLBufferW1 );
        LocalValue1.Type := drv_def.vtPString256;
        LocalValue1.ValPString256W := ADR( s1 );
        as1 := LocalValue1.ValPString256W;
        PLocalValue1 := ADR( LocalValue1 );
      ELSE
        FreeFlag1 := FALSE;
        PLocalValue1 := ADR( Param1 );
      END;
      IF Param2.Type = drv_def.vtDString THEN
        PLBufferW2 := NIL;
        FreeFlag2 := ( Param2.ValDStringW = NIL ) OR drv_str.CreateUFromT( PLBufferW2, Param2.ValDStringW );
        drv_str.CopyDStrToStrW( s2, PLBufferW2 );
        LocalValue2.Type := drv_def.vtPString256;
        LocalValue2.ValPString256W := ADR( s2 );
        as2 := LocalValue2.ValPString256W;
        PLocalValue2 := ADR( LocalValue2 );
      ELSE
        FreeFlag2 := FALSE;
        PLocalValue2 := ADR( Param2 );
      END;

      __QueryProc1W( PObjectData, PLocalValue1^, PLocalValue2^ );

      IF ( Param1.Type = drv_def.vtDString ) AND ( as1 <> PLocalValue1^.ValPString256W ) THEN
        ErrorCode := drv_def.ecDriverOverwrittenString;
      ELSIF Param2.Type = drv_def.vtDString THEN 
        IF as2 <> PLocalValue2^.ValPString256W THEN
          ErrorCode := drv_def.ecDriverOverwrittenString;
        ELSE
          // convert string back
          drv_str.CopyStrToDStrW( PLBufferW2, s2 );
          IF FreeFlag2 THEN // PLBufferA2 is newly allocated, so environment is ANSI
            PBuffer := NIL;
            b := drv_str.CreateTFromU( PBuffer, PLBufferW2 );
            drv_def.SetValueDString( Param2, PBuffer );
            IF b AND ( PBuffer <> NIL ) THEN
              DISPOSE( PBuffer );
            END;
          ELSE // PLBufferW2 is Param2.ValDString, so it need not be SetValueDString back in Param2.
               // But PLBufferW2 can be modified from CopyStrToDStrA, thus is MUST be
               // into Param2 ASSIGNED.
            // drv_def.SetValueDString( Param2, PBuffer );
            Param2.ValDStringW := drv_str.TPDStringW( PLBufferW2 );
          END;
        END;
      END;

      IF FreeFlag1 AND ( PLBufferW1 <> NIL ) THEN
        DISPOSE( PLBufferW1 );
      END;
      IF FreeFlag2 AND ( PLBufferW2 <> NIL ) THEN
        DISPOSE( PLBufferW2 );
      END;

      RETURN ErrorCode = drv_def.ecSuccess;
    END QueryProcString1W;

  (*----------*)

    PROCEDURE QueryProcString3() : BOOLEAN;
    LABEL
      Fail, GoAgain;
    VAR
      as1, as2       : ADDRESS;
      l              : CARDINAL;
      LocalValue1    : drv_def.TValue;
      LocalValue2    : drv_def.TValue;
      Param2IN       : drv_def.TValue;
      PBuffer        : drv_str.TPDStringW;
      PLBufferA1     : drv_str.TPDStringA;
      PLBufferA2     : drv_str.TPDStringA;
      PLocalValue1   : drv_def.TPValue;
      PLocalValue2IN : drv_def.TPValue;
      PLocalValue2   : drv_def.TPValue;
      FirstPass      : BOOLEAN;
      FreeFlag1      : BOOLEAN;
      FreeFlag2      : BOOLEAN;
      FreeFlag3      : BOOLEAN;
    BEGIN
      ErrorCode := drv_def.ecSuccess;

      IF Param1.Type = drv_def.vtDString THEN
        PLBufferA1 := NIL;
        FreeFlag1 := drv_str.CreateAFromT( PLBufferA1, Param1.ValDStringW );
        drv_str.GetDStrAddrLenA( PLBufferA1, as1, l );;
        LocalValue1.Type := drv_def.vtDriverString;
        LocalValue1.ValDriverStringCharLength := l;
        LocalValue1.ValDriverStringAddress := as1;
        PLocalValue1 := ADR( LocalValue1 );
      ELSE
        FreeFlag1 := FALSE;
        PLocalValue1 := ADR( Param1 );
      END;
      IF Param2.Type = drv_def.vtDString THEN
        PLBufferA2 := NIL;
        FreeFlag2 := drv_str.CreateAFromT( PLBufferA2, Param2.ValDStringW );
        drv_str.GetDStrAddrLenA( PLBufferA2, as2, l );
        Param2IN.Type := drv_def.vtDriverString;
        Param2IN.ValDriverStringCharLength := l;
        Param2IN.ValDriverStringAddress := as2;
        PLocalValue2IN := ADR( Param2IN );

        drv_str.GetDStrAddrLenA( PBufferA, as2, l );
        PLocalValue2 := ADR( LocalValue2 );
        LocalValue2.Type := drv_def.vtDriverString;

        FirstPass := TRUE;
      GoAgain:
        l := PBufferA^.Size;
        LocalValue2.ValDriverStringCharLength := l;
        LocalValue2.ValDriverStringAddress := as2;
      ELSE
        FreeFlag2 := FALSE;
        PLocalValue2 := ADR( Param2 );
        PLocalValue2IN := ADR( Param2 );
      END;

      FirstPass := TRUE;
      __QueryProc3( PObjectData, PLocalValue1^, PLocalValue2IN^, PLocalValue2^ );

      IF ( Param1.Type = drv_def.vtDString ) AND ( as1 <> PLocalValue1^.ValDriverStringAddress ) THEN
        ErrorCode := drv_def.ecDriverOverwrittenString;
      ELSIF Param2.Type = drv_def.vtDString THEN // convert string back
        IF PLocalValue2^.ValDriverStringAddress = NIL THEN
          // driver requests more data
          IF NOT FirstPass THEN
            ErrorCode := drv_def.ecDriverSecondRequestForAllocation;
            GOTO Fail;
          ELSIF ( PLocalValue2^.ValDriverStringCharLength <= l ) THEN // error, driver cannot requested less than is allocated
            ErrorCode := drv_def.ecDriverRequestForLessMemory;
            GOTO Fail;
          ELSE
            FirstPass := FALSE;
            drv_str.EnsureDStrLenA( PBufferA, ( PLocalValue2^.ValDriverStringCharLength + 31 ) >> 5 << 5, as2, l );
            GOTO GoAgain;
          END;
        ELSIF PLocalValue2^.ValDriverStringAddress <> as2 THEN
          ErrorCode := drv_def.ecDriverOverwrittenString;
          RETURN FALSE;
        ELSE // convert string back
          PBufferA^.Len := PLocalValue2^.ValDriverStringCharLength;
          PBuffer := NIL;
          FreeFlag3 := drv_str.CreateTFromA( PBuffer, PBufferA );
          IF FreeFlag3 THEN
            drv_def.SetValueDString( Param2, PBuffer );
            IF PBuffer <> NIL THEN
              DISPOSE( PBuffer );
            END;
          ELSE
            drv_def.SetValueDString( Param2, PBuffer );
          END;
        END;
      END;

    Fail:
      IF FreeFlag1 AND ( PLBufferA1 <> NIL ) THEN
        DISPOSE( PLBufferA1 );
      END;
      IF FreeFlag2 AND ( PLBufferA2 <> NIL ) THEN
        DISPOSE( PLBufferA2 );
      END;

      RETURN ErrorCode = drv_def.ecSuccess;
    END QueryProcString3;

  (*----------*)

    PROCEDURE QueryProcString1() : BOOLEAN;
    VAR
      as1, as2     : ADDRESS;
      LocalValue1  : drv_def.TValue;
      LocalValue2  : drv_def.TValue;
      PBuffer      : drv_str.TPDStringW;
      PLBufferA1   : drv_str.TPDStringA;
      PLBufferA2   : drv_str.TPDStringA;
      PLocalValue1 : drv_def.TPValue;
      PLocalValue2 : drv_def.TPValue;
      s1           : ARRAY [0..255] OF CHAR;
      s2           : ARRAY [0..255] OF CHAR;
      b            : BOOLEAN;
      FreeFlag1    : BOOLEAN;
      FreeFlag2    : BOOLEAN;
    BEGIN
      ErrorCode := drv_def.ecSuccess;

      IF Param1.Type = drv_def.vtDString THEN
        PLBufferA1 := NIL;
        FreeFlag1 := drv_str.CreateAFromT( PLBufferA1, Param1.ValDStringW );
        drv_str.CopyDStrToStrA( s1, PLBufferA1 );
        LocalValue1.Type := drv_def.vtPString256;
        LocalValue1.ValPString256A := ADR( s1 );
        as1 := LocalValue1.ValPString256A;
        PLocalValue1 := ADR( LocalValue1 );
      ELSE
        FreeFlag1 := FALSE;
        PLocalValue1 := ADR( Param1 );
      END;
      IF Param2.Type = drv_def.vtDString THEN
        PLBufferA2 := NIL;
        FreeFlag2 := ( Param2.ValDStringW = NIL ) OR drv_str.CreateAFromT( PLBufferA2, Param2.ValDStringW );
        drv_str.CopyDStrToStrA( s2, PLBufferA2 );
        LocalValue2.Type := drv_def.vtPString256;
        LocalValue2.ValPString256A := ADR( s2 );
        as2 := LocalValue2.ValPString256A;
        PLocalValue2 := ADR( LocalValue2 );
      ELSE
        FreeFlag2 := FALSE;
        PLocalValue2 := ADR( Param2 );
      END;

      __QueryProc1( PObjectData, PLocalValue1^, PLocalValue2^ );

      IF ( Param1.Type = drv_def.vtDString ) AND ( as1 <> PLocalValue1^.ValPString256A ) THEN
        ErrorCode := drv_def.ecDriverOverwrittenString;
      ELSIF Param2.Type = drv_def.vtDString THEN
        IF as2 <> PLocalValue2^.ValPString256A THEN
          ErrorCode := drv_def.ecDriverOverwrittenString;
        ELSE // convert string back
          drv_str.CopyStrToDStrA( PLBufferA2, s2 );
          IF FreeFlag2 THEN // PLBufferA2 is newly allocated, so environment is UNICODE
            PBuffer := NIL;
            b := drv_str.CreateTFromA( PBuffer, PLBufferA2 );
            drv_def.SetValueDString( Param2, PBuffer );
            IF b AND ( PBuffer <> NIL ) THEN
              DISPOSE( PBuffer );
            END;
          ELSE // PLBufferA2 is Param2.ValDString, so it need not be SetValueDString back in Param2.
               // But, PLBufferA2 can be modified from CopyStrToDStrA, thus is MUST be
               // into Param2 ASSIGNED.
            // drv_def.SetValueDString( Param2, PBuffer );
            Param2.ValDStringA := drv_str.TPDStringA( PLBufferA2 );
          END;
        END;
      END;

      IF FreeFlag1 AND ( PLBufferA1 <> NIL ) THEN
        DISPOSE( PLBufferA1 );
      END;
      IF FreeFlag2 AND ( PLBufferA2 <> NIL ) THEN
        DISPOSE( PLBufferA2 );
      END;

      RETURN ErrorCode = drv_def.ecSuccess;
    END QueryProcString1;

  (*----------*)

  LABEL
    Fail;
  BEGIN
    IF ADDRESS( __QueryProc3W ) <> NIL THEN
      IF ( Param1.Type <> drv_def.vtDString ) AND ( Param2.Type <> drv_def.vtDString ) THEN
        __QueryProc3W( PObjectData, Param1, Param2, Param2 );
      ELSIF NOT QueryProcString3W() THEN
        GOTO Fail;
      END;
    ELSIF ADDRESS( __QueryProc1W ) <> NIL THEN
      IF ( Param1.Type <> drv_def.vtDString ) AND ( Param2.Type <> drv_def.vtDString ) THEN
        __QueryProc1W( PObjectData, Param1, Param2 );
      ELSIF NOT QueryProcString1W() THEN
        GOTO Fail;
      END;
    ELSIF ADDRESS( __QueryProc3 ) <> NIL THEN
      IF ( Param1.Type <> drv_def.vtDString ) AND ( Param2.Type <> drv_def.vtDString ) THEN
        __QueryProc3( PObjectData, Param1, Param2, Param2 );
      ELSIF NOT QueryProcString3() THEN // converts from/to UNICODE if needed
        GOTO Fail;
      END;
    ELSIF ADDRESS( __QueryProc1 ) <> NIL THEN
      IF ( Param1.Type <> drv_def.vtDString ) AND ( Param2.Type <> drv_def.vtDString ) THEN
        __QueryProc1( PObjectData, Param1, Param2 );
      ELSIF NOT QueryProcString1() THEN // converts from/to UNICODE if needed
        GOTO Fail;
      END;
    ELSE
      ErrorCode := drv_def.ecDriverMissingQueryProc;
  Fail:
      RETURN FALSE;
    END;

    RETURN TRUE;
  END QueryProc;

(*----------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE DriverCallBackA( Func : CARDINAL; Param : ADDRESS ) : CARDINAL;
  BEGIN
    RETURN drv_def.erNoFunction;
  END DriverCallBackA;

(*----------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE DriverCallBackW( Func : CARDINAL; Param : ADDRESS ) : CARDINAL;
  BEGIN
    RETURN drv_def.erNoFunction;
  END DriverCallBackW;

(*----------------------------------------------------------------------------*)

BEGIN
  DriverDLLName := '';
  DriverAppName := '';
  DriverHandle := MAX( CARDINAL );

  PObjectData := NIL;
  DLLHandle := NIL;
  DriverRunHandle := MAX( CARDINAL );
  DriverDLLVersion := 10000H * cwDriversAPIMajorVersion + cwDriversAPIMinorVersionGenericDriver;
  DriverRunMode := drv_def.drmRun;

  PBufferA := NIL;
  PBufferW := NIL;

  ParFilePath := '';
  PObjectData := NIL;

  __SystemEnvironment         := TSystemEnvironment( NIL );
  __MakeDriver                := TMakeDriver( NIL );
  __DisposeDriver             := TDisposeDriver( NIL );
  __Init                      := TInit( NIL );
  __Init3                     := TInit3( NIL );
  __ReadParameters            := TReadParameters( NIL );
  __QueryErrorCode            := TQueryErrorCode( NIL );
  __EnumerateChannels         := TEnumerateChannels( NIL );
  __InputParameters           := TInputParameters( NIL );
  __GetChannelDescription     := TGetChannelDescription( NIL );
  __Run                       := TRun( NIL );
  __Stop                      := TStop( NIL );
  __Done                      := TDone( NIL );
  __BufferInfo                := TBufferInfo( NIL );
  __SetBufferAddr             := TSetBufferAddr( NIL );
  __InputRequestStart         := TInputRequestStart( NIL );
  __InputRequest              := TInputRequest( NIL );
  __InputRequestCompleted     := TInputRequestCompleted( NIL );
  __InputFinalized            := TInputFinalized( NIL );
  __InputOOBDataQuery         := TInputOOBDataQuery( NIL );
  __GetInput1                 := TGetInput1( NIL );
  __OutputRequestStart        := TOutputRequestStart( NIL );
  __OutputRequest1            := TOutputRequest1( NIL );         
  __OutputRequestCompleted    := TOutputRequestCompleted( NIL );
  __OutputFinalized           := TOutputFinalized( NIL );
  __DriverProc                := TDriverProc( NIL );
  __QueryProc1                := TQueryProc1( NIL );    

  __GetInput2                 := TGetInput2( NIL );
  __OutputRequest2            := TOutputRequest2( NIL );

  __GetInput3                 := TGetInput3( NIL );
  __OutputRequest3            := TOutputRequest3( NIL );
  __QueryProc3                := TQueryProc3( NIL );

  __SystemEnvironmentW        := TSystemEnvironmentW( NIL );
  __MakeDriverW               := TMakeDriverW( NIL );
  __DisposeDriverW            := TDisposeDriverW( NIL );
  __InitW                     := TInitW( NIL );
  __Init3W                    := TInit3W( NIL );
  __ReadParametersW           := TReadParametersW( NIL );
  __QueryErrorCodeW           := TQueryErrorCodeW( NIL );
  __EnumerateChannelsW        := TEnumerateChannelsW( NIL );
  __InputParametersW          := TInputParametersW( NIL );
  __GetChannelDescriptionW    := TGetChannelDescriptionW( NIL );
  __RunW                      := TRunW( NIL );
  __StopW                     := TStopW( NIL );
  __DoneW                     := TDoneW( NIL );
  __BufferInfoW               := TBufferInfoW( NIL );
  __SetBufferAddrW            := TSetBufferAddrW( NIL );
  __InputRequestStartW        := TInputRequestStartW( NIL );
  __InputRequestW             := TInputRequestW( NIL );
  __InputRequestCompletedW    := TInputRequestCompletedW( NIL );
  __InputFinalizedW           := TInputFinalizedW( NIL );
  __InputOOBDataQueryW        := TInputOOBDataQueryW( NIL );
  __GetInput1W                := TGetInput1W( NIL );
  __OutputRequestStartW       := TOutputRequestStartW( NIL );
  __OutputRequest1W           := TOutputRequest1W( NIL );         
  __OutputRequestCompletedW   := TOutputRequestCompletedW( NIL );
  __OutputFinalizedW          := TOutputFinalizedW( NIL );
  __DriverProcW               := TDriverProcW( NIL );
  __QueryProc1W               := TQueryProc1W( NIL );    
                             
  __GetInput2W                := TGetInput2W( NIL );
  __OutputRequest2W           := TOutputRequest2W( NIL );

  __GetInput3W                := TGetInput3W( NIL );
  __OutputRequest3W           := TOutputRequest3W( NIL );
  __QueryProc3W               := TQueryProc3W( NIL );
END CDriver;

//=============================================================================

CLASS IMPLEMENTATION CDriverComponentDLLHelper;

//-----------------------------------------------------------------------------

  PUBLIC PROCEDURE Init( VAR ErrorString : ARRAY OF WCHAR; HModule : windows.HANDLE ) : BOOLEAN;
  VAR
    __Version : TVersion;
    __VersionW : TVersionW;
    __Check : TCheck;
    __CheckW : TCheckW;
    __GetDriverInfo : TGetDriverInfo;
    __GetDriverInfoW : TGetDriverInfoW;
  BEGIN
    // presetting
    State := dcstMapError;
    DLLHandle := HModule;

    // get driver info -- check it first as it is specific for drivers -- all instruments
    // are skipped and scan is faster
    __GetDriverInfo := TGetDriverInfo( windows.GetProcAddress( DLLHandle, procGetDriverInfoA ));
    __GetDriverInfoW := TGetDriverInfoW( windows.GetProcAddress( DLLHandle, procGetDriverInfoW ));
    IF ( ADDRESS( __GetDriverInfo ) = NIL ) AND ( ADDRESS( __GetDriverInfoW ) = NIL ) THEN
      Strings.ConcatW( OUT ErrorString, 'GetDriverInfo, GetDriverInfoW', _ProcedureNotFoundInDLL );
      RETURN FALSE;
    END;
    // version
    __Version := TVersion( windows.GetProcAddress( DLLHandle, procVersionA ));
    __VersionW := TVersionW( windows.GetProcAddress( DLLHandle, procVersionW ));
    IF ( ADDRESS( __Version ) = NIL ) AND ( ADDRESS( __VersionW ) = NIL ) THEN
      Strings.ConcatW( OUT ErrorString, 'Version, VersionW', _ProcedureNotFoundInDLL );
      RETURN FALSE;
    END;
    // check
    __Check := TCheck( windows.GetProcAddress( DLLHandle, procCheckA ));
    __CheckW := TCheckW( windows.GetProcAddress( DLLHandle, procCheckW ));
    IF ( ADDRESS( __Check ) = NIL ) AND ( ADDRESS( __CheckW ) = NIL ) THEN
      Strings.ConcatW( OUT ErrorString, 'Check, CheckW', _ProcedureNotFoundInDLL );
      RETURN FALSE;
    END;
    State := dcstMapOK;

    RETURN TRUE;
  END Init;

//-----------------------------------------------------------------------------

  PUBLIC PROCEDURE Version( VAR DriverVersion : CARDINAL ) : BOOLEAN;
  VAR
    __Version : TVersion;
    __VersionW : TVersionW;
  BEGIN
    IF State <> dcstMapOK THEN
      RETURN FALSE;
    END;
    __Version := TVersion( windows.GetProcAddress( DLLHandle, procVersionA ));
    __VersionW := TVersionW( windows.GetProcAddress( DLLHandle, procVersionW ));
    IF ADDRESS( __VersionW ) <> NIL THEN
      DriverVersion := __VersionW(); 
    ELSIF ADDRESS( __Version ) <> NIL THEN
      DriverVersion := __Version(); 
    ELSE
      RETURN FALSE;
    END;
    RETURN TRUE;
  END Version;

//-----------------------------------------------------------------------------

  PUBLIC PROCEDURE GetDriverDescription( VAR Description : ARRAY OF WCHAR ) : BOOLEAN;
  VAR
    DA : ARRAY [0..255] OF CHAR;
    DW : ARRAY [0..255] OF WCHAR;
    __GetDriverInfo : TGetDriverInfo;
    __GetDriverInfoW : TGetDriverInfoW;
  BEGIN
    IF State <> dcstMapOK THEN
      RETURN FALSE;
    END;
    __GetDriverInfo := TGetDriverInfo( windows.GetProcAddress( DLLHandle, procGetDriverInfoA ));
    __GetDriverInfoW := TGetDriverInfoW( windows.GetProcAddress( DLLHandle, procGetDriverInfoW ));
    IF ADDRESS( __GetDriverInfoW ) <> NIL THEN
      __GetDriverInfoW( DW );
      ASSIGN( Description, DW );
    ELSE
      __GetDriverInfo( DA );
      Strings.ToW( DA, 0, OUT Description );
    END;
    RETURN TRUE;
  END GetDriverDescription;

//-----------------------------------------------------------------------------

  PUBLIC PROCEDURE AbleToRunInThisCW( VAR ErrorString : ARRAY OF WCHAR; ControlWebKind, MajorVersion, MinorVersion : CARDINAL ) : BOOLEAN;
  VAR
    __Check : TCheck;
    __CheckW : TCheckW;
    ESA : ARRAY [0..255] OF CHAR;
    ESW : ARRAY [0..255] OF WCHAR;
  BEGIN
    IF State <> dcstMapOK THEN
      ASSIGN( ErrorString, _DLLHasBadInterface );
      RETURN FALSE;
    END;
    __Check := TCheck( windows.GetProcAddress( DLLHandle, procCheckA ));
    __CheckW := TCheckW( windows.GetProcAddress( DLLHandle, procCheckW ));
    IF ADDRESS( __CheckW ) <> NIL THEN
      IF NOT __CheckW( ESW, ControlWebKind, MajorVersion, MinorVersion, cwDriversAPIMajorVersionDString, cwDriversAPIMinorVersionRevision2 ) THEN
        ASSIGN( ErrorString, ESW );
        RETURN FALSE;
      END;
    ELSIF ADDRESS( __Check ) <> NIL THEN
      IF NOT __Check( ESA, ControlWebKind, MajorVersion, MinorVersion, cwDriversAPIMajorVersionDString, cwDriversAPIMinorVersionRevision2 ) THEN
        Strings.ToW( ESA, 0, OUT ErrorString );
        RETURN FALSE;
      END;
    END;
    RETURN TRUE;
  END AbleToRunInThisCW;

//-----------------------------------------------------------------------------

  PUBLIC PROCEDURE IsUNICODE( VAR _IsUNICODE : BOOLEAN ) : BOOLEAN;
  BEGIN
    IF State <> dcstMapOK THEN
      RETURN FALSE;
    END;
  (*%F UNICODE *)
    _IsUNICODE := ( ADDRESS( TVersion(  windows.GetProcAddress( DLLHandle, procVersionA ))) = NIL ) AND
                  ( ADDRESS( TVersionW( windows.GetProcAddress( DLLHandle, procVersionW ))) <> NIL );
  (*%E UNICODE *)
  (*%T UNICODE *)
    _IsUNICODE := ADDRESS( TVersionW( windows.GetProcAddress( DLLHandle, procVersionW ))) <> NIL;
  (*%E UNICODE *)
    RETURN TRUE;
  END IsUNICODE;

//-----------------------------------------------------------------------------

  PUBLIC PROCEDURE AbleToEnumerateChannels( ForceInit3 : BOOLEAN ) : BOOLEAN;
  VAR
    __EnumerateChannels : TEnumerateChannels;
    __EnumerateChannelsW : TEnumerateChannelsW;
    __Init3 : TInit3;
    __Init3W : TInit3W;
  BEGIN
    __EnumerateChannels := TEnumerateChannels( windows.GetProcAddress( DLLHandle, procEnumerateChannelsA ));
    __EnumerateChannelsW := TEnumerateChannelsW( windows.GetProcAddress( DLLHandle, procEnumerateChannelsW ));
    IF ( ADDRESS( __EnumerateChannels ) = NIL ) AND ( ADDRESS( __EnumerateChannelsW ) = NIL ) THEN
      RETURN FALSE;
    ELSIF NOT ForceInit3 THEN
      RETURN TRUE;
    END;
    __Init3 := TInit3( windows.GetProcAddress( DLLHandle, procInit3A ));
    __Init3W := TInit3W( windows.GetProcAddress( DLLHandle, procInit3W ));
    RETURN ( ADDRESS( __Init3 ) <> NIL ) OR ( ADDRESS( __Init3W ) <> NIL );
  END AbleToEnumerateChannels;

//-----------------------------------------------------------------------------

BEGIN
  State := dcstInit;
  DLLHandle := NIL;
END CDriverComponentDLLHelper;

//=============================================================================

TYPE
  TPMapTreeElem = POINTER TO CMapTreeElem;

CLASS CMapTreeElem( avltree.CAVLTreeElem );
  From         : CARDINAL;
  Count        : CARDINAL;
  Type         : drv_def.TValueType;
  Direction    : drv_def.TDirection;
  PId          : drv_str.TPDStringW;
  PDescription : drv_str.TPDStringW;
  PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;
  OPERATOR :=( CONST E : CMapTreeElem );
END CMapTreeElem;

//-----------------------------------------------------------------------------

CLASS IMPLEMENTATION CMapTreeElem;

//-----------------------------------------------------------------------------

  PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;
  BEGIN
    // an interval is tested
    IF TPMapTreeElem( pelem )^.From > From THEN
      RETURN -1;
    ELSIF TPMapTreeElem( pelem )^.From + TPMapTreeElem( pelem )^.Count - 1 < From THEN
      RETURN 1;
    ELSE
      RETURN 0;
    END;
  END Compare;

//-----------------------------------------------------------------------------

  OPERATOR CMapTreeElem.:=( CONST E : CMapTreeElem );
  BEGIN
    Storage.Move( ADR( E ), ADR( SELF ), SIZE( SELF ));
  END CMapTreeElem.:=;

//-----------------------------------------------------------------------------

BEGIN
  From := 0;
  Count := 0;
  Type := drv_def.vtNothing;
  Direction := drv_def.TDirection{};
  PId := NIL;
  PDescription := NIL;
FINALLY
  IF PId <> NIL THEN
    DISPOSE( PId );
  END;
  IF PDescription <> NIL THEN
    DISPOSE( PDescription );
  END;
END CMapTreeElem;

//-----------------------------------------------------------------------------

CLASS IMPLEMENTATION CChannelMap;

//-----------------------------------------------------------------------------

  PUBLIC PROCEDURE LoadFromDriver( VAR ErrorString : ARRAY OF WCHAR; PDriver : TPDriver ) : BOOLEAN;
  VAR
    Description : ARRAY [0..511] OF WCHAR;
    ES : LONGWORD;
    i : CARDINAL;
    Id : ARRAY [0..63] OF WCHAR;
    ME : CMapTreeElem;
    PME : TPMapTreeElem;
    ns : ARRAY [0..31] OF WCHAR;
    b : BOOLEAN;
  BEGIN
    IF NOT PDriver^.AbleToEnumerateChannels( FALSE ) THEN
      RETURN FALSE;
    END;

    ES := 0;
    WHILE PDriver^.EnumerateChannels( ES, i, ME.Direction, ME.From, ME.Count, b ) DO
      ME.Type := drv_def.TValueType( i );

      IF Channels.Search( ADR( ME ), OUT PME ) THEN
        ASSIGN( ErrorString, drv_wrapper_._Channel_number_redefined );
        Strings.FromCARD32W( PME^.From, 10, OUT ns );
        Strings.AppendW( REF ErrorString, L' (' );
        Strings.AppendW( REF ErrorString, ns );
        Strings.AppendW( REF ErrorString, L')' );
        RETURN FALSE;
      ELSIF NOT b THEN
        NEW( PME );
        PME^ := ME;
        Channels.Insert( PME );  
      ELSIF b THEN // get description too
        FOR i := ME.From TO ME.From + ME.Count - 1 DO
          NEW( PME );
          PME^ := ME; PME^.From := i; PME^.Count := 1;
          Channels.Insert( PME );
          IF PDriver^.GetChannelDescription( i, Description, Id ) THEN
            IF Id[0] <> 0W THEN
              drv_str.CopyStrToDStrW( PME^.PId, Id );
            END;
            IF Description[0] <> 0W THEN
              drv_str.CopyStrToDStrW( PME^.PDescription, Description );
            END;
          END;
        END;
      END;
    
    END; // WHILE

    RETURN TRUE;
  END LoadFromDriver;

//-----------------------------------------------------------------------------

(*/*
  PROCEDURE LoadFromDString( VAR ErrorString : ARRAY OF TCHAR; PString : vdstr.TPDString ) : BOOLEAN;
  LABEL
    Failure;
  CONST
    kwBegin = 'begin';
    kwEnd = 'end';
    kwREAL = 'real';
    kwBOOLEAN = 'boolean';
    kwBUFFER = 'buffer';
    kwSTRING = 'string';
    kwINTEGER = 'integer';
    kwLONGINT = 'longint';
    kwLONGCARD = 'longcard';
    kwCARDINAL = 'cardinal';
    kwSHORTREAL = 'shortreal';
    kwSHORTCARD = 'shortcard';
    kwSHORTINT = 'shortint';
    kwInput = 'input';
    kwInputShort = 'in';
    kwInputAbbreviation = 'i';
    kwOutput = 'output';
    kwOutputShort = 'out';
    kwOutputAbbreviation = 'o';
    kwBidirectional = 'bidirectional';
    kwBidirectionalShort = 'bidirect';
    kwBidirectionalAbbreviation = 'b';
  TYPE
    TExpect = (
      expectBegin,
      expectLoRange,
      expectInterval,
      expectHiRange,
      expectType,
      expectDirection,
      expectDot
    );
  VAR
    ec : CARDINAL;
    Expect : TExpect;
    ME : CMapTreeElem;
    PME : TPMapTreeElem;
    Token : vtape.TToken;
    TR : vtape.CStringTapeReader;
    Id : BOOLEAN;
    b : BOOLEAN;
  BEGIN
    TR.InitDString( PString );
    Expect := expectBegin;

    LOOP
      IF NOT TR.ReadToken( ec, Token, TRUE ) THEN
        CASE ec OF
        | 
        END;
        EXIT;
      ELSIF Token.Kind = vtape.tokenEndOfSource THEN
        EXIT;
      ELSIF Token.Kind = vtape.tokenIdentifier THEN
        Id := TRUE;
        Str.Lows( Token.PString^ );
      ELSE
        Id := FALSE;
      END;

      CASE Expect OF
      //----------
      | expectBegin :
        IF Id AND ( Str.Compare( Token.PString^, kwBegin ) = 0 ) THEN
          Expect := expectLoRange;
        END;
        TR.ReadToken( ec, Token, FALSE );

      //----------
      | expectLoRange :
        IF Token.Kind = vtape.tokenNumberLiteral THEN
          ME.From := Str.StrToCard( Token.PString^, 10, b );
          IF NOT b THEN
            Str.Copy( ErrorString, drv_wrapper_._Bad_number_in_map_file );
            Str.Append( ErrorString, ' (' );
            Str.Append( ErrorString, Token.PString^ );
            Str.Append( ErrorString, ')' );
            GOTO Failure;
          END;
          TR.ReadToken( ec, Token, FALSE );
          Expect := expectInterval;
        ELSIF Id AND ( Str.Compare( Token.PString^, kwEnd ) = 0 ) THEN
          TR.ReadToken( ec, Token, FALSE );
          Expect := expectDot;
        ELSE
          Str.Copy( ErrorString, drv_wrapper_._Bad_number_in_map_file );
          GOTO Failure;
        END;

      //----------
      | expectInterval :
        IF Token.Kind = vtape.tokenMinus THEN
          TR.ReadToken( ec, Token, FALSE );
          Expect := expectHiRange;
        ELSE
          ME.Count := 1;
          Expect := expectType;
        END;

      //----------
      | expectHiRange :
        IF Token.Kind = vtape.tokenNumberLiteral THEN
          ec := Str.StrToCard( Token.PString^, 10, b );
          IF NOT b THEN
            Str.Copy( ErrorString, drv_wrapper_._Bad_number_in_map_file );
            Str.Append( ErrorString, ' (' );
            Str.Append( ErrorString, Token.PString^ );
            Str.Append( ErrorString, ')' );
            GOTO Failure;
          END;
          IF ec < ME.From THEN
            Str.Copy( ErrorString, drv_wrapper_._Hi_less_than_Lo );
            Str.Append( ErrorString, ' (' );
            Str.Append( ErrorString, Token.PString^ );
            Str.Append( ErrorString, ')' );
            GOTO Failure;
          ELSE
            ME.Count := ec - ME.From + 1;
          END;
          TR.ReadToken( ec, Token, FALSE );
          Expect := expectType;
        ELSE
          Str.Copy( ErrorString, drv_wrapper_._Bad_number_in_map_file );
          GOTO Failure;
        END;

      //----------
      | expectType :
        IF NOT Id THEN
          Str.Copy( ErrorString, drv_wrapper_._Expected_Type );
          GOTO Failure;
        END;
        IF Str.Compare( Token.PString^, kwREAL ) = 0 THEN
          ME.Type := cw_def.vtLongReal;
        ELSIF Str.Compare( Token.PString^, kwBOOLEAN ) = 0 THEN
          ME.Type := cw_def.vtBoolean;
        ELSIF Str.Compare( Token.PString^, kwBUFFER ) = 0 THEN
          ME.Type := cw_def.vtBuffer;
        ELSIF Str.Compare( Token.PString^, kwSTRING ) = 0 THEN
          ME.Type := cw_def.vtDString;
        ELSIF Str.Compare( Token.PString^, kwINTEGER ) = 0 THEN
          ME.Type := cw_def.vtInteger;
        ELSIF Str.Compare( Token.PString^, kwLONGINT ) = 0 THEN
          ME.Type := cw_def.vtLongInt;
        ELSIF Str.Compare( Token.PString^, kwLONGCARD ) = 0 THEN
          ME.Type := cw_def.vtLongCard;
        ELSIF Str.Compare( Token.PString^, kwCARDINAL ) = 0 THEN
          ME.Type := cw_def.vtCardinal;
        ELSIF Str.Compare( Token.PString^, kwSHORTREAL ) = 0 THEN
          ME.Type := cw_def.vtReal;
        ELSIF Str.Compare( Token.PString^, kwSHORTCARD ) = 0 THEN
          ME.Type := cw_def.vtShortCard;
        ELSIF Str.Compare( Token.PString^, kwSHORTINT ) = 0 THEN
          ME.Type := cw_def.vtShortInt;
        ELSE
          Str.Copy( ErrorString, drv_wrapper_._Unknown_Type );
          Str.Append( ErrorString, ' (' );
          Str.Append( ErrorString, Token.PString^ );
          Str.Append( ErrorString, ')' );
          GOTO Failure;
        END;
        TR.ReadToken( ec, Token, FALSE );
        Expect := expectDirection;

      //----------
      | expectDirection :
        IF NOT Id THEN
          Str.Copy( ErrorString, drv_wrapper_._Expected_Direction );
          GOTO Failure;
        END;
        IF Str.Compare( Token.PString^, kwInput ) = 0 THEN
          ME.Direction := cw_def.TDirection{cw_def.dirInput};
        ELSIF Str.Compare( Token.PString^, kwInputShort ) = 0 THEN
          ME.Direction := cw_def.TDirection{cw_def.dirInput};
        ELSIF Str.Compare( Token.PString^, kwInputAbbreviation ) = 0 THEN
          ME.Direction := cw_def.TDirection{cw_def.dirInput};
        ELSIF Str.Compare( Token.PString^, kwOutput ) = 0 THEN
          ME.Direction := cw_def.TDirection{cw_def.dirOutput};
        ELSIF Str.Compare( Token.PString^, kwOutputShort ) = 0 THEN
          ME.Direction := cw_def.TDirection{cw_def.dirOutput};
        ELSIF Str.Compare( Token.PString^, kwOutputAbbreviation ) = 0 THEN
          ME.Direction := cw_def.TDirection{cw_def.dirOutput};
        ELSIF Str.Compare( Token.PString^, kwBidirectional ) = 0 THEN
          ME.Direction := cw_def.TDirection{cw_def.dirInput, cw_def.dirOutput};
        ELSIF Str.Compare( Token.PString^, kwBidirectionalShort ) = 0 THEN
          ME.Direction := cw_def.TDirection{cw_def.dirInput, cw_def.dirOutput};
        ELSIF Str.Compare( Token.PString^, kwBidirectionalAbbreviation ) = 0 THEN
          ME.Direction := cw_def.TDirection{cw_def.dirInput, cw_def.dirOutput};
        ELSE
          Str.Copy( ErrorString, drv_wrapper_._Unknown_Direction );
          Str.Append( ErrorString, ' (' );
          Str.Append( ErrorString, Token.PString^ );
          Str.Append( ErrorString, ')' );
          GOTO Failure;
        END;

        // check and append item into the tree
        IF Channels.Search( ADR( ME ), PME ) THEN
          Str.Copy( ErrorString, drv_wrapper_._Channel_number_redefined );
          GOTO Failure;
        ELSE
          NEW( PME );
          PME^ := ME;
          Channels.Insert( PME );
        END;

        // go again
        TR.ReadToken( ec, Token, FALSE );
        Expect := expectLoRange;

      //----------
      | expectDot :
        IF Token.Kind = vtape.tokenPoint THEN
          EXIT;
        ELSE
          EXIT;
        END;
      END; // CASE

    END; // LOOP

    TR.Done();
    RETURN TRUE;

  Failure:
    TR.Done();
    RETURN FALSE;
  END LoadFromDString;

//-----------------------------------------------------------------------------

  PROCEDURE LoadFromFile( VAR ErrorString : ARRAY OF TCHAR; Path : ARRAY OF TCHAR ) : BOOLEAN;
  VAR
    a : ADDRESS;
    c : CARDINAL;
    F : FIO.File;
    l, s : CARDINAL;
    PS : vdstr.TPDString;
    PSA : vdstr.TPDStringA;
    PSW : vdstr.TPDStringW;
    f : BOOLEAN;
    Result : BOOLEAN;
    u : BOOLEAN;
  BEGIN
    F := FIO.OpenRead( Path, FIO.fsRead );
    IF F = FIO.FileError THEN
      Str.Copy( ErrorString, drv_wrapper_._Cannot_find_map_file );
      RETURN FALSE;
    END;

    PS := NIL;
    PSA := NIL;
    PSW := NIL;
    s := FIO.Size( F );
    u := FIO.IsUnicodeFile( F );
    IF u THEN
      c := ( s + 1 ) DIV SIZE( TCHAR );
      vdstr.EnsureDStrLenW( PSW, c, a, l );
      PSW^.Len := c;
      FIO.RdBin( F, a^, s );
      f := vdstr.CreateTFromU( PS, PSW );
    ELSE
      vdstr.EnsureDStrLenA( PSA, s, a, l );
      PSA^.Len := s;
      FIO.RdBin( F, a^, s );
      f := vdstr.CreateTFromA( PS, PSA );
    END;  
    Result := LoadFromDString( ErrorString, PS );

    IF f THEN
      DISPOSE( PS );
    END;
    IF PSA <> NIL THEN
      DISPOSE( PSA );
    END;
    IF PSW <> NIL THEN
      DISPOSE( PSW );
    END;

    FIO.Close( F );
    RETURN Result;
  END LoadFromFile;
*/*)

//-----------------------------------------------------------------------------

  PUBLIC PROCEDURE Dispose();
  BEGIN
    Channels.Dispose();
  END Dispose;

//-----------------------------------------------------------------------------

  VIRTUAL PROCEDURE Check( VAR ErrorString : ARRAY OF WCHAR; DriverIndex, Count : CARDINAL; Type : drv_def.TValueType; CheckedDirection : drv_def.TDirection; VAR AllowedDirection : drv_def.TDirection ) : BOOLEAN;
  VAR
    i : INTEGER;
    ME : CMapTreeElem;
    PME : TPMapTreeElem;
  BEGIN
    IF Type = drv_def.vtBuffer THEN
      RETURN TRUE;
    ELSIF Channels.Count = 0 THEN
      // channel number not found in the tree
      ASSIGN( ErrorString, drv_wrapper_._Incorrect_channel_number );
      RETURN FALSE;
    END;
    ME.Count := 1;
    FOR i := DriverIndex TO DriverIndex + Count - 1 DO
      ME.From := i;
      IF Channels.Search( ADR( ME ), OUT PME ) THEN
        // element found, test direction and type
        IF CheckedDirection * PME^.Direction <> CheckedDirection THEN
          ASSIGN( ErrorString, drv_wrapper_._Incorrect_channel_direction );
          RETURN FALSE;
        END;
        IF Type <> PME^.Type THEN
          ASSIGN( ErrorString, drv_wrapper_._Incorrect_channel_type );
          RETURN FALSE;
        END;
      ELSIF AutomaticInsertOnCheck THEN
        NEW( PME );
        PME^ := ME;
        Channels.Insert( PME );
        AllowedDirection := CheckedDirection;
        RETURN TRUE;
      ELSE
        // channel number not found in the tree and it cannot be added
        ASSIGN( ErrorString, drv_wrapper_._Incorrect_channel_number );
        RETURN FALSE;
      END;
    END;
    AllowedDirection := PME^.Direction;
    RETURN TRUE;
  END Check;

//-----------------------------------------------------------------------------

  PUBLIC PROCEDURE Get( VAR ErrorString : ARRAY OF WCHAR; DriverIndex : CARDINAL; VAR Type : drv_def.TValueType; VAR Direction : drv_def.TDirection ) : BOOLEAN; // ErrorCode
  VAR
    ME : CMapTreeElem;
    PME : TPMapTreeElem;
  BEGIN
    ME.From := DriverIndex;
    ME.Count := 1;
    IF Channels.Search( ADR( ME ), OUT PME ) THEN
      Type := PME^.Type;
      Direction := PME^.Direction;
      RETURN TRUE;
    ELSE
      // channel number not found in the tree
      ASSIGN( ErrorString, drv_wrapper_._Incorrect_channel_number );
      RETURN FALSE;
    END;
  END Get;

//-----------------------------------------------------------------------------

  PUBLIC PROCEDURE Info( VAR ErrorString : ARRAY OF WCHAR; DriverIndex : CARDINAL; VAR Id, Description : ARRAY OF WCHAR ) : BOOLEAN;
  VAR
    ME : CMapTreeElem;
    PME : TPMapTreeElem;
  BEGIN
    ME.From := DriverIndex;
    ME.Count := 1;
    IF Channels.Search( ADR( ME ), OUT PME ) THEN
      drv_str.CopyDStrToStrW( Id, PME^.PId );
      drv_str.CopyDStrToStrW( Description, PME^.PDescription );
      RETURN TRUE;
    ELSE
      // channel number not found in the tree
      ASSIGN( ErrorString, drv_wrapper_._Incorrect_channel_number );
      RETURN FALSE;
    END;
  END Info;

//-----------------------------------------------------------------------------

BEGIN
  AutomaticInsertOnCheck := FALSE;
END CChannelMap;

//=============================================================================

END drv_wrapper.
