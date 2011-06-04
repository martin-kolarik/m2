IMPLEMENTATION MODULE testimpl;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;
   
IMPORT
   baseobject,
   collection,
   iplugin,
   lists,
   helper,
   StringsO;

(*================================================================================*)

CONST
   ctestClass = L"Development.Tests";

(*================================================================================*)

CLASS CTestIterator( lists.CPtrListIterator ) IMPLEMENTS test.ITestIterator;

   // collection.IIterator
   PUBLIC VIRTUAL READONLY PROPERTY
      colCurrent : baseobject.PBASE;

   PUBLIC VIRTUAL PROCEDURE Reset();
   PUBLIC VIRTUAL PROCEDURE MoveNext() : BOOLEAN;

   PUBLIC VIRTUAL READONLY PROPERTY
      Implementor : baseobject.TPDisposable; // the object to be disposed, when TPIterator is to be disposed (interface cannot be disposed)
      OfCollection : collection.TPCollection;

   // ITestIterator
   PUBLIC VIRTUAL PROCEDURE
      Name( OUT name : ARRAY OF WCHAR );
   PUBLIC VIRTUAL READONLY PROPERTY
      Test : test.TPTest;

END CTestIterator;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CTestIterator;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY colCurrent GET : baseobject.PBASE;
   BEGIN
      RETURN SUPER.colCurrent;
   END colCurrent;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Reset();
   BEGIN
      SUPER.Reset();
   END Reset;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE MoveNext() : BOOLEAN;
   BEGIN
      RETURN SUPER.MoveNext();
   END MoveNext;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Implementor GET : baseobject.TPDisposable; // the object to be disposed, when TPIterator is to be disposed (interface cannot be disposed)
   BEGIN
      RETURN SUPER.Implementor;
   END Implementor;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY OfCollection GET : collection.TPCollection;
   BEGIN
      RETURN SUPER.OfCollection;
   END OfCollection;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Name( OUT name : ARRAY OF WCHAR );
   BEGIN
      IF Value = NIL THEN
         name := L"";
      ELSE
         StringsO.TPString( Data )^.ToOA( OUT name );
      END;
   END Name;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Test GET : test.TPTest;
   BEGIN
      RETURN Value;
   END Test;

(*---------------------------------------------------------------------------*)

END CTestIterator;

(*================================================================================*)
// abstract helper implementations -- implementor can directly use the class, the only thing he
// must do it to export Factory procedure and instantiate the class

CLASS CTests( helper.APlugin ) IMPLEMENTS test.ITests;

   // IPluginObject
   PUBLIC FINAL READONLY PROPERTY
      Type : iplugin.TObjectType;
      OfPlugin : iplugin.TPPlugin;
      OwnerHandle : PTR;

   // IPlugin
   PUBLIC VIRTUAL PROCEDURE EnumerateClasses( REF EnumerateState : PTR; OUT ClassName : ARRAY OF WCHAR ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE GetLECData( OUT cllvData : iplugin.TcllvData; OUT cllvPath : ARRAY OF WCHAR ) : BOOLEAN;

   // ITests
   PUBLIC VIRTUAL PROCEDURE TestFactory( CONST ClassPath : ARRAY OF WCHAR; OUT Object : iplugin.TPPluginObject ) : CARDINAL;
   PUBLIC VIRTUAL PROCEDURE GetIterator() : POINTER TO test.ITestIterator;
   PUBLIC VIRTUAL PROCEDURE AddTest( CONST Name : ARRAY OF WCHAR; Test : test.TPTest );

   // APluginObject
   PUBLIC FINAL PROCEDURE Dispose();

   // APlugin
   PUBLIC VIRTUAL PROCEDURE PluginInfo( OUT Plugin, PluginVersionString : ARRAY OF WCHAR );
   PUBLIC VIRTUAL PROCEDURE CreateObject( CONST QName : ARRAY OF WCHAR; OUT Object : iplugin.TPPluginObject ) : iplugin.TLoadResult;
   PUBLIC VIRTUAL PROCEDURE DestroyObject( REF Object : iplugin.TPPluginObject ) : iplugin.TLoadResult;

   // SELF
   PRIVATE VAR
      _Tests : lists.CPtrList;

END CTests;

(*---------------------------------------------------------------------------*)

VAR
   Tests : POINTER TO CTests := NIL;

(*================================================================================*)

CLASS IMPLEMENTATION CTests;

(*--------------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY Type GET : iplugin.TObjectType;
   BEGIN
      RETURN iplugin.otSingleton;
   END Type;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY OfPlugin GET : iplugin.TPPlugin;
   BEGIN
      RETURN SUPER.OfPlugin;
   END OfPlugin;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY OwnerHandle GET : PTR;
   BEGIN
      RETURN SUPER.OwnerHandle;
   END OwnerHandle;

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

   PUBLIC VIRTUAL PROCEDURE GetLECData( OUT cllvData : iplugin.TcllvData; OUT cllvPath : ARRAY OF WCHAR ) : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END GetLECData;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE TestFactory( CONST ClassPath : ARRAY OF WCHAR; OUT Object : iplugin.TPPluginObject ) : CARDINAL;
   BEGIN
      IF ClassPath = L"" THEN
         RETURN CARDINAL( Factory( ctestClass, OUT Object ));
      ELSE
         RETURN CARDINAL( Factory( ClassPath, OUT Object ));
      END;
   END TestFactory;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE GetIterator() : POINTER TO test.ITestIterator;
   VAR
      iterator : POINTER TO CTestIterator;
   BEGIN
      NEW( iterator );
      iterator^.Init( _Tests, collection.dirForward );
      RETURN iterator;
   END GetIterator;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE AddTest( CONST Name : ARRAY OF WCHAR; Test : test.TPTest );
   VAR
      S : StringsO.TPString;
   BEGIN
      IF _Tests.Contains( Test ) THEN
         RETURN;
      END;
      S := NEW( StringsO.CString );
      S^.FromOA( Name );
      _Tests.Add( Test, S );
   END AddTest;

(*--------------------------------------------------------------------------------*)

   PUBLIC FINAL PROCEDURE Dispose();
   VAR
      iterator : lists.CPtrListIterator;
      _S : POINTER TO StringsO.CString;
   BEGIN
      iterator.Init( _Tests, collection.dirForward );
      WHILE iterator.MoveNext() DO
         _S := iterator.Data;
         DISPOSE( _S );
      END; // WHILE
      _Tests.Dispose();

      // global variable
      Tests := NIL; // Dispose can be here called ONLY from Release, so deallocation follows and global pointer must be cleared
   END Dispose;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE PluginInfo( OUT Plugin, PluginVersionString : ARRAY OF WCHAR );
   BEGIN
      Plugin := ProductId;
      PluginVersionString := ProductVersion;
   END PluginInfo;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CreateObject( CONST QName : ARRAY OF WCHAR; OUT Object : iplugin.TPPluginObject ) : iplugin.TLoadResult;
   BEGIN
      IF EQUALS( QName, iplugin.cidPlugin ) THEN
         Object := OfPlugin; // return SELF
      ELSIF EQUALS( QName, ctestClass ) THEN
         Object := ADR( ITests );
      ELSE
         RETURN iplugin.lrClassNotFound;
      END;
      Refcounter^.AddRef();
      RETURN iplugin.lrSuccess;
   END CreateObject;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE DestroyObject( REF Object : iplugin.TPPluginObject ) : iplugin.TLoadResult;
   BEGIN
      IF Object = OfPlugin THEN
         // fall down
      ELSIF Object = ADR( ITests ) THEN
         // fall down
      ELSE
         RETURN iplugin.lrClassNotFound;
      END;
      Object := NIL;
      Refcounter^.Release(); // inside Release the Dispose is called
      RETURN iplugin.lrSuccess;
   END DestroyObject;

(*--------------------------------------------------------------------------------*)

END CTests;

(*================================================================================*)

PROCEDURE tests() : test.TPTests;
BEGIN
   IF Tests = NIL THEN
      NEW( Tests );
   END;
   RETURN Tests;
END tests;

(*================================================================================*)

END testimpl.
