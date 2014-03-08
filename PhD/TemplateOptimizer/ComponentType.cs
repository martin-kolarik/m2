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
        private static Tuple<ComponentType, ComponentType>[] pairPermutations = new Tuple<ComponentType, ComponentType>[] {
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

        private static Tuple<ComponentType, ComponentType>[] allPermutations = new Tuple<ComponentType, ComponentType>[] {
            new Tuple<ComponentType, ComponentType>( ComponentType.RandomNormal, ComponentType.RandomNormal ),
            new Tuple<ComponentType, ComponentType>( ComponentType.RandomNormal, ComponentType.RandomPearson ),
            new Tuple<ComponentType, ComponentType>( ComponentType.RandomNormal, ComponentType.RandomUniform ),
            new Tuple<ComponentType, ComponentType>( ComponentType.RandomNormal, ComponentType.RandomWeibull ),

            new Tuple<ComponentType, ComponentType>( ComponentType.RandomPearson, ComponentType.RandomNormal ),
            new Tuple<ComponentType, ComponentType>( ComponentType.RandomPearson, ComponentType.RandomPearson ),
            new Tuple<ComponentType, ComponentType>( ComponentType.RandomPearson, ComponentType.RandomUniform ),
            new Tuple<ComponentType, ComponentType>( ComponentType.RandomPearson, ComponentType.RandomWeibull ),

            new Tuple<ComponentType, ComponentType>( ComponentType.RandomUniform, ComponentType.RandomNormal ),
            new Tuple<ComponentType, ComponentType>( ComponentType.RandomUniform, ComponentType.RandomPearson ),
            new Tuple<ComponentType, ComponentType>( ComponentType.RandomUniform, ComponentType.RandomUniform ),
            new Tuple<ComponentType, ComponentType>( ComponentType.RandomUniform, ComponentType.RandomWeibull ),

            new Tuple<ComponentType, ComponentType>( ComponentType.RandomWeibull, ComponentType.RandomNormal ),
            new Tuple<ComponentType, ComponentType>( ComponentType.RandomWeibull, ComponentType.RandomPearson ),
            new Tuple<ComponentType, ComponentType>( ComponentType.RandomWeibull, ComponentType.RandomUniform ),
            new Tuple<ComponentType, ComponentType>( ComponentType.RandomWeibull, ComponentType.RandomWeibull )
        };

        public static Tuple<ComponentType, ComponentType>[] Permutation( this ComponentType component, bool all = false )
        {
            return all ? allPermutations : pairPermutations;
        }

        public static string ToString( this Tuple<ComponentType, ComponentType> permutation )
        {
            return permutation.Item1.ToString() + "×" + permutation.Item2.ToString();
        }

        public static bool Equals( this Tuple<ComponentType, ComponentType> p1, Tuple<ComponentType, ComponentType> p2 )
        {
            return p1.Item1 == p2.Item1 && p1.Item2 == p2.Item2;
        }
    }
}
