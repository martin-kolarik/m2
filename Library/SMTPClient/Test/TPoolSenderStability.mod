MODULE TPoolSenderStability;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   datetime,
   MailMessage,
   MailPerson,
   MIME,
   log,
   scinit,
   SmtpSender,
   Storage,
   StringsO,
   Sync,
   syncmaps,
   test,
   testimpl;
  
(*===========================================================================*)

TYPE
   TStatistics = RECORD
      DelayMinimum : datetime.TimeSpan;
      DelayMaximum : datetime.TimeSpan;
      DelayAverage : LONGREAL;
      AverageCount : CARDINAL;
      Sent : CARDINAL;
      Received : CARDINAL;
      Busy : CARDINAL;
      Succeeded : CARDINAL;
      Failed : CARDINAL;
   END; // TStatistics

   TMailData = RECORD
      Created : datetime.HighResolutionTime;
   END; // TMailData
   TPMailData = POINTER TO TMailData;

(*---------------------------------------------------------------------------*)

CLASS CTest IMPLEMENTS test.ITest, SmtpSender.INotifier;

   // INotifier
   PUBLIC VIRTUAL PROCEDURE OnMailMessageCompletion( Result : Sync.TAsyncResult; SmtpPhase : SmtpSender.TSmtpPhase; CONST message : MailMessage.TPMailMessage; UserId : PTR; CONST failedRecipientsList : MailPerson.TPPersons );

   // SELF
   PRIVATE VAR
      _Host : test.TPHost := NIL;
      _Mails : syncmaps.CPtrSyncMap;
      _Lock : Sync.RWLOCK;

      Current : TStatistics;
      Overall : TStatistics;


   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;

END CTest;

(*===========================================================================*)

VAR
   TestPoolSenderStability : CTest;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CTest;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnMailMessageCompletion( Result : Sync.TAsyncResult; SmtpPhase : SmtpSender.TSmtpPhase; CONST message : MailMessage.TPMailMessage; UserId : PTR; CONST failedRecipientsList : MailPerson.TPPersons );
   VAR
      delay : datetime.TimeSpan;
      delayMS : LONGREAL;
      lock : Sync.AutoLock;
      mailData : TPMailData;
      r : LONGREAL;
   BEGIN
      IF _Mails.Get( message, OUT mailData ) THEN
         _Mails.Remove( message );
         delay := datetime.NowHR() - mailData^.Created;
         delayMS := delay.Milliseconds;
         DISPOSE( mailData );
      ELSE
         _Host^.Log^.LogS( log.lcError, 0, L"", L"Completed mail has not been found." );
      END;

      // now operate self      
      lock.TakeSafe( REF _Lock, L"" );

      INC( Overall.Received );
      INC( Current.Received );

      IF Overall.DelayMinimum > delay THEN
         Overall.DelayMinimum := delay;
      END;
      IF Current.DelayMinimum > delay THEN
         Current.DelayMinimum := delay;
      END;
      IF Overall.DelayMaximum < delay THEN
         Overall.DelayMaximum := delay;
      END;
      IF Current.DelayMaximum < delay THEN
         Current.DelayMaximum := delay;
      END;

      r := LONGREAL( Overall.AverageCount ) * Overall.DelayAverage;
      r := r + delayMS;
      INC( Overall.AverageCount );
      Overall.DelayAverage := r / LONGREAL( Overall.AverageCount );
         
      r := LONGREAL( Current.AverageCount ) * Current.DelayAverage;
      r := r + delayMS;
      INC( Current.AverageCount );
      Current.DelayAverage := r / LONGREAL( Current.AverageCount );

      IF Result = Sync.arCompleted THEN
         INC( Overall.Succeeded );
         INC( Current.Succeeded );
      ELSE
         INC( Overall.Failed );
         INC( Current.Failed );
      END;
   END OnMailMessageCompletion;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   CONST
      LOPERF_COUNT = 100;
      SPAN_BETWEEN_MAILS = 1; // ms
   VAR
      c : CARDINAL;
      mailData : TPMailData;
      message : MailMessage.TPMailMessage;
      person : MailPerson.Person;
      result : Sync.TAsyncResult;
      s, n : StringsO.CString;
      sender : SmtpSender.TPSender;
      testResult : test.TTestResult;
   BEGIN
      _Host := Host;

      scinit.Startup();

      //-----
      Host^.StartPhase( L"Mail in loop" );
      testResult := test.trFailure;

      IF SmtpSender.New( OUT sender, FALSE, TRUE ) THEN

         sender^.Notifier := ADR( SELF );
         sender^.Mailer := StringsO.FromOA( L"sc" );
         sender^.Server := StringsO.FromOA( L"out.smtp.cz:25" );
         sender^.Login := StringsO.FromOA( L"martin@smartcontrol.cz" );
         sender^.Password := StringsO.FromOA( L"Tankem" );

         person.Name := StringsO.FromOA( L"Martin Kolaøík" );
         person.Address := StringsO.FromOA( L"martin@smartcontrol.cz" );

         Storage.Zero( ADR( Overall ), SIZE( Overall )); Overall.DelayMinimum.Value := MAX( INT64 );
         Storage.Zero( ADR( Current ), SIZE( Overall )); Current.DelayMinimum.Value := MAX( INT64 );

         LOOP
            MailMessage.New( OUT message );
            NEW( mailData );
            mailData^.Created := datetime.NowHR();
            _Mails.Add( message, mailData );

            message^.Sender := person;
            message^.Recipient := person;
            message^.Subject := StringsO.FromOA( L"Testovací majlíèek výkonového testíèku" );
            message^.Body^.WriteOA( L"Obsah testovacího emailu", OUT c, 0 );
            
            result := sender^.Send( message, 0, TRUE );
            IF result = Sync.arPending THEN
               INC( Current.Sent );
               INC( Overall.Sent );
            ELSE
               _Mails.Remove( message );
               MailMessage.Dispose( REF message );
               DISPOSE( mailData );

               IF result = Sync.arBusy THEN
                  INC( Current.Busy );
                  INC( Overall.Busy );
               ELSE
                  Host^.Log^.LogS( log.lcError, 0, L"", L"Mail send failed." );
               END;
            END;

            // exit in the case of fast test
            IF Host^.FastEvaluation AND ( Overall.Sent = LOPERF_COUNT ) THEN
               EXIT;
            END;

            Sync.Sleep( SPAN_BETWEEN_MAILS );

            IF Overall.Sent MOD 10000 = 0 THEN // report
               s.FromOA( L"S: " );
               n.FromCARD32( Overall.Sent, 10 );
               s.Append( n );

               s.AppendOA( L" b: " );
               n.FromCARD32( Overall.Busy, 10 );
               s.Append( n );

               s.AppendOA( L" q: " );
               n.FromCARD32( sender^.Count, 10 );
               s.Append( n );

               s.AppendOA( L", R: " );
               n.FromCARD32( Overall.Received, 10 );
               s.Append( n );

               s.AppendOA( L", min: " );
               n.FromLONGREALExt( Current.DelayMinimum.Milliseconds, 3, -1, FALSE, L"." );
               s.Append( n );

               s.AppendOA( L", max: " );
               n.FromLONGREALExt( Current.DelayMaximum.Milliseconds, 3, -1, FALSE, L"." );
               s.Append( n );

               s.AppendOA( L", avg: " );
               n.FromLONGREALExt( Current.DelayAverage, 3, -1, FALSE, L"." );
               s.Append( n );

               Host^.Log^.LogS( log.lcInfo, 0, L"", OA( s.Length-1, s.Data ));

               Storage.Zero( ADR( Current ), SIZE( Current )); Current.DelayMinimum.Value := MAX( INT64 );
            END;
         END; // LOOP

      END; // IF SmtpSender.New

      SmtpSender.Dispose( REF sender );

      Host^.StopPhaseWithResult( testResult );

      scinit.Cleanup();
      RETURN testResult;
   END Run;

(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"PoolSenderStability", ADR( TestPoolSenderStability ));
END CTest;

(*===========================================================================*)

END TPoolSenderStability.