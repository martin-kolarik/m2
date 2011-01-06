IMPLEMENTATION MODULE Integra;

(*================================================================================*)

FROM Debug IMPORT
   Assertion, LogAssertionW;
   
FROM Exceptions IMPORT
   TestIfCatched, RetrieveException, CModula2Exception;

IMPORT
   datetime,
   FIO,
   iobject,
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
   Log;

(*================================================================================*)

VAR
   R : resources.CResources;

(*================================================================================*)

CONST
   DEFAULT_PORT = 10001;
   CONNECTION_CHECK_TIMEOUT = 10000; // 10 second

CONST
   B_SYNCHRONIZE  = 0FFH;
   B_INTERLEAVE_1 = 0FFH;
   B_INTERLEAVE_2 = 0FEH;

#save, option( pack => 1 )
TYPE
   TPacketType = (
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
      itArmedPartitions    = 012H,
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
                    ArmZones : ARRAY [0..3] OF BYTE;
                    ArmMode : BYTE;
                    ArmCRC : BYTE;
                 //-----
                 | ptDisarm :
                    DisarmSync1 : BYTE;
                    DisarmSync2 : BYTE;
                    DisarmDataType : TPacketType;
                    DisarmCode : ARRAY [0..7] OF BYTE;
                    DisarmZones : ARRAY [0..3] OF BYTE;
                    DisarmCRC : BYTE;
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
      CASE _PacketType OF
      | ptArm, ptDisarm :
         chksumFrom := 2;
         chksumOffset := FIELDOFS( TWirePacket.ArmCRC );
      ELSE
         ASSERTLOG( FALSE );
         RETURN;
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
      | ptDisarm :
         _Packet^.DisarmSync1 := B_SYNCHRONIZE;
         _Packet^.DisarmSync2 := B_SYNCHRONIZE;
         _Packet^.DisarmDataType := ptDisarm;
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
         _Length := FIELDOFS( TWirePacket.ArmCRC ) + SIZE( TWirePacket.ArmCRC );
      | ptDisarm :
         _Length := FIELDOFS( TWirePacket.DisarmCRC ) + SIZE( TWirePacket.DisarmCRC );
      | ptInfo :
         CASE _Packet^.InfoDataType OF
         // fixed lengths
         | itDateTime:
            _Length := 3 + 7;
         | itOutputsState:
            _Length := 3 + 9;
         // variable lengths
         | itViolation1, itViolation2, itTamper1, itTamper2, itAlarm1, itAlarm2, itTamperAlarm1, itTamperAlarm2, itAlarmMemory1, itAlarmMemory2, itTamperAlarmMemory1, itTamperAlarmMemory2,
           itBypasses1, itBypasses2, itNoViolation1, itNoViolation2, itLongViolation1, itLongViolation2, itArmedPartitions, itPartEntry, itPartExit1, itPartExit2, itPartAlarm, itPartFire,
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
   VAR
     I : ns.TPnsItem;
   BEGIN
      Root^.AddChild( CreateNewItem( L"Control", ns.ntName, iovalue.vtString, 0 ));

      DataRoot := nsitem.TPnsItem( CreateNewItem( L"Data", ns.ntName, iovalue.vtString, 0 ));
      Root^.AddChild( DataRoot );

      I := CreateNewItem( L"Humidity",    ns.ntValue, iovalue.vtFloat, 0 ); DataRoot^.AddChild( I );
      I := CreateNewItem( L"Temperature", ns.ntValue, iovalue.vtFloat, 0 ); DataRoot^.AddChild( I );

      I := CreateNewItem( L"Humidity setpoint",    ns.ntValue, iovalue.vtFloat, 0 ); DataRoot^.AddChild( I );
      I := CreateNewItem( L"Temperature setpoint", ns.ntValue, iovalue.vtFloat, 0 ); DataRoot^.AddChild( I );

      I := CreateNewItem( L"Temperature (bath) setpoint", ns.ntValue, iovalue.vtFloat, 0 ); DataRoot^.AddChild( I );
      I := CreateNewItem( L"Temperature (party) setpoint", ns.ntValue, iovalue.vtFloat, 0 ); DataRoot^.AddChild( I );
      I := CreateNewItem( L"Temperature (standby) setpoint", ns.ntValue, iovalue.vtFloat, 0 ); DataRoot^.AddChild( I );

      I := CreateNewItem( L"Humidity (bath) setpoint", ns.ntValue, iovalue.vtFloat, 0 ); DataRoot^.AddChild( I );
      I := CreateNewItem( L"Humidity (party) setpoint", ns.ntValue, iovalue.vtFloat, 0 ); DataRoot^.AddChild( I );
      I := CreateNewItem( L"Humidity (standby) setpoint", ns.ntValue, iovalue.vtFloat, 0 ); DataRoot^.AddChild( I );
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
      State := tasIdle;

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
      State := tasIdle;
      _ItemToWrite := NIL;
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
      IF _ItemToWrite <> NIL THEN
         RETURN Sync.arAlreadyPending;
      END;

      _ItemToWrite := ItemToWrite;
      State := tasWaitWrite;
      _Driven^.SendData( _ItemToWrite );
      State := tasIdle;
      _Driven^.Sent( Sync.arCompleted, _ItemToWrite );
      _ItemToWrite := NIL;

      RETURN Sync.arCompleted;
   END EventWrite;

(*---------------------------------------------------------------------------*)

   PRIVATE PROPERTY State GET : TAutomatonState;
   BEGIN
      RETURN _State;
   END State;

(*---------------------------------------------------------------------------*)

   PRIVATE PROPERTY State SET( Value : TAutomatonState );
   BEGIN
      _State := Value;
   END State;

(*---------------------------------------------------------------------------*)

BEGIN
   _State := tasIdle;
   _Driven := NIL;
   _ItemToWrite := NIL;
FINALLY
   Stop();
END CDeviceAutomaton;

(*===========================================================================*)

CLASS IMPLEMENTATION CDeviceCommunicator;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Running GET : BOOLEAN;
   BEGIN
      RETURN Connection.Connected;
   END Running;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Start() : Sync.TAsyncResult;
   BEGIN
      _PoolDelegate.TimeoutSink := ADR( SELF );

      _LastReceiveTime := datetime.UptimeMS();
      StartTimeout( CONNECTION_CHECK_TIMEOUT, FALSE, REF _ConnectionTimeoutHandle );

      Logger.LogS( log.ldMessage, 0, L"Integra", L"Started" );

      RETURN Connection.OpenS( _HostAddress, DEFAULT_PORT, TRUE, 500 );
   END Start;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Stop();
   BEGIN
      _PoolDelegate.TimeoutSink := NIL;
   
      StopTimeout( REF _ConnectionTimeoutHandle );

      Connection.Close();
      Logger.LogS( log.ldMessage, 0, L"Integra", L"Stopped" );

      LogConfig.DisposeAppenderList( REF _AppenderList );
   END Stop;

(*---------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnTimeout( Result : Sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR );
   BEGIN
      IF PoolHandle = _ConnectionTimeoutHandle THEN
         IF NOT Connection.Connected THEN
            Logger.LogS( log.ldTrace, 0, L"Integra", L"Disconnected (periodic check), trying to reconnect" );
            Connection.OpenS( _HostAddress, DEFAULT_PORT, TRUE, 500 );
         ELSIF datetime.UptimeMS() - _LastReceiveTime >= CONNECTION_CHECK_TIMEOUT THEN
            Logger.LogS( log.ldTrace, 0, L"Integra", L"Disconnected (no data received for a long time), trying to reconnect" );
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
   BEGIN
   (*
   VAR
      Packet : TPacket;
      Wrapper : CPacket;
   BEGIN
      Packet.FIRST := 0C;
      Wrapper.EmptyPacket := ADR( Packet );
      Wrapper.PacketType := ptDataRequest;
      Wrapper.DeviceAddress := _DeviceAddress;
      Tx( OA( Wrapper.Length-1, Wrapper.Packet ), FALSE, 1, 150, 500 );
   *)
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
      keyHost = L"host";
   VAR
      Result : Sync.TAsyncResult := Sync.arCompleted;

      (*----------*)

      PROCEDURE LogError( line : CARDINAL; errorText : CARDINAL; CONST addonText : StringsO.TPString );
      VAR
         msg : StringsO.CString;
      BEGIN
         Result := Sync.arAborted;

         msg.FromOA( OAsz( R[errorText] ));
         IF addonText <> NIL THEN
            msg.Append( addonText^ );
         END;
         Log^.LogFilePos( log.lcError, 0, L"Integra", L"", OA( msg.Length-1, msg.Data ), line, 0 );
      END LogError;

      (*----------*)

   VAR
      l : CARDINAL;
   BEGIN
      IF iniFile.SetSection( OA( iniFileSection.Length-1, iniFileSection.Data )) THEN
         LogConfig.ConfigureLog( iniFile, OA( iniFileSection.Length-1, iniFileSection.Data ), REF Logger, REF _AppenderList, OUT l );
         IF NOT iniFile.GetKeyStr( keyHost, OUT l, OUT _HostAddress ) THEN
            LogError( l, Texts._HostKeyMissing, NIL );
         END;
      ELSE
         LogError( 0, Texts._ConfigurationSectionMissing, ADR( iniFileSection ));
      END;
      RETURN Result;
   END Configure;

(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Tx( CONST Data : ARRAY OF BYTE; _SendAsIs : BOOLEAN; _RepeatCount : CARDINAL );
   VAR
      c : CARDINAL;
      Result : Sync.TAsyncResult;
      TxBuffer : StorageO.CMemoryBuffer;
   BEGIN
      IF NOT Connection.Connected THEN
         Logger.LogS( log.ldTrace, 0, L"Integra", L"Disconnected, trying to reconnect" );
         Connection.OpenS( _HostAddress, DEFAULT_PORT, TRUE, 500 );
      END;
   
      IF INTEGER( HIGH( Data )) >= 0 THEN // HACK
         TxBuffer.Size := 1024;
         TxBuffer.AppendOA( Data );
         IF NOT _SendAsIs THEN
            AddChkSum( REF TxBuffer );
         END;
      END;
      
      Logger.LogSCB( log.ldDebug, 0, L"Integra", L'tx start of ', TxBuffer.Length, TxBuffer.Data, TxBuffer.Length );
      Result := Connection.Stream^.WriteBuffer( TxBuffer, OUT c, netsocket.FORSAFETY );
      IF Result = Sync.arTimeout THEN
         ASSERTLOG( FALSE );
      END;
   END Tx;

//---------------------------------------------------------

   PUBLIC PROCEDURE Abort();
   BEGIN
      Automaton^.EventAbort();
      Connection.Stream^.AbortWriting();
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
         Logger.LogSC( log.ldError, 0, L"Integra", L'rx error: ', CARDINAL( Result ));
         OnRx( Result, LRxBuffer );
         RxBuffer.Clear();
         RETURN;
      ELSIF NOT Data.Empty THEN
         RxBuffer.Append( Data );
         Logger.LogSCB( log.ldDebug, 0, L"Integra", L'rx success, len: ', Data.Length, Data.Data, Data.Length );
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
      Result : Sync.TAsyncResult := Sync.arCompleted;
   BEGIN
      IF Direction = IOO.dirRead THEN // get data immediatelly
         (*
         GetValueFromPtr( nsitem.TPnsItem( Item )^.Data, OUT Value );
         *)
         Delegate^.OnIO( IOO.dirRead, ADR( SELF ), OA( 0, ADR( Result )), OA( 0, ADR( Item )), OA( -1, NIL ), OA( 0, ADR( Value )));
         
         RETURN Sync.arCompleted;
      ELSE
         _Pending := Direction;
         _Item := Item;
         _Callback := Delegate;

         (*
         SetValueToPtr( REF nsitem.TPnsItem( Item )^.Data, Value );
         *)
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
      i : INTEGER;
   BEGIN
      IF Result = Sync.arCompleted THEN
         // prepare value
         CASE PPacket^.PacketType OF
         | ptInfo :
         ELSE
            ASSERTLOG( FALSE );
            RETURN;
         END;

DeviceCommunicator.Logger.LogSCC( log.ldDebug, 0, L"Integra", L'Received info: ', CARDINAL( PPacket^.Packet^.InfoDataType ), PPacket^.Length );
DeviceCommunicator.Logger.LogSC( log.ldDebug, 0, L"Integra", L'  shifted: ', CARDINAL( PPacket^.Shifted ));

         
         // lookup for item and set data to it
         (*
         FOR i := 0 TO DataRoot^.Count-1 DO
            IF ( GetValueIndexFromPtr( DataRoot^[i]^.Data ) = Wrapper.ValueIndex ) AND
               ( GetTypeFromPtr( DataRoot^[i]^.Data ) = Wrapper.ValueType ) THEN
               CASE Wrapper.ValueType OF
               | vtDigital :
                  SetPtrValueDigital( REF DataRoot^[i]^.Data, Wrapper.Digital );
               | vtInteger :
                  SetPtrValueInteger( REF DataRoot^[i]^.Data, Wrapper.Integer );
               | vtAnalog :
                  SetPtrValueAnalog( REF DataRoot^[i]^.Data, Wrapper.Analog );
               END; // CASE
               EXIT;
            END;
         END;
         *)
         
      END;
   END OnRx;

(*---------------------------------------------------------------------------*)

   LOCAL PROCEDURE OnTxCON( Result : Sync.TAsyncResult );
   BEGIN
      IF _AbortFlag THEN
         _AbortFlag := FALSE;
         _Pending := IOO.dirUnknown;
         RETURN;
      ELSIF _Pending <> IOO.dirWrite THEN
         RETURN;
      END;
      _Pending := IOO.dirUnknown;
      IF Result = Sync.arCompleted THEN
         _Callback^.OnIO( IOO.dirWrite, ADR( SELF ), OA( 0, ADR( Result )), OA( 0, ADR( _Item )), OA( -1, NIL ), OA( 0, iovalue.TPValue( NIL )));
      ELSE
         _Callback^.OnIO( IOO.dirWrite, ADR( SELF ), OA( 0, ADR( Result )), OA( 0, ADR( _Item )), OA( -1, NIL ), OA( 0, iovalue.TPValue( NIL )));
         _Callback^.OnError( IOO.dirWrite, ADR( SELF ), OA( 0, ADR( Result )), OA( 0, ADR( _Item )), OA( -1, NIL ));
      END;
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
      _IO.DataRoot := _NS.DataRoot;
      RETURN ADR( _IO );
   END IO;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Configure( CONST Source : ARRAY OF device.TConfigureItem; CONST Log : log.TPLogger ) : Sync.TAsyncResult;
   BEGIN
      IF HIGH( Source ) < 0 THEN
         RETURN Sync.arCannotStart;
      ELSIF Source[0].Type <> device.citINIFileSection THEN
         RETURN Sync.arCannotStart;
      END;
      RETURN _IO.DeviceCommunicator.Configure( Source[0]._iniFile^, Source[0].section^, Log );
   END Configure;
   
(*---------------------------------------------------------------------------*)

BEGIN FINALLY
   _IO.Stop();
   OnDispose();
END CIntegraDevice;

(*===========================================================================*)

BEGIN
   R.LoadRES2( EMIT( %dll ), L"Integra.Texts" );
END Integra.
