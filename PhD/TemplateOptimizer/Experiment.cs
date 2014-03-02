using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Accord.Statistics.Analysis;
using DE = DifferentialEvolution;

namespace TemplateOptimizer
{
    class Experiment
    {
        // private
        private Population Population;
        private ExperimentParameters Parameters;
        private Population NormalizedPopulation;

        public Experiment( ExperimentParameters parameters = null, Population population = null )
        {
            Parameters = parameters != null ? parameters : new ExperimentParameters();
            Population = population != null ? population : new PopulationCreator( Parameters.PopulationCount, Parameters.ComponentCount, ( i ) => GetComponent( i ) ).Populate();
        }

        // executive methods
        public void Run( Action<ExperimentResult> completionHandler )
        {
            NormalizedPopulation = Population.Normalize( Parameters.Normalization );

            var result = new ExperimentResult( Parameters, Population, NormalizedPopulation );
            RunPlain( result );
            RunPCA( result );
            RunDEs( result );
            Executor.ScheduleCompletion( this, () =>
            {
                completionHandler( result );
            } );
        }

        public static void Complete()
        {
            Executor.Complete();
        }

        private void RunPlain( ExperimentResult result )
        {
            var plainWeights = Weights.Uniform( Population.ComponentCount );
            foreach( var distanceType in Parameters.DistanceTypes )
            {
                result.AddPlainDistance( distanceType, Population.Distance( distanceType, plainWeights ));
            }
        }

        private void RunPCA( ExperimentResult result )
        {
            var pca = new PrincipalComponentAnalysis( new PCAAdapter( Population ).Table );
            pca.Compute();

            var weights = new Weights( Population.ComponentCount );
            foreach( var component in pca.Components )
            {
                for( var i = 0; i < component.Eigenvector.Count(); i++ )
                {
                    weights[i] += component.Proportion * component.Eigenvector[i] * component.Eigenvector[i];
                }
                if( component.CumulativeProportion > Parameters.PCARecompositionThreshold )
                {
                    break;
                }
            }
            result.PCAComponents = pca.Components;
            result.PCAWeights = weights.Weigh();
            foreach( var distanceType in Parameters.DistanceTypes )
            {
                result.AddPCADistance( distanceType, Population.Distance( distanceType, result.PCAWeights ) );
            }
        }

        private void RunDEs( ExperimentResult result ) // run all combinations
        {
            foreach( var deType in Parameters.DETypes )
            {
                foreach( var deWeight in Parameters.DEWeights )
                {
                    foreach( var deCrossover in Parameters.DECrossoverProbabilities )
                    {
                        foreach( var dePopulationCount in Parameters.DEPopulationCounts )
                        {
                            foreach( var deIterationCount in Parameters.DEIterationCounts )
                            {
                                foreach( var distanceType in Parameters.DistanceTypes )
                                {
                                    for( var run = 0; run < Parameters.DERuns; run++ )
                                    {
                                        var ldeType = deType;
                                        var ldeWeight = deWeight;
                                        var ldeCrossover = deCrossover;
                                        var ldePopulationCount = dePopulationCount;
                                        var ldeIterationCount = deIterationCount;
                                        var ldistanceType = distanceType;
                                        var lrun = run;
                                        Executor.Queue( this, () =>
                                        {
                                            RunDE( result, ldeType, ldeWeight, ldeCrossover, ldePopulationCount, ldeIterationCount, ldistanceType, lrun );
                                        } );
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        private void RunDE( ExperimentResult result, int deType, double deWeight, double deCrossover, int dePopulationCount, int deIterationCount, Distance distance, int run )
        {
            var deAdapter = new DEAdapter( Population, deType, deWeight, deCrossover, dePopulationCount, deIterationCount, distance );
            var de = new DE.DifferentialEvolution( deAdapter.Objective );

            var deOutput = de.Optimizer( deAdapter.InputStructure );
            var bestObjective = -deOutput.S_bestval.FVr_oa[0];
            var bestWeights = new Weights( deOutput.FVr_bestmem, Weights.NormalizationMode.Weigh );

            result.AddDEResult( new ExperimentResult.DEResult( deType, deWeight, deCrossover, dePopulationCount, deIterationCount, distance, run, bestObjective, bestWeights ));
        }

        // helpers
        private ComponentDefinition GetComponent( int index )
        {
            if( Parameters.Components == null || Parameters.ComponentCount == 0 )
            {
                return new ComponentDefinition( ComponentType.RandomNormal, 0, 1 );
            }
            var lastDefined = Parameters.Components.Length-1;
            if( index > lastDefined )
            {
                return Parameters.Components[lastDefined];
            }
            else
            {
                return Parameters.Components[index];
            }
        }
    }
}
