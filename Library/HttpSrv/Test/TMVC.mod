MODULE TMVC;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE, Move;

IMPORT
   HttpCommon,
   httpsrv,
   log,
   maps,
   msgqueuethread,
   MVC,
   scinit,
   StringsO,
   Sync,
   test,
   testimpl;
  
(*===========================================================================*)

TYPE
   TPTest = POINTER TO CTest;

(*---------------------------------------------------------------------------*)

CLASS CTest IMPLEMENTS test.ITest;
   PUBLIC VAR
      Host : test.TPHost := NIL;

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
END CTest;

(*---------------------------------------------------------------------------*)

CLASS CController IMPLEMENTS MVC.IController;
   PUBLIC VIRTUAL PROCEDURE ProcessRequest( CONST Request : MVC.TPHttpRequest; OUT View : MVC.TPView ) : BOOLEAN;
END CController;

(*---------------------------------------------------------------------------*)

CLASS CServerThread( msgqueuethread.MessageQueueThread );
   PRIVATE VAR
      mvc : MVC.TPMVC := NIL;
      Controller : CController;
   INTERNAL VIRTUAL PROCEDURE OnStart();
   INTERNAL VIRTUAL PROCEDURE OnExit();
END CServerThread;

(*---------------------------------------------------------------------------*)

VAR
   Test : CTest;

(*===========================================================================*)

CLASS IMPLEMENTATION CTest;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   VAR
      Failure1, Failure2 : BOOLEAN := FALSE;
      T : CServerThread;
   BEGIN
      SELF.Host := Host;
      scinit.Startup();

      (*==========*)

      Host^.StartPhase( L"Run HTTP server" );
      
      T.Run( FALSE );
      Sync.Sleep( 1000000 );
      T.Stop( TRUE );
      httpsrv.Cleanup();

      IF Failure1 OR Failure2 THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      (*==========*)

      scinit.Cleanup();
      IF Failure1 OR Failure2 THEN
         RETURN test.trFailure;
      ELSE
         RETURN test.trSuccess;
      END;
   END Run;
   
(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"MVC", ADR( Test ));
END CTest;

(*===========================================================================*)

CLASS IMPLEMENTATION CServerThread;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnStart();
   VAR
      root : StringsO.CString;
   BEGIN
      root.FromOA( '/test' );
      httpsrv.srv()^.RootPath := root;
      httpsrv.srv()^.Start();

      mvc := MVC.mvc( L"/context" );
      mvc^.RegisterController( ADR( Controller ), HttpCommon.verbGET, L"page.do" );
   END OnStart;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnExit();
   BEGIN
      mvc^.ForgetController( ADR( Controller ), HttpCommon.verbGET, L"page.do" );
      MVC.Cleanup();

      httpsrv.srv()^.Stop();
   END OnExit;

(*---------------------------------------------------------------------------*)

BEGIN
END CServerThread;

(*===========================================================================*)

CLASS IMPLEMENTATION CController;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE ProcessRequest( CONST Request : MVC.TPHttpRequest; OUT View : MVC.TPView ) : BOOLEAN;
   VAR
      Model : maps.TPStringStringMap;
      s : StringsO.CString;
   BEGIN
      IF Request^.ModelContainer^.GetModelOA( MVC.DEFAULT_MODEL, OUT Model ) THEN
         IF Model^.GetOA( L"ahoj", OUT s ) THEN
            // report
         END;
         s.FromOA( L"martine" );
         Model^.AddOA( L"ahoj", s );
      END;
      View := MVC.rawHTMLView( L"<html><head><title>KUKU»</title></head><body><h1>éluùouËk˝ k˘Ú ˙pÏl Ô·belskÈ Ûdy.</h1></body></html>" );
      RETURN TRUE;
   END ProcessRequest;

(*---------------------------------------------------------------------------*)

END CController;

(*===========================================================================*)

END TMVC.
