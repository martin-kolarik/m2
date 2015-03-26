using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer.Statistics
{
    public class RootFinder // Newton/Householder's method, works only for converging functions (having used derivations nonzero)
    {
        public RootFinder( Func<double, double> f, Func<double, double> df, Func<double, double> d2f = null )
        {
            this.f = f;
            this.df = df;
            this.d2f = d2f;
        }

        public RootFinder( Func<double, Tuple<double,double>> fdf )
        {
            this.fdf = fdf;
        }

        public RootFinder( Func<double, Tuple<double,double,double>> fdfd2f )
        {
            this.fdfd2f = fdfd2f;
        }

        public double Find( double eps )
        {
            if( fdfd2f == null && d2f == null )
            {
                return FindNewton( eps );
            }
            else
            {
                return FindHalley( eps );
            }
        }

        private double FindNewton( double eps )
        {
            double x = 0;
            double prevx = x + 2*eps;
            while( Math.Abs( x - prevx ) >= eps )
            {
                double fv;
                double dfv;
                if( fdf == null )
                {
                    fv = f( x );
                    dfv = df( x );
                }
                else
                {
                    var fdfv = fdf( x );
                    fv = fdfv.Item1;
                    dfv = fdfv.Item2;
                }
                prevx = x;
                x = prevx - fv / dfv;
            }
            return x;
        }

        private double FindHalley( double eps )
        {
            double x = 0;
            double prevx = x + 2*eps;
            while( Math.Abs( x - prevx ) >= eps )
            {
                double fv;
                double dfv;
                double d2fv;
                if( fdfd2f == null )
                {
                    fv = f( x );
                    dfv = df( x );
                    d2fv = d2f( x );
                }
                else
                {
                    var fdfd2fv = fdfd2f( x );
                    fv = fdfd2fv.Item1;
                    dfv = fdfd2fv.Item2;
                    d2fv = fdfd2fv.Item3;
                }
                prevx = x;
                x = prevx - ( fv * dfv ) / ( dfv * dfv - 0.5 * fv * d2fv );
            }
            return x;
        }

        private Func<double, double> f;
        private Func<double, double> df;
        private Func<double, double> d2f;
        private Func<double, Tuple<double,double>> fdf;
        private Func<double, Tuple<double,double,double>> fdfd2f;
    }
}
