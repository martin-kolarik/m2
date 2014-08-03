using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer
{
    class TimeDevelopment : IAnalysis
    {
        #region IAnalysis Members

        public void Analyze( IEnumerable<Entity> entities )
        {
            foreach( var entity in entities )
            {
                var timing = new Timing( entity );
                var timingExtractor = new TimingExtractor();
                var count = 0;
                foreach( var input in entity.Events )
                {
                    if( timing.AddItems( timingExtractor.AddEvent( input, timing.Items ) ) )
                    {
                        timing.ComputeMarkers( ( ++count ).ToString( "D5" ) );
                    }
                }
                entity.AddFeature( timing );
            }

        }

        public void Dump( CSVDumper dumper, IEnumerable<Entity> entities )
        {
        }

        #endregion
    }
}
