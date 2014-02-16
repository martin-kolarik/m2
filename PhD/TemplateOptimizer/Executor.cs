using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace TemplateOptimizer
{
    static class Executor
    {
        private class ExperimentProxy
        {
            private ManualResetEvent Signal = new ManualResetEvent( false );
            int Tasks = 0;

            public void Inc()
            {
                Interlocked.Increment( ref Tasks );
            }

            public void Dec()
            {
                if( Interlocked.Decrement( ref Tasks ) == 0 )
                {
                    Signal.Set();
                }
            }

            public void WaitForCompletion()
            {
                Signal.WaitOne();
            }
        }

        private static Dictionary<Experiment, ExperimentProxy> Proxies = new Dictionary<Experiment, ExperimentProxy>();
        private static List<Tuple<Action, ExperimentProxy>> Tasks = new List<Tuple<Action, ExperimentProxy>>();
        private static Semaphore Consume = new Semaphore( 0, Int32.MaxValue );
        private static ManualResetEvent Exit = new ManualResetEvent( false );

        static Executor()
        {
            for( var i = 0; i < System.Environment.ProcessorCount; i++ )
            {
                var thread = new Thread( () => Execute() );
                thread.Start();
            }
        }

        public static void Stop()
        {
            Exit.Set();
        }

        public static void Queue( Experiment experiment, Action task )
        {
            lock( Tasks )
            {
                ExperimentProxy proxy;
                if( !Proxies.TryGetValue( experiment, out proxy ))
                {
                    proxy = new ExperimentProxy();
                    Proxies.Add( experiment, proxy );
                }
                proxy.Inc();
                Tasks.Add( new Tuple<Action, ExperimentProxy>( task, proxy ));
            }
            Consume.Release();
        }

        public static void WaitForCompletion( Experiment experiment )
        {
            ExperimentProxy proxy;
            lock( Tasks )
            {
                if( !Proxies.TryGetValue( experiment, out proxy ) )
                {
                    return;
                }
            }
            proxy.WaitForCompletion();
            lock( Tasks )
            {
                Proxies.Remove( experiment );
            }
        }

        private static void Execute()
        {
            for( ; ; )
            {
                switch( EventWaitHandle.WaitAny( new WaitHandle[] { Exit, Consume } ) )
                {
                    case 0: // Exit
                        return;
                    case 1: // Consume
                        Tuple<Action, ExperimentProxy> task = null;
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
                            task.Item1();
                            task.Item2.Dec();
                        }
                        break;
                }
            }
        }
    }
}
