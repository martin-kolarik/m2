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
   Folders,
   HttpCommon,
   httpsrv,
   IOO,
   iovalue,
   lists,
   msgqueuethread,
   MVC,
   ns,
   sha256,
   Strings,
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

    cfSmartServerUsersFolder = L"SmartServer";
    cfSmartServerUsersFile = L"WebUsers.cfg";

    snRoles = L"roles";
       knNamed = L"named";
       knKeyed = L"keyed";
    snUsers = L"users";

    ROLE_SYS_ADMIN = L"sysadmin";
    ROLE_SYS_USER = L"sysuser";

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
      _ConnectedTime := datetime.GetCurrentJD();
      
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
      _DisconnectedTime := datetime.GetCurrentJD();
      
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
      dt : datetime.DateTime;
   BEGIN
      dt.SetNowUTC();
      AdjustHours( dt, REF _WrittenByHour, REF _WrittenByHourModified );

      Sync.IInc( REF _WrittenByHour[dt.Hour MOD 24] );
   END OnWritten;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnInputQueueAdd( OOBQueue, PromiscuousQueue : BOOLEAN );
   VAR
      dt : datetime.DateTime;
   BEGIN
      dt.SetNowUTC();
      AdjustHours( dt, REF _GotByHour, REF _GotByHourModified );

      _EIB^.QueueLock.Lock();

      Sync.IExchgAdd( REF _GotByHour[dt.Hour MOD 24], _EIB^.oobData.Count );
      _EIB^.oobData.Dispose();

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

   PUBLIC PROPERTY CacheOnlyMode GET : BOOLEAN;
   BEGIN
      RETURN _EIB^.CacheOnlyMode;
   END CacheOnlyMode;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY StartedTime GET : datetime.DayCount;
   BEGIN
      // no need to lock, value written once
      RETURN _StartedTime;
   END StartedTime;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY ConnectedTime  GET : datetime.DayCount;
   VAR
      connectedTime : datetime.DayCount;
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

   PUBLIC PROPERTY DisconnectedTime  GET : datetime.DayCount;
   VAR
      connectedTime : datetime.DayCount;
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

   PUBLIC PROPERTY LicenceExpires GET : datetime.DateTime;
   VAR
      startTime : datetime.DateTime;
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

   PUBLIC PROPERTY Connection GET : StringsO.CString;
   BEGIN
      RETURN _EIB^.Connection;
   END Connection;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY WrittenByHour GET : CARDINAL;
   VAR
      dt : datetime.DateTime;
   BEGIN
      dt.SetNowUTC();
      AdjustHours( dt, REF _WrittenByHour, REF _WrittenByHourModified );

      RETURN Sync.IGet( REF _WrittenByHour[dt.Hour MOD 24] );
   END WrittenByHour;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY WrittenByDay GET : CARDINAL;
   VAR
      byDay : CARDINAL := 0;
      dt : datetime.DateTime;
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
      dt : datetime.DateTime;
   BEGIN
      dt.SetNowUTC();
      AdjustHours( dt, REF _GotByHour, REF _GotByHourModified );

      RETURN Sync.IGet( REF _GotByHour[dt.Hour MOD 24] );
   END ReadByHour;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY ReadByDay GET : CARDINAL;
   VAR
      byDay : CARDINAL := 0;
      dt : datetime.DateTime;
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

   PUBLIC PROPERTY Project GET : StringsO.TPString;
   BEGIN
      RETURN ADR( _Project );
   END Project;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ConnectEIB();
   VAR
      Result : Sync.TAsyncResult;
   BEGIN
      Result := msgqueuethread.global()^.DispatchCall( ADR( SELF ), CARDINAL( cmdStart ), OA( -1, NIL ), NIL, TRUE, Sync.FORSAFETY );
      ASSERTLOG( Result <> Sync.arTimeout );
   END ConnectEIB;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE DisconnectEIB();
   VAR
      Result : Sync.TAsyncResult;
   BEGIN
      Result := msgqueuethread.global()^.DispatchCall( ADR( SELF ), CARDINAL( cmdStop ), OA( -1, NIL ), NIL, TRUE, Sync.FORSAFETY );
      ASSERTLOG( Result <> Sync.arTimeout );
   END DisconnectEIB;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ConfigureEIB( CONST configFilePath : StringsO.CString );
   VAR
      pConfigFilePath : StringsO.TPString := ADR( configFilePath );
      Result : Sync.TAsyncResult;
   BEGIN
      Result := msgqueuethread.global()^.DispatchCall( ADR( SELF ), CARDINAL( cmdLoadConfiguration ), OA( 0, ADR( pConfigFilePath )), NIL, TRUE, Sync.FORSAFETY );
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
         Log.logger()^.LogS( Log.lcWarning, 0, LOG_PREFIX, L"OperateDevice index out of range." );
      ELSIF StartNotStop THEN
         Result := msgqueuethread.global()^.DispatchCall( ADR( SELF ), CARDINAL( cmdDeviceStart ), OA( 0, ADR( pindex )), NIL, TRUE, Sync.FORSAFETY );
         ASSERTLOG( Result <> Sync.arTimeout );
      ELSE
         Result := msgqueuethread.global()^.DispatchCall( ADR( SELF ), CARDINAL( cmdDeviceStop ), OA( 0, ADR( pindex )), NIL, TRUE, Sync.FORSAFETY );
         ASSERTLOG( Result <> Sync.arTimeout );
      END;
   END OperateDevice;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE DeviceRunning( index : CARDINAL ) : BOOLEAN;
   BEGIN
      IF index >= _DeviceCount THEN
         Log.logger()^.LogS( Log.lcWarning, 0, LOG_PREFIX, L"DeviceRunning index out of range." );
         RETURN FALSE;
      ELSE
         RETURN _Devices^[index]^.Running;
      END;
   END DeviceRunning;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SetValue( CONST originator : inetaddr.INETADDR; CONST name, value : StringsO.IString ) : BOOLEAN;
   VAR
      d : StringsO.CString;
      hash : ns.THash;
      ia : ARRAY [0..63] OF WCHAR;
      Originator : io.CSimpleOriginator;
      s : StringsO.CString;
      Value : iovalue.Value;
   BEGIN
      // no need to sync, NameToHash is be thread safe
      IF NOT _EIB^.NameToHash( name, OUT hash ) THEN
         RETURN FALSE;
      END;
      s.Assign( value );
      Value.String := s;

      originator.ToOA( TRUE, OUT ia );
      d.FromOA( L"web/" ); d.AppendOA( ia );
      Originator.SetDescription( d );

      // no need to sync, IOh is be thread safe
      RETURN _EIB^.IOh( ADR( Originator ), IOO.dirWrite, hash, REF Value, NIL ) IN Sync.arsCompletions;
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
      IF _EIB^.IOh( NIL, IOO.dirRead, hash, REF io, NIL ) NOT IN Sync.arsCompletions THEN
         RETURN FALSE;
      END;
      s := io.String;
      value.Assign( s );
      RETURN TRUE;
   END GetValue;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE GetWixValue( CONST name : StringsO.IString; OUT value : StringsO.IString ) : BOOLEAN;
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
      IF _EIB^.IOh( NIL, IOO.dirRead, hash, REF io, NIL ) NOT IN Sync.arsCompletions THEN
         RETURN FALSE;
      END;
      
      CASE io.Type OF
      | iovalue.vtBoolean,
        iovalue.vtTristate :
         value.FromINT32( 10 * io.Integer, 10 );
      | iovalue.vtInteger :
         value.FromINT32( 10 * io.Integer, 10 );
      | iovalue.vtLong :
         value.FromINT64( 10 * io.Long, 10 );
      | iovalue.vtFloat :
         value.FromINT64( INT64( 10.0 * io.Float + 0.5 ), 10 );
      ELSE
         s := io.String;
         value.Assign( s );
      END;

      RETURN TRUE;
   END GetWixValue;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Authenticate( CONST Name, Password : StringsO.IString; OUT Role : StringsO.IString ) : TRole;
   
   (*----------*)
   
      PROCEDURE PrepareItem( CONST authinfo : StringsO.IString; OUT Role : StringsO.IString; OUT hash : sha256.CDigest ) : TRole;
      VAR
         base64OA : ARRAY [0..63] OF WCHAR;
         hashOA : sha256.TDigest;
         i : CARDINAL;
         itemRolePtr : PTR;
         role : TRole;
         roleS : StringsO.CString;
      BEGIN
         // split role and hash
         i := authinfo.IndexOfOA( L",", 0 );
         IF i = -1 THEN
            RETURN roleGuest;
         END;
         authinfo.Substring( 0, i, OUT roleS );
         authinfo.SubstringOA( i+1, -1, OUT base64OA );
         roleS.Trim();
         Strings.TrimW( REF base64OA );
         
         // check if role is known
         IF NOT _Roles.Get( roleS, OUT itemRolePtr ) THEN
            RETURN roleGuest;
         END;
         role := TRole( LOPTRLONGWORD( itemRolePtr ));

         // check if hash is not corrupted
         IF cphcommon.FromBASE64( base64OA, OUT hashOA, OUT i ) AND ( i = SIZE( hashOA )) THEN
            hash.FromOA( hashOA );
            Role.Assign( roleS );
            RETURN role;
         END;

         RETURN roleGuest;
      END PrepareItem;
   
   (*----------*)
   
   VAR
      authinfo : StringsO.CString;
      hash, password : sha256.CDigest;
      itemRole, role : TRole := roleGuest;
      s : StringsO.CString;
   BEGIN
      IF Password.Empty THEN
         RETURN roleGuest;
      ELSIF _Lock.LockRead( Sync.FORSAFETY ) = Sync.arTimeout THEN
         ASSERTLOG( FALSE );
         RETURN roleGuest;
      END;
      
      IF Name.Empty THEN // keyed users
         digest.DigestSalt( digest.sha256, OA( 2*Password.Length-1, PBYTE( Password.Data )), C"project", OUT password );
         
         _Users.Reset();
         WHILE _Users.MoveNext() DO
            itemRole := PrepareItem( _Users.CurrentData^, OUT s, OUT hash );
            IF ( itemRole = roleUserKeyed ) AND ( hash = password ) THEN
               role := itemRole;
               Role.Assign( s );
               EXIT; // WHILE
            END;
         END; // WHILE
         
      ELSE // named users

         IF _Users.Get( Name, OUT authinfo ) THEN
            itemRole := PrepareItem( authinfo, OUT s, OUT hash );
            IF ( itemRole <> roleUserKeyed ) AND ( itemRole <> roleGuest ) THEN 
               IF itemRole = roleSystemAdministrator THEN
                  digest.DigestSalt( digest.sha256, OA( 2*Password.Length-1, PBYTE( Password.Data )), C"web_root", OUT password );
               ELSE
                  digest.DigestSalt( digest.sha256, OA( 2*Password.Length-1, PBYTE( Password.Data )), C"message_file", OUT password );
               END;
               IF hash = password THEN
                  role := itemRole;
                  Role.Assign( s );
               END;
            END;
         END;

      END;

      _Lock.UnlockRead();
      RETURN role;
   END Authenticate;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY RolesCount GET : CARDINAL;
   BEGIN
      RETURN _Roles.Count;
   END RolesCount;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY UsersCount GET : CARDINAL;
   BEGIN
      RETURN _Users.Count;
   END UsersCount;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE GetRole( i : CARDINAL; OUT role : TRole; OUT name : StringsO.IString ) : BOOLEAN;
   VAR
      data : PTR;
   BEGIN
      IF NOT _Roles.ElementAt( i, OUT name, OUT data ) THEN
         RETURN FALSE;
      END;

      role := TRole( LOPTRLONGWORD( data ));

      RETURN TRUE;
   END GetRole;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE GetUser( i : CARDINAL; OUT role : TRole; OUT userName, roleName : StringsO.IString ) : BOOLEAN;
   VAR
      authinfo : StringsO.CString;
      data : PTR;
   BEGIN
      IF NOT _Users.ElementAt( i, OUT userName, OUT authinfo ) THEN
         RETURN FALSE;
      END;

      i := authinfo.IndexOfOA( L",", 0 );
      IF i = -1 THEN
         RETURN FALSE;
      END;
      authinfo.Length := i;
      authinfo.Trim();
      
      roleName.Assign( authinfo );
      IF NOT _Roles.Get( roleName, OUT data ) THEN
         RETURN FALSE;
      END;
      role := TRole( LOPTRLONGWORD( data ));

      RETURN TRUE;
   END GetUser;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CheckRenameRoleConflict( CONST currentName, roleName : StringsO.IString ) : BOOLEAN; // TRUE = conflict
   BEGIN
      IF currentName.Equals( roleName ) THEN // no conflict on rename will appear
         RETURN FALSE; 
      ELSIF _Roles.Contains( roleName ) THEN // role would be renamed to a name, which would collide with another existing one
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END CheckRenameRoleConflict;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE UpdateRole( CONST currentName, roleName : StringsO.IString; role : TRole ) : BOOLEAN;
   VAR
      i : CARDINAL;
      userRole : StringsO.CString;
   BEGIN
      IF _Lock.LockWrite( Sync.FORSAFETY ) = Sync.arTimeout THEN
         ASSERTLOG( FALSE );
         RETURN FALSE;
      ELSIF NOT currentName.Empty AND NOT _Roles.Contains( currentName ) THEN // unable to edit role, which does not exist
         _Lock.UnlockWrite();
         RETURN FALSE;
      ELSIF NOT currentName.Equals( roleName ) AND _Roles.Contains( roleName ) THEN // unable to rename role to an existing name
         _Lock.UnlockWrite();
         RETURN FALSE;
      END;

      // replace roles in users, if the role is not new
      IF NOT currentName.Empty THEN
         _Users.Reset();
         WHILE _Users.MoveNext() DO
            i := _Users.CurrentData^.IndexOfOA( L",", 0 );
            IF i = -1 THEN
               CONTINUE;
            END;
            _Users.CurrentData^.Substring( 0, i, OUT userRole );
            IF userRole.Equals( currentName ) THEN
               _Users.CurrentData^.Remove( 0, i );
               _Users.CurrentData^.Prepend( roleName );
            END;
         END; // WHILE
      END;

      _Roles.Remove( currentName );
      _Roles.Add( roleName, PTR( role ));

      PersistUsers();
      
      _Lock.UnlockWrite();
      RETURN TRUE;
   END UpdateRole;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE DeleteRole( CONST roleName : StringsO.IString ) : BOOLEAN;
   VAR
      i : CARDINAL;
      userRole : StringsO.CString;
   BEGIN
      IF _Lock.LockWrite( Sync.FORSAFETY ) = Sync.arTimeout THEN
         ASSERTLOG( FALSE );
         RETURN FALSE;
      END;

      _Users.Reset();
      WHILE _Users.MoveNext() DO
         i := _Users.CurrentData^.IndexOfOA( L",", 0 );
         IF i = -1 THEN
            CONTINUE;
         END;
         _Users.CurrentData^.Substring( 0, i, OUT userRole );
         IF userRole.Equals( roleName ) THEN
            _Lock.UnlockWrite();
            RETURN FALSE; // cannot delete role when it is used
         END;
      END; // WHILE

      _Roles.Remove( roleName );
      PersistUsers();

      _Lock.UnlockWrite();
      RETURN TRUE;
   END DeleteRole;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CheckRenameUserConflict( CONST currentName, userName : StringsO.IString ) : BOOLEAN; // TRUE = conflict
   BEGIN
      IF currentName.Equals( userName ) THEN // no conflict on rename will appear
         RETURN FALSE;
      ELSIF _SysUsers.Contains( currentName ) OR _Users.Contains( userName ) THEN // user would be renamed to a name, which would collide with another existing one
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END CheckRenameUserConflict;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE UpdateUser( CONST roleName, currentName, userName, password : StringsO.IString ) : BOOLEAN;
   VAR
      authinfo : StringsO.CString;
      hash : sha256.CDigest;
      hashOA : sha256.TDigest;
      base64OA : ARRAY [0..63] OF WCHAR;
      role : TRole;
      rolePtr : PTR;
   BEGIN
      IF _Lock.LockWrite( Sync.FORSAFETY ) = Sync.arTimeout THEN
         ASSERTLOG( FALSE );
         RETURN FALSE;
      ELSIF NOT currentName.Empty AND NOT _Users.Contains( currentName ) OR NOT _Roles.Get( roleName, OUT rolePtr ) THEN // unable to edit user, which does not exist, or role of which does not exist
         _Lock.UnlockWrite();
         RETURN FALSE;
      ELSIF currentName.Equals( userName ) THEN
         // OK, only a property, not name is to be changed
      ELSIF _SysUsers.Contains( currentName ) OR _Users.Contains( userName ) THEN // unable to rename user to an existing name or to rename system user
         _Lock.UnlockWrite();
         RETURN FALSE;
      END;
      role := TRole( LOPTRLONGWORD( rolePtr ));
      
      // compute hash
      CASE role OF
      | roleSystemAdministrator :
         digest.DigestSalt( digest.sha256, OA( 2*password.Length-1, PBYTE( password.Data )), C"web_root", OUT hash );
      | roleSystemUser, roleUserNamed :
         digest.DigestSalt( digest.sha256, OA( 2*password.Length-1, PBYTE( password.Data )), C"message_file", OUT hash );
      | roleUserKeyed :
         digest.DigestSalt( digest.sha256, OA( 2*password.Length-1, PBYTE( password.Data )), C"project", OUT hash );
      ELSE
         _Lock.UnlockWrite();
         RETURN FALSE;
      END;
      hash.ToOA( OUT hashOA );
      IF NOT cphcommon.ToBASE64( hashOA, OUT base64OA ) THEN
         RETURN FALSE;
      END;
      
      authinfo.Assign( roleName );
      authinfo.AppendOA( L", " );
      authinfo.AppendOA( base64OA );

      _Users.Remove( currentName );
      _Users.Add( userName, authinfo );
      PersistUsers();
      
      _Lock.UnlockWrite();
      RETURN TRUE;
   END UpdateUser;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE DeleteUser( CONST userName : StringsO.IString ) : BOOLEAN;
   BEGIN
      IF _Lock.LockWrite( Sync.FORSAFETY ) = Sync.arTimeout THEN
         ASSERTLOG( FALSE );
         RETURN FALSE;
      ELSIF _SysUsers.Contains( userName ) THEN // system user cannot be deleted
         _Lock.UnlockWrite();
         RETURN FALSE;
      END;

      _Users.Remove( userName );
      PersistUsers();

      _Lock.UnlockWrite();
      
      RETURN TRUE;
   END DeleteUser;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( Port : CARDINAL; CONST ContextName : ARRAY OF WCHAR; CONST cfg : INIfile.CINIFile; EIB : srvcore.TPEIBServer; DeviceNames : ARRAY OF PWCHAR; Devices : ARRAY OF io.TPIStartStopControl; ConfigLogger, DataLogger : Log.TPBufferedLogger; HttpLogger : Log.TPILogger ) : BOOLEAN;
   CONST
      snProject = L"project";
         knName = L"name";
      snServer = L"server";
      snUsers = L"users";
      snAccessList = L"http_access_list";
         knAllow = L"allow";
         knDeny = L"deny";
      knWebRoot = L"web_root";
      knMessageFile = L"message_file";
      knSessionValidity = L"session_validity";
   VAR
      authinfo : StringsO.CString;
      es : PTR;
      line : CARDINAL;
      ok : BOOLEAN := TRUE;
      Path : ARRAY [0..260] OF WCHAR;
      rule : StringsO.CString;
      s : StringsO.CString;
      sessionValidity : CARDINAL;
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
      
      IF NOT cfg.SetSection( snProject ) OR
         NOT cfg.GetKeyStr( knName, OUT line, OUT _Project ) THEN
         _Project.FromOA( L"SmartServer Project" );
      END;

      IF cfg.SetSection( snServer ) AND FIO.GetModuleDirW( L"", OUT Path ) THEN // EXE dir
         IF cfg.GetKeyStr( knWebRoot, OUT line, OUT _RootDir ) THEN
            _RootDir.ReplaceOA( L"%exedir%", Path );
         ELSE
            _RootDir.FromOA( Path );
         END;
         IF cfg.GetKeyStr( knMessageFile, OUT line, OUT _MessageFile ) THEN
            _MessageFile.ReplaceOA( L"%exedir%", Path );
         END;
         IF cfg.GetKeyInt( knSessionValidity, OUT line, OUT sessionValidity ) THEN
            _SessionValidity := sessionValidity;
         END;
      END;
      IF _RootDir.Empty THEN
         ok := FALSE;
         Log.logger()^.LogS( Log.lcError, 0, LOG_PREFIX, L"Web root is not defined, web interface will not start." );
      END;
      IF _MessageFile.Empty THEN
         ok := FALSE;
         Log.logger()^.LogS( Log.lcError, 0, LOG_PREFIX, L"Message source for web is not defined, web interface will not start." );
      END;
      
      // add system roles      
      _Roles.AddOA( ROLE_SYS_ADMIN, PTR( roleSystemAdministrator ));
      _Roles.AddOA( ROLE_SYS_USER, PTR( roleSystemUser ));
      
      // load users from system configuration
      IF NOT cfg.SetSection( snUsers ) THEN
         ok := FALSE;
         Log.logger()^.LogS( Log.lcError, 0, LOG_PREFIX, L"No users defined, web interface will not start." );
      ELSE
         es := 0;
         WHILE cfg.EnumerateKeys( REF es, OUT line, OUT s, OUT authinfo ) DO // sOA = name, authinfo = role, hash
            _Users.Remove( s );
            _Users.Add( s, authinfo );
            _SysUsers.Add( s, 0 );
         END; // WHILE
      END;
      
      IF cfg.SetSection( snAccessList ) THEN
         es := 0;
         WHILE cfg.EnumerateKeys( REF es, OUT line, OUT rule, OUT s ) DO
            s.Trim();
            IF rule.EqualsOA( knAllow ) THEN
               _AccessList.AddRuleS( accesslist.actAllow, s );
            ELSIF rule.EqualsOA( knDeny ) THEN
               _AccessList.AddRuleS( accesslist.actDeny, s );
            ELSE
               ConfigLogger^.LogFilePos( Log.lcError, 0, LOG_PREFIX, L"Only 'allow' and 'deny' rules are allowed, the rule will be ignored.", L"(web config file)", line, 0 );
            END; 
         END; // WHILE
      END;
      
      IF ok THEN
         LoadWebUsers();
      END;
      
      RETURN ok
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
      _MVC := mvc.mvc( OA( _Context.Length-1, _Context.Data ));
      _MVC^.SessionValidity := _SessionValidity;
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
      _StartedTime := datetime.GetCurrentJD();      

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
      
      _Roles.Dispose();
      _Users.Dispose();
      _SysUsers.Dispose();
      
      // unhook EIB
      _EIB^.EventSink := NIL;
      
      ASSERT( _MVC <> NIL );
      RemoveControllers();
      mvc.Cleanup();

      httpsrv.srv()^.Stop();
      httpsrv.Cleanup();
   END Stop;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE LoadWebUsers() : BOOLEAN; // load users from self configuration file
   VAR
      authinfo : StringsO.CString;
      cfg : INIfile.CINIFile;
      es : PTR;
      i : CARDINAL;
      key : StringsO.CString;
      line : CARDINAL;
      role : StringsO.CString;
      user : StringsO.CString;
      usersFileOA : FIO.PathStrW;
   BEGIN
      IF NOT Folders.GetManufacturerSpecialFolderW( Folders.sfAppDataCommon, TRUE, OUT usersFileOA ) THEN
         RETURN FALSE;
      END;
      FIO.PathAddW( REF usersFileOA, cfSmartServerUsersFolder );
      FIO.PathAddW( REF usersFileOA, cfSmartServerUsersFile );
      IF NOT cfg.LoadPath( usersFileOA ) THEN 
         RETURN FALSE;
      END;
      
      IF cfg.SetSection( snRoles ) THEN
         es := 0;
         WHILE cfg.EnumerateKeys( REF es, OUT line, OUT key, OUT role ) DO
            IF role.EqualsOA( ROLE_SYS_ADMIN ) OR role.EqualsOA( ROLE_SYS_USER ) THEN // cannot override system roles
               CONTINUE;
            ELSIF key.EqualsOA( knNamed ) THEN
               _Roles.Remove( role );
               _Roles.Add( role, PTR( roleUserNamed ));
            ELSIF key.EqualsOA( knKeyed ) THEN
               _Roles.Remove( role );
               _Roles.Add( role, PTR( roleUserKeyed ));
            ELSE
               CONTINUE;
            END;
         END; // WHILE roles
      END;
      
      IF cfg.SetSection( snUsers ) THEN
         es := 0;
         WHILE cfg.EnumerateKeys( REF es, OUT line, OUT user, OUT authinfo ) DO
            // detect and filter out missing roles
            authinfo.Trim();
            i := authinfo.IndexOfOA( L",", 0 );
            IF i = -1 THEN
               CONTINUE;
            END;
            authinfo.Substring( 0, i, OUT role );
            role.Trim();
            IF NOT _Roles.Contains( role ) THEN
               CONTINUE;
            END;

            _Users.Remove( user );
            _Users.Add( user, authinfo );
         END; // WHILE roles
      END;
      
      RETURN TRUE;
   END LoadWebUsers;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE PersistUsers(); // synchronized
   VAR
      cfg : INIfile.CINIFile;
      usersFileOA : FIO.PathStrW;
   BEGIN
      IF NOT Folders.GetManufacturerSpecialFolderW( Folders.sfAppDataCommon, TRUE, OUT usersFileOA ) THEN
         ASSERTLOG( FALSE, L"Unable to get web users file folder" );
         RETURN;
      END;
      FIO.PathAddW( REF usersFileOA, cfSmartServerUsersFolder );
      IF NOT FIO.CreateDirectoryW( usersFileOA ) THEN
         ASSERTLOG( FALSE, L"Unable to store to web users file" );
         RETURN; // store nothing
      END;
      FIO.PathAddW( REF usersFileOA, cfSmartServerUsersFile );
      cfg.LoadPath( usersFileOA ); // load the file

      cfg.CreateSection( snRoles, FALSE );
      cfg.ClearSection( snRoles );
      IF cfg.SetSection( snRoles ) THEN
         _Roles.Reset();
         WHILE _Roles.MoveNext() DO
            CASE TRole( LOPTRLONGWORD( _Roles.CurrentData )) OF
            | roleSystemAdministrator,
              roleSystemUser :
               CONTINUE; // roles are not written
            | roleUserKeyed :
               cfg.SetKeyStr( knKeyed, _Roles.Current^, TRUE );
            ELSE
               cfg.SetKeyStr( knNamed, _Roles.Current^, TRUE );
            END;
         END;
      END;

      cfg.CreateSection( snUsers, FALSE );
      cfg.ClearSection( snUsers );
      IF cfg.SetSection( snUsers ) THEN
         _Users.Reset();
         WHILE _Users.MoveNext() DO
            cfg.SetKeyStr( OA( _Users.Current^.Length-1, _Users.Current^.Data ), _Users.CurrentData^, FALSE );
         END;
      END;

      cfg.SavePath( usersFileOA ); // save the file
   END PersistUsers;

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
      
      _MVC^.RegisterController( _Controller, HttpCommon.verbGET, Controller.USERS_PAGE );

      _MVC^.RegisterController( _Controller, HttpCommon.verbGET, Controller.ROLE_EDIT_PAGE );
      _MVC^.RegisterController( _Controller, HttpCommon.verbPOST, Controller.ROLE_EDIT_PAGE );
      
      _MVC^.RegisterController( _Controller, HttpCommon.verbGET, Controller.USER_EDIT_PAGE );
      _MVC^.RegisterController( _Controller, HttpCommon.verbPOST, Controller.USER_EDIT_PAGE );
      
      _MVC^.RegisterController( _Controller, HttpCommon.verbGET, Controller.USER_LOGIN_PAGE );
      _MVC^.RegisterController( _Controller, HttpCommon.verbPOST, Controller.USER_LOGIN_PAGE );
      
      _MVC^.RegisterFallbackController( _Controller );
   END AddControllers;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE RemoveControllers();
   VAR
      LController : Controller.TPController := Controller.TPController( _Controller );
   BEGIN
      IF LController <> NIL THEN
         _MVC^.ForgetControllerCompletely( LController );
         DISPOSE( LController );
         _Controller := NIL;
      END;

      _MVC^.ForgetFallbackController();
   END RemoveControllers;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE AdjustHours( CONST dt : datetime.DateTime; REF hours : ARRAY OF CARDINAL; REF modified : ARRAY OF datetime.DayCount );
   CONST
      TWENTY_THREE_HOURS = datetime.unitsInDay DIV 24 * 23 - 1;
   VAR
      dc : datetime.DayCount := dt.DayCount;
      i : CARDINAL;
      locked : BOOLEAN := FALSE;
   BEGIN
      IF _Lock.LockWrite( Sync.FORSAFETY ) = Sync.arTimeout THEN
         ASSERTLOG( FALSE );
         RETURN;
      END;

      FOR i := 0 TO HIGH( hours ) DO
         IF modified[i] + TWENTY_THREE_HOURS < dc THEN
            hours[i] := 0;
         END;
      END;
      modified[dt.Hour MOD 24] := dc;

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
   _SessionValidity := 30 * 60; // 30 minutes
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
