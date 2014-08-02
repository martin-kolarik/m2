using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer
{
    class Event
    {
        public enum Button
        {
            Left = 0,
            Middle = 1,
            Right = 2,
            B4 = 3,
            B5 = 4
        }

        public enum ButtonState
        {
            Release,
            Released,
            Press,
            Pressed,
            DoublePress
        };

        public static Event Null()
        {
            return new Event();
        }

        private int x;
        private int y;
        private double time;
        private ButtonState[] state;

        private int dx;
        private int dy;
        private double dt;

        private Event()
        {
        }

        public Event( int dx, int dy, double dt, int x, int y, double time, ButtonState[] state )
        {
            this.dx = dx;
            this.dy = dy;
            this.dt = dt;
            this.x = x;
            this.y = y;
            this.time = time;
            this.state = state;
        }

        public int X
        {
            get { return x; }
        }

        public int Y
        {
            get { return y; }
        }

        public double Time
        {
            get { return time; }
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

        public ButtonState this[ Button button ]
        {
            get
            {
                return state[(uint)button];
            }
        }
    }

    static class EnumExtensions
    {
        public static bool IsPressed( this Event.ButtonState state )
        {
            return state == Event.ButtonState.Press || state == Event.ButtonState.Pressed || state == Event.ButtonState.DoublePress;
        }

        public static bool IsReleased( this Event.ButtonState state )
        {
            return state == Event.ButtonState.Release || state == Event.ButtonState.Released;
        }
    }
}
