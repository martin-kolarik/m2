using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer.Experiment
{
    class K_HistogramExperiment : IExperiment
    {

        #region IExperiment Members

        public void Perform( string outputFileNameHint = "" )
        {
            var dumper = new CSVDumper();

            var entities = DataSources.Get( DataSource.EnvironmentType.ControlledPlain, DataSource.SourceType.UEF );

            var analyzer = new Analysis.KinematicsAnalysis();
            analyzer.Analyze( entities, null );
            analyzer.PushDumpedContent( dumper, entities );

            dumper.Dump( outputFileNameHint == "" ? "k-h" : outputFileNameHint );
        }

        #endregion
    }
}
