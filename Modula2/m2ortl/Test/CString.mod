MODULE CString;

IMPORT
  StringsO;

  #save, call( convention => cdecl )
  PROCEDURE wmain05() : INTEGER;
  #restore
  CONST
    cSA = C'KonstantnÌ ¯etÏzec ANSI';
    cSW = L'KonstantnÌ ¯etÏzec UNIC';
  VAR
    SA : ARRAY [0..255] OF CHAR;
    SW : ARRAY [0..255] OF WCHAR;
    S1, S2, Sast, Sabcd : StringsO.CString;
    SA1 : ARRAY [0..1] OF StringsO.CString;
    SA2 : ARRAY [0..5] OF StringsO.CString;
  VAR
    p, i : CARDINAL;
    t : TRISTATE;
    b : BOOLEAN;
  BEGIN
    // indexes
    IF S1[0] = L'A' THEN END;
    S1[0] := L'B';
    S2[10] := L'C';

    // operators
    // S1 := S1 + S2;
    
    // conversions
    S1.FromOA( L'Text to test »ÿç' );
    S1.ToOAA( 0, OUT SA, OUT p );
    S2.FromOAA( 0, C'ANSI text to test »ÿç' );
    S2.ToOA( OUT SW );
    
    // information
    S1.FromOA( L'Text to compare' );
    S2.FromOA( L'Text to compare strings' );
    b := S1.Equals( S2 );
    t := S1.Compare( S2 );
    S1.AppendOA( L' strings' );
    b := S1.Equals( S2 );
    t := S1.Compare( S2 );
    
    // construction
    S1.Clear(); S1.AppendOA( L'ABCD' );
    S1.Clear(); S1.PrependOA( L'ABCD' );
    S1.AppendOA( L'*ABCD' );
    S1.Remove( 0, 4 );
    S1.PrependOA( L'ABCD' );
    S1.Remove( 4, 1 );
    S1.Remove( 4, 150 );
    
    Sast.FromOA( L'*' );
    Sabcd.FromOA( L'ABCD' );
    S1.Clear(); S1.Append( Sabcd );
    S1.Clear(); S1.Prepend( Sabcd );
    S1.Append( Sast ); S1.Append( Sabcd );
    S1.Remove( 0, 4 );
    S1.Prepend( Sabcd );
    S1.Remove( 4, 1 );
    S1.Remove( 4, 150 );
    
    // analysis
    S1.FromOA( L' Item1 Item2 Item3;Item4  ; ; ; ; ; ; ; ; Item5 ' );
    S2.FromOA( L'Item1 Item2' );
    i := S1.Split( L' ;', 0, FALSE, OUT p, OUT SA1 );
    i := S1.Split( L' ;', i, FALSE, OUT p, OUT SA1 );
    i := S1.Split( L' ;', i, FALSE, OUT p, OUT SA1 );
    S2.Split( L' ;', 0, FALSE, OUT p, OUT SA1 );
    S1.Split( L' ;', 0, FALSE, OUT p, OUT SA2 );
    S2.Split( L' ;', 0, FALSE, OUT p, OUT SA2 );

    S1.SubstringOA( 1, 5, OUT SW );
    S1.SubstringOA( 0, -1, OUT SW );
    S1.SubstringOA( 0, S1.Length, OUT SW );
    S1.SubstringOA( 100, 10, OUT SW );
    S1.SubstringOA( 1, 11, OUT SW );
    S1.Substring( 1, 5, OUT S2 );
    S1.Substring( 0, -1, OUT S2 );
    S1.Substring( 0, S1.Length, OUT S2 );
    S1.Substring( 100, 10, OUT S2 );
    S1.Substring( 1, 11, OUT S2 );

    i := S1.IndexOfOA( L';', 0 );
    i := S1.IndexOfOA( L'ABC', 0 );
    i := S1.IndexOfOA( L'IteABC', 0 );
    i := S1.IndexOfOA( L'Item', 0 );
    i := S1.IndexOfOA( L'Item', 1 );
    i := S1.IndexOfOA( L'Item', 2 );
    S2.FromOA( L'ItItem1 ItItem2' );
    i := S2.IndexOfOA( L'Item', 0 );
    i := S2.IndexOfOA( L'Item', i+1 );
    S2.FromOA( L'ItItItEm' );
    i := S2.IndexOfOA( L'ItItEm', 0 );
    
    RETURN 0;
  END wmain05;

BEGIN
END CString.