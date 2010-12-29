IMPLEMENTATION MODULE HttpTools;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;
FROM Exceptions IMPORT
   TestIfCatched, RetrieveException;

IMPORT
   cphcommon,
   Exceptions,
   Languages,
   lists,
   StorageO,
   Strings;

CONST
   HTTP_TIME_FORMAT = L"ddd, dd MMM yyyy HH:mm:ss 'GMT'";

(*===========================================================================*)

PROCEDURE FormatDate( CONST Date : time.DateTime ) : StringsO.CString;
VAR
   formatted : ARRAY [0..255] OF WCHAR;
   s : StringsO.CString;
BEGIN
   IF Date.ToLanguageStringOA( Languages.GetDefaultLanguage( Languages.dlNeutral ), HTTP_TIME_FORMAT, TRUE, TRUE, OUT formatted ) THEN
      s.FromOA( formatted );
   END;
   RETURN s;
END FormatDate;

(*---------------------------------------------------------------------------*)

PROCEDURE FormatDateJD( Date : time.TJD ) : StringsO.CString;
VAR
   dt : time.DateTime;
BEGIN
   dt.JulianDate := Date;
   RETURN FormatDate( dt );
END FormatDateJD;

(*---------------------------------------------------------------------------*)

PROCEDURE DecodeDate( CONST Encoded : StringsO.IString; OUT Decoded : time.DateTime ) : BOOLEAN;
BEGIN
   RETURN Decoded.FromLanguageStringOA( Languages.GetDefaultLanguage( Languages.dlNeutral ), OA( Encoded.Length-1, Encoded.Data ), HTTP_TIME_FORMAT );
END DecodeDate;

(*---------------------------------------------------------------------------*)

PROCEDURE DecodeDateJD( CONST Encoded : StringsO.IString; OUT Decoded : time.TJD ) : BOOLEAN;
VAR
   dt : time.DateTime;
BEGIN
   IF NOT DecodeDate( Encoded, OUT dt ) THEN
      RETURN FALSE;
   END;
   Decoded := dt.JulianDate;
   RETURN TRUE;
END DecodeDateJD;

(*---------------------------------------------------------------------------*)

PROCEDURE FormatSIDCookie( CONST SID : StringsO.IString; CONST Expires : time.DateTime; CONST Path, Domain : StringsO.IString ) : StringsO.CString;
VAR
   s : StringsO.CString;
BEGIN
   s.FromOA( L"sid=" ); s.Append( SID );
   IF NOT Expires.Empty THEN
      s.AppendOA( L"; expires=" );
      s.Append( FormatDate( Expires ));
   END;
   IF NOT Path.Empty THEN
      s.AppendOA( L"; path=" );
      s.Append( Path );
   END;
   IF NOT Domain.Empty THEN
      s.AppendOA( L"; domain=" );
      s.Append( Domain );
   END;
   RETURN s;
END FormatSIDCookie;

(*---------------------------------------------------------------------------*)

PROCEDURE DecodeSIDCookie( CONST Cookies : StringsO.IString; OUT SID : StringsO.IString ) : BOOLEAN;
VAR
   cookie : StringsO.CString;
   i, j : INTEGER;
   leading : StringsO.CString;
BEGIN
   i := 0;
   LOOP
      i := Cookies.ItemS( StringsO.WCHARS{L";"}, i, 0, TRUE, OUT cookie );
      IF cookie.Length < 4 THEN // less than "sid="
         RETURN FALSE;
      END;
      cookie.Trim();
      cookie.Substring( 0, 3, OUT leading );
      leading.Lowerize();
      IF NOT leading.StartsWithOA( L"sid" ) THEN
         CONTINUE;
      END;
      j := cookie.IndexOfOA( L"=", 3 ); // 3 is length of "sid"
      IF j = -1 THEN
         CONTINUE;
      END;
      cookie.Remove( 0, j+1 );
      cookie.Trim();
      IF cookie.Empty THEN
         RETURN FALSE;
      END;
      SID.Assign( cookie );
      RETURN TRUE;
   END; // LOOP
END DecodeSIDCookie;

(*---------------------------------------------------------------------------*)

PROCEDURE FormatContent( Content : TContent; CONST FileName, RFC1766Code : StringsO.IString; Fallback : BOOLEAN; OUT ContentHeader : StringsO.IString ) : BOOLEAN;
VAR
   appendCharset : BOOLEAN := TRUE;
   highF : INTEGER;
   f, s : StringsO.CString;
BEGIN
   CASE Content OF
   | contentDefault :
      appendCharset := FALSE;
      s.FromOA( CONTENT_TYPE_BINARY );
   | contentTextPlain :
      s.FromOA( CONTENT_TYPE_TEXT );
   | contentTextHTML :
      s.FromOA( CONTENT_TYPE_HTML );
   | contentTextXHTML :
      appendCharset := FALSE;
      s.FromOA( CONTENT_TYPE_XHTML );
   | contentTextXML :
      s.FromOA( CONTENT_TYPE_XML );
   | contentTextCSS :
      s.FromOA( CONTENT_TYPE_CSS );
   | contentTextCSV :
      s.FromOA( CONTENT_TYPE_CSV );
   | contentApplicationJS :
      s.FromOA( CONTENT_TYPE_JS );
   ELSE
      appendCharset := FALSE;
      highF := FileName.Length-1;
      IF highF < 0 THEN
         IF Fallback THEN
            ContentHeader.FromOA( CONTENT_TYPE_BINARY );
            RETURN TRUE;
         ELSE
            RETURN FALSE;
         END;
      END;
         
      FileName.Substring( highF-15, 16, OUT f ); // get last 16 characters
      f.Lowerize();
      
      IF f.EndsWithOA( L"txt" ) THEN
         appendCharset := TRUE;
         s.FromOA( CONTENT_TYPE_TEXT );
      ELSIF f.EndsWithOA( L"htm" ) OR f.EndsWithOA( L"html" ) THEN
         appendCharset := TRUE;
         s.FromOA( CONTENT_TYPE_HTML );
      ELSIF f.EndsWithOA( L"xhtml" ) THEN
         s.FromOA( CONTENT_TYPE_XHTML );
      ELSIF f.EndsWithOA( L"xml" ) THEN
         s.FromOA( CONTENT_TYPE_XML );
      ELSIF f.EndsWithOA( L"css" ) THEN
         appendCharset := TRUE;
         s.FromOA( CONTENT_TYPE_CSS );

      ELSIF f.EndsWithOA( L"png" ) THEN
         s.FromOA( L"image/png" );
      ELSIF f.EndsWithOA( L"gif" ) THEN
         s.FromOA( L"image/gif" );
      ELSIF f.EndsWithOA( L"jpg" ) OR f.EndsWithOA( L"jpeg" ) THEN
         s.FromOA( L"image/jpeg" );
      ELSIF f.EndsWithOA( L"svg" ) THEN
         s.FromOA( L"image/svg+xml" );

      ELSIF f.EndsWithOA( L"exe" ) OR f.EndsWithOA( L"dll" ) OR f.EndsWithOA( L"obj" ) OR f.EndsWithOA( L"lib" ) THEN
         s.FromOA( CONTENT_TYPE_BINARY );
      ELSIF f.EndsWithOA( L"zip" ) THEN
         s.FromOA( L"application/zip" );
      ELSIF f.EndsWithOA( L"cab" ) THEN
         s.FromOA( L"application/vnd.ms-cab-compressed" );
      ELSIF f.EndsWithOA( L"msi" ) THEN
         s.FromOA( CONTENT_TYPE_BINARY );
      ELSIF f.EndsWithOA( L"pdf" ) THEN
         s.FromOA( L"application/pdf" );

      ELSIF Fallback THEN
         s.FromOA( CONTENT_TYPE_BINARY );
      ELSE
         RETURN FALSE;
      END;
      
   END;
   IF appendCharset THEN
      IF RFC1766Code.Empty THEN
         s.AppendOA( L"; charset=utf-8" );
      ELSE
         s.AppendOA( L"; charset=" );
         s.Append( RFC1766Code );
      END;
   END;

   ContentHeader.Assign( s );
   RETURN TRUE;
END FormatContent;

(*---------------------------------------------------------------------------*)

PROCEDURE FormatContentOA( Content : TContent; CONST FileName, RFC1766Code : ARRAY OF WCHAR; Fallback : BOOLEAN; OUT ContentHeader : StringsO.IString ) : BOOLEAN;
VAR
   s1, s2 : StringsO.CString;
BEGIN
   s1.FromOA( FileName );
   s2.FromOA( RFC1766Code );
   RETURN FormatContent( Content, s1, s2, Fallback, OUT ContentHeader );
END FormatContentOA;

(*---------------------------------------------------------------------------*)

PROCEDURE DecodeContent( CONST ContentString : StringsO.IString; OUT Content : TContent; OUT RFC1766Code : StringsO.IString ) : BOOLEAN;
VAR
   equal : CARDINAL;
   index : CARDINAL;
   newindex : CARDINAL;
   parameter : StringsO.CString;
   parameters : StringsO.CString;
   s : StringsO.CString;
BEGIN
   index := ContentString.IndexOfOA( L";", 0 );
   IF index = -1 THEN
      s.Assign( ContentString );
      // parameters left empty
   ELSE
      ContentString.Substring( 0, index-1, OUT s );
      ContentString.Substring( index+1, -1, OUT parameters );
   END;

   s.Trim();
   s.Lowerize();
   IF s.EqualsOA( CONTENT_TYPE_TEXT ) THEN
      Content := contentTextPlain;
   ELSIF s.EqualsOA( CONTENT_TYPE_HTML ) THEN
      Content := contentTextHTML;
   ELSIF s.EqualsOA( CONTENT_TYPE_XHTML ) THEN
      Content := contentTextXHTML;
   ELSIF s.EqualsOA( CONTENT_TYPE_XML ) THEN
      Content := contentTextXML;
   ELSIF s.EqualsOA( CONTENT_TYPE_CSS ) THEN
      Content := contentTextCSS;
   ELSIF s.EqualsOA( CONTENT_TYPE_CSV ) THEN
      Content := contentTextCSV;
   ELSIF s.EqualsOA( CONTENT_TYPE_JS ) THEN
      Content := contentApplicationJS;
   ELSIF s.EqualsOA( CONTENT_TYPE_BINARY ) THEN
      Content := contentApplicationBinary;
   ELSE
      RETURN FALSE;
   END;
   
   RFC1766Code.Clear();
   parameters.Trim();
   IF parameters.Empty THEN
      RETURN TRUE;
   END;
   parameters.Lowerize();

   index := 0;
   WHILE index <> -1 DO
      newindex := parameters.IndexOfOA( L";", index );
      IF newindex = -1 THEN
         parameter := parameters;
      ELSE
         parameters.Substring( index, newindex-index-1, OUT parameter );
      END;
      index := newindex;

      parameter.Trim();      
      IF parameter.Empty THEN
         CONTINUE;
      END;
      equal := parameter.IndexOfOA( L"=", 0 );
      IF equal = -1 THEN
         CONTINUE;
      END;
      parameter.Substring( 0, equal-1, OUT s );
      s.Trim();
      IF NOT s.EqualsOA( CHARSET_PREFIX ) THEN
         CONTINUE;
      END;

      parameter.Substring( equal+1, -1, OUT RFC1766Code );
      RFC1766Code.Trim();

      EXIT;
   END; // WHILE

   RETURN TRUE;
END DecodeContent;

(*---------------------------------------------------------------------------*)

PROCEDURE DecodeContentOA( CONST ContentString : ARRAY OF WCHAR; OUT Content : TContent; OUT RFC1766Code : ARRAY OF WCHAR ) : BOOLEAN;
VAR
   s1, s2 : StringsO.CString;
BEGIN
   s1.FromOA( ContentString );
   IF DecodeContent( s1, OUT Content, OUT s2 ) THEN
      s2.ToOA( OUT RFC1766Code );
      RETURN TRUE;
   END;
   RETURN FALSE;
END DecodeContentOA;

(*---------------------------------------------------------------------------*)

PROCEDURE DecodeLanguage( CONST AcceptLanguageHeader : StringsO.IString; OUT language : Languages.TLanguage ) : BOOLEAN;
VAR
   firstItem : StringsO.CString;
BEGIN
   IF AcceptLanguageHeader.Empty THEN
      RETURN FALSE;
   END;
   AcceptLanguageHeader.ItemS( StringsO.WCHARS{ L"," }, 0, 0, FALSE, OUT firstItem );
   IF firstItem.Empty THEN
      RETURN FALSE;
   END;
   firstItem.Trim();
   RETURN Languages.RFC1766ToLanguage( OA( firstItem.Length-1, firstItem.Data ), OUT language );
END DecodeLanguage;

(*---------------------------------------------------------------------------*)

PROCEDURE DecodeURLEncoding( XFormFlag : BOOLEAN; CONST Encoded : ARRAY OF BYTE; OUT Decoded : lists.CStringStringList );
VAR
   bl : lists.CBufferList;
   byte : BYTE;
   encoded : StorageO.CMemoryBuffer;
   escprevi : INTEGER;
   ch : CHAR;
   i : INTEGER;
   l : INTEGER;
   mb : StorageO.TPMemoryBuffer;
   pb : PBYTE;
   previ : INTEGER;
   s : StringsO.CString;
   sd : StringsO.CString;
   sl : lists.CStringList;
BEGIN
   encoded.FromOA( Encoded, FALSE );
   pb := encoded.Data;

   // at first, split to strings
   previ := 0;
   escprevi := 0;
   LOOP
      i := encoded.IndexOfByte( C"&", escprevi );
      IF i = -1 THEN
         l := HIGH( Encoded )-previ+1;
         bl.AddOA( OA( l-1, pb@[previ] ), PTR( l ));
         EXIT;
      END;
      IF ( i+4 > HIGH( Encoded )) OR ( Encoded[i+4] <> C";" ) THEN
         // no & escape, fall down
      ELSIF ( Encoded[i+1] = C"#" ) AND ( Encoded[i+2] = C"3" ) AND ( Encoded[i+3] = C"8" ) OR
            ( Encoded[i+1] = C"a" ) AND ( Encoded[i+2] = C"m" ) AND ( Encoded[i+3] = C"p" ) THEN // & escape found, skip here
         escprevi := escprevi + 1; // move lookup index forward
         CONTINUE;
      // ELSE // no & escape, fall down
      END;
      l := i-previ;
      bl.AddOA( OA( l-1, pb@[previ] ), PTR( l ));
      previ := i+1;
      escprevi := previ;
   END; // LOOP

   // find equals and revert + to spaces if XFormFlag
   bl.Reset();
   WHILE bl.MoveNext() DO
      mb := bl.Current;

      i := 0;
      l := mb^.Length;
      TRY
         WHILE i < l DO
            ch := mb^[i];
            IF ch = C"%" THEN // decode three %XX characters
               IF i+2 >= l THEN
                  EXIT; // errorneous input
               END;
               cphcommon.FromHexByteA( OA( 1, PCHAR( mb^.Data@[i+1] )), OUT byte );
               mb^[i] := byte;
               mb^.Remove( i+1, 2 );
               DEC( l, 2 );

            ELSIF ch = C"=" THEN // remember split position (length)
               bl.CurrentData := PTR( i );
               mb^[i] := C"=";
               
            ELSIF ch = C"&" THEN // here it can only be an & escape
               mb^[i] := C"&";
               mb^.Remove( i+1, 4 );
               DEC( l, 4 );

            ELSIF XFormFlag AND ( ch = C"+" ) THEN // replace + with spaces
               mb^[i] := C" ";

            ELSE
               mb^[i] := ch;
            END;
            
            INC( i );
         END;
      CATCH m : Exceptions.CModula2Exception DO
         Decoded.Clear();
         RETURN;
      END; // TRY
      
      IF Languages.IsUTF8( OA( i-1, mb^.Data )) THEN
         s.FromOAA( Languages.cp_UTF8, OA( i-1, PCHAR( mb^.Data )));
      ELSE
         s.FromOAA( 0, OA( i-1, PCHAR( mb^.Data )));
      END;
      sl.Add( s, bl.CurrentData );
   END; // WHILE
   
   // split
   sl.Reset();
   WHILE sl.MoveNext() DO
      // first part
      i := INTEGER( LOPTRLONGWORD( sl.CurrentData ));
      s.FromOA( OA( i-1, sl.Current^.Data ));

      // second part
      l := sl.Current^.Length;
      IF i+1 <= l THEN
         sd.FromOA( OA( l-i-2, sl.Current^.Data@[(i+1)<<1] ));
      ELSE
         sd.Clear();
      END;
      
      Decoded.Add( s, sd );
   END; // WHILE
   
   bl.Dispose();
   sl.Dispose();
END DecodeURLEncoding;

(*===========================================================================*)

PROCEDURE GetRedirectCode( Redirect : TRedirect; HTTP10Flag : BOOLEAN ) : HttpCommon.THttpResponse; // HTTP status code
BEGIN
   IF Redirect = redirectPermanently THEN
      IF HTTP10Flag THEN
         RETURN HttpCommon.httpres_301;
      ELSE
         RETURN HttpCommon.httpres_301;
      END;
   ELSE
      IF HTTP10Flag THEN
         RETURN HttpCommon.httpres_302;
      ELSE
         RETURN HttpCommon.httpres_303;
      END;
   END;
END GetRedirectCode;

(*===========================================================================*)

END HttpTools.