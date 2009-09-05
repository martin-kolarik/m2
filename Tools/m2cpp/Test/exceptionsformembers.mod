MODULE ExceptionsForMembers;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
	Exceptions;
	
TYPE
   TR = RECORD
      I : INTEGER;
   END; // RECORD
   
   CLASS CEXC1( Exceptions.CException ); END CEXC1;
   CLASS IMPLEMENTATION CEXC1; END CEXC1;
	
   CLASS CEXC2( Exceptions.CException ); END CEXC2;
   CLASS IMPLEMENTATION CEXC2; END CEXC2;
	
   PROCEDURE TPlainProc();
   BEGIN
   END TPlainProc;

   PROCEDURE TProc() THROWS CEXC2;
   BEGIN
      THROW NEW( CEXC2 )^;
   END TProc;

   PROCEDURE TProcPar( par : INTEGER ) THROWS CEXC1;
   BEGIN
      RETURN;
   END TProcPar;

   PROCEDURE TPlainFunc() : INTEGER;
   BEGIN
      RETURN 0;
   END TPlainFunc;

   PROCEDURE TFunc() : INTEGER THROWS CEXC1;
   BEGIN
      RETURN 0;
   END TFunc;

   PROCEDURE TFuncPar( par : INTEGER ) : INTEGER THROWS CEXC1;
   BEGIN
      RETURN 0;
   END TFuncPar;

   PROCEDURE TFuncRecord() : TR THROWS CEXC1;
   BEGIN
      RETURN TR( 0 );
   END TFuncRecord;

   CLASS C;
      PROPERTY Property : INTEGER THROWS CEXC1;
      INDEX( Index : INTEGER ) : INTEGER THROWS CEXC1;
      PROCEDURE TMethodProc() THROWS CEXC1;
      PROCEDURE TMethodProcPar( Par : INTEGER ) THROWS CEXC1;
      PROCEDURE TMethodFunc() : INTEGER THROWS CEXC1;
      PROCEDURE TMethodFuncPar( Par : INTEGER ) : INTEGER THROWS CEXC1;
      // OPERATOR +( Par : INTEGER ) : INTEGER; // THROWS CEXC1; // not allowed for native exeptions
   END C;
  
   CLASS IMPLEMENTATION C;

      PROPERTY Property GET : INTEGER;
      BEGIN
         RETURN -1;
      END Property;

      PROPERTY Property SET( Value : INTEGER );
      BEGIN
      END Property;

      INDEX C GET( Index : INTEGER ) : INTEGER;
      BEGIN
         RETURN 0;
      END C;

      INDEX C SET( Index : INTEGER; Value : INTEGER );
      BEGIN
      END C;

      PROCEDURE TMethodProc();
      BEGIN
      END TMethodProc;

      PROCEDURE TMethodProcPar( Par : INTEGER );
      BEGIN
      END TMethodProcPar;

      PROCEDURE TMethodFunc() : INTEGER;
      BEGIN
         RETURN 1;
      END TMethodFunc;

      PROCEDURE TMethodFuncPar( Par : INTEGER ) : INTEGER;
      BEGIN
         RETURN 2;
      END TMethodFuncPar;

(*
      OPERATOR +( Par : INTEGER ) : INTEGER;
      BEGIN
         RETURN 3;
      END +;
*)      

   END C;
   
   PROCEDURE TestProc();
   VAR
      i : INTEGER;
      R : TR;
      V : C;
   BEGIN
      TRY
         TPlainProc();
         TProc();
         TProcPar( 10 );
         TPlainFunc();
         RETURN;
         TFunc();
         TFuncPar( 11 );
         i := TPlainFunc();
         i := TFuncPar( 12 );
         R := TFuncRecord();
      CATCH e : CEXC2 DO
         // THROW e; -- sem error
      CATCH e : CEXC1 DO
      CATCH UNHANDLED DO
      FINALLY
      END;
   END TestProc;

   PROCEDURE TestFunc() : INTEGER;
   VAR
      i : INTEGER;
      R : TR;
      V : C;
   BEGIN
      TRY
         TPlainProc();
         TProc();
         TProcPar( 10 );
         TPlainFunc();
         TFunc();
         TFuncPar( 11 );
         RETURN 0;
         i := TPlainFunc();
         i := TFuncPar( 12 );
         R := TFuncRecord();
      CATCH e : CEXC2 DO
         // THROW e; -- sem error
         RETURN 2;
      CATCH e : CEXC1 DO
         RETURN 3;
      CATCH UNHANDLED DO
         RETURN 4;
      FINALLY
      END;
      RETURN 5;
   END TestFunc;

   PROCEDURE TestFuncThrow() : INTEGER THROWS CEXC2;
   VAR
      i : INTEGER;
      R : TR;
      V : C;
   BEGIN
      TRY
         TPlainProc();
         TProc();
         THROW NEW( CEXC2 )^;
         TProcPar( 10 );
         TPlainFunc();
         TFunc();
         TFuncPar( 11 );
         RETURN 0;
         i := TPlainFunc();
         i := TFuncPar( 12 );
         R := TFuncRecord();
      CATCH e : CEXC2 DO
         THROW e;
         RETURN 2;
      CATCH e : CEXC1 DO
         RETURN 3;
      CATCH UNHANDLED DO
         RETURN 4;
      FINALLY
         THROW NEW( CEXC2 )^;
      END;
      RETURN 5;
   END TestFuncThrow;

END ExceptionsForMembers.