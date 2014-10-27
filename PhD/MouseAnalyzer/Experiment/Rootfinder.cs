using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer.Statistics
{
    public class Rootfinder // Newton/Householder's method, works only for converging functions (having used derivations nonzero)
    {
        public Rootfinder( Func<double, double> f, Func<double, double> df, Func<double, double> d2f )
        {
            this.f = f;
            this.df = df;
            this.d2f = d2f;
        }

        public Rootfinder( Func<double, Tuple<double,double>> fdf )
        {
            this.fdf = fdf;
        }

        public Rootfinder( Func<double, Tuple<double,double,double>> fdfd2f )
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

        private double FindNewton( double xeps )
        {
            double x = 0;
            double prevx = double.NaN;
            while( Math.Abs( x - prevx ) < xeps )
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

        private double FindHalley( double xeps )
        {
            double x = 0;
            double prevx = double.NaN;
            while( Math.Abs( x - prevx ) < xeps )
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
