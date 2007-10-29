IMPLEMENTATION MODULE iface;

(*===========================================================================*)

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   device,
   Midea;

(*===========================================================================*)

CONST
   nDeviceIO = L"IO.Device";

(*===========================================================================*)

CLASS CCreator( objlib.ACreator );
   PUBLIC VIRTUAL PROCEDURE LibraryInfo( OUT Library, LibraryVersionString : ARRAY OF WCHAR );
   PUBLIC VIRTUAL PROCEDURE EnumerateClasses( REF EnumerateState : PTR; OUT ClassName : ARRAY OF WCHAR ) : BOOLEAN;

   PUBLIC VIRTUAL PROCEDURE GetLECData( OUT cllvData : objlib.TcllvData; OUT cllvPath : ARRAY OF WCHAR ) : BOOLEAN;

   INTERNAL VIRTUAL PROCEDURE OnFactory( CONST QName : ARRAY OF WCHAR; OUT Object : objlib.TPObject ) : objlib.TResult;
END CCreator;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CCreator;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE LibraryInfo( OUT Library, LibraryVersionString : ARRAY OF WCHAR );
   BEGIN
      Library := ProductId;
      LibraryVersionString := ProductVersion;
   END LibraryInfo;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE EnumerateClasses( REF EnumerateState : PTR; OUT ClassName : ARRAY OF WCHAR ) : BOOLEAN;
   BEGIN
      IF EnumerateState > 0 THEN
         RETURN FALSE;
      END;
      ClassName := nDeviceIO;
      RETURN TRUE;
   END EnumerateClasses;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE GetLECData( OUT cllvData : objlib.TcllvData; OUT cllvPath : ARRAY OF WCHAR ) : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END GetLECData;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnFactory( CONST QName : ARRAY OF WCHAR; OUT Object : objlib.TPObject ) : objlib.TResult;
   BEGIN
      IF NOT EQUALS( QName, nDeviceIO ) THEN
         RETURN objlib.lrClassNotFound;
      END;
      Object := ADR( NEW( Midea.CMideaDevice )^.IDevice );
      RETURN objlib.lrSuccess;
   END OnFactory;

(*---------------------------------------------------------------------------*)

END CCreator;

(*===========================================================================*)

VAR
   Creator : CCreator;

PROCEDURE Factory( CONST ClassPath : ARRAY OF WCHAR; OUT Object : objlib.TPObject ) : objlib.TResult;
BEGIN
   RETURN Creator.Factory( ClassPath, OUT Object );
END Factory;

(*===========================================================================*)

END iface.