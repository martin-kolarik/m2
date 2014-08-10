using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using MouseAnalyzer.Optimizer;

namespace MouseAnalyzer.Lookup
{
    class OptimizedPopulation : Population
    {
        public OptimizedPopulation( IEnumerable<Entity> entities ) :
            base( entities )
        {
            WeightsAttempts = new List<Weights>();
        }

        public OptimizedPopulation( Population denormalized, NormalizationType howNormalize ) :
            base( denormalized, howNormalize )
        {
            WeightsAttempts = new List<Weights>();
        }

        public Distance OptimizedDistance { get; private set; }
        public Weights Weights { get { return WeightsAttempts[0]; } }
        public double MaximalDistance { get; private set; }

        public List<Weights> WeightsAttempts { get; private set; }
        public Vector ComputedMaskPercentile { get; private set; }
        public Weights ComputedMask { get; private set; }

        public void Optimize( Distance distance, int repeatCount = 1 )
        {
            OptimizedDistance = distance;

            WeightsAttempts.Clear();
            for( var repeat = 0; repeat < repeatCount; repeat++ )
            {
                WeightsAttempts.Add( DEOptimizer.Optimize( this, OptimizedDistance ));
            }

            MaximalDistance = Distance( distance, Weights );
        }

        public IEnumerable<Tuple<Entity, double>> Lookup( Template foreign, bool equalWeights = false, int candidates = 5 )
        {
            return base.Lookup( foreign, OptimizedDistance, equalWeights ? Weights.Uniform( Weights.ComponentCount ) : Weights, MaximalDistance, candidates );
        }

        public void ComputeMask( bool storeResultToSelf, double keptPercentile = 95, double uselessThresholdOrder = 1.0 ) // how order of useless wi must differ from uniform value order
        {
            var componentCount = Weights.ComponentCount;
            var uniform = Math.Log10( 1.0 / componentCount );

            var logAttempts = new List<Vector>();
            foreach( var attempt in WeightsAttempts )
            {
                logAttempts.Add( new Vector( attempt.Components.Select( c => Math.Log10( c ) ) ) );
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
            var mask = Weights.Unit( componentCount );
            var maskPercentile = new Vector( componentCount );
            foreach( var owi in ordered  )
            {
                percentile += WeightsAttempts.Select( wa => wa[owi.Item1] ).Average();
                maskPercentile[owi.Item1] = percentile;
                mask[owi.Item1] = percentile >= limitpercentile ? 0.0 : (owi.Item2 < 0.0 ? 0.5 : 1.0);
            }

            if( storeResultToSelf )
            {
                for( var i = 0; i < componentCount; ++i )
                {
                    Mask[i] = mask[i];
                }
            }
            ComputedMask = mask;
            ComputedMaskPercentile = maskPercentile;
        }
    }
}
