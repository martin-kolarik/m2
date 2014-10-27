using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer.Experiment
{
    class SmoothingExperiment : IExperiment
    {
        private static double[] XS = {
            631.0, 627.0, 625.0, 624.0, 623.0, 622.0, 621.0, 620.0, 619.0, 617.0, 613.0, 607.0, 604.0, 599.0, 595.0, 591.0, 590.0,
            587.0, 586.0, 584.0, 582.0, 580.0, 578.0, 575.0, 572.0, 568.0, 566.0, 563.0, 562.0, 561.0, 560.0, 558.0, 557.0, 556.0,
            555.0, 554.0, 553.0, 553.0, 553.0, 552.0, 550.0, 550.0, 550.0, 550.0, 549.0, 547.0, 546.0, 546.0, 545.0, 545.0, 545.0,
            545.0, 545.0, 543.0, 543.0, 543.0, 543.0, 543.0, 543.0, 543.0, 543.0, 543.0, 543.0, 543.0, 543.0, 543.0, 542.0, 540.0,
            540.0, 540.0, 538.0, 537.0, 537.0, 537.0, 535.0, 533.0, 533.0, 532.0, 532.0, 532.0,
            532.0, 532.0, 532.0, 533.0 };

        private static double[] YS = {
            306.0, 301.0, 301.0, 301.0, 301.0, 301.0, 301.0, 301.0, 301.0, 301.0, 300.0, 300.0, 300.0, 300.0, 300.0, 300.0, 300.0,
            300.0, 300.0, 300.0, 301.0, 301.0, 302.0, 302.0, 303.0, 303.0, 303.0, 304.0, 304.0, 304.0, 304.0, 305.0, 306.0, 307.0,
            308.0, 309.0, 310.0, 312.0, 316.0, 318.0, 321.0, 324.0, 328.0, 332.0, 336.0, 341.0, 346.0, 349.0, 353.0, 358.0, 363.0,
            368.0, 372.0, 377.0, 379.0, 383.0, 387.0, 392.0, 395.0, 400.0, 403.0, 407.0, 412.0, 416.0, 422.0, 428.0, 433.0, 440.0,
            446.0, 453.0, 459.0, 465.0, 469.0, 475.0, 478.0, 482.0, 484.0, 488.0, 490.0, 491.0,
            492.0, 493.0, 494.0, 495.0 };

        #region IExperiment Members

        public void Perform( string outputFileNameHint = "" )
        {
            var LIMIT = 0.01; // pixel
            var COUNT = 3;

            var ts = new List<double>();
            for( var i = 0; i < XS.Length; i++ )
            {
                ts.Add( i*8.0 );
            }
            var TS = ts;

            var eps = LIMIT * LIMIT;
            var xs = XS.ToList();
            var ys = YS.ToList();

            for( ; ; )
            {
                List<double> nxs = new List<double>();
                List<double> nys = new List<double>();
                List<double> nts = new List<double>();
                var withinEps = true;

                var xp = xs[0]; nxs.Add( xp ); // store first, it does not change
                var yp = ys[0]; nys.Add( yp );
                var tp = ts[0]; nts.Add( tp );

                var xc = xs[1]; // start iteration preparing previous value
                var xpm = 0.5 * ( xp + xc ); // previous mid
                var yc = ys[1];
                var ypm = 0.5 * ( yp + yc );
                var tc = ts[1];
                var tpm = 0.5 * ( tp + tc );
                for( int i = 2; i < xs.Count; i++ )
                {
                    // X
                    var xn = xs[i]; // load current, next, i is ahead of 1 so +1 is not necessary
                    var xm = 0.5 * ( xc + xn ); // compute next mid
                    var xb = ( xpm + xc + xm ) / 3; // compute new barycenter to replace current
                    var dx = xb - xc; // evaluate closeness

                    // Y
                    var yn = ys[i]; // load current, next, i is ahead of 1 so +1 is not necessary
                    var ym = 0.5 * ( yc + yn ); // compute next mid
                    var yb = ( ypm + yc + ym ) / 3; // compute new barycenter to replace current
                    var dy = yb - yc; // evaluate closeness

                    // T
                    var tn = ts[i];
                    var tm = 0.5 * ( tc + tn ); // compute next mid

                    if( dx*dx + dy*dy > eps ) // use new point
                    {
                        withinEps = false;

                        // center tb to xb,yb
                        var dxl = xc-xpm;
                        var dyl = yc-ypm;
                        var dl = Math.Sqrt( dxl*dxl + dyl*dyl );
                        //
                        var dxr = xm-xc;
                        var dyr = yc-ym;
                        var dr = Math.Sqrt( dxr*dxr + dyr*dyr );
                        //
                        var tb = tpm + dl/(dl+dr) * ( tm - tpm );

                        xpm = ( xp + xpm + xb ) / 3;
                        nxs.Add( xpm ); nxs.Add( xb );

                        ypm = ( yp + ypm + yb ) / 3;
                        nys.Add( ypm ); nys.Add( yb );

                        // center tpm to xpm,ypm
                        dxl = xpm-xp;
                        dyl = ypm-yp;
                        dl = Math.Sqrt( dxl*dxl + dyl*dyl );
                        //
                        dxr = xb-xpm;
                        dyr = yb-ypm;
                        dr = Math.Sqrt( dxr*dxr + dyr*dyr );
                        //
                        tpm = tp + dl/(dl+dr) * ( tb - tp );

                        nts.Add( tpm ); nts.Add( tb );
                    }
                    else
                    {
                        nxs.Add( xc );
                        nys.Add( yc );
                        nts.Add( tc );
                    }

                    xpm = xm; // move mid
                    xp = xc; xc = xn; // move source point
                    ypm = ym; // move mid
                    yp = yc;  yc = yn; // move source point
                    tp = tc; tc = tn; // move source point
                    tpm = tm;
                }

                nxs.Add( xpm ); nxs.Add( xs.Last() ); // store last, it does not change
                nys.Add( ypm ); nys.Add( ys.Last() ); // store last, it does not change
                nts.Add( tpm ); nts.Add( ts.Last() ); // store last, it does not change

                if( withinEps || --COUNT == 0 )
                {
                    var dumper = new CSVDumper();
                    dumper.AddContent( "", d =>
                    {
                        var headers = new List<object>();
                        var columns = new List<IEnumerable<object>>();

                        headers.Add( "src x" );
                        headers.Add( "src y" );
                        headers.Add( "src t" );
                        headers.Add( "smooth x" );
                        headers.Add( "smooth y" );
                        headers.Add( "smooth t" );

                        columns.Add( XS.Select( x => x.ToString( "G5" ) ) );
                        columns.Add( YS.Select( y => y.ToString( "G5" ) ) );
                        columns.Add( TS.Select( t => t.ToString( "G5" ) ) );
                        columns.Add( nxs.Select( x => x.ToString( "G5" ) ) );
                        columns.Add( nys.Select( y => y.ToString( "G5" ) ) );
                        columns.Add( nts.Select( t => t.ToString( "G5" ) ) );

                        d.Columns( headers, columns );
                    } );

                    dumper.Dump( "x-s" );    

                    break;
                }
                else // switch lists and continue
                {
                    xs = nxs;
                    ys = nys;
                    ts = nts;
                }
            }
        }

        #endregion
    }
}
