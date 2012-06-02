IMPLEMENTATION MODULE diface_device;

IMPORT
   iocached;

(*================================================================================*)

CLASS IMPLEMENTATION CCWDriverSkeleton;

(*--------------------------------------------------------------------------------*)

   INTERNAL PROCEDURE Init( RunMode : CARDINAL; CONST SymbolicName : StringsO.CString; CallbackId : ADDRESS; PCallback : drv_def.TDriverCallbackW );
   BEGIN
      SELF.RunMode := RunMode;
      SELF.SymbolicName := SymbolicName;
      SELF.CallbackId := CallbackId;
      SELF.CallbackProc := CallbackProc;
   END Init;

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

   PUBLIC FINAL PROCEDURE OnError( Direction : IOO.TDirection; Source : io.TPIO; CONST Result : ARRAY OF Sync.TAsyncResult; CONST Item : ARRAY OF ns.THash; CONST DeviceSpecificError : ARRAY OF CARDINAL );
   BEGIN
      // do nothing
   END OnError;

(*--------------------------------------------------------------------------------*)

   PUBLIC FINAL PROCEDURE OnIO( Direction : IOO.TDirection; Source : io.TPIO; CONST Result : ARRAY OF Sync.TAsyncResult; CONST Item : ARRAY OF ns.THash; CONST DeviceSpecificError : ARRAY OF CARDINAL; CONST Value : ARRAY OF iovalue.Value );
   BEGIN
      IF Direction = IOO.dirRead THEN
         Signal( dsInputFinalized );
      ELSE
         Signal( dsOutputFinalized );
      END;      
   END OnIO;

(*--------------------------------------------------------------------------------*)

   PUBLIC FINAL PROCEDURE OnAdvise( CONST Originator : ns.TPOriginator; CONST Result : ARRAY OF Sync.TAsyncResult; CONST Item : ARRAY OF ns.TPNameValuePairs; CONST Value : ARRAY OF iovalue.Value );
   BEGIN
   END OnAdvise;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Initialize( RunMode : CARDINAL; CONST SymbolicName : StringsO.CString; CallbackId : ADDRESS; PCallback : drv_def.TDriverCallbackW );
   BEGIN
      Init( RunMode, SymbolicName, CallbackId, PCallback );
   END Initialize;

(*--------------------------------------------------------------------------------*)

   PUBLIC FINAL PROCEDURE DriverRun();
   BEGIN
      IO()^.Start();
   END DriverRun;

(*--------------------------------------------------------------------------------*)

   PUBLIC FINAL PROCEDURE DriverStop();
   BEGIN
      IO()^.Stop();
   END DriverStop;

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
   VAR
      Hash : ns.THash;
      io : iovalue.Value;
   BEGIN
      IF DriverIndexToHash( DriverIndex, OUT Hash ) THEN
         IO()^.IOmh( iocached.iomAsynchronous, IOO.dirRead, Hash, REF io, NIL, 0 );
      END;
   END InputRequest;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE InputRequestCompleted();
   BEGIN
   END InputRequestCompleted;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE InputFinalized( DriverIndex : CARDINAL; OUT ErrorCode : CARDINAL ) : BOOLEAN;
   VAR
      Hash : ns.THash;
      Pending : BOOLEAN;
   BEGIN
      IF NOT DriverIndexToHash( DriverIndex, OUT Hash ) THEN
         ErrorCode := drv_def.ecUnknownElement;
         RETURN TRUE;
      END;
      IO()^.Pendingh( IOO.dirRead, Hash, OUT Pending );
      IF Pending THEN
         RETURN FALSE;
      ELSE
         ErrorCode := drv_def.ecSuccess;
         RETURN TRUE;
      END;
   END InputFinalized;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE InputOOBDataQuery( REF EnumerateState : LONGWORD; OUT DriverIndex : CARDINAL ) : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END InputOOBDataQuery;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE GetInput( DriverIndex : CARDINAL; InValueLimit : CARDINAL; OUT InValue : iovalue.Value; OUT QoS : CARDINAL; OUT TimeStamp : drv_def.TUTCStamp; OUT ErrorCode : CARDINAL );
   VAR
      Hash : ns.THash;
   BEGIN
      IF DriverIndexToHash( DriverIndex, OUT Hash ) THEN
         ErrorCode := drv_def.ecSuccess;
         IO()^.IOmh( iocached.iomCached, IOO.dirRead, Hash, REF InValue, NIL, 0 );
      ELSE
         ErrorCode := drv_def.ecUnknownElement;
      END;
   END GetInput;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OutputRequestStart();
   BEGIN
   END OutputRequestStart;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OutputRequest( DriverIndex : CARDINAL; CONST OutValue : iovalue.Value; QoS : CARDINAL; CONST TimeStamp : drv_def.TUTCStamp );
   VAR
      Hash : ns.THash;
   BEGIN
      IF DriverIndexToHash( DriverIndex, OUT Hash ) THEN
         IO()^.IOmh( iocached.iomAsynchronous, IOO.dirRead, Hash, REF iovalue.TPValue( ADR( OutValue ))^, NIL, 0 );
      END;
   END OutputRequest;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OutputRequestCompleted();
   BEGIN
   END OutputRequestCompleted;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OutputFinalized( DriverIndex : CARDINAL; OUT ErrorCode : CARDINAL ) : BOOLEAN;
   VAR
      Hash : ns.THash;
      Pending : BOOLEAN;
   BEGIN
      IF NOT DriverIndexToHash( DriverIndex, OUT Hash ) THEN
         ErrorCode := drv_def.ecUnknownElement;
         RETURN TRUE;
      END;
      IO()^.Pendingh( IOO.dirWrite, Hash, OUT Pending );
      IF Pending THEN
         RETURN FALSE;
      ELSE
         ErrorCode := drv_def.ecSuccess;
         RETURN TRUE;
      END;
   END OutputFinalized;

(*--------------------------------------------------------------------------------*)

BEGIN
FINALLY
END ADeviceAsCWDriver;

(*================================================================================*)

END diface_device.