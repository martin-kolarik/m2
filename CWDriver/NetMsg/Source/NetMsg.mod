MODULE NetMsg;

(*# call( o_a_copy => off ) *)

(*================================================================================*)

FROM Storage IMPORT
  REALLOCATE, ALLOCATE, DEALLOCATE;
  
FROM log IMPORT
  dldTrace, dldDebug;

IMPORT
  cllv,
  crc,
  diface,
  digest,
  dns,
  drv_def,
  FIO,
  FIOO,
  INIFile,
  inetaddr,
  IOO,
  iovalue,
  Languages,
  lec,
  list,
  lists,
  log,
  maps,
  msghandler,
  netconndispatch,
  netsrv,
  netsocket,
  Resources,
  rijndael,
  scinit,
  sha256,
  Storage,
  StorageO,
  Strings,
  StringsO,
  Sync,
  TextReader,
  Texts;

(*================================================================================*)

CONST // device specific error codes
  ecRxTimeout = drv_def.ecCommunicationTimeout;
  ecChkSumError = drv_def.ecCheckSumError;
  ecDeviceStopped = drv_def.ecUser + 1;

CONST
   logPrefix = L"NetMsg";

(*--------------------------------------------------------------------------------*)

CONST // driver channels
  chStatus = 1;

(*================================================================================*)

TYPE
  TPDriver = POINTER TO CDriver;

  TRStatusItem  = (
    rsRunning,
    rsEventsPending,
    rsListening,
    rsValid,
    rsGlobalKey
  );
  TRStatus = SET OF TRStatusItem;

CONST
  rssUser = TRStatus{rsRunning, rsEventsPending, rsListening, rsValid};
  
CONST
  ck = sha256.TDigest(
    0D5H, 007H, 072H, 003H, 014H, 0BEH, 054H, 046H, 008H, 0BEH, 01DH, 082H, 0E3H, 0D3H, 0E0H, 05DH,
    0FCH, 090H, 06EH, 080H, 02EH, 08DH, 045H, 0BAH, 08DH, 019H, 06AH, 0EBH, 09EH, 0B6H, 06AH, 03EH
  );

(*--------------------------------------------------------------------------------*)

CLASS CClient( netconndispatch.CClientInterface );
  Connection : netconndispatch.TConnectionHandle;
  LOCAL VIRTUAL PROCEDURE OnJoin( Connection : netconndispatch.TConnectionHandle );
  LOCAL VIRTUAL PROCEDURE OnConnect( Connection : netconndispatch.TConnectionHandle; Local : BOOLEAN; Error : CARDINAL );
  LOCAL VIRTUAL PROCEDURE OnDisconnect( Connection : netconndispatch.TConnectionHandle; Local : BOOLEAN; Error : CARDINAL );
END CClient;

TYPE
  TPClient = POINTER TO CClient;

CLASS CClientLE( list.CListElem );
  PClient : TPClient;
  Group   : ARRAY [0..63] OF WCHAR;
  Name    : ARRAY [0..63] OF WCHAR;
  Address : inetaddr.INETADDR;
END CClientLE;

TYPE
  TPClientLE = POINTER TO CClientLE;

(*--------------------------------------------------------------------------------*)

CLASS CGroupLE( list.CListElem );
  Name : ARRAY [0..63] OF WCHAR;
  Clients : list.CList;
END CGroupLE;

TYPE
  TPGroupLE = POINTER TO CGroupLE;

CLASS CClientGroupLE( list.CListElem );
  PClientLE : TPClientLE;
END CClientGroupLE;

TYPE
  TPClientGroupLE = POINTER TO CClientGroupLE; 

(*--------------------------------------------------------------------------------*)

CLASS CServer( netconndispatch.CDispatcher );
  Driver : TPDriver;
  VIRTUAL PROCEDURE OnConnect( PConnection : netconndispatch.TConnectionHandle; Local : BOOLEAN; Error : CARDINAL );
  VIRTUAL PROCEDURE OnDisconnect( PConnection : netconndispatch.TConnectionHandle; Local : BOOLEAN; Error : CARDINAL );
  VIRTUAL PROCEDURE OnReceive( PConnection : netconndispatch.TConnectionHandle; PData : ADDRESS; DataLen : CARDINAL );
END CServer;

(*================================================================================*)

TYPE
  TTransport = (
    trUnknown,
    trGroup,
    trString,
    trStruct
  );

(*# save, option( pack => 1 ) *)
  TPPacket = POINTER TO RECORD
                Length : CARDINAL;
                CRC : CARDINAL;
                CASE TR : TTransport OF
                | trGroup  : Group : ARRAY [0..255] OF WCHAR; // use Length
                | trString : Data  : ARRAY [0..0] OF CHAR; // normally longer, use Length
                | trStruct : Struct : ARRAY [0..0] OF CHAR; // normally longer, use Length
                END; // CASE
             END; // RECORD
(*# restore *)

CONST
  hdr = SIZE( CARDINAL ) + SIZE( CARDINAL ) + SIZE( TTransport );

TYPE
  TEvent = (
    evConnect,
    evDisconnect,
    evDataReceived1,
      evDataReceived2Success,
      evDataReceived2BadCRC,
    evStructReceived1,
      evStructReceived2Success,
      evStructReceived2BadCRC
  );

  TEventData = RECORD
                 CASE Event : TEvent OF
                 | evConnect, evDisconnect :
                   Local : BOOLEAN;
                   Address : inetaddr.INETADDR;
                   Error : CARDINAL;
                 | evDataReceived1, evStructReceived1 :
                   PReceiveClient : TPClientLE;
                 | evDataReceived2Success, // always follows evDataReceived1
                   evStructReceived2Success : // always follows evStructReceived1
                   PacketLen : CARDINAL;
                   PPacket : TPPacket;
                 | evDataReceived2BadCRC, // always follows evDataReceived1
                   evStructReceived2BadCRC : // always follows evStructReceived1
                 END; // CASE
               END; // RECORD

  TPEventLE  = POINTER TO CEventLE;

CLASS CEventLE( list.CListElem );
  Event : TEventData;
END CEventLE;

(*--------------------------------------------------------------------------------*)

CLASS CDriver( msghandler.MessageHandler ) IMPLEMENTS diface.ICWDriver;
  R             : Resources.CResources;
  RStatus       : TRStatus;
  Name          : StringsO.CString;
  Logger        : log.CLogger;

  CallbackId    : ADDRESS;
  CallbackProc  : drv_def.TDriverCallbackW;
  RunMode       : CARDINAL;
  Result        : lec.CResult;

  // driver data
  ListenAddress : inetaddr.INETADDR;
  Server        : CServer;
  GlobalKey     : sha256.TDigest;
  Delimiter     : WCHAR := WCHAR(":");

  ClientsLock   : Sync.LOCK;
  Clients       : list.CList;
  Groups        : list.CList;
  RemovedClients: list.CList;

  EventsLock    : Sync.LOCK;
  Events        : list.CList;
  Packet        : StorageO.CMemoryBuffer;
  FieldToValue  : maps.CIntegerMap; // Map OF PTR TO iovalue.Value
  Records       : maps.CStringMap; // Map OF Array OF PTR to iovalue.Value in above structure

  // binding to procedural interface
  PUBLIC VIRTUAL PROCEDURE Initialize( RunMode : CARDINAL; CONST SymbolicName : StringsO.CString; CallbackId : ADDRESS; CallbackProc : drv_def.TDriverCallbackW );
  PUBLIC VIRTUAL PROCEDURE ReadParameters( CONST ParametersFilePath : StringsO.CString; CONST Logger : log.CLogger ) : BOOLEAN;
  PUBLIC VIRTUAL PROCEDURE QueryErrorCode( ErrorCode : CARDINAL; OUT ErrorText : StringsO.CString ) : BOOLEAN;
  PUBLIC VIRTUAL PROCEDURE EnumerateChannels( REF EnumerateState : LONGWORD; OUT Type : drv_def.TValueType; OUT Direction : drv_def.TDirection; OUT DriverIndex, Count : CARDINAL; OUT HaveDescription : BOOLEAN ) : BOOLEAN;
  PUBLIC VIRTUAL PROCEDURE GetChannelDescription( DriverIndex : CARDINAL; OUT Description : StringsO.CString; OUT Id : StringsO.CString ) : BOOLEAN;

  PUBLIC VIRTUAL PROCEDURE DriverRun();
  PUBLIC VIRTUAL PROCEDURE DriverStop();
  PUBLIC VIRTUAL PROCEDURE Dispose();

  PUBLIC VIRTUAL PROCEDURE DriverProc( Func, Param1, Param2, Param3, Param4 : CARDINAL );
  PUBLIC VIRTUAL PROCEDURE QueryProc( CONST InValue1, InValue2 : iovalue.Value; OutValueLimit : CARDINAL; OUT OutValue : iovalue.Value );

  PUBLIC VIRTUAL PROCEDURE InputRequestStart();
  PUBLIC VIRTUAL PROCEDURE InputRequest( DriverIndex : CARDINAL );
  PUBLIC VIRTUAL PROCEDURE InputRequestCompleted();
  PUBLIC VIRTUAL PROCEDURE InputFinalized( DriverIndex : CARDINAL; OUT ErrorCode : CARDINAL ) : BOOLEAN;
  PUBLIC VIRTUAL PROCEDURE InputOOBDataQuery( REF EnumerateState : LONGWORD; OUT DriverIndex : CARDINAL ) : BOOLEAN;
  PUBLIC VIRTUAL PROCEDURE GetInput( DriverIndex : CARDINAL; InValueLimit : CARDINAL; OUT InValue : iovalue.Value; OUT QoS : CARDINAL; OUT TimeStamp : drv_def.TUTCStamp; OUT ErrorCode : CARDINAL );

  PUBLIC VIRTUAL PROCEDURE OutputRequestStart();
  PUBLIC VIRTUAL PROCEDURE OutputRequest( DriverIndex : CARDINAL; CONST OutValue : iovalue.Value; QoS : CARDINAL; CONST TimeStamp : drv_def.TUTCStamp );
  PUBLIC VIRTUAL PROCEDURE OutputRequestCompleted();
  PUBLIC VIRTUAL PROCEDURE OutputFinalized( DriverIndex : CARDINAL; OUT ErrorCode : CARDINAL ) : BOOLEAN;

  // helpers
  PROCEDURE InitToDefault();
  PROCEDURE Exists( Name : ARRAY OF WCHAR; CONST Address : inetaddr.INETADDR ) : BOOLEAN;
  PROCEDURE SearchName( Name : ARRAY OF WCHAR; VAR PClientLE : TPClientLE ) : BOOLEAN;
  PROCEDURE SearchNet( REF Clients : list.CList; CONST Address : inetaddr.INETADDR; VAR PClientLE : TPClientLE ) : BOOLEAN;
  PROCEDURE SearchGroup( Name : ARRAY OF WCHAR; VAR PGroupLE : TPGroupLE ) : BOOLEAN;
  PROCEDURE RemoveClientFromGroups( PClientLE : TPClientLE );

  LOCAL PROCEDURE OnConnect( PConnection : netconndispatch.TConnectionHandle; Local : BOOLEAN; Error : CARDINAL );
  LOCAL PROCEDURE OnDisconnect( PConnection : netconndispatch.TConnectionHandle; Local : BOOLEAN; Error : CARDINAL );
  LOCAL PROCEDURE OnReceive( PConnection : netconndispatch.TConnectionHandle; PData : ADDRESS; DataLen : CARDINAL );
END CDriver;

(*================================================================================*)

CLASS IMPLEMENTATION CClient;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE OnJoin( _Connection : netconndispatch.TConnectionHandle );
  BEGIN
    Connection := _Connection;
  END OnJoin;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE OnConnect( _Connection : netconndispatch.TConnectionHandle; Local : BOOLEAN; Error : CARDINAL );
  BEGIN
    // Connection := _Connection;
  END OnConnect;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE OnDisconnect( _Connection : netconndispatch.TConnectionHandle; Local : BOOLEAN; Error : CARDINAL );
  BEGIN
    Connection := _Connection;
  END OnDisconnect;

(*--------------------------------------------------------------------------------*)

BEGIN
  Connection := NIL;
END CClient;

(*================================================================================*)

CLASS IMPLEMENTATION CClientLE;
BEGIN
  PClient := NIL;
  Group[0] := WCHAR( 0 );
  Name[0] := WCHAR( 0 );
END CClientLE;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CGroupLE;
BEGIN
  Name[0] := WCHAR( 0 );
END CGroupLE;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CClientGroupLE;
BEGIN
  PClientLE := NIL;
END CClientGroupLE;

(*================================================================================*)

CLASS IMPLEMENTATION CServer;

(*--------------------------------------------------------------------------------*)

  VIRTUAL PROCEDURE OnConnect( PConnection : netconndispatch.TConnectionHandle; Local : BOOLEAN; Error : CARDINAL );
  BEGIN
    Driver^.OnConnect( PConnection, Local, Error );
  END OnConnect;

(*--------------------------------------------------------------------------------*)

  VIRTUAL PROCEDURE OnDisconnect( PConnection : netconndispatch.TConnectionHandle; Local : BOOLEAN; Error : CARDINAL );
  BEGIN
    Driver^.OnDisconnect( PConnection, Local, Error );
  END OnDisconnect;

(*--------------------------------------------------------------------------------*)

  VIRTUAL PROCEDURE OnReceive( PConnection : netconndispatch.TConnectionHandle; PData : ADDRESS; DataLen : CARDINAL );
  BEGIN
    Driver^.OnReceive( PConnection, PData, DataLen );
  END OnReceive;

(*--------------------------------------------------------------------------------*)

BEGIN
  Connection := netconndispatch.ctDatagram;
  PieceSize := -1;
  Driver := NIL;
END CServer;

(*================================================================================*)

CLASS IMPLEMENTATION CEventLE;
BEGIN
  Storage.Zero( ADR( Event ), SIZE( Event ));
FINALLY
  IF ( Event.Event = evDataReceived2Success ) OR ( Event.Event = evStructReceived2Success ) THEN
    DISPOSE( Event.PPacket );
  END;
END CEventLE;

(*================================================================================*)

CLASS IMPLEMENTATION CDriver;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE Initialize( _RunMode : CARDINAL; CONST SymbolicName : StringsO.CString; CallbackId : ADDRESS; CallbackProc : drv_def.TDriverCallbackW );
  BEGIN
    Init( TRUE );

    SELF.CallbackId := CallbackId;
    SELF.CallbackProc := CallbackProc;
    RunMode := _RunMode;
    Name := SymbolicName;

    Server.Init( TRUE );
  END Initialize;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE ReadParameters( CONST ParametersFilePath : StringsO.CString; CONST Logger : log.CLogger ) : BOOLEAN;

  LABEL
    Fail;
  CONST
    // .PAR section names
    snDevice               = L'NetMsg';
      knKey                = L'key';
      knDelimiter          = L'delimiter';
    // .PAR key names
    snRecordType           = L'record_type';
    snRecord               = L'record';
    // .PAR key names 
    knFields               = L'fields';
      kvBoolean            = L'boolean';
      kvTristate           = L'tristate';
      kvInteger            = L'integer';
      kvFloat              = L'float';
      kvString             = L'string';
    knFirstChannel         = L'first_channel';
    knName                 = L'name';
    knRecordType           ::= snRecordType;

  //----------
  
      PROCEDURE Error( ErrorCode, ErrorLine : CARDINAL );
      BEGIN
         Logger.LogFilePos( log.dlcError, L"", OA( ParametersFilePath.Length-1, ParametersFilePath.rawData ), OAsz( R[ ErrorCode ] ), ErrorLine, 0 );
      END Error;

  //----------

  VAR
    cs : StringsO.CString;
    ChannelIndex : CARDINAL;
    ErrorLine : CARDINAL;
    ES : PTR;
    fs : FIOO.CFileStream;
    I : StringsO.CString;
    i, number : CARDINAL;
    RecordTypes : maps.CStringMap;
    S : StringsO.CString;
    s : ARRAY [0..127] OF WCHAR;
    TS : INIFile.CINIFile;
    tr : TextReader.CTextReader;
    TypeList : lists.TPIntegerList;
    Value : iovalue.TPValue;
    ValueList : lists.TPPtrList;
  BEGIN
      TRY
         fs.FromPath( OA( ParametersFilePath.Length-1, ParametersFilePath.rawData ), FIOO.imOpenRead );
      CATCH : IOO.CIOException DO
         Error( Texts._CannotOpenPar, 0 );
         GOTO Fail;
      END; // TRY
      tr.Stream := ADR( fs );
      IF NOT TS.Load( tr ) THEN
         Error( Texts._CannotOpenPar, 0 );
         GOTO Fail;
      END;
      fs.Close( FALSE );

      InitToDefault();

      IF NOT TS.SetSection( snDevice ) THEN
         IF RunMode = drv_def.drmRun THEN
            Error( Texts._MissingDeviceSection, 0 );
            GOTO Fail;
         ELSE
            RETURN TRUE;
         END;
      END;
      IF TS.GetKeyStr( knKey, OUT ErrorLine, OUT cs ) THEN
         IF cs.Length < 32 THEN
            Error( Texts._KeyTooShort, ErrorLine );
            GOTO Fail;
         ELSE
            INCL( RStatus, rsGlobalKey );
            digest.DigestOA( digest.sha256, OA( cs.Length-1, cs.rawData ), OUT GlobalKey );
         END;
      END;
      IF TS.GetKeyStr( knDelimiter, OUT ErrorLine, OUT cs ) THEN
         IF cs.Length <> 1 THEN
            Error( Texts._DelimiterTooLong, ErrorLine );
            GOTO Fail;
         ELSE
            Delimiter := cs[0];
         END;
      END;

      CASE drv_def.ConfigureLog( TS, REF SELF.Logger, OUT ErrorLine ) OF
      | drv_def.clrUnknownDebugMode :
         Error( Texts._UnknownDebugMode, ErrorLine );
      | drv_def.clrUnknownDebugLevel :
         Error( Texts._UnknownDebugLevel, ErrorLine );
      | drv_def.clrFileDebugMissingFile :
         Error( Texts._FileDebugMissingFile, ErrorLine );
      END; // CASE
    
      // get all record types
      ES := 0;
      WHILE TS.EnumerateSections( REF ES, OUT ErrorLine, OUT s, TRUE ) DO
         IF EQUALS( s, snRecordType ) THEN
            IF NOT TS.GetKeyStr( knName, OUT ErrorLine, OUT S ) THEN
               Error( Texts._MissingNameOfRecordType, ErrorLine );
               GOTO Fail;
            ELSIF RecordTypes.Contains( S ) THEN
               Error( Texts._RecordTypeDuplicated, ErrorLine );
               GOTO Fail;
            ELSE
               TypeList := NEW( lists.CIntegerList );
               RecordTypes.Add( S, TypeList );
            END;
            IF NOT TS.GetKeyStr( knFields, OUT ErrorLine, OUT S ) THEN
               Error( Texts._MissingFieldsOfRecordType, ErrorLine );
               GOTO Fail;
            END;
            i := S.ItemS( StringsO.WCHARS{ L"," }, 0, 0, TRUE, OUT I );
            WHILE i <> -1 DO
               I.Lowerize();
               
               // determine index
               number := I.IndexOfOA( L"[", 0 );
               IF number = -1 THEN // and sequence of types will be created
                  number := 1;
               ELSE
                  I.Substring( number+1, -1, OUT cs );
                  I.Remove( number, -1 );
                  number := cs.IndexOfOA( L"]", 0 );
                  IF number = -1 THEN
                     Error( Texts._MalformedTypeArray, ErrorLine );
                     GOTO Fail;
                  END;
                  cs.Remove( number, -1 );
                  cs.Trim();
                  IF NOT cs.ToINT32( 10, OUT number ) THEN
                     Error( Texts._MalformedArrayRange, ErrorLine );
                     GOTO Fail;
                  ELSIF number < 1 THEN
                     Error( Texts._BadArrayRange, ErrorLine );
                     GOTO Fail;
                  END;
               END;

               I.Trim();
               IF I.EqualsOA( kvBoolean ) THEN
                  TypeList^.Add( INTEGER( iovalue.vtBoolean ), number );
               ELSIF I.EqualsOA( kvTristate ) THEN
                  TypeList^.Add( INTEGER( iovalue.vtTristate ), number );
               ELSIF I.EqualsOA( kvInteger ) THEN
                  TypeList^.Add( INTEGER( iovalue.vtInteger ), number );
               ELSIF I.EqualsOA( kvFloat ) THEN
                  TypeList^.Add( INTEGER( iovalue.vtFloat ), number );
               ELSIF I.EqualsOA( kvString ) THEN
                  TypeList^.Add( INTEGER( iovalue.vtString ), number );
               ELSE
                  Error( Texts._UnknownFieldType, ErrorLine );
                  GOTO Fail;
               END;
               i := S.ItemS( StringsO.WCHARS{ L"," }, i, 0, TRUE, OUT I );
            END; // WHILE
         END;
      END; // WHILE

      // get all records
      ES := 0;
      WHILE TS.EnumerateSections( REF ES, OUT ErrorLine, OUT s, TRUE ) DO
         IF EQUALS( s, snRecord ) THEN
            IF NOT TS.GetKeyStr( knRecordType, OUT ErrorLine, OUT S ) THEN
               Error( Texts._MissingRecordTypeInRecord, ErrorLine );
               GOTO Fail;
            ELSIF NOT RecordTypes.Get( S, OUT TypeList ) THEN
               Error( Texts._UnknownRecordType, ErrorLine );
               GOTO Fail;
            ELSIF NOT TS.GetKeyStr( knName, OUT ErrorLine, OUT S ) THEN
               Error( Texts._MissingNameOfRecord, ErrorLine );
               GOTO Fail;
            ELSIF Records.Contains( S ) THEN
               Error( Texts._RecordDuplicated, ErrorLine );
               GOTO Fail;
            ELSIF NOT TS.GetKeyInt( knFirstChannel, OUT ErrorLine, OUT ChannelIndex ) THEN
               Error( Texts._MissingFirstChannelRecord, ErrorLine );
               GOTO Fail;

            ELSE

               ValueList := NEW( lists.CPtrList );
               TypeList^.Reset();
               WHILE TypeList^.MoveNext() DO
                  IF ChannelIndex = 1 THEN
                     Error( Texts._ChannelOneReserved, ErrorLine );
                     GOTO Fail;
                  END;
                  FOR i := 0 TO CARDINAL( LOPTRLONGWORD( TypeList^.CurrentData )) - 1 DO
                     IF FieldToValue.Contains( ChannelIndex ) THEN
                        Error( Texts._ChannelIndexDuplicated, ErrorLine );
                        GOTO Fail;
                     END;
                     Value := NEW( iovalue.Value );
                     Value^.Type := iovalue.TValueType( TypeList^.Current );
                     ValueList^.Add( Value, 0 );
                     FieldToValue.Add( ChannelIndex, Value );
                     INC( ChannelIndex );
                  END;
               END; // WHILE
               Records.Add( S, ValueList );

            END;
         END;
      END; // WHILE

      // remove temporary structures
      RecordTypes.Reset();
      WHILE RecordTypes.MoveNext() DO
         DISPOSE( lists.TPIntegerList( RecordTypes.CurrentData ));
      END; // WHILE
      RecordTypes.Dispose();

      RETURN TRUE;

   Fail:
      // remove temporary structures
      RecordTypes.Reset();
      WHILE RecordTypes.MoveNext() DO
         DISPOSE( lists.TPIntegerList( RecordTypes.CurrentData ));
      END; // WHILE
      RecordTypes.Dispose();

      RETURN FALSE;
   END ReadParameters;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE QueryErrorCode( ErrorCode : CARDINAL; OUT ErrorText : StringsO.CString ) : BOOLEAN;
   BEGIN
      CASE ErrorCode OF
      | ecDeviceStopped :
         ErrorText.FromOA( OAsz( R[ Texts._E_DeviceStopped ] ));
      ELSE
         RETURN FALSE;
      END; // CASE
      RETURN TRUE;
   END QueryErrorCode;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE EnumerateChannels( REF EnumerateState : LONGWORD; OUT Type : drv_def.TValueType; OUT Direction : drv_def.TDirection; OUT DriverIndex, Count : CARDINAL; OUT HaveDescription : BOOLEAN ): BOOLEAN;
  VAR
    Value : iovalue.TPValue;
  BEGIN
    IF EnumerateState = 0 THEN
      // status channel
      Direction := drv_def.TDirection{drv_def.dirInput};
      DriverIndex := chStatus;
      Type := drv_def.vtLongCard;
    ELSIF NOT FieldToValue.ElementAt( CARDINAL( EnumerateState )-1, OUT DriverIndex, OUT Value ) THEN
      RETURN FALSE;
    ELSE
       Direction := drv_def.TDirection{drv_def.dirInput, drv_def.dirOutput};
       // DriverIndex already set
       Type := drv_def.IOTypeToCWType( Value^.Type );
    END;

    Count := 1;
    HaveDescription := FALSE;
    INC( EnumerateState );

    RETURN TRUE;
  END EnumerateChannels;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE GetChannelDescription( DriverIndex : CARDINAL; OUT Description : StringsO.CString; OUT Id : StringsO.CString ) : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END GetChannelDescription;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE DriverRun();
   VAR
      s : FIO.PathStrW;
   BEGIN
      IF TRStatus{rsRunning} * RStatus <> TRStatus{} THEN
         RETURN;
      END;
      INCL( RStatus, rsRunning );

      Result.Reset( lec.bhBestCase );
      FIO.GetModuleDirW( EMITW( %dll ), OUT s );
      lec.QueryData( s, L"", ADR( cllv.data ), cllv.length, REF Result );

      IF rsListening IN RStatus THEN
         ListenAddress.V6 := FALSE;
         netsrv.StartListen( netsocket.stStream, ListenAddress, NIL, Server.Listener, 0, NIL );
         ListenAddress.V6 := TRUE;
         netsrv.StartListen( netsocket.stStream, ListenAddress, NIL, Server.Listener, 0, NIL );
      END;
   END DriverRun;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE DriverStop();
   BEGIN
      IF TRStatus{rsRunning} * RStatus = TRStatus{} THEN
         RETURN;
      END;
      EXCL( RStatus, rsRunning );

      IF rsListening IN RStatus THEN
         ListenAddress.V6 := FALSE;
         netsrv.StopListenServer( netsocket.stStream, ListenAddress );
         ListenAddress.V6 := TRUE;
         netsrv.StopListenServer( netsocket.stStream, ListenAddress );
      END;
   END DriverStop;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE Dispose();
  VAR
    List : lists.TPPtrList;
    PClientLE : TPClientLE;
    PGroupLE : TPGroupLE;
  BEGIN
    Server.Dispose();
    Packet.Dispose();
    
    EventsLock.Lock();
    Events.Dispose();
    EventsLock.Unlock();

    // kill user records structures
    FieldToValue.Reset();
    WHILE FieldToValue.MoveNext() DO
       DISPOSE( iovalue.TPValue( FieldToValue.CurrentData ));
    END; // WHILE
    FieldToValue.Dispose();
    Records.Reset();
    WHILE Records.MoveNext() DO
       List := lists.TPPtrList( Records.CurrentData );
       IF List <> NIL THEN
         DISPOSE( List );
       END;
    END; // WHILE
    Records.Dispose();

    // kill client/server groups
    ClientsLock.Lock();
    WHILE Groups.GetFirst( OUT PGroupLE ) DO
      PGroupLE^.Clients.Dispose();
      Groups.Remove( PGroupLE );
      DISPOSE( PGroupLE );
    END; // WHILE

    WHILE Clients.GetFirst( OUT PClientLE ) DO
      IF PClientLE^.PClient <> NIL THEN
        PClientLE^.PClient^.Release();
      END;
      Clients.Remove( PClientLE );
      DISPOSE( PClientLE );
    END; // WHILE
    ClientsLock.Unlock();
  END Dispose;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE QueryProc( CONST InValue1, InValue2 : iovalue.Value; OutValueLimit : CARDINAL; OUT OutValue : iovalue.Value );
  LABEL
    DoSend, Error, Success;
  CONST
    structItemSepChar = 9W;
    structItemSep = StringsO.WCHARS{ structItemSepChar };
  VAR
    c, i : CARDINAL;
    Group : ARRAY [0..63] OF WCHAR;
    IAddress : inetaddr.INETADDR;
    len : CARDINAL;
    List : lists.TPPtrList;
    
    Payload : TTransport;
    PPacket : TPPacket;
    PClient : TPClient;
    PClientGroupLE : TPClientGroupLE;
    PClientLE : TPClientLE;
    PELE : TPEventLE;
    PGroupLE : TPGroupLE;
    RAddr : inetaddr.INETADDR;
    RPort : CARDINAL;
    Name : ARRAY [0..63] OF WCHAR;
    n, si : ARRAY [0..63] OF WCHAR;
    SW : StringsO.CString;
    S : StringsO.CString;
    b : BOOLEAN;
    
  //----------

    PROCEDURE PreparePayload( OUT Payload : TTransport ) : BOOLEAN;
    VAR
       Name : ARRAY [0..63] OF WCHAR;
       S : StringsO.CString;
    BEGIN
       SW.ItemSOA( StringsO.WCHARS{ L' ' }, 0, 3, TRUE, OUT Name );
       IF EQUALS( Name, L'record' ) THEN // a record will be sent, not user data
          SW.ItemSOA( StringsO.WCHARS{ L' ' }, 0, 4, TRUE, OUT Name );
          SW.FromOA( Name );
          IF NOT Records.Get( SW, OUT List ) THEN
             SW.FromOA( OAsz( R[ Texts._UnknownRecord ] ));
             RETURN FALSE;
          END;
       
          // construct data
          List^.Reset();
          WHILE List^.MoveNext() DO
             SW.AppendOA( structItemSepChar );
             iovalue.TPValue( List^.Current )^.ToString( OUT S, TRUE );
             SW.Append( S );
          END; // WHILE
          Payload := trStruct;

       ELSE // record not requested, send user data
          SW := InValue2.String;
          Payload := trString;

       END;
       RETURN TRUE;
    END PreparePayload;

  //----------

  BEGIN
    SW := InValue1.String;
    SW.ItemSOA( StringsO.WCHARS{ L' ' }, 0, 0, TRUE, OUT si );
    Result.Inc();

    IF EQUALS( si, L'event' ) THEN
      SW.ItemSOA( StringsO.WCHARS{ L' ' }, 0, 1, TRUE, OUT si );

      IF EQUALS( si, L'count' ) THEN
        EventsLock.Lock();
        c := Events.Count;
        EventsLock.Unlock();

        Logger.LogSC( dldDebug, logPrefix, L"Event.Count ", c );

        OutValue.Integer := c; 
        RETURN;
      
      ELSIF EQUALS( si, L'get' ) THEN
      (*
        IF Result.Counted OR Result.Expired THEN
          Logger.LogS( dldDebug, logPrefix, L"Event.Get clear buffer" );
          Logger.LogS( dldDebug, logPrefix, L"RS- rsEventPending" );

          EventsLock.Lock();
          Events.Dispose();
          EXCL( RStatus, rsEventsPending );
          EventsLock.Unlock();

          GOTO Success;
        END;
        *)

        EventsLock.Lock();
        b := Events.GetFirst( OUT PELE );
        IF b THEN
          Events.Remove( PELE );
        ELSE  
          EXCL( RStatus, rsEventsPending );
        END;
        EventsLock.Unlock();

        IF b THEN
          Logger.LogSC( dldDebug, logPrefix, L"Event.Dequeue ", CARDINAL( PELE^.Event.Event ));

          CASE PELE^.Event.Event OF
          //-----
          | evConnect :
            ClientsLock.Lock();
            IF SearchNet( REF Clients, PELE^.Event.Address, PClientLE ) THEN
              ASSIGN( Name, PClientLE^.Name );
              ASSIGN( Group, PClientLE^.Group );
            ELSE
              Name := L'';
              Group := L'';
            END;
            ClientsLock.Unlock();

            IF Name[0] = L'$' THEN // PClientLE is server stub
               IF PELE^.Event.Local THEN
                 SW.FromOA( L'server_connect' );
               ELSE
                 SW.FromOA( L'client_connect' );
               END;
            ELSE
               IF PELE^.Event.Local THEN
                 SW.FromOA( L'client_connect' );
               ELSE
                 SW.FromOA( L'server_connect' );
               END;
            END;

            SW.AppendOA( Delimiter );

          //-----
          | evDisconnect :
            ClientsLock.Lock();
            IF SearchNet( REF Clients, PELE^.Event.Address, PClientLE ) THEN
              ASSIGN( Name, PClientLE^.Name );
              ASSIGN( Group, PClientLE^.Group );
            ELSIF SearchNet( REF RemovedClients, PELE^.Event.Address, PClientLE ) THEN
              ASSIGN( Name, PClientLE^.Name );
              ASSIGN( Group, PClientLE^.Group );
              RemovedClients.Remove( PClientLE );
              DISPOSE( PClientLE );
            ELSE
              Name := L'';
              Group := L'';
            END;

            IF Name[0] = L'$' THEN // disconnected is server stub
               IF PELE^.Event.Local THEN
                 SW.FromOA( L'server_disconnect' );
               ELSE
                 SW.FromOA( L'client_disconnect' );
               END;
               // finish remove from OnDisconnect
               Clients.Remove( PClientLE );
               DISPOSE( PClientLE );
            ELSE
               IF PELE^.Event.Local THEN
                 SW.FromOA( L'client_disconnect' );
               ELSE
                 SW.FromOA( L'server_disconnect' );
               END;
            END;
            ClientsLock.Unlock();

            SW.AppendOA( Delimiter );

          //-----
          | evDataReceived1 :
            ASSIGN( Name, PELE^.Event.PReceiveClient^.Name );
            ASSIGN( Group, PELE^.Event.PReceiveClient^.Group );
            IF Name[0] = L'$' THEN
              SW.FromOA( L'client_data' );
            ELSE
              SW.FromOA( L'server_data' );
            END;
            SW.AppendOA( Delimiter );

          //-----
          | evStructReceived1 :
            ASSIGN( Name, PELE^.Event.PReceiveClient^.Name );
            ASSIGN( Group, PELE^.Event.PReceiveClient^.Group );
            IF Name[0] = L'$' THEN
              SW.FromOA( L'client_record' );
            ELSE
              SW.FromOA( L'server_record' );
            END;
            SW.AppendOA( Delimiter );

          //-----
          | evDataReceived2Success, evStructReceived2Success :
            CASE PELE^.Event.PPacket^.TR OF
            | trString :
					c := PELE^.Event.PacketLen - hdr;
					IF c = 0 THEN
						SW.Clear();
					ELSE
						SW.FromUTF8( OA( c-1, ADR( PELE^.Event.PPacket^.Data )));
					END;
			   | trStruct :
					c := PELE^.Event.PacketLen - hdr;
					IF c = 0 THEN
						SW.Clear();
					ELSE
						SW.FromUTF8( OA( c-1, ADR( PELE^.Event.PPacket^.Data )));
					END;

					// detach data, name of record will become data
					i := SW.ItemS( structItemSep, 0, 0, FALSE, OUT S );
					IF S.Empty THEN
					   SW.FromOA( L"$empty" );
					ELSIF NOT Records.Get( S, OUT List ) THEN
					   SW.FromOA( L"$unknown " );
					   SW.Append( S );
					ELSE // decompose data
					   
					   List^.Reset();
                  i := SW.ItemS( structItemSep, i, 0, FALSE, OUT S );
                  WHILE ( i <> -1 ) AND List^.MoveNext() DO
                     iovalue.TPValue( List^.Current )^.FromString( S, TRUE );
                     i := SW.ItemS( structItemSep, i, 0, FALSE, OUT S );
                  END; // WHILE
                  SW.ItemS( structItemSep, 0, 0, FALSE, OUT S );
                  SW := S;
					  
		         END;
            END;

          //-----
          | evDataReceived2BadCRC, evStructReceived2BadCRC :
            SW.FromOA( L'$badcrc' );
          END; // CASE

          b := TRUE;
          CASE PELE^.Event.Event OF
          | evConnect, evDisconnect :
            IAddress := PELE^.Event.Address;
          | evDataReceived1, evStructReceived1 :
            IAddress := PELE^.Event.PReceiveClient^.Address;
          ELSE
            b := FALSE;
          END; // CASE
          IF b THEN
            IAddress.GetAddressOA( FALSE, OUT n );
            SW.AppendOA( n ); SW.AppendOA( L"-" );
            Strings.FromCARD32W( IAddress.Port, 10, OUT n );
            SW.AppendOA( n );
          END;

          CASE PELE^.Event.Event OF
          | evConnect, evDisconnect, evDataReceived1, evStructReceived1 :
            SW.AppendOA( Delimiter );
            IF Group[0] <> WCHAR( 0 ) THEN
              SW.AppendOA( Group );
              SW.AppendOA( L"." );
            END;
            SW.AppendOA( Name );
          END;

          CASE PELE^.Event.Event OF
          | evConnect, evDisconnect :
            SW.AppendOA( Delimiter );
            Strings.FromCARD32W( PELE^.Event.Error, 10, OUT n );
            SW.AppendOA( n );
          END;

          OutValue.String := SW;
          IF SW.Length < OutValueLimit THEN
            DISPOSE( PELE );
          ELSE // wait for longer string, enter record back
            Logger.LogS( dldDebug, logPrefix, L"Event.Enqueue back" );

            EventsLock.Lock();
            Events.InsertFirst( PELE );
            EventsLock.Unlock();
          END;
          RETURN;

        ELSE
          Logger.LogS( dldDebug, logPrefix, L"RS- rsEventPending" );

          GOTO Success;
        END;
        
      ELSE
        SW.FromOA( OAsz( R[ Texts._UnrecognizedEventCommand ] ));
        GOTO Error;
      END;

    ELSIF EQUALS( si, L'server' ) THEN
      SW.ItemSOA( StringsO.WCHARS{ L' ' }, 0, 1, TRUE, OUT si );

      IF EQUALS( si, L'run' ) THEN
        IF TRStatus{rsListening} * RStatus <> TRStatus{} THEN
          GOTO Success;
        END;
        ListenAddress.V6 := FALSE;
        IF netsrv.StartListen( netsocket.stStream, ListenAddress, NIL, Server.Listener, 0, NIL ) <> 0 THEN
          SW.FromOA( OAsz( R[ Texts._ListenFailure ] ));
          GOTO Error;
        END;
        ListenAddress.V6 := TRUE;
        netsrv.StartListen( netsocket.stStream, ListenAddress, NIL, Server.Listener, 0, NIL );
        INCL( RStatus, rsListening );

      ELSIF EQUALS( si, L'stop' ) THEN
        IF TRStatus{rsListening} * RStatus = TRStatus{} THEN
          GOTO Success;
        END;
        EXCL( RStatus, rsListening );
        ListenAddress.V6 := FALSE;
        netsrv.StopListenServer( netsocket.stStream, ListenAddress );
        ListenAddress.V6 := TRUE;
        netsrv.StopListenServer( netsocket.stStream, ListenAddress );

      ELSIF EQUALS( si, L'port' ) THEN
        SW.ItemSOA( StringsO.WCHARS{ L' ' }, 0, 2, TRUE, OUT n );
        IF NOT Strings.ToCARD32W( n, 10, OUT c ) OR ( c > 65535 ) THEN
          SW.FromOA( OAsz( R[ Texts._BadPortNumber ] ));
          GOTO Error;
        END;
        IF rsListening IN RStatus THEN
          ListenAddress.V6 := FALSE;
          netsrv.StopListenServer( netsocket.stStream, ListenAddress );
          ListenAddress.V6 := TRUE;
          netsrv.StopListenServer( netsocket.stStream, ListenAddress );
          ListenAddress.Port := c;
          ListenAddress.V6 := FALSE;
          netsrv.StartListen( netsocket.stStream, ListenAddress, NIL, Server.Listener, 0, NIL );
          ListenAddress.V6 := TRUE;
          netsrv.StartListen( netsocket.stStream, ListenAddress, NIL, Server.Listener, 0, NIL );
        ELSE
          ListenAddress.Port := c;
        END;

      #if DEBUG #then
      ELSIF EQUALS( si, L'disconnect' ) THEN
         SW.ItemSOA( StringsO.WCHARS{ L' ' }, 0, 2, TRUE, OUT Name );

         IF Name[0] <> L'$' THEN
            GOTO Error;
         END;
         IF NOT SearchName( Name, PClientLE ) THEN
            SW.FromOA( OAsz( R[ Texts._UnknownClient ] ));
            GOTO Error;
         END;
         PClientLE^.PClient^.Disconnect( PClientLE^.PClient^.Connection );
      #endif

      ELSIF EQUALS( si, L'send' ) THEN
        SW.ItemSOA( StringsO.WCHARS{ L' ' }, 0, 2, TRUE, OUT Name );

        ClientsLock.Lock();
        IF EQUALS( Name, L'all' ) THEN
          PClientLE := NIL;
        ELSIF Name[0] <> L'$' THEN
          SW.FromOA( OAsz( R[ Texts._UnknownClient ] ));
          ClientsLock.Unlock();
          GOTO Error;
        ELSIF NOT SearchName( Name, PClientLE ) THEN
          SW.FromOA( OAsz( R[ Texts._UnknownClient ] ));
          ClientsLock.Unlock();
          GOTO Error;
        END;
        ClientsLock.Unlock();

        IF FALSE AND ( Result.Counted OR Result.Expired ) THEN
          GOTO Success;
        ELSIF NOT PreparePayload( OUT Payload ) THEN
          GOTO Error;
        END;

        len := hdr + SW.Length << 2; 
        IF Packet.Size < len THEN
          Packet.Size := ( len >> 4 + 1 ) << 4;
        END;
        PPacket := TPPacket( Packet.Data );
        PPacket^.TR := Payload;
        SW.ToUTF8( OUT OA( len-hdr-1, ADR( PPacket^.Data )), OUT len );
        INC( len, hdr );
        PPacket^.CRC := 0;
        PPacket^.CRC := crc.crc32( crc.crc32i, OA( len-1, PPacket ));
        IF rsGlobalKey IN RStatus THEN
          rijndael.Encrypt( rijndael.cphmStreamEncrypt, rijndael.rkl256, ck, GlobalKey, OA( len-1, PPacket ), OUT OA( len-1, PPacket ), OUT len );
        END;

        IF PClientLE <> NIL THEN // send single client
          PClientLE^.PClient^.Send( PClientLE^.PClient^.Connection, 0, PPacket, len );
        ELSE // send all clients
          ClientsLock.Lock();
          b := Clients.GetFirst( OUT PClientLE );
          WHILE b DO
            IF ( PClientLE^.PClient <> NIL ) AND ( PClientLE^.Name[0] = L'$' ) AND ( PClientLE^.Group[0] <> L' ' ) THEN
              PClientLE^.PClient^.Send( PClientLE^.PClient^.Connection, 0, PPacket, len );
            END;
            b := Clients.NextOf( PClientLE, OUT PClientLE );
          END; // WHILE
          ClientsLock.Unlock();
        END;

      ELSE
        SW.FromOA( OAsz( R[ Texts._UnrecognizedServerCommand ] ));
        GOTO Error;
      END;
      GOTO Success;

    ELSIF EQUALS( si, L'group' ) THEN
      SW.ItemSOA( StringsO.WCHARS{ L' ' }, 0, 1, TRUE, OUT si );
      SW.ItemSOA( StringsO.WCHARS{ L' ' }, 0, 2, TRUE, OUT Name );

      IF EQUALS( si, L'create' ) THEN
        ClientsLock.Lock();

        IF SearchGroup( Name, PGroupLE ) THEN
          SW.FromOA( OAsz( R[ Texts._GroupAlreadyExists ] ));
          ClientsLock.Unlock();
          GOTO Error;
        END;
        NEW( PGroupLE );
        ASSIGN( PGroupLE^.Name, Name );
        Groups.Append( PGroupLE );

        ClientsLock.Unlock();
      
      ELSIF EQUALS( si, L'connect' ) THEN
        ClientsLock.Lock();

        IF NOT SearchGroup( Name, PGroupLE ) THEN
          SW.FromOA( OAsz( R[ Texts._UnknownGroup ] ));
          ClientsLock.Unlock();
          GOTO Error;
        END;
        b := PGroupLE^.Clients.GetFirst( OUT PClientGroupLE );
        LOOP
          PClientGroupLE^.PClientLE^.PClient^.Connect( PClientGroupLE^.PClientLE^.PClient^.Connection );
          b := PGroupLE^.Clients.NextOf( PClientGroupLE, OUT PClientGroupLE );
        END; // WHILE

        ClientsLock.Unlock();

      ELSIF EQUALS( si, L'disconnect' ) THEN
        ClientsLock.Lock();

        IF NOT SearchGroup( Name, PGroupLE ) THEN
          SW.FromOA( OAsz( R[ Texts._UnknownGroup ] ));
          ClientsLock.Unlock();
          GOTO Error;
        END;
        b := PGroupLE^.Clients.GetFirst( OUT PClientGroupLE );
        LOOP
          PClientGroupLE^.PClientLE^.PClient^.Disconnect( PClientGroupLE^.PClientLE^.PClient^.Connection );
          b := PGroupLE^.Clients.NextOf( PClientGroupLE, OUT PClientGroupLE );
        END; // WHILE

        ClientsLock.Unlock();

      ELSIF EQUALS( si, L'send' ) THEN
        ClientsLock.Lock();

        IF NOT SearchGroup( Name, PGroupLE ) THEN
          SW.FromOA( OAsz( R[ Texts._UnknownGroup ] ));
          ClientsLock.Unlock();
          GOTO Error;
        END;

        ClientsLock.Unlock();

        IF FALSE AND ( Result.Counted OR Result.Expired ) THEN
          GOTO Success;
        ELSIF NOT PreparePayload( OUT Payload ) THEN
          GOTO Error;
        END;

        len := hdr + SW.Length << 2; 
        IF Packet.Size < len THEN
          Packet.Size := ( len >> 4 + 1 ) << 4;
        END;
        PPacket := TPPacket( Packet.Data );
        PPacket^.TR := Payload;
        SW.ToUTF8( OUT OA( len-hdr-1, ADR( PPacket^.Data )), OUT len );
        INC( len, hdr );
        PPacket^.CRC := 0;
        PPacket^.CRC := crc.crc32( crc.crc32i, OA( len-1, PPacket ));
        IF rsGlobalKey IN RStatus THEN
          rijndael.Encrypt( rijndael.cphmStreamEncrypt, rijndael.rkl256, ck, GlobalKey, OA( len-1, PPacket ), OUT OA( len-1, PPacket ), OUT len );
        END;

        ClientsLock.Lock();

        b := PGroupLE^.Clients.GetFirst( OUT PClientGroupLE );
        WHILE b DO
          IF PClientGroupLE^.PClientLE <> NIL THEN
            PClientGroupLE^.PClientLE^.PClient^.Send( PClientGroupLE^.PClientLE^.PClient^.Connection, 0, PPacket, len );
          END;
          b := PGroupLE^.Clients.NextOf( PClientGroupLE, OUT PClientGroupLE );
        END; // WHILE

        ClientsLock.Unlock();

      ELSE
        SW.FromOA( OAsz( R[ Texts._UnrecognizedGroupCommand ] ));
        GOTO Error;
      END;
      GOTO Success;

    ELSIF EQUALS( si, L'client' ) THEN
      SW.ItemSOA( StringsO.WCHARS{ L' ' }, 0, 1, TRUE, OUT si );
      SW.ItemSOA( StringsO.WCHARS{ L' ' }, 0, 2, TRUE, OUT Name ); // client id

      IF Name[0] = L'$' THEN
        SW.FromOA( OAsz( R[ Texts._ClientNameReserved ] ));
        GOTO Error;

      ELSIF EQUALS( si, L'create' ) THEN
        SW.ItemSOA( StringsO.WCHARS{ L' ' }, 0, 3, TRUE, OUT si ); // server
        c := Strings.IndexOfCharW( si, L'-', 0 );
        IF c = MAX( CARDINAL ) THEN
          RPort := 6001;
        ELSE
          Strings.SubstringW( si, c+1, MAX( CARDINAL ), OUT n );
          IF NOT Strings.ToCARD32W( n, 10, OUT RPort ) THEN
            SW.FromOA( OAsz( R[ Texts._BadPortNumber ] ));
            GOTO Error;
          END;
          si[c] := WCHAR( 0 );
        END;
        IF NOT dns.NameToAddressWait( si, RPort, 1000, OUT OA( 0, ADR( RAddr ))) THEN
          SW.FromOA( L"Bad client name/IP address" );
          GOTO Error;
        END;

        ClientsLock.Lock();

        IF Exists( Name, RAddr ) THEN
          SW.FromOA( OAsz( R[ Texts._ClientAlreadyExists ] ));
          ClientsLock.Unlock();
          GOTO Error;
        END;

        NEW( PClientLE );
        c := Strings.IndexOfCharW( Name, L'.', 0 );
        IF c = MAX( CARDINAL ) THEN
          ASSIGN( PClientLE^.Name, Name );
        ELSE
          Strings.SubstringW( Name, c+1, MAX( CARDINAL ), OUT PClientLE^.Name );
          Name[c] := WCHAR( 0 );
          ASSIGN( PClientLE^.Group, Name );
          IF NOT SearchGroup( Name, PGroupLE ) THEN
            NEW( PGroupLE );
            ASSIGN( PGroupLE^.Name, Name );
            Groups.Append( PGroupLE );
          END;
          NEW( PClientGroupLE );
          PClientGroupLE^.PClientLE := PClientLE;
          PGroupLE^.Clients.Append( PClientGroupLE );
        END;
        PClientLE^.Address := RAddr;
        NEW( PClientLE^.PClient );
        Clients.Append( PClientLE );

        ClientsLock.Unlock();

        PClientLE^.PClient^.BindDispatcher( ADR( Server ));
        PClientLE^.PClient^.Join( RAddr );

      ELSIF EQUALS( si, L'connect' ) THEN
        ClientsLock.Lock();

        IF NOT SearchName( Name, PClientLE ) THEN
          SW.FromOA( OAsz( R[ Texts._UnknownClient ] ));
          ClientsLock.Unlock();
          GOTO Error;
        END;
        PClientLE^.PClient^.Connect( PClientLE^.PClient^.Connection );

        ClientsLock.Unlock();

      ELSIF EQUALS( si, L'disconnect' ) THEN
        ClientsLock.Lock();

        IF NOT SearchName( Name, PClientLE ) THEN
          SW.FromOA( OAsz( R[ Texts._UnknownClient ] ));
          ClientsLock.Unlock();
          GOTO Error;
        END;
        PClientLE^.PClient^.Disconnect( PClientLE^.PClient^.Connection );

        ClientsLock.Unlock();

      ELSIF EQUALS( si, L'remove' ) THEN
        ClientsLock.Lock();

        IF Name[0] = L'$' THEN
          SW.FromOA( OAsz( R[ Texts._ClientNameReserved ] ));
          ClientsLock.Unlock();
          GOTO Error;
        ELSIF NOT SearchName( Name, PClientLE ) THEN
          SW.FromOA( OAsz( R[ Texts._UnknownClient ] ));
          ClientsLock.Unlock();
          GOTO Error;
        END;

        Clients.Remove( PClientLE );
        RemoveClientFromGroups( PClientLE );
        PClient := PClientLE^.PClient;
        // removed clients store data to allow notify correct information
        RemovedClients.Append( PClientLE );

        ClientsLock.Unlock();

        PClient^.Disconnect( PClient^.Connection );
        PClient^.Leave( PClient^.Connection );
        PClient^.Release();

      ELSIF EQUALS( si, L'join' ) THEN
        ClientsLock.Lock();

        IF NOT SearchName( Name, PClientLE ) THEN
          SW.FromOA( OAsz( R[ Texts._UnknownClient ] ));
          ClientsLock.Unlock();
          GOTO Error;
        END;
        SW.ItemSOA( StringsO.WCHARS{ L' ' }, 0, 3, TRUE, OUT Name ); // group id
        IF NOT SearchGroup( Name, PGroupLE ) THEN
          SW.FromOA( OAsz( R[ Texts._UnknownGroup ] ));
          ClientsLock.Unlock();
          GOTO Error;
        END;
        b := PGroupLE^.Clients.GetFirst( OUT PClientGroupLE );
        LOOP
          IF NOT b THEN
            NEW( PClientGroupLE );
            PClientGroupLE^.PClientLE := PClientLE;
            PGroupLE^.Clients.Append( PClientGroupLE );
            EXIT;
          ELSIF PClientGroupLE^.PClientLE = PClientLE THEN
            EXIT;
          END;
          b := PGroupLE^.Clients.NextOf( PClientGroupLE, OUT PClientGroupLE );
        END; // WHILE

        ClientsLock.Unlock();

      ELSIF EQUALS( si, L'leave' ) THEN
        ClientsLock.Lock();

        IF NOT SearchName( Name, PClientLE ) THEN
          SW.FromOA( OAsz( R[ Texts._UnknownClient ] ));
          ClientsLock.Unlock();
          GOTO Error;
        END;
        SW.ItemSOA( StringsO.WCHARS{ L' ' }, 0, 3, TRUE, OUT Name ); // group id
        IF NOT SearchGroup( Name, PGroupLE ) THEN
          SW.FromOA( OAsz( R[ Texts._UnknownGroup ] ));
          ClientsLock.Unlock();
          GOTO Error;
        END;
        b := PGroupLE^.Clients.GetFirst( OUT PClientGroupLE );
        LOOP
          IF NOT b THEN
            EXIT;
          ELSIF PClientGroupLE^.PClientLE = PClientLE THEN
            PGroupLE^.Clients.Remove( PClientGroupLE );
            DISPOSE( PClientGroupLE );
            EXIT;
          END;
          b := PGroupLE^.Clients.NextOf( PClientGroupLE, OUT PClientGroupLE );
        END; // WHILE

        ClientsLock.Unlock();

      ELSIF EQUALS( si, L'send' ) THEN
        ClientsLock.Lock();

        IF EQUALS( Name, L'all' ) THEN
          PClientLE := NIL;
        ELSIF Name[0] = L'$' THEN
          SW.FromOA( OAsz( R[ Texts._UnknownClient ] ));
          ClientsLock.Unlock();
          GOTO Error;
        ELSIF NOT SearchName( Name, PClientLE ) THEN
          SW.FromOA( OAsz( R[ Texts._UnknownClient ] ));
          ClientsLock.Unlock();
          GOTO Error;
        END;

        ClientsLock.Unlock();

        IF FALSE AND ( Result.Counted OR Result.Expired ) THEN
          GOTO Success;
        ELSIF NOT PreparePayload( OUT Payload ) THEN
          GOTO Error;
        END;

        len := hdr + SW.Length << 2; 
        IF Packet.Size < len THEN
          Packet.Size := ( len >> 4 + 1 ) << 4;
        END;
        PPacket := TPPacket( Packet.Data );
        PPacket^.TR := Payload;
        SW.ToUTF8( OUT OA( len-hdr-1, ADR( PPacket^.Data )), OUT len );
        INC( len, hdr );
        PPacket^.CRC := 0;
        PPacket^.CRC := crc.crc32( crc.crc32i, OA( len-1, PPacket ));
        IF rsGlobalKey IN RStatus THEN
          rijndael.Encrypt( rijndael.cphmStreamEncrypt, rijndael.rkl256, ck, GlobalKey, OA( len-1, PPacket ), OUT OA( len-1, PPacket ), OUT len );
        END;

        IF PClientLE = NIL THEN // send all clients
          ClientsLock.Lock();
          b := Clients.GetFirst( OUT PClientLE );
          WHILE b DO
            IF ( PClientLE^.PClient <> NIL ) AND ( PClientLE^.Name[0] <> L'$' ) THEN
              PClientLE^.PClient^.Send( PClientLE^.PClient^.Connection, 0, PPacket, len );
            END;
            b := Clients.NextOf( PClientLE, OUT PClientLE );
          END; // WHILE
          ClientsLock.Unlock();
        ELSE
          PClientLE^.PClient^.Send( PClientLE^.PClient^.Connection, 0, PPacket, len );
        END;

      ELSE
        SW.FromOA( OAsz( R[ Texts._UnrecognizedClientCommand ] ));
        GOTO Error;
      END;
      GOTO Success;

    // ELSIF EQUALS( si, L'data' ) THEN
 
    ELSE
      SW.FromOA( OAsz( R[ Texts._UnrecognizedCommand ] ));
    END;

  Error:
    OutValue.String := SW;
    RETURN;

  Success:
    SW.Clear();
    OutValue.String := SW;
  END QueryProc;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE DriverProc( Func, Param1, Param2, Param3, Param4 : CARDINAL );
   BEGIN
   END DriverProc;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE InputRequestStart();
   BEGIN
   END InputRequestStart;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE InputRequest( DriverIndex : CARDINAL );
   BEGIN
      Result.Inc(); // locked by self
   END InputRequest;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE InputRequestCompleted();
   BEGIN
   END InputRequestCompleted;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE InputFinalized( DriverIndex : CARDINAL; OUT ErrorCode : CARDINAL ) : BOOLEAN;
   VAR
      Finalized : BOOLEAN;
   BEGIN
      Finalized := TRUE;
      ErrorCode := 0;
      IF DriverIndex = chStatus THEN
         // return always OK
      ELSIF TRStatus{rsRunning} * RStatus = TRStatus{} THEN
         ErrorCode := ecDeviceStopped;
      ELSIF FALSE AND ( Result.Expired OR Result.Counted ) THEN // locked by self
         RETURN FALSE;
      ELSE
         ////
      END;
      RETURN Finalized;
   END InputFinalized;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE InputOOBDataQuery( REF EnumerateState : LONGWORD; OUT DriverIndex : CARDINAL ) : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END InputOOBDataQuery;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE GetInput( DriverIndex : CARDINAL; InValueLimit : CARDINAL; OUT InValue : iovalue.Value; OUT QoS : CARDINAL; OUT TimeStamp : drv_def.TUTCStamp; OUT ErrorCode : CARDINAL );
   VAR
      Value : iovalue.TPValue;
   BEGIN
      ErrorCode := drv_def.ecSuccess;
      QoS := drv_def.qosGood;

      IF DriverIndex = chStatus THEN
         IF FALSE AND ( Result.Counted OR Result.Expired ) THEN // locked by self
            EXCL( RStatus, rsValid );
         ELSE
            INCL( RStatus, rsValid );
         END;
         InValue.Integer := CARDINAL( RStatus * rssUser );

      ELSIF NOT FieldToValue.Get( DriverIndex, OUT Value ) THEN
         ErrorCode := drv_def.ecUnknownElement;
      
      ELSE
         InValue := Value^;
      END;
   END GetInput;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OutputRequestStart();
   BEGIN
   END OutputRequestStart;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OutputRequest( DriverIndex : CARDINAL; CONST OutValue : iovalue.Value; QoS : CARDINAL; CONST TimeStamp : drv_def.TUTCStamp );
   VAR
      Value : iovalue.TPValue;
   BEGIN
      Result.Inc(); // locked by self
      IF FieldToValue.Get( DriverIndex, OUT Value ) THEN
         Value^ := OutValue;
      END;
   END OutputRequest;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE OutputRequestCompleted();
  BEGIN
  END OutputRequestCompleted;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE OutputFinalized( DriverIndex : CARDINAL; OUT ErrorCode : CARDINAL ) : BOOLEAN;
  BEGIN
    ErrorCode := 0;
    RETURN TRUE OR NOT Result.Expired AND NOT Result.Counted; // locked by self
  END OutputFinalized;

(*--------------------------------------------------------------------------------*)

  PROCEDURE InitToDefault();
  BEGIN
    Delimiter := L":";
  END InitToDefault;

(*--------------------------------------------------------------------------------*)

  PROCEDURE Exists( Name : ARRAY OF WCHAR; CONST Address : inetaddr.INETADDR ) : BOOLEAN;
  VAR
    PClientLE : TPClientLE;
    b : BOOLEAN;
  BEGIN
    b := Clients.GetFirst( OUT PClientLE );
    WHILE b DO
      IF PClientLE^.Address = Address THEN
        RETURN TRUE;
      ELSIF EQUALS( PClientLE^.Name, Name ) THEN
        RETURN TRUE;
      END;
      b := Clients.NextOf( PClientLE, OUT PClientLE );
    END;  // WHILE
    RETURN FALSE;
  END Exists;

(*--------------------------------------------------------------------------------*)

  PROCEDURE SearchName( Name : ARRAY OF WCHAR; VAR PClientLE : TPClientLE ) : BOOLEAN;
  VAR
    LPClientLE : TPClientLE;
    b : BOOLEAN;
  BEGIN
    b := Clients.GetFirst( OUT LPClientLE );
    WHILE b DO
      IF LPClientLE^.PClient = NIL THEN // disconnected server stub
      ELSIF EQUALS( LPClientLE^.Name, Name ) THEN
        PClientLE := LPClientLE;
        RETURN TRUE;
      END;
      b := Clients.NextOf( LPClientLE, OUT LPClientLE );
    END;  // WHILE
    RETURN FALSE;
  END SearchName;

(*--------------------------------------------------------------------------------*)

  PROCEDURE SearchNet( REF _Clients : list.CList; CONST Address : inetaddr.INETADDR; VAR PClientLE : TPClientLE ) : BOOLEAN;
  VAR
    LPClientLE : TPClientLE;
    b : BOOLEAN;
  BEGIN
    b := _Clients.GetFirst( OUT LPClientLE );
    WHILE b DO
      IF LPClientLE^.Address = Address THEN
        PClientLE := LPClientLE;
        RETURN TRUE;
      END;
      b := _Clients.NextOf( LPClientLE, OUT LPClientLE );
    END;  // WHILE
    RETURN FALSE;
  END SearchNet;

(*--------------------------------------------------------------------------------*)

  PROCEDURE SearchGroup( Name : ARRAY OF WCHAR; VAR PGroupLE : TPGroupLE ) : BOOLEAN;
  VAR
    LPGroupLE : TPGroupLE;
    b : BOOLEAN;
  BEGIN
    b := Groups.GetFirst( OUT LPGroupLE );
    WHILE b DO
      IF EQUALS( LPGroupLE^.Name, Name ) THEN
        PGroupLE := LPGroupLE;
        RETURN TRUE;
      END;
      b := Groups.NextOf( LPGroupLE, OUT LPGroupLE );
    END;  // WHILE
    RETURN FALSE;
  END SearchGroup;

(*--------------------------------------------------------------------------------*)

  PROCEDURE RemoveClientFromGroups( PClientLE : TPClientLE );
  VAR
    PGroupLE : TPGroupLE;
    PClientGroupLE, PN : TPClientGroupLE;
    b : BOOLEAN;
  BEGIN
    b := Groups.GetFirst( OUT PGroupLE );
    WHILE b DO
      b := PGroupLE^.Clients.GetFirst( OUT PClientGroupLE );
      WHILE b DO
        b := PGroupLE^.Clients.NextOf( PClientGroupLE, OUT PN );
        IF PClientGroupLE^.PClientLE = PClientLE THEN
          PGroupLE^.Clients.Remove( PClientGroupLE );
          DISPOSE( PClientGroupLE );
        END;
        PClientGroupLE := PN;
      END; // WHILE
      b := Groups.NextOf( PGroupLE, OUT PGroupLE );
    END; // WHILE
  END RemoveClientFromGroups;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE OnConnect( PConnection : netconndispatch.TConnectionHandle; Local : BOOLEAN; Error : CARDINAL );
  VAR
    b : BOOLEAN;
    len : CARDINAL;
    PPacket : TPPacket := Packet.Data;
    PClientLE : TPClientLE;
    PELE : TPEventLE;
  BEGIN
    // OK, send self id if I am Local, create stub if I am remote
    IF Local THEN // local connect
      NEW( PELE );
      PELE^.Event.Event := evConnect;
      PELE^.Event.Local := Local;
      PELE^.Event.Address := PConnection^.RemoteAddress;
      PELE^.Event.Error := Error;

      EventsLock.Lock();
      Events.Append( PELE );
      EventsLock.Unlock();

      Logger.LogSC( dldDebug, logPrefix, L"Event.Add evConnect/client ", CARDINAL( evConnect ));

      ClientsLock.Lock();
      b := SearchNet( REF Clients, PELE^.Event.Address, PClientLE );
      ClientsLock.Unlock();
      IF b THEN

        len := LENGTH( PClientLE^.Group ) << 1;
        PPacket^.TR := trGroup;
        ASSIGN( PPacket^.Group, PClientLE^.Group );
        INC( len, hdr );
        PPacket^.Length := len;
        PPacket^.CRC := 0;
        PPacket^.CRC := crc.crc32( crc.crc32i, OA( len-1, PPacket ));
        IF rsGlobalKey IN RStatus THEN
          rijndael.Encrypt( rijndael.cphmStreamEncrypt, rijndael.rkl256, ck, GlobalKey, OA( len-1, PPacket ), OUT OA( len-1, PPacket ), OUT len );
        END;

        PClientLE^.PClient^.Send( PClientLE^.PClient^.Connection, 0, PPacket, len );
      END;

    ELSE // remote connect
      Logger.LogSC( dldDebug, logPrefix, L"Remote connection detected: ", CARDINAL( RStatus ));

      ClientsLock.Lock();

      IF SearchNet( REF Clients, PConnection^.RemoteAddress, PClientLE ) THEN
        // a previous one exists, strange, but reuse it
      ELSE
        NEW( PClientLE );
      END;
      Strings.FromCARD64W( CARD64( PClientLE ), 16, OUT PClientLE^.Name );
      Strings.PrependW( REF PClientLE^.Name, L'$' );
      PClientLE^.Group := L' ';
      PClientLE^.Address := PConnection^.RemoteAddress;
      Clients.Append( PClientLE );
      NEW( PClientLE^.PClient );

      ClientsLock.Unlock();

      PClientLE^.PClient^.BindDispatcher( ADR( Server ));
      PClientLE^.PClient^.Connection := PConnection;

    END;

    EventsLock.Lock();
    IF rsEventsPending IN RStatus THEN
      EventsLock.Unlock();
      RETURN;
    ELSE
      INCL( RStatus, rsEventsPending );
    END;
    EventsLock.Unlock();
    Logger.LogS( dldDebug, logPrefix, L"RS+ rsEventPending, fire dcfException (1)" );

    CallbackProc( CallbackId, drv_def.dcfException, NIL );
  END OnConnect;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE OnDisconnect( PConnection : netconndispatch.TConnectionHandle; Local : BOOLEAN; Error : CARDINAL );
  VAR
    PClientLE : TPClientLE;
    PELE : TPEventLE;
  BEGIN
    NEW( PELE );
    PELE^.Event.Event := evDisconnect;
    PELE^.Event.Local := Local;
    PELE^.Event.Address := PConnection^.RemoteAddress;
    PELE^.Event.Error := Error;

    EventsLock.Lock();
    Events.Append( PELE );
    EventsLock.Unlock();

    Logger.LogSC( dldDebug, logPrefix, L"Event.Add evDisconnect", CARDINAL( evDisconnect ));

    // remove remote client stub
    ClientsLock.Lock();

    IF SearchNet( REF Clients, PELE^.Event.Address, PClientLE ) AND ( PClientLE^.Name[0] = L'$' ) THEN
      // remove client from groups
      RemoveClientFromGroups( PClientLE );

      // remove remote stub itself
      PClientLE^.PClient^.Release();
      PClientLE^.PClient := NIL;
      // client cannot be removed here; it will be needed for event procesing
      // Clients.Remove();
      // DISPOSE( PClientLE );
    END;

    ClientsLock.Unlock();

    EventsLock.Lock();
    IF rsEventsPending IN RStatus THEN
      EventsLock.Unlock();
      RETURN;
    ELSE
      INCL( RStatus, rsEventsPending );
    END;
    EventsLock.Unlock();
    Logger.LogS( dldDebug, logPrefix, L"RS+ rsEventPending, fire dcfException (2)" );

    CallbackProc( CallbackId, drv_def.dcfException, NIL );
  END OnDisconnect;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE OnReceive( PConnection : netconndispatch.TConnectionHandle; PData : ADDRESS; DataLen : CARDINAL );
  VAR
    b : BOOLEAN;
    c : CARDINAL;
    CRC : CARDINAL;
    CRCValid : BOOLEAN;
    Name : ARRAY [0..79] OF WCHAR;
    PClientLE : TPClientLE := NIL;
    PClientGroupLE : TPClientGroupLE;
    PELE : TPEventLE;
    PGroupLE : TPGroupLE;
  BEGIN
    IF rsGlobalKey IN RStatus THEN
      rijndael.Decrypt( rijndael.cphmStreamDecrypt, rijndael.rkl256, ck, GlobalKey, OA( DataLen-1, PData ), OUT OA( DataLen-1, PData ), OUT c );
    END;
    CRC := TPPacket( PData )^.CRC; TPPacket( PData )^.CRC := 0;
    CRCValid := crc.crc32( crc.crc32i, OA( DataLen-1, PData )) = CRC;

    Logger.LogSC( dldDebug, logPrefix, L"OnReceive bytes ", DataLen );

    CASE TPPacket( PData )^.TR OF
    | trGroup :
      ClientsLock.Lock();

      IF NOT SearchNet( REF Clients, PConnection^.RemoteAddress, PClientLE ) THEN
        Logger.LogS( dldError, logPrefix, L"Connection for group data not found, leaving receiving" );
        ClientsLock.Unlock();
        RETURN;
      
      ELSIF NOT CRCValid THEN
        PClientLE^.PClient^.Disconnect( PConnection );

        Logger.LogS( dldTrace, logPrefix, L"Disconnect, bad CRC" );
        ClientsLock.Unlock();
        RETURN;

      ELSIF TPPacket( PData )^.Length = hdr THEN
        c := 0;
      ELSE
        c := ( TPPacket( PData )^.Length - hdr ) >> 1;
        Strings.MoveW( ADR( TPPacket( PData )^.Group ), ADR( Name ), c );
      END;
      Name[c] := WCHAR( 0 );
      Strings.PrependW( REF Name, L'$' );
      IF NOT SearchGroup( Name, PGroupLE ) THEN
        NEW( PGroupLE );
        ASSIGN( PGroupLE^.Name, Name );
        Groups.Append( PGroupLE );
      END;
      NEW( PClientGroupLE );
      PClientGroupLE^.PClientLE := PClientLE;
      ASSIGN( PClientGroupLE^.PClientLE^.Group, Name );
      PGroupLE^.Clients.Append( PClientGroupLE );

      ClientsLock.Unlock();

      // remote connect
      NEW( PELE );
      PELE^.Event.Event := evConnect;
      PELE^.Event.Local := FALSE;
      PELE^.Event.Address := PConnection^.RemoteAddress;
      PELE^.Event.Error := 0;

      Logger.LogSC( dldDebug, logPrefix, L"Event.Add evConnect/remote ", CARDINAL( evConnect ));

      EventsLock.Lock();
      Events.Append( PELE );
      IF rsEventsPending IN RStatus THEN
        EventsLock.Unlock();
        RETURN;
      ELSE
        INCL( RStatus, rsEventsPending );
      END;
      EventsLock.Unlock();
      Logger.LogS( dldDebug, logPrefix, L"RS+ rsEventPending, fire dcfException (3)" );

      CallbackProc( CallbackId, drv_def.dcfException, NIL );

    | trString, trStruct :
      NEW( PELE );
      IF TPPacket( PData )^.TR = trString THEN
         PELE^.Event.Event := evDataReceived1;
         Logger.LogSC( dldDebug, logPrefix, L"Event.Add evDataReceived1 ", CARDINAL( evDataReceived1 ));
      ELSE
         PELE^.Event.Event := evStructReceived1;
         Logger.LogSC( dldDebug, logPrefix, L"Event.Add evStructReceived1 ", CARDINAL( evStructReceived1 ));
      END;
      
      ClientsLock.Lock();
      b := SearchNet( REF Clients, PConnection^.RemoteAddress, PELE^.Event.PReceiveClient );
      ClientsLock.Unlock();
      IF NOT b THEN
        Logger.LogS( dldError, logPrefix, L"Connection for string/struct data not found, leaving receiving" );
        RETURN;
      END;

      EventsLock.Lock();
      Events.Append( PELE );
      EventsLock.Unlock();

      NEW( PELE );
      IF CRCValid THEN
         IF TPPacket( PData )^.TR = trString THEN
            PELE^.Event.Event := evDataReceived2Success;
            Logger.LogSC( dldDebug, logPrefix, L"Event.Add evDataReceived2Success ", CARDINAL( evDataReceived2Success ));
         ELSE
            PELE^.Event.Event := evStructReceived2Success;
            Logger.LogSC( dldDebug, logPrefix, L"Event.Add evStructReceived2Success ", CARDINAL( evStructReceived2Success ));
         END;
         PELE^.Event.PacketLen := DataLen;
         ALLOCATE( PELE^.Event.PPacket, DataLen );
         Storage.Move( PData, PELE^.Event.PPacket, DataLen );
      ELSE
         IF TPPacket( PData )^.TR = trString THEN
            PELE^.Event.Event := evDataReceived2BadCRC;
            Logger.LogSC( dldDebug, logPrefix, L"Event.Add evDataReceived2BadCRC ", CARDINAL( evDataReceived2BadCRC ));
         ELSE
            PELE^.Event.Event := evStructReceived2BadCRC;
            Logger.LogSC( dldDebug, logPrefix, L"Event.Add evStructReceived2BadCRC ", CARDINAL( evStructReceived2BadCRC ));
         END;
      END;

      EventsLock.Lock();
      Events.Append( PELE );
      IF rsEventsPending IN RStatus THEN
        EventsLock.Unlock();
        RETURN;
      ELSE
        INCL( RStatus, rsEventsPending );
      END;
      EventsLock.Unlock();
      Logger.LogS( dldDebug, logPrefix, L"RS+ rsEventPending, fire dcfException (4)" );

      CallbackProc( CallbackId, drv_def.dcfException, NIL );

    ELSE
      Logger.LogSC( dldTrace, logPrefix, L"Unrecognized packet ", CARDINAL( TPPacket( PData )^.TR  ));
    
    END;
  END OnReceive;

(*--------------------------------------------------------------------------------*)

BEGIN
  R.LoadRES2( EMITW( %dll ), L'NetMsg.Texts' );
  R.Lang := Languages.GetDefaultLanguage( Languages.dlUser );
  RStatus := TRStatus{rsValid};
  RunMode := drv_def.drmEdit;
  CallbackId := NIL;
  CallbackProc := NIL;
  ListenAddress.Port := 6001;
  Server.Driver := ADR( SELF );
  GlobalKey[0] := 0;
  Packet.Size := 272;
END CDriver;

(*================================================================================*)

CLASS CFactory IMPLEMENTS diface.ICWDriverFactory;
   PRIVATE VAR
      R : Resources.CResources;
   PUBLIC VIRTUAL READONLY PROPERTY
      DriverName : StringsO.CString;
   PUBLIC VIRTUAL PROCEDURE CreateInstance( OUT Instance : diface.TPCWDriver ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE DeleteInstance( Instance : diface.TPCWDriver );
END CFactory;   

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CFactory;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY DriverName GET : StringsO.CString;
   VAR
      Name : StringsO.CString;
   BEGIN
      Name.FromOA( OAsz( R[ Texts._DriverName ] ));
      RETURN Name;
   END DriverName;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CreateInstance( OUT Instance : diface.TPCWDriver ) : BOOLEAN;
   VAR
      Driver : TPDriver;
   BEGIN
      NEW( Driver );
      Instance := Driver;
      RETURN TRUE;
   END CreateInstance;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE DeleteInstance( Instance : diface.TPCWDriver );
   VAR
      Driver : TPDriver := TPDriver( Instance );
   BEGIN
      DISPOSE( Driver );
   END DeleteInstance;

(*--------------------------------------------------------------------------------*)

BEGIN
   R.LoadRES2( EMITW( %dll ), L'NetMsg.Texts' );
   R.Lang := Languages.GetDefaultLanguage( Languages.dlUser );
END CFactory;

(*--------------------------------------------------------------------------------*)

VAR
   Factory : CFactory;

(*--------------------------------------------------------------------------------*)

BEGIN
   diface.RegisterFactory( ADR( Factory ));
END NetMsg.
