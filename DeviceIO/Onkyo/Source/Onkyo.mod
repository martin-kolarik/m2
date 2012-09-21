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
   DEFAULT_PORT = 60128;
   CONNECTION_DISCONNECT_TIMEOUT = 86400000; // 86400 second, each day the connection is reset
   POLL_TIMEOUT = 20000; // 20 second, in the case of missing connection

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
      item := CreateNewItem( L"Speakers B", ns.ntValue, iovalue.vtBoolean, PTR( cmdSpeakerBQuery )); DataRoot^.AddChild( item );

      item := CreateNewItem( L"Master volume", ns.ntValue, iovalue.vtInteger, PTR( cmdMasterVolume )); DataRoot^.AddChild( item );
      item := CreateNewItem( L"Master volume status", ns.ntValue, iovalue.vtInteger, PTR( cmdMasterVolumeQuery )); DataRoot^.AddChild( item );
      item := CreateNewItem( L"Master volume up", ns.ntValue, iovalue.vtBoolean, PTR( cmdMasterVolumeUp )); DataRoot^.AddChild( item );
      item := CreateNewItem( L"Master volume down", ns.ntValue, iovalue.vtBoolean, PTR( cmdMasterVolumeDown )); DataRoot^.AddChild( item );

      item := CreateNewItem( L"Audio info", ns.ntValue, iovalue.vtString, PTR( cmdAudioInfoQuery )); DataRoot^.AddChild( item );

      item := CreateNewItem( L"HDMI output", ns.ntValue, iovalue.vtString, PTR( cmdHDMIOutput )); DataRoot^.AddChild( item ); // expects some HDMI output name, HDMI_OUTPUT_*
      item := CreateNewItem( L"HDMI output status", ns.ntValue, iovalue.vtString, PTR( cmdHDMIOutputQuery )); DataRoot^.AddChild( item );

      item := CreateNewItem( L"Zone2 power", ns.ntValue, iovalue.vtBoolean, PTR( cmdZone2Power )); DataRoot^.AddChild( item );
      item := CreateNewItem( L"Zone2 power status", ns.ntValue, iovalue.vtBoolean, PTR( cmdZone2PowerQuery )); DataRoot^.AddChild( item );

      item := CreateNewItem( L"Zone3 power", ns.ntValue, iovalue.vtBoolean, PTR( cmdZone3Power )); DataRoot^.AddChild( item );
      item := CreateNewItem( L"Zone3 power status", ns.ntValue, iovalue.vtBoolean, PTR( cmdZone3PowerQuery )); DataRoot^.AddChild( item );

      item := CreateNewItem( L"Zone4 power", ns.ntValue, iovalue.vtBoolean, PTR( cmdZone4Power )); DataRoot^.AddChild( item );
      item := CreateNewItem( L"Zone4 power status", ns.ntValue, iovalue.vtBoolean, PTR( cmdZone4PowerQuery )); DataRoot^.AddChild( item )
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

   PROCEDURE AssemblyCommand( command : TCommand; CONST value : iovalue.Value; OUT request : StorageO.CMemoryBuffer ) : BOOLEAN;
   CONST
      D = 16; // Data start
      V = 18; // Value in data start
   VAR
      i : INTEGER;
      s : StringsO.CString;
      valueLength : CARDINAL;
      volume : ARRAY [0..7] OF CHAR;
   BEGIN
      request.Size := 64; // reserve space

      TRY

         // fill command
         CASE command OF
         //-----
         | cmdPower :
            request[V+0] := C'P';
            request[V+1] := C'W';
            request[V+2] := C'R';
            request[V+3] := C'0';
            IF value.Boolean THEN
               request[V+4] := C'1';
            ELSE
               request[V+4] := C'0';
            END;
            valueLength := 5;

         //-----
         | cmdPowerQuery :
            request[V+0] := C'P';
            request[V+1] := C'W';
            request[V+2] := C'R';
            request[V+3] := C'Q';
            request[V+4] := C'S';
            request[V+5] := C'T';
            request[V+6] := C'N';
            valueLength := 7;

         //-----
         | cmdInputQuery :
            request[V+0] := C'S';
            request[V+1] := C'L';
            request[V+2] := C'I';
            request[V+3] := C'Q';
            request[V+4] := C'S';
            request[V+5] := C'T';
            request[V+6] := C'N';
            valueLength := 7;

         //-----
         | cmdSpeakerA :
            request[V+0] := C'S';
            request[V+1] := C'P';
            request[V+2] := C'A';
            request[V+3] := C'0';
            IF value.Boolean THEN
               request[V+4] := C'1';
            ELSE
               request[V+4] := C'0';
            END;
            valueLength := 5;

         //-----
         | cmdSpeakerAQuery :
            request[V+0] := C'S';
            request[V+1] := C'P';
            request[V+2] := C'A';
            request[V+3] := C'Q';
            request[V+4] := C'S';
            request[V+5] := C'T';
            request[V+6] := C'N';
            valueLength := 7;

         //-----
         | cmdSpeakerB :
            request[V+0] := C'S';
            request[V+1] := C'P';
            request[V+2] := C'B';
            request[V+3] := C'0';
            IF value.Boolean THEN
               request[V+4] := C'1';
            ELSE
               request[V+4] := C'0';
            END;
            valueLength := 5;

         //-----
         | cmdSpeakerBQuery :
            request[V+0] := C'S';
            request[V+1] := C'P';
            request[V+2] := C'B';
            request[V+3] := C'Q';
            request[V+4] := C'S';
            request[V+5] := C'T';
            request[V+6] := C'N';
            valueLength := 7;

         //-----
         | cmdMasterVolume :
            request[V+0] := C'M';
            request[V+1] := C'V';
            request[V+2] := C'L';

            i := MIN2( 100, MAX2( 0, value.Integer ));
            IF NOT Strings.FromCARD64A( CARD64( value.Integer ), 16, OUT volume ) THEN
               RETURN FALSE;
            END;
            IF i > 16 THEN
               request[V+3] := volume[0];
               request[V+4] := volume[1];
            ELSE
               request[V+3] := C'0';
               request[V+4] := volume[0];
            END;

            valueLength := 5;

         //-----
         | cmdMasterVolumeQuery :
            request[V+0] := C'M';
            request[V+1] := C'V';
            request[V+2] := C'L';
            request[V+3] := C'Q';
            request[V+4] := C'S';
            request[V+5] := C'T';
            request[V+6] := C'N';
            valueLength := 7;

         //-----
         | cmdMasterVolumeUp :
            request[V+0] := C'M';
            request[V+1] := C'V';
            request[V+2] := C'L';
            request[V+3] := C'U';
            request[V+4] := C'P';
            valueLength := 5;

         //-----
         | cmdMasterVolumeDown :
            request[V+0] := C'M';
            request[V+1] := C'V';
            request[V+2] := C'L';
            request[V+3] := C'D';
            request[V+4] := C'O';
            request[V+5] := C'W';
            request[V+6] := C'N';
            valueLength := 7;

         //-----
         | cmdAudioInfoQuery :
            request[V+0] := C'I';
            request[V+1] := C'F';
            request[V+2] := C'A';
            request[V+3] := C'Q';
            request[V+4] := C'S';
            request[V+5] := C'T';
            request[V+6] := C'N';
            valueLength := 7;

         //-----
         | cmdHDMIOutputQuery :
            request[V+0] := C'H';
            request[V+1] := C'D';
            request[V+2] := C'O';
            request[V+3] := C'Q';
            request[V+4] := C'S';
            request[V+5] := C'T';
            request[V+6] := C'N';
            valueLength := 7;

         //-----
         | cmdZone2Power :
            request[V+0] := C'Z';
            request[V+1] := C'P';
            request[V+2] := C'W';
            request[V+3] := C'0';
            IF value.Boolean THEN
               request[V+4] := C'1';
            ELSE
               request[V+4] := C'0';
            END;
            valueLength := 5;

         //-----
         | cmdZone2PowerQuery :
            request[V+0] := C'Z';
            request[V+1] := C'P';
            request[V+2] := C'W';
            request[V+3] := C'Q';
            request[V+4] := C'S';
            request[V+5] := C'T';
            request[V+6] := C'N';
            valueLength := 7;

         //-----
         | cmdZone3Power :
            request[V+0] := C'P';
            request[V+1] := C'W';
            request[V+2] := C'3';
            request[V+3] := C'0';
            IF value.Boolean THEN
               request[V+4] := C'1';
            ELSE
               request[V+4] := C'0';
            END;
            valueLength := 5;

         //-----
         | cmdZone3PowerQuery :
            request[V+0] := C'P';
            request[V+1] := C'W';
            request[V+2] := C'3';
            request[V+3] := C'Q';
            request[V+4] := C'S';
            request[V+5] := C'T';
            request[V+6] := C'N';
            valueLength := 7;

         //-----
         | cmdZone4Power :
            request[V+0] := C'P';
            request[V+1] := C'W';
            request[V+2] := C'4';
            request[V+3] := C'0';
            IF value.Boolean THEN
               request[V+4] := C'1';
            ELSE
               request[V+4] := C'0';
            END;
            valueLength := 5;

         //-----
         | cmdZone4PowerQuery :
            request[V+0] := C'P';
            request[V+1] := C'W';
            request[V+2] := C'4';
            request[V+3] := C'Q';
            request[V+4] := C'S';
            request[V+5] := C'T';
            request[V+6] := C'N';
            valueLength := 7;

         //-----
         | cmdInput :
            valueLength := 5;
            s := value.String;
            IF s.EqualsOA( INPUT_NAME_VIDEO1 ) THEN
               request[V+3] := C'0'; 
               request[V+4] := C'0';
            ELSIF s.EqualsOA( INPUT_NAME_VIDEO2 ) THEN
               request[V+3] := C'0';
               request[V+4] := C'1';
            ELSIF s.EqualsOA( INPUT_NAME_VIDEO3 ) THEN
               request[V+3] := C'0';
               request[V+4] := C'2';
            ELSIF s.EqualsOA( INPUT_NAME_VIDEO4 ) THEN
               request[V+3] := C'0';
               request[V+4] := C'3';
            ELSIF s.EqualsOA( INPUT_NAME_VIDEO5 ) THEN
               request[V+3] := C'0';
               request[V+4] := C'4';
            ELSIF s.EqualsOA( INPUT_NAME_VIDEO6 ) THEN
               request[V+3] := C'0';
               request[V+4] := C'5';
            ELSIF s.EqualsOA( INPUT_NAME_VIDEO7 ) THEN
               request[V+3] := C'0';
               request[V+4] := C'6';
            ELSIF s.EqualsOA( INPUT_NAME_DVD ) THEN
               request[V+3] := C'1';
               request[V+4] := C'0';
            ELSIF s.EqualsOA( INPUT_NAME_TAPE1 ) THEN
               request[V+3] := C'2';
               request[V+4] := C'0';
            ELSIF s.EqualsOA( INPUT_NAME_TAPE2 ) THEN
               request[V+3] := C'2';
               request[V+4] := C'1';
            ELSIF s.EqualsOA( INPUT_NAME_PHONO ) THEN
               request[V+3] := C'2';
               request[V+4] := C'2';
            ELSIF s.EqualsOA( INPUT_NAME_CD ) THEN
               request[V+3] := C'2';
               request[V+4] := C'3';
            ELSIF s.EqualsOA( INPUT_NAME_FM ) THEN
               request[V+3] := C'2';
               request[V+4] := C'4';
            ELSIF s.EqualsOA( INPUT_NAME_AM ) THEN
               request[V+3] := C'2';
               request[V+4] := C'5';
            ELSIF s.EqualsOA( INPUT_NAME_TUNER ) THEN
               request[V+3] := C'2';
               request[V+4] := C'6';
            ELSIF s.EqualsOA( INPUT_NAME_DLNA ) THEN
               request[V+3] := C'2';
               request[V+4] := C'7';
            ELSIF s.EqualsOA( INPUT_NAME_INETRADIO ) THEN
               request[V+3] := C'2';
               request[V+4] := C'8';
            ELSIF s.EqualsOA( INPUT_NAME_USBFRONT ) THEN
               request[V+3] := C'2';
               request[V+4] := C'9';
            ELSIF s.EqualsOA( INPUT_NAME_USBREAR ) THEN
               request[V+3] := C'2';
               request[V+4] := C'A';
            ELSIF s.EqualsOA( INPUT_NAME_NETWORK ) THEN
               request[V+3] := C'2';
               request[V+4] := C'B';
            ELSIF s.EqualsOA( INPUT_NAME_UP ) THEN
               request[V+3] := C'U';
               request[V+4] := C'P';
            ELSIF s.EqualsOA( INPUT_NAME_DOWN ) THEN
               request[V+3] := C'D';
               request[V+4] := C'O';
               request[V+5] := C'W';
               request[V+6] := C'N';
               valueLength := 7;
            ELSE
               RETURN FALSE;
            END;

            request[V+0] := C'S';
            request[V+1] := C'L';
            request[V+2] := C'I';

         //-----
         | cmdHDMIOutput :
            valueLength := 5;
            s := value.String;
            IF s.EqualsOA( HDMI_OUTPUT_NONE ) THEN
               request[V+3] := C'0';
               request[V+4] := C'0';
            ELSIF s.EqualsOA( HDMI_OUTPUT_MAIN ) THEN
               request[V+3] := C'0';
               request[V+4] := C'1';
            ELSIF s.EqualsOA( HDMI_OUTPUT_SUB ) THEN
               request[V+3] := C'0';
               request[V+4] := C'2';
            ELSIF s.EqualsOA( HDMI_OUTPUT_BOTH ) THEN
               request[V+3] := C'0';
               request[V+4] := C'3';
            ELSIF s.EqualsOA( HDMI_OUTPUT_UP ) THEN
               request[V+3] := C'U';
               request[V+4] := C'P';
            ELSE
               RETURN FALSE;
            END;

            request[V+0] := C'H';
            request[V+1] := C'D';
            request[V+2] := C'O';

         ELSE
            RETURN FALSE;
         END; // CASE

         request[00] := C'I'; request[01] := C'S'; request[02] := C'C'; request[03] := C'P';
         request[04] := 0;    request[05] := 0;    request[06] := 0;    request[07] := 16;
         request[08] := 0;    request[09] := 0;    request[10] := 0;    request[11] := 0; // data size
         request[12] := 1;    request[13] := 0;    request[14] := 0;    request[15] := 0;

         request[D+0] := C'!';
         request[D+1] := C'1';

         // add stop characters
         request[V+valueLength+0] := 26;
         request[V+valueLength+1] := 13;
         request[V+valueLength+2] := 10;

      CATCH : CModula2Exception DO
         RETURN FALSE;

      END; // TRY

      RETURN TRUE;
   END AssemblyCommand;

(*---------------------------------------------------------------------------*)

   PROCEDURE DisassemblyCommand( CONST response : StorageO.CMemoryBuffer; OUT command1, command2 : TCommand; REF value1, value2 : iovalue.Value ) : BOOLEAN;
   VAR
      sCommand : StringsO.CString;
   BEGIN
      (*
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
      *)

      RETURN FALSE;
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
      request : StorageO.CMemoryBuffer;
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
            Logger.LogSB( log.ldDebug, 0, LOG_NAME, L"Dropped request:", request.Data, request.Length );
         END; // WHILE

      END;
   END OnConnect;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnReadable( Length : CARDINAL; Source : ADDRESS );
   VAR
      authError : BOOLEAN;
      byteLen : CARDINAL;
      ptext : PWCHAR;
      response : StorageO.CMemoryBuffer;
   BEGIN
      WHILE _Reader.Peek( OUT ptext, OUT byteLen ) DO
         IF byteLen >= 4 THEN
            response.FromOA( OA( byteLen DIV 2 - 2, ptext )); // -1 CR, -1 Len to HIGH

            IF _State = csConnected THEN // TODO
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

   PUBLIC PROCEDURE Dispose();
   BEGIN
      _Password.Clear();
      _State := csDisconnected;
      _AuthRequested := FALSE;

      LogConfig.DisposeAppenderList( REF _AppenderList );
   END Dispose;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Request( CONST request : StorageO.AMemoryBuffer );
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
      filled : CARDINAL;
      request : StorageO.CMemoryBuffer;
   BEGIN
      WHILE _Queue.Dequeue( OUT request, OUT d ) DO

         IF _AuthRequested THEN
            // TODO
         END;
         
         IF _Connection.BufferedStream^.WriteBuffer( request, OUT consumed, CONNECTION_DISCONNECT_TIMEOUT DIV 2 ) = Sync.arTimeout THEN
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
      b : StorageO.CMemoryBuffer;
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

         IF AssemblyCommand( command, Value, OUT b ) THEN
            DeviceCommunicator.Logger.LogSS( log.ldDebug, 0, LOG_NAME, L"Request to send:", OA( s.Length-1, s.Data ));

            DeviceCommunicator.Request( b );
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
      request : StorageO.CMemoryBuffer;
      value : iovalue.Value;
   BEGIN
      IF AssemblyCommand( cmdPowerQuery, value, OUT request ) THEN
         DeviceCommunicator.Logger.LogSB( log.ldDebug, 0, LOG_NAME, L"Request to send:", request.Data, request.Length );
         DeviceCommunicator.Request( request );
      ELSE
         DeviceCommunicator.Logger.LogS( log.ldTrace, 0, LOG_NAME, L"Cannot assembly cmdPowerQuery packet" );
      END;
   END OnTimeout;

(*---------------------------------------------------------------------------*)

   LOCAL PROCEDURE OnResponse( CONST response : StorageO.CMemoryBuffer );
   VAR
      al : Sync.AutoLock;
      command1, command2 : TCommand;
      i : CARDINAL;
      item1, item2 : nsitem.TPnsItem := NIL;
      s : StringsO.CString;
      value1, value2 : iovalue.Value;
   BEGIN
      DeviceCommunicator.Logger.LogSB( log.ldDebug, 0, LOG_NAME, L"Response received:", response.Data, response.Length );

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
