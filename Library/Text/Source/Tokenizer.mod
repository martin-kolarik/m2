IMPLEMENTATION MODULE Tokenizer;

FROM Exceptions IMPORT
   StoreException, TestIfCatched, RetrieveException;

IMPORT
   DateTime,
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

   PUBLIC PROPERTY Base GET : CARDINAL;
   BEGIN
      IF _Type = tokenNumber THEN
         RETURN BASES[_Number];
      ELSE
         RETURN 0;
      END;
   END Base;

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
      IF s.ToCARD32( BASES[_Number], OUT i ) THEN
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

CONST
   DELIMITER_BEGIN_SET = StringsO.WCHARS{L"!", L"#", L"$", L"%", L"&", L"'", L"(", L")", L"*", L"+", L",", L"-", L".", L"/", L":", L";", L"<", L"=", L">", L"?", L"[", L"\", L"]", L"^", L"_", L"{", L"|", L"}", L"~"};
   WHITE_SPACE_SET = StringsO.WCHARS{9W, 32W};

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CTokenizer;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Current GET : CToken;
   BEGIN
      RETURN _CurrentToken;
   END Current;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY TokenNumber GET : CARD64;
   BEGIN
      RETURN _TokenNumber;
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
      _CurrentToken := empty;
      _TokenNumber := 0;
      _Position := 0;
      _Line := 0;
      _Column := 0;
      _Marks.Dispose();

      // reading      
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
      _StopTime := DateTime.UptimeMS() + TimeoutMS;
      TRY
         DoMoveNext();
         RETURN Sync.arCompleted;
      CATCH fe : CFeedException DO
         RETURN Sync.TAsyncResult( fe.Code );
      END;
   END MoveNext;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE MarkPosition() : PTR; // return mark handle of current position
   BEGIN
      RETURN 0;
   END MarkPosition;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE GotoMarkedPosition( Handle : PTR );
   BEGIN
   END GotoMarkedPosition;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Reader GET : TextReader.TPTextReader;
   BEGIN
      RETURN _Reader;
   END Reader;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Reader SET( Value : TextReader.TPTextReader );
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

   PUBLIC VIRTUAL PROPERTY RestrictKeywordsToASCII GET : BOOLEAN;
   BEGIN
      RETURN _RestrictKeywordsToASCII;
   END RestrictKeywordsToASCII;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY RestrictKeywordsToASCII SET( Value : BOOLEAN );
   BEGIN
      _RestrictKeywordsToASCII := Value;
   END RestrictKeywordsToASCII;

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

   PUBLIC VIRTUAL PROPERTY Delimiters GET : TPCharacters;
   BEGIN
      IF _Delimiters = TPCharacters( ADR( DELIMITER_BEGIN_SET )) THEN
         RETURN NIL;
      ELSE
         RETURN _Delimiters;
      END;
   END Delimiters;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Delimiters SET( Value : TPCharacters );
   BEGIN
      IF Value = NIL THEN
         _Delimiters := TPCharacters( ADR( DELIMITER_BEGIN_SET ));
      ELSE
         _Delimiters := Value;
      END;
   END Delimiters;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Multigrams GET : TMultigrams;
   BEGIN
      RETURN _Multigrams;
   END Multigrams;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Multigrams SET( Value : TMultigrams );
   BEGIN
      _Multigrams := Value;
      // correct the set
      IF TMultigrams{mulLogicalAndAssignment, mulLogicalNotShortcutAnd} * _Multigrams <> TMultigrams{} THEN // &&=, &&& require mulLogicalAnd being present too
         INCL( _Multigrams, mulLogicalAnd );
      END;
      IF mulBeginJavaDoc2 IN _Multigrams THEN
         INCL( _Multigrams, mulBeginComment2 );
      END;
      IF mulBeginJavaDoc1 IN _Multigrams THEN
         INCL( _Multigrams, mulBeginComment1 );
      END;
      IF TMultigrams{mulLogicalOrAssignment, mulLogicalNotShortcutOr} * _Multigrams <> TMultigrams{} THEN // ||=, ||| require mulLogicalOr being present too
         INCL( _Multigrams, mulLogicalOr );
      END;
   END Multigrams;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY WhiteSpaces GET : TPCharacters;
   BEGIN
      IF _WhiteSpaces = TPCharacters( ADR( WHITE_SPACE_SET )) THEN
         RETURN NIL;
      ELSE
         RETURN _WhiteSpaces;
      END;
   END WhiteSpaces;
      
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY WhiteSpaces SET( Value : TPCharacters );
   BEGIN
      IF Value = NIL THEN
         _WhiteSpaces := TPCharacters( ADR( WHITE_SPACE_SET ));
      ELSE
         _WhiteSpaces := Value;
      END;
   END WhiteSpaces;
      
(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE DoMoveNext();
   LABEL
      Finish,
      DoKeyword,
      DoExclamationMark, DoAmpersand, DoLogicalAnd, DoParenthesisL, DoBeginComment2, DoAsterisk, DoPlus, DoMinus, DoDot, DoSlash, DoBeginComment1, DoColon, DoLess, DoEqual, DoGreater, DoCircumflex, DoPipe, DoLogicalOr,
      DoNumber,
      DoApostropheString, DoGraveString, DoQuoteString;
   CONST
      ASCII_ID_BEGIN_SET = StringsO.WCHARS{L"A".."Z", "a".."z", "_"};
      ASCII_ID_SET = StringsO.WCHARS{L"A".."Z", "a".."z", "_", "0".."9"};
      NEXT_WHITE_SPACE_SET = StringsO.WCHARS{9W, 10W, 13W, 32W};
      NUMBER_SET = StringsO.WCHARS{L"0"..L"9"};
   BEGIN
      CASE _Type OF
      | tokenUnknown : // fall down to the loop
      | tokenKeyword : GOTO DoKeyword;
      | tokenDelimiter :
         CASE _Delimiter OF
         | delExclamationMark : GOTO DoExclamationMark;
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
            Feed();

            // keyword start      
            IF _Current IN ASCII_ID_BEGIN_SET THEN   
               _Type := tokenKeyword;
               _Data.AppendOA( _Current );
            DoKeyword:
               LOOP
                  IF _Next IN ASCII_ID_SET THEN
                     Feed();
                     _Data.AppendOA( _Current );
                  ELSE
                     GOTO Finish;
                  END;
               END;
               
            // delimiters start
            ELSIF _Current IN _Delimiters^ THEN
               _Type := tokenDelimiter;
               CASE _Current OF
               | L"!" :
                  _Delimiter := delExclamationMark; // !
               DoExclamationMark:
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
                  IF ( _Next = L"&" ) AND ( TMultigrams{mulLogicalAnd, mulLogicalNotShortcutAnd, mulLogicalAndAssignment} * _Multigrams <> TMultigrams{} ) THEN
                     Feed();
                     _Delimiter := delLogicalAnd; // &&
                  DoLogicalAnd:
                     IF ( _Next = L"&" ) AND ( mulLogicalNotShortcutAnd IN _Multigrams ) THEN
                        Feed();
                        _Delimiter := delLogicalNotShortcutAnd; // &&&
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
               DoParenthesisL:
                  IF ( _Next = L"*" ) AND ( mulBeginComment2 IN _Multigrams ) THEN
                     Feed();
                     _Delimiter := delBeginComment2; // (*
                  DoBeginComment2:
                     IF ( _Next = L"*" ) AND ( mulBeginJavaDoc2 IN _Multigrams ) THEN
                        Feed();
                        _Delimiter := delBeginJavaDoc2; // (**
                     END;
                  END;
               | L")" :
                  _Delimiter := delParenthesisR; // (
               | L"*" :
                  _Delimiter := delAsterisk; // *
               DoAsterisk:
                  IF ( _Next = L"/" ) AND ( mulEndComment1 IN _Multigrams ) THEN
                     Feed();
                     _Delimiter := delEndComment1; // */
                  ELSIF ( _Next = L")" ) AND ( mulEndComment2 IN _Multigrams ) THEN
                     Feed();
                     _Delimiter := delEndComment1; // *)
                  ELSIF ( _Next = L"=" ) AND ( mulMultiplyAssignment IN _Multigrams ) THEN
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
                  IF ( _Next = L"/" ) AND ( mulLineComment IN _Multigrams ) THEN
                     Feed();
                     _Delimiter := delLineComment; // //
                  ELSIF ( _Next = L"*" ) AND ( TMultigrams{mulBeginComment1, mulBeginJavaDoc1} * _Multigrams <> TMultigrams{} ) THEN
                     Feed();
                     _Delimiter := delBeginComment1; // /*
                  DoBeginComment1:
                     IF ( _Next = L"*" ) AND ( mulBeginJavaDoc1 IN _Multigrams ) THEN
                        Feed();
                        _Delimiter := delBeginJavaDoc1; // /**
                     END;
                  ELSIF ( _Next = L"=" ) AND ( mulDivideAssignment IN _Multigrams ) THEN
                     Feed();
                     _Delimiter := delDivideAssignment; // /=
                  END;
               | L":" :
                  _Delimiter := delColon; // :
               DoColon:
                  IF ( _Next = L"=" ) AND ( mulAssignment IN _Multigrams ) THEN
                     Feed();
                     _Delimiter := delAssignment; // :=
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
               DoGreater:
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
               | L"]" :
                  _Delimiter := delBracketR; // ]
               | L"^" :
                  _Delimiter := delCircumflex; // ^
               DoCircumflex:
                  IF ( _Next = L"." ) AND ( mulAccessor2 IN _Multigrams ) THEN
                     Feed();
                     _Delimiter := delAccessor2; // ^.
                  END;
               | L"_" :
                  _Delimiter := delUnderscore; // _
               | L"{" :
                  _Delimiter := delBraceL; // {
               | L"|" :
                  _Delimiter := delPipe; // |
               DoPipe:
                  IF ( _Next = L"|" ) AND ( TMultigrams{mulLogicalOr, mulLogicalNotShortcutOr, mulLogicalOrAssignment} * _Multigrams <> TMultigrams{} ) THEN
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

            // white spaces start
            ELSIF _Current IN _WhiteSpaces^ THEN
               WHILE _Next IN _WhiteSpaces^ DO
                  Feed();
               END;            
            ELSIF _Current = 13W THEN
               // ignore
            ELSIF _Current = 10W THEN
               _Column := 0;
               INC( _Line );            

            // number start
            ELSIF _Current IN NUMBER_SET THEN
               _Type := tokenKeyword;
               _Data.AppendOA( _Current );
            DoNumber:
               WHILE _Next IN NUMBER_SET DO
                  Feed();
                  _Data.AppendOA( _Current );
               END;
            
            // strings
            ELSIF _Current = '"' THEN
               _Type := tokenString;
               _String := strQuote;
            DoQuoteString:
               LOOP
                  Feed();
                  IF _Current = '"' THEN
                     GOTO Finish;
                  ELSE
                     _Data.AppendOA( _Current );
                  END;
               END;

            ELSIF _Current = "'" THEN
               _Type := tokenString;
               _String := strApostrophe;
            DoApostropheString:
               LOOP
                  Feed();
                  IF _Current = "'" THEN
                     GOTO Finish;
                  ELSE
                     _Data.AppendOA( _Current );
                  END;
               END;
            
            ELSIF _Current = "`" THEN
               _Type := tokenString;
               _String := strGrave;
            DoGraveString:
               LOOP
                  Feed();
                  IF _Current= "`" THEN
                     GOTO Finish;
                  ELSE
                     _Data.AppendOA( _Current );
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
         _CurrentToken.InitKeyword( _Data );
         _CurrentLength := _Data.Length;
      | tokenNumber :
         _CurrentToken.InitNumber( _Number, _Data );
         _CurrentLength := _Data.Length;
      | tokenDelimiter :
         _CurrentToken.InitDelimiter( _Delimiter );
         _CurrentLength := 1; // TODO longer delimiters
      | tokenString :
         _CurrentToken.InitString( _Data );
         _CurrentLength := _Data.Length; // TODO unescaped/escaped
      END;
      _Type := tokenUnknown;
      _Data.Clear();
   END DoMoveNext;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Feed();
   VAR
      Result : Sync.TAsyncResult;
      timeout : INTEGER;
   BEGIN
      timeout := INTEGER( _StopTime - DateTime.UptimeMS());
      IF timeout <= 0 THEN
         THROW FeedException( Sync.arTimeout );
      END;

      // handle ahead reading
      IF _Next = 0W THEN
         Result := Reader^.ReadChar( OUT _Current, timeout, TRUE );
         IF Result NOT IN Sync.arsCompletions THEN
            THROW FeedException( Result );
         END;
         timeout := INTEGER( _StopTime - DateTime.UptimeMS());
         IF timeout <= 0 THEN
            THROW FeedException( Sync.arTimeout );
         END;

         INC( _Line );            
      ELSE
         _Current := _Next;
      END;

      // read new
      Result := Reader^.ReadChar( OUT _Next, timeout, TRUE );
      IF Result NOT IN Sync.arsCompletions THEN
         THROW FeedException( Result );
      END;

      INC( _Position );
      INC( _Column );
   END Feed;

(*--------------------------------------------------------------------------------*)

BEGIN
   _Next := 0W;
   _Current := 0W;
   _TokenNumber := 0;
   _Position := 0;
   _Line := 0;
   _Column := 0;   
   _StopTime := 0;
   _Type := tokenUnknown;
   _Delimiter := delUnknown;
   _Number := numDecimal;
   _String := strQuote;
   _CurrentLength := 0;
END CTokenizer;

(*================================================================================*)

END Tokenizer.
