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
        private class ExperimentProxy : IDisposable
        {
            private Action completionHandler = null;
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
                    Action handler = null;
                    lock( this )
                    {
                        if( completionHandler != null )
                        {
                            handler = completionHandler;
                            completionHandler = null;
                        }
                    }
                    Signal.Set();
                    if( handler != null )
                    {
                        handler();
                    }
                }
            }

            public void Complete( bool wait = true, Action completionHandler = null )
            {
                if( wait )
                {
                    Signal.WaitOne();
                }
                else
                {
                    lock( this )
                    {
                        if( !Signal.WaitOne( 0 ))
                        {
                            this.completionHandler = completionHandler; // If Signal is not set, something is still pending and I am able to schedule completion routine.
                            completionHandler = null; // Localy the routine must not run.
                        }
                    }
                }
                if( completionHandler != null )
                {
                    completionHandler();
                }
            }

            public void Dispose()
            {
                Signal.Dispose();
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

        public static void Complete()
        {
            // wait until everything finishes
            for( ; ; )
            {
                ExperimentProxy proxy;
                Experiment experiment;
                lock( Tasks )
                {
                    if( Proxies.Count == 0 )
                    {
                        break;
                    }
                    experiment = Proxies.Keys.First();
                    proxy = Proxies[experiment];
                }
                proxy.Complete( true, () =>
                {
                    lock( Tasks )
                    {
                        Proxies.Remove( experiment );
                        proxy.Dispose();
                    }
                } );
            }
        }

        public static void Stop()
        {
            Complete();
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

        public static void ScheduleCompletion( Experiment experiment, Action completionHandler )
        {
            ExperimentProxy proxy;
            lock( Tasks )
            {
                if( !Proxies.TryGetValue( experiment, out proxy ) )
                {
                    return;
                }
            }
            proxy.Complete( false, () =>
            {
                if( completionHandler != null )
                {
                    completionHandler();
                }
                lock( Tasks )
                {
                    Proxies.Remove( experiment );
                    proxy.Dispose();
                }
            } );
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
