using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace TemplateOptimizer
{
    class ComponentDefinition :
        Tuple<ComponentType, double, double>
    {
        public ComponentDefinition( ComponentType componentType, double? parameter1 = null, double? parameter2 = null ) :
            base( componentType,
                  parameter1.HasValue ? parameter1.Value : DefaultParameter( componentType, 0 ),
                  parameter2.HasValue ? parameter2.Value : DefaultParameter( componentType, 1 ) )
        {
        }

        private static double DefaultParameter( ComponentType componentType, int parameterIndex )
        {
            switch( componentType )
            {
                case ComponentType.RandomNormal :
                    return parameterIndex == 0 ? 0.0 : 1.0; // standardized is Mu = 0, Sigma = 1
                case ComponentType.RandomPearson :
                    return parameterIndex == 0 ? 1.0 : 0.0; // standardized is N = 1, others have no sense
                case ComponentType.RandomUniform :
                    return parameterIndex == 0 ? 0.0 : 1.0;
                case ComponentType.RandomWeibull :
                    return parameterIndex == 0 ? 1.0 : 1.0; // exponential is C = 1, standard exponential is Lambda = 1
                default:
                    return 0.0;
            }
        }

        public ComponentType Type
        {
            get { return Item1; }
        }

        // -- mi, sigma for RandomNormal
        public double Mu { get { return Item2; } }
        public double Sigma { get { return Item3; } }

        // -- n for Pearson
        public double N { get { return Item2; } }

        // -- a, b for Uniform
        public double A { get { return Item2; } }
        public double B { get { return Item3; } }

        // -- lambda, c for Weibull
        public double Lambda { get { return Item2; } }
        public double C { get { return Item3; } }
    }
}
