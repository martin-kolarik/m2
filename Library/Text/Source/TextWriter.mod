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

	PUBLIC PROCEDURE Write( CONST String : StringsO.IString; LineEnd : BOOLEAN );
	BEGIN
      WriteM( String.rawData, String.Length, LineEnd );
	END Write;
	
(*---------------------------------------------------------------------------*)

	PUBLIC PROCEDURE WriteOA( CONST String : ARRAY OF WCHAR; LineEnd : BOOLEAN );
	BEGIN
      WriteM( ADR( String ), LENGTH( String ), LineEnd );
	END WriteOA;

(*---------------------------------------------------------------------------*)

	PUBLIC PROCEDURE WriteM( CONST String : PWCHAR; Length : CARDINAL; _LineEnd : BOOLEAN );
	VAR
	   Buffer : ARRAY [0..1023] OF BYTE;
		c, i, l, p, sl : CARDINAL;
		s : PWCHAR;
	BEGIN
		IF _Stream = NIL THEN
			RETURN;
		END;
		sl := Length;
		IF sl > 0 THEN
		   i := 0;
		   s := String;
		   WHILE i < sl DO
			   l := MIN2( 2*HIGH( Buffer ) DIV 3 + 1, sl-i );
			   Strings.ToAStream( OA( l-1, s ), _Encoding, OUT Buffer, OUT c, OUT p );
			   IF p > 0 THEN
				   _Stream^.WriteOA( OA( p-1, ADR( Buffer )), OUT l, Sync.FOREVER );
			   END;
			   IF c = 0 THEN // error
			      ASSERTLOG( FALSE );
			      EXIT;
			   END;
			   INC( s, c << 1 );
			   INC( i, c );
		   END; // WHILE
		END; // IF
		IF _LineEnd THEN
		   LineEnd();
		END;
   END WriteM;

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

   PUBLIC PROCEDURE LineEnd();
   VAR
      l : CARDINAL;
   BEGIN
		IF _Stream = NIL THEN
			RETURN;
		END;
      IF ( _Encoding = Languages.cp_UTF16 ) OR ( _Encoding = Languages.cp_UTF16_BIG_ENDIAN ) THEN
         CASE _LineEndStyle OF
         | lesWindows : _Stream^.WriteOA( WCHAR( 13 ) + WCHAR( 10 ), OUT l, Sync.FOREVER );
         | lesUNIX : _Stream^.WriteOA( WCHAR( 10 ), OUT l, Sync.FOREVER );
         | lesMAC : _Stream^.WriteOA( WCHAR( 13 ), OUT l, Sync.FOREVER );
         END;
      ELSE
         CASE _LineEndStyle OF
         | lesWindows : _Stream^.WriteOA( CHAR( 13 ) + CHAR( 10 ), OUT l, Sync.FOREVER );
         | lesUNIX : _Stream^.WriteOA( CHAR( 10 ), OUT l, Sync.FOREVER );
         | lesMAC : _Stream^.WriteOA( CHAR( 13 ), OUT l, 
         Sync.FOREVER );
         END;
      END;
   END LineEnd;

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