using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using MouseAnalyzer.Lookup;
using MouseAnalyzer.Optimizer;

namespace MouseAnalyzer
{
    class SplitDefinition
    {
        public static int RANDOM = 0;
        public int Fractions { get; set; }
        public int Fraction { get; set; }

        public SplitDefinition()
        {
            Fraction = RANDOM;
        }

        public static IEnumerable<Event> Split( SplitDefinition split, IEnumerable<Event> events )
        {
            if( split == null )
            {
                return events;
            }

            var from = 0;
            var eventsCount = events.Count();
            var length = eventsCount;
            if( split != null )
            {
                length = length / split.Fractions;
                from = from == SplitDefinition.RANDOM ?
                        random.Next( eventsCount - length ) :
                        split.Fraction * length;
            }

            return from == 0 && length == eventsCount ?
                   events :
                   events.Skip( from ).Take( length );
        }

        private static Random random = new Random( new object().GetHashCode() );
    }

    interface IAnalysis
    {
        void Analyze( IEnumerable<Entity> entities, SplitDefinition split = null );
        void Optimize( IEnumerable<Entity> entities, int repeatCount = 1, bool reweight = false );
        OptimizedPopulation Population { get; }
        void PushDumpedContent( CSVDumper dumper, IEnumerable<Entity> entities, string extendedSpecification = null );
    }

    abstract class AnalysisBase
    {
        public void Optimize( IEnumerable<Entity> entities, int repeatCount = 1, bool reweight = false )
        {
            var distance = new Distance( Lookup.Population.DistanceProcessing.MinimumTimesMedian );

            var denormalized = new Population( entities );
            Population = new OptimizedPopulation( denormalized, Lookup.Population.NormalizationType.Unite );
            Population.Optimize( distance, repeatCount );
            Population.ComputeMask( reweight );

            if( reweight )
            {
                Population.Optimize( distance );
            }
        }

        public OptimizedPopulation Population { get; private set; }
    }
}
