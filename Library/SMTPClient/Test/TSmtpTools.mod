MODULE TSmtpTools;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   log,
   MIME,
   SmtpTools,
   StringsO,
   test,
   testimpl;
  
(*===========================================================================*)

CLASS CTest IMPLEMENTS test.ITest;
   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
END CTest;

(*===========================================================================*)

VAR
   TestSmtpTools : CTest;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CTest;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   CONST
      FOLD = 13W + 10W + 32W;
   VAR
      containsSpaces : BOOLEAN;
      header : StringsO.CString;
      neededEncoding : SmtpTools.THeaderEncoding;
      output : StringsO.CString;
      s : StringsO.CString;
   BEGIN
      Host^.StartPhase( L"AnalyzeHeaderEncoding (ASCII 7, no spaces, no escapes)" );
      s.FromOA( L"nospaces_ascii_only" );
      SmtpTools.AnalyzeHeaderEncoding( s, OUT neededEncoding, OUT containsSpaces );
      IF neededEncoding <> SmtpTools.HeaderEncodingPlain THEN
         Host^.StopPhaseWithResult( FALSE );
      ELSIF containsSpaces THEN
         Host^.StopPhaseWithResult( FALSE );
      ELSE
         Host^.StopPhaseWithResult( TRUE );
      END;
      
      Host^.StartPhase( L"AnalyzeHeaderEncoding (ASCII 7, spaces, no escapes)" );
      s.FromOA( L"spaces ascii only" );
      SmtpTools.AnalyzeHeaderEncoding( s, OUT neededEncoding, OUT containsSpaces );
      IF neededEncoding <> SmtpTools.HeaderEncodingPlain THEN
         Host^.StopPhaseWithResult( FALSE );
      ELSIF NOT containsSpaces THEN
         Host^.StopPhaseWithResult( FALSE );
      ELSE
         Host^.StopPhaseWithResult( TRUE );
      END;
      
      Host^.StartPhase( L"AnalyzeHeaderEncoding (ASCII 7, no spaces, escapes)" );
      s.FromOA( L'nospaces_"ascii"_only' );
      SmtpTools.AnalyzeHeaderEncoding( s, OUT neededEncoding, OUT containsSpaces );
      IF neededEncoding <> SmtpTools.HeaderEncodingEscaped THEN
         Host^.StopPhaseWithResult( FALSE );
      ELSIF containsSpaces THEN
         Host^.StopPhaseWithResult( FALSE );
      ELSE
         Host^.StopPhaseWithResult( TRUE );
      END;
      
      Host^.StartPhase( L"AnalyzeHeaderEncoding (ASCII 7, spaces, escapes)" );
      s.FromOA( L'spaces "ascii" only' );
      SmtpTools.AnalyzeHeaderEncoding( s, OUT neededEncoding, OUT containsSpaces );
      IF neededEncoding <> SmtpTools.HeaderEncodingEscaped THEN
         Host^.StopPhaseWithResult( FALSE );
      ELSIF NOT containsSpaces THEN
         Host^.StopPhaseWithResult( FALSE );
      ELSE
         Host^.StopPhaseWithResult( TRUE );
      END;
      
      Host^.StartPhase( L"AnalyzeHeaderEncoding (16bit, no spaces)" );
      s.FromOA( L"Žádné_mezery_leè_háèkové_a_èárkové" );
      SmtpTools.AnalyzeHeaderEncoding( s, OUT neededEncoding, OUT containsSpaces );
      IF neededEncoding <> SmtpTools.HeaderEncodingMimeWord THEN
         Host^.StopPhaseWithResult( FALSE );
      ELSIF containsSpaces THEN
         Host^.StopPhaseWithResult( FALSE );
      ELSE
         Host^.StopPhaseWithResult( TRUE );
      END;
      
      Host^.StartPhase( L"AnalyzeHeaderEncoding (16bit, spaces)" );
      s.FromOA( L"Žádné mezery leè háèkové a èárkové" );
      SmtpTools.AnalyzeHeaderEncoding( s, OUT neededEncoding, OUT containsSpaces );
      IF neededEncoding <> SmtpTools.HeaderEncodingMimeWord THEN
         Host^.StopPhaseWithResult( FALSE );
      ELSIF containsSpaces THEN
         Host^.StopPhaseWithResult( FALSE );
      ELSE
         Host^.StopPhaseWithResult( TRUE );
      END;
      
      Host^.StartPhase( L"ToMimeWords (first line bigger than maximal)" );
      s.FromOA( L"Žádné mezery leè háèkové a èárkové" );
      Host^.StopPhaseWithResult( MIME.ToMimeWords( s, 10, 5, OUT output ));
      
      Host^.StartPhase( L"ToMimeWords (bad maximal line length is too small)" );
      s.FromOA( L"Žádné mezery leè háèkové a èárkové" );
      Host^.StopPhaseWithResult( MIME.ToMimeWords( s, 0, 1, OUT output ));
      
      Host^.StartPhase( L"ToMimeWords (single mime word)" );
      s.FromOA( L"Žádné mezery leè háèkové a èárkové" );
      IF NOT MIME.ToMimeWords( s, -1, -1, OUT output ) THEN
         Host^.StopPhaseWithResult( FALSE );
      ELSIF NOT output.EqualsOA( L"=?utf-8?b?xb3DoWRuw6kgbWV6ZXJ5IGxlxI0gaMOhxI1rb3bDqSBhIMSNw6Fya292w6k=?=" ) THEN
         Host^.StopPhaseWithResult( FALSE );
      ELSE
         Host^.StopPhaseWithResult( TRUE );
      END;
      
      Host^.StartPhase( L"ToMimeWords (single mime word, first line folded)" );
      s.FromOA( L"Žádné mezery leè háèkové a èárkové" );
      IF NOT MIME.ToMimeWords( s, 1, -1, OUT output ) THEN
         Host^.StopPhaseWithResult( FALSE );
      ELSIF NOT output.EqualsOA( FOLD + L"=?utf-8?b?xb3DoWRuw6kgbWV6ZXJ5IGxlxI0gaMOhxI1rb3bDqSBhIMSNw6Fya292w6k=?=" ) THEN
         Host^.StopPhaseWithResult( FALSE );
      ELSE
         Host^.StopPhaseWithResult( TRUE );
      END;
      
      Host^.StartPhase( L"ToMimeWords (multiple mime words, first line halfened)" );
      s.FromOA( L"Žádné mezery leè háèkové a èárkové Žádné mezery leè háèkové a èárkové Žádné mezery leè háèkové a èárkové Žádné mezery leè háèkové a èárkové Žádné mezery leè háèkové a èárkové Žádné mezery leè háèkové a èárkové Žádné mezery leè háèkové a èárkové Žádné mezery leè háèkové a èárkové Žádné mezery leè háèkové a èárkové" );
      IF NOT MIME.ToMimeWords( s, 32, 64, OUT output ) THEN
         Host^.StopPhaseWithResult( FALSE );
      ELSIF NOT output.EqualsOA( L"=?utf-8?b?xb3DoWRuw6kgbWV6?=" + FOLD +
                                 L"=?utf-8?b?ZXJ5IGxlxI0gaMOhxI1rb3bDqSBhIMSNw6Fya292w6kgxb3DoWRuw6kgbQ==?=" + FOLD +
                                 L"=?utf-8?b?ZXplcnkgbGXEjSBow6HEjWtvdsOpIGEgxI3DoXJrb3bDqSDFvcOhZG7DqQ==?=" + FOLD +
                                 L"=?utf-8?b?IG1lemVyeSBsZcSNIGjDocSNa292w6kgYSDEjcOhcmtvdsOpIMW9w6Fk?=" + FOLD +
                                 L"=?utf-8?b?bsOpIG1lemVyeSBsZcSNIGjDocSNa292w6kgYSDEjcOhcmtvdsOpIMW9?=" + FOLD +
                                 L"=?utf-8?b?w6FkbsOpIG1lemVyeSBsZcSNIGjDocSNa292w6kgYSDEjcOhcmtvdsOp?=" + FOLD +
                                 L"=?utf-8?b?IMW9w6FkbsOpIG1lemVyeSBsZcSNIGjDocSNa292w6kgYSDEjcOhcmtv?=" + FOLD +
                                 L"=?utf-8?b?dsOpIMW9w6FkbsOpIG1lemVyeSBsZcSNIGjDocSNa292w6kgYSDEjcOhcg==?=" + FOLD +
                                 L"=?utf-8?b?a292w6kgxb3DoWRuw6kgbWV6ZXJ5IGxlxI0gaMOhxI1rb3bDqSBhIMSN?=" + FOLD +
                                 L"=?utf-8?b?w6Fya292w6kgxb3DoWRuw6kgbWV6ZXJ5IGxlxI0gaMOhxI1rb3bDqSBh?=" + FOLD +
                                 L"=?utf-8?b?IMSNw6Fya292w6k=?=" ) THEN
         Host^.StopPhaseWithResult( FALSE );
      ELSE
         Host^.StopPhaseWithResult( TRUE );
      END;

      Host^.StartPhase( L"AppendStringToHeader (plain, no hint)" );
      header.FromOA( L"To: " );
      s.FromOA( L"martin.kolarik@smartcontrol.cz" );
      SmtpTools.AppendStringToHeader( REF header, s, SmtpTools.HintNone );
      Host^.StopPhaseWithResult( header.EqualsOA( L"To: martin.kolarik@smartcontrol.cz" ));

      Host^.StartPhase( L"AppendStringToHeader (plain, hint quoted)" );
      header.FromOA( L"To: " );
      s.FromOA( L"martin.kolarik@smartcontrol.cz" );
      SmtpTools.AppendStringToHeader( REF header, s, SmtpTools.HintPersonName );
      Host^.StopPhaseWithResult( header.EqualsOA( L'To: "martin.kolarik@smartcontrol.cz"' ));

      Host^.StartPhase( L"AppendStringToHeader (plain, hint address)" );
      header.FromOA( L"To: " );
      s.FromOA( L"martin.kolarik@smartcontrol.cz" );
      SmtpTools.AppendStringToHeader( REF header, s, SmtpTools.HintPersonAddress );
      Host^.StopPhaseWithResult( header.EqualsOA( L'To: <martin.kolarik@smartcontrol.cz>' ));

      Host^.StartPhase( L"AppendStringToHeader (escaped, no hint)" );
      header.FromOA( L"To: " );
      s.FromOA( L"martin\.kolarik@smartcontrol.cz" );
      SmtpTools.AppendStringToHeader( REF header, s, SmtpTools.HintNone );
      Host^.StopPhaseWithResult( header.EqualsOA( L'To: martin\\.kolarik@smartcontrol.cz' ));

      Host^.StartPhase( L"AppendStringToHeader (escaped, hint quoted)" );
      header.FromOA( L"To: " );
      s.FromOA( L"martin\.kolarik@smartcontrol.cz" );
      SmtpTools.AppendStringToHeader( REF header, s, SmtpTools.HintPersonName );
      Host^.StopPhaseWithResult( header.EqualsOA( L'To: "martin\\.kolarik@smartcontrol.cz"' ));

      Host^.StartPhase( L"AppendStringToHeader (escaped, hint address)" );
      header.FromOA( L"To: " );
      s.FromOA( L"martin\.kolarik@smartcontrol.cz" );
      SmtpTools.AppendStringToHeader( REF header, s, SmtpTools.HintPersonAddress );
      Host^.StopPhaseWithResult( header.EqualsOA( L'To: <martin\\.kolarik@smartcontrol.cz>' ));

      Host^.StartPhase( L"AppendStringToHeader (escaped, spaces, hint address)" );
      header.FromOA( L"To: " );
      s.FromOA( L"martin\. kolarik@smartcontrol.cz" );
      SmtpTools.AppendStringToHeader( REF header, s, SmtpTools.HintPersonAddress );
      Host^.StopPhaseWithResult( header.EqualsOA( L'To: <"martin\\. kolarik"@smartcontrol.cz>' ));

      Host^.StartPhase( L"AppendStringToHeader (mimeword, no hint)" );
      header.FromOA( L"To: " );
      s.FromOA( L"Martin Kolaøík" );
      SmtpTools.AppendStringToHeader( REF header, s, SmtpTools.HintNone );
      Host^.StopPhaseWithResult( header.EqualsOA( L"To: =?utf-8?b?TWFydGluIEtvbGHFmcOtaw==?=" ));

      Host^.StartPhase( L"AppendStringToHeader (mimeword, hint quoted)" );
      header.FromOA( L"To: " );
      s.FromOA( L"Martin Kolaøík" );
      SmtpTools.AppendStringToHeader( REF header, s, SmtpTools.HintPersonName );
      Host^.StopPhaseWithResult( header.EqualsOA( L"To: =?utf-8?b?TWFydGluIEtvbGHFmcOtaw==?=" ));

      // invalid variant: Host^.StartPhase( L"AppendStringToHeader (mimeword, hint address)" );

      Host^.StartPhase( L"Construct full test header" );
      header.FromOA( L"To: " );
      s.FromOA( L"Martin Kolaøík" );
      SmtpTools.AppendStringToHeader( REF header, s, SmtpTools.HintPersonName );
      header.AppendOA( L" " );
      s.FromOA( L"martin.kolarik@smartcontrol.cz" );
      SmtpTools.AppendStringToHeader( REF header, s, SmtpTools.HintPersonAddress );
      Host^.StopPhaseWithResult( header.EqualsOA( L"To: =?utf-8?b?TWFydGluIEtvbGHFmcOtaw==?= <martin.kolarik@smartcontrol.cz>" ));
      
      RETURN test.trSuccess;
   END Run;

(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"SmtpTools", ADR( TestSmtpTools ));
END CTest;

(*===========================================================================*)

END TSmtpTools.