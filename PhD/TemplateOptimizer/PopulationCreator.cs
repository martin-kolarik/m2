using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Troschuetz.Random;

namespace TemplateOptimizer
{
    class PopulationCreator
    {
        private MT19937Generator rng;
        private object[] sources;
        private int templateCount;
        private int componentCount;

        public PopulationCreator( int templateCount, int templateComponentCount, Func<int, ComponentDefinition> componentDefinition)
        {
            this.templateCount = templateCount;
            this.componentCount = templateComponentCount;

            rng = new MT19937Generator( (uint)DateTime.Now.Ticks );
            sources = new object[templateComponentCount];
            for( var i = 0; i < templateComponentCount; i++ )
            {
                var definition = componentDefinition( i );
                if( definition.Generator == null )
                {
                    Distribution distribution;
                    switch( definition.Type )
                    {
                        case ComponentType.Deterministic:
                            throw new Exception( "Unexpected component type, Deterministic must specify 'componentValue' member" );
                        case ComponentType.RandomNormal:
                            distribution = new NormalDistribution( rng ) { Mu = definition.Mu, Sigma = definition.Sigma };
                            break;
                        case ComponentType.RandomPearson:
                            distribution = new ChiSquareDistribution( rng ) { Alpha = (int)definition.N };
                            break;
                        case ComponentType.RandomUniform:
                            distribution = new ContinuousUniformDistribution( rng ) { Alpha = definition.A, Beta = definition.B };
                            break;
                        case ComponentType.RandomWeibull:
                            distribution = new WeibullDistribution( rng ) { Alpha = definition.C, Lambda = definition.Lambda };
                            break;
                        default:
                            throw new Exception( "Unknown component type" );
                    }
                    sources[i] = distribution;
                }
                else
                {
                    sources[i] = componentDefinition( i ).Generator;
                }
            }
        }

        public Population Populate()
        {
            var space = new Population();

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
                        template[j] = ( (Func<int, double>)sources[j] )( i );
                    }
                }

                space.AddTemplate( template );
            }

            return space;
        }
    }
}
