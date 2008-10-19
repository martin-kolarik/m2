MODULE TMVC;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE, Move;

IMPORT
   HttpCommon,
   httpsrv,
   lists,
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
      mvc^.RegisterController( ADR( Controller ), HttpCommon.verbGET, L"raw.do" );
      mvc^.RegisterController( ADR( Controller ), HttpCommon.verbGET, L"page.do" );
   END OnStart;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnExit();
   BEGIN
      mvc^.ForgetController( ADR( Controller ), HttpCommon.verbGET, L"raw.do" );
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
      l : lists.TPStringStringList;
      m : maps.TPStringStringMap;
      s : StringsO.CString;
   BEGIN
      IF Request^.ControllerURI.EqualsOA( L"raw.do" ) THEN
         View := MVC.rawHTMLView( L"<html><head><title>KUKU»</title></head><body><h1>éluùouËk˝ k˘Ú ˙pÏl Ô·belskÈ Ûdy.</h1></body></html>" );

      ELSIF Request^.ControllerURI.EqualsOA( L"page.do" ) THEN
         Request^.ModelContainer^.AddBooleanOA( L"testbool", TRUE );

         s.FromOA( L"xxx" ); Request^.ModelContainer^.AddStringOA( L"teststring", s );

         Request^.ModelContainer^.AddListOA( L"testlist", OUT l );
         l^.AddOA( L"list item 1", 0 );
         l^.AddOA( L"list item 2", 0 );
         l^.AddOA( L"list item 3", 0 );
         l^.AddOA( L"list item 4", 0 );
         l^.AddOA( L"list item 5", 0 );

         Request^.ModelContainer^.AddMapOA( L"testmap", OUT m );
         s.FromOA( L"MAPA" ); m^.AddOA( L"key", s );
         s.FromOA( L"MAPB" ); m^.AddOA( L"lock", s );
         s.FromOA( L"MAPC" ); m^.AddOA( L"flock", s );
         s.FromOA( L"MAPD" ); m^.AddOA( L"block", s );
         s.FromOA( L"MAPE" ); m^.AddOA( L"mlock", s );

         View := MVC.pageTemplateView( NIL, L"d:\work\smartcontrol\code\library\httpsrv\~Debug\page.pt" );
      END;
      RETURN TRUE;
   END ProcessRequest;

(*---------------------------------------------------------------------------*)

END CController;

(*===========================================================================*)

END TMVC.
