MODULE Browse;

IMPORT
	winsock;

IMPORT
   arrays,
	windows,
	browser,
	netinit,
	Sync;

PROCEDURE Wait( i : CARDINAL );
VAR
	msg : windows.MSG;
BEGIN
	LOOP
    WHILE windows.PeekMessage( ADR( msg ), NIL, 0, 0, windows.PM_REMOVE ) = windows.True DO
			windows.DispatchMessage( ADR( msg ));
		END;
		windows.Sleep( 10 );
		IF i > 0 THEN
			DEC( i );
			IF i = 0 THEN
				EXIT;
			END;
		END;
	END; // LOOP
END Wait;

CLASS CDelegate( browser.CBrowserDelegate );
	LOCAL VIRTUAL PROCEDURE OnCompleted( Result : Sync.TAsyncResult; CONST Servers : arrays.CPtrArray );
END CDelegate;

CLASS IMPLEMENTATION CDelegate;

	LOCAL VIRTUAL PROCEDURE OnCompleted( Result : Sync.TAsyncResult; CONST Servers : arrays.CPtrArray );
	BEGIN
	END OnCompleted;

END CDelegate;

PROCEDURE Test();
VAR
  B : browser.CBrowser;
  D : CDelegate;
BEGIN
	B.Browse( ADR( D ), 0 );
	Wait( 1000000 );
END Test;

#save, call( entry_point => on )
PROCEDURE wmain();
#restore
BEGIN
	netinit.Startup();
	Test();
	netinit.Cleanup();
END wmain;

END Browse.