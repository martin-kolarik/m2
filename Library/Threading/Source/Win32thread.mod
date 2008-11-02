IMPLEMENTATION MODULE Win32thread;

FROM Debug IMPORT
   Assertion;

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
  
   PUBLIC FINAL PROCEDURE Win32Thread.Run( Wait : BOOLEAN );
   BEGIN
      IF _HThread <> NIL THEN
         RETURN;
      END;
      _RunLock := 0;
      _HThread := windows.CreateThread( NIL, STACK_SIZE, windows.PTHREAD_START_ROUTINE( Win32_thread ), ADR( SELF ), 0, ADR( _Thread ));
      WHILE Wait AND ( Sync.IGet( REF _RunLock ) = 0 ) DO
         Sync.Sleep( 0 );
      END;
   END Win32Thread.Run;
  
  PUBLIC FINAL PROCEDURE Win32Thread.Stop( Wait : BOOLEAN );
  VAR
    Result : Sync.TAsyncResult;
  BEGIN
    IF _HThread = NIL THEN
      RETURN;
    END;
    _HExit.Signal();
    IF Wait THEN
      Result := sync.RawWait( _HThread, 10 * sync.FORSAFETY );
      ASSERT( Result <> Sync.arTimeout );
    END;
    IF _HThread <> NIL THEN
      windows.CloseHandle( _HThread );
    END;
    _Thread := 0;
    _HThread := NIL;
    IF _WMsg = 1 THEN
      _WMsg := -1;
    END;
  END Win32Thread.Stop;
  
   PUBLIC FINAL PROCEDURE WaitStop( Timeout : CARDINAL ) : sync.TAsyncResult;
   BEGIN
      RETURN sync.RawWait( _HThread, Timeout );
   END WaitStop;

   PUBLIC FINAL PROCEDURE RunWithRunnable( Runnable : OSALthread.TPRunnable );
   BEGIN
      ASSERT( _Runnable = NIL );
      _Runnable := Runnable;
      Run( FALSE );
   END RunWithRunnable;

   INTERNAL VIRTUAL PROCEDURE OnRun() : CARDINAL;
   BEGIN
      RETURN 0;
   END OnRun;

   LOCAL PROCEDURE Exec() : CARDINAL;
   VAR
     msg : windows.MSG;
   BEGIN
     IF _WMsg = -1 THEN
        windows.PeekMessage( ADR( msg ), NIL, 0, 0, windows.PM_NOREMOVE );
        _WMsg := 1;
     END;
     Sync.IExchg( REF _RunLock, 1 );
     IF _Runnable = NIL THEN
       RETURN OnRun();
     ELSE
       RETURN _Runnable^.OnRun();
     END;
   END Exec;

   VIRTUAL FINALLY Win32Thread();
   BEGIN
      Stop( FALSE );
   END Win32Thread;

BEGIN
   _RunLock := 0;
   _Thread := 0;
   _HThread := NIL;
   _HExit.Init( Sync.stEvent, L"", FALSE );
   _WMsg := 0;
   _Runnable := NIL;
END Win32Thread;

END Win32thread.