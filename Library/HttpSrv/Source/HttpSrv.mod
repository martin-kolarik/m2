IMPLEMENTATION MODULE HttpSrv;

IMPORT
   SrvHttpApi;

(*================================================================================*)

PROCEDURE srv() : TPHttpServer;
BEGIN
   RETURN SrvHttpApi.srv();
END srv;

(*--------------------------------------------------------------------------------*)

PROCEDURE Cleanup();
BEGIN
   SrvHttpApi.Cleanup();
END Cleanup;

(*================================================================================*)

END HttpSrv.