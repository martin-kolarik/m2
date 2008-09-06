IMPLEMENTATION MODULE Storage;

//================================================================================

IMPORT
  windows;
  
#if DEBUG #then
  IMPORT
    // crtdbg,
    malloc;
#else
  VAR
    GHeap : windows.HANDLE;
#endif

//--------------------------------------------------------------------------------

INITIALLY __I();
BEGIN
  #if DEBUG #then
    // crtdbg._CrtSetDbgFlag( crtdbg._CRTDBG_CHECK_ALWAYS_DF OR crtdbg._CRTDBG_ALLOC_MEM_DF );
  #else
    GHeap := windows.GetProcessHeap();
  #endif  
END __I;

//================================================================================

PROCEDURE M2ALLOCATE( VAR a : ADDRESS; size : CARDINAL );
BEGIN
  IF size = 0 THEN
    a := NIL;
  ELSE
    #if DEBUG #then
      // ASSERT( malloc._heapchk() = malloc._HEAPOK );
      a := malloc.malloc( size );
    #else
      __I();
      a := windows.HeapAlloc( GHeap, 0, size );
    #endif
    // LeakSTART();
    LeakALLOCATE( a, size );
  END;
END M2ALLOCATE;

//--------------------------------------------------------------------------------

PROCEDURE M2DEALLOCATE( VAR a : ADDRESS );
BEGIN
  IF a = NIL THEN
    RETURN;
  ELSE
    LeakDEALLOCATE( a );
    #if DEBUG #then
      malloc.free( a );
      // ASSERT( malloc._heapchk() = malloc._HEAPOK );
    #else
      windows.HeapFree( GHeap, 0, a );
    #endif
  END;
  a := NIL;
END M2DEALLOCATE;

//--------------------------------------------------------------------------------

PROCEDURE M2REALLOCATE( VAR a : ADDRESS; size: CARDINAL );
VAR
  na : ADDRESS;
BEGIN
  #if DEBUG #then
    IF size = 0 THEN
      malloc.free( a ); na := NIL;
    ELSE
      // ASSERT( malloc._heapchk() = malloc._HEAPOK );
      na := malloc.realloc( a, size );
    END;
  #else
    __I();
    IF a = NIL THEN
      na := windows.HeapAlloc( GHeap, 0, size );
    ELSIF size = 0 THEN
      windows.HeapFree( GHeap, 0, a ); na := NIL;
    ELSE
      na := windows.HeapReAlloc( GHeap, 0, a, size );
    END;
  #endif
  // LeakSTART();
  LeakREALLOCATE( a, na, size );
  a := na;
END M2REALLOCATE;

//================================================================================

PROCEDURE Move( CONST Source : ADDRESS; Destination : ADDRESS; Length : CARDINAL );
BEGIN
  windows.MoveMemory( Destination, ADDRESS( Source ), Length );
END Move;

PROCEDURE Fill( Destination : ADDRESS; Length : CARDINAL; Value : BYTE );
BEGIN
  windows.FillMemory( Destination, Length, Value );
END Fill;

PROCEDURE Zero( Destination : ADDRESS; Length : CARDINAL );
BEGIN
  windows.ZeroMemory( Destination, Length );
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
