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

TYPE
   TMode = ( NN, PN, NC, PC );


CLASS CTest IMPLEMENTS test.ITest;
   PRIVATE VAR
      Host : test.TPHost := NIL;
      Ring : SyncQueue.RingBuffer;
      Exit : CARDINAL := 0;
      Limit : CARD64 := 0;

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR );
   INTERNAL PROCEDURE Round( Mode : TMode; RingSize : CARDINAL ) : BOOLEAN;
   
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

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR );
   TYPE
      TSizes = ARRAY [0..10] OF CARDINAL;
   CONST
      sizes = TSizes( 1, 2, 7, 8, 11, 24, 113, 256, 8191, 8192, 8193 );
   VAR
      Mode : TMode;
      Size : CARDINAL;
   BEGIN
      SELF.Host := Host;
      
      IF Host^.FastEvaluation THEN
         Limit := 10000;
      ELSE
         Limit := 500000;
      END;
   
      FOR Mode := NN TO PC DO
         FOR Size := 0 TO HIGH( sizes ) DO
            Host^.StartParticle();
            Host^.StopParticleWithResult( Round( Mode, sizes[Size] ), L"Round failed." );
         END;
      END;
   END Run;
   
(*---------------------------------------------------------------------------*)

   INTERNAL PROCEDURE Round( Mode : TMode; RingSize : CARDINAL ) : BOOLEAN;
   VAR
      CE : Sync.SIGNAL;
      CT : windows.HANDLE := NIL;
      PE : Sync.SIGNAL;
      PT : windows.HANDLE := NIL;
      Phase : ARRAY [0..31] OF WCHAR;
   BEGIN
      CE.Init( Sync.stEvent, L"", FALSE );
      PE.Init( Sync.stEvent, L"", TRUE );
   
      Exit := 0; // reset
      Ring.FlushSleep := 0;
      Ring.Size := RingSize;
      Ring.Clear();
      
      Strings.FromCARD32W( RingSize, 10, OUT Phase );
      Strings.PrependW( REF Phase, L", bytes: " );      
      CASE Mode OF
      | NN :
         Ring.Consume := NIL;
         Ring.Produce := NIL;
         Strings.PrependW( REF Phase, L"0/0" );
      | PN :
         Ring.Consume := NIL;
         Ring.Produce := ADR( PE );
         Strings.PrependW( REF Phase, L"P/0" );
      | NC :
         Ring.Consume := ADR( CE );
         Ring.Produce := NIL;
         Strings.PrependW( REF Phase, L"0/C" );
      | PC :
         Ring.Consume := ADR( CE );
         Ring.Produce := ADR( PE );
         Strings.PrependW( REF Phase, L"P/C" );
      END; // CASE
      Host^.StartPhase( Phase );

      PT := windows.CreateThread( NIL, 0, ProducerThread, ADR( SELF ), 0, NIL );
      CT := windows.CreateThread( NIL, 0, ConsumerThread, ADR( SELF ), 0, NIL );
      Sync.RawWait( PT, Sync.FOREVER );
      Sync.RawWait( CT, Sync.FOREVER );
      windows.CloseHandle( PT );
      PE.Dispose();
      windows.CloseHandle( CT );
      CE.Dispose();
      
      Host^.StopPhase();
      RETURN Exit = 0;
   END Round;

(*---------------------------------------------------------------------------*)

   LOCAL PROCEDURE Produce();
   VAR
      C64 : CARD64 := 1;
   BEGIN
      LOOP
         Ring.WriteOA( C64 ); // also waits for Produce
         INC( C64 );
         IF C64 > Limit THEN
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
         Ring.ReadOA( OUT C64 ); // also waits for consume
         IF C64 <> P64+1 THEN
            Strings.FromCARD64W( C64, 10, OUT sC64 ); Strings.FromCARD64W( P64, 10, OUT sP64 );
            Host^.Log^.LogSSS( log.lcError, 0, L"", L"Failed on numbers: ", sC64, sP64 );
            Exit := 1;
            EXIT;
         END;
         IF C64 = Limit THEN
            EXIT;
         ELSIF Exit = 1 THEN
            EXIT;
         END;
         INC( P64 );
       END; // LOOP
   END Consume;

(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"RingBuffer", ADR( Test ));
END CTest;

(*===========================================================================*)

END ringbuffer.