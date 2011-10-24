IMPLEMENTATION MODULE Win32msg;

FROM Debug IMPORT
   AssertionW;

FROM Storage IMPORT
  ALLOCATE;

IMPORT
   collection,
   Storage,
   Strings,
   Win32msgqueuethread,
   windows;

(*================================================================================*)

#if DEBUG #then
IMPORT
  lists;
 
CLASS CChecker;
END CChecker;

VAR
  Handlers : lists.CPtrList;
  Checked : CChecker;

CLASS IMPLEMENTATION CChecker;
BEGIN FINALLY
  ASSERTLOG( Handlers.Empty );
END CChecker;
#endif

(*================================================================================*)

PROCEDURE Win32RawMsgBase() : CARDINAL;
BEGIN
   RETURN windows.WM_USER;
END Win32RawMsgBase;
  
(*--------------------------------------------------------------------------------*)

PROCEDURE Win32MsgBase() : CARDINAL;
BEGIN
   RETURN Win32RawMsgBase() + OSALmsg.RAW_MESSAGE_SPACE;
END Win32MsgBase;
  
(*================================================================================*)

VAR
  WndClass : windows.ATOM;
  WndClassName : ARRAY [0..63] OF WCHAR;

(*--------------------------------------------------------------------------------*)

(*# save, call( convention=>stdcall ) *)
PROCEDURE WndProc( hwnd : windows.HWND; 
                   message : windows.UINT; 
                   wParam : windows.WPARAM; 
                   lParam : windows.LPARAM ): windows.LRESULT;
VAR
   Msg : Win32Message;
   Target : OSALmsg.TPMessageTarget;
   Result : PTR;
BEGIN
   IF HandleToTarget( hwnd, OUT Target ) THEN
      Msg.Source := NIL;
      Msg.Target := Target;
      Msg.Message := message;
      Msg[ MI_WPARAM ] := wParam;
      Msg[ MI_LPARAM ] := PTR( lParam );
   ELSE
      RETURN windows.DefWindowProc( hwnd, message, wParam, lParam );
   END;
   IF Target^.Message( Msg, OSALmsg.delSynchronous, ADR( Result )) THEN
      RETURN windows.LRESULT( Result );
   ELSE
      RETURN windows.DefWindowProc( hwnd, message, wParam, lParam );
   END;
END WndProc;
(*# restore *)

(*--------------------------------------------------------------------------------*)

PROCEDURE CreateWndClass();
VAR
  c : CARD64;
  li : windows.LARGE_INTEGER;
  n : ARRAY [0..31] OF WCHAR;
  wndclass : windows.WNDCLASS;
BEGIN
  IF WndClass <> windows.INVALID_ATOM THEN
    RETURN;
  END;
  windows.QueryPerformanceCounter( li );
  c := CARD64( li );
  windows.Sleep( 0 );
  windows.QueryPerformanceCounter( li );
  c := c * ( MAX( CARD64 ) - c - 13 ) - CARD64( li );

  Strings.FromCARD64W( c, 10, OUT n );
  Strings.ConcatW( OUT WndClassName, L'SCWndClass:', n );

  Storage.Fill( ADR( wndclass ), SIZE( wndclass ), 0 );
  WITH wndclass DO
    style := windows.CS_GLOBALCLASS;
    lpfnWndProc := WndProc;
    hInstance := windows.GetModuleHandleW( NIL );
    lpszClassName := ADR( WndClassName );
  END;
  WndClass := windows.RegisterClass( ADR( wndclass ));
END CreateWndClass;

(*--------------------------------------------------------------------------------*)

PROCEDURE DestroyWndClass();
BEGIN
  IF WndClass = windows.INVALID_ATOM THEN
    RETURN;
  END;
  windows.UnregisterClass( ADR( WndClassName ), windows.GetModuleHandleW( NIL ));
  WndClass := windows.INVALID_ATOM;
END DestroyWndClass;

(*--------------------------------------------------------------------------------*)

PROCEDURE HandleToTarget( CONST Handle : PTR; OUT Target : OSALmsg.TPMessageTarget ) : BOOLEAN;
BEGIN
  IF Handle = NIL THEN
    RETURN FALSE;
  ELSIF windows.GetClassLongPtr( Handle, windows.GCW_ATOM ) = windows.ULONG_PTR( WndClass ) THEN
    Target := OSALmsg.TPMessageTarget( windows.GetWindowLongPtr( Handle, windows.GWL_USERDATA ));
    RETURN Target <> NIL;
  ELSE
    RETURN FALSE;
  END;
END HandleToTarget;

(*--------------------------------------------------------------------------------*)

INITIALLY __I();
BEGIN
  WndClass := windows.INVALID_ATOM;
  CreateWndClass();
END __I;

(*--------------------------------------------------------------------------------*)

FINALLY __F();
BEGIN
  DestroyWndClass();
END __F;

(*================================================================================*)

CLASS IMPLEMENTATION Win32Message;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROPERTY Win32Message.Source GET : ADDRESS;
  BEGIN
    RETURN source;
  END Win32Message.Source;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROPERTY Win32Message.Source SET( Value : ADDRESS );
  BEGIN
    source := Value;
  END Win32Message.Source;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROPERTY Win32Message.Target GET : OSALmsg.TPMessageTarget;
  BEGIN
    RETURN target;
  END Win32Message.Target;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROPERTY Win32Message.Target SET( Value : OSALmsg.TPMessageTarget );
  BEGIN
    target := Value;
  END Win32Message.Target;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROPERTY Win32Message.Message GET : CARDINAL;
  BEGIN
    RETURN message;
  END Win32Message.Message;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROPERTY Win32Message.Message SET( Value : CARDINAL );
  BEGIN
    message := Value;
  END Win32Message.Message;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROPERTY Win32Message.Parameter GET : PTR;
  BEGIN
    RETURN wParam;
  END Win32Message.Parameter;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROPERTY Win32Message.Parameter SET( Value : PTR );
  BEGIN
    wParam := Value;
  END Win32Message.Parameter;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL READONLY PROPERTY Win32Message.ParameterCount GET : CARDINAL;
  BEGIN
    RETURN 5;
  END Win32Message.ParameterCount;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL INDEX Win32Message GET( ParameterIndex : CARDINAL ) : PTR;
  BEGIN
    CASE ParameterIndex OF
    | OSALmsg.MI_SOURCE : RETURN source;
    | OSALmsg.MI_TARGET : RETURN target;
    | OSALmsg.MI_MESSAGE : RETURN message;
    | MI_WPARAM : RETURN wParam;
    | MI_LPARAM : RETURN lParam;
    ELSE RETURN 0;
    END;
  END Win32Message;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL INDEX Win32Message SET( ParameterIndex : CARDINAL; Value : PTR );
  BEGIN
    CASE ParameterIndex OF
    | OSALmsg.MI_SOURCE : source := Value;
    | OSALmsg.MI_TARGET : target := Value;
    | OSALmsg.MI_MESSAGE : message := CARDINAL( LOPTRLONGWORD( Value ));
    | MI_WPARAM : wParam := Value;
    | MI_LPARAM : lParam := Value;
    END;
  END Win32Message;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Send( Target : OSALmsg.TPMessageTarget; Delivery : OSALmsg.TDelivery; Result : PPTR ) : BOOLEAN;
   BEGIN
      target := Target;
      RETURN target^.Message( SELF, Delivery, Result );
   END Send;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE Clone() : POINTER TO OSALmsg.IMessage;
  VAR
    Message : POINTER TO Win32Message;
  BEGIN
    NEW( Message );
    Message^ := SELF;
    RETURN Message;
  END Clone;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Release();
   VAR
      Message : POINTER TO Win32Message := ADR( SELF );
   BEGIN
      DISPOSE( Message );
   END Release;

(*--------------------------------------------------------------------------------*)

  PUBLIC OPERATOR :=( CONST MSG : Win32Message );
  BEGIN
    source := MSG.source;
    target := MSG.target;
    message := MSG.message;
    wParam := MSG.wParam;
    lParam := MSG.lParam;
  END :=;

(*--------------------------------------------------------------------------------*)

BEGIN
  source := NIL;
  target := NIL;
  message := windows.WM_NULL;
  lParam := 0;
  wParam := 0;
END Win32Message;

(*--------------------------------------------------------------------------------*)

PROCEDURE FromMessage( Source : ADDRESS; Message : CARDINAL; Parameter : PTR ) : Win32Message;
VAR
   msg : Win32Message;
BEGIN
   msg.Source := Source;
   msg.Message := Message;
   msg.Parameter := Parameter;
   RETURN msg;
END FromMessage;

(*================================================================================*)

CLASS IMPLEMENTATION Win32MessageHandler;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROPERTY JoinedTo GET : OSALmsg.TPMessageQueueThread;
  BEGIN
    RETURN joinedTo;
  END JoinedTo;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL READONLY PROPERTY Win32MessageHandler.SelfContext GET : BOOLEAN;
  BEGIN
    RETURN LOPTRLONGWORD( windows.GetWindowThreadProcessId( HWND, NIL )) = windows.GetCurrentThreadId();
  END Win32MessageHandler.SelfContext;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL READONLY PROPERTY Win32MessageHandler.Handle GET : PTR;
  BEGIN
    RETURN HWND;
  END Win32MessageHandler.Handle;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Win32MessageHandler.Init( AutomaticJoin : BOOLEAN );
  BEGIN
    IF AutomaticJoin THEN
      JoinMessageThread( Win32msgqueuethread.Win32GlobalMessageQueueThread()^, TRUE );
    END;
  END Win32MessageHandler.Init;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE Dispose();
  BEGIN
    LeaveMessageThread( TRUE );
  END Dispose;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Message( CONST MSG : OSALmsg.IMessage; Delivery : OSALmsg.TDelivery; Result : PPTR ) : BOOLEAN;
   VAR
      i : CARDINAL;
      message : Win32Message;
      msg : OSALmsg.TPMessage;
      LResult : PTR;
      Repeat : PTR;
      Timer : PTR;
   BEGIN
      IF MSG.Target = NIL THEN // no target, set self as it
         FOR i := 0 TO MIN2( MSG.ParameterCount, message.ParameterCount )-1 DO
            message[i] := MSG[i];
         END; // FOR
         message.Target := ADR( SELF );
         msg := ADR( message );
      ELSE
         msg := OSALmsg.TPMessage( ADR( MSG ));
      END;

      IF ( Delivery = OSALmsg.delSynchronous ) OR ( Delivery = OSALmsg.delSynchronousIfInThread ) AND SelfContext THEN
         IF msg^[ OSALmsg.MI_MESSAGE ] = windows.WM_TIMER THEN
            Timer := msg^[ MI_WPARAM ];
            IF NOT Timers.Get( Timer, OUT Repeat ) THEN
               RETURN FALSE;
            ELSIF Repeat = 0 THEN
               windows.KillTimer( HWND, Timer );
            END;
            OnTimer( Timer );
         ELSE
            IF Result = NIL THEN
               Result := ADR( LResult );
            END;
            RETURN OnMessage( msg^, OUT Result^ );
         END;
      ELSIF HWND = NIL THEN
         RETURN FALSE;
      ELSE // deffer message
         windows.PostMessage( HWND, msg^.Message, windows.WPARAM( msg^[ MI_WPARAM ] ), windows.LPARAM( msg^[ MI_LPARAM ] ));
      END;
      IF Result <> NIL THEN
         Result^ := 0;
      END;
      RETURN TRUE;
   END Message;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnMessage( CONST MSG : OSALmsg.IMessage; OUT Result : PTR ) : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END Win32MessageHandler.OnMessage;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE StartTimer( Timer : PTR; PeriodMS : CARDINAL; Repeat : BOOLEAN );
  BEGIN
    IF HWND = NIL THEN
      RETURN;
    END;
    ASSERT( SelfContext );

    IF Timers.Contains( Timer ) THEN
      windows.KillTimer( HWND, Timer );
      Timers.Remove( Timer );
    END;
    Timers.Add( windows.SetTimer( HWND, Timer, PeriodMS, NIL ), PTR( Repeat )); // IA64PTR
  END StartTimer;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE TimerRunning( Timer : PTR ) : BOOLEAN;
  BEGIN
    IF HWND = NIL THEN
      RETURN FALSE;
    ELSE
      RETURN Timers.Contains( Timer );
    END;
  END TimerRunning;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE StopTimer( Timer : PTR );
  BEGIN
    IF HWND = NIL THEN
      RETURN;
    END;
    ASSERT( SelfContext );

    IF Timers.Contains( Timer ) THEN
      windows.KillTimer( HWND, Timer );
      Timers.Remove( Timer );
    END;
  END StopTimer;
  
(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnTimer( Timer : PTR );
   BEGIN
   END OnTimer;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE OnJoin( CONST JoinTo : OSALmsg.IMessageQueueThread );
  BEGIN
    IF HWND <> NIL THEN
      RETURN;
    END;
    joinedTo := OSALmsg.TPMessageQueueThread( ADR( JoinTo ));

    __I();
    HWND := windows.CreateWindowEx(
              windows.WS_EX_TOOLWINDOW,
              windows.PCTSTR( WndClass ),
              NIL, 0, -1, -1, 0, 0, NIL, NIL,
              windows.GetModuleHandleW( NIL ), NIL
            );
    IF HWND <> NIL THEN        
      LeakALLOCATE( ADDRESS( HWND ), CARDINAL( LOPTRLONGWORD( HWND )) OR 08000000H );
      windows.SetWindowLongPtr( HWND, windows.GWL_USERDATA, PTR( ADR( SELF )));
    END;

    #if DEBUG #then
      Handlers.Add( ADR( SELF ), 0 );
    #endif
  END OnJoin;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE OnLeave();
   VAR
      iterator : lists.CPtrListIterator;   
  BEGIN
    IF HWND <> NIL THEN
      iterator.Init( Timers, collection.dirForward );
      WHILE iterator.MoveNext() DO
        windows.KillTimer( HWND, iterator.Value ); // IA64PTR
      END;
      Timers.Dispose();
      #if DEBUG #then
        Handlers.Remove( ADR( SELF ));
      #endif
      LeakDEALLOCATE( ADDRESS( HWND ));
      windows.SetWindowLongPtr( HWND, windows.GWL_USERDATA, windows.LONG_PTR( 0 ));
      windows.DestroyWindow( HWND );
      HWND := NIL;
      __F();
    END;

    joinedTo := NIL;
  END OnLeave;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE JoinMessageThread( CONST JoinTo : OSALmsg.IMessageQueueThread; CallOnJoinInThread : BOOLEAN );
  BEGIN
    JoinTo.Join( ADR( SELF ), CallOnJoinInThread );
  END JoinMessageThread;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE LeaveMessageThread( CallOnLeaveInThread : BOOLEAN );
  BEGIN
    IF joinedTo <> NIL THEN
      JoinedTo^.Leave( ADR( SELF ), CallOnLeaveInThread );
    END;
  END LeaveMessageThread;

(*--------------------------------------------------------------------------------*)

BEGIN
  joinedTo := NIL;
  HWND := NIL;
FINALLY
  Dispose();
END Win32MessageHandler;

(*================================================================================*)

END Win32msg.