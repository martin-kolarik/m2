using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace TemplateOptimizer
{
    public enum ComponentType
    {
        RandomNormal,
        RandomPearson,
        RandomUniform,
        RandomWeibull
    }

    static class ComponentTypeExtension
    {
        public static Tuple<ComponentType, ComponentType>[] Permutation( this ComponentType component )
        {
                return new Tuple<ComponentType, ComponentType>[] {
                    new Tuple<ComponentType, ComponentType>( ComponentType.RandomNormal, ComponentType.RandomNormal ),
                    new Tuple<ComponentType, ComponentType>( ComponentType.RandomNormal, ComponentType.RandomPearson ),
                    new Tuple<ComponentType, ComponentType>( ComponentType.RandomNormal, ComponentType.RandomUniform ),
                    new Tuple<ComponentType, ComponentType>( ComponentType.RandomNormal, ComponentType.RandomWeibull ),

                    new Tuple<ComponentType, ComponentType>( ComponentType.RandomPearson, ComponentType.RandomPearson ),
                    new Tuple<ComponentType, ComponentType>( ComponentType.RandomPearson, ComponentType.RandomUniform ),
                    new Tuple<ComponentType, ComponentType>( ComponentType.RandomPearson, ComponentType.RandomWeibull ),

                    new Tuple<ComponentType, ComponentType>( ComponentType.RandomUniform, ComponentType.RandomUniform ),
                    new Tuple<ComponentType, ComponentType>( ComponentType.RandomUniform, ComponentType.RandomWeibull ),

                    new Tuple<ComponentType, ComponentType>( ComponentType.RandomWeibull, ComponentType.RandomWeibull )
                };
        }

        public static string ToString( this Tuple<ComponentType, ComponentType> permutation )
        {
            return permutation.Item1.ToString() + "×" + permutation.Item2.ToString();
        }
    }
}
