using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using MouseAnalyzer.Optimizer;

namespace MouseAnalyzer.Lookup
{
    class Template : Vector
    {
        public enum DistanceType
        {
            Manhattan,
            Euclidean
        }

        public Template( Entity entity, int componentCount ) :
            base( componentCount )
        {
            Entity = entity;
        }

        public Template( Entity entity, IEnumerable<double> source ) :
            base( source )
        {
            Entity = entity;
        }

        public Template( Entity entity ) :
            base( entity.Markers.Where( m1 => m1 is IValueMarker ).Select( m2 => ( (IValueMarker)m2 ).Value ) )
        {
            Entity = entity;
        }

        public Entity Entity { get; private set; }

        public double Distance( Template from, Distance distance, Weights weights, Weights mask = null )
        {
            return Distance( from, distance.Type, weights, mask );
        }

        public double Distance( Template from, DistanceType distanceType, Weights weights, Weights mask = null )
        {
            var distance = 0.0;
            for( var i = 0; i < ComponentCount; i++ )
            {
                if( mask != null && mask[i] == 0.0 )
                {
                    continue;
                }
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
