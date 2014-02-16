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

        public Vector( IEnumerable<double> source, bool normalize = false ) :
            this( source )
        {
            if( normalize )
            {
                PerformNormalization();
            }
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

        public Vector Normalize()
        {
            return new Vector( components, true );
        }

        protected void PerformNormalization()
        {
            var length = Length;
            for( var i = 0; i < ComponentCount; i++ )
            {
                components[i] /= length;
            }
        }

        public override string ToString()
        {
            return ToString( "[", ", ", "]" );
        }

        public string ToString( string leading, string separator, string trailing )
        {
            var any = false;
            var s = new StringBuilder( leading );
            foreach( var component in components )
            {
                if( any )
                {
                    s.Append( separator );
                }
                else
                {
                    any = true;
                }
                s.Append( component.ToString() );
            }
            s.Append( trailing );
            return s.ToString();
        }
    }
}
