MODULE OneToNStress;

IMPORT
  msghandler,
  msgqueue,
  windows;
  
VAR
  MQ : ARRAY [0..19] OF msgqueue.CMessageQueue;

#save, call( convention => stdcall )
PROCEDURE Thread( Index : ADDRESS ) : windows.DWORD;
#restore  
VAR
  LastC : CARDINAL := 0;
  C : CARDINAL := 1;
BEGIN
  LOOP
    IF NOT MQ[CARDINAL( Index )].Dequeue( ADR( C ), SIZE( CARDINAL )) THEN
      windows.Sleep( 0 );
    ELSIF C = LastC + 1 THEN
      INC( LastC );
    ELSE
      ASSERT( FALSE );
    END;
  END;
  RETURN 0;
END Thread;

#save, call( convention => cdecl )
PROCEDURE xwmain() : INTEGER;
#restore
VAR
  C : ARRAY [0..19] OF CARDINAL;
  I, J, K : CARDINAL := 0;
BEGIN
  FOR I := 0 TO 19 DO
    C[I] := 1;
    MQ[I].Init( 128, SIZE( CARDINAL ));
    windows.CreateThread( NIL, 0, Thread, ADDRESS( I ), 0, NIL );
  END;
  
  FOR I := 1 TO 10000000 DO
    FOR J := 0 TO 61 DO
      MQ[K].Queue( ADR( C[K] ), SIZE( CARDINAL ));
      INC( C[K] );
    END;
    IF K = 19 THEN
      K := 0;
    ELSE
      INC( K );
    END;
  END;

  RETURN 0;
END xwmain;

END OneToNStress.