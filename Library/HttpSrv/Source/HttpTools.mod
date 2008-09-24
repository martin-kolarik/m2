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

PROCEDURE DecodeQueryURL( XFormFlag : BOOLEAN; FirstCharsSkipCount : INTEGER; CONST Encoded : ARRAY OF WCHAR; OUT Decoded : maps.CStringStringMap );
VAR
   byte : BYTE;
   ch : WCHAR;
   i : INTEGER;
   l : INTEGER := LENGTH( Encoded );
   mb : StorageO.CMemoryBuffer;
   previ : INTEGER;
   s : StringsO.CString;
   sd : StringsO.CString;
   sl : lists.CStringList;
BEGIN
   // at first, split to strings
   previ := FirstCharsSkipCount;
   LOOP
      i := Strings.IndexOfCharW( Encoded, L"&", previ );
      IF i = -1 THEN
         l := HIGH( Encoded )-previ+1;
         sl.AddOA( OA( l-1, ADR( Encoded[previ] )), PTR( l ));
         EXIT;
      ELSE
         l := i-previ;
         sl.AddOA( OA( l-1, ADR( Encoded[previ] )), PTR( l ));
      END;
      previ := i+1;
   END; // LOOP

   // find equals and revert + to spaces if XFormFlag
   sl.Reset();
   WHILE sl.MoveNext() DO
      i := 0;
      l := sl.Current^.Length;
      mb.Size := l;
      mb.Length := l;

      WHILE i < l DO
         ch := sl.Current^[i];
         IF ch = L"%" THEN // decode three %XX characters
            IF i+2 >= l THEN
               EXIT; // errorneous input
            END;
            cphcommon.FromHexByte( OA( 1, sl.Current^.rawData@[(i+1)<<1] ), OUT byte );
            mb[i] := byte;

            sl.Current^.Remove( i+1, 2 );
            DEC( l, 2 );

         ELSIF ch = L"=" THEN // remember split position (length)
            sl.CurrentData := PTR( i );
            mb[i] := BYTE( C"=" );

         ELSIF XFormFlag AND ( ch = L"+" ) THEN // replace + with spaces
            mb[i] := BYTE( C" " );

         ELSE
            mb[i] := BYTE( ch );
         END;
         
         INC( i );
      END;
      
      IF Languages.IsUTF8( OA( i-1, mb.Data )) THEN
         sl.Current^.FromOAA( Languages.cp_UTF8, OA( i-1, PCHAR( mb.Data )));
      ELSE
         sl.Current^.FromOAA( 0, OA( i-1, PCHAR( mb.Data )));
      END;
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
      END;
      
      Decoded.Add( s, sd );
   END; // WHILE
   
   sl.Dispose();
END DecodeQueryURL;

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