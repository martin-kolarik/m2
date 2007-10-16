MODULE formalsetof;

IMPORT
  Strings,
  StringsO;

TYPE
  TEnum = ( Item1, Item2 );
  
PROCEDURE X( W1 : SET OF WCHAR; W2 : SET OF TEnum );
BEGIN
END X;

PROCEDURE Y();
TYPE
  TW = SET OF WCHAR;
VAR
  S : StringsO.CString;
  s : ARRAY [0..1] OF WCHAR;
BEGIN
  X( TW{L'A', L'B'}, {Item1} );
  X( WCHAR{L'A', L'B'}, {Item1, Item2} );
  Strings.ItemSW( L'A', Strings.WCHARS{L'A'}, 0, 0, OUT s );
  S.ItemSOA( StringsO.WCHARS{L'A'}, 0, 0, OUT s );
END Y;

END formalsetof.