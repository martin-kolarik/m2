using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using MouseAnalyzer.Lookup;
using MouseAnalyzer.Optimizer;

namespace MouseAnalyzer.Analysis
{
    class StrokePopulationAnalysis : AnalysisBase, IAnalysis
    {
        #region IAnalysis Members

        public void Analyze( IEnumerable<Entity> entities, SplitDefinition split = null, bool leaveFeatureItems = false )
        {
            foreach( var entity in entities )
            {
                Executor.Queue( () =>
                {
                    var events = SplitDefinition.Split( split, entity.Events );

                    // stroke
                    var stroke = new StrokeFeature( entity );
                    var strokeExtractor = new StrokeFeatureExtractor();
                    foreach( var input in events )
                    {
                        stroke.AddItems( strokeExtractor.AddEvent( input, stroke.TypedItems ) );
                    }
                    stroke.ComputeMarkers( "0", !leaveFeatureItems );

                    entity.AddFeature( stroke );
                } );
            }

            Executor.Complete();
        }

        public IPopulationOptimizer PopulationOptimizer { get; private set; }

        public void Optimize( IEnumerable<Entity> entities, int repeatCount = 1, IEnumerable<ProbeEntity> probes = null )
        {
            Features.Markers markers;
            Population population;
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
                headers.Add( "marker" );
                var row = 1;
                columns.Add( entities.First().Markers.
                    Where( m => m is IDistributionMarker ).
                    Cast<IDistributionMarker>().
                    SelectMany( m => m.ParameterNames.Select( pn => (row++).ToString( "D2" ) + " " + m.Feature.Source.ToString() + "." + m.Name + "." + pn ) ) );

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
