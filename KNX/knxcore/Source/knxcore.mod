IMPLEMENTATION MODULE knxcore;

FROM Exceptions IMPORT
   TestIfCatched, RetrieveException;

(*# call( o_a_copy => off ) *)

//================================================================================

FROM Debug IMPORT
   AssertionW;

IMPORT
   DateTime,
   FIO,
   FIOO,
   IOO,
   Log,
   namevaluepairsimpl,
   Storage,
   Strings,
   StringsO,
   Sync;

IMPORT
   INIFile,
   inetaddr,
   netsocket,
   netsrv,
   TextReader;

IMPORT
   knxstack_knxnet;

IMPORT
   Texts;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

FROM Strings IMPORT
   LowerizeW;

//================================================================================

CONST // behaviour names
   bnReader                         = L'reader';
   bnTracker                        = L'tracker';
   bnTracker2                       = L'tracker_init';
   bnTransmitter                    = L'transmitter';
   bnTransmitterWithStatus          = L'transmitter_with_status';
   bnTransmitterWithStatus2         = L'transmitter_with_status_init';
   bnTransmitterWithStatusCallback  = L'transmitter_with_status_and_callback';
   bnTransmitterWithStatusCallback2 = L'transmitter_with_status_and_callback_init';
   bnServer                         = L'server';
   bnConcentrator                   = L'concentrator';
   bnSource                         = L'source';
   
CONST // object type names
   otnObject                = L"object";
   otnObjects               = L"objects";
   otnLoggedObject          = L"logged_object";
   otnLoggedObjects         = L"logged_objects";
   otnLoggedOnChangeObject  = L"logged_on_change_object";
   otnLoggedOnChangeObjects = L"logged_on_change_objects";
   otnESFStrict             = L"esf_strict";
   otnESFAdapt              = L"esf_adapt";
   otnESFIgnore             = L"esf_ignore";
   otnLoggedESFStrict       = L"logged_esf_strict";
   otnLoggedESFAdapt        = L"logged_esf_adapt";
   otnLoggedESFIgnore       = L"logged_esf_ignore";
   
CONST
   itemConnected = 1;
   nameNamespace = L"KNX";
   nameConnected = L"Connected";
   namePathConnected = L"Control." + nameConnected;

//================================================================================

CONST
   tiInitReadDelay = 67;
   tiDateAndTime = 68;
   tiForceRead = 69;
   
//-----

TYPE
   TPBehaviour = POINTER TO CBehaviour;

CLASS CBehaviour( list.CListElem );
   Class : knx_def.TPriority;
   Flags : knx_def.TA_ObjectFlags;
   Name  : StringsO.CString;
END CBehaviour;

//-----

TYPE
   TStatusChannelItem = (
      schiUSBConnected,
      schiKNXConnected,
      schiInitReadPending,
      schiInputQueueOverflow,
      schiHavePromiscuousData
   );
   TStatusChannel = SET OF TStatusChannelItem;

//================================================================================
// helpers

PROCEDURE Group2LogNumber( LongForm : BOOLEAN; M, S, G : CARDINAL ) : CARDINAL;
BEGIN
   IF LongForm THEN
      RETURN 10000000 +
              1000000 * ( M DIV 10 ) +
               100000 * ( M MOD 10 ) +
                        G;
   ELSE
      RETURN  1000000 * ( M DIV 10 ) +
               100000 * ( M MOD 10 ) +
                 1000 * S +
                        G;
   END;
END Group2LogNumber;

//--------------------------------------------------------------------------------

PROCEDURE LogNumber2Group( LogNumber : CARDINAL; VAR LongForm : BOOLEAN; VAR M, S, G : CARDINAL );
BEGIN
   IF LogNumber > 10000000 - 1 THEN
      LongForm := TRUE;
      LogNumber :=  LogNumber - 10000000;
   ELSE
      LongForm := FALSE;
   END;
   G := LogNumber MOD 1000;
   LogNumber := LogNumber DIV 1000;
   S := LogNumber MOD 100;
   M := LogNumber DIV 100;
   IF LongForm THEN
      G := 1000 * S + G;
      S := 0;
   END;
END LogNumber2Group;

//--------------------------------------------------------------------------------

PROCEDURE LogNumber2Address( LogNumber : CARDINAL; VAR Address : knx_def.CAddress );
VAR
   G, M, S : CARDINAL;
   LongForm : BOOLEAN;
BEGIN
   LogNumber2Group( LogNumber, LongForm, M, S, G );
   IF LongForm THEN
      Address.SetGroupAddress4( M, G );
   ELSE
      Address.SetGroupAddress2( M, S, G );
   END;
END LogNumber2Address;

//================================================================================

CLASS IMPLEMENTATION CBehaviour;
BEGIN
   Flags := knx_def.TA_ObjectFlags{};
   Class := knx_def.priorityNormal;
END CBehaviour;

//================================================================================

CLASS IMPLEMENTATION CObject;

//--------------------------------------------------------------------------------

   PUBLIC PROPERTY ObjectType GET : TObjectType;
   BEGIN
      RETURN _ObjectType;
   END ObjectType;

//--------------------------------------------------------------------------------

   PUBLIC PROPERTY ObjectType SET( Value : TObjectType );
   BEGIN
      _ObjectType := Value;
   END ObjectType;

//--------------------------------------------------------------------------------

   PUBLIC PROPERTY ChangedOnWrite GET : TRISTATE;
   BEGIN
      RETURN _ChangedOnWrite;
   END ChangedOnWrite;

//--------------------------------------------------------------------------------

   PUBLIC PROPERTY ChangedOnWrite SET( Value : TRISTATE );
   BEGIN
      _ChangedOnWrite := Value;
   END ChangedOnWrite;

//--------------------------------------------------------------------------------

   PUBLIC PROPERTY Pairs GET : ns.TPNameValuePairs;
   BEGIN
      RETURN _Pairs;
   END Pairs;

//--------------------------------------------------------------------------------

   PUBLIC PROPERTY Pairs SET( Value : ns.TPNameValuePairs );
   BEGIN
      _Pairs := Value;
   END Pairs;

//--------------------------------------------------------------------------------

   INTERNAL VIRTUAL PROCEDURE ValueReadRequestSent( Status : knx_status.TKNXStackStatus; CurrentState : knx_user.TObjectState );
   BEGIN
      RSStatus := Status;
      Server^.ValueReadRequestSent( ADR( SELF ), CurrentState );
   END ValueReadRequestSent;

//--------------------------------------------------------------------------------

   INTERNAL VIRTUAL PROCEDURE ValueRead( Status : knx_status.TKNXStackStatus; CurrentState : knx_user.TObjectState; CurrentInitReadState : knx_user.TInitReadState );
   BEGIN
      RSStatus := Status;
      Server^.ValueRead( ADR( SELF ), CurrentState, CurrentInitReadState );
   END ValueRead;

//--------------------------------------------------------------------------------

   INTERNAL VIRTUAL PROCEDURE ValueUpdated( Status : knx_status.TKNXStackStatus; CurrentState : knx_user.TObjectState );
   VAR
      EISString : knx_def.TEISStringW;
      value : knx_def.TValue;
   BEGIN
      RSStatus := Status;
      IF ( RSStatus = knx_status.essOK ) AND ( Type = knx_def.eitString ) THEN
         GetValue( OUT value, TRUE, FALSE );
         value.GetString( EISString );
         StringValue.FromOA( EISString );
      END;
      Server^.ValueUpdated( IOO.dirRead, ADR( SELF ), CurrentState );
   END ValueUpdated;

//--------------------------------------------------------------------------------

   INTERNAL VIRTUAL PROCEDURE ValueWritten( Status : knx_status.TKNXStackStatus; CurrentState : knx_user.TObjectState );
   BEGIN
      WSStatus := Status;
      Server^.ValueWritten( ADR( SELF ), CurrentState );
      IF ( Status = knx_status.essOK ) AND ( knx_def.TA_ObjectFlags{knx_def.aofForceRead, knx_def.aofWritable} * GetFlags() = knx_def.TA_ObjectFlags{knx_def.aofWritable} ) THEN
         // element always read from KNX cannot be reset for reading;
         // only writable elements can be reset for reading too
         RSStatus := knx_status.essOK;
      END;
   END ValueWritten;

//--------------------------------------------------------------------------------

   INTERNAL VIRTUAL PROCEDURE Lock();
   BEGIN
      Server^.LockObjects();
   END Lock;

//--------------------------------------------------------------------------------

   INTERNAL VIRTUAL PROCEDURE Unlock();
   BEGIN
      Server^.UnlockObjects();
   END Unlock;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE LogNumber() : CARDINAL;
   VAR
      G, M, S : CARDINAL;
      sa : knx_def.CAddress;
   BEGIN
      sa := SendAddress;
      IF sa.GetAddressType() = knx_def.addressUnknown THEN
         RETURN -1;
      ELSIF sa.GetAddressType() = knx_def.addressGroup2 THEN
         sa.GetGroupAddress4( M, G );
         RETURN Group2LogNumber( TRUE, M, 0, G );
      ELSE
         sa.GetGroupAddress2( M, S, G );
         RETURN Group2LogNumber( FALSE, M, S, G );
      END;
   END LogNumber;

//--------------------------------------------------------------------------------

BEGIN
   Server := NIL;
   _ObjectType := TObjectType{};
   _ChangedOnWrite := -1;
   _Pairs := NIL;
   RSStatus := knx_status.essOK;
   WSStatus := knx_status.essOK;
   ReadRepeatCount := 1;
   RecoveryExpiration := 0;
END CObject;

//================================================================================

CLASS IMPLEMENTATION PromiscuousData;
BEGIN
   Status := knx_status.essOK;
END PromiscuousData;

//================================================================================

CLASS IMPLEMENTATION CStackSink;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE OnDeviceConnected();
   BEGIN
      Server^.OnDeviceConnect();
   END OnDeviceConnected;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE OnDeviceDisconnected();
   BEGIN
      Server^.OnDeviceDisconnect();
   END OnDeviceDisconnected;

//--------------------------------------------------------------------------------

BEGIN
   Server := NIL;
END CStackSink;

//================================================================================

CLASS IMPLEMENTATION KNXServerEvent;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE OnConnect();
   BEGIN
      Reset();
      WHILE MoveNext() DO
         TPKNXServerSink( Listener )^.OnConnect();
      END; // WHILE
   END OnConnect;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE OnDisconnect();
   BEGIN
      Reset();
      WHILE MoveNext() DO
         TPKNXServerSink( Listener )^.OnDisconnect();
      END; // WHILE
   END OnDisconnect;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE OnInitReadCompleted();
   BEGIN
      Reset();
      WHILE MoveNext() DO
         TPKNXServerSink( Listener )^.OnInitReadCompleted();
      END; // WHILE
   END OnInitReadCompleted;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE OnRead( PObject : TPObject );
   BEGIN
      Reset();
      WHILE MoveNext() DO
         TPKNXServerSink( Listener )^.OnRead( PObject );
      END; // WHILE
   END OnRead;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE OnWritten( PObject : TPObject );
   BEGIN
      Reset();
      WHILE MoveNext() DO
         TPKNXServerSink( Listener )^.OnWritten( PObject );
      END; // WHILE
   END OnWritten;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE OnInputQueueAdd( OOBQueue, PromiscuousQueue : BOOLEAN );
   BEGIN
      Reset();
      WHILE MoveNext() DO
         TPKNXServerSink( Listener )^.OnInputQueueAdd( OOBQueue, PromiscuousQueue );
      END; // WHILE
   END OnInputQueueAdd;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE OnInputQueueOverflow( OOBQueue, PromiscuousQueue : BOOLEAN );
   BEGIN
      Reset();
      WHILE MoveNext() DO
         TPKNXServerSink( Listener )^.OnInputQueueOverflow( OOBQueue, PromiscuousQueue );
      END; // WHILE
   END OnInputQueueOverflow;

//--------------------------------------------------------------------------------

END KNXServerEvent;

//================================================================================

CLASS IMPLEMENTATION CKNXServer;

//--------------------------------------------------------------------------------

   PUBLIC PROPERTY Result SET( Value : lec.TPResult );
   BEGIN
      _Result := Value;
   END Result;
//--------------------------------------------------------------------------------

   PUBLIC PROPERTY EXEFlag GET : BOOLEAN;
   BEGIN
      RETURN rsEXEFlag IN RStatus;
   END EXEFlag;

//--------------------------------------------------------------------------------

   PUBLIC PROPERTY EXEFlag SET( Value : BOOLEAN );
   BEGIN
      IF Value THEN
         INCL( RStatus, rsEXEFlag );
      ELSE
         EXCL( RStatus, rsEXEFlag );
      END;
   END EXEFlag;

//--------------------------------------------------------------------------------

   PUBLIC PROPERTY DataLogger GET : log.TPLogger;
   BEGIN
      RETURN _DataLogger;
   END DataLogger;

//--------------------------------------------------------------------------------

   PUBLIC PROPERTY DataLogger SET( Value : log.TPLogger );
   BEGIN
      _DataLogger := Value;
   END DataLogger;

//--------------------------------------------------------------------------------

   INTERNAL VIRTUAL PROCEDURE OnTimer( TimerId : PTR );
   BEGIN
      IF TimerId = tiInitReadDelay THEN
         DoInitRead( TRUE );
      ELSIF TimerId = tiDateAndTime THEN
         DoPushDateAndTime();
      ELSIF TimerId = tiForceRead THEN
         DoForceRead();
      END;
   END OnTimer;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROPERTY DataSourceCapabilities GET : device.TCapabilities;
   BEGIN
      RETURN device.TCapabilities{device.capAdviseSource};
   END DataSourceCapabilities;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE Configure( CONST Source : ARRAY OF device.TConfigureItem; CONST Log : log.TPLogger ) : Sync.TAsyncResult;
   VAR
      line : CARDINAL;
      message : StringsO.CString;
   BEGIN
      IF ( HIGH( Source ) = -1 ) OR ( Source[0].Type <> device.citIString ) THEN
         RETURN Sync.arCannotStart;
      END;
      IF LoadConfiguration( Source[0].iString^, OUT message, OUT line ) THEN
         Log^.LogSS( log.ldMessage, 0, L"", OAsz( R[ Texts._ConfigurationLoadSuccessfully ] ), OA( Source[0].iString^.Length-1, Source[0].iString^.Data ));
         RETURN Sync.arCompleted;
      ELSE
         Log^.LogFilePos( log.lcError, 0, L"", OA( Source[0].iString^.Length-1, Source[0].iString^.Data ), OA( message.Length-1, message.Data ), line, 0 );
         Log^.LogSS( log.lcInfo, 0, L"", OAsz( R[ Texts._ConfigurationLoadUnsuccessfully ] ), OA( Source[0].iString^.Length-1, Source[0].iString^.Data ));
         RETURN Sync.arCannotStart;
      END;
   END Configure;
   
//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE NS() : ns.TPNamespace;
   BEGIN
      RETURN ADR( Namespace );
   END NS;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE AdviseSource() : ns.TPAdviseSource;
   BEGIN
      RETURN ADR( _AdviseSource );
   END AdviseSource;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE StartStop() : io.TPStartStopControl;
   BEGIN
      RETURN ADR( SELF );
   END StartStop;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE IO() : io.TPIO;
   BEGIN
      RETURN ADR( SELF );
   END IO;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROPERTY Description GET : StringsO.CString;
   BEGIN
      RETURN StringsO.FromOA( nameNamespace );
   END Description;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE ValueIO( CONST Originator : ns.TPOriginator; CONST NameValuePairs : ns.TPNameValuePairs; Direction : IOO.TDirection; REF Value : iovalue.Value ) : Sync.TAsyncResult;
   VAR
      address : ARRAY [0..63] OF WCHAR;
      description : StringsO.CString;
      EV : knx_def.CValue;
      changed : BOOLEAN;
      connected : BOOLEAN;
      PObject : TPObject;
   BEGIN
      IF _Result^.Counted OR _Result^.Expired THEN
         RETURN Sync.arCannotStart;
      END;
      
      IF NameValuePairs^.Data = itemConnected THEN
         connected := ( _CacheOnlyMode AND Running ) OR ( KNX <> NIL ) AND KNX^.KNXConnected();
         IF Direction = IOO.dirRead THEN
            Value.Boolean := connected;
            RETURN Sync.arCompleted;
         ELSIF connected = Value.Boolean THEN
            RETURN Sync.arCompleted;
         ELSE
            IF connected THEN
               Stop();
               RETURN Sync.arCompleted;
            ELSE
               RETURN Start();
            END;
         END;
      END;
      
      PObject := TPObject( NameValuePairs^.Data );
      IF Direction = IOO.dirRead THEN
         PObject^.GetValue( OUT EV, TRUE, FALSE );
         KNXValue2IOValue( EV, PObject^.StringValue, OUT Value );

      ELSE // dirWrite
         IOValue2KNXValue( Value, PObject^.Type, OUT EV, OUT PObject^.StringValue );
         PObject^.SetValue( EV, OUT changed );

         // log operation originator
         IF ( Originator <> NIL ) AND
            ( objtLogNoChange IN PObject^.ObjectType ) OR // log always
            ( objtLogOnChange IN PObject^.ObjectType ) AND changed THEN // always allow log failures
            description := Originator^.Description;
            PObject^.SendAddress.GetGroupAddress3( TRUE, OUT address );
            _DataLogger^.LogSSS( log.ldMessage, 0, L"srv", "SET RQ", address, OA( description.Length-1, description.Data ));
         END;         
      
         IF changed THEN
            PObject^.ChangedOnWrite := 1;
            // for notification using EventSink, if it exists
            ValueUpdated( IOO.dirWrite, PObject, PObject^.CommunicationState + knx_user.TObjectState{knx_user.osChanged} );
         ELSE
            PObject^.ChangedOnWrite := 0;
            // for notification using EventSink, if it exists
            ValueUpdated( IOO.dirWrite, PObject, PObject^.CommunicationState );
         END;
      END;

      IF KNX^.DeviceConnected() THEN
         RETURN Sync.arCompleted;
      ELSE
         RETURN Sync.arCompletedFromCache;
      END;
   END ValueIO;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROPERTY IOCapabilities GET : io.TCapabilities;
   BEGIN
      RETURN io.TCapabilities{};
   END IOCapabilities;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROPERTY Pending GET : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END Pending;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROPERTY Running GET : BOOLEAN;
   BEGIN
      IF _CacheOnlyMode THEN
         RETURN rsRunning IN RStatus;
      ELSE
         RETURN ( rsRunning IN RStatus ) AND ( KNX <> NIL ) AND KNX^.DeviceConnected();
      END;
   END Running;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE Start() : Sync.TAsyncResult;
   VAR
      s : FIO.PathStrW := L"";
   BEGIN
      IF rsRunning IN RStatus THEN
         RETURN Sync.arCompleted;
      ELSIF KNX = NIL THEN
         RETURN Sync.arCannotStart;
      ELSE
         INCL( RStatus, rsRunning );
      END;

      IF _CacheOnlyMode THEN
         OnDeviceConnect();
      ELSE
         StopTimer( tiForceRead );
         StopTimer( tiInitReadDelay );
         EXCL( RStatus, rsInitReadFinished );
         KNX^.Connect();
      END;

      IF Running THEN
         RETURN Sync.arCompleted;
      ELSE
         RETURN Sync.arPending;
      END;
   END Start;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE Stop();
   BEGIN
      IF rsRunning IN RStatus THEN
         EXCL( RStatus, rsRunning );
      ELSE
         RETURN;
      END;

      IF _CacheOnlyMode THEN
         OnDeviceDisconnect();
      ELSE
         StopTimer( tiForceRead );
         StopTimer( tiInitReadDelay );
         IF KNX <> NIL THEN
            KNX^.Disconnect();
         END;
      END;
   END Stop;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE IOh( CONST Originator : ns.TPOriginator; Direction : IOO.TDirection; Item : ns.THash; REF Value : iovalue.Value; Callback : io.TPDataInfo ) : Sync.TAsyncResult;
   BEGIN
      RETURN ValueIO( Originator, Item, Direction, REF Value );
   END IOh;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE IOha( CONST Originator : ns.TPOriginator; Direction : IOO.TDirection; Item : ARRAY OF ns.THash; REF Value : ARRAY OF iovalue.Value; Callback : io.TPDataInfo ) : Sync.TAsyncResult;
   BEGIN
      RETURN Sync.arCannotStart;
   END IOha;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE AbortAll();
   BEGIN
   END AbortAll;

//--------------------------------------------------------------------------------

   PUBLIC PROPERTY Configuration GET : StringsO.TPString;
   BEGIN
      RETURN ADR( ConfigurationPath );
   END Configuration;
   
//--------------------------------------------------------------------------------

   PUBLIC PROPERTY Connection GET : StringsO.CString;
   VAR
      connection : ARRAY [0..255] OF WCHAR;
      s : StringsO.CString;
   BEGIN
      IF _CacheOnlyMode THEN
         s.FromOA( L"CACHE" );
      ELSIF KNX = NIL THEN
         // fall down
      ELSIF KNX^.GetParameter( L"link.connection", OUT connection ) THEN
         s.FromOA( connection );
      END;
      RETURN s;
   END Connection;

//--------------------------------------------------------------------------------

   PUBLIC PROPERTY CacheOnlyMode GET : BOOLEAN;
   BEGIN
      RETURN _CacheOnlyMode;
   END CacheOnlyMode;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE LoadConfiguration( CONST ConfigurationFile : StringsO.IString; OUT ErrorMessage : StringsO.CString; OUT ErrorLine : CARDINAL ) : BOOLEAN;
   LABEL
      Fail;
   CONST
      // .PAR section names 
      snDevice               = L'device';
      snInterface            = L'interface';
      snReadStart            = L'read_on_start';
      snReadRun              = L'read_during_run';
      snBehaviours           = L'behaviours';
      snObjectTypes          = L'object_types';
      snObjects              = L'objects';
      snBlocks               = L'blocks';
      // .PAR key names
      knId                   = L'id';
         kvFalcon            = L'falcon';
         kvEIBnet            = L'eibnet';
         kvKNXnet            = L'knxnet';
      knKey                  = L'key';
      knCacheOnlyMode        = L'cache_only';
      knMode                 = L'mode';
      knInputQueueLength     = L'input_queue_length';
      knOutputQueueLength    = L'output_queue_length';
      knWriteQueueLength     = L'write_queue_length';
      knAddress              = L'address';
      knACKTimeout           = L'ACK_timeout';
      knBUSYDelay            = L'BUSY_delay';
      knACKMethod            = L'ACK_method';
      knRetryCount           = L'retry_count';
      knIgnoreRepeated       = L'ignore_repeated';
      knSendDelay            = L'send_delay';
      knWriteDelay           = L'write_delay';
      knTimeout              = L'timeout';
      knRepeatCount          = L'repeat_count';
      knDelay                = L'delay';
      knRecoveryTime         = L'recovery_time';
      knInitReadRepeatDelay  = L'read_on_start_delay';
      knInitReadRepeatCount  = L'read_on_start_repeat_count';
      knPromiscuousMode      = L'promiscuous_mode';
      knBehaviour            = L'behaviour';
         knForceReadPeriod   = L'readers_period';
         kvReadable          = L'readable';
         kvWritable          = L'writable';
         kvTransmit          = L'transmit';
         kvUpdate            = L'updateable';
         kvForceRead         = L'communicate_on_read';
         kvCallback          = L'callback_on_write';
         kvInitRead          = L'read_on_start';
         kvPHigh             = L'high';
         kvPAlarm            = L'alarm';
      // knObjectType
        kvLogNoChange        = L"log_always";
        kvLogOnChange        = L"log_on_change";
        kvMultipleAddresses  = L"multiple_addresses";
        kvESFStrict          = L'esf_strict';
        kvESFIgnore          = L'esf_ignore';
        kvESFAdapt           = L'esf_adapt';
      knBlock                = L'block';
      knType                 = L'type';
      snFormats              = L'formats';
      knDateAsString         = L'date_as_string';
      knDateFormat           = L'date_format';
      knTimeAsString         = L'time_as_string';               
      knTimeFormat           = L'time_format';
      snControl              = L'control';
      knDate                 = L'date';
      knTime                 = L'time';
      knDateAndTimePeriod    = L'date_time_push_period';

   //----------

      PROCEDURE AppendErrorId( REF ErrorMessage : StringsO.CString; CONST ErrorId : StringsO.IString );
      BEGIN
         ErrorMessage.AppendOA( L" (" );
         ErrorMessage.Append( ErrorId );
         ErrorMessage.AppendOA( L")" );
      END AppendErrorId;

   //----------
   
      PROCEDURE AppendErrorLine( REF ErrorMessage : StringsO.CString; Line : CARDINAL );
      VAR
         n : StringsO.CString;
      BEGIN
         n.FromCARD32( Line, 10 );
         ErrorMessage.AppendOA( L" [" );
         ErrorMessage.Append( n );
         ErrorMessage.AppendOA( L"]" );
      END AppendErrorLine;

   //----------
   
      PROCEDURE CreateParameterError( Key : CARDINAL; CONST ParameterError : ARRAY OF WCHAR; REF ErrorMessage : StringsO.CString );
      BEGIN
         ErrorMessage.FromOA( OAsz( R[ Key ] ));
         ErrorMessage.AppendOA( L": " );
         ErrorMessage.AppendOA( ParameterError );
      END CreateParameterError;
   
   //----------
   
      PROCEDURE AddGroup( CONST Address : knx_def.TAddress ) : BOOLEAN;
      VAR
         addr : CARD16 := CARD16( Address.GetGroupAddress1());
      BEGIN
         IF Groups[addr] <> 0FFFFH THEN
            RETURN FALSE;
         END;
         Groups[addr] := CARD16( Objects.Count-1 );
         RETURN TRUE;
      END AddGroup;

   //----------

      PROCEDURE StringToEIT( REF ErrorMessage : StringsO.CString; CONST String : StringsO.IString; VAR EIT : knx_def.TKNXType ) : BOOLEAN;
      BEGIN
         IF String[0] = WCHAR( 0 ) THEN
            ErrorMessage.FromOA( OAsz( R[ Texts._MissingType ] ));
            RETURN FALSE;
         ELSIF knx_def.StringToType( OA( String.Length-1, String.Data ), EIT ) THEN
            RETURN TRUE;
         ELSE
            ErrorMessage.FromOA( OAsz( R[ Texts._UnknownType ] ));
            AppendErrorId( REF ErrorMessage, String );
            RETURN FALSE;
         END;
      END StringToEIT;

   //----------

      PROCEDURE StringToSingleObject( REF ErrorMessage : StringsO.CString; CONST String : StringsO.CString; StartFromItem : CARDINAL; Priority : knx_def.TPriority; BFlags : knx_def.TA_ObjectFlags; EIT : knx_def.TKNXType; ObjectType : TObjectType ) : BOOLEAN;
      LABEL
         NextItem, NextItemAfterComment;
      VAR
         i : CARDINAL;
         l : CARDINAL;
         LAddress : knx_def.TAddress;
         p : StringsO.CString;
         PObject : TPObject;
         ReadAddressFound : BOOLEAN;
         FirstAddress : BOOLEAN;
         b : BOOLEAN;
      BEGIN
         ReadAddressFound := FALSE;
         FirstAddress := TRUE;
         i := StartFromItem;
         LOOP
            String.ItemS( StringsO.WCHARS{L','}, 0, i, TRUE, OUT p );
            IF i = StartFromItem THEN
               IF p.Empty THEN
                  ErrorMessage.FromOA( OAsz( R[ Texts._MissingAddress ] ));
                  RETURN FALSE;
               ELSE // OK, add object
                  PObject := AddObject( Priority, BFlags, EIT, ObjectType );
               END;
            ELSIF p.Empty THEN
               RETURN TRUE;
            END;
            p.Trim();

            IF ( p[0] = L"'" ) OR ( p[0] = L'"' ) THEN // comment
               p.Remove( 0, 1 );
               l := p.Length;
               IF l > 1 THEN
                  IF ( p[l-1] = L"'" ) OR ( p[l-1] = L'"' ) THEN
                     p.Length := l-1;
                  END;
                  PObject^.Comment := p;
               END;
               GOTO NextItemAfterComment;
            ELSIF p[0] = L'[' THEN // name
               p.Remove( 0, 1 );
               l := p.Length;
               IF l > 1 THEN
                  IF p[l-1] = L']' THEN
                     p.Length := l-1;
                  END;
                  PObject^.Name := p;
               END;
               GOTO NextItemAfterComment;
            END;

            IF NOT ReadAddressFound AND (( p[0] = L'r' ) OR ( p[0] = L'R' )) THEN
               p.Remove( 0, 1 );
               b := TRUE;
            ELSE
               b := FALSE;
            END;
            IF NOT LAddress.SetGroupAddress3( OA( p.Length-1, p.Data )) THEN
               ErrorMessage.FromOA( OAsz( R[ Texts._BadGroupAddress ] ));
               AppendErrorId( REF ErrorMessage, p );
               RETURN FALSE;
            END;
            IF FirstAddress AND NOT AddGroup( LAddress ) THEN
               ErrorMessage.FromOA( OAsz( R[ Texts._ObjectWithTheMainAddressAlreadyExists ] ));
               AppendErrorId( REF ErrorMessage, p );
               RETURN FALSE;
            END;
            PObject^.AddAddress( FALSE, FALSE, LAddress );
            IF NOT ReadAddressFound AND b THEN
               ReadAddressFound := TRUE;
               PObject^.ReadAddress := LAddress;
            END;

         NextItem:
            FirstAddress := FALSE;
         NextItemAfterComment:
            INC( i );
         END; // LOOP
      END StringToSingleObject;

   //----------

      PROCEDURE StringToMultipleObjects( REF ErrorMessage : StringsO.CString; CONST String : StringsO.IString; StartFromItem : CARDINAL; Priority : knx_def.TPriority; BFlags : knx_def.TA_ObjectFlags; EIT : knx_def.TKNXType; ObjectType : TObjectType ) : BOOLEAN;
      LABEL
         NextItem;
      VAR
         c : CARDINAL;
         Comment : StringsO.CString;
         f, l : CARDINAL;
         i, j : CARDINAL;
         LAddress : knx_def.TAddress;
         Name, Number : StringsO.CString;
         p0 : StringsO.CString; 
         p1, p2 : StringsO.CString;
         PObject : TPObject;
      BEGIN
         i := StartFromItem;
         LOOP
            String.ItemS( StringsO.WCHARS{L','}, 0, i, TRUE, OUT p0 );
            IF p0.Empty THEN
               IF i = StartFromItem THEN
                  ErrorMessage.FromOA( OAsz( R[ Texts._MissingAddress ] ));
                  RETURN FALSE;
               ELSE // OK, add object
                  EXIT;
               END;
            END;
            p0.Trim();
            
            IF ( p0[0] = L"'" ) OR ( p0[0] = L'"' ) THEN // comment
               p0.Remove( 0, 1 );
               l := p0.Length;
               IF l > 1 THEN
                  IF ( p0[l-1] = L"'" ) OR ( p0[l-1] = L'"' ) THEN
                     p0.Length := l-1;
                  END;
                  Comment := p0;
               END;
               GOTO NextItem;
            ELSIF p0[0] = L'[' THEN // name
               p0.Remove( 0, 1 );
               l := p0.Length;
               IF l > 1 THEN
                  IF p0[l-1] = L']' THEN
                     p0.Length := l-1;
                  END;
                  Name := p0;
               END;
               GOTO NextItem;
            END;

            c := p0.IndexOfOA( L'..', 0 );
            IF c = MAX( CARDINAL ) THEN
               IF NOT LAddress.SetGroupAddress3( OA( p0.Length-1, p0.Data )) THEN
                  ErrorMessage.FromOA( OAsz( R[ Texts._BadGroupAddress ] ));
                  AppendErrorId( REF ErrorMessage, p0 );
                  RETURN FALSE;
               END;
               f := CARDINAL( LAddress.GetGroupAddress1());
               l := f;
            ELSE
               p0.Substring( c + 2, MAX( CARDINAL ), OUT p2 );
               p1 := p0;
               p1.Length := c;
               IF NOT LAddress.SetGroupAddress3( OA( p1.Length-1, p1.Data )) THEN
                  ErrorMessage.FromOA( OAsz( R[ Texts._BadGroupAddress ] ));
                  AppendErrorId( REF ErrorMessage, p1 );
                  RETURN FALSE;
               END;
               f := CARDINAL( LAddress.GetGroupAddress1());
               IF NOT LAddress.SetGroupAddress3( OA( p2.Length-1, p2.Data )) THEN
                  ErrorMessage.FromOA( OAsz( R[ Texts._BadGroupAddress ] ));
                  AppendErrorId( REF ErrorMessage, p2 );
                  RETURN FALSE;
               END;
               l := CARDINAL( LAddress.GetGroupAddress1());
               IF l < f THEN
                  ErrorMessage.FromOA( OAsz( R[ Texts._BadGroupAddressInterval ] ));
                  AppendErrorId( REF ErrorMessage, p0 );
                  RETURN FALSE;
               END;
            END;

            j := 1;
            FOR c := f TO l DO
               PObject := AddObject( Priority, BFlags, EIT, ObjectType );
               LAddress.SetGroupAddress1( c );
               IF NOT Name.Empty THEN
                  Number.FromCARD32( j, 10 );
                  Number.Size := 16;
                  Number.Length := 4;
                  Strings.PadLeftW( REF OA( Number.Size-1, PWCHAR( Number.Data )), 4, L'0' );
                  PObject^.Name := Name;
                  PObject^.Name.Append( Number );
                  INC( j );
               END;
               IF NOT Comment.Empty THEN
                  PObject^.Comment := Comment;
               END;

               IF AddGroup( LAddress ) THEN
                  PObject^.AddAddress( FALSE, FALSE, LAddress );
               ELSE
                  ErrorMessage.FromOA( OAsz( R[ Texts._ObjectWithTheMainAddressAlreadyExists ] ));
                  AppendErrorId( REF ErrorMessage, p0 );
                  RETURN FALSE;
               END;
            END; // FOR

         NextItem:
            INC( i );
         END; // LOOP
         RETURN TRUE;
      END StringToMultipleObjects;

   //----------

   CONST
      fullIOFlags = knx_def.TA_ObjectFlags{knx_def.aofCommunicated, knx_def.aofTransmit, knx_def.aofUpdate, knx_def.aofWritable};

   VAR
      fs : FIOO.CFileStream;
      tr : TextReader.CTextReader;

   //----------

      PROCEDURE ReadESF( REF ErrorMessage : StringsO.CString; CONST Mode : ARRAY OF WCHAR; CONST ESFPath : StringsO.CString; ObjectType : TObjectType ) : BOOLEAN;
      CONST
         kvEIS = L"EIS";
         kvESFLow = L"Low";
         kvESFHigh = L"High";
         kvESFAlarm = L"Alarm";
         kvUncertain = L"Uncertain";
         tabSet = StringsO.WCHARS{ 9W };
         spaceSet = StringsO.WCHARS{ L" " };
      VAR
         c, i : CARDINAL;
         EIT : knx_def.TKNXType;
         GroupAddress : knx_def.CAddress;
         so, item, io : StringsO.CString;
         Path : FIO.PathStrW;
         PObject : TPObject;
         Priority : knx_def.TPriority;
      BEGIN
         TRY
            FIO.PathHeadW( OA( ConfigurationFile.Length-1, ConfigurationFile.Data ), OUT Path );
            FIO.PathAddW( REF Path, OA( ESFPath.Length-1, ESFPath.Data ));
            fs.FromPath( Path, FIOO.imOpenRead );
         CATCH e : IOO.CIOException DO
            ErrorMessage.FromOA( OAsz( R[ Texts._CannotOpenESF ] ));
            AppendErrorId( REF ErrorMessage, ESFPath );
            RETURN FALSE;
         END; // try
         tr.Stream := ADR( fs );
         tr.ReadLine( OUT so, Sync.FORSAFETY, TRUE ); // read first line comment
         WHILE tr.ReadLine( OUT so, Sync.FORSAFETY, TRUE ) = Sync.arCompleted DO
            IF so.Empty THEN
               CONTINUE;
            END;

            // group address
            i := so.ItemS( tabSet, 0, 0, FALSE, OUT item );
            IF item.Empty THEN
               ErrorMessage.FromOA( OAsz( R[ Texts._ESFMissingGroupField1 ] ));
               AppendErrorLine( REF ErrorMessage, tr.Line );
               RETURN FALSE;
            ELSE
               c := Strings.LastIndexOfCharW( OA( item.Length-1, item.Data ), L'.', 0 );
               IF c <> -1 THEN
                  item.Remove( 0, c+1 );
               END;
               item.Trim();
               IF NOT GroupAddress.SetGroupAddress3( OA( item.Length-1, item.Data )) THEN
                  ErrorMessage.FromOA( OAsz( R[ Texts._BadGroupAddress ] ));
                  AppendErrorLine( REF ErrorMessage, tr.Line );
                  RETURN FALSE;
               END;
            END;
            
            // skip name, read type
            i := so.ItemS( tabSet, i, 1, FALSE, OUT item );
            c := item.ItemS( spaceSet, 0, 0, FALSE, OUT io );
            IF io.Empty THEN
               ErrorMessage.FromOA( OAsz( R[ Texts._ESFMissingTypeField3 ] ));
               AppendErrorLine( REF ErrorMessage, tr.Line );
               RETURN FALSE;

            ELSIF io.EqualsOA( kvEIS ) THEN
               c := item.ItemS( spaceSet, c, 0, FALSE, OUT io );
               IF NOT io.ToCARD32( 10, OUT c ) THEN
                  ErrorMessage.FromOA( OAsz( R[ Texts._BadTypeInfo ] ));
                  AppendErrorLine( REF ErrorMessage, tr.Line );
                  RETURN FALSE;
               ELSIF NOT knx_def.NumberToType( c, EIT ) THEN
                  ErrorMessage.FromOA( OAsz( R[ Texts._BadTypeInfo ] ));
                  AppendErrorLine( REF ErrorMessage, tr.Line );
                  RETURN FALSE;
               END;

            ELSIF io.EqualsOA( kvUncertain ) THEN
               IF objtESFIgnore IN ObjectType THEN
                  CONTINUE;
               ELSIF objtESFStrict IN ObjectType THEN
                  ErrorMessage.FromOA( OAsz( R[ Texts._BadTypeInfoUnableToDetectUncertainType ] ));
                  AppendErrorLine( REF ErrorMessage, tr.Line );
                  RETURN FALSE;
               END;

               item.Remove( 0, c );
               c := item.IndexOfOA( L'(', 0 );
               IF c = -1 THEN
                  ErrorMessage.FromOA( OAsz( R[ Texts._BadTypeInfo ] ));
                  AppendErrorLine( REF ErrorMessage, tr.Line );
                  RETURN FALSE;
               ELSE
                  item.Remove( 0, c+1 );
               END;
               c := item.IndexOfOA( L')', 0 );
               IF c = -1 THEN
                  ErrorMessage.FromOA( OAsz( R[ Texts._BadTypeInfo ] ));
                  AppendErrorLine( REF ErrorMessage, tr.Line );
                  RETURN FALSE;
               ELSE
                  item.Remove( c, -1 );
               END;
               item.Trim();
               CASE item[0] OF
               | L'1' :
                  IF item[1] = L'4' THEN
                     EIT := knx_def.eitString;
                  ELSIF item[3] = L'i' THEN
                     EIT := knx_def.eitSwitch;
                  ELSE // L'y' -- byte
                     EIT := knx_def.eitScaling;
                  END;
               | L'2' :
                  EIT := knx_def.eitValue;
               | L'3' :
                  EIT := knx_def.eitTime;
               | L'4' :
                  IF item[3] = L'i' THEN
                     EIT := knx_def.eitIncrease;
                  ELSE // L'y' -- byte
                     EIT := knx_def.eit32bit;
                  END;
               ELSE
                  ErrorMessage.FromOA( OAsz( R[ Texts._BadTypeInfo ] ));
                  AppendErrorLine( REF ErrorMessage, tr.Line );
                  RETURN FALSE;
               END; // CASE

            ELSE
               ErrorMessage.FromOA( OAsz( R[ Texts._BadTypeInfo ] ));
               AppendErrorLine( REF ErrorMessage, tr.Line );
               RETURN FALSE;
            END;
            
            // read priority
            i := so.ItemS( tabSet, i, 0, FALSE, OUT item );
            IF item.Empty THEN
               ErrorMessage.FromOA( OAsz( R[ Texts._ESFMissingPriorityField4 ] ));
               AppendErrorLine( REF ErrorMessage, tr.Line );
               RETURN FALSE;
            ELSIF item.EqualsOA( kvESFLow ) THEN
               Priority := knx_def.priorityNormal;
            ELSIF item.EqualsOA( kvESFHigh ) THEN
               Priority := knx_def.priorityHigh;
            ELSIF item.EqualsOA( kvESFAlarm ) THEN
               Priority := knx_def.priorityAlarm;
            ELSE
               ErrorMessage.FromOA( OAsz( R[ Texts._BadESFPriority ] ));
               AppendErrorLine( REF ErrorMessage, tr.Line );
               RETURN FALSE;
            END;
            
            PObject := AddObject( Priority, fullIOFlags, EIT, ObjectType );
            IF AddGroup( GroupAddress ) THEN
               PObject^.AddAddress( FALSE, FALSE, GroupAddress );
            ELSE
               ErrorMessage.FromOA( OAsz( R[ Texts._ObjectWithTheMainAddressAlreadyExists ] ));
               AppendErrorLine( REF ErrorMessage, tr.Line );
               RETURN FALSE;
            END;

            // read optional adjacent group address;
            i := so.ItemS( tabSet, i, 0, FALSE, OUT item );
            IF NOT item.Empty THEN
               so := item;
               i := so.ItemS( spaceSet, 0, 0, FALSE, OUT item );
               WHILE NOT item.Empty DO
                  IF NOT GroupAddress.SetGroupAddress3( OA( item.Length-1, item.Data )) THEN
                     ErrorMessage.FromOA( OAsz( R[ Texts._BadAdjacentGroupAddress ] ));
                     AppendErrorLine( REF ErrorMessage, tr.Line );
                     RETURN FALSE;
                  END;
                  PObject^.AddAddress( FALSE, FALSE, GroupAddress );
                  i := so.ItemS( spaceSet, i, 0, FALSE, OUT item );
               END;
            END; // WHILE

         END; // WHILE

         fs.Close( FALSE );
         RETURN TRUE;
      END ReadESF;

   //----------

   VAR
      BFlags : knx_def.TA_ObjectFlags;
      Blocks : lists.CStringList;
      c : CARDINAL;
      Connection, Key : ARRAY [0..255] OF WCHAR;
      EIT : knx_def.TKNXType;
      ErrorMessageOA : ARRAY [0..255] OF WCHAR;
      ES : PTR;
      i : CARDINAL;
      Name : StringsO.CString;
      objectType : TObjectType;
      p : StringsO.CString;
      pairs : namevaluepairsimpl.TPNameValuePairsIO;
      PBehaviour : TPBehaviour;
      PObject : TPObject;
      Priority : knx_def.TPriority;
      s : ARRAY [0..4095] OF WCHAR;
      so : StringsO.CString;
      TS : INIFile.CINIFile;
      b : BOOLEAN;
      logged : BOOLEAN;
   BEGIN
      IF EXEFlag THEN
         R.LoadRES2( L"", L"knxcore.Texts" );
      ELSE
         R.LoadRES2( EMITW( %dll ), L"knxcore.Texts" );
      END;
      ErrorLine := 0;
      InitToDefault();
      
      TRY
         fs.FromPath( OA( ConfigurationFile.Length-1, ConfigurationFile.Data ), FIOO.imOpenRead );
      CATCH e : IOO.CIOException DO
         ErrorMessage.FromOA( OAsz( R[ Texts._CannotOpenPar ] ));
         GOTO Fail;
      END; // try

      so.FromOA( L";" );
      tr.Stream := ADR( fs );
      tr.CommentaryStart := so;
      tr.OmitCommentaries := TRUE;
      b := TS.Load( tr );
      fs.Close( FALSE );
      IF NOT b THEN
         ErrorMessage.FromOA( OAsz( R[ Texts._CannotOpenPar ] ));
         AppendErrorId( REF ErrorMessage, ConfigurationFile );
         GOTO Fail;
      END;

      // read device id
      DeviceId := -1;
      PromiscuousMode := FALSE;
      Connection := L'';
      Key := L'';
      IF TS.SetSection( snDevice ) THEN
         IF TS.GetKeyStr( knId, OUT ErrorLine, OUT so ) THEN
            IF so.StartsWithOA( kvFalcon ) THEN
               c := so.IndexOfOA( kvFalcon, 0 );
               so.SubstringOA( c+LENGTH( kvFalcon )+1, MAX( CARDINAL ), OUT Connection );
               Strings.TrimW( REF Connection );
            ELSIF so.StartsWithOA( kvEIBnet ) THEN
               c := so.IndexOfOA( kvEIBnet, 0 );
               so.SubstringOA( c+LENGTH( kvEIBnet )+1, MAX( CARDINAL ), OUT Connection );
               Strings.TrimW( REF Connection );
               DeviceId := LONGWORD( -2 );
            ELSIF so.StartsWithOA( kvKNXnet ) THEN
               c := so.IndexOfOA( kvKNXnet, 0 );
               so.SubstringOA( c+LENGTH( kvKNXnet )+1, MAX( CARDINAL ), OUT Connection );
               Strings.TrimW( REF Connection );
               DeviceId := LONGWORD( -2 );
            END;
         END;
         IF TS.GetKeyStr( knKey, OUT ErrorLine, OUT so ) THEN
            so.ToOA( OUT Key );
         END;
         IF NOT TS.GetKeyBool( knCacheOnlyMode, OUT ErrorLine, OUT _CacheOnlyMode ) AND _CacheOnlyMode THEN
            _CacheOnlyMode := FALSE;
         END;
      END; // IF snDevice
      IF _CacheOnlyMode THEN
         NEW( knxstack_knxnet.TPKNXnetStack( KNX ));
      ELSIF DeviceId = LONGWORD( -1 ) THEN
         // Stack := stackFalcon;
         // NEW( falconStack.TPFalconStack( KNX ));
         // ASSIGN( falconStack.TPFalconStack( KNX )^.Connection, FalconConnection );
         // ASSIGN( falconStack.TPFalconStack( KNX )^.Key, Key );
         ErrorMessage.FromOA( OAsz( R[ Texts._UnsupportedStack ] ));
         GOTO Fail;
      ELSIF DeviceId = LONGWORD( -2 ) THEN
         Stack := stackKNXnet;
         NEW( knxstack_knxnet.TPKNXnetStack( KNX ));
      ELSE
         // Stack := stackUSB;
         // NEW( eibusb.TPTPUARTStack( KNX ));
         ErrorMessage.FromOA( OAsz( R[ Texts._UnsupportedStack ] ));
         GOTO Fail;
      END;

      KNX^.Init( FALSE, knx_stack.kltUndefined, knx_stack.kltUndefined, ADR( Sink ));
      knxstack_knxnet.TPKNXnetStack( KNX )^.SetLogger( ADR( Logger ));

      IF NOT KNX^.SetParameter( L"link.connection", Connection, OUT ErrorMessageOA ) THEN
         CreateParameterError( Texts._BadConnection, ErrorMessageOA, REF ErrorMessage );
         GOTO Fail;
      END;
      // still inside snDevice
      IF TS.GetKeyStr( knMode, OUT ErrorLine, OUT so ) THEN
         IF NOT KNX^.SetParameter( L"link.mode", OA( so.Length-1, so.Data ), OUT ErrorMessageOA ) THEN
            CreateParameterError( Texts._BadMode, ErrorMessageOA, REF ErrorMessage );
            GOTO Fail;
         END;
      END;

      // read interface options
      IF TS.SetSection( snInterface ) THEN
         IF TS.GetKeyInt( knInputQueueLength, OUT ErrorLine, OUT c ) THEN
            InputQueueLength := c;
         END;
         IF TS.GetKeyStr( knOutputQueueLength, OUT ErrorLine, OUT so ) THEN
            IF NOT KNX^.SetParameter( L"link.outputQueueLength", OA( so.Length-1, so.Data ), OUT ErrorMessageOA ) THEN
               CreateParameterError( Texts._BadOutputQueueLength, ErrorMessageOA, REF ErrorMessage );
               GOTO Fail;
            END;
         END;
         IF TS.GetKeyStr( knWriteQueueLength, OUT ErrorLine, OUT so ) THEN
            IF NOT KNX^.SetParameter( L"application.pendingQueueLength.write", OA( so.Length-1, so.Data ), OUT ErrorMessageOA ) THEN
               CreateParameterError( Texts._BadWriteQueueLength, ErrorMessageOA, REF ErrorMessage );
               GOTO Fail;
            END;
         END;
         IF TS.GetKeyStr( knAddress, OUT ErrorLine, OUT so ) THEN
            IF NOT Address.SetPhysicalAddress3( OA( so.Length-1, so.Data )) THEN
               ErrorMessage.AppendOA( OAsz( R[ Texts._BadPhysicalAddress ] ));
               AppendErrorId( REF ErrorMessage, so );
               GOTO Fail;
            END;
         END;
         IF TS.GetKeyInt( knACKTimeout, OUT ErrorLine, OUT c ) THEN
            ACKTimeout := c;
         END;
         IF TS.GetKeyStr( knACKMethod, OUT ErrorLine, OUT so ) THEN
            IF NOT KNX^.SetParameter( L"link.ackMethod", OA( so.Length-1, so.Data ), OUT ErrorMessageOA ) THEN
               CreateParameterError( Texts._BadACKMethod, ErrorMessageOA, REF ErrorMessage );
               GOTO Fail;
            END;
         END;
         IF TS.GetKeyStr( knRetryCount, OUT ErrorLine, OUT so ) THEN
            IF NOT KNX^.SetParameter( L"link.retryCount", OA( so.Length-1, so.Data ), OUT ErrorMessageOA ) THEN
               CreateParameterError( Texts._BadRetryCount, ErrorMessageOA, REF ErrorMessage );
               GOTO Fail;
            END;
         END;
         IF TS.GetKeyInt( knBUSYDelay, OUT ErrorLine, OUT c ) THEN
            BUSYDelay := c;
         END;
         IF TS.GetKeyInt( knSendDelay, OUT ErrorLine, OUT c ) THEN
            SendDelay := c;
         END;
         IF TS.GetKeyInt( knWriteDelay, OUT ErrorLine, OUT c ) THEN
            WriteDelay := c;
         END;
         IF TS.GetKeyBool( knIgnoreRepeated, OUT ErrorLine, OUT b ) THEN
            IgnoreRepeated := b;
         END;
         IF TS.GetKeyInt( knInitReadRepeatDelay, OUT ErrorLine, OUT c ) THEN
            InitReadRepeatDelay := c;
         END;
         IF TS.GetKeyInt( knInitReadRepeatCount, OUT ErrorLine, OUT c ) THEN
            InitReadRepeatCount := c;
         END;
         IF TS.GetKeyBool( knPromiscuousMode, OUT ErrorLine, OUT b ) THEN
            PromiscuousMode := b;
         END;
      END;

      // read read on start options
      IF TS.SetSection( snReadStart ) THEN
         // timeouts
         IF TS.GetKeyInt( knTimeout, OUT ErrorLine, OUT c ) THEN
            ReadOnStart.Timeout := c;
         END;
         IF TS.GetKeyInt( knRepeatCount, OUT ErrorLine, OUT c ) THEN
            ReadOnStart.RepeatCount := MAX2( 1, c );
         END;
         IF TS.GetKeyInt( knDelay, OUT ErrorLine, OUT c ) THEN
            ReadOnStart.Delay := c;
         END;
         IF TS.GetKeyInt( knRecoveryTime, OUT ErrorLine, OUT c ) THEN
            ReadOnStart.RecoveryTime := c;
         END;
      END; // IF snReadStart

      // read read during run options
      IF TS.SetSection( snReadRun ) THEN
         // timeouts
         IF TS.GetKeyInt( knTimeout, OUT ErrorLine, OUT c ) THEN
            ReadDuringRun.Timeout := c;
         END;
         IF TS.GetKeyInt( knRepeatCount, OUT ErrorLine, OUT c ) THEN
            ReadDuringRun.RepeatCount := MAX2( 1, c );
         END;
         IF TS.GetKeyInt( knDelay, OUT ErrorLine, OUT c ) THEN
            ReadDuringRun.Delay := c;
         END;
         IF TS.GetKeyInt( knRecoveryTime, OUT ErrorLine, OUT c ) THEN
            ReadDuringRun.RecoveryTime := c;
         END;
      END; // IF snReadRun

      // read behaviours
      Behaviours.Dispose();
      IF TS.SetSection( snBehaviours ) THEN
         IF NOT TS.GetKeyInt( knForceReadPeriod, OUT ErrorLine, OUT _ForceReadPeriod ) THEN
            _ForceReadPeriod := 0;
         ELSIF _ForceReadPeriod < 60 * 1000 THEN // _ForceReadPeriod cannot be smaller than 1 minute
            _ForceReadPeriod := 60 * 1000;
         END;

         ES := 0;
         WHILE TS.EnumerateKeys( REF ES, OUT ErrorLine, OUT p, OUT so ) DO
            IF NOT p.EqualsOA( knBehaviour ) THEN
               CONTINUE;
            END;

            Priority := knx_def.priorityNormal;
            so.ItemS( StringsO.WCHARS{L' ', L','}, 0, 0, TRUE, OUT p );
            IF p.Empty THEN
               ErrorMessage.AppendOA( OAsz( R[ Texts._MissingBehaviourName ] ));
               GOTO Fail;
            ELSE
               BFlags := knx_def.TA_ObjectFlags{knx_def.aofCommunicated};
               Name := p;
            END;

            i := 1;
            LOOP
               so.ItemS( StringsO.WCHARS{L' ', L','}, 0, i, TRUE, OUT p );
               IF p.Empty THEN
                  EXIT;
               END;
               IF p.EqualsOA( kvReadable ) THEN
                  INCL( BFlags, knx_def.aofReadable );
               ELSIF p.EqualsOA( kvWritable ) THEN
                  INCL( BFlags, knx_def.aofWritable );
               ELSIF p.EqualsOA( kvTransmit ) THEN
                  INCL( BFlags, knx_def.aofTransmit );
               ELSIF p.EqualsOA( kvUpdate ) THEN
                  INCL( BFlags, knx_def.aofUpdate );
               ELSIF p.EqualsOA( kvForceRead ) THEN
                  INCL( BFlags, knx_def.aofForceRead );
               ELSIF p.EqualsOA( kvCallback ) THEN
                  INCL( BFlags, knx_def.aofAdvise );
               ELSIF p.EqualsOA( kvInitRead ) THEN
                  INCL( BFlags, knx_def.aofInitRead );
               ELSIF p.EqualsOA( kvPHigh ) THEN
                  Priority := knx_def.priorityHigh;
               ELSIF p.EqualsOA( kvPAlarm ) THEN
                  Priority := knx_def.priorityAlarm;
               ELSE
                  ErrorMessage.AppendOA( OAsz( R[ Texts._BadBehaviourItemName ] ));
                  AppendErrorId( REF ErrorMessage, p );
                  GOTO Fail;
               END;
               INC( i );
            END; // LOOP

            NEW( PBehaviour );
            PBehaviour^.Name := Name;
            PBehaviour^.Class := Priority;
            PBehaviour^.Flags := BFlags;
            Behaviours.Append( PBehaviour );
         END; // WHILE
      END; // IF snBehaviours
      
      // read object types
      ObjectTypes.Dispose();
      IF TS.SetSection( snObjectTypes ) THEN
         ES := 0;
         WHILE TS.EnumerateKeys( REF ES, OUT ErrorLine, OUT p, OUT so ) DO
            objectType := TObjectType{};

            i := 0;
            LOOP
               so.ItemS( StringsO.WCHARS{L' ', L','}, 0, i, TRUE, OUT p );
               IF p.Empty THEN
                  EXIT;
               END;
               IF p.EqualsOA( kvLogNoChange ) THEN
                  INCL( objectType, objtLogNoChange );
               ELSIF p.EqualsOA( kvLogOnChange ) THEN
                  INCL( objectType, objtLogOnChange );
               ELSIF p.EqualsOA( kvMultipleAddresses ) THEN
                  INCL( objectType, objtMultipleAddresses );
               ELSIF p.EqualsOA( kvESFStrict ) THEN
                  INCL( objectType, objtESFStrict );
               ELSIF p.EqualsOA( kvESFIgnore ) THEN
                  INCL( objectType, objtESFIgnore );
               ELSIF p.EqualsOA( kvESFAdapt ) THEN
                  INCL( objectType, objtESFAdapt );
               ELSE
                  ErrorMessage.AppendOA( OAsz( R[ Texts._BadObjectTypeItemName ] ));
                  AppendErrorId( REF ErrorMessage, p );
                  GOTO Fail;
               END;
               INC( i );
            END; // LOOP

            ObjectTypes.Add( p, PTR( objectType ));
         END; // WHILE
      END; // IF snObjectTypes

      // read objects
      INCL( RStatus, rsInitReadFinished );

      IF TS.SetSection( snObjects ) THEN
         ES := 0;
         WHILE TS.EnumerateKeys( REF ES, OUT ErrorLine, OUT p, OUT so ) DO
            IF NOT FindObjectType( p, OUT objectType ) THEN
               ErrorMessage.AppendOA( OAsz( R[ Texts._UnknownObjectType ] ));
               AppendErrorId( REF ErrorMessage, p );
               GOTO Fail;
            END;
            
            IF TObjectType{objtESFStrict, objtESFAdapt, objtESFIgnore} * objectType <> TObjectType{} THEN // esf file
               IF NOT ReadESF( REF ErrorMessage, OA( p.Length-1, p.Data ), so, objectType ) THEN
                  GOTO Fail;
               END;
            
            ELSE // other object types
               so.ItemS( StringsO.WCHARS{L' ', L','}, 0, 0, TRUE, OUT p );
               IF p.Empty THEN
                  ErrorMessage.AppendOA( OAsz( R[ Texts._MissingBehaviourName ] ));
                  GOTO Fail;
               ELSIF NOT FindBehaviour( p, Priority, BFlags ) THEN
                  ErrorMessage.AppendOA( OAsz( R[ Texts._UnknownBehaviour ] ));
                  AppendErrorId( REF ErrorMessage, p );
                  GOTO Fail;
               ELSIF NOT _CacheOnlyMode AND ( knx_def.aofInitRead IN BFlags ) THEN // in _CacheOnlyMode no init read is done
                  EXCL( RStatus, rsInitReadFinished );
               END;
               so.ItemS( StringsO.WCHARS{L' ', L','}, 0, 1, TRUE, OUT p );
               IF NOT StringToEIT( REF ErrorMessage, p, EIT ) THEN
                  GOTO Fail;
               END;

               IF objtMultipleAddresses IN objectType  THEN
                  IF NOT StringToSingleObject( REF ErrorMessage, so, 2, Priority, BFlags, EIT, objectType ) THEN
                     GOTO Fail;
                  END;
               ELSE
                  IF NOT StringToMultipleObjects( REF ErrorMessage, so, 2, Priority, BFlags, EIT, objectType ) THEN
                     GOTO Fail;
                  END;
               END;

            END; // if ESF or normal object
         END; // WHILE
      END; // IF snObjects

      // read blocks
      IF TS.SetSection( snBlocks ) THEN
         ES := 0;
         WHILE TS.EnumerateKeys( REF ES, OUT ErrorLine, OUT p, OUT so ) DO
            IF p.EqualsOA( knBlock ) THEN
               Blocks.Enqueue( so, 0 );
            END;
         END;
      END; // IF snGroups
      WHILE Blocks.Dequeue( OUT p, OUT c ) DO

         IF NOT TS.SetSection( OA( p.Length-1, p.Data )) THEN
            ErrorMessage.AppendOA( OAsz( R[ Texts._RequestedBlockNotFound ] ));
            ErrorMessage.AppendOA( L' (' );
            ErrorMessage.Append( p );
            ErrorMessage.AppendOA( L')' );
            GOTO Fail;
         END;

         IF NOT TS.GetKeyStr( knType, OUT ErrorLine, OUT so ) THEN
            ErrorMessage.AppendOA( OAsz( R[ Texts._BlockWithoutType ] ));
            AppendErrorId( REF ErrorMessage, p );
            GOTO Fail;
         ELSIF NOT StringToEIT( REF ErrorMessage, so, EIT ) THEN
            GOTO Fail;
         END;

         IF NOT TS.GetKeyStr( knBehaviour, OUT ErrorLine, OUT so ) THEN
            ErrorMessage.AppendOA( OAsz( R[ Texts._BlockWithoutBehaviour ] ));
            AppendErrorId( REF ErrorMessage, p );
            GOTO Fail;
         END;
         IF NOT FindBehaviour( so, Priority, BFlags ) THEN
            ErrorMessage.AppendOA( OAsz( R[ Texts._UnknownBehaviour ] ));
            AppendErrorId( REF ErrorMessage, so );
            GOTO Fail;
         ELSIF NOT _CacheOnlyMode AND ( knx_def.aofInitRead IN BFlags ) THEN
            EXCL( RStatus, rsInitReadFinished );
         END;

         // objects
         ES := 0;
         WHILE TS.EnumerateKeys( REF ES, OUT ErrorLine, OUT p, OUT so ) DO
            IF p.EqualsOA( knType ) THEN
               CONTINUE;
            ELSIF p.EqualsOA( knBehaviour ) THEN
               CONTINUE;
            ELSIF NOT FindObjectType( p, OUT objectType ) THEN
               ErrorMessage.AppendOA( OAsz( R[ Texts._UnknownObjectType ] ));
               AppendErrorId( REF ErrorMessage, p );
               GOTO Fail;
            END;
            
            IF objtMultipleAddresses IN objectType  THEN
               IF NOT StringToSingleObject( REF ErrorMessage, so, 0, Priority, BFlags, EIT, objectType ) THEN
                  GOTO Fail;
               END;
            ELSE
               IF NOT StringToMultipleObjects( REF ErrorMessage, so, 0, Priority, BFlags, EIT, objectType ) THEN
                  GOTO Fail;
               END;
            END;
         END; // WHILE objects

      END; // WHILE Blocks
      
      // read formats
      IF TS.SetSection( snFormats ) THEN
         IF TS.GetKeyBool( knDateAsString, OUT ErrorLine, OUT b ) THEN
            DateAsString := b;
         END;
         IF TS.GetKeyStr( knDateFormat, OUT ErrorLine, OUT so ) THEN
            DateFormat := so;
         END;

         IF TS.GetKeyBool( knTimeAsString, OUT ErrorLine, OUT b ) THEN
            TimeAsString := b;
         END;
         IF TS.GetKeyStr( knTimeFormat, OUT ErrorLine, OUT so ) THEN
            TimeFormat := so;
         END;
      END; // IF snFormats
      
      // read control
      IF TS.SetSection( snControl ) THEN
         IF NOT FindBehaviour( StringsO.FromOA( bnSource ), Priority, BFlags ) THEN
            Priority := knx_def.priorityNormal;
            BFlags := knx_def.TA_ObjectFlags{};
         END;
         IF TS.GetKeyStr( knDate, OUT ErrorLine, OUT so ) THEN
            IF NOT StringToMultipleObjects( REF ErrorMessage, so, 0, Priority, BFlags, knx_def.eitDate, TObjectType{ objtDate } ) THEN
               GOTO Fail;
            END;
         END;
         IF TS.GetKeyStr( knTime, OUT ErrorLine, OUT so ) THEN
            IF NOT StringToMultipleObjects( REF ErrorMessage, so, 0, Priority, BFlags, knx_def.eitTime, TObjectType{ objtTime } ) THEN
               GOTO Fail;
            END;
         END;

         IF NOT TS.GetKeyInt( knDateAndTimePeriod, OUT ErrorLine, OUT _DateAndTimePushPeriod ) THEN
            _DateAndTimePushPeriod := 1800000;
         ELSIF _DateAndTimePushPeriod < 600000 THEN // _ForceReadPeriod cannot be smaller than 10 minute
            _DateAndTimePushPeriod := 600000;
         END;
      END;

      // handle connection and promiscuous mode
      IF NOT _CacheOnlyMode THEN
         KNX^.SetStackAddress( Address );

         IF PromiscuousMode THEN
            KNX^.SetParameter( L"application.promiscuousMode", L"true", OUT ErrorMessageOA );
         ELSE
            KNX^.SetParameter( L"application.promiscuousMode", L"false", OUT ErrorMessageOA );
         END;
         IF PromiscuousMode THEN
            FOR EIT := knx_def.eitSwitch TO knx_def.eitString DO WITH prObjects[EIT] DO
               Server := ADR( SELF );
               Init( KNX, EIT, knx_user.obNone );
               SetClass( knx_def.priorityNormal );
               SetFlags( fullIOFlags + knx_def.TA_ObjectFlags{knx_def.aofPromiscuous} );
               SubscribePromiscuous();
            END; END; // WITH // FOR
         END; // IF PromiscuousMode

         KNX^.SetTimeout( knx_stack.tidL_ACKTimeout, ACKTimeout, 0 );
         KNX^.SetTimeout( knx_stack.tidL_BUSYDelay, BUSYDelay, 0 );
         KNX^.SetTimeout( knx_stack.tidL_SendDelay, SendDelay, 0 );
         KNX^.SetTimeout( knx_stack.tidA_PendingDelay, WriteDelay, knx_stack.pendingGroupWrite );
         KNX^.SetTimeout( knx_stack.tidA_PendingDelay, ReadOnStart.Delay, knx_stack.pendingGroupRead );
         KNX^.SetTimeout( knx_stack.tidA_PendingTimeout, ReadOnStart.Timeout, knx_stack.pendingGroupRead );

         IF NOT PromiscuousMode THEN
            knx_stack.TPKNXStackApplicationLayer( KNX^.Layers[ knx_stack.kltApplication ] )^.Update_L_Layer();
         END;
      END; // IF NOT _CacheOnlyMode

      // fill namespace
      // compute line name (1.5.156 -> 1-5)
      // UNTIL there are more lines in the code, no line-address-specific namespace is needed
      // Address.GetPhysicalAddress3( OUT s );
      // IF EQUALS( s, L"" ) THEN
      //    s := L"0-0";
      // ELSE
      //    i := Strings.LastIndexOfCharW( s, L".", 0 );
      //    IF i <> -1 THEN
      //       s[i] := 0W;
      //    END;
      //    i := Strings.IndexOfCharW( s, L".", 0 );
      //    IF i <> -1 THEN
      //       s[i] := L"-";
      //    END;
      // END;
      // Namespace.InitializeName := StringsO.FromOA( s );
      Namespace.InitializeName := StringsO.FromOA( nameNamespace );

      // group addresses
      FOR i := 0 TO Objects.Count - 1 DO
         PObject := TPObject( Objects[i] );
         PObject^.SendAddress.GetGroupAddress3( TRUE, OUT s );
         Namespace.DefineIOValue( StringsO.FromOA( s ), REF SELF, PObject, NIL, OUT pairs );
      END; // FOR

      // connection info/control
      Namespace.DefineIOValue( StringsO.FromOA( nameConnected ), REF SELF, itemConnected, NIL, OUT pairs );
      
      ConfigurationPath.Assign( ConfigurationFile ); // store sucessfully read configuration
      RETURN TRUE;

   Fail:
      Blocks.Dispose();
      RETURN FALSE;
   END LoadConfiguration;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE Dispose();
   BEGIN
      InitToDefault();
      SUPER.Dispose();
   END Dispose;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE OnDeviceConnect();
   VAR
      result : Sync.TAsyncResult;
      value : iovalue.Value;
      pairs : ns.TPNameValuePairs;
   BEGIN
      EventSinks.OnConnect();

      RStatus := RStatus - TRStatus{rsInitReadRepeat, rsInitReadFinished} + TRStatus{rsInitReadPending};
      InitReadItems := 0;
      IF Objects.Count = 0 THEN
         InitReadFinished();
      ELSIF _CacheOnlyMode THEN
         InitReadFinished();
      ELSE
         IF ( _ForceReadPeriod > 0 ) AND ( _ReadersCount > 0 ) THEN
            StartTimer( tiForceRead, _ForceReadPeriod, TRUE );
         END;
         DoInitRead( FALSE );
      END;
      
      IF NOT DateAndTimeObjects.Empty THEN
         StartTimer( tiDateAndTime, _DateAndTimePushPeriod, TRUE );
         DoPushDateAndTime();
      END;
      
      IF _AdviseSource.AdviseListener <> NIL THEN
         Namespace.Get( StringsO.FromOA( namePathConnected ), OUT pairs );
         result := Sync.arCompleted;
         value.Boolean := TRUE;
         _AdviseSource.AdviseListener^.OnAdvise( ADR( SELF ), OA( 0, ADR( result )), OA( 0, ADR( pairs )), OA( 0, ADR( value )) );
      END;
   END OnDeviceConnect;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE OnDeviceDisconnect();
   VAR
      result : Sync.TAsyncResult;
      value : iovalue.Value;
      pairs : ns.TPNameValuePairs;
   BEGIN
      EventSinks.OnDisconnect();

      StopTimer( tiDateAndTime );
      StopTimer( tiForceRead );

      IF _AdviseSource.AdviseListener <> NIL THEN
         Namespace.Get( StringsO.FromOA( namePathConnected ), OUT pairs );
         result := Sync.arCompleted;
         value.Boolean := FALSE;
         _AdviseSource.AdviseListener^.OnAdvise( ADR( SELF ), OA( 0, ADR( result )), OA( 0, ADR( pairs )), OA( 0, ADR( value )) );
      END;
   END OnDeviceDisconnect;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE GetObject( CONST Address : knx_def.TAddress; OUT PObject : TPObject ) : BOOLEAN;
   VAR
      c : CARDINAL;
   BEGIN
      IF Objects.Count = 0 THEN
         RETURN FALSE;
      END;

      c := Address.GetGroupAddress1();
      IF Groups[ CARD16( c ) ] = 0FFFFH THEN
         RETURN FALSE;
      END;

      PObject := Objects[ CARDINAL( Groups[ CARD16( c ) ] ) ];
      RETURN TRUE;
   END GetObject;

//--------------------------------------------------------------------------------

   PROCEDURE FindObjectType( CONST ObjectTypeName : StringsO.IString; OUT ObjectType : TObjectType ) : BOOLEAN;
   VAR
      ptr : PTR;
   BEGIN
      IF ObjectTypes.Get( ObjectTypeName, OUT ptr ) THEN
         ObjectType := TObjectType( LOPTRLONGWORD( ptr ));
      ELSIF ObjectTypeName.EqualsOA( otnObject ) THEN
         ObjectType := TObjectType{ objtMultipleAddresses };
      ELSIF ObjectTypeName.EqualsOA( otnObjects ) THEN
         ObjectType := TObjectType{};
      ELSIF ObjectTypeName.EqualsOA( otnLoggedObject ) THEN
         ObjectType := TObjectType{ objtMultipleAddresses, objtLogNoChange };
      ELSIF ObjectTypeName.EqualsOA( otnLoggedObjects ) THEN
         ObjectType := TObjectType{ objtLogNoChange };
      ELSIF ObjectTypeName.EqualsOA( otnLoggedOnChangeObject ) THEN
         ObjectType := TObjectType{ objtMultipleAddresses, objtLogOnChange };
      ELSIF ObjectTypeName.EqualsOA( otnLoggedOnChangeObjects ) THEN
         ObjectType := TObjectType{ objtLogOnChange };
      ELSIF ObjectTypeName.EqualsOA( otnESFStrict ) THEN
         ObjectType := TObjectType{ objtESFStrict };
      ELSIF ObjectTypeName.EqualsOA( otnLoggedESFStrict ) THEN
         ObjectType := TObjectType{ objtESFStrict, objtLogNoChange };
      ELSIF ObjectTypeName.EqualsOA( otnESFAdapt ) THEN
         ObjectType := TObjectType{ objtESFAdapt };
      ELSIF ObjectTypeName.EqualsOA( otnLoggedESFAdapt ) THEN
         ObjectType := TObjectType{ objtESFAdapt, objtLogNoChange };
      ELSIF ObjectTypeName.EqualsOA( otnESFIgnore ) THEN
         ObjectType := TObjectType{ objtESFIgnore };
      ELSIF ObjectTypeName.EqualsOA( otnLoggedESFIgnore ) THEN
         ObjectType := TObjectType{ objtESFIgnore, objtLogNoChange };
      ELSE
         RETURN FALSE;
      END;
      
      RETURN TRUE;
   END FindObjectType;

//--------------------------------------------------------------------------------

   PROCEDURE FindBehaviour( CONST BehaviourName : StringsO.IString; VAR Priority : knx_def.TPriority; VAR Flags : knx_def.TA_ObjectFlags ) : BOOLEAN;
   VAR
      PBehaviour : TPBehaviour;
      b : BOOLEAN;
   BEGIN
      b := Behaviours.GetFirst( OUT PBehaviour );
      WHILE b DO
         IF PBehaviour^.Name = BehaviourName THEN
            Priority := PBehaviour^.Class;
            Flags := PBehaviour^.Flags;
            RETURN TRUE;
         END;
         b := Behaviours.NextOf( PBehaviour, OUT PBehaviour );
      END;
      IF BehaviourName.EqualsOA( bnReader ) THEN
         Flags := knx_def.TA_ObjectFlags{knx_def.aofCommunicated, knx_def.aofUpdate, knx_def.aofWritable, knx_def.aofInitRead, knx_def.aofForceRead};
      ELSIF BehaviourName.EqualsOA( bnTracker ) THEN
         Flags := knx_def.TA_ObjectFlags{knx_def.aofCommunicated, knx_def.aofUpdate, knx_def.aofWritable};
      ELSIF BehaviourName.EqualsOA( bnTracker2 ) THEN
         Flags := knx_def.TA_ObjectFlags{knx_def.aofCommunicated, knx_def.aofUpdate, knx_def.aofWritable, knx_def.aofInitRead};
      ELSIF BehaviourName.EqualsOA( bnTransmitter ) THEN
         Flags := knx_def.TA_ObjectFlags{knx_def.aofCommunicated, knx_def.aofTransmit};
      ELSIF BehaviourName.EqualsOA( bnTransmitterWithStatus ) THEN
         Flags := knx_def.TA_ObjectFlags{knx_def.aofCommunicated, knx_def.aofTransmit, knx_def.aofUpdate, knx_def.aofWritable};
      ELSIF BehaviourName.EqualsOA( bnTransmitterWithStatus2 ) THEN
         Flags := knx_def.TA_ObjectFlags{knx_def.aofCommunicated, knx_def.aofTransmit, knx_def.aofUpdate, knx_def.aofWritable, knx_def.aofInitRead};
      ELSIF BehaviourName.EqualsOA( bnTransmitterWithStatusCallback ) THEN
         Flags := knx_def.TA_ObjectFlags{knx_def.aofCommunicated, knx_def.aofTransmit, knx_def.aofUpdate, knx_def.aofWritable, knx_def.aofAdvise};
      ELSIF BehaviourName.EqualsOA( bnTransmitterWithStatusCallback2 ) THEN
         Flags := knx_def.TA_ObjectFlags{knx_def.aofCommunicated, knx_def.aofTransmit, knx_def.aofUpdate, knx_def.aofWritable, knx_def.aofAdvise, knx_def.aofInitRead};
      ELSIF BehaviourName.EqualsOA( bnServer ) THEN
         Flags := knx_def.TA_ObjectFlags{knx_def.aofCommunicated, knx_def.aofReadable};
      ELSIF BehaviourName.EqualsOA( bnConcentrator ) THEN
         Flags := knx_def.TA_ObjectFlags{knx_def.aofCommunicated, knx_def.aofReadable, knx_def.aofUpdate, knx_def.aofWritable};
      ELSIF BehaviourName.EqualsOA( bnSource ) THEN
         Flags := knx_def.TA_ObjectFlags{knx_def.aofCommunicated, knx_def.aofReadable, knx_def.aofTransmit};
      ELSE
         RETURN FALSE;
      END;
      Priority := knx_def.priorityNormal;
      RETURN TRUE;
   END FindBehaviour;

//--------------------------------------------------------------------------------

   PROCEDURE AddObject( Priority : knx_def.TPriority; Flags : knx_def.TA_ObjectFlags; Type : knx_def.TKNXType; ObjectType : TObjectType ) : TPObject;
   VAR
      PObject : TPObject;
   BEGIN
      IF _CacheOnlyMode THEN
         Flags := Flags - knx_def.TA_ObjectFlags{knx_def.aofCommunicated, knx_def.aofInitRead};
      END;
      IF knx_def.aofForceRead IN Flags THEN
         INC( _ReadersCount );
      END;

      NEW( PObject );
      PObject^.Server := ADR( SELF );
      PObject^.Init( KNX, Type, knx_user.obNone );
      PObject^.SetClass( Priority );
      PObject^.SetFlags( Flags );
      PObject^.ObjectType := ObjectType;
      
      Objects.Add( PObject );

      IF ObjectType * TObjectType{ objtDate, objtTime } <> TObjectType{} THEN
         DateAndTimeObjects.Add( PObject );
      END;

      RETURN PObject;
   END AddObject;

//--------------------------------------------------------------------------------

   PROCEDURE DoneObjects( NILExecutive : BOOLEAN );
   VAR
      EIT : knx_def.TKNXType;
      i : CARDINAL;
      PObject : TPObject;
   BEGIN
      FOR i := 0 TO Objects.Count - 1 DO
         PObject := TPObject( Objects[i] );
         IF NILExecutive THEN
            PObject^.PExecutive := NIL;
         END;
         DISPOSE( PObject );
      END;
      Objects.Dispose();
      DateAndTimeObjects.Dispose();
      IF NILExecutive THEN
         FOR EIT := knx_def.eitSwitch TO knx_def.eitString DO
           prObjects[EIT].PExecutive := NIL;
         END;
      END;
   END DoneObjects;

//--------------------------------------------------------------------------------

   LOCAL PROCEDURE ValueReadRequestSent( PObject : TPObject; CurrentState : knx_user.TObjectState );
   BEGIN
      IF PObject^.RSStatus <> knx_status.essOK THEN
         ValueRead( PObject, CurrentState, PObject^.InitReadState );
      END;
   END ValueReadRequestSent;

//--------------------------------------------------------------------------------

   LOCAL PROCEDURE ValueRead( PObject : TPObject; CurrentState : knx_user.TObjectState; CurrentInitReadState : knx_user.TInitReadState );
   VAR
      c : CARDINAL;
      ResponseAwaited : BOOLEAN;
   BEGIN
      IF knx_def.aofPromiscuous IN PObject^.GetFlags() THEN // promiscuous mode object, no need to count repeats or do init read
         RETURN;
      END;

      CASE PObject^.RSStatus OF
      //-----
      | knx_status.essOK :
         INCL( PObject^.Flags, knx_def.aofKNXValue );
      
      //-----
      | knx_status.essConError, // A_Read without L_ACK -- called from ValueReadRequestSent
        knx_status.essA_Timeout : // A_Read with L_ACK but without READ
         // -- handle repeating and delaying after error
         IF PObject^.ReadRepeatCount > 1 THEN
            DEC( PObject^.ReadRepeatCount );
         ELSIF INTEGER( PObject^.ReadRepeatCount ) = 1 THEN // finalize operation after all allowed counts
            DEC( PObject^.ReadRepeatCount );
            IF CurrentInitReadState = knx_user.irsPending THEN
               c := ReadOnStart.RecoveryTime;
            ELSE
               c := ReadDuringRun.RecoveryTime;
            END;
            IF c = 0 THEN
               PObject^.RecoveryExpiration := 0;
            ELSE
               PObject^.RecoveryExpiration := DateTime.UptimeMS() + c;
               IF PObject^.RecoveryExpiration = 0 THEN
                  PObject^.RecoveryExpiration := 1;
               END;
            END;
         END;
         // ++ handle repeating and delaying after error
      //-----
      END; // CASE

      // normal value read processing
      IF CurrentInitReadState = knx_user.irsPending THEN
         ResponseAwaited := TRUE;

         IF PObject^.RSStatus = knx_status.essOK THEN
            PObject^.InitReadState := knx_user.irsUnknown;
         ELSIF InitReadRepeat <= 1 THEN // repeated init read will not be performed, so notify error
            PObject^.InitReadState := knx_user.irsUnknown;
         ELSE
            ResponseAwaited := FALSE; // wait until all tries are done

            INCL( RStatus, rsInitReadRepeat );
            PObject^.InitReadState := knx_user.irsWillRepeat;
         END;
         
         DEC( InitReadItems );
         IF InitReadItems = 0 THEN
            InitReadFinished();
         END;

      ELSE
         ResponseAwaited := knx_user.osReading IN CurrentState;
      END;

      // for both osReading and osInitReadPending the reading must be announced by callback -- CW driver, e.g., can wait
      // with InputFinalized = FALSE, and if it does not receive asynchronous notification, it will never ask for value again   
      IF ResponseAwaited THEN
         EventSinks.OnRead( PObject );
      END;
   END ValueRead;

//--------------------------------------------------------------------------------

   LOCAL PROCEDURE ValueUpdated( Direction : IOO.TDirection; PObject : TPObject; CurrentState : knx_user.TObjectState );
   VAR
      address : ARRAY [0..31] OF WCHAR;
      asyncResult : Sync.TAsyncResult := Sync.arCompleted;
      comment : StringsO.CString;
      EValue : knx_def.CValue;
      io : iovalue.Value;
      logged : BOOLEAN;
      value : StringsO.CString;
      valuesConverted : BOOLEAN := FALSE;
   BEGIN
      IF knx_user.osReading IN CurrentState THEN // value is NOT OOB
         RETURN;
      ELSIF PObject^.RSStatus = knx_status.essOK THEN
         INCL( PObject^.Flags, knx_def.aofKNXValue );
      END;
      IF _Result^.Counted OR _Result^.Expired THEN
         RETURN;
      END;

      IF TObjectType{objtLogNoChange, objtLogOnChange} * PObject^.ObjectType = TObjectType{} THEN
         // pass down
      ELSIF ( objtLogNoChange IN PObject^.ObjectType ) OR // log always
            ( objtLogOnChange IN PObject^.ObjectType ) AND ( knx_user.osChanged IN CurrentState ) OR // log changes
            ( Direction = IOO.dirWrite ) AND NOT KNX^.DeviceConnected() THEN // always allow log failures

         valuesConverted := TRUE;
         PObject^.GetValue( OUT EValue, TRUE, FALSE );
         KNXValue2IOValue( EValue, PObject^.StringValue, OUT io );
         value := io.String;
         PObject^.SendAddress.GetGroupAddress3( TRUE, OUT address );

         comment := PObject^.Comment;
         IF NOT comment.Empty THEN
            comment.PrependOA( L"(" );
            comment.AppendOA( L")" );
         END;

         IF Direction = IOO.dirRead THEN
            _DataLogger^.LogSSSS( log.ldMessage, 0, L"srv", "UPDATE", address, OA( value.Length-1, value.Data ), OA( comment.Length-1, comment.Data ));
         ELSIF NOT KNX^.DeviceConnected() THEN
            IF _CacheOnlyMode THEN
               _DataLogger^.LogSSSS( log.ldMessage, 0, L"srv", "SET TO CACHE", address, OA( value.Length-1, value.Data ), OA( comment.Length-1, comment.Data ));
            ELSE
               _DataLogger^.LogSSSS( log.ldMessage, 0, L"srv", "SET FAILED", address, OA( value.Length-1, value.Data ), OA( comment.Length-1, comment.Data ));
            END;
         END;
                  
      END;
      
      IF knx_def.aofPromiscuous IN PObject^.GetFlags() THEN // promiscuous mode queueing

         IF Direction = IOO.dirRead THEN
            EnqueuePromiscuous( knx_status.essOK, PObject );
         END;

         IF _AdviseSource.AdviseListener <> NIL THEN
            IF NOT valuesConverted THEN
               PObject^.GetValue( OUT EValue, TRUE, FALSE );
               KNXValue2IOValue( EValue, PObject^.StringValue, OUT io );
            END;
            _AdviseSource.AdviseListener^.OnAdvise( ADR( SELF ), OA( 0, ADR( asyncResult )), OA( 0, ADR( PObject^.Pairs )), OA( 0, ADR( io )) );
         END;

      ELSE // oobData promiscuous mode queueing

         IF ( Direction = IOO.dirRead ) AND NOT EventSinks.Empty THEN
            QueueLock.Lock();
            IF oobData.Count >= InputQueueLength THEN
               QueueLock.Unlock();
               EventSinks.OnInputQueueOverflow( TRUE, FALSE );
               RETURN;
            END;
         END;

         IF NOT valuesConverted THEN
            PObject^.GetValue( OUT EValue, TRUE, FALSE );
            KNXValue2IOValue( EValue, PObject^.StringValue, OUT io );
         END;

         IF ( Direction = IOO.dirRead ) AND NOT EventSinks.Empty THEN
            oobData.EnqueueOA( EValue.Data, PObject );
            QueueLock.Unlock();

            EventSinks.OnInputQueueAdd( TRUE, FALSE );
         END;

         IF _AdviseSource.AdviseListener <> NIL THEN
            _AdviseSource.AdviseListener^.OnAdvise( ADR( SELF ), OA( 0, ADR( asyncResult )), OA( 0, ADR( PObject^.Pairs )), OA( 0, ADR( io )) );
         END;

      END;
   END ValueUpdated;

//--------------------------------------------------------------------------------

   LOCAL PROCEDURE ValueWritten( PObject : TPObject; CurrentState : knx_user.TObjectState );
   VAR
      address : ARRAY [0..31] OF WCHAR;
      comment : StringsO.CString;
      EValue : knx_def.CValue;
      io : iovalue.Value;
      value : StringsO.CString;
   BEGIN
      IF PObject^.WSStatus = knx_status.essOK THEN
         INCL( PObject^.Flags, knx_def.aofKNXValue );
      END;
      IF NOT EventSinks.Empty THEN
         IF knx_user.osWriting IN CurrentState THEN
            EventSinks.OnWritten( PObject );
         END;
         
         // in case of promiscuous mode report error
         IF ( PObject^.WSStatus <> knx_status.essOK ) AND ( knx_def.aofPromiscuous IN PObject^.GetFlags()) THEN
            EnqueuePromiscuous( PObject^.WSStatus, PObject );
         END;
      END;
      
      IF TObjectType{objtLogNoChange, objtLogOnChange} * PObject^.ObjectType = TObjectType{} THEN
         // pass down
      ELSIF ( objtLogNoChange IN PObject^.ObjectType ) OR // log always
            ( objtLogOnChange IN PObject^.ObjectType ) AND ( PObject^.ChangedOnWrite <> 0 ) OR // log changes
            ( PObject^.WSStatus <> knx_status.essOK ) THEN // always allow log errors

         PObject^.GetValue( OUT EValue, TRUE, FALSE );
         KNXValue2IOValue( EValue, PObject^.StringValue, OUT io );
         value := io.String;
         PObject^.SendAddress.GetGroupAddress3( TRUE, OUT address );

         comment := PObject^.Comment;
         IF NOT comment.Empty THEN
            comment.PrependOA( L"(" );
            comment.AppendOA( L")" );
         END;

         IF PObject^.WSStatus = knx_status.essOK THEN
            _DataLogger^.LogSSSS( log.ldMessage, 0, L"srv", "SET OK", address, OA( value.Length-1, value.Data ), OA( comment.Length-1, comment.Data ));
         ELSE
            _DataLogger^.LogSSSS( log.ldMessage, 0, L"srv", "SET ERROR", address, OA( value.Length-1, value.Data ), OA( comment.Length-1, comment.Data ));
         END;
                  
      END;

      IF knx_def.aofAdvise IN PObject^.GetFlags() THEN
         ValueUpdated( IOO.dirRead, PObject, CurrentState );
      END;
   END ValueWritten;

//--------------------------------------------------------------------------------

   PRIVATE PROCEDURE EnqueuePromiscuous( Status : knx_status.TKNXStackStatus; PObject : TPObject );
   VAR
      EValue : knx_def.CValue;
      prItem : PromiscuousData;
   BEGIN
      IF EventSinks.Empty THEN
         RETURN;
      END;

      QueueLock.Lock();
      IF prData.Count >= InputQueueLength THEN
         QueueLock.Unlock();
         EventSinks.OnInputQueueOverflow( FALSE, TRUE );
         RETURN;
      END;
      
      prItem.Status := Status;
      prItem.Address := PObject^.PromiscuousAddress;
      PObject^.GetValue( OUT prItem.Value, TRUE, FALSE );
      
      prData.EnqueueOA( prItem, 0 );
      INCL( RStatus, rsPromiscuousInQueue );
      QueueLock.Unlock();

      EventSinks.OnInputQueueAdd( FALSE, TRUE );
   END EnqueuePromiscuous;
         
//--------------------------------------------------------------------------------

   PROCEDURE InitToDefault();
   BEGIN
      ConfigurationPath.Clear();
      DeviceId := MAX( CARDINAL );
      PromiscuousMode := FALSE;
      InputQueueLength := 256;
      Address.SetPhysicalAddress1( 0 );
      ACKTimeout := 500;
      BUSYDelay := 200;
      SendDelay := 0;
      WriteDelay := 0;
      IgnoreRepeated := TRUE;
      InitReadRepeatDelay := 5000;
      InitReadRepeatCount := 3;
      TimeAsString := FALSE;
      DateAsString := FALSE;
      WITH ReadOnStart DO
         Timeout := 1500;
         RepeatCount := 1;
         Delay := 150;
         RecoveryTime := 1000;
      END;
      WITH ReadDuringRun DO
         Timeout := 2500;
         RepeatCount := 1;
         Delay := 0;
         RecoveryTime := 0;
      END;
      DoneObjects( TRUE );
      Behaviours.Dispose();
      _ForceReadPeriod := 0;
      _ReadersCount := 0;
      _DateAndTimePushPeriod := 1800000;
      IF KNX <> NIL THEN
         KNX^.Done();
         DISPOSE( KNX );
      END;
      Storage.Fill( ADR( Groups ), SIZE( Groups ), 0FFH );
   END InitToDefault;

//--------------------------------------------------------------------------------

   PROCEDURE DoInitRead( RepeatFlag : BOOLEAN );
   VAR
      EV : knx_def.TValue;
      i : CARDINAL;
      PObject : TPObject;
      saddr : ARRAY [0..63] OF WCHAR;
   BEGIN
      IF NOT RepeatFlag THEN
         InitReadRepeat := InitReadRepeatCount;
      END;

      LockObjects();
      FOR i := 0 TO Objects.Count - 1 DO
         PObject := TPObject( Objects[i] );
         IF NOT RepeatFlag AND ( knx_def.aofInitRead IN PObject^.GetFlags()) OR
                RepeatFlag AND ( PObject^.InitReadState = knx_user.irsWillRepeat ) THEN

            IF NOT Logger.FilteredFastCheck( log.ldTrace, 0 ) THEN
               PObject^.ReadAddress.GetGroupAddress3( TRUE, saddr );
               Logger.LogSS( log.ldTrace, 0, L"srv", "INIT: ", saddr );
            END;

            INC( InitReadItems );
            PObject^.InitReadState := knx_user.irsPending;
            PObject^.ReadRepeatCount := ReadOnStart.RepeatCount;
            PObject^.GetValue( OUT EV, FALSE, TRUE );
         END;
      END; // FOR
      UnlockObjects();

   END DoInitRead;

//--------------------------------------------------------------------------------

   PROCEDURE DoForceRead();
   VAR
      EV : knx_def.TValue;
      i : CARDINAL;
      PObject : TPObject;
      saddr : ARRAY [0..63] OF WCHAR;
   BEGIN
      IF _ReadersCount > 0 THEN // redundant check

         LockObjects();

         FOR i := 0 TO Objects.Count - 1 DO
            PObject := TPObject( Objects[i] );
            IF knx_def.aofForceRead NOT IN PObject^.GetFlags() THEN
               CONTINUE;
            END;

            IF NOT Logger.FilteredFastCheck( log.ldTrace, 0 ) THEN
               PObject^.ReadAddress.GetGroupAddress3( TRUE, saddr );
               Logger.LogSS( log.ldTrace, 0, L"srv", "READER: ", saddr );
            END;

            PObject^.GetValue( OUT EV, FALSE, TRUE );
         END;

         UnlockObjects();

      END;
   END DoForceRead;

//--------------------------------------------------------------------------------

   PRIVATE PROCEDURE DoPushDateAndTime();
   VAR
      b : BOOLEAN;
      Day : knx_def.TDay;
      DT : DateTime.DateTime;
      EVDate : knx_def.TValue;
      EVTime : knx_def.TValue;
      i : INTEGER;
      PObject : TPObject;
   BEGIN
      IF DateAndTimeObjects.Empty THEN
         RETURN;
      END;

      DT.SetNowLocal();
      EVDate.SetDate( DT.Year, DT.Month, DT.Day );
      Day := knx_def.TDay( 1 + ( CARDINAL( DT.DayOfWeek ) + 6 ) MOD 7 );
      EVTime.SetTime( Day, DT.Hour, DT.Minute, DT.Second );

      FOR i := 0 TO DateAndTimeObjects.Count -1 DO;
         PObject := DateAndTimeObjects[i];
         IF objtDate IN PObject^.ObjectType THEN
            PObject^.SetValue( EVDate, OUT b );
         ELSIF objtTime IN PObject^.ObjectType THEN
            PObject^.SetValue( EVTime, OUT b );
         END;
      END; // WHILE
   END DoPushDateAndTime;

//--------------------------------------------------------------------------------

   PROCEDURE InitReadFinished();
   BEGIN
      IF NOT( rsInitReadRepeat IN RStatus ) THEN
         RStatus := RStatus - TRStatus{rsInitReadPending} + TRStatus{rsInitReadFinished};
         KNX^.SetTimeout( knx_stack.tidA_PendingDelay, ReadDuringRun.Delay, knx_stack.pendingGroupRead );
         KNX^.SetTimeout( knx_stack.tidA_PendingTimeout, ReadDuringRun.Timeout, knx_stack.pendingGroupRead );
         StopTimer( tiInitReadDelay );
         EventSinks.OnInitReadCompleted();
      ELSIF InitReadRepeat <= 1 THEN
         InitReadRepeat := 0;
         EXCL( RStatus, rsInitReadRepeat );
         InitReadFinished();
      ELSE
         DEC( InitReadRepeat );
         RStatus := RStatus - TRStatus{rsInitReadRepeat};
         StartTimer( tiInitReadDelay, InitReadRepeatDelay, FALSE );
      END;
   END InitReadFinished;

//--------------------------------------------------------------------------------

   LOCAL PROCEDURE LockObjects();
   BEGIN
      ObjectLock.Lock();
   END LockObjects;

//--------------------------------------------------------------------------------

   LOCAL PROCEDURE UnlockObjects();
   BEGIN
      ObjectLock.Unlock();
   END UnlockObjects;

//--------------------------------------------------------------------------------

   LOCAL PROCEDURE IOValue2KNXValue( CONST Value : iovalue.Value; DestEVType : knx_def.TKNXType; OUT EV : knx_def.TValue; OUT SupportingStringData : StringsO.IString );
   VAR
      c : CARDINAL;
      Day : knx_def.TDay;
      DT : DateTime.DateTime;
      fd : CARDINAL;
      H, M, S, WD : CARDINAL;
      i : INTEGER;
      s : knx_def.TEISStringW;
      so : StringsO.CString;
      Y, MM, D : INTEGER;
   BEGIN
      EV.SetType( DestEVType );

      CASE EV.GetType() OF
      | knx_def.eitUnknown :
         RETURN;

      | knx_def.eitSwitch :
         EV.SetSwitch( Value.Boolean );

      | knx_def.eitIncrease :
         i := Value.Integer;
         IF i = 0 THEN
            EV.SetIncrease( FALSE, FALSE, 0 );
         ELSIF i < 0 THEN
            EV.SetIncrease( FALSE, TRUE, CARDINAL( -i ));
         ELSE
            EV.SetIncrease( TRUE, FALSE, CARDINAL( i ));
         END;

      | knx_def.eitTime :
         IF TimeAsString THEN
            so := Value.String;
            IF TimeFormat.Empty THEN
               IF NOT DT.FromStringOA( OA( so.Length-1, so.Data ), L"HH:mm:ss" ) THEN
                  Logger.LogSSSS( log.ldError, 0, L"srv", L"string to time conversion failure: ", OA( so.Length-1, so.Data ), L", format: HH:mm:ss", L"" );
               END;
            ELSE
               IF NOT DT.FromStringOA( OA( so.Length-1, so.Data ), OA( TimeFormat.Length-1, TimeFormat.Data )) THEN
                  Logger.LogSSSS( log.ldError, 0, L"srv", L"string to time conversion failure: ", OA( so.Length-1, so.Data ), L", format: ", OA( TimeFormat.Length-1, TimeFormat.Data ));
               END;
            END;
            WD := 0;
            H := DT.Hour;
            M := DT.Minute;
            S := DT.Second;
         ELSE
            c := Value.Integer;
            WD := c DIV 100000;
            c := c - WD * 100000;
            H := c DIV 3600;
            c := c - H * 3600;
            M := c DIV 60;
            S := c MOD 60;
         END;
         CASE WD OF
         | 0 :
            DT.SetNowLocal();
            Day := knx_def.TDay( 1 + ( CARDINAL( DT.DayOfWeek ) + 6 ) MOD 7 );
         | 1..7 :
            Day := knx_def.TDay( WD );
         ELSE
            Day := knx_def.dayNo;
         END;
         EV.SetTime( Day, H, M, S );

      | knx_def.eitDate :
         IF DateAsString THEN
            so := Value.String;
            IF DateFormat.Empty THEN
               IF NOT DT.FromStringOA( OA( so.Length-1, so.Data ), L"yyyy-MM-dd" ) THEN
                  Logger.LogSSSS( log.ldError, 0, L"srv", L"string to date conversion failure: ", OA( so.Length-1, so.Data ), L", format: yyyy-MM-dd", L"" );
               END;
            ELSE
               IF NOT DT.FromStringOA( OA( so.Length-1, so.Data ), OA( DateFormat.Length-1, DateFormat.Data )) THEN
                  Logger.LogSSSS( log.ldError, 0, L"srv", L"string to date conversion failure: ", OA( so.Length-1, so.Data ), L", format: ", OA( DateFormat.Length-1, DateFormat.Data ));
               END;
            END;
            Y := DT.Year;
            MM := DT.Month;
            D := DT.Day;
         ELSE
            DateTime.iJD( Value.Date, OUT Y, OUT MM, OUT D, OUT fd );
         END;
         EV.SetDate( Y, MM, D );

      | knx_def.eitValue, knx_def.eitValueRange :
         EV.SetValue( Value.Float );

      | knx_def.eitScaling :
         EV.SetScaling( MIN2( 100, Value.LimitedInteger( 8, FALSE, TRUE )));

      | knx_def.eitScaling255 :
         EV.SetScaling255( CARD8( Value.LimitedInteger( 8, FALSE, TRUE )));

      | knx_def.eitMove :
         EV.SetMove( Value.Boolean );

      | knx_def.eitPriority :
         EV.SetPriority( Value.LimitedInteger( 2, FALSE, TRUE ));

      | knx_def.eitFloat :
         EV.SetFloat( Value.Float );

      | knx_def.eit16bit :
         EV.Set16bit( Value.LimitedInteger( 16, FALSE, TRUE ));

      | knx_def.eit32bit :
         EV.Set32bit( Value.Integer );

      | knx_def.eitChar :
         EV.SetChar( Value.String[0] );

      | knx_def.eit8bit :
         EV.Set8bit( Value.LimitedInteger( 8, FALSE, TRUE ));

      | knx_def.eitString :
         SupportingStringData.Assign( Value.String );
         SupportingStringData.ToOA( OUT s );
         EV.SetString( s );
      END; // CASE EV.Type

   END IOValue2KNXValue;

//--------------------------------------------------------------------------------

   LOCAL PROCEDURE KNXValue2IOValue( CONST EV : knx_def.TValue; CONST SupportingStringData : StringsO.IString; OUT Value : iovalue.Value );
   VAR
      c : CARDINAL;
      Day : knx_def.TDay;
      dt : DateTime.DateTime;
      s : ARRAY [0..255] OF WCHAR;
      Y, M, D, H, S : CARDINAL;
      b1 : BOOLEAN;
      b2 : BOOLEAN;
   BEGIN

      CASE EV.GetType() OF
      | knx_def.eitUnknown :
         ASSERT( FALSE );
         Value.Boolean := FALSE;

      | knx_def.eitSwitch :
         Value.Boolean := EV.GetSwitch();

      | knx_def.eitIncrease :
         c := EV.GetIncrease( b1, b2 );
         IF b1 THEN
            Value.Integer := INTEGER( c );
         ELSIF b2 THEN
            Value.Integer := -INTEGER( c );
         ELSE
            Value.Integer := 0;
         END;

      | knx_def.eitTime :
         EV.GetTime( Day, H, M, S );
         IF TimeAsString THEN
            dt.Hour := H;
            dt.Minute := M;
            dt.Second := S;
            IF TimeFormat.Empty THEN // use default format
               b1 := dt.ToStringOA( L"HH:mm:ss", FALSE, TRUE, OUT s );
            ELSE
               b1 := dt.ToStringOA( OA( TimeFormat.Length-1, TimeFormat.Data ), FALSE, TRUE, OUT s );
            END;
            IF b1 THEN
               Value.String := StringsO.FromOA( s );
            ELSE
               Value.String := StringsO.Empty();
            END;
         ELSE
            Value.Integer := CARDINAL( Day ) * 100000 + ( H * 60 + M ) * 60 + S;
         END;

      | knx_def.eitDate :
         EV.GetDate( Y, M, D );
         IF DateAsString THEN
            dt.Year := Y;
            dt.Month := M;
            dt.Day := D;
            IF DateFormat.Empty THEN
               b1 := dt.ToStringOA( L"yyyy-MM-dd", TRUE, FALSE, OUT s );
            ELSE
               b1 := dt.ToStringOA( OA( DateFormat.Length-1, DateFormat.Data ), TRUE, FALSE, OUT s );
            END;
            IF b1 THEN
               Value.String := StringsO.FromOA( s );
            ELSE
               Value.String := StringsO.Empty();
            END;
         ELSE
            Value.Date := DateTime.JD( Y, M, D, 0 );
         END;

      | knx_def.eitValue, knx_def.eitValueRange :
         Value.Float := EV.GetValue();

      | knx_def.eitScaling :
         Value.Integer := EV.GetScaling();

      | knx_def.eitScaling255 :
         Value.Integer := EV.GetScaling255();

      | knx_def.eitMove :
         Value.Boolean := EV.GetMove();
      
      | knx_def.eitPriority :
         Value.Integer := EV.GetPriority();

      | knx_def.eitFloat :
         Value.Float := EV.GetFloat();

      | knx_def.eit16bit :
         Value.Integer := EV.Get16bit();

      | knx_def.eit32bit :
         Value.Integer := EV.Get32bit();

      | knx_def.eitChar :
         Value.Type := iovalue.vtString;
         Value.String := StringsO.FromOA( EV.GetChar());

      | knx_def.eit8bit :
         Value.Integer := EV.Get8bit();

      | knx_def.eitString :
         Value.FromString( SupportingStringData, FALSE );

      END; // CASE EV.Type

   END KNXValue2IOValue;

//--------------------------------------------------------------------------------

BEGIN
   RStatus := TRStatus{};
   Stack := stackUnknown;
   _CacheOnlyMode := FALSE;

   DeviceId := MAX( CARDINAL );
   PromiscuousMode := FALSE;
   InputQueueLength := 256;
   ACKTimeout := 500;
   BUSYDelay := 200;
   SendDelay := 0;
   WriteDelay := 0;
   IgnoreRepeated := TRUE;
   InitReadRepeatDelay := 5000;
   InitReadRepeatCount := 3;
   InitReadRepeat := 0;
   TimeAsString := FALSE;
   DateAsString := FALSE;
   Groups[0] := 0FFH; // satisfy initialization warning

   KNX := NIL;
   Sink.Server := ADR( SELF );
   EventSinks.SinkType := RTTI( IKNXServerSink );
   _Result := NIL;
   _DataLogger := NIL;

   Logger.Level := Log.ldDebug;
   Logger.Output := log.outsNone; // redirect all to Log.logger()
   Logger.AddOutput( Log.logger());
   Log.ConfigureByRegistry( REF Logger, LIBRARY );
   Logger.SetName( L"KNX" );
   
   _ForceReadPeriod := 0;
   _ReadersCount := 0;
   _DateAndTimePushPeriod := 0;

   ObjectLock.Init( Sync.ltCS, L"", FALSE );
   QueueLock.Init( Sync.ltSpin, L"", FALSE );
   
   InitReadItems := 0;
   oobData.ItemType := lists.blitSlot32;
   prData.ItemType := lists.blitSlot64;
   ASSERT( SIZE( PromiscuousData ) < 64 );
FINALLY
   Dispose();
END CKNXServer;

//================================================================================

END knxcore.
