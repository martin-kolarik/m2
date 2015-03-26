using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer.Statistics
{
    /// <summary>
    ///   Gamma Γ(x) functions.
    /// </summary>
    ///  
    /// <remarks>
    /// <para>
    ///   In mathematics, the gamma function (represented by the capital Greek 
    ///   letter Γ) is an extension of the factorial function, with its argument
    ///   shifted down by 1, to real and complex numbers. That is, if <c>n</c> is
    ///   a positive integer:</para>
    /// <code>
    ///   Γ(n) = (n-1)!</code>
    /// <para>
    ///   The gamma function is defined for all complex numbers except the negative
    ///   integers and zero. For complex numbers with a positive real part, it is 
    ///   defined via an improper integral that converges:</para>
    /// <code>
    ///          ∞
    ///   Γ(z) = ∫  t^(z-1)e^(-t) dt
    ///          0
    /// </code>     
    /// <para>
    ///   This integral function is extended by analytic continuation to all 
    ///   complex numbers except the non-positive integers (where the function 
    ///   has simple poles), yielding the meromorphic function we call the gamma
    ///   function.</para>
    /// <para>
    ///   The gamma function is a component in various probability-distribution 
    ///   functions, and as such it is applicable in the fields of probability 
    ///   and statistics, as well as combinatorics.</para>
    ///   
    /// <para>
    ///   References:
    ///   <list type="bullet">
    ///     <item><description>
    ///       Wikipedia contributors, "Gamma function,". Wikipedia, The Free 
    ///       Encyclopedia. Available at: http://en.wikipedia.org/wiki/Gamma_function 
    ///       </description></item>
    ///     <item><description>
    ///       Cephes Math Library, http://www.netlib.org/cephes/ </description></item>
    ///   </list></para>
    /// </remarks>
    /// 
    /// <example>
    /// <code>
    ///   double x = 0.17;
    ///   
    ///   // Compute main Gamma function and variants
    ///   double gamma = Gamma.Function(x); // 5.4511741801042106
    ///   double gammap = Gamma.Function(x, p: 2); // -39.473585841300675
    ///   double log = Gamma.Log(x);        // 1.6958310313607003
    ///   double logp = Gamma.Log(x, p: 2); // 3.6756317353404273
    ///   double stir = Gamma.Stirling(x);  // 24.040352622960743
    ///   double psi = Gamma.Digamma(x);    // -6.2100942259248626
    ///   double tri = Gamma.Trigamma(x);   // 35.915302055854525
    ///
    ///   double a = 4.2;
    ///   
    ///   // Compute the incomplete regularized Gamma functions P and Q:
    ///   double lower = Gamma.LowerIncomplete(a, x); // 0.000015685073063633753
    ///   double upper = Gamma.UpperIncomplete(a, x); // 0.9999843149269364
    /// </code>
    /// </example>
    /// 
    public static class Gamma
    {

        /// <summary>Maximum gamma on the machine.</summary>
        public const double GammaMax = 171.624376956302725;

        /// <summary>
        ///   Gamma function of the specified value.
        /// </summary>
        /// 
        public static double Function( double x )
        {
            double[] P =
            {
                1.60119522476751861407E-4,
                1.19135147006586384913E-3,
                1.04213797561761569935E-2,
                4.76367800457137231464E-2,
                2.07448227648435975150E-1,
                4.94214826801497100753E-1,
                9.99999999999999996796E-1
            };
            double[] Q =
            {
               -2.31581873324120129819E-5,
                5.39605580493303397842E-4,
               -4.45641913851797240494E-3,
                1.18139785222060435552E-2,
                3.58236398605498653373E-2,
               -2.34591795718243348568E-1,
                7.14304917030273074085E-2,
                1.00000000000000000320E0
            };

            double p, z;

            double q = System.Math.Abs( x );

            if( q > 33.0 )
            {
                if( x < 0.0 )
                {
                    p = System.Math.Floor( q );

                    if( p == q )
                        throw new OverflowException();

                    z = q - p;
                    if( z > 0.5 )
                    {
                        p += 1.0;
                        z = q - p;
                    }
                    z = q * System.Math.Sin( System.Math.PI * z );

                    if( z == 0.0 )
                        throw new OverflowException();

                    z = System.Math.Abs( z );
                    z = System.Math.PI / ( z * Stirling( q ) );

                    return -z;
                }
                else
                {
                    return Stirling( x );
                }
            }

            z = 1.0;
            while( x >= 3.0 )
            {
                x -= 1.0;
                z *= x;
            }

            while( x < 0.0 )
            {
                if( x == 0.0 )
                {
                    throw new ArithmeticException();
                }
                else if( x > -1.0E-9 )
                {
                    return ( z / ( ( 1.0 + 0.5772156649015329 * x ) * x ) );
                }
                z /= x;
                x += 1.0;
            }

            while( x < 2.0 )
            {
                if( x == 0.0 )
                {
                    throw new ArithmeticException();
                }
                else if( x < 1.0E-9 )
                {
                    return ( z / ( ( 1.0 + 0.5772156649015329 * x ) * x ) );
                }

                z /= x;
                x += 1.0;
            }

            if( ( x == 2.0 ) || ( x == 3.0 ) ) return z;

            x -= 2.0;
            p = Polevl( x, P, 6 );
            q = Polevl( x, Q, 7 );
            return z * p / q;
        }

        /// <summary>
        ///   Gamma function as computed by Stirling's formula.
        /// </summary>
        /// 
        private static double Stirling( double x )
        {
            double[] STIR =
            {
                 7.87311395793093628397E-4,
                -2.29549961613378126380E-4,
                -2.68132617805781232825E-3,
                 3.47222221605458667310E-3,
                 8.33333333333482257126E-2,
            };

            double MAXSTIR = 143.01608;

            double w = 1.0 / x;
            double y = Math.Exp( x );

            w = 1.0 + w * Polevl( w, STIR, 4 );

            if( x > MAXSTIR )
            {
                double v = Math.Pow( x, 0.5 * x - 0.25 );
                y = v * ( v / y );
            }
            else
            {
                y = System.Math.Pow( x, x - 0.5 ) / y;
            }

            y = Sqrt2PI * y * w;
            return y;
        }

        /// <summary>
        ///   Evaluates polynomial of degree N
        /// </summary>
        /// 
        private static double Polevl( double x, double[] coef, int n )
        {
            double ans;

            ans = coef[0];

            for( int i = 1; i <= n; i++ )
                ans = ans * x + coef[i];

            return ans;
        }

        private const double Sqrt2PI = 2.50662827463100050242E0;
    }
}