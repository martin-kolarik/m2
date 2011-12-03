IMPLEMENTATION MODULE iface;

(*===========================================================================*)

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   device,
   helper,
   PJLink;

(*===========================================================================*)

CONST
   nDeviceIO = L"IO.Device";

(*===========================================================================*)

CLASS CCreator( helper.ACreator );
   // IObject
   PUBLIC VIRTUAL PROCEDURE OnDispose();
   
   // ILibrary
   PUBLIC VIRTUAL PROCEDURE LibraryInfo( OUT Library, LibraryVersionString : ARRAY OF WCHAR );
   PUBLIC VIRTUAL PROCEDURE EnumerateClasses( REF EnumerateState : PTR; OUT ClassName : ARRAY OF WCHAR ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE GetLECData( OUT cllvData : iobject.TcllvData; OUT cllvPath : ARRAY OF WCHAR ) : BOOLEAN;

   // ACreator
   INTERNAL VIRTUAL PROCEDURE OnFactory( CONST QName : ARRAY OF WCHAR; OUT Object : iobject.TPObject ) : iobject.TResult;
END CCreator;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CCreator;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnDispose();
   BEGIN
   END OnDispose;

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

   PUBLIC VIRTUAL PROCEDURE GetLECData( OUT cllvData : iobject.TcllvData; OUT cllvPath : ARRAY OF WCHAR ) : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END GetLECData;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnFactory( CONST QName : ARRAY OF WCHAR; OUT Object : iobject.TPObject ) : iobject.TResult;
   BEGIN
      IF NOT EQUALS( QName, nDeviceIO ) THEN
         RETURN iobject.lrClassNotFound;
      END;
      Object := ADR( NEW( PJLink.CPJLinkDevice )^.IDevice );
      RETURN iobject.lrSuccess;
   END OnFactory;

(*---------------------------------------------------------------------------*)

END CCreator;

(*===========================================================================*)

VAR
   Creator : CCreator;

PROCEDURE Factory( CONST ClassPath : ARRAY OF WCHAR; OUT Object : iobject.TPObject ) : iobject.TResult;
BEGIN
   RETURN Creator.Factory( ClassPath, OUT Object );
END Factory;

(*===========================================================================*)

END iface.