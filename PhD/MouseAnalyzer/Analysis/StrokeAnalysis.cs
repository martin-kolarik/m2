using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using MouseAnalyzer.Lookup;
using MouseAnalyzer.Optimizer;

namespace MouseAnalyzer.Analysis
{
    class StrokeAnalysis : AnalysisBase, IAnalysis
    {
        #region IAnalysis Members

        public void Analyze( IEnumerable<Entity> entities, SplitDefinition split = null )
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
                        stroke.AddItems( strokeExtractor.AddEvent( input, stroke.Items ) );
                    }
                    stroke.ComputeMarkers( "0" );

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
            Prepare( entities, Population.NormalizationType.Desquare, out markers, out population );
            PopulationOptimizer = new IterateOverBestPopulationOptimizer( markers, new Distance( Population.DistanceMeasureType.AverageWithLeastVariance ), population );
            // PopulationOptimizer = new AveragePopulationOptimizer( new Distance( Population.DistanceMeasureType.AverageWithLeastVariance ), population );
            PopulationOptimizer.Optimize( repeatCount, probes );
        }

        public void PushDumpedContent( CSVDumper dumper, IEnumerable<Entity> entities, string extendedSpecification = null )
        {
            dumper.AddContent( "s" + extendedSpecification, d =>
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
                    d.CellsE( entity.Id + entity.Source.ToString(), false, estimates.Select( e => ( (IValueMarker)e ).Value.ToString( "G4" ) ) );
                }
                foreach( var template in PopulationOptimizer.Population.Templates )
                {
                    d.CellsE( template.Entity.Id + template.Entity.Source.ToString(), false, template.Components.Select( c => c.ToString( "G4" ) ) );
                }

                d.CellsE( "WEIGHTS", false, firstEntity.Markers.Where( m1 => m1 is IValueMarker ).Select( m2 => m2.Name ) );
                foreach( var weights in PopulationOptimizer.WeightsAttempts )
                {
                    d.CellsE( "WEIGHTS", false, weights.Components.Select( w => w.ToString( "G4" ) ) );
                }
                d.Cell( "-----", "-----" );
                d.CellsE( "WEIG USE", false, PopulationOptimizer.Markers.Weights.Components.Select( w => w.ToString( "G4" ) ) );
                d.CellsE( "MASK ORD", false, PopulationOptimizer.ComponentsOrder.Components.Select( w => w.ToString( "G4" ) ) );
                d.CellsE( "MASK PCT", false, PopulationOptimizer.Percentile.Components.Select( w => w.ToString( "G4" ) ) );
                d.CellsE( "MASK VAL", false, PopulationOptimizer.Markers.Actives.Components.Select( w => w.ToString( "G4" ) ) );

                // histograms
                if( false )
                {
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
                }

                // population distances histogram
                var population = PopulationOptimizer.Population;
                var distances = population.Distances( new Distance(), Weights.Uniform( population.ComponentCount ) );
                var populationHistogramDefinition = new HistogramMarker.HistogramDefinition( 8 );
                populationHistogramDefinition.SupplyRange( distances.Min(), distances.Max() );
                var populationHistogram = new HistogramMarker( null, null, null, null, populationHistogramDefinition, distances );
                var pheaders = new List<string>();
                var pcolumns = new List<IEnumerable<object>>();
                pheaders.Add( "01B" );
                pheaders.Add( "02B" );
                pcolumns.Add( ( populationHistogram ).BinMidpoints.Select( hi => (object)hi ) );
                pcolumns.Add( ( populationHistogram ).Frequencies.Select( hi => (object)hi ) );
                d.Columns( pheaders, pcolumns );
            } );
        }

        #endregion
    }
}
