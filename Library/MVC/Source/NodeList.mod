IMPLEMENTATION MODULE NodeList;

FROM Storage IMPORT
   ALLOCATE;
  
//===========================================================================

CLASS IMPLEMENTATION CNodeItem;

   PUBLIC PROPERTY Type GET : xmlreader.TNodeType;
   BEGIN
      RETURN _Type;
   END Type;

//---------------------------------------------------------------------------

   PUBLIC PROPERTY Prefix GET : StringsO.TPString;
   BEGIN
      RETURN ADR( _Prefix );
   END Prefix;
   
//---------------------------------------------------------------------------

   PUBLIC PROPERTY Name GET : StringsO.TPString;
   BEGIN
      RETURN ADR( _Name );
   END Name;

//---------------------------------------------------------------------------

   PUBLIC PROPERTY Empty GET : BOOLEAN;
   BEGIN
      RETURN _Empty;
   END Empty;

//---------------------------------------------------------------------------

   PUBLIC PROPERTY Value GET : StringsO.TPString;
   BEGIN
      RETURN ADR( _Value );
   END Value;

//---------------------------------------------------------------------------

   PUBLIC PROPERTY Attributes GET : lists.TPStringStringList;
   BEGIN
      RETURN ADR( _Attributes );
   END Attributes;

//---------------------------------------------------------------------------

BEGIN
   _Type := xmlreader.xntUnknown;
   _Empty := TRUE;
END CNodeItem;

//---------------------------------------------------------------------------

CLASS IMPLEMENTATION CNodeList;

//---------------------------------------------------------------------------

   PUBLIC PROCEDURE CNodeList.Add( Type : xmlreader.TNodeType; CONST Prefix, Name : StringsO.IString; Empty : BOOLEAN; CONST Value : StringsO.IString; REF Attributes : lists.CStringStringList ); // Attributes are cleared when added
   VAR
      PE : TPNodeItem;
   BEGIN
      NEW( PE );
      PE^._Type := Type;
      PE^._Prefix.Assign( Prefix );
      PE^._Name.Assign( Name );
      PE^._Empty := Empty;
      PE^._Value.Assign( Value );
      PE^._Attributes.AppendList( REF Attributes );
      SUPER.Add( PE );
   END CNodeList.Add;

//---------------------------------------------------------------------------

END CNodeList;

(*================================================================================*)

CLASS IMPLEMENTATION CNodeListIterator;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Value GET : TPNodeItem;
   BEGIN
      RETURN TPNodeItem( Current );
   END Value;

(*--------------------------------------------------------------------------------*)

END CNodeListIterator;

(*================================================================================*)

END NodeList.