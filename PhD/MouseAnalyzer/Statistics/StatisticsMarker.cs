using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using MouseAnalyzer.Statistics;

namespace MouseAnalyzer
{
    class StatisticsMarker : IValueMarker
    {
        #region IMarker Members

        public string Name { get { return ( markerName == null ? "" : markerName + "." ) + MarkerTypeName; } }
        public string MarkerTypeName { get; private set; }
        public string ComputeId { get; private set; }
        public IFeature Feature { get; private set; }
        public Func<IFeatureItem, double> Extractor { get; private set; }
        public IDistribution Estimate { get; private set; }

        #endregion

        #region IValueMarker Members

        public double Value { get; private set; }

        #endregion

        private string markerName;

        public StatisticsMarker( string computeId, IFeature feature, string markerName, Func<IFeatureItem, double> extractor, IDistribution estimate, string markerTypeName, double value )
        {
            Feature = feature;
            this.markerName = markerName;
            ComputeId = computeId;
            Estimate = estimate;
            MarkerTypeName = markerTypeName;
            Value = value;
            Extractor = extractor;

            if( double.IsNaN( value ) )
            {
                throw new Exception();
            }
        }
    }

    class DistributionMarker : IDistributionMarker
    {
        #region IMarker Members

        public string Name { get { return ( markerName == null ? "" : markerName + "." ) + MarkerTypeName; } }
        public string MarkerTypeName { get; private set; }
        public string ComputeId { get; private set; }
        public IFeature Feature { get; private set; }
        public Func<IFeatureItem, double> Extractor { get; private set; }
        public IDistribution Estimate { get; private set; }

        #endregion

        #region IDistributionMarker Members

        public IList<string> ParameterNames
        {
            get { return Estimate.ParameterNames; }
        }

        public IList<double> ParameterValues
        {
            get { return Estimate.ParameterValues; }
        }

        #endregion

        private string markerName;

        public DistributionMarker( string computeId, IFeature feature, string markerName, Func<IFeatureItem, double> extractor, IDistribution estimate )
        {
            Feature = feature;
            this.markerName = markerName;
            ComputeId = computeId;
            Estimate = estimate;
            MarkerTypeName = "PD";
            Extractor = extractor;
        }
    }

    class DistributionStandaloneMarker : IDistributionMarker
    {
        #region IMarker Members

        public string Name
        {
            get { return ( markerName == null ? "" : markerName ) + ( MarkerTypeName == null ? "" : "." + MarkerTypeName ); }
        }
        public string MarkerTypeName { get; private set; }
        public string ComputeId { get; private set; }
        public IFeature Feature { get; private set; }
        public Func<IFeatureItem, double> Extractor { get; private set; }
        public IDistribution Estimate { get; private set; }

        #endregion

        #region IDistributionMarker Members

        public IList<string> ParameterNames
        {
            get { return Estimate.ParameterNames; }
        }

        public IList<double> ParameterValues
        {
            get { return Estimate.ParameterValues; }
        }

        #endregion

        private string markerName;

        public DistributionStandaloneMarker( string markerName, Func<IFeatureItem, double> extractor, DistributionType type, List<string> parameterNames, List<string> parameterValues )
        {
            this.markerName = markerName;
            Extractor = extractor;

            Estimate = DistributionClass.CreateDistribution( type );
            for( var i = 0; i < parameterNames.Count; i++ )
            {
                Estimate.SetParameterValue( parameterNames[i], double.Parse( parameterValues[i] ) );
            }
        }
    }

    class HistogramMarker : IHistogramMarker
    {
        #region IMarker Members

        public string Name { get { return ( markerName == null ? "" : markerName + "." ) + MarkerTypeName; } }
        public string MarkerTypeName { get { return "Histogram"; } }
        public string ComputeId { get; private set; }
        public IFeature Feature { get; private set; }
        public Func<IFeatureItem, double> Extractor { get; private set; }
        public IDistribution Estimate { get; private set; }

        #endregion

        #region IHistogramMarker Members

        public HistogramDefinition Definition { get { return definition; } }
        public int[] Frequencies { get { return histogram.Frequencies; } }
        public double[] BinMidpoints { get { return definition.BinMidpoints; } }

        #endregion

        private string markerName;
        private HistogramDefinition definition;
        private Histogram histogram;

        public HistogramMarker( string computeId, IFeature feature, string markerName, Func<IFeatureItem, double> extractor, IDistribution estimate, HistogramDefinition definition, IEnumerable<double> values )
        {
            Feature = feature;
            this.markerName = markerName;
            ComputeId = computeId;
            Extractor = extractor;
            Estimate = estimate;
            this.definition = definition;

            var from = values.Where( v => !double.IsNegativeInfinity( v ) ).Min();
            var to = values.Where( v => !double.IsPositiveInfinity( v ) ).Max();
            this.histogram = new Histogram( definition, values, from, to );
        }
    }

    class GaussianMarkerExtractor : IMarkerExtractor
    {
        #region IMarkerExtractor Members

        public IEnumerable<IMarker> Extract( string computeId, IFeature feature, IEnumerable<IFeatureItem> items, string markerName, Func<IFeatureItem, double> valueExtractor, HistogramDefinition definition )
        {
            var markers = new List<IMarker>();
            var input = items.Select<IFeatureItem, double>( d => valueExtractor( d ) ).Where( d => !double.IsNaN( d ) );

            // data sets
            var estimate = (GaussianDatasetEstimate)new Estimator().Estimate( DistributionType.Gaussian, input, true );

            markers.Add( new DistributionMarker( computeId, feature, markerName, valueExtractor, estimate ) );

            markers.Add( new StatisticsMarker( computeId, feature, markerName, valueExtractor, estimate, "Minimum", estimate.MdfMinimum ) );
            markers.Add( new StatisticsMarker( computeId, feature, markerName, valueExtractor, estimate, "Maximum", estimate.MdfMaximum ) );
            markers.Add( new StatisticsMarker( computeId, feature, markerName, valueExtractor, estimate, "Mean", estimate.MdfMean ) );
            markers.Add( new StatisticsMarker( computeId, feature, markerName, valueExtractor, estimate, "Sigma", estimate.MdfSigma ) );

            // histograms
            if( definition != null )
            {
                definition.SupplyRange( estimate.Minimum, estimate.Maximum );
                var histogram = new HistogramMarker( computeId, feature, markerName, valueExtractor, estimate, definition, input );
                markers.Add( histogram );

                var fit = (GaussianHistogramEstimate)new Estimator().Estimate( DistributionType.Gaussian, histogram );

                markers.Add( new DistributionMarker( computeId, feature, "h" + markerName, valueExtractor, fit ) );

                markers.Add( new StatisticsMarker( computeId, feature, markerName, valueExtractor, fit, "hMean", fit.Mean ) );
                markers.Add( new StatisticsMarker( computeId, feature, markerName, valueExtractor, fit, "hSigma", fit.Sigma ) );
            }

            return markers;
        }

        #endregion
    }

    class LogisticMarkerExtractor : IMarkerExtractor
    {
        #region IMarkerExtractor Members

        public IEnumerable<IMarker> Extract( string computeId, IFeature feature, IEnumerable<IFeatureItem> items, string markerName, Func<IFeatureItem, double> valueExtractor, HistogramDefinition definition )
        {
            var markers = new List<IMarker>();
            var input = items.Select<IFeatureItem, double>( d => valueExtractor( d ) ).Where( d => !double.IsNaN( d ) );

            // data sets
            var estimate = (LogisticDatasetEstimate)new Estimator().Estimate( DistributionType.Logistic, input, false );

            markers.Add( new DistributionMarker( computeId, feature, markerName, valueExtractor, estimate ) );

            markers.Add( new StatisticsMarker( computeId, feature, markerName, valueExtractor, estimate, "Minimum", estimate.Minimum ) );
            markers.Add( new StatisticsMarker( computeId, feature, markerName, valueExtractor, estimate, "Maximum", estimate.Maximum ) );
            markers.Add( new StatisticsMarker( computeId, feature, markerName, valueExtractor, estimate, "Mean", estimate.Mean ) );
            markers.Add( new StatisticsMarker( computeId, feature, markerName, valueExtractor, estimate, "Sigma", estimate.Sigma ) );

            // histograms
            if( definition != null )
            {
                definition.SupplyRange( estimate.Minimum, estimate.Maximum );
                var histogram = new HistogramMarker( computeId, feature, markerName, valueExtractor, estimate, definition, input );
                markers.Add( histogram );

                var fit = (LogisticHistogramEstimate)new Estimator().Estimate( DistributionType.Logistic, histogram );

                markers.Add( new DistributionMarker( computeId, feature, "h" + markerName, valueExtractor, fit ) );

                markers.Add( new StatisticsMarker( computeId, feature, markerName, valueExtractor, fit, "hMean", fit.Mean ) );
                markers.Add( new StatisticsMarker( computeId, feature, markerName, valueExtractor, fit, "hSigma", fit.Sigma ) );
            }

            return markers;
        }

        #endregion
    }

    class LognormalMarkerExtractor : IMarkerExtractor
    {
        #region IMarkerExtractor Members

        public IEnumerable<IMarker> Extract( string computeId, IFeature feature, IEnumerable<IFeatureItem> items, string markerName, Func<IFeatureItem, double> valueExtractor, HistogramDefinition definition )
        {
            var markers = new List<IMarker>();
            var input = items.Select<IFeatureItem, double>( d => valueExtractor( d ) ).Where( d => !double.IsNaN( d ) );

            // data sets
            var estimate = (LognormalDatasetEstimate)new Estimator().Estimate( DistributionType.Lognormal, input, false );

            markers.Add( new DistributionMarker( computeId, feature, markerName, valueExtractor, estimate ) );

            markers.Add( new StatisticsMarker( computeId, feature, markerName, valueExtractor, estimate, "Minimum", estimate.Minimum ) );
            markers.Add( new StatisticsMarker( computeId, feature, markerName, valueExtractor, estimate, "Maximum", estimate.Maximum ) );
            markers.Add( new StatisticsMarker( computeId, feature, markerName, valueExtractor, estimate, "Mu", estimate.Mu ) );
            markers.Add( new StatisticsMarker( computeId, feature, markerName, valueExtractor, estimate, "Sigma", estimate.Sigma ) );

            // histograms
            if( definition != null )
            {
                definition.SupplyRange( estimate.Minimum, estimate.Maximum );
                var histogram = new HistogramMarker( computeId, feature, markerName, valueExtractor, estimate, definition, input );
                markers.Add( histogram );

                var fit = (LognormalHistogramEstimate)new Estimator().Estimate( DistributionType.Lognormal, histogram );

                markers.Add( new DistributionMarker( computeId, feature, "h" + markerName, valueExtractor, fit ) );

                markers.Add( new StatisticsMarker( computeId, feature, markerName, valueExtractor, fit, "hMu", fit.Mu ) );
                markers.Add( new StatisticsMarker( computeId, feature, markerName, valueExtractor, fit, "hSigma", fit.Sigma ) );
            }

            return markers;
        }

        #endregion
    }

    class InverseGaussianMarkerExtractor : IMarkerExtractor
    {
        #region IMarkerExtractor Members

        public IEnumerable<IMarker> Extract( string computeId, IFeature feature, IEnumerable<IFeatureItem> items, string markerName, Func<IFeatureItem, double> valueExtractor, HistogramDefinition definition )
        {
            var markers = new List<IMarker>();
            var input = items.Select<IFeatureItem, double>( d => valueExtractor( d ) ).Where( d => !double.IsNaN( d ) );

            // data sets
            var estimate = (InverseGaussianDatasetEstimate)new Estimator().Estimate( DistributionType.InverseGaussian, input, false ); // Median is not computed

            markers.Add( new DistributionMarker( computeId, feature, markerName, valueExtractor, estimate ) );

            markers.Add( new StatisticsMarker( computeId, feature, markerName, valueExtractor, estimate, "Minimum", estimate.Minimum ) );
            markers.Add( new StatisticsMarker( computeId, feature, markerName, valueExtractor, estimate, "Maximum", estimate.Maximum ) );
            markers.Add( new StatisticsMarker( computeId, feature, markerName, valueExtractor, estimate, "Mean", estimate.Mean ) );
            markers.Add( new StatisticsMarker( computeId, feature, markerName, valueExtractor, estimate, "Lambda", estimate.Lambda ) );

            // histograms
            if( definition != null )
            {
                definition.SupplyRange( estimate.Minimum, estimate.Maximum );
                var histogram = new HistogramMarker( computeId, feature, markerName, valueExtractor, estimate, definition, input );
                markers.Add( histogram );

                var fit = (InverseGaussianHistogramEstimate)new Estimator().Estimate( DistributionType.InverseGaussian, histogram );

                markers.Add( new DistributionMarker( computeId, feature, "h" + markerName, valueExtractor, fit ) );

                markers.Add( new StatisticsMarker( computeId, feature, markerName, valueExtractor, fit, "hMean", fit.Mean ) );
                markers.Add( new StatisticsMarker( computeId, feature, markerName, valueExtractor, fit, "hLambda", fit.Lambda ) );
            }

            return markers;
        }

        #endregion
    }

    class WeibullMarkerExtractor : IMarkerExtractor
    {
        #region IMarkerExtractor Members

        public IEnumerable<IMarker> Extract( string computeId, IFeature feature, IEnumerable<IFeatureItem> items, string markerName, Func<IFeatureItem, double> valueExtractor, HistogramDefinition definition )
        {
            var markers = new List<IMarker>();
            var input = items.Select<IFeatureItem, double>( d => valueExtractor( d ) ).Where( d => !double.IsNaN( d ) );

            // data sets
            var estimate = (WeibullDatasetEstimate)new Estimator().Estimate( DistributionType.Weibull, input, false );

            markers.Add( new DistributionMarker( computeId, feature, markerName, valueExtractor, estimate ) );

            markers.Add( new StatisticsMarker( computeId, feature, markerName, valueExtractor, estimate, "Minimum", estimate.Minimum ) );
            markers.Add( new StatisticsMarker( computeId, feature, markerName, valueExtractor, estimate, "Maximum", estimate.Maximum ) );
            markers.Add( new StatisticsMarker( computeId, feature, markerName, valueExtractor, estimate, "Alpha", estimate.Alpha ) );
            markers.Add( new StatisticsMarker( computeId, feature, markerName, valueExtractor, estimate, "Beta", estimate.Beta ) );

            // histograms
            if( definition != null )
            {
                definition.SupplyRange( estimate.Minimum, estimate.Maximum );
                var histogram = new HistogramMarker( computeId, feature, markerName, valueExtractor, estimate, definition, input );
                markers.Add( histogram );

                var fit = (WeibullHistogramEstimate)new Estimator().Estimate( DistributionType.Weibull, histogram );

                markers.Add( new DistributionMarker( computeId, feature, "h" + markerName, valueExtractor, fit ) );

                markers.Add( new StatisticsMarker( computeId, feature, markerName, valueExtractor, fit, "hMean", fit.Alpha ) );
                markers.Add( new StatisticsMarker( computeId, feature, markerName, valueExtractor, fit, "hSigma", fit.Beta ) );
            }

            return markers;
        }

        #endregion
    }

    class GammaMarkerExtractor : IMarkerExtractor
    {
        #region IMarkerExtractor Members

        public IEnumerable<IMarker> Extract( string computeId, IFeature feature, IEnumerable<IFeatureItem> items, string markerName, Func<IFeatureItem, double> valueExtractor, HistogramDefinition definition )
        {
            var markers = new List<IMarker>();
            var input = items.Select<IFeatureItem, double>( d => valueExtractor( d ) ).Where( d => !double.IsNaN( d ) );

            // data sets
            var estimate = (GammaDatasetEstimate)new Estimator().Estimate( DistributionType.Gamma, input, false );

            markers.Add( new DistributionMarker( computeId, feature, markerName, valueExtractor, estimate ) );

            markers.Add( new StatisticsMarker( computeId, feature, markerName, valueExtractor, estimate, "Minimum", estimate.Minimum ) );
            markers.Add( new StatisticsMarker( computeId, feature, markerName, valueExtractor, estimate, "Maximum", estimate.Maximum ) );
            markers.Add( new StatisticsMarker( computeId, feature, markerName, valueExtractor, estimate, "Alpha", estimate.Alpha ) );
            markers.Add( new StatisticsMarker( computeId, feature, markerName, valueExtractor, estimate, "Theta", estimate.Theta ) );

            // histograms
            if( definition != null )
            {
                definition.SupplyRange( estimate.Minimum, estimate.Maximum );
                var histogram = new HistogramMarker( computeId, feature, markerName, valueExtractor, estimate, definition, input );
                markers.Add( histogram );

                var fit = (GammaHistogramEstimate)new Estimator().Estimate( DistributionType.Gamma, histogram );

                markers.Add( new DistributionMarker( computeId, feature, "h" + markerName, valueExtractor, fit ) );

                markers.Add( new StatisticsMarker( computeId, feature, markerName, valueExtractor, fit, "hMean", fit.Alpha ) );
                markers.Add( new StatisticsMarker( computeId, feature, markerName, valueExtractor, fit, "hTheta", fit.Theta ) );
            }

            return markers;
        }

        #endregion
    }

    class RayleighMarkerExtractor : IMarkerExtractor
    {
        #region IMarkerExtractor Members

        public IEnumerable<IMarker> Extract( string computeId, IFeature feature, IEnumerable<IFeatureItem> items, string markerName, Func<IFeatureItem, double> valueExtractor, HistogramDefinition definition )
        {
            var markers = new List<IMarker>();
            var input = items.Select<IFeatureItem, double>( d => valueExtractor( d ) ).Where( d => !double.IsNaN( d ) );

            // data sets
            var estimate = (RayleighDatasetEstimate)new Estimator().Estimate( DistributionType.Rayleigh, input, false );

            markers.Add( new DistributionMarker( computeId, feature, markerName, valueExtractor, estimate ) );

            markers.Add( new StatisticsMarker( computeId, feature, markerName, valueExtractor, estimate, "Minimum", estimate.Minimum ) );
            markers.Add( new StatisticsMarker( computeId, feature, markerName, valueExtractor, estimate, "Maximum", estimate.Maximum ) );
            markers.Add( new StatisticsMarker( computeId, feature, markerName, valueExtractor, estimate, "Sigma", estimate.Sigma ) );

            // histograms
            if( definition != null )
            {
                definition.SupplyRange( estimate.Minimum, estimate.Maximum );
                var histogram = new HistogramMarker( computeId, feature, markerName, valueExtractor, estimate, definition, input );
                markers.Add( histogram );

                var fit = (RayleighHistogramEstimate)new Estimator().Estimate( DistributionType.Rayleigh, histogram );

                markers.Add( new DistributionMarker( computeId, feature, "h" + markerName, valueExtractor, fit ) );

                markers.Add( new StatisticsMarker( computeId, feature, markerName, valueExtractor, fit, "hSigma", fit.Sigma ) );
            }

            return markers;
        }

        #endregion
    }

    class SplineMarkerExtractor : IMarkerExtractor
    {
        #region IMarkerExtractor Members

        public IEnumerable<IMarker> Extract( string computeId, IFeature feature, IEnumerable<IFeatureItem> items, string markerName, Func<IFeatureItem, double> valueExtractor, HistogramDefinition definition )
        {
            var markers = new List<IMarker>();
            var input = items.Select<IFeatureItem, double>( d => valueExtractor( d ) ).Where( d => !double.IsNaN( d ) );

            // data sets
            var estimate = (SplineDatasetEstimate)new Estimator().Estimate( DistributionType.Spline, input, false );

            markers.Add( new DistributionMarker( computeId, feature, markerName, valueExtractor, estimate ) );

            // histograms
            if( definition != null )
            {
                definition.SupplyRange( estimate.Minimum, estimate.Maximum );
                var histogram = new HistogramMarker( computeId, feature, markerName, valueExtractor, estimate, definition, input );
                markers.Add( histogram );
            }

            return markers;
        }

        #endregion
    }
}
