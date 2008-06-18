IMPLEMENTATION MODULE DiskInfo;

IMPORT
  windows,
  winioctl;

IMPORT
  FIO,
  Strings,
  Storage;

TYPE
  IDSECTOR = RECORD
               wGenConfig                 : CARD16;
               wNumCyls                   : CARD16;
               wReserved                  : CARD16;
               wNumHeads                  : CARD16;
               wBytesPerTrack             : CARD16;
               wBytesPerSector            : CARD16;
               wSectorsPerTrack           : CARD16;
               wVendorUnique              : ARRAY [0..2] OF CARD16;
               sSerialNumber              : ARRAY [0..19] OF CHAR;
               wBufferType                : CARD16;
               wBufferSize                : CARD16;
               wECCSize                   : CARD16;
               sFirmwareRev               : ARRAY [0..7] OF CHAR;
               sModelNumber               : ARRAY [0..39] OF CHAR;
               wMoreVendorUnique          : CARD16;
               wDoubleWordIO              : CARD16;
               wCapabilities              : CARD16;
               wReserved1                 : CARD16;
               wPIOTiming                 : CARD16;
               wDMATiming                 : CARD16;
               wBS                        : CARD16;
               wNumCurrentCyls            : CARD16;
               wNumCurrentHeads           : CARD16;
               wNumCurrentSectorsPerTrack : CARD16;
               ulCurrentSectorCapacity    : CARD32;
               wMultSectorStuff           : CARD16;
               ulTotalAddressableSectors  : CARD32;
               wSingleWordDMA             : CARD16;
               wMultiWordDMA              : CARD16;
               bReserved                  : ARRAY [0..127] OF BYTE;
             END;

CLASS IMPLEMENTATION CDiskInfo;
END CDiskInfo;

CLASS CDiskInfoQuery;
  LOCAL PROCEDURE LoadDiskInfo( DiskNumber : CARDINAL; OUT DiskInfo : CDiskInfo ) : BOOLEAN;
END CDiskInfoQuery;

CLASS IMPLEMENTATION CDiskInfoQuery;

  LOCAL PROCEDURE LoadDiskInfo( DiskNumber : CARDINAL; OUT DiskInfo : CDiskInfo ) : BOOLEAN;
  CONST
    // ID_ATAPI_IDENTIFY = 0A1H;
    ID_ATA_IDENTIFY = 0ECH;
  LABEL
    Failure;
  TYPE
    TPIDSECTOR = POINTER TO IDSECTOR;
  VAR
    c : CARDINAL;
    Disk : FIO.File := NIL;
    DriveNumber : ARRAY [0..3] OF WCHAR;
    DrivePath : ARRAY [0..31] OF WCHAR;
    i : CARDINAL;
    IdentifyCmdOut : ARRAY [0..511 + winioctl.IDENTIFY_BUFFER_SIZE] OF BYTE;
    PIDSECTOR : TPIDSECTOR;
    pw : PWORD;
    SendCmdIn : winioctl.SENDCMDINPARAMS;
    SendCmdOut : winioctl.SENDCMDOUTPARAMS;
    Version : winioctl.GETVERSIONINPARAMS;
  BEGIN
    Strings.FromCARD32W( DiskNumber, 10, OUT DriveNumber );
    Strings.ConcatW( OUT DrivePath, L"\\.\PhysicalDrive", DriveNumber );
    Disk := FIO.OpenW( DrivePath, FIO.TFileShare{FIO.fsRead, FIO.fsWrite, FIO.fsDelete} ); // works on XP
    IF Disk = NIL THEN
      RETURN FALSE;
    END;

    
    // check if SMART can be used
		IF windows.DeviceIoControl(
		     Disk, winioctl.SMART_GET_VERSION,
		     NIL, 0, ADR( Version ), SIZE( Version ),
		     ADR( c ), NIL ) <> windows.True THEN
		  c := windows.GetLastError();
		  GOTO Failure;
		END;

    // enable SMART, if it is not already enabled
		Storage.Zero( ADR( SendCmdIn ), SIZE( SendCmdIn ));
		WITH SendCmdIn DO
			cBufferSize := 0;
			WITH SendCmdIn.irDriveRegs DO // commented are not needed for SMART_CMD
				bFeaturesReg := winioctl.ENABLE_SMART;
				// bSectorCountReg := 1;
				// bSectorNumberReg := 1;
				bCylLowReg := winioctl.SMART_CYL_LOW;
				bCylHighReg := winioctl.SMART_CYL_HI;
				// bDriveHeadReg := 0A0H;
        bCommandReg := winioctl.SMART_CMD;
      END; // WITH
		END; // WITH
		SendCmdOut.cBufferSize := 0;
		IF windows.DeviceIoControl(
		     Disk, winioctl.SMART_SEND_DRIVE_COMMAND,
		     ADR( SendCmdIn ), SIZE( SendCmdIn ) - SIZE( SendCmdIn.bBuffer ), ADR( SendCmdOut ), SIZE( SendCmdOut ) - SIZE( SendCmdOut.bBuffer ),
		     ADR( c ), NIL ) <> windows.True THEN
		  c := windows.GetLastError();
		  GOTO Failure;
		END;

    // read data
		Storage.Zero( ADR( SendCmdIn ), SIZE( SendCmdIn ));
		WITH SendCmdIn DO
			cBufferSize := winioctl.IDENTIFY_BUFFER_SIZE;
			WITH SendCmdIn.irDriveRegs DO // commented are not needed for SMART_CMD
				bFeaturesReg := winioctl.ENABLE_SMART;
				// bSectorCountReg := 1;
				// bSectorNumberReg := 1;
				bCylLowReg := winioctl.SMART_CYL_LOW;
				bCylHighReg := winioctl.SMART_CYL_HI;
				// bDriveHeadReg := 0A0H;
        bCommandReg := ID_ATA_IDENTIFY;
      END; // WITH
		END; // WITH
		SendCmdOut.cBufferSize := 0;
		IF windows.DeviceIoControl(
		     Disk, winioctl.SMART_RCV_DRIVE_DATA,
		     ADR( SendCmdIn ), SIZE( SendCmdIn ) - SIZE( SendCmdIn.bBuffer ), ADR( IdentifyCmdOut ), SIZE( IdentifyCmdOut ),
		     ADR( c ), NIL ) <> windows.True THEN
		  c := windows.GetLastError();
		  GOTO Failure;
		END;
		
		PIDSECTOR := TPIDSECTOR( ADR( IdentifyCmdOut )@[SIZE(winioctl.SENDCMDOUTPARAMS)-SIZE(winioctl.SENDCMDOUTPARAMS.bBuffer)] );

		// swap bytes in serial number
		pw := PWORD( ADR( PIDSECTOR^.sSerialNumber ));
		FOR i := 0 TO HIGH( PIDSECTOR^.sSerialNumber ) DIV 2 DO
			pw^ := REVERSE( pw^ );
			INC( pw, SIZE( WORD ));
		END; // FOR
		// swap bytes in model number
		pw := PWORD( ADR( PIDSECTOR^.sModelNumber ));
		FOR i := 0 TO HIGH( PIDSECTOR^.sModelNumber ) DIV 2 DO
			pw^ := REVERSE( pw^ );
			INC( pw, SIZE( WORD ));
		END; // FOR
		// swap bytes in firmware rev
		pw := PWORD( ADR( PIDSECTOR^.sFirmwareRev ));
		FOR i := 0 TO HIGH( PIDSECTOR^.sFirmwareRev ) DIV 2 DO
			pw^ := REVERSE( pw^ );
			INC( pw, SIZE( WORD ));
		END; // FOR
		
		DiskInfo.Serial.FromOAA( 0, PIDSECTOR^.sSerialNumber );
		DiskInfo.Model.FromOAA( 0, PIDSECTOR^.sModelNumber );
		DiskInfo.Firmware.FromOAA( 0, PIDSECTOR^.sFirmwareRev );

    FIO.Close( Disk );
    RETURN TRUE;
  Failure:
    FIO.Close( Disk );
    RETURN FALSE;
  END LoadDiskInfo;

END CDiskInfoQuery;

PROCEDURE LoadDiskInfo( DiskNumber : CARDINAL; OUT DiskInfo : CDiskInfo ) : BOOLEAN;
VAR
  Q : CDiskInfoQuery;
BEGIN
  RETURN Q.LoadDiskInfo( DiskNumber, OUT DiskInfo );
END LoadDiskInfo;

END DiskInfo.