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

            public string CellSeparator
            {
                get { return dumper.CellSeparator; }
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
        private static object fileLock = new Object();
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
            string name = "EXP[" + fileMark + "][" + ( (int)type ).ToString( "D2" ) + "]" + DateTime.Now.ToString( "yyyyMMdd" );
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
            var CS = CellSeparator;
            var CS8 = CS + CS + CS + CS + CS + CS + CS + CS;
            var p = result.Parameters;

            Cell( "normalization", p.Normalization );
            Cell( "pcaRecompositionThreshold", p.PCARecompositionThreshold );

            int index = 1;
            CellsE( "component" + CS8, p.Components.Select( ( definition ) => (object)index++ ) );
            CellsE( "type" + CS8, p.Components.Select( ( definition ) => definition.Type.ToString() ) );
            CellsE( "p1" + CS8, p.Components.Select( ( definition ) => definition.Item2.ToString() ) );
            CellsE( "p2" + CS8, p.Components.Select( ( definition ) => definition.Item3.ToString() ) );
        }

        private void DumpCommon()
        {
            var CS = CellSeparator;
            var CS8 = CS + CS + CS + CS + CS + CS + CS + CS;
            var r = result;
            var p = r.Parameters;

            Cell( "distance" );
            CellsE( "which", p.DistanceTypes.Select( ( distance ) => distance ) );
            CellsE( "plain", p.DistanceTypes.Select( ( distance ) => r.PlainDistances[distance].ToString( "G5" ) ) );
            CellsE( "PCA", p.DistanceTypes.Select( ( distance ) => r.PCADistances[distance].ToString( "G5" ) ) );

            CellsVA( "PCA" );
            CellsE( "weights" + CS8, r.PCAWeights.Components.Select( ( i ) => i.ToString( "G5" ) ) );

            Cell( "differential evolutions parameters, by distance type" );
            CellsVA( "i", "dDE / dP", "distance", "type", "parentWeight", "crossover", "population", "iterations", "distance", "weights ->" );
            int index = 1;
            foreach( var de in r.DEResults.OrderBy( ( der ) => 100 * ( (int)der.Distance.Type ) + ( (int)der.Distance.Processing ) ) )
            {
                var components = de.DEWeights.Components.ToList();
                if( de.ToCompare )
                {
                    var spread = new double[30];
                    int si = 0;
                    for( int i = 0; i < spread.Length; i++ )
                    {
                        switch( i%3 )
                        {
                            case 0: spread[i] = components[si++]; break;
                            case 1: spread[i] = 0.0; break;
                            case 2: spread[i] = components[si++]; break;
                        }
                    }
                    components = spread.ToList<double>();
                }

                CellsE( String.Join( CS, (index++).ToString() + (de.ToCompare ? "co" : "ex"), ( de.DEDistance / r.PlainDistances[de.Distance] ).ToString( "G5" ), de.DEDistance.ToString( "G5" ), de.Type, de.Weight, de.Crossover, de.PopulationCount, de.IterationCount, de.Distance ),
                        components.Select( ( i ) => i.ToString( "G5" ) ) );

                // CellsE( String.Join( CS, ( index++ ).ToString() + ( de.ToCompare ? "coX" : "exX" ), ( de.DEDistance / r.PlainDistances[de.Distance] ).ToString( "G5" ), de.DEDistance.ToString( "G5" ), de.Type, de.Weight, de.Crossover, de.PopulationCount, de.IterationCount, de.Distance ),
                //         de.DEWeights.Components.Select( ( i ) => i.ToString( "G5" ) ) );
            }
            Cell( "differential evolutions parameters, by distance" );
            CellsVA( "i", "dDE / dP", "distance", "type", "parentWeight", "crossover", "population", "iterations", "distance",  "weights ->" );
            index = 1;
            foreach( var de in r.DEResults.OrderBy( ( der ) => der.DEDistance / r.PlainDistances[der.Distance] ) )
            {
                var components = de.DEWeights.Components.ToList();
                if( de.ToCompare )
                {
                    var spread = new double[30];
                    int si = 0;
                    for( int i = 0; i < spread.Length; i++ )
                    {
                        switch( i%3 )
                        {
                            case 0: spread[i] = components[si++]; break;
                            case 1: spread[i] = 0.0; break;
                            case 2: spread[i] = components[si++]; break;
                        }
                    }
                    components = spread.ToList<double>();
                }

                CellsE( String.Join( CS, ( index++ ).ToString() + ( de.ToCompare ? "co" : "ex" ), ( de.DEDistance / r.PlainDistances[de.Distance] ).ToString( "G5" ), de.DEDistance.ToString( "G5" ), de.Type, de.Weight, de.Crossover, de.PopulationCount, de.IterationCount, de.Distance ),
                        components.Select( ( i ) => i.ToString( "G5" ) ) );

                // CellsE( String.Join( CS, ( index++ ).ToString() + ( de.ToCompare ? "coX" : "exX" ), ( de.DEDistance / r.PlainDistances[de.Distance] ).ToString( "G5" ), de.DEDistance.ToString( "G5" ), de.Type, de.Weight, de.Crossover, de.PopulationCount, de.IterationCount, de.Distance ),
                //         de.DEWeights.Components.Select( ( i ) => i.ToString( "G5" ) ) );
            }

            Cell( "population" );
            index = 1;
            foreach( var ind in r.Population.Templates )
            {
                CellsE( ( index++ ).ToString(), ind.Components.Select( ( i ) => i.ToString( "G5" ) ) );
            }
            Cell( "normalized population" );
            index = 1;
            foreach( var ind in r.NormalizedPopulation.Templates )
            {
                CellsE( ( index++ ).ToString(), ind.Components.Select( ( i ) => i.ToString( "G5" ) ) );
            }

            Cell( "differential evolutions criterion development, by distance" );
            CellsVA( "i", "dDE / dP", "distance", "type", "parentWeight", "crossover", "population", "iterations", "distance", "develop ->" );
            index = 1;
            foreach( var de in r.DEResults.OrderBy( ( der ) => der.DEDistance / r.PlainDistances[der.Distance] ) )
            {
                CellsE( String.Join( CS, ( index++ ).ToString() + ( de.ToCompare ? "co" : "ex" ), ( de.DEDistance / r.PlainDistances[de.Distance] ).ToString( "G5" ), de.DEDistance.ToString( "G5" ), de.Type, de.Weight, de.Crossover, de.PopulationCount, de.IterationCount, de.Distance ),
                        de.DEDistanceDevelop.Select( ( i ) => i.ToString( "G5" ) ) );
            }
        }
    }
}
