MODULE driver;

(*================================================================================*)

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   cphcommon,
   diface,
   drv_def,
   iovalue,
   log,
   Resources,
   Rijndael,
   StringsO,
   Texts;

(*================================================================================*)

VAR
   dr : Resources.CResources;

PROCEDURE DR() : Resources.TPResources;
BEGIN
   RETURN ADR( dr );
END DR;

(*================================================================================*)

TYPE
   TPPojCryptDriver = POINTER TO CPojCryptDriver;

CLASS CPojCryptDriver IMPLEMENTS diface.ICWDriver;
   CallbackId   : ADDRESS;
   CallbackProc : drv_def.TDriverCallbackW;
   ClientName   : ARRAY [0..63] OF WCHAR;

   // ICWDriver
   PUBLIC VIRTUAL PROCEDURE Initialize( RunMode : CARDINAL; CONST SymbolicName : StringsO.CString; CallbackId : ADDRESS; CallbackProc : drv_def.TDriverCallbackW );
   PUBLIC VIRTUAL PROCEDURE ReadParameters( CONST ParFilePath : StringsO.CString; CONST Logger : log.CLogger ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE QueryErrorCode( ErrorCode : CARDINAL; OUT ErrorText : StringsO.CString ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE EnumerateChannels( REF EnumerateState : LONGWORD; OUT Type : drv_def.TValueType; OUT Direction : drv_def.TDirection; OUT DriverIndex, Count : CARDINAL; OUT HaveDescription : BOOLEAN ): BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE GetChannelDescription( DriverIndex : CARDINAL; OUT Description, Id : StringsO.CString ) : BOOLEAN;
   
   PUBLIC VIRTUAL PROCEDURE DriverRun();
   PUBLIC VIRTUAL PROCEDURE DriverStop();
   PUBLIC VIRTUAL PROCEDURE Dispose();

   PUBLIC VIRTUAL PROCEDURE DriverProc( Func, Param1, Param2, Param3, Param4 : CARDINAL );
   PUBLIC VIRTUAL PROCEDURE QueryProc( CONST InValue1, InValue2 : iovalue.Value; OutValueStringLimit : CARDINAL; OUT OutValue : iovalue.Value );

   PUBLIC VIRTUAL PROCEDURE InputRequestStart();
   PUBLIC VIRTUAL PROCEDURE InputRequest( DriverIndex : CARDINAL );
   PUBLIC VIRTUAL PROCEDURE InputRequestCompleted();
   PUBLIC VIRTUAL PROCEDURE InputFinalized( DriverIndex : CARDINAL; OUT ErrorCode : CARDINAL ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE InputOOBDataQuery( REF EnumerateState : LONGWORD; OUT DriverIndex : CARDINAL ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE GetInput( DriverIndex : CARDINAL; InValueStringLimit : CARDINAL; OUT InValue : iovalue.Value; OUT QoS : CARDINAL; OUT TimeStamp : drv_def.TUTCStamp; OUT ErrorCode : CARDINAL );

   PUBLIC VIRTUAL PROCEDURE OutputRequestStart();
   PUBLIC VIRTUAL PROCEDURE OutputRequest( DriverIndex : CARDINAL; CONST OutValue : iovalue.Value; QoS : CARDINAL; CONST TimeStamp : drv_def.TUTCStamp );
   PUBLIC VIRTUAL PROCEDURE OutputRequestCompleted();
   PUBLIC VIRTUAL PROCEDURE OutputFinalized( DriverIndex : CARDINAL; OUT ErrorCode : CARDINAL ) : BOOLEAN;
END CPojCryptDriver;

(*================================================================================*)

CLASS IMPLEMENTATION CPojCryptDriver;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Initialize( RunMode : CARDINAL; CONST SymbolicName : StringsO.CString; CallbackId : ADDRESS; CallbackProc : drv_def.TDriverCallbackW );
   BEGIN
      SELF.CallbackId := CallbackId;
      SELF.CallbackProc := CallbackProc;
      SymbolicName.ToOA( OUT ClientName );
   END Initialize;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE ReadParameters( CONST ParFilePath : StringsO.CString; CONST Logger : log.CLogger ) : BOOLEAN;
   BEGIN
      RETURN TRUE;
   END ReadParameters;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE EnumerateChannels( REF EnumerateState : LONGWORD; OUT Type : drv_def.TValueType; OUT Direction : drv_def.TDirection; OUT DriverIndex, Count : CARDINAL; OUT HaveDescription : BOOLEAN ): BOOLEAN;
   BEGIN
      RETURN FALSE;
   END EnumerateChannels;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE GetChannelDescription( DriverIndex : CARDINAL; OUT Description, Id : StringsO.CString ) : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END GetChannelDescription;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE QueryErrorCode( ErrorCode : CARDINAL; OUT ErrorText : StringsO.CString ) : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END QueryErrorCode;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE DriverRun();
   BEGIN
   END DriverRun;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE DriverStop();
   BEGIN
   END DriverStop;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   BEGIN
   END Dispose;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE InputRequestStart();
   BEGIN
   END InputRequestStart;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE InputRequest( DriverIndex : CARDINAL );
   BEGIN
   END InputRequest;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE InputRequestCompleted();
   BEGIN
   END InputRequestCompleted;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE InputFinalized( DriverIndex : CARDINAL; OUT ErrorCode : CARDINAL ) : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END InputFinalized;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE InputOOBDataQuery( REF EnumerateState : LONGWORD; OUT DriverIndex : CARDINAL ) : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END InputOOBDataQuery;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE GetInput( DriverIndex : CARDINAL; InValueLimit : CARDINAL; OUT InValue : iovalue.Value; OUT QoS : CARDINAL; OUT TimeStamp : drv_def.TUTCStamp; OUT ErrorCode : CARDINAL );
   BEGIN
      QoS := drv_def.qosBad;
      ErrorCode := drv_def.ecUnknownElement;
   END GetInput;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OutputRequestStart();
   BEGIN
   END OutputRequestStart;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OutputRequest( DriverIndex : CARDINAL; CONST OutValue : iovalue.Value; QoS : CARDINAL; CONST TimeStamp : drv_def.TUTCStamp );
   BEGIN
   END OutputRequest;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OutputRequestCompleted();
   BEGIN
   END OutputRequestCompleted;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OutputFinalized( DriverIndex : CARDINAL; OUT ErrorCode : CARDINAL ) : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END OutputFinalized;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE DriverProc( Func, Param1, Param2, Param3, Param4 : CARDINAL );
   BEGIN
   END DriverProc;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE QueryProc( CONST InValue1, InValue2 : iovalue.Value; OutValueLimit : CARDINAL; OUT OutValue : iovalue.Value );
   LABEL
      Done;
   VAR
      c, l : CARDINAL;
      CS : StringsO.CString;
      Data : ARRAY [0..1023] OF BYTE;
      DataLength : CARDINAL;
      DataUTF8 : ARRAY[0..1023] OF CHAR;
      DataUTF8Length : CARDINAL;
      Key, IV : ARRAY [0..255] OF BYTE;
      KeyLength, IVLength : CARDINAL;
      Parameters : ARRAY [0..2] OF StringsO.CString;
   BEGIN
      CS := InValue1.String;
      CS.SplitS( StringsO.WCHARS{ L' ' }, 0, TRUE, OUT c, OUT Parameters );

      // Parameters[0] = encrypt/decrypt, Parameters[1] = Key, Parameters[2] = IV, Parameters[3] = text
      IF Parameters[0].EqualsOA( L'encrypt' ) THEN
         // OK
      ELSIF Parameters[0].EqualsOA( L'decrypt' ) THEN
         // OK
      ELSE
         CS.FromOA( L'error: unknown driver procedure' );
         GOTO Done;
      END;

      IF Parameters[1].Empty THEN
         CS.FromOA( L'error: missing KEY' );
         GOTO Done;
      ELSIF Parameters[2].Empty THEN
         CS.FromOA( L'error: missing IV' );
         GOTO Done;
      END;
      
      IF NOT cphcommon.FromHex( OA( Parameters[1].Length-1, Parameters[1].Data ), OUT Key, OUT KeyLength ) THEN
         CS.FromOA( L'error: bad KEY format' );
         GOTO Done;
      ELSIF NOT cphcommon.FromHex( OA( Parameters[2].Length-1, Parameters[2].Data ), OUT IV, OUT IVLength ) THEN
         CS.FromOA( L'error: bad IV format' );
         GOTO Done;
      END;

      // empty string is converted to empty string
      CS := InValue2.String;
      IF CS.Empty THEN
         GOTO Done;
      END;

      //=====
      IF Parameters[0].EqualsOA( L'encrypt' ) THEN
         CS.ToUTF8( OUT DataUTF8, OUT l );
         DataUTF8Length := ( l + 15 ) AND 0FFFFFFF0H;
         FOR c := l TO MIN2( HIGH( DataUTF8 ), DataUTF8Length-1 ) DO
            DataUTF8[c] := 10C;
         END;

         IF NOT Rijndael.Encrypt( Rijndael.cphmCBCe, Rijndael.rkl256, OA( KeyLength-1, ADR( Key )), OA( IVLength-1, ADR( IV )), OA( DataUTF8Length-1, ADR( DataUTF8 )), OUT Data, OUT DataLength ) THEN
            CS.FromOA( L'error: encryption failed' );
            GOTO Done;
         END;
         
         CS.Size := 2*DataLength;
         CS.Length := 2*DataLength;
         cphcommon.ToHex( OA( DataLength-1, ADR( Data )), OUT OA( CS.Length-1, PWCHAR( CS.Data )));
         
      //=====
      ELSIF Parameters[0].EqualsOA( L'decrypt' ) THEN
         IF NOT cphcommon.FromHex( OA( CS.Length-1, CS.Data ), OUT Data, OUT DataLength ) THEN
            CS.FromOA( L'error: bad DATA format' );
            GOTO Done;
         END;

         IF NOT Rijndael.Decrypt( Rijndael.cphmCBCd, Rijndael.rkl256, OA( KeyLength-1, ADR( Key )), OA( IVLength-1, ADR( IV )), OA( DataLength-1, ADR( Data )), OUT DataUTF8, OUT DataUTF8Length ) THEN
            CS.FromOA( L'error: decryption failed' );
            GOTO Done;
         END;
         
         CS.FromUTF8( OA( DataUTF8Length-1, ADR( DataUTF8 )));

      //=====
      // ELSE solved on top
      END;

   Done:
      OutValue.String := CS;
   END QueryProc;

(*--------------------------------------------------------------------------------*)

BEGIN
   CallbackId := NIL;
   CallbackProc := NIL;
   ClientName := L"";
END CPojCryptDriver;

(*================================================================================*)

CLASS CFactory IMPLEMENTS diface.ICWDriverFactory;
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
      Name.FromOA( OAsz( DR()^[ Texts._DriverName ] ));
      RETURN Name;
   END DriverName;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CreateInstance( OUT Instance : diface.TPCWDriver ) : BOOLEAN;
   VAR
      Driver : TPPojCryptDriver;
   BEGIN
      NEW( Driver );
      Instance := Driver;
      RETURN TRUE;
   END CreateInstance;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE DeleteInstance( Instance : diface.TPCWDriver );
   VAR
      Driver : TPPojCryptDriver := TPPojCryptDriver( Instance );
   BEGIN
      DISPOSE( Driver );
   END DeleteInstance;

(*--------------------------------------------------------------------------------*)

END CFactory;

(*--------------------------------------------------------------------------------*)

VAR
   Factory : CFactory;

(*--------------------------------------------------------------------------------*)

BEGIN
   dr.LoadRES2( EMITW( %dll ), L"CPojCrypt.Texts" );
   diface.RegisterFactory( ADR( Factory ));
END driver.

(*================================================================================*)
