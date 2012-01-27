IMPLEMENTATION MODULE nsimpl;

(*===========================================================================*)

PROCEDURE HashToValue( CONST Hash : ns.THash; OUT Value : iovalue.TPValue ) : BOOLEAN;
BEGIN
   RETURN nsinternal.HashToValue( Hash, OUT Value );
END HashToValue;

(*===========================================================================*)

CLASS IMPLEMENTATION Namespace;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   BEGIN
      IF _Pairs <> NIL THEN
         _Pairs^.Dispose();
      END;
   END Dispose;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE NameToHash( CONST Name : StringsO.IString; OUT Hash : ns.THash ) : BOOLEAN;
   VAR
      i : CARDINAL := 0;
      pairs : ns.TPNameValuePairs := NIL;
      toTest : StringsO.CString;
   BEGIN
      IF Name.Empty THEN
         RETURN FALSE;
      END;

      pairs := _Pairs;
      LOOP
         i := Name.ItemS( StringsO.WCHARS{L'.'}, i, 0, TRUE, OUT toTest );
         IF i = -1 THEN
            EXIT;
         ELSIF toTest.Empty THEN // Empty string before Name end detected, likely ".." appeared in the Name. This is disallowed.
            RETURN FALSE;
         ELSIF NOT pairs^.Child( toTest, OUT pairs ) THEN
            RETURN FALSE;
         END;
      END; // LOOP

      IF pairs = NIL THEN
         RETURN FALSE;
      ELSE
         Hash := pairs;
         RETURN TRUE;
      END;
   END NameToHash;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE HashToName( CONST Hash : ns.THash; OUT Name : StringsO.IString ) : BOOLEAN;
   VAR
      dot : StringsO.CString;
      name : StringsO.CString;
      pairs : ns.TPNameValuePairs;
      singleName : StringsO.CString;
   BEGIN
      IF Hash = ns.hashINVALID THEN
         RETURN FALSE;
      END;

      dot := StringsO.FromOA( L"." );
      pairs := ns.TPNameValuePairs( Hash );

      REPEAT
         singleName.Assign( pairs^.Name^ );
         // construct
         IF name.Empty THEN
            name := singleName;
         ELSE
            name.Prepend( dot );
            name.Prepend( singleName );
         END;
         // move up
         pairs := pairs^.Parent;
      UNTIL pairs = ADR( _Pairs^.INameValuePairs ); // me as a Hash

      Name.Assign( name );
      RETURN TRUE;
   END HashToName;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Map( CONST Name : StringsO.IString; OUT Value : iovalue.TPValue ) : BOOLEAN; // looks for string, does not try to convert name to index
   VAR
      hash : ns.THash;
   BEGIN
      RETURN NameToHash( Name, OUT hash ) AND HashToValue( hash, OUT Value );
   END Map;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Name GET : POINTER TO CONST StringsO.IString;
   BEGIN
      RETURN _Pairs^.Name;
   END Name;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Parent GET : ns.TPNameValuePairs;
   BEGIN
      RETURN _Pairs^.Parent;
   END Parent;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Child( CONST Name : StringsO.IString; OUT child : ns.TPNameValuePairs ) : BOOLEAN;
   VAR
      hash : ns.THash;
   BEGIN
      IF NOT NameToHash( Name, OUT hash ) THEN
         RETURN FALSE;
      END;
      child := ns.TPNameValuePairs( hash );
      RETURN TRUE;
   END Child;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Contains( CONST Name : StringsO.IString ) : BOOLEAN;
   VAR
      hash : ns.TPHash;
   BEGIN
      RETURN NameToHash( Name, OUT hash );
   END Contains;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( CONST Name : StringsO.IString );
   BEGIN
      StringsO.TPString( _Pairs^.Name )^.Assign( Name );
   END Init;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE DefineValue( CONST Name : StringsO.IString; Type : iovalue.TType; Flags : iovalue.TFlags; Data : PTR; CONST InitialValue : iovalue.TPValue; OUT Children : ns.TPNameValuePairs ) : BOOLEAN;
   VAR
      leaf : StringsO.CString;
      pairs : ns.TPNameValuePairs := NIL;
   BEGIN
      IF LookupAndDefine( Name, OUT pairs, OUT leaf ) THEN
         RETURN pairs^.DefineValue( leaf, Type, Flags, Data, InitialValue, OUT Children );
      ELSE
         RETURN FALSE;
      END;
   END DefineValue;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE DefineLink( CONST Name : StringsO.IString; Flags : iovalue.TFlags; Link, Data : PTR ) : BOOLEAN;
   VAR
      leaf : StringsO.CString;
      pairs : ns.TPNameValuePairs := NIL;
   BEGIN
      IF LookupAndDefine( Name, OUT pairs, OUT leaf ) THEN
         RETURN nsinternal.TPNameValuePairs( ns.TPNameValuePairs( pairs ))^.DefineLink( leaf, Flags, Link, Data );
      ELSE
         RETURN FALSE;
      END;
   END DefineLink;

(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE LookupAndDefine( CONST Name : StringsO.IString; OUT Children : ns.TPNameValuePairs; OUT LeafName : StringsO.IString ) : BOOLEAN;
   VAR
      i : CARDINAL := 0;
      pairs : ns.TPNameValuePairs := NIL;
      toTest : StringsO.CString;
   BEGIN
      IF Name.Empty THEN
         RETURN FALSE;
      END;

      pairs := _Pairs;
      LOOP
         i := Name.ItemS( StringsO.WCHARS{L'.'}, i, 0, TRUE, OUT toTest );
         IF i = Name.Length THEN // last item decomposed
            EXIT;
         ELSIF toTest.Empty THEN // Empty string before Name end detected, likely ".." appeared in the Name. This is disallowed.
            RETURN FALSE;
         ELSIF pairs^.Child( toTest, OUT pairs ) THEN
            // OK, fall down
         ELSIF NOT pairs^.DefineValue( toTest, iovalue.vtObject, nsinternal.flagsDefaultName, 0, NIL, OUT pairs ) THEN // strange, but ok
            RETURN FALSE;
         END;
      END; // LOOP

      Children := pairs;
      LeafName.Assign( toTest );

      RETURN TRUE;
   END LookupAndDefine;

(*---------------------------------------------------------------------------*)

BEGIN
   NEW( _Pairs );
FINALLY
   Dispose();
   IF _Pairs <> NIL THEN
      DISPOSE( _Pairs );
   END;
END Namespace;

(*===========================================================================*)

END nsimpl.