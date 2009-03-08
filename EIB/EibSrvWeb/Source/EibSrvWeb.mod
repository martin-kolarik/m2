IMPLEMENTATION MODULE EibSrvWeb;

(*================================================================================*)

FROM Debug IMPORT
   Assertion;

IMPORT
   Controller,
   cphcommon,
   device,
   digest,
   FIO,
   HttpCommon,
   httpsrv,
   IOO,
   iovalue,
   MVC,
   ns,
   sha256,
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

   PUBLIC PROPERTY RootDir GET : StringsO.TPString;
   BEGIN
      RETURN ADR( _RootDir );
   END RootDir;

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

   PUBLIC PROCEDURE ConfigureEIB( CONST configFilePath : StringsO.CString );
   VAR
      configuration : ARRAY [0..0] OF device.TConfigureItem;
      wasRunning : BOOLEAN;
   BEGIN
      wasRunning := _EIB^.Running;
      _EIB^.Stop();

      configuration[0].Type := device.citIString;
      configuration[0].iString := StringsO.TPString( ADR( configFilePath ));
      IF _EIB^.Configure( configuration, _ConfigLogger ) = Sync.arCompleted THEN
         IF wasRunning THEN
            _EIB^.Start();
         END;
      END;
   END ConfigureEIB;

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

   PUBLIC PROCEDURE SetValue( CONST name, value : StringsO.IString ) : BOOLEAN;
   VAR
      hash : ns.THash;
      io : iovalue.Value;
      s : StringsO.CString;
   BEGIN
      IF NOT _EIB^.NameToHash( name, OUT hash ) THEN
         RETURN FALSE;
      END;
      s.Assign( value );
      io.String := s;
      RETURN _EIB^.IOh( IOO.dirWrite, hash, REF io, NIL ) = Sync.arCompleted; // partial = cache write is not evaluated as true
   END SetValue;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE GetValue( CONST name : StringsO.IString; OUT value : StringsO.IString ) : BOOLEAN;
   VAR
      hash : ns.THash;
      io : iovalue.Value;
      s : StringsO.CString;
   BEGIN
      IF NOT _EIB^.NameToHash( name, OUT hash ) THEN
         RETURN FALSE;
      END;
      IF _EIB^.IOh( IOO.dirRead, hash, REF io, NIL ) NOT IN Sync.arsCompletions THEN
         RETURN FALSE;
      END;
      s := io.String;
      value.Assign( s );
      RETURN TRUE;
   END GetValue;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Authenticate( CONST Name, Password : StringsO.IString ) : TRole;
   CONST
      ROLE_ADMIN = L"admin";
      ROLE_USER = L"user";
   VAR
      base64OA : ARRAY [0..63] OF WCHAR;
      i : CARDINAL;
      hash, password : sha256.CDigest;
      hashOA : sha256.TDigest;
      itemRole, role : TRole := roleGuest;
      s : StringsO.CString;
   BEGIN
      IF Name.Empty OR Password.Empty THEN
         RETURN role;
      END;

      _Users.Reset();
      WHILE _Users.MoveNext() DO
         IF _Users.Current^.Equals( Name ) THEN

            // split data to role and hash
            i := _Users.CurrentData^.IndexOfOA( L",", 0 );
            IF i = -1 THEN
               CONTINUE;
            END;
            _Users.CurrentData^.Substring( i+1, -1, OUT s );
            s.Trim();
            s.ToOA( OUT base64OA );
            _Users.CurrentData^.Substring( 0, i, OUT s );
            s.Trim();
            IF s.EqualsOA( ROLE_ADMIN ) THEN
               itemRole := roleAdministrator;
            ELSIF s.EqualsOA( ROLE_USER ) THEN
               itemRole := roleUser;
            ELSE
               CONTINUE;
            END;

            // try expand and compare hash
            IF cphcommon.FromBASE64( base64OA, OUT hashOA, OUT i ) AND ( i = SIZE( hashOA )) THEN
               hash.FromOA( hashOA );
               IF itemRole = roleAdministrator THEN
                  digest.DigestSalt( digest.sha256, OA( 2*Password.Length-1, PBYTE( Password.rawData )), C"web_root", OUT password );
               ELSE
                  digest.DigestSalt( digest.sha256, OA( 2*Password.Length-1, PBYTE( Password.rawData )), C"message_file", OUT password );
               END;
               IF hash = password THEN
                  role := itemRole;
               END;
               EXIT;
            END;

         END;
      END; // WHILE
 
      RETURN role;
   END Authenticate;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( Port : CARDINAL; CONST ContextName : ARRAY OF WCHAR; CONST cfg : INIfile.CINIFile; EIB : srvcore.TPEIBServer; DeviceNames : ARRAY OF PWCHAR; Devices : ARRAY OF io.TPIStartStopControl; ConfigLogger, DataLogger : Log.TPLogger ) : BOOLEAN;
   CONST
      snServer = L"server";
      snUsers = L"users";
      knWebRoot = L"web_root";
      knMessageFile = L"message_file";
   VAR
      es : PTR;
      hash : StringsO.CString;
      line : CARDINAL;
      ok : BOOLEAN := TRUE;
      Path : ARRAY [0..260] OF WCHAR;
      userOA : ARRAY [0..63] OF WCHAR;
      user : StringsO.CString;
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

      IF cfg.SetSection( snServer ) AND FIO.GetModuleDirW( L"", OUT Path ) THEN // EXE dir
         IF cfg.GetKeyStr( knWebRoot, OUT line, OUT _RootDir ) THEN
            _RootDir.ReplaceOA( L"%exedir%", Path );
         ELSE
            _RootDir.FromOA( Path );
         END;
         IF cfg.GetKeyStr( knMessageFile, OUT line, OUT _MessageFile ) THEN
            _MessageFile.ReplaceOA( L"%exedir%", Path );
         END;
      END;
      IF _RootDir.Empty THEN
         ok := FALSE;
         Log.logger()^.LogS( Log.dlcError, L"KnxSrv", L"Web root is not defined, web interface will not start." );
      END;
      IF _MessageFile.Empty THEN
         ok := FALSE;
         Log.logger()^.LogS( Log.dlcError, L"KnxSrv", L"Message source for web is not defined, web interface will not start." );
      END;
      
      IF NOT cfg.SetSection( snUsers ) THEN
         ok := FALSE;
         Log.logger()^.LogS( Log.dlcError, L"KnxSrv", L"No users defined, web interface will not start." );
      ELSE
         es := 0;
         WHILE cfg.EnumerateKeys( REF es, OUT line, OUT userOA, OUT hash ) DO
            user.FromOA( userOA );
            _Users.Add( user, hash );
         END; // WHILE
      END;
      
      RETURN ok;
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
      _MVC^.MessageSourcePath := _MessageFile;
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

      _MVC^.RegisterController( _Controller, HttpCommon.verbGET, Controller.INDEX_PAGE );

      _MVC^.RegisterController( _Controller, HttpCommon.verbGET, Controller.LOGIN_PAGE );
      _MVC^.RegisterController( _Controller, HttpCommon.verbPOST, Controller.LOGIN_PAGE );

      _MVC^.RegisterController( _Controller, HttpCommon.verbGET, Controller.LOGOUT_PAGE );

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
   _ConfigLogger := NIL;
   _DataLogger := NIL;
FINALLY
   Stop();   
END CEibSrvWeb;

(*================================================================================*)

END EibSrvWeb.