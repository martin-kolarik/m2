IMPLEMENTATION MODULE Win32thread;

FROM Debug IMPORT
   Assertion, LogAssertionW;

IMPORT
  windows,
  Sync;

CONST
  STACK_SIZE = 81920;

TYPE
  TPWin32Thread = POINTER TO Win32Thread;

#save, call( convention => stdcall )
PROCEDURE Win32_thread( Thread : TPWin32Thread ) : windows.DWORD;
BEGIN
  RETURN Thread^.Exec();
END Win32_thread;
#restore

CLASS IMPLEMENTATION Win32Thread;

  PUBLIC VIRTUAL READONLY PROPERTY Win32Thread.Id GET : PTR;
  BEGIN
    RETURN _Thread;
  END Win32Thread.Id;

  PUBLIC VIRTUAL READONLY PROPERTY Win32Thread.SelfContext GET : BOOLEAN;
  BEGIN
    RETURN _Thread = windows.GetCurrentThreadId();
  END Win32Thread.SelfContext;

  PUBLIC PROPERTY Win32Thread.WithMessages GET : BOOLEAN;
  BEGIN
    RETURN _WMsg <> 0;
  END Win32Thread.WithMessages;
  
  PUBLIC PROPERTY Win32Thread.WithMessages SET( Value : BOOLEAN );
  BEGIN
    IF ( _WMsg = 1 ) OR NOT Value THEN
      RETURN;
    END;
    _WMsg := -1;
    IF _Thread = 0 THEN
      RETURN;
    END;
    WHILE windows.PostThreadMessage( _Thread, windows.WM_USER, 0, 0 ) = 0 DO
      Sync.Sleep( 0 );
    END; // WHILE
    _WMsg := 1;
  END Win32Thread.WithMessages;
  
   PUBLIC FINAL PROCEDURE Win32Thread.Start( WaitRun : BOOLEAN ) : Sync.TAsyncResult;
   VAR
      Result : Sync.TAsyncResult;
   BEGIN
      IF _HThread <> NIL THEN
         RETURN Sync.arAlreadyPending;
      END;

      _RunLock.Reset();
      _HExit.Reset();
      _HThread := windows.CreateThread( NIL, STACK_SIZE, windows.PTHREAD_START_ROUTINE( Win32_thread ), ADR( SELF ), 0, ADR( _Thread ));
      IF WaitRun THEN
         Result := _RunLock.Wait( Sync.FORSAFETY );
      ELSE
         Result := Sync.arPending;
      END;
      ASSERTLOG( Result <> Sync.arTimeout );
      
      RETURN Result;
   END Win32Thread.Start;
  
   PUBLIC FINAL PROCEDURE Win32Thread.Stop( _WaitStop : BOOLEAN ) : Sync.TAsyncResult;
   VAR
      Result : Sync.TAsyncResult;
   BEGIN
      IF _HThread = NIL THEN
         RETURN Sync.arAlreadyCompleted;
      END;

      _HExit.Signal();
      IF _WaitStop THEN
         Result := WaitStop( Sync.FORSAFETY );
      ELSE
         Result := Sync.arPending;
      END;
      ASSERTLOG( Result <> Sync.arTimeout );

      RETURN Result;
   END Win32Thread.Stop;
  
   PUBLIC FINAL PROCEDURE WaitStop( Timeout : CARDINAL ) : Sync.TAsyncResult;
   VAR
      Result : Sync.TAsyncResult;
   BEGIN
      IF _HThread = NIL THEN
         RETURN Sync.arAlreadyCompleted;
      END;

      Result := sync.RawWait( _HThread, Timeout );

      windows.CloseHandle( _HThread );
      _Thread := 0;
      _HThread := NIL;
      _Runnable := NIL;
      IF _WMsg = 1 THEN
         _WMsg := -1;
      END;
      
      RETURN Result;
   END WaitStop;

   PUBLIC FINAL PROCEDURE RunWithRunnable( Runnable : OSALthread.TPRunnable ) : Sync.TAsyncResult;
   BEGIN
      IF _Runnable <> NIL THEN // already exists
         ASSERTLOG( FALSE );
         RETURN Sync.arAlreadyPending;
      END;
      _Runnable := Runnable;
      RETURN Start( TRUE );
   END RunWithRunnable;

   INTERNAL VIRTUAL PROCEDURE OnRun( CONST Helper : OSALthread.IRunnableHelper ) : CARDINAL;
   BEGIN
      RETURN 0;
   END OnRun;

   PUBLIC VIRTUAL PROCEDURE WaitForStopRequest( Timeout : CARDINAL ) : Sync.TAsyncResult; // arCompleted for Stop request
   CONST
      waitHandles = 1;
   VAR
      Status : CARDINAL;
      RawHandle : windows.HANDLE;
   BEGIN
      IF WithMessages THEN
         RawHandle := _HExit.RawHandle;
         Status := windows.MsgWaitForMultipleObjectsEx( waitHandles, ADR( RawHandle ), windows.INFINITE, windows.QS_ALLINPUT, windows.MWMO_INPUTAVAILABLE OR windows.MWMO_ALERTABLE );
      ELSE
         Status := windows.WaitForSingleObjectEx( _HExit.RawHandle, Timeout, windows.True );
      END;
   
      CASE Status OF
      | CARDINAL( windows.WAIT_FAILED ), windows.WAIT_ABANDONED_0 : // some handle failed, this MUST not occur
         Status := windows.GetLastError();
         ASSERTLOG( FALSE );
         RETURN sync.arAborted;

      //-----
      | windows.WAIT_OBJECT_0 : // graceful EXIT
         RETURN sync.arCompleted;

      //-----
      | windows.WAIT_OBJECT_0 + waitHandles : // a message detected
         RETURN Sync.arPending;

      //-----
      | windows.WAIT_IO_COMPLETION :
         RETURN sync.arNoData;

      //-----
      | windows.WAIT_TIMEOUT :
         RETURN sync.arTimeout;
      
      //-----
      ELSE
         Status := windows.GetLastError();
         ASSERTLOG( FALSE );
         RETURN sync.arAborted;
      END;
   END WaitForStopRequest;

   PUBLIC VIRTUAL PROCEDURE WaitForStopRequestAndSignal( CONST Signal : Sync.PSIGNAL; Timeout : CARDINAL ) : Sync.TAsyncResult; // arCompleted for Stop request, arPartCompleted for SIGNAL
   VAR
      signaled : CARDINAL;
   BEGIN
      RETURN WaitForStopRequestAndSignals( OA( 0, ADR( Signal )), Timeout, OUT signaled );
   END WaitForStopRequestAndSignal;

   PUBLIC VIRTUAL PROCEDURE WaitForStopRequestAndSignals( CONST Signal : ARRAY OF Sync.PSIGNAL; Timeout : CARDINAL; OUT IndexOfSignal : CARDINAL ) : Sync.TAsyncResult; // arCompleted for Stop request, arPartCompleted for SIGNAL
   VAR
      i : CARDINAL;
      Status : CARDINAL;
      WaitArray : ARRAY [0..windows.MAXIMUM_WAIT_OBJECTS-1] OF windows.HANDLE;
      WaitCount : CARDINAL := HIGH( Signal ) + 2; // +exit+1
   BEGIN
      IndexOfSignal := -1;
      IF HIGH( Signal ) > windows.MAXIMUM_WAIT_OBJECTS-2 THEN // -1-_HExit
         RETURN Sync.arCannotStart;
      END;
      
      WaitArray[0] := _HExit.RawHandle;
      FOR i := 0 TO HIGH( Signal ) DO
         WaitArray[i+1] := Signal[i]^.RawHandle;
      END; // FOR
      IF WithMessages THEN
         Status := windows.MsgWaitForMultipleObjectsEx( WaitCount, ADR( WaitArray ), Timeout, windows.QS_ALLINPUT, windows.MWMO_INPUTAVAILABLE OR windows.MWMO_ALERTABLE );
      ELSE
         Status := windows.WaitForMultipleObjectsEx( WaitCount, ADR( WaitArray ), windows.False, Timeout, windows.True );
      END;

      CASE Status OF
      | CARDINAL( windows.WAIT_FAILED ), windows.WAIT_ABANDONED_0 : // some handle failed, this MUST not occur
         Status := windows.GetLastError();
         ASSERTLOG( FALSE );
         RETURN sync.arAborted;

      //-----
      | windows.WAIT_OBJECT_0 : // graceful EXIT
         RETURN sync.arCompleted;

      //-----
      | windows.WAIT_IO_COMPLETION :
         RETURN sync.arNoData;

      //-----
      | windows.WAIT_TIMEOUT :
         RETURN sync.arTimeout;
      
      //-----
      ELSE // some handle signalized or aborted
         IF Status = windows.WAIT_OBJECT_0 + WaitCount THEN // a message detected
            RETURN Sync.arPending;
         ELSIF Status > windows.WAIT_ABANDONED_0 THEN
            IndexOfSignal := Status - windows.WAIT_ABANDONED_0 - 1; // exit handle is masked by -1
            RETURN Sync.arAborted;
         ELSE
            IndexOfSignal := Status - windows.WAIT_OBJECT_0 - 1; // exit handle is masked by -1
            RETURN Sync.arPartCompleted;
         END;

      //-----
      END;
   END WaitForStopRequestAndSignals;

   LOCAL PROCEDURE Exec() : CARDINAL;
   VAR
     msg : windows.MSG;
   BEGIN
     IF _WMsg = -1 THEN
        windows.PeekMessage( ADR( msg ), NIL, 0, 0, windows.PM_NOREMOVE );
        _WMsg := 1;
     END;
     _RunLock.Signal();
     IF _Runnable = NIL THEN
       RETURN OnRun( SELF );
     ELSE
       RETURN _Runnable^.OnRun( SELF );
     END;
   END Exec;

   VIRTUAL FINALLY Win32Thread();
   BEGIN
      Stop( FALSE );
   END Win32Thread;

BEGIN
   _RunLock.Init( Sync.stSpin, L"", FALSE );;
   _Thread := 0;
   _HThread := NIL;
   _HExit.Init( Sync.stEvent, L"", FALSE );
   _WMsg := 0;
   _Runnable := NIL;
END Win32Thread;

END Win32thread.