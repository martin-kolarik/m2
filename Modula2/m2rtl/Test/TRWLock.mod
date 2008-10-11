MODULE TRWLock;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   log,
   Strings,
   Sync,
   SyncQueue,
   test,
   testimpl,
   time,
   windows;
  
(*===========================================================================*)

CLASS CTest IMPLEMENTS test.ITest;
   PRIVATE VAR
      Host : test.TPHost := NIL;
      Exit : CARDINAL := 0;

      RWLock : Sync.RWLOCK;
      Shared : ARRAY [0..15] OF CARDINAL;
      
      ReaderCount : CARDINAL;
      Threads : ARRAY [0..255] OF Sync.WAITABLE;

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   INTERNAL PROCEDURE Round( WriterCount, ReaderCount : CARDINAL ) : BOOLEAN;
   
   LOCAL PROCEDURE Write();
   LOCAL PROCEDURE Read();

   INITIALLY CTest;
END CTest;

(*---------------------------------------------------------------------------*)

TYPE
   TPTest = POINTER TO CTest;
VAR
   Test : CTest;

(*---------------------------------------------------------------------------*)

#save, call( convention => stdcall )
PROCEDURE WriterThread( a : ADDRESS ) : windows.DWORD;
BEGIN
   TPTest( a )^.Write();
   RETURN 0;
END WriterThread;

PROCEDURE ReaderThread( a : ADDRESS ) : windows.DWORD;
BEGIN
   TPTest( a )^.Read();
   RETURN 0;
END ReaderThread;
#restore  

(*===========================================================================*)

CLASS IMPLEMENTATION CTest;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   TYPE
      TThreads = ARRAY [0..3] OF CARDINAL;
   CONST
      writerThreads = TThreads( 1, 5, 25, 125 );
   VAR
      Failure : BOOLEAN := FALSE;
      Thread : CARDINAL;
   BEGIN
      SELF.Host := Host;
   
      FOR Thread := 0 TO HIGH( writerThreads ) DO
         Failure := NOT Round( 1, writerThreads[Thread] ) OR Failure;
         Failure := NOT Round( 2, writerThreads[Thread] ) OR Failure;
      END;

      IF Failure THEN
         RETURN test.trFailure;
      ELSE
         RETURN test.trSuccess;
      END;
   END Run;
   
(*---------------------------------------------------------------------------*)

   INTERNAL PROCEDURE Round( WriterCount, ReaderCount : CARDINAL ) : BOOLEAN;
   VAR
      i : CARDINAL;
      Phase : ARRAY [0..47] OF WCHAR;
      s : ARRAY [0..31] OF WCHAR;
      Success : BOOLEAN;
      WT1, WT2 : windows.HANDLE;
   BEGIN
      Exit := 0; // reset
      SELF.ReaderCount := ReaderCount;
      
      Phase := L"Readers: ";
      Strings.FromCARD32W( ReaderCount, 10, OUT s );
      Strings.AppendW( REF Phase, s );
      Strings.AppendW( REF Phase, L", writers: " );
      Strings.FromCARD32W( WriterCount, 10, OUT s );
      Strings.AppendW( REF Phase, s );
      Host^.StartPhase( Phase );

      FOR i := 0 TO ReaderCount-1 DO
         Threads[i] := windows.CreateThread( NIL, 0, ReaderThread, ADR( SELF ), 0, NIL );
      END;
      WT1 := windows.CreateThread( NIL, 0, WriterThread, ADR( SELF ), 0, NIL );
      IF WriterCount > 1 THEN
         WT2 := windows.CreateThread( NIL, 0, WriterThread, ADR( SELF ), 0, NIL );
      END;

      // wait for writer thread
      Sync.RawWait( WT1, Sync.FOREVER ); windows.CloseHandle( WT1 );
      IF WriterCount > 1 THEN
         Sync.RawWait( WT2, Sync.FOREVER ); windows.CloseHandle( WT2 );
      END;

      // stop reader threads
      Exit := 1;

      // wait for all readers
      FOR i := 0 TO ReaderCount-1 DO
         Sync.RawWait( Threads[i], Sync.FOREVER );
         windows.CloseHandle( Threads[i] );
      END;
      Success := Exit = 0;

      Host^.StopPhase();
      RETURN Success;
   END Round;

(*---------------------------------------------------------------------------*)

   LOCAL PROCEDURE Write();
   CONST
      INIT_COUNT = 100000;
   VAR
      count : CARDINAL := 0;
      i : CARDINAL;
      stop : CARDINAL := INIT_COUNT DIV ReaderCount;
   BEGIN
      LOOP
         RWLock.LockWrite( Sync.FOREVER );

         Shared[0] := time.UptimeMS() MOD 1000;
         FOR i := 1 TO HIGH( Shared ) DO
            IF i MOD 2 = 0 THEN
               Sync.Sleep( 0 );
            END;
            Shared[i] := Shared[i-1] + 1;
         END;
         
         RWLock.UnlockWrite();

         INC( count );
         IF count = stop THEN
            EXIT;
         ELSE
            Sync.Sleep( Shared[0] MOD 3 );
         END;
      END;
   END Write;

(*---------------------------------------------------------------------------*)

   LOCAL PROCEDURE Read();
   VAR
      i, value : CARDINAL;
   BEGIN
      LOOP
         RWLock.LockRead( Sync.FOREVER );

         value := Shared[0];
         FOR i := 1 TO HIGH( Shared ) DO
            INC( value );
            IF value <> Shared[i] THEN // error
               Host^.Log^.LogSC( log.dlcError, L"", L"Expected value: ", value );
               Host^.Log^.LogSC( log.dlcError, L"", L"   found value: ", Shared[i] );
            END;
         END;
         
         RWLock.UnlockRead();

         IF Exit = 1 THEN
            EXIT;
         ELSE
            windows.Sleep( 0 );
         END;
      END; // LOOP
   END Read;

(*---------------------------------------------------------------------------*)

   INITIALLY CTest;
   VAR
      i : CARDINAL;
   BEGIN
      ReaderCount := 0;
      Threads[0] := NIL;
   
      FOR i := 0 TO HIGH( Shared ) DO
         Shared[i] := i;
      END; // FOR

      testimpl.tests()^.AddTest( L"RWLock", ADR( Test ));
   END CTest;
      
(*---------------------------------------------------------------------------*)

END CTest;

(*===========================================================================*)

END TRWLock.