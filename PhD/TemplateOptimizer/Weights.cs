using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace TemplateOptimizer
{
    class Weights : Vector
    {
        public enum NormalizationMode
        {
            Normalize, // sum of squares = 1
            Weigh // sum of components = 1
        }

        public static Weights Uniform( int componentCount )
        {
            Weights weights = new Weights( componentCount );
            for( var i = 0; i < weights.ComponentCount; i++ )
            {
                weights[i] = 1.0;
            }
            return new Weights( weights.Components, NormalizationMode.Weigh );
        }

        public Weights( int componentCount ) :
            base( componentCount )
        {
        }

        public Weights( IEnumerable<double> source ) :
            base( source )
        {
        }

        public Weights( IEnumerable<double> source, NormalizationMode mode ) :
            base( source )
        {
            switch( mode )
            {
                case NormalizationMode.Normalize:
                    PerformNormalization();
                    break;
                case NormalizationMode.Weigh:
                    PerformWeighing();
                    break;
            }
        }

        public new double this[ int component ] {
            get { return base[component]; }
            set { base[component] = value > 1.0 ? 1.0 : ( value < -1.0 ? -1.0 : value ); }
        }

        public new Weights Normalize()
        {
            return new Weights( Components, NormalizationMode.Normalize );
        }

        public Weights Weigh()
        {
            return new Weights( Components, NormalizationMode.Weigh );
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
