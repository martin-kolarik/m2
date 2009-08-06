MODULE SendReceiveBufferedStream;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   IOO,
   inetaddr,
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
   threadpool,
   SCmsgqueuethread,
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
      Delay : CARDINAL := 0;
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
   INTERNAL VIRTUAL PROCEDURE OnRun( CONST Helper : thread.IRunnableHelper ) : CARDINAL;
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
    // _Ptr := 0; // reset reading

    IF DetectPrevious AND ( PINTEGER( _Data )^ <> PrevCount+1 ) THEN
       Test^.Host^.Log^.LogSC( log.dlcError, L"", L"Failed: ", PCARDINAL( _Data )^ );
    END;
    INC( PrevCount );
    
    IF Delay > 0 THEN
       sync.Sleep( Delay );
    END;
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

   INTERNAL VIRTUAL PROCEDURE OnRun( CONST Helper : thread.IRunnableHelper ) : CARDINAL;
   VAR
      c : CARDINAL;
      r : sync.TAsyncResult;
   BEGIN
      LOOP
         Test^.Reader.Init( ADR( c ), SIZE( c ), FALSE );
         r := Test^.ReadStream.Read( ADR( Test^.Reader ), windows.INFINITE, TRUE );
         IF r <> sync.arCompleted THEN
            Test^.Host^.Log^.LogSC( log.dlcError, L"", L"Read failure: ", Test^.Reader.PrevCount );
            Test^.Host^.Log^.LogSC( log.dlcError, L"", L"      result: ", CARDINAL( r ));
         END;
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
      ai : inetaddr.INETADDR;
      Count : INTEGER;
      Failure : BOOLEAN := FALSE;
      NetWriteStream : netstream.CNetworkStream;
      ReaderThread : CReaderThread;
      WriteStream : IOO.CBufferedStream;
      
   //----------

      PROCEDURE WriteOnly();
      BEGIN
         Reader.DetectPrevious := TRUE;
         Reader.PrevCount := 0;
         Reader.Summa := 0;
         Writer.Summa := 0;

         // start
         NetWriteStream.FromServer( L"127.0.0.1:4444" );
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

         WriteStream.Flush();
         WHILE Reader.PrevCount+1 < Count DO
            sync.Sleep( 0 );
         END;

         WriteStream.Close( FALSE );
         ReadStream.Close( FALSE );

         ReaderThread.Stop( TRUE );

         // check
         IF Count <> Reader.PrevCount+1 THEN
            Failure := TRUE;
            Host^.StopPhaseWithResult( test.trFailure );
         ELSE
            Host^.StopPhaseWithResult( test.trSuccess );
         END;
      END WriteOnly;
      
   //----------

      PROCEDURE ReadWrite( BigBlock : BOOLEAN );
      VAR
         bb : ARRAY [0..1023] OF CARDINAL;
         c : CARDINAL;
         lcount : INTEGER;
      BEGIN
         Reader.DetectPrevious := NOT BigBlock;
         Reader.PrevCount := 0;
         Reader.Summa := 0;
         Writer.Summa := 0;

         // start
         NetWriteStream.FromServer( L"127.0.0.1:4444" );
         WaitForMessages( 50 );
         
         IF BigBlock THEN
            lcount := count DIV 10;
         ELSE
            lcount := count;
         END;
     
         // run
         Count := 0; // must start from 0, it is incremented firstly
         LOOP
            IF NOT WriteStream.Writing THEN
               INC( Count );
               IF BigBlock THEN
                  Writer.Init( ADR( bb ), SIZE( bb ), FALSE );
               ELSE
                  Writer.Init( ADR( Count ), SIZE( Count ), FALSE );
               END;
               WriteStream.Write( ADR( Writer ), windows.INFINITE, FALSE );
            END;

            IF Count = lcount THEN
               EXIT;
            END;
            
            IF NOT ReadStream.Reading THEN
               IF BigBlock THEN
                  Reader.Init( ADR( bb ), SIZE( bb ), FALSE );
               ELSE
                  Reader.Init( ADR( c ), SIZE( c ), FALSE );
               END;
               ReadStream.Read( ADR( Reader ), windows.INFINITE, FALSE );
            END;
         END; // LOOP

         WriteStream.Flush();
         LOOP
            IF NOT ReadStream.Reading THEN
               Reader.Init( ADR( c ), SIZE( c ), FALSE );
               ReadStream.Read( ADR( Reader ), windows.INFINITE, FALSE );
            END;
            IF BigBlock THEN
               IF Reader.Summa < CARD64( lcount ) * SIZE( bb ) THEN
                  sync.Sleep( 0 );
               ELSE
                  EXIT;
               END;
            ELSE
               IF Reader.PrevCount+1 < Count THEN
                  sync.Sleep( 0 );
               ELSE
                  EXIT;
               END;
            END;
         END; // LOOP

         WriteStream.Close( FALSE );
         ReadStream.Close( FALSE );

         // check
         IF BigBlock THEN
            IF CARD64( lcount ) * SIZE( bb ) <> Reader.Summa THEN
               Failure := TRUE;
               Host^.StopPhaseWithResult( test.trFailure );
            ELSE
               Host^.StopPhaseWithResult( test.trSuccess );
            END;
         ELSE
            IF Count <> Reader.PrevCount+1 THEN
               Failure := TRUE;
               Host^.StopPhaseWithResult( test.trFailure );
            ELSE
               Host^.StopPhaseWithResult( test.trSuccess );
            END;
         END;
      END ReadWrite;
      
   //----------

   BEGIN
      SELF.Host := Host;
      ServerListener.Test := ADR( SELF );
      Reader.Test := ADR( SELF );
      Writer.Test := ADR( SELF );

      SCmsgqueuethread.Startup();
      threadpool.Startup();
      netinit.Startup();

      // global init      
      netsrv.SetCallbackMode( IOO.cbmPooled );
      
      ai.Port := 4444;
      netsrv.StartListen( netsocket.stStream, ai, NIL, ADR( ServerListener ), 0, NIL );

      ReadStream.Stream := ADR( NetReadStream );
      WriteStream.Stream := ADR( NetWriteStream );

      ReaderThread.Test := ADR( SELF );

      //=====

      Host^.StartPhase( L"BufferedStream, 100k * 4 bytes, W/R WAIT, 127/257, 2 T" );

      ReadStream.BufferSize := 257;
      WriteStream.BufferSize := 127;

      WriteOnly();      
      
      //=====

      Host^.StartPhase( L"BufferedStream, 100k * 4 bytes, W/R WAIT, 127/2057 2 T" );

      ReadStream.BufferSize := 2057;
      WriteStream.BufferSize := 127;

      WriteOnly();      
      
      //=====

      Host^.StartPhase( L"BufferedStream, 100k * 4 bytes, W/R WAIT, 257/127, 2 T" );

      ReadStream.BufferSize := 127;
      WriteStream.BufferSize := 257;

      WriteOnly();      
      
      //=====

      Host^.StartPhase( L"BufferedStream, 100k * 4 bytes, W/R WAIT, 2057/127 2 T" );

      ReadStream.BufferSize := 127;
      WriteStream.BufferSize := 2057;

      WriteOnly();      
      
      //=====

      Host^.StartPhase( L"BufferedStream, 100k * 4 bytes, -/- WAIT, 4096/4096 1 T" );

      ReadStream.BufferSize := 4096;
      WriteStream.BufferSize := 4096;

      ReadWrite( FALSE );      

      //=====

      Host^.StartPhase( L"BufferedStream, 10k * 4k bytes, -/- WAIT, 255/257 1 T" );

      ReadStream.BufferSize := 257;
      WriteStream.BufferSize := 255;

      ReadWrite( TRUE );      
      
      //=====

      Host^.StartPhase( L"BufferedStream, 10k * 4k bytes, -/- WAIT, 4096/4096 1 T" );

      ReadStream.BufferSize := 4096;
      WriteStream.BufferSize := 4096;

      ReadWrite( TRUE );      
      
      //=====

      netsrv.StopListenServer( netsocket.stStream, ai );

      WaitForMessages( 100 );

      netinit.Cleanup();
      threadpool.Cleanup();
      SCmsgqueuethread.Cleanup();

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
            IF netpool.pool()^.UndeliveredMessagesPending THEN
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
