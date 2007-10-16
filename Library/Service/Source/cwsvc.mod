MODULE cwsvc;

////////////////////////////////////////////////////////////////
// Control Web Administrator EXE                              //
//                            Service (WNT) and W9x interface //
//                              (C) 2001 Moravian Instruments //
////////////////////////////////////////////////////////////////

(*# module( init_code => off ) *)
(*# option( pack => 8 ) *)
(*# call( o_a_copy => off ) *)

(*===========================================================================*)

FROM Storage IMPORT ALLOCATE, FREE;

IMPORT
  assert,
  windows,
  wincon,
  winerror,
  winnls,
  winreg,
  winsock,
  winsvc;

IMPORT
  FIO,
  Str;

IMPORT
  vcom,
  vipc,
  vnet,
  vsvc_def,
  vsvc,
  vwthread;

IMPORT
  cw_ipc,
  cw_ipc_,
  cw_srv,
  cwsvc_,
  cwsvclr;

(*===========================================================================*)

CONST
  maximalWaitTime = 10000; // 10 s

TYPE
  TPService = POINTER TO CService;

CLASS CService;
  HEventSource        : windows.HANDLE;
  ServiceStatus       : winsvc.SERVICE_STATUS;
  StatusHandle        : winsvc.SERVICE_STATUS_HANDLE;

  PLicenceEnumerator  : cw_ipc.TPLicenceEnumerator;
  PIPCServer          : vnet.TPIPServer;
  PCWServer           : cw_srv.TPServer;

  PROCEDURE Init() : windows.DWORD;
  PROCEDURE Done();

  PROCEDURE StartService();
  PROCEDURE ControlService( ControlCode : CARDINAL ) : BOOLEAN;
    // if ControlService returns true, it should be stopped...
  PROCEDURE SetServiceState( ServiceState, ErrorCode : windows.DWORD ) : BOOLEAN;

  PROCEDURE LogEvent( ErrorCode : windows.DWORD; ErrorText : ARRAY OF WCHAR );
  PROCEDURE CreateEventLogSource() : windows.DWORD;
END CService;

VAR
  PService : TPService;

(*===========================================================================*)

TYPE
  TParamStringW       = ARRAY[0..255] OF WCHAR;
  TPParamStringW      = POINTER TO TParamStringW;
  TParamStringArrayW  = ARRAY [0..0] OF TPParamStringW;
  TPParamStringArrayW = POINTER TO TParamStringArrayW;

(*# save, call( o_a_size=>off,
                prefix=>stdcall ) *)

PROCEDURE ControlHandler( fdwControl : CARDINAL );
BEGIN
  IF PService <> NIL THEN
    IF PService^.ControlService( fdwControl ) THEN
      PService^.Done();
      FREE( PService );
    END;
  END;
END ControlHandler;

(*---------------------------------------------------------------------------*)

PROCEDURE ServiceMain( argc : INTEGER; argv : TPParamStringArrayW );
BEGIN
  IF PService = NIL THEN
    NEW( PService );
    PService^.Init();
  END;
  PService^.StartService();
END ServiceMain;

(*# restore *)

(*===========================================================================*)

CLASS IMPLEMENTATION CService;

(*---------------------------------------------------------------------------*)
  
  PROCEDURE Init() : windows.DWORD;
  VAR
    Result : CARDINAL;
  BEGIN
    Result := CreateEventLogSource();
    PLicenceEnumerator := cwsvclr.CreateSVCLicenceEnumerator();
    IF PLicenceEnumerator <> NIL THEN
      Result := PLicenceEnumerator^.Initialize();
    END;
    RETURN windows.DWORD( Result );
  END Init;

(*---------------------------------------------------------------------------*)

  PROCEDURE Done();
  BEGIN
    IF PLicenceEnumerator <> NIL THEN
      PLicenceEnumerator^.Done();
      FREE( PLicenceEnumerator );
    END;
    IF HEventSource <> NIL THEN
      windows.DeregisterEventSource( HEventSource );
      HEventSource := NIL;
    END;
  END Done;

(*---------------------------------------------------------------------------*)

  PROCEDURE StartService();
  LABEL
    Fail;
  VAR
    Result : CARDINAL;
  BEGIN
    StatusHandle := winsvc.RegisterServiceCtrlHandlerW( vsvc_def.defaultIPCSvcNameW, winsvc.PHANDLER_FUNCTION( ControlHandler ));
    IF StatusHandle = winsvc.SERVICE_STATUS_HANDLE( NIL ) THEN
      GOTO Fail;

    ELSIF SetServiceState( winsvc.SERVICE_START_PENDING, 0 ) THEN
      Result := cw_srv.CreateServer( FALSE, HEventSource, PLicenceEnumerator, PIPCServer, PCWServer );
      IF Result <> winerror.ERROR_SUCCESS THEN
        windows.SetLastError( Result );
        GOTO Fail;
      END;

      SetServiceState( winsvc.SERVICE_RUNNING, 0 );
      LogEvent( winerror.ERROR_SUCCESS, cwsvc_._ServiceIsStartedSuccessfully );
    END;

    RETURN;

  Fail:
    Result := windows.GetLastError();
    LogEvent( Result, cwsvc_._RegisterServiceCtrlHandlerFailed );
    SetServiceState( winsvc.SERVICE_STOPPED, Result );
  END StartService;

(*---------------------------------------------------------------------------*)

  PROCEDURE ControlService( ControlCode : CARDINAL ) : BOOLEAN;
  LABEL
    Fail;
  VAR
    Result : CARDINAL;
  BEGIN
    Result := winerror.ERROR_SUCCESS;

    CASE ControlCode OF
    | winsvc.SERVICE_CONTROL_CONTINUE :
      IF NOT SetServiceState( winsvc.SERVICE_CONTINUE_PENDING, 0 ) THEN
        GOTO Fail;
      END;
      Result := PIPCServer^.RegisterPort( vipc.defaultIPCPort, winsock.SOCK_STREAM, PCWServer, 0, NIL );
      IF Result <> winerror.ERROR_SUCCESS THEN
        GOTO Fail;
      END;
      IF SetServiceState( winsvc.SERVICE_RUNNING, 0 ) THEN
        LogEvent( winerror.ERROR_SUCCESS, cwsvc_._ServiceIsResumedSuccessfully );
      ELSE
        GOTO Fail;
      END;

    // | winsvc.SERVICE_CONTROL_INTERROGATE : -- solved in ELSE of CASE
    //  SetServiceState( ServiceStatus.dwCurrentState, 0 );

    | winsvc.SERVICE_CONTROL_PAUSE :
      IF NOT SetServiceState( winsvc.SERVICE_PAUSE_PENDING, 0 ) THEN
        GOTO Fail;
      END;
      PIPCServer^.ForgetPort( vipc.defaultIPCPort, winsock.SOCK_STREAM );
      IF SetServiceState( winsvc.SERVICE_PAUSED, 0 ) THEN
        LogEvent( winerror.ERROR_SUCCESS, cwsvc_._ServiceIsPausedSuccessfully );
      ELSE
        GOTO Fail;
      END;

    | winsvc.SERVICE_CONTROL_SHUTDOWN,
      winsvc.SERVICE_CONTROL_STOP :
      IF NOT SetServiceState( winsvc.SERVICE_STOP_PENDING, 0 ) THEN
        GOTO Fail;
      END;
      cw_srv.DoneServer( PCWServer );
      IF SetServiceState( winsvc.SERVICE_STOPPED, 0 ) THEN
        LogEvent( winerror.ERROR_SUCCESS, cwsvc_._ServiceIsStoppedSuccessfully );
        RETURN TRUE;
      ELSE
        GOTO Fail;
      END;
    
    ELSE
      SetServiceState( ServiceStatus.dwCurrentState, 0 );
    END; // CASE

    RETURN FALSE;

  Fail:
    cw_srv.DoneServer( PCWServer );
    SetServiceState( winsvc.SERVICE_STOPPED, 0 );
    RETURN TRUE;

    // SERVICE_CONTINUE_PENDING The service continue is pending. 
    // SERVICE_PAUSE_PENDING The service pause is pending. 
    // SERVICE_PAUSED The service is paused. 
    // SERVICE_RUNNING The service is running. 
    // SERVICE_START_PENDING The service is starting. 
    // SERVICE_STOP_PENDING The service is stopping. 
    // SERVICE_STOPPED 
  END ControlService;

(*---------------------------------------------------------------------------*)

  PROCEDURE SetServiceState( ServiceState, ErrorCode : windows.DWORD ) : BOOLEAN;
  BEGIN
    WITH ServiceStatus DO
      IF ServiceState = ServiceStatus.dwCurrentState THEN
        INC( dwCheckPoint );
      ELSE
        dwCurrentState := ServiceState; 
        dwCheckPoint   := 0;
      END;
      dwWaitHint      := maximalWaitTime; 
      dwWin32ExitCode := ErrorCode;
    END; // WITH
    IF winsvc.SetServiceStatus( StatusHandle, ADR( ServiceStatus )) = windows.True THEN
      RETURN TRUE;
    ELSE
      LogEvent( windows.GetLastError(), cwsvc_._SetServiceStatusFailed );
      RETURN FALSE;
    END;
  END SetServiceState;

(*---------------------------------------------------------------------------*)

  PROCEDURE LogEvent( ErrorCode : windows.DWORD; ErrorText : ARRAY OF WCHAR );
  VAR
    LocalErrorText : vcom.TString255W;
    LogType        : WORD;
    PErrorText     : windows.PWSTR;
  BEGIN
    IF HEventSource = NIL THEN
      RETURN;
    END;
    IF ErrorCode = winerror.ERROR_SUCCESS THEN
      LogType := windows.EVENTLOG_INFORMATION_TYPE;
    ELSE
      LogType := windows.EVENTLOG_ERROR_TYPE;
    END;
    IF ErrorCode = 0 THEN
      Str.CopyW( LocalErrorText, ErrorText );
    ELSE
      vcom.GetErrorMessageW( ErrorCode, LocalErrorText );
      Str.PrependW( LocalErrorText, L': ' );
      Str.PrependW( LocalErrorText, ErrorText );
    END;
    PErrorText := windows.PWSTR( ADR( LocalErrorText ));
    windows.ReportEventW( HEventSource, LogType, 0, 1, NIL, 1, 0, windows.PPCWSTR( ADR( PErrorText )), NIL );
  END LogEvent;

(*---------------------------------------------------------------------------*)

  PROCEDURE CreateEventLogSource() : windows.DWORD;
  LABEL
    Fail;
  CONST
    EventLogPath = L'SYSTEM\CurrentControlSet\Services\EventLog\Application';
  VAR
    EventTypeData : windows.DWORD;
    HKey          : winreg.HKEY;
    Len           : CARDINAL;
    Path          : FIO.PathStrW;
    Result        : windows.DWORD;
  BEGIN
    Str.ConcatW( Path, EventLogPath, L'\' );
    Str.AppendW( Path, vsvc_def.defaultIPCSvcDisplayName );
    HKey := NIL;

    Result := winreg.RegCreateKeyExW(
                winreg.HKEY_LOCAL_MACHINE,
                ADR( Path ),
                0, NIL, 
                windows.REG_OPTION_NON_VOLATILE,
                windows.KEY_READ OR windows.KEY_WRITE,
                NIL, ADR( HKey ), NIL );
    IF Result <> winerror.ERROR_SUCCESS THEN
      GOTO Fail;
    END;

    // Add the name to the EventMessageFile subkey. 
    vcom.GetModulePathW( L'cwsvc.exe', Path );
    Len := Str.LengthW( Path );
    IF Len < SIZE( Path ) DIV SIZE( WCHAR ) THEN
      Path[ Len ] := WCHAR( 0 ); // append second trailing zero
    ELSE
      windows.SetLastError( winerror.ERROR_INSUFFICIENT_BUFFER );
    END;
    Result := winreg.RegSetValueExW( HKey, L'EventMessageFile', 0, windows.REG_EXPAND_SZ, ADR( Path ), ( Str.LengthW( Path ) + 1 ) * SIZE( WCHAR ));
    IF Result <> winerror.ERROR_SUCCESS THEN
      GOTO Fail;
    END;
 
    // Set the supported event types in the TypesSupported subkey. 
    EventTypeData := windows.EVENTLOG_ERROR_TYPE OR windows.EVENTLOG_WARNING_TYPE OR windows.EVENTLOG_INFORMATION_TYPE; 
    Result := winreg.RegSetValueExW( HKey, L'TypesSupported', 0, windows.REG_DWORD, ADR( EventTypeData ), SIZE( windows.DWORD ));
    IF Result <> winerror.ERROR_SUCCESS THEN
      GOTO Fail;
    END;

    HEventSource := windows.RegisterEventSourceW( NIL, ADR( vsvc_def.defaultIPCSvcDisplayName ));
    IF HEventSource = NIL THEN
      GOTO Fail;
    END;

    windows.SetLastError( winerror.ERROR_SUCCESS );

  Fail:
    Result := windows.GetLastError();
    IF HKey <> NIL THEN
      winreg.RegCloseKey( HKey );
    END;
    RETURN Result;
  END CreateEventLogSource;

(*---------------------------------------------------------------------------*)

BEGIN
  HEventSource := NIL;
  WITH ServiceStatus DO
    dwServiceType             := windows.SERVICE_WIN32; 
    dwCurrentState            := winsvc.SERVICE_STOPPED; 
    dwControlsAccepted        := winsvc.SERVICE_ACCEPT_STOP OR winsvc.SERVICE_ACCEPT_PAUSE_CONTINUE; 
    dwWin32ExitCode           := 0; 
    dwServiceSpecificExitCode := 0; 
    dwCheckPoint              := 0; 
    dwWaitHint                := 10000; 
  END;
  PLicenceEnumerator := NIL;
  PCWServer := NIL;
  PIPCServer := NIL;
END CService;

(*===========================================================================*)

TYPE
  TDispatcherTable = ARRAY [0..1] OF winsvc.SERVICE_TABLE_ENTRYW;

VAR
  DispatcherTable  : TDispatcherTable;

PROCEDURE RunService();
VAR
  MaximalWaitTime : CARDINAL;
BEGIN
  DispatcherTable[0].lpServiceName := ADR( vsvc_def.defaultIPCSvcName );
  DispatcherTable[0].lpServiceProc := winsvc.PSERVICE_MAIN_FUNCTIONW( ServiceMain );
  DispatcherTable[1].lpServiceName := NIL;
  DispatcherTable[1].lpServiceProc := NIL;

  IF winsvc.StartServiceCtrlDispatcherW( winsvc.PSERVICE_TABLE_ENTRYW( ADR( DispatcherTable ))) = windows.True THEN
    // code for SAFETY
    // successfully done, wait to allow the process exit gracefully
    MaximalWaitTime := maximalWaitTime;
    LOOP
      IF vwthread.DefaultDispatcherExists() THEN
        windows.Sleep( 10 );
      ELSE
        EXIT;
      END;
      DEC( MaximalWaitTime, 10 );
      IF MaximalWaitTime = 0 THEN
        EXIT;
      END;
    END; // LOOP
  END;
END RunService;

(*---------------------------------------------------------------------------*)

TYPE
  TParamStringA       = ARRAY[0..255] OF CHAR;
  TPParamStringA      = POINTER TO TParamStringA;
  TParamStringArrayA  = ARRAY [0..0] OF TPParamStringA;
  TPParamStringArrayA = POINTER TO TParamStringArrayA;

CONST
  // actions
  acCreate = 0;
  acDelete = 1;
  acRun    = 2;
  acStop   = 3;
  acInfo   = 4;
  acQuiet  = 31;

(*# save, call( prefix=>cdecl,
                c_conv=>on ) *)
PROCEDURE main( argc : INTEGER; argp : TPParamStringArrayA; enpv : TPParamStringArrayA );
LABEL
  End, Error;
VAR
  Action       : BITSET;
  ErrOutF      : windows.HANDLE;
  i            : INTEGER;
  Message      : vcom.TString255;
  DescriptionW : vcom.TString255W;
  Result       : windows.DWORD;
  SelfEXEPath  : FIO.PathStrW;
  String       : vcom.TString32;

 (*----------*)

  PROCEDURE WrLn();
  BEGIN
    FIO.WrLnA( ErrOutF );
  END WrLn;

(*----------*)

  (*%F UNICODE *)
  PROCEDURE WrStr( _String : ARRAY OF TCHAR );
  (*%E UNICODE *)
  (*%T UNICODE *)
  PROCEDURE WrStr( String : ARRAY OF TCHAR );
  (*%E UNICODE *)
  VAR
    AString : vcom.TString255A;
    l : CARDINAL;
  (*%F UNICODE *)
    String : vcom.TString255W;
  (*%E UNICODE *)
  BEGIN
  (*%F UNICODE *)
    Str.A2U( _String, String );
  (*%E UNICODE *)
    l := Str.LengthW( String );
    IF l = 0 THEN
      RETURN;
    END;
    l := winnls.WideCharToMultiByte( wincon.GetConsoleOutputCP(),
                                     0,
                                     ADR( String ), l,
                                     ADR( AString ), SIZE( AString ), NIL, NIL );
    IF l <= SIZE( AString ) THEN
      AString[l] := CHAR(0);
    END;
    FIO.WrStrA( ErrOutF, AString );
  END WrStr;

(*----------*)

BEGIN
  Result := 0;
  ErrOutF := windows.GetStdHandle( windows.STD_ERROR_HANDLE );

  IF argc = 1 THEN
    // command line contains name of EXE only -- this is normal service run
    PService := NIL;
    RunService();
    GOTO End;
  ELSE
    vcom.GetModulePathW( L'cwsvc.exe', SelfEXEPath );
  END;

  Action := {};
  FOR i := 1 TO argc - 1 DO
    IF ( argp^[i]^[0] = C'/' ) OR ( argp^[i]^[0] = C'-' ) THEN
      CASE argp^[i]^[1] OF
      | C'c' :
        IF acInfo IN Action THEN
          WrStr( 'error: -c option cannot be used together with -i option' ); WrLn();
          GOTO Error;
        ELSIF acDelete IN Action THEN
          WrStr( 'error: -c option cannot be used together with -d option' ); WrLn();
          GOTO Error;
        END;
        Action := Action + {acCreate};
      | C'd' :
        IF acInfo IN Action THEN
          WrStr( 'error: -d option cannot be used together with -i option' ); WrLn();
          GOTO Error;
        ELSIF {acCreate, acRun} * Action <> {} THEN
          WrStr( 'error: -d option cannot be used together with -[cr] options' ); WrLn();
          GOTO Error;
        END;
        Action := Action + {acDelete};
      | C'h', C'?' :
        GOTO Error;
      // | 'i' :
      //   IF Action <> {} THEN
      //     WrStr( 'error: -i option cannot be used together with -[cdrs] option' ); WrLn();
      //     GOTO Error;
      //   END;
      //   Action := Action + {acInfo};
      | C'q' :
        INCL( Action, acQuiet );
      | C'r' :
        IF acInfo IN Action THEN
          WrStr( 'error: -r option cannot be used together with -i option' ); WrLn();
          GOTO Error;
        ELSIF acDelete IN Action THEN
          WrStr( 'error: -r option cannot be used together with -d option' ); WrLn();
          GOTO Error;
        END;
        Action := Action + {acRun};
      | C's' :
        IF acInfo IN Action THEN
          WrStr( 'error: -s option cannot be used together with -i option' ); WrLn();
          GOTO Error;
        END;
        Action := Action + {acStop};
      ELSE
        Str.CopyFromA( String, argp^[i]^ );
        WrStr( 'error: unknown option: ' ); WrStr( String ); WrLn();
        GOTO Error;
      END;
    ELSE
      Str.CopyFromA( String, argp^[i]^ ); String[1] := 0C;
      WrStr( 'error: bad character: ' ); WrStr( String ); WrLn();
      GOTO Error;
    END;
  END;

  IF acStop IN Action THEN    
    Result := vsvc.StopDefaultService( vsvc_def.defaultStartStopTimeout );
    IF {acQuiet} * Action = {} THEN
      vcom.GetErrorMessage( Result, Message );
      WrStr( 'STOP   result: ' ); WrStr( Message ); WrLn();
    END;
  END;
  IF acDelete IN Action THEN
    Result := vsvc.StopAndDeleteDefaultService( vsvc_def.defaultStartStopTimeout );
    IF {acQuiet} * Action = {} THEN
      vcom.GetErrorMessage( Result, Message );
      WrStr( 'DELETE result: ' ); WrStr( Message ); WrLn();
    END;
  END;
  IF acCreate IN Action THEN
    Str.CopyToU( DescriptionW, cw_ipc_.cwServiceDescription );
    IF acRun IN Action THEN
      Result := vsvc.CreateAndStartDefaultService( SelfEXEPath, DescriptionW, vsvc_def.defaultStartStopTimeout );
    ELSE
      Result := vsvc.CreateDefaultService( SelfEXEPath, DescriptionW );
    END;
    IF {acQuiet} * Action = {} THEN
      vcom.GetErrorMessage( Result, Message );
      WrStr( 'CREATE result: ' ); WrStr( Message ); WrLn();
    END;
  END;
  IF acRun IN Action THEN
    Result := vsvc.StartDefaultService( vsvc_def.defaultStartStopTimeout );
    IF {acQuiet} * Action = {} THEN
      vcom.GetErrorMessage( Result, Message );
      WrStr( 'RUN    result: ' ); WrStr( Message ); WrLn();
    END;
  END;
  GOTO End;

Error:
  IF acQuiet IN Action THEN
    GOTO End;
  END;

  WrLn();
  WrStr( 'Control Web IPC Service control utility, (c) Moravian Instruments 1992-2003' ); WrLn();
  WrStr( 'Usage: cwsvc [-cdrs] [-h] [-q]' ); WrLn();
  WrStr( '  -c  creates service' ); WrLn();
  WrStr( '  -d  deletes service' ); WrLn();
  WrStr( '  -h  shows this help' ); WrLn();
  //WrStr( '  -i             defines configuration file' ); WrLn();
  WrStr( '  -q  forces cwsvc to run quietly' ); WrLn();
  WrStr( '  -r  starts service' ); WrLn();
  WrStr( '  -s  stops service'); WrLn();

End:
  IF ErrOutF <> NIL THEN
    windows.CloseHandle( ErrOutF );
  END;
  windows.ExitProcess( Result );

END main;
(*# restore *)

(*===========================================================================*)

BEGIN
END cwsvc.