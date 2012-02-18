MODULE TSDAPClient;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   log,
   scinit,
   SDAPClient,
   StringsO,
   Sync,
   test,
   testimpl;
  
(*===========================================================================*)

TYPE
   TPTest = POINTER TO CTest;

(*---------------------------------------------------------------------------*)

CONST
   COUNT = 1000;

CLASS CTest IMPLEMENTS test.ITest, SDAPClient.ISDAPClientEvents;
   PUBLIC VAR
      Host : test.TPHost := NIL;
      Client : SDAPClient.TPISDAPClient := NIL;
      ReceiveCount : CARDINAL := 0;

   // ITest
   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;

   // ISDAPClientEvents
   PUBLIC VIRTUAL PROCEDURE OnConnect( Result : Sync.TAsyncResult; Error : CARDINAL );
   PUBLIC VIRTUAL PROCEDURE OnDisconnect( Result : Sync.TAsyncResult; Error : CARDINAL );
   PUBLIC VIRTUAL PROCEDURE OnReceive( CONST Data, Value : StringsO.IString );
END CTest;

(*===========================================================================*)

VAR
   Test : CTest;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CTest;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   VAR
      Failure1, Failure2 : BOOLEAN := FALSE;
      i : CARDINAL;
      Result : Sync.TAsyncResult;
      s : StringsO.CString;
   BEGIN
      SELF.Host := Host;

      scinit.Startup();
      Result := SDAPClient.newSDAPClient( OUT Client );
      Client^.EventListener := ADR( SELF );

      Host^.StartPhase( L"Connect and get something" );
      ReceiveCount := 0;

      s.FromOA( L"127.0.0.1:6007" );
      Result := Client^.Connect( s );
      WHILE NOT Client^.Connected DO
         Sync.Sleep( 10 );
      END; // WHILE
      
      s.FromOA( L"3/1/21" );
      FOR i := 0 TO COUNT-1 DO
         Client^.Ask( s );
         Sync.Sleep( 5 );
      END; // FOR
      Sync.Sleep( 100 );
      
      Client^.Disconnect();
      Sync.Sleep( 10 );
      Client^.Dispose();
      Client := NIL;
      
      Failure1 := ReceiveCount <> COUNT-1;
      Host^.StopPhaseWithResult( NOT Failure1 );

      scinit.Cleanup();

      IF Failure1 OR Failure2 THEN
         RETURN test.trFailure;
      ELSE
         RETURN test.trSuccess;
      END;
   END Run;
   
(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnConnect( Result : Sync.TAsyncResult; Error : CARDINAL );
   BEGIN
      Host^.Log^.LogSC( log.ldMessage, 0, L"", L"Connect: ", Error );
   END OnConnect;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnDisconnect( Result : Sync.TAsyncResult; Error : CARDINAL );
   BEGIN
      Host^.Log^.LogSC( log.ldMessage, 0, L"", L"Close: ", Error );
   END OnDisconnect;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnReceive( CONST Data, Value : StringsO.IString );
   BEGIN
      Sync.IInc( REF ReceiveCount );
      Host^.Log^.LogSSSS( log.ldMessage, 0, L"", OA( Data.Length-1, Data.Data ), L" ", OA( Value.Length-1, Value.Data ), L" " );
   END OnReceive;

(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"SDAPClient", ADR( Test ));
END CTest;

(*===========================================================================*)

END TSDAPClient.
