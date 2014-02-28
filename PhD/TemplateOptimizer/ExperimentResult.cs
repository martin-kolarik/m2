using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Accord.Statistics.Analysis;

namespace TemplateOptimizer
{
    class ExperimentResult
    {
        public class DEResult
        {
            public DEResult( int deType, double deWeight, double deCrossover, int dePopulationCount, int deIterationCount, Distance distance, int run, double bestDistance, Weights bestWeights )
            {
                Type = deType;
                Weight = deWeight;
                Crossover = deCrossover;
                PopulationCount = dePopulationCount;
                IterationCount = deIterationCount;
                Distance = distance;
                Run = run;
                DEDistance = bestDistance;
                DEWeights = bestWeights;
            }

            public int Type { get; private set; }
            public double Weight { get; private set; }
            public double Crossover { get; private set; }
            public int PopulationCount { get; private set; }
            public int IterationCount { get; private set; }
            public Distance Distance { get; private set; }
            public int Run { get; private set; }

            public double DEDistance { get; private set; }
            public Weights DEWeights { get; private set; }
        }

        // parameters, inputs
        public ExperimentResult( ExperimentParameters parameters, Population population, Population normalizedPopulation )
        {
            Parameters = parameters;
            Population = population;
            NormalizedPopulation = normalizedPopulation;

            PlainDistances = new Dictionary<Distance, double>();

            PCADistances = new Dictionary<Distance, double>(); 

            DEResults = new List<DEResult>();
        }

        public ExperimentParameters Parameters { get; private set; }
        public Population Population { get; private set; }
        public Population NormalizedPopulation { get; private set; }

        // plain, original data
        public Dictionary<Distance, double> PlainDistances { get; private set; }
        public void AddPlainDistance( Distance distance, double value )
        {
            PlainDistances[distance] = value;
        }

        // PCA
        public PrincipalComponentCollection PCAComponents { get; set; }
        public Weights PCAWeights { get; set; }
        public Dictionary<Distance, double> PCADistances { get; private set; }
        public void AddPCADistance( Distance distance, double value )
        {
            PCADistances[distance] = value;
        }

        // DE
        public List<DEResult> DEResults { get; private set; }
        public void AddDEResult( DEResult result )
        {
            DEResults.Add( result );
        }

        // user data
        private Dictionary<string, object> auxiliaryData = new Dictionary<string, object>();
        public void SetAuxiliaryData( string key, object value )
        {
            auxiliaryData[key] = value;
        }

        public object GetAuxiliaryData( string key )
        {
            object value;
            return auxiliaryData.TryGetValue( key, out value ) ? value : null;
        }
    }
}
