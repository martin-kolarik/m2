IMPLEMENTATION MODULE stacks;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   collection,
   list;

(*===========================================================================*)

CLASS IMPLEMENTATION CIntegerPtrStack;

(*---------------------------------------------------------------------------*)

   PUBLIC READONLY PROPERTY Top GET : INTEGER;
   VAR
      it : lists.CIntegerPtrListIterator;
   BEGIN
      it.Init( SELF, collection.dirForward );
      RETURN it.Value;
   END Top;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY TopData GET : PTR;
   VAR
      it : lists.CIntegerPtrListIterator;
   BEGIN
      it.Init( SELF, collection.dirForward );
      RETURN it.Data;
   END TopData;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY TopData SET( Value : PTR );
   VAR
      it : lists.CIntegerPtrListIterator;
   BEGIN
      it.Init( SELF, collection.dirForward );
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
      it : lists.CIntegerPtrListIterator;
   BEGIN
      it.Init( SELF, collection.dirForward );
      IF it.colCurrent = NIL THEN
         RETURN FALSE;
      ELSE
         Value := it.Value;
         Data := it.Data;
         Delete( list.TPListElem( it.colCurrent ));
         RETURN TRUE;
      END;
   END Pop;
  
(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Peek( OUT Value : INTEGER; OUT Data : PTR ) : BOOLEAN;
   VAR
      it : lists.CIntegerPtrListIterator;
   BEGIN
      it.Init( SELF, collection.dirForward );
      IF it.colCurrent = NIL THEN
         RETURN FALSE;
      ELSE
         Value := it.Value;
         Data := it.Data;
         RETURN TRUE;
      END;
   END Peek;

(*---------------------------------------------------------------------------*)

END CIntegerPtrStack;

(*===========================================================================*)

CLASS IMPLEMENTATION CPtrPtrStack;

(*---------------------------------------------------------------------------*)

   PUBLIC READONLY PROPERTY Top GET : PTR;
   VAR
      it : lists.CPtrPtrListIterator;
   BEGIN
      it.Init( SELF, collection.dirForward );
      RETURN it.Value;
   END Top;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY TopData GET : PTR;
   VAR
      it : lists.CPtrPtrListIterator;
   BEGIN
      it.Init( SELF, collection.dirForward );
      RETURN it.Data;
   END TopData;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY TopData SET( Value : PTR );
   VAR
      it : lists.CPtrPtrListIterator;
   BEGIN
      it.Init( SELF, collection.dirForward );
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
      it : lists.CPtrPtrListIterator;
   BEGIN
      it.Init( SELF, collection.dirForward );
      IF it.colCurrent = NIL THEN
         RETURN FALSE;
      ELSE
         Value := it.Value;
         Data := it.Data;
         Delete( list.TPListElem( it.colCurrent ));
         RETURN TRUE;
      END;
   END Pop;
  
(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Peek( OUT Value : PTR; OUT Data : PTR ) : BOOLEAN;
   VAR
      it : lists.CPtrPtrListIterator;
   BEGIN
      it.Init( SELF, collection.dirForward );
      IF it.colCurrent = NIL THEN
         RETURN FALSE;
      ELSE
         Value := it.Value;
         Data := it.Data;
         RETURN TRUE;
      END;
   END Peek;

(*---------------------------------------------------------------------------*)

END CPtrPtrStack;

(*===========================================================================*)

CLASS IMPLEMENTATION CStringPtrStack;

(*---------------------------------------------------------------------------*)

   PUBLIC READONLY PROPERTY Top GET : StringsO.TPString;
   VAR
      it : lists.CStringPtrListIterator;
   BEGIN
      it.Init( SELF, collection.dirForward );
      RETURN it.Value;
   END Top;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY TopData GET : PTR;
   VAR
      it : lists.CStringPtrListIterator;
   BEGIN
      it.Init( SELF, collection.dirForward );
      RETURN it.Data;
   END TopData;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY TopData SET( Value : PTR );
   VAR
      it : lists.CStringPtrListIterator;
   BEGIN
      it.Init( SELF, collection.dirForward );
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
      it : lists.CStringPtrListIterator;
   BEGIN
      it.Init( SELF, collection.dirForward );
      IF it.colCurrent = NIL THEN
         RETURN FALSE;
      ELSE
         Value.Assign( it.Value^ );
         Data := it.Data;
         Delete( list.TPListElem( it.colCurrent ));
         RETURN TRUE;
      END;
   END Pop;
  
(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Peek( OUT Value : StringsO.IString; OUT Data : PTR ) : BOOLEAN;
   VAR
      it : lists.CStringPtrListIterator;
   BEGIN
      it.Init( SELF, collection.dirForward );
      IF it.colCurrent = NIL THEN
         RETURN FALSE;
      ELSE
         Value.Assign( it.Value^ );
         Data := it.Data;
         RETURN TRUE;
      END;
   END Peek;

(*---------------------------------------------------------------------------*)

END CStringPtrStack;

(*===========================================================================*)

END stacks.