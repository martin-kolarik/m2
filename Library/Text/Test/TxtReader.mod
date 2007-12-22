MODULE TxtReader;

IMPORT
  FIO,
  FIOO,
  IOO,
  Sync,
  StringsO,
  TextReader,
  windows;

PROCEDURE Test();
CONST
  CR = 13C;
  LF = 10C;
  s1a = C'Line1';
  s1b = s1a+CR+C'still line 1';
  s2a = s1a+LF+C'Line2';
  s2b = s1a+CR+LF+C'Line2';
VAR
  a : PWCHAR;
  Ch : WCHAR;
  f : FIO.File := windows.GetStdHandle( windows.STD_OUTPUT_HANDLE );
  F : FIOO.CFileStream;
  l : CARDINAL;
  M : IOO.CMemoryStream;
  R : TextReader.CTextReader;
  S : StringsO.CString;
BEGIN
  R.Stream := ADR( M );
  M.Init( ADR( s1a ), LENGTH( s1a ), IOO.accRead );
  WHILE R.ReadChar( OUT Ch, Sync.INFINITE_TIME, TRUE ) = Sync.arCompleted DO END;
  M.Init( ADR( s2a ), LENGTH( s2a ), IOO.accRead );
  WHILE R.ReadChar( OUT Ch, Sync.INFINITE_TIME, TRUE ) = Sync.arCompleted DO END;

  M.Init( ADR( s1a ), LENGTH( s1a ), IOO.accRead );
  R.ReadLine( OUT S, Sync.INFINITE_TIME, TRUE );

  M.Init( ADR( s1b ), LENGTH( s1b ), IOO.accRead );
  R.ReadLine( OUT S, Sync.INFINITE_TIME, TRUE );
  R.ReadLine( OUT S, Sync.INFINITE_TIME, TRUE );

  M.Init( ADR( s2a ), LENGTH( s2a ), IOO.accRead );
  R.ReadLine( OUT S, Sync.INFINITE_TIME, TRUE );
  R.ReadLine( OUT S, Sync.INFINITE_TIME, TRUE );

  M.Init( ADR( s2b ), LENGTH( s2b ), IOO.accRead );
  R.ReadLine( OUT S, Sync.INFINITE_TIME, TRUE );
  R.ReadLine( OUT S, Sync.INFINITE_TIME, TRUE );
  
  TRY
    F.FromPath( L'Test\TxtReaderUTF8.txt', FIOO.imOpenRead );
  CATCH : IOO.CIOException DO
  END;
  R.Stream := ADR( F );
  WHILE R.ReadLine( OUT S, Sync.INFINITE_TIME, TRUE ) = Sync.arCompleted DO
    FIO.WrStrW( f, OAsz( S.szData )); FIO.WrLnW( f );
  END; // WHILE

  TRY
    F.FromPath( L'Test\TxtReaderUTF8.txt', FIOO.imOpenRead );
  CATCH : IOO.CIOException DO
  END;
  S.FromOA( L"//" );
  R.Stream := ADR( F );
  R.CommentaryStart := S;
  WHILE R.ReadLine( OUT S, Sync.INFINITE_TIME, TRUE ) = Sync.arCompleted DO
    FIO.WrStrW( f, OAsz( S.szData )); FIO.WrLnW( f );
  END; // WHILE

  TRY
    F.FromPath( L'Test\TxtReaderUTF8.txt', FIOO.imOpenRead );
  CATCH : IOO.CIOException DO
  END;
  R.Stream := ADR( F );
  R.StartReading();
  WHILE R.Peek( OUT a, OUT l ) DO
    FIO.WrStrW( f, OA( l>>1-1, a )); FIO.WrLnW( f );
    R.ReadOut( l );
  END; // WHILE

  TRY
    F.FromPath( L'Test\TxtReaderUTF8.txt', FIOO.imOpenRead );
  CATCH : IOO.CIOException DO
  END;
  R.Stream := ADR( F );
  R.StartReading();
  WHILE R.Peek( OUT a, OUT l ) DO
    R.ReadLine( OUT S, Sync.INFINITE_TIME, TRUE );
    FIO.WrStrW( f, OAsz( S.szData )); FIO.WrLnW( f );
  END; // WHILE
END Test;

PROCEDURE wmain03() : INTEGER;
BEGIN
  Test();
  RETURN 0;
END wmain03;

END TxtReader.