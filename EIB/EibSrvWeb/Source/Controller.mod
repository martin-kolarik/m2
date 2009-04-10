IMPLEMENTATION MODULE Controller;

(*================================================================================*)

FROM Debug IMPORT
   Assertion;
   
IMPORT
   EibSrvWeb,
   FIO,
   FIOO,
   HttpCommon,
   HttpTools,
   lec,
   lists,
   Log,
   Strings,
   time;

(*--------------------------------------------------------------------------------*)

CONST
   CRLF = 13W + 10W;
   SESSION_LOGGED = L"logged";
   SESSION_ROLE = L"role";
   ROLE_ADMIN = L"isAdmin";
   USER_LOGGED = L"isLogged";
   VERSION = L"version";
   
   RESOLVER_CONTEXT_WEB = 0;
   RESOLVER_CONTEXT_DISK = 1;

   LOGIN_VIEW = L"login.pt.xml";
   STATUS_VIEW = L"status.pt.xml";
   CONTROL_VIEW = L"control.pt.xml";
   DATA_LOG_VIEW = L"datalog.pt.xml";
   SYSTEM_LOG_VIEW = L"syslog.pt.xml";
   IO_VIEW = L"io.pt.xml";
   INDEX_VIEW = L"index.pt.xml";
   
   LOGIN_MESSAGE = L"message";
   LOGIN_USERNAME = L"username";
   LOGIN_PASSWORD = L"password";
   
   DATETIME_FORMAT = L"d. MMMM H.mm:ss 'GMT'";
   STATUS_CONNECTED = L"connected";
   STATUS_CONNECTIONTIME = L"connectionTime";
   STATUS_UPTIME = L"uptime";
   STATUS_LICENCE_VALID = L"licenceValid";
   STATUS_LICENCE = L"licence";
   STATUS_LICENCE_NUMBER = L"licenceNumber";
   STATUS_LICENCE_TYPE = "licenceType";
   STATUS_LAST_HOUR = L"ioLastHour";
   STATUS_LAST_DAY = L"ioLastDay";
   STATUS_CONFIGURATION = L"configurationPath";
   STATUS_CONNECT = L"connect";
   STATUS_DISCONNECT = L"disconnect";
   
   CONTROL_DEVICES_NAME = L"names";
   CONTROL_DEVICES_RUN = L"runStatus";
   CONTROL_DEVICES_IDX = L"indexes";
   CONTROL_START = L"start";
   CONTROL_STOP = L"stop";
   CONTROL_DOWNLOAD = L"download";
   CONTROL_CONFIG_LOG = L"configLog";
   CONTROL_CONFIG_FILE = L"configFile";
   
   LOG_LOG = L"logRecords";
   LOG_DOWNLOAD = L"download";
   
   IO_FORM_ID = L"formId";
   IO_READ_NAME = L"readName";
   IO_READ_VALUE = L"readValue";
   IO_DO_READ  = L"read";
   IO_READ_FAILED = L"readFailed";
   IO_WRITE_NAME = L"writeName";
   IO_WRITE_VALUE = L"writeValue";
   IO_DO_WRITE = L"write";
   IO_WRITE_FAILED = L"writeFailed";

   DYNAMIC_SUFFIX = L".pt.xml";
   FN_SET = L"set";
   FN_GET = L"get";

(*================================================================================*)

CLASS IMPLEMENTATION CController;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE ResolvePath( Context : PTR; CONST Fragment : ARRAY OF WCHAR; OUT Resolved : StringsO.IString ) : BOOLEAN;
   VAR
      f : StringsO.CString;
   BEGIN
      IF Context = RESOLVER_CONTEXT_DISK THEN
         IF FIO.IsUNCW( Fragment ) OR FIO.IsDriveW( Fragment ) THEN
            Resolved.FromOA( Fragment );
         ELSE
            RETURN FALSE;
         END;
      ELSIF Context = RESOLVER_CONTEXT_WEB THEN
         Resolved.Assign( _Web^.RootDir^ );
         IF Resolved.Empty THEN
            RETURN FALSE;
         ELSE
            f.FromOA( Fragment );
            FIOO.PathAdd( REF Resolved, f );
         END;
      ELSE
         RETURN FALSE;
      END;
      RETURN TRUE;
   END ResolvePath;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Call( CONST FunctionName : StringsO.IString; REF Parameters : lists.CStringStringList; RetVal : StringsO.TPString ) : BOOLEAN;
   VAR
      name, s, value : StringsO.CString;
   BEGIN
      IF FunctionName.EqualsOA( FN_SET ) THEN
         IF Parameters.Count < 2 THEN
            RETURN FALSE;
         END;
         Parameters.ElementAt( 0, OUT s, OUT name );
         Parameters.ElementAt( 1, OUT s, OUT value );
         RETURN _Web^.SetValue( name, value );
      ELSIF FunctionName.EqualsOA( FN_GET ) THEN
         IF Parameters.Count < 2 THEN
            RETURN FALSE;
         END;
         Parameters.ElementAt( 0, OUT s, OUT name );
         IF NOT _Web^.GetValue( name, OUT value ) THEN
            RETURN FALSE;
         ELSIF RetVal <> NIL THEN
            RetVal^.Assign( value );
         END;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END Call;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE ResolveMIME( ResolveContext : PTR; CONST Source : StringsO.IString; OUT ContentHeader : StringsO.IString ) : BOOLEAN;
   VAR
      s : StringsO.CString;
   BEGIN
      s.Assign( Source );
      s.Lowerize();
      IF Source.EndsWithOA( L"cfg" ) THEN
         HttpTools.FormatContentOA( HttpTools.contentTextPlain, L"", L"utf-8", FALSE, OUT ContentHeader );
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END ResolveMIME;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE ProcessRequest( Fallback : BOOLEAN; CONST Request : mvc.IHttpRequest; OUT View : mvc.TPView ) : BOOLEAN; // returning false means 500 response
   VAR
      data : PTR;
      role : EibSrvWeb.TRole;
      uri : StringsO.CString;
      version : StringsO.CString;
   BEGIN
      IF Request.Session^.Get( SESSION_ROLE, OUT data ) THEN
         role := EibSrvWeb.TRole( LOPTRLONGWORD( data ));
      ELSE
         role := EibSrvWeb.roleGuest;
         Request.Session^.Add( SESSION_ROLE, PTR( role ));
      END;
      
      version.FromOA( ProductVersion );
      Request.ModelContainer^.AddStringOA( VERSION, version );

      IF Fallback THEN
         uri := Request.ControllerURI;
         IF NOT uri.EndsWithOA( DYNAMIC_SUFFIX ) THEN
            View := mvc.fileView( ADR( SELF ), RESOLVER_CONTEXT_WEB, OA( uri.Length-1, uri.rawData ), FALSE, ADR( SELF ), RESOLVER_CONTEXT_WEB );
         ELSIF NOT Request.ModelContainer^.GetFunctionCallsMemo() THEN // no call during the request
            Request.ModelContainer^.AddFunctionHandlerOA( FN_SET, ADR( SELF ));
            Request.ModelContainer^.AddFunctionHandlerOA( FN_GET, ADR( SELF ));
            View := mvc.pageTemplateView( ADR( SELF ), OA( uri.Length-1, uri.rawData ));
         ELSE // some call was performed, redirect to self
            View := mvc.redirectView( OA( uri.Length-1, uri.rawData ));
         END;
         RETURN TRUE;
   
      ELSIF Request.ControllerURI.EqualsOA( INDEX_PAGE ) THEN
         Request.ModelContainer^.AddBooleanOA( USER_LOGGED, Request.Session^.Get( SESSION_LOGGED, OUT data ) AND ( data = PTR( ADR( SELF ))) );
         View := mvc.pageTemplateView( ADR( SELF ), INDEX_VIEW );
         RETURN TRUE;
      
      ELSIF Request.ControllerURI.EqualsOA( LOGIN_PAGE ) THEN
         RETURN ProcessLogin( Request, OUT View );
      
      ELSIF Request.ControllerURI.EqualsOA( LOGOUT_PAGE ) THEN
         Request.Session^.Remove( SESSION_LOGGED );
         View := mvc.redirectView( LOGIN_PAGE );
         RETURN TRUE;
      
      ELSIF Request.ControllerURI.Empty THEN // context directly accessed
         View := mvc.redirectView( INDEX_PAGE );
         RETURN TRUE;

      ELSIF NOT Request.Session^.Get( SESSION_LOGGED, OUT data ) OR ( data <> PTR( ADR( SELF ))) THEN
         Request.Session^.Remove( SESSION_LOGGED );
         View := mvc.redirectView( LOGIN_PAGE );
         RETURN TRUE;
      
      ELSIF Request.ControllerURI.EqualsOA( STATUS_PAGE ) THEN
         Request.ModelContainer^.AddBooleanOA( ROLE_ADMIN, role = EibSrvWeb.roleAdministrator );
         RETURN ProcessStatus( Request, OUT View );

      ELSIF Request.ControllerURI.EqualsOA( CONTROL_PAGE ) THEN
         IF role = EibSrvWeb.roleAdministrator THEN
            Request.ModelContainer^.AddBooleanOA( ROLE_ADMIN, TRUE );
            RETURN ProcessControl( Request, OUT View );
         ELSE
            View := mvc.httpStatusCodeView( HttpCommon.httpres_Unauthorized );
            RETURN TRUE;
         END;

      ELSIF Request.ControllerURI.EqualsOA( SYSTEM_LOG_PAGE ) THEN
         IF role = EibSrvWeb.roleAdministrator THEN
            Request.ModelContainer^.AddBooleanOA( ROLE_ADMIN, TRUE );
            RETURN ProcessSystemLog( Request, OUT View );
         ELSE
            View := mvc.httpStatusCodeView( HttpCommon.httpres_Unauthorized );
            RETURN TRUE;
         END;

      ELSIF Request.ControllerURI.EqualsOA( DATA_LOG_PAGE ) THEN
         Request.ModelContainer^.AddBooleanOA( ROLE_ADMIN, role = EibSrvWeb.roleAdministrator );
         RETURN ProcessDataLog( Request, OUT View );

      ELSIF Request.ControllerURI.EqualsOA( IO_PAGE ) THEN
         Request.ModelContainer^.AddBooleanOA( ROLE_ADMIN, role = EibSrvWeb.roleAdministrator );
         RETURN ProcessIO( Request, OUT View );

      END;

      ASSERT( FALSE );
      RETURN FALSE;
   END ProcessRequest;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE BindToEibSrv( web : EibSrvWeb.TPEibSrvWeb );
   BEGIN
      _Web := web;
   END BindToEibSrv;
   
(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ProcessLogin( CONST Request : mvc.IHttpRequest; OUT View : mvc.TPView ) : BOOLEAN;
   VAR
      su, sp : StringsO.CString;
   BEGIN
      IF Request.RequestVerb = HttpCommon.verbGET THEN // OK, only render a login page
         Request.ModelContainer^.AddStringOA( LOGIN_MESSAGE, sp ); // empty
         Request.ModelContainer^.AddStringOA( LOGIN_USERNAME, sp ); // empty
         Request.ModelContainer^.AddStringOA( LOGIN_PASSWORD, sp ); // empty
         View := mvc.pageTemplateView( ADR( SELF ), LOGIN_VIEW );

      // post, try to login
      ELSIF NOT Request.ModelContainer^.GetStringOA( LOGIN_USERNAME, OUT su ) OR // bad input
            NOT Request.ModelContainer^.GetStringOA( LOGIN_PASSWORD, OUT sp ) OR // bad input
            NOT ValidateUser( Request, su, sp ) THEN // bad credentials
         Request.MessageSource^.GetMessageOA( Request.Language, L"login.badCredentials", OUT su );
         Request.ModelContainer^.AddStringOA( LOGIN_MESSAGE, su );

         sp.Clear();
         Request.ModelContainer^.AddStringOA( LOGIN_MESSAGE, sp ); // empty
         Request.ModelContainer^.AddStringOA( LOGIN_USERNAME, sp ); // empty
         Request.ModelContainer^.AddStringOA( LOGIN_PASSWORD, sp ); // empty
         View := mvc.pageTemplateView( ADR( SELF ), LOGIN_VIEW );
         
      ELSE // OK, set up session, redirect to status page
         Request.Session^.Remove( SESSION_LOGGED );
         Request.Session^.Add( SESSION_LOGGED, ADR( SELF ));
         View := mvc.redirectView( STATUS_PAGE );

      END;

      RETURN TRUE;
   END ProcessLogin;
   
(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ProcessStatus( CONST Request : mvc.IHttpRequest; OUT View : mvc.TPView ) : BOOLEAN;
   VAR
      b : BOOLEAN;
      c : CARDINAL;
      cs : StringsO.CString;
      currentDT : time.DateTime;
      currentTime : time.TJD;
      dt : time.DateTime;
      lt : lec.TLicenceType;
      s : ARRAY [0..63] OF WCHAR;
      starttime : time.TJD;
      uptime : time.TJDC;
   BEGIN
      // check actions to do
      IF Request.ModelContainer^.GetBooleanOA( STATUS_CONNECT, OUT b ) AND b THEN
         _Web^.ConnectEIB();
         Request.ModelContainer^.AddBooleanOA( STATUS_CONNECT, FALSE );
         View := mvc.redirectView( STATUS_PAGE );
         RETURN TRUE;
      ELSIF Request.ModelContainer^.GetBooleanOA( STATUS_DISCONNECT, OUT b ) AND b THEN
         _Web^.DisconnectEIB();
         Request.ModelContainer^.AddBooleanOA( STATUS_DISCONNECT, FALSE );
         View := mvc.redirectView( STATUS_PAGE );
         RETURN TRUE;
      END;
   
      b := _Web^.Connected;
      Request.ModelContainer^.AddBooleanOA( STATUS_CONNECTED, b );

      starttime := _Web^.StartedTime;
      IF b THEN
         dt.JulianDate := _Web^.ConnectedTime;
      ELSE
         dt.JulianDate := _Web^.DisconnectedTime;
      END;
      IF dt.Empty THEN
         dt.JulianDate := starttime;
      END;
      IF dt.ToLanguageStringOA( Request.Language, DATETIME_FORMAT, TRUE, TRUE, OUT s ) THEN
         cs.FromOA( s );
      ELSE
         cs.FromOA( L"N/A" );
      END;
      Request.ModelContainer^.AddStringOA( STATUS_CONNECTIONTIME, cs );
      Request.ModelContainer^.AddBooleanOA( STATUS_CONNECT, FALSE );
      Request.ModelContainer^.AddBooleanOA( STATUS_DISCONNECT, FALSE );
      
      currentDT.SetNowUTC();
      currentTime := currentDT.JulianDate;
      uptime := currentTime - starttime;
      dt.Day := time.JDCToDays( uptime );
      time.fd2HMS( time.fd( uptime ), OUT dt.Hour, OUT dt.Minute, OUT dt.Second, OUT dt.Millisecond );
      IF dt.Second > 0 THEN
         INC( dt.Minute );
      END;
      Strings.FromCARD32W( dt.Day, 10, OUT s );
      cs.FromOA( s );
      cs.AppendOA( L"d " );
      Strings.FromCARD32W( dt.Hour, 10, OUT s );
      cs.AppendOA( s );
      cs.AppendOA( L"h " );
      Strings.FromCARD32W( dt.Minute, 10, OUT s );
      cs.AppendOA( s );
      cs.AppendOA( L"m " );
      Request.ModelContainer^.AddStringOA( STATUS_UPTIME, cs );

      dt := _Web^.LicenceExpires;
      IF dt.Day = 0 THEN
         Request.MessageSource^.GetMessageOA( Request.Language, L"status.licencePermanent", OUT cs );
      ELSE
         dt.ToLanguageStringOA( Request.Language, DATETIME_FORMAT, TRUE, TRUE, OUT s );
         Request.MessageSource^.GetMessageOA( Request.Language, L"status.licenceValidUntil", OUT cs );
         cs.AppendOA( s );
      END;
      Request.ModelContainer^.AddBooleanOA( STATUS_LICENCE_VALID, ( dt.Day = 0 ) OR ( currentDT < dt ));
      Request.ModelContainer^.AddStringOA( STATUS_LICENCE, cs );

      Request.ModelContainer^.AddStringOA( STATUS_LICENCE_NUMBER, _Web^.Licence );
      cs.Clear();
      lt := _Web^.LicenceType;
      IF lec.ltEducational IN lt THEN
         cs.FromOA( L"EDU " );
      END;
      IF lec.ltTrial IN lt THEN
         cs.FromOA( L"TRIAL " );
      END;
      Request.ModelContainer^.AddStringOA( STATUS_LICENCE_TYPE, cs );
      
      c := _Web^.WrittenByHour + _Web^.ReadByHour;
      cs.FromCARD32( c, 10 );
      Request.ModelContainer^.AddStringOA( STATUS_LAST_HOUR, cs );

      c := _Web^.WrittenByDay + _Web^.ReadByDay;
      cs.FromCARD32( c, 10 );
      Request.ModelContainer^.AddStringOA( STATUS_LAST_DAY, cs );
 
      Request.ModelContainer^.AddStringOA( STATUS_CONFIGURATION, _Web^.Configuration^ );
 
      View := mvc.pageTemplateView( ADR( SELF ), STATUS_VIEW );
      RETURN TRUE;
   END ProcessStatus;
   
(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ProcessControl( CONST Request : mvc.IHttpRequest; OUT View : mvc.TPView ) : BOOLEAN;
   VAR
      count : CARDINAL;
      cs : StringsO.CString;
      i : CARDINAL;
      log : ARRAY [0..511] OF WCHAR;
      listDevices : lists.TPStringStringList;
      listRunning : lists.TPStringStringList;
      listIndexes : lists.TPStringStringList;
   BEGIN
      // check actions to do
      IF Request.RequestVerb = HttpCommon.verbPOST THEN // OK, process form output
         IF Request.ModelContainer^.GetStringOA( CONTROL_CONFIG_FILE, OUT cs ) THEN
            _Web^.ConfigureEIB( cs );
         END;
         View := mvc.redirectView( CONTROL_PAGE );
         RETURN TRUE;
      ELSIF Request.ModelContainer^.GetStringOA( CONTROL_START, OUT cs ) AND cs.ToCARD32( 10, OUT i ) AND ( i <> -1 ) THEN
         cs.FromOA( L"-1" );
         Request.ModelContainer^.AddStringOA( CONTROL_START, cs );
         IF i > MAX( INTEGER ) THEN
            // do nothing
         ELSIF i < _Web^.OperatedDeviceCount THEN
            _Web^.OperateDevice( i, TRUE );
         END;
         View := mvc.redirectView( CONTROL_PAGE );
         RETURN TRUE;
      ELSIF Request.ModelContainer^.GetStringOA( CONTROL_STOP, OUT cs ) AND cs.ToCARD32( 10, OUT i ) AND ( i <> -1 ) THEN
         cs.FromOA( L"-1" );
         Request.ModelContainer^.AddStringOA( CONTROL_STOP, cs );
         IF i > MAX( INTEGER ) THEN
            // do nothing
         ELSIF i < _Web^.OperatedDeviceCount THEN
            _Web^.OperateDevice( i, FALSE );
         END;
         View := mvc.redirectView( CONTROL_PAGE );
         RETURN TRUE;
      ELSIF Request.ModelContainer^.GetStringOA( CONTROL_DOWNLOAD, OUT cs ) AND cs.ToCARD32( 10, OUT i ) AND ( i <> -1 ) THEN
         cs.FromOA( L"-1" );
         Request.ModelContainer^.AddStringOA( CONTROL_DOWNLOAD, cs );
         View := mvc.fileView( ADR( SELF ), RESOLVER_CONTEXT_DISK, OA( _Web^.Configuration^.Length-1, _Web^.Configuration^.rawData ), TRUE, ADR( SELF ), RESOLVER_CONTEXT_WEB );
         RETURN TRUE;
      END;

      Request.ModelContainer^.AddListOA( CONTROL_DEVICES_NAME, OUT listDevices ); listDevices^.Clear();
      Request.ModelContainer^.AddListOA( CONTROL_DEVICES_RUN, OUT listRunning ); listRunning^.Clear();
      Request.ModelContainer^.AddListOA( CONTROL_DEVICES_IDX, OUT listIndexes ); listIndexes^.Clear();

      count := _Web^.OperatedDeviceCount;
      IF count > 0 THEN
         FOR i := 0 TO count-1 DO
            Request.MessageSource^.GetMessageOA( Request.Language, OAsz( _Web^.OperatedDeviceName( i )), OUT cs );
            listDevices^.Add( cs, cs );

            IF _Web^.DeviceRunning( i ) THEN
               cs.FromOA( L"true" );
            ELSE
               cs.FromOA( L"false" );
            END;
            listRunning^.Add( cs, cs );

            cs.FromCARD32( i, 10 );
            listIndexes^.Add( cs, cs );
         END;
      END;

      cs.FromOA( L"-1" );
      Request.ModelContainer^.AddStringOA( CONTROL_START, cs );
      Request.ModelContainer^.AddStringOA( CONTROL_STOP, cs );
      Request.ModelContainer^.AddStringOA( CONTROL_DOWNLOAD, cs );

      Request.ModelContainer^.AddStringOA( CONTROL_CONFIG_FILE, _Web^.Configuration^ );
      
      count := _Web^.ConfigLogger^.BufferCount;
      cs.Clear();
      IF count > 0 THEN
         FOR i := 0 TO count-1 DO
            IF i > 0 THEN
               cs.AppendOA( CRLF );
            END;
            _Web^.ConfigLogger^.BufferGetItem( i, OUT log );
            cs.AppendOA( log );
         END;
      END;
      Request.ModelContainer^.AddStringOA( CONTROL_CONFIG_LOG, cs );
            
      View := mvc.pageTemplateView( ADR( SELF ), CONTROL_VIEW );
      RETURN TRUE;
   END ProcessControl;
   
(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ProcessDataLog( CONST Request : mvc.IHttpRequest; OUT View : mvc.TPView ) : BOOLEAN;
   VAR
      count : CARDINAL;
      cs : StringsO.CString;
      downloadFlag : BOOLEAN;
      empty : StringsO.CString;
      i : CARDINAL;
      log : ARRAY [0..511] OF WCHAR;
      logS : StringsO.CString;
   BEGIN
      downloadFlag := Request.ModelContainer^.GetStringOA( LOG_DOWNLOAD, OUT cs ) AND cs.ToCARD32( 10, OUT i ) AND ( i <> -1 );
      count := _Web^.DataLogger^.BufferCount;

      IF downloadFlag THEN
         // direct order
         IF count > 0 THEN
            FOR i := 0 TO count-1 DO
               IF i > 0 THEN
                  logS.AppendOA( CRLF );
               END;
               _Web^.DataLogger^.BufferGetItem( i, OUT log );
               logS.AppendOA( log );
            END;
         END;

         View := mvc.rawTextView( OA( logS.Length-1, logS.rawData ), L"datalog", empty, TRUE );
      ELSE
         // backward order
         IF count > 0 THEN
            FOR i := count-1 TO 0 BY -1 DO
               IF i < count-1 THEN
                  logS.AppendOA( CRLF );
               END;
               _Web^.DataLogger^.BufferGetItem( i, OUT log );
               logS.AppendOA( log );
            END;
         END;

         Request.ModelContainer^.AddStringOA( LOG_LOG, logS );
         View := mvc.pageTemplateView( ADR( SELF ), DATA_LOG_VIEW );
      END;

      cs.FromOA( L"-1" );
      Request.ModelContainer^.AddStringOA( LOG_DOWNLOAD, cs );

      RETURN TRUE;
   END ProcessDataLog;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ProcessSystemLog( CONST Request : mvc.IHttpRequest; OUT View : mvc.TPView ) : BOOLEAN;
   VAR
      count : CARDINAL;
      cs : StringsO.CString;
      empty : StringsO.CString;
      i : CARDINAL;
      log : ARRAY [0..511] OF WCHAR;
      logS : StringsO.CString;
   BEGIN
      count := Log.logger()^.BufferCount;
      IF count > 0 THEN
         FOR i := 0 TO count-1 DO
            IF i > 0 THEN
               logS.AppendOA( CRLF );
            END;
            Log.logger()^.BufferGetItem( i, OUT log );
            logS.AppendOA( log );
         END;
      END;

      IF Request.ModelContainer^.GetStringOA( LOG_DOWNLOAD, OUT cs ) AND cs.ToCARD32( 10, OUT i ) AND ( i <> -1 ) THEN
         View := mvc.rawTextView( OA( logS.Length-1, logS.rawData ), L"systemlog", empty, TRUE );
      ELSE
         Request.ModelContainer^.AddStringOA( LOG_LOG, logS );
         View := mvc.pageTemplateView( ADR( SELF ), SYSTEM_LOG_VIEW );
      END;

      cs.FromOA( L"-1" );
      Request.ModelContainer^.AddStringOA( LOG_DOWNLOAD, cs );

      RETURN TRUE;
   END ProcessSystemLog;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ProcessIO( CONST Request : mvc.IHttpRequest; OUT View : mvc.TPView ) : BOOLEAN;
   VAR
      b : BOOLEAN;
      empty, fid : StringsO.CString;
      rfailed : BOOLEAN := FALSE;
      rname, rvalue : StringsO.CString;
      wfailed : BOOLEAN := FALSE;
      wname, wvalue : StringsO.CString;
   BEGIN
      IF Request.RequestVerb <> HttpCommon.verbPOST THEN
         // OK, only display
         Request.ModelContainer^.GetStringOA( IO_WRITE_NAME, OUT wname );
         Request.ModelContainer^.GetStringOA( IO_WRITE_VALUE, OUT wvalue );
         Request.ModelContainer^.GetBooleanOA( IO_WRITE_FAILED, OUT wfailed );
         Request.ModelContainer^.GetStringOA( IO_READ_NAME, OUT rname );
         Request.ModelContainer^.GetStringOA( IO_READ_VALUE, OUT rvalue );
         Request.ModelContainer^.GetBooleanOA( IO_READ_FAILED, OUT rfailed );

      ELSIF Request.ModelContainer^.GetStringOA( IO_FORM_ID, OUT fid ) AND fid.EqualsOA( IO_DO_READ ) THEN
         IF Request.ModelContainer^.GetStringOA( IO_READ_NAME, OUT rname ) THEN
            IF _Web^.GetValue( rname, OUT rvalue ) THEN
               Request.ModelContainer^.AddStringOA( IO_READ_VALUE, rvalue );
               Request.ModelContainer^.AddBooleanOA( IO_READ_FAILED, FALSE );
            ELSE
               Request.ModelContainer^.AddStringOA( IO_READ_VALUE, empty );
               Request.ModelContainer^.AddBooleanOA( IO_READ_FAILED, TRUE );
            END;
         END;
         
         View := mvc.redirectView( IO_PAGE );
         RETURN TRUE;

      ELSIF Request.ModelContainer^.GetStringOA( IO_FORM_ID, OUT fid ) AND fid.EqualsOA( IO_DO_WRITE ) THEN
         IF Request.ModelContainer^.GetStringOA( IO_WRITE_NAME, OUT wname ) AND
            Request.ModelContainer^.GetStringOA( IO_WRITE_VALUE, OUT wvalue ) THEN
            Request.ModelContainer^.AddBooleanOA( IO_WRITE_FAILED, NOT _Web^.SetValue( wname, wvalue ));
         END;

         View := mvc.redirectView( IO_PAGE );
         RETURN TRUE;
         
      ELSE // error
         View := mvc.redirectView( IO_PAGE );
         RETURN TRUE;
      END;

      Request.ModelContainer^.AddFunctionHandlerOA( FN_SET, ADR( SELF ));
      Request.ModelContainer^.AddFunctionHandlerOA( FN_GET, ADR( SELF ));

      Request.ModelContainer^.AddStringOA( IO_FORM_ID, empty );
      Request.ModelContainer^.AddStringOA( IO_READ_NAME, rname );
      Request.ModelContainer^.AddStringOA( IO_READ_VALUE, rvalue );
      Request.ModelContainer^.AddBooleanOA( IO_READ_FAILED, rfailed );
      Request.ModelContainer^.AddStringOA( IO_WRITE_NAME, wname );
      Request.ModelContainer^.AddStringOA( IO_WRITE_VALUE, wvalue );
      Request.ModelContainer^.AddBooleanOA( IO_WRITE_FAILED, wfailed );

      View := mvc.pageTemplateView( ADR( SELF ), IO_VIEW );
      RETURN TRUE;
   END ProcessIO;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ValidateUser( CONST Request : mvc.IHttpRequest; CONST UserName, Password : StringsO.CString ) : BOOLEAN;
   VAR
      role : EibSrvWeb.TRole;
   BEGIN
      role := _Web^.Authenticate( UserName, Password );
      Request.Session^.Remove( SESSION_ROLE );
      Request.Session^.Add( SESSION_ROLE, PTR( role ));
      RETURN role <> EibSrvWeb.roleGuest;
   END ValidateUser;
   
(*--------------------------------------------------------------------------------*)

BEGIN
   _Web := NIL;;
END CController;

(*================================================================================*)

END Controller.
