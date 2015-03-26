using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using MouseAnalyzer.Statistics;

namespace MouseAnalyzer
{
    class Triple<T>
    {
        public T Value { get { return Positive; } }
        public T Positive { get; private set; }
        public T Negative { get; private set; }
        public T Zero { get; private set; }

        public Triple( T positiveOrSingle, T negative = default(T), T zero = default(T) )
        {
            Positive = positiveOrSingle;
            Negative = negative;
            Zero = zero;
        }
    }

    interface IMarker
    {
        string Name { get; }
        string MarkerTypeName { get; }
        string ComputeId { get; }
        IFeature Feature { get; } // of feature
    }

    interface ISingleDistribution
    {
        IDistribution Distribution { get; } // if available
        Func<IFeatureItem, double> Extractor { get; } // to get value from given IFeatureItem
    }

    interface ITripleDistribution
    {
        Triple<IDistribution> Distribution { get; } // if available
        Func<IFeatureItem, Triple<double>> Extractor { get; } // to get value from given IFeatureItem
    }

    interface IValueMarker : IMarker, ISingleDistribution
    {
        double Value { get; }
    }

    interface IDistributionMarker : IMarker, ITripleDistribution
    {
        IList<string> ParameterNames { get; }
        IList<double> ParameterValues { get; }

        string Serialized { get; set; }
    }

    interface IHistogramMarker : IMarker, ISingleDistribution
    {
        HistogramDefinition Definition { get; }
        double[] BinMidpoints { get; }
        int[] Frequencies { get; }
    }

    interface IMarkerExtractor
    {
        IEnumerable<IMarker> Extract(
            string computeId, IFeature feature, IEnumerable<IFeatureItem> items, string markerName, DistributionType distributionType,
            Func<IFeatureItem, Triple<double>> valueExtractor, Triple<HistogramDefinition> definition );
    }

    public enum MatchType
    {
        ItemArithmeticAverage, // the same as ItemD1Distance in fact, because D1 depends in count and is thus divided by it
        ItemProduct,
        ItemGeometricAverage,
        // ItemD1Distance, the same as ItemArithmeticAverage
        ItemD2Distance,
        DistributionArithmeticAverage,
        DistributionProduct,
        DistributionLogProduct,
        DistributionGeometricAverage,
        DistributionSum
    }

    interface IMarkers
    {
        IEnumerable<IMarker> Markers { get; }

        IList<double> Match( IEnumerable<IMarkers> samples, MatchType matchType, bool normalize = false, bool computeDistanceInsteadOfProximity = false ); // intended to match self.Values to all sample.Values
        IList<double> Match( Features.Markers drivingMarkers, IEnumerable<IFeatureItem> samples, MatchType matchType, bool adjustForInvalidSampleMarkers = true ); // intended to match self.Distributions to all samples.Values
            // adjustForInvalidSampleMarkers = true renormalizes result using this way: if e.g. 8 items from 10 passes, then result is remultiplied by 10/8
            // adjustForInvalidSampleMarkers = false returns 0.0 is some sample marker value is invalid (NaN or out of probability distribution bound)
    }
}
