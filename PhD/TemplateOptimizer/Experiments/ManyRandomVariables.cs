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
            get
            {
                return false;
            }
        }

        public static void Execute( string fileMark, int numberOfVariables, int repeatCount, bool dumpIndividuals = true, bool dumpGrouped = true )
        {
            SingleAmongMany( fileMark, numberOfVariables, repeatCount, dumpIndividuals, dumpGrouped );
            HalfOfType( fileMark, numberOfVariables, repeatCount, dumpIndividuals, dumpGrouped );
        }

        private static void SingleAmongMany( string fileMark, int numberOfComponents, int repeatCount, bool dumpInvidivuals = true, bool dumpGrouped = true )
        {
            // variables, permutted types, scaled values
            CSVDumper dumper;
            List<ExperimentResult> results = new List<ExperimentResult>();

            var coefficient = Math.Pow( 2.0, 1.0/3.0 );
            foreach( var permutation in ComponentType.RandomNormal.Permutation() )
            {
                for( var repeat = 0; repeat < repeatCount; repeat++ )
                {
                    var gain = 1.0;
                    while( gain <= 130 )
                    {
                        var parameters = new ExperimentParameters();
                        parameters.DistanceTypes = Distance.Permutation;
                        parameters.DERuns = 5;
                        parameters.ComponentCount = numberOfComponents;

                        ComponentDefinition c1;
                        // adjust what is needed according to component type
                        switch( permutation.Item1 )
                        {
                            case ComponentType.RandomWeibull:
                                c1 = new ComponentDefinition( permutation.Item1, 1.0 / gain );
                                break;
                            case ComponentType.RandomUniform:
                                c1 = new ComponentDefinition( permutation.Item1, 0.0, gain );
                                break;
                            default:
                                c1 = new ComponentDefinition( permutation.Item1, gain );
                                break;
                        }
                        parameters.Components = new ComponentDefinition[] { c1, new ComponentDefinition( permutation.Item2 ) };

                        var lpermutation = permutation;
                        var lrepeat = repeat; // prepare closure
                        var lgain = gain; // prepare closure
                        new Experiment( parameters ).Run( ( result ) =>
                        {
                            result.SetAuxiliaryData( "permutation", lpermutation );
                            result.SetAuxiliaryData( "repeat", lrepeat );
                            result.SetAuxiliaryData( "gain", lgain );
                            results.Add( result );

                            if( dumpInvidivuals )
                            {
                                dumper = new CSVDumper( result );
                                dumper.Dump( fileMark, numberOfComponents.ToString() + " random variables, variable gain", "", ExperimentType.SingleAmongManyVaryingGain, true, true, ( d ) =>
                                {
                                    d.Cell( "GAIN" );
                                    d.Cell( lgain.ToString( "G2" ) );
                                } );
                            }
                        } );

                        gain *= coefficient;
                    }
                }
            }
            Experiment.Complete();

            if( dumpGrouped )
            {
                var sorted = results.OrderBy( ( result ) => (double)result.GetAuxiliaryData( "gain" ) );

                dumper = new CSVDumper();
                dumper.Dump( fileMark, numberOfComponents.ToString() + " random variables, variable gain", "Comparison by gain, distance type and variable type", ExperimentType.SingleAmongManyVaryingGain, false, false, ( d ) =>
                {
                    var CS = dumper.CellSeparator;

                    // parameters
                    d.Cell( "parameters" );
                    d.DumpParameters( results.First() );

                    // distance type x gain for variable type
                    foreach( var permutation in ComponentType.RandomNormal.Permutation() )
                    {
                        d.Cell( permutation.ToString() + " (many)" );
                        var filtered = sorted.Where( ( r ) => r.GetAuxiliaryData( "permutation" ) == permutation );
                        foreach( var distance in Distance.Permutation )
                        {
                            d.CellsE( "D plain " + distance.ToString(), filtered.Select( ( r ) => (object)r.PlainDistances[distance] ) );
                            d.CellsE( "D PCA " + distance.ToString(), filtered.Select( ( r ) => (object)r.PCADistances[distance] ) );
                            d.CellsE( "D DE (avg)" + distance.ToString(), filtered.Select( ( r ) => (object)r.DEResults.Where( ( der ) => der.Distance == distance ).Select( ( der ) => der.DEDistance ).Average() ) );
                        }
                    }
                } );
            }
        }

        private static void HalfOfType( string fileMark, int numberOfComponents, int repeatCount, bool dumpInvidivuals = true, bool dumpGrouped = true )
        {
            // variables, permutted types, scaled values
            CSVDumper dumper;
            List<ExperimentResult> results = new List<ExperimentResult>();

            var coefficient = Math.Pow( 2.0, 1.0/3.0 );
            foreach( var permutation in ComponentType.RandomNormal.Permutation() )
            {
                for( var repeat = 0; repeat < repeatCount; repeat++ )
                {
                    var gain = 1.0;
                    while( gain <= 130 )
                    {
                        var parameters = new ExperimentParameters();
                        parameters.DistanceTypes = Distance.Permutation;
                        parameters.DERuns = 5;
                        parameters.ComponentCount = numberOfComponents;

                        // first half is filled with the same definition, second half is filled only once and then mechanism using the last defined
                        // component (when populating a population) is left to work
                        var halfCount = numberOfComponents / 2;
                        var definitions = new ComponentDefinition[halfCount + 1];
                        // adjust what is needed according to component type
                        ComponentDefinition definition;
                        switch( permutation.Item1 )
                        {
                            case ComponentType.RandomWeibull:
                                definition = new ComponentDefinition( permutation.Item1, 1.0 / gain );
                                break;
                            case ComponentType.RandomUniform:
                                definition = new ComponentDefinition( permutation.Item1, 0.0, gain );
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
                        new Experiment( parameters ).Run( ( result ) =>
                        {
                            result.SetAuxiliaryData( "permutation", lpermutation );
                            result.SetAuxiliaryData( "repeat", lrepeat );
                            result.SetAuxiliaryData( "gain", lgain );
                            results.Add( result );

                            if( dumpInvidivuals )
                            {
                                dumper = new CSVDumper( result );
                                dumper.Dump( fileMark, numberOfComponents.ToString() + " random variables, variable gain", "", ExperimentType.SingleAmongManyVaryingGain, true, true, ( d ) =>
                                {
                                    d.Cell( "GAIN" );
                                    d.Cell( lgain.ToString( "G2" ) );
                                } );
                            }
                        } );

                        gain *= coefficient;
                    }
                }
            }
            Experiment.Complete();

            if( dumpGrouped )
            {
                var sorted = results.OrderBy( ( result ) => (double)result.GetAuxiliaryData( "gain" ) );

                dumper = new CSVDumper();
                dumper.Dump( fileMark, numberOfComponents.ToString() + " random variables, variable gain", "Comparison by gain, distance type and variable type", ExperimentType.SingleAmongManyVaryingGain, false, false, ( d ) =>
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
                d.Cell( permutation.ToString() + " (many)" );
                var filtered = results.Where( ( r ) => r.GetAuxiliaryData( "permutation" ) == permutation );
                foreach( var distance in Distance.Permutation )
                {
                    d.CellsE( "D plain " + distance.ToString(), filtered.Select( ( r ) => (object)r.PlainDistances[distance] ) );
                    d.CellsE( "D PCA " + distance.ToString(), filtered.Select( ( r ) => (object)r.PCADistances[distance] ) );
                    d.CellsE( "D DE (avg)" + distance.ToString(), filtered.Select( ( r ) => (object)r.DEResults.Where( ( der ) => der.Distance == distance ).Select( ( der ) => der.DEDistance ).Average() ) );
                }
            }
        }

        private static void PrintWeights( CSVDumper.CSVParticularResultDumper d, IEnumerable<ExperimentResult> results )
        {
            foreach( var result in results )
            {
                d.Cell( "components", result.GetAuxiliaryData( "permutation" ) );
                d.Cell( "gain", result.GetAuxiliaryData( "gain" ) );
                d.Cell( "run", result.GetAuxiliaryData( "run" ) );

                d.CellsE( "PCA", result.PCAWeights.Components.Cast<object>() );
                for( var dei = 0; dei < result.DEResults.Count; dei++ )
                {
                    d.CellsE( "DE" + dei.ToString(), result.DEResults[dei].DEWeights.Components.Cast<object>() );
                }
            }
        }
    }
}
