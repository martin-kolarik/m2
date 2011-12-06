IMPLEMENTATION MODULE adviser;

FROM Debug IMPORT
   AssertionW;

IMPORT
   collection,
   lists;

(*===========================================================================*)

TYPE
   TPClientData = POINTER TO CClientData;

(*---------------------------------------------------------------------------*)

CLASS CClientData;
   LOCAL VAR
      Client : io.TPIAdviseInfo := NIL;
      Advise : io.TAdvise := io.advNone;
END CClientData;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CClientData;
BEGIN
END CClientData;

(*===========================================================================*)

CLASS IMPLEMENTATION CAdviser;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   VAR
      Advised : lists.TPPtrList;
      ClientData : TPClientData;
      it : maps.CPtrPtrMapIterator;
   BEGIN
      Device := NIL;

      it.Init( _Clients, collection.dirForward );
      WHILE it.MoveNext() DO
         ClientData := it.Key;
         DISPOSE( ClientData );
      END; // WHILE      
      _Clients.Dispose();

      it.Init( _Advised, collection.dirForward );
      WHILE it.MoveNext() DO
         Advised := it.Value;
         DISPOSE( Advised );
      END; // WHILE      
      _Advised.Dispose();
   END Dispose;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROCEDURE OnAdvise( Source : io.TPIO; CONST Result : ARRAY OF Sync.TAsyncResult; CONST Item : ARRAY OF ns.THash; CONST Value : ARRAY OF iovalue.Value );
   VAR
      ClientData : TPClientData;
      Clients : lists.TPPtrList;
      d : PTR;
      i : INTEGER;
      it : maps.CPtrPtrMapIterator;
   BEGIN
      IF NOT _Advising.State THEN
         RETURN;
      END;
      _OnAdviseLock.Lock();
   
      // handle addressed advising
      FOR i := 0 TO HIGH( Item ) DO
         IF _Advised.Get( Item[i], OUT Clients, OUT d ) THEN

            it.Init( Clients^, collection.dirForward );
            WHILE it.MoveNext() DO
               ClientData := it.Key;
               CASE ClientData^.Advise OF
               | io.advWithData :
                  ClientData^.Client^.OnAdvise( Source, OA( 0, ADR( Result[i] )), OA( 0, ADR( Item[i] )), OA( 0, ADR( Value[i] )));
               | io.advWithoutData :
                  ClientData^.Client^.OnAdvise( Source, OA( 0, ADR( Result[i] )), OA( 0, ADR( Item[i] )), OA( -1, iovalue.TPValue( NIL )));
               END;
            END; // WHILE

         END;
      END; // FOR

      // handle promiscuous advising
      IF _Advised.Get( NIL, OUT Clients, OUT d ) THEN

         it.Init( Clients^, collection.dirForward );
         WHILE it.MoveNext() DO
            ClientData := it.Key;

            FOR i := 0 TO HIGH( Item ) DO
               CASE ClientData^.Advise OF
               | io.advWithData :
                  ClientData^.Client^.OnAdvise( Source, OA( 0, ADR( Result[i] )), OA( 0, ADR( Item[i] )), OA( 0, ADR( Value[i] )));
               | io.advWithoutData :
                  ClientData^.Client^.OnAdvise( Source, OA( 0, ADR( Result[i] )), OA( 0, ADR( Item[i] )), OA( -1, iovalue.TPValue( NIL )));
               END;
            END; // FOR

         END; // WHILE
      END;

      _OnAdviseLock.Unlock();
   END OnAdvise;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Device GET : device.TPDevice;
   BEGIN
      RETURN _Device;
   END Device;
      
(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Device SET( Value : device.TPDevice );
   BEGIN
      IF _Device = Value THEN
         RETURN;
      END;
      
      IF _Device <> NIL THEN
         _Device^.IO()^.AdviseListener := NIL;
      END;
      
      _Device := Value;
      
      IF _Device <> NIL THEN
         IF io.capAdvise IN _Device^.IO()^.IOCapabilities THEN
            _Device^.IO()^.Advise := io.advWithData;
            _Device^.IO()^.AdviseListener := ADR( SELF );
         ELSE // not implemented, the adviser class should not do it
            ASSERT( FALSE );
         END;
      END;
   END Device;
      
(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Empty GET : BOOLEAN;
   BEGIN
      RETURN _Clients.Empty;
   END Empty;
   
(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE JoinClient( Client : io.TPIAdviseInfo; Advise : io.TAdvise );
   VAR
      ClientData : TPClientData;
   BEGIN
      IF _Clients.Contains( Client ) THEN
         RETURN;
      END;
      
      NEW( ClientData );
      ClientData^.Client := Client;
      ClientData^.Advise := Advise;
      
      _Clients.Add( Client, ClientData, 0 );
   END JoinClient;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE LeaveClient( Client : io.TPIAdviseInfo );
   VAR
      ClientData : TPClientData;
      d : PTR;
   BEGIN
      IF _Clients.Get( Client, OUT ClientData, OUT d ) THEN
         DoUnadvise( ClientData, NIL, ns.hashINVALID, TRUE );
         DISPOSE( ClientData );

         _Clients.Remove( Client );
      END;
   END LeaveClient;
   
(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Advise( Client : io.TPIAdviseInfo; CONST Name : StringsO.CString ) : BOOLEAN;
   VAR
      ClientData : TPClientData;
      d : PTR;
   BEGIN
      IF _Clients.Get( Client, OUT ClientData, OUT d ) THEN
         RETURN DoAdvise( ClientData, ADR( Name ), ns.hashINVALID );
      ELSE
         RETURN FALSE;
      END;
   END Advise;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE AdviseHash( Client : io.TPIAdviseInfo; Hash : ns.THash ) : BOOLEAN;
   VAR
      ClientData : TPClientData;
      d : PTR;
   BEGIN
      IF _Clients.Get( Client, OUT ClientData, OUT d ) THEN
         RETURN DoAdvise( ClientData, NIL, Hash );
      ELSE
         RETURN FALSE;
      END;
   END AdviseHash;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE AdviseAll( Client : io.TPIAdviseInfo );
   VAR
      ClientData : TPClientData;
      d : PTR;
   BEGIN
      IF _Clients.Get( Client, OUT ClientData, OUT d ) THEN
         DoAdvise( ClientData, NIL, ns.hashINVALID );
      END;
   END AdviseAll;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Unadvise( Client : io.TPIAdviseInfo; CONST Name : StringsO.CString ) : BOOLEAN;
   VAR
      ClientData : TPClientData;
      d : PTR;
   BEGIN
      IF _Clients.Get( Client, OUT ClientData, OUT d ) THEN
         RETURN DoUnadvise( ClientData, ADR( Name ), ns.hashINVALID, FALSE );
      ELSE
         RETURN FALSE;
      END;
   END Unadvise;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE UnadviseHash( Client : io.TPIAdviseInfo; Hash : ns.THash ) : BOOLEAN;
   VAR
      ClientData : TPClientData;
      d : PTR;
   BEGIN
      IF _Clients.Get( Client, OUT ClientData, OUT d ) THEN
         RETURN DoUnadvise( ClientData, NIL, Hash, FALSE );
      ELSE
         RETURN FALSE;
      END;
   END UnadviseHash;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE UnadviseAll( Client : io.TPIAdviseInfo );
   VAR
      ClientData : TPClientData;
      d : PTR;
   BEGIN
      IF _Clients.Get( Client, OUT ClientData, OUT d ) THEN
         DoUnadvise( ClientData, NIL, ns.hashINVALID, FALSE );
      END;
   END UnadviseAll;
   
(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Start();
   BEGIN
      _Advising.Signal();
   END Start;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Stop();
   BEGIN
      _Advising.Reset();
   END Stop;

(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE DoAdvise( _ClientData : ADDRESS; CONST Name : StringsO.TPString; Hash : ns.THash ) : BOOLEAN;
   VAR
      Clients : lists.TPPtrList;
      ClientData : TPClientData := _ClientData;
      d : PTR;
   BEGIN
      IF Name <> NIL THEN // want advise by name, find it it
         IF NOT _Device^.Mapper()^.NameToHash( Name^, OUT Hash ) THEN
            RETURN FALSE;
         END;
      END;

      IF NOT _Advised.Get( Hash, OUT Clients, OUT d ) THEN
         NEW( Clients );
         _Advised.Add( Hash, Clients, 0 );
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
      d : PTR;
      it : maps.CPtrPtrMapIterator;
   BEGIN
      IF Name <> NIL THEN // want unadvise by name, do it
         IF NOT _Device^.Mapper()^.NameToHash( Name^, OUT Hash ) THEN
            RETURN FALSE;
         END;
      END;

      IF UnadviseCompletely THEN
         it.Init( _Advised, collection.dirForward );
         WHILE it.MoveNext() DO
            Clients := it.Value;
            Clients^.Remove( ClientData );
         END; // WHILE

      ELSE
         IF _Advised.Get( Hash, OUT Clients, OUT d ) THEN
            Clients^.Remove( ClientData );
         END;

      END;

      RETURN TRUE;
   END DoUnadvise;

(*---------------------------------------------------------------------------*)

BEGIN
   _Device := NIL;
FINALLY
   Dispose();
END CAdviser;

(*===========================================================================*)

CLASS IMPLEMENTATION CAdvisedDevice;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Type GET : iplugin.TObjectType;
   BEGIN
      IF _Device = NIL THEN
         ASSERT( FALSE );
         RETURN iplugin.otSingleton;
      ELSE
         RETURN _Device^.Type;
      END;
   END Type;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY OfPlugin GET : iplugin.TPPlugin;
   BEGIN
      IF _Device = NIL THEN
         ASSERT( FALSE );
         RETURN NIL;
      ELSE
         RETURN _Device^.OfPlugin;
      END;
   END OfPlugin;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY OwnerHandle GET : PTR;
   BEGIN
      IF _Device = NIL THEN
         ASSERT( FALSE );
         RETURN NIL;
      ELSE
         RETURN _Device^.OwnerHandle;
      END;
   END OwnerHandle;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY DeviceCapabilities GET : device.TCapabilities;
   BEGIN
	   IF _Device = NIL THEN
	      ASSERT( FALSE );
	      RETURN device.TCapabilities{};
	   ELSE
	      RETURN _Device^.DeviceCapabilities;
	   END;
   END DeviceCapabilities;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE Configure( CONST Source : ARRAY OF device.TConfigureItem; CONST Log : log.TPLogger ) : Sync.TAsyncResult;
	BEGIN
	   IF _Device = NIL THEN
	      ASSERT( FALSE );
	      RETURN Sync.arCannotStart;
	   ELSE
	      RETURN _Device^.Configure( Source, Log );
	   END;
	END Configure;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Mapper() : ns.TPMapper;
   BEGIN
	   IF _Device = NIL THEN
	      ASSERT( FALSE );
	      RETURN NIL;
	   ELSE
	      RETURN _Device^.Mapper();
	   END;
	END Mapper;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE NS() : ns.TPns;
	BEGIN
	   IF _Device = NIL THEN
	      ASSERT( FALSE );
	      RETURN NIL;
	   ELSE
	      RETURN _Device^.NS();
	   END;
	END NS;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE IO() : io.TPIO;
	BEGIN
	   IF _Device = NIL THEN
	      ASSERT( FALSE );
	      RETURN NIL;
	   ELSE
	      RETURN _Device^.IO();
	   END;
	END IO;

(*---------------------------------------------------------------------------*)

END CAdvisedDevice;

(*===========================================================================*)

END adviser.
