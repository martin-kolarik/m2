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
   NodeList,
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

CONST
   PT_XMLNS = L"xmlns";
   PT_NAMESPACE = L"http://www.smartcontrol.cz/2008/XML/Web/PageTemplate";
   PT_ROOTNAME = L"pagetemplate";
      PT_CONDITION = L"condition";
   PT_CHOOSE = L"choose";
      PT_WHEN = L"when";
      PT_OTHERWISE = L"otherwise";
   PT_FOR = L"for";
      PT_FROM = L"from";
      PT_TO = L"to";
      PT_BY = L"by";
      PT_INDEX = L"index";
      PT_ODD = L"odd";
   PT_FOREACH = L"foreach";
      PT_SOURCE = L"source";
      PT_ITEM = L"item";
   PT_FORM = L"form";
      PT_MODEL = L"model";
      PT_FORM_INPUT = L"input";
      PT_FORM_CHECKBOX = L"checkbox";
      PT_FORM_RADIOBUTTON = L"radiobutton";
      PT_FORM_PASSWORD = L"password";
      PT_FORM_SELECT = L"select";
      PT_FORM_OPTION = L"option";
      PT_FORM_TEXTAREA = L"textarea";
      PT_FORM_HIDDEN = L"hidden";
      PT_FORM_ERRORS = L"errors";

CLASS IMPLEMENTATION CPageTemplateView;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Format( CONST Request : MVC.TPHttpRequest; OUT Output : StorageO.CMemoryBuffer ) : BOOLEAN; // returning false means 500 response
   VAR
      b : BOOLEAN;
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
      b := ParseRoot( Request );
      Writer.Close( FALSE ); 
      
      IF b THEN
         Request^.ResponseHeaders^.Add( HttpCommon.ContentType, HttpTools.FormatContentOA( HttpTools.contentTextHTML, L"utf-8" ));
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END Format;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( CONST Resolver : FSO.TPFilePathResolver; CONST ViewName : ARRAY OF WCHAR );
   BEGIN
      SELF.Resolver := Resolver;
      SELF.ViewName.FromOA( ViewName );
   END Init;
   
(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ParseRoot( CONST Request : MVC.TPHttpRequest ) : BOOLEAN;
   VAR
      xmle : xmlreader.TXMLError;
   BEGIN
      xmle := Reader.MoveNext();
      WHILE xmle = xmlreader.xmle_S_OK DO
         
         CASE Reader.CurrentType OF
         | xmlreader.xntText :
            ASSERT( FALSE ); // should not occur here

         | xmlreader.xntElementBegin :
            IF NOT Reader.CurrentName.EqualsIgnoreCaseOA( PT_ROOTNAME ) THEN
               RETURN FALSE;
            ELSIF Reader.MoveToFirstAttribute() <> xmlreader.xmle_S_OK THEN
               RETURN FALSE; // at least single attribute with xmlns:... must be present
            END;
            
            Prefix.Clear();
            REPEAT
               IF Reader.CurrentType <> xmlreader.xntAttribute THEN
                  ASSERT( FALSE ); // should not occur here
                  CONTINUE;
               ELSIF Reader.CurrentPrefix.EqualsIgnoreCaseOA( PT_XMLNS ) AND Reader.CurrentValue.EqualsIgnoreCaseOA( PT_NAMESPACE ) THEN
                  Prefix := Reader.CurrentName;
               END;
            UNTIL Reader.MoveToNextAttribute() <> xmlreader.xmle_S_OK;
            
            IF Prefix.Empty THEN
               RETURN FALSE;
            END;
            PrefixCondition := Prefix;
            PrefixCondition.AppendOA( L":" );
            PrefixCondition.AppendOA( PT_CONDITION );
            
            RETURN Parse( Request, TRUE );

         | xmlreader.xntAttribute :
            ASSERT( FALSE ); // should not occur here
         END; // CASE

         xmle := Reader.MoveNext();
      END; // WHILE
      RETURN TRUE;
   END ParseRoot;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Parse( CONST Request : MVC.TPHttpRequest; Emit : BOOLEAN ) : BOOLEAN;
   LABEL
      Next;
   VAR
      attributes : lists.CStringStringList;
      depth : INTEGER := 0;
      empty : StringsO.CString;
      nodeName : StringsO.CString;
      nodePrefix : StringsO.CString;
      nodeType : xmlreader.TNodeType;
      nodeValue : StringsO.CString;
      isEmpty : BOOLEAN;
      pname : StringsO.TPString;
      ptFlag : BOOLEAN;
      value : StringsO.CString;
   BEGIN
      INC( depth ); // we entered element

      LOOP
         CASE MoveNext( OUT nodeType, OUT nodePrefix, OUT nodeName, OUT isEmpty, OUT nodeValue, OUT attributes ) OF
         | xmlreader.xmle_S_OK :
            // continue
         | xmlreader.xmle_S_FALSE :
            RETURN TRUE;
         ELSE
            RETURN FALSE;
         END;
        
         IF nodeType = xmlreader.xntElementBegin THEN
            INC( depth );
         ELSIF nodeType = xmlreader.xntElementEnd THEN
            IF depth = 1 THEN
               RETURN TRUE;
            END;
            DEC( depth );
         END;
         IF NOT Emit THEN
            GOTO Next;
         END;

         CASE nodeType OF
         | xmlreader.xntText :
            ParseText( Request, nodeValue, OUT value );
            Writer.WriteString( value );

         | xmlreader.xntElementBegin :
            ptFlag := nodePrefix.EqualsIgnoreCase( Prefix );
         
            // look for condition
            attributes.Reset();
            WHILE attributes.MoveNext() DO
               pname := attributes.Current;
               IF ptFlag AND pname^.EqualsIgnoreCaseOA( PT_CONDITION ) OR pname^.EqualsIgnoreCase( PrefixCondition ) THEN
                  IF NOT EvaluateBoolean( Request, attributes.CurrentData^ ) THEN
                     IF Parse( Request, FALSE ) THEN
                        GOTO Next;
                     ELSE
                        RETURN FALSE;
                     END;
                  END;
               END;
            END; // WHILE
            
            IF ptFlag THEN // Page Template element
               IF nodeName.EqualsIgnoreCaseOA( PT_CHOOSE ) THEN
                  IF NOT ParseChoose( Request ) THEN
                     RETURN FALSE;
                  END;
               ELSIF nodeName.EqualsIgnoreCaseOA( PT_FOR ) THEN
                  ParseFor( Request, attributes );
               ELSIF nodeName.EqualsIgnoreCaseOA( PT_FOREACH ) THEN
                  ParseForeach( Request, attributes );
               ELSIF nodeName.EqualsIgnoreCaseOA( PT_FORM ) THEN
                  ParseForm( Request, attributes );
               ELSE
                  RETURN FALSE; // unknown element
               END;

            ELSE // another element
               Writer.WriteElementStartOA( OA( nodeName.Length-1, nodeName.rawData ));

               // write attributes
               attributes.Reset();
               WHILE attributes.MoveNext() DO
                  pname := attributes.Current;
                  IF ptFlag AND pname^.EqualsIgnoreCaseOA( PT_CONDITION ) OR pname^.EqualsIgnoreCase( PrefixCondition ) THEN
                     CONTINUE; // ignore pt:condition
                  END;
                  ParseText( Request, attributes.CurrentData^, OUT value );
                  Writer.WriteAttributeStringOA( OA( pname^.Length-1, pname^.rawData ), OA( value.Length-1, value.rawData ));
               END; // WHILE

               IF isEmpty THEN
                  Writer.WriteElementEnd();
               ELSE
                  Writer.WriteString( empty ); // terminate attributes forcibly
               END;
            END;

         | xmlreader.xntElementEnd :
            Writer.WriteElementEnd(); // writer does it itself
         END; // CASE

      Next:
      END; // WHILE
   END Parse;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ParseChoose( CONST Request : MVC.TPHttpRequest ) : BOOLEAN;
   VAR
      attributes : lists.CStringStringList;
      done : BOOLEAN := FALSE;
      emit : TRISTATE;
      haveOtherwise : BOOLEAN := FALSE;
      isEmpty : BOOLEAN;
      nodeName : StringsO.CString;
      nodePrefix : StringsO.CString;
      nodeType : xmlreader.TNodeType;
      nodeValue : StringsO.CString;
      pname : StringsO.TPString;
   BEGIN
      LOOP
         CASE MoveNext( OUT nodeType, OUT nodePrefix, OUT nodeName, OUT isEmpty, OUT nodeValue, OUT attributes ) OF
         | xmlreader.xmle_S_OK :
            // continue
         | xmlreader.xmle_S_FALSE :
            RETURN TRUE;
         ELSE
            RETURN FALSE;
         END;

         IF nodeType = xmlreader.xntElementBegin THEN
            // ok, follow to processing
         ELSIF nodeType = xmlreader.xntElementEnd THEN // other ends are consumed inside
            RETURN TRUE;
         ELSE
            RETURN FALSE; // nothing other we do not expect
         END;
         
         IF nodeType = xmlreader.xntElementBegin THEN
            IF NOT nodePrefix.EqualsIgnoreCase( Prefix ) THEN
               RETURN FALSE;

            ELSIF nodeName.EqualsIgnoreCaseOA( PT_WHEN ) THEN

               IF done THEN
                  emit := 0;
               ELSE // look for condition
                  emit := -1;
                  attributes.Reset();
                  WHILE attributes.MoveNext() DO
                     pname := attributes.Current;
                     IF pname^.EqualsIgnoreCaseOA( PT_CONDITION ) OR pname^.EqualsIgnoreCase( PrefixCondition ) THEN
                        IF EvaluateBoolean( Request, attributes.CurrentData^ ) THEN
                           emit := 1;
                        ELSE
                           emit := 0;
                        END;
                     END;
                  END; // WHILE
                  IF emit = -1 THEN
                     RETURN FALSE; // condition is required
                  ELSIF emit = 1 THEN
                     done := TRUE;
                  END;
               END;
               
               IF NOT Parse( Request, emit = 1 ) THEN
                  RETURN FALSE;
               END;
            
            ELSIF nodeName.EqualsIgnoreCaseOA( PT_OTHERWISE ) THEN
               IF haveOtherwise THEN
                  RETURN FALSE;
               END;
               haveOtherwise := TRUE;

               IF NOT Parse( Request, NOT done ) THEN
                  RETURN FALSE;
               END;

            ELSE
               RETURN FALSE; // nothing except when or otherwise is bad
            END;
         END;
         
      END; // WHILE
   END ParseChoose;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ParseFor( CONST Request : MVC.TPHttpRequest; CONST attributes : lists.CStringStringList ) : BOOLEAN;
   VAR
      attribute : StringsO.CString;
      by : INTEGER := 1;
      depth : INTEGER := 1; // we are in for
      from : INTEGER;
      haveBy : BOOLEAN := FALSE;
      haveFrom : BOOLEAN := FALSE;
      haveTo : BOOLEAN := FALSE;
      i, iodd : INTEGER;
      index : StringsO.CString;
      inverted : BOOLEAN;
      isEmpty : BOOLEAN;
      lattributes : lists.CStringStringList;
      nl : NodeList.CNodeList;
      nodeName : StringsO.CString;
      nodePrefix : StringsO.CString;
      nodeType : xmlreader.TNodeType;
      nodeValue : StringsO.CString;
      odd : StringsO.CString;
      pname : StringsO.TPString;
      prefix : StringsO.CString;
      to : INTEGER;
      value : StringsO.CString;
   BEGIN
      prefix := Prefix;
      prefix.AppendOA( L":" );

      // first analyze attributes
      attributes.Reset();
      WHILE attributes.MoveNext() DO
         pname := StringsO.TPString( attributes.Current );

         attribute := prefix; attribute.AppendOA( PT_FROM );
         IF pname^.EqualsIgnoreCaseOA( PT_FROM ) OR pname^.EqualsIgnoreCase( attribute ) THEN
            ParseText( Request, attributes.CurrentData^, OUT value );
            TRY
               from := value.ToCARD32( 10 );
               haveFrom := TRUE;
            CATCH e : StringsO.CStringException DO
               RETURN FALSE;
            END;
            CONTINUE;
         END;
         
         attribute := prefix; attribute.AppendOA( PT_TO );
         IF pname^.EqualsIgnoreCaseOA( PT_TO ) OR pname^.EqualsIgnoreCase( attribute ) THEN
            ParseText( Request, attributes.CurrentData^, OUT value );
            TRY
               to := value.ToCARD32( 10 );
               haveTo := TRUE;
            CATCH e : StringsO.CStringException DO
               RETURN FALSE;
            END;
            CONTINUE;
         END;

         attribute := prefix; attribute.AppendOA( PT_BY );
         IF pname^.EqualsIgnoreCaseOA( PT_BY ) OR pname^.EqualsIgnoreCase( attribute ) THEN
            ParseText( Request, attributes.CurrentData^, OUT value );
            TRY
               by := value.ToCARD32( 10 );
               haveBy := TRUE;
            CATCH e : StringsO.CStringException DO
               RETURN FALSE;
            END;
            CONTINUE;
         END;

         attribute := prefix; attribute.AppendOA( PT_INDEX );
         IF pname^.EqualsIgnoreCaseOA( PT_INDEX ) OR pname^.EqualsIgnoreCase( attribute ) THEN
            ParseText( Request, attributes.CurrentData^, OUT index );
            CONTINUE;
         END;

         attribute := prefix; attribute.AppendOA( PT_ODD );
         IF pname^.EqualsIgnoreCaseOA( PT_ODD ) OR pname^.EqualsIgnoreCase( attribute ) THEN
            ParseText( Request, attributes.CurrentData^, OUT odd );
            CONTINUE;
         END;

      END; // WHILE      
      
      IF NOT haveFrom THEN
         RETURN FALSE;
      ELSIF NOT haveTo THEN
         RETURN FALSE;
      ELSIF ( to < from ) AND ( by >= 0 ) THEN
         RETURN FALSE;
      ELSIF ( to > from ) AND ( by <= 0 ) THEN
         RETURN FALSE;
      END;
      
      // second buffer "for" content
      LOOP
         IF MoveNext( OUT nodeType, OUT nodePrefix, OUT nodeName, OUT isEmpty, OUT nodeValue, OUT lattributes ) <> xmlreader.xmle_S_OK THEN
            RETURN FALSE;
         END;
         nl.Add( nodeType, nodePrefix, nodeName, isEmpty, nodeValue, REF lattributes );
         IF nodeType = xmlreader.xntElementBegin THEN
            INC( depth );
         ELSIF nodeType = xmlreader.xntElementEnd THEN // other ends are consumed inside Parse
            IF depth = 1 THEN
               EXIT;
            END;
            DEC( depth );
         END;
      END; // WHILE
      
      // third switch sources and do "for"
      Sources.Push( ADR( nl ));
      inverted := from > to;
      i := from;
      iodd := 1;
      WHILE inverted AND ( i >= to ) OR NOT inverted AND ( i <= to ) DO
         IF NOT odd.Empty THEN
            SetModelBoolean( Request, odd, iodd AND 1 = 1 );
         END;
         IF NOT index.Empty THEN
            value.FromCARD32( i, 10 );
            SetModelValue( Request, index, value );
         END;
         nl.Reset(); // prepare parsing
         Parse( Request, TRUE );
         INC( i, by );
         INC( iodd );
      END; // WHILE
      Sources.Pop();
      
      RETURN TRUE;
   END ParseFor;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ParseForeach( CONST Request : MVC.TPHttpRequest; CONST attributes : lists.CStringStringList ) : BOOLEAN;
   VAR
      attribute : StringsO.CString;
      depth : INTEGER := 1; // we are in foreach
      haveSource : BOOLEAN := FALSE;
      haveList : BOOLEAN := FALSE;
      i : INTEGER;
      index : StringsO.CString;
      item : StringsO.CString;
      isEmpty : BOOLEAN;
      lattributes : lists.CStringStringList;
      list : lists.TPStringStringList;
      map : maps.TPStringStringMap;
      nl : NodeList.CNodeList;
      nodeName : StringsO.CString;
      nodePrefix : StringsO.CString;
      nodeType : xmlreader.TNodeType;
      nodeValue : StringsO.CString;
      odd : StringsO.CString;
      pname : StringsO.TPString;
      prefix : StringsO.CString;
      source : StringsO.CString;
      value : StringsO.CString;
   BEGIN
      prefix := Prefix;
      prefix.AppendOA( L":" );

      // first analyze attributes
      attributes.Reset();
      WHILE attributes.MoveNext() DO
         pname := StringsO.TPString( attributes.Current );

         attribute := prefix; attribute.AppendOA( PT_SOURCE );
         IF pname^.EqualsIgnoreCaseOA( PT_SOURCE ) OR pname^.EqualsIgnoreCase( attribute ) THEN
            ParseText( Request, attributes.CurrentData^, OUT source );
            CONTINUE;
         END;
         
         attribute := prefix; attribute.AppendOA( PT_INDEX );
         IF pname^.EqualsIgnoreCaseOA( PT_INDEX ) OR pname^.EqualsIgnoreCase( attribute ) THEN
            ParseText( Request, attributes.CurrentData^, OUT index );
            CONTINUE;
         END;

         attribute := prefix; attribute.AppendOA( PT_ITEM );
         IF pname^.EqualsIgnoreCaseOA( PT_ITEM ) OR pname^.EqualsIgnoreCase( attribute ) THEN
            ParseText( Request, attributes.CurrentData^, OUT item );
            CONTINUE;
         END;

         attribute := prefix; attribute.AppendOA( PT_ODD );
         IF pname^.EqualsIgnoreCaseOA( PT_ODD ) OR pname^.EqualsIgnoreCase( attribute ) THEN
            ParseText( Request, attributes.CurrentData^, OUT odd );
            CONTINUE;
         END;
      END; // WHILE
      
      // get list or map
      IF source.Empty THEN
         RETURN FALSE;
      ELSIF Request^.ModelContainer^.GetListOA( OA( source.Length-1, source.rawData ), OUT list ) THEN
         haveList := TRUE;
      ELSIF Request^.ModelContainer^.GetMapOA( OA( source.Length-1, source.rawData ), OUT map ) THEN
         haveList := FALSE;
      ELSE
         RETURN FALSE;
      END;

      // second buffer "for" content
      LOOP
         IF MoveNext( OUT nodeType, OUT nodePrefix, OUT nodeName, OUT isEmpty, OUT nodeValue, OUT lattributes ) <> xmlreader.xmle_S_OK THEN
            RETURN FALSE;
         END;
         nl.Add( nodeType, nodePrefix, nodeName, isEmpty, nodeValue, REF lattributes );
         IF nodeType = xmlreader.xntElementBegin THEN
            INC( depth );
         ELSIF nodeType = xmlreader.xntElementEnd THEN // other ends are consumed inside Parse
            IF depth = 1 THEN
               EXIT;
            END;
            DEC( depth );
         END;
      END; // WHILE
      
      // third switch sources and do "for"
      Sources.Push( ADR( nl ));
      i := 1;
      IF haveList THEN
         list^.Reset();
         WHILE list^.MoveNext() DO
            IF NOT item.Empty THEN
               SetModelValue( Request, item, list^.Current^ );
            END;
            IF NOT odd.Empty THEN
               SetModelBoolean( Request, odd, i AND 1 = 1 );
            END;
            IF NOT index.Empty THEN
               value.FromCARD32( i, 10 );
               SetModelValue( Request, index, value );
               INC( i );
            END;
            nl.Reset(); // prepare parsing
            Parse( Request, TRUE );
         END; // WHILE
      ELSE
         map^.Reset();
         WHILE map^.MoveNext() DO
            IF NOT item.Empty THEN
               SetModelValue( Request, item, map^.Current^ );
            END;
            IF NOT odd.Empty THEN
               SetModelBoolean( Request, odd, i AND 1 = 1 );
            END;
            IF NOT index.Empty THEN
               value.FromCARD32( i, 10 );
               SetModelValue( Request, index, value );
               INC( i );
            END;
            nl.Reset(); // prepare parsing
            Parse( Request, TRUE );
         END; // WHILE
      END;
      Sources.Pop();
      
      RETURN TRUE;
   END ParseForeach;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ParseForm( CONST Request : MVC.TPHttpRequest; CONST attributes : lists.CStringStringList ) : BOOLEAN;
   VAR
      attribute : StringsO.CString;
      formModel : StringsO.CString;
      lattributes : lists.CStringStringList;
      isEmpty : BOOLEAN;
      model : StringsO.CString;
      nodeName : StringsO.CString;
      nodePrefix : StringsO.CString;
      nodeType : xmlreader.TNodeType;
      nodeValue : StringsO.CString;
      pname : StringsO.TPString;
   BEGIN
      attribute := Prefix; attribute.AppendOA( PT_MODEL );

      attributes.Reset();
      WHILE attributes.MoveNext() DO
         pname := StringsO.TPString( attributes.Current );
         IF pname^.EqualsIgnoreCaseOA( PT_MODEL ) OR pname^.EqualsIgnoreCase( attribute ) THEN
            ParseText( Request, attributes.CurrentData^, OUT formModel );
         END;
      END; // WHILE
      IF formModel.Empty THEN
         RETURN FALSE;
      END;

      LOOP
         CASE MoveNext( OUT nodeType, OUT nodePrefix, OUT nodeName, OUT isEmpty, OUT nodeValue, OUT lattributes ) OF
         | xmlreader.xmle_S_OK :
            // continue
         | xmlreader.xmle_S_FALSE :
            RETURN TRUE;
         ELSE
            RETURN FALSE;
         END;

         IF nodeType = xmlreader.xntElementBegin THEN
            // ok, follow to processing
         ELSIF nodeType = xmlreader.xntElementEnd THEN // other ends are consumed inside
            RETURN TRUE;
         ELSE
            RETURN FALSE; // nothing other we do not expect
         END;
         
         IF nodeType = xmlreader.xntElementBegin THEN
            IF NOT nodePrefix.EqualsIgnoreCase( Prefix ) THEN
               RETURN FALSE;
            ELSE
               attributes.Reset();
               WHILE attributes.MoveNext() DO
                  pname := StringsO.TPString( attributes.Current );
                  IF pname^.EqualsIgnoreCaseOA( PT_MODEL ) OR pname^.EqualsIgnoreCase( attribute ) THEN
                     ParseText( Request, attributes.CurrentData^, OUT model );
                  END;
               END; // WHILE
               IF model.Empty THEN
                  RETURN FALSE;
               END;
            END;

            IF nodeName.EqualsIgnoreCaseOA( PT_FORM_INPUT ) THEN
            
            ELSIF nodeName.EqualsIgnoreCaseOA( PT_FORM_CHECKBOX ) THEN

            ELSIF nodeName.EqualsIgnoreCaseOA( PT_FORM_RADIOBUTTON ) THEN

            ELSIF nodeName.EqualsIgnoreCaseOA( PT_FORM_PASSWORD ) THEN

            ELSIF nodeName.EqualsIgnoreCaseOA( PT_FORM_SELECT ) THEN
               // ELSIF nodeName.EqualsIgnoreCaseOA( PT_FORM_OPTION ) THEN

            ELSIF nodeName.EqualsIgnoreCaseOA( PT_FORM_TEXTAREA ) THEN

            ELSIF nodeName.EqualsIgnoreCaseOA( PT_FORM_HIDDEN ) THEN

            ELSIF nodeName.EqualsIgnoreCaseOA( PT_FORM_ERRORS ) THEN

            ELSIF NOT Parse( Request, TRUE ) THEN // form can contain arbitrary elements
               RETURN FALSE;
            END;
         END;
         
      END; // WHILE
   END ParseForm;

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

   PRIVATE PROCEDURE MoveNext( OUT nodeType : xmlreader.TNodeType; OUT nodePrefix : StringsO.IString; OUT nodeName : StringsO.IString; OUT empty : BOOLEAN; OUT nodeValue : StringsO.IString; OUT attributes : lists.CStringStringList ) : xmlreader.TXMLError;
   VAR
      nl : NodeList.TPNodeList;
      nli : NodeList.TPNodeItem;
      xmle : xmlreader.TXMLError;
   BEGIN
      IF Sources.Empty THEN
         LOOP
            xmle := Reader.MoveNext();
            IF xmle <> xmlreader.xmle_S_OK THEN
               RETURN xmle;
            END;

            nodeType := Reader.CurrentType;
            CASE nodeType OF
            | xmlreader.xntText :
               nodeValue.Assign( Reader.CurrentValue );
               RETURN xmlreader.xmle_S_OK;

            | xmlreader.xntElementBegin :
               nodePrefix.Assign( Reader.CurrentPrefix );
               nodeName.Assign( Reader.CurrentName );
               empty := Reader.CurrentEmpty;

               // get attributes
               attributes.Dispose();
               IF Reader.MoveToFirstAttribute() = xmlreader.xmle_S_OK THEN
                  REPEAT
                     IF Reader.CurrentType <> xmlreader.xntAttribute THEN
                        ASSERT( FALSE ); // should not occur here
                        CONTINUE;
                     END;
                     attributes.Add( Reader.CurrentQualifiedName, Reader.CurrentValue );
                  UNTIL Reader.MoveToNextAttribute() <> xmlreader.xmle_S_OK;
               END;
               RETURN xmlreader.xmle_S_OK;

            | xmlreader.xntElementEnd :
               nodePrefix.Assign( Reader.CurrentPrefix );
               nodeName.Assign( Reader.CurrentName );
               RETURN xmlreader.xmle_S_OK;

            END; // CASE
         END; // LOOP

      ELSE
         nl := NodeList.TPNodeList( Sources.Peek());
         IF NOT nl^.MoveNext() THEN
            ASSERT( FALSE );
            RETURN xmlreader.xmle_S_FALSE; // should not occur
         END;
         
         nli := nl^.Current;
         nodeType := nli^.Type;
         nodePrefix.Assign( nli^.Prefix^ );
         nodeName.Assign( nli^.Name^ );
         empty := nli^.Empty;
         nodeValue.Assign( nli^.Value^ );
         attributes.Dispose();
         
         RETURN xmlreader.xmle_S_OK;
      END;
   END MoveNext;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE GetModelValue( CONST Request : MVC.TPHttpRequest; CONST model : StringsO.CString; OUT value : StringsO.IString ) : BOOLEAN;
   LABEL
      Error;
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
         IF NOT Request^.ModelContainer^.GetMapOA( OA( i-1, model.rawData ), OUT map ) THEN
            GOTO Error;
         END;
         model.Substring( i+1, -1, OUT sindex1 );            
         ParseText( Request, sindex1, OUT sindex2 );
         IF NOT map^.GetOA( OA( sindex2.Length-1, sindex2.rawData ), OUT value ) THEN
            GOTO Error;
         END;
         RETURN TRUE;
      END;

      i := model.IndexOfOA( L"[", 0 );
      IF i > 0 THEN // ok, find in map or list
         index := -1;
         j := model.IndexOfOA( L"]", i+1 );
         IF j = -1 THEN
            GOTO Error;
         END;
         model.Substring( i+1, j-i-1, OUT sindex1 );
         ParseText( Request, sindex1, OUT sindex2 );
         sindex2.Trim();
         IF NOT Strings.ToINT32W( OA( sindex2.Length-1, sindex2.rawData ), 10, OUT index ) THEN
            GOTO Error;
         ELSIF Request^.ModelContainer^.GetMapOA( OA( i-1, model.rawData ), OUT map ) THEN
            ps := map^[index];
            IF ps = NIL THEN
               GOTO Error;
            END;
            value.Assign( ps^ );
            RETURN TRUE;
         ELSIF Request^.ModelContainer^.GetListOA( OA( i-1, model.rawData ), OUT list ) THEN
            ps := list^[index];
            IF ps = NIL THEN
               GOTO Error;
            END;
            value.Assign( ps^ );
            RETURN TRUE;
         ELSE
            GOTO Error;
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
   Error:
      value.FromOA( L'##unknown model: ' );
      value.Append( model );
      value.AppendOA( L"" );
      RETURN FALSE;
   END GetModelValue;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE SetModelValue( CONST Request : MVC.TPHttpRequest; CONST model : StringsO.CString; CONST value : StringsO.IString ) : BOOLEAN;
   LABEL
      Error;
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
         IF NOT Request^.ModelContainer^.GetMapOA( OA( i-1, model.rawData ), OUT map ) THEN
            GOTO Error;
         END;
         model.Substring( i+1, -1, OUT sindex1 );            
         ParseText( Request, sindex1, OUT sindex2 );
         map^.RemoveOA( OA( sindex2.Length-1, sindex2.rawData ));
         map^.AddOA( OA( sindex2.Length-1, sindex2.rawData ), value );
         RETURN TRUE;
      END;

      i := model.IndexOfOA( L"[", 0 );
      IF i > 0 THEN // ok, find in map or list
         index := -1;
         j := model.IndexOfOA( L"]", i+1 );
         IF j = -1 THEN
            GOTO Error;
         END;
         model.Substring( i+1, j-i-1, OUT sindex1 );
         ParseText( Request, sindex1, OUT sindex2 );
         sindex2.Trim();
         IF NOT Strings.ToINT32W( OA( sindex2.Length-1, sindex2.rawData ), 10, OUT index ) THEN
            GOTO Error;
         ELSIF Request^.ModelContainer^.GetMapOA( OA( i-1, model.rawData ), OUT map ) THEN
            ps := map^[index];
            IF ps = NIL THEN
               GOTO Error;
            END;
            ps^.Assign( value );
            RETURN TRUE;
         ELSIF Request^.ModelContainer^.GetListOA( OA( i-1, model.rawData ), OUT list ) THEN
            ps := list^[index];
            IF ps = NIL THEN
               GOTO Error;
            END;
            ps^.Assign( value );
            RETURN TRUE;
         END;
      END;
      
      // string
      Request^.ModelContainer^.AddStringOA( OA( model.Length-1, model.rawData ), value );

      RETURN TRUE;

      // emit error      
   Error:
      value.FromOA( L'##unknown model: ' );
      value.Append( model );
      value.AppendOA( L"" );
      RETURN FALSE;
   END SetModelValue;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE SetModelBoolean( CONST Request : MVC.TPHttpRequest; CONST model : StringsO.CString; value : BOOLEAN );
   BEGIN
      Request^.ModelContainer^.AddBooleanOA( OA( model.Length-1, model.rawData ), value );
   END SetModelBoolean;

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