IMPLEMENTATION MODULE msgWin32;

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

PROCEDURE Win32MsgBase() : CARDINAL;
BEGIN
   RETURN windows.WM_USER + 64;
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
   Handler : msgOSAL.TPMessageHandler;
   Result : PTR;
BEGIN
   IF HandleToHandler( hwnd, OUT Handler ) THEN
      Msg.Target := Handler;
      Msg.Message := message;
      Msg[2] := wParam;
      Msg[3] := PTR( lParam );
   ELSE
      RETURN windows.DefWindowProc( hwnd, message, wParam, lParam );
   END;
   IF Handler^.Message( Msg, msgOSAL.delSynchronous, ADR( Result )) THEN
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

PROCEDURE HandleToHandler( CONST Handle : PTR; OUT Handler : msgOSAL.TPMessageHandler ) : BOOLEAN;
BEGIN
  IF Handle = NIL THEN
    RETURN FALSE;
  ELSIF windows.GetClassLongPtr( Handle, windows.GCW_ATOM ) = windows.ULONG_PTR( WndClass ) THEN
    Handler := msgOSAL.TPMessageHandler( windows.GetWindowLongPtr( Handle, windows.GWL_USERDATA ));
    RETURN Handler <> NIL;
  ELSE
    RETURN FALSE;
  END;
END HandleToHandler;

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

  PUBLIC VIRTUAL PROPERTY Win32Message.Target GET : msgOSAL.TPMessageHandler;
  BEGIN
    RETURN target;
  END Win32Message.Target;
  
  PUBLIC VIRTUAL PROPERTY Win32Message.Target SET( Value : msgOSAL.TPMessageHandler );
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
  
  PUBLIC VIRTUAL READONLY PROPERTY Win32Message.ParameterCount GET : CARDINAL;
  BEGIN
    RETURN 4;
  END Win32Message.ParameterCount;

  PUBLIC VIRTUAL INDEX Win32Message GET( ParameterIndex : CARDINAL ) : PTR;
  BEGIN
    CASE ParameterIndex OF
    | 0: RETURN target;
    | 1: RETURN message;
    | 2: RETURN wParam;
    | 3: RETURN lParam;
    ELSE RETURN 0;
    END;
  END Win32Message;

  PUBLIC VIRTUAL INDEX Win32Message SET( ParameterIndex : CARDINAL; Value : PTR );
  BEGIN
    CASE ParameterIndex OF
    | 0: target := Value;
    | 1: message := CARDINAL( LOPTRLONGWORD( Value ));
    | 2: wParam := Value;
    | 3: lParam := Value;
    END;
  END Win32Message;

  PUBLIC VIRTUAL PROCEDURE Clone() : POINTER TO msgOSAL.IMessage;
  VAR
    Message : POINTER TO Win32Message;
  BEGIN
    NEW( Message );
    Message^ := SELF;
    RETURN Message;
  END Clone;

  PUBLIC OPERATOR :=( CONST MSG : Win32Message );
  BEGIN
    target := MSG.target;
    message := MSG.message;
    wParam := MSG.wParam;
    lParam := MSG.lParam;
  END :=;

BEGIN
  target := NIL;
  message := windows.WM_NULL;
  lParam := 0;
  wParam := 0;
END Win32Message;

CLASS IMPLEMENTATION Win32MessageHandler;

  PUBLIC VIRTUAL READONLY PROPERTY Win32MessageHandler.SelfContext GET : BOOLEAN;
  BEGIN
    RETURN LOPTRLONGWORD( windows.GetWindowThreadProcessId( HWND, NIL )) = windows.GetCurrentThreadId();
  END Win32MessageHandler.SelfContext;

  PUBLIC VIRTUAL READONLY PROPERTY Win32MessageHandler.Handle GET : PTR;
  BEGIN
    RETURN HWND;
  END Win32MessageHandler.Handle;

  PUBLIC PROCEDURE Win32MessageHandler.Init();
  BEGIN
    CreateHWND();
  END Win32MessageHandler.Init;
  
  PUBLIC PROCEDURE Dispose();
  BEGIN
    DestroyHWND();
  END Dispose;

   PUBLIC VIRTUAL PROCEDURE Message( CONST MSG : msgOSAL.IMessage; Delivery : msgOSAL.TDelivery; Result : PPTR ) : BOOLEAN;
   VAR
      LResult : PTR;
      Repeat : PTR;
      Timer : PTR;
   BEGIN
      IF ( Delivery = msgOSAL.delSynchronous ) OR ( Delivery = msgOSAL.delSynchronousInThread ) AND SelfContext THEN
         IF MSG[1] = windows.WM_TIMER THEN
            Timer := MSG[2];
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
         windows.PostMessage( HWND, MSG.Message, windows.WPARAM( MSG[2] ), windows.LPARAM( MSG[3] ));
      END;
      IF Result <> NIL THEN
         Result^ := 0;
      END;
      RETURN TRUE;
   END Message;

   INTERNAL VIRTUAL PROCEDURE OnMessage( CONST MSG : msgOSAL.IMessage; OUT Result : PTR ) : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END Win32MessageHandler.OnMessage;

  INTERNAL VIRTUAL PROCEDURE StartTimer( Timer : PTR; PeriodMS : CARDINAL; Repeat : BOOLEAN );
  BEGIN
    IF HWND = NIL THEN
      RETURN;
    ELSIF Timers.Contains( Timer ) THEN
      windows.KillTimer( HWND, Timer );
      Timers.Remove( Timer );
    END;
    Timers.Add( windows.SetTimer( HWND, Timer, PeriodMS, NIL ), PTR( Repeat )); // IA64PTR
  END StartTimer;
  
  INTERNAL VIRTUAL PROCEDURE TimerRunning( Timer : PTR ) : BOOLEAN;
  BEGIN
    IF HWND = NIL THEN
      RETURN FALSE;
    ELSE
      RETURN Timers.Contains( Timer );
    END;
  END TimerRunning;

  INTERNAL VIRTUAL PROCEDURE StopTimer( Timer : PTR );
  BEGIN
    IF HWND = NIL THEN
      RETURN;
    ELSIF Timers.Contains( Timer ) THEN
      windows.KillTimer( HWND, Timer );
      Timers.Remove( Timer );
    END;
  END StopTimer;
  
   INTERNAL VIRTUAL PROCEDURE OnTimer( Timer : PTR );
   BEGIN
   END OnTimer;

  PRIVATE VIRTUAL PROCEDURE CreateHWND();
  BEGIN
    IF HWND <> NIL THEN
      RETURN;
    END;
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
  END CreateHWND;

  PRIVATE VIRTUAL PROCEDURE DestroyHWND();
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
  END DestroyHWND;

BEGIN
  HWND := NIL;
FINALLY
  Dispose();
END Win32MessageHandler;

END msgWin32.