IMPLEMENTATION MODULE netpool;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

(*===========================================================================*)

VAR
  NetPool : POINTER TO threadpool.CThreadPool := NIL;

(*===========================================================================*)

PROCEDURE Pool() : threadpool.TPThreadPool;
BEGIN
  IF NetPool = NIL THEN
    ASSERT( FALSE ); // netinit.Startup was not called
    Startup();
  END;
  RETURN NetPool;
END Pool;

PROCEDURE Startup();
BEGIN
  IF NetPool = NIL THEN
    NEW( NetPool );
    NetPool^.MinThreads := 2; // 1 for handles and messages, 1 for workers
  END;
END Startup;

PROCEDURE Cleanup();
BEGIN
  IF NetPool <> NIL THEN
    NetPool^.FinishAndWait();
    DISPOSE( NetPool );
  END;
END Cleanup;

(*===========================================================================*)

END netpool.