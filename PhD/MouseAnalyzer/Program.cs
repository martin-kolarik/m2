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

        static void Main( string[] args )
        {
            System.Threading.Thread.CurrentThread.CurrentCulture = System.Globalization.CultureInfo.InvariantCulture;

            foreach( var source in EntitySources )
            {
                var loader = new Loader( source.Item2, 100.0 );
                ProcessSource( source, loader.UEFEvents, "uef" );
                // ProcessSource( source, loader.RawEvents, "raw" );
            }
        }

        private static void ProcessSource( Tuple<string, string> source, IEnumerable<Event> events, string fileSuffix )
        {
            var name = source.Item1 + fileSuffix;

            var timing = new Timing();
            var timingExtractor = new TimingExtractor();
            foreach( var input in events )
            {
                timing.AddItems( timingExtractor.AddEvent( input, timing.Items ) );
            }
            timing.ComputeMarkers();

            var kinematics = new Kinematics();
            var kinematicsExtractor = new KinematicsExtractor();
            foreach( var input in events )
            {
                kinematics.AddItems( kinematicsExtractor.AddEvent( input, kinematics.Items ) );
            }
            kinematics.ComputeMarkers();

            var entity = new Entity( source.Item2 );
            entity.AddFeature( timing );
            entity.AddFeature( kinematics );

            var dumper = new CSVDumper();
            dumper.Dump( "hg" + name, d =>
            {
                // histograms and times
                var headers = new List<string>();
                var columns = new List<IEnumerable<object>>();
                var column = 1;

                var markers = entity.Markers.Where( m =>
                    m is IValueMarker &&
                    ( m.Estimate is InverseGaussianEstimate || m.Estimate is LognormalEstimate ) &&
                    ( m.MarkerTypeName.EndsWith( "Mean" ) || m.MarkerTypeName.Contains( "Lambda" ) || m.MarkerTypeName.EndsWith( "Mu" ) || m.MarkerTypeName.EndsWith( "Sigma" ) ) );
                foreach( IValueMarker marker in markers )
                {
                    headers.Add( ( column++ ).ToString( "D2" ) + marker.Name );
                    columns.Add( new List<object> { marker.Value.ToString( "G5" ) } );
                }

                var histograms = entity.Markers.Where( m => m is IHistogramMarker );
                foreach( var histogram in histograms )
                {
                    headers.Add( ( column++ ).ToString( "D2" ) + histogram.Name );
                    headers.Add( ( column++ ).ToString( "D2" ) + histogram.Name );
                    columns.Add( ( (IHistogramMarker)histogram ).BinMidpoints.Select( hi => (object)hi ) );
                    columns.Add( ( (IHistogramMarker)histogram ).Frequencies.Select( hi => (object)hi ) );
                }

                d.Columns( headers, columns );
            } );
        }
    }
}
