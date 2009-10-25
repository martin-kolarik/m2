MODULE RemoteASCIIDrv;

(*# call( o_a_copy => off ) *)

(*================================================================================*)

FROM Storage IMPORT
  ALLOCATE, DEALLOCATE;
  
FROM Strings IMPORT
  CapitalizeW;  
  
FROM log IMPORT
  dldTrace, dldDebug;

IMPORT
   cllv,
   cphcommon,
   diface,
   drv_def,
   FIO,
   FIOO,
   INIFile,
   IOO,
   iovalue,
   Languages,
   lec,
   log,
   msgqueue,
   netsocket,
   rawconnection,
   Resources,
   Strings,
   StringsO,
   StorageO,
   Sync,
   TextReader,
   Texts;

(*================================================================================*)

CONST // device specific error codes
   ecRxTimeout = drv_def.ecCommunicationTimeout;
   ecDeviceStopped = drv_def.ecUser + 1;

CONST
   logPrefix = L"RemoteASCIIDrv";

CONST // driver channels
   chStatus = 1;

(*================================================================================*)

TYPE
   TPDriver = POINTER TO CDriver;

   TRStatusItem  = (
      rsRunning,
      rsEventsPending,
      rsValid,
      rsGlobalKey
   );
   TRStatus = SET OF TRStatusItem;

CONST
   rssUser = TRStatus{rsRunning, rsEventsPending, rsValid};
  
(*--------------------------------------------------------------------------------*)

CLASS CNotifier( netsocket.ASocketNotifier );
   Driver : TPDriver;
   LOCAL VIRTUAL PROCEDURE OnConnect( Result : CARDINAL; CONST Socket : netsocket.TPDSocket; Local : BOOLEAN ); 
   LOCAL VIRTUAL PROCEDURE OnDisconnect( Result : CARDINAL; CONST Socket : netsocket.TPDSocket; Local : BOOLEAN ); // calling Socket^.Release is safe if OnDisconnect is called from OnHandle. Otherwise (when OnDisconnect is called synchronously from Disconnect) it can be dangerous.
   PUBLIC VIRTUAL PROCEDURE OnFlowPossible( Direction : IOO.TDirection; Source : ADDRESS );
   PUBLIC VIRTUAL PROCEDURE OnReadable( Length : CARDINAL; Source : ADDRESS );
END CNotifier;

(*================================================================================*)

TYPE
   TEvent = (
      evNone = 0,
      evRxError = 1,
      evTxError = 2,
      evDataReceived = 3,
      evDriverError = 4,
      
      evConnect = 100,
      evDisconnect = 101
   );
   
   TASCIIError = (
      erOK = 0,
      erTxBufferFull = 1018,
      erRxBufferFull = 1019,
      erBadQueryProcedureParameter = 1020,
      erNoData = 1021,
      erUnknownQueryProcedure = 1022,
      erNotConnected = 1025,
      erBadHexString = 1027
   );

   TEventData   = RECORD
                     CASE Event : TEvent OF
                     | evRxError, evTxError :
                        ASCIIError : TASCIIError;
                     | evDataReceived :
                        Length : CARDINAL;
                     | evConnect, evDisconnect :
                        NetError : CARDINAL;
                        Local : BOOLEAN;
                     END; // CASE
                  END; // RECORD
   TPEventData  = POINTER TO TEventData;

(*--------------------------------------------------------------------------------*)

CLASS CDriver IMPLEMENTS diface.ICWDriver;
   R             : Resources.CResources;
   RStatus       : TRStatus;
   Name          : StringsO.CString;
   Logger        : log.CLogger;

   CallbackId    : ADDRESS;
   CallbackProc  : drv_def.TDriverCallbackW;
   RunMode       : CARDINAL;
   Result        : lec.CResult;

   // driver data
   Notifier      : CNotifier;
   Connection    : rawconnection.TCPConnection;
   Events        : msgqueue.CPtrQueue;
   LastError     : TASCIIError;
   Delimiter     : WCHAR;

   WBuffer       : StorageO.CMemoryBuffer;
   WIndex        : CARDINAL;
   RBufferLock   : Sync.LOCK;
   RBuffer       : StorageO.CMemoryBuffer;
   RIndex        : CARDINAL;

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

   PRIVATE PROCEDURE DecodeASCIIString( REF String : StringsO.CString ) : BOOLEAN;
   PRIVATE PROCEDURE EncodeASCIIString( REF String : StringsO.CString );
   PRIVATE PROCEDURE ProcessASCIICommand( CONST Command : StringsO.CString; CONST InValue2 : iovalue.Value; OUT OutValue : iovalue.Value ) : BOOLEAN;
   PRIVATE PROCEDURE AddEvent( Event : POINTER TO TEventData );

   // callbacks
   LOCAL PROCEDURE OnConnect( Local : BOOLEAN; Error : CARDINAL );
   LOCAL PROCEDURE OnDisconnect( Local : BOOLEAN; Error : CARDINAL );
   LOCAL PROCEDURE OnDataReceived( Length : CARDINAL );
   LOCAL PROCEDURE OnFlowPossible( Direction : IOO.TDirection );
END CDriver;

(*================================================================================*)

CLASS IMPLEMENTATION CNotifier;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnConnect( Result : CARDINAL; CONST Socket : netsocket.TPDSocket; Local : BOOLEAN ); 
   BEGIN
      Driver^.OnConnect( Local, Result );
   END OnConnect;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnDisconnect( Result : CARDINAL; CONST Socket : netsocket.TPDSocket; Local : BOOLEAN ); // calling Socket^.Release is safe if OnDisconnect is called from OnHandle. Otherwise (when OnDisconnect is called synchronously from Disconnect) it can be dangerous.
   BEGIN
      Driver^.OnDisconnect( Local, Result );
   END OnDisconnect;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnReadable( Length : CARDINAL; Source : ADDRESS );
   BEGIN
      Driver^.OnDataReceived( Length );
   END OnReadable;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnFlowPossible( Direction : IOO.TDirection; Source : ADDRESS );
   BEGIN
      Driver^.OnFlowPossible( Direction );
   END OnFlowPossible;

(*--------------------------------------------------------------------------------*)

BEGIN
   Driver := NIL;
END CNotifier;

(*================================================================================*)

CLASS IMPLEMENTATION CDriver;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Initialize( _RunMode : CARDINAL; CONST SymbolicName : StringsO.CString; CallbackId : ADDRESS; CallbackProc : drv_def.TDriverCallbackW );
   BEGIN
      SELF.CallbackId := CallbackId;
      SELF.CallbackProc := CallbackProc;
      RunMode := _RunMode;
      Name := SymbolicName;
   END Initialize;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE ReadParameters( CONST ParametersFilePath : StringsO.CString; CONST Logger : log.CLogger ) : BOOLEAN;
   LABEL
      Fail;
   CONST
      snDevice = L'RemoteASCIIDrv';

  //----------
  
      PROCEDURE Error( ErrorCode, ErrorLine : CARDINAL );
      BEGIN
         Logger.LogFilePos( log.dlcError, L"", OA( ParametersFilePath.Length-1, ParametersFilePath.rawData ), OAsz( R[ ErrorCode ] ), ErrorLine, 0 );
      END Error;

  //----------

  VAR
    ErrorLine : CARDINAL;
    fs : FIOO.CFileStream;
    TS : INIFile.CINIFile;
    tr : TextReader.CTextReader;
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

      IF NOT TS.SetSection( snDevice ) THEN
         IF RunMode = drv_def.drmRun THEN
            Error( Texts._MissingDeviceSection, 0 );
            GOTO Fail;
         ELSE
            RETURN TRUE;
         END;
      END;

      CASE INIFile.ConfigureLog( TS, L"", REF SELF.Logger, OUT ErrorLine ) OF
      | INIFile.clrUnknownTarget :
         Error( Texts._UnknownDebugMode, ErrorLine );
      | INIFile.clrUnknownLevel :
         Error( Texts._UnknownDebugLevel, ErrorLine );
      | INIFile.clrTargetFileMissingFile :
         Error( Texts._FileDebugMissingFile, ErrorLine );
      END; // CASE
    
      RETURN TRUE;

   Fail:
      // remove temporary structures
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
   BEGIN
      IF EnumerateState = 0 THEN
         // status channel
         Direction := drv_def.TDirection{drv_def.dirInput};
         DriverIndex := chStatus;
         Type := drv_def.vtLongCard;

      ELSE
         RETURN FALSE;
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
   END DriverRun;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE DriverStop();
   BEGIN
      IF TRStatus{rsRunning} * RStatus = TRStatus{} THEN
         RETURN;
      END;
      
      Connection.Close();
      EXCL( RStatus, rsRunning );
   END DriverStop;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   BEGIN
      Events.Dispose();
   END Dispose;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE QueryProc( CONST InValue1, InValue2 : iovalue.Value; OutValueLimit : CARDINAL; OUT OutValue : iovalue.Value );
   LABEL
      DoSend, Error, Success;
   VAR
      c, l : CARDINAL;
      Event : POINTER TO TEventData;
      n : ARRAY [0..31] OF WCHAR;
      si : StringsO.CString;
      sw : StringsO.CString;
   BEGIN
      sw := InValue1.String;
      sw.ItemS( StringsO.WCHARS{ L' ' }, 0, 0, TRUE, OUT si );
      Result.Inc();

      IF si.EqualsOA( L'event' ) THEN
         sw.ItemS( StringsO.WCHARS{ L' ' }, 0, 1, TRUE, OUT si );

         IF si.EqualsOA( L'count' ) THEN
            c := Events.Count;
            Logger.LogSC( dldDebug, logPrefix, L"Event.Count ", c );

            OutValue.Integer := c; 
            RETURN;
      
         ELSIF si.EqualsOA( L'get' ) THEN
            IF Result.Counted OR Result.Expired THEN
               Logger.LogS( dldDebug, logPrefix, L"Event.Get clear buffer" );
               Events.Dispose();

               GOTO Success;

            ELSIF Events.Peek( OUT Event ) THEN
               Logger.LogSC( dldDebug, logPrefix, L"Event.Peek ", CARDINAL( Event^.Event ));

               CASE Event^.Event OF
               //-----
               | evRxError :
                  sw.FromOA( L'rx_error' );
                  sw.AppendOA( Delimiter );
                  Strings.FromCARD32W( CARDINAL( Event^.ASCIIError ), 10, OUT n );
                  sw.AppendOA( n );
               //-----
               | evTxError :
                  sw.FromOA( L'tx_error' );
                  sw.AppendOA( Delimiter );
                  Strings.FromCARD32W( CARDINAL( Event^.ASCIIError ), 10, OUT n );
                  sw.AppendOA( n );
               //-----
               | evDriverError :
                  sw.FromOA( L'driver_error' );
                  sw.AppendOA( Delimiter );
                  Strings.FromCARD32W( CARDINAL( Event^.ASCIIError ), 10, OUT n );
                  sw.AppendOA( n );
               
               //-----
               | evConnect :
                  sw.FromOA( L'client_connect' );
                  sw.AppendOA( Delimiter );
                  Strings.FromCARD32W( Event^.NetError, 10, OUT n );
                  sw.AppendOA( n );
               //-----
               | evDisconnect :
                  IF Event^.Local THEN
                     sw.FromOA( L'client_disconnect' );
                  ELSE
                     sw.FromOA( L'server_disconnect' );
                  END;
                  sw.AppendOA( Delimiter );
                  Strings.FromCARD32W( Event^.NetError, 10, OUT n );
                  sw.AppendOA( n );
                  
                  Connection.Close();

               //-----
               | evDataReceived :
                  sw.FromOA( L'server_data' );
                  sw.AppendOA( Delimiter );
                  Strings.FromCARD32W( Event^.Length, 10, OUT n );
                  sw.AppendOA( n );
               END;

               OutValue.String := sw;
               IF sw.Length < OutValueLimit THEN // OK
                  Events.Dequeue( OUT Event );
                  DISPOSE( Event );
               // ELSE // wait for longer string, leave event in queue
               END;
               RETURN;

            ELSE
               Logger.LogS( dldDebug, logPrefix, L"Event.Emptied" );
            END; // IF Events.Dequeue

            GOTO Success;
        
         ELSE
            sw.FromOA( OAsz( R[ Texts._UnrecognizedEventCommand ] ));
            GOTO Error;
         END;

      ELSIF si.EqualsOA( L'client' ) THEN
         sw.ItemS( StringsO.WCHARS{ L' ' }, 0, 1, TRUE, OUT si );

         IF si.EqualsOA( L'connect' ) THEN
            IF Connection.Connected THEN
               sw.FromOA( OAsz( R[ Texts._AlreadyConnected ] ));
               GOTO Error;
            END;
         
            sw.ItemS( StringsO.WCHARS{ L' ' }, 0, 2, TRUE, OUT si );
            Connection.OpenS( si, FALSE, netsocket.FORSAFETY );

         ELSIF si.EqualsOA( L'disconnect' ) THEN
            Connection.Close();

         ELSIF si.EqualsOA( L'send' ) THEN
            IF NOT Connection.Connected THEN
               sw.FromOA( OAsz( R[ Texts._NotConnected ] ));
               GOTO Error;
            END;
         
            sw.ItemS( StringsO.WCHARS{ L' ' }, 0, 2, TRUE, OUT si );

            l := WBuffer.Size - WBuffer.Length;
            IF si.Length MOD 2 = 1 THEN
               sw.FromOA( OAsz( R[ Texts._BadSendData ] ));
               GOTO Error;
            ELSIF si.Length DIV 2 > l THEN
               sw.FromOA( OAsz( R[ Texts._NotEnoughWriteSpace ] ));
               GOTO Error;
            ELSIF WBuffer.Length + si.Length DIV 2 > Connection.BufferedStream^.WriteSpace THEN
               sw.FromOA( OAsz( R[ Texts._NotEnoughWriteSpace ] ));
               GOTO Error;
            END;

            IF NOT cphcommon.FromHex( OA( si.Length-1, si.rawData ), OUT OA( l-1, ADDRESS( WBuffer.Data@[WBuffer.Length] )), OUT c ) THEN
               sw.FromOA( OAsz( R[ Texts._BadCharacterInDataToSend ] ));
               GOTO Error;
            ELSE
               INC( WBuffer.Length, c );
               Connection.Stream^.WriteBuffer( WBuffer, OUT c, netsocket.FORSAFETY );
               WBuffer.RemoveStart( c );
            END;

         ELSIF si.EqualsOA( L'receive' ) THEN
            RBufferLock.Lock();
            c := MIN2( OutValueLimit DIV 2, RBuffer.Length );
            l := c << 1;
            IF l > 0 THEN
               sw.Size := l;
               sw.Length := l;
               cphcommon.ToHex( OA( c-1, ADDRESS( RBuffer.Data )), OUT OA( l-1, PWCHAR( sw.rawData )));
               RBuffer.RemoveStart( c );
            ELSE
               sw.Clear();
            END;
            RBufferLock.Unlock();
            
            OutValue.String := sw;
            RETURN;
         
         ELSIF si.EqualsOA( L'available' ) THEN
            c := RBuffer.Length;
            Logger.LogSC( dldDebug, logPrefix, L"Client.Available ", c );

            OutValue.Integer := c; 
            RETURN;

         ELSE
            sw.FromOA( OAsz( R[ Texts._UnrecognizedClientCommand ] ));
            GOTO Error;
         END;
         GOTO Success;
         
      ELSIF ProcessASCIICommand( si, InValue2, OUT OutValue ) THEN
         RETURN;

      ELSE
         sw.FromOA( OAsz( R[ Texts._UnrecognizedCommand ] ));
      END;

   Error:
      OutValue.String := sw;
      RETURN;

   Success:
      sw.Clear();
      OutValue.String := sw;
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
   BEGIN
      ErrorCode := 0;
      IF DriverIndex = chStatus THEN
         // return always OK
      ELSIF TRStatus{rsRunning} * RStatus = TRStatus{} THEN
         ErrorCode := ecDeviceStopped;
      ELSIF Result.Expired OR Result.Counted THEN // locked by self
         RETURN FALSE;
      ELSE
         ////
      END;
      RETURN TRUE;
   END InputFinalized;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE InputOOBDataQuery( REF EnumerateState : LONGWORD; OUT DriverIndex : CARDINAL ) : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END InputOOBDataQuery;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE GetInput( DriverIndex : CARDINAL; InValueLimit : CARDINAL; OUT InValue : iovalue.Value; OUT QoS : CARDINAL; OUT TimeStamp : drv_def.TUTCStamp; OUT ErrorCode : CARDINAL );
   BEGIN
      ErrorCode := drv_def.ecSuccess;
      QoS := drv_def.qosGood;

      IF DriverIndex = chStatus THEN
         IF Result.Counted OR Result.Expired THEN // locked by self
            EXCL( RStatus, rsValid );
         ELSE
            INCL( RStatus, rsValid );
         END;
         IF Events.Empty THEN
            EXCL( RStatus, rsEventsPending );
         ELSE
            INCL( RStatus, rsEventsPending );
         END;
         InValue.Integer := CARDINAL( RStatus * rssUser );

      ELSE
         ErrorCode := drv_def.ecUnknownElement;
      END;
   END GetInput;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OutputRequestStart();
   BEGIN
   END OutputRequestStart;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OutputRequest( DriverIndex : CARDINAL; CONST OutValue : iovalue.Value; QoS : CARDINAL; CONST TimeStamp : drv_def.TUTCStamp );
   BEGIN
      Result.Inc(); // locked by self
   END OutputRequest;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE OutputRequestCompleted();
  BEGIN
  END OutputRequestCompleted;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE OutputFinalized( DriverIndex : CARDINAL; OUT ErrorCode : CARDINAL ) : BOOLEAN;
  BEGIN
    ErrorCode := 0;
    RETURN NOT Result.Expired AND NOT Result.Counted; // locked by self
  END OutputFinalized;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE DecodeASCIIString( REF String : StringsO.CString ) : BOOLEAN;
   VAR
      byte : BYTE;
      c, i, l : INTEGER;
   BEGIN
      l := String.Length;
      i := 0;
      WHILE i <= l-3 DO // If escape character expects something more, it still cannot be read. Concurrently this allows safe accessing index i+1, i+2 of String in the while loop.
         IF String[i] = L"~" THEN
            IF String[i+1] = L"~" THEN // reduce ~ escape
               String.Remove( i, 1 );
            ELSE // reduce time value
               String.Remove( i, 3 );
            END;
            l := String.Length;
         ELSIF String[i] = L"#" THEN
            IF String[i+1] = L"#" THEN // reduce # escapce
               String.Remove( i, 1 );
            ELSIF cphcommon.FromHex( OA( 1, String.rawData@[2*(i+1)] ), OUT byte, OUT c ) THEN // reduce hexadecimal character
               String.Remove( i, 2 );
               String[i] := WCHAR( byte );
            ELSE
               RETURN FALSE;
            END;
            l := String.Length;
         END;
         INC( i );
      END; // WHILE

      RETURN TRUE;
   END DecodeASCIIString;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE EncodeASCIIString( REF String : StringsO.CString );
   VAR
      code : ARRAY [0..1] OF WCHAR;
      encoded : StringsO.CString;
      ei, i : INTEGER;
   BEGIN
      encoded.Size := String.Length + 16;
      ei := 0;
      FOR i := 0 TO String.Length-1 DO
         IF ( String[i] >= L" " ) AND ( String[i] <> L"#" ) AND ( String[i] <= 127W ) THEN
            encoded[ei] := String[i];
            INC( ei );
         ELSE
            cphcommon.ToHex( BYTE( String[i] ), OUT code ); CAP( code );
            encoded[ei] := L"#";
            encoded.Length := ei+1;
            encoded.AppendOA( code );
            ei := encoded.Length;
         END;
      END;
      encoded.Length := ei;
      String := encoded;
   END EncodeASCIIString;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ProcessASCIICommand( CONST Command : StringsO.CString; CONST InValue2 : iovalue.Value; OUT OutValue : iovalue.Value ) : BOOLEAN;
   VAR
      b : BOOLEAN;
      c : CARDINAL;
      empty, s : StringsO.CString;
      Event : POINTER TO TEventData;
   BEGIN
      IF Command.EqualsOA( L"GetResult" ) THEN
         OutValue.Integer := INTEGER( LastError );
      
      ELSIF Command.EqualsOA( L"GetExcStatus" ) THEN
         IF Events.Peek( OUT Event ) THEN
            OutValue.Integer := INTEGER( Event^.Event );
         ELSE
            OutValue.Integer := INTEGER( evNone );
         END;

         LastError := erOK;
      
      ELSIF Command.EqualsOA( L"GetErrorCode" ) THEN
         IF Events.Peek( OUT Event ) THEN
            CASE Event^.Event OF
            | evRxError, evTxError, evDriverError :
               OutValue.Integer := INTEGER( Event^.ASCIIError );
            | evConnect, evDisconnect :
               OutValue.Integer := INTEGER( Event^.NetError );
            ELSE
               OutValue.Integer := 0;
            END;
         ELSE
            OutValue.Integer := 0;
         END;

         LastError := erOK;
      
      ELSIF Command.EqualsOA( L"EnableException" ) THEN
         c := Events.Count;
         IF c > 0 THEN
            Events.Dequeue( OUT Event );
            DISPOSE( Event );
            IF c > 1 THEN
               CallbackProc( CallbackId, drv_def.dcfException, NIL );
            END;
         END;

         LastError := erOK;
      
      ELSIF Command.EqualsOA( L"GetRxCount" ) THEN
         RBufferLock.Lock();
         OutValue.Integer := RBuffer.Length;
         RBufferLock.Unlock();

         LastError := erOK;
      
      ELSIF Command.EqualsOA( L"ClearRxQueue" ) THEN
         RBufferLock.Lock();
         RBuffer.Clear();
         RBufferLock.Unlock();
         RIndex := 0;         

         LastError := erOK;

      ELSIF Command.EqualsOA( L"GetCharSeq" ) THEN
         RBufferLock.Lock();
         b := RIndex < RBuffer.Length;
         IF b THEN
            s.Size := 1;
            s.Length := 1;
            s[0] := WCHAR( RBuffer[RIndex] );
         END;
         RBufferLock.Unlock();

         IF b THEN
            IF InValue2.Type = iovalue.vtString THEN // OutValue is paired with InValue2, so output should be string
               EncodeASCIIString( REF s );
               OutValue.String := s;
            ELSE // OutValue is not string, assume it is number and assign ORD of found character
               OutValue.Integer := ORD( s[0] );
            END;
            INC( RIndex );

            LastError := erOK;
         ELSE
            // NEW( Event ); // error
            // Event^.Event := evRxError;
            // Event^.ASCIIError := erNoData;
            // AddEvent( Event );

            LastError := erNoData;
         END;

      ELSIF Command.EqualsOA( L"SetRxIndex" ) THEN
         RIndex := InValue2.Integer;
         LastError := erOK;
      
      ELSIF Command.EqualsOA( L"GetTxCount" ) THEN
         OutValue.Integer := WBuffer.Length;
         LastError := erOK;

      ELSIF Command.EqualsOA( L"ClearTxQueue" ) THEN
         WBuffer.Clear();
         WIndex := 0;
         LastError := erOK;
      
      ELSIF Command.EqualsOA( L"PutCharSeq" ) THEN
         IF WIndex >= WBuffer.Size THEN
            // NEW( Event ); // error
            // Event^.Event := evTxError;
            // Event^.ASCIIError := erTxBufferFull;
            // AddEvent( Event );

            LastError := erTxBufferFull;

         ELSIF InValue2.Type = iovalue.vtString THEN
            s := InValue2.String;
            IF DecodeASCIIString( REF s ) THEN
               LastError := erOK;
            ELSE
               // NEW( Event ); // error
               // Event^.Event := evTxError;
               // Event^.ASCIIError := erBadHexString;
               // AddEvent( Event );

               LastError := erBadHexString;
            END;

         ELSE // assume InValue2 is number = ordinal number of character
            s.FromOA( WCHAR( InValue2.Integer ));

            LastError := erOK;
         END;
             
         IF LastError = erOK THEN
            WBuffer.Length := MAX2( WBuffer.Length, WIndex+1 );
            WBuffer[WIndex] := BYTE( s[0] );
            INC( WIndex );
         END;

      ELSIF Command.EqualsOA( L"SetTxIndex" ) THEN
         WIndex := InValue2.Integer;
         LastError := erOK;
      
      ELSIF Command.EqualsOA( L"SendAsync" ) THEN
         WBuffer.Length := InValue2.Integer;

         IF NOT Connection.Connected THEN
            // NEW( Event ); // error
            // Event^.Event := evTxError;
            // Event^.ASCIIError := erNotConnected;
            // AddEvent( Event );

            LastError := erNotConnected;
         ELSIF WBuffer.Length > Connection.BufferedStream^.WriteSpace THEN
            // NEW( Event ); // error
            // Event^.Event := evTxError;
            // Event^.ASCIIError := erTxBufferFull;
            // AddEvent( Event );

            LastError := erTxBufferFull;
         ELSE
            Connection.Stream^.WriteBuffer( WBuffer, OUT c, netsocket.FORSAFETY );
            WBuffer.RemoveStart( c );

            LastError := erOK;
         END;
      
      ELSE
         // NEW( Event ); // error
         // Event^.Event := evDriverError;
         // Event^.ASCIIError := erUnknownQueryProcedure;
         // AddEvent( Event );

         LastError := erUnknownQueryProcedure;

         RETURN FALSE;
      END;
      RETURN TRUE;
   END ProcessASCIICommand;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE AddEvent( Event : POINTER TO TEventData );
   BEGIN
      Events.Enqueue( Event );
      IF Events.Produce^.State THEN
         Logger.LogSC( dldDebug, logPrefix, L"Event.Queued, fire dcfException ", CARDINAL( Event^.Event ));
         CallbackProc( CallbackId, drv_def.dcfException, NIL );
      ELSE
         Logger.LogSC( dldDebug, logPrefix, L"Event.Queued, NOT FIRED dcfException ", CARDINAL( Event^.Event ));
      END;
   END AddEvent;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE OnConnect( Local : BOOLEAN; Error : CARDINAL );
   VAR
      Event : POINTER TO TEventData;
   BEGIN
      Logger.LogSC( dldDebug, logPrefix, L"Event.Add evConnect ", CARDINAL( Error ));

      NEW( Event );
      Event^.Event := evConnect;
      Event^.NetError := Error;
      Event^.Local := Local;

      AddEvent( Event );

      Connection.BufferedStream^.StartReading(); // start advise reading
   END OnConnect;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE OnDisconnect( Local : BOOLEAN; Error : CARDINAL );
   VAR
      Event : POINTER TO TEventData;
   BEGIN
      Logger.LogSC( dldDebug, logPrefix, L"Event.Add evDisconnect", CARDINAL( Error ));

      NEW( Event );
      Event^.Event := evDisconnect;
      Event^.NetError := Error;
      Event^.Local := Local;

      AddEvent( Event );
   END OnDisconnect;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE OnDataReceived( Length : CARDINAL );
   VAR
      Event : POINTER TO TEventData;
      l : CARDINAL;
   BEGIN
      RBufferLock.Lock();

      IF RBuffer.Length + Length > RBuffer.Size THEN
         Logger.LogSC( dldDebug, logPrefix, L"Event.Add evRxError", CARDINAL( erRxBufferFull ));

         NEW( Event );
         Event^.Event := evRxError;
         Event^.ASCIIError := erRxBufferFull;
         AddEvent( Event );
      END;
      Connection.Stream^.ReadBuffer( RBuffer.Size - RBuffer.Length, REF RBuffer, 0 ); // read only what is immediatelly possible
      l := RBuffer.Length;

      RBufferLock.Unlock();

      Logger.LogSC( dldDebug, logPrefix, L"Event.Add evDataReceived bytes ", Length );

      NEW( Event );
      Event^.Event := evDataReceived;
      Event^.Length := l;
      AddEvent( Event );

      Connection.BufferedStream^.StartReading(); // continue with advised reading
   END OnDataReceived;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE OnFlowPossible( Direction : IOO.TDirection );
   VAR
      Event : POINTER TO TEventData;
   BEGIN
      IF Direction = IOO.dirWrite THEN
         Logger.LogS( dldDebug, logPrefix, L"Event.Add evTxError OK -- tx allowed" );

         NEW( Event );
         Event^.Event := evTxError;
         Event^.ASCIIError := erOK;
         AddEvent( Event );
      END;
   END OnFlowPossible;

(*--------------------------------------------------------------------------------*)

BEGIN
   R.LoadRES2( EMITW( %dll ), L'RemoteASCIIDrv.Texts' );
   R.Lang := Languages.GetDefaultLanguage( Languages.dlUser );
   RStatus := TRStatus{rsValid};
   RunMode := drv_def.drmEdit;
   CallbackId := NIL;
   CallbackProc := NIL;
   
   Connection.CallbackMode := IOO.cbmPooled;
   Connection.Notifier := ADR( Notifier );
   Connection.BufferedStream^.BufferSize := 16384;

   Notifier.Driver := ADR( SELF );

   Events.Produce := Sync.CreateSignal( Sync.stEventAutoreset, L"", TRUE );
   LastError := erOK;

   Delimiter := L" ";
   WBuffer.Size := 16384;
   WIndex := 0;
   RBuffer.Size := 16384;
   RIndex := 0;
FINALLY
   Sync.DeleteSignal( REF Events.Produce );
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
   R.LoadRES2( EMITW( %dll ), L'RemoteASCIIDrv.Texts' );
   R.Lang := Languages.GetDefaultLanguage( Languages.dlUser );
END CFactory;

(*--------------------------------------------------------------------------------*)

VAR
   Factory : CFactory;

(*--------------------------------------------------------------------------------*)

BEGIN
   diface.RegisterFactory( ADR( Factory ));
END RemoteASCIIDrv.
