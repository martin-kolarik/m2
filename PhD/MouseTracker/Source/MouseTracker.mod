MODULE MouseTracker;

FROM Storage IMPORT
  ALLOCATE, DEALLOCATE;

IMPORT
   windows,
   wincon;
  
IMPORT
   datetime,
   FIO,
   FIOO,
   lists,
   log,
   Storage,
   StorageO,
   Strings,
   StringsO,
   Sync,
   TextWriter,
   thread;

IMPORT
   OSALmsg,
   Win32msg,
   Win32msgqueuethread;

TYPE
   THookMessage = RECORD
      DiffMS : LONGREAL;
      Message : PTR;
      Event : windows.MSLLHOOKSTRUCT;
   END; // RECORD
   TPHookMessage = POINTER TO THookMessage;

   TRawInputMessage = RECORD
      DiffMS : LONGREAL;
      Event : windows.RAWMOUSE;
   END; // RECORD
   TPRawInputMessage = POINTER TO TRawInputMessage;

CLASS CMessageHandler( Win32msg.Win32MessageHandler ) IMPLEMENTS thread.IRunnable;

   // IRunnable
   INTERNAL VIRTUAL PROCEDURE OnRun( Restarted : BOOLEAN; CONST Helper : thread.IRunnableHelper ) : CARDINAL; // Restarted is TRUE if recovery from crash has been requested

   // IMessageHandler
   INTERNAL VIRTUAL PROCEDURE OnMessage( CONST MSG : OSALmsg.IMessage; OUT Result : PTR ) : BOOLEAN;

   // SELF
   PUBLIC WRITEONLY PROPERTY
      LogPath : StringsO.CString;

   PUBLIC PROCEDURE Init();

   PUBLIC PROCEDURE EnqueueLLHook( message : PTR; event : windows.PMSLLHOOKSTRUCT );
   PUBLIC PROCEDURE EnqueueRawInput( rawInput : windows.PRAWINPUT );

   PRIVATE VAR
      // load event buffer
      _Buffer : StorageO.CMemoryBuffer;
      // deferred event processing
      _Lock : Sync.LOCK;
      _Signal : Sync.SIGNAL;
      _Queue : lists.CBufferList;
      // processing thread
      _LogThread : thread.Thread;
      _Logger : log.CLogger;
      // coordinate memos
      _RawInputAbsX : INTEGER;
      _RawInputAbsY : INTEGER;
      _LastHookAbsX : INTEGER;
      _LastHookAbsY : INTEGER;
      // timestamps
      _RawInputTime : datetime.HighResolutionTime;
      _HookTime : datetime.HighResolutionTime;

   PRIVATE PROCEDURE ProcessRawInput( CONST buffer : StorageO.CMemoryBuffer );
   PRIVATE PROCEDURE ProcessLLHook( CONST buffer : StorageO.CMemoryBuffer );

END CMessageHandler;

CLASS IMPLEMENTATION CMessageHandler;

   INTERNAL VIRTUAL PROCEDURE OnRun( Restarted : BOOLEAN; CONST Helper : thread.IRunnableHelper ) : CARDINAL; // Restarted is TRUE if recovery from crash has been requested
   VAR
      al : Sync.AutoLock;
      buffer : StorageO.CMemoryBuffer;
      d : PTR;
      haveData : BOOLEAN;
   BEGIN
      LOOP
         CASE Helper.WaitForStopRequestAndSignal( ADR( _Signal ), 60000 ) OF // arCompleted for Stop request, arPartCompleted for SIGNAL, arNoData for duty loop, arPending for message (if thread supports them)
         //-----
         | Sync.arCompleted : // exit
            EXIT;

         //-----
         | Sync.arTimeout : // liveness check
           _Logger.LogS( log.ldMessage, 0, L"", L"liveness check" );

         //-----
         | Sync.arPartCompleted : // _Signal signalled
            LOOP
               IF al.TakeSafe( REF _Lock, L"Unable to lock queue for processing" ) <> Sync.arCompleted THEN
                  EXIT;
               END;
               haveData := _Queue.Dequeue( OUT buffer, OUT d );
               al.Unlock();
               IF NOT haveData THEN
                  EXIT;
               END;

               IF d = 0 THEN
                  ProcessRawInput( buffer );
               ELSE
                  ProcessLLHook( buffer );
               END;
            END;

         //-----
         END; // CASE
      END; // LOOP
      RETURN 0;
   END OnRun;

   INTERNAL VIRTUAL PROCEDURE OnMessage( CONST MSG : OSALmsg.IMessage; OUT Result : PTR ) : BOOLEAN;
   VAR
      neededBufferSize : CARDINAL := 0;
      rawInput : windows.PRAWINPUT;
   BEGIN
      IF MSG.Message <> windows.WM_INPUT THEN
         RETURN FALSE;
      END;

      // determine size and allocate buffer
      IF windows.GetRawInputData( MSG[Win32msg.MI_LPARAM], windows.RID_INPUT, NIL, ADR( neededBufferSize ), SIZE( windows.RAWINPUTHEADER )) = -1 THEN // error
         // TODO
         RETURN TRUE;
      ELSIF neededBufferSize > _Buffer.Size THEN
         _Buffer.Size := (( neededBufferSize + 1023 ) DIV 1024 ) * 1024;
      END;
      
      // load input data
      IF windows.GetRawInputData( MSG[Win32msg.MI_LPARAM], windows.RID_INPUT, _Buffer.Data, ADR( neededBufferSize ), SIZE( windows.RAWINPUTHEADER )) = -1 THEN // error
         // TODO
         RETURN TRUE;
      END;

      rawInput := windows.PRAWINPUT( _Buffer.Data );
      IF rawInput^.header.dwType = windows.RIM_TYPEMOUSE THEN // OK, we have mouse, queue the event
         EnqueueRawInput( rawInput );
      END;

      windows.DefRawInputProc( ADR( rawInput ), 1, SIZE( windows.RAWINPUTHEADER ));
      
      RETURN TRUE;
   END OnMessage;

   PUBLIC PROPERTY LogPath SET( CONST value : StringsO.CString );
   VAR
      cs : StringsO.CString := value;
      dt : datetime.DateTime;
      s : ARRAY [0..31] OF WCHAR;
   BEGIN
      dt.SetNowUTC();
      dt.ToStringOA( L".yyyyMMddHHmm.", TRUE, TRUE, OUT s );
      cs.ReplaceOA( ".", s );
      _Logger.SetLogFile( OA( cs.Length-1, cs.Data ));
   END LogPath;

   PUBLIC PROCEDURE Init();
   VAR
      point : windows.POINT;
   BEGIN
      SUPER.Init( TRUE );

      // initialize mouse position
      windows.GetCursorPos( ADR( point ));
      _RawInputAbsX := point.x;
      _RawInputAbsY := point.y;

      _RawInputTime.SetNow();
      _HookTime.SetNow();

      // run
      _LogThread.RunWithRunnable( ADR( SELF ));
   END Init;

   PUBLIC PROCEDURE EnqueueLLHook( message : PTR; _event : windows.PMSLLHOOKSTRUCT );
   VAR
      al : Sync.AutoLock;
      event : THookMessage;
      now : datetime.HighResolutionTime;
      ts : datetime.TimeSpan;
   BEGIN
      now := datetime.NowHR();
      ts := now - _HookTime;
      _HookTime := now;

      event.DiffMS := ts.Milliseconds;
      event.Message := message;
      event.Event := _event^;

      IF al.TakeSafe( REF _Lock, L"Unable to lock event queue" ) = Sync.arCompleted THEN
         _Queue.EnqueueOA( event, 1 );
         IF _Queue.Count = 1 THEN
            _Signal.Signal();
         END;
         al.Unlock();
      END;
   END EnqueueLLHook;

   PUBLIC PROCEDURE EnqueueRawInput( rawInput : windows.PRAWINPUT );
   VAR
      al : Sync.AutoLock;
      event : TRawInputMessage;
      now : datetime.HighResolutionTime;
      ts : datetime.TimeSpan;
   BEGIN
      now := datetime.NowHR();
      ts := now - _RawInputTime;
      _RawInputTime := now;

      event.DiffMS := ts.Milliseconds;
      event.Event := rawInput^.data.mouse;

      IF al.TakeSafe( REF _Lock, L"Unable to lock event queue" ) = Sync.arCompleted THEN
         _Queue.EnqueueOA( event, 0 );
         IF _Queue.Count = 1 THEN
            _Signal.Signal();
         END;
         al.Unlock();
      END;
   END EnqueueRawInput;

   PRIVATE PROCEDURE ProcessRawInput( CONST buffer : StorageO.CMemoryBuffer );
   VAR
      event : TPRawInputMessage;
      relX : INTEGER;
      relY : INTEGER;
      sbuttons, swheel, sx, sy, n : ARRAY [0..31] OF WCHAR;
   BEGIN
      event := buffer.Data;

      // position
      IF windows.MOUSE_MOVE_ABSOLUTE AND event^.Event.usFlags = windows.MOUSE_MOVE_ABSOLUTE THEN // count relative from absolute
         relX := event^.Event.lLastX - _RawInputAbsX;
         relY := event^.Event.lLastY - _RawInputAbsY;
         _RawInputAbsX := event^.Event.lLastX;
         _RawInputAbsY := event^.Event.lLastY;
      ELSE // count absolute from relative
         relX := event^.Event.lLastX;
         relY := event^.Event.lLastY;
         INC( _RawInputAbsX, relX );
         INC( _RawInputAbsY, relY );
      END;

      Strings.FromINT32W( relX, 10, OUT sx );
      Strings.FromINT32W( _RawInputAbsX, 10, OUT n );
      Strings.AppendW( REF sx, L">" );
      Strings.AppendW( REF sx, n );
      Strings.FromINT32W( relY, 10, OUT sy );
      Strings.FromINT32W( _RawInputAbsY, 10, OUT n );
      Strings.AppendW( REF sy, L">" );
      Strings.AppendW( REF sy, n );

      // wheel
      IF windows.RI_MOUSE_WHEEL AND event^.Event.usButtonFlags = windows.RI_MOUSE_WHEEL THEN
         Strings.FromINT32W( INTEGER( INT16( event^.Event.usButtonData )), 10, OUT swheel );
      ELSE
         swheel := L"0";
      END;

      // buttons
      sbuttons[0] := L" ";
      IF windows.RI_MOUSE_BUTTON_1_DOWN AND event^.Event.usButtonFlags = windows.RI_MOUSE_BUTTON_1_DOWN THEN
         sbuttons[1] := L"D";
      ELSIF windows.RI_MOUSE_BUTTON_1_UP AND event^.Event.usButtonFlags = windows.RI_MOUSE_BUTTON_1_UP THEN
         sbuttons[1] := L"U";
      ELSE
         sbuttons[1] := L"-";
      END;
      IF windows.RI_MOUSE_BUTTON_2_DOWN AND event^.Event.usButtonFlags = windows.RI_MOUSE_BUTTON_2_DOWN THEN
         sbuttons[2] := L"D";
      ELSIF windows.RI_MOUSE_BUTTON_2_UP AND event^.Event.usButtonFlags = windows.RI_MOUSE_BUTTON_2_UP THEN
         sbuttons[2] := L"U";
      ELSE
         sbuttons[2] := L"-";
      END;
      IF windows.RI_MOUSE_BUTTON_3_DOWN AND event^.Event.usButtonFlags = windows.RI_MOUSE_BUTTON_3_DOWN THEN
         sbuttons[3] := L"D";
      ELSIF windows.RI_MOUSE_BUTTON_3_UP AND event^.Event.usButtonFlags = windows.RI_MOUSE_BUTTON_3_UP THEN
         sbuttons[3] := L"U";
      ELSE
         sbuttons[3] := L"-";
      END;
      IF windows.RI_MOUSE_BUTTON_4_DOWN AND event^.Event.usButtonFlags = windows.RI_MOUSE_BUTTON_4_DOWN THEN
         sbuttons[4] := L"D";
      ELSIF windows.RI_MOUSE_BUTTON_4_UP AND event^.Event.usButtonFlags = windows.RI_MOUSE_BUTTON_4_UP THEN
         sbuttons[4] := L"U";
      ELSE
         sbuttons[4] := L"-";
      END;
      IF windows.RI_MOUSE_BUTTON_5_DOWN AND event^.Event.usButtonFlags = windows.RI_MOUSE_BUTTON_5_DOWN THEN
         sbuttons[5] := L"D";
      ELSIF windows.RI_MOUSE_BUTTON_5_UP AND event^.Event.usButtonFlags = windows.RI_MOUSE_BUTTON_5_UP THEN
         sbuttons[5] := L"U";
      ELSE
         sbuttons[5] := L"-";
      END;
      sbuttons[6] := 0W;

      Strings.FromLONGREALW( event^.DiffMS, FALSE, OUT n );
      Strings.PrependW( REF sbuttons, n );

      // log everything
      _Logger.LogSSSS( log.ldMessage, 0, L"R", sbuttons, sx, sy, swheel );
   END ProcessRawInput;

   PRIVATE PROCEDURE ProcessLLHook( CONST buffer : StorageO.CMemoryBuffer );
   VAR
      event : TPHookMessage;
      relX : INTEGER := 0;
      relY : INTEGER := 0;
      sbuttons, swheel, sx, sy, n : ARRAY [0..31] OF WCHAR;
   BEGIN
      event := buffer.Data;

      IF _LastHookAbsX = MIN( INTEGER ) THEN
         relX := 0;
      ELSE
         relX := event^.Event.pt.x - _LastHookAbsX;
      END;
      IF _LastHookAbsY = MIN( INTEGER ) THEN
         relY := 0;
      ELSE
         relY := event^.Event.pt.y - _LastHookAbsY;
      END;
      _LastHookAbsX := event^.Event.pt.x;
      _LastHookAbsY := event^.Event.pt.y;

      Strings.FromINT32W( relX, 10, OUT sx );
      Strings.FromINT32W( _LastHookAbsX, 10, OUT n );
      Strings.AppendW( REF sx, L">" );
      Strings.AppendW( REF sx, n );
      Strings.FromINT32W( relY, 10, OUT sy );
      Strings.FromINT32W( _LastHookAbsY, 10, OUT n );
      Strings.AppendW( REF sy, L">" );
      Strings.AppendW( REF sy, n );

      swheel := L"0";
      sbuttons := L" -----";
      CASE event^.Message OF
      | windows.WM_LBUTTONDOWN, windows.WM_NCLBUTTONDOWN :
         sbuttons[1] := L"D";
      | windows.WM_LBUTTONUP, windows.WM_NCLBUTTONUP :
         sbuttons[1] := L"U";
      | windows.WM_RBUTTONDOWN, windows.WM_NCRBUTTONDOWN :
         sbuttons[2] := L"D";
      | windows.WM_RBUTTONUP, windows.WM_NCRBUTTONUP :
         sbuttons[2] := L"U";
      | windows.WM_MBUTTONDOWN, windows.WM_NCMBUTTONDOWN :
         sbuttons[3] := L"D";
      | windows.WM_MBUTTONUP, windows.WM_NCMBUTTONUP :
         sbuttons[3] := L"U";
      | windows.WM_XBUTTONDOWN, windows.WM_NCXBUTTONDOWN :
         IF HIWORD( event^.Event.mouseData ) = windows.XBUTTON1 THEN
            sbuttons[4] := L"D";
         ELSE
            sbuttons[5] := L"D";
         END;
      | windows.WM_XBUTTONUP, windows.WM_NCXBUTTONUP :
         IF HIWORD( event^.Event.mouseData ) = windows.XBUTTON1 THEN
            sbuttons[4] := L"U";
         ELSE
            sbuttons[5] := L"U";
         END;
      | windows.WM_MOUSEWHEEL :
         Strings.FromINT32W( INTEGER( INT16( HIWORD( event^.Event.mouseData ))), 10, OUT swheel );
      END;
      sbuttons[6] := 0W;

      Strings.FromLONGREALW( event^.DiffMS, FALSE, OUT n );
      Strings.PrependW( REF sbuttons, n );

      // log everything
      _Logger.LogSSSS( log.ldMessage, 0, L"H", sbuttons, sx, sy, swheel );
   END ProcessLLHook;

BEGIN
   _Buffer.Size := 128;
   _Signal.Init( Sync.stEventAutoreset, L"", FALSE );
   _Logger.Names := TRUE;
   _Logger.Levels := FALSE;
   _Logger.TimeStamps := FALSE;
   _Logger.Output := log.outsFile;
   _Logger.SetName( L"trk" );
   _Logger.SetLogFile( L"C:\Mouse.log" );

   _RawInputAbsX := 0;
   _RawInputAbsY := 0;
   _LastHookAbsX := MIN( INTEGER );
   _LastHookAbsY := MIN( INTEGER );
FINALLY
   _LogThread.Stop( TRUE );
END CMessageHandler;

VAR
  gMessageHandler : CMessageHandler;

# save, call( convention => stdcall )
PROCEDURE MouseLLHook( nCode : INTEGER; wParam : windows.WPARAM; lParam : windows.LPARAM );
# restore
BEGIN
   gMessageHandler.EnqueueLLHook( wParam, windows.PMSLLHOOKSTRUCT( lParam ));
   windows.CallNextHookEx( NIL, nCode, wParam, lParam );
END MouseLLHook;

TYPE
  TParamStringArray  = ARRAY [0..0] OF POINTER TO ARRAY [0..511] OF WCHAR;
  TPParamStringArray = POINTER TO TParamStringArray;

# save, call( convention => cdecl )
PROCEDURE Main( argc : INTEGER; argp : TPParamStringArray ) : INTEGER;
# restore
LABEL
   Error;
VAR
   errout : TextWriter.TPTextWriter := TextWriter.errout();
   hook : windows.HANDLE;
   i : INTEGER;
   msg : windows.MSG;
   path : ARRAY [0..511] OF WCHAR;
   Result : INTEGER := 0;
   rid : windows.RAWINPUTDEVICE;
   start : CARD32;
BEGIN
   path := "C:\Mouse.log";

   wincon.AttachConsole( -1 );

   IF argc < 2 THEN
      errout^.LineEnd();
      errout^.LineEnd();
      errout^.WriteOA( L"MouseTracker: missing output file specification", TRUE );
      GOTO Error;
   END;

   i := 1;
   WHILE i < argc DO
      IF ( argp^[i]^[0] = L'/' ) OR ( argp^[i]^[0] = L'-' ) THEN // option

         CASE argp^[i]^[1] OF
         | L'l' :
            INC( i );
            IF i >= argc THEN // error
               errout^.LineEnd();
               errout^.LineEnd();
               errout^.WriteOA( L"MouseTracker: missing file path", TRUE );
               GOTO Error;
            END;
            ASSIGNsz( path, PWCHAR( argp^[i] ));
         ELSE
            errout^.LineEnd();
            errout^.LineEnd();
            errout^.WriteOA( L"MouseTracker: invalid option ", FALSE ); errout^.WriteOA( argp^[i]^, TRUE );
            GOTO Error;
         END;

      END;
      
      INC( i );
   END; // WHILE
   gMessageHandler.LogPath := StringsO.FromOA( path );

   // startup
   Win32msgqueuethread.Startup();
   gMessageHandler.Init();

   // hook mouse
   rid.usUsagePage := 01H; 
   rid.usUsage := 02H; 
   rid.dwFlags := windows.RIDEV_NOLEGACY OR windows.RIDEV_INPUTSINK;   // adds HID mouse and also ignores legacy mouse messages
   rid.hwndTarget := gMessageHandler.Handle;
   IF windows.RegisterRawInputDevices( ADR( rid ), 1, SIZE( rid )) = windows.False THEN
      ASM
         int 3;
      END;
   END;

   hook := windows.SetWindowsHookEx( windows.WH_MOUSE_LL, windows.HOOKPROC( MouseLLHook ), NIL, 0 );
   IF hook = NIL THEN
      ASM
         int 3;
      END;
   END;

   // run main thread loop, max for 2 hours
   LOOP
   start := datetime.UptimeMS32();
   LOOP
      windows.MsgWaitForMultipleObjectsEx( 0, NIL, 60 * 1000, windows.QS_ALLINPUT, windows.MWMO_INPUTAVAILABLE );
      WHILE windows.PeekMessage( ADR( msg ), NIL, 0, 0, windows.PM_REMOVE ) = windows.True DO
         windows.TranslateMessage( ADR( msg ));
         windows.DispatchMessage( ADR( msg ));
      END;
      IF datetime.UptimeMS32() - start > 60 * 60 * 1000 THEN

         windows.Beep( 1000, 250 );
         Sync.Sleep( 150 );
         windows.Beep( 1000, 250 );
         Sync.Sleep( 150 );
         windows.Beep( 1000, 250 );

         EXIT;
      END;
   END; // LOOP
   END; // outer LOOP

   windows.UnhookWindowsHookEx( hook );

   // unhook mouse
   rid.usUsagePage := 01H; 
   rid.usUsage := 02H; 
   rid.dwFlags := windows.RIDEV_REMOVE;
   rid.hwndTarget := NIL;
   windows.RegisterRawInputDevices( ADR( rid ), 1, SIZE( rid ));

   // cleanup
   gMessageHandler.Dispose();
   Win32msgqueuethread.Cleanup();

   RETURN Result;

Error:
   errout^.WriteOA( L"  usage: MouseTracker [-l log-file-path]", TRUE );
   RETURN Result;
END Main;
  
END MouseTracker.

