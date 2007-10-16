MODULE charsetw;

  PROCEDURE Test;
  TYPE
    CHARSETW = SET OF [WCHAR(0)..WCHAR(127)];
  VAR
    Ignore : CHARSETW;
  BEGIN
    INCL( Ignore, L' ' );
    INCL( Ignore, WCHAR( 9 )); INCL( Ignore, WCHAR( 10 )); INCL( Ignore, WCHAR( 13 )); 
  END Test;

BEGIN
END charsetw.