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
        IPopulationOptimizer PopulationOptimizer { get; }
        void Optimize( IEnumerable<Entity> entities, int repeatCount, IEnumerable<ProbeEntity> probes );
        void PushDumpedContent( CSVDumper dumper, IEnumerable<Entity> entities, string extendedSpecification = null );
    }

    abstract class AnalysisBase
    {
        internal void Prepare( IEnumerable<Entity> entities, Lookup.Population.NormalizationType normalization, out Features.Markers markers, out Population population )
        {
            population = new Population( new Population( entities ), normalization );

            var valueMarkers = entities.First().Markers.Where( m1 => m1 is IValueMarker ).Select( m2 => (IValueMarker)m2 );
            markers = new Features.Markers();
            markers.AddMarkers( valueMarkers );

            var constants = population.DetermineConstantComponents();
            foreach( var constant in constants )
            {
                markers.SetConstant( constant, true );
                markers.SetActive( constant, false );
            }
        }
    }
}
