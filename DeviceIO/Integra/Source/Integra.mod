IMPLEMENTATION MODULE Integra;

(*================================================================================*)

FROM Debug IMPORT
   Assertion, LogAssertionW;
   
FROM Exceptions IMPORT
   TestIfCatched, RetrieveException, CModula2Exception;

IMPORT
   bitarray,
   datetime,
   FIO,
   IOO,
   LogConfig,
   resources,
   Storage,
   StorageO,
   Strings,
   StringsO,
   Sync,
   Texts;
   
IMPORT
   log;

(*================================================================================*)

VAR
   R : resources.CResources;

(*================================================================================*)

CONST
   LOG_NAME = L"Integra";
   
   ARM_SUFFIX = L" arm";
   DISARM_SUFFIX = L" disarm";
   ARMED_SUFFIX = L" armed";
   ALARM_SUFFIX = L" alarm";
   OUTPUTS_SUFFIX = L" outputs";

   PARTITIONS = 32;
   OUTPUTS = 64;

CONST
   DEFAULT_PORT = 10001;
   CONNECTION_CHECK_TIMEOUT = 10000; // 10 second

CONST
   B_SYNCHRONIZE  = 0FFH;
   B_STOP         = 0AAH;
   B_INTERLEAVE_1 = 0FFH;
   B_INTERLEAVE_2 = 0FEH;

#save, option( pack => 1 )
TYPE
   TPacketType = INT8(
      ptUnknown,
      ptInfo,
      ptArm = 70H,
      ptDisarm = 71H
   );
   
   TInfoType = INT8(
      itViolation1         = 0H,
      itViolation2         = 1H,
      itTamper1            = 2H,
      itTamper2            = 3H,
      itAlarm1             = 4H,
      itAlarm2             = 5H,
      itTamperAlarm1       = 6H,
      itTamperAlarm2       = 7H,
      itAlarmMemory1       = 8H,
      itAlarmMemory2       = 9H,
      itTamperAlarmMemory1 = 0AH,
      itTamperAlarmMemory2 = 0BH,
      itBypasses1          = 0CH,
      itBypasses2          = 0DH,
      itNoViolation1       = 0EH,
      itNoViolation2       = 0FH,
      itLongViolation1     = 010H,
      itLongViolation2     = 011H,
      itPartArmed          = 012H,
      itPartEntry          = 013H,
      itPartExit1          = 014H,
      itPartExit2          = 015H,
      itPartAlarm          = 016H,
      itPartFire           = 017H,
      itPartAlarmMemory    = 018H,
      itPartFireMemory     = 019H,
      itDateTime           = 01AH,
      it27                 = 01BH,
      it28                 = 01CH,
      itOutputsState       = 055H
   );

TYPE
  TWirePacket  = RECORD
                 CASE : TPacketType OF
                 //-----
                 | ptUnknown :
                 //-----
                 | ptArm :
                    ArmSync1 : BYTE;
                    ArmSync2 : BYTE;
                    ArmDataType : TPacketType;
                    ArmCode : ARRAY [0..7] OF BYTE;
                    ArmPartitions : ARRAY [0..3] OF BYTE;
                    ArmMode : BYTE;
                    ArmCRC : BYTE;
                    ArmOuterCRC : BYTE;
                    ArmTrail1 : BYTE;
                    ArmTrail2 : BYTE;
                 //-----
                 | ptDisarm :
                    DisarmSync1 : BYTE;
                    DisarmSync2 : BYTE;
                    DisarmDataType : TPacketType;
                    DisarmCode : ARRAY [0..7] OF BYTE;
                    DisarmPartitions : ARRAY [0..3] OF BYTE;
                    DisarmCRC : BYTE;
                    DisarmOuterCRC : BYTE;
                    DisarmTrail1 : BYTE;
                    DisarmTrail2 : BYTE;
                 //-----
                 | ptInfo :
                    Interleave : BYTE;
                    InfoDataType : TInfoType;
                    InfoData : ARRAY [0..15] OF BYTE;
                    // InfoCRC : BYTE; -- somewhere at the end
                 //-----
                 END; // CASE
              END; // RECORD
   TPWirePacket = POINTER TO TWirePacket;
#restore

CLASS CPacket; // class is wrapping some foreign data area
   PRIVATE VAR
      _PacketType : TPacketType;
      _Packet : TPWirePacket;
      _Length : CARDINAL;
      _Shifted : BOOLEAN;

   PUBLIC PROPERTY
      PacketType : TPacketType;

   PUBLIC WRITEONLY PROPERTY
      EmptyPacket : TPWirePacket;
      FilledPacket : TPWirePacket;

   PUBLIC READONLY PROPERTY
      Packet : TPWirePacket;
      Length : CARDINAL;
      Shifted : BOOLEAN;
      
   PUBLIC PROCEDURE ComputeCheckSum();
   PUBLIC PROCEDURE TestCheckSum() : BOOLEAN;
   PUBLIC PROCEDURE Complete( KnownLength : CARDINAL; OUT FirstIndexAfterData, FirstIndexAfterFrame : CARDINAL; OUT ApplyChecksum : BOOLEAN ) : BOOLEAN;

   PRIVATE PROCEDURE SetPacketBoundaries(); // _Packet MUST not be NIL
   PRIVATE PROCEDURE DetermineLengthAndShift(); // _Packet MUST not be NIL
END CPacket;

(*===========================================================================*)

CLASS IMPLEMENTATION CPacket;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY PacketType GET : TPacketType;
   BEGIN
      RETURN _PacketType;
   END PacketType;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY PacketType SET( Value : TPacketType );
   BEGIN
      _PacketType := Value;
      IF _Packet <> NIL THEN
         SetPacketBoundaries();
         DetermineLengthAndShift();
      END;
   END PacketType;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY EmptyPacket SET( Value : TPWirePacket );
   BEGIN
      _Packet := Value;
      IF _PacketType <> ptUnknown THEN
         SetPacketBoundaries();
         DetermineLengthAndShift();
      END;
   END EmptyPacket;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY FilledPacket SET( Value : TPWirePacket );
   BEGIN
      _Packet := Value;
      IF _Packet = NIL THEN
         RETURN;
      ELSIF _Packet^.ArmSync2 = B_SYNCHRONIZE THEN // differences in this byte are principal
         IF _Packet^.ArmDataType = ptArm THEN
            _PacketType := ptArm;
         ELSIF _Packet^.ArmDataType = ptDisarm THEN
            _PacketType := ptDisarm;
         ELSE
            ASSERTLOG( FALSE );
            _Packet := NIL;
         END;
      ELSE // assume info
         _PacketType := ptInfo;
      END;
      DetermineLengthAndShift();
   END FilledPacket;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Packet GET : TPWirePacket;
   BEGIN
      RETURN _Packet;
   END Packet;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Length GET : CARDINAL;
   BEGIN
      RETURN _Length;
   END Length;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Shifted GET : BOOLEAN;
   BEGIN
      RETURN _Shifted;
   END Shifted;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ComputeCheckSum();
   VAR
      chksum : CARD8;
      chksumFrom : CARDINAL;
      chksumOffset : CARDINAL;
      i : CARDINAL;
   BEGIN
      chksumFrom := 2;
      CASE _PacketType OF
      | ptArm :
         chksumOffset := FIELDOFS( TWirePacket.ArmCRC );
      | ptDisarm :
         chksumOffset := FIELDOFS( TWirePacket.DisarmCRC );
      ELSE
         ASSERTLOG( FALSE );
         RETURN;
      END;

      // inner chksum      
      chksum := 0;
      FOR i := chksumFrom TO chksumOffset - 1 DO
         chksum := chksum XOR PCARD8( _Packet@[i] )^;
      END; // FOR
      PCARD8( _Packet@[chksumOffset] )^ := chksum;

      // outer chksum
      chksumFrom := 2;
      IF _PacketType = ptArm THEN
         chksumOffset := FIELDOFS( TWirePacket.ArmOuterCRC );
      ELSE
         chksumOffset := FIELDOFS( TWirePacket.DisarmOuterCRC );
      END;

      chksum := 0;
      FOR i := chksumFrom TO chksumOffset - 1 DO
         INC( chksum, PCARD8( _Packet@[i] )^ );
      END; // FOR
      PCARD8( _Packet@[chksumOffset] )^ := chksum;

   END ComputeCheckSum;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE TestCheckSum() : BOOLEAN;
   VAR
      chksum : CARD8;
      chksumFrom : CARDINAL;
      chksumOffset : CARDINAL;
      chksumToCheck : CARD8;
      i : CARDINAL;
   BEGIN
      CASE _PacketType OF
      | ptInfo :
         chksumFrom := 0;
         chksumOffset := _Length-1;
      ELSE
         RETURN FALSE;
      END;

      chksumToCheck := CARD8( _Packet@[chksumOffset]^ );
      
      chksum := 0;
      FOR i := chksumFrom TO chksumOffset - 1 DO
         INC( chksum, PCARD8( _Packet@[i] )^ );
      END;

      RETURN chksumToCheck = chksum;
   END TestCheckSum;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Complete( KnownLength : CARDINAL; OUT FirstIndexAfterData, FirstIndexAfterFrame : CARDINAL; OUT ApplyChecksum : BOOLEAN ) : BOOLEAN;
   BEGIN
      IF ( _Packet = NIL ) OR ( KnownLength < 1 ) THEN
         RETURN FALSE;
      END;

      CASE _PacketType OF
      //-----
      | ptInfo :
         IF KnownLength < 7 THEN (* 7 is the minimal length of the packet *)
            RETURN FALSE;
         END;
         FirstIndexAfterFrame := _Length;
         FirstIndexAfterData := FirstIndexAfterFrame - SIZE( BYTE ); // - SIZE( CRC )
         ApplyChecksum := TRUE;
      //-----
      ELSE
         ASSERTLOG( FALSE );
         RETURN FALSE;
      END;

      RETURN KnownLength >= FirstIndexAfterFrame;
   END Complete;

(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE SetPacketBoundaries(); // _Packet MUST not be NIL
   BEGIN
      CASE _PacketType OF
      | ptArm :
         _Packet^.ArmSync1 := B_SYNCHRONIZE;
         _Packet^.ArmSync2 := B_SYNCHRONIZE;
         _Packet^.ArmDataType := ptArm;
         _Packet^.ArmTrail1 := B_SYNCHRONIZE;
         _Packet^.ArmTrail2 := B_STOP;
      | ptDisarm :
         _Packet^.DisarmSync1 := B_SYNCHRONIZE;
         _Packet^.DisarmSync2 := B_SYNCHRONIZE;
         _Packet^.DisarmDataType := ptDisarm;
         _Packet^.DisarmTrail1 := B_SYNCHRONIZE;
         _Packet^.DisarmTrail2 := B_STOP;
      END;
   END SetPacketBoundaries;

(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE DetermineLengthAndShift();
   VAR
      i : CARDINAL;
      xor : CARD8;
   BEGIN
      _Shifted := FALSE;
      _Length := 0;
      IF _Packet = NIL THEN
         RETURN;
      END;
      CASE _PacketType OF
      | ptArm :
         _Length := FIELDOFS( TWirePacket.ArmTrail2 ) + SIZE( TWirePacket.ArmTrail2 );
      | ptDisarm :
         _Length := FIELDOFS( TWirePacket.DisarmTrail2 ) + SIZE( TWirePacket.DisarmTrail2 );
      | ptInfo :
         CASE _Packet^.InfoDataType OF
         // fixed lengths
         | itDateTime:
            _Length := 3 + 7;
         | itOutputsState:
            _Length := 3 + 9;
         // variable lengths
         | itViolation1, itViolation2, itTamper1, itTamper2, itAlarm1, itAlarm2, itTamperAlarm1, itTamperAlarm2, itAlarmMemory1, itAlarmMemory2, itTamperAlarmMemory1, itTamperAlarmMemory2,
           itBypasses1, itBypasses2, itNoViolation1, itNoViolation2, itLongViolation1, itLongViolation2, itPartArmed, itPartEntry, itPartExit1, itPartExit2, itPartAlarm, itPartFire,
           itPartAlarmMemory, itPartFireMemory, it27:
            xor := CARD8( _Packet^.InfoDataType );
            FOR i := 0 TO 3 DO
               xor := xor + CARD8( _Packet^.InfoData[i] );
            END;
            IF xor = _Packet^.InfoData[4] THEN // 5 data bytes
               _Length := 3 + 5;
               _Shifted := TRUE;
            ELSE
               _Length := 3 + 4;
            END;
         | it28 :
            IF _Packet^.InfoData[0] = 0 THEN
               _Length := 3 + 5;
            ELSIF _Packet^.InfoData[0] = 1 THEN
               _Length := 3 + 9;
            ELSE // for safety
               _Length := 3 + 4;
            END;
         // safety, 7 bytes is the shortest packet, return the length
         ELSE
            _Length := 3 + 4;
         END;
      END;
   END DetermineLengthAndShift;

(*---------------------------------------------------------------------------*)

BEGIN
   _PacketType := ptUnknown;
   _Packet := NIL;
   _Shifted := FALSE;
   _Length := 0;
END CPacket;

(*===========================================================================*)

TYPE
   TPArea = POINTER TO CArea;

CLASS CArea;
   LOCAL VAR
      Description : StringsO.CString;
      Partitions : bitarray.CBitArray;
      Armed : bitarray.CBitArray;
      Alarm : bitarray.CBitArray;
      Outputs : bitarray.CBitArray;
      ScanForAlarm : BOOLEAN;

      Operation : TPacketType; // temporary
      Password : StringsO.CString; // temporary
END CArea; // CArea

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CArea;
BEGIN
   Partitions.Size := PARTITIONS;
   Armed.Size := PARTITIONS;
   Alarm.Size := PARTITIONS;
   Outputs.Size := OUTPUTS;
   ScanForAlarm := TRUE;
   Operation := ptUnknown;
END CArea;

(*================================================================================*)

CLASS IMPLEMENTATION CNS;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE HashToName( CONST Hash : ns.THash; OUT Name : StringsO.IString ) : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END HashToName;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE CreateRoot() : ns.TPnsItem;
   BEGIN
      RETURN CreateNewItem( L"Integra", ns.ntName, iovalue.vtString, 0 );
   END CreateRoot;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE CreateStructure();
   BEGIN
      Root^.AddChild( CreateNewItem( L"Control", ns.ntName, iovalue.vtString, 0 ));

      DataRoot := nsitem.TPnsItem( CreateNewItem( L"Data", ns.ntName, iovalue.vtString, 0 ));
      Root^.AddChild( DataRoot );
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

CLASS IMPLEMENTATION CDeviceAutomaton;
      
(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Running GET : BOOLEAN;
   BEGIN
      RETURN _Running;
   END Running;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Start() : Sync.TAsyncResult;
   VAR
      al : Sync.AutoLock;
   BEGIN
      IF _Running THEN
         RETURN Sync.arAlreadyPending;
      END;

      al.TakeSafe( REF _Lock, L"Unable to lock automaton (start)" );
      _Running := TRUE;

      RETURN Sync.arCompleted;
   END Start;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Stop();
   VAR
      al : Sync.AutoLock;
   BEGIN
      al.TakeSafe( REF _Lock, L"Unable to lock automaton (stop)" );
      _Running := FALSE;
   END Stop;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( REF Driven : IAutomatonRequest );
   BEGIN
      _Driven := ADR( Driven );
   END Init;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE EventAbort();
   VAR
      al : Sync.AutoLock;
   BEGIN
      al.TakeSafe( REF _Lock, L"Unable to lock automaton (abort)" );
   END EventAbort;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE EventInfo( Packet : TPPacket );
   VAR
      al : Sync.AutoLock;
   BEGIN
      al.TakeSafe( REF _Lock, L"Unable to lock automaton (info)" );
      _Driven^.OnData( Packet );
   END EventInfo;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE EventWrite( ItemToWrite : nsitem.TPnsItem ) : Sync.TAsyncResult;
   VAR
      al : Sync.AutoLock;
   BEGIN
      al.TakeSafe( REF _Lock, L"Unable to lock automaton (write)" );

      _Driven^.SendData( ItemToWrite );
      _Driven^.Sent( Sync.arCompleted, ItemToWrite );

      RETURN Sync.arCompleted;
   END EventWrite;

(*---------------------------------------------------------------------------*)

BEGIN
   _Driven := NIL;
FINALLY
   Stop();
END CDeviceAutomaton;

(*===========================================================================*)

CLASS IMPLEMENTATION CDeviceCommunicator;

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

      _LastReceiveTime := datetime.UptimeMS();
      StartTimeout( CONNECTION_CHECK_TIMEOUT, FALSE, REF _ConnectionTimeoutHandle );

      Logger.LogS( log.ldMessage, 0, LOG_NAME, L"Started" );

      RETURN Connection.OpenS( _HostAddress, DEFAULT_PORT, TRUE, 500 );
   END Start;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Stop();
   BEGIN
      IF NOT _Running THEN
         RETURN;
      END;
      _Running := FALSE;

      _PoolDelegate.TimeoutSink := NIL;
   
      StopTimeout( REF _ConnectionTimeoutHandle );

      Connection.Close();
      Logger.LogS( log.ldMessage, 0, LOG_NAME, L"Stopped" );
   END Stop;

(*---------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnTimeout( Result : Sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR );
   BEGIN
      IF PoolHandle = _ConnectionTimeoutHandle THEN
         IF NOT Connection.Connected THEN
            Logger.LogS( log.ldTrace, 0, LOG_NAME, L"Disconnected (periodic check), trying to reconnect" );
            Connection.OpenS( _HostAddress, DEFAULT_PORT, TRUE, 500 );
         ELSIF datetime.UptimeMS() - _LastReceiveTime >= CONNECTION_CHECK_TIMEOUT THEN
            Logger.LogS( log.ldTrace, 0, LOG_NAME, L"Disconnected (no data received for a long time), trying to reconnect" );
            Connection.Close();
            Connection.OpenS( _HostAddress, DEFAULT_PORT, TRUE, 500 );
         END;

      END;
   END OnTimeout;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnData( Packet : TPPacket );
   BEGIN
      PIO^.OnRx( Sync.arCompleted, Packet );
   END OnData;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE SendData( ItemToSend : nsitem.TPnsItem );
   VAR
      area : TPArea := ItemToSend^.Data;
      i, len : CARDINAL;
      mask : BYTE;
      Packet : TWirePacket;
      shift : CARDINAL;
      Wrapper : CPacket;
   BEGIN
      Packet.ArmSync1 := 0;
      Wrapper.EmptyPacket := ADR( Packet );
      Wrapper.PacketType := area^.Operation;

      Storage.Fill( ADR( Packet.ArmCode ), SIZE( Packet.ArmCode ), 0AAH );
      len := MIN2( 16, area^.Password.Length );
      shift := 4; mask := 0FH;
      FOR i := 0 TO len-1 DO
         IF ( area^.Password[i] < L'0' ) OR ( area^.Password[i] > L'9' ) THEN
            Logger.LogSS( log.ldError, 0, LOG_NAME, L"Unexpected character in the password, replacing with 0: ", OA( area^.Password.Length-1, area^.Password.Data ));
            Packet.ArmCode[i DIV 2] := Packet.ArmCode[i DIV 2] AND mask;
         ELSE
            Packet.ArmCode[i DIV 2] := ( Packet.ArmCode[i DIV 2] AND mask ) OR (( ORD( area^.Password[i] ) - ORD( L'0' )) << shift );
         END;
         IF shift = 4 THEN
            shift := 0; mask := 0F0H;
         ELSE
            shift := 4; mask := 00FH;
         END;
      END; // FOR
      IF area^.Operation = ptArm THEN
         Packet.ArmMode := 0;
         area^.Partitions.ToOA( 0, OUT Packet.ArmPartitions, OUT len );

         Logger.LogSCB( log.ldTrace, 0, LOG_NAME, L"Armed partitions: ", SIZE( Packet.ArmPartitions ), ADR( Packet.ArmPartitions ), SIZE( Packet.ArmPartitions ));
      ELSE
         area^.Partitions.ToOA( 0, OUT Packet.DisarmPartitions, OUT len );

         Logger.LogSCB( log.ldTrace, 0, LOG_NAME, L"Disarmed partitions: ", SIZE( Packet.DisarmPartitions ), ADR( Packet.DisarmPartitions ), SIZE( Packet.DisarmPartitions ));
      END;

      Tx( OA( Wrapper.Length-1, Wrapper.Packet ));
   END SendData;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Sent( Result : Sync.TAsyncResult; SentItem : nsitem.TPnsItem );
   BEGIN
      PIO^.OnTxCON( Result );
   END Sent;

(*---------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnConnect( Result : CARDINAL; CONST Socket : netsocket.TPDSocket; Local : BOOLEAN ); 
   BEGIN
      IF Result = 0 THEN
         Connection.BufferedStream^.StartReading();
      END;
   END OnConnect;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnReadable( Length : CARDINAL; Source : ADDRESS );
   VAR
      Data : StorageO.CMemoryBuffer;
   BEGIN
      Connection.BufferedStream^.ReadBuffer( 2048, REF Data, 0 );
      HandleRx( Sync.arCompleted, REF Data );

      Connection.BufferedStream^.StartReading();
   END OnReadable;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE DetectDataStart( CONST Data : StorageO.AMemoryBuffer; OUT FirstIndexOfFrame, FirstIndexOfData : CARDINAL ) : BOOLEAN;
   VAR
      candidate : CARDINAL := -1;
      dataByte : CARD8;
      i : CARDINAL := 0;
      l : CARDINAL := Data.Length;
   BEGIN
      WHILE i < l DO
         TRY
            dataByte := CARD8( Data[i] ); // ch in CASE is not handled correctly by CASE
            IF ( dataByte = B_INTERLEAVE_1 ) OR ( dataByte = B_INTERLEAVE_2 ) THEN
               candidate := i;
            ELSIF candidate = -1 THEN
               // no candidate found yet, continue scanning (for consecutive leading bytes)
            ELSE
               FirstIndexOfFrame := candidate;
               FirstIndexOfData := candidate;
               RETURN TRUE;
            END; // CASE
         CATCH e : CModula2Exception DO
            RETURN FALSE;
         END;

         INC( i );
      END; // WHILE

      RETURN FALSE;
   END DetectDataStart;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE DataComplete( CONST Data : StorageO.AMemoryBuffer; OUT FirstIndexAfterData, FirstIndexAfterFrame : CARDINAL; OUT ApplyCheckSum : BOOLEAN ) : BOOLEAN;
   VAR
      Wrapper : CPacket;
   BEGIN
      IF Data.Length < 1 THEN
         RETURN FALSE;
      ELSE
         Wrapper.FilledPacket := Data.Data;
         RETURN Wrapper.Complete( Data.Length, OUT FirstIndexAfterData, OUT FirstIndexAfterFrame, OUT ApplyCheckSum );
      END;
   END DataComplete;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE TestChkSum( CONST Data : StorageO.AMemoryBuffer ) : BOOLEAN;
   VAR
      Wrapper : CPacket;
   BEGIN
      Wrapper.FilledPacket := Data.Data;
      RETURN Wrapper.TestCheckSum();
   END TestChkSum;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnRx( Result : Sync.TAsyncResult; CONST Data : StorageO.AMemoryBuffer );
   VAR
      Wrapper : CPacket;
   BEGIN
      IF Result = Sync.arCompleted THEN
         _LastReceiveTime := datetime.UptimeMS();

         Wrapper.FilledPacket := Data.Data;
         CASE Wrapper.PacketType OF
         | ptInfo :
            Automaton^.EventInfo( ADR( Wrapper ));
         ELSE
            ASSERTLOG( FALSE );
         END;
      END;
   END OnRx;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE AddChkSum( REF Data : StorageO.AMemoryBuffer );
   VAR
      Wrapper : CPacket;
   BEGIN
      Wrapper.FilledPacket := Data.Data;
      Wrapper.ComputeCheckSum();
   END AddChkSum;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Configure( CONST iniFile : INIFile.CINIFile; CONST iniFileSection : StringsO.IString; CONST Log : log.TPLogger ) : Sync.TAsyncResult;
   CONST
      keyAreas = L"areas";
      keyHost = L"host";
      keyScanForAlarm = L"scan_for_alarm";
      keyPartitions = L"partitions";
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
      PARTITION_SPLITTER = StringsO.WCHARS{ L"," };
      PARTITION_INTERVAL = L"..";
   VAR
      area : TPArea;
      es : PTR;
      i, j, l : CARDINAL;
      key, value : StringsO.CString;
      partitionFrom : CARDINAL;
      partitionTo : CARDINAL;
      partitionFromString : StringsO.CString;
      partitionToString : StringsO.CString;
   BEGIN
      Dispose();

      IF iniFile.SetSection( OA( iniFileSection.Length-1, iniFileSection.Data )) THEN
         // TODO: does ConfigureLog dispose _AppenderList ???
         LogConfig.ConfigureLog( iniFile, OA( iniFileSection.Length-1, iniFileSection.Data ), REF Logger, REF _AppenderList, OUT l );

         // load host to connect to
         IF NOT iniFile.GetKeyStr( keyHost, OUT l, OUT _HostAddress ) THEN
            LogError( TRUE, l, Texts._HostKeyMissing, NIL );
         END;

         // load areas name
         IF NOT iniFile.GetKeyStr( keyAreas, OUT l, OUT value ) THEN
            LogError( TRUE, l, Texts._AreasKeyMissing, NIL );
         END;

         // load areas
         IF NOT iniFile.SetSection( OA( value.Length-1, value.Data )) THEN
            LogError( TRUE, 0, Texts._AreasSectionMissing, ADR( value ));
         ELSE
            es := NIL;
            WHILE iniFile.EnumerateKeys( REF es, OUT l, OUT key, OUT value ) DO
               IF AreaList.Contains( key ) THEN
                  LogError( TRUE, l, Texts._AreaAlreadyKnown, ADR( key ));
               ELSE // not known area found

                  area := NEW( CArea );
                  area^.Description := value;
                  AreaList.Add( key, area );

               END;
            END;
         END;

         // load configuration of particular areas
         AreaList.Reset();
         WHILE AreaList.MoveNext() DO
            IF NOT iniFile.SetSection( OA( AreaList.Current^.Length-1, AreaList.Current^.Data )) THEN
               LogError( TRUE, l, Texts._AreaNotFound, AreaList.Current );
               CONTINUE;
            END;
               
            area := AreaList.CurrentData;
            iniFile.GetKeyBool( keyScanForAlarm, OUT l, OUT area^.ScanForAlarm );

            IF NOT iniFile.GetKeyStr( keyPartitions, OUT l, OUT value ) THEN
               LogError( TRUE, l, Texts._PartitionsKeyMissing, AreaList.Current );
               CONTINUE;
            END;

            // parse partitions -- a list separated by comas, containing either number or an interval (..), no partition can be greater than 32
            i := 0;
            LOOP
               i := value.ItemS( PARTITION_SPLITTER, i, 0, FALSE, OUT partitionFromString );
               IF i = -1 THEN
                  EXIT;
               ELSIF partitionFromString.Empty THEN
                  LogError( FALSE, i, Texts._PartitionUndefined, NIL );
                  CONTINUE;
               END;
                  
               // detect interval
               j := partitionFromString.IndexOfOA( PARTITION_INTERVAL, 0 );
               IF j = -1 THEN
                  partitionToString.Clear();
               ELSE
                  partitionFromString.Substring( j+2, -1, OUT partitionToString );
                  IF partitionToString.Empty THEN
                     LogError( TRUE, l, Texts._UpperBoundaryOfPartitionIntervalIsMissing, ADR( partitionFromString ));
                     CONTINUE;
                  END;
                  partitionToString.Trim();
                  partitionFromString.Length := j; // trim
               END;
               partitionFromString.Trim();

               IF NOT partitionFromString.ToCARD32( 10, OUT partitionFrom ) THEN
                  LogError( TRUE, l, Texts._UnableToConvertPartitionFrom, ADR( partitionFromString ));
                  CONTINUE;
               ELSIF ( partitionFrom < 1 ) OR ( partitionFrom > PARTITIONS ) THEN
                  LogError( TRUE, l, Texts._PartitionFromOutOfScope, ADR( partitionFromString ));
                  CONTINUE;
               END;
               IF partitionToString.Empty THEN
                  partitionTo := partitionFrom;
               ELSIF NOT partitionToString.ToCARD32( 10, OUT partitionTo ) THEN
                  LogError( TRUE, l, Texts._UnableToConvertPartitionTo, ADR( partitionToString ));
                  CONTINUE;
               ELSIF ( partitionTo < 1 ) OR ( partitionTo > PARTITIONS ) THEN
                  LogError( TRUE, l, Texts._PartitionToOutOfScope, ADR( partitionToString ));
                  CONTINUE;
               END;

               // include found partititions to the element
               FOR j := partitionFrom TO partitionTo DO
                  area^.Partitions.Incl( j-1 );
               END;
            END; // parsing loop
               
         END; // WHILE

      ELSE
         LogError( TRUE, 0, Texts._ConfigurationSectionMissing, ADR( iniFileSection ));
      END;
      RETURN Result;
   END Configure;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Dispose();
   VAR
      area : TPArea;
   BEGIN
      LogConfig.DisposeAppenderList( REF _AppenderList );

      AreaList.Reset();
      WHILE AreaList.MoveNext() DO
         area := AreaList.CurrentData;
         DISPOSE( area );
      END; // WHILE
      AreaList.Dispose();
   END Dispose;

(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Tx( CONST Data : ARRAY OF BYTE );
   VAR
      c : CARDINAL;
      Result : Sync.TAsyncResult;
      TxBuffer : StorageO.CMemoryBuffer;
   BEGIN
      IF NOT Connection.Connected THEN
         Logger.LogS( log.ldTrace, 0, LOG_NAME, L"Disconnected, trying to reconnect" );
         Connection.OpenS( _HostAddress, DEFAULT_PORT, TRUE, 500 );
      END;
   
      IF HIGH( Data ) >= 0 THEN // HACK
         TxBuffer.Size := 1024;
         TxBuffer.AppendOA( Data );
         AddChkSum( REF TxBuffer );
      END;
      
      Logger.LogSCB( log.ldDebug, 0, LOG_NAME, L'tx start of ', TxBuffer.Length, TxBuffer.Data, TxBuffer.Length );
      Result := Connection.BufferedStream^.WriteBuffer( TxBuffer, OUT c, netsocket.FORSAFETY );
      IF Result = Sync.arTimeout THEN
         ASSERTLOG( FALSE );
      END;
   END Tx;

//---------------------------------------------------------

   PUBLIC PROCEDURE Abort();
   BEGIN
      Automaton^.EventAbort();
      Connection.BufferedStream^.AbortWriting();
   END Abort;

//---------------------------------------------------------

   PRIVATE PROCEDURE HandleRx( Result : Sync.TAsyncResult; REF Data : StorageO.AMemoryBuffer );
   VAR
      LDI, LI : CARDINAL := 0;
      LRxBuffer : StorageO.CMemoryBuffer;
      TDI, TI : CARDINAL;
      ApplyChecksum : BOOLEAN; // apply checksum
      ChkSumOK : BOOLEAN := TRUE;
   BEGIN
      IF Result <> Sync.arCompleted THEN
         Logger.LogSC( log.ldError, 0, LOG_NAME, L'rx error: ', CARDINAL( Result ));
         OnRx( Result, LRxBuffer );
         RxBuffer.Clear();
         RETURN;
      ELSIF NOT Data.Empty THEN
         RxBuffer.Append( Data );
         Logger.LogSCB( log.ldDebug, 0, LOG_NAME, L'rx success, len: ', Data.Length, Data.Data, Data.Length );
      END;

      LOOP
         IF NOT DetectDataStart( RxBuffer, OUT LI, OUT LDI ) THEN
            RxBuffer.Clear();
            RETURN;
         ELSIF LI > 0 THEN
            RxBuffer.RemoveStart( LI );
            DEC( LDI, LI );
            LI := 0;
         END;

         IF NOT DataComplete( RxBuffer, OUT TDI, OUT TI, OUT ApplyChecksum ) THEN
            RETURN;
         END;

         IF ApplyChecksum THEN
            RxBuffer.Subbuffer( LI, TI - LI, OUT LRxBuffer );
            ChkSumOK := TestChkSum( LRxBuffer );
         END;
         IF ChkSumOK THEN
            RxBuffer.Subbuffer( LDI, TDI - LDI, OUT LRxBuffer );
            OnRx( Result, LRxBuffer );
         END;

         IF RxBuffer.Length = TI THEN
            RxBuffer.Clear();
            RETURN;
         ELSE
            RxBuffer.RemoveStart( TI );
         END;
      END; // LOOP
   END HandleRx;

//---------------------------------------------------------

   PRIVATE PROCEDURE StartTimeout( TimeoutMS : CARDINAL; WaitOnce : BOOLEAN; REF Handle : threadpool.TPoolHandle );
   BEGIN
      ASSERTLOG( Handle = NIL );
      threadpool.pool()^.WaitTimeout( ADR( _PoolDelegate ), 0, TimeoutMS, WaitOnce, FALSE, OUT Handle );
   END StartTimeout;

//---------------------------------------------------------

   PRIVATE PROCEDURE StopTimeout( REF Handle : threadpool.TPoolHandle );
   BEGIN
      IF Handle = NIL THEN
         RETURN;
      END;
      threadpool.pool()^.Abort( REF Handle );
   END StopTimeout;

//---------------------------------------------------------

BEGIN
   Connection.Notifier := ADR( SELF );
   PIO := NIL;
   Automaton := NIL;
   _LastReceiveTime := 0;
   _ConnectionTimeoutHandle := NIL;
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
      RETURN DeviceAutomaton.Running;
   END Running;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Start() : Sync.TAsyncResult;
   BEGIN
      DeviceAutomaton.Start();
      RETURN DeviceCommunicator.Start();
   END Start;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Stop();
   BEGIN
      DeviceCommunicator.Stop();
      DeviceAutomaton.Stop();
   END Stop;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY IOCapabilities GET : io.TCapabilities;
   BEGIN
      RETURN io.TCapabilities{};
   END IOCapabilities;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Pending GET : BOOLEAN;
   BEGIN
      RETURN _Pending <> IOO.dirUnknown;
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
      area : TPArea;
      item : nsitem.TPnsItem;
      Result : Sync.TAsyncResult := Sync.arCompleted;
   BEGIN
      IF Direction = IOO.dirRead THEN // get data immediatelly

         item := nsitem.TPnsItem( Item );
         IF ( item^.NameType <> ns.ntValue ) OR ( item^.ValueType = iovalue.vtString ) THEN
            RETURN Sync.arCannotStart;
         END;

         al.TakeSafe( REF _Lock, L"Unable to lock data area" );

         area := item^.Data;
         IF item^.Name^.EndsWithOA( ALARM_SUFFIX ) THEN
            Value.Boolean := area^.Alarm.Count > 0;
         ELSIF item^.Name^.EndsWithOA( ARMED_SUFFIX ) THEN
            Value.Boolean := area^.Armed.Count > 0;
         ELSE
            Value.Boolean := area^.Outputs.Count > 0;
         END;
         DeviceCommunicator.Logger.LogSSC( log.ldTrace, 0, LOG_NAME, L"Item read: ", OA( item^.Name^.Length-1, item^.Name^.Data ), CARDINAL( Value.Boolean ));

         Delegate^.OnIO( IOO.dirRead, ADR( SELF ), OA( 0, ADR( Result )), OA( 0, ADR( Item )), OA( -1, NIL ), OA( 0, ADR( Value )));
         
         RETURN Sync.arCompleted;
      ELSE
         item := nsitem.TPnsItem( Item );
         IF ( item^.NameType <> ns.ntValue ) OR ( item^.ValueType <> iovalue.vtString ) THEN
            RETURN Sync.arCannotStart;
         END;

         _Pending := Direction;
         _Item := Item;
         _Callback := Delegate;

         al.TakeSafe( REF _Lock, L"Unable to lock data area" );

         area := item^.Data;
         area^.Password := Value.String;
         DeviceCommunicator.Logger.LogSSS( log.ldTrace, 0, LOG_NAME, L"Item write: ", OA( item^.Name^.Length-1, item^.Name^.Data ), OA( area^.Password.Length-1, area^.Password.Data ));
         IF item^.Name^.EndsWithOA( DISARM_SUFFIX ) THEN
            area^.Operation := ptDisarm;
         ELSE
            area^.Operation := ptArm;
         END;

         DeviceAutomaton.EventWrite( _Item );

         RETURN Sync.arPending;
      END;
   END IOh;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE AbortAll();
   BEGIN
      DeviceCommunicator.Abort();
   END AbortAll;

(*---------------------------------------------------------------------------*)

   LOCAL PROCEDURE OnRx( Result : Sync.TAsyncResult; PPacket : TPPacket );
   VAR
      al : Sync.AutoLock;
      area : TPArea;
      ba : bitarray.CBitArray;
      data : PBYTE;
      i : INTEGER;
   BEGIN
      IF Result <> Sync.arCompleted THEN
         RETURN;
      END;

      // prepare value
      CASE PPacket^.PacketType OF
      | ptInfo :
      ELSE
         ASSERTLOG( FALSE );
         RETURN;
      END;

      // other useful can be itArmedPartitions
      CASE PPacket^.Packet^.InfoDataType OF
      | itPartArmed :
         IF NOT PPacket^.Shifted THEN // only really armed partitions are important
            RETURN;
         END;
      | itPartAlarm,
        itPartAlarmMemory,
        itOutputsState : // 8 bytes
      ELSE
         RETURN; // event ignored
      END;
      data := ADR( PPacket^.Packet^.InfoData );
      DeviceCommunicator.Logger.LogSH( log.ldTrace, 0, LOG_NAME, L"Received info type: 0x", CARDINAL( PPacket^.Packet^.InfoDataType ));

      al.TakeSafe( REF _Lock, L"Unable to lock data area" );

      CASE PPacket^.Packet^.InfoDataType OF
      | itPartArmed :
         FOR i := 0 TO DataRoot^.Count-1 DO
            area := DataRoot^[i]^.Data;
            area^.Armed.FromOA( 0, OA( 3, data ));
            area^.Armed.And( area^.Partitions );
         END; // FOR
      | itPartAlarm, itPartAlarmMemory : // these two sources are ORed
         FOR i := 0 TO DataRoot^.Count-1 DO
            area := DataRoot^[i]^.Data;
            IF area^.ScanForAlarm THEN
               ba.FromOA( 0, OA( 3, data ));
               area^.Alarm.Or( ba );
               area^.Alarm.And( area^.Partitions );
            END;
         END; // FOR
      | itOutputsState : // 8 bytes
         FOR i := 0 TO DataRoot^.Count-1 DO
            area := DataRoot^[i]^.Data;
            area^.Outputs.FromOA( 0, OA( 7, data ));
         END; // FOR
      END;

   END OnRx;

(*---------------------------------------------------------------------------*)

   LOCAL PROCEDURE OnTxCON( Result : Sync.TAsyncResult );
   VAR
      // no lock needed, OnTxCON is called synchronously
      // al : Sync.AutoLock;
      area : TPArea;
   BEGIN
      IF _AbortFlag THEN
         _AbortFlag := FALSE;
         _Pending := IOO.dirUnknown;
      ELSIF _Pending <> IOO.dirWrite THEN
         RETURN;

      ELSE
         _Pending := IOO.dirUnknown;
         IF Result = Sync.arCompleted THEN
            _Callback^.OnIO( IOO.dirWrite, ADR( SELF ), OA( 0, ADR( Result )), OA( 0, ADR( _Item )), OA( -1, NIL ), OA( 0, iovalue.TPValue( NIL )));
         ELSE
            _Callback^.OnIO( IOO.dirWrite, ADR( SELF ), OA( 0, ADR( Result )), OA( 0, ADR( _Item )), OA( -1, NIL ), OA( 0, iovalue.TPValue( NIL )));
            _Callback^.OnError( IOO.dirWrite, ADR( SELF ), OA( 0, ADR( Result )), OA( 0, ADR( _Item )), OA( -1, NIL ));
         END;
      END;

      // no lock needed, OnTxCON is called synchronously
      // al.TakeSafe( REF _Lock, L"Unable to lock data area" );

      area := _Item^.Data;
      area^.Password.Clear();
      area^.Operation := ptUnknown;

      _Item := NIL;
   END OnTxCON;

(*---------------------------------------------------------------------------*)

BEGIN
   DeviceCommunicator.PIO := ADR( SELF );
   DeviceCommunicator.Automaton := ADR( DeviceAutomaton );
   DeviceAutomaton.Init( REF DeviceCommunicator );
   DataRoot := NIL;
   _AbortFlag := FALSE;
   _Pending := IOO.dirUnknown;
   _Callback := NIL;
   _Item := NIL;
FINALLY
   Dispose();
END CIO;

(*===========================================================================*)

CLASS IMPLEMENTATION CIntegraDevice;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   BEGIN
      // _NS.Dispose();
      _IO.Stop();
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
      IF Result = Sync.arCompleted THEN
         FillNsWithLoadedConfiguration();
      END;

      RETURN Result;
   END Configure;
   
(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE FillNsWithLoadedConfiguration();
   VAR
      area : TPArea;
      I : ns.TPnsItem;
      list : lists.TPStringList := ADR( _IO.DeviceCommunicator.AreaList );
      name, s : StringsO.CString;
   BEGIN
      // _NS.Dispose(); -- possible leak?
      _NS.Initialize();
      _IO.DataRoot := _NS.DataRoot;

      list^.Reset();
      WHILE list^.MoveNext() DO
         area := list^.CurrentData;
         name.Assign( list^.Current^ );

         s := name; s.AppendOA( ARM_SUFFIX );
         I := _NS.CreateNewItem( OA( s.Length-1, s.Data ), ns.ntValue, iovalue.vtString, area ); _NS.DataRoot^.AddChild( I );

         s := name; s.AppendOA( DISARM_SUFFIX );
         I := _NS.CreateNewItem( OA( s.Length-1, s.Data ), ns.ntValue, iovalue.vtString, area ); _NS.DataRoot^.AddChild( I );

         s := name; s.AppendOA( ARMED_SUFFIX );
         I := _NS.CreateNewItem( OA( s.Length-1, s.Data ), ns.ntValue, iovalue.vtBoolean, area ); _NS.DataRoot^.AddChild( I );

         s := name; s.AppendOA( ALARM_SUFFIX );
         I := _NS.CreateNewItem( OA( s.Length-1, s.Data ), ns.ntValue, iovalue.vtBoolean, area ); _NS.DataRoot^.AddChild( I );

         s := name; s.AppendOA( OUTPUTS_SUFFIX );
         I := _NS.CreateNewItem( OA( s.Length-1, s.Data ), ns.ntValue, iovalue.vtBoolean, area ); _NS.DataRoot^.AddChild( I );
      END; // WHILE
   END FillNsWithLoadedConfiguration;

(*---------------------------------------------------------------------------*)

END CIntegraDevice;

(*===========================================================================*)

BEGIN
   R.LoadRES2( EMIT( %dll ), L"Integra.Texts" );
END Integra.
