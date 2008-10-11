IMPLEMENTATION MODULE netstream;

FROM Storage IMPORT
  ALLOCATE;
  
(*================================================================================*)

CLASS IMPLEMENTATION CNetworkStream;

(*--------------------------------------------------------------------------------*)

  PUBLIC FINAL READONLY PROPERTY CanRead GET : BOOLEAN;
  BEGIN
    RETURN ( Socket <> NIL ) AND Socket^.Readable AND (( Access = IOO.accRead ) OR ( Access = IOO.accReadWrite ));
  END CanRead;

(*--------------------------------------------------------------------------------*)

  PUBLIC FINAL READONLY PROPERTY CanWrite GET : BOOLEAN;
  BEGIN
    RETURN ( Socket <> NIL ) AND Socket^.Connected AND (( Access = IOO.accWrite ) OR ( Access = IOO.accReadWrite ));
  END CanWrite;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC FINAL READONLY PROPERTY CanSeek GET : BOOLEAN;
  BEGIN
    RETURN FALSE;
  END CanSeek;

(*--------------------------------------------------------------------------------*)

  PUBLIC FINAL READONLY PROPERTY Long GET : BOOLEAN;
  BEGIN
    RETURN FALSE;
  END Long;

(*--------------------------------------------------------------------------------*)

  PUBLIC FINAL PROPERTY Length GET : CARD64;
  BEGIN
    IF Socket = NIL THEN
      RETURN 0;
    ELSE
      RETURN CARD64( Socket^.DataAvailable );
    END;
  END Length;

(*--------------------------------------------------------------------------------*)

  PUBLIC FINAL PROPERTY Length SET( Value : CARD64 );
  BEGIN
  END Length;

(*--------------------------------------------------------------------------------*)

  PUBLIC FINAL PROPERTY Position GET : CARD64;
  BEGIN
    RETURN 0;
  END Position;

(*--------------------------------------------------------------------------------*)

  PUBLIC FINAL PROPERTY Position SET( Value : CARD64 );
  BEGIN
  END Position;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE FromSocket( Socket : netsocket.TPDSocket; TakeSocketOwnership : BOOLEAN; Access : IOO.TAccess ); // Access tells the stream what should be allowed
  BEGIN
    Close( FALSE );
    Socket^.AddRef();
    SELF.Socket := Socket;
    IF TakeSocketOwnership THEN
      OwnHandle := TRUE;
    END;
    SELF.Access := Access;
  END FromSocket;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE FromServer( CONST Server : ARRAY OF WCHAR );
  VAR
    Result : Sync.TAsyncResult;
  BEGIN
    Close( FALSE );

    NEW( Socket );
    Socket^.Waitable := TRUE;
    Result := Socket^.Connect( Server, netsocket.FORSAFETY );
    IF ( Result IN Sync.arsStarts ) AND ( Socket^.WaitCompletion( netsocket.FORSAFETY + 100 ) = Sync.arCompleted ) THEN
       Access := IOO.accReadWrite;
       OwnHandle := TRUE;
    ELSE
      Socket^.Release();
      Socket := NIL;
    END;
  END FromServer;

(*--------------------------------------------------------------------------------*)

  PUBLIC FINAL PROCEDURE Seek( Origin : IOO.TSeekOrigin; Position : INT64 ); 
  BEGIN
  END Seek;

(*--------------------------------------------------------------------------------*)

  PUBLIC FINAL PROCEDURE Flush();
  BEGIN
  END Flush;

(*--------------------------------------------------------------------------------*)

  PUBLIC FINAL PROCEDURE Close( Persist : BOOLEAN );
  BEGIN
    AbortReading();
    AbortWriting();
    IF Socket <> NIL THEN
      IF OwnHandle THEN
        Socket^.Disconnect( TRUE, netsocket.FORSAFETY ); // Close is Close, if I want to read (after peer close), I can, I cannot call Close. So Disconnect can be Abortive.
      END;
      IF NOT Persist THEN
        Socket^.Release();
        Socket := NIL;
        OwnHandle := FALSE;
        Access := IOO.accUnknown;
      END;
    END;
  END Close;
  
(*--------------------------------------------------------------------------------*)

  INTERNAL FINAL PROCEDURE Start( Direction : IOO.TDirection; OperationTimeoutMS : CARDINAL ) : Sync.TAsyncResult;
  BEGIN
    IF Socket = NIL THEN
      RETURN Sync.arCannotStart;
    ELSIF Direction = IOO.dirRead THEN
      RETURN Socket^.Receive( ADR( RProxy ), OperationTimeoutMS, FALSE );
    ELSIF Direction = IOO.dirWrite THEN
      RETURN Socket^.Send( ADR( WProxy ), OperationTimeoutMS, FALSE );
    ELSE
      RETURN Sync.arCannotStart;
    END;
  END Start;

(*--------------------------------------------------------------------------------*)

  INTERNAL FINAL PROCEDURE Abort( Direction : IOO.TDirection );
  BEGIN
    IF Socket = NIL THEN
      // fall down
    ELSIF Direction = IOO.dirRead THEN
      Socket^.AbortReceive();
    ELSIF Direction = IOO.dirWrite THEN
      Socket^.AbortSend();
    END;
    DeviceFinish( Direction, Sync.arAborted );
  END Abort;

(*--------------------------------------------------------------------------------*)

BEGIN
  Access := IOO.accUnknown;
  Socket := NIL;
  OwnHandle := FALSE;
  RProxy.Init( IOO.dirRead, ADR( SELF ));
  WProxy.Init( IOO.dirWrite, ADR( SELF ));
FINALLY
  Close( FALSE );
END CNetworkStream;

(*================================================================================*)

END netstream.