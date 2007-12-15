MODULE SendReceive;

IMPORT
  winsock;

FROM Storage IMPORT
  ALLOCATE, DEALLOCATE;
  
IMPORT
  IOO,
  netinit,
  netsocket,
  netsrv,
  Strings,
  Sync,
  windows;
  
CLASS RDR( IOO.CMemoryProxy );
  VAR
    LL : CARD64 := 0;
    PrevC : CARDINAL := 0;
  PUBLIC VIRTUAL PROCEDURE CompleteData( Completed : CARDINAL );
END RDR;

CLASS WRT( IOO.CMemoryProxy );
  VAR
    LL : CARD64 := 0;
  PUBLIC VIRTUAL PROCEDURE CompleteData( Completed : CARDINAL );
END WRT;

PROCEDURE Wait();
VAR
  C : CARDINAL := 2;
  msg : windows.MSG;
BEGIN
  WHILE C > 0 DO 
    windows.PeekMessage( ADR( msg ), NIL, 0, 0, windows.PM_REMOVE );
    windows.DispatchMessage( ADR( msg ));
    windows.Sleep( 0 );
    DEC( C );
  END; // WHILE
END Wait;
  
CLASS C_LN( netsrv.AListener );
  LOCAL VIRTUAL PROCEDURE OnListen( CONST ServerSocket : netsocket.TPSSocket );
END C_LN;

VAR  
  Buffer : ARRAY [0..9999] OF BYTE;
  DC : netsocket.TPDSocket;
  DS : netsocket.DSocket;
  LN : C_LN;
  RD : RDR;
  LL : CARD64 := 0;

CLASS IMPLEMENTATION RDR;

  PUBLIC VIRTUAL PROCEDURE CompleteData( Completed : CARDINAL );
  BEGIN
    INC( LL, Completed );
    SUPER.CompleteData( Completed );
    _Ptr := 0;
    // IF SUPER.OnCompletion( Result, Completed ) THEN
    //   RETURN TRUE;
    // END;
    // have all, check
    ASSERT( PCARDINAL( _Data )^ = PrevC+1 );
    INC( PrevC );
    // RETURN TRUE;
  END CompleteData;

BEGIN
END RDR;
  
CLASS IMPLEMENTATION WRT;

  PUBLIC VIRTUAL PROCEDURE CompleteData( Completed : CARDINAL );
  BEGIN
    INC( LL, Completed );
    SUPER.CompleteData( Completed );
  END CompleteData;

BEGIN
END WRT;
  
CLASS IMPLEMENTATION C_LN;

  LOCAL VIRTUAL PROCEDURE OnListen( CONST ServerSocket : netsocket.TPSSocket );
  VAR
    Error : CARDINAL;
  BEGIN
    DS.Accept( ServerSocket, OUT Error );
    DS.Receive( ADR( RD ), windows.INFINITE, FALSE );
  END OnListen;

END C_LN;

PROCEDURE Test();
CONST
  S = L'Ahoj Martine.';
VAR
  AR : Sync.TAsyncResult;
  C : CARDINAL := 1; // start with 1
  CA : ARRAY [0..9999] OF BYTE;
  SD : WRT;
BEGIN
  RD.Init( ADR( Buffer ), 4, FALSE ); // SIZE( Buffer ), FALSE );
  RD.Persistent := TRUE;

  netsrv.StartListen( netsocket.stStream, 4444, NIL, ADR( LN ), 0, NIL );
  Wait();

  NEW( DC );
  DC^.Waitable := TRUE;
  DC^.ConnectAddress( winsock.IN_ADDR( 0, 07FH, 0, 0, 1 ), 4444, windows.INFINITE );
  // DC^.ConnectAddress( winsock.IN_ADDR( 0, 0AH, 80H, 1, 15H ), 4444, windows.INFINITE );
  Wait();
  DC^.WaitCompletion( windows.INFINITE );
  Wait();
  
  SD.Persistent := TRUE;
  LOOP
    SD.Init( ADR( C ), 4, FALSE );
    // SD.Init( ADR( CA ), SIZE( CA ), FALSE );
    IF DC^.Send( ADR( SD ), windows.INFINITE, TRUE ) = Sync.arCompleted THEN
      INC( C );
    END;
    IF C = 1000000 THEN
    // IF C = 100 THEN
      EXIT;
    END;
  END; // LOOP
  
  DS.AbortReceive();

  (*
  SD^.Init( ADR( CA ), SIZE( CA ), FALSE );
  DC^.Send( SD, windows.INFINITE, TRUE );
  LOOP
    IF SD^.Result = Sync.arCompleted THEN
      SD^.Reset();
      INC( C );
      SD^.Init( ADR( CA ), SIZE( CA ), FALSE );
      AR := DC^.Send( SD, windows.INFINITE, TRUE );
      IF AR <> Sync.arCompleted THEN
        AR := Sync.arAborted;
      END;
    END;
    IF C = 1000000 THEN
      EXIT;
    END;
  END; // LOOP
  *)

END Test;

(*========================================================================*)

#save, call( convention => cdecl )
PROCEDURE wmain() : INTEGER;
#restore
VAR
  msg : windows.MSG;
BEGIN
  netinit.Startup();
  Test();
  WHILE windows.GetMessage( ADR( msg ), NIL, 0, 0 ) = windows.True DO
    windows.DispatchMessage( ADR( msg ));
  END;
  RETURN 0;
END wmain;

END SendReceive.