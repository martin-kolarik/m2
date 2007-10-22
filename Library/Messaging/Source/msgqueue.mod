IMPLEMENTATION MODULE msgqueue;

FROM Storage IMPORT
  ALLOCATE, DEALLOCATE, REALLOCATE;
IMPORT
  Storage,
  windows;

(*================================================================================*)

CLASS IMPLEMENTATION CMessageQueue;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY FlushIfFull GET : BOOLEAN;
  BEGIN
    RETURN moFlushIfFull IN Options;
  END FlushIfFull;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY FlushIfFull SET( Value : BOOLEAN );
  BEGIN
    IF Value THEN
      INCL( Options, moFlushIfFull )
    ELSE
      EXCL( Options, moFlushIfFull )
    END;
  END FlushIfFull;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROPERTY Size GET : CARDINAL;
  BEGIN
    RETURN SUPER.Size;
  END Size;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROPERTY Size SET( Value : CARDINAL );
  BEGIN
    SUPER.Size := Value;
    IF ItemISize * _Size > 0 THEN
      REALLOCATE( Data, ItemISize * _Size );
      Storage.Zero( Data, ItemISize * _Size );
    END;
  END Size;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROPERTY ItemSize GET : CARDINAL;
  BEGIN
    IF ItemISize = 0 THEN
      RETURN 0;
    ELSE
      RETURN ItemISize - SIZE( CARDINAL );
    END;
  END ItemSize;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROPERTY ItemSize SET( Value : CARDINAL );
  BEGIN
    ItemISize := ( Value + SIZE( CARDINAL ) + 7 ) AND NOT 7;
    IF ItemISize * _Size > 0 THEN
      REALLOCATE( Data, ItemISize * _Size );
      Storage.Zero( Data, ItemISize * _Size );
    END;
  END ItemSize;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY ConsumerMsg GET : POINTER TO msghandler.Message;
  BEGIN
    RETURN Msg;
  END ConsumerMsg;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY ConsumerMsg SET( Value : POINTER TO msghandler.Message );
  BEGIN
    IF Msg <> NIL THEN
      DISPOSE( Msg );
    END;
    Msg := msghandler.TPMessage( Value^.Clone());
  END ConsumerMsg;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Init( QueueSize, MessageSize : CARDINAL );
  BEGIN
    Size := QueueSize;
    ItemSize := MessageSize;
  END Init;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Dequeue( MessageBuffer : ADDRESS; MessageBufferLen : CARDINAL ) : BOOLEAN; // returns if data get
  VAR
    Block : CARDINAL;
  BEGIN
    IF NOT StartConsuming( OUT Block ) THEN
      RETURN FALSE;
    END;
    Storage.Move( Data@[ Block*ItemISize + SIZE( CARDINAL )], MessageBuffer, MIN2( ItemISize-SIZE( CARDINAL ), MessageBufferLen ));
    CommitConsuming();
    RETURN TRUE;
  END Dequeue;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE DequeueOA( OUT Message : ARRAY OF BYTE ) : BOOLEAN;
  BEGIN
    RETURN Dequeue( ADR( Message ), HIGH( Message )+1 );
  END DequeueOA;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Queue( Message : ADDRESS; MessageLen : CARDINAL ) : BOOLEAN; // returns if added, MANY threads
  VAR
    Block : CARDINAL;
  BEGIN
    IF MessageLen > ItemISize - SIZE( CARDINAL ) THEN
      RETURN FALSE;
    ELSIF MessageLen = 0 THEN
      RETURN FALSE;
    ELSIF NOT StartProducing( OUT Block ) THEN
      RETURN FALSE;
    ELSE // now Block is allocated index, move data
      Storage.Move( Message, Data@[ Block*ItemISize + SIZE( CARDINAL )], MessageLen );
      CommitProducing( Block );
      RETURN TRUE;
    END;
  END Queue;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE QueueOA( CONST Message : ARRAY OF BYTE ) : BOOLEAN;
  BEGIN
    RETURN Queue( ADR( Message ), MIN2( ItemISize-SIZE( CARDINAL ), HIGH( Message )+1 ));
  END QueueOA;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE PushToConsumer() : Sync.TAsyncResult;
  BEGIN
    RETURN Flush();
  END PushToConsumer;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE Flush() : Sync.TAsyncResult; // completed, timeout, aborted
  BEGIN
    IF NOT( moFlushIfFull IN Options ) THEN
      RETURN Sync.arCompleted;
    ELSIF Consumer = NIL THEN
      windows.Sleep( 0 );
    ELSIF msghandler.CurrentThread() = Consumer^.OfThread THEN // consumer is in my thread
      IF Msg = NIL THEN
        NEW( msghandler.TPMessage( Msg )); Msg^.Message := WM_MQ_PROCESS;
      END;
      INCL( Options, moLeaveLock );
      IF NOT Consumer^.Message( Msg^, msghandler.delSynchronous, NIL ) THEN
        ASSERT( FALSE );
      END;
      EXCL( Options, moLeaveLock );
    ELSE // consumer is in the other thread
      windows.Sleep( 0 );
    END;
    RETURN Sync.arCompleted;
  END Flush;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE Validate( Block : CARDINAL );
  BEGIN
    Sync.IExchg( REF PCARD32( INC( Data, Block*ItemISize ))^, 1 );
  END Validate;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE IsValid( Block : CARDINAL ) : BOOLEAN;
  BEGIN
    RETURN Sync.IExchgAdd( REF PCARD32( INC( Data, Block*ItemISize ))^, 0 ) = 1;
  END IsValid;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE Invalidate( Block : CARDINAL );
  BEGIN
    Sync.IExchg( REF PCARD32( INC( Data, Block*ItemISize ))^, 0 );
  END Invalidate;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE Signal( What : Sync.TpcqSignal ); // when produced, next producing SHOULD NOT be done (until signalling consumed)
  BEGIN
    CASE What OF
    | Sync.pcqProduced :
      IF Sync.IExchg( REF DoConsume, 1 ) = 0 THEN
        IF Consumer <> NIL THEN
          IF Msg = NIL THEN
            NEW( msghandler.TPMessage( Msg )); Msg^.Message := WM_MQ_PROCESS;
          END;
          IF NOT Consumer^.Message( Msg^, msghandler.delAsynchronous, NIL ) THEN
            ASSERT( FALSE );
          END;
        END;
        Sync.Signal( Consume );
      END;
    | Sync.pcqStartingConsumation :
      IF moLeaveLock IN Options THEN
        // skip, do nothing
      ELSIF Sync.IExchg( REF DoConsume, 0 ) = 1 THEN
        Sync.Reset( Consume );
      END;
    END; // CASE
  END Signal;

(*--------------------------------------------------------------------------------*)

BEGIN
  DoConsume := 0;
  Options := TMQOptions{};
  Data := NIL;
  ItemISize := 0;
  Msg := NIL;
  Consume := NIL;
  Consumer := NIL;
FINALLY
  IF Data <> NIL THEN
    DISPOSE( Data );
  END;
  IF Msg <> NIL THEN
    DISPOSE( Msg );
  END;
END CMessageQueue;

(*================================================================================*)

END msgqueue.