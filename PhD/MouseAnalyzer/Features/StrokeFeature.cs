using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer
{
    class StrokeFeatureItem : IFeatureItem
    {
        private int count;
        private List<KinematicsFeatureItem> items;
    }

    class StrokeFeature : Feature, IFeature<StrokeFeatureItem>
    {
        #region IFeature Members

        public void ComputeMarkers( string computeId, bool cleanupProcessData = true )
        {
            if( cleanupProcessData )
            {
                _Items.Clear();
            }
        }

        #endregion

        #region IFeature<StrokeFeatureItem> Members

        public IList<StrokeFeatureItem> Items { get { return _Items; } }

        public bool AddItems( IEnumerable<StrokeFeatureItem> items )
        {
            if( items == null || items.Count() == 0 )
            {
                return false;
            }
            _Items.AddRange( items );
            return true;
        }

        #endregion

        public StrokeFeature( Entity entity ) :
            base( NAME, entity )
        {
            _Items = new List<StrokeFeatureItem>();
        }

        private static string NAME = "StrokeFeature";
        private List<StrokeFeatureItem> _Items { get; set; }
    }

    class StrokeFeatureExtractor : IFeatureExtractor<StrokeFeatureItem>
    {
        #region IFeatureExtractor<StrokeFeatureItem> Members

        public IEnumerable<StrokeFeatureItem> AddEvent( Event input, IList<StrokeFeatureItem> previousItems )
        {
            throw new NotImplementedException();
        }

        #endregion
    }
}
