MODULE ringbuffer;

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
      Ring : SyncQueue.RingBuffer;
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
   VAR
      Failure : BOOLEAN := FALSE;
   BEGIN
      SELF.Host := Host;
   
      Failure := NOT Round( 1 ) OR Failure;
      Failure := NOT Round( 2 ) OR Failure;
      Failure := NOT Round( 7 ) OR Failure;
      Failure := NOT Round( 8 ) OR Failure;
      Failure := NOT Round( 11 ) OR Failure;
      Failure := NOT Round( 24 ) OR Failure;
      Failure := NOT Round( 113 ) OR Failure;
      Failure := NOT Round( 256 ) OR Failure;
      Failure := NOT Round( 8191 ) OR Failure;
      Failure := NOT Round( 8192 ) OR Failure;
      Failure := NOT Round( 8193 ) OR Failure;

      IF Failure THEN
         RETURN test.trFailure;
      ELSE
         RETURN test.trSuccess;
      END;
   END Run;
   
(*---------------------------------------------------------------------------*)

   INTERNAL PROCEDURE Round( RingSize : CARDINAL ) : BOOLEAN;
   VAR
      PT : windows.HANDLE := NIL;
      CT : windows.HANDLE := NIL;
      Phase : ARRAY [0..31] OF WCHAR;
   BEGIN
      Exit := 0; // reset
      Ring.Size := RingSize; 

      Strings.FromCARD32W( RingSize, 10, OUT Phase );
      Strings.PrependW( REF Phase, L"Ring size [bytes]: " );      
      Host^.StartPhase( Phase );

      PT := windows.CreateThread( NIL, 0, ProducerThread, ADR( SELF ), 0, NIL );
      CT := windows.CreateThread( NIL, 0, ConsumerThread, ADR( SELF ), 0, NIL );
      Sync.Wait( PT, Sync.INFINITE_TIME );
      Sync.Wait( CT, Sync.INFINITE_TIME );
      windows.CloseHandle( PT );
      windows.CloseHandle( CT );
      
      Host^.StopPhase();
      RETURN Exit = 0;
   END Round;

(*---------------------------------------------------------------------------*)

   LOCAL PROCEDURE Produce();
   VAR
      C64 : CARD64 := 1;
   BEGIN
      LOOP
         Ring.WriteOA( C64 );
         INC( C64 );
         IF C64 > 500000 THEN
            EXIT;
         ELSIF Exit = 1 THEN
            EXIT;
         END;
      END;
   END Produce;

(*---------------------------------------------------------------------------*)

   LOCAL PROCEDURE Consume();
   VAR
      C64, P64 : CARD64 := 0;
      sC64, sP64 : ARRAY [0..15] OF WCHAR;
   BEGIN
      LOOP
         Ring.ReadOA( OUT C64 );
         IF C64 <> P64+1 THEN
            Strings.FromCARD64W( C64, 10, OUT sC64 ); Strings.FromCARD64W( P64, 10, OUT sP64 );
            Host^.Log^.LogSSS( log.dlcError, L"", L"Failed on numbers: ", sC64, sP64 );
            Exit := 1;
            EXIT;
         END;
         IF C64 = 500000 THEN
            EXIT;
         ELSIF Exit = 1 THEN
            EXIT;
         END;
         INC( P64 );
       END; // LOOP
   END Consume;

(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"Ring buffer", ADR( Test ));
END CTest;

(*===========================================================================*)

END ringbuffer.