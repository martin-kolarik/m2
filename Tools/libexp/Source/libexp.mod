MODULE libexp;

IMPORT
   FIO,
   FIOO,
   FSO,
   IOO,
   StringsO,
   Sync,
   TextReader,
   TextWriter;

TYPE
  TParamStringArray  = ARRAY [0..0] OF POINTER TO ARRAY [0..511] OF WCHAR;
  TPParamStringArray = POINTER TO TParamStringArray;
  
# save, call( convention => cdecl )
PROCEDURE wmain( argc : INTEGER; argp : TPParamStringArray; enpv : TPParamStringArray ) : INTEGER;
# restore
LABEL
   Error;
VAR
   DumpBin : FIO.PathStrW := L"dumpbin.exe";
   errout : TextWriter.TPTextWriter := TextWriter.errout();
   i : INTEGER;
   Line : StringsO.CString;
   Result : FIOO.TPFileStream;
   S : StringsO.CString;
   stdout : TextWriter.TPTextWriter := TextWriter.stdout();
   tr : TextReader.CTextReader;
BEGIN
   i := 1;
   WHILE i < argc DO
      IF ( argp^[i]^[0] = L'/' ) OR ( argp^[i]^[0] = L'-' ) THEN // option
         CASE argp^[i]^[1] OF
         | L'h' :
            GOTO Error;
         | L'p' :
            INC( i );
            IF i = argc THEN
               errout^.WriteOA( L"libexp: missing path-to-dumpbin", TRUE );
               GOTO Error;
            END;
            DumpBin := argp^[i]^;
         ELSE
            errout^.WriteOA( L"libexp: invalid option ", FALSE ); errout^.WriteOA( argp^[i]^, TRUE );
            GOTO Error;
         END;

      ELSE // files
         S.AppendOA( L' "' );
         S.AppendOA( argp^[i]^ );
         S.AppendOA( L'"' );

      END;
      INC( i );
   END; // WHILE

   S.PrependOA( L"/directives" );

   TRY   
      FSO.RunProgramInPipe( DumpBin, OA( S.Length-1, S.rawData ), NIL, OUT Result );
   CATCH e : IOO.CIOException DO
      errout^.WriteOA( L"libexp: running dumpbin failed: ", FALSE ); 
      errout^.WriteExc( e, TRUE );
      GOTO Error;
   END;
   
   stdout^.WriteOA( L"EXPORTS", TRUE );

   tr.Stream := Result;
   WHILE tr.ReadLine( OUT Line, Sync.INFINITE_TIME, TRUE ) = Sync.arCompleted DO
      i := Line.IndexOfOA( L"fatal error", 0 );
      IF i <> -1 THEN
         errout^.WriteOA( L"libexp: error during parsing result line: ", FALSE ); 
         errout^.Write( Line, TRUE ); 
         GOTO Error;
      END;
      i := Line.IndexOfOA( L"/EXPORT:", 0 );
      IF i <> -1 THEN
        Line.Remove( 0, i+8 );
        i := Line.IndexOfOA( L",DATA", 0 );
        IF i <> -1 THEN
          Line.Remove( i, -1 );
        END;
        stdout^.WriteOA( L"    ", FALSE ); stdout^.Write( Line, TRUE );
      END;
   END; // WHILE
   Result^.Close( FALSE );

   RETURN 0;

Error:
   errout^.WriteOA( L"  usage: libexp [-p path-to-dumbin] <list of lib files> [-h]", TRUE );
   RETURN -1;
END wmain;
  
END libexp.

