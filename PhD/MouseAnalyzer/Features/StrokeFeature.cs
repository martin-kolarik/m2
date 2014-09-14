using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using MouseAnalyzer.Statistics;

namespace MouseAnalyzer
{
    class StrokeFeatureItem : IFeatureItem
    {
        public enum ItemType
        {
            ToClick,
            ToDoubleClick,
            Drag,
            MoveEnded
        }

        private static StrokeFeatureItem tiNull = new StrokeFeatureItem();

        public static StrokeFeatureItem Null()
        {
            return tiNull;
        }

        public StrokeFeatureItem( StrokeFeatureItem.ItemType type, Event.Button? button, List<Event> input )
        {
            Type = type;
            Button = button;
            Input = input;

            var f = Input.First();
            var l = Input.Last();

            var vxPrev = double.NaN; // needed for ax
            var vyPrev = double.NaN; // needed for ay
            var vPrev = double.NaN; // needed for dv
            var dvPrev = double.NaN; // needed for d2v
            var afixyPrev = double.NaN; // needed for at, an
            var csPrev = double.NaN; // needed for dc

            var si = 0.0;
            var ti = 0.0;
            var csList = new List<double>();
            var dcsList = new List<double>();
            var vList = new List<double>();
            var vfiList = new List<double>();
            var vtList = new List<double>();
            var vnList = new List<double>();
            var dvList = new List<double>();
            var d2vList = new List<double>();
            var aList = new List<double>();
            var afiList = new List<double>();
            var atList = new List<double>();
            var anList = new List<double>();
            var caList = new List<double>();
            foreach( var i in Input )
            {
                var ds = i == f ? 0.0 : Math.Sqrt( i.dX*i.dX + i.dY*i.dY );
                var dt = i == f ? 0.0 : i.dT;
                si += ds;
                ti += dt;

                if( dt > 1.0 && ds > 0.0 && i != f )
                {
                    // path curvature
                    var cs = i.FiTN / ds;
                    var dcs = double.IsNaN( csPrev ) ? 0.0 : ( cs - csPrev ) / ds;
                    csList.Add( cs ); //****
                    dcsList.Add( dcs ); //****
                    csPrev = cs;

                    // velocity as vector
                    var vx = i.dX / dt;
                    var vy = i.dY / dt;
                    var v = Math.Sqrt( vx*vx + vy*vy );
                    var vn = v * Math.Sin( i.FiTN );
                    var vt = v * Math.Cos( i.FiTN );
                    vList.Add( v ); //****
                    vfiList.Add( i.FiTN ); //****
                    vtList.Add( vt ); //****
                    vnList.Add( vn ); //****

                    // velocity as scalar
                    var dv = double.IsNaN( vPrev ) ? 0.0 : ( v - vPrev ) / dt;
                    var d2v = double.IsNaN( dvPrev ) ? 0.0 : ( dv - dvPrev ) / dt;
                    dvList.Add( dv ); //****
                    d2vList.Add( d2v ); //****
                    vPrev = v;
                    dvPrev = dv;

                    // acceleration as vector
                    var ax = double.IsNaN( vxPrev ) ? 0.0 : ( vx - vxPrev ) / dt;
                    var ay = double.IsNaN( vyPrev ) ? 0.0 : ( vy - vyPrev ) / dt;
                    vxPrev = vx;
                    vyPrev = vy;
                    var afixy = Math.Atan2( ay, ax );
                    var afi = Event.fitn( afixyPrev, afixy );
                    afixyPrev = afixy;
                    var a = Math.Sqrt( ax*ax + ay*ay );
                    var an = a * Math.Sin( afi );
                    var at = a * Math.Cos( afi );
                    aList.Add( a ); //****
                    afiList.Add( afi ); //****
                    atList.Add( at ); //****
                    anList.Add( an ); //****
                    caList.Add( afi / ds ); //****
                }
            }

            if( si == 0.0 ) // data is unusable
            {
                return; 
            }
            var count = input.Count();

            // determine boundaries of acceleration and decceleration
            /*
            var indexEndOfAcc = 1;
            var indexStartOfDecc = dvList.Count-1;
            if( dvList.Count > 1 )
            {
                for( var index = 1; index < dvList.Count; index++ )
                {
                    if( dvList[index] <= 0.0 )
                    {
                        indexEndOfAcc = index-1;
                        break;
                    }
                }
                for( var index = dvList.Count-2; index >= 0; index-- )
                {
                    if( dvList[index] >= 0.0 )
                    {
                        indexStartOfDecc = index+1;
                        break;
                    }
                }
            }
            */
            var indexEndOfAcc = count * 100 / 25;
            var indexStartOfDecc = count * 100 / 75;

            var dx = l.X-f.X;
            var dy = l.Y-f.Y;

            _Si = si;
            _Ti = ti;
            _CSi = csList.Sum();

            _Sd = Math.Sqrt(dx*dx+dy*dy);
            _Vd = Sd / Ti;
            _CSd = ( Si - Sd ) / ( 1.0 + Sd ) / Si;

            _RL = (double)indexEndOfAcc / count;
            _RH = 1.0 - (double)indexStartOfDecc / count;

            AnalyzeList( csList, indexEndOfAcc, indexStartOfDecc,
                         out _CSA0, out _CSA2, out _CSA4, out _CSAV,
                         out _CSL0, out _CSL2, out _CSL4, out _CSLV,
                         out _CSM0, out _CSM2, out _CSM4, out _CSMV,
                         out _CSH0, out _CSH2, out _CSH4, out _CSHV );

            AnalyzeList( caList, indexEndOfAcc, indexStartOfDecc,
                         out _CAA0, out _CAA2, out _CAA4, out _CAAV,
                         out _CAL0, out _CAL2, out _CAL4, out _CALV,
                         out _CAM0, out _CAM2, out _CAM4, out _CAMV,
                         out _CAH0, out _CAH2, out _CAH4, out _CAHV );

            AnalyzeList( vList, indexEndOfAcc, indexStartOfDecc,
                         out _VA0, out _VA2, out _VA4, out _VAV,
                         out _VL0, out _VL2, out _VL4, out _VLV,
                         out _VM0, out _VM2, out _VM4, out _VMV,
                         out _VH0, out _VH2, out _VH4, out _VHV );

            AnalyzeList( aList, indexEndOfAcc, indexStartOfDecc,
                         out _AA0, out _AA2, out _AA4, out _AAV,
                         out _AL0, out _AL2, out _AL4, out _ALV,
                         out _AM0, out _AM2, out _AM4, out _AMV,
                         out _AH0, out _AH2, out _AH4, out _AHV );

            /*
            var dcsList 

            var vfiList = new List<double>();
            var vtList = new List<double>();
            var vnList = new List<double>();
            var dvList = new List<double>();
            var d2vList = new List<double>();

            var afiList = new List<double>(); -- ca
            var atList = new List<double>();
            var anList = new List<double>();
            */
        }

        private StrokeFeatureItem()
        {
        }

        private void AnalyzeList( List<double> list, int endOfL, int startOfH,
                                  out double a0, out double a2, out double a4, out double av,
                                  out double l0, out double l2, out double l4, out double lv,
                                  out double m0, out double m2, out double m4, out double mv,
                                  out double h0, out double h2, out double h4, out double hv )
        {
            var c = list.Count;
            var l = list.Take( endOfL );
            var m = list.Skip( endOfL ).Take( c - endOfL-1 - startOfH );
            var h = list.Skip( startOfH );
            a0 = list.Min(); a2 = list.Average(); a4 = list.Max(); av = list.Variance();
            if( l.Count() == 0 )
            {
                l0 = a0; l2 = l0; l4 = l0; lv = 0.0;
            }
            else
            {
                l0 = l.Min(); l2 = l.Average(); l4 = l.Max(); lv = l.Variance();
            }
            if( h.Count() == 0 )
            {
                h0 = a4; h2 = h0; h4 = h0; hv = 0.0;
            }
            else
            {
                h0 = h.Min(); h2 = h.Average(); h4 = h.Max(); hv = h.Variance();
            }
            if( m.Count() == 0 )
            {
                m0 = 0.5 * ( l4 + h0 ); m2 = m0; m4 = m0; mv = 0.5 * ( lv + hv );
            }
            else
            {
                m0 = m.Min(); m2 = m.Average(); m4 = m.Max(); mv = m.Variance();
            }
        }

        public ItemType Type { get; private set; }
        public Event.Button? Button { get; private set; }
        public List<Event> Input { get; private set; }

        public double Si { get { return _Si; } } // path integrated
        public double Ti { get { return _Ti; } } // time integrated
        public double CSi { get { return _CSi; } } // path excess interated

        public double Sd { get { return _Sd; } } // path direct
        public double Vd { get { return _Vd; } } // velocity direct
        public double CSd { get { return _CSd; } } // path excess direct

        public double RL { get { return _RL; } } // ratio of start acc part
        public double RH { get { return _RH; } } // ratio of start decc part

        public double CSA0 { get { return _CSA0; } } // curvature all minimum
        public double CSA2 { get { return _CSA2; } } // curvature all average
        public double CSA4 { get { return _CSA4; } } // curvature all maximum
        public double CSAV { get { return _CSAV; } } // curvature all variance
        public double CSL0 { get { return _CSL0; } } // curvature low minimum
        public double CSL2 { get { return _CSL2; } } // curvature low average
        public double CSL4 { get { return _CSL4; } } // curvature low maximum
        public double CSLV { get { return _CSLV; } } // curvature low variance
        public double CSM0 { get { return _CSM0; } } // curvature central minimum
        public double CSM2 { get { return _CSM2; } } // curvature central average
        public double CSM4 { get { return _CSM4; } } // curvature central maximum
        public double CSMV { get { return _CSMV; } } // curvature central variance
        public double CSH0 { get { return _CSH0; } } // curvature high minimum
        public double CSH2 { get { return _CSH2; } } // curvature high average
        public double CSH4 { get { return _CSH4; } } // curvature high maximum
        public double CSHV { get { return _CSHV; } } // curvature high variance

        public double CAA0 { get { return _CAA0; } } // curvature acc all minimum
        public double CAA2 { get { return _CAA2; } } // curvature acc all average
        public double CAA4 { get { return _CAA4; } } // curvature acc all maximum
        public double CAAV { get { return _CAAV; } } // curvature acc all variance
        public double CAL0 { get { return _CAL0; } } // curvature acc low minimum
        public double CAL2 { get { return _CAL2; } } // curvature acc low average
        public double CAL4 { get { return _CAL4; } } // curvature acc low maximum
        public double CALV { get { return _CALV; } } // curvature acc low variance
        public double CAM0 { get { return _CAM0; } } // curvature acc central minimum
        public double CAM2 { get { return _CAM2; } } // curvature acc central average
        public double CAM4 { get { return _CAM4; } } // curvature acc central maximum
        public double CAMV { get { return _CAMV; } } // curvature acc central variance
        public double CAH0 { get { return _CAH0; } } // curvature acc high minimum
        public double CAH2 { get { return _CAH2; } } // curvature acc high average
        public double CAH4 { get { return _CAH4; } } // curvature acc high maximum
        public double CAHV { get { return _CAHV; } } // curvature acc high variance

        public double VA0 { get { return _VA0; } } // velocity all minimum
        public double VA2 { get { return _VA2; } } // velocity all average
        public double VA4 { get { return _VA4; } } // velocity all maximum
        public double VAV { get { return _VAV; } } // velocity all variance
        public double VL0 { get { return _VL0; } } // velocity low minimum
        public double VL2 { get { return _VL2; } } // velocity low average
        public double VL4 { get { return _VL4; } } // velocity low maximum
        public double VLV { get { return _VLV; } } // velocity low variance
        public double VM0 { get { return _VM0; } } // velocity central minimum
        public double VM2 { get { return _VM2; } } // velocity central average
        public double VM4 { get { return _VM4; } } // velocity central maximum
        public double VMV { get { return _VMV; } } // velocity central variance
        public double VH0 { get { return _VH0; } } // velocity high minimum
        public double VH2 { get { return _VH2; } } // velocity high average
        public double VH4 { get { return _VH4; } } // velocity high maximum
        public double VHV { get { return _VHV; } } // velocity high variance

        public double AA0 { get { return _AA0; } } // velocity acc all minimum
        public double AA2 { get { return _AA2; } } // velocity acc all average
        public double AA4 { get { return _AA4; } } // velocity acc all maximum
        public double AAV { get { return _AAV; } } // velocity acc all variance
        public double AL0 { get { return _AL0; } } // velocity acc low minimum
        public double AL2 { get { return _AL2; } } // velocity acc low average
        public double AL4 { get { return _AL4; } } // velocity acc low maximum
        public double ALV { get { return _ALV; } } // velocity acc low variance
        public double AM0 { get { return _AM0; } } // velocity acc central minimum
        public double AM2 { get { return _AM2; } } // velocity acc central average
        public double AM4 { get { return _AM4; } } // velocity acc central maximum
        public double AMV { get { return _AMV; } } // velocity acc central variance
        public double AH0 { get { return _AH0; } } // velocity acc high minimum
        public double AH2 { get { return _AH2; } } // velocity acc high average
        public double AH4 { get { return _AH4; } } // velocity acc high maximum
        public double AHV { get { return _AHV; } } // velocity acc high variance

        private double _Si;
        private double _Ti;
        private double _CSi;

        private double _Sd;
        private double _Vd;
        private double _CSd;

        private double _RL;
        private double _RH;

        private double _CSA0;
        private double _CSA2;
        private double _CSA4;
        private double _CSAV;
        private double _CSL0;
        private double _CSL2;
        private double _CSL4;
        private double _CSLV;
        private double _CSM0;
        private double _CSM2;
        private double _CSM4;
        private double _CSMV;
        private double _CSH0;
        private double _CSH2;
        private double _CSH4;
        private double _CSHV;

        private double _CAA0;
        private double _CAA2;
        private double _CAA4;
        private double _CAAV;
        private double _CAL0;
        private double _CAL2;
        private double _CAL4;
        private double _CALV;
        private double _CAM0;
        private double _CAM2;
        private double _CAM4;
        private double _CAMV;
        private double _CAH0;
        private double _CAH2;
        private double _CAH4;
        private double _CAHV;

        private double _VA0;
        private double _VA2;
        private double _VA4;
        private double _VAV;
        private double _VL0;
        private double _VL2;
        private double _VL4;
        private double _VLV;
        private double _VM0;
        private double _VM2;
        private double _VM4;
        private double _VMV;
        private double _VH0;
        private double _VH2;
        private double _VH4;
        private double _VHV;

        private double _AA0;
        private double _AA2;
        private double _AA4;
        private double _AAV;
        private double _AL0;
        private double _AL2;
        private double _AL4;
        private double _ALV;
        private double _AM0;
        private double _AM2;
        private double _AM4;
        private double _AMV;
        private double _AH0;
        private double _AH2;
        private double _AH4;
        private double _AHV;
    }

    class StrokeFeature : Feature, IFeature<StrokeFeatureItem>
    {
        #region IFeature Members

        public void ComputeMarkers( string computeId, bool cleanupProcessData = true )
        {
            if( _Markers.Count == 0 )
            {
                // ComputeMarkersForItems( computeId, Items.Where( i => i.Si > 0.0 && i.Type == StrokeFeatureItem.ItemType.Drag ), "d" );
                ComputeMarkersForItems( computeId, Items.Where( i => i.Si > 0.0 && i.Type == StrokeFeatureItem.ItemType.MoveEnded ), "m" );
                // ComputeMarkersForItems( computeId, Items.Where( i => i.Si > 0.0 && i.Type == StrokeFeatureItem.ItemType.ToClick ), "c" );
            }

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

        private void ComputeMarkersForItems( string computeId, IEnumerable<StrokeFeatureItem> items, string namePrefix )
        {
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "Si", f => ( (StrokeFeatureItem)f ).Si, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "Ti", f => ( (StrokeFeatureItem)f ).Ti, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "CSi", f => ( (StrokeFeatureItem)f ).CSi, new HistogramMarker.HistogramDefinition( 200 ) ) );

            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "Sd", f => ( (StrokeFeatureItem)f ).Sd, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "Vd", f => ( (StrokeFeatureItem)f ).Vd, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "CSd", f => ( (StrokeFeatureItem)f ).CSd, new HistogramMarker.HistogramDefinition( 200 ) ) );

            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "RL", f => ( (StrokeFeatureItem)f ).RL, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "RH", f => ( (StrokeFeatureItem)f ).RH, new HistogramMarker.HistogramDefinition( 200 ) ) );

            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "CSA0", f => ( (StrokeFeatureItem)f ).CSA0, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "CSA2", f => ( (StrokeFeatureItem)f ).CSA2, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "CSA4", f => ( (StrokeFeatureItem)f ).CSA4, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "CSAV", f => ( (StrokeFeatureItem)f ).CSAV, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "CSL0", f => ( (StrokeFeatureItem)f ).CSL0, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "CSL2", f => ( (StrokeFeatureItem)f ).CSL2, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "CSL4", f => ( (StrokeFeatureItem)f ).CSL4, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "CSLV", f => ( (StrokeFeatureItem)f ).CSLV, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "CSM0", f => ( (StrokeFeatureItem)f ).CSM0, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "CSM2", f => ( (StrokeFeatureItem)f ).CSM2, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "CSM4", f => ( (StrokeFeatureItem)f ).CSM4, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "CSMV", f => ( (StrokeFeatureItem)f ).CSMV, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "CSH0", f => ( (StrokeFeatureItem)f ).CSH0, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "CSH2", f => ( (StrokeFeatureItem)f ).CSH2, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "CSH4", f => ( (StrokeFeatureItem)f ).CSH4, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "CSHV", f => ( (StrokeFeatureItem)f ).CSHV, new HistogramMarker.HistogramDefinition( 200 ) ) );

            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "CAA0", f => ( (StrokeFeatureItem)f ).CAA0, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "CAA2", f => ( (StrokeFeatureItem)f ).CAA2, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "CAA4", f => ( (StrokeFeatureItem)f ).CAA4, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "CAAV", f => ( (StrokeFeatureItem)f ).CAAV, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "CAL0", f => ( (StrokeFeatureItem)f ).CAL0, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "CAL2", f => ( (StrokeFeatureItem)f ).CAL2, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "CAL4", f => ( (StrokeFeatureItem)f ).CAL4, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "CALV", f => ( (StrokeFeatureItem)f ).CALV, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "CAM0", f => ( (StrokeFeatureItem)f ).CAM0, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "CAM2", f => ( (StrokeFeatureItem)f ).CAM2, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "CAM4", f => ( (StrokeFeatureItem)f ).CAM4, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "CAMV", f => ( (StrokeFeatureItem)f ).CAMV, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "CAH0", f => ( (StrokeFeatureItem)f ).CAH0, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "CAH2", f => ( (StrokeFeatureItem)f ).CAH2, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "CAH4", f => ( (StrokeFeatureItem)f ).CAH4, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "CAHV", f => ( (StrokeFeatureItem)f ).CAHV, new HistogramMarker.HistogramDefinition( 200 ) ) );

            _Markers.AddRange( new LognormalMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "VA0", f => ( (StrokeFeatureItem)f ).VA0, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new LognormalMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "VA2", f => ( (StrokeFeatureItem)f ).VA2, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new LognormalMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "VA4", f => ( (StrokeFeatureItem)f ).VA4, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new LognormalMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "VAV", f => ( (StrokeFeatureItem)f ).VAV, new HistogramMarker.HistogramDefinition( 0, 0.1/200, 0.1/200, 0.1 ) ) );
            _Markers.AddRange( new LognormalMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "VL0", f => ( (StrokeFeatureItem)f ).VL0, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new LognormalMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "VL2", f => ( (StrokeFeatureItem)f ).VL2, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new LognormalMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "VL4", f => ( (StrokeFeatureItem)f ).VL4, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new LognormalMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "VLV", f => ( (StrokeFeatureItem)f ).VLV, new HistogramMarker.HistogramDefinition( 0, 0.001/200, 0.001/200, 0.001 ) ) );
            _Markers.AddRange( new LognormalMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "VM0", f => ( (StrokeFeatureItem)f ).VM0, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new LognormalMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "VM2", f => ( (StrokeFeatureItem)f ).VM2, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new LognormalMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "VM4", f => ( (StrokeFeatureItem)f ).VM4, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new LognormalMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "VMV", f => ( (StrokeFeatureItem)f ).VMV, new HistogramMarker.HistogramDefinition( 0, 0.001/200, 0.001/200, 0.001 ) ) );
            _Markers.AddRange( new LognormalMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "VH0", f => ( (StrokeFeatureItem)f ).VH0, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new LognormalMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "VH2", f => ( (StrokeFeatureItem)f ).VH2, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new LognormalMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "VH4", f => ( (StrokeFeatureItem)f ).VH4, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new LognormalMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "VHV", f => ( (StrokeFeatureItem)f ).VHV, new HistogramMarker.HistogramDefinition( 0, 0.001/200, 0.001/200, 0.001 ) ) );

            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "AA0", f => ( (StrokeFeatureItem)f ).AA0, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "AA2", f => ( (StrokeFeatureItem)f ).AA2, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "AA4", f => ( (StrokeFeatureItem)f ).AA4, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "AAV", f => ( (StrokeFeatureItem)f ).AAV, new HistogramMarker.HistogramDefinition( 0, 0.005/200, 0.005/200, 0.005 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "AL0", f => ( (StrokeFeatureItem)f ).AL0, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "AL2", f => ( (StrokeFeatureItem)f ).AL2, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "AL4", f => ( (StrokeFeatureItem)f ).AL4, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "ALV", f => ( (StrokeFeatureItem)f ).ALV, new HistogramMarker.HistogramDefinition( 0, 0.0001/200, 0.0001/200, 0.0001 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "AM0", f => ( (StrokeFeatureItem)f ).AM0, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "AM2", f => ( (StrokeFeatureItem)f ).AM2, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "AM4", f => ( (StrokeFeatureItem)f ).AM4, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "AMV", f => ( (StrokeFeatureItem)f ).AMV, new HistogramMarker.HistogramDefinition( 0, 0.0001/200, 0.0001/200, 0.0001 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "AH0", f => ( (StrokeFeatureItem)f ).AH0, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "AH2", f => ( (StrokeFeatureItem)f ).AH2, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "AH4", f => ( (StrokeFeatureItem)f ).AH4, new HistogramMarker.HistogramDefinition( 200 ) ) );
            _Markers.AddRange( new InverseGaussianMarkerExtractor().Extract( computeId, this, items, namePrefix +
                "AHV", f => ( (StrokeFeatureItem)f ).AHV, new HistogramMarker.HistogramDefinition( 0, 0.0001/200, 0.0001/200, 0.0001 ) ) );
        }
    }

    class StrokeFeatureExtractor : IFeatureExtractor<StrokeFeatureItem>
    {
        private int ends = 0;
        private int sharps = 0;
        private int totals = 0;

        #region IFeatureExtractor<StrokeFeatureItem> Members

        public IEnumerable<StrokeFeatureItem> AddEvent( Event input, IList<StrokeFeatureItem> previousItems )
        {
            var list = new List<StrokeFeatureItem>();

            if( previousItems == null || previousItems.Count == 0 )
            {
                list.Add( StrokeFeatureItem.Null() );
                buffer = new List<Event>();
            }
            else
            {
                HandleButton( ref list, Event.Button.Left, input );
                HandleButton( ref list, Event.Button.Middle, input );
                HandleButton( ref list, Event.Button.Right, input );
                HandleButton( ref list, Event.Button.B4, input );
                HandleButton( ref list, Event.Button.B5, input );

                totals++;
                if( input.dT >= TIME_THRESHOLD )
                {
                    ends++;
                }
                if( Math.Abs( input.FiTN ) >= ANGLE_THRESHOLD )
                {
                    sharps++;
                }

                if( list.Count == 0 && // no button caught,
                    ( input.dT >= TIME_THRESHOLD || Math.Abs( input.FiTN ) >= ANGLE_THRESHOLD ) ) // so try time or angle criterion
                {
                    if( buffer.Count > LENGTH_THRESHOLD ) // but only we have anything
                    {
                        list.Add( new StrokeFeatureItem( StrokeFeatureItem.ItemType.MoveEnded, null, buffer ) );
                    }
                    buffer = new List<Event>();
                }

                buffer.Add( input );
            }

            return list;
        }

        #endregion

        private void HandleButton( ref List<StrokeFeatureItem> list, Event.Button button, Event input )
        {
            if( input[button] == Event.ButtonState.Press )
            {
                clickedInput[button] = input;
                if( buffer.Count > LENGTH_THRESHOLD ) // but only we have anything
                {
                    list.Add( new StrokeFeatureItem( StrokeFeatureItem.ItemType.ToClick, button, buffer ) );
                }
                buffer = new List<Event>();
            }
            else if( input[button] == Event.ButtonState.DoublePress )
            {
                if( clickedInput[button] != null )
                {
                    if( buffer.Count > LENGTH_THRESHOLD ) // but only we have anything
                    {
                        list.Add( new StrokeFeatureItem( StrokeFeatureItem.ItemType.ToDoubleClick, button, buffer ) );
                    }
                    buffer = new List<Event>();
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
                    if( distance > DRAG_MOVEMENT_THRESHOLD )
                    {
                        if( buffer.Count > LENGTH_THRESHOLD ) // but only we have anything
                        {
                            list.Add( new StrokeFeatureItem( StrokeFeatureItem.ItemType.Drag, button, buffer ) );
                        }
                        buffer = new List<Event>();
                    }
                    clickedInput[button] = null;
                }
            }
        }

        private static double DRAG_MOVEMENT_THRESHOLD = 3;
        private static double LENGTH_THRESHOLD = 3;
        private static double TIME_THRESHOLD = 32;
        private static double ANGLE_THRESHOLD = Math.PI / 2;
        private Dictionary<Event.Button, Event> clickedInput = new Dictionary<Event.Button, Event>();
        private List<Event> buffer;
    }
}
