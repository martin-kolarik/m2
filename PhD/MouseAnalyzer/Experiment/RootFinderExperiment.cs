using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using MouseAnalyzer.Statistics;

namespace MouseAnalyzer.Experiment
{
    class RootFinderExperiment : IExperiment
    {
        #region IExperiment Members

        public void Perform( string outputFileNameHint = "" )
        {
            Func<double, double> f = x => -1 + 10*x + 6*x*x + x*x*x;
            Func<double, double> df = x => 10 + 12*x + 3*x*x;
            Func<double, double> d2f = x => 12 + 6*x;
            Func<double, Tuple<double, double>> newton = x => new Tuple<double, double>( f( x ), df( x ) );
            Func<double, Tuple<double, double, double>> halley = x => new Tuple<double, double, double>( f( x ), df( x ), d2f( x ) );

            var rfn1 = new RootFinder( f, df );
            var xn1 = rfn1.Find( 1e-6 );

            var rfh1 = new RootFinder( f, df, d2f );
            var xh1 = rfh1.Find( 1e-6 );

            var rfn2 = new RootFinder( newton );
            var xn2 = rfn2.Find( 1e-6 );

            var rfh2 = new RootFinder( halley );
            var xh2 = rfh2.Find( 1e-6 );

            var hlx1 = new double[] { -1000, -100, -10, -1, -0.1, -0.01, -0.001, -0.0001, 0, 0.0001, 0.001, 0.01, 0.1, 1, 10, 100, 1000 };
            var hly1 = hlx1.Select( x => HyperLog.f( x, 0.1, 0.0001 ) ).ToArray();
            var hly1ihs = hlx1.Select( x => Math.Log(1e4*x + Math.Sqrt( 1e8*x*x + 1.0 ) ) ).ToArray();

            var hlx2 = new double[] { -0.0005, -0.0004, -0.0003, -0.0002, -0.0001, -0.000001, 0, 0.000001, 0.0001, 0.0002, 0.0003, 0.0004, 0.0005 };
            var hly2 = hlx2.Select( x => HyperLog.f( 1000000*x, 1, 1 ) ).ToArray();
            var hly2ihs = hlx2.Select( x => Math.Log(1e6*x + Math.Sqrt( 1e12*x*x + 1.0 ) ) ).ToArray();
        }

        #endregion
    }
}
