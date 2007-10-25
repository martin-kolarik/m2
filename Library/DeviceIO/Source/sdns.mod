IMPLEMENTATION MODULE sdns;

FROM Storage IMPORT
	ALLOCATE;
	
IMPORT
	Exceptions,
	Strings;

(*===========================================================================*)

CLASS IMPLEMENTATION ASDNSItem;
	
(*---------------------------------------------------------------------------*)

	PUBLIC PROCEDURE Contains( CONST SingleName : StringsO.IString ) : BOOLEAN;
	BEGIN
		IF SingleName.Empty THEN
			RETURN FALSE;
		ELSE
			RETURN ContainsOA( OA( SingleName.Length-1, SingleName.rawData ));
		END;
	END Contains;
	
(*---------------------------------------------------------------------------*)

	PUBLIC PROCEDURE Get( CONST SingleName : StringsO.IString; OUT Item : TPSDNSItem ) : BOOLEAN;
	BEGIN
		IF SingleName.Empty THEN
			RETURN FALSE;
		ELSE
			RETURN GetOA( OA( SingleName.Length-1, SingleName.rawData ), OUT Item );
		END;
	END Get;

(*---------------------------------------------------------------------------*)

	PUBLIC PROCEDURE GetNewIterator() : TPSDNSIterator;
	VAR
	  PI : TPSDNSIterator;
	BEGIN
		NEW( PI );
		PI^.Init( ADR( SELF ));
		RETURN PI;
	END GetNewIterator;
	
(*---------------------------------------------------------------------------*)

END ASDNSItem;

(*===========================================================================*)

CLASS IMPLEMENTATION CSDNSIterator;

(*---------------------------------------------------------------------------*)

	PUBLIC PROPERTY Count GET : CARDINAL;
	BEGIN
		IF Owner = NIL THEN
			RETURN 0;
		ELSE
			RETURN Owner^.Count;
		END;
	END Count;

(*---------------------------------------------------------------------------*)

	PUBLIC PROPERTY Current GET : TPSDNSItem;
	BEGIN
		IF Owner = NIL THEN
			RETURN NIL;
		ELSE
			RETURN Owner^[Index];
		END;
	END Current;

(*---------------------------------------------------------------------------*)

	PUBLIC INDEX CSDNSIterator GET( Index : CARDINAL ) : TPSDNSItem;
	BEGIN
		IF Owner = NIL THEN
			RETURN NIL;
		ELSE
			RETURN Owner^[Index];
		END;
	END CSDNSIterator;
	
(*---------------------------------------------------------------------------*)

	LOCAL PROCEDURE Init( Item : TPSDNSItem );
	BEGIN
		Owner := Item;
		Reset();
	END Init;

(*---------------------------------------------------------------------------*)

	PUBLIC PROCEDURE Reset();
	BEGIN
		Index := -1;
	END Reset;

(*---------------------------------------------------------------------------*)

	PUBLIC PROCEDURE MoveNext() : BOOLEAN;
	BEGIN
		IF Index = Count THEN // disallow incrementing Index
			RETURN FALSE;
		END;
		INC( Index );
		RETURN Index < Count;
	END MoveNext;

(*---------------------------------------------------------------------------*)

BEGIN
	Owner := NIL;
	Index := -1;
END CSDNSIterator;

(*===========================================================================*)

CLASS IMPLEMENTATION ASDNS;

(*---------------------------------------------------------------------------*)

	PUBLIC PROPERTY Namespace GET : StringsO.TPString;
	BEGIN
		RETURN Root^.Name;
	END Namespace;

(*---------------------------------------------------------------------------*)

	PUBLIC PROCEDURE Contains( CONST Name : StringsO.IString ) : BOOLEAN;
	VAR
		Item : TPSDNSItem;
	BEGIN
		RETURN Get( Name, OUT Item );
	END Contains;

(*---------------------------------------------------------------------------*)

	PUBLIC PROCEDURE Get( CONST Name : StringsO.IString; OUT Item : TPSDNSItem ) : BOOLEAN;
	BEGIN
		IF Name.Empty THEN
			RETURN FALSE;
		ELSE
			RETURN GetOA( OA( Name.Length-1, Name.rawData ), OUT Item );
		END;
	END Get;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE GetOA( CONST Name : ARRAY OF WCHAR; OUT Item : TPSDNSItem ) : BOOLEAN;
	VAR
		i : CARDINAL;
		item : TPSDNSItem;
		s : ARRAY [0..511] OF WCHAR;
	BEGIN
		IF Name[0] = 0W THEN
			RETURN FALSE;
		END;

		// Root, the first item must be handled separatelly
		item := Root;
		i := Strings.ItemSW( Name, Strings.WCHARS{L'.'}, 0, 0, TRUE, OUT s );
		IF i = -1 THEN
			RETURN FALSE;
		ELSIF NOT item^.Name^.EqualsOA( s ) THEN
			RETURN FALSE;
		END;
		LOOP
			i := Strings.ItemSW( Name, Strings.WCHARS{L'.'}, i, 0, TRUE, OUT s );
			IF i = -1 THEN
				EXIT;
			ELSIF NOT item^.GetOA( s, OUT item ) THEN
				RETURN FALSE;
			END;
		END; // LOOP

		Item := item;
		RETURN TRUE;
	END GetOA;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE Map( CONST Name : ARRAY OF WCHAR; OUT Hash : THash ) : BOOLEAN;
	VAR
		Item : TPSDNSItem;
	BEGIN
		IF NOT GetOA( Name, OUT Item ) THEN
			Hash := 0;
			RETURN FALSE;
		ELSE
			Hash := sdns.THash( Item );
			RETURN TRUE;
		END;
	END Map;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE GetHash( Hash : THash; OUT Item : TPSDNSItem ) : BOOLEAN;
	BEGIN
		IF Hash = 0 THEN
			RETURN FALSE;
		END;
		Item := TPSDNSItem( Hash );
		RETURN TRUE;
	END GetHash;

(*---------------------------------------------------------------------------*)

END ASDNS;

(*===========================================================================*)

END sdns.