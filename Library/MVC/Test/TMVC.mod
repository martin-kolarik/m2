MODULE TMVC;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE, Move;

IMPORT
   collection,
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

      Host^.StopPhaseWithResult( NOT Failure1 AND NOT Failure2 );

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
      d : PTR;
      l : lists.TPStringStringList;
      lit : lists.CStringStringListIterator;
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
            lit.Init( l^, collection.dirForward );
            WHILE lit.MoveNext() DO
               s.Assign( lit.Value^ );
               v.Assign( lit.Data^ );
            END;
         END;
         Request.ModelContainer^.AddListOA( L"testlist", OUT l );
         l^.Add( StringsO.FromOA( L"list item 1" ), s );
         l^.Add( StringsO.FromOA( L"list item 2" ), s );
         l^.Add( StringsO.FromOA( L"list item 3" ), s );
         l^.Add( StringsO.FromOA( L"list item 4" ), s );
         l^.Add( StringsO.FromOA( L"list item 5" ), s );

         IF Request.ModelContainer^.GetMapOA( L"testmap", OUT m ) THEN
            b := m^.Get( StringsO.FromOA( L"key" ), OUT v, OUT d );
            b := m^.Get( StringsO.FromOA( L"lock" ), OUT v, OUT d );
            b := m^.Get( StringsO.FromOA( L"flock" ), OUT v, OUT d );
            b := m^.Get( StringsO.FromOA( L"block" ), OUT v, OUT d );
            b := m^.Get( StringsO.FromOA( L"mlock" ), OUT v, OUT d );
         END;
         Request.ModelContainer^.AddMapOA( L"testmap", OUT m );
         s.FromOA( L"MAPA" ); m^.Add( StringsO.FromOA( L"key" ), s, 0 );
         s.FromOA( L"MAPB" ); m^.Add( StringsO.FromOA( L"lock" ), s, 0 );
         s.FromOA( L"MAPC" ); m^.Add( StringsO.FromOA( L"flock" ), s, 0 );
         s.FromOA( L"MAPD" ); m^.Add( StringsO.FromOA( L"block" ), s, 0 );
         s.FromOA( L"MAPE" ); m^.Add( StringsO.FromOA( L"mlock" ), s, 0 );

         View := MVC.pageTemplateView( NIL, L"d:\work\smartcontrol\code\library\httpsrv\~Debug\page.pt", FALSE, 0 );
      END;
      RETURN TRUE;
   END ProcessRequest;

(*---------------------------------------------------------------------------*)

END CController;

(*===========================================================================*)

END TMVC.
