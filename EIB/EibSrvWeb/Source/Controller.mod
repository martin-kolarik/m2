IMPLEMENTATION MODULE Controller;

(*================================================================================*)

FROM Debug IMPORT
   Assertion;
   
IMPORT
   datetime,
   EibSrvWeb,
   FIO,
   FIOO,
   HttpCommon,
   HttpTools,
   Languages,
   lec,
   lists,
   Log,
   MIME,
   Strings;

(*--------------------------------------------------------------------------------*)

CONST
   CRLF = 13W + 10W;
   FALSE_S = L"false";
   TRUE_S = L"true";
   SESSION_LOGGED = L"logged";
   SESSION_ROLE = L"role";
   ROLE_NAME = L"roleName";
   ROLE_ADMIN = L"isAdmin";
   ROLE_IS_KEYED = L"roleIsKeyed";
   USER_LOGGED = L"isLogged";
   VERSION = L"version";
   MESSAGE = L"message";
   LOGIN_REDIRECTED = L"redirected";
   USER_LOGIN_SOURCE_PAGE = L"sourcePage";
   LANGUAGE = L"language";
   INVALID_LANGUAGE = -1;
   
   RESOLVER_CONTEXT_WEB = 0;
   RESOLVER_CONTEXT_DISK = 1;

   LOGIN_VIEW = L"login.pt.xml";
   STATUS_VIEW = L"status.pt.xml";
   CONTROL_VIEW = L"control.pt.xml";
   DATA_LOG_VIEW = L"datalog.pt.xml";
   SYSTEM_LOG_VIEW = L"syslog.pt.xml";
   IO_VIEW = L"io.pt.xml";
   USERS_VIEW = L"users.pt.xml";
   ROLE_EDIT_VIEW = L"roleEdit.pt.xml";
   USER_EDIT_VIEW = L"userEdit.pt.xml";
   USER_LOGIN_VIEW = L"userLogin.pt.xml";
   INDEX_VIEW = L"index.pt.xml";
   
   LOGIN_USERNAME = L"username";
   LOGIN_PASSWORD = L"password";
   LOGOUT_NEXT_PAGE = L"nextpage";
   ERROR_LOGIN_NOT_FOUND_OR_EXPIRED = L"login.invalidLoginOrSessionExpired";
   ERROR_USER_LOGIN_NOT_FOUND_OR_EXPIRED = L"userLogin.invalidLoginOrSessionExpired";
   ERROR_LOGIN_BAD_CREDENTIALS = L"login.badCredentials";
   ERROR_USER_LOGIN_BAD_CREDENTIALS = L"userLogin.badCredentials";
   
   DATETIME_FORMAT_CS = L"d. MMMM H.mm:ss";
   DATETIME_FORMAT_EN = L"MMMM d, H:mm:ss";
   STATUS_CONNECTED = L"connected";
   STATUS_CACHE_ONLY = L"cacheOnly";
   STATUS_CONNECTIONTIME = L"connectionTime";
   STATUS_CONNECTION = L"connection";
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
   STATUS_PROJECT = L"project";
   STATUS_TEXT_VALID_UNTIL = L"status.licenceValidUntil";
   STATUS_TEXT_PERMANENT = L"status.licencePermanent";   

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
   
   USERS_ACTION = L"action";
      ACTION_DELETE = L"delete";
      ACTION_EDIT = L"edit";
   USERS_ID = L"id";
   USERS_ROLES = L"roles";
   USERS_ROLE_IDS = L"roleIds";
   USERS_USERS = L"users";
   USERS_USER_IDS = L"userIds";
   USERS_ERROR = L"error";
   USERS_ERROR_TEXT = L"errorText";
   USERS_ERROR_TEXT_BADEDITDATA = L"users.badUsersEditData";
   
   USER_EDIT_NAME = L"name";
   USER_EDIT_ROLE = L"role";
   USER_EDIT_PASSWORD1 = L"password1";
   USER_EDIT_PASSWORD2 = L"password2";
   USER_EDIT_ERROR_TEXT_EMPTYNAME = L"userEdit.nameIsEmpty";
   USER_EDIT_ERROR_TEXT_PASSWORDEMPTY = L"userEdit.passwordEmpty";
   USER_EDIT_ERROR_TEXT_PASSWORDSDONOTMATCH = L"userEdit.passwordDoNotMatch";
   USER_EDIT_ERROR_TEXT_EMPTYROLE = L"userEdit.roleIsEmpty";
   USER_EDIT_ERROR_TEXT_UPDATEFAILED = L"userEdit.updateFailed";
   USER_EDIT_ERROR_TEXT_DELETEFAILED = L"userEdit.deleteFailed";
   USER_EDIT_ERROR_NAME_EXISTS = L"userEdit.nameCollides";
   
   ROLE_EDIT_NAME = L"name";
   ROLE_EDIT_KEYED = L"keyed";
   ROLE_EDIT_ERROR_TEXT_EMPTYNAME = L"roleEdit.nameIsEmpty";
   ROLE_EDIT_ERROR_TEXT_UPDATEFAILED = L"roleEdit.updateFailed";
   ROLE_EDIT_ERROR_TEXT_DELETEFAILED = L"roleEdit.deleteFailed";
   ROLE_EDIT_ERROR_NAME_EXISTS = L"roleEdit.nameCollides";

   DYNAMIC_SUFFIX = L".pt.xml";
   FN_SET = L"set";
   FN_GET = L"get";
   FN_GETWIX = L"getwix";
   FN_SETV = L"setv"; // set without redirect
   FN_EQUAL = L"equal";
   FN_NOTEQUAL = L"notEqual";
   FN_LESS = L"less";
   FN_LESSEQUAL = L"lessEqual";
   FN_GREATER = L"greater";
   FN_GREATEREQUAL = L"greaterEqual";

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

   PUBLIC VIRTUAL PROCEDURE Call( CONST Request : mvc.IMvcRequest; CONST FunctionName : StringsO.IString; REF Parameters : lists.CStringStringList; RetVal : StringsO.TPString ) : mvc.TCallResult;
   VAR
      b : BOOLEAN;
      name, s, value1, value2 : StringsO.CString;
      real1, real2 : LONGREAL;
   BEGIN
      IF FunctionName.EqualsOA( FN_SET ) OR
         FunctionName.EqualsOA( FN_SETV ) THEN
         IF Parameters.Count < 2 THEN
            RETURN mvc.crMissingParameter;
         END;
         Parameters.ElementAt( 0, OUT s, OUT name );
         Parameters.ElementAt( 1, OUT s, OUT value1 );
         IF _Web^.SetValue( Request.RequestSource, name, value1 ) THEN
            RETURN mvc.crSuccess;
         ELSE
            RETURN mvc.crCallFailed;
         END;

      ELSIF FunctionName.EqualsOA( FN_GET ) THEN
         IF Parameters.Count < 1 THEN
            RETURN mvc.crMissingParameter;
         END;
         Parameters.ElementAt( 0, OUT s, OUT name );
         IF NOT _Web^.GetValue( name, OUT value1 ) THEN
            RETURN mvc.crCallFailed;
         ELSIF RetVal <> NIL THEN
            RetVal^.Assign( value1 );
         END;
         RETURN mvc.crSuccess;
         
      ELSIF FunctionName.EqualsOA( FN_GETWIX ) THEN
         IF Parameters.Count < 1 THEN
            RETURN mvc.crMissingParameter;
         END;
         Parameters.ElementAt( 0, OUT s, OUT name );
         IF NOT _Web^.GetWixValue( name, OUT value1 ) THEN
            RETURN mvc.crCallFailed;
         ELSIF RetVal <> NIL THEN
            RetVal^.Assign( value1 );
         END;
         RETURN mvc.crSuccess;
         
      ELSIF FunctionName.EqualsOA( FN_EQUAL ) THEN
         IF Parameters.Count < 2 THEN
            RETURN mvc.crMissingParameter;
         ELSIF RetVal <> NIL THEN
            Parameters.ElementAt( 0, OUT s, OUT value1 );
            Parameters.ElementAt( 1, OUT s, OUT value2 );
            IF value1.Equals( value2 ) THEN
               RetVal^.FromOA( TRUE_S );
            ELSE
               RetVal^.FromOA( FALSE_S );
            END;
         END;
         RETURN mvc.crSuccess;
         
      ELSIF FunctionName.EqualsOA( FN_NOTEQUAL ) THEN
         IF Parameters.Count < 2 THEN
            RETURN mvc.crMissingParameter;
         ELSIF RetVal <> NIL THEN
            Parameters.ElementAt( 0, OUT s, OUT value1 );
            Parameters.ElementAt( 1, OUT s, OUT value2 );
            IF value1.Equals( value2 ) THEN
               RetVal^.FromOA( FALSE_S );
            ELSE
               RetVal^.FromOA( TRUE_S );
            END;
         END;
         RETURN mvc.crSuccess;
         
      ELSIF FunctionName.EqualsOA( FN_LESS ) THEN
         IF Parameters.Count < 2 THEN
            RETURN mvc.crMissingParameter;
         ELSIF RetVal <> NIL THEN
            Parameters.ElementAt( 0, OUT s, OUT value1 );
            Parameters.ElementAt( 1, OUT s, OUT value2 );
            IF value1.ToLONGREAL( OUT real1 ) AND value2.ToLONGREAL( OUT real2 ) THEN
               b := real1 < real2;
            ELSE
               b := value1.CompareLanguage( Language( Request ), TRUE, value2 ) = -1;
            END;
            IF b THEN
               RetVal^.FromOA( TRUE_S );
            ELSE
               RetVal^.FromOA( FALSE_S );
            END;
         END;
         RETURN mvc.crSuccess;
         
      ELSIF FunctionName.EqualsOA( FN_LESSEQUAL ) THEN
         IF Parameters.Count < 2 THEN
            RETURN mvc.crMissingParameter;
         ELSIF RetVal <> NIL THEN
            Parameters.ElementAt( 0, OUT s, OUT value1 );
            Parameters.ElementAt( 1, OUT s, OUT value2 );
            IF value1.ToLONGREAL( OUT real1 ) AND value2.ToLONGREAL( OUT real2 ) THEN
               b := real1 <= real2;
            ELSE
               b := value1.CompareLanguage( Language( Request ), TRUE, value2 ) <> 1;
            END;
            IF b THEN
               RetVal^.FromOA( TRUE_S );
            ELSE
               RetVal^.FromOA( FALSE_S );
            END;
         END;
         RETURN mvc.crSuccess;
         
      ELSIF FunctionName.EqualsOA( FN_GREATER ) THEN
         IF Parameters.Count < 2 THEN
            RETURN mvc.crMissingParameter;
         ELSIF RetVal <> NIL THEN
            Parameters.ElementAt( 0, OUT s, OUT value1 );
            Parameters.ElementAt( 1, OUT s, OUT value2 );
            IF value1.ToLONGREAL( OUT real1 ) AND value2.ToLONGREAL( OUT real2 ) THEN
               b := real1 > real2;
            ELSE
               b := value1.CompareLanguage( Language( Request ), TRUE, value2 ) = 1;
            END;
            IF b THEN
               RetVal^.FromOA( TRUE_S );
            ELSE
               RetVal^.FromOA( FALSE_S );
            END;
         END;
         RETURN mvc.crSuccess;
         
      ELSIF FunctionName.EqualsOA( FN_GREATEREQUAL ) THEN
         IF Parameters.Count < 2 THEN
            RETURN mvc.crMissingParameter;
         ELSIF RetVal <> NIL THEN
            Parameters.ElementAt( 0, OUT s, OUT value1 );
            Parameters.ElementAt( 1, OUT s, OUT value2 );
            IF value1.ToLONGREAL( OUT real1 ) AND value2.ToLONGREAL( OUT real2 ) THEN
               b := real1 >= real2;
            ELSE
               b := value1.CompareLanguage( Language( Request ), TRUE, value2 ) <> -1;
            END;
            IF b THEN
               RetVal^.FromOA( TRUE_S );
            ELSE
               RetVal^.FromOA( FALSE_S );
            END;
         END;
         RETURN mvc.crSuccess;
         
      ELSE
         RETURN mvc.crUnknownFunction;
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
         MIME.FormatContentOA( MIME.contentTextPlain, L"", L"utf-8", FALSE, OUT ContentHeader );
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END ResolveMIME;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE InitializeModelContainer( REF Container : mvc.IContainer );
   VAR
      version : StringsO.CString;
   BEGIN
      Container.AddFunctionHandlerOA( FN_EQUAL, ADR( SELF ));
      Container.AddFunctionHandlerOA( FN_NOTEQUAL, ADR( SELF ));
      Container.AddFunctionHandlerOA( FN_LESS, ADR( SELF ));
      Container.AddFunctionHandlerOA( FN_LESSEQUAL, ADR( SELF ));
      Container.AddFunctionHandlerOA( FN_GREATER, ADR( SELF ));
      Container.AddFunctionHandlerOA( FN_GREATEREQUAL, ADR( SELF ));
      Container.AddFunctionHandlerOA( FN_SET, ADR( SELF ));
      Container.AddFunctionHandlerOA( FN_GET, ADR( SELF ));
      Container.AddFunctionHandlerOA( FN_GETWIX, ADR( SELF ));
      Container.AddFunctionHandlerOA( FN_SETV, ADR( SELF ));

      version.FromOA( ProductVersion );
      Container.AddStringOA( VERSION, version );
   END InitializeModelContainer;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CleanupModelContainer( REF Container : mvc.IContainer );
   BEGIN
   END CleanupModelContainer;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE ProcessRequest( Fallback : BOOLEAN; REF Request : mvc.IMvcRequest; OUT View : mvc.TPView ) : BOOLEAN; // returning false means 500 response
   VAR
      authMethodInfo : StringsO.CString;
      authorized : BOOLEAN := FALSE;
      authTokens : lists.CStringStringList;
      data : PTR;
      empty : StringsO.CString;
      functionsCalled : CARDINAL := 0;
      role : EibSrvWeb.TRole;
      roleName : StringsO.CString;
      s : StringsO.CString;
      setsCalled : CARDINAL := 0;
      singleSetCalled : BOOLEAN := FALSE;
      uri : StringsO.CString;
      uriParameters : lists.TPStringStringList := Request.URIParameters;
      value : StringsO.CString;
   BEGIN
      IF Request.Session^.Get( SESSION_ROLE, OUT data ) THEN
         role := EibSrvWeb.TRole( LOPTRLONGWORD( data ));
      ELSE
         InvalidateUser( REF Request );
         role := EibSrvWeb.roleGuest;
      END;
      
      // process parameters not known to views' models
      IF uriParameters^.GetOA( LANGUAGE, OUT s ) THEN // override language
         SetOverriddenLanguage( Request, s );

         uri := Request.ControllerURI;
         View := mvc.redirectView( OA( uri.Length-1, uri.Data )); // language switch cannot carry other parameters
         RETURN TRUE;

      // process other unknown parameters to detect functions
      ELSIF uriParameters^.Count = 0 THEN
         // fall down to normal controller processing

      // process other unknown parameters to detect functions
      ELSE
         uriParameters^.Reset();
         WHILE uriParameters^.MoveNext() DO
            IF Request.ModelContainer^.IsFunctionCall( uriParameters^.Current^ ) THEN
               INC( functionsCalled );
               IF uriParameters^.Current^.StartsWithOA( FN_SET + L"(" ) THEN
                  INC( setsCalled );
               END;
               IF Request.ModelContainer^.GetModelValue( Request, Request.MessageSource, Language( Request ), uriParameters^.Current^, OUT value ) THEN
                  s.Append( value );
               ELSE
                  s.AppendOA( L"##error: function call failed" );
               END;
               s.AppendOA( CRLF );
            END;
         END; // WHILE URIParameter

         singleSetCalled := ( functionsCalled = 1 ) AND ( setsCalled = 1 );
         IF ( functionsCalled = 0 ) OR singleSetCalled THEN
            // fall down, single set falls to the same page, no function means no action
         ELSE // do not render "normal" view output, but textual function output
            View := mvc.rawTextView( OA( s.Length-1, s.Data ), L"", empty, FALSE ); // language switch cannot carry other parameters
            RETURN TRUE;
         END;
      // end of parameters processing
      END;
      
      IF Fallback THEN
         uri := Request.ControllerURI;
         IF NOT uri.EndsWithOA( DYNAMIC_SUFFIX ) THEN
            View := mvc.fileView( ADR( SELF ), RESOLVER_CONTEXT_WEB, OA( uri.Length-1, uri.Data ), FALSE, ADR( SELF ), RESOLVER_CONTEXT_WEB );

         ELSIF singleSetCalled THEN // some set call was performed, redirect to self
            View := mvc.redirectView( OA( uri.Length-1, uri.Data ));
         
         ELSE // no call during the request
            View := GetPageTemplateView( Request, OA( uri.Length-1, uri.Data ));

            // handle authentication
            IF NOT View^.GetAuthenticationInfo( Request, OUT authMethodInfo, OUT authTokens ) THEN // some error occurred
               RETURN FALSE;
            END;
            // authMethodInfo is ignored now, method is always native

            IF authTokens.Empty OR ( role = EibSrvWeb.roleSystemAdministrator ) THEN // if page does not want to authorize or if admin is logged
               authorized := TRUE;
            ELSIF Request.ModelContainer^.GetStringOA( ROLE_NAME, OUT roleName ) THEN // check role, it takes sense only if is somebody is logged
               authTokens.Reset();
               WHILE authTokens.MoveNext() DO
                  IF authTokens.CurrentData^.Equals( roleName ) THEN // authorized
                     authorized := TRUE;
                     EXIT;
                  END;
               END; // WHILE
            END;

            IF authorized THEN
               Request.ModelContainer^.AddBooleanOA( USER_LOGGED, Request.Session^.Get( SESSION_LOGGED, OUT data ) AND ( data = PTR( ADR( SELF ))) );
            ELSE // redirect to login page
               IF Request.ModelContainer^.GetStringOA( USER_LOGIN_SOURCE_PAGE, OUT s ) THEN // repeated attempt to authorize, leave MESSAGE intact
                  Request.ModelContainer^.AddBooleanOA( LOGIN_REDIRECTED, TRUE );
               END;
               Request.ModelContainer^.AddStringOA( USER_LOGIN_SOURCE_PAGE, uri );
               View^.Release();
               View := mvc.redirectView( USER_LOGIN_PAGE );
            END;

         END;
         RETURN TRUE;
   
      ELSIF Request.ControllerURI.EqualsOA( INDEX_PAGE ) THEN
         View := mvc.redirectView( INDEX_VIEW );
         RETURN TRUE;
      
      ELSIF Request.ControllerURI.EqualsOA( LOGIN_PAGE ) THEN
         RETURN ProcessLogin( REF Request, OUT View );
      
      ELSIF Request.ControllerURI.EqualsOA( LOGOUT_PAGE ) THEN
         InvalidateUser( REF Request );
         IF uriParameters^.GetOA( LOGOUT_NEXT_PAGE, OUT s ) THEN
            View := mvc.redirectView( OA( s.Length-1, s.Data ));
         ELSE
            View := mvc.redirectView( INDEX_PAGE );
         END;
         RETURN TRUE;
      
      // context directly accessed
      ELSIF Request.ControllerURI.Empty THEN
         View := mvc.redirectView( INDEX_VIEW );
         RETURN TRUE;

      // user login must be processed before system login redirect         
      ELSIF Request.ControllerURI.EqualsOA( USER_LOGIN_PAGE ) THEN
         IF Request.ModelContainer^.GetStringOA( USER_LOGIN_SOURCE_PAGE, OUT s ) THEN // OK
            RETURN ProcessUserLogin( REF Request, OUT View );
         ELSE // nowhere to user-login, redirect to login
            Request.ModelContainer^.AddBooleanOA( LOGIN_REDIRECTED, TRUE );
            Request.MessageSource^.GetMessageOA( Language( Request ), ERROR_USER_LOGIN_NOT_FOUND_OR_EXPIRED, OUT s );
            Request.ModelContainer^.AddStringOA( MESSAGE, s );

            View := mvc.redirectView( INDEX_VIEW );
            RETURN TRUE;
         END;

      ELSIF NOT Request.Session^.Get( SESSION_LOGGED, OUT data ) OR ( data <> PTR( ADR( SELF ))) THEN
         InvalidateUser( REF Request );

         Request.ModelContainer^.AddBooleanOA( LOGIN_REDIRECTED, TRUE );
         Request.MessageSource^.GetMessageOA( Language( Request ), ERROR_LOGIN_NOT_FOUND_OR_EXPIRED, OUT s );
         Request.ModelContainer^.AddStringOA( MESSAGE, s );

         View := mvc.redirectView( LOGIN_PAGE );
         RETURN TRUE;
   
      // all next pages require system role, either sysadmin or sysuser
      ELSIF ( role <> EibSrvWeb.roleSystemUser ) AND ( role <> EibSrvWeb.roleSystemAdministrator ) THEN
         View := mvc.httpStatusCodeCustomView( ADR( SELF ), HttpCommon.httpres_Unauthorized );
         RETURN TRUE;
      
      ELSIF Request.ControllerURI.EqualsOA( STATUS_PAGE ) THEN
         Request.ModelContainer^.AddBooleanOA( ROLE_ADMIN, role = EibSrvWeb.roleSystemAdministrator );
         RETURN ProcessStatus( Request, OUT View );

      ELSIF Request.ControllerURI.EqualsOA( CONTROL_PAGE ) THEN
         IF role = EibSrvWeb.roleSystemAdministrator THEN
            Request.ModelContainer^.AddBooleanOA( ROLE_ADMIN, TRUE );
            RETURN ProcessControl( Request, OUT View );
         ELSE
            View := mvc.httpStatusCodeCustomView( ADR( SELF ), HttpCommon.httpres_Unauthorized );
            RETURN TRUE;
         END;

      ELSIF Request.ControllerURI.EqualsOA( SYSTEM_LOG_PAGE ) THEN
         IF role = EibSrvWeb.roleSystemAdministrator THEN
            Request.ModelContainer^.AddBooleanOA( ROLE_ADMIN, TRUE );
            RETURN ProcessSystemLog( Request, OUT View );
         ELSE
            View := mvc.httpStatusCodeCustomView( ADR( SELF ), HttpCommon.httpres_Unauthorized );
            RETURN TRUE;
         END;

      ELSIF Request.ControllerURI.EqualsOA( DATA_LOG_PAGE ) THEN
         Request.ModelContainer^.AddBooleanOA( ROLE_ADMIN, role = EibSrvWeb.roleSystemAdministrator );
         RETURN ProcessDataLog( Request, OUT View );

      ELSIF Request.ControllerURI.EqualsOA( IO_PAGE ) THEN
         Request.ModelContainer^.AddBooleanOA( ROLE_ADMIN, role = EibSrvWeb.roleSystemAdministrator );
         RETURN ProcessIO( Request, OUT View );

      ELSIF Request.ControllerURI.EqualsOA( USERS_PAGE ) THEN
         IF role = EibSrvWeb.roleSystemAdministrator THEN
            Request.ModelContainer^.AddBooleanOA( ROLE_ADMIN, TRUE );
            RETURN ProcessUsers( Request, OUT View );
         ELSE
            View := mvc.httpStatusCodeCustomView( ADR( SELF ), HttpCommon.httpres_Unauthorized );
            RETURN TRUE;
         END;

      ELSIF Request.ControllerURI.EqualsOA( ROLE_EDIT_PAGE ) THEN
         IF role = EibSrvWeb.roleSystemAdministrator THEN
            Request.ModelContainer^.AddBooleanOA( ROLE_ADMIN, TRUE );
            RETURN ProcessRoleEdit( Request, OUT View );
         ELSE
            View := mvc.httpStatusCodeCustomView( ADR( SELF ), HttpCommon.httpres_Unauthorized );
            RETURN TRUE;
         END;

      ELSIF Request.ControllerURI.EqualsOA( USER_EDIT_PAGE ) THEN
         IF role = EibSrvWeb.roleSystemAdministrator THEN
            Request.ModelContainer^.AddBooleanOA( ROLE_ADMIN, TRUE );
            RETURN ProcessUserEdit( Request, OUT View );
         ELSE
            View := mvc.httpStatusCodeCustomView( ADR( SELF ), HttpCommon.httpres_Unauthorized );
            RETURN TRUE;
         END;

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

   PRIVATE PROCEDURE ProcessLogin( REF Request : mvc.IMvcRequest; OUT View : mvc.TPView ) : BOOLEAN;
   VAR
      redirected : BOOLEAN;
      su, sp : StringsO.CString;
   BEGIN
      IF Request.RequestVerb = HttpCommon.verbGET THEN // OK, only render a login page
         // message is cleared in all GETs, but in GET coming from redirect
         IF Request.ModelContainer^.GetBooleanOA( LOGIN_REDIRECTED, OUT redirected ) AND redirected THEN
            Request.ModelContainer^.RemoveOA( LOGIN_REDIRECTED );
         ELSE
            Request.ModelContainer^.AddStringOA( MESSAGE, sp ); // empty
         END;
         Request.ModelContainer^.AddStringOA( LOGIN_USERNAME, sp ); // empty
         Request.ModelContainer^.AddStringOA( LOGIN_PASSWORD, sp ); // empty
         View := GetPageTemplateView( Request, LOGIN_VIEW );

      // post, try to login
      ELSIF NOT Request.ModelContainer^.GetStringOA( LOGIN_USERNAME, OUT su ) OR // bad input
            NOT Request.ModelContainer^.GetStringOA( LOGIN_PASSWORD, OUT sp ) OR // bad input
            NOT ValidateUser( Request, su, sp ) THEN // bad credentials
         InvalidateUser( REF Request );

         Request.MessageSource^.GetMessageOA( Language( Request ), ERROR_LOGIN_BAD_CREDENTIALS, OUT su );
         Request.ModelContainer^.AddStringOA( MESSAGE, su );

         sp.Clear();
         Request.ModelContainer^.AddStringOA( LOGIN_USERNAME, sp ); // empty
         Request.ModelContainer^.AddStringOA( LOGIN_PASSWORD, sp ); // empty
         View := GetPageTemplateView( Request, LOGIN_VIEW );
         
      ELSE // OK, set up session, redirect to status page
         Request.Session^.Remove( SESSION_LOGGED );
         Request.Session^.Add( SESSION_LOGGED, ADR( SELF ));
         View := mvc.redirectView( STATUS_PAGE );

      END;

      RETURN TRUE;
   END ProcessLogin;
   
(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ProcessStatus( CONST Request : mvc.IMvcRequest; OUT View : mvc.TPView ) : BOOLEAN;
   VAR
      b : BOOLEAN;
      c : CARDINAL;
      cs : StringsO.CString;
      currentDT : datetime.DateTime;
      currentTime : datetime.TJD;
      dt : datetime.DateTime;
      language : Languages.TLanguage;
      LangName : ARRAY[0..15] OF WCHAR;
      lt : lec.TLicenceType;
      s : ARRAY [0..63] OF WCHAR;
      starttime : datetime.TJD;
      uptime : datetime.TJDC;
      uriParameters : lists.TPStringStringList := Request.URIParameters;
   BEGIN
      // check actions to do
      IF uriParameters^.GetOA( STATUS_CONNECT, OUT cs ) AND mvc.uriParameterValueToBoolean( cs ) THEN
         _Web^.ConnectEIB();
         View := mvc.redirectView( STATUS_PAGE );
         RETURN TRUE;
      ELSIF uriParameters^.GetOA( STATUS_DISCONNECT, OUT cs ) AND mvc.uriParameterValueToBoolean( cs ) THEN
         _Web^.DisconnectEIB();
         View := mvc.redirectView( STATUS_PAGE );
         RETURN TRUE;
      END;

      language := Language( Request );
   
      b := _Web^.Connected;
      Request.ModelContainer^.AddBooleanOA( STATUS_CONNECTED, b );
      b := _Web^.CacheOnlyMode;
      Request.ModelContainer^.AddBooleanOA( STATUS_CACHE_ONLY, b );

      starttime := _Web^.StartedTime;
      IF b THEN
         dt.JulianDate := _Web^.ConnectedTime;
      ELSE
         dt.JulianDate := _Web^.DisconnectedTime;
      END;
      IF dt.Empty THEN
         dt.JulianDate := starttime;
      END;
      dt.SetZoneToLocal();
      IF Languages.LanguageToRFC1766( language, OUT LangName ) AND Strings.StartsWithW( LangName, L"cs" ) THEN
         b := dt.ToLanguageStringOA( language, DATETIME_FORMAT_CS, TRUE, TRUE, OUT s );
      ELSE
         LangName := L""; // it is used below too
         b := dt.ToLanguageStringOA( language, DATETIME_FORMAT_EN, TRUE, TRUE, OUT s );
      END;
      IF b THEN
         cs.FromOA( s );
      ELSE
         cs.FromOA( L"N/A" );
      END;
      Request.ModelContainer^.AddStringOA( STATUS_CONNECTIONTIME, cs );
      Request.ModelContainer^.AddStringOA( STATUS_CONNECTION, _Web^.Connection );
      Request.ModelContainer^.AddBooleanOA( STATUS_CONNECT, FALSE );
      Request.ModelContainer^.AddBooleanOA( STATUS_DISCONNECT, FALSE );
      
      currentDT.SetNowUTC();
      currentTime := currentDT.JulianDate;
      uptime := currentTime - starttime;
      dt.Day := datetime.JDCToDays( uptime );
      datetime.fd2HMS( datetime.fd( uptime ), OUT dt.Hour, OUT dt.Minute, OUT dt.Second, OUT dt.Millisecond );

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
         Request.MessageSource^.GetMessageOA( Language( Request ), STATUS_TEXT_PERMANENT, OUT cs );
      ELSE
         dt.SetZoneToLocal();
         IF Strings.StartsWithW( LangName, L"cs" ) THEN
            dt.ToLanguageStringOA( language, DATETIME_FORMAT_CS, TRUE, TRUE, OUT s );
         ELSE
            dt.ToLanguageStringOA( language, DATETIME_FORMAT_EN, TRUE, TRUE, OUT s );
         END;
         Request.MessageSource^.GetMessageOA( language, STATUS_TEXT_VALID_UNTIL, OUT cs );
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
      
      Request.ModelContainer^.AddStringOA( STATUS_PROJECT, _Web^.Project^ );
 
      View := GetPageTemplateView( Request, STATUS_VIEW );
      RETURN TRUE;
   END ProcessStatus;
   
(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ProcessControl( CONST Request : mvc.IMvcRequest; OUT View : mvc.TPView ) : BOOLEAN;
   VAR
      count : CARDINAL;
      cs : StringsO.CString;
      i : CARDINAL;
      log : ARRAY [0..511] OF WCHAR;
      listDevices : lists.TPStringStringList;
      listRunning : lists.TPStringStringList;
      listIndexes : lists.TPStringStringList;
      uriParameters : lists.TPStringStringList := Request.URIParameters;
   BEGIN
      // check actions to do
      IF Request.RequestVerb = HttpCommon.verbPOST THEN // OK, process form output
         IF Request.ModelContainer^.GetStringOA( CONTROL_CONFIG_FILE, OUT cs ) THEN
            _Web^.ConfigureEIB( cs );
         END;
         View := mvc.redirectView( CONTROL_PAGE );
         RETURN TRUE;
      ELSIF uriParameters^.GetOA( CONTROL_START, OUT cs ) AND cs.ToCARD32( 10, OUT i ) AND ( i <> -1 ) THEN
         IF i > MAX( INTEGER ) THEN
            // do nothing
         ELSIF i < _Web^.OperatedDeviceCount THEN
            _Web^.OperateDevice( i, TRUE );
         END;
         View := mvc.redirectView( CONTROL_PAGE );
         RETURN TRUE;
      ELSIF uriParameters^.GetOA( CONTROL_STOP, OUT cs ) AND cs.ToCARD32( 10, OUT i ) AND ( i <> -1 ) THEN
         IF i > MAX( INTEGER ) THEN
            // do nothing
         ELSIF i < _Web^.OperatedDeviceCount THEN
            _Web^.OperateDevice( i, FALSE );
         END;
         View := mvc.redirectView( CONTROL_PAGE );
         RETURN TRUE;
      ELSIF uriParameters^.GetOA( CONTROL_DOWNLOAD, OUT cs ) AND cs.ToCARD32( 10, OUT i ) AND ( i <> -1 ) THEN
         View := mvc.fileView( ADR( SELF ), RESOLVER_CONTEXT_DISK, OA( _Web^.Configuration^.Length-1, _Web^.Configuration^.Data ), TRUE, ADR( SELF ), RESOLVER_CONTEXT_WEB );
         RETURN TRUE;
      END;

      Request.ModelContainer^.AddListOA( CONTROL_DEVICES_NAME, OUT listDevices ); listDevices^.Dispose();
      Request.ModelContainer^.AddListOA( CONTROL_DEVICES_RUN, OUT listRunning ); listRunning^.Dispose();
      Request.ModelContainer^.AddListOA( CONTROL_DEVICES_IDX, OUT listIndexes ); listIndexes^.Dispose();

      count := _Web^.OperatedDeviceCount;
      IF count > 0 THEN
         FOR i := 0 TO count-1 DO
            Request.MessageSource^.GetMessageOA( Language( Request ), OAsz( _Web^.OperatedDeviceName( i )), OUT cs );
            listDevices^.Add( cs, cs );

            IF _Web^.DeviceRunning( i ) THEN
               cs.FromOA( TRUE_S );
            ELSE
               cs.FromOA( FALSE_S );
            END;
            listRunning^.Add( cs, cs );

            cs.FromCARD32( i, 10 );
            listIndexes^.Add( cs, cs );
         END;
      END;

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
            
      View := GetPageTemplateView( Request, CONTROL_VIEW );
      RETURN TRUE;
   END ProcessControl;
   
(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ProcessDataLog( CONST Request : mvc.IMvcRequest; OUT View : mvc.TPView ) : BOOLEAN;
   VAR
      count : CARDINAL;
      cs : StringsO.CString;
      downloadFlag : BOOLEAN;
      empty : StringsO.CString;
      i : CARDINAL;
      log : ARRAY [0..511] OF WCHAR;
      logS : StringsO.CString;
      uriParameters : lists.TPStringStringList := Request.URIParameters;
   BEGIN
      downloadFlag := uriParameters^.GetOA( LOG_DOWNLOAD, OUT cs ) AND cs.ToCARD32( 10, OUT i ) AND ( i <> -1 );
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

         View := mvc.rawTextView( OA( logS.Length-1, logS.Data ), L"datalog", empty, TRUE );
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
         View := GetPageTemplateView( Request, DATA_LOG_VIEW );
      END;

      RETURN TRUE;
   END ProcessDataLog;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ProcessSystemLog( CONST Request : mvc.IMvcRequest; OUT View : mvc.TPView ) : BOOLEAN;
   VAR
      count : CARDINAL;
      cs : StringsO.CString;
      empty : StringsO.CString;
      i : CARDINAL;
      log : ARRAY [0..511] OF WCHAR;
      logS : StringsO.CString;
      uriParameters : lists.TPStringStringList := Request.URIParameters;
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

      IF uriParameters^.GetOA( LOG_DOWNLOAD, OUT cs ) AND cs.ToCARD32( 10, OUT i ) AND ( i <> -1 ) THEN
         View := mvc.rawTextView( OA( logS.Length-1, logS.Data ), L"systemlog", empty, TRUE );
      ELSE
         Request.ModelContainer^.AddStringOA( LOG_LOG, logS );
         View := GetPageTemplateView( Request, SYSTEM_LOG_VIEW );
      END;

      RETURN TRUE;
   END ProcessSystemLog;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ProcessIO( CONST Request : mvc.IMvcRequest; OUT View : mvc.TPView ) : BOOLEAN;
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
            Request.ModelContainer^.AddBooleanOA( IO_WRITE_FAILED, NOT _Web^.SetValue( Request.RequestSource, wname, wvalue ));
         END;

         View := mvc.redirectView( IO_PAGE );
         RETURN TRUE;
         
      ELSE // error
         View := mvc.redirectView( IO_PAGE );
         RETURN TRUE;
      END;

      Request.ModelContainer^.AddStringOA( IO_FORM_ID, empty );
      Request.ModelContainer^.AddStringOA( IO_READ_NAME, rname );
      Request.ModelContainer^.AddStringOA( IO_READ_VALUE, rvalue );
      Request.ModelContainer^.AddBooleanOA( IO_READ_FAILED, rfailed );
      Request.ModelContainer^.AddStringOA( IO_WRITE_NAME, wname );
      Request.ModelContainer^.AddStringOA( IO_WRITE_VALUE, wvalue );
      Request.ModelContainer^.AddBooleanOA( IO_WRITE_FAILED, wfailed );

      View := GetPageTemplateView( Request, IO_VIEW );
      RETURN TRUE;
   END ProcessIO;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ProcessUsers( CONST Request : mvc.IMvcRequest; OUT View : mvc.TPView ) : BOOLEAN;
   VAR
      cs : StringsO.CString;
      empty : StringsO.CString;
      i : CARDINAL;
      listRoles : lists.TPStringStringList;
      listRoleIds : lists.TPStringStringList;
      listUsers : lists.TPStringStringList;
      listUserIds : lists.TPStringStringList;
      role : EibSrvWeb.TRole;
      roleName : StringsO.CString;
      userName : StringsO.CString;
   BEGIN
      Request.ModelContainer^.AddListOA( USERS_ROLES, OUT listRoles ); listRoles^.Dispose();
      Request.ModelContainer^.AddListOA( USERS_ROLE_IDS, OUT listRoleIds ); listRoleIds^.Dispose();
      Request.ModelContainer^.AddListOA( USERS_USERS, OUT listUsers ); listUsers^.Dispose();
      Request.ModelContainer^.AddListOA( USERS_USER_IDS, OUT listUserIds ); listUserIds^.Dispose();

      // roles
      FOR i := 0 TO _Web^.RolesCount-1 DO
         IF _Web^.GetRole( i, OUT role, OUT roleName ) THEN
            IF ( role = EibSrvWeb.roleSystemAdministrator ) OR ( role = EibSrvWeb.roleSystemUser ) THEN
               CONTINUE;
            END;
            listRoles^.Add( roleName, roleName );
            cs.FromCARD32( i+1, 10 );
            listRoleIds^.Add( cs, cs );
         END;
      END; // FOR
   
      // users
      FOR i := 0 TO _Web^.UsersCount-1 DO
         IF _Web^.GetUser( i, OUT role, OUT userName, OUT roleName ) THEN
            listUsers^.Add( userName, roleName );
            cs.FromCARD32( i+1, 10 );
            listUserIds^.Add( cs, cs );
         END;
      END; // FOR
   
      View := GetPageTemplateView( Request, USERS_VIEW );
      RETURN TRUE;
   END ProcessUsers;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ProcessRoleEdit( CONST Request : mvc.IMvcRequest; OUT View : mvc.TPView ) : BOOLEAN;
   VAR
      action : StringsO.CString;
      currentName : StringsO.CString;
      cs1, cs2 : StringsO.CString;
      empty : StringsO.CString;
      i : CARDINAL;
      id : CARDINAL;
      ids : StringsO.CString;
      idValid : BOOLEAN := FALSE;
      keyed : BOOLEAN;
      role : EibSrvWeb.TRole;
      roleName : StringsO.CString;
      uriParameters : lists.TPStringStringList := Request.URIParameters;
   BEGIN
      Request.ModelContainer^.AddBooleanOA( USERS_ERROR, FALSE );
      Request.ModelContainer^.AddStringOA( USERS_ERROR_TEXT, empty );
      Request.ModelContainer^.AddStringOA( MESSAGE, empty );

      // retrieve editation id      
      IF Request.RequestVerb = HttpCommon.verbPOST THEN // OK, process form output
         Request.ModelContainer^.GetStringOA( USERS_ID, OUT ids );
      ELSIF uriParameters^.GetOA( USERS_ID, OUT ids ) THEN // OK, first opening the page transfers id using URI...
         Request.ModelContainer^.AddStringOA( USERS_ID, ids );
      ELSE // ...the second opening uses model's variable
         Request.ModelContainer^.GetStringOA( USERS_ID, OUT ids );
      END;
      IF NOT ids.Empty THEN
         ids.ToINT32( 10, OUT id );
         IF id = -1 THEN // new role is to be edited
            idValid := TRUE; 
         ELSE
            DEC( id );
            IF _Web^.GetRole( id, OUT role, OUT currentName ) THEN
               idValid := TRUE;
            ELSE
               Request.ModelContainer^.AddBooleanOA( USERS_ERROR, TRUE );
               Request.MessageSource^.GetMessageOA( Language( Request ), USERS_ERROR_TEXT_BADEDITDATA, OUT cs1 );
               Request.ModelContainer^.AddStringOA( USERS_ERROR_TEXT, cs1 );
            END;
         END;
      END;

      IF NOT idValid THEN
         Request.ModelContainer^.AddStringOA( USERS_ID, empty ); // kill edited id, bad action
         // fall down to display error
      
      ELSIF Request.RequestVerb = HttpCommon.verbPOST THEN // OK, process form output
         // validate
         Request.ModelContainer^.GetStringOA( ROLE_EDIT_NAME, OUT roleName ); 
         Request.ModelContainer^.GetBooleanOA( ROLE_EDIT_KEYED, OUT keyed ); 
         IF keyed THEN
            role := EibSrvWeb.roleUserKeyed;
         ELSE
            role := EibSrvWeb.roleUserNamed;
         END;
         
         IF roleName.Empty THEN
            Request.MessageSource^.GetMessageOA( Language( Request ), ROLE_EDIT_ERROR_TEXT_EMPTYNAME, OUT cs1 );
         ELSIF _Web^.CheckRenameRoleConflict( currentName, roleName ) THEN
            Request.MessageSource^.GetMessageOA( Language( Request ), ROLE_EDIT_ERROR_NAME_EXISTS, OUT cs1 );

         ELSIF _Web^.UpdateRole( currentName, roleName, role ) THEN
            Request.ModelContainer^.AddStringOA( USERS_ID, empty ); // kill edited id
            View := mvc.redirectView( USERS_PAGE );
            RETURN TRUE;
         ELSE // error during updating
            Request.MessageSource^.GetMessageOA( Language( Request ), ROLE_EDIT_ERROR_TEXT_UPDATEFAILED, OUT cs1 );
         END;

         // fill error message
         Request.ModelContainer^.AddStringOA( MESSAGE, cs1 );
         currentName.Assign( roleName );

      ELSIF uriParameters^.GetOA( USERS_ACTION, OUT action ) AND NOT action.Empty THEN

         IF Request.ModelContainer^.GetStringOA( USERS_ID, OUT ids ) AND NOT ids.Empty THEN
            // Request.ModelContainer^.AddStringOA( USERS_ID, empty ); -- leave users_id until editing finishes

            IF action.EqualsOA( ACTION_DELETE ) THEN
               IF _Web^.DeleteRole( currentName ) THEN
                  Request.ModelContainer^.AddStringOA( USERS_ID, empty ); // kill edited id, no next deletion allowed
                  View := mvc.redirectView( USERS_PAGE );
                  RETURN TRUE;
               ELSE // role cannot be deleted
                  Request.MessageSource^.GetMessageOA( Language( Request ), ROLE_EDIT_ERROR_TEXT_DELETEFAILED, OUT cs1 );
                  Request.ModelContainer^.AddStringOA( MESSAGE, cs1 );
               END;

            ELSIF action.EqualsOA( ACTION_EDIT ) THEN 
               // loop self to edit page with stored editation id
               View := mvc.redirectView( ROLE_EDIT_PAGE );
               RETURN TRUE;

            ELSE
               Request.ModelContainer^.AddStringOA( USERS_ID, empty ); // kill edited id, bad action
               
            END;
         END;
      END;

      Request.ModelContainer^.AddStringOA( ROLE_EDIT_NAME, currentName );
      // user role is always KEYED -- see #206
      // Request.ModelContainer^.AddBooleanOA( ROLE_EDIT_KEYED, role = EibSrvWeb.roleUserKeyed );
      Request.ModelContainer^.AddBooleanOA( ROLE_EDIT_KEYED, ( role <> EibSrvWeb.roleSystemUser ) AND ( role <> EibSrvWeb.roleSystemAdministrator ));

      View := GetPageTemplateView( Request, ROLE_EDIT_VIEW );
      RETURN TRUE;
   END ProcessRoleEdit;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ProcessUserEdit( CONST Request : mvc.IMvcRequest; OUT View : mvc.TPView ) : BOOLEAN;
   VAR
      action : StringsO.CString;
      currentName : StringsO.CString;
      cs1, cs2 : StringsO.CString;
      empty : StringsO.CString;
      i : CARDINAL;
      id : CARDINAL;
      ids : StringsO.CString;
      idValid : BOOLEAN := FALSE;
      listRoles : lists.TPStringStringList;
      listRoleIds : lists.TPStringStringList;
      role : EibSrvWeb.TRole;
      roleName : StringsO.CString;
      userName : StringsO.CString;
      uriParameters : lists.TPStringStringList := Request.URIParameters;
   BEGIN
      Request.ModelContainer^.AddBooleanOA( USERS_ERROR, FALSE );
      Request.ModelContainer^.AddStringOA( USERS_ERROR_TEXT, empty );
      Request.ModelContainer^.AddStringOA( MESSAGE, empty );

      // retrieve editation id      
      IF Request.RequestVerb = HttpCommon.verbPOST THEN // OK, process form output
         Request.ModelContainer^.GetStringOA( USERS_ID, OUT ids );
      ELSIF uriParameters^.GetOA( USERS_ID, OUT ids ) THEN // OK, first opening the page transfers id using URI...
         Request.ModelContainer^.AddStringOA( USERS_ID, ids );
      ELSE // ...the second opening uses model's variable
         Request.ModelContainer^.GetStringOA( USERS_ID, OUT ids );
      END;
      IF NOT ids.Empty THEN
         ids.ToINT32( 10, OUT id );
         IF id = -1 THEN // new user is to be edited
            idValid := TRUE; 
            role := EibSrvWeb.roleUserNamed;
         ELSE
            DEC( id );
            IF _Web^.GetUser( id, OUT role, OUT currentName, OUT roleName ) THEN
               idValid := TRUE; 
            ELSE
               Request.ModelContainer^.AddBooleanOA( USERS_ERROR, TRUE );
               Request.MessageSource^.GetMessageOA( Language( Request ), USERS_ERROR_TEXT_BADEDITDATA, OUT cs1 );
               Request.ModelContainer^.AddStringOA( USERS_ERROR_TEXT, cs1 );
            END;
         END;
      END;

      IF NOT idValid THEN
         Request.ModelContainer^.AddStringOA( USERS_ID, empty ); // kill edited id, bad action
         // fall down to display error
      
      ELSIF Request.RequestVerb = HttpCommon.verbPOST THEN // OK, process form output
         // validate
         Request.ModelContainer^.GetStringOA( USER_EDIT_NAME, OUT userName ); 
         Request.ModelContainer^.GetStringOA( USER_EDIT_PASSWORD1, OUT cs1 ); 
         Request.ModelContainer^.GetStringOA( USER_EDIT_PASSWORD2, OUT cs2 );
         Request.ModelContainer^.GetStringOA( USER_EDIT_ROLE, OUT roleName );
         IF userName.Empty THEN
            Request.MessageSource^.GetMessageOA( Language( Request ), USER_EDIT_ERROR_TEXT_EMPTYNAME, OUT cs1 );
         ELSIF cs1.Empty THEN
            Request.MessageSource^.GetMessageOA( Language( Request ), USER_EDIT_ERROR_TEXT_PASSWORDEMPTY, OUT cs1 );
         ELSIF cs1 <> cs2 THEN
            Request.MessageSource^.GetMessageOA( Language( Request ), USER_EDIT_ERROR_TEXT_PASSWORDSDONOTMATCH, OUT cs1 );
         ELSIF roleName.Empty THEN
            Request.MessageSource^.GetMessageOA( Language( Request ), USER_EDIT_ERROR_TEXT_EMPTYROLE, OUT cs1 );
         ELSIF _Web^.CheckRenameUserConflict( currentName, userName ) THEN
            Request.MessageSource^.GetMessageOA( Language( Request ), USER_EDIT_ERROR_NAME_EXISTS, OUT cs1 );

         ELSIF _Web^.UpdateUser( roleName, currentName, userName, cs2 ) THEN // either add new or update edited user
            Request.ModelContainer^.AddStringOA( USERS_ID, empty ); // kill edited id
            View := mvc.redirectView( USERS_PAGE );
            RETURN TRUE;
         ELSE // error during updating
            Request.MessageSource^.GetMessageOA( Language( Request ), USER_EDIT_ERROR_TEXT_UPDATEFAILED, OUT cs1 );
         END;

         // fill error message
         Request.ModelContainer^.AddStringOA( MESSAGE, cs1 );
         currentName.Assign( userName );

      ELSIF uriParameters^.GetOA( USERS_ACTION, OUT action ) AND NOT action.Empty THEN
         
         IF Request.ModelContainer^.GetStringOA( USERS_ID, OUT ids ) AND NOT ids.Empty THEN
            // Request.ModelContainer^.AddStringOA( USERS_ID, empty ); -- leave users_id until editing finishes

            IF action.EqualsOA( ACTION_DELETE ) THEN
               IF _Web^.DeleteUser( currentName ) THEN
                  Request.ModelContainer^.AddStringOA( USERS_ID, empty ); // kill edited id, no next deletion allowed
                  View := mvc.redirectView( USERS_PAGE );
                  RETURN TRUE;
               ELSE // user cannot be deleted
                  Request.MessageSource^.GetMessageOA( Language( Request ), USER_EDIT_ERROR_TEXT_DELETEFAILED, OUT cs1 );
                  Request.ModelContainer^.AddStringOA( MESSAGE, cs1 );
               END;

            ELSIF action.EqualsOA( ACTION_EDIT ) THEN 
               // loop self to edit page with stored editation id
               View := mvc.redirectView( USER_EDIT_PAGE );
               RETURN TRUE;

            ELSE
               Request.ModelContainer^.AddStringOA( USERS_ID, empty ); // kill edited id, bad action
               
            END;
         END;
      END;

      Request.ModelContainer^.AddStringOA( USER_EDIT_ROLE, roleName );
      Request.ModelContainer^.AddStringOA( USER_EDIT_NAME, currentName );
      Request.ModelContainer^.AddStringOA( USER_EDIT_PASSWORD1, empty );
      Request.ModelContainer^.AddStringOA( USER_EDIT_PASSWORD2, empty );

      // roles
      Request.ModelContainer^.AddListOA( USERS_ROLES, OUT listRoles ); listRoles^.Dispose();
      Request.ModelContainer^.AddListOA( USERS_ROLE_IDS, OUT listRoleIds ); listRoleIds^.Dispose();
      i := 0;
      WHILE _Web^.GetRole( i, OUT role, OUT roleName ) DO
         listRoles^.Add( roleName, roleName );
         cs1.FromCARD32( i+1, 10 );
         listRoleIds^.Add( cs1, cs1 );
         INC( i );
      END; // WHILE
   
      View := GetPageTemplateView( Request, USER_EDIT_VIEW );
      RETURN TRUE;
   END ProcessUserEdit;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ProcessUserLogin( REF Request : mvc.IMvcRequest; OUT View : mvc.TPView ) : BOOLEAN;
   VAR
      redirected : BOOLEAN;
      src, su, sp : StringsO.CString;
   BEGIN
      IF Request.RequestVerb = HttpCommon.verbGET THEN // OK, only render a login page
         // message is cleared in all GETs, but in GET coming from redirect
         IF Request.ModelContainer^.GetBooleanOA( LOGIN_REDIRECTED, OUT redirected ) AND redirected THEN
            Request.ModelContainer^.RemoveOA( LOGIN_REDIRECTED );
         ELSE
            Request.ModelContainer^.AddStringOA( MESSAGE, sp ); // empty
         END;
         Request.ModelContainer^.AddStringOA( LOGIN_USERNAME, sp ); // empty
         Request.ModelContainer^.AddStringOA( LOGIN_PASSWORD, sp ); // empty
         View := GetPageTemplateView( Request, USER_LOGIN_VIEW );

      // post, try to login
      ELSIF // checked before ProcessUserLogin is called, but there "src" must be get:
            NOT Request.ModelContainer^.GetStringOA( USER_LOGIN_SOURCE_PAGE, OUT src ) OR // bad input
            NOT Request.ModelContainer^.GetStringOA( LOGIN_USERNAME, OUT su ) OR // bad input
            NOT Request.ModelContainer^.GetStringOA( LOGIN_PASSWORD, OUT sp ) OR // bad input
            NOT ValidateUser( Request, su, sp ) THEN // bad credentials
         InvalidateUser( REF Request );

         Request.MessageSource^.GetMessageOA( Language( Request ), ERROR_USER_LOGIN_BAD_CREDENTIALS, OUT su );
         Request.ModelContainer^.AddStringOA( MESSAGE, su );

         sp.Clear();
         Request.ModelContainer^.AddStringOA( LOGIN_USERNAME, sp ); // empty
         Request.ModelContainer^.AddStringOA( LOGIN_PASSWORD, sp ); // empty
         View := GetPageTemplateView( Request, USER_LOGIN_VIEW );
         
      ELSE // OK, set up session, redirect to source page
         Request.ModelContainer^.RemoveOA( USER_LOGIN_SOURCE_PAGE );

         Request.Session^.Remove( SESSION_LOGGED );
         Request.Session^.Add( SESSION_LOGGED, ADR( SELF ));
         View := mvc.redirectView( OA( src.Length-1, src.Data ));

      END;

      RETURN TRUE;
   END ProcessUserLogin;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ValidateUser( CONST Request : mvc.IMvcRequest; CONST UserName, Password : StringsO.CString ) : BOOLEAN;
   VAR
      role : EibSrvWeb.TRole;
      Role : StringsO.CString;
   BEGIN
      role := _Web^.Authenticate( UserName, Password, OUT Role );

      Request.Session^.Remove( SESSION_ROLE );
      Request.Session^.Add( SESSION_ROLE, PTR( role ));

      Request.ModelContainer^.RemoveOA( ROLE_NAME );
      Request.ModelContainer^.AddStringOA( ROLE_NAME, Role );
      Request.ModelContainer^.AddBooleanOA( ROLE_IS_KEYED, role = EibSrvWeb.roleUserKeyed );

      RETURN role <> EibSrvWeb.roleGuest;
   END ValidateUser;
   
(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE InvalidateUser( REF Request : mvc.IMvcRequest );
   BEGIN
      // cleanup session
      Request.Session^.Remove( SESSION_LOGGED ); // kill potentially logged user

      Request.Session^.Remove( SESSION_ROLE );
      Request.Session^.Add( SESSION_ROLE, PTR( EibSrvWeb.roleGuest ));

      // cleanup and recreate container
      Request.ModelContainer^.Dispose();
      InitializeModelContainer( REF Request.ModelContainer^ );
   END InvalidateUser;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE SetOverriddenLanguage( CONST Request : mvc.IMvcRequest; CONST Language : StringsO.IString );
   VAR
      _Language : Languages.TLanguage;
   BEGIN
      IF Language.Empty THEN
         RETURN; // do nothing
      ELSIF Language.EqualsOA( L"client" ) THEN
         _Language := INVALID_LANGUAGE;
      ELSIF NOT HttpTools.DecodeLanguage( Language, OUT _Language ) THEN
         _Language := INVALID_LANGUAGE;
      END;
      Request.Session^.Remove( LANGUAGE );
      Request.Session^.Add( LANGUAGE, _Language );
   END SetOverriddenLanguage;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Language( CONST Request : mvc.IMvcRequest ) : Languages.TLanguage;
   VAR
      _Language : Languages.TLanguage;
   BEGIN
      IF Request.Session^.Get( LANGUAGE, OUT _Language ) THEN
         RETURN _Language;
      ELSE
         RETURN Request.Language;
      END;
   END Language;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE GetPageTemplateView( CONST Request : mvc.IMvcRequest; CONST ViewName : ARRAY OF WCHAR ) : mvc.TPView;
   VAR
      _Language : Languages.TLanguage;
      View : mvc.TPView;
   BEGIN
      IF NOT Request.Session^.Get( LANGUAGE, OUT _Language ) THEN
         _Language := INVALID_LANGUAGE;
      END;
      IF _Language = INVALID_LANGUAGE THEN
         View := mvc.pageTemplateView( ADR( SELF ), ViewName, FALSE, 0 );
      ELSE
         View := mvc.pageTemplateView( ADR( SELF ), ViewName, TRUE, _Language );
      END;
      RETURN View;
   END GetPageTemplateView;

(*--------------------------------------------------------------------------------*)

BEGIN
   _Web := NIL;;
END CController;

(*================================================================================*)

END Controller.
