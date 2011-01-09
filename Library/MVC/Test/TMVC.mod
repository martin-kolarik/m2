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
   PUBLIC VIRTUAL PROCEDURE InitializeModelContainer( REF Container : MVC.IContainer );
   PUBLIC VIRTUAL PROCEDURE CleanupModelContainer( REF Container : MVC.IContainer );

   PUBLIC VIRTUAL PROCEDURE ProcessRequest( Fallback : BOOLEAN; REF Request : MVC.IMvcRequest; OUT View : MVC.TPView ) : BOOLEAN;
END CController;

(*---------------------------------------------------------------------------*)

CLASS CServerThread( msgqueuethread.MessageQueueThread );
   PRIVATE VAR
      mvc : MVC.TPMVC := NIL;
      Controller : CController;
   INTERNAL VIRTUAL PROCEDURE OnStart( Restarted : BOOLEAN );
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
      
      T.Start( FALSE );
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

   INTERNAL VIRTUAL PROCEDURE OnStart( Restarted : BOOLEAN );
   VAR
      root : StringsO.CString;
   BEGIN
      root.FromOA( '/test' );
      httpsrv.srv()^.RootPath := root;
      httpsrv.srv()^.Start();

      mvc := MVC.mvc( L"/context" );
      mvc^.RegisterController( ADR( Controller ), HttpCommon.verbGET, L"raw.do" );
      mvc^.RegisterController( ADR( Controller ), HttpCommon.verbGET, L"page.do" );
      mvc^.RegisterController( ADR( Controller ), HttpCommon.verbPOST, L"page.do" );
   END OnStart;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnExit();
   BEGIN
      mvc^.ForgetController( ADR( Controller ), HttpCommon.verbGET, L"raw.do" );
      mvc^.ForgetController( ADR( Controller ), HttpCommon.verbGET, L"page.do" );
      mvc^.ForgetController( ADR( Controller ), HttpCommon.verbPOST, L"page.do" );
      MVC.Cleanup();

      httpsrv.srv()^.Stop();
   END OnExit;

(*---------------------------------------------------------------------------*)

BEGIN
END CServerThread;

(*===========================================================================*)

CLASS IMPLEMENTATION CController;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE InitializeModelContainer( REF Container : MVC.IContainer );
   BEGIN
   END InitializeModelContainer;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CleanupModelContainer( REF Container : MVC.IContainer );
   BEGIN
   END CleanupModelContainer;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE ProcessRequest( Fallback : BOOLEAN; REF Request : MVC.IMvcRequest; OUT View : MVC.TPView ) : BOOLEAN;
   VAR
      b : BOOLEAN;
      l : lists.TPStringStringList;
      m : maps.TPStringStringMap;
      s : StringsO.CString;
      v : StringsO.CString;
   BEGIN
      IF Request.ControllerURI.EqualsOA( L"raw.do" ) THEN
         View := MVC.rawHTMLView( L"<html><head><title>KUKU»</title></head><body><h1>éluùouËk˝ k˘Ú ˙pÏl Ô·belskÈ Ûdy.</h1></body></html>" );

(*
   PROCEDURE GetBooleanOA( CONST Name : ARRAY OF WCHAR; OUT Model : BOOLEAN ) : BOOLEAN;
   PROCEDURE GetStringOA( CONST Name : ARRAY OF WCHAR; OUT Model : StringsO.IString ) : BOOLEAN;
   PROCEDURE GetListOA( CONST Name : ARRAY OF WCHAR; OUT Model : lists.TPStringStringList ) : BOOLEAN;
   PROCEDURE GetMapOA( CONST Name : ARRAY OF WCHAR; OUT Model : maps.TPStringStringMap ) : BOOLEAN;
*)

      ELSIF Request.ControllerURI.EqualsOA( L"page.do" ) THEN

         IF Request.ModelContainer^.GetBooleanOA( L"testbool", OUT b ) THEN
            b := b;
         END;
         Request.ModelContainer^.AddBooleanOA( L"testbool", TRUE );
         
         IF Request.ModelContainer^.GetStringOA( L"teststring", OUT s ) THEN
            s := s;
         END;
         s.FromOA( L"xxx" ); Request.ModelContainer^.AddStringOA( L"teststring", s );

         IF Request.ModelContainer^.GetListOA( L"testlist", OUT l ) THEN
            l^.Reset();
            WHILE l^.MoveNext() DO
               s.Assign( l^.Current^ );
               v.Assign( l^.CurrentData^ );
            END;
         END;
         Request.ModelContainer^.AddListOA( L"testlist", OUT l );
         l^.AddOA( L"list item 1", s );
         l^.AddOA( L"list item 2", s );
         l^.AddOA( L"list item 3", s );
         l^.AddOA( L"list item 4", s );
         l^.AddOA( L"list item 5", s );

         IF Request.ModelContainer^.GetMapOA( L"testmap", OUT m ) THEN
            b := m^.GetOA( L"key", OUT v );
            b := m^.GetOA( L"lock", OUT v );
            b := m^.GetOA( L"flock", OUT v );
            b := m^.GetOA( L"block", OUT v );
            b := m^.GetOA( L"mlock", OUT v );
         END;
         Request.ModelContainer^.AddMapOA( L"testmap", OUT m );
         s.FromOA( L"MAPA" ); m^.AddOA( L"key", s );
         s.FromOA( L"MAPB" ); m^.AddOA( L"lock", s );
         s.FromOA( L"MAPC" ); m^.AddOA( L"flock", s );
         s.FromOA( L"MAPD" ); m^.AddOA( L"block", s );
         s.FromOA( L"MAPE" ); m^.AddOA( L"mlock", s );

         View := MVC.pageTemplateView( NIL, L"d:\work\smartcontrol\code\library\httpsrv\~Debug\page.pt", FALSE, 0 );
      END;
      RETURN TRUE;
   END ProcessRequest;

(*---------------------------------------------------------------------------*)

END CController;

(*===========================================================================*)

END TMVC.
