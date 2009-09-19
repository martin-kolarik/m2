IMPLEMENTATION MODULE StringsO;

FROM Storage IMPORT
	ALLOCATE, REALLOCATE, DEALLOCATE, Fill;
	
IMPORT
	windows,
	winnls;
	
IMPORT
   lrconv,
	Strings;
	
FROM Strings IMPORT
   CapitalizeW, LowerizeW;

CLASS IMPLEMENTATION CStringException;

   PUBLIC PROCEDURE Init( NestedException : POINTER TO Exceptions.Exception; CONST Originator, Text : ARRAY OF WCHAR; Kind : TStringException ) : CStringException;
   BEGIN
      SELF.Kind := Kind;
      SUPER.Init( NestedException, Originator, Text );
      RETURN SELF;
   END Init;

   INTERNAL VIRTUAL PROCEDURE Name( OUT S : ARRAY OF WCHAR );
   BEGIN
      ASSIGN( S, EMITW( %class ));
   END Name;

BEGIN
   Kind := sexcUnknown;
END CStringException;

PROCEDURE StringException( NestedException : POINTER TO Exceptions.Exception; CONST Originator, Text : ARRAY OF WCHAR; Kind : TStringException ) : CStringException;
VAR
	SE : CStringException;
BEGIN
	SE.Init( NestedException, Originator, Text, Kind );
	RETURN SE;
END StringException;

// class for building huge strings from small pieces
CLASS IMPLEMENTATION CString;

	PUBLIC VIRTUAL PROPERTY CString.Length GET : CARDINAL;
	BEGIN
		RETURN _Len;
	END CString.Length;
	
	PUBLIC VIRTUAL PROPERTY CString.Length SET( Value : CARDINAL );
	BEGIN
		_Len := MIN2( Value, _Size );
	END CString.Length;
	
	PUBLIC VIRTUAL PROPERTY Size GET : CARDINAL;
	BEGIN
		RETURN _Size;
	END Size;

	PUBLIC VIRTUAL PROPERTY Size SET( Value : CARDINAL );
	BEGIN
		Reallocate( Value );
	END Size;

	PUBLIC VIRTUAL PROPERTY CString.Empty GET : BOOLEAN;
	BEGIN
		RETURN _Len = 0;
	END CString.Empty;
	
	PUBLIC VIRTUAL PROPERTY CString.rawData GET : PWCHAR;
	BEGIN
      RETURN _Data;
	END CString.rawData;
	
	PUBLIC VIRTUAL PROPERTY CString.szData GET : PWCHAR;
	BEGIN
		IF _Size = _Len THEN
			Reallocate( _Size + 1 );
		END;
		_Data@[_Len<<1]^ := WCHAR( 0 );
		RETURN _Data;
	END CString.szData;
	
	INTERNAL VIRTUAL PROCEDURE CString.Reallocate( Characters : CARDINAL );
	BEGIN
		IF Characters > _Size THEN
			_Size := Characters AND 0FFFFFFF0H + 10H;
			REALLOCATE( _Data, _Size<<1 );
		END;
	END CString.Reallocate;

	INTERNAL VIRTUAL PROCEDURE CString.Deallocate();
	BEGIN
		DISPOSE( _Data );
	END CString.Deallocate;
	
	PUBLIC VIRTUAL INDEX CString GET( Index : CARDINAL ) : WCHAR;
	BEGIN
		IF Index < _Len THEN
			RETURN _Data@[Index<<1]^;
		ELSE
			RETURN WCHAR( 0 );
		END;
	END CString;
	
	PUBLIC VIRTUAL INDEX CString SET( Index : CARDINAL; Value : WCHAR );
	BEGIN
		IF Index >= _Size THEN
			Reallocate( Index + 1 );
		END;
		IF Index >= _Len THEN
			_Len := Index + 1;
		END;
		_Data@[Index<<1]^ := Value;
	END CString;
	
	PUBLIC VIRTUAL OPERATOR CString.:=( CONST S : CString );
	BEGIN
		Assign( S );
	END CString.:=;
	
	PUBLIC VIRTUAL OPERATOR CString.=( CONST S : IString ) : BOOLEAN;
	BEGIN
		RETURN Equals( S );
	END CString.=;

	PUBLIC VIRTUAL OPERATOR CString.<>( CONST S : IString ) : BOOLEAN;
	BEGIN
		RETURN NOT Equals( S );
	END CString.<>;

	PUBLIC VIRTUAL OPERATOR CString.+( CONST S : CString ) : CString;
	VAR
		CS : POINTER TO CString;
	BEGIN
		NEW( CS );
		CS^.Assign( SELF );
		CS^.Append( S );
		RETURN CS^;
	END CString.+;
	
	PUBLIC VIRTUAL PROCEDURE CString.Clear();
	BEGIN
		_Len := 0;
	END CString.Clear;

	PUBLIC VIRTUAL PROCEDURE CString.Dispose();
	BEGIN
		Deallocate();
	END CString.Dispose;

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
			RETURN EQUALS( OA( l-1, _Data ), OA( l-1, S.rawData ));
		END;
	END CString.Equals;

	PUBLIC VIRTUAL PROCEDURE CString.EqualsOA( CONST S : ARRAY OF WCHAR ) : BOOLEAN;
	BEGIN
		IF _Len = 0 THEN
			RETURN S[0] = WCHAR( 0 );
		ELSE
			RETURN EQUALS( S, OA( _Len-1, _Data ));
		END;
	END CString.EqualsOA;

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
			RETURN winnls.CompareStringW(
				windows.LOCALE_USER_DEFAULT,
				winnls.NORM_IGNORECASE,
				S.rawData, l, _Data, _Len
			) = winnls.CSTR_EQUAL;
		END;
	END CString.EqualsIgnoreCase;

   PUBLIC VIRTUAL PROCEDURE EqualsIgnoreCaseOA( CONST S : ARRAY OF WCHAR ) : BOOLEAN;
	VAR
		l : CARDINAL;
	BEGIN
		l := LENGTH( S );
		IF _Len <> l THEN
			RETURN FALSE;
		ELSIF l = 0 THEN
			RETURN TRUE;
		ELSE
			RETURN winnls.CompareStringW(
				windows.LOCALE_USER_DEFAULT,
				winnls.NORM_IGNORECASE,
				ADR( S ), l, _Data, _Len
			) = winnls.CSTR_EQUAL;
		END;
   END EqualsIgnoreCaseOA;
   
	PUBLIC VIRTUAL PROCEDURE CString.Compare( CONST S : IString ) : TRISTATE;
	VAR
		i, l, k : CARDINAL;
		rd : PWCHAR;
	BEGIN
		l := S.Length;
		IF l = 0 THEN
			IF _Len = 0 THEN
				RETURN 0;
			ELSE
				RETURN 1;
			END;
		ELSIF _Len = 0 THEN
			RETURN -1;
		END;

		rd := PWCHAR( S.rawData );
		i := 0;
		k := MIN2( l, _Len );
		WHILE i < k DO
			IF _Data@[i<<1]^ > rd@[i<<1]^ THEN
				RETURN 1;
			ELSIF _Data@[i<<1]^ < rd@[i<<1]^ THEN
				RETURN -1;
			ELSE
				INC( i );
			END;
		END; // WHILE
		
		IF _Len > l THEN
			RETURN 1;
		ELSIF _Len < l THEN
			RETURN -1;
		ELSE
			RETURN 0;
		END;
	END CString.Compare;

	PUBLIC VIRTUAL PROCEDURE CString.Assign( CONST S : IString );
	BEGIN
		_Len := S.Length;
		IF _Len = 0 THEN
			RETURN;
		ELSIF _Size < _Len THEN
			Reallocate( _Len + 1 );
		END;
		Strings.MoveW( S.rawData, _Data, _Len );
	END CString.Assign;

	PUBLIC VIRTUAL PROCEDURE CString.Append( CONST S : IString );
	VAR
		l : CARDINAL;
	BEGIN
		l := S.Length;
		IF l = 0 THEN
			RETURN;
		END;
		INC( _Len, l );
		IF _Size < _Len THEN
			Reallocate( _Len + 1 );
		END;
		Strings.MoveW( S.rawData, _Data@[(_Len-l)<<1], l );
	END CString.Append;

	PUBLIC VIRTUAL PROCEDURE CString.AppendOA( CONST S : ARRAY OF WCHAR );
	VAR
		l : CARDINAL;
	BEGIN
		l := LENGTH( S );
		IF l = 0 THEN
			RETURN;
		END;
		INC( _Len, l );
		IF _Size < _Len THEN
			Reallocate( _Len + 1 );
		END;
		Strings.MoveW( ADR( S ), _Data@[(_Len-l)<<1], l );
	END CString.AppendOA;

	PUBLIC VIRTUAL PROCEDURE CString.Prepend( CONST S : IString );
	VAR
		l : CARDINAL;
	BEGIN
		l := S.Length;
		IF l = 0 THEN
			RETURN;
		END;
		INC( _Len, l );
		IF _Size < _Len THEN
			Reallocate( _Len + 1 );
		END;
		Strings.MoveW( _Data, _Data@[l<<1], _Len-l );
		Strings.MoveW( S.rawData, _Data, l );
	END CString.Prepend;

	PUBLIC VIRTUAL PROCEDURE CString.PrependOA( CONST S : ARRAY OF WCHAR );
	VAR
		l : CARDINAL;
	BEGIN
		l := LENGTH( S );
		IF l = 0 THEN
			RETURN;
		END;
		INC( _Len, l );
		IF _Size < _Len THEN
			Reallocate( _Len + 1 );
		END;
		Strings.MoveW( _Data, _Data@[l<<1], _Len-l );
		Strings.MoveW( ADR( S ), _Data, l );
	END CString.PrependOA;

	PUBLIC VIRTUAL PROCEDURE CString.Insert( To : CARDINAL; CONST S : IString );
	VAR
		l : CARDINAL;
	BEGIN
		l := S.Length;
		IF l = 0 THEN
			RETURN;
		END;
		INC( _Len, l );
		IF _Size < _Len THEN
			Reallocate( _Len + 1 );
		END;
		Strings.MoveW( _Data@[To<<1], _Data@[(To+l)<<1], _Len-l-To );
		Strings.MoveW( S.rawData, _Data@[To<<1], l );
	END CString.Insert;

	PUBLIC VIRTUAL PROCEDURE CString.InsertOA( To : CARDINAL; CONST S : ARRAY OF WCHAR );
	VAR
		l : CARDINAL;
	BEGIN
		l := LENGTH( S );
		IF l = 0 THEN
			RETURN;
		END;
		INC( _Len, l );
		IF _Size < _Len THEN
			Reallocate( _Len + 1 );
		END;
		Strings.MoveW( _Data@[To<<1], _Data@[(To+l)<<1], _Len-l-To );
		Strings.MoveW( ADR( S ), _Data@[To<<1], l );
	END CString.InsertOA;

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
		rl := From+Count;
		IF rl >= _Len THEN
			_Len := From;
	   ELSE
   		Strings.MoveW( _Data@[rl<<1], _Data@[From<<1], _Len-rl );
	   	DEC( _Len, Count );
	   END;
	END CString.Remove;

	PUBLIC VIRTUAL PROCEDURE CString.Replace( CONST Old, New : IString );
	VAR
		i, nl, ol : CARDINAL;
	BEGIN
		IF ( Old[0] = 0W ) OR ( _Len = 0 ) THEN
			RETURN;
		END;
		ol := Old.Length;
		nl := New.Length;
		i := 0;
		LOOP
			i := Strings.IndexOfMW( _Len, _Data, ol, PWCHAR( Old.rawData ), i );
			IF i = -1 THEN
				RETURN;
			END;
			IF ol > nl THEN
				Strings.MoveW( ADR( New ), _Data@[i<<1], nl );
				Remove( i+nl, ol-nl );
			ELSIF ol < nl THEN
				Strings.MoveW( ADR( New ), _Data@[i<<1], ol );
				InsertOA( i+ol, OA( nl-ol-1, New.rawData@[ol<<1] ));
			ELSE
				Strings.MoveW( ADR( New ), _Data@[i<<1], nl );
			END;
			INC( i, nl );
		END; // LOOP
	END CString.Replace;

	PUBLIC VIRTUAL PROCEDURE CString.ReplaceOA( CONST Old, New : ARRAY OF WCHAR );
	VAR
		i, nl, ol : CARDINAL;
	BEGIN
		IF ( Old[0] = 0W ) OR ( _Len = 0 ) THEN
			RETURN;
		END;
		ol := LENGTH( Old );
		nl := LENGTH( New );
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
	
	PUBLIC VIRTUAL PROCEDURE CString.Trim();
	BEGIN
	   IF _Len > 0 THEN
	      Strings.TrimW( REF OA( _Len-1, _Data ));
	      _Len := LENGTH( OA( _Len-1, _Data ));
	   END;
	END Trim;

	PUBLIC VIRTUAL PROCEDURE IndexOf( CONST S : IString; FromIndex : CARDINAL ) : CARDINAL;
	BEGIN
	   RETURN Strings.IndexOfMW( _Len, _Data, S.Length, PWCHAR( S.rawData ), FromIndex );
	END CString.IndexOf;

	PUBLIC VIRTUAL PROCEDURE IndexOfOA( CONST S : ARRAY OF WCHAR; FromIndex : CARDINAL ) : CARDINAL;
	BEGIN
	   RETURN Strings.IndexOfMW( _Len, _Data, LENGTH( S ), ADR( S ), FromIndex );
	END CString.IndexOfOA;

   PUBLIC VIRTUAL PROCEDURE LastIndexOf( CONST S : IString; IndexFromRight : CARDINAL ) : CARDINAL;
   BEGIN
	   RETURN Strings.LastIndexOfMW( _Len, _Data, S.Length, PWCHAR( S.rawData ), IndexFromRight );
   END LastIndexOf;

   PUBLIC VIRTUAL PROCEDURE LastIndexOfOA( CONST S : ARRAY OF WCHAR; IndexFromRight : CARDINAL ) : CARDINAL;
   BEGIN
	   RETURN Strings.LastIndexOfMW( _Len, _Data, LENGTH( S ), ADR( S ), IndexFromRight );
   END LastIndexOfOA;

	PUBLIC VIRTUAL PROCEDURE StartsWith( CONST S : IString ) : BOOLEAN;
	BEGIN
		IF _Len = 0 THEN
			RETURN S[0] = 0W;
		ELSIF S.Length = 0 THEN
			RETURN FALSE;
		ELSE
			RETURN Strings.StartsWithW( OA( _Len-1, _Data ), OA( S.Length-1, S.rawData ));
		END;
	END StartsWith;

	PUBLIC VIRTUAL PROCEDURE StartsWithOA( CONST S : ARRAY OF WCHAR ) : BOOLEAN;
	BEGIN
		IF _Len = 0 THEN
			RETURN S[0] = 0W;
		ELSE
			RETURN Strings.StartsWithW( OA( _Len-1, _Data ), S );
		END;
	END StartsWithOA;

	PUBLIC VIRTUAL PROCEDURE EndsWith( CONST S : IString ) : BOOLEAN;
	BEGIN
		IF _Len = 0 THEN
			RETURN S[0] = 0W;
		ELSIF S.Length = 0 THEN
			RETURN FALSE;
		ELSE
			RETURN Strings.StartsWithW( OA( _Len-1, _Data ), OA( S.Length-1, S.rawData ));
		END;
	END EndsWith;

	PUBLIC VIRTUAL PROCEDURE EndsWithOA( CONST S : ARRAY OF WCHAR ) : BOOLEAN;
	BEGIN
		IF _Len = 0 THEN
			RETURN S[0] = 0W;
		ELSE
			RETURN Strings.EndsWithW( OA( _Len-1, _Data ), S );
		END;
	END EndsWithOA;

   PUBLIC VIRTUAL PROCEDURE Match( CONST Pattern : IString; CaseSensitive : BOOLEAN ) : BOOLEAN;
   BEGIN
      RETURN Strings.MatchW( OA( _Len-1, _Data ), OA( Pattern.Length-1, Pattern.rawData ), CaseSensitive );
   END Match;

   PUBLIC VIRTUAL PROCEDURE MatchOA( CONST Pattern : ARRAY OF WCHAR; CaseSensitive : BOOLEAN ) : BOOLEAN;
   BEGIN
      RETURN Strings.MatchW( OA( _Len-1, _Data ), Pattern, CaseSensitive );
   END MatchOA;

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

	PUBLIC VIRTUAL PROCEDURE CString.Item( CONST Delimiters : SET OF WCHAR; FromIndex, ItemIndex : CARDINAL; SkipEmpty : BOOLEAN; OUT S : IString ) : CARDINAL;
	VAR
		i, j, l, p : CARDINAL;
	BEGIN
		p := 0;
		i := FromIndex;
   	IF SkipEmpty THEN
		   WHILE ( i < _Len ) AND ( _Data@[i<<1]^ IN Delimiters ) DO
			   INC( i );
		   END;
		END;
		LOOP
			IF i >= _Len THEN
				S.Clear();
				RETURN -1;
			ELSE
				j := i;
			END;
			WHILE ( i < _Len ) AND NOT( _Data@[i<<1]^ IN Delimiters ) DO
				INC( i );
			END;
			IF p = ItemIndex THEN
				l := i-j;
				IF l = 0 THEN
					S.Clear();
				ELSE
					S.FromOA( OA( l-1, _Data@[j<<1] ));
				END;
			END;
			IF SkipEmpty THEN
			   WHILE ( i < _Len ) AND ( _Data@[i<<1]^ IN Delimiters ) DO
				   INC( i );
			   END;
			ELSE
			   INC( i );
			END;
			IF p < ItemIndex THEN
				INC( p );
			ELSE
				RETURN i;
			END;
		END;
	END CString.Item;

	PUBLIC VIRTUAL PROCEDURE CString.ItemS( CONST Delimiters : SET OF WCHARS; FromIndex, ItemIndex : CARDINAL; SkipEmpty : BOOLEAN; OUT S : IString ) : CARDINAL;
	VAR
		i, j, l, p : CARDINAL;
	BEGIN
		p := 0;
		i := FromIndex;
		IF SkipEmpty THEN
		   WHILE ( i < _Len ) AND ( _Data@[i<<1]^ IN Delimiters ) DO
			   INC( i );
		   END;
		END;
		LOOP
			IF i >= _Len THEN
				S.Clear();
				RETURN -1;
			ELSE
				j := i;
			END;
			WHILE ( i < _Len ) AND NOT( _Data@[i<<1]^ IN Delimiters ) DO
				INC( i );
			END;
			IF p = ItemIndex THEN
				l := i-j;
				IF l = 0 THEN
					S.Clear();
				ELSE
					S.FromOA( OA( l-1, _Data@[j<<1] ));
				END;
			END;
			IF SkipEmpty THEN
			   WHILE ( i < _Len ) AND ( _Data@[i<<1]^ IN Delimiters ) DO
				   INC( i );
			   END;
			ELSE
			   INC( i );
			END;
			IF p < ItemIndex THEN
				INC( p );
			ELSE
				RETURN i;
			END;
		END;
	END CString.ItemS;

	PUBLIC VIRTUAL PROCEDURE CString.ItemOA( CONST Delimiters : SET OF WCHAR; FromIndex, ItemIndex : CARDINAL; SkipEmpty : BOOLEAN; OUT S : ARRAY OF WCHAR ) : CARDINAL;
	VAR
		i, j, p : CARDINAL;
	BEGIN
		p := 0;
		i := FromIndex;
		IF SkipEmpty THEN
		   WHILE ( i < _Len ) AND ( _Data@[i<<1]^ IN Delimiters ) DO
			   INC( i );
		   END;
		END;
		LOOP
			IF i >= _Len THEN
				S[0] := WCHAR( 0 );
				RETURN -1;
			ELSE
				j := i;
			END;
			WHILE ( i < _Len ) AND NOT( _Data@[i<<1]^ IN Delimiters ) DO
				INC( i );
			END;
			IF p = ItemIndex THEN
				ASSIGN( S, OA( i-j-1, _Data@[j<<1] ));
			END;
			IF SkipEmpty THEN
			   WHILE ( i < _Len ) AND ( _Data@[i<<1]^ IN Delimiters ) DO
				   INC( i );
			   END;
			ELSE
			   INC( i );
			END;
			IF p < ItemIndex THEN
				INC( p );
			ELSE
				RETURN i;
			END;
		END;
	END CString.ItemOA;

	PUBLIC VIRTUAL PROCEDURE CString.ItemSOA( CONST Delimiters : SET OF WCHARS; FromIndex, ItemIndex : CARDINAL; SkipEmpty : BOOLEAN; OUT S : ARRAY OF WCHAR ) : CARDINAL;
	VAR
		i, j, p : CARDINAL;
	BEGIN
		p := 0;
		i := FromIndex;
		IF SkipEmpty THEN
		   WHILE ( i < _Len ) AND ( _Data@[i<<1]^ IN Delimiters ) DO
			   INC( i );
		   END;
		END;
		LOOP
			IF i >= _Len THEN
				S[0] := WCHAR( 0 );
				RETURN -1;
			ELSE
				j := i;
			END;
			WHILE ( i < _Len ) AND NOT( _Data@[i<<1]^ IN Delimiters ) DO
				INC( i );
			END;
			IF p = ItemIndex THEN
				ASSIGN( S, OA( i-j-1, _Data@[j<<1] ));
			END;
			IF SkipEmpty THEN
			   WHILE ( i < _Len ) AND ( _Data@[i<<1]^ IN Delimiters ) DO
				   INC( i );
			   END;
			ELSE
			   INC( i );
			END;
			IF p < ItemIndex THEN
				INC( p );
			ELSE
				RETURN i;
			END;
		END;
	END CString.ItemSOA;

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

   PUBLIC VIRTUAL PROCEDURE Lowerize();
   BEGIN
      IF _Len = 0 THEN
         RETURN;
      END;
      LOW( OA( _Len-1, _Data ));
   END Lowerize;

   PUBLIC VIRTUAL PROCEDURE Capitalize();
   BEGIN
      IF _Len = 0 THEN
         RETURN;
      END;
      CAP( OA( _Len-1, _Data ));
   END Capitalize;

	PUBLIC VIRTUAL PROCEDURE CString.ToOA( OUT S : ARRAY OF WCHAR );
	BEGIN
		IF _Len = 0 THEN
			S[0] := WCHAR( 0 );
		ELSE
			ASSIGN( S, OA( _Len-1, _Data ));
		END;
	END CString.ToOA;

	PUBLIC VIRTUAL PROCEDURE CString.ToOAA( CodePage : CARDINAL; OUT S : ARRAY OF CHAR; OUT Filled : CARDINAL );
	BEGIN
		IF _Len = 0 THEN
		   Filled := 0;
			S[0] := CHAR( 0 );
		ELSE
			IF CodePage = 0 THEN
				CodePage := winnls.CP_ACP;
			END;
			Filled := winnls.WideCharToMultiByte( CodePage, 0, _Data, _Len, ADR( S ), HIGH( S ) + 1, NIL, NIL );
			IF Filled < HIGH( S ) THEN
				S[Filled] := CHAR( 0 );
			END;
		END;
	END CString.ToOAA;

	PUBLIC VIRTUAL PROCEDURE CString.ToUTF8( OUT S : ARRAY OF CHAR; OUT Filled : CARDINAL );
	BEGIN
	   ToOAA( winnls.CP_UTF8, OUT S, OUT Filled );
	END CString.ToUTF8;

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

	PUBLIC VIRTUAL PROCEDURE CString.ToLONGREAL( OUT R : LONGREAL ) : BOOLEAN;
	BEGIN
	   RETURN Strings.ToLONGREALW( OA( _Len-1, _Data ), OUT R );
	END CString.ToLONGREAL;

	PUBLIC VIRTUAL PROCEDURE CString.FromOA( CONST S : ARRAY OF WCHAR );
	BEGIN
		_Len := LENGTH( S );
		IF _Len = 0 THEN
			RETURN;
		ELSIF _Size < _Len THEN
			Reallocate( _Len + 1 );
		END;
		Strings.MoveW( ADR( S ), _Data, _Len );
	END CString.FromOA;

	PUBLIC VIRTUAL PROCEDURE FromOAA( CodePage : CARDINAL; CONST S : ARRAY OF CHAR );
	BEGIN
		_Len := LENGTH( S );
		IF _Len = 0 THEN
			RETURN;
		ELSIF _Size < _Len THEN
			Reallocate( _Len + 1 );
		END;
		IF CodePage = 0 THEN
			CodePage := winnls.CP_ACP;
		END;
		IF CodePage = winnls.CP_UTF8 THEN
			_Len := winnls.MultiByteToWideChar( CodePage, 0, ADR( S ), _Len, _Data, _Len );
		ELSE
         _Len := winnls.MultiByteToWideChar( CodePage, winnls.MB_PRECOMPOSED, ADR( S ), _Len, _Data, _Len );
      END;
	END CString.FromOAA;
	
   PUBLIC VIRTUAL PROCEDURE FromUTF8( CONST S : ARRAY OF CHAR );
	BEGIN
	   FromOAA( winnls.CP_UTF8, S );
   END CString.FromUTF8;

	PUBLIC VIRTUAL PROCEDURE FromINT32( I : INT32; Base : CARDINAL );
	BEGIN
		IF _Size < 10 THEN
			Reallocate( 10 );
		END;
		Strings.FromINT32W( I, Base, OUT OA( 9, _Data ));
		_Len := LENGTH( OA( 9, _Data ));
	END CString.FromINT32;
	
	PUBLIC VIRTUAL PROCEDURE FromCARD32( C : CARD32; Base : CARDINAL );
	BEGIN
		IF _Size < 10 THEN
			Reallocate( 10 );
		END;
		Strings.FromCARD32W( C, Base, OUT OA( 9, _Data ));
		_Len := LENGTH( OA( 9, _Data ));
	END CString.FromCARD32;
	
	PUBLIC VIRTUAL PROCEDURE FromINT64( I : INT64; Base : CARDINAL );
	BEGIN
		IF _Size < 20 THEN
			Reallocate( 20 );
		END;
		Strings.FromINT64W( I, Base, OUT OA( 19, _Data ));
		_Len := LENGTH( OA( 19, _Data ));
	END CString.FromINT64;
	
	PUBLIC VIRTUAL PROCEDURE FromCARD64( C : CARD64; Base : CARDINAL );
	BEGIN
		IF _Size < 20 THEN
			Reallocate( 20 );
		END;
		Strings.FromCARD64W( C, Base, OUT OA( 19, _Data ));
		_Len := LENGTH( OA( 19, _Data ));
	END CString.FromCARD64;
	
	PUBLIC VIRTUAL PROCEDURE FromLONGREAL( R : LONGREAL; ExpFlag : BOOLEAN );
	VAR
		S : ARRAY [0..319] OF WCHAR;
	BEGIN
		IF lrconv.LONGREALToStrW( R, -1, -1, ExpFlag, 0W, OUT S ) THEN
			FromOA( S );
		ELSE
			FromOA( L"0.0" );
		END;
	END CString.FromLONGREAL;

	PUBLIC VIRTUAL PROCEDURE FromLONGREALExt( R : LONGREAL; ValidCiphers, FractionPlaces : CARDINAL; ExpFlag : BOOLEAN; PointChar : WCHAR );
	VAR
		S : ARRAY [0..319] OF WCHAR;
	BEGIN
		IF lrconv.LONGREALToStrW( R, ValidCiphers, FractionPlaces, ExpFlag, PointChar, OUT S ) THEN
			FromOA( S );
		ELSE
			FromOA( L"0.0" );
		END;
	END CString.FromLONGREALExt;

	INITIALLY CString;
	BEGIN
		_Size := 0;
		_Len := 0;
		_Data := NIL;
	END CString;

	FINALLY CString;
	BEGIN
		Deallocate();
	END CString;

END CString;

END StringsO.
