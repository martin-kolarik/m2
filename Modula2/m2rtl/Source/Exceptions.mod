IMPLEMENTATION MODULE Exceptions;
// Modula2 Exceptions handling module

IMPORT
   Languages,
   Rtti,
   Storage,
   Strings,
   Sync,
   windows;

//--------------------------------------------------------------------------------

TYPE
   TPException = POINTER TO Exception;

CLASS IMPLEMENTATION Exception;

   INTERNAL VIRTUAL PROCEDURE FormatCode( OUT S : ARRAY OF WCHAR );
   VAR
      N : ARRAY [0..7] OF WCHAR;
   BEGIN
      S := L" (code ";
      Strings.FromCARD32W( CARDINAL( Code ), 10, OUT N );
      Strings.AppendW( REF S, N );
      Strings.AppendW( REF S, L")" );
   END FormatCode;

   PUBLIC VIRTUAL PROCEDURE Name( OUT S : ARRAY OF WCHAR );
   BEGIN
      Strings.ToW( OAsz( Rtti.TPRTTI( RTTI( SELF ))^.Name ), Languages.cp_ACP, OUT S );
   END Name;

   PUBLIC VIRTUAL PROCEDURE ToString( OUT S : ARRAY OF WCHAR );
   VAR
      N : ARRAY [0..127] OF WCHAR;
   BEGIN
      IF NestedException = NIL THEN
         Name( OUT N ); Strings.AppendW( REF S, N );
         FormatCode( OUT N ); Strings.AppendW( REF S, N );
      ELSE
         NestedException^.ToString( OUT S );
         Strings.AppendW( REF S, L" in " );
         Name( OUT N ); Strings.AppendW( REF S, N );
      END;
   END ToString;

BEGIN
END Exception;

//--------------------------------------------------------------------------------

CLASS IMPLEMENTATION CGenericException;

   PUBLIC PROCEDURE Init( Code : CARDINAL; NestedException : POINTER TO Exception; CONST Originator, Text : ARRAY OF WCHAR ) : CGenericException;
   BEGIN
      SELF.Code := Code;
      SELF.NestedException := NestedException;
      ASSIGN( SELF.Text, Text );
      ASSIGN( SELF.Originator, Originator );
      RETURN SELF;
   END Init;

   PUBLIC VIRTUAL PROCEDURE ToString( OUT S : ARRAY OF WCHAR );
   BEGIN
      SUPER.ToString( OUT S );
      IF Originator[0] <> 0W THEN
         Strings.AppendW( REF S, L" [" );
         Strings.AppendW( REF S, Originator );
         Strings.AppendW( REF S, L"] " );
      END;
      IF Text[0] <> 0W THEN
         Strings.AppendW( REF S, L": " );
         Strings.AppendW( REF S, Text );
      END;
   END ToString;

BEGIN
   Text := L"";
   Originator := L"";
END CGenericException;

//--------------------------------------------------------------------------------

PROCEDURE GenericException( Code : CARDINAL; NestedException : POINTER TO Exception; CONST Originator, Text : ARRAY OF WCHAR ) : CGenericException;
VAR
	CE : CGenericException;
BEGIN
	RETURN CE.Init( Code, NestedException, Originator, Text );
END GenericException;

//--------------------------------------------------------------------------------

CLASS IMPLEMENTATION CModula2Exception;

   INTERNAL VIRTUAL PROCEDURE FormatCode( OUT S : ARRAY OF WCHAR );
   BEGIN
      CASE Kind OF
      | mexOutOfArrayIndex :
         S := "(OutOfArrayIndex)";
      | mexProcedureNotImplemented :
         S := "(ProcedureNotImplemented)";
      | mexMethodNotImplemented :
         S := "(MethodNotImplemented)";
      | mexNotSupported :
         S := "(NotSupported)";
      | mexInvalidParameter :
         S := "(InvalidParameter)";
      | mexInvalidObjectState :
         S := "(InvalidObjectState)";
      ELSE
         SUPER.FormatCode( OUT S );
      END;
   END FormatCode;

   PUBLIC PROCEDURE Init( NestedException : POINTER TO Exception; CONST Originator, Text : ARRAY OF WCHAR; Kind : TModula2Exception ) : CModula2Exception;
   BEGIN
      SELF.Kind := Kind;
      SUPER.Init( 0, NestedException, Originator, Text );
      RETURN SELF;
   END Init;

BEGIN
   Kind := mexNotSupported;
END CModula2Exception;

//--------------------------------------------------------------------------------

PROCEDURE Modula2Exception( NestedException : POINTER TO Exception; CONST Originator, Text : ARRAY OF WCHAR; Exception : TModula2Exception ) : CModula2Exception;
VAR
	M2E : CModula2Exception;
BEGIN
	RETURN M2E.Init( NestedException, Originator, Text, Exception );
END Modula2Exception;

// #save, option( dll_export => on )

(*================================================================================*)
// system support

TYPE
   TExceptionInfo  = RECORD
                        rtti : Rtti.TPRTTI;
                        storageLength : CARDINAL;
                        storage : ADDRESS;
                     END;
   TPExceptionInfo = POINTER TO TExceptionInfo;

CLASS CExceptionHandler;
   PRIVATE VAR
      Lock : Sync.LOCK;
      TlsAllocated : BOOLEAN;
      TlsIndex : CARDINAL;
      Heap : PTR;
      
   LOCAL PROCEDURE StoreException( Source : POINTER TO Exception );
   LOCAL PROCEDURE IsCatchedBy( catchRtti : ADDRESS ) : BOOLEAN;
   LOCAL PROCEDURE RetrieveException() : POINTER TO Exception;
END CExceptionHandler;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CExceptionHandler;
      
(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE StoreException( Source : POINTER TO Exception );
   VAR
      ExceptionInfo : TPExceptionInfo;
      rtti : Rtti.TPRTTI;
   BEGIN
      IF Source = NIL THEN
         RETURN;
      END;
      rtti := RTTI( Source^ );
   
      Lock.Lock();
      IF NOT TlsAllocated THEN
         TlsAllocated := TRUE;
         TlsIndex := windows.TlsAlloc();
      END;
      Lock.Unlock();
      
      ExceptionInfo := TPExceptionInfo( windows.TlsGetValue( TlsIndex ));
      IF ExceptionInfo = NIL THEN // this is a documented inital value too

         IF NOT Storage.HeapAllocate( Heap, OUT ExceptionInfo, SIZE( TExceptionInfo )) THEN
            RETURN;
         END;
         ExceptionInfo^.rtti := NIL;
         ExceptionInfo^.storageLength := 0;
         ExceptionInfo^.storage := NIL;

         windows.TlsSetValue( TlsIndex, ExceptionInfo );
      END;

      ExceptionInfo^.rtti := rtti;
      IF rtti^.ClassSize > ExceptionInfo^.storageLength THEN
         ExceptionInfo^.storageLength := ( rtti^.ClassSize + 127 ) AND 0FFFFFF80H;
         IF NOT Storage.HeapReallocate( Heap, REF ExceptionInfo^.storage, ExceptionInfo^.storageLength ) THEN
            ExceptionInfo^.rtti := NIL;
            RETURN;
         END;
      END;

      Storage.Move( Source, ExceptionInfo^.storage, ExceptionInfo^.storageLength );
   END StoreException;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE IsCatchedBy( catchRtti : ADDRESS ) : BOOLEAN;
   VAR
      ExceptionInfo : TPExceptionInfo;
   BEGIN
      IF NOT TlsAllocated THEN
         RETURN FALSE;
      END;
      ExceptionInfo := TPExceptionInfo( windows.TlsGetValue( TlsIndex ));
      IF ( ExceptionInfo = NIL ) OR ( ExceptionInfo^.rtti = NIL ) THEN
         RETURN FALSE;
      ELSIF TPException( ExceptionInfo^.storage )^ IS LOOSE RTTI catchRtti THEN
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END IsCatchedBy;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE RetrieveException() : POINTER TO Exception;
   VAR
      ExceptionInfo : TPExceptionInfo;
   BEGIN
      IF NOT TlsAllocated THEN
         RETURN NIL;
      END;
      ExceptionInfo := TPExceptionInfo( windows.TlsGetValue( TlsIndex ));
      RETURN TPException( ExceptionInfo^.storage );
   END RetrieveException;

(*--------------------------------------------------------------------------------*)

BEGIN
   TlsAllocated := FALSE;
   TlsIndex := 0;
   Storage.CreateHeap( OUT Heap );
FINALLY
   IF TlsAllocated THEN
      windows.TlsFree( TlsIndex );
      TlsAllocated := FALSE;
   END;
   Storage.DisposeHeap( OUT Heap );
END CExceptionHandler;

(*--------------------------------------------------------------------------------*)

VAR
   ExceptionHandler : CExceptionHandler;

PROCEDURE THROW_( Source : POINTER TO Exception );
BEGIN
   ExceptionHandler.StoreException( Source );
END THROW_;

PROCEDURE CATCHED_( catchRtti : ADDRESS ) : BOOLEAN;
BEGIN
   RETURN ExceptionHandler.IsCatchedBy( catchRtti );
END CATCHED_;

PROCEDURE RETRIEVE_() : ADDRESS;
BEGIN
   RETURN ExceptionHandler.RetrieveException();
END RETRIEVE_;

(*================================================================================*)

// #restore

END Exceptions.
