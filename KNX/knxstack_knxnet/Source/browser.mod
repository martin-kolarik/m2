IMPLEMENTATION MODULE browser;

(*================================================================================*)

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;
   
FROM Log IMPORT
   logger, ldTrace;

(*================================================================================*)

CLASS IMPLEMENTATION CServer;
BEGIN
   ServiceFamilies := transport.TServiceFamilies{};
END CServer;

(*================================================================================*)

CLASS IMPLEMENTATION CBrowserDelegate;
END CBrowserDelegate;

(*================================================================================*)

CLASS IMPLEMENTATION CBrowser;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Browse( Delegate : TPBrowserDelegate; Timeout : CARDINAL ) : Sync.TAsyncResult; // if Timeout = 0 then the default one is used
   VAR
      LDelegate : TPBrowserDelegate;
      res : Sync.TAsyncResult;
      sr : transport.SearchRequest;
   BEGIN
      LDelegate := Sync.ICmpExchgPtr( REF SELF.Delegate, Delegate, NIL );
      IF LDelegate = NIL THEN // previous value
         logger()^.LogS( ldTrace, 0, L"KNXnet Browser", "started" );
      ELSE
         logger()^.LogS( ldTrace, 0, L"KNXnet Browser", "not started -- already pending" );
         RETURN Sync.arAlreadyPending;
      END;
      Delegate^.AddRef();
      DisposeServers();

      res := Connect( Timeout );
      IF res IN Sync.arsStarts THEN // send query
         sr.HPAI := HPAISelf;
         _Socket^.SendOA( OA( sr.Length-1, ADR( sr )));
         RETURN Sync.arPending;
      END;

      logger()^.LogSC( ldTrace, 0, L"KNXnet Browser", "stopped with error: ", CARDINAL( res ));
      Sync.IExchgPtr( REF SELF.Delegate, NIL );
      RETURN Sync.arCannotStart;
   END Browse;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnScanCompleted();
   VAR
      l : CARDINAL;
      LDelegate : TPBrowserDelegate;
   BEGIN
      LDelegate := Sync.IExchgPtr( REF SELF.Delegate, NIL );
      IF LDelegate <> NIL THEN
         logger()^.LogSC( ldTrace, 0, L"KNXnet Browser", "stopped with servers: ", Servers.Count );

         l := Servers.Count;
         IF l = 0 THEN
            LDelegate^.OnCompleted( Sync.arNoData, Servers );
         ELSE
            LDelegate^.OnCompleted( Sync.arCompleted, Servers );
         END;
         LDelegate^.Release();
      END;
      DisposeServers();
   END OnScanCompleted;
   
(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnSearchResponse( CONST packet : transport.SearchResponse );
   VAR
      ai : inetaddr.INETADDR;
      Server : TPServer;
      String : ARRAY [0..63] OF WCHAR;
   BEGIN
      packet.Address.ToOA( FALSE, OUT String );
      logger()^.LogSS( ldTrace, 0, L"KNXnet Browser", "found server: ", String );

      NEW( Server );
      Server^.HPAI := packet.HPAI;
      Server^.Description := packet.Name;
      Server^.ServiceFamilies := packet.SupportedFamilies;
      Server^.MAC := packet.MAC;

      ai := packet.Address;
      ai.Port := packet.Port;
      Server^.Address := ai;

      ai := packet.RoutingAddress;
      ai.Port := transport.KNXNET_IPPORT;
      Server^.RoutingAddress := ai;

      Servers.Add( Server );
   END OnSearchResponse;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE DisposeServers();
   VAR
      i : CARDINAL;
   BEGIN
      FOR i := 0 TO Servers.Count-1 DO
         DISPOSE( TPServer( Servers[i] ));
      END;
      Servers.Dispose();
   END DisposeServers;

(*--------------------------------------------------------------------------------*)

BEGIN
   Delegate := NIL;
   Mode := protocol.cmScanning;
END CBrowser;

(*================================================================================*)

END browser.