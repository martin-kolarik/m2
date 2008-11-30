MODULE TDecodeURL;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   httptools,
   Languages,
   log,
   lists,
   scinit,
   StringsO,
   Sync,
   test,
   testimpl;
  
(*===========================================================================*)

TYPE
   TPTest = POINTER TO CTest;

(*---------------------------------------------------------------------------*)

CLASS CTest IMPLEMENTS test.ITest;
   PUBLIC VAR
      Host : test.TPHost := NIL;

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;

   PRIVATE PROCEDURE PlainPass( FormFlag : BOOLEAN ) : BOOLEAN;
   PRIVATE PROCEDURE EncPass( FormFlag : BOOLEAN ) : BOOLEAN;
END CTest;

(*---------------------------------------------------------------------------*)

VAR
   Test : CTest;

(*===========================================================================*)

CLASS IMPLEMENTATION CTest;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   VAR
      Failure : BOOLEAN;
   BEGIN
      SELF.Host := Host;
      scinit.Startup();

      (*==========*)
      
      Failure := NOT PlainPass( FALSE );
      Failure := NOT PlainPass( TRUE ) OR Failure;
      Failure := NOT EncPass( FALSE );
      Failure := NOT EncPass( TRUE ) OR Failure;

      (*==========*)

      scinit.Cleanup();
      IF Failure THEN
         RETURN test.trFailure;
      ELSE
         RETURN test.trSuccess;
      END;
   END Run;
   
(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE PlainPass( FormFlag : BOOLEAN ) : BOOLEAN;
   VAR
      Decoded : lists.CStringStringList;
      Failure1, Failure2 : BOOLEAN;
   BEGIN
      IF FormFlag THEN
         Host^.StartPhase( L"FRMenc, query: na+me1=val+ue1&na+me2=val+ue2&na+me3=val+ue3" );
      ELSE
         Host^.StartPhase( L"URLenc, query: na+me1=val+ue1&na+me2=val+ue2&na+me3=val+ue3" );
      END;
      
      Decoded.Dispose();
      httptools.DecodeURLEncoding( FormFlag, C"na+me1=val+ue1&na+me2=val+ue2&na+me3=val+ue3", OUT Decoded );
      Decoded.Reset();
      IF Decoded.MoveNext() THEN
         IF FormFlag THEN
            Failure1 := NOT Decoded.Current^.EqualsOA( L"na me1" );
            Failure2 := NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"val ue1" );
         ELSE
            Failure1 := NOT Decoded.Current^.EqualsOA( L"na+me1" );
            Failure2 := NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"val+ue1" );
         END;
      ELSE
         Failure1 := TRUE;
      END;
      IF Decoded.MoveNext() THEN
         IF FormFlag THEN
            Failure1 := Failure1 OR NOT Decoded.Current^.EqualsOA( L"na me2" );
            Failure2 := Failure2 OR NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"val ue2" );
         ELSE
            Failure1 := Failure1 OR NOT Decoded.Current^.EqualsOA( L"na+me2" );
            Failure2 := Failure2 OR NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"val+ue2" );
         END;
      ELSE
         Failure1 := TRUE;
      END;
      IF Decoded.MoveNext() THEN
         IF FormFlag THEN
            Failure1 := Failure1 OR NOT Decoded.Current^.EqualsOA( L"na me3" );
            Failure2 := Failure2 OR NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"val ue3" );
         ELSE
            Failure1 := Failure1 OR NOT Decoded.Current^.EqualsOA( L"na+me3" );
            Failure2 := Failure2 OR NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"val+ue3" );
         END;
      ELSE
         Failure1 := TRUE;
      END;

      IF Failure1 OR Failure2 THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      (*==========*)

      IF FormFlag THEN
         Host^.StartPhase( L"FRMenc, query: na+me1=val+ue1&na+me2=val+ue2&na+me3=" );
      ELSE
         Host^.StartPhase( L"URLenc, query: na+me1=val+ue1&na+me2=val+ue2&na+me3=" );
      END;
      
      Decoded.Dispose();
      httptools.DecodeURLEncoding( FormFlag, C"na+me1=val+ue1&na+me2=val+ue2&na+me3=", OUT Decoded );
      Decoded.Reset();
      IF Decoded.MoveNext() THEN
         IF FormFlag THEN
            Failure1 := NOT Decoded.Current^.EqualsOA( L"na me1" );
            Failure2 := NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"val ue1" );
         ELSE
            Failure1 := NOT Decoded.Current^.EqualsOA( L"na+me1" );
            Failure2 := NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"val+ue1" );
         END;
      ELSE
         Failure1 := TRUE;
      END;
      IF Decoded.MoveNext() THEN
         IF FormFlag THEN
            Failure1 := Failure1 OR NOT Decoded.Current^.EqualsOA( L"na me2" );
            Failure2 := Failure2 OR NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"val ue2" );
         ELSE
            Failure1 := Failure1 OR NOT Decoded.Current^.EqualsOA( L"na+me2" );
            Failure2 := Failure2 OR NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"val+ue2" );
         END;
      ELSE
         Failure1 := TRUE;
      END;
      IF Decoded.MoveNext() THEN
         IF FormFlag THEN
            Failure1 := Failure1 OR NOT Decoded.Current^.EqualsOA( L"na me3" );
            Failure2 := Failure2 OR NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"" );
         ELSE
            Failure1 := Failure1 OR NOT Decoded.Current^.EqualsOA( L"na+me3" );
            Failure2 := Failure2 OR NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"" );
         END;
      ELSE
         Failure1 := TRUE;
      END;

      IF Failure1 OR Failure2 THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      (*==========*)

      IF FormFlag THEN
         Host^.StartPhase( L"FRMenc, query: na+me1=val+ue1&na+me2=&na+me3=val+ue3" );
      ELSE
         Host^.StartPhase( L"URLenc, query: na+me1=val+ue1&na+me2=&na+me3=val+ue3" );
      END;
      
      Decoded.Dispose();
      httptools.DecodeURLEncoding( FormFlag, C"na+me1=val+ue1&na+me2=&na+me3=val+ue3", OUT Decoded );
      Decoded.Reset();
      IF Decoded.MoveNext() THEN
         IF FormFlag THEN
            Failure1 := NOT Decoded.Current^.EqualsOA( L"na me1" );
            Failure2 := NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"val ue1" );
         ELSE
            Failure1 := NOT Decoded.Current^.EqualsOA( L"na+me1" );
            Failure2 := NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"val+ue1" );
         END;
      ELSE
         Failure1 := TRUE;
      END;
      IF Decoded.MoveNext() THEN
         IF FormFlag THEN
            Failure1 := Failure1 OR NOT Decoded.Current^.EqualsOA( L"na me2" );
            Failure2 := Failure2 OR NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"" );
         ELSE
            Failure1 := Failure1 OR NOT Decoded.Current^.EqualsOA( L"na+me2" );
            Failure2 := Failure2 OR NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"" );
         END;
      ELSE
         Failure1 := TRUE;
      END;
      IF Decoded.MoveNext() THEN
         IF FormFlag THEN
            Failure1 := Failure1 OR NOT Decoded.Current^.EqualsOA( L"na me3" );
            Failure2 := Failure2 OR NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"val ue3" );
         ELSE
            Failure1 := Failure1 OR NOT Decoded.Current^.EqualsOA( L"na+me3" );
            Failure2 := Failure2 OR NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"val+ue3" );
         END;
      ELSE
         Failure1 := TRUE;
      END;

      IF Failure1 OR Failure2 THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      (*==========*)

      IF FormFlag THEN
         Host^.StartPhase( L"FRMenc, query: na+me1=val+ue1&na+me2=val+ue2&na+me3" );
      ELSE
         Host^.StartPhase( L"URLenc, query: na+me1=val+ue1&na+me2=val+ue2&na+me3" );
      END;
      
      Decoded.Dispose();
      httptools.DecodeURLEncoding( FormFlag, C"na+me1=val+ue1&na+me2=val+ue2&na+me3", OUT Decoded );
      Decoded.Reset();
      IF Decoded.MoveNext() THEN
         IF FormFlag THEN
            Failure1 := NOT Decoded.Current^.EqualsOA( L"na me1" );
            Failure2 := NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"val ue1" );
         ELSE
            Failure1 := NOT Decoded.Current^.EqualsOA( L"na+me1" );
            Failure2 := NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"val+ue1" );
         END;
      ELSE
         Failure1 := TRUE;
      END;
      IF Decoded.MoveNext() THEN
         IF FormFlag THEN
            Failure1 := Failure1 OR NOT Decoded.Current^.EqualsOA( L"na me2" );
            Failure2 := Failure2 OR NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"val ue2" );
         ELSE
            Failure1 := Failure1 OR NOT Decoded.Current^.EqualsOA( L"na+me2" );
            Failure2 := Failure2 OR NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"val+ue2" );
         END;
      ELSE
         Failure1 := TRUE;
      END;
      IF Decoded.MoveNext() THEN
         IF FormFlag THEN
            Failure1 := Failure1 OR NOT Decoded.Current^.EqualsOA( L"na me3" );
            Failure2 := Failure2 OR NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"" );
         ELSE
            Failure1 := Failure1 OR NOT Decoded.Current^.EqualsOA( L"na+me3" );
            Failure2 := Failure2 OR NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"" );
         END;
      ELSE
         Failure1 := TRUE;
      END;

      IF Failure1 OR Failure2 THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      (*==========*)

      IF FormFlag THEN
         Host^.StartPhase( L"FRMenc, query: na+me1=val+ue1&na+me2&na+me3=val+ue3" );
      ELSE
         Host^.StartPhase( L"URLenc, query: na+me1=val+ue1&na+me2&na+me3=val+ue3" );
      END;
      
      Decoded.Dispose();
      httptools.DecodeURLEncoding( FormFlag, C"na+me1=val+ue1&na+me2&na+me3=val+ue3", OUT Decoded );
      Decoded.Reset();
      IF Decoded.MoveNext() THEN
         IF FormFlag THEN
            Failure1 := NOT Decoded.Current^.EqualsOA( L"na me1" );
            Failure2 := NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"val ue1" );
         ELSE
            Failure1 := NOT Decoded.Current^.EqualsOA( L"na+me1" );
            Failure2 := NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"val+ue1" );
         END;
      ELSE
         Failure1 := TRUE;
      END;
      IF Decoded.MoveNext() THEN
         IF FormFlag THEN
            Failure1 := Failure1 OR NOT Decoded.Current^.EqualsOA( L"na me2" );
            Failure2 := Failure2 OR NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"" );
         ELSE
            Failure1 := Failure1 OR NOT Decoded.Current^.EqualsOA( L"na+me2" );
            Failure2 := Failure2 OR NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"" );
         END;
      ELSE
         Failure1 := TRUE;
      END;
      IF Decoded.MoveNext() THEN
         IF FormFlag THEN
            Failure1 := Failure1 OR NOT Decoded.Current^.EqualsOA( L"na me3" );
            Failure2 := Failure2 OR NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"val ue3" );
         ELSE
            Failure1 := Failure1 OR NOT Decoded.Current^.EqualsOA( L"na+me3" );
            Failure2 := Failure2 OR NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"val+ue3" );
         END;
      ELSE
         Failure1 := TRUE;
      END;

      IF Failure1 OR Failure2 THEN
         Host^.StopPhaseWithResult( test.trFailure );
         RETURN FALSE;
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
         RETURN TRUE;
      END;

   END PlainPass;

(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE EncPass( FormFlag : BOOLEAN ) : BOOLEAN;
   VAR
      Decoded : lists.CStringStringList;
      Failure1, Failure2 : BOOLEAN;
   BEGIN
      IF FormFlag THEN
         Host^.StartPhase( L"FRMenc, query: na+me1=va%20l+ue1&na+me2=va%FDl+ue2&na+me3=val+ue3" );
      ELSE
         Host^.StartPhase( L"URLenc, query: na+me1=va%20l+ue1&na+me2=va%FDl+ue2&na+me3=val+ue3" );
      END;
      
      Decoded.Dispose();
      httptools.DecodeURLEncoding( FormFlag, C"na+me1=va%20l+ue1&na+me2=va%FDl+ue2&na+me3=val+ue3", OUT Decoded );
      Decoded.Reset();
      IF Decoded.MoveNext() THEN
         IF FormFlag THEN
            Failure1 := NOT Decoded.Current^.EqualsOA( L"na me1" );
            Failure2 := NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"va l ue1" );
         ELSE
            Failure1 := NOT Decoded.Current^.EqualsOA( L"na+me1" );
            Failure2 := NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"va l+ue1" );
         END;
      ELSE
         Failure1 := TRUE;
      END;
      IF Decoded.MoveNext() THEN
         IF FormFlag THEN
            Failure1 := Failure1 OR NOT Decoded.Current^.EqualsOA( L"na me2" );
            Failure2 := Failure2 OR NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"vaýl ue2" );
         ELSE
            Failure1 := Failure1 OR NOT Decoded.Current^.EqualsOA( L"na+me2" );
            Failure2 := Failure2 OR NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"vaýl+ue2" );
         END;
      ELSE
         Failure1 := TRUE;
      END;
      IF Decoded.MoveNext() THEN
         IF FormFlag THEN
            Failure1 := Failure1 OR NOT Decoded.Current^.EqualsOA( L"na me3" );
            Failure2 := Failure2 OR NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"val ue3" );
         ELSE
            Failure1 := Failure1 OR NOT Decoded.Current^.EqualsOA( L"na+me3" );
            Failure2 := Failure2 OR NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"val+ue3" );
         END;
      ELSE
         Failure1 := TRUE;
      END;

      IF Failure1 OR Failure2 THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;
      
      (*==========*)

      IF FormFlag THEN
         Host^.StartPhase( L"FRMenc, query: na+me1=va%20l+ue1&na+&amp;me2=va%FDl+ue2&na+me&#38;3=val+ue3" );
      ELSE
         Host^.StartPhase( L"URLenc, query: na+me1=va%20l+ue1&na+&amp;me2=va%FDl+ue2&na+me&#38;3=val+ue3" );
      END;
      
      Decoded.Dispose();
      httptools.DecodeURLEncoding( FormFlag, C"na+me1=va%20l+ue1&na+&amp;me2=va%FDl+ue2&na+me&#38;3=val+ue3", OUT Decoded );
      Decoded.Reset();
      IF Decoded.MoveNext() THEN
         IF FormFlag THEN
            Failure1 := NOT Decoded.Current^.EqualsOA( L"na me1" );
            Failure2 := NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"va l ue1" );
         ELSE
            Failure1 := NOT Decoded.Current^.EqualsOA( L"na+me1" );
            Failure2 := NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"va l+ue1" );
         END;
      ELSE
         Failure1 := TRUE;
      END;
      IF Decoded.MoveNext() THEN
         IF FormFlag THEN
            Failure1 := Failure1 OR NOT Decoded.Current^.EqualsOA( L"na &me2" );
            Failure2 := Failure2 OR NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"vaýl ue2" );
         ELSE
            Failure1 := Failure1 OR NOT Decoded.Current^.EqualsOA( L"na+&me2" );
            Failure2 := Failure2 OR NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"vaýl+ue2" );
         END;
      ELSE
         Failure1 := TRUE;
      END;
      IF Decoded.MoveNext() THEN
         IF FormFlag THEN
            Failure1 := Failure1 OR NOT Decoded.Current^.EqualsOA( L"na me&3" );
            Failure2 := Failure2 OR NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"val ue3" );
         ELSE
            Failure1 := Failure1 OR NOT Decoded.Current^.EqualsOA( L"na+me&3" );
            Failure2 := Failure2 OR NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"val+ue3" );
         END;
      ELSE
         Failure1 := TRUE;
      END;

      IF Failure1 OR Failure2 THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;
      
      (*==========*)

      IF FormFlag THEN
         Host^.StartPhase( L"FRMenc, query: na+me1=va%20l+ue1&na+me2=va%FDl+ue2&na+me3=val+ue%3" );
      ELSE
         Host^.StartPhase( L"URLenc, query: na+me1=va%20l+ue1&na+me2=va%FDl+ue2&na+me3=val+ue%3" );
      END;
      
      Decoded.Dispose();
      httptools.DecodeURLEncoding( FormFlag, C"na+me1=va%20l+ue1&na+me2=va%FDl+ue2&na+me3=val+ue%3", OUT Decoded );
      Decoded.Reset();
      IF Decoded.MoveNext() THEN
         IF FormFlag THEN
            Failure1 := NOT Decoded.Current^.EqualsOA( L"na me1" );
            Failure2 := NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"va l ue1" );
         ELSE
            Failure1 := NOT Decoded.Current^.EqualsOA( L"na+me1" );
            Failure2 := NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"va l+ue1" );
         END;
      ELSE
         Failure1 := TRUE;
      END;
      IF Decoded.MoveNext() THEN
         IF FormFlag THEN
            Failure1 := Failure1 OR NOT Decoded.Current^.EqualsOA( L"na me2" );
            Failure2 := Failure2 OR NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"vaýl ue2" );
         ELSE
            Failure1 := Failure1 OR NOT Decoded.Current^.EqualsOA( L"na+me2" );
            Failure2 := Failure2 OR NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"vaýl+ue2" );
         END;
      ELSE
         Failure1 := TRUE;
      END;
      IF Decoded.MoveNext() THEN
         IF FormFlag THEN
            Failure1 := Failure1 OR NOT Decoded.Current^.EqualsOA( L"na me3" );
            Failure2 := Failure2 OR NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"val ue" ); // the input is errorneous
         ELSE
            Failure1 := Failure1 OR NOT Decoded.Current^.EqualsOA( L"na+me3" );
            Failure2 := Failure2 OR NOT StringsO.TPString( Decoded.CurrentData )^.EqualsOA( L"val+ue" ); // the input is errorneous
         END;
      ELSE
         Failure1 := TRUE;
      END;

      IF Failure1 OR Failure2 THEN
         Host^.StopPhaseWithResult( test.trFailure );
         RETURN FALSE;
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
         RETURN TRUE;
      END;

   END EncPass;

(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"DecodeURLEncoding", ADR( Test ));
END CTest;

(*===========================================================================*)

END TDecodeURL.
