IMPLEMENTATION MODULE srvcore;

FROM Exceptions IMPORT
   TestIfCatched, RetrieveException;

(*# call( o_a_copy => off ) *)

//================================================================================
(*/* changes:

21.10.2007 -- started to split to core/svc/driver
01.09.2007 -- started with SDAP/Server
--.08.2007 -- checked operations, EIB network code complete
26.07.2007 -- first alpha, unchanged sources, started removing abundant code
12.07.2007 -- started to connect EIBNetStack
 4.07.2007 -- changes to EIBServer and new m2
10.03.2007 -- mii V2.7, build >= ???, added promiscuos mode and groups handling  
18.06.2006 -- started falcon
 3.05.2006 -- V2.6, build >= 498
                -- corrected eis4 (date) bug, see eib_def
 2.06.2005 -- V2.5, build >= 496
                -- added WriteQueueLength, SendDelay, WriteDelay parameters
                -- added WriteDelay handling code
                -- added GetChannelDescription
                -- added reading comment and id from PAR
18.05.2005 -- V2.4, build >= 454
                -- corrected status channel schiInitReadPending bit -- it was not cleared
15.03.2005 -- V2.3, build >
                -- in stack, added clearing of osReading into errornenous ValueReadRequestSent -- such request stops reading
                -- updated ActiveX to be more friendly if ReadInputs/WriteOutputs returns csPending -- it continues after Notify* itself
24.02.2005 -- V2.2, build >= 437
                -- ActiveX control enhanced, OOB data handling addition
17.02.2005 -- V2.1, build >= 420
16.02.2005 -- added watchdog handling
11.02.2005 -- corrected eitChar, eitString -- they did not work for ANSI driver interface
 7.02.2005 -- V2.0, build >= 368
                -- eibusb: corrected sending of LL_Config -- the device can be in rBusy state after init and this
                     response MUST be handled as correct
 3.02.2005 -- corrected T_Connect/T_Disconnect bug -- this occurred if duplicite PH address appeared in network or
                     if somebody tried to connect me
                -- changed behaviour of reception of repeated packets -- they are accepted, even if they are repeated and repeat
                     packet are filtered, if the new packet carries new (yet unknown) data
                -- added delaying of transmission/retransmission of packets not accepted by device due to rBusy
                -- added Input/OutputQueueLengthChannels
                -- added repeating of unread init_read objects
                -- corrected behaviour of NAK read requests -- they were never repeated nor they were never detected as unread init_read item
20.12.2004 -- V1.8. build >= 302
                -- corrected bug caused that status channel was not enumerated
10.12.2004 -- V1.7, build >= 282
                -- modified eibusb.mod to report F0: errors
30.11.2004 -- V1.6, build >= 268
                -- modified StringToSingleObject to store in PGroups only the first address of an object
19.11.2004 -- V1.5, build >= 267
                -- removed QChecks, added ActiveX support, added CW2K API (version 30000H and dummy exported symbols)
 2.11.2004 -- V1.4, build >= 237
                -- added LineBusy, TransceiverFault errors and OutputQueueLength parameter
27.10.2004 -- added delays between read operations
19.10.2004 -- V1.3, build
                -- added remap of status L_Con_Timeout to LCON error code
17.10.2004 -- modified HWConnected, but it should be analyzed more...
15.10.2004 -- added RSStatus handling into ValueWritten
 4.10.2004 -- added INCL( aofEIBValue ) into ValueUpdated for success
23.09.2004 -- removed RSStatus = essOK from input OOBData. The place is bad,
                     OOB data must be read without changing error -- error during init
                     read must be reported too.
                -- changed Driver.ValueRead to notify init read error using OOB (osInitReadPending)
19.09.2004 -- V1.2, build
                -- added RSStatus = essOK into input OOBData. This allows continuing of communication
                     of element, which was not properly read during init_read phase. Without
                     setting essOK the driver does not read the element anymore.
                -- removed duplicity of errors of explicit reading -- UNACKED and TIMEOUT errors
                     appeared both. After change in EIBSTACK this dissapeared.

*/*)
//================================================================================

FROM Debug IMPORT
   Assertion;

IMPORT
   DateTime,
   FIO,
   FIOO,
   IOO,
   Log,
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
   eibnetstack;

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
   itemSystemSuspend = 1;
   itemSystemSerialNumber = 2;
   itemConnected = 3;
   nameSystemSuspend = L".System.Licensing.Suspend";
   nameSystemSerialNumber = L"System.Licensing.SerialNumber";
   nameConnected = L"Control.Connected";
   suspendKey = L"suspend";
   suspendValue = L"true";

//================================================================================

CONST
   tiInitReadDelay = 67;
   tiForceRead = 69;
   
//-----

TYPE
   TPBehaviour = POINTER TO CBehaviour;

CLASS CBehaviour( list.CListElem );
   Class : eib_def.TPriority;
   Flags : eib_def.TA_ObjectFlags;
   Name  : StringsO.CString;
END CBehaviour;

//-----

TYPE
   TStatusChannelItem = (
      schiUSBConnected,
      schiEIBConnected,
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

PROCEDURE LogNumber2Address( LogNumber : CARDINAL; VAR Address : eib_def.CAddress );
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
   Flags := eib_def.TA_ObjectFlags{};
   Class := eib_def.priorityNormal;
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

   INTERNAL VIRTUAL PROCEDURE ValueReadRequestSent( Status : eib_status.TEIBStackStatus; CurrentState : eib_user.TObjectState );
   BEGIN
      RSStatus := Status;
      Server^.ValueReadRequestSent( ADR( SELF ), CurrentState );
   END ValueReadRequestSent;

//--------------------------------------------------------------------------------

   INTERNAL VIRTUAL PROCEDURE ValueRead( Status : eib_status.TEIBStackStatus; CurrentState : eib_user.TObjectState; CurrentInitReadState : eib_user.TInitReadState );
   BEGIN
      RSStatus := Status;
      Server^.ValueRead( ADR( SELF ), CurrentState, CurrentInitReadState );
   END ValueRead;

//--------------------------------------------------------------------------------

   INTERNAL VIRTUAL PROCEDURE ValueUpdated( Status : eib_status.TEIBStackStatus; CurrentState : eib_user.TObjectState );
   BEGIN
      RSStatus := Status;
      Server^.ValueUpdated( IOO.dirRead, ADR( SELF ), CurrentState );
   END ValueUpdated;

//--------------------------------------------------------------------------------

   INTERNAL VIRTUAL PROCEDURE ValueWritten( Status : eib_status.TEIBStackStatus; CurrentState : eib_user.TObjectState );
   BEGIN
      WSStatus := Status;
      Server^.ValueWritten( ADR( SELF ), CurrentState );
      IF ( Status = eib_status.essOK ) AND ( eib_def.TA_ObjectFlags{eib_def.aofForceRead, eib_def.aofWritable} * GetFlags() = eib_def.TA_ObjectFlags{eib_def.aofWritable} ) THEN
         // element always read from EIB cannot be reset for reading;
         // only writable elements can be reset for reading too
         RSStatus := eib_status.essOK;
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
      sa : eib_def.CAddress;
   BEGIN
      sa := SendAddress;
      IF sa.GetAddressType() = eib_def.addressUnknown THEN
         RETURN -1;
      ELSIF sa.GetAddressType() = eib_def.addressGroup2 THEN
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
   RSStatus := eib_status.essOK;
   WSStatus := eib_status.essOK;
   ReadRepeatCount := 1;
   RecoveryExpiration := 0;
END CObject;

//================================================================================

CLASS IMPLEMENTATION PromiscuousData;
BEGIN
   Status := eib_status.essOK;
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

CLASS IMPLEMENTATION CSuspendableResult;

//--------------------------------------------------------------------------------

   PUBLIC PROPERTY Expired GET : BOOLEAN;
   BEGIN
      IF _Suspended THEN
         RETURN TRUE;
      ELSE
         RETURN SUPER.Expired;
      END;
   END Expired;

//--------------------------------------------------------------------------------

   PUBLIC PROPERTY Suspended GET : BOOLEAN;
   BEGIN
      RETURN _Suspended;
   END Suspended;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE QuerySuspension();
   VAR
      value : StringsO.CString;
   BEGIN
      ProductsLock();
      ProductsReset();
      WHILE ProductsMoveNext() DO
         IF CurrentProduct^.Info^.GetOA( suspendKey, OUT value ) THEN
            _Suspended := value.EqualsOA( suspendValue );
         END;
      END;
      ProductsUnlock();
   END QuerySuspension;

//--------------------------------------------------------------------------------

BEGIN
   _Suspended := FALSE;
END CSuspendableResult;

//================================================================================

CLASS IMPLEMENTATION CEIBServer;

//--------------------------------------------------------------------------------

   PUBLIC PROPERTY PResult GET : POINTER TO CSuspendableResult;
   BEGIN
      RETURN ADR( Result );
   END PResult;

//--------------------------------------------------------------------------------

   PUBLIC PROPERTY cllvData SET( Value : ADDRESS );
   BEGIN
      cllvdata := Value;
   END cllvData;

//--------------------------------------------------------------------------------

   PUBLIC PROPERTY cllvLength SET( Value : CARDINAL );
   BEGIN
      cllvlength := Value;
   END cllvLength;

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
      ELSIF TimerId = tiForceRead THEN
         DoForceRead();
      END;
   END OnTimer;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL READONLY PROPERTY Type GET : iobject.TObjectType;
   BEGIN
      RETURN iobject.otEphemeral
   END Type;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROPERTY Library GET : iobject.TPLibrary;
   BEGIN
      RETURN NIL;
   END Library;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROPERTY Library SET( Value : iobject.TPLibrary );
   BEGIN
   END Library;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE OnDispose(); // here meant also as a Command
   BEGIN
      Dispose();
   END OnDispose;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROPERTY DeviceCapabilities GET : device.TCapabilities;
   BEGIN
      RETURN device.TCapabilities{};
   END DeviceCapabilities;

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

   PUBLIC VIRTUAL PROCEDURE Mapper() : ns.TPMapper;
   BEGIN
      RETURN ADR( SELF );
   END Mapper;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE NS() : ns.TPns;
   BEGIN
      RETURN NIL;
   END NS;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE IO() : io.TPIO;
   BEGIN
      RETURN ADR( SELF );
   END IO;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE NameToHash( CONST Name : StringsO.IString; OUT Hash : ns.THash ) : BOOLEAN;
   VAR
      address : eib_def.TAddress;
      PObject : TPObject;
   BEGIN
      IF Name.EqualsOA( nameSystemSuspend ) THEN
         Hash := itemSystemSuspend;
         RETURN TRUE;
      ELSIF Name.EqualsOA( nameConnected ) THEN
         Hash := itemConnected;
         RETURN TRUE;
      ELSIF Name.EqualsOA( nameSystemSerialNumber ) THEN
         Hash := itemSystemSerialNumber;
         RETURN TRUE;
      END;
      address.SetGroupAddress3( OA( Name.Length-1, Name.Data ));
      IF NOT GetObject( address, OUT PObject ) THEN
         RETURN FALSE;
      END;
      Hash := PObject;
      RETURN TRUE;
   END NameToHash;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE HashToName( CONST Hash : ns.THash; OUT Name : StringsO.IString ) : BOOLEAN;
   VAR
      address : eib_def.TAddress;
      PObject : TPObject;
      s : ARRAY [0..31] OF WCHAR;
   BEGIN
      IF Hash = NIL THEN
         RETURN FALSE;
      ELSIF Hash = itemSystemSuspend THEN
         RETURN FALSE;
      ELSIF Hash = itemConnected THEN
         Name.FromOA( nameConnected );
         RETURN TRUE;
      ELSIF Hash = itemSystemSerialNumber THEN
         Name.FromOA( nameSystemSerialNumber );
         RETURN TRUE;
      END;
      address := TPObject( Hash )^.SendAddress;
      IF GetObject( address, OUT PObject ) THEN
         address.GetGroupAddress3( TRUE, OUT s );
         Name.FromOA( s );
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END HashToName;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROPERTY IOCapabilities GET : io.TCapabilities;
   BEGIN
      RETURN io.TCapabilities{io.capAdvise};
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
         RETURN ( rsRunning IN RStatus ) AND ( EIB <> NIL ) AND EIB^.DeviceConnected();
      END;
   END Running;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROPERTY Advise GET : io.TAdvise;
   BEGIN
      RETURN _Advise;
   END Advise;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROPERTY Advise SET( Value : io.TAdvise );
   BEGIN
      _Advise := Value;
   END Advise;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROPERTY AdviseListener GET : io.TPIAdviseInfo;
   BEGIN
      RETURN _AdviseListener;
   END AdviseListener;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROPERTY AdviseListener SET( Value : io.TPIAdviseInfo );
   BEGIN
      _AdviseListener := Value;
   END AdviseListener;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE Start() : Sync.TAsyncResult;
   VAR
      s : FIO.PathStrW := L"";
   BEGIN
      IF rsRunning IN RStatus THEN
         RETURN Sync.arCompleted;
      ELSIF EIB = NIL THEN
         RETURN Sync.arCannotStart;
      ELSE
         INCL( RStatus, rsRunning );
      END;
   
      Result.Reset( lec.bhBestCase );
      IF rsEXEFlag IN RStatus THEN
         FIO.GetModuleDirW( L"", OUT s );
      ELSE
         FIO.GetModuleDirW( EMITW( %dll ), OUT s );
      END;
      ASSERT( cllvdata <> NIL );
      IF cllvdata <> NIL THEN
         lec.QueryData( s, L"", cllvdata, cllvlength, REF Result );
         Result.QuerySuspension();
      END;

      IF _CacheOnlyMode THEN
         OnDeviceConnect();
      ELSE
         StopTimer( tiForceRead );
         StopTimer( tiInitReadDelay );
         EXCL( RStatus, rsInitReadFinished );
         EIB^.Connect();
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
         IF EIB <> NIL THEN
            EIB^.Disconnect();
         END;
      END;
   END Stop;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE IOh( CONST Originator : io.TPOriginator; Direction : IOO.TDirection; Item : ns.THash; REF Value : iovalue.Value; Callback : io.TPDataInfo ) : Sync.TAsyncResult;
   VAR
      address : ARRAY [0..63] OF WCHAR;
      description : StringsO.CString;
      EV : eib_def.CValue;
      changed : BOOLEAN;
      key, value : StringsO.CString;
      licences : lists.CStringList;
      PObject : TPObject;
      ptrType : PTR;
      s : FIO.PathStrW;
   BEGIN
      // system suspend must be processed before expiration check
      IF Item = itemSystemSuspend THEN
         IF rsEXEFlag IN RStatus THEN
            FIO.GetModuleDirW( L"", OUT s );
         ELSE
            FIO.GetModuleDirW( EMITW( %dll ), OUT s );
         END;
         ASSERT( cllvdata <> NIL );
         IF cllvdata <> NIL THEN
            key.FromOA( suspendKey );
            value := Value.String;
            lec.StoreInfo( s, cllvdata, cllvlength, key, value );
            ASSERT( cllvdata <> NIL );
            IF cllvdata <> NIL THEN
               lec.QueryData( s, L"", cllvdata, cllvlength, REF Result );
               Result.QuerySuspension();
            END;
         END;
         RETURN Sync.arCompleted;

      ELSIF Item = itemSystemSerialNumber THEN
         Result.GetLicences( OUT licences );
         IF NOT licences.GetFirst( OUT value, OUT ptrType ) THEN
            value.Clear();
         END;
         Value.String := value;
         RETURN Sync.arCompleted;
      END;
      
      IF Result.Counted OR Result.Expired THEN
         RETURN Sync.arCannotStart;
      END;
      
      IF Item = itemConnected THEN
         IF Direction = IOO.dirRead THEN
            Value.Boolean := _CacheOnlyMode OR ( EIB <> NIL ) AND EIB^.EIBConnected();
            RETURN Sync.arCompleted;
         ELSE
            RETURN Sync.arCannotStart;
         END;
      END;
      
      PObject := TPObject( Item );
      IF Direction = IOO.dirRead THEN
         PObject^.GetValue( OUT EV, TRUE, FALSE );
         EIBValue2IOValue( EV, OUT Value );

      ELSE // dirWrite
      
         IOValue2EIBValue( Value, PObject^.Type, OUT EV );
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
            ValueUpdated( IOO.dirWrite, PObject, PObject^.CommunicationState + eib_user.TObjectState{eib_user.osChanged} );
         ELSE
            PObject^.ChangedOnWrite := 0;
            // for notification using EventSink, if it exists
            ValueUpdated( IOO.dirWrite, PObject, PObject^.CommunicationState );
         END;
      END;

      IF EIB^.DeviceConnected() THEN
         RETURN Sync.arCompleted;
      ELSE
         RETURN Sync.arCompletedFromCache;
      END;
   END IOh;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE IOha( CONST Originator : io.TPOriginator; Direction : IOO.TDirection; Item : ARRAY OF ns.THash; REF Value : ARRAY OF iovalue.Value; Callback : io.TPDataInfo ) : Sync.TAsyncResult;
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
      ELSIF EIB = NIL THEN
         // fall down
      ELSIF EIB^.GetParameter( L"link.connection", OUT connection ) THEN
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
         kvEIBNet            = L'eibnet';
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
   
      PROCEDURE AddGroup( CONST Address : eib_def.TAddress ) : BOOLEAN;
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

      PROCEDURE StringToEIT( REF ErrorMessage : StringsO.CString; CONST String : StringsO.IString; VAR EIT : eib_def.TEIBType ) : BOOLEAN;
      BEGIN
         IF String[0] = WCHAR( 0 ) THEN
            ErrorMessage.FromOA( OAsz( R[ Texts._MissingType ] ));
            RETURN FALSE;
         ELSIF eib_def.StringToType( OA( String.Length-1, String.Data ), EIT ) THEN
            RETURN TRUE;
         ELSE
            ErrorMessage.FromOA( OAsz( R[ Texts._UnknownType ] ));
            AppendErrorId( REF ErrorMessage, String );
            RETURN FALSE;
         END;
      END StringToEIT;

   //----------

      PROCEDURE StringToSingleObject( REF ErrorMessage : StringsO.CString; CONST String : StringsO.CString; StartFromItem : CARDINAL; Priority : eib_def.TPriority; BFlags : eib_def.TA_ObjectFlags; EIT : eib_def.TEIBType; ObjectType : TObjectType ) : BOOLEAN;
      LABEL
         NextItem, NextItemAfterComment;
      VAR
         i : CARDINAL;
         l : CARDINAL;
         LAddress : eib_def.TAddress;
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

      PROCEDURE StringToMultipleObjects( REF ErrorMessage : StringsO.CString; CONST String : StringsO.IString; StartFromItem : CARDINAL; Priority : eib_def.TPriority; BFlags : eib_def.TA_ObjectFlags; EIT : eib_def.TEIBType; ObjectType : TObjectType ) : BOOLEAN;
      LABEL
         NextItem;
      VAR
         c : CARDINAL;
         Comment : StringsO.CString;
         f, l : CARDINAL;
         i, j : CARDINAL;
         LAddress : eib_def.TAddress;
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
      fullIOFlags = eib_def.TA_ObjectFlags{eib_def.aofCommunicated, eib_def.aofTransmit, eib_def.aofUpdate, eib_def.aofWritable};

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
         EIT : eib_def.TEIBType;
         GroupAddress : eib_def.CAddress;
         so, item, io : StringsO.CString;
         Path : FIO.PathStrW;
         PObject : TPObject;
         Priority : eib_def.TPriority;
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
               ELSIF NOT eib_def.NumberToType( c, EIT ) THEN
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
                     EIT := eib_def.eitString;
                  ELSIF item[3] = L'i' THEN
                     EIT := eib_def.eitSwitch;
                  ELSE // L'y' -- byte
                     EIT := eib_def.eitScaling;
                  END;
               | L'2' :
                  EIT := eib_def.eitValue;
               | L'3' :
                  EIT := eib_def.eitTime;
               | L'4' :
                  IF item[3] = L'i' THEN
                     EIT := eib_def.eitIncrease;
                  ELSE // L'y' -- byte
                     EIT := eib_def.eit32bit;
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
               Priority := eib_def.priorityNormal;
            ELSIF item.EqualsOA( kvESFHigh ) THEN
               Priority := eib_def.priorityHigh;
            ELSIF item.EqualsOA( kvESFAlarm ) THEN
               Priority := eib_def.priorityAlarm;
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
      BFlags : eib_def.TA_ObjectFlags;
      Blocks : lists.CStringList;
      c : CARDINAL;
      Connection, Key : ARRAY [0..255] OF WCHAR;
      EIT : eib_def.TEIBType;
      ErrorMessageOA : ARRAY [0..255] OF WCHAR;
      ES : PTR;
      i : CARDINAL;
      Name : StringsO.CString;
      objectType : TObjectType;
      p : StringsO.CString;
      PBehaviour : TPBehaviour;
      Priority : eib_def.TPriority;
      s : ARRAY [0..4095] OF WCHAR;
      so : StringsO.CString;
      TS : INIFile.CINIFile;
      b : BOOLEAN;
      logged : BOOLEAN;
   BEGIN
      IF EXEFlag THEN
         R.LoadRES2( L"", L"srvcore.Texts" );
      ELSE
         R.LoadRES2( EMITW( %dll ), L"srvcore.Texts" );
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
            ELSIF so.StartsWithOA( kvEIBNet ) THEN
               c := so.IndexOfOA( kvEIBNet, 0 );
               so.SubstringOA( c+LENGTH( kvEIBNet )+1, MAX( CARDINAL ), OUT Connection );
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
         NEW( eibnetstack.TPEIBNetStack( EIB ));
      ELSIF DeviceId = LONGWORD( -1 ) THEN
         // Stack := stackFalcon;
         // NEW( falconStack.TPFalconStack( EIB ));
         // ASSIGN( falconStack.TPFalconStack( EIB )^.Connection, FalconConnection );
         // ASSIGN( falconStack.TPFalconStack( EIB )^.Key, Key );
         ErrorMessage.FromOA( OAsz( R[ Texts._UnsupportedStack ] ));
         GOTO Fail;
      ELSIF DeviceId = LONGWORD( -2 ) THEN
         Stack := stackEIBNet;
         NEW( eibnetstack.TPEIBNetStack( EIB ));
      ELSE
         // Stack := stackUSB;
         // NEW( eibusb.TPTPUARTStack( EIB ));
         ErrorMessage.FromOA( OAsz( R[ Texts._UnsupportedStack ] ));
         GOTO Fail;
      END;

      EIB^.Init( FALSE, eib_stack.eltUndefined, eib_stack.eltUndefined, ADR( Sink ));
      eibnetstack.TPEIBNetStack( EIB )^.SetLogger( ADR( Logger ));

      IF NOT EIB^.SetParameter( L"link.connection", Connection, OUT ErrorMessageOA ) THEN
         CreateParameterError( Texts._BadConnection, ErrorMessageOA, REF ErrorMessage );
         GOTO Fail;
      END;
      // still inside snDevice
      IF TS.GetKeyStr( knMode, OUT ErrorLine, OUT so ) THEN
         IF NOT EIB^.SetParameter( L"link.mode", OA( so.Length-1, so.Data ), OUT ErrorMessageOA ) THEN
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
            IF NOT EIB^.SetParameter( L"link.outputQueueLength", OA( so.Length-1, so.Data ), OUT ErrorMessageOA ) THEN
               CreateParameterError( Texts._BadOutputQueueLength, ErrorMessageOA, REF ErrorMessage );
               GOTO Fail;
            END;
         END;
         IF TS.GetKeyStr( knWriteQueueLength, OUT ErrorLine, OUT so ) THEN
            IF NOT EIB^.SetParameter( L"application.pendingQueueLength.write", OA( so.Length-1, so.Data ), OUT ErrorMessageOA ) THEN
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
            IF NOT EIB^.SetParameter( L"link.ackMethod", OA( so.Length-1, so.Data ), OUT ErrorMessageOA ) THEN
               CreateParameterError( Texts._BadACKMethod, ErrorMessageOA, REF ErrorMessage );
               GOTO Fail;
            END;
         END;
         IF TS.GetKeyStr( knRetryCount, OUT ErrorLine, OUT so ) THEN
            IF NOT EIB^.SetParameter( L"link.retryCount", OA( so.Length-1, so.Data ), OUT ErrorMessageOA ) THEN
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

            Priority := eib_def.priorityNormal;
            so.ItemS( StringsO.WCHARS{L' ', L','}, 0, 0, TRUE, OUT p );
            IF p.Empty THEN
               ErrorMessage.AppendOA( OAsz( R[ Texts._MissingBehaviourName ] ));
               GOTO Fail;
            ELSE
               BFlags := eib_def.TA_ObjectFlags{eib_def.aofCommunicated};
               Name := p;
            END;

            i := 1;
            LOOP
               so.ItemS( StringsO.WCHARS{L' ', L','}, 0, i, TRUE, OUT p );
               IF p.Empty THEN
                  EXIT;
               END;
               IF p.EqualsOA( kvReadable ) THEN
                  INCL( BFlags, eib_def.aofReadable );
               ELSIF p.EqualsOA( kvWritable ) THEN
                  INCL( BFlags, eib_def.aofWritable );
               ELSIF p.EqualsOA( kvTransmit ) THEN
                  INCL( BFlags, eib_def.aofTransmit );
               ELSIF p.EqualsOA( kvUpdate ) THEN
                  INCL( BFlags, eib_def.aofUpdate );
               ELSIF p.EqualsOA( kvForceRead ) THEN
                  INCL( BFlags, eib_def.aofForceRead );
               ELSIF p.EqualsOA( kvCallback ) THEN
                  INCL( BFlags, eib_def.aofAdvise );
               ELSIF p.EqualsOA( kvInitRead ) THEN
                  INCL( BFlags, eib_def.aofInitRead );
               ELSIF p.EqualsOA( kvPHigh ) THEN
                  Priority := eib_def.priorityHigh;
               ELSIF p.EqualsOA( kvPAlarm ) THEN
                  Priority := eib_def.priorityAlarm;
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
               ELSIF eib_def.aofInitRead IN BFlags THEN
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
         ELSIF eib_def.aofInitRead IN BFlags THEN
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

      IF NOT _CacheOnlyMode THEN
         EIB^.SetStackAddress( Address );

         IF PromiscuousMode THEN
            EIB^.SetParameter( L"application.promiscuousMode", L"true", OUT ErrorMessageOA );
         ELSE
            EIB^.SetParameter( L"application.promiscuousMode", L"false", OUT ErrorMessageOA );
         END;
         IF PromiscuousMode THEN
            FOR EIT := eib_def.eitSwitch TO eib_def.eitString DO WITH prObjects[EIT] DO
               Server := ADR( SELF );
               Init( EIB, EIT, eib_user.obNone );
               SetClass( eib_def.priorityNormal );
               SetFlags( fullIOFlags + eib_def.TA_ObjectFlags{eib_def.aofPromiscuous} );
               SubscribePromiscuous();
            END; END; // WITH // FOR
         END; // IF PromiscuousMode

         EIB^.SetTimeout( eib_stack.tidL_ACKTimeout, ACKTimeout, 0 );
         EIB^.SetTimeout( eib_stack.tidL_BUSYDelay, BUSYDelay, 0 );
         EIB^.SetTimeout( eib_stack.tidL_SendDelay, SendDelay, 0 );
         EIB^.SetTimeout( eib_stack.tidA_PendingDelay, WriteDelay, eib_stack.pendingGroupWrite );
         EIB^.SetTimeout( eib_stack.tidA_PendingDelay, ReadOnStart.Delay, eib_stack.pendingGroupRead );
         EIB^.SetTimeout( eib_stack.tidA_PendingTimeout, ReadOnStart.Timeout, eib_stack.pendingGroupRead );

         IF NOT PromiscuousMode THEN
            eib_stack.TPEIBStackApplicationLayer( EIB^.Layers[ eib_stack.eltApplication ] )^.Update_L_Layer();
         END;
      END; // IF NOT _CacheOnlyMode
      
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
      hash : ns.THash;
      result : Sync.TAsyncResult;
      value : iovalue.Value;
   BEGIN
      IF EventSink <> NIL THEN
         EventSink^.OnConnect();
      END;

      RStatus := RStatus - TRStatus{rsInitReadRepeat, rsInitReadFinished} + TRStatus{rsInitReadPending};
      InitReadItems := 0;
      IF Objects.Count = 0 THEN
         InitReadFinished();
      ELSE
         IF ( _ForceReadPeriod > 0 ) AND ( _ReadersCount > 0 ) THEN
            StartTimer( tiForceRead, _ForceReadPeriod, TRUE );
         END;
         DoInitRead( FALSE );
      END;
      
      IF _AdviseListener <> NIL THEN
         hash := itemConnected;
         result := Sync.arCompleted;
         value.Boolean := TRUE;
         _AdviseListener^.OnAdvise( ADR( SELF ), OA( 0, ADR( result )), OA( 0, ADR( hash )), OA( 0, ADR( value )) );
      END;
   END OnDeviceConnect;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE OnDeviceDisconnect();
   VAR
      hash : ns.THash;
      result : Sync.TAsyncResult;
      value : iovalue.Value;
   BEGIN
      IF EventSink <> NIL THEN
         EventSink^.OnDisconnect();
      END;

      StopTimer( tiForceRead );

      IF _AdviseListener <> NIL THEN
         hash := itemConnected;
         result := Sync.arCompleted;
         value.Boolean := FALSE;
         _AdviseListener^.OnAdvise( ADR( SELF ), OA( 0, ADR( result )), OA( 0, ADR( hash )), OA( 0, ADR( value )) );
      END;
   END OnDeviceDisconnect;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE GetObject( CONST Address : eib_def.TAddress; OUT PObject : TPObject ) : BOOLEAN;
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
         ObjectType := TObjectType{ objtMultipleAddresses};
      ELSIF ObjectTypeName.EqualsOA( otnObjects ) THEN
         ObjectType := TObjectType{};
      ELSIF ObjectTypeName.EqualsOA( otnLoggedObject ) THEN
         ObjectType := TObjectType{ objtMultipleAddresses, objtLogNoChange};
      ELSIF ObjectTypeName.EqualsOA( otnLoggedObjects ) THEN
         ObjectType := TObjectType{ objtLogNoChange};
      ELSIF ObjectTypeName.EqualsOA( otnLoggedOnChangeObject ) THEN
         ObjectType := TObjectType{ objtMultipleAddresses, objtLogOnChange};
      ELSIF ObjectTypeName.EqualsOA( otnLoggedOnChangeObjects ) THEN
         ObjectType := TObjectType{ objtLogOnChange};
      ELSIF ObjectTypeName.EqualsOA( otnESFStrict ) THEN
         ObjectType := TObjectType{ objtESFStrict};
      ELSIF ObjectTypeName.EqualsOA( otnLoggedESFStrict ) THEN
         ObjectType := TObjectType{ objtESFStrict, objtLogNoChange};
      ELSIF ObjectTypeName.EqualsOA( otnESFAdapt ) THEN
         ObjectType := TObjectType{ objtESFAdapt};
      ELSIF ObjectTypeName.EqualsOA( otnLoggedESFAdapt ) THEN
         ObjectType := TObjectType{ objtESFAdapt, objtLogNoChange};
      ELSIF ObjectTypeName.EqualsOA( otnESFIgnore ) THEN
         ObjectType := TObjectType{ objtESFIgnore};
      ELSIF ObjectTypeName.EqualsOA( otnLoggedESFIgnore ) THEN
         ObjectType := TObjectType{ objtESFIgnore, objtLogNoChange};
      ELSE
         RETURN FALSE;
      END;
      
      RETURN TRUE;
   END FindObjectType;

//--------------------------------------------------------------------------------

   PROCEDURE FindBehaviour( CONST BehaviourName : StringsO.IString; VAR Priority : eib_def.TPriority; VAR Flags : eib_def.TA_ObjectFlags ) : BOOLEAN;
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
         Flags := eib_def.TA_ObjectFlags{eib_def.aofCommunicated, eib_def.aofUpdate, eib_def.aofWritable, eib_def.aofInitRead, eib_def.aofForceRead};
      ELSIF BehaviourName.EqualsOA( bnTracker ) THEN
         Flags := eib_def.TA_ObjectFlags{eib_def.aofCommunicated, eib_def.aofUpdate, eib_def.aofWritable};
      ELSIF BehaviourName.EqualsOA( bnTracker2 ) THEN
         Flags := eib_def.TA_ObjectFlags{eib_def.aofCommunicated, eib_def.aofUpdate, eib_def.aofWritable, eib_def.aofInitRead};
      ELSIF BehaviourName.EqualsOA( bnTransmitter ) THEN
         Flags := eib_def.TA_ObjectFlags{eib_def.aofCommunicated, eib_def.aofTransmit};
      ELSIF BehaviourName.EqualsOA( bnTransmitterWithStatus ) THEN
         Flags := eib_def.TA_ObjectFlags{eib_def.aofCommunicated, eib_def.aofTransmit, eib_def.aofUpdate, eib_def.aofWritable};
      ELSIF BehaviourName.EqualsOA( bnTransmitterWithStatus2 ) THEN
         Flags := eib_def.TA_ObjectFlags{eib_def.aofCommunicated, eib_def.aofTransmit, eib_def.aofUpdate, eib_def.aofWritable, eib_def.aofInitRead};
      ELSIF BehaviourName.EqualsOA( bnTransmitterWithStatusCallback ) THEN
         Flags := eib_def.TA_ObjectFlags{eib_def.aofCommunicated, eib_def.aofTransmit, eib_def.aofUpdate, eib_def.aofWritable, eib_def.aofAdvise};
      ELSIF BehaviourName.EqualsOA( bnTransmitterWithStatusCallback2 ) THEN
         Flags := eib_def.TA_ObjectFlags{eib_def.aofCommunicated, eib_def.aofTransmit, eib_def.aofUpdate, eib_def.aofWritable, eib_def.aofAdvise, eib_def.aofInitRead};
      ELSIF BehaviourName.EqualsOA( bnServer ) THEN
         Flags := eib_def.TA_ObjectFlags{eib_def.aofCommunicated, eib_def.aofReadable};
      ELSIF BehaviourName.EqualsOA( bnConcentrator ) THEN
         Flags := eib_def.TA_ObjectFlags{eib_def.aofCommunicated, eib_def.aofReadable, eib_def.aofUpdate, eib_def.aofWritable};
      ELSIF BehaviourName.EqualsOA( bnSource ) THEN
         Flags := eib_def.TA_ObjectFlags{eib_def.aofCommunicated, eib_def.aofReadable, eib_def.aofTransmit};
      ELSE
         RETURN FALSE;
      END;
      Priority := eib_def.priorityNormal;
      RETURN TRUE;
   END FindBehaviour;

//--------------------------------------------------------------------------------

   PROCEDURE AddObject( Priority : eib_def.TPriority; Flags : eib_def.TA_ObjectFlags; Type : eib_def.TEIBType; ObjectType : TObjectType ) : TPObject;
   VAR
      PObject : TPObject;
   BEGIN
      IF _CacheOnlyMode THEN
         Flags := Flags - eib_def.TA_ObjectFlags{eib_def.aofCommunicated, eib_def.aofInitRead};
      END;
      IF eib_def.aofForceRead IN Flags THEN
         INC( _ReadersCount );
      END;

      NEW( PObject );
      PObject^.Server := ADR( SELF );
      PObject^.Init( EIB, Type, eib_user.obNone );
      PObject^.SetClass( Priority );
      PObject^.SetFlags( Flags );
      PObject^.ObjectType := ObjectType;
      
      Objects.Add( PObject );

      RETURN PObject;
   END AddObject;

//--------------------------------------------------------------------------------

   PROCEDURE DoneObjects( NILExecutive : BOOLEAN );
   VAR
      EIT : eib_def.TEIBType;
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
      IF NILExecutive THEN
         FOR EIT := eib_def.eitSwitch TO eib_def.eitString DO
           prObjects[EIT].PExecutive := NIL;
         END;
      END;
   END DoneObjects;

//--------------------------------------------------------------------------------

   LOCAL PROCEDURE ValueReadRequestSent( PObject : TPObject; CurrentState : eib_user.TObjectState );
   BEGIN
      IF PObject^.RSStatus <> eib_status.essOK THEN
         ValueRead( PObject, CurrentState, PObject^.InitReadState );
      END;
   END ValueReadRequestSent;

//--------------------------------------------------------------------------------

   LOCAL PROCEDURE ValueRead( PObject : TPObject; CurrentState : eib_user.TObjectState; CurrentInitReadState : eib_user.TInitReadState );
   VAR
      c : CARDINAL;
      ResponseAwaited : BOOLEAN;
   BEGIN
      IF eib_def.aofPromiscuous IN PObject^.GetFlags() THEN // promiscuous mode object, no need to count repeats or do init read
         RETURN;
      END;

      CASE PObject^.RSStatus OF
      //-----
      | eib_status.essOK :
         INCL( PObject^.Flags, eib_def.aofEIBValue );
      
      //-----
      | eib_status.essConError, // A_Read without L_ACK -- called from ValueReadRequestSent
        eib_status.essA_Timeout : // A_Read with L_ACK but without READ
         // -- handle repeating and delaying after error
         IF PObject^.ReadRepeatCount > 1 THEN
            DEC( PObject^.ReadRepeatCount );
         ELSIF INTEGER( PObject^.ReadRepeatCount ) = 1 THEN // finalize operation after all allowed counts
            DEC( PObject^.ReadRepeatCount );
            IF CurrentInitReadState = eib_user.irsPending THEN
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
      IF CurrentInitReadState = eib_user.irsPending THEN
         ResponseAwaited := TRUE;

         IF PObject^.RSStatus = eib_status.essOK THEN
            PObject^.InitReadState := eib_user.irsUnknown;
         ELSIF InitReadRepeat <= 1 THEN // repeated init read will not be performed, so notify error
            PObject^.InitReadState := eib_user.irsUnknown;
         ELSE
            ResponseAwaited := FALSE; // wait until all tries are done

            INCL( RStatus, rsInitReadRepeat );
            PObject^.InitReadState := eib_user.irsWillRepeat;
         END;
         
         DEC( InitReadItems );
         IF InitReadItems = 0 THEN
            InitReadFinished();
         END;

      ELSE
         ResponseAwaited := eib_user.osReading IN CurrentState;
      END;

      // for both osReading and osInitReadPending the reading must be announced by callback -- CW driver, e.g., can wait
      // with InputFinalized = FALSE, and if it does not receive asynchronous notification, it will never ask for value again   
      IF ResponseAwaited AND ( EventSink <> NIL ) THEN
         EventSink^.OnRead( PObject );
      END;
   END ValueRead;

//--------------------------------------------------------------------------------

   LOCAL PROCEDURE ValueUpdated( Direction : IOO.TDirection; PObject : TPObject; CurrentState : eib_user.TObjectState );
   VAR
      address : ARRAY [0..31] OF WCHAR;
      asyncResult : Sync.TAsyncResult := Sync.arCompleted;
      comment : StringsO.CString;
      EValue : eib_def.CValue;
      io : iovalue.Value;
      logged : BOOLEAN;
      value : StringsO.CString;
      valuesConverted : BOOLEAN := FALSE;
   BEGIN
      IF eib_user.osReading IN CurrentState THEN // value is NOT OOB
         RETURN;
      ELSIF PObject^.RSStatus = eib_status.essOK THEN
         INCL( PObject^.Flags, eib_def.aofEIBValue );
      END;
      IF Result.Counted OR Result.Expired THEN
         RETURN;
      END;

      IF TObjectType{objtLogNoChange, objtLogOnChange} * PObject^.ObjectType = TObjectType{} THEN
         // pass down
      ELSIF ( objtLogNoChange IN PObject^.ObjectType ) OR // log always
            ( objtLogOnChange IN PObject^.ObjectType ) AND ( eib_user.osChanged IN CurrentState ) OR // log changes
            ( Direction = IOO.dirWrite ) AND NOT EIB^.DeviceConnected() THEN // always allow log failures

         valuesConverted := TRUE;
         PObject^.GetValue( OUT EValue, TRUE, FALSE );
         EIBValue2IOValue( EValue, OUT io );
         value := io.String;
         PObject^.SendAddress.GetGroupAddress3( TRUE, OUT address );

         comment := PObject^.Comment;
         IF NOT comment.Empty THEN
            comment.PrependOA( L"(" );
            comment.AppendOA( L")" );
         END;

         IF Direction = IOO.dirRead THEN
            _DataLogger^.LogSSSS( log.ldMessage, 0, L"srv", "UPDATE", address, OA( value.Length-1, value.Data ), OA( comment.Length-1, comment.Data ));
         ELSIF NOT EIB^.DeviceConnected() THEN
            IF _CacheOnlyMode THEN
               _DataLogger^.LogSSSS( log.ldMessage, 0, L"srv", "SET TO CACHE", address, OA( value.Length-1, value.Data ), OA( comment.Length-1, comment.Data ));
            ELSE
               _DataLogger^.LogSSSS( log.ldMessage, 0, L"srv", "SET FAILED", address, OA( value.Length-1, value.Data ), OA( comment.Length-1, comment.Data ));
            END;
         END;
                  
      END;
      
      IF eib_def.aofPromiscuous IN PObject^.GetFlags() THEN // promiscuous mode queueing

         IF Direction = IOO.dirRead THEN
            EnqueuePromiscuous( eib_status.essOK, PObject );
         END;

         IF _AdviseListener <> NIL THEN
            IF NOT valuesConverted THEN
               PObject^.GetValue( OUT EValue, TRUE, FALSE );
               EIBValue2IOValue( EValue, OUT io );
            END;
            _AdviseListener^.OnAdvise( ADR( SELF ), OA( 0, ADR( asyncResult )), OA( 0, ADR( PObject )), OA( 0, ADR( io )) );
         END;

      ELSE // oobData promiscuous mode queueing

         IF ( Direction = IOO.dirRead ) AND ( EventSink <> NIL ) THEN
            QueueLock.Lock();
            IF oobData.Count >= InputQueueLength THEN
               QueueLock.Unlock();
               EventSink^.OnInputQueueOverflow( TRUE, FALSE );
               RETURN;
            END;
         END;

         IF NOT valuesConverted THEN
            PObject^.GetValue( OUT EValue, TRUE, FALSE );
            EIBValue2IOValue( EValue, OUT io );
         END;

         IF ( Direction = IOO.dirRead ) AND ( EventSink <> NIL ) THEN
            oobData.EnqueueOA( EValue.Data, PObject );
            QueueLock.Unlock();

            EventSink^.OnInputQueueAdd( TRUE, FALSE );
         END;

         IF _AdviseListener <> NIL THEN
            _AdviseListener^.OnAdvise( ADR( SELF ), OA( 0, ADR( asyncResult )), OA( 0, ADR( PObject )), OA( 0, ADR( io )) );
         END;

      END;
   END ValueUpdated;

//--------------------------------------------------------------------------------

   LOCAL PROCEDURE ValueWritten( PObject : TPObject; CurrentState : eib_user.TObjectState );
   VAR
      address : ARRAY [0..31] OF WCHAR;
      comment : StringsO.CString;
      EValue : eib_def.CValue;
      io : iovalue.Value;
      value : StringsO.CString;
   BEGIN
      IF PObject^.WSStatus = eib_status.essOK THEN
         INCL( PObject^.Flags, eib_def.aofEIBValue );
      END;
      IF EventSink <> NIL THEN
         IF eib_user.osWriting IN CurrentState THEN
            EventSink^.OnWritten( PObject );
         END;
         
         // in case of promiscuous mode report error
         IF ( PObject^.WSStatus <> eib_status.essOK ) AND ( eib_def.aofPromiscuous IN PObject^.GetFlags()) THEN
            EnqueuePromiscuous( PObject^.WSStatus, PObject );
         END;
      END;
      
      IF TObjectType{objtLogNoChange, objtLogOnChange} * PObject^.ObjectType = TObjectType{} THEN
         // pass down
      ELSIF ( objtLogNoChange IN PObject^.ObjectType ) OR // log always
            ( objtLogOnChange IN PObject^.ObjectType ) AND ( PObject^.ChangedOnWrite <> 0 ) OR // log changes
            ( PObject^.WSStatus <> eib_status.essOK ) THEN // always allow log errors

         PObject^.GetValue( OUT EValue, TRUE, FALSE );
         EIBValue2IOValue( EValue, OUT io );
         value := io.String;
         PObject^.SendAddress.GetGroupAddress3( TRUE, OUT address );

         comment := PObject^.Comment;
         IF NOT comment.Empty THEN
            comment.PrependOA( L"(" );
            comment.AppendOA( L")" );
         END;

         IF PObject^.WSStatus = eib_status.essOK THEN
            _DataLogger^.LogSSSS( log.ldMessage, 0, L"srv", "SET OK", address, OA( value.Length-1, value.Data ), OA( comment.Length-1, comment.Data ));
         ELSE
            _DataLogger^.LogSSSS( log.ldMessage, 0, L"srv", "SET ERROR", address, OA( value.Length-1, value.Data ), OA( comment.Length-1, comment.Data ));
         END;
                  
      END;

      IF eib_def.aofAdvise IN PObject^.GetFlags() THEN
         ValueUpdated( IOO.dirRead, PObject, CurrentState );
      END;
   END ValueWritten;

//--------------------------------------------------------------------------------

   PRIVATE PROCEDURE EnqueuePromiscuous( Status : eib_status.TEIBStackStatus; PObject : TPObject );
   VAR
      EValue : eib_def.CValue;
      prItem : PromiscuousData;
   BEGIN
      IF EventSink = NIL THEN
         RETURN;
      END;

      QueueLock.Lock();
      IF prData.Count >= InputQueueLength THEN
         QueueLock.Unlock();
         EventSink^.OnInputQueueOverflow( FALSE, TRUE );
         RETURN;
      END;
      
      prItem.Status := Status;
      prItem.Address := PObject^.PromiscuousAddress;
      PObject^.GetValue( OUT prItem.Value, TRUE, FALSE );
      
      prData.EnqueueOA( prItem, 0 );
      INCL( RStatus, rsPromiscuousInQueue );
      QueueLock.Unlock();

      EventSink^.OnInputQueueAdd( FALSE, TRUE );
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
      IF EIB <> NIL THEN
         EIB^.Done();
         DISPOSE( EIB );
      END;
      Storage.Fill( ADR( Groups ), SIZE( Groups ), 0FFH );
   END InitToDefault;

//--------------------------------------------------------------------------------

   PROCEDURE DoInitRead( RepeatFlag : BOOLEAN );
   VAR
      EV : eib_def.TValue;
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
         IF NOT RepeatFlag AND ( eib_def.aofInitRead IN PObject^.GetFlags()) OR
                RepeatFlag AND ( PObject^.InitReadState = eib_user.irsWillRepeat ) THEN

            IF NOT Logger.FilteredFastCheck( log.ldTrace, 0 ) THEN
               PObject^.ReadAddress.GetGroupAddress3( TRUE, saddr );
               Logger.LogSS( log.ldTrace, 0, L"srv", "INIT: ", saddr );
            END;

            INC( InitReadItems );
            PObject^.InitReadState := eib_user.irsPending;
            PObject^.ReadRepeatCount := ReadOnStart.RepeatCount;
            PObject^.GetValue( OUT EV, FALSE, TRUE );
         END;
      END; // FOR
      UnlockObjects();

   END DoInitRead;

//--------------------------------------------------------------------------------

   PROCEDURE DoForceRead();
   VAR
      EV : eib_def.TValue;
      i : CARDINAL;
      PObject : TPObject;
      saddr : ARRAY [0..63] OF WCHAR;
   BEGIN
      IF _ReadersCount > 0 THEN // redundant check

         LockObjects();

         FOR i := 0 TO Objects.Count - 1 DO
            PObject := TPObject( Objects[i] );
            IF eib_def.aofForceRead NOT IN PObject^.GetFlags() THEN
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

   PROCEDURE InitReadFinished();
   BEGIN
      IF NOT( rsInitReadRepeat IN RStatus ) THEN
         RStatus := RStatus - TRStatus{rsInitReadPending} + TRStatus{rsInitReadFinished};
         EIB^.SetTimeout( eib_stack.tidA_PendingDelay, ReadDuringRun.Delay, eib_stack.pendingGroupRead );
         EIB^.SetTimeout( eib_stack.tidA_PendingTimeout, ReadDuringRun.Timeout, eib_stack.pendingGroupRead );
         StopTimer( tiInitReadDelay );
         IF EventSink <> NIL THEN
            EventSink^.OnInitReadCompleted();
         END;
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

   LOCAL PROCEDURE IOValue2EIBValue( CONST Value : iovalue.Value; DestEVType : eib_def.TEIBType; OUT EV : eib_def.TValue );
   VAR
      c : CARDINAL;
      Day : eib_def.TDay;
      DT : DateTime.DateTime;
      fd : CARDINAL;
      H, M, S, WD : CARDINAL;
      i : INTEGER;
      s : ARRAY [0..31] OF WCHAR;
      so : StringsO.CString;
      Y, MM, D : INTEGER;
   BEGIN
      EV.SetType( DestEVType );

      CASE EV.GetType() OF
      | eib_def.eitUnknown :
         RETURN;

      | eib_def.eitSwitch :
         EV.SetSwitch( Value.Boolean );

      | eib_def.eitIncrease :
         i := Value.Integer;
         IF i = 0 THEN
            EV.SetIncrease( FALSE, FALSE, 0 );
         ELSIF i < 0 THEN
            EV.SetIncrease( FALSE, TRUE, CARDINAL( -i ));
         ELSE
            EV.SetIncrease( TRUE, FALSE, CARDINAL( i ));
         END;

      | eib_def.eitTime :
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
            Day := eib_def.TDay( 1 + ( CARDINAL( DT.DayOfWeek ) + 6 ) MOD 7 );
         | 1..7 :
            Day := eib_def.TDay( WD );
         ELSE
            Day := eib_def.dayNo;
         END;
         EV.SetTime( Day, H, M, S );

      | eib_def.eitDate :
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

      | eib_def.eitValue, eib_def.eitValueRange :
         EV.SetValue( Value.Float );

      | eib_def.eitScaling :
         EV.SetScaling( MIN2( 100, Value.LimitedInteger( 8, FALSE, TRUE )));

      | eib_def.eitScaling255 :
         EV.SetScaling255( CARD8( Value.LimitedInteger( 8, FALSE, TRUE )));

      | eib_def.eitMove :
         EV.SetMove( Value.Boolean );

      | eib_def.eitPriority :
         EV.SetPriority( Value.LimitedInteger( 2, FALSE, TRUE ));

      | eib_def.eitFloat :
         EV.SetFloat( Value.Float );

      | eib_def.eit16bit :
         EV.Set16bit( Value.LimitedInteger( 16, FALSE, TRUE ));

      | eib_def.eit32bit :
         EV.Set32bit( Value.Integer );

      | eib_def.eitChar :
         EV.SetChar( Value.String[0] );

      | eib_def.eit8bit :
         EV.Set8bit( Value.LimitedInteger( 8, FALSE, TRUE ));

      | eib_def.eitString :
         Value.String.ToOA( OUT s );
         EV.SetString( s );
      END; // CASE EV.Type

   END IOValue2EIBValue;

//--------------------------------------------------------------------------------

   LOCAL PROCEDURE EIBValue2IOValue( CONST EV : eib_def.TValue; OUT Value : iovalue.Value );
   VAR
      c : CARDINAL;
      Day : eib_def.TDay;
      dt : DateTime.DateTime;
      s : ARRAY [0..255] OF WCHAR;
      Y, M, D, H, S : CARDINAL;
      b1 : BOOLEAN;
      b2 : BOOLEAN;
   BEGIN

      CASE EV.GetType() OF
      | eib_def.eitUnknown :
         ASSERT( FALSE );
         Value.Boolean := FALSE;

      | eib_def.eitSwitch :
         Value.Boolean := EV.GetSwitch();

      | eib_def.eitIncrease :
         c := EV.GetIncrease( b1, b2 );
         IF b1 THEN
            Value.Integer := INTEGER( c );
         ELSIF b2 THEN
            Value.Integer := -INTEGER( c );
         ELSE
            Value.Integer := 0;
         END;

      | eib_def.eitTime :
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
               Value.FromStringOA( s, FALSE );
            ELSE
               Value.FromStringOA( L"", FALSE );
            END;
         ELSE
            Value.Integer := CARDINAL( Day ) * 100000 + ( H * 60 + M ) * 60 + S;
         END;

      | eib_def.eitDate :
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
               Value.FromStringOA( s, FALSE );
            ELSE
               Value.FromStringOA( L"", FALSE );
            END;
         ELSE
            Value.Date := DateTime.JD( Y, M, D, 0 );
         END;

      | eib_def.eitValue, eib_def.eitValueRange :
         Value.Float := EV.GetValue();

      | eib_def.eitScaling :
         Value.Integer := EV.GetScaling();

      | eib_def.eitScaling255 :
         Value.Integer := EV.GetScaling255();

      | eib_def.eitMove :
         Value.Boolean := EV.GetMove();
      
      | eib_def.eitPriority :
         Value.Integer := EV.GetPriority();

      | eib_def.eitFloat :
         Value.Float := EV.GetFloat();

      | eib_def.eit16bit :
         Value.Integer := EV.Get16bit();

      | eib_def.eit32bit :
         Value.Integer := EV.Get32bit();

      | eib_def.eitChar :
         Value.Type := iovalue.vtString;
         Value.FromStringOA( EV.GetChar(), FALSE );

      | eib_def.eit8bit :
         Value.Integer := EV.Get8bit();

      | eib_def.eitString :
         EV.GetString( s );
         Value.FromStringOA( s, FALSE );
      END; // CASE EV.Type

   END EIBValue2IOValue;

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

   EIB := NIL;
   Sink.Server := ADR( SELF );
   EventSink := NIL;
   _Advise := io.advWithData;
   _AdviseListener := NIL;
   _DataLogger := NIL;

   Logger.Level := Log.ldDebug;
   Logger.Output := log.outsNone; // redirect all to Log.logger()
   Logger.AddOutput( Log.logger());
   Log.ConfigureByRegistry( REF Logger, LIBRARY );
   Logger.SetName( L"KNX" );
   
   _ForceReadPeriod := 0;
   _ReadersCount := 0;

   ObjectLock.Init( Sync.ltCS, L"", FALSE );
   QueueLock.Init( Sync.ltSpin, L"", FALSE );
   
   cllvdata := NIL;
   cllvlength := 0;

   InitReadItems := 0;
   oobData.ItemType := lists.blitSlot32;
   prData.ItemType := lists.blitSlot64;
   ASSERT( SIZE( PromiscuousData ) < 64 );
FINALLY
   Dispose();
END CEIBServer;

//================================================================================

END srvcore.
