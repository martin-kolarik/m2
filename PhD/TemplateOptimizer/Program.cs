using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Accord.Statistics.Analysis;
using DE = DifferentialEvolution;

namespace TemplateOptimizer
{
    class Program
    {
        static void MainXXX( string[] args )
        {
            var experiment = new Experiment();
        }

        static void Main( string[] args )
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
            var result = experiment.Run();

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
            result = experiment.Run();

            Executor.Stop();
        }
    }
}
