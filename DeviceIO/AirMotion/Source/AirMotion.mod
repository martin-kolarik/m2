IMPLEMENTATION MODULE AirMotion;

(*================================================================================*)

FROM Debug IMPORT
   Assertion, LogAssertionW;

IMPORT
   FIO,
   iobject,
   IOO,
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
   CH_NUL = 0C;
   CH_STX = 2C;
   CH_ETX = 3C;
   CH_ENQ = 5C;
   CH_ACK = 6C;
   CH_BEL = 7C;
   CH_F   = C'F';
   
   CH_DIGITAL     = C'D';
   CH_INTEGER     = C'I';
   CH_ANALOG      = C'A';
   CH_FILL_BUFFER ::= CH_F;
   
   POLL_PERIOD_DEFAULT = 15000;

#save, option( pack => 1 )
TYPE
   TPacketType = (
      ptUnknown,
      ptDataRequest,
      ptData,
      ptFillBuffer,
      ptNoData,
      ptACK,
      ptNAK
   );
   
   TValueType = CARD8( // CARD8 due to presence in TNSPTR
      vtAnalog,
      vtInteger,
      vtDigital
   );

TYPE
   TPacket  = RECORD
                 CASE : TPacketType OF
                 | ptUnknown :
                    FIRST       : CHAR;
                 | ptDataRequest :
                    ENQ         : CHAR;
                    rAddress    : CHAR;
                 | ptData :
                    dSTX        : CHAR;
                    dAddress    : CHAR;
                    ValueType   : CHAR;
                    ValueIndex  : CHAR;
                    CASE : TValueType OF
                    | vtAnalog,
                      vtInteger :
                       Number   : ARRAY [0..3] OF CHAR;
                       nETX     : CHAR;
                       nChkSum  : ARRAY [0..1] OF CHAR;
                    | vtDigital :
                       Digital  : CHAR;
                       dETX     : CHAR;
                       dChkSum  : ARRAY [0..1] OF CHAR;
                    END; // CASE
                 | ptFillBuffer :
                    fSTX        : CHAR;
                    fAddress    : CHAR;
                    F           : CHAR;
                    fETX        : CHAR;
                    fChkSum     : ARRAY [0..1] OF CHAR;
                 | ptNoData :
                    NUL         : CHAR;
                 | ptACK :
                    ACK         : CHAR;
                 | ptNAK :
                    BEL         : CHAR;
                 END; // CASE
              END; // RECORD
   TPPacket = POINTER TO TPacket;
   
   TNSPTR  = RECORD
                CASE : CARDINAL OF
                | 0 :
                  Type : TValueType;
                  Address : CARD8;
                  Value : INT16;
                | 1 :
                  Ptr : PTR;
                END; // CASE
             END; // RECORD
   TPNSPTR = POINTER TO TNSPTR;
   
   PROCEDURE PTRCtor( Type : TValueType; Address : CARD8 ) : PTR;
   VAR
      Ptr : TNSPTR;
   BEGIN
      Ptr.Type := Type;
      Ptr.Address := Address;
      Ptr.Value := 0;
      RETURN Ptr.Ptr;
   END PTRCtor;
#restore

CLASS CPacket; // class is wrapping some foreign data area
   PRIVATE VAR
      _PacketType : TPacketType;
      _Packet : TPPacket;

   PUBLIC PROPERTY
      PacketType : TPacketType;
      DeviceAddress : CARDINAL;

      ValueIndex : CARDINAL;
      Analog : LONGREAL;
      Integer : INTEGER;
      Digital : BOOLEAN;
      
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

   PRIVATE PROCEDURE SetPacketCharacters(); // _Packet MUST not be NIL
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
         SetPacketCharacters();
      END;
   END PacketType;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY DeviceAddress GET : CARDINAL;
   BEGIN
      IF _Packet = NIL THEN
         RETURN -1;
      END;
      CASE _PacketType OF
      | ptDataRequest :
         RETURN CARDINAL( _Packet^.rAddress ) - ORD( '0' );
      | ptData :
         RETURN CARDINAL( _Packet^.dAddress ) - ORD( '0' );
      | ptFillBuffer :
         RETURN CARDINAL( _Packet^.fAddress ) - ORD( '0' );
      ELSE
         RETURN -1;
      END;
   END DeviceAddress;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY DeviceAddress SET( Value : CARDINAL );
   BEGIN
      IF _Packet = NIL THEN
         RETURN;
      ELSIF ( Value < 1 ) OR ( Value > 200 ) THEN
         RETURN;
      END;
      CASE _PacketType OF
      | ptDataRequest :
         _Packet^.rAddress := CHAR( Value + ORD( '0' ));
      | ptData :
         _Packet^.dAddress := CHAR( Value + ORD( '0' ));
      | ptFillBuffer :
         _Packet^.fAddress := CHAR( Value + ORD( '0' ));
      END;
   END DeviceAddress;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY ValueIndex GET : CARDINAL;
   BEGIN
      IF _Packet = NIL THEN
         RETURN -1;
      ELSIF _PacketType <> ptData THEN
         RETURN -1;
      END;
      RETURN CARDINAL( _Packet^.ValueIndex ) - ORD( '0' );
   END ValueIndex;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY ValueIndex SET( Value : CARDINAL );
   BEGIN
      IF _Packet = NIL THEN
         RETURN;
      ELSIF ( Value < 1 ) OR ( Value > 100 ) THEN
         RETURN;
      ELSIF _PacketType <> ptData THEN
         RETURN;
      END;
      _Packet^.ValueIndex := CHAR( Value + ORD( '0' ));
   END ValueIndex;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY EmptyPacket SET( Value : TPPacket );
   BEGIN
      _Packet := Value;
      IF _PacketType <> ptUnknown THEN
         SetPacketCharacters();
      END;
   END EmptyPacket;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY FilledPacket SET( Value : TPPacket );
   BEGIN
      _Packet := Value;
      IF _Packet = NIL THEN
         RETURN;
      END;
      CASE _Packet^.FIRST OF
      // | CH_ENX : // ptDataRequest cannot be received
      | CH_STX :
         IF _Packet^.ValueType = CH_FILL_BUFFER THEN
            _PacketType := ptFillBuffer;
         ELSE
            _PacketType := ptData;
         END;
      | CH_NUL :
         _PacketType := ptNoData;
      | CH_ACK :
         _PacketType := ptACK;
      | CH_BEL :
         _PacketType := ptNAK;
      END;
   END FilledPacket;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Analog GET : LONGREAL;
   VAR
      IValue : INTEGER;
      WData : ARRAY [0..3] OF WCHAR;
   BEGIN
      IF _PacketType <> ptData THEN
         RETURN 0.0;
      ELSIF _Packet = NIL THEN
         RETURN 0.0;
      ELSIF _Packet^.ValueType <> CH_ANALOG THEN
         RETURN 0.0;
      END;

      WData[0] := WCHAR( _Packet^.Number[0] );
      WData[1] := WCHAR( _Packet^.Number[1] );
      WData[2] := WCHAR( _Packet^.Number[2] );
      WData[3] := WCHAR( _Packet^.Number[3] );
      IF Strings.ToINT32W( WData, 16, OUT IValue ) THEN
         RETURN LONGREAL( IValue ) / 10.0;
      ELSE
         RETURN 0.0;
      END;
   END Analog;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Analog SET( Value : LONGREAL );
   VAR
      b : BOOLEAN;
      IValue : INTEGER := INTEGER( Value * 10.0 + 0.5 );
      WData : ARRAY [0..3] OF WCHAR;
   BEGIN
      _PacketType := ptData;
      IF _Packet = NIL THEN
         RETURN;
      END;
      _Packet^.ValueType := CH_ANALOG;
      WData := L"0000";

      IF IValue < 16 THEN
         b := Strings.FromINT32W( IValue, 16, OUT OA( 0, ADR( WData[3] )));
      ELSIF IValue < 16*16 THEN
         b := Strings.FromINT32W( IValue, 16, OUT OA( 1, ADR( WData[2] )));
      ELSIF IValue < 16*16*16 THEN
         b := Strings.FromINT32W( IValue, 16, OUT OA( 2, ADR( WData[1] )));
      ELSE
         b := Strings.FromINT32W( IValue, 16, OUT WData );
      END;

      IF b THEN
         _Packet^.Number[0] := CHAR( WData[0] );
         _Packet^.Number[1] := CHAR( WData[1] );
         _Packet^.Number[2] := CHAR( WData[2] );
         _Packet^.Number[3] := CHAR( WData[3] );
      END;
   END Analog;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Integer GET : INTEGER;
   VAR
      IValue : INTEGER;
      WData : ARRAY [0..3] OF WCHAR;
   BEGIN
      IF _PacketType <> ptData THEN
         RETURN 0;
      ELSIF _Packet = NIL THEN
         RETURN 0;
      ELSIF _Packet^.ValueType <> CH_INTEGER THEN
         RETURN 0;
      END;

      WData[0] := WCHAR( _Packet^.Number[0] );
      WData[1] := WCHAR( _Packet^.Number[1] );
      WData[2] := WCHAR( _Packet^.Number[2] );
      WData[3] := WCHAR( _Packet^.Number[3] );
      IF Strings.ToINT32W( WData, 16, OUT IValue ) THEN
         RETURN IValue;
      ELSE
         RETURN 0;
      END;
   END Integer;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Integer SET( IValue : INTEGER );
   VAR
      b : BOOLEAN;
      WData : ARRAY [0..3] OF WCHAR;
   BEGIN
      _PacketType := ptData;
      IF _Packet = NIL THEN
         RETURN;
      END;
      _Packet^.ValueType := CH_ANALOG;
      WData := L"0000";

      IF IValue < 16 THEN
         b := Strings.FromINT32W( IValue, 16, OUT OA( 0, ADR( WData[3] )));
      ELSIF IValue < 16*16 THEN
         b := Strings.FromINT32W( IValue, 16, OUT OA( 1, ADR( WData[2] )));
      ELSIF IValue < 16*16*16 THEN
         b := Strings.FromINT32W( IValue, 16, OUT OA( 2, ADR( WData[1] )));
      ELSE
         b := Strings.FromINT32W( IValue, 16, OUT WData );
      END;

      IF b THEN
         _Packet^.Number[0] := CHAR( WData[0] );
         _Packet^.Number[1] := CHAR( WData[1] );
         _Packet^.Number[2] := CHAR( WData[2] );
         _Packet^.Number[3] := CHAR( WData[3] );
      END;
   END Integer;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Digital GET : BOOLEAN;
   BEGIN
      IF _PacketType <> ptData THEN
         RETURN FALSE;
      ELSIF _Packet = NIL THEN
         RETURN FALSE;
      ELSIF _Packet^.ValueType <> CH_DIGITAL THEN
         RETURN FALSE;
      ELSE
         RETURN _Packet^.Digital = C'1';
      END;
   END Digital;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Digital SET( Value : BOOLEAN );
   BEGIN
      _PacketType := ptData;
      IF _Packet = NIL THEN
         RETURN;
      END;
      _Packet^.ValueType := CH_DIGITAL;
      IF Value THEN
         _Packet^.Digital := C'1';
      ELSE
         _Packet^.Digital := C'0';
      END;
   END Digital;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY ValueType GET : TValueType;
   BEGIN
      IF _PacketType <> ptData THEN
         ASSERTLOG( FALSE );
         RETURN vtDigital;
      END;
      CASE _Packet^.ValueType OF
      | CH_DIGITAL :
         RETURN vtDigital;
      | CH_INTEGER :
         RETURN vtInteger;
      | CH_ANALOG :
         RETURN vtAnalog;
      ELSE
         ASSERTLOG( FALSE );
         RETURN vtDigital;
      END;
   END ValueType;

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
      | ptDataRequest :
         RETURN 2;
      | ptData  :
         IF _Packet^.ValueType = CH_DIGITAL THEN
            RETURN 8;
         ELSE
            RETURN 11;
         END;
      | ptFillBuffer :
         RETURN 6;
      | ptNoData :
         RETURN 1;
      | ptACK :
         RETURN 1;
      | ptNAK :
         RETURN 1;
      ELSE
         RETURN 0;
      END;
   END Length;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ComputeCheckSum();
   VAR
      chksum : CARD8;
      chksumOffset : CARDINAL;
      i : CARDINAL;
      WData : ARRAY [0..1] OF WCHAR;
   BEGIN
      CASE _PacketType OF
      | ptData :
         IF _Packet^.ValueType = CH_DIGITAL THEN
            chksumOffset := FIELDOFS( TPacket.dChkSum );
         ELSE
            chksumOffset := FIELDOFS( TPacket.nChkSum );
         END;
      | ptFillBuffer :
         chksumOffset := FIELDOFS( TPacket.fChkSum );
      ELSE
         RETURN;
      END;
      
      chksum := 0;
      FOR i := 0 TO chksumOffset -1 DO
         INC( chksum, PCARD8( _Packet@[i] )^ );
      END;
      IF chksum < 10H THEN
         WData[0] := L'0';
      ELSE
         WData[0] := WCHAR( ORD( L'0' ) + chksum DIV 10H );
      END;
      WData[1] := WCHAR( ORD( L'0' ) + chksum AND 0FH );
      
      IF _PacketType = ptFillBuffer THEN
         _Packet^.fChkSum[0] := CHAR( WData[0] );
         _Packet^.fChkSum[1] := CHAR( WData[1] );
      ELSIF _Packet^.ValueType = CH_DIGITAL THEN
         _Packet^.dChkSum[0] := CHAR( WData[0] );
         _Packet^.dChkSum[1] := CHAR( WData[1] );
      ELSE
         _Packet^.nChkSum[0] := CHAR( WData[0] );
         _Packet^.nChkSum[1] := CHAR( WData[1] );
      END;
   END ComputeCheckSum;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CheckSum() : BOOLEAN;
   VAR
      chksum : CARD8;
      chksumToCheck : CARDINAL;
      chksumOffset : CARDINAL;
      i : CARDINAL;
      WData : ARRAY [0..1] OF WCHAR;
   BEGIN
      CASE _PacketType OF
      | ptData :
         IF _Packet^.ValueType = CH_DIGITAL THEN
            chksumOffset := FIELDOFS( TPacket.dChkSum );
            WData[0] := WCHAR( _Packet^.dChkSum[0] );
            WData[1] := WCHAR( _Packet^.dChkSum[1] );
         ELSE
            chksumOffset := FIELDOFS( TPacket.nChkSum );
            WData[0] := WCHAR( _Packet^.nChkSum[0] );
            WData[1] := WCHAR( _Packet^.nChkSum[1] );
         END;
      | ptFillBuffer :
         chksumOffset := FIELDOFS( TPacket.fChkSum );
         WData[0] := WCHAR( _Packet^.fChkSum[0] );
         WData[1] := WCHAR( _Packet^.fChkSum[1] );
      ELSE
         RETURN TRUE;
      END;

      chksumToCheck := 10H * ( ORD( WData[0] ) - ORD( L'0' )) + ( ORD( WData[1] ) - ORD( C'0' ));
      
      chksum := 0;
      FOR i := 0 TO chksumOffset -1 DO
         INC( chksum, PCARD8( _Packet@[i] )^ );
      END;

      RETURN CARD8( chksumToCheck ) = chksum;
   END CheckSum;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Complete( KnownLength : CARDINAL; OUT FirstIndexAfterData, FirstIndexAfterFrame : CARDINAL; OUT ApplyChecksum : BOOLEAN ) : BOOLEAN;
   BEGIN
      IF ( _Packet = NIL ) OR ( KnownLength < 1 ) THEN
         RETURN FALSE;
      END;

      CASE _PacketType OF
      //-----
      | ptData :
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
      | ptNoData, ptACK, ptNAK :
         FirstIndexAfterData := 1;
         FirstIndexAfterFrame := 1;
         ApplyChecksum := FALSE;
      //-----
      ELSE
         RETURN FALSE;
      END;

      RETURN KnownLength >= FirstIndexAfterFrame;
   END Complete;

(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE SetPacketCharacters(); // _Packet MUST not be NIL
   BEGIN
      CASE _PacketType OF
      | ptDataRequest :
         _Packet^.ENQ := CH_ENQ;
      | ptData  :
         _Packet^.dSTX := CH_STX;
         _Packet^.dETX := CH_ETX;
      | ptFillBuffer :
         _Packet^.fSTX := CH_STX;
         _Packet^.F := CH_F;
         _Packet^.fETX := CH_ETX;
      | ptNoData :
         _Packet^.NUL := CH_NUL;
      | ptACK :
         _Packet^.ACK := CH_ACK;
      | ptNAK :
         _Packet^.BEL := CH_BEL;
      END;
   END SetPacketCharacters;

(*---------------------------------------------------------------------------*)

BEGIN
   _PacketType := ptUnknown;
   _Packet := NIL;
END CPacket;

(*===========================================================================*)

PROCEDURE SetPtrValueDigital( REF Ptr : PTR; Digital : BOOLEAN );
BEGIN
   TPNSPTR( ADR( Ptr ))^.Value := INT16( Digital );
END SetPtrValueDigital;

(*---------------------------------------------------------------------------*)

PROCEDURE SetPtrValueInteger( REF Ptr : PTR; Integer : INTEGER );
BEGIN
   TPNSPTR( ADR( Ptr ))^.Value := INT16( Integer );
END SetPtrValueInteger;

(*---------------------------------------------------------------------------*)

PROCEDURE SetPtrValueAnalog( REF Ptr : PTR; Analog : LONGREAL );
BEGIN
   TPNSPTR( ADR( Ptr ))^.Value := INT16( Analog * 10.0 );
END SetPtrValueAnalog;

(*---------------------------------------------------------------------------*)

PROCEDURE GetValueIndexFromPtr( Ptr : PTR ) : CARDINAL;
VAR
   PPtr : TPNSPTR := TPNSPTR( ADR( Ptr ));
BEGIN
   RETURN CARDINAL( PPtr^.Address );
END GetValueIndexFromPtr;

(*---------------------------------------------------------------------------*)

PROCEDURE GetTypeFromPtr( Ptr : PTR ) : TValueType;
VAR
   PPtr : TPNSPTR := TPNSPTR( ADR( Ptr ));
BEGIN
   RETURN TValueType( PPtr^.Type );
END GetTypeFromPtr;

(*---------------------------------------------------------------------------*)

PROCEDURE GetValueFromPtr( Ptr : PTR; OUT Value : iovalue.Value );
VAR
   PPtr : TPNSPTR := TPNSPTR( ADR( Ptr ));
BEGIN
   CASE PPtr^.Type OF
   | vtDigital :
      Value.Boolean := BOOLEAN( PPtr^.Value );
   | vtInteger :
      Value.Integer := INTEGER( PPtr^.Value );
   | vtAnalog :
      Value.Float := LONGREAL( PPtr^.Value ) / 10.0;
   ELSE
      ASSERTLOG( FALSE );
   END;
END GetValueFromPtr;

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
      RETURN CreateNewItem( L"AirMotion", ns.ntName, iovalue.vtString, 0 );
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
      State := tasIdle;
      threadpool.pool()^.WaitTimeout( ADR( _PoolDelegate ), 0, PollPeriodMS, FALSE, FALSE, OUT _PeriodHandle );
      RETURN Sync.arCompleted;
   END Start;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Stop();
   BEGIN
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
   BEGIN
      IF State = tasIdle THEN
         State := tasWaitUpdate;
         _Driven^.UpdateDeviceBuffer();
      END;
   END EventTime;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE EventAbort();
   BEGIN
      State := tasIdle;
      _ItemToWrite := NIL;
   END EventAbort;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE EventACK();
   BEGIN
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
   BEGIN
      IF State = tasWaitUpdate THEN
         IF _ItemToWrite = NIL THEN
            State := tasIdle;
         ELSE
            State := tasWaitWrite;
            SendData();
         END;
      END;
   END EventNAK;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE EventSTX( Packet : ADDRESS );
   BEGIN
      IF State = tasWaitData THEN
         _Driven^.Ack();
         _Driven^.ProcessData( Packet );
         IF _ItemToWrite = NIL THEN
            _Driven^.AskData();
         ELSE
            State := tasWaitWrite;
            SendData();
         END;
      END;
   END EventSTX;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE EventNoData();
   BEGIN
      IF State = tasWaitData THEN
         State := tasIdle;
      END;
   END EventNoData;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE EventWrite( ItemToWrite : nsitem.TPnsItem ) : Sync.TAsyncResult;
   BEGIN
      IF _ItemToWrite <> NIL THEN
         RETURN Sync.arAlreadyPending;
      END;
      _ItemToWrite := ItemToWrite;
      IF State = tasIdle THEN
         State := tasWaitWrite;
         SendData();
      END;
      RETURN Sync.arPending;
   END EventWrite;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE EventTimeout();
   BEGIN
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
      RETURN TAutomatonState( Sync.IGet( REF PINT32( ADR( _State ))^ ));
   END State;

(*---------------------------------------------------------------------------*)

   PRIVATE PROPERTY State SET( Value : TAutomatonState );
   BEGIN
      Sync.IExchg( REF PINT32( ADR( _State ))^, INT32( Value ));
   END State;

(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE SendData();
   VAR
      io : iovalue.Value;
      Packet : TPacket;
      Wrapper : CPacket;
   BEGIN
      IF _ItemToWrite = NIL THEN
         RETURN;
      END;
   
      Packet.FIRST := 0C;
      Wrapper.EmptyPacket := ADR( Packet );
      
      Wrapper.PacketType := ptData;
      Wrapper.ValueIndex := GetValueIndexFromPtr( _ItemToWrite^.Data );
      GetValueFromPtr( _ItemToWrite^.Data, OUT io );
      CASE GetTypeFromPtr( _ItemToWrite^.Data ) OF
      | vtAnalog :
         Wrapper.Analog := io.Float;
      | vtInteger :
         Wrapper.Integer := io.Integer;
      | vtDigital :
         Wrapper.Digital := io.Boolean;
      ELSE
         ASSERTLOG( FALSE );
      END;
      
      _Driven^.SendData( Wrapper.Packet, Wrapper.Length );
   END SendData;

(*---------------------------------------------------------------------------*)

BEGIN
   _State := tasIdle;
   _Driven := NIL;
   _PeriodHandle := NIL;
   _PoolDelegate.TimeoutSink := ADR( SELF );
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
      Logger.LogS( log.dldMessage, L"AirMotion", L"Started" );
      RETURN Connection.OpenS( _HostAddress, TRUE, 500 );
   END Start;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Stop();
   BEGIN
      Connection.Close();
      Logger.LogS( log.dldMessage, L"AirMotion", L"Stopped" );
   END Stop;

(*---------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnTimeout( Result : Sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR );
   BEGIN
      IF PoolHandle = _TxTimeoutHandle THEN
         _TxTimeoutHandle := NIL;
         Logger.LogS( log.dldTrace, L"", L"Tx timeout" );
         Automaton^.EventTimeout();

      ELSIF PoolHandle = _RxTimeoutHandle THEN
         _RxTimeoutHandle := NIL;
         Logger.LogS( log.dldTrace, L"", L"Rx timeout" );
         Automaton^.EventTimeout();

      END;
   END OnTimeout;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE UpdateDeviceBuffer();
   VAR
      Packet : TPacket;
      Wrapper : CPacket;
   BEGIN
      Packet.FIRST := 0C;
      Wrapper.EmptyPacket := ADR( Packet );
      Wrapper.PacketType := ptFillBuffer;
      Wrapper.DeviceAddress := _DeviceAddress;
      Tx( OA( Wrapper.Length-1, Wrapper.Packet ), FALSE, 1, 150, 500 );
   END UpdateDeviceBuffer;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Ack();
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

   PUBLIC VIRTUAL PROCEDURE AskData();
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

   PUBLIC VIRTUAL PROCEDURE SendData( Packet : ADDRESS; Length : CARDINAL );
   BEGIN
      Tx( OA( Length-1, PBYTE( Packet )), FALSE, 1, 150, 500 );
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
      Connection.Stream^.ReadBuffer( 2048, REF Data, 0 );
      HandleRx( Sync.arCompleted, REF Data );
      Connection.BufferedStream^.StartReading();
   END OnReadable;

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
         Log^.LogFilePos( log.dlcError, L"AirMotion", L"", OA( msg.Length-1, msg.rawData ), line, 0 );
      END LogError;

      (*----------*)

   VAR
      l : CARDINAL;
   BEGIN
      IF iniFile.SetSection( OA( iniFileSection.Length-1, iniFileSection.rawData )) THEN
         INIFile.ConfigureLog( iniFile, OA( iniFileSection.Length-1, iniFileSection.rawData ), REF Logger, OUT l );
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
         Logger.LogS( log.dldTrace, L"", L"Disconnected, trying to reconnect" );
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

      Logger.LogSCB( log.dldDebug, L'', L'tx start of ', TxBuffer.Length, TxBuffer.Data, TxBuffer.Length );
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
      LDI, LI : CARDINAL := 0; // TODO
      LRxBuffer : StorageO.CMemoryBuffer;
      TDI, TI : CARDINAL;
      ApplyChecksum : BOOLEAN; // apply checksum
      ChkSumOK : BOOLEAN := TRUE;
   BEGIN
      IF Result <> Sync.arCompleted THEN
         Logger.LogSC( log.dldError, L'', L'rx error: ', CARDINAL( Result ));
         OnRx( Result, LRxBuffer );
         RxBuffer.Clear();
         RETURN FALSE;
      ELSIF NOT Data.Empty THEN
         RxBuffer.Append( Data );
         Logger.LogSCB( log.dldDebug, L'', L'rx success, len: ', Data.Length, Data.Data, Data.Length );
      END;

      (* // TODO
      IF NOT DetectDataStart( RxBuffer, OUT LI, OUT LDI ) THEN
         RETURN FALSE;
      ELSIF LI > 0 THEN
         RxBuffer.RemoveStart( LI );
         DEC( LDI, LI );
         LI := 0;
      END;
      *)

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
   _PoolDelegate.TimeoutSink := ADR( SELF );
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
            IF GetValueIndexFromPtr( DataRoot^[i]^.Data ) = Wrapper.ValueIndex THEN
               CASE Wrapper.ValueType OF
               | vtDigital :
                  SetPtrValueDigital( REF DataRoot^[i]^.Data, Wrapper.Digital );
               | vtInteger :
                  SetPtrValueInteger( REF DataRoot^[i]^.Data, Wrapper.Integer );
               | vtAnalog :
            
// TODO            
Log.logger()^.LogSCC( log.dldTrace, L'', L"Analog", Wrapper.ValueIndex, CARDINAL( 100.0 * Wrapper.Analog ));
            
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

CLASS IMPLEMENTATION CAirMotionDevice;

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
END CAirMotionDevice;

(*===========================================================================*)

BEGIN
   R.LoadRES2( EMIT( %dll ), L"AirMotion.Texts" );
END AirMotion.