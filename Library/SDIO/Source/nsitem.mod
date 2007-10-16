IMPLEMENTATION MODULE nsitem;

FROM Storage IMPORT
	ALLOCATE;

IMPORT
	Exceptions,
	StringsO;

(*===========================================================================*)

CLASS IMPLEMENTATION CnsWrapper;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROPERTY Name GET : StringsO.TPString;
	BEGIN
		RETURN _NS^.Root^.Name;
	END Name;
	
(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROPERTY NameType GET : sdns.TSDNameType;
	BEGIN
		RETURN _NS^.Root^.NameType;
	END NameType;
	
(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROPERTY ValueType GET : sdvalue.TSDValueType;
	BEGIN
		RETURN _NS^.Root^.ValueType;
	END ValueType;
	
(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROPERTY Data GET : PTR;
	BEGIN
		RETURN _NS^.Root^.Data;
	END Data;
	
(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROPERTY Count GET : CARDINAL;
	BEGIN
		RETURN _NS^.Root^.Count;
	END Count;

(*---------------------------------------------------------------------------*)

	PUBLIC PROPERTY Namespace GET : sdns.TPSDNS;
	BEGIN
		RETURN _NS;
	END Namespace;

(*---------------------------------------------------------------------------*)

	PUBLIC PROPERTY Namespace SET( NS : sdns.TPSDNS );
	BEGIN
		_NS := NS;
	END Namespace;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL INDEX CnsWrapper GET( Index : CARDINAL ) : sdns.TPSDNSItem;
	BEGIN
		RETURN _NS^.Root^[Index];
	END CnsWrapper;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE ContainsOA( CONST SingleName : ARRAY OF WCHAR ) : BOOLEAN;
	BEGIN
		RETURN _NS^.Root^.ContainsOA( SingleName );
	END ContainsOA;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE GetOA( CONST SingleName : ARRAY OF WCHAR; OUT Item : sdns.TPSDNSItem ) : BOOLEAN;
	BEGIN
		RETURN _NS^.Root^.GetOA( SingleName, OUT Item );
	END GetOA;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE AddChild( Child : sdns.TPSDNSItem );
	BEGIN
		Exceptions.Modula2Exception( NIL, L"SDNamespace Wrapper", L"", Exceptions.mexNotSupported );
	END AddChild;

(*---------------------------------------------------------------------------*)

BEGIN
	_NS := NIL;
END CnsWrapper;

(*===========================================================================*)

TYPE
  TPnsItem = POINTER TO CnsItem;

CLASS IMPLEMENTATION CnsItem;

	VIRTUAL PROPERTY Name GET : StringsO.TPString;
	BEGIN
		RETURN ADR( _Name );
	END Name;

	VIRTUAL PROPERTY NameType GET : sdns.TSDNameType;
	BEGIN
		RETURN _NameType;
	END NameType;

	VIRTUAL PROPERTY ValueType GET : sdvalue.TSDValueType;
	BEGIN
		RETURN _ValueType;
	END ValueType;

	VIRTUAL PROPERTY Data GET : PTR;
	BEGIN
		RETURN _Data;
	END Data;

	PUBLIC PROCEDURE Init( CONST SingleChildName : ARRAY OF WCHAR; ConstName : BOOLEAN; NameType : sdns.TSDNameType; ValueType : sdvalue.TSDValueType; Data : PTR );
	BEGIN
		_Name.FromOA( SingleChildName );
		_NameType := NameType;
		_ValueType := ValueType;
		_Data := Data;
	END Init;

BEGIN
   _NameType := sdns.sdnName;
	_ValueType := sdvalue.sdtVoid;
	_Data := 0;
END CnsItem;

(*===========================================================================*)

CLASS IMPLEMENTATION ANS;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROPERTY Root GET : sdns.TPSDNSItem;
	BEGIN
		RETURN _Root;
	END Root;

(*---------------------------------------------------------------------------*)

	PUBLIC PROCEDURE Initialize();
	BEGIN
		_Root := CreateRoot();
		CreateStructure();
	END Initialize;

(*---------------------------------------------------------------------------*)

	INTERNAL VIRTUAL PROCEDURE CreateStructure(); // excluding root, need not to be overriden
	BEGIN
	END CreateStructure;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE CreateNewItem( CONST Name : ARRAY OF WCHAR; ValueType : sdvalue.TSDValueType; Data : PTR ) : sdns.TPSDNSItem;
	BEGIN
		RETURN NIL;
	END CreateNewItem;

(*---------------------------------------------------------------------------*)

	PUBLIC PROCEDURE FromXML( Stream : IOO.TPStream );
	BEGIN
	END FromXML;

(*---------------------------------------------------------------------------*)

BEGIN
	_Root := NIL;
END ANS;

(*===========================================================================*)

END nsitem.