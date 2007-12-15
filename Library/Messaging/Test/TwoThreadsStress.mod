MODULE twothreadsstress;

IMPORT
  msghandler,
  msgqueue,
  windows;
  
VAR
  MH : msghandler.MessageHandler;
  MQ : msgqueue.CMessageQueue;

  Exit : CARDINAL;  
  HConsume : windows.HANDLE;
  HProduce : windows.HANDLE;
  HStart : windows.HANDLE;
  HThread : windows.HANDLE;
  
#save, call( convention => stdcall )
PROCEDURE ThreadM( TP : ADDRESS ) : windows.DWORD;
#restore  
VAR
  C, PrevC : CARDINAL := 0;
  msg : windows.MSG;
BEGIN
  windows.PeekMessage( ADR( msg ), NIL, 0, 0, windows.PM_REMOVE );
  MH.Init();
  windows.SetEvent( HStart );
  
  LOOP
    windows.Sleep( 0 );
    IF Exit = 1 THEN
      EXIT;
    ELSE
      windows.GetMessage( ADR( msg ), NIL, 0, 0 );
    END;
    IF msg.message <> msgqueue.WM_MQ_PROCESS THEN
      CONTINUE;
    END;

    // QUEUE processing
    WHILE MQ.Dequeue( ADR( C ), SIZE( C )) DO
      IF C <> PrevC+1 THEN
        ASSERT( FALSE );
      END;
      INC( PrevC );
    END; // WHILE

  END; // LOOP
  
  RETURN 0;
END ThreadM;

#save, call( convention => stdcall )
PROCEDURE ThreadS( TP : ADDRESS ) : windows.DWORD;
#restore  
VAR
  C, PrevC : CARDINAL := 0;
BEGIN
  windows.SetEvent( HStart );
  LOOP
    // windows.Sleep( 0 );
    IF Exit = 1 THEN
      EXIT;
    ELSE
      windows.WaitForSingleObject( HConsume, 10000 );
    END;

    // QUEUE processing
    WHILE MQ.Dequeue( ADR( C ), SIZE( C )) DO
      IF C <> PrevC+1 THEN
        ASSERT( FALSE );
      END;
      INC( PrevC );
    END; // WHILE

  END; // LOOP
  
  RETURN 0;
END ThreadS;

#save, call( convention => cdecl )
PROCEDURE wmain() : INTEGER;
#restore
VAR
  C : CARDINAL := 1; // sending must start from 1
BEGIN
  HStart := windows.CreateEvent( NIL, windows.True, windows.False, NIL );
  HConsume := windows.CreateEvent( NIL, windows.True, windows.False, NIL );
  HProduce := windows.CreateEvent( NIL, windows.True, windows.True, NIL );

  MQ.Init( 32, SIZE( CARDINAL ));
  // MQ.Produce := HProduce; // -- setting this and not setting Consume takes the best performance

  MQ.Consumer := ADR( MH );
  HThread := windows.CreateThread( NIL, 0, ThreadM, NIL, 0, NIL );

  // MQ.Consume := HConsume;
  // HThread := windows.CreateThread( NIL, 0, ThreadS, NIL, 0, NIL );

  windows.WaitForSingleObject( HStart, windows.INFINITE );

  LOOP
    MQ.Queue( ADR( C ), SIZE( CARDINAL ));
    INC( C );
    IF C > 50000000 THEN
      EXIT;
    END;
  END;
  
  Exit := 1;
  windows.WaitForSingleObject( HThread, windows.INFINITE );
  RETURN 0;
END wmain;

END twothreadsstress.