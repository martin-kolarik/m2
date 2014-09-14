using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer
{
    class Kinematics2FeatureItem : IFeatureItem
    {
        private double t = 0.0;
        private double s = 0.0;
        private double st = 0.0;
        private double sn = 0.0;
        private double sfixy = double.NaN;
        private double sfitn = double.NaN;
        private double sfitnd1 = double.NaN;
        private double sfitnd2 = double.NaN;
        private double sfitnd3 = double.NaN;
        private double sfitnd4 = double.NaN;
        private double v = 0.0;
        private double vt = 0.0;
        private double vn = 0.0;
        private double vfi = double.NaN;
        private double vfid1 = double.NaN;
        private double vfid2 = double.NaN;
        private double vfid3 = double.NaN;
        private double a = 0.0;
        private double at = 0.0;
        private double an = 0.0;
        private double afi = double.NaN;
        private double afid1 = double.NaN;
        private double afid2 = double.NaN;
        private double j = 0.0;
        private double jt = 0.0;
        private double jn = 0.0;
        private double jfi = double.NaN;
        private double jfid1 = double.NaN;

        private static Kinematics2FeatureItem tiNull = new Kinematics2FeatureItem();

        public static Kinematics2FeatureItem Null()
        {
            return tiNull;
        }

        public Kinematics2FeatureItem( Event input, Kinematics2FeatureItem previous )
        {
            var dt = input.dT;
            if( dt == 0.0 ) // the same time, the same position, presumably, shall be filtered by caller
            {
                throw new ArgumentOutOfRangeException( "currentEvent.dT" );
            }
            t = dt;

            // length of this piece
            s = Math.Sqrt( input.dX * input.dX + input.dY * input.dY );

            // count s descriptors
            sfixy = Math.Atan2( input.dX, input.dY );
            sfitn = Event.fitn( previous.sfixy, sfixy );
            sfitnd1 = ( sfitn - previous.sfitn ) / dt;
            sfitnd2 = ( sfitnd1 - previous.sfitnd1 ) / dt;
            sfitnd3 = ( sfitnd2 - previous.sfitnd2 ) / dt;
            sfitnd4 = ( sfitnd3 - previous.sfitnd3 ) / dt;

            // count tangents and normals
            st = s * Math.Cos( sfitn );
            vt = ( st - previous.st ) / dt;
            at = ( vt - previous.vt ) / dt;
            jt = ( at - previous.at ) / dt;

            sn = s * Math.Sin( sfitn );
            vn = ( sn - previous.sn ) / dt;
            an = ( vn - previous.vn ) / dt;
            jn = ( an - previous.an ) / dt;

            // counts total values
            v = Math.Sqrt( vt * vt + vn * vn );
            a = Math.Sqrt( at * at + an * an );
            j = Math.Sqrt( jt * jt + jn * jn );

            // count angles
            vfi = Math.Atan2( vn, vt );
            vfid1 = ( vfi - previous.vfi ) / dt;
            vfid2 = ( vfid1 - previous.vfid1 ) / dt;
            vfid3 = ( vfid2 - previous.vfid2 ) / dt;

            afi = Math.Atan2( an, at );
            afid1 = ( afi - previous.afi ) / dt;
            afid2 = ( afid1 - previous.afid1 ) / dt;

            jfi = Math.Atan2( jn, jt );
            jfid1 = ( jfi - previous.jfi ) / dt;
        }

        private Kinematics2FeatureItem()
        {
        }

        public double T { get { return t; } }
        public double S { get { return s; } }
        public double Sfi { get { return sfitn; } }
        public double Sfid1 { get { return sfitnd1; } }
        public double Sfid2 { get { return sfitnd2; } }
        public double Sfid3 { get { return sfitnd3; } }
        public double Sfid4 { get { return sfitnd4; } }
        public double ST { get { return st; } }
        public double SN { get { return sn; } }

        public double V { get { return v; } }
        public double Vfi { get { return vfi; } }
        public double Vfid1 { get { return vfid1; } }
        public double Vfid2 { get { return vfid2; } }
        public double Vfid3 { get { return vfid3; } }
        public double VT { get { return vt; } }
        public double VN { get { return vn; } }

        public double A { get { return a; } }
        public double Afi { get { return afi; } }
        public double Afid1 { get { return afid1; } }
        public double Afid2 { get { return afid2; } }
        public double AT { get { return at; } }
        public double AN { get { return an; } }

        public double J { get { return j; } }
        public double Jfi { get { return jfi; } }
        public double Jfid1 { get { return jfid1; } }
        public double JT { get { return jt; } }
        public double JN { get { return jn; } }
    }

    class Kinematics2FeatureExtractor : IFeatureExtractor<Kinematics2FeatureItem>
    {
        #region IFeatureExtractor Members

        public IEnumerable<Kinematics2FeatureItem> AddEvent( Event input, IList<Kinematics2FeatureItem> previousItems )
        {
            if( previousItems == null )
            {
                return new List<Kinematics2FeatureItem>{ Kinematics2FeatureItem.Null() };
            }
            var previous = previousItems.LastOrDefault<Kinematics2FeatureItem>();
            if( previous == null )
            {
                return new List<Kinematics2FeatureItem> { Kinematics2FeatureItem.Null() };
            }
            else
            {
                return new List<Kinematics2FeatureItem> { new Kinematics2FeatureItem( input, previous ) };
            }
        }

        #endregion

        public Kinematics2FeatureExtractor()
        {
        }

    }

    class Kinematics2Feature : Feature, IFeature<Kinematics2FeatureItem>
    {
        #region IFeature Members

        public bool AddItems( IEnumerable<Kinematics2FeatureItem> items )
        {
            if( items == null || items.Count() == 0 )
            {
                return false;
            }
            _Items.AddRange( items );
            return true;
        }

        public IList<Kinematics2FeatureItem> Items { get { return _Items; } }

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
                    "sTl", f => ( (Kinematics2FeatureItem)f ).S, sHistogramDefinition ) );
                _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this,
                    Items.Where( i => i.T > 31 ),
                    "sTh", f => ( (Kinematics2FeatureItem)f ).S, sHistogramDefinition ) );

                _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this, Items, "sfi", f => ( (Kinematics2FeatureItem)f ).Sfi,
                    new HistogramMarker.HistogramDefinition( 1000 ) ) );
                _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this, Items, "sfid1", f => ( (Kinematics2FeatureItem)f ).Sfid1,
                    new HistogramMarker.HistogramDefinition( -0.5, 1.0/100, 1.0/200, +0.5 ) ) );
                _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this, Items, "sfid2", f => ( (Kinematics2FeatureItem)f ).Sfid2,
                    new HistogramMarker.HistogramDefinition( -0.2, 0.4/100, 0.4/200, +0.2 ) ) );
                _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this, Items, "sfid3", f => ( (Kinematics2FeatureItem)f ).Sfid3,
                    new HistogramMarker.HistogramDefinition( -0.05, 0.1/100, 0.1/200, +0.05 ) ) );
                _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this, Items, "sfid4", f => ( (Kinematics2FeatureItem)f ).Sfid4,
                    new HistogramMarker.HistogramDefinition( -0.01, 0.02/100, 0.02/200, +0.01 ) ) );
                _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this, Items, "sT", f => ( (Kinematics2FeatureItem)f ).ST, new HistogramMarker.HistogramDefinition( 1000 ) ) );
                _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this, Items, "sN", f => ( (Kinematics2FeatureItem)f ).SN, new HistogramMarker.HistogramDefinition( 1000 ) ) );

                // sHistogramDefinition = new HistogramMarker.HistogramDefinition( -0.5, 1.0/100, 1.0/200, +0.5 );
                _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this, Items, "v", f => ( (Kinematics2FeatureItem)f ).V, new HistogramMarker.HistogramDefinition( 1000 ) ) );
                _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this, Items, "vfi", f => ( (Kinematics2FeatureItem)f ).Vfi, new HistogramMarker.HistogramDefinition( 1000 ) ) );
                _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this, Items, "vfid1", f => ( (Kinematics2FeatureItem)f ).Vfid1,
                    new HistogramMarker.HistogramDefinition( -1.5, 3.0/100, 3.0/200, +1.5 ) ) );
                _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this, Items, "vfid2", f => ( (Kinematics2FeatureItem)f ).Vfid2,
                    new HistogramMarker.HistogramDefinition( -0.5, 1.0/100, 1.0/200, +0.5 ) ) );
                _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this, Items, "vfid3", f => ( (Kinematics2FeatureItem)f ).Vfid3,
                    new HistogramMarker.HistogramDefinition( -0.1, 0.2/100, 0.2/200, +0.1 ) ) );
                _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this, Items, "vT", f => ( (Kinematics2FeatureItem)f ).VT, new HistogramMarker.HistogramDefinition( 1000 ) ) );
                _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this, Items, "vN", f => ( (Kinematics2FeatureItem)f ).VN, new HistogramMarker.HistogramDefinition( 1000 ) ) );

                // sHistogramDefinition = new HistogramMarker.HistogramDefinition( -0.2, 0.4/100, 0.4/200, +0.2 );
                _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this, Items, "a", f => ( (Kinematics2FeatureItem)f ).A, new HistogramMarker.HistogramDefinition( 1000 ) ) );
                _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this, Items, "afi", f => ( (Kinematics2FeatureItem)f ).Afi, new HistogramMarker.HistogramDefinition( 1000 ) ) );
                _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this, Items, "afid1", f => ( (Kinematics2FeatureItem)f ).Afid1,
                    new HistogramMarker.HistogramDefinition( -1.5, 3.0/100, 3.0/200, +1.5 ) ) );
                _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this, Items, "afid2", f => ( (Kinematics2FeatureItem)f ).Afid2,
                    new HistogramMarker.HistogramDefinition( -0.3, 0.6/100, 0.6/200, +0.3 ) ) );
                _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this, Items, "aT", f => ( (Kinematics2FeatureItem)f ).AT, new HistogramMarker.HistogramDefinition( 1000 ) ) );
                _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this, Items, "aN", f => ( (Kinematics2FeatureItem)f ).AN, new HistogramMarker.HistogramDefinition( 1000 ) ) );

                // sHistogramDefinition = new HistogramMarker.HistogramDefinition( -0.05, 0.1/100, 0.1/200, +0.05 );
                _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this, Items, "j", f => ( (Kinematics2FeatureItem)f ).J, new HistogramMarker.HistogramDefinition( 1000 ) ) );
                _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this, Items, "jfi", f => ( (Kinematics2FeatureItem)f ).Jfi, new HistogramMarker.HistogramDefinition( 1000 ) ) );
                _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this, Items, "jfid1", f => ( (Kinematics2FeatureItem)f ).Jfid1,
                    new HistogramMarker.HistogramDefinition( -2.0, 4.0/100, 4.0/200, +2.0 ) ) );
                _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this, Items, "jT", f => ( (Kinematics2FeatureItem)f ).JT, new HistogramMarker.HistogramDefinition( 1000 ) ) );
                _Markers.AddRange( new GaussianMarkerExtractor().Extract( computeId, this, Items, "jN", f => ( (Kinematics2FeatureItem)f ).JN, new HistogramMarker.HistogramDefinition( 1000 ) ) );
            }

            if( cleanupProcessData )
            {
                _Items.Clear();
            }
        }

        #endregion

        public Kinematics2Feature( Entity entity ) :
            base( NAME, entity )
        {
            _Items = new List<Kinematics2FeatureItem>();
        }

        private static string NAME = "Kinematics2Feature";
        private List<Kinematics2FeatureItem> _Items { get; set; }
    }
}
