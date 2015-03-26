using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using MouseAnalyzer.Features;
using MouseAnalyzer.Lookup;
using DE = DifferentialEvolution;

namespace MouseAnalyzer.Optimizer
{
    class DEOptimizer : IVectorSetOptimizer
    {
        private static IVectorSetOptimizer instance;
        public static IVectorSetOptimizer Instance {
            get
            {
                if( instance == null )
                {
                    instance = new DEOptimizer();
                }
                return instance;
            }
        }

        public Weights Optimize( Markers markers, Population population, Distance distance )
        {
            var deAdapter = new DEAdapter( markers, population, 3, 0.25, 1.0, 100, 150, distance );
            var de = new DE.DifferentialEvolution( deAdapter.Objective );

            var deOutput = de.Optimizer( deAdapter.InputStructure );
            var bestObjective = -deOutput.S_bestval.FVr_oa[0];
            var bestWeights = markers.ExpandFromActive( new Weights( deOutput.FVr_bestmem ) );

            return bestWeights;
        }
    }
}
