IMPLEMENTATION MODULE ax_register;

// disable warning unary minus operator applied to unsigned type, result still unsigned
// (*# warn ( 4146 => off ) *)

FROM Storage IMPORT
  ALLOCATE, DEALLOCATE;

IMPORT
  oaidl,
  objbase,
  oleauto,
  olectl,
  registry,
  windows,
  winerror;

IMPORT
  FIO,
  Strings;

IMPORT
  ax_automation;

CONST
// strings
  keyCLSID                    = L'CLSID';
  keyInProcServer32           = L'InProcServer32';
  keyThreadingModel           = L'ThreadingModel';
  keyValueApartment           = L'Apartment';
  keyProgId                   = L'ProgId';
  keyVersionIndependentProgId = L'VersionIndependentProgId';
  keyTypeLib                  = L'TypeLib';
  keyProgrammable             = L'Programmable';
  keyControl                  = L'Control';
  keyCurVer                   = L'CurVer';

  // versions
  verTypeLibMajor             = 1;
  verTypeLibMinor             = 0;

(*===========================================================================*)
// common COM server DLL interface

PROCEDURE DllGetClassObject( CONST rclsid : guiddef.CLSID;
                             CONST riid   : guiddef.IID;
                               VAR ppv    : ADDRESS ) : wtypes.HRESULT;
BEGIN
  #if DEBUG #then
    ax_automation.DbgOutIID( L'GCO: ', NIL, riid );
  #endif
  RETURN ax_automation.CreateInterface( riid, ppv );
END DllGetClassObject;

(*---------------------------------------------------------------------------*)

PROCEDURE DllCanUnloadNow(): wtypes.HRESULT;
BEGIN
  IF ax_automation.UnloadAllowed() THEN
    RETURN winerror.S_OK;
  ELSE
    RETURN winerror.S_FALSE;
  END;
END DllCanUnloadNow;

(*---------------------------------------------------------------------------*)

PROCEDURE DllRegisterServer(): wtypes.HRESULT;
VAR
  ControlName : ARRAY [0..255] OF WCHAR;
  DLLName : ARRAY [0..255] OF WCHAR;
  hModule : windows.HANDLE;
  IID1, IID2, IIDx : guiddef.IID;
  CLSID1, CLSID2 : ARRAY [0..255] OF WCHAR;
  Path : FIO.PathStrW;
  PBSTR : wtypes.BSTR;
  PITypeLib : oaidl.TPITypeLib;
  ProgIdCommon : ARRAY [0..255] OF WCHAR;
  ProgIdCurrent : ARRAY [0..255] OF WCHAR;
  ProgIdVersion : CARDINAL;
  Registry : registry.CRegistry;
BEGIN
  IF ax_automation.GetClientConstructor() = NIL THEN
    RETURN olectl.SELFREG_E_CLASS;
  ELSE
    ax_automation.GetClientConstructor()^.QueryControlIIDs( IID1, IID2, IIDx, IIDx );
    objbase.StringFromIID( IID1, PBSTR );
    ASSIGN( CLSID1, OA( 255, PBSTR ));
    objbase.CoTaskMemFree( PBSTR );
    objbase.StringFromIID( IID2, PBSTR );
    ASSIGN( CLSID2, OA( 255, PBSTR ));
    objbase.CoTaskMemFree( PBSTR );

    ax_automation.GetClientConstructor()^.QueryControlNames( DLLName, ControlName, ProgIdCommon, ProgIdVersion );
    Strings.FromCARD32W( ProgIdVersion, 10, OUT ProgIdCurrent );
    Strings.PrependW( REF ProgIdCurrent, L'.' );
    Strings.PrependW( REF ProgIdCurrent, ProgIdCommon );
  END;

// create HKCR/CLSID/{clsidClassCWClusAdmExt}
  IF NOT Registry.Open( L'', registry.CLASSES_ROOT, keyCLSID ) THEN 
    RETURN olectl.SELFREG_E_CLASS;
  END;
  IF Registry.CreateSection( CLSID1 ) THEN
    Registry.SetKeyStr( L'', ControlName );
    Registry.Close();
  ELSE
    RETURN olectl.SELFREG_E_CLASS;
  END;

// forward entries
// HKCR/CLSID/{clsidClassCWClusAdmExt}/InProcServer32,ProgId,VersionIndependentProgId,TypeLib,Programmable
  Strings.ConcatW( OUT Path, keyCLSID, L'\' );
  Strings.AppendW( REF Path, CLSID1 );
  IF NOT Registry.Open( L'', registry.CLASSES_ROOT, Path ) THEN
    RETURN olectl.SELFREG_E_CLASS;
  END;
  // InProcServer32
  IF Registry.CreateSection( keyInProcServer32 ) THEN 
    hModule := windows.GetModuleHandleW( ADR( DLLName ));
    IF hModule = NIL THEN
      Path := L'';
    ELSE
      windows.GetModuleFileNameW( hModule, ADR( Path ), SIZE( Path ) DIV SIZE( WCHAR ));
    END;
    Registry.SetKeyStr( L'', Path );
  ELSE
    RETURN olectl.SELFREG_E_CLASS;
  END;
  // InProcServer32/ThreadingModel
  IF Registry.CreateSection( keyInProcServer32 ) THEN 
    Registry.SetKeyStr( keyThreadingModel, keyValueApartment );
  ELSE
    RETURN olectl.SELFREG_E_CLASS;
  END;
  // ProgId
  IF Registry.CreateSection( keyProgId ) THEN 
    Registry.SetKeyStr( L'', ProgIdCurrent );
  ELSE
    RETURN olectl.SELFREG_E_CLASS;
  END;
  // VersionIndependentProgId
  IF Registry.CreateSection( keyVersionIndependentProgId ) THEN 
    Registry.SetKeyStr( L'', ProgIdCommon );
  ELSE
    RETURN olectl.SELFREG_E_CLASS;
  END;
  // TypeLib
  IF Registry.CreateSection( keyTypeLib ) THEN 
    Registry.SetKeyStr( L'', CLSID2 );
  ELSE
    RETURN olectl.SELFREG_E_CLASS;
  END;

  // Programmable
  IF Registry.CreateSection( keyProgrammable ) THEN 
    Registry.Close();
  ELSE
    RETURN olectl.SELFREG_E_CLASS;
  END;

// cross reference entries
// HKCR/ProgIdCommon/CLSID,CurVer and HKCR/nameProIdCurrent/CLSID 
  IF NOT Registry.Open( L'', registry.CLASSES_ROOT, L'' ) THEN 
    RETURN olectl.SELFREG_E_CLASS;
  END;
  IF Registry.CreateSection( ProgIdCommon ) THEN 
    Registry.SetKeyStr( L'', ControlName );
    Registry.Close();
  ELSE
    RETURN olectl.SELFREG_E_CLASS;
  END;
  IF NOT Registry.Open( L'', registry.CLASSES_ROOT, ProgIdCommon ) THEN
    RETURN olectl.SELFREG_E_CLASS;
  END;

  // CLSID
  IF Registry.CreateSection( keyCLSID ) THEN
    Registry.SetKeyStr( L'', CLSID1 );
  ELSE
    RETURN olectl.SELFREG_E_CLASS;
  END;
  // CurVer
  IF Registry.CreateSection( keyCurVer ) THEN
    Registry.SetKeyStr( L'', ProgIdCurrent );
    Registry.Close();
  ELSE
    RETURN olectl.SELFREG_E_CLASS;
  END;

// HKCR/ProgIdCurrent/CLSID
  IF NOT Registry.Open( L'', registry.CLASSES_ROOT, L'' ) THEN 
    RETURN olectl.SELFREG_E_CLASS;
  END;
  IF Registry.CreateSection( ProgIdCurrent ) THEN 
    Registry.SetKeyStr( L'', ControlName );
    Registry.Close();
  ELSE
    RETURN olectl.SELFREG_E_CLASS;
  END;
  IF NOT Registry.Open( L'', registry.CLASSES_ROOT, ProgIdCurrent ) THEN
    RETURN olectl.SELFREG_E_CLASS;
  END;

  // CLSID
  IF Registry.CreateSection( keyCLSID ) THEN
    Registry.SetKeyStr( L'', CLSID1 );
    Registry.Close();
  ELSE
    RETURN olectl.SELFREG_E_CLASS;
  END;

// type library entries
  IF oleauto.LoadTypeLibEx( ADR( Path ), oleauto.REGKIND_NONE, PITypeLib ) = winerror.S_OK THEN
    oleauto.RegisterTypeLib( PITypeLib, ADR( Path ), NIL );
    PITypeLib^.Release();
    RETURN winerror.S_OK;
  ELSE
    RETURN olectl.SELFREG_E_TYPELIB;
  END;
END DllRegisterServer;

(*---------------------------------------------------------------------------*)

PROCEDURE DllUnregisterServer(): wtypes.HRESULT;
VAR
  CLSID1 : ARRAY [0..255] OF WCHAR;
  ControlName : ARRAY [0..255] OF WCHAR;
  DLLName : ARRAY [0..255] OF WCHAR;
  IID1, IID2, IIDx : guiddef.IID;
  PBSTR : wtypes.BSTR;
  ProgIdCommon : ARRAY [0..255] OF WCHAR;
  ProgIdCurrent : ARRAY [0..255] OF WCHAR;
  ProgIdVersion : CARDINAL;
  Registry : registry.CRegistry;
BEGIN
  IF ax_automation.GetClientConstructor() = NIL THEN
    RETURN olectl.SELFREG_E_CLASS;
  ELSE
    ax_automation.GetClientConstructor()^.QueryControlIIDs( IID1, IID2, IIDx, IIDx );
    objbase.StringFromIID( IID1, PBSTR );
    ASSIGN( CLSID1, OA( 255, PBSTR ));
    objbase.CoTaskMemFree( PBSTR );

    ax_automation.GetClientConstructor()^.QueryControlNames( DLLName, ControlName, ProgIdCommon, ProgIdVersion );
    Strings.FromCARD32W( ProgIdVersion, 10, OUT ProgIdCurrent );
    Strings.PrependW( REF ProgIdCurrent, L'.' );
    Strings.PrependW( REF ProgIdCurrent, ProgIdCommon );
  END;

// HKCR/CLSID/{clsidClassCWClusAdmExt}
  IF NOT Registry.Open( L'', registry.CLASSES_ROOT, keyCLSID ) THEN 
    RETURN olectl.SELFREG_E_CLASS;
  END;
  IF Registry.DeleteSection( CLSID1 ) THEN
    Registry.Close();
  ELSE
    RETURN olectl.SELFREG_E_CLASS;
  END;

// HKCR/ProgIdCommon
  IF NOT Registry.Open( L'', registry.CLASSES_ROOT, L'' ) THEN 
    RETURN olectl.SELFREG_E_CLASS;
  END;
  IF Registry.DeleteSection( ProgIdCommon ) THEN 
    Registry.Close();
  ELSE
    RETURN olectl.SELFREG_E_CLASS;
  END;

// HKCR/ProgIdCurrent/CLSID
  IF NOT Registry.Open( L'', registry.CLASSES_ROOT, L'' ) THEN 
    RETURN olectl.SELFREG_E_CLASS;
  END;
  IF Registry.DeleteSection( ProgIdCurrent ) THEN 
    Registry.Close();
  ELSE
    RETURN olectl.SELFREG_E_CLASS;
  END;

// type library entries
  IF oleauto.UnRegisterTypeLib( IID2, verTypeLibMajor, verTypeLibMinor, 0, oaidl.SYS_WIN32 ) = winerror.S_OK THEN
    RETURN winerror.S_OK;
  ELSE
    RETURN olectl.SELFREG_E_TYPELIB;
  END;
END DllUnregisterServer;

(*===========================================================================*)

END ax_register.
