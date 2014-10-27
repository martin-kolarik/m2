using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using MouseAnalyzer.Optimizer;

namespace MouseAnalyzer.Features
{
    class Markers
    {
        private class MarkerData
        {
            public int Index;
            public string Name;
            public double Weight;
        }

        public void AddMarkers( IEnumerable<IMarker> markers )
        {
            foreach( var marker in markers )
            {
                var data = new MarkerData()
                {
                    Name = marker.Name,
                    Index = map.Count
                };
                list.Add( data );
                active.Add( map.Count );
                map.Add( marker.Name, data );
            }
        }

        public IEnumerable<string> Names
        {
            get
            {
                return list.Select( i => i.Name );
            }
        }

        public int NameToIndex( string name )
        {
            return map[name].Index;
        }

        public string IndexToName( int index )
        {
            return list[index].Name;
        }

        public int Count
        {
            get
            {
                return list.Count;
            }
        }

        public Weights Weights
        {
            get
            {
                var weights = new Weights( list.Count );
                for( int i = 0; i < list.Count; i++ )
                {
                    weights[i] = list[i].Weight;
                }
                return weights;
            }
            set
            {
                if( value.ComponentCount != list.Count )
                {
                    throw new Exception();
                }
                for( int i = 0; i < list.Count; i++ )
                {
                    list[i].Weight = value[i];
                }
            }
        }

        public Vector Actives
        {
            get
            {
                var actives = new Vector( list.Count );
                for( int i = 0; i < list.Count; i++ )
                {
                    actives[i] = active.Contains(i) ? 1.0 : 0.0;
                }
                return actives;
            }
        }

        public int ActiveCount
        {
            get
            {
                return active.Count;
            }
        }

        public Weights ActiveWeights
        {
            get
            {
                var ia = 0;
                var weights = new Weights( active.Count );
                for( int i = 0; i < list.Count; i++ )
                {
                    if( active.Contains( i ) )
                    {
                        weights[ia++] = list[i].Weight;
                    }
                }
                return weights;
            }
            set
            {
                var ia = 0;
                for( int i = 0; i < list.Count; i++ )
                {
                    if( active.Contains( i ) )
                    {
                        list[i].Weight = value[ia++];
                    }
                }
            }
        }

        public bool IsActive( string name )
        {
            MarkerData data;
            return map.TryGetValue( name, out data ) && active.Contains( data.Index );
        }

        public bool IsActive( int index )
        {
            return active.Contains( index );
        }

        public void SetActive( int index, bool isActive )
        {
            if( isActive )
            {
                active.Add( index );
            }
            else
            {
                active.Remove( index );
            }
        }

        public bool IsConstant( string name )
        {
            MarkerData data;
            return map.TryGetValue( name, out data ) && constant.Contains( data.Index );
        }

        public bool IsConstant( int index )
        {
            return constant.Contains( index );
        }

        public void SetConstant( int index, bool isConstant )
        {
            if( isConstant )
            {
                constant.Add( index );
            }
            else
            {
                constant.Remove( index );
            }
        }

        public double Weight( int index )
        {
            return list[index].Weight;
        }

        public void SetWeight( int index, double weight )
        {
            list[index].Weight = weight;
        }

        public Weights CompressToActive( Weights allToCompress )
        {
            if( allToCompress.ComponentCount != list.Count )
            {
                throw new Exception();
            }
            var ia = 0;
            var weights = new Weights( active.Count );
            for( int i = 0; i < list.Count; i++ )
            {
                if( active.Contains( i ) )
                {
                    weights[ia++] = allToCompress[i];
                }
            }
            return weights;
        }

        public Weights ExpandFromActive( Weights activeToExpand )
        {
            if( activeToExpand.ComponentCount != active.Count )
            {
                throw new Exception();
            }
            var ia = 0;
            var weights = new Weights( list.Count );
            for( int i = 0; i < list.Count; i++ )
            {
                if( active.Contains( i ) )
                {
                    weights[i] = activeToExpand[ia++];
                }
            }
            return weights;
        }

        public string Serialize()
        {
            return string.Join( ",", active.Select( a => list[a].Name ) );
        }

        public void Deserialize( string input )
        {
            active.Clear();
            foreach( var s in input.Split( ' ', ',' ) )
            {
                active.Add( map[s].Index );
            }
        }

        private Dictionary<string, MarkerData> map = new Dictionary<string, MarkerData>();
        private List<MarkerData> list = new List<MarkerData>();
        private HashSet<int> active = new HashSet<int>();
        private HashSet<int> constant = new HashSet<int>();
    }
}
