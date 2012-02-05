IMPLEMENTATION MODULE adviser;

FROM Debug IMPORT
   AssertionW;

IMPORT
   lists;

(*===========================================================================*)

TYPE
   TPClientData = POINTER TO CClientData;

(*---------------------------------------------------------------------------*)

CLASS CClientData;
   LOCAL VAR
      Client : ns.TPAdviseInfo := NIL;
      Advise : ns.TAdvise := ns.advNone;
END CClientData;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CClientData;
BEGIN
END CClientData;

(*===========================================================================*)

CLASS IMPLEMENTATION CAdviser;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROCEDURE OnAdvise( CONST Originator : ns.TPOriginator; CONST Result : ARRAY OF Sync.TAsyncResult; CONST Item : ARRAY OF ns.TPNameValuePairs; CONST Value : ARRAY OF iovalue.Value );
   VAR
      ClientData : TPClientData;
      Clients : lists.TPPtrList;
      i : INTEGER;
   BEGIN
      IF NOT _Advising.State THEN
         RETURN;
      END;
      _OnAdviseLock.Lock();
   
      // handle addressed advising
      FOR i := 0 TO HIGH( Item ) DO
         IF _Advised.Get( Item[i], OUT Clients ) THEN

            Clients^.Reset();
            WHILE Clients^.MoveNext() DO
               ClientData := Clients^.Current;
               CASE ClientData^.Advise OF
               | ns.advWithData :
                  ClientData^.Client^.OnAdvise( Originator, OA( 0, ADR( Result[i] )), OA( 0, ADR( Item[i] )), OA( 0, ADR( Value[i] )));
               | ns.advWithoutData :
                  ClientData^.Client^.OnAdvise( Originator, OA( 0, ADR( Result[i] )), OA( 0, ADR( Item[i] )), OA( -1, iovalue.TPValue( NIL )));
               END;
            END; // WHILE

         END;
      END; // FOR

      // handle promiscuous advising
      IF _Advised.Get( NIL, OUT Clients ) THEN

         Clients^.Reset();
         WHILE Clients^.MoveNext() DO
            ClientData := Clients^.Current;

            FOR i := 0 TO HIGH( Item ) DO
               CASE ClientData^.Advise OF
               | ns.advWithData :
                  ClientData^.Client^.OnAdvise( Originator, OA( 0, ADR( Result[i] )), OA( 0, ADR( Item[i] )), OA( 0, ADR( Value[i] )));
               | ns.advWithoutData :
                  ClientData^.Client^.OnAdvise( Originator, OA( 0, ADR( Result[i] )), OA( 0, ADR( Item[i] )), OA( -1, iovalue.TPValue( NIL )));
               END;
            END; // FOR

         END; // WHILE
      END;

      _OnAdviseLock.Unlock();
   END OnAdvise;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Running GET : BOOLEAN;
   BEGIN
      RETURN _StartStopHandler.Running;
   END Running;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Start() : Sync.TAsyncResult;
   BEGIN
      RETURN _StartStopHandler.Start();
   END Start;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Stop();
   BEGIN
      _StartStopHandler.Stop();
   END Stop;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnStart() : Sync.TAsyncResult;
   BEGIN
      _Advising.Signal();
      RETURN Sync.arCompleted;
   END OnStart;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnStop();
   BEGIN
      _Advising.Reset();
   END OnStop;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY DataSource GET : device.TPDataSource;
   BEGIN
      RETURN _DataSource;
   END DataSource;
      
(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY DataSource SET( Value : device.TPDataSource );
   BEGIN
      IF _DataSource = Value THEN
         RETURN;
      END;
      
      IF ( _DataSource <> NIL ) AND ( device.capAdviseSource IN _DataSource^.DataSourceCapabilities ) THEN
         _DataSource^.AdviseSource()^.AdviseListener := NIL;
      END;
      
      _DataSource := Value;
      
      IF _DataSource <> NIL THEN
         IF device.capAdviseSource IN _DataSource^.DataSourceCapabilities THEN
            _DataSource^.AdviseSource()^.Advise := ns.advWithData;
            _DataSource^.AdviseSource()^.AdviseListener := ADR( SELF );
         ELSE // not implemented, the adviser class should not do it
            ASSERT( FALSE );
         END;
      END;
   END DataSource;
      
(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Empty GET : BOOLEAN;
   BEGIN
      RETURN _Clients.Empty;
   END Empty;
   
(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE JoinClient( Client : ns.TPAdviseInfo; Advise : ns.TAdvise );
   VAR
      ClientData : TPClientData;
   BEGIN
      IF _Clients.Contains( Client ) THEN
         RETURN;
      END;
      
      NEW( ClientData );
      ClientData^.Client := Client;
      ClientData^.Advise := Advise;
      
      _Clients.Add( Client, ClientData );
   END JoinClient;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE LeaveClient( Client : ns.TPAdviseInfo );
   VAR
      ClientData : TPClientData;
   BEGIN
      IF _Clients.Get( Client, OUT ClientData ) THEN
         DoUnadvise( ClientData, NIL, ns.hashINVALID, TRUE );
         DISPOSE( ClientData );

         _Clients.Remove( Client );
      END;
   END LeaveClient;
   
(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Advise( Client : ns.TPAdviseInfo; CONST Name : StringsO.IString ) : BOOLEAN;
   VAR
      ClientData : TPClientData;
   BEGIN
      IF _Clients.Get( Client, OUT ClientData ) THEN
         RETURN DoAdvise( ClientData, ADR( Name ), ns.hashINVALID );
      ELSE
         RETURN FALSE;
      END;
   END Advise;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE AdviseHash( Client : ns.TPAdviseInfo; Hash : ns.THash ) : BOOLEAN;
   VAR
      ClientData : TPClientData;
   BEGIN
      IF _Clients.Get( Client, OUT ClientData ) THEN
         RETURN DoAdvise( ClientData, NIL, Hash );
      ELSE
         RETURN FALSE;
      END;
   END AdviseHash;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE AdviseAll( Client : ns.TPAdviseInfo );
   VAR
      ClientData : TPClientData;
   BEGIN
      IF _Clients.Get( Client, OUT ClientData ) THEN
         DoAdvise( ClientData, NIL, ns.hashINVALID );
      END;
   END AdviseAll;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Unadvise( Client : ns.TPAdviseInfo; CONST Name : StringsO.IString ) : BOOLEAN;
   VAR
      ClientData : TPClientData;
   BEGIN
      IF _Clients.Get( Client, OUT ClientData ) THEN
         RETURN DoUnadvise( ClientData, ADR( Name ), ns.hashINVALID, FALSE );
      ELSE
         RETURN FALSE;
      END;
   END Unadvise;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE UnadviseHash( Client : ns.TPAdviseInfo; Hash : ns.THash ) : BOOLEAN;
   VAR
      ClientData : TPClientData;
   BEGIN
      IF _Clients.Get( Client, OUT ClientData ) THEN
         RETURN DoUnadvise( ClientData, NIL, Hash, FALSE );
      ELSE
         RETURN FALSE;
      END;
   END UnadviseHash;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE UnadviseAll( Client : ns.TPAdviseInfo );
   VAR
      ClientData : TPClientData;
   BEGIN
      IF _Clients.Get( Client, OUT ClientData ) THEN
         DoUnadvise( ClientData, NIL, ns.hashINVALID, FALSE );
      END;
   END UnadviseAll;
   
(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Dispose();
   VAR
      Advised : lists.TPPtrList;
      ClientData : TPClientData;
   BEGIN
      DataSource := NIL;

      _Clients.Dispose();
      WHILE _Clients.MoveNext() DO
         ClientData := _Clients.Current;
         DISPOSE( ClientData );
      END; // WHILE      
      _Clients.Dispose();

      _Advised.Reset();
      WHILE _Advised.MoveNext() DO
         Advised := _Advised.CurrentData;
         DISPOSE( Advised );
      END; // WHILE      
      _Advised.Dispose();
   END Dispose;

(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE DoAdvise( _ClientData : ADDRESS; CONST Name : StringsO.TPString; Hash : ns.THash ) : BOOLEAN;
   VAR
      Clients : lists.TPPtrList;
      ClientData : TPClientData := _ClientData;
   BEGIN
      IF Name <> NIL THEN // want advise by name, find it it
         IF NOT _DataSource^.NS()^.Get( Name^, OUT Hash ) THEN
            RETURN FALSE;
         END;
      END;

      IF NOT _Advised.Get( Hash, OUT Clients ) THEN
         NEW( Clients );
         _Advised.Add( Hash, Clients );
      END;
      IF NOT Clients^.Contains( ClientData ) THEN
         Clients^.Add( ClientData, 0 );
      END;

      RETURN TRUE;
   END DoAdvise;

(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE DoUnadvise( _ClientData : ADDRESS; CONST Name : StringsO.TPString; Hash : ns.THash; UnadviseCompletely : BOOLEAN ) : BOOLEAN;
   VAR
      Clients : lists.TPPtrList;
      ClientData : TPClientData := _ClientData;
   BEGIN
      IF Name <> NIL THEN // want unadvise by name, do it
         IF NOT _DataSource^.NS()^.Get( Name^, OUT Hash ) THEN
            RETURN FALSE;
         END;
      END;

      IF UnadviseCompletely THEN
         _Advised.Reset();
         WHILE _Advised.MoveNext() DO
            Clients := _Advised.CurrentData;
            Clients^.Remove( ClientData );
         END; // WHILE

      ELSE
         IF _Advised.Get( Hash, OUT Clients ) THEN
            Clients^.Remove( ClientData );
         END;

      END;

      RETURN TRUE;
   END DoUnadvise;

(*---------------------------------------------------------------------------*)

BEGIN
   _DataSource := NIL;
FINALLY
   Dispose();
END CAdviser;

(*===========================================================================*)

CLASS IMPLEMENTATION CAdvisedDataSource;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY DataSourceCapabilities GET : device.TCapabilities;
   BEGIN
      IF _DataSource = NIL THEN
         ASSERT( FALSE );
         RETURN device.TCapabilities{};
      ELSE
         RETURN _DataSource^.DataSourceCapabilities;
      END;
   END DataSourceCapabilities;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Configure( CONST Source : ARRAY OF device.TConfigureItem; CONST Log : log.TPLogger ) : Sync.TAsyncResult;
   BEGIN
      IF _DataSource = NIL THEN
         ASSERT( FALSE );
         RETURN Sync.arCannotStart;
      ELSE
         RETURN _DataSource^.Configure( Source, Log );
      END;
   END Configure;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE NS() : ns.TPNamespace;
   BEGIN
      IF _DataSource = NIL THEN
         ASSERT( FALSE );
         RETURN NIL;
      ELSE
         RETURN _DataSource^.NS();
      END;
   END NS;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE AdviseSource() : ns.TPAdviseSource;
   BEGIN
      IF _DataSource = NIL THEN
         ASSERT( FALSE );
         RETURN NIL;
      ELSE
         RETURN _DataSource^.AdviseSource();
      END;
   END AdviseSource;

(*---------------------------------------------------------------------------*)

END CAdvisedDataSource;

(*===========================================================================*)

END adviser.