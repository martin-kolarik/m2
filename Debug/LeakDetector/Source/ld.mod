IMPLEMENTATION MODULE ld;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
  avltree,
  log,
  Storage,
  Strings,
  Sync,
  Tls,
  windows;

//================================================================================

CONST
  tracks = 12;
  
TYPE
  TTrackItem  = RECORD
                  Line   : CARDINAL;
                  Source : ARRAY [0..11] OF WCHAR;
                END;
  TTrackArray = ARRAY [0..tracks-1] OF TTrackItem;
  TTrack      = RECORD
                  Index : INTEGER;
                  Data  : TTrackArray;
                END;
  
CONST
  emptyTrack = TTrack( -1, TTrackArray(
    TTrackItem( 0, L'' ), TTrackItem( 0, L'' ), TTrackItem( 0, L'' ), TTrackItem( 0, L'' ),
    TTrackItem( 0, L'' ), TTrackItem( 0, L'' ), TTrackItem( 0, L'' ), TTrackItem( 0, L'' ),
    TTrackItem( 0, L'' ), TTrackItem( 0, L'' ), TTrackItem( 0, L'' ), TTrackItem( 0, L'' )
  ));
                            
//--------------------------------------------------------------------------------
  
CLASS CAllocation( avltree.CAVLTreeElem );
  PUBLIC VAR
    Track : TTrackArray;
    Block : PTR;
    Size  : CARDINAL;
  PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;

  PUBLIC OPERATOR NEW( size : CARDINAL ) : ADDRESS;
  PUBLIC OPERATOR DISPOSE( a : ADDRESS );                       
END CAllocation;

//--------------------------------------------------------------------------------
  
CLASS CFilter( avltree.CAVLTreeElem );
  PUBLIC VAR
    Name : ARRAY [0..7] OF WCHAR;

  PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;

  PUBLIC OPERATOR NEW( size : CARDINAL ) : ADDRESS;
  PUBLIC OPERATOR DISPOSE( a : ADDRESS );                       
END CFilter;

//--------------------------------------------------------------------------------
  
CLASS CLeakDetector;
  Running : BOOLEAN;
  Lock : Sync.LOCK;
  Allocations : avltree.CAVLTree;
  Filters : avltree.CAVLTree;
  LHeap : PTR;
  Log : log.CLogger;
  
  LOCAL PROCEDURE SwitchOn();
  LOCAL PROCEDURE SwitchOff();
  LOCAL PROCEDURE Reset();
  LOCAL PROCEDURE AddFilter( CONST Source : ARRAY OF WCHAR );
  LOCAL PROCEDURE RemoveFilter( CONST Source : ARRAY OF WCHAR );
  LOCAL PROCEDURE ResetFilters();

  LOCAL PROCEDURE Mark( Enter : BOOLEAN; CONST Source : ARRAY OF WCHAR; Line : CARDINAL );

  LOCAL PROCEDURE Allocate( CONST A : ADDRESS; CONST S : CARDINAL );
  LOCAL PROCEDURE Deallocate( CONST A : ADDRESS );
  LOCAL PROCEDURE Reallocate( CONST O, N : ADDRESS; CONST S : CARDINAL );
  
  LOCAL PROCEDURE iAllocate( size : CARDINAL ) : ADDRESS;
  LOCAL PROCEDURE iDeallocate( a : ADDRESS );
  
  FINALLY CLeakDetector();
END CLeakDetector;

//--------------------------------------------------------------------------------

TYPE
  TPAllocation = POINTER TO CAllocation;
  TPFilter = POINTER TO CFilter;

VAR
  LD : CLeakDetector;
  ThreadLocalStorage : Tls.TPIThreadLocalStorage := NIL;

//--------------------------------------------------------------------------------

CLASS IMPLEMENTATION CAllocation;

  PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;
  BEGIN
    IF Block > TPAllocation( pelem )^.Block THEN
      RETURN 1;
    ELSIF Block < TPAllocation( pelem )^.Block THEN
      RETURN -1;
    ELSE
      RETURN 0;
    END;
  END Compare;

  OPERATOR NEW( size : CARDINAL ) : ADDRESS;
  BEGIN
    RETURN LD.iAllocate( size );
  END NEW;

  OPERATOR DISPOSE( a : ADDRESS );
  BEGIN
    LD.iDeallocate( a );
  END DISPOSE;

BEGIN
  Track := emptyTrack.Data;
  Block := 0;
  Size := 0;
END CAllocation;
  
//--------------------------------------------------------------------------------

CLASS IMPLEMENTATION CFilter;

  PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;
  BEGIN
    RETURN Strings.CompareW( Name, TPFilter( pelem )^.Name );
  END Compare;

  OPERATOR NEW( size : CARDINAL ) : ADDRESS;
  BEGIN
    RETURN LD.iAllocate( size );
  END NEW;

  OPERATOR DISPOSE( a : ADDRESS );
  BEGIN
    LD.iDeallocate( a );
  END DISPOSE;

BEGIN
  Name[0] := 0W;
END CFilter;

//================================================================================
  
CLASS IMPLEMENTATION CLeakDetector;

//--------------------------------------------------------------------------------
  
  LOCAL PROCEDURE SwitchOn();
  BEGIN
    Running := TRUE;
  END SwitchOn;
  
//--------------------------------------------------------------------------------
  
  LOCAL PROCEDURE SwitchOff();
  BEGIN
    Running := FALSE;
  END SwitchOff;

//--------------------------------------------------------------------------------
  
  LOCAL PROCEDURE Reset();
  BEGIN
    Lock.Lock();
    Allocations.Dispose();
    Lock.Unlock();
  END Reset;
  
//--------------------------------------------------------------------------------
  
  LOCAL PROCEDURE AddFilter( CONST Source : ARRAY OF WCHAR );
  VAR
    F : TPFilter;
    LF : CFilter;
  BEGIN
    ASSIGN( LF.Name, Source );
    Lock.Lock();
    IF NOT Filters.Get( 0, ADR( LF ), OUT F ) THEN
      NEW( F );
      ASSIGN( F^.Name, Source );
      Filters.Add( F );
    END;
    Lock.Unlock();
  END AddFilter;

//--------------------------------------------------------------------------------
  
  LOCAL PROCEDURE RemoveFilter( CONST Source : ARRAY OF WCHAR );
  VAR
    F : TPFilter;
    LF : CFilter;
  BEGIN
    ASSIGN( LF.Name, Source );
    Lock.Lock();
    IF Filters.Remove( 0, ADR( LF ), OUT F ) THEN
      DISPOSE( F );
    END;
    Lock.Unlock();
  END RemoveFilter;

//--------------------------------------------------------------------------------
  
  LOCAL PROCEDURE ResetFilters();
  BEGIN
    Lock.Lock();
    Filters.Dispose();
    Lock.Unlock();
  END ResetFilters;

//--------------------------------------------------------------------------------
  
  LOCAL PROCEDURE Mark( Enter : BOOLEAN; CONST Source : ARRAY OF WCHAR; Line : CARDINAL );
  VAR
    Track : POINTER TO TTrack;
  BEGIN
    IF NOT Running THEN
      RETURN;
    END;

    Track := ThreadLocalStorage^.Value;
    IF Track = NIL THEN
      RETURN;
    END;

    IF Enter THEN
      IF Track^.Index < tracks-1 THEN
        INC( Track^.Index );
        ASSIGN( Track^.Data[Track^.Index].Source, Source );
        Track^.Data[Track^.Index].Line := Line;
      END;
    ELSE
      IF Track^.Index > -1 THEN
        Track^.Data[Track^.Index].Line := 0;
        DEC( Track^.Index );
      END;
    END;
  END Mark;

//--------------------------------------------------------------------------------
  
  LOCAL PROCEDURE Allocate( CONST A : ADDRESS; CONST S : CARDINAL );
  VAR
    AL : TPAllocation;
    F : TPFilter;
    LAL : CAllocation;
    LF : CFilter;
    Track : POINTER TO TTrack;
  BEGIN
    IF NOT Running THEN
      RETURN;
    END;

    Track := ThreadLocalStorage^.Value;
    IF Track = NIL THEN
      RETURN;
    ELSIF Track^.Index = -1 THEN
      Log.LogS( log.lcInfo, 0, L"", L"Allocation without mark" );
      RETURN;
    END;

    ASSIGN( LF.Name, Track^.Data[0].Source );
    Lock.Lock();
    IF Filters.Empty OR Filters.Get( 0, ADR( LF ), OUT F ) THEN
      LAL.Block := A;
      IF Allocations.Get( 0, ADR( LAL ), OUT AL ) THEN
        Log.LogSP( log.lcWarning, 0, L"", L"Duplicite allocation:", A );
      ELSE
        NEW( AL );
        AL^.Track := Track^.Data;
        AL^.Block := A;
        AL^.Size := S;
        Allocations.Add( AL );
      END;
    END;
    Lock.Unlock();
  END Allocate;
  
//--------------------------------------------------------------------------------
  
  LOCAL PROCEDURE Deallocate( CONST A : ADDRESS );
  VAR
    AL : TPAllocation;
    F : TPFilter;
    LAL : CAllocation;
    LF : CFilter;
    Track : POINTER TO TTrack;
  BEGIN
    IF NOT Running THEN
      RETURN;
    END;

    Track := ThreadLocalStorage^.Value;
    IF Track = NIL THEN
      RETURN;
    ELSIF Track^.Index = -1 THEN
      Log.LogS( log.lcInfo, 0, L"", L"Deallocation without mark" );
      RETURN;
    END;

    ASSIGN( LF.Name, Track^.Data[0].Source );
    Lock.Lock();
    IF Filters.Empty OR Filters.Get( 0, ADR( LF ), OUT F ) THEN
      LAL.Block := A;
      IF Allocations.Remove( 0, ADR( LAL ), OUT AL ) THEN
        DISPOSE( AL );
      ELSE
        Log.LogSP( log.lcWarning, 0, L"", L"Deallocation of unallocated memory:", A );
      END;
    END;
    Lock.Unlock();
  END Deallocate;
  
//--------------------------------------------------------------------------------
  
  LOCAL PROCEDURE Reallocate( CONST O, N : ADDRESS; CONST S : CARDINAL );
  VAR
    AL : TPAllocation;
    F : TPFilter;
    LAL : CAllocation;
    LF : CFilter;
    Track : POINTER TO TTrack;
  BEGIN
    IF NOT Running THEN
      RETURN;
    END;

    Track := ThreadLocalStorage^.Value;
    IF Track = NIL THEN
      RETURN;
    ELSIF Track^.Index = -1 THEN
      Log.LogS( log.lcInfo, 0, L"", L"Reallocation without mark" );
      RETURN;
    END;

    ASSIGN( LF.Name, Track^.Data[0].Source );
    Lock.Lock();
    IF Filters.Empty OR Filters.Get( 0, ADR( LF ), OUT F ) THEN
      // deallocate
      LAL.Block := O;
      IF O = NIL THEN
        // OK, first re/allocation
      ELSIF Allocations.Remove( 0, ADR( LAL ), OUT AL ) THEN
        DISPOSE( AL );
      ELSE
        Log.LogSP( log.lcWarning, 0, L"", L"Re/deallocation of unallocated memory:", O );
      END;
      // allocate
      LAL.Block := N;
      IF Allocations.Get( 0, ADR( LAL ), OUT AL ) THEN
        Log.LogSP( log.lcWarning, 0, L"", L"Duplicite re/allocation", N );
      ELSE
        NEW( AL );
        AL^.Track := Track^.Data;
        AL^.Block := N;
        AL^.Size := S;
        Allocations.Add( AL );
      END;
    END;
    Lock.Unlock();
  END Reallocate;
  
//--------------------------------------------------------------------------------
  
  LOCAL PROCEDURE iAllocate( size : CARDINAL ) : ADDRESS;
  VAR
    a : ADDRESS;
  BEGIN
    IF Storage.HeapAllocate( LHeap, OUT a, size ) THEN
      RETURN a;
    ELSE
      RETURN NIL;
    END;
  END iAllocate;

//--------------------------------------------------------------------------------
  
  LOCAL PROCEDURE iDeallocate( a : ADDRESS );
  BEGIN
    Storage.HeapDeallocate( LHeap, REF a );
  END iDeallocate;
  
//--------------------------------------------------------------------------------
  
  FINALLY CLeakDetector();
  VAR
    AL : TPAllocation;
    i : CARDINAL;
    N : ARRAY [0..31] OF WCHAR;
    S : ARRAY [0..255] OF WCHAR;
    b : BOOLEAN;
  BEGIN
    IF Running THEN
      Log.LogS( log.lcWarning, 0, L"", L"Start dumping of memory leaks" );
    END;

    b := Allocations.GetFirst( 0, OUT AL );
    WHILE b DO
      i := 0;
      WHILE ( i < tracks ) AND ( AL^.Track[i].Line <> 0 ) DO
        IF i = 0 THEN
          Strings.FromCARD32W( AL^.Size, 10, OUT S );
          Strings.AppendW( REF S, L' in ' );
        ELSE
          Strings.AppendW( REF S, L' -> ' );
        END;
        Strings.AppendW( REF S, AL^.Track[i].Source );
        Strings.AppendW( REF S, L'[' );
          Strings.FromCARD32W( AL^.Track[i].Line, 10, OUT N );
          Strings.AppendW( REF S, N );
        Strings.AppendW( REF S, L']' );
        INC( i );
      END; // WHILE
      Strings.FromCARD64W( CARD64( AL^.Block ), 16, OUT N );
      Log.LogSSSS( log.lcWarning, 0, L"", L"Leak of size", S, "at", N );
      
      b := Allocations.NextOf( 0, AL, OUT AL );
    END; // WHILE

    IF Running THEN
      Log.LogS( log.lcWarning, 0, L"", L"Stop dumping of memory leaks" );
    END;

    SwitchOff();
    Allocations.FINALLY(); // OK
    Filters.FINALLY(); // OK

    Storage.DisposeHeap( REF LHeap );
  END CLeakDetector;

//--------------------------------------------------------------------------------
  
BEGIN
  Running := TRUE;
  Storage.CreateHeap( OUT LHeap );
  Lock.Init( Sync.ltSpin, L"", FALSE );
  Log.SetName( "LD" );
  Log.Output := log.outsKernel;
  Log.Level := log.lcWarning;
END CLeakDetector;

//================================================================================
  
PROCEDURE SwitchOn();
BEGIN
  LD.SwitchOn();
END SwitchOn;

//--------------------------------------------------------------------------------
  
PROCEDURE SwitchOff();
BEGIN
  LD.SwitchOff();
END SwitchOff;

//--------------------------------------------------------------------------------
  
PROCEDURE Reset();
BEGIN
  LD.Reset();
END Reset;

//--------------------------------------------------------------------------------
  
PROCEDURE AddFilter( CONST Source : ARRAY OF WCHAR );
BEGIN
  LD.AddFilter( Source );
END AddFilter;

//--------------------------------------------------------------------------------
  
PROCEDURE RemoveFilter( CONST Source : ARRAY OF WCHAR );
BEGIN
  LD.RemoveFilter( Source );
END RemoveFilter;

//--------------------------------------------------------------------------------
  
PROCEDURE ResetFilters(); // unfiltered
BEGIN
  LD.ResetFilters();
END ResetFilters;

//--------------------------------------------------------------------------------
  
PROCEDURE Mark( Enter : BOOLEAN; CONST Source : ARRAY OF WCHAR; Line : CARDINAL );
BEGIN
  LD.Mark( Enter, Source, Line );
END Mark;
  
//--------------------------------------------------------------------------------
  
PROCEDURE AllocateHook( CONST A : ADDRESS; CONST S : CARDINAL );
BEGIN
  LD.Allocate( A, S );
END AllocateHook;

//--------------------------------------------------------------------------------
  
PROCEDURE DeallocateHook( CONST A : ADDRESS );
BEGIN
  LD.Deallocate( A );
END DeallocateHook;

//--------------------------------------------------------------------------------
  
PROCEDURE ReallocateHook( CONST O, N : ADDRESS; CONST S : CARDINAL );
BEGIN
  LD.Reallocate( O, N, S );
END ReallocateHook;

//================================================================================
  
PROCEDURE DllMain( Reason : CARDINAL ) : BOOLEAN;
VAR
  Track : POINTER TO TTrack;
BEGIN
  CASE Reason OF
  | windows.DLL_PROCESS_ATTACH :
    Tls.Create( OUT ThreadLocalStorage );

    Track := LD.iAllocate( SIZE( TTrack ));
    Track^ := emptyTrack;
    ThreadLocalStorage^.Value := Track;

  | windows.DLL_THREAD_ATTACH :
    Track := LD.iAllocate( SIZE( TTrack ));
    Track^ := emptyTrack;
    ThreadLocalStorage^.Value := Track;
  
  | windows.DLL_THREAD_DETACH :
    Track := ThreadLocalStorage^.Value;
    LD.iDeallocate( Track );

  | windows.DLL_PROCESS_DETACH :
    Track := ThreadLocalStorage^.Value;
    LD.iDeallocate( Track );

    Tls.Dispose( REF ThreadLocalStorage );
  END; // CASE

  RETURN TRUE;
END DllMain;

//================================================================================
  
END ld.