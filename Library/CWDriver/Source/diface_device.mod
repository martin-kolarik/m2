IMPLEMENTATION MODULE diface_device;

(*================================================================================*)

CLASS IMPLEMENTATION CCWDriverSkeleton;

(*--------------------------------------------------------------------------------*)

   INTERNAL PROCEDURE DoInit( RunMode : CARDINAL; CONST SymbolicName : StringsO.CString; CallbackId : ADDRESS; PCallback : drv_def.TDriverCallbackW );
   BEGIN
      SELF.RunMode := RunMode;
      SELF.SymbolicName := SymbolicName;
      SELF.CallbackId := CallbackId;
      SELF.CallbackProc := CallbackProc;
   END DoInit;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Signal( What : TDriverSignal );
   BEGIN
      IF CallbackProc = NIL THEN
         RETURN;
      END;
      CASE What OF
      | dsInputFinalized :
         CallbackProc( CallbackId, drv_def.dcfInputFinalized, NIL );
      | dsOutputFinalized :
         CallbackProc( CallbackId, drv_def.dcfOutputFinalized, NIL );
      | dsOOBData :
         CallbackProc( CallbackId, drv_def.dcfOOBDataAdvise, NIL );
      | dsException :
         CallbackProc( CallbackId, drv_def.dcfException, NIL );
      END; // CASE
   END Signal;

(*--------------------------------------------------------------------------------*)

BEGIN
   RunMode := drv_def.drmSimulate;
   CallbackId := NIL;
   CallbackProc := NIL;
END CCWDriverSkeleton;

(*================================================================================*)

ABSTRACT CLASS IMPLEMENTATION ADeviceAsCWDriver;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Init( RunMode : CARDINAL; CONST SymbolicName : StringsO.CString; CallbackId : ADDRESS; PCallback : drv_def.TDriverCallbackW );
   BEGIN
      DoInit( RunMode, SymbolicName, CallbackId, PCallback );
   END Init;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run();
   BEGIN
      IO()^.Run();
   END Run;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Stop();
   BEGIN
      IO()^.Stop();
   END Stop;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   BEGIN
   END Dispose;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE DriverProc( Func, Param1, Param2, Param3, Param4 : CARDINAL );
   BEGIN
   END DriverProc;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE InputRequestStart();
   BEGIN
   END InputRequestStart;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE InputRequest( DriverIndex : CARDINAL );
   BEGIN
   END InputRequest;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE InputRequestCompleted();
   BEGIN
   END InputRequestCompleted;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE InputFinalized( DriverIndex : CARDINAL; OUT ErrorCode : CARDINAL ) : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END InputFinalized;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE InputOOBDataQuery( REF EnumerateState : LONGWORD; OUT DriverIndex : CARDINAL ) : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END InputOOBDataQuery;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE GetInput( DriverIndex : CARDINAL; InValueLimit : CARDINAL; OUT InValue : iovalue.Value; OUT QoS : CARDINAL; OUT TimeStamp : drv_def.TUTCStamp; OUT ErrorCode : CARDINAL );
   BEGIN
   END GetInput;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OutputRequestStart();
   BEGIN
   END OutputRequestStart;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OutputRequest( DriverIndex : CARDINAL; CONST OutValue : iovalue.Value; QoS : CARDINAL; CONST TimeStamp : drv_def.TUTCStamp );
   BEGIN
   END OutputRequest;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OutputRequestCompleted();
   BEGIN
   END OutputRequestCompleted;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OutputFinalized( DriverIndex : CARDINAL; OUT ErrorCode : CARDINAL ) : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END OutputFinalized;

(*--------------------------------------------------------------------------------*)

END ADeviceAsCWDriver;

(*================================================================================*)

END diface_device.