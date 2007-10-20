IMPLEMENTATION MODULE Registry;

FROM Storage IMPORT
  ALLOCATE, DEALLOCATE;

IMPORT
  windows,
  winerror,
  winreg;
  
IMPORT
  Strings;

//==========================================================

CLASS IMPLEMENTATION CRegistry;

  PUBLIC PROCEDURE OpenRead( CONST RemoteName : ARRAY OF WCHAR; Root : TRoot; CONST Path : ARRAY OF WCHAR ): BOOLEAN;
  BEGIN
    RETURN vfOpenRead( RemoteName, Root, Path );
  END OpenRead;

  PUBLIC PROCEDURE Open( CONST RemoteName : ARRAY OF WCHAR; Root : TRoot; CONST Path : ARRAY OF WCHAR ): BOOLEAN;
  BEGIN
    RETURN vfOpen( RemoteName, Root, Path );
  END Open;

  PUBLIC PROCEDURE Close();
  BEGIN
    vfClose();
  END Close;

  INTERNAL VIRTUAL PROCEDURE vfOpenRead( CONST RemoteName : ARRAY OF WCHAR; Root : TRoot; CONST Path : ARRAY OF WCHAR ): BOOLEAN;
  VAR
    CurrentRoot : winreg.HKEY;
    key1, key2 : winreg.HKEY;
    res : INTEGER;
    PMachine : ADDRESS;
  BEGIN
    #if DEBUG #then
      IF ( Root = LOCAL_MACHINE ) AND ( _al1 <> -1 ) THEN
        _al1 := TRISTATE( Root = LOCAL_MACHINE );
      END;
    #endif
    vfClose();
    CASE Root OF
    | LOCAL_MACHINE : CurrentRoot := winreg.HKEY_LOCAL_MACHINE;
    | CURRENT_USER : CurrentRoot := winreg.HKEY_CURRENT_USER;
    | CLASSES_ROOT : CurrentRoot := winreg.HKEY_CLASSES_ROOT;
    END; // CASE

    IF RemoteName[0] <> WCHAR(0) THEN
      PMachine := ADDRESS( ADR( RemoteName ));
    ELSE
      PMachine := NIL; // local machine
    END;
    IF PMachine = NIL THEN
      key1 := CurrentRoot;
      res := 0;
    ELSE
      res := winreg.RegConnectRegistry( PMachine, CurrentRoot, ADR( key1 ));
    END;
    IF res <> 0 THEN
      RETURN FALSE;
    END;

    res := winreg.RegOpenKeyExW( key1, ADR( Path ), 0, windows.KEY_READ, ADR( key2 ));
    IF res <> 0 THEN
      key2 := NIL;
    END;
    key1 := key2;
    CurrentKey := key1;
    CurrentSec := key1; 

    RETURN CurrentKey <> NIL;
  END vfOpenRead;

  INTERNAL VIRTUAL PROCEDURE vfOpen( CONST RemoteName : ARRAY OF WCHAR; Root : TRoot; CONST Path : ARRAY OF WCHAR ): BOOLEAN;
  VAR
    CurrentRoot : winreg.HKEY;
    key1, key2 : winreg.HKEY;
    res : INTEGER;
    PMachine : ADDRESS;
    s : ARRAY [0..511] OF WCHAR;
  BEGIN
    #if DEBUG #then
      IF ( Root = LOCAL_MACHINE ) AND ( _al1 <> -1 ) THEN
        _al1 := TRISTATE( Root = LOCAL_MACHINE );
      END;
      IF _al1 = 1 THEN
        Strings.ConcatW( OUT s, L"Zapisuješ do HKLM: ", Path );
        windows.MessageBoxW( NIL, ADR( s ), L"Pozor! Registry.Open", windows.MB_OK );
      END;
    #endif
    vfClose();
    CASE Root OF
    | LOCAL_MACHINE : CurrentRoot := winreg.HKEY_LOCAL_MACHINE;
    | CURRENT_USER : CurrentRoot := winreg.HKEY_CURRENT_USER;
    | CLASSES_ROOT : CurrentRoot := winreg.HKEY_CLASSES_ROOT;
    END; // CASE

    IF RemoteName[0] <> WCHAR(0) THEN
      PMachine := ADDRESS( ADR( RemoteName ));
    ELSE
      PMachine := NIL; // local machine
    END;
    IF PMachine = NIL THEN
      key1 := CurrentRoot;
      res  := 0;
    ELSE
      res := winreg.RegConnectRegistry( PMachine, CurrentRoot, ADR( key1 ));
    END;
    IF res <> 0 THEN
      RETURN FALSE;
    END;

    res := winreg.RegOpenKeyExW( key1, ADR( Path ), 0, windows.KEY_READ OR windows.KEY_WRITE, ADR( key2 ));
    IF res <> 0 THEN
      res := winreg.RegCreateKeyExW( key1, ADR( s ), 0, NIL, windows.REG_OPTION_NON_VOLATILE, windows.KEY_READ OR windows.KEY_WRITE, NIL, ADR( key2 ), NIL );
    END;
    IF res <> 0 THEN
      key2 := NIL;
    END;
    key1 := key2;
    CurrentKey := key1;
    CurrentSec := key1; 

    RETURN CurrentKey <> NIL;
  END vfOpen;

  INTERNAL VIRTUAL PROCEDURE vfClose();
  BEGIN
    IF ( CurrentSec <> NIL ) AND ( CurrentKey <> CurrentSec ) THEN
      winreg.RegCloseKey( CurrentSec );
    END;
    IF CurrentKey <> NIL THEN
      winreg.RegCloseKey( winreg.HKEY( CurrentKey ));
    END;
    CurrentKey := NIL;
    CurrentSec := NIL;
  END vfClose;

  INTERNAL VIRTUAL PROCEDURE GetKeyData( CONST Key : ARRAY OF WCHAR; PData : ADDRESS; OUT DataSize : CARDINAL; OUT RegType : CARDINAL ) : BOOLEAN;
  BEGIN
    RETURN winreg.RegQueryValueExW( CurrentSec, ADR( Key ), NIL, ADR( RegType ), PData, ADR( DataSize )) = 0;
  END GetKeyData;

  INTERNAL VIRTUAL PROCEDURE SetKeyData( CONST Key : ARRAY OF WCHAR; PData : ADDRESS; DataSize : CARDINAL; RegType : CARDINAL ) : BOOLEAN;
  BEGIN
    #if DEBUG #then
      IF _al1 = 1 THEN
        windows.MessageBoxW( NIL, ADR( Key ), L"Pozor! Zapisuješ do HKLM", windows.MB_OK );
      END;
    #endif
    RETURN winreg.RegSetValueExW( CurrentSec, ADR( Key ), 0, RegType, PData, DataSize ) = 0;
  END SetKeyData;

  PUBLIC PROCEDURE SetRootSection() : BOOLEAN;
  BEGIN
    IF ( CurrentSec <> NIL ) AND ( CurrentKey <> CurrentSec ) THEN
      winreg.RegCloseKey( CurrentSec );
    END;
    CurrentSec := CurrentKey;
    RETURN TRUE;
  END SetRootSection;

  PUBLIC PROCEDURE SetSection( CONST Section : ARRAY OF WCHAR ): BOOLEAN;
  VAR
    res : INTEGER;
  BEGIN
    IF ( CurrentSec <> NIL ) AND ( CurrentKey <> CurrentSec ) THEN
      winreg.RegCloseKey( CurrentSec );
    END;
    IF Section[0] = WCHAR(0) THEN
      CurrentSec := CurrentKey;
      RETURN TRUE;
    END;

    res := winreg.RegOpenKeyExW( winreg.HKEY( CurrentKey ), ADR( Section ), 0, windows.KEY_READ OR windows.KEY_WRITE, ADR( CurrentSec ));
    IF res <> 0 THEN
      res := winreg.RegOpenKeyExW( winreg.HKEY( CurrentKey ), ADR( Section ), 0, windows.KEY_READ, ADR( CurrentSec ));
    END;
    IF res <> 0 THEN
      CurrentSec := CurrentKey;
      RETURN FALSE;
    END;
    RETURN TRUE;
  END SetSection;

  PUBLIC PROCEDURE CreateSection( CONST Section : ARRAY OF WCHAR ): BOOLEAN;
  VAR
    res : INTEGER;
  BEGIN
    IF ( CurrentSec <> NIL ) AND ( CurrentKey <> CurrentSec ) THEN
      winreg.RegCloseKey( CurrentSec );
    END;
    res := winreg.RegCreateKeyExW( winreg.HKEY( CurrentKey ), ADR( Section ), 0, NIL, windows.REG_OPTION_NON_VOLATILE, windows.KEY_READ OR windows.KEY_WRITE, NIL, ADR( CurrentSec ), NIL );
    IF res <> 0 THEN
      CurrentSec := CurrentKey;
      RETURN FALSE;
    END;
    RETURN TRUE;
  END CreateSection;

  PUBLIC PROCEDURE ClearSection( CONST Section : ARRAY OF WCHAR ): BOOLEAN;

    PROCEDURE RemoveSubTree( HKey : winreg.HKEY ) : BOOLEAN;
    VAR
      s : ARRAY [0..255] OF WCHAR;
      key : winreg.HKEY;
      sl : CARDINAL;
    BEGIN
      sl := SIZE( s ) >> 1;
      WHILE winreg.RegEnumKeyExW( HKey, 0, ADR( s ), ADR( sl ), NIL, NIL, NIL, NIL ) = 0 DO
        IF winreg.RegOpenKeyExW( HKey, ADR( s ), 0, windows.KEY_READ OR windows.KEY_WRITE, ADR( key )) <> 0 THEN
          RETURN FALSE;
        ELSIF NOT RemoveSubTree( key ) THEN
          RETURN FALSE;
        END;
        winreg.RegCloseKey( key );

        IF winreg.RegDeleteKeyW( HKey, ADR( s )) <> 0 THEN
          RETURN FALSE;
        END;
        sl := SIZE( s ) >> 1;
      END;

      // added 10/07/2000 -- remove values
      // updated 31/01/2001 to remove also "Default" values (RegEnumValue returns value name length = 0)
      sl := SIZE( s ) DIV SIZE( WCHAR );
      WHILE winreg.RegEnumValueW( HKey, 0, ADR( s ), ADR( sl ), NIL, NIL, NIL, NIL ) = 0 DO
        // do not test sl
        winreg.RegDeleteValueW( HKey, ADR( s ));
        sl := SIZE( s ) DIV SIZE( WCHAR );
      END;
      RETURN TRUE;
    END RemoveSubTree;

  VAR
    b   : BOOLEAN;
    key : winreg.HKEY;
  BEGIN
    IF Section[0] = WCHAR(0) THEN
      key := winreg.HKEY( CurrentKey );
    ELSIF winreg.RegOpenKeyExW( winreg.HKEY( CurrentKey ), ADR( Section ), 0, windows.KEY_READ OR windows.KEY_WRITE, ADR( key )) <> 0 THEN
      RETURN FALSE;
    END;
    b := RemoveSubTree( key );
    IF key <> winreg.HKEY( CurrentKey ) THEN
      winreg.RegCloseKey( key );
    END;
    RETURN b;
  END ClearSection;

  PUBLIC PROCEDURE DeleteSection( CONST Section : ARRAY OF WCHAR ): BOOLEAN;
  BEGIN
    IF NOT ClearSection( Section ) THEN
      RETURN FALSE;
    ELSIF winreg.RegDeleteKeyW( winreg.HKEY( CurrentKey ), ADR( Section )) <> 0 THEN
      RETURN FALSE;
    ELSE
      RETURN TRUE;
    END;
  END DeleteSection;

  PUBLIC PROCEDURE DeleteKey( CONST Key : ARRAY OF WCHAR ) : BOOLEAN;
  BEGIN
    RETURN winreg.RegDeleteValueW( CurrentSec, ADR( Key )) = 0;
  END DeleteKey;

  PUBLIC PROCEDURE Enumerate( DoSections, DoKeys : BOOLEAN; REF EnumerateState : PTR; OUT Key : ARRAY OF WCHAR ) : BOOLEAN;
  VAR
    KeyHigh : CARDINAL;
    res : INTEGER;
  BEGIN
    IF EnumerateState = -1 THEN
      RETURN FALSE;
    ELSIF DoSections THEN
      KeyHigh := HIGH( Key ) + 1;
      res := winreg.RegEnumKeyExW( CurrentSec, windows.DWORD( LOPTRLONGWORD( EnumerateState )), ADR( Key ), ADR( KeyHigh ), NIL, NIL, NIL, NIL );
    ELSIF DoKeys THEN
      KeyHigh := HIGH( Key ) + 1;
      res := winreg.RegEnumValueW( CurrentSec, windows.DWORD( LOPTRLONGWORD( EnumerateState )), ADR( Key ), ADR( KeyHigh ), NIL, NIL, NIL, NIL );
    END;
    CASE res OF
    | winerror.ERROR_SUCCESS:
      INC( EnumerateState );
    | winerror.ERROR_NO_MORE_ITEMS:
      EnumerateState := -1;
    END;
    RETURN res = 0;
  END Enumerate;

  PUBLIC PROCEDURE GetKeyStr( CONST Key : ARRAY OF WCHAR; OUT V : ARRAY OF WCHAR ): BOOLEAN;
  VAR
    szlen : CARDINAL;
    vtype : CARDINAL;
    b : BOOLEAN;
  BEGIN
    szlen := ( HIGH( V ) + 1 ) << 1;
    vtype := windows.REG_SZ;
    b := GetKeyData( Key, ADR( V ), OUT szlen, OUT vtype ) AND ( vtype = windows.REG_SZ );
    IF b AND ( szlen = 0 ) THEN
      V[0] := WCHAR(0);
    END;
    RETURN b;
  END GetKeyStr;

  PUBLIC PROCEDURE GetKeyBool( CONST Key : ARRAY OF WCHAR; OUT V : BOOLEAN ): BOOLEAN;
  VAR
    dw : windows.DWORD;
    szlen : CARDINAL;
    vtype : CARDINAL;
    b : BOOLEAN;
  BEGIN
    szlen := SIZE( dw );
    vtype := windows.REG_DWORD;
    b := GetKeyData( Key, ADR( dw ), OUT szlen, OUT vtype ) AND ( vtype = windows.REG_DWORD ) AND ( szlen = SIZE( dw ));
    IF b THEN
      V := dw <> 0;
    END;
    RETURN b;
  END GetKeyBool;

  PUBLIC PROCEDURE GetKeyInt( CONST Key : ARRAY OF WCHAR; OUT V : INTEGER ): BOOLEAN;
  VAR
    I : INTEGER;
    szlen : CARDINAL;
    vtype : CARDINAL;
    b : BOOLEAN;
  BEGIN
    szlen := SIZE( I );
    vtype := windows.REG_DWORD;
    b := GetKeyData( Key, ADR( I ), OUT szlen, OUT vtype ) AND ( vtype = windows.REG_DWORD ) AND ( szlen = SIZE( I ));
    IF b THEN
      V := I;
    END;
    RETURN b;
  END GetKeyInt;

  PUBLIC PROCEDURE GetKeyReal( CONST Key : ARRAY OF WCHAR; OUT V : LONGREAL ): BOOLEAN;
  VAR
    szlen : CARDINAL;
    vtype : CARDINAL;
    r : LONGREAL;
    b : BOOLEAN;
  BEGIN
    szlen := SIZE( r );
    vtype := windows.REG_BINARY;
    b := GetKeyData( Key, ADR( r ), OUT szlen, OUT vtype ) AND ( vtype = windows.REG_BINARY ) AND ( szlen = SIZE( r ));
    IF b THEN
      V := r;
    END;
    RETURN b;
  END GetKeyReal;

  PUBLIC PROCEDURE GetKeyBin( CONST Key : ARRAY OF WCHAR; REF PData : ADDRESS; DataSize : CARDINAL; OUT DataLen : CARDINAL ): BOOLEAN;
  VAR
    vtype : CARDINAL;
  BEGIN
    vtype := windows.REG_BINARY;
    IF NOT GetKeyData( Key, PData, OUT DataSize, OUT vtype ) OR ( vtype <> windows.REG_BINARY ) THEN
      RETURN FALSE;
    END;
    DataLen := DataSize;
    RETURN TRUE;
  END GetKeyBin;

  PUBLIC PROCEDURE SetKeyStr( CONST Key : ARRAY OF WCHAR; CONST V : ARRAY OF WCHAR ): BOOLEAN;
  BEGIN
    RETURN SetKeyData( Key, ADR( V ), LENGTH( V ) << 1 + 2, windows.REG_SZ );
  END SetKeyStr;

  PUBLIC PROCEDURE SetKeyBool( CONST Key : ARRAY OF WCHAR; V : BOOLEAN ): BOOLEAN;
  VAR
    dw : LONGWORD;
  BEGIN
    dw := LONGWORD( V );
    RETURN SetKeyData( Key, ADR( dw ), SIZE( LONGWORD ), windows.REG_DWORD );
  END SetKeyBool;

  PUBLIC PROCEDURE SetKeyInt( CONST Key : ARRAY OF WCHAR; V : INTEGER ): BOOLEAN;
  BEGIN
    RETURN SetKeyData( Key, ADR( V ), SIZE( LONGWORD ), windows.REG_DWORD );
  END SetKeyInt;

  PUBLIC PROCEDURE SetKeyReal( CONST Key : ARRAY OF WCHAR; V : LONGREAL ): BOOLEAN;
  BEGIN
    RETURN SetKeyData( Key, ADR( V ), SIZE( V ), windows.REG_BINARY );
  END SetKeyReal;

  PUBLIC PROCEDURE SetKeyBin( CONST Key : ARRAY OF WCHAR; PData : ADDRESS; DataLen : CARDINAL ) : BOOLEAN;
  BEGIN
    RETURN SetKeyData( Key, PData, DataLen, windows.REG_BINARY );
  END SetKeyBin;
  
BEGIN
  CurrentKey := NIL;
  CurrentSec := NIL;
  Modified := FALSE;
  #if DEBUG #then
    _al1 := 0;
  #endif
FINALLY
  vfClose();
END CRegistry;

END Registry.
