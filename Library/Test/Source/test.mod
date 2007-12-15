IMPLEMENTATION MODULE test;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   Strings,
   StringsO;

(*================================================================================*)

CONST
   ctestClass = L"Development.Tests";

(*================================================================================*)

CLASS IMPLEMENTATION ATests;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE EnumerateClasses( REF EnumerateState : PTR; OUT ClassName : ARRAY OF WCHAR ) : BOOLEAN;
   BEGIN
      IF EnumerateState > 0 THEN
         RETURN FALSE;
      END;
      ClassName := ctestClass;
      RETURN TRUE;
   END EnumerateClasses;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE GetLECData( OUT cllvData : objlib.TcllvData; OUT cllvPath : ARRAY OF WCHAR ) : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END GetLECData;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE EnumerateTests( REF ES : PTR; OUT Name : ARRAY OF WCHAR; OUT Test : TPTest ) : BOOLEAN;
   VAR
      _S : StringsO.TPString;
      _Test : TPTest;
      b : BOOLEAN;
   BEGIN
      IF ES = 0 THEN
         b := Tests.GetFirst( OUT _Test, OUT _S );
      ELSE
         b := Tests.NextOf( ES, OUT _Test, OUT _S );
      END;
      IF b THEN
         ES := Tests.Current;
         Test := _Test;
         _S^.ToOA( OUT Name );
      END;
      RETURN b;
   END EnumerateTests;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE AddTest( CONST Name : ARRAY OF WCHAR; Test : TPTest );
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

   VIRTUAL PROCEDURE OnFactory( CONST QName : ARRAY OF WCHAR; OUT Object : objlib.TPObject ) : objlib.TResult;
   BEGIN
      IF EQUALS( QName, ctestClass ) THEN
         Object := ADR( AObject );
         RETURN objlib.lrSuccess;
      ELSE
         RETURN objlib.lrClassNotFound;
      END;
   END OnFactory;

(*--------------------------------------------------------------------------------*)

END ATests;

(*================================================================================*)

END test.