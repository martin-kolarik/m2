MODULE TBase64D;

IMPORT
	cphcommon;
  
#save, call( convention => cdecl )
PROCEDURE wmain02() : INTEGER;
#restore
VAR
   c : CARDINAL;
   ba : ARRAY [0..255] OF CHAR;
   wa : ARRAY [0..255] OF WCHAR;
BEGIN
   cphcommon.FromBASE64( W'c3VyZS4=', OUT ba, OUT c ); // sure.
   cphcommon.FromBASE64( W'c3VyZQ==', OUT ba, OUT c ); // sure
   cphcommon.FromBASE64( W'c3Vy', OUT ba, OUT c ); // sur
   cphcommon.FromBASE64( W'c3U=', OUT ba, OUT c ); // su

   cphcommon.ToBASE64( C'sure.', OUT wa );
   cphcommon.ToBASE64( C'sure', OUT wa );
   cphcommon.ToBASE64( C'sur', OUT wa );
   cphcommon.ToBASE64( C'su', OUT wa );

	RETURN 0;
END wmain02;

END TBase64D.