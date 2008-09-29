MODULE THttpSrv;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE, Move;

IMPORT
   HttpCommon,
   HttpConnection,
   httpsrv,
   log,
   msgqueuethread,
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

CLASS CServerThread( msgqueuethread.MessageQueueThread );
   INTERNAL VIRTUAL PROCEDURE OnStart();
END CServerThread;

(*---------------------------------------------------------------------------*)

CLASS CProcessor IMPLEMENTS httpsrv.IHttpProcessor;
   PUBLIC VIRTUAL PROCEDURE AppliesFor( Verb : HttpCommon.TVerb; CONST URL : ARRAY OF WCHAR; OUT WantsSession : BOOLEAN ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE ProcessRequest( Connection : HttpConnection.TPHttpSrvConnection; CONST Session : httpsrv.TPSession );
END CProcessor;

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
      Sync.Sleep( 10000 );
      httpsrv.srv()^.Stop();
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
   testimpl.tests()^.AddTest( L"HttpSrv", ADR( Test ));
END CTest;

(*===========================================================================*)

CLASS IMPLEMENTATION CServerThread;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnStart();
   VAR
      root : StringsO.CString;
   BEGIN
      root.FromOA( '/oa' );
      httpsrv.srv()^.RootPath := root;
      httpsrv.srv()^.Start();
      httpsrv.srv()^.RegisterProcessor( NEW( CProcessor ));
   END OnStart;

(*---------------------------------------------------------------------------*)

END CServerThread;

(*===========================================================================*)

CLASS IMPLEMENTATION CProcessor;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE AppliesFor( Verb : HttpCommon.TVerb; CONST URL : ARRAY OF WCHAR; OUT WantsSession : BOOLEAN ) : BOOLEAN;
   BEGIN
      WantsSession := FALSE;
      RETURN TRUE;
   END AppliesFor;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE ProcessRequest( Connection : HttpConnection.TPHttpSrvConnection; CONST Session : httpsrv.TPSession );
   CONST
      s = C"Hello, world!";
   VAR
      l : CARDINAL;
   BEGIN
      Connection^.Chunked := TRUE;

      Connection^.Stream^.WriteOA( OA( 11, ADR( s )), OUT l, Sync.FORSAFETY );
      Connection^.Stream^.WriteOA( OA( 11, ADR( s )), OUT l, Sync.FORSAFETY );
      Connection^.Stream^.WriteOA( OA( 11, ADR( s )), OUT l, Sync.FORSAFETY );
      Connection^.Stream^.WriteOA( OA( 11, ADR( s )), OUT l, Sync.FORSAFETY );
      Connection^.Stream^.WriteOA( OA( 11, ADR( s )), OUT l, Sync.FORSAFETY );
      Connection^.Stream^.WriteOA( OA( 11, ADR( s )), OUT l, Sync.FORSAFETY );

   END ProcessRequest;

(*---------------------------------------------------------------------------*)

END CProcessor;

(*===========================================================================*)

END THttpSrv.
