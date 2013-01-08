IMPLEMENTATION MODULE Onkyo;

(*================================================================================*)

FROM Debug IMPORT
   Assertion, LogAssertionW;
   
FROM Exceptions IMPORT
   TestIfCatched, RetrieveException, CModula2Exception;

IMPORT
   digest,
   iobject,
   log,
   LogConfig,
   md5,
   resources,
   Strings,
   TextWriter,
   Texts;
   
(*--------------------------------------------------------------------------------*)

VAR
   R : resources.CResources;

(*================================================================================*)

CONST
   LOG_NAME = L"Onkyo";
   
CONST
   DEFAULT_PORT = 10001;
   CONNECTION_DISCONNECT_TIMEOUT = 86400000; // 86400 second, each day the connection is reset
   POLL_TIMEOUT = 60000; // 60 second
   EOF = 26C;

(*--------------------------------------------------------------------------------*)

#save, option( pack => 1 )
#restore

(*===========================================================================*)

TYPE
   TCommand = (
      cmdUnknown,

      cmdPower,
      cmdPowerQuery,

      cmdInput, // expects some input name, INPUT_NAME_*
      cmdInputQuery,

      cmdSpeakerA,
      cmdSpeakerAQuery,

      cmdSpeakerB,
      cmdSpeakerBQuery,

      cmdMasterVolume,
      cmdMasterVolumeQuery,
      cmdMasterVolumeUp,
      cmdMasterVolumeDown,

      cmdMute,
      cmdMuteQuery,

      cmdAudioInfoQuery,

      cmdHDMIOutput, // expects some HDMI output name, HDMI_OUTPUT_*
      cmdHDMIOutputQuery,

      // zones
      cmdZone2Power,
      cmdZone2PowerQuery,

      cmdZone3Power,
      cmdZone3PowerQuery,

      cmdZone4Power,
      cmdZone4PowerQuery
   );

CONST
   INPUT_NAME_UNKNOWN = L"unknown";
   INPUT_NAME_VIDEO1 = L"video1";
   INPUT_NAME_VIDEO2 = L"video2";
   INPUT_NAME_VIDEO3 = L"video3";
   INPUT_NAME_VIDEO4 = L"video4";
   INPUT_NAME_VIDEO5 = L"video5";
   INPUT_NAME_VIDEO6 = L"video6";
   INPUT_NAME_VIDEO7 = L"video7";
   INPUT_NAME_DVD = L"dvd";
   INPUT_NAME_TAPE1 = L"tape1";
   INPUT_NAME_TAPE2 = L"tape2";
   INPUT_NAME_PHONO = L"phono";
   INPUT_NAME_CD = L"cd";
   INPUT_NAME_FM = L"fm";
   INPUT_NAME_AM = L"am";
   INPUT_NAME_TUNER = L"tuner";
   INPUT_NAME_DLNA = L"dlna";
   INPUT_NAME_INETRADIO = L"inetradio";
   INPUT_NAME_USBFRONT = L"usbfront";
   INPUT_NAME_USBREAR = L"usbrear";
   INPUT_NAME_NETWORK = L"network";
   INPUT_NAME_UP = L"up";
   INPUT_NAME_DOWN = L"down";

   HDMI_OUTPUT_UNKNOWN = L"unknown";
   HDMI_OUTPUT_NONE = L"none";
   HDMI_OUTPUT_MAIN = L"main";
   HDMI_OUTPUT_SUB = L"sub";
   HDMI_OUTPUT_BOTH = L"main+sub";
   HDMI_OUTPUT_UP = L"up";

CLASS IMPLEMENTATION CNS;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE HashToName( CONST Hash : ns.THash; OUT Name : StringsO.IString ) : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END HashToName;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE CreateRoot() : ns.TPnsItem;
   BEGIN
      RETURN CreateNewItem( L"Onkyo", ns.ntName, iovalue.vtString, 0 );
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
      item := CreateNewItem( L"Power status", ns.ntValue, iovalue.vtInteger, PTR( cmdPowerQuery )); DataRoot^.AddChild( item );

      item := CreateNewItem( L"Input", ns.ntValue, iovalue.vtString, PTR( cmdInput )); DataRoot^.AddChild( item ); // expects some input name, INPUT_NAME_*
      item := CreateNewItem( L"Input status", ns.ntValue, iovalue.vtString, PTR( cmdInputQuery )); DataRoot^.AddChild( item );

      item := CreateNewItem( L"Speakers A", ns.ntValue, iovalue.vtBoolean, PTR( cmdSpeakerA )); DataRoot^.AddChild( item );
      item := CreateNewItem( L"Speakers A status", ns.ntValue, iovalue.vtBoolean, PTR( cmdSpeakerAQuery )); DataRoot^.AddChild( item );

      item := CreateNewItem( L"Speakers B", ns.ntValue, iovalue.vtBoolean, PTR( cmdSpeakerB )); DataRoot^.AddChild( item );
      item := CreateNewItem( L"Speakers B status", ns.ntValue, iovalue.vtBoolean, PTR( cmdSpeakerBQuery )); DataRoot^.AddChild( item );

      item := CreateNewItem( L"Master volume", ns.ntValue, iovalue.vtInteger, PTR( cmdMasterVolume )); DataRoot^.AddChild( item );
      item := CreateNewItem( L"Master volume status", ns.ntValue, iovalue.vtInteger, PTR( cmdMasterVolumeQuery )); DataRoot^.AddChild( item );
      item := CreateNewItem( L"Master volume up", ns.ntValue, iovalue.vtBoolean, PTR( cmdMasterVolumeUp )); DataRoot^.AddChild( item );
      item := CreateNewItem( L"Master volume down", ns.ntValue, iovalue.vtBoolean, PTR( cmdMasterVolumeDown )); DataRoot^.AddChild( item );

      item := CreateNewItem( L"Mute", ns.ntValue, iovalue.vtBoolean, PTR( cmdMute )); DataRoot^.AddChild( item );
      item := CreateNewItem( L"Mute status", ns.ntValue, iovalue.vtBoolean, PTR( cmdMuteQuery )); DataRoot^.AddChild( item );

      item := CreateNewItem( L"Audio info", ns.ntValue, iovalue.vtString, PTR( cmdAudioInfoQuery )); DataRoot^.AddChild( item );

      item := CreateNewItem( L"HDMI output", ns.ntValue, iovalue.vtString, PTR( cmdHDMIOutput )); DataRoot^.AddChild( item ); // expects some HDMI output name, HDMI_OUTPUT_*
      item := CreateNewItem( L"HDMI output status", ns.ntValue, iovalue.vtString, PTR( cmdHDMIOutputQuery )); DataRoot^.AddChild( item );

      item := CreateNewItem( L"Zone 2 power", ns.ntValue, iovalue.vtBoolean, PTR( cmdZone2Power )); DataRoot^.AddChild( item );
      item := CreateNewItem( L"Zone 2 power status", ns.ntValue, iovalue.vtBoolean, PTR( cmdZone2PowerQuery )); DataRoot^.AddChild( item );

      item := CreateNewItem( L"Zone 3 power", ns.ntValue, iovalue.vtBoolean, PTR( cmdZone3Power )); DataRoot^.AddChild( item );
      item := CreateNewItem( L"Zone 3 power status", ns.ntValue, iovalue.vtBoolean, PTR( cmdZone3PowerQuery )); DataRoot^.AddChild( item );

      item := CreateNewItem( L"Zone 4 power", ns.ntValue, iovalue.vtBoolean, PTR( cmdZone4Power )); DataRoot^.AddChild( item );
      item := CreateNewItem( L"Zone 4 power status", ns.ntValue, iovalue.vtBoolean, PTR( cmdZone4PowerQuery )); DataRoot^.AddChild( item )
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

   PROCEDURE AssemblyCommand( command : TCommand; CONST value : iovalue.Value; OUT request : StringsO.IString ) : BOOLEAN;
   VAR
      i : INTEGER;
      s : StringsO.CString;
      volume : ARRAY [0..7] OF WCHAR;
   BEGIN
      request.Size := 64; // reserve space

      // fill command
      CASE command OF
      //-----
      | cmdPower :
         request.FromOA( L"!1PWR0" );
         IF value.Boolean THEN
            request.AppendOA( L"1" );
         ELSE
            request.AppendOA( L"0" );
         END;
      //-----
      | cmdPowerQuery :
         request.FromOA( L"!1PWRQSTN" );

      //-----
      | cmdInput :
         request.FromOA( L"!1SLI" );
         s := value.String;
         IF s.EqualsOA( INPUT_NAME_VIDEO1 ) THEN
            request.AppendOA( L"00" );
         ELSIF s.EqualsOA( INPUT_NAME_VIDEO2 ) THEN
            request.AppendOA( L"01" );
         ELSIF s.EqualsOA( INPUT_NAME_VIDEO3 ) THEN
            request.AppendOA( L"02" );
         ELSIF s.EqualsOA( INPUT_NAME_VIDEO4 ) THEN
            request.AppendOA( L"03" );
         ELSIF s.EqualsOA( INPUT_NAME_VIDEO5 ) THEN
            request.AppendOA( L"04" );
         ELSIF s.EqualsOA( INPUT_NAME_VIDEO6 ) THEN
            request.AppendOA( L"05" );
         ELSIF s.EqualsOA( INPUT_NAME_VIDEO7 ) THEN
            request.AppendOA( L"06" );
         ELSIF s.EqualsOA( INPUT_NAME_DVD ) THEN
            request.AppendOA( L"10" );
         ELSIF s.EqualsOA( INPUT_NAME_TAPE1 ) THEN
            request.AppendOA( L"20" );
         ELSIF s.EqualsOA( INPUT_NAME_TAPE2 ) THEN
            request.AppendOA( L"21" );
         ELSIF s.EqualsOA( INPUT_NAME_PHONO ) THEN
            request.AppendOA( L"22" );
         ELSIF s.EqualsOA( INPUT_NAME_CD ) THEN
            request.AppendOA( L"23" );
         ELSIF s.EqualsOA( INPUT_NAME_FM ) THEN
            request.AppendOA( L"24" );
         ELSIF s.EqualsOA( INPUT_NAME_AM ) THEN
            request.AppendOA( L"25" );
         ELSIF s.EqualsOA( INPUT_NAME_TUNER ) THEN
            request.AppendOA( L"26" );
         ELSIF s.EqualsOA( INPUT_NAME_DLNA ) THEN
            request.AppendOA( L"27" );
         ELSIF s.EqualsOA( INPUT_NAME_INETRADIO ) THEN
            request.AppendOA( L"28" );
         ELSIF s.EqualsOA( INPUT_NAME_USBFRONT ) THEN
            request.AppendOA( L"29" );
         ELSIF s.EqualsOA( INPUT_NAME_USBREAR ) THEN
            request.AppendOA( L"2A" );
         ELSIF s.EqualsOA( INPUT_NAME_NETWORK ) THEN
            request.AppendOA( L"2B" );
         ELSIF s.EqualsOA( INPUT_NAME_UP ) THEN
            request.AppendOA( L"UP" );
         ELSIF s.EqualsOA( INPUT_NAME_DOWN ) THEN
            request.AppendOA( L"DOWN" );
         ELSE
            RETURN FALSE;
         END;
      //-----
      | cmdInputQuery :
         request.FromOA( L"!1SLIQSTN" );

      //-----
      | cmdSpeakerA :
         request.FromOA( L"!1SPA0" );
         IF value.Boolean THEN
            request.AppendOA( L"1" );
         ELSE
            request.AppendOA( L"0" );
         END;
      //-----
      | cmdSpeakerAQuery :
         request.FromOA( L"!1SPAQSTN" );

      //-----
      | cmdSpeakerB :
         request.FromOA( L"!1SPB0" );
         IF value.Boolean THEN
            request.AppendOA( L"1" );
         ELSE
            request.AppendOA( L"0" );
         END;
      //-----
      | cmdSpeakerBQuery :
         request.FromOA( L"!1SPBQSTN" );

      //-----
      | cmdMasterVolume :
         request.FromOA( L"!1MVL" );
         i := MIN2( 100, MAX2( 0, value.Integer ));
         IF NOT Strings.FromCARD64W( CARD64( value.Integer ), 16, OUT volume ) THEN
            RETURN FALSE;
         END;
         IF i < 16 THEN
            request.AppendOA( L"0" );
         END;
         request.AppendOA( volume );
      //-----
      | cmdMasterVolumeQuery :
         request.FromOA( L"!1MVLQSTN" );
      //-----
      | cmdMasterVolumeUp :
         IF NOT value.Boolean THEN
            RETURN FALSE;
         END;
         request.FromOA( L"!1MVLUP" );
      //-----
      | cmdMasterVolumeDown :
         IF NOT value.Boolean THEN
            RETURN FALSE;
         END;
         request.FromOA( L"!1MVLDOWN" );

      //-----
      | cmdMute :
         request.FromOA( L"!1AMT0" );
         IF value.Boolean THEN
            request.AppendOA( L"1" );
         ELSE
            request.AppendOA( L"0" );
         END;
      //-----
      | cmdMuteQuery :
         request.FromOA( L"!1AMTQSTN" );

      //-----
      | cmdAudioInfoQuery :
         request.FromOA( L"!1IVFQSTN" ); // request.FromOA( L"!1IFAQSTN" );

      //-----
      | cmdHDMIOutput :
         request.FromOA( L"!1HDO" );
         s := value.String;
         IF s.EqualsOA( HDMI_OUTPUT_NONE ) THEN
            request.AppendOA( L"00" );
         ELSIF s.EqualsOA( HDMI_OUTPUT_MAIN ) THEN
            request.AppendOA( L"01" );
         ELSIF s.EqualsOA( HDMI_OUTPUT_SUB ) THEN
            request.AppendOA( L"02" );
         ELSIF s.EqualsOA( HDMI_OUTPUT_BOTH ) THEN
            request.AppendOA( L"03" );
         ELSIF s.EqualsOA( HDMI_OUTPUT_UP ) THEN
            request.AppendOA( L"UP" );
         ELSE
            RETURN FALSE;
         END;
      //-----
      | cmdHDMIOutputQuery :
         request.FromOA( L"!1HDOQSTN" );

      //-----
      | cmdZone2Power :
         request.FromOA( L"!1ZPW0" );
         IF value.Boolean THEN
            request.AppendOA( L"1" );
         ELSE
            request.AppendOA( L"0" );
         END;
      //-----
      | cmdZone2PowerQuery :
         request.FromOA( L"!1ZPWQSTN" );

      //-----
      | cmdZone3Power :
         request.FromOA( L"!1PW3" );
         IF value.Boolean THEN
            request.AppendOA( L"1" );
         ELSE
            request.AppendOA( L"0" );
         END;
      //-----
      | cmdZone3PowerQuery :
         request.FromOA( L"!1PW3QSTN" );

      //-----
      | cmdZone4Power :
         request.FromOA( L"!1PW4" );
         IF value.Boolean THEN
            request.AppendOA( L"1" );
         ELSE
            request.AppendOA( L"0" );
         END;
      //-----
      | cmdZone4PowerQuery :
         request.FromOA( L"!1PW4QSTN" );

      ELSE
         RETURN FALSE;
      END; // CASE

      // add stop characters
      request.AppendOA( 13W + 10W );

      RETURN TRUE;
   END AssemblyCommand;

(*---------------------------------------------------------------------------*)

   PROCEDURE DisassemblyCommand( CONST response : StringsO.CString; OUT command : TCommand; REF value : iovalue.Value ) : BOOLEAN;
   VAR
      i : INTEGER;
      s : StringsO.CString;
      sCommand : StringsO.CString;
   BEGIN
      // check basic properties
      IF ( response.Length < 6 ) OR ( response[0] <> L"!" ) OR ( response[1] <> L"1" ) THEN
         RETURN FALSE;
      END;

      // determine command
      response.Substring( 2, 3, OUT sCommand );
      sCommand.Capitalize();

      IF sCommand.EqualsOA( L"PWR" ) THEN
         command := cmdPowerQuery;
         value.Boolean := response[6] = L"1";

      ELSIF sCommand.EqualsOA( L"SLI" ) THEN
         command := cmdInputQuery;
         response.Substring( 5, 2, OUT s );
         IF s.EqualsOA( L"00" ) THEN
            s.FromOA( INPUT_NAME_VIDEO1 );
         ELSIF s.EqualsOA( L"01" ) THEN
            s.FromOA( INPUT_NAME_VIDEO2 );
         ELSIF s.EqualsOA( L"02" ) THEN
            s.FromOA( INPUT_NAME_VIDEO3 );
         ELSIF s.EqualsOA( L"03" ) THEN
            s.FromOA( INPUT_NAME_VIDEO4 );
         ELSIF s.EqualsOA( L"04" ) THEN
            s.FromOA( INPUT_NAME_VIDEO5 );
         ELSIF s.EqualsOA( L"05" ) THEN
            s.FromOA( INPUT_NAME_VIDEO6 );
         ELSIF s.EqualsOA( L"06" ) THEN
            s.FromOA( INPUT_NAME_VIDEO7 );
         ELSIF s.EqualsOA( L"10" ) THEN
            s.FromOA( INPUT_NAME_DVD );
         ELSIF s.EqualsOA( L"20" ) THEN
            s.FromOA( INPUT_NAME_TAPE1 );
         ELSIF s.EqualsOA( L"21" ) THEN
            s.FromOA( INPUT_NAME_TAPE2 );
         ELSIF s.EqualsOA( L"22" ) THEN
            s.FromOA( INPUT_NAME_PHONO );
         ELSIF s.EqualsOA( L"23" ) THEN
            s.FromOA( INPUT_NAME_CD );
         ELSIF s.EqualsOA( L"24" ) THEN
            s.FromOA( INPUT_NAME_FM );
         ELSIF s.EqualsOA( L"25" ) THEN
            s.FromOA( INPUT_NAME_AM );
         ELSIF s.EqualsOA( L"26" ) THEN
            s.FromOA( INPUT_NAME_TUNER );
         ELSIF s.EqualsOA( L"27" ) THEN
            s.FromOA( INPUT_NAME_DLNA );
         ELSIF s.EqualsOA( L"28" ) THEN
            s.FromOA( INPUT_NAME_INETRADIO );
         ELSIF s.EqualsOA( L"29" ) THEN
            s.FromOA( INPUT_NAME_USBFRONT );
         ELSIF s.EqualsOA( L"2A" ) THEN
            s.FromOA( INPUT_NAME_USBREAR );
         ELSIF s.EqualsOA( L"2B" ) THEN
            s.FromOA( INPUT_NAME_NETWORK );
         ELSE
            s.FromOA( INPUT_NAME_UNKNOWN );
         END;
         value.String := s;

      ELSIF sCommand.EqualsOA( L"SPA" ) THEN
         command := cmdSpeakerAQuery;
         value.Boolean := response[6] = L"1";

      ELSIF sCommand.EqualsOA( L"SPB" ) THEN
         command := cmdSpeakerBQuery;
         value.Boolean := response[6] = L"1";

      ELSIF sCommand.EqualsOA( L"MVL" ) THEN
         command := cmdMasterVolumeQuery;
         response.Substring( 5, 2, OUT s );
         IF NOT s.ToINT32( 16, OUT i ) THEN
            RETURN FALSE;
         END;
         value.Integer := i;

      ELSIF sCommand.EqualsOA( L"IFV" ) THEN // IFA
         command := cmdAudioInfoQuery;
         response.Substring( 5, response.Length-1-5, OUT s );
         value.String := s;

      ELSIF sCommand.EqualsOA( L"HDO" ) THEN
         command := cmdHDMIOutputQuery;
         response.Substring( 5, 2, OUT s );
         IF s.EqualsOA( L"00" ) THEN
            s.FromOA( HDMI_OUTPUT_NONE );
         ELSIF s.EqualsOA( L"01" ) THEN
            s.FromOA( HDMI_OUTPUT_MAIN );
         ELSIF s.EqualsOA( L"02" ) THEN
            s.FromOA( HDMI_OUTPUT_SUB );
         ELSIF s.EqualsOA( L"03" ) THEN
            s.FromOA( HDMI_OUTPUT_BOTH );
         ELSE
            s.FromOA( HDMI_OUTPUT_UNKNOWN );
         END;
         value.String := s;

      ELSIF sCommand.EqualsOA( L"AMT" ) THEN
         command := cmdMuteQuery;
         value.Boolean := response[6] = L"1";

      ELSIF sCommand.EqualsOA( L"ZPW" ) THEN
         command := cmdZone2PowerQuery;
         value.Boolean := response[6] = L"1";

      ELSIF sCommand.EqualsOA( L"PW3" ) THEN
         command := cmdZone3PowerQuery;
         value.Boolean := response[6] = L"1";

      ELSIF sCommand.EqualsOA( L"PW4" ) THEN
         command := cmdZone4PowerQuery;
         value.Boolean := response[6] = L"1";

      ELSE
         RETURN FALSE;
      END;

      RETURN TRUE;
   END DisassemblyCommand;

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
         _Connection.BufferedStream^.StartReading();
         _State := csConnected;

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
      ch : CHAR;
      i, l : INTEGER;
      response : StringsO.CString;
   BEGIN
      _Connection.BufferedStream^.ReadBuffer( CARDINAL( _Connection.BufferedStream^.Length ), REF _Buffer, 0 );
      _Connection.BufferedStream^.StartReading();

      // remove unusable characters
      LOOP
         i := 0;
         l := _Buffer.Length;
         TRY
            LOOP
               IF i = l THEN
                  EXIT;
               END;
               ch := _Buffer[i];
               IF ch = C'!' THEN
                  EXIT;
               END;
               INC( i );
            END; // LOOP
         CATCH : CModula2Exception DO
            // intentionally left empty, shall not appear
         END;
         _Buffer.RemoveStart( i );
         IF i = l THEN // no start found
            EXIT;
         END;

         i := 0;
         l := _Buffer.Length;
         TRY
            LOOP
               IF i = l THEN
                  EXIT;
               END;
               ch := _Buffer[i];
               IF ch = EOF THEN
                  EXIT;
               END;
               INC( i );
            END; // LOOP
         CATCH : CModula2Exception DO
            // intentionally left empty, shall not appear
         END;
         IF i = l THEN // no next data found
            EXIT;
         END;
         INC( i ); // change last index to length
         
         // some packet found
         response.FromOAA( 0, OA( i-1, PCHAR( _Buffer.Data )));
         PIO^.OnResponse( response );

         _Buffer.RemoveStart( i );
      END;
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

   PUBLIC PROCEDURE Dispose();
   BEGIN
      _Password.Clear();
      _State := csDisconnected;

      LogConfig.DisposeAppenderList( REF _AppenderList );
   END Dispose;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Request( CONST request : StringsO.CString );
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
      d : PTR;
      request : StringsO.CString;
      writer : TextWriter.CTextWriter;
   BEGIN
      writer.Stream := _Connection.BufferedStream;
      WHILE _Queue.Dequeue( OUT request, OUT d ) DO
         IF writer.WriteTimeout( request, FALSE, CONNECTION_DISCONNECT_TIMEOUT DIV 2 ) = Sync.arTimeout THEN
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
      request : StringsO.CString;
      Result : Sync.TAsyncResult := Sync.arCompleted;
   BEGIN
      item := nsitem.TPnsItem( Item );
      IF item^.NameType <> ns.ntValue THEN
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
            request := Value.String;
            DeviceCommunicator.Logger.LogSSS( log.ldTrace, 0, LOG_NAME, L"Item write:", OA( item^.Name^.Length-1, item^.Name^.Data ), OA( request.Length-1, request.Data ));
         END;

         IF AssemblyCommand( command, Value, OUT request ) THEN
            DeviceCommunicator.Logger.LogSS( log.ldDebug, 0, LOG_NAME, L"Request to send:", OA( request.Length-3, request.Data )); // trim trailing CRLF using -3 instead of -1

            DeviceCommunicator.Request( request );
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
      request : StringsO.CString;
      value : iovalue.Value;
   BEGIN
      IF AssemblyCommand( cmdPowerQuery, value, OUT request ) THEN
         DeviceCommunicator.Logger.LogSS( log.ldDebug, 0, LOG_NAME, L"Request to send:", OA( request.Length-3, request.Data )); // trim trailing CRLF using -3 instead of -1
         DeviceCommunicator.Request( request );
      ELSE
         DeviceCommunicator.Logger.LogS( log.ldTrace, 0, LOG_NAME, L"Cannot assembly cmdPowerQuery packet" );
      END;

      IF AssemblyCommand( cmdInputQuery, value, OUT request ) THEN
         DeviceCommunicator.Logger.LogSS( log.ldDebug, 0, LOG_NAME, L"Request to send:", OA( request.Length-3, request.Data )); // trim trailing CRLF using -3 instead of -1
         DeviceCommunicator.Request( request );
      ELSE
         DeviceCommunicator.Logger.LogS( log.ldTrace, 0, LOG_NAME, L"Cannot assembly cmdInputQuery packet" );
      END;

      IF AssemblyCommand( cmdSpeakerAQuery, value, OUT request ) THEN
         DeviceCommunicator.Logger.LogSS( log.ldDebug, 0, LOG_NAME, L"Request to send:", OA( request.Length-3, request.Data )); // trim trailing CRLF using -3 instead of -1
         DeviceCommunicator.Request( request );
      ELSE
         DeviceCommunicator.Logger.LogS( log.ldTrace, 0, LOG_NAME, L"Cannot assembly cmdSpeakerAQuery packet" );
      END;

      IF AssemblyCommand( cmdSpeakerBQuery, value, OUT request ) THEN
         DeviceCommunicator.Logger.LogSS( log.ldDebug, 0, LOG_NAME, L"Request to send:", OA( request.Length-3, request.Data )); // trim trailing CRLF using -3 instead of -1
         DeviceCommunicator.Request( request );
      ELSE
         DeviceCommunicator.Logger.LogS( log.ldTrace, 0, LOG_NAME, L"Cannot assembly cmdSpeakerBQuery packet" );
      END;

      IF AssemblyCommand( cmdMasterVolumeQuery, value, OUT request ) THEN
         DeviceCommunicator.Logger.LogSS( log.ldDebug, 0, LOG_NAME, L"Request to send:", OA( request.Length-3, request.Data )); // trim trailing CRLF using -3 instead of -1
         DeviceCommunicator.Request( request );
      ELSE
         DeviceCommunicator.Logger.LogS( log.ldTrace, 0, LOG_NAME, L"Cannot assembly cmdMasterVolumeQuery packet" );
      END;

      IF AssemblyCommand( cmdMuteQuery, value, OUT request ) THEN
         DeviceCommunicator.Logger.LogSS( log.ldDebug, 0, LOG_NAME, L"Request to send:", OA( request.Length-3, request.Data )); // trim trailing CRLF using -3 instead of -1
         DeviceCommunicator.Request( request );
      ELSE
         DeviceCommunicator.Logger.LogS( log.ldTrace, 0, LOG_NAME, L"Cannot assembly cmdMuteQuery packet" );
      END;

      IF AssemblyCommand( cmdAudioInfoQuery, value, OUT request ) THEN
         DeviceCommunicator.Logger.LogSS( log.ldDebug, 0, LOG_NAME, L"Request to send:", OA( request.Length-3, request.Data )); // trim trailing CRLF using -3 instead of -1
         DeviceCommunicator.Request( request );
      ELSE
         DeviceCommunicator.Logger.LogS( log.ldTrace, 0, LOG_NAME, L"Cannot assembly cmdAudioInfoQuery packet" );
      END;

      IF AssemblyCommand( cmdHDMIOutputQuery, value, OUT request ) THEN
         DeviceCommunicator.Logger.LogSS( log.ldDebug, 0, LOG_NAME, L"Request to send:", OA( request.Length-3, request.Data )); // trim trailing CRLF using -3 instead of -1
         DeviceCommunicator.Request( request );
      ELSE
         DeviceCommunicator.Logger.LogS( log.ldTrace, 0, LOG_NAME, L"Cannot assembly cmdHDMIOutputQuery packet" );
      END;

      IF AssemblyCommand( cmdZone2PowerQuery, value, OUT request ) THEN
         DeviceCommunicator.Logger.LogSS( log.ldDebug, 0, LOG_NAME, L"Request to send:", OA( request.Length-3, request.Data )); // trim trailing CRLF using -3 instead of -1
         DeviceCommunicator.Request( request );
      ELSE
         DeviceCommunicator.Logger.LogS( log.ldTrace, 0, LOG_NAME, L"Cannot assembly cmdZone2PowerQuery packet" );
      END;

      IF AssemblyCommand( cmdZone3PowerQuery, value, OUT request ) THEN
         DeviceCommunicator.Logger.LogSS( log.ldDebug, 0, LOG_NAME, L"Request to send:", OA( request.Length-3, request.Data )); // trim trailing CRLF using -3 instead of -1
         DeviceCommunicator.Request( request );
      ELSE
         DeviceCommunicator.Logger.LogS( log.ldTrace, 0, LOG_NAME, L"Cannot assembly cmdZone3PowerQuery packet" );
      END;

      IF AssemblyCommand( cmdZone4PowerQuery, value, OUT request ) THEN
         DeviceCommunicator.Logger.LogSS( log.ldDebug, 0, LOG_NAME, L"Request to send:", OA( request.Length-3, request.Data )); // trim trailing CRLF using -3 instead of -1
         DeviceCommunicator.Request( request );
      ELSE
         DeviceCommunicator.Logger.LogS( log.ldTrace, 0, LOG_NAME, L"Cannot assembly cmdZone4PowerQuery packet" );
      END;
   END OnTimeout;

(*---------------------------------------------------------------------------*)

   LOCAL PROCEDURE OnResponse( CONST response : StringsO.CString );
   VAR
      al : Sync.AutoLock;
      command : TCommand;
      i : CARDINAL;
      item : nsitem.TPnsItem := NIL;
      s : StringsO.CString;
      value : iovalue.Value;
   BEGIN
      DeviceCommunicator.Logger.LogSS( log.ldDebug, 0, LOG_NAME, L"Response received:", OA( response.Length-1, response.Data ));

      IF DisassemblyCommand( response, OUT command, REF value ) THEN
         FOR i := 0 TO DataRoot^.Count-1 DO
            IF DataRoot^[i]^.Data = PTR( command ) THEN
               item := nsitem.TPnsItem( DataRoot^[i] );
               EXIT;
            END;
         END;
         IF item = NIL THEN
            RETURN;
         END;
      
         IF item <> NIL THEN
            IF NOT DeviceCommunicator.Logger.FilteredFastCheck( log.ldDebug, 0 ) THEN
               s := value.String;
               DeviceCommunicator.Logger.LogSSS( log.ldTrace, 0, LOG_NAME, L"Item value accepted:", OA( item^.Name^.Length-1, item^.Name^.Data ), OA( s.Length-1, s.Data ));
            END;

            al.TakeSafe( REF _Lock, L"Unable to lock data area" );
            item^.Value^.Undefined := FALSE;
            item^.Value^ := value;
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

CLASS IMPLEMENTATION COnkyoDevice;

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
   OnDispose();
END COnkyoDevice;

(*===========================================================================*)

BEGIN
   R.LoadRES2( EMIT( %dll ), L"Onkyo.Texts" );
END Onkyo.
