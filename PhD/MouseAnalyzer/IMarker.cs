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
        double Value { get; }
    }

    interface IMarkerExtractor
    {
        IEnumerable<IMarker> Extract( IFeature feature, IEnumerable<IFeatureItem> items, Func<IFeatureItem, double> valueExtractor );
    }
}
