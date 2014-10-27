using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer.Statistics
{
    class Polynomial
    {
        private double[] coeff;

        public Polynomial( double[] coeff )
        {
            this.coeff = coeff;
        }

        public int Degree
        {
            get { return coeff.Length - 1; }
        }

        public double[] Coefficients
        {
            get { return coeff; }
        }

        public double Evaluate( double x )
        {
            var degree = Degree;
            double res = coeff[degree];
            for( int i = degree - 1; i >= 0; i-- )
            {
                res = coeff[i] + x * res;
            }
            return res;
        }

        public double Derivative( double x )
        {
            return Derivative( x, 1 );
        }

        public double Derivative( double x, int n )
        {
            var degree = Degree;
            if( n == 0 )
            {
                return Evaluate( x );
            }
            else if( n >= degree+1 )
            {
                return 0;
            }
            else
            {
                double res = getCoeffDer( Degree, n );
                for( int i = degree-1; i >= n; i-- )
                {
                    res = getCoeffDer( i, n ) + x * res;
                }
                return res;
            }
        }

        public Polynomial derivativePolynomial( int n )
        {
            var degree = Degree;
            var degreePlusOne = degree + 1;
            if( n >= degreePlusOne )
            {
                return new Polynomial( new double[] { 0 } );
            }
            else
            {
                double[] coeffDer = new double[degreePlusOne - n];
                for( int i = degree; i >= n; i-- )
                {
                    coeffDer[i - n] = getCoeffDer( i, n );
                }
                return new Polynomial( coeffDer );
            }
        }

        private double getCoeffDer( int i, int n )
        {
            double coeffDer = coeff[i];
            for( int j = i; j > i - n; j-- )
            {
                coeffDer *= j;
            }
            return coeffDer;
        }

        public Polynomial IntegralPolynomial( double c )
        {
            var degreePlusOne = Degree + 1;
            double[] coeffInt = new double[degreePlusOne + 1];
            coeffInt[0] = c;
            for( int i = 0; i < degreePlusOne; i++ )
            {
                coeffInt[i + 1] = coeff[i] / ( i + 1 );
            }
            return new Polynomial( coeffInt );
        }
    }

    class SmoothingSpline
    {
        private Polynomial[] splineVector;
        private IList<double> x, y, weight;
        private double rho;

        public SmoothingSpline( IList<double> x, IList<double> y, IList<double> w, double rho )
        {

            splineVector = new Polynomial[x.Count+1];
            this.rho = rho;
            this.x = x;
            this.y = y;

            weight = new double[x.Count];
            if( w == null )
            {
                for( int i = 0; i < weight.Count; i++ )
                {
                    weight[i] = 1.0;
                }
            }
            else
            {
                for( int i = 0; i < weight.Count; i++ )
                {
                    weight[i] = w[i];
                }
            }

            Resolve();
        }

        public double Evaluate( double z, bool trimToRange = false )
        {
            int i = getPolynomialIndex( z );
            if( i == 0 )
            {
                var xp = trimToRange && z < x[0] ? 0 : z-x[0];
                return splineVector[i].Evaluate( xp );
            }
            else
            {
                var lastX = x[x.Count-1];
                var xp = trimToRange && z > lastX ? 0 : z-x[i-1];
                return splineVector[i].Evaluate( xp );
            }
        }

        public double Derivative( double z )
        {
            return Derivative( z, 1 );
        }

        public double Derivative( double z, int n )
        {
            int i = getPolynomialIndex( z );
            if( i == 0 )
            {
                return splineVector[i].Derivative( z - x[0], n );
            }
            else
            {
                return splineVector[i].Derivative( z - x[i-1], n );
            }
        }

        private int getPolynomialIndex( double x )
        {
            // Algorithme de recherche binaire legerement modifie
            int j = this.x.Count-1;
            if( x > this.x[j] )
            {
                return j+1;
            }
            int tmp = 0;
            int i = 0;

            while( i+1 != j )
            {
                if( x > this.x[tmp] )
                {
                    i = tmp;
                }
                else
                {
                    j = tmp;
                }
                tmp = i+( j-i )/2;
                if( j == 0 )
                {
                    i--;
                }
            }
            return i+1;
        }

        private void Resolve()
        {
            /*
               taken from D.S.G Pollock's paper, "Smoothing with Cubic Splines",
               Queen Mary, University of London (1993)
               http://www.qmw.ac.uk/~ugte133/PAPERS/SPLINES.PDF
            */

            var length = x.Count;
            double[] h = new double[length];
            double[] r = new double[length];
            double[] u = new double[length];
            double[] v = new double[length];
            double[] w = new double[length];
            double[] q = new double[length+1];
            double[] sigma = new double[weight.Count];

            for( int i = 0; i < weight.Count; i++ )
            {
                if( weight[i] <= 0.0 )
                {
                    sigma[i] = 1.0e100;
                }
                else
                {
                    sigma[i] = 1.0/Math.Sqrt( weight[i] );
                }
            }

            double mu;
            int n = length-1;

            if( rho <= 0 )
            {
                mu = 1.0e100;   // arbitrary large number to avoid 1/0
            }
            else
            {
                mu = 2 * ( 1 - rho )/( 3 * rho );
            }

            h[0] = x[1] - x[0];
            r[0] = 3/h[0];
            for( int i = 1; i < n; i++ )
            {
                h[i] = x[i+1] - x[i];
                r[i] = 3/h[i];
                q[i] = 3 * ( y[i+1] - y[i] )/h[i] - 3 * ( y[i] - y[i-1] )/h[i - 1];
            }

            for( int i = 1; i < n; i++ )
            {
                u[i] =
                    r[i-1]*r[i-1] * sigma[i-1] +
                    ( r[i - 1] + r[i] )*( r[i - 1] + r[i] ) * sigma[i] +
                    r[i]*r[i] * sigma[i+1];
                u[i] =
                    mu * u[i] +
                    2 * ( x[i+1] - x[i-1] );
                v[i] =
                    -( r[i - 1] + r[i] ) * r[i] * sigma[i] -
                    r[i] * ( r[i] + r[i+1] ) * sigma[i+1];
                v[i] =
                    mu * v[i] +
                    h[i];
                w[i] =
                    mu * r[i] * r[i+1] * sigma[i+1];
            }
            q = Quincunx( u, v, w, q );

            // extrapolation a gauche
            double[] pars = new double[4];
            double dd;
            pars[0] = y[0] - mu * r[0] * q[1] * sigma[0];
            dd = y[1] - mu * ( ( -r[0] - r[1] ) * q[1] + r[1] * q[2] ) * sigma[1];
            pars[1] = ( dd - pars[0] )/h[0] - q[1] * h[0]/3;
            splineVector[0] = new Polynomial( pars );

            // premier polynome
            pars = new double[4];
            pars[0] = y[0] - mu * r[0] * q[1] * sigma[0];
            dd = y[1] - mu * ( ( -r[0] - r[1] ) * q[1] + r[1] * q[2] ) * sigma[1];
            pars[3] = q[1]/( 3 * h[0] );
            pars[2] = 0;
            pars[1] = ( dd - pars[0] )/h[0] - q[1] * h[0]/3;
            splineVector[1] = new Polynomial( pars );

            // les polynomes suivants
            int j;
            for( j = 1; j < n; j++ )
            {
                pars = new double[4];
                pars[3] = ( q[j + 1] - q[j] )/( 3 * h[j] );
                pars[2] = q[j];
                pars[1] = ( q[j] + q[j - 1] ) * h[j - 1] + splineVector[j].Coefficients[1];
                pars[0] = r[j - 1] * q[j - 1] + ( -r[j-1] - r[j] ) * q[j] + r[j] * q[j + 1];
                pars[0] = y[j] - mu * pars[0] * sigma[j];
                splineVector[j+1] = new Polynomial( pars );
            }

            // extrapolation a droite
            j = n;
            pars = new double[4];
            pars[3] = 0;
            pars[2] = 0;
            pars[1] = splineVector[j].Derivative( x[length-1]-x[length-2] );
            pars[0] = splineVector[j].Evaluate( x[length-1]-x[length-2] );
            splineVector[n+1] = new Polynomial( pars );
        }

        private static double[] Quincunx( double[] u, double[] v, double[] w, double[] q )
        {
            var length = u.Length;

            u[0] = 0;
            v[1] = v[1]/u[1];
            w[1] = w[1]/u[1];
            int j;

            for( j = 2; j < length-1; j++ )
            {
                u[j] = u[j] - u[j - 2] * w[j-2]*w[j-2] - u[j - 1] * v[j-1]*v[j-1];
                v[j] = ( v[j] - u[j - 1] * v[j-1] * w[j-1] )/u[j];
                w[j] = w[j]/u[j];
            }

            // forward substitution
            q[1] = q[1] - v[0] * q[0];
            for( j = 2; j < length-1; j++ )
            {
                q[j] = q[j] - v[j - 1] * q[j - 1] - w[j - 2] * q[j - 2];
            }
            for( j = 1; j < length-1; j++ )
            {
                q[j] = q[j]/u[j];
            }

            // back substitution
            q[length-1] = 0;
            for( j = length-3; j > 0; j-- )
            {
                q[j] = q[j] - v[j] * q[j + 1] - w[j] * q[j + 2];
            }
            return q;
        }
    }


}
