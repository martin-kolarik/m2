using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Accord.Statistics.Analysis;
using DE = DifferentialEvolution;

namespace TemplateOptimizer
{
    class Program
    {
        static void Main( string[] args )
        {
            Thread.CurrentThread.CurrentCulture = System.Globalization.CultureInfo.InvariantCulture;

            Experiments();

            Executor.Stop();
        }

        static void Experiments()
        {
            TwoRandomVariablesUnitGain( false );
            TwoRandomVariablesVaryingGain( false );
        }

        static void TwoRandomVariablesUnitGain( bool dumpInvidivuals = true, bool dumpGrouped = true )
        {
            // two variables, permutted types, normalized values
            CSVDumper dumper;
            List<ExperimentResult> results;
            
            results = new List<ExperimentResult>();
            foreach( var permutation in ComponentType.RandomNormal.Permutation() )
            {
                var parameters = new ExperimentParameters();
                parameters.Components = new ComponentDefinition[] { new ComponentDefinition( permutation.Item1 ), new ComponentDefinition( permutation.Item2 ) };
                new Experiment( parameters ).Run( ( result ) =>
                {
                    results.Add( result );
                    if( dumpInvidivuals )
                    {
                        dumper = new CSVDumper( result );
                        dumper.Dump( "Two random variables, unit gain", "", ExperimentType.TwoRandomVariablesUnitGain, true, true );
                    }
                } );
            }
            Experiment.Complete();

            if( dumpGrouped )
            {
                dumper = new CSVDumper();
                dumper.Dump( "Two random variables, unit gain, comparison", "", ExperimentType.TwoRandomVariablesUnitGain, false, false, ( d ) =>
                {
                    var CS = dumper.CellSeparator;
                    d.CellsE( "variables", results.Select( ( r ) => r.Parameters.Components[0].Type.ToString() + " (1)" + CS + r.Parameters.Components[1].Type.ToString() + " (2)" ) );
                    d.Cell( "distances" );
                    d.CellsE( "D plain", results.Select( ( r ) => r.PlainDistances.First().Value.ToString() + CS ) );
                    d.CellsE( "D PCA", results.Select( ( r ) => r.PCADistances.First().Value.ToString() + CS ) );
                    d.CellsE( "D DE (avg)", results.Select( ( r ) => r.DEResults.Select( ( der ) => der.DEDistance ).Average().ToString() + CS ) );
                    d.CellsE( "D PCA ratio", results.Select( ( r ) => ( r.PCADistances.First().Value / r.PlainDistances.First().Value ).ToString() + CS ) );
                    d.CellsE( "D DE (avg) ratio", results.Select( ( r ) => ( r.DEResults.Select( ( der ) => der.DEDistance ).Average() / r.PlainDistances.First().Value ).ToString() + CS ) );
                    d.Cell( "weights" );
                    d.CellsE( "W PCA", results.Select( ( r ) => r.PCAWeights[0].ToString() + CS + r.PCAWeights[1].ToString() ) );
                    d.CellsE( "W DE (avg)", results.Select( ( r ) => r.DEResults.Select( ( der ) => der.DEWeights[0] ).Average() + CS + r.DEResults.Select( ( der ) => der.DEWeights[1] ).Average() ) );
                } );
            }
        }

        static void TwoRandomVariablesVaryingGain( bool dumpInvidivuals = true, bool dumpGrouped = true )
        {
            // two variables, permutted types, scaled values
            CSVDumper dumper;
            List<ExperimentResult> results;

            var scale = 1.0;
            var coefficient = Math.Pow( 2.0, 1.0/3.0 );
            foreach( var permutation in ComponentType.RandomNormal.Permutation() )
            {
                results = new List<ExperimentResult>();
                while( scale <= 130 )
                {
                    var parameters = new ExperimentParameters();
                    parameters.Components = new ComponentDefinition[] { new ComponentDefinition( permutation.Item1, scale, 0.0 ), new ComponentDefinition( permutation.Item2 ) };
                    new Experiment( parameters ).Run( ( result ) =>
                    {
                        var lscale = scale;

                        result.SetAuxiliaryData( "scale", lscale );
                        results.Add( result );

                        if( dumpInvidivuals )
                        {
                            dumper = new CSVDumper( result );
                            dumper.Dump( "Two random variables, variable gain", "", ExperimentType.TwoRandomVariablesVaryingGain, true, true, ( d ) =>
                            {
                                d.Cell( "GAIN" );
                                d.Cell( lscale.ToString( "G2" ) );
                            } );
                        }
                    } );

                    scale *= coefficient;
                }
                Experiment.Complete();

                if( dumpGrouped )
                {
                    dumper = new CSVDumper();
                    dumper.Dump( "Two random variables, variable gain", "Comparison by gain", ExperimentType.TwoRandomVariablesUnitGain, false, false, ( d ) =>
                    {
                        var CS = dumper.CellSeparator;
                        d.CellsVA( "variables", permutation.Item1, permutation.Item2 );
                        d.CellsE( "scale", results.Select( ( r ) => r.GetAuxiliaryData( "scale" ).ToString() + CS ) );
                        d.Cell( "distances" );
                        d.CellsE( "D plain", results.Select( ( r ) => r.PlainDistances.First().Value.ToString() + CS ) );
                        d.CellsE( "D PCA", results.Select( ( r ) => r.PCADistances.First().Value.ToString() + CS ) );
                        d.CellsE( "D DE (avg)", results.Select( ( r ) => r.DEResults.Select( ( der ) => der.DEDistance ).Average().ToString() + CS ) );
                        d.CellsE( "D PCA ratio", results.Select( ( r ) => ( r.PCADistances.First().Value / r.PlainDistances.First().Value ).ToString() + CS ) );
                        d.CellsE( "D DE (avg) ratio", results.Select( ( r ) => ( r.DEResults.Select( ( der ) => der.DEDistance ).Average() / r.PlainDistances.First().Value ).ToString() + CS ) );
                        d.Cell( "weights" );
                        d.CellsE( "W PCA", results.Select( ( r ) => r.PCAWeights[0].ToString() + CS + r.PCAWeights[1].ToString() ) );
                        d.CellsE( "W DE (avg)", results.Select( ( r ) => r.DEResults.Select( ( der ) => der.DEWeights[0] ).Average() + CS + r.DEResults.Select( ( der ) => der.DEWeights[1] ).Average() ) );
                    } );
                }
            }
        }

        static void Tests()
        {
            const int COMPONENT_COUNT = 5;
            var weights = Weights.Uniform( COMPONENT_COUNT );

            //==========
            // test distance computation, dS = 12, dA = 4
            Population population = new Population();
            population.AddTemplate( new Template( new double[] { 0, 0 } ) );
            population.AddTemplate( new Template( new double[] { 3, 0 } ) );
            population.AddTemplate( new Template( new double[] { 3, 4 } ) );

            var weights2 = new Weights( new double[]{ 1, 1 } );
            var dS = population.Distance( new Distance( Population.DistanceProcessing.Summation ), weights2 );
            var dA = population.Distance( new Distance( Population.DistanceProcessing.Average ), weights2 );
            var dG = population.Distance( new Distance( Population.DistanceProcessing.GeometricAverage ), weights2 );

            Population npopulation;
            npopulation = population.Normalize( Population.NormalizationType.Center );
            npopulation = population.Normalize( Population.NormalizationType.Standard );
            npopulation = population.Normalize( Population.NormalizationType.Normalize );

            var pca = new PrincipalComponentAnalysis( new PCAAdapter( npopulation ).Table );
            pca.Compute();

            //==========
            population = new Population();
            population.AddTemplate( new Template( new double[] { 0.3, 0.01, 0.80, 0.5 } ) );
            population.AddTemplate( new Template( new double[] { 0.4, 0.02, 0.10, 0.6 } ) );
            population.AddTemplate( new Template( new double[] { 0.4, 0.03, 0.20, 0.7 } ) );
            population.AddTemplate( new Template( new double[] { 0.4, 0.04, 0.05, 0.8 } ) );
            population.AddTemplate( new Template( new double[] { 0.5, 0.05, 0.02, 0.9 } ) );

            var parameters = new ExperimentParameters() { DERuns = 1 };
            var experiment = new Experiment( parameters, population );
            experiment.Run( ( result ) =>
            {
            } );

            //==========
            population = new Population();
            population.AddTemplate( new Template( new double[] { 0, 1 } ) );
            population.AddTemplate( new Template( new double[] { 1, -1 } ) );
            population.AddTemplate( new Template( new double[] { 2, 1 } ) );
            population.AddTemplate( new Template( new double[] { 3, -1 } ) );
            population.AddTemplate( new Template( new double[] { 4, 1 } ) );
            population.AddTemplate( new Template( new double[] { 5, -1 } ) );
            population.AddTemplate( new Template( new double[] { 6, 1 } ) );
            population.AddTemplate( new Template( new double[] { 7, -1 } ) );
            population.AddTemplate( new Template( new double[] { 8, 1 } ) );

            npopulation = population.Normalize( Population.NormalizationType.Standard );

            pca = new PrincipalComponentAnalysis( new PCAAdapter( npopulation ).Table );
            pca.Compute();

            //==========
            PopulationCreator creator = new PopulationCreator( 75, COMPONENT_COUNT,
                ( component ) =>
                {
                    // return new ComponentDefinition( component < 2 ? ComponentType.RandomWeibull : ComponentType.RandomNormal, 1, component < 2 ? 1 : 0.1 );
                    return new ComponentDefinition( ComponentType.RandomNormal, 1, component < 2 ? 5 : 0.1 );
                }
            );
            population = creator.Populate();

            parameters = new ExperimentParameters()
            {
                DistanceTypes = new Distance[] {
                    new Distance( Template.DistanceType.Manhattan ),
                    new Distance( Population.DistanceProcessing.Average ),
                    new Distance( Population.DistanceProcessing.Minimum ),
                    new Distance( Population.DistanceProcessing.Median ),
                    new Distance( Population.DistanceProcessing.MinimumTimesMedian )
                }
            };
            experiment = new Experiment( parameters, population );
            experiment.Run( ( result ) =>
            {
                var avgmed = result.DEResults.Where( r => r.Distance.Item2 == Population.DistanceProcessing.Median ).Select( r => r.DEDistance ).Average();
            } );

        }
    }
}
