IMPLEMENTATION MODULE FIOO;

IMPORT
  windows,
  winerror;

(*================================================================================*)

CLASS IMPLEMENTATION CFileStream;

(*--------------------------------------------------------------------------------*)

  PUBLIC FINAL READONLY PROPERTY CanRead GET : BOOLEAN;
  BEGIN
    RETURN ( Handle <> NIL ) AND (( Access = IOO.accRead ) OR ( Access = IOO.accReadWrite ));
  END CanRead;

(*--------------------------------------------------------------------------------*)

  PUBLIC FINAL READONLY PROPERTY CanWrite GET : BOOLEAN;
  BEGIN
    RETURN ( Handle <> NIL ) AND (( Access = IOO.accWrite ) OR ( Access = IOO.accReadWrite ));
  END CanWrite;

(*--------------------------------------------------------------------------------*)

  PUBLIC FINAL READONLY PROPERTY CanSeek GET : BOOLEAN;
  BEGIN
    RETURN Handle <> NIL;
  END CanSeek;

(*--------------------------------------------------------------------------------*)

  PUBLIC FINAL READONLY PROPERTY Long GET : BOOLEAN;
  BEGIN
    RETURN FALSE;
  END Long;

(*--------------------------------------------------------------------------------*)

  PUBLIC FINAL PROPERTY Length GET : CARD64;
  BEGIN
    IF Handle = NIL THEN
      RETURN 0;
    ELSE
      RETURN CARD64( FIO.Size( Handle ));
    END;
  END Length;

(*--------------------------------------------------------------------------------*)

  PUBLIC FINAL PROPERTY Length SET( Value : CARD64 );
  BEGIN
    IF Handle <> NIL THEN
      FIO.Seek( Handle, CARD32( Value ));
      FIO.Truncate( Handle );
    END;
  END Length;

(*--------------------------------------------------------------------------------*)

  PUBLIC FINAL PROPERTY Position GET : CARD64;
  BEGIN
    IF Handle = NIL THEN
      RETURN 0;
    ELSE
      RETURN CARD64( FIO.GetPos( Handle ));
    END;
  END Position;

(*--------------------------------------------------------------------------------*)

  PUBLIC FINAL PROPERTY Position SET( Value : CARD64 );
  BEGIN
    IF Handle <> NIL THEN
      windows.SetFilePointer( Handle, CARD32( Value ), NIL, windows.FILE_BEGIN );
    END;
  END Position;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE FromHandle( Handle : FIO.File; TakeHandleOwnership : BOOLEAN; FileAccess : IOO.TAccess ); // TFileAccess should not colide with Handle access flags
  BEGIN
    Close( FALSE );
    SELF.Handle := Handle;
    IF TakeHandleOwnership THEN
      OwnHandle := TRUE;
    END;
    Access := FileAccess;
  END FromHandle;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE FromPath( CONST Path : ARRAY OF WCHAR; InitMode : TInitMode );
  VAR
    lp : FIO.PathStrW;
  BEGIN
    lp := Path;
    Close( FALSE );
    CASE InitMode OF
    | imOpenRead :
      Handle := windows.CreateFileW( ADR( lp ),
        windows.GENERIC_READ, windows.FILE_SHARE_READ, NIL, windows.OPEN_EXISTING,
        windows.FILE_ATTRIBUTE_NORMAL, NIL );
      Access := IOO.accRead;
    | imOpenOrCreate :
      Handle := windows.CreateFileW( ADR( lp ),
        windows.GENERIC_READ OR windows.GENERIC_WRITE, 0, NIL, windows.OPEN_ALWAYS,
        windows.FILE_ATTRIBUTE_NORMAL, NIL );
      Access := IOO.accReadWrite;
    | imCreate :
      Handle := windows.CreateFileW( ADR( lp ),
        windows.GENERIC_READ OR windows.GENERIC_WRITE, 0, NIL, windows.CREATE_ALWAYS,
        windows.FILE_ATTRIBUTE_NORMAL, NIL );
      Access := IOO.accReadWrite;
    | imAppend :
      Handle := windows.CreateFileW( ADR( lp ),
        windows.GENERIC_READ OR windows.GENERIC_WRITE, 0, NIL, windows.OPEN_ALWAYS,
        windows.FILE_ATTRIBUTE_NORMAL, NIL );
      Seek( IOO.soEnd, 0 );
      Access := IOO.accReadWrite;
    END;
    IF Handle = windows.INVALID_HANDLE_VALUE THEN
      Access := IOO.accUnknown;
      THROW IOO.IOException( NIL, EMITW( %lprocedure ), L"", FIO.IOresult());
    ELSE
      OwnHandle := TRUE;
    END;
  END FromPath;

(*--------------------------------------------------------------------------------*)

  PUBLIC FINAL PROCEDURE Seek( Origin : IOO.TSeekOrigin; Position : INT64 ); 
  BEGIN
    IF Handle = NIL THEN
      RETURN;
    END;
    CASE Origin OF
    | IOO.soBegin :
      windows.SetFilePointer( Handle, CARD32( Position ), NIL, windows.FILE_BEGIN );
    | IOO.soCurrent :
      windows.SetFilePointer( Handle, CARD32( Position ), NIL, windows.FILE_CURRENT );
    | IOO.soEnd :
      windows.SetFilePointer( Handle, CARD32( Position ), NIL, windows.FILE_END );
    END; // CASE
  END Seek;

(*--------------------------------------------------------------------------------*)

  PUBLIC FINAL PROCEDURE Flush();
  BEGIN
    IF Handle <> NIL THEN
      FIO.Flush( Handle );
    END;
  END Flush;

(*--------------------------------------------------------------------------------*)

  PUBLIC FINAL PROCEDURE Close( Persist : BOOLEAN );
  BEGIN
    AbortReading();
    AbortWriting();
    IF Handle <> NIL THEN
      FIO.Flush( Handle );
      IF NOT Persist THEN
        IF OwnHandle THEN
          FIO.Close( Handle );
        END;
        Handle := NIL;
        OwnHandle := FALSE;
        Access := IOO.accUnknown;
      END;
    END;
  END Close;
  
(*--------------------------------------------------------------------------------*)

   INTERNAL FINAL PROCEDURE Start( Direction : IOO.TDirection; OperationTimeoutMS : CARDINAL ) : Sync.TAsyncResult;
   VAR
      A : ADDRESS;
      L1, L2 : CARDINAL;
      Result : Sync.TAsyncResult := Sync.arCompleted;
   BEGIN
      IF Handle = NIL THEN
         RETURN Sync.arCannotStart;
      END;
      WHILE DevicePrepareData( Direction, OUT A, OUT L1 ) DO
         IF Direction = IOO.dirRead THEN
            L2 := FIO.RdBin( Handle, A^, L1 );
            IF L2 = 0 THEN
               CASE CARDINAL( windows.GetLastError()) OF
               | winerror.ERROR_HANDLE_EOF, // by documentation
                 winerror.ERROR_BROKEN_PIPE, // by documentation
                 winerror.ERROR_INVALID_HANDLE : // by reality
                  Result := Sync.arNoData;
               ELSE
                  Result := Sync.arAborted;
               END;
            END;
         ELSE
            L2 := FIO.WrBin( Handle, A^, L1 );
            IF L2 < L1 THEN
               Result := Sync.arAborted;
            END;
         END;
         DeviceCompleteData( Direction, L2 );
         IF L2 < L1 THEN
            EXIT;
         END;
      END; // WHILE
      DeviceFinish( Direction, Result );
      RETURN Result;
   END Start;

(*--------------------------------------------------------------------------------*)

  INTERNAL FINAL PROCEDURE Abort( Direction : IOO.TDirection );
  BEGIN
    DeviceFinish( Direction, Sync.arAborted );
  END Abort;

(*--------------------------------------------------------------------------------*)

BEGIN
  Access := IOO.accUnknown;
  Handle := NIL;
  OwnHandle := FALSE;
FINALLY
  Close( FALSE );
END CFileStream;

(*================================================================================*)

VAR
   fsstdin : CFileStream;
   fsstdout : CFileStream;
   fserrout : CFileStream;

(*--------------------------------------------------------------------------------*)

PROCEDURE stdin() : TPFileStream;
BEGIN
   IF fsstdin.Handle = NIL THEN
      fsstdin.FromHandle( windows.GetStdHandle( windows.STD_INPUT_HANDLE ), FALSE, IOO.accRead );
   END;
   RETURN ADR( fsstdin );
END stdin;

(*--------------------------------------------------------------------------------*)

PROCEDURE stdout() : TPFileStream;
BEGIN
   IF fsstdout.Handle = NIL THEN
      fsstdout.FromHandle( windows.GetStdHandle( windows.STD_OUTPUT_HANDLE ), FALSE, IOO.accWrite );
   END;
   RETURN ADR( fsstdout );
END stdout;

(*--------------------------------------------------------------------------------*)

PROCEDURE errout() : TPFileStream;
BEGIN
   IF fserrout.Handle = NIL THEN
      fserrout.FromHandle( windows.GetStdHandle( windows.STD_ERROR_HANDLE ), FALSE, IOO.accWrite );
   END;
   RETURN ADR( fserrout );
END errout;

(*================================================================================*)

END FIOO.
