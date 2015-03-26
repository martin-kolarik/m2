using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace TemplateOptimizer.Experiments
{
    static class ManyRandomVariables
    {
        public static bool HasRun
        {
            get { return true; }
        }

        public enum Variant
        {
            All,
            Optimized
        }

        public static void Execute( string fileMark, Variant variant, int numberOfVariables, int repeatCount, bool dumpIndividuals = true, bool dumpGrouped = true )
        {
            if( HasRun )
            {
                return;
            }

            SingleAmongMany( fileMark, variant, numberOfVariables, repeatCount, dumpIndividuals, dumpGrouped );
            HalfOfType( fileMark, variant, numberOfVariables, repeatCount, dumpIndividuals, dumpGrouped );
        }

        private static void SingleAmongMany( string fileMark, Variant variant, int numberOfComponents, int repeatCount, bool dumpInvidivuals = true, bool dumpGrouped = true )
        {
            // variables, permutted types, scaled values
            CSVDumper dumper;
            List<ExperimentResult> results = new List<ExperimentResult>();

            var coefficient = Math.Pow( 3.0, 1.0/1.0 );
            foreach( var permutation in ComponentType.RandomNormal.Permutation( true ) )
            {
                for( var repeat = 0; repeat < repeatCount; repeat++ )
                {
                    var gain = 1.0;
                    while( gain <= (variant == Variant.All ? 130.0 : 10.0 ))
                    {
                        var parameters = new ExperimentParameters();
                        parameters.ComponentCount = numberOfComponents;
                        parameters.Normalization = Population.NormalizationType.Center;

                        if( variant == Variant.All )
                        {
                            parameters.DistanceTypes = Distance.Permutation;
                            parameters.DERuns = 3;
                        }
                        else
                        {
                            parameters.DistanceTypes = new Distance[] { new Distance( Population.DistanceProcessing.MinimumTimesMedian ) };
                            parameters.DETypes = new int[] { 3 };
                            parameters.DECrossoverProbabilities = new double[] { numberOfComponents < 60 ? 0.25 : 0.5 };
                            parameters.DEWeights = new double[] { 1.0 };
                            parameters.DEPopulationCounts = new int[] { 150 };
                            parameters.DEIterationCounts = new int[] { 175 };
                            parameters.DERuns = 5;
                        }

                        ComponentDefinition c1;
                        // adjust what is needed according to component type
                        switch( permutation.Item1 )
                        {
                            case ComponentType.RandomNormal:
                            case ComponentType.RandomUniform:
                                c1 = new ComponentDefinition( permutation.Item1, 0.0, gain );
                                break;
                            case ComponentType.RandomWeibull:
                                c1 = new ComponentDefinition( permutation.Item1, 1.0 / gain );
                                break;
                            default:
                                c1 = new ComponentDefinition( permutation.Item1, gain );
                                break;
                        }
                        var definitions = new ComponentDefinition[] { c1, new ComponentDefinition( permutation.Item2 ) };
                        parameters.Components = definitions;

                        var lpermutation = permutation;
                        var lrepeat = repeat; // prepare closure
                        var lgain = gain; // prepare closure
                        var experiment = new Experiment( parameters );
                        experiment.Run( ( result ) =>
                        {
                            result.SetAuxiliaryData( "permutation", lpermutation );
                            result.SetAuxiliaryData( "repeat", lrepeat );
                            result.SetAuxiliaryData( "gain", lgain );
                            results.Add( result );

                            if( dumpInvidivuals )
                            {
                                dumper = new CSVDumper( result );
                                dumper.Dump( "i" + fileMark, numberOfComponents.ToString() + " random variables, variable gain", "", ExperimentType.SingleAmongManyVaryingGain, true, true, ( d ) =>
                                {
                                    d.Cell( "GAIN" );
                                    d.Cell( lgain.ToString( "G2" ) );
                                } );
                            }
                        } );

                        if( variant == Variant.All )
                        {
                            parameters = new ExperimentParameters();
                            parameters.DistanceTypes = Distance.Permutation;
                            parameters.DERuns = 3;
                            parameters.ComponentCount = numberOfComponents;
                            parameters.Normalization = Population.NormalizationType.Standard;
                            parameters.Components = definitions;
                            new Experiment( parameters, experiment.Population ).Run( ( result ) =>
                            {
                                result.SetAuxiliaryData( "permutation", lpermutation );
                                result.SetAuxiliaryData( "repeat", lrepeat );
                                result.SetAuxiliaryData( "gain", lgain );
                                results.Add( result );

                                if( dumpInvidivuals )
                                {
                                    dumper = new CSVDumper( result );
                                    dumper.Dump( "i" + fileMark, numberOfComponents.ToString() + " random variables, variable gain", "", ExperimentType.SingleAmongManyVaryingGain, true, true, ( d ) =>
                                    {
                                        d.Cell( "GAIN" );
                                        d.Cell( lgain.ToString( "G2" ) );
                                    } );
                                }
                            } );
                        }

                        gain *= coefficient;
                    }
                }
            }
            Experiment.Complete();

            if( dumpGrouped )
            {
                var sorted = results.OrderBy( ( result ) => (double)result.GetAuxiliaryData( "gain" ) );

                dumper = new CSVDumper();
                dumper.Dump( "g" + fileMark, numberOfComponents.ToString() + " random variables, variable gain", "Comparison by gain, distance type and variable type", ExperimentType.SingleAmongManyVaryingGain, false, false, ( d ) =>
                {
                    var CS = dumper.CellSeparator;

                    // parameters
                    d.Cell( "parameters" );
                    d.DumpParameters( results.First() );

                    PrintDistances( d, sorted );
                    PrintWeights( d, sorted );
                } );
            }
        }

        private static void HalfOfType( string fileMark, Variant variant, int numberOfComponents, int repeatCount, bool dumpInvidivuals = true, bool dumpGrouped = true )
        {
            // variables, permutted types, scaled values
            CSVDumper dumper;
            List<ExperimentResult> results = new List<ExperimentResult>();

            var coefficient = Math.Pow( 3.0, 1.0/1.0 );
            foreach( var permutation in ComponentType.RandomNormal.Permutation( true ) )
            {
                for( var repeat = 0; repeat < repeatCount; repeat++ )
                {
                    var gain = 1.0;
                    while( gain <= ( variant == Variant.All ? 130.0 : 10.0 ) )
                    {
                        var parameters = new ExperimentParameters();
                        parameters.Normalization = Population.NormalizationType.Center;
                        parameters.ComponentCount = numberOfComponents;

                        if( variant == Variant.All )
                        {
                            parameters.DistanceTypes = Distance.Permutation;
                            parameters.DERuns = 3;
                        }
                        else
                        {
                            parameters.DistanceTypes = new Distance[] { new Distance( Population.DistanceProcessing.MinimumTimesMedian ) };
                            parameters.DETypes = new int[] { 3 };
                            parameters.DECrossoverProbabilities = new double[] { numberOfComponents < 60 ? 0.25 : 0.5 };
                            parameters.DEWeights = new double[] { 1.0 };
                            parameters.DEPopulationCounts = new int[] { 150 };
                            parameters.DEIterationCounts = new int[] { 175 };
                            parameters.DERuns = 5;
                        }

                        // first half is filled with the same definition, second half is filled only once and then mechanism using the last defined
                        // component (when populating a population) is left to work
                        var halfCount = numberOfComponents / 2;
                        var definitions = new ComponentDefinition[halfCount + 1];
                        // adjust what is needed according to component type
                        ComponentDefinition definition;
                        switch( permutation.Item1 )
                        {
                            case ComponentType.RandomNormal:
                            case ComponentType.RandomUniform:
                                definition = new ComponentDefinition( permutation.Item1, 0.0, gain );
                                break;
                            case ComponentType.RandomWeibull:
                                definition = new ComponentDefinition( permutation.Item1, 1.0 / gain );
                                break;
                            default:
                                definition = new ComponentDefinition( permutation.Item1, gain );
                                break;
                        }
                        for( var defi = 0; defi < halfCount; defi++ )
                        {
                            definitions[defi] = definition;
                        }
                        definitions[halfCount] = new ComponentDefinition( permutation.Item2 );
                        parameters.Components = definitions;

                        var lpermutation = permutation;
                        var lrepeat = repeat; // prepare closure
                        var lgain = gain; // prepare closure
                        var experiment = new Experiment( parameters );
                        experiment.Run( ( result ) =>
                        {
                            result.SetAuxiliaryData( "permutation", lpermutation );
                            result.SetAuxiliaryData( "repeat", lrepeat );
                            result.SetAuxiliaryData( "gain", lgain );
                            results.Add( result );

                            if( dumpInvidivuals )
                            {
                                dumper = new CSVDumper( result );
                                dumper.Dump( "i" + fileMark, numberOfComponents.ToString() + " random variables, variable gain", "", ExperimentType.SingleAmongManyVaryingGain, true, true, ( d ) =>
                                {
                                    d.Cell( "GAIN" );
                                    d.Cell( lgain.ToString( "G2" ) );
                                } );
                            }
                        } );

                        if( variant == Variant.All )
                        {
                            parameters = new ExperimentParameters();
                            parameters.DistanceTypes = Distance.Permutation;
                            parameters.DERuns = 3;
                            parameters.ComponentCount = numberOfComponents;
                            parameters.Normalization = Population.NormalizationType.Standard;
                            parameters.Components = definitions;
                            new Experiment( parameters, experiment.Population ).Run( ( result ) =>
                            {
                                result.SetAuxiliaryData( "permutation", lpermutation );
                                result.SetAuxiliaryData( "repeat", lrepeat );
                                result.SetAuxiliaryData( "gain", lgain );
                                results.Add( result );

                                if( dumpInvidivuals )
                                {
                                    dumper = new CSVDumper( result );
                                    dumper.Dump( "i" + fileMark, numberOfComponents.ToString() + " random variables, variable gain", "", ExperimentType.SingleAmongManyVaryingGain, true, true, ( d ) =>
                                    {
                                        d.Cell( "GAIN" );
                                        d.Cell( lgain.ToString( "G2" ) );
                                    } );
                                }
                            } );
                        }

                        gain *= coefficient;
                    }
                }
            }
            Experiment.Complete();

            if( dumpGrouped )
            {
                var sorted = results.OrderBy( ( result ) => (double)result.GetAuxiliaryData( "gain" ) );

                dumper = new CSVDumper();
                dumper.Dump( "g" + fileMark, numberOfComponents.ToString() + " random variables, variable gain", "Comparison by gain, distance type and variable type", ExperimentType.SingleAmongManyVaryingGain, false, false, ( d ) =>
                {
                    var CS = dumper.CellSeparator;

                    // parameters
                    d.Cell( "parameters" );
                    d.DumpParameters( results.First() );

                    PrintDistances( d, sorted );
                    PrintWeights( d, sorted );
                } );
            }
        }

        private static void PrintDistances( CSVDumper.CSVParticularResultDumper d, IEnumerable<ExperimentResult> results )
        {
            // distance type x gain for variable type
            foreach( var permutation in ComponentType.RandomNormal.Permutation() )
            {
                d.Cell( "distances", permutation.ToString() + " (many)" );
                d.CellsVA( "gain", 1, 3, 9, 27, 81 );

                var filtered = results.Where( ( r ) => r.GetAuxiliaryData( "permutation" ).Equals( permutation ) );
                var centered = filtered.Where( ( r ) => r.Parameters.Normalization == Population.NormalizationType.Center );
                var standardized = filtered.Where( ( r ) => r.Parameters.Normalization == Population.NormalizationType.Standard );

                foreach( var distance in results.First().Parameters.DistanceTypes )
                {
                    d.CellsE( "D plain [C] " + distance.ToString(), centered.Select( ( r ) => r.PlainDistances[distance].ToString( "G5" ) ) );
                    if (standardized.Count() > 0 ) d.CellsE( "D plain [S] " + distance.ToString(), standardized.Select( ( r ) => r.PlainDistances[distance].ToString( "G5" ) ) );
                    d.CellsE( "D PCA [C] " + distance.ToString(), centered.Select( ( r ) => r.PCADistances[distance].ToString( "G5" ) ) );
                    if( standardized.Count() > 0 ) d.CellsE( "D PCA [S] " + distance.ToString(), standardized.Select( ( r ) => r.PCADistances[distance].ToString( "G5" ) ) );
                    d.CellsE( "D DE (min)[C] " + distance.ToString(), centered.Select( ( r ) => r.DEResults.Where( ( der ) => der.Distance.Equals( distance ) ).Select( ( der ) => der.DEDistance ).Min().ToString( "G5" ) ) );
                    if( standardized.Count() > 0 ) d.CellsE( "D DE (min)[S] " + distance.ToString(), standardized.Select( ( r ) => r.DEResults.Where( ( der ) => der.Distance.Equals( distance ) ).Select( ( der ) => der.DEDistance ).Min().ToString( "G5" ) ) );
                    d.CellsE( "D DE (avg)[C] " + distance.ToString(), centered.Select( ( r ) => r.DEResults.Where( ( der ) => der.Distance.Equals( distance ) ).Select( ( der ) => der.DEDistance ).Average().ToString( "G5" ) ) );
                    if( standardized.Count() > 0 ) d.CellsE( "D DE (avg)[S] " + distance.ToString(), standardized.Select( ( r ) => r.DEResults.Where( ( der ) => der.Distance.Equals( distance ) ).Select( ( der ) => der.DEDistance ).Average().ToString( "G5" ) ) );
                    d.CellsE( "D DE (max)[C] " + distance.ToString(), centered.Select( ( r ) => r.DEResults.Where( ( der ) => der.Distance.Equals( distance ) ).Select( ( der ) => der.DEDistance ).Max().ToString( "G5" ) ) );
                    if( standardized.Count() > 0 ) d.CellsE( "D DE (max)[S] " + distance.ToString(), standardized.Select( ( r ) => r.DEResults.Where( ( der ) => der.Distance.Equals( distance ) ).Select( ( der ) => der.DEDistance ).Max().ToString( "G5" ) ) );
                    d.CellsE( "D PCA/D plain [C] " + distance.ToString(), centered.Select( ( r ) => ( r.PCADistances[distance] / r.PlainDistances[distance] ).ToString( "G5" ) ) );
                    d.CellsE( "D DE (avg)/D plain[C] " + distance.ToString(), centered.Select( ( r ) => ( r.DEResults.Where( ( der ) => der.Distance.Equals( distance ) ).Select( ( der ) => der.DEDistance ).Average() / r.PlainDistances[distance] ).ToString( "G5" ) ) );
                    d.CellsE( "D DE (avg)/D PCA[C] " + distance.ToString(), centered.Select( ( r ) => ( r.DEResults.Where( ( der ) => der.Distance.Equals( distance ) ).Select( ( der ) => der.DEDistance ).Average() / r.PCADistances[distance] ).ToString( "G5" ) ) );
                }
            }
        }

        private static void PrintWeights( CSVDumper.CSVParticularResultDumper d, IEnumerable<ExperimentResult> results )
        {
            var CS = d.CellSeparator;

            foreach( var result in results )
            {
                d.Cell( "weights", result.GetAuxiliaryData( "permutation" ) );
                d.CellsVA( "gain", result.GetAuxiliaryData( "gain" ), "normalization", result.Parameters.Normalization );

                int index = 1;
                d.CellsE( "component" + CS + CS + CS + CS + CS, result.PCAWeights.Components.Select( (c) => (object)(index++) ) );

                d.CellsE( "PCA" + CS + CS + CS + CS + CS, result.PCAWeights.Components.Select( ( i ) => i.ToString( "G5" ) ) );

                d.CellsVA( "distance", "dDE", "dDE/dP", "dPCA", "dPCA/dP", "dDE/dPCA", "weights ->" );
                var sorted = result.DEResults.OrderBy( ( der ) => der.DEDistance / result.PlainDistances[der.Distance] );
                foreach( var der in sorted )
                {
                    d.CellsE( String.Join( CS, "DE " + der.Distance.ToString(),
                                               der.DEDistance.ToString( "G5" ),
                                               ( der.DEDistance / result.PlainDistances[der.Distance] ).ToString( "G5" ),
                                               result.PCADistances[der.Distance],
                                               ( result.PCADistances[der.Distance] / result.PlainDistances[der.Distance] ).ToString( "G5" ),
                                               ( der.DEDistance / result.PCADistances[der.Distance] ).ToString( "G5" ) ),
                              der.DEWeights.Components.Select( ( i ) => i.ToString( "G5" ) ) );
                }
            }
        }
    }
}
