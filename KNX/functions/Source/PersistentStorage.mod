IMPLEMENTATION MODULE PersistentStorage;

(*================================================================================*)

FROM Debug IMPORT
   AssertionW;

IMPORT
   device,
   FIO,
   Folders,
   IOO,
   iovalue,
   INIFile,
   ns,
   Texts;

(*================================================================================*)

CLASS CItem;

   LOCAL PROCEDURE Enqueue() : BOOLEAN; // returns FALSE if the object is already in the queue
   LOCAL PROCEDURE Dequeue();

   LOCAL VAR
      Address : StringsO.CString;
      Pairs : ns.TPNameValuePairs := NIL;
      Value : iovalue.Value;

   PRIVATE VAR
      _Signal : Sync.SIGNAL;

END CItem;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CItem;

(*-------------------------------------------------------------------------------*)

   LOCAL PROCEDURE Enqueue() : BOOLEAN;
   BEGIN
      RETURN _Signal.Signal();
   END Enqueue;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE Dequeue();
   BEGIN
      _Signal.Reset();
   END Dequeue;

(*-------------------------------------------------------------------------------*)

BEGIN
   _Signal.Init( Sync.stSpin, L"", FALSE );
END CItem;

(*================================================================================*)

CONST
   LOGNAME = L"Storage";
   CFG_SECTION = L"storage";
   WRITE_DELAY_TIMER = 1;
   STORAGE_FILE = L'PersistingStorage.ini';

CLASS IMPLEMENTATION CPersistentStorageFunction;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnTimer( Timer : PTR );
   BEGIN
      IF Timer = WRITE_DELAY_TIMER THEN
         Write();
      END;
   END OnTimer;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnAdvise( CONST Originator : ns.TPOriginator; CONST Result : ARRAY OF Sync.TAsyncResult; CONST Item : ARRAY OF ns.TPNameValuePairs; CONST Value : ARRAY OF iovalue.Value );
   VAR
      item : TPItem;
      i : CARDINAL;
   BEGIN
      // check validity of input
      IF HIGH( Item ) < 0 THEN
         RETURN;
      END;
      
      // look for items and check if operation finished sucessfully
      FOR i := 0 TO HIGH( Item ) DO
         IF Result[i] IN Sync.arsCompletions THEN
            
            _Items.Reset();
            WHILE _Items.MoveNext() DO
               item := _Items.Current;
               IF item^.Pairs = Item[i] THEN
                  Mark( item );
               END;
            END; // WHILE
            
         END;
      END;
   END OnAdvise;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnConnect();
   BEGIN
   END OnConnect;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnDisconnect();
   BEGIN
   END OnDisconnect;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnInitReadCompleted();
   VAR
      item : TPItem;
      result : Sync.TAsyncResult;
      value : StringsO.CString;
   BEGIN
      Logger^.LogS( log.lcWarning, 0, LOGNAME, L"Init-read phase finished, pushing persistent values to KNX" );

      // write values to KNX
      _Items.Reset();
      WHILE _Items.MoveNext() DO
         item := _Items.Current;

         value := item^.Value.String;
         Logger^.LogSSSS( log.lcInfo, 0, LOGNAME, L"Pushing value:", OA( item^.Address.Length-1, item^.Address.Data ), L"=", OA( value.Length-1, value.Data ));

         result := item^.Pairs^.ValueIO( ADR( SELF ), item^.Pairs, IOO.dirWrite, REF item^.Value );
         IF result NOT IN Sync.arsCompletions THEN // log error
            Logger^.LogSS( log.lcError, 0, LOGNAME, L"Unable to write persisted value:", OA( item^.Address.Length-1, item^.Address.Data ));
         END;

      END; // WHILE      
   END OnInitReadCompleted;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnRead( PObject : knxcore.TPObject );
   BEGIN
   END OnRead;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnWritten( PObject : knxcore.TPObject );
   BEGIN
   END OnWritten;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnInputQueueAdd( OOBQueue, PromiscuousQueue : BOOLEAN );
   END OnInputQueueAdd;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnInputQueueOverflow( OOBQueue, PromiscuousQueue : BOOLEAN );
   BEGIN
   END OnInputQueueOverflow;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY DefaultStorageFolder GET : StringsO.CString;
   BEGIN
      RETURN _DefaultStorageFolder;
   END DefaultStorageFolder;
      
(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY DefaultStorageFolder SET( CONST Value : StringsO.CString );
   BEGIN
      _DefaultStorageFolder := Value;
   END DefaultStorageFolder;
      
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Configure( CONST Source : ARRAY OF device.TConfigureItem; CONST Log : log.TPLogger ) : Sync.TAsyncResult;
   VAR
      iniFile : INIFile.TPINIFile;
      result : Sync.TAsyncResult;
      section : StringsO.CString;
      storageFile : INIFile.CINIFile;
      storagePathOA : FIO.PathStrW;
   BEGIN
      IF DataSource = NIL THEN
	      Log^.LogS( log.lcError, 0, LOGNAME, OAsz( R^[ Texts._DeviceIsNotInitialized ] ));
         RETURN Sync.arCannotStart;
      
      ELSIF HIGH( Source ) < 0 THEN
	      Log^.LogS( log.lcError, 0, LOGNAME, OAsz( R^[ Texts._BadParameterMissingSourceOfConfiguration ] ));
         RETURN Sync.arCannotStart;

      ELSIF Source[0].Type = device.citINIFile THEN
         iniFile := Source[0].iniFile;
         section.FromOA( CFG_SECTION ); // load default section

      ELSIF Source[0].Type = device.citINIFileSection THEN
         iniFile := Source[0].iniFile;
         section.Assign( Source[0].section^ ); // load ordered section

      ELSE
	      Log^.LogS( log.lcError, 0, LOGNAME, OAsz( R^[ Texts._UnsupportedSourceOfConfiguration ] ));
         RETURN Sync.arCannotStart;
      END;
      
      _StoragePath.Clear();
      result := LoadData( iniFile, OA( section.Length-1, section.Data ), Log, TRUE );
      IF result NOT IN Sync.arsCompletions THEN
         RETURN result;
      END;

      IF _StoragePath.Empty THEN // nothing was read, set up default
         IF NOT Folders.GetManufacturerSpecialFolderW( Folders.sfAppDataCommon, TRUE, OUT storagePathOA ) THEN
	         Log^.LogS( log.lcError, 0, LOGNAME, OAsz( R^[ Texts._AppDataStorageUnavailable ] ));
            RETURN Sync.arCannotStart;
         END;
         FIO.PathAddW( REF storagePathOA, OA( _DefaultStorageFolder.Length-1, _DefaultStorageFolder.Data ));
         FIO.PathAddW( REF storagePathOA, STORAGE_FILE );
         _StoragePath.FromOA( storagePathOA );
      END;

      Logger^.LogSS( log.lcInfo, 0, LOGNAME, L"Using storage file:", OA( _StoragePath.Length-1, _StoragePath.Data ));

      IF storageFile.LoadPath( OA( _StoragePath.Length-1, _StoragePath.Data )) THEN
         section.FromOA( CFG_SECTION ); // load default section
         result := LoadData( ADR( storageFile ), OA( section.Length-1, section.Data ), Log, FALSE );
         IF result NOT IN Sync.arsCompletions THEN
            RETURN result;
         END;
      END;
      
      RETURN Sync.arCompleted;
   END Configure; 
   
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   VAR
      item : TPItem;
   BEGIN
      StopTimer( WRITE_DELAY_TIMER );

      IF DataSource <> NIL THEN
         DataSource^.UnadviseAll( ADR( SELF ));
         DataSource^.LeaveClient( ADR( SELF ));
      END;
   
      _Items.Reset();
      WHILE _Items.MoveNext() DO
         item := _Items.Current;
         DISPOSE( item );
      END; // WHILE
      _Items.Dispose();
   END Dispose;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnStart();
   VAR
      item : TPItem;
   BEGIN
      DataSource^.JoinClient( ADR( SELF ), ns.advWithData );
      
      _Items.Reset();
      WHILE _Items.MoveNext() DO
         item := _Items.Current;
         DataSource^.AdviseHash( ADR( SELF ), item^.Pairs );
      END; // WHILE

      // values are written into KNX after init read phase
   END OnStart;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnStop();
   BEGIN
      DataSource^.UnadviseAll( ADR( SELF ));
      DataSource^.LeaveClient( ADR( SELF ));
   END OnStop;
   
(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE LoadData( CONST iniFile : INIFile.TPINIFile; section : ARRAY OF WCHAR; CONST Log : log.TPLogger; acceptConfigurationKeys : BOOLEAN ) : Sync.TAsyncResult;
   CONST
      keyWriteDelay = L"write_delay";
      keyStoragePath = L"storage_file_path";
   VAR
      ES : PTR;
      item : TPItem;
      Line : CARDINAL;
      key : StringsO.CString;
      pairs : ns.TPNameValuePairs;
      s : StringsO.CString;
      storagePath : StringsO.CString;
      value : StringsO.CString;
      writeDelay : INTEGER;
   BEGIN
      IF NOT iniFile^.SetSection( section ) THEN
	      Log^.LogSS( log.lcInfo, 0, LOGNAME, OAsz( R^[ Texts._ConfigurationSectionNotFound ] ), section );
         RETURN Sync.arCompleted;
      END;
      // here the inifile has proper section set

      IF acceptConfigurationKeys THEN
         // get optional write delay
         IF iniFile^.GetKeyInt( keyWriteDelay, OUT Line, OUT writeDelay ) THEN
            IF writeDelay < 1 THEN
	            Log^.LogSC( log.lcError, 0, LOGNAME, OAsz( R^[ Texts._WriteDelayCannotBeZeroOrLessThanZeroIgnoring ] ), writeDelay );
            ELSE
               _WriteDelay := 1000 * writeDelay;
            END;
         END;
      
         // get optional storage path
         IF iniFile^.GetKeyStr( keyStoragePath, OUT Line, OUT storagePath ) THEN
            _StoragePath := storagePath;
         END;
      END;

      ES := 0;
      WHILE iniFile^.EnumerateKeys( REF ES, OUT Line, OUT key, OUT value ) DO

         // skip keys already read
         IF NOT acceptConfigurationKeys THEN
            // fall down, do not test for special configuration keys
         ELSIF value.EqualsOA( keyWriteDelay ) OR
            value.EqualsOA( keyStoragePath ) THEN
            CONTINUE;
         END;

         // key/output = value
         IF NOT DataSource^.NS()^.Get( key, OUT pairs ) THEN
	         Log^.LogSSSS( log.lcError, 0, LOGNAME, LOGNAME, OAsz( R^[ Texts._GroupAddressNotFound ] ), OA( key.Length-1, key.Data ), L"" );
            CONTINUE;
         END;
         
         // everything OK, create item in _Items
         NEW( item );
         item^.Address := key;
         item^.Pairs := pairs;
         item^.Value := iovalue.FromString( value );
         _Items.Add( item, 0 );
      END; // WHILE

      RETURN Sync.arCompleted;
   END LoadData;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Mark( item : TPItem );
   BEGIN
      IF NOT item^.Enqueue() THEN // smart queueuing, the item is already inside the queue
         RETURN;
      END;

      Logger^.LogSS( log.lcInfo, 0, LOGNAME, L"Marking item for write:", OA( item^.Address.Length-1, item^.Address.Data ));
      _WriteQueue.Enqueue( item );

      IF TimerRunning( WRITE_DELAY_TIMER ) THEN
         Logger^.LogS( log.lcInfo, 0, LOGNAME, L"Timer pending, not scheduled." );
         RETURN;
      END;
      Logger^.LogS( log.lcWarning, 0, LOGNAME, L"Timer not pending, scheduled." );
      StartTimer( WRITE_DELAY_TIMER, _WriteDelay, FALSE );
   END Mark;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Write();
   VAR
      item : TPItem;
      result : Sync.TAsyncResult;
      value : StringsO.CString;
   BEGIN
      Logger^.LogS( log.lcWarning, 0, LOGNAME, L"Timer elapsed, writting changed items to the file." );

      _Storage.CreateSection( CFG_SECTION, FALSE );
      _Storage.SetSection( CFG_SECTION );

      WHILE _WriteQueue.Dequeue( OUT item ) DO
         item^.Dequeue();

         result := item^.Pairs^.ValueIO( ADR( SELF ), item^.Pairs, IOO.dirRead, REF item^.Value );
         IF result NOT IN Sync.arsCompletions THEN // log error
	         Logger^.LogSS( log.lcError, 0, LOGNAME, L"Unable to read value from device:", OA( item^.Address.Length-1, item^.Address.Data ));
	         Logger^.LogSR( log.lcInfo, 0, LOGNAME, L"    result", result );
            CONTINUE;
         END;

         value := item^.Value.String;
         IF _Storage.SetKeyStr( OA( item^.Address.Length-1, item^.Address.Data ), value, FALSE ) THEN
            Logger^.LogSSSS( log.lcInfo, 0, LOGNAME, L"Value stored:", OA( item^.Address.Length-1, item^.Address.Data ), L"=", OA( value.Length-1, value.Data ));
         ELSE // log error
            Logger^.LogSS( log.lcError, 0, LOGNAME, L"Unable to store value:", OA( item^.Address.Length-1, item^.Address.Data ));
         END;

      END; // _SendQueue

      IF _Storage.SavePath( OA( _StoragePath.Length-1, _StoragePath.Data )) THEN // log error
         Logger^.LogSS( log.lcInfo, 0, LOGNAME, L"Storage file saved:", OA( _StoragePath.Length-1, _StoragePath.Data ));
      ELSE
         Logger^.LogSS( log.lcError, 0, LOGNAME, L"Unable to save storage file:", OA( _StoragePath.Length-1, _StoragePath.Data ));
      END;
   END Write;

(*--------------------------------------------------------------------------------*)

BEGIN
   DescriptionSet := StringsO.FromOA( L"Persistent storage" );
FINALLY
   Dispose();
END CPersistentStorageFunction;

(*================================================================================*)

END PersistentStorage.