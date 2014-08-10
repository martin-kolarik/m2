using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using MouseAnalyzer.Lookup;

namespace MouseAnalyzer.Optimizer
{
    class Distance :
        Tuple<Template.DistanceType, Population.DistanceProcessing>
    {
        private static Distance[] permutation = new Distance[] {
            new Distance( Template.DistanceType.Manhattan, Population.DistanceProcessing.Average ),
            new Distance( Template.DistanceType.Manhattan, Population.DistanceProcessing.LimitedAverage ),
            new Distance( Template.DistanceType.Manhattan, Population.DistanceProcessing.GeometricAverage ),
            new Distance( Template.DistanceType.Manhattan, Population.DistanceProcessing.Median ),
            new Distance( Template.DistanceType.Manhattan, Population.DistanceProcessing.Minimum ),
            new Distance( Template.DistanceType.Manhattan, Population.DistanceProcessing.MinimumTimesMedian ),
            new Distance( Template.DistanceType.Manhattan, Population.DistanceProcessing.Summation ),

            new Distance( Template.DistanceType.Euclidean, Population.DistanceProcessing.Average ),
            new Distance( Template.DistanceType.Euclidean, Population.DistanceProcessing.LimitedAverage ),
            new Distance( Template.DistanceType.Euclidean, Population.DistanceProcessing.GeometricAverage ),
            new Distance( Template.DistanceType.Euclidean, Population.DistanceProcessing.Median ),
            new Distance( Template.DistanceType.Euclidean, Population.DistanceProcessing.Minimum ),
            new Distance( Template.DistanceType.Euclidean, Population.DistanceProcessing.MinimumTimesMedian ),
            new Distance( Template.DistanceType.Euclidean, Population.DistanceProcessing.Summation )
        };

        public static Distance[] Permutation
        {
            get { return permutation; }
        }

        public Distance( Template.DistanceType type, Population.DistanceProcessing processing ) :
            base( type, processing )
        {
        }

        public Distance( Template.DistanceType type ) :
            base( type, Population.DistanceProcessing.Average )
        {
        }

        public Distance( Population.DistanceProcessing processing ) :
            base( Template.DistanceType.Euclidean, processing )
        {
        }

        public Distance() :
            base( Template.DistanceType.Euclidean, Population.DistanceProcessing.Average )
        {
        }

        public Template.DistanceType Type
        {
            get { return Item1; }
        }

        public Population.DistanceProcessing Processing
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
