MODULE TLogger;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   Exceptions,
   log,
   Strings,
   Sync,
   test,
   testimpl;
  
(*===========================================================================*)

CLASS CTest IMPLEMENTS test.ITest;
   PRIVATE VAR
      Host : test.TPHost := NIL;

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
END CTest;

(*---------------------------------------------------------------------------*)

TYPE
   TPTest = POINTER TO CTest;
VAR
   Test : CTest;

(*===========================================================================*)

CLASS IMPLEMENTATION CTest;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   CONST
      Data = C"Ahoj pidiku";
   VAR
      i : INTEGER;
      l : log.TPBufferedLogger := log.logger();
      s : ARRAY [0..1023] OF WCHAR;
   BEGIN
      SELF.Host := Host;
      l^.AddOutput( Host^.Output );
      
      //==========
      Host^.StartPhase( L"All formatting functions" );
      
      l^.LogS( log.lcInfo, 0, L"Prefix", L"String1" );
      l^.LogSS( log.lcWarning, 0, L"Prefix", L"String1", L"String2" );
      l^.LogSSC( log.lcError, 0, L"Prefix", L"String1", L"String2", 666 );
      l^.LogSC( log.lcSysError, 0, L"Prefix", L"String1", 666 );
      l^.LogSCC( log.lcInfo, 0, L"Prefix", L"String1", 7, 666 );
      l^.LogSH( log.lcWarning, 0, L"Prefix", L"String1", 32768+1 );
      l^.LogSP( log.lcError, 0, L"Prefix", L"String1", 12345678 );
      l^.LogSCP( log.lcSysError, 0, L"Prefix", L"String1", 666, 12345679 );
      l^.LogSHP( log.lcInfo, 0, L"Prefix", L"String1", 32768+1, 12345679 );
      l^.LogSB( log.lcWarning, 0, L"Prefix", L"String1", ADR( Data ), SIZE( Data ));
      l^.LogSCB( log.lcError, 0, L"Prefix", L"String1", 666, ADR( Data ), SIZE( Data ));
      l^.LogSSS( log.lcSysError, 0, L"Prefix", L"String1", L"String2", L"String3" );
      l^.LogSSSS( log.lcInfo, 0, L"Prefix", L"String1", L"String2", L"String3", L"String4" );
  
      l^.LogSE( log.lcWarning, 0, L"Prefix", L"String1", 5 );
      l^.LogSR( log.lcError, 0, L"Prefix", L"String1", Sync.arTimeout );
      l^.LogExc( log.lcSysError, 0, L"Prefix", Exceptions.Modula2Exception( NIL, L"Logger Test", L"A message to exception.", Exceptions.mexMethodNotImplemented ));
      l^.LogFilePos( log.lcInfo, 0, L"Prefix", L"FilePath\File.txt", L"String1", 123, 10 );
      l^.LogFilePos( log.lcWarning, 0, L"Prefix", L"FilePath\File.txt", L"String1", 0, 10 );
      l^.LogFilePos( log.lcError, 0, L"Prefix", L"FilePath\File.txt", L"String1", 123, 0 );
      l^.LogFilePos( log.lcSysError, 0, L"Prefix", L"FilePath\File.txt", L"String1", 0, 0 );

      Host^.StopPhase();

      //==========
      Host^.StartPhase( L"None output" );
      
      l^.Output := log.outsNone;
      l^.LogS( log.ldMessage, 0, L"Output", L"Text nowhere" );
      
      Host^.StopPhase();
      
      //==========
      Host^.StartPhase( L"File output (d:\test.log)" );
      
      l^.Output := log.outsFile;
      l^.SetLogFile( L"d:\test.log" );
      l^.LogS( log.ldMessage, 0, L"Output", L"Text in file only" );
      
      Host^.StopPhase();
      
      //==========
      Host^.StartPhase( L"Kernel output" );
      
      l^.Output := log.outsKernel;
      l^.LogS( log.ldMessage, 0, L"Output", L"Text in kernel only" );
      
      Host^.StopPhase();
      
      //==========
      Host^.StartPhase( L"Kernel and file output" );
      
      l^.Output := log.outsKernel + log.outsFile;
      l^.LogS( log.ldMessage, 0, L"Output", L"Text in kernel and file" );
      
      Host^.StopPhase();

      //==========
      Host^.StartPhase( L"Dump buffer" );
      
      l^.Output := log.outsNone;

      FOR i := 0 TO l^.BufferCount-1 DO
         l^.BufferGetItem( i, OUT s );
         l^.LogS( log.ldTrace, 0, L"Output", s );
      END;
      
      Host^.StopPhase();

      //==========
      Host^.StartPhase( L"Limiting levels" );
      
      l^.Output := log.outsKernel;

      l^.Level := log.lcInfo;
      l^.LogS( log.lcSysError, 0, L"Level", L"1 Should be visible" );
      l^.LogS( log.lcError, 0, L"Level", L"1 Should be visible" );
      l^.LogS( log.lcWarning, 0, L"Level", L"1 Should be visible" );
      l^.LogS( log.lcInfo, 0, L"Level", L"1 Should be visible" );
      
      l^.Level := log.lcWarning;
      l^.LogS( log.lcSysError, 0, L"Level", L"2 Should be visible" );
      l^.LogS( log.lcError, 0, L"Level", L"2 Should be visible" );
      l^.LogS( log.lcWarning, 0, L"Level", L"2 Should be visible" );
      l^.LogS( log.lcInfo, 0, L"Level", L"2 Should NOT be visible" );
      
      l^.Level := log.lcError;
      l^.LogS( log.lcSysError, 0, L"Level", L"3 Should be visible" );
      l^.LogS( log.lcError, 0, L"Level", L"3 Should be visible" );
      l^.LogS( log.lcWarning, 0, L"Level", L"3 Should NOT be visible" );
      l^.LogS( log.lcInfo, 0, L"Level", L"3 Should NOT be visible" );
      
      l^.Level := log.lcSysError;
      l^.LogS( log.lcSysError, 0, L"Level", L"4 Should be visible" );
      l^.LogS( log.lcError, 0, L"Level", L"4 Should NOT be visible" );
      l^.LogS( log.lcWarning, 0, L"Level", L"4 Should NOT be visible" );
      l^.LogS( log.lcInfo, 0, L"Level", L"4 Should NOT be visible" );
      
      Host^.StopPhase();

      //==========
      Host^.StartPhase( L"Filtering by bits" );
      
      l^.AllowedFilterDataBits := 80000005H;
      l^.Level := log.lcInfo;
      
      l^.LogS( log.lcWarning, 10000000H, L"Bits", L"Should NOT be visible" );
      l^.LogS( log.lcWarning, 01000000H, L"Bits", L"Should NOT be visible" );
      l^.LogS( log.lcWarning, 00000001H, L"Bits", L"Should be visible 1" );
      l^.LogS( log.lcWarning, 00000004H, L"Bits", L"Should be visible 2" );
      l^.LogS( log.lcWarning, 00000002H, L"Bits", L"Should NOT be visible" );
      l^.LogS( log.lcWarning, 00000008H, L"Bits", L"Should NOT be visible" );

      //==========
      Host^.StartPhase( L"Chaining of appenders" );
      
      //==========
      Host^.StartPhase( L"Creation and deletion of IAppender -- controlled" );
      
      //==========
      Host^.StartPhase( L"Creation and deletion of IAppender -- automatic" );
      
      l^.RemoveOutput( Host^.Output );
      RETURN test.trSuccess;
   END Run;
   
(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"Logger", ADR( Test ));
END CTest;

(*===========================================================================*)

END TLogger.