IMPLEMENTATION MODULE nsitem;

FROM Storage IMPORT
   ALLOCATE;

IMPORT
   Exceptions,
   StringsO;

(*===========================================================================*)

CLASS IMPLEMENTATION CnsWrapper;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Name GET : StringsO.TPString;
   BEGIN
      RETURN _NS^.Root^.Name;
   END Name;
   
(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY NameType GET : ns.TNameType;
   BEGIN
      RETURN _NS^.Root^.NameType;
   END NameType;
   
(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY ValueType GET : iovalue.TValueType;
   BEGIN
      RETURN _NS^.Root^.ValueType;
   END ValueType;
   
(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Value GET : iovalue.TPValue;
   BEGIN
      RETURN _NS^.Root^.Value;
   END Value;
   
(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Data GET : PTR;
   BEGIN
      RETURN _NS^.Root^.Data;
   END Data;
   
(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Data SET( Value : PTR );
   BEGIN
      _NS^.Root^.Data := Value;
   END Data;
   
(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Count GET : CARDINAL;
   BEGIN
      RETURN _NS^.Root^.Count;
   END Count;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Namespace GET : ns.TPns;
   BEGIN
      RETURN _NS;
   END Namespace;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Namespace SET( NS : ns.TPns );
   BEGIN
      _NS := NS;
   END Namespace;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL INDEX CnsWrapper GET( Index : CARDINAL ) : ns.TPnsItem;
   BEGIN
      RETURN _NS^.Root^[Index];
   END CnsWrapper;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE ContainsOA( CONST SingleName : ARRAY OF WCHAR ) : BOOLEAN;
   BEGIN
      RETURN _NS^.Root^.ContainsOA( SingleName );
   END ContainsOA;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE GetOA( CONST SingleName : ARRAY OF WCHAR; OUT Item : ns.TPnsItem ) : BOOLEAN;
   BEGIN
      RETURN _NS^.Root^.GetOA( SingleName, OUT Item );
   END GetOA;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE AddChild( Child : ns.TPnsItem );
   BEGIN
      Exceptions.Modula2Exception( NIL, L"Namespace Wrapper", L"", Exceptions.mexNotSupported );
   END AddChild;

(*---------------------------------------------------------------------------*)

BEGIN
   _NS := NIL;
END CnsWrapper;

(*===========================================================================*)

TYPE
  TPnsItem = POINTER TO CnsItem;

CLASS IMPLEMENTATION CnsItem;

(*---------------------------------------------------------------------------*)

   VIRTUAL PROPERTY Name GET : StringsO.TPString;
   BEGIN
      RETURN ADR( _Name );
   END Name;

(*---------------------------------------------------------------------------*)

   VIRTUAL PROPERTY NameType GET : ns.TNameType;
   BEGIN
      RETURN _NameType;
   END NameType;

(*---------------------------------------------------------------------------*)

   VIRTUAL PROPERTY ValueType GET : iovalue.TValueType;
   BEGIN
      RETURN _Value.Type;
   END ValueType;

(*---------------------------------------------------------------------------*)

   VIRTUAL PROPERTY Value GET : iovalue.TPValue;
   BEGIN
      RETURN ADR( _Value );
   END Value;

(*---------------------------------------------------------------------------*)

   VIRTUAL PROPERTY Data GET : PTR;
   BEGIN
      RETURN _Data;
   END Data;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Data SET( Value : PTR );
   BEGIN
      _Data := Value;
   END Data;
   
(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( CONST SingleChildName : ARRAY OF WCHAR; ConstName : BOOLEAN; NameType : ns.TNameType; ValueType : iovalue.TValueType; Data : PTR );
   BEGIN
      _Name.FromOA( SingleChildName );
      _NameType := NameType;
      _Value.Type := ValueType;
      _Data := Data;
   END Init;

(*---------------------------------------------------------------------------*)

BEGIN
   _NameType := ns.ntName;
   _Value.Type := iovalue.vtUnknown;
   _Data := 0;
END CnsItem;

(*===========================================================================*)

CLASS IMPLEMENTATION Ans;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Root GET : ns.TPnsItem;
   BEGIN
      RETURN _Root;
   END Root;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Initialize();
   BEGIN
      _Root := CreateRoot();
      CreateStructure();
   END Initialize;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE CreateStructure(); // excluding root, need not to be overriden
   BEGIN
   END CreateStructure;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE FromXML( Stream : IOO.TPStream );
   BEGIN
   END FromXML;

(*---------------------------------------------------------------------------*)

BEGIN
   _Root := NIL;
END Ans;

(*===========================================================================*)

END nsitem.