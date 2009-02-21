IMPLEMENTATION MODULE Controller;

(*================================================================================*)

FROM Debug IMPORT
   Assertion;
   
IMPORT
   FIO,
   HttpCommon,
   HttpTools,
   lists,
   Log,
   Strings,
   time;

(*--------------------------------------------------------------------------------*)

CONST
   CRLF = 13W + 10W;
   SESSION_LOGGED = L"logged";
   
   RESOLVER_CONTEXT_WEB = 0;
   RESOLVER_CONTEXT_DISK = 1;

   LOGIN_VIEW = L"login.pt.xml";
   STATUS_VIEW = L"status.pt.xml";
   CONTROL_VIEW = L"control.pt.xml";
   DATA_LOG_VIEW = L"datalog.pt.xml";
   SYSTEM_LOG_VIEW = L"syslog.pt.xml";
   IO_VIEW = L"io.pt.xml";
   
   LOGIN_MESSAGE = L"message";
   LOGIN_USERNAME = L"username";
   LOGIN_PASSWORD = L"password";
   
   DATETIME_FORMAT = L"d. MMMM H.mm:ss 'GMT'";
   STATUS_CONNECTED = L"connected";
   STATUS_CONNECTIONTIME = L"connectionTime";
   STATUS_UPTIME = L"uptime";
   STATUS_LICENCE_VALID = L"licenceValid";
   STATUS_LICENCE = L"licence";
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

(*================================================================================*)

CLASS IMPLEMENTATION CController;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE ResolvePath( Context : PTR; CONST Fragment : ARRAY OF WCHAR; OUT Resolved : StringsO.IString ) : BOOLEAN;
   BEGIN
      IF Context = RESOLVER_CONTEXT_DISK THEN
         IF FIO.IsUNCW( Fragment ) OR FIO.IsDriveW( Fragment ) THEN
            Resolved.FromOA( Fragment );
         ELSE
            RETURN FALSE;
         END;
      ELSIF Context = RESOLVER_CONTEXT_WEB THEN
         // TODO
         Resolved.FromOA( L"D:\Work\SmartControl\Code\EIB\EibSrv\Install\Web\" );
         Resolved.AppendOA( Fragment );
      ELSE
         RETURN FALSE;
      END;
      RETURN TRUE;
   END ResolvePath;

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

   PUBLIC VIRTUAL PROCEDURE ProcessRequest( Fallback : BOOLEAN; CONST Request : mvc.TPHttpRequest; OUT View : mvc.TPView ) : BOOLEAN; // returning false means 500 response
   VAR
      data : PTR;
      uri : StringsO.CString;
   BEGIN
      IF Fallback THEN
         uri := Request^.ControllerURI;
         View := mvc.fileView( ADR( SELF ), RESOLVER_CONTEXT_WEB, OA( uri.Length-1, uri.rawData ), FALSE, ADR( SELF ), RESOLVER_CONTEXT_WEB );
         RETURN TRUE;
   
      ELSIF Request^.ControllerURI.EqualsOA( LOGIN_PAGE ) THEN
         RETURN ProcessLogin( Request, OUT View );
      
      ELSIF NOT Request^.Session^.Get( SESSION_LOGGED, OUT data ) OR ( data <> PTR( ADR( SELF ))) THEN
         Request^.Session^.Remove( SESSION_LOGGED );
         View := mvc.redirectView( LOGIN_PAGE );
         RETURN TRUE;
      
      ELSIF Request^.ControllerURI.EqualsOA( STATUS_PAGE ) THEN
         RETURN ProcessStatus( Request, OUT View );

      ELSIF Request^.ControllerURI.EqualsOA( CONTROL_PAGE ) THEN
         RETURN ProcessControl( Request, OUT View );

      ELSIF Request^.ControllerURI.EqualsOA( DATA_LOG_PAGE ) THEN
         RETURN ProcessDataLog( Request, OUT View );

      ELSIF Request^.ControllerURI.EqualsOA( SYSTEM_LOG_PAGE ) THEN
         RETURN ProcessSystemLog( Request, OUT View );

      ELSIF Request^.ControllerURI.EqualsOA( IO_PAGE ) THEN
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

   PRIVATE PROCEDURE ProcessLogin( CONST Request : mvc.TPHttpRequest; OUT View : mvc.TPView ) : BOOLEAN;
   VAR
      su, sp : StringsO.CString;
   BEGIN
      IF Request^.RequestVerb = HttpCommon.verbGET THEN // OK, only render a login page
         Request^.ModelContainer^.AddStringOA( LOGIN_MESSAGE, sp ); // empty
         Request^.ModelContainer^.AddStringOA( LOGIN_USERNAME, sp ); // empty
         Request^.ModelContainer^.AddStringOA( LOGIN_PASSWORD, sp ); // empty
         View := mvc.pageTemplateView( ADR( SELF ), LOGIN_VIEW );

      // post, try to login
      ELSIF NOT Request^.ModelContainer^.GetStringOA( LOGIN_USERNAME, OUT su ) OR // bad input
            NOT Request^.ModelContainer^.GetStringOA( LOGIN_PASSWORD, OUT sp ) OR // bad input
            NOT ValidateUser( su, sp ) THEN // bad credentials
         Request^.MessageSource^.GetMessageOA( Request^.Language, L"login.badCredentials", OUT su );
         Request^.ModelContainer^.AddStringOA( LOGIN_MESSAGE, su );

         sp.Clear();
         Request^.ModelContainer^.AddStringOA( LOGIN_MESSAGE, sp ); // empty
         Request^.ModelContainer^.AddStringOA( LOGIN_USERNAME, sp ); // empty
         Request^.ModelContainer^.AddStringOA( LOGIN_PASSWORD, sp ); // empty
         View := mvc.pageTemplateView( ADR( SELF ), LOGIN_VIEW );
         
      ELSE // OK, set up session, redirect to status page
         Request^.Session^.Remove( SESSION_LOGGED );
         Request^.Session^.Add( SESSION_LOGGED, ADR( SELF ));
         View := mvc.redirectView( STATUS_PAGE );

      END;

      RETURN TRUE;
   END ProcessLogin;
   
(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ProcessStatus( CONST Request : mvc.TPHttpRequest; OUT View : mvc.TPView ) : BOOLEAN;
   VAR
      b : BOOLEAN;
      c : CARDINAL;
      cs : StringsO.CString;
      currentDT : time.TDateTime;
      currentTime : time.TJD;
      dt : time.TDateTime;
      s : ARRAY [0..63] OF WCHAR;
      starttime : time.TJD;
      uptime : time.TJDC;
      t : time.TJD;
   BEGIN
      // check actions to do
      IF Request^.ModelContainer^.GetBooleanOA( STATUS_CONNECT, OUT b ) AND b THEN
         _Web^.ConnectEIB();
         Request^.ModelContainer^.AddBooleanOA( STATUS_CONNECT, FALSE );
         View := mvc.redirectView( STATUS_PAGE );
         RETURN TRUE;
      ELSIF Request^.ModelContainer^.GetBooleanOA( STATUS_DISCONNECT, OUT b ) AND b THEN
         _Web^.DisconnectEIB();
         Request^.ModelContainer^.AddBooleanOA( STATUS_DISCONNECT, FALSE );
         View := mvc.redirectView( STATUS_PAGE );
         RETURN TRUE;
      END;
   
      b := _Web^.Connected;
      Request^.ModelContainer^.AddBooleanOA( STATUS_CONNECTED, b );

      starttime := _Web^.StartedTime;
      IF b THEN
         t := _Web^.ConnectedTime;
      ELSE
         t := _Web^.DisconnectedTime;
      END;
      IF t = 0 THEN
         t := starttime;
      END;
      time.JDToZonalDateTime( t, dt, 0, 0 );
      IF time.DateTimeToStringLang( Request^.Language, dt, DATETIME_FORMAT, TRUE, TRUE, s ) THEN
         cs.FromOA( s );
      ELSE
         cs.FromOA( L"N/A" );
      END;
      Request^.ModelContainer^.AddStringOA( STATUS_CONNECTIONTIME, cs );
      Request^.ModelContainer^.AddBooleanOA( STATUS_CONNECT, FALSE );
      Request^.ModelContainer^.AddBooleanOA( STATUS_DISCONNECT, FALSE );
      
      time.GetCurrentUTCDateTime( currentDT );
      currentTime := time.DateTimeToJD( currentDT );
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
      Request^.ModelContainer^.AddStringOA( STATUS_UPTIME, cs );

      dt := _Web^.LicenceExpires;
      IF dt.Day = 0 THEN
         Request^.MessageSource^.GetMessageOA( Request^.Language, L"status.licencePermanent", OUT cs );
      ELSE
         time.DateTimeToStringLang( Request^.Language, dt, DATETIME_FORMAT, TRUE, TRUE, s );
         Request^.MessageSource^.GetMessageOA( Request^.Language, L"status.licenceValidUntil", OUT cs );
         cs.AppendOA( s );
      END;
      Request^.ModelContainer^.AddBooleanOA( STATUS_LICENCE_VALID, ( dt.Day = 0 ) OR time.Greater( currentDT, dt ));
      Request^.ModelContainer^.AddStringOA( STATUS_LICENCE, cs );
      
      c := _Web^.WrittenByHour + _Web^.ReadByHour;
      cs.FromCARD32( c, 10 );
      Request^.ModelContainer^.AddStringOA( STATUS_LAST_HOUR, cs );

      c := _Web^.WrittenByDay + _Web^.ReadByDay;
      cs.FromCARD32( c, 10 );
      Request^.ModelContainer^.AddStringOA( STATUS_LAST_DAY, cs );
 
      Request^.ModelContainer^.AddStringOA( STATUS_CONFIGURATION, _Web^.Configuration^ );
 
      View := mvc.pageTemplateView( ADR( SELF ), STATUS_VIEW );
      RETURN TRUE;
   END ProcessStatus;
   
(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ProcessControl( CONST Request : mvc.TPHttpRequest; OUT View : mvc.TPView ) : BOOLEAN;
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
      IF Request^.RequestVerb = HttpCommon.verbPOST THEN // OK, process form output
         IF Request^.ModelContainer^.GetStringOA( CONTROL_CONFIG_FILE, OUT cs ) THEN
            _Web^.ConfigureEIB( cs );
         END;
         View := mvc.redirectView( CONTROL_PAGE );
         RETURN TRUE;
      ELSIF Request^.ModelContainer^.GetStringOA( CONTROL_START, OUT cs ) AND cs.ToCARD32( 10, OUT i ) AND ( i <> -1 ) THEN
         cs.FromOA( L"-1" );
         Request^.ModelContainer^.AddStringOA( CONTROL_START, cs );
         IF i > MAX( INTEGER ) THEN
            // do nothing
         ELSIF i < _Web^.OperatedDeviceCount THEN
            _Web^.OperatedDevice( i )^.Start();
         END;
         View := mvc.redirectView( CONTROL_PAGE );
         RETURN TRUE;
      ELSIF Request^.ModelContainer^.GetStringOA( CONTROL_STOP, OUT cs ) AND cs.ToCARD32( 10, OUT i ) AND ( i <> -1 ) THEN
         cs.FromOA( L"-1" );
         Request^.ModelContainer^.AddStringOA( CONTROL_STOP, cs );
         IF i > MAX( INTEGER ) THEN
            // do nothing
         ELSIF i < _Web^.OperatedDeviceCount THEN
            _Web^.OperatedDevice( i )^.Stop();
         END;
         View := mvc.redirectView( CONTROL_PAGE );
         RETURN TRUE;
      ELSIF Request^.ModelContainer^.GetStringOA( CONTROL_DOWNLOAD, OUT cs ) AND cs.ToCARD32( 10, OUT i ) AND ( i <> -1 ) THEN
         cs.FromOA( L"-1" );
         Request^.ModelContainer^.AddStringOA( CONTROL_DOWNLOAD, cs );
         View := mvc.fileView( ADR( SELF ), RESOLVER_CONTEXT_DISK, OA( _Web^.Configuration^.Length-1, _Web^.Configuration^.rawData ), TRUE, ADR( SELF ), RESOLVER_CONTEXT_WEB );
         RETURN TRUE;
      END;

      Request^.ModelContainer^.AddListOA( CONTROL_DEVICES_NAME, OUT listDevices ); listDevices^.Clear();
      Request^.ModelContainer^.AddListOA( CONTROL_DEVICES_RUN, OUT listRunning ); listRunning^.Clear();
      Request^.ModelContainer^.AddListOA( CONTROL_DEVICES_IDX, OUT listIndexes ); listIndexes^.Clear();

      count := _Web^.OperatedDeviceCount;
      IF count > 0 THEN
         FOR i := 0 TO count-1 DO
            Request^.MessageSource^.GetMessageOA( Request^.Language, OAsz( _Web^.OperatedDeviceName( i )), OUT cs );
            listDevices^.Add( cs, cs );

            IF _Web^.OperatedDevice( i )^.Running THEN
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
      Request^.ModelContainer^.AddStringOA( CONTROL_START, cs );
      Request^.ModelContainer^.AddStringOA( CONTROL_STOP, cs );
      Request^.ModelContainer^.AddStringOA( CONTROL_DOWNLOAD, cs );

      Request^.ModelContainer^.AddStringOA( CONTROL_CONFIG_FILE, _Web^.Configuration^ );
      
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
      Request^.ModelContainer^.AddStringOA( CONTROL_CONFIG_LOG, cs );
            
      View := mvc.pageTemplateView( ADR( SELF ), CONTROL_VIEW );
      RETURN TRUE;
   END ProcessControl;
   
(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ProcessDataLog( CONST Request : mvc.TPHttpRequest; OUT View : mvc.TPView ) : BOOLEAN;
   VAR
      count : CARDINAL;
      cs : StringsO.CString;
      i : CARDINAL;
      log : ARRAY [0..511] OF WCHAR;
   BEGIN
      count := _Web^.DataLogger^.BufferCount;
      cs.Clear();
      IF count > 0 THEN
         FOR i := 0 TO count-1 DO
            IF i > 0 THEN
               cs.AppendOA( CRLF );
            END;
            _Web^.DataLogger^.BufferGetItem( i, OUT log );
            cs.AppendOA( log );
         END;
      END;
      Request^.ModelContainer^.AddStringOA( LOG_LOG, cs );

      View := mvc.pageTemplateView( ADR( SELF ), DATA_LOG_VIEW );
      RETURN TRUE;
   END ProcessDataLog;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ProcessSystemLog( CONST Request : mvc.TPHttpRequest; OUT View : mvc.TPView ) : BOOLEAN;
   VAR
      count : CARDINAL;
      cs : StringsO.CString;
      i : CARDINAL;
      log : ARRAY [0..511] OF WCHAR;
   BEGIN
      count := Log.logger()^.BufferCount;
      cs.Clear();
      IF count > 0 THEN
         FOR i := 0 TO count-1 DO
            IF i > 0 THEN
               cs.AppendOA( CRLF );
            END;
            Log.logger()^.BufferGetItem( i, OUT log );
            cs.AppendOA( log );
         END;
      END;
      Request^.ModelContainer^.AddStringOA( LOG_LOG, cs );

      View := mvc.pageTemplateView( ADR( SELF ), SYSTEM_LOG_VIEW );
      RETURN TRUE;
   END ProcessSystemLog;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ProcessIO( CONST Request : mvc.TPHttpRequest; OUT View : mvc.TPView ) : BOOLEAN;
   BEGIN
      // TODO
      RETURN FALSE;
   END ProcessIO;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ValidateUser( CONST UserName, Password : StringsO.CString ) : BOOLEAN;
   BEGIN
      // TODO
      RETURN UserName.EqualsOA( L"admin" ) AND Password.EqualsOA( L"admin" );
   END ValidateUser;
   
(*--------------------------------------------------------------------------------*)

BEGIN
   _Web := NIL;;
END CController;

(*================================================================================*)

END Controller.
