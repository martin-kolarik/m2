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
    class StrokeMatchingAnalysis : AnalysisBase, IAnalysis
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
                    var strokeExtractor = new StrokeFeatureExtractor( 32 );
                    foreach( var input in events )
                    {
                        stroke.AddItems( strokeExtractor.AddEvent( input, stroke.TypedItems ) );
                    }
                    stroke.ComputeMarkers( "0", !leaveFeatureItems );

                    entity.AddFeature( stroke );
                } );
            }

            Executor.Complete();

            // evaluation

            // try what it does
            IList<double> result;

            // samples comparison
            var entity1 = entities.First();
            result = entity1.Match( entities, MatchType.ItemArithmeticAverage );
            result = result.OrderBy( r => -r ).ToList();

            result = entity1.Match( entities, MatchType.ItemProduct );
            result = result.OrderBy( r => -r ).ToList();

            result = entity1.Match( entities, MatchType.ItemGeometricAverage );
            result = result.OrderBy( r => -r ).ToList();

            result = entity1.Match( entities, MatchType.ItemD2Distance );
            result = result.OrderBy( r => -r ).ToList();

            // probabilistic comparison
            foreach( var entity in entities )
            {
                var items1 = entity.Features.First().Items.Skip( 10 ).Take( 10 );
                var pavg1 = Test( entities, items1, MatchType.DistributionArithmeticAverage, MatchType.DistributionProduct );
                var pprod1 = Test( entities, items1, MatchType.DistributionProduct, MatchType.DistributionProduct );
                var pgavg1 = Test( entities, items1, MatchType.DistributionGeometricAverage, MatchType.DistributionProduct );

                var items2 = entity.Features.First().Items.Skip( 500 ).Take( 10 );
                var pavg2 = Test( entities, items2, MatchType.DistributionArithmeticAverage, MatchType.DistributionProduct );
                var pprod2 = Test( entities, items2, MatchType.DistributionProduct, MatchType.DistributionProduct );
                var pgavg2 = Test( entities, items2, MatchType.DistributionGeometricAverage, MatchType.DistributionProduct );
            }

        }

        private IEnumerable<object> Test(
            IEnumerable<Entity> entities,
            IEnumerable<IFeatureItem> items,
            MatchType itemMatchType = MatchType.DistributionGeometricAverage,
            MatchType samplesMatchType = MatchType.DistributionProduct )
        {
            var matches = entities.Select( e =>
            {
                var samples = e.Match( null, items, itemMatchType );
                double p = 0.0;
                switch( samplesMatchType )
                {
                    case MatchType.DistributionSum:
                        p = samples.Sum();
                        break;
                    case MatchType.DistributionArithmeticAverage:
                        p = samples.Average();
                        break;
                    case MatchType.DistributionProduct:
                        p = samples.Product();
                        break;
                    case MatchType.DistributionGeometricAverage:
                        p = samples.GeometricAverage();
                        break;
                }
                return new
                {
                    entity = e,
                    probability = p
                };
            } );

            // bayes
            var sum = matches.Select( m => m.probability ).Sum();
            var probabilities = matches.Select( m => new
            {
                entity = m.entity,
                probability = sum == 0 ? 0.0 : m.probability / sum
            } );

            return probabilities;
        }

        public IPopulationOptimizer PopulationOptimizer { get; private set; }

        public void Optimize( IEnumerable<Entity> entities, int repeatCount = 1, IEnumerable<ProbeEntity> probes = null )
        {
        }

        public void PushDumpedContent( CSVDumper dumper, IEnumerable<Entity> entities, string extendedSpecification = null )
        {
        }

        #endregion
    }
}
