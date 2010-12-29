IMPLEMENTATION MODULE Integra;

(*================================================================================*)

FROM Debug IMPORT
   Assertion, LogAssertionW;
   
FROM Exceptions IMPORT
   TestIfCatched, RetrieveException, CModula2Exception;

IMPORT
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
   B_SYNCHRONIZE  = 0FFH;
   B_INTERLEAVE_1 = 0FFH;
   B_INTERLEAVE_2 = 0FEH;
   
   POLL_PERIOD_DEFAULT = 30000;

#save, option( pack => 1 )
TYPE
   TPacketType = (
      ptUnknown,
      ptArm,
      ptDisarm,
      ptInfo
   );
   
   TInfoType : BYTE = (
      itViolation1 = 0H,
      itViolation2 = 1H,
      itTamper1 = 2H,
      itTamper2 = 3H,
      itArm = 70H,
      itDisarm = 71H
   );
   
TYPE
  TPacket  = RECORD
                 CASE : TPacketType OF
                 //-----
                 | ptUnknown :
                 //-----
                 | ptArm :
                    ArmSync1 : BYTE;
                    ArmSync2 : BYTE;
                    ArmDataType : TDataType;
                    ArmCode : ARRAY [0..7] OF BYTE;
                    ArmZones : ARRAY [0..3] OF BYTE;
                    ArmMode : BYTE;
                    ArmCRC : BYTE;
                 //-----
                 | ptDisarm :
                    DisarmSync1 : BYTE;
                    DisarmSync2 : BYTE;
                    DisarmDataType : TDataType;
                    DisarmCode : ARRAY [0..7] OF BYTE;
                    DisarmZones : ARRAY [0..3] OF BYTE;
                    DisarmCRC : BYTE;
                 //-----
                 | ptInfo :
                    Interleave : BYTE;
                    InfoDataType : TDataType;
                    Data : ARRAY [0..3] OF BYTE;
                    Xor : BYTE;
                    InfoCRC : BYTE;
                 END; // CASE
              END; // RECORD
   TPPacket = POINTER TO TPacket;
#restore

CLASS CPacket; // class is wrapping some foreign data area
   PRIVATE VAR
      _PacketType : TPacketType;
      _Packet : TPPacket;

   PUBLIC PROPERTY
      PacketType : TPacketType;

   PUBLIC WRITEONLY PROPERTY
      EmptyPacket : TPPacket;
      FilledPacket : TPPacket;

   PUBLIC READONLY PROPERTY
      ValueType : TValueType;
      Packet : TPPacket;
      Length : CARDINAL;
      
   PUBLIC PROCEDURE ComputeCheckSum();
   PUBLIC PROCEDURE CheckSum() : BOOLEAN;
   PUBLIC PROCEDURE Complete( KnownLength : CARDINAL; OUT FirstIndexAfterData, FirstIndexAfterFrame : CARDINAL; OUT ApplyChecksum : BOOLEAN ) : BOOLEAN;

   PRIVATE PROCEDURE SetPacketBoundaries(); // _Packet MUST not be NIL
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
      END;
   END PacketType;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY EmptyPacket SET( Value : TPPacket );
   BEGIN
      _Packet := Value;
      IF _PacketType <> ptUnknown THEN
         SetPacketBoundaries();
      END;
   END EmptyPacket;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY FilledPacket SET( Value : TPPacket );
   BEGIN
      _Packet := Value;
      IF _Packet = NIL THEN
         RETURN;
      END;
      IF _Packet^.ArmSync2 = B_SYNCHRONIZE OF // differences in this byte are principal
         IF _Packet^.ArmDataType = itArm THEN
            _PacketType := ptArm;
         ELSIF _Packet^.ArmDataType = itDisarm THEN
            _PacketType := ptDisarm;
         ELSE
            ASSERT( FALSE );
            _Packet := NIL;
         END;
      ELSE // assume info
         _PacketType := ptInfo;
      END;
   END FilledPacket;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Packet GET : TPPacket;
   BEGIN
      RETURN _Packet;
   END Packet;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Length GET : CARDINAL;
   BEGIN
      IF _Packet = NIL THEN
         RETURN 0;
      END;
      CASE _PacketType OF
      | ptArm :
         RETURN 17;
      | ptDisarm :
         RETURN 17;
      | ptInfo :
         RETURN 8;
      ELSE
         RETURN 0;
      END;
   END Length;

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
         chksumOffset := FIELDOFS( TPacket.ArmCRC );
      | ptInfo :
         chksumFrom := 0;
         chksumOffset := FIELDOFS( TPacket.InfoCRC );
      ELSE
         RETURN;
      END;
      
      chksum := 0;
      FOR i := chksumFrom TO chksumOffset - 1 DO
         INC( chksum, PCARD8( _Packet@[i] )^ );
      END; // FOR

      PCARD8( _Packet@[chksumOffset] )^ := chksum;
   END ComputeCheckSum;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CheckSum() : BOOLEAN;
   VAR
      chksum : CARD8;
      chksumFrom : CARDINAL;
      chksumOffset : CARDINAL;
      chksumToCheck : CARD8;
      i : CARDINAL;
   BEGIN
      CASE _PacketType OF
      | ptArm, ptDisarm :
         chksumFrom := 2;
         chksumOffset := FIELDOFS( TPacket.ArmCRC );
      | ptInfo :
         chksumFrom := 0;
         chksumOffset := FIELDOFS( TPacket.InfoCRC );
      ELSE
         RETURN TRUE;
      END;

      chksumToCheck := CARD8( _Packet@[chksumOffset]^ );
      
      chksum := 0;
      FOR i := chksumFrom TO chksumOffset - 1 DO
         INC( chksum, PCARD8( _Packet@[i] )^ );
      END;

      RETURN chksumToCheck = chksum;
   END CheckSum;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Complete( KnownLength : CARDINAL; OUT FirstIndexAfterData, FirstIndexAfterFrame : CARDINAL; OUT ApplyChecksum : BOOLEAN ) : BOOLEAN;
   BEGIN
      IF ( _Packet = NIL ) OR ( KnownLength < 1 ) THEN
         RETURN FALSE;
      END;

      CASE _PacketType OF
      //-----
      | ptArm, ptDisarm :
         IF KnownLength < FIELDOFS( TPacket.ValueType ) + SIZE( TPacket.ValueType ) THEN
            RETURN FALSE;
         ELSIF _Packet^.ValueType = CH_DIGITAL THEN
            FirstIndexAfterData := FIELDOFS( TPacket.dChkSum );
            FirstIndexAfterFrame := FirstIndexAfterData + SIZE( TPacket.dChkSum );
         ELSE
            FirstIndexAfterData := FIELDOFS( TPacket.nChkSum );
            FirstIndexAfterFrame := FirstIndexAfterData + SIZE( TPacket.nChkSum );
         END;
         ApplyChecksum := TRUE;
      //-----
      | ptInfo :
      //-----
      ELSE
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
   END SetPacketCharacters;

(*---------------------------------------------------------------------------*)

BEGIN
   _PacketType := ptUnknown;
   _Packet := NIL;
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

      I := CreateNewItem( L"Humidity",    ns.ntValue, iovalue.vtFloat, PTRCtor( vtAnalog, 5 )); DataRoot^.AddChild( I );
      I := CreateNewItem( L"Temperature", ns.ntValue, iovalue.vtFloat, PTRCtor( vtAnalog, 6 )); DataRoot^.AddChild( I );

      I := CreateNewItem( L"Humidity setpoint",    ns.ntValue, iovalue.vtFloat, PTRCtor( vtAnalog, 13 )); DataRoot^.AddChild( I );
      I := CreateNewItem( L"Temperature setpoint", ns.ntValue, iovalue.vtFloat, PTRCtor( vtAnalog, 11 )); DataRoot^.AddChild( I );

      I := CreateNewItem( L"Temperature (bath) setpoint", ns.ntValue, iovalue.vtFloat, PTRCtor( vtAnalog, 29 )); DataRoot^.AddChild( I );
      I := CreateNewItem( L"Temperature (party) setpoint", ns.ntValue, iovalue.vtFloat, PTRCtor( vtAnalog, 33 )); DataRoot^.AddChild( I );
      I := CreateNewItem( L"Temperature (standby) setpoint", ns.ntValue, iovalue.vtFloat, PTRCtor( vtAnalog, 31 )); DataRoot^.AddChild( I );

      I := CreateNewItem( L"Humidity (bath) setpoint", ns.ntValue, iovalue.vtFloat, PTRCtor( vtAnalog, 30 )); DataRoot^.AddChild( I );
      I := CreateNewItem( L"Humidity (party) setpoint", ns.ntValue, iovalue.vtFloat, PTRCtor( vtAnalog, 34 )); DataRoot^.AddChild( I );
      I := CreateNewItem( L"Humidity (standby) setpoint", ns.ntValue, iovalue.vtFloat, PTRCtor( vtAnalog, 32 )); DataRoot^.AddChild( I );
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
      RETURN _PeriodHandle <> NIL;
   END Running;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Start() : Sync.TAsyncResult;
   BEGIN
      IF _PeriodHandle <> NIL THEN
         RETURN Sync.arAlreadyPending;
      END;

      _Lock.Lock();
      State := tasIdle;
      _Lock.Unlock();

      _PoolDelegate.TimeoutSink := ADR( SELF );
      threadpool.pool()^.WaitTimeout( ADR( _PoolDelegate ), 0, PollPeriodMS, FALSE, FALSE, OUT _PeriodHandle );

      RETURN Sync.arCompleted;
   END Start;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Stop();
   BEGIN
      _PoolDelegate.TimeoutSink := NIL;
      IF _PeriodHandle <> NIL THEN
         threadpool.pool()^.Abort( REF _PeriodHandle );
      END;
   END Stop;

(*---------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnTimeout( Result : Sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR );
   BEGIN
      IF PoolHandle = _PeriodHandle THEN
         EventTime();
      END;
   END OnTimeout;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( REF Driven : IAutomatonRequest );
   BEGIN
      _Driven := ADR( Driven );
   END Init;

(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE EventTime();
   VAR
      al : Sync.AutoLock;
   BEGIN
      al.Take( REF _Lock );
      IF State = tasIdle THEN
         State := tasWaitUpdate;
         _Driven^.UpdateDeviceBuffer();
      END;
   END EventTime;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE EventAbort();
   VAR
      al : Sync.AutoLock;
   BEGIN
      al.Take( REF _Lock );
      State := tasIdle;
      _ItemToWrite := NIL;
   END EventAbort;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE EventACK();
   VAR
      al : Sync.AutoLock;
   BEGIN
      al.Take( REF _Lock );
      CASE State OF
      | tasWaitUpdate :
         State := tasWaitData;
         _Driven^.AskData();
      | tasWaitWrite :
         _Driven^.Sent( Sync.arCompleted, _ItemToWrite );
         _ItemToWrite := NIL;
         State := tasWaitData;
         _Driven^.AskData();
      END;
   END EventACK;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE EventNAK();
   VAR
      al : Sync.AutoLock;
   BEGIN
      al.Take( REF _Lock );
      IF State = tasWaitUpdate THEN
         IF _ItemToWrite = NIL THEN
            State := tasIdle;
         ELSE
            State := tasWaitWrite;
            _Driven^.SendData( _ItemToWrite );
         END;
      END;
   END EventNAK;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE EventSTX( Packet : ADDRESS );
   VAR
      al : Sync.AutoLock;
   BEGIN
      al.Take( REF _Lock );
      IF State = tasWaitData THEN
         _Driven^.Ack();
         _Driven^.ProcessData( Packet );
         IF _ItemToWrite = NIL THEN
            _Driven^.AskData();
         ELSE
            State := tasWaitWrite;
            _Driven^.SendData( _ItemToWrite );
         END;
      END;
   END EventSTX;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE EventNoData();
   VAR
      al : Sync.AutoLock;
   BEGIN
      al.Take( REF _Lock );
      IF State = tasWaitData THEN
         State := tasIdle;
      END;
   END EventNoData;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE EventWrite( ItemToWrite : nsitem.TPnsItem ) : Sync.TAsyncResult;
   VAR
      al : Sync.AutoLock;
   BEGIN
      al.Take( REF _Lock );
      IF _ItemToWrite <> NIL THEN
         RETURN Sync.arAlreadyPending;
      END;
      _ItemToWrite := ItemToWrite;
      IF State = tasIdle THEN
         State := tasWaitWrite;
         _Driven^.SendData( _ItemToWrite );
      END;
      RETURN Sync.arPending;
   END EventWrite;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE EventTimeout();
   VAR
      al : Sync.AutoLock;
   BEGIN
      al.Take( REF _Lock );
      CASE State OF
      | tasWaitUpdate :
         State := tasIdle;
      | tasWaitData :
         State := tasIdle;
      | tasWaitWrite :
         _Driven^.Sent( Sync.arTimeout, _ItemToWrite );
         _ItemToWrite := NIL;
         State := tasWaitData;
         _Driven^.AskData();
      END; // CASE
   END EventTimeout;

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
   _PeriodHandle := NIL;
   _ItemToWrite := NIL;
   PollPeriodMS := POLL_PERIOD_DEFAULT;
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

      Logger.LogS( log.ldMessage, 0, L"Integra", L"Started" );
      RETURN Connection.OpenS( _HostAddress, TRUE, 500 );
   END Start;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Stop();
   BEGIN
      _PoolDelegate.TimeoutSink := NIL;
   
      StopTimeout( REF _TxTimeoutHandle );
      StopTimeout( REF _RxTimeoutHandle );

      Connection.Close();
      Logger.LogS( log.ldMessage, 0, L"Integra", L"Stopped" );

   	LogConfig.DisposeAppenderList( REF _AppenderList );
   END Stop;

(*---------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnTimeout( Result : Sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR );
   BEGIN
      IF PoolHandle = _TxTimeoutHandle THEN
         _TxTimeoutHandle := NIL;
         Logger.LogS( log.ldTrace, 0, L"", L"Tx timeout" );
         Automaton^.EventTimeout();

      ELSIF PoolHandle = _RxTimeoutHandle THEN
         _RxTimeoutHandle := NIL;
         Logger.LogS( log.ldTrace, 0, L"", L"Rx timeout" );
         Automaton^.EventTimeout();

      END;
   END OnTimeout;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Arm();
   VAR
      Packet : TPacket;
      Wrapper : CPacket;
   BEGIN
      Packet.FIRST := 0C;
      Wrapper.EmptyPacket := ADR( Packet );
      Wrapper.PacketType := ptACK;
      Tx( OA( Wrapper.Length-1, Wrapper.Packet ), FALSE, 1, 0, 0 );
   END Ack;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Disarm();
   VAR
      Packet : TPacket;
      Wrapper : CPacket;
   BEGIN
      Packet.FIRST := 0C;
      Wrapper.EmptyPacket := ADR( Packet );
      Wrapper.PacketType := ptDataRequest;
      Wrapper.DeviceAddress := _DeviceAddress;
      Tx( OA( Wrapper.Length-1, Wrapper.Packet ), FALSE, 1, 150, 500 );
   END AskData;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE ProcessData( Packet : ADDRESS );
   BEGIN
      PIO^.OnRx( Sync.arCompleted, TPPacket( Packet ));
   END ProcessData;

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
      Connection.Stream^.ReadBuffer( 2048, REF Data, 0 );
      HandleRx( Sync.arCompleted, REF Data );
      Connection.BufferedStream^.StartReading();
   END OnReadable;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE DetectDataStart( CONST Data : StorageO.AMemoryBuffer; OUT FirstIndexOfFrame, FirstIndexOfData : CARDINAL ) : BOOLEAN;
   VAR
      ch : CHAR;
      i : CARDINAL := 0;
      l : CARDINAL := Data.Length;
   BEGIN
      WHILE i < l DO
         TRY
            ch := CHAR( Data[i] ); // ch in CASE is not handled correctly by CASE
            CASE ch OF
            | CH_NUL,
              CH_STX,
              CH_ACK,
              CH_BEL :
               FirstIndexOfFrame := i;
               FirstIndexOfData := i;
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
      RETURN Wrapper.CheckSum();
   END TestChkSum;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnRx( Result : Sync.TAsyncResult; CONST Data : StorageO.AMemoryBuffer );
   VAR
      Wrapper : CPacket;
   BEGIN
      StopTimeout( REF _TxTimeoutHandle );
      StopTimeout( REF _RxTimeoutHandle );

      IF Result = Sync.arCompleted THEN

         Wrapper.FilledPacket := Data.Data;
         CASE Wrapper.PacketType OF
         | ptData :
            Automaton^.EventSTX( Data.Data );
         | ptACK :
            Automaton^.EventACK();
         | ptNAK :
            Automaton^.EventNAK();
         | ptNoData :
            Automaton^.EventNoData();
         ELSE
            ASSERTLOG( FALSE );
         END;

      ELSE
         Automaton^.EventTimeout();
 
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
      keyAddress = L"address";
      keyPollPeriod = L"poll_period";
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
         IF NOT iniFile.GetKeyInt( keyAddress, OUT l, OUT _DeviceAddress ) THEN
            LogError( l, Texts._AddressKeyMissing, NIL );
         END;
         IF NOT iniFile.GetKeyInt( keyPollPeriod, OUT l, OUT _PollPeriodMS ) THEN
            _PollPeriodMS := POLL_PERIOD_DEFAULT;
         END;
         Automaton^.PollPeriodMS := _PollPeriodMS;
      ELSE
         LogError( 0, Texts._ConfigurationSectionMissing, ADR( iniFileSection ));
      END;
      RETURN Result;
   END Configure;

(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Tx( CONST Data : ARRAY OF BYTE; _SendAsIs : BOOLEAN; _RepeatCount : CARDINAL; _TxTimeout, _RxTimeout : CARDINAL );
   VAR
      c : CARDINAL;
      Result : Sync.TAsyncResult;
      TxBuffer : StorageO.CMemoryBuffer;
   BEGIN
      IF NOT Connection.Connected THEN
         Logger.LogS( log.ldTrace, 0, L"", L"Disconnected, trying to reconnect" );
         Connection.OpenS( _HostAddress, TRUE, 500 );
      END;
   
      IF INTEGER( HIGH( Data )) >= 0 THEN // HACK
         TxBuffer.Size := 1024;
         TxBuffer.AppendOA( Data );
         IF NOT _SendAsIs THEN
            AddChkSum( REF TxBuffer );
         END;
      END;
      
      IF _TxTimeout > 0 THEN
         StartTimeout( _TxTimeout, REF _TxTimeoutHandle );
      END;
      IF _RxTimeout > 0 THEN
         StartTimeout( _RxTimeout, REF _RxTimeoutHandle );
      END;

      Logger.LogSCB( log.ldDebug, 0, L'', L'tx start of ', TxBuffer.Length, TxBuffer.Data, TxBuffer.Length );
      Result := Connection.Stream^.WriteBuffer( TxBuffer, OUT c, netsocket.FORSAFETY );
      IF Result = Sync.arTimeout THEN
         ASSERTLOG( FALSE );
      END;
   END Tx;

//---------------------------------------------------------

   PUBLIC PROCEDURE Abort();
   BEGIN
      Automaton^.EventAbort();
      StopTimeout( REF _TxTimeoutHandle );
      StopTimeout( REF _RxTimeoutHandle );
      Connection.Stream^.AbortWriting();
   END Abort;

//---------------------------------------------------------

   PRIVATE PROCEDURE HandleRx( Result : Sync.TAsyncResult; REF Data : StorageO.AMemoryBuffer ) : BOOLEAN;
   VAR
      LDI, LI : CARDINAL := 0;
      LRxBuffer : StorageO.CMemoryBuffer;
      TDI, TI : CARDINAL;
      ApplyChecksum : BOOLEAN; // apply checksum
      ChkSumOK : BOOLEAN := TRUE;
   BEGIN
      IF Result <> Sync.arCompleted THEN
         Logger.LogSC( log.ldError, 0, L'', L'rx error: ', CARDINAL( Result ));
         OnRx( Result, LRxBuffer );
         RxBuffer.Clear();
         RETURN FALSE;
      ELSIF NOT Data.Empty THEN
         RxBuffer.Append( Data );
         Logger.LogSCB( log.ldDebug, 0, L'', L'rx success, len: ', Data.Length, Data.Data, Data.Length );
      END;

      IF NOT DetectDataStart( RxBuffer, OUT LI, OUT LDI ) THEN
         RxBuffer.Clear();
         RETURN FALSE;
      ELSIF LI > 0 THEN
         RxBuffer.RemoveStart( LI );
         DEC( LDI, LI );
         LI := 0;
      END;

      IF NOT DataComplete( RxBuffer, OUT TDI, OUT TI, OUT ApplyChecksum ) THEN
         RETURN FALSE;
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
      ELSE
         RxBuffer.RemoveStart( TI );
      END;
      RETURN NOT RxBuffer.Empty;
   END HandleRx;

//---------------------------------------------------------

   PRIVATE PROCEDURE StartTimeout( TimeoutMS : CARDINAL; REF Handle : threadpool.TPoolHandle );
   BEGIN
      ASSERTLOG( Handle = NIL );
      threadpool.pool()^.WaitTimeout( ADR( _PoolDelegate ), 0, TimeoutMS, TRUE, FALSE, OUT Handle );
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
   _RxTimeoutHandle := 0;
   _TxTimeoutHandle := 0;
   _PollPeriodMS := POLL_PERIOD_DEFAULT;
   _DeviceAddress := 1;
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
         GetValueFromPtr( nsitem.TPnsItem( Item )^.Data, OUT Value );
         Delegate^.OnIO( IOO.dirRead, ADR( SELF ), OA( 0, ADR( Result )), OA( 0, ADR( Item )), OA( -1, NIL ), OA( 0, ADR( Value )));
         
         RETURN Sync.arCompleted;
      ELSE
         _Pending := Direction;
         _Item := Item;
         _Callback := Delegate;

         SetValueToPtr( REF nsitem.TPnsItem( Item )^.Data, Value );
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
      Wrapper : CPacket;
   BEGIN
      IF Result = Sync.arCompleted THEN
         // prepare value
         Wrapper.FilledPacket := PPacket;
         CASE Wrapper.ValueType OF
         | vtAnalog, vtInteger, vtDigital :
         ELSE
            ASSERTLOG( FALSE );
            RETURN;
         END;
         
         // lookup for item and set data to it
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
