using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace TemplateOptimizer
{
    class Template : Vector
    {
        public Template( int componentCount ) :
            base( componentCount )
        {
        }

        public Template( IEnumerable<double> source ) :
            base( source )
        {
        }

        public double Distance( Template from, Weights weights )
        {
            var distance = 0.0;
            for( var i = 0; i < ComponentCount; i++ )
            {
                var wi = weights[i];
                var di = from[i] - this[i];
                distance += wi * wi * di * di;
            }
            return Math.Sqrt( distance );
        }
    }
}
