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
            BestAfterOmitBadsLinearyCombinedAllDistancesMoreDERuns,
            RedundantDuplicatedComponents,
            RedundantCombinedComponents
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

            if( variant == Variant.RedundantDuplicatedComponents ||
                variant == Variant.RedundantCombinedComponents )
            {
                parameters.PopulationCount = 30;
                parameters.DistanceTypes = // Distance.Permutation;
                    new Distance[] {
                        new Distance( Template.DistanceType.Euclidean, Population.DistanceProcessing.MinimumTimesMedian )
                };
                parameters.DETypes = new int[] { 3 };
                parameters.DECrossoverProbabilities = new double[] { 0.5 };
                parameters.DEWeights = new double[] { 1.0 };
                parameters.DEPopulationCounts = new int[] { 100 };
                parameters.DEIterationCounts = new int[] { 150 };
                parameters.DERuns = 1000;

            }
            else if( variant == Variant.BestAfterOmitBadsLinearyCombinedAllDistances ||
                variant == Variant.BestAfterOmitBadsLinearyCombinedAllDistancesMoreDERuns )
            {
                parameters.DistanceTypes = // Distance.Permutation;
                    new Distance[] {
                        new Distance( Template.DistanceType.Euclidean, Population.DistanceProcessing.MinimumTimesMedian )
                };
                
                parameters.DETypes = new int[] { 2, 3 };
                parameters.DECrossoverProbabilities = new double[] { numberOfComponents < 60 ? 0.25 : 0.5 };
                parameters.DEWeights = new double[] { 1.0 };
                parameters.DEPopulationCounts = new int[] { 25, 50, 75, 100, 125, 150 };
                parameters.DEIterationCounts = new int[] { 175 };
                parameters.DERuns = variant == Variant.BestAfterOmitBadsLinearyCombinedAllDistancesMoreDERuns ? 30 : 3;
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
            Population populationToCompare = null;

            if( variant == Variant.RedundantCombinedComponents ||
                variant == Variant.RedundantDuplicatedComponents )
            {
                parameters.Components = new ComponentDefinition[] { new ComponentDefinition( ComponentType.RandomNormal, 0.0, 3.0 ) };
                parameters.ComponentCount = 20;

                populationToCompare = Experiment.Populate( parameters );
                population = new Population();

                // make populations the same
                foreach( var source in populationToCompare.Templates )
                {
                    var template = new Template( 30 );

                    int di = 0;
                    for( int i = 0; i < source.ComponentCount; i++ )
                    {
                        if( variant == Variant.RedundantDuplicatedComponents )
                        {
                            template[di++] = source[i];
                            if( i % 2 == 0 )
                            {
                                template[di++] = source[i];
                            }
                        }
                        else
                        {
                            template[di++] = source[i];
                            if( i % 2 == 0 )
                            {
                                var pair = i / 2;
                                template[di++] = ( 1+pair )*0.1*source[i] + ( 10-pair )*0.1*source[i+1];
                            }
                        }
                    }

                    population.AddTemplate( template );
                }
            }
            else if( variant == Variant.BestAfterOmitBadsLinearyCombinedAllDistances ||
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

            new Experiment( parameters, population, populationToCompare ).Run( ( result ) =>
            {
                results.Add( result );
                if( dumpInvidivuals )
                {
                    result.SetAuxiliaryData( "id", id++ );

                    dumper = new CSVDumper( result );
                    dumper.Dump( "i" + fileMark, "Differential evolution variants", "", experimentType, true, true, ( d ) =>
                    {
                        d.Cell( "id", id );

                        // transpose data to columns
                        var bestdistance = result.DEResults.Max( der => der.DEDistance );
                        var sortedResults = result.DEResults.OrderBy( der => der.Type ).ThenBy( der => der.PopulationCount ).ThenBy( der => der.DEDistance );

                        var quartileCaptions = new List<string>() { "all q0", "all q1", "all q2", "all q3", "all q4" };
                        for( var t = 0; t < parameters.DETypes.Count(); t++ )
                        {
                            var tt = parameters.DETypes[t];
                            quartileCaptions.Add( "t" + tt.ToString() + " q0" );
                            quartileCaptions.Add( "t" + tt.ToString() + " q1" );
                            quartileCaptions.Add( "t" + tt.ToString() + " q2" );
                            quartileCaptions.Add( "t" + tt.ToString() + " q3" );
                            quartileCaptions.Add( "t" + tt.ToString() + " q4" );
                        }
                        for( var p = 0; p < parameters.DEPopulationCounts.Count(); p++ )
                        {
                            var pp = parameters.DEPopulationCounts[p];
                            quartileCaptions.Add( "p" + pp.ToString() + " q0" );
                            quartileCaptions.Add( "p" + pp.ToString() + " q1" );
                            quartileCaptions.Add( "p" + pp.ToString() + " q2" );
                            quartileCaptions.Add( "p" + pp.ToString() + " q3" );
                            quartileCaptions.Add( "p" + pp.ToString() + " q4" );
                        }
                        for( var t = 0; t < parameters.DETypes.Count(); t++ )
                        {
                            for( var p = 0; p < parameters.DEPopulationCounts.Count(); p++ )
                            {
                                var tt = parameters.DETypes[t];
                                var pp = parameters.DEPopulationCounts[p];
                                quartileCaptions.Add( "t" + tt.ToString() + " p" + pp.ToString() + " q0" );
                                quartileCaptions.Add( "t" + tt.ToString() + " p" + pp.ToString() + " q1" );
                                quartileCaptions.Add( "t" + tt.ToString() + " p" + pp.ToString() + " q2" );
                                quartileCaptions.Add( "t" + tt.ToString() + " p" + pp.ToString() + " q3" );
                                quartileCaptions.Add( "t" + tt.ToString() + " p" + pp.ToString() + " q4" );
                            }
                        }

                        var resultCount = sortedResults.Count();
                        var iterations = new List<List<double>>( parameters.DEIterationCounts[0] );
                        var quartiles = new List<List<double>>( parameters.DEIterationCounts[0] );
                        for( var i = 1; i < parameters.DEIterationCounts[0]; i++ )
                        {
                            // iterations development
                            var iterationList = new List<double>();
                            iterations.Add( iterationList );

                            foreach( var deResult in sortedResults )
                            {
                                iterationList.Add( 1.0 + deResult.DEDistanceDevelop[i] / bestdistance ); // normalize it by the best result
                            }

                            // count quartiles
                            var quartileList = new List<double>( 5 ); // quartiles are five
                            quartiles.Add( quartileList );
                            // all
                            AddQuartiles( ref quartileList, iterationList );
                            // types
                            for( var t = 0; t < parameters.DETypes.Count(); t++ )
                            {
                                iterationList = new List<double>();
                                foreach( var deResult in sortedResults.Where( sr => sr.Type == parameters.DETypes[t] ) )
                                {
                                    iterationList.Add( 1.0 + deResult.DEDistanceDevelop[i] / bestdistance ); // normalize it by the best result
                                }
                                AddQuartiles( ref quartileList, iterationList );
                            }
                            // populations
                            for( var p = 0; p < parameters.DEPopulationCounts.Count(); p++ )
                            {
                                iterationList = new List<double>();
                                foreach( var deResult in sortedResults.Where( sr => sr.PopulationCount == parameters.DEPopulationCounts[p] ) )
                                {
                                    iterationList.Add( 1.0 + deResult.DEDistanceDevelop[i] / bestdistance ); // normalize it by the best result
                                }
                                AddQuartiles( ref quartileList, iterationList );
                            }
                            // types & populations
                            for( var t = 0; t < parameters.DETypes.Count(); t++ )
                            {
                                for( var p = 0; p < parameters.DEPopulationCounts.Count(); p++ )
                                {
                                    iterationList = new List<double>();
                                    foreach( var deResult in sortedResults.Where( sr => sr.Type == parameters.DETypes[t] && sr.PopulationCount == parameters.DEPopulationCounts[p] ) )
                                    {
                                        iterationList.Add( 1.0 + deResult.DEDistanceDevelop[i] / bestdistance ); // normalize it by the best result
                                    }
                                    AddQuartiles( ref quartileList, iterationList );
                                }
                            }
                        }

                        d.Cell( "iterations in DE run" );
                        d.CellsE( "distance", sortedResults.Select( der => (object)der.DEDistance ) );
                        d.CellsE( "type", sortedResults.Select( der => (object)der.Type ) );
                        d.CellsE( "population", sortedResults.Select( der => (object)der.PopulationCount ) );

                        for( var i = 0; i < parameters.DEIterationCounts[0]-1; i++ )
                        {
                            d.CellsE( i.ToString(), iterations[i].Select( it => (object)it ) );
                        }

                        d.Cell( "quartiles for DE run" );
                        d.CellsE( "iteration", quartileCaptions );
                        for( var i = 0; i < parameters.DEIterationCounts[0]-1; i++ )
                        {
                            d.CellsE( i.ToString(), quartiles[i].Select( it => (object)it ) );
                        }

                    } );
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

        private static void AddQuartiles( ref List<double> quartileList, IEnumerable<double> source )
        {
            var sorted = source.OrderBy( item => item );
            var count = source.Count();
            for( var q = 0; q < 5; q++ )
            {
                if( q==0 )
                {
                    quartileList.Add( sorted.First() );
                }
                else if( q==4 )
                {
                    quartileList.Add( sorted.Last() );
                }
                else
                {
                    quartileList.Add( sorted.Skip( q*count/4 ).First() );
                }
            }
        }
    }
}
