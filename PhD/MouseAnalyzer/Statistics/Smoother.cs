using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer.Statistics
{
    class SmootherOutput
    {
        public List<double> X { get; private set; }
        public List<double> Y { get; private set; }
        public List<double> T { get; private set; }

        public List<double> dX { get; private set; }
        public List<double> dY { get; private set; }
        public List<double> dT { get; private set; }

        public SmootherOutput( List<double> X, List<double> Y, List<double> T, List<double> dX, List<double> dY, List<double> dT )
        {
            this.X = X;
            this.Y = Y;
            this.T = T;

            this.dX = dX;
            this.dY = dY;
            this.dT = dT;
        }
    }

    class Smoother
    {
        public enum SmoothMethod
        {
            Spline,
            CatmullClark
        }

        public static SmootherOutput Smooth( SmoothMethod method, List<Event> input, int startFrom = 1 )
        {
            if( method == SmoothMethod.CatmullClark )
            {
                return SmoothCatmullClark( input, startFrom );
            }
            else
            {
                return SmoothSpline( input, startFrom );
            }
        }

        private static SmootherOutput SmoothCatmullClark( List<Event> input, int startFrom, int iterations = 3, double epsToStopSmoothing = 0.01 ) // start from skip item having dX, dY, dT and X, Y, T related to previous stroke; eps [pixel]
        {
            var skipped = input.Skip( startFrom );
            var xs = skipped.Select( i => (double)i.X ).ToList();
            var ys = skipped.Select( i => (double)i.Y ).ToList();
            var ts = skipped.Select( i => i.Time ).ToList();

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

                    if( dx*dx + dy*dy > epsToStopSmoothing ) // use new point
                    {
                        withinEps = false;

                        // center tb to xb,yb
                        var dxl = xc-xpm;
                        var dyl = yc-ypm;
                        var dl = Math.Sqrt( dxl*dxl + dyl*dyl );
                        //
                        var dxr = xm-xc;
                        var dyr = ym-yc;
                        var dr = Math.Sqrt( dxr*dxr + dyr*dyr );
                        //
                        var tb = tpm + dl/( dl+dr ) * ( tm - tpm );
                        tb = tc;

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
                        // tpm = tp + dl/( dl+dr ) * ( tb - tp );

                        nts.Add( tpm ); nts.Add( tc );
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
                    yp = yc; yc = yn; // move source point
                    tp = tc; tc = tn; // move source point
                    tpm = tm;
                }

                nxs.Add( xpm ); nxs.Add( xs.Last() ); // store last, it does not change
                nys.Add( ypm ); nys.Add( ys.Last() ); // store last, it does not change
                nts.Add( tpm ); nts.Add( ts.Last() ); // store last, it does not change

                // swith lists to continue
                xs = nxs;
                ys = nys;
                ts = nts;

                // terminate when criteria satisfied
                if( withinEps || --iterations == 0 )
                {
                    break;
                }
            }

            List<double> dxs = new List<double>() { 0.0 };
            List<double> dys = new List<double>() { 0.0 };
            List<double> dts = new List<double>() { 0.0 };

            for( var i = 1; i < xs.Count; i++ )
            {
                dxs.Add( xs[i] - xs[i-1] );
                dys.Add( ys[i] - ys[i-1] );
                dts.Add( ts[i] - ts[i-1] );
            }

            return new SmootherOutput( xs, ys, ts, dxs, dys, dts );
        }

        private static SmootherOutput SmoothSpline( List<Event> input, int startFrom, int samplesPerPoint = 2 )
        {
            var skipped = input.Skip( startFrom );
            var count = skipped.Count();
            var xs = skipped.Select( i => (double)i.X ).ToList();
            var ys = skipped.Select( i => (double)i.Y ).ToList();
            var ts = skipped.Select( i => i.Time ).ToList();

            var ps = new List<double>();
            for( var i = 0; i < count; i++ )
            {
                ps.Add( (double)i / (count-1) );
            }

            var xspline = new SmoothingSpline( ps.ToArray(), xs.ToArray(), null, 0.999 );
            xs = new List<double>();
            var yspline = new SmoothingSpline( ps.ToArray(), ys.ToArray(), null, 0.999 );
            ys = new List<double>();
            var tspline = new SmoothingSpline( ps.ToArray(), ts.ToArray(), null, 0.999 );
            ts = new List<double>();

            xs.Add( xspline.Evaluate( ps[0] ) );
            ys.Add( yspline.Evaluate( ps[0] ) );
            ts.Add( tspline.Evaluate( ps[0] ) );
            for( var i = 1; i < count; i++ )
            {
                var pointWidth = ps[i] - ps[i-1];
                for( int s = 1; s < samplesPerPoint; s++ )
                {
                    var samplepoint = ps[i-1] + ((double)s) * pointWidth / (double)samplesPerPoint;
                    xs.Add( xspline.Evaluate( samplepoint ) );
                    ys.Add( yspline.Evaluate( samplepoint ) );
                    ts.Add( tspline.Evaluate( samplepoint ) );
                }
                var point = ps[i];
                xs.Add( xspline.Evaluate( point ) );
                ys.Add( yspline.Evaluate( point ) );
                ts.Add( tspline.Evaluate( point ) );
            }

            List<double> dxs = new List<double>() { 0.0 };
            List<double> dys = new List<double>() { 0.0 };
            List<double> dts = new List<double>() { 0.0 };
            for( var i = 1; i < xs.Count; i++ )
            {
                dxs.Add( xs[i] - xs[i-1] );
                dys.Add( ys[i] - ys[i-1] );
                dts.Add( ts[i] - ts[i-1] );
            }

            return new SmootherOutput( xs, ys, ts, dxs, dys, dts );
        }
    }
}
