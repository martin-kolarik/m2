IMPLEMENTATION MODULE PJLink;

(*================================================================================*)

FROM Debug IMPORT
   AssertionW;
   
FROM Exceptions IMPORT
   TestIfCatched, RetrieveException, CModula2Exception;

IMPORT
   digest,
   log,
   LogConfig,
   md5,
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
      cmdUnknown,
      cmdPower,
      cmdPowerQuery,
      cmdPowerStatus
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
      item : ns.TPnsItem;
   BEGIN
      Root^.AddChild( CreateNewItem( L"Control", ns.ntName, iovalue.vtString, 0 ));

      DataRoot := nsitem.TPnsItem( CreateNewItem( L"Data", ns.ntName, iovalue.vtString, 0 ));
      Root^.AddChild( DataRoot );

      item := CreateNewItem( L"Power", ns.ntValue, iovalue.vtBoolean, PTR( cmdPower )); DataRoot^.AddChild( item );
      item := CreateNewItem( L"Power status", ns.ntValue, iovalue.vtInteger, PTR( cmdPowerStatus )); DataRoot^.AddChild( item );
   END CreateStructure;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CreateNewItem( CONST Name : ARRAY OF WCHAR; NType : ns.TNameType; VType : iovalue.TValueType; Data : PTR ) : ns.TPnsItem;
   VAR
      R : nsitem.TPnsItem;
   BEGIN
      NEW( R );
      R^.Init( Name, ConstNames, NType, VType, Data );
      R^.Value^.Undefined := TRUE;
      RETURN R;
   END CreateNewItem;

(*---------------------------------------------------------------------------*)

BEGIN
   DataRoot := NIL;
   Initialize();
END CNS;

(*===========================================================================*)

   PROCEDURE AssemblyCommand( command : TCommand; CONST value : iovalue.Value; OUT request : StringsO.CString ) : BOOLEAN;
   BEGIN
      // check
      CASE command OF
      | cmdPower, cmdPowerQuery :
         // fall down
      ELSE
         RETURN FALSE;
      END;

      request.Size := 16; // reserve space
      request[0] := L"%";
      request[1] := L"1";
      request[6] := L" ";
      request[8] := 13W; // CR

      CASE command OF
      | cmdPower, cmdPowerQuery :
         request[2] := L"P";
         request[3] := L"O";
         request[4] := L"W";
         request[5] := L"R";
         IF command = cmdPowerQuery THEN
            request[7] := L"?";
         ELSIF value.Boolean THEN
            request[7] := L"1";
         ELSE
            request[7] := L"0";
         END;
         request.Length := 9;
      //----
      END; // CASE

      RETURN TRUE;
   END AssemblyCommand;

(*---------------------------------------------------------------------------*)

   PROCEDURE DisassemblyCommand( CONST response : StringsO.CString; OUT command1, command2 : TCommand; REF value1, value2 : iovalue.Value ) : BOOLEAN;
   VAR
      sCommand : StringsO.CString;
   BEGIN
      // check basic properties
      IF ( response.Length < 8 ) OR ( response[0] <> L"%" ) OR ( response[1] <> L"1" ) THEN
         RETURN FALSE;
      END;

      // determine command
      response.Substring( 2, 4, OUT sCommand );
      sCommand.Capitalize();
      IF sCommand.EqualsOA( L"POWR" ) THEN
         command1 := cmdPowerStatus;
         command2 := cmdPower;
      ELSE
         RETURN FALSE;
      END;

      CASE response[7] OF
      | L"0" : value1.Integer := 0;
      | L"1" : value1.Integer := 1;
      | L"2" : value1.Integer := 2;
      | L"3" : value1.Integer := 3;
      ELSE
         RETURN FALSE; // it covers ERRx and OK
      END;
      // fallen down
      value2.Boolean := value1.Integer = 1;
      RETURN TRUE;
   END DisassemblyCommand;

(*---------------------------------------------------------------------------*)

   PROCEDURE DisassemblyConnectResponse( CONST response : StringsO.IString; OUT authError, authRequired : BOOLEAN; OUT authKey : StringsO.IString ) : BOOLEAN;
   VAR
      sCommand : StringsO.CString;
   BEGIN
      // check basic properties
      IF response.Length < 8 THEN
         RETURN FALSE;
      END;

      // determine command
      response.Substring( 0, 6, OUT sCommand );
      sCommand.Capitalize();
      IF NOT sCommand.EqualsOA( L"PJLINK" ) THEN
         RETURN FALSE;
      ELSIF response[7] = L"E" THEN // error
         authError := TRUE;
         RETURN TRUE;
      END;

      authError := FALSE;
      authRequired := response[7] = L"1";
      response.Substring( 9, -1, OUT authKey );

      RETURN TRUE;
   END DisassemblyConnectResponse;

(*===========================================================================*)

CLASS IMPLEMENTATION CDeviceCommunicator;

(*---------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnConnect( Result : CARDINAL; CONST Socket : netsocket.TPDSocket; Local : BOOLEAN ); 
   VAR
      al : Sync.AutoLock;
      d : PTR;
      request : StringsO.CString;
   BEGIN
      al.TakeSafe( REF _Lock, L"Unable to lock communicator (request)" );

      IF Result = 0 THEN
         Logger.LogS( log.ldDebug, 0, LOG_NAME, L"Connection connected" );

         StartTimeout( CONNECTION_DISCONNECT_TIMEOUT, TRUE, REF _ConnectionCloseTimeoutHandle );
         _Reader.StartReading();
         _State := csWaitAuthorization;

      ELSE
         Logger.LogSC( log.ldTrace, 0, LOG_NAME, L"Connect failed:", Result );

         _State := csDisconnected;

         // empty queue
         WHILE _Queue.Dequeue( OUT request, OUT d ) DO
            Logger.LogSS( log.ldDebug, 0, LOG_NAME, L"Dropped request:", OA( request.Length-1, request.Data ));
         END; // WHILE

      END;
   END OnConnect;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnReadable( Length : CARDINAL; Source : ADDRESS );
   VAR
      authError : BOOLEAN;
      byteLen : CARDINAL;
      ptext : PWCHAR;
      response : StringsO.CString;
   BEGIN
      WHILE _Reader.Peek( OUT ptext, OUT byteLen ) DO
         IF byteLen >= 4 THEN
            response.FromOA( OA( byteLen DIV 2 - 2, ptext )); // -1 CR, -1 Len to HIGH

            IF DisassemblyConnectResponse( response, OUT authError, OUT _AuthRequested, OUT _AuthKey ) THEN
               IF authError THEN
                  Logger.LogSS( log.ldDebug, 0, LOG_NAME, L"Auth error:", OA( response.Length-1, response.Data ));
               ELSE
                  Logger.LogSS( log.ldDebug, 0, LOG_NAME, L"Connect response:", OA( response.Length-1, response.Data ));

                  _Lock.Lock(); // TODO safety
                  _State := csConnected;
                  FlushQueue();
                  _Lock.Unlock();
               END;

            ELSIF _State = csConnected THEN
               PIO^.OnResponse( response );

            ELSE
               Logger.LogSS( log.ldTrace, 0, LOG_NAME, L"Connect response improper:", OA( response.Length-1, response.Data ));

               _Lock.Lock(); // TODO safety
               StopTimeout( REF _ConnectionCloseTimeoutHandle );
               _State := csDisconnected;
               _Connection.Close();
               _Lock.Unlock();
            END;

         END; // IF

         _Reader.ReadOut( byteLen ); // read out and signal next reading
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

      StopTimeout( REF _ConnectionCloseTimeoutHandle );
      _State := csDisconnected;
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

         _ConnectionCloseTimeoutHandle := NIL; // can be StopTimeout, but calling Abort is not necessary here
         _State := csDisconnected;
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

   CONST
      keyHost = L"host";
      keyPassword = L"password";
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

         iniFile.GetKeyStr( keyPassword, OUT l, OUT _Password );

      ELSE
         LogError( TRUE, 0, Texts._ConfigurationSectionMissing, ADR( iniFileSection ));
      END;
      RETURN Result;
   END Configure;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   BEGIN
      _Password.Clear();
      _State := csDisconnected;
      _AuthRequested := FALSE;

      LogConfig.DisposeAppenderList( REF _AppenderList );
   END Dispose;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Request( CONST request : StringsO.IString );
   VAR
      al : Sync.AutoLock;
   BEGIN
      al.TakeSafe( REF _Lock, L"Unable to lock communicator (request)" );

      _Queue.Enqueue( request, 0 );
      IF _State = csConnecting THEN
         // do nothing, wait connected
      ELSIF _State = csConnected THEN
         FlushQueue();
      ELSIF _State = csDisconnected THEN
         _State := csConnecting;

         Logger.LogSS( log.ldDebug, 0, LOG_NAME, L"Connecting to:", OA( _HostAddress.Length-1, _HostAddress.Data ));
         _Connection.OpenS( _HostAddress, DEFAULT_PORT, FALSE, 0 );
      END;
   END Request;

(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE FlushQueue(); // in sync environment
   VAR
      bHash : StorageO.CMemoryBuffer;
      d : PTR;
      dg : md5.CDigest;
      filled : CARDINAL;
      request : StringsO.CString;
      sHash : StringsO.CString;
      Writer : TextWriter.CTextWriter;
   BEGIN
      Writer.Stream := _Connection.BufferedStream;

      WHILE _Queue.Dequeue( OUT request, OUT d ) DO

         IF _AuthRequested THEN
            _AuthRequested := FALSE; // do not append key more times

            sHash := _AuthKey + _Password;
            bHash.Size := sHash.Length * 2;
            sHash.ToUTF8( OUT OA( bHash.Size-1, PCHAR( bHash.Data )), OUT filled );
            ASSERT( filled = sHash.Length );
            bHash.Length := filled;
            digest.Digest( digest.md5, OA( filled-1, bHash.Data ), OUT dg );

            sHash.Size := 32; // md5 hash is 16 bytes long
            sHash.Length := 32;
            dg.ToHex( OUT OA( sHash.Size-1, PWCHAR( sHash.Data )));

            request.Prepend( sHash );

            Logger.LogSS( log.ldDebug, 0, LOG_NAME, L"Password:", OA( _Password.Length-1, _Password.Data ));
            Logger.LogSS( log.ldDebug, 0, LOG_NAME, L"Request with auth info:", OA( request.Length-1, request.Data ));
         END;
         
         IF Writer.WriteTimeout( request, FALSE, CONNECTION_DISCONNECT_TIMEOUT DIV 2 ) = Sync.arTimeout THEN
            // disconnect
            StopTimeout( REF _ConnectionCloseTimeoutHandle );
            _State := csDisconnected;
            _Connection.Close();
            // requeue the request
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
   _Reader.LineEndStyle := TextReader.lesMAC;
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
      _PoolDelegate.TimeoutSink := ADR( SELF );
      threadpool.pool()^.WaitTimeout( ADR( _PoolDelegate ), 0, POLL_TIMEOUT, FALSE, FALSE, OUT _PeriodHandle );
      RETURN DeviceCommunicator.Start();
   END Start;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Stop();
   BEGIN
      IF _PeriodHandle <> NIL THEN
         _PoolDelegate.TimeoutSink := NIL;
         threadpool.pool()^.Abort( REF _PeriodHandle );
      END;
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
      i : CARDINAL;
      item : nsitem.TPnsItem := NIL;
      Result : Sync.TAsyncResult := Sync.arCompleted;
      s : StringsO.CString;
   BEGIN
      item := nsitem.TPnsItem( Item );
      IF ( item^.NameType <> ns.ntValue ) OR ( item^.ValueType = iovalue.vtString ) THEN
         RETURN Sync.arCannotStart;
      END;

      command := TCommand( LOPTRLONGWORD( item^.Data ));
      FOR i := 0 TO DataRoot^.Count-1 DO
         IF DataRoot^[i]^.Data = PTR( command ) THEN
            item := nsitem.TPnsItem( DataRoot^[i] );
            EXIT;
         END;
      END;
      IF item = NIL THEN
         ASSERTLOG( FALSE, L"Unexpected command in item found" );
         RETURN Sync.arCannotStart;
      END; // CASE

      al.TakeSafe( REF _Lock, L"Unable to lock data area" );

      IF Direction = IOO.dirRead THEN // get data immediatelly
         IF item^.Value^.Undefined THEN
            Result := Sync.arNoData;
         ELSE
            Value := item^.Value^;
            DeviceCommunicator.Logger.LogSSC( log.ldTrace, 0, LOG_NAME, L"Item read:", OA( item^.Name^.Length-1, item^.Name^.Data ), Value.Integer );
         END;

         Delegate^.OnIO( IOO.dirRead, ADR( SELF ), OA( 0, ADR( Result )), OA( 0, ADR( Item )), OA( -1, NIL ), OA( 0, ADR( Value )));
         RETURN Result;

      ELSE
         IF NOT DeviceCommunicator.Logger.FilteredFastCheck( log.ldTrace, 0 ) THEN
            s := Value.String;
            DeviceCommunicator.Logger.LogSSS( log.ldTrace, 0, LOG_NAME, L"Item write:", OA( item^.Name^.Length-1, item^.Name^.Data ), OA( s.Length-1, s.Data ));
         END;

         IF AssemblyCommand( command, Value, OUT s ) THEN
            DeviceCommunicator.Logger.LogSS( log.ldDebug, 0, LOG_NAME, L"Request to send:", OA( s.Length-1, s.Data ));

            DeviceCommunicator.Request( s );
            Delegate^.OnIO( IOO.dirWrite, ADR( SELF ), OA( 0, ADR( Result )), OA( 0, ADR( Item )), OA( -1, NIL ), OA( 0, iovalue.TPValue( NIL )));
            RETURN Sync.arCompleted;
         ELSE
            DeviceCommunicator.Logger.LogSS( log.ldDebug, 0, LOG_NAME, L"Item write, cannot assembly packet:", OA( item^.Name^.Length-1, item^.Name^.Data ));
            RETURN Sync.arCannotStart;
         END;
      END;
   END IOh;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE AbortAll();
   BEGIN
   END AbortAll;

(*---------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnTimeout( Result : Sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR );
   VAR
      value : iovalue.Value;
      s : StringsO.CString;
   BEGIN
      IF AssemblyCommand( cmdPowerQuery, value, OUT s ) THEN
         DeviceCommunicator.Logger.LogSS( log.ldDebug, 0, LOG_NAME, L"Request to send:", OA( s.Length-1, s.Data ));
         DeviceCommunicator.Request( s );
      ELSE
         DeviceCommunicator.Logger.LogS( log.ldTrace, 0, LOG_NAME, L"Cannot assembly cmdPowerQuery packet" );
      END;
   END OnTimeout;

(*---------------------------------------------------------------------------*)

   LOCAL PROCEDURE OnResponse( response : StringsO.CString );
   VAR
      al : Sync.AutoLock;
      command1, command2 : TCommand;
      i : CARDINAL;
      item1, item2 : nsitem.TPnsItem := NIL;
      s : StringsO.CString;
      value1, value2 : iovalue.Value;
   BEGIN
      DeviceCommunicator.Logger.LogSS( log.ldDebug, 0, LOG_NAME, L"Response received:", OA( response.Length-1, response.Data ));

      IF DisassemblyCommand( response, OUT command1, OUT command2, REF value1, REF value2 ) THEN
         FOR i := 0 TO DataRoot^.Count-1 DO
            IF DataRoot^[i]^.Data = PTR( command1 ) THEN
               item1 := nsitem.TPnsItem( DataRoot^[i] );
               EXIT;
            END;
         END;
         FOR i := 0 TO DataRoot^.Count-1 DO
            IF DataRoot^[i]^.Data = PTR( command2 ) THEN
               item2 := nsitem.TPnsItem( DataRoot^[i] );
               EXIT;
            END;
         END;
         IF ( item1 = NIL ) AND ( item2 = NIL ) THEN
            RETURN;
         END;
      
         IF item1 <> NIL THEN
            IF NOT DeviceCommunicator.Logger.FilteredFastCheck( log.ldDebug, 0 ) THEN
               s := value1.String;
               DeviceCommunicator.Logger.LogSSS( log.ldTrace, 0, LOG_NAME, L"Item value accepted:", OA( item1^.Name^.Length-1, item1^.Name^.Data ), OA( s.Length-1, s.Data ));
            END;

            al.TakeSafe( REF _Lock, L"Unable to lock data area" );
            item1^.Value^.Undefined := FALSE;
            item1^.Value^ := value1;
         END; // IF item1

         IF item2 <> NIL THEN
            IF NOT DeviceCommunicator.Logger.FilteredFastCheck( log.ldDebug, 0 ) THEN
               s := value2.String;
               DeviceCommunicator.Logger.LogSSS( log.ldTrace, 0, LOG_NAME, L"Item value accepted:", OA( item2^.Name^.Length-1, item2^.Name^.Data ), OA( s.Length-1, s.Data ));
            END;

            al.TakeSafe( REF _Lock, L"Unable to lock data area" );
            item2^.Value^.Undefined := FALSE;
            item2^.Value^ := value2;
         END; // IF item1

      END;
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

   PUBLIC VIRTUAL PROCEDURE Dispose();
   BEGIN
      // _NS.Dispose();
      _IO.Dispose();
   END Dispose;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY Type GET : iplugin.TObjectType;
   BEGIN
      RETURN iplugin.otEphemeral;
   END Type;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY OfPlugin GET : iplugin.TPPlugin;
   BEGIN
      RETURN SUPER.OfPlugin;
   END OfPlugin;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY OwnerHandle GET : PTR;
   BEGIN
      RETURN SUPER.OwnerHandle;
   END OwnerHandle;

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
   VAR
      Result : Sync.TAsyncResult;
   BEGIN
      IF HIGH( Source ) < 0 THEN
         RETURN Sync.arCannotStart;
      ELSIF Source[0].Type <> device.citINIFileSection THEN
         RETURN Sync.arCannotStart;
      END;

      Result := _IO.DeviceCommunicator.Configure( Source[0]._iniFile^, Source[0].section^, Log );
      IF Result = Sync.arCompleted THEN // copy data from NS to IO
         _NS.Initialize();
         _IO.DataRoot := _NS.DataRoot;
      END;

      RETURN Result;
   END Configure;
   
(*---------------------------------------------------------------------------*)

BEGIN FINALLY
   _IO.Stop();
   Dispose();
END CPJLinkDevice;

(*===========================================================================*)

BEGIN
   R.LoadRES2( EMIT( %dll ), L"PJLink.Texts" );
END PJLink.
