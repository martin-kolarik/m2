MODULE messagedelegate;

IMPORT
  msghandler,
  threadpool,
  windows;
  
VAR
  Count : CARDINAL := 0;
  
CLASS CDelegate( threadpool.CPoolDelegate );
  LOCAL VIRTUAL PROCEDURE OnMessage( Result : threadpool.TPoolResult; PoolHandle, UserId : PTR; CONST MSG : msghandler.IMessage );
END CDelegate;
  
CLASS IMPLEMENTATION CDelegate;

  LOCAL VIRTUAL PROCEDURE OnMessage( Result : threadpool.TPoolResult; PoolHandle, UserId : PTR; CONST MSG : msghandler.IMessage );
  BEGIN
    windows.InterlockedIncrement( ADR( Count ));
  END OnMessage;
  
END CDelegate;

PROCEDURE Test();
VAR
  DLG : CDelegate;
  MH : ARRAY [0..1499] OF msghandler.TPMessageHandler;
  TM : ARRAY [0..1499] OF msghandler.Message;
  i : CARDINAL;
  msg : windows.MSG;
  PH : ARRAY [0..1499] OF windows.HANDLE;
  TP : threadpool.CThreadPool;
BEGIN
  FOR i := 0 TO 1499 DO
    TP.WaitMessage( ADR( DLG ), i, windows.INFINITE, OUT MH[i], OUT TM[i], OUT PH[i] );
  END; // FOR

  // windows.Sleep( 2000 );

  // 1.
  // TP.FINALLY();  

  // 2.
  // FOR i := 1499 TO 0 BY -1 DO
  //   windows.PostMessage( MH[i]^.Handle, TM[i].MSG, 0, 0 );
  // END; // FOR

  // 3.
  // FOR i := 1499 TO 0 BY -1 DO
  //  TP.Abort( PH[i] );
  // END; // FOR

  // 4.
  TP.CompletionInOwningThread := TRUE;
  i := 1500;
  REPEAT
    DEC( i );
    TP.Abort( PH[i] );
    WHILE windows.PeekMessage( ADR( msg ), NIL, 0, 0, windows.PM_REMOVE ) = windows.True DO
      windows.DispatchMessage( ADR( msg ));
    END; // WHILE
  UNTIL i = 0;

  windows.Sleep( 1000 );

  WHILE windows.GetMessage( ADR( msg ), NIL, 0, 0 ) = windows.True DO
    windows.DispatchMessage( ADR( msg ));
  END; // WHILE
  
  TP.FINALLY();
END Test;

#save, call( convention => cdecl )
PROCEDURE wmain() : INTEGER;
#restore
BEGIN
  Test();
  RETURN 0;
END wmain;

END messagedelegate.