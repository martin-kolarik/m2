IMPLEMENTATION MODULE nsimpl;

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

   PUBLIC VIRTUAL PROCEDURE Get( CONST Name : StringsO.IString; OUT child : ns.TPNameValuePairs ) : BOOLEAN;
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
         ELSIF NOT pairs^.Get( toTest, OUT pairs ) THEN
            RETURN FALSE;
         END;
      END; // LOOP

      IF pairs = NIL THEN
         RETURN FALSE;
      ELSE
         child := pairs;
         RETURN TRUE;
      END;
   END Get;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Name GET : StringsO.CString;
   BEGIN
      RETURN _Pairs^.Name;
   END Name;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Parent GET : ns.TPNameValuePairs;
   BEGIN
      RETURN _Pairs^.Parent;
   END Parent;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Value GET : iovalue.Value;
   BEGIN
      RETURN _Pairs^.Value;
   END Value;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Value SET( CONST value : iovalue.Value );
   BEGIN
      _Pairs^.Value := value;
   END Value;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Contains( CONST Name : StringsO.IString ) : BOOLEAN;
   VAR
      hash : ns.THash;
   BEGIN
      RETURN Get( Name, OUT hash );
   END Contains;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE GetFullName( CONST Value : ns.TPNameValuePairs; OUT FullName : StringsO.IString ) : BOOLEAN;
   VAR
      dot : StringsO.CString;
      name : StringsO.CString;
      pairs : ns.TPNameValuePairs;
   BEGIN
      IF Value = NIL THEN
         RETURN FALSE;
      END;

      dot := StringsO.FromOA( L"." );
      pairs := Value;

      REPEAT
         // construct
         IF name.Empty THEN
            name := pairs^.Name;
         ELSE
            name.Prepend( dot );
            name.Prepend( pairs^.Name );
         END;
         // move up
         pairs := pairs^.Parent;
      UNTIL pairs = ADR( _Pairs^.INameValuePairs ); // me as a Hash

      FullName.Assign( name );
      RETURN TRUE;
   END GetFullName;

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

   PUBLIC VIRTUAL PROCEDURE Link( CONST Name : StringsO.IString; CONST Child : ns.TPNameValuePairs ) : BOOLEAN;
   VAR
      leaf : StringsO.CString;
      pairs : ns.TPNameValuePairs := NIL;
   BEGIN
      IF LookupAndDefine( Name, OUT pairs, OUT leaf ) THEN
         RETURN pairs^.Link( leaf, Child );
      ELSE
         RETURN FALSE;
      END;
   END Link;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY InitializeName SET( CONST Value : StringsO.CString );
   BEGIN
      _Pairs^.InitializeName := Value;
   END InitializeName;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE DefineReference( CONST Name : StringsO.IString; Flags : iovalue.TFlags; Reference, Data : PTR ) : BOOLEAN;
   VAR
      iv : iovalue.Value;
      leaf : StringsO.CString;
      pairs : ns.TPNameValuePairs := NIL;
   BEGIN
      IF LookupAndDefine( Name, OUT pairs, OUT leaf ) THEN
         iv.Reference := Reference;
         RETURN pairs^.DefineValue( leaf, iovalue.vtReference, Flags, Data, ADR( iv ), OUT pairs );
      ELSE
         RETURN FALSE;
      END;
   END DefineReference;

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
         ELSIF pairs^.Get( toTest, OUT pairs ) THEN
            // OK, fall down
         ELSIF NOT pairs^.DefineValue( toTest, iovalue.vtObject, iovalue.TFlags{ iovalue.vfReadOnly }, 0, NIL, OUT pairs ) THEN // strange, but ok
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