IMPLEMENTATION MODULE testimpl;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;
   
IMPORT
   iplugin,
   lists,
   helper,
   StringsO;

(*================================================================================*)

CONST
   ctestClass = L"Development.Tests";

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
   PUBLIC VIRTUAL PROCEDURE EnumerateTests( REF ES : PTR; OUT Name : ARRAY OF WCHAR; OUT Test : test.TPTest ) : BOOLEAN;
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

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE EnumerateTests( REF ES : PTR; OUT Name : ARRAY OF WCHAR; OUT Test : test.TPTest ) : BOOLEAN;
   VAR
      _S : StringsO.TPString;
      _Test : test.TPTest;
      b : BOOLEAN;
   BEGIN
      IF ES = 0 THEN
         b := _Tests.GetFirst( OUT _Test, OUT _S );
      ELSE
         b := _Tests.NextOf( ES, OUT _Test, OUT _S );
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
      _S : POINTER TO StringsO.CString;
   BEGIN
      _Tests.Reset();
      WHILE _Tests.MoveNext() DO
         _S := _Tests.CurrentData;
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
