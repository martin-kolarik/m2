IMPLEMENTATION MODULE netconndispatch; // network connections dispatcher

FROM Storage IMPORT
  ALLOCATE, DEALLOCATE;
  
FROM log IMPORT
  logger, TDebugLevel, dldError, dldDebug;

IMPORT
  IOO,
  list,
  lists,
  msghandler,
  Storage,
  StorageO,
  Sync,
  TextReader,
  TextWriter,
  winerror;

//================================================================================
(*/*

3,
3, 3, 1,
2, 2, 1, 1.5,
2

21.4. (3)

-- pri Done ovladaèe se nepozavírají serverová spojení a skonèí to na vw ASSERTu

*/*)
//================================================================================

CLASS IMPLEMENTATION CClientInterface;
  
//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE BindDispatcher( _PDispatcher : TPDispatcher );
  BEGIN
    PDispatcher := _PDispatcher;
  END BindDispatcher;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE Join( RemotePort : CARDINAL; RemoteAddress : winsock.IN_ADDR );
  BEGIN
    IF PDispatcher = NIL THEN
      OnLeave( NIL, winsock.WSAENOTCONN );
    ELSE
      PDispatcher^.Join( ADR( SELF ), RemotePort, RemoteAddress );
    END;
  END Join;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE Leave( Connection : TConnectionHandle );
  BEGIN
    IF PDispatcher = NIL THEN
      OnLeave( NIL, winsock.WSAENOTCONN );
    ELSE
      PDispatcher^.Leave( ADR( SELF ), Connection );
    END;
  END Leave;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE Connect( Connection : TConnectionHandle );
  BEGIN
    IF PDispatcher = NIL THEN
      OnDisconnect( NIL, TRUE, winsock.WSAENOTCONN );
    ELSE
      PDispatcher^.Connect( ADR( SELF ), Connection );
    END;
  END Connect;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE Disconnect( Connection : TConnectionHandle );
  BEGIN
    IF PDispatcher = NIL THEN
      OnDisconnect( NIL, TRUE, winsock.WSAENOTCONN );
    ELSE
      PDispatcher^.Disconnect( ADR( SELF ), Connection );
    END;
  END Disconnect;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE Send( Connection : TConnectionHandle; Id : LONGWORD; PData : ADDRESS; DataLen : CARDINAL );
  BEGIN
    IF PDispatcher = NIL THEN
      OnSent( Connection, Id, winsock.WSAENOTCONN );
    ELSIF PDispatcher^.Connection = ctLine THEN
      OnSent( Connection, Id, winsock.WSAEINVAL );
    ELSE
      PDispatcher^.Send( ADR( SELF ), Connection, Id, PData, DataLen );
    END;
  END Send;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE SendS( Connection : TConnectionHandle; Id : LONGWORD; CONST String : StringsO.IString );
  BEGIN
    IF PDispatcher = NIL THEN
      OnSent( Connection, Id, winsock.WSAENOTCONN );
    ELSIF PDispatcher^.Connection <> ctLine THEN
      OnSent( Connection, Id, winsock.WSAEINVAL );
    ELSE
      PDispatcher^.Send( ADR( SELF ), Connection, Id, String.rawData, String.Length );
    END;
  END SendS;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE SendOA( Connection : TConnectionHandle; Id : LONGWORD; CONST String : ARRAY OF WCHAR );
  BEGIN
    IF PDispatcher = NIL THEN
      OnSent( Connection, Id, winsock.WSAENOTCONN );
    ELSIF PDispatcher^.Connection <> ctLine THEN
      OnSent( Connection, Id, winsock.WSAEINVAL );
    ELSE
      PDispatcher^.Send( ADR( SELF ), Connection, Id, ADR( String ), LENGTH( String ) << 1 );
    END;
  END SendOA;

//--------------------------------------------------------------------------------

  LOCAL VIRTUAL PROCEDURE OnJoin( Connection : TConnectionHandle );
  BEGIN
  END OnJoin;

//--------------------------------------------------------------------------------

  LOCAL VIRTUAL PROCEDURE OnLeave( Connection : TConnectionHandle; Error : CARDINAL );
  BEGIN
  END OnLeave;

//--------------------------------------------------------------------------------

  LOCAL VIRTUAL PROCEDURE OnConnect( Connection : TConnectionHandle; Local : BOOLEAN; Error : CARDINAL );
  BEGIN
  END OnConnect;

//--------------------------------------------------------------------------------

  LOCAL VIRTUAL PROCEDURE OnDisconnect( Connection : TConnectionHandle; Local : BOOLEAN; Error : CARDINAL );
  BEGIN
  END OnDisconnect;

//--------------------------------------------------------------------------------

  LOCAL VIRTUAL PROCEDURE OnReceive( Connection : TConnectionHandle; Data : ADDRESS; DataLen : CARDINAL );
  BEGIN
  END OnReceive;

//--------------------------------------------------------------------------------

  LOCAL VIRTUAL PROCEDURE OnSent( Connection : TConnectionHandle; Id : LONGWORD; Error : CARDINAL );
  BEGIN
  END OnSent;

//--------------------------------------------------------------------------------

BEGIN
  PDispatcher := NIL;
END CClientInterface;

//================================================================================

TYPE
  TCommand = (
    cmNetworkAccept,
    cmNetworkConnect,
    cmNetworkDisconnect,
    cmNetworkReceive,
    cmClientJoin,
    cmClientLeave,
    cmClientConnect,
    cmClientDisconnect,
    cmClientSend
  );
  TMessage  = RECORD
                CASE Command : TCommand OF
                | cmNetworkAccept : 
                  NServerSocket  : netsocket.TPSSocket;

                | cmNetworkConnect,
                  cmNetworkDisconnect,
                  cmNetworkReceive :
                  NSocket : netsocket.TPDSocket;
                  NData : CARDINAL; // error/length
                  NLocal : BOOLEAN;

                | cmClientJoin :
                  JPClient : TPClientInterface;
                  JRemotePort : CARDINAL;
                  JRemoteAddress : winsock.IN_ADDR;

                | cmClientLeave,
                  cmClientConnect,
                  cmClientDisconnect :
                  CPClient : TPClientInterface;
                  CPConnection : TConnectionHandle;

                | cmClientSend :
                  SPClient : TPClientInterface;
                  SPConnection : TConnectionHandle;
                  SPId : LONGWORD;
                  SData : ADDRESS;
                  SLen : CARDINAL;
                END; // CASE
              END;
  TPMessage = POINTER TO TMessage;

//================================================================================

PROCEDURE APQW( Address : winsock.IN_ADDR; Port : CARDINAL ) : QUADWORD;
BEGIN
  RETURN QUADWORD( Address ) << 32 OR QUADWORD( Port );
END APQW;

//================================================================================

TYPE
  TPConnection = POINTER TO CConnection;
  TPListener = POINTER TO CListener;
  TPNotifier = POINTER TO CSocketNotifier;

//--------------------------------------------------------------------------------

CLASS CDatagrammerNotifier( IOO.ADataInfo ); // using separae notifier reduces count of notifications/message posts/void processing
  LOCAL VAR
    Dispatcher : TPDispatcher;
    Connection : TPConnection;
  PUBLIC VIRTUAL PROCEDURE OnReadable( Length : CARDINAL; Source : ADDRESS );
END CDatagrammerNotifier;

//--------------------------------------------------------------------------------

CLASS CConnection( netsocket.DSocket );
  LOCAL VAR
    Clients : lists.CPtrList;
  PRIVATE VAR
    NStream : netstream.CNetworkStream;
    Stream : IOO.CBufferedStream;
    // ctStream uses Stream only
    // ctDatagram
    PDatagrammer : IOO.TPDatagramReader;
    PDatagrammerNotifier : POINTER TO CDatagrammerNotifier;
    // ctLine
    PReader : TextReader.TPTextReader;
  PUBLIC READONLY PROPERTY
    Empty : BOOLEAN;
    IRead : IOO.TPBufferedReader;
    IWrite : IOO.TPStream;
    
  LOCAL PROCEDURE Init( Dispatcher : TPDispatcher; SocketNotifier : netsocket.TPSocketNotifier );

  LOCAL PROCEDURE AddClient( PClient : TPClientInterface ) : BOOLEAN; // FALSE if PClient already known
  LOCAL PROCEDURE RemoveClient( PClient : TPClientInterface ) : BOOLEAN; // FALSE if PClient is unknown

  LOCAL PROCEDURE OnConnect( Local : BOOLEAN; Error : CARDINAL );
  LOCAL PROCEDURE OnDisconnect( Local : BOOLEAN; Error : CARDINAL );
  LOCAL PROCEDURE OnReceive( Data : ADDRESS; DataLen : CARDINAL );

  LOCAL PROCEDURE StartReading();
  LOCAL PROCEDURE Disconnect( Persist : BOOLEAN ); 
END CConnection;

//--------------------------------------------------------------------------------

CLASS CListener( netsrv.AListener );
   PDispatcher : TPDispatcher;
   LOCAL VIRTUAL PROCEDURE OnListen( CONST ServerSocket : netsocket.TPSSocket );
END CListener;
  
//--------------------------------------------------------------------------------

CLASS CSocketNotifier( netsocket.ASocketNotifier );
   LOCAL VAR
      PDispatcher : TPDispatcher;
   // IDataInfo
   PUBLIC VIRTUAL PROCEDURE OnReadable( Length : CARDINAL; Source : ADDRESS );
   // ASocketNotifier
   LOCAL VIRTUAL PROCEDURE OnConnect( Result : CARDINAL; CONST Socket : netsocket.TPDSocket; Local : BOOLEAN ); 
   LOCAL VIRTUAL PROCEDURE OnDisconnect( Result : CARDINAL; CONST Socket : netsocket.TPDSocket; Local : BOOLEAN );
END CSocketNotifier;

//================================================================================

CLASS IMPLEMENTATION CDatagrammerNotifier;

//--------------------------------------------------------------------------------

  PUBLIC VIRTUAL PROCEDURE OnReadable( Length : CARDINAL; Source : ADDRESS );
  BEGIN
    Dispatcher^.OnNetworkReceive( Connection, Length );
  END OnReadable;

//--------------------------------------------------------------------------------

BEGIN
  Dispatcher := NIL;
  Connection := NIL;
END CDatagrammerNotifier;

//================================================================================

CLASS IMPLEMENTATION CConnection;

//--------------------------------------------------------------------------------
  
  PUBLIC PROPERTY Empty GET : BOOLEAN;
  BEGIN
    RETURN Clients.Empty;
  END Empty;

//--------------------------------------------------------------------------------
  
   PUBLIC PROPERTY IRead GET : IOO.TPBufferedReader;
   BEGIN
      IF PReader <> NIL THEN
         RETURN PReader;
      ELSIF PDatagrammer <> NIL THEN
         RETURN PDatagrammer;
      ELSE
         RETURN ADR( Stream );
      END;
   END IRead;

//--------------------------------------------------------------------------------
  
   PUBLIC PROPERTY IWrite GET : IOO.TPStream;
   BEGIN
      RETURN ADR( Stream );
   END IWrite;

//--------------------------------------------------------------------------------
  
   LOCAL PROCEDURE Init( Dispatcher : TPDispatcher; SocketNotifier : netsocket.TPSocketNotifier );
   BEGIN
      CASE Dispatcher^.Connection OF
      //-----
      | ctDatagram :
         NEW( PDatagrammer );
         NEW( PDatagrammerNotifier );
         Stream.Notifier := PDatagrammer;
         PDatagrammer^.Notifier := PDatagrammerNotifier;
         PDatagrammer^.Stream := ADR( Stream );
         PDatagrammerNotifier^.Dispatcher := Dispatcher;
         PDatagrammerNotifier^.Connection := ADR( SELF );

         IF Dispatcher^.PieceSize > 128*1024 THEN
            PDatagrammer^.SelfBuffer := TRUE;
         ELSIF Dispatcher^.PieceSize > Stream.BufferSize THEN
            Stream.BufferSize := ( Dispatcher^.PieceSize DIV 4096 + 1 ) * 4096;
         END;
      //-----
      | ctLine :
         NEW( PReader );
         PReader^.Stream := ADR( Stream );
         PReader^.BufferSize := 80;
      END; // CASE
      Notifier := SocketNotifier;
   END Init;

//--------------------------------------------------------------------------------
  
  LOCAL PROCEDURE AddClient( PClient : TPClientInterface ) : BOOLEAN; // FALSE if PClient already known
  BEGIN
    IF Clients.Contains( PClient ) THEN
      RETURN FALSE;
    ELSE
      Clients.Add( PClient, 0 );
    END;
    PClient^.AddRef();
    PClient^.OnJoin( ADR( SELF ));
    IF Connected THEN
      PClient^.OnConnect( ADR( SELF ), TRUE, 0 );
    END;
    RETURN TRUE;
  END AddClient;

//--------------------------------------------------------------------------------
  
  LOCAL PROCEDURE RemoveClient( PClient : TPClientInterface ) : BOOLEAN; // FALSE if PClient is unknown
  BEGIN
    IF Clients.Contains( PClient ) THEN
      Clients.Remove( PClient );
    ELSE
      RETURN FALSE;
    END;
    IF Connected THEN
      PClient^.OnDisconnect( ADR( SELF ), TRUE, 0 );
    END;
    PClient^.OnLeave( ADR( SELF ), 0 );
    PClient^.Release();
    RETURN TRUE;
  END RemoveClient;

//--------------------------------------------------------------------------------
  
  LOCAL PROCEDURE OnConnect( Local : BOOLEAN; Error : CARDINAL );
  BEGIN
    Clients.Reset();
    WHILE Clients.MoveNext() DO
      TPClientInterface( Clients.Current )^.OnConnect( ADR( SELF ), Local, Error );
    END; // WHILE
  END OnConnect;

//--------------------------------------------------------------------------------
  
  LOCAL PROCEDURE OnDisconnect( Local : BOOLEAN; Error : CARDINAL );
  BEGIN
    Clients.Reset();
    WHILE Clients.MoveNext() DO
      TPClientInterface( Clients.Current )^.OnDisconnect( ADR( SELF ), Local, Error );
    END; // WHILE
  END OnDisconnect;

//--------------------------------------------------------------------------------

  LOCAL PROCEDURE OnReceive( Data : ADDRESS; DataLen : CARDINAL );
  BEGIN
    Clients.Reset();
    WHILE Clients.MoveNext() DO
      TPClientInterface( Clients.Current )^.OnReceive( ADR( SELF ), Data, DataLen );
    END; // WHILE
  END OnReceive;

//--------------------------------------------------------------------------------

  LOCAL PROCEDURE StartReading();
  BEGIN
    IF PReader <> NIL THEN
      PReader^.StartReading(); // Reader call Stream.StartReading internally
    ELSIF PDatagrammer <> NIL THEN
      PDatagrammer^.StartReading(); // Datagrammer.StartReading calls Stream.StartReading internally, so here only Datagrammer.StartReading could be sufficient. The code is clearer.
    ELSE
      Stream.StartReading();
    END;
  END StartReading;

//--------------------------------------------------------------------------------

   LOCAL PROCEDURE Disconnect( Persist : BOOLEAN ); 
   BEGIN
      Stream.Close( Persist );
   END Disconnect;

//--------------------------------------------------------------------------------

BEGIN
   NStream.FromSocket( ADR( SELF ), TRUE, IOO.accReadWrite );
   Stream.Stream := ADR( NStream );
   PDatagrammer := NIL;
   PDatagrammerNotifier := NIL;
   PReader := NIL;
FINALLY
   IF PReader <> NIL THEN
      DISPOSE( PReader );
   END;
   IF PDatagrammerNotifier <> NIL THEN
      PDatagrammerNotifier^.Release();
      PDatagrammerNotifier := NIL;
   END;
   IF PDatagrammer <> NIL THEN
      PDatagrammer^.Release();
      PDatagrammer := NIL;
   END;
   Stream.Close( FALSE );
   Clients.Reset();
   WHILE Clients.MoveNext() DO
      TPClientInterface( Clients.Current )^.Release();
   END; // WHILE
   Clients.Dispose();
END CConnection;

//================================================================================

CLASS IMPLEMENTATION CListener;

//--------------------------------------------------------------------------------

  LOCAL VIRTUAL PROCEDURE OnListen( CONST ServerSocket : netsocket.TPSSocket );
  BEGIN
    PDispatcher^.OnListen( ServerSocket );
  END OnListen;

//--------------------------------------------------------------------------------
  
BEGIN
  PDispatcher := NIL;
END CListener;

//================================================================================

CLASS IMPLEMENTATION CSocketNotifier;

//--------------------------------------------------------------------------------
  
   PUBLIC VIRTUAL PROCEDURE OnReadable( Length : CARDINAL; Source : ADDRESS );
   BEGIN
      IF PDispatcher^.Connection <> ctDatagram THEN // in the case Connection uses self notifier
         PDispatcher^.OnNetworkReceive( netsocket.TPDSocket( Source ), Length );
      END;
   END OnReadable;

//--------------------------------------------------------------------------------

   LOCAL VIRTUAL PROCEDURE OnConnect( Error : CARDINAL; CONST Socket : netsocket.TPDSocket; Local : BOOLEAN );
   BEGIN
      PDispatcher^.OnNetworkConnect( Error, Socket, Local );
   END OnConnect;

//--------------------------------------------------------------------------------

   LOCAL VIRTUAL PROCEDURE OnDisconnect( Error : CARDINAL; CONST Socket : netsocket.TPDSocket; Local : BOOLEAN );
   BEGIN
      PDispatcher^.OnNetworkDisconnect( Error, Socket, Local );
   END OnDisconnect;
  
//--------------------------------------------------------------------------------

BEGIN
   PDispatcher := NIL;
END CSocketNotifier;

//================================================================================

CONST
   logPrefix = L"Net.Dispatcher";
  
PROCEDURE Log( Severity : TDebugLevel; Connection : TPConnection; Text : ARRAY OF WCHAR );
BEGIN
   logger()^.LogS( Severity, logPrefix, Text );
   logger()^.LogSH( Severity, logPrefix, "2 address ", Connection^.RemoteAddress.s_addr );
   logger()^.LogSC( Severity, logPrefix, "3 port ", Connection^.RemotePort );
END Log;
  
//--------------------------------------------------------------------------------
  
CLASS IMPLEMENTATION CDispatcher;

//--------------------------------------------------------------------------------

  PUBLIC PROPERTY Listener GET : netsrv.TPListener;
  BEGIN
    RETURN PListener;
  END Listener;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE Dispose();
  BEGIN
    IF NOT Connections.Empty THEN
      Connections.Reset();
      WHILE Connections.MoveNext() DO WITH TPConnection( Connections.CurrentData )^ DO
        Notifier := NIL;
        Disconnect( FALSE );
        Release();
      END; END; // WITH // WHILE
      Connections.Dispose();
    END;
    IF PListener <> NIL THEN
      PListener^.Release();
      PListener := NIL;
    END;
    IF PNotifier <> NIL THEN
      PNotifier^.Release();
      PNotifier := NIL;
    END;
  END Dispose;

//--------------------------------------------------------------------------------

  INTERNAL VIRTUAL PROCEDURE OnMessage( CONST MSG : msghandler.IMessage; OUT Result : CARDINAL ) : BOOLEAN;
  VAR
    a : ADDRESS;
    Connection : TPConnection;
    CurrentConnection : TPConnection;
    Error : CARDINAL;
    IRead : IOO.TPBufferedReader;
    Len : CARDINAL;
    MDatagram : IOO.CMemoryProxy;
    Message : TMessage;
    NResult : Sync.TAsyncResult;
    QWA : QUADWORD;
    WDatagram : IOO.CDatagramProxy;
    Writer : TextWriter.CTextWriter;
    b : BOOLEAN;
    Known : BOOLEAN;
  BEGIN
    IF SUPER.OnMessage( MSG, OUT Result ) THEN
      RETURN TRUE;
    END;
    
    CASE MSG.Message OF
    //-----
    | msgqueue.WM_MQ_PROCESS :
      WHILE MQueue.DequeueOA( OUT Message ) DO
        CASE Message.Command OF
        //-----
        | cmNetworkAccept :
          NEW( Connection ); Connection^.Init( ADR( SELF ), PNotifier );
          IF Connection^.Accept( Message.NServerSocket, OUT Error ) = Sync.arCompleted THEN
            Log( dldDebug, Connection, "Accept" );

            QWA := APQW( Connection^.RemoteAddress, Connection^.RemotePort );
            IF Connections.Get( QWA, OUT CurrentConnection ) THEN
              Log( dldError, Connection, "Accept connection already exists" );

              // this should not occur -- two same connections are impossible, but it can be state after undetected failure
              Connection^.Notifier := NIL;
              CurrentConnection^.AcceptFrom( REF Connection, OUT Error );
              Connection^.Release();
            ELSE
              Connections.Add( QWA, Connection );
            END;
          ELSE
            Connection^.Disconnect( FALSE );
            Connection^.Release();
          END;

        //-----
        | cmNetworkConnect :
          Connection := TPConnection( Message.NSocket );
          IF Connections.Contains( APQW( Connection^.RemoteAddress, Connection^.RemotePort )) THEN
            Log( dldDebug, Connection, L"Connect" );
          ELSE
            Log( dldError, Connection, L"Connect on unknown connection" );
          END;

          Connection^.OnConnect( Message.NLocal, Message.NData );
          OnConnect( Connection, Message.NLocal, Message.NData );
          IF Connection^.Connected THEN
            Connection^.StartReading();
          END;

        //-----
        | cmNetworkDisconnect :
          Connection := TPConnection( Message.NSocket );

          QWA := APQW( Connection^.RemoteAddress, Connection^.RemotePort );
          IF Connections.Contains( QWA ) THEN
            Log( dldDebug, Connection, L"Disconnect" );

            Connection^.OnDisconnect( Message.NLocal, Message.NData ); // dispatch event to the clients
            OnDisconnect( Connection, Message.NLocal, Message.NData );
            IF Connection^.Empty THEN
              Connections.Remove( QWA );
              Connection^.Disconnect( FALSE );
              Connection^.Release();
            ELSE
              Connection^.Disconnect( TRUE ); // flushing of buffers, redundant underlying stream close
            END;

          ELSE
            Log( dldDebug, Connection, L"Disconnect on unknown connection" );
          END;

        //-----
        | cmNetworkReceive :
          Connection := TPConnection( Message.NSocket );

          Log( dldDebug, Connection, L"Receive " );
          QWA := APQW( Connection^.RemoteAddress, Connection^.RemotePort );
          ASSERT( Connections.Contains( QWA ));

          IRead := Connection^.IRead;
          WHILE IRead^.Peek( OUT a, OUT Len ) DO
            OnReceive( Connection, a, Len );
            Connection^.OnReceive( a, Len );
            IRead^.ReadOut( Len );
          END; // WHILE

        //-----
        | cmClientJoin :
          logger()^.LogSP( dldDebug, logPrefix, L"Join ", Message.CPClient );

          QWA := APQW( Message.JRemoteAddress, Message.JRemotePort );
          IF Connections.Get( QWA, OUT Connection ) THEN
            Log( dldDebug, Connection, L". to existing connection" );

          ELSE
            NEW( Connection ); Connection^.Init( ADR( SELF ), PNotifier );
            Connection^.RemoteAddress := Message.JRemoteAddress;
            Connection^.RemotePort := Message.JRemotePort;
            Connections.Add( QWA, Connection );

            Log( dldDebug, Connection, L". to new connection" );
          END;
          IF Connection^.AddClient( Message.JPClient ) THEN // OnJoin/OnConnected called inside
            OnClientJoin( Connection, Message.JPClient );
          END;
          Message.JPClient^.Release(); // temporary

        //-----
        | cmClientLeave :
          Known := Message.CPConnection <> NIL;
          IF Known THEN // unknown/promiscuous client close
            logger()^.LogSP( dldDebug, logPrefix, L"Leave from single connection ", Message.CPClient );
            IF Connections.Contains( APQW( Message.CPConnection^.RemoteAddress, Message.CPConnection^.RemotePort )) THEN
               Log( dldDebug, TPConnection( Message.CPConnection ), L". from known connection" );
            ELSE
               Log( dldError, TPConnection( Message.CPConnection ), L". from unknown connection" );
            END;

            b := TRUE;
            Connection := TPConnection( Message.CPConnection );
          ELSE
            logger()^.LogSP( dldDebug, logPrefix, L"Leave from all connections ", Message.CPClient );

            Connections.Reset();
            b := Connections.MoveNext();
            Connection := Connections.CurrentData;
          END;
          WHILE b DO
            IF Connection^.RemoveClient( Message.CPClient ) THEN // OnDisconnect/OnLeave called inside
              OnClientLeave( Connection, Message.CPClient );
            ELSE
              ASSERT( NOT Known );
            END;
            IF Connection^.Empty THEN
              IF Connection^.Connected THEN
                OnDisconnect( Connection, TRUE, 0 ); // network disconnect will not be accepted as Connection is removed now
              END;
              Connections.Remove( APQW( Connection^.RemoteAddress, Connection^.RemotePort ));
              Connection^.Disconnect( FALSE );
              Connection^.Release();
              b := FALSE; // Connection was deleted
            END;
            IF Known THEN
              EXIT;
            ELSIF NOT b THEN // Connection was deleted
              Connections.Reset();
            END;
            b := Connections.MoveNext();
            Connection := Connections.CurrentData;
          END; // WHILE
          Message.CPClient^.Release(); // temporary

        //-----
        | cmClientConnect :
          Known := Message.CPConnection <> NIL;
          IF Known THEN // unknown/promiscuous client close
            logger()^.LogSP( dldDebug, logPrefix, L"Connect ", Message.CPClient );
            IF Connections.Contains( APQW( Message.CPConnection^.RemoteAddress, Message.CPConnection^.RemotePort )) THEN
               Log( dldDebug, TPConnection( Message.CPConnection ), L". to known connection" );
            ELSE
               Log( dldError, TPConnection( Message.CPConnection ), L". to unknown connection" );
            END;

            b := TRUE;
            Connection := TPConnection( Message.CPConnection );
          ELSE
            logger()^.LogSP( dldDebug, logPrefix, L"Connect to all connections ", Message.CPClient );

            Connections.Reset();
            b := Connections.MoveNext();
            Connection := Connections.CurrentData;
          END;
          WHILE b DO
            IF NOT Connection^.Connected THEN
              NResult := Connection^.ConnectAddress( Connection^.RemoteAddress, Connection^.RemotePort, Sync.INFINITE_TIME );
              IF NResult NOT IN Sync.arsStarts THEN
                Message.CPClient^.OnConnect( Connection, TRUE, winsock.WSAECONNREFUSED );
              END;
            END;
            IF Known THEN
              EXIT;
            ELSE
              b := Connections.MoveNext();
              Connection := Connections.CurrentData;
            END;
          END; // WHILE

        //-----
        | cmClientDisconnect :
          Known := Message.CPConnection <> NIL;
          IF Known THEN // unknown/promiscuous client close
            logger()^.LogSP( dldDebug, logPrefix, L"Disconnect ", Message.CPClient );
            IF Connections.Contains( APQW( Message.CPConnection^.RemoteAddress, Message.CPConnection^.RemotePort )) THEN
               Log( dldDebug, TPConnection( Message.CPConnection ), L". from known connection" );
            ELSE
               Log( dldError, TPConnection( Message.CPConnection ), L". from unknown connection" );
            END;

            b := TRUE;
            Connection := TPConnection( Message.CPConnection );
          ELSE
            logger()^.LogSP( dldDebug, logPrefix, L"Disconnect from all connections ", Message.CPClient );

            Connections.Reset();
            b := Connections.MoveNext();
            Connection := Connections.CurrentData;
          END;
          WHILE b DO
            Connection^.Disconnect( TRUE );
            IF Known THEN
              EXIT;
            ELSE
              b := Connections.MoveNext();
              Connection := Connections.CurrentData;
            END;
          END; // WHILE

        //-----
        | cmClientSend :
          Known := Message.SPConnection <> NIL;
          IF Known THEN // unknown/promiscuous client close
            logger()^.LogSP( dldDebug, logPrefix, L"Send ", Message.CPClient );
            IF Connections.Contains( APQW( Message.CPConnection^.RemoteAddress, Message.CPConnection^.RemotePort )) THEN
               Log( dldDebug, TPConnection( Message.CPConnection ), L". to known connection" );
               b := TRUE;
               Connection := TPConnection( Message.SPConnection );
            ELSE
               Log( dldDebug, TPConnection( Message.CPConnection ), L". to unknown connection" );
               // the only possibility is, that connection is server, closed now, and notified to client. So, simply ignore everything.
               b := FALSE;
            END;

          ELSE
            logger()^.LogSP( dldDebug, logPrefix, L"Send to all connections ", Message.CPClient );

            Connections.Reset();
            b := Connections.MoveNext();
            Connection := Connections.CurrentData;
          END;

          WHILE b DO

            CASE SELF.Connection OF
            | ctStream :
               MDatagram.Init( Message.SData, Message.SLen, FALSE );
               NResult := Connection^.IWrite^.Write( ADR( MDatagram ), Sync.INFINITE_TIME, TRUE );
            | ctDatagram :
               WDatagram.Init( Message.SData, Message.SLen, FALSE );
               NResult := Connection^.IWrite^.Write( ADR( WDatagram ), Sync.INFINITE_TIME, TRUE );
            | ctLine :
               Writer.Stream := Connection^.IWrite;
               Writer.WriteM( PWCHAR( Message.SData ), Message.SLen >> 1, TRUE );
            END;
            IF Message.SPClient <> NIL THEN
              IF NResult IN Sync.arsCompletions THEN
                Message.SPClient^.OnSent( Connection, Message.SPId, 0 );
              ELSE
                Message.SPClient^.OnSent( Connection, Message.SPId, winerror.ERROR_ACCESS_DENIED );
              END;
            END;
            IF Known THEN
              EXIT;
            ELSE
              b := Connections.MoveNext();
              Connection := Connections.CurrentData;
            END;
          END; // WHILE
          DISPOSE( Message.SData );

        ELSE
          logger()^.LogSC( dldError, logPrefix, L"Unrecognized command ", CARDINAL( Message.Command ));

        END; // CASE
      END; // WHILE

    ELSE
      RETURN FALSE;
    END; // CASE
    
    Result := 0;
    RETURN TRUE;  
  END OnMessage;

//--------------------------------------------------------------------------------
  
  LOCAL PROCEDURE OnListen( CONST ServerSocket : netsocket.TPSSocket );
  VAR
    Message : TMessage;
  BEGIN
    // OnListen is in GUI thread, so posting there is not neccessary
    Message.Command := cmNetworkAccept;
    Message.NServerSocket := ServerSocket;
    MQueue.QueueOA( Message );
  END OnListen;

//--------------------------------------------------------------------------------
  
  LOCAL PROCEDURE OnNetworkConnect( Error : CARDINAL; CONST Socket : netsocket.TPDSocket; Local : BOOLEAN );
  VAR
    Message : TMessage;
  BEGIN
    Message.Command := cmNetworkConnect;
    Message.NSocket := Socket;
    Message.NData := Error;
    Message.NLocal := Local;
    MQueue.QueueOA( Message );
  END OnNetworkConnect;

//--------------------------------------------------------------------------------
  
  LOCAL PROCEDURE OnNetworkDisconnect( Error : CARDINAL; CONST Socket : netsocket.TPDSocket; Local : BOOLEAN );
  VAR
    Message : TMessage;
  BEGIN
    Message.Command := cmNetworkDisconnect;
    Message.NSocket := Socket;
    Message.NData := Error;
    Message.NLocal := Local;
    MQueue.QueueOA( Message );
  END OnNetworkDisconnect;

//--------------------------------------------------------------------------------
  
  LOCAL PROCEDURE OnNetworkReceive( CONST Socket : netsocket.TPDSocket; Length : CARDINAL );
  VAR
    Message : TMessage;
  BEGIN
    IF Length = 0 THEN
      RETURN;
    END;
    Message.Command := cmNetworkReceive;
    Message.NSocket := Socket;
    Message.NData := Length;
    MQueue.QueueOA( Message );
  END OnNetworkReceive;

//--------------------------------------------------------------------------------
  
  INTERNAL VIRTUAL PROCEDURE OnConnect( PConnection : TConnectionHandle; Local : BOOLEAN; Error : CARDINAL );
  BEGIN
  END OnConnect;

//--------------------------------------------------------------------------------
  
  INTERNAL VIRTUAL PROCEDURE OnDisconnect( PConnection : TConnectionHandle; Local : BOOLEAN; ErrorCode : CARDINAL );
  BEGIN
  END OnDisconnect;

//--------------------------------------------------------------------------------
  
  INTERNAL VIRTUAL PROCEDURE OnReceive( PConnection : TConnectionHandle; PData : ADDRESS; DataLen : CARDINAL );
  BEGIN
  END OnReceive;

//--------------------------------------------------------------------------------
  
  INTERNAL VIRTUAL PROCEDURE OnClientJoin( PConnection : TConnectionHandle; PClientInterface : TPClientInterface );
  BEGIN
  END OnClientJoin;

//--------------------------------------------------------------------------------
  
  INTERNAL VIRTUAL PROCEDURE OnClientLeave( PConnection : TConnectionHandle; PClientInterface : TPClientInterface );
  BEGIN
  END OnClientLeave;

//--------------------------------------------------------------------------------
  
  LOCAL PROCEDURE Join( PClient : TPClientInterface; RemotePort : CARDINAL; RemoteAddress : winsock.IN_ADDR ); // asynchronous, results in Client.OnConnect
  VAR
    Message : TMessage;
  BEGIN
    Message.Command := cmClientJoin;
    Message.JPClient := PClient;
    Message.JPClient^.AddRef(); // temporary
    Message.JRemotePort := RemotePort;
    Message.JRemoteAddress := RemoteAddress;
    MQueue.QueueOA( Message );
    // make Join synchronous (to allow clients synchronously store their records)
    MQueue.PushToConsumer();
  END Join;

//--------------------------------------------------------------------------------
  
  LOCAL PROCEDURE Leave( PClient : TPClientInterface; Connection : TConnectionHandle ); // asynchronous, results in Client.OnDisconnect and Done
  VAR
    Message : TMessage;
  BEGIN
    Message.Command := cmClientLeave;
    Message.CPClient := PClient;
    Message.CPClient^.AddRef(); // temporary
    Message.CPConnection := Connection;
    MQueue.QueueOA( Message );
    // make Leave synchronous (to allow clients synchronously remove their records)
    MQueue.PushToConsumer();
  END Leave;

//--------------------------------------------------------------------------------
  
  LOCAL PROCEDURE Connect( PClient : TPClientInterface; Connection : TConnectionHandle ); // asynchronous, results in Client.OnConnect
  VAR
    Message : TMessage;
  BEGIN
    Message.Command := cmClientConnect;
    Message.CPClient := PClient;
    Message.CPConnection := Connection;
    MQueue.QueueOA( Message );
  END Connect;

//--------------------------------------------------------------------------------

  LOCAL PROCEDURE Disconnect( PClient : TPClientInterface; Connection : TConnectionHandle ); // asynchronous, results in Client.OnDisconnect
  VAR
    Message : TMessage;
  BEGIN
    Message.Command := cmClientDisconnect;
    Message.CPClient := PClient;
    Message.CPConnection := Connection;
    MQueue.QueueOA( Message );
  END Disconnect;

//--------------------------------------------------------------------------------

  LOCAL PROCEDURE Send( PClient : TPClientInterface; Connection : TConnectionHandle; ClientId : LONGWORD; PData : ADDRESS; DataLen : CARDINAL ); // asynchronous, results in Client.OnSend
  VAR
    Message : TMessage;
  BEGIN
    Message.Command := cmClientSend;
    Message.SPClient := PClient;
    Message.SPConnection := Connection;
    Message.SPId := ClientId;
    Message.SLen := DataLen;
    ALLOCATE( Message.SData, DataLen );
    Storage.Move( PData, Message.SData, DataLen );
    MQueue.QueueOA( Message );
  END Send;

//--------------------------------------------------------------------------------

BEGIN
  MQueue.Init( 256, SIZE( TMessage ));
  MQueue.FlushIfFull := TRUE;
  MQueue.Consumer := ADR( SELF );
  NEW( TPListener( PListener )); TPListener( PListener )^.PDispatcher := ADR( SELF );
  NEW( TPNotifier( PNotifier )); TPNotifier( PNotifier )^.PDispatcher := ADR( SELF );
FINALLY
  Dispose();
END CDispatcher;

//================================================================================

END netconndispatch.