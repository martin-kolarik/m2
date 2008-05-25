MODULE Timers;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   log,
   msghandler,
   msgqueuethread,
   sync,
   test,
   testimpl,
   thread,
   threadinit,
   windows;
  
(*===========================================================================*)

CONST
   count = 20;

TYPE
   TPTest = POINTER TO CTest;
   TPWorker = POINTER TO CWorker;

(*---------------------------------------------------------------------------*)

CLASS CWorker IMPLEMENTS thread.IRunnable;
   PUBLIC VAR
      Test : TPTest;
   INTERNAL VIRTUAL PROCEDURE OnRun() : CARDINAL;
END CWorker;

(*---------------------------------------------------------------------------*)

CLASS CMH( msghandler.MessageHandler );
   PUBLIC VAR
      Test : TPTest;
   PUBLIC VIRTUAL PROCEDURE OnJoin( CONST JoinedTo : msgqueuethread.IMessageQueueThread );
   INTERNAL VIRTUAL PROCEDURE OnTimer( TimerId : PTR );
END CMH;

(*---------------------------------------------------------------------------*)

CLASS CTest IMPLEMENTS test.ITest;
   PUBLIC VAR
      Count : CARDINAL := 0;
      CountingStops : BOOLEAN := FALSE;
      Host : test.TPHost := NIL;
      Handler : POINTER TO CMH;
      Threads : ARRAY [0..count-1] OF thread.TPThread;
      Worker : CWorker;
      Exit : CARDINAL := 0;

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
END CTest;

VAR
   Test : CTest;
   Index : CARDINAL := 0;

(*===========================================================================*)

CLASS IMPLEMENTATION CWorker;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnRun() : CARDINAL;
   VAR
      i : CARDINAL;
      LIndex : CARDINAL := sync.IInc( REF Index );
   BEGIN 
      FOR i := 0 TO 199 DO
         Test^.Handler^.StartTimer( 1000 * LIndex + i, 1000 + i, FALSE );
         sync.Sleep( 20 );
      END;
      RETURN 0;
   END OnRun;

(*---------------------------------------------------------------------------*)

BEGIN
   Test := NIL;
END CWorker;

(*===========================================================================*)

CLASS IMPLEMENTATION CMH;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnJoin( CONST JoinedTo : msgqueuethread.IMessageQueueThread );
   BEGIN
      SUPER.OnJoin( JoinedTo );
   
      StartTimer( 1, 1000, TRUE );
      StartTimer( 2, 2000, TRUE );
      StartTimer( 3, 3000, TRUE );
      StartTimer( 4, 4000, TRUE );
      StartTimer( 12, 12000, FALSE );
   END OnJoin;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnTimer( TimerId : PTR );
   BEGIN
      IF Test^.CountingStops THEN
         INC( Test^.Count );
      
      ELSE
         Test^.Host^.Log^.LogSC( log.dlcInfo, L"", L"  Timer: ", CARDINAL( TimerId ));
         INC( Test^.Count, TimerId );

         IF TimerId = 12 THEN
           // check
           IF TimerRunning( 1 ) THEN
              StopTimer( 1 );
           ELSE
              Test^.Host^.Log^.LogSC( log.dlcError, L"", L"Unexpectedly NOT running: ", 1 );
           END;
           IF TimerRunning( 1 ) THEN
              Test^.Host^.Log^.LogSC( log.dlcError, L"", L"Unexpectedly running: ", 1 );
           END;

           IF TimerRunning( 2 ) THEN
              StopTimer( 2 );
           ELSE
              Test^.Host^.Log^.LogSC( log.dlcError, L"", L"Unexpectedly NOT running: ", 2 );
           END;
           IF TimerRunning( 2 ) THEN
              Test^.Host^.Log^.LogSC( log.dlcError, L"", L"Unexpectedly running: ", 2 );
           END;

           IF TimerRunning( 3 ) THEN
              StopTimer( 3 );
           ELSE
              Test^.Host^.Log^.LogSC( log.dlcError, L"", L"Unexpectedly NOT running: ", 3 );
           END;
           IF TimerRunning( 3 ) THEN
              Test^.Host^.Log^.LogSC( log.dlcError, L"", L"Unexpectedly running: ", 3 );
           END;

           IF TimerRunning( 4 ) THEN
              StopTimer( 4 );
           ELSE
              Test^.Host^.Log^.LogSC( log.dlcError, L"", L"Unexpectedly NOT running: ", 4 );
           END;
           IF TimerRunning( 4 ) THEN
              Test^.Host^.Log^.LogSC( log.dlcError, L"", L"Unexpectedly running: ", 4 );
           END;

           IF TimerRunning( 12 ) THEN
              Test^.Host^.Log^.LogSC( log.dlcError, L"", L"Unexpectedly running: ", 12 );
              StopTimer( 12 );
           END;
            
           Test^.Exit := 1;        
         END;
      END;
   END OnTimer;

(*---------------------------------------------------------------------------*)

BEGIN
   Test := NIL;
END CMH;

(*===========================================================================*)

CLASS IMPLEMENTATION CTest;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   VAR
      Failure : BOOLEAN := FALSE;
      i, LCount : CARDINAL;
   BEGIN
      threadinit.Startup();
      SELF.Host := Host;
   
      NEW( Handler );
      Handler^.Test := ADR( SELF );
      Worker.Test := ADR( SELF );

      //-----      
      Host^.StartPhase( L"4 timers controlled in thread" );
      Exit := 0;
      Count := 0;
      CountingStops := FALSE;
      Handler^.Init( TRUE );
      
      REPEAT
        sync.Sleep( 50 );
      UNTIL Exit = 1;
      sync.Sleep( 50 );

      IF Count = 50 THEN
         Host^.StopPhaseWithResult( test.trSuccess );
      ELSE
         Host^.StopPhaseWithResult( test.trFailure );
      END;

      //-----      
      Host^.StartPhase( L"4 timers started out of thread" );
      Exit := 0;
      Count := 0;
      CountingStops := FALSE;

      Handler^.StartTimer( 1, 1000, TRUE );
      Handler^.StartTimer( 2, 2000, TRUE );
      Handler^.StartTimer( 3, 3000, TRUE );
      Handler^.StartTimer( 4, 4000, TRUE );
      Handler^.StartTimer( 12, 12000, FALSE );

      REPEAT
        sync.Sleep( 50 );
      UNTIL Exit = 1;
      sync.Sleep( 50 );

      IF Count = 50 THEN
         Host^.StopPhaseWithResult( test.trSuccess );
      ELSE
         Host^.StopPhaseWithResult( test.trFailure );
      END;

      //-----      
      Host^.StartPhase( L"20 threads each making 200 not repeated timers" );
      Exit := 0;
      Count := 0;
      CountingStops := TRUE;
      
      FOR i := 0 TO HIGH( Threads ) DO
         NEW( Threads[i] );
         Threads[i]^.RunWithRunnable( ADR( Worker ));
      END;

      FOR i := 0 TO HIGH( Threads ) DO
         Threads[i]^.Stop( TRUE );
         DISPOSE( Threads[i] );
      END;

      LCount := 200;
      REPEAT
         sync.Sleep( 50 );
         DEC( LCount );
         IF LCount = 0 THEN
            EXIT;
         END;
      UNTIL Count = 4000;

      IF Count = 4000 THEN
         Host^.StopPhaseWithResult( test.trSuccess );
      ELSE
         Host^.StopPhaseWithResult( test.trFailure );
      END;

      DISPOSE( Handler );
      threadinit.Cleanup();

      IF Failure THEN
         RETURN test.trFailure;
      ELSE
         RETURN test.trSuccess;
      END;
   END Run;
   
(*---------------------------------------------------------------------------*)

BEGIN
   Handler := NIL;
   Threads[0] := NIL;
   testimpl.tests()^.AddTest( L"MessageHander::Timers", ADR( Test ));
END CTest;

(*===========================================================================*)

END Timers.
