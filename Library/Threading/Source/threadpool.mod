IMPLEMENTATION MODULE threadpool;

FROM Storage IMPORT
  ALLOCATE, DEALLOCATE;

IMPORT
  array,
  arrays,
  lists,
  maps,
  thread;
  
//================================================================================

CLASS IMPLEMENTATION APoolDelegate;

  LOCAL VIRTUAL PROCEDURE OnTimeout( Result : Sync.TAsyncResult; PoolHandle : Sync.WAITABLE; UserId : PTR );
  BEGIN
  END OnTimeout;

  LOCAL VIRTUAL PROCEDURE OnMessage( Result : Sync.TAsyncResult; PoolHandle : Sync.WAITABLE; UserId : PTR; CONST MSG : msghandler.IMessage );
  BEGIN
  END OnMessage;

  LOCAL VIRTUAL PROCEDURE OnHandle( Result : Sync.TAsyncResult; PoolHandle : Sync.WAITABLE; UserId : PTR );
  BEGIN
  END OnHandle;

  LOCAL VIRTUAL PROCEDURE OnWorker( Result : Sync.TAsyncResult; PoolHandle : Sync.WAITABLE; UserId : PTR );
  BEGIN
  END OnWorker;

END APoolDelegate;

//================================================================================

CLASS IMPLEMENTATION CMessageHandlerDelegate;

   LOCAL VIRTUAL PROCEDURE OnMessage( Result : Sync.TAsyncResult; PoolHandle : Sync.WAITABLE; UserId : PTR; CONST MSG : msghandler.IMessage );
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

CLASS CTask;
  Task     : TTask;
  Data     : PTR; // Handle, message, Worker
  UserId   : PTR;
  Delegate : TPPoolDelegate;
  Timeout  : CARDINAL;
  HWait    : Sync.SIGNAL;
END CTask;

//================================================================================

TYPE
  TPTaskItem = POINTER TO CTaskItem;

CLASS CTaskItem( avltree.CAVLTreeElem2 ); // MUST BE BINARY COMPATIBLE WITH maps.CPtrMap !!!
  PUBLIC VAR
    Key : windows.HANDLE;
    Task : TPTask;
    ElapsesOn : CARD64;
  PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;
  // OPERATOR NEW() : ADDRESS;
  // OPERATOR DISPOSE( a : ADDRESS );
END CTaskItem;

//---------------------------------------------------------------------------

CLASS CTaskMap( avltree.CAVLTree );
  PRIVATE VAR
    Counter : CARDINAL;
  LOCAL VAR
    CurrentTime : CARDINAL;

  // map interface
  PUBLIC PROCEDURE Add( Key : windows.HANDLE; Task : TPTask; Timeout : CARDINAL );
  PUBLIC PROCEDURE Remove( Key : windows.HANDLE );
  PUBLIC PROCEDURE Get( Key : windows.HANDLE; OUT Task : TPTask ) : BOOLEAN;

  // pool thread interface
  LOCAL PROCEDURE GetTimeoutToFirstElapsed( TimeToCount : CARDINAL ) : CARDINAL;
  LOCAL PROCEDURE GetFirstElapsed( OUT Task : TPTask ) : BOOLEAN;

  PRIVATE PROCEDURE GetFirstWithTimeout( CurrentTime : CARDINAL; OUT Task : TPTask; OUT Timeout : CARDINAL ) : BOOLEAN;
END CTaskMap;

//--------------------------------------------------------------------------------

TYPE
  TPPoolThread = POINTER TO CPoolThread;

CLASS CPoolThread( thread.Thread );
  PRIVATE VAR
    Pool : TPThreadPool;
    HTasks : CTaskMap; // CTask.HWait/PTask
    Handles : maps.CPtrMap; // CTask.Data/PPtrList
    Messages : maps.CPtrMap; // CTask.Data/PTask
    Workers : lists.CPtrList; // CTask.Data/PTask
    WaitArray : arrays.CPtrArray;
  LOCAL READONLY VAR
    Messager : msghandler.MessageHandler;
    MQueue : msgqueue.CMessageQueue;
  LOCAL VAR
    PendingHandles : CARDINAL;
    PendingWorkers : CARDINAL;
  LOCAL READONLY PROPERTY
    Empty : BOOLEAN;
    AbleWait : BOOLEAN;
    AbleRunWorkers : BOOLEAN;

  INITIALLY CPoolThread();
  FINALLY CPoolThread();
  
  LOCAL PROCEDURE Init( Pool : TPThreadPool );
  INTERNAL VIRTUAL PROCEDURE OnRun() : CARDINAL;

  PRIVATE PROCEDURE AddTask( Task : TPTask );
  PRIVATE PROCEDURE RemoveTask( Result : Sync.TAsyncResult; Task : TPTask );
  PRIVATE PROCEDURE Completed( Result : Sync.TAsyncResult; Task : TPTask; PMSG : POINTER TO msghandler.Message; RemoveTask, DisposeTask : BOOLEAN );
END CPoolThread;

//================================================================================

CLASS IMPLEMENTATION CTask;
BEGIN
  Task := tskUnknown;
  UserId := 0;
  Delegate := NIL;
  Timeout := Sync.INFINITE_TIME;
  Data := NIL;
  HWait := Sync.CreateSignal( FALSE, L'' );
FINALLY
  IF Delegate <> NIL THEN
    Delegate^.Release();
  END;
  Sync.DeleteSignal( REF HWait );
END CTask;

//================================================================================

CLASS IMPLEMENTATION CTaskItem;

//--------------------------------------------------------------------------------

  PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;
  BEGIN
    IF i = 0 THEN
      IF PTR( Key ) < PTR( TPTaskItem( pelem )^.Key ) THEN
        RETURN -1;
      ELSIF PTR( Key ) > PTR( TPTaskItem( pelem )^.Key ) THEN
        RETURN 1;
      ELSE
        RETURN 0;
      END;
    ELSIF i = 1 THEN
      IF ElapsesOn < TPTaskItem( pelem )^.ElapsesOn THEN
        RETURN -1;
      ELSIF ElapsesOn > TPTaskItem( pelem )^.ElapsesOn THEN
        RETURN 1;
      ELSE
        RETURN 0;
      END;
    ELSE
      RETURN 1;
    END;
  END Compare;

  // OPERATOR CTaskItem.NEW() : ADDRESS;
  // VAR
  //   a : ADDRESS;
  // BEGIN
  //   IF TaskAllocator.Allocate( OUT a, SIZE( CTaskItem )) THEN
  //     RETURN a;
  //   ELSE
  //     RETURN NIL;
  //   END;
  // END CPtrItem.NEW;
  
  // OPERATOR CTaskItem.DISPOSE( a : ADDRESS );
  // BEGIN
  //   TaskAllocator.Deallocate( REF a );
  // END CTaskItem.DISPOSE;

//--------------------------------------------------------------------------------

BEGIN
  Key := NIL;
  Task := NIL;
  ElapsesOn := 0;
END CTaskItem;

//--------------------------------------------------------------------------------

CLASS IMPLEMENTATION CTaskMap;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE Add( Key : windows.HANDLE; Task : TPTask; Timeout : CARDINAL );
  VAR
    PI : TPTaskItem;
  BEGIN
    NEW( PI );
    PI^.Key := Key;
    PI^.Task := Task;
    IF Timeout = Sync.INFINITE_TIME THEN
      PI^.ElapsesOn := CARD64( Sync.INFINITE_TIME ) << 32 OR CARD64( Counter );
    ELSIF Timeout = 0 THEN
      PI^.ElapsesOn := CARD64( CurrentTime + 1 ) << 32 OR CARD64( Counter );
    ELSE
      PI^.ElapsesOn := CARD64( CurrentTime + Timeout ) << 32 OR CARD64( Counter );
    END;
    Insert( PI );
    INC( Counter );
  END Add;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE Remove( Key : windows.HANDLE );
  VAR
    I : CTaskItem;
  BEGIN
    I.Key := Key;
    Delete( ADR( I ));
  END Remove;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE Get( Key : windows.HANDLE; OUT Task : TPTask ) : BOOLEAN;
  VAR
    I : CTaskItem;
    PI : TPTaskItem;
  BEGIN
    I.Key := Key;
    IF NOT Search( ADR( I ), OUT PI ) THEN
      RETURN FALSE;
    END;
    Task := PI^.Task;
    RETURN TRUE;  
  END Get;

//--------------------------------------------------------------------------------

  LOCAL PROCEDURE GetTimeoutToFirstElapsed( TimeToCount : CARDINAL ) : CARDINAL;
  VAR
    Task : TPTask;
    Timeout : CARDINAL;
  BEGIN
    IF GetFirstWithTimeout( TimeToCount, OUT Task, OUT Timeout ) THEN
      RETURN Timeout;
    ELSE
      RETURN Sync.INFINITE_TIME;
    END;
  END GetTimeoutToFirstElapsed;

//--------------------------------------------------------------------------------

  LOCAL PROCEDURE GetFirstElapsed( OUT Task : TPTask ) : BOOLEAN;
  VAR
    Timeout : CARDINAL;
  BEGIN
    RETURN GetFirstWithTimeout( CurrentTime, OUT Task, OUT Timeout ) AND ( Timeout = 0 );
  END GetFirstElapsed;

//--------------------------------------------------------------------------------

  PRIVATE PROCEDURE GetFirstWithTimeout( CurrentTime : CARDINAL; OUT Task : TPTask; OUT Timeout : CARDINAL ) : BOOLEAN;
  VAR
    ElapsesOn : CARDINAL;
    TI : TPTaskItem;
  BEGIN
    IF NOT GetFirstI( 1, OUT TI ) THEN
      RETURN FALSE;
    END;
    ElapsesOn := CARDINAL( TI^.ElapsesOn >> 32 );
    IF ElapsesOn = Sync.INFINITE_TIME THEN
      RETURN FALSE;
    END;
    Task := TI^.Task;
    IF ElapsesOn <= CurrentTime THEN
      Timeout := 0;
    ELSE
      Timeout := ElapsesOn - CurrentTime;
    END;
    RETURN TRUE;
  END GetFirstWithTimeout;

//--------------------------------------------------------------------------------

BEGIN
  Counter := 0;
  Indexes := 2;
  CurrentTime := 0;
END CTaskMap;

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
                 HTask : Sync.WAITABLE;
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
    RETURN Handles.Empty AND Messages.Empty AND Workers.Empty AND MQueue.Empty;
  END Empty;

//--------------------------------------------------------------------------------

  LOCAL READONLY PROPERTY AbleWait GET : BOOLEAN;
  BEGIN
    RETURN ( Workers.Count + PendingWorkers = 0 ) AND ( Handles.Count + PendingHandles < windows.MAXIMUM_WAIT_OBJECTS-2 );
  END AbleWait;

//--------------------------------------------------------------------------------

  LOCAL READONLY PROPERTY AbleRunWorkers GET : BOOLEAN;
  BEGIN
    RETURN ( Handles.Count + PendingHandles = 0 ) AND Messages.Empty AND ( Workers.Count + PendingWorkers < Pool^.WorkerLoad );
  END AbleRunWorkers;

//--------------------------------------------------------------------------------

  INTERNAL VIRTUAL PROCEDURE OnRun() : CARDINAL;
  VAR
    CheckEmpty : BOOLEAN;
    D : PTR;
    HandleList : lists.TPPtrList;
    Message : TMessage;
    msg : windows.MSG;
    MSG : msghandler.Message;
    Status : CARDINAL;
    Task, NextTask : TPTask;
    Timeout : CARDINAL;
    Worker : TPPoolWorker;
    b : BOOLEAN;
  BEGIN
    Messager.Init();
    WaitArray.Add( _HExit );
    
    LOOP
      CheckEmpty := FALSE;
      IF Workers.Empty THEN
        Timeout := HTasks.GetTimeoutToFirstElapsed( windows.GetTickCount());
      ELSE
        Timeout := 0;
      END;
      Status := windows.MsgWaitForMultipleObjectsEx( WaitArray.Count, WaitArray.Data, Timeout, windows.QS_ALLINPUT, windows.MWMO_INPUTAVAILABLE );
      HTasks.CurrentTime := windows.GetTickCount();
      CASE Status OF
      | CARDINAL( windows.WAIT_FAILED ), windows.WAIT_ABANDONED : // some handle failed, this MUST not occur
        Status := windows.GetLastError();
        ASSERT( FALSE );
        EXIT;
      | windows.WAIT_OBJECT_0 : // graceful EXIT
        EXIT;
      | windows.WAIT_TIMEOUT : // remove all timeouted tasks
        WHILE HTasks.GetFirstElapsed( OUT Task ) DO
          CASE Task^.Task OF
          | tskTimeoutOnce :
            Completed( Sync.arCompleted, Task, NIL, TRUE, TRUE );
            CheckEmpty := TRUE;
          | tskTimeoutRepeated :
            Completed( Sync.arCompleted, Task, NIL, TRUE, FALSE );
            AddTask( Task );
          ELSE
            RemoveTask( Sync.arTimeout, Task );
            CheckEmpty := TRUE;
          END;
        END;
      ELSE
        DEC( Status, windows.WAIT_OBJECT_0 );
      END;

      IF Status = WaitArray.Count THEN // a message has arrived
        WHILE windows.PeekMessage( ADR( msg ), NIL, 0, 0, windows.PM_REMOVE ) <> 0 DO
          IF msg.message = msgqueue.WM_MQ_PROCESS THEN // administrative message
          
            WHILE MQueue.DequeueOA( OUT Message ) DO
              CASE Message.Operation OF
              //---
              | topAdd :
                AddTask( Message.Task );
              //---
              | topRemoveTask :
                IF HTasks.Get( Message.HTask, OUT Task ) THEN
                  RemoveTask( Sync.arAborted, Task );
                  CheckEmpty := TRUE;
                END;
              //---
              | topRemoveDelegate : // NOT IMPLEMENTED YET
                ASSERT( FALSE );
              //---
              ELSE
                ASSERT( FALSE );
              END; // CASE
            END; // WHILE
          
          ELSIF Messages.Get( msg.message, OUT Task ) THEN // known waited message
            MSG[1] := msg.message; MSG[2] := msg.wParam; MSG[3] := PTR( msg.lParam );
            Completed( Sync.arCompleted, Task, ADR( MSG ), Task^.Task = tskMessageOnce, FALSE );
            IF Task^.Task = tskMessageOnce THEN
              Messages.Remove( Task^.Data );
              DISPOSE( Task );
            END;
            CheckEmpty := TRUE;

          END;
        END; // end of messages

      ELSIF ( Status < WaitArray.Count ) AND ( Handles.Get( WaitArray[Status], OUT HandleList )) THEN // handle is signalized
        b := HandleList^.GetFirst( OUT Task, OUT D );
        WHILE b DO
          b := HandleList^.NextOf( Task, OUT NextTask, OUT D );
          Completed( Sync.arCompleted, Task, NIL, Task^.Task = tskHandleOnce, FALSE );
          IF Task^.Task = tskHandleOnce THEN
            HandleList^.Remove( Task );
            DISPOSE( Task );
          END; // IF tskHandleOnce
          Task := NextTask;
        END; // WHILE
        IF HandleList^.Empty THEN
          DISPOSE( HandleList );
          Handles.Remove( WaitArray[Status] );
          WaitArray.RemoveIndex( Status );
          CheckEmpty := TRUE;
        END;

      END; // IF WaitResult
      
      // Run Workers
      IF Workers.GetFirst( OUT Worker, OUT Task ) THEN
        Workers.Remove( Worker );
        Worker^.Run();
        Completed( Sync.arCompleted, Task, NIL, TRUE, TRUE );
        Worker^.Release();
        IF Workers.Empty THEN // continue with self, but after checking or processing messages and exit event
          CheckEmpty := TRUE;
        END;
      END;
      
      IF CheckEmpty AND Empty THEN
        Pool^.OnThreadEmpty();
      END;
    END; // LOOP
    
    Messager.Dispose();
    RETURN 0;
  END OnRun;

//--------------------------------------------------------------------------------

  PRIVATE PROCEDURE AddTask( Task : TPTask );
  VAR
    HandleList : lists.TPPtrList;
  BEGIN
    HTasks.Add( Task^.HWait, Task, Task^.Timeout );
    CASE Task^.Task OF
    | tskTimeoutOnce, tskTimeoutRepeated :
      // do nothing
    | tskMessageOnce, tskMessageRepeated :
      Messages.Add( Task^.Data, Task );
    | tskHandleOnce, tskHandleRepeated :
      IF NOT Handles.Get( Task^.Data, OUT HandleList ) THEN
        NEW( HandleList );
        Handles.Add( Task^.Data, HandleList );
        WaitArray.Add( Task^.Data );
      END;
      HandleList^.Add( Task, 0 );
      Sync.IDec( REF PendingHandles );
    | tskWorker :
      Workers.Add( Task^.Data, Task );
      Sync.IDec( REF PendingWorkers );
    ELSE
      ASSERT( FALSE );
    END; // CASE
  END AddTask;

//--------------------------------------------------------------------------------

  PRIVATE PROCEDURE RemoveTask( Result : Sync.TAsyncResult; Task : TPTask );
  VAR
    HandleList : lists.TPPtrList;
  BEGIN
    CASE Task^.Task OF
    | tskTimeoutOnce, tskTimeoutRepeated :
      // do nothing
    | tskMessageOnce, tskMessageRepeated :
      Messages.Remove( Task^.Data );
    | tskHandleOnce, tskHandleRepeated :
      IF Handles.Get( Task^.Data, OUT HandleList ) THEN
        HandleList^.Remove( Task );
        IF HandleList^.Empty THEN
          DISPOSE( HandleList );
          Handles.Remove( Task^.Data );
          WaitArray.Remove( Task^.Data );
        END;
      END;
    | tskWorker :
      Workers.Remove( Task^.Data );
      TPPoolWorker( Task^.Data )^.Release();
    ELSE
      ASSERT( FALSE );
    END; // CASE
    Completed( Result, Task, NIL, TRUE, TRUE );
  END RemoveTask;

//--------------------------------------------------------------------------------

  PRIVATE PROCEDURE Completed( Result : Sync.TAsyncResult; Task : TPTask; PMSG : msghandler.TPMessage; RemoveTask, DisposeTask : BOOLEAN );
  VAR
    Disposable : BOOLEAN;
    MSG : msghandler.Message;
  BEGIN
    IF RemoveTask THEN
      HTasks.Remove( Task^.HWait );
    ELSE
      DisposeTask := FALSE; // for safety
    END;
    IF Result = Sync.arCompleted THEN
      windows.PulseEvent( Task^.HWait );
    END;
    IF Pool = NIL THEN
      Disposable := TRUE;
    ELSIF PMSG = NIL THEN
      Disposable := Pool^.OnCompletion( Result, Task, MSG );
    ELSE
      Disposable := Pool^.OnCompletion( Result, Task, PMSG^ );
    END;
    IF DisposeTask AND Disposable THEN
      DISPOSE( Task );
    END;
  END Completed;

//--------------------------------------------------------------------------------

  INITIALLY CPoolThread();
  BEGIN
    Pool := NIL;
    MQueue.Init( 128, SIZE( TMessage ));
    MQueue.FlushIfFull := TRUE;
    MQueue.Consumer := ADR( Messager );
    WithMessages := TRUE;
    WaitArray.Strategy := array.astrgListInArray;
    PendingHandles := 0; ASSERT( PTR( ADR( PendingHandles )) AND 03H = 0 );
    PendingWorkers := 0; ASSERT( PTR( ADR( PendingWorkers )) AND 03H = 0 );
  END CPoolThread;

//--------------------------------------------------------------------------------

  FINALLY CPoolThread();
  VAR
    Task : TPTask;
  BEGIN
    Handles.Reset();
    WHILE Handles.MoveNext() DO
      lists.TPPtrList( Handles.CurrentData )^.Reset();
      WHILE lists.TPPtrList( Handles.CurrentData )^.MoveNext() DO
        Completed( Sync.arAborted, lists.TPPtrList( Handles.CurrentData )^.Current, NIL, TRUE, TRUE );
      END; // WHILE
      DISPOSE( lists.TPPtrList( Handles.CurrentData ));
    END; // WHILE
    Messages.Reset();
    WHILE Messages.MoveNext() DO
      Completed( Sync.arAborted, Messages.CurrentData, NIL, TRUE, TRUE );
    END; // WHILE
    Workers.Reset();
    WHILE Workers.MoveNext() DO
      Completed( Sync.arAborted, Workers.CurrentData, NIL, TRUE, TRUE );
      TPPoolWorker( Workers.Current )^.Release();
    END; // WHILE
    WHILE HTasks.GetFirstElapsed( OUT Task ) DO
      Completed( Sync.arAborted, Task, NIL, TRUE, TRUE );
    END; // WHILE
  END CPoolThread;

//--------------------------------------------------------------------------------

END CPoolThread;

//================================================================================

CLASS IMPLEMENTATION CThreadPool;

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
    | msgqueue.WM_MQ_PROCESS :
      WHILE MQueue.DequeueOA( OUT Message ) DO
        CASE Message.Operation OF
        //---
        | topOnThreadEmpty : // if possible, remove thread
          DisposeThreads( TRUE );
        //---
        | topOnCompletion :
          OnCompletion( Message.Result, Message.Task, Message.MSG );
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

  PUBLIC PROCEDURE WaitTimeout( CONST Delegate : TPPoolDelegate; UserId : PTR; TimeoutMS : CARDINAL; WaitOnce : BOOLEAN; OUT PoolHandle : Sync.WAITABLE ) : BOOLEAN;
  VAR
    MSG : TMessage;
    PoolThread : TPPoolThread;
  BEGIN
    IF NOT LookupThread( FALSE, OUT PoolThread ) THEN
      RETURN FALSE;
    END;

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

    // return value
    PoolHandle := MSG.Task^.HWait;

    PoolThread^.MQueue.QueueOA( MSG );
    RETURN TRUE;
  END WaitTimeout;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE WaitMessage( CONST Delegate : TPPoolDelegate; UserId : PTR; TimeoutMS : CARDINAL; WaitOnce : BOOLEAN; OUT Handler : msghandler.TPMessageHandler; OUT Message : msghandler.Message; OUT PoolHandle : Sync.WAITABLE ) : BOOLEAN;
  VAR
    MSG : TMessage;
    PoolThread : TPPoolThread;
  BEGIN
    IF NOT LookupThread( FALSE, OUT PoolThread ) THEN
      RETURN FALSE;
    END;

    IF Delegate <> NIL THEN
      Delegate^.AddRef();
    END;
    MSG.Operation := topAdd;

    NEW( MSG.Task );
    IF WaitOnce THEN
      MSG.Task^.Task := tskMessageOnce;
    ELSE
      MSG.Task^.Task := tskMessageRepeated;
    END;
    MSG.Task^.UserId := UserId;
    MSG.Task^.Delegate := Delegate;
    MSG.Task^.Timeout := TimeoutMS;
    MSG.Task^.Data := PTR( MSG.Task^.HWait ) + msgqueue.WM_MQ_PROCESS;

    // return values
    PoolHandle := MSG.Task^.HWait;
    Message[1] := MSG.Task^.Data;
    Handler := ADR( PoolThread^.Messager );

    PoolThread^.MQueue.QueueOA( MSG );
    RETURN TRUE;
  END WaitMessage;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE WaitHandle( CONST Delegate : TPPoolDelegate; UserId : PTR; TimeoutMS : CARDINAL; WaitOnce : BOOLEAN; Handle : windows.HANDLE; OUT PoolHandle : Sync.WAITABLE ) : BOOLEAN;
  VAR
    MSG : TMessage;
    PoolThread : TPPoolThread;
  BEGIN
    IF NOT LookupThread( FALSE, OUT PoolThread ) THEN
      RETURN FALSE;
    END;

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

    // return value
    PoolHandle := MSG.Task^.HWait;

    Sync.IInc( REF PoolThread^.PendingHandles );
    PoolThread^.MQueue.QueueOA( MSG );
    RETURN TRUE;
  END WaitHandle;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE RunWorker( CONST Delegate : TPPoolDelegate; UserId : PTR; TimeoutMS : CARDINAL; Worker : TPPoolWorker; OUT PoolHandle : Sync.WAITABLE ) : BOOLEAN;
  VAR
    MSG : TMessage;
    PoolThread : TPPoolThread;
  BEGIN
    IF NOT LookupThread( TRUE, OUT PoolThread ) THEN
      RETURN FALSE;
    END;

    IF Delegate <> NIL THEN
      Delegate^.AddRef();
    END;
    Worker^.AddRef();
    MSG.Operation := topAdd;

    NEW( MSG.Task );
    MSG.Task^.Task := tskWorker;
    MSG.Task^.UserId := UserId;
    MSG.Task^.Delegate := Delegate;
    MSG.Task^.Timeout := TimeoutMS;
    MSG.Task^.Data := Worker;

    // return value
    PoolHandle := MSG.Task^.HWait;

    Sync.IInc( REF PoolThread^.PendingWorkers );
    PoolThread^.MQueue.QueueOA( MSG );
    RETURN TRUE;
  END RunWorker;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE WaitCompletion( PoolHandle : Sync.WAITABLE; Timeout : CARDINAL ) : Sync.TAsyncResult;
  BEGIN
    RETURN Sync.Wait( PoolHandle, Timeout );
  END WaitCompletion;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE Abort( REF PoolHandle : Sync.WAITABLE );
  VAR
    MSG : TMessage;
  BEGIN
    MSG.Operation := topRemoveTask;
    MSG.HTask := PoolHandle;
    Threads.Reset();
    WHILE Threads.MoveNext() DO
      TPPoolThread( Threads.Current )^.MQueue.QueueOA( MSG );
    END; // WHILE
    PoolHandle := NIL;
  END Abort;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE AbortAll( CONST Delegate : TPPoolDelegate );
  VAR
    MSG : TMessage;
  BEGIN
    MSG.Operation := topRemoveDelegate;
    MSG.Delegate := Delegate;
    Threads.Reset();
    WHILE Threads.MoveNext() DO
      TPPoolThread( Threads.Current )^.MQueue.QueueOA( MSG );
    END; // WHILE
  END AbortAll;

//--------------------------------------------------------------------------------

  LOCAL PROCEDURE OnThreadEmpty();
  VAR
    LMSG : TMessage;
  BEGIN
    LMSG.Operation := topOnThreadEmpty;
    MQueue.QueueOA( LMSG ); 
  END OnThreadEmpty;

//--------------------------------------------------------------------------------

  LOCAL PROCEDURE OnCompletion( Result : Sync.TAsyncResult; _Task : PTR; CONST MSG : msghandler.Message ) : BOOLEAN;
  // !! returns if Task can be disposed
  VAR
    LMSG : TMessage;
    Task : TPTask := TPTask( _Task );
  BEGIN
    IF Task^.Delegate = NIL THEN
      RETURN TRUE;
    ELSIF ( msghandler.CurrentThread() = OfThread ) OR NOT CompletionInOwningThread THEN
      CASE Task^.Task OF
      | tskTimeoutOnce, tskTimeoutRepeated :
        Task^.Delegate^.OnTimeout( Result, Task, Task^.UserId );
      | tskMessageOnce, tskMessageRepeated :
        Task^.Delegate^.OnMessage( Result, Task, Task^.UserId, MSG );
      | tskHandleOnce, tskHandleRepeated :
        Task^.Delegate^.OnHandle( Result, Task, Task^.UserId );
      | tskWorker :
        Task^.Delegate^.OnWorker( Result, Task, Task^.UserId );
      END;
      RETURN TRUE;
    ELSE
      LMSG.Operation := topOnCompletion;
      LMSG.Result := Result;
      LMSG.Task := Task;
      LMSG.MSG := MSG;
      MQueue.QueueOA( LMSG ); 
      RETURN FALSE;
    END;
  END OnCompletion;

//--------------------------------------------------------------------------------

  PRIVATE PROCEDURE LookupThread( WorkerFlag : BOOLEAN; OUT _PoolThread : PTR ) : BOOLEAN;
  VAR
    PoolThread : TPPoolThread;
  BEGIN
    Threads.Reset();
    WHILE Threads.MoveNext() DO
      IF     WorkerFlag AND TPPoolThread( Threads.Current )^.AbleRunWorkers OR
         NOT WorkerFlag AND TPPoolThread( Threads.Current )^.AbleWait THEN
        _PoolThread := TPPoolThread( Threads.Current );
        RETURN TRUE;
      END; // IF
    END; // WHILE
    IF Threads.Count >= MaxThreads THEN
      _PoolThread := NIL;
      RETURN FALSE;
    END;

    NEW( PoolThread );
    PoolThread^.Init( ADR( SELF ));
    Threads.Add( PoolThread, 0 );

    PoolThread^.Run( FALSE ); // not wait here, we wait before SendMsg
    WHILE PoolThread^.Messager.Handle = NIL DO // thread has not start yet
      windows.Sleep( 0 );
    END; // IF

    _PoolThread := PoolThread;
    RETURN TRUE;
  END LookupThread;

//--------------------------------------------------------------------------------

  PRIVATE PROCEDURE DisposeThreads( RespectMinThreads : BOOLEAN );
  VAR
    PoolThread : TPPoolThread;
    b : BOOLEAN;
  BEGIN
    Threads.Reset();
    b := Threads.MoveNext();
    WHILE b DO
      IF RespectMinThreads AND ( Threads.Count <= _MinThreads ) THEN // kill not needed threads
        EXIT;
      END;
      PoolThread := TPPoolThread( Threads.Current );
      b := Threads.MoveNext();
      IF NOT RespectMinThreads OR PoolThread^.Empty THEN
        Threads.Remove( PoolThread );
        PoolThread^.Stop( TRUE );
        DISPOSE( PoolThread );
      END;
    END; // WHILE
  END DisposeThreads;

//--------------------------------------------------------------------------------

BEGIN
  _MinThreads := 1;
  WorkerLoad := 32;
  MaxThreads := -1;
  SingleThreadInterface := TRUE;
  CompletionInOwningThread := FALSE;
  Init();
  MQueue.Init( 128, SIZE( TMessage ));
  MQueue.FlushIfFull := TRUE;
  MQueue.Consumer := ADR( SELF );
FINALLY
  DisposeThreads( FALSE );
END CThreadPool;

//================================================================================

END threadpool.