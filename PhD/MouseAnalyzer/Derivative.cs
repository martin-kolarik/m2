using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer
{
    class Derivative
    {
        public static enum CoordinateSystem
        {
            World,
            AlongPath
        };

        public static Derivative Null( CoordinateSystem coordinateSystem )
        {
            return new Derivative( coordinateSystem );
        }

        private CoordinateSystem cs = CoordinateSystem.World;
        private double v;
        private double v1;
        private double v2;
        private double a;
        private double a1;
        private double a2;
        private double j;
        private double j1;
        private double j2;

        private Derivative( CoordinateSystem coordinateSystem )
        {
            cs = coordinateSystem;
        }

        public Derivative( Derivative previousDerivative, Event currentEvent )
        {
            var dt = currentEvent.dT;
            if( dt == 0.0 ) // the same time, the same position, presumably, shall be filtered by caller
            {
                throw new ArgumentOutOfRangeException( "currentEvent.dT" );
            }

            if( previousDerivative.cs == CoordinateSystem.World )
            {
                v1 = currentEvent.dX  / dt;
                v2 = currentEvent.dY  / dt;
                a1 = ( v1 - previousDerivative.v1 ) / dt;
                a2 = ( v2 - previousDerivative.v2 ) / dt;
                j1 = ( a1 - previousDerivative.a1 ) / dt;
                j2 = ( a2 - previousDerivative.a2 ) / dt;
            }
            else
            {
                throw new NotImplementedException();
            }

            v = Math.Sqrt( v1 * v1 + v2 * v2 );
            a = Math.Sqrt( a1 * a1 + a2 * a2 );
            j = Math.Sqrt( j1 * j1 + j2 * j2 );
        }

        public double V 
        {
            get { return v; }
        }
        public double A
        {
            get { return a; }
        }
        public double J
        {
            get { return j; }
        }

        public double VX
        {
            get { return v1; }
        }
        public double AX
        {
            get { return a1; }
        }
        public double JX
        {
            get { return j1; }
        }

        public double VY
        {
            get { return v2; }
        }
        public double AY
        {
            get { return a2; }
        }
        public double JY
        {
            get { return j2; }
        }

        public double VR
        {
            get { return v1; }
        }
        public double AR
        {
            get { return a1; }
        }
        public double JR
        {
            get { return j1; }
        }

        public double VT
        {
            get { return v2; }
        }
        public double AT
        {
            get { return a2; }
        }
        public double JT
        {
            get { return j2; }
        }
    }
}
