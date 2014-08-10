using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer.Experiment
{
    class TK_FARExperiment : IExperiment
    {

        #region IExperiment Members

        public void Perform( string outputFileNameHint = "" )
        {
            var fractions = 1;
            var probeAttempts = 10;
            var probeFractions = 2;

            var entities = DataSources.Get( DataSource.EnvironmentType.ControlledPlain, DataSource.SourceType.UEF );
            var probes = new List<Lookup.ProbeEntity>();
            foreach( var entity in entities )
            {
                for( var probeAttempt = 0; probeAttempt < probeAttempts; probeAttempt++ )
                {
                    probes.Add( new Lookup.ProbeEntity( entity, DataSource.SourceType.UEF, entity.Events ) );
                }
            }

            var dumper = new CSVDumper();

            var split = new SplitDefinition()
            {
                Fractions = fractions
            };

            var analyzer = new Analysis.TimeKinematicsAnalysis();
            analyzer.Analyze( entities, split );
            analyzer.Optimize( entities, 20 );
            analyzer.PushDumpedContent( dumper, entities );

            var probesSplit = new SplitDefinition()
            {
                Fractions = probeFractions
            };
            var probesAnalyzer = new Analysis.TimeKinematicsAnalysis();
            probesAnalyzer.Analyze( probes, probesSplit );

            foreach( var probe in probes )
            {
                probe.TestMatch( analyzer.Population );
            }
            dumper.AddContent( "Matches", d =>
            {
                var count = (double)probes.Count();
                var farUnoptimized = probes.Where( p => p.Related.Id != p.ClosestUnoptimized.Id ).Count() / count;
                var farOptimized = probes.Where( p => p.Related.Id != p.ClosestOptimized.Id ).Count() / count;
                d.CellsVA( false, "overall U", farUnoptimized );
                d.CellsVA( false, "overall O", farOptimized );

                var ids = probes.Select( p => p.Related.Id ).Distinct();
                var idsCount = (double)ids.Count();
                foreach( var id in ids )
                {
                    var farIdUnoptimized = probes.Where( p => p.Related.Id == id && p.ClosestUnoptimized.Id != id ).Count() / count * idsCount;
                    var farIdOptimized = probes.Where( p => p.Related.Id == id && p.ClosestOptimized.Id != id ).Count() / count * idsCount;

                    d.CellsVA( false, id + " U", farIdUnoptimized );
                    d.CellsVA( false, id + " O", farIdOptimized );
                }

                foreach( var probe in probes )
                {
                    d.CellsE( probe.Related.Id + "U", false, probe.UnoptimizedCandidates.Select( c => (object)c.Item1.Id + " " + c.Item2.ToString( "G5" ) ) );
                    d.CellsE( probe.Related.Id + "O", false, probe.OptimizedCandidates.Select( c => (object)c.Item1.Id + " " + c.Item2.ToString( "G5" ) ) );
                }
            }
            );

            dumper.Dump( outputFileNameHint == "" ? "tk-f" : outputFileNameHint );
        }

        #endregion
    }
}
