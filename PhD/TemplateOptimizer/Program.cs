using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace TemplateOptimizer
{
    class Program
    {
        static void Main( string[] args )
        {
            Weights weights = new Weights( 100 );
            for( var i = 0; i < weights.ComponentCount; i++ )
            {
                weights[i] = 1.0;
            }

            Space space = new Space();
            space.AddTemplate( new Template( new double[] { 0, 0 } ) );
            space.AddTemplate( new Template( new double[] { 3, 0 } ) );
            space.AddTemplate( new Template( new double[] { 3, 4 } ) );

            var dS = space.Distance( Space.DistanceType.Summation, weights );
            var dA = space.Distance( Space.DistanceType.Average, weights );
            var dG = space.Distance( Space.DistanceType.GeometricAverage, weights );

            SimulationFiller filler = new SimulationFiller( 100, 100,
                (component) =>
                {
                    switch( component )
                    {
                        default:
                            return SimulationFiller.ComponentType.RandomNormal;
                    }
                },
                (component) =>
                {
                    switch( component )
                    {
                        default:
                            return new Tuple<double, double>( 0, 0.1 );
                    }
                }
            );
            space = filler.Populate();

            dS = space.Distance( Space.DistanceType.Summation, weights );
            dA = space.Distance( Space.DistanceType.Average, weights );
            dG = space.Distance( Space.DistanceType.GeometricAverage, weights );
        }
    }
}
