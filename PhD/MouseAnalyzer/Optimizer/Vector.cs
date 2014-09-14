using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace MouseAnalyzer.Optimizer
{
    class Vector
    {
        private double[] components;

        public Vector( int componentCount )
        {
            components = new double[componentCount];
        }

        public Vector( IEnumerable<double> source )
        {
            components = source.ToArray<double>();
        }

        public IEnumerable<double> Components
        {
            get { return components; }
        }

        public double this[ int component ] {
            get { return components[component]; }
            set { components[component] = value; }
        }

        public int ComponentCount
        {
            get { return this.components.Length; }
        }

        public double Length
        {
            get
            {
                var d = 0.0;
                foreach( var component in components )
                {
                    d += component * component;
                }
                return Math.Sqrt( d );
            }
        }

        public override string ToString()
        {
            return ToString( "[", ", ", "]" );
        }

        public string ToString( string leading, string separator, string trailing )
        {
            return leading + String.Join( separator, components ) + trailing;
        }
    }
}
