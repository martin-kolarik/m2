using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer.Statistics
{
    public static class HyperLog
    {
        public static double f( double p, double b = 1.0, double d = 1.0, double r = 1.0 )
        {
            var k = d / r;
            var bk = b * k;
            Func<double, Tuple<double, double, double>> eh = x =>
            {
                var ekx = x >= 0 ? Math.Exp( k*x ) : Math.Exp( -k*x );
                var kekx = k * ekx;
                var fv = x >= 0 ? ekx + bk*x - 1 - p : -ekx + bk*x + 1 - p;
                var dfv = kekx + bk;
                var d2fv = x >= 0 ? k*kekx : -k*kekx;
                return new Tuple<double, double, double>( fv, dfv, d2fv );
            };
            return new RootFinder( eh ).Find( 1e-9 );
        }
    }
}
