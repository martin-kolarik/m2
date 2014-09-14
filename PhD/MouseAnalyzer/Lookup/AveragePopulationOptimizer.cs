using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer.Lookup
{
    class AveragePopulationOptimizer : PopulationOptimizerBase, IPopulationOptimizer
    {
        public AveragePopulationOptimizer( Features.Markers markers, Optimizer.Distance distance, Population population )
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

            ComputeMaskFromAttempts();
        }

        public IEnumerable<Tuple<Entity, double>> Lookup( Template template, bool useUniformWeights = false )
        {
            return Population.Lookup( template, Distance, useUniformWeights ? Optimizer.Weights.Uniform( Population.ComponentCount ) : Weights, MaximalDistanceMeasure );
        }

        private void ComputeMaskFromAttempts( double keptPercentile = 95, double uselessThresholdOrder = 1.0 ) // how order of useless wi must differ from uniform value order
        {
            var componentCount = Weights.ComponentCount;
            var uniform = Math.Log10( 1.0 / componentCount );

            var logAttempts = new List<Optimizer.Vector>();
            foreach( var attempt in WeightsAttempts )
            {
                logAttempts.Add( new Optimizer.Vector( attempt.Components.Select( c => Math.Log10( c ) ) ) );
            }

            var statistics = new List<Tuple<int, double, double>>(); // original index, counted sub-threshold value, summed sub-threshold value, summed threshold value
            for( var wi = 0; wi < componentCount; ++wi )
            {
                var aboveThresholdCount = logAttempts.Where( la1 => la1[wi] - uniform > 0.33333 * uselessThresholdOrder ).Select( la2 => la2[wi] ).Count();
                var subThresholdCount = logAttempts.Where( la1 => uniform - la1[wi] > uselessThresholdOrder ).Select( la2 => la2[wi] ).Count();
                var sum = logAttempts.Select( la => la[wi] ).Sum();
                statistics.Add( new Tuple<int, double, double>( wi, aboveThresholdCount - subThresholdCount, sum ) );
            }
            var ordered = statistics.OrderBy( si1 => -si1.Item2 ).ThenBy( si2 => -si2.Item3 );

            // now percentile is evaluated over whole data set, weight on owi-th place is computed as sum of weights
            // of all attempts and averaged to component count. This way whole attempt data space is taken into account.
            var percentile = 0.0;
            var limitpercentile = keptPercentile / 100.0;
            var componentOrder = 0;
            var maskPercentile = new Optimizer.Vector( componentCount );
            var maskComponentsOrder = new Optimizer.Vector( componentCount );
            foreach( var owi in ordered  )
            {
                percentile += WeightsAttempts.Select( wa => wa[owi.Item1] ).Average();
                maskPercentile[owi.Item1] = percentile;
                Markers.SetActive( owi.Item1, percentile < limitpercentile );
                maskComponentsOrder[owi.Item1] = ++componentOrder;
            }
            Markers.Weights = Weights;

            Percentile = maskPercentile;
            ComponentsOrder = maskComponentsOrder;
        }

        private List<Optimizer.Weights> weightsAttempts;
        private int bestWeightsIndex;
    }
}
