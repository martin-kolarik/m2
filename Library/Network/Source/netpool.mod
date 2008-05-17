IMPLEMENTATION MODULE netpool;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

(*===========================================================================*)

VAR
  NetPool : POINTER TO threadpool.CThreadPool := NIL;

(*===========================================================================*)

PROCEDURE pool() : threadpool.TPThreadPool;
BEGIN
  IF NetPool = NIL THEN
    ASSERT( FALSE ); // netinit.Startup was not called
    Startup();
  END;
  RETURN NetPool;
END pool;

PROCEDURE Startup();
BEGIN
  IF NetPool = NIL THEN
    NEW( NetPool );
    NetPool^.MinThreads := 2; // 1 for handles and messages, 1 for workers
    NetPool^.MaxThreads := 64;
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