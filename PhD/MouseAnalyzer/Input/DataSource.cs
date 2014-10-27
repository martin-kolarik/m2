using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer
{
    class DataSource
    {
        public enum EnvironmentType
        {
            ControlledPlain,
            ControlledAccelerated,
            Uncontrolled
        }

        public enum SourceType
        {
            DRV,
            API
        }

        public DataSource( string person, EnvironmentType environment, string filePath )
        {
            events[SourceType.DRV] = null;
            events[SourceType.API] = null;

            Person = person;
            Environment = environment;
            this.filePath = filePath;
        }

        public EnvironmentType Environment { get; private set; }
        public string Person { get; private set; }
        public string Id { get { return Person + EnvironmentTypeString(); } }

        public IList<Event> GetEvents( SourceType sourceType ) {
            if( events[sourceType] == null )
            {
                events[sourceType] = new Loader( filePath, 100.0 ).GetEvents( sourceType );
            }
            return events[sourceType];
        }

        private string filePath;
        private Dictionary<SourceType, IList<Event>> events = new Dictionary<SourceType,IList<Event>>();

        private string EnvironmentTypeString()
        {
            switch( Environment ){
                case EnvironmentType.ControlledAccelerated : return "ca";
                case EnvironmentType.ControlledPlain : return "cp";
                case EnvironmentType.Uncontrolled : return "uc";
                default: return "??";
            }
        }
    }

    static class DataSources
    {
        static DataSources()
        {
            sources = new List<DataSource>()
            {
                new DataSource( "ElK", DataSource.EnvironmentType.ControlledPlain, @"D:\Private\Skola\Disertace\MouseMeasurement\Mouse1\eliska.dtrk.201403151156.log" ),
                new DataSource( "ElK", DataSource.EnvironmentType.ControlledAccelerated, @"D:\Private\Skola\Disertace\MouseMeasurement\Mouse2\eliska.trk.201403151257.log" ),

                new DataSource( "JiH", DataSource.EnvironmentType.ControlledPlain, @"D:\Private\Skola\Disertace\MouseMeasurement\Mouse1\jirda.dtrk.201404011809 (1).log" ),
                new DataSource( "JiH", DataSource.EnvironmentType.ControlledAccelerated, @"D:\Private\Skola\Disertace\MouseMeasurement\Mouse2\jirda.trk.201404021756 (2).log" ),

                new DataSource( "MaK", DataSource.EnvironmentType.ControlledPlain, @"D:\Private\Skola\Disertace\MouseMeasurement\Mouse1\marek.dtrk.201404211842.log" ),
                new DataSource( "MaK", DataSource.EnvironmentType.ControlledAccelerated, @"D:\Private\Skola\Disertace\MouseMeasurement\Mouse2\marek.trk.201404212002.log" ),

                new DataSource( "ZuK", DataSource.EnvironmentType.ControlledPlain, @"D:\Private\Skola\Disertace\MouseMeasurement\Mouse1\zuza.dtrk.201404271826.log" ),
                new DataSource( "ZuK", DataSource.EnvironmentType.ControlledAccelerated, @"D:\Private\Skola\Disertace\MouseMeasurement\Mouse2\zuza.trk.201404281740.log" ),

                new DataSource( "PeK", DataSource.EnvironmentType.ControlledPlain, @"D:\Private\Skola\Disertace\MouseMeasurement\Mouse1\petrkucera.dtrk.201407061751.log" ),
                new DataSource( "PeK", DataSource.EnvironmentType.ControlledAccelerated, @"D:\Private\Skola\Disertace\MouseMeasurement\Mouse2\petrkucera.trk.201407061854.log" ),

                new DataSource( "MiH", DataSource.EnvironmentType.ControlledPlain, @"D:\Private\Skola\Disertace\MouseMeasurement\Mouse1\michalhladik.dtrk.201408041600.log" ),
                new DataSource( "MiH", DataSource.EnvironmentType.ControlledAccelerated, @"D:\Private\Skola\Disertace\MouseMeasurement\Mouse2\michalhladik.trk.201408041701.log" ),

                new DataSource( "HoM", DataSource.EnvironmentType.ControlledPlain, @"D:\Private\Skola\Disertace\MouseMeasurement\Mouse1\michna.dtrk.201408061833.log" ),
                new DataSource( "HoM", DataSource.EnvironmentType.ControlledAccelerated, @"D:\Private\Skola\Disertace\MouseMeasurement\Mouse2\michna.trk.201408061938.log" ),

                new DataSource( "RuD", DataSource.EnvironmentType.ControlledPlain, @"D:\Private\Skola\Disertace\MouseMeasurement\Mouse1\ruda.dtrk.201408111639.log" ),
                new DataSource( "RuD", DataSource.EnvironmentType.ControlledAccelerated, @"D:\Private\Skola\Disertace\MouseMeasurement\Mouse2\ruda.trk.201408111733.log" ),

                new DataSource( "JiB", DataSource.EnvironmentType.ControlledPlain, @"D:\Private\Skola\Disertace\MouseMeasurement\Mouse1\jirkabaros.dtrk.201409261541.log" ),
                new DataSource( "JiB", DataSource.EnvironmentType.ControlledAccelerated, @"D:\Private\Skola\Disertace\MouseMeasurement\Mouse2\jirkabaros.trk.201409261643.log" ),

                new DataSource( "ZdV", DataSource.EnvironmentType.ControlledPlain, @"D:\Private\Skola\Disertace\MouseMeasurement\Mouse1\zdenkavymetalova.dtrk.201409271547.log" ),
                new DataSource( "ZdV", DataSource.EnvironmentType.ControlledAccelerated, @"D:\Private\Skola\Disertace\MouseMeasurement\Mouse2\zdenkavymetalova.trk.201409271648.log" ),

                // new DataSource( "MaZ", DataSource.EnvironmentType.ControlledPlain, @"D:\Private\Skola\Disertace\MouseMeasurement\Mouse1\XXX.log" ),
                new DataSource( "MaZ", DataSource.EnvironmentType.ControlledAccelerated, @"D:\Private\Skola\Disertace\MouseMeasurement\Mouse2\martinzachar.trk.201410051708.log" ),

                new DataSource( "MiB", DataSource.EnvironmentType.ControlledPlain, @"D:\Private\Skola\Disertace\MouseMeasurement\Mouse1\michaelabrychtova.dtrk.201410051236.log" ),
                new DataSource( "MiB", DataSource.EnvironmentType.ControlledAccelerated, @"D:\Private\Skola\Disertace\MouseMeasurement\Mouse2\michaela.brychtova.trk.201410051457.log" )
            };
        }

        public static Entity Get( string person, DataSource.EnvironmentType environment, DataSource.SourceType sourceType )
        {
            var filtered = sources.Where( s => s.Person == person && s.Environment == environment ).First();
            return new Entity( filtered.Id, sourceType, filtered.GetEvents( sourceType ) );
        }

        public static List<Entity> Get( DataSource.EnvironmentType environment, DataSource.SourceType sourceType )
        {
            return sources.
                   Where( s => s.Environment == environment ).
                   Select( f => new Entity( f.Id, sourceType, f.GetEvents( sourceType ) ) ).
                   ToList<Entity>();
        }

        private static List<DataSource> sources;
    }
}
