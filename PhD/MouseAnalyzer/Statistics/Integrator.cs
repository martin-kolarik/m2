using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer.Statistics
{
    public static class Integrator // Runge-Kutta 4th order for x only = Simpson's rule
    {
        public static double Integrate( Func<double, double> derivative, double from, double to, int steps = 0 )
        {
            var diff = Math.Abs( to - from );
            var h = diff / (steps == 0 ? 10 : steps);
            var h2 = h / 2.0;

            var x = from;
            var y = 0.0;

            var f = derivative( from );
            while( x < to )
            {
                double f1 = f;
                double f2 = derivative( x + h2 );
                double f3 = derivative( x + h );

                x += h;
                y += h / 6.0 * ( f1 + 4.0*f2 + f3 );
                f = f3;
            }

            return y;
        }
    }
}
