using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer
{
    class TimingItem : IFeatureItem
    {
        public enum TimingType
        {
            BeforeClick,
            InClick,
            DoubleClick
        }

        private TimingType type = TimingType.BeforeClick;
        private double value = 0.0;

        private static TimingItem tiNull = new TimingItem();

        public static TimingItem Null()
        {
            return tiNull;
        }

        public TimingItem( TimingType type, double value )
        {
            this.type = type;
            this.value = value;
        }

        private TimingItem()
        {
        }

        public TimingType Type { get { return type; } }
        public double Value { get { return value; } }
    }

    class TimingExtractor : IFeatureExtractor<TimingItem>
    {
        #region IFeatureExtractor Members

        public IEnumerable<TimingItem> AddEvent( Event input, IList<TimingItem> previousItems )
        {
            var list = new List<TimingItem>();

            if( previousItems == null || previousItems.Count == 0 )
            {
                list.Add( TimingItem.Null() );
            }
            else
            {
                HandleButton( ref list, Event.Button.Left, input );
                HandleButton( ref list, Event.Button.Middle, input );
                HandleButton( ref list, Event.Button.Right, input );
                HandleButton( ref list, Event.Button.B4, input );
                HandleButton( ref list, Event.Button.B5, input );
            }

            return list;
        }

        #endregion

        public TimingExtractor()
        {
            clickedOn[Event.Button.Left] = NO_TIME;
            clickedOn[Event.Button.Middle] = NO_TIME;
            clickedOn[Event.Button.Right] = NO_TIME;
            clickedOn[Event.Button.B4] = NO_TIME;
            clickedOn[Event.Button.B5] = NO_TIME;
        }

        private void HandleButton( ref List<TimingItem> list, Event.Button button, Event input )
        {
            if( input[button] == Event.ButtonState.Press )
            {
                clickedOn[button] = input.Time;
                list.Add( new TimingItem( TimingItem.TimingType.BeforeClick, input.dT ) );
            }
            else if( input[button] == Event.ButtonState.DoublePress )
            {
                if( clickedOn[button] != NO_TIME )
                {
                    list.Add( new TimingItem( TimingItem.TimingType.DoubleClick, input.Time - clickedOn[button] ) );
                }
                clickedOn[button] = input.Time;
            }
            else if( input[button] == Event.ButtonState.Release )
            {
                if( clickedOn[button] != NO_TIME )
                {
                    list.Add( new TimingItem( TimingItem.TimingType.InClick, input.Time - clickedOn[button] ) );
                    clickedOn[button] = NO_TIME;
                }
            }
        }

        private const double NO_TIME = -1.0;
        private Dictionary<Event.Button, double> clickedOn = new Dictionary<Event.Button, double>();
    }

    class Timing : Feature, IFeature<TimingItem>
    {
        #region IFeature Members

        public bool AddItems( IEnumerable<TimingItem> items )
        {
            if( items == null || items.Count() == 0 )
            {
                return false;
            }
            _Items.AddRange( items );
            return true;
        }

        public IList<TimingItem> Items { get { return _Items; }
        }

        public void ComputeMarkers( string computeId )
        {
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, Items.Where( i => i.Type == TimingItem.TimingType.BeforeClick ), "Before", f => ( (TimingItem)f ).Value, new HistogramMarker.HistogramDefinition( 8, 8, 2, 1500 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, Items.Where( i => i.Type == TimingItem.TimingType.InClick ), "In", f => ( (TimingItem)f ).Value, new HistogramMarker.HistogramDefinition( 8, 8, 2, 1500 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, Items.Where( i => i.Type == TimingItem.TimingType.DoubleClick ), "Double", f => ( (TimingItem)f ).Value, new HistogramMarker.HistogramDefinition( 8, 8, 2, 200 ) ) );

            _Markers.AddRange( new LognormalMarkerExtractor().Extract( computeId, this, Items.Where( i => i.Type == TimingItem.TimingType.BeforeClick ), "Before", f => ( (TimingItem)f ).Value, new HistogramMarker.HistogramDefinition( 8, 8, 2, 1500 ) ) );
            _Markers.AddRange( new LognormalMarkerExtractor().Extract( computeId, this, Items.Where( i => i.Type == TimingItem.TimingType.InClick ), "In", f => ( (TimingItem)f ).Value, new HistogramMarker.HistogramDefinition( 8, 8, 2, 1500 ) ) );
            _Markers.AddRange( new LognormalMarkerExtractor().Extract( computeId, this, Items.Where( i => i.Type == TimingItem.TimingType.DoubleClick ), "Double", f => ( (TimingItem)f ).Value, new HistogramMarker.HistogramDefinition( 8, 8, 2, 200 ) ) );
        }

        #endregion

        public Timing( Entity entity ) :
            base( NAME, entity )
        {
            _Items = new List<TimingItem>();
        }

        private static string NAME = "Timing";
        private List<TimingItem> _Items { get; set; }
    }
}
