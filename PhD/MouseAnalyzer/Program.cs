using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer
{
    class Program
    {
        static void Main( string[] args )
        {
            System.Threading.Thread.CurrentThread.CurrentCulture = System.Globalization.CultureInfo.InvariantCulture;

            var loader = new Loader( @"d:\mouse.201404202133.log", 100.0 );

            var derivative = new Derivative();
            var derivativeExtractor = new DerivativeExtractor( DerivativeItem.CoordinateSystem.World );
            foreach( var input in loader.RawEvents )
            {
                derivative.AddItem( derivativeExtractor.AddEvent( input, derivative.Items ) );
            }
            derivative.ComputeMarkers();

            var entity = new Entity();
            entity.AddFeature( derivative );
        }
    }
}
