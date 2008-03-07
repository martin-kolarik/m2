MODULE TQuadwordQueue;

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
      QQ   : SyncQueue.QuadwordQueue;
      Exit : CARDINAL := 0;

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
      TSizes = ARRAY [0..8] OF CARDINAL;
   CONST
      sizes = TSizes( 8, 9, 11, 24, 113, 256, 8191, 8192, 8193 );
   VAR
      Failure : BOOLEAN := FALSE;
      Size : CARDINAL;
   BEGIN
      SELF.Host := Host;
   
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
      CE : Sync.SIGNAL := Sync.CreateSignal( FALSE, L"" );
      CT : windows.HANDLE := NIL;
      PE : Sync.SIGNAL := Sync.CreateSignal( TRUE, L"" );
      PT : windows.HANDLE := NIL;
      Phase : ARRAY [0..31] OF WCHAR;
   BEGIN
      Exit := 0; // reset
      QQ.Size := RingSize;
      QQ.Clear();
      
      Strings.FromCARD32W( RingSize, 10, OUT Phase );
      Strings.PrependW( REF Phase, L"Bytes: " );      
      Host^.StartPhase( Phase );

      PT := windows.CreateThread( NIL, 0, ProducerThread, ADR( SELF ), 0, NIL );
      CT := windows.CreateThread( NIL, 0, ConsumerThread, ADR( SELF ), 0, NIL );
      Sync.Wait( PT, Sync.FOREVER );
      Sync.Wait( CT, Sync.FOREVER );
      windows.CloseHandle( PT );
      Sync.DeleteSignal( REF PE );
      windows.CloseHandle( CT );
      Sync.DeleteSignal( REF CE );
      
      Host^.StopPhase();
      RETURN Exit = 0;
   END Round;

(*---------------------------------------------------------------------------*)

   LOCAL PROCEDURE Produce();
   VAR
      I64 : INT64 := 1;
   BEGIN
      LOOP
         QQ.Queue( I64, TRUE, Sync.FOREVER );
         INC( I64 );
         IF I64 > 500000 THEN
            EXIT;
         ELSIF Exit = 1 THEN
            EXIT;
         END;
      END;
   END Produce;

(*---------------------------------------------------------------------------*)

   LOCAL PROCEDURE Consume();
   VAR
      I64, P64 : INT64 := 0;
      sI64, sP64 : ARRAY [0..15] OF WCHAR;
   BEGIN
      LOOP
         QQ.Dequeue( OUT I64, TRUE, Sync.FOREVER );
         IF I64 <> P64+1 THEN
            Strings.FromINT64W( I64, 10, OUT sI64 ); Strings.FromINT64W( P64, 10, OUT sP64 );
            Host^.Log^.LogSSSS( log.dlcError, L"", L"Failed on numbers: ", sI64, L"/", sP64 );
            Exit := 1;
            EXIT;
         END;
         IF I64 = 500000 THEN
            EXIT;
         ELSIF Exit = 1 THEN
            EXIT;
         END;
         INC( P64 );
       END; // LOOP
   END Consume;

(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"QuadwordQueue", ADR( Test ));
END CTest;

(*===========================================================================*)

END TQuadwordQueue.