IMPLEMENTATION MODULE XMLWriter;

(*===========================================================================*)

IMPORT
   Strings,
   Sync;

(*===========================================================================*)

CLASS IMPLEMENTATION CXMLWriter;

(*---------------------------------------------------------------------------*)

   // PUBLIC PROPERTY
   // Encoding : CARDINAL;
   
   PUBLIC PROPERTY Stream GET : IOO.TPStream;
   BEGIN
      RETURN _Stream;
   END Stream;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Stream SET( Value : IOO.TPStream );
   BEGIN
      // IF _Stream <> NIL THEN
      //    there are no pending actions like write which should be aborted 
      // END;
      _Stream := Value;
   END Stream;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY XMLDeclaration GET : BOOLEAN;
   BEGIN
      RETURN _XMLDeclaration;
   END XMLDeclaration;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY XMLDeclaration SET( Value : BOOLEAN );
   BEGIN
      IF xwsStarted IN _State	THEN // the flag cannot be changed when declaration is already emitted
         RETURN;
      END;
      _XMLDeclaration := Value;
   END XMLDeclaration;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Fragment GET : BOOLEAN;
   BEGIN
      RETURN _Fragment;
   END Fragment;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Fragment SET( Value : BOOLEAN );
   BEGIN
      IF xwsStarted IN _State	THEN // the flag cannot be changed when already started
         RETURN;
      END;
      _Fragment := Value;
      IF _Fragment THEN
         INCL( _State, xwsStarted );
      END;
   END Fragment;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE WriteElementString( CONST NSPrefix, Element : ARRAY OF WCHAR; CONST String : StringsO.CString );
   BEGIN
      WriteElementStartOA( NSPrefix, Element );
      WriteString( String );
      WriteElementEnd();
   END WriteElementString;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE WriteElementStringOA( CONST NSPrefix, Element, String : ARRAY OF WCHAR );
   BEGIN
      WriteElementStartOA( NSPrefix, Element );
      WriteStringOA( String );
      WriteElementEnd();
   END WriteElementStringOA;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE WriteElementStartOA( CONST NSPrefix, Element : ARRAY OF WCHAR );
   BEGIN
      IF xwsInAttribute IN _State THEN
         RETURN;
      ELSIF xwsInAttributes IN _State THEN
         EXCL( _State, xwsInAttributes );
         WriteOAA( C'>' ); // close leading of current element
      ELSIF xwsStarted NOT IN _State THEN
         INCL( _State, xwsStarted );
         IF _XMLDeclaration THEN
            WriteOAA( C'<?xml version="1.0" encoding="utf-8"?>' ); WriteEOL();
         END;
      END;
      WriteEOL(); WriteIndent(); WriteOAA( C'<' );

      IF INSIDE( 0, NSPrefix ) AND ( NSPrefix[0] <> 0W ) THEN
         WriteOA( NSPrefix );
         WriteOAA( C":" );
      END;
      WriteOA( Element );

      _Stack.Push( StringsO.FromOA( NSPrefix ), 0 );
      _Stack.Push( StringsO.FromOA( Element ), 0 );

      INCL( _State, xwsInAttributes );
   END WriteElementStartOA;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE WriteElementEnd();
   VAR
      Element : StringsO.CString;
      HaveText : BOOLEAN;
      NSPrefix : StringsO.CString;
      ptr : PTR;
   BEGIN
      IF _Stack.Empty OR ( xwsInAttribute IN _State ) THEN
         RETURN;
      END;
      HaveText := _Stack.TopData = 1;

      _Stack.Pop( OUT Element, OUT ptr );
      _Stack.Pop( OUT NSPrefix, OUT ptr );

      IF xwsInAttributes IN _State THEN
         EXCL( _State, xwsInAttributes );
         WriteOAA( C'/>' );
      ELSIF HaveText THEN
         WriteOAA( C'</' );
         IF NOT NSPrefix.Empty THEN
            Write( NSPrefix );
            WriteOAA( C":" );
         END;
         Write( Element );
         WriteOAA( C'>' );
      ELSE
         WriteEOL();
         WriteIndent();
         WriteOAA( C'</' );
         IF NOT NSPrefix.Empty THEN
            Write( NSPrefix );
            WriteOAA( C":" );
         END;
         Write( Element );
         WriteOAA( C'>' );
      END;
   END WriteElementEnd;
   
(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE WriteAttributeStringOA( CONST NSPrefix, Attribute, String : ARRAY OF WCHAR );
   BEGIN
      WriteAttributeStartOA( NSPrefix, Attribute );
      WriteStringOA( String );
      WriteAttributeEnd();
   END WriteAttributeStringOA;
   
(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE WriteAttributeStartOA( CONST NSPrefix, Attribute : ARRAY OF WCHAR );
   BEGIN
      IF TXMLWriterState{xwsInAttributes, xwsInAttribute} * _State <> TXMLWriterState{xwsInAttributes} THEN
         RETURN;
      END;
      INCL( _State, xwsInAttribute );

      WriteOAA( C" " );
      IF INSIDE( 0, NSPrefix ) AND ( NSPrefix[0] <> 0W ) THEN
         WriteOA( NSPrefix );
         WriteOAA( C":" );
      END;
      WriteOA( Attribute ); WriteOAA( C'="' );
   END WriteAttributeStartOA;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE WriteAttributeEnd();
   BEGIN
      IF xwsInAttribute NOT IN _State THEN
         RETURN;
      END;
      EXCL( _State, xwsInAttribute );
      WriteOAA( C'"' );
   END WriteAttributeEnd;
   
(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE WriteString( CONST String : StringsO.CString );
   VAR
      S : StringsO.CString := String;
   BEGIN
      IF xwsStarted NOT IN _State THEN
         RETURN;
      ELSIF xwsInAttributes NOT IN _State THEN
         // fall down, already in text
      ELSIF xwsInAttribute NOT IN _State THEN
         EXCL( _State, xwsInAttributes );
         WriteOAA( C'>' ); // close leading of current element, continue in the line
         _Stack.TopData := 1; // signalize we are in text
      END;

      // escape reserved characters
      S.ReplaceOA( L"&", L"&amp;" );
      S.ReplaceOA( L"<", L"&lt;" );
      S.ReplaceOA( L">", L"&gt;" );
      S.ReplaceOA( L'"', L"&quot;" );

      Write( S );
   END WriteString;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE WriteUnescapedString( CONST String : StringsO.CString );
   BEGIN
      IF xwsStarted NOT IN _State THEN
         RETURN;
      ELSIF xwsInAttributes NOT IN _State THEN
         // fall down, already in text
      ELSIF xwsInAttribute NOT IN _State THEN
         EXCL( _State, xwsInAttributes );
         WriteOAA( C'>' ); // close leading of current element, continue in the line
         _Stack.TopData := 1; // signalize we are in text
      END;
      Write( String );
   END WriteUnescapedString;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE WriteStringOA( CONST String : ARRAY OF WCHAR );
   VAR
      S : StringsO.CString;
   BEGIN
      IF xwsStarted NOT IN _State THEN
         RETURN;
      ELSIF xwsInAttributes NOT IN _State THEN
         // fall down, already in text
      ELSIF xwsInAttribute NOT IN _State THEN
         EXCL( _State, xwsInAttributes );
         WriteOAA( C'>' ); // close leading of current element, continue in the line
         _Stack.TopData := 1; // signalize we are in text
      END;

      S.FromOA( String );
      // escape reserved characters
      S.ReplaceOA( L"&", L"&amp;" );
      S.ReplaceOA( L"<", L"&lt;" );
      S.ReplaceOA( L">", L"&gt;" );
      S.ReplaceOA( L'"', L"&quot;" );

      Write( S );
   END WriteStringOA;
   
(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Close( Persist : BOOLEAN );
   BEGIN
      WHILE NOT _Stack.Empty DO
         WriteElementEnd();
      END;
      IF NOT Persist AND ( _Stream <> NIL ) THEN
         Stream := NIL;
      END;
   END Close;

(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Write( CONST String : StringsO.CString );
   VAR
      Buffer : ARRAY [0..1023] OF CHAR;
      i, l, sl : CARDINAL;
      s : PWCHAR;
   BEGIN
      sl := String.Length;
      IF ( sl = 0 ) OR ( _Stream = NIL ) THEN
         RETURN;
      END;
      i := 0;
      s := String.Data;
      WHILE i < sl DO
         l := MIN2( 2*HIGH( Buffer ) DIV 3 + 1, sl-i );
         Strings.ToA( OA( l-1, s ), _Encoding, OUT Buffer );
         IF Buffer[0] <> 0C THEN // performance: if ToAStream is used the LENGTH( Buffer ) probably need not to be computed
            WriteOAA( OA( LENGTH( Buffer )-1, ADR( Buffer )));
         END;
         INC( s, l << 1 );
         INC( i, l );
      END; // WHILE
   END Write;
   
(*---------------------------------------------------------------------------*)

   PRIVATE INLINE PROCEDURE WriteOA( CONST String : ARRAY OF WCHAR );
   VAR
      S : StringsO.CString;
   BEGIN
      S.FromOA( String );
      Write( S );
   END WriteOA;

(*---------------------------------------------------------------------------*)

   PRIVATE INLINE PROCEDURE WriteOAA( CONST String : ARRAY OF CHAR );
   VAR
      l : CARDINAL;
   BEGIN
      _Stream^.WriteOA( String, OUT l, Sync.FOREVER );
   END WriteOAA;

(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE WriteIndent();
   CONST
      indent = C'                                                                                                                                ';
   VAR
      nest : CARDINAL := _Stack.Count;
   BEGIN
      IF nest = 0 THEN
         RETURN;
      END;
      WriteOAA( OA( MIN2( HIGH( indent ), nest << 1 - 1 ), ADR( indent )));
   END WriteIndent;

(*---------------------------------------------------------------------------*)

   PRIVATE INLINE PROCEDURE WriteEOL();
   BEGIN
      WriteOAA( CHAR( 13 ) + CHAR( 10 ));
   END WriteEOL;

(*---------------------------------------------------------------------------*)

BEGIN
   _Stream := NIL;
   _State := TXMLWriterState{};
FINALLY
   Close( FALSE );
END CXMLWriter;

(*===========================================================================*)

END XMLWriter.
