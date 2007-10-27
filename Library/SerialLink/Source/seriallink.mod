IMPLEMENTATION MODULE seriallink;

(*/*)
(* ================================================================ *)
(*   CwComm - COM Communication Layer for Control Web               *)
(*                                                                  *)
(*   (c) 1998 by DAD, Moravian Instruments                          *)
(* ================================================================ *)
(*/*)

(*# call( o_a_size=>on,
          o_a_copy=>off ) *)

IMPORT
  windows;

IMPORT
  Storage,
  Strings,
  FIO;

FROM Storage IMPORT
  ALLOCATE, DEALLOCATE;
  
FROM Strings IMPORT
  LowerizeW;

(* ================================================================ *)

CLASS IMPLEMENTATION CCommLinkStream; (* >>>>>>>>>>>>>>>>>>>>>>>>>> *)

  PUBLIC VIRTUAL PROCEDURE Init( Device      : ARRAY OF CHAR;
                                 IniFilePath : ARRAY OF CHAR;
                                 fMultithreadLock, fPrivate : BOOLEAN;
                                 VAR ErrorString : ARRAY OF CHAR;
                                 VAR hSession : TSessionHandle ) : BOOLEAN;
  BEGIN
    RETURN FALSE;
  END Init;

  PUBLIC VIRTUAL PROCEDURE InitW( Device      : ARRAY OF WCHAR;
                                  IniFilePath : ARRAY OF WCHAR;
                                  fMultithreadLock, fPrivate : BOOLEAN;
                                  VAR ErrorString : ARRAY OF WCHAR;
                                  VAR hSession : TSessionHandle ) : BOOLEAN;
  BEGIN
    RETURN FALSE;
  END InitW;

  PUBLIC VIRTUAL PROCEDURE Done();
  BEGIN
    IF PSHandles <> NIL THEN
      DISPOSE( PSHandles );
    END;
  END Done;

  PUBLIC VIRTUAL PROCEDURE DoneSession( hSession : TSessionHandle );
  VAR
    c : CARDINAL;
  BEGIN
    IF (hSession <> InvalidSessionHandle) AND (PSHandles <> NIL) THEN
      EXCL( TPSessionHandleSet( PSHandles )^, hSession - 1 );
      FOR c := 0 TO SIZE(BITSET) - 1 DO
        WITH CommCBArray[c] DO
          IF SessionHandle = hSession THEN
            CommCallback := TCommCallback( NIL );
            CommCallbackParam := NIL;
            SessionHandle     := TSessionHandle( NIL );
            Opt               := {};
          END;
        END;
      END;
    END;
  END DoneSession;

  VIRTUAL PROCEDURE GetNewSessionHandle() : TSessionHandle;
  VAR
    c : CARDINAL;
  BEGIN
    IF PSHandles = NIL THEN
      RETURN InvalidSessionHandle;
    END;
    c := 0;
    WHILE (c < SessionHandles) AND (c IN TPSessionHandleSet( PSHandles )^) DO
      INC( c );
    END;
    IF c < SessionHandles THEN
      INCL( TPSessionHandleSet( PSHandles )^, c );
      RETURN TSessionHandle(c + 1);
    ELSE
      RETURN InvalidSessionHandle;
    END;
  END GetNewSessionHandle;

  PUBLIC VIRTUAL PROCEDURE SetBasePriority( ThreadPriority : INTEGER );
  BEGIN
  END SetBasePriority;

  PUBLIC VIRTUAL PROCEDURE GetCommFocusMask( VAR Mask : BITSET );
  BEGIN
    Mask := FocusMask;
  END GetCommFocusMask;

  PUBLIC VIRTUAL PROCEDURE SetCommFocus( Event : CARDINAL; fSet : BOOLEAN );
  BEGIN
    IF fSet THEN
      INCL( FocusMask, Event );
    ELSE
      EXCL( FocusMask, Event );
    END;
  END SetCommFocus;

  PUBLIC VIRTUAL PROCEDURE SetCommFocusMask( Mask : BITSET );
  BEGIN
    FocusMask := Mask;
  END SetCommFocusMask;

  PUBLIC VIRTUAL PROCEDURE GetCommCallback( Event : CARDINAL; 
                                            VAR CBRoutine : ADDRESS; //TCommCallback;
                                            VAR CBParam   : ADDRESS;
                                            VAR hSession : TSessionHandle ) : BOOLEAN;
  BEGIN
    IF Event >= 8*SIZE(BITSET) THEN
      RETURN FALSE;
    END;
    IF NOT( cbtInvisible IN CommCBArray[ Event ].Opt ) THEN
      CBRoutine := ADDRESS(CommCBArray[ Event ].CommCallback);
      CBParam   := CommCBArray[ Event ].CommCallbackParam;
      hSession  := CommCBArray[ Event ].SessionHandle;
    ELSE
      CBRoutine := NIL; //TCommCallback( NIL );
      CBParam   := NIL;
      hSession  := TSessionHandle( NIL );
    END;
    RETURN TRUE;
  END GetCommCallback;

  PUBLIC VIRTUAL PROCEDURE SetCommCallback( hSession : TSessionHandle;
                                            Event : CARDINAL;
                                            CBRoutine : TCommCallback; CBParam : ADDRESS;
                                            fPrivate, fInvisible : BOOLEAN ) : BOOLEAN;
  VAR
    c : CARDINAL;
  BEGIN
    IF (PSHandles = NIL) OR (hSession = InvalidSessionHandle) THEN
      RETURN FALSE;
    END;
    IF Event >= 8*SIZE(BITSET) THEN
      RETURN FALSE;
    END;
    c := CARDINAL( hSession ) - 1;
    IF NOT( c IN TPSessionHandleSet( PSHandles )^) THEN
      RETURN FALSE;
    END;
    WITH CommCBArray[ Event ] DO
      CommCallback  := CBRoutine;
      CommCallbackParam := CBParam;
      SessionHandle := hSession;
      IF fPrivate THEN
        INCL( Opt, cbtPrivate );
      END;
      IF fInvisible THEN
        INCL( Opt, cbtInvisible );
      END;
    END;
    RETURN TRUE;
  END SetCommCallback;

  PUBLIC VIRTUAL PROCEDURE SetCommCallbackM( hSession : TSessionHandle;
                                             Mask : BITSET;
                                             CBRoutine : TCommCallback; CBParam : ADDRESS;
                                             fPrivate, fInvisible : BOOLEAN ) : BOOLEAN;
  VAR
    c : CARDINAL;
  BEGIN
    IF (PSHandles = NIL) OR (hSession = InvalidSessionHandle) THEN
      RETURN FALSE;
    END;
    c := CARDINAL( hSession ) - 1;
    IF NOT( c IN TPSessionHandleSet( PSHandles )^) THEN
      RETURN FALSE;
    END;
    IF Mask = {} THEN
      RETURN TRUE;
    END;
    FOR c := 0 TO SIZE(BITSET)*8-1 DO
      IF c IN Mask THEN
        WITH CommCBArray[ c ] DO
          CommCallback  := CBRoutine;
          CommCallbackParam := CBParam;
          SessionHandle := hSession;
          IF fPrivate THEN
            INCL( Opt, cbtPrivate );
          END;
          IF fInvisible THEN
            INCL( Opt, cbtInvisible );
          END;
        END;
      END;
    END;
    RETURN TRUE;
  END SetCommCallbackM;

  PUBLIC VIRTUAL PROCEDURE SetRxTimeout( TotalPerByte, TotalConst, Interval : CARDINAL ) : BOOLEAN;
  BEGIN
    RETURN FALSE;
  END SetRxTimeout;

  PUBLIC VIRTUAL PROCEDURE RxCount() : CARDINAL;
  BEGIN
    RETURN 0;
  END RxCount;

  PUBLIC VIRTUAL PROCEDURE RxFree() : CARDINAL;
  BEGIN
    RETURN 0;
  END RxFree;

  PUBLIC VIRTUAL PROCEDURE Receive( PBuf : ADDRESS; Len : CARDINAL; MaskRxCharPending : BOOLEAN ) : CARDINAL;
  BEGIN
    RETURN 0;
  END Receive;
    
  PUBLIC VIRTUAL PROCEDURE PurgeRxBuffer() : BOOLEAN;
  BEGIN
    RETURN FALSE;
  END PurgeRxBuffer;

  PUBLIC VIRTUAL PROCEDURE SetTxTimeout( TotalPerByte, TotalConst : CARDINAL ) : BOOLEAN;
  BEGIN
    RETURN FALSE;
  END SetTxTimeout;

  PUBLIC VIRTUAL PROCEDURE TxCount() : CARDINAL;
  BEGIN
    RETURN 0;
  END TxCount;

  PUBLIC VIRTUAL PROCEDURE TxFree() : CARDINAL;
  BEGIN
    RETURN 0;
  END TxFree;

  PUBLIC VIRTUAL PROCEDURE Send( PBuf : ADDRESS; Len : CARDINAL ) : CARDINAL;
  BEGIN
    RETURN 0;
  END Send;

  PUBLIC VIRTUAL PROCEDURE Flush() : BOOLEAN;
  BEGIN
    RETURN FALSE;
  END Flush;

  PUBLIC VIRTUAL PROCEDURE PurgeTxBuffer() : BOOLEAN;
  BEGIN
    RETURN FALSE;
  END PurgeTxBuffer;

  PUBLIC VIRTUAL PROCEDURE Escape( EscCode : CARDINAL ) : BOOLEAN;
  BEGIN
    RETURN FALSE;
  END Escape;

  PUBLIC VIRTUAL PROCEDURE GetErrorMsg( VAR ErrorString : ARRAY OF CHAR );
  BEGIN
    ErrorString[0] := CHAR(0C);
  END GetErrorMsg;

  PUBLIC VIRTUAL PROCEDURE GetErrorMsgW( VAR ErrorString : ARRAY OF WCHAR );
  BEGIN
    ErrorString[0] := WCHAR(0C);
  END GetErrorMsgW;

  PUBLIC VIRTUAL PROCEDURE GetProperty( PropertyName         : ARRAY OF CHAR;
                                        VAR PropertyType     : CARDINAL;
                                        PPropertyData        : ADDRESS;
                                        VAR PropertyDataSize : CARDINAL ) : BOOLEAN;
  BEGIN
    RETURN FALSE;
  END GetProperty;

  PUBLIC VIRTUAL PROCEDURE GetPropertyW( PropertyName         : ARRAY OF WCHAR;
                                         VAR PropertyType     : CARDINAL;
                                         PPropertyData        : ADDRESS;
                                         VAR PropertyDataSize : CARDINAL ) : BOOLEAN;
  BEGIN
    RETURN FALSE;
  END GetPropertyW;

  PUBLIC VIRTUAL PROCEDURE SetProperty( PropertyName     : ARRAY OF CHAR;
                                        PropertyType     : CARDINAL;
                                        PPropertyData    : ADDRESS;
                                        PropertyDataSize : CARDINAL ) : BOOLEAN;
  BEGIN
    RETURN FALSE;
  END SetProperty;

  PUBLIC VIRTUAL PROCEDURE SetPropertyW( PropertyName     : ARRAY OF WCHAR;
                                         PropertyType     : CARDINAL;
                                         PPropertyData    : ADDRESS;
                                         PropertyDataSize : CARDINAL ) : BOOLEAN;
  BEGIN
    RETURN FALSE;
  END SetPropertyW;

// PROTECTED members
  VIRTUAL PROCEDURE CommEvent( Mask : BITSET; ErrorCode : CARDINAL );
  VAR
    c : CARDINAL;
    s : CARD32;
  BEGIN
    Mask := Mask * FocusMask;
    IF Mask = {} THEN
      RETURN;
    END;
    s := 1;
    c := 0;
    WHILE (s <> 0) AND (Mask <> {}) DO
      IF BITSET(s) * Mask <> {} THEN
        WITH CommCBArray[ c ] DO
          IF CommCallback <> TCommCallback(NIL) THEN
            CommCallback( CommCallbackParam, c, ErrorCode );
          ELSIF CommCallbackParam <> NIL THEN
            windows.SetEvent( CommCallbackParam );
          END;
        END;
        Mask := Mask - BITSET(s);
      END;
      INC( c );
      s := s << 1;
    END;
  END CommEvent;

BEGIN
  FocusMask := {};
  Storage.Fill( ADR( CommCBArray ), SIZE( CommCBArray ), 0 );
  ALLOCATE( PSHandles, SessionHandles DIV 8 );
  IF PSHandles <> NIL THEN
    Storage.Fill( PSHandles, SessionHandles DIV 8, 0 );
  END;
END CCommLinkStream; (* <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< *)

(* >>> Link Interface >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> *)

CONST
  NOHANDLE = TLinkHandle( NIL );

  // not supported since CW 4.00
  (*/*
  PROCEDURE Init( hLink    : TLinkHandle;
                  Device   : ARRAY OF CHAR;
                  PScanner : TPScanner; 
                  fMultithreadLock, fPrivate : BOOLEAN;
                  VAR ErrorString : ARRAY OF CHAR;
                  VAR hSession : TSessionHandle ) : BOOLEAN;
  */*)


  PROCEDURE Init( hLink       : TLinkHandle;
                  Device      : ARRAY OF CHAR;
                  IniFilePath : ARRAY OF CHAR;
                  fMultithreadLock, fPrivate : BOOLEAN;
                  VAR ErrorString : ARRAY OF CHAR;
                  VAR hSession : TSessionHandle ) : BOOLEAN;
(*%T UNICODE *)
  VAR
    DeviceW       : ARRAY [0..63] OF WCHAR;
    IniFilePathW  : FIO.PathStrW;
    ErrorStringW  : ARRAY [0..1023] OF WCHAR;
    b             : BOOLEAN;
(*%E UNICODE *)
  BEGIN
(*%F UNICODE *)
    IF hLink <> NOHANDLE THEN
      RETURN TPCommLinkStream( hLink )^.Init( Device, IniFilePath, fMultithreadLock, fPrivate, ErrorString, hSession );
    END;
(*%E UNICODE *)
(*%T UNICODE *)
    IF hLink <> NOHANDLE THEN
      Strings.ToW( Device, 0, OUT DeviceW );
      Strings.ToW( IniFilePath, 0, OUT IniFilePathW );
      b := TPCommLinkStream( hLink )^.InitW( DeviceW, IniFilePathW, fMultithreadLock, fPrivate, ErrorStringW, hSession );
      Strings.ToA( ErrorStringW, 0, OUT ErrorString );
      RETURN b;
    END;
(*%E UNICODE *)
    RETURN FALSE;
  END Init;

  PROCEDURE InitW( hLink       : TLinkHandle;
                   Device      : ARRAY OF WCHAR;
                   IniFilePath : ARRAY OF WCHAR;
                   fMultithreadLock, fPrivate : BOOLEAN;
                   VAR ErrorString : ARRAY OF WCHAR;
                   VAR hSession : TSessionHandle ) : BOOLEAN;
  BEGIN
    IF hLink <> NOHANDLE THEN
      RETURN TPCommLinkStream( hLink )^.InitW( Device, IniFilePath, fMultithreadLock, fPrivate, ErrorString, hSession );
    END;
    RETURN FALSE;
  END InitW;

  PROCEDURE Done( hLink    : TLinkHandle;
                  hSession : TSessionHandle );
  BEGIN
    IF hLink <> NOHANDLE THEN
      TPCommLinkStream( hLink )^.DoneSession( hSession );
      TPCommLinkStream( hLink )^.Done();
    END;
  END Done;

  // Priority
  PROCEDURE SetBasePriority( hLink          : TLinkHandle;
                             ThreadPriority : INTEGER );
  BEGIN
    IF hLink <> NOHANDLE THEN
      TPCommLinkStream( hLink )^.SetBasePriority( ThreadPriority );
    END;
  END SetBasePriority;

  // Focus
  PROCEDURE GetCommFocusMask( hLink    : TLinkHandle;
                              VAR Mask : BITSET );
  BEGIN
    IF hLink <> NOHANDLE THEN
      TPCommLinkStream( hLink )^.GetCommFocusMask( Mask );
    END;
  END GetCommFocusMask;

  PROCEDURE SetCommFocus( hLink : TLinkHandle;
                          Event : CARDINAL;
                          fSet  : BOOLEAN );
  BEGIN
    IF hLink <> NOHANDLE THEN
      TPCommLinkStream( hLink )^.SetCommFocus( Event, fSet );
    END;
  END SetCommFocus;

  PROCEDURE SetCommFocusMask( hLink    : TLinkHandle;
                              Mask     : BITSET );
  BEGIN
    IF hLink <> NOHANDLE THEN
      TPCommLinkStream( hLink )^.SetCommFocusMask( Mask );
    END;
  END SetCommFocusMask;

  PROCEDURE GetCommCallback( hLink    : TLinkHandle;
                             Event    : CARDINAL; 
                             VAR CBRoutine : ADDRESS; //TCommCallback;
                             VAR CBParam   : ADDRESS;
                             VAR hSession  : TSessionHandle ) : BOOLEAN;
  BEGIN
    IF hLink <> NOHANDLE THEN
      RETURN TPCommLinkStream( hLink )^.GetCommCallback( Event, CBRoutine, CBParam, hSession );
    ELSE
      RETURN FALSE;
    END;
  END GetCommCallback;

  PROCEDURE SetCommCallback( hLink    : TLinkHandle;
                             hSession : TSessionHandle;
                             Event    : CARDINAL;
                             CBRoutine : TCommCallback; 
                             CBParam   : ADDRESS;
                             fPrivate, fInvisible : BOOLEAN ) : BOOLEAN;
  BEGIN
    IF hLink <> NOHANDLE THEN
      RETURN TPCommLinkStream( hLink )^.SetCommCallback( hSession, Event, CBRoutine, CBParam, fPrivate, fInvisible );
    ELSE
      RETURN FALSE;
    END;
  END SetCommCallback;

  PROCEDURE SetCommCallbackM( hLink    : TLinkHandle;
                              hSession : TSessionHandle;
                              Mask      : BITSET;
                              CBRoutine : TCommCallback; 
                              CBParam   : ADDRESS;
                              fPrivate, fInvisible : BOOLEAN ) : BOOLEAN;
  BEGIN
    IF hLink <> NOHANDLE THEN
      RETURN TPCommLinkStream( hLink )^.SetCommCallbackM( hSession, Mask, CBRoutine, CBParam, fPrivate, fInvisible );
    ELSE
      RETURN FALSE;
    END;
  END SetCommCallbackM;

  // Rx
  PROCEDURE SetRxTimeout( hLink : TLinkHandle;
                          TotalPerByte, TotalConst, Interval : CARDINAL ) : BOOLEAN;
  BEGIN
    IF hLink <> NOHANDLE THEN
      RETURN TPCommLinkStream( hLink )^.SetRxTimeout( TotalPerByte, TotalConst, Interval );
    END;
    RETURN FALSE;
  END SetRxTimeout;

  PROCEDURE RxCount( hLink : TLinkHandle ) : CARDINAL;
  BEGIN
    IF hLink <> NOHANDLE THEN
      RETURN TPCommLinkStream( hLink )^.RxCount();
    END;
    RETURN 0;
  END RxCount;

  PROCEDURE RxFree( hLink : TLinkHandle ) : CARDINAL;
  BEGIN
    IF hLink <> NOHANDLE THEN
      RETURN TPCommLinkStream( hLink )^.RxFree();
    END;
    RETURN 0;
  END RxFree;

  PROCEDURE Receive( hLink : TLinkHandle;
                     PBuf  : ADDRESS; Len : CARDINAL; 
                     MaskRxCharPending : BOOLEAN ) : CARDINAL;
  BEGIN
    IF hLink <> NOHANDLE THEN
      RETURN TPCommLinkStream( hLink )^.Receive( PBuf, Len, MaskRxCharPending );
    END;
    RETURN 0;
  END Receive;

  PROCEDURE PurgeRxBuffer( hLink : TLinkHandle ) : BOOLEAN;
  BEGIN
    IF hLink <> NOHANDLE THEN
      RETURN TPCommLinkStream( hLink )^.PurgeRxBuffer();
    END;
    RETURN FALSE;
  END PurgeRxBuffer;

  // Tx
  PROCEDURE SetTxTimeout( hLink : TLinkHandle;
                          TotalPerByte, TotalConst : CARDINAL ) : BOOLEAN;
  BEGIN
    IF hLink <> NOHANDLE THEN
      RETURN TPCommLinkStream( hLink )^.SetTxTimeout( TotalPerByte, TotalConst );
    END;
    RETURN FALSE;
  END SetTxTimeout;

  PROCEDURE TxCount( hLink : TLinkHandle ) : CARDINAL;
  BEGIN
    IF hLink <> NOHANDLE THEN
      RETURN TPCommLinkStream( hLink )^.TxCount();
    END;
    RETURN 0;
  END TxCount;

  PROCEDURE TxFree( hLink : TLinkHandle ) : CARDINAL;
  BEGIN
    IF hLink <> NOHANDLE THEN
      RETURN TPCommLinkStream( hLink )^.TxFree();
    END;
    RETURN 0;
  END TxFree;

  PROCEDURE Send( hLink : TLinkHandle;
                  PBuf  : ADDRESS; Len : CARDINAL ) : CARDINAL;
  BEGIN
    IF hLink <> NOHANDLE THEN
      RETURN TPCommLinkStream( hLink )^.Send( PBuf, Len );
    END;
    RETURN 0;
  END Send;

  PROCEDURE Flush( hLink : TLinkHandle ) : BOOLEAN;
  BEGIN
    IF hLink <> NOHANDLE THEN
      RETURN TPCommLinkStream( hLink )^.Flush();
    END;
    RETURN FALSE;
  END Flush;

  PROCEDURE PurgeTxBuffer( hLink : TLinkHandle ) : BOOLEAN;
  BEGIN
    IF hLink <> NOHANDLE THEN
      RETURN TPCommLinkStream( hLink )^.PurgeTxBuffer();
    END;
    RETURN FALSE;
  END PurgeTxBuffer;

  // Tools
  PROCEDURE Escape( hLink : TLinkHandle; EscCode : CARDINAL ) : BOOLEAN;
  BEGIN
    IF hLink <> NOHANDLE THEN
      RETURN TPCommLinkStream( hLink )^.Escape( EscCode );
    END;
    RETURN FALSE;
  END Escape;

  PROCEDURE GetErrorMsg( hLink : TLinkHandle; VAR ErrorString : ARRAY OF CHAR );
(*%T UNICODE *)
  VAR
    ES : ARRAY [0..1023] OF WCHAR;
(*%E UNICODE *)
  BEGIN
(*%F UNICODE *)
    IF hLink <> NOHANDLE THEN
      TPCommLinkStream( hLink )^.GetErrorMsg( ErrorString );
    END;
(*%E UNICODE *)
(*%T UNICODE *)
    IF hLink <> NOHANDLE THEN
      TPCommLinkStream( hLink )^.GetErrorMsgW( ES );
      Strings.ToA( ES, 0, OUT ErrorString );
    END;
(*%E UNICODE *)
  END GetErrorMsg;

  PROCEDURE GetErrorMsgW( hLink : TLinkHandle; VAR ErrorString : ARRAY OF WCHAR );
  BEGIN
    IF hLink <> NOHANDLE THEN
      TPCommLinkStream( hLink )^.GetErrorMsgW( ErrorString );
    END;
  END GetErrorMsgW;

  PROCEDURE GetProperty( hLink            : TLinkHandle;
                         PropertyName     : ARRAY OF CHAR;
                         VAR PropertyType : CARDINAL;
                         PPropertyData    : ADDRESS;
                         VAR PropertyDataSize : CARDINAL ) : BOOLEAN;
(*%T UNICODE *)
  VAR
    PropertyNameW : ARRAY [0..63] OF WCHAR;
(*%E UNICODE *)
  BEGIN
(*%F UNICODE *)
    IF hLink <> NOHANDLE THEN
      RETURN TPCommLinkStream( hLink )^.GetProperty( PropertyName, PropertyType, PPropertyData, PropertyDataSize );
    END;
(*%E UNICODE *)
(*%T UNICODE *)
    IF hLink <> NOHANDLE THEN
      Strings.ToW( PropertyName, 0, OUT PropertyNameW );
      RETURN TPCommLinkStream( hLink )^.GetPropertyW( PropertyNameW, PropertyType, PPropertyData, PropertyDataSize );
    END;
(*%E UNICODE *)
    RETURN FALSE;
  END GetProperty;

  PROCEDURE GetPropertyW( hLink            : TLinkHandle;
                          PropertyName     : ARRAY OF WCHAR;
                          VAR PropertyType : CARDINAL;
                          PPropertyData    : ADDRESS;
                          VAR PropertyDataSize : CARDINAL ) : BOOLEAN;
  BEGIN
    IF hLink <> NOHANDLE THEN
      RETURN TPCommLinkStream( hLink )^.GetPropertyW( PropertyName, PropertyType, PPropertyData, PropertyDataSize );
    END;
    RETURN FALSE;
  END GetPropertyW;

  PROCEDURE SetProperty( hLink            : TLinkHandle;
                         PropertyName     : ARRAY OF CHAR;
                         PropertyType     : CARDINAL;
                         PPropertyData    : ADDRESS;
                         PropertyDataSize : CARDINAL ) : BOOLEAN;
(*%T UNICODE *)
  VAR
    PropertyNameW : ARRAY [0..63] OF WCHAR;
(*%E UNICODE *)
  BEGIN
(*%F UNICODE *)
    IF hLink <> NOHANDLE THEN
      RETURN TPCommLinkStream( hLink )^.SetProperty( PropertyName, PropertyType, PPropertyData, PropertyDataSize );
    END;
(*%E UNICODE *)
(*%T UNICODE *)
    IF hLink <> NOHANDLE THEN
      Strings.ToW( PropertyName, 0, OUT PropertyNameW );
      RETURN TPCommLinkStream( hLink )^.SetPropertyW( PropertyNameW, PropertyType, PPropertyData, PropertyDataSize );
    END;
(*%E UNICODE *)
    RETURN FALSE;
  END SetProperty;

  PROCEDURE SetPropertyW( hLink            : TLinkHandle;
                          PropertyName     : ARRAY OF WCHAR;
                          PropertyType     : CARDINAL;
                          PPropertyData    : ADDRESS;
                          PropertyDataSize : CARDINAL ) : BOOLEAN;
  BEGIN
    IF hLink <> NOHANDLE THEN
      RETURN TPCommLinkStream( hLink )^.SetPropertyW( PropertyName, PropertyType, PPropertyData, PropertyDataSize );
    END;
    RETURN FALSE;
  END SetPropertyW;

(* >>> Management Interface >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> *)
CONST
#if PlatformName #startswith L"WinCE" #then
  sNewLinkInstance   = L'NewLinkInstance';
  sFreeLinkInstance  = L'FreeLinkInstance';
#else
  sNewLinkInstance   = C'NewLinkInstance';
  sFreeLinkInstance  = C'FreeLinkInstance';
#endif

  errCANNOT_OPEN_    = 'Cannot open library ';
  errLIBRARY_BAD     = 'Library inconsistent';

(* ---------------------------------------------------------------- *)
TYPE
  TPOpenLinkElem = POINTER TO COpenLinkElem;

CLASS COpenLinkElem( CListElem );
  LibraryName : FIO.PathStrW;
  DeviceName  : ARRAY [0..63] OF WCHAR;
  PDeviceLink : TPCommLinkStream;
  DllHandle   : windows.HANDLE;
  InitCount   : CARDINAL;
  NewInstance : TNewLinkInstance;
  FreeInstance: TFreeLinkInstance;
END COpenLinkElem;

CLASS IMPLEMENTATION COpenLinkElem;
BEGIN
  LibraryName[0] := 0W;
  DeviceName[0]  := 0W;
  PDeviceLink    := NIL;
  DllHandle      := NIL;
  InitCount      := 0;
  NewInstance    := TNewLinkInstance( NIL );
  FreeInstance   := TFreeLinkInstance( NIL );
END COpenLinkElem;
(* ---------------------------------------------------------------- *)

#if #not( PlatformName #startswith L"WinCE" ) #then
  PROCEDURE OpenLink( Library,
                      Device            : ARRAY OF CHAR;
                      PScanner          : ADDRESS;          //TPScanner;
                      fMultithreadLock, 
                      fPrivate          : BOOLEAN;
                      VAR ErrorString   : ARRAY OF CHAR;
                      VAR hLink         : TLinkHandle;
                      VAR hSession      : TSessionHandle ) : BOOLEAN;
  TYPE
  // NEVER CHANGE THIS DECLARATION !!!
    TPPathStr = POINTER TO ARRAY [0..260] OF CHAR;  // compatibility issue
  VAR
    FileName  : FIO.PathStrA;
  BEGIN

(*%T DEBUG *)
  windows.MessageBox( NIL, "cwxlink.OpenLink() used instead of cwxlink.OpendLinkEx()", "Warning!!!", windows.MB_OK );
(*%E DEBUG *)

    IF PScanner <> NIL THEN
      ASSIGN( FileName, TPPathStr( PScanner )^);
      RETURN OpenLinkEx( Library, Device, FileName, fMultithreadLock, fPrivate, ErrorString, hLink, hSession );
    END;
    RETURN FALSE;
  END OpenLink;
#endif

  PROCEDURE OpenLinkEx( Library,
                        Device            : ARRAY OF CHAR;
                        IniFilePath       : ARRAY OF CHAR;
                        fMultithreadLock,
                        fPrivate          : BOOLEAN;
                        VAR ErrorString   : ARRAY OF CHAR;
                        VAR hLink         : TLinkHandle;
                        VAR hSession      : TSessionHandle ) : BOOLEAN;
(*%F UNICODE *)
  VAR
    b   : BOOLEAN;
    c   : CARDINAL;
    PE  : TPOpenLinkElem;
    h   : windows.HANDLE;
    pa  : ADDRESS;
    s, sHead, sTail : FIO.PathStr;
    sPath   : FIO.PathStr;
    sDevice : FIO.PathStr;
    hModule : windows.HINSTANCE;
    Elem    : COpenLinkElem;
(*%E UNICODE *)

(*%T UNICODE *)
  VAR
    DeviceW       : ARRAY [0..63] OF WCHAR;
    LibraryW      : FIO.PathStrW;
    IniFilePathW  : FIO.PathStrW;
    ErrorStringW  : ARRAY [0..1023] OF WCHAR;
    b             : BOOLEAN;
(*%E UNICODE *)
  BEGIN
(*%F UNICODE *)
    hLink := NOHANDLE;

    ASSIGN( sPath, Library );
    ASSIGN( sDevice, Device );
    Str.Lows( sPath );
    Str.Lows( sDevice );
    FIOR.SplitPath( sPath, sHead, sTail );

    IF POpenLinkList = NIL THEN
      NEW( POpenLinkList );
    END;
    b := POpenLinkList^.GetFirst( PE );
    WHILE b AND 
          NOT( (Str.Compare( sTail, PE^.LibraryName ) = 0) AND
               (Str.Compare( sDevice, PE^.DeviceName ) = 0) ) DO
      b := POpenLinkList^.GetNext( PE );
    END;

    IF NOT b THEN  // link does not exist
      h := windows.LoadLibrary( sPath );
      IF h = NIL THEN
        ASSIGN( sPath, 'cwxlink.dll' );
        hModule := windows.GetModuleHandle( sPath );
        IF hModule <> NIL THEN
          IF windows.GetModuleFileName( hModule, s, SIZE( s )) <> 0 THEN
            c := Str.RCharPos( s, '\' );
            IF c = MAX(CARDINAL) THEN
              s[0] := 0C;
            ELSE
              Str.Delete( s, c + 1, MAX( CARDINAL ));
            END;
          ELSE
            s[0] := 0C;
          END;
        ELSE
          s[0] := 0C;
        END;
        FIOR.MakePath( sPath, s, sTail );
        h := windows.LoadLibrary( sPath );
      END;
      IF h = NIL THEN
        Str.Concat( ErrorString, errCANNOT_OPEN_, Library );
        RETURN FALSE;
      END;

      WITH Elem DO
        ASSIGN( LibraryName, sPath );
        ASSIGN( DeviceName, sDevice );
        DllHandle := h;
      END;

      pa := windows.GetProcAddress( h, sNewLinkInstance );
      IF pa = NIL THEN
        windows.FreeLibrary( h );
        ASSIGN( ErrorString, errLIBRARY_BAD );
        RETURN FALSE;
      END;
      Elem.NewInstance := TNewLinkInstance( pa );
      pa := windows.GetProcAddress( h, sFreeLinkInstance );
      IF pa = NIL THEN
        windows.FreeLibrary( h );
        ASSIGN( ErrorString, errLIBRARY_BAD );
        RETURN FALSE;
      END;
      Elem.FreeInstance := TFreeLinkInstance( pa );

      Elem.PDeviceLink := Elem.NewInstance();
      INC( Elem.InitCount );
      b := Elem.PDeviceLink^.Init( Device, IniFilePath,
                                   fMultithreadLock, fPrivate,
                                   ErrorString, hSession );
      IF NOT b THEN
        Elem.FreeInstance( Elem.PDeviceLink );
        windows.FreeLibrary( h );
        RETURN FALSE;
      END;

      NEW( PE );
      PE^ := Elem;
      POpenLinkList^.Append( PE );

    ELSE  // link already exists
      b := PE^.PDeviceLink^.Init( Device, IniFilePath,
                                  fMultithreadLock, fPrivate,
                                  ErrorString, hSession );
      IF b THEN
        INC( PE^.InitCount );
      ELSE
        RETURN FALSE;
      END;
    END;

    hLink := TLinkHandle( PE^.PDeviceLink );  
    RETURN TRUE;
(*%E UNICODE *)

(*%T UNICODE *)
    Strings.ToW( Device, 0, OUT DeviceW );
    Strings.ToW( Library, 0, OUT LibraryW );
    Strings.ToW( IniFilePath, 0, OUT IniFilePathW );
    ErrorStringW[0] := 0W;
    b := OpenLinkExW( LibraryW, DeviceW, IniFilePathW, fMultithreadLock, fPrivate, ErrorStringW, hLink, hSession );
    Strings.ToA( ErrorStringW, 0, OUT ErrorString );
    RETURN b;
(*%E UNICODE *)
  END OpenLinkEx;

  PROCEDURE OpenLinkExW( Library,
                         Device            : ARRAY OF WCHAR;
                         IniFilePath       : ARRAY OF WCHAR;
                         fMultithreadLock,
                         fPrivate          : BOOLEAN;
                         VAR ErrorString   : ARRAY OF WCHAR;
                         VAR hLink         : TLinkHandle;
                         VAR hSession      : TSessionHandle ) : BOOLEAN;
(*%T UNICODE *)
  VAR
    b   : BOOLEAN;
    c   : CARDINAL;
    PE  : TPOpenLinkElem;
    h   : windows.HANDLE;
    pa  : ADDRESS;
    s, sHead, sTail : FIO.PathStrW;
    sPath   : FIO.PathStrW;
    sDevice : FIO.PathStrW;
    hModule : windows.HINSTANCE;
    Elem    : COpenLinkElem;
(*%E UNICODE *)
  BEGIN
(*%F UNICODE *)
    RETURN FALSE;
(*%E UNICODE *)
(*%T UNICODE *)
    hLink := NOHANDLE;

    ASSIGN( sPath, Library );
    ASSIGN( sDevice, Device );
    LOW( sPath );
    LOW( sDevice );
    FIO.SplitPathW( sPath, OUT sHead, OUT sTail );

    IF POpenLinkList = NIL THEN
      NEW( POpenLinkList );
    END;
    b := POpenLinkList^.GetFirst( OUT PE );
    WHILE b AND 
          NOT( EQUALS( sTail, PE^.LibraryName ) AND 
               EQUALS( sDevice, PE^.DeviceName ) ) DO
      b := POpenLinkList^.NextOf( PE, OUT PE );
    END;

    IF NOT b THEN  // link does not exist
      h := windows.LoadLibrary( ADR( sPath ));
      IF h = NIL THEN
        ASSIGN( sPath, 'cwxlink.dll' );
        hModule := windows.GetModuleHandle( ADR( sPath ));
        IF hModule <> NIL THEN
          IF windows.GetModuleFileName( hModule, ADR( s ), SIZE( s )) <> 0 THEN
            c := Strings.LastIndexOfCharW( s, L'\', 0 );
            IF c = MAX(CARDINAL) THEN
              s[0] := 0W;
            ELSE
              Strings.RemoveW( REF s, c + 1, MAX( CARDINAL ));
            END;
          ELSE
            s[0] := 0W;
          END;
        ELSE
          s[0] := 0W;
        END;
        FIO.MakePathW( s, sTail, OUT sPath );
        h := windows.LoadLibrary( ADR( sPath ));
      END;
      IF h = NIL THEN
        Strings.ConcatW( OUT ErrorString, errCANNOT_OPEN_, Library );
        RETURN FALSE;
      END;

      WITH Elem DO
        ASSIGN( LibraryName, sPath );
        ASSIGN( DeviceName, sDevice );
        DllHandle := h;
      END;

      pa := windows.GetProcAddress( h, sNewLinkInstance );
      IF pa = NIL THEN
        windows.FreeLibrary( h );
        ASSIGN( ErrorString, errLIBRARY_BAD );
        RETURN FALSE;
      END;
      Elem.NewInstance := TNewLinkInstance( pa );
      pa := windows.GetProcAddress( h, sFreeLinkInstance );
      IF pa = NIL THEN
        windows.FreeLibrary( h );
        ASSIGN( ErrorString, errLIBRARY_BAD );
        RETURN FALSE;
      END;
      Elem.FreeInstance := TFreeLinkInstance( pa );

      Elem.PDeviceLink := Elem.NewInstance();
      INC( Elem.InitCount );
      b := Elem.PDeviceLink^.InitW( Device, IniFilePath,
                                    fMultithreadLock, fPrivate,
                                    ErrorString, hSession );
      IF NOT b THEN
        Elem.FreeInstance( Elem.PDeviceLink );
        windows.FreeLibrary( h );
        RETURN FALSE;
      END;

      NEW( PE );
      PE^ := Elem;
      POpenLinkList^.Append( PE );

    ELSE  // link already exists
      b := PE^.PDeviceLink^.InitW( Device, IniFilePath,
                                   fMultithreadLock, fPrivate,
                                   ErrorString, hSession );
      IF b THEN
        INC( PE^.InitCount );
      ELSE
        RETURN FALSE;
      END;
    END;

    hLink := TLinkHandle( PE^.PDeviceLink );  
    RETURN TRUE;
(*%E UNICODE *)
  END OpenLinkExW;

  PROCEDURE CloseLink( hLink : TLinkHandle; 
                       hSession : TSessionHandle );
  VAR
    b   : BOOLEAN;
    PE  : TPOpenLinkElem;
  BEGIN
    IF POpenLinkList = NIL THEN
      RETURN;
    END;
    b := POpenLinkList^.GetFirst( OUT PE );
    WHILE b AND (hLink <> TLinkHandle(PE^.PDeviceLink)) DO
      b := POpenLinkList^.NextOf( PE, OUT PE );
    END;
    IF b THEN
      PE^.PDeviceLink^.DoneSession( hSession );
      PE^.PDeviceLink^.Done();
      IF PE^.InitCount = 1 THEN
        POpenLinkList^.Remove( PE );
        PE^.FreeInstance( ADDRESS(PE^.PDeviceLink));
        windows.FreeLibrary( PE^.DllHandle );
        DISPOSE( PE );
      ELSE
        DEC( PE^.InitCount );
      END;
    END;
    IF POpenLinkList^.Empty THEN
      DISPOSE( POpenLinkList );
    END;
  END CloseLink;

END seriallink.