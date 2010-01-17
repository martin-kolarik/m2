IMPLEMENTATION MODULE Storage;

//================================================================================

IMPORT
   windows;
  
VAR
   GHeap : windows.HANDLE := NIL;
   GPageSize : CARDINAL := 0;

//--------------------------------------------------------------------------------

INITIALLY __I();
VAR
	si : windows.SYSTEM_INFO;
BEGIN
   GHeap := windows.GetProcessHeap();

	Fill( ADR( si ), SIZE( si ), 0 );
	windows.GetSystemInfo( ADR( si ));
	GPageSize := si.dwPageSize;
END __I;

PROCEDURE PageSize() : CARDINAL;
BEGIN
   __I();
   RETURN GPageSize;
END PageSize;
	
//================================================================================

PROCEDURE M2ALLOCATE( OUT a : ADDRESS; size : CARDINAL );
BEGIN
   __I();
   HeapAllocate( GHeap, OUT a, size );
END M2ALLOCATE;

//--------------------------------------------------------------------------------

PROCEDURE M2DEALLOCATE( OUT a : ADDRESS );
BEGIN
   HeapDeallocate( GHeap, OUT a );
END M2DEALLOCATE;

//--------------------------------------------------------------------------------

PROCEDURE M2REALLOCATE( REF a : ADDRESS; size: CARDINAL );
BEGIN
   __I();
   HeapReallocate( GHeap, REF a, size );
END M2REALLOCATE;

(*================================================================================*)

PROCEDURE CreateHeap( OUT Heap : PTR ) : BOOLEAN;
BEGIN
   Heap := windows.HeapCreate( 0, 0, 0 );
   RETURN Heap <> NIL;
END CreateHeap;

(*--------------------------------------------------------------------------------*)

PROCEDURE DisposeHeap( OUT Heap : PTR );
BEGIN
   IF Heap = NIL THEN
      RETURN;
   END;
   windows.HeapDestroy( Heap );
   Heap := NIL;
END DisposeHeap;

(*--------------------------------------------------------------------------------*)

PROCEDURE HeapAllocate( Heap : PTR; OUT a : ADDRESS; size : CARDINAL ) : BOOLEAN;
BEGIN
   IF Heap = NIL THEN
      RETURN FALSE;
   ELSIF size = 0 THEN
      a := NIL;
   ELSE
      a := windows.HeapAlloc( Heap, 0, size );
      IF a = NIL THEN
         RETURN FALSE;
      END;
      LeakALLOCATE( a, size );
   END;
   RETURN TRUE;
END HeapAllocate;

(*--------------------------------------------------------------------------------*)

PROCEDURE HeapDeallocate( Heap : PTR; OUT a : ADDRESS ) : BOOLEAN;
BEGIN
   IF ( a = NIL ) OR ( Heap = NIL ) THEN
      RETURN FALSE;
   ELSE
      LeakDEALLOCATE( a );
      windows.HeapFree( Heap, 0, a );
      a := NIL;
      RETURN TRUE;
   END;
END HeapDeallocate;

(*--------------------------------------------------------------------------------*)

PROCEDURE HeapReallocate( Heap : PTR; REF a : ADDRESS; size : CARDINAL ) : BOOLEAN;
VAR
   na : ADDRESS;
BEGIN
   IF Heap = NIL THEN
      RETURN FALSE;
   ELSIF a = NIL THEN
      na := windows.HeapAlloc( Heap, 0, size );
      IF na = NIL THEN
         RETURN FALSE;
      END;
   ELSIF size = 0 THEN
      windows.HeapFree( Heap, 0, a );
      na := NIL;
   ELSE
      na := windows.HeapReAlloc( Heap, 0, a, size );
      IF na = NIL THEN
         RETURN FALSE;
      END;
   END;
   LeakREALLOCATE( a, na, size );
   a := na;
   RETURN TRUE;
END HeapReallocate;

(*================================================================================*)

PROCEDURE Move( CONST source : ADDRESS; destination : ADDRESS; length : CARDINAL );
VAR
   termination : ADDRESS := INC( source, length );
BEGIN
   IF length = 0 THEN
      RETURN;

   ELSIF ( PTR( destination ) < PTR( source )) OR ( PTR( destination ) > PTR( termination )) THEN // blocks do not overlap for upward moving
      WHILE source <> termination DO
         PBYTE( destination )^ := PBYTE( source )^;
         INC( source );
         INC( destination );
      END; // WHILE

   ELSE // move downwards
      INC( destination, length-1 );
      WHILE source <> termination DO
         DEC( termination );
         PBYTE( destination )^ := PBYTE( termination )^;
         DEC( destination );
      END; // WHILE

   END;
END Move;

PROCEDURE Fill( destination : ADDRESS; length : CARDINAL; value : BYTE );
VAR
   termination : ADDRESS := INC( destination, length );
BEGIN
   WHILE destination <> termination DO
      PBYTE( destination )^ := value;
      INC( destination );
   END;
END Fill;

PROCEDURE Zero( destination : ADDRESS; length : CARDINAL );
VAR
   termination : ADDRESS := INC( destination, length );
BEGIN
   WHILE destination <> termination DO
      PBYTE( destination )^ := 0;
      INC( destination );
   END;
END Zero;

PROCEDURE Equals( CONST Source, Destination : ADDRESS; Length : CARDINAL ) : BOOLEAN;
VAR
   Termination : ADDRESS;
BEGIN
   Termination := INC( Source, Length );
   LOOP
      IF Source = Termination THEN
         RETURN TRUE;
      ELSIF PBYTE( Source )^ <> PBYTE( Destination )^ THEN
         RETURN FALSE;
      ELSE
         INC( Source );
         INC( Destination );
      END;
   END; // LOOP
END Equals;

//================================================================================

END Storage.
