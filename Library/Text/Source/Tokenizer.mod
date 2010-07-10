IMPLEMENTATION MODULE Tokenizer;

FROM Exceptions IMPORT
   StoreException, TestIfCatched, RetrieveException;

IMPORT
   Time,
   Sync;

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
   END InitNumber;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE InitString( CONST String : StringsO.IString );
   BEGIN
      _Type := tokenString;
      _Data.Assign( String );
   END InitString;

(*--------------------------------------------------------------------------------*)

BEGIN
   _Type := tokenUnknown;
   _Delimiter := delUnknown;
   _Number := numDecimal;
END CToken;
   
(*================================================================================*)

CLASS IMPLEMENTATION CFeedException;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE FormatCode( OUT Code : ARRAY OF WCHAR );
   BEGIN
      IF NOT Sync.ResultToName( Sync.TAsyncResult( SELF.Code ), OUT Code ) THEN
         SUPER.FormatCode( OUT Code );
      END;
   END FormatCode;

(*--------------------------------------------------------------------------------*)

END CFeedException;

(*--------------------------------------------------------------------------------*)

PROCEDURE FeedException( Result : Sync.TAsyncResult ) : CFeedException;
VAR
   FE : CFeedException;
BEGIN
   FE.Init( CARDINAL( Result ), NIL, L"", L"" );
   RETURN FE;
END FeedException;

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
      _TokenNumber := 0;
      _Position := 0;
      _Line := 0;
      _Column := 0;
      _Marks.Dispose();

      // reading      
      _InProgress := FALSE;
      _Next := 0W;
      _Type := tokenUnknown;
      _Data.Clear();
      _Delimiter := delUnknown;
      _Number := numDecimal;
      _CurrentLength := 0;
   END Reset;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE MoveNext( TimeoutMS : CARDINAL ) : Sync.TAsyncResult;
   BEGIN
      _StopTime : Time.UptimeMS() + TimeoutMS;
      TRY
         DoMoveNext();
         RETURN Sync.asCompleted;
      CATCH fe : CFeedException DO
         RETURN Sync.TAsyncResult( fe.Code );
      END;
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
      _Strings := Value;
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

   PRIVATE PROCEDURE DoMoveNext();
   LABEL
      DoKeyword,
      DoNot, DoAmpersand, DoLogicalAnd, DoAsterisk, DoPlus, DoMinus, DoDot, DoSlash, DoColon, DoLess, DoEqual, DoGreater, DoBackslash, DoCircumflex, DoPipe, DoLogicalOr,
      DoNumber,
      DoApostropheString, DoGraveString, DoQuoteString
   CONST
      ASCII_ID_BEGIN_SET = StringsO.WCHARS{L"A".."Z", "a".."z", "_"};
      ASCII_ID_SET = StringsO.WCHARS{L"A".."Z", "a".."z", "_", "0".."9"};
      DELIMITER_BEGIN_SET = StringsO.WCHARS{L"!", L"#", L"$", L"%", L"&", L"'", L"(", L")", L"*", L"+", L",", L"-", L".", L"/", L":", L";", L"<", L"=", L">", L"?", L"[", L"\", L"]", L"^", L"_", L"{", L"|", L"}", L"~"};
      NEXT_WHITE_SPACE_SET = StringsO.WCHARS{9W, 10W, 13W, 32W};
      NUMBER_SET = StringsO.WCHARS{L"0"..L"9"};
      WHITE_SPACE_SET = StringsO.WCHARS{9W, 32W};
   VAR
      Ch : WCHAR;
      WS : TPCharacters;
   BEGIN
      IF _WhiteSpaces = NIL THEN
         WS := ADR( WHITE_SPACE_SET );
      ELSE
         WS := _WhiteSpaces;
      END;
      IF _Delimiters = NIL THEN
         DEL := ADR( DELIMITER_BEGIN_SET );
      ELSE
         DEL := _Delimiters;
      END;
   
      CASE _Type OF
      | tokenUnknown : // fall down to the loop
      | tokenKeyword : GOTO DoKeyword;
      | tokenDelimiter :
         CASE _Delimiter OF
         | delNot : GOTO DoNot;
         | delAmpersand : GOTO DoAmpersand;
         | delLogicalAnd : GOTO DoLogicalAnd;
         | delAsterisk : GOTO DoAsterisk;
         | delPlus : GOTO DoPlus;
         | delMinus : GOTO DoMinus;
         | delDot : GOTO DoDot;
         | delSlash : GOTO DoSlash;
         | delColon : GOTO DoColon;
         | delLess : GOTO DoLess;
         | delEqual : GOTO DoEqual;
         | delGreater : GOTO DoGreater;
         | delBackslash : GOTO DoBackslash;
         | delCircumflex : GOTO DoCircumflex;
         | delPipe : GOTO DoPipe;
         | delLogicalOr : GOTO DoLogicalOr;
         END;
      | tokenNumber : GOTO DoNumber;
      | tokenString :
         CASE _String OF
         | strApostrophe : GOTO DoApostropheString;
         | strGrave : GOTO DoGraveString;
         | strQuote : GOTO DoQuoteString;
         END;
      END; // CASE

      TRY
         LOOP // LOOP assures looping around whitespaces and lines
            Ch := Feed();

            // keyword start      
            IF Ch IN ASCII_ID_BEGIN_SET THEN   
               _Type = tokenKeyword;
               _Data.Append( Ch );
               LOOP
            DoKeyword:
                  Ch := Feed();
                  IF Ch IN ASCII_ID_SET THEN
                     _Data.Append( Ch );
                  ELSE
                     GOTO Finish;
                  END;
               END;
               
            // delimiters start
            ELSIF Ch IN DEL^ THEN
               _Type := tokenDelimiter;
               CASE Ch OF
               | L"!" :
                  _Delimiter := delNot; // !
               DoNot:
                  IF ( _Next = L"=" ) AND ( mulNotEqual1 IN _Multigrams ) THEN
                     Feed();
                     _Delimiter := delNotEqual1; // !=
                  END;
               | L'"' :
                  _Delimiter := delQuote; // "
               | L"#" :
                  _Delimiter := delNumberSign; // #
               | L"$" :
                  _Delimiter := delDollar; // $
               | L"%" :
                  _Delimiter := delPercent; // %
               | L"&" :
                  _Delimiter := delAmpersand; // &
               DoAmpersand:
                  IF ( _Next = L"&" ) AND ( TMultigrams{mulLogicalAnd, mulLogicalNotShurtcutAnd, mulLogicalAndAssignment} * _Multigrams <> TMultigrams{} ) THEN
                     Feed();
                     _Delimiter := delLogicalAnd; // &&
                  DoLogicalAnd:
                     IF ( _Next = L"&" ) AND ( mulLogicalNotShortcutAnd IN _Multigrams ) THEN
                        Feed();
                        _Delimiter = delLogicalNotShortcutAnd; // &&&
                     ELSIF ( _Next = L"=" ) AND ( mulLogicalAndAssignment IN _Multigrams ) THEN
                        Feed();
                        _Delimiter := delLogicalAndAssignment; // &&=
                     END;
                  ELSIF ( _Next = L"=" ) AND ( mulAndAssignment IN _Multigrams ) THEN
                     Feed();
                     _Delimiter := delAndAssignment; // &=
                  END;
               | L"'" :
                  _Delimiter := delApostrophe; // '
               | L"(" :
                  _Delimiter := delParenthesisL; // (
               | L")" :
                  _Delimiter := delParenthesisR; // (
               | L"*" :
                  _Delimiter := delAsterisk; // *
               DoAsterisk:
                  IF ( _Next = L"*" ) AND ( mulMultiplyAssignment IN _Multigrams ) THEN
                     Feed();
                     _Delimiter := delMultiplyAssignment; // *=
                  ELSIF ( _Next = L"*" ) AND ( mulPower IN _Multigrams ) THEN
                     Feed();
                     _Delimiter := delPower; // **
                  END;
               | L"+" :
                  _Delimiter := delPlus; // +
               DoPlus:
                  IF ( _Next = L"+" ) AND ( mulIncrement IN _Multigrams ) THEN
                     Feed();
                     _Delimiter := delIncrement; // ++
                  ELSIF ( _Next = L"=" ) AND ( mulPlusAssignment IN _Multigrams ) THEN
                     Feed();
                     _Delimiter := delPlusAssignment; // +=
                  END;
               | L"," :
                  _Delimiter := delComma; // ,
               | L"-" :
                  _Delimiter := delMinus; // -
               DoMinus:
                  IF ( _Next = L">" ) AND ( mulAccessor1 IN _Multigrams ) THEN
                     Feed();
                     _Delimiter := delAccessor1; // ->
                  ELSIF ( _Next = L"-" ) AND ( mulDecrement IN _Multigrams ) THEN
                     Feed();
                     _Delimiter := delDecrement; // --
                  ELSIF ( _Next = L"=" ) AND ( mulMinusAssignment IN _Multigrams ) THEN
                     Feed();
                     _Delimiter := delMinusAssignment; // -=
                  END;
               | L"." :
                  _Delimiter := delDot; // .
               DoDot:
                  IF ( _Next = L"." ) AND ( mulInterval IN _Multigrams ) THEN
                     Feed();
                     _Delimiter := delInterval; // ..
                  END;
               | L"/" :
                  _Delimiter := delSlash; // /
               DoSlash:
                  IF ( _Next = L"/" ) AND ( mulComment IN _Multigrams ) THEN
                     Feed();
                     _Delimiter := delComment; // //
                  ELSIF ( _Next = L"=" ) AND ( mulDivideAssignment IN _Multigrams ) THEN
                     Feed();
                     _Delimiter = delDivideAssignment; // /=
                  END;
               | L":" :
                  _Delimiter := delColon; // :
               DoColon:
                  IF ( _Next = L"=" ) AND ( mulAssignment IN _Multigrams ) THEN
                     Feed();
                     _Delimiter = delAssignment; // :=
                  END;
               | L";" :
                  _Delimiter := delSemicolon; // ;
               | L"<" :
                  _Delimiter := delLess; // <
               DoLess:
                  IF ( _Next = L"=" ) AND ( mulLessEqual IN _Multigrams ) THEN
                     Feed();
                     _Delimiter := delLessEqual; // <=
                  ELSIF ( _Next = L">" ) AND ( mulNotEqual2 IN _Multigrams ) THEN
                     Feed();
                     _Delimiter := delNotEqual2; // <>
                  END;
               | L"=" :
                  _Delimiter := delEqual; // :
               DoEqual:
                  IF ( _Next = L"=" ) AND ( mulEqualEqual IN _Multigrams ) THEN
                     Feed();
                     _Delimiter := delEqual; // ==
                  END;
               | L">" :
                  _Delimiter := delGreater; // >
               DoGrater:
                  IF ( _Next = L"=" ) AND ( mulGreaterEqual IN _Multigrams ) THEN
                     Feed();
                     _Delimiter := delGreaterEqual; // >=
                  END;
               | L"?" :
                  _Delimiter := delQuestionMark; // ?
               | L"@" :
                  _Delimiter := delAt; // @
               | L"[" :
                  _Delimiter := delBracketL; // [
               | L"\" :
                  _Delimiter := delBackslash; // \
               DoBackslash:
                  IF ( _Next = L"\" ) AND ( mulBackslashEscape IN _Multigrams ) THEN
                     Feed();
                     _Delimiter := delBackslashEscape; // \\
                  END;
               | L"]" :
                  _Delimiter := delBracketR; // ]
               | L"^" :
                  _Delimiter := delCircumflex; // ^
               DoCircumflex:
                  IF ( _Next = L"." ) AND ( mulAccessor2 IN _Multigrams ) THEN
                     Feed();
                     _Delimiter := mulAccessor2; // ^.
                  END;
               | L"_" :
                  _Delimiter := delUnderscore; // _
               | L"{" :
                  _Delimiter := delBraceL; // {
               | L"|" :
                  _Delimiter := delPipe; // |
               DoPipe:
                  IF ( _Next = L"|" ) AND ( TMultigrams{mulLogicalOr, mulLogicalNotShurtcutOr, mulLogicalOrAssignment} * _Multigrams <> TMultigrams{} ) THEN
                     Feed();
                     _Delimiter := delLogicalOr; // ||
                  DoLogicalOr:
                     IF ( _Next = L"|" ) AND ( mulLogicalNotShortcutOr IN _Multigrams ) THEN
                        Feed();
                        _Delimiter := delLogicalNotShortcutOr; // |||
                     ELSIF ( _Next = L"=" ) AND ( mulLogicalOrAssignment IN _Multigrams ) THEN
                        Feed();
                        _Delimiter := delLogicalOrAssignment; // ||=
                     END;
                  ELSIF ( _Next = L"=" ) AND ( mulOrAssignment IN _Multigrams ) THEN
                     Feed();
                     _Delimiter := delOrAssignment; // |=
                  END;
               | L"}" :
                  _Delimiter := delBraceR; // }
               | L"~" :
                  _Delimiter := delTilde; // ~

               END; // CASE
               GOTO Finish;

            // white spaces start
            ELSIF Ch IN WS^ THEN
               LOOP
                  Ch := Feed();
                  IF Ch NOT IN WS^ THEN
                     EXIT;
                  END;
               END;            
            ELSIF Ch = 13W THEN
               // ignore
            ELSIF Ch = 10W THEN
               _Column := 0;
               INC( _Line );            

            // number start
            ELSIF Ch IN NUMBER_SET THEN
               _Type := tokenKeyword;
               _Data.Append( Ch );
               LOOP
            DoNumber:
                  Ch := Feed();
                  IF Ch IN NUMBER_SET THEN
                     _Data.Append( Ch );
                  ELSE
                     GOTO Finish;
                  END;
               END;
            
            // strings
            ELSIF Ch = '"' THEN
               _Type := tokenString;
               _String := strQuote;
               LOOP
            DoQuoteString:
                  Ch := Feed();
                  IF Ch = '"' THEN
                     GOTO Finish;
                  ELSE
                     _Data.AppendOA( Ch );
                  END;
               END;

            ELSIF Ch = "'" THEN
               _Type := tokenString;
               _String := strApostrophe;
               LOOP
            DoApostropheString:
                  Ch := Feed();
                  IF Ch = "'" THEN
                     GOTO Finish;
                  ELSE
                     _Data.AppendOA( Ch );
                  END;
               END;
            
            ELSIF Ch = "`" THEN
               _Type := tokenString;
               _String := strGrave;
               LOOP
            DoGraveString:
                  Ch := Feed();
                  IF Ch = "`" THEN
                     GOTO Finish;
                  ELSE
                     _Data.AppendOA( Ch );
                  END;
               END;

            END; // switch of token type
         END;
      CATCH fe : CFeedException DO
         THROW fe;
      END;
            
   Finish:
      INC( _Position, _CurrentLength );
      INC( _TokenNumber );
      CASE _Type OF
      | tokenKeyword :
         _Current.InitKeyword( _Data );
         _CurrentLength := _Data.Length;
      | tokenNumber :
         _Current.InitNumber( _Number, _Data );
         _CurrentLength := _Data.Length;
      | tokenDelimiter :
         _Current.InitDelimiter( _Delimiter );
         _CurrentLength := 1; // TODO longer delimiters
      | tokenString :
         _Current.InitString( _Data );
         _CurrentLength := _Data.Length; // TODO unescaped/escaped
      END;
      _Type := tokenUnknown;
      _Data.Clear();
   END DoMoveNext;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Feed() : WCHAR;
   VAR
      Result : Sync.TAsyncResult;
      timeout : INTEGER;
   BEGIN
      timeout := INTEGER( _StopTime - Time.UptimeMS());
      IF timeout <= 0 THEN
         THROW FeedException( Sync.arTimeout );
      END;

      // handle ahead reading
      IF _Next = 0W THEN
         Result := ReadCharS( OUT Ch, timeout, TRUE );
         IF Result NOT IN Sync.arsCompletions THEN
            THROW FeedException( Result );
         END;
         timeout := INTEGER( _StopTime - Time.UptimeMS());
         IF timeout <= 0 THEN
            THROW FeedException( Sync.arTimeout );
         END;

         INC( _Line );            
      ELSE
         Ch := _Next;
      END;

      // read new
      Result := ReadChar( OUT _Next, timeout, TRUE );
      IF Result NOT IN Sync.arsCompletions THEN
         THROW FeedException( Result );
      END;

      INC( _Position );
      INC( _Column );

      RETURN Ch;
   END Feed;

(*--------------------------------------------------------------------------------*)

BEGIN
   _Next := 0W;
END CTokenizer;

(*================================================================================*)

END Tokenizer.
