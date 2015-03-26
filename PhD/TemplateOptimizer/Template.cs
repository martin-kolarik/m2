using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace TemplateOptimizer
{
    class Template : Vector
    {
        public enum DistanceType
        {
            Manhattan,
            Euclidean
        }

        public Template( int componentCount ) :
            base( componentCount )
        {
        }

        public Template( IEnumerable<double> source ) :
            base( source )
        {
        }

        public double Distance( Template from, Distance distance, Weights weights )
        {
            return Distance( from, distance.Type, weights );
        }

        public double Distance( Template from, DistanceType distanceType, Weights weights )
        {
            var distance = 0.0;
            for( var i = 0; i < ComponentCount; i++ )
            {
                var wi = weights[i];
                var di = from[i] - this[i];
                if( distanceType == DistanceType.Manhattan )
                {
                    distance += wi * Math.Abs( di );
                }
                else
                {
                    distance += wi * wi * di * di;
                }
            }
            return distanceType == DistanceType.Manhattan ? distance : Math.Sqrt( distance );
        }
    }
}
