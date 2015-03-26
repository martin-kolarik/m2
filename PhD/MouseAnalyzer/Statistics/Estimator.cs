using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using MouseAnalyzer.Statistics;

namespace MouseAnalyzer
{
    abstract class DistributionClass : IDistribution
    {
        public static double InvPISqrt2 = 1 / Math.Sqrt( 2 * Math.PI );
        public static double Sqrt3ByPI =  Math.Sqrt( 3 ) / Math.PI;
        public static double PIBySqrt3 =  Math.PI / Math.Sqrt( 3 );

        #region IDistribution Members

        public DistributionType Type
        {
            get; private set;
        }

        public double Mean
        {
            get; set;
        }

        public double Variance
        {
            get; set;
        }

        public double Deviation
        {
            get; set;
        }

        public abstract double f( double x );

        public double p( double x, double sigma )
        {
            sigma *= 0.5;
            var r = Integrator.Integrate( i => f( i ), x - sigma, x + sigma );
            if( double.IsInfinity( r ) )
            {
                var rr = r;
            }
            return r;
        }

        public double p( double x )
        {
            return p( x, 0.01 * Deviation );
        }

        public abstract IList<string> ParameterNames { get; }
        public abstract IList<double> ParameterValues { get; }

        public abstract void SetParameterValue( string name, double value );

        #endregion

        public DistributionClass()
        {
        }

        public static IDistribution CreateDistribution( DistributionType type )
        {
            DistributionClass distribution;
            switch( type )
            {
                case DistributionType.Gamma:
                    distribution = new GammaDistribution();
                    break;
                case DistributionType.Gaussian:
                    distribution = new GaussianDistribution();
                    break;
                case DistributionType.InverseGaussian:
                    distribution = new InverseGaussianDistribution();
                    break;
                case DistributionType.Logistic:
                    distribution = new LogisticDistribution();
                    break;
                case DistributionType.Lognormal:
                    distribution = new LognormalDistribution();
                    break;
                case DistributionType.Rayleigh:
                    distribution = new RayleighDistribution();
                    break;
                case DistributionType.Weibull:
                    distribution = new WeibullDistribution();
                    break;
                case DistributionType.Spline:
                    distribution = new SplineDistribution();
                    break;
                default:
                    throw new Exception( "Unsupported distribution" );
            }
            distribution.Type = type;
            return distribution;
        }
    }

    abstract class Estimate : IEstimate
    {
        #region IDistribution Members

        public DistributionType Type
        {
            get { return Distribution.Type; }
        }

        public double Mean
        {
            get { return Distribution.Mean; }
        }

        public double Variance
        {
            get { return Distribution.Variance; }
        }

        public double Deviation
        {
            get { return Distribution.Deviation; }
        }

        public double f( double x )
        {
            return Distribution.f( x );
        }

        public double p( double x, double sigma )
        {
            return Distribution.p( x, sigma );
        }

        public double p( double x )
        {
            return Distribution.p( x );
        }

        public IList<string> ParameterNames
        {
            get { return Distribution.ParameterNames; }
        }

        public IList<double> ParameterValues
        {
            get { return Distribution.ParameterValues; }
        }

        public void SetParameterValue( string name, double value )
        {
            Distribution.SetParameterValue( name, value );
        }

        #endregion

        #region IEstimate Members

        public int Count { get; private set; }

        public double Minimum { get; private set; }
        public double Maximum { get; private set; }
        public double Average { get; private set; }

        #endregion

        public Estimate( DistributionType type, bool allowOrdering )
        {
            Distribution = DistributionClass.CreateDistribution( type );
            OrderingAllowed = allowOrdering;
        }

        internal void Populate( IEnumerable<double> source )
        {
            Count = source.Count();
            if( Count > 0 )
            {
                Average = source.Average();
                if( OrderingAllowed )
                {
                    Minimum = source.First();
                    Maximum = source.Last();
                }
                else
                {
                    Minimum = source.Min();
                    Maximum = source.Max();
                }
            }
        }

        internal IEnumerable<double> SkipZeros( IEnumerable<double> unordered, bool alsoNegatives = false )
        {
            return unordered.Where( d => alsoNegatives ? d > 0.0 : d != 0.0 );
        }

        internal IEnumerable<double> Order( IEnumerable<double> unordered )
        {
            if( OrderingAllowed )
            {
                return unordered.OrderBy( v => v );
            }
            else
            {
                return unordered;
            }
        }

        internal IEnumerable<double> Reduce( IEnumerable<double> source, double leftModifier, double rightModifier )
        {
            if( OrderingAllowed )
            {
                var count = source.Count();
                var left = (int)( leftModifier * count );
                var mid = (int)( ( leftModifier + rightModifier ) * count );
                if( left == 0 || mid == 0 )
                {
                    return source;
                }
                else
                {
                    return source.Skip( left ).Take( mid );
                }
            }
            else
            {
                return source;
            }
        }

        internal bool OrderingAllowed { get; private set; }
        internal readonly IDistribution Distribution;
    }

    class GaussianDistribution : DistributionClass
    {
        public double Sigma { get; set; }

        public override double f( double x )
        {
            if( Sigma == 0.0 )
            {
                return 0.0;
            }
            else
            {
                var z = ( x - Mean ) / Sigma;
                return InvPISqrt2 * Math.Exp( -0.5*z*z ) / Sigma;
            }
        }

        public override IList<string> ParameterNames
        {
            get { return NAMES; }
        }

        public override IList<double> ParameterValues
        {
            get { return new List<double> { Mean, Variance, Sigma }; }
        }

        public override void SetParameterValue( string parameterName, double value )
        {
            if( parameterName == NAMES[0] ) {
                Mean = value;
            } else if( parameterName == NAMES[1] ) {
                Variance = value;
                Deviation = Math.Sqrt( Variance );
            } else if( parameterName == NAMES[2] ) {
                Sigma = value;
            } else {
                throw new Exception( "Unknown parameter name" );
            }
        }

        private static List<string> NAMES = new List<string> { "Mean", "Variance", "Sigma" };
    }

    class LogisticDistribution : DistributionClass
    {
        public double Sigma { get; set; }

        public override double f( double x )
        {
            if( Sigma == 0.0 )
            {
                return 0.0;
            }
            else
            {
                var z = ( x - Mean ) / Sigma;
                var expz = Math.Exp( -z );
                var expzden = ( 1 + expz ) * ( 1 + expz );
                return expz / expzden / Sigma;
            }
        }

        public override IList<string> ParameterNames
        {
            get { return NAMES; }
        }

        public override IList<double> ParameterValues
        {
            get { return new List<double> { Mean, Variance, Sigma }; }
        }

        public override void SetParameterValue( string parameterName, double value )
        {
            if( parameterName == NAMES[0] ) {
                Mean = value;
            } else if( parameterName == NAMES[1] ) {
                Variance = value;
                Deviation = Math.Sqrt( Variance );
            } else if( parameterName == NAMES[2] ) {
                Sigma = value;
            } else {
                throw new Exception( "Unknown parameter name" );
            }
        }

        private static List<string> NAMES = new List<string> { "Mean", "Variance", "Sigma" };
    }

    class LognormalDistribution : DistributionClass
    {
        public double Mu { get; set; }
        public double Sigma { get; set; }

        public override double f( double x )
        {
            if( x <= 0.0 || Sigma == 0.0 )
            {
                return 0.0;
            }
            else
            {
                var z = ( Math.Log( x ) - Mu ) / Sigma;
                return InvPISqrt2 * Math.Exp( -0.5*z*z ) / Sigma / x;
            }
        }

        public override IList<string> ParameterNames
        {
            get { return NAMES; }
        }

        public override IList<double> ParameterValues
        {
            get { return new List<double> { Mean, Variance, Mu, Sigma }; }
        }

        public override void SetParameterValue( string parameterName, double value )
        {
            if( parameterName == NAMES[0] ) {
                Mean = value;
            } else if( parameterName == NAMES[1] ) {
                Variance = value;
                Deviation = Math.Sqrt( Variance );
            } else if( parameterName == NAMES[2] ) {
                Mu = value;
            } else if( parameterName == NAMES[3] ) {
                Sigma = value;
            } else {
                throw new Exception( "Unknown parameter name" );
            }
        }

        private static List<string> NAMES = new List<string> { "Mean", "Variance", "Mu", "Sigma" };
    }

    class InverseGaussianDistribution : DistributionClass
    {
        public double Lambda { get; set; }

        public override double f( double x )
        {
            if( x <= 0.0 || Mean == 0.0 )
            {
                return 0;
            }
            else
            {
                var z = ( x - Mean ) / Mean;
                var Invx3 = 1 / ( x * x * x );
                var fx = InvPISqrt2 * Math.Exp( -0.5*z*z*Lambda/x ) * Math.Sqrt( Lambda * Invx3 );
                return fx;
            }
        }

        public override IList<string> ParameterNames
        {
            get { return NAMES; }
        }

        public override IList<double> ParameterValues
        {
            get { return new List<double> { Mean, Variance, Lambda }; }
        }

        public override void SetParameterValue( string parameterName, double value )
        {
            if( parameterName == NAMES[0] ) {
                Mean = value;
            } else if( parameterName == NAMES[1] ) {
                Variance = value;
                Deviation = Math.Sqrt( Variance );
            } else if( parameterName == NAMES[2] ) {
                Lambda = value;
            } else {
                throw new Exception( "Unknown parameter name" );
            }
        }

        private static List<string> NAMES = new List<string> { "Mean", "Variance", "Lambda" };
    }

    class WeibullDistribution : DistributionClass
    {
        public double Alpha { get; set; }
        public double Beta { get; set; }

        public override double f( double x )
        {
            if( x < 0.0 || Beta == 0.0 )
            {
                return 0;
            }
            else
            {
                var xreduced = x / Beta;
                var r = Alpha / Beta * Math.Pow( xreduced, Alpha - 1 ) * Math.Exp( -Math.Pow( xreduced, Alpha ) );
                if( double.IsInfinity( r ) )
                {
                    var rr = r;
                }
                return r;
            }
        }

        public override IList<string> ParameterNames
        {
            get { return NAMES; }
        }

        public override IList<double> ParameterValues
        {
            get { return new List<double> { Mean, Variance, Alpha, Beta }; }
        }

        public override void SetParameterValue( string parameterName, double value )
        {
            if( parameterName == NAMES[0] ) {
                Mean = value;
            } else if( parameterName == NAMES[1] ) {
                Variance = value;
                Deviation = Math.Sqrt( Variance );
            } else if( parameterName == NAMES[2] ) {
                Alpha = value;
            } else if( parameterName == NAMES[3] ) {
                Beta = value;
            } else {
                throw new Exception( "Unknown parameter name" );
            }
        }

        private static List<string> NAMES = new List<string> { "Mean", "Variance", "Alpha", "Beta" };
    }

    class GammaDistribution : DistributionClass
    {
        public double Alpha
        {
            get
            {
                return alpha;
            }
            set
            {
                alpha = value;
                invGammaAlpha = 1.0 / Gamma.Function( Alpha );
                thetaToNegAlpha = Math.Pow( Theta, -Alpha );
            }
        }

        public double Theta
        {
            get
            {
                return theta;
            }
            set
            {
                theta = value;
                thetaToNegAlpha = Math.Pow( Theta, -Alpha );
            }
        }

        private double alpha;
        private double theta;
        private double invGammaAlpha = 0.0; // for speed up f()
        private double thetaToNegAlpha = 0.0; // for speed up f()

        public override double f( double x )
        {
            if( x <= 0.0 )
            {
                return 0;
            }
            else
            {
                var xpow = Math.Pow( x, Alpha - 1.0 );
                var epow = Math.Exp( -x / Theta );
                return thetaToNegAlpha * xpow * epow * invGammaAlpha;
            }
        }

        public override IList<string> ParameterNames
        {
            get { return NAMES; }
        }

        public override IList<double> ParameterValues
        {
            get { return new List<double> { Mean, Variance, Alpha, Theta }; }
        }

        public override void SetParameterValue( string parameterName, double value )
        {
            if( parameterName == NAMES[0] ) {
                Mean = value;
            } else if( parameterName == NAMES[1] ) {
                Variance = value;
                Deviation = Math.Sqrt( Variance );
            } else if( parameterName == NAMES[2] ) {
                Alpha = value;
            } else if( parameterName == NAMES[3] ) {
                Theta = value;
            } else {
                throw new Exception( "Unknown parameter name" );
            }
        }

        private static List<string> NAMES = new List<string> { "Mean", "Variance", "Alpha", "Theta" };
    }

    class RayleighDistribution : DistributionClass
    {
        public double Sigma { get; set; }

        public override double f( double x )
        {
            if( x < 0.0 )
            {
                return 0;
            }
            else
            {
                var xInvSigmaSquare = x / ( Sigma*Sigma );
                return xInvSigmaSquare * Math.Exp( -0.5 * x * xInvSigmaSquare );
            }
        }

        public override IList<string> ParameterNames
        {
            get { return NAMES; }
        }

        public override IList<double> ParameterValues
        {
            get { return new List<double> { Mean, Variance, Sigma }; }
        }

        public override void SetParameterValue( string parameterName, double value )
        {
            if( parameterName == NAMES[0] ) {
                Mean = value;
            } else if( parameterName == NAMES[1] ) {
                Variance = value;
                Deviation = Math.Sqrt( Variance );
            } else if( parameterName == NAMES[2] ) {
                Sigma = value;
            } else {
                throw new Exception( "Unknown parameter name" );
            }
        }

        private static List<string> NAMES = new List<string> { "Mean", "Variance", "Sigma" };
    }

    class SplineDistribution : DistributionClass
    {
        public SmoothingSpline Spline { get; set; }

        public override double f( double x )
        {
            var f = Spline.Evaluate( x );
            return f < 0.0 ? -0.1 * f : f; // do not allow returning negative values for density
        }

        public override IList<string> ParameterNames
        {
            get { return NAMES; }
        }

        public override IList<double> ParameterValues
        {
            get { return new List<double> { 0.0, 0.0, 0.0 }; }
        }

        public override void SetParameterValue( string parameterName, double value )
        {
            throw new NotImplementedException();
        }

        public static SmoothingSpline ComputeSpline( double[] binMidpoints, double binWidth, int[] frequencies )
        {
            // model pdf with splines
            var integral = frequencies.Select( f => f * binWidth ).Sum(); // integral will normalize frequencies values
            var prbf = frequencies.Select( f => (double)(f) / integral );

            // create zero tails
            var binMidpointsCount = binMidpoints.Length;
            var midpoints = new List<double>();
            for( var i = 20; i >= 1; i-- )
            {
                midpoints.Add( binMidpoints[0] - i*binWidth );
            }
            midpoints.AddRange( binMidpoints );
            for( var i = 1; i <= 20; i++ )
            {
                midpoints.Add( binMidpoints[binMidpointsCount-1] + i*binWidth );
            }
            var prb = new List<double>();
            for( var i = 1; i <= 20; i++ )
            {
                prb.Add( 0 );
            }
            prb.AddRange( prbf );
            for( var i = 1; i <= 20; i++ )
            {
                prb.Add( 0 );
            }

            // compute spline
            return new Statistics.SmoothingSpline( midpoints, prb, null, 0.999999 );
        }

        private static List<string> NAMES = new List<string> { "X", "Y", "Z" };
    }

    class GaussianDatasetEstimate : Estimate
    {
        public double MdfMinimum { get; private set; }
        public double MdfMaximum { get; private set; }
        public double MdfAverage { get; private set; }

        public double MdfMean { get; private set; }
        public double MdfSigma { get; private set; }

        public GaussianDatasetEstimate( IEnumerable<double> values, bool computeMedian, double leftModifier, double rightModifier ) : // values are unordered
            base( DistributionType.Gaussian, computeMedian || leftModifier != 0.0 || rightModifier != 0.0 )
        {
            var distribution = (GaussianDistribution)Distribution;

            var ordered = Order( values );
            Populate( ordered );

            var squares = ordered.Select<double, double>( d => d * d ).Average();
            distribution.Sigma = Math.Sqrt( squares - Average * Average );

            if( leftModifier != 0.0 || rightModifier != 0.0 )
            {
                var modified = Reduce( ordered, leftModifier, rightModifier );
                MdfMinimum = modified.First();
                MdfMaximum = modified.Last();
                MdfAverage = modified.Average();
                MdfMean = MdfAverage;
                var modifiedSquares = modified.Select<double, double>( d => d * d ).Average();
                MdfSigma = Math.Sqrt( modifiedSquares - MdfAverage * MdfAverage );
            }
            else
            {
                MdfMinimum = Minimum;
                MdfMaximum = Maximum;
                MdfAverage = Average;
                MdfMean = Average;
                MdfSigma = distribution.Sigma;
            }

            distribution.Mean = MdfAverage;
            distribution.Variance = MdfSigma * MdfSigma;
            distribution.Deviation = MdfSigma;
        }
    }

    class GaussianHistogramEstimate : Estimate
    {
        public double Sigma
        {
            get { return ((GaussianDistribution)Distribution).Sigma; }
        }

        public GaussianHistogramEstimate( IHistogramMarker histogram ) :
            base( DistributionType.Gaussian, false )
        {
            var distribution = (GaussianDistribution)Distribution;

            var count = histogram.BinMidpoints.Length;
            var sumf = histogram.Frequencies.Sum();
            var M2 = 0.0;

            distribution.Mean = 0.0;
            for( var bin = 0; bin < count; bin++ )
            {
                var value = histogram.Frequencies[bin] * histogram.BinMidpoints[bin];
                distribution.Mean += value;
                M2 += value * histogram.BinMidpoints[bin];
            }
            distribution.Mean = distribution.Mean / sumf;
            M2 = M2 / sumf;

            distribution.Variance = M2 - distribution.Mean * distribution.Mean;
            distribution.Deviation = Math.Sqrt( distribution.Variance );
            distribution.Sigma = distribution.Deviation;
        }
    }

    class LogisticDatasetEstimate : Estimate
    {
        public double Sigma
        {
            get { return ((LogisticDistribution)Distribution).Sigma; }
        }

        public LogisticDatasetEstimate( IEnumerable<double> values, bool computeMedian ) : // values are unordered
            base( DistributionType.Logistic, computeMedian )
        {
            var distribution = (LogisticDistribution)Distribution;

            var ordered = Order( values );
            Populate( ordered );

            distribution.Mean = Average;

            var squares = ordered.Select<double, double>( d => d * d ).Average();
            distribution.Variance = squares - distribution.Mean * distribution.Mean;
            distribution.Deviation = Math.Sqrt( distribution.Variance );
            distribution.Sigma = distribution.Deviation * DistributionClass.Sqrt3ByPI;
        }
    }

    class LogisticHistogramEstimate : Estimate
    {
        public double Sigma
        {
            get { return ((LogisticDistribution)Distribution).Sigma; }
        }

        public LogisticHistogramEstimate( IHistogramMarker histogram ) :
            base( DistributionType.Logistic, false )
        {
            var distribution = (LogisticDistribution)Distribution;

            var count = histogram.BinMidpoints.Length;
            var sumf = histogram.Frequencies.Sum();
            var M2 = 0.0;

            distribution.Mean = 0.0;
            for( var bin = 0; bin < count; bin++ )
            {
                var value = histogram.Frequencies[bin] * histogram.BinMidpoints[bin];
                distribution.Mean += value;
                M2 += value * histogram.BinMidpoints[bin];
            }
            distribution.Mean = distribution.Mean / sumf;
            M2 = M2 / sumf;

            distribution.Variance = M2 - distribution.Mean * distribution.Mean;
            distribution.Deviation = Math.Sqrt( distribution.Variance );
            distribution.Sigma = distribution.Deviation * DistributionClass.Sqrt3ByPI;
        }
    }

    class LognormalDatasetEstimate : Estimate
    {
        public double Mu
        {
            get { return ((LognormalDistribution)Distribution).Mu; }
        }

        public double Sigma
        {
            get { return ((LognormalDistribution)Distribution).Sigma; }
        }

        public LognormalDatasetEstimate( IEnumerable<double> values, bool computeMedian ) : // values are unordered
            base( DistributionType.Lognormal, computeMedian )
        {
            var distribution = (LognormalDistribution)Distribution;

            var filtered = SkipZeros( values, true );
            if( filtered.Count() == 0 )
            {
                return;
            }
            var ordered = Order( filtered );
            Populate( ordered );

            var logordered = ordered.Select<double, double>( d => Math.Log( d ) );

            distribution.Mu = logordered.Average();

            var squares = logordered.Select<double, double>( d => d * d ).Average();
            var sigmasquare = squares - distribution.Mu * distribution.Mu;
            distribution.Sigma = Math.Sqrt( sigmasquare );

            distribution.Mean = Math.Exp( distribution.Mu + 0.5 * sigmasquare );
            distribution.Variance = ( Math.Exp( sigmasquare ) - 1 ) * Math.Exp( 2*distribution.Mu + sigmasquare );
            distribution.Deviation = Math.Sqrt( distribution.Variance );
        }
    }

    class LognormalHistogramEstimate : Estimate
    {
        public double Mu
        {
            get { return ((LognormalDistribution)Distribution).Mu; }
        }

        public double Sigma
        {
            get { return ((LognormalDistribution)Distribution).Sigma; }
        }

        public LognormalHistogramEstimate( IHistogramMarker histogram ) :
            base( DistributionType.Lognormal, false )
        {
            var distribution = (LognormalDistribution)Distribution;

            var count = histogram.BinMidpoints.Length;
            var sumf = histogram.Frequencies.Sum();
            var M2 = 0.0;

            distribution.Mu = 0.0;
            for( var bin = 0; bin < count; bin++ )
            {
                if( histogram.BinMidpoints[bin] <= 0.0 )
                {
                    continue;
                }
                var value = histogram.Frequencies[bin] * Math.Log( histogram.BinMidpoints[bin] );
                distribution.Mu += value;
                M2 += value * Math.Log( histogram.BinMidpoints[bin] );
            }
            distribution.Mu = distribution.Mu / sumf;
            M2 = M2 / sumf;

            var sigmasquare = M2 - distribution.Mu * distribution.Mu;
            distribution.Sigma = Math.Sqrt( sigmasquare );

            distribution.Mean = Math.Exp( distribution.Mu + 0.5 * sigmasquare );
            distribution.Variance = ( Math.Exp( sigmasquare ) - 1 ) * Math.Exp( 2*distribution.Mu + sigmasquare );
            distribution.Deviation = Math.Sqrt( distribution.Variance );
        }
    }

    class InverseGaussianDatasetEstimate : Estimate
    {
        public double Lambda
        {
            get { return ((InverseGaussianDistribution)Distribution).Lambda; }
        }

        public InverseGaussianDatasetEstimate( IEnumerable<double> values, bool computeMedian ) : // values are unordered
            base( DistributionType.InverseGaussian, computeMedian )
        {
            var distribution = (InverseGaussianDistribution)Distribution;

            var filtered = SkipZeros( values );
            if( filtered.Count() == 0 )
            {
                return;
            }
            var ordered = Order( filtered );
            Populate( ordered );

            distribution.Mean = Average;

            /* MLE method gives less acceptable results if low values (close 0], then momentum metod is more robust.
             * EasyFit uses Momentum for InverseGaussian as well.
             * Momentum method also gives the same results for Estimate (this class) and Histogram approach.
             * Differences were always caused by limiting histogram and not limiting data and vice versa.
             * 
            Lambda1 = filtered.Select<double, double>( d => ( 1 / d - 1 / Mean ) ).Average();
            Lambda1 = 1.0 / Lambda1;
             * */

            // Momentum estimation of Lambda
            // http://is.muni.cz/th/357381/prif_b/bp.pdf
            // EasyFit
            var M2 = ordered.Select( d => d * d ).Average();
            var meanSquare = distribution.Mean * distribution.Mean;
            if( M2 == meanSquare ) // an error, distribution is not InverseGaussian
            {
                distribution.Lambda = 1.0;
            }
            else
            {
                distribution.Lambda = meanSquare * distribution.Mean / ( M2 - meanSquare );
            }

            distribution.Variance = meanSquare*distribution.Mean / distribution.Lambda;
            distribution.Deviation = Math.Sqrt( distribution.Variance );
        }
    }

    class InverseGaussianHistogramEstimate : Estimate
    {
        public double Lambda
        {
            get { return ((InverseGaussianDistribution)Distribution).Lambda; }
        }

        public InverseGaussianHistogramEstimate( IHistogramMarker histogram ) :
            base( DistributionType.InverseGaussian, false )
        {
            var distribution = (InverseGaussianDistribution)Distribution;

            var count = histogram.BinMidpoints.Length;
            var sumf = histogram.Frequencies.Sum();
            var M2 = 0.0;

            distribution.Mean = 0.0;
            for( var bin = 0; bin < count; bin++ )
            {
                if( histogram.BinMidpoints[bin] <= 0.0 )
                {
                    continue;
                }
                var value = histogram.Frequencies[bin] * histogram.BinMidpoints[bin];
                distribution.Mean += value;
                M2 += value * histogram.BinMidpoints[bin];
            }
            distribution.Mean = distribution.Mean / sumf;
            M2 = M2 / sumf;

            // MLE estimation of Lambda
            /* MLE method gives less acceptable results if low values (close 0], then momentum metod is more robust.
             * EasyFit uses Momentum for InverseGaussian as well.
             * Momentum method also gives the same results for Estimate (this class) and Histogram approach.
             * Differences were always caused by limiting histogram and not limiting data and vice versa.
             * *
            var invMean = 1.0 / Mean;
            Lambda1 = 0.0;
            for( var bin = 0; bin < count; bin++ )
            {
                Lambda1 += histogram.Frequencies[bin] * ( 1 / histogram.BinMidpoints[bin] - invMean );
            }
            Lambda1 = sumf / Lambda1;
             * */

            // Momentum estimation of Lambda
            // http://is.muni.cz/th/357381/prif_b/bp.pdf
            // EasyFit
            var meanSquare = distribution.Mean * distribution.Mean;
            if( M2 == meanSquare ) // an error, distribution is not InverseGaussian
            {
                distribution.Lambda = 1.0;
            }
            else
            {
                distribution.Lambda = meanSquare * distribution.Mean / ( M2 - meanSquare );
            }

            distribution.Variance = meanSquare*distribution.Mean / distribution.Lambda;
            distribution.Deviation = Math.Sqrt( distribution.Variance );
        }
    }

    class WeibullDatasetEstimate : Estimate
    // http://stats.stackexchange.com/questions/60511/weibull-distribution-parameters-k-and-c-for-wind-speed-data
    // http://journals.ametsoc.org/doi/abs/10.1175/1520-0450%281978%29017%3C0350%3AMFEWSF%3E2.0.CO%3B2
    {
        public double Alpha
        {
            get { return ((WeibullDistribution)Distribution).Alpha; }
        }

        public double Beta
        {
            get { return ((WeibullDistribution)Distribution).Beta; }
        }

        public WeibullDatasetEstimate( IEnumerable<double> values, bool computeMedian ) : // values are unordered
            base( DistributionType.Weibull, true )
        {
            var distribution = (WeibullDistribution)Distribution;

            const double AlphaLog = 1.5725335836855191807855737661251; // = Math.Log( Math.Log( 0.25 ) / Math.Log( 0.75 ) )
            const double Log2 = 0.69314718055994530941723212145818;

            var ordered = Order( values );
            Populate( ordered );

            var count = ordered.Count();
            var q25data = ordered.Skip( count / 4 );
            var q25 = q25data.First();
            var q50data = q25data.Skip( count / 4 );
            var q50 = q50data.First();
            var q75data = q50data.Skip( count / 4 );
            var q75 = q75data.First();

            distribution.Alpha = AlphaLog / Math.Log( ( q75 + 0.000000001 ) / ( q25 + 0.000000001 ) );
            distribution.Beta = q50 / Math.Pow( Log2, 1 / distribution.Alpha );

            var g11byAlpha = Gamma.Function( 1 + 1 / distribution.Alpha );
            var g12byAlpha = Gamma.Function( 1 + 2 / distribution.Alpha );

            distribution.Mean = distribution.Beta * g11byAlpha;
            distribution.Variance = distribution.Beta*distribution.Beta * ( g12byAlpha - g11byAlpha * g11byAlpha );
            distribution.Deviation = Math.Sqrt( distribution.Variance );
        }
    }

    class WeibullHistogramEstimate : Estimate
    // http://academicjournals.org/article/article1380700010_Ahmed.pdf
    {
        public double Alpha
        {
            get { return ((WeibullDistribution)Distribution).Alpha; }
        }

        public double Beta
        {
            get { return ((WeibullDistribution)Distribution).Beta; }
        }

        public WeibullHistogramEstimate( IHistogramMarker histogram ) :
            base( DistributionType.Weibull, false )
        {
            var distribution = (WeibullDistribution)Distribution;

            var count = histogram.BinMidpoints.Length;
            var sumf = histogram.Frequencies.Sum();

            var M2 = 0.0;
            var mean = 0.0;
            for( var bin = 0; bin < count; bin++ )
            {
                if( histogram.BinMidpoints[bin] < 0.0 )
                {
                    continue;
                }
                var value = histogram.Frequencies[bin] * histogram.BinMidpoints[bin];
                mean += value;
                M2 += value * histogram.BinMidpoints[bin];
            }
            mean = mean / sumf;
            M2 = M2 / sumf;
            var sigma = Math.Sqrt( M2 - mean * mean );

            distribution.Alpha = Math.Pow( sigma / mean, -1.086 );
            distribution.Beta = mean / Gamma.Function( 1.0 + 1.0 / distribution.Alpha );

            var g11byAlpha = Gamma.Function( 1 + 1 / distribution.Alpha );
            var g12byAlpha = Gamma.Function( 1 + 2 / distribution.Alpha );

            distribution.Mean = distribution.Beta * g11byAlpha;
            distribution.Variance = distribution.Beta*distribution.Beta * ( g12byAlpha - g11byAlpha * g11byAlpha );
            distribution.Deviation = Math.Sqrt( distribution.Variance );
        }
    }

    class GammaDatasetEstimate : Estimate
    // http://www.itl.nist.gov/div898/handbook/eda/section3/eda366b.htm
    {
        public double Alpha
        {
            get { return ((GammaDistribution)Distribution).Alpha; }
        }

        public double Theta
        {
            get { return ((GammaDistribution)Distribution).Theta; }
        }

        public GammaDatasetEstimate( IEnumerable<double> values, bool computeMedian ) : // values are unordered
            base( DistributionType.Gamma, computeMedian )
        {
            var distribution = (GammaDistribution)Distribution;

            var filtered = SkipZeros( values );
            if( filtered.Count() == 0 )
            {
                return;
            }
            var ordered = Order( filtered );
            Populate( ordered );

            var M2 = ordered.Select( d => d * d ).Average();

            var var = M2 - Average * Average;
            distribution.Alpha = Average*Average / var;
            distribution.Theta = var / Average;

            distribution.Mean = distribution.Alpha * distribution.Theta;
            distribution.Variance = distribution.Alpha * distribution.Theta * distribution.Theta;
            distribution.Deviation = Math.Sqrt( distribution.Variance );
        }
    }

    class GammaHistogramEstimate : Estimate
    // http://www.itl.nist.gov/div898/handbook/eda/section3/eda366b.htm
    {
        public double Alpha
        {
            get { return ((GammaDistribution)Distribution).Alpha; }
        }

        public double Theta
        {
            get { return ((GammaDistribution)Distribution).Theta; }
        }

        public GammaHistogramEstimate( IHistogramMarker histogram ) :
            base( DistributionType.Gamma, false )
        {
            var distribution = (GammaDistribution)Distribution;

            var count = histogram.BinMidpoints.Length;
            var sumf = histogram.Frequencies.Sum();

            var M2 = 0.0;
            var mean = 0.0;
            for( var bin = 0; bin < count; bin++ )
            {
                if( histogram.BinMidpoints[bin] <= 0.0 )
                {
                    continue;
                }
                var value = histogram.Frequencies[bin] * histogram.BinMidpoints[bin];
                mean += value;
                M2 += value * histogram.BinMidpoints[bin];
            }
            mean = mean / sumf;
            M2 = M2 / sumf;

            var var = M2 - mean * mean;
            distribution.Alpha = mean*mean / var;
            distribution.Theta = var / mean;

            distribution.Mean = distribution.Alpha * distribution.Theta;
            distribution.Variance = distribution.Alpha * distribution.Theta * distribution.Theta;
            distribution.Deviation = Math.Sqrt( distribution.Variance );
        }
    }

    class RayleighDatasetEstimate : Estimate
    {
        public double Sigma
        {
            get { return ((RayleighDistribution)Distribution).Sigma; }
        }

        public RayleighDatasetEstimate( IEnumerable<double> values, bool computeMedian ) : // values are unordered
            base( DistributionType.Rayleigh, computeMedian )
        {
            var distribution = (RayleighDistribution)Distribution;

            var ordered = Order( values );
            Populate( ordered );

            distribution.Sigma = Average * Math.Sqrt( 2.0 / Math.PI );

            distribution.Mean = Average;
            distribution.Deviation = distribution.Sigma * Math.Sqrt( ( 4.0 - Math.PI ) / 2.0 );
            distribution.Variance = distribution.Deviation * distribution.Deviation;
        }
    }

    class RayleighHistogramEstimate : Estimate
    {
        public double Sigma
        {
            get { return ((RayleighDistribution)Distribution).Sigma; }
        }

        public RayleighHistogramEstimate( IHistogramMarker histogram ) :
            base( DistributionType.Rayleigh, false )
        {
            var distribution = (RayleighDistribution)Distribution;

            var count = histogram.BinMidpoints.Length;
            var sumf = histogram.Frequencies.Sum();

            var mean = 0.0;
            for( var bin = 0; bin < count; bin++ )
            {
                if( histogram.BinMidpoints[bin] < 0.0 )
                {
                    continue;
                }
                mean += histogram.Frequencies[bin] * histogram.BinMidpoints[bin];
            }
            mean = mean / sumf;

            distribution.Sigma = mean * Math.Sqrt( 2.0 / Math.PI );

            distribution.Mean = Average;
            distribution.Deviation = distribution.Sigma * Math.Sqrt( ( 4.0 - Math.PI ) / 2.0 );
            distribution.Variance = distribution.Deviation * distribution.Deviation;
        }
    }

    class SplineDatasetEstimate : Estimate
    {
        public SmoothingSpline Spline
        {
            get { return ((SplineDistribution)Distribution).Spline; }
        }

        public SplineDatasetEstimate( IEnumerable<double> values ) : // values are unordered
            base( DistributionType.Spline, false )
        {
            var distribution = (SplineDistribution)Distribution;

            var ordered = Order( values );
            Populate( ordered );

            var definition = new HistogramDefinition( 200 );
            definition.SupplyRange( Minimum, Maximum );
            var histogram = new Histogram( definition, values, Minimum, Maximum );

            distribution.Spline = SplineDistribution.ComputeSpline( definition.BinMidpoints, definition.BinWidth, histogram.Frequencies );

            distribution.Mean = Average;

            var squares = ordered.Select<double, double>( d => d * d ).Average();
            distribution.Variance = squares - distribution.Mean * distribution.Mean;
            distribution.Deviation = Math.Sqrt( distribution.Variance );

            // check
            /*
            var xs = histogram.BinMidpoints;
            var cxs = new double[2*definition.Bins-1]; // up-sample prb twice 
            cxs[0] = xs[0];
            for( var i = 1; i < definition.Bins; i++ )
            {
                cxs[2*i-1] = 0.5 * ( xs[i] + xs[i-1] );
                cxs[2*i-0] = xs[i];
            }
            var samples = cxs.Select( x => Spline.Evaluate( x ) ).ToArray();
            var checkintegral = Integrator.Integrate( x => Spline.Evaluate( x ), xs[0], xs[xs.Length-1], 10*xs.Length );
            */ 
        }
    }

    class SplineHistogramEstimate : Estimate
    {
        public SmoothingSpline Spline
        {
            get { return ((SplineDistribution)Distribution).Spline; }
        }

        public SplineHistogramEstimate( IHistogramMarker histogram ) :
            base( DistributionType.Spline, false )
        {
            var distribution = (SplineDistribution)Distribution;
            var definition = histogram.Definition;

            distribution.Spline = SplineDistribution.ComputeSpline( definition.BinMidpoints, definition.BinWidth, histogram.Frequencies );

            var count = histogram.BinMidpoints.Length;
            var sumf = histogram.Frequencies.Sum();
            var M = 0.0;
            var M2 = 0.0;
            for( var bin = 0; bin < count; bin++ )
            {
                var value = histogram.Frequencies[bin] * histogram.BinMidpoints[bin];
                M += value;
                M2 += value * histogram.BinMidpoints[bin];
            }
            M = M / sumf;
            M2 = M2 / sumf;

            distribution.Mean = M;
            distribution.Variance = M2 - distribution.Mean * distribution.Mean;
            distribution.Deviation = Math.Sqrt( distribution.Variance );

            // check
            /*
            var xs = histogram.BinMidpoints;
            var cxs = new double[2*definition.Bins-1]; // up-sample prb twice 
            cxs[0] = xs[0];
            for( var i = 1; i < definition.Bins; i++ )
            {
                cxs[2*i-1] = 0.5 * ( xs[i] + xs[i-1] );
                cxs[2*i-0] = xs[i];
            }
            var samples = cxs.Select( x => Spline.Evaluate( x ) ).ToArray();
            var checkintegral = Integrator.Integrate( x => Spline.Evaluate( x ), xs[0], xs[xs.Length-1], 10*xs.Length );
            */
        }
    }

    class Estimator : IEstimator
    {
        #region IEstimator Members

        public IEstimate Estimate( DistributionType distribution, IEnumerable<double> values, bool computeMedian = false, double leftModifier = 0.0, double rightModifier = 0.0 )
        {
            switch( distribution )
            {
                case DistributionType.Gaussian :
                    return new GaussianDatasetEstimate( values, computeMedian, leftModifier, rightModifier );
                case DistributionType.Lognormal :
                    return new LognormalDatasetEstimate( values, computeMedian );
                case DistributionType.InverseGaussian:
                    return new InverseGaussianDatasetEstimate( values, computeMedian );
                case DistributionType.Logistic:
                    return new LogisticDatasetEstimate( values, computeMedian );
                case DistributionType.Weibull:
                    return new WeibullDatasetEstimate( values, computeMedian );
                case DistributionType.Gamma:
                    return new GammaDatasetEstimate( values, computeMedian );
                case DistributionType.Rayleigh:
                    return new RayleighDatasetEstimate( values, computeMedian );
                case DistributionType.Spline:
                    return new SplineDatasetEstimate( values );
                default:
                    return null;
            }
        }

        public IEstimate Estimate( DistributionType distribution, IHistogramMarker histogram )
        {
            switch( distribution )
            {
                case DistributionType.Gaussian:
                    return new GaussianHistogramEstimate( histogram );
                case DistributionType.Lognormal:
                    return new LognormalHistogramEstimate( histogram );
                case DistributionType.InverseGaussian:
                    return new InverseGaussianHistogramEstimate( histogram );
                case DistributionType.Logistic:
                    return new LogisticHistogramEstimate( histogram );
                case DistributionType.Weibull:
                    return new WeibullHistogramEstimate( histogram );
                case DistributionType.Gamma:
                    return new GammaHistogramEstimate( histogram );
                case DistributionType.Rayleigh:
                    return new RayleighHistogramEstimate( histogram );
                case DistributionType.Spline:
                    return new SplineHistogramEstimate( histogram );
                default:
                    return null;
            }
        }

        #endregion
    }
}
