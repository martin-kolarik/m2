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

        private ButtonState[] state;

        private Event()
        {
        }

        public Event( DataSource.SourceType source, int dx, int dy, double dt, int x, int y, double time, ButtonState[] state )
        {
            Source = source;
            X = x;
            Y = y;
            Time = time;
            dX = dx;
            dY = dy;
            dT = dt;
            this.state = state;
        }

        public DataSource.SourceType Source { get; private set; }
        public int X { get; private set; }
        public int Y { get; private set; }
        public double Time { get; private set; }

        public int dX { get; private set; }
        public int dY { get; private set; }
        public double dT { get; private set; }

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
