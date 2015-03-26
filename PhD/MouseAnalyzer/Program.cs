using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using MouseAnalyzer.Lookup;

namespace MouseAnalyzer
{
    class Program
    {
        static void Main( string[] args )
        {
            // prepare environment
            System.Threading.Thread.CurrentThread.CurrentCulture = System.Globalization.CultureInfo.InvariantCulture;

            // experiments
            // new Experiment.TK_FARExperiment().Perform();
            // new Experiment.K_HistogramExperiment().Perform();
            // new Experiment.TK_OverviewExperiment().Perform();
            // new Experiment.StatisticsTestExperiment().Perform();
            // new Experiment.S_MatchingExperiment().Perform();
            // new Experiment.SmoothingExperiment().Perform();
            // new Experiment.SplineDistributionExperiment().Perform();
            // new Experiment.RootFinderExperiment().Perform();

            new Experiment.S_OverviewExperiment().Perform();

            // var exp0 = new Experiment.S_FARExperiment( true, false, false );
            // exp0.Perform();

            /*
            var exp1 = new Experiment.S_FARExperiment( true, false, false );
            exp1.Perform();
            exp1 = null;
            GC.Collect();
            GC.Collect();
            */

            /*
            var exp2 = new Experiment.S_FARExperiment( false, false, true );
            exp2.Perform();
             */

            // cleanup statics
            Executor.Stop();
        }
    }
}
