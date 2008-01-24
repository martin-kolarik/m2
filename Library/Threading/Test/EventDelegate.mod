MODULE EventDelegate;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   sync,
   test,
   testimpl,
   threadpool,
   windows;
  
(*===========================================================================*)

CLASS CTest IMPLEMENTS test.ITest;
   PUBLIC VAR
      Host : test.TPHost := NIL;
      Count : CARDINAL := 0;
   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
END CTest;

(*---------------------------------------------------------------------------*)

TYPE
   TPTest = POINTER TO CTest;
VAR
   Test : CTest;

(*===========================================================================*)

CLASS CDelegate( threadpool.APoolDelegate );
   PUBLIC VAR
      Test : TPTest;
   LOCAL VIRTUAL PROCEDURE OnHandle( Result : sync.TAsyncResult; PoolHandle, UserId : PTR );
END CDelegate;
  
(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CDelegate;

  LOCAL VIRTUAL PROCEDURE OnHandle( Result : sync.TAsyncResult; PoolHandle, UserId : PTR );
  BEGIN
    sync.IInc( REF Test^.Count );
  END OnHandle;

BEGIN
   Test := NIL;
END CDelegate;

(*===========================================================================*)

CLASS IMPLEMENTATION CTest;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   CONST
      count = 1500;
   VAR
      EA : ARRAY [0..count-1] OF windows.HANDLE;
      DLG : CDelegate;
      Failure : BOOLEAN := FALSE;
      i, j : CARDINAL;
      PH : ARRAY [0..10*count-1] OF windows.HANDLE;
      TP : threadpool.CThreadPool;
   BEGIN
      SELF.Host := Host;
      DLG.Test := ADR( SELF );

      // create handles
      FOR i := 0 TO count-1 DO
         EA[i] := windows.CreateEvent( NIL, windows.True, windows.False, NIL );
      END; // FOR
      
      //==========
      Host^.StartPhase( L"SingleWait/SetEvent in reverted order" );
         // reset
         Count := 0;
         // initiate
         FOR i := 0 TO count-1 DO
            TP.WaitHandle( NIL, i, windows.INFINITE, TRUE, EA[i], OUT PH[i] );
         END; // FOR
         // test
         FOR i := count-1 TO 0 BY -1 DO
            windows.SetEvent( EA[i] );
         END; // FOR
         windows.Sleep( 1000 );
      // check
      IF Count = count THEN
         Host^.StopPhaseWithResult( test.trSuccess );
      ELSE
         Host^.StopPhaseWithResult( test.trFailure );
         Failure := TRUE;
      END;

      //==========
      Host^.StartPhase( L"SingleWait/Abort in reverted order" );
         // reset
         Count := 0;
         FOR i := 0 TO count-1 DO
            windows.ResetEvent( EA[i] );
         END; // FOR
         // initiate
         FOR i := 0 TO count-1 DO
            TP.WaitHandle( NIL, i, windows.INFINITE, TRUE, EA[i], OUT PH[i] );
         END; // FOR
         // test
         FOR i := count-1 TO 0 BY -1 DO
            TP.Abort( REF PH[i] );
         END; // FOR
         windows.Sleep( 1000 );
      // check
      IF Count = count THEN
         Host^.StopPhaseWithResult( test.trSuccess );
      ELSE
         Host^.StopPhaseWithResult( test.trFailure );
         Failure := TRUE;
      END;

(*
      FOR i := 0 TO 1499 DO
         FOR j := 0 TO 9 DO
            TP.WaitHandle( ADR( DLG ), i, windows.INFINITE, TRUE, EA[i], OUT PH[i*10+j] );
         END;
      END; // FOR
*)      

      // done handles
      FOR i := 0 TO 1499 DO
          windows.CloseHandle( EA[i] );
      END; // FOR
   
      TP.FINALLY();
      IF Failure THEN
         RETURN test.trFailure;
      ELSE
         RETURN test.trSuccess;
      END;
   END Run;
   
(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"ThreadPool::EventDelegate", ADR( Test ));
END CTest;

(*===========================================================================*)

END EventDelegate.


(*
  // 4.
  // TP.CompletionInOwningThread := TRUE;
  // FOR i := 14999 TO 0 BY -1 DO
  //   TP.Abort( PH[i] );
  // END; // FOR

  windows.Sleep( 1000 );

  FOR i := 0 TO 1499 DO
    windows.CloseHandle( EA[i] );
  END;

  WHILE windows.GetMessage( ADR( msg ), NIL, 0, 0 ) = windows.True DO
    windows.DispatchMessage( ADR( msg ));
  END; // WHILE
*)  
