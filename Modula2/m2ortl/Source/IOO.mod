IMPLEMENTATION MODULE IOO;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE, REALLOCATE, Move;
  
IMPORT
   Storage;
  
(*================================================================================*)

CLASS IMPLEMENTATION CIOException;

   PUBLIC PROCEDURE Init( NestedException : POINTER TO Exceptions.Exception; CONST Originator, Text : ARRAY OF WCHAR; ErrorCode : CARDINAL ) : CIOException;
   BEGIN
      SELF.ErrorCode := ErrorCode;
      SUPER.Init( NestedException, Originator, Text );
      RETURN SELF;
   END Init;

   INTERNAL VIRTUAL PROCEDURE Name( OUT S : ARRAY OF WCHAR );
   BEGIN
      ASSIGN( S, EMITW( %class ));
   END Name;

BEGIN
END CIOException;

(*--------------------------------------------------------------------------------*)

PROCEDURE IOException( NestedException : POINTER TO Exceptions.Exception; CONST Originator, Text : ARRAY OF WCHAR; ErrorCode : CARDINAL ) : CIOException;
VAR
   IOE : CIOException;
BEGIN
   IOE.Init( NestedException, Originator, Text, ErrorCode );
   RETURN IOE;
END IOException;

(*================================================================================*)

CLASS IMPLEMENTATION ADataInfo;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE OnError( Direction : TDirection; Error : CARDINAL; Source : ADDRESS; SourceSpecificCode : LONGWORD );
  BEGIN
  END OnError;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE OnFlowPossible( Direction : TDirection; Source : ADDRESS );
  BEGIN
  END OnFlowPossible;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE OnReadable( Length : CARDINAL; Source : ADDRESS );
  BEGIN
  END OnReadable;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE OnWritten( Length : CARDINAL; Source : ADDRESS );
  BEGIN
  END OnWritten;

(*--------------------------------------------------------------------------------*)

END ADataInfo;

(*================================================================================*)

CLASS IMPLEMENTATION ADataProxy;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY Waitable GET : BOOLEAN;
  BEGIN
    RETURN _Signal.RawHandle = NIL;
  END Waitable;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY Waitable SET( Value : BOOLEAN );
  BEGIN
    IF Value = Waitable THEN
      RETURN;
    END;
    IF Value THEN
      _Signal.Init( Sync.stEventAutoreset, L"", FALSE );
    ELSE
      _Signal.Dispose();
    END;
  END Waitable;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY Completed GET : BOOLEAN;
  BEGIN
    RETURN NOT _Lock.In( REF _Status, dpsPending );
  END Completed;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROPERTY SignalsCompleteData GET : BOOLEAN; // if TRUE then both DeviceFinish/CompleteData causes Signal
  BEGIN
    RETURN FALSE;
  END SignalsCompleteData;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Start(); // prepares waiting, clears Result
  BEGIN
    _Lock.Lock();
      INCL( _Status, dpsPending );
      Result := Sync.arUnknown;
    _Lock.Unlock();

    Reset();
  END Start;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE WaitCompletion( TimeoutMS : CARDINAL ) : Sync.TAsyncResult;
  VAR
    LResult : Sync.TAsyncResult;
  BEGIN
    LResult := _Signal.Wait( TimeoutMS );
    IF LResult = Sync.arCompleted THEN
      RETURN Sync.TAsyncResult( _Lock.Get( REF Result ));
    ELSE
      RETURN LResult;
    END;
  END WaitCompletion;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE PrepareData( OUT Prepared : ADDRESS; OUT Length : CARDINAL ) : BOOLEAN;
  BEGIN
    RETURN FALSE;
  END PrepareData;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE CompleteData( Completed : CARDINAL );
  BEGIN
  END CompleteData;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Signal();
  BEGIN
    _Signal.Signal();
  END Signal;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Reset();
  BEGIN
    _Signal.Reset();
  END Reset;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE DeviceFinish( Result : Sync.TAsyncResult );
  BEGIN
    _Lock.Lock();
      SELF.Result := Result;
      EXCL( _Status, dpsPending );
    _Lock.Unlock();

    Signal();

    IF NOT Persistent THEN
      Release();
    END;
  END DeviceFinish;

(*--------------------------------------------------------------------------------*)

BEGIN
  _Status := TDataProxyStatus{};
  _Lock.Init( Sync.ltSpin, L"", FALSE );
  Result := Sync.arCannotStart;
FINALLY
  _Signal.Dispose();
END ADataProxy;

(*================================================================================*)

CLASS IMPLEMENTATION CMemoryProxy;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROPERTY Processed GET : CARDINAL; // count of read/written data
  BEGIN
    RETURN _Ptr;
  END Processed;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Init( Data : ADDRESS; Length : CARDINAL; CreatePrivateBuffer : BOOLEAN );
  BEGIN
    _Length := Length;
    _Ptr := 0;
    IF CreatePrivateBuffer THEN
      _Private := TRUE;
      REALLOCATE( _Data, Length );
      Move( Data, _Data, Length );
    ELSE
      IF _Private THEN
        _Private := FALSE;
        DISPOSE( _Data );
      END;
      _Data := Data;
    END;
  END Init;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE InitBuffer( CONST Buffer : StorageO.AMemoryBuffer; CreateCopy : BOOLEAN );
  BEGIN
    Init( Buffer.Data, Buffer.Length, CreateCopy );
  END InitBuffer;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE PrepareData( OUT Prepared : ADDRESS; OUT Length : CARDINAL ) : BOOLEAN;
  BEGIN
    Prepared := _Data@[_Ptr];
    Length := _Length-_Ptr;
    RETURN Length > 0;
  END PrepareData;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE CompleteData( Completed : CARDINAL );
  BEGIN
    _Ptr := MIN2( _Length, _Ptr + Completed );
  END CompleteData;
  
(*--------------------------------------------------------------------------------*)

BEGIN
  _Private := FALSE;
  _Data := NIL;
  _Length := 0;
  _Ptr := 0;
FINALLY
  IF _Private THEN
    DISPOSE( _Data );
  END;
END CMemoryProxy;

(*================================================================================*)

CLASS IMPLEMENTATION CDatagramProxy;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROPERTY Processed GET : CARDINAL; // count of read/written data
  BEGIN
    RETURN _Ptr - SIZE( CARDINAL );
  END Processed;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE PrepareData( OUT Prepared : ADDRESS; OUT Length : CARDINAL ) : BOOLEAN; // TRUE == have next data
  BEGIN
    IF _Ptr < SIZE( CARDINAL ) THEN
      Prepared := ADR( _Length )@[ _Ptr ];
      Length := SIZE( CARDINAL ) - _Ptr;
    ELSE
      Prepared := _Data@[ _Ptr - SIZE( CARDINAL ) ];
      Length := _Length - _Ptr + SIZE( CARDINAL );
    END;
    RETURN Length > 0;
  END PrepareData;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE CompleteData( Completed : CARDINAL );
  BEGIN
    IF _Ptr < SIZE( CARDINAL ) THEN
      ASSERT( _Ptr + Completed <= SIZE( CARDINAL ));
      _Ptr := MIN2( SIZE( CARDINAL ), _Ptr + Completed );
    ELSE
      _Ptr := MIN2( _Length + SIZE( CARDINAL ), _Ptr + Completed );
    END;
  END CompleteData;

(*--------------------------------------------------------------------------------*)

END CDatagramProxy;

(*================================================================================*)

CLASS IMPLEMENTATION CRingBufferProxy;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROPERTY Processed GET : CARDINAL; // count of read/written data
  BEGIN
    RETURN 0;
  END Processed;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROPERTY SignalsCompleteData GET: BOOLEAN; // if TRUE then both DeviceFinish/CompleteData causes Signal
  BEGIN
    RETURN TRUE;
  END SignalsCompleteData;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE PrepareData( OUT Prepared : ADDRESS; OUT Length : CARDINAL ) : BOOLEAN; // TRUE == have next data
  BEGIN
    CASE Direction OF
    | dirRead :
      RETURN RingBuffer^.StartWriting( MAX( CARDINAL ), OUT Prepared, OUT Length );
    | dirWrite :
      RETURN RingBuffer^.StartReading( MAX( CARDINAL ), OUT Prepared, OUT Length );
    END; // CASE
    RETURN FALSE;
  END PrepareData;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE CompleteData( Completed : CARDINAL );
  BEGIN
    CASE Direction OF
    | dirRead :
      RingBuffer^.CommitWriting( Completed );
    | dirWrite :
      RingBuffer^.CommitReading( Completed );
    END; // CASE
    _Signal.Signal();
  END CompleteData;

(*--------------------------------------------------------------------------------*)

BEGIN
  RingBuffer := NIL;
END CRingBufferProxy;

(*================================================================================*)

CLASS IMPLEMENTATION AStream;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY Length32 GET : CARD32;
  BEGIN
    RETURN CARD32( Length );
  END Length32;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY Length32 SET( Value : CARD32 );
  BEGIN
    Length := CARD64( Value );
  END Length32;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY Position32 GET : CARD32;
  BEGIN
    RETURN CARD32( Position );
  END Position32;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY Position32 SET( Value : CARD32 );
  BEGIN
    Position := CARD64( Value );
  END Position32;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY AtEnd GET : BOOLEAN;
  BEGIN
    RETURN Position = Length;
  END AtEnd;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY Reading GET : BOOLEAN;
  BEGIN
    RETURN Sync.IGetPtr( REF Reader ) <> NIL;
  END Reading;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY Writing GET : BOOLEAN;
  BEGIN
    RETURN Sync.IGetPtr( REF Writer ) <> NIL;
  END Writing;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL FINALLY AStream();
  BEGIN
  END AStream;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Read( _Reader : TPDataProxy; TimeoutMS : CARDINAL; WaitForResult : BOOLEAN ) : Sync.TAsyncResult;
  BEGIN
    RETURN IO( dirRead, _Reader, TimeoutMS, WaitForResult );
  END Read;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ReadOA( REF Data : ARRAY OF BYTE; OUT Filled : CARDINAL; TimeoutMS : CARDINAL ) : Sync.TAsyncResult;
   VAR
      Chunk : CMemoryProxy; // by default persistent
      R : Sync.TAsyncResult;
   BEGIN
      Chunk.Init( ADR( Data ), HIGH( Data )+1, FALSE );
      R := IO( dirRead, ADR( Chunk ), TimeoutMS, TRUE );
      WHILE Chunk.References > 1 DO
         Sync.Sleep( 0 );
      END; // WHILE
      Filled := Chunk.Processed;
      RETURN R;
   END ReadOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ReadBuffer( MaximalReadLength : CARDINAL; REF Data : StorageO.AMemoryBuffer; TimeoutMS : CARDINAL ) : Sync.TAsyncResult;
   VAR
      a : ADDRESS;
      l : CARDINAL := Data.Length;
      R : Sync.TAsyncResult;
   BEGIN
      Data.Size := l + MaximalReadLength; // reserve space
      a := Data.Data@[l];
      R := ReadOA( REF OA( MaximalReadLength-1, a ), OUT l, TimeoutMS );
      INC( Data.Length, l );
      RETURN R;
   END ReadBuffer;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE AbortReading();
  BEGIN
    Abort( dirRead );
  END AbortReading;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Write( _Writer : TPDataProxy; TimeoutMS : CARDINAL; WaitForResult : BOOLEAN ) : Sync.TAsyncResult;
  BEGIN
    RETURN IO( dirWrite, _Writer, TimeoutMS, WaitForResult );
  END Write;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE WriteOA( CONST Data : ARRAY OF BYTE; OUT Consumed : CARDINAL; TimeoutMS : CARDINAL ) : Sync.TAsyncResult;
   VAR
      Chunk : CMemoryProxy; // by default persistent
      R : Sync.TAsyncResult;
   BEGIN
      Chunk.Init( ADR( Data ), HIGH( Data )+1, FALSE );
      R := IO( dirWrite, ADR( Chunk ), TimeoutMS, TRUE );
      WHILE Chunk.References > 1 DO
         Sync.Sleep( 0 );
      END; // WHILE
      Consumed := Chunk.Processed;
      RETURN R;
  END WriteOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE WriteBuffer( CONST Data : StorageO.AMemoryBuffer; OUT Consumed : CARDINAL; TimeoutMS : CARDINAL ) : Sync.TAsyncResult;
   BEGIN
      RETURN WriteOA( OA( Data.Length-1, Data.Data ), OUT Consumed, TimeoutMS );
   END WriteBuffer;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE AbortWriting();
  BEGIN
    Abort( dirWrite );
  END AbortWriting;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE DevicePrepareData( Direction : TDirection; OUT Prepared : ADDRESS; OUT Length : CARDINAL ) : BOOLEAN;
  VAR
    Proxy : TPDataProxy;
  BEGIN
    CASE Direction OF
    | dirRead :
      Proxy := Sync.IGetPtr( REF Reader );
    | dirWrite :
      Proxy := Sync.IGetPtr( REF Writer );
    ELSE
      RETURN FALSE;
    END; // CASE
    RETURN ( Proxy <> NIL ) AND Proxy^.PrepareData( OUT Prepared, OUT Length );
  END DevicePrepareData;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE DeviceCompleteData( Direction : TDirection; Completed : CARDINAL );
  VAR
    Proxy : TPDataProxy;
  BEGIN
    CASE Direction OF
    | dirRead :
      Proxy := Sync.IGetPtr( REF Reader );
    | dirWrite :
      Proxy := Sync.IGetPtr( REF Writer );
    ELSE
      RETURN;
    END; // CASE
    IF Proxy <> NIL THEN
      Proxy^.CompleteData( Completed );
    END;
  END DeviceCompleteData;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE DeviceFinish( Direction : TDirection; Result : Sync.TAsyncResult );
  VAR
    Proxy : TPDataProxy;
  BEGIN
    CASE Direction OF
    | dirRead :
      Proxy := Sync.IExchgPtr( REF Reader, NIL );
    | dirWrite :
      Proxy := Sync.IExchgPtr( REF Writer, NIL );
    ELSE
      RETURN;
    END; // CASE
    IF Proxy <> NIL THEN
      Proxy^.DeviceFinish( Result );
      Proxy^.Release();
    END; // CASE
  END DeviceFinish;

(*--------------------------------------------------------------------------------*)

  INTERNAL PROCEDURE IO( Direction : TDirection; _Proxy : TPDataProxy; TimeoutMS : CARDINAL; WaitForResult : BOOLEAN ) : Sync.TAsyncResult;
  VAR
    Proxy : TPDataProxy;
    Result : Sync.TAsyncResult;
  BEGIN
    CASE Direction OF
    | dirRead :
      IF NOT CanRead THEN
        RETURN Sync.arCannotStart;
      END;
      Proxy := Sync.ICmpExchgPtr( REF Reader, _Proxy, NIL );
    | dirWrite :
      IF NOT CanWrite THEN
        RETURN Sync.arCannotStart;
      END;
      Proxy := Sync.ICmpExchgPtr( REF Writer, _Proxy, NIL );
    ELSE
      RETURN Sync.arCannotStart;
    END;
    IF Proxy <> NIL THEN
      RETURN Sync.arAlreadyPending;
    END;
    _Proxy^.AddRef();
    IF WaitForResult THEN
      _Proxy^.Waitable := TRUE;
      _Proxy^.Start();
      Result := Start( Direction, Sync.FOREVER );
      IF Result = Sync.arPending THEN
        Result := _Proxy^.WaitCompletion( TimeoutMS );
        IF Result = Sync.arTimeout THEN
          DeviceFinish( Direction, Sync.arTimeout );
        END;
      END;
    ELSE
      _Proxy^.Start();
      Result := Start( Direction, TimeoutMS );
    END;
    RETURN Result;
  END IO;

(*--------------------------------------------------------------------------------*)

BEGIN
  Reader := NIL;
  Writer := NIL;
END AStream;

(*================================================================================*)

CLASS IMPLEMENTATION CStreamProxy;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROPERTY Processed GET : CARDINAL; // count of read/written data
  BEGIN
    RETURN Stream^.Position32;
  END Processed;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Init( Direction : TDirection; Stream : TPStream );
  BEGIN
    SELF.Direction := Direction;
    SELF.Stream := Stream;
  END Init;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE PrepareData( OUT Prepared : ADDRESS; OUT Length : CARDINAL ) : BOOLEAN; // TRUE == have next data
  BEGIN
    RETURN ( Stream <> NIL ) AND Stream^.DevicePrepareData( Direction, OUT Prepared, OUT Length );
  END PrepareData;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE CompleteData( Completed : CARDINAL );
  BEGIN
    IF Stream <> NIL THEN
      Stream^.DeviceCompleteData( Direction, Completed );
    END;
  END CompleteData;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE DeviceFinish( Result : Sync.TAsyncResult );
  BEGIN
    IF Stream <> NIL THEN
      Stream^.DeviceFinish( Direction, Result );
    END;
  END DeviceFinish;

(*--------------------------------------------------------------------------------*)

BEGIN
  Stream := NIL;
END CStreamProxy;

(*================================================================================*)

CLASS IMPLEMENTATION CBufferedStream;

(*--------------------------------------------------------------------------------*)

  PUBLIC FINAL PROPERTY CanRead GET : BOOLEAN;
  BEGIN
    RETURN NOT _RBuffer.Empty OR ( _Stream <> NIL ) AND _Stream^.CanRead;
  END CanRead;
    
(*--------------------------------------------------------------------------------*)

  PUBLIC FINAL PROPERTY CanWrite GET : BOOLEAN;
  BEGIN
    RETURN NOT _RBuffer.Full OR ( _Stream <> NIL ) AND _Stream^.CanWrite;
  END CanWrite;
    
(*--------------------------------------------------------------------------------*)

  PUBLIC FINAL PROPERTY CanSeek GET : BOOLEAN;
  BEGIN
    RETURN ( _Stream <> NIL ) AND _Stream^.CanSeek;
  END CanSeek;
    
(*--------------------------------------------------------------------------------*)

  PUBLIC FINAL PROPERTY Long GET : BOOLEAN;
  BEGIN
    RETURN ( _Stream <> NIL ) AND _Stream^.Long;
  END Long;

(*--------------------------------------------------------------------------------*)

  PUBLIC FINAL PROPERTY Length GET : CARD64;
  BEGIN
    IF _Stream = NIL THEN
      RETURN CARD64( _RBuffer.Count );
    ELSE
      RETURN CARD64( _RBuffer.Count ) + _Stream^.Length;
    END;
  END Length;

(*--------------------------------------------------------------------------------*)

  PUBLIC FINAL PROPERTY Length SET( Value : CARD64 );
  BEGIN
    IF _Stream <> NIL THEN
      _Stream^.Length := Value;
    END;
  END Length;

(*--------------------------------------------------------------------------------*)

  PUBLIC FINAL PROPERTY Position GET : CARD64;
  BEGIN
    IF _Stream = NIL THEN
      RETURN 0;
    ELSE
      RETURN _Stream^.Position;
    END;
  END Position;

(*--------------------------------------------------------------------------------*)

  PUBLIC FINAL PROPERTY Position SET( Value : CARD64 );
  BEGIN
    _RBuffer.Clear();
    IF _Stream <> NIL THEN
      _Stream^.Position := Value;
    END;
  END Position;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY BufferSize GET : CARD32;
  BEGIN  
    RETURN _BSize;
  END BufferSize;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY BufferSize SET( Value : CARD32 );
  BEGIN
    IF Value = _BSize THEN
      RETURN;
    END;
    _BSize := Value;
    IF _Stream <> NIL THEN
      AbortReading();
      AbortWriting();
    END;
    _RBuffer.Size := _BSize;
    _WBuffer.Size := _BSize;
  END BufferSize;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY Stream GET : TPStream;
  BEGIN
    RETURN _Stream;
  END Stream;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY Stream SET( Value : TPStream );
  BEGIN
    IF Value = _Stream THEN
      RETURN;
    END;
    AbortReading();
    AbortWriting();
    _Stream := Value;
  END Stream;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY WriteSpace GET : CARD32; // space in output buffer
   BEGIN
      RETURN _WBuffer.Size - _WBuffer.Count; 
   END WriteSpace;

(*--------------------------------------------------------------------------------*)

  PUBLIC FINAL PROCEDURE Seek( Origin : TSeekOrigin; Position : INT64 ); 
  BEGIN
    _RBuffer.Clear();
    IF _Stream <> NIL THEN
      _Stream^.Seek( Origin, Position );
    END;
  END Seek;

(*--------------------------------------------------------------------------------*)

  PUBLIC FINAL PROCEDURE Flush();
  BEGIN
    IF _Stream = NIL THEN
      RETURN;
    END;
    _Stream^.Flush();
    IF _WBuffer.Empty THEN
      RETURN;
    END;
    // flush self buffers
    _Stream^.Write( ADR( _WProxy ), Sync.FOREVER, TRUE );
  END Flush;

(*--------------------------------------------------------------------------------*)

  PUBLIC FINAL PROCEDURE Close( Persist : BOOLEAN );
  BEGIN
    IF _Stream <> NIL THEN
      Flush();
      _Stream^.Close( Persist );
    END;
    _RBuffer.Clear();
    _WBuffer.Clear();
  END Close;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROPERTY Notifier GET : TPDataInfo;
  BEGIN
    RETURN _Notifier;
  END Notifier;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROPERTY Notifier SET( Value : TPDataInfo );
  VAR
    _LNotifier : TPDataInfo;
  BEGIN
    IF _Notifier = Value THEN
      RETURN;
    END;
    IF Value <> NIL THEN
      Value^.AddRef();
    END;
    _LNotifier := _Notifier; // use local variable to avoid recursion
    _Notifier := Value;
    IF _LNotifier <> NIL THEN
      _LNotifier^.Release();
    END;
  END Notifier;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE StartReading();
  BEGIN
    Start( dirRead, Sync.FOREVER );
  END StartReading;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE Peek( OUT Data : ADDRESS; OUT Length : CARDINAL ) : BOOLEAN; // peeks data from read buffer
  BEGIN
    RETURN _RBuffer.Peek( OUT Data, OUT Length );
  END Peek;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE ReadOut( Length : CARDINAL ); // consumes data from read buffer
  BEGIN
    _RBuffer.CommitReading( Length );
    OperateDevice( dirRead );
  END ReadOut;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE CommitWrite();
  BEGIN
    IF NOT _WBuffer.Empty THEN
      _Stream^.IO( dirWrite, ADR( _WProxy ), Sync.FOREVER, FALSE );
    END;
  END CommitWrite;
  
(*--------------------------------------------------------------------------------*)

  INTERNAL FINAL PROCEDURE Start( Direction : TDirection; OperationTimeoutMS : CARDINAL ) : Sync.TAsyncResult;
  VAR
    Result : Sync.TAsyncResult;
  BEGIN
    IF _Stream = NIL THEN
      RETURN Sync.arCannotStart;
    ELSIF Direction = dirRead THEN
      IF RMode = bmBypass THEN
        RETURN _Stream^.IO( dirRead, Reader, OperationTimeoutMS, FALSE ); 
      ELSE
        Result := OperateClient( Direction, FALSE ); 
      END;
    ELSE
      IF WMode = bmBypass THEN
        RETURN _Stream^.IO( dirWrite, Writer, OperationTimeoutMS, FALSE ); 
      ELSE
        Result := OperateClient( Direction, FALSE ); 
      END;
    END;
    OperateDevice( Direction );
    RETURN Result;
  END Start;

(*--------------------------------------------------------------------------------*)

  INTERNAL FINAL PROCEDURE Abort( Direction : TDirection );
  BEGIN
    IF _Stream = NIL THEN
      DeviceFinish( Direction, Sync.arAborted );
    ELSE
      _Stream^.Abort( Direction );
    END;
    IF Direction = dirRead THEN
      _RBuffer.Clear();
    ELSE
      _WBuffer.Clear();
    END;
  END Abort;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE DevicePrepareData( Direction : TDirection; OUT Prepared : ADDRESS; OUT Length : CARDINAL ) : BOOLEAN;
  BEGIN
    CASE Direction OF
    | dirRead :
      RETURN _RBuffer.StartWriting( MAX( CARDINAL ), OUT Prepared, OUT Length );
    | dirWrite :
      RETURN _WBuffer.StartReading( MAX( CARDINAL ), OUT Prepared, OUT Length );
    END; // CASE
    RETURN FALSE;
  END DevicePrepareData;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE DeviceCompleteData( Direction : TDirection; Completed : CARDINAL );
  BEGIN
    CASE Direction OF
    | dirRead :
      _RBuffer.CommitWriting( Completed );
      IF _Notifier <> NIL THEN
        _Notifier^.OnReadable( _RBuffer.Count, ADR( SELF ));
      END;
      OperateClient( dirRead, TRUE );
    | dirWrite :
      _WBuffer.CommitReading( Completed );
      IF _Notifier <> NIL THEN
        _Notifier^.OnWritten( Completed, ADR( SELF ));
      END;
      OperateClient( dirWrite, TRUE );
    END; // CASE
  END DeviceCompleteData;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE DeviceFinish( Direction : TDirection; Result : Sync.TAsyncResult );
  BEGIN
    IF Result IN Sync.arsCompletions THEN
      OperateDevice( Direction );
    ELSE
      // should this be so relaxed ???
      _RLock.ExchgPtr( REF _RPending, NIL );
      _WLock.ExchgPtr( REF _WPending, NIL );
      SUPER.DeviceFinish( Direction, Result );
    END;
  END DeviceFinish;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE OperateClient( Direction : TDirection; FromDevice : BOOLEAN ) : Sync.TAsyncResult;
   LABEL
      RPending, WPending;
   VAR
      CA, SA : ADDRESS;
      CL, SL : CARDINAL;
      Proxy : TPDataProxy;
   BEGIN
      IF Direction = dirRead THEN

         _RLock.Lock();

         IF FromDevice THEN
            Proxy := _RPending;
         ELSE
            Proxy := Sync.IGetPtr( REF Reader );
            // ASSERT(( Proxy <> NIL ) AND ( _RPending = NIL )); -- Here, ASSERT must be allowed as stream
            // can be used as device-buffer + client-peeker. Thus, if client peeks and it does not read,
            // no Reader neither _RPending is set.
         END;
         IF Proxy = NIL THEN
            _RLock.Unlock();
            RETURN Sync.arCannotStart;
         END;

         IF RMode = bmChunked THEN
            IF _RBuffer.Count < RChunk THEN
               GOTO RPending;
            END;
         ELSIF RMode = bmCache THEN
            IF _RBuffer.Count < _RBuffer.Size DIV 2 THEN
               GOTO RPending;
            END;
         END;

         LOOP
            SL := 0;
            IF NOT Proxy^.PrepareData( OUT CA, OUT CL ) THEN // finish
               _RPending := NIL;
               _RLock.Unlock();      

               SUPER.DeviceFinish( dirRead, Sync.arCompleted );
               IF ( _Notifier <> NIL ) AND NOT _RBuffer.Empty THEN
                  _Notifier^.OnFlowPossible( dirRead, ADR( SELF ));
               END;

               // already unlocked
               RETURN Sync.arCompleted;

            ELSIF _RBuffer.StartReading( CL, OUT SA, OUT SL ) THEN
               Storage.Move( SA, CA, SL );
               _RBuffer.CommitReading( SL );
               Proxy^.CompleteData( SL );

            END; // ELSIF StartReading

            IF ( SL < CL ) AND _RBuffer.Empty THEN
               GOTO RPending;
            END; // IF accepted less than required
         END; // LOOP
         
    RPending:
         _RPending := Proxy;
         _RLock.Unlock();
         RETURN Sync.arPending;

      ELSE // dirWrite :
      
         _WLock.Lock();      

         IF FromDevice THEN
            Proxy := _WPending;
         ELSE
            Proxy := Sync.IGetPtr( REF Writer );
            ASSERT(( Proxy <> NIL ) AND ( _WPending = NIL ));
         END;
         IF Proxy = NIL THEN
            _WLock.Unlock();
            RETURN Sync.arCannotStart;
         END;

         LOOP
            SL := 0;
            IF NOT Proxy^.PrepareData( OUT CA, OUT CL ) THEN
               Sync.IExchgPtr( REF _WPending, NIL );
               _WLock.Unlock();      
      
               SUPER.DeviceFinish( dirWrite, Sync.arCompleted );
               IF _Notifier <> NIL THEN
                  _Notifier^.OnFlowPossible( dirWrite, ADR( SELF ));
               END;

               // already unlocked
               RETURN Sync.arCompleted;

            ELSIF _WBuffer.StartWriting( CL, OUT SA, OUT SL ) THEN
               Storage.Move( CA, SA, SL );
               _WBuffer.CommitWriting( SL );
               Proxy^.CompleteData( SL );
               
            END; // ELSIF StartReading

            IF ( SL < CL ) AND _WBuffer.Full THEN
               GOTO WPending;
            END; // IF accepted less than required
         END; // LOOP

    WPending:
         _WPending := Proxy;
         _WLock.Unlock();
         RETURN Sync.arPending;

      END; // IF Direction
  END OperateClient;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE OperateDevice( Direction : TDirection );
   // Procedure needs no synchronization, even if is called from both device and client.
   // _WBuffer.Empty/Count is safe and IO can be called with the same proxy more times (it returns pending or complete)
   BEGIN
      IF Direction = dirRead THEN
         IF NOT _RBuffer.Full THEN
            _Stream^.IO( dirRead, ADR( _RProxy ), Sync.FOREVER, FALSE );
         END;

      ELSIF Direction = dirWrite THEN
         IF WMode = bmCommited THEN
            // wait for commit

         ELSIF NOT _WBuffer.Empty THEN
            ASSERT( WMode <> bmBypass );
            IF WMode = bmChunked THEN
               IF _WBuffer.Count >= WChunk THEN
                  _Stream^.IO( dirWrite, ADR( _WProxy ), Sync.FOREVER, FALSE );
               END;
            ELSIF WMode = bmCache THEN
               IF _WBuffer.Count > _WBuffer.Size DIV 2 THEN
                  _Stream^.IO( dirWrite, ADR( _WProxy ), Sync.FOREVER, FALSE );
               END;
            END;

         END;
      END;
   END OperateDevice;

(*--------------------------------------------------------------------------------*)

BEGIN
  _Stream := NIL;
  _Notifier := NIL;
  _RProxy.Init( IOO.dirRead, ADR( SELF ));
  _RPending := NIL;
  _WProxy.Init( IOO.dirWrite, ADR( SELF ));
  _WPending := NIL;
FINALLY
  Stream := NIL;
  Notifier := NIL;
END CBufferedStream;

(*================================================================================*)

CLASS IMPLEMENTATION CDatagramReader;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY Stream GET : TPBufferedStream;
  BEGIN
    RETURN _Stream;
  END Stream;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY Stream SET( Value : TPBufferedStream );
  BEGIN
    IF Value = _Stream THEN
      RETURN;
    END;
    IF _Stream <> NIL THEN
      _Stream^.Notifier := NIL;
    END;
    _Stream := Value;
    IF _Stream <> NIL THEN
      _Stream^.Notifier := ADR( SELF );
    END;
  END Stream;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY SelfBuffer GET : BOOLEAN;
  BEGIN
    RETURN _Buffer <> NIL;
  END SelfBuffer;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY SelfBuffer SET( Value : BOOLEAN );
  BEGIN
    IF ( _Buffer <> NIL ) = Value THEN
      RETURN;
    END;
    IF Value THEN
      NEW( _Buffer );
      NEW( _BufferLock );
    ELSE
      DISPOSE( _Buffer );
      DISPOSE( _BufferLock );
    END;
    _BufferDataLength := 0;
  END SelfBuffer;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROPERTY Notifier GET : TPDataInfo;
  BEGIN
    RETURN _Notifier;
  END Notifier;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROPERTY Notifier SET( Value : TPDataInfo );
  BEGIN
    IF _Notifier = Value THEN
      RETURN;
    END;
    IF Value <> NIL THEN
      Value^.AddRef();
    END;
    IF _Notifier <> NIL THEN
      _Notifier^.Release();
    END;
    _Notifier := Value;
  END Notifier;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE StartReading();
  BEGIN
    IF _Buffer <> NIL THEN // it should not be here? it should be moved to connection close, not after connection start; current implementation denies calling StartReading more times !!!!
      _Buffer^.Clear();
      _BufferDataLength := 0;
    END;
    IF _Stream <> NIL THEN
      _Stream^.StartReading();
    END;
  END StartReading;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE Peek( OUT Data : ADDRESS; OUT Length : CARDINAL ) : BOOLEAN;
  LABEL
    ReadToBuffer;
  VAR
    A : ADDRESS;
    L1, L2 : CARDINAL;
  BEGIN
    IF _Stream = NIL THEN
      RETURN FALSE;

    ELSIF ( _Buffer <> NIL ) AND FeedDataToBuffer( 0, NIL ) THEN // return prepared data
      Data := _Buffer^.Data;
      Length := _BufferDataLength;
      RETURN TRUE;

    ELSIF NOT _Stream^.Peek( OUT A, OUT L1 ) THEN
      RETURN FALSE;

    ELSIF ( _Buffer <> NIL ) AND ( _BufferLock^.Get( REF _BufferDataLength ) > 0 ) THEN // return newly feeded data
  ReadToBuffer:
      IF FeedDataToBuffer( L1, A ) THEN
        Data := _Buffer^.Data;
        Length := _BufferDataLength;
        RETURN TRUE;
      END;
      RETURN FALSE;

    ELSIF L1 < SIZE( CARDINAL ) THEN
      RETURN FALSE;
    END;
    L2 := PCARD32( A )^;

    IF _Buffer <> NIL THEN
      LoadLengthForBuffer( L2 );
      INC( A, SIZE( CARDINAL ));
      DEC( L1, SIZE( CARDINAL ));
      GOTO ReadToBuffer;

    ELSIF L1 < L2 THEN
      ASSERT( L2 <= _Stream^.BufferSize );
      RETURN FALSE;
    ELSE
      Data := INC( A, SIZE( CARDINAL ));
      Length := L2;
      RETURN TRUE;
    END;
  END Peek;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE ReadOut( Length : CARDINAL ); // consumes data from read buffer
  BEGIN
    IF _Stream = NIL THEN
      RETURN;
    ELSIF _Buffer <> NIL THEN
      _BufferLock^.Lock();
      ASSERT( Length <= _BufferDataLength );
      _Buffer^.RemoveStart( Length );
      _BufferDataLength := _Buffer^.Length;
      IF ( _BufferDataLength = 0 ) AND ( _Buffer^.Size > 1024*1024 ) THEN
        _Buffer^.Size := 512*1024;
      END;
      _BufferLock^.Unlock();
    ELSE
      _Stream^.ReadOut( Length + SIZE( CARDINAL ));
    END;
  END ReadOut;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE OnReadable( Length : CARDINAL; Source : ADDRESS );
  LABEL
    ReadToBuffer;
  VAR
    A : ADDRESS;
    L1, L2 : CARDINAL;
  BEGIN
    IF ( _Notifier = NIL ) OR ( _Stream = NIL ) THEN
      RETURN;
    ELSIF NOT _Stream^.Peek( OUT A, OUT L1 ) THEN
      RETURN;

    ELSIF ( _Buffer <> NIL ) AND ( _BufferLock^.Get( REF _BufferDataLength ) > 0 ) THEN
  ReadToBuffer:
      IF FeedDataToBuffer( L1, A ) THEN
        _Notifier^.OnReadable( _BufferDataLength, ADR( SELF ));
      END; 
      RETURN;

    ELSIF L1 < SIZE( CARDINAL ) THEN
      RETURN;
    END;
    L2 := PCARD32( A )^;

    IF _Buffer <> NIL THEN
      LoadLengthForBuffer( L2 );
      INC( A, SIZE( CARDINAL ));
      DEC( L1, SIZE( CARDINAL ));
      GOTO ReadToBuffer;

    ELSIF L1 < L2 THEN
      ASSERT( L2 <= _Stream^.BufferSize );
      RETURN;
    END;
    _Notifier^.OnReadable( L2, ADR( SELF ));
  END OnReadable;

(*--------------------------------------------------------------------------------*)

  PRIVATE PROCEDURE FeedDataToBuffer( L1 : CARDINAL; A : ADDRESS ) : BOOLEAN; // returns if buffer is filled
  BEGIN
    _BufferLock^.Lock();
    IF _BufferDataLength = 0 THEN
      _BufferLock^.Unlock();
      RETURN FALSE;
    ELSIF _Buffer^.Length = _BufferDataLength THEN // already filled
      _BufferLock^.Unlock();
      RETURN TRUE;
    ELSIF L1 = 0 THEN
      _BufferLock^.Unlock();
      RETURN FALSE;
    END;

    L1 := MIN2( L1, _BufferDataLength - _Buffer^.Length );
    _Buffer^.AppendOA( OA( L1-1, A ));
    _BufferLock^.Unlock();

    _Stream^.ReadOut( L1 );

    _BufferLock^.Lock();
    IF _Buffer^.Length = _BufferDataLength THEN
      _BufferLock^.Unlock();
      RETURN TRUE;
    ELSE
      _BufferLock^.Unlock();
      RETURN FALSE;
    END;
  END FeedDataToBuffer;

(*--------------------------------------------------------------------------------*)

  PRIVATE PROCEDURE LoadLengthForBuffer( L2 : CARDINAL );
  BEGIN
    _BufferLock^.Lock();
    ASSERT( _Buffer^.Length = 0 );
    IF _Buffer^.Size < L2 THEN
      _Buffer^.Size := L2;
    END;
    _BufferDataLength := L2;
    _BufferLock^.Unlock();
    // read out length and pass corrected values to normal processing
    _Stream^.ReadOut( SIZE( CARDINAL ));
  END LoadLengthForBuffer;

(*--------------------------------------------------------------------------------*)

BEGIN
  _Stream := NIL;
  _Notifier := NIL;
FINALLY
  Stream := NIL;
  Notifier := NIL;
  SelfBuffer := FALSE;
END CDatagramReader;

(*================================================================================*)

CLASS IMPLEMENTATION CMemoryStream;

  PUBLIC VIRTUAL PROPERTY CanRead GET : BOOLEAN;
  BEGIN
    RETURN ( _Access = accRead ) OR ( _Access = accReadWrite );
  END CanRead;
  
  PUBLIC VIRTUAL PROPERTY CanWrite GET : BOOLEAN;
  BEGIN
    RETURN ( _Access = accWrite ) OR ( _Access = accReadWrite );
  END CanWrite;
  
  PUBLIC VIRTUAL PROPERTY CanSeek GET : BOOLEAN;
  BEGIN
    RETURN TRUE;
  END CanSeek;
  
  PUBLIC VIRTUAL PROPERTY Long GET : BOOLEAN;
  BEGIN
    RETURN SIZE( PTR ) > 4;
  END Long;
  
  PUBLIC VIRTUAL PROPERTY Length GET : CARD64;
  BEGIN
    RETURN CARD64( _Length );
  END Length;
  
  PUBLIC VIRTUAL PROPERTY Length SET( Value : CARD64 );
  BEGIN
    _Length := PTR( Value );
  END Length;
  
  PUBLIC VIRTUAL PROPERTY Position GET : CARD64;
  BEGIN
    RETURN CARD64( _Offset );
  END Position;
  
  PUBLIC VIRTUAL PROPERTY Position SET( Value : CARD64 );
  BEGIN
    Seek( soBegin, Value );
  END Position;
    
  PUBLIC PROCEDURE Init( Data : ADDRESS; Length : PTR; Access : TAccess );
  BEGIN
    _Data := Data;
    _Length := Length;
    _Access := Access;
    _Offset := 0;
  END Init;

  PUBLIC VIRTUAL PROCEDURE Seek( Origin : TSeekOrigin; Position : INT64 );
  BEGIN
    CASE Origin OF
    | soBegin :
      IF Position < 0 THEN
        _Offset := 0;
      ELSIF Position > INT64( _Length ) THEN
        _Offset := _Length;
      ELSE
        _Offset := PTR( Position );
      END;
    | soCurrent :
      IF Position > 0 THEN
        IF INT64( _Length - _Offset ) < Position THEN
          _Offset := Length;
        ELSE
          INC( _Offset, Position );
        END;
      ELSE
        IF INT64( _Offset ) < -Position THEN
          _Offset := 0;
        ELSE
          INC( _Offset, Position );
        END;
      END;
    | soEnd :
      IF Position < 0 THEN
        _Offset := _Length;
      ELSIF Position > INT64( _Length ) THEN
        _Offset := 0;
      ELSE
        _Offset := _Length - PTR( Position );
      END;
    END; // CASE
  END Seek;
  
  PUBLIC VIRTUAL PROCEDURE Flush();
  BEGIN
  END Flush;
  
  PUBLIC VIRTUAL PROCEDURE Close( Persist : BOOLEAN );
  BEGIN
    Flush();
  END Close;
  
  INTERNAL VIRTUAL PROCEDURE Start( Direction : TDirection; OperationTimeoutMS : CARDINAL ) : Sync.TAsyncResult;
  VAR
    a : ADDRESS;
    l : CARDINAL := 0;
    space : PTR;
  BEGIN
    IF Direction = dirRead THEN
      IF _Offset = _Length THEN
        DeviceFinish( Direction, Sync.arNoData );
        RETURN Sync.arNoData;
      END;
    ELSIF _Offset < _Length THEN
       // fall down
    ELSIF ExtendMemory( 1024 ) THEN
       // fall down
    ELSE
       DeviceFinish( Direction, Sync.arCannotStart );
       RETURN Sync.arCannotStart;
    END;

    WHILE DevicePrepareData( Direction, OUT a, OUT l ) DO
      space := _Length-_Offset;
      IF PTR( l ) < space THEN
         // OK, there is space
      ELSIF ( Direction = dirWrite ) AND ExtendMemory( _Length - space + PTR( l )) THEN
         // OK, memory enhanced
      ELSE
         l := CARDINAL( LOPTRLONGWORD( space )); // limit memory
      END;
      IF l > 0 THEN
        IF Direction = dirRead THEN
          Storage.Move( _Data@[_Offset], a, l );
        ELSE
          Storage.Move( a, _Data@[_Offset], l );
        END;
        DeviceCompleteData( Direction, l );
        INC( _Offset, l );
      END;
      IF _Offset = _Length THEN
        EXIT;
      END;
    END;

    DeviceFinish( Direction, Sync.arCompleted );
    RETURN Sync.arCompleted;
  END Start;

  INTERNAL VIRTUAL PROCEDURE Abort( Direction : TDirection );
  BEGIN
    DeviceFinish( Direction, Sync.arAborted );
  END Abort;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE ExtendMemory( NewLength : PTR ) : BOOLEAN;
   BEGIN
      RETURN FALSE; 
   END ExtendMemory;

(*--------------------------------------------------------------------------------*)

BEGIN
  _Access := accUnknown;
  _Data := NIL;
  _Length := 0;
  _Offset := 0;
END CMemoryStream;

(*================================================================================*)

CLASS IMPLEMENTATION CMemoryBufferStream;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE DeviceFinish( Direction : TDirection; Result : Sync.TAsyncResult );
   BEGIN
      IF Direction = dirWrite THEN
         _Buffer^.Length := CARDINAL( LOPTRLONGWORD( _Offset ));
      END;
      SUPER.DeviceFinish( Direction, Result );
   END DeviceFinish;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE ExtendMemory( NewLength : PTR ) : BOOLEAN;
   VAR
      pg : PTR := PTR( Storage.PageSize());
   BEGIN
      IF NewLength < _Buffer^.Size THEN
         RETURN TRUE;
      END;
      _Buffer^.Size := CARDINAL(( NewLength DIV pg + 1 ) * pg );
      _Data := _Buffer^.Data;
      _Length := _Buffer^.Size;
      RETURN TRUE;
   END ExtendMemory;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( REF Buffer : StorageO.AMemoryBuffer; Access : TAccess );
   BEGIN
      _Buffer := ADR( Buffer );
      IF Access = accWrite THEN
         SUPER.Init( Buffer.Data, Buffer.Size, Access );
      ELSE
         SUPER.Init( Buffer.Data, Buffer.Length, Access );
      END;
   END Init;

(*--------------------------------------------------------------------------------*)

BEGIN
   _Buffer := NIL;
END CMemoryBufferStream;

(*================================================================================*)

END IOO.
