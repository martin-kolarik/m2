using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer.Lookup
{
    interface IPopulationOptimizer
    {
        Features.Markers Markers { get; }
        Optimizer.Distance Distance { get; }
        Population Population { get; }

        Optimizer.Weights Weights { get; }
        IEnumerable<Optimizer.Weights> WeightsAttempts { get; }
        double MaximalDistanceMeasure { get; }

        Optimizer.Vector ComponentsOrder { get; }
        Optimizer.Vector Percentile { get; }

        void Optimize( int vectorSetOptimizationRepeatCount = 1, IEnumerable<ProbeEntity> probes = null );
        IEnumerable<Tuple<Entity, double>> Lookup( Template template, bool useUniformWeights = false );
    }

    abstract class PopulationOptimizerBase
    {
        internal List<Optimizer.Weights> OptimizeVectorSet( Features.Markers markers, Optimizer.Distance distance, Population population, int vectorSetOptimizationRepeatCount = 1 )
        {
            var attempts = new List<Optimizer.Weights>();
            attempts.Clear();
            for( var repeat = 0; repeat < vectorSetOptimizationRepeatCount; repeat++ )
            {
                Executor.Queue( () => attempts.Add( Optimizer.DEOptimizer.Instance.Optimize( markers, population, distance ) ) );
            }
            Executor.Complete();
            return attempts;
        }

        internal void DetermineBestDistanceMeasure( IEnumerable<Optimizer.Weights> attempts, Optimizer.Distance distance, Population population, out int bestIndex, out double bestDistance )
        {
            var bestidx = 0;
            var bestdist = double.MinValue;
            var index = 0;

            attempts.Select( a =>
            {
                var d = population.DistanceMeasure( new Optimizer.Distance( distance.Type, Population.DistanceMeasureType.Maximum ), a );
                if( d > bestdist )
                {
                    bestdist = d;
                    bestidx = index;
                }
                ++index;
                return 0;
            } ).Count();

            bestIndex = bestidx;
            bestDistance = bestdist;
        }
    }
}
