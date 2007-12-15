MODULE NToOneStress;

IMPORT
  msghandler,
  msgqueue,
  windows;
  
TYPE
  TCards = ARRAY [0..19] OF CARDINAL;
VAR
  LastC : TCards;
  MQ : msgqueue.CMessageQueue;

CLASS CMH( msghandler.MessageHandler );
  INTERNAL VIRTUAL PROCEDURE OnMessage( CONST MSG : msghandler.IMessage; OUT Result : CARDINAL ) : BOOLEAN;
END CMH;

CLASS IMPLEMENTATION CMH;

  INTERNAL VIRTUAL PROCEDURE OnMessage( CONST MSG : msghandler.IMessage; OUT Result : CARDINAL ) : BOOLEAN;
  VAR
    GetC : CARDINAL;
    I : CARDINAL;
  BEGIN
    IF MSG.MSG <> msgqueue.WM_MQ_PROCESS THEN
      RETURN FALSE;
    END;
    
    WHILE MQ.Dequeue( ADR( GetC ), SIZE( GetC )) DO
      I := GetC >> 24;
      IF GetC AND 0FFFFFFH <> LastC[I]+1 THEN
        ASSERT( FALSE );
      END;
      INC( LastC[I] ); 
    END; // WHILE
    
    RETURN TRUE;
  END OnMessage;

END CMH;
  
VAR
  MH : CMH;

#save, call( convention => stdcall )
PROCEDURE Thread( Index : ADDRESS ) : windows.DWORD;
#restore  
VAR
  C : CARDINAL := 1 OR ( CARDINAL( Index ) << 24 );
BEGIN
  LOOP
    MQ.Queue( ADR( C ), SIZE( CARDINAL ));
    INC( C );
    IF C AND 0FFFFFFH >= 0FFFFFFH THEN
      EXIT;
    END;
  END;
  RETURN 0;
END Thread;

#save, call( convention => cdecl )
PROCEDURE wmain() : INTEGER;
#restore
TYPE
  TCards = ARRAY [0..19] OF CARDINAL;
VAR
  HThread : windows.HANDLE;
  I : CARDINAL := 0;
  msg : windows.MSG;
BEGIN
  MH.Init();
  MQ.Init( 32, SIZE( CARDINAL ));
  MQ.Consumer := ADR( MH );

  // init
  FOR I := 0 TO 19 DO
    LastC[I] := 0;
    HThread := windows.CreateThread( NIL, 0, Thread, ADDRESS( I ), 0, NIL );
  END; // FOR

  // run is inside MH
  WHILE windows.GetMessage( ADR( msg ), NIL, 0, 0 ) = windows.True DO
    windows.DispatchMessage( ADR( msg ));
  END;
  
  RETURN 0;
END wmain;

END NToOneStress.