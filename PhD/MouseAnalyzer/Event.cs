using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer
{
    class Event
    {
        public static enum Attribute
        {
            enLeft = 1,
            enMiddle = 2,
            enRight = 4,
            enDoubleClick = 8
        };

        public static Event Null()
        {
            return new Event();
        }

        private int x;
        private int y;
        private uint attributes;
        private double dTDoubleClick;

        private int dx;
        private int dy;
        private double dt;

        private Event()
        {
        }

        public Event()
        {
        }

        public int X
        {
            get { return x; }
        }

        public int Y
        {
            get { return y; }
        }

        public int dX
        {
            get { return dx; }
        }

        public int dY
        {
            get { return dy; }
        }

        public double dT
        {
            get { return dt; }
        }
    }
}
