MODULE TRunInPipe;

IMPORT
  FIOO,
  FSO,
  IOO,
  Languages,
  StringsO,
  Sync,
  TextReader,
  TextWriter;

#save, call( convention => cdecl )
PROCEDURE wmain();
#restore
VAR
  out : FIOO.TPFileStream;
  s : StringsO.CString;
  tr : TextReader.CTextReader;
  tw : TextWriter.TPTextWriter := TextWriter.stdout();
BEGIN
  TRY
    FSO.RunProgramInPipe( L"C:\Program Files\Microsoft Visual Studio 8\VC\bin\dumpbin.exe", L"/directives ~Debug/Text.lib", NIL, OUT out );

    tr.Stream := out;
    tr.Encoding := Languages.cp_Console();
    WHILE tr.ReadLine( OUT s, Sync.INFINITE_TIME, TRUE ) IN Sync.arsCompletions DO
      tw^.Write( s, TRUE );
    END; // while

  CATCH e : IOO.CIOException DO
    tw^.WriteExc( e, TRUE );
  END;
END wmain;

END TRunInPipe.