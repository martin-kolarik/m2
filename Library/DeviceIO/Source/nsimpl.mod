IMPLEMENTATION MODULE nsimpl;

(*===========================================================================*)

CLASS IMPLEMENTATION SimpleAdviseSource;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Advise GET : ns.TAdvise;
   BEGIN
      RETURN _Advise;
   END Advise;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Advise SET( Value : ns.TAdvise );
   BEGIN
      _Advise := Value;
   END Advise;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY AdviseListener GET : ns.TPAdviseInfo;
   BEGIN
      RETURN _AdviseListener;
   END AdviseListener;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY AdviseListener SET( Value : ns.TPAdviseInfo );
   BEGIN
      _AdviseListener := Value;
   END AdviseListener;

(*---------------------------------------------------------------------------*)

BEGIN
END SimpleAdviseSource;

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

   PUBLIC VIRTUAL PROCEDURE ValueIO( CONST Originator : ns.TPOriginator; CONST NameValuePairs : ns.TPNameValuePairs; Direction : IOO.TDirection; REF Value : iovalue.Value ) : Sync.TAsyncResult;
   BEGIN
      RETURN _Pairs^.ValueIO( Originator, NameValuePairs, Direction, REF Value );
   END ValueIO;

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
         ELSIF i = 0 THEN // ok, leading dot is allowed
            CONTINUE;
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

   PUBLIC VIRTUAL PROPERTY AdviseSource GET : ns.TPAdviseSource;
   BEGIN
      RETURN _Pairs^.AdviseSource;
   END AdviseSource;

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

   PUBLIC VIRTUAL PROPERTY Data GET : PTR;
   BEGIN
      RETURN _Pairs^.Data;
   END Data;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Data SET( Value : PTR );
   BEGIN
      _Pairs^.Data := Value;
   END Data;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY VisibleToUser GET : BOOLEAN;
   BEGIN
      RETURN _Pairs^.VisibleToUser;
   END VisibleToUser;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY HasValue GET : BOOLEAN;
   BEGIN
      RETURN _Pairs^.HasValue;
   END HasValue;

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

   PUBLIC VIRTUAL PROCEDURE DefineStorageValue( CONST Name : StringsO.IString; Type : iovalue.TType; Flags : iovalue.TFlags; CONST InitialValue : iovalue.TPValue; Data : PTR; AccessLock : Sync.PIRLock; CONST AdviseSource : ns.TPAdviseSource; OUT Children : ns.TPNameValuePairs ) : BOOLEAN;
   VAR
      leaf : StringsO.CString;
      pairs : ns.TPNameValuePairs := NIL;
   BEGIN
      IF LookupAndDefine( TRUE, Name, OUT pairs, OUT leaf ) THEN
         RETURN pairs^.DefineStorageValue( leaf, Type, Flags, InitialValue, Data, AccessLock, AdviseSource, OUT Children );
      ELSE
         RETURN FALSE;
      END;
   END DefineStorageValue;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE DefineIOValue( CONST Name : StringsO.IString; REF ValueIO : ns.IValueIO; Data : PTR; CONST AdviseSource : ns.TPAdviseSource; OUT Children : ns.TPNameValuePairs ) : BOOLEAN;
   VAR
      leaf : StringsO.CString;
      pairs : ns.TPNameValuePairs := NIL;
   BEGIN
      IF LookupAndDefine( TRUE, Name, OUT pairs, OUT leaf ) THEN
         RETURN pairs^.DefineIOValue( leaf, REF ValueIO, Data, AdviseSource, OUT Children );
      ELSE
         RETURN FALSE;
      END;
   END DefineIOValue;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Link( CONST Name : StringsO.IString; CONST Child : ns.TPNameValuePairs ) : BOOLEAN;
   VAR
      leaf : StringsO.CString;
      pairs : ns.TPNameValuePairs := NIL;
   BEGIN
      IF LookupAndDefine( TRUE, Name, OUT pairs, OUT leaf ) THEN
         RETURN pairs^.Link( leaf, Child );
      ELSE
         RETURN FALSE;
      END;
   END Link;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Unlink( CONST Name : StringsO.IString; OUT Child : ns.TPNameValuePairs ) : BOOLEAN;
   VAR
      leaf : StringsO.CString;
      pairs : ns.TPNameValuePairs := NIL;
   BEGIN
      IF LookupAndDefine( FALSE, Name, OUT pairs, OUT leaf ) THEN
         RETURN pairs^.Unlink( leaf, OUT Child );
      ELSE
         RETURN FALSE;
      END;
   END Unlink;

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
      IF LookupAndDefine( TRUE, Name, OUT pairs, OUT leaf ) THEN
         iv.Reference := Reference;
         RETURN pairs^.DefineStorageValue( leaf, iovalue.vtReference, Flags, ADR( iv ), Data, NIL, NIL, OUT pairs );
      ELSE
         RETURN FALSE;
      END;
   END DefineReference;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY AccessLock GET : Sync.PIRLock;
   BEGIN
      RETURN ADR( _Lock );
   END AccessLock;

(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE LookupAndDefine( AllowCreation : BOOLEAN; CONST Name : StringsO.IString; OUT Children : ns.TPNameValuePairs; OUT LeafName : StringsO.IString ) : BOOLEAN;
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
         ELSIF NOT AllowCreation THEN
            RETURN FALSE;
         ELSIF NOT pairs^.DefineStorageValue( toTest, iovalue.vtObject, iovalue.TFlags{ iovalue.vfReadOnly }, NIL, 0, NIL, NIL, OUT pairs ) THEN // strange, but ok
            RETURN FALSE;
         END;
      END; // LOOP

      Children := pairs;
      LeafName.Assign( toTest );

      RETURN TRUE;
   END LookupAndDefine;

(*---------------------------------------------------------------------------*)

   INITIALLY Namespace();
   VAR
      value : iovalue.Value;
   BEGIN
      NEW( _Pairs );
      value.Type := iovalue.vtObject;
      _Pairs^.Value := value;
   END Namespace;

(*---------------------------------------------------------------------------*)

   FINALLY Namespace();
   BEGIN
      Dispose();
      IF _Pairs <> NIL THEN
         DISPOSE( _Pairs );
      END;
   END Namespace;

(*---------------------------------------------------------------------------*)

END Namespace;

(*===========================================================================*)

PROCEDURE AddContext( CONST Context, Name : StringsO.IString ) : StringsO.CString;
VAR
   s : StringsO.CString;
BEGIN
   IF Name.Empty THEN
      // fall down
   ELSIF ( Name[0] = L"." ) OR Context.Empty THEN
      s.Assign( Name ); // the name is absolute, do not append context
   ELSE
      s.Assign( Context );
      s.AppendOA( L"." );
      s.Append( Name );
   END;
   RETURN s;
END AddContext;

(*---------------------------------------------------------------------------*)

PROCEDURE RemoveContext( CONST Context, Input : StringsO.IString ) : StringsO.CString;
VAR
   s : StringsO.CString;
BEGIN
   s.Assign( Input );
   IF NOT Context.Empty AND Input.StartsWith( Context ) THEN
      s.Remove( 0, Context.Length + 1 ); // with DOT
   END;
   RETURN s;
END RemoveContext;

(*===========================================================================*)

END nsimpl.