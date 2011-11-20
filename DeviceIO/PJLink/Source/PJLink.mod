IMPLEMENTATION MODULE PJLink;

(*================================================================================*)

FROM Debug IMPORT
   Assertion, LogAssertionW;
   
FROM Exceptions IMPORT
   TestIfCatched, RetrieveException, CModula2Exception;

IMPORT
   iobject,
   log,
   LogConfig,
   resources,
   TextWriter,
   Texts;
   
(*--------------------------------------------------------------------------------*)

VAR
   R : resources.CResources;

(*================================================================================*)

CONST
   LOG_NAME = L"PJLink";
   
CONST
   DEFAULT_PORT = 4352;
   CONNECTION_DISCONNECT_TIMEOUT = 5000; // 5 second
   POLL_TIMEOUT = 20000; // 20 second

(*--------------------------------------------------------------------------------*)

#save, option( pack => 1 )
#restore

(*===========================================================================*)

TYPE
   TCommand = (
      cmdPower
   );

CLASS IMPLEMENTATION CNS;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE HashToName( CONST Hash : ns.THash; OUT Name : StringsO.IString ) : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END HashToName;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE CreateRoot() : ns.TPnsItem;
   BEGIN
      RETURN CreateNewItem( L"PJLink", ns.ntName, iovalue.vtString, 0 );
   END CreateRoot;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE CreateStructure();
   VAR
      item : nsitem.TPnsItem;
   BEGIN
      Root^.AddChild( CreateNewItem( L"Control", ns.ntName, iovalue.vtString, 0 ));

      DataRoot := nsitem.TPnsItem( CreateNewItem( L"Data", ns.ntName, iovalue.vtString, 0 ));
      Root^.AddChild( DataRoot );

		item := CreateNewItem( L"Power", ns.ntValue, iovalue.vtInteger, PTR( cmdPower )); DataRoot^.AddChild( item );
   END CreateStructure;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CreateNewItem( CONST Name : ARRAY OF WCHAR; NType : ns.TNameType; VType : iovalue.TValueType; Data : PTR ) : ns.TPnsItem;
   VAR
      R : nsitem.TPnsItem;
   BEGIN
      NEW( R )^.Init( Name, ConstNames, NType, VType, Data );
      RETURN R;
   END CreateNewItem;

(*---------------------------------------------------------------------------*)

BEGIN
   DataRoot := NIL;
   Initialize();
END CNS;

(*===========================================================================*)

CLASS IMPLEMENTATION CDeviceCommunicator;

(*---------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnConnect( Result : CARDINAL; CONST Socket : netsocket.TPDSocket; Local : BOOLEAN ); 
   VAR
      al : Sync.AutoLock;
   BEGIN
      al.TakeSafe( REF _Lock, L"Unable to lock communicator (request)" );

      IF Result = 0 THEN
         Logger.LogS( log.ldDebug, 0, LOG_NAME, L"Connection connected" );

         StartTimeout( CONNECTION_DISCONNECT_TIMEOUT, TRUE, REF _ConnectionCloseTimeoutHandle );
         _Reader.StartReading();

         FlushQueue();

      ELSE
         Logger.LogSC( log.ldTrace, 0, LOG_NAME, L"Connect failed:", Result );

      END;
   END OnConnect;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnReadable( Length : CARDINAL; Source : ADDRESS );
   VAR
      byteLen : CARDINAL;
      ptext : PWCHAR;
      response : StringsO.CString;
   BEGIN
      WHILE _Reader.Peek( OUT ptext, OUT byteLen ) DO
         IF byteLen >= 2 THEN
            response.FromOA( OA( byteLen DIV 2 - 1, ptext ));
            PIO^.OnResponse( response );
         END;
      END; // WHILE
      
      _Reader.StartReading();
   END OnReadable;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Running GET : BOOLEAN;
   BEGIN
      RETURN _Running;
   END Running;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Start() : Sync.TAsyncResult;
   BEGIN
      IF _Running THEN
         RETURN Sync.arAlreadyCompleted;
      END;
      _Running := TRUE;
      _PoolDelegate.TimeoutSink := ADR( SELF );

      Logger.LogS( log.ldMessage, 0, LOG_NAME, L"Started" );
      RETURN Sync.arCompleted;
   END Start;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Stop();
   VAR
      al : Sync.AutoLock;
   BEGIN
      IF NOT _Running THEN
         RETURN;
      END;
      _Running := FALSE;
      _PoolDelegate.TimeoutSink := NIL;

      al.TakeSafe( REF _Lock, L"Unable to lock communicator (stop)" );
      _Connection.Close();

      Logger.LogS( log.ldMessage, 0, LOG_NAME, L"Stopped" );
   END Stop;

(*---------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnTimeout( Result : Sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR );
   VAR
      al : Sync.AutoLock;
   BEGIN
      IF PoolHandle = _ConnectionCloseTimeoutHandle THEN
         al.TakeSafe( REF _Lock, L"Unable to lock communicator (timeout)" );
         _Connection.Close();

         Logger.LogS( log.ldDebug, 0, LOG_NAME, L"Connection closed" );
      END;
   END OnTimeout;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Configure( CONST iniFile : INIFile.CINIFile; CONST iniFileSection : StringsO.IString; CONST Log : log.TPLogger ) : Sync.TAsyncResult;
   VAR
      Result : Sync.TAsyncResult := Sync.arCompleted;

      (*----------*)

      PROCEDURE LogError( abort : BOOLEAN; line : CARDINAL; errorText : CARDINAL; CONST addonText : StringsO.TPString );
      VAR
         level : log.TLevel := log.lcWarning;
         msg : StringsO.CString;
      BEGIN
         IF abort THEN
            level := log.lcError;
            Result := Sync.arAborted;
         END;

         msg.FromOA( OAsz( R[errorText] ));
         IF addonText <> NIL THEN
            msg.Append( addonText^ );
         END;
         Log^.LogFilePos( level, 0, LOG_NAME, OA( iniFileSection.Length-1, iniFileSection.Data ), OA( msg.Length-1, msg.Data ), line, 0 );
      END LogError;

      (*----------*)

   VAR
      l : CARDINAL;
   BEGIN
      Dispose();

      IF iniFile.SetSection( OA( iniFileSection.Length-1, iniFileSection.Data )) THEN
         // TODO: does ConfigureLog dispose _AppenderList ???
         LogConfig.ConfigureLog( iniFile, OA( iniFileSection.Length-1, iniFileSection.Data ), REF Logger, REF _AppenderList, OUT l );

         // load host to connect to
         IF NOT iniFile.GetKeyStr( keyHost, OUT l, OUT _HostAddress ) THEN
            LogError( TRUE, l, Texts._HostKeyMissing, NIL );
         END;

      ELSE
         LogError( TRUE, 0, Texts._ConfigurationSectionMissing, ADR( iniFileSection ));
      END;
      RETURN Result;
   END Configure;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Dispose();
   BEGIN
      LogConfig.DisposeAppenderList( REF _AppenderList );
   END Dispose;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Request( CONST request : StringsO.IString );
   VAR
      al : Sync.AutoLock;
   BEGIN
      al.TakeSafe( REF _Lock, L"Unable to lock communicator (request)" );

      _Queue.Add( request, 0 );
      IF _Connection.Connected THEN
         FlushQueue();
      ELSE
         _Connection.OpenS( _HostAddress, DEFAULT_PORT, FALSE, 0 );
      END;
   END Request;

(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE FlushQueue(); // in sync environment
   VAR
      request : StringsO.CString;
      d : PTR;
      Writer : TextWriter.CTextWriter;
   BEGIN
      Writer.Stream := _Connection.BufferedStream;

      WHILE _Queue.Dequeue( OUT request, OUT d ) DO
         IF Writer.WriteTimeout( request, FALSE, CONNECTION_DISCONNECT_TIMEOUT DIV 2 ) = Sync.arTimeout THEN
            _Connection.Close();
            _Queue.Enqueue( request, 0 );
            EXIT;
         END;
      END; // WHILE
   END FlushQueue;

(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE StartTimeout( TimeoutMS : CARDINAL; WaitOnce : BOOLEAN; REF Handle : threadpool.TPoolHandle );
   BEGIN
      ASSERTLOG( Handle = NIL );
      threadpool.pool()^.WaitTimeout( ADR( _PoolDelegate ), 0, TimeoutMS, WaitOnce, FALSE, OUT Handle );
   END StartTimeout;

(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE StopTimeout( REF Handle : threadpool.TPoolHandle );
   BEGIN
      IF Handle = NIL THEN
         RETURN;
      END;
      threadpool.pool()^.Abort( REF Handle );
   END StopTimeout;

(*---------------------------------------------------------------------------*)

BEGIN
   _Connection.Notifier := ADR( SELF );
   _Reader.Stream := _Connection.BufferedStream;
   PIO := NIL;
   _ConnectionCloseTimeoutHandle := NIL;
END CDeviceCommunicator;

(*===========================================================================*)

CLASS IMPLEMENTATION CIO;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Dispose();
   BEGIN
   END Dispose;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Running GET : BOOLEAN;
   BEGIN
      RETURN DeviceCommunicator.Running;
   END Running;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Start() : Sync.TAsyncResult;
   BEGIN
      RETURN DeviceCommunicator.Start();
   END Start;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Stop();
   BEGIN
      DeviceCommunicator.Stop();
   END Stop;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY IOCapabilities GET : io.TCapabilities;
   BEGIN
      RETURN io.TCapabilities{};
   END IOCapabilities;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Pending GET : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END Pending;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Advise GET : io.TAdvise;
   BEGIN
      RETURN io.advNone;
   END Advise;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Advise SET( Value : io.TAdvise );
   BEGIN
      ASSERT( FALSE );
   END Advise;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY AdviseListener GET : io.TPIAdviseInfo;
   BEGIN
      RETURN NIL;
   END AdviseListener;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY AdviseListener SET( Value : io.TPIAdviseInfo );
   BEGIN
      ASSERT( FALSE );
   END AdviseListener;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE IOh( CONST Originator : io.TPOriginator; Direction : IOO.TDirection; Item : ns.THash; REF Value : iovalue.Value; Delegate : io.TPDataInfo ) : Sync.TAsyncResult;
   VAR
      al : Sync.AutoLock;
      command : TCommand;
      item : nsitem.TPnsItem;
      Result : Sync.TAsyncResult := Sync.arCompleted;
   BEGIN
      item := nsitem.TPnsItem( Item );
      IF ( item^.NameType <> ns.ntValue ) OR ( item^.ValueType = iovalue.vtString ) THEN
         RETURN Sync.arCannotStart;
      END;

      command := TCommand( LOPTRLONGWORD( item^.Data ));
      CASE command OF
      | cmdPower : // OK
      ELSE
         ASSERTLOG( FALSE, L"Unexpected command in item found" );
         RETURN Sync.arCannotStart;
      END; // CASE

      al.TakeSafe( REF _Lock, L"Unable to lock data area" );

      IF Direction = IOO.dirRead THEN // get data immediatelly

         DeviceCommunicator.Logger.LogSSC( log.ldTrace, 0, LOG_NAME, L"Item read: ", OA( item^.Name^.Length-1, item^.Name^.Data ), CARDINAL( Value.Boolean ));

         Delegate^.OnIO( IOO.dirRead, ADR( SELF ), OA( 0, ADR( Result )), OA( 0, ADR( Item )), OA( -1, NIL ), OA( 0, ADR( Value )));
         
         RETURN Sync.arCompleted;
      ELSE

         DeviceCommunicator.Logger.LogSSS( log.ldTrace, 0, LOG_NAME, L"Item write: ", OA( item^.Name^.Length-1, item^.Name^.Data ), OA( area^.Password.Length-1, area^.Password.Data ));

         DeviceCommunicator.Request( request );

         Delegate^.OnIO( IOO.dirWrite, ADR( SELF ), OA( 0, ADR( Result )), OA( 0, ADR( Item )), OA( -1, NIL ), OA( 0, iovalue.TPValue( NIL )));

         RETURN Sync.arCompleted;
      END;
   END IOh;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE AbortAll();
   BEGIN
   END AbortAll;

(*---------------------------------------------------------------------------*)

	LOCAL PROCEDURE OnResponse( response : StringsO.CString );
   BEGIN
   END OnResponse;

(*---------------------------------------------------------------------------*)

BEGIN
   DeviceCommunicator.PIO := ADR( SELF );
   DataRoot := NIL;
FINALLY
   Dispose();
END CIO;

(*===========================================================================*)

CLASS IMPLEMENTATION CPJLinkDevice;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY Type GET : iobject.TObjectType;
   BEGIN
      RETURN iobject.otEphemeral;
   END Type;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY Library GET : iobject.TPLibrary;
   BEGIN
      RETURN SUPER.Library;
   END Library;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY Library SET( Value : iobject.TPLibrary );
   BEGIN
      SUPER.Library := Value;
   END Library;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnDispose();
   BEGIN
      // _NS.Dispose();
      _IO.Dispose();
   END OnDispose;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY DeviceCapabilities GET : device.TCapabilities;
   BEGIN
      RETURN device.TCapabilities{device.capNamespace};
   END DeviceCapabilities;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Mapper() : ns.TPMapper;
   BEGIN
      RETURN ADR( _NS );
   END Mapper;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE NS() : ns.TPns;
   BEGIN
      RETURN ADR( _NS );
   END NS;
   
(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE IO() : io.TPIO;
   BEGIN
      RETURN ADR( _IO );
   END IO;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Configure( CONST Source : ARRAY OF device.TConfigureItem; CONST Log : log.TPLogger ) : Sync.TAsyncResult;
   BEGIN
      IF HIGH( Source ) < 0 THEN
         RETURN Sync.arCannotStart;
      ELSIF Source[0].Type <> device.citINIFileSection THEN
         RETURN Sync.arCannotStart;
      ELSE
         RETURN _IO.DeviceCommunicator.Configure( Source[0]._iniFile^, Source[0].section^, Log );
      END;
   END Configure;
   
(*---------------------------------------------------------------------------*)

BEGIN FINALLY
   _IO.Stop();
   OnDispose();
END CPJLinkDevice;

(*===========================================================================*)

BEGIN
   R.LoadRES2( EMIT( %dll ), L"PJLink.Texts" );
END PJLink.
