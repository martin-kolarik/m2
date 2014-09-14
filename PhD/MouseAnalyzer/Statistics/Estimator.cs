using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer
{
    abstract class Estimate : IEstimate
    {
        internal static double InvPISqrt2 = 1 / Math.Sqrt( 2 * Math.PI );
        internal static double Sqrt2ByPI =  Math.Sqrt( 3 ) / Math.PI;

        #region IEstimate Members

        public DistributionType Distribution { get; private set; }
        public int Count { get; private set; }

        public double Minimum { get; private set; }
        public double Maximum { get; private set; }
        public double Average { get; private set; }
        public double Median { get; private set; }

        public abstract double f( double x );

        #endregion

        public Estimate( DistributionType distribution, bool allowOrdering )
        {
            Distribution = distribution;
            OrderingAllowed = allowOrdering;
        }

        internal void Populate( IEnumerable<double> source )
        {
            Count = source.Count();
            if( Count > 0 )
            {
                Minimum = source.First();
                Maximum = source.Last();
                Average = source.Average();
                if( OrderingAllowed )
                {
                    Median = 0.5 * source.Skip( ( Count-1 ) / 2 ).First() + 0.5 * source.Skip( Count / 2 ).First();
                }
            }
        }

        internal IEnumerable<double> SkipZeros( IEnumerable<double> unordered )
        {
            return unordered.Where( d => d != 0.0 );
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
                return source.Skip( (int)( leftModifier * count ) ).Take( (int)( ( leftModifier + rightModifier ) * count ) );
            }
            else
            {
                return source;
            }
        }

        internal bool OrderingAllowed { get; private set; }
    }

    class GaussianDatasetEstimate : Estimate
    {
        public double MdfMinimum { get; private set; }
        public double MdfMaximum { get; private set; }
        public double MdfAverage { get; private set; }

        public double Mean { get; private set; }
        public double Sigma { get; private set; }

        public double MdfMean { get; private set; }
        public double MdfSigma { get; private set; }

        public GaussianDatasetEstimate( IEnumerable<double> values, bool computeMedian, double leftModifier, double rightModifier ) : // values are unordered
            base( DistributionType.Gaussian, computeMedian || leftModifier != 0.0 || rightModifier != 0.0 )
        {
            var ordered = Order( values );
            Populate( ordered );

            Mean = Average;
            var squares = ordered.Select<double, double>( d => d * d ).Average();
            Sigma = Math.Sqrt( squares - Average * Average );

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
                MdfMean = Mean;
                MdfSigma = Sigma;
            }
        }

        public override double f( double x )
        {
            var z = ( x - MdfMean ) / MdfSigma;
            return InvPISqrt2 * Math.Exp( -0.5*z*z ) / MdfSigma;
        }
    }

    class GaussianHistogramEstimate : Estimate
    {
        public double Mean { get; private set; }
        public double Sigma { get; private set; }

        public GaussianHistogramEstimate( IHistogramMarker histogram ) :
            base( DistributionType.Gaussian, false )
        {
            var count = histogram.BinMidpoints.Length;
            var sumf = histogram.Frequencies.Sum();
            var M2 = 0.0;

            Mean = 0.0;
            for( var bin = 0; bin < count; bin++ )
            {
                var value = histogram.Frequencies[bin] * histogram.BinMidpoints[bin];
                Mean += value;
                M2 += value * histogram.BinMidpoints[bin];
            }
            Mean = Mean / sumf;
            M2 = M2 / sumf;

            Sigma = Math.Sqrt( M2 - Mean * Mean );
        }

        public override double f( double x )
        {
            var z = ( x - Mean ) / Sigma;
            return InvPISqrt2 * Math.Exp( -0.5*z*z ) / Sigma;
        }
    }

    class LogisticDatasetEstimate : Estimate
    {
        public double Mean { get; private set; }
        public double Sigma { get; private set; }

        public LogisticDatasetEstimate( IEnumerable<double> values, bool computeMedian ) : // values are unordered
            base( DistributionType.Logistic, computeMedian )
        {
            var ordered = Order( values );
            Populate( ordered );

            Mean = Average;

            var squares = ordered.Select<double, double>( d => d * d ).Average();
            Sigma = Math.Sqrt( squares - Mean * Mean ) * Sqrt2ByPI;
        }

        public override double f( double x )
        {
            var z = ( x - Mean ) / Sigma;
            var expz = Math.Exp( -z );
            var expzden = ( 1 + expz ) * ( 1 + expz );
            return expz / expzden / Sigma;
        }
    }

    class LogisticHistogramEstimate : Estimate
    {
        public double Mean { get; private set; }
        public double Sigma { get; private set; }

        public LogisticHistogramEstimate( IHistogramMarker histogram ) :
            base( DistributionType.Logistic, false )
        {
            var count = histogram.BinMidpoints.Length;
            var sumf = histogram.Frequencies.Sum();
            var M2 = 0.0;

            Mean = 0.0;
            for( var bin = 0; bin < count; bin++ )
            {
                var value = histogram.Frequencies[bin] * histogram.BinMidpoints[bin];
                Mean += value;
                M2 += value * histogram.BinMidpoints[bin];
            }
            Mean = Mean / sumf;
            M2 = M2 / sumf;

            Sigma = Math.Sqrt( M2 - Mean * Mean ) * Sqrt2ByPI;
        }

        public override double f( double x )
        {
            var z = ( x - Mean ) / Sigma;
            var expz = Math.Exp( -z );
            var expzden = ( 1 + expz ) * ( 1 + expz );
            return expz / expzden / Sigma;
        }
    }

    class LognormalDatasetEstimate : Estimate
    {
        public double Mu { get; private set; }
        public double Sigma { get; private set; }

        public LognormalDatasetEstimate( IEnumerable<double> values, bool computeMedian ) : // values are unordered
            base( DistributionType.Lognormal, computeMedian )
        {
            var filtered = SkipZeros( values );
            if( filtered.Count() == 0 )
            {
                return;
            }
            var ordered = Order( values );
            Populate( ordered );

            var logordered = ordered.Select<double, double>( d => Math.Log( d ) );

            Mu = logordered.Average();

            var squares = logordered.Select<double, double>( d => d * d ).Average();
            Sigma = Math.Sqrt( squares - Mu * Mu );
        }

        public override double f( double x )
        {
            var z = ( Math.Log( x ) - Mu ) / Sigma;
            return InvPISqrt2 * Math.Exp( -0.5*z*z ) / Sigma / x;
        }
    }

    class LognormalHistogramEstimate : Estimate
    {
        public double Mu { get; private set; }
        public double Sigma { get; private set; }

        public LognormalHistogramEstimate( IHistogramMarker histogram ) :
            base( DistributionType.Lognormal, false )
        {
            var count = histogram.BinMidpoints.Length;
            var sumf = histogram.Frequencies.Sum();
            var M2 = 0.0;

            Mu = 0.0;
            for( var bin = 0; bin < count; bin++ )
            {
                if( histogram.BinMidpoints[bin] == 0.0 )
                {
                    continue;
                }
                var value = histogram.Frequencies[bin] * Math.Log( histogram.BinMidpoints[bin] );
                Mu += value;
                M2 += value * Math.Log( histogram.BinMidpoints[bin] );
            }
            Mu = Mu / sumf;
            M2 = M2 / sumf;

            Sigma = Math.Sqrt( M2 - Mu * Mu );
        }

        public override double f( double x )
        {
            var z = ( Math.Log( x ) - Mu ) / Sigma;
            return InvPISqrt2 * Math.Exp( -0.5*z*z ) / Sigma / x;
        }
    }

    class InverseGaussianDatasetEstimate : Estimate
    {
        public double Mean { get; private set; }
        public double Lambda { get; private set; }

        public InverseGaussianDatasetEstimate( IEnumerable<double> values, bool computeMedian ) : // values are unordered
            base( DistributionType.InverseGaussian, computeMedian )
        {
            var filtered = SkipZeros( values );
            if( filtered.Count() == 0 )
            {
                return;
            }
            var ordered = Order( filtered );
            Populate( ordered );

            Mean = Average;

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
            var meanSquare = Mean * Mean;
            if( M2 == meanSquare ) // an error, distribution is not InverseGaussian
            {
                Lambda = 1.0;
            }
            else
            {
                Lambda = meanSquare * Mean / ( M2 - meanSquare );
            }
        }

        public override double f( double x )
        {
            var z = ( x - Mean ) / Mean;
            var Invx3 = 1 / ( x * x * x );
            return InvPISqrt2 * Math.Exp( -0.5*z*z*Lambda/x ) * Math.Sqrt( Lambda * Invx3 );
        }
    }

    class InverseGaussianHistogramEstimate : Estimate
    {
        public double Mean { get; private set; }
        public double Lambda { get; private set; }

        public InverseGaussianHistogramEstimate( IHistogramMarker histogram ) :
            base( DistributionType.InverseGaussian, false )
        {
            var count = histogram.BinMidpoints.Length;
            var sumf = histogram.Frequencies.Sum();
            var M2 = 0.0;

            Mean = 0.0;
            for( var bin = 0; bin < count; bin++ )
            {
                var value = histogram.Frequencies[bin] * histogram.BinMidpoints[bin];
                Mean += value;
                M2 += value * histogram.BinMidpoints[bin];
            }
            Mean = Mean / sumf;
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
            var meanSquare = Mean * Mean;
            if( M2 == meanSquare ) // an error, distribution is not InverseGaussian
            {
                Lambda = 1.0;
            }
            else
            {
                Lambda = meanSquare * Mean / ( M2 - meanSquare );
            }
        }

        public override double f( double x )
        {
            var z = ( x - Mean ) / Mean;
            var Invx3 = 1 / ( x * x * x );
            return InvPISqrt2 * Math.Exp( -0.5*z*z*Lambda/x ) * Math.Sqrt( Lambda * Invx3 );
        }
    }

    class Estimator : IEstimator
    {
        #region IEstimator Members

        public IEstimate Estimate( DistributionType distribution, IEnumerable<double> values, bool computeMedian, double leftModifier = 0.1, double rightModifier = 0.1 )
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
                default:
                    return null;
            }
        }

        #endregion
    }
}
