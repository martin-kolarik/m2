using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer
{
    class StrokeItem : IFeatureItem
    {
        private int count;
        private List<KinematicsItem> items;
    }

    class Stroke : Feature, IFeature<StrokeItem>
    {
        #region IFeature Members

        public void ComputeMarkers( string computeId )
        {
        }

        #endregion

        #region IFeature<StrokeItem> Members

        public IList<StrokeItem> Items { get { return _Items; } }

        public bool AddItems( IEnumerable<StrokeItem> items )
        {
            if( items == null || items.Count() == 0 )
            {
                return false;
            }
            _Items.AddRange( items );
            return true;
        }

        #endregion

        public Stroke( Entity entity ) :
            base( NAME, entity )
        {
            _Items = new List<StrokeItem>();
        }

        private static string NAME = "Stroke";
        private List<StrokeItem> _Items { get; set; }
    }

    class StrokeExtractor : IFeatureExtractor<StrokeItem>
    {
        #region IFeatureExtractor<StrokeItem> Members

        public IEnumerable<StrokeItem> AddEvent( Event input, IList<StrokeItem> previousItems )
        {
            throw new NotImplementedException();
        }

        #endregion
    }
}
