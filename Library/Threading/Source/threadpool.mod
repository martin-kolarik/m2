IMPLEMENTATION MODULE threadpool;

FROM Debug IMPORT
   Assertion, LogAssertionW;

FROM Storage IMPORT
  ALLOCATE, DEALLOCATE;

IMPORT
  array,
  arrays,
  datetime,
  lists,
  maps,
  msghandler,
  SCmsgqueuethread,
  thread,
  TimeoutableTwoPtrMap,
  windows;
  
//================================================================================

CLASS IMPLEMENTATION APoolDelegate;

  LOCAL VIRTUAL PROCEDURE OnTimeout( Result : Sync.TAsyncResult; PoolHandle : TPoolHandle; UserId : PTR );
  BEGIN
  END OnTimeout;

  LOCAL VIRTUAL PROCEDURE OnMessage( Result : Sync.TAsyncResult; PoolHandle : TPoolHandle; UserId : PTR; CONST MSG : msghandler.IMessage );
  BEGIN
  END OnMessage;

  LOCAL VIRTUAL PROCEDURE OnHandle( Result : Sync.TAsyncResult; PoolHandle : TPoolHandle; UserId : PTR );
  BEGIN
  END OnHandle;

  LOCAL VIRTUAL PROCEDURE OnWorker( Result : Sync.TAsyncResult; PoolHandle : TPoolHandle; UserId : PTR );
  BEGIN
  END OnWorker;

END APoolDelegate;

//================================================================================

CLASS IMPLEMENTATION CSinkDelegate;

//---------------------------------------------------------------------------

   LOCAL FINAL PROCEDURE OnTimeout( Result : Sync.TAsyncResult; PoolHandle : TPoolHandle; UserId : PTR );
   BEGIN
      IF TimeoutSink <> NIL THEN
         TimeoutSink^.OnTimeout( Result, PoolHandle, UserId );
      END;
   END OnTimeout;

//---------------------------------------------------------------------------

   LOCAL FINAL PROCEDURE OnMessage( Result : Sync.TAsyncResult; PoolHandle : TPoolHandle; UserId : PTR; CONST MSG : msghandler.IMessage );
   BEGIN
      IF MessageSink <> NIL THEN
         MessageSink^.OnMessage( Result, PoolHandle, UserId, MSG );
      END;
   END OnMessage;

//---------------------------------------------------------------------------

   LOCAL FINAL PROCEDURE OnHandle( Result : Sync.TAsyncResult; PoolHandle : TPoolHandle; UserId : PTR );
   BEGIN
      IF HandleSink <> NIL THEN
         HandleSink^.OnHandle( Result, PoolHandle, UserId );
      END;
   END OnHandle;

//---------------------------------------------------------------------------

   LOCAL FINAL PROCEDURE OnWorker( Result : Sync.TAsyncResult; PoolHandle : TPoolHandle; UserId : PTR );
   BEGIN
      IF WorkerSink <> NIL THEN
         WorkerSink^.OnWorker( Result, PoolHandle, UserId );
      END;
   END OnWorker;

//---------------------------------------------------------------------------

BEGIN
   TimeoutSink := NIL;
   MessageSink := NIL;
   HandleSink := NIL;
   WorkerSink := NIL;
END CSinkDelegate;

//================================================================================

CLASS IMPLEMENTATION CMessageHandlerDelegate;

   LOCAL FINAL PROCEDURE OnMessage( Result : Sync.TAsyncResult; PoolHandle : TPoolHandle; UserId : PTR; CONST MSG : msghandler.IMessage );
   BEGIN
      IF Handler = NIL THEN
        RETURN;
      ELSIF Result = Sync.arCompleted THEN
        Handler^.Message( MSG, Delivery, NIL );
      END;
   END OnMessage;
  
BEGIN
   Handler := NIL;
END CMessageHandlerDelegate;

//================================================================================

CLASS IMPLEMENTATION APoolWorker;
END APoolWorker;

//================================================================================

TYPE
  TTask = (
    tskUnknown,
    tskTimeoutOnce,
    tskTimeoutRepeated,
    tskHandleOnce,
    tskHandleRepeated,
    tskMessageOnce,
    tskMessageRepeated,
    tskWorker
  );

TYPE
  TPTask = POINTER TO CTask;
  
VAR
  GCurrentHandle : CARD32 := 1;

CLASS CTask;
  Task : TTask;
  Data : PTR; // Handle, message, Worker
  UserId : PTR;
  Delegate : TPPoolDelegate;
  Timeout : CARDINAL;
  CompleteInOwningThread : BOOLEAN;
  PUBLIC READONLY VAR
    Handle : TPoolHandle;
END CTask;

//================================================================================

TYPE
  TPPoolThread = POINTER TO CPoolThread;

CLASS CPoolThread( SCmsgqueuethread.SCMessageQueueThread );
  PRIVATE VAR
    Pool : TPThreadPool;
    HTasks : TimeoutableTwoPtrMap.CTimeoutableTwoPtrMapSimplified; // CTask.Handle/PTask
    Handles : maps.CPtrMap; // CTask.Data/PPtrList
    Messages : maps.CPtrMap; // CTask.Data/PTask
    Workers : lists.CPtrList; // CTask.Data/PTask
    WaitArray : arrays.CPtrArray;
  LOCAL READONLY VAR
    ReqQueue : msgqueue.CMessageQueue; // MessageQueue is used instead of simple DatagramQueue, because it simplifies concurrent usage of messages (administrative and WaitMessage). If one creates WaitMessage and immediatelly send the message, message queue assures correct ordering without any add-on handling.
  LOCAL VAR
    TasksCount : CARDINAL; // synchronized version of unsafe HTasks.Count, the count is used to determine if thread is empty.
    HandlesCount : CARDINAL; // synchronized version of unsafe Handles.Count, the count is used to limit amount of messages/handles/workers in the thread.
    WorkersCount : CARDINAL; // synchronized version of unsafe Workers.Count, the count is used to limit amount of messages/handles/workers in the thread.
    MessagesCount : CARDINAL; // synchronized version of unsafe Messages.Count, the count is used to limit amount of messages/handles/workers in the thread.
  LOCAL READONLY PROPERTY
    Empty : BOOLEAN;
    AbleWaitHandles : BOOLEAN;
    AbleRunWorkers : BOOLEAN;

  INITIALLY CPoolThread();
  FINALLY CPoolThread();
  
  LOCAL PROCEDURE Init( Pool : TPThreadPool );
  INTERNAL VIRTUAL PROCEDURE OnRun( CONST Helper : thread.IRunnableHelper ) : CARDINAL;

  PRIVATE PROCEDURE AddTask( CurrentTime : CARDINAL; Task : TPTask );
  PRIVATE PROCEDURE RemoveTask( Result : Sync.TAsyncResult; Task : TPTask );
  PRIVATE PROCEDURE Completed( Result : Sync.TAsyncResult; Task : TPTask; PMSG : msghandler.TPMessage; RemoveTask, DisposeTask : BOOLEAN; OUT CanBeDisposed : BOOLEAN );
END CPoolThread;

//================================================================================

CLASS IMPLEMENTATION CTask;
BEGIN
  Task := tskUnknown;
  UserId := 0;
  Delegate := NIL;
  Timeout := Sync.FOREVER;
  Data := NIL;
  CompleteInOwningThread := FALSE;
  Handle := PTR( Sync.IInc( REF GCurrentHandle ));
FINALLY
  IF Delegate <> NIL THEN
    Delegate^.Release();
  END;
END CTask;

//================================================================================

TYPE
  TOperation = (
    topUnknown,
    topAdd,
    topRemoveTask,
    topRemoveDelegate, // not implemented yet
    topOnCompletion,
    topOnThreadEmpty
  );
  TMessage = RECORD
               CASE Operation : TOperation OF
               | topAdd, topOnCompletion :
                 Task : TPTask;
                 MSG : msghandler.Message;
                 Result : Sync.TAsyncResult;
               | topRemoveTask :
                 HTask : TPoolHandle;
               | topRemoveDelegate :
                 Delegate : TPPoolDelegate;
               | topOnThreadEmpty :
               END; // CASE
             END; // TMessage

//--------------------------------------------------------------------------------

CLASS IMPLEMENTATION CPoolThread;

//--------------------------------------------------------------------------------

  LOCAL PROCEDURE Init( Pool : TPThreadPool );
  BEGIN
    SELF.Pool := Pool;
  END Init;

//--------------------------------------------------------------------------------

  LOCAL READONLY PROPERTY Empty GET : BOOLEAN;
  BEGIN
    RETURN Sync.IGet( REF TasksCount ) = 0;
  END Empty;

//--------------------------------------------------------------------------------

  LOCAL READONLY PROPERTY AbleWaitHandles GET : BOOLEAN;
  BEGIN
    RETURN ( Sync.IGet( REF WorkersCount ) = 0 ) AND ( Sync.IGet( REF HandlesCount ) < windows.MAXIMUM_WAIT_OBJECTS-3 ); //-1-exit-queue.Consume
  END AbleWaitHandles;

//--------------------------------------------------------------------------------

  LOCAL READONLY PROPERTY AbleRunWorkers GET : BOOLEAN;
  BEGIN
    RETURN ( Sync.IGet( REF HandlesCount ) = 0 ) AND ( Sync.IGet( REF MessagesCount ) = 0 ) AND ( CARDINAL( Sync.IGet( REF WorkersCount )) < Pool^.WorkerLoad );
  END AbleRunWorkers;

//--------------------------------------------------------------------------------

   INTERNAL VIRTUAL PROCEDURE OnRun( CONST Helper : thread.IRunnableHelper ) : CARDINAL;

      //-----
      
      PROCEDURE HandleTimeouts( CurrentTime : CARDINAL ) : BOOLEAN;
      VAR
         CheckEmpty : BOOLEAN := FALSE;
         disposable : BOOLEAN;
         Handle : TPoolHandle;
         Task : TPTask;
      BEGIN
         WHILE HTasks.GetFirstElapsed( CurrentTime, FALSE, OUT Handle, OUT Task ) DO
            CASE Task^.Task OF
            | tskTimeoutOnce :
               Completed( Sync.arCompleted, Task, NIL, TRUE, TRUE, OUT disposable );
               CheckEmpty := TRUE;
            | tskTimeoutRepeated :
               Completed( Sync.arCompleted, Task, NIL, TRUE, FALSE, OUT disposable );
               Task^.Delegate^.Completed := FALSE;
               AddTask( CurrentTime, Task );
            | tskWorker :
               // workers are logically timeouted, but they must be removed after completion, allow worker run
               RETURN FALSE; // workers set CheckEmpty by itself
            ELSE
               RemoveTask( Sync.arTimeout, Task );
               CheckEmpty := TRUE;
            END;
         END; // WHILE

         RETURN CheckEmpty;
      END HandleTimeouts;
      
      //-----
      
      PROCEDURE HandleAdministrativeMessages( CurrentTime : CARDINAL ) : BOOLEAN;
      VAR
         CheckEmpty : BOOLEAN := FALSE;
         Message : TMessage;
         Task : TPTask;
      BEGIN
         WHILE ReqQueue.DequeueOA( OUT Message, FALSE, 0 ) = Sync.arCompleted DO
            CASE Message.Operation OF
            //---
            | topAdd :
               AddTask( CurrentTime, Message.Task );
            //---
            | topRemoveTask :
               IF HTasks.Get( Message.HTask, 0, OUT Task ) THEN
                  RemoveTask( Sync.arAborted, Task );
                  CheckEmpty := TRUE;
               END;
            //---
            | topRemoveDelegate : // NOT IMPLEMENTED YET
               ASSERTLOG( FALSE );
            //---
            ELSE
               ASSERT( FALSE );
            END; // CASE
         END; // WHILE

         RETURN CheckEmpty;
      END HandleAdministrativeMessages;

      //-----
      
      PROCEDURE CheckAndHandleKnownMessage( CONST Message : msghandler.Message ) : BOOLEAN;
      VAR
         disposable : BOOLEAN;
         Task : TPTask;
      BEGIN
         IF NOT Messages.Get( Message.Message, OUT Task ) THEN // known waited message
            RETURN FALSE; // check empty
         END;

         Completed( Sync.arCompleted, Task, msghandler.TPMessage( ADR( Message )), Task^.Task = tskMessageOnce, FALSE, OUT disposable );
         IF Task^.Task = tskMessageOnce THEN
            Messages.Remove( Task^.Data );
            Sync.IDec( REF MessagesCount );
            IF disposable THEN
               DISPOSE( Task );
            END;
         ELSE
            Task^.Delegate^.Completed := FALSE;
         END;

         RETURN TRUE; // check empty
      END CheckAndHandleKnownMessage;

      //-----
      
      PROCEDURE CheckAndHandleKnownHandle( WaitAbandoned : BOOLEAN; Handle : PTR ) : BOOLEAN;
      VAR
         b : BOOLEAN;
         D : PTR;
         disposable : BOOLEAN;
         HandleList : lists.TPPtrList;
         removeTask : BOOLEAN;
         Task, NextTask : TPTask;
      BEGIN
         IF NOT Handles.Get( Handle, OUT HandleList ) THEN
            RETURN FALSE; // check empty
         END;

         b := HandleList^.GetFirst( OUT Task, OUT D );
         WHILE b DO
            b := HandleList^.NextOf( Task, OUT NextTask, OUT D );
            removeTask := WaitAbandoned OR ( Task^.Task = tskHandleOnce );
            IF WaitAbandoned THEN
               Completed( Sync.arAborted, Task, NIL, TRUE, FALSE, OUT disposable );
            ELSE
               Completed( Sync.arCompleted, Task, NIL, removeTask, FALSE, OUT disposable );
            END;
            IF removeTask THEN
               HandleList^.Remove( Task );
               IF disposable THEN
                  DISPOSE( Task );
               END;
            ELSE
               Task^.Delegate^.Completed := FALSE;
            END; // IF tskHandleOnce
            Task := NextTask;
         END; // WHILE

         IF HandleList^.Empty THEN
            DISPOSE( HandleList );
            Handles.Remove( Handle );
            Sync.IDec( REF HandlesCount );
            RETURN TRUE; // check empty
         ELSE
            RETURN FALSE; // check empty
         END;
      END CheckAndHandleKnownHandle;
      
      //-----
      
   VAR
      CheckEmpty : BOOLEAN;
      CurrentTime : CARDINAL;
      disposable : BOOLEAN;
      Message : msghandler.Message;
      Status : CARDINAL;
      Timeout : CARDINAL;
      WaitAbandoned : BOOLEAN;
      Worker : TPPoolWorker;
      WorkerTask : TPTask;
   BEGIN
      OnStart();
   
      WaitArray.Add( _HExit.RawHandle );
      WaitArray.Add( Queue.Consume^.RawHandle );
      
      LOOP
         CheckEmpty := FALSE;
         Timeout := HTasks.GetTimeoutToFirstElapsed( datetime.UptimeMS());
         Status := windows.WaitForMultipleObjectsEx( WaitArray.Count, WaitArray.Data, windows.False, Timeout, windows.True );
         CurrentTime := datetime.UptimeMS();
         
         CASE Status OF
         //-----
         | CARDINAL( windows.WAIT_FAILED ) : // something failed
            Status := windows.GetLastError();
            ASSERTLOG( FALSE );
            EXIT;
         
         //-----
         | windows.WAIT_OBJECT_0 : // graceful EXIT
            EXIT;

         //-----
         | windows.WAIT_OBJECT_0 + 1 : // message received
            WHILE Queue.DequeueOA( OUT Message, FALSE, 0 ) = Sync.arCompleted DO
               IF Message.Message = msgqueue.MSG_PROCESS_QUEUE THEN // administrative message/queue
                  CheckEmpty := HandleAdministrativeMessages( CurrentTime ) OR CheckEmpty;
               ELSE
                  CheckEmpty := CheckAndHandleKnownMessage( Message ) OR CheckEmpty;
               END;
            END; // WHILE messages

         //-----
         | windows.WAIT_TIMEOUT : // remove all timeouted tasks
            CheckEmpty := HandleTimeouts( datetime.UptimeMS());

         //-----
         ELSE
            IF Status > windows.WAIT_ABANDONED_0 THEN
               DEC( Status, windows.WAIT_ABANDONED_0 );
               WaitAbandoned := TRUE;
            ELSE
               DEC( Status, windows.WAIT_OBJECT_0 );
               WaitAbandoned := FALSE;
            END;
            CheckEmpty := CheckAndHandleKnownHandle( WaitAbandoned, WaitArray[Status] );
            IF CheckEmpty THEN // handle was removed
               WaitArray.RemoveIndex( Status );
            END;

         //-----
         END; // ELSE CASE
      
         // Run Workers
         IF Workers.GetFirst( OUT Worker, OUT WorkerTask ) THEN
            Workers.Remove( Worker );
            Worker^.Run();
            Completed( Sync.arCompleted, WorkerTask, NIL, TRUE, TRUE, OUT disposable );
            Sync.IDec( REF WorkersCount );
            Worker^.Release();
            IF Workers.Empty THEN // continue with self, but after checking or processing messages and exit event
               CheckEmpty := TRUE;
            END;
         END;
      
         IF CheckEmpty AND Empty THEN
            Pool^.OnThreadEmpty();
         END;
      END; // LOOP

      OnExit();
      RETURN 0;
   END OnRun;

//--------------------------------------------------------------------------------

  PRIVATE PROCEDURE AddTask( CurrentTime : CARDINAL; Task : TPTask );
  VAR
    HandleList : lists.TPPtrList;
  BEGIN
    HTasks.Add( CurrentTime, Task^.Handle, Task, Task^.Timeout );
    CASE Task^.Task OF
    | tskTimeoutOnce, tskTimeoutRepeated :
      // do nothing
    | tskMessageOnce, tskMessageRepeated :
      Messages.Add( Task^.Data, Task );
    | tskHandleOnce, tskHandleRepeated :
      IF Handles.Get( Task^.Data, OUT HandleList ) THEN
         Sync.IDec( REF HandlesCount ); // no resource was consumed, decrease count
      ELSE
         NEW( HandleList );
         Handles.Add( Task^.Data, HandleList );
         WaitArray.Add( Task^.Data );
      END;
      HandleList^.Add( Task, 0 );
    | tskWorker :
      Workers.Add( Task^.Data, Task );
    ELSE
      ASSERTLOG( FALSE );
    END; // CASE
  END AddTask;

//--------------------------------------------------------------------------------

  PRIVATE PROCEDURE RemoveTask( Result : Sync.TAsyncResult; Task : TPTask );
  VAR
    disposable : BOOLEAN;
    HandleList : lists.TPPtrList;
  BEGIN
    CASE Task^.Task OF
    | tskTimeoutOnce, tskTimeoutRepeated :
      // do nothing
    | tskMessageOnce, tskMessageRepeated :
      Messages.Remove( Task^.Data );
      Sync.IDec( REF MessagesCount );
    | tskHandleOnce, tskHandleRepeated :
      IF Handles.Get( Task^.Data, OUT HandleList ) THEN
        HandleList^.Remove( Task );
        IF HandleList^.Empty THEN
          DISPOSE( HandleList );
          Handles.Remove( Task^.Data );
          WaitArray.Remove( Task^.Data );
          Sync.IDec( REF HandlesCount );
        END;
      END;
    | tskWorker :
      Workers.Remove( Task^.Data );
      Sync.IDec( REF WorkersCount );
      TPPoolWorker( Task^.Data )^.Release();
    ELSE
      ASSERTLOG( FALSE );
    END; // CASE
    Completed( Result, Task, NIL, TRUE, TRUE, OUT disposable );
  END RemoveTask;

//--------------------------------------------------------------------------------

  PRIVATE PROCEDURE Completed( Result : Sync.TAsyncResult; Task : TPTask; PMSG : msghandler.TPMessage; RemoveTask, DisposeTask : BOOLEAN; OUT CanBeDisposed : BOOLEAN );
  VAR
    Disposable : BOOLEAN;
    MSG : msghandler.Message;
  BEGIN
    IF RemoveTask THEN
      HTasks.Remove( Task^.Handle );
      Sync.IDec( REF TasksCount );
    ELSE
      DisposeTask := FALSE; // for safety
    END;

    Task^.Delegate^.Completed := TRUE;
    IF Pool = NIL THEN
      Disposable := TRUE;
    ELSIF PMSG = NIL THEN
      Disposable := Pool^.OnCompletion( Result, Task, MSG );
    ELSE
      Disposable := Pool^.OnCompletion( Result, Task, PMSG^ );
    END;

    IF DisposeTask AND Disposable THEN
      DISPOSE( Task );
      CanBeDisposed := FALSE;
    ELSE
      CanBeDisposed := Disposable;
    END;
  END Completed;

//--------------------------------------------------------------------------------

  INITIALLY CPoolThread();
  BEGIN
    Queue.Size := 128;
    Pool := NIL;
    ReqQueue.Init( 128, SIZE( TMessage ));
    ReqQueue.Produce := Sync.CreateSignal( Sync.stEvent, L"", FALSE );
    ReqQueue.Consumer := ADR( SELF );
    WaitArray.Strategy := array.astrgListInArray;
    TasksCount := 0;
    HandlesCount := 0;
    WorkersCount := 0;
    MessagesCount := 0;
  END CPoolThread;

//--------------------------------------------------------------------------------

  FINALLY CPoolThread();
  VAR
    disposable : BOOLEAN;
    Key : PTR;
    Task : TPTask;
  BEGIN
    Sync.DeleteSignal( REF ReqQueue.Produce );
    Handles.Reset();
    WHILE Handles.MoveNext() DO
      lists.TPPtrList( Handles.CurrentData )^.Reset();
      WHILE lists.TPPtrList( Handles.CurrentData )^.MoveNext() DO
        Completed( Sync.arAborted, lists.TPPtrList( Handles.CurrentData )^.Current, NIL, TRUE, TRUE, OUT disposable );
      END; // WHILE
      DISPOSE( lists.TPPtrList( Handles.CurrentData ));
    END; // WHILE
    Messages.Reset();
    WHILE Messages.MoveNext() DO
      Completed( Sync.arAborted, Messages.CurrentData, NIL, TRUE, TRUE, OUT disposable );
    END; // WHILE
    Workers.Reset();
    WHILE Workers.MoveNext() DO
      Completed( Sync.arAborted, Workers.CurrentData, NIL, TRUE, TRUE, OUT disposable );
      TPPoolWorker( Workers.Current )^.Release();
    END; // WHILE
    WHILE HTasks.GetFirstElapsed( datetime.UptimeMS(), FALSE, OUT Key, OUT Task ) DO
      Completed( Sync.arAborted, Task, NIL, TRUE, TRUE, OUT disposable );
    END; // WHILE
  END CPoolThread;

//--------------------------------------------------------------------------------

END CPoolThread;

//================================================================================

CLASS IMPLEMENTATION CThreadPool;

//--------------------------------------------------------------------------------

   PUBLIC PROPERTY UndeliveredMessagesPending GET : BOOLEAN; // mostly for debug purposes
   BEGIN
      RETURN NOT MQueue.Empty;
   END UndeliveredMessagesPending;

//--------------------------------------------------------------------------------

  PUBLIC PROPERTY MinThreads GET : CARDINAL;
  BEGIN
    RETURN _MinThreads;
  END MinThreads;

//--------------------------------------------------------------------------------

  PUBLIC PROPERTY MinThreads SET( Value : CARDINAL );
  BEGIN
    _MinThreads := Value;
    IF _MinThreads < Threads.Count THEN // try to decrease threads number
      OnThreadEmpty();
    END;
  END MinThreads;

//--------------------------------------------------------------------------------

  INTERNAL VIRTUAL PROCEDURE OnMessage( CONST MSG : msghandler.IMessage; OUT Result : PTR ) : BOOLEAN;
  VAR
    Message : TMessage;
  BEGIN
    IF SUPER.OnMessage( MSG, OUT Result ) THEN
      RETURN TRUE;
    END;

    Result := 0;
    CASE MSG.Message OF
    //-----
    | msgqueue.MSG_PROCESS_QUEUE :
      WHILE MQueue.DequeueOA( OUT Message, FALSE, 0 ) = Sync.arCompleted DO
        CASE Message.Operation OF
        //---
        | topOnThreadEmpty : // if possible, remove thread
          DisposeThreads( TRUE );
        //---
        | topOnCompletion :
          IF OnCompletion( Message.Result, Message.Task, Message.MSG ) THEN
            CASE Message.Task^.Task OF // all disposable once-repeated tasks must be cleared
            | tskHandleOnce, tskMessageOnce, tskTimeoutOnce, tskWorker :
              DISPOSE( Message.Task );
            END; // CASE           
          END;

        END; // CASE
      END; // WHILE

    //-----
    ELSE
      RETURN FALSE;
    END;
    RETURN TRUE;
  END OnMessage;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE FinishAndWait();
  BEGIN
    DisposeThreads( FALSE );
  END FinishAndWait;
  
//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE WaitTimeout( CONST Delegate : TPPoolDelegate; UserId : PTR; TimeoutMS : CARDINAL; WaitOnce, CompleteInOwningThread : BOOLEAN; OUT PoolHandle : TPoolHandle ) : BOOLEAN;
  VAR
    MSG : TMessage;
    PoolThread : TPPoolThread;
    Result : Sync.TAsyncResult;
  BEGIN
    _Lock.Lock();
    IF NOT LookupThread( FALSE, FALSE, OUT PoolThread ) THEN
      _Lock.Unlock();
      RETURN FALSE;
    END;
    Sync.IInc( REF PoolThread^.TasksCount );
    _Lock.Unlock();

    IF Delegate <> NIL THEN
      Delegate^.AddRef();
    END;
    MSG.Operation := topAdd;

    NEW( MSG.Task );
    IF WaitOnce THEN
      MSG.Task^.Task := tskTimeoutOnce;
    ELSE
      MSG.Task^.Task := tskTimeoutRepeated;
    END;
    MSG.Task^.UserId := UserId;
    MSG.Task^.Delegate := Delegate;
    MSG.Task^.Timeout := TimeoutMS;
    MSG.Task^.CompleteInOwningThread := CompleteInOwningThread;

    // return value
    PoolHandle := MSG.Task^.Handle;

    Result := PoolThread^.ReqQueue.EnqueueOA( MSG, TRUE, Sync.FORSAFETY );
    ASSERTLOG( Result <> Sync.arTimeout );
    RETURN Result = Sync.arCompleted;
  END WaitTimeout;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE WaitMessage( CONST Delegate : TPPoolDelegate; UserId : PTR; TimeoutMS : CARDINAL; WaitOnce, CompleteInOwningThread : BOOLEAN; OUT Target : msghandler.TPIMessageTarget; OUT Message : msghandler.IMessage; OUT PoolHandle : TPoolHandle ) : BOOLEAN;
  VAR
    message : CARDINAL;
    MSG : TMessage;
    PoolThread : TPPoolThread;
    Result : Sync.TAsyncResult;
  BEGIN
    _Lock.Lock();
    IF NOT LookupThread( FALSE, FALSE, OUT PoolThread ) THEN
      _Lock.Unlock();
      RETURN FALSE;
    END;
    Sync.IInc( REF PoolThread^.TasksCount );
    Sync.IInc( REF PoolThread^.MessagesCount ); // do it as the first, here, as interface is single threaded only now
    _Lock.Unlock();

    IF Delegate <> NIL THEN
      Delegate^.AddRef();
    END;
    MSG.Operation := topAdd;

    NEW( MSG.Task );
    message := CARDINAL( LOPTRLONGWORD( MSG.Task^.Handle )) + msgqueue.MSG_PROCESS_QUEUE;
    IF WaitOnce THEN
      MSG.Task^.Task := tskMessageOnce;
    ELSE
      MSG.Task^.Task := tskMessageRepeated;
    END;
    MSG.Task^.UserId := UserId;
    MSG.Task^.Delegate := Delegate;
    MSG.Task^.Timeout := TimeoutMS;
    MSG.Task^.Data := PTR( message );
    MSG.Task^.CompleteInOwningThread := CompleteInOwningThread;

    // return values
    PoolHandle := MSG.Task^.Handle;
    Message.Message := message;
    Message.Target := PoolThread;
    Target := PoolThread;

    Result := PoolThread^.ReqQueue.EnqueueOA( MSG, TRUE, Sync.FORSAFETY );
    ASSERTLOG( Result <> Sync.arTimeout );
    RETURN Result = Sync.arCompleted;
  END WaitMessage;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE WaitHandle( CONST Delegate : TPPoolDelegate; UserId : PTR; TimeoutMS : CARDINAL; WaitOnce, CompleteInOwningThread : BOOLEAN; Handle : Sync.WAITABLE; OUT PoolHandle : TPoolHandle ) : BOOLEAN;
  VAR
    MSG : TMessage;
    PoolThread : TPPoolThread;
    Result : Sync.TAsyncResult;
  BEGIN
    _Lock.Lock();
    IF NOT LookupThread( FALSE, FALSE, OUT PoolThread ) THEN
      _Lock.Unlock();
      RETURN FALSE;
    END;
    Sync.IInc( REF PoolThread^.TasksCount );
    Sync.IInc( REF PoolThread^.HandlesCount ); // do it as the first, here, as interface is single threaded only now
    _Lock.Unlock();

    IF Delegate <> NIL THEN
      Delegate^.AddRef();
    END;
    MSG.Operation := topAdd;

    NEW( MSG.Task );
    IF WaitOnce THEN
      MSG.Task^.Task := tskHandleOnce;
    ELSE
      MSG.Task^.Task := tskHandleRepeated;
    END;
    MSG.Task^.UserId := UserId;
    MSG.Task^.Delegate := Delegate;
    MSG.Task^.Timeout := TimeoutMS;
    MSG.Task^.Data := Handle;
    MSG.Task^.CompleteInOwningThread := CompleteInOwningThread;

    // return value
    PoolHandle := MSG.Task^.Handle;

    Result := PoolThread^.ReqQueue.EnqueueOA( MSG, TRUE, Sync.FORSAFETY );
    ASSERTLOG( Result <> Sync.arTimeout );
    RETURN Result = Sync.arCompleted;
  END WaitHandle;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE RunWorker( CONST Delegate : TPPoolDelegate; UserId : PTR; ForceSelfThread : BOOLEAN; Worker : TPPoolWorker; CompleteInOwningThread : BOOLEAN; OUT PoolHandle : TPoolHandle ) : BOOLEAN;
  VAR
    MSG : TMessage;
    PoolThread : TPPoolThread;
    Result : Sync.TAsyncResult;
  BEGIN
    _Lock.Lock();
    IF NOT LookupThread( TRUE, ForceSelfThread, OUT PoolThread ) THEN
      _Lock.Unlock();
      RETURN FALSE;
    END;
    Sync.IInc( REF PoolThread^.TasksCount );
    Sync.IInc( REF PoolThread^.WorkersCount ); // do it as the first, here, as interface is single threaded only now
    _Lock.Unlock();

    IF Delegate <> NIL THEN
      Delegate^.AddRef();
    END;
    Worker^.AddRef();
    MSG.Operation := topAdd;

    NEW( MSG.Task );
    MSG.Task^.Task := tskWorker;
    MSG.Task^.UserId := UserId;
    MSG.Task^.Delegate := Delegate;
    MSG.Task^.Timeout := 0;
    MSG.Task^.Data := Worker;
    MSG.Task^.CompleteInOwningThread := CompleteInOwningThread;

    // return value
    PoolHandle := MSG.Task^.Handle;

    Result := PoolThread^.ReqQueue.EnqueueOA( MSG, TRUE, Sync.FORSAFETY );
    ASSERTLOG( Result <> Sync.arTimeout );
    RETURN Result = Sync.arCompleted;
  END RunWorker;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE Abort( REF PoolHandle : TPoolHandle );
  VAR
    MSG : TMessage;
    Result : Sync.TAsyncResult;
  BEGIN
    // CheckThreadInterface(); -- not checked, the method can be called from all threads
    MSG.Operation := topRemoveTask;
    MSG.HTask := PoolHandle;
    PoolHandle := 0;

    _Lock.Lock();
    Threads.Reset();
    WHILE Threads.MoveNext() DO // deliver the message to pool threads
      Result := TPPoolThread( Threads.Current )^.ReqQueue.EnqueueOA( MSG, TRUE, Sync.FORSAFETY );
      ASSERTLOG( Result <> Sync.arTimeout );
    END; // WHILE
    _Lock.Unlock();
  END Abort;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE AbortAll( CONST Delegate : TPPoolDelegate );
  VAR
    MSG : TMessage;
    Result : Sync.TAsyncResult;
  BEGIN
    // CheckThreadInterface(); -- not checked, the method can be called from all threads
    MSG.Operation := topRemoveDelegate;
    MSG.Delegate := Delegate;

    _Lock.Lock();
    Threads.Reset();
    WHILE Threads.MoveNext() DO // deliver the message to pool threads
      Result := TPPoolThread( Threads.Current )^.ReqQueue.EnqueueOA( MSG, TRUE, Sync.FORSAFETY );
      ASSERTLOG( Result <> Sync.arTimeout );
    END; // WHILE
    _Lock.Unlock();
  END AbortAll;

//--------------------------------------------------------------------------------

  LOCAL PROCEDURE OnThreadEmpty();
  VAR
    LMSG : TMessage;
    Result : Sync.TAsyncResult;
  BEGIN
    LMSG.Operation := topOnThreadEmpty;
    Result := MQueue.EnqueueOA( LMSG, TRUE, Sync.FORSAFETY ); 
    ASSERTLOG( Result <> Sync.arTimeout );
  END OnThreadEmpty;

//--------------------------------------------------------------------------------

  LOCAL PROCEDURE OnCompletion( Result : Sync.TAsyncResult; _Task : PTR; CONST MSG : msghandler.Message ) : BOOLEAN;
  // !! returns if Task can be disposed
  VAR
    LMSG : TMessage;
    LResult : Sync.TAsyncResult;
    Task : TPTask := TPTask( _Task );
  BEGIN
    IF Task^.Delegate = NIL THEN
      RETURN TRUE;
    ELSIF ( CompletionInOwningThread OR Task^.CompleteInOwningThread ) AND NOT SelfContext THEN
      LMSG.Operation := topOnCompletion;
      LMSG.Result := Result;
      LMSG.Task := Task;
      LMSG.MSG := MSG;
      LResult := MQueue.EnqueueOA( LMSG, TRUE, Sync.FORSAFETY ); 
      ASSERTLOG( LResult <> Sync.arTimeout );
      RETURN FALSE;
    ELSE
      CASE Task^.Task OF
      | tskTimeoutOnce, tskTimeoutRepeated :
        Task^.Delegate^.OnTimeout( Result, Task^.Handle, Task^.UserId );
      | tskMessageOnce, tskMessageRepeated :
        Task^.Delegate^.OnMessage( Result, Task^.Handle, Task^.UserId, MSG );
      | tskHandleOnce, tskHandleRepeated :
        Task^.Delegate^.OnHandle( Result, Task^.Handle, Task^.UserId );
      | tskWorker :
        Task^.Delegate^.OnWorker( Result, Task^.Handle, Task^.UserId );
      END;
      RETURN TRUE;
    END;
  END OnCompletion;

//--------------------------------------------------------------------------------

  PRIVATE PROCEDURE LookupThread( WorkerFlag : BOOLEAN; ForceSelfThread : BOOLEAN; OUT _PoolThread : PTR ) : BOOLEAN;
  VAR
    PoolThread : TPPoolThread;
  BEGIN
    IF NOT ForceSelfThread THEN
       // lookup
       Threads.Reset();
       WHILE Threads.MoveNext() DO
         IF     WorkerFlag AND TPPoolThread( Threads.Current )^.AbleRunWorkers OR
            NOT WorkerFlag AND TPPoolThread( Threads.Current )^.AbleWaitHandles THEN
           _PoolThread := TPPoolThread( Threads.Current );
           RETURN TRUE;
         END; // IF
       END; // WHILE
    END;
    IF Threads.Count >= MaxThreads THEN
      _PoolThread := NIL;
      RETURN FALSE;
    END;

    NEW( PoolThread );
    PoolThread^.Init( ADR( SELF ));
    PoolThread^.Start( TRUE );
    WHILE PoolThread^.ReqQueue.Consumer = NIL DO // wait thread is able to process administrative messages
      Sync.Sleep( 0 );
    END; // WHILE
    Threads.Add( PoolThread, 0 );

    _PoolThread := PoolThread;
    RETURN TRUE;
  END LookupThread;

//--------------------------------------------------------------------------------

  PRIVATE PROCEDURE DisposeThreads( RespectMinThreads : BOOLEAN );
  VAR
    PoolThread : TPPoolThread;
    ThreadsToLeave : lists.CPtrList;
    ThreadsToRemove : lists.CPtrList;
  BEGIN
    _Lock.Lock();
    Threads.Reset();
    WHILE Threads.MoveNext() DO
      PoolThread := TPPoolThread( Threads.Current );
      IF NOT RespectMinThreads OR ( ThreadsToLeave.Count > _MinThreads ) AND PoolThread^.Empty THEN
        ThreadsToRemove.Add( PoolThread, 0 );
      ELSE
        ThreadsToLeave.Add( PoolThread, 0 );
      END;
    END; // WHILE
    // switch thread lists
    Threads.Dispose();
    Threads.AppendList( REF ThreadsToLeave );
    _Lock.Unlock();

    ThreadsToRemove.Reset();
    WHILE ThreadsToRemove.MoveNext() DO
      PoolThread := TPPoolThread( ThreadsToRemove.Current );
      PoolThread^.Stop( TRUE );
      DISPOSE( PoolThread );
    END; // WHILE
    ThreadsToRemove.Dispose();
  END DisposeThreads;

//--------------------------------------------------------------------------------

BEGIN
  Init( TRUE );
  MQueue.Init( 128, SIZE( TMessage ));
  MQueue.Consumer := ADR( SELF );
FINALLY
  DisposeThreads( FALSE );
END CThreadPool;

//================================================================================

VAR
   Pool : TPThreadPool;

//--------------------------------------------------------------------------------

PROCEDURE Startup();
BEGIN
   IF Pool = NIL THEN
      NEW( Pool );
      Pool^.MinThreads := 1;
      Pool^.MaxThreads := 64;
   END;
END Startup;

//--------------------------------------------------------------------------------

PROCEDURE Cleanup();
BEGIN
   IF Pool <> NIL THEN
      Pool^.FinishAndWait();
      DISPOSE( Pool );
   END;
END Cleanup;

//--------------------------------------------------------------------------------

PROCEDURE pool() : TPThreadPool;
BEGIN
   ASSERTLOG( Pool <> NIL );
   RETURN Pool;
END pool;

//================================================================================

BEGIN
   Pool := NIL;
FINALLY
   ASSERTLOG( Pool = NIL );
END threadpool.
