IMPLEMENTATION MODULE netsrv;

//================================================================================

FROM Storage IMPORT
  ALLOCATE, DEALLOCATE;

IMPORT
  lists,
  msghandler,
  msgqueue,
  netpool,
  Storage,
  Sync,
  threadpool;

//================================================================================

TYPE
  TPIPServer = POINTER TO CIPServer;

TYPE
  TCommand = (
    cmRegister,
    cmForgetPort,
    cmForgetSocket,
    cmAccept,
    cmDataArrived
  );

  TMessage  = RECORD
                CASE Command : TCommand OF
                | cmRegister, cmForgetSocket :
                  Socket    : netsocket.TPSSocket;
                  Creator   : TPListener;
                  CloseTime : CARDINAL;
                | cmForgetPort :
                  Port      : CARDINAL;
                  Type      : netsocket.TSocketType;
                | cmAccept  :
                  __        : netsocket.TPSSocket;
                  Result    : CARDINAL;
                END; // CASE  
              END;
  TPMessage = POINTER TO TMessage;

//================================================================================

CLASS IMPLEMENTATION AListener;

  LOCAL VIRTUAL PROCEDURE OnListen( CONST ServerSocket : netsocket.TPSSocket );
  BEGIN
  END OnListen;

  LOCAL VIRTUAL PROCEDURE OnDatagramReceived( CONST ServerSocket : netsocket.TPSSocket );
  BEGIN
  END OnDatagramReceived;

  LOCAL VIRTUAL PROCEDURE OnListenSocketClosed( CONST ServerSocket : netsocket.TPSSocket );
  BEGIN
  END OnListenSocketClosed;

END AListener;

//================================================================================

CLASS CSocketNotifier( netsocket.ASocketNotifier );
  Server : TPIPServer;
  LOCAL VIRTUAL PROCEDURE OnListen( Result : CARDINAL; CONST Socket : netsocket.TPSSocket );
  LOCAL VIRTUAL PROCEDURE OnDataArrived( Result : CARDINAL; CONST Socket : netsocket.TPSSocket );
END CSocketNotifier;

//--------------------------------------------------------------------------------

CLASS CIPServer( msghandler.MessageHandler );
  _FDHandle : Sync.WAITABLE;
  _FDMessager : msghandler.TPMessageHandler;
  _FDMessage : msghandler.Message;
  _Delegate : threadpool.CMessageHandlerDelegate;

  CBMode : TCallbackMode := cbmDefault;
  MQueue : msgqueue.CMessageQueue;
  SocketNotifier : CSocketNotifier;
  Sockets : lists.CPtrList;

  PUBLIC PROCEDURE Dispose();

  INTERNAL VIRTUAL PROCEDURE OnMessage( CONST MSG : msghandler.IMessage; OUT Result : CARDINAL ) : BOOLEAN;
  INTERNAL VIRTUAL PROCEDURE OnTimer( Timer : PTR );

  LOCAL PROCEDURE SetCallbackMode( Mode : TCallbackMode );
  LOCAL PROCEDURE StartListen( Type : netsocket.TSocketType; Port : CARDINAL; PMulticastGroup : winsock.PIN_ADDR; PStreamCreator : TPListener; AutomaticCloseTimeMS : CARDINAL; PCreatedSocket : POINTER TO netsocket.TPSSocket ) : CARDINAL;
  LOCAL PROCEDURE StopListenPort( Port : CARDINAL; Type : netsocket.TSocketType );
  LOCAL PROCEDURE StopListenSocket( Socket : netsocket.TPSSocket );

  PRIVATE PROCEDURE CloseSocket( Socket : netsocket.TPSSocket; Creator : TPListener; Deregister : BOOLEAN );
  PRIVATE PROCEDURE SearchSocket( Port : CARDINAL; Type : netsocket.TSocketType; OUT Socket : netsocket.TPSSocket; OUT Creator : TPListener ) : BOOLEAN;
END CIPServer;

//================================================================================

CLASS IMPLEMENTATION CSocketNotifier;

  LOCAL VIRTUAL PROCEDURE OnListen( Result : CARDINAL; CONST Socket : netsocket.TPSSocket );
  VAR
    Message : TMessage;
  BEGIN
    IF Result = 0 THEN
      Message.Command := cmAccept;
      Message.Socket := Socket;
      Message.Result := Result;
      Server^.MQueue.QueueOA( Message );
    END;
  END OnListen;

  LOCAL VIRTUAL PROCEDURE OnDataArrived( Result : CARDINAL; CONST Socket : netsocket.TPSSocket );
  VAR
    Message : TMessage;
  BEGIN
    IF Result = 0 THEN
      Message.Command := cmDataArrived;
      Message.Socket := Socket;
      Message.Result := Result;
      Server^.MQueue.QueueOA( Message );
    END;
  END OnDataArrived;

BEGIN
  Server := NIL;
END CSocketNotifier;

//================================================================================

CLASS IMPLEMENTATION CIPServer;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE Dispose();
  VAR
    Socket : netsocket.TPSSocket;
  BEGIN
    IF NOT Sockets.Empty THEN
      Sockets.Reset();
      WHILE Sockets.MoveNext() DO
        Socket := netsocket.TPSSocket( Sockets.Current );
        CloseSocket( Socket, Sockets.CurrentData, FALSE );
      END; // WHILE
      Sockets.Dispose();
    END;
    IF _FDHandle <> NIL THEN
      netpool.Pool()^.Abort( REF _FDHandle );
    END;
  END Dispose;

//--------------------------------------------------------------------------------

  INTERNAL VIRTUAL PROCEDURE OnMessage( CONST MSG : msghandler.IMessage; OUT Result : CARDINAL ) : BOOLEAN;
  VAR
    Creator : TPListener;
    Message : TMessage;
    Socket : netsocket.TPSSocket;
  BEGIN
    Result := 0;
    IF SUPER.OnMessage( MSG, OUT Result ) THEN
      RETURN TRUE;
    ELSIF (( _FDHandle = NIL ) OR ( _FDMessage.Message <> MSG.Message )) AND ( MSG.Message <> msgqueue.WM_MQ_PROCESS ) THEN
      RETURN TRUE;
    END;

    WHILE MQueue.DequeueOA( OUT Message ) DO
      CASE Message.Command OF
      //-----
      | cmRegister :
        Sockets.Add( Message.Socket, Message.Creator );
        IF ( Message.CloseTime <> 0 ) AND ( Message.CloseTime <> Sync.INFINITE_TIME ) THEN
          StartTimer( Message.Socket, Message.CloseTime, FALSE );
        END; // IF
      //-----
      | cmForgetPort :
        IF SearchSocket( Message.Port, Message.Type, OUT Socket, OUT Creator ) THEN
          CloseSocket( Socket, Creator, TRUE );
        END;
      //-----
      | cmForgetSocket :
        IF Sockets.Get( Message.Socket, OUT Creator ) THEN
          CloseSocket( Message.Socket, Creator, TRUE );
        END;
      //-----
      | cmAccept :
        IF Message.Result <> 0 THEN
          // skip
        ELSIF Sockets.Get( Message.Socket, OUT Creator ) THEN
          Creator^.OnListen( Message.Socket );
        ELSE
          Message.Socket^.Flush();
        END;
      //-----
      | cmDataArrived :
        IF Message.Result <> 0 THEN
          // skip
        ELSIF Sockets.Get( Message.Socket, OUT Creator ) THEN
          Creator^.OnDatagramReceived( Message.Socket );
        ELSE
          Message.Socket^.Flush();
        END;
      END; // CASE
    END; // WHILE
    
    RETURN TRUE;  
  END OnMessage;

//--------------------------------------------------------------------------------

  INTERNAL VIRTUAL PROCEDURE OnTimer( Timer : PTR );
  VAR
    Socket : netsocket.TPSSocket := netsocket.TPSSocket( Timer );
    Creator : TPListener;
  BEGIN
    IF NOT Sockets.Get( Socket, OUT Creator ) THEN
      RETURN;
    END;
    CloseSocket( Socket, Creator, TRUE );
  END OnTimer;

//--------------------------------------------------------------------------------

  LOCAL PROCEDURE SetCallbackMode( Mode : TCallbackMode );
  BEGIN
    IF CBMode = Mode THEN
      RETURN;
    END;
    CBMode := Mode;
    IF CBMode = cbmPooled THEN
      IF _FDHandle = NIL THEN
        netpool.Pool()^.WaitMessage( ADR( _Delegate ), 0, Sync.INFINITE_TIME, FALSE, OUT _FDMessager, OUT _FDMessage, OUT _FDHandle );
      END;
      MQueue.Consumer := _FDMessager;
      MQueue.ConsumerMsg := ADR( _FDMessage );
    ELSE
      MQueue.Consumer := ADR( SELF );
      MQueue.ConsumerMsg := NIL;
    END;
  END SetCallbackMode;

//--------------------------------------------------------------------------------

   LOCAL PROCEDURE StartListen( Type : netsocket.TSocketType; Port : CARDINAL; PMulticastGroup : winsock.PIN_ADDR; PStreamCreator : TPListener; AutomaticCloseTimeMS : CARDINAL; PCreatedSocket : POINTER TO netsocket.TPSSocket ) : CARDINAL;
   VAR
      Error : CARDINAL;
      Message : TMessage;
      Result : Sync.TAsyncResult;
      Socket : netsocket.TPSSocket;
   BEGIN
      IF PStreamCreator = NIL THEN
         RETURN -1;
      ELSE
         PStreamCreator^.AddRef();
      END;
      IF HWND = NIL THEN
         Init();
      END;

      NEW( Socket );
      Socket^.Type := Type;
      Socket^.LocalPort := Port;
      IF PMulticastGroup <> NIL THEN
         Socket^.MulticastGroup := PMulticastGroup^;
      END;
      Result := Socket^.Open( OUT Error );
      IF Result NOT IN Sync.arsStarts THEN
         Socket^.Release();
         RETURN Error;
      END;
      IF PCreatedSocket <> NIL THEN
         PCreatedSocket^ := Socket;
      END;

      Message.Command := cmRegister;
      Message.Creator := PStreamCreator;
      Message.Socket := Socket;
      Message.CloseTime := AutomaticCloseTimeMS;
      MQueue.QueueOA( Message );
    
      // listen must be started synchronously, to assure that send/receivings done immediatelly after StartListen will be catched
      Socket^.Notifier := ADR( SocketNotifier );
      Result := Socket^.Listen( OUT Error );
      IF Result IN Sync.arsStarts THEN
         RETURN 0;
      ELSE
         StopListenSocket( Socket );
         RETURN Error;
      END;
   END StartListen;

//--------------------------------------------------------------------------------

  LOCAL PROCEDURE StopListenPort( Port : CARDINAL; Type : netsocket.TSocketType );
  VAR
    Message : TMessage;
  BEGIN
    IF HWND = NIL THEN
      Init();
    END;
    Message.Command := cmForgetPort;
    Message.Port := Port;
    Message.Type := Type;
    MQueue.QueueOA( Message );
  END StopListenPort;
  
//--------------------------------------------------------------------------------

  LOCAL PROCEDURE StopListenSocket( Socket : netsocket.TPSSocket );
  VAR
    Message : TMessage;
  BEGIN
    IF HWND = NIL THEN
      Init();
    END;
    Message.Command := cmForgetSocket;
    Message.Socket := Socket;
    MQueue.QueueOA( Message );
  END StopListenSocket;

//--------------------------------------------------------------------------------

  PRIVATE PROCEDURE CloseSocket( Socket : netsocket.TPSSocket; Creator : TPListener; Deregister : BOOLEAN );
  BEGIN
    IF Creator <> NIL THEN
      Creator^.OnListenSocketClosed( Socket );
      Creator^.Release();
    END;
    IF Deregister THEN
      Sockets.Remove( Socket );
      StopTimer( Socket );
    END;
    Socket^.Close( FALSE );
    Socket^.Release();
  END CloseSocket;

//--------------------------------------------------------------------------------

  PRIVATE PROCEDURE SearchSocket( Port : CARDINAL; Type : netsocket.TSocketType; OUT Socket : netsocket.TPSSocket; OUT Creator : TPListener ) : BOOLEAN;
  VAR
    LSocket : netsocket.TPSSocket;
  BEGIN
    Sockets.Reset();
    WHILE Sockets.MoveNext() DO
      LSocket := Sockets.Current;
      IF ( LSocket^.LocalPort = Port ) AND ( LSocket^.Type = Type ) THEN
        Socket := LSocket;
        Creator := Sockets.CurrentData;
        RETURN TRUE;
      END;
    END; // WHILE
    RETURN FALSE;
  END SearchSocket;

//--------------------------------------------------------------------------------

BEGIN
  _FDHandle := NIL;
  _FDMessager := NIL;
  _Delegate.Handler := ADR( SELF );
  MQueue.Init( 32, SIZE( TMessage ));
  MQueue.Consumer := ADR( SELF );
  SocketNotifier.Server := ADR( SELF );
FINALLY
  Dispose();
END CIPServer;

//================================================================================

VAR
  IPServer : CIPServer;

PROCEDURE SetCallbackMode(
            Mode : TCallbackMode
          );
BEGIN
  IPServer.SetCallbackMode( Mode );
END SetCallbackMode;

PROCEDURE StartListen(
            Type : netsocket.TSocketType;
            Port : CARDINAL;
            PMulticastGroup : winsock.PIN_ADDR;
            PStreamCreator : TPListener;
            AutomaticCloseTimeMS : CARDINAL;	// can be 0 or INFINITE
            PCreatedSocket : POINTER TO netsocket.TPSSocket // can be NIL
          ) : CARDINAL;
BEGIN
  RETURN IPServer.StartListen( Type, Port, PMulticastGroup, PStreamCreator, AutomaticCloseTimeMS, PCreatedSocket );
END StartListen;

PROCEDURE StopListenPort( Type : netsocket.TSocketType; Port : CARDINAL );
BEGIN
  IPServer.StopListenPort( Port, Type );
END StopListenPort;

PROCEDURE StopListenSocket( OUT Socket : netsocket.TPSSocket );
BEGIN
  IPServer.StopListenSocket( Socket );
  Socket := NIL;
END StopListenSocket;

PROCEDURE Cleanup();
BEGIN
  IPServer.Dispose();
END Cleanup;

//================================================================================

END netsrv.