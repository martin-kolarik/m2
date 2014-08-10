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
            new Experiment.TK_FARExperiment().Perform();
            // new Experiment.K_HistogramExperiment().Perform();

            // cleanup statics
            Executor.Stop();
        }
    }
}
