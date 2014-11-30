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
            var CFG_ENV = DataSource.EnvironmentType.ControlledPlain;
            var CFG_SOURCE = DataSource.SourceType.DRV;
            var CFG_END_STROKE_GAP = 100;
            var CFG_FRACTIONS = 1;
            var CFG_FRACTION = SplitDefinition.RANDOM;

            var DESCRIPTION_STRING =
                "env: " + CFG_ENV.ToString() + 
                ", source: " + CFG_SOURCE.ToString() + 
                ", endgap: " + CFG_END_STROKE_GAP.ToString(); // ", without L/M/H",

            var entities = DataSources.Get( CFG_ENV, CFG_SOURCE );

            var dumper = new CSVDumper();
            dumper.AddContent( "OVERVIEW " + DESCRIPTION_STRING, (d) => {} );

            var split = new SplitDefinition()
            {
                Fractions = CFG_FRACTIONS,
                Fraction = CFG_FRACTION
            };
            var analyzer = new Analysis.StrokePopulationAnalysis( CFG_END_STROKE_GAP );
            analyzer.Analyze( entities, split );
            analyzer.Optimize( entities );
            analyzer.PushDumpedContent( dumper, entities );

            dumper.Dump( outputFileNameHint == "" ? "s-o" : outputFileNameHint );
        }

        #endregion
    }
}
