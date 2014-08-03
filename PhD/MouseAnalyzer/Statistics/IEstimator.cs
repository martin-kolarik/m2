using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer
{
    public enum DistributionType
    {
        Gaussian,
        Lognormal,
        InverseGaussian
    }

    interface IEstimate
    {
        DistributionType Distribution { get; }
        int Count { get; }

        double Minimum { get; }
        double Maximum { get; }
        double Average { get; }
        double Median { get; }
    }

    interface IEstimator
    {
        IEstimate Estimate( DistributionType distribution, IEnumerable<double> values, double leftModifier = 0.1, double rightModifier = 0.1 );
        IEstimate Fit( DistributionType distribution, IHistogramMarker histogram );
    }
}
