IMPLEMENTATION MODULE DOM;

FROM Storage IMPORT
	ALLOCATE, DEALLOCATE;

IMPORT
	com,
	windows;

(*===========================================================================*)

PROCEDURE CastToDOM( REF xn : xmlDOM.TPIXMLDOMNode ) : TPXMLNode; FORWARD;

(*--------------------------------------------------------------------------------*)

CLASS iCXMLNode( CXMLNode ); END iCXMLNode;
CLASS IMPLEMENTATION iCXMLNode; END iCXMLNode;

CLASS iCXMLNodeList( CXMLNodeList ); END iCXMLNodeList;
CLASS IMPLEMENTATION iCXMLNodeList; END iCXMLNodeList;

(*===========================================================================*)

CLASS IMPLEMENTATION CXMLNode;

(*--------------------------------------------------------------------------------*)

	LOCAL PROPERTY of GET : xmlDOM.TPIXMLDOMNode;
	BEGIN
		RETURN _of;
	END of;
	
(*--------------------------------------------------------------------------------*)

	LOCAL PROPERTY of SET( Value : xmlDOM.TPIXMLDOMNode );
	BEGIN
		_of := Value;
	END of;
	
(*--------------------------------------------------------------------------------*)

	VIRTUAL FINALLY CXMLNode(); // allows IS usage
	BEGIN
		IF _of <> NIL THEN
			_of^.Release();
			_of := NIL;
		END;
	END CXMLNode;

(*--------------------------------------------------------------------------------*)

	PUBLIC PROPERTY InnerText GET : StringsO.CString;
	VAR
		BS : com.BSTR;
		S : StringsO.CString;
	BEGIN
		BS := of^.text;
		S.FromOA( OAsz( BS ));
		com.DisposeBS( REF BS );
		RETURN S;
	END InnerText;

(*--------------------------------------------------------------------------------*)

	PUBLIC PROPERTY InnerText SET( CONST Value : StringsO.CString );
	BEGIN
		of^.text := com.BSTR( Value.szData );
	END InnerText;

(*--------------------------------------------------------------------------------*)

	PUBLIC PROPERTY NodeType GET : XMLNodeType;
	VAR
		nt : xmlDOM.DOMNodeType;
	BEGIN
		nt := of^.nodeType;
		CASE nt OF
		| xmlDOM.NODE_ELEMENT : RETURN Element;
		| xmlDOM.NODE_ATTRIBUTE : RETURN Attribute;
		| xmlDOM.NODE_TEXT : RETURN Text;
		| xmlDOM.NODE_CDATA_SECTION : RETURN CDATA;
		| xmlDOM.NODE_ENTITY_REFERENCE : RETURN EntityReference;
		| xmlDOM.NODE_ENTITY : RETURN Entity;
		| xmlDOM.NODE_PROCESSING_INSTRUCTION : RETURN ProcessingInstruction;
		| xmlDOM.NODE_COMMENT : RETURN Comment;
		| xmlDOM.NODE_DOCUMENT : RETURN Document;
		| xmlDOM.NODE_DOCUMENT_TYPE : RETURN DocumentType;
		| xmlDOM.NODE_DOCUMENT_FRAGMENT : RETURN DocumentFragment;
		| xmlDOM.NODE_NOTATION : RETURN Notation;
		ELSE
			RETURN Text;
		END; // CASE
	END NodeType;

(*--------------------------------------------------------------------------------*)

	PUBLIC PROPERTY ChildNodes GET : TPXMLNodeList;
	VAR
		dnl : TPXMLNodeList;
	BEGIN
		dnl := NEW( iCXMLNodeList );
		dnl^.of := of^.childNodes;
		RETURN dnl;
	END ChildNodes;

(*--------------------------------------------------------------------------------*)

BEGIN
	_of := NIL;
END CXMLNode;

(*===========================================================================*)

CLASS IMPLEMENTATION CXMLNodeList;

(*--------------------------------------------------------------------------------*)

	VIRTUAL FINALLY CXMLNodeList();
	BEGIN
		IF of <> NIL THEN
			of^.Release();
			of := NIL;
		END;
	END CXMLNodeList;

(*--------------------------------------------------------------------------------*)

	PUBLIC INDEX CXMLNodeList GET( Index : INTEGER ) : TPXMLNode;
	VAR
		xn : xmlDOM.TPIXMLDOMNode;
	BEGIN
		xn := of^[ Index ];
		RETURN CastToDOM( REF xn );
	END CXMLNodeList;

(*--------------------------------------------------------------------------------*)

	PUBLIC PROPERTY Count GET : CARDINAL;
	BEGIN
		RETURN of^.length;
	END Count;

(*--------------------------------------------------------------------------------*)

	PUBLIC PROCEDURE Reset();
	BEGIN
		of^.reset();
	END Reset;

(*--------------------------------------------------------------------------------*)

	PUBLIC PROCEDURE MoveNext() : TPXMLNode;
	VAR
		xn : xmlDOM.TPIXMLDOMNode;
	BEGIN
		xn := of^.nextNode();
		RETURN CastToDOM( REF xn );
	END MoveNext;

(*--------------------------------------------------------------------------------*)

BEGIN
	of := NIL;
END CXMLNodeList;

(*===========================================================================*)

CLASS IMPLEMENTATION CXMLElement;

(*--------------------------------------------------------------------------------*)

	LOCAL PROPERTY of GET : xmlDOM.TPIXMLDOMElement;
	VAR
		a : ADDRESS := _of;
	BEGIN
		RETURN xmlDOM.TPIXMLDOMElement( a );
	END of;
	
(*--------------------------------------------------------------------------------*)

	LOCAL PROPERTY of SET( Value : xmlDOM.TPIXMLDOMElement );
	BEGIN
		_of := Value;
	END of;
	
(*--------------------------------------------------------------------------------*)

	PUBLIC PROPERTY LocalName GET : StringsO.CString;
	VAR
		BS : com.BSTR;
		S : StringsO.CString;
	BEGIN
		BS := of^.tagName;
		S.FromOA( OAsz( BS ));
		com.DisposeBS( REF BS );
		RETURN S;
	END LocalName;

(*--------------------------------------------------------------------------------*)

	PUBLIC PROPERTY Name GET : StringsO.CString;
	VAR
		BS : com.BSTR;
		S : StringsO.CString;
	BEGIN
		BS := of^.baseName;
		S.FromOA( OAsz( BS ));
		com.DisposeBS( REF BS );
		RETURN S;
	END Name;

(*--------------------------------------------------------------------------------*)

	PUBLIC PROCEDURE GetAttribute( AttributeName : ARRAY OF WCHAR; OUT AttributeValue : StringsO.CString ) : BOOLEAN; // returns if the attribute is not present
	VAR
		BS : com.BSTR := NIL;
	BEGIN
		com.VariantToBSRef( of^.getAttribute( com.ToBSRef( AttributeName, REF BS )), TRUE, REF BS );
		IF BS = NIL THEN
			RETURN FALSE;
		END;
		AttributeValue.FromOA( OAsz( BS ));
		com.DisposeBS( REF BS );
		RETURN TRUE;
	END GetAttribute;

(*--------------------------------------------------------------------------------*)

	PUBLIC PROCEDURE GetElementsByTagName( TagName : ARRAY OF WCHAR ) : TPXMLNodeList;
	VAR
		BS : com.BSTR := NIL;
		dnl : TPXMLNodeList;
	BEGIN
		dnl := NEW( iCXMLNodeList );
		dnl^.of := of^.getElementsByTagName( com.ToBSRef( TagName, REF BS ));
		com.DisposeBS( REF BS );
		RETURN dnl;
	END GetElementsByTagName;

(*--------------------------------------------------------------------------------*)

END CXMLElement;

(*--------------------------------------------------------------------------------*)

CLASS iCXMLElement( CXMLElement ); END iCXMLElement;
CLASS IMPLEMENTATION iCXMLElement; END iCXMLElement;

(*===========================================================================*)

CLASS IMPLEMENTATION CXMLDocument;

(*--------------------------------------------------------------------------------*)

	LOCAL PROPERTY of GET : xmlDOM.TPIXMLDOMDocument;
	VAR
		a : ADDRESS := _of;
	BEGIN
		RETURN xmlDOM.TPIXMLDOMDocument( a );
	END of;
	
(*--------------------------------------------------------------------------------*)

	LOCAL PROPERTY of SET( Value : xmlDOM.TPIXMLDOMDocument );
	BEGIN
		_of := Value;
	END of;
	
(*--------------------------------------------------------------------------------*)

	PUBLIC PROCEDURE Load( CONST Path : ARRAY OF WCHAR ) : BOOLEAN;
	VAR
		V : com.VARIANTARG;
		VB : com.VARIANT_BOOL;
	BEGIN
		com.VariantInitString( OUT V, Path );
   	VB := of^.load( V );
		com.VariantClear( REF V );
		RETURN VB <> windows.False;
	END Load;

(*--------------------------------------------------------------------------------*)

	// PUBLIC PROCEDURE LoadXML( CONST XML : ARRAY OF WCHAR );
	// BEGIN
	// END LoadXML;
	
(*--------------------------------------------------------------------------------*)

	PUBLIC PROCEDURE SelectNodes( XPath : ARRAY OF WCHAR ) : TPXMLNodeList;
	VAR
		BS : com.BSTR := NIL;
		dnl : TPXMLNodeList;
	BEGIN
		dnl := NEW( iCXMLNodeList );
		dnl^.of := of^.selectNodes( com.ToBSRef( XPath, REF BS ));
		com.DisposeBS( REF BS );
		RETURN dnl;
	END SelectNodes;

(*--------------------------------------------------------------------------------*)

	PUBLIC PROCEDURE SelectSingleNode( XPath : ARRAY OF WCHAR ) : TPXMLNode;
	VAR
		BS : com.BSTR := NIL;
		xn : xmlDOM.TPIXMLDOMNode;
	BEGIN
		xn := of^.selectSingleNode( com.ToBSRef( XPath, REF BS ));
		com.DisposeBS( REF BS );
		RETURN CastToDOM( REF xn );
	END SelectSingleNode;
	
(*--------------------------------------------------------------------------------*)

	PUBLIC PROCEDURE GetElementsByTagName( TagName : ARRAY OF WCHAR ) : TPXMLNodeList;
	VAR
		BS : com.BSTR := NIL;
		dnl : TPXMLNodeList;
	BEGIN
		dnl := NEW( iCXMLNodeList );
		dnl^.of := of^.getElementsByTagName( com.ToBSRef( TagName, REF BS ));
		com.DisposeBS( REF BS );
		RETURN dnl;
	END GetElementsByTagName;

(*--------------------------------------------------------------------------------*)

END CXMLDocument;

(*--------------------------------------------------------------------------------*)

CLASS iCXMLDocument( CXMLDocument ); END iCXMLDocument;
CLASS IMPLEMENTATION iCXMLDocument; END iCXMLDocument;

(*===========================================================================*)

PROCEDURE CastToDOM( REF xn : xmlDOM.TPIXMLDOMNode ) : TPXMLNode;
VAR
	dn : TPXMLNode;
	nodeType : xmlDOM.DOMNodeType;
BEGIN
	nodeType := xn^.nodeType;
	CASE nodeType OF
	| xmlDOM.NODE_DOCUMENT :
		com.Cast( REF xn, xmlDOM.IID_IXMLDOMDocument, TRUE, OUT xn );
		dn := NEW( iCXMLDocument );
		dn^.of := xn;
	| xmlDOM.NODE_ELEMENT :
		com.Cast( REF xn, xmlDOM.IID_IXMLDOMElement, TRUE, OUT xn );
		dn := NEW( iCXMLElement );
		dn^.of := xn;
	ELSE
	  xn^.Release();
	  dn := NIL;
	END;
	RETURN dn;
END CastToDOM;

(*===========================================================================*)

PROCEDURE newXMLDocument() : TPXMLDocument;
VAR
	dd : POINTER TO iCXMLDocument;
	xd : xmlDOM.TPIXMLDOMDocument;
BEGIN
	IF com.New2( "MSXML2.DOMDocument.3.0", OUT xd ) <> 0 THEN
		RETURN NIL;
	END;
	NEW( dd );
	dd^.of := xd;
	RETURN dd;
END newXMLDocument;

(*===========================================================================*)

END DOM.