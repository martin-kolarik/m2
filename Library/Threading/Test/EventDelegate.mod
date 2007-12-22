MODULE eventdelegate;

IMPORT
  sync,
  threadpool,
  windows;
  
VAR
  Count : CARDINAL := 0;
  
CLASS CDelegate( threadpool.APoolDelegate );
  LOCAL VIRTUAL PROCEDURE OnHandle( Result : sync.TAsyncResult; PoolHandle, UserId : PTR );
END CDelegate;
  
CLASS IMPLEMENTATION CDelegate;

  LOCAL VIRTUAL PROCEDURE OnHandle( Result : sync.TAsyncResult; PoolHandle, UserId : PTR );
  BEGIN
    windows.InterlockedIncrement( REF Count );
  END OnHandle;
  
END CDelegate;

PROCEDURE Test();
VAR
  DLG : CDelegate;
  EA : ARRAY [0..1499] OF windows.HANDLE;
  i, j : CARDINAL;
  msg : windows.MSG;
  PH : ARRAY [0..14999] OF windows.HANDLE;
  TP : threadpool.CThreadPool;
BEGIN
  FOR i := 0 TO 1499 DO
    EA[i] := windows.CreateEvent( NIL, windows.True, windows.False, NIL );

    // 1.
    // TP.WaitHandle( NIL, i, windows.INFINITE, EA[i], OUT PH[i] );

    // 2.
    FOR j := 0 TO 9 DO
      TP.WaitHandle( ADR( DLG ), i, windows.INFINITE, TRUE, EA[i], OUT PH[i*10+j] );
    END;
  END; // FOR

  // windows.Sleep( 2000 );

  // 1.
  // TP.FINALLY();  

  // 2.
  FOR i := 1499 TO 0 BY -1 DO
    windows.SetEvent( EA[i] );
  END; // FOR

  // 3.
  // FOR i := 1499 TO 0 BY -1 DO
  //   TP.Abort( PH[i] );
  // END; // FOR

  // 4.
  // TP.CompletionInOwningThread := TRUE;
  // FOR i := 14999 TO 0 BY -1 DO
  //   TP.Abort( PH[i] );
  // END; // FOR

  windows.Sleep( 1000 );

  FOR i := 0 TO 1499 DO
    windows.CloseHandle( EA[i] );
  END;

  WHILE windows.GetMessage( ADR( msg ), NIL, 0, 0 ) = windows.True DO
    windows.DispatchMessage( ADR( msg ));
  END; // WHILE
  
  TP.FINALLY();
END Test;

#save, call( convention => cdecl )
PROCEDURE wmain05() : INTEGER;
#restore
BEGIN
  Test();
  RETURN 0;
END wmain05;

END eventdelegate.