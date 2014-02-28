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
        public ComponentDefinition( ComponentType componentType ) :
            base( componentType, DefaultParameter( componentType, 0 ), DefaultParameter( componentType, 1 ) )
        {
        }

        public ComponentDefinition( ComponentType componentType, double parameter1, double parameter2 ) :
            base( componentType, parameter1, parameter2 )
        {
        }

        private static double DefaultParameter( ComponentType componentType, int parameterIndex )
        {
            switch( componentType )
            {
                case ComponentType.RandomNormal :
                    return parameterIndex == 0 ? 0.0 : 1.0;
                case ComponentType.RandomPearson :
                    return parameterIndex == 0 ? 0.0 : 1.0;
                case ComponentType.RandomUniform :
                    return parameterIndex == 0 ? 0.0 : 1.0;
                case ComponentType.RandomWeibull :
                    return parameterIndex == 0 ? 0.0 : 1.0;
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

        // -- c, lambda for Weibull
        public double C { get { return Item2; } }
        public double Lambda { get { return Item3; } }
    }
}
