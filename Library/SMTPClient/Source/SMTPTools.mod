IMPLEMENTATION MODULE SMTPTools;

FROM Debug IMPORT
   Assertion, LogAssertionW;

IMPORT
   cphcommon,
   cphcommonO,
   languages,
   languagesO,
   StorageO;

(*--------------------------------------------------------------------------------*)

CONST
   RFC822_LINE_LENGTH = 78;
   PREFIX = L"=?utf-8?b?";
   SUFFIX = L"?=";
   MINIMAL_MIME_WORD_LENGTH = HIGH( PREFIX )+1 + HIGH( SUFFIX )+1 + 4 + 1; // 4 for single BASE64 chunk (0--3 bytes), 1 for folding <SP>
   FOLD = 13W + 10W + 32W; // <CRLF> <SP>

(*================================================================================*)

PROCEDURE CodeToResponse( Code : CARDINAL ) : TSmtpResponse;
BEGIN
   CASE Code OF
   | 211: RETURN smtpres_211;
   | 214: RETURN smtpres_214;
   | 220: RETURN smtpres_220;
   | 221: RETURN smtpres_221;
   | 235: RETURN smtpres_235;
   | 250: RETURN smtpres_250;
   | 251: RETURN smtpres_251;
   | 334: RETURN smtpres_334;
   | 354: RETURN smtpres_354;
   | 421: RETURN smtpres_421;
   | 432: RETURN smtpres_432;
   | 450: RETURN smtpres_450;
   | 451: RETURN smtpres_451;
   | 452: RETURN smtpres_452;
   | 454: RETURN smtpres_454;
   | 500: RETURN smtpres_500;
   | 501: RETURN smtpres_501;
   | 502: RETURN smtpres_502;
   | 503: RETURN smtpres_503;
   | 504: RETURN smtpres_504;
   | 521: RETURN smtpres_521;
   | 530: RETURN smtpres_530;
   | 534: RETURN smtpres_534;
   | 538: RETURN smtpres_538;
   | 550: RETURN smtpres_550;
   | 551: RETURN smtpres_551;
   | 552: RETURN smtpres_552;
   | 553: RETURN smtpres_553;
   | 554: RETURN smtpres_554;
   ELSE // unknown response code
      ASSERTLOG( FALSE, L"Unknown SMTP response code" );
      RETURN smtpres_Unknown;
   END;
END CodeToResponse;

(*--------------------------------------------------------------------------------*)

PROCEDURE StringToResponse( CONST String : StringsO.IString ) : TSmtpResponse;
VAR
   number : StringsO.CString;
   statusCode : CARDINAL;
BEGIN
   IF String.Length < 3 THEN
      RETURN smtpres_Unknown;
   END;
   String.Substring( 0, 3, OUT number );
   IF number.ToCARD32( 10, OUT statusCode ) THEN
      RETURN CodeToResponse( statusCode );
   ELSE // malformed, not a number
      RETURN smtpres_Unknown;
   END;
END StringToResponse;

(*================================================================================*)

PROCEDURE AnalyzeHeaderEncoding( CONST String : StringsO.IString; OUT NeededEncoding : THeaderEncoding; OUT ContainsSpaces : BOOLEAN );
VAR
   ch : WCHAR;
   i : INTEGER;
BEGIN
   ContainsSpaces := FALSE;
   IF String.Length > RFC822_LINE_LENGTH THEN
      NeededEncoding := HeaderEncodingMimeWord; // only this encoding can split strings without spaces
   ELSE
      NeededEncoding := HeaderEncodingPlain;
      FOR i := 0 TO String.Length-1 DO
         ch := String[i];
         IF ch > 127W THEN
            ContainsSpaces := FALSE;
            NeededEncoding := HeaderEncodingMimeWord;
            EXIT;
         ELSIF ch = L" " THEN
            ContainsSpaces := TRUE;
         ELSIF ( ch = L"\" ) OR ( ch = L'"' ) THEN
            NeededEncoding := HeaderEncodingEscaped;
         END;
      END;
   END;
END AnalyzeHeaderEncoding;

(*--------------------------------------------------------------------------------*)

PROCEDURE ToMimeWords( CONST String : StringsO.IString; FirstLineLength, MaximalLineLength : CARDINAL; OUT Mimewords : StringsO.IString ) : BOOLEAN; // Mimewords contains <CRLF> <SP> separated mimewords
VAR
   base64 : StringsO.CString;
   buffer : StorageO.CMemoryBuffer;
   encodedLength : CARDINAL;
   index : CARDINAL;
   maximalInputCharacters : CARDINAL;
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
      languagesO.ToMB( slice, languages.cp_UTF8, FALSE, REF buffer );
      cphcommonO.ToBASE64( buffer, OUT base64 );

      // combine it to whole mime word
      mimeWords.AppendOA( PREFIX );
      mimeWords.Append( base64 );
      mimeWords.AppendOA( SUFFIX );
         
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

(*--------------------------------------------------------------------------------*)

PROCEDURE AppendStringToHeader( REF header : StringsO.IString; CONST string : StringsO.IString; StringTypeHint : TStringTypeHint );
CONST
   MIME_TOTAL_WORD_LENGTH = 75;
   MIME_DATA_WORD_LENGTH = MIME_TOTAL_WORD_LENGTH - MINIMAL_MIME_WORD_LENGTH; // DATA_WORD is shorted by 3 bytes, than it could be, but it does not matter, because probably ToMimeWords exhausts the reserve
VAR
   brackets : BOOLEAN;
   containsSpace : BOOLEAN;
   lineLength : CARDINAL;
   neededEncoding : THeaderEncoding;
   quotes : BOOLEAN;
   s : StringsO.CString;
BEGIN
   AnalyzeHeaderEncoding( string, OUT neededEncoding, OUT containsSpace );

   CASE neededEncoding OF
   //-----
   | HeaderEncodingPlain,
     HeaderEncodingEscaped :
      s.Copy( string );
      IF neededEncoding = HeaderEncodingEscaped THEN
         s.ReplaceOA( L'\', L'\\' );
         s.ReplaceOA( L'"', L'\"' );
      END;
      brackets := StringTypeHint = StringTypeHintAddress;
      IF brackets THEN
         quotes := containsSpace;
      ELSE
         quotes := StringTypeHint = StringTypeHintQuoted;
      END;
      IF brackets AND quotes THEN // only a local part of address must be quoted
         header.AppendOA( L'<"' );
         s.ReplaceOA( L'@', L'"@' );
         header.Append( s );
         header.AppendOA( L'>' );
      ELSIF brackets THEN
         header.AppendOA( L'<' );
         header.Append( s );
         header.AppendOA( L'>' );
      ELSIF quotes THEN
         header.AppendOA( L'"' );
         header.Append( s );
         header.AppendOA( L'"' );
      ELSE
         header.Append( s );
      END;

   //-----
   | HeaderEncodingMimeWord :
      IF header.Length > MIME_DATA_WORD_LENGTH THEN // no space for prefix and suffix
         header.AppendOA( FOLD );
         lineLength := MIME_DATA_WORD_LENGTH;
      ELSE 
         lineLength := MIME_DATA_WORD_LENGTH - header.Length; // first line is shorter
      END;
      ToMimeWords( string, lineLength, MIME_DATA_WORD_LENGTH, OUT s );
      header.Append( s );

   //-----
   ELSE
      ASSERTLOG( FALSE, L"Unexpected HeaderEncoding" );
      header.Append( string );
   END;
END AppendStringToHeader;

(*================================================================================*)

END SMTPTools.