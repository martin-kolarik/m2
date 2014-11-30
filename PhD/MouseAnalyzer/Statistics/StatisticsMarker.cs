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
        public IDistribution Distribution { get; private set; }

        #endregion

        #region IValueMarker Members

        public double Value { get; private set; }

        #endregion

        private string markerName;

        public StatisticsMarker( string computeId, IFeature feature, string markerName, Func<IFeatureItem, double> extractor, IDistribution distribution, string markerTypeName, double value )
        {
            Feature = feature;
            this.markerName = markerName;
            ComputeId = computeId;
            Distribution = distribution;
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
        public Func<IFeatureItem, Triple<double>> Extractor { get; private set; }
        public Triple<IDistribution> Distribution { get; private set; }

        #endregion

        #region IDistributionMarker Members

        public IList<string> ParameterNames
        {
            get
            {
                var output = new List<string>();
                if( Distribution.Positive != null )
                {
                    output.AddRange( Distribution.Positive.ParameterNames.Select( n => n + "+" ) );
                }
                if( Distribution.Negative != null )
                {
                    output.AddRange( Distribution.Negative.ParameterNames.Select( n => n + "-" ) );
                }
                if( Distribution.Zero != null )
                {
                    output.AddRange( Distribution.Zero.ParameterNames.Select( n => n + "0" ) );
                }
                return output;
            }
        }

        public IList<double> ParameterValues
        {
            get
            {
                var output = new List<double>();
                if( Distribution.Positive != null )
                {
                    output.AddRange( Distribution.Positive.ParameterValues );
                }
                if( Distribution.Negative != null )
                {
                    output.AddRange( Distribution.Negative.ParameterValues );
                }
                if( Distribution.Zero != null )
                {
                    output.AddRange( Distribution.Zero.ParameterValues );
                }
                return output;
            }
        }

        public string Serialized
        {
            get
            {
                string s = "";
                if( Distribution.Positive != null )
                {
                    s += "+:" +
                         Distribution.Positive.Type.ToString() + ":" +
                         string.Join( " ", Distribution.Positive.ParameterNames ) + ":" +
                         string.Join( " ", Distribution.Positive.ParameterValues ) + ":+|";
                }
                if( Distribution.Negative != null )
                {
                    s += "-:" +
                         Distribution.Negative.Type.ToString() + ":" +
                         string.Join( " ", Distribution.Negative.ParameterNames ) + ":" +
                         string.Join( " ", Distribution.Negative.ParameterValues ) + ":-|";
                }
                if( Distribution.Zero != null )
                {
                    s += "0:" +
                         Distribution.Zero.Type.ToString() + ":" +
                         string.Join( " ", Distribution.Zero.ParameterNames ) + ":" +
                         string.Join( " ", Distribution.Zero.ParameterValues ) + ":0|";
                }
                return s;
            }
            set
            {
                throw new Exception( "Set is unsupported for computed marker" );
            }
        }

        #endregion

        private string markerName;

        public DistributionMarker( string computeId, IFeature feature, string markerName, Func<IFeatureItem, Triple<double>> extractor, Triple<IDistribution> estimate )
        {
            Feature = feature;
            this.markerName = markerName;
            ComputeId = computeId;
            Distribution = estimate;
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
        public Func<IFeatureItem, Triple<double>> Extractor { get; set; }
        public Triple<IDistribution> Distribution { get; private set; }

        #endregion

        #region IDistributionMarker Members

        public IList<string> ParameterNames
        {
            get
            {
                var output = new List<string>();
                if( Distribution.Positive != null )
                {
                    output.AddRange( Distribution.Positive.ParameterNames.Select( n => n + "+" ) );
                }
                if( Distribution.Negative != null )
                {
                    output.AddRange( Distribution.Negative.ParameterNames.Select( n => n + "-" ) );
                }
                if( Distribution.Zero != null )
                {
                    output.AddRange( Distribution.Zero.ParameterNames.Select( n => n + "0" ) );
                }
                return output;
            }
        }

        public IList<double> ParameterValues
        {
            get
            {
                var output = new List<double>();
                if( Distribution.Positive != null )
                {
                    output.AddRange( Distribution.Positive.ParameterValues );
                }
                if( Distribution.Negative != null )
                {
                    output.AddRange( Distribution.Negative.ParameterValues );
                }
                if( Distribution.Zero != null )
                {
                    output.AddRange( Distribution.Zero.ParameterValues );
                }
                return output;
            }
        }

        public string Serialized
        {
            get
            {
                string s = "";
                if( Distribution.Positive != null )
                {
                    s += "+:" +
                         Distribution.Positive.Type.ToString() + ":" +
                         string.Join( " ", Distribution.Positive.ParameterNames ) + ":" +
                         string.Join( " ", Distribution.Positive.ParameterValues ) + ":+|";
                }
                if( Distribution.Negative != null )
                {
                    s += "-:" +
                         Distribution.Negative.Type.ToString() + ":" +
                         string.Join( " ", Distribution.Negative.ParameterNames ) + ":" +
                         string.Join( " ", Distribution.Negative.ParameterValues ) + ":-|";
                }
                if( Distribution.Zero != null )
                {
                    s += "0:" +
                         Distribution.Zero.Type.ToString() + ":" +
                         string.Join( " ", Distribution.Zero.ParameterNames ) + ":" +
                         string.Join( " ", Distribution.Zero.ParameterValues ) + ":0|";
                }
                return s;
            }
            set
            {
                IDistribution positive = null;
                IDistribution negative = null;
                IDistribution zero = null;

                var signparts = value.Split( '|' );
                foreach( var signpart in signparts )
                {
                    if( signpart == string.Empty )
                    {
                        continue;
                    }

                    var dataparts = signpart.Split( ':' );
                    var type = (DistributionType)Enum.Parse( typeof( DistributionType ), dataparts[1] );
                    var distribution = DistributionClass.CreateDistribution( type );
                    var names = dataparts[2].Split( ' ' );
                    var values = dataparts[3].Split( ' ' );
                    for( var i = 0; i < names.Length; i++ )
                    {
                        distribution.SetParameterValue( names[i], double.Parse( values[i] ) );
                    }

                    if( dataparts[0] == "+" )
                    {
                        positive = distribution;
                    }
                    else if( dataparts[0] == "-" )
                    {
                        negative = distribution;
                    }
                    else if( dataparts[0] == "0" )
                    {
                        zero = distribution;
                    }
                }

                Distribution = new Triple<IDistribution>( positive, negative, zero );
            }
        }

        #endregion

        private string markerName;

        public DistributionStandaloneMarker( string markerName )
        {
            this.markerName = markerName;
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
        public IDistribution Distribution { get; private set; }

        #endregion

        #region IHistogramMarker Members

        public HistogramDefinition Definition { get { return definition; } }
        public int[] Frequencies { get { return histogram.Frequencies; } }
        public double[] BinMidpoints { get { return definition.BinMidpoints; } }

        #endregion

        private string markerName;
        private HistogramDefinition definition;
        private Histogram histogram;

        public HistogramMarker( string computeId, IFeature feature, string markerName, Func<IFeatureItem, double> extractor, IDistribution distribution, HistogramDefinition definition, IEnumerable<double> values )
        {
            Feature = feature;
            this.markerName = markerName;
            ComputeId = computeId;
            Extractor = extractor;
            Distribution = distribution;
            this.definition = definition;

            var from = values.Where( v => !double.IsNegativeInfinity( v ) ).Min();
            var to = values.Where( v => !double.IsPositiveInfinity( v ) ).Max();
            this.histogram = new Histogram( definition, values, from, to );
        }
    }

    abstract class MarkerExtractorBase : IMarkerExtractor
    {
        abstract public IEnumerable<IMarker> Extract(
            string computeId, IFeature feature, IEnumerable<IFeatureItem> items, string markerName, DistributionType distributionType,
            Func<IFeatureItem, Triple<double>> valueExtractor, Triple<HistogramDefinition> definition );

        public IEnumerable<IMarker> Extract(
            string computeId, IFeature feature, IEnumerable<IFeatureItem> items, string markerName, DistributionType distributionType,
            Func<IFeatureItem, double> valueExtractor, HistogramDefinition definition )
        {
            return Extract( computeId, feature, items, markerName, distributionType,
                            ( i ) => new Triple<double>( valueExtractor( i ) ), new Triple<HistogramDefinition>( definition ) );
        }
    }

    class MarkerExtractor : MarkerExtractorBase
    {
        #region IMarkerExtractor Members

        public override IEnumerable<IMarker> Extract(
            string computeId, IFeature feature, IEnumerable<IFeatureItem> items, string markerName,
            DistributionType distributionType, Func<IFeatureItem, Triple<double>> valueExtractor, Triple<HistogramDefinition> definitions )
        {
            var markers = new List<IMarker>();

            var input = items.Select<IFeatureItem, Triple<double>>( i => valueExtractor( i ) );
            var positives = input.Select( i => i.Positive ).Where( v => !double.IsNaN( v ) );
            var negatives = input.Select( i => i.Negative ).Where( v => !double.IsNaN( v ) );
            var zeros = input.Select( i => i.Zero ).Where( v => !double.IsNaN( v ) );

            var havePositives = positives.Count() > 0;
            var haveNegatives = negatives.Count() > 0;
            var haveZeros = zeros.Count() > 0;

            // data sets
            IEstimate positiveEstimate = null;
            IEstimate negativeEstimate = null;
            IEstimate zeroEstimate = null;
            if( havePositives )
            {
                positiveEstimate = new Estimator().Estimate( distributionType, positives );
            }
            if( haveNegatives )
            {
                negativeEstimate = new Estimator().Estimate( distributionType, negatives );
            }
            if( haveZeros )
            {
                zeroEstimate = new Estimator().Estimate( distributionType, zeros );
            }

            markers.Add( new DistributionMarker(
                computeId, feature, markerName, valueExtractor,
                new Triple<IDistribution>( positiveEstimate, negativeEstimate, zeroEstimate ) )
            );

            if( havePositives )
            {
                Func<IFeatureItem, double> extractor = ( i ) => valueExtractor( i ).Positive;
                markers.Add( new StatisticsMarker( computeId, feature, markerName + "+", extractor, positiveEstimate, "Minimum", positiveEstimate.Minimum ) );
                markers.Add( new StatisticsMarker( computeId, feature, markerName + "+", extractor, positiveEstimate, "Maximum", positiveEstimate.Maximum ) );
                // TODO other specific parameters
                // markers.Add( new StatisticsMarker( computeId, feature, markerName, extractor, positiveEstimate, "Mean", positiveEstimate.MdfMean ) );
                // markers.Add( new StatisticsMarker( computeId, feature, markerName, extractor, positiveEstimate, "Sigma", positiveEstimate.MdfSigma ) );

                if( definitions.Positive != null )
                {
                    definitions.Positive.SupplyRange( positiveEstimate.Minimum, positiveEstimate.Maximum );
                    var histogram = new HistogramMarker( computeId, feature, markerName, extractor, positiveEstimate, definitions.Positive, positives );
                    markers.Add( histogram );
                    // TODO specific parameters
                    // var fit = new Estimator().Estimate( DistributionType.Gaussian, histogram );
                    // markers.Add( new StatisticsMarker( computeId, feature, markerName, extractor, fit, "hMean", fit.Mean ) );
                    // markers.Add( new StatisticsMarker( computeId, feature, markerName, extractor, fit, "hSigma", fit.Sigma ) );
                }
            }
            if( haveNegatives )
            {
                Func<IFeatureItem, double> extractor = ( i ) => valueExtractor( i ).Negative;
                markers.Add( new StatisticsMarker( computeId, feature, markerName + "-", extractor, negativeEstimate, "Minimum", negativeEstimate.Minimum ) );
                markers.Add( new StatisticsMarker( computeId, feature, markerName + "-", extractor, negativeEstimate, "Maximum", negativeEstimate.Maximum ) );
                // TODO other specific parameters
                // markers.Add( new StatisticsMarker( computeId, feature, markerName, extractor, negativeEstimate, "Mean", negativeEstimate.MdfMean ) );
                // markers.Add( new StatisticsMarker( computeId, feature, markerName, extractor, negativeEstimate, "Sigma", negativeEstimate.MdfSigma ) );

                if( definitions.Negative != null )
                {
                    definitions.Negative.SupplyRange( negativeEstimate.Minimum, negativeEstimate.Maximum );
                    var histogram = new HistogramMarker( computeId, feature, markerName, extractor, negativeEstimate, definitions.Negative, negatives );
                    markers.Add( histogram );
                    // TODO specific parameters
                    // var fit = new Estimator().Estimate( DistributionType.Gaussian, histogram );
                    // markers.Add( new StatisticsMarker( computeId, feature, markerName, extractor, fit, "hMean", fit.Mean ) );
                    // markers.Add( new StatisticsMarker( computeId, feature, markerName, extractor, fit, "hSigma", fit.Sigma ) );
                }
            }
            if( haveZeros )
            {
                Func<IFeatureItem, double> extractor = ( i ) => valueExtractor( i ).Negative;
                markers.Add( new StatisticsMarker( computeId, feature, markerName + "0", extractor, zeroEstimate, "Minimum", zeroEstimate.Minimum ) );
                markers.Add( new StatisticsMarker( computeId, feature, markerName + "0", extractor, zeroEstimate, "Maximum", zeroEstimate.Maximum ) );
                // TODO other specific parameters
                // markers.Add( new StatisticsMarker( computeId, feature, markerName, extractor, zeroEstimate, "Mean", zeroEstimate.MdfMean ) );
                // markers.Add( new StatisticsMarker( computeId, feature, markerName, extractor, zeroEstimate, "Sigma", zeroEstimate.MdfSigma ) );

                if( definitions.Zero != null )
                {
                    definitions.Zero.SupplyRange( zeroEstimate.Minimum, zeroEstimate.Maximum );
                    var histogram = new HistogramMarker( computeId, feature, markerName, extractor, zeroEstimate, definitions.Zero, zeros );
                    markers.Add( histogram );
                    // TODO specific parameters
                    // var fit = new Estimator().Estimate( DistributionType.Gaussian, histogram );
                    // markers.Add( new StatisticsMarker( computeId, feature, markerName, extractor, fit, "hMean", fit.Mean ) );
                    // markers.Add( new StatisticsMarker( computeId, feature, markerName, extractor, fit, "hSigma", fit.Sigma ) );
                }
            }

            return markers;
        }

        #endregion
    }
}
