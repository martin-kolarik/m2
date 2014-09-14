using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using MouseAnalyzer.Features;

namespace MouseAnalyzer.Optimizer
{
    interface IVectorSetOptimizer
    {
        Weights Optimize( Markers markers, Lookup.Population population, Distance distance );
    }
}
