IMPLEMENTATION MODULE scinit;

IMPORT
   netinit,
   threadinit;

PROCEDURE Startup();
BEGIN
   threadinit.Startup();
   netinit.Startup();
END Startup;

PROCEDURE Cleanup();
BEGIN
   netinit.Cleanup();
   threadinit.Cleanup();
END Cleanup;

(*# restore *)

END scinit.