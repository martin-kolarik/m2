using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer.Lookup
{
    class ProbeEntity : Entity
    {
        public ProbeEntity( Entity related, DataSource.SourceType source, IList<Event> events ) :
            base( related == null ? "unk" : related.Id, source, events )
        {
            Related = related;
        }

        public Entity Related { get; private set; }

        public IEnumerable<Tuple<Entity, double>> UnoptimizedCandidates { get; private set; }
        public Entity ClosestUnoptimized { get { return UnoptimizedCandidates.First().Item1; } }
        public double DistanceUnoptimized { get { return UnoptimizedCandidates.First().Item2; } }

        public IEnumerable<Tuple<Entity, double>> OptimizedCandidates { get; private set; }
        public Entity ClosestOptimized { get { return OptimizedCandidates.First().Item1; } }
        public double DistanceOptimized { get { return OptimizedCandidates.First().Item2; } }

        public void TestMatch( IPopulationOptimizer populationOptimizer )
        {
            UnoptimizedCandidates = populationOptimizer.Lookup( new Lookup.Template( this ), true );
            OptimizedCandidates = populationOptimizer.Lookup( new Lookup.Template( this ) );
        }
    }
}
