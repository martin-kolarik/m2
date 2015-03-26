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
        DataSource.SourceType Source { get; }
        Entity Entity { get; }

        IEnumerable<IFeatureItem> Items { get; }

        void ComputeMarkers( string computeId, bool cleanupProcessData = true );
        IEnumerable<IMarker> Markers { get; }
    }

    interface IFeature<F> : IFeature where F : IFeatureItem
    {
        bool AddItems( IEnumerable<F> items ); // returns if any new added
        IList<F> TypedItems { get; } // IList chosen to allow both forward and backward traversing
    }

    abstract class Feature
    {
        public string Name { get; private set; }
        public DataSource.SourceType Source { get { return Entity.Source; } }
        public Entity Entity { get; private set; }
        public IEnumerable<IMarker> Markers { get { return _Markers; } }

        public Feature( string name, Entity entity )
        {
            Name = name;
            Entity = entity;
            _Markers = new List<IMarker>();
        }

        internal List<IMarker> _Markers { get; private set; }
    }
}
