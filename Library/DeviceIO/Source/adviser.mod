IMPLEMENTATION MODULE adviser;

IMPORT
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

   PUBLIC FINAL PROCEDURE OnAdvise( Source : io.TPIO; CONST Result : ARRAY OF Sync.TAsyncResult; CONST Item : ARRAY OF ns.THash; CONST Value : ARRAY OF iovalue.Value );
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
               | io.advWithData :
                  ClientData^.Client^.OnAdvise( Source, OA( 0, ADR( Result[i] )), OA( 0, ADR( Item[i] )), OA( 0, ADR( Value[i] )));
               | io.advWithoutData :
                  ClientData^.Client^.OnAdvise( Source, OA( 0, ADR( Result[i] )), OA( 0, ADR( Item[i] )), OA( -1, iovalue.TPValue( NIL )));
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
         IF io.capAdvise NOT IN _Device^.IO()^.IOCapabilities THEN
            // not implemented, the adviser class should not do it
            ASSERT( FALSE );
         END;
         _Device^.IO()^.Advise := io.advWithData;
         _Device^.IO()^.AdviseListener := ADR( SELF );
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
      
      _Clients.Add( Client, ClientData );
   END JoinClient;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE LeaveClient( Client : io.TPIAdviseInfo );
   VAR
      ClientData : TPClientData;
   BEGIN
      IF _Clients.Get( Client, OUT ClientData ) THEN
         DoUnadvise( ClientData, NIL, TRUE );
         DISPOSE( ClientData );

         _Clients.Remove( Client );
      END;
   END LeaveClient;
   
(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Advise( Client : io.TPIAdviseInfo; CONST Name : StringsO.CString ) : BOOLEAN;
   VAR
      ClientData : TPClientData;
   BEGIN
      IF _Clients.Get( Client, OUT ClientData ) THEN
         RETURN DoAdvise( ClientData, ADR( Name ));
      ELSE
         RETURN FALSE;
      END;
   END Advise;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE AdviseAll( Client : io.TPIAdviseInfo );
   VAR
      ClientData : TPClientData;
   BEGIN
      IF _Clients.Get( Client, OUT ClientData ) THEN
         DoAdvise( ClientData, NIL );
      END;
   END AdviseAll;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Unadvise( Client : io.TPIAdviseInfo; CONST Name : StringsO.CString ) : BOOLEAN;
   VAR
      ClientData : TPClientData;
   BEGIN
      IF _Clients.Get( Client, OUT ClientData ) THEN
         RETURN DoUnadvise( ClientData, ADR( Name ), FALSE );
      ELSE
         RETURN FALSE;
      END;
   END Unadvise;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE UnadviseAll( Client : io.TPIAdviseInfo );
   VAR
      ClientData : TPClientData;
   BEGIN
      IF _Clients.Get( Client, OUT ClientData ) THEN
         DoUnadvise( ClientData, NIL, FALSE );
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

   PUBLIC PROCEDURE Dispose();
   VAR
      Advised : lists.TPPtrList;
      ClientData : TPClientData;
   BEGIN
      Device := NIL;

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

   PRIVATE PROCEDURE DoAdvise( _ClientData : ADDRESS; CONST Name : StringsO.TPString ) : BOOLEAN;
   VAR
      Clients : lists.TPPtrList;
      ClientData : TPClientData := _ClientData;
      Hash : ns.THash := ns.hashINVALID;
   BEGIN
      IF Name <> NIL THEN // want advise single, find it it
         IF NOT _Device^.Mapper()^.NameToHash( Name^, OUT Hash ) THEN
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

   PRIVATE PROCEDURE DoUnadvise( _ClientData : ADDRESS; CONST Name : StringsO.TPString; UnadviseCompletely : BOOLEAN ) : BOOLEAN;
   VAR
      Clients : lists.TPPtrList;
      ClientData : TPClientData := _ClientData;
      Hash : ns.THash := ns.hashINVALID;
   BEGIN
      IF Name <> NIL THEN // want unadvise single, do it
         IF NOT _Device^.Mapper()^.NameToHash( Name^, OUT Hash ) THEN
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
         IF ( Name = NIL ) AND _Advised.Get( Hash, OUT Clients ) THEN // wants to unadvise all, remove client
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

   PUBLIC VIRTUAL PROPERTY Type GET : iobject.TObjectType;
   BEGIN
      IF _Device = NIL THEN
         ASSERT( FALSE );
         RETURN iobject.otSingleton;
      ELSE
         RETURN _Device^.Type;
      END;
   END Type;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Library GET : iobject.TPLibrary;
   BEGIN
      IF _Device = NIL THEN
         ASSERT( FALSE );
         RETURN NIL;
      ELSE
         RETURN _Device^.Library;
      END;
   END Library;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Library SET( Value : iobject.TPLibrary );
   BEGIN
      IF _Device = NIL THEN
         ASSERT( FALSE );
      ELSE
         _Device^.Library := Value;
      END;
   END Library;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnDispose(); // meant not as Command, but as Callback, usually, destroying of object is done with ReleaseObject of some loader.
   BEGIN
      IF _Device <> NIL THEN
         _Device^.OnDispose();
      END;
   END OnDispose;

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

   PUBLIC VIRTUAL PROCEDURE Mapper() : ns.TPMapper; // required
   BEGIN
	   IF _Device = NIL THEN
	      ASSERT( FALSE );
	      RETURN NIL;
	   ELSE
	      RETURN _Device^.Mapper();
	   END;
	END Mapper;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE NS() : ns.TPns; // optional
	BEGIN
	   IF _Device = NIL THEN
	      ASSERT( FALSE );
	      RETURN NIL;
	   ELSE
	      RETURN _Device^.NS();
	   END;
	END NS;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE IO() : io.TPIO; // required
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