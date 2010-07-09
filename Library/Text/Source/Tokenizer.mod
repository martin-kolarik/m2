IMPLEMENTATION MODULE Tokenizer;

(*================================================================================*)

VAR
   empty : StringsO.CString;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CToken;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Type GET : TToken;
   BEGIN
      RETURN _Type;
   END Type;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Delimiter GET : TDelimiter;
   BEGIN
      IF _Type = tokenDelimiter THEN
         RETURN _Delimiter;
      ELSE
         RETURN delUnknown;
      END;
   END Delimiter;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Keyword GET : StringsO.CString;
   BEGIN
      IF _Type = tokenKeyword THEN
         RETURN _Data;
      ELSE
         RETURN empty;
      END;
   END Keyword;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY String GET : StringsO.CString;
   BEGIN
      IF _Type = tokenString THEN
         RETURN _Data;
      ELSE
         RETURN empty;
      END;
   END String;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Number GET : StringsO.CString;
   BEGIN
      IF _Type = tokenNumber THEN
         RETURN _Data;
      ELSE
         RETURN empty;
      END;
   END Number;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Integer GET : INT32;
   VAR
      i : INT32;
      s : StringsO.CString;
   BEGIN
      IF _Type <> tokenNumber THEN
         RETURN 0;
      END;
      CASE _Number OF
      | numDecimal :
         s := _Data;
      | numCHexadecimal :
         _Data.Substring( 2, -1, OUT s ); // trim 0x
      | numCOctal :
         _Data.Substring( 1, -1, OUT s ); // trim 0
      | numMBinary, numMOctal, numMHexadecimal : // trim B, O, H
         s := _Data;
         DEC( s.Length );
      | numPlainHexadecimal :
         s := _Data;
      ELSE
         RETURN 0;
      END;
      IF s.ToCARD32( CARDINAL( _Number ), OUT i ) THEN
         RETURN i;
      ELSE
         RETURN 0;
      END;
   END Integer;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Long GET : INT64;
   VAR
      i : INT64;
      s : StringsO.CString;
   BEGIN
      IF _Type <> tokenNumber THEN
         RETURN 0;
      END;
      CASE _Number OF
      | numDecimal :
         s := _Data;
      | numCHexadecimal :
         _Data.Substring( 2, -1, OUT s ); // trim 0x
      | numCOctal :
         _Data.Substring( 1, -1, OUT s ); // trim 0
      | numMBinary, numMOctal, numMHexadecimal : // trim B, O, H
         s := _Data;
         DEC( s.Length );
      | numPlainHexadecimal :
         s := _Data;
      ELSE
         RETURN 0;
      END;
      IF s.ToCARD64( CARDINAL( _Number ), OUT i ) THEN
         RETURN i;
      ELSE
         RETURN 0;
      END;
   END Long;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Float GET : LONGREAL;
   VAR
      r : LONGREAL;
   BEGIN
      IF _Type <> tokenNumber THEN
         RETURN 0.0;
      ELSIF _Number <> numFloat THEN
         RETURN 0.0;
      ELSIF _Data.ToLONGREAL( OUT r ) THEN
         RETURN r;
      ELSE
         RETURN 0.0;
      END;
   END Float;
      
(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE InitKeyword( CONST Keyword : StringsO.IString );
   BEGIN
      _Type := tokenKeyword;
      _Data.Assign( Keyword );
   END InitKeyword;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE InitDelimiter( Delimiter : TDelimiter );
   BEGIN
      _Type := tokenDelimiter;
      _Delimiter := Delimiter;
   END InitDelimiter;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE InitNumber( Number : TNumber; CONST String : StringsO.IString );
   BEGIN
      _Type := tokenNumber;
      _Number := Number;
      _Data.Assign( String );
   END InitKeyword;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE InitString( CONST String : StringsO.IString );
   BEGIN
      _Type := tokenString;
      _Data.Assign( String );
   END InitKeyword;

(*--------------------------------------------------------------------------------*)

BEGIN
   _Type := tokenDelimiter;
   _Delimiter := delUnknown;
   _Number := numDecimal;
END CToken;
   
(*================================================================================*)

CLASS IMPLEMENTATION CTokenizer;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Current GET : CToken;
   BEGIN
      RETURN _Current;
   END Current;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY TokenNumber GET : CARD64;
   BEGIN
      RETURN _Number;
   END TokenNumber;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Position GET : CARD64;
   BEGIN
      RETURN _Position;
   END Position;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Line GET : CARD64;
   BEGIN
      RETURN _Line;
   END Line;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Column GET : CARDINAL;
   BEGIN
      RETURN _Column;
   END Column;
      
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Reset(); // rewinds to start
   VAR
      empty : CToken;
   BEGIN
      _Current := empty;
      _CurrentLength := 0;
      _Number := numDecimal;
      _Position := 0;
      _Line := 0;
      _Column := 0;
      _Marks.Dispose();
      // TODO
   END Reset;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE MoveNext( TimeoutMS : CARDINAL ) : Sync.TAsyncResult;
   VAR
      Ch : WCHAR;
      Result : Sync.TAsyncResult;
   BEGIN
      LOOP
         Result := ReadChar( OUT Ch, TimeoutMS, TRUE );
         IF Result NOT IN Sync.arsCompletions THEN
            RETURN Result;
         END;

         CASE Ch OF
         | L"0"..L"9" :
            
         | 
         
         END; // CASE
      END; // LOOP
      
      RETURN Sync.arCompleted;
   END MoveNext;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Mark() : PTR; // return mark handle of current position
   BEGIN
   END Mark;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE GotoMark( Handle : PTR );
   BEGIN
   END GotoMark;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Reader GET : TextReader.TPReader;
   BEGIN
      RETURN _Reader;
   END Reader;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Reader SET( Value : TextReader.TPReader );
   BEGIN
      _Reader := Value;
   END Reader;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Numbers GET : TNumbers;
   BEGIN
      RETURN _Numbers;
   END Numbers;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Numbers SET( Value : TNumbers );
   BEGIN
      _Numbers := Value;
   END Numbers;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Strings GET : TStrings;
   BEGIN
      RETURN _Strings;
   END Strings;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Strings SET( Value : TStrings );
   BEGIN
      RETURN _Strings;
   END Strings;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY UnescapeStrings GET : BOOLEAN;
   BEGIN
      RETURN _UnescapeStrings;
   END UnescapeStrings;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY UnescapeStrings SET( Value : BOOLEAN );
   BEGIN
      _UnescapeStrings := Value;
   END UnescapeStrings;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY WhiteSpaces GET : TPCharacters;
   BEGIN
      RETURN _WhiteSpaces;
   END WhiteSpaces;
      
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY WhiteSpaces SET( Value : TPCharacters );
   BEGIN
      _WhiteSpaces := Value;
   END WhiteSpaces;
      
(*--------------------------------------------------------------------------------*)

BEGIN
END CTokenizer;

(*================================================================================*)

END Tokenizer.
