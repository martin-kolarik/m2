IMPLEMENTATION MODULE TextWriter;

(*===========================================================================*)

FROM Debug IMPORT
   Assertion, LogAssertionW;

IMPORT
   FIOO,
   languages,
	Strings,
	Sync;

(*===========================================================================*)

CLASS IMPLEMENTATION CTextWriter;

(*---------------------------------------------------------------------------*)

	PUBLIC PROPERTY Encoding GET : CARDINAL;
	BEGIN
	   RETURN _Encoding;
	END Encoding;
	
(*---------------------------------------------------------------------------*)

	PUBLIC PROPERTY Encoding SET( Value : CARDINAL );
	BEGIN
	   _Encoding := Value;
	END Encoding;
	
(*---------------------------------------------------------------------------*)

	PUBLIC PROPERTY Stream GET : IOO.TPStream;
	BEGIN
		RETURN _Stream;
	END Stream;

(*---------------------------------------------------------------------------*)

	PUBLIC PROPERTY Stream SET( Value : IOO.TPStream );
	BEGIN
		_Stream := Value;
	END Stream;

(*---------------------------------------------------------------------------*)

	PUBLIC PROPERTY LineEndStyle GET : TLineEndStyle;
	BEGIN
	   RETURN _LineEndStyle;
	END LineEndStyle;

(*---------------------------------------------------------------------------*)

	PUBLIC PROPERTY LineEndStyle SET( Value : TLineEndStyle );
	BEGIN
	   _LineEndStyle := Value;
	END LineEndStyle;

(*---------------------------------------------------------------------------*)

	PUBLIC PROCEDURE WriteINT32( I : INT32; Base : CARDINAL; LineEnd : BOOLEAN );
	VAR
		S : StringsO.CString;
	BEGIN
		S.FromINT32( I, Base );
		Write( S, LineEnd );
	END WriteINT32;

(*---------------------------------------------------------------------------*)

	PUBLIC PROCEDURE WriteExc( CONST e : Exceptions.CException; LineEnd : BOOLEAN );
	VAR
		S : StringsO.CString;
		t : ARRAY [0..1023] OF WCHAR;
	BEGIN
	   e.ToString( OUT t );
	   S.FromOA( t );
		Write( S, LineEnd );
	END WriteExc;

(*---------------------------------------------------------------------------*)

	PUBLIC PROCEDURE Write( CONST String : StringsO.IString; LineEnd : BOOLEAN );
	BEGIN
      WriteTimeoutM( String.Data, String.Length, LineEnd, Sync.FOREVER );
	END Write;
	
(*---------------------------------------------------------------------------*)

	PUBLIC PROCEDURE WriteOA( CONST String : ARRAY OF WCHAR; LineEnd : BOOLEAN );
	BEGIN
      WriteTimeoutM( ADR( String ), LENGTH( String ), LineEnd, Sync.FOREVER );
	END WriteOA;

(*---------------------------------------------------------------------------*)

	PUBLIC PROCEDURE WriteM( CONST String : PWCHAR; Length : CARDINAL; LineEnd : BOOLEAN );
	BEGIN
	   WriteTimeoutM( String, Length, LineEnd, Sync.FOREVER );
	END WriteM;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE LineEnd();
   BEGIN
      LineEndTimeout( Sync.FOREVER );
   END LineEnd;

(*---------------------------------------------------------------------------*)

	PUBLIC PROCEDURE WriteTimeout( CONST String : StringsO.IString; LineEnd : BOOLEAN; TimeoutMS : CARDINAL ) : Sync.TAsyncResult;
	BEGIN
      RETURN WriteTimeoutM( String.Data, String.Length, LineEnd, TimeoutMS );
   END WriteTimeout;

(*---------------------------------------------------------------------------*)

	PUBLIC PROCEDURE WriteTimeoutOA( CONST String : ARRAY OF WCHAR; LineEnd : BOOLEAN; TimeoutMS : CARDINAL ) : Sync.TAsyncResult;
	BEGIN
      RETURN WriteTimeoutM( ADR( String ), LENGTH( String ), LineEnd, TimeoutMS );
	END WriteTimeoutOA;

(*---------------------------------------------------------------------------*)

	PUBLIC PROCEDURE WriteTimeoutM( CONST String : PWCHAR; Length : CARDINAL; _LineEnd : BOOLEAN; TimeoutMS : CARDINAL ) : Sync.TAsyncResult;
	VAR
	   Buffer : ARRAY [0..1023] OF BYTE;
		c, i, l, p, sl : CARDINAL;
		Result : Sync.TAsyncResult;
		s : PWCHAR;
	BEGIN
		IF _Stream = NIL THEN
			RETURN Sync.arCannotStart;
		END;
		sl := Length;
		IF sl > 0 THEN
		   i := 0;
		   s := String;
		   WHILE i < sl DO
			   l := MIN2( 2*HIGH( Buffer ) DIV 3 + 1, sl-i );
			   Strings.ToAStream( OA( l-1, s ), _Encoding, OUT Buffer, OUT c, OUT p );
			   IF p = 0 THEN
			      Result := Sync.arCompleted;
			   ELSE
				   Result := _Stream^.WriteOA( OA( p-1, ADR( Buffer )), OUT l, TimeoutMS );
			   END;
			   IF Result NOT IN Sync.arsCompletions THEN
			      RETURN Result;
			   ELSIF c = 0 THEN // error
			      ASSERTLOG( FALSE );
			      EXIT;
			   END;
			   INC( s, c << 1 );
			   INC( i, c );
		   END; // WHILE
		END; // IF
		IF _LineEnd THEN
		   RETURN LineEndTimeout( TimeoutMS );
		ELSE
   		RETURN Sync.arCompleted;
		END;
   END WriteTimeoutM;
	
(*---------------------------------------------------------------------------*)

	PUBLIC PROCEDURE LineEndTimeout( TimeoutMS : CARDINAL ) : Sync.TAsyncResult;
   VAR
      l : CARDINAL;
   BEGIN
		IF _Stream = NIL THEN
			RETURN Sync.arCannotStart;
		END;
      IF ( _Encoding = Languages.cp_UTF16 ) OR ( _Encoding = Languages.cp_UTF16_BIG_ENDIAN ) THEN
         CASE _LineEndStyle OF
         | lesWindows : RETURN _Stream^.WriteOA( WCHAR( 13 ) + WCHAR( 10 ), OUT l, TimeoutMS );
         | lesUNIX : RETURN _Stream^.WriteOA( WCHAR( 10 ), OUT l, TimeoutMS );
         | lesMAC : RETURN _Stream^.WriteOA( WCHAR( 13 ), OUT l, TimeoutMS );
         END;
      ELSE
         CASE _LineEndStyle OF
         | lesWindows : RETURN _Stream^.WriteOA( CHAR( 13 ) + CHAR( 10 ), OUT l, TimeoutMS );
         | lesUNIX : RETURN _Stream^.WriteOA( CHAR( 10 ), OUT l, TimeoutMS );
         | lesMAC : RETURN _Stream^.WriteOA( CHAR( 13 ), OUT l, TimeoutMS );
         END;
      END;
      RETURN Sync.arCannotStart;
   END LineEndTimeout;

(*---------------------------------------------------------------------------*)

BEGIN
	_Stream := NIL;
FINALLY
	Stream := NIL;
END CTextWriter;

(*===========================================================================*)

CLASS CStdTextWriter( CTextWriter ); END CStdTextWriter;

CLASS IMPLEMENTATION CStdTextWriter;
BEGIN FINALLY
   _Stream := NIL;
END CStdTextWriter;

(*---------------------------------------------------------------------------*)

VAR
   twstdout : CStdTextWriter;
   twerrout : CStdTextWriter;

(*---------------------------------------------------------------------------*)

PROCEDURE stdout() : TPTextWriter;
BEGIN
   IF twstdout.Stream = NIL THEN
      twstdout.Stream := FIOO.stdout();
      twstdout.Encoding := languages.cp_Console();
   END;
   RETURN ADR( twstdout );
END stdout;

(*---------------------------------------------------------------------------*)

PROCEDURE errout() : TPTextWriter;
BEGIN
   IF twerrout.Stream = NIL THEN
      twerrout.Stream := FIOO.errout();
      twerrout.Encoding := languages.cp_Console();
   END;
   RETURN ADR( twerrout );
END errout;

(*===========================================================================*)

END TextWriter.