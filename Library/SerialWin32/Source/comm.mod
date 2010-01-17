IMPLEMENTATION MODULE comm;

(*/*)
(* ================================================================ *)
(*   CwComm - COM Communication Layer for Control Web               *)
(*                                                                  *)
(*   (c) 1998 by DAD, Moravian Instruments                          *)
(* ================================================================ *)
(*/*)

(*/*

  Last Modified:

                version 4.0
                  07/02/2003  -- Tx double-buffering changed to circular buffer + cache
                                 (TxFree/TxCount/Send changed)
                version 4.1
                  02/02/2006  -- GetProperty error - CTS, DSR, RING, RLSD fails


*** TO DO LIST ***

  %F WINCE -- nevolat pokazde SetCommMask, jen tehdy, pokud zmena, nutno vsak osetrit, aby se do WaitCommEvent nevlezlo vicekrat
  %T WINCE -- mozna to pujde taky, tim padem by nevyskakoval thread CECommThreadWait

*/*)

(*# call( o_a_size=>on,
          o_a_copy=>off ) *)

IMPORT
  comm_;

IMPORT 
  windows,
  winerror;

IMPORT
  FIO,
  INIFile,
  Storage,
  Strings,
  StringsO;

FROM Storage IMPORT
  ALLOCATE, REALLOCATE, DEALLOCATE;
  
FROM Strings IMPORT
  LowerizeW;

(*%T DEBUG *)
//  IMPORT vd;
//  IMPORT pr;
(*%E DEBUG *)

IMPORT stdio;
CONST
(*%F UNICODE *)
  __sprintf ::= stdio.sprintf;
(*%E UNICODE *)
(*%T UNICODE *)
  __sprintf ::= stdio.swprintf;
(*%E UNICODE *)

(* ================================================================ *)
CONST
  ASCII_XON  = CHAR(11H);
  ASCII_XOFF = CHAR(13H);

(* ================================================================ *)


(*%T DEBUG *)
(*/*
  PROCEDURE _DbgFocus( bs : BITSET );
  BEGIN
    vd.Lock();
  // ---------- >>>
    vd.WrStr('Event:'); vd.WrLn(); vd.IncIndent( 4 );
    IF seriallink.comfBreakEvent IN bs THEN
      vd.WrStr('comfBreakEvent'); vd.WrLn();
    END;
    IF seriallink.comfCTS IN bs THEN
      vd.WrStr('comfBreakEvent'); vd.WrLn();
    END;
    IF seriallink.comfDSR IN bs THEN
      vd.WrStr('comfCTS'); vd.WrLn();
    END;
    IF seriallink.comfErrorEvent IN bs THEN
      vd.WrStr('comfErrorEvent'); vd.WrLn();
    END;
    IF seriallink.comfRing IN bs THEN
      vd.WrStr('comfRing'); vd.WrLn();
    END;
    IF seriallink.comfRLSD IN bs THEN
      vd.WrStr('comfRLSD'); vd.WrLn();
    END;
    IF seriallink.comfRxChar IN bs THEN
      vd.WrStr('comfRxChar'); vd.WrLn();
    END;
    IF seriallink.comfRxEvent IN bs THEN
      vd.WrStr('comfRxEvent'); vd.WrLn();
    END;
    IF seriallink.comfTxEmpty IN bs THEN
      vd.WrStr('comfTxEmpty'); vd.WrLn();
    END;
    IF seriallink.comfRx80Full IN bs THEN
      vd.WrStr('comfRx80Full'); vd.WrLn();
    END;
    IF seriallink.comfRecvCountReached IN bs THEN
      vd.WrStr('comfRecvCountReached'); vd.WrLn();
    END;
    IF seriallink.comfRxTimeout IN bs THEN
      vd.WrStr('comfRxTimeout'); vd.WrLn();
    END;
    IF seriallink.comfTxTimeout IN bs THEN
      vd.WrStr('comfTxTimeout'); vd.WrLn();
    END;
    IF seriallink.comfRxDataQueued IN bs THEN
      vd.WrStr('comfRxDataQueued'); vd.WrLn();
    END;
    IF seriallink.comfCE IN bs THEN
      vd.WrStr('comfCE'); vd.WrLn();
    END;
    IF seriallink.comfCTSHold IN bs THEN
      vd.WrStr('comfCTSHold'); vd.WrLn();
    END;
    IF seriallink.comfDSRHold IN bs THEN
      vd.WrStr('comfDSRHold'); vd.WrLn();
    END;
    IF seriallink.comfRingHold IN bs THEN
      vd.WrStr('comfRingHold'); vd.WrLn();
    END;
    IF seriallink.comfRLSDHold IN bs THEN
      vd.WrStr('comfRLSDHold'); vd.WrLn();
    END;
    vd.DecIndent( 4 );
  // ---------- <<<
    vd.Unlock();
  END _DbgFocus;
*/*)
(*%E DEBUG *)

(* ================================================================ *)

(*# save, call( convention=>stdcall ) *) (* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> *)
  PROCEDURE CommThreadAction( PComm : TPCommStream ) : CARDINAL;
  BEGIN
//(*%T DEBUG *) vd.WrStr('CommThreadAction START'); vd.WrLn(); (*%E DEBUG *)
    PComm^.CommThread();
//(*%T DEBUG *) vd.WrStr('CommThreadAction STOP'); vd.WrLn(); (*%E DEBUG *)
    windows.ExitThread( 0 );
    RETURN 0;
  END CommThreadAction;
(*# restore *) (* <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< *)

(*%T SYNC_COMM *)
(*# save, call( convention=>stdcall ) *) (* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> *)
  PROCEDURE CECommThread_Wait( PComm : TPCommStream ) : CARDINAL;
  BEGIN
//(*%T DEBUG *) vd.WrStr('CECommThread_Wait START'); vd.WrLn(); (*%E DEBUG *)
    PComm^.CECommThreadWait();
//(*%T DEBUG *) vd.WrStr('CECommThread_Wait STOP'); vd.WrLn(); (*%E DEBUG *)
    windows.ExitThread( 0 );
    RETURN 0;
  END CECommThread_Wait;

  PROCEDURE CECommThread_Write( PComm : TPCommStream ) : CARDINAL;
  BEGIN
//(*%T DEBUG *) vd.WrStr('CECommThread_Write START'); vd.WrLn(); (*%E DEBUG *)
    PComm^.CECommThreadWrite();
//(*%T DEBUG *) vd.WrStr('CECommThread_Write STOP'); vd.WrLn(); (*%E DEBUG *)
    windows.ExitThread( 0 );
    RETURN 0;
  END CECommThread_Write;
(*# restore *) (* <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< *)
(*%E SYNC_COMM *)


  PROCEDURE commWait( ms : CARDINAL );
#if #not( PlatformName #startswith L"WinCE" ) #then
  CONST
    msHiThresh    = 15; // ms
    msLoThresh    = 10; // ms
    msErrorThresh = 70; // ms
  TYPE
    TLarge =  RECORD
                CASE :BOOLEAN OF
                | FALSE:
                  li : windows.LARGE_INTEGER;
                | TRUE:
                  Quad : INT64;
                END;
              END;
  VAR
    bSleep    : BOOLEAN;
    PerfFreq,
    Perf_cnt,
    Perf_last : TLarge;
    Tick_cnt,
    Tick_last : CARDINAL;
    diff1     : CARDINAL;
    diff2     : CARDINAL;
    temp      : CARDINAL;
    P1ms      : CARDINAL;
#endif
  BEGIN
#if PlatformName #startswith L"WinCE" #then
    windows.Sleep( ms );
#else
    IF (ms > msHiThresh) OR (windows.QueryPerformanceFrequency( PerfFreq.li ) = windows.False) THEN
      windows.Sleep( ms );
    ELSE
    // see MS KB Q274323 -- Performance Counter Value May Unexpectedly Leap Forward
    // http://support.microsoft.com/default.aspx?scid=kb%3ben-us%3b274323
      bSleep := (ms > msLoThresh);
      P1ms   := CARDINAL( PerfFreq.Quad DIV INT64(1000));
      windows.QueryPerformanceCounter( Perf_last.li );
      Tick_last := windows.GetTickCount();
      WHILE (ms <> 0) DO
        IF bSleep THEN
          windows.Sleep( 1 );
        END;

        windows.QueryPerformanceCounter( Perf_cnt.li );
        Tick_cnt := windows.GetTickCount();

        diff1 := CARDINAL(Perf_cnt.Quad - Perf_last.Quad);
        IF (diff1 AND 80000000H) <> 0 THEN
          diff1 := -INTEGER(diff1);
        END;
        diff2 := Tick_cnt - Tick_last;
        IF Tick_cnt < Tick_last THEN
          diff2 := -INTEGER(diff2);
        END;
        IF (diff1 < P1ms) AND (diff2 <= msErrorThresh) THEN
        // nothing to do, 1ms did not past
        ELSE
        // convert diff1 to milliseconds
        // carry for overflow
          IF INT64(diff1) > PerfFreq.Quad THEN
            temp := CARDINAL( INT64(diff1) DIV PerfFreq.Quad );
            diff1 := CARDINAL( INT64(diff1) MOD PerfFreq.Quad );
          ELSE
            temp := 0;
          END;
          diff1 := 1000 * temp +
                   CARDINAL( INT64(diff1 * 1000) DIV PerfFreq.Quad );
          IF (diff1 > msErrorThresh) AND (diff2 < (msErrorThresh DIV 2)) THEN
          // error in performance counter occured...
            temp := diff2;
          ELSE
            temp := diff1;
          END;
          IF ms > temp THEN
            DEC( ms, temp );
          ELSE
            ms := 0;
          END;
          Perf_last.Quad := Perf_cnt.Quad;
          Tick_last := Tick_cnt;
        END;
      END; // WHILE
    END;
#endif
  END commWait;


(* ================================================================ *)
(* === IMPLEMENTATION ============================================= *)
(* ================================================================ *)

CLASS IMPLEMENTATION CCommStream; (* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>> *)

#if #not( PlatformName #startswith L"WinCE" ) #then
  PUBLIC VIRTUAL PROCEDURE Init( Device   : ARRAY OF CHAR;
                                 IniFilePath : ARRAY OF CHAR;
                                 fMultithreadLock, fPrivate : BOOLEAN;
                                 VAR ErrorString : ARRAY OF CHAR;
                                 VAR hSession : seriallink.TSessionHandle ) : BOOLEAN;
(*%F UNICODE *)
    PROCEDURE ConstructErrorMessage( err : CARDINAL; VAR ErrMsg : ARRAY OF CHAR );
    BEGIN
      vcom.GetErrorMessage( err, ErrMsg );
      IF ErrMsg[0] <> 0C THEN
        Str.Prepend( ErrMsg, ' (Win32: ' );
        Str.Append( ErrMsg, ')' );
      END;
    END ConstructErrorMessage;

  VAR
    wb    : windows.BOOL;
    b     : BOOLEAN;
    c     : CARDINAL;

    fn    : FIO.PathStr;
    s     : vcom.TString80;
    so    : vcom.TString80;
    ss    : vcom.TString255;

    Scanner : INIFile.CINIFile;

    i     : INTEGER;
    ok    : BOOLEAN;

  LABEL
    Error;

  BEGIN
    IF NOT Scanner.Init( IniFilePath ) THEN
      ASSIGN( ErrorString, comm_.errCANNOT_INITIALIZE );
      GOTO Error;
    END;

    hSession := GetNewSessionHandle();
    IF hSession = seriallink.InvalidSessionHandle THEN
      ASSIGN( ErrorString, comm_.errCANNOT_INITIALIZE );
      GOTO Error;
    END;

    IF comsInitialized IN CommState THEN
      IF fPrivate OR (comsPrivate IN CommState) THEN
        ASSIGN( ErrorString, comm_.errPRIVATE_CONFLICT );
        GOTO Error;
      END;
      INC( InitCount );
      IF fMultithreadLock THEN
        INCL( CommState, comsThreadLock );
      END;
      RETURN TRUE;
    END;
    IF fMultithreadLock THEN
      INCL( CommState, comsThreadLock );
    END;
    IF fPrivate THEN
      INCL( CommState, comsPrivate );
    END;
    INC( InitCount );

    IF NOT Scanner.SetSection( comm_.secCOMMPAR ) THEN
      ASSIGN( ErrorString, comm_.errCANNOT_INITIALIZE );
      GOTO Error;
    END;
    IF Scanner.GetKeyStr( comm_.keyFILE, fn ) THEN
      Scanner.Done();
      IF Scanner.Init( fn ) THEN
        IF NOT Scanner.SetSection( comm_.secCOMMPAR ) THEN
          ASSIGN( ErrorString, comm_.errCANNOT_INITIALIZE );
          GOTO Error;
        END;
      ELSE
        Strings.ConcatW( OUT ErrorString, comm_.errCANNOT_OPEN_, fn );
        GOTO Error;
      END;
    END;

    IF (Device[0] = 0C) THEN
      IF NOT Scanner.GetKeyStr( comm_.keyDEVICE, s ) THEN
        ASSIGN( ErrorString, comm_.errMISSING_DEVICE );
        GOTO Error;
      END;
    ELSE
      ASSIGN( s, Device );
    END;

    IF NOT Scanner.SetSection( s ) THEN
      Scanner.SetSection( comm_.secCOMMPAR )
    END;

    ASSIGN( so, s );

    HComm  := windows.CreateFile( s,
                                  windows.GENERIC_READ OR windows.GENERIC_WRITE,
                                  0,
                                  NIL,
                                  windows.OPEN_EXISTING,
                                (*%F SYNC_COMM *)
                                  windows.FILE_FLAG_OVERLAPPED OR windows.FILE_ATTRIBUTE_NORMAL,
                                (*%E SYNC_COMM *)
                                (*%T SYNC_COMM *)
                                  windows.FILE_ATTRIBUTE_NORMAL,
                                (*%E SYNC_COMM *)
                                  NIL );

    IF HComm = windows.INVALID_HANDLE_VALUE THEN
      ConstructErrorMessage( windows.GetLastError(), ss );
      LOW( s );
      Strings.PrependW( REF s, '\\.\' );
      HComm  := windows.CreateFile( s,
                                    windows.GENERIC_READ OR windows.GENERIC_WRITE,
                                    0,
                                    NIL,
                                    windows.OPEN_EXISTING,
                                (*%F SYNC_COMM *)
                                  windows.FILE_FLAG_OVERLAPPED OR windows.FILE_ATTRIBUTE_NORMAL,
                                (*%E SYNC_COMM *)
                                (*%T SYNC_COMM *)
                                  windows.FILE_ATTRIBUTE_NORMAL,
                                (*%E SYNC_COMM *)
                                    NIL );
    END;

    IF HComm = windows.INVALID_HANDLE_VALUE THEN
      Strings.ConcatW( OUT ErrorString, comm_.errCANNOT_OPEN_DEVICE_, so );
      Strings.AppendW( REF ErrorString, ss );
      GOTO Error;
    END;
    ASSIGN( OpenedDev, s );

    IF NOT Scanner.GetKeyStr( comm_.keyMODE, s ) THEN
      EXCL( CommState, comsHalfDuplex );
    ELSE
      ASSIGN( ss, s );
      LOW( ss );
      IF EQUALS( ss, comm_.keyFULLDUPLEX ) THEN
        EXCL( CommState, comsHalfDuplex );
      ELSIF EQUALS( ss, comm_.keyHALFDUPLEX ) THEN
        INCL( CommState, comsHalfDuplex );
      ELSE
        Strings.ConcatW( OUT ErrorString, comm_.errUNKNOWN_, s );
        GOTO Error;
      END;
    END;

    PreKey := 0;
    ok := Scanner.GetKeyInt( comm_.keyPREKEY, OUT PreKey );
    ok := Scanner.GetKeyInt( comm_.keyHOLDKEY, OUT HoldKey );

    IF NOT Scanner.GetKeyStr( comm_.keyPRIORITY, s ) THEN
      BasePriority := windows.THREAD_PRIORITY_NORMAL;
    ELSE
      ASSIGN( ss, s );
      LOW( ss );
      IF EQUALS( ss, comm_.keyIDLE ) THEN
        BasePriority := windows.THREAD_PRIORITY_IDLE;
      ELSIF EQUALS( ss, comm_.keyLOW ) THEN
        BasePriority := windows.THREAD_PRIORITY_LOWEST;
      ELSIF EQUALS( ss, comm_.keyBELOW_NORMAL ) = THEN
        BasePriority := windows.THREAD_PRIORITY_BELOW_NORMAL;
      ELSIF EQUALS( ss, comm_.keyNORMAL ) THEN
        BasePriority := windows.THREAD_PRIORITY_NORMAL;
      ELSIF EQUALS( ss, comm_.keyABOVE_NORMAL ) THEN
        BasePriority := windows.THREAD_PRIORITY_ABOVE_NORMAL;
      ELSIF EQUALS( ss, comm_.keyHIGH ) THEN
        BasePriority := windows.THREAD_PRIORITY_HIGHEST;
      ELSIF EQUALS( ss, comm_.keyREALTIME ) THEN
        BasePriority := windows.THREAD_PRIORITY_TIME_CRITICAL;
      ELSE
        Strings.ConcatW( OUT ErrorString, comm_.errUNKNOWN_, s );
        GOTO Error;
      END;
    END;

    AutoReadPending := Scanner.GetKeyBool( comm_.keyAUTO_READ, ok ) AND ok;

  // windows internal buffers
    RxWinBufSize := 4096;
    ok := Scanner.GetKeyInt( comm_.keyRX_BUFFER, OUT RxWinBufSize );
    TxWinBufSize := 4096;
    ok := Scanner.GetKeyInt( comm_.keyTX_BUFFER, OUT TxWinBufSize );

  // Rx frame buffer
    c  := RxWinBufSize;
    ok := Scanner.GetKeyInt( comm_.keyRX_FRAME_BUFFER, OUT c );
    IF ok AND (c < 96) OR (c > 2*65536) THEN
      Str.Concat( ErrorString, comm_.errSETUP_FAILED_, comm_.keyRX_FRAME_BUFFER );
      GOTO Error;
    END;
    c := MAX2( c, RxWinBufSize );
    RxQueue.Init( c );

  // Tx frame buffer
    c  := RxWinBufSize;
    ok := Scanner.GetKeyInt( comm_.keyTX_FRAME_BUFFER, OUT c );
    IF ok AND (c < 96) OR (c > 2*65536) THEN
      Str.Concat( ErrorString, comm_.errSETUP_FAILED_, comm_.keyTX_FRAME_BUFFER );
      GOTO Error;
    END;
    c := MAX2( c, TxWinBufSize );
    TxQueue.Init( c );

  // protocol
    WITH CommDCB DO
      DCBlength := SIZE(CommDCB);
      ok := Scanner.GetKeyInt( comm_.keyBAUDRATE, OUT c );
      BaudRate := windows.DWORD( c );
      IF NOT ok THEN
        Str.Concat( ErrorString, comm_.errMISSING_, comm_.keyBAUDRATE );
        GOTO Error;
      END;
      fBinary := windows.True;
      IF NOT Scanner.GetKeyStr( comm_.keyPARITY, s ) THEN
        fParity := windows.True;
        Parity  := windows.NOPARITY; (*// EVEN/MARK/NO/ODD/SPACE *)
      ELSE
        ASSIGN( ss, s );
        LOW( ss );
        IF EQUALS( ss, comm_.keyNONE ) OR EQUALS( ss, comm_.keyNO ) THEN
          fParity  := windows.True;
          Parity   := windows.NOPARITY;
        ELSIF EQUALS( ss, comm_.keyEVEN ) THEN
          fParity  := windows.True;
          Parity   := windows.EVENPARITY;
        ELSIF EQUALS( ss, comm_.keyMARK ) THEN
          fParity  := windows.True;
          Parity   := windows.MARKPARITY;
        ELSIF EQUALS( ss, comm_.keyODD ) THEN
          fParity  := windows.True;
          Parity   := windows.ODDPARITY;
        ELSIF EQUALS( ss, comm_.keySPACE ) THEN
          fParity  := windows.True;
          Parity   := windows.SPACEPARITY;
        ELSE
          Strings.ConcatW( OUT ErrorString, comm_.errUNKNOWN_, s );
          GOTO Error;
        END;
      END;

      b := Scanner.GetKeyBool( comm_.keyCTSFLOW, ok ) AND ok;
      fOutxCtsFlow := windows.DWORD( b );
      b := Scanner.GetKeyBool( comm_.keyDSRFLOW, ok ) AND ok;
      fOutxDsrFlow := windows.DWORD( b );

      IF NOT Scanner.GetKeyStr( comm_.keyDTRCONTROL, s ) THEN
        fDtrControl   := windows.DTR_CONTROL_DISABLE; (*// DISABLE/ENABLE/HANDSHAKE *)
      ELSE
        ASSIGN( ss, s );
        LOW( ss );
        IF EQUALS( ss, comm_.keyDISABLE ) OR EQUALS( ss, comm_.keyLOW ) THEN
          fDtrControl := windows.DTR_CONTROL_DISABLE;
        ELSIF EQUALS( ss, comm_.keyENABLE ) OR EQUALS( ss, comm_.keyHIGH ) THEN
          fDtrControl := windows.DTR_CONTROL_ENABLE;
        ELSIF EQUALS( ss, comm_.keyHANDSHAKE ) THEN
          fDtrControl := windows.DTR_CONTROL_HANDSHAKE;
        ELSIF EQUALS( ss, comm_.keyTOGGLE ) THEN
          fDtrControl := windows.DTR_CONTROL_DISABLE;
          INCL( CommState, comsToggleDTR );
        ELSIF EQUALS( ss, comm_.keyTOGGLE_NEG ) THEN
          fDtrControl := windows.DTR_CONTROL_DISABLE;
          INCL( CommState, comsNegToggleDTR );
        ELSE
          Strings.ConcatW( OUT ErrorString, comm_.errUNKNOWN_, s );
          GOTO Error;
        END;
      END;

      IF NOT Scanner.GetKeyStr( comm_.keyRTSCONTROL, s ) THEN
        fRtsControl   := windows.RTS_CONTROL_DISABLE; (*// DISABLE/ENABLE/HANDSHAKE/TOGGLE *)
      ELSE
        ASSIGN( ss, s );
        LOW( ss );
        IF EQUALS( ss, comm_.keyDISABLE ) OR EQUALS( ss, comm_.keyLOW ) THEN
          fRtsControl := windows.RTS_CONTROL_DISABLE;
        ELSIF EQUALS( ss, comm_.keyENABLE ) OR EQUALS( ss, comm_.keyHIGH ) THEN
          fRtsControl := windows.RTS_CONTROL_ENABLE;
        ELSIF EQUALS( ss, comm_.keyHANDSHAKE ) THEN
          fRtsControl := windows.RTS_CONTROL_HANDSHAKE;
        ELSIF EQUALS( ss, comm_.keyTOGGLE ) = 0 THEN
//          fRtsControl := windows.RTS_CONTROL_TOGGLE; ---> DO NOT USE WINDOWS SW TOGGLE
          fRtsControl := windows.RTS_CONTROL_DISABLE;
          INCL( CommState, comsToggleRTS );
        ELSIF EQUALS( ss, comm_.keyTOGGLE_NEG ) THEN
          fRtsControl := windows.RTS_CONTROL_DISABLE;
          INCL( CommState, comsNegToggleRTS );
        ELSE
          Strings.ConcatW( OUT ErrorString, comm_.errUNKNOWN_, s );
          GOTO Error;
        END;
      END;

      IF NOT Scanner.GetKeyStr( comm_.keyDSRSENSE, s ) THEN
        fDsrSensitivity   := windows.False;
      ELSE
        ASSIGN( ss, s );
        LOW( ss );
        IF EQUALS( ss, comm_.keyLOW ) THEN
          fDsrSensitivity := windows.False;
        ELSIF EQUALS( ss, comm_.keyHIGH ) THEN
          fDsrSensitivity := windows.True;
        ELSE
          Strings.ConcatW( ErrorString, comm_.errUNKNOWN_, s );
          GOTO Error;
        END;
      END;

      b := Scanner.GetKeyBool( comm_.keyTX_CONT_ON_XOFF, ok ) AND ok OR
           Scanner.GetKeyBool( comm_.keyTX_CONT_ON_XOFF2, ok ) AND ok;
      fTXContinueOnXoff := windows.DWORD( b );
      b := Scanner.GetKeyBool( comm_.keyTX_XON_XOFF, ok ) AND ok;
      fOutX := windows.DWORD( b );
      b := Scanner.GetKeyBool( comm_.keyRX_XON_XOFF, ok ) AND ok;
      fInX  := windows.DWORD( b );

      ok := Scanner.GetKeyInt( comm_.keyXON_TRESH, i );
      IF ok THEN
        XonLim  := WORD(i);
      ELSE
        XonLim  := WORD(RxWinBufSize DIV 2);  // 50%
      END;
      ok := Scanner.GetKeyInt( comm_.keyXOFF_TRESH, i );
      IF ok THEN
        XoffLim  := WORD(i);
      ELSE
        XoffLim  := WORD(RxWinBufSize * 8 DIV 10);  // 80%
      END;

      b := Scanner.GetKeyBool( comm_.keyERR_XLAT, ok ) AND ok;
      fErrorChar := windows.DWORD( b );
      b := Scanner.GetKeyBool( comm_.keyDISCARD_NULL, ok ) AND ok;
      fNull := windows.DWORD( b );
      
      fAbortOnError := windows.False;
//      fAbortOnError := windows.True;

      fDummy2       := 0;
      wReserved     := 0;

      ok := Scanner.GetKeyInt( comm_.keyDATABITS, i );
      IF ok THEN
        ByteSize := BYTE(i);
      ELSE
        Str.Concat( ErrorString, comm_.errMISSING_, comm_.keyDATABITS );
        GOTO Error;
      END;

      IF NOT Scanner.GetKeyStr( comm_.keySTOPBITS, s ) THEN
        Str.Concat( ErrorString, comm_.errMISSING_, comm_.keySTOPBITS );
        GOTO Error;
      ELSE
        ASSIGN( ss, s );
        LOW( ss );
        IF EQUALS( ss, comm_.keyONE ) OR EQUALS( ss, '1'+0C )  THEN
          StopBits := windows.ONESTOPBIT;
        ELSIF EQUALS( ss, comm_.keyONEANDHALF ) OR EQUALS( ss, '1.5'+0C ) THEN
          StopBits := windows.ONE5STOPBITS;
        ELSIF EQUALS( ss, comm_.keyTWO ) OR EQUALS( ss, '2'+0C ) THEN
          StopBits := windows.TWOSTOPBITS;
        ELSE
          Strings.ConcatW( OUT ErrorString, comm_.errUNKNOWN_, s );
          GOTO Error;
        END;
      END;

      ok := Scanner.GetKeyInt( comm_.keyXONCHAR, OUT c );
      IF NOT ok THEN
        XonChar           := ASCII_XON;
      ELSE
        XonChar           := CHR(c);
      END;
      ok := Scanner.GetKeyInt( comm_.keyXOFFCHAR, OUT c );
      IF NOT ok THEN
        XoffChar           := ASCII_XOFF;
      ELSE
        XoffChar           := CHR(c);
      END;
      ok := Scanner.GetKeyInt( comm_.keyERRCHAR, OUT c );
      IF NOT ok THEN
        ErrorChar          := CHR(0);
      ELSE
        ErrorChar          := CHR(c);
      END;
      ok := Scanner.GetKeyInt( comm_.keyEOFCHAR, OUT c );
      IF NOT ok THEN
        EofChar            := CHR(26);
      ELSE
        EofChar            := CHR(c);
      END;
      ok := Scanner.GetKeyInt( comm_.keyEVTCHAR, OUT c );
      IF NOT ok THEN
        EvtChar            := CHR(26);
      ELSE
        EvtChar            := CHR(c);
      END;
      wReserved1        := 0;

    END; (* WITH *)

    IF CommDCB.BaudRate >= 9600 THEN
      CharDelay := 1;
    ELSE
      c := CARDINAL(CommDCB.ByteSize) + 1;
      IF CommDCB.StopBits = BYTE(windows.TWOSTOPBITS) THEN
        INC( c, 2 );
      ELSE
        INC( c );
      END;
      IF CommDCB.Parity <> BYTE(windows.NOPARITY) THEN
        INC( c );
      END;
      IF CommDCB.BaudRate <> 0 THEN
        CharDelay := 1000 * c DIV CARDINAL(CommDCB.BaudRate);
      ELSE
        CharDelay := 1;
      END;
    END;

  // Windows internal buffer
    wb := windows.SetupComm( HComm, RxWinBufSize, TxWinBufSize );
    IF wb = windows.False THEN
      ConstructErrorMessage( windows.GetLastError(), ss );
      ASSIGN( ErrorString, comm_.errUNABLE_SETUP_DEVICE_BUFFERS );
      Str.Append( ErrorString, ss );
      GOTO Error;
    END;

    WITH Timeouts DO
      ok := Scanner.GetKeyInt( comm_.keyRX_INT_TIMEOUT, OUT c );
      IF ok THEN
        ReadIntervalTimeout := c;
      END;
      //IF NOT ok THEN
      //  Str.Concat( ErrorString, comm_.errMISSING_, comm_.keyRX_INT_TIMEOUT );
      //  GOTO Error;
      //END;
      ok := Scanner.GetKeyInt( comm_.keyRX_TIMEOUT_MULT, OUT c );
      IF ok THEN
        ReadTotalTimeoutMultiplier := c;
      END;
      //IF NOT ok THEN
      //  Str.Concat( ErrorString, comm_.errMISSING_, comm_.keyRX_TIMEOUT_MULT );
      //  GOTO Error;
      //END;
      //IF ReadTotalTimeoutMultiplier = 0 THEN
      //  IF CommDCB.BaudRate > 9600 THEN
      //    ReadTotalTimeoutMultiplier := 1;
      //  ELSIF CommDCB.BaudRate <> 0 THEN
      //    ReadTotalTimeoutMultiplier := 9600 DIV CommDCB.BaudRate;
      //  ELSE
      //    ReadTotalTimeoutMultiplier := 1;
      //  END;
      //END;
      ok := Scanner.GetKeyInt( comm_.keyRX_TIMEOUT, OUT c );
      IF ok THEN
        ReadTotalTimeoutConstant := c;
      END;
      //IF NOT ok THEN
      //  Str.Concat( ErrorString, comm_.errMISSING_, comm_.keyRX_TIMEOUT );
      //  GOTO Error;
      //END;
      //IF ReadTotalTimeoutConstant = 0 THEN
      //  ReadTotalTimeoutConstant := 20;
      //END;
      ok := Scanner.GetKeyInt( comm_.keyTX_TIMEOUT_MULT, OUT c );
      IF ok THEN
        WriteTotalTimeoutMultiplier := c;
      END;
      //IF NOT ok THEN
      //  Str.Concat( ErrorString, comm_.errMISSING_, comm_.keyTX_TIMEOUT_MULT );
      //  GOTO Error;
      //END;
      IF WriteTotalTimeoutMultiplier = 0 THEN
        IF CommDCB.BaudRate > 9600 THEN
          WriteTotalTimeoutMultiplier := 1;
        ELSIF CommDCB.BaudRate <> 0 THEN
          WriteTotalTimeoutMultiplier := 9600 DIV CommDCB.BaudRate;
        ELSE
          WriteTotalTimeoutMultiplier := 1;
        END;
      END;
      ok := Scanner.GetKeyInt( comm_.keyTX_TIMEOUT, OUT c );
      IF ok THEN
        WriteTotalTimeoutConstant := c;
      END;
      //IF NOT ok THEN
      //  Str.Concat( ErrorString, comm_.errMISSING_, comm_.keyTX_TIMEOUT );
      //  GOTO Error;
      //END;
      //IF WriteTotalTimeoutConstant = 0 THEN
      //  WriteTotalTimeoutConstant := 100;
      //END;
    END;

    windows.PurgeComm( HComm, windows.PURGE_TXABORT OR windows.PURGE_RXABORT OR
                              windows.PURGE_TXCLEAR OR windows.PURGE_RXCLEAR );

    wb := windows.SetCommTimeouts( HComm, ADR(Timeouts));
    IF wb = windows.False THEN
      ConstructErrorMessage( windows.GetLastError(), ss );
      ASSIGN( ErrorString, comm_.errUNABLE_SETUP_DEVICE_TIMEOUTS );
      Str.Append( ErrorString, ss );
      GOTO Error;
    END;

    wb := windows.SetCommState( HComm, ADR(CommDCB));
    IF wb = windows.False THEN
      ConstructErrorMessage( windows.GetLastError(), ss );
      Str.Concat( ErrorString, comm_.errUNABLE_INIT_DEVICE_, s );
      Str.Append( ErrorString, ss );
      GOTO Error;
    END;

    FOR c := hevFirst TO hevLast DO
      EventArray[c] := windows.CreateEvent( NIL, windows.True, windows.False, NIL );
      IF EventArray[c] = windows.INVALID_HANDLE_VALUE THEN
        ConstructErrorMessage( windows.GetLastError(), ss );
        ASSIGN( ErrorString, comm_.errSETUP_FAILED );
        Str.Append( ErrorString, ss );
        GOTO Error;
      END;
    END;
(*%F SYNC_COMM *)
    WITH RxOverlapped DO
      Internal      := 0;
      InternalHigh  := 0;
      Offset        := 0;
      OffsetHigh    := 0;
      hEvent        := EventArray[hevRead];
    END;
    WITH TxOverlapped DO
      Internal      := 0;
      InternalHigh  := 0;
      Offset        := 0;
      OffsetHigh    := 0;
      hEvent        := EventArray[hevWrite];
    END;
    WITH WaitOverlapped DO
      Internal      := 0;
      InternalHigh  := 0;
      Offset        := 0;
      OffsetHigh    := 0;
      hEvent        := EventArray[hevCommEvent];
    END;
(*%E SYNC_COMM *)

    IF HCommThread = NIL THEN
      HCommThread := windows.CreateThread( 
        NIL, // pointer to thread security attributes
        0,   // initial thread stack size, in bytes
        windows.PTHREAD_START_ROUTINE( CommThreadAction ), // pointer to thread function 
        ADR(SELF),    // argument for new thread
        0,            // creation flags 
        ADR(CommThreadId) // pointer to returned thread identifier 
      );
    END;
    IF HCommThread = NIL THEN
      ConstructErrorMessage( windows.GetLastError(), ss );
      ASSIGN( ErrorString, comm_.errSETUP_FAILED );
      Str.Append( ErrorString, ss );
      GOTO Error;
    END;

  (*%T SYNC_COMM *)
    IF HWaitThread = NIL THEN
      HWaitThread := windows.CreateThread( 
        NIL, // pointer to thread security attributes
        0,   // initial thread stack size, in bytes
        windows.PTHREAD_START_ROUTINE( CECommThread_Wait ), // pointer to thread function 
        ADR(SELF),    // argument for new thread
        0,            // creation flags 
        ADR(WaitThreadId) // pointer to returned thread identifier 
      );
    END;
    IF HWaitThread = NIL THEN
      ConstructErrorMessage( windows.GetLastError(), ss );
      ASSIGN( ErrorString, comm_.errSETUP_FAILED );
      Str.Append( ErrorString, ss );
      GOTO Error;
    END;

    IF HWriteThread = NIL THEN
      HWriteThread := windows.CreateThread( 
        NIL, // pointer to thread security attributes
        0,   // initial thread stack size, in bytes
        windows.PTHREAD_START_ROUTINE( CECommThread_Write ), // pointer to thread function 
        ADR(SELF),    // argument for new thread
        0,            // creation flags 
        ADR(WriteThreadId) // pointer to returned thread identifier 
      );
    END;
    IF HWriteThread = NIL THEN
      ConstructErrorMessage( windows.GetLastError(), ss );
      ASSIGN( ErrorString, comm_.errSETUP_FAILED );
      Str.Append( ErrorString, ss );
      GOTO Error;
    END;
  (*%E SYNC_COMM *)

    SetBasePriority( BasePriority );

    INCL( CommState, comsReady );
    SetCommFocusMask( FocusMask );

    Scanner.Done();
    INCL( CommState, comsInitialized );
    RETURN TRUE;

  Error:
    IF hSession <> seriallink.InvalidSessionHandle THEN
      DoneSession( hSession );
    END;
    hSession := seriallink.TSessionHandle( NIL );

    Scanner.Done();
    Done();
(*%E UNICODE *)
(*%T UNICODE *)
  VAR
    DeviceW       : ARRAY [0..63] OF WCHAR;
    IniFilePathW  : FIO.PathStrW;
    ErrorStringW  : ARRAY [0..1023] OF WCHAR;
    b             : BOOLEAN;
  BEGIN
    Strings.ToW( Device, 0, OUT DeviceW );
    Strings.ToW( IniFilePath, 0, OUT IniFilePathW );
    b := InitW( DeviceW, IniFilePathW, fMultithreadLock, fPrivate, ErrorStringW, hSession );
    Strings.ToA( ErrorStringW, 0, OUT ErrorString );
    RETURN b;
(*%E UNICODE *)
    RETURN FALSE;
  END Init;
#endif

  PUBLIC VIRTUAL PROCEDURE InitW( Device      : ARRAY OF WCHAR;
                                  IniFilePath : ARRAY OF WCHAR;
                                  fMultithreadLock, fPrivate : BOOLEAN;
                                  VAR ErrorString : ARRAY OF WCHAR;
                                  VAR hSession : seriallink.TSessionHandle ) : BOOLEAN;
(*%T UNICODE *)
    PROCEDURE ConstructErrorMessage( err : CARDINAL; VAR ErrMsg : ARRAY OF WCHAR );
    BEGIN
      Strings.FromErrorW( err, OUT ErrMsg );
      IF ErrMsg[0] <> 0W THEN
        Strings.PrependW( REF ErrMsg, L' (Win32: ' );
        Strings.AppendW( REF ErrMsg, L')' );
      END;
    END ConstructErrorMessage;

  VAR
    wb : windows.BOOL;
    b : BOOLEAN;
    c : CARDINAL;

    fn : FIO.PathStrW;
    s : ARRAY [0..79] OF WCHAR;
    so : ARRAY [0..79] OF WCHAR;
    ss : ARRAY [0..255] OF WCHAR;
    cs : StringsO.CString;

    Scanner : INIFile.CINIFile;

    i, line : INTEGER;
    ok : BOOLEAN;

  LABEL
    Error;

  BEGIN
    IF NOT Scanner.LoadPath( IniFilePath ) THEN
      ASSIGN( ErrorString, comm_.errCANNOT_INITIALIZE );
      GOTO Error;
    END;

    hSession := GetNewSessionHandle();
    IF hSession = seriallink.InvalidSessionHandle THEN
      ASSIGN( ErrorString, comm_.errCANNOT_INITIALIZE );
      GOTO Error;
    END;

    IF comsInitialized IN CommState THEN
      IF fPrivate OR (comsPrivate IN CommState) THEN
        ASSIGN( ErrorString, comm_.errPRIVATE_CONFLICT );
        GOTO Error;
      END;
      INC( InitCount );
      IF fMultithreadLock THEN
        INCL( CommState, comsThreadLock );
      END;
      RETURN TRUE;
    END;
    IF fMultithreadLock THEN
      INCL( CommState, comsThreadLock );
    END;
    IF fPrivate THEN
      INCL( CommState, comsPrivate );
    END;
    INC( InitCount );

    IF NOT Scanner.SetSection( comm_.secCOMMPAR ) THEN
      ASSIGN( ErrorString, comm_.errCANNOT_INITIALIZE );
      GOTO Error;
    END;
    IF Scanner.GetKeyStr( comm_.keyFILE, OUT line, OUT cs ) THEN
      cs.ToOA( OUT fn );
      IF Scanner.LoadPath( fn ) THEN
        IF NOT Scanner.SetSection( comm_.secCOMMPAR ) THEN
          ASSIGN( ErrorString, comm_.errCANNOT_INITIALIZE );
          GOTO Error;
        END;
      ELSE
        Strings.ConcatW( OUT ErrorString, comm_.errCANNOT_OPEN_, fn );
        GOTO Error;
      END;
    END;

    IF Device[0] = 0W THEN
      IF NOT Scanner.GetKeyStr( comm_.keyDEVICE, OUT line, OUT cs ) THEN
        cs.ToOA( OUT s );
        ASSIGN( ErrorString, comm_.errMISSING_DEVICE );
        GOTO Error;
      END;
    ELSE
      ASSIGN( s, Device );
    END;

    IF NOT Scanner.SetSection( s ) THEN
      Scanner.SetSection( comm_.secCOMMPAR )
    END;

    ASSIGN( so, s );

    HComm  := windows.CreateFile( ADR( s ),
                                  windows.GENERIC_READ OR windows.GENERIC_WRITE,
                                  0,
                                  NIL,
                                  windows.OPEN_EXISTING,
                                (*%F SYNC_COMM *)
                                  windows.FILE_FLAG_OVERLAPPED OR windows.FILE_ATTRIBUTE_NORMAL,
                                (*%E SYNC_COMM *)
                                (*%T SYNC_COMM *)
                                  windows.FILE_ATTRIBUTE_NORMAL,
                                (*%E SYNC_COMM *)
                                  NIL );

#if PlatformName #startswith L"WinCE" #then
    IF HComm = windows.INVALID_HANDLE_VALUE THEN
      ConstructErrorMessage( windows.GetLastError(), ss );
      LOW( s );
      Str.Append( s, ':'+0C );
      HComm  := windows.CreateFile( s,
                                    windows.GENERIC_READ OR windows.GENERIC_WRITE,
                                    0,
                                    NIL,
                                    windows.OPEN_EXISTING,
                                  (*%F SYNC_COMM *)
                                    windows.FILE_FLAG_OVERLAPPED OR windows.FILE_ATTRIBUTE_NORMAL,
                                  (*%E SYNC_COMM *)
                                  (*%T SYNC_COMM *)
                                    windows.FILE_ATTRIBUTE_NORMAL,
                                  (*%E SYNC_COMM *)
                                    NIL );
    END;
#else
    IF HComm = windows.INVALID_HANDLE_VALUE THEN
      ConstructErrorMessage( windows.GetLastError(), ss );
      LOW( s );
      Strings.PrependW( REF s, L'\\.\' );
      HComm  := windows.CreateFile( ADR( s ),
                                    windows.GENERIC_READ OR windows.GENERIC_WRITE,
                                    0,
                                    NIL,
                                    windows.OPEN_EXISTING,
                                  (*%F SYNC_COMM *)
                                    windows.FILE_FLAG_OVERLAPPED OR windows.FILE_ATTRIBUTE_NORMAL,
                                  (*%E SYNC_COMM *)
                                  (*%T SYNC_COMM *)
                                    windows.FILE_ATTRIBUTE_NORMAL,
                                  (*%E SYNC_COMM *)
                                    NIL );
    END;
#endif

    IF HComm = windows.INVALID_HANDLE_VALUE THEN
      Strings.ConcatW( OUT ErrorString, comm_.errCANNOT_OPEN_DEVICE_, so );
      Strings.AppendW( REF ErrorString, ss );
      GOTO Error;
    END;
    ASSIGN( OpenedDev, s );

    IF NOT Scanner.GetKeyStr( comm_.keyMODE, OUT line, OUT cs ) THEN
      EXCL( CommState, comsHalfDuplex );
    ELSE
      cs.ToOA( OUT ss );
      LOW( ss );
      IF EQUALS( ss, comm_.keyFULLDUPLEX ) THEN
        EXCL( CommState, comsHalfDuplex );
      ELSIF EQUALS( ss, comm_.keyHALFDUPLEX ) THEN
        INCL( CommState, comsHalfDuplex );
      ELSE
        Strings.ConcatW( OUT ErrorString, comm_.errUNKNOWN_, s );
        GOTO Error;
      END;
    END;

    PreKey := 0;
    ok := Scanner.GetKeyInt( comm_.keyPREKEY, OUT line, OUT PreKey );
    ok := Scanner.GetKeyInt( comm_.keyHOLDKEY, OUT line, OUT HoldKey );

    IF NOT Scanner.GetKeyStr( comm_.keyPRIORITY, OUT line, OUT cs ) THEN
      BasePriority := windows.THREAD_PRIORITY_NORMAL;
    ELSE
      cs.ToOA( OUT ss );
      LOW( ss );
      IF EQUALS( ss, comm_.keyIDLE ) THEN
        BasePriority := windows.THREAD_PRIORITY_IDLE;
      ELSIF EQUALS( ss, comm_.keyLOW ) THEN
        BasePriority := windows.THREAD_PRIORITY_LOWEST;
      ELSIF EQUALS( ss, comm_.keyBELOW_NORMAL ) THEN
        BasePriority := windows.THREAD_PRIORITY_BELOW_NORMAL;
      ELSIF EQUALS( ss, comm_.keyNORMAL ) THEN
        BasePriority := windows.THREAD_PRIORITY_NORMAL;
      ELSIF EQUALS( ss, comm_.keyABOVE_NORMAL ) THEN
        BasePriority := windows.THREAD_PRIORITY_ABOVE_NORMAL;
      ELSIF EQUALS( ss, comm_.keyHIGH ) THEN
        BasePriority := windows.THREAD_PRIORITY_HIGHEST;
      ELSIF EQUALS( ss, comm_.keyREALTIME ) THEN
        BasePriority := windows.THREAD_PRIORITY_TIME_CRITICAL;
      ELSE
        Strings.ConcatW( OUT ErrorString, comm_.errUNKNOWN_, s );
        GOTO Error;
      END;
    END;

    AutoReadPending := Scanner.GetKeyBool( comm_.keyAUTO_READ, OUT line, OUT ok ) AND ok;

  // windows internal buffers
    RxWinBufSize := 4096;
    ok := Scanner.GetKeyInt( comm_.keyRX_BUFFER, OUT line, OUT RxWinBufSize );
    TxWinBufSize := 4096;
    ok := Scanner.GetKeyInt( comm_.keyTX_BUFFER, OUT line, OUT TxWinBufSize );

  // Rx frame buffer
    c  := RxWinBufSize;
    ok := Scanner.GetKeyInt( comm_.keyRX_FRAME_BUFFER, OUT line, OUT c );
    IF ok AND (c < 96) OR (c > 2*65536) THEN
      Strings.ConcatW( OUT ErrorString, comm_.errSETUP_FAILED_, comm_.keyRX_FRAME_BUFFER );
      GOTO Error;
    END;
    c := MAX2( c, RxWinBufSize );
    RxQueue.Init( c );

  // Tx frame buffer
    c  := RxWinBufSize;
    ok := Scanner.GetKeyInt( comm_.keyTX_FRAME_BUFFER, OUT line, OUT c );
    IF ok AND (c < 96) OR (c > 2*65536) THEN
      Strings.ConcatW( OUT ErrorString, comm_.errSETUP_FAILED_, comm_.keyTX_FRAME_BUFFER );
      GOTO Error;
    END;
    c := MAX2( c, TxWinBufSize );
    TxQueue.Init( c );

  // protocol
    WITH CommDCB DO
      DCBlength         := SIZE(CommDCB);
      ok := Scanner.GetKeyInt( comm_.keyBAUDRATE, OUT line, OUT c );
      BaudRate := windows.DWORD( c );
      IF NOT ok THEN
        Strings.ConcatW( OUT ErrorString, comm_.errMISSING_, comm_.keyBAUDRATE );
        GOTO Error;
      END;
      fBinary	        := windows.True;
      IF NOT Scanner.GetKeyStr( comm_.keyPARITY, OUT line, OUT cs ) THEN
        fParity    := windows.True;
        Parity     := windows.NOPARITY; (* EVEN/MARK/NO/ODD/SPACE *)
      ELSE
        cs.ToOA( OUT ss );
        LOW( ss );
        IF EQUALS( ss, comm_.keyNONE ) OR EQUALS( ss, comm_.keyNO ) THEN
          fParity  := windows.True;
          Parity   := windows.NOPARITY;
        ELSIF EQUALS( ss, comm_.keyEVEN ) THEN
          fParity  := windows.True;
          Parity   := windows.EVENPARITY;
        ELSIF EQUALS( ss, comm_.keyMARK ) THEN
          fParity  := windows.True;
          Parity   := windows.MARKPARITY;
        ELSIF EQUALS( ss, comm_.keyODD ) THEN
          fParity  := windows.True;
          Parity   := windows.ODDPARITY;
        ELSIF EQUALS( ss, comm_.keySPACE ) THEN
          fParity  := windows.True;
          Parity   := windows.SPACEPARITY;
        ELSE
          Strings.ConcatW( OUT ErrorString, comm_.errUNKNOWN_, s );
          GOTO Error;
        END;
      END;

      b := Scanner.GetKeyBool( comm_.keyCTSFLOW, OUT line, OUT ok ) AND ok;
      fOutxCtsFlow := windows.DWORD( b );
      b := Scanner.GetKeyBool( comm_.keyDSRFLOW, OUT line, OUT ok ) AND ok;
      fOutxDsrFlow := windows.DWORD( b );

      IF NOT Scanner.GetKeyStr( comm_.keyDTRCONTROL, OUT line, OUT cs ) THEN
        fDtrControl   := windows.DTR_CONTROL_DISABLE; (*// DISABLE/ENABLE/HANDSHAKE *)
      ELSE
        cs.ToOA( OUT ss );
        LOW( ss );
        IF EQUALS( ss, comm_.keyDISABLE ) OR EQUALS( ss, comm_.keyLOW ) THEN
          fDtrControl := windows.DTR_CONTROL_DISABLE;
        ELSIF EQUALS( ss, comm_.keyENABLE ) OR EQUALS( ss, comm_.keyHIGH ) THEN
          fDtrControl := windows.DTR_CONTROL_ENABLE;
        ELSIF EQUALS( ss, comm_.keyHANDSHAKE ) THEN
          fDtrControl := windows.DTR_CONTROL_HANDSHAKE;
        ELSIF EQUALS( ss, comm_.keyTOGGLE ) THEN
          fDtrControl := windows.DTR_CONTROL_DISABLE;
          INCL( CommState, comsToggleDTR );
        ELSIF EQUALS( ss, comm_.keyTOGGLE_NEG ) THEN
          fDtrControl := windows.DTR_CONTROL_DISABLE;
          INCL( CommState, comsNegToggleDTR );
        ELSE
          Strings.ConcatW( OUT ErrorString, comm_.errUNKNOWN_, s );
          GOTO Error;
        END;
      END;

      IF NOT Scanner.GetKeyStr( comm_.keyRTSCONTROL, OUT line, OUT cs ) THEN
        fRtsControl   := windows.RTS_CONTROL_DISABLE; (*// DISABLE/ENABLE/HANDSHAKE/TOGGLE *)
      ELSE
        cs.ToOA( OUT ss );
        LOW( ss );
        IF EQUALS( ss, comm_.keyDISABLE ) OR EQUALS( ss, comm_.keyLOW ) THEN
          fRtsControl := windows.RTS_CONTROL_DISABLE;
        ELSIF EQUALS( ss, comm_.keyENABLE ) OR EQUALS( ss, comm_.keyHIGH ) THEN
          fRtsControl := windows.RTS_CONTROL_ENABLE;
        ELSIF EQUALS( ss, comm_.keyHANDSHAKE ) THEN
          fRtsControl := windows.RTS_CONTROL_HANDSHAKE;
        ELSIF EQUALS( ss, comm_.keyTOGGLE ) THEN
//          fRtsControl := windows.RTS_CONTROL_TOGGLE; ---> DO NOT USE WINDOWS SW TOGGLE
          fRtsControl := windows.RTS_CONTROL_DISABLE;
          INCL( CommState, comsToggleRTS );
        ELSIF EQUALS( ss, comm_.keyTOGGLE_NEG ) THEN
          fRtsControl := windows.RTS_CONTROL_DISABLE;
          INCL( CommState, comsNegToggleRTS );
        ELSE
          Strings.ConcatW( OUT ErrorString, comm_.errUNKNOWN_, s );
          GOTO Error;
        END;
      END;

      IF NOT Scanner.GetKeyStr( comm_.keyDSRSENSE, OUT line, OUT cs ) THEN
        fDsrSensitivity   := windows.False;
      ELSE
        cs.ToOA( OUT ss );
        LOW( ss );
        IF EQUALS( ss, comm_.keyLOW ) THEN
          fDsrSensitivity := windows.False;
        ELSIF EQUALS( ss, comm_.keyHIGH ) THEN
          fDsrSensitivity := windows.True;
        ELSE
          Strings.ConcatW( OUT ErrorString, comm_.errUNKNOWN_, s );
          GOTO Error;
        END;
      END;

      b := Scanner.GetKeyBool( comm_.keyTX_CONT_ON_XOFF, OUT line, OUT ok ) AND ok OR
           Scanner.GetKeyBool( comm_.keyTX_CONT_ON_XOFF2, OUT line, OUT ok ) AND ok;
      fTXContinueOnXoff := windows.DWORD( b );
      b := Scanner.GetKeyBool( comm_.keyTX_XON_XOFF, OUT line, OUT ok ) AND ok;
      fOutX := windows.DWORD( b );
      b := Scanner.GetKeyBool( comm_.keyRX_XON_XOFF, OUT line, OUT ok ) AND ok;
      fInX  := windows.DWORD( b );

      ok := Scanner.GetKeyInt( comm_.keyXON_TRESH, OUT line, OUT i );
      IF ok THEN
        XonLim  := WORD(i);
      ELSE
        XonLim  := WORD(RxWinBufSize DIV 2);  // 50%
      END;
      ok := Scanner.GetKeyInt( comm_.keyXOFF_TRESH, OUT line, OUT i );
      IF ok THEN
        XoffLim  := WORD(i);
      ELSE
        XoffLim  := WORD(RxWinBufSize * 8 DIV 10);  // 80%
      END;

      b := Scanner.GetKeyBool( comm_.keyERR_XLAT, OUT line, OUT ok ) AND ok;
      fErrorChar := windows.DWORD( b );
      b := Scanner.GetKeyBool( comm_.keyDISCARD_NULL, OUT line, OUT ok ) AND ok;
      fNull := windows.DWORD( b );
      
      fAbortOnError := windows.False;
//      fAbortOnError := windows.True;

      fDummy2       := 0;
      wReserved     := 0;

      ok := Scanner.GetKeyInt( comm_.keyDATABITS, OUT line, OUT i );
      IF ok THEN
        ByteSize := BYTE(i);
      ELSE
        Strings.ConcatW( OUT ErrorString, comm_.errMISSING_, comm_.keyDATABITS );
        GOTO Error;
      END;

      IF NOT Scanner.GetKeyStr( comm_.keySTOPBITS, OUT line, OUT cs ) THEN
        Strings.ConcatW( OUT ErrorString, comm_.errMISSING_, comm_.keySTOPBITS );
        GOTO Error;
      ELSE
        cs.ToOA( OUT ss );
        LOW( ss );
        IF EQUALS( ss, comm_.keyONE ) OR EQUALS( ss, L'1'+0W ) THEN
          StopBits := windows.ONESTOPBIT;
        ELSIF EQUALS( ss, comm_.keyONEANDHALF ) OR EQUALS( ss, L'1.5'+0W ) THEN
          StopBits := windows.ONE5STOPBITS;
        ELSIF EQUALS( ss, comm_.keyTWO ) OR EQUALS( ss, L'2'+0W ) THEN
          StopBits := windows.TWOSTOPBITS;
        ELSE
          Strings.ConcatW( OUT ErrorString, comm_.errUNKNOWN_, s );
          GOTO Error;
        END;
      END;

      ok := Scanner.GetKeyInt( comm_.keyXONCHAR, OUT line, OUT c );
      IF NOT ok THEN
        XonChar           := ASCII_XON;
      ELSE
        XonChar           := CHAR(c);
      END;
      ok := Scanner.GetKeyInt( comm_.keyXOFFCHAR, OUT line, OUT c );
      IF NOT ok THEN
        XoffChar           := ASCII_XOFF;
      ELSE
        XoffChar           := CHAR(c);
      END;
      ok := Scanner.GetKeyInt( comm_.keyERRCHAR, OUT line, OUT c );
      IF NOT ok THEN
        ErrorChar          := CHAR(0);
      ELSE
        ErrorChar          := CHAR(c);
      END;
      ok := Scanner.GetKeyInt( comm_.keyEOFCHAR, OUT line, OUT c );
      IF NOT ok THEN
        EofChar            := CHAR(26);
      ELSE
        EofChar            := CHAR(c);
      END;
      ok := Scanner.GetKeyInt( comm_.keyEVTCHAR, OUT line, OUT c );
      IF NOT ok THEN
        EvtChar            := CHAR(26);
      ELSE
        EvtChar            := CHAR(c);
      END;
      wReserved1        := 0;
    END; (* WITH *)

    IF CommDCB.BaudRate >= 9600 THEN
      CharDelay := 1;
    ELSE
      c := CARDINAL(CommDCB.ByteSize) + 1;
      IF CommDCB.StopBits = BYTE(windows.TWOSTOPBITS) THEN
        INC( c, 2 );
      ELSE
        INC( c );
      END;
      IF CommDCB.Parity <> BYTE(windows.NOPARITY) THEN
        INC( c );
      END;
      IF CommDCB.BaudRate <> 0 THEN
        CharDelay := 1000 * c DIV CARDINAL(CommDCB.BaudRate);
      ELSE
        CharDelay := 1;
      END;
    END;

  // Windows internal buffer
    wb := windows.SetupComm( HComm, RxWinBufSize, TxWinBufSize );
    IF wb = windows.False THEN
      ConstructErrorMessage( windows.GetLastError(), ss );
      ASSIGN( ErrorString, comm_.errUNABLE_SETUP_DEVICE_BUFFERS );
      Strings.AppendW( REF ErrorString, ss );
      GOTO Error;
    END;

    WITH Timeouts DO
      ok := Scanner.GetKeyInt( comm_.keyRX_INT_TIMEOUT, OUT line, OUT c );
      IF ok THEN
        ReadIntervalTimeout := c;
      END;
      //IF NOT ok THEN
      //  Str.Concat( ErrorString, comm_.errMISSING_, comm_.keyRX_INT_TIMEOUT );
      //  GOTO Error;
      //END;
      ok := Scanner.GetKeyInt( comm_.keyRX_TIMEOUT_MULT, OUT line, OUT c );
      IF ok THEN
        ReadTotalTimeoutMultiplier := c;
      END;
      //IF NOT ok THEN
      //  Str.Concat( ErrorString, comm_.errMISSING_, comm_.keyRX_TIMEOUT_MULT );
      //  GOTO Error;
      //END;
      //IF ReadTotalTimeoutMultiplier = 0 THEN
      //  IF CommDCB.BaudRate > 9600 THEN
      //    ReadTotalTimeoutMultiplier := 1;
      //  ELSIF CommDCB.BaudRate <> 0 THEN
      //    ReadTotalTimeoutMultiplier := 9600 DIV CommDCB.BaudRate;
      //  ELSE
      //    ReadTotalTimeoutMultiplier := 1;
      //  END;
      //END;
      ok := Scanner.GetKeyInt( comm_.keyRX_TIMEOUT, OUT line, OUT c );
      IF ok THEN
        ReadTotalTimeoutConstant := c;
      END;
      //IF NOT ok THEN
      //  Str.Concat( ErrorString, comm_.errMISSING_, comm_.keyRX_TIMEOUT );
      //  GOTO Error;
      //END;
      //IF ReadTotalTimeoutConstant = 0 THEN
      //  ReadTotalTimeoutConstant := 20;
      //END;
      ok := Scanner.GetKeyInt( comm_.keyTX_TIMEOUT_MULT, OUT line, OUT c );
      IF ok THEN
        WriteTotalTimeoutMultiplier := c;
      END;
      //IF NOT ok THEN
      //  Str.Concat( ErrorString, comm_.errMISSING_, comm_.keyTX_TIMEOUT_MULT );
      //  GOTO Error;
      //END;
      IF WriteTotalTimeoutMultiplier = 0 THEN
        IF CommDCB.BaudRate > 9600 THEN
          WriteTotalTimeoutMultiplier := 1;
        ELSIF CommDCB.BaudRate <> 0 THEN
          WriteTotalTimeoutMultiplier := 9600 DIV CommDCB.BaudRate;
        ELSE
          WriteTotalTimeoutMultiplier := 1;
        END;
      END;
      ok := Scanner.GetKeyInt( comm_.keyTX_TIMEOUT, OUT line, OUT c );
      IF ok THEN
        WriteTotalTimeoutConstant := c;
      END;
      //IF NOT ok THEN
      //  Str.Concat( ErrorString, comm_.errMISSING_, comm_.keyTX_TIMEOUT );
      //  GOTO Error;
      //END;
      //IF WriteTotalTimeoutConstant = 0 THEN
      //  WriteTotalTimeoutConstant := 100;
      //END;
    END;

    windows.PurgeComm( HComm, windows.PURGE_TXABORT OR windows.PURGE_RXABORT OR
                              windows.PURGE_TXCLEAR OR windows.PURGE_RXCLEAR );

    wb := windows.SetCommTimeouts( HComm, ADR(Timeouts));
    IF wb = windows.False THEN
      ConstructErrorMessage( windows.GetLastError(), ss );
      ASSIGN( ErrorString, comm_.errUNABLE_SETUP_DEVICE_TIMEOUTS );
      Strings.AppendW( REF ErrorString, ss );
      GOTO Error;
    END;

    wb := windows.SetCommState( HComm, ADR(CommDCB));
    IF wb = windows.False THEN
      ConstructErrorMessage( windows.GetLastError(), ss );
      Strings.ConcatW( OUT ErrorString, comm_.errUNABLE_INIT_DEVICE_, s );
      Strings.AppendW( REF ErrorString, ss );
      GOTO Error;
    END;

    FOR c := hevFirst TO hevLast DO
      EventArray[c] := windows.CreateEvent( NIL, windows.True, windows.False, NIL );
      IF EventArray[c] = windows.INVALID_HANDLE_VALUE THEN
        ConstructErrorMessage( windows.GetLastError(), ss );
        ASSIGN( ErrorString, comm_.errSETUP_FAILED );
        Strings.AppendW( REF ErrorString, ss );
        GOTO Error;
      END;
    END;
(*%F SYNC_COMM *)
    WITH RxOverlapped DO
      Internal      := 0;
      InternalHigh  := 0;
      Offset        := 0;
      OffsetHigh    := 0;
      hEvent        := EventArray[hevRead];
    END;
    WITH TxOverlapped DO
      Internal      := 0;
      InternalHigh  := 0;
      Offset        := 0;
      OffsetHigh    := 0;
      hEvent        := EventArray[hevWrite];
    END;
    WITH WaitOverlapped DO
      Internal      := 0;
      InternalHigh  := 0;
      Offset        := 0;
      OffsetHigh    := 0;
      hEvent        := EventArray[hevCommEvent];
    END;
(*%E SYNC_COMM *)

    IF HCommThread = NIL THEN
      HCommThread := windows.CreateThread( 
        NIL, // pointer to thread security attributes
        0,   // initial thread stack size, in bytes
        windows.PTHREAD_START_ROUTINE( CommThreadAction ), // pointer to thread function 
        ADR(SELF),    // argument for new thread
        0,            // creation flags 
        ADR(CommThreadId) // pointer to returned thread identifier 
      );
    END;
    IF HCommThread = NIL THEN
      ConstructErrorMessage( windows.GetLastError(), ss );
      ASSIGN( ErrorString, comm_.errSETUP_FAILED );
      Strings.AppendW( REF ErrorString, ss );
      GOTO Error;
    END;

  (*%T SYNC_COMM *)
    IF HWaitThread = NIL THEN
      HWaitThread := windows.CreateThread( 
        NIL, // pointer to thread security attributes
        0,   // initial thread stack size, in bytes
        windows.PTHREAD_START_ROUTINE( CECommThread_Wait ), // pointer to thread function 
        ADR(SELF),    // argument for new thread
        0,            // creation flags 
        ADR(WaitThreadId) // pointer to returned thread identifier 
      );
    END;
    IF HWaitThread = NIL THEN
      ConstructErrorMessage( windows.GetLastError(), ss );
      ASSIGN( ErrorString, comm_.errSETUP_FAILED );
      Str.Append( ErrorString, ss );
      GOTO Error;
    END;

    IF HWriteThread = NIL THEN
      HWriteThread := windows.CreateThread( 
        NIL, // pointer to thread security attributes
        0,   // initial thread stack size, in bytes
        windows.PTHREAD_START_ROUTINE( CECommThread_Write ), // pointer to thread function 
        ADR(SELF),    // argument for new thread
        0,            // creation flags 
        ADR(WriteThreadId) // pointer to returned thread identifier 
      );
    END;
    IF HWriteThread = NIL THEN
      ConstructErrorMessage( windows.GetLastError(), ss );
      ASSIGN( ErrorString, comm_.errSETUP_FAILED );
      Str.Append( ErrorString, ss );
      GOTO Error;
    END;
  (*%E SYNC_COMM *)

    SetBasePriority( BasePriority );

    INCL( CommState, comsReady );
    SetCommFocusMask( FocusMask );

    Scanner.Clear();
    INCL( CommState, comsInitialized );
    RETURN TRUE;

  Error:
    IF hSession <> seriallink.InvalidSessionHandle THEN
      DoneSession( hSession );
    END;
    hSession := seriallink.TSessionHandle( NIL );

    Scanner.Clear();
    Done();
(*%E UNICODE *)

(*%F UNICODE *)
  VAR
    DeviceA       : ARRAY [0..63] OF CHAR;
    IniFilePathA  : FIO.PathStr;
    ErrorStringA  : ARRAY [0..1023] OF CHAR;
    b             : BOOLEAN;
  BEGIN
    Strings.ToA( Device, 0, OUT DeviceA );
    Strings.ToA( IniFilePath, 0, OUT IniFilePathA );
    b := Init( DeviceA, IniFilePathA, fMultithreadLock, fPrivate, ErrorStringA, hSession );
    Strings.ToW( ErrorStringA, 0, OUT ErrorString );
    RETURN b;
(*%E UNICODE *)

    RETURN FALSE;
  END InitW;

  PUBLIC VIRTUAL PROCEDURE Done();
  VAR
    c : CARDINAL;
  BEGIN
    IF InitCount < 1 THEN
      RETURN;
    ELSIF InitCount = 1 THEN
      CommState := {};

    (*%T SYNC_COMM *)
      windows.SetEvent( EventArray[hevCEThreadDone]);
      windows.SetCommMask( HComm, 0 );
      IF HWaitThread <> NIL THEN
        windows.WaitForSingleObject( HWaitThread, windows.INFINITE );
        windows.CloseHandle( HWaitThread );
        HWaitThread := NIL;
      END;
      IF HWriteThread <> NIL THEN
        windows.SetEvent( EventArray[hevCEWriteNext] );
        windows.WaitForSingleObject( HWriteThread, windows.INFINITE );
        windows.CloseHandle( HWriteThread );
        HWriteThread := NIL;
      END;
    (*%E SYNC_COMM *)

      IF HCommThread <> NIL THEN
        windows.SetEvent( EventArray[hevDoneRq]);
        windows.WaitForSingleObject( HCommThread, windows.INFINITE );
        windows.CloseHandle( HCommThread );
        HCommThread := NIL;
      END;

      IF HComm <> windows.INVALID_HANDLE_VALUE THEN
        windows.CloseHandle( HComm );
        HComm := windows.INVALID_HANDLE_VALUE;
      END;

      FOR c := hevFirst TO hevLast DO
        IF EventArray[c] <> NIL THEN
          windows.CloseHandle( EventArray[c]);
          EventArray[c] := NIL;
        END;
      END;


      RxQueue.Purge();
      RxQueue.Release();
      TxQueue.Purge();
      TxQueue.Release();

      IF PRxCache <> NIL THEN
        DISPOSE( PRxCache );
      END;
      IF PTxCache <> NIL THEN
        DISPOSE( PTxCache );
      END;

      PRxCache := NIL;  RxCacheSize := 0;
      PTxCache := NIL;  TxCacheSize := 0;
      DEC( InitCount );

      CCommLinkStream.Done();
      RETURN;
    END;
    DEC( InitCount );
  END Done;

  PUBLIC VIRTUAL PROCEDURE SetBasePriority( ThreadPriority : INTEGER );
  BEGIN
    BasePriority := ThreadPriority;
    IF HCommThread <> NIL THEN
      windows.SetThreadPriority( HCommThread, BasePriority );
    END;
  (*%T SYNC_COMM *)
    IF HWaitThread <> NIL THEN
      windows.SetThreadPriority( HWaitThread, BasePriority );
    END;
    IF HWriteThread <> NIL THEN
      windows.SetThreadPriority( HWriteThread, BasePriority );
    END;
  (*%E SYNC_COMM *)
  END SetBasePriority;

  PUBLIC VIRTUAL PROCEDURE GetCommFocusMask( VAR Mask : BITSET );
  BEGIN
    Mask := FocusMask;
  END GetCommFocusMask;

  PUBLIC VIRTUAL PROCEDURE SetCommFocus( Event : CARDINAL; fSet : BOOLEAN );
  VAR
    Mask : BITSET;
    mm : CARDINAL;
  BEGIN
    IF Event >= SIZE(BITSET)*8 THEN
      RETURN;
    END;
    IF comsThreadLock IN CommState THEN
      windows.EnterCriticalSection( ADR(MTCS));
    END;
    mm := 0;
    Mask := {};
    INCL( Mask, Event );
    CASE Event OF
    | seriallink.comfBreakEvent:
      mm := mm OR windows.EV_BREAK;
    | seriallink.comfCTS:
      mm := mm OR windows.EV_CTS;
    | seriallink.comfDSR:
      mm := mm OR windows.EV_DSR;
    | seriallink.comfErrorEvent:
      mm := mm OR windows.EV_ERR;
    | seriallink.comfRing:
      mm := mm OR windows.EV_RING;
    | seriallink.comfRLSD:
      mm := mm OR windows.EV_RLSD;
    | seriallink.comfRxChar:
      mm := mm OR windows.EV_RXCHAR;
    | seriallink.comfRxEvent:
      mm := mm OR windows.EV_RXFLAG;
    | seriallink.comfTxEmpty:
      mm := mm OR windows.EV_TXEMPTY;
    | seriallink.comfRx80Full:
      mm := mm OR windows.EV_RX80FULL;
    END;
    IF comsThreadLock IN CommState THEN
      windows.LeaveCriticalSection( ADR(MTCS));
    END;

  // CS >>>
    windows.EnterCriticalSection( ADR(CommCritical));
    IF fSet THEN
      FocusMask := FocusMask + Mask;
      CommEventMask := CommEventMask OR mm;
    ELSE
      FocusMask := FocusMask - Mask;
      CommEventMask := CommEventMask AND NOT mm;
    END;
    windows.LeaveCriticalSection( ADR(CommCritical));
  // CS <<<

    IF comsReady IN CommState THEN
      windows.SetEvent( EventArray[hevCommEventRq]);
    END;
  END SetCommFocus;

  PUBLIC VIRTUAL PROCEDURE SetCommFocusMask( Mask : BITSET );
  VAR
    mm : CARDINAL;
  BEGIN
    IF (FocusMask <> Mask) OR (FocusMask = {}) THEN
      IF comsThreadLock IN CommState THEN
        windows.EnterCriticalSection( ADR(MTCS));
      END;
      mm := 0;
      IF seriallink.comfBreakEvent IN Mask THEN
        mm := mm OR windows.EV_BREAK;
      END;
      IF {seriallink.comfCTS,seriallink.comfCTSHold} * Mask <> {} THEN
        mm := mm OR windows.EV_CTS;
      END;
      IF {seriallink.comfDSR,seriallink.comfDSRHold} * Mask <> {} THEN
        mm := mm OR windows.EV_DSR;
      END;
      IF seriallink.comfErrorEvent IN Mask THEN
        mm := mm OR windows.EV_ERR;
      END;
      IF {seriallink.comfRing,seriallink.comfRingHold} * Mask <> {} THEN
        mm := mm OR windows.EV_RING;
      END;
      IF {seriallink.comfRLSD,seriallink.comfRLSDHold} * Mask <> {} THEN
        mm := mm OR windows.EV_RLSD;
      END;
      IF seriallink.comfRxChar IN Mask THEN
        mm := mm OR windows.EV_RXCHAR;
      END;
      IF seriallink.comfRxEvent IN Mask THEN
        mm := mm OR windows.EV_RXFLAG;
      END;
      IF seriallink.comfTxEmpty IN Mask THEN
        mm := mm OR windows.EV_TXEMPTY;
      END;
      IF seriallink.comfRx80Full IN Mask THEN
        mm := mm OR windows.EV_RX80FULL;
      END;
      IF comsThreadLock IN CommState THEN
        windows.LeaveCriticalSection( ADR(MTCS));
      END;

      IF AutoReadPending THEN
        mm := mm AND NOT(windows.EV_RXCHAR OR windows.EV_RX80FULL);
      END;

    // CS >>>
      windows.EnterCriticalSection( ADR(CommCritical));
      CommEventMask := mm;
      FocusMask := Mask;
      windows.LeaveCriticalSection( ADR(CommCritical));
    // CS <<<

      IF comsReady IN CommState THEN
        windows.SetEvent( EventArray[hevCommEventRq]);
      END;
    END;
  END SetCommFocusMask;

  PUBLIC VIRTUAL PROCEDURE SetRxTimeout( TotalPerByte, TotalConst, Interval : CARDINAL ) : BOOLEAN;
  BEGIN
    WITH Timeouts DO
      ReadIntervalTimeout         := Interval;
      ReadTotalTimeoutMultiplier  := TotalPerByte;
      ReadTotalTimeoutConstant    := TotalConst;
    END;
    RETURN windows.SetCommTimeouts( HComm, ADR(Timeouts)) = windows.True;
  END SetRxTimeout;

  PUBLIC VIRTUAL PROCEDURE RxCount() : CARDINAL;
  VAR
    c : CARDINAL;
  BEGIN
    IF AutoReadPending THEN
    // CS >>>
      windows.EnterCriticalSection( ADR(CommCritical));
      c := RxQueue.GetCount();
      windows.LeaveCriticalSection( ADR(CommCritical));
    // CS <<<
      RETURN c;
    END;
    IF NOT ComStatCached THEN
    // CS >>>
      windows.EnterCriticalSection( ADR(CommCritical));
      UpdateCommStat();
      windows.LeaveCriticalSection( ADR(CommCritical));
    // CS <<<
    END;
    RETURN CurRxCount;
  END RxCount;

  PUBLIC VIRTUAL PROCEDURE RxFree() : CARDINAL;
  VAR
    c : CARDINAL;
  BEGIN
    IF AutoReadPending THEN
    // CS >>>
      windows.EnterCriticalSection( ADR(CommCritical));
      c := RxQueue.GetFree();
      windows.LeaveCriticalSection( ADR(CommCritical));
    // CS <<<
      RETURN c;
    END;
    IF NOT ComStatCached THEN
    // CS >>>
      windows.EnterCriticalSection( ADR(CommCritical));
      UpdateCommStat();
      windows.LeaveCriticalSection( ADR(CommCritical));
    // CS <<<
    END;
    RETURN RxQueue.BufferSize - CurRxCount;
  END RxFree;

  PUBLIC VIRTUAL PROCEDURE Receive( PBuf : ADDRESS; Len : CARDINAL; MaskRxCharPending : BOOLEAN ) : CARDINAL;
  VAR
    c : CARDINAL;
    n : CARDINAL;

    a1, a2 : ADDRESS;
    n1, n2 : CARDINAL;

    dbgs : ARRAY [0..255] OF TCHAR;

    b : BOOLEAN;
  BEGIN
    //{{AFX
    IF DebugMask * {dbgRecv} <> {} THEN
      __sprintf( ADR( dbgs ), '+++Receive pbuf=0x%x len=0x%x', PBuf, Len );
      windows.OutputDebugString( ADR( dbgs ));
    END;
    //}}AFX

    c := 0;
    IF Len = 0 THEN
      //{{AFX
      IF DebugMask * {dbgRecv} <> {} THEN
        __sprintf( ADR( dbgs ), '---Receive no request' );
        windows.OutputDebugString( ADR( dbgs ));
      END;
      //}}AFX
      RETURN 0;
    END;

    IF comsThreadLock IN CommState THEN
      windows.EnterCriticalSection( ADR(MTCS));
    END;

  // CS >>>
    windows.EnterCriticalSection( ADR(CommCritical));

    IF NOT CSRxPending THEN

    (*%F SYNC_COMM *) // Win9x/WinNT starts overlapped read
      n := RxQueue.GetCount();
      //{{AFX
      IF DebugMask * {dbgRecv} <> {} THEN
        __sprintf( ADR( dbgs ), 09W+0W+L'RxQueue 0x%x', n );
        windows.OutputDebugString( ADR( dbgs ));
      END;
      //}}AFX

      IF Len > n THEN
        RxBytesRq := Len;         // bytes in queue to complete this request
      ELSE
        RxBytesRq := 0;           // no additional request
      END;

      IF NOT AutoReadPending THEN
        CSMaskRxChar := MaskRxCharPending;
        IF DoReadComm( TRUE ) THEN
          RxBytesRq   := 0;     // no request
        END;
      END;

    // copy the requested data now 
      IF RxBytesRq = 0 THEN
        CSMaskRxChar := FALSE;
        c := MIN2( RxQueue.GetCount(), Len );
        IF NOT RxQueue.GetBlock( PBuf, c ) THEN
          c := 0;
        END;
        ComStatCached := FALSE;
      ELSE
        c := 0;
      END;
    (*%E SYNC_COMM *)

    (*%T SYNC_COMM *) // WinCE -- synchronous
      RxBytesRq     := Len;
      CSRxPending   := TRUE;
      UpdateCommStat();
      IF Len > CurRxCount THEN
        RxBytesRq := Len - CurRxCount;
        Len := CurRxCount;
      ELSE
        RxBytesRq := 0;
      END;
      IF Len <> 0 THEN
        ComStatCached := FALSE;
        b := windows.ReadFile( HComm, PBuf, Len, ADR( c ), NIL ) <> windows.False;
      ELSE
        b := TRUE;
      END;
      IF NOT b THEN
        //{{AFX
        IF DebugMask * {dbgReadFile} <> {} THEN
          __sprintf( ADR( dbgs ), '---ReadFile SYNC ERROR');
          windows.OutputDebugString( ADR( dbgs ));
        END;
        //}}AFX
        c := 0;
        INC( RxBytesRq, Len );
        //windows.SetEvent( EventArray[hevCommError]);  // ClearCommError
      ELSE
        //{{AFX
        IF DebugMask * {dbgReadFile} <> {} THEN
          __sprintf( dbgs, '---ReadFile SYNC bytes=0x%x', c );
          windows.OutputDebugString( dbgs );
        END;
        //}}AFX
      END;
      IF RxBytesRq = 0 THEN
        CSRxPending  := FALSE;
        CSMaskRxChar := FALSE;
      ELSE
        CSMaskRxChar := MaskRxCharPending;
      END;
    (*%E SYNC_COMM *)

    ELSE
      //{{AFX
      IF DebugMask * {dbgRecv} <> {} THEN
        __sprintf( ADR( dbgs ), '  Rx pending...' );
        windows.OutputDebugString( ADR( dbgs ));
      END;
      //}}AFX
    (*%F SYNC_COMM *)
    // copy the requested data now
      IF RxBytesRq = 0 THEN
        c := MIN2( RxQueue.GetCount(), Len );
        IF NOT RxQueue.GetBlock( PBuf, c ) THEN
          c := 0;
        END;
        ComStatCached := FALSE;
      ELSE
        c := 0;
      END;
    (*%E SYNC_COMM *)
    (*%T SYNC_COMM *)
      c := 0;
    (*%E SYNC_COMM *)
    END;

    windows.LeaveCriticalSection( ADR(CommCritical));
  // CS <<<

    (*%F SYNC_COMM *)
    IF CSRxPending AND NOT AutoReadPending THEN
      windows.SetEvent( EventArray[hevCommEventRq]);  // update event mask
    END;
    (*%E SYNC_COMM *)

    IF comsThreadLock IN CommState THEN
      windows.LeaveCriticalSection( ADR(MTCS));
    END;

    //{{AFX
    IF DebugMask * {dbgRecv} <> {} THEN
      __sprintf( ADR( dbgs ), '---Receive returns 0x%x', c );
      windows.OutputDebugString( ADR( dbgs ));
    END;
    //}}AFX

    RETURN c;
  END Receive;

  PUBLIC VIRTUAL PROCEDURE PurgeRxBuffer() : BOOLEAN;
  VAR
    b : BOOLEAN;
  BEGIN
    IF comsThreadLock IN CommState THEN
      windows.EnterCriticalSection( ADR(MTCS));
    END;
    IF windows.PurgeComm( HComm, windows.PURGE_RXABORT OR windows.PURGE_RXCLEAR ) = windows.True THEN
      b := TRUE;
    ELSE
      b := FALSE;
    END;

  // CS >>>
    windows.EnterCriticalSection( ADR(CommCritical));
    ComStatCached := FALSE;
    RxQueue.Purge();
    windows.LeaveCriticalSection( ADR(CommCritical));
  // CS <<<

    IF comsThreadLock IN CommState THEN
      windows.LeaveCriticalSection( ADR(MTCS));
    END;
    RETURN b;
  END PurgeRxBuffer;

  PUBLIC VIRTUAL PROCEDURE SetTxTimeout( TotalPerByte, TotalConst : CARDINAL ) : BOOLEAN;
  VAR
    b : BOOLEAN;
  BEGIN
    IF comsThreadLock IN CommState THEN
      windows.EnterCriticalSection( ADR(MTCS));
    END;
    WITH Timeouts DO
      WriteTotalTimeoutMultiplier := TotalPerByte;
      WriteTotalTimeoutConstant   := TotalConst;
    END;
    b := windows.SetCommTimeouts( HComm, ADR(Timeouts)) = windows.True;
    IF comsThreadLock IN CommState THEN
      windows.LeaveCriticalSection( ADR(MTCS));
    END;
    RETURN b;
  END SetTxTimeout;

  PUBLIC VIRTUAL PROCEDURE TxCount() : CARDINAL;
  VAR
    CurTxCount : CARDINAL;
  BEGIN
  // CS >>>
    windows.EnterCriticalSection( ADR(CommCritical));
    CurTxCount := TxQueue.GetCount();
    windows.LeaveCriticalSection( ADR(CommCritical));
  // CS <<<
    RETURN CurTxCount;
  END TxCount;

  PUBLIC VIRTUAL PROCEDURE TxFree() : CARDINAL;
  VAR
    CurTxCount : CARDINAL;
  BEGIN
  // CS >>>
    windows.EnterCriticalSection( ADR(CommCritical));
    CurTxCount := TxQueue.GetFree();
    windows.LeaveCriticalSection( ADR(CommCritical));
  // CS <<<
    RETURN CurTxCount;
  END TxFree;

  PUBLIC VIRTUAL PROCEDURE Send( PBuf : ADDRESS; Len : CARDINAL ) : CARDINAL;
  VAR
    c            : CARDINAL;
    fDirectWrite : BOOLEAN;
    dbgs : ARRAY [0..255] OF TCHAR;
  BEGIN
    //{{AFX
    IF DebugMask * {dbgSend} <> {} THEN
      __sprintf( ADR( dbgs ), '+++Send pbuf=0x%x len=0x%x', PBuf, Len );
      windows.OutputDebugString( ADR( dbgs ));
    END;
    //}}AFX

    IF (PBuf = NIL) OR (Len = 0) THEN
      RETURN 0;
    END;

    IF comsThreadLock IN CommState THEN
      windows.EnterCriticalSection( ADR(MTCS));
    END;

  // CS >>>
    windows.EnterCriticalSection( ADR(CommCritical));
  // copy data
    IF TxQueue.PutBlock( PBuf, Len ) THEN
      c := Len;
    ELSE
      c := 0;
      //{{AFX
      IF DebugMask * {dbgSend} <> {} THEN
        __sprintf( ADR( dbgs ), 09W+0W+L'ERROR - no space' );
        windows.OutputDebugString( ADR( dbgs ));
      END;
      //}}AFX
    END;

    fDirectWrite := NOT CSTxPending AND (c <> 0);
    windows.LeaveCriticalSection( ADR(CommCritical));
  // CS <<<

    IF comsThreadLock IN CommState THEN
      windows.LeaveCriticalSection( ADR(MTCS));
    END;

  (*%F SYNC_COMM *)
    IF fDirectWrite THEN
      windows.SetEvent( EventArray[hevWriteRq]);
    END;
  (*%E SYNC_COMM *)
  (*%T SYNC_COMM *)
    IF fDirectWrite THEN
      windows.SetEvent( EventArray[hevCEStartWrite]);
    END;
  (*%E SYNC_COMM *)

    //{{AFX
    IF DebugMask * {dbgSend} <> {} THEN
      __sprintf( ADR( dbgs ), '---Send bytes=0x%x', c );
      windows.OutputDebugString( ADR( dbgs ));
    END;
    //}}AFX

    RETURN c;
  END Send;

  PUBLIC VIRTUAL PROCEDURE Flush() : BOOLEAN;
  VAR
    b : BOOLEAN;
  BEGIN
    IF comsThreadLock IN CommState THEN
      windows.EnterCriticalSection( ADR(MTCS));
    END;
    b := windows.FlushFileBuffers( HComm ) = windows.True;
    IF comsThreadLock IN CommState THEN
      windows.LeaveCriticalSection( ADR(MTCS));
    END;
    RETURN b;
  END Flush;

  PUBLIC VIRTUAL PROCEDURE PurgeTxBuffer() : BOOLEAN;
  VAR
    b : BOOLEAN;
  BEGIN
    IF comsThreadLock IN CommState THEN
      windows.EnterCriticalSection( ADR(MTCS));
    END;

  // CS >>>
    windows.EnterCriticalSection( ADR(CommCritical));
    b := windows.PurgeComm( HComm, windows.PURGE_TXABORT OR windows.PURGE_TXCLEAR ) = windows.True;
    IF b THEN
      TxQueue.Purge();
    END;
    windows.LeaveCriticalSection( ADR(CommCritical));
  // CS <<<

    IF comsThreadLock IN CommState THEN
      windows.LeaveCriticalSection( ADR(MTCS));
    END;
    RETURN b;
  END PurgeTxBuffer;

  PUBLIC VIRTUAL PROCEDURE Escape( EscCode : CARDINAL ) : BOOLEAN;
  VAR
    b : BOOLEAN;
  BEGIN
    IF comsThreadLock IN CommState THEN
      windows.EnterCriticalSection( ADR(MTCS));
    END;

    CASE EscCode OF
    | escNOPARITY, escEVENPARITY, escMARKPARITY, escODDPARITY, escSPACEPARITY:
      WITH CommDCB DO
        CASE EscCode OF
        | escNOPARITY:
          Parity   := windows.NOPARITY

        | escEVENPARITY:
          Parity   := windows.EVENPARITY

        | escMARKPARITY:
          Parity   := windows.MARKPARITY

        | escODDPARITY:
          Parity   := windows.ODDPARITY

        | escSPACEPARITY:
          Parity   := windows.SPACEPARITY
        END;
        fParity := windows.True;
      END; (* WITH *)
      b := windows.EscapeCommFunction( HComm, windows.RESETDEV ) <> windows.False;
      b := windows.SetCommState( HComm, ADR(CommDCB)) <> windows.False;
      IF b THEN
      // CS >>>
        windows.EnterCriticalSection( ADR(CommCritical));
        UpdateCommStat();
        windows.LeaveCriticalSection( ADR(CommCritical));
      // CS <<<
      END;

    | escSETBREAK:  b := windows.SetCommBreak( HComm ) <> windows.False;
    | escCLRBREAK:  b := windows.ClearCommBreak( HComm ) <> windows.False;

    ELSE
      b := windows.EscapeCommFunction( HComm, EscCode ) <> windows.False;
    END;

    IF comsThreadLock IN CommState THEN
      windows.LeaveCriticalSection( ADR(MTCS));
    END;
    RETURN b;
  END Escape;

  PUBLIC VIRTUAL PROCEDURE GetProperty( PropertyName         : ARRAY OF CHAR;
                                        VAR PropertyType     : CARDINAL;
                                        PPropertyData        : ADDRESS;
                                        VAR PropertyDataSize : CARDINAL ) : BOOLEAN;
  TYPE
    TPC   = POINTER TO CARDINAL;
    TPAC  = POINTER TO ARRAY [0..0] OF CHAR;
  VAR
    c  : CARDINAL;
    dw : CARDINAL;
    res : BOOLEAN;
  BEGIN
    IF PropertyName[0] = CHAR(0C) THEN
      RETURN FALSE;
    END;
    res := FALSE;
    IF EQUALS( PropertyName, pnameVersion ) AND 
       (PropertyType = seriallink.propDWORD ) AND
       (PropertyDataSize >= SIZE(CARDINAL)) THEN
      IF PPropertyData <> NIL THEN
        TPC( PPropertyData )^ := CommVersion;
        PropertyDataSize := SIZE(CARDINAL);
        RETURN TRUE;
      END;

    ELSIF EQUALS( PropertyName, pnameDevice ) AND 
       (PropertyType = seriallink.propSZ ) THEN
      c := LENGTH(OpenedDev);
      IF (PropertyDataSize >= c + 1) AND (PPropertyData <> NIL) THEN
        IF c <> 0 THEN
          Storage.Move( ADR(OpenedDev), PPropertyData, c );
        END;
        TPAC( PPropertyData )^[c] := CHAR(0C);
        PropertyDataSize := c + 1;
        RETURN TRUE;      
      END;

    ELSIF EQUALS( PropertyName, pnameRxBuffer ) AND 
       (PropertyType = seriallink.propDWORD ) AND
       (PropertyDataSize >= SIZE(CARDINAL)) THEN
      IF PPropertyData <> NIL THEN
        TPC( PPropertyData )^ := MAX2( 1, RxWinBufSize-1 );
        PropertyDataSize := SIZE(CARDINAL);
        RETURN TRUE;      
      END;

    ELSIF EQUALS( PropertyName, pnameTxBuffer ) AND 
       (PropertyType = seriallink.propDWORD ) AND
       (PropertyDataSize >= SIZE(CARDINAL)) THEN
      IF PPropertyData <> NIL THEN
        TPC( PPropertyData )^ := MAX2( 1, TxWinBufSize-1 );
        PropertyDataSize := SIZE(CARDINAL);
        RETURN TRUE;      
      END;

    ELSIF EQUALS( PropertyName, pnameBaudRate ) AND 
       (PropertyType = seriallink.propDWORD ) AND
       (PropertyDataSize >= SIZE(CARDINAL)) THEN
      IF PPropertyData <> NIL THEN
        TPC( PPropertyData )^ := CommDCB.BaudRate;
        PropertyDataSize := SIZE(CARDINAL);
        RETURN TRUE;      
      END;

    ELSIF EQUALS( PropertyName, pnameParity ) AND 
       (PropertyType = seriallink.propDWORD ) AND
       (PropertyDataSize >= SIZE(CARDINAL)) THEN
      IF PPropertyData <> NIL THEN
        TPC( PPropertyData )^ := CARDINAL( CommDCB.Parity );
        PropertyDataSize := SIZE(CARDINAL);
        RETURN TRUE;      
      END;

    ELSIF EQUALS( PropertyName, pnameDataBits ) AND 
       (PropertyType = seriallink.propDWORD ) AND
       (PropertyDataSize >= SIZE(CARDINAL)) THEN
      IF PPropertyData <> NIL THEN
        TPC( PPropertyData )^ := CARDINAL( CommDCB.ByteSize );
        PropertyDataSize := SIZE(CARDINAL);
        RETURN TRUE;      
      END;

    ELSIF EQUALS( PropertyName, pnameStopBits ) AND 
       (PropertyType = seriallink.propDWORD ) AND
       (PropertyDataSize >= SIZE(CARDINAL)) THEN
      IF PPropertyData <> NIL THEN
        TPC( PPropertyData )^ := CARDINAL( CommDCB.StopBits );
        PropertyDataSize := SIZE(CARDINAL);
        RETURN TRUE;      
      END;

    ELSIF EQUALS( PropertyName, pnameCTS ) AND 
       (PropertyType = seriallink.propDWORD ) AND
       (PropertyDataSize >= SIZE(CARDINAL)) AND
       (HComm <> windows.INVALID_HANDLE_VALUE) THEN
      IF PPropertyData <> NIL THEN
        windows.GetCommModemStatus( HComm, ADR( dw ));
        IF (windows.MS_CTS_ON AND dw) <> 0 THEN
          c := 1;
        ELSE
          c := 0;
        END;
        res := TRUE;
      END;

    ELSIF EQUALS( PropertyName, pnameDSR ) AND 
       (PropertyType = seriallink.propDWORD ) AND
       (PropertyDataSize >= SIZE(CARDINAL)) AND
       (HComm <> windows.INVALID_HANDLE_VALUE) THEN
      IF PPropertyData <> NIL THEN
        windows.GetCommModemStatus( HComm, ADR( dw ));
        IF (windows.MS_DSR_ON AND dw) <> 0 THEN
          c := 1;
        ELSE
          c := 0;
        END;
        res := TRUE;
      END;

    ELSIF EQUALS( PropertyName, pnameRING ) AND 
       (PropertyType = seriallink.propDWORD ) AND
       (PropertyDataSize >= SIZE(CARDINAL)) AND
       (HComm <> windows.INVALID_HANDLE_VALUE) THEN
      IF PPropertyData <> NIL THEN
        windows.GetCommModemStatus( HComm, ADR( dw ));
        IF (windows.MS_RING_ON AND dw) <> 0 THEN
          c := 1;
        ELSE
          c := 0;
        END;
        res := TRUE;
      END;

    ELSIF EQUALS( PropertyName, pnameRLSD ) AND 
       (PropertyType = seriallink.propDWORD ) AND
       (PropertyDataSize >= SIZE(CARDINAL)) AND
       (HComm <> windows.INVALID_HANDLE_VALUE) THEN
      IF PPropertyData <> NIL THEN
        windows.GetCommModemStatus( HComm, ADR( dw ));
        IF (windows.MS_RLSD_ON AND dw) <> 0 THEN
          c := 1;
        ELSE
          c := 0;
        END;
        res := TRUE;
      END;
    END;
    IF res THEN
      TPC( PPropertyData )^ := c;
    END;
    RETURN res;
  END GetProperty;

  PUBLIC VIRTUAL PROCEDURE GetPropertyW( PropertyName         : ARRAY OF WCHAR;
                                         VAR PropertyType     : CARDINAL;
                                         PPropertyData        : ADDRESS;
                                         VAR PropertyDataSize : CARDINAL ) : BOOLEAN;
  VAR
    PropA : ARRAY [0..63] OF CHAR;
  BEGIN
    Strings.ToA( PropertyName, 0, OUT PropA );
    RETURN GetProperty( PropA, PropertyType, PPropertyData, PropertyDataSize );
  END GetPropertyW;

  PUBLIC VIRTUAL PROCEDURE SetProperty( PropertyName     : ARRAY OF CHAR;
                                        PropertyType     : CARDINAL;
                                        PPropertyData    : ADDRESS;
                                        PropertyDataSize : CARDINAL ) : BOOLEAN;
  TYPE
    TPC   = POINTER TO CARDINAL;
  VAR
    c : CARDINAL;
    b : BOOLEAN;
  BEGIN
    IF EQUALS( PropertyName, pnameBaudRate ) AND 
       (PropertyType = seriallink.propDWORD ) AND
       (PropertyDataSize >= SIZE(CARDINAL)) THEN
      IF PPropertyData <> NIL THEN
        c := CommDCB.BaudRate;
        CommDCB.BaudRate := TPC( PPropertyData )^;
        b := windows.SetCommState( HComm, ADR(CommDCB)) <> windows.False;
        IF NOT b THEN
          CommDCB.BaudRate := c;
          b := windows.SetCommState( HComm, ADR(CommDCB)) <> windows.False;
          RETURN FALSE;
        END;
        c := CARDINAL(CommDCB.ByteSize) + 1;
        IF CommDCB.StopBits = BYTE(windows.TWOSTOPBITS) THEN
          INC( c, 2 );
        ELSE
          INC( c );
        END;
        IF CommDCB.Parity <> BYTE(windows.NOPARITY) THEN
          INC( c );
        END;
        IF CommDCB.BaudRate <> 0 THEN
          CharDelay := 1000 * c DIV CARDINAL(CommDCB.BaudRate);
        ELSE
          CharDelay := 1;
        END;
        RETURN TRUE;
      END;

    ELSIF EQUALS( PropertyName, pnameParity ) AND 
       (PropertyType = seriallink.propDWORD ) AND
       (PropertyDataSize >= SIZE(CARDINAL)) THEN
      IF PPropertyData <> NIL THEN
        c := CARDINAL( CommDCB.Parity );
        CommDCB.Parity := BYTE( TPC( PPropertyData )^);
        b := windows.SetCommState( HComm, ADR(CommDCB)) <> windows.False;
        IF NOT b THEN
          CommDCB.Parity := BYTE( c );
          b := windows.SetCommState( HComm, ADR(CommDCB)) <> windows.False;
          RETURN FALSE;
        END;
        RETURN TRUE;
      END;

    ELSIF EQUALS( PropertyName, pnameDataBits ) AND 
       (PropertyType = seriallink.propDWORD ) AND
       (PropertyDataSize >= SIZE(CARDINAL)) THEN
      IF PPropertyData <> NIL THEN
        c := CARDINAL( CommDCB.ByteSize );
        CommDCB.ByteSize := BYTE( TPC( PPropertyData )^);
        b := windows.SetCommState( HComm, ADR(CommDCB)) <> windows.False;
        IF NOT b THEN
          CommDCB.ByteSize := BYTE( c );
          b := windows.SetCommState( HComm, ADR(CommDCB)) <> windows.False;
          RETURN FALSE;
        END;
        RETURN TRUE;
      END;

    ELSIF EQUALS( PropertyName, pnameStopBits ) AND 
       (PropertyType = seriallink.propDWORD ) AND
       (PropertyDataSize >= SIZE(CARDINAL)) THEN
      IF PPropertyData <> NIL THEN
        c := CARDINAL( CommDCB.StopBits );
        CommDCB.StopBits := BYTE( TPC( PPropertyData )^);
        b := windows.SetCommState( HComm, ADR(CommDCB)) <> windows.False;
        IF NOT b THEN
          CommDCB.StopBits := BYTE( c );
          b := windows.SetCommState( HComm, ADR(CommDCB)) <> windows.False;
          RETURN FALSE;
        END;
        RETURN TRUE;
      END;
    END;
    RETURN FALSE;
  END SetProperty;

  PUBLIC VIRTUAL PROCEDURE SetPropertyW( PropertyName     : ARRAY OF WCHAR;
                                         PropertyType     : CARDINAL;
                                         PPropertyData    : ADDRESS;
                                         PropertyDataSize : CARDINAL ) : BOOLEAN;
  VAR
    PropA : ARRAY [0..63] OF CHAR;
  BEGIN
    Strings.ToA( PropertyName, 0, OUT PropA );
    RETURN SetProperty( PropA, PropertyType, PPropertyData, PropertyDataSize );
  END SetPropertyW;

  LOCAL VIRTUAL PROCEDURE CommThread();

    PROCEDURE EmitEvent( Event : BITSET; Data : CARDINAL );
    BEGIN
      IF Event * FocusMask <> {} THEN
        CommEvent( Event, Data );
      END;
    END EmitEvent;

  VAR
    dw    : windows.DWORD;
    wb    : windows.BOOL;
    we    : CARDINAL;
    bs    : BITSET;

    pt       : ADDRESS;
    pa1, pa2 : ADDRESS;
    la1, la2 : CARDINAL;

    OwnEventMask : CARDINAL;
    Error        : CARDINAL;
    b            : BOOLEAN;
    fExit        : BOOLEAN;

  (*%F SYNC_COMM *)
    dbgs : ARRAY [0..255] OF TCHAR;
  (*%E SYNC_COMM *)
  BEGIN
    fExit             := FALSE;
    TxEmptySignalized := FALSE;

  (*%F SYNC_COMM *)
    IF AutoReadPending THEN
      windows.SetEvent( EventArray[hevReadRq]);
    ELSE
      windows.SetEvent( EventArray[hevRead]);
    END;
    windows.SetEvent( EventArray[hevWrite]);
    windows.SetEvent( EventArray[hevCommEventRq] );
  (*%E SYNC_COMM *)

    OwnEventMask := windows.EV_RXCHAR OR windows.EV_TXEMPTY OR windows.EV_ERR;
    IF AutoReadPending THEN
      OwnEventMask := OwnEventMask OR windows.EV_RXCHAR OR windows.EV_RX80FULL;
    END;

(*/* for testing purposes only
OwnEventMask := 
  windows.EV_BREAK OR
  windows.EV_CTS OR
  windows.EV_DSR OR
  windows.EV_ERR OR
  windows.EV_RING OR
  windows.EV_RLSD OR
  windows.EV_RXCHAR OR
  windows.EV_RXFLAG OR
  windows.EV_TXEMPTY OR
  windows.EV_RX80FULL;
*/*)

    SetCommFocusMask( FocusMask );

    REPEAT
    (*%F SYNC_COMM *)
      dw := windows.WaitForMultipleObjectsEx(
              NumCommEvents, ADR( EventArray ),
              windows.False,
              windows.INFINITE,
              windows.True );
    (*%E SYNC_COMM *)
    (*%T SYNC_COMM *)
      dw := windows.WaitForMultipleObjects(
              NumCommEvents, ADR( EventArray ),
              windows.False,
              windows.INFINITE );
    (*%E SYNC_COMM *)

      CASE dw OF

    (*%F SYNC_COMM *)
      | hevReadRq + windows.WAIT_OBJECT_0:

        windows.ResetEvent( EventArray[hevReadRq] );
        bs := {};
        Error := 0;

      // CS >>>
        windows.EnterCriticalSection( ADR(CommCritical));

        IF NOT CSRxPending THEN
          b := DoReadComm( TRUE );
        ELSE
          b := FALSE;
        END;
        IF NOT CSRxPending AND b THEN
          IF RxBytesRq <> 0 THEN
            IF RxBytesRq <= RxQueue.GetCount() THEN
              bs := {seriallink.comfRecvCountReached};
            ELSE
              bs := {seriallink.comfRxTimeout};
            END; // else bs = {}
            Error := RxBytesRead;
            RxBytesRq := 0;     // no request
          END;
        END; // CSRxPending

        windows.LeaveCriticalSection( ADR(CommCritical));
      // CS <<<

        EmitEvent( bs, Error );

        la1 := RxQueue.GetCount();
        IF la1 > RxBytesRq THEN
          EmitEvent( {seriallink.comfRxDataQueued}, la1 );
        END;
    (*%E SYNC_COMM *)

    (*%F SYNC_COMM *)
      | hevRead + windows.WAIT_OBJECT_0:

        bs := {};
        Error := 0;

      // CS >>>
        windows.EnterCriticalSection( ADR(CommCritical));
        b := DoReadComm( FALSE );
        windows.ResetEvent( EventArray[hevRead] );

        IF NOT CSRxPending AND b THEN
          IF RxBytesRq <> 0 THEN
            IF RxBytesRq <= RxQueue.GetCount() THEN
              bs := {seriallink.comfRecvCountReached};
            ELSE
              bs := {seriallink.comfRxTimeout};
            END; // else bs = {}
            Error := RxBytesRead;
            RxBytesRq   := 0;     // no request
          END;
        END; // CSRxPending
        windows.LeaveCriticalSection( ADR(CommCritical));
      // CS <<<

        EmitEvent( bs, Error );

        IF NOT AutoReadPending THEN
        // CS >>>
          windows.EnterCriticalSection( ADR(CommCritical));
          ComStatCached := FALSE;
          UpdateCommStat();
          windows.LeaveCriticalSection( ADR(CommCritical));
        // CS <<<
          IF NOT CSRxPending THEN
            windows.SetEvent( EventArray[hevCommEventRq] ); // set event mask to catch RXCHAR
          END;
        END;

        la1 := RxQueue.GetCount();
        IF AutoReadPending AND NOT CSRxPending AND (RxQueue.BufferSize * 8 DIV 10 <= la1) THEN
          EmitEvent( {seriallink.comfRx80Full}, la1 );
        END;
        IF la1 > RxBytesRq THEN
          EmitEvent( {seriallink.comfRxDataQueued}, la1 );
        END;
    (*%E SYNC_COMM *)

    (*%F SYNC_COMM *)
      | hevWrite + windows.WAIT_OBJECT_0,
        hevWriteRq + windows.WAIT_OBJECT_0:
    (*%E SYNC_COMM *)
    (*%T SYNC_COMM *)
      | hevWrite + windows.WAIT_OBJECT_0:
    (*%E SYNC_COMM *)

        bs := {};
        Error := 0;

      // CS >>>
        windows.EnterCriticalSection( ADR(CommCritical));

      (*%F SYNC_COMM *)
        IF (dw = hevWrite + windows.WAIT_OBJECT_0) AND CSTxPending THEN
        // has the overlapped write finished?

          windows.SetLastError( 0 );
          wb := windows.GetOverlappedResult( HComm, ADR(TxOverlapped), ADR(TxBytesWritten), windows.False );

        // ATTENTION: ResetEvent can be called after preceding call of GetOverlappedResult only
        // Calling it before causes Win9x to return incorrect ERROR_IO_INCOMPLETE result
          windows.ResetEvent( EventArray[hevWrite] );

          IF (wb = windows.False) AND (windows.GetLastError() = winerror.ERROR_IO_INCOMPLETE) THEN
          // continue pending ...
          ELSE
          // error in GetOverlappedResult (wb = False), but not ERROR_IO_INCOMPLETE 
          // OR
          // overlapped result ok
            CSTxPending := FALSE;
            INC( TotalTx, TxBytesWritten );
            b := ClearCommError();
            IF b AND (ComStatError <> 0) THEN
              bs := {seriallink.comfCE};
              Error := ComStatError;
            ELSE
              IF TxBytesWritten < TxBytesRq THEN
                bs := {seriallink.comfTxTimeout};
                Error := TxBytesWritten;
              END;
            END;
            TxQueue.GetBlockCommit( TxBytesRq );
          END;
        ELSE // not hevWrite or not CSTxPending
          CASE dw OF
          | hevWrite + windows.WAIT_OBJECT_0:   windows.ResetEvent( EventArray[hevWrite] );
          | hevWriteRq + windows.WAIT_OBJECT_0: windows.ResetEvent( EventArray[hevWriteRq] );
          END;
        END;
      (*%E SYNC_COMM *)

      (*%T SYNC_COMM *)
      //(*%T DEBUG *) vd.WrStr('CommThread SYNC hevWrite'); vd.WrLn(); (*%E DEBUG *)
        windows.ResetEvent( EventArray[hevWrite] );
        IF CSTxPending THEN
          INC( TotalTx, TxBytesWritten );
          b := ClearCommError();
          IF b AND (ComStatError <> 0) THEN
            bs := {seriallink.comfCE};
          ELSE
            IF TxBytesWritten < TxBytesRq THEN
              bs := {seriallink.comfTxTimeout};
              Error := TxBytesWritten;
            END;
          END;
          TxQueue.GetBlockCommit( TxBytesRq );
          CSTxPending := FALSE;
        END;
      (*%E SYNC_COMM *)

        windows.LeaveCriticalSection( ADR(CommCritical));
      // CS <<<

        IF NOT CSTxPending AND (bs * {seriallink.comfCE,seriallink.comfTxTimeout} <> {}) THEN
          PurgeTxBuffer();
        END;

      // timeout could occured...
        EmitEvent( bs, Error );

      (*%T SYNC_COMM *)
        IF NOT CSTxPending THEN
          la1 := TxCount();
          IF TxEmptySignalized AND (la1 = 0) THEN
            TxEmptySignalized := FALSE;
            EmitEvent( {seriallink.comfTxEmpty}, errOK );
            la1 := TxCount();
            IF la1 = 0 THEN
            // finish transmit
              XmitSignal( FALSE );
            END;
          END;
        END;
      //(*%T DEBUG *) vd.WrStr('CommThread SET hevCEWriteNext'); vd.WrLn(); (*%E DEBUG *)
        windows.SetEvent( EventArray[hevCEWriteNext] );
      (*%E SYNC_COMM *)

      (*%F SYNC_COMM *)
      // CS >>>
        windows.EnterCriticalSection( ADR(CommCritical));
        b := TxQueue.QryGetBlock( pa1, la1, pa2, la2 );
        windows.LeaveCriticalSection( ADR(CommCritical));
      // CS <<<
        IF b THEN
          IF (pa2 <> NIL) AND (la2 <> 0) THEN
            IF la1 + la2 > TxCacheSize THEN
              TxCacheSize := la1 + la2;
              IF PTxCache <> NIL THEN
                REALLOCATE( REF PTxCache, TxCacheSize );
              ELSE
                ALLOCATE( OUT PTxCache, TxCacheSize );
              END;
            END;
            pt := PTxCache;
            windows.CopyMemory( pt, pa1, la1 );
            INC( pt, la1 );
            windows.CopyMemory( pt, pa2, la2 );
            pa1 := PTxCache;
            INC( la1, la2 );
          END;
        ELSE
          pa1 := NIL;
          la1 := 0;
        END;

        IF NOT CSTxPending AND (la1 <> 0) THEN
          IF NOT CSXmit THEN
            XmitSignal( TRUE );
          END;
          TxBytesRq := la1;

          TxEmptySignalized := FALSE;
          TxBytesWritten := 0;
          TxOverlapped.Offset := 0;
          TxOverlapped.OffsetHigh := 0;
          b := windows.WriteFile( HComm, pa1, la1,
                                  ADR( TxBytesWritten ), ADR( TxOverlapped )) <> windows.False;
          IF b THEN
            INC( TotalTx, TxBytesWritten );
            IF TxBytesWritten < TxBytesRq THEN
              bs := {seriallink.comfTxTimeout};
              Error := TxBytesWritten;
            END;
          // CS >>>
            windows.EnterCriticalSection( ADR(CommCritical));
            TxQueue.GetBlockCommit( TxBytesRq ); 
            windows.LeaveCriticalSection( ADR(CommCritical));
          // CS <<<
          ELSIF windows.GetLastError() = winerror.ERROR_IO_PENDING THEN
          // CS >>>
            windows.EnterCriticalSection( ADR(CommCritical));
            CSTxPending := TRUE;
            windows.LeaveCriticalSection( ADR(CommCritical));
          // CS <<<
          ELSE
            windows.SetEvent( EventArray[hevCommError]);
          END;
        END;

      // user event - status may be changed
        EmitEvent( bs, Error );
        bs := {};
        Error := 0;

      // It is possible that some characters were added into transmit buffer
      // within the last call of CommEvent()
      // Check TxCount() now

        IF NOT CSTxPending THEN
          la1 := TxCount();
          IF TxEmptySignalized AND (la1 = 0) THEN
            TxEmptySignalized := FALSE;
            EmitEvent( {seriallink.comfTxEmpty}, errOK );
            la1 := TxCount();
            IF (la1 = 0) THEN
              XmitSignal( FALSE );
            END;
          END;
        END;
      (*%E SYNC_COMM *)

      | hevCommEventRq + windows.WAIT_OBJECT_0:
        windows.ResetEvent( EventArray[hevCommEventRq] );
      // CS >>>
        windows.EnterCriticalSection( ADR(CommCritical));
        we := CommEventMask OR OwnEventMask;
      (*%F SYNC_COMM *)
        IF NOT AutoReadPending AND CSRxPending AND ( NOT( seriallink.comfRxChar IN FocusMask ) OR CSMaskRxChar ) THEN
          we := we AND NOT(windows.EV_RXCHAR);
        END;
      (*%E SYNC_COMM *)
        windows.LeaveCriticalSection( ADR(CommCritical));
      // CS <<<

        IF we <> CurrentEvMask THEN
        //{{AFX
        IF DebugMask * {dbgCommEvt} <> {} THEN
          __sprintf( ADR( dbgs ), 'SetCommMask 0x%x', we );
          windows.OutputDebugString( ADR( dbgs ));
        END;
        //}}AFX
          windows.SetCommMask( HComm, we );
          CurrentEvMask := we;
        END;

        IF NOT CSWaitPending THEN
        // initially set the event to start wait operation
          windows.SetEvent( EventArray[hevCommEvent] );
        END;


      | hevCommEvent + windows.WAIT_OBJECT_0:

        IF CSWaitPending THEN
          //{{AFX
          IF DebugMask * {dbgCommEvt} <> {} THEN
            __sprintf( ADR( dbgs ), '---WaitCommEvent evt=0x%x', WaitEventOccured );
            windows.OutputDebugString( ADR( dbgs ));
          END;
          //}}AFX
          windows.SetLastError( 0 );
          wb := windows.GetOverlappedResult( HComm, ADR(WaitOverlapped), ADR(we), windows.False );
          windows.ResetEvent( EventArray[hevCommEvent] );
          we := WaitEventOccured;
          ComStatCached := FALSE;

          (*/*
          // CS >>>
            windows.EnterCriticalSection( ADR(CommCritical));
            we := WaitEventOccured;
            WaitEventOccured := 0;
            IF NOT CSRxPending AND (we = 0) THEN
              UpdateCommStat();
              IF CurRxCount <> 0 THEN
                we := we OR windows.EV_RXCHAR;
              END;
            END;
            windows.LeaveCriticalSection( ADR(CommCritical));
          // CS <<<
          */*)

          IF we <> 0 THEN
          (*%F SYNC_COMM *)
            IF AutoReadPending AND NOT CSRxPending AND ((we AND (windows.EV_RXCHAR OR windows.EV_RX80FULL)) <> 0) THEN
              windows.SetEvent( EventArray[ hevReadRq ] );
            END;
          (*%E SYNC_COMM *)

            windows.GetCommModemStatus( HComm, ADR( dw ));
            bs := {};
            IF (we AND windows.EV_BREAK) <> 0 THEN
              INCL( bs, seriallink.comfBreakEvent );
            END;
            IF (we AND windows.EV_CTS) <> 0 THEN
              IF (windows.MS_CTS_ON AND dw) <> 0 THEN
                INCL( bs, seriallink.comfCTSHold );
              ELSE
                INCL( bs, seriallink.comfCTS );
              END;
            END;
            IF (we AND windows.EV_DSR) <> 0 THEN
              IF (windows.MS_DSR_ON AND dw) <> 0 THEN
                INCL( bs, seriallink.comfDSRHold );
              ELSE
                INCL( bs, seriallink.comfDSR );
              END;
            END;
            IF (we AND windows.EV_ERR) <> 0 THEN
              INCL( bs, seriallink.comfErrorEvent );
              windows.SetEvent( EventArray[ hevCommError ]);
            END;
            IF (we AND windows.EV_RING) <> 0 THEN
              IF (windows.MS_RING_ON AND dw) <> 0 THEN
                INCL( bs, seriallink.comfRingHold );
              ELSE
                INCL( bs, seriallink.comfRing );
              END;
            END;
            IF (we AND windows.EV_RLSD) <> 0 THEN
              IF (windows.MS_RLSD_ON AND dw) <> 0 THEN
                INCL( bs, seriallink.comfRLSDHold );
              ELSE
                INCL( bs, seriallink.comfRLSD );
              END;
            END;
            IF (we AND windows.EV_RXFLAG) <> 0 THEN
              INCL( bs, seriallink.comfRxEvent );
            END;
            IF (we AND windows.EV_TXEMPTY) <> 0 THEN
            // CS >>>
              windows.EnterCriticalSection( ADR(CommCritical));
              IF NOT CSTxPending THEN
                INCL( bs, seriallink.comfTxEmpty );
              ELSE
                TxEmptySignalized := TRUE;
              END;
              windows.LeaveCriticalSection( ADR(CommCritical));
            // CS <<<
              IF seriallink.comfTxEmpty IN bs THEN
                EXCL( bs, seriallink.comfTxEmpty );
                EmitEvent( {seriallink.comfTxEmpty}, errOK );
                IF TxCount() = 0 THEN
                  XmitSignal( FALSE );
                END;
              END;
            END;

            IF (we AND windows.EV_RXCHAR) <> 0 THEN
              INCL( bs, seriallink.comfRxChar );
            (*%F SYNC_COMM *)
              IF NOT CSRxPending AND NOT AutoReadPending THEN
                IF seriallink.comfRxDataQueued IN FocusMask THEN
                // CS >>>
                  windows.EnterCriticalSection( ADR(CommCritical));
                  UpdateCommStat();
                  windows.LeaveCriticalSection( ADR(CommCritical));
                // CS <<<
                  EmitEvent( {seriallink.comfRxDataQueued}, CurRxCount );
                END;
              END;
            (*%E SYNC_COMM *)
            END;

          (*%F SYNC_COMM *)
            IF NOT AutoReadPending THEN
          (*%E SYNC_COMM *)
            IF (we AND windows.EV_RX80FULL) <> 0 THEN
              INCL( bs, seriallink.comfRx80Full );
            END;
          (*%F SYNC_COMM *)
            END; // AutoReadPending
          (*%E SYNC_COMM *)


          (*%T DEBUG *)
            // _DbgFocus( bs );
          (*%E DEBUG *)

            bs := bs * FocusMask;
            IF CSMaskRxChar THEN
              EXCL( bs, seriallink.comfRxChar );
            END;

            IF (seriallink.comfRxDataQueued IN bs) THEN
              IF CurRxCount = 0 THEN
                EXCL( bs, seriallink.comfRxDataQueued );
              END;
            END;

            IF bs <> {} THEN
              EmitEvent( bs, errOK );
            END;

          (*%T SYNC_COMM *)
            IF ((we AND windows.EV_RXCHAR) <> 0) THEN
              IF CSRxPending THEN
              // CS >>>
                windows.EnterCriticalSection( ADR(CommCritical));
                UpdateCommStat();
                windows.LeaveCriticalSection( ADR(CommCritical));
              // CS <<<
                IF CurRxCount <= RxBytesRq THEN
                  CSRxPending := FALSE;
                  EmitEvent( {seriallink.comfRecvCountReached}, CurRxCount );
                END;
              END;
              IF seriallink.comfRxDataQueued IN FocusMask THEN
              // CS >>>
                windows.EnterCriticalSection( ADR(CommCritical));
                UpdateCommStat();
                windows.LeaveCriticalSection( ADR(CommCritical));
              // CS <<<
                IF CurRxCount <> 0 THEN
                  EmitEvent( {seriallink.comfRxDataQueued}, CurRxCount );
                END;
              END;
            END;
          (*%E SYNC_COMM *)
          END;

          CSWaitPending := FALSE;
        END;  // CSWaitPending

      (*%F SYNC_COMM *) // overlapped wait 
        //{{AFX
        IF DebugMask * {dbgCommEvt} <> {} THEN
          __sprintf( ADR( dbgs ), '+++WaitCommEvent' );
          windows.OutputDebugString( ADR( dbgs ));
        END;
        //}}AFX
        WaitEventOccured := 0;
        CSWaitPending    := TRUE;
        wb := windows.WaitCommEvent( HComm, ADR( WaitEventOccured ), ADR( WaitOverlapped ));
        IF (wb = windows.True) THEN
          windows.SetEvent( EventArray[hevCommEvent] );
        ELSIF windows.GetLastError() <> winerror.ERROR_IO_PENDING THEN
          //{{AFX
          IF DebugMask * {dbgCommEvt} <> {} THEN
            __sprintf( ADR( dbgs ), '---WaitCommEvent ERROR' );
            windows.OutputDebugString( ADR( dbgs ));
          END;
          //}}AFX
          windows.SetEvent( EventArray[hevCommEventRq] );
          windows.SetEvent( EventArray[hevCommEvent] );
          windows.Sleep( 1 );
        END;
      (*%E SYNC_COMM *)

      (*%T SYNC_COMM *) // synchronous wait within other thread
//(*%T DEBUG *) vd.WrStr('CommThread SET hevCEWaitNext'); vd.WrLn(); (*%E DEBUG *)
        windows.SetEvent( EventArray[hevCEWaitNext] );
      (*%E SYNC_COMM *)

      | hevCommError + windows.WAIT_OBJECT_0:
        windows.ResetEvent( EventArray[hevCommError] );

//(*%T DEBUG *) vd.WrStr('CommThread SYNC hevCommError'); vd.WrLn(); (*%E DEBUG *)

        bs := {};
        Error := 0;
        b := ClearCommError();
        IF b AND (ComStatError <> 0) THEN
          bs := {seriallink.comfCE};
        END;
        EmitEvent( bs, ComStatError );
        ComStatError := 0;

      | hevDoneRq + windows.WAIT_OBJECT_0:
        windows.ResetEvent( EventArray[hevDoneRq] );
        fExit := NOT(comsReady IN CommState);

//(*%T DEBUG *) vd.WrStr('CommThread SYNC hevDoneRq'); vd.WrLn(); (*%E DEBUG *)

      END; // CASE
    UNTIL fExit;

  // added 23/03/2001
  // problems with ADAM4570 -- application stop delays for undefined time
  // problem is: Advantech COM/Ethernet SW tuneling support fails when Control Web application
  // stops and some comm. operation has not reached its finish (TX buffer is not free, RX_CHAR signalized, ...???)

    wb := windows.SetCommMask( HComm, 0 );
    windows.PurgeComm( HComm, windows.PURGE_TXABORT OR windows.PURGE_RXABORT OR
                              windows.PURGE_TXCLEAR OR windows.PURGE_RXCLEAR );
    ClearCommError();
    windows.Sleep( 1 );
  END CommThread;

  VIRTUAL PROCEDURE XmitSignal( On : BOOLEAN );
  BEGIN
    IF ({comsToggleDTR,comsNegToggleDTR,comsToggleRTS,comsNegToggleRTS} * CommState <> {}) AND
       (CSXmit <> On) THEN
      IF On THEN
        CSXmit := TRUE;   // begin transmition
      // PREKEY
        IF (comsToggleDTR IN CommState) THEN
          windows.EscapeCommFunction( HComm, windows.SETDTR );
        ELSIF (comsNegToggleDTR IN CommState) THEN
          windows.EscapeCommFunction( HComm, windows.CLRDTR );
        END;
        IF (comsToggleRTS IN CommState) THEN
          windows.EscapeCommFunction( HComm, windows.SETRTS );
        ELSIF (comsNegToggleRTS IN CommState) THEN
          windows.EscapeCommFunction( HComm, windows.CLRRTS );
        END;
        IF PreKey <> 0 THEN
          commWait( PreKey );
        END;
      ELSE
      // HOLDKEY
        IF (comsHalfDuplex IN CommState) AND (CharDelay + HoldKey <> 0) THEN
          commWait( CharDelay + HoldKey );
        ELSIF HoldKey <> 0 THEN
          commWait( HoldKey );
        END;
        IF (comsNegToggleDTR IN CommState) THEN
          windows.EscapeCommFunction( HComm, windows.SETDTR );
        ELSIF (comsToggleDTR IN CommState) THEN
          windows.EscapeCommFunction( HComm, windows.CLRDTR );
        END;
        IF (comsNegToggleRTS IN CommState) THEN
          windows.EscapeCommFunction( HComm, windows.SETRTS );
        ELSIF (comsToggleRTS IN CommState) THEN
          windows.EscapeCommFunction( HComm, windows.CLRRTS );
        END;
        CSXmit := FALSE;   // end transmition
      END;
    END;
  END XmitSignal;

  VIRTUAL PROCEDURE ClearCommError() : BOOLEAN;
  VAR
    LocError : CARDINAL;
    b        : BOOLEAN;
  BEGIN
    b := windows.ClearCommError( HComm, ADR( LocError ), ADR( ComStat )) <> windows.False;
    IF b THEN
      ComStatError := ComStatError OR LocError;
      IF ComStatError <> 0 THEN
        windows.SetEvent( EventArray[hevCommError] );
      END;
    END;
    RETURN b;
  END ClearCommError;

  VIRTUAL PROCEDURE UpdateCommStat();
  VAR
    LocError : CARDINAL;
  BEGIN
    IF windows.ClearCommError( HComm, ADR( LocError ), ADR( ComStat )) <> windows.False THEN
      ComStatError  := ComStatError OR LocError;
      IF NOT AutoReadPending THEN
        CurRxCount    := MAX2( CARDINAL( ComStat.cbInQue ), RxQueue.GetCount());
      END;
      ComStatCached := TRUE;
    END;
  END UpdateCommStat;

(*%F SYNC_COMM *)
  VIRTUAL PROCEDURE DoReadComm( StartRead : BOOLEAN ) : BOOLEAN;
  VAR
    c : CARDINAL;
    n : CARDINAL;

    a1, a2 : ADDRESS;
    n1, n2 : CARDINAL;

    dbgs : ARRAY [0..255] OF TCHAR;

    CheckSync  : BOOLEAN;
    CheckAsync : BOOLEAN;
    b   : BOOLEAN;
    res : BOOLEAN;
  BEGIN
    res        := FALSE;
    CheckSync  := FALSE;
    CheckAsync := FALSE;

    IF StartRead THEN
      IF NOT CSRxPending THEN
        ComStatCached := FALSE;
        UpdateCommStat();
        c := ComStat.cbInQue;

        IF NOT AutoReadPending THEN
        // option - to begin overlapped read
          c := MAX2( RxBytesRq, c );
        END;


        IF c <> 0 THEN
        // check for space
          RxQueue.QryPutBlock( a1, n1, a2, n2 );
          IF c > n1 + n2 THEN
            c := n1 + n2;
          END;
        // check if cannot be perfomed in-situ
          IF c > n1 THEN
            IF c > RxQueue.BufferSize THEN
              a1 := NIL;
            ELSE
              IF c > RxCacheSize THEN
                RxCacheSize := c;
                IF PRxCache <> NIL THEN
                  REALLOCATE( REF PRxCache, RxCacheSize );
                ELSE
                  ALLOCATE( OUT PRxCache, RxCacheSize );
                END;
              END;
              a1 := PRxCache;
              RxCacheUsed := TRUE;
            END;
          ELSE
          // in-situ
            RxCacheUsed := FALSE;
          END;

          IF a1 <> NIL THEN
            //{{AFX
            IF DebugMask * {dbgReadFile} <> {} THEN
              __sprintf( ADR( dbgs ), '+++ReadFile len=0x%x', c );
              windows.OutputDebugString( ADR( dbgs ));
            END;
            //}}AFX
            CSRxPending             := TRUE;
            RxOverlapped.Offset     := 0;
            RxOverlapped.OffsetHigh := 0;
            RxBytesRead             := 0;
            ComStatCached           := FALSE;
            b := windows.ReadFile( HComm, a1, c,
                                   ADR( RxBytesRead ), ADR( RxOverlapped )) <> windows.False;
            CheckSync := TRUE;
          ELSE
            //{{AFX
            IF DebugMask * {dbgReadFile} <> {} THEN
              __sprintf( ADR( dbgs ), 'ReadFile ABORT - no buffer space', c );
              windows.OutputDebugString( ADR( dbgs ));
            END;
            //}}AFX
            b := FALSE;
            windows.SetLastError( winerror.ERROR_OUTOFMEMORY );
          END;
        ELSE
        // no-op
          res := TRUE; // signalize SUCCESS: no read in progress
        END;
      ELSE
      // ignore when pending
        //{{AFX
        IF DebugMask * {dbgRecv} <> {} THEN
          __sprintf( ADR( dbgs ), 'DoReadComm Rx pending, ignored' );
          windows.OutputDebugString( ADR( dbgs ));
        END;
        //}}AFX
      END;

    ELSE  // IF StartRead
      // !!!
      // Ignored when called w/o CSRxPending - some drivers always set event although overlapped read finished synchronously
      CheckAsync := CSRxPending;

      IF CSRxPending THEN
        RxBytesRead := 0;
        windows.SetLastError( 0 );
        ComStatCached := FALSE;
        b := windows.GetOverlappedResult( HComm, ADR(RxOverlapped), ADR(RxBytesRead), windows.False ) <> windows.False;
      ELSE
        RxBytesRead := 0;
        //{{AFX
        IF DebugMask * {dbgReadFile} <> {} THEN
          __sprintf( ADR( dbgs ), '  ***ReadFile - not pending, ignored');
          windows.OutputDebugString( ADR( dbgs ));
        END;
        //}}AFX
      END;
    END;

    IF CheckSync OR CheckAsync THEN
      IF b THEN
      // To block processing of 'hevRead' event set-off CSRxPending:
      // Operation has been performed synchronously, but some drivers signalize
      // finished overlapped operation in all cases.
      // If an overlapped operation finish no problems were detected.
        CSRxPending := FALSE; // finished
        INC( TotalRx, RxBytesRead );
      // finish read
        IF RxCacheUsed THEN
          RxQueue.PutBlock( PRxCache, RxBytesRead );
        ELSE
          RxQueue.PutBlockCommit( RxBytesRead );
        END;
        //{{AFX
        IF DebugMask * {dbgReadFile} <> {} THEN
          __sprintf( ADR( dbgs ), '---ReadFile (sync=%x) res=%x bytes=0x%x', CheckSync, b, RxBytesRead );
          windows.OutputDebugString( ADR( dbgs ));
        END;
        //}}AFX
        ClearCommError();
        res := TRUE;

      ELSIF windows.GetLastError() = winerror.ERROR_IO_PENDING THEN
        //{{AFX
        IF DebugMask * {dbgReadFile} <> {} THEN
          __sprintf( ADR( dbgs ), '  ***ReadFile still pending');
          windows.OutputDebugString( ADR( dbgs ));
        END;
        //}}AFX
        res := FALSE;

      ELSE  // error
        CSRxPending := FALSE; // finished by error
        //{{AFX
        IF DebugMask * {dbgReadFile} <> {} THEN
          __sprintf( ADR( dbgs ), '---ReadFile (sync=%x) ERROR', CheckSync );
          windows.OutputDebugString( ADR( dbgs ));
        END;
        //}}AFX
        ClearCommError();
        res := FALSE;
      END;
    END;
    RETURN res;
  END DoReadComm;
(*%E SYNC_COMM *)

(*%T SYNC_COMM *)
  VIRTUAL PROCEDURE CECommThreadWait();
  VAR
    EvtArray : ARRAY [0..1] OF windows.HANDLE;
    dw       : CARDINAL;
    wb       : windows.BOOL;

    dbgs : ARRAY [0..255] OF TCHAR;
  BEGIN
    EvtArray[0] := EventArray[hevCEThreadDone];
    EvtArray[1] := EventArray[hevCEWaitNext];
    REPEAT
      dw := windows.WaitForMultipleObjects(
              2, ADR( EvtArray ),
              windows.False,
              windows.INFINITE );

      CASE dw OF
      | 1 + windows.WAIT_OBJECT_0: //hevCEWaitNext
        //windows.ResetEvent( EventArray[hevCEWaitNext] );
      // run synchronous wait
//(*%T DEBUG *) vd.WrStr('WaitCommEvent SYNC START'); vd.WrLn(); (*%E DEBUG *)

        //{{AFX
        IF DebugMask * {dbgCommEvt} <> {} THEN
          __sprintf( dbgs, '+++WaitCommEvent SYNC' );
          windows.OutputDebugString( dbgs );
        END;
        //}}AFX

        wb := windows.WaitCommEvent( HComm, ADR( WaitEventOccured ), NIL );
//(*%T DEBUG *) vd.WrStr('WaitCommEvent AFTER'); vd.WrLn(); (*%E DEBUG *)

        //{{AFX
        IF DebugMask * {dbgCommEvt} <> {} THEN
          __sprintf( dbgs, '---WaitCommEvent SYNC evt=0x%x', WaitEventOccured );
          windows.OutputDebugString( dbgs );
        END;
        //}}AFX

        windows.ResetEvent( EventArray[hevCEWaitNext] );
        IF WaitEventOccured <> 0 THEN
//(*%T DEBUG *) vd.WrStr('WaitCommEvent SET hevCommEvent'); vd.WrLn(); (*%E DEBUG *)
          windows.SetEvent( EventArray[hevCommEvent] );
//(*%T DEBUG *) ELSE vd.WrStr('WaitCommEvent *NO-EVENT*'); vd.WrLn(); (*%E DEBUG *)
        END;
      END;
    UNTIL dw = 0 + windows.WAIT_OBJECT_0; //hevCEThreadDone
  END CECommThreadWait;

  VIRTUAL PROCEDURE CECommThreadWrite();
  VAR
    EvtArray : ARRAY [0..1] OF windows.HANDLE;
    dw       : CARDINAL;
    pt       : ADDRESS;
    pa1, pa2 : ADDRESS;
    la1, la2 : CARDINAL;
    b        : BOOLEAN;

    dbgs : ARRAY [0..255] OF TCHAR;
  BEGIN
    EvtArray[0] := EventArray[hevCEThreadDone];
    EvtArray[1] := EventArray[hevCEStartWrite];
    REPEAT
      dw := windows.WaitForMultipleObjects(
              2, ADR( EvtArray ),
              windows.False,
              windows.INFINITE );

      CASE dw OF
      | 1 + windows.WAIT_OBJECT_0: //hevCEStartWrite
        windows.ResetEvent( EventArray[hevCEStartWrite] );

//(*%T DEBUG *) vd.WrStr('Write SYNC hevCEStartWrite'); vd.WrLn(); (*%E DEBUG *)

      // CS >>>
        windows.EnterCriticalSection( ADR(CommCritical));
        b := TxQueue.QryGetBlock( pa1, la1, pa2, la2 );
        windows.LeaveCriticalSection( ADR(CommCritical));
      // CS <<<

        IF b THEN
          //{{AFX
          IF DebugMask * {dbgWriteFile} <> {} THEN
            __sprintf( dbgs, 'TxQueue bytes=0x%x', la1+la2 );
            windows.OutputDebugString( dbgs );
          END;
          //}}AFX
          IF (pa2 <> NIL) AND (la2 <> 0) THEN
            IF la1 + la2 > TxCacheSize THEN
              TxCacheSize := la1 + la2;
              IF PTxCache <> NIL THEN
                REALLOCATE( REF PTxCache, TxCacheSize );
              ELSE
                ALLOCATE( OUT PTxCache, TxCacheSize );
              END;
            END;
            pt := PTxCache;
            windows.CopyMemory( pt, pa1, la1 );
            INC( pt, la1 );
            windows.CopyMemory( pt, pa2, la2 );
            pa1 := PTxCache;
            INC( la1, la2 );
          END;
        ELSE
          pa1 := NIL;
          la1 := 0;
        END;

        IF (la1 <> 0) THEN
        // CS >>>
          windows.EnterCriticalSection( ADR(CommCritical));
          TxBytesRq := la1;
          CSTxPending := TRUE;
          TxBytesWritten    := 0;
          TxEmptySignalized := FALSE;
          windows.LeaveCriticalSection( ADR(CommCritical));
        // CS <<<

          IF NOT CSXmit THEN
          // start transmit
            XmitSignal( TRUE );
          END;

          //{{AFX
          IF DebugMask * {dbgWriteFile} <> {} THEN
            __sprintf( dbgs, '+++WriteFile bytes=0x%x', la1 );
            windows.OutputDebugString( dbgs );
          END;
          //}}AFX

          b := windows.WriteFile( HComm, pa1, la1, ADR( TxBytesWritten ), NIL ) <> windows.False;

          //{{AFX
          IF DebugMask * {dbgWriteFile} <> {} THEN
            __sprintf( dbgs, '---WriteFile SYNC res=%x bytes=0x%x', b, TxBytesWritten );
            windows.OutputDebugString( dbgs );
          END;
          //}}AFX

//(*%T DEBUG *) vd.WrBool('Write windows.WriteFile', b ); vd.WrLn(); (*%E DEBUG *)

          IF NOT b THEN
            windows.SetEvent( EventArray[hevCommError]);
          END;
          windows.SetEvent( EventArray[hevWrite]);

        // synchronize with comm. thread
//(*%T DEBUG *) vd.WrStr('Write WAIT hevCEWriteNext'); vd.WrLn(); (*%E DEBUG *)
          windows.WaitForSingleObject( EventArray[hevCEWriteNext], windows.INFINITE );
//(*%T DEBUG *) vd.WrStr('Write SYNC hevCEWriteNext'); vd.WrLn(); (*%E DEBUG *)
          windows.ResetEvent( EventArray[hevCEWriteNext] );

        // check transmit buffer
          IF TxCount() <> 0 THEN
            windows.SetEvent( EventArray[hevCEStartWrite] );
          END;
        END;
      END;
    UNTIL dw = 0 + windows.WAIT_OBJECT_0; //hevCEThreadDone
  END CECommThreadWrite;
(*%E SYNC_COMM *)

BEGIN
  InitCount    := 0;
  CommState    := {};
  FocusMask    := {};

  OpenedDev[0] := 0T;
  HComm        := windows.INVALID_HANDLE_VALUE;

// COMMTIMEOUTS
//
// ReadIntervalTimeout: A value of MAXDWORD, combined with zero values for both 
// the ReadTotalTimeoutConstant and ReadTotalTimeoutMultiplier members,
// specifies that the read operation is to return immediately with the characters 
// that have already been received, even if no characters have been received.
//
// If an application sets ReadIntervalTimeout and ReadTotalTimeoutMultiplier to MAXDWORD
// and sets ReadTotalTimeoutConstant to a value greater than zero and less than MAXDWORD,
// one of the following occurs when the ReadFile function is called:
// * If there are any characters in the input buffer, ReadFile returns immediately with the characters in the buffer.
// * If there are no characters in the input buffer, ReadFile waits until a character arrives and then returns immediately.
// * If no character arrives within the time specified by ReadTotalTimeoutConstant, ReadFile times out.

  Timeouts          := windows.COMMTIMEOUTS( MAX(CARDINAL), 0, 0, 10, 1000 );
//  Timeouts          := windows.COMMTIMEOUTS( MAX(CARDINAL), MAX(CARDINAL), 1, 10, 1000 );

  Storage.Fill( ADR( CommDCB ),      SIZE( CommDCB ),      0 );
(*%F SYNC_COMM *)
  Storage.Fill( ADR(RxOverlapped),   SIZE(RxOverlapped),   0 );
  Storage.Fill( ADR(TxOverlapped),   SIZE(TxOverlapped),   0 );
  Storage.Fill( ADR(WaitOverlapped), SIZE(WaitOverlapped), 0 );
(*%E SYNC_COMM *)

  CommEventMask     := 0;
  CurrentEvMask     := 0;
  WaitEventOccured  := 0;
  RxWinBufSize      := 0;
  TxWinBufSize      := 0;

// set ClearOnFree to preserve maximum continuous space
// to ensure in-situ operations
  RxQueue.ClearOnFree := TRUE;
  TxQueue.ClearOnFree := TRUE;

  RxCacheSize       := 0;
  PRxCache          := NIL;
  TxCacheSize       := 0;
  PTxCache          := NIL;

  RxCacheUsed       := FALSE;
  TxCacheUsed       := FALSE;

  windows.InitializeCriticalSection( ADR(CommCritical));
  windows.InitializeCriticalSection( ADR(MTCS));

  Storage.Fill( ADR(EventArray), SIZE(EventArray), 0 );
  HCommThread       := NIL;
  CommThreadId      := MAX(CARDINAL);
(*%T SYNC_COMM *)
  HWaitThread       := NIL;
  WaitThreadId      := MAX(CARDINAL);
  HWriteThread      := NIL;
  WriteThreadId     := MAX(CARDINAL);
(*%E SYNC_COMM *)

  BasePriority      := windows.THREAD_PRIORITY_NORMAL;

  CharDelay         := 1;
  PreKey            := 0;
  HoldKey           := 0;

  Storage.Fill( ADR( ComStat ), SIZE( ComStat ), 0 );
  ComStatError      := 0;
  CurRxCount        := 0;
  ComStatCached     := FALSE;
  AutoReadPending   := FALSE;
  CSRxPending       := FALSE;
  CSTxPending       := FALSE;
  CSWaitPending     := FALSE;
  CSMaskRxChar      := FALSE;
  CSXmit            := FALSE;
  TxEmptySignalized := FALSE;

  RxBytesRq         := 0;
  TxBytesRq         := 0;
  RxBytesRead       := 0;
  TxBytesWritten    := 0;

(*%F DEBUG *)
  DebugMask         := {};
(*%E DEBUG *)
(*%T DEBUG *)
  // DebugMask         := BITSET(0FFFFFFFFH);
  DebugMask         := {};
(*%E DEBUG *)

// performance counters
  TotalRx           := 0;
  TotalTx           := 0;
END CCommStream;

(* ================================================================ *)

  PROCEDURE NewLinkInstance() : ADDRESS;
  VAR
    PCom : TPCommStream;
  BEGIN
    NEW( PCom );
    RETURN PCom;
  END NewLinkInstance;

  PROCEDURE FreeLinkInstance( PI : ADDRESS );
  BEGIN
    IF PI <> NIL THEN
      DISPOSE( PI );
    END;
  END FreeLinkInstance;

END comm.