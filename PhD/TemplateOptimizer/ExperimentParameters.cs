using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace TemplateOptimizer
{
    class ExperimentParameters
    {
        public ExperimentParameters()
        {
            // DE related parameters
            DETypes = new int[] { 2 };
            DECrossoverProbabilities = new double[] { 0.5 };
            DEWeights = new double[] { 0.85 };
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

        // DE related parameters
        public int[] DETypes { get; set; }

        public double[] DECrossoverProbabilities { get; set; }

        public double[] DEWeights { get; set; }

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
    }
}
