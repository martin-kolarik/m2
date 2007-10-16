MODULE MemoryBuffer;

IMPORT
  StorageO;

VAR
  MB1 : StorageO.CMemoryBuffer;
  MB2 : StorageO.CMemoryBuffer;

#save, call( entry_point => on, convention => cdecl )
PROCEDURE wmain();
#restore
CONST
  c1 = C'ABC';
  c2 = L'XYZ';
VAR
  b : BOOLEAN;
  c : CARDINAL;
BEGIN
  MB1.FromOA( c1, FALSE );
  MB1.FromOA( c1, TRUE );
  MB1.FromOA( c1, FALSE );
  
  MB2 := MB1;
  
  MB1.AppendOA( c2 );
  MB1.PrependOA( c2 );
  
  MB2.AppendOA( c1 );
  
  b := MB1.StartsWith( c1 );
  b := MB1.StartsWith( c2 );
  b := MB1.EndsWith( c1 );
  b := MB1.EndsWith( c2 );

  c := MB1.IndexOfOA( c1, 0 );
  c := MB1.IndexOfOA( c1, 6 );
  c := MB1.IndexOfAny( BYTE{ BYTE( C'A' ) }, 1 );
  
  MB1.RemoveStart( 1 );
  MB2.RemoveEnd( 2 );
  MB1.Remove( 2, 2 );
END wmain;

END MemoryBuffer.