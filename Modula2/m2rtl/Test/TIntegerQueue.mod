MODULE TIntegerQueue;

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

CLASS CTest IMPLEMENTS test.ITest;
   PRIVATE VAR
      Host : test.TPHost := NIL;
      IQ   : SyncQueue.IntegerQueue;
      Exit : CARDINAL := 0;
      Limit : INT32 := 0;

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   INTERNAL PROCEDURE Round( RingSize : CARDINAL ) : BOOLEAN;
   
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
      TSizes = ARRAY [0..9] OF CARDINAL;
   CONST
      sizes = TSizes( 5, 7, 8, 11, 24, 113, 256, 8191, 8192, 8193 );
   VAR
      Failure : BOOLEAN := FALSE;
      Size : CARDINAL;
   BEGIN
      SELF.Host := Host;
      
      IF Host^.FastEvaluation THEN
         Limit := 50000;
      ELSE
         Limit := 500000;
      END;
   
      FOR Size := 0 TO HIGH( sizes ) DO
         Failure := NOT Round( sizes[Size] ) OR Failure;
      END;

      IF Failure THEN
         RETURN test.trFailure;
      ELSE
         RETURN test.trSuccess;
      END;
   END Run;
   
(*---------------------------------------------------------------------------*)

   INTERNAL PROCEDURE Round( RingSize : CARDINAL ) : BOOLEAN;
   VAR
      CT : windows.HANDLE := NIL;
      PT : windows.HANDLE := NIL;
      Phase : ARRAY [0..31] OF WCHAR;
   BEGIN
      Exit := 0; // reset
      IQ.Size := RingSize;
      IQ.FlushSleep := 0;
      IQ.Clear();
      
      Strings.FromCARD32W( RingSize, 10, OUT Phase );
      Strings.PrependW( REF Phase, L"Bytes: " );      
      Host^.StartPhase( Phase );

      PT := windows.CreateThread( NIL, 0, ProducerThread, ADR( SELF ), 0, NIL );
      CT := windows.CreateThread( NIL, 0, ConsumerThread, ADR( SELF ), 0, NIL );
      Sync.RawWait( PT, Sync.FOREVER );
      Sync.RawWait( CT, Sync.FOREVER );
      windows.CloseHandle( PT );
      windows.CloseHandle( CT );
      
      Host^.StopPhase();
      RETURN Exit = 0;
   END Round;

(*---------------------------------------------------------------------------*)

   LOCAL PROCEDURE Produce();
   VAR
      I32 : INT32 := 1;
   BEGIN
      LOOP
         IQ.Enqueue( I32, TRUE, Sync.FOREVER );
         INC( I32 );
         IF I32 > Limit THEN
            EXIT;
         ELSIF Exit = 1 THEN
            EXIT;
         END;
      END;
   END Produce;

(*---------------------------------------------------------------------------*)

   LOCAL PROCEDURE Consume();
   VAR
      I32, P32 : INT32 := 0;
      sI32, sP32 : ARRAY [0..15] OF WCHAR;
   BEGIN
      LOOP
         IQ.Dequeue( OUT I32, TRUE, Sync.FOREVER );
         IF I32 <> P32+1 THEN
            Strings.FromINT32W( I32, 10, OUT sI32 ); Strings.FromINT32W( P32, 10, OUT sP32 );
            Host^.Log^.LogSSSS( log.lcError, 0, L"", L"Failed on numbers: ", sI32, L"/", sP32 );
            Exit := 1;
            EXIT;
         END;
         IF I32 = Limit THEN
            EXIT;
         ELSIF Exit = 1 THEN
            EXIT;
         END;
         INC( P32 );
       END; // LOOP
   END Consume;

(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"IntegerQueue", ADR( Test ));
END CTest;

(*===========================================================================*)

END TIntegerQueue.