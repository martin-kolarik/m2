IMPLEMENTATION MODULE TimeoutablePtrMap;

IMPORT
   Sync;
  
//================================================================================

TYPE
  TPTimeoutableItem = POINTER TO CTimeoutableItem;

CLASS CTimeoutableItem( avltree.CAVLTreeElem2 );
  PUBLIC VAR
    Key : QUADWORD;
    Data : PTR;
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
      IF Key < TPTimeoutableItem( pelem )^.Key THEN
        RETURN -1;
      ELSIF Key > TPTimeoutableItem( pelem )^.Key THEN
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
  Key := 0;
  Data := 0;
  ElapsesOn := 0;
END CTimeoutableItem;

//================================================================================

CLASS IMPLEMENTATION CTimeoutableQuadwordMap;

//--------------------------------------------------------------------------------

   PUBLIC READONLY PROPERTY CTimeoutableQuadwordMap.Current GET : QUADWORD;
   BEGIN
      IF _Current = -1 THEN
         RETURN 0;
      ELSE
         RETURN TPTimeoutableItem( _Current )^.Key;
      END;
   END CTimeoutableQuadwordMap.Current;

//---------------------------------------------------------------------------

   PUBLIC READONLY PROPERTY CTimeoutableQuadwordMap.CurrentData GET : PTR;
   BEGIN
      IF _Current = -1 THEN
         RETURN NIL;
      ELSE
         RETURN TPTimeoutableItem( _Current )^.Data;
      END;
   END CTimeoutableQuadwordMap.CurrentData;

//---------------------------------------------------------------------------

   PUBLIC PROPERTY CTimeoutableQuadwordMap.CurrentData SET( Data : PTR );
   BEGIN
      IF _Current = -1 THEN
         RETURN;
      ELSE
         TPTimeoutableItem( _Current )^.Data := Data;
      END;
   END CTimeoutableQuadwordMap.CurrentData;

//---------------------------------------------------------------------------

   PUBLIC PROCEDURE Add( CurrentTime : CARDINAL; Key : QUADWORD; Data : PTR; Timeout : CARDINAL );
   VAR
      PI : TPTimeoutableItem;
   BEGIN
      NEW( PI );
      PI^.Key := Key;
      PI^.Data := Data;
      IF Timeout = Sync.FOREVER THEN
         PI^.ElapsesOn := CARD64( Sync.FOREVER ) << 32 OR CARD64( Counter );
      ELSIF Timeout = 0 THEN
         PI^.ElapsesOn := CARD64( CurrentTime + 1 ) << 32 OR CARD64( Counter );
      ELSE
         PI^.ElapsesOn := CARD64( CurrentTime + Timeout ) << 32 OR CARD64( Counter );
      END;
      Insert( PI );
      INC( Counter );
   END Add;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE Remove( Key : QUADWORD );
   VAR
      I : CTimeoutableItem;
   BEGIN
      I.Key := Key;
      Delete( ADR( I ));
   END Remove;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE Contains( Key : QUADWORD ) : BOOLEAN;
   VAR
      I : CTimeoutableItem;
   BEGIN
      I.Key := Key;
      RETURN SUPER.Contains( ADR( I ));
   END Contains;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE Get( Key : QUADWORD; OUT Data : PTR ) : BOOLEAN;
   VAR
      I : CTimeoutableItem;
      PI : TPTimeoutableItem;
   BEGIN
      I.Key := Key;
      IF NOT Search( ADR( I ), OUT PI ) THEN
         RETURN FALSE;
      END;
      Data := PI^.Data;
      RETURN TRUE;  
   END Get;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE ElementByKeyAt( Index : CARDINAL; OUT Key : QUADWORD; OUT Data : PTR ) : BOOLEAN; // similar as []
   VAR
      PI : TPTimeoutableItem;
   BEGIN
      IF NOT OfIndexI( 0, Index, OUT PI ) THEN
         RETURN FALSE;
      ELSE
         Key := PI^.Key;
         Data := PI^.Data;
      END;
      RETURN TRUE;
   END ElementByKeyAt;
  
//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE ElementByTimeoutAt( Index : CARDINAL; OUT Key : QUADWORD; OUT Data : PTR ) : BOOLEAN; // similar as []
   VAR
      PI : TPTimeoutableItem;
   BEGIN
      IF NOT OfIndexI( 1, Index, OUT PI ) THEN
         RETURN FALSE;
      ELSE
         Key := PI^.Key;
         Data := PI^.Data;
      END;
      RETURN TRUE;
   END ElementByTimeoutAt;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE GetTimeoutToFirstElapsed( CurrentTime : CARDINAL ) : CARDINAL;
   VAR
      Key : QUADWORD;
      Data : PTR;
      Timeout : CARDINAL;
   BEGIN
      IF GetFirstWithTimeout( CurrentTime, OUT Key, OUT Data, OUT Timeout ) THEN
         RETURN Timeout;
      ELSE
         RETURN Sync.FOREVER;
      END;
   END GetTimeoutToFirstElapsed;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE GetFirstElapsed( CurrentTime : CARDINAL; RemoveKey : BOOLEAN; OUT Key : QUADWORD; OUT Data : PTR ) : BOOLEAN;
   VAR
      Timeout : CARDINAL;
   BEGIN
      IF NOT GetFirstWithTimeout( CurrentTime, OUT Key, OUT Data, OUT Timeout ) OR ( Timeout > 0 ) THEN
         RETURN FALSE;
      ELSIF RemoveKey THEN
         Remove( Key );
      END;
      RETURN TRUE;
   END GetFirstElapsed;

//--------------------------------------------------------------------------------

   PRIVATE PROCEDURE GetFirstWithTimeout( CurrentTime : CARDINAL; OUT Key : QUADWORD; OUT Data : PTR; OUT Timeout : CARDINAL ) : BOOLEAN;
   VAR
      ElapsesOn : CARDINAL;
      TI : TPTimeoutableItem;
   BEGIN
      IF NOT GetFirstI( 1, OUT TI ) THEN
         RETURN FALSE;
      END;
      ElapsesOn := CARDINAL( TI^.ElapsesOn >> 32 );
      IF ElapsesOn = Sync.FOREVER THEN
         RETURN FALSE;
      END;
      Key := TI^.Key;
      Data := TI^.Data;
      IF ElapsesOn <= CurrentTime THEN
         Timeout := 0;
      ELSE
         Timeout := ElapsesOn - CurrentTime;
      END;
      RETURN TRUE;
  END GetFirstWithTimeout;

//--------------------------------------------------------------------------------

BEGIN
  Counter := 0;
  Indexes := 2;
END CTimeoutableQuadwordMap;

//================================================================================

END TimeoutablePtrMap.
