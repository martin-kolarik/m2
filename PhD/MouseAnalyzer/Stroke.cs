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

    class Stroke : IFeature<StrokeItem>
    {
        #region IFeature<StrokeItem> Members

        public void AddItem( StrokeItem item )
        {
            if( item == null )
            {
                return;
            }
            items.Add( item );
        }

        public IEnumerable<StrokeItem> Items
        {
            get { return items; }
        }

        #endregion

        #region IFeature Members

        public string Name
        {
            get { return "Stroke"; }
        }

        public IEnumerable<IMarker> Markers
        {
            get { return markers; }
        }

        public void ComputeMarkers()
        {
        }

        #endregion

        private List<StrokeItem> items = new List<StrokeItem>();
        private List<IMarker> markers = new List<IMarker>();
    }

    class StrokeExtractor : IFeatureExtractor<StrokeItem>
    {
        #region IFeatureExtractor<StrokeItem> Members

        public StrokeItem AddEvent( Event input, IEnumerable<StrokeItem> previousItems )
        {
            throw new NotImplementedException();
        }

        #endregion
    }
}
