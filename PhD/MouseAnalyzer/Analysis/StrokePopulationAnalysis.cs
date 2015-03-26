using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using MouseAnalyzer.Lookup;
using MouseAnalyzer.Optimizer;
using MouseAnalyzer.Statistics;

namespace MouseAnalyzer.Analysis
{
    class StrokePopulationAnalysis : AnalysisBase, IAnalysis
    {
        public StrokePopulationAnalysis( StrokeFeatureItem.ItemType strokeKind, int endGapThreshold )
        {
            StrokeKind = strokeKind;
            EndGapThreshold = endGapThreshold;
        }

        StrokeFeatureItem.ItemType StrokeKind;
        private int EndGapThreshold;

        #region IAnalysis Members

        public void Analyze( IEnumerable<Entity> entities, SplitDefinition split = null, bool leaveFeatureItems = false )
        {
            foreach( var entity in entities )
            {
                Executor.Queue( () =>
                {
                    var events = SplitDefinition.Split( split, entity.Events );

                    // stroke
                    var stroke = new StrokeFeature( entity, StrokeKind );
                    var strokeExtractor = new StrokeFeatureExtractor( StrokeKind, EndGapThreshold );
                    foreach( var input in events )
                    {
                        stroke.AddItems( strokeExtractor.AddEvent( input, stroke.TypedItems ) );
                    }
                    stroke.ComputeMarkers( "0", !leaveFeatureItems );

                    /*
                    var dTs = events.Select( e => e.dT );
                    var definition = new HistogramDefinition( 200 );
                    var min = dTs.Min();
                    var max = dTs.Max();
                    definition.SupplyRange( min, max );
                    var histogram1 = new Histogram( definition, dTs, min, max );

                    dTs = events.Select( e => e.dT ).Where( dT => dT <= 500.0 && dT >= 12.0 );
                    definition = new HistogramDefinition( 200 );
                    min = 12;
                    max = 500;
                    definition.SupplyRange( min, max );
                    var histogram2 = new Histogram( definition, dTs, min, max );

                    dTs = events.Select( e => e.dT ).Where( dT => dT <= 80 );
                    definition = new HistogramDefinition( 201 );
                    min = -0.2;
                    max = 80.2;
                    definition.SupplyRange( min, max );
                    var histogram3 = new Histogram( definition, dTs, min, max );
                    */

                    entity.AddFeature( stroke );
                } );
            }

            Executor.Complete();
        }

        public IPopulationOptimizer PopulationOptimizer { get; private set; }

        public void Optimize( IEnumerable<Entity> entities, int repeatCount = 1, IEnumerable<ProbeEntity> probes = null )
        {
            // Features.Markers markers;
            // Population population;
            // PrepareValueMarkers( entities, Population.NormalizationType.Desquare, out markers, out population );
            // PopulationOptimizer = new IterateOverBestPopulationOptimizer( markers, new Distance( Population.DistanceMeasureType.AverageWithLeastVariance ), population );
            // PopulationOptimizer = new AveragePopulationOptimizer( markers, new Distance( Population.DistanceMeasureType.AverageWithLeastVariance ), population );
            // PopulationOptimizer.Optimize( repeatCount, probes );
        }

        public void PushDumpedContent( CSVDumper dumper, IEnumerable<Entity> entities, string extendedSpecification = null )
        {
            dumper.AddContent( "s" + extendedSpecification, d =>
            {
                var headers = new List<string>();
                var columns = new List<IEnumerable<object>>();

                // estimates
                headers.Add( "marker;" );
                var row = 1;
                columns.Add( entities.First().Markers.
                    Where( m => m is IDistributionMarker ).
                    Cast<IDistributionMarker>().
                    SelectMany( m => m.ParameterNames.Select( pn => (row++).ToString( "D2" ) + " " + m.Feature.Source.ToString() + "." + m.Name + "." + pn + ";" + m.Distribution.Positive.Type.ToString() ) ) );

                foreach( var entity in entities )
                {
                    headers.Add( entity.Id );

                    var estimates = entity.Markers.Where( m => m is IDistributionMarker ).Cast<IDistributionMarker>();
                    columns.Add( estimates.SelectMany( e => e.ParameterValues.Select( pv => pv.ToString( "G4" ) ) ) );
                }

                d.Columns( headers, columns );

                // histograms
                if( true )
                {
                    var column = 1;
                    headers = new List<string>();
                    columns = new List<IEnumerable<object>>();
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
                }
            } );
        }

        #endregion
    }
}
