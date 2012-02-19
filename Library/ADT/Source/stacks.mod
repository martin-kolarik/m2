IMPLEMENTATION MODULE stacks;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   collection,
   list;

(*===========================================================================*)

CLASS IMPLEMENTATION CIntegerStack;

(*---------------------------------------------------------------------------*)

   PUBLIC READONLY PROPERTY Top GET : INTEGER;
   VAR
      it : lists.CIntegerListIterator;
   BEGIN
      it.Init( SELF, collection.dirForward );
      it.MoveNext();
      RETURN it.Value;
   END Top;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY TopData GET : PTR;
   VAR
      it : lists.CIntegerListIterator;
   BEGIN
      it.Init( SELF, collection.dirForward );
      it.MoveNext();
      RETURN it.Data;
   END TopData;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY TopData SET( Value : PTR );
   VAR
      it : lists.CIntegerListIterator;
   BEGIN
      it.Init( SELF, collection.dirForward );
      it.MoveNext();
      it.Data := Value;
   END TopData;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Push( Value : INTEGER; Data : PTR );
   BEGIN
      InsertFirst( Value, Data );
   END Push;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Pop( OUT Value : INTEGER; OUT Data : PTR ) : BOOLEAN;
   VAR
      it : lists.CIntegerListIterator;
   BEGIN
      it.Init( SELF, collection.dirForward );
      IF it.MoveNext() THEN
         Value := it.Value;
         Data := it.Data;
         Delete( list.TPListElem( it.colCurrent ));
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END Pop;
  
(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Peek( OUT Value : INTEGER; OUT Data : PTR ) : BOOLEAN;
   VAR
      it : lists.CIntegerListIterator;
   BEGIN
      it.Init( SELF, collection.dirForward );
      IF it.MoveNext() THEN
         Value := it.Value;
         Data := it.Data;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END Peek;

(*---------------------------------------------------------------------------*)

END CIntegerStack;

(*===========================================================================*)

CLASS IMPLEMENTATION CPtrStack;

(*---------------------------------------------------------------------------*)

   PUBLIC READONLY PROPERTY Top GET : PTR;
   VAR
      it : lists.CPtrListIterator;
   BEGIN
      it.Init( SELF, collection.dirForward );
      it.MoveNext();
      RETURN it.Value;
   END Top;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY TopData GET : PTR;
   VAR
      it : lists.CPtrListIterator;
   BEGIN
      it.Init( SELF, collection.dirForward );
      it.MoveNext();
      RETURN it.Data;
   END TopData;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY TopData SET( Value : PTR );
   VAR
      it : lists.CPtrListIterator;
   BEGIN
      it.Init( SELF, collection.dirForward );
      it.MoveNext();
      it.Data := Value;
   END TopData;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Push( Value : PTR; Data : PTR );
   BEGIN
      InsertFirst( Value, Data );
   END Push;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Pop( OUT Value : PTR; OUT Data : PTR ) : BOOLEAN;
   VAR
      it : lists.CPtrListIterator;
   BEGIN
      it.Init( SELF, collection.dirForward );
      IF it.MoveNext() THEN
         Value := it.Value;
         Data := it.Data;
         Delete( list.TPListElem( it.colCurrent ));
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END Pop;
  
(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Peek( OUT Value : PTR; OUT Data : PTR ) : BOOLEAN;
   VAR
      it : lists.CPtrListIterator;
   BEGIN
      it.Init( SELF, collection.dirForward );
      IF it.MoveNext() THEN
         Value := it.Value;
         Data := it.Data;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END Peek;

(*---------------------------------------------------------------------------*)

END CPtrStack;

(*===========================================================================*)

CLASS IMPLEMENTATION CStringStack;

(*---------------------------------------------------------------------------*)

   PUBLIC READONLY PROPERTY Top GET : StringsO.TPString;
   VAR
      it : lists.CStringListIterator;
   BEGIN
      it.Init( SELF, collection.dirForward );
      it.MoveNext();
      RETURN it.Value;
   END Top;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY TopData GET : PTR;
   VAR
      it : lists.CStringListIterator;
   BEGIN
      it.Init( SELF, collection.dirForward );
      it.MoveNext();
      RETURN it.Data;
   END TopData;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY TopData SET( Value : PTR );
   VAR
      it : lists.CStringListIterator;
   BEGIN
      it.Init( SELF, collection.dirForward );
      it.MoveNext();
      it.Data := Value;
   END TopData;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Push( CONST Value : StringsO.IString; Data : PTR );
   BEGIN
      InsertFirst( Value, Data );
   END Push;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Pop( OUT Value : StringsO.IString; OUT Data : PTR ) : BOOLEAN;
   VAR
      it : lists.CStringListIterator;
   BEGIN
      it.Init( SELF, collection.dirForward );
      IF it.MoveNext() THEN
         Value.Assign( it.Value^ );
         Data := it.Data;
         Delete( list.TPListElem( it.colCurrent ));
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END Pop;
  
(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Peek( OUT Value : StringsO.IString; OUT Data : PTR ) : BOOLEAN;
   VAR
      it : lists.CStringListIterator;
   BEGIN
      it.Init( SELF, collection.dirForward );
      IF it.MoveNext() THEN
         Value.Assign( it.Value^ );
         Data := it.Data;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END Peek;

(*---------------------------------------------------------------------------*)

END CStringStack;

(*===========================================================================*)

END stacks.