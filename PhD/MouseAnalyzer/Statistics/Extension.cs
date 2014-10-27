using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer.Statistics
{
    static class Extension
    {
        public static double Product( this IEnumerable<double> source ) // expects source[i] > 0.0
        {
            var product = 1.0;
            source.Select( value => product *= value ).Count();
            return product;
        }

        public static double GeometricAverage( this IEnumerable<double> source ) // expects source[i] > 0.0
        {
            var logs = source.Select( value => Math.Log( value ) );
            return Math.Exp( logs.Average() );
        }

        public static double Variance( this IEnumerable<double> source, bool isSample = false )
        {
            int count = 0;
            double delta = 0;
            double mean = 0;
            double sumOfDiffSquares = 0;

            foreach( double value in source )
            {
                count++;
                delta = value - mean;
                mean = mean + ( delta / count );
                sumOfDiffSquares = sumOfDiffSquares + delta * ( value - mean );
            }

            // Switch calculation and item minimum based upon sample or population flag
            if( isSample )
            {
                return count <= 1 ? 0 : sumOfDiffSquares / ( count - 1 );
            }
            else
            {
                return count == 0 ? 0 : sumOfDiffSquares / count;
            }
        }
    }
}
