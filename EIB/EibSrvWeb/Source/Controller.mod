IMPLEMENTATION MODULE Controller;

(*================================================================================*)

FROM Debug IMPORT
   Assertion;
   
IMPORT
   HttpCommon,
   Strings,
   time;

(*--------------------------------------------------------------------------------*)

CONST
   SESSION_LOGGED = L"logged";

   LOGIN_VIEW = L"login.pt.xml";
   STATUS_VIEW = L"status.pt.xml";
   
   LOGIN_MESSAGE = L"message";
   LOGIN_USERNAME = L"username";
   LOGIN_PASSWORD = L"password";
   
   DATETIME_FORMAT = L"d. MMMM H.mm:ss 'GMT'";
   STATUS_CONNECTED = L"connected";
   STATUS_CONNECTIONTIME = L"connectionTime";
   STATUS_UPTIME = L"uptime";
   STATUS_LICENCE = L"licence";
   STATUS_LAST_HOUR = L"ioLastHour";
   STATUS_LAST_DAY = L"ioLastDay";

(*================================================================================*)

CLASS IMPLEMENTATION CController;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Resolve( CONST Fragment : ARRAY OF WCHAR; OUT Resolved : StringsO.IString ) : BOOLEAN;
   BEGIN
      // TODO
      Resolved.FromOA( L"D:\Work\SmartControl\Code\EIB\EibSrv\Install\Web\" );
      Resolved.AppendOA( Fragment );
      RETURN TRUE;
   END Resolve;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE ProcessRequest( Fallback : BOOLEAN; CONST Request : mvc.TPHttpRequest; OUT View : mvc.TPView ) : BOOLEAN; // returning false means 500 response
   VAR
      data : PTR;
      uri : StringsO.CString;
   BEGIN
      IF Fallback THEN
         uri := Request^.ControllerURI;
         View := mvc.fileView( ADR( SELF ), OA( uri.Length-1, uri.rawData ));
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
         Request^.ModelContainer^.AddStringOA( LOGIN_MESSAGE, su ); // empty
         Request^.ModelContainer^.AddStringOA( LOGIN_USERNAME, su ); // empty
         Request^.ModelContainer^.AddStringOA( LOGIN_PASSWORD, sp ); // empty
         View := mvc.pageTemplateView( ADR( SELF ), LOGIN_VIEW );

      // post, try to login
      ELSIF NOT Request^.ModelContainer^.GetStringOA( LOGIN_USERNAME, OUT su ) OR // bad input
            NOT Request^.ModelContainer^.GetStringOA( LOGIN_PASSWORD, OUT sp ) OR // bad input
            NOT ValidateUser( su, sp ) THEN // bad credentials
         Request^.MessageSource^.GetMessageOA( Request^.Language, L"login.badCredentials", OUT su );
         Request^.ModelContainer^.AddStringOA( LOGIN_MESSAGE, su );
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
      dt : time.TDateTime;
      s : ARRAY [0..63] OF WCHAR;
      starttime : time.TJD;
      uptime : time.TJDC;
      t : time.TJD;
   BEGIN
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
      
      uptime := time.GetCurrentJD() - starttime;
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
      Request^.ModelContainer^.AddStringOA( STATUS_LICENCE, cs );
      
      c := _Web^.WrittenByHour + _Web^.ReadByHour;
      cs.FromCARD32( c, 10 );
      Request^.ModelContainer^.AddStringOA( STATUS_LAST_HOUR, cs );

      c := _Web^.WrittenByDay + _Web^.ReadByDay;
      cs.FromCARD32( c, 10 );
      Request^.ModelContainer^.AddStringOA( STATUS_LAST_DAY, cs );
 
      View := mvc.pageTemplateView( ADR( SELF ), STATUS_VIEW );
      RETURN TRUE;
   END ProcessStatus;
   
(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ProcessControl( CONST Request : mvc.TPHttpRequest; OUT View : mvc.TPView ) : BOOLEAN;
   BEGIN
      // TODO
      RETURN FALSE;
   END ProcessControl;
   
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
