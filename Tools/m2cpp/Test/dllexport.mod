MODULE Dllexport;

#name( decoration => c )

#save, call( convention => stdcall ), option( dll_export => on )
PROCEDURE A( v : CARDINAL ) : CARDINAL;
VAR
   Number : ARRAY[0..255] OF WCHAR;
   Length : CARDINAL := HIGH( Number ) + 1;
   Valid : BOOLEAN;
BEGIN
  RETURN 0;
END A;
#restore

END Dllexport.