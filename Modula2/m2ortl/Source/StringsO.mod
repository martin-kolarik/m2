IMPLEMENTATION MODULE StringsO;

(*================================================================================*)

FROM Storage IMPORT
   REALLOCATE, DEALLOCATE;
FROM Strings IMPORT
   CapitalizeW, LowerizeW;
FROM Debug IMPORT
   Assertion;

IMPORT
   lrconv,
   Strings;
   
(*================================================================================*)

CLASS IMPLEMENTATION CStringException;

   INTERNAL VIRTUAL PROCEDURE FormatCode( OUT S : ARRAY OF WCHAR );
   BEGIN
      CASE Kind OF
      | sexcNotNumber :
         S := "(NotNumber)";
      | sexcOutputBufferTooSmall :
         S := "(OutputBufferTooSmall)";
      | sexcCipherOutOfBase :
         S := "(CipherOutOfBase)";
      | sexcNumberTooLong :
         S := "(NumberTooLong)";
      | sexcNumberTooBig :
         S := "(NumberTooBig)";
      ELSE
         SUPER.FormatCode( OUT S );
      END;
   END FormatCode;

   PUBLIC PROCEDURE Init( NestedException : POINTER TO Exceptions.Exception; CONST Originator, Text : ARRAY OF WCHAR; Kind : TStringException ) : CStringException;
   BEGIN
      SELF.Kind := Kind;
      SUPER.Init( 0, NestedException, Originator, Text );
      RETURN SELF;
   END Init;

BEGIN
   Kind := sexcUnknown;
END CStringException;

(*--------------------------------------------------------------------------------*)

PROCEDURE StringException( NestedException : POINTER TO Exceptions.Exception; CONST Originator, Text : ARRAY OF WCHAR; Kind : TStringException ) : CStringException;
VAR
   SE : CStringException;
BEGIN
   SE.Init( NestedException, Originator, Text, Kind );
   RETURN SE;
END StringException;

(*================================================================================*)

// class for building huge strings from small pieces
CLASS IMPLEMENTATION CString;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY CString.Length GET : CARDINAL;
   BEGIN
      RETURN _Len;
   END CString.Length;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY CString.Length SET( Value : CARDINAL );
   BEGIN
      _Len := MIN2( Value, _Size );
   END CString.Length;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Size GET : CARDINAL;
   BEGIN
      RETURN _Size;
   END Size;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Size SET( Value : CARDINAL );
   BEGIN
      IF _Len > Value THEN
         _Len := Value;
      END;
      ReallocateAndFork( Value, _Len );
   END Size;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY CString.Empty GET : BOOLEAN;
   BEGIN
      RETURN _Len = 0;
   END CString.Empty;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY CString.Data GET : PWCHAR;
   BEGIN
      IF _Size = 0 THEN
         RETURN NIL;
      ELSIF _Size = _Len THEN // it occurs rarely, because there is always allocated one character more
         ReallocateAndFork( _Size + 1, _Len );
      END;
      _Data@[_Len<<1]^ := 0W;
      RETURN _Data;
   END CString.Data;
   
(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE CString.ReallocateAndFork( Characters : CARDINAL; CopyLength : CARDINAL );
   CONST
      REFCOUNTER_SIZE = SIZE( _Storage^ );
      REFCOUNTER_CHAR_SIZE = REFCOUNTER_SIZE DIV SIZE( WCHAR );
   VAR
      _ForkedStorage : ADDRESS;
   BEGIN
      ASSERT( Characters >= CopyLength );

      IF _Storage = NIL THEN // empty, simply reallocate memory
         _ForkedStorage := NIL;
      ELSIF Sync.IGet( REF _Storage^ ) = 1 THEN // RefCounter is one (= me), simply reallocate memory. There IDec is not called to allow persist source copied string without deallocation. IDec is called later.
         _ForkedStorage := NIL;
      ELSE // RefCounter will be decremented, force allocate self as new
         _ForkedStorage := _Storage;
         _Storage := NIL; // fork, force new allocation
         _Size := 0; // set correct size here, if Characters = 0 procedure finishes
      END;

      IF Characters > 0 THEN // only if requested size is not zero allocate something
         INC( Characters, 1 + REFCOUNTER_CHAR_SIZE ); // reserve space for 0W (zero termination) and RefCounter
         IF Characters > _Size THEN
            _Size := ( Characters + 10H ) AND 0FFFFFFF0H; // a roundup to 16 characters
            REALLOCATE( REF _Storage, _Size<<1 );
            _Data := PWCHAR( _Storage@[ REFCOUNTER_SIZE ] );
            _Storage^ := 1; // initialize RefCount -- done on new own memory, no need to lock (all Fork calls must be done either on local (fork) string or synchronized (source) string

            // do a copy of current string (forked string is identical, do not copy if no fork is done)
            IF ( _ForkedStorage <> NIL ) AND ( CopyLength > 0 ) THEN
               Strings.MoveW( _ForkedStorage@[ REFCOUNTER_SIZE ], _Data, CopyLength );
            END;
         END;
      END;

      // solve delayed IDec
      IF _ForkedStorage <> NIL THEN
         Sync.IDec( REF _ForkedStorage^ );
      END;
   END CString.ReallocateAndFork;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE CString.Deallocate();
   BEGIN
      IF _Storage = NIL THEN
         // fall down
      ELSIF Sync.IDec( REF _Storage^ ) = 0 THEN // if RefCounter was one (= me), dispose
         DISPOSE( _Storage );
      ELSE
         _Storage := NIL;
      END;
      _Data := NIL;
      _Size := 0;
      _Len := 0;
   END CString.Deallocate;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL INDEX CString GET( Index : CARDINAL ) : WCHAR;
   BEGIN
      IF Index < _Len THEN
         RETURN _Data@[Index<<1]^;
      ELSE
         RETURN 0W;
      END;
   END CString;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL INDEX CString SET( Index : CARDINAL; Value : WCHAR );
   BEGIN
      ReallocateAndFork( MAX2( _Len, Index+1 ), _Len ); // copy on write
      IF Index >= _Len THEN
         _Len := Index + 1;
      END;
      _Data@[Index<<1]^ := Value;
   END CString;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL OPERATOR CString.:=( CONST S : CString );
   BEGIN
      Assign( S );
   END CString.:=;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL OPERATOR CString.=( CONST S : IString ) : BOOLEAN;
   BEGIN
      RETURN Equals( S );
   END CString.=;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL OPERATOR CString.<>( CONST S : IString ) : BOOLEAN;
   BEGIN
      RETURN NOT Equals( S );
   END CString.<>;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL OPERATOR CString.+( CONST S : CString ) : CString;
   VAR
      CS : CString;
   BEGIN
      CS.Size := _Size + S.Size;
      CS.Copy( SELF );
      CS.Append( S );
      RETURN CS;
   END CString.+;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CString.Clear();
   BEGIN
      _Len := 0;
   END CString.Clear;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CString.Dispose();
   BEGIN
      Deallocate();
   END CString.Dispose;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CString.Equals( CONST S : IString ) : BOOLEAN;
   VAR
      l : CARDINAL;
   BEGIN
      l := S.Length;
      IF _Len <> l THEN
         RETURN FALSE;
      ELSIF l = 0 THEN
         RETURN TRUE;
      ELSE
         RETURN EQUALS( OA( l-1, _Data ), OA( l-1, S.Data ));
      END;
   END CString.Equals;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CString.EqualsOA( CONST S : ARRAY OF WCHAR ) : BOOLEAN;
   BEGIN
      IF _Len = 0 THEN
         RETURN S[0] = WCHAR( 0 );
      ELSE
         RETURN EQUALS( S, OA( _Len-1, _Data ));
      END;
   END CString.EqualsOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CString.EqualsIgnoreCase( CONST S : IString ) : BOOLEAN;
   VAR
      l : CARDINAL;
   BEGIN
      l := S.Length;
      IF _Len <> l THEN
         RETURN FALSE;
      ELSIF l = 0 THEN
         RETURN TRUE;
      ELSE
         RETURN Languages.CompareStringMLW( Languages.GetDefaultLanguage( Languages.dlUser ), FALSE, _Len, _Data, l, S.Data ) = 0;
      END;
   END CString.EqualsIgnoreCase;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CString.EqualsIgnoreCaseOA( CONST S : ARRAY OF WCHAR ) : BOOLEAN;
   VAR
      l : CARDINAL;
   BEGIN
      l := LENGTH( S );
      IF _Len <> l THEN
         RETURN FALSE;
      ELSIF l = 0 THEN
         RETURN TRUE;
      ELSE
         RETURN Languages.CompareStringMLW( Languages.GetDefaultLanguage( Languages.dlUser ), FALSE, _Len, _Data, l, ADR( S )) = 0;
      END;
   END CString.EqualsIgnoreCaseOA;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CString.Compare( CONST S : IString ) : TRISTATE;
   BEGIN
      RETURN Strings.CompareW( OA( _Len-1, _Data ), OA( S.Length-1, S.Data ));
   END CString.Compare;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CString.CompareLanguage( Language : Languages.TLanguage; CaseSensitive : BOOLEAN; CONST S : IString ) : TRISTATE;
   BEGIN
      RETURN Languages.CompareStringMLW( Language, CaseSensitive, _Len, _Data, S.Length, S.Data );
   END CString.CompareLanguage;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CString.Assign( CONST S : IString );
   TYPE
      TPCString = POINTER TO CString;
   VAR
      ps : TPCString;
   BEGIN
      IF S IS CString THEN
         ps := TPCString( ADR( S ));
      ELSE // I cannot assume anything about S, use generic method
         Copy( S );
         RETURN;
      END;

      IF _Storage = NIL THEN // I am empty
         // fall down
      ELSIF Sync.IDec( REF _Storage^ ) = 0 THEN // if RefCounter was one (= me), dispose
         DISPOSE( _Storage );
      ELSE
         _Storage := NIL;
      END;

      _Len := ps^._Len;
      IF _Len = 0 THEN
         _Data := NIL;
         _Size := 0;
      ELSE
         _Data := ps^._Data;
         _Storage := ps^._Storage;
         _Size := ps^._Size;
         Sync.IInc( REF _Storage^ );
      END;
   END CString.Assign;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CString.Copy( CONST S : IString );
   BEGIN
      _Len := S.Length;
      ReallocateAndFork( _Len, 0 );
      IF _Len > 0 THEN
         Strings.MoveW( S.Data, _Data, _Len );
      END;
   END CString.Copy;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CString.Append( CONST S : IString );
   VAR
      l : CARDINAL;
   BEGIN
      l := S.Length;
      IF l = 0 THEN
         RETURN;
      END;
      ReallocateAndFork( _Len+l, _Len );
      Strings.MoveW( S.Data, _Data@[_Len<<1], l );
      INC( _Len, l );
   END CString.Append;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CString.AppendOA( CONST S : ARRAY OF WCHAR );
   VAR
      l : CARDINAL;
   BEGIN
      l := LENGTH( S );
      IF l = 0 THEN
         RETURN;
      END;
      ReallocateAndFork( _Len+l, _Len );
      Strings.MoveW( ADR( S ), _Data@[_Len<<1], l );
      INC( _Len, l );
   END CString.AppendOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CString.Prepend( CONST S : IString );
   VAR
      l : CARDINAL;
   BEGIN
      l := S.Length;
      IF l = 0 THEN
         RETURN;
      END;
      ReallocateAndFork( _Len+l, _Len );
      Strings.MoveW( _Data, _Data@[l<<1], _Len );
      Strings.MoveW( S.Data, _Data, l );
      INC( _Len, l );
   END CString.Prepend;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CString.PrependOA( CONST S : ARRAY OF WCHAR );
   VAR
      l : CARDINAL;
   BEGIN
      l := LENGTH( S );
      IF l = 0 THEN
         RETURN;
      END;
      ReallocateAndFork( _Len+l, _Len );
      Strings.MoveW( _Data, _Data@[l<<1], _Len );
      Strings.MoveW( ADR( S ), _Data, l );
      INC( _Len, l );
   END CString.PrependOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CString.Insert( To : CARDINAL; CONST S : IString );
   VAR
      l : CARDINAL;
   BEGIN
      l := S.Length;
      IF l = 0 THEN
         RETURN;
      END;
      ReallocateAndFork( _Len+l, _Len );
      Strings.MoveW( _Data@[To<<1], _Data@[(To+l)<<1], _Len-To );
      Strings.MoveW( S.Data, _Data@[To<<1], l );
      INC( _Len, l );
   END CString.Insert;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CString.InsertOA( To : CARDINAL; CONST S : ARRAY OF WCHAR );
   VAR
      l : CARDINAL;
   BEGIN
      l := LENGTH( S );
      IF l = 0 THEN
         RETURN;
      END;
      ReallocateAndFork( _Len+l, _Len );
      Strings.MoveW( _Data@[To<<1], _Data@[(To+l)<<1], _Len-To );
      Strings.MoveW( ADR( S ), _Data@[To<<1], l );
      INC( _Len, l );
   END CString.InsertOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CString.Remove( From, Count : CARDINAL );
   VAR
      rl : CARDINAL;
   BEGIN
      IF Count = 0 THEN
         RETURN;
      ELSIF From >= _Len THEN
         RETURN;
      ELSIF Count > MAX( INTEGER ) THEN
         Count := _Len;
      END;
      ReallocateAndFork( _Len, _Len ); // copy on write
      rl := From+Count;
      IF rl >= _Len THEN
         _Len := From;
      ELSE
         Strings.MoveW( _Data@[rl<<1], _Data@[From<<1], _Len-rl );
         DEC( _Len, Count );
      END;
   END CString.Remove;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CString.Replace( CONST Old, New : IString );
   VAR
      i, nl, ol : CARDINAL;
   BEGIN
      IF ( Old[0] = 0W ) OR ( _Len = 0 ) THEN
         RETURN;
      END;
      ol := Old.Length;
      nl := New.Length;
      IF ol > nl THEN
         ReallocateAndFork( _Len + ol - nl, _Len ); // copy on write, add speculatively space for single replacement
      ELSE
         ReallocateAndFork( _Len + nl - ol, _Len ); // copy on write, add speculatively space for single replacement
      END;
      i := 0;
      LOOP
         i := Strings.IndexOfMW( _Len, _Data, ol, Old.Data, i );
         IF i = -1 THEN
            RETURN;
         END;
         IF ol > nl THEN
            Strings.MoveW( New.Data, _Data@[i<<1], nl );
            Remove( i+nl, ol-nl );
         ELSIF ol < nl THEN
            Strings.MoveW( New.Data, _Data@[i<<1], ol );
            InsertOA( i+ol, OA( nl-ol-1, New.Data@[ol<<1] ));
         ELSE
            Strings.MoveW( New.Data, _Data@[i<<1], nl );
         END;
         INC( i, nl );
      END; // LOOP
   END CString.Replace;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CString.ReplaceOA( CONST Old, New : ARRAY OF WCHAR );
   VAR
      i, nl, ol : CARDINAL;
   BEGIN
      IF ( Old[0] = 0W ) OR ( _Len = 0 ) THEN
         RETURN;
      END;
      ol := LENGTH( Old );
      nl := LENGTH( New );
      IF ol > nl THEN
         ReallocateAndFork( _Len + ol - nl, _Len ); // copy on write, add speculatively space for single replacement
      ELSE
         ReallocateAndFork( _Len + nl - ol, _Len ); // copy on write, add speculatively space for single replacement
      END;
      i := 0;
      LOOP
         i := Strings.IndexOfMW( _Len, _Data, ol, ADR( Old ), i );
         IF i = -1 THEN
            RETURN;
         END;
         IF ol > nl THEN
            Strings.MoveW( ADR( New ), _Data@[i<<1], nl );
            Remove( i+nl, ol-nl );
         ELSIF ol < nl THEN
            Strings.MoveW( ADR( New ), _Data@[i<<1], ol );
            InsertOA( i+ol, OA( nl-ol-1, ADR( New[ol] )));
         ELSE
            Strings.MoveW( ADR( New ), _Data@[i<<1], nl );
         END;
         INC( i, nl );
      END; // LOOP
   END CString.ReplaceOA;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CString.Trim();
   BEGIN
      IF _Len > 0 THEN
         ReallocateAndFork( _Len, _Len ); // copy on write 
         Strings.TrimW( REF OA( _Len-1, _Data ));
         _Len := LENGTH( OA( _Len-1, _Data ));
      END;
   END Trim;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE IndexOf( CONST S : IString; FromIndex : CARDINAL ) : CARDINAL;
   BEGIN
      RETURN Strings.IndexOfMW( _Len, _Data, S.Length, S.Data, FromIndex );
   END CString.IndexOf;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE IndexOfOA( CONST S : ARRAY OF WCHAR; FromIndex : CARDINAL ) : CARDINAL;
   BEGIN
      RETURN Strings.IndexOfMW( _Len, _Data, LENGTH( S ), ADR( S ), FromIndex );
   END CString.IndexOfOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE IndexOfAny( CONST Delimiters : SET OF WCHAR; FromIndex : CARDINAL ) : CARDINAL;
   BEGIN
      RETURN Strings.IndexOfAnyW( OA( _Len-1, _Data ), Delimiters, FromIndex );
   END IndexOfAny;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE IndexOfAnyS( CONST Delimiters : SET OF WCHARS; FromIndex : CARDINAL ) : CARDINAL;
   BEGIN
      RETURN Strings.IndexOfAnySW( OA( _Len-1, _Data ), Strings.WCHARS( Delimiters ), FromIndex );
   END IndexOfAnyS;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE LastIndexOf( CONST S : IString; IndexFromRight : CARDINAL ) : CARDINAL;
   BEGIN
      RETURN Strings.LastIndexOfMW( _Len, _Data, S.Length, PWCHAR( S.Data ), IndexFromRight );
   END LastIndexOf;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE LastIndexOfOA( CONST S : ARRAY OF WCHAR; IndexFromRight : CARDINAL ) : CARDINAL;
   BEGIN
      RETURN Strings.LastIndexOfMW( _Len, _Data, LENGTH( S ), ADR( S ), IndexFromRight );
   END LastIndexOfOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE LastIndexOfAny( CONST Delimiters : SET OF WCHAR; IndexFromRight : CARDINAL ) : CARDINAL;
   BEGIN
      RETURN Strings.LastIndexOfAnyW( OA( _Len-1, _Data ), Delimiters, IndexFromRight );
   END LastIndexOfAny;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE LastIndexOfAnyS( CONST Delimiters : SET OF WCHARS; IndexFromRight : CARDINAL ) : CARDINAL;
   BEGIN
      RETURN Strings.LastIndexOfAnySW( OA( _Len-1, _Data ), Strings.WCHARS( Delimiters ), IndexFromRight );
   END LastIndexOfAnyS;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Contains( CONST S : IString ) : BOOLEAN;
   BEGIN
      RETURN Strings.IndexOfMW( _Len, _Data, S.Length, PWCHAR( S.Data ), 0 ) <> -1;
   END Contains;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE ContainsOA( CONST S : ARRAY OF WCHAR ) : BOOLEAN;
   BEGIN
      RETURN Strings.IndexOfMW( _Len, _Data, LENGTH( S ), ADR( S ), 0 ) <> -1;
   END ContainsOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE StartsWith( CONST S : IString ) : BOOLEAN;
   BEGIN
      IF _Len = 0 THEN
         RETURN S[0] = 0W;
      ELSIF S.Length = 0 THEN
         RETURN FALSE;
      ELSE
         RETURN Strings.StartsWithW( OA( _Len-1, _Data ), OA( S.Length-1, S.Data ));
      END;
   END StartsWith;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE StartsWithOA( CONST S : ARRAY OF WCHAR ) : BOOLEAN;
   BEGIN
      IF _Len = 0 THEN
         RETURN S[0] = 0W;
      ELSE
         RETURN Strings.StartsWithW( OA( _Len-1, _Data ), S );
      END;
   END StartsWithOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE EndsWith( CONST S : IString ) : BOOLEAN;
   BEGIN
      IF _Len = 0 THEN
         RETURN S[0] = 0W;
      ELSIF S.Length = 0 THEN
         RETURN FALSE;
      ELSE
         RETURN Strings.StartsWithW( OA( _Len-1, _Data ), OA( S.Length-1, S.Data ));
      END;
   END EndsWith;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE EndsWithOA( CONST S : ARRAY OF WCHAR ) : BOOLEAN;
   BEGIN
      IF _Len = 0 THEN
         RETURN S[0] = 0W;
      ELSE
         RETURN Strings.EndsWithW( OA( _Len-1, _Data ), S );
      END;
   END EndsWithOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Match( CONST Pattern : IString; CaseSensitive : BOOLEAN ) : BOOLEAN;
   BEGIN
      RETURN Strings.MatchW( OA( _Len-1, _Data ), OA( Pattern.Length-1, Pattern.Data ), CaseSensitive );
   END Match;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE MatchOA( CONST Pattern : ARRAY OF WCHAR; CaseSensitive : BOOLEAN ) : BOOLEAN;
   BEGIN
      RETURN Strings.MatchW( OA( _Len-1, _Data ), Pattern, CaseSensitive );
   END MatchOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Substring( From, Count : CARDINAL; OUT S : IString );
   BEGIN
      IF Count = 0 THEN
         S.Clear();
         RETURN;
      ELSIF From >= _Len THEN
         S.Clear();
         RETURN;
      ELSIF Count > MAX( INTEGER ) THEN
         Count := _Len; 
      END;
      Count := MIN2( _Len-From, Count );
      IF Count = 0 THEN
         S.Clear();
      ELSE
         S.FromOA( OA( Count-1, _Data@[From<<1] ));
      END;
   END CString.Substring;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE SubstringOA( From, Count: CARDINAL; OUT S : ARRAY OF WCHAR );
   VAR
      l : CARDINAL := 0;
   BEGIN
      IF ( Count = 0 ) OR ( From > _Len ) THEN
         S[0] := WCHAR( 0 );
         RETURN;
      END;
      IF Count > MAX( INTEGER ) THEN
         Count := _Len;
      END;
      l := MIN2( HIGH(S)+1, MIN2( _Len-From, Count ));
      Strings.MoveW( _Data@[From<<1], ADR( S ), l );
      IF l <= HIGH(S) THEN
         S[l] := WCHAR( 0 );
      END;
   END CString.SubstringOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CString.Item( CONST Delimiters : SET OF WCHAR; FromIndex, ItemIndex : CARDINAL; SkipEmpty : BOOLEAN; OUT S : IString ) : CARDINAL;
   VAR
      i, l : CARDINAL;
   BEGIN
      S.Length := 0; // avoid copying of S's data during fork in Size
      S.Size := _Len; // preallocate space
      i := Strings.ItemMW( _Len, _Data, Delimiters, FromIndex, ItemIndex, SkipEmpty, OUT OA( _Len-1, PWCHAR( S.Data )), ADR( l ));
      S.Length := l; // adjust real size
      RETURN i;
   END CString.Item;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CString.ItemS( CONST Delimiters : SET OF WCHARS; FromIndex, ItemIndex : CARDINAL; SkipEmpty : BOOLEAN; OUT S : IString ) : CARDINAL;
   VAR
      i, l : CARDINAL;
   BEGIN
      S.Length := 0; // avoid copying of S's data during fork in Size
      S.Size := _Len; // preallocate space
      i := Strings.ItemSMW( _Len, _Data, Strings.WCHARS( Delimiters ), FromIndex, ItemIndex, SkipEmpty, OUT OA( _Len-1, PWCHAR( S.Data )), ADR( l ));
      S.Length := l; // adjust real size
      RETURN i;
   END CString.ItemS;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CString.ItemOA( CONST Delimiters : SET OF WCHAR; FromIndex, ItemIndex : CARDINAL; SkipEmpty : BOOLEAN; OUT S : ARRAY OF WCHAR ) : CARDINAL;
   BEGIN
      RETURN Strings.ItemMW( _Len, _Data, Delimiters, FromIndex, ItemIndex, SkipEmpty, OUT S, NIL );
   END CString.ItemOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CString.ItemSOA( CONST Delimiters : SET OF WCHARS; FromIndex, ItemIndex : CARDINAL; SkipEmpty : BOOLEAN; OUT S : ARRAY OF WCHAR ) : CARDINAL;
   BEGIN
      RETURN Strings.ItemSMW( _Len, _Data, Strings.WCHARS( Delimiters ), FromIndex, ItemIndex, SkipEmpty, OUT S, NIL );
   END CString.ItemSOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CString.Split( CONST Delimiters : SET OF WCHAR; FromIndex : CARDINAL; SkipEmpty : BOOLEAN; OUT Pieces : CARDINAL; OUT S : ARRAY OF CString ) : CARDINAL;
   VAR
      i, j, l : CARDINAL;
   BEGIN
      Pieces := 0;
      i := FromIndex;
      IF SkipEmpty THEN
         WHILE ( i < _Len ) AND ( _Data@[i<<1]^ IN Delimiters ) DO
            INC( i );
         END;
      END;
      LOOP
         IF i >= _Len THEN
            RETURN -1;
         ELSE
            j := i;
         END;
         WHILE ( i < _Len ) AND NOT( _Data@[i<<1]^ IN Delimiters ) DO
            INC( i );
         END;
         l := i-j;
         IF l = 0 THEN
            S[Pieces].Clear();
         ELSE
            S[Pieces].FromOA( OA( l-1, _Data@[j<<1] ));
         END;
         INC( Pieces );
         IF SkipEmpty THEN
            WHILE ( i < _Len ) AND ( _Data@[i<<1]^ IN Delimiters ) DO
               INC( i );
            END;
         ELSE
            INC( i );
         END;
         IF Pieces <= HIGH( S ) THEN
            // continue
         ELSE
            RETURN i;
         END;
      END;
   END CString.Split;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CString.SplitS( CONST Delimiters : SET OF WCHARS; FromIndex : CARDINAL; SkipEmpty : BOOLEAN; OUT Pieces : CARDINAL; OUT S : ARRAY OF CString ) : CARDINAL;
   VAR
      i, j, l : CARDINAL;
   BEGIN
      Pieces := 0;
      i := FromIndex;
      IF SkipEmpty THEN
         WHILE ( i < _Len ) AND ( _Data@[i<<1]^ IN Delimiters ) DO
            INC( i );
         END;
      END;
      LOOP
         IF i >= _Len THEN
            RETURN -1;
         ELSE
            j := i;
         END;
         WHILE ( i < _Len ) AND NOT( _Data@[i<<1]^ IN Delimiters ) DO
            INC( i );
         END;
         l := i-j;
         IF l = 0 THEN
            S[Pieces].Clear();
         ELSE
            S[Pieces].FromOA( OA( l-1, _Data@[j<<1] ));
         END;
         INC( Pieces );
         IF SkipEmpty THEN
            WHILE ( i < _Len ) AND ( _Data@[i<<1]^ IN Delimiters ) DO
               INC( i );
            END;
         ELSE
            INC( i );
         END;
         IF Pieces <= HIGH( S ) THEN
            // continue
         ELSE
            RETURN i;
         END;
      END;
   END CString.SplitS;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Lowerize();
   BEGIN
      IF _Len = 0 THEN
         RETURN;
      END;
      ReallocateAndFork( _Len, _Len ); // copy on write 
      LOW( OA( _Len-1, _Data ));
   END Lowerize;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Capitalize();
   BEGIN
      IF _Len = 0 THEN
         RETURN;
      END;
      ReallocateAndFork( _Len, _Len ); // copy on write 
      CAP( OA( _Len-1, _Data ));
   END Capitalize;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CString.ToOA( OUT S : ARRAY OF WCHAR );
   BEGIN
      IF _Len = 0 THEN
         S[0] := WCHAR( 0 );
      ELSE
         ASSIGN( S, OA( _Len-1, _Data ));
      END;
   END CString.ToOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CString.ToOAA( CodePage : CARDINAL; OUT S : ARRAY OF CHAR; OUT Filled : CARDINAL );
   BEGIN
      IF _Len = 0 THEN
         Filled := 0;
         S[0] := CHAR( 0 );
      ELSIF NOT Strings.ToMA( _Len, _Data, CodePage, HIGH( S ) + 1, ADR( S ), OUT Filled ) THEN // something failed
         Filled := 0;
         S[0] := CHAR( 0 );
      END;
   END CString.ToOAA;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CString.ToUTF8( OUT S : ARRAY OF CHAR; OUT Filled : CARDINAL );
   BEGIN
      ToOAA( Languages.cp_UTF8, OUT S, OUT Filled );
   END CString.ToUTF8;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CString.ToINT32( Base : CARDINAL; OUT I : INT32 ) : BOOLEAN;
   VAR
      LC : INT64;
   BEGIN
      IF Strings.ToCARD64MW( _Len, _Data, Base, OUT LC ) <> Strings.tcrSuccess THEN
         RETURN FALSE;
      ELSIF LC > MAX( CARD32 ) THEN
         RETURN FALSE;
      END;
      I := INT32( LC );
      RETURN TRUE;
   END CString.ToINT32;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CString.ToCARD32( Base : CARDINAL; OUT C : CARD32 ) : BOOLEAN;
   VAR
      LC : CARD64;
   BEGIN
      IF Strings.ToCARD64MW( _Len, _Data, Base, OUT LC ) <> Strings.tcrSuccess THEN
         RETURN FALSE;
      ELSIF LC > MAX( CARD32 ) THEN
         RETURN FALSE;
      END;
      C := CARD32( LC );
      RETURN TRUE;
   END CString.ToCARD32;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CString.ToINT64( Base : CARDINAL; OUT I : INT64 ) : BOOLEAN;
   VAR
      LC : INT64;
   BEGIN
      IF Strings.ToCARD64MW( _Len, _Data, Base, OUT LC ) <> Strings.tcrSuccess THEN
         RETURN FALSE;
      ELSIF LC > MAX( INT64 ) THEN
         RETURN FALSE;
      END;
      I := INT64( LC );
      RETURN TRUE;
   END CString.ToINT64;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CString.ToCARD64( Base : CARDINAL; OUT C : CARD64 ) : BOOLEAN;
   VAR
      LC : CARD64;
   BEGIN
      IF Strings.ToCARD64MW( _Len, _Data, Base, OUT LC ) <> Strings.tcrSuccess THEN
         RETURN FALSE;
      END;
      C := LC;
      RETURN TRUE;
   END CString.ToCARD64;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CString.ToLONGREAL( OUT R : LONGREAL ) : BOOLEAN;
   BEGIN
      RETURN Strings.ToLONGREALW( OA( _Len-1, _Data ), OUT R );
   END CString.ToLONGREAL;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CString.FromOA( CONST S : ARRAY OF WCHAR );
   BEGIN
      _Len := LENGTH( S );
      ReallocateAndFork( _Len, 0 );
      Strings.MoveW( ADR( S ), _Data, _Len );
   END CString.FromOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE FromOAA( CodePage : CARDINAL; CONST S : ARRAY OF CHAR );
   BEGIN
      _Len := LENGTH( S );
      ReallocateAndFork( _Len, 0 );
      IF NOT Strings.ToMW( _Len, ADR( S ), CodePage, _Size, _Data, OUT _Len ) THEN // something failed
         Clear();
      END;
   END CString.FromOAA;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE FromUTF8( CONST S : ARRAY OF CHAR );
   BEGIN
      FromOAA( Languages.cp_UTF8, S );
   END CString.FromUTF8;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE FromINT32( I : INT32; Base : CARDINAL );
   BEGIN
      ReallocateAndFork( 10, 0 );
      Strings.FromINT32W( I, Base, OUT OA( 9, _Data ));
      _Len := LENGTH( OA( 9, _Data ));
   END CString.FromINT32;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE FromCARD32( C : CARD32; Base : CARDINAL );
   BEGIN
      ReallocateAndFork( 10, 0 );
      Strings.FromCARD32W( C, Base, OUT OA( 9, _Data ));
      _Len := LENGTH( OA( 9, _Data ));
   END CString.FromCARD32;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE FromINT64( I : INT64; Base : CARDINAL );
   BEGIN
      ReallocateAndFork( 20, 0 );
      Strings.FromINT64W( I, Base, OUT OA( 19, _Data ));
      _Len := LENGTH( OA( 19, _Data ));
   END CString.FromINT64;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE FromCARD64( C : CARD64; Base : CARDINAL );
   BEGIN
      ReallocateAndFork( 20, 0 );
      Strings.FromCARD64W( C, Base, OUT OA( 19, _Data ));
      _Len := LENGTH( OA( 19, _Data ));
   END CString.FromCARD64;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE FromLONGREAL( R : LONGREAL; ExpFlag : BOOLEAN );
   VAR
      S : ARRAY [0..319] OF WCHAR;
   BEGIN
      ReallocateAndFork( _Len, 0 ); // copy on write 
      IF lrconv.LONGREALToStrW( R, -1, -1, ExpFlag, 0W, OUT S ) THEN
         FromOA( S );
      ELSE
         FromOA( L"0.0" );
      END;
   END CString.FromLONGREAL;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE FromLONGREALExt( R : LONGREAL; ValidCiphers, FractionPlaces : CARDINAL; ExpFlag : BOOLEAN; PointChar : WCHAR );
   VAR
      S : ARRAY [0..319] OF WCHAR;
   BEGIN
      ReallocateAndFork( _Len, 0 ); // copy on write 
      IF lrconv.LONGREALToStrW( R, ValidCiphers, FractionPlaces, ExpFlag, PointChar, OUT S ) THEN
         FromOA( S );
      ELSE
         FromOA( L"0.0" );
      END;
   END CString.FromLONGREALExt;

(*--------------------------------------------------------------------------------*)

   INITIALLY CString;
   BEGIN
      _Size := 0;
      _Len := 0;
      _Storage := NIL;
      _Data := NIL;
   END CString;

(*--------------------------------------------------------------------------------*)

   FINALLY CString;
   BEGIN
      Deallocate();
   END CString;

(*--------------------------------------------------------------------------------*)

END CString;

(*--------------------------------------------------------------------------------*)

PROCEDURE FromOA( String : ARRAY OF WCHAR ) : CString;
VAR
   string : CString;
BEGIN
   string.FromOA( String );
   RETURN string;
END FromOA;

(*--------------------------------------------------------------------------------*)

VAR
   _Empty : CString;

PROCEDURE Empty() : CString;
BEGIN
   RETURN _Empty;
END Empty;

(*================================================================================*)

END StringsO.
