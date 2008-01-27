MODULE Timeouts;

IMPORT
  FIO,
  Strings,
  Sync,
  threadpool,
  windows;

VAR
  Count : CARDINAL;
  
CLASS CDelegate( threadpool.APoolDelegate );
  LOCAL VIRTUAL PROCEDURE OnTimeout( Result : Sync.TAsyncResult; PoolHandle : Sync.WAITABLE; UserId : PTR );
END CDelegate;
  
CLASS IMPLEMENTATION CDelegate;

  LOCAL VIRTUAL PROCEDURE OnTimeout( Result : Sync.TAsyncResult; PoolHandle : Sync.WAITABLE; UserId : PTR );
  VAR
    f : FIO.File := windows.GetStdHandle( windows.STD_OUTPUT_HANDLE );
    n : ARRAY [0..255] OF CHAR;
    nw : ARRAY [0..15] OF WCHAR;
  BEGIN
    Strings.FromCARD32W( CARDINAL( UserId ), 10, OUT nw );
    Strings.ToA( nw, 0, OUT n );
    // FIO.WrStrA( f, n );
    IF UserId = 1 THEN
      // FIO.WrLnA( f );
      INC( Count );
      Strings.FromCARD32W( CARDINAL( Count ), 10, OUT nw );
      Strings.ToA( nw, 0, OUT n );
      // FIO.WrStrA( f, n );
      // FIO.WrStrA( f, C': ' );
    ELSE
      // FIO.WrStrA( f, C', ' );
    END;
  END OnTimeout;
  
END CDelegate;

PROCEDURE Test();
VAR
  DLG : CDelegate;
  i : CARDINAL;
  msg : windows.MSG;
  PH : ARRAY [0..1499] OF windows.HANDLE;
  TP : threadpool.CThreadPool;
BEGIN
  Count := 1;
  FOR i := 0 TO 119 DO
    TP.WaitTimeout( ADR( DLG ), 120-i, (120-i)*500, FALSE, OUT PH[i] );
  END; // FOR

  WHILE windows.GetMessage( ADR( msg ), NIL, 0, 0 ) = windows.True DO
    windows.DispatchMessage( ADR( msg ));
  END; // WHILE
  
  TP.FINALLY();
END Test;

#save, call( convention => cdecl )
PROCEDURE wmain02() : INTEGER;
#restore
BEGIN
  Test();
  RETURN 0;
END wmain02;

END Timeouts.