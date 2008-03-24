IMPLEMENTATION MODULE NetMsg;

(*# call( o_a_copy => off ) *)

//================================================================================
(*/* changes:

19.09.2004 -- V1.1, build ???

*/*)
//================================================================================

IMPORT
  windows;

FROM Storage IMPORT
  REALLOCATE, ALLOCATE, DEALLOCATE;
  
FROM log IMPORT
  logger, dldTrace, dldDebug;

IMPORT
  avltree,
  cllv,
  crc,
  digest,
  dns,
  drv_str,
  FIO,
  FIOO,
  INIFile,
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
  netinit,
  netsrv,
  netsocket,
  Resources,
  rijndael,
  sha256,
  Storage,
  StorageO,
  Strings,
  StringsO,
  TextReader,
  Texts;

//================================================================================

CONST // device specific error codes
  ecRxTimeout     = drv_def.ecCommunicationTimeout;
  ecChkSumError   = drv_def.ecCheckSumError;
  ecDeviceStopped = 10001H;

CONST
   logPrefix = L"NetMsg";

//================================================================================

CONST // driver channels
  chStatus = 1;

//================================================================================

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

//--------------------------------------------------------------------------------

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
  Port    : CARDINAL;
  Address : winsock.IN_ADDR;
END CClientLE;

TYPE
  TPClientLE = POINTER TO CClientLE;

//--------------------------------------------------------------------------------

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

//--------------------------------------------------------------------------------

CLASS CServer( netconndispatch.CDispatcher );
  Driver : TPDriver;
  VIRTUAL PROCEDURE OnConnect( PConnection : netconndispatch.TConnectionHandle; Local : BOOLEAN; Error : CARDINAL );
  VIRTUAL PROCEDURE OnDisconnect( PConnection : netconndispatch.TConnectionHandle; Local : BOOLEAN; Error : CARDINAL );
  VIRTUAL PROCEDURE OnReceive( PConnection : netconndispatch.TConnectionHandle; PData : ADDRESS; DataLen : CARDINAL );
END CServer;

//--------------------------------------------------------------------------------

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
                   Address : winsock.IN_ADDR;
                   Port : CARDINAL;
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

CLASS CDriver( msghandler.MessageHandler );
  R             : Resources.CResources;
  RStatus       : TRStatus;
  Name          : ARRAY [0..63] OF WCHAR;

  CallbackId    : ADDRESS;
  CallbackProc  : drv_def.TDriverCallbackW;
  RunMode       : CARDINAL;
  Result        : lec.CResult;

  // driver data
  Port          : CARDINAL;
  Server        : CServer;
  Clients       : list.CList;
  Groups        : list.CList;
  RemovedClients: list.CList;
  GlobalKey     : sha256.TDigest;

  Packet        : StorageO.CMemoryBuffer;
  Events        : list.CList;
  FieldToValue  : maps.CIntegerMap; // Map OF PTR TO iovalue.Value
  Records       : maps.CStringMap; // Map OF Array OF PTR to iovalue.Value in above structure

  // binding to procedural interface
  LOCAL PROCEDURE Init( RunMode : CARDINAL; VAR SymbolicName : ARRAY OF WCHAR; CallbackId : ADDRESS; PCallback : drv_def.TDriverCallbackW ) : BOOLEAN;
  LOCAL PROCEDURE ReadParameters( VAR ParFilePath, ErrorMessage : ARRAY OF WCHAR; VAR ErrorLine, ErrorColumn : CARDINAL; VAR HintOrHelp : ARRAY OF WCHAR ) : BOOLEAN;
  LOCAL PROCEDURE EnumerateChannels(  VAR EnumerateState : LONGWORD; VAR Type : CARDINAL; VAR Direction : CARDINAL; VAR DriverIndex : CARDINAL; VAR Count : CARDINAL; VAR HaveDescription : BOOLEAN ): BOOLEAN;

  LOCAL PROCEDURE Run();
  LOCAL PROCEDURE Stop();
  LOCAL PROCEDURE Done();

  LOCAL PROCEDURE QueryProc( UFlag : BOOLEAN; InValue1, InValue2 : drv_def.TValue; VAR OutValue : drv_def.TValue );

  LOCAL PROCEDURE InputRequestStart();
  LOCAL PROCEDURE InputRequest( DriverIndex : CARDINAL );
  LOCAL PROCEDURE InputRequestCompleted();
  LOCAL PROCEDURE InputFinalized( DriverIndex : CARDINAL; VAR ErrorCode : CARDINAL ) : BOOLEAN;
  LOCAL PROCEDURE InputOOBDataQuery( VAR EnumerateState : LONGWORD; VAR DriverIndex : CARDINAL ) : BOOLEAN;
  LOCAL PROCEDURE GetInput( UFlag : BOOLEAN; DriverIndex : CARDINAL; VAR InValue : drv_def.TValue; VAR QoS : CARDINAL; VAR TimeStamp : drv_def.TUTCStamp; VAR ErrorCode : CARDINAL );

  LOCAL PROCEDURE OutputRequestStart();
  LOCAL PROCEDURE OutputRequest( UFlag : BOOLEAN; DriverIndex : CARDINAL; OutValue : drv_def.TValue; QoS : CARDINAL; TimeStamp : drv_def.TUTCStamp );
  LOCAL PROCEDURE OutputRequestCompleted();
  LOCAL PROCEDURE OutputFinalized( DriverIndex : CARDINAL; VAR ErrorCode : CARDINAL ) : BOOLEAN;

  // helpers
  PROCEDURE InitToDefault();
  PROCEDURE Exists( Name : ARRAY OF WCHAR; Port : CARDINAL; Address : winsock.IN_ADDR ) : BOOLEAN;
  PROCEDURE SearchName( Name : ARRAY OF WCHAR; VAR PClientLE : TPClientLE ) : BOOLEAN;
  PROCEDURE SearchNet( REF Clients : list.CList; Port : CARDINAL; Address : winsock.IN_ADDR; VAR PClientLE : TPClientLE ) : BOOLEAN;
  PROCEDURE SearchGroup( Name : ARRAY OF WCHAR; VAR PGroupLE : TPGroupLE ) : BOOLEAN;
  PROCEDURE RemoveClientFromGroups( PClientLE : TPClientLE );

  LOCAL PROCEDURE OnConnect( PConnection : netconndispatch.TConnectionHandle; Local : BOOLEAN; Error : CARDINAL );
  LOCAL PROCEDURE OnDisconnect( PConnection : netconndispatch.TConnectionHandle; Local : BOOLEAN; Error : CARDINAL );
  LOCAL PROCEDURE OnReceive( PConnection : netconndispatch.TConnectionHandle; PData : ADDRESS; DataLen : CARDINAL );
END CDriver;

//================================================================================

CLASS IMPLEMENTATION CClient;

//--------------------------------------------------------------------------------

  LOCAL VIRTUAL PROCEDURE OnJoin( _Connection : netconndispatch.TConnectionHandle );
  BEGIN
    Connection := _Connection;
  END OnJoin;

//--------------------------------------------------------------------------------

  LOCAL VIRTUAL PROCEDURE OnConnect( _Connection : netconndispatch.TConnectionHandle; Local : BOOLEAN; Error : CARDINAL );
  BEGIN
    // Connection := _Connection;
  END OnConnect;

//--------------------------------------------------------------------------------

  LOCAL VIRTUAL PROCEDURE OnDisconnect( _Connection : netconndispatch.TConnectionHandle; Local : BOOLEAN; Error : CARDINAL );
  BEGIN
    Connection := _Connection;
  END OnDisconnect;

//--------------------------------------------------------------------------------

BEGIN
  Connection := NIL;
END CClient;

//================================================================================

CLASS IMPLEMENTATION CClientLE;
BEGIN
  PClient := NIL;
  Group[0] := WCHAR( 0 );
  Name[0] := WCHAR( 0 );
  Port := 0;
  Storage.Fill( ADR( Address ), SIZE( Address ), 0 );
END CClientLE;

//--------------------------------------------------------------------------------

CLASS IMPLEMENTATION CGroupLE;
BEGIN
  Name[0] := WCHAR( 0 );
END CGroupLE;

//--------------------------------------------------------------------------------

CLASS IMPLEMENTATION CClientGroupLE;
BEGIN
  PClientLE := NIL;
END CClientGroupLE;

//================================================================================

CLASS IMPLEMENTATION CServer;

//--------------------------------------------------------------------------------

  VIRTUAL PROCEDURE OnConnect( PConnection : netconndispatch.TConnectionHandle; Local : BOOLEAN; Error : CARDINAL );
  BEGIN
    Driver^.OnConnect( PConnection, Local, Error );
  END OnConnect;

//--------------------------------------------------------------------------------

  VIRTUAL PROCEDURE OnDisconnect( PConnection : netconndispatch.TConnectionHandle; Local : BOOLEAN; Error : CARDINAL );
  BEGIN
    Driver^.OnDisconnect( PConnection, Local, Error );
  END OnDisconnect;

//--------------------------------------------------------------------------------

  VIRTUAL PROCEDURE OnReceive( PConnection : netconndispatch.TConnectionHandle; PData : ADDRESS; DataLen : CARDINAL );
  BEGIN
    Driver^.OnReceive( PConnection, PData, DataLen );
  END OnReceive;

//--------------------------------------------------------------------------------

BEGIN
  Connection := netconndispatch.ctDatagram;
  PieceSize := -1;
  Driver := NIL;
END CServer;

//================================================================================

CLASS IMPLEMENTATION CEventLE;
BEGIN
  Storage.Zero( ADR( Event ), SIZE( Event ));
FINALLY
  IF ( Event.Event = evDataReceived2Success ) OR ( Event.Event = evStructReceived2Success ) THEN
    DISPOSE( Event.PPacket );
  END;
END CEventLE;

//================================================================================

CLASS IMPLEMENTATION CDriver;

//--------------------------------------------------------------------------------

  LOCAL PROCEDURE Init( _RunMode : CARDINAL; VAR SymbolicName : ARRAY OF WCHAR; _CallbackId : ADDRESS; PCallback : drv_def.TDriverCallbackW ) : BOOLEAN;
  BEGIN
    SUPER.Init();

    CallbackId := _CallbackId;
    CallbackProc := PCallback;
    RunMode := _RunMode;
    ASSIGN( Name, SymbolicName );
    Server.Init();

    RETURN TRUE;
  END Init;

//--------------------------------------------------------------------------------

  LOCAL PROCEDURE ReadParameters( VAR ParFilePath, ErrorMessage : ARRAY OF WCHAR; VAR ErrorLine, ErrorColumn : CARDINAL; VAR HintOrHelp : ARRAY OF WCHAR ) : BOOLEAN;
  LABEL
    Fail;
  CONST
    // .PAR section names
    snDevice               = L'NetMsg';
      knKey                = L'key';
    // .PAR key names
    snRecordType           = L'record_type';
    snRecord               = L'record';
    // .PAR key names 
    knDebugMode            = L'debug_mode';
      kvDebugNone          = L'none';
      kvDebugFile          = L'file';
      kvDebugKernel        = L'windows';
    knDebugFile            = L'debug_file';
    knDebugLevel           = L'debug_level';
      kvDebugBasic         = L'basic';
      kvDebugExtended      = L'extended';
      kvDebugAllProtocol   = L'protocol';
      kvDebugAll           = L'all';
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

  VAR
    cs : StringsO.CString;
    ChannelIndex : CARDINAL;
    DebugFile : FIO.PathStrW;
    DebugLevel : log.TDebugLevel;
    DebugMode : log.TDebugMethod;
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
    HintOrHelp[0] := WCHAR( 0 );

      TRY
         fs.FromPath( ParFilePath, FIOO.imOpenRead );
      CATCH : IOO.CIOException DO
         ASSIGN( ErrorMessage, OAsz( R[ Texts._CannotOpenPar ] ));
         GOTO Fail;
      END; // TRY
      tr.Stream := ADR( fs );
      IF NOT TS.Load( tr ) THEN
         ASSIGN( ErrorMessage, OAsz( R[ Texts._CannotOpenPar ] ));
         GOTO Fail;
      END;
      fs.Close( FALSE );

    InitToDefault();
    DebugMode := log.dmNone;
    DebugLevel := log.dl1;

    IF NOT TS.SetSection( snDevice ) THEN
      IF RunMode = drv_def.drmRun THEN
        ASSIGN( ErrorMessage, OAsz( R[ Texts._MissingDeviceSection ] ));
        GOTO Fail;
      ELSE
        RETURN TRUE;
      END;
    END;
    IF TS.GetKeyStr( knKey, OUT ErrorLine, OUT cs ) THEN
      IF cs.Length < 32 THEN
        ASSIGN( ErrorMessage, OAsz( R[ Texts._KeyTooShort ] ));
        GOTO Fail;
      ELSE
        INCL( RStatus, rsGlobalKey );
        digest.DigestOA( digest.sha256, OA( cs.Length-1, cs.rawData ), OUT GlobalKey );
      END;
    END;

    IF TS.GetKeyStr( knDebugMode, OUT ErrorLine, OUT cs ) THEN
      cs.ToOA( OUT s );

      IF EQUALS( s, kvDebugNone ) THEN
        DebugMode := log.dmNone;
      ELSIF EQUALS( s, kvDebugFile ) THEN
        DebugMode := log.dmFile;
        IF NOT TS.GetKeyStr( knDebugFile, OUT ErrorLine, OUT cs ) THEN
          ASSIGN( ErrorMessage, OAsz( R[ Texts._FileDebugMissingFile ] ));
          GOTO Fail;
        END;
         cs.ToOA( OUT DebugFile );
      ELSIF EQUALS( s, kvDebugKernel ) THEN
        DebugMode := log.dmKernel;
      END;
      IF DebugMode <> log.dmNone THEN
        IF TS.GetKeyStr( knDebugLevel, OUT ErrorLine, OUT cs ) THEN
            cs.ToOA( OUT s );
          IF EQUALS( s, kvDebugBasic ) THEN
            DebugLevel := log.dldError;
          ELSIF EQUALS( s, kvDebugExtended ) THEN
            DebugLevel := log.dldInfo;
          ELSIF EQUALS( s, kvDebugAllProtocol ) THEN
            DebugLevel := log.dldTrace;
          ELSIF EQUALS( s, kvDebugAll ) THEN
            DebugLevel := log.dldDebug;
          END;
        END;
      END;
    END;

      // get all record types
      ES := 0;
      WHILE TS.EnumerateSections( REF ES, OUT ErrorLine, OUT s, TRUE ) DO
         IF EQUALS( s, snRecordType ) THEN
            IF NOT TS.GetKeyStr( knName, OUT ErrorLine, OUT S ) THEN
               ErrorMessage := OAsz( R[ Texts._MissingNameOfRecordType ] );
               GOTO Fail;
            ELSIF RecordTypes.Contains( S ) THEN
               ErrorMessage := OAsz( R[ Texts._RecordTypeDuplicated ] );
               GOTO Fail;
            ELSE
               TypeList := NEW( lists.CIntegerList );
               RecordTypes.Add( S, TypeList );
            END;
            IF NOT TS.GetKeyStr( knFields, OUT ErrorLine, OUT S ) THEN
               ErrorMessage := OAsz( R[ Texts._MissingFieldsOfRecordType ] );
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
                     ErrorMessage := OAsz( R[ Texts._MalformedTypeArray ] );
                     GOTO Fail;
                  END;
                  cs.Remove( number, -1 );
                  cs.Trim();
                  TRY
                     number := cs.ToINT32( 10 );
                  CATCH e : StringsO.CStringException DO
                     ErrorMessage := OAsz( R[ Texts._MalformedArrayRange ] );
                     GOTO Fail;
                  END;
                  IF number < 1 THEN
                     ErrorMessage := OAsz( R[ Texts._BadArrayRange ] );
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
                  ErrorMessage := OAsz( R[ Texts._UnknownFieldType ] );
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
               ErrorMessage := OAsz( R[ Texts._MissingRecordTypeInRecord ] );
               GOTO Fail;
            ELSIF NOT RecordTypes.Get( S, OUT TypeList ) THEN
               ErrorMessage := OAsz( R[ Texts._UnknownRecordType ] );
               GOTO Fail;
            ELSIF NOT TS.GetKeyStr( knName, OUT ErrorLine, OUT S ) THEN
               ErrorMessage := OAsz( R[ Texts._MissingNameOfRecord ] );
               GOTO Fail;
            ELSIF Records.Contains( S ) THEN
               ErrorMessage := OAsz( R[ Texts._RecordDuplicated ] );
               GOTO Fail;
            ELSIF NOT TS.GetKeyInt( knFirstChannel, OUT ErrorLine, OUT ChannelIndex ) THEN
               ErrorMessage := OAsz( R[ Texts._MissingFirstChannelRecord ] );
               GOTO Fail;

            ELSE

               ValueList := NEW( lists.CPtrList );
               TypeList^.Reset();
               WHILE TypeList^.MoveNext() DO
                  IF ChannelIndex = 1 THEN
                     ErrorMessage := OAsz( R[ Texts._ChannelOneReserved ] );
                     GOTO Fail;
                  END;
                  FOR i := 0 TO CARDINAL( LOPTRLONGWORD( TypeList^.CurrentData )) - 1 DO
                     IF FieldToValue.Contains( ChannelIndex ) THEN
                        ErrorMessage := OAsz( R[ Texts._ChannelIndexDuplicated ] );
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

      IF RunMode = drv_def.drmRun THEN
      END;
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

//--------------------------------------------------------------------------------

  LOCAL PROCEDURE EnumerateChannels( VAR EnumerateState : LONGWORD; VAR Type : CARDINAL; VAR Direction : CARDINAL; VAR DriverIndex : CARDINAL; VAR Count : CARDINAL; VAR HaveDescription : BOOLEAN ): BOOLEAN;
  VAR
    Value : iovalue.TPValue;
  BEGIN
    IF EnumerateState = 0 THEN
      // status channel
      Direction := CARDINAL( drv_def.TDirection{drv_def.dirInput} );
      DriverIndex := chStatus;
      Type := CARDINAL( drv_def.vtLongCard );

    ELSIF NOT FieldToValue.ElementAt( CARDINAL( EnumerateState )-1, OUT DriverIndex, OUT Value ) THEN
      RETURN FALSE;
      
    ELSE
       Direction := CARDINAL( drv_def.TDirection{drv_def.dirInput, drv_def.dirOutput} );
       // DriverIndex already set
       Type := CARDINAL( drv_def.IOTypeToCWType( Value^.Type ));

    END;

    Count := 1;
    HaveDescription := FALSE;
    INC( EnumerateState );
    RETURN TRUE;
  END EnumerateChannels;

//--------------------------------------------------------------------------------

   LOCAL PROCEDURE Run();
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
         netsrv.StartListen( netsocket.stStream, Port, NIL, Server.Listener, 0, NIL );
      END;
  END Run;

//--------------------------------------------------------------------------------

  LOCAL PROCEDURE Stop();
  BEGIN
    IF TRStatus{rsRunning} * RStatus = TRStatus{} THEN
      RETURN;
    END;
    EXCL( RStatus, rsRunning );
    IF rsListening IN RStatus THEN
      netsrv.StopListenPort( netsocket.stStream, Port );
    END;
  END Stop;

//--------------------------------------------------------------------------------

  LOCAL PROCEDURE Done();
  VAR
    List : lists.TPPtrList;
    PClientLE : TPClientLE;
    PGroupLE : TPGroupLE;
  BEGIN
    Server.Dispose();
    Events.Dispose();
    Packet.Dispose();

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
  END Done;

//--------------------------------------------------------------------------------

  LOCAL PROCEDURE QueryProc( UFlag : BOOLEAN; InValue1, InValue2 : drv_def.TValue; VAR OutValue : drv_def.TValue );
  LABEL
    DoSend, Error, Success;
  CONST
    structItemSepChar = 9W;
    structItemSep = StringsO.WCHARS{ structItemSepChar };
  VAR
    c, i : CARDINAL;
    Group : ARRAY [0..63] OF WCHAR;
    IAddress : winsock.IN_ADDR;
    len : CARDINAL;
    List : lists.TPPtrList;
    Payload : TTransport;
    PPacket : TPPacket;
    PClient : TPClient;
    PClientGroupLE : TPClientGroupLE;
    PClientLE : TPClientLE;
    PELE : TPEventLE;
    PGroupLE : TPGroupLE;
    RAddr : winsock.IN_ADDR;
    RPort : CARDINAL;
    Name : ARRAY [0..63] OF WCHAR;
    na : ARRAY [0..63] OF CHAR;
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
          drv_def.DrvValueToCStringW( InValue2, UFlag, OUT SW );
          Payload := trString;

       END;
       RETURN TRUE;
    END PreparePayload;

  //----------

  BEGIN
    drv_def.DrvValueToCStringW( InValue1, UFlag, OUT SW );
    SW.ItemSOA( StringsO.WCHARS{ L' ' }, 0, 0, TRUE, OUT si );
    Result.Inc();

    IF EQUALS( si, L'event' ) THEN
      SW.ItemSOA( StringsO.WCHARS{ L' ' }, 0, 1, TRUE, OUT si );

      IF EQUALS( si, L'count' ) THEN
        c := Events.Count;
        logger()^.LogSC( dldDebug, logPrefix, L"Event.Count ", c );

        drv_def.AssignValueCardinal( OutValue, UFlag, TRUE, c );
        RETURN;
      
      ELSIF EQUALS( si, L'get' ) THEN
        IF Result.Counted OR Result.Expired THEN
          logger()^.LogS( dldDebug, logPrefix, L"Event.Get clear buffer" );
          logger()^.LogS( dldDebug, logPrefix, L"RS- rsEventPending" );

          Events.Dispose();
          EXCL( RStatus, rsEventsPending );
          GOTO Success;
        END;

        IF Events.GetFirst( OUT PELE ) THEN
          logger()^.LogSC( dldDebug, logPrefix, L"Event.Dequeue ", CARDINAL( PELE^.Event.Event ));

          Events.Remove( PELE );

          CASE PELE^.Event.Event OF
          | evConnect :
            IF SearchNet( REF Clients, PELE^.Event.Port, PELE^.Event.Address, PClientLE ) THEN
              ASSIGN( Name, PClientLE^.Name );
              ASSIGN( Group, PClientLE^.Group );
            ELSE
              Name := L'';
              Group := L'';
            END;
            IF Name[0] = L'$' THEN // PClientLE is server stub
               IF PELE^.Event.Local THEN
                 SW.FromOA( L'server_connect:' );
               ELSE
                 SW.FromOA( L'client_connect:' );
               END;
            ELSE
               IF PELE^.Event.Local THEN
                 SW.FromOA( L'client_connect:' );
               ELSE
                 SW.FromOA( L'server_connect:' );
               END;
            END;
          | evDisconnect :
            IF SearchNet( REF Clients, PELE^.Event.Port, PELE^.Event.Address, PClientLE ) THEN
              ASSIGN( Name, PClientLE^.Name );
              ASSIGN( Group, PClientLE^.Group );
            ELSIF SearchNet( REF RemovedClients, PELE^.Event.Port, PELE^.Event.Address, PClientLE ) THEN
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
                 SW.FromOA( L'server_disconnect:' );
               ELSE
                 SW.FromOA( L'client_disconnect:' );
               END;
               // finish remove from OnDisconnect
               Clients.Remove( PClientLE );
               DISPOSE( PClientLE );
            ELSE
               IF PELE^.Event.Local THEN
                 SW.FromOA( L'client_disconnect:' );
               ELSE
                 SW.FromOA( L'server_disconnect:' );
               END;
            END;
          | evDataReceived1 :
            ASSIGN( Name, PELE^.Event.PReceiveClient^.Name );
            ASSIGN( Group, PELE^.Event.PReceiveClient^.Group );
            IF Name[0] = L'$' THEN
              SW.FromOA( L'client_data:' );
            ELSE
              SW.FromOA( L'server_data:' );
            END;
          | evStructReceived1 :
            ASSIGN( Name, PELE^.Event.PReceiveClient^.Name );
            ASSIGN( Group, PELE^.Event.PReceiveClient^.Group );
            IF Name[0] = L'$' THEN
              SW.FromOA( L'client_record:' );
            ELSE
              SW.FromOA( L'server_record:' );
            END;
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
          | evDataReceived2BadCRC, evStructReceived2BadCRC :
            SW.FromOA( L'$badcrc' );
          END; // CASE

          b := TRUE;
          CASE PELE^.Event.Event OF
          | evConnect, evDisconnect :
            IAddress := PELE^.Event.Address;
            Port := PELE^.Event.Port;
          | evDataReceived1, evStructReceived1 :
            IAddress := PELE^.Event.PReceiveClient^.Address;
            Port := PELE^.Event.PReceiveClient^.Port;
          ELSE
            b := FALSE;
          END; // CASE
          IF b THEN
            ASSIGNsz( na, winsock.inet_ntoa( IAddress ));
            Strings.ToW( na, 0, OUT n );
            SW.AppendOA( n ); SW.AppendOA( L"-" );
            Strings.FromCARD32W( Port, 10, OUT n );
            SW.AppendOA( n );
          END;

          CASE PELE^.Event.Event OF
          | evConnect, evDisconnect, evDataReceived1, evStructReceived1 :
            SW.AppendOA( L":" );
            IF Group[0] <> WCHAR( 0 ) THEN
              SW.AppendOA( Group );
              SW.AppendOA( L"." );
            END;
            SW.AppendOA( Name );
          END;

          CASE PELE^.Event.Event OF
          | evConnect, evDisconnect :
            SW.AppendOA( L":" );
            Strings.FromCARD32W( PELE^.Event.Error, 10, OUT n );
            SW.AppendOA( n );
          END;

          IF drv_def.AssignDrvValueCStringW( REF OutValue, UFlag, FALSE, SW ) THEN
            DISPOSE( PELE );
          ELSE // wait for longer string, enter record back
            logger()^.LogS( dldDebug, logPrefix, L"Event.Enqueue back" );

            Events.InsertFirst( PELE );
          END;
          RETURN;

        ELSE
          logger()^.LogS( dldDebug, logPrefix, L"RS- rsEventPending" );

          EXCL( RStatus, rsEventsPending );
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
        ELSIF netsrv.StartListen( netsocket.stStream, Port, NIL, Server.Listener, 0, NIL ) <> 0 THEN
          SW.FromOA( OAsz( R[ Texts._ListenFailure ] ));
          GOTO Error;
        END;
        INCL( RStatus, rsListening );

      ELSIF EQUALS( si, L'stop' ) THEN
        IF TRStatus{rsListening} * RStatus = TRStatus{} THEN
          GOTO Success;
        END;
        EXCL( RStatus, rsListening );
        netsrv.StopListenPort( netsocket.stStream, Port );

      ELSIF EQUALS( si, L'port' ) THEN
        SW.ItemSOA( StringsO.WCHARS{ L' ' }, 0, 2, TRUE, OUT n );
        IF NOT Strings.ToCARD32W( n, 10, OUT c ) OR ( c > 65535 ) THEN
          SW.FromOA( OAsz( R[ Texts._BadPortNumber ] ));
          GOTO Error;
        END;
        IF rsListening IN RStatus THEN
          netsrv.StopListenPort( netsocket.stStream, Port );
          Port := c;
          netsrv.StartListen( netsocket.stStream, Port, NIL, Server.Listener, 0, NIL );
        ELSE
          Port := c;
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

        IF EQUALS( Name, L'all' ) THEN
          PClientLE := NIL;
        ELSIF Name[0] <> L'$' THEN
          SW.FromOA( OAsz( R[ Texts._UnknownClient ] ));
          GOTO Error;
        ELSIF NOT SearchName( Name, PClientLE ) THEN
          SW.FromOA( OAsz( R[ Texts._UnknownClient ] ));
          GOTO Error;
        END;
        IF Result.Counted OR Result.Expired THEN
          GOTO Success;
        END;

        IF NOT PreparePayload( OUT Payload ) THEN
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
          b := Clients.GetFirst( OUT PClientLE );
          WHILE b DO
            IF ( PClientLE^.PClient <> NIL ) AND ( PClientLE^.Name[0] = L'$' ) AND ( PClientLE^.Group[0] <> L' ' ) THEN
              PClientLE^.PClient^.Send( PClientLE^.PClient^.Connection, 0, PPacket, len );
            END;
            b := Clients.NextOf( PClientLE, OUT PClientLE );
          END; // WHILE
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
        IF SearchGroup( Name, PGroupLE ) THEN
          SW.FromOA( OAsz( R[ Texts._GroupAlreadyExists ] ));
          GOTO Error;
        END;
        NEW( PGroupLE );
        ASSIGN( PGroupLE^.Name, Name );
        Groups.Append( PGroupLE );
      
      ELSIF EQUALS( si, L'connect' ) THEN
        IF NOT SearchGroup( Name, PGroupLE ) THEN
          SW.FromOA( OAsz( R[ Texts._UnknownGroup ] ));
          GOTO Error;
        END;
        b := PGroupLE^.Clients.GetFirst( OUT PClientGroupLE );
        LOOP
          PClientGroupLE^.PClientLE^.PClient^.Connect( PClientGroupLE^.PClientLE^.PClient^.Connection );
          b := PGroupLE^.Clients.NextOf( PClientGroupLE, OUT PClientGroupLE );
        END; // WHILE

      ELSIF EQUALS( si, L'disconnect' ) THEN
        IF NOT SearchGroup( Name, PGroupLE ) THEN
          SW.FromOA( OAsz( R[ Texts._UnknownGroup ] ));
          GOTO Error;
        END;
        b := PGroupLE^.Clients.GetFirst( OUT PClientGroupLE );
        LOOP
          PClientGroupLE^.PClientLE^.PClient^.Disconnect( PClientGroupLE^.PClientLE^.PClient^.Connection );
          b := PGroupLE^.Clients.NextOf( PClientGroupLE, OUT PClientGroupLE );
        END; // WHILE

      ELSIF EQUALS( si, L'send' ) THEN
        IF NOT SearchGroup( Name, PGroupLE ) THEN
          SW.FromOA( OAsz( R[ Texts._UnknownGroup ] ));
          GOTO Error;
        END;
        IF Result.Counted OR Result.Expired THEN
          GOTO Success;
        END;
          
        IF NOT PreparePayload( OUT Payload ) THEN
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

        b := PGroupLE^.Clients.GetFirst( OUT PClientGroupLE );
        WHILE b DO
          IF PClientGroupLE^.PClientLE <> NIL THEN
            PClientGroupLE^.PClientLE^.PClient^.Send( PClientGroupLE^.PClientLE^.PClient^.Connection, 0, PPacket, len );
          END;
          b := PGroupLE^.Clients.NextOf( PClientGroupLE, OUT PClientGroupLE );
        END; // WHILE

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
        IF NOT dns.NameToAddressWait( si, 1000, OUT RAddr ) THEN
          SW.FromOA( L"Bad client name/IP address" );
          GOTO Error;
        END;

        IF Exists( Name, RPort, RAddr ) THEN
          SW.FromOA( OAsz( R[ Texts._ClientAlreadyExists ] ));
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
        PClientLE^.Port := RPort;
        PClientLE^.Address := RAddr;
        NEW( PClientLE^.PClient );
        Clients.Append( PClientLE );

        PClientLE^.PClient^.BindDispatcher( ADR( Server ));
        PClientLE^.PClient^.Join( RPort, RAddr );

      ELSIF EQUALS( si, L'connect' ) THEN
        IF NOT SearchName( Name, PClientLE ) THEN
          SW.FromOA( OAsz( R[ Texts._UnknownClient ] ));
          GOTO Error;
        END;
        PClientLE^.PClient^.Connect( PClientLE^.PClient^.Connection );

      ELSIF EQUALS( si, L'disconnect' ) THEN
        IF NOT SearchName( Name, PClientLE ) THEN
          SW.FromOA( OAsz( R[ Texts._UnknownClient ] ));
          GOTO Error;
        END;
        PClientLE^.PClient^.Disconnect( PClientLE^.PClient^.Connection );

      ELSIF EQUALS( si, L'remove' ) THEN
        IF Name[0] = L'$' THEN
          SW.FromOA( OAsz( R[ Texts._ClientNameReserved ] ));
          GOTO Error;
        ELSIF NOT SearchName( Name, PClientLE ) THEN
          SW.FromOA( OAsz( R[ Texts._UnknownClient ] ));
          GOTO Error;
        END;

        Clients.Remove( PClientLE );
        RemoveClientFromGroups( PClientLE );
        PClient := PClientLE^.PClient;
        // removed clients store data to allow notify correct information
        RemovedClients.Append( PClientLE );

        PClient^.Disconnect( PClient^.Connection );
        PClient^.Leave( PClient^.Connection );
        PClient^.Release();

      ELSIF EQUALS( si, L'join' ) THEN
        IF NOT SearchName( Name, PClientLE ) THEN
          SW.FromOA( OAsz( R[ Texts._UnknownClient ] ));
          GOTO Error;
        END;
        SW.ItemSOA( StringsO.WCHARS{ L' ' }, 0, 3, TRUE, OUT Name ); // group id
        IF NOT SearchGroup( Name, PGroupLE ) THEN
          SW.FromOA( OAsz( R[ Texts._UnknownGroup ] ));
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

      ELSIF EQUALS( si, L'leave' ) THEN
        IF NOT SearchName( Name, PClientLE ) THEN
          SW.FromOA( OAsz( R[ Texts._UnknownClient ] ));
          GOTO Error;
        END;
        SW.ItemSOA( StringsO.WCHARS{ L' ' }, 0, 3, TRUE, OUT Name ); // group id
        IF NOT SearchGroup( Name, PGroupLE ) THEN
          SW.FromOA( OAsz( R[ Texts._UnknownGroup ] ));
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

      ELSIF EQUALS( si, L'send' ) THEN
        IF EQUALS( Name, L'all' ) THEN
          PClientLE := NIL;
        ELSIF Name[0] = L'$' THEN
          SW.FromOA( OAsz( R[ Texts._UnknownClient ] ));
          GOTO Error;
        ELSIF NOT SearchName( Name, PClientLE ) THEN
          SW.FromOA( OAsz( R[ Texts._UnknownClient ] ));
          GOTO Error;
        END;
        IF Result.Counted OR Result.Expired THEN
          GOTO Success;
        END;

        IF NOT PreparePayload( OUT Payload ) THEN
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
          b := Clients.GetFirst( OUT PClientLE );
          WHILE b DO
            IF ( PClientLE^.PClient <> NIL ) AND ( PClientLE^.Name[0] <> L'$' ) THEN
              PClientLE^.PClient^.Send( PClientLE^.PClient^.Connection, 0, PPacket, len );
            END;
            b := Clients.NextOf( PClientLE, OUT PClientLE );
          END; // WHILE
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
    drv_def.AssignDrvValueCStringW( REF OutValue, UFlag, FALSE, SW );
    RETURN;
  Success:
    drv_def.AssignDrvValueStringW( REF OutValue, UFlag, FALSE, L'' );
  END QueryProc;

//--------------------------------------------------------------------------------

  LOCAL PROCEDURE InputRequestStart();
  BEGIN
  END InputRequestStart;

//--------------------------------------------------------------------------------

   LOCAL PROCEDURE InputRequest( DriverIndex : CARDINAL );
   BEGIN
      Result.Inc();
   END InputRequest;

//--------------------------------------------------------------------------------

  LOCAL PROCEDURE InputRequestCompleted();
  BEGIN
  END InputRequestCompleted;

//--------------------------------------------------------------------------------

   LOCAL PROCEDURE InputFinalized( DriverIndex : CARDINAL; VAR ErrorCode : CARDINAL ) : BOOLEAN;
   VAR
      Finalized : BOOLEAN;
   BEGIN
      Finalized := TRUE;
      ErrorCode := 0;
      IF DriverIndex = chStatus THEN
         // return always OK
      ELSIF TRStatus{rsRunning} * RStatus = TRStatus{} THEN
         ErrorCode := ecDeviceStopped;
      ELSIF Result.Expired OR Result.Counted THEN
         RETURN FALSE;
      ELSE
         ////
      END;
      RETURN Finalized;
  END InputFinalized;

//--------------------------------------------------------------------------------

  LOCAL PROCEDURE InputOOBDataQuery( VAR EnumerateState : LONGWORD; VAR DriverIndex : CARDINAL ) : BOOLEAN;
  BEGIN
    RETURN FALSE;
  END InputOOBDataQuery;

//--------------------------------------------------------------------------------

   LOCAL PROCEDURE GetInput( UFlag : BOOLEAN; DriverIndex : CARDINAL; VAR InValue : drv_def.TValue; VAR QoS : CARDINAL; VAR TimeStamp : drv_def.TUTCStamp; VAR ErrorCode : CARDINAL );
   VAR
      Value : iovalue.TPValue;
   BEGIN
      ErrorCode := drv_def.ecSuccess;
      QoS := drv_def.qosGood;

      IF DriverIndex = chStatus THEN
         IF Result.Counted OR Result.Expired THEN
            EXCL( RStatus, rsValid );
         ELSE
            INCL( RStatus, rsValid );
         END;
         drv_def.AssignValueCardinal( InValue, UFlag, TRUE, CARDINAL( RStatus * rssUser ));

      ELSIF NOT FieldToValue.Get( DriverIndex, OUT Value ) THEN
         ErrorCode := drv_def.ecUnknownElement;
      
      ELSE
         drv_def.IOValueToCWValue( Value^, UFlag, FALSE, REF InValue );

      END; // CASE
   END GetInput;

//--------------------------------------------------------------------------------

  LOCAL PROCEDURE OutputRequestStart();
  BEGIN
  END OutputRequestStart;

//--------------------------------------------------------------------------------

   LOCAL PROCEDURE OutputRequest( UFlag : BOOLEAN; DriverIndex : CARDINAL; OutValue : drv_def.TValue; QoS : CARDINAL; TimeStamp : drv_def.TUTCStamp );
   VAR
      Value : iovalue.TPValue;
   BEGIN
      Result.Inc();
      IF FieldToValue.Get( DriverIndex, OUT Value ) THEN
         drv_def.CWValueToIOValue( OutValue, UFlag, REF Value^ );
      END;
   END OutputRequest;

//--------------------------------------------------------------------------------

  LOCAL PROCEDURE OutputRequestCompleted();
  BEGIN
  END OutputRequestCompleted;

//--------------------------------------------------------------------------------

  LOCAL PROCEDURE OutputFinalized( DriverIndex : CARDINAL; VAR ErrorCode : CARDINAL ) : BOOLEAN;
  BEGIN
    ErrorCode := 0;
    RETURN NOT Result.Expired AND NOT Result.Counted;
  END OutputFinalized;

//--------------------------------------------------------------------------------

  PROCEDURE InitToDefault();
  BEGIN
  END InitToDefault;

//--------------------------------------------------------------------------------

  PROCEDURE Exists( Name : ARRAY OF WCHAR; Port : CARDINAL; Address : winsock.IN_ADDR ) : BOOLEAN;
  VAR
    PClientLE : TPClientLE;
    b : BOOLEAN;
  BEGIN
    b := Clients.GetFirst( OUT PClientLE );
    WHILE b DO
      IF ( PClientLE^.Port = Port ) AND ( PClientLE^.Address = Address ) THEN
        RETURN TRUE;
      ELSIF EQUALS( PClientLE^.Name, Name ) THEN
        RETURN TRUE;
      END;
      b := Clients.NextOf( PClientLE, OUT PClientLE );
    END;  // WHILE
    RETURN FALSE;
  END Exists;

//--------------------------------------------------------------------------------

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

//--------------------------------------------------------------------------------

  PROCEDURE SearchNet( REF _Clients : list.CList; Port : CARDINAL; Address : winsock.IN_ADDR; VAR PClientLE : TPClientLE ) : BOOLEAN;
  VAR
    LPClientLE : TPClientLE;
    b : BOOLEAN;
  BEGIN
    b := _Clients.GetFirst( OUT LPClientLE );
    WHILE b DO
      IF ( LPClientLE^.Port = Port ) AND ( LPClientLE^.Address = Address ) THEN
        PClientLE := LPClientLE;
        RETURN TRUE;
      END;
      b := _Clients.NextOf( LPClientLE, OUT LPClientLE );
    END;  // WHILE
    RETURN FALSE;
  END SearchNet;

//--------------------------------------------------------------------------------

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

//--------------------------------------------------------------------------------

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

//--------------------------------------------------------------------------------

  LOCAL PROCEDURE OnConnect( PConnection : netconndispatch.TConnectionHandle; Local : BOOLEAN; Error : CARDINAL );
  VAR
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
      PELE^.Event.Port := PConnection^.RemotePort;
      PELE^.Event.Error := Error;
      Events.Append( PELE );

      logger()^.LogSC( dldDebug, logPrefix, L"Event.Add evConnect/client ", CARDINAL( evConnect ));

      IF SearchNet( REF Clients, PELE^.Event.Port, PELE^.Event.Address, PClientLE ) THEN
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
      IF SearchNet( REF Clients, PConnection^.RemotePort, PConnection^.RemoteAddress, PClientLE ) THEN
        // a previous one exists, strange, but reuse it
      ELSE
        NEW( PClientLE );
      END;
      Strings.FromCARD64W( CARD64( PClientLE ), 16, OUT PClientLE^.Name );
      Strings.PrependW( REF PClientLE^.Name, L'$' );
      PClientLE^.Group := L' ';
      PClientLE^.Port := PConnection^.RemotePort;
      PClientLE^.Address := PConnection^.RemoteAddress;
      Clients.Append( PClientLE );
      NEW( PClientLE^.PClient );
      PClientLE^.PClient^.BindDispatcher( ADR( Server ));
      PClientLE^.PClient^.Connection := PConnection;

    END;

    IF rsEventsPending IN RStatus THEN
      RETURN;
    END;
    logger()^.LogS( dldDebug, logPrefix, L"RS+ rsEventPending, fire dcfException (1)" );

    INCL( RStatus, rsEventsPending );
    CallbackProc( CallbackId, drv_def.dcfException, NIL );
  END OnConnect;

//--------------------------------------------------------------------------------

  LOCAL PROCEDURE OnDisconnect( PConnection : netconndispatch.TConnectionHandle; Local : BOOLEAN; Error : CARDINAL );
  VAR
    PClientLE : TPClientLE;
    PELE : TPEventLE;
  BEGIN
    NEW( PELE );
    PELE^.Event.Event := evDisconnect;
    PELE^.Event.Local := Local;
    PELE^.Event.Address := PConnection^.RemoteAddress;
    PELE^.Event.Port := PConnection^.RemotePort;
    PELE^.Event.Error := Error;
    Events.Append( PELE );

    logger()^.LogSC( dldDebug, logPrefix, L"Event.Add evDisconnect", CARDINAL( evDisconnect ));

    // remove remote client stub
    IF SearchNet( REF Clients, PELE^.Event.Port, PELE^.Event.Address, PClientLE ) AND ( PClientLE^.Name[0] = L'$' ) THEN
      // remove client from groups
      RemoveClientFromGroups( PClientLE );

      // remove remote stub itself
      PClientLE^.PClient^.Release();
      PClientLE^.PClient := NIL;
      // client cannot be removed here; it will be needed for event procesing
      // Clients.Remove();
      // DISPOSE( PClientLE );
    END;

    IF rsEventsPending IN RStatus THEN
      RETURN;
    END;
    logger()^.LogS( dldDebug, logPrefix, L"RS+ rsEventPending, fire dcfException (2)" );

    INCL( RStatus, rsEventsPending );
    CallbackProc( CallbackId, drv_def.dcfException, NIL );
  END OnDisconnect;

//--------------------------------------------------------------------------------

  LOCAL PROCEDURE OnReceive( PConnection : netconndispatch.TConnectionHandle; PData : ADDRESS; DataLen : CARDINAL );
  VAR
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

    logger()^.LogSC( dldDebug, logPrefix, L"OnReceive bytes ", DataLen );

    CASE TPPacket( PData )^.TR OF
    | trGroup :
      SearchNet( REF Clients, PConnection^.RemotePort, PConnection^.RemoteAddress, PClientLE );
      IF NOT CRCValid THEN
        PClientLE^.PClient^.Disconnect( PConnection );

        logger()^.LogS( dldDebug, logPrefix, L"Disconnect, bad CRC" );
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

      // remote connect
      NEW( PELE );
      PELE^.Event.Event := evConnect;
      PELE^.Event.Local := FALSE;
      PELE^.Event.Address := PConnection^.RemoteAddress;
      PELE^.Event.Port := PConnection^.RemotePort;
      PELE^.Event.Error := 0;
      Events.Append( PELE );

      logger()^.LogSC( dldDebug, logPrefix, L"Event.Add evConnect/remote ", CARDINAL( evConnect ));

      IF rsEventsPending IN RStatus THEN
        RETURN;
      END;
      logger()^.LogS( dldDebug, logPrefix, L"RS+ rsEventPending, fire dcfException (3)" );

      INCL( RStatus, rsEventsPending );
      CallbackProc( CallbackId, drv_def.dcfException, NIL );

    | trString, trStruct :
      NEW( PELE );
      IF TPPacket( PData )^.TR = trString THEN
         PELE^.Event.Event := evDataReceived1;
         logger()^.LogSC( dldDebug, logPrefix, L"Event.Add evDataReceived1 ", CARDINAL( evDataReceived1 ));
      ELSE
         PELE^.Event.Event := evStructReceived1;
         logger()^.LogSC( dldDebug, logPrefix, L"Event.Add evStructReceived1 ", CARDINAL( evStructReceived1 ));
      END;
      SearchNet( REF Clients, PConnection^.RemotePort, PConnection^.RemoteAddress, PELE^.Event.PReceiveClient );
      Events.Append( PELE );

      NEW( PELE );
      IF CRCValid THEN
         IF TPPacket( PData )^.TR = trString THEN
            PELE^.Event.Event := evDataReceived2Success;
            logger()^.LogSC( dldDebug, logPrefix, L"Event.Add evDataReceived2Success ", CARDINAL( evDataReceived2Success ));
         ELSE
            PELE^.Event.Event := evStructReceived2Success;
            logger()^.LogSC( dldDebug, logPrefix, L"Event.Add evStructReceived2Success ", CARDINAL( evStructReceived2Success ));
         END;
         PELE^.Event.PacketLen := DataLen;
         ALLOCATE( PELE^.Event.PPacket, DataLen );
         Storage.Move( PData, PELE^.Event.PPacket, DataLen );
      ELSE
         IF TPPacket( PData )^.TR = trString THEN
            PELE^.Event.Event := evDataReceived2BadCRC;
            logger()^.LogSC( dldDebug, logPrefix, L"Event.Add evDataReceived2BadCRC ", CARDINAL( evDataReceived2BadCRC ));
         ELSE
            PELE^.Event.Event := evStructReceived2BadCRC;
            logger()^.LogSC( dldDebug, logPrefix, L"Event.Add evStructReceived2BadCRC ", CARDINAL( evStructReceived2BadCRC ));
         END;
      END;
      Events.Append( PELE );
      
      IF rsEventsPending IN RStatus THEN
        RETURN;
      END;
      logger()^.LogS( dldDebug, logPrefix, L"RS+ rsEventPending, fire dcfException (4)" );

      INCL( RStatus, rsEventsPending );
      CallbackProc( CallbackId, drv_def.dcfException, NIL );

    ELSE
      logger()^.LogSC( dldTrace, logPrefix, L"Unrecognized packet ", CARDINAL( TPPacket( PData )^.TR  ));
    
    END;
  END OnReceive;

//--------------------------------------------------------------------------------

BEGIN
  R.LoadRES2( EMITW( %dll ), L'NetMsg.Texts' );
  R.Lang := Languages.GetDefaultLanguage( Languages.dlUser );
  RStatus := TRStatus{rsValid};
  RunMode := drv_def.drmEdit;
  Name := L'';
  CallbackId := NIL;
  CallbackProc := NIL;
  Port := 6001;
  Server.Driver := ADR( SELF );
  GlobalKey[0] := 0;
  Packet.Size := 272;
END CDriver;

//================================================================================
// procedural interface

VAR
  RefCount  : CARDINAL;
  GR : Resources.CResources;

PROCEDURE VersionW() : CARDINAL;
BEGIN
  RETURN 030000H;
END VersionW;

//--------------------------------------------------------------------------------

PROCEDURE GetDriverInfo( VAR DriverName : ARRAY OF CHAR );
BEGIN
  Strings.ToA( OAsz( GR[ Texts._DriverName ] ), 0, OUT DriverName );
END GetDriverInfo;

//--------------------------------------------------------------------------------

PROCEDURE GetDriverInfoW( VAR DriverNameW : ARRAY OF WCHAR );
BEGIN
  ASSIGN( DriverNameW, OAsz( GR[ Texts._DriverName ] ));
END GetDriverInfoW;

//--------------------------------------------------------------------------------

PROCEDURE Check( VAR ErrorString : ARRAY OF CHAR; CWVersion, MajorVersion, MinorVersion, APIMajorVersion, APIMinorVersion : CARDINAL ): BOOLEAN;
VAR
  es : ARRAY [0..255] OF WCHAR;
  b : BOOLEAN;
BEGIN
  b := CheckW( es, CWVersion, MajorVersion, MinorVersion, APIMajorVersion, APIMinorVersion );
  Strings.ToA( es, 0, OUT ErrorString );
  RETURN b;
END Check;

//--------------------------------------------------------------------------------

PROCEDURE CheckW( VAR ErrorString : ARRAY OF WCHAR; CWVersion, MajorVersion, MinorVersion, APIMajorVersion, APIMinorVersion : CARDINAL ): BOOLEAN;
BEGIN
  RETURN TRUE;
END CheckW;

//--------------------------------------------------------------------------------

PROCEDURE MakeDriverW() : ADDRESS;
VAR
  PDriver : TPDriver;
BEGIN
  IF RefCount = 0 THEN
    netinit.Startup();
  END;
  INC( RefCount );

  NEW( PDriver );
  RETURN PDriver;
END MakeDriverW;

//--------------------------------------------------------------------------------

PROCEDURE DisposeDriverW( PData : ADDRESS );
BEGIN
  DISPOSE( TPDriver( PData ));

  DEC( RefCount );
  IF RefCount = 0 THEN
    netinit.Cleanup();
  END;
END DisposeDriverW;

//--------------------------------------------------------------------------------

PROCEDURE InitCommon(    PData        : ADDRESS;
                         RunMode      : CARDINAL;
                     VAR SymbolicName : ARRAY OF WCHAR;
                         CallbackId   : ADDRESS;
                         PCallback    : drv_def.TDriverCallbackW;
                     VAR ErrorString  : ARRAY OF WCHAR ) : BOOLEAN;
BEGIN
  RETURN TPDriver( PData )^.Init( RunMode, SymbolicName, CallbackId, PCallback );
END InitCommon;

PROCEDURE Init(      PData        : ADDRESS;
                 VAR ParFilePath  : ARRAY OF CHAR;
                 VAR ErrorMessage : ARRAY OF CHAR;
                     UserLevel    : CARDINAL;
                     RunFlag      : BOOLEAN;
                     CallbackId   : ADDRESS;
                     PCallback    : drv_def.TDriverCallbackW ) : BOOLEAN;
VAR
  ec, el  : CARDINAL;
  em : ARRAY [0..255] OF WCHAR;
  hoh : ARRAY [0..3] OF CHAR;
  RunMode : CARDINAL;
  s : ARRAY [0..7] OF WCHAR;
BEGIN
  IF RunFlag THEN
    RunMode := drv_def.drmRun;
  ELSE
    RunMode := drv_def.drmEdit;
  END;
  ErrorMessage[0] := CHAR( 0 );
  ASSIGN( s, L'NetMsg' );
  IF InitCommon( PData, RunMode, s, CallbackId, drv_def.TDriverCallbackW( PCallback ), em ) THEN
    IF NOT ReadParameters( PData, ParFilePath, ErrorMessage, el, ec, hoh ) THEN
      RETURN FALSE;
    END;
    RunW( PData );
  ELSIF em[0] = WCHAR( 0 ) THEN
    Strings.ToA( OAsz( GR[ Texts._InitError ] ), 0, OUT ErrorMessage );
    RETURN FALSE;
  ELSE
    Strings.ToA( em, 0, OUT ErrorMessage );
    RETURN FALSE;
  END;
  RETURN TRUE;
END Init;

PROCEDURE Init3(     PData        : ADDRESS;
                     RunMode      : CARDINAL;
                 VAR SymbolicName : ARRAY OF CHAR;
                     CallbackId   : ADDRESS;
                     PCallback    : drv_def.TDriverCallbackW ) : BOOLEAN;
VAR
  ES : ARRAY [0..3] OF WCHAR;
  sn : ARRAY [0..255] OF WCHAR;
BEGIN
  Strings.ToW( SymbolicName, 0, OUT sn );
  RETURN InitCommon( PData, RunMode, sn, CallbackId, PCallback, ES );
END Init3;

PROCEDURE InitW(     PData        : ADDRESS;
                 VAR ParFilePath  : ARRAY OF WCHAR;
                 VAR ErrorMessage : ARRAY OF WCHAR;
                     UserLevel    : CARDINAL;
                     RunFlag      : BOOLEAN;
                     CallbackId   : ADDRESS;
                     PCallback    : drv_def.TDriverCallbackW ) : BOOLEAN;
VAR
  ec, el  : CARDINAL;
  hoh     : ARRAY [0..3] OF WCHAR;
  RunMode : CARDINAL;
BEGIN
  IF RunFlag THEN
    RunMode := drv_def.drmRun;
  ELSE
    RunMode := drv_def.drmEdit;
  END;
  ErrorMessage[0] := WCHAR( 0 );
  IF InitCommon( PData, RunMode, hoh, CallbackId, PCallback, ErrorMessage ) THEN
    IF NOT ReadParametersW( PData, ParFilePath, ErrorMessage, el, ec, hoh ) THEN
      RETURN FALSE;
    END;
    RunW( PData );
  ELSIF ErrorMessage[0] = WCHAR( 0 ) THEN
    ASSIGN( ErrorMessage, OAsz( GR[ Texts._InitError ] ));
    RETURN FALSE;
  ELSE
    RETURN FALSE;
  END;
  RETURN TRUE;
END InitW;

PROCEDURE Init3W(    PData        : ADDRESS;
                     RunMode      : CARDINAL;
                 VAR SymbolicName : ARRAY OF WCHAR;
                     CallbackId   : ADDRESS;
                     PCallback    : drv_def.TDriverCallbackW ) : BOOLEAN;
VAR
  ES : ARRAY [0..3] OF WCHAR;
BEGIN
  RETURN InitCommon( PData, RunMode, SymbolicName, CallbackId, PCallback, ES );
END Init3W;

//--------------------------------------------------------------------------------

PROCEDURE ReadParameters(             PData : ADDRESS;
                           VAR ParFilePath  : ARRAY OF CHAR;
                           VAR ErrorMessage : ARRAY OF CHAR;
                           VAR ErrorLine    : CARDINAL;
                           VAR ErrorColumn  : CARDINAL;
                           VAR HintOrHelp   : ARRAY OF CHAR ) : BOOLEAN;
VAR
  pf, em, hoh : ARRAY [0..287] OF WCHAR;
  b : BOOLEAN;
BEGIN
  Strings.ToW( ParFilePath, 0, OUT pf );
  b := TPDriver( PData )^.ReadParameters( pf, em, ErrorLine, ErrorColumn, hoh );
  Strings.ToA( em, 0, OUT ErrorMessage );
  Strings.ToA( hoh, 0, OUT HintOrHelp );
  RETURN b;
END ReadParameters;

PROCEDURE ReadParametersW(            PData : ADDRESS;
                           VAR ParFilePath  : ARRAY OF WCHAR;
                           VAR ErrorMessage : ARRAY OF WCHAR;
                           VAR ErrorLine    : CARDINAL;
                           VAR ErrorColumn  : CARDINAL;
                           VAR HintOrHelp   : ARRAY OF WCHAR ) : BOOLEAN;
BEGIN
  RETURN TPDriver( PData )^.ReadParameters( ParFilePath, ErrorMessage, ErrorLine, ErrorColumn, HintOrHelp );
END ReadParametersW;

PROCEDURE EnumerateChannelsW( PData : ADDRESS;
                              VAR EnumerateState : LONGWORD;
                              VAR Type : CARDINAL;
                              VAR Direction : CARDINAL;
                              VAR DriverIndex : CARDINAL;
                              VAR Count : CARDINAL;
                              VAR HaveDescription : BOOLEAN
                            ): BOOLEAN;
BEGIN
  RETURN TPDriver( PData )^.EnumerateChannels( EnumerateState, Type, Direction, DriverIndex, Count, HaveDescription );
END EnumerateChannelsW;

//--------------------------------------------------------------------------------

PROCEDURE QueryErrorCode(          PData : ADDRESS;
                               ErrorCode : CARDINAL;
                           VAR ErrorText : ARRAY OF CHAR ) : BOOLEAN;
VAR
  et : ARRAY [0..255] OF WCHAR;
  b : BOOLEAN;
BEGIN
  b := QueryErrorCodeW( PData, ErrorCode, et );
  Strings.ToA( et, 0, OUT ErrorText );
  RETURN b;
END QueryErrorCode;

PROCEDURE QueryErrorCodeW(         PData : ADDRESS;
                               ErrorCode : CARDINAL;
                           VAR ErrorText : ARRAY OF WCHAR ) : BOOLEAN;
BEGIN
  CASE ErrorCode OF
  | ecDeviceStopped :
    ASSIGN( ErrorText, OAsz( GR[ Texts._E_DeviceStopped ] ));
  ////
  ELSE
    RETURN FALSE;
  END;
  RETURN TRUE;
END QueryErrorCodeW;

//--------------------------------------------------------------------------------

PROCEDURE BufferInfoW( PData : ADDRESS; DriverIndex : CARDINAL; BType : CARD8; BLen : CARDINAL ) : BOOLEAN;
BEGIN
  RETURN FALSE;
END BufferInfoW;

//--------------------------------------------------------------------------------

PROCEDURE SetBufferAddrW( PData : ADDRESS; DriverIndex : CARDINAL; PBuffer : ADDRESS );
BEGIN
END SetBufferAddrW;

//--------------------------------------------------------------------------------

PROCEDURE RunW( PData : ADDRESS );
BEGIN
  TPDriver( PData )^.Run();
END RunW;

//--------------------------------------------------------------------------------

PROCEDURE StopW( PData : ADDRESS );
BEGIN
  TPDriver( PData )^.Stop();
END StopW;

//--------------------------------------------------------------------------------

PROCEDURE DoneW( PData : ADDRESS );
BEGIN
  TPDriver( PData )^.Done();
END DoneW;

//--------------------------------------------------------------------------------

PROCEDURE DriverProcW( PData : ADDRESS; Func, Param1, Param2, Param3, Param4 : CARDINAL );
BEGIN
END DriverProcW;

//--------------------------------------------------------------------------------

PROCEDURE QueryProc( PData : ADDRESS; InValue : drv_def.TValue; VAR OutValue : drv_def.TValue );
BEGIN
  QueryProc3( PData, InValue, OutValue, OutValue );
END QueryProc;

//--------------------------------------------------------------------------------

PROCEDURE QueryProcW( PData : ADDRESS; InValue : drv_def.TValue; VAR OutValue : drv_def.TValue );
BEGIN
  QueryProc3W( PData, InValue, OutValue, OutValue );
END QueryProcW;

//--------------------------------------------------------------------------------

PROCEDURE QueryProc3( PData : ADDRESS; InValue1, InValue2 : drv_def.TValue; VAR OutValue : drv_def.TValue );
BEGIN
  TPDriver( PData )^.QueryProc( FALSE, InValue1, InValue2, OutValue );
END QueryProc3;

//--------------------------------------------------------------------------------

PROCEDURE QueryProc3W( PData : ADDRESS; InValue1, InValue2 : drv_def.TValue; VAR OutValue : drv_def.TValue );
BEGIN
  TPDriver( PData )^.QueryProc( TRUE, InValue1, InValue2, OutValue );
END QueryProc3W;

//--------------------------------------------------------------------------------

PROCEDURE InputRequestStartW( PData : ADDRESS );
BEGIN
  TPDriver( PData )^.InputRequestStart();
END InputRequestStartW;

//--------------------------------------------------------------------------------

PROCEDURE InputRequestW( PData : ADDRESS; DriverIndex : CARDINAL );
BEGIN
  TPDriver( PData )^.InputRequest( DriverIndex );
END InputRequestW;

//--------------------------------------------------------------------------------

PROCEDURE InputRequestCompletedW( PData : ADDRESS );
BEGIN
  TPDriver( PData )^.InputRequestCompleted();
END InputRequestCompletedW;

//--------------------------------------------------------------------------------

PROCEDURE InputFinalizedW( PData : ADDRESS; DriverIndex : CARDINAL; VAR ErrorCode : CARDINAL ) : BOOLEAN;
BEGIN
  RETURN TPDriver( PData )^.InputFinalized( DriverIndex, ErrorCode );
END InputFinalizedW;

//--------------------------------------------------------------------------------

PROCEDURE InputOOBDataQueryW( PData : ADDRESS; VAR EnumerateState : LONGWORD; VAR DriverIndex : CARDINAL ) : BOOLEAN;
BEGIN
  RETURN TPDriver( PData )^.InputOOBDataQuery( EnumerateState, DriverIndex );
END InputOOBDataQueryW;

//--------------------------------------------------------------------------------

PROCEDURE GetInput( PData : ADDRESS; DriverIndex : CARDINAL; VAR InValue : drv_def.TValue );
VAR
  ec : CARDINAL;
  QoS : CARDINAL;
  ts : drv_def.TUTCStamp;
BEGIN
  GetInput3( PData, DriverIndex, InValue, QoS, ts, ec );
END GetInput;

PROCEDURE GetInput3( PData : ADDRESS; DriverIndex : CARDINAL; VAR InValue : drv_def.TValue; VAR QoS : CARDINAL; VAR TimeStamp : drv_def.TUTCStamp; VAR ErrorCode : CARDINAL );
BEGIN
  TPDriver( PData )^.GetInput( FALSE, DriverIndex, InValue, QoS, TimeStamp, ErrorCode );
END GetInput3;

PROCEDURE GetInputW( PData : ADDRESS; DriverIndex : CARDINAL; VAR InValue : drv_def.TValue );
VAR
  ec : CARDINAL;
  QoS : CARDINAL;
  ts : drv_def.TUTCStamp;
BEGIN
  GetInput3W( PData, DriverIndex, InValue, QoS, ts, ec );
END GetInputW;

PROCEDURE GetInput3W( PData : ADDRESS; DriverIndex : CARDINAL; VAR InValue : drv_def.TValue; VAR QoS : CARDINAL; VAR TimeStamp : drv_def.TUTCStamp; VAR ErrorCode : CARDINAL );
BEGIN
  TPDriver( PData )^.GetInput( TRUE, DriverIndex, InValue, QoS, TimeStamp, ErrorCode );
END GetInput3W;

//--------------------------------------------------------------------------------

PROCEDURE OutputRequestStartW( PData : ADDRESS );
BEGIN
  TPDriver( PData )^.OutputRequestStart();
END OutputRequestStartW;

//--------------------------------------------------------------------------------

PROCEDURE OutputRequest( PData : ADDRESS; DriverIndex : CARDINAL; OutValue : drv_def.TValue );
VAR
  ts : drv_def.TUTCStamp;
BEGIN
  OutputRequest3( PData, DriverIndex, OutValue, drv_def.qosGood, ts );
END OutputRequest;

PROCEDURE OutputRequest3( PData : ADDRESS; DriverIndex : CARDINAL; OutValue : drv_def.TValue; QoS : CARDINAL; VAR TimeStamp : drv_def.TUTCStamp );
BEGIN
  TPDriver( PData )^.OutputRequest( FALSE, DriverIndex, OutValue, QoS, TimeStamp );
END OutputRequest3;

PROCEDURE OutputRequestW( PData : ADDRESS; DriverIndex : CARDINAL; OutValue : drv_def.TValue );
VAR
  ts : drv_def.TUTCStamp;
BEGIN
  OutputRequest3W( PData, DriverIndex, OutValue, drv_def.qosGood, ts );
END OutputRequestW;

PROCEDURE OutputRequest3W( PData : ADDRESS; DriverIndex : CARDINAL; OutValue : drv_def.TValue; QoS : CARDINAL; VAR TimeStamp : drv_def.TUTCStamp );
BEGIN
  TPDriver( PData )^.OutputRequest( TRUE, DriverIndex, OutValue, QoS, TimeStamp );
END OutputRequest3W;

//--------------------------------------------------------------------------------

PROCEDURE OutputRequestCompletedW( PData : ADDRESS );
BEGIN
  TPDriver( PData )^.OutputRequestCompleted();
END OutputRequestCompletedW;

//--------------------------------------------------------------------------------

PROCEDURE OutputFinalizedW( PData : ADDRESS; DriverIndex : CARDINAL; VAR ErrorCode : CARDINAL ) : BOOLEAN;
BEGIN
  RETURN TPDriver( PData )^.OutputFinalized( DriverIndex, ErrorCode );
END OutputFinalizedW;

//================================================================================

INITIALLY __I();
BEGIN
  // self
  RefCount := 0;
  // global resources
  GR.LoadRES2( EMITW( %dll ), L'NetMsg.Texts' );
  GR.Lang := Languages.GetDefaultLanguage( Languages.dlUser );
END __I;

FINALLY __F();
BEGIN
END __F;

//================================================================================

END NetMsg.
