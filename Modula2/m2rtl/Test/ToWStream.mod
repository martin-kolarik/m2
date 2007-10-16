MODULE ToWStream;

IMPORT
  windows,
  Strings,
  Languages,
  winnls;

  #save, call( entry_point => on )
  PROCEDURE wmain() : INTEGER;
  #restore
  CONST
    s1250 = C'Aøè';
    sU = L'Aøè';
  VAR
    c, d : CARDINAL;
    sa : ARRAY [0..127] OF CHAR;
    sw : ARRAY [0..127] OF WCHAR;
  BEGIN
    Strings.ToW( s1250, 0, OUT sw );
    Languages.ToWStream( sU, winnls.CP_UTF16, OUT sw, OUT c, OUT d );
    Languages.ToWStream( s1250, winnls.CP_ACP, OUT sw, OUT c, OUT d );
    Languages.ToWStream( s1250, 1250, OUT sw, OUT c, OUT d );
    Strings.ToA( sw, winnls.CP_UTF8, OUT sa );
    Languages.ToWStream( OA( LENGTH( sa )-1, ADR( sa )), winnls.CP_UTF8, OUT sw, OUT c, OUT d ); // c should be 5, d should be 3
    Languages.ToWStream( OA( LENGTH( sa )-2, ADR( sa )), winnls.CP_UTF8, OUT sw, OUT c, OUT d ); // last UTF8 is incomplete, c should be 3, d should be 2
    RETURN 0;
  END wmain;

BEGIN
END ToWStream.