MODULE TIntegerQueue;

IMPORT
  Sync,
  SyncQueue,
  time,
  windows;
  
VAR
  Q : SyncQueue.IntegerQueue;

  Exit : CARDINAL;  
  HStart : windows.HANDLE;
  HThread : windows.HANDLE;
  
#save, call( convention => stdcall )
PROCEDURE Thread( TP : ADDRESS ) : windows.DWORD;
#restore  
VAR
  C, PrevC : CARDINAL := 0;
  C64, PrevC64 : CARD64 := 0;
BEGIN
  windows.SetEvent( HStart );
  LOOP
    // windows.Sleep( 0 );
    IF Exit = 1 THEN
      EXIT;
    END;

    // QUEUE processing
    LOOP
      Q.Dequeue( OUT C, TRUE, Sync.INFINITE_TIME );
      IF C <> PrevC+1 THEN
        ASSERT( FALSE );
      END;
      IF C = 10000000 THEN
        EXIT;
      END;
      INC( PrevC );
    END; // LOOP
    (*
    LOOP
      Q.ReadOA( OUT C64 );
      IF C64 <> PrevC64+1 THEN
        ASSERT( FALSE );
      END;
      IF C64 = 10000000 THEN
        EXIT;
      END;
      INC( PrevC64 );
    END; // LOOP
    *)

  END; // LOOP
  
  RETURN 0;
END Thread;

#save, call( convention => cdecl )
PROCEDURE wmain() : INTEGER;
#restore
VAR
  C : CARDINAL := 1; // sending must start from 1
  C64 : CARD64 := 1;
  T : time.TTime64;
BEGIN
  Q.Size := 111;

  HStart := windows.CreateEvent( NIL, windows.True, windows.False, NIL );
  HThread := windows.CreateThread( NIL, 0, Thread, NIL, 0, NIL );
  windows.WaitForSingleObject( HStart, Sync.INFINITE_TIME );

  T := time.GetHiResTicks();
  
  LOOP
    Q.Queue( C, TRUE, Sync.INFINITE_TIME );
    INC( C );
    IF C > 10000000 THEN
      EXIT;
    END;
  END;
  (*
  LOOP
    Q.WriteOA( C64 );
    INC( C64 );
    IF C64 > 10000000 THEN
      EXIT;
    END;
  END;
  *)

  C := CARDINAL( time.HiResTicksToLRMS( time.GetHiResDifference( REF T )));
  
  Exit := 1;
  windows.WaitForSingleObject( HThread, windows.INFINITE );
  RETURN 0;
END wmain;

END TIntegerQueue.