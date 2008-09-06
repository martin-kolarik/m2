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
   StorageO,
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
   
   TGDEResponse = (
      gderReset = 0,
      gderStatus = 1,
      gderRead = 8,
      gderFrameError = 01BH,
      gderReadFailure = 01CH,
      gderACK = 01DH,
      gderNAK = 01EH,
      gderEvent = 01FH
   );
   
   TGDEResponseLength = ARRAY TGDEResponse OF CARDINAL;
   
CONST
   gderl = TGDEResponseLength(
      3, 3, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 3
   );

CLASS CUDPCommunicator( netsrv.AListener ) IMPLEMENTS threadpool.ITimeoutSink;
   CONST
      timerTimeout = 1;
      timerDelay = 2;
   PRIVATE VAR
      Address : inetaddr.INETADDR;
      Buffer : StorageO.CMemoryBuffer;
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
            threadpool.pool()^.WaitTimeout( TimerSink, timerDelay, delay, TRUE, TRUE, OUT Delay );
            RETURN Sync.arAlreadyPending;
         END;   
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
      
      IF Reset THEN
         RETURN Socket^.SendToOA( OA( 2, ADR( SendData )), Address );
      ELSE
         RETURN Socket^.SendToOA( OA( 1 + HIGH( Data ), ADR( SendData )), Address );
      END;
   END SendDaliData;

(*-------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnDatagramReceived( CONST ServerSocket : netsocket.TPSSocket );
   VAR
      dali : TDaliPacket;
      gdeResponse : TGDEResponse;
      i, l : CARDINAL;
      leaveTimeout : BOOLEAN;
      packet : ARRAY [0..15] OF BYTE;
      processResult : Sync.TAsyncResult := Sync.arNoData;
   BEGIN

      ServerSocket^.ReceiveOA( OUT packet, OUT l ); // receive, possibly not whole datagram
      IF l < 1 THEN // filter damaged data
         Logger^.LogSC( dldMessage, logPrefix, L"Corrupted data received, length: ", l );
         EventSink^.OnDaliData( Sync.arAborted, OA( -1, NIL ));

      ELSIF EventSink = NIL THEN // and filter data for nobody
         Logger^.LogS( dldMessage, logPrefix, L"Data received, but nobody listens" );
         RETURN;
      END;

      Buffer.AppendOA( OA( l-1, ADR( packet ))); // store correct data in buffer
      
      LOOP // process buffer
      
         IF Buffer.Empty THEN
            EXIT;
         END;
         gdeResponse := TGDEResponse( Buffer[0] AND 03FH );
         IF Buffer.Length < gderl[ gdeResponse ] THEN // not all data for command were received, wait for more
            EXIT;
         ELSE
            l := gderl[ gdeResponse ];
         END;
         
         leaveTimeout := FALSE;
         CASE gdeResponse OF
         | gderReset : // OK, switch on
            Logger^.LogS( dldDebug, logPrefix, L"res: Reset OK" );
         | gderStatus : // OK, status
            Logger^.LogS( dldTrace, logPrefix, L"res: Reset/Status response" );
            WaitReset := FALSE;
         | gderRead : // OK, response to 8
            Logger^.LogSB( dldDebug, logPrefix, L"res: Expected device response received: ", Buffer.Data, l );
            processResult := Sync.arCompleted;
            WaitResponse := FALSE;
         | gderFrameError : // 008H frame link error
            Logger^.LogS( dldTrace, logPrefix, L"res: Frame link error when waiting device response" );
            processResult := Sync.arAlreadyPending;
            WaitResponse := FALSE;
         | gderReadFailure : // 008H timeout
            Logger^.LogS( dldDebug, logPrefix, L"res: Expected device response not received" );
            processResult := Sync.arPartCompleted;
            WaitResponse := FALSE;
         | gderACK : // ACK
            IF WaitResponse OR WaitReset THEN
               Logger^.LogS( dldDebug, logPrefix, L"res: ACK, but continue waiting for device response" );
               leaveTimeout := TRUE;
            ELSE
               Logger^.LogS( dldDebug, logPrefix, L"res: ACK" );
               processResult := Sync.arCompleted;
            END;
         | gderNAK : // NAK
            Logger^.LogS( dldTrace, logPrefix, L"res: NAK" );
            processResult := Sync.arAlreadyPending; // repeat command
         | gderEvent : // OK, event data
            Logger^.LogSB( dldDebug, logPrefix, L"EVT: Event data: ", Buffer.Data, l );
            processResult := Sync.arCompleted;
         ELSE
            Logger^.LogSB( dldMessage, logPrefix, L"res: Strange device response: ", Buffer.Data, l );
            processResult := Sync.arAlreadyPending; // repeat command
         END;
         
         IF ( Timeout <> NIL ) AND NOT leaveTimeout THEN
            threadpool.pool()^.Abort( REF Timeout );
         END;
      
         IF l = 1 THEN
            l := 0; // no data in packet, mostly used for cmdRead: 08 returns either response either timeout.
         ELSIF processResult = Sync.arCompleted THEN // copy buffer to dali data packet
            FOR i := 1 TO l-1 DO
               dali[i-1] := Buffer[i];
            END; // FOR
         ELSE
            l := 0;
         END;

         IF processResult <> Sync.arNoData THEN
            EventSink^.OnDaliData( processResult, OA( l-1, ADR( dali )));

         ELSIF ( gdeResponse = gderReset ) OR ( gdeResponse = gderStatus ) THEN
            EventSink^.OnSendable();
         END;

         Buffer.RemoveStart( gderl[ gdeResponse ] );
      END; // LOOP
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
      IF Result = Sync.arCompleted THEN
         WaitReset := FALSE;
         WaitResponse := FALSE;
         Buffer.Clear();

         IF EventSink <> NIL THEN
            IF UserId = timerTimeout THEN
               EventSink^.OnTimeout();
            ELSE
               EventSink^.OnSendable();
            END;
         END;

      END;
   END OnTimeout;

(*-------------------------------------------------------------------------------*)

BEGIN
   ListenPort := 0;
   Buffer.Size := 16;

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
      IF State = dasFailure THEN
         RETURN getFALSE;
      END;
      IF L > H THEN
         CASE State OF
         | dasSeek, dasCheck :
            State := dasCheck;
            Address.C24 := L;
            RETURN getTRUE;
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
      IF Pairing THEN
         IF CurrentShort > 63 THEN
            RETURN -1;
         ELSIF Current[CurrentShort] = -1 THEN
            RETURN -1;
         ELSE
            RETURN CurrentShort;
         END;
      ELSIF ReaddressMode THEN
         IF CurrentShort > 63 THEN
            RETURN -1;
         ELSE
            RETURN Readdress[CurrentShort];
         END;
      ELSE
         RETURN CurrentShort;
      END;
   END CurrentShortAddress;
      
(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE InitProgramming( PreserveExisting : BOOLEAN ) : BOOLEAN;
   BEGIN
      Current := addressesNone;
      ReaddressMode := FALSE;
      SELF.PreserveExisting := PreserveExisting;
      SELF.Pairing := PreserveExisting;

      IF NOT Pairing THEN
         State := dapInitFull;
         HaveAddresses := FALSE;
      ELSIF HaveAddresses THEN
         State := dapInitPairing;
      ELSE
         RETURN FALSE;
      END;
      CurrentShort := 0;
      CurrentSelected := 0;
      
      RETURN TRUE;
   END InitProgramming;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE InitReaddressing( Readdress : TAddresses ) : BOOLEAN;
   BEGIN
      IF NOT HaveAddresses THEN
         RETURN FALSE;
      END;
      ReaddressMode := TRUE;
      SELF.Readdress := Readdress;
      SELF.PreserveExisting := FALSE;
      SELF.Pairing := FALSE;

      State := dapInitReaddressing;
      CurrentShort := 0;
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
      i : CARDINAL;
      Next : CARDINAL;
   BEGIN
      CASE State OF
      | dapInitFull :
         IF Positive THEN
            State := dapRandomize;
         END;
      | dapInitPairing :
         IF Positive THEN
            State := dapCheckOne;
         END;
      | dapInitPartial:
         IF Positive THEN
            State := dapRandomize;
         END;
      | dapInitReaddressing :
         IF Positive THEN
            Next := CurrentShortAddress;
            IF Next = -1 THEN
               Failed := FALSE;
               State := dapFinish;
            ELSE
               CurrentSelected := Current[CurrentShort];
               State := dapSelectOne;
            END;
         END;
      | dapRandomize :
         IF Positive THEN
            State := dapStartSeek;
         ELSE
            State := dapInitPartial;
         END;
      | dapStartSeek :
         State := dapSeekOne;
      | dapSeekOne :
         IF Positive THEN
            Current[CurrentShort] := Data;
            CurrentSelected := Data;
            State := dapProgramOne;
         ELSE
            Failed := FALSE;
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
         IF Pairing THEN
            State := dapFinish; // state is set always for Pairing, but for sure:
         ELSIF ReaddressMode THEN
            Failed := TRUE;
            State := dapFinish;
         ELSE
            State := dapDisableOne;
         END;

         // check response
         IF Positive THEN
            // fall down
         ELSIF Pairing THEN // the device with address is not found, remember this
            Current[CurrentShort] := -1;
         ELSE // error
            Logger^.LogSC( dldMessage, logProgramPrefix, L"Check address failed for: ", CurrentShortAddress );
            RETURN;
         END;
         
         IF PreserveExisting THEN
            INC( CurrentShort );
            IF CurrentShort >= HIGH( New ) THEN
               // we are over
            ELSIF NOT Pairing THEN // we are programming, get address corresponding to some hole in addresses
               FOR i := CurrentShort TO HIGH( New ) DO
                  IF New[i] = -1 THEN // we found hole in addresses
                     CurrentShort := i;
                     EXIT;
                  END;
               END;
            END;
         ELSIF ReaddressMode THEN
            New[CurrentShortAddress] := CurrentSelected;
            INC( CurrentShort );
         ELSE
            INC( CurrentShort );
         END;

         IF Pairing THEN
            Next := CurrentShortAddress;
            IF Next = -1 THEN // everything scanned, try to assign address to new devices
               New := Current; // remember existing, only unknown will be filled
               Pairing := FALSE;
               State := dapInitPartial; // continue with addressing of new devices in new loop
            ELSE
               State := dapCheckOne;
            END;
         ELSIF ReaddressMode THEN
            Next := CurrentShortAddress;
            IF Next = -1 THEN
               Failed := FALSE;
               State := dapFinish;
            ELSE
               CurrentSelected := Current[CurrentShort];
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
            HaveAddresses := TRUE;
         END;
         State := dapEnd;
      END; // CASE
   END HandleResponse;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE GetLongAddresses( OUT Addresses : TAddresses ) : BOOLEAN;
   BEGIN
      IF HaveAddresses THEN
         Addresses := Current;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END GetLongAddresses;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE LoadLongAddresses( CONST Addresses : TAddresses );
   BEGIN
      Current := Addresses;
      HaveAddresses := TRUE;
   END LoadLongAddresses;

(*-------------------------------------------------------------------------------*)

BEGIN
   Current := addressesNone;
   New := addressesNone;
   Readdress := addressesNone;
   State := dapInitFull;
   CurrentSelected := 0;
   CurrentShort := 0;
   ReaddressMode := FALSE;
   PreserveExisting := FALSE;
   Pairing := FALSE;
   Failed := FALSE;
   HaveAddresses := FALSE;
   Logger := NIL;
END CDaliAddressProgrammer;

(*===============================================================================*)

TYPE
   TPDaliRequest = POINTER TO DaliRequest;

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

   PUBLIC PROPERTY ProgrammingInProgress GET : BOOLEAN;
   BEGIN
      RETURN Programming;
   END ProgrammingInProgress;

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
      Request : TPDaliRequest;
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

   PUBLIC PROCEDURE StartProgramming( Linie : CARDINAL; PreserveExisting : BOOLEAN ) : BOOLEAN;
   VAR
      Msg : msghandler.Message;
   BEGIN
      IF Programming OR NOT Programmer.InitProgramming( PreserveExisting ) THEN
         RETURN FALSE;
      END;

      Programming := TRUE;
      ProgrammedLinie := Linie;

      Msg.Message := MSG_START_PROGRAMMING;
      Message( Msg, msghandler.delDefault, NIL );
      
      RETURN TRUE;
   END StartProgramming;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Readdress( Linie : CARDINAL; CONST Readdressed : TAddresses ) : BOOLEAN;
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

   PUBLIC PROCEDURE LoadLongAddresses( CONST Addresses : TAddresses );
   BEGIN
      Programmer.LoadLongAddresses( Addresses );
   END LoadLongAddresses;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE GetLongAddresses( OUT Addresses : TAddresses ) : BOOLEAN;
   BEGIN
      RETURN Programmer.GetLongAddresses( OUT Addresses );
   END GetLongAddresses;

(*-------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnMessage( CONST Message : msghandler.IMessage; OUT Result : PTR ) : BOOLEAN;
   BEGIN
      CASE Message.Message OF
      | msgqueue.MSG_PROCESS_QUEUE :
         Logger.LogS( dldDebug, logPrefix, L"CTR: Communicate after SWITCH" );
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
      Logger.LogS( dldDebug, logPrefix, L"CTR: Communicate after DELAY/RESET" );
      Communicate();
   END OnSendable;

(*-------------------------------------------------------------------------------*)

   // ICommunicationSink -- in thread
   LOCAL VIRTUAL PROCEDURE OnTimeout();
   BEGIN
      Logger.LogS( dldTrace, logPrefix, L"CTR: Receive response TIMEOUT" );
      OnDaliData( Sync.arTimeout, OA( -1, NIL ));
   END OnTimeout;

(*-------------------------------------------------------------------------------*)

   // ICommunicationSink -- in thread
   LOCAL VIRTUAL PROCEDURE OnDaliData( Result : Sync.TAsyncResult; Data : ARRAY OF BYTE );
   VAR
      CurrentNext : TCommand;
      Response : CARD8 := 0;
      Request : TPDaliRequest;
   BEGIN
      IF Queue.Peek( OUT Request ) THEN
         IF Result = Sync.arAlreadyPending THEN
            Request^.Pending := FALSE; // allow new send
         ELSE
            Queue.Dequeue( OUT Request );

            IF Result = Sync.arCompleted THEN
               IF HIGH( Data ) = -1 THEN
                  Response := 0;
               ELSIF ( Request^.Command <> cmdCurrentLevel ) OR ( Data[0] < 0FFH ) THEN
                  Response := Data[0];
               ELSE
                  Response := 0;
               END;
            END;            

            IF Programming THEN
               LogRequest( dldDebug, L"FIN: ", Request, Result, FALSE, TRUE, FALSE );

               IF Result NOT IN Sync.arsCompletions THEN // arTimeout, etc.
                  Logger.LogSC( dldMessage, logProgramPrefix, L"Programming stopped, result: ", CARDINAL( Result ));

                  Programming := FALSE; // kill
                  IF EventSink <> NIL THEN
                     EventSink^.OnProgrammingStopped( Sync.arAborted, ProgrammedLinie );
                  END;

               ELSIF Request^.ClientId = EXPECTED_RESPONSE THEN
                  CurrentNext := Programmer.WhatNext();
                  IF CurrentNext = dapSeekOne THEN
                     Seeker.HandleResponse( Result = Sync.arCompleted );
                  ELSIF CurrentNext <> dapCheckOne THEN                           
                     Programmer.HandleResponse( TRUE, INTEGER( Response ));
                  ELSE
                     Programmer.HandleResponse( Result = Sync.arCompleted, INTEGER( Response ));
                  END;
                  ProgrammingStep();

               END;

            ELSIF EventSink <> NIL THEN
               LogRequest( dldDebug, L"FIN: ", Request, Result, TRUE, TRUE, FALSE );

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
         Logger.LogS( dldMessage, logPrefix, L"CTR: Data received when nothing is expected" );
      END; // IF something in the Queue
         
      Communicate();
   END OnDaliData;

(*-------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE FeedCommand( Linie : CARDINAL; daliAddress : TPDaliAddress; _Command : TDaliCommand; Data : CARD8; CONST ClientId : PTR ) : Sync.TAsyncResult;
   VAR
      Request : TPDaliRequest;
   BEGIN
      NEW( Request );
      Request^.Linie := Linie;
      Request^.ClientId := ClientId;
      IF daliAddress <> NIL THEN
         Request^.Address := daliAddress^;
      END;
      Request^.Command := _Command;
      Request^.Data := Data;

      LogRequest( dldDebug, L"REQ: ", Request, Sync.arCompleted, daliAddress <> NIL, FALSE, TRUE );

      Queue.Enqueue( Request );
      
      RETURN Sync.arPending; // all processing is moved into thread
   END FeedCommand;

(*-------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Communicate() : Sync.TAsyncResult;
   VAR
      DaliData : ARRAY [0..1] OF BYTE;
      Result : Sync.TAsyncResult;
      Request : TPDaliRequest;
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

         LogRequest( dldDebug, L"SND: ", Request, Sync.arCompleted, FALSE, FALSE, TRUE );

      ELSIF Request^.Command = cmdDirect THEN
         DaliData[0] := Request^.Address.TransportAddress AND NOT 01H;
         DaliData[1] := MIN2( 0FEH, Request^.Data );

         LogRequest( dldDebug, L"SND: ", Request, Sync.arCompleted, TRUE, FALSE, TRUE );

      ELSE
         DaliData[0] := Request^.Address.TransportAddress OR 01H;
         DaliData[1] := BYTE( Request^.Command );

         LogRequest( dldDebug, L"SND: ", Request, Sync.arCompleted, TRUE, FALSE, FALSE );
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
         | dapInitFull :
            FeedCommand( ProgrammedLinie, NIL, cmdTerminate, 0, DUMMY_RESPONSE );

            DA.Type := DaliBridge.adrAll;
            FeedCommand( ProgrammedLinie, ADR( DA ), cmdMin, 0, DUMMY_RESPONSE );
            FeedCommand( ProgrammedLinie, NIL, cmdLoadDTR, 0FFH, DUMMY_RESPONSE );
            FeedCommand( ProgrammedLinie, ADR( DA ), cmdDTRToAddress, 0FFH, DUMMY_RESPONSE );

            FeedCommand( ProgrammedLinie, NIL, cmdInitialize, 0FFH, EXPECTED_RESPONSE );
            EXIT;

         | dapInitPairing :
            FeedCommand( ProgrammedLinie, NIL, cmdTerminate, 0, DUMMY_RESPONSE );
            EXIT;

         | dapInitPartial :
            DA.Type := DaliBridge.adrAll;
            FeedCommand( ProgrammedLinie, ADR( DA ), cmdMin, 0, DUMMY_RESPONSE );

            FeedCommand( ProgrammedLinie, NIL, cmdInitialize, 0FFH, EXPECTED_RESPONSE );
            EXIT;

         | dapInitReaddressing :
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
            DA.Type := DaliBridge.adrSingle;
            DA.Address := Programmer.CurrentShortAddress;
            FeedCommand( ProgrammedLinie, NIL, cmdCheckAddress, DA.TransportAddress OR 01H, EXPECTED_RESPONSE );
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
            IF EventSink <> NIL THEN
               IF Programmer.Failed THEN
                  EventSink^.OnProgrammingStopped( Sync.arAborted, ProgrammedLinie );
               ELSE
                  EventSink^.OnProgrammingStopped( Sync.arCompleted, ProgrammedLinie );
               END;
            END;
            EXIT;

         END; // CASE
      END; // LOOP
   END ProgrammingStep;

(*-------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE LogRequest( Level : log.TDebugLevel; LeadingText : ARRAY OF WCHAR; Request : ADDRESS; Result : Sync.TAsyncResult; PrintAddress, PrintResult, PrintData : BOOLEAN );
   VAR
      S : ARRAY [0..127] OF WCHAR;
      N : ARRAY [0..31] OF WCHAR;
   BEGIN
      S := LeadingText;
   
      // command
      CASE TPDaliRequest( Request )^.Command OF
      | cmdDTRToAddress :
         N := L'DTR to address';
      | cmdTerminate :
         N := L"terminate programming";
      | cmdLoadDTR :
         N := L"load to DTR";
      | cmdInitialize :
         N := L"initialize programming";
      | cmdRandomize :
         N := L"randomize";
      | cmdCompare :
         N := L"compare";
      | cmdWithdraw :
         N := L"withdraw";
      | cmdStoreH :
         N := L"store long address H";
      | cmdStoreM :
         N := L"store long address M";
      | cmdStoreL :
         N := L"store long address L";
      | cmdSetAddress :
         N := L"set address";
      | cmdGetAddress :
         N := L"get address";
      ELSE
         Strings.FromCARD32W( CARDINAL( TPDaliRequest( Request )^.Command ), 16, OUT N );
      END;
      Strings.AppendW( REF S, N );
      Strings.AppendW( REF S, L", " );
      
      // linie.address
      Strings.FromCARD32W( CARDINAL( TPDaliRequest( Request )^.Linie ), 10, OUT N );
      Strings.AppendW( REF S, N );
      IF PrintAddress THEN
         Strings.AppendW( REF S, L"." );
         Strings.FromCARD32W( TPDaliRequest( Request )^.Address.Address, 10, OUT N );
         Strings.AppendW( REF S, N );
      END;
      
      // result
      IF PrintResult AND Sync.ResultToName( Result, OUT N ) THEN
         Strings.AppendW( REF S, L", " );
         Strings.AppendW( REF S, N );
      END;
      
      // data
      IF PrintData THEN
         Strings.AppendW( REF S, L", data: " );
         Strings.FromCARD32W( CARDINAL( TPDaliRequest( Request )^.Data ), 16, OUT N );
         Strings.AppendW( REF S, N );
      END;
      
      // all
      Logger.LogS( Level, logPrefix, S );
   END LogRequest;

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