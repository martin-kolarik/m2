MODULE TRunInPipe;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;
FROM Exceptions IMPORT
   TestIfCatched, RetrieveException;

IMPORT
  FIOO,
  FSO,
  IOO,
  Languages,
  log,
  StringsO,
  Sync,
  test,
  testimpl,
  TextReader,
  TextWriter;

(*===========================================================================*)

CLASS CRunInPipe IMPLEMENTS test.ITest;
   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
END CRunInPipe;

(*---------------------------------------------------------------------------*)

VAR
   RunInPipe : CRunInPipe;

(*===========================================================================*)

CLASS IMPLEMENTATION CRunInPipe;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   VAR
     out : FIOO.TPFileStream;
     s : StringsO.CString;
     tr : TextReader.CTextReader;
   BEGIN
     TRY
       FSO.RunProgramInPipe( L"C:\Program Files\Microsoft Visual Studio 8\VC\bin\dumpbin.exe", L"/directives ~Debug/Text.lib", NIL, OUT out );

       tr.Stream := out;
       tr.Encoding := Languages.cp_Console();
       WHILE tr.ReadLine( OUT s, Sync.FOREVER, TRUE ) IN Sync.arsCompletions DO
         Host^.Log^.LogS( log.lcInfo, 0, L"", OAsz( s.Data ));
       END; // while

     CATCH e : IOO.CIOException DO
       Host^.Log^.LogExc( log.lcError, 0, L"", e );
       RETURN test.trFailure;
     END;
     
     RETURN test.trSuccess;
   END Run;

(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"Run in pipe", ADR( RunInPipe ));
END CRunInPipe;
   
(*===========================================================================*)

END TRunInPipe.