using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer
{
    class KinematicsItem : IFeatureItem
    {
        private double t = 0.0;
        private double s = 0.0;
        private double st = 0.0;
        private double sn = 0.0;
        private double sfixy = double.NaN;
        private double sfitn = double.NaN;
        private double c = double.NaN;
        private double v = 0.0;
        private double vx = 0.0;
        private double vy = 0.0;
        private double vt = 0.0;
        private double vn = 0.0;
        private double vfixy = double.NaN;
        private double vfitn = double.NaN;
        private double a = 0.0;
        private double ax = 0.0;
        private double ay = 0.0;
        private double at = 0.0;
        private double an = 0.0;
        private double afixy = double.NaN;
        private double afitn = double.NaN;
        private double j = 0.0;
        private double jx = 0.0;
        private double jy = 0.0;
        private double jt = 0.0;
        private double jn = 0.0;
        private double jfixy = double.NaN;
        private double jfitn = double.NaN;

        private static KinematicsItem tiNull = new KinematicsItem();

        public static KinematicsItem Null()
        {
            return tiNull;
        }

        public KinematicsItem( Event input, KinematicsItem previous )
        {
            var dt = input.dT;
            if( dt == 0.0 ) // the same time, the same position, presumably, shall be filtered by caller
            {
                throw new ArgumentOutOfRangeException( "currentEvent.dT" );
            }
            t = dt;

            // count world-coordinated derivations
            vx = input.dX / t;
            vy = input.dY / t;
            ax = ( vx - previous.vx ) / t;
            ay = ( vy - previous.vy ) / t;
            jx = ( ax - previous.ax ) / t;
            jy = ( ay - previous.ay ) / t;

            s = Math.Sqrt( input.dX * input.dX + input.dY * input.dY );
            v = Math.Sqrt( vx * vx + vy * vy );
            a = Math.Sqrt( ax * ax + ay * ay );
            j = Math.Sqrt( jx * jx + jy * jy );

            // count angles
            if( s != 0.0 )
            {
                sfixy = Math.Atan2( input.dX, input.dY );
                sfitn = fitn( sfixy, previous.sfixy );
            }
            if( v != 0.0 )
            {
                vfixy = Math.Atan2( vy, vx );
                vfitn = fitn( vfixy, previous.vfixy );
            }
            if( a != 0.0 )
            {
                afixy = Math.Atan2( ay, ax );
                afitn = fitn( afixy, previous.afixy );
            }
            if( j != 0.0 )
            {
                jfixy = Math.Atan2( ay, ax );
                jfitn = fitn( jfixy, previous.jfixy );
            }

            // count along-path derivations
            if( s != 0.0 )
            {
                st = s * Math.Cos( sfitn );
                sn = s * Math.Sin( sfitn );
            }
            if( v != 0.0 )
            {
                vt = v * Math.Cos( vfitn );
                vn = v * Math.Sin( vfitn );
            }
            if( a != 0.0 )
            {
                at = a * Math.Cos( afitn );
                an = a * Math.Sin( afitn );
            }
            if( j != 0.0 )
            {
                jt = j * Math.Cos( jfitn );
                jn = j * Math.Sin( jfitn );
            }

            // curvature
            // c = v == 0.0 ? double.PositiveInfinity : an / v / v;
            c = sfitn / s; // gamboa
        }

        private KinematicsItem()
        {
        }

        public double T { get { return t; } }
        public double S { get { return s; } }
        public double Sfixy { get { return sfixy; } }
        public double Sfitn { get { return sfitn; } }
        public double ST { get { return st; } }
        public double SN { get { return sn; } }
        public double C { get { return c; } }

        public double V { get { return v; } }
        public double Vfixy { get { return vfixy; } }
        public double Vfitn { get { return vfitn; } }
        public double VX { get { return vx; } }
        public double VY { get { return vy; } }
        public double VT { get { return vt; } }
        public double VN { get { return vn; } }

        public double A { get { return a; } }
        public double Afixy { get { return afixy; } }
        public double Afitn { get { return afitn; } }
        public double AX { get { return ax; } }
        public double AY { get { return ay; } }
        public double AT { get { return at; } }
        public double AN { get { return an; } }

        public double J { get { return j; } }
        public double Jfixy { get { return jfixy; } }
        public double Jfitn { get { return jfitn; } }
        public double JX { get { return jx; } }
        public double JY { get { return jy; } }
        public double JT { get { return jt; } }
        public double JN { get { return jn; } }

        private double fitn( double fixy, double previousfixy )
        {
            double fitn = double.NaN;
            if( !double.IsNaN( previousfixy ) )
            {
                fitn = fixy - previousfixy;
            }
            if( double.IsNaN( fitn ) )
            {
                return double.NaN;
            }
            while( fitn < 0.0 )
            {
                fitn = fitn + 2.0 * Math.PI;
            }
            while( fitn > 2 * Math.PI )
            {
                fitn = fitn - 2 * Math.PI;
            }
            if( fitn > Math.PI )
            {
                fitn = fitn - 2 * Math.PI;
            }
            return fitn;
        }
    }

    class KinematicsExtractor : IFeatureExtractor<KinematicsItem>
    {
        #region IFeatureExtractor Members

        public IEnumerable<KinematicsItem> AddEvent( Event input, IList<KinematicsItem> previousItems )
        {
            if( previousItems == null )
            {
                return new List<KinematicsItem>{ KinematicsItem.Null() };
            }
            var previous = previousItems.LastOrDefault<KinematicsItem>();
            if( previous == null )
            {
                return new List<KinematicsItem> { KinematicsItem.Null() };
            }
            else
            {
                return new List<KinematicsItem> { new KinematicsItem( input, previous ) };
            }
        }

        #endregion

        public KinematicsExtractor()
        {
        }

    }

    class Kinematics : IFeature<KinematicsItem>
    {
        #region IFeature Members

        public string Name
        {
            get { return "Kinematics"; }
        }

        public void AddItems( IEnumerable<KinematicsItem> items )
        {
            if( items == null )
            {
                return;
            }
            this.items.AddRange( items );
        }

        public IList<KinematicsItem> Items
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
                markers.AddRange( new GaussianMarkerExtractor().Extract( this, items, "t", f => ( (KinematicsItem)f ).T, new HistogramMarker.HistogramDefinition( 8, 8, 2, 1500 ) ) );

                markers.AddRange( new GaussianMarkerExtractor().Extract( this, items, "s", f => ( (KinematicsItem)f ).S, new HistogramMarker.HistogramDefinition( new double[] {
                    Math.Sqrt(01), Math.Sqrt(02), Math.Sqrt(04), Math.Sqrt(05), Math.Sqrt(08), Math.Sqrt(09),
                    Math.Sqrt(10), Math.Sqrt(13), Math.Sqrt(17), Math.Sqrt(18), Math.Sqrt(20), Math.Sqrt(25),
                    Math.Sqrt(26), Math.Sqrt(29), Math.Sqrt(32), Math.Sqrt(34), Math.Sqrt(37) 
                }, 0.05 ) ) );
                // markers.AddRange( new StatisticsMarkerExtractor().Extract( this, items, "sfitn", f => ( (KinematicsItem)f ).Sfitn, null ) );
                // markers.AddRange( new StatisticsMarkerExtractor().Extract( this, items, "sT", f => ( (KinematicsItem)f ).ST, null ) );
                // markers.AddRange( new StatisticsMarkerExtractor().Extract( this, items, "sN", f => ( (KinematicsItem)f ).SN, null ) );
                // markers.AddRange( new StatisticsMarkerExtractor().Extract( this, items, "c", f => ( (KinematicsItem)f ).C, null ) );

                markers.AddRange( new GaussianMarkerExtractor().Extract( this, items, "v", f => ( (KinematicsItem)f ).V, null ) );
                // markers.AddRange( new StatisticsMarkerExtractor().Extract( this, items, "vfitn", f => ( (KinematicsItem)f ).Vfitn, null ) );
                // markers.AddRange( new StatisticsMarkerExtractor().Extract( this, items, "vT", f => ( (KinematicsItem)f ).VT, null ) );
                // markers.AddRange( new StatisticsMarkerExtractor().Extract( this, items, "vN", f => ( (KinematicsItem)f ).VN, null ) );

                markers.AddRange( new GaussianMarkerExtractor().Extract( this, items, "a", f => ( (KinematicsItem)f ).A, null ) );
                // markers.AddRange( new StatisticsMarkerExtractor().Extract( this, items, "afitn", f => ( (KinematicsItem)f ).Afitn, null ) );
                // markers.AddRange( new StatisticsMarkerExtractor().Extract( this, items, "aT", f => ( (KinematicsItem)f ).AT, null ) );
                // markers.AddRange( new StatisticsMarkerExtractor().Extract( this, items, "aN", f => ( (KinematicsItem)f ).AN, null ) );

                markers.AddRange( new GaussianMarkerExtractor().Extract( this, items, "j", f => ( (KinematicsItem)f ).J, null ) );
                // markers.AddRange( new StatisticsMarkerExtractor().Extract( this, items, "jfitn", f => ( (KinematicsItem)f ).Jfitn, null ) );
                // markers.AddRange( new StatisticsMarkerExtractor().Extract( this, items, "jT", f => ( (KinematicsItem)f ).JT, null ) );
                // markers.AddRange( new StatisticsMarkerExtractor().Extract( this, items, "jN", f => ( (KinematicsItem)f ).JN, null ) );
            }
        }

        #endregion

        private List<KinematicsItem> items = new List<KinematicsItem>();
        private List<IMarker> markers = new List<IMarker>();

    }
}
