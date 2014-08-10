using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using MouseAnalyzer.Lookup;
using DE = DifferentialEvolution;

namespace MouseAnalyzer.Optimizer
{
    static class DEOptimizer
    {
        public static Weights Optimize( Population population, Distance distance )
        {
            var deAdapter = new DEAdapter( population, 3, 0.5, 1.0, 150, 150, distance );
            var de = new DE.DifferentialEvolution( deAdapter.Objective );

            var deOutput = de.Optimizer( deAdapter.InputStructure );
            var bestObjective = -deOutput.S_bestval.FVr_oa[0];
            var bestWeights = new Weights( deOutput.FVr_bestmem, Weights.NormalizationMode.Weigh );

            return bestWeights;
        }

        public static Weights Optimize( IEnumerable<Entity> entities, Distance distance )
        {
            return Optimize( new Population( entities ), distance );
        }
    }
}
