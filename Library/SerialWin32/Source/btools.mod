IMPLEMENTATION MODULE btools;

(*# call( o_a_size=>on,
          o_a_copy=>off ),
    option( pack=>4 ) *)

FROM Storage IMPORT
  ALLOCATE, DEALLOCATE;

(* ================================================================ *)

CLASS IMPLEMENTATION CCircularBuffer;

  PUBLIC PROCEDURE Init( Size : CARDINAL );
  BEGIN
    IF PBuffer = NIL THEN
      BufferSize := Size;
      ALLOCATE( PBuffer, BufferSize );
    END;
  END Init;

  PUBLIC VIRTUAL PROCEDURE Release();
  BEGIN
    IF PBuffer <> NIL THEN
      BufferSize := 0;
      DISPOSE( PBuffer );
    END;
  END Release;

  PUBLIC PROCEDURE Purge();
  BEGIN
    Head := 0;
    Tail := 0;
    BufferFull := FALSE;
  END Purge;

  PUBLIC PROCEDURE PutBlock( a : ADDRESS; len : CARDINAL ) : BOOLEAN;
  VAR
    nFree  : CARDINAL;
    nChunk : CARDINAL;
    pb     : ADDRESS;
  BEGIN
    IF (PBuffer = NIL) OR (a = NIL) THEN
      RETURN FALSE;
    END;
    IF len = 0 THEN
      RETURN TRUE;
    END;
    nFree := GetFree();
    IF len > nFree THEN
      RETURN FALSE;
    END;
    IF Head >= Tail THEN
      nChunk := BufferSize - Head;
      IF nChunk > len THEN
        nChunk := len;
      END;
      pb := PBuffer; INC( pb, Head );
      windows.CopyMemory( pb, a, nChunk );
      INC( a, nChunk );
      DEC( len, nChunk );
      INC( Head, nChunk ); IF Head >= BufferSize THEN Head := 0; END;
    END;
    IF len <> 0 THEN
      nChunk := Tail - Head;
      IF nChunk > len THEN
        nChunk := len;
      END;
      pb := PBuffer; INC( pb, Head );
      windows.CopyMemory( pb, a, nChunk );
      //DEC( len, nChunk ); ...not necessary
      INC( Head, nChunk ); //IF Head >= BufferSize THEN Head := 0; END; ...not necessary
    END;
    BufferFull := Head = Tail;
    RETURN TRUE;
  END PutBlock;

  PROCEDURE PutBlockMin( a : ADDRESS; VAR len : CARDINAL ) : BOOLEAN;
  VAR
    nFree  : CARDINAL;
  BEGIN
    IF (PBuffer = NIL) OR (a = NIL) THEN
      RETURN FALSE;
    END;
    IF (len = 0) THEN
      RETURN TRUE;
    END;
    nFree := GetFree();
    IF len > nFree THEN
      len := nFree;
    END;
    IF PutBlock( a, len ) THEN
      RETURN TRUE;
    ELSE
      RETURN FALSE;
    END;
  END PutBlockMin;

  PUBLIC PROCEDURE QryPutBlock( VAR a1 : ADDRESS; VAR len1 : CARDINAL;
                                VAR a2 : ADDRESS; VAR len2 : CARDINAL ) : BOOLEAN;
  BEGIN
    IF BufferFull THEN
      len1 := 0;
      len2 := 0;
      RETURN TRUE;
    END;
    IF Head >= Tail THEN
      len1 := BufferSize - Head;
      IF len1 > 0 THEN
        a1 := PBuffer; INC( a1, Head );
      END;
      len2 := Tail;
      IF len2 > 0 THEN
        a2 := PBuffer;
      END;
    ELSE
      len1 := Tail - Head;
      IF len1 > 0 THEN
        a1 := PBuffer; INC( a1, Head );
      END;
      len2 := 0;
      a2 := NIL;
    END;
    RETURN TRUE;
  END QryPutBlock;

  PROCEDURE QryPutBlockContinuous( VAR a : ADDRESS; VAR len : CARDINAL ) : BOOLEAN;
  VAR
    da : ADDRESS;
    dl : CARDINAL;
  BEGIN
    RETURN QryPutBlock( a, len, da, dl );
  END QryPutBlockContinuous;

  PUBLIC PROCEDURE PutBlockCommit( len : CARDINAL ) : BOOLEAN;
  VAR
    nFree  : CARDINAL;
    nChunk : CARDINAL;
  BEGIN
    IF PBuffer = NIL THEN
      RETURN FALSE;
    END;
    IF len = 0 THEN
      RETURN TRUE;
    END;
    nFree := GetFree();
    IF len > nFree THEN
      RETURN FALSE;
    END;
    IF Head >= Tail THEN
      nChunk := BufferSize - Head;
      IF nChunk > len THEN
        nChunk := len;
      END;
      DEC( len, nChunk );
      INC( Head, nChunk ); IF Head >= BufferSize THEN Head := 0; END;
    END;
    IF len <> 0 THEN
      nChunk := Tail - Head;
      IF nChunk > len THEN
        nChunk := len;
      END;
      //DEC( len, nChunk ); ...not necessary
      INC( Head, nChunk ); //IF Head >= BufferSize THEN Head := 0; END; ...not necessary
    END;
    BufferFull := Head = Tail;
    RETURN TRUE;
  END PutBlockCommit;

  PUBLIC PROCEDURE GetBlock( a : ADDRESS; len : CARDINAL ) : BOOLEAN;
  VAR
    a1   : ADDRESS;
    n1   : CARDINAL;
    a2   : ADDRESS;
    n2   : CARDINAL;
  BEGIN
    IF (PBuffer = NIL) OR (a = NIL) THEN
      RETURN FALSE;
    END;
    IF len = 0 THEN
      RETURN TRUE;
    END;
    IF len > GetCount() THEN
      RETURN FALSE;
    END;
    IF QryGetBlock( a1, n1, a2, n2 ) THEN
      IF n1 > len THEN
        n1 := len;
      END;
      windows.CopyMemory( a, a1, n1 );
      DEC( len, n1 );
      IF len <> 0 THEN
        INC( a, n1 );
        IF n2 > len THEN
          n2 := len;
        END;
        windows.CopyMemory( a, a2, n2 );
      END;
      GetBlockCommit( n1 + n2 );
      RETURN TRUE;
    END;
    RETURN FALSE;
  END GetBlock;

  PUBLIC PROCEDURE QryGetBlock( VAR a1   : ADDRESS;
                                VAR len1 : CARDINAL;
                                VAR a2   : ADDRESS;
                                VAR len2 : CARDINAL ) : BOOLEAN;
  BEGIN
    IF PBuffer = NIL THEN
      RETURN FALSE;
    END;
    IF (Head <> Tail) OR BufferFull THEN
      a1 := PBuffer; INC( a1, Tail );
      IF Head <= Tail THEN
        len1 := BufferSize - Tail;
        IF Tail = 0 THEN
          a2 := NIL;
          len2 := 0;
        ELSE
          a2 := PBuffer;
          len2 := Head;
        END;
      ELSE // Head > Tail
        len1 := Head - Tail;
        a2 := NIL;
        len2 := 0;
      END;
      RETURN TRUE;
    END;
    RETURN FALSE;
  END QryGetBlock;

  PROCEDURE QryGetBlockContinuous( VAR a   : ADDRESS;
                                   VAR len : CARDINAL ) : BOOLEAN;
  VAR
    da : ADDRESS;
    dl : CARDINAL;
  BEGIN
    RETURN QryGetBlock( a, len, da, dl );
  END QryGetBlockContinuous;

  PROCEDURE QryGetBlockLen( RequiredLen : CARDINAL;
                            VAR a1   : ADDRESS;
                            VAR len1 : CARDINAL;
                            VAR a2   : ADDRESS;
                            VAR len2 : CARDINAL ) : BOOLEAN;
  VAR
    da1, da2 : ADDRESS;
    dl1, dl2 : CARDINAL;
    m        : CARDINAL;
  BEGIN
    IF QryGetBlock( da1, dl1, da2, dl2 ) THEN
      m := dl1 + dl2;
      IF m < RequiredLen THEN
        RETURN FALSE;
      ELSE // m >= RequiredLen
        IF dl1 >= RequiredLen THEN
          dl1 := RequiredLen;
          dl2 := 0;
          da2 := NIL;
        ELSE
          dl2 := RequiredLen - dl1;
        END;
        a1 := da1;
        len1 := dl1;
        a2 := da2;
        len2 := dl2;
        RETURN TRUE;
      END;
    END;
    RETURN FALSE;
  END QryGetBlockLen;

  PUBLIC PROCEDURE GetBlockCommit( len : CARDINAL ) : BOOLEAN;
  VAR
    m : CARDINAL;
  BEGIN
    IF (PBuffer = NIL) OR (len > GetCount()) THEN
      RETURN FALSE;
    END;
    IF len = 0 THEN
      RETURN TRUE;
    END;
    IF (Head <> Tail) OR BufferFull THEN
      IF Head <= Tail THEN
        m := BufferSize - Tail;
        IF m > len THEN
          m := len;
        END;
        INC( Tail, m ); IF Tail >= BufferSize THEN Tail := 0; END;
        DEC( len, m );
      END;
      IF len <> 0 THEN
        m := Head - Tail;
        IF m > len THEN
          m := len;
        END;
        INC( Tail, m ); //IF Tail >= BufferSize THEN Tail := 0; END; ...not necessary
        DEC( len, m );
      END;
      BufferFull := FALSE;
      IF ClearOnFree AND (Head = Tail) THEN
        Head := 0;
        Tail := 0;
      END;
      RETURN TRUE;
    END;
    RETURN FALSE;
  END GetBlockCommit;

  PROCEDURE IsEmpty() : BOOLEAN;
  BEGIN
    RETURN GetCount() = 0;
  END IsEmpty;

  PROCEDURE IsFull() : BOOLEAN;
  BEGIN
    RETURN BufferFull;
  END IsFull;

  PUBLIC PROCEDURE GetCount() : CARDINAL;
  VAR
    nCount : CARDINAL;
  BEGIN
    nCount := Head - Tail;
    IF (Head < Tail) OR BufferFull THEN
      INC( nCount, BufferSize );
    END;
    RETURN nCount;
  END GetCount;

  PUBLIC PROCEDURE GetFree() : CARDINAL;
  VAR
    nFree : CARDINAL;
  BEGIN
    nFree := Tail - Head;
    IF (Tail <= Head) AND NOT BufferFull THEN
      INC( nFree, BufferSize );
    END;
    RETURN nFree;
  END GetFree;

BEGIN
  PBuffer     := NIL;
  BufferSize  := 0;
  Head        := 0;
  Tail        := 0;
  BufferFull  := FALSE;
  ClearOnFree := FALSE;
END CCircularBuffer;

(* ================================================================ *)

CLASS IMPLEMENTATION CCircularBufferSync;

  PUBLIC VIRTUAL PROCEDURE Release();
  BEGIN
    CCircularBuffer.Release();
    IF MTLock THEN
      windows.DeleteCriticalSection( ADR( CS ));
      MTLock := FALSE;
    END;
  END Release;

  PROCEDURE Lock();
  BEGIN
    IF NOT MTLock THEN
      windows.InitializeCriticalSection( ADR( CS ));
      MTLock := TRUE;
    END;
    windows.EnterCriticalSection( ADR( CS ));
  END Lock;

  PROCEDURE Unlock();
  BEGIN
    IF MTLock THEN
      windows.LeaveCriticalSection( ADR( CS ));
    END;
  END Unlock;

BEGIN
  MTLock := FALSE;
  windows.FillMemory( ADR(CS), SIZE(CS), 0 );
END CCircularBufferSync;

(* ================================================================ *)

END btools.