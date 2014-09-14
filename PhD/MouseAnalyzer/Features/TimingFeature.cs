using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer
{
    class TimingFeatureItem : IFeatureItem
    {
        public enum TimingType
        {
            BeforeClick,
            InClick,
            DoubleClick
        }

        private TimingType type = TimingType.BeforeClick;
        private double value = 0.0;

        private static TimingFeatureItem tiNull = new TimingFeatureItem();

        public static TimingFeatureItem Null()
        {
            return tiNull;
        }

        public TimingFeatureItem( TimingType type, double value )
        {
            this.type = type;
            this.value = value;
        }

        private TimingFeatureItem()
        {
        }

        public TimingType Type { get { return type; } }
        public double Value { get { return value; } }
    }

    class TimingFeatureExtractor : IFeatureExtractor<TimingFeatureItem>
    {
        #region IFeatureExtractor Members

        public IEnumerable<TimingFeatureItem> AddEvent( Event input, IList<TimingFeatureItem> previousItems )
        {
            var list = new List<TimingFeatureItem>();

            if( previousItems == null || previousItems.Count == 0 )
            {
                list.Add( TimingFeatureItem.Null() );
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

        private void HandleButton( ref List<TimingFeatureItem> list, Event.Button button, Event input )
        {
            if( input[button] == Event.ButtonState.Press )
            {
                clickedInput[button] = input;
                list.Add( new TimingFeatureItem( TimingFeatureItem.TimingType.BeforeClick, input.dT ) );
            }
            else if( input[button] == Event.ButtonState.DoublePress )
            {
                if( clickedInput[button] != null )
                {
                    list.Add( new TimingFeatureItem( TimingFeatureItem.TimingType.DoubleClick, input.Time - clickedInput[button].Time ) );
                }
                clickedInput[button] = input;
            }
            else if( input[button] == Event.ButtonState.Release )
            {
                if( clickedInput.ContainsKey( button ) && clickedInput[button] != null )
                {
                    var dX = input.X - clickedInput[button].X;
                    var dY = input.Y - clickedInput[button].Y;
                    var distance = Math.Sqrt( dX * dX + dY * dY );
                    if( distance < DRAG_MOVEMENT_THRESHOLD )
                    {
                        list.Add( new TimingFeatureItem( TimingFeatureItem.TimingType.InClick, input.Time - clickedInput[button].Time ) );
                    }
                    clickedInput[button] = null;
                }
            }
        }

        private static double DRAG_MOVEMENT_THRESHOLD = 3;
        private Dictionary<Event.Button, Event> clickedInput = new Dictionary<Event.Button, Event>();
    }

    class TimingFeature : Feature, IFeature<TimingFeatureItem>
    {
        #region IFeature Members

        public bool AddItems( IEnumerable<TimingFeatureItem> items )
        {
            if( items == null || items.Count() == 0 )
            {
                return false;
            }
            _Items.AddRange( items );
            return true;
        }

        public IList<TimingFeatureItem> Items { get { return _Items; }
        }

        public void ComputeMarkers( string computeId, bool cleanupProcessData = true )
        {
            var BeforeClickLimit = 5000.0;
            var InClickLimit = 1500.0;
            var DoubleClickLimit = 300.0;
            var InvGaussHistograms = false; // no need for using histograms now, they have Lognormal or InvGaussian or some other exponential distribution, and
                                            // I have already tested that Estimate equals Fit for used distributions.
                                            // Allow histograms to compare another people.
            var LognormalHistograms = false; // Lognormal is more sensitive to values close to zero -- that is values are limited to 7.0, what is the same boundary
                                             // as histogram uses. After such limiting of input set both Fit and Est. give identical values.

            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this,
                Items.Where( i => i.Type == TimingFeatureItem.TimingType.BeforeClick && i.Value <= BeforeClickLimit && i.Value >= 7.0 ),
                "Before", f => ( (TimingFeatureItem)f ).Value,
                InvGaussHistograms ? new HistogramMarker.HistogramDefinition( 8, 8, 2, BeforeClickLimit ) : null ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this,
                Items.Where( i => i.Type == TimingFeatureItem.TimingType.InClick && i.Value <= InClickLimit && i.Value >= 7.0 ),
                "In", f => ( (TimingFeatureItem)f ).Value,
                InvGaussHistograms ? new HistogramMarker.HistogramDefinition( 8, 8, 2, InClickLimit ) : null ) );
            if( useDoubleClick )
            {
                _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this,
                    Items.Where( i => i.Type == TimingFeatureItem.TimingType.DoubleClick && i.Value <= DoubleClickLimit && i.Value >= 7.0 ),
                    "Double", f => ( (TimingFeatureItem)f ).Value,
                    InvGaussHistograms ? new HistogramMarker.HistogramDefinition( 8, 8, 2, DoubleClickLimit ) : null ) );
            }

            _Markers.AddRange( new LognormalMarkerExtractor().Extract( computeId, this,
                Items.Where( i => i.Type == TimingFeatureItem.TimingType.BeforeClick && i.Value <= BeforeClickLimit && i.Value >= 7.0 ),
                "Before", f => ( (TimingFeatureItem)f ).Value,
                LognormalHistograms ? new HistogramMarker.HistogramDefinition( 8, 8, 2, BeforeClickLimit ) : null ) );
            _Markers.AddRange( new LognormalMarkerExtractor().Extract( computeId, this,
                Items.Where( i => i.Type == TimingFeatureItem.TimingType.InClick && i.Value <= InClickLimit && i.Value >= 7.0 ),
                "In", f => ( (TimingFeatureItem)f ).Value,
                LognormalHistograms ? new HistogramMarker.HistogramDefinition( 8, 8, 2, InClickLimit ) : null ) );
            if( useDoubleClick )
            {
                _Markers.AddRange( new LognormalMarkerExtractor().Extract( computeId, this,
                    Items.Where( i => i.Type == TimingFeatureItem.TimingType.DoubleClick && i.Value <= DoubleClickLimit && i.Value >= 7.0 ),
                    "Double", f => ( (TimingFeatureItem)f ).Value,
                    LognormalHistograms ? new HistogramMarker.HistogramDefinition( 8, 8, 2, DoubleClickLimit ) : null ) );
            }

            if( cleanupProcessData )
            {
                _Items.Clear();
            }
        }

        #endregion

        public TimingFeature( Entity entity, bool useDoubleClick ) :
            base( NAME, entity )
        {
            _Items = new List<TimingFeatureItem>();
            this.useDoubleClick = useDoubleClick;
        }

        private static string NAME = "TimingFeature";
        private List<TimingFeatureItem> _Items { get; set; }
        private bool useDoubleClick;
    }
}
