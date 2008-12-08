IMPLEMENTATION MODULE EibSrvWeb;

(*================================================================================*)

FROM Debug IMPORT
   Assertion;

IMPORT
   Controller,
   httpsrv,
   MVC;

(*================================================================================*)

CLASS IMPLEMENTATION CEibSrvWeb;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnConnect();
   BEGIN
      _Connected := TRUE;
      _ConnectedTime := time.GetCurrentJD();
   END OnConnect;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnDisconnect();
   BEGIN
      _Connected := FALSE;
      _DisconnectedTime := time.GetCurrentJD();
   END OnDisconnect;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnInitReadCompleted();
   BEGIN
   END OnInitReadCompleted;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnRead( PObject : srvcore.TPObject );
   BEGIN
   END OnRead;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnWritten( PObject : srvcore.TPObject );
   BEGIN
      // TODO
   END OnWritten;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnInputQueueAdd( OOBQueue, PromiscuousQueue : BOOLEAN );
   BEGIN
      _EIB^.QueueLock.Lock();
      // TODO
      _EIB^.QueueLock.Unlock();
   END OnInputQueueAdd;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnInputQueueOverflow( OOBQueue, PromiscuousQueue : BOOLEAN );
   BEGIN
   END OnInputQueueOverflow;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( Port : CARDINAL; CONST ContextName : ARRAY OF WCHAR; EIB : srvcore.TPEIBServer );
   BEGIN
      Stop();
      _Port := Port;
      _Context.FromOA( ContextName );
      _EIB := EIB;
   END Init;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Running GET : BOOLEAN;
   BEGIN
      RETURN _Running;
   END Running;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Run();
   VAR
      i : CARDINAL;
   BEGIN 
      IF _Running THEN
         RETURN;
      END;
      _Running := TRUE;
      
      httpsrv.srv()^.Port := _Port;      
      httpsrv.srv()^.Start();

      ASSERT( _MVC = NIL );
      _MVC := mvc.mvc( OA( _Context.Length-1, _Context.rawData ));
      AddControllers();

      FOR i := 0 TO HIGH( _WrittenByHour ) DO
         _WrittenByHour[i] := 0;
         _GotByHour[i] := 0;
      END; // FOR
      _StartedTime := time.GetCurrentJD();      

      // hook EIB
      _EIB^.EventSink := ADR( SELF );
   END Run;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Stop();
   BEGIN
      IF NOT _Running THEN
         RETURN;
      END;
      _Running := FALSE;
      
      // unhook EIB
      _EIB^.EventSink := NIL;
      
      ASSERT( _MVC <> NIL );
      RemoveControllers();
      mvc.Cleanup();

      httpsrv.srv()^.Stop();
      httpsrv.Cleanup();
   END Stop;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE AddControllers();
   BEGIN
      // TODO
   END AddControllers;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE RemoveControllers();
   BEGIN
      // TODO
   END RemoveControllers;

(*--------------------------------------------------------------------------------*)

BEGIN
   _EIB := NIL;
   _MVC := NIL;
   _Port := 8080;
   _Running := FALSE;
   _StartedTime := 0;
   _Connected := FALSE;
   _ConnectedTime := 0;
   _DisconnectedTime := 0;
   _WrittenByHour[0] := 0;
   _GotByHour[0] := 0;
FINALLY
   Stop();   
END CEibSrvWeb;

(*================================================================================*)

END EibSrvWeb.