using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace TemplateOptimizer
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

        public double this[ int component ] {
            get { return components[component]; }
            set { components[component] = value; }
        }

        public int ComponentCount
        {
            get { return this.components.Length; }
        }
    }
}
