IMPLEMENTATION MODULE eibsrv;

(*# call( o_a_copy => off ) *)

//================================================================================
(*/* changes:

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

IMPORT
   winsock,
   windows;

IMPORT
   FIO,
   FIOO,
   IOO,
   Log,
   Storage,
   Strings,
   StringsO,
   Sync,
   Time;

IMPORT
   cllv,
   drv_str,
   INIFile,
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

//================================================================================

CONST
   tiInitReadDelay = 67;
   
//-----

TYPE
   TPBehaviour = POINTER TO CBehaviour;

CLASS CBehaviour( list.CListElem );
   Class : eib_def.TPriority;
   Flags : eib_def.TA_ObjectFlags;
   Name  : ARRAY [0..63] OF WCHAR;
END CBehaviour;

//-----

TYPE
   TPPromiscuousData = POINTER TO PromiscuousData;

CLASS PromiscuousData;
   Address : eib_def.CAddress;
   Value   : eib_def.CValue;
END PromiscuousData;

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

//-----

TYPE
   TsdapCommand = (
      sdapLOAD,
      sdapSET,
      sdapGET,
      sdapRUN,
      sdapSTOP,
      sdapLOCK,
      sdapUNLOCK
   );

   TsdapSubcommand = (
      sdapName,
      sdapGlobal,
      sdapDevice
   );
   
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
   Name[0] := 0W;
END CBehaviour;

//================================================================================

CLASS IMPLEMENTATION CObject;

//--------------------------------------------------------------------------------

   INTERNAL VIRTUAL PROCEDURE ValueReadRequestSent( Status : eib_status.TEIBStackStatus );
   BEGIN
      RSStatus := Status;
      Server^.ValueReadRequestSent( ADR( SELF ));
   END ValueReadRequestSent;

//--------------------------------------------------------------------------------

   INTERNAL VIRTUAL PROCEDURE ValueRead( Status : eib_status.TEIBStackStatus; Changed : BOOLEAN );
   BEGIN
      RSStatus := Status;
      Server^.ValueRead( ADR( SELF ));
   END ValueRead;

//--------------------------------------------------------------------------------

   INTERNAL VIRTUAL PROCEDURE ValueUpdated( Status : eib_status.TEIBStackStatus; Changed : BOOLEAN );
   BEGIN
      RSStatus := Status;
      Server^.ValueUpdated( ADR( SELF ));
   END ValueUpdated;

//--------------------------------------------------------------------------------

   INTERNAL VIRTUAL PROCEDURE ValueWritten( Status : eib_status.TEIBStackStatus );
   BEGIN
      WSStatus := Status;
      Server^.ValueWritten( ADR( SELF ));
      IF ( Status = eib_status.essOK ) AND ( eib_def.TA_ObjectFlags{eib_def.aofForceRead, eib_def.aofWritable} * GetFlags() = eib_def.TA_ObjectFlags{eib_def.aofWritable} ) THEN
         // element always read from EIB cannot be reset for reading;
         // only writable elements can be reset for reading too
         RSStatus := eib_status.essOK;
      END;
   END ValueWritten;

//--------------------------------------------------------------------------------

   LOCAL PROCEDURE LogNumber() : CARDINAL;
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
   RSStatus := eib_status.essOK;
   WSStatus := eib_status.essOK;
   ReadRepeatCount := 1;
   RecoveryExpiration := 0;
END CObject;

//================================================================================

CLASS IMPLEMENTATION PromiscuousData;
END PromiscuousData;

//================================================================================

CLASS IMPLEMENTATION CStackSink;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE OnDeviceConnected();
   BEGIN
      Server^.Connected();
   END OnDeviceConnected;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE OnDeviceDisconnected();
   BEGIN
      Server^.Disconnected();
   END OnDeviceDisconnected;

//--------------------------------------------------------------------------------

BEGIN
   Server := NIL;
END CStackSink;

//================================================================================

CLASS IMPLEMENTATION CSDAPServer;

//--------------------------------------------------------------------------------

  LOCAL PROCEDURE Start();
  BEGIN
    netsrv.StartListen( netsocket.stStream, 6007, NIL, Listener, 0, NIL );
  END Start;

//--------------------------------------------------------------------------------

  LOCAL PROCEDURE Stop();
  BEGIN
    netsrv.StopListenPort( netsocket.stStream, 6007 );
    // kill all connections
  END Stop;

//--------------------------------------------------------------------------------

  INTERNAL VIRTUAL PROCEDURE OnConnect( PConnection : netconndispatch.TConnectionHandle; Local : BOOLEAN; Error : CARDINAL );
  BEGIN
  END OnConnect;

//--------------------------------------------------------------------------------

  INTERNAL VIRTUAL PROCEDURE OnDisconnect( PConnection : netconndispatch.TConnectionHandle; Local : BOOLEAN; Error : CARDINAL );
  BEGIN
  END OnDisconnect;

//--------------------------------------------------------------------------------

   INTERNAL VIRTUAL PROCEDURE OnReceive( PConnection : netconndispatch.TConnectionHandle; PData : ADDRESS; DataLen : CARDINAL );
   VAR
      Command : TsdapCommand;
      d : StringsO.CString; // data
      eadr : eib_def.CAddress;
      EV : eib_def.TValue;
      i : CARDINAL;
      IOValue : sdvalue.Value;
      l : CARDINAL;
      p : ARRAY [0..3] OF StringsO.CString; // parameters
      parametersCount : CARDINAL;
      parametersFound : CARDINAL;
      PObject : TPObject;
      s : ARRAY [0..1] OF StringsO.CString; // sub parameters
      Subcommand : TsdapSubcommand;
      b : BOOLEAN;
   BEGIN
      d.FromOA( OA( DataLen>>1-1, PWCHAR( PData )));
      IF d.EndsWithOA( 13W + 10W ) THEN
         d.Length := d.Length - 2;
      END;

      // TODO
      Log.logger()^.LogSS( Log.dlpIO, L"sdap", "RCV: ", OA( d.Length-1, d.rawData ));

      d.SplitS( StringsO.WCHARS{L' '}, 0, TRUE, OUT parametersFound, OUT p );
      p[0].Lowerize();
      IF p[0].Empty THEN
         ACK( PConnection, sdap400 );
         RETURN;
      END;

      // split command and subcommand
      parametersCount := 2;
      p[0].SplitS( StringsO.WCHARS{L'.'}, 0, FALSE, OUT l, OUT s );
      IF s[0].EqualsOA( L"load" ) THEN
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
      ELSIF s[0].EqualsOA( L"lock" ) THEN
         Command := sdapLOCK;
      ELSIF s[0].EqualsOA( L"unlock" ) THEN
         Command := sdapUNLOCK;
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
      | sdapRUN :
       //-----
      | sdapSTOP :
       //-----
      ELSE
         ACK( PConnection, sdap502 ); // not supported
         RETURN;
      END; // CASE
      // presence of parameter
      FOR i := 0 TO parametersCount-1 DO
         IF p[i].Empty THEN
            ACKs( PConnection, sdap403, i );
            RETURN;
         END;
      END;

      // IF Result.Counted THEN
      // ELSIF Result.Expired THEN

      CASE Command OF
      //-----
      | sdapLOAD :
         // recode parameters
         d.Substring( p[0].Length + 1, -1, OUT p[1] );

         // stop, load
         b := Server^.Running;
         Server^.Stop( TRUE, FALSE );
         Server^.Dispose();
         Server^.Init( L"EibSrv", NIL, NIL );
         IF NOT Server^.ReadParameters( p[1], OUT p[0], OUT l ) THEN
            p[1].FromINT32( l, 10 );
            p[0].PrependOA( L" " );
            p[0].Prepend( p[1] );
            ACKS( PConnection, sdap406, p[0] );
         ELSIF b THEN
            Server^.Run( TRUE, FALSE );
            IF Server^.Running THEN
               ACK( PConnection, sdap200 );
            ELSE
               ACK( PConnection, sdap501 );
            END;
         ELSE
            ACK( PConnection, sdap200 );
         END;

      //-----
      | sdapRUN :
         Server^.Run( TRUE, FALSE );
         IF Server^.Running THEN
            ACK( PConnection, sdap200 );
         ELSE
            ACK( PConnection, sdap501 );
         END;

      //-----
      | sdapSTOP :
         Server^.Stop( TRUE, FALSE );
         ACK( PConnection, sdap200 );

       //-----
      | sdapSET, sdapGET :
         IF FALSE AND NOT Server^.Running THEN // TODO
            ACK( PConnection, sdap501 );

         ELSIF NOT eadr.SetGroupAddress3( OA( p[1].Length-1, p[1].rawData )) THEN
            ACKs( PConnection, sdap404, 1 );

         ELSIF Server^.Groups[ CARD16( eadr.GetGroupAddress1()) ] = 0FFFFH THEN
            ACKs( PConnection, sdap404, 1 );

         ELSE
            PObject := Server^.Objects[ INTEGER( Server^.Groups[ CARD16( eadr.GetGroupAddress1()) ] ) ];
            IF Command = sdapSET THEN // expect data.name (aka data.x/x/x)
               IOValue.String := p[2];
               Server^.IOValue2EIBValue( IOValue, PObject^.Type, OUT EV );
               PObject^.SetValue( EV );
               ACK( PConnection, sdap200 );

               // TODO
               Server^.ValueUpdated( PObject ); // notify CWDriver OOBQueue, if we are in such environment
       
            ELSE // expect data.name (aka data.x/x/x)
        
               PObject^.GetValue( EV, TRUE, FALSE );
               Server^.EIBValue2IOValue( EV, OUT IOValue );
               ACKd( PConnection, sdap200, p[1], IOValue );
       
            END;

         END;
      END; // CASE
  END OnReceive;

//--------------------------------------------------------------------------------

   PRIVATE PROCEDURE ACK( PConnection : netconndispatch.TConnectionHandle; ack : TsdapACK );
   VAR
      s : StringsO.CString;
   BEGIN
      s.FromCARD32( CARDINAL( ack ), 10 );
      
      // TODO
      Log.logger()^.LogSS( Log.dlpIO, L"sdap", "ACK: ", OA( s.Length-1, s.rawData ));
      
      Send( NIL, PConnection, 0, s.rawData, s.Length<<1 );
   END ACK;

//--------------------------------------------------------------------------------

   PRIVATE PROCEDURE ACKs( PConnection : netconndispatch.TConnectionHandle; ack : TsdapACK; subCode : CARDINAL );
   VAR
      s : StringsO.CString;
   BEGIN
      s.FromCARD32( CARDINAL( ack ), 10 );

      // TODO
      Log.logger()^.LogSS( Log.dlpIO, L"sdap", "ACK: ", OA( s.Length-1, s.rawData ));
      
      Send( NIL, PConnection, 0, s.rawData, s.Length<<1 );
   END ACKs;

//--------------------------------------------------------------------------------

   PRIVATE PROCEDURE ACKS( PConnection : netconndispatch.TConnectionHandle; ack : TsdapACK; CONST S : StringsO.CString );
   VAR
      s : StringsO.CString;
   BEGIN
      s.FromCARD32( CARDINAL( ack ), 10 );
      s.AppendOA( L" " );
      s.Append( S );

      // TODO
      Log.logger()^.LogSS( Log.dlpIO, L"sdap", "ACK: ", OA( s.Length-1, s.rawData ));
      
      Send( NIL, PConnection, 0, s.rawData, s.Length<<1 );
   END ACKS;

//--------------------------------------------------------------------------------

   PRIVATE PROCEDURE ACKd( PConnection : netconndispatch.TConnectionHandle; ack : TsdapACK; CONST address : StringsO.CString; CONST value : sdvalue.Value );
   VAR
      s : StringsO.CString;
   BEGIN
      s.FromCARD32( CARDINAL( ack ), 10 );
      s.AppendOA( ' 1' );

      // TODO
      Log.logger()^.LogSS( Log.dlpIO, L"sdap", "ACK: ", OA( s.Length-1, s.rawData ));
      
      Send( NIL, PConnection, 0, s.rawData, s.Length<<1 );

      s := address; s.AppendOA( L" " ); s.Append( value.String );

      // TODO
      Log.logger()^.LogSS( Log.dlpIO, L"sdap", "DATA: ", OA( s.Length-1, s.rawData ));
      
      Send( NIL, PConnection, 0, s.rawData, s.Length<<1 );
   END ACKd;

//--------------------------------------------------------------------------------

BEGIN
   Connection := netconndispatch.ctLine;
   PieceSize := -1;
END CSDAPServer;

//================================================================================

CLASS IMPLEMENTATION CEIBServer;

//--------------------------------------------------------------------------------

   PUBLIC PROPERTY Running GET : BOOLEAN;
   BEGIN
      RETURN ( rsRunning IN RStatus ) AND ( EIB <> NIL ) AND EIB^.DeviceConnected();
   END Running;

//--------------------------------------------------------------------------------

   INTERNAL VIRTUAL PROCEDURE OnTimer( TimerId : PTR );
   BEGIN
      IF TimerId = tiInitReadDelay THEN
         DoInitRead( TRUE );
      END;
   END OnTimer;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE Init( CONST SymbolicName : ARRAY OF WCHAR; _CallbackId : ADDRESS; PCallback : drv_def.TDriverCallbackW ) : BOOLEAN;
   BEGIN
      SUPER.Init();
      CallbackId := _CallbackId;
      CallbackProc := PCallback;
      SDAP.Init();
      RETURN TRUE;
   END Init;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE ReadParameters( CONST ParFilePath : StringsO.CString; OUT ErrorMessage : StringsO.CString; OUT ErrorLine : CARDINAL ) : BOOLEAN;
   LABEL
      Fail;
   CONST
      // .PAR section names 
      snDevice               = L'device';
      snInterface            = L'interface';
      snReadStart            = L'read_on_start';
      snReadRun              = L'read_during_run';
      snBehaviours           = L'behaviours';
      snObjects              = L'objects';
      snBlocks               = L'blocks';
      // .PAR key names
      knId                   = L'id';
         kvFalcon            = L'falcon';
         kvEIBNet            = L'eibnet';
      knKey                  = L'key';
      knMode                 = L'mode';
      knStatusChannel        = L'status_channel';
      knIQChannel            = L'input_queue_length_channel';
      knOQChannel            = L'output_queue_length_channel';
      knWQChannel            = L'write_queue_length_channel';
      knInputQueueLength     = L'input_queue_length';
      knOutputQueueLength    = L'output_queue_length';
      knWriteQueueLength     = L'write_queue_length';
      knAddress              = L'address';
      knACKTimeout           = L'ACK_timeout';
      knBUSYDelay            = L'BUSY_delay';
      knACKMethod            = L'ACK_method';
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
         kvReadable          = L'readable';
         kvWritable          = L'writable';
         kvTransmit          = L'transmit';
         kvUpdate            = L'updateable';
         kvForceRead         = L'communicate_on_read';
         kvCallback          = L'callback_on_write';
         kvInitRead          = L'read_on_start';
         kvPHigh             = L'high';
         kvPAlarm            = L'alarm';
      knObject               = L'object';
      knObjects              ::= snObjects;
      knESFStrict            = L'esf_strict';
      knESFIgnore            = L'esf_ignore';
      knESFAdapt             = L'esf_adapt';
      knBlock                = L'block';
      knType                 = L'type';

   //----------

      PROCEDURE AppendErrorId( REF ErrorMessage : StringsO.CString; ErrorId : ARRAY OF WCHAR );
      BEGIN
         ErrorMessage.AppendOA( L" (" );
         ErrorMessage.AppendOA( ErrorId );
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

      PROCEDURE StringToEIT( REF ErrorMessage : StringsO.CString; String : ARRAY OF WCHAR; VAR EIT : eib_def.TEIBType ) : BOOLEAN;
      BEGIN
         IF String[0] = WCHAR( 0 ) THEN
            ErrorMessage.FromOA( OAsz( R[ Texts._MissingType ] ));
            RETURN FALSE;
         ELSIF eib_def.StringToType( String, EIT ) THEN
            RETURN TRUE;
         ELSE
            ErrorMessage.FromOA( OAsz( R[ Texts._UnknownType ] ));
            AppendErrorId( REF ErrorMessage, String );
            RETURN FALSE;
         END;
      END StringToEIT;

   //----------

      PROCEDURE StringToSingleObject( REF ErrorMessage : StringsO.CString; String : ARRAY OF WCHAR; StartFromItem : CARDINAL; Priority : eib_def.TPriority; BFlags : eib_def.TA_ObjectFlags; EIT : eib_def.TEIBType ) : BOOLEAN;
      LABEL
         NextItem;
      VAR
         i : CARDINAL;
         l : CARDINAL;
         LAddress : eib_def.TAddress;
         p : ARRAY [0..31] OF WCHAR;
         PObject : TPObject;
         ReadAddressFound : BOOLEAN;
         FirstAddress : BOOLEAN;
         b : BOOLEAN;
      BEGIN
         ReadAddressFound := FALSE;
         FirstAddress := TRUE;
         i := StartFromItem;
         LOOP
            Strings.ItemSW( String, Strings.WCHARS{L' ', L','}, 0, i, TRUE, OUT p );
            IF i = StartFromItem THEN
               IF p[0] = 0W THEN
                  ErrorMessage.FromOA( OAsz( R[ Texts._MissingAddress ] ));
                  RETURN FALSE;
               ELSE // OK, add object
                  PObject := AddObject( Priority, BFlags, EIT );
               END;
            ELSIF p[0] = 0W THEN
               EXIT;
            END;

            IF ( p[0] = L"'" ) OR ( p[0] = L'"' ) THEN // comment
               Strings.RemoveW( REF p, 0, 1 );
               l := LENGTH( p );
               IF l > 1 THEN
                  IF ( p[l-1] = L"'" ) OR ( p[l-1] = L'"' ) THEN
                     p[l-1] := 0W;
                  END;
                  PObject^.Comment.FromOA( p );
               END;
               GOTO NextItem;
            ELSIF p[0] = L'[' THEN // name
               Strings.RemoveW( REF p, 0, 1 );
               l := LENGTH( p );
               IF l > 1 THEN
                  IF p[l-1] = L']' THEN
                     p[l-1] := 0W;
                  END;
                  PObject^.Name.FromOA( p );
               END;
               GOTO NextItem;
            END;

            IF NOT ReadAddressFound AND (( p[0] = L'r' ) OR ( p[0] = L'R' )) THEN
               Strings.RemoveW( REF p, 0, 1 );
               b := TRUE;
            ELSE
               b := FALSE;
            END;
            IF NOT LAddress.SetGroupAddress3( p ) THEN
               ErrorMessage.FromOA( OAsz( R[ Texts._BadGroupAddress ] ));
               AppendErrorId( REF ErrorMessage, p );
               RETURN FALSE;
            END;
            PObject^.AddAddress( FALSE, FALSE, LAddress );
            IF FirstAddress THEN
               Groups[ CARD16( LAddress.GetGroupAddress1()) ] := CARD16( Objects.Count - 1 );
            END;
            IF NOT ReadAddressFound AND b THEN
               ReadAddressFound := TRUE;
               PObject^.ReadAddress := LAddress;
            END;

         NextItem:
            INC( i );
            FirstAddress := FALSE;
         END; // LOOP
         RETURN TRUE;
      END StringToSingleObject;

   //----------

      PROCEDURE StringToMultipleObjects( REF ErrorMessage : StringsO.CString; String : ARRAY OF WCHAR; StartFromItem : CARDINAL; Priority : eib_def.TPriority; BFlags : eib_def.TA_ObjectFlags; EIT : eib_def.TEIBType ) : BOOLEAN;
      LABEL
         NextItem;
      VAR
         c : CARDINAL;
         Comment : ARRAY [0..511] OF WCHAR;
         f, l : CARDINAL;
         i, j : CARDINAL;
         LAddress : eib_def.TAddress;
         Name : ARRAY [0..63] OF WCHAR;
         NameNumber : ARRAY [0..63] OF WCHAR;
         Number : ARRAY [0..31] OF WCHAR;
         p0, p1, p2 : ARRAY [0..31] OF WCHAR;
         PObject : TPObject;
      BEGIN
         Comment[0] := 0W;
         Name[0] := 0W;
         
         i := StartFromItem;
         LOOP
            Strings.ItemSW( String, Strings.WCHARS{L' ', L','}, 0, i, TRUE, OUT p0 );
            IF p0[0] = 0W THEN
               IF i = StartFromItem THEN
                  ErrorMessage.FromOA( OAsz( R[ Texts._MissingAddress ] ));
                  RETURN FALSE;
               ELSE // OK, add object
                  EXIT;
               END;
            END;
            
            IF ( p0[0] = L"'" ) OR ( p0[0] = L'"' ) THEN // comment
               Strings.RemoveW( REF p0, 0, 1 );
               l := LENGTH( p0 );
               IF l > 1 THEN
                  IF ( p0[l-1] = L"'" ) OR ( p0[l-1] = L'"' ) THEN
                     p0[l-1] := 0W;
                  END;
                  ASSIGN( Comment, p0 );
               END;
               GOTO NextItem;
            ELSIF p0[0] = L'[' THEN // name
               Strings.RemoveW( REF p0, 0, 1 );
               l := LENGTH( p0 );
               IF l > 1 THEN
                  IF p0[l-1] = L']' THEN
                     p0[l-1] := 0W;
                  END;
                  ASSIGN( Name, p0 );
               END;
            END;

            c := Strings.IndexOfW( p0, L'..', 0 );
            IF c = MAX( CARDINAL ) THEN
               IF NOT LAddress.SetGroupAddress3( p0 ) THEN
                  ErrorMessage.FromOA( OAsz( R[ Texts._BadGroupAddress ] ));
                  AppendErrorId( REF ErrorMessage, p0 );
                  RETURN FALSE;
               END;
               f := CARDINAL( LAddress.GetGroupAddress1());
               l := f;
            ELSE
               Strings.SubstringW( p0, c + 2, MAX( CARDINAL ), OUT p2 );
               ASSIGN( p1, p0 );
               p1[c] := 0W;
               IF NOT LAddress.SetGroupAddress3( p1 ) THEN
                  ErrorMessage.FromOA( OAsz( R[ Texts._BadGroupAddress ] ));
                  AppendErrorId( REF ErrorMessage, p1 );
                  RETURN FALSE;
               END;
               f := CARDINAL( LAddress.GetGroupAddress1());
               IF NOT LAddress.SetGroupAddress3( p2 ) THEN
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
               PObject := AddObject( Priority, BFlags, EIT );
               LAddress.SetGroupAddress1( c );
               PObject^.AddAddress( FALSE, FALSE, LAddress );
               IF Name[0] <> 0W THEN
                  Strings.FromCARD32W( j, 10, OUT Number );
                  Strings.PadLeftW( REF Number, 4, L'0' );
                  Strings.ConcatW( OUT NameNumber, Name, Number );
                  PObject^.Name.FromOA( NameNumber );
                  INC( j );
               END;
               IF Comment[0] <> 0W THEN
                  PObject^.Comment.FromOA( Comment );
               END;
               Groups[ CARD16( c ) ] := CARD16( Objects.Count - 1 );
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

      PROCEDURE ReadESF( REF ErrorMessage : StringsO.CString; CONST ESFPath : StringsO.CString ) : BOOLEAN;
      CONST
         kvEIS = L"EIS";
         kvESFLow = L"Low";
         kvESFHigh = L"High";
         kvESFAlarm = L"Alarm";
         kvUncertain = L"Uncertain";
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
            FIO.PathHeadW( OA( ParFilePath.Length-1, ParFilePath.rawData ), OUT Path );
            FIO.PathAddW( REF Path, OA( ESFPath.Length-1, ESFPath.rawData ));
            fs.FromPath( Path, FIOO.imOpenRead );
         CATCH e : IOO.CIOException DO
            ErrorMessage.FromOA( OAsz( R[ Texts._CannotOpenESF ] ));
            AppendErrorId( REF ErrorMessage, OA( ESFPath.Length-1, ESFPath.rawData ));
            RETURN FALSE;
         END; // try
         tr.Stream := ADR( fs );
         tr.ReadLine( OUT so, Sync.INFINITE_TIME, TRUE ); // read first line comment
         WHILE tr.ReadLine( OUT so, Sync.INFINITE_TIME, TRUE ) = Sync.arCompleted DO
            IF so.Empty THEN
               CONTINUE;
            END;

            // group address
            i := so.ItemS( StringsO.WCHARS{ 9W }, 0, 0, FALSE, OUT item );
            IF item.Empty THEN
               ErrorMessage.FromOA( OAsz( R[ Texts._ESFMissingGroupField1 ] ));
               AppendErrorLine( REF ErrorMessage, tr.Line );
               RETURN FALSE;
            ELSE
               c := Strings.LastIndexOfCharW( OA( item.Length-1, item.rawData ), L'.', 0 );
               IF c <> -1 THEN
                  item.Remove( 0, c+1 );
               END;
               item.Trim();
               IF NOT GroupAddress.SetGroupAddress3( OA( item.Length-1, item.rawData )) THEN
                  ErrorMessage.FromOA( OAsz( R[ Texts._BadGroupAddress ] ));
                  AppendErrorLine( REF ErrorMessage, tr.Line );
                  RETURN FALSE;
               END;
            END;
            
            // skip name, read type
            i := so.ItemS( StringsO.WCHARS{ 9W }, i, 1, FALSE, OUT item );
            c := item.ItemS( StringsO.WCHARS{ L' ' }, 0, 0, FALSE, OUT io );
            IF io.Empty THEN
               ErrorMessage.FromOA( OAsz( R[ Texts._ESFMissingTypeField3 ] ));
               AppendErrorLine( REF ErrorMessage, tr.Line );
               RETURN FALSE;

            ELSIF io.EqualsOA( kvEIS ) THEN
               c := item.ItemS( StringsO.WCHARS{ L' ' }, c, 0, FALSE, OUT io );
               TRY
                  c := io.ToCARD32( 10 );
               CATCH e : StringsO.CStringException DO
                  ErrorMessage.FromOA( OAsz( R[ Texts._BadTypeInfo ] ));
                  AppendErrorLine( REF ErrorMessage, tr.Line );
                  RETURN FALSE;
               END;
               IF NOT eib_def.NumberToType( c, EIT ) THEN
                  ErrorMessage.FromOA( OAsz( R[ Texts._BadTypeInfo ] ));
                  AppendErrorLine( REF ErrorMessage, tr.Line );
                  RETURN FALSE;
               END;

            ELSIF io.EqualsOA( kvUncertain ) THEN
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
            i := so.ItemS( StringsO.WCHARS{ 9W }, i, 0, FALSE, OUT item );
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
            
            PObject := AddObject( Priority, fullIOFlags, EIT );
            PObject^.AddAddress( FALSE, FALSE, GroupAddress );
            
            // read optional adjacent group address;

         END; // WHILE

         fs.Close( FALSE );
         RETURN TRUE;
      END ReadESF;

   //----------

   VAR
      BFlags : eib_def.TA_ObjectFlags;
      Blocks : lists.CStringList;
      BName : ARRAY [0..63] OF WCHAR;
      c : CARDINAL;
      Connection, Key : ARRAY [0..255] OF WCHAR;
      EIT : eib_def.TEIBType;
      ErrorMessageOA : ARRAY [0..255] OF WCHAR;
      ES : PTR;
      i : CARDINAL;
      p : ARRAY [0..255] OF WCHAR;
      PBehaviour : TPBehaviour;
      Priority : eib_def.TPriority;
      s : ARRAY [0..4095] OF WCHAR;
      so : StringsO.CString;
      TS : INIFile.CINIFile;
      b : BOOLEAN;
   BEGIN
      ErrorLine := 0;
   
      TRY
         fs.FromPath( OA( ParFilePath.Length-1, ParFilePath.rawData ), FIOO.imOpenRead );
      CATCH e : IOO.CIOException DO
         ErrorMessage.FromOA( OAsz( R[ Texts._CannotOpenPar ] ));
         AppendErrorId( REF ErrorMessage, OA( ParFilePath.Length-1, ParFilePath.rawData ));
         GOTO Fail;
      END; // try
      tr.Stream := ADR( fs );
      b := TS.Load( tr );
      fs.Close( FALSE );
      IF NOT b THEN
         ErrorMessage.FromOA( OAsz( R[ Texts._CannotOpenPar ] ));
         AppendErrorId( REF ErrorMessage, OA( ParFilePath.Length-1, ParFilePath.rawData ));
         GOTO Fail;
      END;
      InitToDefault();

      // read device id
      DeviceId := -1;
      PromiscuousMode := FALSE;
      Connection := L'';
      Key := L'';
      StatusChannel := MAX( CARDINAL );
      InputQueueLengthChannel := MAX( CARDINAL );
      OutputQueueLengthChannel := MAX( CARDINAL );
      WriteQueueLengthChannel := MAX( CARDINAL );
      IF TS.SetSection( snDevice ) THEN
         IF TS.GetKeyInt( knId, OUT ErrorLine, OUT c ) THEN
            DeviceId := c;
         ELSIF TS.GetKeyStr( knId, OUT ErrorLine, OUT so ) THEN
            IF so.StartsWithOA( kvFalcon ) THEN
               c := so.IndexOfOA( kvFalcon, 0 );
               IF c <> MAX( CARDINAL ) THEN
                  so.SubstringOA( c+LENGTH( kvFalcon )+1, MAX( CARDINAL ), OUT Connection );
                  Strings.TrimW( REF Connection );
                  DeviceId := LONGWORD( -2 );
               END;
            ELSIF so.StartsWithOA( kvEIBNet ) THEN
               c := so.IndexOfOA( kvEIBNet, 0 );
               IF c <> MAX( CARDINAL ) THEN
                  so.SubstringOA( c+LENGTH( kvEIBNet )+1, MAX( CARDINAL ), OUT Connection );
                  Strings.TrimW( REF Connection );
                  DeviceId := LONGWORD( -3 );
               END;
            END;
         END;
         IF TS.GetKeyStr( knKey, OUT ErrorLine, OUT so ) THEN
            so.ToOA( OUT Key );
         END;
         IF TS.GetKeyInt( knStatusChannel, OUT ErrorLine, OUT c ) THEN
            StatusChannel := c;
         END;
         IF TS.GetKeyInt( knIQChannel, OUT ErrorLine, OUT c ) THEN
            InputQueueLengthChannel := c;
         END;
         IF TS.GetKeyInt( knOQChannel, OUT ErrorLine, OUT c ) THEN
            OutputQueueLengthChannel := c;
         END;
         IF TS.GetKeyInt( knWQChannel, OUT ErrorLine, OUT c ) THEN
            WriteQueueLengthChannel := c;
         END;
      END; // IF snDevice
      IF DeviceId = LONGWORD( -1 ) THEN
         ErrorMessage.FromOA( OAsz( R[ Texts._BadOrUndefinedDeviceId ] ));
         GOTO Fail;
      ELSIF DeviceId = LONGWORD( -2 ) THEN
         // Stack := stackFalcon;
         // NEW( falconStack.TPFalconStack( EIB ));
         // ASSIGN( falconStack.TPFalconStack( EIB )^.Connection, FalconConnection );
         // ASSIGN( falconStack.TPFalconStack( EIB )^.Key, Key );
         ErrorMessage.FromOA( OAsz( R[ Texts._UnsupportedStack ] ));
      ELSIF DeviceId = LONGWORD( -3 ) THEN
         Stack := stackEIBNet;
         NEW( eibnetstack.TPEIBNetStack( EIB ));
      ELSE
         // Stack := stackUSB;
         // NEW( eibusb.TPTPUARTStack( EIB ));
         ErrorMessage.FromOA( OAsz( R[ Texts._UnsupportedStack ] ));
         GOTO Fail;
      END;

      EIB^.Init( FALSE, eib_stack.eltUndefined, eib_stack.eltUndefined, ADR( Sink ));

      IF NOT EIB^.SetParameter( L"link.connection", Connection, OUT s ) THEN
         ErrorMessage.FromOA( OAsz( R[ Texts._BadConnection ] ));
         ErrorMessage.AppendOA( L": " );
         ErrorMessage.AppendOA( s );
         GOTO Fail;
      END;
      // still inside snDevice
      IF TS.GetKeyStr( knMode, OUT ErrorLine, OUT so ) THEN
         EIB^.SetParameter( L"link.mode", OA( so.Length-1, so.rawData ), OUT ErrorMessageOA ); // TODO error message
      END;

      // read interface options
      IF TS.SetSection( snInterface ) THEN
      
         // TO DO error messages

         IF TS.GetKeyInt( knInputQueueLength, OUT ErrorLine, OUT c ) THEN
            InputQueueLength := c;
         END;
         IF TS.GetKeyStr( knOutputQueueLength, OUT ErrorLine, OUT so ) THEN
            EIB^.SetParameter( L"link.outputQueueLength", OA( so.Length-1, so.rawData ), OUT ErrorMessageOA ); // TODO error message
         END;
         IF TS.GetKeyStr( knWriteQueueLength, OUT ErrorLine, OUT so ) THEN
            EIB^.SetParameter( L"application.pendingQueueLength.write", OA( so.Length-1, so.rawData ), OUT ErrorMessageOA ); // TODO error message
         END;
         IF TS.GetKeyStr( knAddress, OUT ErrorLine, OUT so ) THEN
            so.ToOA( OUT s );
            IF NOT Address.SetPhysicalAddress3( s ) THEN
               ErrorMessage.AppendOA( OAsz( R[ Texts._BadPhysicalAddress ] ));
               AppendErrorId( REF ErrorMessage, s );
               GOTO Fail;
            END;
         END;
         IF TS.GetKeyInt( knACKTimeout, OUT ErrorLine, OUT c ) THEN
            ACKTimeout := c;
         END;
         IF TS.GetKeyStr( knACKMethod, OUT ErrorLine, OUT so ) THEN
            IF NOT EIB^.SetParameter( L"link.ackMethod", OA( so.Length-1, so.rawData ), OUT ErrorMessageOA ) THEN
               ErrorMessage.FromOA( ErrorMessageOA );
               AppendErrorId( REF ErrorMessage, OA( so.Length-1, so.rawData ));
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

      // read read on start options
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
         ES := 0;
         WHILE TS.EnumerateKeys( REF ES, OUT ErrorLine, OUT p, OUT so ) DO
            IF NOT EQUALS( p, knBehaviour ) THEN
               CONTINUE;
            END;

            Priority := eib_def.priorityNormal;
            so.ItemSOA( StringsO.WCHARS{L' ', L','}, 0, 0, TRUE, OUT p );
            IF p[0] = 0W THEN
               ErrorMessage.AppendOA( OAsz( R[ Texts._MissingBehaviourName ] ));
               GOTO Fail;
            ELSE
               BFlags := eib_def.TA_ObjectFlags{eib_def.aofCommunicated};
               ASSIGN( BName, p );
            END;

            i := 1;
            LOOP
               so.ItemSOA( StringsO.WCHARS{L' ', L','}, 0, i, TRUE, OUT p );
               IF p[0] = 0W THEN
                  EXIT;
               END;
               IF EQUALS( p, kvReadable ) THEN
                  INCL( BFlags, eib_def.aofReadable );
               ELSIF EQUALS( p, kvWritable ) THEN
                  INCL( BFlags, eib_def.aofWritable );
               ELSIF EQUALS( p, kvTransmit ) THEN
                  INCL( BFlags, eib_def.aofTransmit );
               ELSIF EQUALS( p, kvUpdate ) THEN
                  INCL( BFlags, eib_def.aofUpdate );
               ELSIF EQUALS( p, kvForceRead ) THEN
                  INCL( BFlags, eib_def.aofForceRead );
               ELSIF EQUALS( p, kvCallback ) THEN
                  INCL( BFlags, eib_def.aofAdvise );
               ELSIF EQUALS( p, kvInitRead ) THEN
                  INCL( BFlags, eib_def.aofInitRead );
               ELSIF EQUALS( p, kvPHigh ) THEN
                  Priority := eib_def.priorityHigh;
               ELSIF EQUALS( p, kvPAlarm ) THEN
                  Priority := eib_def.priorityAlarm;
               ELSE
                  ErrorMessage.AppendOA( OAsz( R[ Texts._BadBehaviourItemName ] ));
                  AppendErrorId( REF ErrorMessage, p );
                  GOTO Fail;
               END;
               INC( i );
            END; // LOOP

            NEW( PBehaviour );
            ASSIGN( PBehaviour^.Name, BName );
            PBehaviour^.Class := Priority;
            PBehaviour^.Flags := BFlags;
            Behaviours.Append( PBehaviour );
         END; // WHILE
      END; // IF snBehaviours

      // read objects
      DoneObjects( FALSE );
      INCL( RStatus, rsInitReadFinished );

      IF TS.SetSection( snObjects ) THEN
         ES := 0;
         WHILE TS.EnumerateKeys( REF ES, OUT ErrorLine, OUT p, OUT so ) DO
            //-----
            IF EQUALS( p, knObject ) OR EQUALS( p, knObjects ) THEN
               b := EQUALS( p, knObject );

               so.ItemSOA( StringsO.WCHARS{L' ', L','}, 0, 0, TRUE, OUT p );
               IF p[0] = 0W THEN
                  ErrorMessage.AppendOA( OAsz( R[ Texts._MissingBehaviourName ] ));
                  GOTO Fail;
               ELSIF NOT FindBehaviour( p, Priority, BFlags ) THEN
                  ErrorMessage.AppendOA( OAsz( R[ Texts._UnknownBehaviour ] ));
                  AppendErrorId( REF ErrorMessage, p );
                  GOTO Fail;
               ELSIF eib_def.aofInitRead IN BFlags THEN
                  EXCL( RStatus, rsInitReadFinished );
               END;
               so.ItemSOA( StringsO.WCHARS{L' ', L','}, 0, 1, TRUE, OUT p );
               IF NOT StringToEIT( REF ErrorMessage, p, EIT ) THEN
                  GOTO Fail;
               END;

               so.ToOA( OUT s );
               IF b THEN
                  IF NOT StringToSingleObject( REF ErrorMessage, s, 2, Priority, BFlags, EIT ) THEN
                     GOTO Fail;
                  END;
               ELSE
                  IF NOT StringToMultipleObjects( REF ErrorMessage, s, 2, Priority, BFlags, EIT ) THEN
                     GOTO Fail;
                  END;
               END;

            //-----
            ELSIF EQUALS( p, knESFStrict ) OR EQUALS( p, knESFIgnore ) OR EQUALS( p, knESFAdapt ) THEN
               IF NOT ReadESF( REF ErrorMessage, so ) THEN
                  GOTO Fail;
               END;

            END;
         END; // WHILE
      END; // IF snObjects

      // read blocks
      IF TS.SetSection( snBlocks ) THEN
         ES := 0;
         WHILE TS.EnumerateKeys( REF ES, OUT ErrorLine, OUT p, OUT so ) DO
            IF EQUALS( p, knBlock ) THEN
               Blocks.Enqueue( so, 0 );
            END;
         END;
      END; // IF snGroups
      WHILE Blocks.DequeueOA( OUT p, OUT c ) DO

         IF NOT TS.SetSection( p ) THEN
            ErrorMessage.AppendOA( OAsz( R[ Texts._RequestedBlockNotFound ] ));
            ErrorMessage.AppendOA( L' (' );
            ErrorMessage.AppendOA( p );
            ErrorMessage.AppendOA( L')' );
            GOTO Fail;
         END;

         IF NOT TS.GetKeyStr( knType, OUT ErrorLine, OUT so ) THEN
            ErrorMessage.AppendOA( OAsz( R[ Texts._BlockWithoutType ] ));
            AppendErrorId( REF ErrorMessage, p );
            GOTO Fail;
         END;
         so.ToOA( OUT s );
         IF NOT StringToEIT( REF ErrorMessage, s, EIT ) THEN
            GOTO Fail;
         END;

         IF NOT TS.GetKeyStr( knBehaviour, OUT ErrorLine, OUT so ) THEN
            ErrorMessage.AppendOA( OAsz( R[ Texts._BlockWithoutBehaviour ] ));
            AppendErrorId( REF ErrorMessage, p );
            GOTO Fail;
         END;
         so.ToOA( OUT s );
         IF NOT FindBehaviour( s, Priority, BFlags ) THEN
            ErrorMessage.AppendOA( OAsz( R[ Texts._UnknownBehaviour ] ));
            AppendErrorId( REF ErrorMessage, s );
            GOTO Fail;
         ELSIF eib_def.aofInitRead IN BFlags THEN
            EXCL( RStatus, rsInitReadFinished );
         END;

         // OBJECT =
         ES := 0;
         WHILE TS.EnumerateKeys( REF ES, OUT ErrorLine, OUT p, OUT so ) DO
            so.ToOA( OUT s );
            IF EQUALS( p, knObject ) AND NOT StringToSingleObject( REF ErrorMessage, s, 0, Priority, BFlags, EIT ) THEN
               GOTO Fail;
            END;
         END; // WHILE knObject        

         // OBJECTS =
         ES := 0;
         WHILE TS.EnumerateKeys( REF ES, OUT ErrorLine, OUT p, OUT so ) DO
            so.ToOA( OUT s );
            IF EQUALS( p, knObjects ) AND NOT StringToMultipleObjects( REF ErrorMessage, s, 0, Priority, BFlags, EIT ) THEN
               GOTO Fail;
            END;
         END; // WHILE knObject        

      END; // WHILE Blocks

      EIB^.SetStackAddress( Address );

      IF PromiscuousMode THEN
         EIB^.SetParameter( L"application.promiscuousMode", L"true", OUT ErrorMessageOA );
      ELSE
         EIB^.SetParameter( L"application.promiscuousMode", L"false", OUT ErrorMessageOA );
      END;
      ErrorMessage.FromOA( ErrorMessageOA ); // TODO error message
      IF PromiscuousMode THEN
         FOR EIT := eib_def.eitSwitch TO eib_def.eitString DO WITH prObjects[EIT] DO
            Server := ADR( SELF );
            Init( EIB, EIT, eib_user.obNone );
            SetClass( eib_def.priorityNormal );
            SetFlags( fullIOFlags );
            SubscribePromiscuous();
            INC( EIT );
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
      RETURN TRUE;

   Fail:
      Blocks.Dispose();
      RETURN FALSE;
   END ReadParameters;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE EnumerateChannels( VAR EnumerateState : LONGWORD; VAR Type : CARDINAL; VAR Direction : CARDINAL; VAR DriverIndex : CARDINAL; VAR Count : CARDINAL; VAR HaveDescription : BOOLEAN ): BOOLEAN;
   LABEL
      Described;
   CONST
      directionInput = eib_def.TA_ObjectFlags{eib_def.aofUpdate, eib_def.aofWritable, eib_def.aofInitRead, eib_def.aofAdvise};
      directionOutput = eib_def.TA_ObjectFlags{eib_def.aofTransmit, eib_def.aofReadable};
   VAR
      Index : CARDINAL;
      OCount : CARDINAL := Objects.Count;
      PObject : TPObject;
   BEGIN
      IF EnumerateState = LONGWORD( 0 ) THEN // start enumeration
         IF OCount = 0 THEN
            RETURN FALSE;
         ELSE
            Index := CARDINAL( EnumerateState );
         END;
      ELSE // continue enumeration
         Index := CARDINAL( EnumerateState );
         IF Index < OCount THEN
            // fall down
         ELSE
            Direction := CARDINAL( drv_def.dirInput );
            HaveDescription := TRUE;
            Type := CARDINAL( drv_def.vtLongCard );
            LOOP
               IF Index > OCount + 3 THEN
                  RETURN FALSE;
               ELSIF ( Index = OCount ) AND ( StatusChannel <> MAX( CARDINAL )) THEN
                  // enumerate status channel
                  DriverIndex := StatusChannel;
                  GOTO Described;
               ELSIF ( Index = OCount + 1 ) AND ( InputQueueLengthChannel <> MAX( CARDINAL )) THEN
                  // enumerate input_queue_length channel
                  DriverIndex := InputQueueLengthChannel;
                  GOTO Described;
               ELSIF ( Index = OCount + 2 ) AND ( OutputQueueLengthChannel <> MAX( CARDINAL )) THEN
                  // enumerate input_queue_length channel
                  DriverIndex := OutputQueueLengthChannel;
                  GOTO Described;
               ELSIF ( Index = OCount + 3 ) AND ( WriteQueueLengthChannel <> MAX( CARDINAL )) THEN
                  // enumerate input_queue_length channel
                  DriverIndex := WriteQueueLengthChannel;
                  GOTO Described;
               END;
               INC( Index );
            END; // LOOP
         END;
      END;

      PObject := TPObject( Objects[ Index ] );
      CASE PObject^.Value.GetType() OF
      | eib_def.eitSwitch :     Type := CARDINAL( drv_def.vtBoolean );
      | eib_def.eitIncrease :   Type := CARDINAL( drv_def.vtShortInt );
      | eib_def.eitTime :       Type := CARDINAL( drv_def.vtLongCard );
      | eib_def.eitDate :       Type := CARDINAL( drv_def.vtLongReal );
      | eib_def.eitValue,
        eib_def.eitValueRange : Type := CARDINAL( drv_def.vtLongReal );
      | eib_def.eitScaling,
        eib_def.eitScaling255 : Type := CARDINAL( drv_def.vtShortCard );
      | eib_def.eitMove :       Type := CARDINAL( drv_def.vtBoolean );
      | eib_def.eitFloat :      Type := CARDINAL( drv_def.vtLongReal );
      | eib_def.eit16bit :      Type := CARDINAL( drv_def.vtLongCard );
      | eib_def.eit32bit :      Type := CARDINAL( drv_def.vtLongCard );
      | eib_def.eitChar :       Type := CARDINAL( drv_def.vtDString );
      | eib_def.eit8bit :       Type := CARDINAL( drv_def.vtShortCard );
      | eib_def.eitString :     Type := CARDINAL( drv_def.vtDString);
      END; // CASE EV.Type

      IF directionOutput * PObject^.Flags = eib_def.TA_ObjectFlags{} THEN
         Direction := CARDINAL( drv_def.TDirection{drv_def.dirInput} );
      ELSIF directionInput * PObject^.Flags = eib_def.TA_ObjectFlags{} THEN
         Direction := CARDINAL( drv_def.TDirection{drv_def.dirOutput} );
      ELSE
         Direction := CARDINAL( drv_def.TDirection{drv_def.dirInput, drv_def.dirOutput} );
      END;

      DriverIndex := PObject^.LogNumber();
      HaveDescription := NOT PObject^.Name.Empty OR NOT PObject^.Comment.Empty;

   Described:
      Count := 1;

      INC( Index );
      EnumerateState := Index;
      RETURN TRUE;
   END EnumerateChannels;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE GetChannelDescription( DriverIndex : CARDINAL; VAR Description : ARRAY OF WCHAR; VAR Id : ARRAY OF WCHAR ) : BOOLEAN;
   CONST
      _StatusId            = L'drvStatus';
      _InputQueueLengthId  = L'drvInputQueueLength';
      _OutputQueueLengthId = L'drvOutputQueueLength';
      _WriteQueueLengthId  = L'drvWriteQueueLength';
   VAR
      PObject : TPObject;
   BEGIN
      IF DriverIndex = StatusChannel THEN
         ASSIGN( Description, OAsz( R[ Texts._StatusComment ] ));
         ASSIGN( Id, _StatusId );
      ELSIF DriverIndex = InputQueueLengthChannel THEN
         ASSIGN( Description, OAsz( R[ Texts._InputQueueLengthComment ] ));
         ASSIGN( Id, _InputQueueLengthId );
      ELSIF DriverIndex = OutputQueueLengthChannel THEN
         ASSIGN( Description, OAsz( R[ Texts._OutputQueueLengthComment ] ));
         ASSIGN( Id, _OutputQueueLengthId );
      ELSIF DriverIndex = WriteQueueLengthChannel THEN
         ASSIGN( Description, OAsz( R[ Texts._WriteQueueLengthComment ] ));
         ASSIGN( Id, _WriteQueueLengthId );
      ELSIF LogNumber2Object( DriverIndex, PObject ) THEN
         PObject^.Name.ToOA( OUT Id );
         PObject^.Comment.ToOA( OUT Description );
      ELSE
         RETURN FALSE;
      END;
      RETURN TRUE;
   END GetChannelDescription;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE Run( OperateEIB, OperateSDAP : BOOLEAN );
   VAR
      s : FIO.PathStrW;
   BEGIN
      IF rsRunning IN RStatus THEN
         RETURN;
      ELSE
         INCL( RStatus, rsRunning );
      END;
   
      Result.Reset( lec.bhBestCase );
      FIO.GetModuleDirW( EMITW( %dll ), OUT s );
      lec.QueryData( s, L"", ADR( cllv.data ), cllv.length, REF Result );

      IF OperateEIB AND ( EIB <> NIL ) THEN
         EXCL( RStatus, rsInitReadFinished );
         EIB^.Connect();
      END;

      IF OperateSDAP THEN      
         SDAP.Start();
      END;
   END Run;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE Connected();
   BEGIN
      IF CallbackProc <> NIL THEN
         CallbackProc( CallbackId, drv_def.dcfException, NIL );
      END;

      IF TRStatus{rsInitReadPending, rsInitReadFinished} * RStatus <> TRStatus{} THEN
         RETURN;
      END;
      RStatus := RStatus - TRStatus{rsInitReadRepeat, rsInitReadFinished} + TRStatus{rsInitReadPending};
      InitReadItems := 0;
      IF Objects.Count = 0 THEN
         InitReadFinished();
      ELSE
         DoInitRead( FALSE );
      END;
   END Connected;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE Disconnected();
   BEGIN
      IF CallbackProc <> NIL THEN
         CallbackProc( CallbackId, drv_def.dcfInputFinalized, NIL );
         CallbackProc( CallbackId, drv_def.dcfOutputFinalized, NIL );
         CallbackProc( CallbackId, drv_def.dcfException, NIL );
      END;
   END Disconnected;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE Stop( OperateEIB, OperateSDAP : BOOLEAN );
   BEGIN
      IF rsRunning IN RStatus THEN
         EXCL( RStatus, rsRunning );
      ELSE
         RETURN;
      END;

      IF OperateSDAP THEN
         SDAP.Stop();
      END;

      IF OperateEIB AND ( EIB <> NIL ) THEN
         EIB^.Disconnect();
      END;
   END Stop;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE Dispose();
   BEGIN
      DoneObjects( TRUE );
      Behaviours.Dispose();
      IF EIB <> NIL THEN
         EIB^.Done();
         DISPOSE( EIB );
      END;
      SUPER.Dispose();
   END Dispose;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE InputRequestStart();
   BEGIN
   END InputRequestStart;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE InputRequest( DriverIndex : CARDINAL );
   VAR
      EV : eib_def.TValue;
      PObject : TPObject;
   BEGIN
      Result.Inc();
      IF ( DriverIndex = StatusChannel ) OR
          ( DriverIndex = InputQueueLengthChannel ) OR
          ( DriverIndex = OutputQueueLengthChannel ) OR
          ( DriverIndex = WriteQueueLengthChannel ) THEN
         // pass down
      ELSIF NOT LogNumber2Object( DriverIndex, PObject ) THEN
         // pass down
      ELSIF eib_user.TObjectState{eib_user.osInitReadPending, eib_user.osReading} * PObject^.State <> eib_user.TObjectState{} THEN
         // pass down
      ELSIF eib_def.aofForceRead IN PObject^.GetFlags() THEN
         IF ( PObject^.RecoveryExpiration <> 0 ) AND ( INTEGER( PObject^.RecoveryExpiration - CARDINAL( windows.GetTickCount())) < 0 ) THEN
            // still cannot read, pass away
            RETURN;
         END;
         // start reading itself
         PObject^.ReadRepeatCount := ReadDuringRun.RepeatCount;
         PObject^.GetValue( EV, FALSE, FALSE );
      END;
   END InputRequest;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE InputRequestCompleted();
   BEGIN
   END InputRequestCompleted;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE InputFinalized( DriverIndex : CARDINAL; VAR ErrorCode : CARDINAL ) : BOOLEAN;
   VAR
      PObject : TPObject;
   BEGIN
      IF ( DriverIndex = StatusChannel ) OR
          ( DriverIndex = InputQueueLengthChannel ) OR
          ( DriverIndex = OutputQueueLengthChannel ) OR
          ( DriverIndex = WriteQueueLengthChannel ) THEN
         ErrorCode := drv_def.ecSuccess;
      ELSIF NOT LogNumber2Object( DriverIndex, PObject ) THEN
         ErrorCode := drv_def.ecUnknownElement;
      ELSIF NOT HWConnected( ErrorCode ) THEN
         PObject^.CancelIO();
      ELSIF eib_user.osReading IN PObject^.State THEN
         RETURN FALSE;
      ELSIF Result.Expired OR Result.Counted THEN
         RETURN FALSE;
      ELSIF PObject^.RSStatus = eib_status.essOK THEN
         ErrorCode := drv_def.ecSuccess;
      ELSE
         ErrorCode := EIBStatus2ErrorCode( PObject^.RSStatus );
      END;
      RETURN TRUE;
   END InputFinalized;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE InputOOBDataQuery( VAR EnumerateState : LONGWORD; VAR DriverIndex : CARDINAL ) : BOOLEAN;
   BEGIN
      IF CARDINAL( EnumerateState ) >= oobData.Count THEN
         EXCL( RStatus, rsProcessingOOB );
         oobData.Dispose();
         RETURN FALSE;
      ELSIF rsProcessingOOB NOT IN RStatus THEN
         INCL( RStatus, rsProcessingOOB );
         oobData.Reset();
      END;
      oobData.MoveNext();
      DriverIndex := TPObject( oobData.CurrentData )^.LogNumber();
      EnumerateState := CARDINAL( EnumerateState ) + 1;
      RETURN TRUE;
   END InputOOBDataQuery;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE GetInput( UFlag : BOOLEAN; DriverIndex : CARDINAL; VAR InValue : drv_def.TValue; VAR QoS : CARDINAL; VAR TimeStamp : drv_def.TUTCStamp; VAR ErrorCode : CARDINAL );
   VAR
      c : CARDINAL;
      Day : eib_def.TDay;
      EV : eib_def.TValue;
      PObject : TPObject;
      s : ARRAY [0..31] OF WCHAR;
      Status : TStatusChannel;
      Y, M, D, H, S : CARDINAL;
      wch : WCHAR;
      b1 : BOOLEAN;
      b2 : BOOLEAN;
   BEGIN
      IF DriverIndex = StatusChannel THEN
         QoS := drv_def.qosGood;
         ErrorCode := drv_def.ecSuccess;

         Status := TStatusChannel{};
         IF EIB^.DeviceConnected() THEN
            INCL( Status, schiUSBConnected );
         END;
         IF PromiscuousMode THEN
            IF prData.Count >= InputQueueLength THEN
               INCL( Status, schiInputQueueOverflow );
            END;
         ELSE
            IF oobData.Count >= InputQueueLength THEN
               INCL( Status, schiInputQueueOverflow );
            END;
         END;
         IF EIB^.EIBConnected() THEN
            INCL( Status, schiEIBConnected );
         END;
         IF NOT( rsInitReadFinished IN RStatus ) THEN
            INCL( Status, schiInitReadPending );
         END;
         IF rsPromiscuousInQueue IN RStatus THEN
            INCL( Status, schiHavePromiscuousData );
         END;

         drv_def.AssignValueCardinal( InValue, TRUE, CARDINAL( Status ));

      ELSIF DriverIndex = InputQueueLengthChannel THEN
         QoS := drv_def.qosGood;
         ErrorCode := drv_def.ecSuccess;
         drv_def.AssignValueCardinal( InValue, TRUE, CARDINAL( oobData.Count ));

      ELSIF DriverIndex = OutputQueueLengthChannel THEN
         QoS := drv_def.qosGood;
         ErrorCode := drv_def.ecSuccess;
         drv_def.AssignValueCardinal( InValue, TRUE, CARDINAL( EIB^.OutputQueueLength() ));

      ELSIF DriverIndex = WriteQueueLengthChannel THEN
         QoS := drv_def.qosGood;
         ErrorCode := drv_def.ecSuccess;
         drv_def.AssignValueCardinal( InValue, TRUE, CARDINAL( EIB^.WriteQueueLength() ));

      ELSIF NOT LogNumber2Object( DriverIndex, PObject ) THEN
         QoS := drv_def.qosBad;
         ErrorCode := drv_def.ecUnknownElement;

      ELSE
         ErrorCode := EIBStatus2ErrorCode( PObject^.RSStatus );
         IF ErrorCode <> drv_def.ecSuccess THEN
            QoS := drv_def.qosBad;
            RETURN;
         ELSIF eib_def.aofEIBValue IN PObject^.GetFlags() THEN
            QoS := drv_def.qosGood;
         ELSE
            QoS := drv_def.qosBad;
         END;

         PObject^.GetValue( EV, TRUE, FALSE );
         IF rsProcessingOOB IN RStatus THEN
            oobData.Current^.ToOA( OUT EV.Data, OUT c );
         END;

         CASE EV.GetType() OF
         | eib_def.eitUnknown :
            ErrorCode := drv_def.ecValueProcessing;
         | eib_def.eitSwitch :
            drv_def.AssignValueBoolean( InValue, TRUE, EV.GetSwitch() );
         | eib_def.eitIncrease :
            c := EV.GetIncrease( b1, b2 );
            IF b1 THEN
               drv_def.AssignValueInteger( InValue, TRUE, INTEGER( c ));
            ELSIF b2 THEN
               drv_def.AssignValueInteger( InValue, TRUE, -INTEGER( c ));
            ELSE
               drv_def.AssignValueInteger( InValue, TRUE, 0 );
            END;
         | eib_def.eitTime :
            EV.GetTime( Day, H, M, S );
            drv_def.AssignValueCardinal( InValue, TRUE, CARDINAL( Day ) * 100000 + ( H * 60 + M ) * 60 + S );
         | eib_def.eitDate :
            EV.GetDate( Y, M, D );
            drv_def.AssignValueLongReal( InValue, TRUE, Time.ToSJD( Time.JD( Y, M, D, 0 )));
         | eib_def.eitValue,
            eib_def.eitValueRange :
            drv_def.AssignValueLongReal( InValue, TRUE, EV.GetValue() );
         | eib_def.eitScaling :
            drv_def.AssignValueCardinal( InValue, TRUE, EV.GetScaling() );
         | eib_def.eitScaling255 :
            drv_def.AssignValueCardinal( InValue, TRUE, EV.GetScaling255() );
         | eib_def.eitMove :
            drv_def.AssignValueBoolean( InValue, TRUE, EV.GetMove() );
         | eib_def.eitFloat :
            drv_def.AssignValueLongReal( InValue, TRUE, EV.GetFloat() );
         | eib_def.eit16bit :
            drv_def.AssignValueCardinal( InValue, TRUE, EV.Get16bit() );
         | eib_def.eit32bit :
            drv_def.AssignValueCardinal( InValue, TRUE, EV.Get32bit() );
         | eib_def.eitChar :
            wch := EV.GetChar();
            InValue.ValDriverStringCharLength := 1;
            IF UFlag THEN
               Strings.MoveW( ADR( wch ), InValue.ValDriverStringAddress, 1 );
            ELSE
               Strings.ToA( OA( 0, ADR( wch )), 0, OUT OA( 0, PCHAR( InValue.ValDriverStringAddress )));
            END;
         | eib_def.eit8bit :
            drv_def.AssignValueCardinal( InValue, TRUE, EV.Get8bit() );
         | eib_def.eitString :
            EV.GetString( s );
            InValue.ValDriverStringCharLength := MIN2( InValue.ValDriverStringCharLength, LENGTH( s ));
            IF UFlag THEN
               Strings.MoveW( ADR( s ), InValue.ValDriverStringAddress, InValue.ValDriverStringCharLength );
            ELSE
               c := InValue.ValDriverStringCharLength-1;
               Strings.ToA( OA( c, ADR( s )), 0, OUT OA( c, PCHAR( InValue.ValDriverStringAddress )));
            END;
         END; // CASE EV.Type

      END;
   END GetInput;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE OutputRequestStart();
   BEGIN
   END OutputRequestStart;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE OutputRequest( UFlag : BOOLEAN; DriverIndex : CARDINAL; OutValue : drv_def.TValue; QoS : CARDINAL; TimeStamp : drv_def.TUTCStamp );
   VAR
      EV : eib_def.TValue;
      PObject : TPObject;
   BEGIN
      Result.Inc();
      IF LogNumber2Object( DriverIndex, PObject ) THEN
         CWValue2EIBValue( UFlag, OutValue, PObject^.Value.GetType(), EV );
         PObject^.SetValue( EV );
      END;
   END OutputRequest;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE OutputRequestCompleted();
   BEGIN
   END OutputRequestCompleted;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE OutputFinalized( DriverIndex : CARDINAL; VAR ErrorCode : CARDINAL ) : BOOLEAN;
   VAR
      PObject : TPObject;
   BEGIN
      IF NOT LogNumber2Object( DriverIndex, PObject ) THEN
         ErrorCode := drv_def.ecUnknownElement;
      ELSIF NOT HWConnected( ErrorCode ) THEN
         PObject^.CancelIO();
      ELSIF eib_user.osWritting IN PObject^.State THEN
         RETURN FALSE;
      ELSIF Result.Expired OR Result.Counted THEN
         RETURN FALSE;
      ELSIF PObject^.WSStatus = eib_status.essOK THEN
         ErrorCode := drv_def.ecSuccess;
      ELSE
         ErrorCode := EIBStatus2ErrorCode( PObject^.WSStatus );
      END;
      RETURN TRUE;
   END OutputFinalized;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE QueryProc( UFlag : BOOLEAN; InValue1, InValue2 : drv_def.TValue; VAR OutValue : drv_def.TValue );
   LABEL
      Error;
   VAR
      c : CARDINAL;
      CS : StringsO.CString;
      Day : eib_def.TDay;
      EIT : eib_def.TEIBType;
      EV : eib_def.TValue;
      H, M, S, D, Y : CARDINAL;
      LValue : drv_def.TValue;
      N, V : ARRAY [0..63] OF WCHAR;
      prItem : PromiscuousData;
      s : ARRAY [0..15] OF WCHAR;
      b1, b2 : BOOLEAN;
   BEGIN
      drv_def.DrvValueToCStringW( InValue1, UFlag, OUT CS );
      CS.ItemSOA( StringsO.WCHARS{ L' ' }, 0, 0, TRUE, OUT N );
      IF EQUALS( N, L'event' ) THEN

         CS.ItemSOA( StringsO.WCHARS{ L' ' }, 0, 1, TRUE, OUT N );
         IF EQUALS( N, L'count' ) THEN
         //-----
            Strings.FromCARD32W( prData.Count, 10, OUT s );
            CS.FromOA( s );

         ELSIF EQUALS( N, L'get' ) THEN
         //-----
            IF NOT prData.DequeueOA( OUT prItem, OUT c, OUT c ) THEN
               EXCL( RStatus, rsPromiscuousInQueue );

               CS.FromOA( L'' ); // queue empty;
               GOTO Error;
            END;

            IF Result.Counted OR Result.Expired THEN
               WHILE prData.DequeueOA( OUT prItem, OUT c, OUT c ) DO END;
               CS.Clear();
               GOTO Error;
            END;

            WITH prItem DO
               Address.GetGroupAddress3( TRUE, s );
               CS.FromOA( s ); CS.AppendOA( L' ' );

               eib_def.TypeToString( Value.GetType(), s );
               CS.AppendOA( s ); CS.AppendOA( L' ' );

               s[0] := WCHAR( 0 );
               CASE Value.GetType() OF
               | eib_def.eitSwitch :
                  IF Value.GetSwitch() THEN
                     s := L'true';
                  ELSE
                     s := L'false';
                  END;

               | eib_def.eitIncrease :
                  c := Value.GetIncrease( b1, b2 );
                  IF b1 THEN
                     Strings.FromINT32W( INTEGER( c ), 10, OUT s );
                  ELSIF b2 THEN
                     Strings.FromINT32W( -INTEGER( c ), 10, OUT s );
                  ELSE
                     s := L'0';
                  END;

               | eib_def.eitTime :
                  Value.GetTime( Day, H, M, S );
                  c := CARDINAL( Day ) * 100000 + ( H * 60 + M ) * 60 + S;
                  Strings.FromCARD32W( c, 10, OUT s );

               | eib_def.eitDate :
                  Value.GetDate( Y, M, D );
                  Strings.FromLONGREALW( Time.ToSJD( Time.JD( Y, M, D, 0 )), FALSE, OUT s );

               | eib_def.eitValue, eib_def.eitValueRange :
                  Strings.FromLONGREALW( Value.GetValue(), FALSE, OUT s );

               | eib_def.eitScaling :
                  Strings.FromCARD32W( Value.GetScaling(), 10, OUT s );

               | eib_def.eitScaling255 :
                  Strings.FromCARD32W( Value.GetScaling255(), 10, OUT s );

               | eib_def.eitMove :
                  IF Value.GetMove() THEN
                     s := L'true';
                  ELSE
                     s := L'false';
                  END;

               | eib_def.eitFloat :
                  Strings.FromLONGREALW( Value.GetFloat(), FALSE, OUT s );

               | eib_def.eit16bit :
                  Strings.FromCARD32W( Value.Get16bit(), 10, OUT s );

               | eib_def.eit32bit :
                  Strings.FromCARD32W( Value.Get32bit(), 10, OUT s );

               | eib_def.eitChar :
                  s[0] := Value.GetChar();
                  s[1] := WCHAR( 0 );

               | eib_def.eit8bit :
                  Strings.FromCARD32W( Value.Get8bit(), 10, OUT s );

               | eib_def.eitString :
                  Value.GetString( s );

               END; // CASE EV.Type
               IF s[0] <> WCHAR( 0 ) THEN
                  CS.AppendOA( s );
               END;

            END; // WITH

         ELSE
            CS.FromOA( L'error: unknown "event" procedure command' );
            GOTO Error;
         END;

      ELSIF EQUALS( N, L'send' ) THEN
         CS.ItemSOA( StringsO.WCHARS{ L' ' }, 0, 1, TRUE, OUT N );
         IF N[0] = WCHAR( 0 ) THEN
            CS.FromOA( L'error: "send" procedure, missing group address' );
            GOTO Error;
         END;
         CS.ItemSOA( StringsO.WCHARS{ L' ' }, 0, 2, TRUE, OUT s );
         IF s[0] = WCHAR( 0 ) THEN
            CS.FromOA( L'error: "send" procedure, missing value type' );
            GOTO Error;
         END;
         CS.ItemSOA( StringsO.WCHARS{ L' ' }, 0, 3, TRUE, OUT V );
         IF V[0] = WCHAR( 0 ) THEN
            CS.FromOA( L'error: "send" procedure, missing value' );
            GOTO Error;
         END;

         IF Result.Counted THEN
            CS.Clear();
            GOTO Error;
         ELSIF NOT eib_def.StringToType( s, EIT ) THEN
            CS.FromOA( L'error: "send" procedure, bad type name (' );
            CS.AppendOA( s );
            CS.AppendOA( L')' );
            GOTO Error;
         ELSIF NOT prObjects[EIT].prAddress.SetGroupAddress3( N ) THEN
            CS.FromOA( L'error: "send" procedure, bad group address (' );
            CS.AppendOA( N );
            CS.AppendOA( L')' );
            GOTO Error;
         ELSIF Result.Expired THEN
            CS.Clear();
            GOTO Error;
         END;

         drv_def.InitValue( LValue );
         drv_def.SetValueString( LValue, V );
         CWValue2EIBValue( TRUE, LValue, EIT, EV );
         prObjects[EIT].SetValue( EV );
         drv_def.DoneValue( LValue )

      ELSE
         CS.FromOA( L'error: unknown driver procedure' );
      END;

   Error:
      drv_def.AssignDrvValueCStringW( REF OutValue, UFlag, FALSE, CS );
      Result.Inc();
   END QueryProc;

//--------------------------------------------------------------------------------

   LOCAL PROCEDURE LogNumber2Object( LogNumber : CARDINAL; VAR PObject : TPObject ) : BOOLEAN;
   VAR
      ca : CARDINAL;
      sa : eib_def.CAddress;
   BEGIN
      IF Objects.Count = 0 THEN
         RETURN FALSE;
      END;

      LogNumber2Address( LogNumber, sa );
      ca := sa.GetGroupAddress1();
      IF Groups[ CARD16( ca ) ] = 0FFFFH THEN
         RETURN FALSE;
      END;

      PObject := Objects[ CARDINAL( Groups[ CARD16( ca ) ] ) ];
      RETURN TRUE;
   END LogNumber2Object;

//--------------------------------------------------------------------------------

   PROCEDURE EIBStatus2ErrorCode( Status : eib_status.TEIBStackStatus ) : CARDINAL;
   BEGIN 
      CASE Status OF
      | eib_status.essOK :
         RETURN drv_def.ecSuccess;
      | eib_status.essConError, eib_status.essL_Timeout :
         RETURN ceLCONError;
      | eib_status.essA_Timeout :
         RETURN ceRD_RES_Timeout;
      | eib_status.essLineBusy :
         RETURN ceLineBusy;
      | eib_status.essTransceiverFault :
         RETURN ceTransceiverFault;
      ELSE
         RETURN ceTransceiverFault; // drv_def.ecValueProcessing;
      END;
   END EIBStatus2ErrorCode;

//--------------------------------------------------------------------------------

   PROCEDURE HWConnected( VAR ErrorCode : CARDINAL ) : BOOLEAN;
   BEGIN
      IF NOT EIB^.DeviceConnected() THEN
         ErrorCode := ceDeviceUnplugged;
         RETURN FALSE;
      // ELSIF NOT EIB^.EIBConnected() THEN
      // rem 15.10.2004, this cause some problems due to not deterministic
      // TPUPART reset state reporting. But it can be an error, so it worths for
      // further analyzing... (*?*)
      ELSE
         RETURN TRUE;
      END;
   END HWConnected;

//--------------------------------------------------------------------------------

   PROCEDURE FindBehaviour( BehaviourName : ARRAY OF WCHAR; VAR Priority : eib_def.TPriority; VAR Flags : eib_def.TA_ObjectFlags ) : BOOLEAN;
   VAR
      PBehaviour : TPBehaviour;
      b : BOOLEAN;
   BEGIN
      b := Behaviours.GetFirst( OUT PBehaviour );
      WHILE b DO
         IF EQUALS( BehaviourName, PBehaviour^.Name ) THEN
            Priority := PBehaviour^.Class;
            Flags := PBehaviour^.Flags;
            RETURN TRUE;
         END;
         b := Behaviours.NextOf( PBehaviour, OUT PBehaviour );
      END;
      IF EQUALS( BehaviourName, bnReader ) THEN
         Flags := eib_def.TA_ObjectFlags{eib_def.aofCommunicated, eib_def.aofUpdate, eib_def.aofForceRead};
      ELSIF EQUALS( BehaviourName, bnTracker ) THEN
         Flags := eib_def.TA_ObjectFlags{eib_def.aofCommunicated, eib_def.aofUpdate, eib_def.aofWritable};
      ELSIF EQUALS( BehaviourName, bnTracker2 ) THEN
         Flags := eib_def.TA_ObjectFlags{eib_def.aofCommunicated, eib_def.aofUpdate, eib_def.aofWritable, eib_def.aofInitRead};
      ELSIF EQUALS( BehaviourName, bnTransmitter ) THEN
         Flags := eib_def.TA_ObjectFlags{eib_def.aofCommunicated, eib_def.aofTransmit};
      ELSIF EQUALS( BehaviourName, bnTransmitterWithStatus ) THEN
         Flags := eib_def.TA_ObjectFlags{eib_def.aofCommunicated, eib_def.aofTransmit, eib_def.aofUpdate, eib_def.aofWritable};
      ELSIF EQUALS( BehaviourName, bnTransmitterWithStatus2 ) THEN
         Flags := eib_def.TA_ObjectFlags{eib_def.aofCommunicated, eib_def.aofTransmit, eib_def.aofUpdate, eib_def.aofWritable, eib_def.aofInitRead};
      ELSIF EQUALS( BehaviourName, bnTransmitterWithStatusCallback ) THEN
         Flags := eib_def.TA_ObjectFlags{eib_def.aofCommunicated, eib_def.aofTransmit, eib_def.aofUpdate, eib_def.aofWritable, eib_def.aofAdvise};
      ELSIF EQUALS( BehaviourName, bnTransmitterWithStatusCallback2 ) THEN
         Flags := eib_def.TA_ObjectFlags{eib_def.aofCommunicated, eib_def.aofTransmit, eib_def.aofUpdate, eib_def.aofWritable, eib_def.aofAdvise, eib_def.aofInitRead};
      ELSIF EQUALS( BehaviourName, bnServer ) THEN
         Flags := eib_def.TA_ObjectFlags{eib_def.aofCommunicated, eib_def.aofReadable};
      ELSIF EQUALS( BehaviourName, bnConcentrator ) THEN
         Flags := eib_def.TA_ObjectFlags{eib_def.aofCommunicated, eib_def.aofReadable, eib_def.aofUpdate, eib_def.aofWritable};
      ELSIF EQUALS( BehaviourName, bnSource ) THEN
         Flags := eib_def.TA_ObjectFlags{eib_def.aofCommunicated, eib_def.aofReadable, eib_def.aofTransmit};
      ELSE
         RETURN FALSE;
      END;
      Priority := eib_def.priorityNormal;
      RETURN TRUE;
   END FindBehaviour;

//--------------------------------------------------------------------------------

   PROCEDURE AddObject( Priority : eib_def.TPriority; Flags : eib_def.TA_ObjectFlags; Type : eib_def.TEIBType ) : TPObject;
   VAR
      PObject : TPObject;
   BEGIN
      NEW( PObject );
      PObject^.Server := ADR( SELF );
      PObject^.Init( EIB, Type, eib_user.obNone );
      PObject^.SetClass( Priority );
      PObject^.SetFlags( Flags );
      
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

   LOCAL PROCEDURE ValueReadRequestSent( PObject : TPObject );
   BEGIN
      IF PObject^.RSStatus <> eib_status.essOK THEN
         ValueRead( PObject );
      END;
   END ValueReadRequestSent;

//--------------------------------------------------------------------------------

   LOCAL PROCEDURE ValueRead( PObject : TPObject );
   VAR
      c : CARDINAL;
      EV : eib_def.TValue;
   BEGIN
      CASE PObject^.RSStatus OF
      //-----
      | eib_status.essOK :
         INCL( PObject^.Flags, eib_def.aofEIBValue );
      
      //-----
      | eib_status.essConError, // A_Read without L_ACK -- called from ValueReadRequestSent
        eib_status.essA_Timeout : // A_Read with L_ACK but without READ
         // -- handle repeating and delaying after error
         DEC( PObject^.ReadRepeatCount );
         IF PObject^.ReadRepeatCount = 0 THEN // finalize operation after all allowed counts
            IF eib_user.osInitReadPending IN PObject^.State THEN
               c := ReadOnStart.RecoveryTime;
            ELSE
               c := ReadDuringRun.RecoveryTime;
            END;
            IF c = 0 THEN
               PObject^.RecoveryExpiration := 0;
            ELSE
               PObject^.RecoveryExpiration := CARDINAL( windows.GetTickCount()) + c;
               IF PObject^.RecoveryExpiration = 0 THEN
                  PObject^.RecoveryExpiration := 1;
               END;
            END;
            // fall down, continue...
         ELSE // continue with reading again
            PObject^.GetValue( EV, FALSE, FALSE );
            RETURN;
         END;
         // ++ handle repeating and delaying after error
      //-----
      END; // CASE

      // normal value read processing
      IF eib_user.osInitReadPending IN PObject^.State THEN
         IF PObject^.RSStatus = eib_status.essOK THEN
            PObject^.State := PObject^.State - eib_user.TObjectState{eib_user.osInitReadPending, eib_user.osInitReadRepeat};
         ELSIF InitReadRepeat <= 1 THEN // repeated init read will not be performed, so notify error
            PObject^.State := PObject^.State - eib_user.TObjectState{eib_user.osInitReadPending, eib_user.osInitReadRepeat};
            ValueUpdated( PObject );
         ELSE
            INCL( RStatus, rsInitReadRepeat );
            PObject^.State := PObject^.State - eib_user.TObjectState{eib_user.osInitReadPending} + eib_user.TObjectState{eib_user.osInitReadRepeat};
         END;
         DEC( InitReadItems );
         IF InitReadItems = 0 THEN
            InitReadFinished();
         END;
      ELSIF ( eib_user.osReading IN PObject^.State ) AND ( CallbackProc <> NIL ) THEN
         CallbackProc( CallbackId, drv_def.dcfInputFinalized, NIL );
      END;
   END ValueRead;

//--------------------------------------------------------------------------------

   LOCAL PROCEDURE ValueUpdated( PObject : TPObject );
   VAR
      EValue : eib_def.CValue;
      prItem : PromiscuousData;
   BEGIN
      IF eib_user.osReading IN PObject^.State THEN // value is NOT OOB
         RETURN;
      ELSIF PObject^.RSStatus = eib_status.essOK THEN
         INCL( PObject^.Flags, eib_def.aofEIBValue );
      END;
      IF CallbackProc = NIL THEN
         RETURN;
      END;

      // this code takes sense for cw driver only
      IF PromiscuousMode THEN // promiscuous mode queueing

         IF prData.Count >= InputQueueLength THEN
            CallbackProc( CallbackId, drv_def.dcfException, NIL );
            RETURN;
         END;
         
         prItem.Address := PObject^.prAddress;
         PObject^.GetValue( prItem.Value, TRUE, FALSE );
         prData.EnqueueOA( prItem, 0 );

         INCL( RStatus, rsPromiscuousInQueue );
         CallbackProc( CallbackId, drv_def.dcfException, NIL );

      ELSE // not promiscuous mode queueing

         IF oobData.Count >= InputQueueLength THEN
            CallbackProc( CallbackId, drv_def.dcfException, NIL );
            RETURN;
         END;

         PObject^.GetValue( EValue, TRUE, FALSE );
         oobData.EnqueueOA( EValue.Data, PObject );

         CallbackProc( CallbackId, drv_def.dcfOOBDataAdvise, NIL );

      END;
   END ValueUpdated;

//--------------------------------------------------------------------------------

   LOCAL PROCEDURE ValueWritten( PObject : TPObject );
   BEGIN
      IF PObject^.WSStatus = eib_status.essOK THEN
         INCL( PObject^.Flags, eib_def.aofEIBValue );
      END;
      IF ( eib_user.osWritting IN PObject^.State ) AND ( CallbackProc <> NIL ) THEN
         CallbackProc( CallbackId, drv_def.dcfOutputFinalized, NIL );
      END;
      IF eib_def.aofAdvise IN PObject^.GetFlags() THEN
         ValueUpdated( PObject );
      END;
   END ValueWritten;

//--------------------------------------------------------------------------------

   PROCEDURE InitToDefault();
   BEGIN
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
      Storage.Fill( ADR( Groups ), SIZE( Groups ), 0FFH );
      StatusChannel := MAX( CARDINAL );
      IF EIB <> NIL THEN
         EIB^.Done();
         DISPOSE( EIB );
      END;
   END InitToDefault;

//--------------------------------------------------------------------------------

   PROCEDURE DoInitRead( RepeatFlag : BOOLEAN );
   VAR
      EV : eib_def.TValue;
      i : CARDINAL;
      PObject : TPObject;
      
// TODO
saddr : ARRAY [0..63] OF WCHAR;
      
   BEGIN
      IF NOT RepeatFlag THEN
         InitReadRepeat := InitReadRepeatCount;
      END;
      FOR i := 0 TO Objects.Count - 1 DO
         PObject := TPObject( Objects[i] );
         IF NOT RepeatFlag AND ( eib_def.aofInitRead IN PObject^.GetFlags() ) OR
                RepeatFlag AND ( eib_user.osInitReadRepeat IN PObject^.State ) THEN

      // TODO
      PObject^.ReadAddress.GetGroupAddress3( TRUE, saddr );
      Log.logger()^.LogSS( Log.dlpIO, L"srv", "INIT: ", saddr );

            INC( InitReadItems );
            PObject^.State := PObject^.State - eib_user.TObjectState{eib_user.osInitReadRepeat} + eib_user.TObjectState{eib_user.osInitReadPending};
            PObject^.ReadRepeatCount := ReadOnStart.RepeatCount;
            PObject^.GetValue( EV, FALSE, TRUE );
         END;
      END; // FOR
   END DoInitRead;

//--------------------------------------------------------------------------------

   PROCEDURE InitReadFinished();
   BEGIN
      IF NOT( rsInitReadRepeat IN RStatus ) THEN
         RStatus := RStatus - TRStatus{rsInitReadPending} + TRStatus{rsInitReadFinished};
         EIB^.SetTimeout( eib_stack.tidA_PendingDelay, ReadDuringRun.Delay, eib_stack.pendingGroupRead );
         EIB^.SetTimeout( eib_stack.tidA_PendingTimeout, ReadDuringRun.Timeout, eib_stack.pendingGroupRead );
         IF CallbackProc <> NIL THEN
            CallbackProc( CallbackId, drv_def.dcfException, NIL );
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

   LOCAL PROCEDURE CWValue2EIBValue( UFlag : BOOLEAN; CONST Value : drv_def.TValue; DestEVType : eib_def.TEIBType; VAR EV : eib_def.TValue );
   VAR
      c : CARDINAL;
      Day : eib_def.TDay;
      fd : CARDINAL;
      H, M, S, WD : CARDINAL;
      i : INTEGER;
      s : ARRAY [0..31] OF WCHAR;
      ST : windows.SYSTEMTIME;
      Y, MM, D : INTEGER;
   BEGIN
      EV.SetType( DestEVType );

      CASE EV.GetType() OF
      | eib_def.eitUnknown :
         RETURN;
      | eib_def.eitSwitch :
         EV.SetSwitch( drv_def.ValueToBoolean( Value, TRUE ));
      | eib_def.eitIncrease :
         i := drv_def.ValueToInteger( Value, TRUE );
         IF i = 0 THEN
            EV.SetIncrease( FALSE, FALSE, 0 );
         ELSIF i < 0 THEN
            EV.SetIncrease( FALSE, TRUE, CARDINAL( -i ));
         ELSE
            EV.SetIncrease( TRUE, FALSE, CARDINAL( i ));
         END;
      | eib_def.eitTime :
         c := drv_def.ValueToCardinal( Value, TRUE );
         WD := c DIV 100000;
         c := c - WD * 100000;
         H := c DIV 3600;
         c := c - H * 3600;
         M := c DIV 60;
         S := c MOD 60;
         CASE WD OF
         | 0 :
            windows.GetLocalTime( ADR( ST ));
            Day := eib_def.TDay( 1 + ( CARDINAL( ST.wDayOfWeek ) + 6 ) MOD 7 );
         | 1..7 :
            Day := eib_def.TDay( WD );
         ELSE
            Day := eib_def.dayNo;
         END;
         EV.SetTime( Day, H, M, S );
      | eib_def.eitDate :
         Time.iJD( Time.FromSJD( drv_def.ValueToLongReal( Value, TRUE )), OUT Y, OUT MM, OUT D, OUT fd );
         EV.SetDate( Y, MM, D );
      | eib_def.eitValue, eib_def.eitValueRange :
         EV.SetValue( drv_def.ValueToLongReal( Value, TRUE ));
      | eib_def.eitScaling :
         EV.SetScaling( CARDINAL( drv_def.ValueToCard8( Value, TRUE )) );
      | eib_def.eitScaling255 :
         EV.SetScaling255( drv_def.ValueToCard8( Value, TRUE ));
      | eib_def.eitMove :
         EV.SetMove( drv_def.ValueToBoolean( Value, TRUE ));
      | eib_def.eitFloat :
         EV.SetFloat( drv_def.ValueToLongReal( Value, TRUE ));
      | eib_def.eit16bit :
         c:= drv_def.ValueToCard32( Value, TRUE );
         IF c > MAX( CARD16 ) THEN
            c := MAX( CARD16 );
         END;
         EV.Set16bit( c );
      | eib_def.eit32bit :
         EV.Set32bit( drv_def.ValueToCardinal( Value, TRUE ));
      | eib_def.eitChar :
         IF UFlag THEN
            Strings.MoveW( Value.ValDriverStringAddress, ADR( s ), 1 );
         ELSE
            Strings.ToW( OA( 0, PCHAR( Value.ValDriverStringAddress )), 0, OUT OA( 0, ADR( s )) );
         END;
         EV.SetChar( s[0] );
      | eib_def.eit8bit :
         EV.Set8bit( CARDINAL( drv_def.ValueToCard8( Value, TRUE )) );
      | eib_def.eitString :
         c := MIN2( SIZE( eib_def.TEISString ), Value.ValDriverStringCharLength );
         IF UFlag THEN
            Strings.MoveW( Value.ValDriverStringAddress, ADR( s ), c );
         ELSE
            DEC( c );
            Strings.ToW( OA( c, PCHAR( Value.ValDriverStringAddress )), 0, OUT OA( c, ADR( s )) );
         END;
         s[c] := 0W;
         EV.SetString( s );
      END; // CASE EV.Type
   
   END CWValue2EIBValue;

   LOCAL PROCEDURE IOValue2EIBValue( CONST Value : sdvalue.Value; DestEVType : eib_def.TEIBType; OUT EV : eib_def.TValue );
   VAR
      c : CARDINAL;
      Day : eib_def.TDay;
      fd : CARDINAL;
      H, M, S, WD : CARDINAL;
      i : INTEGER;
      s : ARRAY [0..31] OF WCHAR;
      ST : windows.SYSTEMTIME;
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
         c := Value.Integer;
         WD := c DIV 100000;
         c := c - WD * 100000;
         H := c DIV 3600;
         c := c - H * 3600;
         M := c DIV 60;
         S := c MOD 60;
         CASE WD OF
         | 0 :
            windows.GetLocalTime( ADR( ST ));
            Day := eib_def.TDay( 1 + ( CARDINAL( ST.wDayOfWeek ) + 6 ) MOD 7 );
         | 1..7 :
            Day := eib_def.TDay( WD );
         ELSE
            Day := eib_def.dayNo;
         END;
         EV.SetTime( Day, H, M, S );

      | eib_def.eitDate :
         Time.iJD( Value.Date, OUT Y, OUT MM, OUT D, OUT fd );
         EV.SetDate( Y, MM, D );

      | eib_def.eitValue, eib_def.eitValueRange :
         EV.SetValue( Value.Float );

      | eib_def.eitScaling :
         EV.SetScaling( Value.LimitedInteger( 8, FALSE, TRUE ));

      | eib_def.eitScaling255 :
         EV.SetScaling255( CARD8( Value.LimitedInteger( 8, FALSE, TRUE )));

      | eib_def.eitMove :
         EV.SetMove( Value.Boolean );

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

   LOCAL PROCEDURE EIBValue2IOValue( CONST EV : eib_def.TValue; OUT Value : sdvalue.Value );
   VAR
      c : CARDINAL;
      Day : eib_def.TDay;
      s : ARRAY [0..31] OF WCHAR;
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
         Value.Integer := CARDINAL( Day ) * 100000 + ( H * 60 + M ) * 60 + S;

      | eib_def.eitDate :
         EV.GetDate( Y, M, D );
         Value.Date := Time.JD( Y, M, D, 0 );

      | eib_def.eitValue, eib_def.eitValueRange :
         Value.Float := EV.GetValue();

      | eib_def.eitScaling :
         Value.Integer := EV.GetScaling();

      | eib_def.eitScaling255 :
         Value.Integer := EV.GetScaling255();

      | eib_def.eitMove :
         Value.Boolean := EV.GetMove();

      | eib_def.eitFloat :
         Value.Float := EV.GetFloat();

      | eib_def.eit16bit :
         Value.Integer := EV.Get16bit();

      | eib_def.eit32bit :
         Value.Integer := EV.Get32bit();

      | eib_def.eitChar :
         Value.Type := sdvalue.sdtString;
         Value.FromStringOA( EV.GetChar(), FALSE );

      | eib_def.eit8bit :
         Value.Integer := EV.Get8bit();

      | eib_def.eitString :
         EV.GetString( s );
         Value.FromStringOA( s, FALSE );
      END; // CASE EV.Type

   END EIBValue2IOValue;

BEGIN
   RStatus := TRStatus{};

   CallbackId := NIL;
   CallbackProc := NIL;
   Stack := stackUnknown;
   EIB := NIL;
   Sink.Server := ADR( SELF );
   SDAP.Server := ADR( SELF );

   InitToDefault();

   InitReadItems := 0;

   oobData.ItemType := lists.blitSlot32;
   prData.ItemType := lists.blitSlot64;

FINALLY
   SDAP.Dispose();
END CEIBServer;

//================================================================================

INITIALLY __I();
BEGIN
   // messages
   R.LoadRES2( EMIT( %exe ), L"eibsrv.Texts" );
END __I;

//================================================================================

END eibsrv.