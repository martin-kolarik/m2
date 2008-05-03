IMPLEMENTATION MODULE browser;

(*================================================================================*)

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;
   
FROM Log IMPORT
   logger, dldTrace;

(*================================================================================*)

CLASS IMPLEMENTATION CServer;
BEGIN
   ServiceFamilies := core.TServiceFamilies{};
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
      sr : core.SearchRequest;
   BEGIN
      LDelegate := Sync.ICmpExchgPtr( REF SELF.Delegate, Delegate, NIL );
      IF LDelegate = NIL THEN // previous value
         logger()^.LogS( dldTrace, L"EIBNet Browser", "started" );
      ELSE
         logger()^.LogS( dldTrace, L"EIBNet Browser", "not started -- already pending" );
         RETURN Sync.arAlreadyPending;
      END;
      Delegate^.AddRef();
      DisposeServers();

      res := Connect( Timeout );
      IF res IN Sync.arsStarts THEN // send query
         sr.HPAI := HPAISelf;
         Socket^.SendOA( OA( sr.Length-1, ADR( sr )));
         RETURN Sync.arPending;
      END;

      logger()^.LogSC( dldTrace, L"EIBNet Browser", "stopped with error: ", CARDINAL( res ));
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
         logger()^.LogSC( dldTrace, L"EIBNet Browser", "stopped with servers: ", Servers.Count );

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

   INTERNAL VIRTUAL PROCEDURE OnSearchResponse( CONST packet : core.SearchResponse );
   VAR
      ai : inetaddr.INETADDR;
      Server : TPServer;
      String : ARRAY [0..63] OF WCHAR;
   BEGIN
      packet.Address.GetAddressOA( FALSE, OUT String );
      logger()^.LogSS( dldTrace, L"EIBNet Browser", "found server: ", String );

      NEW( Server );
      Server^.HPAI := packet.HPAI;
      Server^.Description := packet.Name;
      Server^.ServiceFamilies := packet.SupportedFamilies;
      Server^.MAC := packet.MAC;

      ai := packet.Address;
      ai.Port := packet.Port;
      Server^.Address := ai;

      ai := packet.RoutingAddress;
      ai.Port := core.EIBNET_IPPORT;
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
      Servers.Clear();
   END DisposeServers;

(*--------------------------------------------------------------------------------*)

BEGIN
   Delegate := NIL;
   Mode := eibnet.cmScanning;
END CBrowser;

(*================================================================================*)

END browser.