IMPLEMENTATION MODULE Strings;

FROM Debug IMPORT
   Assertion;

FROM Strings IMPORT
	CapitalizeW;

IMPORT
	Languages,
	lrconv,
	windows,
	winnls;

PROCEDURE MoveA( CONST Source : ADDRESS; Destination : ADDRESS; Chars : CARDINAL );
BEGIN
	windows.MoveMemory( Destination, ADDRESS( Source ), Chars );
END MoveA;

PROCEDURE MoveW( CONST Source : ADDRESS; Destination : ADDRESS; Chars : CARDINAL );
BEGIN
	windows.MoveMemory( Destination, ADDRESS( Source ), Chars << 1 );
END MoveW;

PROCEDURE IncA( CONST Source : ADDRESS; Chars : CARDINAL ) : ADDRESS;
BEGIN
	RETURN INC( Source, Chars );
END IncA;

PROCEDURE IncW( CONST Source : ADDRESS; Chars : CARDINAL ) : ADDRESS;
BEGIN
	RETURN INC( Source, Chars<<1 );
END IncW;

PROCEDURE CompareW( CONST String1, String2 : ARRAY OF WCHAR ) : TRISTATE;
VAR
	S1, S2, Terminate : PWCHAR;
BEGIN
	IF HIGH( String1 ) < HIGH( String2 ) THEN
		Terminate := PWCHAR( ADR( String1 )@[ HIGH(String1)<<1 + 2 ] );
	ELSE
		Terminate := PWCHAR( ADR( String1 )@[ HIGH(String2)<<1 + 2 ] );
	END;
	S1 := PWCHAR( ADR( String1 ));
	S2 := PWCHAR( ADR( String2 ));
	LOOP
		IF S1 = Terminate THEN
			IF HIGH( String1 ) < HIGH( String2 ) THEN
				IF S2^ = 0W THEN
					RETURN 0;
				ELSE
					RETURN -1;
				END;
			ELSIF HIGH( String1 ) > HIGH( String2 ) THEN
				IF S1^ = 0W THEN
					RETURN 0;
				ELSE
					RETURN 1;
				END;
			ELSE
				RETURN 0;
			END;
		ELSIF S1^ > S2^ THEN
			RETURN 1;
		ELSIF S1^ < S2^ THEN
			RETURN -1;
		ELSIF S1^ = 0W THEN
			RETURN 0;
		END;
		INC( S1, 2 );
		INC( S2, 2 );
	END; // LOOP
END CompareW;

PROCEDURE EqualsIgnoreCaseW( CONST String1, String2 : ARRAY OF WCHAR ) : BOOLEAN;
VAR
	L1, L2 : CARDINAL;
BEGIN
	L1 := LENGTH( String1 );
	L2 := LENGTH( String2 );
	IF L1 <> L2 THEN
		RETURN FALSE;
	ELSIF L2 = 0 THEN
		RETURN TRUE;
	ELSE
		RETURN winnls.CompareStringW(
			windows.LOCALE_USER_DEFAULT,
			winnls.NORM_IGNORECASE,
			ADR( String1 ), L1, ADR( String2 ), L2
		) = winnls.CSTR_EQUAL;
	END;
END EqualsIgnoreCaseW;

PROCEDURE ConcatW( OUT String : ARRAY OF WCHAR; CONST Operand1, Operand2 : ARRAY OF WCHAR );  
VAR
	l : PTR;
	src, dst, stop : PWCHAR;
BEGIN
	src := PWCHAR( ADR( Operand1 ));
	dst := ADR( String );
	stop := INC( src, ( MIN2( HIGH( String ), HIGH( Operand1 )) + 1 ) << 1 );
	LOOP
		IF src = stop THEN
			EXIT;
		ELSIF src^ = 0W THEN
			EXIT;
		END;
		dst^ := src^;
		INC( src, 2 );
		INC( dst, 2 );
	END; // LOOP
	l := PTR( DEC( src, PTR( ADR( Operand1 )))) >> 1;
	IF l > HIGH( String ) THEN
		RETURN;
	ELSE
		ASSIGN( OA( HIGH( String ) - l, dst ), Operand2 );
	END;
END ConcatW;

PROCEDURE AppendW( REF String : ARRAY OF WCHAR; CONST Operand : ARRAY OF WCHAR );
VAR
	l, dl : INTEGER;
BEGIN
	l := LENGTH( String );
	dl := HIGH( String ) - l;
	IF dl < 0 THEN
		RETURN;
	ELSE
		ASSIGN( OA( dl, ADR( String )@[l<<1] ), Operand );
	END;
END AppendW;

PROCEDURE PrependW( REF String : ARRAY OF WCHAR; CONST Operand : ARRAY OF WCHAR );
VAR
	l, lo : CARDINAL;
BEGIN
	l := LENGTH( String );
	IF l = 0 THEN
		ASSIGN( String, Operand );
		RETURN;
	END;
	lo := LENGTH( Operand );
	IF lo > HIGH( String ) THEN
		ASSIGN( String, Operand );
		RETURN;
	END;
	MoveW( ADR( String ), ADR( String )@[lo<<1], MIN2( l+1, HIGH( String )+1-lo )); // l+1 to include terminating zero
	MoveW( ADR( Operand ), ADR( String ), lo );
END PrependW;

PROCEDURE InsertW( REF String : ARRAY OF WCHAR; To : CARDINAL; CONST Operand : ARRAY OF WCHAR );
VAR
	l, ol : CARDINAL;
BEGIN
	IF To > HIGH( String ) THEN
		RETURN;
	END;
	ol := LENGTH( Operand );
	IF ol = 0 THEN
		RETURN;
	END;
	l := LENGTH( String );
	IF To > l THEN
		To := l;
	END;
	IF To + ol <= HIGH( String ) THEN
		MoveW( ADR( String )@[To<<1], ADR( String )@[(To+ol)<<1], MIN2( HIGH( String )-To-ol+1, l ));
	END;
	MoveW( ADR( Operand ), ADR( String )@[To<<1], MIN2( HIGH( String )-To+1, ol ));
	INC( l, ol );
	IF l < HIGH( String ) THEN
		String[l] := 0W;
	END;
END InsertW;

PROCEDURE RemoveW( REF String : ARRAY OF WCHAR; From, Count : CARDINAL );
VAR
	l, rl : CARDINAL;
BEGIN
	IF Count = 0 THEN
		RETURN;
	END;
	l := LENGTH( String );
	IF From > l THEN
		RETURN;
	ELSIF Count > MAX( INTEGER ) THEN
		Count := l;
	END;
	rl := From+Count;
	IF rl >= l THEN
		String[From] := 0W;
   ELSE
   	MoveW( ADR( String )@[rl<<1], ADR( String )@[From<<1], l-rl );
	   String[From+l-rl] := 0W;
	END;
END RemoveW;

PROCEDURE ReplaceW( REF String : ARRAY OF WCHAR; CONST Old, New : ARRAY OF WCHAR );
VAR
	i, nl, ol : CARDINAL;
BEGIN
	IF Old[0] = 0W THEN
		RETURN;
	END;
	ol := LENGTH( Old );
	nl := LENGTH( New );
	i := 0;
	LOOP
		i := IndexOfW( String, Old, i );
		IF i = -1 THEN
			RETURN;
		END;
		IF ol > nl THEN
			MoveW( ADR( New ), ADR( String )@[i<<1], MIN2( nl, HIGH( String )+1-i ));
			RemoveW( REF String, i+nl, ol-nl );
		ELSIF ol < nl THEN
			MoveW( ADR( New ), ADR( String )@[i<<1], MIN2( ol, HIGH( String )+1-i ));
			InsertW( REF String, i+ol, OA( nl-ol-1, ADR( New[ol] )));
		ELSE
			MoveW( ADR( New ), ADR( String )@[i<<1], MIN2( nl, HIGH( String )+1-i ));
		END;
		INC( i, nl );
	END; // LOOP
END ReplaceW;

PROCEDURE PadLeftW( REF String : ARRAY OF WCHAR; Length : CARDINAL; CONST Padding : ARRAY OF WCHAR );
VAR
	l1, l2, p : CARDINAL;
BEGIN
	l2 := LENGTH( String );
	IF l2 >= Length THEN
		RETURN;
	END;
	l1 := MIN2( Length, HIGH( String ) + 1 ) - l2;
	MoveW( ADR( String ), ADR( String )@[l1<<1], l2 );
	l2 := LENGTH( Padding );
	p := l2;
	WHILE l1 > 0 DO
		DEC( l1 );
		DEC( p );
		String[l1] := Padding[p];
		IF p = 0 THEN
			p := l2;
		END;
	END; // WHILE
	IF Length < HIGH( String ) THEN
		String[Length] := 0W;
	END;
END PadLeftW;

PROCEDURE PadRightW( REF String : ARRAY OF WCHAR; Length : CARDINAL; CONST Padding : ARRAY OF WCHAR );
VAR
	l1, l2, p : CARDINAL;
BEGIN
	l1 := LENGTH( String );
	IF l1 >= Length THEN
		RETURN;
	END;
	Length := MIN2( Length, HIGH( String )+1 );
	l2 := LENGTH( Padding );
	p := 0;
	WHILE l1 < Length DO
		String[l1] := Padding[p];
		INC( l1 );
		INC( p );
		IF p >= l2 THEN
			p := 0;
		END;
	END; // WHILE
	IF l1 < HIGH( String ) THEN
		String[l1] := 0W;
	END;
END PadRightW;
	
PROCEDURE TrimStartW( REF String : ARRAY OF WCHAR );
BEGIN
	TrimStartDelimitersW( REF String, WCHAR{' ', WCHAR(9), WCHAR(10), WCHAR(13)} );
END TrimStartW;

PROCEDURE TrimStartDelimitersW( REF String : ARRAY OF WCHAR; CONST Delimiters : SET OF WCHAR );
VAR
	i, l : CARDINAL;
BEGIN
	l := LENGTH( String );
	IF l = 0 THEN
		RETURN;
	END;
	i := 0;
	WHILE ( i < l ) AND ( String[i] IN Delimiters ) DO
		INC( i );
	END; // WHILE
	IF i > 0 THEN
		RemoveW( REF String, 0, i );
	END;
END TrimStartDelimitersW;

PROCEDURE TrimStartDelimitersSW( REF String : ARRAY OF WCHAR; CONST Delimiters : SET OF WCHARS );
VAR
	i, l : CARDINAL;
BEGIN
	l := LENGTH( String );
	IF l = 0 THEN
		RETURN;
	END;
	i := 0;
	WHILE ( i < l ) AND ( String[i] IN Delimiters ) DO
		INC( i );
	END; // WHILE
	IF i > 0 THEN
		RemoveW( REF String, 0, i );
	END;
END TrimStartDelimitersSW;

PROCEDURE TrimEndW( REF String : ARRAY OF WCHAR );
BEGIN
	TrimEndDelimitersW( REF String, WCHAR{' ', WCHAR(9), WCHAR(10), WCHAR(13)} );
END TrimEndW;

PROCEDURE TrimEndDelimitersW( REF String : ARRAY OF WCHAR; CONST Delimiters : SET OF WCHAR );
VAR
	i, l : CARDINAL;
BEGIN
	l := LENGTH( String );
	IF l = 0 THEN
		RETURN;
	END;
	i := l - 1;
	LOOP
		IF NOT( String[i] IN Delimiters ) THEN
			IF i + 1 <= HIGH( String ) THEN
				String[i+1] := 0W;
			END;
			EXIT;
		ELSIF i = 0 THEN
			EXIT;
		ELSE
			DEC( i );
		END;
	END; // LOOP
END TrimEndDelimitersW;

PROCEDURE TrimEndDelimitersSW( REF String : ARRAY OF WCHAR; CONST Delimiters : SET OF WCHARS );
VAR
	i, l : CARDINAL;
BEGIN
	l := LENGTH( String );
	IF l = 0 THEN
		RETURN;
	END;
	i := l - 1;
	LOOP
		IF NOT( String[i] IN Delimiters ) THEN
			IF i + 1 <= HIGH( String ) THEN
				String[i+1] := 0W;
			END;
			EXIT;
		ELSIF i = 0 THEN
			EXIT;
		ELSE
			DEC( i );
		END;
	END; // LOOP
END TrimEndDelimitersSW;

PROCEDURE TrimW( REF String : ARRAY OF WCHAR );
BEGIN
	TrimDelimitersW( REF String, WCHAR{' ', WCHAR(9), WCHAR(10), WCHAR(13)} );
END TrimW;

PROCEDURE TrimDelimitersW( REF String : ARRAY OF WCHAR; CONST Delimiters : SET OF WCHAR );
VAR
	i, l : CARDINAL;
BEGIN
	l := LENGTH( String );
	IF l = 0 THEN
		RETURN;
	END;
	i := l - 1;
	LOOP
		IF NOT( String[i] IN Delimiters ) THEN
			IF i+1 <= HIGH( String ) THEN
				String[i+1] := 0W;
			END;
			EXIT;
		ELSIF i = 0 THEN
			RETURN;
		ELSE
			DEC( i );
		END;
	END; // LOOP
	l := i;
	i := 0;
	WHILE ( i < l ) AND ( String[i] IN Delimiters ) DO
		INC( i );
	END; // WHILE
	IF i > 0 THEN
		RemoveW( REF String, 0, i );
	END;
END TrimDelimitersW;

PROCEDURE TrimDelimitersSW( REF String : ARRAY OF WCHAR; CONST Delimiters : SET OF WCHARS );
VAR
	i, l : CARDINAL;
BEGIN
	l := LENGTH( String );
	IF l = 0 THEN
		RETURN;
	END;
	i := l - 1;
	LOOP
		IF NOT( String[i] IN Delimiters ) THEN
			IF i+1 <= HIGH( String ) THEN
				String[i+1] := 0W;
			END;
			EXIT;
		ELSIF i = 0 THEN
			RETURN;
		ELSE
			DEC( i );
		END;
	END; // LOOP
	l := i;
	i := 0;
	WHILE ( i < l ) AND ( String[i] IN Delimiters ) DO
		INC( i );
	END; // WHILE
	IF i > 0 THEN
		RemoveW( REF String, 0, i );
	END;
END TrimDelimitersSW;

PROCEDURE IndexOfCharA( CONST Source : ARRAY OF CHAR; Char : CHAR; FromIndex : CARDINAL ) : CARDINAL;
VAR
	i, l : CARDINAL;
BEGIN
	IF FromIndex = 0 THEN
		l := HIGH( Source );
	ELSE
		l := LENGTH( Source );
		IF l = 0 THEN
			RETURN -1;
		END;
		DEC( l );
	END;
	FOR i := FromIndex TO l DO
		IF Source[i] = Char THEN
			RETURN i;
		ELSIF Source[i] = 0C THEN
			RETURN -1;
		END;
	END;
	RETURN -1;
END IndexOfCharA;

PROCEDURE IndexOfCharW( CONST Source : ARRAY OF WCHAR; Char : WCHAR; FromIndex : CARDINAL ) : CARDINAL;
VAR
	i, l : CARDINAL;
BEGIN
	IF FromIndex = 0 THEN
		l := HIGH( Source );
	ELSE
		l := LENGTH( Source );
		IF l = 0 THEN
			RETURN -1;
		END;
		DEC( l );
	END;
	FOR i := FromIndex TO l DO
		IF Source[i] = Char THEN
			RETURN i;
		ELSIF Source[i] = 0W THEN
			RETURN -1;
		END;
	END;
	RETURN -1;
END IndexOfCharW;

PROCEDURE IndexOfA( CONST Source, String : ARRAY OF CHAR; FromIndex : CARDINAL ) : CARDINAL;
BEGIN
	IF ( HIGH( String ) = 0 ) OR ( String[1] = 0C ) THEN
		RETURN IndexOfCharA( Source, String[0], FromIndex );
	ELSE
		RETURN IndexOfMA( LENGTH( Source ), ADR( Source ), LENGTH( String ), ADR( String ), FromIndex );
	END;
END IndexOfA;

PROCEDURE IndexOfW( CONST Source, String : ARRAY OF WCHAR; FromIndex : CARDINAL ) : CARDINAL;
BEGIN
	IF ( HIGH( String ) = 0 ) OR ( String[1] = 0W ) THEN
		RETURN IndexOfCharW( Source, String[0], FromIndex );
	ELSE
		RETURN IndexOfMW( LENGTH( Source ), ADR( Source ), LENGTH( String ), ADR( String ), FromIndex );
	END;
END IndexOfW;

PROCEDURE IndexOfMA( SourceLen : CARDINAL; CONST Source : POINTER TO CHAR; StringLen : CARDINAL; CONST String : POINTER TO CHAR; FromIndex : CARDINAL ) : CARDINAL;
VAR
	i, j, nexti : CARDINAL;
BEGIN
	IF ( StringLen = 0 ) OR ( SourceLen = 0 ) THEN
		RETURN -1;
	ELSIF FromIndex+StringLen > SourceLen THEN
		RETURN -1;
	END;
	i := FromIndex;
	LOOP
		IF i > SourceLen-StringLen THEN
			EXIT;
		ELSIF Source@[i]^ = String^ THEN // have first char, check whole string
			nexti := 0;
			j := 1;
			LOOP
				IF j >= StringLen THEN
					RETURN i;
				ELSIF Source@[i+j]^ <> String@[j]^ THEN // not found
					IF nexti > 0 THEN
						i := nexti; // use hint
					END;
					EXIT;
				END;
				IF ( nexti = 0 ) AND ( Source@[i+j]^ = String^ ) THEN // hint
					nexti := i+j-1; // after assignment (see "use hint") i is incremented
				END;
				INC( j );
			END; // LOOP
		END;
		INC( i );
	END; // LOOP
	RETURN -1;
END IndexOfMA;

PROCEDURE IndexOfMW( SourceLen : CARDINAL; CONST Source : POINTER TO WCHAR; StringLen : CARDINAL; CONST String : POINTER TO WCHAR; FromIndex : CARDINAL ) : CARDINAL;
VAR
	i, j, nexti : CARDINAL;
BEGIN
	IF ( StringLen = 0 ) OR ( SourceLen = 0 ) THEN
		RETURN -1;
	ELSIF FromIndex+StringLen > SourceLen THEN
		RETURN -1;
	END;
	i := FromIndex;
	LOOP
		IF i > SourceLen-StringLen THEN
			EXIT;
		ELSIF Source@[i<<1]^ = String^ THEN // have first char, check whole string
			nexti := 0;
			j := 1;
			LOOP
				IF j >= StringLen THEN
					RETURN i;
				ELSIF Source@[(i+j)<<1]^ <> String@[j<<1]^ THEN // not found
					IF nexti > 0 THEN
						i := nexti; // use hint
					END;
					EXIT;
				END;
				IF ( nexti = 0 ) AND ( Source@[(i+j)<<1]^ = String^ ) THEN // hint
					nexti := i+j-1; // after assignment (see "use hint") i is incremented
				END;
				INC( j );
			END; // LOOP
		END;
		INC( i );
	END; // LOOP
	RETURN -1;
END IndexOfMW;

PROCEDURE IndexOfAnyW( CONST Source : ARRAY OF WCHAR; CONST Any : SET OF WCHAR; FromIndex : CARDINAL ) : CARDINAL;
VAR
	i, l : CARDINAL;
BEGIN
	IF FromIndex = 0 THEN
		l := HIGH( Source );
	ELSE
		l := LENGTH( Source );
		IF l = 0 THEN
			RETURN -1;
		END;
	END;
	FOR i := FromIndex TO l DO
		IF Source[i] IN Any THEN
			RETURN i;
		ELSIF Source[i] = 0W THEN
			RETURN -1;
		END;
	END;
	RETURN -1;
END IndexOfAnyW;

PROCEDURE IndexOfAnySW( CONST Source : ARRAY OF WCHAR; CONST Any : SET OF WCHARS; FromIndex : CARDINAL ) : CARDINAL;
VAR
	i, l : CARDINAL;
BEGIN
	IF FromIndex = 0 THEN
		l := HIGH( Source );
	ELSE
		l := LENGTH( Source );
		IF l = 0 THEN
			RETURN -1;
		END;
	END;
	FOR i := FromIndex TO l DO
		IF Source[i] IN Any THEN
			RETURN i;
		ELSIF Source[i] = 0W THEN
			RETURN -1;
		END;
	END;
	RETURN -1;
END IndexOfAnySW;

PROCEDURE LastIndexOfCharW( CONST Source : ARRAY OF WCHAR; Char : WCHAR; IndexFromRight : CARDINAL ) : CARDINAL;
VAR
	i : INTEGER;
BEGIN
	FOR i := LENGTH( Source )-1-IndexFromRight TO 0 BY -1 DO
		IF Source[i] = Char THEN
			RETURN i;
		END;
	END;
	RETURN -1;
END LastIndexOfCharW;

PROCEDURE LastIndexOfW( CONST Source : ARRAY OF WCHAR; CONST String : ARRAY OF WCHAR; IndexFromRight : CARDINAL ) : CARDINAL;
BEGIN
	IF ( HIGH( String ) = 0 ) OR ( String[1] = 0W) THEN
		RETURN LastIndexOfCharW( Source, String[0], IndexFromRight );
	ELSE
	   ASSERT( FALSE );
		RETURN -1;
	END;
END LastIndexOfW;

PROCEDURE LastIndexOfAnyW( CONST Source : ARRAY OF WCHAR; CONST Any : SET OF WCHAR; IndexFromRight : CARDINAL ) : CARDINAL;
VAR
	i : INTEGER;
BEGIN
	FOR i := LENGTH( Source )-1-IndexFromRight TO 0 BY -1 DO
		IF Source[i] IN Any THEN
			RETURN i;
		END;
	END;
	RETURN -1;
END LastIndexOfAnyW;

PROCEDURE LastIndexOfAnySW( CONST Source : ARRAY OF WCHAR; CONST Any : SET OF WCHARS; IndexFromRight : CARDINAL ) : CARDINAL;
VAR
	i : INTEGER;
BEGIN
	FOR i := LENGTH( Source )-1-IndexFromRight TO 0 BY -1 DO
		IF Source[i] IN Any THEN
			RETURN i;
		END;
	END;
	RETURN -1;
END LastIndexOfAnySW;

PROCEDURE StartsWithW( CONST String, Start : ARRAY OF WCHAR ) : BOOLEAN;
VAR
	i : INTEGER := 0;
BEGIN
	LOOP
		IF ( i > HIGH( Start )) OR ( Start[i] = 0W) THEN
			RETURN TRUE;
		ELSIF i > HIGH( String ) THEN
			RETURN FALSE;
		ELSIF String[i] <> Start[i] THEN
			RETURN FALSE;
		// ELSIF String[i] = 0 THEN -- not needed, the conditions above cover this
		//  RETURN TRUE;
		END;
		INC( i );
	END; // LOOP
END StartsWithW;

PROCEDURE EndsWithW( CONST String, End : ARRAY OF WCHAR ) : BOOLEAN;
VAR
	i : INTEGER := LENGTH( String ) - 1;
	j : INTEGER := LENGTH( End ) - 1;
BEGIN
	LOOP
		IF j < 0 THEN
			RETURN TRUE;
		ELSIF i < 0 THEN
			RETURN FALSE;
		ELSIF String[i] <> End[j] THEN
			RETURN FALSE;
		END;
		DEC( i );
		DEC( j );
	END; // LOOP
END EndsWithW;

PROCEDURE MatchW( CONST S, Pattern: ARRAY OF WCHAR; CaseSensitive : BOOLEAN ): BOOLEAN;

   PROCEDURE Rmatch( CONST s : ARRAY OF WCHAR; i : CARDINAL; CONST p : ARRAY OF WCHAR; j : CARDINAL ): BOOLEAN;
   // s = to be tested,     i = position in s
   // p = pattern to match, j = position in p
   VAR
     k : CARDINAL;
     matched : BOOLEAN;
     pend : BOOLEAN;
   BEGIN
		IF p[0] = 0W THEN 
			RETURN TRUE;
		END;
		LOOP
			pend := NOT INSIDE( j, p );
			IF pend AND NOT INSIDE( i, s ) THEN
				RETURN TRUE; // both s and p ended
			ELSIF pend THEN
				RETURN FALSE; // pattern ended before source
			ELSIF p[j] = L'*' THEN
				k := i;
				IF NOT INSIDE( j+1, p ) THEN
					RETURN TRUE; // pattern ends with '*', any source tail will be accepted
				ELSE
					LOOP
						matched := Rmatch( s, k, p, j+1 ); // call Rmatch with skipped '*' in pattern
						IF matched OR NOT INSIDE( k, s ) THEN
							RETURN matched;
						END;
						INC( k ); // skip one character in source and try again
					END; // LOOP
				END;
			ELSIF ( p[j] = L'?' ) AND ( s[i] <> 0W ) THEN
				// question mark replaced by any character
				INC( i ); 
				INC( j );
			ELSIF CaseSensitive AND ( p[j] = s[i] ) OR NOT CaseSensitive AND ( CAP( p[j] ) = CAP( s[i] )) THEN
				// character matches
				INC( i ); 
				INC( j );
			ELSE
				RETURN FALSE; // no match found
			END;
		END; // LOOP
	END Rmatch;

BEGIN // MatchW
	RETURN Rmatch( S, 0, Pattern, 0 );
END MatchW;

PROCEDURE SubstringW( CONST Source : ARRAY OF WCHAR; From, Count : CARDINAL; OUT Substring : ARRAY OF WCHAR );
VAR
	l : CARDINAL;
BEGIN
	IF Count = 0 THEN
		RETURN;
	END;
	l := LENGTH( Source );
	IF l = 0 THEN
		Substring := L'';
		RETURN;
	ELSIF From > l THEN
		Substring := L'';
		RETURN;
	ELSIF Count > MAX( INTEGER ) THEN
		Count := l-From; 
	END;
	ASSIGN( Substring, OA( Count-1, ADR( Source )@[From<<1] ));
END SubstringW;

PROCEDURE ItemW( CONST Source : ARRAY OF WCHAR; CONST Delimiters : SET OF WCHAR; FromIndex, ItemIndex : CARDINAL; SkipEmpty : BOOLEAN; OUT Substring : ARRAY OF WCHAR ) : CARDINAL;
BEGIN
	RETURN ItemMW( LENGTH( Source ), ADR( Source ), Delimiters, FromIndex, ItemIndex, SkipEmpty, OUT Substring );
END ItemW;

PROCEDURE ItemSW( CONST Source : ARRAY OF WCHAR; CONST Delimiters : SET OF WCHARS; FromIndex, ItemIndex : CARDINAL; SkipEmpty : BOOLEAN; OUT Substring : ARRAY OF WCHAR ) : CARDINAL;
BEGIN
	RETURN ItemSMW( LENGTH( Source ), ADR( Source ), Delimiters, FromIndex, ItemIndex, SkipEmpty, OUT Substring );
END ItemSW;

PROCEDURE ItemMW( SourceLen : CARDINAL; CONST Source : POINTER TO WCHAR; CONST Delimiters : SET OF WCHAR; FromIndex, ItemIndex : CARDINAL; SkipEmpty : BOOLEAN; OUT Substring : ARRAY OF WCHAR ) : CARDINAL;
VAR
	i, j, p : CARDINAL;
BEGIN
	p := 0;
	i := FromIndex;
   IF SkipEmpty THEN
	   WHILE ( i < SourceLen ) AND ( Source@[i<<1]^ IN Delimiters ) DO
		   INC( i );
	   END;
	END;
	LOOP
		IF i >= SourceLen THEN
			Substring[0] := 0W;
			RETURN -1;
		ELSE
			j := i;
		END;
		WHILE ( i < SourceLen ) AND NOT( Source@[i<<1]^ IN Delimiters ) DO
			INC( i );
		END;
		IF p = ItemIndex THEN
			ASSIGN( Substring, OA( i-j-1, Source@[j<<1] ));
		END;
		IF SkipEmpty THEN
		   WHILE ( i < SourceLen ) AND ( Source@[i<<1]^ IN Delimiters ) DO
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
END ItemMW;

PROCEDURE ItemSMW( SourceLen : CARDINAL; CONST Source : POINTER TO WCHAR; CONST Delimiters : SET OF WCHARS; FromIndex, ItemIndex : CARDINAL; SkipEmpty : BOOLEAN; OUT Substring : ARRAY OF WCHAR ) : CARDINAL;
VAR
	i, j, p : CARDINAL;
BEGIN
	p := 0;
	i := FromIndex;
   IF SkipEmpty THEN
	   WHILE ( i < SourceLen ) AND ( Source@[i<<1]^ IN Delimiters ) DO
		   INC( i );
	   END;
	END;
	LOOP
		IF i >= SourceLen THEN
			Substring[0] := 0W;
			RETURN -1;
		ELSE
			j := i;
		END;
		WHILE ( i < SourceLen ) AND NOT( Source@[i<<1]^ IN Delimiters ) DO
			INC( i );
		END;
		IF p = ItemIndex THEN
			ASSIGN( Substring, OA( i-j-1, Source@[j<<1] ));
		END;
		IF SkipEmpty THEN
		   WHILE ( i < SourceLen ) AND ( Source@[i<<1]^ IN Delimiters ) DO
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
END ItemSMW;

PROCEDURE ToA( CONST Source : ARRAY OF WCHAR; CodePage : CARDINAL; OUT Destination : ARRAY OF CHAR ) : BOOLEAN; // CodePage can be 0
VAR
	f, l : CARDINAL;
BEGIN
	l := MIN2( LENGTH( Source ), HIGH( Destination )+1 );
	f := l;
	IF l > 0 THEN
		IF CodePage = 0 THEN
			CodePage := winnls.CP_ACP;
		END;
		l := winnls.WideCharToMultiByte( CodePage, 0, ADR( Source ), l, ADR( Destination ), HIGH( Destination ) + 1, NIL, NIL );
		ASSERT( l > 0 );
		IF l = 0 THEN
		   RETURN FALSE;
		END;
	END;
	IF l < HIGH( Destination ) THEN
		Destination[l] := CHAR( 0 );
	END;
	RETURN TRUE;
END ToA;

PROCEDURE ToAStream( CONST Source : ARRAY OF WCHAR; CodePage : CARDINAL; OUT Destination : ARRAY OF BYTE; OUT Consumed, Produced : CARDINAL ) : BOOLEAN; // returns if something consumed
BEGIN
	RETURN Languages.ToAStream( Source, CodePage, OUT Destination, OUT Consumed, OUT Produced );
END ToAStream;

PROCEDURE ToW( CONST Source : ARRAY OF CHAR; CodePage : CARDINAL; OUT Destination : ARRAY OF WCHAR ) : BOOLEAN; // CodePage can be 0
VAR
	f, l : CARDINAL;
BEGIN
	l := LENGTH( Source );
	f := l;
	IF l > 0 THEN
		IF CodePage = 0 THEN
			CodePage := winnls.CP_ACP;
		END;
		IF CodePage = winnls.CP_UTF8 THEN
			l := winnls.MultiByteToWideChar( CodePage, 0, ADR( Source ), l, ADR( Destination ), HIGH( Destination ) + 1 );
		ELSE
			l := winnls.MultiByteToWideChar( CodePage, winnls.MB_PRECOMPOSED, ADR( Source ), l, ADR( Destination ), HIGH( Destination ) + 1 );
		END;
		ASSERT( l > 0 );
		IF l = 0 THEN
		   RETURN FALSE;
		END;
	END;
	IF l < HIGH( Destination ) THEN
		Destination[l] := 0W;
	END;
	RETURN TRUE;
END ToW;

PROCEDURE ToWStream( CONST Source : ARRAY OF BYTE; CodePage : CARDINAL; OUT Destination : ARRAY OF WCHAR; OUT Consumed, Produced : CARDINAL ) : BOOLEAN; // returns if something consumed
BEGIN
	RETURN Languages.ToWStream( Source, CodePage, OUT Destination, OUT Consumed, OUT Produced );
END ToWStream;

PROCEDURE IsUTF8( CONST Source : ARRAY OF BYTE ) : BOOLEAN;
BEGIN
   RETURN Languages.IsUTF8( Source );
END IsUTF8;

CONST
	ConvStrW = L'0123456789ABCDEF';
	ConvStrA = C'0123456789ABCDEF';

PROCEDURE FromINT32W( _V : INT32; Base : CARDINAL; OUT S : ARRAY OF WCHAR ) : BOOLEAN; // returns OK
VAR
	B : CARD32;
	Buffer : ARRAY [0..35] OF WCHAR;
	i, l : CARDINAL;
	V : CARD32;
	sign : BOOLEAN;
BEGIN
	IF _V < 0 THEN
		sign := TRUE;
		V := CARD32(-(_V+1))+1;
	ELSE
		V := CARD32( _V );
		sign := FALSE;
	END;
	B := CARD32( MAX2( MIN2( Base, 16 ), 2 ));
	IF B <> Base THEN
		RETURN FALSE;
	END;
	i := 34;
	l := 0;
	LOOP
		Buffer[i] := ConvStrW[ V MOD B ];
		V := V DIV B;
		IF i = 0 THEN
			EXIT;
		ELSIF V = 0 THEN
			IF sign THEN
				DEC( i );
				INC( l );
				Buffer[i] := L'-';
			END;
			EXIT;
		ELSIF l > HIGH( S ) THEN
			RETURN FALSE;
		ELSE
			DEC( i );
			INC( l );
		END;
	END; // LOOP
	Buffer[35] := 0W;
	ASSIGN( S, ADR( Buffer )@[i<<1]^ );
	RETURN TRUE;
END FromINT32W;

PROCEDURE FromINT64W( _V : INT64; Base : CARDINAL; OUT S : ARRAY OF WCHAR ) : BOOLEAN; // returns OK
VAR
	B : CARD64;
	Buffer : ARRAY [0..67] OF WCHAR;
	i, l : CARDINAL;
	V : CARD64;
	sign : BOOLEAN;
BEGIN
	IF _V < 0 THEN
		sign := TRUE;
		V := CARD64(-(_V+1))+1;
	ELSE
		V := CARD64( _V );
		sign := FALSE;
	END;
	IF ( Base < 2 ) OR ( Base > 16 ) THEN
		RETURN FALSE;
	ELSE
		B := CARD64( Base);
	END;
	i := 66;
	l := 0;
	LOOP
		Buffer[i] := ConvStrW[ V MOD B ];
		V := V DIV B;
		IF i = 0 THEN
			EXIT;
		ELSIF V = 0 THEN
			IF sign THEN
				DEC( i );
				INC( l );
				Buffer[i] := L'-';
			END;
			EXIT;
		ELSIF l > HIGH( S ) THEN
			RETURN FALSE;
		ELSE
			DEC( i );
			INC( l );
		END;
	END; // LOOP
	Buffer[67] := 0W;
	ASSIGN( S, ADR( Buffer )@[i<<1]^ );
	RETURN TRUE;
END FromINT64W;

PROCEDURE FromCARD32W( V : CARD32; Base : CARDINAL; OUT S : ARRAY OF WCHAR ) : BOOLEAN; // returns OK
VAR
	B : CARD32;
	Buffer : ARRAY [0..35] OF WCHAR;
	i, l : CARDINAL;
BEGIN
	B := CARD32( MAX2( MIN2( Base, 16 ), 2 ));
	IF B <> Base THEN
		RETURN FALSE;
	END;
	i := 34;
	l := 0;
	LOOP
		Buffer[i] := ConvStrW[ V MOD B ];
		V := V DIV B;
		IF V = 0 THEN
			EXIT;
		ELSIF i = 0 THEN
			EXIT;
		ELSIF l > HIGH( S ) THEN
			RETURN FALSE;
		ELSE
			DEC( i );
			INC( l );
		END;
	END; // LOOP
	Buffer[35] := 0W;
	ASSIGN( S, ADR( Buffer )@[i<<1]^ );
	RETURN TRUE;
END FromCARD32W;

PROCEDURE FromCARD64A( V : CARD64; Base : CARDINAL; OUT S : ARRAY OF CHAR ) : BOOLEAN; // returns OK
VAR
	B : CARD64;
	Buffer : ARRAY [0..67] OF CHAR;
	i, l : CARDINAL;
BEGIN
	IF ( Base < 2 ) OR ( Base > 16 ) THEN
		RETURN FALSE;
	ELSE
		B := CARD64( Base);
	END;
	i := 66;
	l := 0;
	LOOP
		Buffer[i] := ConvStrA[ V MOD B ];
		V := V DIV B;
		IF V = 0 THEN
			EXIT;
		ELSIF i = 0 THEN
			EXIT;
		ELSIF l > HIGH( S ) THEN
			RETURN FALSE;
		ELSE
			DEC( i );
			INC( l );
		END;
	END; // LOOP
	Buffer[67] := 0C;
	ASSIGN( S, ADR( Buffer )@[i]^ );
	RETURN TRUE;
END FromCARD64A;

PROCEDURE FromCARD64W( V : CARD64; Base : CARDINAL; OUT S : ARRAY OF WCHAR ) : BOOLEAN; // returns OK
VAR
	B : CARD64;
	Buffer : ARRAY [0..67] OF WCHAR;
	i, l : CARDINAL;
BEGIN
	IF ( Base < 2 ) OR ( Base > 16 ) THEN
		RETURN FALSE;
	ELSE
		B := CARD64( Base);
	END;
	i := 66;
	l := 0;
	LOOP
		Buffer[i] := ConvStrW[ V MOD B ];
		V := V DIV B;
		IF V = 0 THEN
			EXIT;
		ELSIF i = 0 THEN
			EXIT;
		ELSIF l > HIGH( S ) THEN
			RETURN FALSE;
		ELSE
			DEC( i );
			INC( l );
		END;
	END; // LOOP
	Buffer[67] := 0W;
	ASSIGN( S, ADR( Buffer )@[i<<1]^ );
	RETURN TRUE;
END FromCARD64W;

PROCEDURE FromLONGREALW( V : LONGREAL; ExpFlag : BOOLEAN; OUT S : ARRAY OF WCHAR ) : BOOLEAN; // returns OK
BEGIN
   RETURN lrconv.LONGREALToStrW( V, -1, -1, ExpFlag, 0W, OUT S );
END FromLONGREALW;

PROCEDURE FromLONGREALExtW( V : LONGREAL; ValidCiphers, FractionPlaces : CARDINAL; ExpFlag : BOOLEAN; PointChar : WCHAR; OUT S : ARRAY OF WCHAR ) : BOOLEAN; // returns OK
BEGIN
   RETURN lrconv.LONGREALToStrW( V, ValidCiphers, FractionPlaces, ExpFlag, PointChar, OUT S );
END FromLONGREALExtW;

PROCEDURE FromErrorW( ErrorCode : CARDINAL; OUT S : ARRAY OF WCHAR );
VAR
	c : CARDINAL;
BEGIN
	c := windows.FormatMessageW( 
		windows.FORMAT_MESSAGE_FROM_SYSTEM,
		NIL,
		ErrorCode,
		LONGWORD( windows.MAKELANGID( windows.LANG_NEUTRAL, windows.SUBLANG_DEFAULT )),
		ADR( S ), HIGH( S )+1,
		NIL
	);
	IF c < HIGH( S ) THEN
		S[c] := 0W;
	END;
	c := LENGTH( S );
	WHILE ( c > 0 ) AND ( S[c-1] < 32W ) DO
		// hidden characters, FormatMessage returns in some cases CR at the end of string, trim them
		S[c-1] := 0W;
		DEC( c );
	END; // WHILE
END FromErrorW;

PROCEDURE ToINT32W( CONST String : ARRAY OF WCHAR; Base : CARDINAL; OUT V : INT32 ) : BOOLEAN;
VAR
	LV : CARD64;
BEGIN
	IF ToCARD64MW( LENGTH( String ), ADR( String ), Base, OUT LV ) <> tcrSuccess THEN
		RETURN FALSE;
	ELSIF LV > MAX( CARD32 ) THEN
		RETURN FALSE;
	ELSE
		V := INT32( LV );
		RETURN TRUE;
	END;
END ToINT32W;

PROCEDURE ToINT64W( CONST String : ARRAY OF WCHAR; Base : CARDINAL; OUT V : INT64 ) : BOOLEAN;
VAR
	LV : CARD64;
BEGIN
	IF ToCARD64MW( LENGTH( String ), ADR( String ), Base, OUT LV ) <> tcrSuccess THEN
		RETURN FALSE;
	ELSIF LV > MAX( INT64 ) THEN
		RETURN FALSE;
	ELSE
		V := INT64( LV );
		RETURN TRUE;
	END;
END ToINT64W;

PROCEDURE ToCARD32W( CONST String : ARRAY OF WCHAR; Base : CARDINAL; OUT V : CARD32 ) : BOOLEAN;
VAR
	LV : CARD64;
BEGIN
	IF ToCARD64MW( LENGTH( String ), ADR( String ), Base, OUT LV ) <> tcrSuccess THEN
		RETURN FALSE;
	ELSIF LV > MAX( CARD32 ) THEN
		RETURN FALSE;
	ELSE
		V := CARD32( LV );
		RETURN TRUE;
	END;
END ToCARD32W;

PROCEDURE ToCARD64W( CONST String : ARRAY OF WCHAR; Base : CARDINAL; OUT V : CARD64 ) : BOOLEAN;
VAR
	LV : CARD64;
BEGIN
	IF ToCARD64MW( LENGTH( String ), ADR( String ), Base, OUT LV ) <> tcrSuccess THEN
		RETURN FALSE;
	ELSE
		V := LV;
		RETURN TRUE;
	END;
END ToCARD64W;

PROCEDURE ToCARD64MW( StringLen : CARDINAL; CONST String : POINTER TO WCHAR; Base : CARDINAL; OUT V : CARD64 ) : TConversionResult;
VAR
	Cipher : CARDINAL;
	i : CARDINAL;
	nc : CARD64;
BEGIN
	V := 0;
	IF StringLen = 0 THEN
		RETURN tcrEmptyString;
	END;
	CASE String^ OF
	| L'+' : i := 1; 
	| L'-' : i := 1;
	ELSE
		i := 0;
	END;
	FOR i := i TO StringLen-1 DO
		CASE String@[i<<1]^ OF
		| L'0'..L'9' :
			Cipher := ORD( String@[i<<1]^ ) - ORD( L'0' );
		| L'a'..L'f' :
			Cipher := ORD( String@[i<<1]^ ) - ORD( L'a' ) + 10;
		| L'A'..L'F' :
			Cipher := ORD( String@[i<<1]^ ) - ORD( L'A' ) + 10;
		ELSE
			Cipher := Base;
		END;
		IF Cipher >= Base THEN
			RETURN tcrCipherOutOfBase;
		END;
		nc := CARD64( Base ) * V;
		IF nc < V THEN
			RETURN tcrNumberTooLong;
		ELSE
			V := nc + CARD64( Cipher );
		END;
	END; // FOR
	IF String@[0]^ = L'-' THEN
		V := -V;
	END;
	RETURN tcrSuccess;
END ToCARD64MW;

PROCEDURE ToLONGREALW( CONST String : ARRAY OF WCHAR; OUT V : LONGREAL ) : BOOLEAN;
BEGIN
	RETURN lrconv.StrToLONGREALW( String, OUT V );
END ToLONGREALW;

PROCEDURE LowsA( REF S : ARRAY OF CHAR );
BEGIN
	windows.CharLowerBuffA( ADR( S ), LENGTH( S ));
END LowsA;

PROCEDURE CapsA( REF S : ARRAY OF CHAR );
BEGIN
	windows.CharUpperBuffA( ADR( S ), LENGTH( S ));
END CapsA;

PROCEDURE LowsW( REF S : ARRAY OF WCHAR );
BEGIN
	windows.CharLowerBuffW( ADR( S ), LENGTH( S ));
END LowsW;

PROCEDURE CapsW( REF S : ARRAY OF WCHAR );
BEGIN
	windows.CharUpperBuffW( ADR( S ), LENGTH( S ));
END CapsW;

END Strings.
