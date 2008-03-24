IMPLEMENTATION MODULE DaliSci;

IMPORT
   Log,
   netsocket,
   netsrv,
   netpool,
   Strings,
   Sync,
   threadpool,
   time;

(*===============================================================================*)

CLASS CUDPCommunicator( netsrv.AListener ) IMPLEMENTS threadpool.ITimeoutSink;
   CONST
      timerTimeout = 1;
      timerDelay = 2;
   PRIVATE VAR
      Address : netsocket.INETADDR;
      ListenPort : CARDINAL;
      Socket : netsocket.TPSSocket := NIL;
      TimerSink : threadpool.TPSinkDelegate;
      Timeout : Sync.WAITABLE;
      Delay : Sync.WAITABLE;
      LastSend : CARDINAL;
   LOCAL VAR
      EventSink : TPICommunicatorSink;
      InterPacketDelay : CARDINAL;
      
   TYPE
      TDaliSciPacket = ARRAY [0..7] OF BYTE; // 4 bytes SCI, 3 bytes DALI, 1 SCI XOR byte

   PUBLIC PROCEDURE SetSciDeviceAddress( DeviceAddress : ARRAY OF WCHAR; LocalListenPort : CARDINAL );
   PUBLIC PROCEDURE Run() : Sync.TAsyncResult;
   PUBLIC PROCEDURE Stop();

   PUBLIC PROCEDURE SendDaliData( Data : ARRAY OF BYTE ) : Sync.TAsyncResult;

   // AListener
   LOCAL VIRTUAL PROCEDURE OnDatagramReceived( CONST ServerSocket : netsocket.TPSSocket ); // stDatagram
   
   // ITimeoutSink
   LOCAL VIRTUAL PROCEDURE OnTimeout( Result : Sync.TAsyncResult; PoolHandle : Sync.WAITABLE; UserId : PTR );
END CUDPCommunicator;

TYPE
   TPCommunicator = POINTER TO CUDPCommunicator;

(*-------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CUDPCommunicator;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SetSciDeviceAddress( DeviceAddress : ARRAY OF WCHAR; LocalListenPort : CARDINAL );
   BEGIN
      Address.SetAddressOA( DeviceAddress );
      ListenPort := LocalListenPort;
   END SetSciDeviceAddress;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Run() : Sync.TAsyncResult;
   VAR
      Result : CARDINAL;
   BEGIN
      IF Socket <> NIL THEN
         RETURN Sync.arAlreadyPending;
      END;
      Result := netsrv.StartListen( netsocket.stDatagram, ListenPort, NIL, ADR( SELF ), 0, ADR( Socket ));
      IF Result = 0 THEN
         RETURN Sync.arCompleted;
      ELSE
         Log.logger()^.LogSE( Log.dlcWarning, LIBRARY, L"Unable StartListen: ", Result );
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

   PUBLIC PROCEDURE SendDaliData( Data : ARRAY OF BYTE ) : Sync.TAsyncResult;
   VAR
      i : CARDINAL;
      delay : INTEGER;
      SendData : TDaliSciPacket := TDaliSciPacket( 0A3H, 0, 0, 0, 0, 0, 0, 0 );
      xor : BYTE;
   BEGIN
      IF Socket = NIL THEN
         RETURN Sync.arCannotStart;
      END;
      delay := INTEGER( time.UptimeMS() - LastSend );
      IF ( InterPacketDelay > 0 ) AND ( delay < INTEGER( InterPacketDelay )) THEN // wait
         IF Delay = NIL THEN
            netpool.Pool()^.WaitTimeout( TimerSink, timerDelay, delay, TRUE, TRUE, OUT Timeout );
         END;   
         RETURN Sync.arAlreadyPending;
      END;
      LastSend := time.UptimeMS();

      // copy data and compute xor
      xor := SendData[0];
      FOR i := 1 TO 3 DO
         xor := xor XOR SendData[i];
      END;
      FOR i := 0 TO HIGH( Data ) DO
         SendData[4+i] := Data[i];
         xor := xor XOR Data[i];
      END;
      SendData[4+HIGH( Data )+1] := xor;
      
      IF Timeout <> NIL THEN
         netpool.Pool()^.Abort( REF Timeout );
      END;
      IF Timeout = NIL THEN
         netpool.Pool()^.WaitTimeout( TimerSink, timerTimeout, 200, TRUE, TRUE, OUT Timeout );
      END;
      
      RETURN Socket^.SendTo6OA( OA( 4 + HIGH( Data ) + 1, ADR( SendData )), Address );
   END SendDaliData;

(*-------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnDatagramReceived( CONST ServerSocket : netsocket.TPSSocket );
   LABEL
      Error;
   VAR
      buffer : TDaliSciPacket;
      dali : TDaliSciPacket;
      i, l : CARDINAL;
      xor : BYTE;
   BEGIN
      IF Timeout <> NIL THEN
         netpool.Pool()^.Abort( REF Timeout );
      END;
   
      ServerSocket^.ReceiveOA( OUT buffer, OUT l );
      IF l < 3 THEN // some damaged data
         RETURN;
      ELSIF EventSink = NIL THEN
         RETURN;
      ELSE
         CASE CARD8( buffer[0] ) OF
         | 051H, 052H : // OK
            // fall down
         | 053H : // denial, device is busy
            EventSink^.OnDaliData( Sync.arAlreadyPending, OA( -1, NIL ));
            RETURN;
         ELSE
            GOTO Error;   
         END;
      
         xor := buffer[0];
         FOR i := 1 TO l-2 DO
            xor := xor XOR buffer[i];
            dali[i-1] := buffer[i];
         END;
         IF xor <> buffer[l-1] THEN // xor OK
            GOTO Error;
         END;

         EventSink^.OnDaliData( Sync.arCompleted, OA( l-3, ADR( dali )));
         RETURN;
      END;
      
   Error:
      EventSink^.OnDaliData( Sync.arAborted, OA( -1, NIL ));
   END OnDatagramReceived;

(*-------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnTimeout( Result : Sync.TAsyncResult; PoolHandle : Sync.WAITABLE; UserId : PTR );
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

   EventSink := NIL;
   InterPacketDelay := 0;
FINALLY
   IF Timeout <> NIL THEN
      netpool.Pool()^.Abort( REF Timeout );
   END;
   IF Delay <> NIL THEN
      netpool.Pool()^.Abort( REF Delay );
   END;

   IF TimerSink <> NIL THEN
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

CLASS DaliRequest;
   LOCAL VAR
      Pending : BOOLEAN;
      Repeated : BOOLEAN;
      Address : DaliAddress;
      Command : TDaliCommand;
      Data : CARD8;
END DaliRequest;

(*-------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION DaliRequest;
BEGIN
   Pending := FALSE;
   Repeated := FALSE;
   Command := cmdOff;
   Data := 0;
END DaliRequest;

(*===============================================================================*)

CLASS IMPLEMENTATION CDali;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Dispose();
   VAR
      data : PTR;
      Request : POINTER TO DaliRequest;
   BEGIN
      WHILE Queue.Dequeue( OUT Request, OUT data ) DO
         DISPOSE( Request );
      END; // WHILE
   END Dispose;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE LoadConfiguration( CONST INI : INIFile.CINIFile; REF logger : log.CLogger ) : BOOLEAN;
   BEGIN
      Communicator^.SetSciDeviceAddress( "10.0.0.10:4001", 4001 );
   
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

   PUBLIC PROCEDURE Command( CONST daliAddress : DaliAddress; _Command : TDaliCommand; Data : CARD8; CONST ClientId : PTR ) : Sync.TAsyncResult;
   VAR
      Request : POINTER TO DaliRequest := NEW( DaliRequest );
   BEGIN
      Request^.Address := daliAddress;
      Request^.Command := _Command;
      Request^.Data := Data;
      Request^.Repeated := _Command IN repeatedCommands;
      Queue.Enqueue( Request, ClientId );
      
      RETURN Communicate();
   END Command;
   
(*-------------------------------------------------------------------------------*)

   // ICommunicationSink -- in thread
   LOCAL VIRTUAL PROCEDURE OnSendable();
   BEGIN
      Communicate();
   END OnSendable;

(*-------------------------------------------------------------------------------*)

   // ICommunicationSink -- in thread
   LOCAL VIRTUAL PROCEDURE OnTimeout();
   BEGIN
      OnDaliData( Sync.arTimeout, OA( -1, NIL ));
   END OnTimeout;

(*-------------------------------------------------------------------------------*)

   // ICommunicationSink -- in thread
   LOCAL VIRTUAL PROCEDURE OnDaliData( Result : Sync.TAsyncResult; Data : ARRAY OF BYTE );
   VAR
      ClientId : PTR;
      Response : CARD8 := 0;
      Request : POINTER TO DaliRequest;
   BEGIN
      IF Queue.GetFirst( OUT Request, OUT ClientId ) THEN
         IF Result = Sync.arAlreadyPending THEN
            Request^.Pending := FALSE; // allow new send
         ELSIF Request^.Repeated THEN
            Request^.Repeated := FALSE;   
            Request^.Pending := FALSE; // allow new send for the second time
         ELSE
            Queue.Dequeue( OUT Request, OUT ClientId );
            IF EventSink <> NIL THEN
               IF Result = Sync.arCompleted THEN
                  IF ( Request^.Command <> cmdCurrentLevel ) OR ( Data[0] < 0FFH ) THEN
                     Response := Data[0];
                  ELSE
                     Response := 0;
                  END;
               END;            
               EventSink^.OnCompletion( Result, Request^.Command, ClientId, Request^.Address, Response );
            END;
            DISPOSE( Request );
         END;
      END; // IF something in the Queue
         
      Communicate();
   END OnDaliData;

(*-------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Communicate() : Sync.TAsyncResult;
   VAR
      DaliData : ARRAY [0..1] OF BYTE;
      Data : PTR;
      Result : Sync.TAsyncResult;
      Request : POINTER TO DaliRequest;
   BEGIN
      IF NOT Queue.GetFirst( OUT Request, OUT Data ) THEN
         RETURN Sync.arCompleted;
      ELSIF Request^.Pending THEN
         RETURN Sync.arAlreadyPending;
      ELSE
         Request^.Pending := TRUE;
      END;
      
      // prepare Dali packet
      IF Request^.Command = cmdLoadDTR THEN
         DaliData[0] := BYTE( Request^.Command );
         DaliData[1] := MIN2( 0FEH, Request^.Data );
      ELSIF Request^.Command = cmdDirect THEN
         DaliData[0] := Request^.Address.TransportAddress AND NOT 01H;
         DaliData[1] := MIN2( 0FEH, Request^.Data );
      ELSE
         DaliData[0] := Request^.Address.TransportAddress OR 01H;
         DaliData[1] := BYTE( Request^.Command );
      END;
      
      Result := Communicator^.SendDaliData( DaliData );
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
   Communicator := NEW( CUDPCommunicator );
   Communicator^.EventSink := TPICommunicatorSink( ADR( SELF ));
   EventSink := NIL;
FINALLY
   IF Communicator <> NIL THEN
      Communicator^.Release();
      Communicator := NIL;
   END;
   Dispose();
END CDali;

(*===============================================================================*)

END DaliSci.