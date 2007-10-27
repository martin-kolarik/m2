IMPLEMENTATION MODULE drv_str;

//==============================================================
//
//  Dynamic String Library
//
//  version 1.0  (c) 2001, Moravian Instruments
//
//==============================================================

FROM Storage IMPORT
  ALLOCATE,
  REALLOCATE,
  DEALLOCATE;
  
IMPORT
  Strings;

//==============================================================
// DString helpers

PROCEDURE AllocDStrA( VAR PDStr : TPDStringA; InitSize : CARDINAL );
BEGIN
  ALLOCATE( PDStr, SIZE(CARDINAL) + SIZE(CARDINAL) + InitSize * SIZE( CHAR ));
  PDStr^.Size := InitSize;
  PDStr^.Len := 0;
END AllocDStrA;

PROCEDURE AllocDStrW( VAR PDStr : TPDStringW; InitSize : CARDINAL );
BEGIN
  ALLOCATE( PDStr, SIZE(CARDINAL) + SIZE(CARDINAL) + InitSize * SIZE( WCHAR ));
  PDStr^.Size := InitSize;
  PDStr^.Len := 0;
END AllocDStrW;

//--------------------------------------------------------------

PROCEDURE ReAllocDStrA( VAR PDStr : TPDStringA; InitSize : CARDINAL );
BEGIN
  IF PDStr = NIL THEN
    AllocDStrA( PDStr, InitSize );
  ELSE
    REALLOCATE( PDStr, SIZE(CARDINAL) + SIZE(CARDINAL) + InitSize * SIZE( CHAR ));
    PDStr^.Size := InitSize;
  END;
END ReAllocDStrA;

PROCEDURE ReAllocDStrW( VAR PDStr : TPDStringW; InitSize : CARDINAL );
BEGIN
  IF PDStr = NIL THEN
    AllocDStrW( PDStr, InitSize );
  ELSE
    REALLOCATE( PDStr, SIZE(CARDINAL) + SIZE(CARDINAL) + InitSize * SIZE( WCHAR ));
    PDStr^.Size := InitSize;
  END;
END ReAllocDStrW;

//--------------------------------------------------------------

PROCEDURE AllocDStrCopyA( VAR PDStr : TPDStringA; SrcDStr : TPDStringA );
BEGIN
  IF SrcDStr = NIL THEN
    PDStr := NIL;
    RETURN;
  END;
  ALLOCATE( PDStr, SIZE(CARDINAL) + SIZE(CARDINAL) + SrcDStr^.Size * SIZE( CHAR ));
  PDStr^.Size := SrcDStr^.Size;
  PDStr^.Len := SrcDStr^.Len;
  Strings.MoveA( ADR( SrcDStr^.Chars ), ADR( PDStr^.Chars ), SrcDStr^.Len );
END AllocDStrCopyA;

PROCEDURE AllocDStrCopyW( VAR PDStr : TPDStringW; SrcDStr : TPDStringW );
BEGIN
  IF SrcDStr = NIL THEN
    PDStr := NIL;
    RETURN;
  END;
  ALLOCATE( PDStr, SIZE(CARDINAL) + SIZE(CARDINAL) + SrcDStr^.Size * SIZE( WCHAR ));
  PDStr^.Size := SrcDStr^.Size;
  PDStr^.Len := SrcDStr^.Len;
  Strings.MoveW( ADR( SrcDStr^.Chars ), ADR( PDStr^.Chars ), SrcDStr^.Len );
END AllocDStrCopyW;

//--------------------------------------------------------------

PROCEDURE GetDStrAddrLenA( PDStr : TPDStringA; VAR a : ADDRESS; VAR l : CARDINAL );
BEGIN
  IF PDStr = NIL THEN
    a := NIL;
    l := 0;
  ELSE
    a := ADR( PDStr^.Chars );
    l := PDStr^.Len;
  END;
END GetDStrAddrLenA;

PROCEDURE GetDStrAddrLenW( PDStr : TPDStringW; VAR a : ADDRESS; VAR l : CARDINAL );
BEGIN
  IF PDStr = NIL THEN
    a := NIL;
    l := 0;
  ELSE
    a := ADR( PDStr^.Chars );
    l := PDStr^.Len;
  END;
END GetDStrAddrLenW;

//--------------------------------------------------------------

PROCEDURE EnsureDStrLenA( VAR PDStr : TPDStringA; NeededLen : CARDINAL; VAR a : ADDRESS; VAR l : CARDINAL );
BEGIN
  IF PDStr = NIL THEN
    AllocDStrA( PDStr, NeededLen );
    PDStr^.Len := 0;
  ELSIF PDStr^.Size < NeededLen THEN
    ReAllocDStrA( PDStr, NeededLen );
  END;
  a := ADR( PDStr^.Chars );
  l := PDStr^.Len;
END EnsureDStrLenA;

PROCEDURE EnsureDStrLenW( VAR PDStr : TPDStringW; NeededLen : CARDINAL; VAR a : ADDRESS; VAR l : CARDINAL );
BEGIN
  IF PDStr = NIL THEN
    AllocDStrW( PDStr, NeededLen );
    PDStr^.Len := 0;
  ELSIF PDStr^.Size < NeededLen THEN
    ReAllocDStrW( PDStr, NeededLen );
  END;
  a := ADR( PDStr^.Chars );
  l := PDStr^.Len;
END EnsureDStrLenW;

//--------------------------------------------------------------

PROCEDURE CopyStrToDStrA( VAR R : TPDStringA; S: ARRAY OF CHAR ); // R can be NIL !!!
VAR
  L : CARDINAL;
BEGIN
  L := LENGTH( S );
  IF (R = NIL) OR (L > R^.Size) THEN
    ReAllocDStrA( R, L );
  END;
  Strings.MoveA( ADR( S ), ADR( R^.Chars ), L );
  R^.Len := L;
END CopyStrToDStrA;

PROCEDURE CopyStrToDStrW( VAR R : TPDStringW; S: ARRAY OF WCHAR ); // R can be NIL !!!
VAR
  L : CARDINAL;
BEGIN
  L := LENGTH( S );
  IF (R = NIL) OR (L > R^.Size) THEN
    ReAllocDStrW( R, L );
  END;
  Strings.MoveW( ADR( S ), ADR( R^.Chars ), L );
  R^.Len := L;
END CopyStrToDStrW;

//--------------------------------------------------------------

PROCEDURE CopyDStrToStrA( VAR R: ARRAY OF CHAR; S : TPDStringA );
VAR
  H, L : CARDINAL;
BEGIN
  IF S = NIL THEN
    R[0] := CHAR( 0 );
    RETURN;
  END;
  H := HIGH( R ) + 1;
  L := S^.Len;
  IF L > H THEN
    L := H;
  END;
  Strings.MoveA( ADR( S^.Chars ), ADR( R ), L );
  IF L < H THEN
    R[L] := CHAR( 0 );
  END;
END CopyDStrToStrA;

PROCEDURE CopyDStrToStrW( VAR R: ARRAY OF WCHAR; S : TPDStringW );
VAR
  H, L : CARDINAL;
BEGIN
  IF S = NIL THEN
    R[0] := WCHAR( 0 );
    RETURN;
  END;
  H := HIGH( R ) + 1;
  L := S^.Len;
  IF L > H THEN
    L := H;
  END;
  Strings.MoveW( ADR( S^.Chars ), ADR( R ), L );
  IF L < H THEN
    R[L] := WCHAR( 0 );
  END;
END CopyDStrToStrW;

//--------------------------------------------------------------

PROCEDURE CopyDStrToDStrA( VAR R : TPDStringA; S: TPDStringA ); // R can be NIL !!!
BEGIN
  IF S = NIL THEN
    IF R <> NIL THEN
      DISPOSE( R );
    END;
    RETURN;
  END;
  IF (R = NIL) OR (S^.Len > R^.Size) THEN
    ReAllocDStrA( R, S^.Len );
  END;
  Strings.MoveA( ADR( S^.Chars ), ADR( R^.Chars ), S^.Len );
  R^.Len := S^.Len;
END CopyDStrToDStrA;

PROCEDURE CopyDStrToDStrW( VAR R : TPDStringW; S: TPDStringW ); // R can be NIL !!!
BEGIN
  IF S = NIL THEN
    IF R <> NIL THEN
      DISPOSE( R );
    END;
    RETURN;
  END;
  IF (R = NIL) OR (S^.Len > R^.Size) THEN
    ReAllocDStrW( R, S^.Len );
  END;
  Strings.MoveW( ADR( S^.Chars ), ADR( R^.Chars ), S^.Len );
  R^.Len := S^.Len;
END CopyDStrToDStrW;

//--------------------------------------------------------------

PROCEDURE U2A( dsw : TPDStringW; VAR dsa : TPDStringA );
VAR
  c      : CARDINAL;
  da, sa : ADDRESS;
  dl, sl : CARDINAL;
BEGIN
  GetDStrAddrLenW( dsw, sa, sl );
  IF ( sa = NIL ) OR ( sl = 0 ) THEN
    IF dsa <> NIL THEN
      DISPOSE( dsa );
    END;
  ELSE
    dl := sl;
    dsa := NIL;
    EnsureDStrLenA( dsa, dl, da, c ); // + 1 for 0C
    Strings.ToA( OA( sl-1, PWCHAR( sa )), 0, OUT OA( dl-1, PCHAR( da )));
    dsa^.Len := dl;
  END;
END U2A;

PROCEDURE A2U( dsa : TPDStringA; VAR dsw : TPDStringW );
VAR
  c      : CARDINAL;
  da, sa : ADDRESS;
  dl, sl : CARDINAL;
BEGIN
  GetDStrAddrLenA( dsa, sa, sl );
  IF ( sa = NIL ) OR ( sl = 0 ) THEN
    IF dsw <> NIL THEN
      DISPOSE( dsw );
    END;
  ELSE
    dl := sl;
    dsa := NIL;
    EnsureDStrLenW( dsw, dl, da, c ); // + 1 for 0C
    Strings.ToW( OA( sl-1, PCHAR( sa )), 0, OUT OA( dl-1, PWCHAR( da )));
    dsw^.Len := dl;
  END;
END A2U;

PROCEDURE CreateTFromUA( VAR d : TPDStringA; s : TPDStringW ) : BOOLEAN; // returns TRUE if D is newly allocated and should be after usage freed
BEGIN
  U2A( s, d );
  RETURN d <> NIL;
END CreateTFromUA;

PROCEDURE CreateTFromAA( VAR d : TPDStringA; s : TPDStringA ) : BOOLEAN; // returns TRUE if D is newly allocated and should be after usage freed
BEGIN
  d := s;
  RETURN FALSE;
END CreateTFromAA;

PROCEDURE CreateUFromTA( VAR d : TPDStringW; s : TPDStringA ) : BOOLEAN; // returns TRUE if D is newly allocated and should be after usage freed
BEGIN
  A2U( s, d );
  RETURN d <> NIL;
END CreateUFromTA;

PROCEDURE CreateAFromTA( VAR d : TPDStringA; s : TPDStringA ) : BOOLEAN; // returns TRUE if D is newly allocated and should be after usage freed
BEGIN
  d := s;
  RETURN FALSE;
END CreateAFromTA;

PROCEDURE CreateTFromUW( VAR d : TPDStringW; s : TPDStringW ) : BOOLEAN; // returns TRUE if D is newly allocated and should be after usage freed
BEGIN
  d := s;
  RETURN FALSE;
END CreateTFromUW;

PROCEDURE CreateTFromAW( VAR d : TPDStringW; s : TPDStringA ) : BOOLEAN; // returns TRUE if D is newly allocated and should be after usage freed
BEGIN
  A2U( s, d );
  RETURN d <> NIL;
END CreateTFromAW;

PROCEDURE CreateUFromTW( VAR d : TPDStringW; s : TPDStringW ) : BOOLEAN; // returns TRUE if D is newly allocated and should be after usage freed
BEGIN
  d := s;
  RETURN FALSE;
END CreateUFromTW;

PROCEDURE CreateAFromTW( VAR d : TPDStringA; s : TPDStringW ) : BOOLEAN; // returns TRUE if D is newly allocated and should be after usage freed
BEGIN
  U2A( s, d );
  RETURN d <> NIL;
END CreateAFromTW;

END drv_str.