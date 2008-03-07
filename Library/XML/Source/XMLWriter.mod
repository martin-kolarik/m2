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
		IF _Stream <> NIL THEN
			_Stream^.Close( FALSE );
		END;
		_Stream := Value;
	END Stream;

(*---------------------------------------------------------------------------*)

	PUBLIC PROCEDURE WriteElementString( CONST Element : ARRAY OF WCHAR; CONST String : StringsO.CString );
	BEGIN
		WriteElementStartOA( Element );
		WriteString( String );
		WriteElementEnd();
	END WriteElementString;

(*---------------------------------------------------------------------------*)

	PUBLIC PROCEDURE WriteElementStringOA( CONST Element, String : ARRAY OF WCHAR );
	BEGIN
		WriteElementStartOA( Element );
		WriteStringOA( String );
		WriteElementEnd();
	END WriteElementStringOA;

(*---------------------------------------------------------------------------*)

	PUBLIC PROCEDURE WriteElementStartOA( CONST Element : ARRAY OF WCHAR );
	BEGIN
		IF xwsInAttribute IN _State THEN
			RETURN;
		ELSIF xwsInAttributes IN _State THEN
			EXCL( _State, xwsInAttributes );
			WriteOAA( C'>' ); // close leading of current element
		ELSIF xwsStarted NOT IN _State THEN
			INCL( _State, xwsStarted );	
			WriteOAA( C'<?xml version="1.0" encoding="utf-8"?>' ); WriteEOL();
		END;
		WriteEOL(); WriteIndent(); WriteOAA( C'<' ); WriteOA( Element, FALSE );
		_Stack.PushOA( Element );
		INCL( _State, xwsInAttributes );
	END WriteElementStartOA;

(*---------------------------------------------------------------------------*)

	PUBLIC PROCEDURE WriteElementEnd();
	VAR
		S : StringsO.CString;
		HaveText : BOOLEAN;
	BEGIN
		IF _Stack.Empty OR ( xwsInAttribute IN _State ) THEN
			RETURN;
		END;
		HaveText := _Stack.PeekData() = 1;
		_Stack.Pop( OUT S );
		IF xwsInAttributes IN _State THEN
			EXCL( _State, xwsInAttributes );
			WriteOAA( C'/>' );
		ELSIF HaveText THEN
			WriteOAA( C'</' ); Write( REF S, FALSE ); WriteOAA( C'>' );
		ELSE
			WriteEOL();
			WriteIndent(); WriteOAA( C'</' ); Write( REF S, FALSE ); WriteOAA( C'>' );
		END;
		IF _Stack.Empty THEN
			EXCL( _State, xwsStarted );	
		END;
	END WriteElementEnd;
	
(*---------------------------------------------------------------------------*)

	PUBLIC PROCEDURE WriteAttributeStringOA( CONST Attribute, String : ARRAY OF WCHAR );
	BEGIN
		WriteAttributeStartOA( Attribute );
		WriteStringOA( String );
		WriteAttributeEnd();
	END WriteAttributeStringOA;
	
(*---------------------------------------------------------------------------*)

	PUBLIC PROCEDURE WriteAttributeStartOA( CONST Attribute : ARRAY OF WCHAR );
	BEGIN
		IF TXMLWriterState{xwsInAttributes, xwsInAttribute} * _State <> TXMLWriterState{xwsInAttributes} THEN
			RETURN;
		END;
		INCL( _State, xwsInAttribute );
		WriteOAA( C" " ); WriteOA( Attribute, FALSE ); WriteOAA( C'="' );
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
		ELSIF xwsInAttribute NOT IN _State THEN
			EXCL( _State, xwsInAttributes );
			WriteOAA( C'>' ); // close leading of current element, continue in the line
			_Stack.StoreData( 1 ); // signalize we are in text
		END;
		Write( REF S, TRUE );
	END WriteString;

(*---------------------------------------------------------------------------*)

	PUBLIC PROCEDURE WriteStringOA( CONST String : ARRAY OF WCHAR );
	BEGIN
		IF xwsStarted NOT IN _State THEN
			RETURN;
		ELSIF xwsInAttribute NOT IN _State THEN
			EXCL( _State, xwsInAttributes );
			WriteOAA( C'>' ); // close leading of current element, continue in the line
			_Stack.StoreData( 1 ); // signalize we are in text
		END;
		WriteOA( String, TRUE );
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

	PRIVATE PROCEDURE Write( REF String : StringsO.CString; Escape : BOOLEAN );
	VAR
		Buffer : ARRAY [0..1023] OF CHAR;
		i, l, sl : CARDINAL;
		s : PWCHAR;
	BEGIN
		sl := String.Length;
		IF ( sl = 0 ) OR ( _Stream = NIL ) THEN
			RETURN;
		END;
		IF Escape THEN
			String.ReplaceOA( L"&", L"&amp;" );
			String.ReplaceOA( L"<", L"&lt;" );
			String.ReplaceOA( L">", L"&gt;" );
			String.ReplaceOA( L'"', L"&quot;" );
			sl := String.Length;
		END;
		i := 0;
		s := String.rawData;
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

	PRIVATE INLINE PROCEDURE WriteOA( CONST String : ARRAY OF WCHAR; Escape : BOOLEAN );
	VAR
		S : StringsO.CString;
	BEGIN
		S.FromOA( String );
		Write( REF S, Escape );
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