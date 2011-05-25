IMPLEMENTATION MODULE stacks;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   collection,
   list;

(*===========================================================================*)

CLASS IMPLEMENTATION CIntegerBaseStack;

(*---------------------------------------------------------------------------*)

   PUBLIC READONLY PROPERTY Top GET : INTEGER;
   VAR
      it : lists.CIntegerBaseListIterator;
   BEGIN
      it.Init( ADR( SELF ), collection.dirForward );
      RETURN it.Value;
   END Top;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY TopData GET : baseobject.PIBASE;
   VAR
      it : lists.CIntegerBaseListIterator;
   BEGIN
      it.Init( ADR( SELF ), collection.dirForward );
      RETURN it.Data;
   END TopData;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY TopData SET( Value : baseobject.PIBASE );
   VAR
      it : lists.CIntegerBaseListIterator;
   BEGIN
      it.Init( ADR( SELF ), collection.dirForward );
      it.Data := Value;
   END TopData;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Push( Value : INTEGER; Data : baseobject.PIBASE );
   BEGIN
      InsertFirst( Value, Data );
   END Push;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Pop( OUT Value : INTEGER; OUT Data : baseobject.PIBASE ) : BOOLEAN;
   VAR
      it : lists.CIntegerBaseListIterator;
   BEGIN
      it.Init( ADR( SELF ), collection.dirForward );
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

   PUBLIC PROCEDURE Peek( OUT Value : INTEGER; OUT Data : baseobject.PIBASE ) : BOOLEAN;
   VAR
      it : lists.CIntegerBaseListIterator;
   BEGIN
      it.Init( ADR( SELF ), collection.dirForward );
      IF it.colCurrent = NIL THEN
         RETURN FALSE;
      ELSE
         Value := it.Value;
         Data := it.Data;
         RETURN TRUE;
      END;
   END Peek;

(*---------------------------------------------------------------------------*)

END CIntegerBaseStack;

(*===========================================================================*)

CLASS IMPLEMENTATION CBaseBaseStack;

(*---------------------------------------------------------------------------*)

   PUBLIC READONLY PROPERTY Top GET : baseobject.PIBASE;
   VAR
      it : lists.CBaseBaseListIterator;
   BEGIN
      it.Init( ADR( SELF ), collection.dirForward );
      RETURN it.Value;
   END Top;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY TopData GET : baseobject.PIBASE;
   VAR
      it : lists.CBaseBaseListIterator;
   BEGIN
      it.Init( ADR( SELF ), collection.dirForward );
      RETURN it.Data;
   END TopData;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY TopData SET( Value : baseobject.PIBASE );
   VAR
      it : lists.CBaseBaseListIterator;
   BEGIN
      it.Init( ADR( SELF ), collection.dirForward );
      it.Data := Value;
   END TopData;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Push( Value : baseobject.PIBASE; Data : baseobject.PIBASE );
   BEGIN
      InsertFirst( Value, Data );
   END Push;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Pop( OUT Value : baseobject.PIBASE; OUT Data : baseobject.PIBASE ) : BOOLEAN;
   VAR
      it : lists.CBaseBaseListIterator;
   BEGIN
      it.Init( ADR( SELF ), collection.dirForward );
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

   PUBLIC PROCEDURE Peek( OUT Value : baseobject.PIBASE; OUT Data : baseobject.PIBASE ) : BOOLEAN;
   VAR
      it : lists.CBaseBaseListIterator;
   BEGIN
      it.Init( ADR( SELF ), collection.dirForward );
      IF it.colCurrent = NIL THEN
         RETURN FALSE;
      ELSE
         Value := it.Value;
         Data := it.Data;
         RETURN TRUE;
      END;
   END Peek;

(*---------------------------------------------------------------------------*)

END CBaseBaseStack;

(*===========================================================================*)

CLASS IMPLEMENTATION CStringBaseStack;

(*---------------------------------------------------------------------------*)

   PUBLIC READONLY PROPERTY Top GET : StringsO.TPString;
   VAR
      it : lists.CStringBaseListIterator;
   BEGIN
      it.Init( ADR( SELF ), collection.dirForward );
      RETURN it.Value;
   END Top;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY TopData GET : baseobject.PIBASE;
   VAR
      it : lists.CStringBaseListIterator;
   BEGIN
      it.Init( ADR( SELF ), collection.dirForward );
      RETURN it.Data;
   END TopData;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY TopData SET( Value : baseobject.PIBASE );
   VAR
      it : lists.CStringBaseListIterator;
   BEGIN
      it.Init( ADR( SELF ), collection.dirForward );
      it.Data := Value;
   END TopData;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Push( CONST Value : StringsO.IString; Data : baseobject.PIBASE );
   BEGIN
      InsertFirst( Value, Data );
   END Push;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Pop( OUT Value : StringsO.IString; OUT Data : baseobject.PIBASE ) : BOOLEAN;
   VAR
      it : lists.CStringBaseListIterator;
   BEGIN
      it.Init( ADR( SELF ), collection.dirForward );
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

   PUBLIC PROCEDURE Peek( OUT Value : StringsO.IString; OUT Data : baseobject.PIBASE ) : BOOLEAN;
   VAR
      it : lists.CStringBaseListIterator;
   BEGIN
      it.Init( ADR( SELF ), collection.dirForward );
      IF it.colCurrent = NIL THEN
         RETURN FALSE;
      ELSE
         Value.Assign( it.Value^ );
         Data := it.Data;
         RETURN TRUE;
      END;
   END Peek;

(*---------------------------------------------------------------------------*)

END CStringBaseStack;

(*===========================================================================*)

END stacks.