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
        private Weights PlainWeights;
        private Dictionary<Distance, double> Distances = new Dictionary<Distance, double>();
        private Dictionary<Distance, double> PCADistances = new Dictionary<Distance, double>();
        private Weights PCAWeights;

        public Experiment()
        {
            // DE related parameters
            DETypes = new int[] { 2 };
            DEPopulationCounts = new int[] { 50 };
            DEIterationCounts = new int[] { 50 };
            DERuns = 10;

            // population related parameters
            DistanceTypes = new Distance[] { new Distance() };
            PopulationCount = 75;
            ComponentCount = 75;
            Normalization = Population.NormalizationType.None;
            Components = null;
            PCARecompositionThreshold = 0.95;
        }

        public Experiment( Population population ) :
            this()
        {
            this.Population = population;
        }

        // DE related parameters
        public int[] DETypes { get; set; }

        public int[] DEPopulationCounts { get; set; }

        public int[] DEIterationCounts { get; set; }

        public int DERuns { get; set; }

        // population related parameters
        public Distance[] DistanceTypes { get; set; }

        public int PopulationCount { get; set; }

        public int ComponentCount { get; set; }

        public Population.NormalizationType Normalization { get; set; }

        public ComponentDefinition[] Components { get; set; }

        public double PCARecompositionThreshold { get; set; }

        // callback to catch intermediate results
        // DEType, PopulationCount, IterationCount, DistanceType, RunNumber, Distance, PCADistance, PCAWeights, DEDistance, DEWeights
        private Action<int, int, int, Distance, int, double, double, Weights, double, Weights> ResultCatcher { get; set; }

        // executive methods
        public void Run( Action<int, int, int, Distance, int, double, double, Weights, double, Weights> resultCatcher = null )
        {
            ResultCatcher = resultCatcher;
            DumpParameters();

            CreatePopulation();
            PlainWeights = Weights.Uniform( Population.ComponentCount );

            RunPlain();

            RunPCA();

            RunDEs();
            Executor.WaitForCompletion( this );
        }

        private void CreatePopulation()
        {
            if( Population == null )
            {
                Population = new PopulationCreator( PopulationCount, ComponentCount, ( i ) => GetComponent( i ) ).Populate();
            }

            DumpPopulation();

            Population = Population.Normalize( Normalization );
        }

        private void RunPlain()
        {
            foreach( var distanceType in DistanceTypes )
            {
                Distances[distanceType] = Population.Distance( distanceType, PlainWeights );
            }

            DumpPlain();
        }

        private void RunPCA()
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
                if( component.CumulativeProportion > PCARecompositionThreshold )
                {
                    break;
                }
            }
            PCAWeights = weights.Weigh();
            foreach( var distanceType in DistanceTypes )
            {
                PCADistances[distanceType] = Population.Distance( distanceType, PCAWeights );
            }

            DumpPCA();
        }

        private void RunDEs() // run all combinations
        {
            foreach( var deType in DETypes )
            {
                foreach( var dePopulationCount in DEPopulationCounts )
                {
                    foreach( var deIterationCount in DEIterationCounts )
                    {
                        foreach( var distanceType in DistanceTypes )
                        {
                            for( var run = 0; run < DERuns; run++ )
                            {
                                Executor.Queue( this, () =>
                                {
                                    RunDE( deType, dePopulationCount, deIterationCount, distanceType, run );
                                } );
                            }
                        }
                    }
                }
            }
        }

        private void RunDE( int deType, int dePopulationCount, int deIterationCount, Distance distance, int run )
        {
            var deAdapter = new DEAdapter( Population, deType, dePopulationCount, deIterationCount, distance );
            var de = new DE.DifferentialEvolution( deAdapter.Objective );

            var deOutput = de.Optimizer( deAdapter.InputStructure );
            var bestObjective = -deOutput.S_bestval.FVr_oa[0];
            var bestWeights = new Weights( deOutput.FVr_bestmem, Weights.NormalizationMode.Weigh );

            if( ResultCatcher != null )
            {
                ResultCatcher( deType, dePopulationCount, deIterationCount, distance, run, Distances[distance], PCADistances[distance], PCAWeights, bestObjective, bestWeights );
            }

            DumpDE( bestObjective, bestWeights );
        }

        // helpers
        private ComponentDefinition GetComponent( int index )
        {
            if( Components == null || Components.Count() == 0 )
            {
                return new ComponentDefinition( ComponentType.RandomNormal, 0, 1 );
            }
            else if( index >= Components.Count() )
            {
                return Components[Components.Count()-1];
            }
            else
            {
                return Components[index];
            }
        }

        private void DumpParameters()
        {
        }

        private void DumpPopulation()
        {
        }

        private void DumpPlain()
        {
        }

        private void DumpPCA()
        {
        }

        private void DumpDE( double bestObjective, Weights bestWeights )
        {
        }
    }
}
