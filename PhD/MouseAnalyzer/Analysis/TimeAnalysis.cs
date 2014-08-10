using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using MouseAnalyzer.Lookup;
using MouseAnalyzer.Optimizer;

namespace MouseAnalyzer.Analysis
{
    class TimeAnalysis : AnalysisBase, IAnalysis
    {
        #region IAnalysis Members

        public void Analyze( IEnumerable<Entity> entities, SplitDefinition split = null )
        {
            foreach( var entity in entities )
            {
                Executor.Queue( () =>
                {
                    var events = SplitDefinition.Split( split, entity.Events );

                    // timing
                    var timing = new TimingFeature( entity );
                    var timingExtractor = new TimingFeatureExtractor();
                    foreach( var input in events )
                    {
                        timing.AddItems( timingExtractor.AddEvent( input, timing.Items ) );
                    }
                    timing.ComputeMarkers( "0" );
                    entity.AddFeature( timing );
                } );
            }

            Executor.Complete();
        }

        public void PushDumpedContent( CSVDumper dumper, IEnumerable<Entity> entities, string extendedSpecification = null )
        {
            dumper.AddContent( "t" + extendedSpecification, d =>
            {
                // estimates
                var printHeader = true;
                Entity firstEntity = null;
                foreach( var entity in entities )
                {
                    firstEntity = firstEntity==null ? entity : firstEntity;
                    var estimates = entity.Markers.Where( m => m is IValueMarker );
                    if( printHeader )
                    {
                        d.CellsE( "", false, estimates.Select( e => e.Feature.Source.ToString() + " " + e.Name ) );
                        printHeader = false;
                    }
                    d.CellsE( entity.Id + entity.Source.ToString(), false, estimates.Select( e => ((IValueMarker)e).Value.ToString( "G5" ) ) );
                }

                d.CellsE( "WEIGHTS", false, firstEntity.Markers.Where( m1 => m1 is IValueMarker ).Select( m2 => m2.Name ) );
                d.CellsE( "WEIGHTS", false, Population.Weights.Components.Select( w => w.ToString( "G5" ) ) );

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
