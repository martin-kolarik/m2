MODULE SendReceiveBufferedStream;

IMPORT
   winsock;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   log,
   netinit,
   netpool,
   netsocket,
   netsrv,
   netstream,
   IOO,
   sync,
   test,
   testimpl,
   thread,
   windows;
  
(*===========================================================================*)

CONST
   count = 100000;

TYPE
   TPTest = POINTER TO CTest;

(*---------------------------------------------------------------------------*)

CLASS CServerListener( netsrv.AListener );
   PUBLIC VAR
      Test : TPTest;
   LOCAL VIRTUAL PROCEDURE OnListen( CONST ServerSocket : netsocket.TPSSocket );
END CServerListener;

(*---------------------------------------------------------------------------*)

CLASS CReader( IOO.CMemoryProxy );
   PUBLIC VAR
      DetectPrevious : BOOLEAN;
      PrevCount : INTEGER := 0;
      Summa : CARD64 := 0;
      Test : TPTest;
   PUBLIC VIRTUAL PROCEDURE CompleteData( Completed : CARDINAL );
END CReader;

(*---------------------------------------------------------------------------*)

CLASS CWriter( IOO.CMemoryProxy );
   PUBLIC VAR
      Summa : CARD64 := 0;
      Test : TPTest;
   PUBLIC VIRTUAL PROCEDURE CompleteData( Completed : CARDINAL );
END CWriter;

(*---------------------------------------------------------------------------*)

CLASS CReaderThread( thread.Thread );
   PUBLIC VAR
      Test : TPTest;
   INTERNAL VIRTUAL PROCEDURE OnRun() : CARDINAL;
END CReaderThread;   

(*---------------------------------------------------------------------------*)

CLASS CTest IMPLEMENTS test.ITest;
   PUBLIC VAR
      Host : test.TPHost := NIL;
      ServerListener : CServerListener;
      ServerSocket : netsocket.DSocket;
      
      Reader : CReader;
      Writer : CWriter;

      NetReadStream : netstream.CNetworkStream;
      ReadStream : IOO.CBufferedStream;
      
   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   PRIVATE PROCEDURE WaitForMessages( count : CARDINAL );
END CTest;

(*===========================================================================*)

CLASS IMPLEMENTATION CServerListener;

(*---------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnListen( CONST ServerSocket : netsocket.TPSSocket );
   VAR
      Error : CARDINAL;
   BEGIN
      Test^.ServerSocket.Accept( ServerSocket, OUT Error );
      Test^.NetReadStream.FromSocket( ADR( Test^.ServerSocket ), FALSE, IOO.accRead );
   END OnListen;

(*---------------------------------------------------------------------------*)

BEGIN
   Test := NIL;
END CServerListener;

(*===========================================================================*)

CLASS IMPLEMENTATION CReader;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE CompleteData( Completed : CARDINAL );
  BEGIN
    // windows.Sleep( CARDINAL( LL MOD 2 ));
    INC( Summa, Completed );
    SUPER.CompleteData( Completed );

    IF _Ptr < _Length THEN
      RETURN;
    END;
    _Ptr := 0; // reset reading

    IF DetectPrevious AND ( PINTEGER( _Data )^ <> PrevCount+1 ) THEN
       Test^.Host^.Log^.LogSC( log.dlcError, L"", L"Failed: ", PCARDINAL( _Data )^ );
    END;
    INC( PrevCount );
  END CompleteData;

(*---------------------------------------------------------------------------*)

BEGIN
   Test := NIL;
   DetectPrevious := FALSE;
END CReader;
  
(*===========================================================================*)

CLASS IMPLEMENTATION CWriter;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE CompleteData( Completed : CARDINAL );
  BEGIN
    INC( Summa, Completed );
    SUPER.CompleteData( Completed );
  END CompleteData;

(*---------------------------------------------------------------------------*)

BEGIN
   Test := NIL;
END CWriter;
  
(*===========================================================================*)

CLASS IMPLEMENTATION CReaderThread;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnRun() : CARDINAL;
   VAR
      c : CARDINAL;
   BEGIN
      Test^.Reader.Init( ADR( c ), SIZE( c ), FALSE );

      WHILE Test^.ReadStream.Read( ADR( Test^.Reader ), windows.INFINITE, TRUE ) = sync.arCompleted DO
         IF count = Test^.Reader.PrevCount + 1 THEN
            EXIT;
         END;
      END; // WHILE

      RETURN 0;
   END OnRun;

(*---------------------------------------------------------------------------*)

BEGIN
   Test := NIL;
END CReaderThread;   

(*===========================================================================*)

VAR
   Test : CTest;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CTest;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   VAR
      Count : INTEGER;
      Failure : BOOLEAN := FALSE;
      NetWriteStream : netstream.CNetworkStream;
      ReaderThread : CReaderThread;
      WriteStream : IOO.CBufferedStream;
   BEGIN
      SELF.Host := Host;
      ServerListener.Test := ADR( SELF );
      Reader.Test := ADR( SELF );
      Writer.Test := ADR( SELF );

      netinit.Startup();

      // global init      
      Reader.Persistent := TRUE;
      Writer.Persistent := TRUE;
      netsrv.SetCallbackMode( netsrv.cbmPooled );
      netsrv.StartListen( netsocket.stStream, 4444, NIL, ADR( ServerListener ), 0, NIL );

      ReadStream.Stream := ADR( NetReadStream );
      ReadStream.BufferSize := 257;

      WriteStream.Stream := ADR( NetWriteStream );
      WriteStream.BufferSize := 127;

      ReaderThread.Test := ADR( SELF );

      //=====

      Host^.StartPhase( L"BufferedStream, 100k * 4 bytes, W WAIT, 257/127, 1 T" );
      Reader.DetectPrevious := TRUE;
      Reader.PrevCount := 0;
      Reader.Summa := 0;
      
      // start
      NetWriteStream.FromServer( L"127.0.0.1", 4444 );
      WaitForMessages( 50 );
      ReaderThread.Run( TRUE );
  
      // run
      Count := 1; // must start from 1, it is due to comparsion with PrevCount in receiver
      LOOP
         Writer.Init( ADR( Count ), SIZE( Count ), FALSE );
         IF WriteStream.Write( ADR( Writer ), windows.INFINITE, TRUE ) = sync.arCompleted THEN
            INC( Count );
         ELSE
            Host^.Log^.LogSC( log.dlcError, L"", L"Write failure: ", Count );
         END;

         IF Count = count THEN
            EXIT;
         END;
      END; // LOOP

      // flush receiving
      WaitForMessages( 50 );
      ServerSocket.AbortReceive();

      WriteStream.Close( FALSE );
      ReaderThread.WaitStop( sync.INFINITE_TIME );
      
      // check
      IF Count <> Reader.PrevCount+1 THEN
         Failure := TRUE;
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

(*
      //=====

      Host^.StartPhase( L"BufferedStream, 100k * 4 bytes, W WAIT, 2057/127 1 T" );
      Reader.DetectPrevious := TRUE;
      Reader.PrevCount := 0;
      Reader.Summa := 0;
      
      // start
      NetWriteStream.FromServer( L"127.0.0.1", 4444 );
  
      // run
      Count := 1; // must start from 1, it is due to comparsion with PrevCount in receiver
      LOOP
         // write
         Writer.Init( ADR( Count ), SIZE( Count ), FALSE );
         IF WriteStream.Write( ADR( Writer ), windows.INFINITE, TRUE ) = sync.arCompleted THEN
            INC( Count );
            IF Count MOD 100 = 0 THEN
              sync.Sleep( 0 );
            END;
         ELSE
            Host^.Log^.LogSC( log.dlcError, L"", L"Write failure: ", Count );
         END;

         // flush
         WHILE ReadStream.Read( ADR( Reader ), windows.INFINITE, FALSE ) = sync.arCompleted DO END;

         IF Count = 100000 THEN
            EXIT;
         END;
      END; // LOOP

      // flush receiving
      WaitForMessages( 50 );
      WHILE ReadStream.Read( ADR( Reader ), 100, TRUE ) = sync.arCompleted DO END;
      ServerSocket.AbortReceive();

      WriteStream.Close( FALSE );
      
      // check
      IF Count <> Reader.PrevCount+1 THEN
         Failure := TRUE;
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;
*)      

      //=====

      netinit.Cleanup();
      IF Failure THEN
         RETURN test.trFailure;
      ELSE
         RETURN test.trSuccess;
      END;
   END Run;
   
(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE WaitForMessages( count : CARDINAL );
   VAR
      i : CARDINAL := count;
      msg : windows.MSG;
   BEGIN
      IF i = 0 THEN
         i := 5; // set
         LOOP
            IF netpool.Pool()^.UndeliveredMessagesPending THEN
               WHILE windows.PeekMessage( ADR( msg ), NIL, 0, 0, windows.PM_REMOVE ) = windows.True DO
                  windows.DispatchMessage( ADR( msg ));
               END; // WHILE
               i := 5; // reset
            ELSIF i = 0 THEN
               EXIT;
            END;
            DEC( i );
            windows.Sleep( 1 );
         END; // WHILE
      ELSE
         WHILE i > 0 DO
            WHILE windows.PeekMessage( ADR( msg ), NIL, 0, 0, windows.PM_REMOVE ) = windows.True DO
               windows.DispatchMessage( ADR( msg ));
            END; // WHILE
            DEC( i );
            windows.Sleep( 1 );
         END; // WHILE
      END;
   END WaitForMessages;

(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"Network::SendReceiveBufferedStream", ADR( Test ));
END CTest;

(*===========================================================================*)

END SendReceiveBufferedStream.

(*========================================================================*)
