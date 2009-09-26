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
   
   TValueType = (
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
                    ValueType   : TValueType;
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
#restore

CLASS CPacket; // class is wrapping some foreign data area
   PRIVATE VAR
      _PacketType : TPacketType;
      _Packet : TPPacket;

   PUBLIC PROPERTY
      PacketType : TPacketType;

      Analog : LONGREAL;
      Integer : INTEGER;
      Digital : BOOLEAN;
      
      Address : CARDINAL;
      
   PUBLIC WRITEONLY PROPERTY
      PacketToSend : TPPacket;
      ReceivedPacket : TPPacket;

   PUBLIC READONLY PROPERTY
      Packet : TPPacket;
      Length : CARDINAL;
      
   PUBLIC PROCEDURE ComputeCheckSum();
   PUBLIC PROCEDURE CheckSum( Packet : TPPacket; Length : CARDINAL ) : BOOLEAN;
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

   PUBLIC PROPERTY PacketToSend SET( Value : TPPacket );
   BEGIN
      _Packet := Value;
      IF _PacketType <> ptUnknown THEN
         SetPacketCharacters();
      END;
   END PacketToSend;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY ReceivedPacket SET( Value : TPPacket );
   BEGIN
      _Packet := Value;
      IF _Packet = NIL THEN
         RETURN;
      END;
      CASE _Packet^.FIRST OF
      // | CH_ENX : // ptDataRequest cannot be received
      | CH_STX :
         _PacketType := ptData; // ptFill data cannot be received
      | CH_NUL :
         _PacketType := ptNoData;
      | CH_ACK :
         _PacketType := ptACK;
      | CH_BEL :
         _PacketType := ptNAK;
      END;
   END ReceivedPacket;

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
      ELSIF _Packet^.ValueType <> vtAnalog THEN
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
      WData : ARRAY [0..3] OF WCHAR := L"0000";
   BEGIN
      _PacketType := ptData;
      IF _Packet = NIL THEN
         RETURN;
      END;
      _Packet^.ValueType := vtAnalog;

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
      ELSIF _Packet^.ValueType <> vtInteger THEN
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
      WData : ARRAY [0..3] OF WCHAR := L"0000";
   BEGIN
      _PacketType := ptData;
      IF _Packet = NIL THEN
         RETURN;
      END;
      _Packet^.ValueType := vtInteger;

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
      ELSIF _Packet^.ValueType <> vtDigital THEN
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
      _Packet^.ValueType := vtDigital;
      IF Value THEN
         _Packet^.Digital := C'1';
      ELSE
         _Packet^.Digital := C'0';
      END;
   END Digital;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Address GET : CARDINAL;
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
   END Address;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Address SET( Value : CARDINAL );
   BEGIN
      IF _Packet = NIL THEN
         RETURN;
      ELSIF Value > 200 THEN
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
   END Address;

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
         IF _Packet^.ValueType = vtDigital THEN
            RETURN 7;
         ELSE
            RETURN 10;
         END;
      | ptFillBuffer :
         RETURN 5;
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
      p : TPacket;
      WData : ARRAY [0..1] OF WCHAR;
   BEGIN
      CASE _PacketType OF
      | ptData :
         IF _Packet^.ValueType = vtDigital THEN
            // chksumOffset := FIELDOFS( TPacket.dChkSum ); -- m2cpp bug
            chksumOffset := CARDINAL( ADR( p.dChkSum )) - CARDINAL( ADR( p ));
         ELSE
            // chksumOffset := FIELDOFS( TPacket.nChkSum ); -- m2cpp bug
            chksumOffset := CARDINAL( ADR( p.nChkSum )) - CARDINAL( ADR( p ));
         END;
      | ptFillBuffer :
         // chksumOffset := FIELDOFS( TPacket.fChkSum ); -- m2cpp bug
         chksumOffset := CARDINAL( ADR( p.fChkSum )) - CARDINAL( ADR( p ));
      ELSE
         RETURN;
      END;
      
      chksum := 0;
      FOR i := 0 TO chksumOffset -1 DO
         INC( chksum, PCARD8( _Packet@[i] )^ );
      END;
      Strings.FromINT32W( CARDINAL( chksum ), 16, OUT WData );
      
      IF _PacketType = ptFillBuffer THEN
         _Packet^.fChkSum[0] := CHAR( WData[0] );
         _Packet^.fChkSum[1] := CHAR( WData[1] );
      ELSIF _Packet^.ValueType = vtDigital THEN
         _Packet^.dChkSum[0] := CHAR( WData[0] );
         _Packet^.dChkSum[1] := CHAR( WData[1] );
      ELSE
         _Packet^.nChkSum[0] := CHAR( WData[0] );
         _Packet^.nChkSum[1] := CHAR( WData[1] );
      END;
   END ComputeCheckSum;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CheckSum( Packet : TPPacket; Length : CARDINAL ) : BOOLEAN;
   VAR
      chksum : CARD8;
      chksumToCheck : CARDINAL;
      chksumOffset : CARDINAL;
      i : CARDINAL;
      p : TPacket;
      WData : ARRAY [0..1] OF WCHAR;
   BEGIN
      CASE _PacketType OF
      | ptData :
         IF _Packet^.ValueType = vtDigital THEN
            // chksumOffset := FIELDOFS( TPacket.dChkSum ); -- m2cpp bug
            chksumOffset := CARDINAL( ADR( p.dChkSum )) - CARDINAL( ADR( p ));
            WData[0] := WCHAR( _Packet^.dChkSum[0] );
            WData[1] := WCHAR( _Packet^.dChkSum[1] );
         ELSE
            // chksumOffset := FIELDOFS( TPacket.nChkSum ); -- m2cpp bug
            chksumOffset := CARDINAL( ADR( p.nChkSum )) - CARDINAL( ADR( p ));
            WData[0] := WCHAR( _Packet^.nChkSum[0] );
            WData[1] := WCHAR( _Packet^.nChkSum[1] );
         END;
      | ptFillBuffer :
         // chksumOffset := FIELDOFS( TPacket.fChkSum ); -- m2cpp bug
         chksumOffset := CARDINAL( ADR( p.fChkSum )) - CARDINAL( ADR( p ));
         WData[0] := WCHAR( _Packet^.fChkSum[0] );
         WData[1] := WCHAR( _Packet^.fChkSum[1] );
      ELSE
         RETURN TRUE;
      END;

      Strings.ToINT32W( WData, 16, OUT chksumToCheck );
      
      chksum := 0;
      FOR i := 0 TO chksumOffset -1 DO
         INC( chksum, PCARD8( _Packet@[i] )^ );
      END;

      RETURN CARD8( chksumToCheck ) = chksum;
   END CheckSum;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Complete( KnownLength : CARDINAL; OUT FirstIndexAfterData, FirstIndexAfterFrame : CARDINAL; OUT ApplyChecksum : BOOLEAN ) : BOOLEAN;
   VAR
      complete : BOOLEAN;
   BEGIN
      IF ( _Packet = NIL ) OR ( KnownLength < 1 ) THEN
         RETURN FALSE;
      END;

      CASE _PacketType OF
      //-----
      | ptData :
         IF KnownLength < FIELDOFS( TPacket.ValueType ) + SIZE( TPacket.ValueType ) THEN
            RETURN FALSE;
         ELSIF _Packet^.ValueType = vtDigital THEN
            FirstIndexAfterData := FIELDOFS( TPacket.dChkSum );
            FirstIndexAfterFrame := FirstIndexAfterData + SIZE( TPacket.dChkSum );
         ELSE
            FirstIndexAfterData := FIELDOFS( TPacket.nChkSum );
            FirstIndexAfterFrame := FirstIndexAfterData + SIZE( TPacket.nChkSum );
         END;
      //-----
      | ptNoData, ptACK, ptNAK :
         FirstIndexAfterData := 1;
         FirstIndexAfterFrame := 1;
         complete := TRUE;
      //-----
      ELSE
         RETURN FALSE;
      END;

      complete := KnownLength >= FirstIndexAfterFrame;
   END Complete;

(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE SetPacketCharacters(); // _Packet MUST not be NIL
   BEGIN
      CASE _PacketType OF
      | ptDataRequest :
         _Packet^.ENQ := CH_ENQ;
      | ptData  :
         _Packet^.dSTX := CH_STX;
      | ptFillBuffer :
         _Packet^.fSTX := CH_STX;
         _Packet^.F := CH_F;
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
     D : nsitem.TPnsItem;
     I : ns.TPnsItem;
   BEGIN
      Root^.AddChild( CreateNewItem( L"Control", ns.ntName, iovalue.vtString, 0 ));

      D := nsitem.TPnsItem( CreateNewItem( L"Data", ns.ntName, iovalue.vtString, 0 ));
      Root^.AddChild( D );

      I := CreateNewItem( L"Inner T",           ns.ntValue, iovalue.vtFloat, 060011H ); D^.AddChild( I );
      I := CreateNewItem( L"Inner T setpoint",  ns.ntValue, iovalue.vtFloat, 060005H ); D^.AddChild( I );
      I := CreateNewItem( L"Return T",          ns.ntValue, iovalue.vtFloat, 030016H ); D^.AddChild( I );
      I := CreateNewItem( L"Return T setpoint", ns.ntValue, iovalue.vtFloat, 060004H ); D^.AddChild( I );

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
   Initialize();
END CNS;

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
      RETURN Connection.OpenS( _DeviceAddress, TRUE, 500 );
   END Start;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Stop();
   BEGIN
      Connection.Close();
      Logger.LogS( log.dldMessage, L"AirMotion", L"Stopped" );
   END Stop;

(*---------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnTimeout( Result : Sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR );
   VAR
      EmptyData : StorageO.CMemoryBuffer;
   BEGIN
      IF PoolHandle = _TxTimeoutHandle THEN
         Logger.LogS( log.dldTrace, L"", L"Tx timeout" );
         OnTx( Sync.arTimeout );
      ELSIF PoolHandle = _RxTimeoutHandle THEN
         Logger.LogS( log.dldTrace, L"", L"Rx timeout" );
         OnRx( Sync.arTimeout, EmptyData );
      END;
   END OnTimeout;

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
      Packet : CPacket;
   BEGIN
      IF Data.Length < 1 THEN
         RETURN FALSE;
      ELSE
         Packet.ReceivedPacket := Data.Data;
         RETURN Packet.Complete( Data.Length, OUT FirstIndexAfterData, OUT FirstIndexAfterData, OUT ApplyCheckSum );
      END;
   END DataComplete;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE TestChkSum( CONST Data : StorageO.AMemoryBuffer ) : BOOLEAN;
   VAR
      Packet : CPacket;
   BEGIN
      Packet.ReceivedPacket := Data.Data;
      RETURN Packet.TestChkSum();
   END TestChkSum;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnRx( Result : Sync.TAsyncResult; CONST Data : StorageO.AMemoryBuffer );
   VAR
      Packet : CPacket;
   BEGIN
      StopTimeout( REF _TxTimeoutHandle );
      IF Result <> Sync.arCompleted THEN
         StopTimeout( REF _RxTimeoutHandle );
         PIO^.OnRx( Result, NIL );
      ELSE
         Packet.ReceivedPacket := Data.Data;
         CASE Packet.Type OF
         | ptACK :
            PIO^.OnTxCON( Sync.arCompleted );
         | ptNAK :
            PIO^.OnTxCON( Sync.arAbort );
         ELSE
            StopTimeout( REF _RxTimeoutHandle );
            PIO^.OnRx( Sync.arCompleted, TPPacket( Data.Data ));
         END;
      END;
   END OnRx;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE AddChkSum( REF Data : StorageO.AMemoryBuffer );
   VAR
      Packet : CPacket;
   BEGIN
      Packet.PacketToSend := Data.Data;
      Packet.ComputeCheckSum();
   END AddChkSum;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnTx( Result : Sync.TAsyncResult );
   BEGIN
      IF Result <> Sync.arCompleted THEN
         PIO^.OnTxCON( Result );
      END;
   END OnTx;

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
         Log^.LogFilePos( log.dlcError, L"AirMotion", L"", OA( msg.Length-1, msg.rawData ), line, 0 );
      END LogError;

      (*----------*)

   VAR
      l : CARDINAL;
   BEGIN
      IF iniFile.SetSection( OA( iniFileSection.Length-1, iniFileSection.rawData )) THEN
         INIFile.ConfigureLog( iniFile, OA( iniFileSection.Length-1, iniFileSection.rawData ), REF Logger, OUT l );
         IF NOT iniFile.GetKeyStr( keyHost, OUT l, OUT _DeviceAddress ) THEN
            LogError( l, Texts._HostKeyMissing, NIL );
         END;
      ELSE
         LogError( 0, Texts._ConfigurationSectionMissing, ADR( iniFileSection ));
      END;
      RETURN Result;
   END Configure;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Tx( CONST Data : ARRAY OF BYTE; _SendAsIs : BOOLEAN; _RepeatCount : CARDINAL; _TxTimeout, _RxTimeout : CARDINAL );
   VAR
      c : CARDINAL;
      Result : Sync.TAsyncResult;
      TxBuffer : StorageO.CMemoryBuffer;
   BEGIN
      IF NOT Connection.Connected THEN
         Logger.LogS( log.dldTrace, L"", L"Disconnected, trying to reconnect" );
         Connection.OpenS( _DeviceAddress, TRUE, 500 );
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
   _RxTimeoutHandle := 0;
   _TxTimeoutHandle := 0;
   _PoolDelegate.TimeoutSink := ADR( SELF );
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
      RETURN DeviceCommunicator.Start();
   END Start;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Stop();
   BEGIN
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

   PUBLIC VIRTUAL PROCEDURE IOh( Direction : IOO.TDirection; Item : ns.THash; REF Value : iovalue.Value; Delegate : io.TPDataInfo ) : Sync.TAsyncResult;
   VAR
      Packet : TPacket;
   BEGIN
      IF _Pending <> IOO.dirUnknown THEN
         RETURN Sync.arAlreadyPending;
      END;

      _Pending := Direction;
      _Item := Item;
      _Callback := Delegate;

      Packet.Address := 0; // m2cpp error
      WITH Packet DO
         SenderType := dtController;
         Address := 0;
         ReceiverType := TDeviceType( LOPTRLONGWORD( nsitem.TPnsItem( Item )^.Data ) >> 16 );
         IF Direction = IOO.dirWrite THEN
            Telegram := ttSet;
         ELSE
            Telegram := ttGet;
         END;
         D1 := 0; // ??
         D2 := 0FAH; // ??
         PointNumber.LE := LOWORD( LOPTRLONGWORD( nsitem.TPnsItem( Item )^.Data ));
         IF Direction = IOO.dirWrite THEN
            IF TPNSI( Item )^.Multiplier = 1000 THEN
               D2 := 0FBH; // ??
               wValue.LE := 0;
            ELSIF TPNSI( Item )^.Multiplier = 1 THEN
               bValue := BYTE( Value.Integer );
            ELSE
               wValue.LE := WORD( Value.Float * LONGREAL( TPNSI( Item )^.Multiplier ));
            END;
         END;
      END;
      
      DeviceCommunicator.Tx( Packet, FALSE, 1, 150, 500 );
      // Serial.Tx( Packet, FALSE, 1, 0, 0 );

      RETURN Sync.arPending;
   END IOh;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE AbortAll();
   BEGIN
      DeviceCommunicator.Abort();
   END AbortAll;

(*---------------------------------------------------------------------------*)

   LOCAL PROCEDURE OnRx( Result : Sync.TAsyncResult; PPacket : TPPacket );
   VAR
      V : iovalue.Value;
   BEGIN
      IF _AbortFlag THEN
         _AbortFlag := FALSE;
         _Pending := IOO.dirUnknown;
         RETURN;
      ELSIF ( _Pending = IOO.dirWrite ) AND ( Result = Sync.arTimeout ) THEN
         // TODO
         // tiemouted write
      ELSIF ( _Pending <> IOO.dirRead ) OR ( _Callback = NIL ) THEN
         RETURN;
      ELSE
         _Pending := IOO.dirUnknown;
      END;
      IF Result = Sync.arCompleted THEN
         IF _Item^.Multiplier = 1 THEN
            V.Float := LONGREAL( PPacket^.bValue );
         ELSE
            V.Float := LONGREAL( PPacket^.wValue.LE ) / LONGREAL( _Item^.Multiplier );
         END;
         _Callback^.OnIO( IOO.dirRead, ADR( SELF ), OA( 0, ADR( Result )), OA( 0, ADR( _Item )), OA( -1, NIL ), OA( 0, ADR( V )));
      ELSIF _Pending = IOO.dirWrite THEN
         // TODO
         _Pending := IOO.dirUnknown;
         // TODO
         _Callback^.OnIO( IOO.dirWrite, ADR( SELF ), OA( 0, ADR( Result )), OA( 0, ADR( _Item )), OA( -1, NIL ), OA( 0, iovalue.TPValue( NIL )));
         _Callback^.OnError( IOO.dirWrite, ADR( SELF ), OA( 0, ADR( Result )), OA( 0, ADR( _Item )), OA( -1, NIL ));
      ELSE
         _Callback^.OnIO( IOO.dirRead, ADR( SELF ), OA( 0, ADR( Result )), OA( 0, ADR( _Item )), OA( -1, NIL ), OA( 0, iovalue.TPValue( NIL )));
         _Callback^.OnError( IOO.dirRead, ADR( SELF ), OA( 0, ADR( Result )), OA( 0, ADR( _Item )), OA( -1, NIL ));
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

   PUBLIC FINAL PROCEDURE OnDispose();
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