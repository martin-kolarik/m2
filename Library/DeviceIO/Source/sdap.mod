IMPLEMENTATION MODULE sdap;

(*================================================================================*)

FROM Debug IMPORT
   AssertionW;

IMPORT
   collection,
   device,
   io,
   IOO,
   netsocket,
   netsrv,
   ns,
   nsimpl,
   Strings,
   Sync;

CONST
   MSG_ADVISE_SEND = msghandler.MSG_BASE;
   LOG_SDAP = L"sdap";

(*================================================================================*)

TYPE
   TPClient = POINTER TO CClient;

CLASS CClient IMPLEMENTS ns.IAdviseInfo;

   // IAdviseInfo
   PUBLIC VIRTUAL PROCEDURE OnAdvise( CONST Originator : ns.TPOriginator; CONST Result : ARRAY OF Sync.TAsyncResult; CONST Item : ARRAY OF ns.TPNameValuePairs; CONST Value : ARRAY OF iovalue.Value );

   // SELF
   LOCAL VAR
      Server : TPSDAPServer;
      Connection : netconndispatch.TConnectionHandle;
      Context : StringsO.CString;

END CClient;

(*================================================================================*)

TYPE
   TsdapCommand = (
      sdapEXIT,
      sdapLOAD,
      sdapSET,
      sdapGET,
      sdapRUN,
      sdapSTOP,
      sdapCONTEXT,
      sdapADVISE, // advise <N> or advise all
      sdapUNADVISE
   );

   TsdapSubcommand = (
      sdapName,
      sdapGlobal,
      sdapDevice
   );
   
(*================================================================================*)

CLASS IMPLEMENTATION CSDAPServer;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnMessage( CONST Message : msghandler.IMessage; OUT Result : PTR ) : BOOLEAN;
   VAR
      b : BOOLEAN;
      client : TPClient;
      count : CARDINAL;
      s : StringsO.CString;
   BEGIN
      IF SUPER.OnMessage( Message, OUT Result ) THEN
         RETURN TRUE;

      ELSIF Message.Message = MSG_ADVISE_SEND THEN
         count := 16;
         LOOP
            _SendLock.Lock();
            b := _SendQueue.Dequeue( OUT s, OUT client );
            _SendLock.Unlock();
            IF NOT b THEN
               EXIT;
            END;

            // for disconnected clients Data of _SendQueue was reset to NIL
            IF client <> NIL THEN
               Send( NIL, TPClient( client )^.Connection, 0, s.Data, s.Length<<1 );
            END;

            DEC( count );
            IF count = 0 THEN
               SUPER.Message( Message, msghandler.delDefault, NIL ); // resend the message to continue with next 16 data in next loop
               EXIT;
            END;
         END; // LOOP

         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END OnMessage;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY DataSource GET : adviser.TPAdvisedDataSource;
   BEGIN
      RETURN _DataSource;
   END DataSource;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY DataSource SET( Value : adviser.TPAdvisedDataSource );
   BEGIN
      _DataSource := Value;
   END DataSource;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY CommonLogger GET : log.TPILogger;
   BEGIN
      RETURN _CommonLogger;
   END CommonLogger;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY CommonLogger SET( Value : log.TPILogger );
   BEGIN
      IF _CommonLogger = Value THEN
         RETURN;
      ELSIF Value = NIL THEN
         _CommonLogger := log.logger();
      ELSE
         _CommonLogger := Value;
      END;
   END CommonLogger;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY ConfigurationLogger GET : log.TPBufferedLogger;
   BEGIN
      RETURN _ConfigurationLogger;
   END ConfigurationLogger;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY ConfigurationLogger SET( Value : log.TPBufferedLogger );
   BEGIN
      IF _ConfigurationLogger = Value THEN
         RETURN;
      ELSIF Value = NIL THEN
         _ConfigurationLogger := log.logger();
      ELSE
         _ConfigurationLogger := Value;
      END;
   END ConfigurationLogger;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY NetworkLogger GET : log.TPILogger;
   BEGIN
      RETURN _NetworkLogger;
   END NetworkLogger;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY NetworkLogger SET( Value : log.TPILogger );
   BEGIN
      IF _NetworkLogger = Value THEN
         RETURN;
      ELSIF Value = NIL THEN
         _NetworkLogger := log.logger();
      ELSE
         _NetworkLogger := Value;
      END;
   END NetworkLogger;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY ListenAddress GET : inetaddr.INETADDR;
   BEGIN
      RETURN _ListenAddress;
   END ListenAddress;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY ListenAddress SET( CONST Value : inetaddr.INETADDR );
   BEGIN
      IF _ListenAddress = Value THEN
         RETURN;
      END;
      IF _Running THEN
         Stop();
         _ListenAddress := Value;
         Start();
      ELSE
         _ListenAddress := Value;
      END;
   END ListenAddress;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY DefaultContext GET : StringsO.CString;
   BEGIN
      RETURN _DefaultContext;
   END DefaultContext;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY DefaultContext SET( CONST Value : StringsO.CString );
   VAR
      dot : StringsO.CString := StringsO.FromOA( L"." );
   BEGIN
      _DefaultContext := Value;
      WHILE _DefaultContext.EndsWith( dot ) DO
         DEC( _DefaultContext.Length );
      END;
   END DefaultContext;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Running GET : BOOLEAN;
   BEGIN
      RETURN _Running;
   END Running;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Start() : Sync.TAsyncResult;
   BEGIN
      IF _Running THEN
         RETURN Sync.arCompleted;
      ELSE
         _Running := TRUE;
      END;
      netsrv.StartListen( netsocket.stStream, _ListenAddress, NIL, Listener, 0, NIL );

      RETURN Sync.arCompleted;
   END Start;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Stop();
   BEGIN
      IF _Running THEN
         _Running := FALSE;
      ELSE
         RETURN;
      END;
      netsrv.StopListenServer( netsocket.stStream, _ListenAddress );
      // kill all connections
   END Stop;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnConnect( Connection : netconndispatch.TConnectionHandle; Local : BOOLEAN; Error : CARDINAL );
   VAR
      address : ARRAY [0..63] OF WCHAR;
      Client : TPClient;
   BEGIN
      ASSERTLOG( NOT _Clients.Contains( Connection ));
      
      IF NOT _NetworkLogger^.FilteredFastCheck( log.lcError, 0 ) THEN
         Connection^.RemoteAddress.ToOA( TRUE, NIL, OUT address );
         _NetworkLogger^.LogSS( log.lcError, 0, LOG_SDAP, "CONNECT:", address );
      END;

      NEW( Client );
      Client^.Server := ADR( SELF );
      Client^.Connection := Connection;
      Client^.Context := DefaultContext;

      _DataSource^.JoinClient( Client, ns.advWithData );
      // done on request only
      // _Device^.AdviseAll( Client );

      _Clients.Add( Connection, Client, 0 );
   END OnConnect;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnDisconnect( Connection : netconndispatch.TConnectionHandle; Local : BOOLEAN; Error : CARDINAL );
   VAR
      address : ARRAY [0..63] OF WCHAR;
      Client : TPClient;
      d : PTR;
      it : lists.CStringListIterator;
   BEGIN
      IF NOT _NetworkLogger^.FilteredFastCheck( log.lcError, 0 ) THEN
         Connection^.RemoteAddress.ToOA( TRUE, NIL, OUT address );
         _NetworkLogger^.LogSS( log.lcError, 0, LOG_SDAP, "DISCONNECT:", address );
      END;

      IF _Clients.Get( Connection, OUT Client, OUT d ) THEN
         _Clients.Remove( Connection );

         _DataSource^.UnadviseAll( Client );
         _DataSource^.LeaveClient( Client );
         
         // mark pending send data as unusable
         _SendLock.Lock();
         it.Init( _SendQueue, collection.dirForward );
         WHILE it.MoveNext() DO
            IF it.Data = PTR( Client ) THEN
               it.Data := NIL; // reset Data field
            END;
         END; // WHILE
         _SendLock.Unlock();

         DISPOSE( Client );
      END;
   END OnDisconnect;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnReceive( PConnection : netconndispatch.TConnectionHandle; PData : ADDRESS; DataLen : CARDINAL );
   VAR
      allFlag : BOOLEAN;
      Client : TPClient;
      Command : TsdapCommand;
      configuration : ARRAY [0..0] OF device.TConfigureItem;
      count, prevcount : CARDINAL;
      d : PTR;
      data : StringsO.CString; // data
      error : ARRAY [0..511] OF WCHAR;
      i : CARDINAL;
      ia : inetaddr.INETADDR;
      IOValue : iovalue.Value;
      l : CARDINAL;
      Originator : io.CSimpleOriginator;
      in, out : StringsO.CString;
      p : ARRAY [0..1] OF StringsO.CString; // parameters
      parametersCount : CARDINAL;
      parametersFound : CARDINAL;
      pvalue : ns.TPNameValuePairs;
      Result : Sync.TAsyncResult;
      s : ARRAY [0..1] OF StringsO.CString; // sub parameters
      sd : ARRAY [0..63] OF WCHAR;
      Subcommand : TsdapSubcommand;
   BEGIN
      in.FromOA( OA( DataLen>>1-1, PWCHAR( PData )));
      IF in.EndsWithOA( 13W + 10W ) THEN
         in.Length := in.Length - 2;
      END;
      _CommonLogger^.LogSS( log.ldDebug, 0, LOG_SDAP, "RCV:", OA( in.Length-1, in.Data ));
      PConnection^.RemoteAddress.ToOA( TRUE, NIL, OUT sd );
      _CommonLogger^.LogSS( log.ldDebug, 0, LOG_SDAP, "from:", sd );

      i := in.SplitS( StringsO.WCHARS{L' '}, 0, TRUE, OUT parametersFound, OUT p ); // i contains position, where splitting should continue if called again
      IF i < in.Length THEN // splitting is not finished
         in.Substring( i, -1, OUT data );
         INC( parametersFound );
      END;

      p[0].Lowerize();
      IF p[0].Empty THEN
         ACK( PConnection, sdap400 );
         RETURN;
      END;

      // split command and subcommand
      parametersCount := 2;
      p[0].SplitS( StringsO.WCHARS{L'.'}, 0, FALSE, OUT l, OUT s );
      IF s[0].EqualsOA( L"exit" ) THEN
         Command := sdapEXIT;
         parametersCount := 1;
      ELSIF s[0].EqualsOA( L"load" ) THEN
         Command := sdapLOAD;
         parametersCount := 2;
      ELSIF s[0].EqualsOA( L"set" ) THEN
         Command := sdapSET;
         parametersCount := 3;
      ELSIF s[0].EqualsOA( L"get" ) THEN
         Command := sdapGET;
       ELSIF s[0].EqualsOA( L"run" ) THEN
         Command := sdapRUN;
         parametersCount := 1;
      ELSIF s[0].EqualsOA( L"stop" ) THEN
         Command := sdapSTOP;
         parametersCount := 1;
      ELSIF s[0].EqualsOA( L"context" ) THEN
         Command := sdapCONTEXT;
         parametersCount := 1;
      ELSIF s[0].EqualsOA( L"advise" ) THEN
         Command := sdapADVISE;
      ELSIF s[0].EqualsOA( L"unadvise" ) THEN
         Command := sdapUNADVISE;
      ELSE
         ACK( PConnection, sdap401 );
         RETURN;
      END;
      IF parametersFound < parametersCount THEN
         ACK( PConnection, sdap403 );
         RETURN;
      END;

      // decoding and check    
      CASE Command OF
      //-----
      | sdapEXIT :
      //-----
      | sdapLOAD :
      //-----
      | sdapSET, sdapGET :
         IF s[1].Empty THEN
            Subcommand := sdapName;
         ELSIF s[1].EqualsOA( L"global" ) THEN
            Subcommand := sdapGlobal;
            ACK( PConnection, sdap402 );
            RETURN;
         ELSIF s[1].EqualsOA( L"device" ) THEN
            Subcommand := sdapDevice;
            ACK( PConnection, sdap402 );
            RETURN;
         ELSE
            ACK( PConnection, sdap402 );
            RETURN;
         END;
      //-----
      | sdapADVISE, sdapUNADVISE :
      //-----
      | sdapCONTEXT :
      ELSE
         ACK( PConnection, sdap502 ); // not supported
         RETURN;
      END; // CASE

      // check presence of parameter
      FOR i := 0 TO MIN2( HIGH( p ), parametersCount-1 ) DO
         IF p[i].Empty THEN
            ACKs( PConnection, sdap403, i );
            RETURN;
         END;
      END;

      CASE Command OF
      //-----
      | sdapEXIT :
         PConnection^.RemoteAddress.ToOA( TRUE, NIL, OUT sd );
         _CommonLogger^.LogSS( log.ldTrace, 0, LOG_SDAP, "EXIT from:", sd );

         ACK( PConnection, sdap200 );
         Disconnect( NIL, PConnection );

      //-----
      | sdapLOAD :
         // recode parameters
         in.Substring( p[0].Length + 1, -1, OUT data );

         _CommonLogger^.LogSS( log.ldTrace, 0, LOG_SDAP, "LOAD:", OA( data.Length-1, data.Data ));

         // stop, load
         prevcount := _ConfigurationLogger^.BufferCount;
         configuration[0].Type := device.citIString;
         configuration[0].iString := ADR( data );
         IF DataSource^.Configure( configuration, _ConfigurationLogger ) = Sync.arCompleted THEN
            ACK( PConnection, sdap200 );
         ELSE
            // emit count of errors
            count := _ConfigurationLogger^.BufferCount - prevcount;
            out.FromINT32( count, 10 );
            ACKS( PConnection, sdap406, out );
            // emit errors
            i := prevcount;
            WHILE _ConfigurationLogger^.BufferGetItem( i, OUT error ) DO
               Strings.TrimAccentsW( REF error );

               _CommonLogger^.LogSS( log.ldDebug, 0, LOG_SDAP, "  406:", error );
               SUPER.Send( NIL, PConnection, 0, ADR( error ), LENGTH( error ) << 1 );
               
               INC( i );
            END; // FOR
         END; // CASE

      //-----
      | sdapSET, sdapGET :
         IF NOT _Clients.Get( PConnection, OUT Client, OUT d ) THEN // unexpected client
            ACK( PConnection, sdap500 );
            RETURN;
         END;

         IF Command = sdapSET THEN
            _CommonLogger^.LogSSSS( log.ldTrace, 0, LOG_SDAP, "SET", OA( p[1].Length-1, p[1].Data ), OA( data.Length-1, data.Data ), L"" );
         ELSE
            _CommonLogger^.LogSS( log.ldTrace, 0, LOG_SDAP, "GET", OA( p[1].Length-1, p[1].Data ));
         END;

         IF NOT _DataSource^.NS()^.Get( nsimpl.AddContext( Client^.Context, p[1] ), OUT pvalue ) OR NOT pvalue^.VisibleToUser THEN
            ACKs( PConnection, sdap405, 1 );

         ELSIF NOT pvalue^.HasValue THEN
            ACKs( PConnection, sdap408, 1 );

         ELSE

            ia := GetRemoteAddress( PConnection );
            ia.ToOA( TRUE, NIL, OUT sd );
            out.FromOA( LOG_SDAP ); out.AppendOA( L"/" ); out.AppendOA( sd );
            Originator.SetDescription( out );

            IF Command = sdapSET THEN // expect data.name (aka data.x/x/x)
               IOValue.String := data;

               Result := pvalue^.ValueIO( ADR( Originator ), pvalue, IOO.dirWrite, REF IOValue );
               CASE Result OF
               | Sync.arCompleted :
                  ACK( PConnection, sdap200 );
               | Sync.arCompletedFromCache :
                  ACK( PConnection, sdap201 );
               ELSE
                  ACK( PConnection, sdap501 );
               END;
       
            ELSE
        
               Result := pvalue^.ValueIO( ADR( Originator ), pvalue, IOO.dirRead, REF IOValue );
               CASE Result OF
               | Sync.arCompleted :
                  ACKd( PConnection, sdap200, p[1], IOValue );
               | Sync.arCompletedFromCache :
                  ACKd( PConnection, sdap201, p[1], IOValue );
               ELSE
                  ACK( PConnection, sdap501 );
               END;
       
            END; // IF SET or GET

         END;
         
      //-----
      | sdapADVISE, sdapUNADVISE :
         IF NOT _Clients.Get( PConnection, OUT Client, OUT d ) THEN // unexpected client
            ACK( PConnection, sdap500 );
            RETURN;
         END;

         IF Command = sdapADVISE THEN
            _CommonLogger^.LogSS( log.ldTrace, 0, LOG_SDAP, "ADVISE", OA( p[1].Length-1, p[1].Data ));
         ELSE
            _CommonLogger^.LogSS( log.ldTrace, 0, LOG_SDAP, "UNADVISE", OA( p[1].Length-1, p[1].Data ));
         END;
         
         allFlag := p[1].EqualsOA( L"all" );
         IF Command = sdapADVISE THEN         
            IF allFlag THEN
               _DataSource^.AdviseAll( Client );
               ACK( PConnection, sdap200 );
            ELSIF NOT _DataSource^.NS()^.Contains( nsimpl.AddContext( Client^.Context, p[1] )) THEN
               ACKs( PConnection, sdap405, 1 );
            ELSE
               _DataSource^.Advise( Client, p[1] );
               ACK( PConnection, sdap200 );
            END;

         ELSE // sdapUNADVISE
            IF allFlag THEN
               _DataSource^.UnadviseAll( Client );
               ACK( PConnection, sdap200 );
            ELSIF NOT _DataSource^.NS()^.Contains( nsimpl.AddContext( Client^.Context, p[1] )) THEN
               ACKs( PConnection, sdap405, 1 );
            ELSE
               _DataSource^.Unadvise( Client, p[1] );
               ACK( PConnection, sdap200 );
            END;

         END;

      //-----
      | sdapCONTEXT :
         IF NOT _Clients.Get( PConnection, OUT Client, OUT d ) THEN // unexpected client
            ACK( PConnection, sdap500 );
            RETURN;
         END;

         IF p[1].Empty THEN
            _CommonLogger^.LogSS( log.ldTrace, 0, LOG_SDAP, "CONTEXT", L". (reset)" );
         ELSE
            _CommonLogger^.LogSS( log.ldTrace, 0, LOG_SDAP, "CONTEXT", OA( p[1].Length-1, p[1].Data ));
         END;

         IF p[1].Empty THEN
            Client^.Context.Clear();
            ACK( PConnection, sdap200 );
         ELSIF _DataSource^.NS()^.Contains( nsimpl.AddContext( Client^.Context, p[1] )) THEN
            Client^.Context := p[1];
            ACK( PConnection, sdap200 );
         ELSE
            ACKs( PConnection, sdap405, 1 );
         END;

      //-----
      END; // CASE
  END OnReceive;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ACK( PConnection : netconndispatch.TConnectionHandle; ack : TsdapACK );
   VAR
      s : StringsO.CString;
   BEGIN
      s.FromCARD32( CARDINAL( ack ), 10 );

      _CommonLogger^.LogSS( log.ldTrace, 0, LOG_SDAP, "ACK:", OA( s.Length-1, s.Data ));

      SUPER.Send( NIL, PConnection, 0, s.Data, s.Length<<1 );
   END ACK;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ACKs( PConnection : netconndispatch.TConnectionHandle; ack : TsdapACK; subCode : CARDINAL );
   VAR
      s, n : StringsO.CString;
   BEGIN
      s.FromCARD32( CARDINAL( ack ), 10 );
      s.AppendOA( L"." );
      n.FromCARD32( subCode, 10 );
      s.Append( n );
      
      _CommonLogger^.LogSS( log.ldTrace, 0, LOG_SDAP, "ACK:", OA( s.Length-1, s.Data ));
      
      SUPER.Send( NIL, PConnection, 0, s.Data, s.Length<<1 );
   END ACKs;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ACKS( PConnection : netconndispatch.TConnectionHandle; ack : TsdapACK; CONST S : StringsO.CString );
   VAR
      s : StringsO.CString;
   BEGIN
      s.FromCARD32( CARDINAL( ack ), 10 );
      s.AppendOA( L" " );
      s.Append( S );

      _CommonLogger^.LogSS( log.ldTrace, 0, LOG_SDAP, "ACK:", OA( s.Length-1, s.Data ));
      
      SUPER.Send( NIL, PConnection, 0, s.Data, s.Length<<1 );
   END ACKS;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ACKd( PConnection : netconndispatch.TConnectionHandle; ack : TsdapACK; CONST address : StringsO.CString; CONST value : iovalue.Value );
   VAR
      s : StringsO.CString;
   BEGIN
      s.FromCARD32( CARDINAL( ack ), 10 );
      s.AppendOA( ' 1' );

      _CommonLogger^.LogSS( log.ldTrace, 0, LOG_SDAP, "ACK:", OA( s.Length-1, s.Data ));
      
      SUPER.Send( NIL, PConnection, 0, s.Data, s.Length<<1 );

      s := address; s.AppendOA( L" " ); s.Append( value.String );

      _CommonLogger^.LogSS( log.ldDebug, 0, LOG_SDAP, "DATA:", OA( s.Length-1, s.Data ));
      
      SUPER.Send( NIL, PConnection, 0, s.Data, s.Length<<1 );
   END ACKd;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE SendAdvise( Client : ADDRESS; CONST string : StringsO.IString );
   VAR
      b : BOOLEAN;
      Msg : msghandler.Message;
   BEGIN         
      _SendLock.Lock();
      b := _SendQueue.Empty;
      _SendQueue.Enqueue( string, Client );
      _SendLock.Unlock();

      IF b THEN
         Msg.Message := MSG_ADVISE_SEND;
         b := Message( Msg, msghandler.delDefault, NIL );
         ASSERT( b );
      END;
   END SendAdvise;

(*--------------------------------------------------------------------------------*)

   INITIALLY CSDAPServer();
   BEGIN
      Connection := netconndispatch.ctLine;
      PieceSize := -1;
      _ConfigurationLogger := log.logger();
      _CommonLogger := log.logger();
      _NetworkLogger := log.logger();
   END CSDAPServer;

(*--------------------------------------------------------------------------------*)

   FINALLY CSDAPServer();
   VAR
      Client : TPClient;
      it : maps.CPtrPtrMapIterator;
   BEGIN
      it.Init( _Clients, collection.dirForward );
      WHILE it.MoveNext() DO
         Client := it.Value;
         _DataSource^.UnadviseAll( Client );
         _DataSource^.LeaveClient( Client );
         DISPOSE( Client );
      END; // WHILE
      _Clients.Dispose();

      _SendQueue.Dispose();
   END CSDAPServer;

(*--------------------------------------------------------------------------------*)

END CSDAPServer;

(*================================================================================*)

CLASS IMPLEMENTATION CClient;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnAdvise( CONST Originator : ns.TPOriginator; CONST Result : ARRAY OF Sync.TAsyncResult; CONST Item : ARRAY OF ns.TPNameValuePairs; CONST Value : ARRAY OF iovalue.Value );
   VAR
      count, i : INTEGER;
      n : StringsO.CString;
      s : StringsO.CString;
   BEGIN
      count := HIGH( Item ) + 1;
      s.FromCARD32( count, 10 );
      s.PrependOA( '202 ' ); // sdap_202
      Server^.SendAdvise( ADR( SELF ), s );
   
      FOR i := 0 TO HIGH( Item ) DO
         IF Result[i] IN Sync.arsCompletions THEN
            Server^.DataSource^.NS()^.GetFullName( Item[i], OUT n );
            s := nsimpl.RemoveContext( Context, n );
            s.AppendOA( L" " ); s.Append( Value[i].String );

            IF NOT Server^.CommonLogger^.FilteredFastCheck( log.ldTrace, 0 ) THEN
               Server^.CommonLogger^.LogSS( log.ldTrace, 0, LOG_SDAP, "ADV: ", OA( s.Length-1, s.Data ));
            END;

            Server^.SendAdvise( ADR( SELF ), s );
         END;
      END; // FOR
   END OnAdvise;

(*--------------------------------------------------------------------------------*)

BEGIN
   Connection := NIL;
   Server := NIL;
END CClient;

(*================================================================================*)

END sdap.
