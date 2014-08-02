using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer
{
    interface IFeatureItem
    {
    }

    interface IFeatureExtractor<F> where F : IFeatureItem
    {
        IEnumerable<F> AddEvent( Event input, IList<F> previousItems );
    }

    interface IFeature
    {
        string Name { get; }

        void ComputeMarkers();
        IEnumerable<IMarker> Markers { get; }
    }

    interface IFeature<F> : IFeature where F : IFeatureItem
    {
        void AddItems( IEnumerable<F> items );
        IList<F> Items { get; } // IList chosen to allow both forward and backward traversing
    }
}
