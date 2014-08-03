using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer
{
    interface IAnalysis
    {
        void Analyze( IEnumerable<Entity> entities );
        void Dump( CSVDumper dumper, IEnumerable<Entity> entities );
    }
}
