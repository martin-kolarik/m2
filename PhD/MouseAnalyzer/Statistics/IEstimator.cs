using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer
{
    public enum DistributionType
    {
        None,
        Gaussian,
        Lognormal,
        InverseGaussian,
        Logistic,
        Weibull,
        Gamma,
        Rayleigh,
        Spline
    }

    interface IDistribution
    {
        DistributionType Type { get; }

        double Deviation { get; }
        double Mean { get; }
        double Variance { get; }

        double f( double x );
        double p( double x, double sigma ); // x-sigmax/2..x+sigmax/2 probability is taken
        double p( double x ); // x-Deviation/2..x+Deviation/2 probability is taken

        IList<string> ParameterNames { get; }
        IList<double> ParameterValues { get; }

        void SetParameterValue( string name, double value );
    }

    interface IEstimate : IDistribution
    {
        int Count { get; }

        double Minimum { get; }
        double Maximum { get; }
        double Average { get; }
    }

    interface IEstimator
    {
        IEstimate Estimate( DistributionType distribution, IEnumerable<double> values, bool computeMedian, double leftModifier, double rightModifier );
        IEstimate Estimate( DistributionType distribution, IHistogramMarker histogram );
    }
}
