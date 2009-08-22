IMPLEMENTATION MODULE EibSrvWeb;

(*================================================================================*)

FROM Debug IMPORT
   Assertion, LogAssertionW;

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
   lists,
   msgqueuethread,
   MVC,
   ns,
   sha256,
   Sync;

(*--------------------------------------------------------------------------------*)

TYPE
   TCommand = (
      cmdLoadConfiguration,
      cmdStart,
      cmdStop,
      cmdDeviceStart,
      cmdDeviceStop
   );

CONST
    LOG_PREFIX = L"KnxSrv";

(*================================================================================*)

CLASS IMPLEMENTATION CEibSrvWeb;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnConnect();
   BEGIN
      IF _Lock.LockWrite( Sync.FORSAFETY ) = Sync.arTimeout THEN
         ASSERTLOG( FALSE );
         RETURN;
      END;

      _Connected := TRUE;
      _ConnectedTime := time.GetCurrentJD();
      
      _Lock.UnlockWrite();
   END OnConnect;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnDisconnect();
   BEGIN
      IF _Lock.LockWrite( Sync.FORSAFETY ) = Sync.arTimeout THEN
         ASSERTLOG( FALSE );
         RETURN;
      END;

      _Connected := FALSE;
      _DisconnectedTime := time.GetCurrentJD();
      
      _Lock.UnlockWrite();
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
      dt : time.DateTime;
   BEGIN
      dt.SetNowUTC();
      AdjustHours( dt, REF _WrittenByHour, REF _WrittenByHourModified );

      Sync.IInc( REF _WrittenByHour[dt.Hour MOD 24] );
   END OnWritten;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnInputQueueAdd( OOBQueue, PromiscuousQueue : BOOLEAN );
   VAR
      dt : time.DateTime;
   BEGIN
      dt.SetNowUTC();
      AdjustHours( dt, REF _GotByHour, REF _GotByHourModified );

      _EIB^.QueueLock.Lock();

      Sync.IExchgAdd( REF _GotByHour[dt.Hour MOD 24], _EIB^.oobData.Count );
      _EIB^.oobData.Clear();

      _EIB^.QueueLock.Unlock();
   END OnInputQueueAdd;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnInputQueueOverflow( OOBQueue, PromiscuousQueue : BOOLEAN );
   BEGIN
   END OnInputQueueOverflow;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Invoke( Operation : CARDINAL; CONST Parameters : ARRAY OF PTR ) : PTR;
   VAR
      configFilePath : StringsO.TPString;
      configuration : ARRAY [0..0] OF device.TConfigureItem;
      index : CARDINAL;
      wasRunning : BOOLEAN;
   BEGIN
      CASE TCommand( Operation ) OF
      | cmdLoadConfiguration :
         configFilePath := StringsO.TPString( Parameters[0] );
      
         wasRunning := _EIB^.Running;
         _EIB^.Stop();

         configuration[0].Type := device.citIString;
         configuration[0].iString := configFilePath;
         IF _EIB^.Configure( configuration, _ConfigLogger ) = Sync.arCompleted THEN
            IF wasRunning THEN
               _EIB^.Start();
            END;
         END;

      | cmdStart :
         _EIB^.Start();

      | cmdStop :
         _EIB^.Stop();
         
      | cmdDeviceStart :
         index := PCARDINAL( Parameters[0] )^;
         IF index < _DeviceCount THEN
            _Devices^[index]^.Start();
         ELSE
            ASSERTLOG( FALSE );
         END;

      | cmdDeviceStop :
         index := PCARDINAL( Parameters[0] )^;
         IF index < _DeviceCount THEN
            _Devices^[index]^.Stop();
         ELSE
            ASSERTLOG( FALSE );
         END;
      
      END; // CASE
      RETURN 0;
   END Invoke;

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
   VAR
      connected : BOOLEAN;
   BEGIN
      IF _Lock.LockRead( Sync.FORSAFETY ) = Sync.arTimeout THEN
         ASSERTLOG( FALSE );
         RETURN FALSE;
      END;
      connected := _Connected;
      _Lock.UnlockRead();
      
      RETURN connected;
   END Connected;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY StartedTime GET : time.TJD;
   BEGIN
      // no need to lock, value written once
      RETURN _StartedTime;
   END StartedTime;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY ConnectedTime  GET : time.TJD;
   VAR
      connectedTime : time.TJD;
   BEGIN
      IF _Lock.LockRead( Sync.FORSAFETY ) = Sync.arTimeout THEN
         ASSERTLOG( FALSE );
         RETURN _StartedTime;
      END;
      connectedTime := _ConnectedTime;
      _Lock.UnlockRead();
      
      RETURN connectedTime;
   END ConnectedTime;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY DisconnectedTime  GET : time.TJD;
   VAR
      connectedTime : time.TJD;
   BEGIN
      IF _Lock.LockRead( Sync.FORSAFETY ) = Sync.arTimeout THEN
         ASSERTLOG( FALSE );
         RETURN _StartedTime;
      END;
      connectedTime := _DisconnectedTime;
      _Lock.UnlockRead();
      
      RETURN connectedTime;
   END DisconnectedTime;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY LicenceExpires GET : time.DateTime;
   VAR
      startTime : time.DateTime;
   BEGIN
      // no need to sync
      IF _EIB^.PResult^.Suspended THEN
         startTime.FromJD( _StartedTime, 0, 0 );
         RETURN startTime;
      ELSE
         RETURN _EIB^.PResult^.Expires;
      END;
   END LicenceExpires;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY LicenceType GET : lec.TLicenceType;
   VAR
      licences : lists.CStringList;
      ptrType : PTR;
      s : StringsO.CString;
   BEGIN
      // no need to sync
      _EIB^.PResult^.GetLicences( OUT licences );
      IF licences.GetFirst( OUT s, OUT ptrType ) THEN
         RETURN lec.TLicenceType( LOPTRLONGWORD( ptrType ));
      ELSE
         RETURN lec.TLicenceType{};
      END;
   END LicenceType;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Licence GET : StringsO.CString;
   VAR
      licences : lists.CStringList;
      ptrType : PTR;
      s : StringsO.CString;
   BEGIN
      // no need to sync
      _EIB^.PResult^.GetLicences( OUT licences );
      IF NOT licences.GetFirst( OUT s, OUT ptrType ) THEN
         s.Clear();
      END;
      RETURN s;
   END Licence;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY WrittenByHour GET : CARDINAL;
   VAR
      dt : time.DateTime;
   BEGIN
      dt.SetNowUTC();
      AdjustHours( dt, REF _WrittenByHour, REF _WrittenByHourModified );

      RETURN Sync.IGet( REF _WrittenByHour[dt.Hour MOD 24] );
   END WrittenByHour;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY WrittenByDay GET : CARDINAL;
   VAR
      byDay : CARDINAL := 0;
      dt : time.DateTime;
      i : CARDINAL;
   BEGIN
      dt.SetNowUTC();
      AdjustHours( dt, REF _WrittenByHour, REF _WrittenByHourModified );

      FOR i := 0 TO 23 DO
         INC( byDay, Sync.IGet( REF _WrittenByHour[i] ));
      END;
      RETURN byDay;
   END WrittenByDay;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY ReadByHour GET : CARDINAL;
   VAR
      dt : time.DateTime;
   BEGIN
      dt.SetNowUTC();
      AdjustHours( dt, REF _GotByHour, REF _GotByHourModified );

      RETURN Sync.IGet( REF _GotByHour[dt.Hour MOD 24] );
   END ReadByHour;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY ReadByDay GET : CARDINAL;
   VAR
      byDay : CARDINAL := 0;
      dt : time.DateTime;
      i : CARDINAL;
   BEGIN
      dt.SetNowUTC();
      AdjustHours( dt, REF _GotByHour, REF _GotByHourModified );

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

   PUBLIC PROPERTY ConfigLogger GET : Log.TPBufferedLogger;
   BEGIN
      RETURN _ConfigLogger;
   END ConfigLogger;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY DataLogger GET : Log.TPBufferedLogger;
   BEGIN
      RETURN _DataLogger;
   END DataLogger;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ConnectEIB();
   VAR
      Result : Sync.TAsyncResult;
   BEGIN
      Result := msgqueuethread.global()^.ThreadCall( ADR( SELF ), CARDINAL( cmdStart ), OA( -1, NIL ), NIL, TRUE, Sync.FORSAFETY );
      ASSERTLOG( Result <> Sync.arTimeout );
   END ConnectEIB;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE DisconnectEIB();
   VAR
      Result : Sync.TAsyncResult;
   BEGIN
      Result := msgqueuethread.global()^.ThreadCall( ADR( SELF ), CARDINAL( cmdStop ), OA( -1, NIL ), NIL, TRUE, Sync.FORSAFETY );
      ASSERTLOG( Result <> Sync.arTimeout );
   END DisconnectEIB;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ConfigureEIB( CONST configFilePath : StringsO.CString );
   VAR
      pConfigFilePath : StringsO.TPString := ADR( configFilePath );
      Result : Sync.TAsyncResult;
   BEGIN
      Result := msgqueuethread.global()^.ThreadCall( ADR( SELF ), CARDINAL( cmdLoadConfiguration ), OA( 0, ADR( pConfigFilePath )), NIL, TRUE, Sync.FORSAFETY );
      ASSERTLOG( Result <> Sync.arTimeout );
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

   PUBLIC PROCEDURE OperateDevice( index : CARDINAL; StartNotStop : BOOLEAN );
   VAR
      pindex : PCARDINAL := ADR( index );
      Result : Sync.TAsyncResult;
   BEGIN
      IF index >= _DeviceCount THEN
         Log.logger()^.LogS( Log.dlcWarning, LOG_PREFIX, L"OperateDevice index out of range." );
      ELSIF StartNotStop THEN
         Result := msgqueuethread.global()^.ThreadCall( ADR( SELF ), CARDINAL( cmdDeviceStart ), OA( 0, ADR( pindex )), NIL, TRUE, Sync.FORSAFETY );
         ASSERTLOG( Result <> Sync.arTimeout );
      ELSE
         Result := msgqueuethread.global()^.ThreadCall( ADR( SELF ), CARDINAL( cmdDeviceStop ), OA( 0, ADR( pindex )), NIL, TRUE, Sync.FORSAFETY );
         ASSERTLOG( Result <> Sync.arTimeout );
      END;
   END OperateDevice;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE DeviceRunning( index : CARDINAL ) : BOOLEAN;
   BEGIN
      IF index >= _DeviceCount THEN
         Log.logger()^.LogS( Log.dlcWarning, LOG_PREFIX, L"DeviceRunning index out of range." );
         RETURN FALSE;
      ELSE
         RETURN _Devices^[index]^.Running;
      END;
   END DeviceRunning;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SetValue( CONST name, value : StringsO.IString ) : BOOLEAN;
   VAR
      hash : ns.THash;
      io : iovalue.Value;
      s : StringsO.CString;
   BEGIN
      // no need to sync, NameToHash is be thread safe
      IF NOT _EIB^.NameToHash( name, OUT hash ) THEN
         RETURN FALSE;
      END;
      s.Assign( value );
      io.String := s;
      // no need to sync, IOh is be thread safe
      RETURN _EIB^.IOh( IOO.dirWrite, hash, REF io, NIL ) = Sync.arCompleted; // partial = cache write is not evaluated as true
   END SetValue;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE GetValue( CONST name : StringsO.IString; OUT value : StringsO.IString ) : BOOLEAN;
   VAR
      hash : ns.THash;
      io : iovalue.Value;
      s : StringsO.CString;
   BEGIN
      // no need to sync, NameToHash is be thread safe
      IF NOT _EIB^.NameToHash( name, OUT hash ) THEN
         RETURN FALSE;
      END;
      // no need to sync, IOh is be thread safe
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
      localUsers : lists.CStringStringList;
      s : StringsO.CString;
   BEGIN
      IF Name.Empty OR Password.Empty THEN
         RETURN role;
      END;
      
      // avoid synchronizing by local copy
      localUsers := _Users;

      localUsers.Reset();
      WHILE localUsers.MoveNext() DO
         IF localUsers.Current^.Equals( Name ) THEN

            // split data to role and hash
            i := localUsers.CurrentData^.IndexOfOA( L",", 0 );
            IF i = -1 THEN
               CONTINUE;
            END;
            localUsers.CurrentData^.Substring( i+1, -1, OUT s );
            s.Trim();
            s.ToOA( OUT base64OA );
            localUsers.CurrentData^.Substring( 0, i, OUT s );
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
      
      localUsers.Clear(); // deny disposing
 
      RETURN role;
   END Authenticate;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( Port : CARDINAL; CONST ContextName : ARRAY OF WCHAR; CONST cfg : INIfile.CINIFile; EIB : srvcore.TPEIBServer; DeviceNames : ARRAY OF PWCHAR; Devices : ARRAY OF io.TPIStartStopControl; ConfigLogger, DataLogger : Log.TPBufferedLogger; HttpLogger : Log.TPILogger ) : BOOLEAN;
   CONST
      snServer = L"server";
      snUsers = L"users";
      snAccessList = L"http_access_list";
         knAllow = L"allow";
         knDeny = L"deny";
      knWebRoot = L"web_root";
      knMessageFile = L"message_file";
   VAR
      es : PTR;
      hash : StringsO.CString;
      line : CARDINAL;
      ok : BOOLEAN := TRUE;
      Path : ARRAY [0..260] OF WCHAR;
      sOA : ARRAY [0..63] OF WCHAR;
      s : StringsO.CString;
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
      _HttpLogger := HttpLogger;

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
         Log.logger()^.LogS( Log.dlcError, LOG_PREFIX, L"Web root is not defined, web interface will not start." );
      END;
      IF _MessageFile.Empty THEN
         ok := FALSE;
         Log.logger()^.LogS( Log.dlcError, LOG_PREFIX, L"Message source for web is not defined, web interface will not start." );
      END;
      
      IF NOT cfg.SetSection( snUsers ) THEN
         ok := FALSE;
         Log.logger()^.LogS( Log.dlcError, LOG_PREFIX, L"No users defined, web interface will not start." );
      ELSE
         es := 0;
         WHILE cfg.EnumerateKeys( REF es, OUT line, OUT sOA, OUT hash ) DO
            s.FromOA( sOA );
            _Users.Add( s, hash );
         END; // WHILE
      END;
      
      IF cfg.SetSection( snAccessList ) THEN
         es := 0;
         WHILE cfg.EnumerateKeys( REF es, OUT line, OUT sOA, OUT s ) DO
            s.Trim();
            IF EQUALS( sOA, knAllow ) THEN
               _AccessList.AddRuleS( accesslist.actAllow, s );
            ELSIF EQUALS( sOA, knDeny ) THEN
               _AccessList.AddRuleS( accesslist.actDeny, s );
            ELSE
               ConfigLogger^.LogFilePos( Log.dlcError, LOG_PREFIX, L"Only 'allow' and 'deny' rules are allowed, the rule will be ignored.", L"(web config file)", line, 0 );
            END; 
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
      _MVC^.Logger := _HttpLogger;
      _MVC^.AccessList := ADR( _AccessList );
      AddControllers();

      FOR i := 0 TO HIGH( _WrittenByHour ) DO
         _WrittenByHourModified[i] := 0;
         _WrittenByHour[i] := 0;
         _GotByHourModified[i] := 0;
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

   PRIVATE PROCEDURE AdjustHours( CONST dt : time.DateTime; REF hours : ARRAY OF CARDINAL; REF modified : ARRAY OF time.TJD );
   VAR
      i : CARDINAL;
      jd : time.TJD := dt.JulianDate;
      locked : BOOLEAN := FALSE;
   BEGIN
      IF _Lock.LockWrite( Sync.FORSAFETY ) = Sync.arTimeout THEN
         ASSERTLOG( FALSE );
         RETURN;
      END;

      FOR i := 0 TO HIGH( hours ) DO
         IF modified[i] + time.unitsInDay < jd THEN
            hours[i] := 0;
         END;
      END;
      modified[dt.Hour MOD 24] := jd;

      _Lock.UnlockWrite();
   END AdjustHours;

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
   _WrittenByHourModified[0] := 0;
   _GotByHour[0] := 0;
   _GotByHourModified[0] := 0;
   _ConfigLogger := NIL;
   _DataLogger := NIL;
   _HttpLogger := NIL;
   _AccessList.Policy := accesslist.actAllow;
FINALLY
   Stop();   
END CEibSrvWeb;

(*================================================================================*)

END EibSrvWeb.