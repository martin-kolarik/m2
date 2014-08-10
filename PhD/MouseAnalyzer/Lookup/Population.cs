using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using MouseAnalyzer.Optimizer;

namespace MouseAnalyzer.Lookup
{
    class Population
    {
        public enum DistanceProcessing
        {
            Average,
            LimitedAverage,
            GeometricAverage,
            Minimum,
            Median,
            MinimumTimesMedian,
            Summation
        }

        public static string DistanceProcessingAbbreviation( DistanceProcessing dp )
        {
            switch( dp )
            {
                case Population.DistanceProcessing.Average: return "a";
                case Population.DistanceProcessing.LimitedAverage: return "l";
                case Population.DistanceProcessing.GeometricAverage: return "g";
                case Population.DistanceProcessing.Median: return "x";
                case Population.DistanceProcessing.Minimum: return "m";
                case Population.DistanceProcessing.MinimumTimesMedian: return "t";
                case Population.DistanceProcessing.Summation: return "s";
            }
            return String.Empty;
        }

        public enum NormalizationType
        {
            None,
            Center, // - mean
            Standard, // (- mean) / stdev
            Normalize, // (- mean), length of component samples is 1
            Unite // - min / (max-min)
        }

        private List<Template> templates;
        private double[] normalizerOffset;
        private double[] normalizerGain;

        public Population( IEnumerable<Template> source )
        {
            templates = source.ToList<Template>();
            Mask = Weights.Unit( templates[0].ComponentCount );
        }

        public Population( IEnumerable<Entity> entities )
        {
            templates = new List<Template>();
            foreach( var entity in entities )
            {
                templates.Add( new Template( entity ) );
            }
            Mask = Weights.Unit( templates[0].ComponentCount );
        }

        public Population( Population denormalized, NormalizationType howNormalize )
        {
            templates = new List<Template>();
            Normalization = howNormalize;
            PerformNormalization( denormalized );
            Mask = new Weights( denormalized.Mask.Components );
        }

        public IEnumerable<Template> Templates
        {
            get { return templates; }
        }

        public bool Empty
        {
            get { return templates.Count == 0; }
        }

        public int TemplateCount
        {
            get { return templates.Count; }
        }

        public int ComponentCount
        {
            get { return Empty ? 0 : templates[0].ComponentCount; }
        }

        public Weights Mask // 1.0 means component is active, 0.0 means component is switched off
        {
            get; private set;
        }

        public NormalizationType Normalization
        {
            get; private set;
        }

        public void AddTemplate( Template template )
        {
            templates.Add( template );
        }

        public double Distance( Distance distance, Weights weights )
        {
            return Distance( distance.Type, distance.Processing, weights );
        }

        public double Distance( Template.DistanceType distanceType, DistanceProcessing distanceProcessing, Weights weights )
        {
            if( templates.Count == 0 )
            {
                return 0.0;
            }

            double distance = 0.0;
            List<double> distances = null;
            switch( distanceProcessing )
            {
                case DistanceProcessing.Minimum:
                    distance = Double.MaxValue;
                    break;
                case DistanceProcessing.LimitedAverage:
                case DistanceProcessing.Median:
                    distances = new List<double>();
                    break;
                case DistanceProcessing.MinimumTimesMedian:
                    distance = Double.MaxValue;
                    distances = new List<double>();
                    break;
            }
            
            
            var n = 1; // it means new count
            for( var i = 0; i < templates.Count; i++ )
            {
                for( var j = i+1; j < templates.Count; j++ )
                {
                    var dij = templates[i].Distance( templates[j], distanceType, weights, Mask );

                    switch( distanceProcessing )
                    {
                        case DistanceProcessing.Summation:
                            distance += dij;
                            break;
                        case DistanceProcessing.Average:
                            distance += ( dij - distance ) / n;
                            break;
                        case DistanceProcessing.GeometricAverage:
                            distance += ( Math.Log( dij ) - distance ) / n;
                            break;
                        case DistanceProcessing.Minimum:
                            distance = dij < distance ? dij : distance;
                            break;
                        case DistanceProcessing.LimitedAverage:
                        case DistanceProcessing.Median:
                            distances.Add( dij );
                            break;
                        case DistanceProcessing.MinimumTimesMedian:
                            distance = dij < distance ? dij : distance;
                            distances.Add( dij );
                            break;
                    }

                    n++;
                }
            }

            switch( distanceProcessing )
            {
                case DistanceProcessing.GeometricAverage:
                    return Math.Exp( distance );
                case DistanceProcessing.LimitedAverage:
                    distances.Sort();
                    var lacount = distances.Count;
                    return distances.Skip( lacount/10 ).Take( 8*lacount/10 ).Average();
                case DistanceProcessing.Median:
                case DistanceProcessing.MinimumTimesMedian:
                    distances.Sort();
                    var count = distances.Count;
                    var multiplier = distanceProcessing == DistanceProcessing.Median ? 1.0 : distance;
                    var median = count % 2 == 0 ?
                        0.5 * distances[count / 2 - 1] + 0.5 * distances[count / 2] :
                        distances[count / 2];
                    return median * multiplier;
                default:
                    return distance;
            }
        }

        public IEnumerable<Tuple<Entity, double>> Lookup( Template foreign, Distance distance, Weights weights, double normalizationDenominator = 1.0, int candidates = 5 )
        {
            // normalize
            var componentCount = foreign.ComponentCount;
            var normalized = new Template( foreign.Entity, componentCount );
            for( var j = 0; j < componentCount; ++j )
            {
                normalized[j] = ( foreign[j] + normalizerOffset[j] ) * normalizerGain[j];
            }

            // lookup
            return templates.
                Select( t => new { entity = t.Entity, distance = t.Distance( normalized, distance, weights, Mask ) } ).
                OrderBy( o => o.distance ).
                Take( candidates ).
                Select( s => new Tuple<Entity, double>( s.entity, s.distance / normalizationDenominator ) );
        }

        private void PerformNormalization( Population denormalized )
        {
            // copy data
            foreach( var template in denormalized.templates )
            {
                templates.Add( new Template( template.Entity, template.Components ));
            }

            // normalize
            if( Normalization == NormalizationType.None ) // we are done, return
            {
                return;
            }

            var componentCount = denormalized.ComponentCount;
            normalizerOffset = new double[componentCount];
            normalizerGain = new double[componentCount];
            for( var j = 0; j < componentCount; j++ )
            {
                normalizerOffset[j] = 0.0;
                normalizerGain[j] = 1.0;
            }
            if( Normalization == NormalizationType.Unite )
            {
                PerformUniteNormalization( denormalized );
            }
            else
            {
                PerformGaussNormalization( denormalized );
            }
        }

        private void PerformGaussNormalization( Population denormalized )
        {
            var templateCount = denormalized.TemplateCount;
            var componentCount = denormalized.ComponentCount;

            // compute means
            var n = 1; // it means new count
            for( var i = 0; i < templateCount; i++ )
            {
                for( var j = 0; j < componentCount; j++ )
                {
                    var aij = templates[i][j];
                    normalizerOffset[j] += ( aij - normalizerOffset[j] ) / n;
                    if( Normalization == NormalizationType.Standard )
                    {
                        normalizerGain[j] += ( aij*aij - normalizerGain[j] ) / n; // for Normalize normalizer is stdev (sqrt(mean(aij*aij)-mean(aij)*mean(aij))), here mean(aij*aij) is computed
                    }
                }
                n++;
            }

            // adjust data
            // subtract mean
            for( var j = 0; j < componentCount; j++ )
            {
                normalizerOffset[j] = -normalizerOffset[j];
            }
            for( var i = 0; i < templateCount; i++ )
            {
                for( var j = 0; j < componentCount; j++ )
                {
                    templates[i][j] += normalizerOffset[j];
                }
            }
            if( Normalization == NormalizationType.Center ) // we are done, return
            {
                return;
            }

            // prepare normalization coefficients -- for Normalize compute euclidean length of component
            for( var j = 0; j < componentCount; j++ )
            {
                if( Normalization == NormalizationType.Normalize )
                {
                    for( var i = 0; i < templateCount; i++ )
                    {
                        var aij = templates[i][j];
                        normalizerGain[j] += aij * aij;
                    }
                }
                else if( Normalization == NormalizationType.Standard )
                {
                    normalizerGain[j] -= normalizerOffset[j]*normalizerOffset[j]; // here mean(aij)*mean(aij) is subtracted
                }
                normalizerGain[j] = 1.0 / Math.Sqrt( normalizerGain[j] ); // for both Normalize and Standardize sqrt must be applied
            }
            // normalize
            for( var i = 0; i < templateCount; i++ )
            {
                for( var j = 0; j < componentCount; j++ )
                {
                    templates[i][j] *= normalizerGain[j];
                }
            }
        }

        private void PerformUniteNormalization( Population denormalized )
        {
            var templateCount = denormalized.TemplateCount;
            var componentCount = denormalized.ComponentCount;

            // compute min and max
            for( var j = 0; j < componentCount; ++j )
            {
                normalizerOffset[j] = double.MaxValue;
                normalizerGain[j] = double.MinValue;
            }
            for( var i = 0; i < templateCount; ++i )
            {
                for( var j = 0; j < componentCount; ++j )
                {
                    var aij = templates[i][j];
                    normalizerOffset[j] = aij < normalizerOffset[j] ? aij : normalizerOffset[j];
                    normalizerGain[j] = aij > normalizerGain[j] ? aij : normalizerGain[j];
                }
            }
            for( var j = 0; j < componentCount; ++j )
            {
                normalizerOffset[j] = -normalizerOffset[j];
                normalizerGain[j] = normalizerGain[j] + normalizerOffset[j];
                normalizerGain[j] = normalizerGain[j] == 0.0 ? 1.0 : 1.0 / normalizerGain[j];
            }

            // normalize
            for( var i = 0; i < templateCount; ++i )
            {
                for( var j = 0; j < componentCount; ++j )
                {
                    templates[i][j] += normalizerOffset[j];
                    templates[i][j] *= normalizerGain[j];
                }
            }
        }
    }
}
