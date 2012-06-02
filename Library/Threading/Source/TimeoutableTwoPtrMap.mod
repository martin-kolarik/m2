IMPLEMENTATION MODULE TimeoutableTwoPtrMap;

FROM Debug IMPORT
   AssertionW;

IMPORT
   Sync;
  
//================================================================================

// for debug purposes
TYPE
   // TStorage = CARD16;
   // TDifference = INT16;
   TStorage = CARDINAL;
   TDifference = INTEGER;

TYPE
  TPTimeoutableItem = POINTER TO CTimeoutableItem;

CLASS CTimeoutableItem( avltree.CAVLTreeElem2 );

   PUBLIC VAR
      // first key
      Key1, Key2 : PTR := 0;
      // second key
      ElapsesOn : TStorage := 0;
      Counter : TStorage;
      // data
      Data : PTR := 0;
      Timeout : TStorage := 0;

  PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;

  // OPERATOR NEW() : ADDRESS;
  // OPERATOR DISPOSE( a : ADDRESS );
END CTimeoutableItem;

//---------------------------------------------------------------------------

CLASS IMPLEMENTATION CTimeoutableItem;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;
   VAR
      difference : TDifference;
      pe : TPTimeoutableItem := TPTimeoutableItem( pelem );
   BEGIN
      IF i = 0 THEN
         IF Key1 < pe^.Key1 THEN
            RETURN -1;
         ELSIF Key1 > pe^.Key1 THEN
            RETURN 1;
         ELSIF Key2 < pe^.Key2 THEN
            RETURN -1;
         ELSIF Key2 > pe^.Key2 THEN
            RETURN 1;
         ELSE
            RETURN 0;
         END;
      ELSIF i = 1 THEN
         IF Timeout = TStorage( Sync.FOREVER ) THEN
            // fall down, compare only counters
         ELSE
            difference := ElapsesOn - pe^.ElapsesOn;
            IF difference < 0 THEN
               RETURN -1;
            ELSIF difference > 0 THEN
               RETURN 1;
            // ELSE -- fall down to compare counters
            END;
         END;
         // for same times compare creation 
         difference := Counter - pe^.Counter;
         IF difference < 0 THEN
            RETURN -1;
         ELSIF difference > 0 THEN
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
   Counter := 0;
END CTimeoutableItem;

//================================================================================

CLASS IMPLEMENTATION CTimeoutableTwoPtrMap;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE Add( CurrentTime : CARDINAL; Key1, Key2 : PTR; Data : PTR; Timeout : CARDINAL );
   VAR
      PI : TPTimeoutableItem;
   BEGIN
      IF TStorage( Timeout ) > MAX( TStorage ) DIV 2 THEN // timeout cannot be greater than a half of operated time range
         Timeout := Sync.FOREVER;
      END;

      NEW( PI );
      PI^.Key1 := Key1;
      PI^.Key2 := Key2;
      PI^.Data := Data;
      PI^.Timeout := TStorage( Timeout );
      IF Timeout = Sync.FOREVER THEN
         // do nothing
      ELSIF Timeout = 0 THEN
         PI^.ElapsesOn := TStorage( CurrentTime ) + 1;
      ELSE
         PI^.ElapsesOn := TStorage( CurrentTime + Timeout );
      END;
      PI^.Counter := TStorage( Counter );
      Insert( PI );
      INC( Counter );
   END Add;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE Remove( Key1, Key2 : PTR );
   VAR
      I : CTimeoutableItem;
   BEGIN
      I.Key1 := Key1;
      I.Key2 := Key2;
      Delete( 0, ADR( I ));
   END Remove;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE Contains( Key1, Key2 : PTR ) : BOOLEAN;
   VAR
      I : CTimeoutableItem;
   BEGIN
      I.Key1 := Key1;
      I.Key2 := Key2;
      RETURN SUPER.Contains( 0, ADR( I ));
   END Contains;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE Get( Key1, Key2 : PTR; OUT Data : PTR ) : BOOLEAN;
   VAR
      I : CTimeoutableItem;
      PI : TPTimeoutableItem;
   BEGIN
      I.Key1 := Key1;
      I.Key2 := Key2;
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
      elapsesBy : TDifference;
      TI : TPTimeoutableItem;
   BEGIN
      IF NOT GetFirst( 1, OUT TI ) THEN
         RETURN FALSE;
      ELSIF TI^.Timeout = TStorage( Sync.FOREVER ) THEN
         RETURN FALSE;
      END;
      Key1 := TI^.Key1;
      Key2 := TI^.Key2;
      Data := TI^.Data;
      elapsesBy := TI^.ElapsesOn - TStorage( CurrentTime );
      IF elapsesBy < 0 THEN // has already elapsed
         ElapsesBy := 0;
      ELSE
         ElapsesBy := CARDINAL( elapsesBy );
      END;
      Timeout := CARDINAL( TI^.Timeout );
      ElapsesOn := CARDINAL( TI^.ElapsesOn );
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

   PUBLIC READONLY PROPERTY CTimeoutableTwoPtrMapIterator.Value GET : PTR;
   BEGIN
      IF Current = NIL THEN
         RETURN NIL;
      ELSE
         RETURN TPTimeoutableItem( Current )^.Data;
      END;
   END CTimeoutableTwoPtrMapIterator.Value;

//---------------------------------------------------------------------------

   PUBLIC PROPERTY CTimeoutableTwoPtrMapIterator.Value SET( Data : PTR );
   BEGIN
      IF Current = NIL THEN
         RETURN;
      ELSE
         TPTimeoutableItem( Current )^.Data := Data;
      END;
   END CTimeoutableTwoPtrMapIterator.Value;

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
