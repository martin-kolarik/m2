IMPLEMENTATION MODULE SDAPBridge;

FROM Debug IMPORT
   Assertion;

FROM log IMPORT
   dldError, dldMessage, dldTrace, dldDebug;
  
FROM driver IMPORT
   R;

(*===============================================================================*)

CLASS IMPLEMENTATION CSDAP;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROPERTY OutputQueueCount GET : CARDINAL;
   BEGIN
      RETURN Queue.Count;
   END OutputQueueCount;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROPERTY OutputQueueLength GET : CARDINAL;
   BEGIN
      RETURN QueueLength;
   END OutputQueueLength;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROPERTY OutputQueueLength SET( Value : CARDINAL );
   BEGIN
      QueueLength := MAX2( 2, Value );
   END OutputQueueLength;

(*-------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   VAR
      linie : TDaliLinie;
      Request : TPDaliRequest;
   BEGIN
      IF PollTimer <> NIL THEN
         threadpool.pool()^.Abort( REF PollTimer );
      END;
      WHILE Queue.Dequeue( OUT Request ) DO
         DISPOSE( Request );
      END; // WHILE
      FOR linie := l1 TO l4 DO
         DISPOSE( FileToSend[linie] );
      END; // FOR
   END Dispose;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SetConfiguration( CONST SourceLogger : Log.CLogger; CONST ClientName : ARRAY OF WCHAR; ListenPort : CARDINAL; Server : inetaddr.INETADDR );
   VAR
      LongName : ARRAY [0..255] OF WCHAR;
   BEGIN
      Strings.ConcatW( OUT LongName, L"Dali.", ClientName );
      Logger.SetUpByLogger( SourceLogger );
      Logger.SetLogName( LongName );

      Name.FromOA( ClientName );
      Communicator^.Stop();
      Communicator^.SetDeviceAddress( Server, ListenPort );
   END SetConfiguration;
      
(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Run() : Sync.TAsyncResult;
   VAR
      da : DaliAddress;
      Result : Sync.TAsyncResult;
   BEGIN
      IF Running THEN
         RETURN Sync.arAlreadyPending;
      END;
      Running := TRUE;

      IF PollPeriod > 0 THEN
         threadpool.pool()^.WaitTimeout( PollSink, 0, PollPeriod, FALSE, TRUE, OUT PollTimer );
      END;

      Result := Communicator^.Run();
      IF Result = Sync.arCompleted THEN
         Command( l4, da, cmdInterfaceReset, 0, 0 ); // reset
         Command( l3, da, cmdInterfaceReset, 0, 0 ); // reset
         Command( l2, da, cmdInterfaceReset, 0, 0 ); // reset
         Command( l1, da, cmdInterfaceReset, 0, 0 ); // reset, reset first linie (with ETH interface) as last
      END;
      RETURN Result;
   END Run;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Stop();
   BEGIN
      IF NOT Running THEN
         RETURN;
      END;
      Running := FALSE;
      
      Queue.Clear();
      Communicator^.Stop();

      IF PollTimer <> NIL THEN
         threadpool.pool()^.Abort( REF PollTimer );
      END;
   END Stop;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Set( CONST Data, Value : StringsO.CString ) : Sync.TAsyncResult;
   BEGIN
   END Set;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Ask( CONST Data : StringsO.CString ) : Sync.TAsyncResult;
   BEGIN
   END Ask;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Advise() : Sync.TAsyncResult;
   BEGIN
   END Advise;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Unadvise() : Sync.TAsyncResult;
   BEGIN
   END Unadvise;

(*-------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnHandle( Result : Sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR );
   VAR
      address : DaliBridge.DaliAddress;
      linie : TDaliLinie;
   BEGIN
      IF ProgrammingInProgress OR ( Result <> Sync.arCompleted ) THEN
         RETURN;
      END;
         
      address.Type := DaliBridge.adrSingle;
      address.Address := PollActive;

      Logger.LogSC( dldTrace, logDevPrefix, L"Poll status request for: ", PollActive );

      FOR linie := l1 TO l4 DO // 4 DO
         IF NOT Polled[linie] OR PendingArray[linie][PollActive] THEN
            CONTINUE;
         ELSE
            PendingArray[linie][PollActive] := TRUE;
         END;
         Command( linie, address, DaliBridge.cmdStatus, 0, _PollClientId );
      END; // FOR

      PollActive := PollActive + 1;
      IF PollActive > 63 THEN
         PollActive := 0;
      END;
   END OnHandle;

(*-------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Communicate() : Sync.TAsyncResult;
   VAR
      DaliData : ARRAY [0..1] OF BYTE;
      Long : BOOLEAN := FALSE;
      Result : Sync.TAsyncResult;
      Request : TPDaliRequest;
      Reset : BOOLEAN;
   BEGIN
      IF NOT Queue.Peek( OUT Request ) THEN
         RETURN Sync.arCompleted;
      ELSIF Request^.Pending THEN
         RETURN Sync.arAlreadyPending;
      ELSE
         Request^.Pending := TRUE;
      END;
      
      // prepare Dali packet
      Reset := FALSE;
      IF Request^.Command = cmdInterfaceReset THEN
         DaliData[0] := 0;
         DaliData[1] := 0;
         Reset := TRUE;

         LogRequest( dldDebug, L"SNDr: ", Request, Sync.arCompleted, FALSE, FALSE, FALSE );

      ELSIF Request^.Command = cmdFileItem THEN
         Long := PBYTE( Request^.LongData )^ = 2;
         DaliData[0] := PBYTE( Request^.LongData )@[1]^;
         DaliData[1] := PBYTE( Request^.LongData )@[2]^;

         LogRequest( dldDebug, L"SNDf: ", Request, Sync.arCompleted, FALSE, FALSE, FALSE );

      ELSIF Request^.Command IN specialCommands THEN
         DaliData[0] := BYTE( Request^.Command );
         DaliData[1] := Request^.Data;

         LogRequest( dldDebug, L"SNDs: ", Request, Sync.arCompleted, FALSE, FALSE, TRUE );

      ELSIF Request^.Command = cmdDirect THEN
         DaliData[0] := Request^.Address.TransportAddress AND NOT 01H;
         DaliData[1] := MIN2( 0FEH, Request^.Data );

         LogRequest( dldDebug, L"SNDd: ", Request, Sync.arCompleted, TRUE, FALSE, TRUE );

      ELSE
         DaliData[0] := Request^.Address.TransportAddress OR 01H;
         DaliData[1] := BYTE( Request^.Command );

         LogRequest( dldDebug, L"SNDn: ", Request, Sync.arCompleted, TRUE, FALSE, FALSE );
      END;
      
      Result := Communicator^.SendDaliData( Request^.Linie, DaliData, Reset, NOT Reset AND ( Request^.Command IN respondedCommands ), NOT Reset AND ( Request^.Command IN repeatedCommands ), Long );
      IF Result = Sync.arAlreadyPending THEN // data were not sent, communicator is busy
         Request^.Pending := FALSE; // prepare next send after a tick
         RETURN Sync.arPending;
      ELSIF Result IN Sync.arsStarts THEN
         RETURN Sync.arPending;
      ELSE
         RETURN Result;
      END;
   END Communicate;

(*-------------------------------------------------------------------------------*)

BEGIN
   Running := FALSE;
   EventSink := NIL;
   QueueLength := MAX( CARDINAL );
   QueueSignal.Init( );
   Queue.Consume := ADR( QueueSignal );
FINALLY
   Dispose();
END CSDAP;

(*===============================================================================*)

END SDAPBridge.