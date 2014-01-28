using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace TemplateOptimizer
{
    class Weights : Vector
    {
        public Weights( int componentCount ) :
            base( componentCount )
        {
        }

        public Weights( IEnumerable<double> source ) :
            base( source )
        {
        }

        public new double this[ int component ] {
            get { return base[component]; }
            set { base[component] = value > 1.0 ? 1.0 : ( value < -1.0 ? -1.0 : value ); }
        }
    }
}
