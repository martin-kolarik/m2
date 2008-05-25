MODULE UDPSend;

IMPORT
   winsock;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   inetaddr,
   log,
   netinit,
   netsocket,
   netsrv,
   sync,
   test,
   testimpl,
   threadpool,
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
      IA : inetaddr.INETADDR;
   BEGIN
      netinit.Startup();
      
      DSocket.Type := netsocket.stDatagram;
      IA.Port := 10001;
      DSocket.LocalAddress := IA;
      DSocket.SSocket.Open( OUT Error );

      IA.SetAddressOA( L"10.0.0.100:10001", 0 );
      FOR i := 0 TO 100 DO
         DSocket.SendToOA( swonall, IA );
         sync.Sleep( 60 );
         DSocket.SendToOA( swoffall, IA );
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
