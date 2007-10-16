IMPLEMENTATION MODULE threadWin32;

IMPORT
  windows;

TYPE
  TPWin32Thread = POINTER TO Win32Thread;

#save, call( convention => stdcall )
PROCEDURE Win32_thread( Thread : TPWin32Thread ) : windows.DWORD;
BEGIN
  RETURN Thread^.Exec();
END Win32_thread;
#restore

CLASS IMPLEMENTATION Win32Thread;

  PUBLIC VIRTUAL READONLY PROPERTY Win32Thread.Thread GET : CARDINAL;
  BEGIN
    RETURN _Thread;
  END Win32Thread.Thread;

  PUBLIC VIRTUAL PROPERTY Win32Thread.WithMessages GET : BOOLEAN;
  BEGIN
    RETURN _WMsg <> 0;
  END Win32Thread.WithMessages;
  
  PUBLIC VIRTUAL PROPERTY Win32Thread.WithMessages SET( Value : BOOLEAN );
  BEGIN
    IF ( _WMsg = 1 ) OR NOT Value THEN
      RETURN;
    END;
    _WMsg := -1;
    IF _Thread = 0 THEN
      RETURN;
    END;
    WHILE windows.PostThreadMessage( _Thread, windows.WM_USER, 0, 0 ) = 0 DO
      windows.Sleep( 0 );
    END; // WHILE
    _WMsg := 1;
  END Win32Thread.WithMessages;
  
  PUBLIC FINAL PROCEDURE Win32Thread.Run( Wait : BOOLEAN );
  BEGIN
    IF _HThread <> NIL THEN
      RETURN;
    END;
    sync.Reset( _HExit );
    _HThread := windows.CreateThread( NIL, 81920, Win32_thread, ADR( SELF ), 0, ADR( _Thread ));
    IF Wait THEN
      sync.Wait( _HExit, sync.INFINITE_TIME );
    END;
  END Win32Thread.Run;
  
  PUBLIC FINAL PROCEDURE Win32Thread.Stop( Wait : BOOLEAN );
  BEGIN
    IF _HThread = NIL THEN
      RETURN;
    END;
    sync.Signal( _HExit );
    IF Wait THEN
      sync.Wait( _HThread, sync.INFINITE_TIME );
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
      RETURN sync.Wait( _HThread, Timeout );
   END WaitStop;

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
    windows.PulseEvent( _HExit );
    RETURN OnRun();
  END Exec;

   VIRTUAL FINALLY Win32Thread();
   BEGIN
      Stop( FALSE );
      IF _HExit <> NIL THEN
        windows.CloseHandle( _HExit );
      END;
   END Win32Thread;

BEGIN
  _Thread := 0;
  _HThread := NIL;
  _HExit := windows.CreateEvent( NIL, windows.True, windows.False, NIL );
  _WMsg := 0;
END Win32Thread;

END threadWin32.