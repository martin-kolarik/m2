IMPLEMENTATION MODULE ns;

FROM Storage IMPORT
	ALLOCATE;
	
IMPORT
	Exceptions,
	Strings;

(*===========================================================================*)

CLASS IMPLEMENTATION AnsItem;
	
(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Empty GET : BOOLEAN;
   BEGIN
      RETURN Count = 0;
   END Empty;

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

	PUBLIC PROCEDURE Get( CONST SingleName : StringsO.IString; OUT Item : TPnsItem ) : BOOLEAN;
	BEGIN
		IF SingleName.Empty THEN
			RETURN FALSE;
		ELSE
			RETURN GetOA( OA( SingleName.Length-1, SingleName.rawData ), OUT Item );
		END;
	END Get;

(*---------------------------------------------------------------------------*)

	PUBLIC PROCEDURE GetNewIterator() : TPnsIterator;
	VAR
	  PI : TPnsIterator;
	BEGIN
		NEW( PI );
		PI^.Init( ADR( SELF ));
		RETURN PI;
	END GetNewIterator;
	
(*---------------------------------------------------------------------------*)

END AnsItem;

(*===========================================================================*)

CLASS IMPLEMENTATION CnsIterator;

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

	PUBLIC PROPERTY Current GET : TPnsItem;
	BEGIN
		IF Owner = NIL THEN
			RETURN NIL;
		ELSE
			RETURN Owner^[Index];
		END;
	END Current;

(*---------------------------------------------------------------------------*)

	PUBLIC INDEX CnsIterator GET( Index : CARDINAL ) : TPnsItem;
	BEGIN
		IF Owner = NIL THEN
			RETURN NIL;
		ELSE
			RETURN Owner^[Index];
		END;
	END CnsIterator;
	
(*---------------------------------------------------------------------------*)

	LOCAL PROCEDURE Init( Item : TPnsItem );
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
END CnsIterator;

(*===========================================================================*)

CLASS IMPLEMENTATION Ans;

(*---------------------------------------------------------------------------*)

	PUBLIC PROPERTY Namespace GET : StringsO.TPString;
	BEGIN
		RETURN Root^.Name;
	END Namespace;

(*---------------------------------------------------------------------------*)

	PUBLIC PROCEDURE Contains( CONST Name : StringsO.IString ) : BOOLEAN;
	VAR
		Item : TPnsItem;
	BEGIN
		RETURN Get( Name, OUT Item );
	END Contains;

(*---------------------------------------------------------------------------*)

	PUBLIC PROCEDURE Get( CONST Name : StringsO.IString; OUT Item : TPnsItem ) : BOOLEAN;
	BEGIN
		IF Name.Empty THEN
			RETURN FALSE;
		ELSE
			RETURN GetOA( OA( Name.Length-1, Name.rawData ), OUT Item );
		END;
	END Get;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE GetOA( CONST Name : ARRAY OF WCHAR; OUT Item : TPnsItem ) : BOOLEAN;
	VAR
		i : CARDINAL;
		item : TPnsItem;
		s : ARRAY [0..511] OF WCHAR;
	BEGIN
		IF Name[0] = 0W THEN
			RETURN FALSE;
		END;

		// Root, the first item must be handled separatelly
		item := Root;
		i := Strings.ItemSW( Name, Strings.WCHARS{L'.'}, 0, 0, TRUE, OUT s );
		IF s[0] = 0W THEN
			RETURN FALSE;
		ELSIF NOT item^.Name^.EqualsOA( s ) THEN
			RETURN FALSE;
		END;
		LOOP
			i := Strings.ItemSW( Name, Strings.WCHARS{L'.'}, i, 0, TRUE, OUT s );
			IF s[0] = 0W THEN
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
		Item : TPnsItem;
	BEGIN
		IF NOT GetOA( Name, OUT Item ) THEN
			Hash := 0;
			RETURN FALSE;
		ELSE
			Hash := ns.THash( Item );
			RETURN TRUE;
		END;
	END Map;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE GetHash( Hash : THash; OUT Item : TPnsItem ) : BOOLEAN;
	BEGIN
		IF Hash = 0 THEN
			RETURN FALSE;
		END;
		Item := TPnsItem( Hash );
		RETURN TRUE;
	END GetHash;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Dump( CONST Writer : TextWriter.TPTextWriter );
   VAR
      indent : INTEGER := 0;
      
   (*----------*)
   
      PROCEDURE Indent();
      VAR
         i : INTEGER;
      BEGIN
         FOR i := 0 TO indent-1 DO
            Writer^.WriteOA( L" ", FALSE );
         END; // FOR
      END Indent;
   
   (*----------*)
   
      PROCEDURE DumpItem( item : TPnsItem );
      VAR
         it : TPnsIterator;
      BEGIN
         it := item^.GetNewIterator();
         it^.Reset();
         WHILE it^.MoveNext() DO

            Indent(); Writer^.Write( it^.Current^.Name^, TRUE );

            IF NOT it^.Current^.Empty THEN
               INC( indent );
               DumpItem( it^.Current );
               DEC( indent );
            END;
         END; // WHILE
      END DumpItem;
   
   (*----------*)
   
   BEGIN
      Writer^.WriteOA( L"Dump of namespace: ", FALSE ); Writer^.Write( Namespace^, TRUE );
      DumpItem( Root );
   END Dump;

(*---------------------------------------------------------------------------*)

END Ans;

(*===========================================================================*)

END ns.