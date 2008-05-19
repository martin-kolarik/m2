IMPLEMENTATION MODULE Win32msg;

FROM Storage IMPORT
  ALLOCATE;

IMPORT
  Storage,
  Strings,
  windows;

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
  ASSERT( Handlers.Empty );
END CChecker;
#endif

PROCEDURE Win32RawMsgBase() : CARDINAL;
BEGIN
   RETURN windows.WM_USER;
END Win32RawMsgBase;
  
PROCEDURE Win32MsgBase() : CARDINAL;
BEGIN
   RETURN Win32RawMsgBase() + OSALmsg.RAW_MESSAGE_SPACE;
END Win32MsgBase;
  
VAR
  WndClass : windows.ATOM;
  WndClassName : ARRAY [0..63] OF WCHAR;

(*# save, call( convention=>stdcall ) *)
PROCEDURE WndProc( hwnd : windows.HWND; 
                   message : windows.UINT; 
                   wParam : windows.WPARAM; 
                   lParam : windows.LPARAM ): windows.LRESULT;
VAR
   Msg : Win32Message;
   Recipient : OSALmsg.TPMessageRecipient;
   Result : PTR;
BEGIN
   IF HandleToRecipient( hwnd, OUT Recipient ) THEN
      Msg.Source := NIL;
      Msg.Target := Recipient;
      Msg.Message := message;
      Msg[ MI_WPARAM ] := wParam;
      Msg[ MI_LPARAM ] := PTR( lParam );
   ELSE
      RETURN windows.DefWindowProc( hwnd, message, wParam, lParam );
   END;
   IF Recipient^.Message( Msg, OSALmsg.delSynchronous, ADR( Result )) THEN
      RETURN windows.LRESULT( Result );
   ELSE
      RETURN windows.DefWindowProc( hwnd, message, wParam, lParam );
   END;
END WndProc;
(*# restore *)

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

PROCEDURE DestroyWndClass();
BEGIN
  IF WndClass = windows.INVALID_ATOM THEN
    RETURN;
  END;
  windows.UnregisterClass( ADR( WndClassName ), windows.GetModuleHandleW( NIL ));
  WndClass := windows.INVALID_ATOM;
END DestroyWndClass;

PROCEDURE HandleToRecipient( CONST Handle : PTR; OUT Handler : OSALmsg.TPMessageRecipient ) : BOOLEAN;
BEGIN
  IF Handle = NIL THEN
    RETURN FALSE;
  ELSIF windows.GetClassLongPtr( Handle, windows.GCW_ATOM ) = windows.ULONG_PTR( WndClass ) THEN
    Handler := OSALmsg.TPMessageHandler( windows.GetWindowLongPtr( Handle, windows.GWL_USERDATA ));
    RETURN Handler <> NIL;
  ELSE
    RETURN FALSE;
  END;
END HandleToRecipient;

INITIALLY __I();
BEGIN
  WndClass := windows.INVALID_ATOM;
  CreateWndClass();
END __I;

FINALLY __F();
BEGIN
  DestroyWndClass();
END __F;

CLASS IMPLEMENTATION Win32Message;

  PUBLIC VIRTUAL PROPERTY Win32Message.Source GET : ADDRESS;
  BEGIN
    RETURN source;
  END Win32Message.Source;
  
  PUBLIC VIRTUAL PROPERTY Win32Message.Source SET( Value : ADDRESS );
  BEGIN
    source := Value;
  END Win32Message.Source;
  
  PUBLIC VIRTUAL PROPERTY Win32Message.Target GET : OSALmsg.TPMessageRecipient;
  BEGIN
    RETURN target;
  END Win32Message.Target;
  
  PUBLIC VIRTUAL PROPERTY Win32Message.Target SET( Value : OSALmsg.TPMessageRecipient );
  BEGIN
    target := Value;
  END Win32Message.Target;
  
  PUBLIC VIRTUAL PROPERTY Win32Message.Message GET : CARDINAL;
  BEGIN
    RETURN message;
  END Win32Message.Message;
  
  PUBLIC VIRTUAL PROPERTY Win32Message.Message SET( Value : CARDINAL );
  BEGIN
    message := Value;
  END Win32Message.Message;
  
  PUBLIC VIRTUAL PROPERTY Win32Message.Parameter GET : PTR;
  BEGIN
    RETURN wParam;
  END Win32Message.Parameter;
  
  PUBLIC VIRTUAL PROPERTY Win32Message.Parameter SET( Value : PTR );
  BEGIN
    wParam := Value;
  END Win32Message.Parameter;
  
  PUBLIC VIRTUAL READONLY PROPERTY Win32Message.ParameterCount GET : CARDINAL;
  BEGIN
    RETURN 5;
  END Win32Message.ParameterCount;

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

  PUBLIC VIRTUAL PROCEDURE Clone() : POINTER TO OSALmsg.IMessage;
  VAR
    Message : POINTER TO Win32Message;
  BEGIN
    NEW( Message );
    Message^ := SELF;
    RETURN Message;
  END Clone;

  PUBLIC OPERATOR :=( CONST MSG : Win32Message );
  BEGIN
    source := MSG.source;
    target := MSG.target;
    message := MSG.message;
    wParam := MSG.wParam;
    lParam := MSG.lParam;
  END :=;

BEGIN
  source := NIL;
  target := NIL;
  message := windows.WM_NULL;
  lParam := 0;
  wParam := 0;
END Win32Message;

CLASS IMPLEMENTATION Win32MessageHandler;

  PUBLIC VIRTUAL PROPERTY JoinedTo GET : OSALmsg.TPMessageQueueThread;
  BEGIN
    RETURN joinedTo;
  END JoinedTo;

  PUBLIC VIRTUAL READONLY PROPERTY Win32MessageHandler.SelfContext GET : BOOLEAN;
  BEGIN
    RETURN LOPTRLONGWORD( windows.GetWindowThreadProcessId( HWND, NIL )) = windows.GetCurrentThreadId();
  END Win32MessageHandler.SelfContext;

  PUBLIC VIRTUAL READONLY PROPERTY Win32MessageHandler.Handle GET : PTR;
  BEGIN
    RETURN HWND;
  END Win32MessageHandler.Handle;

  PUBLIC PROCEDURE Win32MessageHandler.Init( AutomaticJoin : BOOLEAN );
  BEGIN
    IF AutomaticJoin THEN
      JoinMessageThread( NIL, TRUE );
    END;
  END Win32MessageHandler.Init;
  
  PUBLIC PROCEDURE Dispose();
  BEGIN
    LeaveMessageThread( TRUE );
  END Dispose;

   PUBLIC VIRTUAL PROCEDURE Message( CONST MSG : OSALmsg.IMessage; Delivery : OSALmsg.TDelivery; Result : PPTR ) : BOOLEAN;
   VAR
      LResult : PTR;
      Repeat : PTR;
      Timer : PTR;
   BEGIN
      OSALmsg.TPMessage( ADR( MSG ))^.Target := ADR( SELF );
      IF ( Delivery = OSALmsg.delSynchronous ) OR ( Delivery = OSALmsg.delSynchronousIfInThread ) AND SelfContext THEN
         IF MSG[ OSALmsg.MI_MESSAGE ] = windows.WM_TIMER THEN
            Timer := MSG[ MI_WPARAM ];
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
            RETURN OnMessage( MSG, OUT Result^ );
         END;
      ELSIF HWND = NIL THEN
         RETURN FALSE;
      ELSE // deffer message
         windows.PostMessage( HWND, MSG.Message, windows.WPARAM( MSG[ MI_WPARAM ] ), windows.LPARAM( MSG[ MI_LPARAM ] ));
      END;
      IF Result <> NIL THEN
         Result^ := 0;
      END;
      RETURN TRUE;
   END Message;

   INTERNAL VIRTUAL PROCEDURE OnMessage( CONST MSG : OSALmsg.IMessage; OUT Result : PTR ) : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END Win32MessageHandler.OnMessage;

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
  
  PUBLIC VIRTUAL PROCEDURE TimerRunning( Timer : PTR ) : BOOLEAN;
  BEGIN
    IF HWND = NIL THEN
      RETURN FALSE;
    ELSE
      RETURN Timers.Contains( Timer );
    END;
  END TimerRunning;

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
  
   INTERNAL VIRTUAL PROCEDURE OnTimer( Timer : PTR );
   BEGIN
   END OnTimer;

  PUBLIC VIRTUAL PROCEDURE OnJoin( JoinTo : OSALmsg.TPMessageQueueThread );
  BEGIN
    IF HWND <> NIL THEN
      RETURN;
    END;
    joinedTo := JoinTo;

    __I();
    HWND := windows.CreateWindowEx(
              windows.WS_EX_TOOLWINDOW,
              windows.PCTSTR( WndClass ),
              NIL, 0, -1, -1, 0, 0, NIL, NIL,
              windows.GetModuleHandleW( NIL ), NIL
            );
    IF HWND <> NIL THEN        
      LeakALLOCATE( HWND, CARDINAL( LOPTRLONGWORD( HWND )) OR 08000000H );
      windows.SetWindowLongPtr( HWND, windows.GWL_USERDATA, PTR( ADR( SELF )));
    END;

    #if DEBUG #then
      Handlers.Add( ADR( SELF ), 0 );
    #endif
  END OnJoin;

  PUBLIC VIRTUAL PROCEDURE OnLeave();
  BEGIN
    IF HWND <> NIL THEN
      Timers.Reset();
      WHILE Timers.MoveNext() DO
        windows.KillTimer( HWND, Timers.Current ); // IA64PTR
      END;
      Timers.Dispose();
      #if DEBUG #then
        Handlers.Remove( ADR( SELF ));
      #endif
      windows.SetWindowLongPtr( HWND, windows.GWL_USERDATA, windows.LONG_PTR( 0 ));
      windows.DestroyWindow( HWND );
      LeakDEALLOCATE( HWND );
      HWND := NIL;
      __F();
    END;

    joinedTo := NIL;
  END OnLeave;
  
  PUBLIC VIRTUAL PROCEDURE JoinMessageThread( JoinTo : OSALmsg.TPMessageQueueThread; CallOnJoinInThread : BOOLEAN );
  BEGIN
    IF JoinTo = NIL THEN
      ASSERT( joinedTo = NIL );
      OnJoin( JoinTo );
    ELSE
      JoinTo^.Join( ADR( SELF ), CallOnJoinInThread );
    END;
  END JoinMessageThread;

  PUBLIC VIRTUAL PROCEDURE LeaveMessageThread( CallOnLeaveInThread : BOOLEAN );
  BEGIN
    IF joinedTo = NIL THEN
      OnLeave();
    ELSE
      JoinedTo^.Leave( ADR( SELF ), CallOnLeaveInThread );
    END;
  END LeaveMessageThread;

BEGIN
  joinedTo := NIL;
  HWND := NIL;
FINALLY
  Dispose();
END Win32MessageHandler;

END Win32msg.