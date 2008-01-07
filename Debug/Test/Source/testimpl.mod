IMPLEMENTATION MODULE testimpl;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;
   
IMPORT
   iobject,
   lists,
   helper,
   StringsO;

(*================================================================================*)

CONST
   ctestClass = L"Development.Tests";

(*================================================================================*)
// abstract helper implementations -- implementor can directly use the class, the only thing he
// must do it to export Factory procedure and instantiate the class

CLASS CTests( helper.ACreator ) IMPLEMENTS test.ITests;
   PRIVATE VAR
      Tests : lists.CPtrList;

   // ITests/IObject
   PUBLIC FINAL READONLY PROPERTY
      Type : iobject.TObjectType;
   PUBLIC FINAL PROPERTY
      Library : iobject.TPLibrary;

   // part of ILibrary
   PUBLIC VIRTUAL PROCEDURE EnumerateClasses( REF EnumerateState : PTR; OUT ClassName : ARRAY OF WCHAR ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE GetLECData( OUT cllvData : iobject.TcllvData; OUT cllvPath : ARRAY OF WCHAR ) : BOOLEAN;

   // ITests
   PUBLIC VIRTUAL PROCEDURE TestFactory( CONST ClassPath : ARRAY OF WCHAR; OUT Object : iobject.TPObject ) : CARDINAL;
   PUBLIC VIRTUAL PROCEDURE EnumerateTests( REF ES : PTR; OUT Name : ARRAY OF WCHAR; OUT Test : test.TPTest ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE AddTest( CONST Name : ARRAY OF WCHAR; Test : test.TPTest );

   // CTests
   PUBLIC VIRTUAL PROCEDURE Dispose();

   // ACreator
   PUBLIC VIRTUAL PROCEDURE LibraryInfo( OUT Library, LibraryVersionString : ARRAY OF WCHAR );
   VIRTUAL PROCEDURE OnFactory( CONST QName : ARRAY OF WCHAR; OUT Object : iobject.TPObject ) : iobject.TResult;
END CTests;

(*================================================================================*)

CLASS IMPLEMENTATION CTests;

(*--------------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY Type GET : iobject.TObjectType;
   BEGIN
      RETURN iobject.otSingleton;
   END Type;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY Library GET : iobject.TPLibrary;
   BEGIN
      RETURN SUPER.Library;
   END Library;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY Library SET( Value : iobject.TPLibrary );
   BEGIN
      SUPER.Library := Value;
   END Library;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE EnumerateClasses( REF EnumerateState : PTR; OUT ClassName : ARRAY OF WCHAR ) : BOOLEAN;
   BEGIN
      IF EnumerateState > 0 THEN
         RETURN FALSE;
      END;
      ClassName := ctestClass;
      RETURN TRUE;
   END EnumerateClasses;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE GetLECData( OUT cllvData : iobject.TcllvData; OUT cllvPath : ARRAY OF WCHAR ) : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END GetLECData;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE TestFactory( CONST ClassPath : ARRAY OF WCHAR; OUT Object : iobject.TPObject ) : CARDINAL;
   BEGIN
      IF ClassPath = L"" THEN
         RETURN CARDINAL( Factory( ctestClass, OUT Object ));
      ELSE
         RETURN CARDINAL( Factory( ClassPath, OUT Object ));
      END;
   END TestFactory;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE EnumerateTests( REF ES : PTR; OUT Name : ARRAY OF WCHAR; OUT Test : test.TPTest ) : BOOLEAN;
   VAR
      _S : StringsO.TPString;
      _Test : test.TPTest;
      b : BOOLEAN;
   BEGIN
      IF ES = 0 THEN
         b := Tests.GetFirst( OUT _Test, OUT _S );
      ELSE
         b := Tests.NextOf( ES, OUT _Test, OUT _S );
      END;
      IF b THEN
         ES := _Test;
         Test := _Test;
         _S^.ToOA( OUT Name );
      END;
      RETURN b;
   END EnumerateTests;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE AddTest( CONST Name : ARRAY OF WCHAR; Test : test.TPTest );
   VAR
      S : StringsO.TPString;
   BEGIN
      IF Tests.Contains( Test ) THEN
         RETURN;
      END;
      S := NEW( StringsO.CString );
      S^.FromOA( Name );
      Tests.Add( Test, S );
   END AddTest;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   VAR
      _S : POINTER TO StringsO.CString;
   BEGIN
      Tests.Reset();
      WHILE Tests.MoveNext() DO
         _S := Tests.CurrentData;
         DISPOSE( _S );
      END; // WHILE
      Tests.Dispose();
      SUPER.Dispose();
   END Dispose;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE LibraryInfo( OUT Library, LibraryVersionString : ARRAY OF WCHAR );
   BEGIN
      Library := ProductId;
      LibraryVersionString := ProductVersion;
   END LibraryInfo;

(*---------------------------------------------------------------------------*)

   VIRTUAL PROCEDURE OnFactory( CONST QName : ARRAY OF WCHAR; OUT Object : iobject.TPObject ) : iobject.TResult;
   BEGIN
      IF EQUALS( QName, ctestClass ) THEN
         Object := ADR( ITests );
         RETURN iobject.lrSuccess;
      ELSE
         RETURN iobject.lrClassNotFound;
      END;
   END OnFactory;

(*--------------------------------------------------------------------------------*)

END CTests;

(*================================================================================*)

VAR
   Tests : POINTER TO CTests := NIL;

(*---------------------------------------------------------------------------*)

PROCEDURE tests() : test.TPTests;
BEGIN
   IF Tests = NIL THEN
      NEW( Tests );
   END;
   RETURN Tests;
END tests;

(*================================================================================*)

END testimpl.