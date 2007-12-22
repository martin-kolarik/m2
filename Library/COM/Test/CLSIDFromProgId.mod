MODULE CLSIDFromProgId;

IMPORT
  com,
  guiddef,
  oaidl,
  objbase,
  ocidl,
  unknwn,
  xmlDOM;

  PROCEDURE wmain() : INTEGER;
  VAR
    Object : com.TPIUnknown;
  BEGIN
    objbase.CoInitialize( NIL );
    com.New1( com.TGUID( xmlDOM.CLSID_DOMDocument40 ), com.TGUID( xmlDOM.IID_IXMLDOMDocument ), OUT Object );
    com.New2( L"Msxml2.DOMDocument.3.0", OUT Object );
    RETURN 0;
  END wmain;

END CLSIDFromProgId.
