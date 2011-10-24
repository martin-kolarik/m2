IMPLEMENTATION MODULE netconndispatch; // network connections dispatcher

IMPORT
   winsock;

FROM Debug IMPORT
   AssertionW;

FROM Storage IMPORT
  ALLOCATE, DEALLOCATE;
  
FROM log IMPORT
  logger, TLevel, ldError, ldTrace, ldDebug;

IMPORT
   array,
   collection,
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

CONST
   MQUEUE_MSG = msgqueue.MSG_PROCESS_QUEUE + 1;
   SQUEUE_MSG = msgqueue.MSG_PROCESS_QUEUE + 2;
   
//================================================================================

CLASS IMPLEMENTATION CClientInterface;
  
//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE GetRemoteAddress( Connection : TConnectionHandle ) : inetaddr.INETADDR;
   BEGIN
      RETURN PDispatcher^.GetRemoteAddress( Connection );
   END GetRemoteAddress;

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
      PDispatcher^.Send( ADR( SELF ), Connection, Id, String.Data, String.Length );
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
                  cmNetworkDisconnect :
                  NCSocket : netsocket.TPDSocket;
                  NCError : CARDINAL;
                  NCLocal : BOOLEAN;
                | cmNetworkReceive :
                  NRSocket : netsocket.TPDSocket;
                  NRData : ADDRESS;
                  NRLength : CARDINAL;

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
    Peer : TPConnection; // if connection is self to self in single process, Peer points to second endpoint
    PeerSignal : Sync.SIGNAL;
    DoStartReadingOnConnect : Sync.SIGNAL; // signalled if StartReading should be called
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

   FINALLY CConnection();

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
   PUBLIC VIRTUAL PROCEDURE OnFlowPossible( Direction : IOO.TDirection; Source : ADDRESS );
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
  VAR
    iterator : lists.CPtrListIterator;
  BEGIN
    iterator.Init( Clients, collection.dirForward );
    WHILE iterator.MoveNext() DO
      TPClientInterface( iterator.Value )^.OnConnect( ADR( SELF ), Local, Error );
    END; // WHILE
  END OnConnect;

//--------------------------------------------------------------------------------
  
  LOCAL PROCEDURE OnDisconnect( Local : BOOLEAN; Error : CARDINAL );
  VAR
    iterator : lists.CPtrListIterator;
  BEGIN
    iterator.Init( Clients, collection.dirForward );
    WHILE iterator.MoveNext() DO
      TPClientInterface( iterator.Value )^.OnDisconnect( ADR( SELF ), Local, Error );
    END; // WHILE
  END OnDisconnect;

//--------------------------------------------------------------------------------

  LOCAL PROCEDURE OnReceive( Data : ADDRESS; DataLen : CARDINAL );
  VAR
    iterator : lists.CPtrListIterator;
  BEGIN
    iterator.Init( Clients, collection.dirForward );
    WHILE iterator.MoveNext() DO
      TPClientInterface( iterator.Value )^.OnReceive( ADR( SELF ), Data, DataLen );
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

   FINALLY CConnection();
   VAR
      iterator : lists.CPtrListIterator;
   BEGIN
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
      iterator.Init( Clients, collection.dirForward );
      WHILE iterator.MoveNext() DO
         TPClientInterface( iterator.Value )^.Release();
      END; // WHILE
      Clients.Dispose();
   END CConnection;

//--------------------------------------------------------------------------------

BEGIN
   Peer := NIL;
   DoStartReadingOnConnect.Signal();;
   NStream.FromSocket( ADR( SELF ), TRUE, IOO.accReadWrite );
   Stream.Stream := ADR( NStream );
   PDatagrammer := NIL;
   PDatagrammerNotifier := NIL;
   PReader := NIL;
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
  
   PUBLIC VIRTUAL PROCEDURE OnFlowPossible( Direction : IOO.TDirection; Source : ADDRESS );
   BEGIN
      IF Direction = IOO.dirRead THEN
         PDispatcher^.OnNetworkReceivePossible( netsocket.TPDSocket( Source ));
      END;
   END OnFlowPossible;

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
  
PROCEDURE Log( Severity : TLevel; Connection : TPConnection; Text : ARRAY OF WCHAR );
VAR
   address : ARRAY [0..63] OF WCHAR;
BEGIN
   logger()^.LogS( Severity, 0, logPrefix, Text );

   Connection^.RemoteAddress.ToOA( TRUE, OUT address );
   logger()^.LogSS( Severity, 0, logPrefix, "  address ", address );
END Log;
  
//--------------------------------------------------------------------------------
  
CLASS IMPLEMENTATION CDispatcher;

//--------------------------------------------------------------------------------

  PUBLIC PROPERTY Listener GET : netsrv.TPListener;
  BEGIN
    RETURN PListener;
  END Listener;

//--------------------------------------------------------------------------------

  PUBLIC VIRTUAL PROCEDURE Dispose();
   VAR
      iterator : inetaddr.CINETADDRPtrMapIterator;
  BEGIN
    IF NOT Connections.Empty THEN
      iterator.Init( Connections, collection.dirForward );
      WHILE iterator.MoveNext() DO WITH TPConnection( iterator.Value )^ DO
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
    SUPER.Dispose();
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
      | MQUEUE_MSG :
         WHILE MQueue.DequeueOA( OUT Message, FALSE, 0 ) = Sync.arCompleted DO
            DoMessage( ADR( Message ));
         END; // WHILE

         // restart receiving for defered clients
         RestartDefered();

      //-----
      | SQUEUE_MSG :
         WHILE SQueue.DequeueOA( OUT Message, FALSE, 0 ) = Sync.arCompleted DO
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
    iterator : inetaddr.CINETADDRPtrMapIterator;
    Peer : TPConnection;
    ptr : PTR;
    WDatagram : IOO.CDatagramProxy;
    Writer : TextWriter.CTextWriter;
  BEGIN
     CASE Message^.Command OF
     //-----
     | cmNetworkAccept :
       NEW( Connection ); Connection^.Init( ADR( SELF ), PNotifier );
       IF Connection^.Accept( Message^.NServerSocket, OUT Error ) = Sync.arCompleted THEN
         Log( ldTrace, Connection, "Accept.Net" );

         IF Connections.Get( Connection^.RemoteAddress, OUT CurrentConnection, OUT ptr ) THEN
           Log( ldError, Connection, "Accept connection already exists" );

           // this should not occur -- two same connections are impossible, but it can be state after undetected failure
           Connection^.Notifier := NIL; // not to notify about disconnect, it will continue using CurrentConnection
           CurrentConnection^.AcceptFrom( REF Connection, OUT Error );
           Connection^.Release();
           Connection := CurrentConnection;
         ELSE
           Connections.Add( Connection^.RemoteAddress, Connection, 0 );
         END;
         
         IF Connections.Get( Connection^.LocalAddress, OUT Peer, OUT ptr ) THEN // connection is self to self in single process
            Log( ldTrace, Peer, "Accept.Net.InProcessPeer" );

            Connection^.Peer := Peer;
            Connection^.PeerSignal.Init( Sync.stEventAutoreset, L"", TRUE );
            Peer^.Peer := Connection;
            Peer^.PeerSignal.Init( Sync.stEventAutoreset, L"", TRUE );
         END;
         
       ELSE
         Log( ldTrace, Connection, "Accept.Net unsuccessfull" );

         Connection^.Notifier := NIL; // not to notify about disconnect, the connection is not known and still will not be known
         Connection^.Disconnect( FALSE );
         Connection^.Release();
       END;

     //-----
     | cmNetworkConnect :
       Connection := TPConnection( Message^.NCSocket );
       IF Connections.Contains( Connection^.RemoteAddress ) THEN
         Log( ldTrace, Connection, L"Connect.Net" );
       ELSE
         Log( ldError, Connection, L"Connect on unknown connection" );
       END;

       Connection^.OnConnect( Message^.NCLocal, Message^.NCError );
       OnConnect( Connection, Message^.NCLocal, Message^.NCError );

     //-----
     | cmNetworkDisconnect :
       Connection := TPConnection( Message^.NCSocket );

       IF Connections.Contains( Connection^.RemoteAddress ) THEN
         Log( ldTrace, Connection, L"Disconnect.Net" );
         
         Connection^.OnDisconnect( Message^.NCLocal, Message^.NCError ); // dispatch event to the clients
         OnDisconnect( Connection, Message^.NCLocal, Message^.NCError );
         IF Connection^.Empty THEN
           Connections.Remove( Connection^.RemoteAddress );

           Connection^.Notifier := NIL; // now I do not want next notifications
           Connection^.Disconnect( FALSE );
           Connection^.Release();
         ELSE
           Connection^.Disconnect( TRUE ); // flushing of buffers, redundant underlying stream close
         END;

       ELSE
         Log( ldDebug, Connection, L"Disconnect on unknown connection" );
       END;

     //-----
     | cmNetworkReceive :
       Connection := TPConnection( Message^.NRSocket );

       logger()^.LogSC( ldDebug, 0, logPrefix, L"Receive bytes ", Message^.NRLength );
       Log( ldDebug, Connection, L"  from known connection " );

       ASSERTLOG( Connections.Contains( Connection^.RemoteAddress )); // there only an error could cause that connection is not known

       OnReceive( Connection, Message^.NRData, Message^.NRLength );
       Connection^.OnReceive( Message^.NRData, Message^.NRLength );

       DISPOSE( Message^.NRData ); // cleanup

     //-----
     | cmClientJoin :
       logger()^.LogSP( ldTrace, 0, logPrefix, L"Join ", Message^.CPClient );

       IF Connections.Get( Message^.JRemoteAddress, OUT Connection, OUT ptr ) THEN
         Log( ldDebug, Connection, L"  to existing connection" );

       ELSE
         NEW( Connection ); Connection^.Init( ADR( SELF ), PNotifier );
         Connection^.RemoteAddress := Message^.JRemoteAddress;
         Connections.Add( Message^.JRemoteAddress, Connection, 0 );

         Log( ldDebug, Connection, L"  to new connection" );
       END;
       IF Connection^.AddClient( Message^.JPClient ) THEN // OnJoin/OnConnected called inside
         OnClientJoin( Connection, Message^.JPClient );
       END;
       Message^.JPClient^.Release(); // temporary

     //-----
     | cmClientLeave :
       Known := Message^.CPConnection <> NIL;
       IF Known THEN // unknown/promiscuous client close
         logger()^.LogSP( ldTrace, 0, logPrefix, L"Leave from single connection ", Message^.CPClient );
         IF Connections.Contains( Message^.CPConnection^.RemoteAddress ) THEN
            Log( ldDebug, TPConnection( Message^.CPConnection ), L"  from known connection" );
         ELSE
            Log( ldError, TPConnection( Message^.CPConnection ), L"  from unknown connection" );
         END;

         b := TRUE;
         Connection := TPConnection( Message^.CPConnection );
       ELSE
         logger()^.LogSP( ldDebug, 0, logPrefix, L"Leave from all connections ", Message^.CPClient );

         iterator.Init( Connections, collection.dirForward );
         b := iterator.MoveNext();
         Connection := iterator.Value;
       END;
       WHILE b DO
         IF Connection^.RemoveClient( Message^.CPClient ) THEN // OnDisconnect/OnLeave called inside
           OnClientLeave( Connection, Message^.CPClient );
         ELSE
           ASSERTLOG( NOT Known );
         END;
         IF Connection^.Empty THEN
           IF Connection^.Connected THEN
             OnDisconnect( Connection, TRUE, 0 ); // network disconnect will not be accepted as Connection is removed now
           END;
           Connections.Remove( Connection^.RemoteAddress );

           Connection^.Notifier := NIL; // we do not want next notifications
           Connection^.Disconnect( FALSE );
           Connection^.Release();

           b := FALSE; // Connection was deleted
         END;
         IF Known THEN
           EXIT;
         ELSIF NOT b THEN // Connection was deleted
            iterator.Init( Connections, collection.dirForward );
         END;
         b := iterator.MoveNext();
         Connection := iterator.Value;
       END; // WHILE
       Message^.CPClient^.Release(); // temporary

     //-----
     | cmClientConnect :
       Known := Message^.CPConnection <> NIL;
       IF Known THEN // unknown/promiscuous client close
         logger()^.LogSP( ldTrace, 0, logPrefix, L"Connect ", Message^.CPClient );
         IF Connections.Contains( Message^.CPConnection^.RemoteAddress ) THEN
            Log( ldDebug, TPConnection( Message^.CPConnection ), L"  to known connection" );
         ELSE
            Log( ldError, TPConnection( Message^.CPConnection ), L"  to unknown connection" );
         END;

         b := TRUE;
         Connection := TPConnection( Message^.CPConnection );
       ELSE
         logger()^.LogSP( ldDebug, 0, logPrefix, L"Connect to all connections ", Message^.CPClient );

         iterator.Init( Connections, collection.dirForward );
         b := iterator.MoveNext();
         Connection := iterator.Value;
       END;
       WHILE b DO
         IF NOT Connection^.Connected THEN
           Connection^.DoStartReadingOnConnect.Signal();
           NResult := Connection^.ConnectAddress( Connection^.RemoteAddress, netsocket.FORSAFETY );
           IF NResult NOT IN Sync.arsStarts THEN
             Message^.CPClient^.OnConnect( Connection, TRUE, winsock.WSAECONNREFUSED );
           END;
         END;
         IF Known THEN
           EXIT;
         ELSE
           b := iterator.MoveNext();
           Connection := iterator.Value;
         END;
       END; // WHILE

     //-----
     | cmClientDisconnect :
       Known := Message^.CPConnection <> NIL;
       IF Known THEN // unknown/promiscuous client close
         logger()^.LogSP( ldTrace, 0, logPrefix, L"Disconnect ", Message^.CPClient );
         IF Connections.Contains( Message^.CPConnection^.RemoteAddress ) THEN
            Log( ldDebug, TPConnection( Message^.CPConnection ), L"  from known connection" );
         ELSE
            Log( ldError, TPConnection( Message^.CPConnection ), L"  from unknown connection" );
         END;

         b := TRUE;
         Connection := TPConnection( Message^.CPConnection );
       ELSE
         logger()^.LogSP( ldDebug, 0, logPrefix, L"Disconnect from all connections ", Message^.CPClient );

         iterator.Init( Connections, collection.dirForward );
         b := iterator.MoveNext();
         Connection := iterator.Value;
       END;
       WHILE b DO
         Connection^.Disconnect( TRUE );
         IF Known THEN
           EXIT;
         ELSE
           b := iterator.MoveNext();
           Connection := iterator.Value;
         END;
       END; // WHILE

     //-----
     | cmClientSend :
       Known := Message^.SPConnection <> NIL;
       IF Known THEN // unknown/promiscuous client close
         logger()^.LogSCP( ldDebug, 0, logPrefix, L"Send bytes ", Message^.SLen, Message^.CPClient );
         IF Connections.Contains( Message^.SPConnection^.RemoteAddress ) THEN
            Log( ldDebug, TPConnection( Message^.SPConnection ), L"  to known connection" );
            b := TRUE;
            Connection := TPConnection( Message^.SPConnection );
         ELSE
            Log( ldDebug, TPConnection( Message^.SPConnection ), L"  to unknown (disconnected) connection" );
            // the only possibility is, that connection is server, closed now, and notified to client. So, simply ignore everything.
            b := FALSE;
         END;

       ELSE // not known
         logger()^.LogSP( ldDebug, 0, logPrefix, L"Send to all connections ", Message^.CPClient );

         iterator.Init( Connections, collection.dirForward );
         b := iterator.MoveNext();
         Connection := iterator.Value;
       END;

       WHILE b DO

         IF Connection^.Connected THEN
            CASE SELF.Connection OF
            | ctStream :
               MDatagram.Init( Message^.SData, Message^.SLen, FALSE );
               NResult := Connection^.IWrite^.Write( ADR( MDatagram ), netsocket.FORSAFETY, TRUE );
               ASSERTLOG( NResult <> Sync.arTimeout );
               WHILE MDatagram.References > 1 DO // see note in IOO.CDataProxy
                  Sync.Sleep( 0 );
               END; // WHILE
            | ctDatagram :
               WDatagram.Init( Message^.SData, Message^.SLen, FALSE );
               NResult := Connection^.IWrite^.Write( ADR( WDatagram ), netsocket.FORSAFETY, TRUE );
               ASSERTLOG( NResult <> Sync.arTimeout );
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
           b := iterator.MoveNext();
           Connection := iterator.Value;
         END;

       END; // WHILE
       DISPOSE( Message^.SData );

       IF Known AND ( Message^.SPClient = NIL ) THEN // Data sent by promiscuous handler, call Release to balance AddRef from client Send. Connection can be freed.
          Message^.SPConnection^.Release();
       END;

     ELSE
       logger()^.LogSC( ldError, 0, logPrefix, L"Unrecognized command ", CARDINAL( Message^.Command ));

     END; // CASE
  END DoMessage;

//--------------------------------------------------------------------------------
   
   PRIVATE PROCEDURE RestartDefered();
   VAR
      Connection : TPConnection;
      count : CARDINAL;
      i : CARDINAL;
   BEGIN
      DeferLock.Lock();
      count := Defered.Count;
      IF count > 0 THEN
         FOR i := 0 TO count-1 DO
            Connection := Defered[i];

            // here, connections could be already removed
            IF Connections.Contains( Connection^.RemoteAddress ) THEN
               Log( ldTrace, Connection, L"Receive continue" );
               Connection^.StartReading();
            ELSE
               Log( ldTrace, Connection, L"Receive should continue, but it cannot, as it is already disconnected" );
            END;

            Connection^.Release(); // clean up, AddRef is done before queueing
         END; // FOR
         Defered.Clear();
      END;
      DeferLock.Unlock();
   END RestartDefered;
  
//--------------------------------------------------------------------------------
  
  LOCAL PROCEDURE OnListen( CONST ServerSocket : netsocket.TPSSocket );
  VAR
    Message : TMessage;
    Result : Sync.TAsyncResult;
  BEGIN
    Message.Command := cmNetworkAccept;
    Message.NServerSocket := ServerSocket;
    Result := MQueue.EnqueueOA( Message, TRUE, netsocket.FORSAFETY );
    ASSERTLOG( Result <> Sync.arTimeout );
    ASSERTLOG( MQueue.Count < 10000 );
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
    Result := MQueue.EnqueueOA( Message, TRUE, netsocket.FORSAFETY );
    ASSERTLOG( Result <> Sync.arTimeout );
    ASSERTLOG( MQueue.Count < 10000 );
  END OnNetworkConnect;

//--------------------------------------------------------------------------------
  
  LOCAL PROCEDURE OnNetworkDisconnect( Error : CARDINAL; CONST Socket : netsocket.TPDSocket; Local : BOOLEAN );
  VAR
    Connection : TPConnection := TPConnection( Socket );
    Message : TMessage;
    Peer : TPConnection;
    Result : Sync.TAsyncResult;
  BEGIN
    IF Connection^.Peer <> NIL THEN // connection is self to self in single process, signal to unlock client
       Peer := Connection^.Peer;
       Connection^.Peer := NIL; // deny next waiting
       Connection^.PeerSignal.Signal();
       Peer^.Peer := NIL; // deny next waiting
       Peer^.PeerSignal.Signal();
    END;

    Message.Command := cmNetworkDisconnect;
    Message.NCSocket := Socket;
    Message.NCError := Error;
    Message.NCLocal := Local;
    Result := MQueue.EnqueueOA( Message, TRUE, netsocket.FORSAFETY );
    ASSERTLOG( Result <> Sync.arTimeout );
    ASSERTLOG( MQueue.Count < 10000 );
  END OnNetworkDisconnect;

//--------------------------------------------------------------------------------
  
   LOCAL PROCEDURE OnNetworkReceivePossible( CONST Socket : netsocket.TPDSocket );
   VAR
      Connection : TPConnection := TPConnection( Socket );
   BEGIN
      IF Connection^.DoStartReadingOnConnect.State AND Connection^.Connected THEN
         Connection^.DoStartReadingOnConnect.Reset();
         Connection^.StartReading();
      END;
   END OnNetworkReceivePossible;

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
         Message.NRLength := l;
         ALLOCATE( OUT Message.NRData, l );
         Storage.Move( a, Message.NRData, l );

         // queue request
         Result := MQueue.EnqueueOA( Message, FALSE, 0 ); // to not to block receiving thread to long
         ASSERTLOG( MQueue.Count < 10000 );

         IF Result = Sync.arCompleted THEN
            IRead^.ReadOut( l ); // read out and signal next reading

            IF Connection^.Peer <> NIL THEN // connection is self to self in single process, signal that peer can continue with send
               Connection^.Peer^.PeerSignal.Signal();
            END;
         
         ELSE // if data cannot be queued, leave loop, and store connection in Defered, which will be restarted after Queue flush
            DISPOSE( Message.NRData );
            Log( ldTrace, Connection, "Receive.Queue Timeout" );
       
            DeferLock.Lock();
            IF NOT Defered.Contains( Connection ) THEN
               Connection^.AddRef(); // force leaving over disconnect done before StartReceive
               Defered.Add( Connection );
            END;
            DeferLock.Unlock();

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
  
   LOCAL PROCEDURE GetRemoteAddress( Connection : TConnectionHandle ) : inetaddr.INETADDR;
   VAR
      ia : inetaddr.INETADDR;
   BEGIN
      IF Connection = NIL THEN
         RETURN ia;
      ELSIF Connection^.Connected THEN
         RETURN Connection^.RemoteAddress;
      ELSE
         RETURN ia;
      END;
   END GetRemoteAddress;

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
    Result := MQueue.EnqueueOA( Message, TRUE, netsocket.FORSAFETY );
    ASSERTLOG( Result <> Sync.arTimeout );
    ASSERTLOG( MQueue.Count < 10000 );
    // make Join synchronous (to allow clients synchronously store their records)
    Result := MQueue.PushToConsumer( TRUE, netsocket.FORSAFETY );
    ASSERTLOG( Result <> Sync.arTimeout );
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
    Result := MQueue.EnqueueOA( Message, TRUE, netsocket.FORSAFETY );
    ASSERTLOG( Result <> Sync.arTimeout );
    ASSERTLOG( MQueue.Count < 10000 );
    // make Leave synchronous (to allow clients synchronously remove their records)
    Result := MQueue.PushToConsumer( TRUE, netsocket.FORSAFETY );
    ASSERTLOG( Result <> Sync.arTimeout );
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
    Result := MQueue.EnqueueOA( Message, TRUE, netsocket.FORSAFETY );
    ASSERTLOG( Result <> Sync.arTimeout );
    ASSERTLOG( MQueue.Count < 10000 );
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
    Result := MQueue.EnqueueOA( Message, TRUE, netsocket.FORSAFETY );
    ASSERTLOG( Result <> Sync.arTimeout );
    ASSERTLOG( MQueue.Count < 10000 );
  END Disconnect;

//--------------------------------------------------------------------------------

   LOCAL PROCEDURE Send( PClient : TPClientInterface; Connection : TConnectionHandle; ClientId : LONGWORD; PData : ADDRESS; DataLen : CARDINAL ); // asynchronous, results in Client.OnSend
   VAR
      Message : TMessage;
      Result : Sync.TAsyncResult;
   BEGIN
      // handle special cases
      IF Connection <> NIL THEN
         IF TPConnection( Connection )^.Peer <> NIL THEN // connection is self to self in single process, wait until data flows through socket to other side
            Result := TPConnection( Connection )^.PeerSignal.Wait( netsocket.FORSAFETY );
            ASSERTLOG( Result <> Sync.arTimeout );
         END;

         IF PClient = NIL THEN // Promiscuous handler, client is not joined, this procedure should be called from self thread context.
                               // This means that Connection can be silently disconnected and send could use deallocated object. Avoid
                               // this by AddRef().
           Connection^.AddRef();
         END;                            
      END;
      
      Message.Command := cmClientSend;
      Message.SPClient := PClient;
      Message.SPConnection := Connection;
      Message.SPId := ClientId;
      Message.SLen := DataLen;
      ALLOCATE( OUT Message.SData, DataLen );
      Storage.Move( PData, Message.SData, DataLen );

      Result := SQueue.EnqueueOA( Message, TRUE, netsocket.FORSAFETY );
      ASSERTLOG( Result <> Sync.arTimeout );
      ASSERTLOG( SQueue.Count < 1000000 );
   END Send;

//--------------------------------------------------------------------------------

   INITIALLY CDispatcher();
   VAR
      Msg : msghandler.Message;
   BEGIN
      Defered.Strategy := array.astrgListInArray;

      Msg.Message := MQUEUE_MSG;
      // MQueue.Init( 256, SIZE( TMessage ));
      MQueue.Init( SIZE( TMessage )); // for BufferQueue there is no queue size
      MQueue.Consumer := ADR( SELF );
      MQueue.ConsumerMsg := ADR( Msg );

      Msg.Message := SQUEUE_MSG;
      // SQueue.Init( 256, SIZE( TMessage ));
      SQueue.Init( SIZE( TMessage )); // for BufferQueue there is no queue size
      SQueue.Consumer := ADR( SELF );
      SQueue.ConsumerMsg := ADR( Msg );

      NEW( TPListener( PListener )); TPListener( PListener )^.PDispatcher := ADR( SELF );
      NEW( TPNotifier( PNotifier )); TPNotifier( PNotifier )^.PDispatcher := ADR( SELF );
   END CDispatcher;

//--------------------------------------------------------------------------------

   FINALLY CDispatcher();
   BEGIN
      Dispose();
   END CDispatcher;

//--------------------------------------------------------------------------------

END CDispatcher;

//================================================================================

END netconndispatch.
