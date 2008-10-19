IMPLEMENTATION MODULE View;

IMPORT
   FIOO,
   HttpCommon,
   HttpTools,
   IOO,
   Languages,
   LanguagesO,
   lists,
   maps,
   Strings;

(*================================================================================*)

CLASS IMPLEMENTATION CRawHTMLView;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Format( CONST Request : MVC.TPHttpRequest; OUT Output : StorageO.CMemoryBuffer ) : BOOLEAN; // returning false means 500 response
   BEGIN
      Request^.ResponseHeaders^.Add( HttpCommon.ContentType, HttpTools.FormatContentOA( HttpTools.contentTextHTML, L"utf-8" ));
      LanguagesO.ToMB( HTML, Languages.cp_UTF8, FALSE, REF Output );
      RETURN TRUE;
   END Format;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( CONST HTML : ARRAY OF WCHAR );   
   BEGIN
      SELF.HTML.FromOA( HTML );
   END Init;
   
(*--------------------------------------------------------------------------------*)

END CRawHTMLView;

(*================================================================================*)

CLASS IMPLEMENTATION CPageTemplateView;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Format( CONST Request : MVC.TPHttpRequest; OUT Output : StorageO.CMemoryBuffer ) : BOOLEAN; // returning false means 500 response
   VAR
      fs : FIOO.CFileStream;
      mbs : IOO.CMemoryBufferStream;
      viewPath : StringsO.CString;
   BEGIN
      IF Resolver = NIL THEN
         viewPath := ViewName;
      ELSIF NOT Resolver^.Resolve( OA( ViewName.Length-1, ViewName.rawData ), OUT viewPath ) THEN
         // LOG, output
         RETURN FALSE;
      END;

      TRY
         fs.FromPath( OA( viewPath.Length-1, viewPath.rawData ), FIOO.imOpenRead );
      CATCH e : IOO.CIOException DO
         // LOG, output
         RETURN FALSE;
      END;
      Reader.Stream := ADR( fs );

      mbs.Init( REF Output, IOO.accWrite );
      Writer.Stream := ADR( mbs );

      IF NOT Parse( Request ) THEN
         RETURN FALSE;
      END;
      
      Request^.ResponseHeaders^.Add( HttpCommon.ContentType, HttpTools.FormatContentOA( HttpTools.contentTextHTML, L"utf-8" ));
      RETURN TRUE;
   END Format;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( CONST Resolver : FSO.TPFilePathResolver; CONST ViewName : ARRAY OF WCHAR );
   BEGIN
      SELF.Resolver := Resolver;
      SELF.ViewName.FromOA( ViewName );
   END Init;
   
(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Parse( CONST Request : MVC.TPHttpRequest ) : BOOLEAN;
   LABEL
      Next;
   CONST
      PT_CONDITION = L"ptcond";
      PT_TYPE = L"pttype";
   VAR
      attributes : lists.CStringStringList;
      depth : INTEGER := 0;
      ename : StringsO.CString;
      name : StringsO.CString;
      nodeType : xmlreader.TNodeType;
      omitstart : INTEGER := -1;
      onstart : BOOLEAN := TRUE; // whitespaces before the first element are ignored
      ps1, ps2 : StringsO.TPString;
      value : StringsO.CString;
      xmle : xmlreader.TXMLError;
   BEGIN
      xmle := Reader.MoveNext();
      WHILE xmle = xmlreader.xmle_S_OK DO
         ASSERT( depth >= 0 );
         
         nodeType := Reader.CurrentType;
         IF nodeType = xmlreader.xntElementBegin THEN
            INC( depth );
         ELSIF nodeType = xmlreader.xntElementEnd THEN
            IF depth > omitstart THEN
               DEC( depth );
            ELSIF depth = omitstart THEN
               DEC( depth );
               omitstart := -1;
               GOTO Next;
            ELSE
               DEC( depth );
            END;
         END;
         IF omitstart > -1 THEN
            GOTO Next;
         END;
      
         CASE Reader.CurrentType OF
         |  xmlreader.xntUnknown,
            xmlreader.xntDocumentType,
            xmlreader.xntCDATA,
            xmlreader.xntProcessingInstruction,
            xmlreader.xntComment :
            GOTO Next;

         | xmlreader.xntXMLDeclaration :
            GOTO Next; // omit, Writer writes declaration itself

         | xmlreader.xntText :
            ParseText( Request, Reader.CurrentValue, OUT value );
            Writer.WriteString( value );

         | xmlreader.xntElementBegin :
            onstart := FALSE; // allow writing whitespaces

         | xmlreader.xntElementEnd :
            Writer.WriteElementEnd();

         | xmlreader.xntAttribute :
            ASSERT( FALSE ); // should not occur here

         | xmlreader.xntWhitespace :
            GOTO Next; // omit, Writer handles EOLs by itself
            (*
            IF onstart THEN
               GOTO Next;
            END;
            Writer.WriteString( Reader.CurrentValue );
            *)
         END; // CASE

         IF Reader.CurrentType = xmlreader.xntElementBegin THEN // evaluate element begin
            ename := Reader.CurrentName;
            
            IF Reader.MoveToFirstAttribute() = xmlreader.xmle_S_OK THEN
               attributes.Dispose();
               REPEAT
                  IF Reader.CurrentType <> xmlreader.xntAttribute THEN
                     ASSERT( FALSE ); // should not occur here
                     CONTINUE;
                  END;
                  
                  name := Reader.CurrentName;
                  IF name.EqualsOA( PT_CONDITION ) THEN
                     IF NOT EvaluateBoolean( Request, Reader.CurrentValue ) THEN
                        omitstart := depth;
                        attributes.Dispose();
                        GOTO Next;
                     END;
                     
                  ELSIF name.EqualsOA( PT_TYPE ) THEN
                     (*?*)

                  ELSE
                     attributes.Add( name, Reader.CurrentValue );
                  END;

               UNTIL Reader.MoveToNextAttribute() <> xmlreader.xmle_S_OK;

               Writer.WriteElementStartOA( OA( ename.Length-1, ename.rawData ));

               attributes.Reset();
               WHILE attributes.MoveNext() DO
                  ps1 := attributes.Current;
                  ParseText( Request, attributes.CurrentData^, OUT value );
                  Writer.WriteAttributeStringOA( OA( ps1^.Length-1, ps1^.rawData ), OA( value.Length-1, value.rawData ));
               END; // WHILE
               
            ELSE // no attributes
               Writer.WriteElementStartOA( OA( ename.Length-1, ename.rawData ));
            END;
            
         END; // IF xntElementBegin

      Next:      
         xmle := Reader.MoveNext()   
      END; // WHILE
     
      Writer.Close( FALSE ); 

      RETURN TRUE;
   END Parse;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ParseText( CONST Request : MVC.TPHttpRequest; CONST Text : StringsO.IString; OUT Parsed : StringsO.IString );
   VAR
      i, mi, j : INTEGER;
      model : StringsO.CString;
      value : StringsO.CString;
   BEGIN
      Parsed.Assign( Text );
      i := -1;
      LOOP
         // get ${
         i := Parsed.IndexOfOA( L"${", i+1 );
         IF i = -1 THEN
            EXIT;
         ELSIF ( i > 0 ) AND ( Parsed[i-1] = L"\" ) THEN // not pattern
            CONTINUE;
         END;

         // get }
         mi := i + 2;
         j := Parsed.IndexOfOA( L"}", mi );
         IF j = mi+1 THEN
            CONTINUE;
         END;

         // resolve and replace model
         Parsed.Substring( mi, j-mi, OUT model );
         GetModelValue( Request, model, OUT value );
         Parsed.Remove( i, j-i+1 );
         Parsed.Insert( i, value );
      END; // LOOP
   END ParseText;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE GetModelValue( CONST Request : MVC.TPHttpRequest; CONST model : StringsO.CString; OUT value : StringsO.IString ) : BOOLEAN;
   VAR
      boolean : BOOLEAN;
      i, index, j : INTEGER;
      list : lists.TPStringStringList;
      map : maps.TPStringStringMap;
      ps : StringsO.TPString;
      sindex1, sindex2 : StringsO.CString;
   BEGIN
      i := model.IndexOfOA( L".", 0 );
      IF i > 0 THEN // ok, find in map
         IF Request^.ModelContainer^.GetMapOA( OA( i-1, model.rawData ), OUT map ) THEN
            model.Substring( i+1, -1, OUT sindex1 );            
            ParseText( Request, sindex1, OUT sindex2 );
            IF map^.GetOA( OA( sindex2.Length-1, sindex2.rawData ), OUT value ) THEN
               RETURN TRUE;
            END;
         END;
      END;

      i := model.IndexOfOA( L"[", 0 );
      IF i > 0 THEN // ok, find in map or list
         index := -1;
         j := model.IndexOfOA( L"]", i+1 );
         IF j > -1 THEN
            model.Substring( i+1, j-i-1, OUT sindex1 );
            ParseText( Request, sindex1, OUT sindex2 );
            sindex2.Trim();
            IF NOT Strings.ToINT32W( OA( sindex2.Length-1, sindex2.rawData ), 10, OUT index ) THEN
               index := -1;
            END;
         END;
         IF index > -1 THEN
            IF Request^.ModelContainer^.GetMapOA( OA( i-1, model.rawData ), OUT map ) THEN
               ps := map^[index];
               IF ps <> NIL THEN
                  value.Assign( ps^ );
                  RETURN TRUE;
               END;
            END;
            IF Request^.ModelContainer^.GetListOA( OA( i-1, model.rawData ), OUT list ) THEN
               ps := list^[index];
               IF ps <> NIL THEN
                  value.Assign( ps^ );
                  RETURN TRUE;
               END;
            END;
         END;
      END;
      
      // test string
      IF Request^.ModelContainer^.GetStringOA( OA( model.Length-1, model.rawData ), OUT value ) THEN
         RETURN TRUE;
      END;
      
      // test boolean
      IF Request^.ModelContainer^.GetBooleanOA( OA( model.Length-1, model.rawData ), OUT boolean ) THEN
         IF boolean THEN
            value.FromOA( L"true" );
         ELSE
            value.FromOA( L"false" );
         END;
         RETURN TRUE;
      END;

      // emit error      
      value.FromOA( L'##unknown model: ' );
      value.Append( model );
      value.AppendOA( L"" );
      RETURN FALSE;
   END GetModelValue;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE EvaluateBoolean( CONST Request : MVC.TPHttpRequest; CONST Value : StringsO.IString ) : BOOLEAN;
   VAR
      modelValue : BOOLEAN;
   BEGIN
      IF Value.EqualsOA( L"true" ) OR Value.EqualsOA( L"1" ) THEN
         RETURN TRUE;
      ELSIF Request^.ModelContainer^.GetBooleanOA( OA( Value.Length-1, Value.rawData ), OUT modelValue ) THEN
         RETURN modelValue;
      ELSE
         RETURN FALSE;
      END;
   END EvaluateBoolean;

(*--------------------------------------------------------------------------------*)

BEGIN
   Resolver := NIL;
END CPageTemplateView;

(*================================================================================*)

END View.