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
            CellSeparator = ";";
            Directory = ".";
        }

        public void Dump( string title, string focusOn, ExperimentType type, bool dumpParameters = true, bool dumpCommon = true, Action<CSVParticularResultDumper> particularResultDumper = null )
        {
            CreateFile( type );

            Cell( "TITLE", title );
            Cell( "FOCUS ON", focusOn );
            Cell( "EXPERIMENT TYPE", type );

            if( dumpParameters )
            {
                Cell( "PARAMETERS" );
                DumpParameters();
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

        private void CreateFile( ExperimentType type )
        {
            string name = DateTime.Now.ToString( "EXPyyyyMMdd" ) + ( (int)type ).ToString( "D2" );
            string path;

            lock( fileLock )
            {
                for( ; ; )
                {
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

        private void DumpParameters()
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
            CellsE( "which", p.DistanceTypes.Select( ( distance ) => distance.Type.ToString() + "(" + distance.Processing.ToString() + ")" ) );
            CellsE( "plain", p.DistanceTypes.Select( ( distance ) => (object)r.PlainDistances[distance] ) );
            CellsE( "PCA", p.DistanceTypes.Select( ( distance ) => (object)r.PCADistances[distance] ) );
            for( var run = 0; run < p.DERuns; run++ )
            {
                CellsE( "DE" + run.ToString( "D2" ), p.DistanceTypes.Join( r.DEResults.Where( ( item ) => item.Run == run ), ( distance ) => distance, ( item ) => item.Distance, ( distance, item ) => (object)item.DEDistance ) );
            }

            /*
        public PrincipalComponentCollection PCAComponents { get; set; }
        public Weights PCAWeights { get; set; }

            public int Type { get; private set; }
            public double Weight { get; private set; }
            public double Crossover { get; private set; }
            public int PopulationCount { get; private set; }
            public int IterationCount { get; private set; }
            public Distance Distance { get; private set; }
            public int Run { get; private set; }

            public double DEDistance { get; private set; }
            public Weights DEWeights { get; private set; }

        public Population Population { get; private set; }
        public Population NormalizedPopulation { get; private set; }
             * */

        }
    }
}
