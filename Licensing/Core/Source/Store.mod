IMPLEMENTATION MODULE Store;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;
FROM Log IMPORT
   logger, dldTrace;
FROM Debug IMPORT
   Assertion, LogAssertionW;
FROM Exceptions IMPORT
   StoreException, TestIfCatched, RetrieveException;

IMPORT
   bitarray,
   FIO,
   FIOO,
   Folders,
   FSO,
   INIfile,
   IOO,
   lists,
   Strings,
   TextReader,
   TextWriter;

(*================================================================================*)

CLASS IMPLEMENTATION CStorage;
END CStorage;

(*================================================================================*)

CONST
   cfFolder = L"Licence";

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CFileStorage;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY OperationMode GET : TFileOperationMode;
   BEGIN
      RETURN _OperationMode;
   END OperationMode;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY OperationMode SET( Value : TFileOperationMode );
   BEGIN
      _OperationMode := Value;
   END OperationMode;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Path GET : StringsO.CString;
   BEGIN
      RETURN _Path;
   END Path;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Path SET( CONST Value : StringsO.CString );
   BEGIN
      _Path := Value;
      IF NOT _Path.Empty AND NOT _Path.EndsWithOA( L"\" ) THEN
         _Path.AppendOA( L"\" );
      END;
   END Path;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY FilterToStore GET : TPFileFilter;
   BEGIN
      RETURN _Filters[0];
   END FilterToStore;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY FilterToStore SET( Value : TPFileFilter );
   BEGIN
      IF _Filters.Contains( Value ) THEN
         _Filters.Remove( Value );
      END;
      _Filters.InsertFirst( Value, 0 );
   END FilterToStore;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Filters GET : lists.TPPtrList;
   BEGIN
      RETURN ADR( _Filters );
   END Filters;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SetPathOA( Path : ARRAY OF WCHAR );
   BEGIN
      _Path.FromOA( Path );
   END SetPathOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC FINAL PROCEDURE Load( ProductIdFilter : ARRAY OF WCHAR; REF ItemsToLoad : arrays.CPtrArray; ClearArray, RespectValidation : BOOLEAN );
   VAR
      path : FIO.PathStrW;
   BEGIN
      IF ClearArray THEN
         ItemsToLoad.Dispose();
      END;
      IF _Filters.Empty THEN
         RETURN;
      END;

      IF NOT _Path.Empty THEN
         _Path.ToOA( OUT path );
         LoadSingleFolder( ProductIdFilter, REF ItemsToLoad, RespectValidation, path );

      ELSE // else use default storages
         IF Folders.GetManufacturerSpecialFolderW( Folders.sfProgramsCommon, FALSE, OUT path ) THEN
            FIO.PathAddW( REF path, cfFolder );
            LoadSingleFolder( ProductIdFilter, REF ItemsToLoad, RespectValidation, path );
         END;
         IF Folders.GetManufacturerSpecialFolderW( Folders.sfAppDataCommon, FALSE, OUT path ) THEN
            FIO.PathAddW( REF path, cfFolder );
            LoadSingleFolder( ProductIdFilter, REF ItemsToLoad, RespectValidation, path );
         END;

      END;
   END Load;

(*--------------------------------------------------------------------------------*)

   PUBLIC FINAL PROCEDURE Store( CONST ItemsToStore : arrays.CPtrArray; RespectDirty : BOOLEAN );
   VAR
      count : CARDINAL;
      filter : TPFileFilter;
      folderOA : ARRAY [0..511] OF WCHAR;
      i : CARDINAL;
      item, pivot : Items.TPItem;
      LocalItems : arrays.CPtrArray;
      pathOA : FIO.PathStrW;
      processed : bitarray.CBitArray;
      s : ARRAY [0..255] OF WCHAR;
      someDirty : BOOLEAN := FALSE;
   BEGIN
      IF ItemsToStore.Empty THEN
         RETURN;
      END;
      filter := FilterToStore;
      IF filter = NIL THEN
         RETURN;
      END;

      // create folder
      IF NOT _Path.Empty THEN
         _Path.ToOA( OUT folderOA );
      // else use default storage
      ELSIF Folders.GetManufacturerSpecialFolderW( Folders.sfAppDataCommon, TRUE, OUT folderOA ) THEN
         FIO.PathAddW( REF folderOA, cfFolder );
      ELSE
         ASSERTLOG( FALSE, L"Unable to get CSIDL_COMMON_APPDATA" );
         RETURN; // store nothing
      END;
      IF NOT FIO.CreateDirectoryW( folderOA ) THEN
         ASSERTLOG( FALSE, L"Unable to store to CSIDL_COMMON_APPDATA" );
         RETURN; // store nothing
      END;

      // prepare write structures
      count := ItemsToStore.Count;
      filter^.InitStore();

      CASE OperationMode OF
      //-----
      | fomFileByItem :
         FOR i := 0 TO count-1 DO
            item := Items.TPItem( ItemsToStore[i] );
            IF RespectDirty AND NOT item^.Dirty THEN
               CONTINUE;
            END;
            Items.TPItem( ItemsToStore[i] )^.CreateTransportData();

            item^.ProductId.ToOA( OUT s );
            FIO.MakePathW( folderOA, s, OUT pathOA );
            Strings.AppendW( REF pathOA, L"." );
            Strings.FromCARD32W( i, 8, OUT s ); Strings.AppendW( REF pathOA, s );
            Strings.AppendW( REF pathOA, L"." );
            filter^.Extension( OUT s );
            Strings.AppendW( REF pathOA, s );

            LocalItems.Clear(); // LocalItems is temporary storage (references to ItemsToStore), do not call dispose
            LocalItems.Add( item );
            filter^.StoreFile( pathOA, LocalItems );
         END;
      //-----
      | fomFileByProduct :
         processed.Count := count;
         processed.ExclAll();
         LOOP
            // search products
            someDirty := FALSE;
            LocalItems.Clear(); // LocalItems is temporary storage (references to ItemsToStore), do not call dispose
            FOR i := 0 TO count-1 DO
               IF processed[i] THEN
                  CONTINUE;
               END;
               item := Items.TPItem( ItemsToStore[i] );
               IF LocalItems.Empty THEN
                  pivot := item;

                  someDirty := NOT RespectDirty OR item^.Dirty;
                  item^.CreateTransportData();
                  LocalItems.Add( item );
                  processed[i] := TRUE;
               ELSIF pivot^.ProductId = item^.ProductId THEN
                  someDirty := someDirty OR NOT RespectDirty OR item^.Dirty;
                  item^.CreateTransportData();
                  LocalItems.Add( item );
                  processed[i] := TRUE;
               END;
            END; // FOR

            IF LocalItems.Empty THEN // exhausted
               EXIT;
            ELSIF someDirty THEN // write only if something is touched
               item^.ProductId.ToOA( OUT s );
               FIO.MakePathW( folderOA, s, OUT pathOA );
               Strings.AppendW( REF pathOA, L"." );
               filter^.Extension( OUT s );
               Strings.AppendW( REF pathOA, s );
               filter^.StoreFile( pathOA, LocalItems );
            END;

         END; // LOOP over products
      //-----
      | fomSingleFile :
         IF NOT _Path.Empty THEN
            FOR i := 0 TO count-1 DO
               someDirty := someDirty OR NOT RespectDirty OR Items.TPItem( ItemsToStore[i] )^.Dirty;
               Items.TPItem( ItemsToStore[i] )^.CreateTransportData();
            END; // FOR
            IF someDirty THEN
               // TODO: does this work?
               _Path.ToOA( OUT pathOA );
               Strings.AppendW( REF pathOA, L"." );
               filter^.Extension( OUT s );
               Strings.AppendW( REF pathOA, s );

               filter^.StoreFile( pathOA, ItemsToStore );
            END;
         END;
      END;
      filter^.FinishStore();
   END Store;

(*--------------------------------------------------------------------------------*)

	PUBLIC PROCEDURE LoadSingleFile( CONST Path : StringsO.IString; REF Items : arrays.CPtrArray; ClearArray, RespectValidation : BOOLEAN ) : BOOLEAN;
	VAR
	   path : FIO.PathStrW;
	BEGIN
	   Path.ToOA( OUT path );
	   TRY
	      RETURN LoadSingleFileOA( path, REF Items, ClearArray, RespectValidation );
	   CATCH e : IOO.CIOException DO
	      THROW e;
	   END;
	   RETURN FALSE;
	END LoadSingleFile;

(*--------------------------------------------------------------------------------*)

	PUBLIC PROCEDURE LoadSingleFileOA( CONST Path : ARRAY OF WCHAR; REF Items : arrays.CPtrArray; ClearArray, RespectValidation : BOOLEAN ) : BOOLEAN;
	VAR
      LocalItems : arrays.CPtrArray;
      haveSomething : BOOLEAN := FALSE;
	BEGIN
      IF ClearArray THEN
         Items.Dispose();
      END;
      _Filters.Reset();
      WHILE _Filters.MoveNext() DO
         IF TPFileFilter( _Filters.Current )^.IsFor( Path ) THEN
            TPFileFilter( _Filters.Current )^.InitLoad();
            TPFileFilter( _Filters.Current )^.LoadFile( Path, REF LocalItems );
            TPFileFilter( _Filters.Current )^.FinishLoad();
            haveSomething := TRUE;
            EXIT;
         END;
      END; // WHILE
      IF NOT haveSomething OR LocalItems.Empty THEN
         RETURN FALSE;
      END;
      ValidateItems( RespectValidation, LocalItems, OUT Items );
      RETURN TRUE;
	END LoadSingleFileOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE StoreSingleFile( CONST Path : StringsO.IString; CONST ItemsToStore : arrays.CPtrArray );
	VAR
	   path : FIO.PathStrW;
	BEGIN
	   Path.ToOA( OUT path );
      StoreSingleFileOA( path, ItemsToStore );
	END StoreSingleFile;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE StoreSingleFileOA( CONST Path : ARRAY OF WCHAR; CONST ItemsToStore : arrays.CPtrArray );
   VAR
      count : CARDINAL;
      filter : TPFileFilter := NIL;
      i : CARDINAL;
   BEGIN
      IF ItemsToStore.Empty THEN
         RETURN;
      END;
      
      // search proper filter
      _Filters.Reset();
      WHILE _Filters.MoveNext() DO
         IF TPFileFilter( _Filters.Current )^.IsFor( Path ) THEN
            filter := TPFileFilter( _Filters.Current );
            EXIT;
         END;
      END; // WHILE
      IF filter = NIL THEN
         RETURN; // TO DO error
      END;

      // prepare write structures
      count := ItemsToStore.Count;
      FOR i := 0 TO count-1 DO
         Items.TPItem( ItemsToStore[i] )^.CreateTransportData();
      END; // FOR
      
      filter^.InitStore();
      filter^.StoreFile( Path, ItemsToStore );
      filter^.FinishStore();
   END StoreSingleFileOA;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ValidateItems( RespectValidation : BOOLEAN; CONST SourceItems : arrays.CPtrArray; OUT ValidItems : arrays.CPtrArray );
	VAR
	   i : CARDINAL;
      item : Items.TPItem;
	BEGIN
      FOR i := 0 TO SourceItems.Count-1 DO
         item := Items.TPItem( SourceItems[i] );
         item^.ValidateByTransportData();
         IF item^.Valid OR NOT RespectValidation THEN
            ValidItems.Add( item );
         ELSE
            DISPOSE( item );
         END;
      END; // WHILE
	END ValidateItems;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE LoadSingleFolder( ProductIdFilter : ARRAY OF WCHAR; REF ItemsToLoad : arrays.CPtrArray; RespectValidation : BOOLEAN; path : ARRAY OF WCHAR );
   VAR
      DI : FSO.CDirectoryInfo;
      filter : ARRAY [0..255] OF WCHAR;
      LocalItems : arrays.CPtrArray;
      localPath : FIO.PathStrW;
   BEGIN
      IF ProductIdFilter[0] = 0W THEN
         filter[0] := 0W;
      ELSE
         Strings.ConcatW( OUT filter, ProductIdFilter, L".*" );
      END;
      IF NOT DI.StartOA( path, filter, FSO.soTopDirectoryOnly, FALSE, TRUE ) THEN
         RETURN;
      END;

      _Filters.Reset();
      WHILE _Filters.MoveNext() DO
         TPFileFilter( _Filters.Current )^.InitLoad();
      END;
      REPEAT
         DI.Path.ToOA( OUT localPath );
         _Filters.Reset();
         WHILE _Filters.MoveNext() DO
            IF TPFileFilter( _Filters.Current )^.IsFor( localPath ) THEN
               TPFileFilter( _Filters.Current )^.LoadFile( localPath, REF LocalItems );
               EXIT;
            END;
         END; // WHILE
      UNTIL NOT DI.MoveNext();
      _Filters.Reset();
      WHILE _Filters.MoveNext() DO
         TPFileFilter( _Filters.Current )^.FinishLoad();
      END;

      ValidateItems( RespectValidation, LocalItems, OUT ItemsToLoad );
   END LoadSingleFolder;

(*--------------------------------------------------------------------------------*)

BEGIN
END CFileStorage;

(*================================================================================*)

CLASS IMPLEMENTATION CFileFilter;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE IsFor( CONST Path : ARRAY OF WCHAR ) : BOOLEAN;
   VAR
      ext : ARRAY [0..63] OF WCHAR;
   BEGIN
      ext[0] := L'.';
      Extension( OUT OA( HIGH( ext ) -1, ADR( ext[1] )));
      RETURN Strings.EndsWithW( Path, ext );
   END IsFor;

(*--------------------------------------------------------------------------------*)

	LOCAL VIRTUAL PROCEDURE InitLoad();
	BEGIN
	END InitLoad;

(*--------------------------------------------------------------------------------*)

	LOCAL VIRTUAL PROCEDURE FinishLoad();
	BEGIN
	END FinishLoad;

(*--------------------------------------------------------------------------------*)

	LOCAL VIRTUAL PROCEDURE InitStore();
	BEGIN
	END InitStore;

(*--------------------------------------------------------------------------------*)

	LOCAL VIRTUAL PROCEDURE FinishStore();
	BEGIN
	END FinishStore;

(*--------------------------------------------------------------------------------*)

BEGIN
END CFileFilter;

(*================================================================================*)

CLASS IMPLEMENTATION CINIFilter;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE Extension( OUT extension : ARRAY OF WCHAR );
   BEGIN
      extension := L"tlic";
   END Extension;

(*--------------------------------------------------------------------------------*)

	LOCAL VIRTUAL PROCEDURE LoadFile( CONST File : ARRAY OF WCHAR; REF ItemsToLoad : arrays.CPtrArray );
	VAR
	   es, ies : PTR;
	   fs : FIOO.CFileStream;
	   l : CARDINAL;
	   tr : TextReader.CTextReader;
	   key : ARRAY [0..63] OF WCHAR;
	   INI : INIfile.CINIFile;
	   item : Items.TPItem;
	   section : ARRAY [0..63] OF WCHAR;
	   value : StringsO.CString;
	BEGIN
	   TRY
         fs.FromPath( File, FIOO.imOpenRead );
      CATCH e : IOO.CIOException DO
         logger()^.LogExc( dldTrace, EMITW( %lprocedure ), e );
         RETURN;
      END;
      tr.Stream := ADR( fs );
      INI.Load( tr );
      fs.Close( FALSE );

      es := 0;
      WHILE INI.EnumerateSections( REF es, OUT l, OUT section, TRUE ) DO
         IF EQUALS( section, L"product" ) THEN
            item := NEW( Items.CProduct );

            INI.GetKeyStr( L"id", OUT l, OUT item^.ProductId );
            INI.GetKeyStr( L"name", OUT l, OUT Items.TPProduct( item )^.Name );
            INI.GetKeyStr( L"version", OUT l, OUT Items.TPProduct( item )^.VersionString );
            INI.GetKeyStr( L"copyright", OUT l, OUT Items.TPProduct( item )^.Copyright );
            INI.GetKeyStr( L"legal", OUT l, OUT Items.TPProduct( item )^.Legal );
            INI.GetKeyStr( L"note", OUT l, OUT Items.TPProduct( item )^.Note );
            INI.GetKeyStr( L"data", OUT l, OUT item^.TransportData );

         ELSIF EQUALS( section, L"licence" ) THEN
            item := NEW( Items.CLicence );

            INI.GetKeyStr( L"created", OUT l, OUT item^.CreatedString );
            INI.GetKeyStr( L"serial", OUT l, OUT Items.TPLicence( item )^.Serial );
            INI.GetKeyStr( L"owner", OUT l, OUT Items.TPLicence( item )^.Owner );
            INI.GetKeyStr( L"data", OUT l, OUT item^.TransportData );

         ELSIF EQUALS( section, L"activation" ) THEN
            item := NEW( Items.CActivation );

            INI.GetKeyStr( L"created", OUT l, OUT item^.CreatedString );
            INI.GetKeyStr( L"ofserial", OUT l, OUT Items.TPActivation( item )^.OfSerial );
            INI.GetKeyStr( L"starts", OUT l, OUT Items.TPActivation( item )^.StartsString );
            INI.GetKeyStr( L"expires", OUT l, OUT Items.TPActivation( item )^.ExpiresString );
            INI.GetKeyStr( L"data", OUT l, OUT item^.TransportData );

         ELSIF EQUALS( section, L"info" ) THEN
            item := NEW( Items.CInfo );

            ies := 0;
            WHILE INI.EnumerateKeys( REF ies, OUT l, OUT key, OUT value ) DO
               IF EQUALS( key, L"id" ) THEN
                  item^.ProductId := value;
               ELSIF EQUALS( key, L"data" ) THEN
                  item^.TransportData := value;
               ELSE
                  Items.TPInfo( item )^.List^.AddOA( key, value );
               END;
            END; // WHILE

         ELSE
            CONTINUE;
         END;
         
         item^.Dirty := FALSE;
         ItemsToLoad.Add( item );
      END; // WHILE
	END LoadFile;

(*--------------------------------------------------------------------------------*)

	LOCAL VIRTUAL PROCEDURE StoreFile( CONST File : ARRAY OF WCHAR; CONST ItemsToStore : arrays.CPtrArray );
	VAR
	   fs : FIOO.CFileStream;
	   tw : TextWriter.CTextWriter;
	   i : CARDINAL;
	   INI : INIfile.CINIFile;
	   item : Items.TPItem;
	   list : lists.TPStringStringList;
	BEGIN
	   IF ItemsToStore.Count = 0 THEN
	      RETURN;
	   END;

	   FOR i := 0 TO ItemsToStore.Count-1 DO
	      item := Items.TPItem( ItemsToStore[i] );
         IF item^ IS Items.CProduct THEN
            INI.CreateSection( L"product", TRUE );
            INI.SetKeyStr( L"id", item^.ProductId, FALSE );
            INI.SetKeyStr( L"name", Items.TPProduct( item )^.Name, FALSE );
            INI.SetKeyStr( L"version", Items.TPProduct( item )^.VersionString, FALSE );
            INI.SetKeyStr( L"copyright", Items.TPProduct( item )^.Copyright, FALSE );
            INI.SetKeyStr( L"legal", Items.TPProduct( item )^.Legal, FALSE );
            INI.SetKeyStr( L"note", Items.TPProduct( item )^.Note, FALSE );
            INI.SetKeyStr( L"data", item^.TransportData, FALSE );
         ELSIF item^ IS Items.CLicence THEN
            INI.CreateSection( L"licence", TRUE );
            INI.SetKeyStr( L"created", item^.CreatedString, FALSE );
            INI.SetKeyStr( L"serial", Items.TPLicence( item )^.Serial, FALSE );
            INI.SetKeyStr( L"owner", Items.TPLicence( item )^.Owner, FALSE );
            INI.SetKeyStr( L"data", item^.TransportData, FALSE );
         ELSIF item^ IS Items.CActivation THEN
            INI.CreateSection( L"activation", TRUE );
            INI.SetKeyStr( L"created", item^.CreatedString, FALSE );
            INI.SetKeyStr( L"ofserial", Items.TPActivation( item )^.OfSerial, FALSE );
            INI.SetKeyStr( L"starts", Items.TPActivation( item )^.StartsString, FALSE );
            INI.SetKeyStr( L"expires", Items.TPActivation( item )^.ExpiresString, FALSE );
            INI.SetKeyStr( L"data", item^.TransportData, FALSE );
         ELSIF item^ IS Items.CInfo THEN
            INI.CreateSection( L"info", TRUE );
            INI.SetKeyStr( L"id", item^.ProductId, FALSE );
            list := Items.TPInfo( item )^.List;
            list^.Reset();
            WHILE list^.MoveNext() DO
               INI.SetKeyStr( OA( list^.Current^.Length-1, list^.Current^.rawData ), list^.CurrentData^, FALSE );
            END; // WHILE
            INI.SetKeyStr( L"data", item^.TransportData, FALSE );
         END;
	   END; // FOR
	
	   TRY
         fs.FromPath( File, FIOO.imCreate );
      CATCH e : IOO.CIOException DO
         logger()^.LogExc( dldTrace, EMITW( %lprocedure ), e );
         RETURN;
      END;
      tw.Stream := ADR( fs );
      INI.Save( tw );
      fs.Close( FALSE );
	END StoreFile;

(*--------------------------------------------------------------------------------*)

END CINIFilter;

(*================================================================================*)

END Store.