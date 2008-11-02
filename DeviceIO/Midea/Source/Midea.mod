IMPLEMENTATION MODULE Midea;

(*===========================================================================*)

FROM Debug IMPORT
   Assertion;

FROM Storage IMPORT
   ALLOCATE;
   
IMPORT
   FIO,
   IOO,
   Storage,
   StorageO,
   Strings,
   StringsO,
   Sync,
   windows;
   
IMPORT
   log;

IMPORT
   device,
   nsitem,
   io,
   iovalue,
   ns,
   serial;
   
(*===========================================================================*)

TYPE
   TTelegramType = CARD8(
      ttQuery = 0C0H, // and response too
      ttSet = 0C3H,
      ttModeLock = 0CAH, // data fan, TS, Mode
      ttModeUnlock = 0CBH, // empty data
      ttRemoteLock = 0CCH, // empty data
      ttRemoteUnlock = 0CDH // empty data
      // C5?, CE?, CF?
   );
   
#save, option( pack => 1 )
TYPE
   TOutPacket = RECORD
      Telegram  : TTelegramType;
      Target    : CARD16;
      Source    : CARD16;
      Mode      : TMode;
      FanSpeed  : TFanSpeed;
      TS        : CARD8;
      TimerOn   : CARD8;
      TimerOff  : CARD8;
      Aux       : TAux;
      Save      : CARD8;
      Recode    : CARD8;
      CheckCode : CARD8;
   END; // RECORD
   TPOutPacket = POINTER TO TOutPacket;
   
   TInPacket = RECORD
      Telegram      : TTelegramType;
      Target        : CARD16;
      Source        : CARD16;
      Type          : CARD16; // TType
      Mode          : TMode;
      IndoorStatus  : CARD8;
      TS            : CARD8;
      T1            : CARD8;
      T2A           : CARD8;
      T2B           : CARD8;
      T3            : CARD8;
      Electricity   : CARD8;
      Protect       : CARD16;
      NetError      : CARD8;
      HorsePower    : CARD8;
      Humidity      : CARD8;
      TimerOn       : CARD8;
      TimerOff      : CARD8;
      OutdoorStatus : CARD8;
      Aux           : CARD16;
      ACError       : CARD16;
      CheckCode     : CARD8;
   END; // RECORD
   TPInPacket = POINTER TO TInPacket;
#restore

(*===========================================================================*)

TYPE
   TItemType = (
      itMode,
      itFan,
      itSetTemperature
   );

CLASS CNSI( nsitem.CnsItem );
   LOCAL VAR
      Type : TItemType;
END CNSI;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CNSI;
BEGIN
   Type := itMode;
END CNSI;

(*===========================================================================*)

CLASS IMPLEMENTATION CNS;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE CreateRoot() : ns.TPnsItem;
   BEGIN
      RETURN NewItem( L"MideaAC", ns.ntName, iovalue.vtString, 0 );
   END CreateRoot;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE CreateStructure();
   VAR
      AC, CCM, D, I, T : TPNSI;
      i, j : CARDINAL;
      s : ARRAY [0..31] OF WCHAR;
   BEGIN
      Root^.AddChild( NewItem( L"Control", ns.ntName, iovalue.vtString, 0 ));

      D := NewItem( L"Type", ns.ntName, iovalue.vtString, 0 );
      Root^.AddChild( D );
         T := NewItem( L"Mode", ns.ntName, iovalue.vtString, 0 ); D^.AddChild( T );
            // DBG
            I := NewItem( L"xx", ns.ntName, iovalue.vtString, 0 ); T^.AddChild( I );

            I := NewItem( L"auto", ns.ntName, iovalue.vtString, 0 ); T^.AddChild( I );
            I := NewItem( L"heat", ns.ntName, iovalue.vtString, 0 ); T^.AddChild( I );
            I := NewItem( L"cool", ns.ntName, iovalue.vtString, 0 ); T^.AddChild( I );
            I := NewItem( L"fan", ns.ntName, iovalue.vtString, 0 ); T^.AddChild( I );
         T := NewItem( L"Fan", ns.ntName, iovalue.vtString, 0 ); D^.AddChild( T );
            I := NewItem( L"auto", ns.ntName, iovalue.vtString, 0 ); T^.AddChild( I );
            I := NewItem( L"high", ns.ntName, iovalue.vtString, 0 ); T^.AddChild( I );
            I := NewItem( L"middle", ns.ntName, iovalue.vtString, 0 ); T^.AddChild( I );
            I := NewItem( L"low", ns.ntName, iovalue.vtString, 0 ); T^.AddChild( I );

      D := NewItem( L"Data", ns.ntName, iovalue.vtString, 0 );
      Root^.AddChild( D );

      CCM := NewItem( L"All", ns.ntName, iovalue.vtString, 0 ); D^.AddChild( CCM );

      I := NewItem( L"Mode", ns.ntValue, iovalue.vtString, 0FFFFH ); CCM^.AddChild( I );
         I^.Type := itMode;
      I := NewItem( L"Fan", ns.ntValue, iovalue.vtString, 0FFFFH ); CCM^.AddChild( I );
         I^.Type := itFan;
      I := NewItem( L"SetTemperature", ns.ntValue, iovalue.vtInteger, 0FFFFH ); CCM^.AddChild( I );
         I^.Type := itSetTemperature;
      
      FOR i := 0 TO 15 DO // CCM
         Strings.FromCARD32W( i, 10, OUT s );
         CCM := NewItem( s, ns.ntName, iovalue.vtString, 0 ); D^.AddChild( CCM );

         AC := NewItem( L"All", ns.ntName, iovalue.vtString, 0 ); CCM^.AddChild( AC );

         // I := NewItem( L"Connected", ns.ntValue, iovalue.vtBoolean, 0 ); AC^.AddChild( I );
         I := NewItem( L"Mode", ns.ntValue, iovalue.vtString, i << 8 + 0FFH ); AC^.AddChild( I );
            I^.Type := itMode;
         I := NewItem( L"Fan", ns.ntValue, iovalue.vtString, i << 8 + 0FFH ); AC^.AddChild( I );
            I^.Type := itFan;
         I := NewItem( L"SetTemperature", ns.ntValue, iovalue.vtInteger, i << 8 + 0FFH ); AC^.AddChild( I );
            I^.Type := itSetTemperature;

         FOR j := 0 TO 63 DO // AC
            Strings.FromCARD32W( j, 10, OUT s );
            AC := NewItem( s, ns.ntName, iovalue.vtString, 0 ); CCM^.AddChild( AC );

            // I := NewItem( L"Connected", ns.ntValue, iovalue.vtBoolean, 0 ); AC^.AddChild( I );
            I := NewItem( L"Mode", ns.ntValue, iovalue.vtString, i << 8 + j ); AC^.AddChild( I );
               I^.Type := itMode;
            I := NewItem( L"Fan", ns.ntValue, iovalue.vtString, i << 8 + j ); AC^.AddChild( I );
               I^.Type := itFan;
            I := NewItem( L"SetTemperature", ns.ntValue, iovalue.vtInteger, i << 8 + j ); AC^.AddChild( I );
               I^.Type := itSetTemperature;

         END; // FOR j
      END; // FOR i
   END CreateStructure;

(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE NewItem( CONST Name : ARRAY OF WCHAR; NType : ns.TNameType; VType : iovalue.TValueType; Data : PTR ) : TPNSI;
   VAR
      R : TPNSI;
   BEGIN
      NEW( R )^.Init( Name, ConstNames, NType, VType, Data );
      RETURN R;
   END NewItem;

(*---------------------------------------------------------------------------*)

BEGIN
   Midea := NIL;
   Initialize();
END CNS;

(*===========================================================================*)

CLASS IMPLEMENTATION CSerial;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE DataComplete( CONST Data : StorageO.AMemoryBuffer; OUT FirstIndexAfterData, FirstIndexAfterFrame : CARDINAL; OUT ApplyCheckSum : BOOLEAN ) : BOOLEAN;
   BEGIN
      IF Data.Length < 1 + SIZE( TInPacket ) + 2 + 1 THEN // start, crc+stop, 1 unknown bytes
         RETURN FALSE;
      END;
      FirstIndexAfterData := 1 + SIZE( TInPacket );
      FirstIndexAfterFrame := 1 + SIZE( TInPacket ) + 2 + 1;
      ApplyCheckSum := TRUE;
      RETURN TRUE;
   END DataComplete;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE TestChkSum( CONST Data : StorageO.AMemoryBuffer ) : BOOLEAN;
   VAR
      CRC : CARD8 := 0;
      i : CARDINAL;
      l : CARDINAL := Data.Length-2;
   BEGIN
      FOR i := 1 TO l-1 DO // omit first and last two bytes
         INC( CRC, PCARD8( Data.Data@[i] )^ );
      END; // FOR
      RETURN PBYTE( Data.Data@[l] )^ = BYTE( 1 + NOT CRC );
   END TestChkSum;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnRx( Result : Sync.TAsyncResult; CONST Data : StorageO.AMemoryBuffer );
   BEGIN
      IF Result = Sync.arCompleted THEN
         PIO^.OnRx( Sync.arCompleted, TPInPacket( Data.Data ));
      ELSE
         PIO^.OnRx( Result, NIL );
      END;
   END OnRx;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE AddChkSum( REF Data : StorageO.AMemoryBuffer );
   VAR
      CRC : CARD8 := 0;
      i : CARDINAL;
      l : CARDINAL := Data.Length-2;
   BEGIN
      FOR i := 1 TO l-1 DO // omit first and last two bytes
         INC( CRC, PCARD8( Data.Data@[i] )^ );
      END; // FOR
      PBYTE( Data.Data@[l] )^ := 1 + NOT CRC;
   END AddChkSum;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnTx( Result : Sync.TAsyncResult );
   BEGIN
      PIO^.OnTxCON( Result );
   END OnTx;

(*---------------------------------------------------------------------------*)

BEGIN
   PIO := NIL;
   SetInBoundaryStrings( CHAR( 0AAH ), CHAR( 055H ));
   SetOutBoundaryStrings( CHAR( 0AAH ), CHAR( 055H ));
END CSerial;

(*===========================================================================*)

CLASS IMPLEMENTATION CIO;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Running GET : BOOLEAN;
   BEGIN
     // TODO
     RETURN FALSE;
   END Running;

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

   PUBLIC PROCEDURE Dispose();
   BEGIN
      Serial.Dispose();
   END Dispose;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run() : Sync.TAsyncResult;
   BEGIN
      Serial.Run();
      RETURN Sync.arCompleted;
   END Run;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Stop();
   BEGIN
      Serial.Stop();
   END Stop;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE IOh( Direction : IOO.TDirection; Item : ns.THash; REF Value : iovalue.Value; DataInfo : io.TPDataInfo ) : Sync.TAsyncResult;
   VAR
      Data : TPData;
      i, j : INTEGER;
      Packet : TOutPacket;
      Target : CARD16;
   BEGIN
      IF ( Item = 0 ) OR ( TPNSI( Item )^.NameType <> ns.ntValue ) THEN
         RETURN Sync.arCannotStart;
      ELSIF _Pending <> IOO.dirUnknown THEN
         RETURN Sync.arAlreadyPending;
      END;

      _Pending := Direction;
      _Item := Item;
      _DataInfo := DataInfo;

      Target := CARD16( LOPTRLONGWORD( _Item^.Data ));
      Data := Midea^.TargetToData( Target );
      
      CASE _Item^.Type OF
      | itMode :
         IF Value.EqualsOA( L"heat" ) THEN
            Data^.Mode := TMode{mdHeat};
         ELSIF Value.EqualsOA( L"cool" ) THEN
            Data^.Mode := TMode{mdCool};
         ELSIF Value.EqualsOA( L"fan" ) THEN
            Data^.Mode := TMode{mdFan};
         ELSIF Value.EqualsOA( L"auto" ) THEN
            // TODO

         ELSIF Value.EqualsOA( L"xx" ) THEN
            Data^.Mode := TMode{mdXX};
            // TODO
         END;
         
         // TODO: OK
         INCL( Data^.Mode, mdOn );
         
      | itFan :
         IF Value.EqualsOA( L"high" ) THEN
            Data^.FanSpeed := TFanSpeed{fsHigh};
         ELSIF Value.EqualsOA( L"middle" ) THEN
            Data^.FanSpeed := TFanSpeed{fsMiddle};
         ELSIF Value.EqualsOA( L"low" ) THEN
            Data^.FanSpeed := TFanSpeed{fsLow};
         ELSIF Value.EqualsOA( L"auto" ) THEN
            Data^.FanSpeed := TFanSpeed{fsAuto};
         END;

         // TODO
         Data^.Mode := TMode{mdHeat, mdOn};

      | itSetTemperature :
         Data^.SetTemperature := CARD8( Value.LimitedInteger( 5, FALSE, TRUE ));

      END;

      IF HIBYTE( Target ) = 0FFH THEN
         FOR i := 1 TO 16 DO FOR j := 1 TO 64 DO
            Midea^._ACS[i,j] := Data^;
         END; END;
      ELSIF LOBYTE( Target ) = 0FFH THEN
         FOR j := 1 TO 64 DO
            Midea^._ACS[CARDINAL(LOBYTE( Target )),j] := Data^;
         END; // outer FOR
      END;

      Packet.Telegram := ttSet;
      
      Packet.Recode := 0FFH - CARD8( Packet.Telegram );
      Packet.Target := Target;
      Packet.Source := 08080H;
      Packet.Mode := Data^.Mode;
      Packet.FanSpeed := Data^.FanSpeed;
      Packet.TS := Data^.SetTemperature;
      Packet.TimerOn := 0;
      Packet.TimerOff := 0;
      Packet.Aux := Data^.Aux;
      Packet.Save := 0;
      
      Serial.Tx( Packet, FALSE, 1, 150, 500 );
      // Serial.Tx( Packet, FALSE, 1, 0, 0 );

      RETURN Sync.arPending;
   END IOh;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Abort();
   BEGIN
      _AbortFlag := TRUE;
   END Abort;

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
      ELSIF ( _Pending <> IOO.dirRead ) OR ( _DataInfo = NIL ) THEN
         RETURN;
      ELSE
         _Pending := IOO.dirUnknown;
      END;
      
      // DBG
		log.logger()^.LogSCB( Log.dldTrace, L'', L'rx ', SIZE( PPacket^ ), PPacket, SIZE( PPacket^ ));
      
      IF Result = Sync.arCompleted THEN
         _DataInfo^.OnIO( IOO.dirRead, ADR( SELF ), OA( 0, ADR( Result )), OA( 0, ADR( _Item )), OA( 0, ADR( V )));
      ELSIF _Pending = IOO.dirWrite THEN
         // TODO
         _Pending := IOO.dirUnknown;
         // TODO
         _DataInfo^.OnIO( IOO.dirWrite, ADR( SELF ), OA( 0, ADR( Result )), OA( 0, ADR( _Item )), OA( 0, iovalue.TPValue( NIL )));
         _DataInfo^.OnError( IOO.dirWrite, ADR( SELF ), OA( 0, PCARDINAL( ADR( Result ))), OA( 0, ADR( _Item )));
      ELSE
         _DataInfo^.OnIO( IOO.dirRead, ADR( SELF ), OA( 0, ADR( Result )), OA( 0, ADR( _Item )), OA( 0, iovalue.TPValue( NIL )));
         _DataInfo^.OnError( IOO.dirRead, ADR( SELF ), OA( 0, PCARDINAL( ADR( Result ))), OA( 0, ADR( _Item )));
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
         _DataInfo^.OnIO( IOO.dirWrite, ADR( SELF ), OA( 0, ADR( Result )), OA( 0, ADR( _Item )), OA( 0, iovalue.TPValue( NIL )));
      ELSE
         _DataInfo^.OnIO( IOO.dirWrite, ADR( SELF ), OA( 0, ADR( Result )), OA( 0, ADR( _Item )), OA( 0, iovalue.TPValue( NIL )));
         _DataInfo^.OnError( IOO.dirWrite, ADR( SELF ), OA( 0, PCARDINAL( ADR( Result ))), OA( 0, ADR( _Item )));
      END;
   END OnTxCON;

(*---------------------------------------------------------------------------*)

BEGIN
   Serial.PIO := ADR( SELF );
   Midea := NIL;
   _AbortFlag := FALSE;
   _Pending := IOO.dirUnknown;
   _DataInfo := NIL;
   _Item := NIL;
FINALLY
   Dispose();
END CIO;

(*===========================================================================*)

CLASS IMPLEMENTATION CMideaDevice;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY Type GET : objlib.TObjectType;
   BEGIN
      RETURN objlib.otEphemeral;
   END Type;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY Library GET : objlib.TPLibrary;
   BEGIN
      RETURN SUPER.Library;
   END Library;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY Library SET( Value : objlib.TPLibrary );
   BEGIN
      SUPER.Library := Value;
   END Library;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROCEDURE Dispose();
   BEGIN
      _IO.Dispose();
   END Dispose;

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

	PUBLIC VIRTUAL PROCEDURE Configure( CONST Source : ARRAY OF PTR; CONST log : Log.TPLogger ) : Sync.TAsyncResult;
   BEGIN
      IF _IO.Serial.Init( "COM", OAsz( PWCHAR( Source[0] )), L"SerialWin32.DLL", OAsz( PWCHAR( Source[1] )), log ) THEN
         RETURN Sync.arCompleted;
      ELSE
         RETURN Sync.arCannotStart;
      END;
   END Configure;
   
(*---------------------------------------------------------------------------*)

	LOCAL PROCEDURE TargetToData( Target : CARD16 ) : TPData;
	VAR
	   CCM, AC : CARDINAL;
	BEGIN
	   IF HIBYTE( Target ) = 0FFH THEN
	      CCM := 0;
	   ELSE
	      CCM := CARDINAL( HIBYTE( Target ));
	   END;
	   IF LOBYTE( Target ) = 0FFH THEN
	      AC := 0;
	   ELSE
	      AC := CARDINAL( LOBYTE( Target ));
	   END;
	   RETURN ADR( _ACS[CCM,AC] );
	END TargetToData;

(*---------------------------------------------------------------------------*)

   INITIALLY CMideaDevice();
   VAR
      i, j : CARDINAL;
   BEGIN
      _NS.Midea := ADR( SELF );
      _IO.Midea := ADR( SELF );
      FOR i := 0 TO 16 DO FOR j := 0 TO 64 DO
         WITH _ACS[i,j] DO
            Mode := TMode{};
            FanSpeed := TFanSpeed{fsAuto};
            SetTemperature := 24;
            Aux := TAux{};
         END; // WITH
      END; END;
   END CMideaDevice;

(*---------------------------------------------------------------------------*)

   FINALLY CMideaDevice();
   BEGIN
      _IO.Stop();
      Dispose();
   END CMideaDevice;

(*---------------------------------------------------------------------------*)

END CMideaDevice;

(*===========================================================================*)

END Midea.