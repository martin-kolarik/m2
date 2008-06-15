IMPLEMENTATION MODULE DaliBridge;

FROM log IMPORT
   dldError, dldMessage, dldTrace, dldDebug;
  
FROM driver IMPORT
   R;

IMPORT
   dns,
   inetaddr,
   Log,
   netsocket,
   netsrv,
   Strings,
   Sync,
   Texts,
   threadpool,
   time;

(*===============================================================================*)

CONST
   logPrefix = L"Dali.UDP";
   logProgramPrefix = L"Dali.PRG";
   MSG_START_PROGRAMMING = msghandler.MSG_BASE + 1;

(*===============================================================================*)

TYPE
   TGDECommand = CARD8(
      gdecReset = 0,
      gdecWrite = 6,
      gdecWriteTwice = 7,
      gdecRead = 8
   );
   
   TGDEResponse = CARD8(
      gderReset = 0,
      gderStatus = 1,
      gderRead = 8,
      gderReadFailure = 01CH,
      gderACK = 01DH,
      gderNAK = 01EH,
      gderEvent = 01FH
   );

CLASS CUDPCommunicator( netsrv.AListener ) IMPLEMENTS threadpool.ITimeoutSink;
   CONST
      timerTimeout = 1;
      timerDelay = 2;
   PRIVATE VAR
      Address : inetaddr.INETADDR;
      ListenPort : CARDINAL;
      Socket : netsocket.TPSSocket := NIL;
      TimerSink : threadpool.TPSinkDelegate;
      Timeout : threadpool.TPoolHandle;
      Delay : threadpool.TPoolHandle;
      LastSend : CARDINAL;
      WaitReset : BOOLEAN;
      WaitResponse : BOOLEAN;
   LOCAL VAR
      EventSink : TPICommunicatorSink;
      InterPacketDelay : CARDINAL;
      Logger : Log.TPLogger;
      
   TYPE
      TDaliPacket = ARRAY [0..2] OF BYTE; // 3 bytes DALI

   PUBLIC PROCEDURE SetDeviceAddress( CONST DeviceAddress : inetaddr.INETADDR; LocalListenPort : CARDINAL );
   PUBLIC PROCEDURE Run() : Sync.TAsyncResult;
   PUBLIC PROCEDURE Stop();

   PUBLIC PROCEDURE SendDaliData( Linie : CARDINAL; Data : ARRAY OF BYTE; Reset, ExpectResponse, Repeat : BOOLEAN ) : Sync.TAsyncResult;

   // AListener
   LOCAL VIRTUAL PROCEDURE OnDatagramReceived( CONST ServerSocket : netsocket.TPSSocket ); // stDatagram
   
   // ITimeoutSink
   LOCAL VIRTUAL PROCEDURE OnTimeout( Result : Sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR );
END CUDPCommunicator;

TYPE
   TPCommunicator = POINTER TO CUDPCommunicator;

(*-------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CUDPCommunicator;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SetDeviceAddress( CONST DeviceAddress : inetaddr.INETADDR; LocalListenPort : CARDINAL );
   BEGIN
      Address := DeviceAddress;
      ListenPort := LocalListenPort;
   END SetDeviceAddress;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Run() : Sync.TAsyncResult;
   VAR
      Result : CARDINAL;
      IA : inetaddr.INETADDR;
   BEGIN
      IF Socket <> NIL THEN
         RETURN Sync.arAlreadyPending;
      END;

      Logger^.LogSC( Log.dldTrace, logPrefix, L"Listening on port: ", ListenPort );

      IA.Port := ListenPort;
      Result := netsrv.StartListen( netsocket.stDatagram, IA, NIL, ADR( SELF ), 0, ADR( Socket ));
      IF Result = 0 THEN
      
         SendDaliData( 0, OA( -1, NIL ), TRUE, FALSE, FALSE ); // reset
      
         RETURN Sync.arCompleted;
      ELSE
         Logger^.LogSE( Log.dldError, logPrefix, L"Unable StartListen: ", Result );
         RETURN Sync.arCannotStart;
      END;
   END Run;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Stop();
   BEGIN
      IF Socket = NIL THEN
         RETURN;
      END;
      netsrv.StopListenSocket( REF Socket );
   END Stop;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SendDaliData( Linie : CARDINAL; Data : ARRAY OF BYTE; Reset, ExpectResponse, Repeat : BOOLEAN ) : Sync.TAsyncResult;
   VAR
      i : INTEGER;
      delay : INTEGER;
      SendData : TDaliPacket := TDaliPacket( 0, 0, 0 );
   BEGIN
      IF Socket = NIL THEN
         RETURN Sync.arCannotStart;

      ELSIF WaitReset OR WaitResponse THEN
         RETURN Sync.arAlreadyPending;

      ELSIF InterPacketDelay > 0 THEN
         delay := INTEGER( time.UptimeMS() - LastSend );
         IF ( Delay = NIL ) AND ( delay < INTEGER( InterPacketDelay )) THEN // wait if not waiting yet
            threadpool.pool()^.WaitTimeout( TimerSink, timerDelay, delay, TRUE, TRUE, OUT Timeout );
         END;   
         RETURN Sync.arAlreadyPending;
      END;
      LastSend := time.UptimeMS();

      // copy data to packet
      WaitReset := FALSE;
      WaitResponse := FALSE;
      IF Reset THEN
         WaitReset := TRUE;
         SendData[0] := gdecReset; // reset device
      ELSIF ExpectResponse THEN
         WaitResponse := TRUE;
         SendData[0] := gdecRead; // send, wait 100 ms and receive response
      ELSIF Repeat THEN
         SendData[0] := gdecWriteTwice; // send and repeat only
      ELSE
         SendData[0] := gdecWrite; // send only
      END;
      SendData[0] := SendData[0] OR ( CARD8( Linie ) << 5 ); // address is in three highest bits
      FOR i := 0 TO HIGH( Data ) DO
         SendData[1+i] := Data[i];
      END;
      
      IF Timeout <> NIL THEN
         threadpool.pool()^.Abort( REF Timeout );
      END;
      
      // we have no ACK, we cannot do timeouts, but the code rely on them
      IF Timeout = NIL THEN
         IF WaitReset THEN
            threadpool.pool()^.WaitTimeout( TimerSink, timerTimeout, 10000, TRUE, TRUE, OUT Timeout ); // reset has long timeout
         ELSE
            threadpool.pool()^.WaitTimeout( TimerSink, timerTimeout, 200, TRUE, TRUE, OUT Timeout );
         END;
      END;
      
      RETURN Socket^.SendToOA( OA( 1 + HIGH( Data ), ADR( SendData )), Address );
   END SendDaliData;

(*-------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnDatagramReceived( CONST ServerSocket : netsocket.TPSSocket );
   VAR
      buffer : TDaliPacket;
      dali : TDaliPacket;
      i, l : CARDINAL;
   BEGIN
      IF Timeout <> NIL THEN
         threadpool.pool()^.Abort( REF Timeout );
      END;
   
      ServerSocket^.ReceiveOA( OUT buffer, OUT l );
      IF l < 1 THEN // some damaged data
         Logger^.LogSC( dldMessage, logPrefix, L"Corrupted data received, length: ", l );
         EventSink^.OnDaliData( Sync.arAborted, OA( -1, NIL ));
      ELSIF EventSink = NIL THEN
         // fall down
      ELSE
         CASE TGDEResponse( buffer[0] AND 03FH ) OF
         | gderReset : // OK, switch on
            Logger^.LogS( dldDebug, logPrefix, L"Reset OK" );
         | gderStatus : // OK, status
            Logger^.LogS( dldDebug, logPrefix, L"Status" );
         | gderRead : // OK, response to 8
            Logger^.LogSB( dldDebug, logPrefix, L"Expected device response received: ", ADR( buffer ), l );
         | gderReadFailure : // 008H timeout
            Logger^.LogS( dldDebug, logPrefix, L"Expected device response not received" );
         | gderACK : // ACK
            IF WaitResponse THEN
               Logger^.LogS( dldDebug, logPrefix, L"ACK" );
            ELSE
               Logger^.LogS( dldDebug, logPrefix, L"ACK, but continue waiting for device response" );
               RETURN;
            END;
         | gderNAK : // NAK
            Logger^.LogS( dldDebug, logPrefix, L"NAK" );
         | gderEvent : // OK, event data
            Logger^.LogSB( dldDebug, logPrefix, L"Event data: ", ADR( buffer ), l );
         ELSE
            Logger^.LogSB( dldMessage, logPrefix, L"Strange device response: ", ADR( buffer ), l );
            EventSink^.OnDaliData( Sync.arAlreadyPending, OA( -1, NIL )); // repeat command
            RETURN;
         END;
      
         FOR i := 1 TO l-1 DO
            dali[i-1] := buffer[i];
         END; // FOR

         IF CARD8( buffer[0] ) AND 03FH = 01EH THEN // NAK
            EventSink^.OnDaliData( Sync.arAlreadyPending, OA( l-1, ADR( dali ))); // repeat command
         ELSE
            EventSink^.OnDaliData( Sync.arCompleted, OA( l-1, ADR( dali )));
         END;
      END;
   END OnDatagramReceived;

(*-------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnTimeout( Result : Sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR );
   BEGIN
      IF UserId = timerTimeout THEN
         IF PoolHandle <> Timeout THEN // previous queued timeout is ignored
            RETURN;
         END;
         Timeout := NIL;
      ELSIF UserId = timerDelay THEN
         IF PoolHandle <> Delay THEN // previous queued delay is ignored
            RETURN;
         END;
         Delay := NIL;
      END;
      IF ( Result = Sync.arCompleted ) AND ( EventSink <> NIL ) THEN
         IF UserId = timerTimeout THEN
            EventSink^.OnTimeout();
         ELSE
            EventSink^.OnSendable();
         END;
      END;
   END OnTimeout;

(*-------------------------------------------------------------------------------*)

BEGIN
   ListenPort := 0;

   NEW( TimerSink );
   TimerSink^.TimeoutSink := ADR( SELF );
   Timeout := NIL;
   Delay := NIL;
   LastSend := 0;
   WaitReset := FALSE;
   WaitResponse := FALSE;

   EventSink := NIL;
   InterPacketDelay := 0;
   Logger := NIL;
FINALLY
   IF Timeout <> NIL THEN
      threadpool.pool()^.Abort( REF Timeout );
   END;
   IF Delay <> NIL THEN
      threadpool.pool()^.Abort( REF Delay );
   END;

   IF TimerSink <> NIL THEN
      TimerSink^.TimeoutSink := NIL;
      TimerSink^.Release();
      TimerSink := NIL;
   END;
END CUDPCommunicator;

(*===============================================================================*)

CLASS IMPLEMENTATION DaliAddress;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Address GET : CARDINAL;
   VAR
      c8 : CARD8;
   BEGIN
      IF _Address AND 080H = 0 THEN
         RETURN CARDINAL( _Address >> 1 );
      END;
      c8 := _Address AND 060H;
      IF c8 = 0 THEN // group address
         RETURN CARDINAL(( _Address >> 1 ) AND 0FH );
      ELSIF c8 = 060H THEN // broadcast
         RETURN MAX( CARD8 );
      ELSIF c8 = 020H THEN // special command
         RETURN MAX( CARDINAL );
      ELSE
         ASSERT( FALSE );
         RETURN 0;
      END;
   END Address;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Address SET( Value : CARDINAL );
   VAR
      c8 : CARD8;
   BEGIN
      IF _Address AND 080H = 0 THEN
         _Address := CARD8( Value AND 3FH ) << 1;
         RETURN;
      END;
      c8 := _Address AND 060H;
      IF c8 = 0 THEN // group address
         _Address := ( _Address AND 0E0H ) OR ( CARD8( Value AND 0FH ) << 1 );
      ELSIF c8 = 060H THEN // broadcast
         _Address := MAX( CARD8 );
      ELSIF c8 = 020H THEN // special command
         ASSERT( FALSE );
      END;
   END Address;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROPERTY TransportAddress GET : CARD8;
   BEGIN
      RETURN _Address;
   END TransportAddress;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Type GET : TDaliAddress;
   VAR
      c8 : CARD8;
   BEGIN
      IF _Address AND 080H = 0 THEN
         RETURN adrSingle;
      END;
      c8 := _Address AND 060H;
      IF c8 = 0 THEN // group address
         RETURN adrGroup;
      ELSIF c8 = 060H THEN // broadcast
         RETURN adrAll;
      ELSE
         RETURN adrUnknown;
      END;
   END Type;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Type SET( Value : TDaliAddress );
   BEGIN
      CASE Value OF
      | adrUnknown :
         _Address := 040H;
      | adrSingle :
         _Address := _Address AND NOT 0E0H;
      | adrGroup :
         _Address := _Address AND NOT 0E0H OR 080H;
      | adrAll :
         _Address := MAX( CARD8 );
      END; // CASE
   END Type;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ToString( OUT S : ARRAY OF WCHAR );
   BEGIN
      CASE Type OF
      | adrUnknown :
         S := L"?";
      | adrSingle :
         Strings.FromCARD32W( Address, 10, OUT S );
      | adrGroup :
         Strings.FromCARD32W( Address, 10, OUT S );
         Strings.PrependW( REF S, L"g" );
      | adrAll :
         S := L"all";
      END; // CASE
   END ToString;

(*-------------------------------------------------------------------------------*)

BEGIN
   _Address := 0;
END DaliAddress;

(*===============================================================================*)

CONST
   EXPECTED_RESPONSE = -1;
   DUMMY_RESPONSE = -2;

CLASS IMPLEMENTATION CDaliAddressSeeker;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init();
   BEGIN
      H := 1 << 24 - 1;
      L := 0;
      State := dasSeekFirst;
      SeekRepeatCount := 10;
   END Init;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE GetAddressToCheck( OUT Address : TProgramAddress ) : TRISTATE;
   BEGIN
      IF L > H THEN
         CASE State OF
         | dasSeek, dasCheck :
            State := dasCheck;
            Address.C24 := L;
            RETURN getTRUE;
         | dasFailure :
            RETURN getFALSE;
         | dasSuccess :
            Address.C24 := L;
            RETURN getFOUND;
         END; // CASE
      END;
      IF State = dasSeekFirst THEN
         M := H;
      ELSE
         M := ( L + H ) DIV 2;
      END;
      Address.C24 := M;
      RETURN getTRUE;
   END GetAddressToCheck;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE HandleResponse( Positive : BOOLEAN );
   BEGIN
      CASE State OF
      | dasSeekFirst :
         IF Positive THEN
            State := dasSeek;
         ELSIF SeekRepeatCountElapsed() THEN
            State := dasFailure;
            RETURN; // and continue with the query
         END;
      | dasSeek :
         IF Positive THEN
            H := M - 1;
         ELSE
            L := M + 1;
         END;
      | dasCheck :
         IF Positive THEN
            State := dasSuccess;
         ELSE
            State := dasFailure;
         END;
      END;
      SeekRepeatCount := 10; // reset counter
   END HandleResponse;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE OnStart() : BOOLEAN;
   BEGIN
      RETURN State = dasSeekFirst;
   END OnStart;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SeekRepeatCountElapsed() : BOOLEAN;
   BEGIN
      IF SeekRepeatCount = 0 THEN
         RETURN TRUE;
      END;
      DEC( SeekRepeatCount );
      RETURN FALSE;
   END SeekRepeatCountElapsed;

(*-------------------------------------------------------------------------------*)

BEGIN
   H := 0;
   L := 0;
   M := 0;
   State := dasSeekFirst;
   SeekRepeatCount := 0;
END CDaliAddressSeeker;

(*===============================================================================*)

CLASS IMPLEMENTATION CDaliAddressProgrammer;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROPERTY CurrentLongAddress GET : TProgramAddress;
   VAR
      Address : TProgramAddress;
   BEGIN
      Address.C24 := CurrentSelected;
      RETURN Address;
   END CurrentLongAddress;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROPERTY CurrentShortAddress GET : CARDINAL;
   BEGIN
      RETURN CurrentShort;
   END CurrentShortAddress;
      
(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE InitProgramming();
   BEGIN
      Current := addressesNone;
      ReaddressMode := FALSE;
      State := dapInit;
      CurrentSelected := 0;
      CurrentShort := 0;
      HaveAddresses := FALSE;
   END InitProgramming;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE InitReaddressing( Readdress : TAddresses ) : BOOLEAN;
   BEGIN
      IF NOT HaveAddresses THEN
         RETURN FALSE;
      END;
      ReaddressMode := TRUE;
      SELF.Readdress := Readdress;
      State := dapInit;
      RETURN TRUE;
   END InitReaddressing;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE WhatNext() : TCommand;
   BEGIN
      RETURN State;
   END WhatNext;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE HandleResponse( Positive : BOOLEAN; Data : INTEGER );
   VAR
      DA : DaliAddress;
   BEGIN
      CASE State OF
      | dapInit :
         IF Positive THEN
            IF ReaddressMode THEN
               CurrentSelected := Current[Readdress[CurrentShort]];
               IF CurrentSelected = -1 THEN
                  State := dapFinish;
               ELSE
                  State := dapSelectOne;
               END;
            ELSE
               State := dapRandomize;
            END;
         END;
      | dapRandomize :
         IF Positive THEN
            State := dapStartSeek;
         ELSE
            State := dapInit;
         END;
      | dapStartSeek :
         State := dapSeekOne;
      | dapSeekOne :
         IF Positive THEN
            Current[CurrentShort] := Data;
            CurrentSelected := Data;
            State := dapProgramOne;
         ELSE
            State := dapFinish;
         END;
      | dapSelectOne :
         IF Positive THEN
            State := dapProgramOne;
         END;   
      | dapProgramOne :
         IF Positive THEN
            State := dapCheckOne;
         END;
      | dapCheckOne :
         State := dapDisableOne;
         IF NOT Positive THEN
            RETURN;
         END;
         DA.Type := DaliBridge.adrSingle;
         DA.Address := CurrentShort;
         IF INTEGER( DA.TransportAddress OR 01H ) <> Data THEN
            Logger^.LogSC( dldMessage, logProgramPrefix, L"Check address failed for: ", CurrentShort );
            Logger^.LogSC( dldMessage, logProgramPrefix, L"                received: ", Data );
            RETURN;
         END;
         IF ReaddressMode THEN
            New[CurrentShort] := CurrentSelected;
         END;
         INC( CurrentShort );
         IF ReaddressMode THEN
            CurrentSelected := Current[Readdress[CurrentShort]];
            IF CurrentSelected = -1 THEN
               State := dapFinish;
            ELSE
               State := dapSelectOne;
            END;
         ELSE
            State := dapShowOne; // CurrentSelected is left
         END;
      | dapShowOne :
         IF Positive THEN
            State := dapDisableOne;
         END;
      | dapDisableOne :
         IF Positive THEN
            State := dapStartSeek;
         END;
      | dapFinish :
         IF Positive THEN
            IF ReaddressMode THEN
               Current := New;
            END;
         END;
         State := dapEnd;
      END; // CASE
   END HandleResponse;

(*-------------------------------------------------------------------------------*)

BEGIN
   Current := addressesNone;
   New := addressesNone;
   Readdress := addressesNone;
   State := dapInit;
   CurrentSelected := 0;
   CurrentShort := 0;
   ReaddressMode := FALSE;
   HaveAddresses := FALSE;
   Logger := NIL;
END CDaliAddressProgrammer;

(*===============================================================================*)

CLASS DaliRequest;
   LOCAL VAR
      Pending : BOOLEAN;
      Linie : CARDINAL;
      ClientId : PTR;
      Address : DaliAddress;
      Command : TDaliCommand;
      Data : CARD8;
END DaliRequest;

(*-------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION DaliRequest;
BEGIN
   Pending := FALSE;
   Linie := 0;
   ClientId := 0;
   Command := cmdOff;
   Data := 0;
END DaliRequest;

(*===============================================================================*)

CLASS IMPLEMENTATION CDali;

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
      Request : POINTER TO DaliRequest;
   BEGIN
      WHILE Queue.Dequeue( OUT Request ) DO
         DISPOSE( Request );
      END; // WHILE
   END Dispose;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE LoadConfiguration( CONST ClientName, ParFilePath : ARRAY OF WCHAR; CONST INI : INIFile.CINIFile; CONST logger : log.CLogger ) : BOOLEAN;
   CONST
      snInterface        = L"interface";
         knListenPort    = L"listen_port";
         knDeviceAddress = L"device_address";
   VAR
      Addr : ARRAY [0..0] OF inetaddr.INETADDR;
      cs : StringsO.CString;
      line : CARDINAL;
      listenPort : CARDINAL;
   BEGIN
      IF NOT INI.SetSection( snInterface ) THEN
         logger.LogFilePos( log.dlcError, ClientName, ParFilePath, OAsz( R()^[ Texts._MissingInterfaceSection ] ), 0, 0 );
         RETURN FALSE;
      END;

      // listen port
      IF NOT INI.GetKeyInt( knListenPort, OUT line, OUT listenPort ) THEN
         logger.LogFilePos( log.dlcError, ClientName, ParFilePath, OAsz( R()^[ Texts._BadOrMissingListenPort ] ), line, 0 );
         RETURN FALSE;
      END;
      
      // device address
      IF NOT INI.GetKeyStr( knDeviceAddress, OUT line, OUT cs ) THEN
         logger.LogFilePos( log.dlcError, ClientName, ParFilePath, OAsz( R()^[ Texts._MissingDeviceAddress ] ), line, 0 );
         RETURN FALSE;
      ELSIF NOT dns.NameToAddressWait( OA( cs.Length-1, cs.rawData ), listenPort, 2000, OUT Addr ) THEN
         logger.LogFilePos( log.dlcError, ClientName, ParFilePath, OAsz( R()^[ Texts._UnableToGetDeviceAddress ] ), line, 0 );
         RETURN FALSE;
      END;

      Communicator^.SetDeviceAddress( Addr[0], listenPort );
   
      RETURN TRUE;
   END LoadConfiguration;
      
(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Run() : Sync.TAsyncResult;
   BEGIN
      RETURN Communicator^.Run();
   END Run;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Stop();
   BEGIN
      Communicator^.Stop();
   END Stop;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Command( Linie : CARDINAL; CONST daliAddress : DaliAddress; _Command : TDaliCommand; Data : CARD8; CONST ClientId : PTR ) : Sync.TAsyncResult;
   BEGIN
      IF Programming THEN
         Logger.LogSC( dldMessage, logPrefix, L"Unable to send command in programming mode: ", CARDINAL( _Command ));
         RETURN Sync.arCannotStart;
      ELSE
         RETURN FeedCommand( Linie, TPDaliAddress( ADR( daliAddress )), _Command, Data, ClientId );
      END;
   END Command;
   
(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE StartProgramming( Linie : CARDINAL );
   VAR
      Msg : msghandler.Message;
   BEGIN
      IF Programming THEN
         RETURN;
      END;

      Programmer.InitProgramming();
      Programming := TRUE;
      ProgrammedLinie := Linie;

      Msg.Message := MSG_START_PROGRAMMING;
      Message( Msg, msghandler.delDefault, NIL );
   END StartProgramming;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Readdress( Linie : CARDINAL; Readdressed : TAddresses ) : BOOLEAN;
   VAR
      Msg : msghandler.Message;
   BEGIN
      IF Programming OR NOT Programmer.InitReaddressing( Readdressed ) THEN
         RETURN FALSE;
      END;

      Programming := TRUE;
      ProgrammedLinie := Linie;

      Msg.Message := MSG_START_PROGRAMMING;
      Message( Msg, msghandler.delDefault, NIL );
      RETURN TRUE;
   END Readdress;
   
(*-------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnMessage( CONST Message : msghandler.IMessage; OUT Result : PTR ) : BOOLEAN;
   BEGIN
      CASE Message.Message OF
      | msgqueue.MSG_PROCESS_QUEUE :
         Logger.LogS( dldDebug, logPrefix, L"Start Communicate after SWITCH" );
         Communicate();
      | MSG_START_PROGRAMMING :
         ProgrammingStep();
      ELSE
         RETURN FALSE;
      END;
      RETURN TRUE;
   END OnMessage;

(*-------------------------------------------------------------------------------*)

   // ICommunicationSink -- in thread
   LOCAL VIRTUAL PROCEDURE OnSendable();
   BEGIN
      Logger.LogS( dldDebug, logPrefix, L"Communicate after DELAY" );
      Communicate();
   END OnSendable;

(*-------------------------------------------------------------------------------*)

   // ICommunicationSink -- in thread
   LOCAL VIRTUAL PROCEDURE OnTimeout();
   BEGIN
      Logger.LogS( dldTrace, logPrefix, L"Receive response TIMEOUT" );
      OnDaliData( Sync.arTimeout, OA( -1, NIL ));
   END OnTimeout;

(*-------------------------------------------------------------------------------*)

   // ICommunicationSink -- in thread
   LOCAL VIRTUAL PROCEDURE OnDaliData( Result : Sync.TAsyncResult; Data : ARRAY OF BYTE );
   VAR
      Response : CARD8 := 0;
      Request : POINTER TO DaliRequest;
   BEGIN
      IF Queue.Peek( OUT Request ) THEN
         IF Result = Sync.arAlreadyPending THEN
            Request^.Pending := FALSE; // allow new send
         ELSE
            Queue.Dequeue( OUT Request );

            IF Result = Sync.arCompleted THEN
               IF ( Request^.Command <> cmdCurrentLevel ) OR ( Data[0] < 0FFH ) THEN
                  Response := Data[0];
               ELSE
                  Response := 0;
               END;
            END;            

            IF Programming THEN
               Logger.LogSC( dldDebug, logPrefix, L"Completed programming command: ", CARDINAL( Request^.Command ));
               Logger.LogSC( dldDebug, logPrefix, L"                    for linie: ", Request^.Linie );
               Logger.LogSR( dldDebug, logPrefix, L"                       result: ", Result );

               IF Result <> Sync.arCompleted THEN // arTimeout, etc.
                  Logger.LogSC( dldMessage, logProgramPrefix, L"Programming stopped, receive error occured, result: ", CARDINAL( Result ));

                  Programming := FALSE; // kill

               ELSIF Request^.ClientId = EXPECTED_RESPONSE THEN
                  IF Programmer.WhatNext() <> dapSeekOne THEN
                     Programmer.HandleResponse( TRUE, INTEGER( Response ));
                  ELSE
                     Seeker.HandleResponse( Response <> 0 );
                  END;
                  ProgrammingStep();

               END;

            ELSIF EventSink <> NIL THEN

               Logger.LogSC( dldDebug, logPrefix, L"Completed command: ", CARDINAL( Request^.Command ));
               Logger.LogSC( dldDebug, logPrefix, L"        for linie: ", Request^.Linie );
               Logger.LogSC( dldDebug, logPrefix, L"      for address: ", Request^.Address.Address );
               Logger.LogSR( dldDebug, logPrefix, L"           result: ", Result );

               EventSink^.OnCompletion( Result, Request^.Command, Request^.ClientId, Request^.Linie, Request^.Address, Response );
            END;
            DISPOSE( Request );
            
            // flush queue
            WHILE Queue.Count > QueueLength DO
               Queue.Dequeue( OUT Request );
               DISPOSE( Request );
            END; // WHILE

         END;
         
      ELSE
         Logger.LogS( dldMessage, logPrefix, L"Data received when nothing is expected" );
      END; // IF something in the Queue
         
      Communicate();
   END OnDaliData;

(*-------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE FeedCommand( Linie : CARDINAL; daliAddress : TPDaliAddress; _Command : TDaliCommand; Data : CARD8; CONST ClientId : PTR ) : Sync.TAsyncResult;
   VAR
      Request : POINTER TO DaliRequest;
   BEGIN
      Logger.LogSC( dldDebug, logPrefix, L"Start command: ", CARDINAL( _Command ));
      Logger.LogSC( dldDebug, logPrefix, L"    for linie: ", Linie );
      IF daliAddress <> NIL THEN
         Logger.LogSC( dldDebug, logPrefix, L"  for address: ", daliAddress^.Address );
      END;

      NEW( Request );
      Request^.Linie := Linie;
      Request^.ClientId := ClientId;
      IF daliAddress <> NIL THEN
         Request^.Address := daliAddress^;
      END;
      Request^.Command := _Command;
      Request^.Data := Data;
      Queue.Enqueue( Request );
      
      RETURN Sync.arPending; // all processing is moved into thread
   END FeedCommand;

(*-------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Communicate() : Sync.TAsyncResult;
   VAR
      DaliData : ARRAY [0..1] OF BYTE;
      Result : Sync.TAsyncResult;
      Request : POINTER TO DaliRequest;
   BEGIN
      IF NOT Queue.Peek( OUT Request ) THEN
         RETURN Sync.arCompleted;
      ELSIF Request^.Pending THEN
         RETURN Sync.arAlreadyPending;
      ELSE
         Request^.Pending := TRUE;
      END;
      
      // prepare Dali packet
      IF Request^.Command IN specialCommands THEN
         DaliData[0] := BYTE( Request^.Command );
         DaliData[1] := Request^.Data;
      ELSIF Request^.Command = cmdDirect THEN
         DaliData[0] := Request^.Address.TransportAddress AND NOT 01H;
         DaliData[1] := MIN2( 0FEH, Request^.Data );
      ELSE
         DaliData[0] := Request^.Address.TransportAddress OR 01H;
         DaliData[1] := BYTE( Request^.Command );
      END;
      
      Result := Communicator^.SendDaliData( Request^.Linie, DaliData, FALSE, Request^.Command IN respondedCommands, Request^.Command IN repeatedCommands );
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

   PRIVATE PROCEDURE ProgrammingStep();
   VAR
      Address : TProgramAddress;
      DA : DaliAddress;
   BEGIN
      LOOP
         CASE Programmer.WhatNext() OF
         | dapInit :
            FeedCommand( ProgrammedLinie, NIL, cmdTerminate, 0, DUMMY_RESPONSE );

            DA.Type := DaliBridge.adrAll;
            FeedCommand( ProgrammedLinie, ADR( DA ), cmdMin, 0, DUMMY_RESPONSE );
            FeedCommand( ProgrammedLinie, NIL, cmdLoadDTR, 0FFH, DUMMY_RESPONSE );
            FeedCommand( ProgrammedLinie, ADR( DA ), cmdDTRToAddress, 0FFH, DUMMY_RESPONSE );

            FeedCommand( ProgrammedLinie, NIL, cmdInitialize, 0FFH, EXPECTED_RESPONSE );
            EXIT;

         | dapRandomize :
            FeedCommand( ProgrammedLinie, NIL, cmdRandomize, 0, EXPECTED_RESPONSE );
            EXIT;

         | dapStartSeek :
            Seeker.Init();
            LastProgrammedAddress.C24 := 0;
            Programmer.HandleResponse( TRUE, 0 );

         | dapSeekOne :
            CASE Seeker.GetAddressToCheck( OUT Address ) OF
            | getTRUE :
               IF Address.H8 <> LastProgrammedAddress.H8 THEN
                  FeedCommand( ProgrammedLinie, NIL, cmdStoreH, Address.H8, DUMMY_RESPONSE );
               END;
               IF Address.M8 <> LastProgrammedAddress.M8 THEN
                  FeedCommand( ProgrammedLinie, NIL, cmdStoreM, Address.M8, DUMMY_RESPONSE );
               END;
               IF Address.L8 <> LastProgrammedAddress.L8 THEN
                  FeedCommand( ProgrammedLinie, NIL, cmdStoreL, Address.L8, DUMMY_RESPONSE );
               END;
               FeedCommand( ProgrammedLinie, NIL, cmdCompare, 0, EXPECTED_RESPONSE );

               LastProgrammedAddress := Address;
               EXIT;
            | getFALSE :
               Logger.LogS( dldMessage, logProgramPrefix, L"Programming stopped, no next device found" );
               Programmer.HandleResponse( FALSE, 0 );
            | getFOUND :
               Logger.LogSC( dldTrace, logProgramPrefix, L"Found device: ", Address.C24 );
               Programmer.HandleResponse( TRUE, Address.C24 );
            END;
            
         | dapSelectOne :
            Address := Programmer.CurrentLongAddress;
            FeedCommand( ProgrammedLinie, NIL, cmdStoreH, Address.H8, DUMMY_RESPONSE );
            FeedCommand( ProgrammedLinie, NIL, cmdStoreM, Address.M8, DUMMY_RESPONSE );
            FeedCommand( ProgrammedLinie, NIL, cmdStoreL, Address.L8, EXPECTED_RESPONSE );
            EXIT;

         | dapProgramOne :
            Logger.LogSC( dldTrace, logProgramPrefix, L"Programm address: ", Programmer.CurrentShortAddress );
            DA.Type := DaliBridge.adrSingle;
            DA.Address := Programmer.CurrentShortAddress;
            FeedCommand( ProgrammedLinie, NIL, cmdSetAddress, DA.TransportAddress OR 01H, EXPECTED_RESPONSE );
            EXIT;

         | dapCheckOne :
            Logger.LogSC( dldTrace, logProgramPrefix, L"Check address: ", Programmer.CurrentShortAddress );
            FeedCommand( ProgrammedLinie, NIL, cmdGetAddress, 0, EXPECTED_RESPONSE );
            EXIT;

         | dapShowOne :
            Logger.LogSC( dldTrace, logProgramPrefix, L"Address checked: ", Programmer.CurrentShortAddress-1 );
            DA.Type := DaliBridge.adrSingle;
            DA.Address := Programmer.CurrentShortAddress-1; // dapCheckOne moved address forward
            FeedCommand( ProgrammedLinie, ADR( DA ), cmdMax, 0, EXPECTED_RESPONSE );
            EXIT;

         | dapDisableOne :
            FeedCommand( ProgrammedLinie, NIL, cmdWithdraw, 0, EXPECTED_RESPONSE );
            EXIT;

         | dapFinish :
            FeedCommand( ProgrammedLinie, NIL, cmdTerminate, 0, EXPECTED_RESPONSE );
            EXIT;

         | dapEnd :
            Programming := FALSE;
            EXIT;
         END; // CASE
      END; // LOOP
   END ProgrammingStep;

(*-------------------------------------------------------------------------------*)

BEGIN
   Programming := FALSE;
   ProgrammedLinie := 0;
   Programmer.Logger := ADR( Logger );
   Communicator := NEW( CUDPCommunicator );
   Communicator^.EventSink := TPICommunicatorSink( ADR( SELF ));
   Communicator^.Logger := ADR( Logger );
   EventSink := NIL;
   QueueLength := MAX( CARDINAL );
   Queue.Consumer := ADR( SELF );
FINALLY
   IF Communicator <> NIL THEN
      Communicator^.Release();
      Communicator := NIL;
   END;
   Dispose();
END CDali;

(*===============================================================================*)

END DaliBridge.