MODULE BufferQueue;

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
   threadinit,
   windows;
  
(*---------------------------------------------------------------------------*)

TYPE
   TPTest = POINTER TO CTest;

(*===========================================================================*)

CLASS CMH( msghandler.MessageHandler );
   PUBLIC VAR
      Test : TPTest := NIL;
   INTERNAL VIRTUAL PROCEDURE OnMessage( CONST MSG : msghandler.IMessage; OUT Result : PTR ) : BOOLEAN;
END CMH;

(*---------------------------------------------------------------------------*)

CLASS CTest IMPLEMENTS test.ITest;
   PRIVATE VAR
      Host : test.TPHost := NIL;
      MH : CMH;
      MQ : msgqueue.CBufferQueue;
      Exit : CARDINAL := 0;
      Limit : CARDINAL := 0;

      ThreadCount : CARDINAL;
      ThreadIndex : CARDINAL;
      Threads : ARRAY [0..255] OF Sync.WAITABLE;
      Last : ARRAY [0..255] OF CARDINAL; // should be as long as maximal threads number be

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   INTERNAL PROCEDURE Round( ConsumeByEvent : BOOLEAN; producentThreads : CARDINAL; ItemSize : CARDINAL ) : BOOLEAN;
   
   LOCAL PROCEDURE Produce();
   LOCAL PROCEDURE ConsumeByEvent();
   LOCAL PROCEDURE ConsumeByMessage();
END CTest;

(*---------------------------------------------------------------------------*)

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
#restore  

(*===========================================================================*)

CLASS IMPLEMENTATION CMH;

   INTERNAL VIRTUAL PROCEDURE OnMessage( CONST MSG : msghandler.IMessage; OUT Result : PTR ) : BOOLEAN;
   BEGIN
      IF MSG.Message = msgqueue.MSG_PROCESS_QUEUE THEN
         Test^.ConsumeByMessage();
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END OnMessage;

BEGIN
END CMH;

(*===========================================================================*)

CLASS IMPLEMENTATION CTest;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   TYPE
      TSizes = ARRAY [0..3] OF CARDINAL;
   CONST
      producentThreads = TSizes( 1, 5, 25, 125 );
      sizes = TSizes( SIZE( INT32 ), -1, 32, 256 );
   VAR
      Failure : BOOLEAN := FALSE;
      Mode : BOOLEAN;
      Size : CARDINAL;
      Thread : CARDINAL;
   BEGIN
      threadinit.Startup();
   
      SELF.Host := Host;
      MH.Test := ADR( SELF );
      MH.Init( TRUE );
      
      IF Host^.FastEvaluation THEN
         Limit := 5000;
      ELSE
         Limit := 50000;
      END;

      FOR Mode := FALSE TO TRUE DO
         FOR Thread := 0 TO HIGH( producentThreads ) DO
            FOR Size := 0 TO HIGH( sizes ) DO
               Failure := NOT Round( Mode, producentThreads[Thread], sizes[Size] ) OR Failure;
            END;
         END;
      END;
      
      MH.Dispose();

      windows.Sleep( 100 );
      threadinit.Cleanup();

      IF Failure THEN
         RETURN test.trFailure;
      ELSE
         RETURN test.trSuccess;
      END;
   END Run;
   
(*---------------------------------------------------------------------------*)

   INTERNAL PROCEDURE Round( ConsumeByEvent : BOOLEAN; producentThreads : CARDINAL; ItemSize : CARDINAL ) : BOOLEAN;
   VAR
      CT : windows.HANDLE := NIL;
      i : CARDINAL;
      PT : windows.HANDLE := NIL;
      Phase : ARRAY [0..47] OF WCHAR;
      s : ARRAY [0..31] OF WCHAR;
      Success : BOOLEAN;
   BEGIN
      Exit := 0; // reset
      MQ.Clear();
      MQ.ItemSize := ItemSize;
      MQ.Produce := Sync.CreateSignal( Sync.stEvent, L"", TRUE );
      IF ConsumeByEvent THEN
         MQ.Consume := Sync.CreateSignal( Sync.stEvent, L"", FALSE );
         MQ.Consumer := NIL;
      ELSE
         MQ.Consume := NIL;
         MQ.Consumer := ADR( MH );
      END;
      ThreadCount := producentThreads;
      
      ThreadIndex := 0;
      FOR i := 0 TO ThreadCount DO // ThreadIndex is started from 1, so array must be filled up to ThreadCount
         Last[i] := 0;
      END;

      IF ConsumeByEvent THEN
         Phase := L"Evt";
      ELSE
         Phase := L"Msg";
      END; // CASE
      Strings.AppendW( REF Phase, L", threads: " );
      Strings.FromCARD32W( ThreadCount, 10, OUT s );
      Strings.AppendW( REF Phase, s );
      Strings.AppendW( REF Phase, L", items: " );
      Strings.FromCARD32W( ItemSize, 10, OUT s );
      Strings.AppendW( REF Phase, s );
      Host^.StartPhase( Phase );

      IF ConsumeByEvent THEN
         CT := windows.CreateThread( NIL, 0, ConsumerThreadByEvent, ADR( SELF ), 0, NIL );
      ELSE
         CT := NIL;
      END;
      
      FOR i := 0 TO ThreadCount-1 DO
         Threads[i] := windows.CreateThread( NIL, 0, ProducerThread, ADR( SELF ), 0, NIL );
      END;
      // wait for all producers      
      FOR i := 0 TO ThreadCount-1 DO
         IF Sync.RawWait( Threads[i], Sync.FORSAFETY ) = Sync.arTimeout THEN
            // show error
         END;
         windows.CloseHandle( Threads[i] );
      END;

      Success := Exit = 0;

      IF CT = NIL THEN
         // wait for consumer
         windows.Sleep( 100 );
      ELSE
         // stop consumer thread
         Exit := 1;
         IF Sync.RawWait( CT, Sync.FORSAFETY ) = Sync.arTimeout THEN
            // show error
         END;
         windows.CloseHandle( CT );
      END;

      Host^.StopPhase();
      RETURN Success;
   END Round;

(*---------------------------------------------------------------------------*)

   LOCAL PROCEDURE Produce();
   VAR
      Index : CARD32 := Sync.IInc( REF ThreadIndex );
      C32 : CARD32 := 1 OR ( Index << 24 );
      Result : Sync.TAsyncResult;
   BEGIN
      LOOP
         LOOP
            Result := MQ.Enqueue( ADR( C32 ), SIZE( C32 ), TRUE, 1000 );
            IF Result = Sync.arCompleted THEN
               EXIT;
            ELSIF Exit = 1 THEN
               EXIT;
            END;
         END;
         IF Exit = 1 THEN
            EXIT;
         END;

         INC( C32 );
         IF C32 AND 0FFFFFFH > Limit DIV ( 2 * ThreadCount ) THEN
            EXIT;
         END;
      END;
   END Produce;

(*---------------------------------------------------------------------------*)

   LOCAL PROCEDURE ConsumeByEvent();
   VAR
      C32 : CARD32 := 0;
      Index : CARD32;
      sC32, sP32 : ARRAY [0..15] OF WCHAR;
      Result : Sync.TAsyncResult;
   BEGIN
      LOOP

         LOOP
            Result := MQ.DequeueOA( OUT C32, TRUE, 10 );
            IF Result = Sync.arCompleted THEN
               EXIT;
            ELSIF Exit = 1 THEN
               EXIT;
            END;
         END;
         IF Exit = 1 THEN
            EXIT;
         END;

         Index := C32 >> 24;
         C32 := C32 AND 0FFFFFFH;
         IF C32 <> Last[Index]+1 THEN
            Strings.FromCARD32W( C32, 10, OUT sC32 ); Strings.FromCARD32W( Last[Index], 10, OUT sP32 );
            Host^.Log^.LogSSSS( log.dlcError, L"", L"Failed on numbers: ", sC32, L"/", sP32 );
            Exit := 1;
            EXIT;
         END;
         INC( Last[Index] );

      END; // LOOP
   END ConsumeByEvent;

(*---------------------------------------------------------------------------*)

   LOCAL PROCEDURE ConsumeByMessage();
   VAR
      C32 : CARD32 := 0;
      Index : CARD32;
      sC32, sP32 : ARRAY [0..15] OF WCHAR;
   BEGIN
      // QUEUE processing
      WHILE MQ.Dequeue( ADR( C32 ), SIZE( C32 ), FALSE, 0 ) = Sync.arCompleted DO

         Index := C32 >> 24;
         C32 := C32 AND 0FFFFFFH;
         IF C32 <> Last[Index]+1 THEN
            Strings.FromCARD32W( C32, 10, OUT sC32 ); Strings.FromCARD32W( Last[Index], 10, OUT sP32 );
            Host^.Log^.LogSSSS( log.dlcError, L"", L"Failed on numbers: ", sC32, L"/", sP32 );
            Exit := 1;
            EXIT;
         END;
         INC( Last[Index] );

      END; // WHILE
   END ConsumeByMessage;

(*---------------------------------------------------------------------------*)

BEGIN
   ThreadCount := 0;
   ThreadIndex := 0;
   Last[0] := 0;
   Threads[0] := NIL;

   testimpl.tests()^.AddTest( L"Threading::BufferQueue", ADR( Test ));
END CTest;

(*===========================================================================*)

END BufferQueue.