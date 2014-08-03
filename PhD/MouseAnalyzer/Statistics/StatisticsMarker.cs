using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer
{
    class StatisticsMarker : IValueMarker
    {
        #region IMarker Members

        public string Name { get { return ( featureName == null ? "" : featureName + "." ) + MarkerTypeName; } }
        public string MarkerTypeName { get; private set; }
        public string ComputeId { get; private set; }
        public IFeature Feature { get; private set; }
        public IEstimate Estimate { get; private set; }

        #endregion

        #region IValueMarker Members

        public double Value { get; private set; }

        #endregion

        private string featureName;

        public StatisticsMarker( string computeId, IFeature feature, string featureName, IEstimate estimate, string markerName, double value )
        {
            Feature = feature;
            this.featureName = featureName;
            ComputeId = computeId;
            Estimate = estimate;
            MarkerTypeName = markerName;
            Value = value;
        }
    }

    class HistogramMarker : IHistogramMarker
    {
        public class HistogramDefinition
        {
            public enum BinCreationStrategy
            {
                Auto,
                Sparse,
                Predefined
            }

            public BinCreationStrategy Strategy { get; private set; }
            public int Bins { get; private set; }
            public double[] BinMidpoints { get; private set; }
            public double BinWidth { get; private set; }

            public HistogramDefinition( int bins )
            {
                Strategy = HistogramDefinition.BinCreationStrategy.Auto;
                Bins = bins;
            }

            public HistogramDefinition( double firstBinMidpoint, double binMidpointSpread, double binWidth, double stopBinMidpoint = double.MaxValue )
            {
                Strategy = HistogramDefinition.BinCreationStrategy.Sparse;
                BinWidth = binWidth;
                BinMidpoints = new double[] { firstBinMidpoint, binMidpointSpread, stopBinMidpoint }; // ugly
            }

            public HistogramDefinition( IEnumerable<double> binMidpoints, double binWidth )
            {
                Strategy = HistogramDefinition.BinCreationStrategy.Predefined;
                Bins = binMidpoints.Count();
                BinWidth = binWidth;
                BinMidpoints = binMidpoints.ToArray();
            }

            public void SupplyRange( double from, double to )
            {
                if( Strategy == HistogramDefinition.BinCreationStrategy.Auto )
                {
                    BinWidth = ( from - to ) / Bins;
                    BinMidpoints = new double[Bins];
                    for( var bin = 0; bin < Bins; ++bin )
                    {
                        BinMidpoints[bin] = from + ( bin+0.5 ) * BinWidth;
                    }
                }
                else if( Strategy == HistogramDefinition.BinCreationStrategy.Sparse )
                {
                    var firstBinMidpoint = BinMidpoints[0]; // ugly
                    var binMidpointSpread = BinMidpoints[1];
                    var stopBinMidpoint = BinMidpoints[2];
                    Bins = (int)( ( ( stopBinMidpoint > to ? to : stopBinMidpoint ) - firstBinMidpoint ) / binMidpointSpread ) + 1;
                    BinMidpoints = new double[Bins];
                    for( var bin = 0; bin < Bins; bin++ )
                    {
                        BinMidpoints[bin] = firstBinMidpoint + binMidpointSpread * bin;
                    }
                }
            }
        }

        #region IMarker Members

        public string Name { get { return ( featureName == null ? "" : featureName + "." ) + MarkerTypeName; } }
        public string MarkerTypeName { get { return "Histogram"; } }
        public string ComputeId { get; private set; }
        public IFeature Feature { get; private set; }
        public IEstimate Estimate { get; private set; }

        #endregion

        #region IHistogramMarker Members

        public int[] Frequencies { get { return frequencies; } }
        public double[] BinMidpoints { get { return definition.BinMidpoints; } }

        #endregion

        private string featureName;
        private HistogramDefinition definition;
        private int[] frequencies;

        public HistogramMarker( string computeId, IFeature feature, string featureName, IEstimate estimate, HistogramDefinition definition, IEnumerable<double> ordered )
        {
            Feature = feature;
            this.featureName = featureName;
            ComputeId = computeId;
            Estimate = estimate;
            this.definition = definition;
            this.frequencies = new int[definition.Bins];

            var from = ordered.First();
            var to = ordered.Last();

            if( definition.Strategy == HistogramDefinition.BinCreationStrategy.Auto )
            {
                var range = to - from;
                foreach( var item in ordered )
                {
                    var bin = range==0.0 ? definition.Bins : (int)( definition.Bins*( item-from )/range );
                    ++frequencies[bin==definition.Bins ? --bin : bin];
                }
            }
            else
            {
                var halfWidth = definition.BinWidth / 2.0;
                foreach( var item in ordered )
                {
                    var bin = 0;
                    foreach( var midpoint in definition.BinMidpoints )
                    {
                        if( item >= midpoint - halfWidth && item <= midpoint + halfWidth )
                        {
                            ++frequencies[bin];
                            break;
                        }
                        ++bin;
                    }
                }
            }
        }
    }

    class GaussianMarkerExtractor : IMarkerExtractor
    {
        #region IMarkerExtractor Members

        public IEnumerable<IMarker> Extract( string computeId, IFeature feature, IEnumerable<IFeatureItem> items, string featureName, Func<IFeatureItem, double> valueExtractor, HistogramMarker.HistogramDefinition definition )
        {
            var markers = new List<IMarker>();
            var input = items.Select<IFeatureItem, double>( d => valueExtractor( d ) ).Where( d => !double.IsNaN( d ) );
            if( input.Count() == 0 )
            {
                return markers;
            }

            var estimate = (GaussianEstimate)new Estimator().Estimate( DistributionType.Gaussian, input, 0.1, 0.1 );

            // plain values
            markers.Add( new StatisticsMarker( computeId, feature, featureName, estimate, "Minimum", estimate.Minimum ) );
            markers.Add( new StatisticsMarker( computeId, feature, featureName, estimate, "MdfMinimum", estimate.MdfMinimum ) );
            markers.Add( new StatisticsMarker( computeId, feature, featureName, estimate, "Average", estimate.Average ) );
            markers.Add( new StatisticsMarker( computeId, feature, featureName, estimate, "MdfAverage", estimate.MdfAverage ) );
            markers.Add( new StatisticsMarker( computeId, feature, featureName, estimate, "Maximum", estimate.Maximum ) );
            markers.Add( new StatisticsMarker( computeId, feature, featureName, estimate, "MdfMaximum", estimate.MdfMaximum ) );
            markers.Add( new StatisticsMarker( computeId, feature, featureName, estimate, "Median", estimate.Median ) );

            // variance
            markers.Add( new StatisticsMarker( computeId, feature, featureName, estimate, "Variance", estimate.Variance ) );
            markers.Add( new StatisticsMarker( computeId, feature, featureName, estimate, "MdfVariance", estimate.MdfVariance ) );

            // histograms
            if( definition != null )
            {
                definition.SupplyRange( estimate.Minimum, estimate.Maximum );
                markers.Add( new HistogramMarker( computeId, feature, featureName, estimate, definition, input ) );
            }

            return markers;
        }

        #endregion
    }

    class InverseGaussianMarkerExtractor : IMarkerExtractor
    {
        #region IMarkerExtractor Members

        public IEnumerable<IMarker> Extract( string computeId, IFeature feature, IEnumerable<IFeatureItem> items, string featureName, Func<IFeatureItem, double> valueExtractor, HistogramMarker.HistogramDefinition definition )
        {
            var markers = new List<IMarker>();
            var input = items.Select<IFeatureItem, double>( d => valueExtractor( d ) ).Where( d => !double.IsNaN( d ) );
            if( input.Count() == 0 )
            {
                return markers;
            }

            var estimate = (InverseGaussianEstimate)new Estimator().Estimate( DistributionType.InverseGaussian, input );

            // plain values
            markers.Add( new StatisticsMarker( computeId, feature, featureName, estimate, "Minimum", estimate.Minimum ) );
            markers.Add( new StatisticsMarker( computeId, feature, featureName, estimate, "Average", estimate.Average ) );
            markers.Add( new StatisticsMarker( computeId, feature, featureName, estimate, "Maximum", estimate.Maximum ) );
            markers.Add( new StatisticsMarker( computeId, feature, featureName, estimate, "Median", estimate.Median ) );
            markers.Add( new StatisticsMarker( computeId, feature, featureName, estimate, "eMean", estimate.Mean ) );
            markers.Add( new StatisticsMarker( computeId, feature, featureName, estimate, "eLambda1", estimate.Lambda1 ) );
            markers.Add( new StatisticsMarker( computeId, feature, featureName, estimate, "eLambda2", estimate.Lambda2 ) );

            // histograms
            if( definition != null )
            {
                definition.SupplyRange( estimate.Minimum, estimate.Maximum );
                var histogram = new HistogramMarker( computeId, feature, featureName, estimate, definition, input );
                // markers.Add( histogram );

                var fit = (InverseGaussianFit)new Estimator().Fit( DistributionType.InverseGaussian, histogram );

                // characteristics
                markers.Add( new StatisticsMarker( computeId, feature, featureName, estimate, "fMean", fit.Mean ) );
                markers.Add( new StatisticsMarker( computeId, feature, featureName, estimate, "fLambda1", fit.Lambda1 ) );
                markers.Add( new StatisticsMarker( computeId, feature, featureName, estimate, "fLambda2", fit.Lambda2 ) );
            }

            return markers;
        }

        #endregion
    }

    class LognormalMarkerExtractor : IMarkerExtractor
    {
        #region IMarkerExtractor Members

        public IEnumerable<IMarker> Extract( string computeId, IFeature feature, IEnumerable<IFeatureItem> items, string featureName, Func<IFeatureItem, double> valueExtractor, HistogramMarker.HistogramDefinition definition )
        {
            var markers = new List<IMarker>();
            var input = items.Select<IFeatureItem, double>( d => valueExtractor( d ) ).Where( d => !double.IsNaN( d ) );
            if( input.Count() == 0 )
            {
                return markers;
            }

            var estimate = (LognormalEstimate)new Estimator().Estimate( DistributionType.Lognormal, input );

            // plain values
            markers.Add( new StatisticsMarker( computeId, feature, featureName, estimate, "Minimum", estimate.Minimum ) );
            markers.Add( new StatisticsMarker( computeId, feature, featureName, estimate, "Average", estimate.Average ) );
            markers.Add( new StatisticsMarker( computeId, feature, featureName, estimate, "Maximum", estimate.Maximum ) );
            markers.Add( new StatisticsMarker( computeId, feature, featureName, estimate, "Median", estimate.Median ) );
            markers.Add( new StatisticsMarker( computeId, feature, featureName, estimate, "eMu", estimate.Mu ) );
            markers.Add( new StatisticsMarker( computeId, feature, featureName, estimate, "eSigma", estimate.Sigma ) );

            // histograms
            if( definition != null )
            {
                definition.SupplyRange( estimate.Minimum, estimate.Maximum );
                var histogram = new HistogramMarker( computeId, feature, featureName, estimate, definition, input );
                // markers.Add( histogram );

                var fit = (LognormalFit)new Estimator().Fit( DistributionType.Lognormal, histogram );

                // characteristics
                markers.Add( new StatisticsMarker( computeId, feature, featureName, estimate, "fMu", fit.Mu ) );
                markers.Add( new StatisticsMarker( computeId, feature, featureName, estimate, "fSigma", fit.Sigma ) );
            }

            return markers;
        }

        #endregion
    }
}
