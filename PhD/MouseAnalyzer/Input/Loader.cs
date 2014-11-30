using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer
{
    class Loader
    {
        private const int BUTTONS = 5;
        private double doubleClickDelay;
        private string filePath;

        public Loader( string filePath, double doubleClickDelay )
        {
            this.doubleClickDelay = doubleClickDelay;
            this.filePath = filePath;
        }

        public IList<Event> GetEvents( DataSource.SourceType sourceType )
        {
            string recordFilter;
            switch ( sourceType )
            {
                case DataSource.SourceType.DRV:
                    recordFilter = "trk/R:";
                    break;
                case DataSource.SourceType.API:
                    recordFilter = "trk/H:";
                    break;
                default:
                    return null;
            }
            return CreateEvents( sourceType, recordFilter );
        }

        public List<Event> CreateEvents( DataSource.SourceType source, string expectedItem )
        {
            var list = new List<Event>();
            var T = 0.0;
            var X = 0;
            var Y = 0;

            var buttonState = new Event.ButtonState[BUTTONS];
            var lastDownDistance = new double[BUTTONS];
            var previousDownDistance = new double[BUTTONS];
            var doubleClickState = new int[BUTTONS]; // 0 = nothing, 1 = first press, 2 = first release, 3 = second press, 4 = second release
            for( int i = 0; i < buttonState.Length; i++ )
            {
                buttonState[i] = Event.ButtonState.Released;
            }

            Event previousEvent = null;
            var reader = new StreamReader( filePath );
            while( !reader.EndOfStream )
            {
                var items = reader.ReadLine().Split( new char[] { ' ' } );

                // filter out uef data and unknown data
                if( items[0] != expectedItem )
                {
                    continue;
                }

                // get time between events
                var dT = double.Parse( items[1] );

                // detect flags
                var anyRecordable = false;
                var chararray = items[2].ToCharArray();
                for( int i = 0; i < buttonState.Length; i++ )
                {
                    lastDownDistance[i] += dT;
                    if( lastDownDistance[i] > doubleClickDelay )
                    {
                        doubleClickState[i] = 0;
                    }

                    if( chararray[i] == 'U' )
                    {
                        anyRecordable = true;
                        buttonState[i] = Event.ButtonState.Release;
                        if( doubleClickState[i] == 3 )
                        {
                            doubleClickState[i] = 4;
                        }
                        else if( doubleClickState[i] == 1 )
                        {
                            doubleClickState[i] = 2;
                        }
                    }
                    else if( chararray[i] == 'D' )
                    {
                        anyRecordable = true;
                        buttonState[i] = Event.ButtonState.Press;
                        if( doubleClickState[i] == 2 )
                        {
                            doubleClickState[i] = 3;
                            previousDownDistance[i] = 0.0;
                        }
                        else if( doubleClickState[i] == 0 )
                        {
                            doubleClickState[i] = 1;
                            lastDownDistance[i] = 0.0;
                        }
                    }
                    else if( buttonState[i] == Event.ButtonState.Release )
                    {
                        buttonState[i] = Event.ButtonState.Released;
                    }
                    else if( buttonState[i] == Event.ButtonState.Press )
                    {
                        buttonState[i] = Event.ButtonState.Pressed;
                    }

                    if( doubleClickState[i] == 4 ) // double click
                    {
                        buttonState[i] = Event.ButtonState.DoublePress;
                        doubleClickState[i] = 2; // await next double click
                        lastDownDistance[i] = previousDownDistance[i];
                    }
                }

                // x coordinate
                var diffabs = items[3].Split( '>' );
                var dX = int.Parse( diffabs[0] );
                X += dX;

                // y coordinate
                diffabs = items[4].Split( '>' );
                var dY = int.Parse( diffabs[0] );
                Y += dY;

                if( anyRecordable || ( dT > 0.5 && ( dX != 0 || dY != 0 ) ) ) // ignore events having the same time and no change in position, but do not do it before button states are updated
                {
                    var dt = previousEvent == null ? 0 : T - previousEvent.Time;
                    var dx = previousEvent == null ? 0 : X - previousEvent.X;
                    var dy = previousEvent == null ? 0 : Y - previousEvent.Y;
                    var currentEvent = new Event( source, dx, dy, dt, X, Y, T, buttonState.ToArray(), previousEvent );
                    list.Add( currentEvent );
                    previousEvent = currentEvent;
                }

                // move time on
                T += dT;
            }
            reader.Close();
            reader.Dispose();

            return list;
        }
    }
}
