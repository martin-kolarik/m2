IMPLEMENTATION MODULE XMLSerializer;

FROM Storage IMPORT
	DEALLOCATE;

(*===========================================================================*)

CLASS IMPLEMENTATION AXMLSerializable;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE GetProperty( CONST Name : ARRAY OF WCHAR; OUT Value : StringsO.CString ) : BOOLEAN;
	BEGIN
		RETURN FALSE;
	END GetProperty;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE SetChild( CONST Name : StringsO.CString; Child : TPXMLSerializable ) : BOOLEAN;
	BEGIN
		RETURN FALSE;
	END SetChild;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE GetChild( CONST Name : ARRAY OF WCHAR; OUT Child : TPXMLSerializable ) : BOOLEAN;
	BEGIN
		RETURN FALSE;
	END GetChild;

(*---------------------------------------------------------------------------*)

END AXMLSerializable;

(*===========================================================================*)

CLASS IMPLEMENTATION AClassFactory;
END AClassFactory;

(*===========================================================================*)

PROCEDURE DoDeserializeNode( CONST Owner : TPXMLSerializable; CONST Node : DOM.TPXMLNode; CONST NodeName : StringsO.CString; CONST Factory : AClassFactory; OUT Self : TPXMLSerializable ) : BOOLEAN;
VAR
	i : CARDINAL;
	LocalName : StringsO.CString;
	LocalNode : DOM.TPXMLNode;
	NodeList : DOM.TPXMLNodeList;
	Object : TPXMLSerializable;
BEGIN
	IF NOT Factory.CreateInstance( Owner, NodeName, OUT Self ) THEN
		RETURN FALSE;
	END;
	NodeList := Node^.ChildNodes;
	FOR i := 0 TO NodeList^.Count-1 DO
		LocalNode := NodeList^[i];
		IF LocalNode = NIL THEN
			CONTINUE;
		ELSIF LocalNode^.NodeType = DOM.Element THEN
			LocalName := DOM.TPXMLElement( LocalNode )^.LocalName;
			IF DoDeserializeNode( Self, LocalNode, LocalName, Factory, OUT Object ) THEN
				Self^.SetChild( LocalName, Object );
			ELSE
				Self^.SetProperty( LocalName, LocalNode^.InnerText );
			END;
		END;
		DISPOSE( LocalNode );
	END; // FOR
	DISPOSE( NodeList );
	RETURN TRUE;
END DoDeserializeNode;

(*---------------------------------------------------------------------------*)

PROCEDURE DeserializeNodeList( NodeList : DOM.TPXMLNodeList; CONST Factory : AClassFactory; OUT Objects : ARRAY OF TPXMLSerializable; OUT Filled : CARDINAL );
VAR
	i, filled : INTEGER;
	Node : DOM.TPXMLNode;
BEGIN
	filled := 0;
	FOR i := 0 TO NodeList^.Count-1 DO
		IF filled > HIGH( Objects ) THEN
			EXIT;
		END;
		Node := NodeList^[i];
		IF Node = NIL THEN
			CONTINUE;
		ELSIF Node^.NodeType = DOM.Element THEN // others are skipped
			IF DoDeserializeNode( NIL, Node, DOM.TPXMLElement( Node )^.LocalName, Factory, OUT Objects[filled] ) THEN
				INC( filled );
			END;
		END;
		DISPOSE( Node );
	END; // FOR
	Filled := filled;
END DeserializeNodeList;

(*---------------------------------------------------------------------------*)

PROCEDURE DeserializeElement( Node : DOM.TPXMLElement; CONST Factory : AClassFactory; OUT Object : TPXMLSerializable ) : BOOLEAN;
BEGIN
	RETURN DoDeserializeNode( NIL, Node, Node^.LocalName, Factory, OUT Object );
END DeserializeElement;

(*---------------------------------------------------------------------------*)

PROCEDURE Serialize( CONST Writer : XMLWriter.CXMLWriter; CONST Objects : ARRAY OF TPXMLSerializable );
VAR
	i : CARDINAL;
BEGIN
	FOR i := 0 TO HIGH( Objects ) DO
		TPXMLSerializable( Objects[i] )^.Serialize( Writer, TRUE );
	END;
END Serialize;

(*===========================================================================*)

END XMLSerializer.