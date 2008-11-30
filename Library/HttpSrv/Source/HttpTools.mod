IMPLEMENTATION MODULE HttpTools;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   cphcommon,
   Languages,
   lists,
   StorageO,
   Strings;

(*===========================================================================*)

PROCEDURE FormatDate( CONST Date : time.TDateTime ) : StringsO.CString;
CONST
   HTTP_TIME_FORMAT = L"ddd, dd MMM yyyy HH:mm:ss 'GMT'";
VAR
   formatted : ARRAY [0..255] OF WCHAR;
   s : StringsO.CString;
BEGIN
   IF time.DateTimeToStringLang( Languages.GetDefaultLanguage( Languages.dlNeutral ), Date, HTTP_TIME_FORMAT, TRUE, TRUE, formatted ) THEN
      s.FromOA( formatted );
   END;
   RETURN s;
END FormatDate;

(*---------------------------------------------------------------------------*)

PROCEDURE FormatDateJD( Date : time.TJD ) : StringsO.CString;
VAR
   dt : time.TDateTime;
BEGIN
   time.JDToZonalDateTime( Date, dt, 0, 0 );
   RETURN FormatDate( dt );
END FormatDateJD;

(*---------------------------------------------------------------------------*)

PROCEDURE FormatSIDCookie( CONST SID : StringsO.IString; Expires : time.TJD; CONST Path, Domain : StringsO.IString ) : StringsO.CString;
VAR
   s : StringsO.CString;
BEGIN
   s.FromOA( L"sid=" ); s.Append( SID );
   IF Expires > 0 THEN
      s.AppendOA( L"; expires=" );
      s.Append( FormatDateJD( Expires ));
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

PROCEDURE FormatContent( Content : TContent; CONST RFC1766Code : StringsO.IString ) : StringsO.CString;
VAR
   s : StringsO.CString;
BEGIN
   CASE Content OF
   | contentTextPlain :
      s.FromOA( L"text/plain; charset=" );
   | contentTextHTML :
      s.FromOA( L"text/html; charset=" );
   END;
   s.Append( RFC1766Code );
   RETURN s;
END FormatContent;

(*---------------------------------------------------------------------------*)

PROCEDURE FormatContentOA( Content : TContent; CONST RFC1766Code : ARRAY OF WCHAR ) : StringsO.CString;
VAR
   s : StringsO.CString;
BEGIN
   s.FromOA( RFC1766Code );
   RETURN FormatContent( Content, s );
END FormatContentOA;

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
      s.FromOA( OA( i-1, sl.Current^.rawData ));

      // second part
      l := sl.Current^.Length;
      IF i+1 <= l THEN
         sd.FromOA( OA( l-i-2, sl.Current^.rawData@[(i+1)<<1] ));
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
         RETURN HttpCommon.httpres_302;
      ELSE
         RETURN HttpCommon.httpres_302;
      END;
   ELSE
      IF HTTP10Flag THEN
         RETURN HttpCommon.httpres_302;
      ELSE
         RETURN HttpCommon.httpres_302;
      END;
   END;
END GetRedirectCode;

(*===========================================================================*)

END HttpTools.