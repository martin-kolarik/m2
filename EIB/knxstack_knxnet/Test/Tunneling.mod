MODULE Tunneling;

IMPORT
	winsock;

IMPORT
   arrays,
	windows,
	eibnet,
	browser,
	Log,
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
   PUBLIC VAR
      Server : browser.CServer;
	LOCAL VIRTUAL PROCEDURE OnCompleted( Result : Sync.TAsyncResult; CONST Servers : arrays.CPtrArray );
END CDelegate;

CLASS IMPLEMENTATION CDelegate;

	LOCAL VIRTUAL PROCEDURE OnCompleted( Result : Sync.TAsyncResult; CONST Servers : arrays.CPtrArray );
	BEGIN
	   IF Servers.Count = 0 THEN
	      RETURN;
	   END;
	   Server := browser.TPServer( Servers[0] )^;
	END OnCompleted;

END CDelegate;

PROCEDURE Test();
VAR
  B : browser.CBrowser;
  C : eibnet.CConnection;
  D : CDelegate;
BEGIN
	B.Browse( ADR( D ), 500 );
	Wait( 120 );
	
	C.RemoteAddress := D.Server.Address;
	C.RemotePort := D.Server.Port;
	
	C.Connect( 0 );
	// Wait( 100 );
	// C.Disconnect();
	
	Wait( 10000000 );
END Test;

#save, call( entry_point => on )
PROCEDURE wmain();
#restore
BEGIN
   Log.LOG.DebugLevel := Log.ldDebug;

	netinit.Startup();
	Test();
	netinit.Cleanup();
END wmain;

END Tunneling.