MODULE TLightweightSender;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   MailMessage,
   log,
   scinit,
   SmtpSender,
   StringsO,
   Sync,
   test,
   testimpl;
  
(*===========================================================================*)

CLASS CTest IMPLEMENTS test.ITest;
   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
END CTest;

(*===========================================================================*)

VAR
   TestLightweightSender : CTest;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CTest;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   VAR
      message : MailMessage.TPMailMessage;
      person : MailMessage.Person;
      sender : SmtpSender.TPSender;
   BEGIN
      scinit.Startup();

      //-----
      Host^.StartPhase( L"Create the sender" );
      IF SmtpSender.New( OUT sender, TRUE ) THEN
         Host^.StopPhaseWithResult( test.trSuccess );
      ELSE
         Host^.StopPhaseWithResult( test.trFailure );
      END;

      //-----
      Host^.StartPhase( L"Fill simple data" );
      sender^.Mailer := StringsO.FromOA( L"sc" );
      // sender^.Server := StringsO.FromOA( L"smtp.netbox.cz:25" );
      sender^.Server := StringsO.FromOA( L"out.smtp.cz:25" );
      sender^.Login := StringsO.FromOA( L"martin@smartcontrol.cz" );
      sender^.Password := StringsO.FromOA( L"Tankem" );
      IF sender^.Server.EqualsOA( L"out.smtp.cz" ) AND
         sender^.Mailer.EqualsOA( L"sc" ) AND
         sender^.Login.EqualsOA( L"martin@smartcontrol.cz" ) AND
         sender^.Password.EqualsOA( L"Tankem" ) AND
         ( sender^.TimeToLive = 2*86400 ) THEN
         Host^.StopPhaseWithResult( test.trSuccess );
      ELSE
         Host^.StopPhaseWithResult( test.trFailure );
      END;

      //-----
      Host^.StartPhase( L"Try to send something" );
      MailMessage.New( OUT message );

      person.Name := StringsO.FromOA( L"Martin Kolaøík" );
      person.Address := StringsO.FromOA( L"martin@smartcontrol.cz" );
      message^.Sender := person;
      message^.Recipient := person;
      message^.Subject := StringsO.FromOA( L"Testovací majlíèek mazlíèek pro Pifíèka" );

      IF sender^.Send( message, FALSE ) = Sync.arCompleted THEN
         Host^.StopPhaseWithResult( test.trSuccess );
      ELSE
         Host^.StopPhaseWithResult( test.trFailure );
      END;

      MailMessage.Dispose( REF message );
      SmtpSender.Dispose( REF sender );

      scinit.Cleanup();
      RETURN test.trSuccess;
   END Run;

(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"LightweightSender", ADR( TestLightweightSender ));
END CTest;

(*===========================================================================*)

END TLightweightSender.