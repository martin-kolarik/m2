IMPLEMENTATION MODULE netconndispatch; // network connections dispatcher

IMPORT
   winsock;

FROM Storage IMPORT
  ALLOCATE, DEALLOCATE;
  
FROM log IMPORT
  logger, TDebugLevel, dldError, dldTrace, dldDebug;

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

  PUBLIC PROCEDURE Join( RemoteAddress : inetaddr.INETADDR );
  BEGIN
    IF PDispatcher = NIL THEN
      OnLeave( NIL, winsock.WSAENOTCONN );
    ELSE
      PDispatcher^.Join( ADR( SELF ), RemoteAddress );
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
    cmNetworkReceiveContinue,
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
                  cmNetworkDisconnect :
                  NCSocket : netsocket.TPDSocket;
                  NCError : CARDINAL;
                  NCLocal : BOOLEAN;
                | cmNetworkReceive,
                  cmNetworkReceiveContinue :
                  NRSocket : netsocket.TPDSocket;
                  NRData : ADDRESS;
                  NRLen : CARDINAL;

                | cmClientJoin :
                  JPClient : TPClientInterface;
                  JRemoteAddress : inetaddr.INETADDR;

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
VAR
   address : ARRAY [0..63] OF WCHAR;
BEGIN
   Connection^.RemoteAddress.GetAddressOA( TRUE, OUT address );

   logger()^.LogS( Severity, logPrefix, Text );
   logger()^.LogSS( Severity, logPrefix, "  address ", address );
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

  INTERNAL VIRTUAL PROCEDURE OnMessage( CONST MSG : msghandler.IMessage; OUT Result : PTR ) : BOOLEAN;
  VAR
    Message : TMessage;
  BEGIN
    IF SUPER.OnMessage( MSG, OUT Result ) THEN
      RETURN TRUE;
    END;
    
    CASE MSG.Message OF
    //-----
    | msgqueue.MSG_PROCESS_QUEUE :
      WHILE CQueue.DequeueOA( OUT Message, FALSE, 0 ) = Sync.arCompleted DO
         DoMessage( ADR( Message ));
      END; // WHILE

    //-----
    | msgqueue.MSG_PROCESS_QUEUE + 1 :
      WHILE NQueue.DequeueOA( OUT Message, FALSE, 0 ) = Sync.arCompleted DO
         DoMessage( ADR( Message ));
      END; // WHILE

    //-----
    ELSE
      RETURN FALSE;
    END; // CASE
    
    Result := 0;
    RETURN TRUE;  
  END OnMessage;

//--------------------------------------------------------------------------------
  
  PRIVATE PROCEDURE DoMessage( message : ADDRESS );
  VAR
    b : BOOLEAN;
    Connection : TPConnection;
    CurrentConnection : TPConnection;
    Error : CARDINAL;
    Known : BOOLEAN;
    MDatagram : IOO.CMemoryProxy;
    Message : TPMessage := TPMessage( message );
    NResult : Sync.TAsyncResult;
    WDatagram : IOO.CDatagramProxy;
    Writer : TextWriter.CTextWriter;
  BEGIN
     CASE Message^.Command OF
     //-----
     | cmNetworkAccept :
       NEW( Connection ); Connection^.Init( ADR( SELF ), PNotifier );
       IF Connection^.Accept( Message^.NServerSocket, OUT Error ) = Sync.arCompleted THEN
         Log( dldTrace, Connection, "Accept.Net" );

         IF Connections.Get( Connection^.RemoteAddress, OUT CurrentConnection ) THEN
           Log( dldError, Connection, "Accept connection already exists" );

           // this should not occur -- two same connections are impossible, but it can be state after undetected failure
           Connection^.Notifier := NIL;
           CurrentConnection^.AcceptFrom( REF Connection, OUT Error );
           Connection^.Release();
         ELSE
           Connections.Add( Connection^.RemoteAddress, Connection );
         END;
       ELSE
         Connection^.Disconnect( FALSE );
         Connection^.Release();
       END;

     //-----
     | cmNetworkConnect :
       Connection := TPConnection( Message^.NCSocket );
       IF Connections.Contains( Connection^.RemoteAddress ) THEN
         Log( dldTrace, Connection, L"Connect.Net" );
       ELSE
         Log( dldError, Connection, L"Connect on unknown connection" );
       END;

       Connection^.OnConnect( Message^.NCLocal, Message^.NCError );
       OnConnect( Connection, Message^.NCLocal, Message^.NCError );
       IF Connection^.Connected THEN
         Connection^.StartReading();
       END;

     //-----
     | cmNetworkDisconnect :
       Connection := TPConnection( Message^.NCSocket );

       IF Connections.Contains( Connection^.RemoteAddress ) THEN
         Log( dldTrace, Connection, L"Disconnect.Net" );

         Connection^.OnDisconnect( Message^.NCLocal, Message^.NCError ); // dispatch event to the clients
         OnDisconnect( Connection, Message^.NCLocal, Message^.NCError );
         IF Connection^.Empty THEN
           Connections.Remove( Connection^.RemoteAddress );
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
       Connection := TPConnection( Message^.NRSocket );

       logger()^.LogSC( dldDebug, logPrefix, L"Receive bytes ", Message^.NRLen );
       Log( dldDebug, Connection, L". from connection " );

       ASSERT( Connections.Contains( Connection^.RemoteAddress ));

       OnReceive( Connection, Message^.NRData, Message^.NRLen );
       Connection^.OnReceive( Message^.NRData, Message^.NRLen );

       DISPOSE( Message^.NRData );
       
     //----
     | cmNetworkReceiveContinue :
       Connection := TPConnection( Message^.NRSocket );

       ASSERT( Connections.Contains( Connection^.RemoteAddress ));
       Log( dldTrace, Connection, L"Receive continue" );

       Connection^.StartReading();

     //-----
     | cmClientJoin :
       logger()^.LogSP( dldTrace, logPrefix, L"Join ", Message^.CPClient );

       IF Connections.Get( Message^.JRemoteAddress, OUT Connection ) THEN
         Log( dldDebug, Connection, L". to existing connection" );

       ELSE
         NEW( Connection ); Connection^.Init( ADR( SELF ), PNotifier );
         Connection^.RemoteAddress := Message^.JRemoteAddress;
         Connections.Add( Message^.JRemoteAddress, Connection );

         Log( dldDebug, Connection, L". to new connection" );
       END;
       IF Connection^.AddClient( Message^.JPClient ) THEN // OnJoin/OnConnected called inside
         OnClientJoin( Connection, Message^.JPClient );
       END;
       Message^.JPClient^.Release(); // temporary

     //-----
     | cmClientLeave :
       Known := Message^.CPConnection <> NIL;
       IF Known THEN // unknown/promiscuous client close
         logger()^.LogSP( dldTrace, logPrefix, L"Leave from single connection ", Message^.CPClient );
         IF Connections.Contains( Message^.CPConnection^.RemoteAddress ) THEN
            Log( dldDebug, TPConnection( Message^.CPConnection ), L". from known connection" );
         ELSE
            Log( dldError, TPConnection( Message^.CPConnection ), L". from unknown connection" );
         END;

         b := TRUE;
         Connection := TPConnection( Message^.CPConnection );
       ELSE
         logger()^.LogSP( dldDebug, logPrefix, L"Leave from all connections ", Message^.CPClient );

         Connections.Reset();
         b := Connections.MoveNext();
         Connection := Connections.CurrentData;
       END;
       WHILE b DO
         IF Connection^.RemoveClient( Message^.CPClient ) THEN // OnDisconnect/OnLeave called inside
           OnClientLeave( Connection, Message^.CPClient );
         ELSE
           ASSERT( NOT Known );
         END;
         IF Connection^.Empty THEN
           IF Connection^.Connected THEN
             OnDisconnect( Connection, TRUE, 0 ); // network disconnect will not be accepted as Connection is removed now
           END;
           Connections.Remove( Connection^.RemoteAddress );
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
       Message^.CPClient^.Release(); // temporary

     //-----
     | cmClientConnect :
       Known := Message^.CPConnection <> NIL;
       IF Known THEN // unknown/promiscuous client close
         logger()^.LogSP( dldTrace, logPrefix, L"Connect ", Message^.CPClient );
         IF Connections.Contains( Message^.CPConnection^.RemoteAddress ) THEN
            Log( dldDebug, TPConnection( Message^.CPConnection ), L". to known connection" );
         ELSE
            Log( dldError, TPConnection( Message^.CPConnection ), L". to unknown connection" );
         END;

         b := TRUE;
         Connection := TPConnection( Message^.CPConnection );
       ELSE
         logger()^.LogSP( dldDebug, logPrefix, L"Connect to all connections ", Message^.CPClient );

         Connections.Reset();
         b := Connections.MoveNext();
         Connection := Connections.CurrentData;
       END;
       WHILE b DO
         IF NOT Connection^.Connected THEN
           NResult := Connection^.ConnectAddress( Connection^.RemoteAddress, netsocket.FORSAFETY );
           IF NResult NOT IN Sync.arsStarts THEN
             Message^.CPClient^.OnConnect( Connection, TRUE, winsock.WSAECONNREFUSED );
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
       Known := Message^.CPConnection <> NIL;
       IF Known THEN // unknown/promiscuous client close
         logger()^.LogSP( dldTrace, logPrefix, L"Disconnect ", Message^.CPClient );
         IF Connections.Contains( Message^.CPConnection^.RemoteAddress ) THEN
            Log( dldDebug, TPConnection( Message^.CPConnection ), L". from known connection" );
         ELSE
            Log( dldError, TPConnection( Message^.CPConnection ), L". from unknown connection" );
         END;

         b := TRUE;
         Connection := TPConnection( Message^.CPConnection );
       ELSE
         logger()^.LogSP( dldDebug, logPrefix, L"Disconnect from all connections ", Message^.CPClient );

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
       Known := Message^.SPConnection <> NIL;
       IF Known THEN // unknown/promiscuous client close
         logger()^.LogSCP( dldDebug, logPrefix, L"Send bytes ", Message^.SLen, Message^.CPClient );
         IF Connections.Contains( Message^.CPConnection^.RemoteAddress ) THEN
            Log( dldDebug, TPConnection( Message^.CPConnection ), L". to known connection" );
            b := TRUE;
            Connection := TPConnection( Message^.SPConnection );
         ELSE
            Log( dldDebug, TPConnection( Message^.CPConnection ), L". to unknown connection" );
            // the only possibility is, that connection is server, closed now, and notified to client. So, simply ignore everything.
            b := FALSE;
         END;

       ELSE
         logger()^.LogSP( dldDebug, logPrefix, L"Send to all connections ", Message^.CPClient );

         Connections.Reset();
         b := Connections.MoveNext();
         Connection := Connections.CurrentData;
       END;

       WHILE b DO

         IF Connection^.Connected THEN
            CASE SELF.Connection OF
            | ctStream :
               MDatagram.Init( Message^.SData, Message^.SLen, FALSE );
               NResult := Connection^.IWrite^.Write( ADR( MDatagram ), netsocket.FORSAFETY, TRUE );
               ASSERT( NResult <> Sync.arTimeout );
               WHILE MDatagram.References > 1 DO // see note in IOO.CDataProxy
                  Sync.Sleep( 0 );
               END; // WHILE
            | ctDatagram :
               WDatagram.Init( Message^.SData, Message^.SLen, FALSE );
               NResult := Connection^.IWrite^.Write( ADR( WDatagram ), netsocket.FORSAFETY, TRUE );
               ASSERT( NResult <> Sync.arTimeout );
               WHILE WDatagram.References > 1 DO // see note in IOO.CDataProxy
                  Sync.Sleep( 0 );
               END; // WHILE
            | ctLine :
               Writer.Stream := Connection^.IWrite;
               Writer.WriteM( PWCHAR( Message^.SData ), Message^.SLen >> 1, TRUE );
            END;
         ELSE
            NResult := Sync.arCannotStart;
         END;

         IF Message^.SPClient <> NIL THEN
           IF NResult IN Sync.arsCompletions THEN
             Message^.SPClient^.OnSent( Connection, Message^.SPId, 0 );
           ELSE
             Message^.SPClient^.OnSent( Connection, Message^.SPId, winerror.ERROR_ACCESS_DENIED );
           END;
         END;
         IF Known THEN
           EXIT;
         ELSE
           b := Connections.MoveNext();
           Connection := Connections.CurrentData;
         END;
       END; // WHILE
       DISPOSE( Message^.SData );

     ELSE
       logger()^.LogSC( dldError, logPrefix, L"Unrecognized command ", CARDINAL( Message^.Command ));

     END; // CASE
  END DoMessage;

//--------------------------------------------------------------------------------
  
  LOCAL PROCEDURE OnListen( CONST ServerSocket : netsocket.TPSSocket );
  VAR
    Message : TMessage;
    Result : Sync.TAsyncResult;
  BEGIN
    // OnListen is in GUI thread, so posting there is not neccessary
    Message.Command := cmNetworkAccept;
    Message.NServerSocket := ServerSocket;
    Result := NQueue.EnqueueOA( Message, TRUE, netsocket.FORSAFETY );
    ASSERT( Result <> Sync.arTimeout );
  END OnListen;

//--------------------------------------------------------------------------------
  
  LOCAL PROCEDURE OnNetworkConnect( Error : CARDINAL; CONST Socket : netsocket.TPDSocket; Local : BOOLEAN );
  VAR
    Message : TMessage;
    Result : Sync.TAsyncResult;
  BEGIN
    Message.Command := cmNetworkConnect;
    Message.NCSocket := Socket;
    Message.NCError := Error;
    Message.NCLocal := Local;
    Result := NQueue.EnqueueOA( Message, TRUE, netsocket.FORSAFETY );
    ASSERT( Result <> Sync.arTimeout );
  END OnNetworkConnect;

//--------------------------------------------------------------------------------
  
  LOCAL PROCEDURE OnNetworkDisconnect( Error : CARDINAL; CONST Socket : netsocket.TPDSocket; Local : BOOLEAN );
  VAR
    Message : TMessage;
    Result : Sync.TAsyncResult;
  BEGIN
    Message.Command := cmNetworkDisconnect;
    Message.NCSocket := Socket;
    Message.NCError := Error;
    Message.NCLocal := Local;
    Result := NQueue.EnqueueOA( Message, TRUE, netsocket.FORSAFETY );
    ASSERT( Result <> Sync.arTimeout );
  END OnNetworkDisconnect;

//--------------------------------------------------------------------------------
  
  LOCAL PROCEDURE OnNetworkReceive( CONST Socket : netsocket.TPDSocket; Length : CARDINAL );
  VAR
    a : ADDRESS;
    Connection : TPConnection := TPConnection( Socket );
    IRead : IOO.TPBufferedReader;
    l : CARDINAL;
    Message : TMessage;
    Result : Sync.TAsyncResult;
  BEGIN
    IF Length = 0 THEN
      RETURN;
    END;

    IRead := Connection^.IRead;
    WHILE IRead^.Peek( OUT a, OUT l ) DO
      Message.Command := cmNetworkReceive;
      Message.NRSocket := Socket;
      Message.NRLen := l;
      ALLOCATE( Message.NRData, l );
      Storage.Move( a, Message.NRData, l );

      // queue request
      Result := NQueue.EnqueueOA( Message, FALSE, 0 ); // to not to block receiving thread to long
      IF Result = Sync.arCompleted THEN
         IRead^.ReadOut( l ); // read out and signal next reading
      
      ELSE// if data cannot be queued, leave loop, take receiver a chance and wait for next network message to run again (this could be a disadvantage)
         DISPOSE( Message.NRData );
         Log( dldTrace, Connection, "Receive.Queue Timeout" );
         
         // inform second queue, after its flush reading will continue
         Message.Command := cmNetworkReceiveContinue;
         Message.NRSocket := Socket;
         Result := CQueue.EnqueueOA( Message, TRUE, netsocket.FORSAFETY );
         IF Result <> Sync.arCompleted THEN
            Log( dldTrace, Connection, "Receive.Queue Timeout On SendQueue" );
         END;
         
         EXIT;
      END;

    END; // WHILE
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
  
  LOCAL PROCEDURE Join( PClient : TPClientInterface; RemoteAddress : inetaddr.INETADDR ); // asynchronous, results in Client.OnConnect
  VAR
    Message : TMessage;
    Result : Sync.TAsyncResult;
  BEGIN
    Message.Command := cmClientJoin;
    Message.JPClient := PClient;
    Message.JPClient^.AddRef(); // temporary
    Message.JRemoteAddress := RemoteAddress;
    Result := CQueue.EnqueueOA( Message, TRUE, netsocket.FORSAFETY );
    ASSERT( Result <> Sync.arTimeout );
    // make Join synchronous (to allow clients synchronously store their records)
    Result := CQueue.PushToConsumer( TRUE, netsocket.FORSAFETY );
    ASSERT( Result <> Sync.arTimeout );
  END Join;

//--------------------------------------------------------------------------------
  
  LOCAL PROCEDURE Leave( PClient : TPClientInterface; Connection : TConnectionHandle ); // asynchronous, results in Client.OnDisconnect and Done
  VAR
    Message : TMessage;
    Result : Sync.TAsyncResult;
  BEGIN
    Message.Command := cmClientLeave;
    Message.CPClient := PClient;
    Message.CPClient^.AddRef(); // temporary
    Message.CPConnection := Connection;
    Result := CQueue.EnqueueOA( Message, TRUE, netsocket.FORSAFETY );
    ASSERT( Result <> Sync.arTimeout );
    // make Leave synchronous (to allow clients synchronously remove their records)
    Result := CQueue.PushToConsumer( TRUE, netsocket.FORSAFETY );
    ASSERT( Result <> Sync.arTimeout );
  END Leave;

//--------------------------------------------------------------------------------
  
  LOCAL PROCEDURE Connect( PClient : TPClientInterface; Connection : TConnectionHandle ); // asynchronous, results in Client.OnConnect
  VAR
    Message : TMessage;
    Result : Sync.TAsyncResult;
  BEGIN
    Message.Command := cmClientConnect;
    Message.CPClient := PClient;
    Message.CPConnection := Connection;
    Result := CQueue.EnqueueOA( Message, TRUE, netsocket.FORSAFETY );
    ASSERT( Result <> Sync.arTimeout );
  END Connect;

//--------------------------------------------------------------------------------

  LOCAL PROCEDURE Disconnect( PClient : TPClientInterface; Connection : TConnectionHandle ); // asynchronous, results in Client.OnDisconnect
  VAR
    Message : TMessage;
    Result : Sync.TAsyncResult;
  BEGIN
    Message.Command := cmClientDisconnect;
    Message.CPClient := PClient;
    Message.CPConnection := Connection;
    Result := CQueue.EnqueueOA( Message, TRUE, netsocket.FORSAFETY );
    ASSERT( Result <> Sync.arTimeout );
  END Disconnect;

//--------------------------------------------------------------------------------

  LOCAL PROCEDURE Send( PClient : TPClientInterface; Connection : TConnectionHandle; ClientId : LONGWORD; PData : ADDRESS; DataLen : CARDINAL ); // asynchronous, results in Client.OnSend
  VAR
    Message : TMessage;
    Result : Sync.TAsyncResult;
  BEGIN
    Message.Command := cmClientSend;
    Message.SPClient := PClient;
    Message.SPConnection := Connection;
    Message.SPId := ClientId;
    Message.SLen := DataLen;
    ALLOCATE( Message.SData, DataLen );
    Storage.Move( PData, Message.SData, DataLen );
    Result := CQueue.EnqueueOA( Message, TRUE, netsocket.FORSAFETY );
    ASSERT( Result <> Sync.arTimeout );
  END Send;

//--------------------------------------------------------------------------------

   INITIALLY CDispatcher();
   VAR
      MSG : msghandler.Message;
   BEGIN
      CQueue.Init( 128, SIZE( TMessage ));
      CQueue.Consumer := ADR( SELF );
      CQueue.Produce := Sync.CreateSignal( TRUE, L"" );

      NQueue.Init( 256, SIZE( TMessage )); // NQueue for network receiving must be longer than CQueue used for send -- to not to block channel over TCP window if communicating inside one host
      NQueue.Consumer := ADR( SELF );
      NQueue.Produce := Sync.CreateSignal( TRUE, L"" );

      MSG.Message := msgqueue.MSG_PROCESS_QUEUE;
      CQueue.ConsumerMsg := ADR( MSG );
      
      MSG.Message := msgqueue.MSG_PROCESS_QUEUE + 1;
      NQueue.ConsumerMsg := ADR( MSG );

      NEW( TPListener( PListener )); TPListener( PListener )^.PDispatcher := ADR( SELF );
      NEW( TPNotifier( PNotifier )); TPNotifier( PNotifier )^.PDispatcher := ADR( SELF );
   END CDispatcher;

//--------------------------------------------------------------------------------

   FINALLY CDispatcher();
   BEGIN
      Dispose();
  
      Sync.DeleteSignal( REF CQueue.Produce );
      Sync.DeleteSignal( REF NQueue.Produce );
   END CDispatcher;

//--------------------------------------------------------------------------------

END CDispatcher;

//================================================================================

END netconndispatch.