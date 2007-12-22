MODULE SlotAllocator;

IMPORT
  Exceptions,
  StorageO;

  #save, call( convention => cdecl )
  PROCEDURE wmain01() : INTEGER;
  #restore
  VAR
    A : ARRAY [0..99] OF ADDRESS;
    I : INTEGER;
    S : ARRAY [0..255] OF WCHAR;
    SA : StorageO.CSlotAllocator;
  BEGIN
    TRY
      SA.Init( 2000, 0 );

      FOR I := 0 TO 49 DO      
        SA.Allocate( OUT A[I], 25000 );
      END;
      FOR I := 0 TO 49 DO      
        SA.Deallocate( REF A[I] );
      END;
      FOR I := 0 TO 49 DO      
        SA.Allocate( OUT A[I], 2000 );
      END;
      FOR I := 0 TO 49 DO      
        SA.Deallocate( REF A[I] );
      END;
      FOR I := 0 TO 49 DO      
        SA.Allocate( OUT A[I], 2000 );
      END;
      FOR I := 0 TO 49 DO      
        SA.Deallocate( REF A[I] );
      END;

    CATCH EX1 : StorageO.CAllocatorException DO
      EX1.ToString( OUT S );
      RETURN -1;

    FINALLY
      I := I + 1;

    END;
  
    RETURN 0;
  END wmain01;

BEGIN
END SlotAllocator.