IMPLEMENTATION MODULE TimeoutableTwoPtrMap;

IMPORT
   Sync;
  
//================================================================================

TYPE
  TPTimeoutableItem = POINTER TO CTimeoutableItem;

CLASS CTimeoutableItem( avltree.CAVLTreeElem2 );
  PUBLIC VAR
    Key1, Key2 : PTR;
    Data : PTR;
    Timeout : CARDINAL;
    ElapsesOn : CARD64;

  PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;

  // OPERATOR NEW() : ADDRESS;
  // OPERATOR DISPOSE( a : ADDRESS );
END CTimeoutableItem;

//---------------------------------------------------------------------------

CLASS IMPLEMENTATION CTimeoutableItem;

//--------------------------------------------------------------------------------

  PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;
  BEGIN
    IF i = 0 THEN
      IF Key1 < TPTimeoutableItem( pelem )^.Key1 THEN
        RETURN -1;
      ELSIF Key1 > TPTimeoutableItem( pelem )^.Key1 THEN
        RETURN 1;
      ELSIF Key2 < TPTimeoutableItem( pelem )^.Key2 THEN
        RETURN -1;
      ELSIF Key2 > TPTimeoutableItem( pelem )^.Key2 THEN
        RETURN 1;
      ELSE
        RETURN 0;
      END;
    ELSIF i = 1 THEN
      IF ElapsesOn < TPTimeoutableItem( pelem )^.ElapsesOn THEN
        RETURN -1;
      ELSIF ElapsesOn > TPTimeoutableItem( pelem )^.ElapsesOn THEN
        RETURN 1;
      ELSE
        RETURN 0;
      END;
    ELSE
      RETURN 1;
    END;
  END Compare;

  // OPERATOR CTaskItem.NEW() : ADDRESS;
  // VAR
  //   a : ADDRESS;
  // BEGIN
  //   IF TaskAllocator.Allocate( OUT a, SIZE( CTaskItem )) THEN
  //     RETURN a;
  //   ELSE
  //     RETURN NIL;
  //   END;
  // END CPtrItem.NEW;
  
  // OPERATOR CTaskItem.DISPOSE( a : ADDRESS );
  // BEGIN
  //   TaskAllocator.Deallocate( REF a );
  // END CTaskItem.DISPOSE;

//--------------------------------------------------------------------------------

BEGIN
  Key1 := 0;
  Key2 := 0;
  Data := 0;
  Timeout := 0;
  ElapsesOn := 0;
END CTimeoutableItem;

//================================================================================

CLASS IMPLEMENTATION CTimeoutableTwoPtrMap;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE Add( CurrentTime : CARDINAL; Key1, Key2 : PTR; Data : PTR; Timeout : CARDINAL );
   VAR
      PI : TPTimeoutableItem;
   BEGIN
      NEW( PI );
      PI^.Key1 := Key1;
      PI^.Key2 := Key2;
      PI^.Data := Data;
      PI^.Timeout := Timeout;
      IF Timeout = Sync.FOREVER THEN
         PI^.ElapsesOn := CARD64( Sync.FOREVER ) << 32 OR CARD64( Counter );
      ELSIF Timeout = 0 THEN
         PI^.ElapsesOn := CARD64( CurrentTime + 1 ) << 32 OR CARD64( Counter );
      ELSE
         PI^.ElapsesOn := CARD64( CurrentTime + Timeout ) << 32 OR CARD64( Counter );
      END;
      SUPER.Add( PI );
      INC( Counter );
   END Add;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE Remove( Key1, Key2 : PTR );
   VAR
      I : CTimeoutableItem;
   BEGIN
      I.Key1 := Key1;
      Delete( 0, ADR( I ));
   END Remove;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE Contains( Key1, Key2 : PTR ) : BOOLEAN;
   VAR
      I : CTimeoutableItem;
   BEGIN
      I.Key1 := Key1;
      RETURN SUPER.Contains( 0, ADR( I ));
   END Contains;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE Get( Key1, Key2 : PTR; OUT Data : PTR ) : BOOLEAN;
   VAR
      I : CTimeoutableItem;
      PI : TPTimeoutableItem;
   BEGIN
      I.Key1 := Key1;
      IF NOT SUPER.Get( 0, ADR( I ), OUT PI ) THEN
         RETURN FALSE;
      END;
      Data := PI^.Data;
      RETURN TRUE;  
   END Get;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE ElementByKeyAt( Index : CARDINAL; OUT Key1, Key2 : PTR; OUT Data : PTR; OUT Timeout : CARDINAL ) : BOOLEAN; // similar as []
   VAR
      PI : TPTimeoutableItem;
   BEGIN
      IF NOT ElementAt( 0, Index, OUT PI ) THEN
         RETURN FALSE;
      ELSE
         Key1 := PI^.Key1;
         Key2 := PI^.Key2;
         Data := PI^.Data;
         Timeout := PI^.Timeout;
      END;
      RETURN TRUE;
   END ElementByKeyAt;
  
//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE ElementByTimeoutAt( Index : CARDINAL; OUT Key1, Key2 : PTR; OUT Data : PTR; OUT Timeout : CARDINAL ) : BOOLEAN; // similar as []
   VAR
      PI : TPTimeoutableItem;
   BEGIN
      IF NOT ElementAt( 1, Index, OUT PI ) THEN
         RETURN FALSE;
      ELSE
         Key1 := PI^.Key1;
         Key2 := PI^.Key2;
         Data := PI^.Data;
         Timeout := PI^.Timeout;
      END;
      RETURN TRUE;
   END ElementByTimeoutAt;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE GetTimeoutToFirstElapsed( CurrentTime : CARDINAL ) : CARDINAL;
   VAR
      Data : PTR;
      ElapsesBy : CARDINAL;
      ElapsesOn : CARDINAL;
      Key1, Key2 : PTR;
      Timeout : CARDINAL;
   BEGIN
      IF GetFirstWithTimeout( CurrentTime, OUT Key1, OUT Key2, OUT Data, OUT Timeout, OUT ElapsesOn, OUT ElapsesBy ) THEN
         RETURN ElapsesBy;
      ELSE
         RETURN Sync.FOREVER;
      END;
   END GetTimeoutToFirstElapsed;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE GetFirstElapsed( CurrentTime : CARDINAL; RemoveKey : BOOLEAN; OUT Key1, Key2 : PTR; OUT Data : PTR; OUT Timeout, ElapsedOn : CARDINAL ) : BOOLEAN;
   VAR
      ElapsesBy : CARDINAL;
   BEGIN
      IF NOT GetFirstWithTimeout( CurrentTime, OUT Key1, OUT Key2, OUT Data, OUT Timeout, OUT ElapsedOn, OUT ElapsesBy ) OR ( ElapsesBy > 0 ) THEN
         RETURN FALSE;
      ELSIF RemoveKey THEN
         Remove( Key1, Key2 );
      END;
      RETURN TRUE;
   END GetFirstElapsed;

//--------------------------------------------------------------------------------

   PRIVATE PROCEDURE GetFirstWithTimeout( CurrentTime : CARDINAL; OUT Key1, Key2 : PTR; OUT Data : PTR; OUT Timeout, ElapsesOn : CARDINAL; OUT ElapsesBy : CARDINAL ) : BOOLEAN;
   VAR
      TI : TPTimeoutableItem;
   BEGIN
      IF NOT GetFirst( 1, OUT TI ) THEN
         RETURN FALSE;
      END;
      ElapsesOn := CARDINAL( TI^.ElapsesOn >> 32 );
      IF ElapsesOn = Sync.FOREVER THEN
         RETURN FALSE;
      END;
      Key1 := TI^.Key1;
      Key2 := TI^.Key2;
      Data := TI^.Data;
      Timeout := TI^.Timeout;
      IF ElapsesOn <= CurrentTime THEN
         ElapsesBy := 0;
      ELSE
         ElapsesBy := ElapsesOn - CurrentTime;
      END;
      RETURN TRUE;
  END GetFirstWithTimeout;

//--------------------------------------------------------------------------------

BEGIN
  Counter := 0;
  KeyCount := 2;
END CTimeoutableTwoPtrMap;

//================================================================================

CLASS IMPLEMENTATION CTimeoutableTwoPtrMapIterator;

//--------------------------------------------------------------------------------

   PUBLIC READONLY PROPERTY CTimeoutableTwoPtrMapIterator.Key1 GET : PTR;
   BEGIN
      IF Current = NIL THEN
         RETURN NIL;
      ELSE
         RETURN TPTimeoutableItem( Current )^.Key1;
      END;
   END CTimeoutableTwoPtrMapIterator.Key1;

//---------------------------------------------------------------------------

   PUBLIC READONLY PROPERTY CTimeoutableTwoPtrMapIterator.Key2 GET : PTR;
   BEGIN
      IF Current = NIL THEN
         RETURN NIL;
      ELSE
         RETURN TPTimeoutableItem( Current )^.Key2;
      END;
   END CTimeoutableTwoPtrMapIterator.Key2;

//---------------------------------------------------------------------------

   PUBLIC READONLY PROPERTY CTimeoutableTwoPtrMapIterator.CurrentData GET : PTR;
   BEGIN
      IF Current = NIL THEN
         RETURN NIL;
      ELSE
         RETURN TPTimeoutableItem( Current )^.Data;
      END;
   END CTimeoutableTwoPtrMapIterator.CurrentData;

//---------------------------------------------------------------------------

   PUBLIC PROPERTY CTimeoutableTwoPtrMapIterator.CurrentData SET( Data : PTR );
   BEGIN
      IF _Current = NIL THEN
         RETURN;
      ELSE
         TPTimeoutableItem( Current )^.Data := Data;
      END;
   END CTimeoutableTwoPtrMapIterator.CurrentData;

//---------------------------------------------------------------------------

END CTimeoutableTwoPtrMapIterator;

//================================================================================

CLASS IMPLEMENTATION CTimeoutableTwoPtrMapSimplified;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE Add( CurrentTime : CARDINAL; Key : PTR; Data : PTR; Timeout : CARDINAL );
   BEGIN
      SUPER.Add( CurrentTime, Key, 0, Data, Timeout );
   END Add;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE Remove( Key : PTR );
   BEGIN
      SUPER.Remove( Key, 0 );
   END Remove;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE Contains( Key : PTR ) : BOOLEAN;
   BEGIN
      RETURN SUPER.Contains( Key, 0 );
   END Contains;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE GetFirstElapsed( CurrentTime : CARDINAL; RemoveKey : BOOLEAN; OUT Key : PTR; OUT Data : PTR ) : BOOLEAN;
   VAR
      Key2 : PTR;
      Timeout : CARDINAL;
      ElapsedOn : CARDINAL;
   BEGIN
      RETURN SUPER.GetFirstElapsed( CurrentTime, RemoveKey, OUT Key, OUT Key2, OUT Data, OUT Timeout, OUT ElapsedOn );
   END GetFirstElapsed;

//--------------------------------------------------------------------------------

END CTimeoutableTwoPtrMapSimplified;

//================================================================================

END TimeoutableTwoPtrMap.
