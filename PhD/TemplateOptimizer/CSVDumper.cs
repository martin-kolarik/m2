using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace TemplateOptimizer
{
    class CSVDumper
    {
        public class CSVParticularResultDumper
        {
            private CSVDumper dumper;

            public CSVParticularResultDumper( CSVDumper dumper )
            {
                this.dumper = dumper;
            }

            public void DumpParameters( ExperimentResult result )
            {
                dumper.DumpParameters( result );
            }

            public void Cell( object cell )
            {
                dumper.Cell( cell );
            }

            public void Cell( string label, object cell )
            {
                dumper.Cell( label, cell );
            }

            public void CellsE( string label, IEnumerable<object> cells )
            {
                dumper.CellsE( label, cells );
            }

            public void CellsVA( params object[] cells )
            {
                dumper.CellsVA( cells );
            }
        }

        private ExperimentResult result;
        private object fileLock = new Object();
        private int counter = 1;
        private StreamWriter writer;

        public string CellSeparator
        {
            get;
            set;
        }

        public string Directory
        {
            get;
            set;
        }

        public CSVDumper() :
            this( null )
        {
        }

        public CSVDumper( ExperimentResult result )
        {
            this.result = result;
            CellSeparator = @";";
            Directory = @".\res";
        }

        public void Dump( string fileMark, string title, string focusOn, ExperimentType type, bool dumpParameters = true, bool dumpCommon = true, Action<CSVParticularResultDumper> particularResultDumper = null )
        {
            CreateFile( fileMark, type );

            Cell( "TITLE", title );
            Cell( "FOCUS ON", focusOn );
            Cell( "EXPERIMENT TYPE", type );

            if( dumpParameters )
            {
                Cell( "PARAMETERS" );
                DumpParameters( result );
            }

            if( dumpCommon || particularResultDumper != null )
            {
                Cell( "RESULTS" );
            }
            if( dumpCommon )
            {
                Cell( "COMMON" );
                DumpCommon();
            }
            if( particularResultDumper != null )
            {
                Cell( "PARTICULAR" );
                particularResultDumper( new CSVParticularResultDumper( this ) );
            }

            CloseFile();
        }

        private void Cell( object cell )
        {
            CellsVA( cell );
        }

        private void Cell( string label, object cell )
        {
            CellsVA( label, cell );
        }

        private void CellsE( string label, IEnumerable<object> cells )
        {
            bool inline = false;
            StringBuilder builder = new StringBuilder();

            if( label != null )
            {
                inline = true;
                builder.Append( label );
            }

            foreach( var cell in cells )
            {
                if( inline )
                {
                    builder.Append( CellSeparator );
                }
                inline = true;
                builder.Append( cell );
            }
            writer.WriteLine( builder.ToString() );
        }

        private void CellsVA( params object[] cells )
        {
            CellsE( null, cells );
        }

        private void CreateFile( string fileMark, ExperimentType type )
        {
            string name = DateTime.Now.ToString( "EXP[" + fileMark + "]yyyyMMdd" ) + ( (int)type ).ToString( "D2" );
            string path;

            lock( fileLock )
            {
                for( ; ; )
                {
                    System.IO.Directory.CreateDirectory( Directory );

                    path = Path.Combine( Directory, name + counter.ToString( "D3" ) );
                    path = Path.ChangeExtension( path, "csv" );
                    if( !File.Exists( path ) )
                    {
                        break;
                    }
                    counter++;
                }

                writer = new StreamWriter( path );
            }
        }

        private void CloseFile()
        {
            writer.Flush();
            writer.Close();
            writer = null;
        }

        private void DumpParameters( ExperimentResult result )
        {
            var p = result.Parameters;

            Cell( "normalization", p.Normalization );
            Cell( "pcaRecompositionThreshold", p.PCARecompositionThreshold );

            int index = 1;
            CellsE( "component", p.Components.Select( ( definition ) => (object)index++ ) );
            CellsE( "type", p.Components.Select( ( definition ) => definition.Type.ToString() ) );
            CellsE( "p1", p.Components.Select( ( definition ) => definition.Item2.ToString() ) );
            CellsE( "p2", p.Components.Select( ( definition ) => definition.Item3.ToString() ) );
        }

        private void DumpCommon()
        {
            var r = result;
            var p = r.Parameters;

            Cell( "distance" );
            CellsE( "which", p.DistanceTypes.Select( ( distance ) => distance ) );
            CellsE( "plain", p.DistanceTypes.Select( ( distance ) => (object)r.PlainDistances[distance] ) );
            CellsE( "PCA", p.DistanceTypes.Select( ( distance ) => (object)r.PCADistances[distance] ) );
            for( var run = 0; run < p.DERuns; run++ )
            {
                CellsE( "DE" + run.ToString( "D2" ), p.DistanceTypes.Join( r.DEResults.Where( ( item ) => item.Run == run ), ( distance ) => distance, ( item ) => item.Distance, ( distance, item ) => (object)item.DEDistance ) );
            }

            Cell( "differential evolutions parameters" );
            CellsVA( "type", "parentWeight", "crossover", "population", "iterations", "distance" );
            foreach( var de in r.DEResults )
            {
                CellsVA( de.Type, de.Weight, de.Crossover, de.PopulationCount, de.IterationCount, de.Distance );
            }
            CellsVA( "differential evolutions component weights" );
            int index = 1;
            foreach( var de in r.DEResults )
            {
                CellsE( index.ToString(), de.DEWeights.Components.Cast<object>() );
                index++;
            }

            /*
             * public PrincipalComponentCollection PCAComponents { get; set; }
        public Weights PCAWeights { get; set; }

        public Population Population { get; private set; }
        public Population NormalizedPopulation { get; private set; }
             * */

        }
    }
}
