using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer
{
    class KinematicsFeatureItem : IFeatureItem
    {
        private double t = 0.0;
        private double s = 0.0;
        private double st = 0.0;
        private double sn = 0.0;
        private double sfixy = double.NaN;
        private double sfitn = double.NaN;
        private double sfitnd1 = double.NaN;
        private double sfitnd2 = double.NaN;
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

        private static KinematicsFeatureItem tiNull = new KinematicsFeatureItem();

        public static KinematicsFeatureItem Null()
        {
            return tiNull;
        }

        public KinematicsFeatureItem( Event input, KinematicsFeatureItem previous )
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
                sfitnd1 = ( sfitn - previous.sfitn ) / t;
                sfitnd2 = ( sfitnd1 - previous.sfitnd1 ) / t;
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

        private KinematicsFeatureItem()
        {
        }

        public double T { get { return t; } }
        public double S { get { return s; } }
        public double Sfixy { get { return sfixy; } }
        public double Sfitn { get { return sfitn; } }
        public double Sfitnd1 { get { return sfitnd1; } }
        public double Sfitnd2 { get { return sfitnd2; } }
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

    class KinematicsFeatureExtractor : IFeatureExtractor<KinematicsFeatureItem>
    {
        #region IFeatureExtractor Members

        public IEnumerable<KinematicsFeatureItem> AddEvent( Event input, IList<KinematicsFeatureItem> previousItems )
        {
            if( previousItems == null )
            {
                return new List<KinematicsFeatureItem>{ KinematicsFeatureItem.Null() };
            }
            var previous = previousItems.LastOrDefault<KinematicsFeatureItem>();
            if( previous == null )
            {
                return new List<KinematicsFeatureItem> { KinematicsFeatureItem.Null() };
            }
            else
            {
                return new List<KinematicsFeatureItem> { new KinematicsFeatureItem( input, previous ) };
            }
        }

        #endregion

        public KinematicsFeatureExtractor()
        {
        }

    }

    class KinematicsFeature : Feature, IFeature<KinematicsFeatureItem>
    {
        #region IFeature Members

        public bool AddItems( IEnumerable<KinematicsFeatureItem> items )
        {
            if( items == null || items.Count() == 0 )
            {
                return false;
            }
            _Items.AddRange( items );
            return true;
        }

        public IList<KinematicsFeatureItem> Items { get { return _Items; } }

        public void ComputeMarkers( string computeId, bool cleanupProcessData = true )
        {
            if( _Markers.Count == 0 )
            {
                // _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this,
                //     Items.Where( i => ( (KinematicsFeatureItem)i ).T <= 250 ),
                //     "t", f => ( (KinematicsFeatureItem)f ).T, new HistogramMarker.HistogramDefinition( 8, 8, 2, 250 ) ) );

                // var sHistogramDefinition = new HistogramMarker.HistogramDefinition( new double[] {
                //     Math.Sqrt(01), Math.Sqrt(02), Math.Sqrt(04), Math.Sqrt(05), Math.Sqrt(08), Math.Sqrt(09), Math.Sqrt(10),
                //     Math.Sqrt(13), Math.Sqrt(17), Math.Sqrt(18), Math.Sqrt(20), Math.Sqrt(25), Math.Sqrt(26), Math.Sqrt(29),
                //     Math.Sqrt(32), Math.Sqrt(34), Math.Sqrt(37), Math.Sqrt(40), Math.Sqrt(41), Math.Sqrt(45) 
                // }, 0.05 );
                HistogramMarker.HistogramDefinition sHistogramDefinition = null;

                // _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this,
                //      Items,
                //      "s", f => ( (KinematicsFeatureItem)f ).S, sHistogramDefinition ) );
                _Markers.AddRange( new LognormalMarkerExtractor().Extract( computeId, this,
                    Items.Where( i => i.T <= 31 ),
                    "sTl", f => ( (KinematicsFeatureItem)f ).S, sHistogramDefinition ) );
                _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this,
                    Items.Where( i => i.T > 31 ),
                    "sTh", f => ( (KinematicsFeatureItem)f ).S, sHistogramDefinition ) );

                // sHistogramDefinition = new HistogramMarker.HistogramDefinition( -4.0, 8.0/100, 8.0/200, +4.0 );
                _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this, Items, "sfitn", f => ( (KinematicsFeatureItem)f ).Sfitn, null ) );
                _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this, Items, "sT", f => ( (KinematicsFeatureItem)f ).ST, null ) );
                _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this, Items, "sN", f => ( (KinematicsFeatureItem)f ).SN, null ) );
                _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this, Items, "c", f => ( (KinematicsFeatureItem)f ).C, null ) );
                _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this, Items, "sfitnd1", f => ( (KinematicsFeatureItem)f ).Sfitnd1, null ) );
                _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this, Items, "sfitnd2", f => ( (KinematicsFeatureItem)f ).Sfitnd2, null ) );

                // sHistogramDefinition = new HistogramMarker.HistogramDefinition( -0.5, 1.0/100, 1.0/200, +0.5 );
                _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this, Items, "v", f => ( (KinematicsFeatureItem)f ).V, null ) );
                _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this, Items, "vfitn", f => ( (KinematicsFeatureItem)f ).Vfitn, null ) );
                _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this, Items, "vT", f => ( (KinematicsFeatureItem)f ).VT, null ) );
                _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this, Items, "vN", f => ( (KinematicsFeatureItem)f ).VN, null ) );

                // sHistogramDefinition = new HistogramMarker.HistogramDefinition( -0.2, 0.4/100, 0.4/200, +0.2 );
                _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this, Items, "a", f => ( (KinematicsFeatureItem)f ).A, null ) );
                _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this, Items, "afitn", f => ( (KinematicsFeatureItem)f ).Afitn, null ) );
                _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this, Items, "aT", f => ( (KinematicsFeatureItem)f ).AT, null ) );
                _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this, Items, "aN", f => ( (KinematicsFeatureItem)f ).AN, null ) );

                // sHistogramDefinition = new HistogramMarker.HistogramDefinition( -0.05, 0.1/100, 0.1/200, +0.05 );
                _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this, Items, "j", f => ( (KinematicsFeatureItem)f ).J, null ) );
                _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this, Items, "jfitn", f => ( (KinematicsFeatureItem)f ).Jfitn, null ) );
                _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this, Items, "jT", f => ( (KinematicsFeatureItem)f ).JT, null ) );
                _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this, Items, "jN", f => ( (KinematicsFeatureItem)f ).JN, null ) );
            }

            if( cleanupProcessData )
            {
                _Items.Clear();
            }
        }

        #endregion

        public KinematicsFeature( Entity entity ) :
            base( NAME, entity )
        {
            _Items = new List<KinematicsFeatureItem>();
        }

        private static string NAME = "KinematicsFeature";
        private List<KinematicsFeatureItem> _Items { get; set; }
    }
}
