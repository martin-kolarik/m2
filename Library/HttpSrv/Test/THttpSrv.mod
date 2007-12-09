MODULE THttpSrv;

IMPORT
   httpsrv,
   msgqueuethread,
   Sync;
  
CLASS CT( msgqueuethread.MsgQueueThread );
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
   T.WaitStop( Sync.INFINITE_TIME );
   RETURN 0;
END wmain;

END THttpSrv.