IMPLEMENTATION MODULE ax_automation;
(*# option( pack => 8 ) *)

FROM Storage IMPORT
  ALLOCATE, DEALLOCATE;
  
FROM Debug IMPORT
   AssertionW;

IMPORT
  windows;

IMPORT
  objbase,
  ocidl,
  oleauto,
  olectl,
  winerror;

IMPORT
  collection,
  FIO,
  Strings;

(*===========================================================================*)

PROCEDURE GetTypeLib( VAR PITypeLib : oaidl.TPITypeLib ) : wtypes.HRESULT; FORWARD;

(*===========================================================================*)

TYPE
  TPDLLConstructor = POINTER TO CDLLConstructor;

(*---------------------------------------------------------------------------*)

(*# save, call( convention => stdcall ) *)

CLASS CDLLConstructor( CInterface );
  DLLName           : FIO.PathStrW;
  PConstructor      : TPAbstractClientConstructor;
  PITypeLibSelf     : oaidl.TPITypeLib;
  InterfaceCount    : CARDINAL;
  InsideConstructor : BOOLEAN;

  // IUnknown
  PUBLIC VIRTUAL PROCEDURE QueryInterface( CONST riid : guiddef.IID; ppvObject : PADDRESS ) : wtypes.HRESULT;
  PUBLIC VIRTUAL PROCEDURE Release() : windows.ULONG;

  LOCAL PROCEDURE RegisterConstructor( PConstructor : TPAbstractClientConstructor );
  LOCAL PROCEDURE ForgetConstructor();

  LOCAL PROCEDURE RemoveInterface( PInterface : TPInterface ) : BOOLEAN;
  LOCAL PROCEDURE IsEmpty() : BOOLEAN;
END CDLLConstructor;

(*===========================================================================*)

TYPE
  TPIProvideClassInfo     = POINTER TO CIProvideClassInfo;
  TPPIConnectionPoint     = POINTER TO TPIConnectionPoint;
  TPIEnumConnectionPoints = POINTER TO CIEnumConnectionPoints;

CLASS CIProvideClassInfo( CInterface );
  PDLLConstructor : TPDLLConstructor;
  PUBLIC VIRTUAL PROCEDURE GetClassInfo( VAR ppTI : oaidl.TPITypeInfo ) : wtypes.HRESULT;
END CIProvideClassInfo;

(*---------------------------------------------------------------------------*)

TYPE
  TPConnectionPoint = POINTER TO CConnectionPoint;

CLASS CConnectionPoint( list.CListElem );
  IConnectionPoint : CIConnectionPoint;
END CConnectionPoint;

(*---------------------------------------------------------------------------*)

CLASS CIEnumConnectionPoints( CInterface );
   PRIVATE VAR
      Iterator : list.CListIterator;

   PUBLIC PROCEDURE Init( CONST ConnectionPoints : collection.ICollection );

  PUBLIC VIRTUAL PROCEDURE Next( celt : windows.ULONG; rgelt : TPPIConnectionPoint; pceltFetched : windows.PULONG ) : wtypes.HRESULT;
  PUBLIC VIRTUAL PROCEDURE Skip( celt : windows.ULONG ) : wtypes.HRESULT;
  PUBLIC VIRTUAL PROCEDURE Reset() : wtypes.HRESULT;
  PUBLIC VIRTUAL PROCEDURE Clone( VAR ppenum : TPIEnumConnectionPoints ) : wtypes.HRESULT;
END CIEnumConnectionPoints;

(*# restore *)

(*---------------------------------------------------------------------------*)

TYPE
  TPAdvisedClient = POINTER TO CAdvisedClient;

CLASS CAdvisedClient( list.CListElem );
  PClient          : unknwn.TPIUnknown;
  PIDispatch_Event : oaidl.TPIDispatch;
END CAdvisedClient;

(*---------------------------------------------------------------------------*)

(*# save, call( convention => stdcall ) *)

CLASS CIEnumConnections( CInterface );
   PRIVATE VAR
      Iterator : list.CListIterator;

   PUBLIC PROCEDURE Init( CONST AdvisedClients : collection.ICollection );

  PUBLIC VIRTUAL PROCEDURE Next( cConnections : windows.ULONG; rgpcd : ocidl.PCONNECTDATA; pcFetched : windows.PULONG ) : wtypes.HRESULT;
  PUBLIC VIRTUAL PROCEDURE Skip( cConnections : windows.ULONG ) : wtypes.HRESULT;
  PUBLIC VIRTUAL PROCEDURE Reset() : wtypes.HRESULT;
  PUBLIC VIRTUAL PROCEDURE Clone( VAR ppenum : TPIEnumConnections ) : wtypes.HRESULT;
END CIEnumConnections;

(*# restore *)

(*===========================================================================*)

CLASS IMPLEMENTATION CInterface;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE QueryInterface( CONST riid : guiddef.IID; ppvObject : PADDRESS ) : wtypes.HRESULT;
  BEGIN
    IF ppvObject = NIL THEN 
      RETURN winerror.E_INVALIDARG;
    ELSIF riid = unknwn.IID_IUnknown THEN
      AddRef();
      ppvObject^ := ADR( SELF );
      RETURN winerror.S_OK;
    ELSIF PInterfaceFactory = NIL THEN
      RETURN winerror.E_NOTIMPL;
    ELSE
      RETURN PInterfaceFactory^.QueryInterface( riid, ppvObject );
    END;
  END QueryInterface;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE AddRef() : windows.ULONG;
  BEGIN
(*%T DEBUG *)
    DbgOutADD( ADR( SELF ));
(*%E DEBUG *)
    INC( ReferenceCount );
    RETURN windows.ULONG( ReferenceCount );
  END AddRef;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE Release() : windows.ULONG;
  VAR
    a : ADDRESS;
  BEGIN
(*%T DEBUG *)
    DbgOutREL( ADR( SELF ));
(*%E DEBUG *)
      IF ReferenceCount = 0 THEN
         ASSERTLOG( FALSE, L"RefCount = 0, already released" );
         RETURN 0;
      END;
    DEC( ReferenceCount );
    IF ReferenceCount <> 0 THEN
      RETURN windows.ULONG( ReferenceCount );
    ELSE
      a := ADR( SELF );
      DISPOSE( a );
      RETURN 0;
    END;
  END Release;

(*---------------------------------------------------------------------------*)

BEGIN
  IID := unknwn.IID_IUnknown;
  PInterfaceFactory := NIL;
  ReferenceCount := 0;
END CInterface;

(*===========================================================================*)

CLASS IMPLEMENTATION CDLLConstructor;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE QueryInterface( CONST riid : guiddef.IID; ppvObject : PADDRESS ) : wtypes.HRESULT;
  VAR
    HR : wtypes.HRESULT;
    PAX : TPActiveXControl;
    PInterface : TPInterface;
    AddRefFlag : BOOLEAN;
  BEGIN
    IF InsideConstructor THEN
      RETURN winerror.E_NOTIMPL;
    END;

    #if DEBUG #then
      DbgOutIID( L'DFQ: ', ADR( SELF ), riid );
    #endif

    AddRefFlag := TRUE;
    IF riid = unknwn.IID_IUnknown THEN
      NEW( PInterface );
    ELSIF ( riid = unknwn.IID_IClassFactory ) AND ( PConstructor <> NIL ) THEN
      HR := PConstructor^.CreateInstance( PAX );
      IF HR = winerror.S_OK THEN
        PAX^.PDLLConstructor := ADR( SELF );
        PInterface := PAX;
      ELSE
        RETURN HR;
      END;

    #if DEBUG #then
      DbgOutSP( L'PAX: ', PAX );
    #endif

      AddRefFlag := FALSE;
    ELSIF riid = ocidl.IID_IProvideClassInfo THEN
      NEW( TPIProvideClassInfo( PInterface ));
      TPIProvideClassInfo( PInterface )^.PDLLConstructor := ADR( SELF );
    ELSE
      RETURN winerror.E_NOTIMPL;
    END;

    INC( InterfaceCount );
    IF AddRefFlag THEN
      PInterface^.AddRef();
    END;
    IF PInterface^.PInterfaceFactory = NIL THEN
      PInterface^.PInterfaceFactory := ADR( SELF );
    END;
    ppvObject^ := PInterface;

    RETURN winerror.S_OK;
  END QueryInterface;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE Release() : windows.ULONG;
  BEGIN
    IF ReferenceCount = 1 THEN
      IF PConstructor <> NIL THEN
        PConstructor := NIL;
      END;
      IF PITypeLibSelf <> NIL THEN
        PITypeLibSelf^.Release();
        PITypeLibSelf := NIL;
      END;
    END;
    RETURN SUPER.Release();
  END Release;

(*---------------------------------------------------------------------------*)

  LOCAL PROCEDURE RegisterConstructor( _PConstructor : TPAbstractClientConstructor );
  VAR
    c : CARDINAL;
    hModule : windows.HANDLE;
    Path : FIO.PathStrW;
    s : ARRAY [0..3] OF WCHAR;
  BEGIN
    PConstructor := _PConstructor;
    IF PITypeLibSelf <> NIL THEN
      PITypeLibSelf^.Release();
      PITypeLibSelf := NIL;
    END;
    PConstructor^.QueryControlNames( DLLName, s, s, c );
    IF DLLName[0] = WCHAR( 0 ) THEN
      RETURN;
    END;
    hModule := windows.GetModuleHandleW( ADR( DLLName ));
    IF hModule = NIL THEN
      RETURN;
    ELSIF windows.GetModuleFileNameW( hModule, ADR( Path ), SIZE( Path ) DIV SIZE( WCHAR )) = 0 THEN
      RETURN;
    ELSE
      oleauto.LoadTypeLibEx( ADR( Path ), oleauto.REGKIND_NONE, PITypeLibSelf );
    END;
  END RegisterConstructor;

(*---------------------------------------------------------------------------*)

  LOCAL PROCEDURE ForgetConstructor();
  BEGIN
    IF PConstructor <> NIL THEN
      PConstructor := NIL;
    END;
    IF PITypeLibSelf <> NIL THEN
      PITypeLibSelf^.Release();
      PITypeLibSelf := NIL;
    END;
    DLLName[0] := WCHAR( 0 );
  END ForgetConstructor;

(*---------------------------------------------------------------------------*)

  LOCAL PROCEDURE RemoveInterface( PInterface : TPInterface ) : BOOLEAN;
  BEGIN
    DEC( InterfaceCount );
    RETURN InterfaceCount = 0;
  END RemoveInterface;

(*---------------------------------------------------------------------------*)

  LOCAL PROCEDURE IsEmpty() : BOOLEAN;
  BEGIN
    RETURN InterfaceCount = 0;
  END IsEmpty;

(*---------------------------------------------------------------------------*)

BEGIN
  DLLName := L'';
  PITypeLibSelf := NIL;
  PConstructor := NIL;
  InterfaceCount := 0;
  InsideConstructor := FALSE;
  AddRef();
  AddRef();
END CDLLConstructor;

(*===========================================================================*)

CLASS IMPLEMENTATION CIProvideClassInfo;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE GetClassInfo( VAR ppTI : oaidl.TPITypeInfo ) : wtypes.HRESULT;
  VAR
    IID, IIDx : guiddef.IID;
  BEGIN
    IF PDLLConstructor^.PITypeLibSelf = NIL THEN
      RETURN winerror.E_UNEXPECTED;
    ELSE
      GetClientConstructor()^.QueryControlIIDs( IID, IIDx, IIDx, IIDx );
      RETURN PDLLConstructor^.PITypeLibSelf^.GetTypeInfoOfGuid( IID, ppTI );
    END;
  END GetClassInfo;

(*---------------------------------------------------------------------------*)

BEGIN
  IID := ocidl.IID_IProvideClassInfo;
  PDLLConstructor := NIL;
END CIProvideClassInfo;

(*===========================================================================*)

CLASS IMPLEMENTATION CIDispatch;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE GetTypeInfoCount( pctinfo : windows.PUINT ): wtypes.HRESULT;
  BEGIN
    IF pctinfo = NIL THEN
      RETURN winerror.E_NOTIMPL;
    ELSIF PITypeInfoSelf = NIL THEN
      pctinfo^ := 0;
    ELSE
      pctinfo^ := 1;
    END;
    RETURN winerror.S_OK;
  END GetTypeInfoCount;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE GetTypeInfo( iTInfo : windows.UINT;
                                        cid : wtypes.LCID;
                                        VAR ppTInfo : oaidl.TPITypeInfo ): wtypes.HRESULT;
  BEGIN
    IF PITypeInfoSelf = NIL THEN
      RETURN winerror.E_NOTIMPL;
    ELSIF iTInfo <> 0 THEN
      RETURN winerror.DISP_E_BADINDEX;
    ELSE
      ppTInfo := PITypeInfoSelf;
      ppTInfo^.AddRef();
    END;
    RETURN winerror.S_OK;
  END GetTypeInfo;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE GetIDsOfNames( CONST riid : guiddef.IID;
                                          rgszNames : wtypes.PPOLESTR;
                                          cNames : windows.UINT;
                                          lcid : wtypes.LCID;
                                          rgDispId : oaidl.PDISPID ): wtypes.HRESULT;
  BEGIN
    IF PITypeInfoSelf <> NIL THEN
      RETURN oleauto.DispGetIDsOfNames( PITypeInfoSelf, rgszNames^, cNames, rgDispId );
    ELSE
      RETURN winerror.E_NOTIMPL;
    END;
  END GetIDsOfNames;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE Invoke( dispIdMember : oaidl.DISPID;
                                   CONST riid : guiddef.IID;
                                   lcid : wtypes.LCID;
                                   wFlags : WORD;
                                   pDispParams : oaidl.PDISPPARAMS;
                                   pVarResult : oaidl.PVARIANT;
                                   pExcepInfo : oaidl.PEXCEPINFO;
                                   puArgErr : windows.PUINT ): wtypes.HRESULT;
  BEGIN
    RETURN oleauto.DispInvoke( ADR( SELF ), PITypeInfoSelf, dispIdMember, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr );
  END Invoke;

(*---------------------------------------------------------------------------*)

  LOCAL PROCEDURE Init( _IID : guiddef.IID ) : wtypes.HRESULT;
  VAR
    HR : wtypes.HRESULT;
    PITypeLib : oaidl.TPITypeLib;
  BEGIN
    IID := _IID;
    HR := GetTypeLib( PITypeLib );
    IF HR <> winerror.S_OK THEN
      RETURN HR;
    END;

    HR := PITypeLib^.GetTypeInfoOfGuid( IID, PITypeInfoSelf );

    PITypeLib^.Release();
    RETURN HR;
  END Init;

(*---------------------------------------------------------------------------*)

BEGIN
  IID := oaidl.IID_IDispatch;
  PITypeInfoSelf := NIL;
END CIDispatch;

(*===========================================================================*)

CLASS IMPLEMENTATION CConnectionPoint;
BEGIN
  IConnectionPoint.AddRef();
END CConnectionPoint;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CIConnectionPointContainer;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE Release() : windows.ULONG;
  VAR
    it : list.CListIterator;
    PConnectionPoint : TPConnectionPoint;
  BEGIN
    IF ReferenceCount = 1 THEN
      it.Init( ConnectionPoints, collection.dirForward );
      WHILE it.MoveNext() DO
        PConnectionPoint := TPConnectionPoint( it.Current );
        PConnectionPoint^.IConnectionPoint.Release();
        DISPOSE( PConnectionPoint );
      END; // WHILE
      ConnectionPoints.Dispose();
    END;
    RETURN SUPER.Release();
  END Release;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE EnumConnectionPoints( VAR ppEnum : TPInterface ) : wtypes.HRESULT;
  VAR
    PCEnum : TPIEnumConnectionPoints;
  BEGIN
    NEW( PCEnum );
    PCEnum^.PInterfaceFactory := PInterfaceFactory;

(*%T DEBUG *)
    DbgOutSP( L'ECP: ', PCEnum );
(*%E DEBUG *)

    PCEnum^.AddRef();
    PCEnum^.Init( ConnectionPoints );
    ppEnum := PCEnum;

    RETURN winerror.S_OK;
  END EnumConnectionPoints;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE FindConnectionPoint( CONST riid : guiddef.IID; VAR ppCP : TPIConnectionPoint ) : wtypes.HRESULT;
  VAR
    it : list.CListIterator;
    PConnectionPoint : TPConnectionPoint;
  BEGIN
    it.Init( ConnectionPoints, collection.dirForward );
    WHILE it.MoveNext() DO
      PConnectionPoint := TPConnectionPoint( it.Current );
      IF PConnectionPoint^.IConnectionPoint.IID = riid THEN
        ppCP := ADR( PConnectionPoint^.IConnectionPoint );
        ppCP^.AddRef();
        RETURN winerror.S_OK;
      END;
    END; // WHILE
    RETURN olectl.CONNECT_E_NOCONNECTION;
  END FindConnectionPoint;

(*---------------------------------------------------------------------------*)

  LOCAL PROCEDURE Init( _PActiveXControl : TPActiveXControl ) : BOOLEAN;
  LABEL
    Continue;
  VAR
    ES : LONGWORD;
    HR : wtypes.HRESULT;
    IID : guiddef.IID;
    PConnectionPoint : TPConnectionPoint;
    PITypeLib : oaidl.TPITypeLib;
    PITypeInfo : oaidl.TPITypeInfo;
  BEGIN
    PActiveXControl := _PActiveXControl;

    ES := 0;
    LOOP
    Continue:
      IF NOT EnumerateKnownIIDs( ES, IID ) THEN
        EXIT;
      END;

      HR := GetTypeLib( PITypeLib );
      IF HR <> winerror.S_OK THEN
        GOTO Continue;
      END;
      HR := PITypeLib^.GetTypeInfoOfGuid( IID, PITypeInfo );
      PITypeLib^.Release();
      IF HR <> winerror.S_OK THEN
        GOTO Continue;
      END;
      
      NEW( PConnectionPoint );
      PConnectionPoint^.IConnectionPoint.PInterfaceFactory := PInterfaceFactory;
      PConnectionPoint^.IConnectionPoint.PConnectionPointContainer := ADR( SELF );
      PConnectionPoint^.IConnectionPoint.IID := IID;
      PConnectionPoint^.IConnectionPoint.PITypeInfo := PITypeInfo;
      PConnectionPoint^.IConnectionPoint.AddRef();
      ConnectionPoints.Add( PConnectionPoint );
    END; // LOOP

    RETURN TRUE;
  END Init;

(*---------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE EnumerateKnownIIDs( VAR EnumerateState : LONGWORD; VAR IID : guiddef.IID ) : BOOLEAN;
  BEGIN
    RETURN PActiveXControl^.EnumerateEventIDispatch( EnumerateState, IID );
  END EnumerateKnownIIDs;

(*---------------------------------------------------------------------------*)

BEGIN
  IID := ocidl.IID_IConnectionPointContainer;
  PActiveXControl := NIL;
END CIConnectionPointContainer;

(*===========================================================================*)

CLASS IMPLEMENTATION CIEnumConnectionPoints;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( CONST ConnectionPoints : collection.ICollection );
   BEGIN
      Iterator.Init( ConnectionPoints, collection.dirForward );
   END Init;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE Next( celt : windows.ULONG; rgelt : TPPIConnectionPoint; pceltFetched : windows.PULONG ) : wtypes.HRESULT;
  TYPE
    TCA = ARRAY [0..0] OF TPIConnectionPoint;
    TPCA = POINTER TO TCA;
  VAR
    HR : wtypes.HRESULT;
    i : CARDINAL;
  BEGIN
    // rgelt is caller allocated (found in INET)!!!
    // rgelt := objbase.CoTaskMemAlloc( celt * SIZE( TPIConnectionPoint ));
    i := 0;
    WHILE ( i < CARDINAL( celt )) AND Iterator.MoveNext() DO
      TPCA( rgelt )^[i] := ADR( TPConnectionPoint( Iterator.Current )^.IConnectionPoint );
      TPCA( rgelt )^[i]^.AddRef();
      INC( i );
    END; // WHILE

    IF i = CARDINAL( celt ) THEN
      HR := winerror.S_OK;
    ELSE
      HR := winerror.S_FALSE;
    END;
    IF pceltFetched <> NIL THEN
      pceltFetched^ := i;
    END;
    RETURN HR;
  END Next;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE Skip( celt : windows.ULONG ) : wtypes.HRESULT;
  VAR
    i : CARDINAL;
  BEGIN
    i := 0;
    WHILE ( i < CARDINAL( celt )) AND Iterator.MoveNext() DO
      INC( i );
    END;
    IF i = CARDINAL( celt ) THEN
      RETURN winerror.S_OK;
    ELSE
      RETURN winerror.S_FALSE;
    END;
  END Skip;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE Reset() : wtypes.HRESULT;
  BEGIN
    Iterator.Reset();
    RETURN winerror.S_OK;
  END Reset;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE Clone( VAR ppEnum : TPIEnumConnectionPoints ) : wtypes.HRESULT;
  BEGIN
    NEW( ppEnum );
    ppEnum^.PInterfaceFactory := PInterfaceFactory;
    ppEnum^.Init( Iterator.OfCollection^ );
    RETURN winerror.S_OK;
  END Clone;

(*---------------------------------------------------------------------------*)

BEGIN
  IID := ocidl.IID_IEnumConnectionPoints;
END CIEnumConnectionPoints;

(*===========================================================================*)

CLASS IMPLEMENTATION CAdvisedClient;
BEGIN
  PClient := NIL;
  PIDispatch_Event := NIL;
END CAdvisedClient;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CIConnectionPoint;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE Release() : windows.ULONG;
  BEGIN
    IF ReferenceCount = 1 THEN
      IF PITypeInfo <> NIL THEN
        PITypeInfo^.Release();
        PITypeInfo := NIL;
      END;
    END;
    RETURN SUPER.Release();
  END Release;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE GetConnectionInterface( VAR _IID : guiddef.IID ) : wtypes.HRESULT;
  BEGIN
    _IID := IID;
    RETURN winerror.S_OK;
  END GetConnectionInterface;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE GetConnectionPointContainer( VAR ppCPC : TPIConnectionPointContainer ) : wtypes.HRESULT;
  BEGIN
    IF PConnectionPointContainer = NIL THEN
      RETURN winerror.E_UNEXPECTED;
    ELSE
      ppCPC := PConnectionPointContainer;
      ppCPC^.AddRef();
    END;
    RETURN winerror.S_OK;
  END GetConnectionPointContainer;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE Advise( pUnk : unknwn.TPIUnknown; VAR dwCookie : windows.DWORD ) : wtypes.HRESULT;
  VAR
    HR : wtypes.HRESULT;
    PAClient : TPAdvisedClient;
    PIDispatch_Event : oaidl.TPIDispatch;
  BEGIN
    IF pUnk = NIL THEN
      HR := winerror.E_POINTER;
    END;

    HR := pUnk^.QueryInterface( IID, ADR( PIDispatch_Event ));
    IF HR <> 0 THEN
      RETURN olectl.CONNECT_E_CANNOTCONNECT;
    END;
    
    NEW( PAClient );
    PAClient^.PClient := pUnk;
    PAClient^.PClient^.AddRef(); // I will call Release in Unadvise()
    PAClient^.PIDispatch_Event:= PIDispatch_Event;
    AdvisedClients.Add( PAClient );

    dwCookie := LOPTRLONGWORD( PAClient );
    RETURN winerror.S_OK;
  END Advise;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE Unadvise( dwCookie : windows.DWORD ) : wtypes.HRESULT;
  VAR
    PAClient : TPAdvisedClient := TPAdvisedClient( dwCookie );
  BEGIN
    IF AdvisedClients.Contains( PAClient ) THEN
      AdvisedClients.Remove( PAClient );

      PAClient^.PIDispatch_Event^.Release();
      PAClient^.PClient^.Release(); // I called AddRef in Advise
      DISPOSE( PAClient );
    ELSE
      RETURN olectl.CONNECT_E_NOCONNECTION;
    END;

    RETURN winerror.S_OK;
  END Unadvise;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE EnumConnections( VAR ppEnum : TPIEnumConnections ) : wtypes.HRESULT;
  BEGIN
    NEW( ppEnum );
    ppEnum^.PInterfaceFactory := PInterfaceFactory;
    ppEnum^.AddRef();
    ppEnum^.Init( AdvisedClients );
    RETURN winerror.S_OK;
  END EnumConnections;

(*---------------------------------------------------------------------------*)

BEGIN
  IID := ocidl.IID_IConnectionPoint;
  PITypeInfo := NIL;
  PConnectionPointContainer := NIL;
END CIConnectionPoint;

(*===========================================================================*)

CLASS IMPLEMENTATION CIEnumConnections;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( CONST AdvisedClients : collection.ICollection );
   BEGIN
      Iterator.Init( AdvisedClients, collection.dirForward );
   END Init;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE Next( cConnections : windows.ULONG; rgpcd : ocidl.PCONNECTDATA; pcFetched : windows.PULONG ) : wtypes.HRESULT;
  VAR
    HR : wtypes.HRESULT;
    i : CARDINAL;
  BEGIN
    // rgpcd is CALLER allocated (found in INET)!!
    // rgpcd := objbase.CoTaskMemAlloc( cConnections * SIZE( ocidl.CONNECTDATA ));
    i := 0;
    WHILE ( i < CARDINAL( cConnections )) AND Iterator.MoveNext()  DO
      rgpcd^.pUnk := TPAdvisedClient( Iterator.Current )^.PClient;
      rgpcd^.pUnk^.AddRef();
      rgpcd^.dwCookie := windows.DWORD( LOPTRLONGWORD( Iterator.Current ));
      INC( rgpcd, SIZE( ocidl.CONNECTDATA ));
      INC( i );
    END; // WHILE

    IF i = CARDINAL( cConnections ) THEN
      HR := winerror.S_OK;
    ELSE
      HR := winerror.S_FALSE;
    END;
    IF pcFetched <> NIL THEN
      pcFetched^ := i;
    END;

    RETURN HR;
  END Next;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE Skip( cConnections : windows.ULONG ) : wtypes.HRESULT;
  VAR
    i : CARDINAL;
  BEGIN
    i := 0;
    WHILE ( i < CARDINAL( cConnections )) AND Iterator.MoveNext() DO
      INC( i );
    END;
    IF i = CARDINAL( cConnections ) THEN
      RETURN winerror.S_OK;
    ELSE
      RETURN winerror.S_FALSE;
    END;
  END Skip;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE Reset() : wtypes.HRESULT;
  BEGIN
    Iterator.Reset();
    RETURN winerror.S_OK;
  END Reset;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE Clone( VAR ppEnum : TPIEnumConnections ) : wtypes.HRESULT;
  BEGIN
    NEW( ppEnum );
    ppEnum^.Init( Iterator.OfCollection^ );
    RETURN winerror.S_OK;
  END Clone;

(*---------------------------------------------------------------------------*)

BEGIN
  IID := ocidl.IID_IEnumConnections;
END CIEnumConnections;

(*===========================================================================*)

CLASS IMPLEMENTATION CActiveXDispatch;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE AddRef() : windows.ULONG;
  BEGIN
    IF PActiveXControl <> NIL THEN
      PActiveXControl^.AddRef();
    END;
    RETURN SUPER.AddRef();
  END AddRef;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE Release() : windows.ULONG;
  BEGIN
    IF ( PActiveXControl <> NIL ) AND ( PActiveXControl^.Release() = 0 ) THEN
      // I am already Released()
      RETURN 0;
    END;
    RETURN SUPER.Release();
  END Release;

(*---------------------------------------------------------------------------*)

  PUBLIC  PROCEDURE Init( _IID             : guiddef.IID;
                          _PActiveXControl : TPActiveXControl ) : wtypes.HRESULT;
  BEGIN
    PActiveXControl := _PActiveXControl;
    RETURN SUPER.Init( _IID );
  END Init;

(*---------------------------------------------------------------------------*)

BEGIN
  PActiveXControl := NIL;
END CActiveXDispatch;

(*===========================================================================*)

CLASS IMPLEMENTATION CActiveXControl;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE QueryInterface( CONST riid : guiddef.IID; ppvObject : PADDRESS ) : wtypes.HRESULT;
  VAR
    HR : wtypes.HRESULT;
    PConnectionPoint : TPConnectionPoint;
    PInterface : TPInterface;
    PIUnknown : TPInterface;
    DoAddRef : BOOLEAN;
  BEGIN
    PInterface := NIL;
    DoAddRef := TRUE;

(*%T DEBUG *)
    DbgOutIID( L'CFQ: ', ADR( SELF ), riid );
(*%E DEBUG *)

    IF InsideSUPERQueryInterface THEN
      // try PDLLConstructor, it contains some common interfaces
      DoAddRef := FALSE;
      HR := PDLLConstructor^.QueryInterface( riid, ADR( PInterface ));
      IF HR <> winerror.S_OK THEN
        PInterface := NIL;
      END;

    ELSIF riid = IID THEN
      PInterface := ADR( SELF );
    ELSIF riid = unknwn.IID_IUnknown THEN
      PInterface := ADR( SELF );
    ELSIF riid = unknwn.IID_IClassFactory THEN
      PInterface := ADR( SELF );

    ELSIF riid = ocidl.IID_IConnectionPointContainer THEN
      PInterface := PIConnectionPointContainer;
    ELSIF riid = ocidl.IID_IEnumConnectionPoints THEN
      DoAddRef := FALSE;
      PIConnectionPointContainer^.EnumConnectionPoints( PIUnknown );
      PInterface := TPInterface( PIUnknown );

    ELSIF riid = oaidl.IID_IDispatch THEN
      PInterface := PNativeIDispatch;
    ELSIF riid = PNativeIDispatch^.IID THEN
      PInterface := PNativeIDispatch;

    ELSIF riid = ocidl.IID_IConnectionPoint THEN
      IF PIConnectionPointContainer^.ConnectionPoints.colGetFirst( OUT PConnectionPoint ) THEN
        PInterface := ADR( PConnectionPoint^.IConnectionPoint );
      END;

    ELSE
      DoAddRef := FALSE;
      
      InsideSUPERQueryInterface := TRUE;
      HR := SUPER.QueryInterface( riid, ADR( PInterface ));
      InsideSUPERQueryInterface := FALSE;

      IF HR <> winerror.S_OK THEN
        PInterface := NIL;
      END;
    END;

    IF PInterface = NIL THEN
      RETURN winerror.E_NOTIMPL;
    ELSE
      IF DoAddRef THEN
        PInterface^.AddRef();
      END;
      PInterface^.PInterfaceFactory := ADR( SELF );
      ppvObject^ := PInterface;

      RETURN winerror.S_OK;
    END;
  END QueryInterface;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE Release() : windows.ULONG;
  BEGIN
    IF ReferenceCount = 1 THEN
      IF PNativeIDispatch <> NIL THEN
        PNativeIDispatch^.PActiveXControl := NIL; // to avoid recursion
        PNativeIDispatch^.Release();
        PNativeIDispatch := NIL;
      END;
      IF PIConnectionPointContainer <> NIL THEN
        PIConnectionPointContainer^.Release();
        PIConnectionPointContainer := NIL;
      END;
      IF PDLLConstructor <> NIL THEN
        TPDLLConstructor( PDLLConstructor )^.RemoveInterface( ADR( SELF ));
      END;
    END;
    RETURN SUPER.Release();
  END Release;
  
(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE CreateInstance( pUnkOuter : unknwn.TPIUnknown; CONST riid : guiddef.IID; VAR ppvObject : ADDRESS ): wtypes.HRESULT;
  BEGIN
    IF pUnkOuter = NIL THEN 
      RETURN QueryInterface( riid, ADR( ppvObject ));
    ELSE
      RETURN winerror.CLASS_E_NOAGGREGATION;
    END;
  END CreateInstance;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE LockServer( fLock : windows.BOOL ): wtypes.HRESULT;
  BEGIN
    RETURN winerror.S_OK;
  END LockServer;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Init();
  BEGIN
    AddRef();
    Release();

    IF CreateNativeIDispatch( PNativeIDispatch ) THEN
      PNativeIDispatch^.PInterfaceFactory := PInterfaceFactory;
    ELSE
      PNativeIDispatch := NIL;
    END;

(*%T DEBUG *)
    DbgOutSP( L'NID: ', PNativeIDispatch );
(*%E DEBUG *)

    NEW( PIConnectionPointContainer );
    PIConnectionPointContainer^.PInterfaceFactory := PInterfaceFactory;

(*%T DEBUG *)
    DbgOutSP( L'CPC: ', PIConnectionPointContainer );
(*%E DEBUG *)

    PIConnectionPointContainer^.AddRef();
    IF NOT PIConnectionPointContainer^.Init( ADR( SELF )) THEN
      PIConnectionPointContainer := NIL;
    END;
  END Init;

(*---------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE CreateNativeIDispatch( VAR PIDispatch : TPActiveXDispatch ) : BOOLEAN;
  BEGIN
    RETURN FALSE;
  END CreateNativeIDispatch;

(*---------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE EnumerateEventIDispatch( VAR EnumerateState : LONGWORD; VAR IID : guiddef.IID ) : BOOLEAN;
  BEGIN
    RETURN FALSE;
  END EnumerateEventIDispatch;

(*---------------------------------------------------------------------------*)

  INTERNAL PROCEDURE DispatchEvent( EventIDispatchIID : guiddef.IID; DispatchId : CARDINAL; Parameters : ARRAY OF oaidl.VARIANTARG );
  VAR
    DispatchParameters : oaidl.DISPPARAMS;
    HR : wtypes.HRESULT;
    it : list.CListIterator;
    PConnectionPoint : TPIConnectionPoint;
    PIDispatch : oaidl.TPIDispatch;
    Result : oaidl.VARIANT;
  BEGIN
    HR := PIConnectionPointContainer^.FindConnectionPoint( EventIDispatchIID, PConnectionPoint );
    IF HR <> winerror.S_OK THEN
      RETURN;
    END;

    DispatchParameters.rgvarg := ADR( Parameters );
    DispatchParameters.rgdispidNamedArgs := NIL;
    DispatchParameters.cArgs := HIGH( Parameters ) + 1;
    DispatchParameters.cNamedArgs := 0;

    it.Init( PConnectionPoint^.AdvisedClients, collection.dirForward );
    WHILE it.MoveNext() DO
      HR := TPAdvisedClient( it.Current )^.PClient^.QueryInterface( EventIDispatchIID, ADR( PIDispatch ));
      IF HR = winerror.S_OK THEN
        oleauto.VariantInit( ADR( Result ));
        PIDispatch^.Invoke( DispatchId, guiddef.IID_NULL, windows.LOCALE_USER_DEFAULT, oleauto.DISPATCH_METHOD, ADR( DispatchParameters ), ADR( Result ), NIL, NIL );
        PIDispatch^.Release();
        oleauto.VariantClear( ADR( Result ));
      END;
    END; // WHILE

    PConnectionPoint^.Release();
  END DispatchEvent;

(*---------------------------------------------------------------------------*)

BEGIN
  PInterfaceFactory := ADR( SELF );
  PDLLConstructor := NIL;
  PIConnectionPointContainer := NIL;
  PNativeIDispatch := NIL;
  InsideSUPERQueryInterface := FALSE;
END CActiveXControl;

(*===========================================================================*)

PROCEDURE DbgOutSH( String : ARRAY OF WCHAR; HexNumber : CARDINAL );
VAR
  OString : ARRAY [0..255] OF WCHAR;
  NString : ARRAY [0..32] OF WCHAR;
BEGIN
  Strings.FromCARD32W( HexNumber, 16, OUT NString );
  Strings.ConcatW( OUT OString, String, NString );
  Strings.AppendW( REF OString, WCHAR( 13 ) + WCHAR( 10 ));
  windows.OutputDebugStringW( ADR( OString ));
END DbgOutSH;

(*---------------------------------------------------------------------------*)

PROCEDURE DbgOutSP( String : ARRAY OF WCHAR; HexNumber : PTR );
VAR
  OString : ARRAY [0..255] OF WCHAR;
  NString : ARRAY [0..32] OF WCHAR;
BEGIN
  Strings.FromCARD64W( CARD64( HexNumber ), 16, OUT NString );
  Strings.ConcatW( OUT OString, String, NString );
  Strings.AppendW( REF OString, WCHAR( 13 ) + WCHAR( 10 ));
  windows.OutputDebugStringW( ADR( OString ));
END DbgOutSP;

(*---------------------------------------------------------------------------*)

PROCEDURE DbgOutIID( String : ARRAY OF WCHAR; POwner : ADDRESS; riid : guiddef.IID );
VAR
  PBSTR : wtypes.BSTR;
  s : ARRAY [0..127] OF WCHAR;
BEGIN
  Strings.FromCARD64W( CARD64( POwner ), 16, OUT s );
  Strings.PrependW( REF s, L'ref: ' );
  Strings.PrependW( REF s, String );
  Strings.AppendW( REF s, L' req: ' );

     IF riid = guiddef.IID_NULL THEN
    Strings.AppendW( REF s, L'{INull}' );
  ELSIF riid = unknwn.IID_IUnknown THEN
    Strings.AppendW( REF s, L'{IUnknown}' );
  ELSIF riid = unknwn.IID_IClassFactory THEN
    Strings.AppendW( REF s, L'{IClassFactory}' );
  ELSIF riid = ocidl.IID_IClassFactory2 THEN
    Strings.AppendW( REF s, L'{IClassFactory2}' );
  ELSIF riid = oaidl.IID_IDispatch THEN
    Strings.AppendW( REF s, L'{IDispatch}' );
  ELSIF riid = ocidl.IID_IProvideClassInfo THEN
    Strings.AppendW( REF s, L'{IProvideClassInfo}' );
  ELSIF riid = ocidl.IID_IConnectionPointContainer THEN
    Strings.AppendW( REF s, L'{IConnectionPointContainer}' );
  ELSIF riid = ocidl.IID_IEnumConnectionPoints THEN
    Strings.AppendW( REF s, L'{IEnumConnectionPoints}' );
  ELSIF riid = ocidl.IID_IConnectionPoint THEN
    Strings.AppendW( REF s, L'{IConnectionPoint}' );
  ELSIF riid = ocidl.IID_IEnumConnections THEN
    Strings.AppendW( REF s, L'{IEnumConnections}' );

  ELSE
    objbase.StringFromIID( riid, PBSTR );
    Strings.AppendW( REF s, OA( 64, PBSTR ));
    objbase.CoTaskMemFree( PBSTR );
  END;

  Strings.AppendW( REF s, WCHAR( 13 ) + WCHAR( 10 ));
  windows.OutputDebugStringW( ADR( s ));
END DbgOutIID;

(*---------------------------------------------------------------------------*)

PROCEDURE DbgOutRefCount( Text : ARRAY OF WCHAR; PInterface : TPInterface; From : CARDINAL; Amount : INTEGER );
VAR
  n : ARRAY [0..31] OF WCHAR;
  s : ARRAY [0..127] OF WCHAR;
BEGIN
  Strings.FromCARD64W( CARD64( PInterface ), 16, OUT s );
  Strings.PrependW( REF s, Text );
  Strings.FromCARD32W( From, 10, OUT n );
  Strings.AppendW( REF s, L', ' );
  Strings.AppendW( REF s, n );
  Strings.AppendW( REF s, L' -> ' );
  Strings.FromCARD32W( CARDINAL( INTEGER( From ) + Amount ), 10, OUT n );
  Strings.AppendW( REF s, n );
  Strings.AppendW( REF s, WCHAR( 13 ) + WCHAR( 10 ));
  windows.OutputDebugStringW( ADR( s ));
END DbgOutRefCount;

(*---------------------------------------------------------------------------*)

PROCEDURE DbgOutADD( PInterface : TPInterface );
BEGIN
  DbgOutRefCount( L'ADD: ', PInterface, PInterface^.ReferenceCount, 1 );
END DbgOutADD;

(*---------------------------------------------------------------------------*)

PROCEDURE DbgOutREL( PInterface : TPInterface );
BEGIN
  DbgOutRefCount( L'REL: ', PInterface, PInterface^.ReferenceCount, -1 );
END DbgOutREL;

(*===========================================================================*)
// public procedures manipulating interfaces

VAR
  DLLConstructor : CDLLConstructor;

(*---------------------------------------------------------------------------*)

PROCEDURE RegisterClientConstructor( PClientConstructor : TPAbstractClientConstructor );
BEGIN
  DLLConstructor.RegisterConstructor( PClientConstructor );
END RegisterClientConstructor;

(*---------------------------------------------------------------------------*)

PROCEDURE ForgetClientConstructor();
BEGIN
  DLLConstructor.ForgetConstructor();
END ForgetClientConstructor;

(*---------------------------------------------------------------------------*)

PROCEDURE GetClientConstructor() : TPAbstractClientConstructor;
BEGIN
  RETURN DLLConstructor.PConstructor;
END GetClientConstructor;

(*---------------------------------------------------------------------------*)

PROCEDURE GetTypeLib( VAR PITypeLib : oaidl.TPITypeLib ) : wtypes.HRESULT; // calls AddRef()
BEGIN
  PITypeLib := DLLConstructor.PITypeLibSelf;
  PITypeLib^.AddRef();
  RETURN winerror.S_OK;
END GetTypeLib;

(*---------------------------------------------------------------------------*)

PROCEDURE CreateInterface( CONST riid   : guiddef.IID; VAR ppv    : ADDRESS ) : wtypes.HRESULT;
BEGIN
  RETURN DLLConstructor.QueryInterface( riid, ADR( ppv ));
END CreateInterface;

(*---------------------------------------------------------------------------*)

PROCEDURE UnloadAllowed() : BOOLEAN;
BEGIN
  IF DLLConstructor.IsEmpty() THEN
    DLLConstructor.Release();
    RETURN TRUE;
  ELSE
    RETURN FALSE;
  END;
END UnloadAllowed;

(*===========================================================================*)

END ax_automation.
