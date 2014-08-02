using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer
{
    class Estimate : IEstimate
    {
        #region IEstimate Members

        public DistributionType Distribution { get; private set; }
        public int Count { get; private set; }

        public double Minimum { get; private set; }
        public double Maximum { get; private set; }
        public double Average { get; private set; }
        public double Median { get; private set; }

        #endregion

        public Estimate( DistributionType distribution )
        {
            Distribution = distribution;
        }

        internal void Populate( IEnumerable<double> ordered )
        {
            Count = ordered.Count();

            Minimum = ordered.First();
            Maximum = ordered.Last();
            Average = ordered.Average();
            Median = 0.5 * ordered.Skip( ( Count-1 ) / 2 ).First() + 0.5 * ordered.Skip( Count / 2 ).First();
        }

        internal static IEnumerable<double> SkipZeros( IEnumerable<double> unordered )
        {
            return unordered.Where( d => d != 0.0 );
        }

        internal static IEnumerable<double> Order( IEnumerable<double> unordered )
        {
            return unordered.OrderBy( v => v );
        }

        internal static IEnumerable<double> Reduce( IEnumerable<double> ordered, double leftModifier, double rightModifier )
        {
            var count = ordered.Count();
            return ordered.Skip( (int)( leftModifier * count ) ).Take( (int)( ( leftModifier + rightModifier ) * count ) );
        }
    }

    class GaussianEstimate : Estimate
    {
        public double MdfMinimum { get; private set; }
        public double MdfMaximum { get; private set; }
        public double MdfAverage { get; private set; }

        public double Mean { get; private set; }
        public double Variance { get; private set; }

        public double MdfMean { get; private set; }
        public double MdfVariance { get; private set; }

        public GaussianEstimate( IEnumerable<double> values, double leftModifier, double rightModifier ) : // values are unordered
            base( DistributionType.Gaussian )
        {
            var ordered = Order( values );
            Populate( ordered );

            Mean = Average;
            var squares = ordered.Select<double, double>( d => d * d ).Average();
            Variance = squares - Mean * Mean;

            if( leftModifier != 0.0 || rightModifier != 0.0 )
            {
                var modified = Reduce( ordered, leftModifier, rightModifier );
                MdfMinimum = modified.First();
                MdfMaximum = modified.Last();
                MdfAverage = modified.Average();
                MdfMean = MdfAverage;
                var modifiedSquares = modified.Select<double, double>( d => d * d ).Average();
                MdfVariance = modifiedSquares - MdfMean * MdfMean;
            }
            else
            {
                MdfMinimum = Minimum;
                MdfMaximum = Maximum;
                MdfAverage = Average;
                MdfMean = Mean;
                MdfVariance = Variance;
            }
        }
    }

    class LognormalEstimate : Estimate
    {
        public double Mu { get; private set; }
        public double Sigma { get; private set; }

        public LognormalEstimate( IEnumerable<double> values ) : // values are unordered
            base( DistributionType.Lognormal )
        {
            var ordered = Order( values );
            Populate( ordered );

            var logordered = SkipZeros( ordered ).Select<double, double>( d => Math.Log( d ) );
            Mu = logordered.Average();
            var squares = logordered.Select<double, double>( d => d * d ).Average();
            Sigma = Math.Sqrt( squares - Mu * Mu );
        }
    }

    class LognormalFit : Estimate
    {
        public double Mu { get; private set; }
        public double Sigma { get; private set; }

        public LognormalFit( IHistogramMarker histogram ) :
            base( DistributionType.InverseGaussian )
        {
            var count = histogram.BinMidpoints.Length;
            var sumf = histogram.Frequencies.Sum();
            var M2 = 0.0;

            Mu = 0.0;
            for( var bin = 0; bin < count; bin++ )
            {
                var value = histogram.Frequencies[bin] * Math.Log( histogram.BinMidpoints[bin] );
                Mu += value;
                M2 += value * Math.Log( histogram.BinMidpoints[bin] );
            }
            Mu = Mu / sumf;
            M2 = M2 / sumf;

            Sigma = Math.Sqrt( M2 - Mu * Mu );
        }
    }

    class InverseGaussianEstimate : Estimate
    {
        public double Mean { get; private set; }
        public double Lambda1 { get; private set; }
        public double Lambda2 { get; private set; }

        public InverseGaussianEstimate( IEnumerable<double> values ) : // values are unordered
            base( DistributionType.InverseGaussian )
        {
            var ordered = Order( values );
            Populate( ordered );

            var filtered = SkipZeros( ordered );
            Mean = filtered.Average();
            Lambda1 = filtered.Select<double, double>( d => ( 1 / d - 1 / Mean )).Average();
            Lambda1 = Count / Lambda1;

            var M2 = filtered.Select( d => d * d ).Average();
            var meanSquare = Mean * Mean;
            Lambda2 = meanSquare * Mean / ( M2 - meanSquare );
        }
    }

    class InverseGaussianFit : Estimate
    {
        public double Mean { get; private set; }
        public double Lambda1 { get; private set; }
        public double Lambda2 { get; private set; }

        public InverseGaussianFit( IHistogramMarker histogram ) :
            base( DistributionType.InverseGaussian )
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
            var invMean = 1.0 / Mean;
            Lambda1 = 0.0;
            for( var bin = 0; bin < count; bin++ )
            {
                Lambda1 += histogram.Frequencies[bin] * ( 1 / histogram.BinMidpoints[bin] - invMean );
            }
            Lambda1 = sumf / Lambda1;

            // Momentum estimation of Lambda
            // http://is.muni.cz/th/357381/prif_b/bp.pdf
            var meanSquare = Mean * Mean;
            Lambda2 = meanSquare * Mean / ( M2 - meanSquare );
        }
    }

    class Estimator : IEstimator
    {
        #region IEstimator Members

        public IEstimate Estimate( DistributionType distribution, IEnumerable<double> values, double leftModifier = 0.1, double rightModifier = 0.1 )
        {
            switch( distribution )
            {
                case DistributionType.Gaussian :
                    return new GaussianEstimate( values, leftModifier, rightModifier );
                case DistributionType.Lognormal :
                    return new LognormalEstimate( values );
                case DistributionType.InverseGaussian:
                    return new InverseGaussianEstimate( values );
                default:
                    return null;
            }
        }

        public IEstimate Fit( DistributionType distribution, IHistogramMarker histogram )
        {
            switch( distribution )
            {
                case DistributionType.Gaussian:
                    // return new GaussianFit( histogram );
                case DistributionType.Lognormal:
                    return new LognormalFit( histogram );
                case DistributionType.InverseGaussian:
                    return new InverseGaussianFit( histogram );
                default:
                    return null;
            }
        }

        #endregion
    }
}
