using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer.Lookup
{
    class ThresholdPopulationOptimizer : PopulationOptimizerBase, IPopulationOptimizer
    {
        public ThresholdPopulationOptimizer( Features.Markers markers, Optimizer.Distance distance, Population population )
        {
            Markers = markers;
            Distance = distance;
            Population = population;
            Population.PrecomputeUnoptimizedDistances( distance.Item1 );
        }

        public Features.Markers Markers { get; private set; }
        public Optimizer.Distance Distance { get; private set; }
        public Population Population { get; private set; }

        public Optimizer.Weights Weights { get { return weightsAttempts[bestWeightsIndex]; } }
        public IEnumerable<Optimizer.Weights> WeightsAttempts { get { return weightsAttempts; } }
        public double MaximalDistanceMeasure { get; private set; }

        public Optimizer.Vector ComponentsOrder { get; private set; }
        public Optimizer.Vector Percentile { get; private set; }

        public void Optimize( int vectorSetOptimizationRepeatCount = 1, IEnumerable<ProbeEntity> probes = null )
        {
            weightsAttempts = OptimizeVectorSet( Markers, Distance, Population, vectorSetOptimizationRepeatCount );

            double bestDistanceMeasure;
            DetermineBestDistanceMeasure( weightsAttempts, Distance, Population, out bestWeightsIndex, out bestDistanceMeasure );
            MaximalDistanceMeasure = bestDistanceMeasure;

            Markers.Weights = Weights;
            ComputeMaskFromWeigths( 1.0 / Population.ComponentCount );
        }

        public IEnumerable<Tuple<Entity, double>> Lookup( Template template, bool useUniformWeights = false )
        {
            return Population.Lookup( template, Distance, useUniformWeights ? Optimizer.Weights.Uniform( Population.ComponentCount ) : Weights, MaximalDistanceMeasure );
        }

        private void ComputeMaskFromWeigths( double threshold )
        {
            var componentCount = Weights.ComponentCount;
            var statistics = new List<Tuple<int, double>>();
            for( var i = 0; i < componentCount; i++ )
            {
                statistics.Add( new Tuple<int, double>( i, Weights[i] >= threshold ? Weights[i] : 0.0 ) );
            }
            var ordered = statistics.OrderBy( s => -s.Item2 );

            var percentile = 0.0;
            var componentOrder = 0;
            var maskPercentile = new Optimizer.Vector( componentCount );
            var maskComponentsOrder = new Optimizer.Vector( componentCount );
            foreach( var owi in ordered )
            {
                percentile += owi.Item2;
                maskPercentile[owi.Item1] = percentile;
                maskComponentsOrder[owi.Item1] = ++componentOrder;
                Markers.SetActive( owi.Item1, owi.Item2 > 0.0 );
            }

            Percentile = maskPercentile;
            ComponentsOrder = maskComponentsOrder;
        }

        private List<Optimizer.Weights> weightsAttempts;
        private int bestWeightsIndex;
    }
}
