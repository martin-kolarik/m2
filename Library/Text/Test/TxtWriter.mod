MODULE TxtWriter;

FROM Exceptions IMPORT
   TestIfCatched;

IMPORT
  FIO,
  FIOO,
  IOO,
  Languages,
  Sync,
  StringsO,
  test,
  testimpl,
  TextWriter;

PROCEDURE Test();
VAR
  F : FIOO.CFileStream;
  W : TextWriter.CTextWriter;
BEGIN
  W.Stream := ADR( F );

   TRY
      F.FromPath( L'Test\TxtWriterUTF8.txt', FIOO.imCreate );
   CATCH : IOO.CIOException DO
   END;

  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', FALSE );
  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', FALSE );
  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', TRUE );

  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', FALSE );
  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', FALSE );
  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', TRUE );

  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', FALSE );
  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', FALSE );
  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', TRUE );

  F.Close( FALSE );

  W.Encoding := 1250;

   TRY
      F.FromPath( L'Test\TxtWriter1250.txt', FIOO.imCreate );
   CATCH : IOO.CIOException DO
   END;

  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', FALSE );
  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', FALSE );
  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', TRUE );

  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', FALSE );
  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', FALSE );
  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', TRUE );

  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', FALSE );
  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', FALSE );
  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', TRUE );

  F.Close( FALSE );

  W.Encoding := Languages.cp_UTF16;

   TRY
      F.FromPath( L'Test\TxtWriterUTF16.txt', FIOO.imCreate );
   CATCH : IOO.CIOException DO
   END;

  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', FALSE );
  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', FALSE );
  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', TRUE );

  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', FALSE );
  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', FALSE );
  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', TRUE );

  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', FALSE );
  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', FALSE );
  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', TRUE );

  F.Close( FALSE );
END Test;

#save, call( convention => cdecl )
PROCEDURE wmain02() : INTEGER;
#restore
BEGIN
  Test();
  RETURN 0;
END wmain02;

END TxtWriter.