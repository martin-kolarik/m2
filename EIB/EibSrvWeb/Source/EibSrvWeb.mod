IMPLEMENTATION MODULE EibSrvWeb;

(*================================================================================*)

FROM Debug IMPORT
   Assertion;

IMPORT
   Controller,
   HttpCommon,
   httpsrv,
   MVC,
   Sync;

(*================================================================================*)

CLASS IMPLEMENTATION CEibSrvWeb;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnConnect();
   BEGIN
      _Connected := TRUE;
      _ConnectedTime := time.GetCurrentJD();
   END OnConnect;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnDisconnect();
   BEGIN
      _Connected := FALSE;
      _DisconnectedTime := time.GetCurrentJD();
   END OnDisconnect;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnInitReadCompleted();
   BEGIN
   END OnInitReadCompleted;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnRead( PObject : srvcore.TPObject );
   BEGIN
   END OnRead;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnWritten( PObject : srvcore.TPObject );
   VAR
      dt : time.TDateTime;
   BEGIN
      time.GetCurrentUTCDateTime( dt );
      Sync.IInc( REF _WrittenByHour[dt.Hour MOD 24] );
   END OnWritten;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnInputQueueAdd( OOBQueue, PromiscuousQueue : BOOLEAN );
   VAR
      dt : time.TDateTime;
   BEGIN
      time.GetCurrentUTCDateTime( dt );

      _EIB^.QueueLock.Lock();

      INC( _GotByHour[dt.Hour MOD 24], _EIB^.oobData.Count );
      _EIB^.oobData.Clear();

      _EIB^.QueueLock.Unlock();
   END OnInputQueueAdd;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnInputQueueOverflow( OOBQueue, PromiscuousQueue : BOOLEAN );
   BEGIN
   END OnInputQueueOverflow;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Configuration GET : StringsO.TPString;
   BEGIN
      RETURN _EIB^.Configuration;
   END Configuration;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Connected GET : BOOLEAN;
   BEGIN
      RETURN _Connected;
   END Connected;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY StartedTime GET : time.TJD;
   BEGIN
      RETURN _StartedTime;
   END StartedTime;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY ConnectedTime  GET : time.TJD;
   BEGIN
      RETURN _ConnectedTime;
   END ConnectedTime;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY DisconnectedTime  GET : time.TJD;
   BEGIN
      RETURN _DisconnectedTime;
   END DisconnectedTime;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY LicenceExpires GET : time.TDateTime;
   BEGIN
      RETURN _EIB^.PResult^.Expires;
   END LicenceExpires;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY WrittenByHour GET : CARDINAL;
   VAR
      dt : time.TDateTime;
   BEGIN
      time.GetCurrentUTCDateTime( dt );
      RETURN Sync.IGet( REF _WrittenByHour[dt.Hour MOD 24] );
   END WrittenByHour;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY WrittenByDay GET : CARDINAL;
   VAR
      byDay : CARDINAL := 0;
      i : CARDINAL;
   BEGIN
      FOR i := 0 TO 23 DO
         INC( byDay, Sync.IGet( REF _WrittenByHour[i] ));
      END;
      RETURN byDay;
   END WrittenByDay;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY ReadByHour GET : CARDINAL;
   VAR
      dt : time.TDateTime;
   BEGIN
      time.GetCurrentUTCDateTime( dt );
      RETURN Sync.IGet( REF _GotByHour[dt.Hour MOD 24] );
   END ReadByHour;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY ReadByDay GET : CARDINAL;
   VAR
      byDay : CARDINAL := 0;
      i : CARDINAL;
   BEGIN
      FOR i := 0 TO 23 DO
         INC( byDay, Sync.IGet( REF _GotByHour[i] ));
      END;
      RETURN byDay;
   END ReadByDay;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY OperatedDeviceCount GET : CARDINAL;
   BEGIN
      RETURN _DeviceCount;
   END OperatedDeviceCount;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY ConfigLogger GET : Log.TPLogger;
   BEGIN
      RETURN _ConfigLogger;
   END ConfigLogger;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY DataLogger GET : Log.TPLogger;
   BEGIN
      RETURN _DataLogger;
   END DataLogger;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ConnectEIB();
   BEGIN
      _EIB^.Start();
   END ConnectEIB;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE DisconnectEIB();
   BEGIN
      _EIB^.Stop();
   END DisconnectEIB;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE OperatedDeviceName( index : CARDINAL ) : PWCHAR;
   BEGIN
      IF index < _DeviceCount THEN
         RETURN _DeviceNames^[index];
      ELSE
         RETURN NIL;
      END;
   END OperatedDeviceName;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE OperatedDevice( index : CARDINAL ) : io.TPIStartStopControl;
   BEGIN
      IF index < _DeviceCount THEN
         RETURN _Devices^[index];
      ELSE
         RETURN NIL;
      END;
   END OperatedDevice;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( Port : CARDINAL; CONST ContextName : ARRAY OF WCHAR; EIB : srvcore.TPEIBServer; DeviceNames : ARRAY OF PWCHAR; Devices : ARRAY OF io.TPIStartStopControl; ConfigLogger, DataLogger : Log.TPLogger );
   BEGIN
      Stop();
      _Port := Port;
      _Context.FromOA( ContextName );
      _EIB := EIB;
      _DeviceCount := MIN2( HIGH( DeviceNames ), HIGH( Devices )) + 1;
      _DeviceNames := ADR( DeviceNames );
      _Devices := ADR( Devices );
      _ConfigLogger := ConfigLogger;
      _DataLogger := DataLogger;
   END Init;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Running GET : BOOLEAN;
   BEGIN
      RETURN _Running;
   END Running;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Run();
   VAR
      i : CARDINAL;
   BEGIN 
      IF _Running THEN
         RETURN;
      END;
      _Running := TRUE;
      
      httpsrv.srv()^.Port := _Port;      
      httpsrv.srv()^.Start();

      ASSERT( _MVC = NIL );
      _MVC := mvc.mvc( OA( _Context.Length-1, _Context.rawData ));
      AddControllers();

      FOR i := 0 TO HIGH( _WrittenByHour ) DO
         _WrittenByHour[i] := 0;
         _GotByHour[i] := 0;
      END; // FOR
      _StartedTime := time.GetCurrentJD();      

      // hook EIB
      _EIB^.EventSink := ADR( SELF );
   END Run;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Stop();
   BEGIN
      IF NOT _Running THEN
         RETURN;
      END;
      _Running := FALSE;
      
      // unhook EIB
      _EIB^.EventSink := NIL;
      
      ASSERT( _MVC <> NIL );
      RemoveControllers();
      mvc.Cleanup();

      httpsrv.srv()^.Stop();
      httpsrv.Cleanup();
   END Stop;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE AddControllers();
   BEGIN
      IF _Controller = NIL THEN
         NEW( Controller.TPController( _Controller ));
         Controller.TPController( _Controller )^.BindToEibSrv( ADR( SELF ));
      END;

      _MVC^.RegisterController( _Controller, HttpCommon.verbGET, L"" ); // index

      _MVC^.RegisterController( _Controller, HttpCommon.verbGET, Controller.LOGIN_PAGE );
      _MVC^.RegisterController( _Controller, HttpCommon.verbPOST, Controller.LOGIN_PAGE );

      _MVC^.RegisterController( _Controller, HttpCommon.verbGET, Controller.STATUS_PAGE );

      _MVC^.RegisterController( _Controller, HttpCommon.verbGET, Controller.CONTROL_PAGE );
      _MVC^.RegisterController( _Controller, HttpCommon.verbPOST, Controller.CONTROL_PAGE );

      _MVC^.RegisterController( _Controller, HttpCommon.verbGET, Controller.DATA_LOG_PAGE );

      _MVC^.RegisterController( _Controller, HttpCommon.verbGET, Controller.SYSTEM_LOG_PAGE );

      _MVC^.RegisterController( _Controller, HttpCommon.verbGET, Controller.IO_PAGE );
      _MVC^.RegisterController( _Controller, HttpCommon.verbPOST, Controller.IO_PAGE );
      
      _MVC^.RegisterFallbackController( _Controller );
   END AddControllers;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE RemoveControllers();
   BEGIN
      _MVC^.ForgetControllerCompletely( _Controller );

      _MVC^.ForgetFallbackController();
   END RemoveControllers;

(*--------------------------------------------------------------------------------*)

BEGIN
   _EIB := NIL;
   _MVC := NIL;
   _DeviceCount := 0;
   _DeviceNames := NIL;
   _Devices := NIL;
   _Port := 8080;
   _Running := FALSE;
   _Controller := NIL;
   _StartedTime := 0;
   _Connected := FALSE;
   _ConnectedTime := 0;
   _DisconnectedTime := 0;
   _WrittenByHour[0] := 0;
   _GotByHour[0] := 0;
FINALLY
   Stop();   
END CEibSrvWeb;

(*================================================================================*)

END EibSrvWeb.