using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer.Lookup
{
    class IterateOverBestPopulationOptimizer : PopulationOptimizerBase, IPopulationOptimizer
    {
        public IterateOverBestPopulationOptimizer( Features.Markers markers, Optimizer.Distance distance, Population population )
        {
            Markers = markers;
            Distance = distance;
            Population = population;
            Population.PrecomputeUnoptimizedDistances( distance.Item1 );
        }

        public Features.Markers Markers { get; private set; }
        public Optimizer.Distance Distance { get; private set; }
        public Population Population { get; private set; }

        public Optimizer.Weights Weights { get { return weights; } }
        public IEnumerable<Optimizer.Weights> WeightsAttempts { get { return weightsAttempts; } }
        public double MaximalDistanceMeasure { get; private set; }

        public Optimizer.Vector ComponentsOrder { get; private set; }
        public Optimizer.Vector Percentile { get; private set; }

        public void Optimize( int vectorSetOptimizationRepeatCount = 1, IEnumerable<ProbeEntity> probes = null )
        {
            var componentCount = Population.ComponentCount;
            var probesCount = (double)probes.Count();

            var order = 0;
            ComponentsOrder = new Optimizer.Vector( componentCount );
            var componentsByOrder = new int[componentCount];

            // FORWARD RUN -- always remove the BEST compoent and remember its order
            for( var i = 0; i < componentCount; i++ )
            {
                if( !Markers.IsConstant( i ))
                {
                    // optimize vector set
                    weightsAttempts = OptimizeVectorSet( Markers, Distance, Population, vectorSetOptimizationRepeatCount );
                    // take best distance
                    int bestWeightsIndex;
                    double bestDistanceMeasure;
                    DetermineBestDistanceMeasure( weightsAttempts, Distance, Population, out bestWeightsIndex, out bestDistanceMeasure );
                    // take best weight
                    var bestWeightIndexCounter = 0;
                    var bestWeightIndex = weightsAttempts[bestWeightsIndex].Components.Select( c => new
                    {
                        index = bestWeightIndexCounter++,
                        weight = c
                    } ).OrderByDescending( oc => oc.weight ).First().index;

                    // remember order of the component
                    componentsByOrder[order] = bestWeightIndex;
                    ComponentsOrder[bestWeightIndex] = ++order;

                    // remove best component and lookup once more using remaining ones
                    Markers.SetActive( bestWeightIndex, false );
                }
            }

            // BACKWARD RUN -- add remembered components one by one successively and test FAR for growing array of components
            // evaluate FARs
            double minFAR = double.MaxValue;
            List<Optimizer.Weights> minFARAttempts = null;
            Optimizer.Weights minFARWeights = null;
            for( var i = 0; i < order; i++ )
            {
                Markers.SetActive( componentsByOrder[i], true );

                weightsAttempts = OptimizeVectorSet( Markers, Distance, Population, vectorSetOptimizationRepeatCount );
                int bestWeightsIndex;
                double bestDistanceMeasure;
                DetermineBestDistanceMeasure( weightsAttempts, Distance, Population, out bestWeightsIndex, out bestDistanceMeasure );
                weights = weightsAttempts[bestWeightsIndex];
                
                foreach( var probe in probes )
                {
                    probe.TestMatch( this );
                }
                var far = probes.Where( p => p.ClosestOptimized.Id != p.Related.Id ).Count() / probesCount;
                if( far < minFAR )
                {
                    minFAR = far;
                    minFARAttempts = weightsAttempts;
                    minFARWeights = weightsAttempts[bestWeightsIndex];
                }
            }

            // FINALLY construct resulting statistics
            weightsAttempts = minFARAttempts;
            weights = minFARWeights;
            var statistics = new List<Tuple<int, double>>();
            for( var i = 0; i < componentCount; i++ )
            {
                Markers.SetActive( i, weights[i] > 0.0 );
                statistics.Add( new Tuple<int, double>( i, weights[i] ) );
            }
            Markers.Weights = weights;

            var percentile = 0.0;
            var componentOrder = 0;
            Percentile = new Optimizer.Vector( componentCount );
            ComponentsOrder = new Optimizer.Vector( componentCount );
            foreach( var os in statistics.OrderBy( s => -s.Item2 ) )
            {
                percentile += os.Item2;
                Percentile[os.Item1] = percentile;
                ComponentsOrder[os.Item1] = ++componentOrder;
            }
            MaximalDistanceMeasure = Population.DistanceMeasure( new Optimizer.Distance( Distance.Type, Population.DistanceMeasureType.Maximum ), minFARWeights );
        }

        public IEnumerable<Tuple<Entity, double>> Lookup( Template template, bool useUniformWeights = false )
        {
            return Population.Lookup( template, Distance, useUniformWeights ? Optimizer.Weights.Uniform( Population.ComponentCount ) : Weights, MaximalDistanceMeasure );
        }

        private List<Optimizer.Weights> weightsAttempts;
        private Optimizer.Weights weights;
    }
}
