using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer
{
    class TimeGeometry : IAnalysis
    {
        #region IAnalysis Members

        public void Analyze( IEnumerable<Entity> entities )
        {
            foreach( var entity in entities )
            {
                // timing
                var timing = new Timing( entity );
                var timingExtractor = new TimingExtractor();
                foreach( var input in entity.Events )
                {
                    timing.AddItems( timingExtractor.AddEvent( input, timing.Items ) );
                }
                timing.ComputeMarkers( "0" );
                entity.AddFeature( timing );

                // kinematics
                var kinematics = new Kinematics( entity );
                var kinematicsExtractor = new KinematicsExtractor();
                foreach( var input in entity.Events )
                {
                    kinematics.AddItems( kinematicsExtractor.AddEvent( input, kinematics.Items ) );
                }
                kinematics.ComputeMarkers( "0" );
                entity.AddFeature( kinematics );
            }

        }

        public void Dump( CSVDumper dumper, IEnumerable<Entity> entities )
        {
            dumper.Dump( "tg", d =>
            {
                // estimates
                var printHeader = true;
                foreach( var entity in entities )
                {
                    var estimates = entity.Markers.Where( m =>
                        m is IValueMarker &&
                        ( m.Estimate is InverseGaussianEstimate || m.Estimate is LognormalEstimate ) &&
                        ( m.MarkerTypeName.EndsWith( "Mean" ) || m.MarkerTypeName.Contains( "Lambda" ) || m.MarkerTypeName.EndsWith( "Mu" ) || m.MarkerTypeName.EndsWith( "Sigma" ) ) );
                    if( printHeader )
                    {
                        d.CellsE( "", false, estimates.Select( e => e.Feature.Source.ToString() + " " + e.Name ) );
                        printHeader = false;
                    }
                    d.CellsE( entity.Id, false, estimates.Select( e => ((IValueMarker)e).Value.ToString( "G5" ) ) );
                }

                // histograms
                var column = 1;
                var headers = new List<string>();
                var columns = new List<IEnumerable<object>>();
                var markers = entities.SelectMany( e => e.Markers );
                var histograms = markers.Where( m => m is IHistogramMarker );
                foreach( IHistogramMarker histogram in histograms )
                {
                    var header = histogram.Feature.Entity.Id + histogram.Feature.Source.ToString() + " " + histogram.Name;
                    headers.Add( ( column++ ).ToString( "D2" ) + header );
                    headers.Add( ( column++ ).ToString( "D2" ) + header );
                    columns.Add( ( histogram ).BinMidpoints.Select( hi => (object)hi ) );
                    columns.Add( ( histogram ).Frequencies.Select( hi => (object)hi ) );
                }

                d.Columns( headers, columns );
            } );
        }

        #endregion
    }
}
