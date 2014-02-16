using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using DE = DifferentialEvolution;

namespace TemplateOptimizer
{
    class DEAdapter
    {
        private Population Population;
        private int DEType;
        private int DEPopulationCount;
        private int DEIterationCount;
        private Distance Distance;

        public DEAdapter( Population population, int deType, int dePopulationCount, int deIterationCount, Distance distance )
        {
            this.Population = population;
            DEType = deType;
            DEPopulationCount = dePopulationCount;
            DEIterationCount = deIterationCount;
            Distance = distance;
        }

        public DE.InputStructure InputStructure
        {
            get
            {
                var count = this.Population.ComponentCount;
                var inputStructure = new DE.InputStructure();

                inputStructure.F_VTR = double.MinValue; // Lower bound on the objective function
                inputStructure.I_D = count; // number of parameters to optimize

                inputStructure.I_bnd_constr = true; // bound by lower and upper limits
                inputStructure.FVr_minbound = new double[count]; // lower limit
                inputStructure.FVr_maxbound = new double[count];
                for( int i = 0; i < count; i++ )
                {
                    inputStructure.FVr_minbound[i] = 0.0;
                    inputStructure.FVr_maxbound[i] = 1.0;
                }

                inputStructure.I_NP = DEPopulationCount;
                inputStructure.I_itermax = DEIterationCount;
                inputStructure.F_weight = 0.85;
                inputStructure.F_CR = 1;
                inputStructure.I_strategy = DEType;
                inputStructure.I_refresh = 0;

                inputStructure.FVr_bestmem = new double[count];
                inputStructure.FM_pop = new double[count, count];

                return inputStructure;
            }
        }

        public DE.DifferentialEvolution.FunctionPointer Objective
        {
            get
            {
                return new DE.DifferentialEvolution.FunctionPointer( ObjectiveFunction );
            }
        }

        private DE.OutputFunction ObjectiveFunction( double[] parameters, DE.InputStructure S_In )
        {
            var weights = new Weights( parameters, Weights.NormalizationMode.Weigh );

            DE.OutputFunction result = new DE.OutputFunction( 0, 1 );
            result.FVr_oa = new double[1] { -this.Population.Distance( Distance, weights ) }; // it is a minimizer

            return result;
        }
    }
}
