IMPLEMENTATION MODULE com;
(*# option( pack => 8 ) *)

////////////////////////////////////////////////////////////////
// Control Web Driver ActiveX Control                         //
//                                               the COM code //
//                              (C) 2004 Moravian Instruments //
////////////////////////////////////////////////////////////////

FROM Storage IMPORT
  ALLOCATE, DEALLOCATE;

IMPORT
  windows;

IMPORT
  objbase,
  ocidl,
  oleauto,
  winerror;

IMPORT
  Strings;

(*===========================================================================*)

CLASS IMPLEMENTATION CIUnknown;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Init( IID : guiddef.IID; PAggregate : TPIUnknown );
  BEGIN
    SELF.IID := IID;
    SELF.PAggregate := PAggregate;
  END Init;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE QueryInterface( CONST riid : guiddef.IID; ppvObject : PADDRESS ) : wtypes.HRESULT;
  BEGIN
    IF ppvObject = NIL THEN 
      RETURN winerror.E_INVALIDARG;
    ELSIF ( riid = unknwn.IID_IUnknown ) OR ( riid = IID ) THEN
      AddRef();
      ppvObject^ := ADR( SELF );
      RETURN winerror.S_OK;
    ELSIF PAggregate = NIL THEN
      RETURN winerror.E_NOTIMPL;
    ELSE
      RETURN PAggregate^.QueryInterface( riid, ppvObject );
    END;
  END QueryInterface;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE AddRef() : windows.ULONG;
  BEGIN
    #if DEBUG #then
      DbgOutADD( ADR( SELF ));
    #endif
    INC( ReferenceCount );
    RETURN windows.ULONG( ReferenceCount );
  END AddRef;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE Release() : windows.ULONG;
  VAR
    a : ADDRESS;
  BEGIN
    #if DEBUG #then
      DbgOutREL( ADR( SELF ));
      IF ReferenceCount = 0 THEN
        ADDRESS( 0 )^ := 0;
      END;
    #endif
    DEC( ReferenceCount );
    IF ReferenceCount > 0 THEN
      RETURN windows.ULONG( ReferenceCount );
    ELSE
      a := ADR( SELF );
      DISPOSE( a );
      RETURN 0;
    END;
  END Release;

//---------------------------------------------------------------------------

  PUBLIC OPERATOR NEW( size : CARDINAL ) : ADDRESS;
  VAR
    a : ADDRESS;
  BEGIN
    ALLOCATE( a, size );
    RETURN a;
  END NEW;

//---------------------------------------------------------------------------

  PUBLIC OPERATOR DISPOSE( a : ADDRESS );
  BEGIN
    DEALLOCATE( a );
  END DISPOSE;

//---------------------------------------------------------------------------

BEGIN
  ReferenceCount := 0;
  PAggregate := NIL;
  IID := unknwn.IID_IUnknown;
END CIUnknown;

//===========================================================================

CLASS IMPLEMENTATION CIDispatch;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Init(
          IID        : guiddef.IID;
          PAggregate : TPIUnknown;
          PTypeInfo  : oaidl.TPITypeInfo );
  BEGIN
    SUPER.Init( IID, PAggregate );
    SELF.PTypeInfo := PTypeInfo;
  END Init;

(*---------------------------------------------------------------------------*)

  PUBLIC COM VIRTUAL PROCEDURE GetTypeInfoCount() : windows.UINT;
  BEGIN
    IF PTypeInfo = NIL THEN
      RETURN 0;
    ELSE
      RETURN 1;
    END;
  END GetTypeInfoCount;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE GetTypeInfo( 
          iTInfo  : windows.UINT;
          lcid    : wtypes.LCID;
      VAR ppTInfo : oaidl.TPITypeInfo
  ) : wtypes.HRESULT;
  BEGIN
    IF PTypeInfo = NIL THEN
      RETURN winerror.DISP_E_BADINDEX;
    ELSIF iTInfo <> 0 THEN
      RETURN winerror.DISP_E_BADINDEX;
    ELSE
      ppTInfo := PTypeInfo;
      ppTInfo^.AddRef();
    END;
    RETURN winerror.S_OK;
  END GetTypeInfo;

(*---------------------------------------------------------------------------*)


  PUBLIC VIRTUAL PROCEDURE GetIDsOfNames( 
    CONST riid      : guiddef.IID;
          rgszNames : wtypes.PPOLESTR;
          cNames    : windows.UINT;
          lcid      : wtypes.LCID;
          rgDispId  : oaidl.PDISPID
  ) : wtypes.HRESULT;
  BEGIN
    IF PTypeInfo <> NIL THEN
      RETURN oleauto.DispGetIDsOfNames( PTypeInfo, rgszNames^, cNames, rgDispId );
    ELSE
      RETURN winerror.E_NOTIMPL;
    END;
  END GetIDsOfNames;

(*---------------------------------------------------------------------------*)


  PUBLIC VIRTUAL PROCEDURE Invoke( 
          dispIdMember : oaidl.DISPID;
    CONST riid         : guiddef.IID;
          lcid         : wtypes.LCID;
          wFlags       : WORD;
          pDispParams  : oaidl.PDISPPARAMS;
          pVarResult   : oaidl.PVARIANT;
          pExcepInfo   : oaidl.PEXCEPINFO;
          puArgErr     : windows.PUINT
  ) : wtypes.HRESULT;
  BEGIN
    RETURN oleauto.DispInvoke( ADR( SELF ), PTypeInfo, dispIdMember, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr );
  END Invoke;

(*---------------------------------------------------------------------------*)

BEGIN
  IID := oaidl.IID_IDispatch;
  PTypeInfo := NIL;
END CIDispatch;

(*===========================================================================*)

PROCEDURE COMInit() : wtypes.HRESULT;
BEGIN
  RETURN objbase.CoInitialize( NIL );
END COMInit;

(*---------------------------------------------------------------------------*)

PROCEDURE COMDone();
BEGIN
  objbase.CoUninitialize();
END COMDone;

(*---------------------------------------------------------------------------*)

PROCEDURE Cast( REF InputInterface : unknwn.TPIUnknown; ToIID : guiddef.GUID; Release : BOOLEAN; OUT OutputInterface : unknwn.TPIUnknown );
VAR
	ii : unknwn.TPIUnknown := InputInterface; // InputInterface and OutputInterface can be coupled by REF/OUT, using ii is safer
BEGIN
  IF ii^.QueryInterface( ToIID, ADR( OutputInterface )) <> 0 THEN
    OutputInterface := NIL;
  END;
  IF Release THEN
    ii^.Release();
    ii := NIL;
  END;
END Cast;

(*---------------------------------------------------------------------------*)

PROCEDURE ToBS( CONST String : ARRAY OF WCHAR ) : BSTR;
BEGIN
  RETURN oleauto.SysAllocString( wtypes.POLECHAR( ADR( String )));
END ToBS;

(*---------------------------------------------------------------------------*)

PROCEDURE ToBSRef( CONST String : ARRAY OF WCHAR; REF BS : BSTR ) : BSTR;
BEGIN
  IF BS = NIL THEN
    BS := oleauto.SysAllocString( wtypes.POLECHAR( ADR( String )));
  ELSE
    oleauto.SysReAllocString( ADR( BS ), wtypes.POLECHAR( ADR( String )));
  END;
  RETURN BS;
END ToBSRef;

(*---------------------------------------------------------------------------*)

PROCEDURE BSToBSRef( Input : BSTR; ClearInput : BOOLEAN; REF Output : BSTR ) : BSTR;
BEGIN
  IF Output = NIL THEN
    Output := oleauto.SysAllocString( Input );
  ELSE
    oleauto.SysReAllocString( ADR( Output ), Input );
  END;
  IF ClearInput AND ( Input <> NIL ) THEN
    oleauto.SysFreeString( Input );
  END;
  RETURN Output;
END BSToBSRef;

(*---------------------------------------------------------------------------*)

PROCEDURE BSEmpty( BS : BSTR ) : BOOLEAN;
BEGIN
  RETURN ( BS = NIL ) OR ( BS^ = 0W );
END BSEmpty;

(*---------------------------------------------------------------------------*)

PROCEDURE DisposeBS( REF BS : BSTR );
BEGIN
  IF BS <> NIL THEN
    oleauto.SysFreeString( BS );
    BS := NIL;
  END;
END DisposeBS;

(*---------------------------------------------------------------------------*)

PROCEDURE VariantInit( OUT V : oaidl.VARIANTARG );
BEGIN
  oleauto.VariantInit( ADR( V ));
END VariantInit;

(*---------------------------------------------------------------------------*)

PROCEDURE VariantInitString( OUT V : oaidl.VARIANTARG; CONST S : ARRAY OF WCHAR );
BEGIN
  oleauto.VariantInit( ADR( V ));
  V.vt := wtypes.VT_BSTR;
  V.bstrVal := ToBS( S );
END VariantInitString;

(*---------------------------------------------------------------------------*)

PROCEDURE VariantToINT32( V : VARIANTARG; ClearVariant : BOOLEAN ) : INT32;
VAR
  LV : VARIANTARG;
BEGIN
  oleauto.VariantInit( ADR( LV ));
  oleauto.VariantChangeType( ADR( LV ), oaidl.PVARIANTARG( ADR( V )), 0, CARD16( wtypes.VT_I4 ));
  IF ClearVariant THEN
    oleauto.VariantClear( ADR( V ));
  END;
  RETURN LV.lVal;
END VariantToINT32;

(*---------------------------------------------------------------------------*)

PROCEDURE VariantToBS( V : VARIANTARG; ClearVariant : BOOLEAN ) : BSTR;
VAR
  LV : VARIANTARG;
BEGIN
  IF ( V.vt = wtypes.VT_EMPTY ) OR ( V.vt = wtypes.VT_NULL ) THEN
    RETURN NIL;
  END;
  oleauto.VariantInit( ADR( LV ));
  oleauto.VariantChangeType( ADR( LV ), oaidl.PVARIANTARG( ADR( V )), 0, CARD16( wtypes.VT_BSTR ));
  IF ClearVariant THEN
    oleauto.VariantClear( ADR( V ));
  END;
  RETURN LV.bstrVal;
END VariantToBS;

(*---------------------------------------------------------------------------*)

PROCEDURE VariantToBSRef( V : VARIANTARG; ClearVariant : BOOLEAN; REF BS : BSTR ) : BSTR;
VAR
  LV : VARIANTARG;
BEGIN
  oleauto.VariantInit( ADR( LV ));
  IF ( V.vt = wtypes.VT_EMPTY ) OR ( V.vt = wtypes.VT_NULL ) THEN
    LV.bstrVal := NIL;
  ELSE
    oleauto.VariantChangeType( ADR( LV ), oaidl.PVARIANTARG( ADR( V )), 0, CARD16( wtypes.VT_BSTR ));
  END;
  IF BS = NIL THEN
    IF LV.bstrVal <> NIL THEN
      BS := oleauto.SysAllocString( LV.bstrVal );
    END;
  ELSE
    IF LV.bstrVal = NIL THEN
      DisposeBS( REF BS ); 
    ELSE
      oleauto.SysReAllocString( ADR( BS ), LV.bstrVal );
    END;
  END;
  oleauto.VariantClear( ADR( LV ));
  IF ClearVariant THEN
    oleauto.VariantClear( ADR( V ));
  END;
  RETURN BS;
END VariantToBSRef;

(*---------------------------------------------------------------------------*)

PROCEDURE VariantClear( REF V : oaidl.VARIANTARG );
BEGIN
  oleauto.VariantClear( ADR( V ));
END VariantClear;

(*---------------------------------------------------------------------------*)

PROCEDURE New0( CONST CLSID, IID : guiddef.GUID; OUT Object : unknwn.TPIUnknown ) : wtypes.HRESULT;
BEGIN
  IF CLSID = guiddef.CLSID_NULL THEN
    RETURN objbase.CoCreateInstance( IID, NIL, objbase.CLSCTX_ALL, IID, Object );
  ELSE
    RETURN objbase.CoCreateInstance( CLSID, NIL, objbase.CLSCTX_ALL, IID, Object );
  END;
END New0;

(*---------------------------------------------------------------------------*)

PROCEDURE New1( CONST CLSID, IID : TGUID; OUT Object : unknwn.TPIUnknown ) : wtypes.HRESULT;
BEGIN
  IF guiddef.GUID( CLSID ) = guiddef.CLSID_NULL THEN
    RETURN objbase.CoCreateInstance( guiddef.GUID( IID ), NIL, objbase.CLSCTX_ALL, guiddef.GUID( IID ), Object );
  ELSE
    RETURN objbase.CoCreateInstance( guiddef.GUID( CLSID ), NIL, objbase.CLSCTX_ALL, guiddef.GUID( IID ), Object );
  END;
END New1;

(*---------------------------------------------------------------------------*)

PROCEDURE New2( CONST ProgId : ARRAY OF WCHAR; OUT Object : unknwn.TPIUnknown ) : wtypes.HRESULT;
LABEL
  Error;
VAR
  ClassInfo, DefaultInfo : oaidl.TPITypeInfo := NIL;
  CLSID : guiddef.CLSID;
  HRefType : oaidl.HREFTYPE;
  i : INTEGER;
  ImplTypeFlags : CARDINAL;
  ProvideClassInfo : ocidl.TPIProvideClassInfo := NIL;
  TypeAttr, DefaultTypeAttr : oaidl.PTYPEATTR := NIL;
  Result : wtypes.HRESULT;
BEGIN
  Result := objbase.CLSIDFromProgID( wtypes.POLESTR( ADR( ProgId )), ADR( CLSID ));
  IF Result <> 0 THEN
    RETURN Result;
  END;
  Result := New0( CLSID, ocidl.IID_IProvideClassInfo, OUT ProvideClassInfo );
  IF Result <> 0 THEN
    RETURN Result;
  END;
  Result := ProvideClassInfo^.GetClassInfo( ClassInfo );
  IF Result <> 0 THEN
    RETURN Result;
  END;

  Result := ClassInfo^.GetTypeAttr( TypeAttr );
  FOR i := 0 TO INTEGER( TypeAttr^.cImplTypes - 1 ) DO
    IF ( ClassInfo^.GetImplTypeFlags( i, ADR( ImplTypeFlags )) = 0 ) AND ( ImplTypeFlags AND oaidl.IMPLTYPEFLAG_FDEFAULT <> 0 ) THEN
      Result := ClassInfo^.GetRefTypeOfImplType( i, ADR( HRefType ));
      IF Result <> 0 THEN
        GOTO Error;
      END;
      Result := ClassInfo^.GetRefTypeInfo( HRefType, DefaultInfo );
      IF Result <> 0 THEN
        GOTO Error;
      END;
      EXIT;
    END;
  END; // FOR
  
  Result := DefaultInfo^.GetTypeAttr( DefaultTypeAttr );
  IF Result <> 0 THEN
    GOTO Error;
  END;
  Result := New0( CLSID, DefaultTypeAttr^.guid, OUT Object );

Error:
  IF DefaultTypeAttr <> NIL THEN
    DefaultInfo^.ReleaseTypeAttr( DefaultTypeAttr );
  END;
  IF DefaultInfo <> NIL THEN
    DefaultInfo^.Release();
  END;
  IF TypeAttr <> NIL THEN
    ClassInfo^.ReleaseTypeAttr( TypeAttr );
  END;
  IF ClassInfo <> NIL THEN
    ClassInfo^.Release();
  END;
  IF ProvideClassInfo <> NIL THEN
    ProvideClassInfo^.Release();
  END;
    
  RETURN Result;
END New2;

(*===========================================================================*)

PROCEDURE DbgOutIID( String : ARRAY OF WCHAR; POwner : ADDRESS; riid : guiddef.IID );
VAR
  PBSTR : wtypes.BSTR;
  s : ARRAY [0..127] OF WCHAR;
BEGIN
  Strings.FromCARD32W( CARDINAL( POwner ), 16, OUT s );
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
  Strings.FromCARD32W( CARDINAL( PInterface ), 16, OUT s );
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

END com.
