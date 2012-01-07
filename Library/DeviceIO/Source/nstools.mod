IMPLEMENTATION MODULE nstools;

(*===========================================================================*)

TYPE
  TPNameValuePairsElem = POINTER TO CNameValuePairsElem;

CLASS CNameValuePairsElem( avltree.CAVLTreeElem );

   // CAVLTreeElem
   PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;

   // SELF
   LOCAL VAR
      Name : StringsO.CString;
      Value : iovalue.Value;
      Parent : TPNameValuePairsElem;

END CNameValuePairsElem;

(*---------------------------------------------------------------------------*)

CLASS CSearchHelper( avltree.CAVLTreeElem );

   // CAVLTreeElem
   PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;

   // SELF
   LOCAL PROCEDURE Init( CONST Source : StringsO.IString );

   PRIVATE VAR
      Source : POINTER TO CONST StringsO.IString;

END CSearchHelper;

(*===========================================================================*)

CLASS IMPLEMENTATION CNameValuePairsElem;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;
   BEGIN
      RETURN Name.Compare( TPNameValuePairsElem( pelem )^.Name );
   END Compare;

(*---------------------------------------------------------------------------*)

BEGIN
   Parent := NIL;
END CNameValuePairsElem;

(*===========================================================================*)

CLASS IMPLEMENTATION CSearchHelper;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;
   BEGIN
      RETURN Source^.Compare( TPNameValuePairsElem( pelem )^.Name );
   END Compare;

(*---------------------------------------------------------------------------*)

   LOCAL PROCEDURE Init( CONST Source : StringsO.IString );
   BEGIN
      SELF.Source := ADR( Source );
   END Init;

(*---------------------------------------------------------------------------*)

BEGIN
   Source := NIL;
END CSearchHelper;

(*===========================================================================*)

CLASS IMPLEMENTATION CNameValuePairs;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   BEGIN
      _Storage.Dispose();
   END Dispose;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE NameToHash( CONST Name : StringsO.IString; OUT Hash : nsex.THash ) : BOOLEAN;
   VAR
      elem : TPNameValuePairsElem;
      helper : CSearchHelper;
   BEGIN
      helper.Init( Name );
      IF _Storage.SearchI( 0, ADR( helper ), OUT elem ) THEN
         Hash := elem;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END NameToHash;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE HashToName( CONST Hash : nsex.THash; OUT Name : StringsO.IString ) : BOOLEAN;
   VAR
      elem : TPNameValuePairsElem := TPNameValuePairsElem( Hash );
   BEGIN
      IF elem = NIL THEN
         RETURN FALSE;
      ELSIF NOT( elem^ IS CNameValuePairsElem ) THEN
         RETURN FALSE;
      ELSE
         Name := elem^.Name;
         RETURN TRUE;
      END;
   END HashToName;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE HashToValue( CONST Hash : nsex.THash; OUT Value : iovalue.TPValue ) : BOOLEAN;
   VAR
      elem : TPNameValuePairsElem := TPNameValuePairsElem( Hash );
   BEGIN
      IF elem = NIL THEN
         RETURN FALSE;
      ELSIF NOT( elem^ IS CNameValuePairsElem ) THEN
         RETURN FALSE;
      ELSE
         Value := ADR( elem^.Value );
         RETURN TRUE;
      END;
   END HashToValue;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE HashToParent( CONST Hash : nsex.THash; OUT Parent : nsex.THash ) : BOOLEAN;
   VAR
      elem : TPNameValuePairsElem := TPNameValuePairsElem( Hash );
   BEGIN
      IF elem = NIL THEN
         RETURN FALSE;
      ELSIF NOT( elem^ IS CNameValuePairsElem ) THEN
         RETURN FALSE;
      ELSE
         Parent := ADR( elem^.Parent );
         RETURN TRUE;
      END;
   END HashToParent;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Get( CONST NameOrIndex : StringsO.IString; OUT Value : iovalue.TPValue ) : BOOLEAN; // tries to convert string to number, if it succeeds index is used
   VAR
      index : CARDINAL;
   BEGIN
      IF NameOrIndex.ToCARD32( 10, OUT index ) THEN
         RETURN ElementAt( index, OUT Value );
      ELSE
         RETURN Map( NameOrIndex, OUT Value );
      END;
   END Get;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Map( CONST Name : StringsO.IString; OUT Value : iovalue.TPValue ) : BOOLEAN; // looks for string, does not try to convert name to index
   VAR
      elem : TPNameValuePairsElem;
      hash : nsex.THash;
   BEGIN
      IF NameToHash( Name, OUT hash ) THEN
         elem := TPNameValuePairsElem( hash );
         Value := ADR( elem^.Value );
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END Map;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE ElementAt( Index : CARDINAL; OUT Value : iovalue.TPValue ) : BOOLEAN;
   VAR
      elem : TPNameValuePairsElem;
   BEGIN
      elem := TPNameValuePairsElem( _Storage[ Index ] );
      IF elem = NIL THEN
         RETURN FALSE;
      ELSE
         Value := ADR( elem^.Value );
         RETURN TRUE;
      END;
      (*
      IF _Storage.ElementAt( Index, OUT elem ) THEN
         Value := ADR( elem^.Value );
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
      *)
   END ElementAt;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Children( CONST Name : StringsO.IString; OUT children : iovalue.TPINameValuePairs ) : BOOLEAN; // shorthand for Get[Name]->Value->Children
   VAR
      Value : iovalue.TPValue;
   BEGIN
      IF NOT Map( Name, OUT Value ) THEN
         RETURN FALSE;
      ELSIF Value^.Children = NIL THEN
         RETURN FALSE;
      ELSE
         children := Value^.Children;
         RETURN TRUE;
      END;
   END Children;

(*---------------------------------------------------------------------------*)

END CNameValuePairs;

(*===========================================================================*)

PUBLIC PROCEDURE LoadNamespace( CONST stream : IOO.TPStream; REF ns : nsex.Namespace ) : Sync.TAsyncResult;
BEGIN
   RETURN Sync.arCannotStart;
END LoadNameSpace;

(*===========================================================================*)

END nstools.