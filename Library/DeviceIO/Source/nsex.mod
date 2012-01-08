IMPLEMENTATION MODULE nsex;

IMPORT
   nstools,
   StringsO;

(*===========================================================================*)

TYPE
   TPairs = POINTER TO nstools.CNameValuePairs;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION Namespace;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   BEGIN
      IF _Pairs <> NIL THEN
         _Pairs^.Dispose();
         DISPOSE( _Pairs );
      END;
   END Dispose;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE NameToHash( CONST Name : StringsO.IString; OUT Hash : THash ) : BOOLEAN;
   VAR
      hash : THash;
      i : CARDINAL;
      pairs : nstools.TPNameValuePairs;
      toTest : StringsO.CString;
      value : iovalue.TPValue;
   BEGIN
      IF Name.Empty THEN
         RETURN FALSE;
      END;

      // Root, the first item, must be handled separatelly
      i := Name.ItemS( StringsO.WCHARS{L'.'}, 0, 0, TRUE, OUT toTest );
      IF toTest.Empty THEN
         RETURN FALSE;
      ELSIF Name <> toTest THEN
         RETURN FALSE;
      END;
      // then continue down pairs by pairs
      pairs := _Pairs;
      LOOP
         i := Name.ItemS( StringsO.WCHARS{L'.'}, i, 0, TRUE, OUT toTest );
         IF toTest.Empty THEN
            EXIT;
         ELSIF NOT pairs^.NameToHash( toTest, OUT hash ) OR NOT pairs^.HashToValue( hash, OUT value ) THEN
            RETURN FALSE;
         ELSIF value^.Children = NIL THEN
            RETURN FALSE;
         ELSIF value^.Children^ IS nstools.CNameValuePairs THEN
            pairs := nstools.TPNameValuePairs( value^.Children );
         ELSE
            RETURN FALSE;
         END;
      END; // LOOP

      Hash := hash;
      RETURN TRUE;
   END NameToHash;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE HashToName( CONST Hash : THash; OUT Name : StringsO.IString ) : BOOLEAN;
   VAR
      dot : StringsO.CString;
      name : StringsO.CString;
      hash : THash := Hash;
      singleName : StringsO.CString;
   BEGIN
      IF NOT _Pairs^.HashToName( Hash, OUT name ) THEN
         RETURN FALSE;
      END;
      dot := StringsO.FromOA( L"." );
      WHILE _Pairs^.HashToParent( hash, OUT hash ) DO
         IF _Pairs^.HashToName( hash, OUT singleName ) THEN
            name.Prepend( dot );
            name.Prepend( singleName );
         ELSE
            RETURN FALSE;
         END;
      END; // WHILE
      Name.Assign( name );
      RETURN TRUE;
   END HashToName;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE HashToValue( CONST Hash : THash; OUT Value : iovalue.TPValue ) : BOOLEAN;
   BEGIN
      RETURN _Pairs^.HashToValue( Hash, OUT Value );
   END HashToValue;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Contains( CONST Name : StringsO.IString ) : BOOLEAN;
   VAR
      Value : iovalue.TPValue;
   BEGIN
      RETURN Get( Name, OUT Value );
   END Contains;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Get( CONST NameOrIndex : StringsO.IString; OUT Value : iovalue.TPValue ) : BOOLEAN; // tries to convert string to number, if it succeeds index is used
   VAR
      index : CARDINAL;
   BEGIN
      IF Name.ToCARD32( 10, OUT index ) THEN
         RETURN ElementAt( index, OUT Value );
      ELSE
         RETURN Map( Name, OUT Value );
      END;
   END Get;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Map( CONST Name : StringsO.IString; OUT Value : iovalue.TPValue ) : BOOLEAN; // looks for string, does not try to convert name to index
   VAR
      hash : THash;
   BEGIN
      RETURN NameToHash( Name, OUT hash ) AND _Pairs^.HashToValue( hash, OUT Value );
   END Map;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE ElementAt( Index : CARDINAL; OUT Value : iovalue.TPValue ) : BOOLEAN;
   BEGIN
      RETURN _Pairs^.ElementAt( Index, OUT Value );
   END ElementAt;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Children( CONST Name : StringsO.IString; OUT children : iovalue.TPINameValuePairs ) : BOOLEAN;
   VAR
      value : iovalue.TPValue;
   BEGIN
      IF Map( Name, OUT value ) THEN
         children := value^.Children;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END Children;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Root GET : iovalue.TPValue;
   BEGIN
      RETURN ADR( _Root );
   END Root;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Name GET : StringsO.CString; // reads Root.String
   BEGIN
      RETURN _Root.String;
   END Name;

(*---------------------------------------------------------------------------*)

BEGIN
   NEW( _Pairs );
FINALLY
   Dispose();
END Namespace;

(*===========================================================================*)

END nsex.