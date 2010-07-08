IMPLEMENTATION MODULE INIFile;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;
FROM Strings IMPORT
   CapitalizeW;
FROM Exceptions IMPORT
   TestIfCatched;

IMPORT
   FIOO,
   IOO,
   TextReader,
   TextWriter,
   Strings,
   Sync;
   
(*================================================================================*)

CLASS CDataListElem( list.CListElem );
   IsSection : BOOLEAN;
   SourceLine : CARDINAL;
   KeyStr : StringsO.CString;
   DataStr : StringsO.CString;
END CDataListElem;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CDataListElem;
BEGIN
   IsSection := FALSE;
   SourceLine := -1;
END CDataListElem;

(*================================================================================*)

CLASS IMPLEMENTATION CINIFile;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Clear();
   BEGIN
      _DataList.Dispose();
      _PSection := NIL;
      Modified := FALSE;
   END Clear;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Load( CONST Reader : TextReader.CTextReader ) : BOOLEAN;
   VAR
      c : CARDINAL;
      Line : StringsO.CString;
      PDataElem : TPDataListElem;
   BEGIN 
      Clear();
      
      WHILE Reader.ReadLineS( OUT Line ) DO
         Line.Trim();
         IF NOT Line.Empty THEN
            IF Line.StartsWithOA( W'[' ) THEN
               c := Line.IndexOfOA( W']', 0 );
               IF c <> MAX(CARDINAL) THEN
                  NEW( PDataElem );
                  WITH PDataElem^ DO
                     IsSection := TRUE;
                     SourceLine := Reader.Line;
                     Line.Substring( 1, c-1, OUT KeyStr );
                     KeyStr.Trim();
                  END;
                  _DataList.Append( PDataElem );
               END;
            ELSE
               NEW( PDataElem );
               WITH PDataElem^ DO
                  IsSection := FALSE;
                  SourceLine := Reader.Line;
                  c := Line.IndexOfOA( W'=', 0 );
                  IF c <> MAX( CARDINAL ) THEN
                     Line.Substring( 0, c, OUT KeyStr );
                     Line.Substring( c+1, -1, OUT DataStr );
                     DataStr.Trim();
                  END;
                  KeyStr.Trim();
               END;
               _DataList.Append( PDataElem );
            END;
         END;
      END;

      RETURN TRUE;
   END Load;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE LoadPath( CONST FilePath : ARRAY OF WCHAR ) : BOOLEAN; // handy shortcut
   VAR
      comment : StringsO.CString;
      fs : FIOO.CFileStream;
      tr : TextReader.CTextReader;
   BEGIN
      TRY
         fs.FromPath( FilePath, FIOO.imOpenRead );
      CATCH : IOO.CIOException DO
         RETURN FALSE;
      END;

      comment.FromOA( L";" );
      tr.Stream := ADR( fs );
      tr.OmitCommentaries := TRUE;
      tr.CommentaryStart := comment;
      IF Load( tr ) THEN
         fs.Close( FALSE );
         RETURN TRUE;

      ELSE
         fs.Close( FALSE );
         RETURN FALSE;
      END;
   END LoadPath;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Save( CONST Writer : TextWriter.CTextWriter ) : BOOLEAN;
   VAR
      PElem : TPDataListElem;
      b : BOOLEAN;
      LineEnd : BOOLEAN := FALSE;
   BEGIN
      IF NOT Modified THEN
         RETURN TRUE;
      END;

      LineEnd := FALSE;
      b := _DataList.GetFirst( OUT PElem );
      WHILE b DO
         IF PElem^.IsSection THEN
            IF LineEnd THEN
               Writer.LineEnd();
            END;
            Writer.WriteOA( W'[', FALSE );
         END;
         Writer.Write( PElem^.KeyStr, FALSE );
         IF PElem^.IsSection THEN
            Writer.WriteOA( W']', TRUE );
         ELSE
            Writer.WriteOA( W' = ', FALSE );
            Writer.Write( PElem^.DataStr, TRUE );
         END;

         b := _DataList.NextOf( PElem, OUT PElem );
         LineEnd := TRUE;
      END;

      RETURN TRUE;
   END Save;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SavePath( CONST FilePath : ARRAY OF WCHAR ) : BOOLEAN; // handy shortcut
   VAR
      fs : FIOO.CFileStream;
      tw : TextWriter.CTextWriter;
   BEGIN
      TRY
         fs.FromPath( FilePath, FIOO.imCreate );
      CATCH : IOO.CIOException DO
         RETURN FALSE;
      END;
      tw.Stream := ADR( fs );
      IF Save( tw ) THEN
         fs.Close( FALSE );
         RETURN TRUE;
      ELSE
         fs.Close( FALSE );
         RETURN FALSE;
      END;
   END SavePath;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SetSection( CONST Section : ARRAY OF WCHAR ): BOOLEAN;
   VAR
      PElem : TPDataListElem;
      b : BOOLEAN;
   BEGIN
      IF Section[0] = 0W THEN
         _PSection := NIL;
         RETURN TRUE;
      END;
      b := _DataList.GetFirst( OUT PElem );
      WHILE b DO
         IF ( PElem^.IsSection ) AND PElem^.KeyStr.EqualsOA( Section ) THEN
            _PSection := PElem;
            RETURN TRUE;
         END;
         b := _DataList.NextOf( PElem, OUT PElem );
      END;
      _PSection := NIL;
      RETURN FALSE;
   END SetSection;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CreateSection( CONST Section : ARRAY OF WCHAR; Multiple : BOOLEAN );
   VAR
      PElem : TPDataListElem;
   BEGIN
      IF Multiple OR NOT SetSection( Section ) THEN
         NEW( PElem );
         WITH PElem^ DO
            IsSection := TRUE;
            KeyStr.FromOA( Section );
         END;
         _DataList.Append( PElem );
         _PSection := PElem;
         Modified := TRUE;
      END;
   END CreateSection;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ClearSection( CONST Section : ARRAY OF WCHAR ) : BOOLEAN;
   VAR
      PElem, PNext : TPDataListElem;
      b : BOOLEAN;
   BEGIN
      IF NOT SetSection( Section ) THEN
         RETURN FALSE;
      ELSIF _PSection = NIL THEN
         b := _DataList.GetFirst( OUT PElem );
      ELSE
         b := _DataList.NextOf( _PSection, OUT PElem );
      END;
      WHILE b AND NOT PElem^.IsSection DO
         b := _DataList.NextOf( PElem, OUT PNext );
         _DataList.Delete( PElem );
         PElem := PNext;
      END;
      Modified := TRUE;
      RETURN TRUE;
   END ClearSection;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE DeleteSection( CONST Section : ARRAY OF WCHAR ) : BOOLEAN;
   BEGIN
      IF NOT ClearSection( Section ) THEN
         RETURN FALSE;
      ELSIF _PSection = NIL THEN
         Clear();
      ELSE
         _DataList.Delete( _PSection );
      END;
      Modified := TRUE;
      RETURN TRUE;
   END DeleteSection;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE GetKeyStr( CONST Key : ARRAY OF WCHAR; OUT Line : CARDINAL; OUT V : StringsO.IString ): BOOLEAN;
   VAR
      PElem : TPDataListElem;
      b : BOOLEAN;
   BEGIN
      IF _PSection = NIL THEN
         b := _DataList.GetFirst( OUT PElem );
      ELSE
         b := _DataList.NextOf( _PSection, OUT PElem );
      END;
      WHILE b DO
         IF PElem^.IsSection THEN
            RETURN FALSE;
         ELSIF PElem^.KeyStr.EqualsOA( Key ) THEN
            Line := PElem^.SourceLine;
            V.Assign( PElem^.DataStr );
            RETURN TRUE;
         END;
         b := _DataList.NextOf( PElem, OUT PElem );
      END;
      RETURN FALSE;
   END GetKeyStr;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE GetKeyBool( CONST Key : ARRAY OF WCHAR; OUT Line : CARDINAL; OUT V : BOOLEAN ): BOOLEAN;
   VAR
      s : StringsO.CString;
   BEGIN
      IF NOT GetKeyStr( Key, OUT Line, OUT s ) THEN
         RETURN FALSE;
      END;
      IF s.EqualsOA( L'0' ) OR s.EqualsIgnoreCaseOA( L'FALSE' ) THEN
         V := FALSE;
      ELSIF s.EqualsOA( L'1' ) OR s.EqualsIgnoreCaseOA( L'TRUE' ) THEN
         V := TRUE;
      ELSE
         RETURN FALSE;
      END;
      RETURN TRUE;
   END GetKeyBool;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE GetKeyInt( CONST Key : ARRAY OF WCHAR; OUT Line : CARDINAL; OUT V : INTEGER ): BOOLEAN;
   VAR
      s : StringsO.CString;
   BEGIN
      IF NOT GetKeyStr( Key, OUT Line, OUT s ) THEN
         RETURN FALSE;
      ELSIF NOT s.ToINT32( 10, OUT V ) THEN
         RETURN FALSE;
      END;
      RETURN TRUE;
   END GetKeyInt;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE GetKeyReal( CONST Key : ARRAY OF WCHAR; OUT Line : CARDINAL; OUT V : LONGREAL ): BOOLEAN;
   VAR
      s : StringsO.CString;
   BEGIN
      IF NOT GetKeyStr( Key, OUT Line, OUT s ) THEN
         RETURN FALSE;
      ELSIF NOT s.ToLONGREAL( OUT V ) THEN
         RETURN FALSE;
      END;
      RETURN TRUE;
   END GetKeyReal;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SetKeyStr( CONST Key : ARRAY OF WCHAR; CONST V : StringsO.IString; Multiple : BOOLEAN ): BOOLEAN;

      PROCEDURE SetKeyStrLocal(): BOOLEAN;
      VAR
         PElem : TPDataListElem;
         b : BOOLEAN;
      BEGIN
         IF _PSection = NIL THEN
            b := _DataList.GetFirst( OUT PElem );
         ELSE
            b := _DataList.NextOf( _PSection, OUT PElem );
         END;
         WHILE b DO
            IF PElem^.IsSection THEN
               RETURN FALSE;
            ELSIF PElem^.KeyStr.EqualsOA( Key ) THEN
               PElem^.DataStr.Assign( V );
               Modified := TRUE;
               RETURN TRUE;
            END;
            b := _DataList.NextOf( PElem, OUT PElem );
         END;
         RETURN FALSE;
      END SetKeyStrLocal;

(*--------------------------------------------------------------------------------*)

   VAR
      PBefore : TPDataListElem := NIL;
      PElem : TPDataListElem;
      b : BOOLEAN;
   BEGIN
      IF Multiple OR NOT SetKeyStrLocal() THEN
         IF _PSection <> NIL THEN
            b := _DataList.NextOf( _PSection, OUT PElem );
            LOOP
               IF NOT b THEN
                  EXIT;
               ELSIF PElem^.IsSection THEN
                  PBefore := PElem;
                  EXIT;
               END;
               b := _DataList.NextOf( PElem, OUT PElem );
            END; // LOOP
         END;
         NEW( PElem );
         WITH PElem^ DO
            IsSection := FALSE;
            KeyStr.FromOA( Key );
            DataStr.Assign( V );
         END;
         IF ( _PSection <> NIL ) AND ( PBefore <> NIL ) THEN
            _DataList.InsertBefore( PBefore, PElem );
         ELSE
            _DataList.Append( PElem );
         END;
         Modified := TRUE;
      END;
      RETURN TRUE;
   END SetKeyStr;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SetKeyBool( CONST Key : ARRAY OF WCHAR; V : BOOLEAN; Multiple : BOOLEAN ): BOOLEAN;
   VAR
      s : StringsO.CString;
   BEGIN
      IF V THEN
         s.FromOA( L'true' );
      ELSE
         s.FromOA( L'false' );
      END;
      RETURN SetKeyStr( Key, s, Multiple );
   END SetKeyBool;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SetKeyInt( CONST Key : ARRAY OF WCHAR; V : INTEGER; Multiple : BOOLEAN ): BOOLEAN;
   VAR
      s : StringsO.CString;
   BEGIN
      s.FromINT32( V, 10 );
      RETURN SetKeyStr( Key, s, Multiple );
   END SetKeyInt;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SetKeyReal( CONST Key : ARRAY OF WCHAR; V : LONGREAL; Multiple : BOOLEAN ): BOOLEAN;
   VAR
      s : StringsO.CString;
   BEGIN
      s.FromLONGREAL( V, FALSE );
      RETURN SetKeyStr( Key, s, Multiple );
   END SetKeyReal;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE EnumerateSections( REF EnumerateState : PTR; OUT Line : CARDINAL; OUT Section : ARRAY OF WCHAR; SetAsActive : BOOLEAN ) : BOOLEAN;
   VAR
      PElem : TPDataListElem;
      b : BOOLEAN;
   BEGIN
      IF EnumerateState <> NIL THEN
         b := _DataList.NextOf( TPDataListElem( EnumerateState ), OUT PElem );
      ELSE
         b := _DataList.GetFirst( OUT PElem );
      END;
      WHILE b DO
         IF PElem^.IsSection THEN
            EnumerateState := PElem;
            Line := PElem^.SourceLine;
            PElem^.KeyStr.ToOA( OUT Section );
            IF SetAsActive THEN
               _PSection := PElem;
            END;
            RETURN TRUE;
         ELSE
            b := _DataList.NextOf( PElem, OUT PElem );
         END;
      END; // WHILE
      RETURN FALSE;
   END EnumerateSections;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE EnumerateKeys( REF EnumerateState : PTR; OUT Line : CARDINAL; OUT Key : ARRAY OF WCHAR; OUT Value : StringsO.IString ) : BOOLEAN;
   VAR
      PElem : TPDataListElem;
      b : BOOLEAN;
   BEGIN
      IF EnumerateState <> NIL THEN
         b := _DataList.NextOf( TPDataListElem( EnumerateState ), OUT PElem );
      ELSIF _PSection = NIL THEN
         b := _DataList.GetFirst( OUT PElem );
      ELSE
         b := _DataList.NextOf( _PSection, OUT PElem );
      END;
      WHILE b DO
         IF NOT PElem^.IsSection THEN
            EnumerateState := PElem;
            Line := PElem^.SourceLine;
            PElem^.KeyStr.ToOA( OUT Key );
            Value.Assign( PElem^.DataStr );
            RETURN TRUE;
         ELSIF PElem^.IsSection THEN
            RETURN FALSE;
         ELSE
            b := _DataList.NextOf( PElem, OUT PElem );
         END;
      END; // WHILE
      RETURN FALSE;
   END EnumerateKeys;

(*--------------------------------------------------------------------------------*)

BEGIN
   _PSection := NIL;
   Modified := FALSE;
FINALLY
   Clear();
END CINIFile;

(*================================================================================*)

PROCEDURE ConfigureLog( CONST ini : CINIFile; CONST SectionName : ARRAY OF WCHAR; REF logger : Log.CLogger; OUT errorLine : CARDINAL ) : TConfigureLogResult;
VAR
   Cached : CARDINAL;
   cs : StringsO.CString;
   File : StringsO.CString;
   haveCached : BOOLEAN := FALSE;
   Level : Log.TDebugLevel := logger^.Level;
   Method : Log.TDebugMethod := logger^.Method;
BEGIN
   IF ( SectionName[0] <> 0W ) AND ini.SetSection( SectionName ) OR ini.SetSection( snLog ) THEN

      IF ini.GetKeyStr( knTarget, OUT errorLine, OUT cs ) THEN
         IF cs.EqualsOA( kvTargetNone ) THEN
            Method := Log.dmNone;
         ELSIF cs.EqualsOA( kvTargetFile ) THEN
            Method := Log.dmFile;
            IF NOT ini.GetKeyStr( knFile, OUT errorLine, OUT File ) THEN
               RETURN clrTargetFileMissingFile;
            END;
         ELSIF cs.EqualsOA( kvTargetKernel ) THEN
            Method := Log.dmKernel;
         ELSE
            RETURN clrUnknownTarget;
         END;
      END;

      IF Method <> Log.dmNone THEN

         IF ini.GetKeyStr( knLevel, OUT errorLine, OUT cs ) THEN
            IF cs.EqualsOA( kvDebugFailure ) OR cs.EqualsOA( kvFatal ) THEN
               Level := Log.dldError;
            ELSIF cs.EqualsOA( kvDebugMessage ) OR cs.EqualsOA( kvError ) THEN
               Level := Log.dldMessage;
            ELSIF cs.EqualsOA( kvDebugTrace ) OR cs.EqualsOA( kvWarning ) THEN
               Level := Log.dldTrace;
            ELSIF cs.EqualsOA( kvDebugAll ) OR cs.EqualsOA( kvInfo ) THEN
               Level := Log.dldDebug;
            ELSE
               RETURN clrUnknownLevel;
            END;
         END;
         
         haveCached := ini.GetKeyInt( knCached, OUT errorLine, OUT Cached );

      END;
      
   END;
   
   logger^.SetLogFile( OA( File.Length-1, File.rawData ));
   logger^.Method := Method;
   logger^.Level := Level;
   IF buffered AND haveCached THEN
      Log.TPBufferedLogger( logger )^.BufferSize := Cached;
   END;
   
   RETURN clrSuccess;
END ConfigureLogInternal;

(*================================================================================*)

PROCEDURE ConfigureLoggerFilter( CONST ini : CINIFile; CONST SectionName : ARRAY OF WCHAR; REF filter : LoggerFilter.CLoggerFilter; OUT errorLine : CARDINAL ) : TConfigureLoggerFilterResult;
VAR
   cs : StringsO.CString;
   data : ARRAY [0..1] OF StringsO.CString;
   deny : BOOLEAN;
   es : PTR;
   key : ARRAY [0..31] OF WCHAR;
   line : CARDINAL;
   pieces : CARDINAL;
   value : StringsO.CString;
BEGIN
   filter.Reset();

   IF ( SectionName[0] <> 0W ) AND ini.SetSection( SectionName ) OR ini.SetSection( snLog ) THEN

      IF ini.GetKeyStr( knLevel, OUT errorLine, OUT cs ) THEN
         IF cs.EqualsOA( kvDebugFailure ) OR cs.EqualsOA( kvFatal ) THEN
            filter.Level := Log.dldError;
         ELSIF cs.EqualsOA( kvDebugMessage ) OR cs.EqualsOA( kvError ) THEN
            filter.Level := Log.dldMessage;
         ELSIF cs.EqualsOA( kvDebugTrace ) OR cs.EqualsOA( kvWarning ) THEN
            filter.Level := Log.dldTrace;
         ELSIF cs.EqualsOA( kvDebugAll ) OR cs.EqualsOA( kvInfo ) THEN
            filter.Level := Log.dldDebug;
         ELSE
            RETURN clfrUnknownLevel;
         END;
      END;
      
      es := 0;
      WHILE ini.EnumerateKeys( REF es, OUT line, OUT key, OUT value ) DO
         IF NOT EQUALS( key, knFilter ) THEN
            CONTINUE;
         END;

         value.SplitS( StringsO.WCHARS{L","}, 0, TRUE, OUT pieces, OUT data );
         IF pieces < 1 THEN
            RETURN clfrUnknownPolicy;
         ELSIF pieces < 2 THEN
            RETURN clfrMissingPattern;
         END;
         IF data[0].EqualsOA( kvDeny ) THEN
            deny := TRUE;
         ELSIF data[0].EqualsOA( kvAllow ) THEN
            deny := FALSE;
         ELSE
            RETURN clfrUnknownPolicy;
         END;

         data[1].Trim();
         filter.AddRule( NOT deny, deny, data[1] );
      END; // WHILE

   END;
   
   RETURN clfrSuccess;
END ConfigureLoggerFilter;

(*================================================================================*)

END INIFile.
