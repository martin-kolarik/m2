IMPLEMENTATION MODULE threadinit;

IMPORT
   msgqueuethread,
   threadpool;

(*================================================================================*)

PROCEDURE Startup();
BEGIN
   msgqueuethread.Startup();
   threadpool.Startup();
END Startup;

(*--------------------------------------------------------------------------------*)

PROCEDURE Cleanup();
BEGIN
   threadpool.Cleanup();
   msgqueuethread.Cleanup();
END Cleanup;

(*================================================================================*)

END threadinit.