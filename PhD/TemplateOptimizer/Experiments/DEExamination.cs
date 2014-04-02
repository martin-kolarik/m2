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
            get { return false; }
        }

        public enum Variant
        {
            BruteForce,
            OmitBads,
            BestAfterOmitBadsRandom,
            BestAfterOmitBadsLinearyCombined,
            BestAfterOmitBadsLinearyCombinedAllDistances,
            BestAfterOmitBadsLinearyCombinedAllDistancesMoreDERuns
        }

        public static void Execute( string fileMark, int numberOfVariables, int populationSize, Variant variant, bool dumpIndividuals = true, bool dumpGrouped = true )
        {
            if( HasRun )
            {
                return;
            }

            DEVariants( fileMark, numberOfVariables, populationSize, variant, dumpIndividuals, dumpGrouped );
        }

        private static void DEVariants( string fileMark, int numberOfComponents, int populationSize, Variant variant, bool dumpInvidivuals, bool dumpGrouped )
        {
            CSVDumper dumper;
            List<ExperimentResult> results = new List<ExperimentResult>();
            int id = 1;

            var parameters = new ExperimentParameters();
            parameters.ComponentCount = numberOfComponents;
            parameters.PopulationCount = populationSize;

            if( variant == Variant.BestAfterOmitBadsLinearyCombinedAllDistances ||
                variant == Variant.BestAfterOmitBadsLinearyCombinedAllDistancesMoreDERuns )
            {
                parameters.DistanceTypes = Distance.Permutation;
                parameters.DETypes = new int[] { 3 };
                parameters.DECrossoverProbabilities = new double[] { numberOfComponents < 60 ? 0.25 : 0.5 };
                parameters.DEWeights = new double[] { 1.0 };
                parameters.DEPopulationCounts = new int[] { 150 };
                parameters.DEIterationCounts = new int[] { 175 };
                parameters.DERuns = variant == Variant.BestAfterOmitBadsLinearyCombinedAllDistancesMoreDERuns ? 10 : 3;
            }
            else if( variant == Variant.BestAfterOmitBadsLinearyCombined )
            {
                parameters.DistanceTypes = new Distance[] { new Distance( Population.DistanceProcessing.MinimumTimesMedian ) };
                parameters.DETypes = new int[] { 3 };
                parameters.DECrossoverProbabilities = new double[] { 0.25, 0.5 };
                parameters.DEWeights = new double[] { 1.0 };
                parameters.DEPopulationCounts = new int[] { 150 };
                parameters.DEIterationCounts = new int[] { 175 };
                parameters.DERuns = 16;
            }
            else if( variant == Variant.BestAfterOmitBadsRandom )
            {
                parameters.DistanceTypes = new Distance[] { new Distance( Population.DistanceProcessing.MinimumTimesMedian ) };
                parameters.DETypes = new int[] { 3 };
                parameters.DECrossoverProbabilities = new double[] { 0.1, 0.25, 0.5 };
                parameters.DEWeights = new double[] { 1.0 };
                parameters.DEPopulationCounts = new int[] { 150 };
                parameters.DEIterationCounts = new int[] { 150, 175 };
                parameters.DERuns = 6;
            }
            else if( variant == Variant.OmitBads )
            {
                parameters.DistanceTypes = new Distance[] { new Distance( Population.DistanceProcessing.MinimumTimesMedian ) };
                parameters.DETypes = new int[] { 2, 3 };
                parameters.DECrossoverProbabilities = new double[] { 0.25, 0.5 };
                parameters.DEWeights = new double[] { 0.85, 1.0, 1.2 };
                parameters.DEPopulationCounts = new int[] { 100, 125, 150 };
                parameters.DEIterationCounts = new int[] { 100, 125, 150 };
                parameters.DERuns = 3;
            }
            else if( variant == Variant.BruteForce )
            {
                // parameters.DistanceTypes = new Distance[] { new Distance(), new Distance( Population.DistanceProcessing.MinimumTimesMedian ), new Distance( Population.DistanceProcessing.Median ) };
                parameters.DistanceTypes = new Distance[] { new Distance( Population.DistanceProcessing.Minimum ) };
                parameters.DETypes = new int[] { 1, 2, 3, 4, 5, 6 };
                parameters.DECrossoverProbabilities = new double[] { 0.25, 0.5, 0.75, 1.0 };
                parameters.DEWeights = new double[] { 0.5, 0.85, 1.0, 1.2, 1.5 };
                parameters.DEPopulationCounts = new int[] { 10, 30, 50, 75, 100, 125, 150 };
                parameters.DEIterationCounts = new int[] { 10, 30, 50, 75, 100, 125, 150 };
                parameters.DERuns = 2;
            }
            else
            {
                throw new Exception();
            }

            Population population = null;
            if( variant == Variant.BestAfterOmitBadsLinearyCombinedAllDistances ||
                variant == Variant.BestAfterOmitBadsLinearyCombined ||
                variant == Variant.BestAfterOmitBadsRandom )
            {
                var cn15 = new ComponentDefinition( ComponentType.RandomNormal, 0.0, 15.0 );
                var cn10 = new ComponentDefinition( ComponentType.RandomNormal, 0.0, 10.0 );
                var cn5 = new ComponentDefinition( ComponentType.RandomNormal, 0.0, 5.0 );
                var cwb5 = new ComponentDefinition( ComponentType.RandomWeibull, 0.0, 0.2 );
                var cwb10 = new ComponentDefinition( ComponentType.RandomWeibull, 0.0, 0.1 );
                var cw5 = new ComponentDefinition( ComponentType.RandomWeibull, 0.0, 5.0 );
                var cu10 = new ComponentDefinition( ComponentType.RandomUniform, 0.0, 10.0 );
                var cu5 = new ComponentDefinition( ComponentType.RandomUniform, 0.0, 5.0 );
                var cu1 = new ComponentDefinition( ComponentType.RandomUniform );
                var cp1 = new ComponentDefinition( ComponentType.RandomPearson, 1 );
                var cp10 = new ComponentDefinition( ComponentType.RandomPearson, 10 );
                parameters.Components = new ComponentDefinition[] {
                cu10, cp10, cwb10, cn10, cu5, cwb5, cn5, cn5, cn5, cwb5, cw5, cu1, cp1,
                new ComponentDefinition( ComponentType.RandomNormal ) };

                if( variant == Variant.BestAfterOmitBadsLinearyCombined )
                {
                    population = Experiment.Populate( parameters );

                    // create combined components
                    foreach( var template in population.Templates )
                    {
                        var src1 = 2;
                        var src2 = 1;
                        var dst1 = template.ComponentCount-1;
                        var dst2 = template.ComponentCount-2;
                        template[dst1] = template[src1];
                        template[dst2] = 0.5 * template[src1] + 0.5 * template[src2];
                    }
                }
            }
            else
            {
                var cn15 = new ComponentDefinition( ComponentType.RandomNormal, 0.0, 15.0 );
                var cn10 = new ComponentDefinition( ComponentType.RandomNormal, 0.0, 10.0 );
                var cn5 = new ComponentDefinition( ComponentType.RandomNormal, 0.0, 5.0 );
                var cwb5 = new ComponentDefinition( ComponentType.RandomWeibull, 0.0, 0.2 );
                var cw5 = new ComponentDefinition( ComponentType.RandomWeibull, 0.0, 5.0 );
                var cu10 = new ComponentDefinition( ComponentType.RandomUniform, 0.0, 10.0 );
                var cu5 = new ComponentDefinition( ComponentType.RandomUniform, 0.0, 5.0 );
                var cu1 = new ComponentDefinition( ComponentType.RandomUniform );
                parameters.Components = new ComponentDefinition[] {
                cn15, cu10, cn10, cn10, cn10, cu5, cwb5, cw5, cn5, cn5, cn5, cn5, cn5, cn5, cn5, cwb5, cw5, cu1,
                new ComponentDefinition( ComponentType.RandomNormal ) };
            }

            var experimentType = variant == Variant.BestAfterOmitBadsLinearyCombinedAllDistances || variant == Variant.BestAfterOmitBadsLinearyCombinedAllDistancesMoreDERuns ? ExperimentType.DEVariantsOfDistances : ExperimentType.DEVariants;

            new Experiment( parameters, population ).Run( ( result ) =>
            {
                results.Add( result );
                if( dumpInvidivuals )
                {
                    result.SetAuxiliaryData( "id", id++ );

                    dumper = new CSVDumper( result );
                    dumper.Dump( "i" + fileMark, "Differential evolution variants", "", experimentType, true, true, ( d ) => d.Cell( "id", id ) );
                }
            } );
            Experiment.Complete();

            if( dumpGrouped )
            {
                dumper = new CSVDumper();
                dumper.Dump( "g" + fileMark, "Ordered by maximal distances", "", experimentType, false, false, ( d ) =>
                {
                    // sorted
                    d.CellsE( "by weight", results.OrderBy( ( r ) => r.DEResults.Max( ( der ) => der.DEDistance ) ).Select( ( r ) => r.GetAuxiliaryData( "id" ) ) );
                } );
            }
        }
    }
}
