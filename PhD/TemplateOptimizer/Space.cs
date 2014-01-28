using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace TemplateOptimizer
{
    class Space
    {
        public enum DistanceType
        {
            Summation,
            Average,
            GeometricAverage
        }

        private List<Template> templates;

        public Space()
        {
            templates = new List<Template>();
        }

        public Space( IEnumerable<Template> source )
        {
            templates = source.ToList<Template>();
        }

        public IEnumerable<Template> Templates
        {
            get
            {
                return templates;
            }
        }

        public void AddTemplate( Template template )
        {
            templates.Add( template );
        }

        public double Distance( DistanceType distanceType, Weights weights )
        {
            var distance = 0.0;
            var n = 1; // it means new count
            for( var i = 0; i < templates.Count; i++ )
            {
                for( var j = i+1; j < templates.Count; j++ )
                {
                    var dij = templates[i].Distance( templates[j], weights );

                    switch( distanceType )
                    {
                        case DistanceType.Summation:
                            distance += dij;
                            break;
                        case DistanceType.Average:
                            distance += ( dij - distance ) / n;
                            break;
                        case DistanceType.GeometricAverage:
                            distance += ( Math.Log( dij ) - distance ) / n;
                            break;
                    }

                    n++;
                }
            }

            if( distanceType == DistanceType.GeometricAverage )
            {
                return Math.Exp( distance );
            }
            else
            {
                return distance;
            }
        }
    }
}
