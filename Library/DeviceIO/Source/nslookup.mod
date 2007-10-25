IMPLEMENTATION MODULE nslookup;

FROM Storage IMPORT
	ALLOCATE;

IMPORT
	Strings;

(*===========================================================================*)

TYPE
  TPnsAVLTreeElem = POINTER TO CnsAVLTreeElem;

CLASS CnsAVLTreeElem( avltree.CAVLTreeElem );
	LOCAL VAR
		Item : sdns.TPSDNSItem;
	PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;
END CnsAVLTreeElem;

CLASS CSearchHelper( avltree.CAVLTreeElem );
	PRIVATE VAR
		String : PWCHAR;
		Length : CARDINAL;
	LOCAL PROCEDURE Init( CONST String : ARRAY OF WCHAR );
	PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;
END CSearchHelper;

(*===========================================================================*)

CLASS IMPLEMENTATION CnsAVLTreeElem;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;
	BEGIN
		RETURN Item^.Name^.Compare( TPnsAVLTreeElem( pelem )^.Item^.Name^ );
	END Compare;

(*---------------------------------------------------------------------------*)

BEGIN
	Item := NIL;
END CnsAVLTreeElem;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CSearchHelper;

(*---------------------------------------------------------------------------*)

	LOCAL PROCEDURE Init( CONST String : ARRAY OF WCHAR );
	BEGIN
		SELF.String := PWCHAR( ADR( String ));
		Length := HIGH( String ) + 1;
	END Init;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;
	VAR
		NameToCompare : StringsO.TPString;
	BEGIN
		NameToCompare := TPnsAVLTreeElem( pelem )^.Item^.Name;
		RETURN Strings.CompareW( OA( Length-1, String ), OA( NameToCompare^.Length-1, NameToCompare^.rawData ));
	END Compare;

(*---------------------------------------------------------------------------*)

BEGIN
	String := NIL;
	Length := 0;
END CSearchHelper;

(*===========================================================================*)

CLASS IMPLEMENTATION AnsAVLItem;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROPERTY Count GET : CARDINAL;
	BEGIN
		RETURN _Childs.Count;
	END Count;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL INDEX AnsAVLItem GET( Index : CARDINAL ) : sdns.TPSDNSItem;
	BEGIN
		RETURN TPnsAVLTreeElem( _Childs[Index] )^.Item;
	END AnsAVLItem;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE ContainsOA( CONST SingleName : ARRAY OF WCHAR ) : BOOLEAN;
	VAR
		SH : CSearchHelper;
	BEGIN
		SH.Init( SingleName );
		RETURN _Childs.Contains( ADR( SH ));
	END ContainsOA;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE GetOA( CONST SingleName : ARRAY OF WCHAR; OUT Item : sdns.TPSDNSItem ) : BOOLEAN;
	VAR
		PElem : TPnsAVLTreeElem;
		SH : CSearchHelper;
		b : BOOLEAN;
	BEGIN
		SH.Init( SingleName );
		b := _Childs.Search( ADR( SH ), OUT PElem );
		IF b THEN
			Item := PElem^.Item;
		END;
		RETURN b;
	END GetOA;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE AddChild( Child : sdns.TPSDNSItem );
	VAR
		PElem : TPnsAVLTreeElem;
	BEGIN
		NEW( PElem );
		PElem^.Item := Child;
		_Childs.Insert( PElem );
	END AddChild;

(*---------------------------------------------------------------------------*)

END AnsAVLItem;

(*===========================================================================*)

CLASS IMPLEMENTATION AnsArrayItem;

(*---------------------------------------------------------------------------*)

	VIRTUAL PROPERTY Items GET : CARDINAL;
	BEGIN
		RETURN _Childs.Count;
	END Items;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL INDEX AnsArrayItem GET( Index : CARDINAL ) : sdns.TPSDNSItem;
	BEGIN
		RETURN _Childs[Index];
	END AnsArrayItem;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE ContainsOA( CONST SingleName : ARRAY OF WCHAR ) : BOOLEAN;
	VAR
		i : CARDINAL;
	BEGIN
		IF _Childs.Empty THEN
			RETURN FALSE;
		END;
		FOR i := 0 TO _Childs.Count-1 DO
			IF sdns.TPSDNSItem( _Childs[i] )^.Name^.EqualsOA( SingleName ) THEN
				RETURN TRUE;
			END;
		END; // WHILE
		RETURN FALSE;
	END ContainsOA;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE GetOA( CONST SingleName : ARRAY OF WCHAR; OUT Item : sdns.TPSDNSItem ) : BOOLEAN;
	VAR
		i : CARDINAL;
	BEGIN
		IF _Childs.Empty THEN
			RETURN FALSE;
		END;
		FOR i := 0 TO _Childs.Count-1 DO
			IF sdns.TPSDNSItem( _Childs[i] )^.Name^.EqualsOA( SingleName ) THEN
				Item := sdns.TPSDNSItem( _Childs[i] );
				RETURN TRUE;
			END;
		END; // WHILE
		RETURN FALSE;
	END GetOA;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE AddChild( Child : sdns.TPSDNSItem );
	BEGIN
		_Childs.Add( Child );
	END AddChild;

(*---------------------------------------------------------------------------*)

END AnsArrayItem;

(*===========================================================================*)

END nslookup.