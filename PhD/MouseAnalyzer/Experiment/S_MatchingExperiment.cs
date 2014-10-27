using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer.Experiment
{
    class S_MatchingExperiment : IExperiment
    {

        #region IExperiment Members

        public void Perform( string outputFileNameHint = "" )
        {
            var entities = DataSources.Get( DataSource.EnvironmentType.ControlledPlain, DataSource.SourceType.API );
            var dumper = new CSVDumper();

            var analyzer = new Analysis.StrokeMatchingAnalysis();
            analyzer.Analyze( entities, null );
            analyzer.Optimize( entities );
            analyzer.PushDumpedContent( dumper, entities );

            // dumper.Dump( outputFileNameHint == "" ? "s-m" : outputFileNameHint );
        }

        #endregion
    }
}
