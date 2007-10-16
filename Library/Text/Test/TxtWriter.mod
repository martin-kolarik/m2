MODULE TxtWriter;

IMPORT
  FIO,
  FIOO,
  IOO,
  Sync,
  StringsO,
  TextWriter,
  windows,
  winnls;

PROCEDURE Test();
VAR
  f : FIO.File := windows.GetStdHandle( windows.STD_OUTPUT_HANDLE );
  F : FIOO.CFileStream;
  W : TextWriter.CTextWriter;
BEGIN
  W.Stream := ADR( F );

  F.FromPath( L'Test\TxtWriterUTF8.txt', FIOO.imCreate );

  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', FALSE );
  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', FALSE );
  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', TRUE );

  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', FALSE );
  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', FALSE );
  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', TRUE );

  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', FALSE );
  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', FALSE );
  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', TRUE );

  W.Close( TRUE );

  W.Encoding := 1250;
  F.FromPath( L'Test\TxtWriter1250.txt', FIOO.imCreate );

  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', FALSE );
  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', FALSE );
  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', TRUE );

  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', FALSE );
  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', FALSE );
  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', TRUE );

  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', FALSE );
  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', FALSE );
  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', TRUE );

  W.Close( TRUE );

  W.Encoding := winnls.CP_UTF16;
  F.FromPath( L'Test\TxtWriterUTF16.txt', FIOO.imCreate );

  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', FALSE );
  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', FALSE );
  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', TRUE );

  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', FALSE );
  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', FALSE );
  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', TRUE );

  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', FALSE );
  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', FALSE );
  W.WriteOA( L'ìšèøžýáíé Bruèel medvìd. ', TRUE );

  W.Close( TRUE );
END Test;

#save, call( entry_point => on )
PROCEDURE wmain() : INTEGER;
#restore
BEGIN
  Test();
  RETURN 0;
END wmain;

END TxtWriter.