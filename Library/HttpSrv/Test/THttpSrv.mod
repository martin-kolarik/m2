MODULE THttpSrv;

IMPORT
   httpsrv,
   msgqueuethread,
   Sync;
  
CLASS CT( msgqueuethread.MessageQueueThread );
   INTERNAL VIRTUAL PROCEDURE OnStart();
END CT;

CLASS IMPLEMENTATION CT;

   INTERNAL VIRTUAL PROCEDURE OnStart();
   BEGIN
      httpsrv.srv()^.Start();
   END OnStart;

END CT;
  
#save, call( convention => cdecl )
PROCEDURE wmain() : INTEGER;
#restore
VAR
   T : CT;
BEGIN
   T.Run( FALSE );
   T.WaitStop( Sync.FORSAFETY );
   RETURN 0;
END wmain;

END THttpSrv.