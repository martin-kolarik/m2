MODULE TRijndaelFilter;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   cphfilter,
   IOO,
   log,
   StorageO,
   Strings,
   sync,
   test,
   testimpl;
  
(*===========================================================================*)

CONST
   input = L"Dùm stál na mírném svahu na samém konci vesnice. Stál o samotì, s vyhlídkou na širé lány jihozápadní Anglie. Rozhodnì nièím nevynikal - asi tøicet let starý, podsaditý, pøibližnì ètvercový cihlový dùm, v prùèelí se ètyømi okny, jejichž velikost v pomìru k celku víceménì pøesnì nelahodila oku. Jediný èlovìk, kterého dùm nìèím zajímal, byl Arthur Dent, a to ještì jen proto, že v nìm náhodou zrovna bydlel. Bydlel tu už tøi roky, od té doby, co se odstìhoval z Londýna, protože na Londýn prostì nemìl nervy. I on byl asi tøicetiletý, vysoký, tmavovlasý a vždycky trochu nesvùj. Nejvíc starostí mu pùsobilo, že se ho všichni poøád ptali, proè vypadá tak ustaranì. Pracoval v místním rozhlase, o kterém vždycky øíkával kamarádùm, že je mnohem, ale mnohem lepší, než si asi myslí. Taky že byl - vìtšina jeho kamarádù totiž pracovala v reklamì. V noci ze støedy na ètvrtek lilo, takže ulice byla mokrá a rozblácená, ale ranní slunce záøivì vesele svítilo - a mìlo to být naposledy - na Arthurùv dùm. Nikdo mu ještì neoznámil, že obecní rada chce dùm zbourat a postavit místo nìj dálnici.";

(*===========================================================================*)

TYPE
   TPTest = POINTER TO CTest;

(*---------------------------------------------------------------------------*)

CLASS CTest IMPLEMENTS test.ITest;
   PUBLIC VAR
      Host : test.TPHost := NIL;

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
END CTest;

(*===========================================================================*)

VAR
   Test : CTest;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CTest;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   VAR
      c : CARDINAL;
      Failure : BOOLEAN;
      filter : cphfilter.CRijndaelFilter;
      filterStream : IOO.CFilterStream;
      mb : StorageO.CMemoryBuffer;
      memoryStream : IOO.CMemoryBufferStream;
      output : ARRAY [0..4095] OF WCHAR;
      result : sync.TAsyncResult;
   BEGIN
      SELF.Host := Host;
      output[0] := 0W;

      Host^.StartPhase( L"Write and read ciphered stream" );
      
      memoryStream.Init( REF mb, IOO.accReadWrite );

      filter.Init( TRUE, L"heslo", L"iv" );
      filterStream.Init( ADR( filter ), ADR( filter ));
      filterStream.Stream := ADR( memoryStream );
      filterStream.WriteOA( input, OUT c, sync.FOREVER );
      
      filter.Init( FALSE, L"heslo", L"iv" );
      filterStream.Position := 0;
      filterStream.ReadOA( REF output, OUT c, sync.FOREVER );
      filterStream.ReadOA( REF output, OUT c, sync.FOREVER );
      Failure := NOT EQUALS( input, output );
      
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      Host^.StartPhase( L"Write and read with bad password" );
      
      filter.Init( FALSE, L"heslo", L"yv" );
      filterStream.Position := 0;
      result := filterStream.ReadOA( REF output, OUT c, sync.FOREVER );
      result := filterStream.ReadOA( REF output, OUT c, sync.FOREVER );
      Failure := result <> sync.arAborted;
      
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;
      
      filterStream.Close( FALSE );
      filterStream.Stream := NIL;

      IF Failure THEN
         RETURN test.trFailure;
      ELSE
         RETURN test.trSuccess;
      END;
   END Run;
   
(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"Ciphering::RijndaelFilter", ADR( Test ));
END CTest;

(*===========================================================================*)

END TRijndaelFilter.
