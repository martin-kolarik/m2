IMPLEMENTATION MODULE XMLReader;

FROM Debug IMPORT
   Assertion;

FROM Storage IMPORT
   REALLOCATE;

IMPORT
   guiddef,
   com,
   objidl,
	Strings,
	Sync,
	windows,
	winerror,
	wtypes,
	xmlLITE;

(*===========================================================================*)

TYPE
   TPMalloc = POINTER TO CMalloc;

# save, call( convention => stdcall ) *)
CLASS CMalloc( com.CIUnknown ) IMPLEMENTS objidl.IMalloc;
   LOCAL VAR
      Commit : CARDINAL;
      Limit : CARDINAL;

   // IUnknown
   PUBLIC VIRTUAL PROCEDURE QueryInterface( CONST riid : guiddef.IID; ppvObject : PADDRESS ) : wtypes.HRESULT;
   PUBLIC VIRTUAL PROCEDURE AddRef() : windows.ULONG;
   PUBLIC VIRTUAL PROCEDURE Release() : windows.ULONG;

   // IMalloc
   PUBLIC VIRTUAL PROCEDURE Alloc( cb : windows.ULONG ): windows.PVOID;
   PUBLIC VIRTUAL PROCEDURE Realloc( pv : windows.PVOID; cb : windows.ULONG ): windows.PVOID;
   PUBLIC VIRTUAL PROCEDURE Free( pv : windows.PVOID );
   PUBLIC VIRTUAL PROCEDURE GetSize( pv : windows.PVOID ) : windows.ULONG;
   PUBLIC VIRTUAL PROCEDURE DidAlloc( pv : windows.PVOID ) : windows.INT;
   PUBLIC VIRTUAL PROCEDURE HeapMinimize();

END CMalloc;
# restore

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CMalloc;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE QueryInterface( CONST riid : guiddef.IID; ppvObject : PADDRESS ) : wtypes.HRESULT;
   BEGIN
      IF ppvObject = NIL THEN
         RETURN winerror.E_INVALIDARG;
      ELSIF riid = IID THEN
			AddRef();
         ppvObject^ := ADR( SELF.IMalloc );
         RETURN winerror.S_OK;
      ELSE
         RETURN SUPER.QueryInterface( riid, ppvObject );
      END;
   END QueryInterface;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE AddRef() : windows.ULONG;
   BEGIN
      RETURN SUPER.AddRef();
   END AddRef;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Release() : windows.ULONG;
   BEGIN
      RETURN SUPER.Release();
   END Release;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Alloc( cb : windows.ULONG ): windows.PVOID;
   VAR
      a : ADDRESS;
   BEGIN
      IF Commit + cb > Limit THEN
         RETURN NIL;
      ELSE
         INC( Commit, cb );
         ALLOCATE( a, cb );
         RETURN a;
      END;
   END Alloc;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Realloc( pv : windows.PVOID; cb : windows.ULONG ): windows.PVOID;
   BEGIN
      REALLOCATE( pv, cb );
      RETURN pv;
   END Realloc;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Free( pv : windows.PVOID );
   BEGIN
      DEALLOCATE( pv );
   END Free;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE GetSize( pv : windows.PVOID ) : windows.ULONG;
   BEGIN
      RETURN 0;
   END GetSize;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE DidAlloc( pv : windows.PVOID ) : windows.INT;
   BEGIN
      RETURN -1;
   END DidAlloc;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE HeapMinimize();
   BEGIN
   END HeapMinimize;

(*---------------------------------------------------------------------------*)

BEGIN
   IID := objidl.IID_IMalloc;
   Commit := 0;
   Limit := -1;
   AddRef();
END CMalloc;

(*===========================================================================*)

TYPE
   TPStream = POINTER TO CStream;

# save, call( convention => stdcall ) *)
CLASS CStream( com.CIUnknown ) IMPLEMENTS objidl.ISequentialStream;
   LOCAL VAR
      Stream : IOO.TPStream;

   // IUnknown
   PUBLIC VIRTUAL PROCEDURE QueryInterface( CONST riid : guiddef.IID; ppvObject : PADDRESS ) : wtypes.HRESULT;
   PUBLIC VIRTUAL PROCEDURE AddRef() : windows.ULONG;
   PUBLIC VIRTUAL PROCEDURE Release() : windows.ULONG;

   // ISequentialStream
   PUBLIC VIRTUAL PROCEDURE Read( pv : ADDRESS; cb : windows.ULONG; pcbRead : windows.PULONG ) : wtypes.HRESULT;
   PUBLIC VIRTUAL PROCEDURE Write( CONST pv : ADDRESS; cb : windows.ULONG; pcbWritten : windows.PULONG ) : wtypes.HRESULT;

END CStream;
# restore

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CStream;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE QueryInterface( CONST riid : guiddef.IID; ppvObject : PADDRESS ) : wtypes.HRESULT;
   BEGIN
      IF ppvObject = NIL THEN
         RETURN winerror.E_INVALIDARG;
      ELSIF riid = IID THEN
			AddRef();
         ppvObject^ := ADR( SELF.ISequentialStream );
         RETURN winerror.S_OK;
      ELSE
         RETURN SUPER.QueryInterface( riid, ppvObject );
      END;
   END QueryInterface;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE AddRef() : windows.ULONG;
   BEGIN
      RETURN SUPER.AddRef();
   END AddRef;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Release() : windows.ULONG;
   BEGIN
      RETURN SUPER.Release();
   END Release;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Read( pv : ADDRESS; cb : windows.ULONG; pcbRead : windows.PULONG ) : wtypes.HRESULT;
   VAR
      filled : CARDINAL;
      Result : Sync.TAsyncResult;
   BEGIN
      IF Stream = NIL THEN
         IF pcbRead <> NIL THEN
            pcbRead^ := 0;
         END;
         RETURN winerror.S_FALSE;
      ELSE
         Result := Stream^.ReadOA( REF OA( cb-1, pv ), OUT filled, Sync.FORSAFETY );
         CASE Result OF
         | Sync.arCompleted, Sync.arPartCompleted :
            IF pcbRead <> NIL THEN
               pcbRead^ := filled;
            END;
            RETURN winerror.S_OK;
         | Sync.arNoData :
            IF pcbRead <> NIL THEN
               pcbRead^ := 0;
            END;
            RETURN winerror.S_FALSE;
         END;
         RETURN winerror.ERROR_ACCESS_DENIED;
      END;
   END Read;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Write( CONST pv : ADDRESS; cb : windows.ULONG; pcbWritten : windows.PULONG ) : wtypes.HRESULT;
   BEGIN
      RETURN winerror.E_NOTIMPL;
   END Write;

(*---------------------------------------------------------------------------*)

BEGIN
   IID := objidl.IID_ISequentialStream;
   Stream := NIL;
   AddRef();
END CStream;

(*===========================================================================*)

PROCEDURE GetErrorText( xmle : TXMLError; OUT Error : StringsO.CString );
BEGIN
   ASSERT( FALSE ); // not implemented yet
END GetErrorText;

(*===========================================================================*)

CLASS IMPLEMENTATION CXMLReader;

(*---------------------------------------------------------------------------*)

	PUBLIC PROPERTY Stream GET : IOO.TPStream;
	BEGIN
		RETURN _Stream;
	END Stream;

(*---------------------------------------------------------------------------*)

	PUBLIC PROPERTY Stream SET( Value : IOO.TPStream );
	BEGIN
		_Stream := Value;
		Reset();
	END Stream;

(*---------------------------------------------------------------------------*)

	PUBLIC PROPERTY EOF GET : BOOLEAN;
   BEGIN
      RETURN ( _IReader = NIL ) OR ( xmlLITE.TPIXmlReader( _IReader )^.IsEOF() = windows.True );
   END EOF;

(*---------------------------------------------------------------------------*)

	PUBLIC PROPERTY CurrentType GET : TNodeType;
	VAR
	   nt : xmlLITE.XmlNodeType;
   BEGIN
      IF ( _IReader = NIL ) OR ( xmlLITE.TPIXmlReader( _IReader )^.IsEOF() = windows.True ) THEN
         RETURN xntUnknown;
      END;
      IF xmlLITE.TPIXmlReader( _IReader )^.GetNodeType( OUT nt ) = winerror.S_OK THEN
         CASE nt OF
         | xmlLITE.XmlNodeType_None :
            RETURN xntUnknown;
         | xmlLITE.XmlNodeType_Element :
            RETURN xntElementBegin;
         | xmlLITE.XmlNodeType_Attribute :
            RETURN xntAttribute;
         | xmlLITE.XmlNodeType_Text :
            RETURN xntText;
         | xmlLITE.XmlNodeType_CDATA :
            RETURN xntCDATA;
         | xmlLITE.XmlNodeType_ProcessingInstruction :
            RETURN xntProcessingInstruction;
         | xmlLITE.XmlNodeType_Comment :
            RETURN xntComment;
         | xmlLITE.XmlNodeType_DocumentType :
            RETURN xntDocumentType;
         | xmlLITE.XmlNodeType_Whitespace :
            RETURN xntWhitespace;
         | xmlLITE.XmlNodeType_EndElement :
            RETURN xntElementEnd;
         | xmlLITE.XmlNodeType_XmlDeclaration :
            RETURN xntXMLDeclaration;
         END; // CASE
      END;
      RETURN xntUnknown;
   END CurrentType;

(*---------------------------------------------------------------------------*)

	PUBLIC PROPERTY CurrentEmpty GET : BOOLEAN;
   BEGIN
      IF ( _IReader = NIL ) OR ( xmlLITE.TPIXmlReader( _IReader )^.IsEOF() = windows.True ) THEN
         RETURN FALSE;
      END;
      RETURN xmlLITE.TPIXmlReader( _IReader )^.IsEmptyElement() = windows.True;
   END CurrentEmpty;

(*---------------------------------------------------------------------------*)

	PUBLIC PROPERTY CurrentName GET : StringsO.CString;	
	VAR
	   l : windows.UINT;
	   pch : windows.PCWSTR;
	   s : StringsO.CString;
   BEGIN
      IF ( _IReader = NIL ) OR ( xmlLITE.TPIXmlReader( _IReader )^.IsEOF() = windows.True ) THEN
         RETURN s;
      END;
      IF xmlLITE.TPIXmlReader( _IReader )^.GetLocalName( OUT pch, OUT l ) = winerror.S_OK THEN
         s.FromOA( OA( l-1, pch ));
      END;
      RETURN s;
   END CurrentName;

(*---------------------------------------------------------------------------*)

	PUBLIC PROPERTY CurrentNamespace GET : StringsO.CString;	
	VAR
	   l : windows.UINT;
	   pch : windows.PCWSTR;
	   s : StringsO.CString;
   BEGIN
      IF ( _IReader = NIL ) OR ( xmlLITE.TPIXmlReader( _IReader )^.IsEOF() = windows.True ) THEN
         RETURN s;
      END;
      IF xmlLITE.TPIXmlReader( _IReader )^.GetNamespaceUri( OUT pch, OUT l ) = winerror.S_OK THEN
         s.FromOA( OA( l-1, pch ));
      END;
      RETURN s;
   END CurrentNamespace;

(*---------------------------------------------------------------------------*)

	PUBLIC PROPERTY CurrentPrefix GET : StringsO.CString;	
	VAR
	   l : windows.UINT;
	   pch : windows.PCWSTR;
	   s : StringsO.CString;
   BEGIN
      IF ( _IReader = NIL ) OR ( xmlLITE.TPIXmlReader( _IReader )^.IsEOF() = windows.True ) THEN
         RETURN s;
      END;
      IF xmlLITE.TPIXmlReader( _IReader )^.GetPrefix( OUT pch, OUT l ) = winerror.S_OK THEN
         s.FromOA( OA( l-1, pch ));
      END;
      RETURN s;
   END CurrentPrefix;

(*---------------------------------------------------------------------------*)

	PUBLIC PROPERTY CurrentQualifiedName GET : StringsO.CString;	
	VAR
	   l : CARDINAL;
	   pch : windows.PCWSTR;
	   s : StringsO.CString;
   BEGIN
      IF ( _IReader = NIL ) OR ( xmlLITE.TPIXmlReader( _IReader )^.IsEOF() = windows.True ) THEN
         RETURN s;
      END;
      IF xmlLITE.TPIXmlReader( _IReader )^.GetQualifiedName( OUT pch, OUT l ) = winerror.S_OK THEN
         s.FromOA( OA( l-1, pch ));
      END;
      RETURN s;
   END CurrentQualifiedName;

(*---------------------------------------------------------------------------*)

	PUBLIC PROPERTY CurrentValue GET : StringsO.CString;
	VAR
	   l : CARDINAL;
	   pch : windows.PCWSTR;
	   s : StringsO.CString;
   BEGIN
      IF ( _IReader = NIL ) OR ( xmlLITE.TPIXmlReader( _IReader )^.IsEOF() = windows.True ) THEN
         RETURN s;
      END;
      IF xmlLITE.TPIXmlReader( _IReader )^.GetValue( OUT pch, OUT l ) = winerror.S_OK THEN
         s.FromOA( OA( l-1, pch ));
      END;
      RETURN s;
   END CurrentValue;
	   
(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY CurrentDepth GET : CARDINAL;
   BEGIN
      IF ( _IReader = NIL ) OR ( xmlLITE.TPIXmlReader( _IReader )^.IsEOF() = windows.True ) THEN
         RETURN 0;
      ELSE
         RETURN xmlLITE.TPIXmlReader( _IReader )^.GetDepth();
      END;
   END CurrentDepth;

(*---------------------------------------------------------------------------*)

	PUBLIC PROCEDURE Reset();
	VAR
	   malloc : TPMalloc;
	   stream : TPStream;
	BEGIN
	   IF _Stream <> NIL THEN
	      _Stream^.Position := 0;
	   END;

	   IF _IMalloc = NIL THEN
	      NEW( malloc );
         _IMalloc := malloc;
	   END;
	   IF _IStream = NIL THEN
	      NEW( stream );
         _IStream := stream;
	   END;
	   stream^.Stream := _Stream;

	   IF _IReader <> NIL THEN
	      xmlLITE.TPIXmlReader( _IReader )^.Release();
	      _IReader := NIL;
	   END;
	   IF xmlLITE.CreateXmlReader( xmlLITE.IID_IXmlReader, OUT _IReader, TPMalloc( _IMalloc )) = winerror.S_OK THEN
	      xmlLITE.TPIXmlReader( _IReader )^.SetInput( ADR( stream^.CIUnknown ));
	   ELSE
	      _IReader := NIL;
	   END;
	END Reset;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE MoveNext() : TXMLError;
   VAR
      nt : xmlLITE.XmlNodeType;
   BEGIN
      IF ( _IReader = NIL ) OR ( xmlLITE.TPIXmlReader( _IReader )^.IsEOF() = windows.True ) THEN
         RETURN xmle_S_FALSE;
      END;
      RETURN Error2Error( xmlLITE.TPIXmlReader( _IReader )^.Read( OUT nt ));
   END MoveNext;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE MoveToElement() : TXMLError;
   BEGIN
      IF ( _IReader = NIL ) OR ( xmlLITE.TPIXmlReader( _IReader )^.IsEOF() = windows.True ) THEN
         RETURN xmle_S_FALSE;
      END;
      RETURN Error2Error( xmlLITE.TPIXmlReader( _IReader )^.MoveToElement());
   END MoveToElement;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE MoveToFirstAttribute() : TXMLError;
   BEGIN
      IF ( _IReader = NIL ) OR ( xmlLITE.TPIXmlReader( _IReader )^.IsEOF() = windows.True ) THEN
         RETURN xmle_S_FALSE;
      END;
      RETURN Error2Error( xmlLITE.TPIXmlReader( _IReader )^.MoveToFirstAttribute());
   END MoveToFirstAttribute;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE MoveToNextAttribute() : TXMLError;
   BEGIN
      IF ( _IReader = NIL ) OR ( xmlLITE.TPIXmlReader( _IReader )^.IsEOF() = windows.True ) THEN
         RETURN xmle_S_FALSE;
      END;
      RETURN Error2Error( xmlLITE.TPIXmlReader( _IReader )^.MoveToNextAttribute());
   END MoveToNextAttribute;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE MoveToAttributeByName( CONST Name : StringsO.IString ) : TXMLError;
   BEGIN
      IF ( _IReader = NIL ) OR ( xmlLITE.TPIXmlReader( _IReader )^.IsEOF() = windows.True ) THEN
         RETURN xmle_S_FALSE;
      END;
      RETURN Error2Error( xmlLITE.TPIXmlReader( _IReader )^.MoveToAttributeByName( Name.szData, NIL ));
   END MoveToAttributeByName;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE MoveToAttributeByNameOA( CONST Name : ARRAY OF WCHAR ) : TXMLError;
   VAR
      s : StringsO.CString;
   BEGIN
      IF ( _IReader = NIL ) OR ( xmlLITE.TPIXmlReader( _IReader )^.IsEOF() = windows.True ) THEN
         RETURN xmle_S_FALSE;
      END;
      s.FromOA( Name );
      RETURN MoveToAttributeByName( s );
   END MoveToAttributeByNameOA;

(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Error2Error( Error : CARDINAL ) : TXMLError;
   BEGIN
      CASE Error OF
      | winerror.S_OK : RETURN xmle_S_OK;
      | winerror.S_FALSE : RETURN xmle_S_FALSE;
      END;
   
      CASE xmlLITE.XmlError( Error ) OF
      | xmlLITE.MX_E_INPUTEND : RETURN xmle_MX_E_INPUTEND;
      | xmlLITE.MX_E_ENCODING : RETURN xmle_MX_E_ENCODING;
      | xmlLITE.MX_E_ENCODINGSWITCH : RETURN xmle_MX_E_ENCODINGSWITCH;
      | xmlLITE.MX_E_ENCODINGSIGNATURE : RETURN xmle_MX_E_ENCODINGSIGNATURE;
       
      | xmlLITE.WC_E_WHITESPACE : RETURN xmle_WC_E_WHITESPACE;
      | xmlLITE.WC_E_SEMICOLON : RETURN xmle_WC_E_SEMICOLON;
      | xmlLITE.WC_E_GREATERTHAN : RETURN xmle_WC_E_GREATERTHAN;
      | xmlLITE.WC_E_QUOTE : RETURN xmle_WC_E_QUOTE;
      | xmlLITE.WC_E_EQUAL : RETURN xmle_WC_E_EQUAL;
      | xmlLITE.WC_E_LESSTHAN : RETURN xmle_WC_E_LESSTHAN;
      | xmlLITE.WC_E_HEXDIGIT : RETURN xmle_WC_E_HEXDIGIT;
      | xmlLITE.WC_E_DIGIT : RETURN xmle_WC_E_DIGIT;
      | xmlLITE.WC_E_LEFTBRACKET : RETURN xmle_WC_E_LEFTBRACKET;
      | xmlLITE.WC_E_LEFTPAREN : RETURN xmle_WC_E_LEFTPAREN;
      | xmlLITE.WC_E_XMLCHARACTER : RETURN xmle_WC_E_XMLCHARACTER;
      | xmlLITE.WC_E_NAMECHARACTER : RETURN xmle_WC_E_NAMECHARACTER;
      | xmlLITE.WC_E_SYNTAX : RETURN xmle_WC_E_SYNTAX;
      | xmlLITE.WC_E_CDSECT : RETURN xmle_WC_E_CDSECT;
      | xmlLITE.WC_E_COMMENT : RETURN xmle_WC_E_COMMENT;
      | xmlLITE.WC_E_CONDSECT : RETURN xmle_WC_E_CONDSECT;
      | xmlLITE.WC_E_DECLATTLIST : RETURN xmle_WC_E_DECLATTLIST;
      | xmlLITE.WC_E_DECLDOCTYPE : RETURN xmle_WC_E_DECLDOCTYPE;
      | xmlLITE.WC_E_DECLELEMENT : RETURN xmle_WC_E_DECLELEMENT;
      | xmlLITE.WC_E_DECLENTITY : RETURN xmle_WC_E_DECLENTITY;
      | xmlLITE.WC_E_DECLNOTATION : RETURN xmle_WC_E_DECLNOTATION;
      | xmlLITE.WC_E_NDATA : RETURN xmle_WC_E_NDATA;
      | xmlLITE.WC_E_PUBLIC : RETURN xmle_WC_E_PUBLIC;
      | xmlLITE.WC_E_SYSTEM : RETURN xmle_WC_E_SYSTEM;
      | xmlLITE.WC_E_NAME : RETURN xmle_WC_E_NAME;
      | xmlLITE.WC_E_ROOTELEMENT : RETURN xmle_WC_E_ROOTELEMENT;
      | xmlLITE.WC_E_ELEMENTMATCH : RETURN xmle_WC_E_ELEMENTMATCH;
      | xmlLITE.WC_E_UNIQUEATTRIBUTE : RETURN xmle_WC_E_UNIQUEATTRIBUTE;
      | xmlLITE.WC_E_TEXTXMLDECL : RETURN xmle_WC_E_TEXTXMLDECL;
      | xmlLITE.WC_E_LEADINGXML : RETURN xmle_WC_E_LEADINGXML;
      | xmlLITE.WC_E_TEXTDECL : RETURN xmle_WC_E_TEXTDECL;
      | xmlLITE.WC_E_XMLDECL : RETURN xmle_WC_E_XMLDECL;
      | xmlLITE.WC_E_ENCNAME : RETURN xmle_WC_E_ENCNAME;
      | xmlLITE.WC_E_PUBLICID : RETURN xmle_WC_E_PUBLICID;
      | xmlLITE.WC_E_PESINTERNALSUBSET : RETURN xmle_WC_E_PESINTERNALSUBSET;
      | xmlLITE.WC_E_PESBETWEENDECLS : RETURN xmle_WC_E_PESBETWEENDECLS;
      | xmlLITE.WC_E_NORECURSION : RETURN xmle_WC_E_NORECURSION;
      | xmlLITE.WC_E_ENTITYCONTENT : RETURN xmle_WC_E_ENTITYCONTENT;
      | xmlLITE.WC_E_UNDECLAREDENTITY : RETURN xmle_WC_E_UNDECLAREDENTITY;
      | xmlLITE.WC_E_PARSEDENTITY : RETURN xmle_WC_E_PARSEDENTITY;
      | xmlLITE.WC_E_NOEXTERNALENTITYREF : RETURN xmle_WC_E_NOEXTERNALENTITYREF;
      | xmlLITE.WC_E_PI : RETURN xmle_WC_E_PI;
      | xmlLITE.WC_E_SYSTEMID : RETURN xmle_WC_E_SYSTEMID;
      | xmlLITE.WC_E_QUESTIONMARK : RETURN xmle_WC_E_QUESTIONMARK;
      | xmlLITE.WC_E_CDSECTEND : RETURN xmle_WC_E_CDSECTEND;
      | xmlLITE.WC_E_MOREDATA : RETURN xmle_WC_E_MOREDATA;
      | xmlLITE.WC_E_DTDPROHIBITED : RETURN xmle_WC_E_DTDPROHIBITED;
      | xmlLITE.WC_E_INVALIDXMLSPACE : RETURN xmle_WC_E_INVALIDXMLSPACE;
       
      | xmlLITE.NC_E_QNAMECHARACTER : RETURN xmle_NC_E_QNAMECHARACTER;
      | xmlLITE.NC_E_QNAMECOLON : RETURN xmle_NC_E_QNAMECOLON;
      | xmlLITE.NC_E_NAMECOLON : RETURN xmle_NC_E_NAMECOLON;
      | xmlLITE.NC_E_DECLAREDPREFIX : RETURN xmle_NC_E_DECLAREDPREFIX;
      | xmlLITE.NC_E_UNDECLAREDPREFIX : RETURN xmle_NC_E_UNDECLAREDPREFIX;
      | xmlLITE.NC_E_EMPTYURI : RETURN xmle_NC_E_EMPTYURI;
      | xmlLITE.NC_E_XMLPREFIXRESERVED : RETURN xmle_NC_E_XMLPREFIXRESERVED;
      | xmlLITE.NC_E_XMLNSPREFIXRESERVED : RETURN xmle_NC_E_XMLNSPREFIXRESERVED;
      | xmlLITE.NC_E_XMLURIRESERVED : RETURN xmle_NC_E_XMLURIRESERVED;
      | xmlLITE.NC_E_XMLNSURIRESERVED : RETURN xmle_NC_E_XMLNSURIRESERVED;
       
      | xmlLITE.SC_E_MAXELEMENTDEPTH : RETURN xmle_SC_E_MAXELEMENTDEPTH;
      | xmlLITE.SC_E_MAXENTITYEXPANSION : RETURN xmle_SC_E_MAXENTITYEXPANSION;
       
      | xmlLITE.WR_E_NONWHITESPACE : RETURN xmle_WR_E_NONWHITESPACE;
      | xmlLITE.WR_E_NSPREFIXDECLARED : RETURN xmle_WR_E_NSPREFIXDECLARED;
      | xmlLITE.WR_E_NSPREFIXWITHEMPTYNSURI : RETURN xmle_WR_E_NSPREFIXWITHEMPTYNSURI;
      | xmlLITE.WR_E_DUPLICATEATTRIBUTE : RETURN xmle_WR_E_DUPLICATEATTRIBUTE;
      | xmlLITE.WR_E_XMLNSPREFIXDECLARATION : RETURN xmle_WR_E_XMLNSPREFIXDECLARATION;
      | xmlLITE.WR_E_XMLPREFIXDECLARATION : RETURN xmle_WR_E_XMLPREFIXDECLARATION;
      | xmlLITE.WR_E_XMLURIDECLARATION : RETURN xmle_WR_E_XMLURIDECLARATION;
      | xmlLITE.WR_E_XMLNSURIDECLARATION : RETURN xmle_WR_E_XMLNSURIDECLARATION;
      | xmlLITE.WR_E_NAMESPACEUNDECLARED : RETURN xmle_WR_E_NAMESPACEUNDECLARED;
      | xmlLITE.WR_E_INVALIDXMLSPACE : RETURN xmle_WR_E_INVALIDXMLSPACE;
      | xmlLITE.WR_E_INVALIDACTION : RETURN xmle_WR_E_INVALIDACTION;
      | xmlLITE.WR_E_INVALIDSURROGATEPAIR : RETURN xmle_WR_E_INVALIDSURROGATEPAIR;
       
      | xmlLITE.XML_E_INVALID_DECIMAL : RETURN xmle_XML_E_INVALID_DECIMAL;
      | xmlLITE.XML_E_INVALID_HEXIDECIMAL : RETURN xmle_XML_E_INVALID_HEXIDECIMAL;
      | xmlLITE.XML_E_INVALID_UNICODE : RETURN xmle_XML_E_INVALID_UNICODE;
      END;

      RETURN xmle_UNSPECIFIED;
   END Error2Error;

(*---------------------------------------------------------------------------*)

BEGIN
	_Stream := NIL;
   _IMalloc := NIL;
   _IStream := NIL;
   _IReader := NIL;
FINALLY
   IF _IReader <> NIL THEN
      xmlLITE.TPIXmlReader( _IReader )^.Release();
      _IReader := NIL;
   END;
   IF _IStream <> NIL THEN
      TPStream( _IStream )^.Release();
      _IStream := NIL;
   END;
   IF _IMalloc <> NIL THEN
      TPMalloc( _IMalloc )^.Release();
      _IMalloc := NIL;
   END;
END CXMLReader;

(*===========================================================================*)

END XMLReader.