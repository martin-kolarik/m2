using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Troschuetz.Random;

namespace TemplateOptimizer
{
    class SimulationFiller
    {
        public enum ComponentType
        {
            Deterministic,
            RandomNormal,
            RandomPearson,
            RandomUniform,
            RandomWeibull
        }

        private MT19937Generator rng;
        private object[] sources;
        private int templateCount;
        private int componentCount;

        // Tuple<double, double> contains:
        // -- mi, sigma for RandomNormal
        // -- c, lambda for Weibull
        // -- a, b for Uniform
        // -- n for Pearson
        // -- y for Deterministic
        public SimulationFiller( int templateCount, int templateComponentCount, Func<int, ComponentType> componentType, Func<int, Tuple<double, double>> componentParameter, Func<int /* template */, int /* component */, double> componentValue = null)
        {
            this.templateCount = templateCount;
            this.componentCount = templateComponentCount;

            rng = new MT19937Generator( (uint)DateTime.Now.Ticks );
            sources = new object[templateComponentCount];
            for( var i = 0; i < templateComponentCount; i++ )
            {
                if( componentValue == null )
                {
                    var parameters = componentParameter( i );
                    Distribution distribution;
                    switch( componentType( i ) )
                    {
                        case ComponentType.Deterministic:
                            throw new Exception( "Unexpected component type, Deterministic must specify 'componentValue' member" );
                        case ComponentType.RandomNormal:
                            distribution = new NormalDistribution( rng ) { Mu = parameters.Item1, Sigma = parameters.Item2 };
                            break;
                        case ComponentType.RandomPearson:
                            distribution = new ChiSquareDistribution( rng ) { Alpha = (int)parameters.Item1 };
                            break;
                        case ComponentType.RandomUniform:
                            distribution = new ContinuousUniformDistribution( rng ) { Alpha = parameters.Item1, Beta = parameters.Item2 };
                            break;
                        case ComponentType.RandomWeibull:
                            distribution = new WeibullDistribution( rng ) { Alpha = parameters.Item1, Lambda = parameters.Item2 };
                            break;
                        default:
                            throw new Exception( "Unknown component type" );
                    }
                    sources[i] = distribution;
                }
                else
                {
                    sources[i] = componentValue;
                }
            }
        }

        public Space Populate()
        {
            var space = new Space();

            for( var i = 0; i < templateCount; i++ )
            {
                var template = new Template( componentCount );

                for ( var j = 0; j < componentCount; j++ )
                {
                    if( sources[j] is Distribution )
                    {
                        template[j] = ( (Distribution)sources[j] ).NextDouble();
                    }
                    else
                    {
                        template[j] = ( (Func<int, int, double>)sources[j] )( i, j );
                    }
                }

                space.AddTemplate( template );
            }

            return space;
        }
    }
}
