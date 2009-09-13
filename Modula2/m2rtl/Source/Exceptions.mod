IMPLEMENTATION MODULE Exceptions;
// Modula2 Exceptions handling module

IMPORT
   Rtti,
   Storage,
   Strings,
   Sync,
   windows;

//--------------------------------------------------------------------------------

TYPE
   TPException = POINTER TO Exception;

CLASS IMPLEMENTATION Exception;
BEGIN
END Exception;

//--------------------------------------------------------------------------------

CLASS IMPLEMENTATION CException;

   PUBLIC PROCEDURE Init( NestedException : POINTER TO Exception; CONST Originator, Text : ARRAY OF WCHAR ) : CException;
   BEGIN
      SELF.NestedException := NestedException;
      ASSIGN( SELF.Text, Text );
      ASSIGN( SELF.Originator, Originator );
      RETURN SELF;
   END Init;

   PUBLIC VIRTUAL PROCEDURE ToString( OUT S : ARRAY OF WCHAR );
   VAR
      N : ARRAY [0..127] OF WCHAR;
   BEGIN
      IF NestedException = NIL THEN
         S := L"";
      ELSE
         NestedException^.ToString( OUT S );
         Strings.AppendW( REF S, L" in " );
      END;
      IF Originator[0] <> 0W THEN
         Strings.AppendW( REF S, L"[" );
         Strings.AppendW( REF S, Originator );
         Strings.AppendW( REF S, L"] " );
      END;
      Name( OUT N ); Strings.AppendW( REF S, N );
      IF Text[0] <> 0W THEN
         Strings.AppendW( REF S, L": " );
         Strings.AppendW( REF S, Text );
      END;
   END ToString;

   INTERNAL VIRTUAL PROCEDURE Name( OUT S : ARRAY OF WCHAR );
   BEGIN
      ASSIGN( S, EMITW( %class ));
   END Name;

BEGIN
   Text := L"";
   Originator := L"";
END CException;

//--------------------------------------------------------------------------------

PROCEDURE GenericException( NestedException : POINTER TO Exception; CONST Originator, Text : ARRAY OF WCHAR ) : CException;
VAR
	CE : CException;
BEGIN
	RETURN CE.Init( NestedException, Originator, Text );
END GenericException;

//--------------------------------------------------------------------------------

CLASS IMPLEMENTATION CModula2Exception;

   PUBLIC PROCEDURE Init( NestedException : POINTER TO Exception; CONST Originator, Text : ARRAY OF WCHAR; Kind : TModula2Exception ) : CModula2Exception;
   BEGIN
      SELF.Kind := Kind;
      SUPER.Init( NestedException, Originator, Text );
      RETURN SELF;
   END Init;

   INTERNAL VIRTUAL PROCEDURE Name( OUT S : ARRAY OF WCHAR );
   BEGIN
      ASSIGN( S, EMITW( %class ));
   END Name;

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
      // rtti := RTTI( Source^ );
      rtti := NIL;
   
      Lock.Lock();
      IF NOT TlsAllocated THEN
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
      ELSIF ( TPException( ExceptionInfo^.storage )^ IS Exception ) OR ( TPException( ExceptionInfo^.storage )^ INHERITS Exception ) THEN
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
