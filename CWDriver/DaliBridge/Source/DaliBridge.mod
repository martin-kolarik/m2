IMPLEMENTATION MODULE DaliBridge;

FROM Debug IMPORT
   AssertionW;

FROM log IMPORT
   ldError, ldMessage, ldTrace, ldDebug;
  
FROM Exceptions IMPORT
   TestIfCatched, RetrieveException, CModula2Exception;

FROM driver IMPORT
   R;

IMPORT
   collection,
   datetime,
   dns,
   Log,
   netsocket,
   netsrv,
   StorageO,
   Strings,
   Sync,
   Texts,
   threadpool;

(*===============================================================================*)

CONST
   logNetPrefix = L"UDP";
   logDevPrefix = L"DEV";
   logProgramPrefix = L"PRG";
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
      3, 3, 1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 3
      // execept last 4 ones all ones are for safety: unrecognized byte will be dropped and next one will be feeded
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
      FrameLinkErrors : CARDINAL;
      FrameLinkErrorLimit : CARDINAL := 10;
   LOCAL VAR
      EventSink : TPICommunicatorSink;
      InterPacketDelay : CARDINAL;
      Logger : Log.TPLogger;
      
   TYPE
      TDaliPacket = ARRAY [0..2] OF BYTE; // 3 bytes DALI

   PUBLIC PROCEDURE SetDeviceAddress( CONST DeviceAddress : inetaddr.INETADDR; LocalListenPort : CARDINAL );
   PUBLIC PROCEDURE Run() : Sync.TAsyncResult;
   PUBLIC PROCEDURE Stop();

   PUBLIC PROCEDURE SendDaliData( Linie : TDaliLinie; Data : ARRAY OF BYTE; Reset, ExpectResponse, Repeat, Long : BOOLEAN ) : Sync.TAsyncResult;

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

      Logger^.LogSC( Log.ldTrace, 0, logNetPrefix, L"Listening on port: ", ListenPort );

      IA.Port := ListenPort;
      Result := netsrv.StartListen( netsocket.stDatagram, IA, NIL, ADR( SELF ), 0, ADR( Socket ));
      IF Result = 0 THEN
         RETURN Sync.arCompleted;
      ELSE
         Logger^.LogSE( Log.ldError, 0, logNetPrefix, L"Unable StartListen: ", Result );
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

   PUBLIC PROCEDURE SendDaliData( Linie : TDaliLinie; Data : ARRAY OF BYTE; Reset, ExpectResponse, Repeat, Long : BOOLEAN ) : Sync.TAsyncResult;
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
         delay := INTEGER( datetime.UptimeMS() - LastSend );
         IF ( Delay = NIL ) AND ( delay < INTEGER( InterPacketDelay )) THEN // wait if not waiting yet
            threadpool.pool()^.WaitTimeout( TimerSink, timerDelay, delay, TRUE, TRUE, OUT Delay );
            RETURN Sync.arAlreadyPending;
         END;   
      END;
      LastSend := datetime.UptimeMS();

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
      expectedReset : BOOLEAN := FALSE;
      gdeResponse : TGDEResponse;
      i, l : CARDINAL;
      leaveTimeout, eventFlag : BOOLEAN;
      packet : ARRAY [0..15] OF BYTE;
      processResult : Sync.TAsyncResult := Sync.arNoData;
   BEGIN

      ServerSocket^.ReceiveOA( OUT packet, OUT l ); // receive, possibly not whole datagram
      IF l < 1 THEN // filter damaged data
         Logger^.LogSC( ldMessage, 0, logNetPrefix, L"Corrupted data received, length: ", l );
         EventSink^.OnDaliData( Sync.arAborted, FALSE, OA( -1, NIL ));

      ELSIF EventSink = NIL THEN // and filter data for nobody
         Logger^.LogS( ldMessage, 0, logNetPrefix, L"Data received, but nobody listens" );
         RETURN;
      END;

      Buffer.AppendOA( OA( l-1, ADR( packet ))); // store correct data in buffer
      
      LOOP // process buffer
      
         IF Buffer.Empty THEN
            EXIT;
         END;
         TRY
            gdeResponse := TGDEResponse( Buffer[0] AND 01FH );
         CATCH e : CModula2Exception DO
            EXIT; // should not occur, as it has been checked using Buffer.Empty above
         END;
         IF Buffer.Length < gderl[ gdeResponse ] THEN // not all data for command were received, wait for more
            EXIT;
         ELSE
            l := gderl[ gdeResponse ];
         END;
         
         leaveTimeout := FALSE;
         eventFlag := FALSE;

         CASE gdeResponse OF
         | gderReset : // OK, switch on
            Logger^.LogS( ldDebug, 0, logNetPrefix, L"res: Reset OK" );
         | gderStatus : // OK, status
            Logger^.LogS( ldTrace, 0, logNetPrefix, L"res: Reset/Status response" );
         | gderRead : // OK, response to 8
            Logger^.LogSB( ldDebug, 0, logNetPrefix, L"res: Expected device response received: ", Buffer.Data, l );
            processResult := Sync.arCompleted;
            WaitResponse := FALSE;
         | gderFrameError : // 008H frame link error
            Logger^.LogS( ldTrace, 0, logNetPrefix, L"res: Frame link error when waiting device response" );
            processResult := Sync.arAlreadyPending;
            WaitResponse := FALSE;
         | gderReadFailure : // 008H timeout
            Logger^.LogS( ldDebug, 0, logNetPrefix, L"res: Expected device response not received" );
            processResult := Sync.arPartCompleted;
            WaitResponse := FALSE;
         | gderACK : // ACK
            IF WaitResponse OR WaitReset THEN
               Logger^.LogS( ldDebug, 0, logNetPrefix, L"res: ACK, but continue waiting for device response" );
               leaveTimeout := TRUE;
            ELSE
               Logger^.LogS( ldDebug, 0, logNetPrefix, L"res: ACK" );
               processResult := Sync.arCompleted;
            END;
         | gderNAK : // NAK
            Logger^.LogS( ldTrace, 0, logNetPrefix, L"res: NAK" );
            processResult := Sync.arAlreadyPending; // repeat command
         | gderEvent : // OK, event data
            Logger^.LogSB( ldDebug, 0, logNetPrefix, L"EVT: Event data: ", Buffer.Data, l );
            eventFlag := TRUE;
            processResult := Sync.arCompleted;
         ELSE
            Logger^.LogSB( ldMessage, 0, logNetPrefix, L"res: Strange device response: ", Buffer.Data, l );
            processResult := Sync.arAlreadyPending; // repeat command
         END;

         CASE gdeResponse OF
         | gderReset, gderStatus : // event, e.g. switch on of device, leave pending send timeout
            leaveTimeout := NOT WaitReset;
            expectedReset := WaitReset;
            WaitReset := FALSE;
         | gderEvent : // these are events too, they must not stop existing pending send timeout
            leaveTimeout := TRUE;
         END;
         
         CASE gdeResponse OF
         | gderFrameError : // kill if errors are repetitive
            INC( FrameLinkErrors );
            IF FrameLinkErrors >= FrameLinkErrorLimit THEN
               FrameLinkErrors := 0;
               processResult := Sync.arAborted; // report unability to get value
            END;
         | gderACK, gderNAK :
            // no frame link count reset, the commands are responses out of DALI itself
         ELSE
            FrameLinkErrors := 0;
         END;

         IF ( Timeout <> NIL ) AND NOT leaveTimeout THEN
            threadpool.pool()^.Abort( REF Timeout );
         END;

         IF l = 1 THEN
            l := 0; // no data in packet, mostly used for cmdRead: 08 returns either response either timeout.
         ELSIF processResult = Sync.arCompleted THEN // copy buffer to dali data packet
            TRY      
               IF eventFlag THEN
                  FOR i := 0 TO l-1 DO
                     dali[i] := Buffer[i];
                  END; // FOR
               ELSE
                  FOR i := 1 TO l-1 DO
                     dali[i-1] := Buffer[i];
                  END; // FOR
               END;
            CATCH e : CModula2Exception DO
               // should not occur, as it has been checked using l
               l := 0;
               processResult := Sync.arAborted;
            END;
         ELSE
            l := 0;
         END;

         IF processResult <> Sync.arNoData THEN
            EventSink^.OnDaliData( processResult, eventFlag, OA( l-1, ADR( dali )));

         ELSIF ( gdeResponse = gderReset ) OR ( gdeResponse = gderStatus ) THEN
            EventSink^.OnDaliSendable( expectedReset );
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
               EventSink^.OnDaliTimeout();
            ELSE
               EventSink^.OnDaliSendable( FALSE );
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
   FrameLinkErrors := 0;

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

   PUBLIC PROPERTY TransportAddress SET( Value : CARD8 );
   BEGIN
      _Address := Value;
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
      IF CurrentShort > 63 THEN
         RETURN -1;
      ELSIF AddressMode = amReaddress THEN
         RETURN Readdress[CurrentShort];
      ELSE
         RETURN CurrentShort;
      END;
   END CurrentShortAddress;
      
(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE InitAddressing( Specific : BOOLEAN; CONST SpecificAddress : DaliAddress ) : BOOLEAN;
   BEGIN
      IF Specific AND NOT HaveAddresses THEN
         RETURN FALSE;
      END;
      AddressMode := amAddress;

      SpecificFlag := Specific;
      IF Specific THEN
         State := dapInitSpecific;
         SELF.SpecificAddress := SpecificAddress;
      ELSE
         State := dapInitFull;
         HaveAddresses := FALSE;
         Current := addressesNone;
      END;
      CurrentSelected := 0;
      CurrentShort := 0;
      New := Current;
      
      RETURN TRUE;
   END InitAddressing;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE InitScanning( ScanBySeek : BOOLEAN );
   BEGIN
      AddressMode := amScan;

      IF ScanBySeek THEN
         State := dapInitScanning2;
      ELSE
         State := dapInitScanning;
      END;
      HaveAddresses := FALSE;
      Current := addressesNone;
      New := addressesNone;

      CurrentShort := 0;
   END InitScanning;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE InitReaddressing( Readdress : TAddresses ) : BOOLEAN;
   BEGIN
      IF NOT HaveAddresses THEN
         RETURN FALSE;
      END;
      AddressMode := amReaddress;
      SELF.Readdress := Readdress;

      State := dapInitReaddressing;
      New := addressesNone;
      CurrentShort := 0;

      RETURN TRUE;
   END InitReaddressing;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE GetLongAddresses( OUT LongAddresses : TAddresses ) : BOOLEAN;
   VAR
      i : CARDINAL;
   BEGIN
      IF NOT HaveAddresses THEN
         RETURN FALSE;
      END;

      FOR i := 0 TO HIGH( LongAddresses ) DO
         IF Current[i] = -1 THEN
            LongAddresses[i] := -1;
         ELSE
            LongAddresses[i] := ( i << 24 ) OR Current[i];
         END;
      END; // FOR
      
      RETURN TRUE;
   END GetLongAddresses;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE LoadLongAddresses( LongAddresses : TAddresses );
   VAR
      i : CARDINAL;
   BEGIN
      Current := addressesNone;
      FOR i := 0 TO HIGH( LongAddresses ) DO
         IF LongAddresses[i] = -1 THEN
            CONTINUE;
         END;
         Current[CARD8( LongAddresses[i] >> 24 )] := LongAddresses[i] AND 0FFFFFFH;
      END; // FOR
      HaveAddresses := TRUE;
   END LoadLongAddresses;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE WhatNext() : TCommand;
   BEGIN
      RETURN State;
   END WhatNext;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE HandleResponse( Positive : BOOLEAN; Data : INTEGER );
   VAR
      da : DaliAddress;
   BEGIN
      CASE State OF
      | dapInitFull :
         IF Positive THEN
            State := dapRandomize;
         END;
      | dapInitSpecific :
         IF Positive THEN
            CurrentShort := LookupNextEmptyShort( 0 );
            IF CurrentShortAddress = -1 THEN
               Failed := FALSE;
               State := dapFinish;
            ELSE
               State := dapRandomize;
            END;
         END;
      | dapInitScanning :
         IF Positive THEN
            CurrentSelected := Current[CurrentShort];
            State := dapScanOneH;
         END;
      | dapInitScanning2 :
         IF Positive THEN
            State := dapStartSeek;
         END;
      | dapInitReaddressing :
         IF Positive THEN
            IF CurrentShortAddress = -1 THEN
               Failed := FALSE;
               State := dapFinish;
            ELSE
               CurrentSelected := LookupNextReaddressed();
               IF CurrentSelected = -1 THEN
                  Failed := FALSE;
                  State := dapFinish;
               ELSE
                  State := dapSelectOne;
               END;
            END;
         END;

      | dapRandomize :
         IF Positive THEN
            State := dapStartSeek;
         ELSIF SpecificFlag THEN
            State := dapInitSpecific;
         ELSE
            State := dapInitFull;
         END;

      | dapStartSeek :
         State := dapSeekOne;

      | dapSeekOne :
         IF Positive THEN
            Current[CurrentShort] := Data;
            CurrentSelected := Data;
            IF AddressMode = amScan THEN
               State := dapScan2GetShort;
            ELSE
               State := dapProgramOne;
            END;
         ELSE
            Failed := FALSE;
            State := dapFinish;
         END;

      | dapSelectOne :
         IF Positive THEN
            State := dapProgramOne;
         END;
         
      | dapScanOneH :   
         IF Positive THEN
            CurrentSelected := Data << 16;
            State := dapScanOneM;
         ELSE
            Logger^.LogSC( ldDebug, 0, logProgramPrefix, L"Scan address (h) failed for: ", CurrentShortAddress );
            CurrentSelected := -1;
            State := dapScannedOne;
         END;

      | dapScanOneM :   
         IF Positive THEN
            CurrentSelected := CurrentSelected OR ( Data << 8 );
            State := dapScanOneL;
         ELSE
            Logger^.LogSC( ldDebug, 0, logProgramPrefix, L"Scan address (m) failed for: ", CurrentShortAddress );
            CurrentSelected := -1;
            State := dapScannedOne;
         END;

      | dapScanOneL :   
         IF Positive THEN
            CurrentSelected := CurrentSelected OR Data;
         ELSE
            Logger^.LogSC( ldDebug, 0, logProgramPrefix, L"Scan address (h) failed for: ", CurrentShortAddress );
            CurrentSelected := -1;
         END;
         State := dapScannedOne;
         
      | dapScannedOne :
         Current[CurrentShortAddress] := CurrentSelected;

         INC( CurrentShort );
         IF CurrentShortAddress <> -1 THEN // continue
            State := dapScanOneH;
         ELSE
            State := dapFinish;
         END;
         
      | dapScan2GetShort :
         IF Positive THEN
            da.TransportAddress := CARD8( Data );
            CurrentShort := da.Address;
            Current[CurrentShort] := CurrentSelected;
         ELSE
            CurrentSelected := -1;
         END;
         State := dapScanned2One;

      | dapScanned2One :
         State := dapSeekOne;
         
      | dapProgramOne :
         IF Positive THEN
            State := dapCheckOne;
         END;

      | dapCheckOne :
         IF AddressMode = amReaddress THEN
            Failed := TRUE;
            State := dapFinish;
         ELSE
            State := dapDisableOne;
         END;

         // check response
         da.TransportAddress := CARD8( Data );
         IF NOT Positive OR ( CurrentShortAddress <> da.Address ) THEN
            Logger^.LogSC( ldMessage, 0, logProgramPrefix, L"Check/get address failed for: ", CurrentShortAddress );
            IF AddressMode = amReaddress THEN
               // fall down and try to readdress next one
            ELSE
               RETURN;
            END;
         END;

         // variant for cmdCheckAddress
         // IF NOT Positive THEN
         //    Logger^.LogSC( ldMessage, 0, logProgramPrefix, L"Check address failed for: ", CurrentShortAddress );
         //    RETURN;
         // END;
         
         IF AddressMode = amReaddress THEN
            New[CurrentShortAddress] := CurrentSelected;

            INC( CurrentShort );
            IF CurrentShortAddress = -1 THEN
               Failed := FALSE;
               State := dapFinish;
            ELSE
               CurrentSelected := LookupNextReaddressed();
               IF CurrentSelected = -1 THEN
                  Failed := FALSE;
                  State := dapFinish;
               ELSE
                  State := dapSelectOne;
               END;
            END;

         ELSE
            State := dapShowOne;
         END;

      | dapShowOne :
         IF Positive THEN
            State := dapDisableOne;
         END;

      | dapDisableOne :
         IF Positive THEN
         
            // disable is done during addressing only, select new empty address
            CurrentShort := LookupNextEmptyShort( CurrentShort+1 );
            IF CurrentShortAddress = -1 THEN
               Failed := FALSE;
               State := dapFinish;
            ELSE
               State := dapStartSeek;
            END;

         END;

      | dapFinish :
         IF Positive THEN
            IF AddressMode = amReaddress THEN
               Current := New;
            END;
            HaveAddresses := TRUE;
         END;
         State := dapEnd;

      END; // CASE
   END HandleResponse;

(*-------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE LookupNextEmptyShort( StartWith : CARDINAL ) : CARDINAL;
   VAR
      i : CARDINAL;
   BEGIN
      FOR i := StartWith TO HIGH( Current ) DO
         IF Current[i] = -1 THEN // we found hole in addresses
            RETURN i;
         END;
      END;
      RETURN HIGH( Current )+1; // CurrentShort over limit
   END LookupNextEmptyShort;

(*-------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE LookupNextReaddressed() : CARDINAL;
   VAR
      i, j : CARDINAL;
   BEGIN
      i := 0;
      j := 0;
      LOOP
         IF i > HIGH( Current ) THEN // next existing long address not found
            RETURN -1;
         END;

         IF Current[i] = -1 THEN
            // no hit, continue
         ELSIF j = CurrentShort THEN
            RETURN Current[i];
         ELSE
            INC( j );
         END;

         INC( i );
      END;
   END LookupNextReaddressed;

(*-------------------------------------------------------------------------------*)

BEGIN
   AddressMode := amUnknown;
   Current := addressesNone;
   New := addressesNone;
   Readdress := addressesNone;
   State := dapInitFull;
   SpecificFlag := FALSE;
   CurrentSelected := 0;
   CurrentShort := 0;
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
      Linie : TDaliLinie;
      ClientId : PTR;
      Address : DaliAddress;
      Command : TDaliCommand;
      Data : CARD8;
      LongData : ADDRESS;
      UserId : StringsO.CString;
      Groups : CARD32 := 0;
END DaliRequest;

(*-------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION DaliRequest;
BEGIN
   Pending := FALSE;
   Linie := l1;
   ClientId := 0;
   Command := cmdOff;
   Data := 0;
   LongData := NIL;
END DaliRequest;

(*===============================================================================*)

CLASS IMPLEMENTATION CDaliDevice;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROPERTY ProgrammingInProgress GET : BOOLEAN;
   BEGIN
      RETURN Programming[l1] OR Programming[l2] OR Programming[l3] OR Programming[l4];
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

   PUBLIC PROPERTY SendDelay SET( Value : CARDINAL );
   BEGIN
      Communicator^.InterPacketDelay := MIN2( 2000, Value );
   END SendDelay;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROPERTY SendDelay GET : CARDINAL;
   BEGIN
      RETURN Communicator^.InterPacketDelay;
   END SendDelay;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROPERTY OutputQueueLength SET( Value : CARDINAL );
   BEGIN
      QueueLength := MAX2( 2, Value );
   END OutputQueueLength;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROPERTY PollClientId GET : PTR;
   BEGIN
      RETURN _PollClientId;
   END PollClientId;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROPERTY PollClientId SET( Value : PTR );
   BEGIN
      _PollClientId := Value;
   END PollClientId;

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
      log.ConfigureByAppender( REF Logger, SourceLogger );
      Logger.SetName( LongName );

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
         Command( l4, da, cmdInterfaceReset, 0, 0, L'' ); // reset
         Command( l3, da, cmdInterfaceReset, 0, 0, L'' ); // reset
         Command( l2, da, cmdInterfaceReset, 0, 0, L'' ); // reset
         Command( l1, da, cmdInterfaceReset, 0, 0, L'' ); // reset, reset first linie (with ETH interface) as last
      END;
      RETURN Result;
   END Run;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Stop();
   VAR
      Request : TPDaliRequest;
   BEGIN
      IF NOT Running THEN
         RETURN;
      END;
      Running := FALSE;
      
      WHILE Queue.Dequeue( OUT Request ) DO
         DISPOSE( Request );
      END; // WHILE
      Communicator^.Stop();

      IF PollTimer <> NIL THEN
         threadpool.pool()^.Abort( REF PollTimer );
      END;
   END Stop;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Command( Linie : TDaliLinie; CONST daliAddress : DaliAddress; _Command : TDaliCommand; Data : CARD8; CONST ClientId : PTR; CONST userId : ARRAY OF WCHAR ) : Sync.TAsyncResult;
   BEGIN
      IF ProgrammingInProgress THEN
         Logger.LogSC( ldMessage, 0, logDevPrefix, L"Unable to send command in programming mode: ", CARDINAL( _Command ));
         RETURN Sync.arCannotStart;
      ELSE
         ASSERTLOG( _Command <> cmdGetGroupsL );
         RETURN FeedCommand( Linie, TPDaliAddress( ADR( daliAddress )), _Command, Data, NIL, ClientId, userId );
      END;
   END Command;
   
(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Address( Linie : TDaliLinie; Specific : BOOLEAN; CONST SpecificAddress : DaliAddress ) : BOOLEAN;
   VAR
      Msg : msghandler.Message;
   BEGIN
      IF ProgrammingInProgress OR NOT Programmer[Linie].InitAddressing( Specific, SpecificAddress ) THEN
         RETURN FALSE;
      END;

      Fill( ADR( StatusArray[Linie] ), SIZE( StatusArray[Linie] ), 0FFH ); // force report new statuses
      Fill( ADR( PendingArray[Linie] ), SIZE( PendingArray[Linie] ), 0 ); // reset pending flags

      Programming[Linie] := TRUE;

      Msg.Message := MSG_START_PROGRAMMING;
      Msg.Parameter := PTR( Linie );
      Message( Msg, msghandler.delDefault, NIL );
      RETURN TRUE;
   END Address;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Scan( Linie : TDaliLinie; ScanBySeek : BOOLEAN ) : BOOLEAN;
   VAR
      Msg : msghandler.Message;
   BEGIN
      IF ProgrammingInProgress THEN
         RETURN FALSE;
      END;
      Programmer[Linie].InitScanning( ScanBySeek );

      Fill( ADR( StatusArray[Linie] ), SIZE( StatusArray[Linie] ), 0FFH ); // force report new statuses
      Fill( ADR( PendingArray[Linie] ), SIZE( PendingArray[Linie] ), 0 ); // reset pending flags

      Programming[Linie] := TRUE;

      Msg.Message := MSG_START_PROGRAMMING;
      Msg.Parameter := PTR( Linie );
      Message( Msg, msghandler.delDefault, NIL );
      RETURN TRUE;
   END Scan;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Readdress( Linie : TDaliLinie; CONST Readdressed : TAddresses ) : BOOLEAN;
   VAR
      Msg : msghandler.Message;
   BEGIN
      IF ProgrammingInProgress OR NOT Programmer[Linie].InitReaddressing( Readdressed ) THEN
         RETURN FALSE;
      END;

      Fill( ADR( StatusArray[Linie] ), SIZE( StatusArray[Linie] ), 0FFH ); // force report new statuses
      Fill( ADR( PendingArray[Linie] ), SIZE( PendingArray[Linie] ), 0 ); // reset pending flags

      Programming[Linie] := TRUE;

      Msg.Message := MSG_START_PROGRAMMING;
      Msg.Parameter := PTR( Linie );
      Message( Msg, msghandler.delDefault, NIL );
      RETURN TRUE;
   END Readdress;
   
(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SetPollPeriod( Linie : TDaliLinie; PollPeriodMS : CARDINAL );
   BEGIN
      Polled[Linie] := PollPeriodMS > 0;

      IF PollPeriod = PollPeriodMS THEN
         RETURN;
      END;
      PollPeriod := PollPeriodMS;
      
      IF PollPeriod = 0 THEN // switch off
         IF PollTimer <> NIL THEN
            threadpool.pool()^.Abort( REF PollTimer );
         END;

      ELSE // switch on
         PollPeriod := MAX2( 75, PollPeriod );
         IF Running THEN
            threadpool.pool()^.WaitTimeout( PollSink, 0, PollPeriod, FALSE, TRUE, OUT PollTimer );
         END;
      END;
   END SetPollPeriod;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE GetLongAddresses( Linie : TDaliLinie; OUT LongAddresses : TAddresses ) : BOOLEAN;
   BEGIN
      RETURN Programmer[Linie].GetLongAddresses( OUT LongAddresses );
   END GetLongAddresses;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE LoadLongAddresses( Linie : TDaliLinie; CONST LongAddresses : TAddresses );
   BEGIN
      Programmer[Linie].LoadLongAddresses( LongAddresses );
   END LoadLongAddresses;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SendFile( Linie : TDaliLinie; _FileToSend : lists.TPBufferList ) : BOOLEAN; // CDaliDevice must deallocate FileToSend by itself
   VAR
      Request : TPDaliRequest;
   BEGIN
      IF Programming[Linie] OR ( _FileToSend = NIL ) THEN
         RETURN FALSE;
      END;
      Programming[Linie] := TRUE;
      FileToSendFailure[Linie] := FALSE;

      // clear output queue
      WHILE Queue.Dequeue( OUT Request ) DO
         DISPOSE( Request );
      END; // WHILE

      // set file data   
      DISPOSE( FileToSend[Linie] );
      FileToSend[Linie] := _FileToSend;
      FileToSend[Linie]^.Reset();
      
      SendFileItem( Linie );
      RETURN TRUE;
   END SendFile;
   
(*-------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE SendFileItem( Linie : TDaliLinie );
   BEGIN
      IF NOT FileToSend[Linie]^.MoveNext() THEN
         Programming[Linie] := FALSE;
         DISPOSE( FileToSend[Linie] );
         IF EventSink <> NIL THEN
            IF FileToSendFailure[Linie] THEN
               EventSink^.OnProgrammingStopped( Sync.arAborted, Name, Linie );
            ELSE
               EventSink^.OnProgrammingStopped( Sync.arCompleted, Name, Linie );
            END;
         END;
         RETURN;
      END;
      FeedCommand( Linie, NIL, cmdFileItem, 0, FileToSend[Linie]^.Current^.Data, 0, L'' );
   END SendFileItem;

(*-------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnMessage( CONST Message : msghandler.IMessage; OUT Result : PTR ) : BOOLEAN;
   BEGIN
      CASE Message.Message OF
      | msgqueue.MSG_PROCESS_QUEUE :
         Logger.LogS( ldDebug, 0, logDevPrefix, L"CTR: Communicate after SWITCH" );
         Communicate();
      | MSG_START_PROGRAMMING :
         ProgrammingStep( TDaliLinie( LOPTRLONGWORD( Message.Parameter )));
      ELSE
         RETURN FALSE;
      END;
      RETURN TRUE;
   END OnMessage;

(*-------------------------------------------------------------------------------*)

   // ICommunicationSink -- in thread
   LOCAL VIRTUAL PROCEDURE OnDaliSendable( AfterReset : BOOLEAN );
   VAR
      Request : TPDaliRequest;
   BEGIN
      Logger.LogS( ldDebug, 0, logDevPrefix, L"CTR: Communicate after DELAY/RESET" );
      IF AfterReset THEN // dequeue reset request
         Queue.Dequeue( OUT Request );
         DISPOSE( Request );
      END;
      Communicate();
   END OnDaliSendable;

(*-------------------------------------------------------------------------------*)

   // ICommunicationSink -- in thread
   LOCAL VIRTUAL PROCEDURE OnDaliTimeout();
   BEGIN
      Logger.LogS( ldTrace, 0, logDevPrefix, L"CTR: Receive response TIMEOUT" );
      OnDaliData( Sync.arTimeout, FALSE, OA( -1, NIL ));
   END OnDaliTimeout;

(*-------------------------------------------------------------------------------*)

   // ICommunicationSink -- in thread
   LOCAL VIRTUAL PROCEDURE OnDaliData( Result : Sync.TAsyncResult; EventFlag : BOOLEAN; Data : ARRAY OF BYTE );
   VAR
      address : CARDINAL;
      CurrentNext : TCommand;
      da : DaliAddress;
      disposeRequest : BOOLEAN := TRUE;
      fileItem : PBYTE;
      i : CARDINAL;
      linie : TDaliLinie;
      Response : CARD8 := 0;
      Response32 : CARD32 := 0;
      Request : TPDaliRequest;
   BEGIN
      IF EventFlag THEN
         IF Result = Sync.arCompleted THEN // only successes should be reported
            CASE Data[0] >> 5 OF
            | 0 : linie := l1;
            | 1 : linie := l2;
            | 2 : linie := l3;
            | 3 : linie := l4;
            ELSE
               linie := l1;
            END; // CASE
            da.TransportAddress := Data[1];
            EventSink^.OnCompletion( Result, Name, linie, da, cmdEvent, CARD32( Data[2] ), 0, NIL );
         END;
      
      ELSIF Queue.Peek( OUT Request ) THEN
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

            IF FileToSend[Request^.Linie] <> NIL THEN // we are sending file
               FileToSendFailure[Request^.Linie] := FileToSendFailure[Request^.Linie] OR ( Result <> Sync.arCompleted );
               fileItem := FileToSend[Request^.Linie]^.Current^.Data;
               IF ( fileItem <> NIL ) AND ( ADR( Data ) <> NIL ) THEN
                  FOR i := 0 TO CARDINAL( fileItem@[32]^ )-1 DO
                     IF Data[i] <> fileItem@[33+i]^ THEN
                        FileToSendFailure[Request^.Linie] := TRUE;
                        EXIT;
                     END;
                  END;
               END;
               SendFileItem( Request^.Linie );
            
            ELSIF Programming[Request^.Linie] THEN
               LogRequest( ldDebug, 0, L"FIN: ", Request, Result, FALSE, TRUE, FALSE );

               IF Result NOT IN Sync.arsCompletions THEN // arTimeout, etc.
                  Logger.LogSC( ldMessage, 0, logProgramPrefix, L"Programming stopped, result: ", CARDINAL( Result ));

                  Programming[Request^.Linie] := FALSE; // kill
                  IF EventSink <> NIL THEN
                     EventSink^.OnProgrammingStopped( Sync.arAborted, Name, Request^.Linie );
                  END;

               ELSIF Request^.ClientId = EXPECTED_RESPONSE THEN
                  CurrentNext := Programmer[Request^.Linie].WhatNext();
                  CASE CurrentNext OF
                  | dapSeekOne :
                     Seeker[Request^.Linie].HandleResponse( Result = Sync.arCompleted );
                  | dapCheckOne, dapScanOneH, dapScanOneM, dapScanOneL, dapScan2GetShort :
                     Programmer[Request^.Linie].HandleResponse( Result = Sync.arCompleted, INTEGER( Response ));
                  ELSE
                     Programmer[Request^.Linie].HandleResponse( TRUE, INTEGER( Response ));
                  END;
                  ProgrammingStep( Request^.Linie );

               END;

            ELSIF EventSink <> NIL THEN
               LogRequest( ldDebug, 0, L"FIN: ", Request, Result, TRUE, TRUE, FALSE );

               IF Request^.ClientId = _PollClientId THEN // response to polling
                  address := Request^.Address.Address;
                  PendingArray[Request^.Linie][address] := FALSE;
                  IF Result = Sync.arCompleted THEN
                     IF StatusArray[Request^.Linie][address] <> Response THEN // unchanged status is not reported
                        StatusArray[Request^.Linie][address] := Response;
                        EventSink^.OnCompletion( Result, Name, Request^.Linie, Request^.Address, Request^.Command, Response32, Request^.ClientId, ADR( Request^.UserId ));
                     END;
                  ELSE
                     IF StatusArray[Request^.Linie][address] <> 0FFH THEN // device was found sooner, but now it is unknown, report dismiss
                        StatusArray[Request^.Linie][address] := 0FFH;
                        EventSink^.OnCompletion( Result, Name, Request^.Linie, Request^.Address, Request^.Command, Response32, Request^.ClientId, ADR( Request^.UserId ));
                     END;
                  END;

               // check if first part of light groups is read and start next one
               ELSIF ( Request^.Command = cmdGetGroupsH ) AND ( Result = Sync.arCompleted ) THEN
                  Request^.Pending := FALSE;
                  Request^.Command := cmdGetGroupsL;
                  Request^.Groups := Response32 << 8;
                  disposeRequest := FALSE;
               
               // check if second part of light groups is read and complete the request
               ELSIF ( Request^.Command = cmdGetGroupsL ) AND ( Result = Sync.arCompleted ) THEN
                  Response32 := Request^.Groups OR Response32;
                  EventSink^.OnCompletion( Result, Name, Request^.Linie, Request^.Address, Request^.Command, Response32, Request^.ClientId, ADR( Request^.UserId ));
               
               // normal finished request
               ELSE
                  EventSink^.OnCompletion( Result, Name, Request^.Linie, Request^.Address, Request^.Command, Response32, Request^.ClientId, ADR( Request^.UserId ));
               END;

            END;
            IF disposeRequest THEN
               DISPOSE( Request );
            ELSE // reuse the request
               Queue.Enqueue( Request );
            END;
            
            // flush queue
            WHILE Queue.Count > QueueLength DO
               Queue.Dequeue( OUT Request );
               DISPOSE( Request );
            END; // WHILE

         END;
         
         Communicate();
      
      ELSE
         Logger.LogS( ldMessage, 0, logDevPrefix, L"CTR: Data received when nothing is expected" );
      END; // IF something in the Queue
   END OnDaliData;

(*-------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnTimeout( Result : Sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR );
   VAR
      address : DaliBridge.DaliAddress;
      linie : TDaliLinie;
   BEGIN
      IF ProgrammingInProgress OR ( Result <> Sync.arCompleted ) THEN
         RETURN;
      END;
         
      address.Type := DaliBridge.adrSingle;
      address.Address := PollActive;

      Logger.LogSC( ldTrace, 0, logDevPrefix, L"Poll status request for: ", PollActive );

      FOR linie := l1 TO l4 DO // 4 DO
         IF NOT Polled[linie] OR PendingArray[linie][PollActive] THEN
            CONTINUE;
         ELSE
            PendingArray[linie][PollActive] := TRUE;
         END;
         Command( linie, address, DaliBridge.cmdStatus, 0, _PollClientId, L'' );
      END; // FOR

      PollActive := PollActive + 1;
      IF PollActive > 63 THEN
         PollActive := 0;
      END;
   END OnTimeout;

(*-------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE FeedCommand( Linie : TDaliLinie; daliAddress : TPDaliAddress; _Command : TDaliCommand; Data : CARD8; LongData : ADDRESS; CONST ClientId : PTR; CONST userId : ARRAY OF WCHAR ) : Sync.TAsyncResult;
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
      Request^.LongData := LongData;
      IF ( HIGH( userId ) <> -1 ) AND ( userId[0] <> 0W ) THEN
         Request^.UserId.FromOA( userId );
      END;

      LogRequest( ldDebug, 0, L"REQ: ", Request, Sync.arCompleted, daliAddress <> NIL, FALSE, TRUE );

      Queue.Enqueue( Request );
      
      RETURN Sync.arPending; // all processing is moved into thread
   END FeedCommand;

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

         LogRequest( ldDebug, 0, L"SNDr: ", Request, Sync.arCompleted, FALSE, FALSE, FALSE );

      ELSIF Request^.Command = cmdFileItem THEN
         Long := PBYTE( Request^.LongData )^ = 2;
         DaliData[0] := PBYTE( Request^.LongData )@[1]^;
         DaliData[1] := PBYTE( Request^.LongData )@[2]^;

         LogRequest( ldDebug, 0, L"SNDf: ", Request, Sync.arCompleted, FALSE, FALSE, FALSE );

      ELSIF Request^.Command IN specialCommands THEN
         DaliData[0] := BYTE( Request^.Command );
         DaliData[1] := Request^.Data;

         LogRequest( ldDebug, 0, L"SNDs: ", Request, Sync.arCompleted, FALSE, FALSE, TRUE );

      ELSIF Request^.Command = cmdDirect THEN
         DaliData[0] := Request^.Address.TransportAddress AND NOT 01H;
         DaliData[1] := MIN2( 0FEH, Request^.Data );

         LogRequest( ldDebug, 0, L"SNDd: ", Request, Sync.arCompleted, TRUE, FALSE, TRUE );

      ELSE
         DaliData[0] := Request^.Address.TransportAddress OR 01H;
         DaliData[1] := BYTE( Request^.Command );

         LogRequest( ldDebug, 0, L"SNDn: ", Request, Sync.arCompleted, TRUE, FALSE, FALSE );
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

   PRIVATE PROCEDURE ProgrammingStep( Linie : TDaliLinie );
   VAR
      Address : TProgramAddress;
      DA : DaliAddress;
   BEGIN
      LOOP
         CASE Programmer[Linie].WhatNext() OF
         | dapInitFull :
            FeedCommand( Linie, NIL, cmdTerminate, 0, NIL, DUMMY_RESPONSE, L'' );

            DA.Type := DaliBridge.adrAll;
            FeedCommand( Linie, ADR( DA ), cmdMin, 0, NIL, DUMMY_RESPONSE, L'' );
            FeedCommand( Linie, NIL, cmdLoadDTR, 0FFH, NIL, DUMMY_RESPONSE, L'' );
            FeedCommand( Linie, ADR( DA ), cmdDTRToAddress, 0FFH, NIL, DUMMY_RESPONSE, L'' );

            FeedCommand( Linie, NIL, cmdInitialize, 0FFH, NIL, EXPECTED_RESPONSE, L'' );
            EXIT;

         | dapInitSpecific :
            FeedCommand( Linie, NIL, cmdTerminate, 0, NIL, DUMMY_RESPONSE, L'' );

            FeedCommand( Linie, ADR( Programmer[Linie].SpecificAddress ), cmdMin, 0, NIL, DUMMY_RESPONSE, L'' );

            FeedCommand( Linie, NIL, cmdInitialize, Programmer[Linie].SpecificAddress.TransportAddress, NIL, EXPECTED_RESPONSE, L'' );
            EXIT;

         | dapInitScanning :
            FeedCommand( Linie, NIL, cmdTerminate, 0, NIL, EXPECTED_RESPONSE, L'' );
            EXIT;

         | dapInitScanning2 :
            FeedCommand( Linie, NIL, cmdTerminate, 0, NIL, EXPECTED_RESPONSE, L'' );
            FeedCommand( Linie, NIL, cmdInitialize, 0, NIL, EXPECTED_RESPONSE, L'' );
            EXIT;

         | dapInitReaddressing :
            FeedCommand( Linie, NIL, cmdTerminate, 0, NIL, DUMMY_RESPONSE, L'' );

            DA.Type := DaliBridge.adrAll;
            FeedCommand( Linie, ADR( DA ), cmdMin, 0, NIL, DUMMY_RESPONSE, L'' );
            
            // variant to erase existing addresses
            // FeedCommand( Linie, NIL, cmdLoadDTR, 0FFH, NIL, DUMMY_RESPONSE, L'' );
            // FeedCommand( Linie, ADR( DA ), cmdDTRToAddress, 0FFH, NIL, DUMMY_RESPONSE, L'' );
            // FeedCommand( Linie, NIL, cmdInitialize, 0FFH, NIL, EXPECTED_RESPONSE, L'' );

            FeedCommand( Linie, NIL, cmdInitialize, 0, NIL, EXPECTED_RESPONSE, L'' );
            EXIT;

         | dapRandomize :
            FeedCommand( Linie, NIL, cmdRandomize, 0, NIL, EXPECTED_RESPONSE, L'' );
            EXIT;

         | dapStartSeek :
            Seeker[Linie].Init();
            LastProgrammedAddress[Linie].C24 := 0;
            Programmer[Linie].HandleResponse( TRUE, 0 );

         | dapSeekOne :
            CASE Seeker[Linie].GetAddressToCheck( OUT Address ) OF
            | getTRUE :
               IF Address.H8 <> LastProgrammedAddress[Linie].H8 THEN
                  FeedCommand( Linie, NIL, cmdStoreH, Address.H8, NIL, DUMMY_RESPONSE, L'' );
               END;
               IF Address.M8 <> LastProgrammedAddress[Linie].M8 THEN
                  FeedCommand( Linie, NIL, cmdStoreM, Address.M8, NIL, DUMMY_RESPONSE, L'' );
               END;
               IF Address.L8 <> LastProgrammedAddress[Linie].L8 THEN
                  FeedCommand( Linie, NIL, cmdStoreL, Address.L8, NIL, DUMMY_RESPONSE, L'' );
               END;
               FeedCommand( Linie, NIL, cmdCompare, 0, NIL, EXPECTED_RESPONSE, L'' );

               LastProgrammedAddress[Linie] := Address;
               EXIT;
            | getFALSE :
               Logger.LogS( ldMessage, 0, logProgramPrefix, L"Programming stopped, no next device found" );
               Programmer[Linie].HandleResponse( FALSE, 0 );
            | getFOUND :
               Logger.LogSC( ldTrace, 0, logProgramPrefix, L"Found device: ", Address.C24 );
               Programmer[Linie].HandleResponse( TRUE, Address.C24 );
            END;
            
         | dapSelectOne :
            Address := Programmer[Linie].CurrentLongAddress;
            FeedCommand( Linie, NIL, cmdStoreH, Address.H8, NIL, DUMMY_RESPONSE, L'' );
            FeedCommand( Linie, NIL, cmdStoreM, Address.M8, NIL, DUMMY_RESPONSE, L'' );
            FeedCommand( Linie, NIL, cmdStoreL, Address.L8, NIL, EXPECTED_RESPONSE, L'' );
            EXIT;

         | dapScanOneH :
            Logger.LogSC( ldTrace, 0, logProgramPrefix, L"Scan address: ", Programmer[Linie].CurrentShortAddress );
            DA.Type := DaliBridge.adrSingle;
            DA.Address := Programmer[Linie].CurrentShortAddress;
            FeedCommand( Linie, ADR( DA ), cmdReadLongH, 0, NIL, EXPECTED_RESPONSE, L'' );
            EXIT;

         | dapScanOneM :
            DA.Type := DaliBridge.adrSingle;
            DA.Address := Programmer[Linie].CurrentShortAddress;
            FeedCommand( Linie, ADR( DA ), cmdReadLongM, 0, NIL, EXPECTED_RESPONSE, L'' );
            EXIT;

         | dapScanOneL :
            DA.Type := DaliBridge.adrSingle;
            DA.Address := Programmer[Linie].CurrentShortAddress;
            FeedCommand( Linie, ADR( DA ), cmdReadLongL, 0, NIL, EXPECTED_RESPONSE, L'' );
            EXIT;
         
         | dapScan2GetShort :
            Logger.LogSC( ldTrace, 0, logProgramPrefix, L"Read address: ", Programmer[Linie].CurrentLongAddress.C24 );
            FeedCommand( Linie, NIL, cmdGetAddress, 0, NIL, EXPECTED_RESPONSE, L'' );
            
         | dapScannedOne,
           dapScanned2One :
            IF Programmer[Linie].CurrentLongAddress.C24 = -1 THEN
               Logger.LogSC( ldTrace, 0, logProgramPrefix, L"Device not found: ", Programmer[Linie].CurrentShortAddress );
            ELSE
               Logger.LogSC( ldTrace, 0, logProgramPrefix, L"Device found: ", Programmer[Linie].CurrentShortAddress );
               Logger.LogSC( ldTrace, 0, logProgramPrefix, L"  with long: ", Programmer[Linie].CurrentLongAddress.C24 );

               DA.Type := DaliBridge.adrSingle;
               DA.Address := Programmer[Linie].CurrentShortAddress;
               EventSink^.OnDeviceFound( Name, Linie, DA, Programmer[Linie].CurrentLongAddress.C24 );
            END;
            Programmer[Linie].HandleResponse( TRUE, 0 ); // move to next state
            
         | dapProgramOne :
            Logger.LogSC( ldTrace, 0, logProgramPrefix, L"Programm address: ", Programmer[Linie].CurrentShortAddress );
            DA.Type := DaliBridge.adrSingle;
            DA.Address := Programmer[Linie].CurrentShortAddress;
            FeedCommand( Linie, NIL, cmdSetAddress, DA.TransportAddress OR 01H, NIL, EXPECTED_RESPONSE, L'' );
            EXIT;

         | dapCheckOne :
            Logger.LogSC( ldTrace, 0, logProgramPrefix, L"Check address: ", Programmer[Linie].CurrentShortAddress );

            // variant for cmdCheckAddress
            // DA.Type := DaliBridge.adrSingle;
            // DA.Address := Programmer.CurrentShortAddress;
            // FeedCommand( ProgrammedLinie, NIL, cmdCheckAddress, DA.TransportAddress OR 01H, EXPECTED_RESPONSE );

            FeedCommand( Linie, NIL, cmdGetAddress, 0, NIL, EXPECTED_RESPONSE, L'' );

            EXIT;

         | dapShowOne :
            Logger.LogSC( ldTrace, 0, logProgramPrefix, L"Address checked: ", Programmer[Linie].CurrentShortAddress );
            DA.Type := DaliBridge.adrSingle;
            DA.Address := Programmer[Linie].CurrentShortAddress;
            FeedCommand( Linie, ADR( DA ), cmdMax, 0, NIL, EXPECTED_RESPONSE, L'' );
            EventSink^.OnDeviceFound( Name, Linie, DA, Programmer[Linie].CurrentLongAddress.C24 );
            EXIT;

         | dapDisableOne :
            FeedCommand( Linie, NIL, cmdWithdraw, 0, NIL, EXPECTED_RESPONSE, L'' );
            EXIT;

         | dapFinish :
            FeedCommand( Linie, NIL, cmdTerminate, 0, NIL, EXPECTED_RESPONSE, L'' );
            EXIT;

         | dapEnd :
            Programming[Linie] := FALSE;
            IF EventSink <> NIL THEN
               IF Programmer[Linie].Failed THEN
                  EventSink^.OnProgrammingStopped( Sync.arAborted, Name, Linie );
               ELSE
                  EventSink^.OnProgrammingStopped( Sync.arCompleted, Name, Linie );
               END;
            END;
            EXIT;

         END; // CASE
      END; // LOOP
   END ProgrammingStep;

(*-------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE LogRequest( Level : log.TLevel; FilterData : PTR; LeadingText : ARRAY OF WCHAR; Request : ADDRESS; Result : Sync.TAsyncResult; PrintAddress, PrintResult, PrintData : BOOLEAN );
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
      Logger.LogS( Level, FilterData, logDevPrefix, S );
   END LogRequest;

(*-------------------------------------------------------------------------------*)

BEGIN
   Programming[l1] := FALSE;
   Programmer[l1].Logger := ADR( Logger );
   Programming[l2] := FALSE;
   Programmer[l2].Logger := ADR( Logger );
   Programming[l3] := FALSE;
   Programmer[l3].Logger := ADR( Logger );
   Programming[l4] := FALSE;
   Programmer[l4].Logger := ADR( Logger );

   Communicator := NEW( CUDPCommunicator );
   Communicator^.EventSink := TPICommunicatorSink( ADR( SELF ));
   Communicator^.Logger := ADR( Logger );

   Running := FALSE;
   EventSink := NIL;
   QueueLength := MAX( CARDINAL );
   Queue.Consumer := ADR( SELF );

   Fill( ADR( Polled ), SIZE( Polled ), 0 );
   Fill( ADR( StatusArray ), SIZE( StatusArray ), 0FFH );
   Fill( ADR( PendingArray ), SIZE( PendingArray ), 0 );
   Fill( ADR( FileToSend ), SIZE( FileToSend ), 0 );
   Fill( ADR( FileToSendFailure ), SIZE( FileToSendFailure ), 0 );
   PollTimer := NIL;
   PollPeriod := Sync.FOREVER;
   PollActive := 0;
   _PollClientId := 0;
   
   NEW( PollSink );
   PollSink^.TimeoutSink := ADR( SELF );

FINALLY
   IF PollSink <> NIL THEN
      PollSink^.TimeoutSink := NIL;
      PollSink^.Release();
      PollSink := NIL;
   END;

   IF Communicator <> NIL THEN
      Communicator^.Release();
      Communicator := NIL;
   END;

   Dispose();
END CDaliDevice;

(*===============================================================================*)

CLASS IMPLEMENTATION CDali;
      
(*-------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnDeviceFound( CONST Dali : StringsO.CString; Linie : TDaliLinie; CONST Address : DaliAddress; LongAddress : CARDINAL );
   BEGIN
      IF EventSink <> NIL THEN
         EventSink^.OnDeviceFound( Dali, Linie, Address, LongAddress );
      END;
   END OnDeviceFound;

(*-------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnProgrammingStopped( Result : Sync.TAsyncResult; CONST Dali : StringsO.CString; Linie : TDaliLinie );
   BEGIN
      IF EventSink <> NIL THEN
         EventSink^.OnProgrammingStopped( Result, Dali, Linie );
      END;
   END OnProgrammingStopped;

(*-------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnCompletion( Result : Sync.TAsyncResult; CONST Dali : StringsO.CString; Linie : TDaliLinie; CONST daliAddress : DaliAddress; Command : TDaliCommand; Data : CARD32; ClientId : PTR; CONST UserId : StringsO.TPString );
   BEGIN
      IF EventSink <> NIL THEN
         EventSink^.OnCompletion( Result, Dali, Linie, daliAddress, Command, Data, ClientId, UserId );
      END;
   END OnCompletion;
   
(*-------------------------------------------------------------------------------*)

   PUBLIC PROPERTY ProgrammingInProgress GET : BOOLEAN;
   VAR
      DaliDevice : POINTER TO CDaliDevice;
      it : maps.CStringPtrMapIterator;
   BEGIN
      it.Init( Dali, collection.dirForward );
      WHILE it.MoveNext() DO
         DaliDevice := it.Value;
         IF DaliDevice^.ProgrammingInProgress THEN
            RETURN TRUE;
         END;
      END; // WHILE
      RETURN FALSE;
   END ProgrammingInProgress;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROPERTY OutputQueueCount GET : CARDINAL;
   VAR
      DaliDevice : POINTER TO CDaliDevice;
      it : maps.CStringPtrMapIterator;
      l : CARDINAL := 0;
   BEGIN
      it.Init( Dali, collection.dirForward );
      WHILE it.MoveNext() DO
         DaliDevice := it.Value;
         INC( l, DaliDevice^.OutputQueueCount );
      END; // WHILE
      RETURN l;
   END OutputQueueCount;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CreateDali( CONST SourceLogger : log.CLogger; CONST Name, Server, Port : ARRAY OF WCHAR; PollClientId : PTR; OutputQueueLength, SendDelay : CARDINAL; OUT Error : StringsO.CString ) : BOOLEAN;
   VAR
      Addr : ARRAY [0..0] OF inetaddr.INETADDR;
      DaliDevice : POINTER TO CDaliDevice;
      listenPort : CARDINAL;
      Result : Sync.TAsyncResult;
      result : ARRAY [0..15] OF WCHAR;
   BEGIN
      IF Dali.Contains( StringsO.FromOA( Name )) THEN
         Error.FromOA( OAsz( R()^[ Texts._DaliAlreadyExists ] ));
         RETURN FALSE;
      END;
      
      IF ( Port[0] = 0W ) OR NOT Strings.ToCARD32W( Port, 10, OUT listenPort ) THEN
         Error.FromOA( OAsz( R()^[ Texts._BadOrMissingListenPort ] ));
         RETURN FALSE;
      END;
      
      // device address
      IF Server[0] = 0W THEN
         Error.FromOA( OAsz( R()^[ Texts._MissingDeviceAddress ] ));
         RETURN FALSE;
      ELSIF NOT dns.NameToAddressWait( Server, listenPort, 2000, OUT Addr ) THEN
         Error.FromOA( OAsz( R()^[ Texts._UnableToGetDeviceAddress ] ));
         RETURN FALSE;
      END;
      
      NEW( DaliDevice );
      DaliDevice^.Init( TRUE );
      DaliDevice^.SetConfiguration( SourceLogger, Name, listenPort, Addr[0] );
      DaliDevice^.PollClientId := PollClientId;
      DaliDevice^.OutputQueueLength := OutputQueueLength;
      DaliDevice^.SendDelay := SendDelay;
      DaliDevice^.EventSink := ADR( SELF );
      Dali.Add( StringsO.FromOA( Name ), DaliDevice, 0 );
      
      IF NOT Running THEN
         RETURN TRUE;
      END;
      
      Result := DaliDevice^.Run();
      CASE Result OF
      | Sync.arAlreadyPending, Sync.arCompleted :
         RETURN TRUE;
      ELSE
         Error.FromOA( OAsz( R()^[ Texts._UnableToRunDevice ] ));
         IF Sync.ResultToName( Result, OUT result ) THEN
            Error.AppendOA( L", status: " );
            Error.AppendOA( result );
         END;
         RETURN FALSE;
      END;
   END CreateDali;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE GetDali( CONST Name : ARRAY OF WCHAR; OUT DaliDevice : PTR ) : BOOLEAN;
   VAR
      d : PTR;
   BEGIN
      RETURN Dali.Get( StringsO.FromOA( Name ), OUT DaliDevice, OUT d );
   END GetDali;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE RemoveDali( CONST Name : ARRAY OF WCHAR ) : BOOLEAN;
   VAR
      d : PTR;
      DaliDevice : POINTER TO CDaliDevice;
   BEGIN
      IF Dali.Get( StringsO.FromOA( Name ), OUT DaliDevice, OUT d ) THEN
         Dali.Remove( StringsO.FromOA( Name ));
         DaliDevice^.Stop();
         DaliDevice^.Dispose();
         DISPOSE( DaliDevice );
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END RemoveDali;
   
(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Run() : Sync.TAsyncResult;
   VAR
      DaliDevice : POINTER TO CDaliDevice;
      it : maps.CStringPtrMapIterator;
   BEGIN
      IF Running THEN
         RETURN Sync.arAlreadyPending;
      END;
      Running := TRUE;
   
      it.Init( Dali, collection.dirForward );
      WHILE it.MoveNext() DO
         DaliDevice := it.Value;
         DaliDevice^.Run();
      END; // WHILE
      RETURN Sync.arCompleted;
   END Run;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Stop();
   VAR
      DaliDevice : POINTER TO CDaliDevice;
      it : maps.CStringPtrMapIterator;
   BEGIN
      IF NOT Running THEN
         RETURN;
      END;
      Running := FALSE;

      it.Init( Dali, collection.dirForward );
      WHILE it.MoveNext() DO
         DaliDevice := it.Value;
         DaliDevice^.Stop();
      END; // WHILE
   END Stop;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Command( Dali : PTR; Linie : TDaliLinie; CONST daliAddress : DaliAddress; _Command : TDaliCommand; Data : CARD8; CONST ClientId : PTR; CONST userId : ARRAY OF WCHAR ) : Sync.TAsyncResult;
   VAR
      DaliDevice : POINTER TO CDaliDevice := Dali;
   BEGIN
      RETURN DaliDevice^.Command( Linie, daliAddress, _Command, Data, ClientId, userId );
   END Command;
   
(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Address( Dali : PTR; Linie : TDaliLinie; Specific : BOOLEAN; CONST SpecificAddress : DaliAddress ) : BOOLEAN;
   VAR
      DaliDevice : POINTER TO CDaliDevice := Dali;
   BEGIN
      RETURN DaliDevice^.Address( Linie, Specific, SpecificAddress );
   END Address;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Scan( Dali : PTR; Linie : TDaliLinie; ScanBySeek : BOOLEAN ) : BOOLEAN;
   VAR
      DaliDevice : POINTER TO CDaliDevice := Dali;
   BEGIN
      RETURN DaliDevice^.Scan( Linie, ScanBySeek );
   END Scan;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Readdress( Dali : PTR; Linie : TDaliLinie; CONST Readdressed : TAddresses ) : BOOLEAN;
   VAR
      DaliDevice : POINTER TO CDaliDevice := Dali;
   BEGIN
      RETURN DaliDevice^.Readdress( Linie, Readdressed );
   END Readdress;
   
(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SetPollPeriod( Dali : PTR; Linie : TDaliLinie; PollPeriodMS : CARDINAL );
   VAR
      DaliDevice : POINTER TO CDaliDevice := Dali;
   BEGIN
      DaliDevice^.SetPollPeriod( Linie, PollPeriodMS );
   END SetPollPeriod;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE GetOutputQueueCount( Dali : PTR ) : CARDINAL;
   VAR
      DaliDevice : POINTER TO CDaliDevice := Dali;
   BEGIN
      RETURN DaliDevice^.OutputQueueCount;
   END GetOutputQueueCount;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE GetLongAddresses( Dali : PTR; Linie : TDaliLinie; OUT LongAddresses : TAddresses ) : BOOLEAN;
   VAR
      DaliDevice : POINTER TO CDaliDevice := Dali;
   BEGIN
      RETURN DaliDevice^.GetLongAddresses( Linie, OUT LongAddresses );
   END GetLongAddresses;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE LoadLongAddresses( Dali : PTR; Linie : TDaliLinie; CONST LongAddresses : TAddresses );
   VAR
      DaliDevice : POINTER TO CDaliDevice := Dali;
   BEGIN
      DaliDevice^.LoadLongAddresses( Linie, LongAddresses );
   END LoadLongAddresses;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SendFile( Dali : PTR; Linie : TDaliLinie; FileToSend : lists.TPBufferList ) : BOOLEAN; // CDaliDevice must deallocate FileToSend by itself
   VAR
      DaliDevice : POINTER TO CDaliDevice := Dali;
   BEGIN
      RETURN DaliDevice^.SendFile( Linie, FileToSend );
   END SendFile;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Dispose();
   VAR
      DaliDevice : POINTER TO CDaliDevice;
      it : maps.CStringPtrMapIterator;
   BEGIN
      Dali.Reset();
      it.Init( Dali, collection.dirForward );
      WHILE it.MoveNext() DO
         DaliDevice := it.Value;
         DaliDevice^.Dispose();
         DISPOSE( DaliDevice );
      END; // WHILE
      Dali.Dispose();
   END Dispose;

(*-------------------------------------------------------------------------------*)

BEGIN
   EventSink := NIL;
   Running := FALSE;
END CDali;

(*===============================================================================*)

END DaliBridge.
