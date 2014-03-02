using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace TemplateOptimizer.Experiments
{
    static class RandomVariablesComparison
    {
        public static bool HasRun
        {
            get { return true; }
        }

        public static void Execute( string fileMark, int numberOfVariables, int repeatCount, Distance distance, bool dumpIndividuals = true, bool dumpGrouped = true )
        {
            if( HasRun )
            {
                return;
            }
            VariablesUnitGainAndVariance( fileMark, numberOfVariables, repeatCount, distance, dumpIndividuals, dumpGrouped );
            VariablesVaryingGain( fileMark, numberOfVariables, repeatCount, distance, dumpIndividuals, dumpGrouped );
            VariablesVaryingVariance( fileMark, numberOfVariables, repeatCount, distance, dumpIndividuals, dumpGrouped );
        }

        private static void VariablesUnitGainAndVariance( string fileMark, int numberOfComponents, int repeatCount, Distance distance, bool dumpInvidivuals = true, bool dumpGrouped = true )
        {
            // variables, permutted types, normalized values
            CSVDumper dumper;
            List<ExperimentResult> results;

            results = new List<ExperimentResult>();
            foreach( var permutation in ComponentType.RandomNormal.Permutation() )
            {
                for( var repeat = 0; repeat < repeatCount; repeat++ )
                {
                    var parameters = new ExperimentParameters();
                    parameters.DistanceTypes = new Distance[] { distance };
                    parameters.DERuns = 5;
                    parameters.ComponentCount = numberOfComponents;
                    parameters.Components = new ComponentDefinition[] { new ComponentDefinition( permutation.Item1 ), new ComponentDefinition( permutation.Item2 ) };

                    var lrepeat = repeat; // prepare closure
                    new Experiment( parameters ).Run( ( result ) =>
                    {
                        result.SetAuxiliaryData( "repeat", lrepeat );
                        results.Add( result );
                        if( dumpInvidivuals )
                        {
                            dumper = new CSVDumper( result );
                            dumper.Dump( fileMark, numberOfComponents.ToString() + " random variables, unit gain", "", ExperimentType.FewRandomVariablesUnitGainAndVariance, true, true );
                        }
                    } );
                }
            }
            Experiment.Complete();

            if( dumpGrouped )
            {
                dumper = new CSVDumper();
                dumper.Dump( fileMark, numberOfComponents.ToString() + " random variables, unit gain, comparison", "", ExperimentType.FewRandomVariablesUnitGainAndVariance, false, false, ( d ) =>
                {
                    var CS = dumper.CellSeparator;

                    d.Cell( "parameters" );
                    int index = 1;
                    foreach( var result in results )
                    {
                        d.Cell( "result " + ( index++ ).ToString() );
                        d.DumpParameters( result );
                    }

                    index = 1;
                    d.CellsE( "result", results.Select( ( r ) => ( index++ ).ToString() + " " + String.Join( ", ", r.Parameters.Components.Select( ( c ) => c.Type.ToString() ) ) ) );

                    PrintDistances( d, results );
                    PrintWeights( d, results );
                } );
            }
        }

        private static void VariablesVaryingGain( string fileMark, int numberOfComponents, int repeatCount, Distance distance, bool dumpInvidivuals = true, bool dumpGrouped = true )
        {
            // variables, permutted types, scaled values
            CSVDumper dumper;
            List<ExperimentResult> results;

            var coefficient = Math.Pow( 2.0, 1.0/3.0 );
            foreach( var permutation in ComponentType.RandomNormal.Permutation() )
            {
                if( permutation.Item1 == ComponentType.RandomUniform || permutation.Item2 == ComponentType.RandomUniform ) // uniform distribution has no gain
                {
                    continue;
                }

                results = new List<ExperimentResult>();
                for( var repeat = 0; repeat < repeatCount; repeat++ )
                {
                    var gain = 1.0;
                    while( gain <= 130 )
                    {
                        var parameters = new ExperimentParameters();
                        parameters.DistanceTypes = new Distance[] { distance };
                        parameters.DERuns = 5;
                        parameters.ComponentCount = numberOfComponents;
                        if( permutation.Item1 == ComponentType.RandomWeibull ) // for Weibull/Exponential, E(x) = 1/Lambda so let's invert gain
                        {
                            parameters.Components = new ComponentDefinition[] { new ComponentDefinition( permutation.Item1 ), new ComponentDefinition( permutation.Item2, 1.0 / gain ) };
                        }
                        else
                        {
                            parameters.Components = new ComponentDefinition[] { new ComponentDefinition( permutation.Item1 ), new ComponentDefinition( permutation.Item2, gain ) };
                        }

                        var lrepeat = repeat; // prepare closure
                        var lgain = gain; // prepare closure
                        new Experiment( parameters ).Run( ( result ) =>
                        {
                            result.SetAuxiliaryData( "repeat", lrepeat );
                            result.SetAuxiliaryData( "gain", lgain );
                            results.Add( result );

                            if( dumpInvidivuals )
                            {
                                dumper = new CSVDumper( result );
                                dumper.Dump( fileMark, numberOfComponents.ToString() + " random variables, variable gain", "", ExperimentType.FewRandomVariablesVaryingGain, true, true, ( d ) =>
                                {
                                    d.Cell( "GAIN" );
                                    d.Cell( lgain.ToString( "G2" ) );
                                } );
                            }
                        } );

                        gain *= coefficient;
                    }
                }
                Experiment.Complete();

                if( dumpGrouped )
                {
                    var sorted = results.OrderBy( ( result ) => (double)result.GetAuxiliaryData( "gain" ) );

                    dumper = new CSVDumper();
                    dumper.Dump( fileMark, numberOfComponents.ToString() + " random variables, variable gain", "Comparison by gain", ExperimentType.FewRandomVariablesVaryingGain, false, false, ( d ) =>
                    {
                        var CS = dumper.CellSeparator;

                        d.Cell( "parameters" );
                        int index = 1;
                        foreach( var result in results )
                        {
                            d.Cell( "result " + ( index++ ).ToString() );
                            d.DumpParameters( result );
                        }

                        index = 1;
                        d.CellsE( "result", sorted.Select( ( r ) => ( index++ ).ToString() + " " + String.Join( ", ", r.Parameters.Components.Select( ( c ) => c.Type.ToString() ) ) ) );
                        d.CellsE( "gain", sorted.Select( ( r ) => r.GetAuxiliaryData( "gain" ).ToString() ) );

                        PrintDistances( d, sorted );
                        PrintWeights( d, sorted );
                    } );
                }
            }
        }

        private static void VariablesVaryingVariance( string fileMark, int numberOfComponents, int repeatCount, Distance distance, bool dumpInvidivuals = true, bool dumpGrouped = true )
        {
            // permutted types, scaled values
            CSVDumper dumper;
            List<ExperimentResult> results;

            var coefficient = Math.Pow( 2.0, 1.0/3.0 );
            foreach( var permutation in ComponentType.RandomNormal.Permutation() )
            {
                if( permutation.Item1 == ComponentType.RandomPearson || permutation.Item2 == ComponentType.RandomPearson || permutation.Item1 == ComponentType.RandomWeibull || permutation.Item2 == ComponentType.RandomWeibull ) // Pearson has no second parameter, Weibull's second parameter does not change variance
                {
                    continue;
                }

                results = new List<ExperimentResult>();
                for( var repeat = 0; repeat < repeatCount; repeat++ )
                {
                    var variance = 1.0;
                    while( variance <= 130 )
                    {
                        var parameters = new ExperimentParameters();
                        parameters.DistanceTypes = new Distance[] { distance };
                        parameters.DERuns = 5;
                        parameters.ComponentCount = numberOfComponents;
                        parameters.Components = new ComponentDefinition[] { new ComponentDefinition( permutation.Item1 ), new ComponentDefinition( permutation.Item2, 1.0, variance ) };

                        var lrepeat = repeat; // prepare closure
                        var lvariance = variance; // prepare closure
                        new Experiment( parameters ).Run( ( result ) =>
                        {
                            result.SetAuxiliaryData( "repeat", lrepeat );
                            result.SetAuxiliaryData( "variance", lvariance );
                            results.Add( result );

                            if( dumpInvidivuals )
                            {
                                dumper = new CSVDumper( result );
                                dumper.Dump( fileMark, numberOfComponents.ToString() + " random variables, variable variance", "", ExperimentType.FewRandomVariablesVaryingVariance, true, true, ( d ) =>
                                {
                                    d.Cell( "VARIANCE" );
                                    d.Cell( lvariance.ToString( "G2" ) );
                                } );
                            }
                        } );

                        variance *= coefficient;
                    }
                }
                Experiment.Complete();

                if( dumpGrouped )
                {
                    var sorted = results.OrderBy( ( result ) => (double)result.GetAuxiliaryData( "variance" ) );

                    dumper = new CSVDumper();
                    dumper.Dump( fileMark, numberOfComponents.ToString() + " random variables, variable variance", "Comparison by variance", ExperimentType.FewRandomVariablesVaryingVariance, false, false, ( d ) =>
                    {
                        var CS = dumper.CellSeparator;

                        d.Cell( "parameters" );
                        int index = 1;
                        foreach( var result in results )
                        {
                            d.Cell( "result " + ( index++ ).ToString() );
                            d.DumpParameters( result );
                        }

                        index = 1;
                        d.CellsE( "result", sorted.Select( ( r ) => ( index++ ).ToString() + " " + String.Join( ", ", r.Parameters.Components.Select( ( c ) => c.Type.ToString() ) ) ) );
                        d.CellsE( "variance", sorted.Select( ( r ) => r.GetAuxiliaryData( "variance" ).ToString() ) );

                        PrintDistances( d, sorted );
                        PrintWeights( d, sorted );
                    } );
                }
            }
        }

        private static void PrintDistances( CSVDumper.CSVParticularResultDumper d, IEnumerable<ExperimentResult> results )
        {
            d.Cell( "distances" );
            d.CellsE( "D plain", results.Select( ( r ) => r.PlainDistances.First().Value.ToString() ) );
            d.CellsE( "D PCA", results.Select( ( r ) => r.PCADistances.First().Value.ToString() ) );
            d.CellsE( "D DE (avg)", results.Select( ( r ) => r.DEResults.Select( ( der ) => der.DEDistance ).Average().ToString() ) );
            d.CellsE( "D PCA ratio", results.Select( ( r ) => ( r.PCADistances.First().Value / r.PlainDistances.First().Value ).ToString() ) );
            d.CellsE( "D DE (avg) ratio", results.Select( ( r ) => ( r.DEResults.Select( ( der ) => der.DEDistance ).Average() / r.PlainDistances.First().Value ).ToString() ) );
        }

        private static void PrintWeights( CSVDumper.CSVParticularResultDumper d, IEnumerable<ExperimentResult> results )
        {
            int index;
            var CS = d.CellSeparator;

            d.CellsE( "weights", results.Select( ( r ) =>
            {
                index = 1;
                return String.Join( CS, r.Parameters.Components.Select( ( c ) => c.Type.ToString() + " (" + ( index++ ).ToString() + ")" ) );
            } ) );
            d.CellsE( "W PCA", results.Select( ( r ) => String.Join( CS, r.PCAWeights.Components ) ) );
            var avgWeightsPreResultPerComponent = new List<object>();
            foreach( var result in results )
            {
                for( var component = 0; component < results.First().Parameters.ComponentCount; component++ )
                {
                    avgWeightsPreResultPerComponent.Add( result.DEResults.Select( ( der ) => der.DEWeights[component] ).Average() );
                }
            }
            d.CellsE( "W DE (avg)", avgWeightsPreResultPerComponent );
        }
    }
}
