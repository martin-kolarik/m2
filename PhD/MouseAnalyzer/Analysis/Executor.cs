using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace MouseAnalyzer
{
    static class Executor
    {
        private static int Count;
        private static List<Action> Tasks = new List<Action>();
        private static Semaphore Consume = new Semaphore( 0, Int32.MaxValue );
        private static ManualResetEvent Exit = new ManualResetEvent( false );
        private static ManualResetEvent Completed = new ManualResetEvent( false );

        static Executor()
        {
            for( var i = 0; i < System.Environment.ProcessorCount; i++ )
            {
                var thread = new Thread( () => Execute() );
                thread.Start();
            }
        }

        public static void Complete()
        {
            Completed.WaitOne();
        }

        public static void Stop()
        {
            Complete();
            Exit.Set();
        }

        public static void Queue( Action task )
        {
            lock( Tasks )
            {
                Completed.Reset();

                ++Count;
                Tasks.Add( task );
            }
            Consume.Release();
        }

        private static void Execute()
        {
            Thread.CurrentThread.CurrentCulture = System.Globalization.CultureInfo.InvariantCulture;
            for( ; ; )
            {
                switch( EventWaitHandle.WaitAny( new WaitHandle[] { Exit, Consume } ) )
                {
                    case 0: // Exit
                        return;
                    case 1: // Consume
                        Action task = null;
                        lock( Tasks )
                        {
                            if( Tasks.Count > 0 )
                            {
                                task = Tasks[0];
                                Tasks.RemoveAt( 0 );
                            }
                        }
                        if( task != null )
                        {
                            task();
                            lock( Tasks )
                            {
                                if( --Count == 0 )
                                {
                                    Completed.Set();
                                }
                            }
                        }
                        break;
                }
            }
        }
    }
}
