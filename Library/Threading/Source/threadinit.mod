IMPLEMENTATION MODULE threadinit;

IMPORT
   SCmsgqueuethread,
   threadpool,
   Win32msgqueuethread;

(*================================================================================*)

PROCEDURE Startup();
BEGIN
   Win32msgqueuethread.Startup();
   SCmsgqueuethread.Startup();
   threadpool.Startup();
END Startup;

(*--------------------------------------------------------------------------------*)

PROCEDURE Cleanup();
BEGIN
   threadpool.Cleanup();
   SCmsgqueuethread.Cleanup();
   Win32msgqueuethread.Cleanup();
END Cleanup;

(*================================================================================*)

END threadinit.