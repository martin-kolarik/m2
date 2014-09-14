using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer.Experiment
{
    class S_OverviewExperiment : IExperiment
    {

        #region IExperiment Members

        public void Perform( string outputFileNameHint = "" )
        {
            var fractions = 1;
            var probeAttempts = 5;
            var probeFractions = 20;

            var entities = DataSources.Get( DataSource.EnvironmentType.ControlledPlain, DataSource.SourceType.API );
            var probes = new List<Lookup.ProbeEntity>();
            foreach( var entity in entities )
            {
                for( var probeAttempt = 0; probeAttempt < probeAttempts; probeAttempt++ )
                {
                    probes.Add( new Lookup.ProbeEntity( entity, DataSource.SourceType.API, entity.Events ) );
                }
            }

            var dumper = new CSVDumper();

            var probesSplit = new SplitDefinition()
            {
                Fractions = probeFractions
            };
            var probesAnalyzer = new Analysis.StrokeAnalysis();
            probesAnalyzer.Analyze( probes, probesSplit );

            var split = new SplitDefinition()
            {
                Fractions = fractions
            };
            var analyzer = new Analysis.StrokeAnalysis();
            analyzer.Analyze( entities, split );
            analyzer.Optimize( entities, 5, probes );
            analyzer.PushDumpedContent( dumper, entities );

            foreach( var probe in probes )
            {
                probe.TestMatch( analyzer.PopulationOptimizer );
            }
            dumper.AddContent( "Matches", d =>
            {
                var count = (double)probes.Count();
                var farUnoptimized = probes.Where( p => p.Related.Id != p.ClosestUnoptimized.Id ).Count() / count;
                var farOptimized = probes.Where( p => p.Related.Id != p.ClosestOptimized.Id ).Count() / count;
                d.CellsVA( false, "U overall", farUnoptimized );
                d.CellsVA( false, "O overall", farOptimized );

                var ids = probes.Select( p => p.Related.Id ).Distinct();
                var idsCount = (double)ids.Count();

                // unoptimized
                foreach( var id in ids )
                {
                    var farIdUnoptimized = probes.Where( p => p.Related.Id == id && p.ClosestUnoptimized.Id != id ).Count() / count * idsCount;
                    d.CellsVA( false, "U" + id, farIdUnoptimized );
                }
                foreach( var probe in probes )
                {
                    var first = probe.UnoptimizedCandidates.First().Item2;
                    d.CellsE( "U" + probe.Related.Id, false, probe.UnoptimizedCandidates.Select( c => (object)c.Item1.Id + " " + c.Item2.ToString( "G4" ) + " [" + ( c.Item2/first ).ToString( "G2" ) + "]" ) );
                }

                // optimized
                foreach( var id in ids )
                {
                    var farIdOptimized = probes.Where( p => p.Related.Id == id && p.ClosestOptimized.Id != id ).Count() / count * idsCount;
                    d.CellsVA( false, "O" + id, farIdOptimized );
                }
                foreach( var probe in probes )
                {
                    var first = probe.OptimizedCandidates.First().Item2;
                    d.CellsE( "O" + probe.Related.Id, false, probe.OptimizedCandidates.Select( c => (object)c.Item1.Id + " " + c.Item2.ToString( "G4" ) + " [" + ( c.Item2/first ).ToString( "G2" ) + "]" ) );
                }
            }
            );

            dumper.Dump( outputFileNameHint == "" ? "s-o" : outputFileNameHint );
        }

        #endregion
    }
}
