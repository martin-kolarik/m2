MODULE MessageQueue;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   log,
   msghandler,
   msgqueue,
   Strings,
   Sync,
   SyncQueue,
   test,
   testimpl,
   windows;
  
(*===========================================================================*)

CLASS CTest IMPLEMENTS test.ITest;
   PRIVATE VAR
      Host : test.TPHost := NIL;
      MH : msghandler.MessageHandler;
      MQ : msgqueue.CMessageQueue;
      Exit : CARDINAL := 0;

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   INTERNAL PROCEDURE Round( QueueSize : CARDINAL; ConsumeByEvent : BOOLEAN ) : BOOLEAN;
   
   LOCAL PROCEDURE Produce();
   LOCAL PROCEDURE ConsumeByEvent();
   LOCAL PROCEDURE ConsumeByMessage();
END CTest;

(*---------------------------------------------------------------------------*)

TYPE
   TPTest = POINTER TO CTest;
VAR
   Test : CTest;

(*---------------------------------------------------------------------------*)

#save, call( convention => stdcall )
PROCEDURE ProducerThread( a : ADDRESS ) : windows.DWORD;
BEGIN
   TPTest( a )^.Produce();
   RETURN 0;
END ProducerThread;

PROCEDURE ConsumerThreadByEvent( a : ADDRESS ) : windows.DWORD;
BEGIN
   TPTest( a )^.ConsumeByEvent();
   RETURN 0;
END ConsumerThreadByEvent;

PROCEDURE ConsumerThreadByMessages( a : ADDRESS ) : windows.DWORD;
BEGIN
   TPTest( a )^.ConsumeByMessage();
   RETURN 0;
END ConsumerThreadByMessages;
#restore  

(*===========================================================================*)

CLASS IMPLEMENTATION CTest;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   TYPE
      TSizes = ARRAY [0..8] OF CARDINAL;
   CONST
      sizes = TSizes( 1, 7, 8, 11, 24, 113, 512, 8191, 8193 );
   VAR
      Failure : BOOLEAN := FALSE;
      Mode : BOOLEAN;
      Size : CARDINAL;
   BEGIN
      SELF.Host := Host;
   
      FOR Mode := FALSE TO TRUE DO
         FOR Size := 0 TO HIGH( sizes ) DO
            Failure := NOT Round( sizes[Size], Mode ) OR Failure;
         END;
      END;

      IF Failure THEN
         RETURN test.trFailure;
      ELSE
         RETURN test.trSuccess;
      END;
   END Run;
   
(*---------------------------------------------------------------------------*)

   INTERNAL PROCEDURE Round( QueueSize : CARDINAL; ConsumeByEvent : BOOLEAN ) : BOOLEAN;
   VAR
      CT : windows.HANDLE := NIL;
      PT : windows.HANDLE := NIL;
      Phase : ARRAY [0..31] OF WCHAR;
      Success : BOOLEAN;
   BEGIN
      Exit := 0; // reset
      MQ.Clear();
      MQ.Size := QueueSize;
      MQ.ItemSize := SIZE( INT32 );
      IF ConsumeByEvent THEN
         MQ.Consume := Sync.CreateSignal( FALSE, L"" );
      ELSE
         MQ.Consumer := ADR( MH );
      END;
      
      Strings.FromCARD32W( QueueSize, 10, OUT Phase );
      Strings.PrependW( REF Phase, L"Queue length: " );      
      Host^.StartPhase( Phase );

      IF ConsumeByEvent THEN
         CT := windows.CreateThread( NIL, 0, ConsumerThreadByEvent, ADR( SELF ), 0, NIL );
      ELSE
         CT := windows.CreateThread( NIL, 0, ConsumerThreadByMessages, ADR( SELF ), 0, NIL );
      END;
      WHILE MH.Handle = NIL DO END;
      PT := windows.CreateThread( NIL, 0, ProducerThread, ADR( SELF ), 0, NIL );
      Sync.Wait( PT, Sync.INFINITE_TIME );
      
      Success := Exit = 0;
      Exit := 1;
      
      Sync.Wait( CT, Sync.INFINITE_TIME );
      windows.CloseHandle( PT );
      windows.CloseHandle( CT );
      
      Host^.StopPhase();
      RETURN Success;
   END Round;

(*---------------------------------------------------------------------------*)

   LOCAL PROCEDURE Produce();
   VAR
      I32 : INT32 := 1;
   BEGIN
      LOOP
         MQ.Queue( ADR( I32 ), SIZE( I32 ), TRUE, Sync.INFINITE_TIME );
         INC( I32 );
         IF I32 > 500000 THEN
            EXIT;
         ELSIF Exit = 1 THEN
            EXIT;
         END;
      END;
   END Produce;

(*---------------------------------------------------------------------------*)

   LOCAL PROCEDURE ConsumeByEvent();
   VAR
      I32, P32 : INT32 := 0;
      sI32, sP32 : ARRAY [0..15] OF WCHAR;
      msg : windows.MSG;
   BEGIN
      windows.PeekMessage( ADR( msg ), NIL, 0, 0, windows.PM_REMOVE );
      MH.Init();

      LOOP
         MQ.Dequeue( ADR( I32 ), SIZE( I32 ), TRUE, Sync.INFINITE_TIME );
         IF I32 <> P32+1 THEN
            Strings.FromINT32W( I32, 10, OUT sI32 ); Strings.FromINT32W( P32, 10, OUT sP32 );
            Host^.Log^.LogSSSS( log.dlcError, L"", L"Failed on numbers: ", sI32, L"/", sP32 );
            Exit := 1;
            EXIT;
         END;
         IF I32 = 500000 THEN
            EXIT;
         ELSIF Exit = 1 THEN
            EXIT;
         END;
         INC( P32 );
      END; // LOOP
   END ConsumeByEvent;

(*---------------------------------------------------------------------------*)

   LOCAL PROCEDURE ConsumeByMessage();
   VAR
      I32, P32 : INT32 := 0;
      sI32, sP32 : ARRAY [0..15] OF WCHAR;
      msg : windows.MSG;
      S : Sync.SIGNAL := Sync.CreateSignal( FALSE, L"" );
   BEGIN
      windows.PeekMessage( ADR( msg ), NIL, 0, 0, windows.PM_REMOVE );
      MH.Init();
  
      LOOP
         IF Exit = 1 THEN
            EXIT;
         ELSE
            windows.MsgWaitForMultipleObjectsEx( 1, ADR( S ), 100, windows.QS_ALLINPUT, windows.MWMO_INPUTAVAILABLE );
            windows.PeekMessage( ADR( msg ), NIL, 0, 0, windows.PM_REMOVE );
         END;
         IF msg.message <> msgqueue.WM_MQ_PROCESS THEN
            CONTINUE;
         END;

         // QUEUE processing
         WHILE MQ.Dequeue( ADR( I32 ), SIZE( I32 ), FALSE, 0 ) = Sync.arCompleted DO
            IF I32 <> P32+1 THEN
               Strings.FromINT32W( I32, 10, OUT sI32 ); Strings.FromINT32W( P32, 10, OUT sP32 );
               Host^.Log^.LogSSSS( log.dlcError, L"", L"Failed on numbers: ", sI32, L"/", sP32 );
               Exit := 1;
               EXIT;
            END;
            INC( P32 );
         END; // WHILE
     END; // LOOP
     
     MH.Dispose();
  END ConsumeByMessage;

(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"MessageQueue", ADR( Test ));
END CTest;

(*===========================================================================*)

END MessageQueue.