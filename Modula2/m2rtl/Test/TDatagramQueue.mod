MODULE TDatagramQueue;

FROM Debug IMPORT
   Assertion;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   log,
   Strings,
   Sync,
   SyncQueue,
   test,
   testimpl,
   windows;
  
(*===========================================================================*)

TYPE
   TMode = ( NN, PN, NC, PC );

CLASS CTest IMPLEMENTS test.ITest;
   PRIVATE VAR
      Host : test.TPHost := NIL;
      DQ   : SyncQueue.CDatagramQueue;
      Exit : CARDINAL := 0;
      
      ThreadCount : CARDINAL;
      ThreadIndex : CARDINAL;
      Threads : ARRAY [0..255] OF Sync.WAITABLE;
      Last : ARRAY [0..255] OF CARDINAL; // should be as long as maximal threads number be

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   INTERNAL PROCEDURE Round( Mode : TMode; ThreadCount : CARDINAL; RingSize : CARDINAL ) : BOOLEAN;
   
   LOCAL PROCEDURE Produce();
   LOCAL PROCEDURE Consume();
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

PROCEDURE ConsumerThread( a : ADDRESS ) : windows.DWORD;
BEGIN
   TPTest( a )^.Consume();
   RETURN 0;
END ConsumerThread;
#restore  

(*===========================================================================*)

CLASS IMPLEMENTATION CTest;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   TYPE
      TSizes = ARRAY [0..3] OF CARDINAL;
   CONST
      sizes = TSizes( 1, 23, 255, 8192 );
      producentThreads = TSizes( 1, 5, 25, 125 );
   VAR
      Failure : BOOLEAN := FALSE;
      Mode : TMode;
      Size : CARDINAL;
      Thread : CARDINAL;
   BEGIN
      SELF.Host := Host;
   
      FOR Mode := NN TO PC DO
         FOR Thread := 0 TO HIGH( producentThreads ) DO
            FOR Size := 0 TO HIGH( sizes ) DO
               ASSERT( producentThreads[Thread] <= HIGH( Last )+1 );
               IF producentThreads[Thread] > sizes[Size] THEN
                  CONTINUE;
               END;
               Failure := NOT Round( Mode, producentThreads[Thread], sizes[Size] ) OR Failure;
            END;
         END;
      END;

      IF Failure THEN
         RETURN test.trFailure;
      ELSE
         RETURN test.trSuccess;
      END;
   END Run;
   
(*---------------------------------------------------------------------------*)

   INTERNAL PROCEDURE Round( Mode : TMode; ThreadCount : CARDINAL; RingSize : CARDINAL ) : BOOLEAN;
   VAR
      CE : Sync.SIGNAL;
      CT : windows.HANDLE := NIL;
      i : CARDINAL;
      PE : Sync.SIGNAL;
      PT : windows.HANDLE := NIL;
      Phase : ARRAY [0..47] OF WCHAR;
      s : ARRAY [0..31] OF WCHAR;
      Success : BOOLEAN;
   BEGIN
      CE.Init( Sync.stEvent, L"", FALSE );
      PE.Init( Sync.stEvent, L"", TRUE );
   
      Exit := 0; // reset
      SELF.ThreadCount := ThreadCount;
      
      DQ.Size := RingSize;
      DQ.ItemSize := SIZE( CARD32 );
      DQ.FlushSleep := 1;
      DQ.Clear();
      
      ThreadIndex := 0;
      FOR i := 0 TO ThreadCount DO // ThreadIndex is started from 1, so array must be filled up to ThreadCount
         Last[i] := 0;
      END;

      CASE Mode OF
      | NN :
         DQ.Consume := NIL;
         DQ.Produce := NIL;
         Phase := L"0/0";
      | PN :
         DQ.Consume := NIL;
         DQ.Produce := ADR( PE );
         Phase := L"P/0";
      | NC :
         DQ.Consume := ADR( CE );
         DQ.Produce := NIL;
         Phase := L"0/C";
      | PC :
         DQ.Consume := ADR( CE );
         DQ.Produce := ADR( PE );
         Phase := L"P/C";
      END; // CASE
      Strings.AppendW( REF Phase, L", threads: " );
      Strings.FromCARD32W( ThreadCount, 10, OUT s );
      Strings.AppendW( REF Phase, s );
      Strings.AppendW( REF Phase, L", items: " );
      Strings.FromCARD32W( RingSize, 10, OUT s );
      Strings.AppendW( REF Phase, s );
      Host^.StartPhase( Phase );

      FOR i := 0 TO ThreadCount-1 DO
         Threads[i] := windows.CreateThread( NIL, 0, ProducerThread, ADR( SELF ), 0, NIL );
      END;
      CT := windows.CreateThread( NIL, 0, ConsumerThread, ADR( SELF ), 0, NIL );
      // wait for all producers      
      FOR i := 0 TO ThreadCount-1 DO
         Sync.RawWait( Threads[i], Sync.FOREVER );
         windows.CloseHandle( Threads[i] );
      END;
      Success := Exit = 0;
      // stop consumer thread
      Exit := 1;
      Sync.RawWait( CT, Sync.FOREVER );
      windows.CloseHandle( CT );

      PE.Dispose();
      CE.Dispose();
      
      Host^.StopPhase();
      RETURN Success;
   END Round;

(*---------------------------------------------------------------------------*)

   LOCAL PROCEDURE Produce();
   VAR
      Index : CARD32 := Sync.IInc( REF ThreadIndex );
      Items : CARDINAL;
      C32 : CARD32 := 1 OR ( Index << 24 );
      Result : Sync.TAsyncResult;
   BEGIN
      IF DQ.Produce = NIL THEN
         Items := 50000 DIV MAX2( 1, ThreadCount DIV 5 );
         IF Host^.FastEvaluation THEN
            Items := Items DIV 200;
         END;
      ELSE
         Items := 1000 DIV ThreadCount;
         IF Host^.FastEvaluation THEN
            Items := Items DIV 200;
         END;
      END;
      
      LOOP
         LOOP
            Result := DQ.EnqueueOA( C32, TRUE, 1000 );
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
         IF C32 AND 0FFFFFFH > Items THEN
            EXIT;
         END;
      END;
   END Produce;

(*---------------------------------------------------------------------------*)

   LOCAL PROCEDURE Consume();
   VAR
      C32 : CARD32 := 0;
      Index : CARD32;
      sC32, sP32 : ARRAY [0..15] OF WCHAR;
      Result : Sync.TAsyncResult;
   BEGIN
      LOOP
         LOOP
            Result := DQ.DequeueOA( OUT C32, TRUE, 10 );
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
   END Consume;

(*---------------------------------------------------------------------------*)

BEGIN
   ThreadCount := 0;
   ThreadIndex := 0;
   Last[0] := 0;
   Threads[0] := NIL;

   testimpl.tests()^.AddTest( L"DatagramQueue", ADR( Test ));
END CTest;

(*===========================================================================*)

END TDatagramQueue.