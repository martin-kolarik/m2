IMPLEMENTATION MODULE Service;

(*================================================================================*)

FROM Debug IMPORT
   Assertion;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   windows,
   winerror,
   winsvc;
  
IMPORT
   Log,
   maps,
   msghandler,
   msgqueuethread,
   Texts,
   Resources,
   Strings;

(*===========================================================================*)

VAR
   PR : POINTER TO Resources.CResources := NIL;

(*---------------------------------------------------------------------------*)
  
PROCEDURE R() : POINTER TO Resources.CResources;
BEGIN
   IF PR = NIL THEN
      NEW( PR );
      PR^.LoadRES2( EMIT( %dll ), L"Service.Texts" );
   END;
   RETURN PR;
END R;

(*===========================================================================*)

CLASS IMPLEMENTATION AService;

(*---------------------------------------------------------------------------*)
  
   LOCAL PROCEDURE SetServiceState( ServiceState : TServiceState; ErrorCode : CARDINAL ) : BOOLEAN;
   BEGIN
      WITH ServiceStatus DO
         IF windows.DWORD( ServiceState ) = ServiceStatus.dwCurrentState THEN
            INC( dwCheckPoint );
         ELSE
            dwCurrentState := ServiceState; 
            dwCheckPoint   := 0;
         END;
         dwWaitHint      := 10000; 
         dwWin32ExitCode := ErrorCode;
      END; // WITH
      IF winsvc.SetServiceStatus( StatusHandle, ADR( ServiceStatus )) = windows.True THEN
         RETURN TRUE;
      ELSE
         LogEvent( windows.GetLastError(), OAsz( R()^[Texts._SetServiceStatusFailed] ));
         RETURN FALSE;
      END;
   END SetServiceState;

(*---------------------------------------------------------------------------*)

   LOCAL PROCEDURE RequestAdditionalTime( TimeMS : CARDINAL );
   BEGIN
      SetServiceState( TServiceState( ServiceStatus.dwCurrentState ), TimeMS );
   END RequestAdditionalTime;

(*---------------------------------------------------------------------------*)

  LOCAL PROCEDURE LogEvent( ErrorCode : CARDINAL; CONST ErrorText : ARRAY OF WCHAR ); // ErrorCode -1 means SUCCESS but with dlcError verbosity
  VAR
    DebugLevel : Log.TDebugLevel;
    LocalErrorText : ARRAY [0..255] OF WCHAR;
  BEGIN
    IF ErrorCode = winerror.ERROR_SUCCESS THEN
      DebugLevel := Log.dlcInfo;
    ELSE
      DebugLevel := Log.dlcError;
    END;
    IF ( ErrorCode = 0 ) OR ( ErrorCode = -1 ) THEN
      Log.logger()^.LogS( DebugLevel, L"SVC", ErrorText );
    ELSE
      Strings.FromErrorW( ErrorCode, OUT LocalErrorText );
      Log.logger()^.LogSSS( DebugLevel, L"SVC", ErrorText, L": ", LocalErrorText );
    END;
  END LogEvent;

(*---------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnPause();
   BEGIN
      SetServiceState( ssPaused, 0 );
   END OnPause;

(*---------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnContinue();
   BEGIN
      SetServiceState( ssRunning, 0 );
   END OnContinue;

(*---------------------------------------------------------------------------*)

BEGIN
   WITH ServiceStatus DO
      dwServiceType := windows.SERVICE_WIN32; 
      dwCurrentState := winsvc.SERVICE_STOPPED; 
      dwControlsAccepted := winsvc.SERVICE_ACCEPT_STOP OR winsvc.SERVICE_ACCEPT_PAUSE_CONTINUE; 
      dwWin32ExitCode := 0; 
      dwServiceSpecificExitCode := 0; 
      dwCheckPoint := 0; 
      dwWaitHint := 10000; 
   END;
   StatusHandle := NIL;
END AService;

(*===========================================================================*)

VAR
   Services : maps.CStringMap;

(*# save, call( o_a_size=>off, convention=>stdcall ) *)

PROCEDURE ControlHandlerEx( dwControl : CARDINAL; dwEventType : CARDINAL; lpEventData : ADDRESS; lpContext : ADDRESS ) : CARDINAL;
LABEL
   Fail;
VAR
   _Service : TPService := lpContext;
BEGIN
   CASE dwControl OF
   | winsvc.SERVICE_CONTROL_CONTINUE :
      IF NOT _Service^.SetServiceState( ssContinuePending, 0 ) THEN
         GOTO Fail;
      END;
      _Service^.OnContinue();
      _Service^.LogEvent( -1, OAsz( R()^[Texts._ServiceContinued] ));

   // | winsvc.SERVICE_CONTROL_INTERROGATE : -- solved in ELSE of CASE
   //  SetServiceState( ServiceStatus.dwCurrentState, 0 );

   | winsvc.SERVICE_CONTROL_PAUSE :
      IF NOT _Service^.SetServiceState( ssPausePending, 0 ) THEN
         GOTO Fail;
      END;
      _Service^.OnPause();
      _Service^.LogEvent( -1, OAsz( R()^[Texts._ServicePaused] ));

   | winsvc.SERVICE_CONTROL_SHUTDOWN, winsvc.SERVICE_CONTROL_STOP :
      _Service^.SetServiceState( ssStopPending, 0 );
      _Service^.OnStop();
      _Service^.LogEvent( -1, OAsz( R()^[Texts._ServiceStopped] ));
    
   ELSE
      _Service^.SetServiceState( TServiceState( _Service^.ServiceStatus.dwCurrentState ), 0 );
   END; // CASE
   RETURN winerror.ERROR_SUCCESS;

Fail:
   _Service^.OnStop();
   _Service^.SetServiceState( ssStopped, 0 );
   RETURN winerror.ERROR_SUCCESS;
END ControlHandlerEx;

(*---------------------------------------------------------------------------*)

TYPE
  TParamStringArrayW  = ARRAY [0..0] OF PWCHAR;
  TPParamStringArrayW = POINTER TO TParamStringArrayW;

PROCEDURE ServiceMain( argc : INTEGER; argv : TPParamStringArrayW );
VAR
   _Service : TPService;
BEGIN
   IF argc = 0 THEN
      ASSERT( FALSE );
      RETURN;

   ELSIF Services.GetOA( OAsz( argv^[0] ), OUT _Service ) THEN // not known service

      _Service^.StatusHandle := winsvc.RegisterServiceCtrlHandlerExW( argv^[0], winsvc.LPHANDLER_FUNCTION_EX( ControlHandlerEx ), _Service );
      IF _Service^.StatusHandle = winsvc.SERVICE_STATUS_HANDLE( NIL ) THEN
         _Service^.LogEvent( windows.GetLastError(), OAsz( R()^[Texts._RegisterServiceCtrlHandlerFailed] ));
         RETURN;
      ELSIF NOT _Service^.SetServiceState( ssStartPending, 0 ) THEN
         RETURN;
      END;

      _Service^.OnStart();
      _Service^.LogEvent( -1, OAsz( R()^[Texts._ServiceIsStartedSuccessfully] ));

   // ELSE leave not starting and timeout to OS
   END;
END ServiceMain;

(*# restore *)

(*================================================================================*)

PROCEDURE Run( _Services : ARRAY OF TPService; WaitResult : BOOLEAN; TimeoutMS : CARDINAL ) : Sync.TAsyncResult; // called from service's EXE main()
TYPE
   TPDispatcherTable = POINTER TO ARRAY [0..0] OF winsvc.SERVICE_TABLE_ENTRYW;
VAR
   DispatcherTable : TPDispatcherTable;
   i : CARDINAL;
   res : windows.BOOL;
BEGIN
   IF HIGH( _Services ) < 0 THEN
      RETURN Sync.arCannotStart;
   END;

   // allocate dispatcher table
   ALLOCATE( DispatcherTable, ( HIGH( _Services ) + 2 ) * SIZE( winsvc.SERVICE_TABLE_ENTRYW ));
   // fill up it
   FOR i := 0 TO HIGH( _Services ) DO

      Services.AddOA( OAsz( _Services[i]^.Name ), _Services[i] );

      DispatcherTable^[i].lpServiceName := _Services[i]^.Name;
      DispatcherTable^[i].lpServiceProc := winsvc.LPSERVICE_MAIN_FUNCTIONW( ServiceMain );

   END; // FOR;
   DispatcherTable^[HIGH(_Services)+1].lpServiceName := NIL;
   DispatcherTable^[HIGH(_Services)+1].lpServiceProc := NIL;

   // start them
   res := winsvc.StartServiceCtrlDispatcherW( winsvc.PSERVICE_TABLE_ENTRYW( DispatcherTable ));;

   // and cleanup
   DISPOSE( DispatcherTable );

   // TODO implement wait

   IF res = windows.True THEN
      RETURN Sync.arPending;
   ELSE
      RETURN Sync.arCannotStart;
   END;
END Run;

(*================================================================================*)

BEGIN
FINALLY
   IF PR <> NIL THEN
      DISPOSE( PR );
   END;
END Service.