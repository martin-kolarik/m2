IMPLEMENTATION MODULE MIME;

IMPORT
   cphcommon,
   cphcommonO,
   languages,
   languagesO,
   StorageO;

(*===========================================================================*)

PROCEDURE FormatContent( Content : TContent; CONST FileName, Charset : StringsO.IString; Fallback : BOOLEAN; OUT ContentHeader : StringsO.IString ) : BOOLEAN;
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
      IF Charset.Empty THEN
         s.AppendOA( L"; charset=utf-8" );
      ELSE
         s.AppendOA( L"; charset=" );
         s.Append( Charset );
      END;
   END;

   ContentHeader.Assign( s );
   RETURN TRUE;
END FormatContent;

(*---------------------------------------------------------------------------*)

PROCEDURE FormatContentOA( Content : TContent; CONST FileName, Charset : ARRAY OF WCHAR; Fallback : BOOLEAN; OUT ContentHeader : StringsO.IString ) : BOOLEAN;
VAR
   s1, s2 : StringsO.CString;
BEGIN
   s1.FromOA( FileName );
   s2.FromOA( Charset );
   RETURN FormatContent( Content, s1, s2, Fallback, OUT ContentHeader );
END FormatContentOA;

(*---------------------------------------------------------------------------*)

PROCEDURE DecodeContent( CONST ContentString : StringsO.IString; OUT Content : TContent; OUT Charset : StringsO.IString ) : BOOLEAN;
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
   
   Charset.Clear();
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

      parameter.Substring( equal+1, -1, OUT Charset );
      Charset.Trim();

      EXIT;
   END; // WHILE

   RETURN TRUE;
END DecodeContent;

(*--------------------------------------------------------------------------------*)

PROCEDURE DecodeContentOA( CONST ContentString : ARRAY OF WCHAR; OUT Content : TContent; OUT Charset : ARRAY OF WCHAR ) : BOOLEAN;
VAR
   s1, s2 : StringsO.CString;
BEGIN
   s1.FromOA( ContentString );
   IF DecodeContent( s1, OUT Content, OUT s2 ) THEN
      s2.ToOA( OUT Charset );
      RETURN TRUE;
   END;
   RETURN FALSE;
END DecodeContentOA;

(*================================================================================*)

CONST
   PREFIX = L"=?utf-8?b?";
   SUFFIX = L"?=";
   MINIMAL_MIME_WORD_LENGTH = HIGH( PREFIX )+1 + HIGH( SUFFIX )+1 + 4 + 1; // 4 for single BASE64 chunk (0--3 bytes), 1 for folding <SP>
   FOLD = 13W + 10W + 32W; // <CRLF> <SP>

(*--------------------------------------------------------------------------------*)

PROCEDURE MimimalMIMEWordLength() : CARDINAL;
BEGIN
   RETURN MINIMAL_MIME_WORD_LENGTH;
END MimimalMIMEWordLength;

(*--------------------------------------------------------------------------------*)

PROCEDURE ToMimeWord( CONST String : StringsO.IString; OUT Mimeword : StringsO.IString );
VAR
   base64 : StringsO.CString;
   buffer : StorageO.CMemoryBuffer;
BEGIN
   languagesO.ToMB( String, languages.cp_UTF8, FALSE, REF buffer );
   cphcommonO.ToBASE64( buffer, OUT base64 );

   // combine it to whole mime word
   Mimeword.AppendOA( PREFIX );
   Mimeword.Append( base64 );
   Mimeword.AppendOA( SUFFIX );
END ToMimeWord;

(*--------------------------------------------------------------------------------*)

PROCEDURE ToMimeWords( CONST String : StringsO.IString; FirstLineLength, MaximalLineLength : CARDINAL; OUT Mimewords : StringsO.IString ) : BOOLEAN; // Mimewords contains <CRLF> <SP> separated mimewords
VAR
   encodedLength : CARDINAL;
   index : CARDINAL;
   maximalInputCharacters : CARDINAL;
   mimeWord : StringsO.CString;
   mimeWords : StringsO.CString;
   slice : StringsO.CString;
BEGIN
   IF MaximalLineLength < FirstLineLength THEN
      RETURN FALSE;
   ELSIF MaximalLineLength < MINIMAL_MIME_WORD_LENGTH THEN
      RETURN FALSE;
   END;

   // decrease allowed lengths by minimally occupied data and prepare first iteration
   DEC( MaximalLineLength, MINIMAL_MIME_WORD_LENGTH );
   IF FirstLineLength < MINIMAL_MIME_WORD_LENGTH THEN // fold line with insufficient length
      mimeWords.FromOA( FOLD );
      encodedLength := MaximalLineLength;
   ELSE // adjust input to not to oversize allowed line length
      DEC( FirstLineLength, MINIMAL_MIME_WORD_LENGTH );
      encodedLength := FirstLineLength;
   END;
   maximalInputCharacters := cphcommon.BASE64ByteCount( encodedLength ); // convert allowed bytes size (encodedLength) to input characters count (maximalInputCharacters)
   IF maximalInputCharacters > 0 THEN // if maximalInputCharacters is zero, then chunk is shorter than BASE64 minimal chunk and therefore whole number of characters (encodedLength) must be taken
      encodedLength := maximalInputCharacters;
   END;
   IF encodedLength > String.Length THEN // only the String must be encoded, not more
      encodedLength := String.Length;
   END;

   // now, precompute maximalInputCharacters for MaximalLineLength;
   // for the FirstLineLength the encodedLength is already corrected
   maximalInputCharacters := cphcommon.BASE64ByteCount( MaximalLineLength );

   index := 0;
   WHILE index < String.Length DO
      // encode a part of string
      String.Substring( index, encodedLength, OUT slice );
      ToMimeWord( slice, OUT mimeWord );
      mimeWords.Append( mimeWord );
         
      // prepare, if needed, the next slice
      INC( index, encodedLength );
      encodedLength := String.Length - index;
      IF encodedLength > 0 THEN
         mimeWords.AppendOA( FOLD );
      END;
      IF encodedLength > maximalInputCharacters THEN
         encodedLength := maximalInputCharacters;
      END;
   END; // WHILE

   Mimewords.Assign( mimeWords );
   RETURN TRUE;
END ToMimeWords;

(*================================================================================*)

END MIME.