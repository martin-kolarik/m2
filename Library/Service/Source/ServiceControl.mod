IMPLEMENTATION MODULE ServiceControl;

(*===========================================================================*)

IMPORT
  windows,
  winerror,
  winsvc;

(*===========================================================================*)

PROCEDURE CheckPresence( CONST ServiceName : ARRAY OF WCHAR; OUT Error : CARDINAL ) : BOOLEAN;
LABEL
  Fail;
VAR
  HSCManager : winsvc.SC_HANDLE := NIL;
  HService : winsvc.SC_HANDLE := NIL;
BEGIN
  HSCManager := winsvc.OpenSCManagerW( NIL, NIL,
                  winsvc.SC_MANAGER_CONNECT OR
                  winsvc.SC_MANAGER_ENUMERATE_SERVICE OR
                  winsvc.SC_MANAGER_QUERY_LOCK_STATUS );
  IF HSCManager = NIL THEN
    GOTO Fail;
  END;
  HService := winsvc.OpenServiceW(
                HSCManager,
                windows.PWSTR( ADR( ServiceName )),
                winsvc.SERVICE_START OR winsvc.SERVICE_QUERY_STATUS );
  IF HService = NIL THEN
    GOTO Fail;
  END;
  windows.SetLastError( winerror.ERROR_SUCCESS );

Fail:
  Error := windows.GetLastError();
  IF HService <> NIL THEN
    winsvc.CloseServiceHandle( HService );
  END;
  IF HSCManager <> NIL THEN
    winsvc.CloseServiceHandle( HSCManager );
  END;
  RETURN Error = 0;
END CheckPresence;

(*---------------------------------------------------------------------------*)

PROCEDURE Create( CONST ServiceName, ServiceDisplayName, ServiceEXEPath, DependsOn, Description : ARRAY OF WCHAR; OUT Error : CARDINAL ) : BOOLEAN;
LABEL
  Fail, IsRun;
CONST
  NETWORK_SERVICE = L"NT AUTHORITY\NetworkService";
VAR
  HSCManager : winsvc.SC_HANDLE := NIL;
  HService : winsvc.SC_HANDLE := NIL;
BEGIN
  HSCManager := winsvc.OpenSCManagerW( NIL, NIL,
                  winsvc.SC_MANAGER_CONNECT OR
                  winsvc.SC_MANAGER_CREATE_SERVICE OR
                  winsvc.SC_MANAGER_ENUMERATE_SERVICE OR
                  winsvc.SC_MANAGER_QUERY_LOCK_STATUS );
  IF HSCManager = NIL THEN
    GOTO Fail;
  END;

  HService := winsvc.CreateServiceW(
                HSCManager,
                windows.PWSTR( ADR( ServiceName )),
                windows.PWSTR( ADR( ServiceDisplayName )),
                winsvc.SERVICE_ALL_ACCESS,
                windows.SERVICE_WIN32_OWN_PROCESS OR windows.SERVICE_INTERACTIVE_PROCESS,
                windows.SERVICE_AUTO_START, // windows.SERVICE_DEMAND_START,
                windows.SERVICE_ERROR_NORMAL,
                windows.PWSTR( ADR( ServiceEXEPath )),
                NIL,
                NIL,
                windows.PWSTR( ADR( DependsOn )),
                NIL,
                NIL
              );
  IF HService = NIL THEN
    GOTO Fail;
  END;
  windows.SetLastError( winerror.ERROR_SUCCESS );

Fail:
  Error := windows.GetLastError();
  IF HService <> NIL THEN
    winsvc.CloseServiceHandle( HService );
  END;
  IF HSCManager <> NIL THEN
    winsvc.CloseServiceHandle( HSCManager );
  END;
  RETURN Error = 0;
END Create;

(*---------------------------------------------------------------------------*)

PROCEDURE Start( CONST ServiceName : ARRAY OF WCHAR; CONST Parameter : ARRAY OF WCHAR; WaitResult : BOOLEAN; TimeoutMS : CARDINAL; OUT Error : CARDINAL ) : Sync.TAsyncResult;
LABEL
  Fail, IsRun;
VAR
  CheckDelay : CARDINAL;
  HSCManager : winsvc.SC_HANDLE := NIL;
  HService : winsvc.SC_HANDLE := NIL;
  PParameter : PWCHAR := ADR( Parameter );
  ServiceStatus : winsvc.SERVICE_STATUS;
  Timeout : INTEGER;
  EnterWaitLoop : BOOLEAN;
BEGIN
  HSCManager := winsvc.OpenSCManagerW( NIL, NIL,
                  winsvc.SC_MANAGER_CONNECT OR
                  winsvc.SC_MANAGER_ENUMERATE_SERVICE OR
                  winsvc.SC_MANAGER_QUERY_LOCK_STATUS );
  IF HSCManager = NIL THEN
    Error := windows.GetLastError();
    IF Error = winerror.ERROR_SUCCESS THEN
      Error := winerror.ERROR_ACCESS_DENIED;
    END;
    GOTO Fail;
  END;
  HService := winsvc.OpenServiceW(
                HSCManager,
                windows.PWSTR( ADR( ServiceName )),
                winsvc.SERVICE_START OR winsvc.SERVICE_QUERY_STATUS );
  IF HService = NIL THEN
    Error := windows.GetLastError();
    IF Error = winerror.ERROR_SUCCESS THEN
      Error := winerror.ERROR_SERVICE_DOES_NOT_EXIST;
    END;
    GOTO Fail;
  END;

  // query state
  IF winsvc.QueryServiceStatus( HService, ADR( ServiceStatus )) = windows.True THEN
    CASE ServiceStatus.dwCurrentState OF
    | winsvc.SERVICE_START_PENDING,
      winsvc.SERVICE_CONTINUE_PENDING :
      EnterWaitLoop := TRUE;
    | winsvc.SERVICE_RUNNING :
      GOTO IsRun;
    ELSE
      EnterWaitLoop := FALSE;
      // try to start service
    END;
  ELSE
    Error := windows.GetLastError();
    GOTO Fail;
  END;
  // start service
  IF EnterWaitLoop OR ( winsvc.StartServiceW( HService, 1, windows.PPCWSTR( ADR( PParameter ))) = windows.True ) THEN

      IF NOT WaitResult THEN
         Error := winerror.ERROR_IO_PENDING;
         GOTO Fail;
      END;
  
    // wait for its start
    Timeout := TimeoutMS;
    CheckDelay := Timeout DIV 10;
    IF CheckDelay > 5000 THEN
      CheckDelay := 5000;
    END;
    LOOP
      IF winsvc.QueryServiceStatus( HService, ADR( ServiceStatus )) <> windows.True THEN
        Error := windows.GetLastError();
        GOTO Fail;
      END;
      CASE ServiceStatus.dwCurrentState OF
      | winsvc.SERVICE_START_PENDING,
        winsvc.SERVICE_CONTINUE_PENDING :
      | winsvc.SERVICE_RUNNING :
        EXIT;
      ELSE
        Error := winerror.ERROR_SERVICE_NOT_ACTIVE;
        GOTO Fail;
      END;

      windows.Sleep( CheckDelay ); 
      DEC( Timeout, CheckDelay );
      IF Timeout <= 0 THEN
        Error := winerror.ERROR_SERVICE_REQUEST_TIMEOUT;
        GOTO Fail;
      END;
    END;

  ELSE
    Error := windows.GetLastError();
    CASE Error OF
    | winerror.ERROR_SERVICE_ALREADY_RUNNING :
    ELSE
      GOTO Fail;  
    END;
  END;

IsRun:
  Error := winerror.ERROR_SUCCESS;

Fail:
  IF HService <> NIL THEN
    winsvc.CloseServiceHandle( HService );
  END;
  IF HSCManager <> NIL THEN
    winsvc.CloseServiceHandle( HSCManager );
  END;
  CASE Error OF
  | winerror.ERROR_SUCCESS :
    RETURN Sync.arCompleted;
  | winerror.ERROR_IO_PENDING :
    RETURN Sync.arPending;
  | winerror.ERROR_SERVICE_REQUEST_TIMEOUT :
    RETURN Sync.arTimeout;
  ELSE
    RETURN Sync.arCannotStart;
  END; // CASE
END Start;

(*---------------------------------------------------------------------------*)

PROCEDURE Stop( CONST ServiceName : ARRAY OF WCHAR; WaitResult : BOOLEAN; StopTimeoutMS : CARDINAL; OUT Error : CARDINAL ) : Sync.TAsyncResult;
LABEL
  Fail, IsStopped;
VAR
  CheckDelay : CARDINAL;
  HSCManager : winsvc.SC_HANDLE := NIL;
  HService : winsvc.SC_HANDLE := NIL;
  ServiceStatus : winsvc.SERVICE_STATUS;
  Timeout : INTEGER;
  EnterWaitLoop : BOOLEAN;
BEGIN
  HSCManager := winsvc.OpenSCManagerW( NIL, NIL,
                  winsvc.SC_MANAGER_CONNECT OR
                  winsvc.SC_MANAGER_ENUMERATE_SERVICE OR
                  winsvc.SC_MANAGER_QUERY_LOCK_STATUS );
  IF HSCManager = NIL THEN
    Error := windows.GetLastError();
    GOTO Fail;
  END;
  HService := winsvc.OpenServiceW(
                HSCManager,
                windows.PWSTR( ADR( ServiceName )),
                winsvc.SERVICE_STOP OR winsvc.SERVICE_QUERY_STATUS );
  IF HService = NIL THEN
    Error := windows.GetLastError();
    GOTO Fail;
  END;

  // query state
  IF winsvc.QueryServiceStatus( HService, ADR( ServiceStatus )) = windows.True THEN
    CASE ServiceStatus.dwCurrentState OF
    | winsvc.SERVICE_STOP_PENDING :
      EnterWaitLoop := TRUE;
    | winsvc.SERVICE_STOPPED :
      GOTO IsStopped;
    ELSE
      EnterWaitLoop := FALSE;
      // try to stop service
    END;
  ELSE
    Error := windows.GetLastError();
    GOTO Fail;
  END;
  // start service
  IF EnterWaitLoop OR ( winsvc.ControlService( HService, winsvc.SERVICE_CONTROL_STOP, ADR( ServiceStatus )) = windows.True ) THEN

      IF NOT WaitResult THEN
         Error := winerror.ERROR_IO_PENDING;
         GOTO Fail;
      END;
  
    // wait for its start
    Timeout := StopTimeoutMS;
    CheckDelay := Timeout DIV 10;
    IF CheckDelay > 5000 THEN
      CheckDelay := 5000;
    END;
    LOOP
      IF winsvc.QueryServiceStatus( HService, ADR( ServiceStatus )) <> windows.True THEN
        Error := windows.GetLastError();
        GOTO Fail;
      END;
      CASE ServiceStatus.dwCurrentState OF
      | winsvc.SERVICE_STOP_PENDING :
      | winsvc.SERVICE_STOPPED :
        EXIT;
      ELSE
        Error := winerror.ERROR_SERVICE_NOT_ACTIVE;
        GOTO Fail;
      END;

      windows.Sleep( CheckDelay ); 
      DEC( Timeout, CheckDelay );
      IF Timeout <= 0 THEN
        Error := winerror.ERROR_SERVICE_REQUEST_TIMEOUT;
        GOTO Fail;
      END;
    END;

  ELSE
    Error := windows.GetLastError();
    GOTO Fail;  
  END;

IsStopped:
  Error := winerror.ERROR_SUCCESS;

Fail:
  IF HService <> NIL THEN
    winsvc.CloseServiceHandle( HService );
  END;
  IF HSCManager <> NIL THEN
    winsvc.CloseServiceHandle( HSCManager );
  END;
  CASE Error OF
  | winerror.ERROR_SUCCESS :
    RETURN Sync.arCompleted;
  | winerror.ERROR_IO_PENDING :
    RETURN Sync.arPending;
  | winerror.ERROR_SERVICE_REQUEST_TIMEOUT :
    RETURN Sync.arTimeout;
  ELSE
    RETURN Sync.arCannotStart;
  END; // CASE
END Stop;

(*---------------------------------------------------------------------------*)

PROCEDURE Delete( CONST ServiceName : ARRAY OF WCHAR; OUT Error : CARDINAL ) : BOOLEAN;
LABEL
  Fail;
VAR
  HSCManager : winsvc.SC_HANDLE := NIL;
  HService : winsvc.SC_HANDLE := NIL;
BEGIN
  HSCManager := winsvc.OpenSCManagerW( NIL, NIL,
                  winsvc.SC_MANAGER_CONNECT OR
                  winsvc.SC_MANAGER_ENUMERATE_SERVICE OR
                  winsvc.SC_MANAGER_QUERY_LOCK_STATUS );
  IF HSCManager = NIL THEN
    GOTO Fail;
  END;

  HService := winsvc.OpenServiceW(
                 HSCManager,
                 windows.PWSTR( ADR( ServiceName )),
                 winsvc.SERVICE_QUERY_STATUS OR winsvc.SERVICE_ALL_ACCESS );
  IF HService = NIL THEN
    GOTO Fail;
  END;
  IF winsvc.DeleteService( HService ) <> windows.True THEN
    GOTO Fail;
  END;
  windows.SetLastError( winerror.ERROR_SUCCESS );

Fail:
  Error := windows.GetLastError();
  IF HService <> NIL THEN
    winsvc.CloseServiceHandle( HService );
  END;
  IF HSCManager <> NIL THEN
    winsvc.CloseServiceHandle( HSCManager );
  END;
  RETURN Error = 0;
END Delete;

(*===========================================================================*)

END ServiceControl.