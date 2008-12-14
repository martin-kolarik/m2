IMPLEMENTATION MODULE Controller;

(*================================================================================*)

FROM Debug IMPORT
   Assertion;
   
IMPORT
   HttpCommon;

(*--------------------------------------------------------------------------------*)

CONST
   SESSION_LOGGED = L"logged";

   LOGIN_VIEW = L"login.pt.xml";
   
   LOGIN_USERNAME = L"username";
   LOGIN_PASSWORD = L"password";

(*================================================================================*)

CLASS IMPLEMENTATION CController;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE ProcessRequest( CONST Request : mvc.TPHttpRequest; OUT View : mvc.TPView ) : BOOLEAN; // returning false means 500 response
   VAR
      data : PTR;
   BEGIN
      IF Request^.ControllerURI.EqualsOA( LOGIN_PAGE ) THEN
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
         View := mvc.pageTemplateView( NIL, LOGIN_VIEW );
         RETURN TRUE;

      // post, try to login
      ELSIF NOT Request^.ModelContainer^.GetStringOA( LOGIN_USERNAME, OUT su ) OR NOT Request^.ModelContainer^.GetStringOA( LOGIN_PASSWORD, OUT sp ) THEN
         // bad input
         // TODO
         RETURN FALSE;
      
      ELSIF NOT ValidateUser( su, sp ) THEN
         // bad credentials
         // TODO
         RETURN FALSE;
         
      ELSE // OK, set up session, redirect to status page
         Request^.Session^.Add( SESSION_LOGGED, ADR( SELF ));
         View := mvc.redirectView( STATUS_PAGE );
         RETURN TRUE;

      END;
   END ProcessLogin;
   
(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ProcessStatus( CONST Request : mvc.TPHttpRequest; OUT View : mvc.TPView ) : BOOLEAN;
   BEGIN
      // TODO
      RETURN FALSE;
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
