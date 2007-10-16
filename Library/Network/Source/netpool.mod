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
    Startup();
  END;
  RETURN NetPool;
END Pool;

PROCEDURE Startup();
BEGIN
  NEW( NetPool );
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