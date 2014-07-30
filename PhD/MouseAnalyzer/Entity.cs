using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer
{
    class Entity
    {
        private string source;
        private List<IFeature> features = new List<IFeature>();

        public Entity( string source )
        {
            this.source = source;
        }

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
