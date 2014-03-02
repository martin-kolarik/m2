using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace TemplateOptimizer.Experiments
{
    static class DEExamination
    {
        public static bool HasRun
        {
            get
            {
                return false;
            }
        }

        public static void Execute( string fileMark, int numberOfVariables, int populationSize, bool dumpIndividuals = true, bool dumpGrouped = true )
        {
            DEVariants( fileMark, numberOfVariables, populationSize, dumpIndividuals, dumpGrouped );
        }

        private static void DEVariants( string fileMark, int numberOfComponents, int populationSize, bool dumpInvidivuals = true, bool dumpGrouped = true )
        {
            CSVDumper dumper;
            List<ExperimentResult> results = new List<ExperimentResult>();
            int id = 1;

            var parameters = new ExperimentParameters();
            // parameters.DistanceTypes, use default EUCL(AVG)
            parameters.ComponentCount = numberOfComponents;
            parameters.PopulationCount = populationSize;
            parameters.DETypes = new int[] { 1, 2, 3, 4, 5, 6 };
            parameters.DECrossoverProbabilities = new double[] { 0.5, 0.75, 1.0 };
            parameters.DEWeights = new double[] { 0.75, 0.85, 0.95 };
            parameters.DEPopulationCounts = new int[] { 5, 10, 20, 40, 75, 100 };
            parameters.DEIterationCounts = new int[] { 5, 10, 20, 40, 75, 100 };
            parameters.DERuns = 3;
            parameters.Components = new ComponentDefinition[] { new ComponentDefinition( ComponentType.RandomNormal ) };

            new Experiment( parameters ).Run( ( result ) =>
            {
                results.Add( result );
                if( dumpInvidivuals )
                {
                    result.SetAuxiliaryData( "id", id++ );

                    dumper = new CSVDumper( result );
                    dumper.Dump( fileMark, "Differential evolution variants", "", ExperimentType.DEVariants, true, true, ( d ) => d.Cell( "id", id ) );
                }
            } );
            Experiment.Complete();

            if( dumpGrouped )
            {
                dumper = new CSVDumper();
                dumper.Dump( fileMark, "Ordered by maximal distances", "", ExperimentType.DEVariants, false, false, ( d ) =>
                {
                    // sorted
                    d.CellsE( "by weight", results.OrderBy( ( r ) => r.DEResults.Max( ( der ) => der.DEDistance ) ).Select( ( r ) => r.GetAuxiliaryData( "id" ) ) );
                } );
            }
        }
    }
}
