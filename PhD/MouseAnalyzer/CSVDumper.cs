using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer
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

            public void Cell( object cell )
            {
                dumper.Cell( cell );
            }

            public void Cell( string label, object cell )
            {
                dumper.Cell( label, cell );
            }

            public void CellsE( string label, bool bylines, IEnumerable<object> cells )
            {
                dumper.CellsE( label, bylines, cells );
            }

            public void CellsVA( bool bylines, params object[] cells )
            {
                dumper.CellsVA( bylines, cells );
            }

            public void Columns( IEnumerable<object> headers, IEnumerable<IEnumerable<object>> series )
            {
                dumper.Columns( headers, series );
            }
        }

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

        public CSVDumper()
        {
            CellSeparator = @";";
            Directory = @".\res";
        }

        public void Dump( string fileMark, Action<CSVParticularResultDumper> particularResultDumper = null )
        {
            CreateFile( fileMark );

            if( particularResultDumper != null )
            {
                particularResultDumper( new CSVParticularResultDumper( this ) );
            }

            CloseFile();
        }

        private void Cell( object cell )
        {
            CellsVA( false, cell );
        }

        private void Cell( string label, object cell )
        {
            CellsVA( false, label, cell );
        }

        private void CellsE( string label, bool bylines, IEnumerable<object> cells )
        {
            bool inline = false;
            StringBuilder builder = new StringBuilder();

            if( label != null )
            {
                inline = true;
                builder.Append( label );
                if( bylines )
                {
                    writer.WriteLine();
                }
            }

            foreach( var cell in cells )
            {
                if( inline )
                {
                    builder.Append( CellSeparator );
                }
                inline = true;
                builder.Append( cell );
                if( bylines )
                {
                    writer.WriteLine( builder.ToString() );
                    builder = new StringBuilder();
                    inline = false;
                }
            }
            if( !bylines )
            {
                writer.WriteLine( builder.ToString() );
            }
        }

        private void CellsVA( bool bylines, params object[] cells )
        {
            CellsE( null, bylines, cells );
        }

        private void Columns( IEnumerable<object> headers, IEnumerable<IEnumerable<object>> series )
        {
            CellsE( null, false, headers );

            var enumerators = new List<IEnumerator<object>>();
            foreach( var serie in series )
            {
                enumerators.Add( serie.GetEnumerator() );
            }

            for( ; ; )
            {
                var any = false;

                var builder = new StringBuilder();
                foreach( var enumerator in enumerators )
                {
                    if( enumerator.MoveNext() )
                    {
                        any = true;
                        builder.Append( enumerator.Current );
                    }
                    builder.Append( CellSeparator );
                }
                writer.WriteLine( builder.ToString() );

                if( !any )
                {
                    break;
                }
            }
        }

        private void CreateFile( string fileMark )
        {
            string name = "RES[" + fileMark + "]";
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
    }
}
