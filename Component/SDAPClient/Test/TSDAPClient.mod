MODULE TSDAPClient;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   log,
   SDAPClient,
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
   PUBLIC VIRTUAL PROCEDURE OnConnect( Error : CARDINAL );
   PUBLIC VIRTUAL PROCEDURE OnClose( Error : CARDINAL );
   PUBLIC VIRTUAL PROCEDURE OnReceive( CONST Data : ARRAY OF WCHAR; CONST Value : ARRAY OF WCHAR );
END CTest;

(*===========================================================================*)

VAR
   Test : CTest;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CTest;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   VAR
      error : CARDINAL;
      Failure1, Failure2 : BOOLEAN := FALSE;
      i : CARDINAL;
   BEGIN
      SELF.Host := Host;

      SDAPClient.Startup();
      error := SDAPClient.newSDAPClient( OUT Client );
      Client^.SetEventListener( ADR( SELF ));

      Host^.StartPhase( L"Connect and get something" );
      ReceiveCount := 0;

      error := Client^.Connect( L"127.0.0.1:6007" );
      WHILE NOT Client^.IsConnected() DO
         Sync.Sleep( 10 );
      END; // WHILE
      
      FOR i := 0 TO COUNT-1 DO
         Client^.Ask( L"3/1/21" );
         Sync.Sleep( 5 );
      END; // FOR
      Sync.Sleep( 100 );
      
      Client^.Close();
      Sync.Sleep( 10 );
      Client^.Dispose();
      Client := NIL;
      
      Failure1 := ReceiveCount <> COUNT-1;

      IF Failure1 THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      SDAPClient.Cleanup();

      IF Failure1 OR Failure2 THEN
         RETURN test.trFailure;
      ELSE
         RETURN test.trSuccess;
      END;
   END Run;
   
(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnConnect( Error : CARDINAL );
   BEGIN
      Host^.Log^.LogSC( log.dldMessage, L"", L"Connect: ", Error );
   END OnConnect;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnClose( Error : CARDINAL );
   BEGIN
      Host^.Log^.LogSC( log.dldMessage, L"", L"Close: ", Error );
   END OnClose;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnReceive( CONST Data : ARRAY OF WCHAR; CONST Value : ARRAY OF WCHAR );
   BEGIN
      Sync.IInc( REF ReceiveCount );
      Host^.Log^.LogSSSS( log.dldMessage, L"", Data, L" ", Value, L" " );
   END OnReceive;

(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"SDAPClient", ADR( Test ));
END CTest;

(*===========================================================================*)

END TSDAPClient.
