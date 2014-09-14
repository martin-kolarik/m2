using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace MouseAnalyzer.Optimizer
{
    class Weights : Vector
    {
        public static Weights Uniform( int componentCount )
        {
            var weights = new Weights( componentCount );
            for( int i = 0; i < componentCount; i++ )
            {
                weights[i] = 1.0;
            }
            return weights.Weigh();
        }

        public Weights( int componentCount ) :
            base( componentCount )
        {
        }

        public Weights( IEnumerable<double> source ) :
            base( source )
        {
            PerformWeighing();
        }

        public new double this[int component]
        {
            get
            {
                return base[component];
            }
            set
            {
                base[component] = value > 1.0 ? 1.0 : ( value < 0.0 ? 0.0 : value );
            }
        }

        public Weights Weigh()
        {
            return new Weights( Components );
        }

        private void PerformWeighing()
        {
            var sum = 0.0;
            for( var i = 0; i < ComponentCount; i++ )
            {
                sum += this[i];
            }
            for( var i = 0; i < ComponentCount; i++ )
            {
                this[i] /= sum;
            }
        }
    }
}
