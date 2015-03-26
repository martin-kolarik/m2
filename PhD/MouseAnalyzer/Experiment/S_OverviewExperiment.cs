using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using MouseAnalyzer.Statistics;

namespace MouseAnalyzer.Experiment
{
    class S_OverviewExperiment : IExperiment
    {

        #region IExperiment Members

        public void Perform( string outputFileNameHint = "" )
        {
            var CFG_ENV = DataSource.EnvironmentType.ControlledAccelerated;
            var CFG_SOURCE = DataSource.SourceType.API;
            var CFG_STROKE_KIND = StrokeFeatureItem.ItemType.MoveEnded;
            var CFG_END_STROKE_GAP = 64;
            var CFG_FRACTIONS = 1;
            var CFG_FRACTION = SplitDefinition.RANDOM;

            var DESCRIPTION_STRING =
                "env: " + CFG_ENV.ToString() + 
                ", source: " + CFG_SOURCE.ToString() + 
                ", endgap: " + CFG_END_STROKE_GAP.ToString(); // ", without L/M/H",

            var entities = DataSources.Get( CFG_ENV, CFG_SOURCE );

            var dumper = new CSVDumper();
            dumper.AddContent( "OVERVIEW " + DESCRIPTION_STRING, (d) => {} );

            var split = new SplitDefinition()
            {
                Fractions = CFG_FRACTIONS,
                Fraction = CFG_FRACTION
            };
            var analyzer = new Analysis.StrokePopulationAnalysis( CFG_STROKE_KIND, CFG_END_STROKE_GAP );
            analyzer.Analyze( entities, split, true );
            analyzer.Optimize( entities );
            analyzer.PushDumpedContent( dumper, entities );

            dumper.AddContent( "STROKE TIME LENGTH HISTOGRAM " + DESCRIPTION_STRING, (d) => {
                var headers = new List<string>();
                var columns = new List<IEnumerable<object>>();
                var overallT = new List<double>();
                var overallN = new List<double>();

                foreach( var entity in entities )
                {
                    var typedItems = entity.Features.First().Items.Select( i => (StrokeFeatureItem)i );
                    var data = typedItems.Where( i => i.IsValid && !i.IsStraight && i.Type == StrokeFeatureItem.ItemType.MoveEnded ).Select( i => i.Value( "Ti" ) );
                    overallT.AddRange( data );

                    var histogram = ComputeHistogram( data );

                    headers.Add( "T " + entity.Id + " mids" );
                    headers.Add( "T " + entity.Id + " freqs" );

                    columns.Add( histogram.BinMidpoints.Select( m => m.ToString( "G5" ) ) );
                    columns.Add( histogram.Frequencies.Select( m => m.ToString( "G5" ) ) );
                }

                foreach( var entity in entities )
                {
                    var typedItems = entity.Features.First().Items.Select( i => (StrokeFeatureItem)i );
                    var data = typedItems.Where( i => i.IsValid && !i.IsStraight && i.Type == StrokeFeatureItem.ItemType.MoveEnded ).Select( i => Math.Log( (double)i.Input.Count ) );
                    overallN.AddRange( data );

                    var histogram = ComputeHistogram( data );

                    headers.Add( "N " + entity.Id + " mids" );
                    headers.Add( "N " + entity.Id + " freqs" );

                    columns.Add( histogram.BinMidpoints.Select( m => m.ToString( "G5" ) ) );
                    columns.Add( histogram.Frequencies.Select( m => m.ToString( "G5" ) ) );
                }

                var overallTHistogram = ComputeHistogram( overallT );

                headers.Add( "T all mids" );
                headers.Add( "T all freqs" );

                columns.Add( overallTHistogram.BinMidpoints.Select( m => m.ToString( "G5" ) ) );
                columns.Add( overallTHistogram.Frequencies.Select( m => m.ToString( "G5" ) ) );

                var overallNHistogram = ComputeHistogram( overallN );

                headers.Add( "N all mids" );
                headers.Add( "N all freqs" );

                columns.Add( overallNHistogram.BinMidpoints.Select( m => m.ToString( "G5" ) ) );
                columns.Add( overallNHistogram.Frequencies.Select( m => m.ToString( "G5" ) ) );

                d.Columns( headers, columns );
            } );

            dumper.Dump( outputFileNameHint == "" ? "s-o" : outputFileNameHint );
        }

        private HistogramMarker ComputeHistogram( IEnumerable<double> data )
        {
            var hitems = 100;
            var min = data.Min();
            var max = data.Max();
            var spread = max - min;
            var bw = spread / hitems;
            spread = max - min + bw;
            bw = spread / hitems;

            var histogramDefinition = new HistogramDefinition( hitems );
            histogramDefinition.SupplyRange( min - bw / 2, max + bw / 2 );
            return new HistogramMarker( null, null, null, null, null, histogramDefinition, data );
        }

        #endregion
    }
}
