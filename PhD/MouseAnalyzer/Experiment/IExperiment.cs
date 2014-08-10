using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer.Experiment
{
    interface IExperiment
    {
        void Perform( string outputFileNameHint = "" );
    }
}
