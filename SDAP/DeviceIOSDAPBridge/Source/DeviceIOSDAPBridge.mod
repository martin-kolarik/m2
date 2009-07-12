IMPLEMENTATION MODULE DeviceIOSDAPBridge;

IMPORT
   FIO,
   INIFile;

(*================================================================================*)

TYPE
   TPItem = POINTER TO CItem;

CLASS CItem;
   PUBLIC VAR
      Direction : IOO.TDirection; // read means read "from device"
      Device : device.TPDevice;
      SDAPName : Strings.CString;
      Hash : ns.TPHash;
END CItem;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CItem;
BEGIN
   Direction := IOO.dirRead;
   Device := 0;
   Hash := 0;
END CItem;

(*================================================================================*)

CLASS IMPLEMENTATION ABridge;

(*--------------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE Configure( CONST Source : ARRAY OF device.TConfigureItem; CONST Log : log.TPLogger ) : Sync.TAsyncResult;
	CONST
	   DEVICE_CLASS_NAME_SUFFIX = L"/IO.Device";
   CONST
	   secDevices      = L"devices";
	   secDevicePrefix = L"device_";
	      keyLibrary   = L"library";
	   secDeviceToSDAP = L"device_to_DSAP";
	      keyPeriod    = L"period";
	   secSDAP         = L"SDAP";
	      keyHost      = L"host";
	   secSDAPToDevice = L"SDAP_to_device";
	VAR
	   dev : device.TPDevice;
	   devices : maps.CStringStringList;
	   devPath, exePath : FIO.PathStrW;
	   iniFile : INIFile.TPINIFile;
	   nameDevMap : maps.CStringMap;
	   key : ARRAY [0..127] OF WCHAR;
	   l : CARDINAL;
	   Result : Sync.TAsyncResult;
	   s : StringsO.CString;
	   value : StringsO.CString;
	   
	   (*----------*)
	   
	   PROCEDURE GetHash( CONST input : ARRAY OF WCHAR; OUT dev : device.TPDevice; OUT hash : ns.THash ) : BOOLEAN;
	   CONST
	      charSplit = Strings.WCHARS{ L"." };
	   VAR
	      dataName : StringsO.CString;
	      i : CARDINAL;
	      inputS : StringsO.CString;
	   BEGIN
	      inputs.FromOA( input );
	      i := inputS.ItemS( charSplit, 0, 0, OUT deviceName );
	      IF i = -1 THEN
	         RETURN FALSE;
	      END;
	      inputS.Delete( i+1, -1 );
	      IF inputS.Empty THEN
	         RETURN FALSE;
	      ELSIF NOT nameDevMap.Get( deviceName, OUT dev ) THEN
	         RETURN FALSE;
	      ELSIF NOT dev^.Mapper()^.NameToHash( inputS, OUT hash ) THEN
	         RETURN FALSE;
	      ELSE
	         RETURN TRUE;
	      END;
	   END GetHash;
	   
	   (*----------*)
	   
	   PROCEDURE LogError( line : CARDINAL; errorText : CARDINAL; addonText : StringsO.TPString );
	   VAR
	      msg : StringsO.CString;
	   BEGIN
	      msg.FromOA( OAsz( R[errorText] ));
	      IF addonText <> NIL THEN
	         msg.Append( addonText^ );
	      END;
	      Log^.LogFilePos( log.dlcError, L"SDAP Bridge", L"", OA( msg.Length-1, msg.rawData ), line, 0 );
	   END LogError;

	   (*----------*)

	BEGIN
	   Dispose();
	   
	   IF Log = NIL THEN
	      RETURN Sync.arCannotStart;
	   ELSIF HIGH( Source ) < 0 THEN
	      RETURN Sync.arCannotStart;
	   ELSIF Source[0].Type <> citINIFile THEN
	      RETURN Sync.arCannotStart;
	   ELSE
	      iniFile := Source^.iniFile;
	   END;

      // SDAP
      IF iniFile^.SetSection( secSDAP ) THEN
         IF iniFile^.GetKeyStr( keyHost, OUT l, OUT _SDAPHost ) THEN
            // OK
         ELSE
            LogError( 0, Texts._HostKeyOfSDAPSectionMissing, NIL );
         END;
      ELSE
         LogError( 0, Texts._SDAPSectionMissing, NIL );
      END;
      
      // devices
      IF iniFile^.SetSection( secDevices ) THEN
         ES := 0;
         WHILE iniFile^.EnumerateKeys( REF ES, OUT l, OUT key, OUT value ) DO
            devices.AddOA( key, value );
         END; // WHILE
      END;

      FIO.GetModuleDirW( L"", OUT exePath );
      
      devices.Reset();
      WHILE devices.MoveNext() DO

         IF nameDevMap.Contains( devices^.Current^ ) THEN
            LogError( 0, Texts._DeviceAlreadyExists, devices^.Current );
            CONTINUE;
         END;

         deviceId.FromOA( secDevicePrefix );
         deviceId.Append( devices.Current )^ );
         IF NOT iniFile^.SetSection( OA( deviceId^.Length-1, deviceId^.rawData )) THEN
            LogError( 0, Texts._DeviceSectionMissing, ADR( deviceId ));
            CONTINUE;
         ELSIF NOT iniFile^.GetKeyStr( keyLibrary, OUT l, OUT value ) THEN
            LogError( 0, Texts._LibraryKeyOfDeviceSectionMissing, ADR( deviceId ));
            CONTINUE;
         END;   
         
         FIO.MakePathW( exePath, OA( value.Length-1, value.rawData ), OUT devPath );
         Loader.AddLibrary( devPath, value ); // value contains LibraryName
         value.AppendOA( DEVICE_CLASS_NAME_SUFFIX );
         CASE Loader.CreateObject( OA( value.Length-1, value.rawData ), OUT dev ) OF
         //----
         | iobject.lrSuccess :
            src.Type := device.citInitFileSection;
            src._iniFile := iniFile;
            src.section := ADR( deviceId );
            IF dev^.Configure( OA( 0, ADR( src )), Log ) = Sync.arCompleted THEN
               _Devices.Add( devices.CurrentData^, dev );
               nameDevMap.Add( deviceId, dev );
            ELSE
               Loader.ReleaseObject( dev );
               Result := Sync.arAbort;
            END;
         //----
         | lrLibraryNotFound :
            s.FromOA( devPath );
            LogError( l, Texts._LibraryNotFound, ADR( s ));
         //----
         | lrLibraryFoundButIsUnloadable :
            s.FromOA( devPath );
            LogError( l, Texts._LibraryUnloadable, ADR( s ));
         //----
         | lrLibraryDisabled :
            s.FromOA( devPath );
            LogError( l, Texts._LibraryDisable, ADR( s ));
         //----
         | lrClassNotFound :
            s.FromOA( devPath );
            LogError( l, Texts._LibraryClassNotFound, ADR( s ));
         END; // CASE
         
      END; // WHILE
      
      // data
      IF INIFile.SetSection( secSDAPToDevice ) THEN // deviceId = sdapId
         ES := 0;
         WHILE iniFile^.EnumerateKeys( REF ES, OUT l, OUT key, OUT value ) DO
            IF NOT GetHash( key, OUT dev, OUT hash ) THEN
               s.FromOA( key );
               LogError( l, Texts._DataItemNotFound, ADR( s ));
               CONTINUE;
            END;
            
            NEW( item );
            item^.Direction := IOO.dirWrite;
            item^.Device := dev;
            item^.Hash := hash;
            item^.SDAPName.Assign( value );
            
            _Data.Add( item, 0 );
         END; // WHILE
      END;

      IF INIFile.SetSection( secDeviceToSDAP ) THEN // sdapId = deviceId
         ES := 0;
         WHILE iniFile^.EnumerateKeys( REF ES, OUT l, OUT key, OUT value ) DO
            IF NOT GetHash( OA( value.Length-1, value.rawData ), OUT dev, OUT hash ) THEN
               LogError( l, Texts._DataItemNotFound, ADR( value ));
               CONTINUE;
            END;
            
            NEW( item );
            item^.Direction := IOO.dirWrite;
            item^.Device := dev;
            item^.Hash := hash;
            item^.SDAPName.FromOA( key );
            
            _Data.Add( item, 0 );
         END; // WHILE
      END;
      
      IF Result <> Sync.arCompleted THEN
         Dispose();
      END;
      RETURN Result;
	END Configure;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Running GET : BOOLEAN;
   BEGIN
      RETURN ( _SDAPClient <> NIL ) AND ( _SDAPClient^.Connected );
   END Running;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Start() : Sync.TAsyncResult;
   VAR
      dev : device.TPDevice;
      Result : Sync.TAsyncResult := Sync.arCannotStart;
   BEGIN
      IF _SDAPClient <> NIL THEN
         Result := _SDAPClient^.Start();
      END;

      _Devices.Reset();
      WHILE _Devices.MoveToNext() DO
         dev := _Devices.CurrentData;
         CASE dev^.Start() OF
         | Sync.arCompleted :
            // OK
         | Sync.arPending :
            Result := Sync.arPending;
         ELSE
            IF Result = Sync.arCompleted THEN
               Result := Sync.arCompletedPartially;
            END;
         END;
      END; // WHILE
      
      RETURN Result;
   END Start;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Stop();
   VAR
      dev : device.TPDevice;
   BEGIN
      _Devices.Reset();
      WHILE _Devices.MoveToNext() DO
         dev := _Devices.CurrentData;
         dev^.Stop();
      END; // WHILE
      
      IF _SDAPClient <> NIL THEN
         _SDAPClient^.Stop();
      END;
   END Stop;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE EnumerateDeviceState( REF ES : PTR; OUT deviceName : StringsO.IString; OUT Running : BOOLEAN ) : BOOLEAN;
   VAR
      dev : device.TPDevice;
   BEGIN
      IF ES = -1 THEN
         RETURN FALSE;
      ELSIF ES = 0 THEN
         _Devices.Reset();
         b := _Devices.MoveToNext();
      ELSE
         b := _Devices.SetNextOf( ES );
      END;
      IF b THEN
         ES := _Devices.CListWState.Current;
         
         dev := _Devices.CurrentData;
         deviceName.Assign( dev^.Current^ );
         Running := dev^.Running;         
         
      ELSE
         ES := -1;
      END;
      RETURN b;
   END EnumerateDeviceState;

(*--------------------------------------------------------------------------------*)

   VIRTUAL PROCEDURE Dispose();
   VAR
      dev : device.TPDevice;
      item : TPItem;
   BEGIN
      Stop();
      
      _Data.Reset();
      WHILE _Data.MoveNext() DO
         item := _Data.Current;
         DISPOSE( item );
      END; // WHILE
      _Data.Dispose();
      _Lookup.Dispose();
      
      _Devices.Reset();
      WHILE _Devices.MoveNext() DO
         dev := _Devices.CurrentData;
         _Loader.ReleaseObject( dev );
      END; // WHILE
      _Devices.Dispose();
      
      _Loader.Dispose();

      IF _SDAPClient <> NIL THEN
         _SDAPClient^.Dispose();
         _SDAPClient := NIL;
      END;
   END Dispose;

(*--------------------------------------------------------------------------------*)

BEGIN
   _SDAPClient := NIL;
   _TimerId := 0;
END ABridge;

(*================================================================================*)

CLASS CBridge( ABridge );
END CBridge;

(*--------------------------------------------------------------------------------*)

PROCEDURE newDeviceIOSDAPBridge( OUT bridge : TPBridge ) : Sync.TAsyncResult;
VAR
   lBridge : POINTER TO CBridge;
BEGIN
   NEW( lBridge );
   bridge := lBridge;
   RETURN Sync.arCompleted;
END newDeviceIOSDAPBridge;

(*================================================================================*)

END DeviceIOSDAPBridge;