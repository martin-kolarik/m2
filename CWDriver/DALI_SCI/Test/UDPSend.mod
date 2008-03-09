MODULE UDPSend;

IMPORT
   winsock;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   log,
   netinit,
   netpool,
   netsocket,
   netsrv,
   sync,
   test,
   testimpl,
   windows;
  
(*===========================================================================*)

TYPE
   TPTest = POINTER TO CTest;

(*---------------------------------------------------------------------------*)

CLASS CTest IMPLEMENTS test.ITest;
   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
END CTest;

(*===========================================================================*)

VAR
   Test : CTest;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CTest;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   TYPE
      TBA = ARRAY [0..6] OF BYTE;
   CONST
      swonall = TBA( 0A3H, 0, 0, 0, 0FFH, 008H, 054H );
      swoffall = TBA( 0A3H, 0, 0, 0, 0FFH, 000H, 05CH );
   VAR
      DSocket : netsocket.DSocket;
      Error : CARDINAL;
      i : CARDINAL;
   BEGIN
      netinit.Startup();
      
      DSocket.Type := netsocket.stDatagram;
      DSocket.LocalPort := 4001;
      DSocket.Open( OUT Error );

      FOR i := 0 TO 100 DO
         DSocket.SendToOA( swonall, winsock.IN_ADDR( 0, 10, 0, 0, 10 ), 4001 );
         sync.Sleep( 60 );
         DSocket.SendToOA( swoffall, winsock.IN_ADDR( 0, 10, 0, 0, 10 ), 4001 );
      END;
      
      netinit.Cleanup();
      
      RETURN test.trSuccess;
   END Run;
   
(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"UDPSend", ADR( Test ));
END CTest;

(*===========================================================================*)

END UDPSend.
