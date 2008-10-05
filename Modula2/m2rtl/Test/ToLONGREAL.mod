MODULE ToLONGREAL;

IMPORT
  Strings;

  #save, call( convention => cdecl )
  PROCEDURE wmain03() : INTEGER;
  #restore
  VAR
    r : LONGREAL;
    b : BOOLEAN;
  BEGIN

		b := Strings.ToLONGREALW( L'', OUT r );
		b := Strings.ToLONGREALW( L'+', OUT r );
		b := Strings.ToLONGREALW( L'-', OUT r );
		b := Strings.ToLONGREALW( L'1', OUT r );
		b := Strings.ToLONGREALW( L'+1', OUT r );
		b := Strings.ToLONGREALW( L'-1', OUT r );
		b := Strings.ToLONGREALW( L'10', OUT r );
		b := Strings.ToLONGREALW( L'+10', OUT r );
		b := Strings.ToLONGREALW( L'-10', OUT r );
		b := Strings.ToLONGREALW( L'.1', OUT r );
		b := Strings.ToLONGREALW( L'+.1', OUT r );
		b := Strings.ToLONGREALW( L'-.1', OUT r );
		b := Strings.ToLONGREALW( L'.11', OUT r );
		b := Strings.ToLONGREALW( L'+.11', OUT r );
		b := Strings.ToLONGREALW( L'-.11', OUT r );
		b := Strings.ToLONGREALW( L'0.1', OUT r );
		b := Strings.ToLONGREALW( L'+0.1', OUT r );
		b := Strings.ToLONGREALW( L'-0.1', OUT r );
		b := Strings.ToLONGREALW( L'0.11', OUT r );
		b := Strings.ToLONGREALW( L'+0.11', OUT r );
		b := Strings.ToLONGREALW( L'-0.11', OUT r );
		b := Strings.ToLONGREALW( L'0.1E', OUT r );
		b := Strings.ToLONGREALW( L'0.1E+', OUT r );
		b := Strings.ToLONGREALW( L'0.1E-', OUT r );
		b := Strings.ToLONGREALW( L'0.1E2', OUT r );
		b := Strings.ToLONGREALW( L'0.1E+2', OUT r );
		b := Strings.ToLONGREALW( L'0.1E-2', OUT r );
		
    RETURN 0;
  END wmain03;

BEGIN
END ToLONGREAL.