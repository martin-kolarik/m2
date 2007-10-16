MODULE workerdelegate;

IMPORT
  msghandler,
  threadpool,
  windows;
  
VAR
  Count : CARDINAL := 0;
  
CLASS CDelegate( threadpool.CPoolDelegate );
  LOCAL VIRTUAL PROCEDURE OnWorker( Result : threadpool.TPoolResult; PoolHandle, UserId : PTR );
END CDelegate;
  
CLASS IMPLEMENTATION CDelegate;

  LOCAL VIRTUAL PROCEDURE OnWorker( Result : threadpool.TPoolResult; PoolHandle, UserId : PTR );
  BEGIN
    windows.InterlockedIncrement( ADR( Count ));
  END OnWorker;
  
END CDelegate;

CLASS CWorker( threadpool.APoolWorker );
  Delay : CARDINAL;
  LOCAL VIRTUAL PROCEDURE Run();
END CWorker;

CLASS IMPLEMENTATION CWorker;

  LOCAL VIRTUAL PROCEDURE Run();
  BEGIN
    windows.Sleep( Delay );
  END Run;

BEGIN
  Delay := 0;
END CWorker;

PROCEDURE Test();
VAR
  DLG : CDelegate;
  i : CARDINAL;
  msg : windows.MSG;
  PH : ARRAY [0..1499] OF windows.HANDLE;
  WA : ARRAY [0..1499] OF CWorker;
  TP : threadpool.CThreadPool;
  TIMEOUT : CARDINAL;
BEGIN
  // TIMEOUT := windows.INFINITE;
  TIMEOUT := 10000;

  FOR i := 0 TO 1499 DO
    WA[i].Delay := ( 1500 - i );
    TP.RunWorker( ADR( DLG ), i, TIMEOUT, ADR( WA[i] ), OUT PH[i] );
  END; // FOR

  // windows.Sleep( 2000 );

  // 1.
  // FOR i := 1499 TO 0 BY -1 DO
  //  TP.Abort( PH[i] );
  // END; // FOR

  // 4.
  // TP.CompletionInOwningThread := TRUE;
  // i := 1500;
  // REPEAT
  //   DEC( i );
  //   TP.Abort( PH[i] );
  //   WHILE windows.PeekMessage( ADR( msg ), NIL, 0, 0, windows.PM_REMOVE ) = windows.True DO
  //     windows.DispatchMessage( ADR( msg ));
  //   END; // WHILE
  // UNTIL i = 0;

  // windows.Sleep( 1000 );

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

END workerdelegate.