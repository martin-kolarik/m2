IMPLEMENTATION MODULE Resources;

FROM Storage IMPORT
  ALLOCATE, REALLOCATE, DEALLOCATE;
  
IMPORT
  FIO,
  maps,
  Strings,
  Storage;
  
IMPORT
  com,
  xmlDOM;

//===========================================================================

CONST
  binMagic = 0BCAF1548H;
  binVersion = 10000H;
  
CONST
  fallback = L'?unknown text';

TYPE
  TText         = RECORD
                    Length : CARDINAL;
                    CASE : CARDINAL OF
                    | 0 : Text   : PWCHAR;
                    | 1 : Offset : CARDINAL;
                    END; // CASE
                  END;
  TPTexts       = POINTER TO ARRAY [0..0] OF TText;
  TLanguageSlot = RECORD
                    Lang : Languages.TLanguage;
                    CASE : CARDINAL OF
                    | 0 : Texts  : TPTexts;
                    | 1 : Offset : CARDINAL;
                    END;
                  END;
  TPSlots       = POINTER TO ARRAY [0..0] OF TLanguageSlot;
  TResourceData = RECORD
                    BinMagic        : CARDINAL;
                    BinLength       : CARDINAL; // over all block
                    BinVersion      : CARDINAL;
                    DataVersion     : ARRAY [0..31] OF WCHAR;
                    DefaultLanguage : CARDINAL;
                    SlotCount       : CARDINAL;
                    TextCount       : CARDINAL;
                    CASE : CARDINAL OF
                    | 0 : Slots   : TPSlots;
                          Strings : PWCHAR;
                    | 1 : OffsetL : CARDINAL;
                          OffsetS : CARDINAL;
                    END; // CASE
                  END;
  TResource     = POINTER TO TResourceData;

//---------------------------------------------------------------------------

CLASS IMPLEMENTATION CResources;

//---------------------------------------------------------------------------

  PUBLIC PROPERTY Lang GET : Languages.TLanguage;
  BEGIN
    RETURN _Lang;
  END Lang;

//---------------------------------------------------------------------------

  PUBLIC PROPERTY Lang SET( Value : Languages.TLanguage );
  VAR
    Index : CARDINAL;
    _LLang : Languages.TLanguage := _Lang;
  BEGIN
    _Texts := NIL;
    IF _Resource = NIL THEN
      _Lang := Value;
    ELSIF SearchLanguage( Value, OUT Index ) THEN
      _Lang := Value;
      IF Languages.LanguageToRFC1766( _Lang, OUT _RFC1766 ) THEN
        _Texts := _Stub^.Slots^[ Index ].Texts;
      ELSE
        _RFC1766 := L'';
      END;
    ELSE
      _Lang := 0;
      _RFC1766 := L'';
    END;
    IF _Lang <> _LLang THEN // _Lang was changed
      Notify( TRUE, FALSE );
    END;
  END Lang;

//---------------------------------------------------------------------------

  PUBLIC PROPERTY RFC1766 GET : Languages.TRFC1766;
  BEGIN
    RETURN _RFC1766;
  END RFC1766;

//---------------------------------------------------------------------------

  PUBLIC PROPERTY RFC1766 SET( CONST Value : Languages.TRFC1766 );
  VAR
    L : Languages.TLanguage;
  BEGIN
    IF Languages.RFC1766ToLanguage( Value, OUT L ) THEN
      Lang := L;
    ELSE
      _Lang := 0;
      _RFC1766 := L'';
    END;
  END RFC1766;

//---------------------------------------------------------------------------

  PUBLIC PROPERTY FallbackLang GET : Languages.TLanguage;
  BEGIN
    RETURN _FallbackLang;
  END FallbackLang;

//---------------------------------------------------------------------------

  PUBLIC PROPERTY FallbackLang SET( Value : Languages.TLanguage );
  VAR
    Index : CARDINAL;
  BEGIN
    IF _FallbackLang = Value THEN
      RETURN;
    END;
    IF SearchLanguage( Value, OUT Index ) THEN
      _FallbackLang := Value;
      _FallbackTexts := _Stub^.Slots^[ Index ].Texts;
    ELSE
      _FallbackLang := 0;
      _FallbackTexts := NIL;
    END;
    Notify( FALSE, TRUE );
  END FallbackLang;

//---------------------------------------------------------------------------

  PUBLIC INDEX CResources GET( Id : CARDINAL ) : PWCHAR; // zero-terminated
  BEGIN
    IF ( _Resource <> NIL ) AND ( Id < _Resource^.TextCount ) THEN
      IF _Texts = NIL THEN // fall down
      ELSIF TPTexts( _Texts )^[ Id ].Text <> NIL THEN
        RETURN TPTexts( _Texts )^[ Id ].Text;
      ELSIF _FallbackTexts = NIL THEN // fall down
      ELSIF TPTexts( _FallbackTexts )^[ Id ].Text <> NIL THEN
        RETURN TPTexts( _FallbackTexts )^[ Id ].Text;
      END;
    END;
    IF GlobalFallback THEN
      RETURN PWCHAR( ADR( fallback ));
    ELSE
      RETURN NIL;
    END;
  END CResources;
    
//---------------------------------------------------------------------------

  PUBLIC PROCEDURE LoadRES1( HModule : windows.HANDLE; CONST ResourceName : ARRAY OF WCHAR ) : BOOLEAN;
  VAR
    ResInfo : windows.HRSRC;
  BEGIN
    _Strings.Dispose();

    CASE _Mode OF
    | rmSelfMemory :
      DISPOSE( _Resource );
    | rmResource :
      windows.FreeResource( _HResource );
      _Resource := NIL;
    END;

    IF HModule = NIL THEN
      HModule := windows.GetModuleHandle( NIL );
    END;
    ResInfo := windows.FindResource( HModule, ADR( ResourceName ), windows.PWSTR( windows.RT_RCDATA ));
    IF ResInfo = NIL THEN
      RETURN FALSE;
    END;
    _HResource := windows.LoadResource( HModule, ResInfo );
    IF _HResource = NIL THEN
      RETURN FALSE;
    END;
    _Resource := windows.LockResource( _HResource );
    IF _Resource = NIL THEN
      RETURN FALSE;
    END;
    _Mode := rmResource;
    ASSIGN( Name, ResourceName );
    
    ResToStub();
    RETURN TRUE;
  END LoadRES1;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE LoadRES2( CONST ModuleName, ResourceName : ARRAY OF WCHAR ) : BOOLEAN;
  VAR
    HModule : windows.HANDLE;
  BEGIN
    HModule := windows.GetModuleHandle( ADR( ModuleName ));
    IF HModule = NIL THEN
      RETURN FALSE;
    END;
    RETURN LoadRES1( HModule, ResourceName );
  END LoadRES2;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE LoadBIN( Path : ARRAY OF WCHAR ) : BOOLEAN;
  VAR
    Bin : TResource;
    f : FIO.File;
    l : CARDINAL;
  BEGIN
    f := FIO.OpenReadW( Path, FIO.TFileShare{FIO.fsRead} );
    IF f = NIL THEN
      RETURN FALSE;
    END;
    l := FIO.Size( f );
    ALLOCATE( Bin, l );
    IF FIO.RdBin( f, Bin^, l ) <> l THEN
       FIO.Close( f );
      RETURN FALSE;
    END;
    FIO.Close( f );
    LoadMemory( Bin, FALSE, rmSelfMemory );
    RETURN TRUE;
  END LoadBIN;
  
//---------------------------------------------------------------------------

  PUBLIC PROCEDURE GetText( Id : CARDINAL; OUT Text : PWCHAR; OUT Length : CARDINAL ) : BOOLEAN;
  BEGIN
    IF ( _Resource <> NIL ) OR ( Id < _Resource^.TextCount ) THEN
      IF _Texts = NIL THEN // fall down
      ELSIF TPTexts( _Texts )^[ Id ].Text <> NIL THEN
        Length := TPTexts( _Texts )^[ Id ].Length;
        Text := TPTexts( _Texts )^[ Id ].Text;
        RETURN TRUE;
      ELSIF _FallbackTexts = NIL THEN // fall down
      ELSIF TPTexts( _FallbackTexts )^[ Id ].Text <> NIL THEN
        Length := TPTexts( _FallbackTexts )^[ Id ].Length;
        Text := TPTexts( _FallbackTexts )^[ Id ].Text;
        RETURN TRUE;
      END;
    END;
    IF GlobalFallback THEN
      Length := SIZE( fallback ) >> 1;
      Text := PWCHAR( ADR( fallback ));
      RETURN TRUE;
    ELSE
      RETURN FALSE;
    END;
  END GetText;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE GetTextL( Language : Languages.TLanguage; Id : CARDINAL; OUT Text : PWCHAR; OUT Length : CARDINAL ) : BOOLEAN;
  VAR
    Index : CARDINAL;
  BEGIN
    IF ( _Resource <> NIL ) AND ( Id < _Resource^.TextCount ) AND SearchLanguage( Language, OUT Index ) THEN
      Length := _Stub^.Slots^[ Index ].Texts^[ Id ].Length;
      Text := _Stub^.Slots^[ Index ].Texts^[ Id ].Text;
    ELSIF GlobalFallback THEN
      Length := SIZE( fallback ) >> 1;
      Text := PWCHAR( ADR( fallback ));
    ELSE
      RETURN FALSE;
    END;
    RETURN TRUE;
  END GetTextL;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE FillText( Id : CARDINAL; OUT Text : ARRAY OF WCHAR ) : BOOLEAN;
  BEGIN
    IF ( _Resource <> NIL ) AND ( Id < _Resource^.TextCount ) THEN
      IF _Texts = NIL THEN // fall down
      ELSIF TPTexts( _Texts )^[ Id ].Text <> NIL THEN
        ASSIGN( Text, OA( TPTexts( _Texts )^[ Id ].Length - 1, TPTexts( _Texts )^[ Id ].Text ));
        RETURN TRUE;
      ELSIF _FallbackTexts = NIL THEN // fall down
      ELSIF TPTexts( _FallbackTexts )^[ Id ].Text <> NIL THEN
        ASSIGN( Text, OA( TPTexts( _FallbackTexts )^[ Id ].Length - 1, TPTexts( _FallbackTexts )^[ Id ].Text ));
        RETURN TRUE;
      END;
    END;
    IF GlobalFallback THEN
      ASSIGN( Text, fallback );
      RETURN TRUE;
    ELSE
      RETURN FALSE;
    END;
  END FillText;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE FillTextL( Language : Languages.TLanguage; Id : CARDINAL; OUT Text : ARRAY OF WCHAR ) : BOOLEAN;
  VAR
    Index : CARDINAL;
  BEGIN
    IF ( _Resource <> NIL ) AND ( Id < _Resource^.TextCount ) AND SearchLanguage( Language, OUT Index ) THEN
      ASSIGN( Text, OA( _Stub^.Slots^[ Index ].Texts^[ Id ].Length - 1, _Stub^.Slots^[ Index ].Texts^[ Id ].Text ));
    ELSIF GlobalFallback THEN
      ASSIGN( Text, fallback );
    ELSE
      RETURN FALSE;
    END;
    RETURN TRUE;
  END FillTextL;
  
//---------------------------------------------------------------------------

  PUBLIC PROCEDURE Text( Id : CARDINAL; Fallback : ARRAY OF WCHAR ) : PWCHAR; // same as []
  BEGIN
    IF ( _Resource <> NIL ) AND ( Id < _Resource^.TextCount ) THEN
      IF _Texts = NIL THEN // fall down
      ELSIF TPTexts( _Texts )^[ Id ].Text <> NIL THEN
        RETURN TPTexts( _Texts )^[ Id ].Text;
      ELSIF _FallbackTexts = NIL THEN // fall down
      ELSIF TPTexts( _FallbackTexts )^[ Id ].Text <> NIL THEN
        RETURN TPTexts( _FallbackTexts )^[ Id ].Text;
      END;
    END;
    IF ( HIGH( Fallback ) <> 0 ) AND ( ADR( Fallback ) <> NIL ) THEN
      RETURN ADR( Fallback );
    ELSIF GlobalFallback THEN
      RETURN PWCHAR( ADR( fallback ));
    ELSE
      RETURN NIL;
    END;
  END Text;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE Length( Id : CARDINAL; Fallback : ARRAY OF WCHAR ) : CARDINAL;
  BEGIN
    IF ( _Resource <> NIL ) OR ( Id < _Resource^.TextCount ) THEN
      IF _Texts = NIL THEN // fall down
      ELSIF TPTexts( _Texts )^[ Id ].Text <> NIL THEN
        RETURN TPTexts( _Texts )^[ Id ].Length;
      ELSIF _FallbackTexts = NIL THEN // fall down
      ELSIF TPTexts( _FallbackTexts )^[ Id ].Text <> NIL THEN
        RETURN TPTexts( _FallbackTexts )^[ Id ].Length;
      END;
    END;
    IF ( HIGH( Fallback ) <> 0 ) AND ( ADR( Fallback ) <> NIL ) THEN
      RETURN LENGTH( Fallback );
    ELSIF GlobalFallback THEN
      RETURN SIZE( fallback ) >> 1;
    ELSE
      RETURN 0;
    END;
  END Length;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE TextL( Language : Languages.TLanguage; Id : CARDINAL; Fallback : ARRAY OF WCHAR ) : PWCHAR; // same as []
  VAR
    Index : CARDINAL;
  BEGIN
    IF ( _Resource <> NIL ) AND ( Id < _Resource^.TextCount ) AND SearchLanguage( Language, OUT Index ) THEN
      RETURN _Stub^.Slots^[ Index ].Texts^[ Id ].Text;
    ELSIF ( HIGH( Fallback ) <> 0 ) AND ( ADR( Fallback ) <> NIL ) THEN
      RETURN ADR( Fallback );
    ELSIF GlobalFallback THEN
      RETURN PWCHAR( ADR( fallback ));
    ELSE
      RETURN NIL;
    END;
  END TextL;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE LengthL( Language : Languages.TLanguage; Id : CARDINAL; Fallback : ARRAY OF WCHAR ) : CARDINAL;
  VAR
    Index : CARDINAL;
  BEGIN
    IF ( _Resource <> NIL ) AND ( Id < _Resource^.TextCount ) AND SearchLanguage( Language, OUT Index ) THEN
      RETURN _Stub^.Slots^[ Index ].Texts^[ Id ].Length;
    ELSIF ( HIGH( Fallback ) <> 0 ) AND ( ADR( Fallback ) <> NIL ) THEN
      RETURN LENGTH( Fallback );
    ELSIF GlobalFallback THEN
      RETURN SIZE( fallback ) >> 1;
    ELSE
      RETURN 0;
    END;
  END LengthL;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE RegisterNotifier( Notifier : TPResourcesNotifier );
  BEGIN
    _Notifiers.Add( Notifier, 0 );
  END RegisterNotifier;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE ForgetNotifier( Notifier : TPResourcesNotifier );
  BEGIN
    _Notifiers.Remove( Notifier );
  END ForgetNotifier;
  
//---------------------------------------------------------------------------

  PRIVATE PROCEDURE SearchLanguage( Language : Languages.TLanguage; OUT Index : CARDINAL ) : BOOLEAN;
  VAR
    i : INTEGER;
  BEGIN
    FOR i := 0 TO INTEGER( _Resource^.SlotCount - 1 ) DO
      IF _Stub^.Slots^[i].Lang = Language THEN
        Index := i;
        RETURN TRUE;
      END;
    END; // FOR
    RETURN FALSE;
  END SearchLanguage;

//---------------------------------------------------------------------------

  PRIVATE PROCEDURE Notify( Lang, Texts : BOOLEAN );
  BEGIN
    IF Lang OR Texts = FALSE THEN
      RETURN;
    END;
    _Notifiers.Reset();
    WHILE _Notifiers.MoveNext() DO
      IF Lang THEN
        TPResourcesNotifier( _Notifiers.Current )^.OnLangChange( ADR( SELF ));
        TPResourcesNotifier( _Notifiers.Current )^.OnTextsChange( ADR( SELF ));
      ELSE // Texts is surely TRUE
        TPResourcesNotifier( _Notifiers.Current )^.OnTextsChange( ADR( SELF ));
      END;
    END; // WHILE
  END Notify;

//---------------------------------------------------------------------------

  INTERNAL PROCEDURE LoadMemory( Bin : TResource; Copy : BOOLEAN; ResultMode : TResourceMode );
  BEGIN
    _Strings.Dispose();
    IF Copy THEN
      CASE _Mode OF
      | rmRefMemory :
        _Resource := NIL;
      | rmResource :
        windows.FreeResource( _HResource );
        _Resource := NIL;
      END;
      _Mode := rmSelfMemory;
      REALLOCATE( _Resource, Bin^.BinLength );
      Storage.Move( Bin, _Resource, Bin^.BinLength );
    ELSE
      CASE _Mode OF
      | rmSelfMemory :
        DISPOSE( _Resource );
      | rmResource :
        windows.FreeResource( _HResource );
        _Resource := NIL;
      END;
      _Mode := ResultMode;
      _Resource := Bin;
    END;
    Name := L'';
    ResToStub();
  END LoadMemory;

//---------------------------------------------------------------------------

  INTERNAL PROCEDURE ResToStub(); 
  VAR
    i, j, l : INTEGER;
  BEGIN
    l := SIZE( TResourceData ) + _Resource^.SlotCount * ( SIZE( TLanguageSlot ) + _Resource^.TextCount * SIZE( TText ));
    REALLOCATE( _Stub, l );
    Storage.Move( _Resource, _Stub, l );
    
    // adjust main offsets
    INC( _Stub^.Slots, PTR( _Stub ));
    INC( _Stub^.Strings, PTR( _Resource ));
    // adjust languages and text offsets
    FOR i := 0 TO INTEGER( _Stub^.SlotCount - 1 ) DO
      INC( _Stub^.Slots^[i].Texts, PTR( _Stub ));
      FOR j := 0 TO INTEGER( _Stub^.TextCount - 1 ) DO
        INC( _Stub^.Slots^[i].Texts^[j].Text, PTR( _Resource ));
      END;
    END;
    
    _Lang := 0; // force to change language data
    Lang := _Stub^.Slots^[0].Lang;
  END ResToStub;

//---------------------------------------------------------------------------

BEGIN
  _Resource := NIL;
  _Stub := NIL;
  _Mode := rmUnknown;
  _HResource := NIL;
  _Lang := 0;
  _FallbackLang := 0;
  _RFC1766 := L'';
  _Texts := NIL;
  _FallbackTexts := NIL;
  Name := L'';
  GlobalFallback := TRUE;
FINALLY
  CASE _Mode OF
  | rmSelfMemory :
    DISPOSE( _Resource );
  | rmResource :
    windows.FreeResource( _HResource );
  END;
  DISPOSE( _Stub );
END CResources;

//===========================================================================

CLASS IMPLEMENTATION CResourcesCreator;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE LoadXML( CONST Path : ARRAY OF WCHAR; OUT ErrorText : ARRAY OF WCHAR ) : BOOLEAN;
  VAR
    _DefaultLanguage : Languages.TLanguage := 0;
    _Langs : lists.CIntegerList;
    _Pool : ADDRESS := NIL;
    _PoolAllocated : CARDINAL := 0;
    _PoolBytes : CARDINAL := 0;
    _TextsAllocated : CARDINAL := 0;
    _Version : com.BSTR := NIL;

  //-----

    PROCEDURE AddString( CONST String : ARRAY OF WCHAR; OUT ErrorString : ARRAY OF WCHAR ) : BOOLEAN;
    VAR
      L : CARDINAL;
      ptr : PTR;
    BEGIN
      IF _Strings.GetOA( String, OUT ptr ) THEN
        Strings.ConcatW( OUT ErrorString, L"String ", String );
        Strings.AppendW( REF ErrorString, L" is already known." );
        RETURN FALSE;
      END;
      _Strings.AddOA( String, _Strings.Count );
      IF _Strings.Count > _TextsAllocated THEN
        L := MAX2( _TextsAllocated << 1, 256 );
        _Langs.Reset();
        WHILE _Langs.MoveNext() DO
          REALLOCATE( _Langs.CurrentData, L * SIZE( TText ));
          Storage.Fill( INC( _Langs.CurrentData, _TextsAllocated * SIZE( TText )), ( L - _TextsAllocated ) * SIZE( TText ), 0 );
        END; // END
        _TextsAllocated := L;
      END;
      RETURN TRUE;
    END AddString;

  //-----

    PROCEDURE AddStringItem( Lang : Languages.TLanguage; CONST String : ARRAY OF WCHAR );
    VAR
      L : CARDINAL;
      Texts : TPTexts;
    BEGIN
      IF NOT _Langs.Get( Lang, OUT Texts ) THEN
        L := _TextsAllocated * SIZE( TText );
        ALLOCATE( Texts, L );
        Storage.Fill( Texts, L, 0 );
        _Langs.Add( Lang, Texts );
      END;

      // store String itself
      L := LENGTH( String ) + 1;
      IF _PoolBytes + L << 1 > _PoolAllocated THEN
        _PoolAllocated := ( _PoolBytes + L << 1 + 4095 ) DIV 4096 * 4096;
        REALLOCATE( _Pool, _PoolAllocated << 1 );
      END;
      Strings.MoveW( ADR( String ), _Pool@[ _PoolBytes ], L );

      // store text data, _Strings.Count is current, so index is -1
      Texts^[ _Strings.Count-1 ].Length := L;
      Texts^[ _Strings.Count-1 ].Offset := _PoolBytes;

      INC( _PoolBytes, L << 1 );
    END AddStringItem;

  //-----
  
    PROCEDURE CreateResource();
    VAR
      at : ADDRESS;
      al, c, cl, l : CARDINAL;
      diff : PTR;
      i, j : INTEGER;
    BEGIN
      CASE _Mode OF
      | rmSelfMemory :
        DISPOSE( _Resource );
      | rmResource :
        windows.FreeResource( _HResource );  
      END;
      _Mode := rmSelfMemory;

      c := _Strings.Count;
      l :=  c * SIZE( TText );
      cl := _Langs.Count;
      al := SIZE( TResourceData ) +  cl * ( SIZE( TLanguageSlot ) + l ) + _PoolBytes;
      ALLOCATE( _Resource, al );

      // main record
      WITH _Resource^ DO
        BinMagic := binMagic;
        BinLength := al;
        BinVersion := binVersion;
        ASSIGNsz( DataVersion, _Version );
        DefaultLanguage := _DefaultLanguage;
        SlotCount := cl;
        TextCount := c;
        Slots := TPSlots( _Resource@[ SIZE( TResourceData ) ] );
        Strings := PWCHAR( Slots@[ cl * ( SIZE( TLanguageSlot ) + l ) ] );
      END; // WITH

      at := _Resource@[ SIZE( TResourceData ) + cl * SIZE( TLanguageSlot ) ];
      diff := PTR( _Resource^.Strings ) - PTR( _Resource );

      // language slots and text indexes
      i := 0;
      _Langs.Reset();
      WHILE _Langs.MoveNext() DO WITH _Resource^ DO
        // slot
        Slots^[i].Texts := at;
        Slots^[i].Lang := _Langs.Current;
      
        // text indexes
        Storage.Move( _Langs.CurrentData, at, l );
        FOR j := 0 TO INTEGER( c - 1 ) DO
          IF Slots^[i].Texts^[j].Length > 0 THEN
            INC( Slots^[i].Texts^[j].Text, diff ); // .Text are offsets from block begin
          END;
        END;
        // dispose temporary data
        DISPOSE( _Langs.CurrentData );

        // convert slot to offset
        DEC( Slots^[i].Texts, PTR( _Resource ));

        INC( i );
        INC( at, l );
      END; END; // WITH, WHILE
      
      // adjust main indexes
      DEC( _Resource^.Slots, PTR( _Resource ));
      DEC( _Resource^.Strings, PTR( _Resource ));
      
      // strings
      Storage.Move( _Pool, at, _PoolBytes );
      DISPOSE( _Pool );
      
      // create stub
      ResToStub();
    END CreateResource;
  
  //-----

  LABEL
    Done, NumberError, StringError;
  VAR
    BS : com.BSTR := NIL;
    Language : Languages.TLanguage;
    E : xmlDOM.TPIXMLDOMElement;
    i : INTEGER;
    Name : com.BSTR := NIL;
    NL : xmlDOM.TPIXMLDOMNodeList;
    N, Item : xmlDOM.TPIXMLDOMNode;
    Result : CARDINAL;
    String : xmlDOM.TPIXMLDOMElement;
    V : com.VARIANTARG;
    XML : xmlDOM.TPIXMLDOMDocument;
    VB : com.VARIANT_BOOL;
    b : BOOLEAN;
  BEGIN
    IF NOT FIO.ExistsW( Path ) THEN
      ASSIGN( ErrorText, L'File not found' );
      GOTO StringError;
    END;
    com.VariantInitString( OUT V, Path );
    _Strings.Dispose();

    Result := com.New2( "MSXML2.DOMDocument.3.0", OUT XML );
    IF Result <> 0 THEN
      GOTO NumberError;
    END;
    VB := XML^.load( V );
    IF VB = windows.False THEN
      BS := XML^.parseError^.reason;
      ASSIGNsz( ErrorText, BS );
      GOTO StringError;
    END;

    N := XML^.selectSingleNode( com.ToBSRef( L"/resources/strings", REF BS ));
    IF N = NIL THEN
      ASSIGN( ErrorText, L"<strings> element not found" );
      GOTO StringError;
    ELSE
      com.Cast( REF N, xmlDOM.IID_IXMLDOMElement, TRUE, OUT E );
    END;
    com.VariantToBSRef( E^.getAttribute( com.ToBSRef( L"version", REF BS )), TRUE, REF _Version );
    com.VariantToBSRef( E^.getAttribute( com.ToBSRef( L"lang", REF BS )), TRUE, REF BS );
    E^.Release();
    IF NOT com.BSEmpty( BS ) AND NOT Languages.RFC1766ToLanguage( OAsz( BS ), OUT _DefaultLanguage ) THEN
      Strings.ConcatW( OUT ErrorText, L"Unrecognized language identifier: ", OAsz( BS ));
      GOTO StringError;
    END;

    NL := XML^.getElementsByTagName( com.ToBS( L"string" ));
    i := 0;
    LOOP
      N := NL^[i];
      IF N = NIL THEN
        EXIT;
      END;

      com.Cast( REF N, xmlDOM.IID_IXMLDOMElement, TRUE, OUT String );
      com.VariantToBSRef( String^.getAttribute( com.ToBSRef( L"name", REF BS )), TRUE, REF Name );
      IF com.BSEmpty( Name ) THEN
        ASSIGN( ErrorText, L"Empty or undefined string name" );
        GOTO StringError;
      ELSIF NOT AddString( OAsz( Name ), OUT ErrorText ) THEN
        GOTO StringError;
      END;

      Item := String^.firstChild;
      WHILE Item <> NIL DO
        b := Item^.nodeType = xmlDOM.NODE_ELEMENT;
        IF b THEN // have <item>
          com.Cast( REF Item, xmlDOM.IID_IXMLDOMElement, FALSE, OUT E );
          Language := _DefaultLanguage;

          com.VariantToBSRef( E^.getAttribute( com.ToBSRef( L"lang", REF BS )), TRUE, REF BS );
          IF NOT com.BSEmpty( BS ) AND NOT Languages.RFC1766ToLanguage( OAsz( BS ), OUT Language ) THEN
            Strings.ConcatW( OUT ErrorText, L"Unrecognized language identifier: ", OAsz( Name ));
            GOTO StringError;
          END;

          AddStringItem( Language, OAsz( com.BSToBSRef( E^.text, TRUE, REF BS )));
        END; // IF have <item>
        N := Item^.nextSibling; Item^.Release(); Item := N;
      END; // WHILE

      String^.Release();
      INC( i );
    END;
    NL^.Release();
    
    // XML parsed OK, create _Resource
    CreateResource();

    b := TRUE;
    GOTO Done;
    
  NumberError:
    Strings.FromErrorW( Result, OUT ErrorText );
  StringError:
    b := FALSE;
  Done:
    com.VariantClear( REF V );
    com.DisposeBS( REF BS );
    com.DisposeBS( REF Name );
    com.DisposeBS( REF _Version );
    RETURN b;  
  END LoadXML;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE GetXML( OUT XML : ARRAY OF WCHAR );
  BEGIN
  END GetXML;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE GetBIN( OUT BIN : ARRAY OF BYTE );
  BEGIN
    Storage.Move( _Resource, ADR( BIN ), MIN2( _Resource^.BinLength, HIGH( BIN ) + 1 ));
  END GetBIN;
  
//---------------------------------------------------------------------------

  PUBLIC PROCEDURE SaveXML( CONST Path : ARRAY OF WCHAR );
  BEGIN
  END SaveXML;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE SaveBIN( CONST Path : ARRAY OF WCHAR );
  VAR
    f : FIO.File;
  BEGIN
    f := FIO.CreateW( Path, FIO.TFileShare{} );
    FIO.WrBin( f, _Resource^, _Resource^.BinLength );
    FIO.Close( f );
  END SaveBIN;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE SaveDEF( CONST ModuleName, Path, NamePrefix : ARRAY OF WCHAR ) : BOOLEAN;
  VAR
    f : FIO.File;
    Index : ARRAY [0..15] OF WCHAR;
    Name : ARRAY [0..511] OF WCHAR;
  BEGIN
    f := FIO.CreateW( Path, FIO.TFileShare{} );
    
    FIO.WrStrW( f, L'DEFINITION MODULE ' ); FIO.WrStrW( f, ModuleName ); FIO.WrStrW( f, L';' ); FIO.WrLnW( f );
    FIO.WrStrW( f, L'// automatically generated from resource file' ); FIO.WrLnW( f );
    FIO.WrLnW( f );
    FIO.WrStrW( f, L'CONST' ); FIO.WrLnW( f );
    
    _Strings.Reset();
    WHILE _Strings.MoveNext() DO
      _Strings.Current^.ToOA( OUT Name );
      Strings.FromCARD64W( CARD64( _Strings.CurrentData ), 10, OUT Index );
      FIO.WrStrW( f, L'  ' ); FIO.WrStrW( f, NamePrefix ); FIO.WrStrW( f, Name ); FIO.WrStrW( f, L' = ' ); FIO.WrStrW( f, Index ); FIO.WrStrW( f, L';' ); FIO.WrLnW( f );
    END; // WHILE

    FIO.WrLnW( f );
    FIO.WrStrW( f, L'END ' ); FIO.WrStrW( f, ModuleName ); FIO.WrStrW( f, L'.' ); FIO.WrLnW( f );

    FIO.Close( f );
    RETURN TRUE;
  END SaveDEF;

//---------------------------------------------------------------------------

END CResourcesCreator;

//===========================================================================

END Resources.
