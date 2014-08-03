using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer
{
    class Program
    {
        static List<Tuple<string, string>> EntitySources = new List<Tuple<string, string>>
        {
            Tuple.Create<string, string>( "E1", @"D:\Private\Skola\Disertace\MouseMeasurement\Mouse1\eliska.dtrk.201403151156.log" ),
            Tuple.Create<string, string>( "E2", @"D:\Private\Skola\Disertace\MouseMeasurement\Mouse2\eliska.trk.201403151257.log" ),
            Tuple.Create<string, string>( "J1", @"D:\Private\Skola\Disertace\MouseMeasurement\Mouse1\jirka.dtrk.201404011809 (1).log" ),
            Tuple.Create<string, string>( "J2", @"D:\Private\Skola\Disertace\MouseMeasurement\Mouse2\jirka.trk.201404021756 (2).log" ),
            Tuple.Create<string, string>( "M1", @"D:\Private\Skola\Disertace\MouseMeasurement\Mouse1\marek.dtrk.201404211842.log" ),
            Tuple.Create<string, string>( "M2", @"D:\Private\Skola\Disertace\MouseMeasurement\Mouse2\marek.trk.201404212002.log" ),
            Tuple.Create<string, string>( "Z1", @"D:\Private\Skola\Disertace\MouseMeasurement\Mouse1\zuza.dtrk.201404271826.log" ),
            Tuple.Create<string, string>( "Z2", @"D:\Private\Skola\Disertace\MouseMeasurement\Mouse2\zuza.trk.201404281740.log" )
        };

        private static List<Entity> entities = new List<Entity>();

        static void Main( string[] args )
        {
            System.Threading.Thread.CurrentThread.CurrentCulture = System.Globalization.CultureInfo.InvariantCulture;

            foreach( var source in EntitySources )
            {
                var loader = new Loader( source.Item2, 100.0 );
                entities.Add( new Entity( source.Item1, MouseAnalyzer.Event.SourceType.RAW, loader.RawEvents ) );
                entities.Add( new Entity( source.Item1, MouseAnalyzer.Event.SourceType.UEF, loader.UEFEvents ) );
            }

            var analyzer = new TimeGeometry();
            analyzer.Analyze( entities );
            analyzer.Dump( new CSVDumper(), entities );
        }
    }
}
