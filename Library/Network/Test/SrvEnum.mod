MODULE SrvEnum;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   dns,
   inetaddr,
   log,
   netinit,
   netsrv,
   SCmsgqueuethread,
   Strings,
   StringsO,
   sync,
   test,
   testimpl,
   threadpool;
  
(*===========================================================================*)

TYPE
   TPTest = POINTER TO CTest;

(*---------------------------------------------------------------------------*)

CLASS CTest IMPLEMENTS test.ITest;
   PUBLIC VAR
      Host : test.TPHost := NIL;

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   
   PROCEDURE Dump( Enum : netsrv.TPInterfaceEnumerator );
END CTest;

(*===========================================================================*)

VAR
   Test : CTest;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CTest;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   VAR
      Addresses : ARRAY [0..255] OF inetaddr.INETADDR;
      Enum : netsrv.TPInterfaceEnumerator;
      Filled : CARDINAL := 0;
      i : CARDINAL;
      String : ARRAY [0..63] OF WCHAR;
   BEGIN
      SELF.Host := Host;

      SCmsgqueuethread.Startup();
      threadpool.Startup();
      netinit.Startup();

      Host^.StartPhase( L"Enumeration of interface addresses -- V4" );
      
      IF netsrv.newInterfaceEnumerator( TRUE, FALSE, OUT Enum ) THEN
         Dump( Enum );
         DISPOSE( Enum );
      END;
      
      Host^.StopPhase();

      Host^.StartPhase( L"Enumeration of interface addresses -- V6" );
      
      IF netsrv.newInterfaceEnumerator( FALSE, TRUE, OUT Enum ) THEN
         Dump( Enum );
         DISPOSE( Enum );
      END;
      
      Host^.StopPhase();

      Host^.StartPhase( L"Enumeration of local addresses -- V4, up" );
      
      IF dns.GetLocalIPs( TRUE, FALSE, FALSE, OUT Addresses, OUT Filled ) THEN
         IF Filled = 0 THEN
            Host^.Log^.LogS( log.lcInfo, 0, L"", L"no local addresses" );
         ELSE
            FOR i := 0 TO Filled-1 DO
               Addresses[i].ToOA( FALSE, OUT String );
               Host^.Log^.LogS( log.lcInfo, 0, L"", String );
            END; // FOR
         END;
      END;
      
      Host^.StopPhase();

      Host^.StartPhase( L"Enumeration of local addresses -- V6, down too" );
      
      IF dns.GetLocalIPs( FALSE, TRUE, TRUE, OUT Addresses, OUT Filled ) THEN
         IF Filled = 0 THEN
            Host^.Log^.LogS( log.lcInfo, 0, L"", L"no local addresses" );
         ELSE
            FOR i := 0 TO Filled-1 DO
               Addresses[i].ToOA( FALSE, OUT String );
               Host^.Log^.LogS( log.lcInfo, 0, L"", String );
            END; // FOR
         END;
      END;
      
      Host^.StopPhase();

      netinit.Cleanup();
      threadpool.Cleanup();
      SCmsgqueuethread.Cleanup();

      RETURN test.trUnknown;
   END Run;
   
(*---------------------------------------------------------------------------*)

   PROCEDURE Dump( Enum : netsrv.TPInterfaceEnumerator );
   VAR
      assignment : netsrv.TAssignment;
      hwAddr : ARRAY [0..15] OF CARD8;
      ia : inetaddr.INETADDR;
      i, index, l : CARDINAL;
      n : ARRAY [0..31] OF WCHAR;
      preferred : BOOLEAN;
      scope : inetaddr.TScope;
      String : ARRAY [0..511] OF WCHAR;
   BEGIN
      WHILE Enum^.MoveNext() DO
         Enum^.HWAddress( OUT hwAddr, OUT l );

         String := L"adapter ";
         Strings.FromCARD32W( Enum^.Index, 10, OUT n );
         Strings.AppendW( REF String, n );
         Strings.AppendW( REF String, L"[if=" );
         Strings.FromCARD32W( Enum^.InterfaceIndex, 10, OUT n );
         Strings.AppendW( REF String, n );
         Strings.AppendW( REF String, L"]: " );

         FOR i := 0 TO l-1 DO
            Strings.FromCARD32W( CARDINAL( hwAddr[i] ), 16, OUT n );
            Strings.AppendW( REF String, n );
            IF i < l-1 THEN
               Strings.AppendW( REF String, L"-" );
            END;
         END;
         Host^.Log^.LogS( log.lcInfo, 0, L"", String );
         
         IF Enum^.State = netsrv.stUp THEN
            String := L"  UP";
         ELSE
            String := L"  DOWN";
         END;
         CASE Enum^.Medium OF
         | netsrv.medLoopback : Strings.AppendW( REF String, L", loopback" );
         | netsrv.medCSMACD : Strings.AppendW( REF String, L", CSMA/CD" );
         | netsrv.med80211 : Strings.AppendW( REF String, L", 802.11" );
         | netsrv.medPPP : Strings.AppendW( REF String, L", PPP" );
         | netsrv.medTunnel : Strings.AppendW( REF String, L", tunnel" );
         | netsrv.medVLAN : Strings.AppendW( REF String, L", VLAN" );
         | netsrv.medOther : Strings.AppendW( REF String, L", unspecified" );
         END; // CASE
         Host^.Log^.LogS( log.lcInfo, 0, L"", String );
         
         index := 0;
         WHILE Enum^.InetAddress( index, OUT ia, OUT preferred, OUT scope, OUT assignment ) DO
            ia.ToOA( FALSE, OUT String );
            IF preferred THEN
               Strings.AppendW( REF String, L", preferred" );
            END;
            CASE scope OF
            | inetaddr.scoLoopback :
               Strings.AppendW( REF String, L", loopback" );
            | inetaddr.scoLocalLink :
               Strings.AppendW( REF String, L", local link" );
            | inetaddr.scoLocalSite :
               Strings.AppendW( REF String, L", local site" );
            | inetaddr.scoGlobal :
               Strings.AppendW( REF String, L", global" );
            END;
            CASE assignment OF
            | netsrv.assFixed :
               Strings.AppendW( REF String, L", FIX" );
            | netsrv.assDynamic :
               Strings.AppendW( REF String, L", DYN" );
            END;

            Strings.PrependW( REF String, L"    " );
            Host^.Log^.LogS( log.lcInfo, 0, L"", String );

            INC( index );
         END; // WHILE
      END; // WHILE
   END Dump;

(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"Network::IfEnum", ADR( Test ));
END CTest;

(*===========================================================================*)

END SrvEnum.
