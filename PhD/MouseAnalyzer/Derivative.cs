using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer
{
    class DerivativeItem : IFeatureItem
    {
        public enum CoordinateSystem
        {
            World,
            AlongPath
        };

        private CoordinateSystem cs = CoordinateSystem.World;
        private double v;
        private double v1;
        private double v2;
        private double a;
        private double a1;
        private double a2;
        private double j;
        private double j1;
        private double j2;

        public static DerivativeItem Null( CoordinateSystem coordinateSystem )
        {
            return new DerivativeItem( coordinateSystem );
        }

        public DerivativeItem( Event input, DerivativeItem previous )
        {
            var dt = input.dT;
            if( dt == 0.0 ) // the same time, the same position, presumably, shall be filtered by caller
            {
                throw new ArgumentOutOfRangeException( "currentEvent.dT" );
            }

            if( previous.cs == CoordinateSystem.World )
            {
                v1 = input.dX  / dt;
                v2 = input.dY  / dt;
                a1 = ( v1 - previous.v1 ) / dt;
                a2 = ( v2 - previous.v2 ) / dt;
                j1 = ( a1 - previous.a1 ) / dt;
                j2 = ( a2 - previous.a2 ) / dt;
            }
            else
            {
                throw new NotImplementedException();
            }

            v = Math.Sqrt( v1 * v1 + v2 * v2 );
            a = Math.Sqrt( a1 * a1 + a2 * a2 );
            j = Math.Sqrt( j1 * j1 + j2 * j2 );
        }

        private DerivativeItem( CoordinateSystem coordinateSystem )
        {
            cs = coordinateSystem;
        }

        public double V { get { return v; } }
        public double A { get { return a; } }
        public double J { get { return j; } }

        public double VX { get { return v1; } }
        public double AX { get { return a1; } }
        public double JX { get { return j1; } }

        public double VY { get { return v2; } }
        public double AY { get { return a2; } }
        public double JY { get { return j2; } }

        public double VR { get { return v1; } }
        public double AR { get { return a1; } }
        public double JR { get { return j1; } }

        public double VT { get { return v2; } }
        public double AT { get { return a2; } }
        public double JT { get { return j2; } }
    }

    class DerivativeExtractor : IFeatureExtractor<DerivativeItem>
    {
        #region IFeatureExtractor Members

        public DerivativeItem AddEvent( Event input, IEnumerable<DerivativeItem> previousItems )
        {
            if( previousItems == null )
            {
                return DerivativeItem.Null( coordinateSystem );
            }
            var previous = previousItems.LastOrDefault<DerivativeItem>();
            if( previous == null )
            {
                return DerivativeItem.Null( coordinateSystem );
            }
            else
            {
                return new DerivativeItem( input, previous );
            }
        }

        #endregion

        private DerivativeItem.CoordinateSystem coordinateSystem;

        public DerivativeExtractor( DerivativeItem.CoordinateSystem coordinateSystem )
        {
            this.coordinateSystem = coordinateSystem;
        }

    }

    class Derivative : IFeature<DerivativeItem>
    {
        #region IFeature Members

        public string Name
        {
            get { return "Derivative"; }
        }

        public void AddItem( DerivativeItem item )
        {
            if( item == null )
            {
                return;
            }
            items.Add( item );
        }

        public IEnumerable<DerivativeItem> Items
        {
            get { return items; }
        }

        public IEnumerable<IMarker> Markers
        {
            get { return markers; }
        }

        public void ComputeMarkers()
        {
            if( markers.Count == 0 )
            {
                markers.AddRange( new StatisticsMarkerExtractor().Extract( this, items, f => ( (DerivativeItem)f ).V ) );
            }
        }

        #endregion

        private List<DerivativeItem> items = new List<DerivativeItem>();
        private List<IMarker> markers = new List<IMarker>();

    }
}
