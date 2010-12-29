IMPLEMENTATION MODULE DeviceIOSDAPBridge;

FROM Debug IMPORT
   Assertion, LogAssertionW;

IMPORT
   cllv,
   FIO,
   INIFile,
   iobject,
   IOO,
   iovalue,
   log,
   ns,
   resources,
   Sync,
   Texts;

(*================================================================================*)

VAR
   R : resources.CResources;

CONST
   LOG_NAME = L"IO";

(*================================================================================*)

TYPE
   TPItem = POINTER TO CItem;

CLASS CItem;
   PUBLIC VAR
      Direction : IOO.TDirection; // read means read "from device"
      Device : device.TPDevice;
      SDAPName : StringsO.CString;
      Hash : ns.THash;
END CItem;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CItem;
BEGIN
   Direction := IOO.dirRead;
   Device := NIL;
   Hash := 0;
END CItem;

(*================================================================================*)

CLASS IMPLEMENTATION ABridge;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnRun( CONST Helper : thread.IRunnableHelper ) : CARDINAL;
   VAR
      cb : io.CCompletionDataInfo;
      item : TPItem;
      Result : Sync.TAsyncResult;
      s : StringsO.CString;
      sdapName : StringsO.CString;
      value : iovalue.Value;
      valueString : StringsO.CString;
   BEGIN
      IF _SDAPClient = NIL THEN
         RETURN -1;
      END;
      _Connecting := TRUE;
      _TickCounter := 1;
      _SDAPClient^.Connect( _SDAPHost );

      LOOP
         Result := Helper.WaitForStopRequestAndSignal( ADR( _WriteSignal ), 1000 );
         CASE Result OF
         | Sync.arCompleted :
            EXIT;
         | Sync.arTimeout, // read timer
           Sync.arPartCompleted : // write queue
            // fall down
         ELSE
            ASSERTLOG( FALSE );
            CONTINUE;
         END; // CASE

         // check and renew the connection
         IF NOT _Connecting AND NOT _SDAPClient^.Connected THEN
            _Logger.LogS( log.ldTrace, 0, LOG_NAME, L"Not connected to SDAP server trying again." );

            _Connecting := TRUE;
            _SDAPClient^.Connect( _SDAPHost );
            CONTINUE;
         END;

         IF Result = Sync.arTimeout THEN // read data from device and send it to SDAP
            // skip unused ticks
            DEC( _TickCounter );
            IF _TickCounter > 0 THEN
               CONTINUE;
            END;
            _TickCounter := _PeriodCounter;

            IF _Result.Counted OR _Result.Expired THEN
               CONTINUE;
            END;

            // get values from device and send them to SDAP
            _Data.Reset();
            WHILE _Data.MoveNext() DO
               IF Helper.WaitForStopRequest( 0 ) = Sync.arCompleted THEN // stop loop prematurely, someone wants to stop the thread
                  EXIT;
               END;

               item := _Data.Current;
               IF item^.Direction <> IOO.dirRead THEN
                  CONTINUE;
               END;
               _Result.Inc();

               IF NOT _Logger.Filtered( log.ldDebug, 0, LOG_NAME ) THEN
                  _Logger.LogSS( log.ldDebug, 0, LOG_NAME, L"Querying: ", OA( item^.SDAPName.Length-1, item^.SDAPName.Data ));
               END;

               cb.Reset();
               value.Dispose();
               Result := item^.Device^.IO()^.IOh( NIL, IOO.dirRead, item^.Hash, REF value, ADR( cb ));
               IF ( Result <> Sync.arCompleted ) AND ( Result <> Sync.arPending ) THEN
                  s.FromOA( L"Error in IOh read: " );
                  s.Append( item^.SDAPName );
                  _Logger.LogSR( log.ldTrace, 0, L"IO", OA( s.Length-1, s.Data ), Result );
                  CONTINUE;
               END;
               Result := cb.WaitCompletion( Sync.FORSAFETY, OUT value );
               IF Result = Sync.arCompleted THEN
                  valueString := value.String;
               ELSE
                  item^.Device^.IO()^.AbortAll();

                  s.FromOA( L"Error waiting read completion: " );
                  s.Append( item^.SDAPName );
                  _Logger.LogSR( log.ldTrace, 0, L"IO", OA( s.Length-1, s.Data ), Result );
                  CONTINUE;
               END;

               IF NOT _Logger.Filtered( log.ldDebug, 0, LOG_NAME ) THEN
                  _Logger.LogSS( log.ldDebug, 0, LOG_NAME, L"Got value: ", OA( valueString.Length-1,  valueString.Data ));
               END;

               // send value using SDAPClient
               Result := _SDAPClient^.Write( item^.SDAPName, valueString );
               IF Result <> Sync.arCompleted THEN
                  s.FromOA( L"Error sending by SDAP: " );
                  s.Append( item^.SDAPName );
                  _Logger.LogSR( log.ldTrace, 0, LOG_NAME, OA( s.Length-1, s.Data ), Result );
               END;
            END; // WHILE
            
         ELSE // write data to device
            LOOP
               _WriteLock.Lock();
               IF _WriteQueue.Dequeue( OUT sdapName, OUT valueString ) THEN
                  _WriteLock.Unlock();
               ELSE
                  _WriteLock.Unlock();
                  EXIT;
               END;
               
               IF Helper.WaitForStopRequest( 0 ) = Sync.arCompleted THEN // stop loop prematurely, someone wants to stop the thread
                  CONTINUE; // continue with queue flushing, do not leave memory to leak
               ELSIF _Result.Counted OR _Result.Expired THEN
                  CONTINUE;
               END;

               _Data.Reset();
               WHILE _Data.MoveNext() DO
                  item := _Data.Current;
                  IF item^.Direction <> IOO.dirWrite THEN
                     CONTINUE;
                  ELSIF NOT item^.SDAPName.Equals( sdapName ) THEN
                     CONTINUE;
                  END;
                  _Result.Inc();

                  IF NOT _Logger.Filtered( log.ldDebug, 0, LOG_NAME ) THEN
                     _Logger.LogSSSS( log.ldDebug, 0, LOG_NAME, L"Writing: ", OA( item^.SDAPName.Length-1, item^.SDAPName.Data ), L"", OA( valueString.Length-1, valueString.Data ));
                  END;

                  cb.Reset();
                  value.String := valueString;
                  Result := item^.Device^.IO()^.IOh( NIL, IOO.dirWrite, item^.Hash, REF value, ADR( cb ));
                  IF Result <> Sync.arPending THEN
                     s.FromOA( L"Error in IOh write: " );
                     s.Append( item^.SDAPName );
                     _Logger.LogSR( log.ldTrace, 0, LOG_NAME, OA( s.Length-1, s.Data ), Result );
                     CONTINUE;
                  END;
                  Result := cb.WaitCompletion( Sync.FORSAFETY, OUT value );
                  IF Result <> Sync.arCompleted THEN
                     item^.Device^.IO()^.AbortAll();

                     s.FromOA( L"Error waiting write completion: " );
                     s.Append( item^.SDAPName );
                     _Logger.LogSR( log.ldTrace, 0, LOG_NAME, OA( s.Length-1, s.Data ), Result );
                     CONTINUE;
                  END;

               END; // WHILE 

            END; // LOOP

         END;

      END; // LOOP

      _SDAPClient^.Disconnect();
      RETURN 0;
   END OnRun;

(*--------------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE Configure( CONST Source : ARRAY OF device.TConfigureItem; CONST Log : log.TPLogger ) : Sync.TAsyncResult;
	CONST
	   DEVICE_CLASS_NAME_SUFFIX = L"/IO.Device";
   CONST
	   secDevices      = L"devices";
	   secDevicePrefix = L"device_";
	      keyLibrary   = L"library";
	   secDeviceToSDAP = L"device_to_sdap";
	      keyPeriod    = L"period";
	   secSDAP         = L"sdap";
	      keyHost      = L"host";
	   secSDAPToDevice = L"sdap_to_device";
	VAR
	   dev : device.TPDevice;
	   deviceId : StringsO.CString;
	   devices : maps.CStringStringMap;
	   devPath, exePath : FIO.PathStrW;
	   ES : PTR;
	   hash : ns.THash;
	   iniFile : INIFile.TPINIFile;
	   item : POINTER TO CItem;
	   nameDevMap : maps.CStringMap;
	   key : ARRAY [0..127] OF WCHAR;
	   l : CARDINAL;
	   Result : Sync.TAsyncResult := Sync.arCompleted;
	   s : StringsO.CString;
	   src : device.TConfigureItem;
	   value : StringsO.CString;
	   
	   (*----------*)
	   
	   PROCEDURE GetHash( CONST input : ARRAY OF WCHAR; OUT dev : device.TPDevice; OUT hash : ns.THash ) : BOOLEAN;
	   CONST
	      charSplit = StringsO.WCHARS{ L"/" };
	   VAR
	      deviceName : StringsO.CString;
	      i : CARDINAL;
	      inputS : StringsO.CString;
	   BEGIN
	      inputS.FromOA( input );
	      i := inputS.ItemS( charSplit, 0, 0, FALSE, OUT deviceName );
	      IF i = -1 THEN
	         RETURN FALSE;
	      END;
	      inputS.Remove( 0, i );
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
	      Result := Sync.arAborted;

	      msg.FromOA( OAsz( R[errorText] ));
	      IF addonText <> NIL THEN
	         msg.Append( addonText^ );
	      END;
	      Log^.LogFilePos( log.lcError, 0, L"SDAP Bridge", L"", OA( msg.Length-1, msg.Data ), line, 0 );
	   END LogError;

	   (*----------*)

	BEGIN
	   Dispose();
	   
	   IF Log = NIL THEN
	      RETURN Sync.arCannotStart;
	   ELSIF HIGH( Source ) < 0 THEN
	      RETURN Sync.arCannotStart;
	   ELSIF Source[0].Type <> device.citINIFile THEN
	      RETURN Sync.arCannotStart;
	   ELSE
	      iniFile := Source[0].iniFile;
	   END;
	   
	   // logger
	   INIFile.ConfigureLog( iniFile^, L"", REF _Logger, OUT l );

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

         IF nameDevMap.Contains( devices.Current^ ) THEN
            LogError( 0, Texts._DeviceAlreadyExists, devices.Current );
            CONTINUE;
         END;

         deviceId.FromOA( secDevicePrefix );
         deviceId.Append( devices.Current^ );
         IF NOT iniFile^.SetSection( OA( deviceId.Length-1, deviceId.Data )) THEN
            LogError( 0, Texts._DeviceSectionMissing, ADR( deviceId ));
            CONTINUE;
         ELSIF NOT iniFile^.GetKeyStr( keyLibrary, OUT l, OUT value ) THEN
            LogError( 0, Texts._LibraryKeyOfDeviceSectionMissing, ADR( deviceId ));
            CONTINUE;
         END;   
         
         FIO.MakePathW( exePath, OA( value.Length-1, value.Data ), OUT devPath );
         _Loader.AddLibrary( devPath, ADR( value )); // value contains LibraryName
         value.AppendOA( DEVICE_CLASS_NAME_SUFFIX );
         CASE _Loader.CreateObject( OA( value.Length-1, value.Data ), OUT dev ) OF
         //----
         | iobject.lrSuccess :
            src.Type := device.citINIFileSection;
            src._iniFile := iniFile;
            src.section := ADR( deviceId );
            IF dev^.Configure( OA( 0, ADR( src )), Log ) = Sync.arCompleted THEN
               _Devices.Add( devices.CurrentData^, dev );
               nameDevMap.Add( devices.Current^, dev );
            ELSE
               _Loader.ReleaseObject( REF dev );
               Result := Sync.arAborted;
            END;
         //----
         | iobject.lrLibraryNotFound :
            s.FromOA( devPath );
            LogError( l, Texts._LibraryNotFound, ADR( s ));
         //----
         | iobject.lrLibraryFoundButIsUnloadable :
            s.FromOA( devPath );
            LogError( l, Texts._LibraryUnloadable, ADR( s ));
         //----
         | iobject.lrLibraryDisabled :
            s.FromOA( devPath );
            LogError( l, Texts._LibraryDisable, ADR( s ));
         //----
         | iobject.lrClassNotFound :
            s.FromOA( devPath );
            LogError( l, Texts._LibraryClassNotFound, ADR( s ));
         END; // CASE
         
      END; // WHILE
      
      // data
      IF iniFile^.SetSection( secSDAPToDevice ) THEN // deviceId = sdapId
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

      IF iniFile^.SetSection( secDeviceToSDAP ) THEN // sdapId = deviceId
         IF NOT iniFile^.GetKeyInt( keyPeriod, OUT l, OUT _PeriodCounter ) THEN
            _PeriodCounter := 15; // seconds per read all
         END;
      
         ES := 0;
         WHILE iniFile^.EnumerateKeys( REF ES, OUT l, OUT key, OUT value ) DO
            IF EQUALS( key, keyPeriod ) THEN
               CONTINUE;
            ELSIF NOT GetHash( OA( value.Length-1, value.Data ), OUT dev, OUT hash ) THEN
               LogError( l, Texts._DataItemNotFound, ADR( value ));
               CONTINUE;
            END;
            
            NEW( item );
            item^.Direction := IOO.dirRead;
            item^.Device := dev;
            item^.Hash := hash;
            item^.SDAPName.FromOA( key );
            
            _Data.Add( item, 0 );
         END; // WHILE
      END;
      
      IF Result = Sync.arCompleted THEN
         Result := sdapClient.newSDAPClient( OUT _SDAPClient );
         _SDAPClient^.EventListener := ADR( SELF );
      ELSE
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
      s : FIO.PathStrW;
   BEGIN
      _Logger.LogS( log.ldMessage, 0, L"IOSDAPBridge", L"Started" );

      _Result.Reset( lec.bhBestCase );
      FIO.GetModuleDirW( L"", OUT s );
      lec.QueryData( s, L"", ADR( cllv.data ), cllv.length, REF _Result );

      _Devices.Reset();
      WHILE _Devices.MoveNext() DO
         dev := _Devices.CurrentData;
         CASE dev^.IO()^.Start() OF
         | Sync.arCompleted :
            // OK
         | Sync.arPending :
            Result := Sync.arPending;
         ELSE
            IF Result = Sync.arCompleted THEN
               Result := Sync.arPartCompleted;
            END;
         END;
      END; // WHILE
      
      _Thread.RunWithRunnable( ADR( SELF ));
      RETURN Result;
   END Start;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Stop();
   VAR
      dev : device.TPDevice;
   BEGIN
      _Thread.Stop( TRUE );
   
      _Devices.Reset();
      WHILE _Devices.MoveNext() DO
         dev := _Devices.CurrentData;
         dev^.IO()^.Stop();
      END; // WHILE

      _Logger.LogS( log.ldMessage, 0, L"IOSDAPBridge", L"Stopped" );
   END Stop;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnConnect( Result : Sync.TAsyncResult; Error : CARDINAL );
   BEGIN
      IF Result = Sync.arCompleted THEN
         _SDAPClient^.SetAdvise( TRUE );
      END;
      _Connecting := FALSE;
   END OnConnect;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnDisconnect( Result : Sync.TAsyncResult; Error : CARDINAL );
   BEGIN
      // intentionaly empty
   END OnDisconnect;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnReceive( CONST Data, Value : StringsO.IString );
   BEGIN
      _WriteLock.Lock();
      _WriteQueue.Enqueue( Data, Value );
      _WriteLock.Unlock();
      _WriteSignal.Signal();
   END OnReceive;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE EnumerateDeviceState( REF ES : PTR; OUT deviceName : StringsO.IString; OUT Running : BOOLEAN ) : BOOLEAN;
   VAR
      b : BOOLEAN;
      dev : device.TPDevice;
   BEGIN
      IF ES = -1 THEN
         RETURN FALSE;
      ELSIF ES = 0 THEN
         _Devices.Reset();
         b := _Devices.MoveNext();
      ELSE
         b := _Devices.SetNextOf( ES );
      END;
      IF b THEN
         ES := _Devices.CListWState.Current;
         
         dev := _Devices.CurrentData;
         deviceName.Assign( _Devices.Current^ );
         Running := dev^.IO()^.Running;         
         
      ELSE
         ES := -1;
      END;
      RETURN b;
   END EnumerateDeviceState;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
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
         _Loader.ReleaseObject( REF dev );
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
   _Connecting := FALSE;
   _PeriodCounter := 15;
   _TickCounter := 0;
   _WriteSignal.Init( Sync.stEventAutoreset, L"", FALSE );
END ABridge;

(*================================================================================*)

CLASS CBridge( ABridge );
END CBridge;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CBridge;
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

BEGIN
   R.LoadRES2( EMIT( %dll ), L"DeviceIOSDAPBridge.Texts" );
END DeviceIOSDAPBridge.
