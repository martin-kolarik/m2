MODULE StringsProc;

IMPORT
  Strings;

  #save, call( entry_point => on )
  PROCEDURE wmain() : INTEGER;
  #restore
  VAR
    SA : ARRAY [0..255] OF CHAR;
    S1, S2, Sast, Sabcd : ARRAY [0..511] OF WCHAR;
  VAR
    i : CARDINAL;
    b : BOOLEAN;
  BEGIN
    // conversions
    S1 := L'Text to test »ÿç';
    Strings.ToA( S1, 0, OUT SA );
    Strings.ToW( SA, 0, OUT S2 );
    
    // information
    // ??? t := S1.Compare( S2 );
    
    // construction
    S1 := L''; Strings.AppendW( REF S1, L'ABCD' );
    S1 := L''; Strings.PrependW( REF S1, L'ABCD' );
    Strings.AppendW( REF S1, L'*ABCD' );
    Strings.RemoveW( REF S1, 0, 4 );
    Strings.PrependW( REF S1, L'ABCD' );
    Strings.RemoveW( REF S1, 4, 1 );
    Strings.RemoveW( REF S1, 4, 150 );
    
    Strings.ConcatW( OUT S2, L"", L"78910" );
    Strings.ConcatW( OUT S2, L"123456", L"78910" );
    Strings.ConcatW( OUT S2, L"123456", L"" );
    
    Strings.InsertW( REF S1, 2, L"*+*" );
    Strings.InsertW( REF S1, 0, L"" );
    Strings.InsertW( REF S1, 1000, L"" );
    Strings.InsertW( REF S1, 0, L"--" );
    Strings.InsertW( REF S1, 1000, L"--" );
    Strings.InsertW( REF S1, 100, L"--" );
    
    Strings.ReplaceW( REF S1, L"*", L"" );
    Strings.ReplaceW( REF S1, L"+", L"*+**+**+*" );
    Strings.ReplaceW( REF S1, L"*+*", L"%" );
    Strings.ReplaceW( REF S1, L"%", L"11222255222211" );
    
    b := Strings.StartsWithW( S1, L'--' );
    b := Strings.StartsWithW( S1, L'ABCD' );
    b := Strings.EndsWithW( S1, L'--' );
    b := Strings.EndsWithW( S1, L'ABCD' );
    
    Sast := L'*';
    Sabcd := L'ABCD';
    S1 := L''; Strings.AppendW( REF S1, Sabcd );
    S1 := L''; Strings.PrependW( REF S1, Sabcd );
    Strings.AppendW( REF S1, Sast ); Strings.AppendW( REF S1, Sabcd );
    Strings.RemoveW( REF S1, 0, 4 );
    Strings.PrependW( REF S1, Sabcd );
    Strings.RemoveW( REF S1, 4, 1 );
    Strings.RemoveW( REF S1, 4, 150 );
    Strings.RemoveW( REF S1, 150, 150 );
    
    // analysis
    S1 := L' Item1 Item2 Item3;Item4  ; ; ; ; ; ; ; ; Item5 ';
    i := Strings.ItemW( S1, WCHAR{L';'}, 0, 1, OUT S2 );
    i := Strings.ItemW( S1, WCHAR{L';', L' '}, 0, 2, OUT S2 );
    S2 := L'Item1 Item2';
    i := Strings.ItemW( S1, WCHAR{L';', L' '}, 0, 20, OUT S2 );
    // i := S1.Split( L' ;', 0, OUT p, OUT SA1 );
    // i := S1.Split( L' ;', i, OUT p, OUT SA1 );
    // i := S1.Split( L' ;', i, OUT p, OUT SA1 );
    // S2.Split( L' ;', 0, OUT p, OUT SA1 );
    // S1.Split( L' ;', 0, OUT p, OUT SA2 );
    // S2.Split( L' ;', 0, OUT p, OUT SA2 );

    Strings.SubstringW( S1, 1, 5, OUT S2 );
    Strings.SubstringW( S1, 0, -1, OUT S2 );
    Strings.SubstringW( S1, 0, LENGTH( S1 ), OUT S2 );
    Strings.SubstringW( S1, 100, 10, OUT S2 );
    Strings.SubstringW( S1, 1, 11, OUT S2 );

    i := Strings.IndexOfW( S1, L';', 0 );
    i := Strings.IndexOfW( S1, L'ABC', 0 );
    i := Strings.IndexOfW( S1, L'IteABC', 0 );
    i := Strings.IndexOfW( S1, L'Item', 0 );
    i := Strings.IndexOfW( S1, L'Item', 1 );
    i := Strings.IndexOfW( S1, L'Item', 2 );
    S2 := L'ItItem1 ItItem2';
    i := Strings.IndexOfW( S2, L'Item', 0 );
    i := Strings.IndexOfW( S2, L'Item', i+1 );
    S2 := L'ItItItEm';
    i := Strings.IndexOfW( S2, L'ItItEm', 0 );
    
    S2 := L'ItItItEm';
    Strings.PadRightW( REF S2, 100, L'*' );
    S2 := L'ItItItEm';
    Strings.PadRightW( REF S2, 100, L'@#' );
    S2 := L'ItItItEm';
    Strings.PadRightW( REF S2, 100, L'@#*' );
    S2 := L'ItItItEm';
    Strings.PadLeftW( REF S2, 10, L'*' );
    S2 := L'ItItItEm';
    Strings.PadLeftW( REF S2, 10, L'@#' );
    S2 := L'ItItItEm';
    Strings.PadLeftW( REF S2, 10, L'@#*' );
    S2 := L'ItItItEm';
    Strings.PadLeftW( REF S2, 100, L'*' );
    S2 := L'ItItItEm';
    Strings.PadLeftW( REF S2, 100, L'@#' );
    S2 := L'ItItItEm';
    Strings.PadLeftW( REF S2, 100, L'@#*' );
    
    S1 := L'    ;g h h h ; ';
    Strings.TrimW( REF S1 );
    S1 := L'    ;g h h h ; ';
    Strings.TrimDelimitersW( REF S1, WCHAR{L' ', L';'} );
    S1 := L';g h h h ;';
    Strings.TrimW( REF S1 );
    S1 := L'';
    Strings.TrimW( REF S1 );
    
    S1 := L'aBaBaBa';
    CAP( S1 );
    LOW( S1 );
    
    RETURN 0;
  END wmain;

BEGIN
END StringsProc.