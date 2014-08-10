using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer
{
    class Entity
    {
        private List<IFeature> features = new List<IFeature>();

        public Entity( string id, DataSource.SourceType source, IList<Event> events )
        {
            Id = id;
            Source = source;
            Events = events;
        }

        public string Id { get; private set; }
        public DataSource.SourceType Source { get; private set; }
        public IList<Event> Events { get; private set; }

        public IEnumerable<IFeature> Features
        {
            get { return features; }
        }

        public IEnumerable<IMarker> Markers
        {
            get
            {
                return Features.SelectMany<IFeature, IMarker>( f => f.Markers );
            }
        }

        public void AddFeature( IFeature feature )
        {
            features.Add( feature );
        }
    }
}
