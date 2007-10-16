IMPLEMENTATION MODULE DOM;
(*# call( o_a_copy => off ) *)

FROM Storage IMPORT
  ALLOCATE, REALLOCATE, DEALLOCATE;

IMPORT
  FIO,
  Storage,
  Strings,
  winerror;

IMPORT
  err, wrn,
  Console,
  Project,
  Types;
  
CONST
  CPP_ACCESS_MODIFIERS = FALSE;

//============================================================

CLASS IMPLEMENTATION CUnit;

  PROCEDURE Add( Unit : TPUnit );
  BEGIN
    Childs.Append( Unit );
    Unit^.Owner := ADR( SELF );
  END Add;

  PROCEDURE GetFirst( VAR Unit : TPUnit ) : BOOLEAN;
  BEGIN
    IF NOT Childs.GetFirst( OUT Current ) THEN
      RETURN FALSE;
    END;
    Unit := Current;
    RETURN TRUE;
  END GetFirst;

  PROCEDURE GetNext( VAR Unit : TPUnit ) : BOOLEAN;
  BEGIN
    IF Childs.NextOf( Current, OUT Current ) THEN
      Unit := Current;
      RETURN TRUE;
    ELSE
      Current := NIL;
      RETURN FALSE;
    END;
  END GetNext;

  PROPERTY Empty GET : BOOLEAN;
  BEGIN
    RETURN Childs.Empty;
  END Empty;

  PROCEDURE Items() : CARDINAL;
  BEGIN
    RETURN Childs.Count;
  END Items;

  PROCEDURE Generate( G : Generator.TPGenerator; C : TGenerateControl ) : TGenerateUnitMode;
  VAR
    Context : CARDINAL := 0;
    GUM : TGenerateUnitMode;
  BEGIN
    GUM := GenHead( G, C, Context );
    CASE GUM OF
    | gumUnknown, gumEmpty, gumSimple, gumSimpleWithTrailing :
    ELSE
      GenBody( G, C, GUM = gumIndent, Context );
      GenTail( G, C, Context );
    END;
    RETURN GUM;
  END Generate;

  VIRTUAL PROCEDURE GenHead( G : Generator.TPGenerator; C : TGenerateControl; VAR Context : CARDINAL ) : TGenerateUnitMode;
  VAR
    E : TPExpression;
    EV : CEValue;
    i : INT64;
    L1, L2 : INT64;
    U : TPUnit;
  BEGIN
    CASE UnitKind OF
    | ukUnknown :
      RETURN gumNoIndent;
    
    | ukRegionMark :
      G^.EOL();
      IF TPSymbol( ADR( SELF ))^.N.Empty THEN
        IF eoRegion IN Options THEN
          G^.LineS( L"#endregion" );
        ELSE
          G^.LineS( L"// endregion" );
        END;
      ELSE
        IF eoRegion IN Options THEN
          G^.OutS( L"#region " );
        ELSE
          G^.OutS( L"// region " );
        END;
        G^.OutCS( TPSymbol( ADR( SELF ))^.N );
        G^.EOL();
      END;
      RETURN gumSimple;
      
    | ukModuleInitCode :
      G^.EOL();
      G^.LineS( L'// implicit module init code' );
      Project.Current()^.GenerateInitHeader( G, FALSE, FALSE, FALSE );
      G^.LineS( L'{' );
      G^.Enter();
        G^.LineS( L'if (InitFinallyCount_++ > 0) return;' );
        Project.Current()^.GenerateWithImported( G, ukModuleInitCode );
      RETURN gumNoIndent;
    | ukModuleFinalCode :
      G^.EOL();
      G^.LineS( L'// implicit module final code' );
      Project.Current()^.GenerateFinalHeader( G, FALSE, FALSE, FALSE );
      G^.LineS( L'{' );
      G^.Enter();
        G^.LineS( L'if (--InitFinallyCount_ > 0) return;' );
        Project.Current()^.GenerateWithImported( G, ukModuleFinalCode );
      RETURN gumNoIndent;

    | ukForwardedTypes,
      ukNestedForwardedFrames,
      ukNestedForwardedSymbols,
      ukNestedForwardedProcedures,
      ukForwardedStatements :
      RETURN gumNoIndent;

    | ukImport,
      ukImportExternal :
      RETURN gumSimple;
      
    | ukConstDeclBlock,
      ukTypeDefBlock,
      ukVarDeclBlock :
      IF NOT( gcDeferredFromDEF IN C ) AND NOT Childs.Empty THEN
        G^.EOL();
      END;
      RETURN gumNoIndent;

    | ukParamDefContainer :
      RETURN gumNoIndent;

    | ukClassInitCode,
      ukClassFinalCode,
      ukFriends :

    | ukParameterList :
      IF NOT( gcExplicit IN C ) THEN
        RETURN gumEmpty;
      ELSIF Childs.Empty THEN
        RETURN gumSimple;
      ELSIF Childs.GetFirst( OUT U ) AND ((U^.UnitKind = ukNestedParameters) OR (U^.UnitKind = ukNestedFrames)) AND U^.Childs.Empty THEN
        RETURN gumSimple;
      ELSE
        G^.OutSP();
        RETURN gumNoIndent;
      END;
    | ukNestedParameters,
      ukNestedFrames :
      RETURN gumNoIndent;

    | ukFieldIds :
      RETURN gumNoIndent;
    | ukVariantContainer :
      // exclude variant selector from container
      IF Childs.GetFirst( OUT U ) AND ( U^.UnitKind = ukVariantSelector ) AND ( TPSymbol( U )^.SymbolKind = skVariable ) THEN
        U^.Generate( G, gcsExplicit );
      END;
      G^.Indent(); G^.OutS( L'union {' ); G^.EOL();
    | ukVariantLabel :
      RETURN gumSimple;
    | ukVariantItem :
      IF Childs.Count <= 1 THEN
        RETURN gumSimple;
      END;
      G^.Indent(); G^.OutS( L'struct {' ); G^.EOL();
    | ukVariantElse :
      IF Childs.Empty THEN
        RETURN gumSimple;
      END;
      G^.Indent(); G^.OutS( L'struct {' ); G^.EOL();

    | ukProcedureBlock :
      IF Childs.Empty AND ( TEnvironmentOptions{eoInitially, eoFinally} * Owner^.Options = TEnvironmentOptions{} ) THEN
        G^.OutLB(); G^.OutRB(); G^.EOL();
        RETURN gumSimple;
      ELSE
        G^.EOL();
        G^.Indent(); G^.OutLB(); G^.EOL();
        IF Owner^.UnitKind IN uksMemberDecl THEN
          // class constructor and destructor do not have counter
        ELSIF eoInitially IN Owner^.Options THEN
          G^.Enter();
          G^.LineS( L'if (InitFinallyCount_++ > 0) return;' );
          Project.Current()^.GenerateWithImported( G, ukModuleInitCode );
          G^.EOL();
          G^.Leave();
        ELSIF eoFinally IN Owner^.Options THEN
          G^.Enter();
          G^.LineS( L'if (--InitFinallyCount_ > 0) return;' );
          Project.Current()^.GenerateWithImported( G, ukModuleFinalCode );
          G^.EOL();
          G^.Leave();
        END;
      END;
    | ukBlockBody, ukBlockBodyOfCOMProcedure :
      IF NOT Childs.Empty THEN
        G^.EOL();
      END;
      RETURN gumNoIndent;
    | ukBlockBodyOfReturnInTryProc, ukBlockBodyOfReturnInTryFunc :
      IF ( UnitKind = ukBlockBodyOfReturnInTryFunc ) AND ( eoHaveReturnInCPPTry IN Options )THEN
        Childs.GetFirst( OUT U );
        G^.Indent(); TPSymbol( U )^.T^.Generate( G, gcsName ); G^.OutS( L' _ReturnResult; // deferred return result' ); G^.EOL();
      END;
      IF eoHaveReturnInCPPTry IN Options THEN
        G^.LineS( L'BOOLEAN _FinallyReturns = false; // TRY/FINALLY exit control' );
      END;
      IF NOT Childs.Empty THEN
        G^.EOL();
      END;
      RETURN gumNoIndent;
    | ukClassInitStart :
      TPClass( Owner )^.GenerateClassVarInit( G, C );
      RETURN gumNoIndent;

    | ukProcedureCall :
      RETURN gumNoIndent;
    | ukActualParameterList :
      // everything moved to handle nested-parameters add-on parameters
      RETURN gumNoIndent;

    | ukVariableDesignator :
      RETURN gumNoIndent;

    | ukIf :
      RETURN gumNoIndent;
    | ukIfExpr :
      G^.Indent(); G^.OutS( L"if (" );
      RETURN gumNoIndent;
    | ukElsifExpr :
      G^.OutS( L" else if (" );
      RETURN gumNoIndent;
    | ukIfBlock, ukElsifBlock :
      G^.OutS( L" {" );
      G^.EOL();
    | ukElse :
      G^.OutS( L" else {" );
      G^.EOL();

    | ukSCase :
      G^.Indent(); G^.OutS( L"switch " );
      RETURN gumNoIndent;
    | ukCaseSelector :
      G^.OutS( L"(" );
      RETURN gumNoIndent;
    | ukCaseLabel :
      G^.Leave();
      IF Childs.Count = 1 THEN
        G^.Indent();
        G^.Enter();
        G^.OutS( L"case " );
        RETURN gumNoIndent;
      ELSE
        Childs.GetFirst( OUT E ); E^.Evaluate( EV, 0 ); L1 := EV.ToInteger();
        Childs.NextOf( E, OUT E ); E^.Evaluate( EV, 0 ); L2 := EV.ToInteger();
        FOR i := L1 TO L2 DO
          G^.Indent(); G^.OutS( L"case " );
          E^.T^.GenerateOrdinal( G, i );
          G^.OutS( L" :" ); G^.EOL();
        END;
        G^.Enter();
        RETURN gumSimple;
      END;
    | ukCaseItem :
      IF Childs.Empty THEN
        RETURN gumSimple;
      END;
    | ukCaseElse :
      G^.LineS( L"default:" );

    | ukSWhile :
      G^.Indent();
      G^.OutS( L"while " );
      RETURN gumNoIndent;
    | ukWhileCondition :
      G^.OutS( L"(" );
      RETURN gumNoIndent;
    | ukWhileBody :

    | ukSLoop :
      G^.LineS( L"for (;;) { // LOOP" );

    | ukSRepeat :
      RETURN gumNoIndent;
    | ukRepeatBody :
      G^.LineS( L"do { // REPEAT" );
    | ukRepeatCondition :
      G^.OutS( L"(!(" );
      RETURN gumNoIndent;

    | ukSForBody :
      RETURN gumNoIndent;

    | ukSTry :
      RETURN gumNoIndent;
    | ukTryCPPBlock :
      G^.LineS( L"try {" );
    | ukTrySEHBlock :
      G^.LineS( L"__try {" );
    | ukExceptBlock :
      G^.OutS( L" __except (" );
      RETURN gumNoIndent;
    | ukExceptDoBlock,
      ukCatchDoBlock :
      G^.OutS( L") {" ); G^.EOL();
    | ukFinallyCPPBlock :
      G^.LineS( L"{ // FINALLY" );
      RETURN gumIndent;
    | ukFinallySEHBlock :
      G^.OutS( L" __finally {" ); G^.EOL();
    | ukCatchBlock :
      G^.Indent(); G^.OutS( L"catch (" );
      RETURN gumNoIndent;
    | ukCatchAnyBlock :
      G^.Indent(); G^.OutS( L"catch (..." );
      RETURN gumNoIndent;

    | ukSThrow :
      IF Childs.Empty THEN
        G^.LineS( L'throw' );
        RETURN gumSimple;
      ELSE
        G^.Indent(); G^.OutS( L'throw ' );
        RETURN gumNoIndent;
      END;

    ELSE

    G^.Indent();

    // CASE Generator.TPGenerator( Generator )^.Mode() OF
    IF Childs.Empty THEN
      G^.OutN( CARDINAL( UnitKind ));
    ELSE
      G^.OutS( L"ENTER " );
      G^.OutN( CARDINAL( UnitKind ));
      G^.EOL();
    END;

    END;
    RETURN gumIndent;
  END GenHead;

  VIRTUAL PROCEDURE GenBody( G : Generator.TPGenerator; C : TGenerateControl; Indent : BOOLEAN; Context : CARDINAL );
  VAR
    GUM : TGenerateUnitMode;
    LU : DOM.TPUnit;
    b, g : BOOLEAN;
  BEGIN
    IF NOT Childs.Empty THEN
      IF Indent THEN
        G^.Enter();
      END;
      b := Childs.GetFirst( OUT LU );
      g := LU^.GenTo[G^.Mode()];
      C := C + TGenerateControl{gcFirst};
      WHILE b DO
        IF g THEN
          GUM := LU^.Generate( G, C );
        ELSE
          GUM := gumEmpty;
        END;
        b := Childs.NextOf( LU, OUT LU );
        IF b THEN
          g := LU^.GenTo[G^.Mode()];
          IF g AND ( GUM <> gumEmpty ) THEN
            C := C - TGenerateControl{gcFirst};
            GenSep( LU, G, C );
          END;
        END;
      END; // WHILE
      IF Indent THEN
        G^.Leave();
      END;
    END;
  END GenBody;

  VIRTUAL PROCEDURE GenSep( CONST BeforeU : TPUnit; G : Generator.TPGenerator; C : TGenerateControl );
  BEGIN
    CASE UnitKind OF
    | ukParameterList :
      IF BeforeU = NIL THEN
        // do nothing
      ELSIF ( BeforeU^.UnitKind <> ukNestedParameters ) AND ( BeforeU^.UnitKind <> ukNestedFrames ) THEN
        // ok, separating normal parameters
        G^.OutCmSP();
      ELSIF NOT BeforeU^.Empty THEN
        // ok, separating normal parameters and frames
        G^.OutCmSP();
      END;
    | ukParamDefContainer,
      ukActualParameterList,
      ukNestedParameters,
      ukNestedFrames :
      G^.OutCmSP();
    END; // CASE
  END GenSep;

  VIRTUAL PROCEDURE GenTail( G : Generator.TPGenerator; C : TGenerateControl; Context : CARDINAL );
  VAR
    L : TPLabel;
  BEGIN
    CASE UnitKind OF
    | ukUnknown :

    | ukModuleInitCode :
      G^.Leave();
      G^.LineS( L'} // module init code' );
    | ukModuleFinalCode :
      G^.Leave();
      G^.LineS( L'} // module final code' );

    | ukForwardedTypes,
      ukNestedForwardedFrames,
      ukNestedForwardedSymbols,
      ukNestedForwardedProcedures,
      ukForwardedStatements :

    | ukConstDeclBlock,
      ukTypeDefBlock,
      ukVarDeclBlock,
      ukClassInitCode,
      ukClassFinalCode,
      ukFriends :
      // G^.EOL();
      
    | ukParamDefContainer :

    | ukParameterList :
      G^.OutSP();
    | ukParameterContainer :
    | ukNestedParameters,
      ukNestedFrames :

    | ukFieldIds :
    | ukVariantContainer :
      G^.Indent(); G^.OutS( L'};' ); G^.EOL();
    | ukVariantLabel :
    | ukVariantItem,
      ukVariantElse :
      G^.Indent(); G^.OutS( L'};' ); G^.EOL();

    | ukProcedureBlock :
      G^.LineRB();
    | ukBlockBody :
    | ukBlockBodyOfCOMProcedure :
      G^.LineS( L'return 0; // implicit return' );
    | ukBlockBodyOfReturnInTryProc, ukBlockBodyOfReturnInTryFunc :
    | ukClassInitStart :

    | ukActualParameterList :
      // G^.OutSPRP(); moved up to allow generate nested-procedures add-on parameters

    | ukVariableDesignator :

    | ukIf :
      G^.OutS( L" // IF" ); G^.EOL();
    | ukIfExpr, ukElsifExpr :
      G^.OutS( L")" );
    | ukIfBlock, ukElsifBlock, ukElse :
      G^.Indent(); G^.OutS( L"}" );

    | ukSCase :
      G^.LineRB();
    | ukCaseSelector :
      G^.OutS( L") {" );
      G^.EOL();
    | ukCaseLabel :
      G^.OutS( L" :" );
      G^.EOL();
    | ukCaseItem,
      ukCaseElse :
      G^.Enter();
      G^.LineS( L"break;" );
      G^.Leave();

    | ukSLoop :
      GetFirst( L ); GetNext( L ); // continue
      IF eoReferenced IN L^.Options THEN
        G^.Enter(); G^.Indent(); G^.OutCS( L^.N ); G^.OutS( L":;" ); G^.EOL(); G^.Leave();
      END;
      G^.LineRBS( L"LOOP" );
      GetFirst( L );  // exit
      IF eoReferenced IN L^.Options THEN
        G^.Indent(); G^.OutCS( L^.N ); G^.OutS( L":;" ); G^.EOL();
      END;

    | ukSWhile :
      G^.LineRBS( L"WHILE" );
      GetFirst( L ); // exit
      IF eoReferenced IN L^.Options THEN
        G^.Indent(); G^.OutCS( L^.N ); G^.OutS( L":;" ); G^.EOL();
      END;
    | ukWhileCondition :
      G^.OutS( L") {" );
      G^.EOL();
    | ukWhileBody :
      GetFirst( L ); // continue
      IF eoReferenced IN L^.Options THEN
        G^.Enter(); G^.Indent(); G^.OutCS( L^.N ); G^.OutS( L":;" ); G^.EOL(); G^.Leave();
      END;

    | ukRepeatBody :
      GetFirst( L );  // continue
      IF eoReferenced IN L^.Options THEN
        G^.Enter(); G^.Indent(); G^.OutCS( L^.N ); G^.OutS( L":;" ); G^.EOL(); G^.Leave();
      END;
      G^.Indent(); G^.OutS( L"} while " );
    | ukRepeatCondition :
      G^.OutS( L"))" );
    | ukSRepeat :
      G^.OutS( L"; // REPEAT" ); G^.EOL();
      GetFirst( L ); // exit
      IF eoReferenced IN L^.Options THEN
        G^.Indent(); G^.OutCS( L^.N ); G^.OutS( L":;" ); G^.EOL();
      END;

    | ukSForBody :
      GetFirst( L ); // continue
      IF eoReferenced IN L^.Options THEN
        G^.Indent(); G^.OutCS( L^.N ); G^.OutS( L":;" ); G^.EOL();
      END;
    
    | ukSTry,
      ukExceptBlock,
      ukCatchBlock,
      ukCatchAnyBlock :
    | ukFinallyCPPBlock :
      IF eoHaveReturnInCPPTry IN Options THEN
        G^.Enter();
        IF eoTryReturnsValue IN Options THEN
          G^.LineS( L'if (_FinallyReturns) return _ReturnResult; // RETURN from TRY' );
        ELSE
          G^.LineS( L'if (_FinallyReturns) return; // RETURN from TRY' );
        END;
        G^.Leave();
      END;
      G^.LineRB();
    | ukTrySEHBlock :
      G^.Indent(); G^.OutRB();
    | ukTryCPPBlock,
      ukExceptDoBlock,
      ukFinallySEHBlock,
      ukCatchDoBlock :
      G^.LineRB();

    | ukSThrow :
      G^.OutSC(); G^.EOL();

    ELSE

      IF NOT Childs.Empty THEN
        G^.Indent();
        G^.OutS( L"LEAVE " );
        G^.OutN( CARDINAL( UnitKind ));
      END;

      G^.EOL();

    END;
  END GenTail;

  INITIALLY CUnit();
  VAR
    M : TPModule;
  BEGIN
    UnitKind := ukUnknown;
    CompileState := csUnknown;
    ImplementationState := isUnknown;
    Owner := NIL;
    Storage.Fill( ADR( GenTo ), SIZE( GenTo ), 1 );
    M := Project.Current();
    IF M = NIL THEN
      Options := TEnvironmentOptions{};
    ELSE
      Options := M^.CurE^.Options;
    END;
    Current := NIL;
  END CUnit;

END CUnit;

//============================================================

CLASS IMPLEMENTATION CSymbol;

  VIRTUAL PROPERTY Symbols GET : TPSymbols;
  BEGIN
    RETURN NIL;
  END Symbols;

  VIRTUAL PROCEDURE Done();
  BEGIN
  END Done;

  PROCEDURE DoneAndFree();
  VAR
    a : ADDRESS;
  BEGIN
    Done();
    a := ADR( SELF );
    DISPOSE( a );
  END DoneAndFree;

  PROCEDURE AddForwardedUnit( U : TPUnit );
  BEGIN
    NSD.Add( U );
  END AddForwardedUnit;

  PROCEDURE IsModule() : BOOLEAN;
  BEGIN
    RETURN SymbolKind = skModule;
  END IsModule;

  PROCEDURE IsClass() : BOOLEAN;
  BEGIN
    RETURN SymbolKind = skClass;
  END IsClass;

  PROCEDURE IsProcedure( AllowTypes : BOOLEAN ) : BOOLEAN;
  BEGIN
    RETURN ( SymbolKind = skProcedure ) OR
           ( SymbolKind = skMethod ) OR ( SymbolKind = skProperty ) OR ( SymbolKind = skIndexer ) OR
           ( SymbolKind = skType ) AND AllowTypes AND ( TPType( ADR( SELF ))^.Unwrap()^.TypeKind = tkProcedure ) OR
           ( SymbolKind = skVariable ) AND ( T^.Unwrap()^.TypeKind = tkProcedure );
  END IsProcedure;

  PROCEDURE GetN( C : TGenerateControl; AppendFlag : BOOLEAN; REF CS : StringsO.CString );
  BEGIN
    IF NOT AppendFlag THEN
      CS.Clear();
    END;
    IF coMacro IN Options THEN
      // CS := CS + N; !!!!!
      CS.Append( N );
    ELSIF OfSymbol = NIL THEN
      GetQN( C, REF CS );
    ELSIF gcNameNested IN C THEN
      CASE OfSymbol^.UnitKind OF
      | ukProcedureDecl, ukNestedProcedureDecl, ukSimpleClassDef, ukClassClassDef, ukMethodDecl..ukPropertyDeclW :
        OfSymbol^.GetN( C, TRUE, REF CS );
        CS.AppendOA( L'_' );
      END;
      CS.Append( N );
    ELSE
      GetQN( C, REF CS );
    END;
  END GetN;
  
  PROCEDURE GetQN( C : TGenerateControl; REF CS : StringsO.CString );
  VAR
    LSymbol : TPSymbol;
    OfSymbol : TPSymbol;
    NameFlag : BOOLEAN;
  BEGIN
    LSymbol := ADR( SELF );
    OfSymbol := LSymbol^.OfSymbol;
    IF ( eoDLLInterface IN LSymbol^.Options ) AND
       ( C * TGenerateControl{gcSimple} = TGenerateControl{} ) AND
       ( OfSymbol <> Project.Current()^.OD ) AND
       ( OfSymbol <> Project.Current()^.OI ) THEN
      WHILE OfSymbol <> NIL DO
        NameFlag := ( OfSymbol^.UnitKind = ukDefinition ) AND ( TPModule( OfSymbol )^.MEnv.Prefix = mprfModula );
        IF NameFlag THEN
          CS.PrependOA( L"::" );
          CS.Prepend( TPModule( OfSymbol )^.OH );
        ELSE
          CASE LSymbol^.UnitKind OF
          | ukSimpleClassDef, ukClassClassDef, ukProcedureDef :
            CS.PrependOA( L"::" );
            IF NameFlag THEN
              CS.Prepend( OfSymbol^.N );
            END;
          | ukSimpleTypeDef, ukClassTypeDef :
            CS.PrependOA( L"::" ); // this assures that global types will not conflict with local ones
          END; // CASE
        END;
        LSymbol := OfSymbol;
        OfSymbol := LSymbol^.OfSymbol;
      END;
    END;
    CS.Append( N );
  END GetQN;
  
  PROCEDURE GetSourceQN( OUT CS : StringsO.CString );
  VAR
    LOfSymbol : TPSymbol;
  BEGIN
    CS.Clear();
    LOfSymbol := OfSymbol;
    IF ( eoDLLInterface IN Options ) AND
       ( LOfSymbol <> Project.Current()^.OD ) AND
       ( LOfSymbol <> Project.Current()^.OI ) THEN
      WHILE LOfSymbol <> NIL DO
        CASE LOfSymbol^.UnitKind OF
        | ukDefinition :
          CS.PrependOA( L"." );
          CS.Prepend( TPModule( LOfSymbol )^.OH );
        | ukClassClassDef :
          CS.PrependOA( L"." );
          CS.Prepend( LOfSymbol^.N );
        END;
        LOfSymbol := LOfSymbol^.OfSymbol;
      END;
    END;
    CS.Append( N );
  END GetSourceQN;
  
  PROCEDURE OutN( G : Generator.TPGenerator; C : TGenerateControl );
  VAR
    CS : StringsO.CString;
  BEGIN
    GetN( C, FALSE, REF CS );
    G^.OutCS( CS );
  END OutN;

  PROCEDURE OutQN( G : Generator.TPGenerator; C : TGenerateControl );
  VAR
    CS : StringsO.CString;
  BEGIN
    GetQN( C, REF CS );
    G^.OutCS( CS );
  END OutQN;

  VIRTUAL PROCEDURE GenHead( G : Generator.TPGenerator; C : TGenerateControl; VAR Context : CARDINAL ) : TGenerateUnitMode;
  BEGIN
    IF NSD.Empty THEN
      RETURN gumEmpty;
    ELSE
      G^.LineS( L"// forwarded structured constants and types" );
      NSD.Generate( G, C );
      RETURN gumSimple;
    END;
  END GenHead;

BEGIN
  SymbolKind := skUnknown;
  T := Types.TUnknown;
  OfSymbol := NIL;
  AM := amUnknown;
  CM := TCodeModifier{};
  NSD.UnitKind := ukNestedForwardedSymbols;
END CSymbol;

//============================================================

TYPE
  TPSTE = POINTER TO CSTE;

CLASS CSTE( avltree.CAVLTreeElem );
  PS : TPSymbol;
  VIRTUAL PROCEDURE Compare( i : CARDINAL; PE : avltree.TPAVLTreeKey ) : TRISTATE;
END CSTE;

//------------------------------------------------------------

CLASS IMPLEMENTATION CSTE;

  VIRTUAL PROCEDURE Compare( i : CARDINAL; PE : avltree.TPAVLTreeKey ) : TRISTATE;
  BEGIN
    RETURN PS^.N.Compare( TPSTE( PE )^.PS^.N );
  END Compare;

BEGIN
  PS := NIL;
END CSTE;

//------------------------------------------------------------

CLASS IMPLEMENTATION CSymbols;

  PROCEDURE Knows( Symbol : TPSymbol ) : BOOLEAN;
  VAR
    PSTE : TPSTE;
    STE : CSTE;
  BEGIN
    STE.PS := Symbol;
    RETURN Search( ADR( STE ), OUT PSTE );
  END Knows;

  PROCEDURE Add( Symbol : TPSymbol );
  VAR
    PSTE : TPSTE;
  BEGIN
    Symbol^.OfSymbol := OfSymbol;
    NEW( PSTE );
    PSTE^.PS := Symbol;
    Insert( PSTE );
  END Add;

  PROCEDURE Forget( Symbol : TPSymbol ) : BOOLEAN;
  VAR
    STE : CSTE;
    PSTE : TPSTE;
  BEGIN
    STE.PS := Symbol;
    IF NOT Remove( ADR( STE ), OUT PSTE ) THEN
      RETURN FALSE;
    END;
    FREE( PSTE );
    RETURN TRUE;
  END Forget;

  PROCEDURE Get( CONST Name : StringsO.CString; VAR Symbol : TPSymbol ) : BOOLEAN;
  VAR
    PSTE : TPSTE;
    SSymbol : CSymbol;
    STE : CSTE;
  BEGIN
    STE.PS := ADR( SSymbol );
    SSymbol.N := Name;
    IF Search( ADR( STE ), OUT PSTE ) THEN
      Symbol := PSTE^.PS;
      RETURN TRUE;
    ELSE
      RETURN FALSE;
    END;
  END Get;

  PROCEDURE GetCI( CONST Name : StringsO.CString; VAR Symbol : TPSymbol ) : BOOLEAN; // CaseInsensitive
  VAR
    PSTE : TPSTE;
    SSymbol : CSymbol;
    STE : CSTE;
    b : BOOLEAN;
  BEGIN
    IF Get( Name, Symbol ) THEN
      RETURN TRUE;
    END;
    STE.PS := ADR( SSymbol );
    SSymbol.N := Name;
    b := GetFirst( OUT PSTE );
    WHILE b AND NOT Name.EqualsIgnoreCase( PSTE^.PS^.N ) DO
      b := NextOf( PSTE, OUT PSTE );
    END;
    IF b THEN
      Symbol := PSTE^.PS;
      RETURN TRUE;
    ELSE
      RETURN FALSE;
    END;
  END GetCI;

  PROCEDURE GetS( Name : ARRAY OF WCHAR; VAR Symbol : TPSymbol ) : BOOLEAN;
  VAR
    CS : StringsO.CString;
    b : BOOLEAN;
  BEGIN
    CS.FromOA( Name );
    b := Get( CS, Symbol );
    CS.Dispose();
    RETURN b;
  END GetS;

  PROCEDURE Reset();
  BEGIN
    CurrentSTE := NIL;
    Current := NIL;
  END Reset;

  PROCEDURE MoveNext() : BOOLEAN;
  VAR
    PSTE : TPSTE;
  BEGIN
    IF CurrentSTE = NIL THEN
      IF GetFirst( OUT PSTE ) THEN
        CurrentSTE := PSTE;
        Current := PSTE^.PS;
        RETURN TRUE;
      END;
    ELSE
      PSTE := TPSTE( CurrentSTE );
      IF NextOf( PSTE, OUT PSTE ) THEN
        CurrentSTE := PSTE;
        Current := PSTE^.PS;
        RETURN TRUE;
      END;
    END;
    Reset();
    RETURN FALSE;
  END MoveNext;

BEGIN
  OfSymbol := NIL;
  CurrentSTE := NIL;
  Current := NIL;
  AnonCount := 0;
END CSymbols;

//============================================================

CLASS IMPLEMENTATION CSymbolsStack;

  PROCEDURE Push( CONST Symbols : TPSymbols; EnterChangesContext : BOOLEAN; WithDesignator : TPDesignator );
  BEGIN
    SUPER.PushEx( Symbols, WithDesignator );
    IF NOT EnterChangesContext OR ( Symbols^.OfSymbol = NIL ) THEN
      // pass down
    ELSIF Symbols^.OfSymbol^.IsClass() THEN
      CurC := TPClass( Symbols^.OfSymbol );
    ELSIF Symbols^.OfSymbol^.IsProcedure( TRUE ) THEN
      CurP := TPProcedure( Symbols^.OfSymbol );
    END;
  END Push;

  PROCEDURE Pop() : TPSymbols;
  VAR
    PS : TPSymbols;
    OS : TPSymbol; // OfSymbol
  BEGIN
    PS := SUPER.Pop();
    IF PS = NIL THEN
      CurC := NIL; CurP := NIL;
      RETURN NIL;
    ELSIF PS^.OfSymbol = CurC THEN
      CurC := NIL;
      Reset();
      WHILE MoveNext() DO
        OS := TPSymbols( Current )^.OfSymbol;
        IF ( OS <> NIL ) AND OS^.IsClass() THEN
          CurC := TPClass( OS );
          EXIT;
        END;
      END; // WHILE
    ELSIF PS^.OfSymbol = CurP THEN
      CurP := NIL;
      Reset();
      WHILE MoveNext() DO
        OS := TPSymbols( Current )^.OfSymbol;
        IF ( OS <> NIL ) AND OS^.IsProcedure( TRUE ) THEN
          CurP := TPProcedure( OS );
          EXIT;
        END;
      END; // WHILE
    END;
    RETURN PS;
  END Pop;

BEGIN
  CurC := NIL;
  CurP := NIL;
END CSymbolsStack;

//============================================================

CLASS IMPLEMENTATION CLabel;

  VIRTUAL PROCEDURE GenHead( G : Generator.TPGenerator; C : TGenerateControl; VAR Context : CARDINAL ) : TGenerateUnitMode;
  BEGIN
    RETURN gumEmpty;
  END GenHead;

BEGIN
  UnitKind := ukLabelDecl;
  SymbolKind := skLabel;
END CLabel;

//============================================================

CLASS IMPLEMENTATION CConstant;

  PROCEDURE Init2( T : TPType; DecimalLiteral : ARRAY OF WCHAR );
  BEGIN
    SymbolKind := skConstant;
    SELF.T := T;
    NEW( DeclarationExpression );
    DeclarationExpression^.Init3( T, okDecimal, DecimalLiteral );
  END Init2;

  PROCEDURE Unwrap() : TPSymbol;
  BEGIN
    IF IsLinkOf = NIL THEN
      RETURN ADR( SELF );
    ELSE CASE IsLinkOf^.UnitKind OF
    | ukCmdLineConstDecl, ukSimpleConstDecl, ukClassConstDecl :
      RETURN TPConstant( IsLinkOf )^.Unwrap();
    ELSE
      RETURN IsLinkOf;
    END; END;
  END Unwrap;

  PROCEDURE LinkOf() : TPSymbol;
  BEGIN
    RETURN IsLinkOf;
  END LinkOf;

  PROCEDURE SetLinkOf( Link : TPSymbol );
  BEGIN
    IsLinkOf := Link;
    IF IsLinkOf = NIL THEN
      T := Types.TUnknown;
      RETURN;
    END;
    CASE IsLinkOf^.UnitKind OF
    | ukSimpleTypeDef,
      ukClassTypeDef,
      ukSimpleClassDef,
      ukClassClassDef:
      T := TPType( IsLinkOf );
    ELSE
      T := IsLinkOf^.T;
    END;
  END SetLinkOf;

  PROCEDURE Expression() : TPExpression;
  BEGIN
    RETURN DeclarationExpression;
  END Expression;

  PROCEDURE SetExpression( Expression : TPExpression );
  BEGIN
    DeclarationExpression := Expression;
    IF DeclarationExpression = NIL THEN
      T := Types.TUnknown;
    ELSE
      T := DeclarationExpression^.T;
    END;
  END SetExpression;

  VIRTUAL PROCEDURE GenHead( G : Generator.TPGenerator; C : TGenerateControl; VAR Context : CARDINAL ) : TGenerateUnitMode;
  VAR
    EV : CEValue;
    GUM : TGenerateUnitMode;
    LT : TPType;
    Deferred : BOOLEAN;
  BEGIN
    IF UnitKind = ukVariantSelector THEN
      RETURN gumSimple;
    ELSIF gcName IN C THEN
      IF UnitKind = ukCmdLineConstDecl THEN
        DeclarationExpression^.Evaluate( EV, 0 );
        IF EV.T <> Types.TBOOLEAN THEN
           IF EV.S.Empty THEN
             G^.OutS( L'L""' );
           ELSE
             G^.OutS( L'L"' ); G^.OutUNICODEEscapeCS( EV.S, FALSE ); G^.OutS( L'"' );
           END;
        ELSIF EV.B THEN
          G^.OutS( L"TRUE" );
        ELSE
          G^.OutS( L"FALSE" );
        END;
      ELSIF eoForwarded IN Options THEN // normal consts
        OutN( G, C + TGenerateControl{gcNameNested} );
      ELSIF eoForwarded IN T^.Options THEN // enum consts
        OutN( G, C + TGenerateControl{gcNameNested} );
      ELSE
        OutN( G, C );
      END;
      RETURN gumSimple;
    ELSIF eoForwarded IN Options THEN
      RETURN gumEmpty;
    ELSIF eoForward IN Options THEN
      (*?*) // BAD -- see CType
      EXCL( IsLinkOf^.Options, eoForwarded );
      GUM := IsLinkOf^.Generate( G, C + TGenerateControl{gcNameNested} );
      INCL( IsLinkOf^.Options, eoForwarded );
      RETURN GUM;
    ELSIF IsLinkOf <> NIL THEN // aliases are not generated, they are resolved during compiling
      RETURN gumEmpty;
    END;

    CASE UnitKind OF
    | ukEnumItemImplicit, ukEnumItemExplicit :
      G^.Indent();
      OutN( G, C );
      IF UnitKind = ukEnumItemExplicit THEN
        G^.OutS( L' = ' );
        DeclarationExpression^.Generate( G, C );
      END;
      RETURN gumSimple;
    END;

    IF IsLinkOf <> NIL THEN
      IF gcDeferredFromDEF IN C THEN
        RETURN gumEmpty;
      END;

      G^.Indent();
      G^.OutS( L'#define ' );
      OutN( G, C );
      G^.OutS( L' ' );
      IsLinkOf^.OutQN( G, C );
      G^.EOL();

    ELSIF ( T = NIL ) OR ( T^.TypeKind = tkMorphable ) OR Types.TFloat^.Compatible( cmOperation, T ) THEN
      IF gcDeferredFromDEF IN C THEN
        RETURN gumEmpty;
      END;

      G^.Indent();
      IF eoUntypedConstAsDefine IN Options THEN
        G^.OutS( L'#define ' );
        OutN( G, C );
        G^.OutS( L' ' );
      ELSIF Types.TOrdinalNumber^.Compatible( cmOperation, T ) THEN
        G^.OutS( L'const ORDINAL ' );
        OutN( G, C );
        G^.OutS( L' = ' );
      ELSIF Types.TLONGREAL^.Compatible( cmOperation, T ) THEN
        G^.OutS( L'const LONGREAL ' );
        OutN( G, C );
        G^.OutS( L' = ' );
      ELSIF Types.TREAL^.Compatible( cmOperation, T ) THEN
        G^.OutS( L'const REAL ' );
        OutN( G, C );
        G^.OutS( L' = ' );
      ELSIF Types.TSet^.Compatible( cmOperation, T ) THEN
        IF TPSet( T )^._Count > 4 THEN
          G^.OutS( L'const LONGSET ' );
        ELSE
          G^.OutS( L'const SET ' );
        END;
        OutN( G, C );
        G^.OutS( L' = ' );
      ELSE // budou tu i jine typy?
        ASSERT( FALSE );
      END;
      DeclarationExpression^.Generate( G, C );
      G^.OutSC();
      G^.EOL();
 
    ELSE

      IF T^.Unwrap()^.PrimitiveType = DOM.ptStructure THEN
        Deferred := eoDLLInterface IN Options;
      ELSE
        Deferred := FALSE;
      END;
      IF NOT Deferred AND ( gcDeferredFromDEF IN C ) THEN
        RETURN gumEmpty;
      END;

      G^.Indent();
      IF NOT Deferred OR ( gcDeferredFromDEF IN C ) THEN
        G^.OutS( L'static const ' );
      ELSE
        G^.OutS( L'extern const ' );
      END;

      // type
      GUM := T^.Generate( G, gcsExplicit );
      G^.OutSP();
      OutN( G, C );
      LT := T;
      WHILE GUM = gumSimpleWithTrailing DO
        GUM := LT^.Generate( G, TGenerateControl{gcExplicitTrailing} );
        LT := LT^.Unwrap()^.T;
      END;

      IF NOT Deferred OR ( gcDeferredFromDEF IN C ) THEN
        G^.OutS( L' = ' );
        DeclarationExpression^.Generate( G, C );
      END;
      G^.OutSC();
      G^.EOL();

    END;

    RETURN gumSimple;
  END GenHead;

BEGIN
  UnitKind := ukSimpleConstDecl;
  SymbolKind := skConstant;
  IsLinkOf := NIL;
  DeclarationExpression := NIL;
END CConstant;

//============================================================

CLASS IMPLEMENTATION CType;

  PROCEDURE Init2( Name : ARRAY OF WCHAR; TK : TTypeKind );
  BEGIN
    N.FromOA( Name );
    TypeKind := TK;
  END Init2;

  PROCEDURE Init3( Name : ARRAY OF WCHAR; TK : TTypeKind; PT : TPrimitiveType );
  BEGIN
    N.FromOA( Name );
    TypeKind := TK;
    PrimitiveType := PT;
  END Init3;

  PROCEDURE Unwrap() : TPType;
  BEGIN
    IF UW = NIL THEN
      UW := ADR( SELF );
      WHILE UW^.TypeKind IN typeLinks DO
        UW := UW^.T;
      END;
    END;
    RETURN UW;
  END Unwrap;

  PROCEDURE UnwrapToFirstType() : TPType;
  VAR
    LT : TPType;
  BEGIN
    LT := ADR( SELF );
    WHILE LT^.TypeKind = tkLink DO
      LT := LT^.T;
    END;
    RETURN LT;
  END UnwrapToFirstType;

  PROCEDURE UnwrapToBaseType() : TPType;
  VAR
    LT : TPType;
  BEGIN
    LT := Unwrap();
    WHILE LT^.TypeKind IN typeLinks + TTypeKindSet{tkReference} DO
      LT := LT^.T;
    END;
    RETURN LT;
  END UnwrapToBaseType;

  VIRTUAL PROCEDURE IsFormal() : BOOLEAN;
  BEGIN
    RETURN FALSE;
  END IsFormal;

  VIRTUAL PROCEDURE IsOpenArray() : BOOLEAN;
  BEGIN
    RETURN FALSE;
  END IsOpenArray;

  VIRTUAL PROCEDURE Compatible( CM : TCompatibilityMode; PWith : TPType ) : BOOLEAN;
  VAR
    LUW : TPType;
  BEGIN
    IF PWith^.TypeKind IN typeLinks THEN
      PWith := PWith^.Unwrap();
    END;
    IF PWith^.TypeKind = tkMorphable THEN
      RETURN PWith^.Compatible( cmOperation, ADR( SELF ));
    ELSIF TypeKind IN typeLinks THEN
      RETURN Unwrap()^.Compatible( CM, PWith );
    END;
    CASE TypeKind OF
    | tkPrimitive :
      IF PWith^.TypeKind <> tkPrimitive THEN
        RETURN FALSE;
      ELSIF PrimitiveType = PWith^.PrimitiveType THEN
        RETURN TRUE;
      ELSIF CM = cmAssign THEN // whole number types are compatible to assignment (not for operation)
        CASE PWith^.PrimitiveType OF
        | ptCARD8  : RETURN PrimitiveType = ptINT8;
        | ptINT8   : RETURN PrimitiveType = ptCARD8;
        | ptCARD16 : RETURN PrimitiveType = ptINT16;
        | ptINT16  : RETURN PrimitiveType = ptCARD16;
        | ptCARD32 : RETURN PrimitiveType = ptINT32;
        | ptINT32  : RETURN PrimitiveType = ptCARD32;
        | ptCARD64 : RETURN PrimitiveType = ptINT64;
        | ptINT64  : RETURN PrimitiveType = ptCARD64;
        | ptSIZE   : RETURN ( PrimitiveType = ptCARD32 ) OR ( PrimitiveType = ptCARD64 );
        END;
        RETURN FALSE;
      ELSE // for operations (compare, AND etc.) are storage types compatible with whole numbers
        CASE PrimitiveType OF
        | ptCARD8  : RETURN PWith^.PrimitiveType = ptBYTE;
        | ptINT8   : RETURN PWith^.PrimitiveType = ptBYTE;
        | ptCARD16 : RETURN PWith^.PrimitiveType = ptWORD;
        | ptINT16  : RETURN PWith^.PrimitiveType = ptWORD;
        | ptCARD32 : RETURN ( PWith^.PrimitiveType = ptLONGWORD ) OR ( PWith^.PrimitiveType = ptSIZE );
        | ptINT32  : RETURN PWith^.PrimitiveType = ptLONGWORD;
        | ptCARD64 : RETURN ( PWith^.PrimitiveType = ptQUADWORD ) OR ( PWith^.PrimitiveType = ptSIZE );
        | ptINT64  : RETURN PWith^.PrimitiveType = ptQUADWORD;
        END;
        RETURN FALSE;
      END;
    | tkRecord, tkEnumeration, tkOpaqueWhole, tkOpaqueBase :
      RETURN ADR( SELF ) = PWith;
    | tkRange :
      IF ADR( SELF ) = PWith THEN
        RETURN TRUE;
      ELSE
        RETURN T^.Compatible( CM, PWith );
      END;
    | tkSet :
      IF ADR( SELF ) = PWith THEN
        RETURN TRUE;
      ELSE
        RETURN T^.Compatible( CM, PWith^.T );
      END;
    | tkArray :
      IF PWith^.TypeKind = tkStringArray THEN
        RETURN PWith^.Compatible( CM, ADR( SELF ));
      ELSIF PWith^.TypeKind = tkOpenArray THEN
        RETURN T^.Compatible( CM, PWith^.T );
      ELSIF Types.TTCHAR^.Compatible( CM, PWith ) THEN
        RETURN T^.Compatible( CM, PWith );
      ELSIF Types.TString^.Compatible( CM, PWith ) THEN
        RETURN T^.Compatible( CM, PWith^.T );
      ELSE
        RETURN ADR( SELF ) = PWith;
      END;
    | tkOpenArray :
      LUW := T^.Unwrap();
      IF Types.TStorage^.Compatible( CM, LUW ) THEN // OA of system storage types is compatible with all types
        RETURN TRUE;
      END;
      CASE PWith^.TypeKind OF
      | tkArray, tkOpenArray, tkStringArray, tkPrimitive :
      ELSE
        RETURN FALSE;
      END;
      IF LUW^.TypeKind <> tkPrimitive THEN
        RETURN T^.Compatible( CM, PWith^.T );
      ELSIF Types.TBString^.Compatible( CM, LUW ) THEN // I am ARRAY OF CHAR
        RETURN Types.TBString^.Compatible( CM, PWith );
      ELSIF Types.TWString^.Compatible( CM, LUW ) THEN // I am ARRAY OF CHAR
        RETURN Types.TWString^.Compatible( CM, PWith );
      ELSE
        RETURN T^.Compatible( CM, PWith^.T );
      END;
    | tkStringArray :
      IF ADR( SELF ) = PWith THEN
        RETURN TRUE;
      END;
      CASE PWith^.TypeKind OF
      | tkArray, tkOpenArray, tkStringArray, tkPrimitive :
      ELSE
        RETURN FALSE;
      END;
      IF ( ADR( SELF ) = Types.TBString ) OR ( ADR( SELF ) = Types.TTStringB ) THEN
        RETURN Types.TBCHAR^.Compatible( CM, PWith ) OR Types.TBCHAR^.Compatible( CM, PWith^.T );
      ELSIF ( ADR( SELF ) = Types.TWString ) OR ( ADR( SELF ) = Types.TTStringW ) THEN
        RETURN Types.TWCHAR^.Compatible( CM, PWith ) OR Types.TWCHAR^.Compatible( CM, PWith^.T );
      END;
    | tkReference :
      IF ADR( SELF ) = PWith THEN
        RETURN TRUE;
      ELSIF ( CM <> cmExact ) AND (( PWith = Types.TADDRESS ) OR ( PWith = Types.TPTR )) THEN
        RETURN TRUE;
      // for special cases see CheckAndGenCast/CSAssignment too
      ELSIF PWith^.TypeKind = tkStringArray THEN
        // 1a. special case: POINTER TO *CHAR and STRING LITERAL
        RETURN T^.Compatible( CM, PWith^.T );
      ELSIF PWith^.TypeKind <> tkReference THEN
        RETURN FALSE;
      ELSIF ADR( SELF ) = Types.TADDRESS THEN
        RETURN TRUE;
      ELSIF ( PWith^.T^.Unwrap()^.TypeKind = tkStringArray ) AND T^.Compatible( CM, PWith^.T^.Unwrap()^.T ) THEN
        // 1b. special case: POINTER TO TYPE and OPEN ARRAY OF TYPE
        RETURN TRUE;
      ELSIF ( PWith^.T^.Unwrap()^.TypeKind = tkOpenArray ) AND T^.Compatible( CM, PWith^.T^.Unwrap()^.T ) THEN
        // 2. special case: POINTER TO TYPE and OPEN ARRAY OF TYPE
        RETURN TRUE;
      ELSIF ( PWith^.T^.Unwrap()^.TypeKind = tkArray ) AND T^.Compatible( CM, PWith^.T^.Unwrap()^.T ) THEN
        // 3. special case: POINTER TO TYPE and ARRAY OF TYPE
        RETURN TRUE;
      ELSE
        RETURN T^.Compatible( CM, PWith^.T );
      END;
    END;
    RETURN FALSE;
  END Compatible;

  VIRTUAL PROCEDURE FirstOrdinal() : INT64;
  BEGIN
    CASE TypeKind OF
    | tkPrimitive :
      CASE PrimitiveType OF
      | ptBOOLEAN :
        RETURN 0;
      | ptCARD8, ptCARD16, ptCARD32, ptCARD64, ptBCHAR, ptWCHAR, ptBYTE, ptWORD, ptLONGWORD, ptQUADWORD, ptPTR :
        RETURN 0;
      | ptINT8 :
        RETURN MIN( INT8 );
      | ptINT16 :
        RETURN MIN( INT16 );
      | ptINT32 :
        RETURN -1 - INT64( MAX( INT32 )); // VC bug?
      | ptINT64 :
        RETURN MIN( INT64 );
      END;
    | tkLink, tkOpaqueBaseLink, tkOpaqueWholeLink, tkReference :
      RETURN T^.FirstOrdinal();
    END;
    RETURN 0; 
  END FirstOrdinal;

  VIRTUAL PROCEDURE LastOrdinal() : INT64;
  BEGIN
    CASE TypeKind OF
    | tkPrimitive :
      CASE PrimitiveType OF
      | ptBOOLEAN :
        RETURN 1;
      | ptCARD8, ptBYTE :
        RETURN MAX( CARD8 );
      | ptCARD16, ptWORD :
        RETURN MAX( CARD16 );
      | ptCARD32, ptLONGWORD, ptPTR :
        RETURN MAX( CARD32 );
      | ptCARD64, ptQUADWORD :
        RETURN MAX( CARD64 );
      | ptBCHAR :
        RETURN MAX( CARD8 );
      | ptWCHAR :
        RETURN MAX( CARD16 );
      | ptINT8 :
        RETURN MAX( INT8 );
      | ptINT16 :
        RETURN MAX( INT16 );
      | ptINT32 :
        RETURN MAX( INTEGER );
      | ptINT64 :
        RETURN MAX( INT64 );
      END;
    | tkLink, tkOpaqueBaseLink, tkOpaqueWholeLink, tkReference :
      RETURN T^.LastOrdinal();
    END;
    RETURN 0;
  END LastOrdinal;

  VIRTUAL PROCEDURE OrdinalRange() : INT64;
  BEGIN
    CASE TypeKind OF
    | tkPrimitive :
      CASE PrimitiveType OF
      | ptBOOLEAN :
        RETURN 2;
      | ptINT8, ptCARD8, ptBCHAR, ptBYTE :
        RETURN 256;
      | ptINT16, ptCARD16, ptWCHAR, ptWORD :
        RETURN 65536;
      | ptINT32, ptCARD32, ptLONGWORD, ptPTR :
        RETURN 1 + INT64( MAX( CARDINAL ));
      | ptINT64, ptCARD64, ptQUADWORD :
        RETURN MAX( INT64 );
      END;
    | tkLink, tkOpaqueBaseLink, tkOpaqueWholeLink, tkReference :
      RETURN T^.OrdinalRange();
    END;
    RETURN 0;
  END OrdinalRange;

  VIRTUAL PROCEDURE CheckIfExpressionFits( E : TPExpression; VAR Ordinal : INT64 ) : BOOLEAN;
  VAR
    EV : CEValue;
    F : INT64;
    LT : TPType;
    R : INT64;
    ESign : BOOLEAN;
  BEGIN
    IF TypeKind IN typeLinks THEN
      RETURN Unwrap()^.CheckIfExpressionFits( E, Ordinal );
    ELSIF TypeKind = tkPrimitive THEN
      LT := Unwrap();
    ELSIF TypeKind = tkRange THEN
      LT := Unwrap()^.T^.Unwrap();
    ELSE
      RETURN FALSE;
    END;

    F := FirstOrdinal();
    R := OrdinalRange();
    E^.Evaluate( EV, 0 );
    Ordinal := EV.ToInteger();
    CASE E^.T^.Unwrap()^.PrimitiveType OF
    | ptINT8, ptINT16, ptINT32, ptINT64 :
      ESign := TRUE;
    ELSE
      ESign := FALSE;
    END;

    CASE LT^.PrimitiveType OF
    | ptCARD8, ptBYTE, ptBCHAR, ptBOOLEAN :
      Ordinal := INT64( CARD8( Ordinal ));
    | ptCARD16, ptWORD, ptWCHAR :
      Ordinal := INT64( CARD16( Ordinal ));
    | ptCARD32, ptLONGWORD :
      Ordinal := INT64( CARD32( Ordinal ));
    | ptCARD64 :
      RETURN NOT ESign OR ( Ordinal >= 0 );
    | ptINT64 :
      RETURN ESign OR ( Ordinal < R );
    END;
    IF Ordinal < F THEN
      RETURN FALSE;
    ELSIF Ordinal >= F + R THEN
      RETURN FALSE;
    ELSE
      RETURN TRUE;
    END;
  END CheckIfExpressionFits;

  VIRTUAL PROCEDURE OccupiedMemory() : CARDINAL;
  BEGIN
    CASE TypeKind OF
    | tkPrimitive :
      CASE PrimitiveType OF
      | ptBOOLEAN, ptINT8, ptCARD8, ptBCHAR, ptBYTE :
        RETURN 1;
      | ptINT16, ptCARD16, ptWCHAR, ptWORD :
        RETURN 2;
      | ptINT32, ptCARD32, ptLONGWORD :
        RETURN 4;
      | ptINT64, ptCARD64, ptQUADWORD :
        RETURN 8;
      END;
    | tkLink, tkOpaqueBaseLink, tkOpaqueWholeLink, tkReference, tkRange :
      RETURN T^.OccupiedMemory();
    END;
    RETURN 0;
  END OccupiedMemory;

  VIRTUAL PROCEDURE GenHead( G : Generator.TPGenerator; C : TGenerateControl; VAR Context : CARDINAL ) : TGenerateUnitMode;
  LABEL
    DoForward;
  VAR
    GUM : TGenerateUnitMode;
    LT : TPType;
  BEGIN
    IF gcDefault IN C THEN
      IF UnitKind = ukOpaqueTypeDeclaration THEN
        G^.Indent();
          G^.OutS( L'struct ' ); OutN( G, C );
          G^.OutS( L' { ' ); T^.Unwrap()^.Generate( G, gcsName ); G^.OutS( L' _; };' );
        G^.EOL();
        RETURN gumSimple;
      ELSIF eoForwarded IN Options THEN
        RETURN gumEmpty;
      ELSIF eoForward IN Options THEN
        (*?*) // BAD there should be some modifying of C, not EXCL/INCL
        EXCL( T^.Options, eoForwarded );
        GUM := T^.Generate( G, C + TGenerateControl{gcNameNested} );
        INCL( T^.Options, eoForwarded );
        RETURN GUM;
      ELSIF TypeKind = tkReference THEN
        RETURN gumSimple;
      ELSIF ( TypeKind = tkOpaqueBaseLink ) OR ( TypeKind = tkOpaqueWholeLink ) OR ( TypeKind = tkOpaqueWhole ) THEN // resolved opaque type
        GOTO DoForward;
      END;

      G^.Indent();
        IF T = NIL THEN
          G^.OutS( L'typedef void ' );
        ELSIF T = Types.TOrdinalNumber THEN
          G^.OutS( L'typedef ORDINAL ' );
        ELSE
          G^.OutS( L'typedef ' );
          T^.Generate( G, gcsExplicit );
          G^.OutSP();
        END;
        OutN( G, C );
        G^.OutSC();
      G^.EOL();
      RETURN gumSimple;

    ELSIF gcForward IN C THEN
  DoForward:
      G^.Indent();
        G^.OutS( L'struct ' );
        OutN( G, C );
        G^.OutSC();
      G^.EOL();
      RETURN gumSimple;

    ELSIF TypeKind = tkOpaqueBaseLink THEN
      OutQN( G, C );
      RETURN gumSimple;

    ELSIF TypeKind = tkOpaqueWholeLink THEN
      OutQN( G, C );
      G^.OutAST();
      RETURN gumSimple;

    ELSIF ( TypeKind = tkReference ) AND ( ADR( SELF ) <> Types.TADDRESS ) THEN
      LT := T^.UnwrapToFirstType();
      IF NOT( LT^.TypeKind IN typeLinks ) THEN // normal type
        GUM := T^.Generate( G, C );
      ELSIF LT^.UnitKind = ukOpaqueClassType THEN // generate class with correct name, skip tkOpaqueLink
        GUM := LT^.Unwrap()^.Generate( G, C );
      ELSE
        GUM := LT^.Generate( G, C );
      END;
      G^.OutAST();
      RETURN gumSimple;

    ELSIF ( ADR( SELF ) = Types.TTCHARB ) OR ( ADR( SELF ) = Types.TTCHARW ) THEN
      G^.OutCS( T^.N );
      RETURN gumSimple;

    ELSIF eoForwarded IN Options THEN
      OutN( G, gcsNameNested );
      RETURN gumSimple;

    ELSE
      OutQN( G, C );
      RETURN gumSimple;
    END;
  END GenHead;

  VIRTUAL PROCEDURE GenerateOrdinal( G : Generator.TPGenerator; Ord : INT64 );
  VAR
    S : StringsO.CString;
  BEGIN
    IF Unwrap()^.TypeKind <> tkPrimitive THEN
      RETURN;
    END;
    CASE Unwrap()^.PrimitiveType OF
    | ptBOOLEAN :
      CASE Ord OF
      | 0 : G^.OutS( L"false" );
      | 1 : G^.OutS( L"true" );
      END;
    | ptINT8, ptCARD8, ptINT16, ptCARD16, ptINT32, ptCARD32 :
      G^.OutNLI( Ord );
    | ptBCHAR, ptWCHAR :
      S[0] := WCHAR( Ord );
      IF Unwrap()^.PrimitiveType = ptBCHAR THEN
        G^.OutANSIEscapeCS( S, TRUE );
      ELSE
        G^.OutUNICODEEscapeCS( S, TRUE );
      END;
      S.Dispose();
    END;
  END GenerateOrdinal;

  PROCEDURE CheckAndGenerateCast( G : Generator.TPGenerator; TargetT : TPType; SourceIsConstant : BOOLEAN; VAR CastInfo : TCastInfo );
  LABEL
    CheckINTCARD;
  VAR
    LT1, LT2 : TPType;
    TM : TTypeModifier;
    LConstFlag, RConstFlag : BOOLEAN := FALSE;
  BEGIN
    CastInfo := TCastInfo{};
    IF TargetT^.IsFormal() THEN
      TM := TPFormalType( TargetT )^.TypeModifier;
    ELSE
      TM := tmUnknown;
    END;
    CASE TM OF
    | tmVAR, tmOUT, tmREF :
      INCL( CastInfo, ciReference );
      LT1 := TargetT^.UnwrapToBaseType();
      IF LT1^.TypeKind = tkClass THEN // cast to accept ancestor class
        IF NOT UnwrapToBaseType()^.Compatible( cmAssign, LT1 ) THEN // if classes are not compatible (as I am asigning into parameter) for assing they must be casted
           CastInfo := CastInfo + TCastInfo{ciCast};
           G^.OutLP(); TargetT^.Generate( G, gcsCast ); G^.OutAST(); G^.OutRP();
        END;
        G^.OutS( L"&" );
        RETURN;
      END;
    | tmCONST :
      IF TargetT^.Unwrap()^.PrimitiveType = ptStructure THEN
        IF IsFormal() THEN
          CastInfo := CastInfo + TCastInfo{ciCastConstPointer};
        ELSE
          CastInfo := CastInfo + TCastInfo{ciCastConstPointer, ciReference};
        END;
      END;
    END;

    LT1 := TargetT^.Unwrap();
    LT2 := Unwrap();
    IF TargetT = ADR( SELF ) THEN
      // do nothing
    ELSIF LT1 = Types.TUnknown THEN
      // no cast for var_arg parameters

    // special type compatibility cases, see CType.Compatible too
    ELSIF LT1^.TypeKind <> tkReference THEN
      IF LT1 = Types.TPTR THEN // cast, PTR := * is specialty o M2
        INCL( CastInfo, ciCast );
      ELSIF LT1^.TypeKind = tkProcedure THEN // cast, TProc := ADDRESS
        INCL( CastInfo, ciCast );
      ELSIF LT1^.TypeKind = tkSet THEN // formal SET
        IF TPSet( LT1 )^.IsLong() THEN
          IF ciCastConstPointer IN CastInfo THEN
            CastInfo := CastInfo + TCastInfo{ciCast};
          ELSIF ciReference IN CastInfo THEN
            CastInfo := CastInfo + TCastInfo{ciCast};
          ELSIF LT2 <> Types.TSet THEN // ELSE source is typed set constructor assigned with simple-constructed set (LT1 = {}). This is solved as AssignSetEmbeddedCall and casting must be ommited.
            CastInfo := CastInfo + TCastInfo{ciCast, ciReference, ciStructure};
          // ELSE
						// @@STRUCT SET ASSIGN
          END;
        END;
      ELSIF TM = tmUnknown THEN
        // CASTING using structure is not needed now, because variables moved to frame omit CONST formal type modifier -- this cannot be used, as C++ than requires for frame struct default constructor (to initialize "const" data)
        // IF SourceIsConstant AND (( LT1^.TypeKind = tkRecord ) OR ( LT1^.TypeKind = tkArray ) OR ( LT1^.TypeKind = tkClass )) THEN
        //  CastInfo := CastInfo + {ciCast, ciReference, ciStructure};
        // END;
      ELSIF Types.TStorage^.Compatible( cmOperation, LT1 ) THEN // cast, VAR Tf(BYTE) := Ta(INT8) is not allowed in CPP
        INCL( CastInfo, ciCast );
      ELSIF NOT( ciReference IN CastInfo ) OR ( TM <> tmCONST ) THEN  // cast only structures passed to CONST
        GOTO CheckINTCARD; // M2 defines assign compatibility between CARDINAL/INTEGER, this must be solved for CPP
      ELSIF NOT IsFormal() THEN
        INCL( CastInfo, ciCast );
      ELSIF TPFormalType( ADR( SELF ))^.TypeModifier <> tmCONST THEN
        INCL( CastInfo, ciCast );
      END;
    ELSIF LT2^.TypeKind <> tkReference THEN
      IF LT2 = Types.TPTR THEN // cast, PTR := * is specialty o M2
        INCL( CastInfo, ciCast );
      END; 
      // ELSE do nothing, neither CheckINTCARD -- after first IF (LT1<>tkReference) it should be solved
    ELSIF ( LT2^.T^.Unwrap()^.TypeKind = tkArray ) OR // cast, char(*)[xxx] is not compatible with char*
          ( LT2^.T^.Unwrap()^.TypeKind = tkOpenArray ) OR // cast, char(*)[xxx] is not compatible with char*
          ( LT2^.T^.Unwrap()^.TypeKind = tkStringArray ) OR // cast, char(*)[xxx] is not compatible with char*
          ( LT2 = Types.TADDRESS ) THEN // cast, CPP/M2 pointers compatibility differences
      IF LT1 <> Types.TADDRESS THEN
        INCL( CastInfo, ciCast );
      ELSIF TM = tmCONST THEN
        IF LT2 <> Types.TADDRESS THEN
          INCL( CastInfo, ciCast );
        END;
      ELSIF SourceIsConstant OR ( TM <> tmUnknown ) THEN
        INCL( CastInfo, ciCast );
      END;

    // CPP/M2 pointers compatibility differences
    ELSIF LT1 = Types.TADDRESS THEN // cast, VAR ADDRESS := T* is not compatible for CPP
      IF ( TM <> tmUnknown ) OR SourceIsConstant OR T^.IsFormal() AND ( TPFormalType( T )^.TypeModifier = tmCONST ) THEN
                                // detected in designator
                                                    // not detected in designator, probably POINTER TO CONST
        INCL( CastInfo, ciCast );
      END;
    // normal cast

    ELSE
  CheckINTCARD:
      // special check for CARDINAL/LONGCARD/DWORD = CARDINAL is unsigned int, LONGCARD is unsigned long; 
      // and for INTEGER/LONGINT = INTEGER is int, LONGINT is long
      LT1 := ADR( SELF );
      LOOP
        CASE LT1^.TypeKind OF
        | tkPrimitive :
          EXIT;
        | tkLink, tkReference :
          RConstFlag := RConstFlag OR LT1^.IsFormal() AND ( TPFormalType( LT1 )^.TypeModifier = tmCONST );
          IF LT1^.T^.TypeKind <> tkPrimitive THEN
            LT1 := LT1^.T;
          ELSE CASE LT1^.T^.PrimitiveType OF
          | ptINT8, ptINT16, ptINT32, ptINT64, ptCARD8, ptCARD16, ptCARD32, ptCARD64 :
            EXIT; // stop on link types (CARDINAL, INTEGER)
          ELSE // others must be fully unwrapped
            LT1 := LT1^.T;
          END; END;
        ELSE
          EXIT;
        END;
      END;
      LT2 := TargetT;
      LOOP
        CASE LT2^.TypeKind OF
        | tkPrimitive :
          EXIT;
        | tkLink, tkReference :
          LConstFlag := LConstFlag OR LT2^.IsFormal() AND ( TPFormalType( LT2 )^.TypeModifier = tmCONST );
          IF LT2^.T^.TypeKind <> tkPrimitive THEN
            LT2 := LT2^.T;
          ELSE CASE LT2^.T^.PrimitiveType OF
          | ptINT8, ptINT16, ptINT32, ptINT64, ptCARD8, ptCARD16, ptCARD32, ptCARD64 :
            EXIT; // stop on link types (CARDINAL, INTEGER)
          ELSE // others must be fully unwrapped
            LT2 := LT2^.T;
          END; END;
        ELSE
          EXIT;
        END;
      END;
      IF ( LT1 <> LT2 ) OR NOT LConstFlag AND RConstFlag THEN
        INCL( CastInfo, ciCast );
      END;

    // probalbly not needed as here types must be compatible
    // ELSIF NOT LT1^.Compatible( cmAssign, LT2 ) THEN
      // ASSERT( FALSE ); // never occurs
      // CastFlag := TRUE;

    END;
    
    IF ciCast IN CastInfo THEN
      IF ciStructure IN CastInfo THEN
        G^.OutS( L'(*(' );
      ELSE
        G^.OutLP();
      END;
      TargetT^.Generate( G, gcsCast );
      IF ciCastConstPointer IN CastInfo THEN
        EXCL( CastInfo, ciReference ); // not to generate & before element, so not RefRequest
        G^.OutS( L"&" );
      ELSIF TCastInfo{ciReference, ciStructure} * CastInfo <> TCastInfo{} THEN
        G^.OutAST();
      END;
      G^.OutRP();
    END;
    IF ciReference IN CastInfo THEN
      IF ciStructure IN CastInfo THEN
        G^.OutS( L"&(" );
      ELSE
        G^.OutS( L"&" );
      END;
    END;
  END CheckAndGenerateCast;

BEGIN
  UnitKind := ukSimpleTypeDef;
  SymbolKind := skType;
  TypeKind := tkUnknown;
  PrimitiveType := ptUnknown;
  Packing := 8;
  UW := NIL;
END CType;

//============================================================

CLASS IMPLEMENTATION CArray;

  VIRTUAL PROCEDURE OccupiedMemory() : CARDINAL;
  BEGIN
    RETURN Count() * T^.OccupiedMemory();
  END OccupiedMemory;

  VIRTUAL PROCEDURE GenHead( G : Generator.TPGenerator; C : TGenerateControl; VAR Context : CARDINAL ) : TGenerateUnitMode;
  VAR
    GUM : TGenerateUnitMode;
    LT : TPType;
  BEGIN
    IF gcDefault IN C THEN
      IF eoForwarded IN Options THEN
        RETURN gumEmpty;
      END;
      ASSERT( NOT N.Empty );
    ELSIF gcName IN C THEN
      RETURN SUPER.GenHead( G, C, Context );
    END;

    IF gcDefault IN C THEN
      G^.SetPacking( Packing );
      G^.Indent();
      IF eoUnnamed IN Options THEN
        G^.OutS( L'typedef ' ); GUM := T^.Generate( G, gcsExplicit );
          G^.OutSP();
        OutN( G, C );
        G^.OutS( L'[' ); GenerateCount( G ); G^.OutS( L']' );
        LT := T;
        WHILE GUM = gumSimpleWithTrailing DO
          GUM := LT^.Generate( G, TGenerateControl{gcExplicitTrailing} );
          LT := LT^.UnwrapToBaseType()^.T;
        END;
        G^.OutSC();
      ELSE
        G^.OutS( L'struct ' ); OutN( G, C ); G^.OutS( L' { ' ); // typedef not usable, Warning C4091 
          GUM := T^.Generate( G, gcsExplicit );
          G^.OutS( L' _[' ); GenerateCount( G ); G^.OutS( L']' );
          LT := T;
          WHILE GUM = gumSimpleWithTrailing DO
            GUM := LT^.Generate( G, TGenerateControl{gcExplicitTrailing} );
            LT := LT^.UnwrapToBaseType()^.T;
          END;
          G^.OutSC();
        G^.OutS( L' };' );
      END;
      G^.EOL();
      G^.ResetPacking( Packing );
      RETURN gumSimple;
    ELSIF gcExplicitLeading IN C THEN
      IF N.Empty OR ( TypeKind = tkStringArray ) THEN
        T^.Generate( G, C );
        RETURN gumSimpleWithTrailing;
      ELSIF gcForceArraySize IN C THEN
        SUPER.GenHead( G, C, Context );
        RETURN gumSimpleWithTrailing;
      ELSE
        RETURN SUPER.GenHead( G, C, Context );
      END;
    ELSE
      G^.OutS( L'[' ); GenerateCount( G ); G^.OutS( L']' );
      IF T^.Unwrap()^.TypeKind = tkArray THEN
        RETURN gumSimpleWithTrailing;
      ELSE
        RETURN gumSimple;
      END;
    END;
  END GenHead;

  PROCEDURE FirstIndex() : INT64;
  BEGIN
    IF ( _Count = -1 ) AND ( I <> NIL ) THEN
      _Count := I^.OrdinalRange();
      _First := I^.FirstOrdinal();
      _Last  := I^.LastOrdinal();
    END;
    RETURN _First;
  END FirstIndex;

  PROCEDURE LastIndex() : INT64;
  BEGIN
    FirstIndex();
    RETURN _Last;
  END LastIndex;

  PROCEDURE High() : CARDINAL;
  BEGIN
    FirstIndex();
    IF _Count = -1 THEN
      RETURN 0;
    ELSE
      RETURN CARDINAL( _Count - 1 );
    END;
  END High;

  PROCEDURE Count() : CARDINAL;
  BEGIN
    FirstIndex();
    IF _Count = -1 THEN
      RETURN 0;
    ELSE
      RETURN CARDINAL( _Count );
    END;
  END Count;

  PROCEDURE GenerateCount( G : Generator.TPGenerator );
  VAR
    n : ARRAY [0..31] OF WCHAR;
  BEGIN
    FirstIndex();
    IF _Count = -1 THEN
      n := L'';
    ELSE
      Strings.FromCARD64W( _Count, 10, OUT n );
    END;
    G^.OutS( n );
  END GenerateCount;

BEGIN
  TypeKind := tkArray;
  PrimitiveType := ptStructure;
  I := NIL;
  _Count := -1;
  _First := 0;
  _Last := 0;
END CArray;

//============================================================

CLASS IMPLEMENTATION CSet;

  VIRTUAL PROCEDURE OccupiedMemory() : CARDINAL;
  BEGIN
    RETURN CARDINAL( _Count );
  END OccupiedMemory;

  VIRTUAL PROCEDURE GenHead( G : Generator.TPGenerator; C : TGenerateControl; VAR Context : CARDINAL ) : TGenerateUnitMode;
  VAR
    GUM : TGenerateUnitMode;
    LT : TPType;
  BEGIN
    IF _Count > 8 THEN
      LT := T;
      T := Types.TBYTE;
      GUM := SUPER.GenHead( G, C, Context );
      T := LT;
    ELSIF gcDefault IN C THEN
      IF eoForwarded IN Options THEN
        RETURN gumEmpty;
      END;
      G^.Indent();
        G^.OutS( L'typedef ' );
        IF TU <> Types.TSet THEN
          TU^.Generate( G, gcsName ); G^.OutSP();
        ELSIF _Count > 4 THEN
          G^.OutS( L'LONGSET ' );
        ELSE
          G^.OutS( L'SET ' );
        END;  
        OutN( G, C );
        G^.OutSC();
      G^.EOL();
      RETURN gumSimple;
    ELSE
      GUM := CType.GenHead( G, C, Context );
    END;
    RETURN GUM;
  END GenHead;

  PROCEDURE GetItemType() : TPType;
  BEGIN
    IF T^.Unwrap()^.TypeKind = tkRange THEN
      RETURN T^.T;
    ELSE
      RETURN T;
    END;
  END GetItemType;

  PROCEDURE IsLong() : BOOLEAN;
  BEGIN
    RETURN _Count > 8;
  END IsLong;

BEGIN
  TypeKind := tkSet;
  PrimitiveType := ptUnknown;
  TU := Types.TSet;
END CSet;

//============================================================

TYPE
  TPOPTE = POINTER TO COPTE;

CLASS COPTE( avltree.CAVLTreeElem );
  O1, O2 : INT64;
  VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;
END COPTE;

CLASS IMPLEMENTATION COPTE;

  VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;
  BEGIN
    IF O1 < TPOPTE( pelem )^.O1 THEN
      RETURN -1;
    ELSIF O1 > TPOPTE( pelem )^.O1 THEN
      RETURN 1;
    ELSE
      RETURN 0;
    END;
  END Compare;

BEGIN
  O1 := 0;
  O2 := 0;
END COPTE;

//------------------------------------------------------------

CLASS CSHOPTE( COPTE ); // search helper
  VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;
END CSHOPTE;

CLASS IMPLEMENTATION CSHOPTE;

  VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;
  BEGIN
    IF ( O1 >= TPOPTE( pelem )^.O1 ) AND ( O2 <= TPOPTE( pelem )^.O2 ) THEN
      RETURN 0;
    ELSIF ( O1 <= TPOPTE( pelem )^.O1 ) AND ( O2 >= TPOPTE( pelem )^.O2 ) THEN
      RETURN 0;
    ELSE
      RETURN SUPER.Compare( i, pelem );
    END;
  END Compare;

END CSHOPTE;

//------------------------------------------------------------

CLASS IMPLEMENTATION COrdinalPresence;

  PROCEDURE Knows( Ordinal1, Ordinal2 : INT64 ) : BOOLEAN;
  VAR
    FOPTE : TPOPTE;
    OPTE : CSHOPTE;
  BEGIN
    OPTE.O1 := Ordinal1;
    OPTE.O2 := Ordinal2;
    RETURN Search( ADR( OPTE ), OUT FOPTE );
  END Knows;

  PROCEDURE Add( Ordinal1, Ordinal2 : INT64 );
  VAR
    OPTE : TPOPTE;
  BEGIN
    NEW( OPTE );
    OPTE^.O1 := Ordinal1;
    OPTE^.O2 := Ordinal2;
    Insert( OPTE );
  END Add; 

BEGIN
END COrdinalPresence;

//============================================================

CLASS IMPLEMENTATION CRecord;

  VIRTUAL PROPERTY Symbols GET : TPSymbols;
  BEGIN
    RETURN ADR( S );
  END Symbols;

  VIRTUAL PROCEDURE OccupiedMemory() : CARDINAL;
  BEGIN
    IF Empty THEN
      RETURN 0;
    ELSE
      RETURN 1; // TODO, there should be correct computation, now it is sufficient to return 0
    END;
  END OccupiedMemory;

  PROCEDURE ConstructorGetFirst( VAR T : TPType; VAR VariantSelector, Unnamed : BOOLEAN ) : BOOLEAN;
  BEGIN
    REPEAT UNTIL Stack.Pop() = NIL;
    Stack.Push( ADR( SELF ));
    RETURN Parse( TRUE, 0, T, VariantSelector, Unnamed, NIL );
  END ConstructorGetFirst;

  PROCEDURE ConstructorGetNext( VariantIndex : INT64; VAR T : TPType; VAR VariantSelector, Unnamed : BOOLEAN ) : BOOLEAN;
  BEGIN
    RETURN Parse( FALSE, VariantIndex, T, VariantSelector, Unnamed, NIL );
  END ConstructorGetNext;

  PRIVATE PROCEDURE Parse( FirstFlag : BOOLEAN; VariantIndex : INT64; VAR T : TPType; VAR VariantSelector, Unnamed : BOOLEAN; PField : POINTER TO TPSymbol ) : BOOLEAN;
  LABEL
    Next;
  VAR
    E1, E2 : TPExpression;
    EV1, EV2 : CEValue;
    I : INT64;
    PU, PUO, PLbl : TPUnit;
    b, e, ValidVariant : BOOLEAN;
  BEGIN
    IF PField <> NIL THEN
      PField^ := NIL;
    END;
    REPEAT
      PUO := Stack.Peek();
      IF PUO = NIL THEN
        b := FALSE;
      ELSIF FirstFlag THEN
        b := PUO^.GetFirst( PU );
      ELSE
        b := PUO^.GetNext( PU );
      END;
      IF b THEN
        CASE PU^.UnitKind OF
        | ukSimpleVarDecl, ukClassVarDecl, ukVariantSelector :
          VariantSelector := PU^.UnitKind = ukVariantSelector;
          Unnamed := VariantSelector AND ( eoUnnamed IN PU^.Options );
          T := DOM.TPSymbol( PU )^.T^.Unwrap();
          IF PField <> NIL THEN
            PField^ := DOM.TPSymbol( PU );
          END;
          RETURN TRUE;
        | ukFieldIds, ukVariantContainer :
          Stack.Push( PU );
          RETURN Parse( TRUE, VariantIndex, T, VariantSelector, Unnamed, PField );
        | ukVariantItem,
          ukVariantElse :
          IF NOT VariantSelector THEN
            GOTO Next;
          END;
          VariantSelector := FALSE;
          e := FALSE;
          LOOP
            IF NOT b THEN
              Project.SemErr( err._RecordDoesNotContainRequiredVariant );
              IF NOT PUO^.GetFirst( PU ) THEN // try to enter first variant
                RETURN FALSE;
              END;
              Stack.Push( PU );
              RETURN Parse( TRUE, 0, T, VariantSelector, Unnamed, PField );
            END;
            //--
            b := PU^.GetFirst( PLbl );
            ValidVariant := b;
            LOOP
              IF NOT b OR ( PLbl^.UnitKind <> ukVariantLabel ) THEN
                EXIT;
              END;
              IF NOT PLbl^.GetFirst( E1 ) THEN
                E1 := NIL;
              ELSIF NOT PLbl^.GetNext( E2 ) THEN
                E2 := NIL;
              END;
              IF E1 <> NIL THEN
                IF VariantIndex = MIN( INT64 ) THEN
                  I := MIN( INT64 );
                ELSE
                  E1^.Evaluate( EV1, 0 );
                  I := EV1.ToInteger();
                END;
                IF I = VariantIndex THEN
                  WHILE ( PLbl^.NextOf <> NIL ) AND ( TPUnit( PLbl^.NextOf )^.UnitKind = ukVariantLabel ) DO // skip other variants
                    b := PU^.GetNext( PLbl );
                  END;
                  Stack.Push( PU );
                  RETURN Parse( FALSE, 0, T, VariantSelector, Unnamed, PField );
                ELSIF ( VariantIndex > I ) AND ( E2 <> NIL ) THEN
                  E2^.Evaluate( EV2, 0 );
                  IF EV2.ToInteger() <= VariantIndex THEN
                    WHILE ( PLbl^.NextOf <> NIL ) AND ( TPUnit( PLbl^.NextOf )^.UnitKind = ukVariantLabel ) DO // skip other variants
                      b := PU^.GetNext( PLbl );
                    END;
                    Stack.Push( PU );
                    RETURN Parse( FALSE, 0, T, VariantSelector, Unnamed, PField );
                  END;
                END;
              END;
              b := PU^.GetNext( PLbl );
            END; // LOOP
            //--
            IF ValidVariant AND NOT e THEN
              e := TRUE;
              Project.SemErr( err._OnlyFirstVariantCanBeInitialized );
            END;
            b := PUO^.GetNext( PU );
          END; // LOOP

        END;
      END;

    Next:
      Stack.Pop();
    UNTIL Stack.Peek() = NIL;
    RETURN FALSE;
  END Parse;
  
  PROCEDURE GetIndexOfField( Field : TPSymbol; OUT ItemIndex : INT64 ) : BOOLEAN;
  VAR
    i : INT64;
    LField : TPSymbol;
    T : TPType;
    b : BOOLEAN;
    First : BOOLEAN;
  BEGIN
    REPEAT UNTIL Stack.Pop() = NIL;
    Stack.Push( ADR( SELF ));

    First := TRUE;
    i := 0;
    WHILE Parse( First, MIN( INT64 ), T, b, b, ADR( LField )) DO
      First := FALSE;
      IF Field = LField THEN
        ItemIndex := i;
        REPEAT UNTIL Stack.Pop() = NIL;
        RETURN TRUE;
      END;
      INC( i );
    END; // WHILE
    Project.SemErr( err._MemberIsNotFirstOrIsNotFound );
    RETURN FALSE;
  END GetIndexOfField;

  VIRTUAL PROCEDURE GenHead( G : Generator.TPGenerator; C : TGenerateControl; VAR Context : CARDINAL ) : TGenerateUnitMode;
  BEGIN
    IF gcDefault IN C THEN
      IF eoForwarded IN Options THEN
        RETURN gumEmpty;
      END;
      ASSERT( NOT N.Empty );
    ELSIF NOT N.Empty THEN
      RETURN SUPER.GenHead( G, C, Context );
    END;
    
    IF gcDefault IN C THEN
      G^.SetPacking( Packing );
      G^.Indent();
        G^.OutS( L'struct ' ); // typedef not usable, Warning C4091 
    ELSE
        G^.OutS( L'struct ' );
    END;
        IF N.Empty THEN
          G^.OutS( L'{' );
        ELSE
          OutN( G, C );
          G^.OutS( L' {' );
        END;
      G^.EOL();

    RETURN gumIndent;
  END GenHead;

  VIRTUAL PROCEDURE GenTail( G : Generator.TPGenerator; C : TGenerateControl; Context : CARDINAL );
  BEGIN
    IF gcDefault IN C THEN
      G^.LineRBSC();
      G^.ResetPacking( Packing );
    ELSE
      G^.Indent();
      G^.OutRB();
    END;
  END GenTail;

  PROCEDURE Add( Symbol : TPSymbol );
  VAR
    U : TPUnit;
  BEGIN
    IF NOT GetFirst( U ) THEN
      NEW( U );
      U^.UnitKind := ukFieldIds;
      SUPER.Add( U );
    END;
    U^.Add( Symbol );
  END Add;

  PROCEDURE HandleNestedTypes( c : TPModule );
  VAR
    SA : TSymbolAccess;
    T : TPType;
    b : BOOLEAN;
    First : BOOLEAN;
  BEGIN
    REPEAT UNTIL Stack.Pop() = NIL;
    Stack.Push( ADR( SELF ));
    First := TRUE;
    WHILE Parse( First, MIN( INT64 ), T, b, b, NIL ) DO
      First := FALSE;
      c^.HandleNestedSymbol( T^.Unwrap(), T^.Unwrap()^.OfSymbol, SA );
    END; // WHILE
    REPEAT UNTIL Stack.Pop() = NIL;
  END HandleNestedTypes;

BEGIN
  TypeKind := tkRecord;
  PrimitiveType := ptStructure;
  S.OfSymbol := ADR( SELF );
END CRecord;

//------------------------------------------------------------

CLASS IMPLEMENTATION CEnumeration;

  VIRTUAL PROCEDURE OccupiedMemory() : CARDINAL;
  BEGIN
    IF T <> Types.TUnknown THEN
      RETURN T^.OccupiedMemory();
    ELSIF OrdinalRange() > MAX( CARD32 ) THEN
      RETURN 8;
    ELSE
      RETURN 4;
    END;
  END OccupiedMemory;

  VIRTUAL PROCEDURE FirstOrdinal() : INT64;
  BEGIN
    RETURN First;
  END FirstOrdinal;

  VIRTUAL PROCEDURE LastOrdinal() : INT64;
  BEGIN
    RETURN Last;
  END LastOrdinal;

  VIRTUAL PROCEDURE OrdinalRange() : INT64;
  BEGIN
    RETURN Last - First + 1;
  END OrdinalRange;

  VIRTUAL PROCEDURE CheckIfExpressionFits( E : TPExpression; VAR Ordinal : INT64 ) : BOOLEAN;
  VAR
    C : TPConstant;
    EV : CEValue;
    n : ARRAY [0..31] OF WCHAR;
    b : BOOLEAN;
  BEGIN
    E^.Evaluate( EV, 0 );
    Ordinal := EV.ToInteger();
    IF Compatible( cmOperation, E^.T ) THEN // this is assured implcitly -- found directed to this enum must be from this enum,
      // and Ordinal is computed now
      RETURN TRUE;
    END;
    Strings.FromINT64W( Ordinal, 10, OUT n );
    b := Childs.GetFirst( OUT C );
    WHILE b AND NOT C^.DeclarationExpression^.N^.r.S.EqualsOA( n ) DO
      b := Childs.NextOf( C, OUT C );
    END;
    RETURN b;
  END CheckIfExpressionFits;

  VIRTUAL PROCEDURE GenHead( G : Generator.TPGenerator; C : TGenerateControl; VAR Context : CARDINAL ) : TGenerateUnitMode;
  BEGIN
    IF gcDefault IN C THEN
      IF eoForwarded IN Options THEN
        RETURN gumEmpty;
      END;
      ASSERT( NOT N.Empty );
    ELSIF NOT N.Empty THEN
      RETURN SUPER.GenHead( G, C, Context );
    END;
    
    IF gcDefault IN C THEN
      G^.Indent();
        G^.OutS( L'enum ' );
    ELSE
        G^.OutS( L'enum ' );
    END;
        IF N.Empty THEN
          G^.OutS( L'{' );
        ELSE
          OutN( G, C );
					IF T <> Types.TUnknown THEN
	          G^.OutS( L' : ' );
						T^.OutN( G, C );
					END;
          G^.OutS( L' {' );
        END;
      G^.EOL();

    RETURN gumIndent;
  END GenHead;

  VIRTUAL PROCEDURE GenSep( CONST BeforeU : TPUnit; G : Generator.TPGenerator; C : TGenerateControl );
  BEGIN
    G^.OutS( L',' ); G^.EOL();
  END GenSep;

  VIRTUAL PROCEDURE GenTail( G : Generator.TPGenerator; C : TGenerateControl; Context : CARDINAL );
  BEGIN
    G^.EOL();
    IF gcDefault IN C THEN
      G^.LineRBSC();
    ELSE
      G^.Indent();
      G^.OutRB();
    END;
  END GenTail;

  VIRTUAL PROCEDURE GenerateOrdinal( G : Generator.TPGenerator; Ord : INT64 );
  VAR
    C : TPConstant;
    n : ARRAY [0..31] OF WCHAR;
    b : BOOLEAN;
  BEGIN
    Strings.FromINT64W( Ord, 10, OUT n );
    b := Childs.GetFirst( OUT C );
    WHILE b AND NOT C^.DeclarationExpression^.N^.r.S.EqualsOA( n ) DO
      b := Childs.NextOf( C, OUT C );
    END;
    IF NOT b THEN
      RETURN;
    END;
    G^.OutCS( C^.N );
  END GenerateOrdinal;

BEGIN
  TypeKind := tkEnumeration;
  S.OfSymbol := ADR( SELF );
  First := 0;
  Last := 0;
  Iteratable := TRUE;
END CEnumeration;

//------------------------------------------------------------

CLASS IMPLEMENTATION CSubrange;

  VIRTUAL PROCEDURE FirstOrdinal() : INT64;
  BEGIN
    IF Count = -1 THEN
      OrdinalRange();
    END;
    RETURN First;
  END FirstOrdinal;

  VIRTUAL PROCEDURE LastOrdinal() : INT64;
  BEGIN
    IF Count = -1 THEN
      OrdinalRange();
    END;
    RETURN Last;
  END LastOrdinal;

  VIRTUAL PROCEDURE OrdinalRange() : INT64;
  VAR
    E1, E2 : TPExpression;
    V1, V2 : CEValue;
  BEGIN
    IF Count <> -1 THEN
      RETURN Count;
    ELSIF NOT Childs.GetFirst( OUT E1 ) OR NOT Childs.NextOf( E1, OUT E2 ) THEN
      RETURN -1;
    END;
    E1^.Evaluate( V1, 0 );
    E2^.Evaluate( V2, 0 );
    First := INT64( V1.ToInteger());
    Last  := INT64( V2.ToInteger());
    Count := Last - First + 1;
    RETURN Count;
  END OrdinalRange;

  VIRTUAL PROCEDURE GenerateOrdinal( G : Generator.TPGenerator; Ord : INT64 );
  BEGIN
    G^.OutNLI( Ord );
  END GenerateOrdinal;

BEGIN
  TypeKind := tkRange;
  Count := -1;
  First := 0;
  Last := 0;
END CSubrange;

//============================================================

CLASS IMPLEMENTATION CVariable;

  VIRTUAL PROCEDURE GenHead( G : Generator.TPGenerator; C : TGenerateControl; VAR Context : CARDINAL ) : TGenerateUnitMode;
  VAR
    GUM : TGenerateUnitMode;
    LT : TPType;
    i : BOOLEAN;
  BEGIN
    IF ( gcDefault IN C ) AND ( UnitKind = ukVariantSelector ) THEN
      RETURN gumSimple;
    ELSIF gcName IN C THEN
      OutN( G, C );
      RETURN gumSimple;
    ELSIF ( UnitKind = ukSimpleVarDecl ) AND ( eoMovedToFrame IN Options ) THEN // disables generating of symbols moved into frame
      RETURN gumEmpty;
    END;

    i := TRUE;
    CASE UnitKind OF
    | ukSimpleVarDecl :
      G^.Indent();
      IF ( eoDLLInterface IN Options ) AND NOT( gcDeferredFromDEF IN C ) THEN
        G^.OutS( L"extern " );
      END;
    | ukClassVarDecl, ukVariantSelector :
      G^.Indent();
    | ukCatchVarDecl :
    ELSE
      i := FALSE;
    END;

    IF UnitKind <> ukParamDef THEN
        GUM := T^.Generate( G, gcsExplicit + C * TGenerateControl{gcForceFormalFrameAddOn} ); // gcForceFormalFrameAddOn for frames variables
    ELSIF T^.Unwrap()^.TypeKind = tkOpenArray THEN
        IF coOASize IN Options THEN
          Types.TCARDINAL^.Generate( G, gcsExplicit );
          IF N.Empty THEN
            G^.OutS( L', ' );
          ELSE
            G^.OutSP();
            G^.OutCS( N );
            G^.OutS( L'_HIGH, ' );
          END;
        END;
        GUM := T^.Generate( G, gcsExplicitParameter );
    ELSE
        GUM := T^.Generate( G, gcsExplicitParameter );
    END;

        IF NOT N.Empty THEN
          G^.OutSP();
          G^.OutCS( N );
        END;
        LT := T;
        WHILE GUM = gumSimpleWithTrailing DO
          GUM := LT^.Generate( G, TGenerateControl{gcExplicitTrailing} );
          LT := LT^.UnwrapToBaseType()^.T;
        END;
        // ...type

    IF i THEN
      IF ( UnitKind <> ukClassVarDecl ) AND ( C * TGenerateControl{gcForceFormalFrameAddOn} = TGenerateControl{} ) AND ( InitE <> NIL ) THEN
          GenerateInitExpression( G, C, Context );
      END;
      IF UnitKind <> ukCatchVarDecl THEN
          G^.OutSC();
        G^.EOL();
      END;  
    END;

    RETURN gumSimple;
  END GenHead;

  PROCEDURE GenerateInitExpression( G : Generator.TPGenerator; C : TGenerateControl; VAR Context : CARDINAL );
  VAR
    TC : CTypedContainer;
  BEGIN
    IF Types.TSet^.Compatible( cmOperation, T ) AND TPSet( T^.Unwrap())^.IsLong() AND
			 (
         ( InitE^.T^.Unwrap() = Types.TSet ) OR
         ( InitE^.N^.r.N = DOM.enDesignator ) AND ( InitE^.N^.r.V^.r.DK = DOM.dkType )
       ) THEN
			// @@STRUCT SET ASSIGN
      // So, here we assign TSet to long typed set (something like: LongTypedSetVar = {} is written).
      // Such assignment will be solved by macro using embedded call.
      G^.OutSC();
      G^.OutS( L' ASSIGNS_( ' );
        G^.OutCS( N );
		    G^.OutS( L', ' );
	      InitE^.Generate( G, C );
				G^.OutS( L' )' );
		  // semicolon is emitted later
      RETURN;
    END;
    G^.OutS( L' = ' );
    IF InitE^.N^.r.N = enDesignator THEN
      InitE^.Generate( G, C );
    ELSIF Types.TString^.Compatible( cmOperation, T ) THEN
      TC.T := T;
      TC.GenHead( G, C, Context );
      InitE^.Generate( G, C );
      TC.GenTail( G, C, Context );
    ELSE
      InitE^.Generate( G, C );
    END;
  END GenerateInitExpression;

BEGIN
  UnitKind := ukSimpleVarDecl;
  SymbolKind := skVariable;
  InitE := NIL;
END CVariable;

//============================================================

CLASS IMPLEMENTATION CSelf;

  VIRTUAL PROCEDURE GenHead( G : Generator.TPGenerator; C : TGenerateControl; VAR Context : CARDINAL ) : TGenerateUnitMode;
  BEGIN
    IF UnitKind = ukSelf THEN
      G^.OutS( L"(*this)" );
    ELSE
      G^.OutS( L"this" );
    END;
    RETURN gumSimple;
  END GenHead;

BEGIN
  UnitKind := ukSelf;
END CSelf;

//============================================================

CLASS IMPLEMENTATION CSuperWrapper;

  VIRTUAL PROCEDURE GenHead( G : Generator.TPGenerator; C : TGenerateControl; VAR Context : CARDINAL ) : TGenerateUnitMode;
  BEGIN
    G^.OutCS( T^.N ); // T^.Generate( G, C );
    RETURN gumSimple;
  END GenHead;

BEGIN
  UnitKind := ukSuperWrapper;
  OfClass := NIL;
END CSuperWrapper;

//============================================================

CLASS CNestedUnit( CVariable );
  VIRTUAL PROCEDURE GenHead( G : Generator.TPGenerator; C : TGenerateControl; VAR Context : CARDINAL ) : TGenerateUnitMode;
  VIRTUAL PROCEDURE GenTail( G : Generator.TPGenerator; C : TGenerateControl; Context : CARDINAL );
END CNestedUnit;

CLASS IMPLEMENTATION CNestedUnit;

  VIRTUAL PROCEDURE GenHead( G : Generator.TPGenerator; C : TGenerateControl; VAR Context : CARDINAL ) : TGenerateUnitMode;
  VAR
    GUM : TGenerateUnitMode;
    LT : TPType;
    R : CType;
    b : BOOLEAN;
  BEGIN
    IF ( UnitKind = ukNestedFrame ) AND T^.Empty THEN // frame is empty
      RETURN gumEmpty;
    END;

    IF gcExplicit IN C THEN
      LT := T;
      R.TypeKind := tkReference;
      R.T := T;
      T := ADR( R );
      GUM := SUPER.GenHead( G, C, Context );
      T := LT;

    ELSIF TGenerateControl{gcPassNestedTopLevel, gcPassNestedInNested} * C <> TGenerateControl{} THEN
      b := gcPassNestedTopLevel IN C;
      IF b THEN
        CASE T^.Unwrap()^.TypeKind OF
        | tkReference, tkOpenArray : // generate no &
          b := FALSE;
        END;
      END;
      IF b THEN
        CASE TPFormalType( T )^.TypeModifier OF
        | tmVAR, tmREF, tmOUT :
          b := FALSE;
        END;
      END;
      IF b THEN
        IF ( OfSymbol^.UnitKind = ukSimpleClassDef ) OR ( OfSymbol^.UnitKind = ukClassClassDef ) THEN
          G^.OutS( L'this' );
          RETURN gumSimple;
        ELSE
          G^.OutS( L'&' );
        END;
      END;

      IF ( UnitKind = ukNestedParameter ) AND ( coParamsInFrame IN OfSymbol^.Options ) THEN
        G^.OutS( L'f_' );
        G^.OutCS( OfSymbol^.N );
        G^.OutS( L'->' );
      END;
      GUM := SUPER.GenHead( G, gcsName, Context );

    ELSIF coParamsInFrame IN OfSymbol^.Options THEN
      G^.OutS( L'f_' );
      G^.OutCS( OfSymbol^.N );
      G^.OutS( L'->' );
      GUM := SUPER.GenHead( G, gcsName, Context );

    ELSE
      G^.OutS( L'*' );
      GUM := SUPER.GenHead( G, gcsName, Context );
    END;

    RETURN GUM;
  END GenHead;

  VIRTUAL PROCEDURE GenTail( G : Generator.TPGenerator; C : TGenerateControl; Context : CARDINAL );
  BEGIN
  END GenTail;

BEGIN
  UnitKind := ukNestedParameter;
END CNestedUnit;

CLASS IMPLEMENTATION CNestedParameters;

  PROCEDURE Add( Symbol, FoundIn : TPSymbol ) : TPSymbol;
  VAR
    NU : POINTER TO CNestedUnit;
    NV : TPVariable; // nested variable
    b : BOOLEAN;
    CF : BOOLEAN;
  BEGIN
    CF := FoundIn^.SymbolKind = skClass;

    IF NOT CF AND ( P^.NF = NIL ) THEN // no frames used
      b := GetFirst( NU );
      LOOP
        IF NOT b THEN
          NEW( NU );
          NU^.SymbolKind := Symbol^.SymbolKind;
          NU^.T := Symbol^.T;
          NU^.N := Symbol^.N;
          NU^.OfSymbol := Symbol^.OfSymbol;
          SUPER.Add( NU );
          EXIT;
        ELSIF NU^.N = Symbol^.N THEN
          EXIT;
        END;
        b := GetNext( NU );
      END; // LOOP
      RETURN NU;

    ELSE // frames used
      IF CF THEN
        RETURN Symbol;
      ELSIF eoMovedToFrame IN Symbol^.Options THEN
        // a member of frame must be created only once
        RETURN Symbol;
      END;
      INCL( Symbol^.Options, eoMovedToFrame );

      IF TPProcedure( FoundIn )^.NFT = NIL THEN
        RETURN Symbol;
      END;
      // construct frame item
      NEW( NV );
      NV^.T := Symbol^.T;
      NV^.N := Symbol^.N;
      NV^.InitE := TPVariable( Symbol )^.InitE;
      TPVariable( Symbol )^.InitE := NIL;
      NV^.OfSymbol := TPProcedure( FoundIn );
      TPProcedure( FoundIn )^.NFT^.Add( NV );
      // if item is open array HIGH must be added too
      IF Symbol^.T^.IsOpenArray() AND ( coOASize IN Symbol^.Options ) THEN
        NEW( NV );
        NV^.T := Types.TCARDINAL;
        NV^.N := Symbol^.N;
        NV^.N.AppendOA( L"_HIGH" );
        NV^.OfSymbol := TPProcedure( FoundIn );
        TPProcedure( FoundIn )^.NFT^.Add( NV );
      END;

      RETURN Symbol;
    END;
  END Add;

BEGIN
  UnitKind := ukNestedParameters;
  P := NIL;
END CNestedParameters;

//------------------------------------------------------------

CLASS IMPLEMENTATION CNestedFrames;

  PROCEDURE Add( Symbol, FoundIn : TPSymbol );
  VAR
    NF : POINTER TO CNestedUnit;
    b : BOOLEAN;
  BEGIN
    b := GetFirst( NF );
    LOOP
      IF NOT b THEN
        NEW( NF );
        NF^.OfSymbol := FoundIn;
        IF FoundIn^.SymbolKind = skClass THEN
          NF^.UnitKind := ukNestedClassFrame;
          NF^.T := TPType( FoundIn );
          NF^.N.FromOA( L'c_' );
        ELSE
          NF^.UnitKind := ukNestedFrame;
          NF^.T := TPProcedure( FoundIn )^.NFT;
          NF^.N.FromOA( L'f_' );
        END;
        NF^.N.Append( FoundIn^.N );
        SUPER.Add( NF );
        EXIT;
      ELSIF NF^.OfSymbol = FoundIn THEN
        EXIT;
      END;
      b := GetNext( NF );
    END; // LOOP
  END Add;

BEGIN
  UnitKind := ukNestedFrames;
  P := NIL;
END CNestedFrames;

//------------------------------------------------------------

CLASS IMPLEMENTATION CProcedureType;

  VIRTUAL PROPERTY Symbols GET : TPSymbols;
  BEGIN
    RETURN ADR( S );
  END Symbols;

  VIRTUAL PROCEDURE Compatible( CM : TCompatibilityMode; PWith : TPType ) : BOOLEAN;
  VAR
    E : CARDINAL;
  BEGIN
    // check simple type compatibility rules
    PWith := PWith^.Unwrap();
    IF PWith^.TypeKind = tkMorphable THEN
      RETURN PWith^.Compatible( cmOperation, ADR( SELF ));
    ELSIF PWith = Types.TADDRESS THEN
      RETURN TRUE;
    ELSIF ADR( SELF ) = PWith THEN
      RETURN TRUE;
    ELSIF PWith^.TypeKind <> tkProcedure THEN
      RETURN FALSE;
    END;
    RETURN CompareHeader( TPProcedureType( PWith ), OUT E );
  END Compatible;

  PROCEDURE GetFirstFormalType( REF Stack : stacks.CPtrStack; OUT T : TPFormalType ) : BOOLEAN;
  BEGIN
    REPEAT UNTIL Stack.Pop() = NIL;
    Stack.Push( ADR( SELF ));
    RETURN GetFormalType( TRUE, REF Stack, OUT T );
  END GetFirstFormalType;

  PROCEDURE GetNextFormalType( REF Stack : stacks.CPtrStack; OUT T : TPFormalType ) : BOOLEAN;
  BEGIN
    RETURN GetFormalType( FALSE, REF Stack, OUT T );
  END GetNextFormalType;

  PROCEDURE GetFormalType( FirstFlag : BOOLEAN; REF Stack : stacks.CPtrStack; OUT T : TPFormalType ) : BOOLEAN;
  VAR
    PU, PUO : TPUnit;
    b : BOOLEAN;
  BEGIN
    REPEAT
      PUO := Stack.Peek();
      IF PUO = NIL THEN
        b := FALSE;
      ELSIF FirstFlag THEN
        b := PUO^.GetFirst( PU );
      ELSE
        b := PUO^.Childs.NextOf( list.TPListElem( Stack.PeekData() ), OUT PU );
      END;

      IF b THEN
        Stack.StoreData( PU );
        CASE PU^.UnitKind OF
        | ukSimpleTypeDef :
          T := TPFormalType( PU );
          RETURN TRUE;
        | ukParameterList,
          ukParamDefContainer :
          Stack.Push( PU );
          RETURN GetFormalType( TRUE, REF Stack, OUT T );
        | ukParamDef, ukNestedParamDef :
          T := TPFormalType( TPSymbol( PU )^.T );
          RETURN TRUE;
        END;
      END;

      Stack.Pop();
      FirstFlag := FALSE;
    UNTIL Stack.Peek() = NIL;
    RETURN FALSE;
  END GetFormalType;

  PROCEDURE CompareHeader( WithP : TPProcedureType; OUT Error : CARDINAL ) : BOOLEAN;
  VAR
    MFT, WFT : TPFormalType;
    MStack, WStack : stacks.CPtrStack; 
    mb, wb : BOOLEAN;
  BEGIN
    IF Options * cpsAll <> WithP^.Options * cpsAll THEN
      Error := err._HdrMismatchCallConv;
      RETURN FALSE;
    ELSIF AM <> WithP^.AM THEN
      Error := err._HdrMismatchAM;
      RETURN FALSE;
    // ELSIF IM <> WithP^.IM THEN -- checked in other place, there is not sufficient information
    //   RETURN FALSE;
    ELSIF CM <> WithP^.CM THEN
      Error := err._HdrMismatchCM;
      RETURN FALSE;
    ELSIF T^.UnwrapToBaseType() <> WithP^.T^.UnwrapToBaseType() THEN
      Error := err._HdrMismatchReturn;
      RETURN FALSE;
    END;
    mb := GetFirstFormalType( REF MStack, OUT MFT );
    wb := WithP^.GetFirstFormalType( REF WStack, OUT WFT );
    WHILE mb AND wb DO
      IF MFT^.IsOpenArray() <> WFT^.IsOpenArray() THEN
        Error := err._HdrMismatchOA;
        RETURN FALSE;
      ELSIF MFT^.TypeModifier <> WFT^.TypeModifier THEN
        Error := err._HdrMismatchTM;
        RETURN FALSE;
      ELSIF NOT MFT^.T^.Compatible( cmExact, WFT^.T ) THEN 
        Error := err._HdrMismatchTypes;
        RETURN FALSE;
      END;
      mb := GetNextFormalType( REF MStack, OUT MFT );
      wb := WithP^.GetNextFormalType( REF WStack, OUT WFT );
    END;
    IF mb AND NOT wb THEN
      Error := err._HdrLessParameters;
    ELSIF NOT mb AND wb THEN
      Error := err._HdrMoreParameters;
    ELSE
      RETURN TRUE;
    END;
    RETURN FALSE;
  END CompareHeader;

	PROCEDURE CopyThrows( From : TPProcedureType );
	BEGIN
		Throws.Dispose();
		From^.Throws.Reset();
		WHILE From^.Throws.MoveNext() DO
			Throws.Add( From^.Throws.Current, 0 );
		END; // WHILE
	END CopyThrows;

  VIRTUAL PROCEDURE GenHead( G : Generator.TPGenerator; C : TGenerateControl; VAR Context : CARDINAL ) : TGenerateUnitMode;
  VAR
    U : TPUnit;
  BEGIN
    IF gcDefault IN C THEN
      ASSERT( NOT N.Empty );
    ELSIF gcExplicitTrailing IN C THEN
      IF N.Empty THEN
        G^.OutRP();
        IF Childs.GetFirst( OUT U ) THEN
          G^.OutLP(); U^.Generate( G, gcsExplicit ); G^.OutRP();
        ELSE
          G^.OutS( L'()' );
        END;
      END;
      RETURN gumSimple;
    ELSIF NOT N.Empty THEN
      RETURN SUPER.GenHead( G, C, Context );
    END;

    IF NOT( gcExplicit IN C ) THEN
      G^.Indent();
      G^.OutS( L'typedef ' );
    END;  

      // impossible to use in typedef
      // IF cpCDecl IN Options THEN
      //   G^.OutS( L'extern "C" ' );
      // END;
      IF ( T = NIL ) OR ( T = Types.TUnknown ) THEN
        G^.OutS( L'void ' );
      ELSE
        T^.Generate( G, gcsExplicit );
        G^.OutSP();
      END;

      G^.OutLP(); 
      IF cpCDecl IN Options THEN
        G^.OutS( L'__cdecl ' );
      ELSIF cpStdCall IN Options THEN
        G^.OutS( L'__stdcall ' );
      ELSIF cpFastCall IN Options THEN
        G^.OutS( L'__fastcall ' );
      END;
      G^.OutAST();

    IF gcExplicit IN C THEN
      RETURN gumSimpleWithTrailing;
    ELSE
      OutN( G, C ); G^.OutRP();
      IF Childs.GetFirst( OUT U ) THEN
        G^.OutLP(); U^.Generate( G, gcsExplicit ); G^.OutRP(); G^.OutSC();
        G^.EOL();
      ELSE
        G^.OutLPRPSCEOL();
      END;
      RETURN gumSimple;
    END;  
  END GenHead;

BEGIN
  TypeKind := tkProcedure;
  IM := TInheritanceModifier{};
  Parameters := NIL;
  S.OfSymbol := ADR( SELF );
  OI := NIL;
END CProcedureType;

//------------------------------------------------------------

CLASS IMPLEMENTATION CProcedure;

  VIRTUAL PROCEDURE GenHead( G : Generator.TPGenerator; C : TGenerateControl; VAR Context : CARDINAL ) : TGenerateUnitMode;
  VAR
    GenIFace : BOOLEAN;
  BEGIN
    IF gcName IN C THEN
      IF OfSymbol^.SymbolKind <> skClass THEN
        OutN( G, C );
      ELSIF eoFinally IN Options THEN
        G^.OutS( L"~" ); OfSymbol^.Generate( G, gcsNameSimple );
      ELSE
        OutN( G, C );
      END;
      RETURN gumSimple;
    ELSIF gcForward IN C THEN
      // no eol
    ELSIF NOT( UnitKind IN uksRoutineDef ) THEN
      G^.EOL();
      IF NOT( gcForward IN C ) AND ( UnitKind <> ukNestedProcedureDecl ) THEN
        IF eoRegion IN Options THEN
          G^.Indent(); G^.OutS( L"#region procedure " ); OutN( G, C ); G^.EOL();
        ELSE
          G^.Indent(); G^.OutS( L"// #region procedure " ); OutN( G, C ); G^.EOL();
        END;
      END;

      G^.Enter();
      IF NOT NSD.Empty OR NOT NSP.Empty THEN
        IF NOT NSD.Empty THEN
          G^.LineS( L"// nested forwarded structured constants, types and frame types" );
          NSD.Generate( G, C + TGenerateControl{gcForceFormalFrameAddOn} );
        END;
        IF NOT NSP.Empty THEN
          G^.LineS( L"// nested procedures" );
          NSP.Generate( G, gcsForward );
          NSP.Generate( G, C );
          G^.EOL();
        END;
      END;
      G^.Leave();
    END;

    G^.Indent();
      IF cpCDecl IN Options THEN
        G^.OutS( L'extern "C" ' );
        GenIFace := ( UnitKind = ukProcedureDef ) OR ( OfSymbol^.UnitKind = ukProgram );
      ELSE
        GenIFace := TRUE;
      END;
      IF NOT GenIFace THEN
        // do nothing, extern "C" can be decorated only once
      ELSIF TEnvironmentOptions{eoDLLInterface, eoExport, eoPublishExports} * Options = TEnvironmentOptions{eoDLLInterface, eoExport, eoPublishExports} THEN
        G^.OutS( L"__IFACE " );
      END;
      IF UnitKind IN uksRoutineDef THEN
        IF IM * TInheritanceModifier{imAbstract, imVirtual} <> TInheritanceModifier{} THEN
          G^.OutS( L'virtual ' );
        ELSIF imFinal IN IM THEN
          IF G^.goManaged() THEN
            G^.OutS( L'__sealed ' );
          ELSE
            G^.OutS( L'virtual ' );
          END;
        END;
      END;
      IF cmINLINE IN CM THEN
        G^.OutS( L'inline ' );
      END;
      IF ( OfSymbol^.SymbolKind = skClass ) AND
         ( TEnvironmentOptions{eoInitially, eoFinally} * Options <> TEnvironmentOptions{} ) AND
         ( TEnvironmentOptions{eoAssignSelf} * Options = TEnvironmentOptions{} ) THEN
        // constructor and destructor do not have return type...
      ELSIF imCOM IN IM THEN
        G^.OutS( L'HRESULT ' );
      ELSIF ( T = NIL ) OR ( T = Types.TUnknown ) THEN
        G^.OutS( L'void ' );
      ELSE
        T^.Generate( G, gcsExplicit );
        // see note in OperatorDef
        // IF UnitKind <> ukOperatorDecl THEN
        //   G^.OutSP();
        // ELSIF TPOperatorDef( OD )^.T^.Unwrap()^.PrimitiveType = ptStructure THEN
        //   G^.OutS( L'& ' );
        // ELSE
          G^.OutSP();
        // END;
      END;
      IF cpCDecl IN Options THEN
        G^.OutS( L'__cdecl ' );
      ELSIF cpStdCall IN Options THEN
        G^.OutS( L'__stdcall ' );
      ELSIF cpFastCall IN Options THEN
        G^.OutS( L'__fastcall ' );
      END;

      IF NI <> NIL THEN
        OutN( G, gcsNameNested );
      ELSIF OfSymbol^.SymbolKind = skClass THEN
        IF UnitKind IN uksRoutineDecl THEN
          OfSymbol^.Generate( G, gcsName ); G^.OutS( L"::" );
        END;
        IF eoFinally IN Options THEN
          G^.OutS( L"~" );
        END;
        OutN( G, C );
      ELSE
        OutN( G, C );
      END;

      RETURN GenParameters( G, C );
  END GenHead;

  VIRTUAL PROCEDURE GenTail( G : Generator.TPGenerator; C : TGenerateControl; Context : CARDINAL );
  BEGIN
    IF UnitKind IN uksRoutineDef THEN
      IF imAbstract IN IM THEN
        G^.OutS( L' = 0' ); // pure virtual method
      END;
      G^.OutSC();
      G^.EOL();
    ELSIF UnitKind <> ukNestedProcedureDecl THEN
      IF eoRegion IN Options THEN
        G^.Indent(); G^.OutS( L"#endregion procedure " ); OutN( G, C ); G^.EOL();
      ELSE
        G^.Indent(); G^.OutS( L"// #endregion procedure " ); OutN( G, C ); G^.EOL();
      END;
    END;
  END GenTail;

  VIRTUAL PROCEDURE GenParameters( G : Generator.TPGenerator; C : TGenerateControl ) : TGenerateUnitMode;
  VAR
    GUM : TGenerateUnitMode;
  BEGIN
      G^.OutLP();
        GUM := Parameters^.Generate( G, gcsExplicit );
        IF ( imCOM IN IM ) AND ( T <> Types.TUnknown ) THEN
          IF GUM = gumNoIndent THEN
            G^.OutS( L", OUT " );
          ELSE
            G^.OutS( L" OUT " );
          END;
          T^.Generate( G, gcsExplicit ); G^.OutS( L"* RetVal " );
        END;
      G^.OutRP();
      IF gcForward IN C THEN
        G^.OutS( L"; // forwarded local/init" );
        G^.EOL();
        RETURN gumSimple;
      ELSIF eoForward IN Options THEN
        G^.OutS( L"; // forwarded" );
        G^.EOL();
        RETURN gumSimple;
      ELSE
        RETURN gumNoIndent;
      END;
  END GenParameters;

  PROCEDURE AddNestedSymbol( Symbol, FoundIn : TPSymbol ) : TPSymbol;
  BEGIN
    IF coParamsInFrame IN Options THEN
      NF^.Add( Symbol, FoundIn );
    END;
    IF Symbol^.UnitKind IN uksRoutineDef THEN
      // procedures are not passed as parameters
      RETURN Symbol;
    ELSIF Symbol^.UnitKind = ukNestedFrame THEN
      // nor frames nor class are passed as parameters, the are not added into frame too
      RETURN Symbol;
    ELSE
      RETURN NP^.Add( Symbol, FoundIn );
    END;
  END AddNestedSymbol;

BEGIN
  UnitKind := ukProcedureDef;
  SymbolKind := skProcedure;
  OD := NIL;
  CTDU := NIL;
  NFT := NIL;
  NSP.UnitKind := ukNestedForwardedProcedures;
  NI := NIL;
  NF := NIL;
  NP := NIL;
END CProcedure;

//------------------------------------------------------------

CLASS IMPLEMENTATION CFormalType;

  VIRTUAL PROCEDURE IsFormal() : BOOLEAN;
  BEGIN
    RETURN TRUE;
  END IsFormal;

  VIRTUAL PROCEDURE IsOpenArray() : BOOLEAN;
  BEGIN
    RETURN Unwrap()^.TypeKind = tkOpenArray;
  END IsOpenArray;

  VIRTUAL PROCEDURE GenHead( G : Generator.TPGenerator; C : TGenerateControl; VAR Context : CARDINAL ) : TGenerateUnitMode;
  BEGIN
    IF TGenerateControl{gcForceFormalFrameAddOn} * C = TGenerateControl{} THEN
      CASE TypeModifier OF
      | tmCONST :
        G^.OutS( L'const ' );
      | tmOUT :
        G^.OutS( L'OUT ' );
      END;
    END;

    IF eoForwarded IN T^.Options THEN
      T^.GenHead( G, C + TGenerateControl{gcNameNested}, Context );
    ELSE
      T^.GenHead( G, C, Context );
    END;

    IF gcCast IN C THEN
      // emit nothing, cast * is added in calling place
    ELSIF IsOpenArray() THEN // OA generates always only one *
      IF TypeKind = tkOpenArray THEN // but only if the type is DIRECTLY OA (not only link to OA)
        G^.OutAST();
      END;
    ELSIF TGenerateControl{gcForceFormalParameterAddOn, gcForceFormalFrameAddOn} * C = TGenerateControl{} THEN
      // do everything as normal, not parameter variable nor variable in stack-frame record is generated
    ELSE
      CASE TypeModifier OF
      | tmVAR, tmREF, tmOUT :
        G^.OutAST();
      | tmCONST :
        IF Unwrap()^.PrimitiveType = ptStructure THEN
          IF gcForceFormalFrameAddOn IN C THEN
            G^.OutAST();
          ELSE
            G^.OutS( L'&' );
          END;
        END;
      END; // CASE
    END; // IF

    RETURN gumSimple;
  END GenHead;

BEGIN
  TypeKind := tkLink;
  TypeModifier := tmUnknown;
END CFormalType;

//------------------------------------------------------------

CLASS IMPLEMENTATION CParameterContainer;

  VIRTUAL PROCEDURE GenHead( G : Generator.TPGenerator; C : TGenerateControl; VAR Context : CARDINAL ) : TGenerateUnitMode;
  VAR
    CI : TCastInfo;
    GUM : TGenerateUnitMode;
    OAFlag : BOOLEAN;
    ConstFlag : BOOLEAN := FALSE;
    REFFlag : BOOLEAN := FALSE;
  BEGIN
    IF CU = NIL THEN
      RETURN gumEmpty;
    ELSIF CU^.UnitKind = ukExpression THEN
      ConstFlag := TPExpression( CU )^.VI * TValueInfo{viConst} <> TValueInfo{};
    ELSE
      ConstFlag := TPDesignator( CU )^.VI * TValueInfo{viConst, viCONST} <> TValueInfo{};
    END;
    IF NOT ConstFlag AND AT^.IsFormal() AND ( TPFormalType( AT )^.TypeModifier = tmCONST ) THEN
      ConstFlag := TRUE;
    END;
    CASE PT^.TypeModifier OF
    | tmVAR, tmOUT, tmREF :
      REFFlag := TRUE;
    END;

    OAFlag := PT^.IsOpenArray();
    IF OAFlag THEN
      IF CU^.UnitKind = ukExpression THEN
        TPExpression( CU )^.AnalyzeAndGenerateOAHigh( G, PT );
      ELSE
        TPDesignator( CU )^.AnalyzeAndGenerateOAHigh( G, PT );
      END;
    ELSE
      AT^.CheckAndGenerateCast( G, PT, ConstFlag, CI );
      IF ciStructure IN CI THEN
        Context := 1;
      END;
    END; // IF PT^.OpenArray

    IF CV <> NIL THEN // cast variable set
      GUM := gumNoIndent;
      G^.OutLP(); G^.OutCS( CV^.N );
      G^.OutS( L" = (" );
    ELSIF Context = 1 THEN
      GUM := gumNoIndent;
    ELSE
      GUM := gumSimple;
    END;

    IF REFFlag THEN
      INCL( C, gcLValue );
    END;
    IF OAFlag THEN
      CU^.Generate( G, C + TGenerateControl{gcCharLiteralAsStringForOA} );
    ELSE
      CU^.Generate( G, C );
    END;
    RETURN GUM;
  END GenHead;
  
  VIRTUAL PROCEDURE GenTail( G : Generator.TPGenerator; C : TGenerateControl; Context : CARDINAL );
  BEGIN
    IF CV <> NIL THEN
      G^.OutS( L"), " ); G^.OutCS( CV^.N ); G^.OutRP();
    ELSIF Context = 1 THEN
      G^.OutS( L"))" );
    END;
  END GenTail;

BEGIN
  UnitKind := ukParameterContainer;
  PT := NIL;
  AT := NIL;
  CU := NIL;
  CV := NIL;
END CParameterContainer;

//============================================================

#if CPP_ACCESS_MODIFIERS #then
TYPE
  TPFriendWrapper = POINTER TO CFriendWrapper;

CLASS CFriendWrapper( CUnit );
  P : TPProcedureType;
  VIRTUAL PROCEDURE GenHead( G : Generator.TPGenerator; C : TGenerateControl; VAR Context : CARDINAL ) : TGenerateUnitMode;
END CFriendWrapper;

CLASS IMPLEMENTATION CFriendWrapper;

  VIRTUAL PROCEDURE GenHead( G : Generator.TPGenerator; C : TGenerateControl; VAR Context : CARDINAL ) : TGenerateUnitMode;
  BEGIN
    P^.Generate( G, C );
    RETURN gumSimple;
  END GenHead;

BEGIN
  UnitKind := ukFriendWrapper;
  P := NIL;
END CFriendWrapper;
#endif

//------------------------------------------------------------

CLASS IMPLEMENTATION CClass;

  VIRTUAL PROPERTY Symbols GET : TPSymbols;
  BEGIN
    RETURN ADR( S );
  END Symbols;

  VIRTUAL PROCEDURE Compatible( CM : TCompatibilityMode; PWith : TPType ) : BOOLEAN;
  VAR
    PSelf : TPClass;
  BEGIN
    // check simple type compatibility rules
    PWith := PWith^.Unwrap();
    IF PWith^.TypeKind = tkMorphable THEN
      RETURN PWith^.Compatible( cmOperation, ADR( SELF ));
    ELSIF ADR( SELF ) = PWith THEN
      RETURN TRUE;
    ELSIF PWith^.TypeKind <> tkClass THEN
      RETURN FALSE;
    END;
    // check class compatibility rules
    CASE CM OF
    | cmExact :
      RETURN FALSE;
    | cmAssign :
      LOOP
        IF PWith = NIL THEN
          RETURN FALSE;

        ELSIF imInterface IN IM THEN
           TPClass( PWith )^.Implements.Reset();
           WHILE TPClass( PWith )^.Implements.MoveNext() DO
              IF Compatible( CM, TPClass( TPClass( PWith )^.Implements.Current )) THEN
                 RETURN TRUE;
              END;
           END; // WHILE

        ELSIF ADR( SELF ) = PWith THEN
          RETURN TRUE;
        END;

        PWith := TPClass( PWith )^.I;
      END; // LOOP

    ELSE // cmOperation, objects are comparable if they are one or other direct ancestor of the other

      PSelf := I;
      LOOP
        IF PSelf = NIL THEN
          EXIT;
        ELSIF PSelf = TPClass( PWith ) THEN
          RETURN TRUE;
        END;
        PSelf := PSelf^.I;
      END; // first loop
      //..
      PSelf := TPClass( PWith );
      LOOP
        IF PSelf = NIL THEN
          EXIT;
        ELSIF ( CM = cmOperatorParameter ) AND ( imInterface IN IM ) THEN
           PSelf^.Implements.Reset();
           WHILE PSelf^.Implements.MoveNext() DO
              IF Compatible( CM, TPClass( PSelf^.Implements.Current )) THEN
                 RETURN TRUE;
              END;
           END; // WHILE
        ELSIF PSelf = ADR( SELF ) THEN
          RETURN TRUE;
        END;
        PSelf := PSelf^.I;
      END; // second loop
      //..
      RETURN FALSE;

    END;
  END Compatible;

  VIRTUAL PROCEDURE GenHead( G : Generator.TPGenerator; C : TGenerateControl; VAR Context : CARDINAL ) : TGenerateUnitMode;
  VAR
    first : BOOLEAN := TRUE;
    noclass : BOOLEAN := TRUE;
  BEGIN
    IF TGenerateControl{gcName, gcExplicitLeading} * C <> TGenerateControl{} THEN
      OutN( G, C );
      RETURN gumSimple;
    END;

    IF UnitKind <> ukNestedForwardedFrame THEN
      G^.EOL();
    END;
    G^.SetPacking( Packing );

    G^.Indent();
      IF imAbstract IN IM THEN
        IF G^.goManaged() THEN
          G^.OutS( L'__abstract ' );
        END;
      // | imVirtual, imCOM :
        // G^.OutS( L'virtual ' );
      ELSIF imFinal IN IM THEN
        IF G^.goManaged() THEN
          G^.OutS( L'__sealed ' );
        // ELSE
          // G^.OutS( L'virtual ' );
        END;
      END;
      G^.OutS( L'class ' );
      IF TEnvironmentOptions{eoExport} * Options = TEnvironmentOptions{} THEN
        // do nothing
      ELSIF TEnvironmentOptions{eoDLLInterface, eoPublishExports} * Options = TEnvironmentOptions{eoDLLInterface, eoPublishExports} THEN
        G^.OutS( L"__IFACE " );
      END;
      IF imInterface IN IM THEN
        G^.OutS( L"__declspec(novtable) " );
      END;
      OutN( G, C );
      IF UnitKind = ukNestedForwardedFrame THEN
         // fall down
      ELSIF Implements.Empty THEN

         IF imInterface NOT IN IM THEN
            G^.OutS( L': public OBJECT' );
         END;

      ELSE

         IF imInterface IN IM THEN
            G^.OutS( L': ' );
         ELSE
            Implements.Reset();
            WHILE Implements.MoveNext() DO
              noclass := noclass AND ( imInterface IN TPClass( Implements.Current )^.IM );
            END; // WHILE
            IF noclass THEN
               G^.OutS( L': public OBJECT, ' );
            ELSE
               G^.OutS( L': ' );
            END;
         END;

         Implements.Reset();
         WHILE Implements.MoveNext() DO
           IF first THEN
             G^.OutS( L'public ' );
             first := FALSE;
           ELSE
             G^.OutS( L', public ' );
           END;
           TPClass( Implements.Current )^.OutQN( G, C );
           noclass := noclass AND ( imInterface IN TPClass( Implements.Current )^.IM );
         END; // WHILE

      END;
    #if CPP_ACCESS_MODIFIERS #then
      IF UnitKind = ukNestedForwardedFrame THEN
         G^.OutS( L' { public:' );
      ELSE
         G^.OutS( L' {' );
      END;
    #else
      G^.OutS( L' { public:' );
    #endif

    G^.EOL();

    RETURN gumIndent;
  END GenHead;

  VIRTUAL PROCEDURE GenBody( G : Generator.TPGenerator; C : TGenerateControl; Indent : BOOLEAN; Context : CARDINAL );
  VAR
    CurrentAM : TAccessModifier;
    LU : DOM.TPUnit;
    b, g : BOOLEAN;
    #if CPP_ACCESS_MODIFIERS #then
      AM : TAccessModifier;
      LUU, LUUU : DOM.TPUnit;
    #endif
  BEGIN
    IF UnitKind = ukNestedForwardedFrame THEN // simplify generation
      SUPER.GenBody( G, C, Indent, Context );

    ELSIF NOT Childs.Empty THEN
      CurrentAM := amUnknown;
      G^.Enter();

      b := Childs.GetFirst( OUT LU );
      g := LU^.GenTo[G^.Mode()];
      WHILE b DO
        IF g THEN
          #if CPP_ACCESS_MODIFIERS #then
            AM := Project.Current()^.MEnv.ClassAM;
            CASE LU^.UnitKind OF
            | ukConstDeclBlock,
              ukTypeDefBlock :
              IF LU^.GetFirst( LUU ) THEN
                AM := TPSymbol( LUU )^.AM;
              END;
            | ukVarDeclBlock :
              IF LU^.GetFirst( LUU ) AND LUU^.GetFirst( LUUU ) THEN
                AM := TPSymbol( LUUU )^.AM;
              END;
            | ukVarDeclContainer : // compatible class data
              IF LU^.GetFirst( LUU ) THEN
                AM := TPSymbol( LUU )^.AM;
              END;
            | ukForwardedTypes :
              AM := CurrentAM;
            ELSE // procedure members
              IF {DOM.eoInitially, DOM.eoFinally} * LU^.Options = {} THEN
                AM := TPSymbol( LU )^.AM;
              ELSE
                AM := amPublic;
              END;
            END; // CASE
            IF AM <> CurrentAM THEN
              IF CurrentAM <> amUnknown THEN
                G^.Leave();
              END;
              CASE AM OF
              | amUnknown :
                AM := amInternal;
                G^.LineS( L'protected:' );
              | amPrivate :
                G^.LineS( L'private:' );
              | amInternal :
                G^.LineS( L'protected:' );
              ELSE
                G^.LineS( L'public:' );
              END;
              CurrentAM := AM;
              G^.Enter();
            END;
          #endif
          LU^.Generate( G, C );
        END;
        b := Childs.NextOf( LU, OUT LU );
        IF b THEN
          g := LU^.GenTo[G^.Mode()];
        END;
      END; // WHILE

      IF CurrentAM <> amUnknown THEN
        G^.Leave();
      END;
      G^.Leave();
    END;
  END GenBody;

  VIRTUAL PROCEDURE GenTail( G : Generator.TPGenerator; C : TGenerateControl; Context : CARDINAL );
  LABEL
    DoEnd;
  BEGIN
    IF imInterface IN IM THEN
      GOTO DoEnd;
    ELSIF UnitKind = ukNestedForwardedFrame THEN
      GOTO DoEnd;
    END;
  
    // constructor & destructor
    G^.EOL();
    G^.Enter();
    #if CPP_ACCESS_MODIFIERS #then
      G^.LineS( L'public:' );
      G^.Enter();
    #endif
        IF InitCode = NIL THEN
          G^.Indent(); OutN( G, C ); G^.OutS( L'(); // implicit empty constructor' ); G^.EOL();
        END;
        IF eoAssignSelf IN Options THEN
          G^.Indent(); G^.OutS( L'void ' ); OutN( G, C ); G^.OutS( '_INITIALLY_(); // init code shared in copy constructor and constructor' ); G^.EOL();
          G^.Indent();
            OutN( G, C );
            G^.OutS( L'( const ' ); OutN( G, C ); G^.OutS( '&' ); G^.OutS( L' Operand ); // implicit copy constructor' );
          G^.EOL();
        END;
        IF FinalCode = NIL THEN
          G^.Indent();
          IF eoVirtualFinally IN Options THEN
            G^.OutS( L'virtual ~' );
          ELSE
            G^.OutS( L'~' );
          END;
          OutN( G, C ); G^.OutS( L'(); // implicit empty destructor' ); G^.EOL();
        END;
    #if CPP_ACCESS_MODIFIERS #then
      G^.Leave();
    #endif
    G^.Leave();

  DoEnd:
    G^.LineRBSCCS( N );
    G^.ResetPacking( Packing );
  END GenTail;

  PROCEDURE GenerateClassVarInit( G : Generator.TPGenerator; C : TGenerateControl );
  VAR
    c : CARDINAL;
    U, SU, IU : TPUnit; // unit, subunit, itemunit
    b, f : BOOLEAN := TRUE;
  BEGIN
    b := GetFirst( U );
    WHILE b DO
      IF U^.UnitKind = ukVarDeclContainer THEN
        SU := U;
      ELSIF U^.UnitKind = ukVarDeclBlock THEN
        b := U^.GetFirst( SU );
      ELSE
        b := FALSE;
      END;
      WHILE b DO
        b := SU^.GetFirst( IU );
        WHILE b DO
          IF ( IU^.UnitKind = ukClassVarDecl ) AND ( TPVariable( IU )^.InitE <> NIL ) THEN
            IF f THEN
              f := FALSE;
              G^.LineS( L'// variables of class definition initialization' );
            END;
            G^.Indent(); TPVariable( IU )^.Generate( G, gcsName ); TPVariable( IU )^.GenerateInitExpression( G, C, c ); G^.OutSC(); G^.EOL();
          END; // IF
          b := SU^.GetNext( IU );
        END; // IF
        IF U = SU THEN
          EXIT;
        END;
        b := U^.GetNext( SU );
      END; // WHILE
      b := GetNext( U );
    END; // WHILE
    IF NOT f THEN
      G^.LineS( L'// end of definition variables' );
    END;
  END GenerateClassVarInit;

  PROCEDURE CheckDefinitionSemantics( c : TPModule );
  BEGIN
    IF TInheritanceModifier{imInterface, imAbstract} * IM <> TInheritanceModifier{} THEN
      RETURN;
    END;
    c^.M2^.ReportAllErrors();

    ExposedAbstract.Reset();
    WHILE ExposedAbstract.MoveNext() DO
      IF NOT S.Knows( ExposedAbstract.Current ) THEN
        c^.SemErrCS( err._ABSTRACTMustNotStayABSTRACT, TPSymbol( ExposedAbstract.Current )^.N );
      END;
    END; // WHILE

    c^.M2^.ReportFirstError();
  END CheckDefinitionSemantics;

  PROCEDURE CheckImplementationSemantics( c : TPModule );
  VAR
    LT : TPType;
    U, SU, IU : TPUnit; // unit, subunit, itemunit
    b : BOOLEAN;
  BEGIN
    c^.M2^.ReportAllErrors();
    b := GetFirst( U );
    WHILE b DO
      CASE U^.UnitKind OF
      | ukVarDeclBlock, ukVarDeclContainer :
        IF U^.UnitKind = ukVarDeclContainer THEN
          SU := U;
        ELSE
          b := U^.GetFirst( SU );
        END;
        WHILE b DO
          b := SU^.GetFirst( IU );
          WHILE b DO
            CASE IU^.UnitKind OF
            | ukClassVarDecl :
              IF eoClassInitialized IN IU^.Options THEN
                // OK, pass down
              ELSE
                LT := TPSymbol( IU )^.T;
                LOOP
                  IF LT = NIL THEN
                    c^.WarningCS( wrn._ClassVarNotInitialized, TPSymbol( IU )^.N );
                    EXIT;
                  ELSIF ( LT^.TypeKind = tkClass ) OR ( LT^.TypeKind = tkRecord ) THEN
                    EXIT;
                  ELSIF LT^.TypeKind <> tkArray THEN
                    c^.WarningCS( wrn._ClassVarNotInitialized, TPSymbol( IU )^.N );
                    EXIT;
                  ELSE
                    LT := LT^.T;
                  END;
                END; // LOOP
              END;
            | ukPropertyDef :
              IF imAbstract IN TPPropertyDef( IU )^.IM THEN
                // OK, no implementation
              ELSE CASE IU^.ImplementationState OF
              | isImplementedA :
              | isImplementedR :
                IF NOT( cmRO IN TPPropertyDef( IU )^.CM ) THEN
                  c^.SemErrCS( err._PropertySETImplementationIsMissing, TPSymbol( IU )^.N );
                END;
              | isImplementedW :
                IF NOT( cmWO IN TPPropertyDef( IU )^.CM ) THEN
                  c^.SemErrCS( err._PropertyGETImplementationIsMissing, TPSymbol( IU )^.N );
                END;
              ELSE
                c^.SemErrCS( err._PropertyImplementationIsMissing, TPSymbol( IU )^.N );
              END; END; // CASE, IF imAbstract
            END; // CASE
            b := SU^.GetNext( IU );
          END; // WHILE
          IF U = SU THEN
            b := FALSE;
          ELSE
            b := U^.GetNext( SU );
          END;
        END; // WHILE
      | ukMethodDef :
        IF imAbstract IN TPProcedureType( U )^.IM THEN
          // OK, no implementation
        ELSIF U^.ImplementationState <> isImplementedA THEN
          c^.SemErrCS( err._MethodImplementationIsMissing, TPSymbol( U )^.N );
        END;
      | ukIndexerDef :
        IF imAbstract IN TPProcedureType( U )^.IM THEN
          // OK, no implementation
        ELSE CASE U^.ImplementationState OF
        | isImplementedA :
        | isImplementedR :
          IF NOT( cmRO IN TPIndexerDef( U )^.CM ) THEN
            c^.SemErr( err._IndexerSETImplementationIsMissing );
          END;
        | isImplementedW :
          IF NOT( cmWO IN TPIndexerDef( U )^.CM ) THEN
            c^.SemErr( err._IndexerSETImplementationIsMissing );
          END;
        ELSE
          c^.SemErr( err._IndexerImplementationIsMissing );
        END; END; // CASE, IF imAbstract
      | ukOperatorDef :
        IF imAbstract IN TPProcedureType( U )^.IM THEN
          // OK, no implementation
        ELSIF U^.ImplementationState <> isImplementedA THEN
          CASE TPOperatorDef( U )^.O OF
          | opNEW :
            c^.SemErr( err._OperatorNEWImplementationIsMissing );
          | opDISPOSE :
            c^.SemErr( err._OperatorDISPOSEImplementationIsMissing );
          ELSE
            c^.SemErrCS( err._OperatorImplementationIsMissing, TPSymbol( U )^.N );
          END;
        END;
      END; // CASE
      b := GetNext( U );
    END; // WHILE
    c^.M2^.ReportFirstError();
  END CheckImplementationSemantics;

	PROCEDURE IsDescendantOf( Ancestor : TPClass; AllowSelf : BOOLEAN ) : BOOLEAN;
	VAR
		C : TPClass;
	BEGIN
		IF AllowSelf AND ( Ancestor = ADR( SELF )) THEN
			RETURN TRUE;
		END;
		C := I;
		WHILE ( C <> NIL ) AND ( C <> Ancestor ) DO
			C := C^.I;
		END;
		RETURN C <> NIL;
	END IsDescendantOf;

  PROCEDURE IsDescendantOfInterface() : BOOLEAN;
  VAR
    C : TPClass;
  BEGIN
    C := I;
    WHILE ( C <> NIL ) AND NOT( imInterface IN C^.IM ) DO
      C := C^.I;
    END;
    RETURN C <> NIL;
  END IsDescendantOfInterface;

	PROCEDURE IsDescendantOfException() : BOOLEAN;
	VAR
		C : TPClass := ADR( SELF );
	BEGIN
		WHILE C^.I <> NIL DO
			C := C^.I;
		END;
		IF NOT C^.N.EqualsOA( L"Exception" ) THEN
			RETURN FALSE;
		ELSIF C^.OfSymbol^.SymbolKind <> skModule THEN
			RETURN FALSE;
		ELSE
			RETURN C^.OfSymbol^.N.EqualsOA( L"Exceptions" );
		END;
	END IsDescendantOfException;

  PROCEDURE AddNestedFriend( AccessedMember : TPSymbol; P : TPProcedureType );
  #if CPP_ACCESS_MODIFIERS #then
    VAR
      FW : TPFriendWrapper;
  #endif
  BEGIN
    #if CPP_ACCESS_MODIFIERS #then
      IF ( AccessedMember = ADR( SELF )) OR ( P^.UnitKind IN uksMemberDecl ) THEN
        RETURN;
      ELSIF eoProcessed IN P^.Options THEN // already is a friend
        RETURN;
      END;  
      INCL( P^.Options, eoProcessed );
      IF NOT( eoDLLInterface IN Options ) THEN // classes in MOD can have friends
        NEW( FW );
        FW^.P := P;
        F.Add( FW );
      ELSIF AccessedMember^.AM = amPublic THEN
        // OK, pass down, conflict will not appear
      ELSE
        Project.Current()^.SemErrCS( 'The nested procedure {0} accesing this class member cannot be used in not-PUBLIC member of the CLASS defined in DEFINITION module.', Project.Current()^.CurrentP()^.N );
      END;
    #else
      RETURN; // solved by defaulting all generated methods as public
    #endif
  END AddNestedFriend;

   PROCEDURE AddAncestor( Ancestor : TPClass );
   BEGIN
      IF Implements.Contains( Ancestor ) THEN
         Project.Current()^.SemErrCS( err._IMPLEMENTSRedefined, Ancestor^.N );
      ELSE
         Implements.Add( Ancestor, 0 );
         // add abstract members
         Ancestor^.ExposedAbstract.Reset();
         WHILE Ancestor^.ExposedAbstract.MoveNext() DO
            IF NOT ExposedAbstract.Contains( Ancestor^.ExposedAbstract.Current ) THEN
               ExposedAbstract.Add( Ancestor^.ExposedAbstract.Current, 0 );
            END;
         END; // WHILE
      END;
   END AddAncestor;

BEGIN
  UnitKind := ukSimpleClassDef;
  SymbolKind := skClass;
  TypeKind := tkClass;
  PrimitiveType := ptStructure;
  IM := TInheritanceModifier{};
  S.OfSymbol := ADR( SELF );
  I := NIL;
  OD := NIL;
  InitCode := NIL;
  FinalCode := NIL;
END CClass;

//------------------------------------------------------------

CLASS IMPLEMENTATION CMember;
BEGIN
  UnitKind := ukMethodDecl;
  SymbolKind := skMethod;
  AM := amPrivate;
END CMember;

//------------------------------------------------------------

CLASS IMPLEMENTATION CPropertyDecl;
BEGIN
  UnitKind := ukPropertyDeclR;
  SymbolKind := skProperty;
END CPropertyDecl;

//------------------------------------------------------------

CLASS IMPLEMENTATION CIndexerDecl;
BEGIN
  UnitKind := ukIndexerDeclR;
  SymbolKind := skIndexer;
END CIndexerDecl;

//------------------------------------------------------------

CLASS IMPLEMENTATION COperatorDecl;
BEGIN
  UnitKind := ukOperatorDecl;
  SymbolKind := skOperator;
END COperatorDecl;

//------------------------------------------------------------

CLASS IMPLEMENTATION CClassDecl;
  
  VIRTUAL PROCEDURE GenHead( G : Generator.TPGenerator; C : TGenerateControl; VAR Context : CARDINAL ) : TGenerateUnitMode;
  VAR
    InitWithAssign : BOOLEAN := FALSE;
  BEGIN
    G^.EOL();
    G^.LineSCS( L'// CLASS IMPLEMENTATION ', OfClass^.N );

    IF InitCode = NIL THEN
      G^.Indent();
        OfClass^.Generate( G, gcsName ); G^.OutS( L"::" ); OfClass^.Generate( G, gcsName ); G^.OutS( L'()' );
        G^.OutS( L'{} // implicit empty constructor' );
      G^.EOL();
    ELSIF eoAssignSelf IN OfClass^.Options THEN
      InitWithAssign := TRUE;
      // generate constructor common for implicit and explicit form
      G^.EOL();
      G^.Indent();
      OfClass^.Generate( G, gcsName ); G^.OutS( L"::" ); OfClass^.Generate( G, gcsName ); G^.OutS( L'()' );
      G^.OutS( L' // implicit constructor' ); G^.EOL();
      G^.LineLB(); G^.Enter();
        G^.Indent(); OfClass^.Generate( G, gcsName ); G^.OutS( L'_INITIALLY_();' ); G^.EOL();
      G^.Leave(); G^.LineRB();

      IF InitCode^.UnitKind <> ukClassInitCode THEN // constructor is explicit, change its name
        INCL( InitCode^.Options, eoAssignSelf );
        OfClass^.S.Forget( TPSymbol( InitCode ));
        TPSymbol( InitCode )^.N.AppendOA( L'_INITIALLY_' );
        OfClass^.S.Add( TPSymbol( InitCode ));
      END;
    END;
    IF ( InitCode = NIL ) AND ( eoAssignSelf IN OfClass^.Options ) THEN // constructor is empty
      G^.EOL();
      G^.Indent();
      G^.OutS( L'void ' ); OfClass^.Generate( G, gcsName ); G^.OutS( L"::" ); OfClass^.Generate( G, gcsName ); G^.OutS( L'_INITIALLY_(){} // empty init code generated to satisfy definition' );
      G^.EOL();
    ELSIF ( InitCode <> NIL ) AND ( InitCode^.UnitKind = ukClassInitCode ) THEN // constructor is implicit
      G^.EOL();
      G^.Indent();
      IF eoAssignSelf IN OfClass^.Options THEN
        G^.OutS( L'void ' ); OfClass^.Generate( G, gcsName ); G^.OutS( L"::" ); OfClass^.Generate( G, gcsName ); G^.OutS( L'_INITIALLY_() // init code shared in copy constructor and constructor' );
      ELSE
        OfClass^.Generate( G, gcsName ); G^.OutS( L"::" ); OfClass^.Generate( G, gcsName ); G^.OutS( L'() // implicit constructor' );
      END;
      G^.EOL();
      G^.LineLB();
        InitCode^.Generate( G, C );
      G^.LineRB();
    END;

    IF eoAssignSelf IN OfClass^.Options THEN // create copy constructor
      G^.EOL();
      G^.Indent();
        OfClass^.Generate( G, gcsName ); G^.OutS( L'::' ); OfClass^.Generate( G, gcsName ); 
        G^.OutS( L'( const ' ); OfClass^.Generate( G, gcsName ); G^.OutS( '&' ); G^.OutS( L' Operand ) // implicit copy constructor' );
      G^.EOL();
      G^.LineLB();
      G^.Enter();
        IF InitCode <> NIL THEN
          G^.Indent(); OfClass^.Generate( G, gcsName ); G^.OutS( L'_INITIALLY_();' ); G^.EOL();
        END;
        G^.Indent(); G^.OutS( L'(*this) = Operand;' ); G^.EOL();
      G^.Leave();
      G^.LineRB();
    END;

    RETURN gumNoIndent;
  END GenHead;

  VIRTUAL PROCEDURE GenTail( G : Generator.TPGenerator; C : TGenerateControl; Context : CARDINAL );
  BEGIN
    IF FinalCode = NIL THEN
      G^.EOL();
      G^.Indent(); OfClass^.Generate( G, gcsName ); G^.OutS( L"::~" ); OfClass^.Generate( G, gcsName ); G^.OutS( L'()' );
      G^.OutS( L'{} // implicit empty destructor' ); G^.EOL();
    ELSIF FinalCode^.UnitKind  = ukClassFinalCode THEN
      G^.EOL();
      G^.Indent(); OfClass^.Generate( G, gcsName ); G^.OutS( L"::~" ); OfClass^.Generate( G, gcsName ); G^.OutS( L'()' );
      G^.OutS( L' // implicit destructor' ); G^.EOL();
      G^.LineLB();
      FinalCode^.Generate( G, C );
      G^.LineRB();
      G^.EOL();
    // ELSE
      // G^.LineS( L'// explicit destructor' );
      // FinalCode^.Generate( G, C );
    END;
    G^.LineSCS( L'// END CLASS IMPLEMENTATION ', OfClass^.N );
  END GenTail;

BEGIN
  UnitKind := ukClassDecl;
  OfClass := NIL;
  InitCode := NIL;
  FinalCode := NIL;
END CClassDecl;

//============================================================

CLASS IMPLEMENTATION CLexer;

  VIRTUAL PROCEDURE IsSpecial( CH : WCHAR ) : BOOLEAN;
  BEGIN
    RETURN M2^.IsSpecial( CH );
  END IsSpecial;

  VIRTUAL PROCEDURE ReadSpecial( CH : WCHAR ) : BOOLEAN;
  BEGIN
    RETURN M2^.ReadSpecial( CH );
  END ReadSpecial;

  VIRTUAL PROCEDURE DoSpecial( CONST Special : StringsO.CString );
  BEGIN
    M2^.DoSpecial( Special );
  END DoSpecial;

BEGIN
  M2 := NIL;
END CLexer;

//------------------------------------------------------------

CLASS IMPLEMENTATION CEnvironmentStack;

  PROCEDURE Push() : TPEnvironment;
  BEGIN
    INC( Current );
    IF Current >= Allocated THEN
      INC( Allocated, 4 );
      REALLOCATE( PData, Allocated * SIZE( TEnvironment ));
    END;
    IF Current >= 0 THEN
      PData^[Current] := PData^[Current - 1];
    END;
    RETURN ADR( PData^[Current] );
  END Push;

  PROCEDURE Pop() : TPEnvironment;
  BEGIN
    ASSERT( Current >= 0 );
    DEC( Current );
    RETURN ADR( PData^[Current] );
  END Pop;

  PROCEDURE PeekBottom() : TPEnvironment;
  BEGIN
    ASSERT( Current >= 0 );
    RETURN ADR( PData^[0] );
  END PeekBottom;

BEGIN
  PData := NIL;
  Allocated := 0;
  Current := -1;
END CEnvironmentStack;

//------------------------------------------------------------

CLASS CWarningListElem( list.CListElem );
  Warning : CARDINAL;
  On      : BOOLEAN;
END CWarningListElem;

CLASS IMPLEMENTATION CWarningListElem;
BEGIN
  Warning := 0;
  On := FALSE;
END CWarningListElem;

TYPE
  TPWarningListElem = POINTER TO CWarningListElem;

//------------------------------------------------------------

CLASS IMPLEMENTATION CModuleEnvironment;
BEGIN
  Timestamp := FIO.FileTime( 0, 0 ); 
  Prefix := mprfModula;
  ClassAM := amInternal;
  Storage.Fill( ADR( MIID ), SIZE( MIID ), 0 );
  Header := TRUE;
END CModuleEnvironment;

//------------------------------------------------------------

CLASS IMPLEMENTATION CModule;

  VIRTUAL PROPERTY Symbols GET : TPSymbols;
  BEGIN
    RETURN ADR( SelfS );
  END Symbols;

  PROCEDURE SD() : TPSymbols; // Symbols of DEF
  BEGIN
    RETURN ADR( OD^.SelfS );
  END SD;

  PROCEDURE SI() : TPSymbols; // Symbols of IMPL
  BEGIN
    RETURN ADR( OI^.SelfS );
  END SI;

  PROCEDURE SC() : TPSymbols; // Symbols of CURRENT
  BEGIN
    RETURN ADR( CU^.SelfS );
  END SC;

  PROCEDURE Compile() : CARDINAL;
  VAR
    ErrorCount : CARDINAL;
    Path : FIO.PathStrW;
    R : CARDINAL;
  BEGIN
    ErrorCount := 0;
    CompileState := csPending;
    Project.EnterSymbols( ADR( SELF ));

    FilePath.ToOA( OUT Path );
    R := Project.ExpandPath( Path );
    IF R = winerror.ERROR_SUCCESS THEN
      R := Lexer.Init( Path, OUT MEnv.Timestamp );
    END;
    IF R = winerror.ERROR_SUCCESS THEN
      // M2^.ReportAllErrors();
      M2^.Parse( ADR( SELF ), ADR( Lexer ));
      Lexer.Buffer.Close();
      CheckSemantics( FALSE );
      ErrorCount := M2^.ErrorCount();
    ELSIF coSolveTimestamps IN Options THEN
      INCL( Options, coFileNotFound );
    ELSE
      INCL( Options, coFileNotFound );
      ErrorCount := 1;
    END;

    IF ErrorCount = 0 THEN
      CompileState := csCompiled;
    ELSE
	    CompileState := csError;
    END;
    Project.LeaveSymbols( ADR( SELF ));

    RETURN ErrorCount;
  END Compile;

  PROCEDURE CheckSemantics( CheckDefinition : BOOLEAN );
  VAR
    InitWarningReported : BOOLEAN := FALSE;
  
    PROCEDURE CheckUnit( U : TPUnit; OnlyImports, InitiallyCallError, FinallyCallError : BOOLEAN );
    VAR
      U1 : TPUnit;
      b : BOOLEAN;
    BEGIN
      CASE U^.UnitKind OF
      | ukImport, ukImportExternal :
        b := U^.GetFirst( U1 );
        WHILE b DO
          IF eoInitially IN TPModule( U1 )^.OD^.Options THEN
            IF eoInitially IN TPModule( U1 )^.Options THEN
              // OK, module initialization called explicitly
            ELSIF NOT( eoInitially IN Options ) THEN
              Options := Options + TEnvironmentOptions{eoInitially};
              NEW( InitCode );
              InitCode^.UnitKind := DOM.ukModuleInitCode;
              Warning( wrn._ImportedModuleRequiresInitializationAutomaticOneCreated );
              Warning( wrn._AutomaticInitiallyNotCalled );
              InitWarningReported := TRUE;
            END;
            IF NOT InitWarningReported AND InitiallyCallError THEN
              Warning( wrn._InitiallyNotCalled );
              InitWarningReported := TRUE;
            END;
          END;
          IF eoFinally IN TPModule( U1 )^.OD^.Options THEN
            IF eoFinally IN TPModule( U1 )^.Options THEN
              // OK, module finalization called explicitly
            ELSIF NOT( eoFinally IN Options ) THEN
              Warning( wrn._ImportedModuleRequiresFinalizationAutomaticOneCreated );
              Options := Options + TEnvironmentOptions{eoFinally};
              NEW( FinalCode );
              FinalCode^.UnitKind := DOM.ukModuleFinalCode;
              // FinallyCallError := TRUE;
            END;
            // this warning is not needed
            // IF FinallyCallError THEN
            //   Warning( wrn._FinallyNotCalled );
            // END;
          END;
          b := U^.GetNext( U1 );
        END; // WHILE
      | ukProcedureDef :
        IF OnlyImports THEN
          // do nothing
        ELSIF U^.ImplementationState <> isImplementedA THEN
          SemErrCS( err._ProcedureNotImplemented, TPSymbol( U )^.N );
        END;
      | ukSimpleClassDef :
        IF OnlyImports THEN
          // do nothing
        ELSIF U^.ImplementationState = isImplementedA THEN
          // OK
        ELSIF imInterface IN TPClass( U )^.IM THEN
          // OK, interfaces does not have implementations
        ELSE
          SemErrCS( err._ClassNotImplemented, TPSymbol( U )^.N );
        END;
      END;
    END CheckUnit;

  VAR
    U : TPUnit;
    b : BOOLEAN;
    InitiallyCallError, FinallyCallError : BOOLEAN := FALSE;
  BEGIN
    IF CheckDefinition AND ( OI <> NIL ) THEN // definition need not to be checked, it was done during implementation check
      RETURN;
    ELSIF UnitKind = ukDefinition THEN
      RETURN;
    END;
    M2^.ReportAllErrors();

    IF UnitKind <> ukDefinition THEN

      // self init codes declaration
      IF NOT( eoInitially IN Options ) AND ( eoInitially IN OD^.Options ) THEN
        SemErr( err._ModuleINITIALLYNotDeclared );
      END;
      IF NOT( eoFinally IN Options ) AND ( eoFinally IN OD^.Options ) THEN
        SemErr( err._ModuleFINALLYNotDeclared );
      END;
      // check InitCode calling
      IF ( OI <> OD ) AND ( eoInitially IN OD^.Options ) THEN
        // init code OK, somebody other must call it
      ELSIF NOT( eoInitially IN OD^.Options ) THEN // OK, DEF does not have init code
        InitiallyCallError := ( InitCode = NIL ) OR ( InitCode^.UnitKind = ukModuleInitCode ) OR NOT( eoReferenced IN TPProcedure( InitCode )^.OD^.Options );
      ELSIF InitCode^.UnitKind = ukModuleInitCode THEN
        InitiallyCallError := UnitKind <> ukProgram;
      ELSIF eoReferenced IN TPProcedure( InitCode )^.OD^.Options THEN
        // OK init procedure is called
      ELSE
        InitiallyCallError := UnitKind <> ukProgram;
      END;
      // check FinalCode calling
      IF ( OI <> OD ) AND ( eoFinally IN OD^.Options ) THEN
        // init code OK, somebody other must call it
      ELSIF NOT( eoFinally IN OD^.Options ) THEN // OK, DEF does not have init code
        FinallyCallError := ( FinalCode = NIL ) OR ( FinalCode^.UnitKind = ukModuleFinalCode ) OR NOT( eoReferenced IN TPProcedure( FinalCode )^.OD^.Options );
      ELSIF FinalCode^.UnitKind = ukModuleFinalCode THEN
        FinallyCallError := UnitKind <> ukProgram;
      ELSIF eoReferenced IN TPProcedure( FinalCode )^.OD^.Options THEN
        // OK init procedure is called
      ELSE
        FinallyCallError := UnitKind <> ukProgram;
      END;
    
    END;

    // DEF childs
    b := ( OD <> OI ) AND OD^.Childs.GetFirst( OUT U );
    WHILE b DO
      CheckUnit( U, UnitKind = ukDefinition, FALSE, FALSE );
      b := OD^.Childs.NextOf( U, OUT U );
    END; // WHILE
    // MOD childs
    b := ( OI <> NIL ) AND OI^.Childs.GetFirst( OUT U );
    WHILE b DO
      CheckUnit( U, FALSE, InitiallyCallError, FinallyCallError );
      b := OI^.Childs.NextOf( U, OUT U );
    END; // WHILE

  END CheckSemantics;

  PROCEDURE ParsePragma( PragmaKind : Parser.TPragma; CONST PragmaString : StringsO.CString );

    PROCEDURE OnOff2Boolean( Value : ARRAY OF WCHAR; VAR B : BOOLEAN ) : BOOLEAN;
    BEGIN
      IF EQUALS( Value, L'on' ) OR EQUALS( Value, L'true' ) THEN
        B := TRUE;
      ELSIF EQUALS( Value, L'off' ) OR EQUALS( Value, L'false' ) THEN
        B := FALSE;
      ELSE
        SemErrS( err._IllegalLogicalValue, Value );
        RETURN FALSE;
      END;
      RETURN TRUE;
    END OnOff2Boolean;

    PROCEDURE OnOff2EnvBit( Value : ARRAY OF WCHAR; BEOI : TEnvironmentOptionsItem );
    BEGIN
      IF EQUALS( Value, L'on' ) OR EQUALS( Value, L'true' ) THEN
        INCL( CurE^.Options, BEOI );
      ELSIF EQUALS( Value, L'off' ) OR EQUALS( Value, L'false' ) THEN
        EXCL( CurE^.Options, BEOI );
      ELSE
        SemErrS( err._IllegalLogicalValue, Value );
      END;
    END OnOff2EnvBit;

    PROCEDURE Parse( PragmaKind : Parser.TPragma; CONST PragmaString : StringsO.CString ); FORWARD;

    PROCEDURE DecomposeByComma( CONST PragmaString : StringsO.CString );
    VAR
      Name : ARRAY [0..255] OF WCHAR;
      p, p1, p2 : CARDINAL;
      Pragma : StringsO.CString;
    BEGIN
      p := 1;
      LOOP
        IF p = MAX( CARDINAL ) THEN
          RETURN;
        ELSIF p > 1 THEN
          INC( p );
        END;
        p1 := PragmaString.Length;
        WHILE ( p < p1 ) AND ( PragmaString[p] IN WCHAR{ L' ', WCHAR( 13 ), WCHAR( 10 ), WCHAR( 9 ) } ) DO
          INC( p );
        END; // WHILE
        PragmaString.Substring( p, MAX( CARDINAL ), OUT Pragma );
        p1 := PragmaString.IndexOfOA( L"(", p );
        p2 := PragmaString.IndexOfOA( L",", p );
        IF p2 < p1 THEN
          p1 := p2;
        ELSE
          p1 := PragmaString.IndexOfOA( L")", p );
          p2 := PragmaString.IndexOfOA( L",", p1 );
        END;
        IF p1 < MAX( CARDINAL ) THEN
          Pragma.Remove( p1 - p, MAX( CARDINAL ));
          p1 := Pragma.IndexOfOA( L"(", 0 );
          IF p1 < MAX( CARDINAL ) THEN
            Pragma.SubstringOA( 0, p1, OUT Name );
            Pragma.Remove( 0, p1 + 1 );
          ELSE
            Pragma.ToOA( OUT Name );
          END;
        ELSE
          Pragma.ToOA( OUT Name );
          Pragma.Clear();
        END;
        Strings.TrimW( REF Name );
        IF EQUALS( Name, L"save" ) THEN
          Parse( Parser.prgSave, Pragma );
        ELSIF EQUALS( Name, L"restore" ) THEN
          Parse( Parser.prgRestore, Pragma );
        ELSIF EQUALS( Name, L"module" ) THEN
          Parse( Parser.prgModule, Pragma );
        ELSIF EQUALS( Name, L"name" ) THEN
          Parse( Parser.prgName, Pragma );
        ELSIF EQUALS( Name, L"call" ) THEN
          Parse( Parser.prgCall, Pragma );
        ELSIF EQUALS( Name, L"option" ) THEN
          Parse( Parser.prgOption, Pragma );
        ELSIF EQUALS( Name, L"warn" ) THEN
          Parse( Parser.prgWarn, Pragma );
        ELSE
          SemErrS( err._UnknownPragma, Name );
        END;
        p := p2;
      END; // LOOP
    END DecomposeByComma;

    PROCEDURE ParseData( Item : CARDINAL; CONST Data : StringsO.CString; VAR Key, Value : ARRAY OF WCHAR ) : BOOLEAN;
    VAR
      Slice : ARRAY [0..127] OF WCHAR;
      c : CARDINAL;
    BEGIN
      Data.ItemOA( WCHAR{L","}, 0, Item, FALSE, OUT Slice );
      IF Slice[0] = WCHAR( 0 ) THEN
        RETURN FALSE;
      END;
      c := Strings.IndexOfW( Slice, L"=>", 0 );
      IF c = MAX( CARDINAL ) THEN
        SemErrS( err._BadPragmaItemSyntax, Slice );
      ELSE
        Strings.SubstringW( Slice, 0, c, OUT Key );
        Strings.SubstringW( Slice, c + 2, MAX( CARDINAL ), OUT Value );
        Strings.TrimW( REF Key );
        Strings.TrimW( REF Value );
      END;
      RETURN TRUE;
    END ParseData;

    PROCEDURE Parse( PragmaKind : Parser.TPragma; CONST PragmaString : StringsO.CString );
    LABEL
      CallConv, Decoration;
    VAR
      i : CARDINAL;
      Key : ARRAY [0..31] OF WCHAR;
      Mark : TPSymbol;
      p : CARDINAL;
      Value : ARRAY [0..31] OF WCHAR;
      w : CARDINAL;
      b : BOOLEAN;
    BEGIN
      CASE PragmaKind OF
      | Parser.prgUnknown :
      | Parser.prgLine, Parser.prgBlock, Parser.prgCompatible :
        DecomposeByComma( PragmaString );

      | Parser.prgRegion :
        p := PragmaString.IndexOfOA( L"region", 0 ) + 6;
        w := PragmaString.Length;
        WHILE ( p < w ) AND ( PragmaString[p] = L' ' ) DO
          INC( p );
        END; // WHILE
        NEW( Mark );
        Mark^.UnitKind := ukRegionMark;
        PragmaString.Substring( p, MAX( CARDINAL ), OUT Mark^.N );
        AddUnit( Mark );
      | Parser.prgEndRegion :
        NEW( Mark );
        Mark^.UnitKind := ukRegionMark;
        AddUnit( Mark );

      | Parser.prgSave :
        CurE := EStack.Push();
      | Parser.prgRestore :
        CurE := EStack.Pop();

      | Parser.prgModule :
        IF CurU <> NIL THEN
          SemErrS( err._IllegalModuleAndNamePragmaPosition, L"module" );
          RETURN;
        END;
        i := 0;
        WHILE ParseData( i, PragmaString, Key, Value ) DO
          IF EQUALS( Key, L'init_code' ) THEN
            M2^.Warning( wrn._InitCodeIgnored );
          ELSIF EQUALS( Key, L'header' ) THEN
            OnOff2Boolean( Value, MEnv.Header );
          ELSE
            SemErrS( err._IllegalModulePragmaItem, Key );
          END;
          INC( i );
        END;

      | Parser.prgName :
        IF CurU <> NIL THEN
          SemErrS( err._IllegalModuleAndNamePragmaPosition, L"name" );
          RETURN;
        END;
        i := 0;
        WHILE ParseData( i, PragmaString, Key, Value ) DO
          IF EQUALS( Key, L'library' ) THEN
          ELSIF EQUALS( Key, L'prefix' ) THEN
            M2^.Warning( wrn._PrefixShouldBeDecoration );
            GOTO Decoration;
          ELSIF EQUALS( Key, L'decoration' ) THEN
        Decoration:
            IF EQUALS( Value, L'c' ) THEN
              MEnv.Prefix := mprfC;
            ELSIF EQUALS( Value, L'modula' ) THEN
              MEnv.Prefix := mprfModula;
            ELSIF EQUALS( Value, L'windows' ) THEN
              MEnv.Prefix := mprfWindows;
            ELSE
              SemErrS( err._IllegalDecorationPragmaValue, Value );
            END;
          ELSE
            SemErrS( err._IllegalNamePragmaItem, Key );
          END;
          INC( i );
        END;

      | Parser.prgCall :
        i := 0;
        WHILE ParseData( i, PragmaString, Key, Value ) DO
          IF EQUALS( Key, L'o_a_size' ) THEN
            OnOff2EnvBit( Value, coOASize );
          ELSIF EQUALS( Key, L'o_a_copy' ) THEN
            OnOff2Boolean( Value, b );
            IF b THEN
              M2^.Warning( wrn._OACopyNotSupported );
            END;
          ELSIF EQUALS( Key, L'var_arg' ) THEN
            OnOff2EnvBit( Value, coVarArg );
          ELSIF EQUALS( Key, L'c_arrays' ) THEN
            OnOff2EnvBit( Value, coCArrays );
          ELSIF EQUALS( Key, L'macro' ) THEN
            OnOff2EnvBit( Value, coMacro );
          ELSIF EQUALS( Key, L'result_optional' ) THEN
            OnOff2EnvBit( Value, coResultOptional );
          ELSIF EQUALS( Key, L'params_in_frame' ) THEN
            OnOff2EnvBit( Value, coParamsInFrame );
          ELSIF EQUALS( Key, L'prefix' ) THEN
            M2^.Warning( wrn._PrefixShouldBeConvention );
            GOTO CallConv;
          ELSIF EQUALS( Key, L'convention' ) THEN
        CallConv:
            IF EQUALS( Value, L'none' ) THEN
              CurE^.Options := CurE^.Options - cpsAll + cpsUndefined;
            ELSIF EQUALS( Value, L'cdecl' ) THEN
              CurE^.Options := CurE^.Options - cpsAll + cpsCDecl;
            ELSIF EQUALS( Value, L'stdcall' ) THEN
              CurE^.Options := CurE^.Options - cpsAll + cpsStdCall;
            ELSIF EQUALS( Value, L'fastcall' ) THEN
              CurE^.Options := CurE^.Options - cpsAll + cpsFastCall;
            ELSE
              SemErrS( err._IllegalConventionPragmaValue, Value );
            END;
          ELSE
            SemErrS( err._IllegalCallPragmaItem, Key );
          END;
          INC( i );
        END;

      | Parser.prgOption :
        i := 0;
        WHILE ParseData( i, PragmaString, Key, Value ) DO
          IF EQUALS( Key, L'typed_adr' ) THEN
            M2^.Warning( wrn._TypedADRNotSupported );
          ELSIF EQUALS( Key, L'volatile' ) THEN
            OnOff2EnvBit( Value, eoVolatile );
          ELSIF EQUALS( Key, L'export' ) THEN
            OnOff2EnvBit( Value, eoExport );
            M2^.Warning( wrn._ExportShouldBeDLLExport );
            IF UnitKind <> ukDefinition THEN
              M2^.SemErr( err._ExportCanBePlacedInDEFOnly );
            END;
          ELSIF EQUALS( Key, L'dll_export' ) THEN
            OnOff2EnvBit( Value, eoExport );
            IF UnitKind <> ukDefinition THEN
              M2^.SemErr( err._ExportCanBePlacedInDEFOnly );
            END;
          ELSIF EQUALS( Key, L'pack' ) THEN
            IF EQUALS( Value, L'1' ) THEN
              CurE^.Packing := 1;
            ELSIF EQUALS( Value, L'2' ) THEN
              CurE^.Packing := 2;
            ELSIF EQUALS( Value, L'4' ) THEN
              CurE^.Packing := 4;
            ELSIF EQUALS( Value, L'8' ) THEN
              CurE^.Packing := 8;
            ELSIF EQUALS( Value, L'16' ) THEN
              CurE^.Packing := 16;
            ELSIF EQUALS( Value, L'32' ) THEN
              CurE^.Packing := 32;
            ELSIF EQUALS( Value, L'64' ) THEN
              CurE^.Packing := 64;
            ELSE
              SemErrS( err._IllegalPackPragmaValue, Value );
            END;
          ELSIF EQUALS( Key, L'char_escape' ) THEN
            OnOff2EnvBit( Value, eoCharEscape );
          ELSIF EQUALS( Key, L'qualified_enum' ) THEN
            OnOff2EnvBit( Value, eoQualifiedEnum );
          ELSIF EQUALS( Key, L'wchar' ) THEN
            OnOff2EnvBit( Value, eoWCHAR );
          ELSIF EQUALS( Key, L'const_define' ) THEN
            OnOff2EnvBit( Value, eoUntypedConstAsDefine );
          ELSIF EQUALS( Key, L'size_as_types' ) THEN
            OnOff2EnvBit( Value, eoSizeAsTypes );
          ELSIF EQUALS( Key, L'leak_info' ) THEN
            OnOff2EnvBit( Value, eoLeakInfo );
          ELSE
            SemErrS( err._IllegalOptionPragmaItem, Key );
          END;
          INC( i );
        END;

      | Parser.prgWarn :
        i := 0;
        WHILE ParseData( i, PragmaString, Key, Value ) DO
          IF Strings.ToCARD32W( Key, 10, OUT w ) THEN
            IF OnOff2Boolean( Value, b ) THEN
              AddWarningSwitch( w, b );
            END;
          ELSE
            SemErrS( err._IllegalWarnPragmaNumber, Key );
          END;
          INC( i );
        END;
        
      ELSE
        ASSERT( FALSE );
      END;
    END Parse;

  BEGIN
    Parse( PragmaKind, PragmaString );
  END ParsePragma;

  PROCEDURE AddWarningSwitch( Warning : CARDINAL; On : BOOLEAN );
  VAR
    PWLE : TPWarningListElem;
  BEGIN
    NEW( PWLE );
    PWLE^.Warning := Warning;
    PWLE^.On := On;
    Warnings.Append( PWLE );
  END AddWarningSwitch;

  PROCEDURE PushOptions( Options : TEnvironmentOptions );
  BEGIN
    CurE := EStack.Push();
    CurE^.Options := Options;
  END PushOptions;

  PROCEDURE PopOptions();
  BEGIN
    CurE := EStack.Pop();
  END PopOptions;

  PROCEDURE EnterSymbols( CONST Symbols : CSymbols; EnterUnitToo, EnterChangesContext : BOOLEAN; WithDescriptor : TPDesignator );
  BEGIN
    SStack.Push( ADR( Symbols ), EnterChangesContext, WithDescriptor );
    CurS := TPSymbols( ADR( Symbols ));
    CurS^.StartLine := Lexer.Line;
    CurS^.StartColumn := Lexer.Pos;
    IF EnterUnitToo THEN
      EnterUnit( Symbols.OfSymbol );
    END;
  END EnterSymbols;

  PROCEDURE LeaveSymbols( LeaveUnitToo : BOOLEAN ) : TPSymbols;
  VAR
    LS : TPSymbols;
  BEGIN
    IF LeaveUnitToo THEN
      LeaveUnit();
    END;
    LS := SStack.Pop();
    LS^.StopLine := Lexer.Line;
    LS^.StopColumn := Lexer.Pos;
    IF SStack.Count = 0 THEN
      CurS := NIL;
    ELSE
      CurS := SStack.Peek();
    END;
    RETURN LS;
  END LeaveSymbols;

  PROCEDURE CurrentP() : TPProcedureType;
  BEGIN
    RETURN SStack.CurP;
  END CurrentP;

  PROCEDURE CurrentC() : TPClass;
  BEGIN
    RETURN SStack.CurC;
  END CurrentC;

  PROCEDURE GetWithDesignator( FoundIn : TPSymbol ) : TPDesignator;
  BEGIN
    SStack.Reset();
    LOOP
      IF NOT SStack.MoveNext() THEN
        RETURN NIL;
      ELSIF SStack.CurrentData = NIL THEN
        RETURN NIL;
      ELSIF TPSymbols( SStack.Current )^.OfSymbol = FoundIn THEN
        RETURN TPDesignator( SStack.CurrentData );
      END;
    END; // LOOP
  END GetWithDesignator;

  PROCEDURE GetNewUnit( UnitKind : TUnitKind; Owner : TPUnit; EnterFlag : BOOLEAN ) : TPUnit;
  VAR
    Unit : TPUnit;
  BEGIN
    NEW( Unit );
    Unit^.UnitKind := UnitKind;
    Unit^.Owner := Owner;
    IF EnterFlag THEN
      EnterUnit( Unit );
    END;  
    RETURN Unit;
  END GetNewUnit;

  PROCEDURE EnterNewUnit( UnitKind : TUnitKind ) : TPUnit;
  VAR
    Unit : TPUnit;
  BEGIN
    NEW( Unit );
    Unit^.UnitKind := UnitKind;
    AddUnit( Unit );
    EnterUnit( Unit );
    RETURN Unit;
  END EnterNewUnit;

  PROCEDURE EnterUnit( CONST Unit : TPUnit );
  BEGIN
    UStack.Push( Unit );
		CurU := TPUnit( Unit );
  END EnterUnit;

  PROCEDURE LeaveUnit() : TPUnit;
  VAR
    LU : TPUnit;
  BEGIN
    LU := UStack.Pop();
    IF UStack.Count = 0 THEN
      CurU := ADR( SELF );
    ELSE
      CurU := UStack.Peek();
    END;
    RETURN LU;
  END LeaveUnit;

  PROCEDURE MarkForwardTypeDeclPlace();
  BEGIN
    NEW( CurTypeC );
    CurTypeC^.UnitKind := ukForwardedTypes;
    AddUnit( CurTypeC );
  END MarkForwardTypeDeclPlace;

  PROCEDURE EnterNewCTDeclUnit( OfSymbol : TPSymbol ) : TPUnit;
  VAR
    VDU : TPVarDeclContainer;
  BEGIN
    IF OfSymbol = NIL THEN
      RETURN NIL;
    END;
    
    NEW( VDU );
    VDU^.OfSymbol := OfSymbol;
    IF OfSymbol^.UnitKind IN uksRoutineDecl THEN
      TPProcedure( OfSymbol )^.CTDU := VDU;
    ELSIF ( OfSymbol^.UnitKind IN uksRoutineDef ) AND ( TPProcedure( OfSymbol )^.OI <> NIL ) THEN
      TPProcedure( OfSymbol )^.OI^.CTDU := VDU;
    END;

    AddUnit( VDU );
    CTDStack.Push( VDU );
    CurCTDU := VDU;

    RETURN VDU;
  END EnterNewCTDeclUnit;

  PROCEDURE LeaveCTDeclUnit() : TPUnit;
  VAR
    LU : TPUnit;
  BEGIN
    LU := CTDStack.Pop();
    IF CTDStack.Count = 0 THEN
      CurCTDU := NIL;
    ELSE
      CurCTDU := CTDStack.Peek();
    END;
    RETURN LU;
  END LeaveCTDeclUnit;

  PROCEDURE AddToCTDeclUnit( Unit : TPUnit );
  BEGIN
    IF CurCTDU = NIL THEN
			CurU^.Add( Unit ); // for created structured constants created inside var decls, where CTDU is not set yet. This should create required const before usage.
    ELSE
      CurCTDU^.Add( Unit );
    END;
  END AddToCTDeclUnit;

  PROCEDURE CreateExpressionWithDesignator( D : TPDesignator; CopyDesignator : BOOLEAN; OUT E : TPExpression );
  BEGIN
    NEW( E );
    E^.T := D^.T;
    NEW( E^.N );
    E^.N^.T := D^.T;
    E^.N^.r.N := enDesignator;
    IF CopyDesignator THEN
      NEW( E^.N^.r.V );
      E^.N^.r.V^ := D^;
    ELSE
      E^.N^.r.V := D;
    END;
  END CreateExpressionWithDesignator;

  PROCEDURE HandleAuxConstantDesignatorRequest( VAR V : TPDesignator );
  VAR
    C : TPConstant;
  BEGIN
    NEW( C );
    SetNumId( C, TRUE, L'Const_' );
    C^.SymbolKind := skConstant;
    C^.T := V^.T;
    CreateExpressionWithDesignator( V, TRUE, OUT C^.DeclarationExpression );
    AddToCTDeclUnit( C );

    V^.r.DK := dkId;
    V^.r.Id := C;
  END HandleAuxConstantDesignatorRequest;

  PROCEDURE HandleAuxConstantExpressionRequest( TargetT : TPType; VAR E : TPExpression );
  VAR
    C : TPConstant;
  BEGIN
    IF TargetT = NIL THEN
      TargetT := E^.T;
    END;
  
    NEW( C );
    SetNumId( C, TRUE, L'Const_' );
    C^.SymbolKind := skConstant;
    C^.T := TargetT;

    NEW( C^.DeclarationExpression );
    C^.DeclarationExpression^.T := TargetT;
    NEW( C^.DeclarationExpression^.N );
    C^.DeclarationExpression^.N^.T := TargetT;
    C^.DeclarationExpression^.N^.r.N := enDesignator;
    NEW( C^.DeclarationExpression^.N^.r.V );
    C^.DeclarationExpression^.N^.r.V^.T := TargetT;
    C^.DeclarationExpression^.N^.r.V^.r.DK := dkType;
    NEW( C^.DeclarationExpression^.N^.r.V^.r.TC );
    C^.DeclarationExpression^.N^.r.V^.r.TC^.T := TargetT;
    C^.DeclarationExpression^.N^.r.V^.r.TC^.Add( E );

    // C^.DeclarationExpression := E;
    AddToCTDeclUnit( C );

    NEW( E );
    E^.T := TargetT;
    NEW( E^.N );
    E^.N^.r.N := enDesignator;
    NEW( E^.N^.r.V );
    E^.N^.r.V^.T := TargetT;
    E^.N^.r.V^.r.DK := dkId;
    E^.N^.r.V^.r.Id := C;
  END HandleAuxConstantExpressionRequest;

  PROCEDURE HandleAuxVariableRequest( T : TPType; VAR V : TPVariable );
  BEGIN
    NEW( V );
    SetNumId( V, FALSE, L'Var_' );
    V^.T := T;
    AddToCTDeclUnit( V );
  END HandleAuxVariableRequest;

  PROCEDURE SetCurrentStatement( S : TPStatement );
  BEGIN
    CurST := S;
  END SetCurrentStatement;

  PROCEDURE AddPrecedingStatement( S : TPUnit );
  BEGIN
    IF CurST = NIL THEN
      RETURN;
    END;  
    CurST^.Preceding.Add( S );
  END AddPrecedingStatement;

  PROCEDURE AddFollowingStatement( S : TPUnit );
  BEGIN
    IF CurST = NIL THEN
      RETURN;
    END;  
    CurST^.Following.Childs.InsertFirst( S );
  END AddFollowingStatement;
  
  PROCEDURE AddLeakInfoPushPop( SourceLine : CARDINAL );
  VAR
    A : TPSAssignment;
  BEGIN
    // push
    NEW( A );
    A^.UnitKind := ukSCall;
    NEW( A^.D );
    A^.D^.r.DK := dkEmbeddedProcedure;
    A^.D^.r.EP := epLeakINFOPush;
    A^.D^.r.U1 := ADR( SELF );
    A^.D^.r.D1 := SourceLine;
    AddPrecedingStatement( A );
    // pop
    NEW( A );
    A^.UnitKind := ukSCall;
    NEW( A^.D );
    A^.D^.r.DK := dkEmbeddedProcedure;
    A^.D^.r.EP := epLeakINFOPop;
    A^.D^.r.U1 := ADR( SELF );
    A^.D^.r.D1 := SourceLine;
    AddFollowingStatement( A );
  END AddLeakInfoPushPop;

  PROCEDURE EnterLoop( LoopType : TUnitKind ) : TPSLoop;
  VAR
    Loop : TPSLoop;
  BEGIN
    IF LoopType = ukSFor THEN
      NEW( TPSFor( Loop ));
    ELSE
      NEW( Loop );
    END;
    Loop^.UnitKind := LoopType;
    AddUnit( Loop );
    EnterUnit( Loop );

    SetNumId( ADR( Loop^.LC ), FALSE, L"LoopContinue_" );
    SetNumId( ADR( Loop^.LE ), FALSE, L"LoopExit_" );
    Loop^.Add( ADR( Loop^.LE ));

    LStack.Push( Loop );
    RETURN Loop;
  END EnterLoop;

  PROCEDURE LeaveLoop() : TPUnit;
  BEGIN
    LStack.Pop();
    RETURN LeaveUnit();
  END LeaveLoop;

  PROCEDURE LoopLabel( Exit : BOOLEAN ) : TPLabel;
  VAR
    Loop : TPSLoop;
  BEGIN
    Loop := LStack.Peek();
    IF Loop = NIL THEN
      RETURN NIL;
    END;
    IF Exit THEN
      INCL( Loop^.LE.Options, eoReferenced );
      RETURN ADR( Loop^.LE );
    ELSE
      INCL( Loop^.LC.Options, eoReferenced );
      RETURN ADR( Loop^.LC );
    END;
  END LoopLabel;

  PROCEDURE CreateSymbol( CONST Name : StringsO.CString; Kind : TSymbolKind; Add, ReportErrors : BOOLEAN; VAR Symbol : TPSymbol ) : BOOLEAN;
  BEGIN
    CASE Kind OF
    | skModule:
      NEW( TPModule( Symbol ));
    | skLabel :
      NEW( TPLabel( Symbol ));
    | skConstant:
      NEW( TPConstant( Symbol ));
    | skType:
      NEW( TPType( Symbol ));
    | skVariable:
      NEW( TPVariable( Symbol ));
    | skProcedure:
      NEW( TPProcedure( Symbol ));
    | skClass:
      NEW( TPClass( Symbol ));
    | skProperty :
      NEW( TPPropertyDef( Symbol ));
    ELSE
      Symbol := NIL;
      RETURN FALSE;
    END;
    Symbol^.N.Assign( Name );
    IF Add THEN
      AddSymbol( Symbol, ReportErrors );
    END;
    RETURN TRUE;
  END CreateSymbol;
  
  PROCEDURE AddSymbol( Symbol : TPSymbol; ReportErrors : BOOLEAN );
  BEGIN
    IF CurS^.Knows( Symbol ) THEN
      IF ReportErrors THEN
        M2^.SemErrCS( err._IdentifierRedefined, Symbol^.N );
      END;
      SetNumId( Symbol, FALSE, L"rdi " );
    END;
    CurS^.Add( Symbol );
  END AddSymbol;

  PROCEDURE AddForeignSymbol( Symbol : TPSymbol; ReportErrors : BOOLEAN );
  VAR
    C : TPConstant;
  BEGIN
    IF NOT SelfS.Knows( Symbol ) THEN

      NEW( C );
      IF Symbol^.SymbolKind = skConstant THEN
        C^.IsLinkOf := TPConstant( Symbol )^.Unwrap();
      ELSE
        C^.IsLinkOf := Symbol;
      END;
      C^.N := Symbol^.N;
      SelfS.Add( C );

      IF Symbol^.N.EqualsOA( L"ALLOCATE" ) THEN
        MEnv.MIID[miidAllocate] := C^.IsLinkOf;
      ELSIF Symbol^.N.EqualsOA( L"DEALLOCATE" ) THEN
        MEnv.MIID[miidDeallocate] := C^.IsLinkOf;
      ELSIF Symbol^.N.EqualsOA( L"CapitalizeA" ) THEN
        MEnv.MIID[miidCapA] := C^.IsLinkOf;
      ELSIF Symbol^.N.EqualsOA( L"CapitalizeW" ) THEN
        MEnv.MIID[miidCapW] := C^.IsLinkOf;
      ELSIF Symbol^.N.EqualsOA( L"LowerizeA" ) THEN
        MEnv.MIID[miidLowA] := C^.IsLinkOf;
      ELSIF Symbol^.N.EqualsOA( L"LowerizeW" ) THEN
        MEnv.MIID[miidLowW] := C^.IsLinkOf;
      END;

    ELSIF ReportErrors THEN
      M2^.SemErrCS( err._IdentifierRedefined, Symbol^.N );
    END;
  END AddForeignSymbol;

  PROCEDURE AddUnit( Unit : TPUnit );
  BEGIN
    CurU^.Add( Unit );
  END AddUnit;

  PROCEDURE CheckIfNested( Symbol : TPSymbol ) : BOOLEAN;
  BEGIN
    IF ( SStack.CurP <> NIL ) AND ( Symbol^.OfSymbol <> SStack.CurP ) THEN
      RETURN TRUE;
    END;
    CASE Symbol^.UnitKind OF
    | ukClassConstDecl,
      ukClassTypeDef,
      ukClassClassDef :
      RETURN TRUE;
    ELSE
      RETURN FALSE;
    END;
  END CheckIfNested;

  PROCEDURE AddToUnitOrNestedUnit( Symbol : TPSymbol );
  BEGIN
    IF CheckIfNested( Symbol ) THEN
      AddForwardedUnit( Symbol );
    ELSE
      CurU^.Add( Symbol );
    END;
  END AddToUnitOrNestedUnit;

  PROCEDURE GetSymbol( CONST Name : StringsO.CString; SymbolKind : TSymbolKind; ReportErrors, CheckOnlyInTop, UnwrapAliases : BOOLEAN; VAR Symbol, FoundIn : TPSymbol ) : BOOLEAN;
  VAR
    CS : TPSymbols;
    HintIdName : StringsO.TPString;
    LC : TPClass;
    LS : TPSymbol;
  BEGIN
    HintIdName := NIL;
    LS := NIL;
    SStack.Reset();
    LOOP
      IF SStack.MoveNext() THEN
        CS := TPSymbols( SStack.Current );
      ELSE
        EXIT;
      END;
      IF CheckOnlyInTop AND CS^.OfSymbol^.IsModule() THEN
        HintIdName := ADR( TPModule( CS^.OfSymbol )^.Name );
      END;
      IF CS^.Get( Name, LS ) OR
         ( CS^.OfSymbol <> NIL ) AND CS^.OfSymbol^.IsClass() AND GetClassSymbol( Name, TPClass( CS^.OfSymbol ), LS, LC ) THEN
        IF ( SymbolKind = skUnknown ) OR ( SymbolKind = LS^.SymbolKind ) THEN
          FoundIn := CS^.OfSymbol;
          EXIT;
        END;
        IF ReportErrors THEN
          SemErrUnknownId( SymbolKind, LS^.SymbolKind, HintIdName, Name );
        END;
        LS := NIL;
        EXIT;
      END;
      IF CheckOnlyInTop THEN
        EXIT;
      END;
    END; // LOOP
    IF LS = NIL THEN
      IF ReportErrors THEN
        SemErrUnknownId( SymbolKind, skUnknown, HintIdName, Name );
      END;
      RETURN FALSE;
    ELSIF UnwrapAliases AND ( LS^.SymbolKind = skConstant ) THEN
      Symbol := TPConstant( LS )^.Unwrap();
    ELSE
      Symbol := LS;
    END;
    RETURN TRUE;
  END GetSymbol;

  PROCEDURE GetClassSymbol( CONST Name : StringsO.CString; Class : TPClass; VAR Symbol : TPSymbol; VAR InClass : TPClass ) : BOOLEAN;
  VAR
    CC : TPClass;
    LS : TPSymbol;
  BEGIN
    CC := Class;
    LS := NIL;
    LOOP
      IF CC = NIL THEN
        EXIT;
      ELSIF CC^.S.Get( Name, LS ) THEN
        Symbol := LS;
        EXIT;
      ELSIF CC^.N.Equals( Name ) THEN
        LS := CC;
        Symbol := CC;
        EXIT;
      END;
      CC := CC^.I;
    END; // LOOP
    IF LS = NIL THEN
      RETURN FALSE;
    ELSE
      InClass := CC;
      RETURN TRUE;
    END;
  END GetClassSymbol;

  PROCEDURE SetNumId( Symbol : TPSymbol; Global : BOOLEAN; Prefix : ARRAY OF WCHAR );
  VAR
    Id : ARRAY [0..127] OF WCHAR;
    n : ARRAY [0..31] OF WCHAR;
  BEGIN
    INC( ASCount );
    Strings.FromCARD32W( ASCount, 10, OUT n );
    Strings.ConcatW( OUT Id, Prefix, n );
    Symbol^.N.FromOA( Id );
  END SetNumId;

  PROCEDURE HandleTypeDefDecl( NewFlag, OpaqueFlag : BOOLEAN; UK : TUnitKind; AM : TAccessModifier; LType, RType : TPType ) : TPType;
  VAR
    SwitchedOpaque : BOOLEAN := FALSE;
  BEGIN
    IF ( LType^.TypeKind = tkOpaqueWhole ) OR ( LType^.TypeKind = tkOpaqueBase ) THEN
      IF ( LType^.TypeKind = tkOpaqueWhole ) AND ( RType^.T^.TypeKind = tkOpaqueBase ) THEN
        SemErr( err._ResolvingOfOpaqueImpossible );
      END;
      INC( LType^.TypeKind ); // change to tkOpaqueWholeLink or tkOpaqueBaseLink
      LType^.UW := NIL; // reset UW
      IF NOT NewFlag THEN // create opaque declaration
        NEW( LType^.T ); // dummy variable, dirty trick
        LType^.T^.T := RType; // dirty trick
        RType := LType^.T; // dirty trick
      END;
      LType^.T := RType;
      RType^.N.Assign( LType^.N );
      RType^.UnitKind := ukOpaqueTypeDeclaration;
      RType^.OfSymbol := LType^.OfSymbol;
      SwitchedOpaque := TRUE; // existing opaque type was changed to link, it must not be added into symbols again
    ELSIF NewFlag THEN
      RType^.N.Assign( LType^.N );
      LType^.N.Dispose();
      LType^.DoneAndFree();
      LType := RType;
    ELSIF OpaqueFlag THEN
      LType^.TypeKind := DOM.tkOpaqueWhole;
    ELSE
      LType^.TypeKind := DOM.tkLink;
      LType^.T := RType;
    END;
    LType^.AM := AM;
    LType^.UnitKind := UK;

    IF SwitchedOpaque THEN // add declaration of opaque type, it must be generated as struct with _, because in DEF it is struct
      AddToUnitOrNestedUnit( RType );
    ELSE // add new type decl
      AddSymbol( LType, TRUE );
      AddToUnitOrNestedUnit( LType );
    END;

    RETURN LType;
  END HandleTypeDefDecl;

  PROCEDURE ForwardOpaqueType( T : TPType );
  VAR
    NT : TPType;
  BEGIN
    T := T^.Unwrap();
    NT := T^.T^.UnwrapToFirstType();
    IF ( T^.TypeKind = DOM.tkReference ) AND ( NT^.TypeKind = DOM.tkOpaqueBase ) AND NOT( DOM.eoProcessed IN NT^.Options ) THEN
      INCL( NT^.Options, DOM.eoProcessed );
      CreateSymbol( NT^.N, DOM.skType, FALSE, TRUE, NT );
      NT^.T := T;
      NT^.Options := NT^.Options + T^.Options * eosIF;
      TypeO.Add( NT );
    END;
  END ForwardOpaqueType;

  PROCEDURE ForwardComplexType( T : TPType );
  BEGIN
    IF T^.N.Empty THEN
      INCL( T^.Options, DOM.eoUnnamed );
    ELSE
      RETURN;
    END;
    IF T^.TypeKind = tkArray THEN
      SetNumId( T, TRUE, L'Ta_' );
    ELSIF T^.TypeKind = tkRecord THEN
      SetNumId( T, TRUE, L'Tr_' );
    ELSIF T^.TypeKind = tkSet THEN
      EXCL( T^.Options, DOM.eoUnnamed ); // big sets must be generated as structs, not arrays -- C arrays are pointers...
      SetNumId( T, TRUE, L'Ts_' );
    ELSE
      RETURN;
      // commented, RETURN added: unnamed pointers to primitive types need not to be named and defined as complex...
      // SetNumId( T, TRUE, L'Tx_' );
    END;
    CurTypeC^.Add( T );
  END ForwardComplexType;

  PROCEDURE HandleNestedSymbol( Symbol, FoundIn : TPSymbol; VAR SA : TSymbolAccess ) : BOOLEAN;
  VAR
    LC : TPConstant;
    LS : TPSymbol;
    LT : TPType;
    NSA : TSymbolAccess; // new SA
    OD : TPProcedureType;
    P : TPProcedure;
    CF : BOOLEAN;
    PF : BOOLEAN;
    TF : BOOLEAN;
    VF : BOOLEAN;
    b : BOOLEAN;
  BEGIN
    SA := saDirect;
    // IF ( SStack.CurP = NIL ) OR ( SStack.CurP^.UnitKind IN uksRoutineDef ) THEN
    // IF divided and its part is moved down: **1:
    IF SStack.CurP = NIL THEN
      RETURN FALSE;
    END;

    PF := Symbol^.SymbolKind = skProcedure;
    IF PF AND ( FoundIn = SStack.CurP ) THEN
      SA := saChildProcedureCall;
    END;
    CF := ( Symbol^.SymbolKind = skConstant ) AND ( Symbol^.T^.TypeKind <> tkEnumeration ); // constants being part of enum must not be forwarded
    VF := Symbol^.SymbolKind = skVariable;
    TF := Symbol^.SymbolKind = skType;
    IF PF OR VF OR TF OR CF = FALSE THEN // handling not needed
      RETURN FALSE;
    ELSIF TF AND ( FoundIn = NIL ) THEN
      RETURN FALSE;
    // **2: (see above)
    ELSIF SStack.CurP^.UnitKind IN uksRoutineDef THEN
      IF NOT TF THEN
        RETURN FALSE;
      ELSIF ( SStack.CurP^.OI = NIL ) OR ( TPProcedure( SStack.CurP^.OI )^.NI = NIL ) THEN
        RETURN FALSE;
      END;
    ELSIF TPProcedure( SStack.CurP )^.NI = NIL THEN
      RETURN FALSE;
    END;

    IF Symbol^.UnitKind = ukSelf THEN
      SA := saParentObject;
      IF SStack.CurC <> NIL THEN
        SStack.CurC^.AddNestedFriend( Symbol, SStack.CurP );
      END;
      RETURN TRUE;
    ELSIF Symbol^.UnitKind = ukSuperWrapper THEN
      SA := saParentObjectSymbol;
      IF SStack.CurC <> NIL THEN
        SStack.CurC^.AddNestedFriend( Symbol, SStack.CurP );
      END;
      RETURN TRUE;
    ELSIF FoundIn^.SymbolKind = skClass THEN
      TPClass( FoundIn )^.AddNestedFriend( Symbol, SStack.CurP );
      P := TPProcedure( SStack.CurP );
      LS := Symbol;
      LOOP
        IF P^.NI = NIL THEN
          EXIT;
        ELSIF P = SStack.CurP THEN // first level
          Symbol := P^.AddNestedSymbol( LS, FoundIn );
        ELSE // higher levels
          P^.AddNestedSymbol( LS, FoundIn );
        END;
        P := P^.NI;
      END; // LOOP
      SA := saParentObjectSymbol;
      RETURN TRUE;
    ELSIF NOT FoundIn^.IsProcedure( TRUE ) THEN
      RETURN FALSE;
    END;

    IF VF THEN // LOCAL DATA OF NESTED PROCEDURE
      NSA := saParentProcedureVariable;
      //...
      P := TPProcedure( SStack.CurP );
      LS := Symbol;
      IF FoundIn^.UnitKind IN uksRoutineDef THEN
        OD := TPProcedureType( FoundIn );
        FoundIn := OD^.OI;
      ELSE
        OD := TPProcedure( FoundIn )^.OD;
      END;
      IF OD = NIL THEN // OD = NIL is case of error
        RETURN SA = NSA;
      END;
      LOOP
        IF P^.OD = OD THEN
          EXIT;
        ELSIF P = SStack.CurP THEN // first level, add not-self-parameters only
          Symbol := P^.AddNestedSymbol( LS, FoundIn );
        ELSE // higher levels
          P^.AddNestedSymbol( LS, FoundIn );
        END;
        P := P^.NI;
        SA := NSA;
      END; // LOOP
      //...
      RETURN SA = NSA;
    
    ELSIF CF THEN // move constant to forward place of owning procedure
      IF eoForwarded IN Symbol^.Options THEN
        RETURN TRUE;
      END;
      INCL( Symbol^.Options, eoForwarded );
      // type must be forwarded too
      HandleNestedSymbol( Symbol^.T, Symbol^.T^.OfSymbol, NSA );
      // the constant itself
      NEW( LC );
      LC^.IsLinkOf := TPConstant( Symbol );
      INCL( LC^.Options, eoForward );
      TPProcedure( FoundIn )^.NSD.Add( LC );
      RETURN TRUE;
      
    ELSIF TF THEN // move type to forward place of owning procedure
      IF eoForwarded IN Symbol^.Options THEN
        RETURN TRUE;
      END;
      // type of type must be forwarded too
      CASE TPType( Symbol )^.Unwrap()^.TypeKind OF
      | tkArray, tkReference :
        HandleNestedSymbol( Symbol^.T^.Unwrap(), Symbol^.T^.Unwrap()^.OfSymbol, NSA );
      | tkRecord : // complex matter
        TPRecord( Symbol )^.HandleNestedTypes( ADR( SELF ));
      END;
      // the type itself
      INCL( Symbol^.Options, eoForwarded );
      NEW( LT );
      LT^.T := TPType( Symbol );
      LT^.TypeKind := tkLink;
      INCL( LT^.Options, eoForward );
      TPProcedure( FoundIn )^.NSD.Add( LT );
      RETURN TRUE;

    ELSE // IF PF AND ( TPProcedure( SStack.CurP )^.OD <> Symbol ) THEN // nested procedure used in nested procedure AND not handle self
         // ELSE // recursive call to self -- I need not to pass frames, but I need to generate proper nested name
      // both, self or not self, always a procedure must be marked as Peer to generate nested name
      SA := saPeerProcedureCall;
      // moreover, the called procedure's stacks must be propagated to handled symbol to access all frames
      //...
      P := TPProcedure( SStack.CurP );
      IF FoundIn^.UnitKind IN uksRoutineDef THEN
        OD := TPProcedureType( FoundIn );
      ELSE
        OD := TPProcedure( FoundIn )^.OD;
      END;
      IF OD = NIL THEN // OD = NIL is case of error
        RETURN TRUE;
      END;
      //... parameters not in frames
      IF TPProcedureType( Symbol )^.OI^.NP <> NIL THEN
        b := TPProcedureType( Symbol )^.OI^.NP^.GetFirst( LS );
        WHILE b DO 
          LOOP
            IF P^.OD = OD THEN
              EXIT;
            ELSE
              P^.AddNestedSymbol( LS, LS^.OfSymbol );
            END;
            P := P^.NI;
          END; // LOOP
          b := TPProcedureType( Symbol )^.OI^.NP^.GetNext( LS );
        END; // WHILE
      END;
      // ... parameters in frames
      IF TPProcedureType( Symbol )^.OI^.NF <> NIL THEN
        b := TPProcedureType( Symbol )^.OI^.NF^.GetFirst( LS );
        WHILE b DO
          IF LS^.UnitKind = ukNestedClassFrame THEN
            TPClass( LS^.OfSymbol )^.AddNestedFriend( Symbol, TPProcedure( P ));
          END;
          LOOP
            IF P^.OD = OD THEN
              EXIT;
            ELSE
              P^.AddNestedSymbol( LS, LS^.OfSymbol );
            END;
            P := P^.NI;
          END; // LOOP
          b := TPProcedureType( Symbol )^.OI^.NF^.GetNext( LS );
        END; // WHILE
      END;
      //...
      RETURN TRUE;
    END;
  END HandleNestedSymbol;

  PROCEDURE HandleCOMPropertyOrFunction( AssignmentFlag : BOOLEAN; REF D : TPDesignator );
  VAR
    LD : TPDesignator;
    Member : TPProcedureType;
  BEGIN
    IF AssignmentFlag THEN
      RETURN;
    END;

    IF D^.r.DK <> dkType THEN
      LD := D;
    ELSIF D^.r.TC^.GetDesignator( OUT LD ) THEN // if D is dkType, then the designator
      // must be changed inside TCs -- simply replaced. So there it is Get, and at the bottom is Set.
    ELSE
      RETURN;
    END;
    
    CASE LD^.r.DK OF
    | dkId :
      Member := TPProcedure( LD^.r.Id );
    | dkOperator :
      CASE LD^.r.O OF
      | doSelecting, doSelectingOfSuperClass :
        Member := TPProcedure( LD^.r.F );
      | doIndexingOfClass, doIndexingOfSuperClass :
        Member := LD^.r.DfI;
      | doCall :
        Member := TPProcedure( LD^.L^.r.Id );
      END;
    ELSE
      RETURN; // ?? strange, nothing to do
    END;

    NEW( LD^.r.CD );
    WITH LD^.r.CD^ DO
      r.DK := dkId; // opreated as being dkCOMAuxId
      r.OD := LD;
      r.CD := LD^.r.CD; // strange cross reference, but it is used in ntAssignment later
      T := D^.T;
      HandleAuxVariableRequest( Member^.T, TPVariable( r.Id ));
      IF NOT D^.T^.IsFormal() OR ( DOM.TPFormalType( D^.T )^.TypeModifier <> DOM.tmOUT ) THEN
         // preceding property-get call
         NEW( r.PA );
         IF imCOM IN Member^.IM THEN
           r.PA^.UnitKind := ukSAssignmentByCOMCall;
           r.PA^.D := LD;
         ELSE
           r.PA^.UnitKind := ukSAssignment;
           r.PA^.D := LD^.r.CD;
           CreateExpressionWithDesignator( LD, FALSE, OUT r.PA^.E );
         END;
         AddPrecedingStatement( r.PA );
      END;
      // add code releasing implicitly get interface
      IF ( Member^.T^.UnwrapToBaseType()^.TypeKind = tkClass ) AND ( DOM.imCOM IN Member^.IM ) THEN
        NEW( r.FA );
        r.FA^.UnitKind := ukSCall;
        NEW( r.FA^.D );
        r.FA^.D^.r.DK := dkOperator;
        r.FA^.D^.r.O := doCallRelease;
        r.FA^.D^.L := LD^.r.CD;
        AddFollowingStatement( r.FA );
      END;
    END; // WITH

    // replace current designator with modified
    IF D^.r.DK <> dkType THEN
      D := LD^.r.CD;
    ELSE
      D^.r.TC^.SetDesignator( LD^.r.CD );
    END;
  END HandleCOMPropertyOrFunction;

  PROCEDURE IdToType( Id : TPSymbol ) : TPType;
  VAR
    LId : TPSymbol;
  BEGIN
    IF Id = NIL THEN
      SemErr( err._ExpectedTypeOrClassName );
      RETURN Types.TUnknown;
    END;
    CASE Id^.UnitKind OF
    | ukCmdLineConstDecl,
      ukSimpleConstDecl,
      ukClassConstDecl :
      LId := TPConstant( Id )^.Unwrap();
      IF LId = Id THEN
        SemErr( err._ExpectedTypeOrClassName );
        RETURN Types.TUnknown;
      ELSE
        RETURN IdToType( LId );
      END;
    | ukSimpleTypeDef,
      ukClassTypeDef,
      ukSimpleClassDef,
      ukClassClassDef :
      RETURN TPType( Id );
    ELSE
      SemErr( err._ExpectedTypeOrClassName );
      RETURN Types.TUnknown;
    END;
  END IdToType;

  PROCEDURE IdToClass( Id : TPSymbol ) : TPClass;
  VAR
    LId : TPSymbol;
  BEGIN
    IF Id = NIL THEN
      SemErr( err._ExpectedClassName );
      RETURN NIL;
    END;
    CASE Id^.UnitKind OF
    | ukCmdLineConstDecl,
      ukSimpleConstDecl,
      ukClassConstDecl :
      LId := TPConstant( Id )^.Unwrap();
      IF LId = Id THEN
        SemErr( err._ExpectedClassName );
        RETURN NIL;
      ELSE
        RETURN IdToClass( LId );
      END;
    | ukSimpleClassDef,
      ukClassClassDef :
      RETURN TPClass( Id );
    ELSE
      SemErr( err._ExpectedClassName );
      RETURN NIL;
    END;
  END IdToClass;

  PROCEDURE RevertOpaqueClassType( OpaqueType, RealType : TPType );
  VAR
    PS : TPSymbols := NIL;
  BEGIN
    CASE OpaqueType^.OfSymbol^.SymbolKind OF
    | skModule :
      PS := ADR( TPModule( OpaqueType^.OfSymbol )^.SelfS );
      IF NOT PS^.Forget( OpaqueType ) THEN
        PS := NIL;
      END;
    | skClass :
      PS := ADR( TPClass( OpaqueType^.OfSymbol )^.S );
      IF NOT PS^.Forget( OpaqueType ) THEN
        PS := NIL;
      END;
    END;
    IF PS <> NIL THEN
      OpaqueType^.N.Assign( RealType^.N );
      OpaqueType^.N.AppendOA( L':q' );
      PS^.Add( OpaqueType );
      OpaqueType^.UnitKind := ukOpaqueClassType;
      OpaqueType^.TypeKind := tkOpaqueBaseLink;
      OpaqueType^.UW := NIL; // reset UW
      OpaqueType^.T := RealType;
      OpaqueType^.GenTo[Generator.genCPP] := FALSE;
    END;
  END RevertOpaqueClassType;

  PROCEDURE IsLabel( CONST Name : StringsO.CString; VAR Label : TPSymbol ) : BOOLEAN;
  VAR
    FI : TPSymbol;
  BEGIN
    RETURN GetSymbol( Name, skLabel, FALSE, TRUE, TRUE, Label, FI );
  END IsLabel;

  PROCEDURE GetConstantBooleanValue( Name : ARRAY OF WCHAR; VAR Value : BOOLEAN ) : BOOLEAN;
  VAR
    FI : TPSymbol;
    Id : TPSymbol;
    N : StringsO.CString;
    V : CEValue;
  BEGIN
    Value := FALSE;
    N.FromOA( Name );
    IF NOT GetSymbol( N, skUnknown, TRUE, FALSE, TRUE, Id, FI ) THEN
      N.Dispose();
      RETURN FALSE;
    ELSIF Types.TBOOLEAN^.Compatible( cmOperation, Id^.T ) THEN
      TPConstant( Id )^.Expression()^.Evaluate( V, 0 );
      Value := V.B;
      N.Dispose();
      RETURN TRUE;
    ELSE
      N.Dispose();
      RETURN FALSE;
    END;
  END GetConstantBooleanValue;

  PROCEDURE GetOpenArrayFormalType( ComponentType : TPType ) : TPFormalType;
  VAR
    OAN : StringsO.CString;
    OpenArray : TPFormalType;
  BEGIN
    OAN.Assign( ComponentType^.Unwrap()^.N );
    OAN.PrependOA( L'ARRAY OF ' );
    IF SelfS.Get( OAN, OpenArray ) THEN
      OAN.Dispose();
      RETURN OpenArray;
    END;
    NEW( OpenArray );
    OpenArray^.N := OAN;
    OpenArray^.TypeKind := tkOpenArray;
    OpenArray^.T := ComponentType;
    SelfS.Add( OpenArray );
    RETURN OpenArray;
  END GetOpenArrayFormalType;

  PROCEDURE GetSetFormalType( ComponentType : TPType ) : TPType;
  LABEL
    CreateInSelf;
  VAR
    LT : TPType;
    OfModule : TPSymbol;
    R : INT64;
    SN : StringsO.CString;
    Set : TPSet;
  BEGIN
    LT := ComponentType^.Unwrap();
    SN.Assign( LT^.N );
    SN.PrependOA( L'Ts_' );

    // first try search type in owning module (only if LT is not intrinsic)
    OfModule := LT^.OfSymbol;
    IF OfModule = NIL THEN
      GOTO CreateInSelf;
    END;
    WHILE OfModule^.OfSymbol <> NIL DO
      OfModule := OfModule^.OfSymbol;
    END; // WHILE
    IF TPModule( OfModule )^.SelfS.Get( SN, Set ) THEN
      RETURN Set; // found in owning module
    ELSIF ( OfModule <> ADR( SELF )) AND ( OfModule <> OD ) THEN // set component type is foreign,
      // I must create name dependent on this foreign module
      LT^.GetSourceQN( OUT SN );
      SN.ReplaceOA( L'.', L'_' );
      SN.PrependOA( L'Ts_' );
    END;
    
  CreateInSelf:
    IF SelfS.Get( SN, Set ) OR ( ADR( SELF ) <> OD ) AND OD^.SelfS.Get( SN, Set ) THEN
      RETURN Set; // found in current module
    END;

    NEW( Set );
    Set^.N := SN;
    Set^.T := ComponentType;
    INCL( Set^.Options, eoDLLInterface );
    R := ComponentType^.OrdinalRange();
    IF R <= 32 THEN
      Set^._Count := 4;
    ELSIF R <= 64 THEN
      Set^._Count := 8;
    ELSIF R < MAX( CARDINAL ) - 7 THEN
      Set^.PrimitiveType := ptStructure;
      Set^._Count := ( R + 7 ) DIV 8;
    ELSE
      Set^.PrimitiveType := ptStructure;
      Set^._Count := R DIV 8;
    END;

    SelfS.Add( Set );
    TypeC.Add( Set );
    
    RETURN Set;
  END GetSetFormalType;

  PROCEDURE ExpectType( LT, RT : TPType; n : CARDINAL ) : BOOLEAN;
  VAR
    LMessage : ARRAY [0..511] OF WCHAR;
    LQName : StringsO.CString;
    RMessage : ARRAY [0..511] OF WCHAR;
    Check : BOOLEAN := TRUE;
  BEGIN
    IF ( LT = Types.TUnknown ) OR ( RT = Types.TUnknown ) THEN
      Check := FALSE; // fall down
    ELSIF LT^.Compatible( cmAssign, RT ) THEN
      RETURN TRUE;
    ELSIF Types.TStorage^.Compatible( cmAssign, LT ) AND ( RT^.Unwrap() = Types.TOrdinalNumber ) THEN
      // system storage types are compatible with number literal
      RETURN TRUE;
    ELSIF Types.TStorage^.Compatible( cmOperation, RT ) AND RT^.Compatible( cmAssign, LT ) THEN
      // system storage types cn be assingned into any corresponding type
      RETURN TRUE;
    END;

    IF NOT Check THEN
      SemErrForced( err._TypeMismatch );
    ELSIF n <> -1 THEN
      SemErrForcedN( err._TypeMismatchComma, n );
    ELSE
      // left
      IF LT^.IsFormal() OR ( LT^.TypeKind = tkOpaqueBaseLink ) AND ( LT^.T^.TypeKind = tkClass ) THEN
        LT^.Unwrap()^.GetSourceQN( OUT LQName ); LQName.ToOA( OUT LMessage );
      ELSIF ( eoUnnamed IN LT^.Options ) AND ( LT^.TypeKind = tkReference ) THEN
        WHILE eoUnnamed IN LT^.Options DO
          LT := LT^.T;
        END; // WHILE
        IF LT = Types.TUnknown THEN
          ASSIGN( LMessage, L"POINTER TO (unnamed)" );
        ELSE
          LT^.GetSourceQN( OUT LQName ); LQName.ToOA( OUT LMessage );
          Strings.PrependW( REF LMessage, L"POINTER TO " );
        END;
      ELSE
        WHILE eoUnnamed IN LT^.Options DO
          LT := LT^.T;
        END; // WHILE
        IF LT = Types.TUnknown THEN
          ASSIGN( LMessage, L"(unnamed)" );
        ELSE
          LT^.GetSourceQN( OUT LQName ); LQName.ToOA( OUT LMessage );
        END;
      END;
      // right
      IF RT^.IsFormal() OR ( RT^.TypeKind = tkOpaqueBaseLink ) AND ( RT^.T^.TypeKind = tkClass ) THEN
        RT^.Unwrap()^.GetSourceQN( OUT LQName ); LQName.ToOA( OUT RMessage );
      ELSIF ( eoUnnamed IN RT^.Options ) AND ( RT^.TypeKind = tkReference ) THEN
        WHILE eoUnnamed IN RT^.Options DO
          RT := RT^.T;
        END; // WHILE
        IF RT = Types.TUnknown THEN
          Strings.PrependW( REF RMessage, L"POINTER TO (unnamed)" );
        ELSE
          RT^.GetSourceQN( OUT LQName ); LQName.ToOA( OUT RMessage );
          Strings.PrependW( REF RMessage, L"POINTER TO " );
        END;
      ELSE
        WHILE eoUnnamed IN RT^.Options DO
          RT := RT^.T;
        END; // WHILE
        IF RT = Types.TUnknown THEN
          ASSIGN( RMessage, L"(unnamed)" );
        ELSE
          RT^.GetSourceQN( OUT LQName ); LQName.ToOA( OUT RMessage );
        END;
      END;
      SemErrForcedSNS( err._TypeMismatchExpected, LMessage, err._TypeMismatchCommaFound, RMessage );
    END;

    RETURN FALSE;
  END ExpectType;

  PROCEDURE CheckTypeMismatch( LT, RT : TPType; ClassOperatorFlag : BOOLEAN; n : CARDINAL ) : BOOLEAN;
  VAR
    CM : TCompatibilityMode := cmOperation;
    LMessage : ARRAY [0..511] OF WCHAR;
    LQName : StringsO.CString;
    RMessage : ARRAY [0..511] OF WCHAR;
  BEGIN
    IF ClassOperatorFlag THEN
      CM := cmOperatorParameter;
    END;
    IF ( LT = Types.TUnknown ) OR ( RT = Types.TUnknown ) THEN
      SemErrForced( err._TypeMismatch );
    ELSIF LT^.Compatible( CM, RT ) THEN
      RETURN TRUE;
    ELSIF n <> -1 THEN
      SemErrForcedN( err._TypeMismatchComma, n );
    ELSE
      IF ( eoUnnamed IN LT^.Options ) AND ( LT^.TypeKind = tkReference ) THEN
        WHILE eoUnnamed IN LT^.Options DO
          LT := LT^.T;
        END; // WHILE
        IF LT = Types.TUnknown THEN
          ASSIGN( LMessage, L"POINTER TO (unnamed)" );
        ELSE
          LT^.GetSourceQN( OUT LQName ); LQName.ToOA( OUT LMessage );
          Strings.PrependW( REF LMessage, L"POINTER TO " );
        END;
      ELSE
        WHILE eoUnnamed IN LT^.Options DO
          LT := LT^.T;
        END; // WHILE
        IF LT = Types.TUnknown THEN
          ASSIGN( LMessage, L"(unnamed)" );
        ELSE
          LT^.GetSourceQN( OUT LQName ); LQName.ToOA( OUT LMessage );
        END;
      END;
      IF ( eoUnnamed IN RT^.Options ) AND ( RT^.TypeKind = tkReference ) THEN
        WHILE eoUnnamed IN RT^.Options DO
          RT := RT^.T;
        END; // WHILE
        IF RT = Types.TUnknown THEN
          ASSIGN( RMessage, L"POINTER TO (unnamed)" );
        ELSE
          RT^.GetSourceQN( OUT LQName ); LQName.ToOA( OUT RMessage );
          Strings.PrependW( REF RMessage, L"POINTER TO " );
        END;
      ELSE
        WHILE eoUnnamed IN RT^.Options DO
          RT := RT^.T;
        END; // WHILE
        IF RT = Types.TUnknown THEN
          ASSIGN( RMessage, L"(unnamed)" );
        ELSE
          RT^.GetSourceQN( OUT LQName ); LQName.ToOA( OUT RMessage );
        END;
      END;
      SemErrForcedSNS( err._TypeMismatchRight, LMessage, err._TypeMismatchIncompatible, RMessage );
    END;
    RETURN FALSE;
  END CheckTypeMismatch;

  PROCEDURE AdaptMorphableTypes( VAR ParentT, LT, RT : TPType );
  BEGIN
    IF LT^.TypeKind <> tkMorphable THEN
      RETURN;
    END;
    IF Types.TTCHAR^.Compatible( cmOperation, LT ) THEN
      IF eoWCHAR IN CurE^.Options THEN
        ParentT := Types.TTCHARW;
      ELSE
        ParentT := Types.TTCHARB;
      END;
      LT := ParentT;
      IF RT^.TypeKind = tkMorphable THEN
        RT := LT;
      END;
    ELSIF Types.TString^.Compatible( cmOperation, LT ) THEN
      IF eoWCHAR IN CurE^.Options THEN
        ParentT := Types.TTStringW;
      ELSE
        ParentT := Types.TTStringB;
      END;
      LT := ParentT;
      IF RT^.TypeKind = tkMorphable THEN
        RT := LT;
      END;
    END;
  END AdaptMorphableTypes;

  PROCEDURE CheckCONSTAssignment( LVI, RVI : TValueInfo; LT, RT : DOM.TPType ) : BOOLEAN;
  VAR
    b : BOOLEAN := TRUE;
  BEGIN
    IF viCONST IN LVI THEN // assignment to CONST
      SemErr( err._UnableToAssignToCONST );
      b := FALSE;
    ELSIF NOT LT^.IsOpenArray() THEN // ok, all next checks will handle open arrays only
      // pass down
    ELSIF TPFormalType( LT )^.TypeModifier = tmUnknown THEN // assignment to OA is allowed for VAR/REF/OUT parameters only
      SemErr( err._UnableToAssignToValueOA );
      b := FALSE;
    END;
    IF LT^.Unwrap()^.TypeKind <> DOM.tkReference THEN // OK, no POINTER TO CONST assignment check
    ELSIF LT^.Unwrap() = RT^.Unwrap() THEN // OK, types are identical
    ELSIF LT^.Unwrap() = Types.TADDRESS THEN // OK, ADDRESS can be assigned everywhere
    ELSIF RT^.Unwrap() = Types.TADDRESS THEN // OK, ADDRESS can be assigned everywhere
    ELSIF TValueInfo{viCONST} * RVI = TValueInfo{} THEN // OK, expression is not CONST
    ELSIF NOT LT^.Unwrap()^.T^.IsFormal() THEN
      // error, POINTER is not formal, so it cannot be POINTER TO CONST
      SemErr( err._UnableToPassCONSTintoREF );
      b := FALSE;
    ELSIF TPFormalType( LT^.Unwrap()^.T )^.TypeModifier <> tmCONST THEN
      // error, POINTER is formal but it is not POINTER TO CONST
      SemErr( err._UnableToPassCONSTintoREF );
      b := FALSE;
    END;
    RETURN b;
  END CheckCONSTAssignment;

  PROCEDURE CheckOverwrittenOperator( Class : TPClass; O : TEO; CheckAccessibility : BOOLEAN ) : BOOLEAN;
  VAR
    DfO : DOM.TPOperatorDef;
    LC : TPClass;
    N : StringsO.CString;
  BEGIN
    N.FromOA( L'operator ' );
    N.AppendOA( opString[O] );
    IF NOT GetClassSymbol( N, Class, DfO, LC ) THEN
      RETURN FALSE;
    ELSIF CheckAccessibility THEN
      CheckAccessToSymbol( DfO );
    END;
    RETURN TRUE;
  END CheckOverwrittenOperator;

  PROCEDURE CheckIndexerUsage( Class : TPClass; OUT DfI : TPIndexerDef; OUT IndexType : TPFormalType; OUT ResultType : TPType ) : BOOLEAN;
  VAR
    LC : TPClass;
    N : StringsO.CString;
  BEGIN
    N.FromOA( L'[]' );
    IF NOT GetClassSymbol( N, Class, DfI, LC ) THEN
      RETURN FALSE;
    END;
    CheckAccessToSymbol( DfI );
    IndexType := DfI^.IndexType;
    ResultType := DfI^.T;
    RETURN TRUE;
  END CheckIndexerUsage;

  PROCEDURE CheckOperatorUsage( N : TPENode; OUT OperandType, ResultType : TPType ) : BOOLEAN;
  VAR
    DfO : DOM.TPOperatorDef;
    LC : TPClass;
    Name : StringsO.CString;
    s : ARRAY [0..31] OF WCHAR;
  BEGIN
    IF N^.r.L^.T^.Unwrap()^.TypeKind <> tkClass THEN
      RETURN FALSE;
    END;
    Strings.ConcatW( OUT s, L'operator ', DOM.opString[N^.r.O] );
    Name.FromOA( s );
    IF NOT GetClassSymbol( Name, TPClass( N^.r.L^.T^.Unwrap()), DfO, LC ) THEN
      RETURN FALSE;
    END;
    CheckAccessToSymbol( DfO );
    OperandType := DfO^.OperandType;
    ResultType := DfO^.T;
    RETURN TRUE;
  END CheckOperatorUsage;

  PROCEDURE CheckAccessToSymbol( Id : TPSymbol );
  VAR
    LId : TPSymbol;
  BEGIN
    CASE Id^.AM OF
    | amPrivate :
      IF CurrentC() <> Id^.OfSymbol THEN
        SemErrCS( err._PrivateInaccessible, Id^.N );
      END;
    | amInternal, amLocal :
      IF CurrentC() = Id^.OfSymbol THEN
        RETURN;
      ELSIF ( CurrentC() <> NIL ) AND CurrentC()^.IsDescendantOf( TPClass( Id^.OfSymbol ), FALSE ) THEN
        RETURN;
      ELSIF Id^.AM = amInternal THEN
        SemErrCS( err._InternalInaccessible, Id^.N );
        RETURN;
      END;
      LId := Id;
      WHILE LId^.OfSymbol <> NIL DO
        LId := LId^.OfSymbol;
      END;
      ASSERT( LId^.SymbolKind = skModule );
      IF TPModule( LId )^.OD <> OD THEN
        SemErrCS( err._LocalInaccessible, Id^.N );
      END;
    END;
  END CheckAccessToSymbol;

  PROCEDURE CheckReadonly( Id : TPSymbol );
  BEGIN
    IF NOT( cmRO IN Id^.CM ) THEN
      RETURN;
    END;
    CASE Id^.OfSymbol^.SymbolKind OF
    | skModule :
      IF Id^.OfSymbol <> OD THEN
        SemErrCS( err._PublicReadonlyInaccessible, Id^.N );
      END;
    | skClass :
      IF CurrentC() = NIL THEN // usage outside of class
        SemErrCS( err._PublicClassReadonlyInaccessible, Id^.N );
      ELSIF CurrentC() = Id^.OfSymbol THEN
        // OK, self has full accessibility
      ELSIF CurrentC()^.IsDescendantOf( TPClass( Id^.OfSymbol ), FALSE ) THEN
        IF Id^.AM = amInternal THEN
          SemErrCS( err._InternalClassReadonlyInaccessible, Id^.N );
        END;
      ELSE // usage in different class
        SemErrCS( err._PublicClassReadonlyInaccessible, Id^.N );
      END;
    ELSE
      SemErr( err._UnableToAssignReadonlyVar );
    END;
  END CheckReadonly;

  PROCEDURE CheckWriteonly( Id : TPSymbol );
  BEGIN
    IF NOT( cmWO IN Id^.CM ) THEN
      RETURN;
    END;
    CASE Id^.OfSymbol^.SymbolKind OF
    | skModule :
      IF Id^.OfSymbol <> OD THEN
        SemErrCS( err._PublicWriteonlyInaccessible, Id^.N );
      END;
    | skClass :
      IF CurrentC() = NIL THEN // usage outside of class
        SemErrCS( err._PublicClassWriteonlyInaccessible, Id^.N );
      ELSIF CurrentC() = Id^.OfSymbol THEN
        // OK, self has full accessibility
      ELSIF CurrentC()^.IsDescendantOf( TPClass( Id^.OfSymbol ), FALSE ) THEN
        IF Id^.AM = amInternal THEN
          SemErrCS( err._InternalClassReadonlyInaccessible, Id^.N );
        END;
      ELSE // usage in different class
        SemErrCS( err._PublicClassWriteonlyInaccessible, Id^.N );
      END;
    ELSE
      SemErr( err._UnableToReadWriteonlyVar );
    END;
  END CheckWriteonly;

  PROCEDURE CheckClassSymbolSemantics( Symbol : TPSymbol; AgainstClass : TPClass );
  VAR
    Error : CARDINAL;
    Id : TPSymbol;
    InClass : TPClass;
    Name1, Name2 : ARRAY [0..127] OF WCHAR;
    Found : BOOLEAN := FALSE;
    ImplementationFlag : BOOLEAN;
  BEGIN
      IF AgainstClass = NIL THEN
         IF GetClassSymbol( Symbol^.N, CurrentC()^.I, Id, InClass ) THEN
            IF Id = InClass THEN // this occurs when defining constructor or destructor
               RETURN;
            END;
            // fall down
         ELSE
            CurrentC()^.Implements.Reset();
            WHILE CurrentC()^.Implements.MoveNext() DO
               IF GetClassSymbol( Symbol^.N, CurrentC()^.Implements.Current, Id, InClass ) THEN
                  Found := TRUE;
                  EXIT;
               END;
            END; // WHILE
            IF NOT Found THEN
               IF Symbol^.UnitKind NOT IN uksRoutineDef THEN
                  // do nothing
               ELSIF imAbstract IN TPProcedure( Symbol )^.IM THEN
                  CurrentC()^.ExposedAbstract.Add( Symbol, 0 );
               END;
               RETURN;
            END;
         END;
      ELSE
         IF NOT GetClassSymbol( Symbol^.N, AgainstClass, Id, InClass ) THEN
            IF Symbol^.UnitKind NOT IN uksRoutineDef THEN
               // do nothing
            ELSIF imAbstract IN TPProcedure( Symbol )^.IM THEN
               CurrentC()^.ExposedAbstract.Add( Symbol, 0 );
            END;
            RETURN;
         ELSIF Id = InClass THEN // this occurs when defining constructor or destructor
            RETURN;
         END;
      END;

    CASE Id^.UnitKind OF
    | ukPropertyDef, ukMethodDef, ukIndexerDef, ukOperatorDef :
      ImplementationFlag := Symbol^.UnitKind IN uksRoutineDecl;
      IF NOT ImplementationFlag THEN
        IF TPProcedureType( Id )^.IM = TInheritanceModifier{} THEN
          IF TPProcedureType( Symbol )^.IM = TInheritanceModifier{} THEN
            RETURN;
          END;
          SemErrCS( err._BadIMNotVirtual, InClass^.N );
        ELSIF imAbstract IN TPProcedureType( Id )^.IM THEN
          IF TPProcedureType( Symbol )^.IM * TInheritanceModifier{imAbstract, imVirtual, imFinal} = TInheritanceModifier{} THEN
            SemErrCS( err._BadIMNotAbstractVirtualFinal, InClass^.N );
          ELSIF imAbstract NOT IN TPProcedureType( Symbol )^.IM THEN
            CurrentC()^.ExposedAbstract.Remove( Id );
          END;
          IF Symbol^.AM <> Id^.AM THEN
            SemErr( err._BadAMVirtualNotSame );
          END;
        ELSIF imVirtual IN TPProcedureType( Id )^.IM THEN
          IF TPProcedureType( Symbol )^.IM * TInheritanceModifier{imVirtual, imFinal} <> TInheritanceModifier{} THEN
            // fall down
          ELSIF imAbstract IN TPProcedureType( Symbol )^.IM THEN
            IF TInheritanceModifier{imInterface} * InClass^.IM = TInheritanceModifier{} THEN // symbol inherited from interface can be abstract
              SemErrCS( err._BadIMMustBeVirtualOrFinal, InClass^.N );
            END;
          ELSE
            SemErrCS( err._BadIMMustBeVirtualOrFinal, InClass^.N );
          END;
          IF Symbol^.AM <> Id^.AM THEN
            SemErr( err._BadAMVirtualNotSame );
          END;
        ELSIF imFinal IN TPProcedureType( Id )^.IM THEN
          SemErrCS( err._UnableToRewriteFinal, InClass^.N );
          IF Symbol^.AM <> Id^.AM THEN
            SemErr( err._BadAMVirtualNotSame );
          END;
        END;
      ELSIF TPProcedureType( Id )^.IM <> TPProcedureType( Symbol )^.IM THEN
        SemErr( err._BadIMDefAndDeclMismatch );
      END;
      CASE Id^.UnitKind OF // parameters and return values
      | ukPropertyDef :
        IF NOT ImplementationFlag THEN
          IF Id^.CM <> Symbol^.CM THEN
            SemErrCS( err._HdrClassMismatchCM, InClass^.N );
          END;
          IF NOT Id^.T^.Compatible( cmOperation, Symbol^.T ) THEN
            SemErrCS( err._HdrClassMismatchReturn, InClass^.N );
          END;
        END;
      | ukIndexerDef :
        IF NOT ImplementationFlag THEN
          IF Id^.CM <> Symbol^.CM THEN
            SemErrCS( err._HdrClassMismatchCM, InClass^.N );
          END;
          IF ( TPIndexerDef( Id )^.IndexType^.T <> TPIndexerDef( Symbol )^.IndexType^.T ) OR
             ( TPFormalType( TPIndexerDef( Id )^.IndexType )^.TypeModifier <> TPFormalType( TPIndexerDef( Symbol )^.IndexType )^.TypeModifier ) THEN
            SemErrCS( err._HdrClassMismatchIndexType, InClass^.N );
          END;
          IF TPIndexerDef( Id )^.T <> TPIndexerDef( Symbol )^.T THEN
            SemErrCS( err._HdrClassMismatchReturn, InClass^.N );
  // GP (*?*)        END;
          END;
        END;
      | ukOperatorDef :
        IF NOT ImplementationFlag THEN
          IF Id^.CM <> Symbol^.CM THEN
            SemErrCS( err._HdrClassMismatchCM, InClass^.N );
          END;
          IF ( TPOperatorDef( Id )^.OperandType^.T <> TPOperatorDef( Symbol )^.OperandType^.T ) OR 
             ( TPFormalType( TPOperatorDef( Id )^.OperandType )^.TypeModifier <> TPFormalType( TPOperatorDef( Symbol )^.OperandType )^.TypeModifier ) THEN
            SemErrCS( err._HdrClassMismatchOperandType, InClass^.N );
          END;
          IF TPOperatorDef( Id )^.T <> TPOperatorDef( Symbol )^.T THEN
            SemErrCS( err._HdrClassMismatchReturn, InClass^.N );
          END;
        END;
      | ukMethodDef : // compare headers using normal way
        IF NOT TPProcedure( Id )^.CompareHeader( TPProcedure( Symbol ), OUT Error ) THEN
          InClass^.N.ToOA( OUT Name1 );
          M2^.SemErrNNS( err._HdrMismatch, Error, err._HdrSee, Name1 );
        END;
      END; // CASE Id^.UnitKind
    ELSE
      Symbol^.N.ToOA( OUT Name1 );
      InClass^.N.ToOA( OUT Name2 );
      M2^.SemErrForcedSNS( err._IdentifierRedefined, Name1, err._IdentifierRedefinedIsMemberOf, Name2 );
    END;
  END CheckClassSymbolSemantics;

  PROCEDURE CreateProcedureImplementation( DP : TPProcedureType; ImS : TImplementationState; AM : TAccessModifier; IM : TInheritanceModifier; CM : TCodeModifier; VAR IP : TPProcedure ); // Definition, Implementation
  VAR
    NI : TPProcedure; // NestedIn
    U : TPUnit;
  BEGIN
    IF DP = NIL THEN
      IP := NIL;
      RETURN;
    END;

    // prepare nesting, copy environment, enter symbols
    NI := TPProcedure( SStack.CurP );
    PushOptions( DP^.Options - TEnvironmentOptions{eoDLLInterface} );
    IF DP^.ImplementationState = DOM.isUnknown THEN
      EnterSymbols( DP^.S, TRUE, TRUE, NIL );
    END;

    // create implementation
    CASE DP^.UnitKind OF
    | ukPropertyDef :
      NEW( TPPropertyDecl( IP ));
    | ukMethodDef :
      NEW( TPMethodDecl( IP ));
    | ukIndexerDef :
      NEW( TPIndexerDecl( IP ));
    | ukOperatorDef :
      NEW( TPOperatorDecl( IP ));
    ELSE
      NEW( IP ); IP^.UnitKind := DOM.ukProcedureDecl;
    END;
    IP^.OfSymbol := DP^.OfSymbol;
    IP^.AM := AM;
    IP^.IM := IM;
    IP^.CM := CM;
    //----- create frame for local data
    NEW( IP^.NFT );
    IP^.NFT^.UnitKind := ukNestedForwardedFrame;
    SetNumId( IP^.NFT, TRUE, L'TFrame_' );
    IP^.N.Assign( DP^.N );
    IP^.NFT^.Packing := CurE^.Packing;
    //-----
    IP^.Options := DP^.Options;
    IF NI <> NIL THEN
      IP^.UnitKind := DOM.ukNestedProcedureDecl;
      IP^.NI := NI;
    END;
    // self pointers
    IP^.OI := IP;
    // cross pointers
    IP^.OD := DP;
    DP^.OI := IP;

    IF imAbstract IN DP^.IM THEN
      SemErrCS( err._AbstractMemberCannotBeDeclared, DP^.N );
    END;
    // all procedures must be checked for duplicite declaration
    CASE DP^.ImplementationState OF
    | DOM.isUnknown : // OK
    | DOM.isForwarded, DOM.isDefined : // check formal types, read into dummy
      EnterSymbols( IP^.S, TRUE, TRUE, NIL );
    | DOM.isImplementedA :
      SemErrCS( err._ProcedureAlreadyImplemented, DP^.N );
      EnterSymbols( IP^.S, TRUE, TRUE, NIL );
    | DOM.isImplementedR :
      IF ImS = DOM.isImplementedR THEN
        SemErrCS( err._MemberGETAlreadyImplemented, DP^.N );
      END;
      EnterSymbols( IP^.S, TRUE, TRUE, NIL );
    | DOM.isImplementedW :
      IF ImS = DOM.isImplementedW THEN
        SemErrCS( err._MemberSETAlreadyImplemented, DP^.N );
      END;
      EnterSymbols( IP^.S, TRUE, TRUE, NIL );
    END;

    // prepare read parameters
    U := EnterNewUnit( DOM.ukParameterList );
    IF DP^.ImplementationState = DOM.isUnknown THEN
      DP^.Parameters := U;
      IP^.Parameters := U;
    ELSE
      IP^.Parameters := U;
    END;
  END CreateProcedureImplementation;

  PROCEDURE EnterProcedureImplementation( DP : TPProcedureType );
  VAR
    E : CARDINAL;
    IP : TPProcedure;
  BEGIN
    IF DP = NIL THEN
      RETURN;
    END;
    IP := DP^.OI;
    IF IP = NIL THEN
      RETURN;
    END;

    // finish read parameteres, create units for include of nested parameters/frames
    IF DP^.ImplementationState = DOM.isUnknown THEN
      DP^.T := IP^.T; // newly read, DP is decl without def
    END;
    NEW( IP^.NP ); IP^.NP^.P := IP;
    IF DOM.coParamsInFrame IN CurE^.Options THEN
      NEW( IP^.NF ); IP^.NF^.P := IP;
      AddUnit( IP^.NF );
    ELSE
      AddUnit( IP^.NP );
    END;
    LeaveUnit();
    PopOptions(); // definition options are valid for procedure header only...

    // ...but implementation options takes sense commonly
    PushOptions( DP^.Options - TEnvironmentOptions{eoDLLInterface, eoExport} );

    // class members must be checked for inheritance semantics
    IF SStack.CurC <> NIL THEN
      CheckClassSymbolSemantics( IP, SStack.CurC );
    END;

    // enter implementation symbols
    EnterSymbols( IP^.S, TRUE, TRUE, NIL );
    // check def/impl
    IF DP^.ImplementationState = DOM.isUnknown THEN
      // ok, procedure has no prototype
    ELSIF DP^.UnitKind = ukPropertyDef THEN
      IF ( IP^.UnitKind = ukPropertyDeclR ) AND ( DP^.T^.UnwrapToBaseType() <> IP^.T^.UnwrapToBaseType()) THEN
        SemErrN( err._HdrMismatch, err._HdrMismatchReturn );
      END;
    ELSIF DP^.UnitKind = ukIndexerDef THEN
      IF ( IP^.UnitKind = ukIndexerDeclR ) AND ( DP^.T^.UnwrapToBaseType() <> IP^.T^.UnwrapToBaseType()) THEN
        SemErrN( err._HdrMismatch, err._HdrMismatchReturn );
      END;
    ELSIF DP^.UnitKind = ukOperatorDef THEN
      IF DP^.T^.UnwrapToBaseType() <> IP^.T^.UnwrapToBaseType() THEN
        SemErrN( err._HdrMismatch, err._HdrMismatchReturn );
      END;
    ELSIF NOT DP^.CompareHeader( IP, OUT E ) THEN
      SemErrN( err._HdrMismatch, E );
    END;

    // enter implementation itself
    EnterNewUnit( DOM.ukProcedureBlock );
  END EnterProcedureImplementation;
  
  PROCEDURE CheckProcedureSemantics( DP : TPProcedureType );
  VAR
    IP : TPProcedure;
  BEGIN
    IF DP = NIL THEN
      RETURN;
    END;
    IP := DP^.OI;
    IF IP = NIL THEN
      RETURN;
    END;
    // check procedure symbol semantics
    IP^.S.Reset();
    WHILE IP^.S.MoveNext() DO
      IF NOT( eoReferenced IN IP^.S.Current^.Options ) AND NOT IP^.S.Current^.T^.IsFormal() THEN
        CASE IP^.S.Current^.SymbolKind OF
        | skConstant, skVariable :
          WarningCS( wrn._LocalSymbolIsNotUsed, IP^.S.Current^.N );
        | skProcedure :
          WarningCS( wrn._ProcedureIsNotCalled, IP^.S.Current^.N );
        END;
      ELSIF ( IP^.S.Current^.SymbolKind = skLabel ) AND
            ( TEnvironmentOptions{eoReferenced, eoInitialized} * IP^.S.Current^.Options = TEnvironmentOptions{eoReferenced} ) THEN
        SemErrCS( err._LabelDestinationNotKnown, IP^.S.Current^.N );
      END;
    END; // WHILE
  END CheckProcedureSemantics;

  PROCEDURE LeaveProcedureImplementation( DP : TPProcedureType; ImS : TImplementationState; OmitAddingUnit : BOOLEAN );
  VAR
    IP : TPProcedure;
    U : TPUnit;
  BEGIN
    IF DP = NIL THEN
      RETURN;
    END;
    IP := DP^.OI;
    IF IP = NIL THEN
      RETURN;
    END;

    // leave implementation itself
    LeaveUnit();
    CASE ImS OF
    | isForwarded :
      INCL( IP^.Options, eoForward );
    | isImplementedA :
      DP^.ImplementationState := isImplementedA;
    | isImplementedR :
      CASE DP^.ImplementationState OF
      | isDefined :
        DP^.ImplementationState := isImplementedR;
      | isImplementedW :
        DP^.ImplementationState := isImplementedA;
      END;
    | isImplementedW :
      CASE DP^.ImplementationState OF
      | isDefined :
        DP^.ImplementationState := isImplementedW;
      | isImplementedR :
        DP^.ImplementationState := isImplementedA;
      END;
    END; // CASE
    // leave def/impl symbols
    IF CurS = ADR( IP^.S ) THEN // protection to complie errors, when IP^.S need not be pushed
      LeaveSymbols( TRUE );
    END;
    LeaveSymbols( TRUE );

    // pop implementation options
    PopOptions();

    // add procedure to proper context
    IF OmitAddingUnit THEN
    ELSIF IP^.UnitKind = DOM.ukNestedProcedureDecl THEN // otherwise the kind was changed to ukNestedProcedureDecl
      IP^.NI^.NSP.Add( IP );
    ELSE
      AddUnit( IP );
    END;
    // handle nested symbols
    IF NOT IP^.NFT^.Empty THEN
      // 1. type to global data
      IP^.NSD.Add( IP^.NFT );
      // 2. variable of procedure encapsulated in frame
      NEW( DOM.TPVariable( U ));
      WITH DOM.TPVariable( U )^ DO
        N.FromOA( L'f_' );
        N.Append( IP^.N );
        T := IP^.NFT;
      END; // WITH
      IF IP^.CTDU <> NIL THEN
        IP^.CTDU^.Add( U );
      END;
    END;
  END LeaveProcedureImplementation;

	PROCEDURE CheckTypeIsException( T : TPType );
	BEGIN
		T := T^.Unwrap();
		IF ( T^.SymbolKind <> skClass ) OR NOT TPClass( T )^.IsDescendantOfException() THEN
			SemErr( err._ExpectedException );
		END;
	END CheckTypeIsException;

	PROCEDURE AddThrownType( P : TPProcedureType; T : TPType );
	BEGIN
		P^.Throws.Add( T^.Unwrap(), 0 );
	END AddThrownType;

	PROCEDURE CheckIfThrowingProcedureIsPossible( P : TPSymbol );
	BEGIN
		IF P^.SymbolKind = skVariable THEN
			P := P^.T^.Unwrap();
		END;
		IF TPProcedureType( P )^.Throws.Empty THEN // procedure does not throw
			RETURN;
		ELSIF NOT TStack.Empty THEN // procedure throws, but we are inside TRY
			AddTryProcedure( TPProcedureType( P ));
			RETURN;
		END;
		IF P^.SymbolKind = skProperty THEN
			SemErrCS( err._PropertyWithThrowMustBeUsedInTryBlockOnly, P^.N );
		ELSE
			SemErrCS( err._ProcedureWithThrowMustBeUsedInTryBlockOnly, P^.N );
		END;
	END CheckIfThrowingProcedureIsPossible;

	PROCEDURE CheckIfThrowIsPossible( T : TPType );
	VAR
		PT : lists.TPPtrList := ADR( TPProcedure( CurrentP())^.OD^.Throws );
	BEGIN
		T := T^.Unwrap();
		PT^.Reset();
		WHILE PT^.MoveNext() DO
			IF T = TPType( PT^.Current ) THEN
				RETURN;
			END;
		END; // WHILE
		IF TStack.Empty THEN // we are not inside TRY
   		SemErr( err._ThrowIsNotPossible );
		ELSE // we are inside TRY, catched type can be local
			AddTryThrow( T );
      END;
	END CheckIfThrowIsPossible;

	PROCEDURE AddTryHandleAll();
	BEGIN
		TPSTRY( TStack.Peek())^.Handles.Dispose();
		TPSTRY( TStack.Peek())^.Handles.Add( Types.TUnknown, 0 );
	END AddTryHandleAll;
	
	PROCEDURE AddTryHandle( T : TPType );
	BEGIN
		TPSTRY( TStack.Peek())^.Handles.Add( T, 0 );
	END AddTryHandle;

	PROCEDURE AddTryProcedure( P : TPProcedureType );
	BEGIN
		TPSTRY( TStack.Peek())^.Procedures.Add( P, 0 );
	END AddTryProcedure;

	PROCEDURE AddTryThrow( T : TPType );
	BEGIN
		TPSTRY( TStack.Peek())^.InnerThrows.Add( T, 0 );
	END AddTryThrow;

	PROCEDURE TryCheckParity();
	LABEL
		NextInnerThrow, NextProcedureThrow;
	VAR
		PT : TPSTRY := TPSTRY( TStack.Peek());
		PP : TPProcedureType;
		IT : TPType; // inner throw
		s1 : ARRAY [0..511] OF WCHAR;
		s2 : ARRAY [0..255] OF WCHAR;
	BEGIN
		IF ( PT^.Handles.Count = 1 ) AND ( TPType( PT^.Handles[0] ) = Types.TUnknown ) THEN // TRY has UNHANDLED clause
			RETURN;
		END;

		// procedures
		PT^.Procedures.Reset();
		WHILE PT^.Procedures.MoveNext() DO
			PP := TPProcedureType( PT^.Procedures.Current );
			PP^.Throws.Reset();
			WHILE PP^.Throws.MoveNext() DO

				PT^.Handles.Reset();
				WHILE PT^.Handles.MoveNext() DO
					IF TPClass( PP^.Throws.Current )^.IsDescendantOf( TPClass( PT^.Handles.Current ), TRUE ) THEN // OK
						GOTO NextProcedureThrow;
					END;
				END; // catches while

				PP^.N.ToOA( OUT s1 ); TPType( PP^.Throws.Current )^.N.ToOA( OUT s2 );
				Strings.AppendW( REF s1, L'.' ); Strings.AppendW( REF s1, s2 );
				SemErrS( err._ProcedureNotCatched, s1 );

	   NextProcedureThrow:
			END; // throws while
		END; // procedures while

		// inner throws
		PT^.InnerThrows.Reset();
		WHILE PT^.InnerThrows.MoveNext() DO
			IT := TPType( PT^.InnerThrows.Current );

			PT^.Handles.Reset();
			WHILE PT^.Handles.MoveNext() DO
				IF TPClass( IT )^.IsDescendantOf( TPClass( PT^.Handles.Current ), TRUE ) THEN // OK
					GOTO NextInnerThrow;
				END;
			END; // catches while

			SemErrCS( err._ThrowNotCatched, IT^.N );

   NextInnerThrow:
		END; // inner throws while
	END TryCheckParity;

  PROCEDURE SemErr( n : CARDINAL );
  BEGIN
    M2^.SemErr( n );
  END SemErr;

  PROCEDURE SemErrN( n, inner : CARDINAL );
  BEGIN
    M2^.SemErrN( n, inner );
  END SemErrN;

  PROCEDURE SemErrForced( n : CARDINAL);
  BEGIN
    M2^.SemErrForcedSNS( n, L'', -1, L'' );
  END SemErrForced;

  PROCEDURE SemErrForcedN( n1, n2 : CARDINAL );
  BEGIN
    M2^.SemErrForcedSNS( n1, L'', n2, L'' );
  END SemErrForcedN;
  
  PROCEDURE SemErrForcedSNS( n1 : CARDINAL; s1 : ARRAY OF WCHAR; n2 : CARDINAL; s2 : ARRAY OF WCHAR );
  BEGIN
    M2^.SemErrForcedSNS( n1, s1, n2, s2 );
  END SemErrForcedSNS;

  PROCEDURE SemErrCS( n : CARDINAL; CONST S : StringsO.CString );
  BEGIN
    M2^.SemErrCS( n, S );
  END SemErrCS;

  PROCEDURE SemErrS( n : CARDINAL; String : ARRAY OF WCHAR );
  BEGIN
    M2^.SemErrS( n, String );
  END SemErrS;

  PROCEDURE SemErrUnknownId( LookForKind, FoundKind : TSymbolKind; CONST HintModuleName : StringsO.TPString; Name : StringsO.CString ); // CONST
  VAR
    E : CARDINAL;
    n1, n2 : ARRAY [0..255] OF WCHAR;
  BEGIN
    IF HintModuleName = NIL THEN
      Name.ToOA( OUT n1 );
    ELSE
      HintModuleName^.ToOA( OUT n1 );
      Name.ToOA( OUT n2 );
      Strings.AppendW( REF n1, L'.' );
      Strings.AppendW( REF n1, n2 );
    END;
    CASE LookForKind OF
    | skModule: E := err._ExpectedModule;
    | skClass: E := err._ExpectedClass;
    | skType: E := err._ExpectedType;
    | skVariable: E := err._ExpectedVariable;
    ELSE
      E := -1;
    END; // CASE
    IF FoundKind = skUnknown THEN
      SemErrForcedSNS( err._UnknownIdentifier, n1, E, L'' );
    ELSE
      SemErrForcedSNS( err._IdentifierOfUnexpectedKind, n1, E, L'' );
    END;
  END SemErrUnknownId;

  PROCEDURE SemErrExpectId( Id : DOM.TPSymbol );
  BEGIN
    IF Id = NIL THEN
      RETURN;
    END;
    SemErrCS( err._Expected, Id^.N );
  END SemErrExpectId;

//------------------------------------------------------------

  PROCEDURE Warning( n : CARDINAL );
  BEGIN
    M2^.Warning( n );
  END Warning;

//------------------------------------------------------------

  PROCEDURE WarningCS( n : CARDINAL; CONST S : StringsO.CString );
  BEGIN
    M2^.WarningCS( n, S );
  END WarningCS; 

//------------------------------------------------------------

  VIRTUAL PROCEDURE GenHead( G : Generator.TPGenerator; C : TGenerateControl; VAR Context : CARDINAL ) : TGenerateUnitMode;
  VAR
    N : ARRAY [0..63] OF WCHAR;
    PWLE : TPWarningListElem;
    U : TPUnit;
    b : BOOLEAN;
  BEGIN
    G^.Indent();
    CASE UnitKind OF
    | ukDefinition :
      G^.OutS( L'// DEFINITION MODULE ' );
    | ukImplementation :
      G^.OutS( L'// IMPLEMENTATION MODULE ' );
    | ukProgram :
      G^.OutS( L'// MODULE ' );
    END;
    G^.OutCS( Name ); G^.EOL();

    G^.EOL();
    G^.Indent(); G^.OutS( L'// Source: ' ); G^.OutCS( FilePath ); G^.EOL();
    G^.EOL();
    // Library:  views
    // Compiler: M2CPP Version 342 (Apr 24 2004)

    G^.LineS( L'#pragma once' );

    b := Warnings.GetFirst( OUT PWLE );
    WHILE b DO
      G^.OutS( L'#pragma warning( ' );
      IF PWLE^.On THEN
        G^.OutS( L'default: ' );
      ELSE
        G^.OutS( L'disable: ' );
      END;
      G^.OutN( PWLE^.Warning );
      G^.OutSPRP();
      G^.EOL();
      b := Warnings.NextOf( PWLE, OUT PWLE );
    END; // WHILE

    G^.LineS( L'#include "m2cpp.h"' );
    IF eoLeakChecking IN Options THEN
      G^.LineS( L'#include "m2leak.h"' );
    END;
    IF eoIS IN Options THEN
	    G^.LineS( L'#include "typeinfo.h"' );
    END;
    IF UnitKind = ukImplementation THEN
      IF ( eoPublishExports IN CurE^.Options ) AND Project.GetComponentName( N, TRUE ) THEN
        G^.Indent(); G^.OutS( L"#define " ); G^.OutS( N ); G^.EOL();
      END;
      G^.Indent(); G^.OutS( L'#include "' ); G^.OutCS( Name ); G^.OutS( L'.h"' ); G^.EOL();
    END;

    GenerateWithImported( G, UnitKind );

    G^.EOL();
    G^.LineS( L"#undef __IFACE" );
    CASE UnitKind OF
    | ukDefinition :
      IF ( eoPublishExports IN CurE^.Options ) AND Project.GetComponentName( N, TRUE ) THEN
        G^.Indent(); G^.OutS( L"#ifdef " ); G^.OutS( N ); G^.EOL();
        G^.LineS( L"  #define __IFACE __DLL_EXPORT" );
        G^.LineS( L"#else" );
        G^.LineS( L"  #define __IFACE __DLL_IMPORT" );
        G^.LineS( L"#endif" );
      END;
    | ukImplementation, ukProgram :
      // control by option
      IF eoPublishExports IN CurE^.Options THEN
        G^.LineS( L"#define __IFACE __DLL_EXPORT" );
      END;
    END;

    G^.EOL();
    G^.LineS( L'#include "m2intrinsic.h"' );

    G^.EOL();
    G^.Indent();
      G^.OutS( L"#pragma pack(push, ");
      G^.OutN( EStack.PeekBottom()^.Packing );
      G^.OutRP();
    G^.EOL();

    CASE OD^.MEnv.Prefix OF
    | mprfC, mprfWindows :
      G^.LineS( L'extern "C" {' );
    | mprfModula :
      IF UnitKind <> ukProgram THEN
        G^.OutS( L"namespace " );
          G^.OutCS( Name );
          G^.OutS( L" { " );
        G^.EOL();
      END;
    END;
    
    //*****
    G^.Enter();

    IF UnitKind = ukImplementation THEN // generate all not-H-exposed symbols
      G^.EOL();
      G^.LineS( L"// variables and structured constants coming from DEF" );
      b := OD^.GetFirst( U );
      WHILE b DO
        IF ( U^.UnitKind = ukVarDeclBlock ) OR ( U^.UnitKind = ukConstDeclBlock ) THEN
          U^.Generate( G, C + TGenerateControl{gcDeferredFromDEF} );
        END;
        b := OD^.GetNext( U );
      END;
    END;

    IF NOT TypeO.Empty THEN
      G^.EOL();
      G^.LineS( L"// forwarded opaque types" );
      TypeO.Generate( G, gcsForward );
    END;

    IF NOT TypeC.Empty THEN
      G^.EOL();
      G^.LineS( L"// unnamed nested complex types" );
      TypeC.Generate( G, C );
    END;

    IF UnitKind <> ukDefinition THEN // nebo kdyz by se nedelalo H
      IF TEnvironmentOptions{eoInitially, eoFinally} * Options <> TEnvironmentOptions{} THEN
        G^.EOL();
        G^.LineS( L"// forward to allow call module initialization and finalization in any entry procedure" );
        G^.LineS( L'// module init/finally counter' );
        G^.LineS( L'static INTEGER InitFinallyCount_ = 0;' );
        IF eoInitially IN Options THEN
          GenerateInitHeader( G, FALSE, FALSE, TRUE );
        END;
        IF eoFinally IN Options THEN
          GenerateFinalHeader( G, FALSE, FALSE, TRUE );
        END;
      END;
    END;

    G^.EOL();
    G^.LineS( L"// module itself begin" );
    
    G^.Leave();
    //*****

    RETURN gumIndent;
  END GenHead;

//------------------------------------------------------------

  VIRTUAL PROCEDURE GenTail( G : Generator.TPGenerator; C : TGenerateControl; Context : CARDINAL );
  BEGIN
    G^.Enter();
    IF UnitKind <> ukDefinition THEN
      IF ( InitCode <> NIL ) AND ( InitCode^.UnitKind <> ukProcedureDecl ) THEN
        InitCode^.Generate( G, C );
      END;
      IF ( FinalCode <> NIL ) AND ( FinalCode^.UnitKind <> ukProcedureDecl ) THEN
        FinalCode^.Generate( G, C );
      END;
    END;
    G^.Leave();

    G^.EOL();
    CASE OD^.MEnv.Prefix OF
    | mprfC, mprfWindows :
      G^.LineRB();
    | mprfModula :
      IF UnitKind <> ukProgram THEN
        G^.LineRB();
      END;
    END; // CASE
    G^.LineS( L'#pragma pack(pop)' );
    G^.Indent();
      G^.OutS( L'// end of module: ' );
      G^.OutCS( Name );
    G^.EOL();
  END GenTail;

//------------------------------------------------------------

  PROCEDURE GenerateWithImported( G : Generator.TPGenerator; Context : TUnitKind ) : BOOLEAN;
  LABEL
    Next, NextModule;
  VAR
    U0, U1, U2 : TPUnit;
    AnyOutput : BOOLEAN;
    b : BOOLEAN;
    f : BOOLEAN;
  BEGIN
    AnyOutput := FALSE;
    
    CASE Context OF
    | ukModuleInitCode, ukModuleFinalCode :
      IF OD = NIL THEN
        U0 := ADR( SELF );
      ELSE
        U0 := OD;
      END;
    ELSE
      U0 := ADR( SELF );
    END;   
    
    b := U0^.Childs.GetFirst( OUT U1 );
    f := FALSE;
    LOOP
      IF NOT b THEN
        EXIT;
      ELSIF ( U1^.UnitKind = ukImport ) OR ( U1^.UnitKind = ukImportExternal ) THEN
        // OK, continute with LOOP
      ELSIF U0 = ADR( SELF ) THEN // done, both modules parsed
        EXIT;
      ELSE // DEF done, parse implementation
        b := FALSE;
        GOTO NextModule;
      END;
      IF U1^.Empty THEN
        GOTO Next;
      END;

      CASE Context OF
      //-----
      | ukDefinition, ukImplementation, ukProgram :
        IF NOT f THEN
          G^.EOL();
          f := TRUE;
        END;
        AnyOutput := TRUE;

        (*/*
        IF U1^.UnitKind = ukImportExternal THEN // open #embed
          G^.LineS( L"#define __M2EXTERNAL // >>" );
          G^.LineS( L"#undef __M2INTERNAL // >>" );
        ELSIF eoSuppressExport IN CurE^.Options THEN
          G^.LineS( L"#undef __M2EXTERNAL // >>" );
          G^.LineS( L"#define __M2INTERNAL // >>" );
        ELSE
          G^.LineS( L"#undef __M2EXTERNAL // >>" );
          G^.LineS( L"#undef __M2INTERNAL // >>" );
        END;
        */*)

        b := U1^.GetFirst( U2 );
        AnyOutput := AnyOutput OR b;
        IF AnyOutput AND NOT f THEN
          G^.EOL();
          f := TRUE;
        END;
        WHILE b DO
          G^.OutS( L'#include "' );
            G^.OutCS( TPModule( U2 )^.OD^.OH );
            G^.OutS( L'.h"' );
          G^.EOL();
          b := U1^.GetNext( U2 );
        END; // WHILE

        (*/*
        G^.LineS( L"#undef __M2INTERNAL // <<" );
        G^.LineS( L"#undef __M2EXTERNAL // <<" );
        G^.EOL();
        */*)

      //-----
      | ukModuleInitCode :
        b := U1^.GetFirst( U2 );
        WHILE b DO
          IF eoInitially IN TPModule( U2 )^.OD^.Options THEN
            IF NOT f THEN
              G^.EOL();
              f := TRUE;
            END;
            AnyOutput := TRUE;
            G^.Indent(); TPModule( U2 )^.OD^.GenerateInitHeader( G, FALSE, TRUE, FALSE ); G^.OutSC(); G^.EOL();
          END;
          b := U1^.GetNext( U2 );
        END; // WHILE

      //-----
      | ukModuleFinalCode :
        b := U1^.GetFirst( U2 );
        WHILE b DO
          IF eoFinally IN TPModule( U2 )^.OD^.Options THEN
            IF NOT f THEN
              G^.EOL();
              f := TRUE;
            END;
            AnyOutput := TRUE;
            G^.Indent(); TPModule( U2 )^.OD^.GenerateFinalHeader( G, FALSE, TRUE, FALSE ); G^.OutSC(); G^.EOL();
          END;
          b := U1^.GetNext( U2 );
        END; // WHILE
      END; // CASE
      
    Next:
      b := U0^.Childs.NextOf( U1, OUT U1 );
    NextModule:
      IF NOT b AND ( U0 = OD ) THEN
        U0 := ADR( SELF );
        b := U0^.Childs.GetFirst( OUT U1 );
      END;
    END;

    RETURN AnyOutput;
  END GenerateWithImported;

//------------------------------------------------------------

  PROCEDURE GenerateInitHeader( G : Generator.TPGenerator; Qualified, Call, Forward : BOOLEAN );
  BEGIN
    IF Qualified THEN
      G^.OutCS( Name );
      G^.OutS( L"::" );
    END;
    IF Call THEN
      IF InitCode^.UnitKind = ukModuleInitCode THEN
        G^.OutS( L'Initially_()' );
      ELSE
        TPProcedure( InitCode )^.Generate( G, gcsName );
        G^.OutS( L'()' );
      END;
    ELSE
      IF InitCode^.UnitKind = ukModuleInitCode THEN
        G^.Indent(); G^.OutS( L'void Initially_()' );
        IF Forward THEN
          G^.OutSC();
          // generate initialization code chaining
          G^.OutS( L' __INIT_SYMBOL( Initially_ );' );
        END;
        G^.EOL();
      ELSE
        ASSERT( Forward );
        TPProcedure( InitCode )^.Generate( G, gcsForward );
        G^.Indent(); G^.OutS( L'__INIT_SYMBOL( ' ); TPProcedure( InitCode )^.Generate( G, gcsName ); G^.OutS( L' );' ); G^.EOL();
      END;
    END;
  END GenerateInitHeader;

//------------------------------------------------------------

  PROCEDURE GenerateFinalHeader( G : Generator.TPGenerator; Qualified, Call, Forward : BOOLEAN );
  BEGIN
    IF Qualified THEN
      G^.OutCS( Name );
      G^.OutS( L"::" );
    END;
    IF Call THEN
      IF FinalCode^.UnitKind = ukModuleFinalCode THEN
        G^.OutS( L'Finally_()' );
      ELSE
        TPProcedure( FinalCode )^.Generate( G, gcsName );
        G^.OutS( L'()' );
      END;
    ELSE
      IF FinalCode^.UnitKind = ukModuleFinalCode THEN
        G^.Indent(); G^.OutS( L'void Finally_()' );
        IF Forward THEN
          G^.OutSC();
          // generate initialization code chaining
          G^.OutS( L' __DONE_SYMBOL( Finally_ );' );
        END;
        G^.EOL();
      ELSE
        ASSERT( Forward );
        TPProcedure( FinalCode )^.Generate( G, gcsForward );
        G^.Indent(); G^.OutS( L'__DONE_SYMBOL( ' ); TPProcedure( FinalCode )^.Generate( G, gcsName ); G^.OutS( L' );' ); G^.EOL();
      END;
    END;
  END GenerateFinalHeader;

//------------------------------------------------------------

BEGIN
  OD := NIL;
  OI := NIL;
  CU := NIL;
  eosIF := TEnvironmentOptions{};
  InitCode := NIL;
  FinalCode := NIL;
  CurE := EStack.Push();
  SymbolKind := skModule;
  SelfS.OfSymbol := ADR( SELF );
  TypeC.UnitKind := ukForwardedTypes;
  CurTypeC := ADR( TypeC );
  TypeO.UnitKind := ukForwardedTypes;
  M2 := Parser.CreateParser();
  Lexer.M2 := M2;
  CurS := NIL;
  CurU := NIL;
  CurST := NIL;
  CurCTDU := NIL;
  ASCount := 0;
  DCount := 0;
  Emit := FALSE;
END CModule;

//============================================================

CLASS IMPLEMENTATION CVarDeclContainer;

  VIRTUAL PROCEDURE GenHead( G : Generator.TPGenerator; C : TGenerateControl; VAR Context : CARDINAL ) : TGenerateUnitMode;
  BEGIN
    RETURN gumNoIndent;
  END GenHead;

  VIRTUAL PROCEDURE GenTail( G : Generator.TPGenerator; C : TGenerateControl; Context : CARDINAL );
  VAR
    V : TPVariable;
    b : BOOLEAN;
    StructureCast : BOOLEAN := FALSE;
  BEGIN
    IF ( OfSymbol = NIL ) OR NOT( OfSymbol^.UnitKind IN uksRoutineDef + uksRoutineDecl ) OR TPProcedure( OfSymbol )^.OI^.NFT^.Empty THEN
      RETURN;
    END;          

    b := TPProcedure( OfSymbol )^.OI^.NFT^.GetFirst( V );
    WHILE b DO
      IF V^.InitE <> NIL THEN
        G^.Indent();
          G^.OutS( L'f_' );
          G^.OutCS( OfSymbol^.N );
          G^.OutS( L'.' );
          V^.Generate( G, gcsName );
          V^.GenerateInitExpression( G, C, Context );
        G^.OutSC();
        G^.EOL();
      ELSIF V^.T^.IsFormal() THEN
        G^.Indent();
        IF TPFormalType( V^.T )^.TypeModifier <> tmCONST THEN
          // do nothing
        ELSIF V^.T^.Unwrap()^.PrimitiveType = ptStructure THEN
          StructureCast := TRUE;
          // bugfix of generating CONST structure moved to frame
          // G^.OutS( L"(*(" ); V^.T^.T^.Generate( G, gcsCast ); G^.OutAST(); G^.OutS( L")&(" );
        END;
        G^.OutS( L'f_' );
        G^.OutCS( OfSymbol^.N );
        G^.OutS( L'.' );
        V^.Generate( G, gcsName );
        IF TPFormalType( V^.T )^.TypeModifier <> tmCONST THEN
          G^.OutS( L' = ' );
        ELSIF StructureCast THEN
          // bugfix of generating CONST structure moved to frame
          // G^.OutS( L')) = ' );
          G^.OutS( L' = (' );
          V^.T^.T^.Generate( G, gcsCast ); G^.OutAST();
          G^.OutS( L")&" );
        ELSE // const not struct
          G^.OutS( L' = (' ); 
          V^.T^.T^.Generate( G, gcsCast );
          IF V^.T^.IsOpenArray() THEN
            G^.OutS( L'*)' );
          ELSE
            G^.OutRP();
          END;
        END;
        V^.Generate( G, gcsName );
        G^.OutSC();
        IF V^.T^.IsOpenArray() AND ( coOASize IN OfSymbol^.Options ) THEN
          G^.OutS( L' f_' );
          G^.OutCS( OfSymbol^.N );
          G^.OutS( L'.' );
          V^.Generate( G, gcsName );
          G^.OutS( L'_HIGH = ' );
          V^.Generate( G, gcsName );
          G^.OutS( L'_HIGH;' );
        END;
        G^.EOL();
      END;
      b := TPProcedure( OfSymbol )^.OI^.NFT^.GetNext( V );
    END; // WHILE
  END GenTail;

BEGIN
  OfSymbol := NIL;
  UnitKind := ukVarDeclContainer;
END CVarDeclContainer;

//------------------------------------------------------------

CLASS IMPLEMENTATION CPropertyDef;

  VIRTUAL PROCEDURE GenHead( G : Generator.TPGenerator; C : TGenerateControl; VAR Context : CARDINAL ) : TGenerateUnitMode;
  LABEL
    REV1, REV2, REV3;
  BEGIN
    IF gcName IN C THEN
      IF TInheritanceModifier{imCOM} * IM = TInheritanceModifier{} THEN
        OutN( G, C );
        IF gcLValue IN C THEN
          G^.OutS( L'_set' );
        ELSIF gcRValue IN C THEN
          G^.OutS( L'_get()' );
        END;
      ELSIF gcLValue IN C THEN
        IF cmREF IN CM THEN
          G^.OutS( L'putref_' );
        ELSE
          G^.OutS( L'put_' );
        END;
        OutN( G, C );
      ELSIF gcRValue IN C THEN
        G^.OutS( L'get_' );
        OutN( G, C );
      END;
      RETURN gumSimple;
    END;

    IF cmREV IN CM THEN
      GOTO REV1;
    END;
  REV2:
    IF NOT( cmWO IN CM ) THEN
      G^.Indent();
        IF TInheritanceModifier{imAbstract, imVirtual} * IM <> TInheritanceModifier{} THEN
          G^.OutS( L'virtual ' );
        ELSIF imFinal IN IM THEN
          IF G^.goManaged() THEN
            G^.OutS( L'__sealed ' );
          ELSE
            G^.OutS( L'virtual ' );
          END;
        END;
        IF cmINLINE IN CM THEN
          G^.OutS( L'inline ' );
        END;
        IF TInheritanceModifier{imCOM} * IM = TInheritanceModifier{} THEN
          T^.Generate( G, gcsExplicit );
          G^.OutSP();
          IF cpCDecl IN Options THEN
            G^.OutS( L'__cdecl ' );
          ELSIF cpStdCall IN Options THEN
            G^.OutS( L'__stdcall ' );
          ELSIF cpFastCall IN Options THEN
            G^.OutS( L'__fastcall ' );
          END;
          G^.OutCS( N );
          G^.OutS( L'_get()' );
        ELSE
          G^.OutS( L'HRESULT ' );
          IF cpCDecl IN Options THEN
            G^.OutS( L'__cdecl ' );
          ELSIF cpStdCall IN Options THEN
            G^.OutS( L'__stdcall ' );
          ELSIF cpFastCall IN Options THEN
            G^.OutS( L'__fastcall ' );
          END;
          G^.OutS( L'get_' );
          G^.OutCS( N );
          G^.OutS( L'( OUT ' );
          T^.Generate( G, gcsExplicit );
          G^.OutS( L'* RetVal )' );
        END;
      IF imAbstract IN IM THEN
        G^.OutS( L' = 0;' ); // pure virtual method
      ELSE
        G^.OutSC();
      END;
      G^.EOL();
    END;
    IF cmREV IN CM THEN
      GOTO REV3;
    END;
   
  REV1:
    IF NOT( cmRO IN CM ) THEN
      G^.Indent();
        IF TInheritanceModifier{imAbstract, imVirtual} * IM <> TInheritanceModifier{} THEN
          G^.OutS( L'virtual ' );
        ELSIF imFinal IN IM THEN
          IF G^.goManaged() THEN
            G^.OutS( L'__sealed ' );
          ELSE
            G^.OutS( L'virtual ' );
          END;
        END;
        IF cmINLINE IN CM THEN
          G^.OutS( L'inline ' );
        END;
        IF TInheritanceModifier{imCOM} * IM = TInheritanceModifier{} THEN
          G^.OutS( L'void ' );
          IF cpCDecl IN Options THEN
            G^.OutS( L'__cdecl ' );
          ELSIF cpStdCall IN Options THEN
            G^.OutS( L'__stdcall ' );
          ELSIF cpFastCall IN Options THEN
            G^.OutS( L'__fastcall ' );
          END;
          G^.OutCS( N );
          G^.OutS( L'_set( ' );
          IF T^.Unwrap()^.PrimitiveType = DOM.ptStructure THEN
            G^.OutS( L'const ' );
            T^.Generate( G, gcsExplicit );
            G^.OutS( L'& Value )' );
          ELSE
            T^.Generate( G, gcsExplicit );
            G^.OutS( L' Value )' );
          END;
        ELSIF cmREF IN CM THEN
          G^.OutS( L'HRESULT ' );
          IF cpCDecl IN Options THEN
            G^.OutS( L'__cdecl ' );
          ELSIF cpStdCall IN Options THEN
            G^.OutS( L'__stdcall ' );
          ELSIF cpFastCall IN Options THEN
            G^.OutS( L'__fastcall ' );
          END;
          G^.OutS( L'putref_' );
          G^.OutCS( N );
          G^.OutS( L'( ' );
          T^.Generate( G, gcsExplicit );
          G^.OutS( L' Value )' );
        ELSE
          G^.OutS( L'HRESULT ' );
          IF cpCDecl IN Options THEN
            G^.OutS( L'__cdecl ' );
          ELSIF cpStdCall IN Options THEN
            G^.OutS( L'__stdcall ' );
          ELSIF cpFastCall IN Options THEN
            G^.OutS( L'__fastcall ' );
          END;
          G^.OutS( L'put_' );
          G^.OutCS( N );
          G^.OutS( L'( ' );
          IF T^.Unwrap()^.PrimitiveType = DOM.ptStructure THEN
            G^.OutS( L'const ' );
            T^.Generate( G, gcsExplicit );
            G^.OutS( L'& Value )' );
          ELSE
            T^.Generate( G, gcsExplicit );
            G^.OutS( L' Value )' );
          END;
        END;
      IF imAbstract IN IM THEN
        G^.OutS( L' = 0;' ); // pure virtual method
      ELSE
        G^.OutSC();
      END;
      G^.EOL();
    END;
    IF cmREV IN CM THEN
      GOTO REV2;
    END;

  REV3:
    RETURN gumSimple;
  END GenHead;

BEGIN
  UnitKind := ukPropertyDef;
  SymbolKind := skProperty;
END CPropertyDef;

//------------------------------------------------------------

CLASS IMPLEMENTATION CIndexerDef;

  VIRTUAL PROCEDURE GenHead( G : Generator.TPGenerator; C : TGenerateControl; VAR Context : CARDINAL ) : TGenerateUnitMode;
  BEGIN
    IF gcName IN C THEN
      IF gcLValue IN C THEN
        IF imCOM IN IM THEN
          G^.OutS( L'set_item' );
        ELSE
          G^.OutS( L'ix_set' );
        END;
      ELSIF gcRValue IN C THEN
        IF imCOM IN IM THEN
          G^.OutS( L'get_item' );
        ELSE
          G^.OutS( L'ix_get' );
        END;
      END;
      RETURN gumSimple;
    END;
    
    IF NOT( cmWO IN CM ) THEN
      GenHeadInternal( G, C, cmRO );
    END;
    IF NOT( cmRO IN CM ) THEN
      GenHeadInternal( G, C, cmWO );
    END;
    RETURN gumSimple;
  END GenHead;

  PROCEDURE GenHeadInternal( G : Generator.TPGenerator; C : TGenerateControl; _CM : TCodeModifierItem ) : TGenerateUnitMode;
  BEGIN
    G^.Indent();
      IF TInheritanceModifier{imAbstract, imVirtual} * IM <> TInheritanceModifier{} THEN
        G^.OutS( L'virtual ' );
      ELSIF imFinal IN IM THEN
        IF G^.goManaged() THEN
          G^.OutS( L'__sealed ' );
        ELSE
          G^.OutS( L'virtual ' );
        END;
      END;
      IF cmINLINE IN CM THEN
        G^.OutS( L'inline ' );
      END;
      IF imCOM IN IM THEN
        IF _CM = cmRO THEN
          G^.OutS( L'HRESULT ' );
          IF cpCDecl IN Options THEN
            G^.OutS( L'__cdecl ' );
          ELSIF cpStdCall IN Options THEN
            G^.OutS( L'__stdcall ' );
          ELSIF cpFastCall IN Options THEN
            G^.OutS( L'__fastcall ' );
          END;
          G^.OutS( L'get_item( ' );
          IndexType^.Generate( G, gcsExplicitParameter );
          G^.OutS( L' Index, OUT ' );
          T^.Generate( G, gcsExplicit ); G^.OutS( L"* RetVal )" );
        ELSIF _CM = cmWO THEN
          G^.OutS( L'HRESULT ' );
          IF cpCDecl IN Options THEN
            G^.OutS( L'__cdecl ' );
          ELSIF cpStdCall IN Options THEN
            G^.OutS( L'__stdcall ' );
          ELSIF cpFastCall IN Options THEN
            G^.OutS( L'__fastcall ' );
          END;
          G^.OutS( L'set_item( ' );
          IndexType^.Generate( G, gcsExplicitParameter );
          G^.OutS( L' Index, ' );
          IF T^.Unwrap()^.PrimitiveType = DOM.ptStructure THEN
            G^.OutS( L'const ' );
            T^.Generate( G, gcsExplicit );
            G^.OutS( L'& Value )' );
          ELSE
            T^.Generate( G, gcsExplicit );
            G^.OutS( L' Value )' );
          END;
        END;
      ELSE
        IF _CM = cmRO THEN
          T^.Generate( G, gcsExplicit ); G^.OutSP();
          IF cpCDecl IN Options THEN
            G^.OutS( L'__cdecl ' );
          ELSIF cpStdCall IN Options THEN
            G^.OutS( L'__stdcall ' );
          ELSIF cpFastCall IN Options THEN
            G^.OutS( L'__fastcall ' );
          END;
          G^.OutS( L'ix_get( ' );
          IF IndexType^.IsOpenArray() AND ( coOASize IN Options ) THEN
            Types.TCARDINAL^.Generate( G, gcsExplicit );
            G^.OutS( L' Index_HIGH, ' );
          END;
          IndexType^.Generate( G, gcsExplicitParameter );
          G^.OutS( L' Index )' );
        ELSIF _CM = cmWO THEN
          G^.OutS( L'void ' );
          IF cpCDecl IN Options THEN
            G^.OutS( L'__cdecl ' );
          ELSIF cpStdCall IN Options THEN
            G^.OutS( L'__stdcall ' );
          ELSIF cpFastCall IN Options THEN
            G^.OutS( L'__fastcall ' );
          END;
          G^.OutS( L'ix_set( ' );
          IF IndexType^.IsOpenArray() AND ( coOASize IN Options ) THEN
            Types.TCARDINAL^.Generate( G, gcsExplicit );
            G^.OutS( L' Index_HIGH, ' );
          END;
          IndexType^.Generate( G, gcsExplicitParameter );
          G^.OutS( L' Index, ' );
          IF T^.Unwrap()^.PrimitiveType = DOM.ptStructure THEN
            G^.OutS( L'const ' );
            T^.Generate( G, gcsExplicitParameter );
            G^.OutS( L'& Value )' );
          ELSE
            T^.Generate( G, gcsExplicitParameter );
            G^.OutS( L' Value )' );
          END;
        END;
      END;
    IF imAbstract IN IM THEN
      G^.OutS( L' = 0;' ); // pure virtual method
    ELSE
      G^.OutSC();
    END;
    G^.EOL();
    RETURN gumSimple;
  END GenHeadInternal;

BEGIN
  UnitKind := ukIndexerDef;
  SymbolKind := skIndexer;
  IndexType := NIL;
END CIndexerDef;

//------------------------------------------------------------

CLASS IMPLEMENTATION COperatorDef;

  VIRTUAL PROCEDURE GenHead( G : Generator.TPGenerator; C : TGenerateControl; VAR Context : CARDINAL ) : TGenerateUnitMode;
  BEGIN
    G^.Indent();
      IF TInheritanceModifier{imAbstract, imVirtual} * IM <> TInheritanceModifier{} THEN
        G^.OutS( L'virtual ' );
      ELSIF imFinal IN IM THEN
        IF G^.goManaged() THEN
          G^.OutS( L'__sealed ' );
        ELSE
          G^.OutS( L'virtual ' );
        END;
      END;
      IF T = Types.TUnknown THEN
        G^.OutS( L'void ' );
      ELSE
        T^.Generate( G, gcsExplicit ); G^.OutSP();
      END;

      IF cpCDecl IN Options THEN
        G^.OutS( L'__cdecl ' );
      ELSIF cpStdCall IN Options THEN
        G^.OutS( L'__stdcall ' );
      ELSIF cpFastCall IN Options THEN
        G^.OutS( L'__fastcall ' );
      END;
      IF T^.Unwrap()^.PrimitiveType = ptStructure THEN
        // G^.OutS( L'& operator ' ); -- result, if typed, must be copied, typically operators prepare result in local variable, which cannot be referenced in outer
        G^.OutS( L'operator ' );
      ELSE
        G^.OutS( L'operator ' );
      END;

      G^.OutS( opString[O] );
      G^.OutS( L'( ' );
      IF NOT OperandType^.IsFormal() AND ( OperandType^.Unwrap()^.PrimitiveType = DOM.ptStructure ) THEN
        G^.OutS( L'const ' );
        OperandType^.Generate( G, gcsExplicitParameter );
        G^.OutS( L'& Operand )' );
      ELSE
        OperandType^.Generate( G, gcsExplicitParameter );
        G^.OutS( L' Operand )' );
      END;
    IF imAbstract IN IM THEN
      G^.OutS( L' = 0;' ); // pure virtual method
    ELSE
      G^.OutSC();
    END;
    G^.EOL();
    RETURN gumSimple;
  END GenHead;

BEGIN
  UnitKind := ukOperatorDef;
  SymbolKind := skOperator;
  O := opUnknown;
  OperandType := NIL;
END COperatorDef;

//============================================================

CLASS IMPLEMENTATION CExpression;

  PROCEDURE Init3( T : TPType; OK : TOrdinalKind; Literal : ARRAY OF WCHAR );
  BEGIN
    UnitKind := ukExpression;
    NEW( N );
    N^.T := T;
    N^.r.N := enLiteral;
    N^.r.OK := OK;
    N^.r.S.FromOA( Literal );
  END Init3;

  PROCEDURE Evaluate( VAR V : CEValue; ItemIndex : INT64 );
  BEGIN
    IF ItemIndex <> 0 THEN
      N^.Evaluate( V, ItemIndex );
    ELSIF Cache.T = NIL THEN
      N^.Evaluate( V, ItemIndex );
      Cache.CopyFrom( V );
    ELSE
      V.CopyFrom( Cache );
    END;
  END Evaluate;

  PROCEDURE High() : CARDINAL;
  VAR
    EV : CEValue;
    high : CARDINAL;
  BEGIN
    high := -1;
    IF N^.r.N = enLiteral THEN
      IF N^.r.S.Empty THEN
        high := 0;
      ELSE
        high := N^.r.S.Length - 1;
      END;
    ELSE
      N^.Evaluate( EV, 0 );
      IF ( EV.T^.Unwrap()^.PrimitiveType = ptStructure ) AND ( EV.T^.Unwrap()^.TypeKind = tkStringArray ) AND ( EV.E <> NIL ) THEN
        // reevaluate string arrays, epEMIT is special case, which leaves E = NIL --> see last AND
        EV.E^.Evaluate( EV, 0 );
      END;
      IF NOT EV.S.Empty THEN
        high := EV.S.Length - 1;
      END;
    END;
    RETURN high;
  END High;

  VIRTUAL PROCEDURE GenHead( G : Generator.TPGenerator; C : TGenerateControl; VAR Context : CARDINAL ) : TGenerateUnitMode;
  VAR
    CI : TCastInfo;
  BEGIN
    IF TargetT <> NIL THEN
      T^.CheckAndGenerateCast( G, TargetT, viCONST IN VI, CI );
      IF ciStructure IN CI THEN
        Context := 1;
      END;
    END;
    IF eoStringLiteralAsChars IN Options THEN
      N^.Generate( G, C + TGenerateControl{gcFirst, gcStringLiteralAsChars} );
    ELSE
      N^.Generate( G, C + TGenerateControl{gcFirst} );
    END;
    RETURN gumNoIndent;
  END GenHead;

  VIRTUAL PROCEDURE GenTail( G : Generator.TPGenerator; C : TGenerateControl; Context : CARDINAL );
  BEGIN
    IF Context = 1 THEN
      G^.OutS( L'))' );
    END;
  END GenTail;

	PROCEDURE AnalyzeAndGenerateOAHigh( G : Generator.TPGenerator; TargetT : TPType ); // TargetT -- destination parameter type
	
		PROCEDURE RecomputeHighTail( SourceBase, TargetBase : TPType );
		BEGIN
			G^.OutS( L'*' );
			G^.OutS( L"sizeof(" ); SourceBase^.Generate( G, gcsName );
			G^.OutS( L")/" );
			G^.OutS( L"sizeof(" ); TargetBase^.Generate( G, gcsName );
			G^.OutS( L")-1" );
		END RecomputeHighTail;

	VAR
		LT : TPType := T^.Unwrap();
		LTb : TPType := LT^.T^.Unwrap(); // base
		PT : TPType := TargetT^.Unwrap();
		PTb : TPType := PT^.T^.Unwrap(); // base
		CastFlag : BOOLEAN := FALSE;
		OAConstructorFlag : BOOLEAN;
		OASizeFlag : BOOLEAN := coOASize IN TargetT^.Options;
		RefFlag : BOOLEAN := FALSE;
		SameBase : BOOLEAN := ( LTb = PTb ) OR ( LTb^.OccupiedMemory() = PTb^.OccupiedMemory() );
	BEGIN
		IF LT^.TypeKind = tkStringArray THEN
			IF OASizeFlag THEN
				IF SameBase THEN
					G^.OutN( High());
				ELSE
					G^.OutN( High()+1 ); 
					RecomputeHighTail( LTb, PTb );
				END;
			END;
			// tkStringArray is always const
			CastFlag := ( LTb <> PTb ) OR ( N^.r.N = enDesignator ) AND ( N^.r.V^.r.DK = dkId );

		ELSIF LT^.TypeKind = tkOpenArray THEN // OK, checked
			OAConstructorFlag := ( N^.r.N = enDesignator ) AND ( N^.r.V^.r.DK = dkEmbeddedProcedure ) AND 
										(( N^.r.V^.r.EP = epOA ) OR ( N^.r.V^.r.EP = epOAsz ));
			IF OASizeFlag THEN
				//...
				IF NOT OAConstructorFlag THEN
					IF N^.r.V^.r.IdA = saParentProcedureVariable THEN // high is of parent procedure parameter
						G^.OutS( L'f_' );
						N^.r.V^.r.GO^.OutN( G, gcsName );
						G^.OutS( L'->' );
					END;
					IF SameBase THEN
						N^.r.V^.r.Id^.OutN( G, gcsName ); G^.OutS( L"_HIGH" );
					ELSE
						G^.OutLP(); N^.r.V^.r.Id^.OutN( G, gcsName ); G^.OutS( L"_HIGH+1)" );
						RecomputeHighTail( LTb, PTb );
					END;
				//...
				ELSIF N^.r.V^.r.EP = epOA THEN// string open array constructor
					WITH N^.r.V^ DO
						r.U1^.Generate( G, gcsDefault );
					END;
				//...
				ELSE // sz string open array constructor
					G^.OutS( L"OA_MAX" );
				END;
			END;
			CastFlag := OAConstructorFlag OR // CastFlag cannot be automatical, CPP does not allow passing "char(*)[xxx]" to "char*"
							//..
							// should not be Compatible replaced with ( LTb <> PTb ) as in tkStringArray above?
							NOT PTb^.Compatible( cmAssign, LTb ) OR // WCHAR -> WORD is OK, will not this be problem for other types? -- yes, will be, CHAR -> BYTE is problem
							//..
							NOT Types.TStorage^.Compatible( cmOperation, LT^.T ) AND
							Types.TStorage^.Compatible( cmOperation, PT^.T ) OR // e.g. cast of CHAR to BYTE, M2 specialty
							//..
							TargetT^.IsFormal() AND // passing const to not const looses qualifiers...
							( TPFormalType( TargetT )^.TypeModifier <> tmCONST ) AND ( TPFormalType( T )^.TypeModifier = tmCONST );

		ELSIF LT^.TypeKind = tkArray THEN // OK, checked
			IF OASizeFlag THEN
				IF SameBase THEN
					G^.OutN( TPArray( LT )^.High());
				ELSE
					G^.OutN( TPArray( LT )^.High()+1);
					RecomputeHighTail( LTb, PTb );
				END;
			END;
			RefFlag := TRUE;
			// CastFlag cannot be automatical, CPP does not allow passing "char(*)[xxx]" to "char*"
			// CastFlag := NOT PT^.T^.Compatible( cmAssign, LT^.T ); // WCHAR -> WORD is OK, will not this be problem for other types?;
			CastFlag := TRUE;
		ELSE // OK, checked
			IF NOT OASizeFlag THEN
			  // pass down
			ELSIF PTb^.Compatible( cmAssign, LT ) THEN
			  G^.OutS( L"0" );
			ELSE
			  G^.OutS( L"sizeof(" ); LT^.Generate( G, gcsName );
			  G^.OutS( L")/" );
			  G^.OutS( L"sizeof(" ); PTb^.Generate( G, gcsName );
			  G^.OutS( L")-1" );
			END;
			IF N^.r.N = enDesignator THEN
			  RefFlag := TRUE;
			  CastFlag := ( viConst IN VI ) OR
							  NOT PTb^.Compatible( cmAssign, LT ) OR
							  NOT Types.TStorage^.Compatible( cmOperation, LT ) AND
							  Types.TStorage^.Compatible( cmOperation, PT^.T ); // e.g. cast of INT8 to BYTE, M2 specialty
			END;
		END;
		IF OASizeFlag THEN
			G^.OutCmSP();
		END;
		IF CastFlag THEN
			G^.OutLP(); TargetT^.Generate( G, gcsCast ); G^.OutAST(); G^.OutRP();
		END;
		IF RefFlag THEN
			G^.OutS( L'&' );
		END;
	END AnalyzeAndGenerateOAHigh;

BEGIN
  UnitKind := ukExpression;
  T := NIL;
  TargetT := NIL;
  N := NIL;
  VI := TValueInfo{};
END CExpression;

//============================================================

CLASS IMPLEMENTATION CEValue;

  PROCEDURE ToInteger() : INT64;
  BEGIN
    IF Types.TBOOLEAN^.Compatible( cmOperation, T ) THEN
      RETURN INT64( B );
    ELSIF Types.TOrdinalNumber^.Compatible( cmOperation, T ) THEN
      RETURN I;
    ELSIF Types.TLONGREAL^.Compatible( cmOperation, T ) THEN
      RETURN INT64( R );
    ELSIF Types.TTCHAR^.Compatible( cmOperation, T ) THEN
      RETURN INT64( S[0] );
    ELSIF Types.TString^.Compatible( cmOperation, T ) THEN
      TRY
         RETURN S.ToINT64( 10 );
      CATCH : StringsO.CStringException DO
         RETURN 0;
      END;
    ELSIF T^.Unwrap()^.TypeKind = tkEnumeration THEN
      RETURN I;
    END;
    RETURN 0;
  END ToInteger;
  
  PROCEDURE CopyFrom( CONST V : CEValue );
  BEGIN
    T := V.T;
    B := V.B;
    I := V.I;
    R := V.R;
    E := V.E;
    S.Assign( V.S );  
  END CopyFrom;

BEGIN
  T := NIL;
  B := FALSE;
  I := 0;
  R := 0.0;
  E := NIL;
END CEValue;

//============================================================

CLASS IMPLEMENTATION CENode;

  PROCEDURE Evaluate( VAR EV : CEValue; ItemIndex : INT64 );
  VAR
    EV2 : CEValue;
    Literal : ARRAY [0..127] OF WCHAR;
  BEGIN
    CASE r.N OF
    | enDesignator :
      r.V^.Evaluate( EV, ItemIndex );

    | enLiteral :
      EV.T := T;
      IF Types.TBOOLEAN^.Compatible( cmOperation, T ) THEN
        EV.B := r.S.EqualsOA( L'TRUE' );
      ELSIF Types.TOrdinalNumber^.Compatible( cmOperation, T ) THEN
        r.S.ToOA( OUT Literal );
        IF r.OK <> okDecimal THEN
          Literal[LENGTH(Literal)-1] := 0W;
        END;
        CASE r.OK OF
        | okDecimal :
          Strings.ToINT64W( Literal, 10, OUT EV.I );
        | okHexadecimal :
          Strings.ToINT64W( Literal, 16, OUT EV.I );
        | okOctal :
          Strings.ToINT64W( Literal, 8, OUT EV.I );
        | okBinary : 
          Strings.ToINT64W( Literal, 2, OUT EV.I );
        END;
      ELSIF Types.TFloat^.Compatible( cmOperation, T ) THEN
        TRY
          EV.R := r.S.ToLONGREAL();
        CATCH e : StringsO.CStringException DO
          EV.R := 0.0;
        END;
      ELSIF Types.TString^.Compatible( cmOperation, T ) THEN
        EV.S.Assign( r.S );
      ELSIF T^.Unwrap()^.TypeKind = tkEnumeration THEN
         TRY
            EV.I := r.S.ToINT64( 10 );
         CATCH : StringsO.CStringException DO
            EV.I := 0;
         END;
      END;

    | enOperation :
      CASE r.O OF
      //-----
      | opSubExpr :
        r.L^.Evaluate( EV, 0 );

      //-----
      | opEQ:
        r.L^.Evaluate( EV, 0 );
        r.R^.Evaluate( EV2, 0 );
        IF Types.TBOOLEAN^.Compatible( cmOperation, EV.T ) THEN
          EV.B := EV.B = EV2.B;
        ELSIF Types.TOrdinalNumber^.Compatible( cmOperation, EV.T ) THEN
          EV.B := EV.I = EV2.I;
        ELSIF Types.TLONGREAL^.Compatible( cmOperation, EV.T ) THEN
          EV.B := EV.R = EV2.R;
        ELSIF Types.TString^.Compatible( cmOperation, EV.T ) THEN
          EV.B := EV.S = EV2.S;
          EV.S.Dispose();
          EV2.S.Dispose();
        ELSE
          ASSERT( FALSE );
        END;
        EV.T := Types.TBOOLEAN;
      //-----
      | opNEQ:
        r.L^.Evaluate( EV, 0 );
        r.R^.Evaluate( EV2, 0 );
        IF Types.TBOOLEAN^.Compatible( cmOperation, EV.T ) THEN
          EV.B := EV.B <> EV2.B;
        ELSIF Types.TOrdinalNumber^.Compatible( cmOperation, EV.T ) THEN
          EV.B := EV.I <> EV2.I;
        ELSIF Types.TLONGREAL^.Compatible( cmOperation, EV.T ) THEN
          EV.B := EV.R <> EV2.R;
        ELSIF Types.TString^.Compatible( cmOperation, EV.T ) THEN
          EV.B := EV.S <> EV2.S;
          EV.S.Dispose();
          EV2.S.Dispose();
        ELSE
          ASSERT( FALSE );
        END;
        EV.T := Types.TBOOLEAN;
      //-----
      | opLT:
        r.L^.Evaluate( EV, 0 );
        r.R^.Evaluate( EV2, 0 );
        IF Types.TBOOLEAN^.Compatible( cmOperation, EV.T ) THEN
          EV.B := EV.B < EV2.B;
        ELSIF Types.TOrdinalNumber^.Compatible( cmOperation, EV.T ) THEN
          EV.B := EV.I < EV2.I;
        ELSIF Types.TLONGREAL^.Compatible( cmOperation, EV.T ) THEN
          EV.B := EV.R < EV2.R;
        ELSIF Types.TString^.Compatible( cmOperation, EV.T ) THEN
          EV.B := EV.S.Compare( EV2.S ) < 0;
          EV.S.Dispose();
          EV2.S.Dispose();
        ELSE
          ASSERT( FALSE );
        END;
        EV.T := Types.TBOOLEAN;
      //-----
      | opGT:
        r.L^.Evaluate( EV, 0 );
        r.R^.Evaluate( EV2, 0 );
        IF Types.TBOOLEAN^.Compatible( cmOperation, EV.T ) THEN
          EV.B := EV.B > EV2.B;
        ELSIF Types.TOrdinalNumber^.Compatible( cmOperation, EV.T ) THEN
          EV.B := EV.I > EV2.I;
        ELSIF Types.TLONGREAL^.Compatible( cmOperation, EV.T ) THEN
          EV.B := EV.R > EV2.R;
        ELSIF Types.TString^.Compatible( cmOperation, EV.T ) THEN
          EV.B := EV.S.Compare( EV2.S ) > 0;
          EV.S.Dispose();
          EV2.S.Dispose();
        ELSE
          ASSERT( FALSE );
        END;
        EV.T := Types.TBOOLEAN;
      //-----
      | opLTE:
        r.L^.Evaluate( EV, 0 );
        r.R^.Evaluate( EV2, 0 );
        IF Types.TBOOLEAN^.Compatible( cmOperation, EV.T ) THEN
          EV.B := EV.B <= EV2.B;
        ELSIF Types.TOrdinalNumber^.Compatible( cmOperation, EV.T ) THEN
          EV.B := EV.I <= EV2.I;
        ELSIF Types.TLONGREAL^.Compatible( cmOperation, EV.T ) THEN
          EV.B := EV.R <= EV2.R;
        ELSIF Types.TString^.Compatible( cmOperation, EV.T ) THEN
          EV.B := EV.S.Compare( EV2.S ) <= 0;
          EV.S.Dispose();
          EV2.S.Dispose();
        ELSE
          ASSERT( FALSE );
        END;
        EV.T := Types.TBOOLEAN;
      //-----
      | opGTE:
        r.L^.Evaluate( EV, 0 );
        r.R^.Evaluate( EV2, 0 );
        IF Types.TBOOLEAN^.Compatible( cmOperation, EV.T ) THEN
          EV.B := EV.B >= EV2.B;
        ELSIF Types.TOrdinalNumber^.Compatible( cmOperation, EV.T ) THEN
          EV.B := EV.I >= EV2.I;
        ELSIF Types.TLONGREAL^.Compatible( cmOperation, EV.T ) THEN
          EV.B := EV.R >= EV2.R;
        ELSIF Types.TString^.Compatible( cmOperation, EV.T ) THEN
          EV.B := EV.S.Compare( EV2.S ) >= 0;
          EV.S.Dispose();
          EV2.S.Dispose();
        ELSE
          ASSERT( FALSE );
        END;
        EV.T := Types.TBOOLEAN;

      //-----
      | opANDL:
        r.L^.Evaluate( EV, 0 );
        r.R^.Evaluate( EV2, 0 );
        EV.B := EV.B AND EV2.B;
      | opORL:
        r.L^.Evaluate( EV, 0 );
        r.R^.Evaluate( EV2, 0 );
        EV.B := EV.B OR EV2.B;
      | opNotL:
        r.L^.Evaluate( EV, 0 );
        IF Types.TBOOLEAN^.Compatible( cmOperation, EV.T ) THEN
          EV.B := NOT EV.B;
        ELSE
          EV.I := NOT EV.I;
        END;

      //-----
      | opANDB:
        r.L^.Evaluate( EV, 0 );
        r.R^.Evaluate( EV2, 0 );
        EV.I := EV.I AND EV2.I;
      | opORB:
        r.L^.Evaluate( EV, 0 );
        r.R^.Evaluate( EV2, 0 );
        EV.I := EV.I OR EV2.I;
      | opEORB:
        r.L^.Evaluate( EV, 0 );
        r.R^.Evaluate( EV2, 0 );
        EV.I := EV.I XOR EV2.I;
      | opNotB:
        r.L^.Evaluate( EV, 0 );
        EV.I := NOT EV.I;

      //-----
      | opSgnM :
        r.R^.Evaluate( EV, 0 );
        EV.I := -EV.I;
      | opSgnP :
        r.R^.Evaluate( EV, 0 );
      | opAdd :
        r.L^.Evaluate( EV, 0 );
        r.R^.Evaluate( EV2, 0 );
        IF Types.TOrdinalNumber^.Compatible( cmOperation, EV.T ) THEN
          EV.I := EV.I + EV2.I;
        ELSIF Types.TFloat^.Compatible( cmOperation, EV.T ) THEN
          EV.R := EV.R + EV2.R;
        ELSIF EV.T^.Unwrap()^.TypeKind = tkEnumeration THEN
          EV.I := EV.I + EV2.I;
        ELSE
          ASSERT( FALSE );
        END;
      | opConcat :
        r.L^.Evaluate( EV, 0 );
        r.R^.Evaluate( EV2, 0 );
        EV.S.Append( EV2.S ); EV2.S.Dispose();
      | opSub :
        r.L^.Evaluate( EV, 0 );
        r.R^.Evaluate( EV2, 0 );
        IF Types.TOrdinalNumber^.Compatible( cmOperation, EV.T ) THEN
          EV.I := EV.I - EV2.I;
        ELSIF Types.TFloat^.Compatible( cmOperation, EV.T ) THEN
          EV.R := EV.R - EV2.R;
        ELSIF EV.T^.Unwrap()^.TypeKind = tkEnumeration THEN
          EV.I := EV.I + EV2.I;
        ELSE
          ASSERT( FALSE );
        END;
      | opMult :
        r.L^.Evaluate( EV, 0 );
        r.R^.Evaluate( EV2, 0 );
        IF Types.TOrdinalNumber^.Compatible( cmOperation, EV.T ) THEN
          EV.I := EV.I * EV2.I;
        ELSIF Types.TFloat^.Compatible( cmOperation, EV.T ) THEN
          EV.R := EV.R * EV2.R;
        ELSIF EV.T^.Unwrap()^.TypeKind = tkEnumeration THEN
          EV.I := EV.I + EV2.I;
        ELSE
          ASSERT( FALSE );
        END;
      | opDiv :
        r.L^.Evaluate( EV, 0 );
        r.R^.Evaluate( EV2, 0 );
        EV.R := EV.R / EV2.R;
      | opIDiv :
        r.L^.Evaluate( EV, 0 );
        r.R^.Evaluate( EV2, 0 );
        EV.I := EV.I DIV EV2.I;
      | opRem, opMod :
        r.L^.Evaluate( EV, 0 );
        r.R^.Evaluate( EV2, 0 );
        EV.I := EV.I MOD EV2.I;
      | opLShift :
        r.L^.Evaluate( EV, 0 );
        r.R^.Evaluate( EV2, 0 );
        EV.I := EV.I << EV2.I;
      | opRShift :
        r.L^.Evaluate( EV, 0 );
        r.R^.Evaluate( EV2, 0 );
        EV.I := EV.I >> EV2.I;

      END; // CASE O
    END; // CASE N
  END Evaluate;

  PROCEDURE Generate( G : Generator.TPGenerator; C : TGenerateControl );

    PROCEDURE OutStringLiteral( T : TPType; S : StringsO.CString );
    BEGIN
      IF NOT( gcCharLiteralAsStringForOA IN C ) AND Types.TBCHAR^.Compatible( cmOperation, T ) THEN
        IF S.Empty THEN
          G^.OutS( L"'\x0'" );
        ELSE
          G^.OutANSIEscapeCS( S, TRUE );
        END;
      ELSIF NOT( gcCharLiteralAsStringForOA IN C ) AND Types.TWCHAR^.Compatible( cmOperation, T ) THEN
        IF S.Empty THEN
          G^.OutS( L"L'\x0'" );
        ELSE
          G^.OutUNICODEEscapeCS( S, TRUE );
        END;
      ELSIF Types.TBString^.Compatible( cmOperation, T ) THEN
        IF S.Empty THEN
          G^.OutS( L'""' );
        ELSIF gcStringLiteralAsChars IN C THEN
          G^.OutANSIEscapeCS( S, TRUE );
        ELSE
          G^.OutS( L'"' ); G^.OutANSIEscapeCS( S, FALSE ); G^.OutS( L'"' );
        END;
      ELSIF Types.TWString^.Compatible( cmOperation, T ) THEN
        IF S.Empty THEN
          G^.OutS( L'L""' );
        ELSIF gcStringLiteralAsChars IN C THEN
          G^.OutUNICODEEscapeCS( S, TRUE );
        ELSE
          G^.OutS( L'L"' ); G^.OutUNICODEEscapeCS( S, FALSE ); G^.OutS( L'"' );
        END;
      END;
    END OutStringLiteral;

  LABEL
    DoEQUALSM;
  VAR
    c : CARDINAL;
    EV : CEValue;
    Literal : ARRAY [0..31] OF WCHAR;
    UT : TPType;
    pf : BOOLEAN;
  BEGIN
    CASE r.N OF
    | enDesignator :
      r.V^.Generate( G, gcsDesignator );

    | enLiteral :
      IF Types.TBOOLEAN^.Compatible( cmOperation, T ) THEN
        IF r.S.EqualsOA( L'TRUE' ) THEN
          G^.OutS( L'true' );
        ELSE
          G^.OutS( L'false' );
        END;
      ELSIF Types.TADDRESS^.Compatible( cmOperation, T ) THEN
        G^.OutS( L'NIL' );
      ELSIF Types.TOrdinalNumber^.Compatible( cmOperation, T ) THEN
        r.S.ToOA( OUT Literal );
        IF r.OK = okHexadecimal THEN
          c := Strings.LastIndexOfCharW( Literal, L'H', 0 );
          IF c < 32 THEN
            Literal[c] := WCHAR( 0 );
          END;
          G^.OutS( L'0x' );
          G^.OutS( Literal );
        ELSIF r.OK = okDecimal THEN // trim leading zeros
          WHILE ( Literal[0] = L'0' ) AND ( Literal[1] <> WCHAR( 0 )) DO
            Strings.RemoveW( REF Literal, 0, 1 );
          END;
          G^.OutS( Literal );
        ELSIF r.OK = okOctal THEN
          c := Strings.LastIndexOfCharW( Literal, L'B', 0 );
          IF c < 32 THEN
            Literal[c] := WCHAR( 0 );
          END;
          G^.OutS( L'0' );
          G^.OutS( Literal );
        ELSE // okBinary
          c := Strings.LastIndexOfCharW( Literal, L'L', 0 );
          IF c < 32 THEN
            Literal[c] := WCHAR( 0 );
          END;
          Strings.ToCARD32W( Literal, 2, OUT c );
          Strings.FromCARD32W( c, 16, OUT Literal );
          G^.OutS( L'0x' );
          G^.OutS( Literal );
        END;
      ELSIF Types.TFloat^.Compatible( cmOperation, T ) THEN
        G^.OutCS( r.S );
      ELSIF T^.Unwrap()^.TypeKind = tkEnumeration THEN
        G^.OutCS( r.S );
      ELSE
        OutStringLiteral( T, r.S );
      END;

    | enOperation, enClassOperator :

      IF r.N = enClassOperator THEN
        // fall down

      ELSIF Types.TString^.Compatible( cmOperation, T ) THEN // strings cannot be output as expression :-(
        // STRINGS
        Evaluate( EV, 0 );
        OutStringLiteral( T, EV.S );
        EV.S.Dispose();
        RETURN;

      ELSIF ( r.O = opEQ ) OR ( r.O = opNEQ ) THEN
      
        // START copy from EQUALS...
        (*
        IF Types.TBString^.Compatible( cmOperation, r.L^.T ) THEN
          G^.OutS( L'EQUALSB_( ' );
          r.L^.AnalyzeAndGenerateOAHigh( G, Types.TBCONSTOAString );
          r.L^.Generate( G, C + TGenerateControl{gcCharLiteralAsStringForOA} );
          G^.OutS( L", " );
          r.R^.AnalyzeAndGenerateOAHigh( G, Types.TBCONSTOAString );
          r.R^.Generate( G, C + TGenerateControl{gcCharLiteralAsStringForOA} );
          G^.OutSPRP();
        ELSIF Types.TWString^.Compatible( cmOperation, r.L^.T ) THEN
          G^.OutS( L'EQUALSW_( ' );
          r.L^.AnalyzeAndGenerateOAHigh( G, Types.TWCONSTOAString );
          r.L^.Generate( G, C + TGenerateControl{gcCharLiteralAsStringForOA} );
          G^.OutS( L", " );
          r.R^.AnalyzeAndGenerateOAHigh( G, Types.TWCONSTOAString );
          r.R^.Generate( G, C + TGenerateControl{gcCharLiteralAsStringForOA} );
          G^.OutSPRP();
        // END copy from EQUALS...

        ELS*)IF r.L^.T^.Unwrap()^.PrimitiveType = ptStructure THEN (*?*) // musi to byt? nestaci == ???
        // IF FALSE AND (r.L^.T^.Unwrap()^.PrimitiveType = ptStructure) THEN (*?*) // musi to byt? nestaci == ???
        DoEQUALSM:
          IF r.O = opEQ THEN
            G^.OutS( L'EQUALSM_( (BYTE*)&' );
          ELSE
            G^.OutS( L'!EQUALSM_( (BYTE*)&' );
          END;
            r.L^.Generate( G, C );
          G^.OutS( L', (BYTE*)&' );
            r.R^.Generate( G, C );
          G^.OutS( L', sizeof(' );
            r.L^.T^.Generate( G, gcsName );
          G^.OutS( L'))' );
          RETURN;
        ELSIF ( r.L^.T^.Unwrap()^.TypeKind = tkSet ) AND TPSet( r.L^.T^.Unwrap())^.IsLong() THEN
          GOTO DoEQUALSM;
        END; // CASE

      ELSIF ( r.O = opIN ) OR ( r.O = opNotIN ) THEN
        IF r.O = opNotIN THEN
          G^.OutS( L'!' );
        END;
        UT := r.R^.T^.Unwrap();
        // operator IN is always generated as function
        c := TPSet( UT )^.Count();
        IF c > 8 THEN
          G^.OutS( L'INA_(' );
        ELSIF c > 4 THEN
          G^.OutS( L'INL_(' );
        ELSE
          G^.OutS( L'INS_(' );
        END;
        r.R^.Generate( G, C );
        IF c > 8 THEN
          IF eoUnnamed IN UT^.Options THEN
            G^.OutS( L', ' );
          ELSE
            G^.OutS( L'._, ' );
          END;
          G^.OutN( CARDINAL( UT^.T^.LastOrdinal()));
          G^.OutS( L', (ORDINAL)' );
        ELSIF c > 4 THEN
          G^.OutS( L', 63, ' );
        ELSIF c > 2 THEN
          G^.OutS( L', 31, ' );
        ELSIF c > 1 THEN
          G^.OutS( L', 15, ' );
        ELSE
          G^.OutS( L', 7, ' );
        END;
        r.L^.Generate( G, C );
        G^.OutS( L')' );
        RETURN;
      
		ELSIF r.O = opIS THEN
			UT := r.R^.T^.Unwrap();
			IF UT^.SymbolKind = skClass THEN // check with class type
				G^.OutS( L'typeid( ' );
					r.L^.Generate( G, C );
				G^.OutS( L' ) == typeid( ' );
					r.R^.Generate( G, C );
				G^.OutS( L' )' );
			ELSE // check with class name
				G^.OutS( L'EQUALSB_( OA_MAX, typeid( ' );
					r.L^.Generate( G, C );
				G^.OutS( L' ).name(), OA_MAX, "class "' );
					r.R^.Generate( G, C + TGenerateControl{gcCharLiteralAsStringForOA} );
				G^.OutS( L' )' );
			END;
			RETURN;

      ELSIF ( r.O = opAddSET ) OR ( r.O = opSubSET ) OR ( r.O = opMultSET ) OR ( r.O = opDivSET ) THEN
        // long set operations are handled separately
        c := TPSet( r.L^.T^.Unwrap() )^.Count();
        IF c > 8 THEN
        
          CASE r.O OF
          | opAddSET : G^.OutS( L'(SDISJA_(' );
          | opSubSET : G^.OutS( L'(SDIFFA_(' );
          | opMultSET : G^.OutS( L'(SCONJA_(' );
          | opDivSET : G^.OutS( L'(SSYMDA_(' );
          END; // CASE  

          G^.OutN( c );
          G^.OutS( L', ' );
          
          r.SV^.Generate( G, gcsName );
          IF eoUnnamed IN r.SV^.T^.Unwrap()^.Options THEN
            G^.OutS( L', ' );
          ELSE
            G^.OutS( L'._, ' );
          END;
          
          r.L^.Generate( G, C );
          IF eoUnnamed IN r.L^.T^.Unwrap()^.Options THEN
            G^.OutS( L', ' );
          ELSE
            G^.OutS( L'._, ' );
          END;
          
          r.R^.Generate( G, C );
          IF eoUnnamed IN r.R^.T^.Unwrap()^.Options THEN
            G^.OutS( L'), ' );
          ELSE
            G^.OutS( L'._), ' );
          END;
          
          r.SV^.Generate( G, gcsName );
          G^.OutS( L')' );

          RETURN;
        END;  
      END;

      // left parenthesis
      IF r.L <> NIL THEN
        pf := ( r.L^.r.N = enOperation ) AND ( cppTOP[r.O] > cppTOP[r.L^.r.O] );
        IF pf THEN
          G^.OutLP();
        END;
        r.L^.Generate( G, C );
        IF pf THEN
          G^.OutRP();
        END;
        IF r.O <> opSubExpr THEN
          G^.OutSP();
        END;
      END;

      CASE r.O OF
      | opEQ:      G^.OutS( L'==' );
      | opNEQ:     G^.OutS( L'!=' );
      | opLT:      G^.OutS( L'<' );
      | opGT:      G^.OutS( L'>' );
      | opLTE:     G^.OutS( L'<=' );
      | opGTE:     G^.OutS( L'>=' );
      | opANDL:    G^.OutS( L'&&' );
      | opORL:     G^.OutS( L'||' );
      | opNotL:    G^.OutS( L'!' );
      | opANDB:    G^.OutS( L'&' );
      | opORB:     G^.OutS( L'|' );
      | opEORB:    G^.OutS( L'^' );
      | opNotB:    G^.OutS( L'~' );
      | opSgnM :   G^.OutS( L'-' );
      | opAdd :    G^.OutS( L'+' );
      | opSub :    G^.OutS( L'-' );
      | opMult :   G^.OutS( L'*' );
      | opDiv :    G^.OutS( L'/' );
      | opIDiv :   G^.OutS( L'/' );
      | opRem :    G^.OutS( L'%' );
      | opMod :    G^.OutS( L'%' );
      | opLShift : G^.OutS( L'<<' );
      | opRShift : G^.OutS( L'>>' );
      | opAddSET : G^.OutS( L'|' );
      | opSubSET : G^.OutS( L'&~' );
      | opMultSET :G^.OutS( L'&' );
      | opDivSET : G^.OutS( L'^' );
      END; // CASE O

      // right parenthesis
      IF r.R <> NIL THEN
        pf := ( r.R^.r.N = enOperation ) AND ( cppTOP[r.O] > cppTOP[r.R^.r.O] );
        IF r.O <> opSgnM THEN
          G^.OutSP();
        END;
        IF pf THEN
          G^.OutLP();
        END;
        r.R^.Generate( G, C );
        IF pf THEN
          G^.OutRP();
        END;
      END;

    END; // CASE N
  END Generate;

BEGIN
  T := Types.TUnknown;
END CENode;

//------------------------------------------------------------

CLASS IMPLEMENTATION CProcedureCall;

  VIRTUAL PROCEDURE GenHead( G : Generator.TPGenerator; C : TGenerateControl; VAR Context : CARDINAL ) : TGenerateUnitMode;
  VAR
    U : TPUnit;
  BEGIN
    IF NOT GetFirst( U ) THEN
      RETURN gumSimple;
    END;
    IF ( imCOM IN P^.IM ) AND ( P^.T <> Types.TUnknown ) THEN
      Context := 1; // will have normal and OUT parameters
    END;
    IF NOT U^.Childs.Empty THEN
      // fall down
    ELSIF Context = 1 THEN
      Context := 2; // will have only OUT parameter
      // fall down
    ELSIF ( P^.OI = NIL ) OR P^.OI^.NP^.Childs.Empty AND P^.OI^.NF^.Childs.Empty THEN
      G^.OutS( L'()' );
      RETURN gumSimple;
    END;
    G^.OutS( L'( ' );
    RETURN gumNoIndent;
  END GenHead;

  VIRTUAL PROCEDURE GenTail( G : Generator.TPGenerator; _C : TGenerateControl; Context : CARDINAL );
  VAR
    U : TPUnit;
  BEGIN
    IF Context = 1 THEN
      G^.OutS( L', OUT &' ); RVD^.Generate( G, _C ); // COM OUT/function value
    ELSIF Context = 2 THEN
      G^.OutS( L'OUT &' ); RVD^.Generate( G, _C ); // COM OUT/function value
    END;
    IF ( P^.OI <> NIL ) AND ( P^.OI^.UnitKind = ukNestedProcedureDecl ) THEN
      IF coParamsInFrame IN P^.Options THEN
        IF NOT P^.OI^.NF^.Empty THEN
          IF GetFirst( U ) AND NOT U^.Empty THEN
            G^.OutCmSP();
          END;
          IF C^.NI = NIL THEN
            P^.OI^.NF^.Generate( G, gcsPassNestedTop );
          ELSE
            P^.OI^.NF^.Generate( G, gcsPassNested );
          END;
        END;
      ELSE
        IF NOT P^.OI^.NP^.Empty THEN
          IF GetFirst( U ) AND NOT U^.Empty THEN
            G^.OutCmSP();
          END;
          IF C^.NI = NIL THEN
            P^.OI^.NP^.Generate( G, gcsPassNestedTop );
          ELSE
            P^.OI^.NP^.Generate( G, gcsPassNested );
          END;
        END;
      END;
    END;
    G^.OutSPRP();
  END GenTail;

BEGIN
  UnitKind := ukProcedureCall;
  P := NIL;
  C := NIL;
  RVD := NIL;
END CProcedureCall;

//============================================================

CLASS IMPLEMENTATION CDesignator;
  
  PROCEDURE Evaluate( VAR V : CEValue; ItemIndex : INT64 );
  VAR
    E : TPExpression;
    I : INT64;
    n : ARRAY [0..127] OF WCHAR;
  BEGIN
    IF ItemIndex <> 0 THEN
      // pass down
    ELSIF Cache.T <> NIL THEN
      V.CopyFrom( Cache );
      RETURN;
    END;
  
    IF r.DK = dkId THEN
      IF ( r.Id <> NIL ) AND ( r.Id^.SymbolKind = skConstant ) THEN // constant expression
        E := TPConstant( TPConstant( r.Id )^.Unwrap())^.Expression();
        IF E = NIL THEN
          V.T := Types.TUnknown;
        ELSIF ( T^.Unwrap()^.PrimitiveType <> ptStructure ) OR ( T^.Unwrap()^.TypeKind = tkStringArray ) THEN
          E^.Evaluate( V, ItemIndex );
        ELSE
          V.T := T;
          V.E := E;
        END;
      ELSE
        V.T := Types.TUnknown;
      END;

    ELSIF r.DK = dkType THEN // typed container
      r.TC^.Evaluate( V, ItemIndex );

    ELSIF r.DK = dkEmbeddedProcedure THEN
      CASE r.EP OF
      | epORD :
        TPExpression( r.U1 )^.Evaluate( V, 0 ); // expression
        V.I := V.ToInteger();
        V.T := T;
      | epMINo :
        V.I := TPType( r.U1 )^.FirstOrdinal();
        V.T := T;
      | epMAXo :
        V.I := TPType( r.U1 )^.LastOrdinal();
        V.T := T;
      | epEMIT :
        V.T := T;
        IF r.D1 = 1 THEN
          V.I := INT64( INTEGER( r.D2 ));
        ELSIF r.U1 <> NIL THEN
          CASE CARDINAL( r.D1 ) OF
          | 2 : V.S.Assign( TPModule( r.U1 )^.OD^.Name );
          | 3 : V.S.Assign( TPModule( r.U1 )^.OD^.FilePath );
          | 4 : V.S.Assign( TPSymbol( r.U1 )^.N );
          | 5 : V.S.Assign( TPSymbol( r.U1 )^.N );
          | 6, 7, 8 :
            IF r.D1 = 7 THEN
              V.S.AppendOA( L"-:" );
            ELSIF r.D1 = 8 THEN
              V.S.AppendOA( L"+:" );
            END;
            IF TPSymbol( r.U1 )^.OfSymbol^.SymbolKind = skClass THEN
              TPSymbol( r.U1 )^.OfSymbol^.GetN( gcsNameNested, TRUE, REF V.S );
              V.S.AppendOA( L"." );
              TPSymbol( r.U1 )^.GetN( gcsName, TRUE, REF V.S );
            ELSE
              TPSymbol( r.U1 )^.GetN( gcsNameNested, TRUE, REF V.S );
            END;
            IF r.D1 > 6 THEN
              V.S.AppendOA( L":" );
              Strings.FromCARD32W( CARDINAL( r.D2 ), 10, OUT n );
              V.S.AppendOA( n );
            END;
          END; // CASE
        ELSIF ( r.D1 = 6 ) OR ( r.D1 = 7 ) THEN
          IF r.D1 = 7 THEN
            V.S.FromOA( L"-:unknown:" );
          ELSE
            V.S.FromOA( L"+:unknown:" );
          END;
          Strings.FromCARD32W( CARDINAL( r.D2 ), 10, OUT n );
          V.S.AppendOA( n );
        ELSIF r.D1 < 12 THEN // library
          IF Project.GetComponentName( n, FALSE ) THEN
            V.S.AppendOA( n );
          ELSE
            V.S.AppendOA( L"<unknown>" );
          END;
          IF r.D1 = 10 THEN
            V.S.AppendOA( L".dll" );
          ELSIF r.D1 = 11 THEN
            V.S.AppendOA( L".exe" );
          END;
        ELSE
          V.S.FromOA( L"unknown" );
        END; // IF
      | epSIZE :
        V.T := T;
        V.I := INT64( TPDesignator( r.U1 )^.T^.OccupiedMemory());
      ELSE
        ASSERT( FALSE );
      END; // CASE
      
    ELSIF r.DK <> dkOperator THEN
      ASSERT( FALSE );

    ELSIF r.O = doIndexing THEN
      r.Idx^.Evaluate( V, 0 );
      I := TPArray( L^.T^.Unwrap())^.FirstIndex() + V.ToInteger();
      L^.Evaluate( V, 0 );
      V.E^.Evaluate( V, I );
      // ItemIndex := -1; // deny caching

    ELSIF r.O = doSelecting THEN
      L^.Evaluate( V, 0 );
      V.E^.Evaluate( V, r.FIdx );
      // ItemIndex := -1; // deny caching
    
    ELSE
      ASSERT( FALSE );
    END; // IF

    IF ItemIndex = 0 THEN
      Cache.CopyFrom( V );
    END;
  END Evaluate;

  VIRTUAL PROCEDURE GenHead( G : Generator.TPGenerator; C : TGenerateControl; VAR Context : CARDINAL ) : TGenerateUnitMode;
  VAR
    Cn : TGenerateControl;
    CI : TCastInfo;
    FT, LT : TPType;
    i : INTEGER;
    n : ARRAY [0..16] OF WCHAR;
    R : CARDINAL;
    V : CEValue;
    b : BOOLEAN;
    OAFlag : BOOLEAN := FALSE;
    FieldOfTypeFlag : BOOLEAN := FALSE;

    PROCEDURE LeakInfo( Push : BOOLEAN; Line : CARDINAL; SeparateLine : BOOLEAN );
    BEGIN
      IF Push THEN
        G^.OutS( L'LEAKINFOPUSH_( ' );
        G^.OutN( Project.Current()^.OD^.Name.Length );
        G^.OutS( L', L"' );
        G^.OutCS( Project.Current()^.OD^.Name );
        G^.OutS( L'", ' );
        G^.OutN( Line );
        G^.OutS( L' )' );
        IF SeparateLine THEN
          G^.OutSC(); G^.EOL(); G^.Indent();
        END;
      ELSE
        IF SeparateLine THEN
          G^.OutSC(); G^.EOL(); G^.Indent();
        END;
        G^.OutS( L'LEAKINFOPOP_()' );
      END;  
    END LeakInfo;
    
  BEGIN
    IF UnitKind = ukWithDesignator THEN
      Context := 1;
      G^.Indent();
      r.WV^.Generate( G, gcsName );
      G^.OutS( L' = &' );
    END;

    Cn := C - TGenerateControl{gcLValue} + TGenerateControl{gcRValue};
    CASE r.DK OF
    | dkOperator :
      CASE r.O OF
      | doIndexing :
        L^.Generate( G, Cn );
        IF NOT L^.T^.IsFormal() THEN // not formal type -- use it directly for
          LT := L^.T;
        ELSIF L^.T^.IsOpenArray() THEN // open array, use it directly too, there must no be any _
          LT := L^.T;
          OAFlag := TRUE;
        ELSE // formal not open array, check for _ linked type
          LT := L^.T^.Unwrap();
        END;
        IF LT^.N.Empty OR ( eoUnnamed IN LT^.Options ) THEN
          // skip, there is no nested _
        ELSIF LT^.TypeKind <> tkStringArray THEN
          G^.OutS( L'._' );
        END;
        G^.OutS( L'[' );
          r.Idx^.Generate( G, Cn );
          IF OAFlag THEN
            // open array always starts with index = 0
          ELSE
            i := INTEGER( TPArray( LT^.Unwrap())^.FirstIndex());
            IF i <> 0 THEN
              Strings.FromINT32W( i, 10, OUT n );
              G^.OutS( L'-(' );
              G^.OutS( n );
              G^.OutRP();
            END;
          END;
        G^.OutS( L']' );

      | doIndexingOfClass, doIndexingOfSuperClass :
        IF L^.T^.IsFormal() AND ( TPFormalType( L^.T )^.TypeModifier = tmCONST ) THEN
          G^.OutS( L'((' );
          L^.T^.T^.Generate( G, gcsCast );
          // Types.TADDRESS^.CheckAndGenerateCast( G, L^.T^.T, TRUE, CI );
          G^.OutS( L'*)&' );
          L^.Generate( G, Cn );
          G^.OutS( L')->' );
        ELSE
          L^.Generate( G, Cn );
          IF r.O = doIndexingOfClass THEN
            G^.OutS( L'.' );
          ELSE
            G^.OutS( L'::' );
          END;
        END;

        r.DfI^.Generate( G, C + gcsNameSimple );
        G^.OutS( L'( ' );
        r.Idx^.Generate( G, Cn );
        IF gcLValue IN C THEN
          G^.OutS( L', ' );
        ELSIF imCOM IN r.DfI^.IM THEN
          G^.OutS( L', &' ); r.CD^.Generate( G, Cn ); G^.OutS( L' )' ); // obtaining COM indexer value
        ELSE
          G^.OutS( L' )' );
        END;
      | doSelecting, doSelectingOfSuperClass :
        IF ( L^.r.DK = dkOperator ) AND ( L^.r.O = doDereferencing ) THEN // AND ( L^.r.AO = NIL ) THEN variant without -> for addressing offset
        // ^ before . found
          IF L^.L^.r.DK = dkType THEN
            G^.OutLP();
          END;

          IF (( r.F^.SymbolKind = skProperty ) OR ( r.F^.SymbolKind = skProcedure )) AND
             L^.L^.T^.IsFormal() AND ( TPFormalType( L^.L^.T )^.TypeModifier = tmCONST ) THEN
            G^.OutS( L'((' );
            L^.L^.T^.T^.Generate( G, gcsCast );
            // Types.TADDRESS^.CheckAndGenerateCast( G, L^.T^.T, TRUE, CI );
            G^.OutS( L')' );
            L^.L^.Generate( G, Cn );
            G^.OutS( L')' );
          ELSE
            L^.L^.Generate( G, Cn );
          END;

          IF L^.L^.r.DK = dkType THEN
            G^.OutRP();
          END;
          IF L^.L^.T^.UnwrapToFirstType()^.TypeKind = tkOpaqueWholeLink THEN
            G^.OutS( L'->_.' );
          ELSE
            G^.OutS( L'->' );
          END;
          
        ELSIF L^.r.DK = dkOperator THEN // [], (), @[] found
          L^.Generate( G, Cn );
          IF r.O = doSelectingOfSuperClass THEN
            G^.OutS( L'::' );
          ELSE
            G^.OutS( L'.' );
          END;
        
        ELSIF ( L^.r.DK = dkType ) AND ( L^.r.TC = NIL ) THEN // selecting of type (class) which is possible only inside SIZE -- replace typename with macro
          FieldOfTypeFlag := TRUE;
          G^.OutS( L'FIELDOFTYPE_( ' );
          L^.Generate( G, Cn );
          G^.OutS( L', ' );

        ELSE
        // id found
          CASE L^.r.Id^.UnitKind OF
          | ukSimpleClassDef, ukClassClassDef, ukSuperWrapper :
            L^.Generate( G, Cn );
            G^.OutS( L'::' );
          | ukSelf :
            L^.Generate( G, Cn );
            G^.OutS( L'.' );
          ELSE IF (( r.F^.SymbolKind = skProperty ) OR ( r.F^.SymbolKind = skProcedure )) AND
                  L^.T^.IsFormal() AND ( TPFormalType( L^.T )^.TypeModifier = tmCONST ) THEN
            G^.OutS( L'((' );
            L^.T^.T^.Generate( G, gcsCast );
            // Types.TADDRESS^.CheckAndGenerateCast( G, L^.T^.T, TRUE, CI );
            G^.OutS( L'*)&' );
            L^.Generate( G, Cn );
            G^.OutS( L')->' );
          ELSE
            L^.Generate( G, Cn );
            G^.OutS( L'.' );
          END; END;
        END;
        r.F^.Generate( G, C + gcsNameSimple );
        IF FieldOfTypeFlag THEN
          G^.OutSPRP();
        // imCOM properties and functions are handled by call/OUT retval, so the usage must be generated properly
        ELSIF ( gcRValue IN C ) AND ( r.F^.SymbolKind = skProperty ) AND ( imCOM IN TPPropertyDef( r.F )^.IM ) THEN
          G^.OutS( L'( &' ); r.CD^.Generate( G, Cn ); G^.OutS( L' )' ); // obtaining property value
        END;

      | doDereferencing :
        Context := Context OR 2;
        G^.OutS( L'(*' );
        IF L^.T^.Unwrap() = Types.TADDRESS THEN
          G^.OutLP(); L^.T^.T^.Generate( G, gcsName ); G^.OutS( L"*)(" ); L^.Generate( G, Cn ); G^.OutRP();
        ELSE
          L^.Generate( G, Cn );
        END;
        RETURN gumNoIndent;

      | doAddressingOffset :
        G^.OutS( L"INCFA_( " );
          L^.T^.Generate( G, gcsName ); G^.OutS( L", " );
        L^.Generate( G, Cn );
           G^.OutS( L", " );
        r.AO^.Generate( G, Cn );
        G^.OutSPRP(); 

      | doCall :
        IF imCOM IN TPProcedure( L^.T )^.IM THEN // set COM assignment designator as last (retval) parameter
          r.P^.RVD := r.CD;
        END;
        L^.Generate( G, Cn );
        r.P^.Generate( G, C );
        
      | doCallRelease :
        L^.Generate( G, gcsName );
        G^.OutS( L"->Release()" );
      END;

    | dkId :
      IF r.Id^.T^.IsFormal() AND NOT r.Id^.T^.IsOpenArray() THEN
        CASE TPFormalType( r.Id^.T )^.TypeModifier OF
        | tmVAR, tmREF, tmOUT :
          Context := Context OR 2;
          G^.OutS( L'(*' );
        | tmCONST : // CONST T parameter moved to frame changes to T* parameter
          IF ( eoMovedToFrame IN r.Id^.Options ) AND ( r.Id^.T^.Unwrap()^.PrimitiveType = ptStructure ) THEN
            Context := Context OR 2;
            G^.OutS( L'(*' );
          END;
        END;
      END;
      IF r.W = NIL THEN
        CASE r.IdA OF
        | saDirect :
          IF eoMovedToFrame IN r.Id^.Options THEN
            G^.OutS( L'f_' );
            r.Id^.OfSymbol^.OutN( G, Cn );
            G^.OutS( L'.' );
          END;
        | saParentProcedureVariable :
          G^.OutS( L'f_' );
          r.GO^.OutN( G, Cn );
          G^.OutS( L'->' );
        | saParentObject :
          G^.OutS( L'c_' );
          r.GO^.OutN( G, Cn );
        | saParentObjectSymbol :
          G^.OutS( L'c_' );
          r.GO^.OutN( G, Cn );
          G^.OutS( L'->' );
        | saChildProcedureCall, saPeerProcedureCall :
          r.GO^.OutN( G, gcsNameNested );
          G^.OutS( L'_' );
        END; // CASE
      ELSE
        IF eoMovedToFrame IN r.W^.r.WV^.Options THEN
          G^.OutS( L'f_' );
          r.W^.r.WV^.OfSymbol^.OutN( G, C );
          G^.OutS( L'.' );
        END;
        r.W^.r.WV^.Generate( G, gcsName );
        LT := r.W^.r.WV^.T;
        IF LT^.Unwrap()^.TypeKind = tkReference THEN
          G^.OutS( L"->" );
        ELSIF NOT LT^.IsFormal() THEN
          G^.OutS( L"." );
        ELSE
          CASE TPFormalType( LT )^.TypeModifier OF
          | tmVAR, tmREF, tmOUT :
            G^.OutS( L"->" );
          ELSE
            IF ( eoMovedToFrame IN r.W^.r.WV^.Options ) AND ( LT^.Unwrap()^.PrimitiveType = ptStructure ) THEN
              G^.OutS( L"->" );
            ELSE
              G^.OutS( L"." );
            END;
          END; // CASE
        END; // IF
      END;
      IF r.IdA <> saParentObject THEN
        r.Id^.Generate( G, C + gcsName );
        // imCOM properties and functions are handled by call/OUT retval, so the usage must be generated properly
        IF ( gcRValue IN C ) AND ( r.Id^.SymbolKind = skProperty ) AND ( imCOM IN TPPropertyDef( r.Id )^.IM ) THEN
          G^.OutS( L'( &' ); r.CD^.Generate( G, Cn ); G^.OutS( L' )' ); // obtaining property value
        END;
      END;

    | dkType :
      IF r.TC = NIL THEN
        T^.Generate( G, gcsName );
      ELSE
        r.TC^.Generate( G, C );
      END;
    | dkEmbeddedProcedure :
      CASE r.EP OF
      | epABS :
        G^.OutS( L'ABS_( ' );
        r.U1^.Generate( G, Cn );
        G^.OutSPRP();
      | epADR :
        IF TPDesignator( r.U1 )^.T^.Unwrap()^.TypeKind <> tkOpenArray THEN
          G^.OutS( L'&' );
        END;
        r.U1^.Generate( G, C );
      | epASSIGN :
        IF Types.TBString^.Compatible( cmOperation, TPDesignator( r.U1 )^.T ) THEN
          G^.OutS( L'ASSIGNB_( ' );
          TPDesignator( r.U1 )^.AnalyzeAndGenerateOAHigh( G, Types.TBOAString );
          r.U1^.Generate( G, Cn );
          G^.OutS( L", " );
          TPExpression( r.U2 )^.AnalyzeAndGenerateOAHigh( G, Types.TBCONSTOAString );
        ELSE
          G^.OutS( L'ASSIGNW_( ' );
          TPDesignator( r.U1 )^.AnalyzeAndGenerateOAHigh( G, Types.TWOAString );
          r.U1^.Generate( G, Cn );
          G^.OutS( L", " );
          TPExpression( r.U2 )^.AnalyzeAndGenerateOAHigh( G, Types.TWCONSTOAString );
        END;
        r.U2^.Generate( G, Cn + TGenerateControl{gcCharLiteralAsStringForOA} );
        G^.OutSPRP();
      | epASSIGNsz :
        IF Types.TBString^.Compatible( cmOperation, TPDesignator( r.U1 )^.T ) THEN
          G^.OutS( L'ASSIGNszB_( ' );
          TPDesignator( r.U1 )^.AnalyzeAndGenerateOAHigh( G, Types.TBOAString );
          r.U1^.Generate( G, Cn );
          G^.OutS( L", " );
          T^.CheckAndGenerateCast( G, Types.TpBCHAR, FALSE, CI );
        ELSE
          G^.OutS( L'ASSIGNszW_( ' );
          TPDesignator( r.U1 )^.AnalyzeAndGenerateOAHigh( G, Types.TWOAString );
          r.U1^.Generate( G, Cn );
          G^.OutS( L", " );
          T^.CheckAndGenerateCast( G, Types.TpWCHAR, FALSE, CI );
        END;
        r.U2^.Generate( G, Cn + TGenerateControl{gcCharLiteralAsStringForOA} );
        G^.OutSPRP();

      | epASSERT :
        IF eoAssertAllowed IN Options THEN
          G^.OutS( L'ASSERT_( ' );
            r.U1^.Generate( G, Cn );
          G^.OutSPRP();
        ELSE
          RETURN gumEmpty;
        END;

      | epCAP :
        IF Types.TBString^.Compatible( cmOperation, TPExpression( r.U1 )^.T ) THEN
          G^.OutS( L'CAPB_( ' );
          TPDesignator( r.U1 )^.AnalyzeAndGenerateOAHigh( G, Types.TBOAString );
        ELSE
          G^.OutS( L'CAPW_( ' );
          TPDesignator( r.U1 )^.AnalyzeAndGenerateOAHigh( G, Types.TWOAString );
        END;
        r.U1^.Generate( G, C );
        G^.OutSPRP();
      | epCAPFunc :
        IF Types.TBCHAR^.Compatible( cmOperation, T ) THEN
          G^.OutS( L'CAPFB_( ' );
        ELSE
          G^.OutS( L'CAPFW_( ' );
        END;
        r.U1^.Generate( G, Cn );
        G^.OutSPRP();
      // | epCHR :
      | epDEBUGGED :
        IF eoDebuggedAllowed IN Options THEN
          G^.OutS( L'DEBUGGED_()' );
        ELSE
          G^.OutS( L'false' );
        END;

      | epDECFunc :
        b := r.U2 <> NIL;
        IF TPExpression( r.U1 )^.T = Types.TOrdinalNumber THEN // literal OP literal
          G^.OutLP(); 
          r.U1^.Generate( G, Cn );
          IF b THEN
            G^.OutS( L' + ' );
            r.U2^.Generate( G, Cn );
          ELSE
            G^.OutS( L' + 1' );
          END;
          G^.OutRP(); 
        ELSE
          IF Types.TOrdinal^.Compatible( cmOperation, T ) THEN // number
            G^.OutS( L'DECFO_( ' );
          ELSE // address
            G^.OutS( L'DECFA_( ' );
          END;
          TPExpression( r.U1 )^.T^.Generate( G, gcsName );
          G^.OutS( L', ' );
          r.U1^.Generate( G, Cn );
          IF b THEN
            G^.OutS( L', ' );
            r.U2^.Generate( G, Cn );
          ELSE
            G^.OutS( L', 1' );
          END;
          G^.OutSPRP(); 
        END;

      | epDISPOSE, epFREE :
        IF eoLeakChecking IN Options THEN
          LeakInfo( TRUE, CARDINAL( r.D1 ), TRUE );
        END;
        IF T^.UnwrapToBaseType()^.TypeKind = tkClass THEN
          G^.OutS( L'delete ' ); 
          r.U1^.Generate( G, Cn );
          G^.OutS( L'; ' ); 
          r.U1^.Generate( G, Cn + TGenerateControl{gcLValue} );
          G^.OutS( L' = NIL' ); 
        ELSE
          Project.Current()^.MEnv.MIID[miidDeallocate]^.Generate( G, gcsName );
          G^.OutS( L'( ' );
          T^.CheckAndGenerateCast( G, Types.TREFADDRESS, FALSE, CI );
          r.U1^.Generate( G, Cn );
          G^.OutS( L' )' );
        END;
        IF eoLeakChecking IN Options THEN
          LeakInfo( FALSE, CARDINAL( r.D1 ), TRUE );
        END;
        
      | epEMIT :
        IF r.D1 = 1 THEN
          G^.OutN( CARDINAL( r.D2 ));
        ELSE
          Evaluate( V, 0 );
          IF Types.TWString^.Compatible( cmOperation, T ) THEN
            G^.OutS( L'L"' );
            G^.OutUNICODEEscapeCS( V.S, FALSE );
          ELSE
            G^.OutS( L'"' );
            G^.OutANSIEscapeCS( V.S, FALSE );
          END;
          G^.OutS( L'"' );
          V.S.Dispose();
        END;  

      | epEQUALS :
        // the code is copied to opEQ too...
        IF Types.TBString^.Compatible( cmOperation, TPExpression( r.U1 )^.T ) THEN
          G^.OutS( L'EQUALSB_( ' );
          TPExpression( r.U1 )^.AnalyzeAndGenerateOAHigh( G, Types.TBCONSTOAString );
          r.U1^.Generate( G, Cn + TGenerateControl{gcCharLiteralAsStringForOA} );
          G^.OutS( L", " );
          TPExpression( r.U2 )^.AnalyzeAndGenerateOAHigh( G, Types.TBCONSTOAString );
        ELSE
          G^.OutS( L'EQUALSW_( ' );
          TPExpression( r.U1 )^.AnalyzeAndGenerateOAHigh( G, Types.TWCONSTOAString );
          r.U1^.Generate( G, Cn + TGenerateControl{gcCharLiteralAsStringForOA} );
          G^.OutS( L", " );
          TPExpression( r.U2 )^.AnalyzeAndGenerateOAHigh( G, Types.TWCONSTOAString );
        END;
        r.U2^.Generate( G, Cn + TGenerateControl{gcCharLiteralAsStringForOA} );
        G^.OutSPRP();
      | epEVEN :
        G^.OutS( L'EVEN_( ' );
        r.U1^.Generate( G, Cn + TGenerateControl{gcCharLiteralAsStringForOA} );
        G^.OutSPRP();
      | epEXCL8..epEXCL32 :
        G^.OutS( L'EXCLS_( ' );
        r.U1^.Generate( G, Cn );
        CASE r.EP OF
        | epEXCL8 : G^.OutS( L', 7, ' );
        | epEXCL16 : G^.OutS( L', 15, ' );
        | epEXCL32 : G^.OutS( L', 31, ' );
        END;  
        r.U2^.Generate( G, Cn );
        G^.OutS( L' )' );
      | epEXCL64 :
        G^.OutS( L'EXCLL_( ' );
        r.U1^.Generate( G, C );
        G^.OutS( L', 63, ' );
        r.U2^.Generate( G, Cn );
        G^.OutS( L' )' );
      | epEXCLArray :
        G^.OutS( L'EXCLA_( ' );
        r.U1^.Generate( G, C );
        LT := TPExpression( r.U1 )^.T^.Unwrap();
        IF eoUnnamed IN LT^.Options THEN
          G^.OutS( L', ' );
        ELSE
          G^.OutS( L'._, ' );
        END;
        G^.OutN( CARDINAL( LT^.T^.LastOrdinal()));
        G^.OutS( L', (ORDINAL)(' );
        r.U2^.Generate( G, Cn );
        G^.OutS( L') )' );
      | epFIELDOFS :
        G^.OutS( L'FIELDOFS_( ' );
        r.U1^.Generate( G, gcsName );
        G^.OutS( L', ' );
        r.U2^.Generate( G, gcsName );
        G^.OutS( L' )' );
      | epFRAC :
        G^.OutS( L'FRAC_( ' );
        T^.Generate( G, gcsName );
        G^.OutS( L', ' );
        r.U1^.Generate( G, Cn );
        G^.OutSPRP();
      | epHIGH :
        LT := TPDesignator( r.U1 )^.T^.Unwrap();
        IF TPDesignator( r.U1 )^.T^.IsOpenArray() OR LT^.IsOpenArray() THEN
          IF TPDesignator( r.U1 )^.r.IdA = saParentProcedureVariable THEN // high is of parent procedure parameter
            G^.OutS( L'f_' );
            TPDesignator( r.U1 )^.r.GO^.OutN( G, C - TGenerateControl{gcLValue} + TGenerateControl{gcRValue} );
            G^.OutS( L'->' );
          END;
          TPDesignator( r.U1 )^.r.Id^.OutN( G, C );
          G^.OutS( L"_HIGH" );
        ELSIF LT^.TypeKind = tkArray THEN
          G^.OutN( TPArray( LT )^.High());
        ELSIF LT^.TypeKind = tkStringArray THEN
          G^.OutN( TPConstant( TPDesignator( r.U1 )^.r.Id )^.Expression()^.High());
        ELSE
          ASSERT( FALSE );
        END;
      | epINC, epDEC :
        IF Types.TOrdinalNumber^.Compatible( cmOperation, T ) THEN
          r.U1^.Generate( G, C );
        ELSIF Types.TADDRESS^.Compatible( cmOperation, T ) THEN
          G^.OutS( L"(*(PTR*)(&" );
          r.U1^.Generate( G, C );
          G^.OutS( L"))" );
        ELSE // non number ordinal
          R := CARDINAL( T^.OrdinalRange());
          IF R > MAX( CARD16 ) + 1 THEN
            G^.OutS( L"(*(ORD32*)(&" );
          ELSIF R > MAX( CARD8 ) + 1 THEN
            G^.OutS( L"(*(ORD16*)(&" );
          ELSE
            G^.OutS( L"(*(ORD8*)(&" );
          END;
          r.U1^.Generate( G, C );
          G^.OutS( L"))" );
        END;
        IF r.U2 <> NIL THEN
          IF r.EP = epDEC THEN
            G^.OutS( L' -= ' );
          ELSE
            G^.OutS( L' += ' );
          END;
          r.U2^.Generate( G, Cn );
        ELSIF r.EP = epDEC THEN
          G^.OutS( L'--' );
        ELSE
          G^.OutS( L'++' );
        END;
      | epINCFunc :
        b := r.U2 <> NIL;
        IF TPExpression( r.U1 )^.T = Types.TOrdinalNumber THEN // literal OP literal
          G^.OutLP(); 
          r.U1^.Generate( G, Cn );
          IF b THEN
            G^.OutS( L' + ' );
            r.U2^.Generate( G, Cn );
          ELSE
            G^.OutS( L' + 1' );
          END;
          G^.OutRP(); 
        ELSE
          IF Types.TOrdinal^.Compatible( cmOperation, T ) THEN // number
            G^.OutS( L'INCFO_( ' );
          ELSE
            G^.OutS( L'INCFA_( ' );
          END;
          TPExpression( r.U1 )^.T^.Generate( G, gcsName );
          G^.OutS( L', ' );
          r.U1^.Generate( G, Cn );
          IF b THEN
            G^.OutS( L', ' );
            r.U2^.Generate( G, Cn );
          ELSE
            G^.OutS( L', 1' );
          END;
          G^.OutSPRP(); 
        END;
      | epINCL8..epINCL32 :
        G^.OutS( L'INCLS_( ' );
        r.U1^.Generate( G, C );
        CASE r.EP OF
        | epINCL8 : G^.OutS( L', 7, ' );
        | epINCL16 : G^.OutS( L', 15, ' );
        | epINCL32 : G^.OutS( L', 31, ' );
        END;  
        r.U2^.Generate( G, Cn );
        G^.OutS( L' )' );
      | epINCL64 :
        G^.OutS( L'INCLL_( ' );
        r.U1^.Generate( G, C );
        G^.OutS( L', 63, ' );
        r.U2^.Generate( G, Cn );
        G^.OutS( L' )' );
      | epINCLArray :
        G^.OutS( L'INCLA_( ' );
        r.U1^.Generate( G, C );
        LT := TPExpression( r.U1 )^.T^.Unwrap();
        IF eoUnnamed IN LT^.Options THEN
          G^.OutS( L', ' );
        ELSE
          G^.OutS( L'._, ' );
        END;
        G^.OutN( CARDINAL( LT^.T^.LastOrdinal()));
        G^.OutS( L', (ORDINAL)(' );
        r.U2^.Generate( G, Cn );
        G^.OutS( L') )' );
      | epINSIDE :
        IF Types.TBString^.Compatible( cmOperation, TPExpression( r.U1 )^.T ) THEN
          G^.OutS( L'INSIDEB_( ' );
          TPExpression( r.U2 )^.AnalyzeAndGenerateOAHigh( G, Types.TBCONSTOAString );
        ELSE
          G^.OutS( L'INSIDEW_( ' );
          TPExpression( r.U2 )^.AnalyzeAndGenerateOAHigh( G, Types.TWCONSTOAString );
        END;
        r.U2^.Generate( G, Cn + TGenerateControl{gcCharLiteralAsStringForOA} );
        G^.OutS( L', (ORDINAL)' );
        r.U1^.Generate( G, Cn + TGenerateControl{gcCharLiteralAsStringForOA} );
        G^.OutSPRP();

      | epLeakINFOPush, epLeakINFOPop :
        IF eoLeakChecking IN Options THEN
          LeakInfo( r.EP = epLeakINFOPush, CARDINAL( r.D1 ), FALSE );
        ELSE
          RETURN gumEmpty;
        END;
      | epLeakALLOCATE :
        IF eoLeakChecking IN Options THEN
          G^.OutS( L'LEAKALLOCATE_( ' );
            r.U1^.Generate( G, Cn );
            G^.OutS( L', ' );
            r.U2^.Generate( G, Cn );
          G^.OutSPRP();
        ELSE
          RETURN gumEmpty;
        END;
      | epLeakREALLOCATE :
        IF eoLeakChecking IN Options THEN
          G^.OutS( L'LEAKREALLOCATE_( ' );
            r.U1^.Generate( G, Cn );
            G^.OutS( L', ' );
            r.U2^.Generate( G, Cn );
            G^.OutS( L', ' );
            TPUnit( r.D1 )^.Generate( G, Cn );
          G^.OutSPRP();
        ELSE
          RETURN gumEmpty;
        END;
      | epLeakDEALLOCATE :
        IF eoLeakChecking IN Options THEN
          G^.OutS( L'LEAKDEALLOCATE_( ' );
            r.U1^.Generate( G, Cn );
          G^.OutSPRP();
        ELSE
          RETURN gumEmpty;
        END;
      | epLeakSTART :
        IF eoLeakChecking IN Options THEN
          G^.OutS( L'LEAKSTART_();' );
        ELSE
          RETURN gumEmpty;
        END;
      | epLeakSTOP :
        IF eoLeakChecking IN Options THEN
          G^.OutS( L'LEAKSTOP_();' );
        ELSE
          RETURN gumEmpty;
        END;
      | epLeakRESET :
        IF eoLeakChecking IN Options THEN
          G^.OutS( L'LEAKRESET_();' );
        ELSE
          RETURN gumEmpty;
        END;

      | epLENGTH :
        IF Types.TBString^.Compatible( cmOperation, TPExpression( r.U1 )^.T ) THEN
          G^.OutS( L'LENGTHB_( ' );
          TPExpression( r.U1 )^.AnalyzeAndGenerateOAHigh( G, Types.TBCONSTOAString );
        ELSE
          G^.OutS( L'LENGTHW_( ' );
          TPExpression( r.U1 )^.AnalyzeAndGenerateOAHigh( G, Types.TWCONSTOAString );
        END;
        r.U1^.Generate( G, Cn + TGenerateControl{gcCharLiteralAsStringForOA} );
        G^.OutSPRP();
      | epLENGTHsz :
        IF Types.TBString^.Compatible( cmOperation, TPExpression( r.U1 )^.T ) THEN
          G^.OutS( L'LENGTHszB_( ' );
          T^.CheckAndGenerateCast( G, Types.TpBCHAR, FALSE, CI );
        ELSE
          G^.OutS( L'LENGTHszW_( ' );
          T^.CheckAndGenerateCast( G, Types.TpWCHAR, FALSE, CI );
        END;
        r.U1^.Generate( G, Cn + TGenerateControl{gcCharLiteralAsStringForOA} );
        G^.OutSPRP();
      | epLOW :
        IF Types.TBString^.Compatible( cmOperation, TPExpression( r.U1 )^.T ) THEN
          G^.OutS( L'LOWB_( ' );
          TPDesignator( r.U1 )^.AnalyzeAndGenerateOAHigh( G, Types.TBOAString );
        ELSE
          G^.OutS( L'LOWW_( ' );
          TPDesignator( r.U1 )^.AnalyzeAndGenerateOAHigh( G, Types.TWOAString );
        END;
        r.U1^.Generate( G, C );
        G^.OutSPRP();
      | epLOWFunc :
        IF Types.TBString^.Compatible( cmOperation, T ) THEN
          G^.OutS( L'LOWFB_( ' );
        ELSE
          G^.OutS( L'LOWFW_( ' );
        END;
        r.U1^.Generate( G, Cn );
        G^.OutSPRP();

      | epMAXf :
        IF TPType( r.U1 ) = Types.TREAL THEN
          G^.OutS( L"3.402823466e+38f" );
        ELSE
          G^.OutS( L"1.7976931348623158e+308" );
        END;
      | epMAXo :
        G^.OutNL( TPType( r.U1 )^.LastOrdinal());
      | epMAX2 :
        G^.OutS( L'MAX2_( ' );
        r.U1^.Generate( G, Cn );
        G^.OutS( L', ' );
        r.U2^.Generate( G, Cn );
        G^.OutS( L' )' );
      | epMINf :
        IF TPType( r.U1 ) = Types.TREAL THEN
          G^.OutS( L"-3.402823466e+38f" );
        ELSE
          G^.OutS( L"-1.7976931348623158e+308" );
        END;
      | epMINo :
        G^.OutNLI( TPType( r.U1 )^.FirstOrdinal());
      | epMIN2 :
        G^.OutS( L'MIN2_(' );
        r.U1^.Generate( G, Cn );
        G^.OutS( L', ' );
        r.U2^.Generate( G, Cn );
        G^.OutS( L')' );
      
      | epNEW :
        IF eoLeakChecking IN Options THEN
          LeakInfo( TRUE, CARDINAL( r.D1 ), TRUE );
        END;
        FT := T^.UnwrapToFirstType();
        LT := FT^.UnwrapToBaseType();
        IF LT^.TypeKind <> tkClass THEN
          Project.Current()^.MEnv.MIID[miidAllocate]^.Generate( G, gcsName );
          G^.OutS( L'(' ); 
            T^.CheckAndGenerateCast( G, Types.TREFADDRESS, FALSE, CI );
            r.U1^.Generate( G, Cn );
            G^.OutS( L', sizeof(' ); LT^.Generate( G, gcsName );
          G^.OutS( L'))' );
        ELSE
          G^.OutLP(); r.U1^.Generate( G, C + TGenerateControl{gcLValueType} );
          IF FT^.TypeKind = tkOpaqueWholeLink THEN
            G^.OutS( L' = ' ); Types.TADDRESS^.CheckAndGenerateCast( G, FT, FALSE, CI ); G^.OutS( L'new ' );
          ELSE
            G^.OutS( L' = new ' );
          END;
          LT^.Generate( G, gcsName ); G^.OutRP();
        END;
        IF eoLeakChecking IN Options THEN
          LeakInfo( FALSE, CARDINAL( r.D1 ), TRUE );
        END;
      | epNEWFunc :
        // IF eoLeakChecking IN Options THEN
        //   LeakInfo( TRUE, CARDINAL( r.D1 ), TRUE );
        // END;
        LT := T^.UnwrapToBaseType();
        IF LT^.TypeKind <> tkClass THEN
          G^.OutLP();
          Project.Current()^.MEnv.MIID[miidAllocate]^.Generate( G, gcsName );
          G^.OutS( L'(' ); 
            T^.CheckAndGenerateCast( G, Types.TREFADDRESS, FALSE, CI );
            r.U1^.Generate( G, gcsName );
            G^.OutS( L', sizeof(' ); LT^.Generate( G, gcsName );
          G^.OutS( L'))' );
          G^.OutS( L', ' ); r.U1^.Generate( G, gcsName ); G^.OutRP();
        ELSE
          G^.OutS( L'(new ' ); LT^.Generate( G, gcsName ); G^.OutRP(); 
        END;
        // IF eoLeakChecking IN Options THEN
        //   LeakInfo( FALSE, CARDINAL( r.D1 ), TRUE );
        // END;

      | epOA, epOAsz :
        // G^.OutLP();
        // TPVariable( r.D1 )^.Generate( G, gcsName );
        // IF Types.TWCHAR^.Compatible( cmOperation, TPExpression( r.U2 )^.T^.T^.Unwrap()^.T ) THEN
          // G^.OutS( L"? ((WCHAR*)" ); -- bad, casting can be complexier
          r.U2^.Generate( G, Cn );
          // G^.OutS( L') :L"")' );
        // ELSE
          // G^.OutS( L"? ((CHAR*)" ); -- bad, casting can be complexier
          // r.U2^.Generate( G, Cn );
          // G^.OutS( L') :"")' );
        // END;

      | epODD :
        G^.OutS( L'ODD_( ' );
        r.U1^.Generate( G, Cn );
        G^.OutSPRP();
      | epORD :
        G^.OutS( L'VAL_( ORDINAL, ' );
        r.U1^.Generate( G, Cn );
        G^.OutSPRP();
      | epSIZE :
        G^.OutS( L'sizeof(' );
        IF eoSizeAsTypes IN Options THEN
          TPDesignator( r.U1 )^.T^.Generate( G, gcsName );
        ELSE
          TPDesignator( r.U1 )^.Generate( G, Cn );
        END;
        G^.OutS( L')' );
      | epTRUNC :
        G^.OutS( L'TRUNC_( ' );
        r.U1^.Generate( G, Cn );
        G^.OutSPRP();
      | epVAL :
        G^.OutS( L'VAL_( ' );
        T^.Generate( G, gcsName );
        G^.OutS( L', ' );
        r.U1^.Generate( G, Cn );
        G^.OutSPRP();
			| epSWAP :
	      IF Types.TLONGWORD^.Compatible( cmOperation, T ) THEN
	        Types.TLONGWORD^.CheckAndGenerateCast( G, T, FALSE, CI );
	        G^.OutS( L'SWAPLW_( ' );
	        T^.CheckAndGenerateCast( G, Types.TLONGWORD, FALSE, CI );
	      ELSIF Types.TWORD^.Compatible( cmOperation, T ) THEN
	        Types.TWORD^.CheckAndGenerateCast( G, T, FALSE, CI );
	        G^.OutS( L'SWAPW_( ' );
	        T^.CheckAndGenerateCast( G, Types.TWORD, FALSE, CI );
	      ELSIF Types.TPTR^.Compatible( cmOperation, T ) THEN
	        Types.TPTR^.CheckAndGenerateCast( G, T, FALSE, CI );
	        G^.OutS( L'SWAPPTR_( ' );
	        T^.CheckAndGenerateCast( G, Types.TPTR, FALSE, CI );
	      ELSIF Types.TQUADWORD^.Compatible( cmOperation, T ) THEN
	        Types.TQUADWORD^.CheckAndGenerateCast( G, T, FALSE, CI );
	        G^.OutS( L'SWAPQW_( ' );
	        T^.CheckAndGenerateCast( G, Types.TQUADWORD, FALSE, CI );
				ELSIF Types.TBYTE^.Compatible( cmOperation, T ) THEN
	        Types.TBYTE^.CheckAndGenerateCast( G, T, FALSE, CI );
	        G^.OutS( L'SWAPB_( ' );
	        T^.CheckAndGenerateCast( G, Types.TBYTE, FALSE, CI );
	      END;
        r.U1^.Generate( G, Cn );
        G^.OutSPRP();
			| epSWAPBytes :
	      IF Types.TLONGWORD^.Compatible( cmOperation, T ) THEN
	        Types.TLONGWORD^.CheckAndGenerateCast( G, T, FALSE, CI );
	        G^.OutS( L'REVERSELWB_( ' );
	        T^.CheckAndGenerateCast( G, Types.TLONGWORD, FALSE, CI );
	      ELSIF Types.TWORD^.Compatible( cmOperation, T ) THEN
	        Types.TWORD^.CheckAndGenerateCast( G, T, FALSE, CI );
	        G^.OutS( L'REVERSEWB_( ' );
	        T^.CheckAndGenerateCast( G, Types.TWORD, FALSE, CI );
	      ELSIF Types.TPTR^.Compatible( cmOperation, T ) THEN
	        Types.TPTR^.CheckAndGenerateCast( G, T, FALSE, CI );
	        G^.OutS( L'REVERSEPTRB_( ' );
	        T^.CheckAndGenerateCast( G, Types.TPTR, FALSE, CI );
	      ELSIF Types.TQUADWORD^.Compatible( cmOperation, T ) THEN
	        Types.TQUADWORD^.CheckAndGenerateCast( G, T, FALSE, CI );
	        G^.OutS( L'REVERSEQWB_( ' );
	        T^.CheckAndGenerateCast( G, Types.TQUADWORD, FALSE, CI );
				ELSIF Types.TBYTE^.Compatible( cmOperation, T ) THEN
	        Types.TBYTE^.CheckAndGenerateCast( G, T, FALSE, CI );
	        G^.OutS( L'REVERSEBB_( ' );
	        T^.CheckAndGenerateCast( G, Types.TBYTE, FALSE, CI );
	      END;
        r.U1^.Generate( G, Cn );
        G^.OutSPRP();
      | epLOBYTE :
        G^.OutS( L'LOBYTE_( (WORD)' );
        r.U1^.Generate( G, Cn );
        G^.OutSPRP();
      | epHIBYTE :
        G^.OutS( L'HIBYTE_( (WORD)' );
        r.U1^.Generate( G, Cn );
        G^.OutSPRP();
      | epLOWORD :
        G^.OutS( L'LOWORD_( (LONGWORD)' );
        r.U1^.Generate( G, Cn );
        G^.OutSPRP();
      | epHIWORD :
        G^.OutS( L'HIWORD_( (LONGWORD)' );
        r.U1^.Generate( G, Cn );
        G^.OutSPRP();
      | epLOLONGWORD :
        G^.OutS( L'LOLONGWORD_( (QUADWORD)' );
        r.U1^.Generate( G, Cn );
        G^.OutSPRP();
      | epHILONGWORD :
        G^.OutS( L'HILONGWORD_( (QUADWORD)' );
        r.U1^.Generate( G, Cn );
        G^.OutSPRP();
      END; // CASE r.EK
    END; // CASE r.DK

    IF Context = 0 THEN
      RETURN gumSimple;
    ELSE
      RETURN gumNoIndent;
    END;
  END GenHead;

  VIRTUAL PROCEDURE GenTail( G : Generator.TPGenerator; C : TGenerateControl; Context : CARDINAL );
  BEGIN
    IF Context AND 2 <> 0 THEN
      G^.OutS( L')' );
      IF ( L <> NIL ) AND ( L^.T^.UnwrapToFirstType()^.TypeKind = tkOpaqueWholeLink ) THEN
        G^.OutS( L'._' );
      END;
    END;
    IF Context AND 1 <> 0 THEN
      G^.OutSC();
      G^.OutS( L" // WITH" );
      G^.EOL();
    END;
  END GenTail;

	PROCEDURE AnalyzeAndGenerateOAHigh( G : Generator.TPGenerator; TargetT : TPType );

		PROCEDURE RecomputeHighTail( SourceBase, TargetBase : TPType );
		BEGIN
			G^.OutS( L'*' );
			G^.OutS( L"sizeof(" ); SourceBase^.Generate( G, gcsName );
			G^.OutS( L")/" );
			G^.OutS( L"sizeof(" ); TargetBase^.Generate( G, gcsName );
			G^.OutS( L")-1" );
		END RecomputeHighTail;

	VAR
		LT : TPType := T^.Unwrap();
		LTb : TPType := LT^.T^.Unwrap(); // base
		PT : TPType := TargetT^.Unwrap();
		PTb : TPType := PT^.T^.Unwrap(); // base
		CastFlag : BOOLEAN;
		OAConstructorFlag : BOOLEAN;
		OASizeFlag : BOOLEAN := coOASize IN TargetT^.Options;
		RefFlag : BOOLEAN;
		SameBase : BOOLEAN := ( LTb = PTb ) OR ( LTb^.OccupiedMemory() = PTb^.OccupiedMemory() );
	BEGIN
		IF LT^.TypeKind = tkOpenArray THEN
			OAConstructorFlag := ( r.DK = dkEmbeddedProcedure ) AND (( r.EP = epOA ) OR ( r.EP = epOAsz ));
			IF OASizeFlag THEN
				IF NOT OAConstructorFlag THEN
					IF r.IdA = saParentProcedureVariable THEN // high is of parent procedure parameter
						G^.OutS( L'f_' );
						r.GO^.OutN( G, gcsName );
						G^.OutS( L'->' );
					END;
					IF SameBase THEN
						r.Id^.OutN( G, gcsName ); G^.OutS( L"_HIGH" );
					ELSE
						G^.OutLP(); r.Id^.OutN( G, gcsName ); G^.OutS( L"_HIGH+1)" );
						RecomputeHighTail( LTb, PTb );
					END;
				ELSIF r.EP = epOA THEN // string open array constructor
					r.U1^.Generate( G, gcsDefault );
				ELSE // sz string open array constructor
					G^.OutS( L"OA_MAX" );
				END;
			END;
			RefFlag := FALSE;
			CastFlag := OAConstructorFlag OR // CastFlag cannot be automatical, CPP does not allow passing "char(*)[xxx]" to "char*", see same note above
							//..
							NOT PTb^.Compatible( cmAssign, LTb ) OR // normal cast
							//..
							NOT Types.TStorage^.Compatible( cmOperation, LT^.T ) AND
							Types.TStorage^.Compatible( cmOperation, PT^.T ) OR // e.g. cast of INT8 to BYTE, M2 specialty
							//..
							TargetT^.IsFormal() AND // passing const to not const looses qualifiers...
							( TPFormalType( TargetT )^.TypeModifier <> tmCONST ) AND ( TPFormalType( T )^.TypeModifier = tmCONST );

		ELSIF LT^.TypeKind = tkArray THEN
			IF OASizeFlag THEN
				IF SameBase THEN
					G^.OutN( TPArray( LT )^.High());
				ELSE
					G^.OutN( TPArray( LT )^.High()+1 );
					RecomputeHighTail( LTb, PTb );
				END;
			END;
			RefFlag := TRUE;
			// CastFlag cannot be automatical, CPP does not allow passing "char(*)[xxx]" to "char*", see same note above
			CastFlag := TRUE;

		ELSE
			IF NOT OASizeFlag THEN
				// pass down
			ELSIF PT^.T^.Compatible( cmAssign, LT ) THEN
				G^.OutS( L"0" );
			ELSE
				G^.OutS( L"sizeof(" ); LT^.Generate( G, gcsName );
				G^.OutS( L")/" );
				G^.OutS( L"sizeof(" ); PT^.T^.Generate( G, gcsName );
				G^.OutS( L")-1" );
			END;
			RefFlag := TRUE;
			CastFlag := NOT PTb^.Compatible( cmAssign, LT ) OR// normal cast
							NOT Types.TStorage^.Compatible( cmOperation, LT ) AND
							Types.TStorage^.Compatible( cmOperation, PT^.T ); // e.g. cast of INT8 to BYTE, M2 specialty
		END;
		IF OASizeFlag THEN
			G^.OutCmSP();
		END;
		IF CastFlag THEN
			G^.OutLP(); TargetT^.Generate( G, gcsCast ); G^.OutAST(); G^.OutRP();
		END;
		IF RefFlag THEN
			G^.OutS( L'&' );
		END;
	END AnalyzeAndGenerateOAHigh;

  PROCEDURE MarkAsInitializedAndCheckRO( c : TPModule; TopLevel, LValueFlag : BOOLEAN );
  BEGIN
    CASE r.DK OF
    | dkOperator :
      IF ( r.O = doSelecting ) OR ( r.O = doSelectingOfSuperClass ) THEN
        L^.MarkAsInitializedAndCheckRO( c, FALSE, LValueFlag );
        IF r.F <> NIL THEN
          r.F^.Options := r.F^.Options + TEnvironmentOptions{eoInitialized} + TEnvironmentOptions{eoClassInitialized} * Project.Current()^.Options;
          IF TopLevel THEN
            IF LValueFlag THEN
              c^.CheckReadonly( r.F );
            ELSE
              c^.CheckWriteonly( r.F );
            END;
          END;
        END;
      ELSIF r.O = doIndexing THEN
        L^.MarkAsInitializedAndCheckRO( c, FALSE, LValueFlag );
      END;
    | dkId :
      r.Id^.Options := r.Id^.Options + TEnvironmentOptions{eoInitialized} + TEnvironmentOptions{eoClassInitialized} * Project.Current()^.Options;
      IF TopLevel THEN
        IF LValueFlag THEN
          c^.CheckReadonly( r.Id );
        ELSE
          c^.CheckWriteonly( r.Id );
        END;
      END;
    | dkEmbeddedProcedure :
      IF r.EP = DOM.epADR THEN
        DOM.TPDesignator( r.U1 )^.MarkAsInitializedAndCheckRO( c, FALSE, LValueFlag );
      END;
    | dkType :
			IF r.TC <> NIL THEN
	      r.TC^.MarkAsInitializedAndCheckRO( c, FALSE, LValueFlag );
	    END;
    END; // CASE
  END MarkAsInitializedAndCheckRO;

BEGIN
  UnitKind := ukDesignator;
  T := Types.TUnknown;
  L := NIL;
  Storage.Fill( ADR( r ), SIZE( r ), 0 );
  VI := TValueInfo{};
END CDesignator;

//------------------------------------------------------------

CLASS IMPLEMENTATION CTypedContainer;

  PROCEDURE Evaluate( VAR V : CEValue; ItemIndex : INT64 );
  VAR
    E, nextE : TPExpression;
    LV : CEValue;
    U : TPUnit;
    s : BITSET64;
    b : BOOLEAN;
  BEGIN
    IF ItemIndex <> 0 THEN
      // fall down
    ELSIF Cache.T <> NIL THEN
      V.CopyFrom( Cache );
      RETURN;
    END;
  
    IF Cast THEN
      ASSERT( ItemIndex = 0 );
      IF ( T^.Unwrap()^.TypeKind <> tkPrimitive ) OR NOT GetFirst( U ) OR ( U^.UnitKind <> ukExpression ) THEN
        ASSERT( FALSE );
        RETURN;
      END;

      V.T := T;
      TPExpression( U )^.Evaluate( LV, 0 );
      IF Types.TBOOLEAN^.Compatible( cmOperation, T ) THEN
        IF Types.TBOOLEAN^.Compatible( cmOperation, LV.T ) THEN
          V.B := LV.B;
        ELSIF Types.TOrdinalNumber^.Compatible( cmOperation, LV.T ) THEN
          V.B := LV.I <> 0;
        ELSIF Types.TFloat^.Compatible( cmOperation, LV.T ) THEN
          V.B := LV.R <> 0.0;
        ELSIF Types.TString^.Compatible( cmOperation, LV.T ) THEN
          IF LV.T^.TypeKind = tkArray THEN
            V.B := LV.S.EqualsOA( L'true' );
          ELSE
            V.B := LV.S[0] = WCHAR( 1 );
          END;
          LV.S.Dispose();
        ELSE
          ASSERT( FALSE );
        END;
        
      ELSIF Types.TOrdinalNumber^.Compatible( cmOperation, T ) THEN
        IF Types.TBOOLEAN^.Compatible( cmOperation, LV.T ) THEN
          V.I := INT64( LV.B );
        ELSIF Types.TOrdinalNumber^.Compatible( cmOperation, LV.T ) THEN
          V.I := LV.I;
        ELSIF Types.TFloat^.Compatible( cmOperation, LV.T ) THEN
          V.I := INT64( LV.R );
        ELSIF Types.TString^.Compatible( cmOperation, LV.T ) THEN
          IF LV.T^.TypeKind = tkArray THEN
            TRY
               V.I := LV.S.ToINT64( 10 );
            CATCH : StringsO.CStringException DO
               V.I := 0;
            END;
          ELSE
            V.I := INT64( LV.S[0] );
          END;
          LV.S.Dispose();
        ELSE
          ASSERT( FALSE );
        END;

      ELSIF Types.TFloat^.Compatible( cmOperation, T ) THEN
        IF Types.TBOOLEAN^.Compatible( cmOperation, LV.T ) THEN
          V.R := LONGREAL( LV.B );
        ELSIF Types.TOrdinalNumber^.Compatible( cmOperation, LV.T ) THEN
          V.R := LONGREAL( LV.I );
        ELSIF Types.TFloat^.Compatible( cmOperation, LV.T ) THEN
          V.R := LV.R;
        ELSIF Types.TString^.Compatible( cmOperation, LV.T ) THEN
          IF LV.T^.TypeKind = tkArray THEN
            TRY
              V.R := LV.S.ToLONGREAL();
            CATCH e : StringsO.CStringException DO
              V.R := 0.0;
            END;
          ELSE
            V.R := LONGREAL( LV.S[0] );
          END;
          LV.S.Dispose();
        ELSE
          ASSERT( FALSE );
        END;

      ELSIF Types.TString^.Compatible( cmOperation, T ) THEN
        IF T^.TypeKind = tkArray THEN
          IF Types.TBOOLEAN^.Compatible( cmOperation, LV.T ) THEN
            IF LV.B THEN
              V.S.FromOA( L'TRUE' );
            ELSE
              V.S.FromOA( L'FALSE' );
            END;
          ELSIF Types.TOrdinalNumber^.Compatible( cmOperation, LV.T ) THEN
            V.S.FromINT64( LV.I, 10 );
          ELSIF Types.TFloat^.Compatible( cmOperation, LV.T ) THEN
            V.S.FromLONGREAL( LV.R, FALSE );
          ELSIF Types.TString^.Compatible( cmOperation, LV.T ) THEN
            V.S.Assign( LV.S );
            LV.S.Dispose();
          ELSE
            ASSERT( FALSE );
          END;
        ELSE
          IF Types.TBOOLEAN^.Compatible( cmOperation, LV.T ) THEN
            V.S[0] := WCHAR( LV.B );
          ELSIF Types.TOrdinalNumber^.Compatible( cmOperation, LV.T ) THEN
            V.S[0] := WCHAR( LV.I );
          ELSIF Types.TFloat^.Compatible( cmOperation, LV.T ) THEN
            V.S[0] := WCHAR( LV.R );
          ELSIF Types.TString^.Compatible( cmOperation, LV.T ) THEN
            V.S[0] := LV.S[0];
            LV.S.Dispose();
          ELSE
            ASSERT( FALSE );
          END;
        END;
      END;
      
    ELSIF Types.TSet^.Compatible( cmOperation, T ) THEN
      IF TPSet( T^.Unwrap())^.Count() <= 8 THEN
        s := {};
        b := GetFirst( E );
        WHILE b DO
          E^.Evaluate( V, 0 );
          INCL( s, V.ToInteger());
          b := GetNext( E );
        END;
        V.T := Types.TCARD32;
        V.I := INT64( s );
      ELSE
        ASSERT( FALSE );
      END;

    ELSIF T^.Unwrap()^.PrimitiveType = ptStructure THEN
      GetFirst( E );
      LOOP
        IF ItemIndex = 0 THEN
          EXIT;
        END;
        DEC( ItemIndex );
        IF GetNext( nextE ) THEN
          E := nextE;
        ELSE
          EXIT;
        END;
      END; // LOOP
      E^.Evaluate( V, 0 );
      ItemIndex := -1; // deny caching

    ELSE
      ASSERT( FALSE );
    END;

    IF ItemIndex = 0 THEN
      Cache.CopyFrom( V );
    END;
  END Evaluate;

  VIRTUAL PROCEDURE GenHead( G : Generator.TPGenerator; C : TGenerateControl; VAR Context : CARDINAL ) : TGenerateUnitMode;
  TYPE
    TPSA = POINTER TO ARRAY [0..0] OF BITSET8;
  VAR
    E : TPExpression;
    i, maxi : INTEGER := 0;
    LTI, LTO : TPType := Types.TUnknown;
    r : INTEGER;
    s : BITSET32;
    sa : TPSA;
    sl : BITSET64;
    U : TPUnit;
    V : CEValue;
    b : BOOLEAN;
  BEGIN
    IF gcLValueType IN C THEN
      // no casting needed for CPP
    ELSIF Cast THEN
      IF GetFirst( U ) AND ( U^.UnitKind = ukExpression ) THEN
        LTI := TPExpression( U )^.T^.Unwrap();
      END;
      LTO := T^.Unwrap();
      IF ( gcLValue IN C ) OR // passing casted parameter into VAR/OUT/REF
         ( LTO^.PrimitiveType = ptStructure ) OR ( LTI^.PrimitiveType = ptStructure ) THEN
        // struct->primitive, primitive->struct must by casted using reference, except assigning sets, this is solved specially
        IF Types.TSet^.Compatible( cmOperation, LTO ) AND ( LTI^.PrimitiveType <> ptStructure ) THEN // do nothing
					// @@STRUCT SET ASSIGN
          Context := 2;
        ELSE
          Context := 1;
          G^.OutS( L"(*(" ); T^.Generate( G, gcsCast ); G^.OutS( L"*)&(" );
        END;
      ELSE
        G^.OutLP(); T^.Generate( G, gcsCast ); G^.OutS( L")(" );
      END;
    ELSIF Types.TSet^.Compatible( cmOperation, T ) THEN
      r := TPSet( T^.Unwrap())^.Count();
      IF r <= 4 THEN
        s := {};
        b := GetFirst( E );
        WHILE b DO
          E^.Evaluate( V, 0 );
          INCL( s, V.ToInteger());
          b := GetNext( E );
        END;
        G^.OutNH( CARDINAL( s ));
      ELSIF r <= 8 THEN
        sl := {};
        b := GetFirst( E );
        WHILE b DO
          E^.Evaluate( V, 0 );
          INCL( sl, V.ToInteger());
          b := GetNext( E );
        END;
        G^.OutNLH( CARD64( sl ));
      ELSE
        G^.OutLB();
        ALLOCATE( sa, r );
        Storage.Fill( sa, r, 0 );
        b := GetFirst( E );
        WHILE b DO
          E^.Evaluate( V, 0 );
          i := INTEGER( V.ToInteger());
          maxi := MAX2( maxi, i );
          INCL( sa^[i>>3], i AND 7 );
          b := GetNext( E );
        END;
        FOR i := 0 TO maxi >> 3 DO
          G^.OutNH( CARDINAL( sa^[i] ));
          G^.OutS( L"," );
        END; // FOR
        DISPOSE( sa );
        G^.OutRB();
      END;
      RETURN gumSimple;
    ELSE
      // pity pity pity, shit C... G^.OutCS( T^.N );
      IF ( T^.Unwrap()^.TypeKind = tkArray ) AND NOT T^.N.Empty THEN // ( for inner struct must be generated
        G^.OutLB();
      END;
      G^.OutLB();
    END;
    RETURN gumNoIndent;
  END GenHead;

  VIRTUAL PROCEDURE GenSep( CONST BeforeU : TPUnit; G : Generator.TPGenerator; C : TGenerateControl );
  BEGIN
    G^.OutCmSP();
  END GenSep;

  VIRTUAL PROCEDURE GenTail( G : Generator.TPGenerator; C : TGenerateControl; Context : CARDINAL );
  BEGIN
    IF gcLValueType IN C THEN
      // no casting needed for CPP
    ELSIF NOT Cast THEN
      G^.OutRB();
      IF ( T^.Unwrap()^.TypeKind = tkArray ) AND NOT T^.N.Empty THEN // } for inner struct must be generated
        G^.OutRB();
      END;
    ELSIF Context = 1 THEN
      G^.OutS( L'))' );
    ELSIF Context = 2 THEN
      // do nothing
    ELSE
      G^.OutRP();
    END;
    RETURN;
  END GenTail;

  PROCEDURE IsLValue() : BOOLEAN;
  VAR
    U : TPUnit;
  BEGIN
    RETURN GetFirst( U ) AND
           (
             ( U^.UnitKind = ukExpression ) AND ( TPExpression( U )^.N^.r.N = enDesignator ) OR
             ( U^.UnitKind = ukTypedContainer ) AND TPTypedContainer( U )^.IsLValue()
           );
  END IsLValue;

  PROCEDURE MarkAsInitializedAndCheckRO( c : TPModule; TopLevel, LValueFlag : BOOLEAN );
  VAR
    U : TPUnit;
  BEGIN
    IF NOT GetFirst( U ) THEN
      RETURN;
    ELSIF ( U^.UnitKind = ukExpression ) AND ( TPExpression( U )^.N^.r.N = enDesignator ) THEN
      TPExpression( U )^.N^.r.V^.MarkAsInitializedAndCheckRO( c, TopLevel, LValueFlag );
    ELSIF U^.UnitKind = ukTypedContainer THEN
      TPTypedContainer( U )^.MarkAsInitializedAndCheckRO( c, TopLevel, LValueFlag );
    END;
  END MarkAsInitializedAndCheckRO;

  PROCEDURE GetDesignator( OUT D : TPDesignator ) : BOOLEAN;
  VAR
    U : TPUnit;
  BEGIN
    IF NOT GetFirst( U ) THEN
      RETURN FALSE;
    ELSIF U^.UnitKind = ukExpression THEN
      IF TPExpression( U )^.N^.r.N = enDesignator THEN
        D := TPExpression( U )^.N^.r.V;
        RETURN TRUE;
      END;
    ELSIF U^.UnitKind = ukTypedContainer THEN
      RETURN TPTypedContainer( U )^.GetDesignator( OUT D );
    END;
    RETURN FALSE;
  END GetDesignator;

  PROCEDURE SetDesignator( D : TPDesignator );
  VAR
    U : TPUnit;
  BEGIN
    IF NOT GetFirst( U ) THEN
      RETURN;
    ELSIF U^.UnitKind = ukExpression THEN
      IF TPExpression( U )^.N^.r.N = enDesignator THEN
        TPExpression( U )^.N^.r.V := D;
      END;
    ELSIF U^.UnitKind = ukTypedContainer THEN
      TPTypedContainer( U )^.SetDesignator( D );
    END;
  END SetDesignator;

BEGIN
  UnitKind := ukTypedContainer;
  T := NIL;
  Cast := FALSE;
END CTypedContainer;

//============================================================

CLASS IMPLEMENTATION CStatement;

  VIRTUAL PROCEDURE GenHead( G : Generator.TPGenerator; C : TGenerateControl; VAR Context : CARDINAL ) : TGenerateUnitMode;
  BEGIN
    IF Preceding.Empty THEN
      RETURN gumEmpty;
    ELSE
      RETURN Preceding.Generate( G, C );
    END;
  END GenHead;

  VIRTUAL PROCEDURE GenTail( G : Generator.TPGenerator; C : TGenerateControl; Context : CARDINAL );
  BEGIN
    SUPER.GenTail( G, C, Context );
    IF NOT Following.Empty THEN
      Following.Generate( G, C );
    END;
  END GenTail;

END CStatement;

//------------------------------------------------------------

CLASS IMPLEMENTATION CSAssignment;

  VIRTUAL PROCEDURE GenHead( G : Generator.TPGenerator; C : TGenerateControl; VAR Context : CARDINAL ) : TGenerateUnitMode;
  VAR
    DT : TPType;
    ProcFlag : BOOLEAN;
    WCHARFlag : BOOLEAN;
  BEGIN
    SUPER.GenHead( G, C, Context );
    DT := D^.T^.Unwrap();

    G^.Indent();
      CASE UnitKind OF
      | ukSAssignment :
        D^.Generate( G, gcsAssignment );
        G^.OutS( L" = " );
        E^.Generate( G, C );

      | ukSCall :
        D^.Generate( G, C );

      | ukSAssignmentByCall1 :
        D^.Generate( G, gcsAssignment );
        G^.OutS( L"( " );
        E^.Generate( G, C );
        G^.OutS( L" )" );

      | ukSAssignmentByCall2 :
        D^.Generate( G, gcsAssignment );
        E^.Generate( G, C );
        G^.OutS( L" )" );

      | ukSAssignmentByCOMCall :
        D^.Generate( G, gcsDesignator );

      // | ukSAssignmentByCOMFunctionCall :
        // D^.Generate( G, gcsAssignment ); // gcLValue controls generating doCall, using gcRValue is prohibited

      | ukSAssignmentStringByEmbeddedCall :
        ProcFlag := TRUE;
        IF Types.TTCHAR^.Compatible( cmOperation, E^.T ) AND ( DT^.TypeKind <> tkOpenArray ) THEN
          ProcFlag := FALSE;
        ELSIF Types.TBString^.Compatible( cmAssign, D^.T ) THEN
          WCHARFlag := FALSE;
          G^.OutS( L"ASSIGNB_( " );
          D^.AnalyzeAndGenerateOAHigh( G, Types.TBOAString );
        ELSIF Types.TWString^.Compatible( cmAssign, D^.T ) THEN
          WCHARFlag := TRUE;
          G^.OutS( L"ASSIGNW_( " );
          D^.AnalyzeAndGenerateOAHigh( G, Types.TWOAString );
        ELSE
          ASSERT( FALSE );
        END;

        IF ProcFlag THEN
          D^.Generate( G, gcsAssignment );
          G^.OutS( L", " );
          //..
          IF WCHARFlag THEN
            E^.AnalyzeAndGenerateOAHigh( G, Types.TWCONSTOAString );
          ELSE
            E^.AnalyzeAndGenerateOAHigh( G, Types.TBCONSTOAString );
          END;
          //..
          E^.Generate( G, C + TGenerateControl{gcCharLiteralAsStringForOA} );
          G^.OutSPRP();
        ELSE
          D^.Generate( G, gcsAssignment );
          IF eoUnnamed IN DT^.Options THEN
            G^.OutS( L"[0] = " );
          ELSE
            G^.OutS( L"._[0] = " );
          END;
          E^.Generate( G, C );
          IF TPArray( D^.T )^.High() > 0 THEN
            G^.OutS( L"; " );
            D^.Generate( G, gcsAssignment );
            IF eoUnnamed IN DT^.Options THEN
              G^.OutS( L"[1] = 0" );
            ELSE
              G^.OutS( L"._[1] = 0" );
            END;
          END;
        END;

			| ukSAssignmentSetByEmbeddedCall :
        G^.OutS( L"ASSIGNS_( " );
        D^.Generate( G, gcsAssignment );
        G^.OutS( L", " );
        E^.Generate( G, C );
        G^.OutS( L" )" );

      END;
      G^.OutSC();
    G^.EOL();

    IF NOT Following.Empty THEN
      Following.Generate( G, C );
    END;
    RETURN gumSimple;
  END GenHead;

BEGIN
  UnitKind := ukSAssignment;
  D := NIL;
  E := NIL;
  Preceding.UnitKind := ukForwardedStatements;
  Following.UnitKind := ukForwardedStatements;
END CSAssignment;

//------------------------------------------------------------

CLASS IMPLEMENTATION CSReturn;

  VIRTUAL PROCEDURE GenHead( G : Generator.TPGenerator; C : TGenerateControl; VAR Context : CARDINAL ) : TGenerateUnitMode;
  LABEL
    SimpleReturn;
  VAR
    E : DOM.TPExpression;
  BEGIN
    SUPER.GenHead( G, C, Context );
    CASE UnitKind OF
    | ukReturn :
    SimpleReturn:
      IF Childs.Empty THEN
        G^.LineS( L"return;" );
        RETURN gumSimple;
      ELSIF Following.Empty THEN
        G^.Indent();
        G^.OutS( L"return " );
      ELSE
        G^.LineS( L"{ // delay return to allow destroying of COM objects" ); G^.Enter(); GetFirst( E );
        G^.Indent(); E^.T^.Generate( G, gcsName ); G^.OutS( L" _LocalReturnValue = " );
      END;
      RETURN gumNoIndent;
    | ukReturnInCOM :
      IF Childs.Empty THEN
        RETURN gumSimple;
      ELSE
        G^.Indent();
        G^.OutS( L'*RetVal = ' );
        RETURN gumNoIndent;
      END;
    | ukReturnInCPPTry :
      G^.Indent();
      IF Childs.Empty THEN
        G^.OutS( L"_FinallyReturns = true;" ); G^.EOL();
        G^.Indent(); G^.OutS( L"goto " ); L^.OutN( G, C ); G^.OutSC();
        G^.EOL();
        RETURN gumSimple;
      ELSE
        G^.OutS( L'_ReturnResult = ' );
        RETURN gumNoIndent;
      END;
    END;
    RETURN gumEmpty;
  END GenHead;

  VIRTUAL PROCEDURE GenTail( G : Generator.TPGenerator; C : TGenerateControl; Context : CARDINAL );
  LABEL
    SimpleReturn;
  BEGIN
    G^.OutSC(); G^.EOL();
    IF NOT Following.Empty THEN
      Following.Generate( G, C );
    END;

    CASE UnitKind OF
    | ukReturn :
    SimpleReturn:
      IF NOT Following.Empty THEN
        G^.LineS( L"return _LocalReturnValue;" );
        G^.Leave(); G^.LineRB();
      END;
    | ukReturnInCOM :
      G^.LineS( L"return 0;" );
    | ukReturnInCPPTry :
      G^.LineS( L"_FinallyReturns = true;" );
      G^.Indent(); G^.OutS( L"goto " ); L^.OutN( G, C ); G^.OutSC(); G^.EOL();
    END;
  END GenTail;

BEGIN
  UnitKind := ukReturn;
  L := NIL;
END CSReturn;

//------------------------------------------------------------

CLASS IMPLEMENTATION CSLabel;

  VIRTUAL PROCEDURE GenHead( G : Generator.TPGenerator; C : TGenerateControl; VAR Context : CARDINAL ) : TGenerateUnitMode;
  BEGIN
    G^.Indent(); 
      G^.OutCS( L^.N );
      G^.OutS( L":;" );
    G^.EOL();
    RETURN gumSimple;
  END GenHead;

BEGIN
  L := NIL;
END CSLabel;

//------------------------------------------------------------

CLASS IMPLEMENTATION CSLoop;

  VIRTUAL PROCEDURE GenHead( G : Generator.TPGenerator; C : TGenerateControl; VAR Context : CARDINAL ) : TGenerateUnitMode;
  BEGIN
    SUPER.GenHead( G, C, Context );
    RETURN CUnit.GenHead( G, C, Context );
  END GenHead;

END CSLoop;

//------------------------------------------------------------

CLASS IMPLEMENTATION CSFor;

  VIRTUAL PROCEDURE GenHead( G : Generator.TPGenerator; C : TGenerateControl; VAR Context : CARDINAL ) : TGenerateUnitMode;
  VAR
    EV : CEValue;
    MinusSense : BOOLEAN;
  BEGIN
    IF NOT Preceding.Empty THEN
      Preceding.GenHead( G, C, Context );
    END;

    MinusSense := FALSE;
    IF SS <> NIL THEN
      SS^.Evaluate( EV, 0 );
      MinusSense := EV.ToInteger() < 0;
    END;

    G^.Indent();
      FVV^.Generate( G, gcsName );
      G^.OutS( L' = ' );
      FVE^.Generate( G, C );
    G^.OutSC();
    G^.EOL();

    G^.Indent();
    G^.OutS( L"for (" );
      CV^.Generate( G, gcsName );
      G^.OutS( L" = " );
      IV^.Generate( G, C );
      G^.OutS( L"; (ORDINAL)(" );
      CV^.Generate( G, gcsName );
      IF MinusSense THEN
        G^.OutS( L") >= (ORDINAL)(" );
      ELSE
        G^.OutS( L") <= (ORDINAL)(" );
      END;
      FVV^.Generate( G, gcsName );
      G^.OutS( L"); " );
      IF SS = NIL THEN
        IF CV^.T^.Unwrap()^.TypeKind = DOM.tkEnumeration THEN
          G^.OutLP();
            CV^.T^.OutQN( G, C ); G^.OutS( L")(*(ORDINAL*)(&" );
            CV^.Generate( G, gcsName );
          G^.OutS( L"))++) {" );
        ELSE
          CV^.Generate( G, gcsName );
          G^.OutS( L"++) {" );
        END;
      ELSE
        IF CV^.T^.Unwrap()^.TypeKind = DOM.tkEnumeration THEN
          CV^.Generate( G, gcsName ); G^.OutS( L" = (" );
            CV^.T^.OutQN( G, C ); G^.OutS( L")((ORDINAL)" ); CV^.Generate( G, gcsName );
            G^.OutS( L" + " );
            SS^.Generate( G, C );
            G^.OutS( L")) {" );
        ELSE
          CV^.Generate( G, gcsName );
          G^.OutS( L" += (" );
          SS^.Generate( G, C );
          G^.OutS( L")) {" );
        END;
      END;
    G^.EOL();
    RETURN gumIndent;
  END GenHead;

  VIRTUAL PROCEDURE GenTail( G : Generator.TPGenerator; C : TGenerateControl; Context : CARDINAL );
  BEGIN
    G^.LineRBS( L'FOR' );
    IF eoReferenced IN LE.Options THEN
      G^.Indent(); G^.OutCS( LE.N ); G^.OutS( L":;" ); G^.EOL();
    END;
    IF NOT Following.Empty THEN
      Following.Generate( G, C );
    END;
  END GenTail;

BEGIN
  UnitKind := ukSFor;
  CV := NIL;
  IV := NIL;
  FVV := NIL;
  FVE := NIL;
  SS := NIL;
END CSFor;

//------------------------------------------------------------

CLASS IMPLEMENTATION CSGoto;

  VIRTUAL PROCEDURE GenHead( G : Generator.TPGenerator; C : TGenerateControl; VAR Context : CARDINAL ) : TGenerateUnitMode;
  BEGIN
    G^.Indent();
      G^.OutS( L"goto " );
      G^.OutCS( L^.N );
      G^.OutSC();
    G^.EOL();
    RETURN gumSimple;
  END GenHead;

BEGIN
  L := NIL;
END CSGoto;

//------------------------------------------------------------

CLASS IMPLEMENTATION CSASM;

  VIRTUAL PROCEDURE GenHead( G : Generator.TPGenerator; C : TGenerateControl; VAR Context : CARDINAL ) : TGenerateUnitMode;
  VAR
    i : CARDINAL;
  BEGIN
    G^.LineS( L"__asm {" );
    IF NOT ASMBlock.Empty THEN
      // trim trailing blanks
      i := ASMBlock.Length;
      LOOP
        IF i = 0 THEN
          EXIT;
        ELSE  
          DEC( i );
        END;
        IF ASMBlock[i] <> L' ' THEN
          ASMBlock.Remove( i + 1, MAX( CARDINAL ));
          EXIT;
        END;  
      END; // LOOP
      // trim other blanks (*?*)
      G^.OutCS( ASMBlock );
    END;
    G^.LineS( L"}" );
    RETURN gumSimple;
  END GenHead;

BEGIN
END CSASM;

//============================================================

CLASS IMPLEMENTATION CCATCH;

  VIRTUAL READONLY PROPERTY Symbols GET : TPSymbols;
  BEGIN
    RETURN ADR( S );
  END Symbols;

BEGIN
   UnitKind := ukCatchBlock;
END CCATCH;

//============================================================

CLASS IMPLEMENTATION CSTRY;

	VIRTUAL PROCEDURE GenHead( G : Generator.TPGenerator; C : TGenerateControl; VAR Context : CARDINAL ) : TGenerateUnitMode;
	BEGIN
		IF Preceding.Empty THEN
			RETURN gumNoIndent;
		ELSE
			RETURN Preceding.Generate( G, C );
		END;
	END GenHead;

BEGIN
	UnitKind := ukSTry;
END CSTRY;

//============================================================

INITIALLY __I();
BEGIN
END __I;

END DOM.