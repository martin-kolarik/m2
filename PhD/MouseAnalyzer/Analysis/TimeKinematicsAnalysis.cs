using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using MouseAnalyzer.Lookup;
using MouseAnalyzer.Optimizer;

namespace MouseAnalyzer.Analysis
{
    class TimeKinematicsAnalysis : AnalysisBase, IAnalysis
    {
        #region IAnalysis Members

        public void Analyze( IEnumerable<Entity> entities, SplitDefinition split = null, bool leaveFeatureItems = false )
        {
            foreach( var entity in entities )
            {
                Executor.Queue( () =>
                {
                    var events = SplitDefinition.Split( split, entity.Events );

                    // timing
                    var timing = new TimingFeature( entity, false );
                    var timingExtractor = new TimingFeatureExtractor();
                    foreach( var input in events )
                    {
                        timing.AddItems( timingExtractor.AddEvent( input, timing.TypedItems ) );
                    }
                    timing.ComputeMarkers( "0", !leaveFeatureItems );
                    entity.AddFeature( timing );
                    var c1 = entity.Markers.Where( m => m is IValueMarker ).Count();

                    // kinematics
                    var kinematics = new KinematicsFeature( entity );
                    var kinematicsExtractor = new KinematicsFeatureExtractor();
                    foreach( var input in events )
                    {
                        kinematics.AddItems( kinematicsExtractor.AddEvent( input, kinematics.TypedItems ) );
                    }
                    kinematics.ComputeMarkers( "0", !leaveFeatureItems );
                    entity.AddFeature( kinematics );
                    var c2 = entity.Markers.Where( m => m is IValueMarker ).Count();

                    var markers = entity.Markers.Where( m => m is IValueMarker ).ToList();
                    if( markers.Count() == 29 )
                    {
                        markers = null;
                    }
                } );
            }

            Executor.Complete();
        }

        public IPopulationOptimizer PopulationOptimizer { get; private set; }

        public void Optimize( IEnumerable<Entity> entities, int repeatCount = 1, IEnumerable<ProbeEntity> probes = null )
        {
            Features.Markers markers;
            Population population;
            PrepareValueMarkers( entities, Population.NormalizationType.Desquare, out markers, out population );
            // PopulationOptimizer = new AveragePopulationOptimizer( new Distance(), population );
            PopulationOptimizer = new IterateOverBestPopulationOptimizer( markers, new Distance(), population );
            PopulationOptimizer.Optimize( repeatCount, probes );
        }

        public void PushDumpedContent( CSVDumper dumper, IEnumerable<Entity> entities, string extendedSpecification = null )
        {
            dumper.AddContent( "tk" + extendedSpecification, d =>
            {
                // estimates
                var printHeader = true;
                Entity firstEntity = null;
                foreach( var entity in entities )
                {
                    firstEntity = firstEntity==null ? entity : firstEntity;
                    var estimates = entity.Markers.Where( m => m is IValueMarker );
                    if( printHeader )
                    {
                        d.CellsE( "", false, estimates.Select( e => e.Feature.Source.ToString() + " " + e.Name ) );
                        printHeader = false;
                    }
                    d.CellsE( entity.Id + entity.Source.ToString(), false, estimates.Select( e => ((IValueMarker)e).Value.ToString( "G4" ) ) );
                }
                foreach( var template in PopulationOptimizer.Population.Templates )
                {
                    d.CellsE( template.Entity.Id + template.Entity.Source.ToString(), false, template.Components.Select( c => c.ToString( "G4" ) ) );
                }

                d.CellsE( "WEIGHTS", false, firstEntity.Markers.Where( m1 => m1 is IValueMarker ).Select( m2 => m2.Name ) );
                foreach( var weights in PopulationOptimizer.WeightsAttempts )
                {
                    d.CellsE( "WEIGHTS", false, weights.Components.Select( w => w.ToString( "G4" ) ) );
                }
                d.Cell( "-----", "-----" );
                d.CellsE( "WEIG USE", false, PopulationOptimizer.Markers.Weights.Components.Select( w => w.ToString( "G4" ) ) );
                d.CellsE( "MASK ORD", false, PopulationOptimizer.ComponentsOrder.Components.Select( w => w.ToString( "G4" ) ) );
                d.CellsE( "MASK PCT", false, PopulationOptimizer.Percentile.Components.Select( w => w.ToString( "G4" ) ) );
                d.CellsE( "MASK VAL", false, PopulationOptimizer.Markers.Actives.Components.Select( w => w.ToString( "G4" ) ) );

                // histograms
                if( false )
                {
                    var column = 1;
                    var headers = new List<string>();
                    var columns = new List<IEnumerable<object>>();
                    var markers = entities.SelectMany( e => e.Markers );
                    var histograms = markers.Where( m => m is IHistogramMarker );
                    foreach( IHistogramMarker histogram in histograms )
                    {
                        var header = histogram.Feature.Entity.Id + histogram.Feature.Source.ToString() + " " + histogram.Name;
                        headers.Add( ( column++ ).ToString( "D2" ) + header );
                        headers.Add( ( column++ ).ToString( "D2" ) + header );
                        columns.Add( ( histogram ).BinMidpoints.Select( hi => (object)hi ) );
                        columns.Add( ( histogram ).Frequencies.Select( hi => (object)hi ) );
                    }

                    d.Columns( headers, columns );
                }
             } );
        }

        #endregion
    }
}
