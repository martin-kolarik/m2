using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer
{
    interface IMarker
    {
        string Name { get; }
        IFeature Feature { get; } // of feature
    }

    interface IValueMarker : IMarker
    {
        double Value { get; }
    }

    interface IHistogramMarker : IMarker
    {
        double[] BinMidpoints { get; }
        int[] Frequencies { get; }
    }

    interface IMarkerExtractor
    {
        IEnumerable<IMarker> Extract( IFeature feature, IEnumerable<IFeatureItem> items, string featureName, Func<IFeatureItem, double> valueExtractor, int bins );
    }
}
