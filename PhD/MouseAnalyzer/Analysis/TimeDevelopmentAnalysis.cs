using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using MouseAnalyzer.Lookup;
using MouseAnalyzer.Optimizer;

namespace MouseAnalyzer
{
    class TimeDevelopmentAnalysis : AnalysisBase, IAnalysis
    {
        #region IAnalysis Members

        public void Analyze( IEnumerable<Entity> entities, SplitDefinition split = null )
        {
            foreach( var entity in entities )
            {
                var timing = new TimingFeature( entity );
                var timingExtractor = new TimingFeatureExtractor();
                var count = 0;
                foreach( var input in SplitDefinition.Split( split, entity.Events ) )
                {
                    if( timing.AddItems( timingExtractor.AddEvent( input, timing.Items ) ) )
                    {
                        timing.ComputeMarkers( ( ++count ).ToString( "D5" ) );
                    }
                }
                entity.AddFeature( timing );
            }

        }

        public void PushDumpedContent( CSVDumper dumper, IEnumerable<Entity> entities, string extendedSpecification = null )
        {
            dumper.AddContent( "tg" + extendedSpecification, d =>
            {
                var headers = new List<string>();
                var columns = new List<IEnumerable<object>>();
                var column = 1;

                foreach( var entity in entities )
                {
                    var estimates = entity.Markers.Where( m =>
                        m is IValueMarker &&
                        ( m.Estimate is InverseGaussianDatasetEstimate || m.Estimate is LognormalDatasetEstimate ) &&
                        ( m.MarkerTypeName.EndsWith( "Mean" ) || m.MarkerTypeName.Contains( "Lambda" ) || m.MarkerTypeName.EndsWith( "Mu" ) || m.MarkerTypeName.EndsWith( "Sigma" ) ) );

                    var markerNames = estimates.Select( e => e.Name ).Distinct();
                    foreach( var markerName in markerNames )
                    {
                        headers.Add( ( column++ ).ToString( "D2" ) + entity.Id + entity.Source.ToString() + " " + markerName );
                        columns.Add( estimates.Where( e => e.Name == markerName ).Select( f => (object)( (IValueMarker)f ).Value ) );
                    }
                }

                d.Columns( headers, columns );
            } );
        }

        #endregion
    }
}
