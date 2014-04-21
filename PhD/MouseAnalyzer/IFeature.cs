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
        F AddEvent( Event input, IEnumerable<F> previousItems );
    }

    interface IFeature
    {
        string Name { get; }

        void ComputeMarkers();
        IEnumerable<IMarker> Markers { get; }
    }

    interface IFeature<F> : IFeature where F : IFeatureItem
    {
        void AddItem( F item );
        IEnumerable<F> Items { get; }
    }
}
