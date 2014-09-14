using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using MouseAnalyzer.Lookup;

namespace MouseAnalyzer.Optimizer
{
    class Distance :
        Tuple<Template.DistanceType, Population.DistanceMeasureType>
    {
        private static Distance[] permutation = new Distance[] {
            new Distance( Template.DistanceType.Manhattan, Population.DistanceMeasureType.Average ),
            new Distance( Template.DistanceType.Manhattan, Population.DistanceMeasureType.LimitedAverage ),
            new Distance( Template.DistanceType.Manhattan, Population.DistanceMeasureType.GeometricAverage ),
            new Distance( Template.DistanceType.Manhattan, Population.DistanceMeasureType.Median ),
            new Distance( Template.DistanceType.Manhattan, Population.DistanceMeasureType.Minimum ),
            new Distance( Template.DistanceType.Manhattan, Population.DistanceMeasureType.MinimumTimesMedian ),
            new Distance( Template.DistanceType.Manhattan, Population.DistanceMeasureType.Summation ),

            new Distance( Template.DistanceType.Euclidean, Population.DistanceMeasureType.Average ),
            new Distance( Template.DistanceType.Euclidean, Population.DistanceMeasureType.LimitedAverage ),
            new Distance( Template.DistanceType.Euclidean, Population.DistanceMeasureType.GeometricAverage ),
            new Distance( Template.DistanceType.Euclidean, Population.DistanceMeasureType.Median ),
            new Distance( Template.DistanceType.Euclidean, Population.DistanceMeasureType.Minimum ),
            new Distance( Template.DistanceType.Euclidean, Population.DistanceMeasureType.MinimumTimesMedian ),
            new Distance( Template.DistanceType.Euclidean, Population.DistanceMeasureType.Summation )
        };

        public static Distance[] Permutation
        {
            get { return permutation; }
        }

        public Distance( Template.DistanceType type, Population.DistanceMeasureType processing ) :
            base( type, processing )
        {
        }

        public Distance( Template.DistanceType type ) :
            base( type, Population.DistanceMeasureType.Average )
        {
        }

        public Distance( Population.DistanceMeasureType processing ) :
            base( Template.DistanceType.Euclidean, processing )
        {
        }

        public Distance() :
            base( Template.DistanceType.Euclidean, Population.DistanceMeasureType.Average )
        {
        }

        public Template.DistanceType Type
        {
            get { return Item1; }
        }

        public Population.DistanceMeasureType Processing
        {
            get { return Item2; }
        }

        public override string ToString()
        {
            return Item1.ToString() + "(" + Item2.ToString() + ")";
        }

        public override bool Equals( object to )
        {
            if( to == null )
            {
                return false;
            }
            var foreign = (Distance)to;
            return Type == foreign.Type && Processing == foreign.Processing;
        }

        public override int GetHashCode()
        {
            return 100 * (int)Type + (int)Processing;
        }
    }
}
