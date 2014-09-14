using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using MouseAnalyzer.Optimizer;

namespace MouseAnalyzer.Lookup
{
    class Population
    {
        public enum DistanceMeasureType
        {
            Average,
            LimitedAverage,
            GeometricAverage,
            Minimum,
            Median,
            MinimumTimesMedian,
            Maximum,
            Summation,
            AverageWithLeastVariance
        }

        public static string DistanceProcessingAbbreviation( DistanceMeasureType dp )
        {
            switch( dp )
            {
                case Population.DistanceMeasureType.Average: return "a";
                case Population.DistanceMeasureType.LimitedAverage: return "l";
                case Population.DistanceMeasureType.GeometricAverage: return "g";
                case Population.DistanceMeasureType.Median: return "x";
                case Population.DistanceMeasureType.Minimum: return "m";
                case Population.DistanceMeasureType.MinimumTimesMedian: return "t";
                case Population.DistanceMeasureType.Maximum: return "M";
                case Population.DistanceMeasureType.Summation: return "s";
                case Population.DistanceMeasureType.AverageWithLeastVariance: return "v";
            }
            return String.Empty;
        }

        public enum NormalizationType
        {
            None,
            Center, // - mean
            Standard, // (- mean) / stdev
            CenterMax, // - mean / max
            CenterRange, // - mean / (max-min)
            Desquare // / avg(x*x)
        }

        private List<Template> templates;
        Dictionary<Tuple<int, int>, double> precomputedDistances;
        private double[] normalizerOffset;
        private double[] normalizerGain;

        public Population( IEnumerable<Template> source )
        {
            templates = source.ToList<Template>();
        }

        public Population( IEnumerable<Entity> entities )
        {
            templates = new List<Template>();
            foreach( var entity in entities )
            {
                templates.Add( new Template( entity ) );
            }
        }

        public Population( Population denormalized, NormalizationType howNormalize )
        {
            templates = new List<Template>();
            Normalization = howNormalize;
            PerformNormalization( denormalized );
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

        public NormalizationType Normalization
        {
            get; private set;
        }

        public void AddTemplate( Template template )
        {
            templates.Add( template );
        }

        public List<int> DetermineConstantComponents()
        {
            var list = new List<int>();

            for( var j = 0; j < ComponentCount; j++ )
            {
                var constant = true;
                for( var i = 1; i < TemplateCount; i++ )
                {
                    if( templates[i][j] != templates[i-1][j] )
                    {
                        constant = false;
                        break;
                    }
                }

                if( constant )
                {
                    list.Add( j );
                }
            }

            return list;
        }

        public void PrecomputeUnoptimizedDistances( Template.DistanceType distanceType )
        {
            precomputedDistances = new Dictionary<Tuple<int, int>, double>();
            var uniform = Weights.Uniform( ComponentCount );
            for( var i = 0; i < templates.Count; i++ )
            {
                for( var j = i+1; j < templates.Count; j++ )
                {
                    precomputedDistances.Add( new Tuple<int, int>( i, j ), templates[i].Distance( templates[j], distanceType, uniform ) );
                }
            }
        }

        public double DistanceMeasure( Distance distance, Weights weights )
        {
            return DistanceMeasure( distance.Type, distance.Processing, weights );
        }

        public double DistanceMeasure( Template.DistanceType distanceType, DistanceMeasureType distanceProcessing, Weights weights )
        {
            if( templates.Count == 0 )
            {
                return 0.0;
            }

            double distance = 0.0;
            double distanceSquare = 0.0;
            List<double> distances = null;
            switch( distanceProcessing )
            {
                case DistanceMeasureType.Minimum:
                    distance = Double.MaxValue;
                    break;
                case DistanceMeasureType.LimitedAverage:
                case DistanceMeasureType.Median:
                    distances = new List<double>();
                    break;
                case DistanceMeasureType.MinimumTimesMedian:
                    distance = Double.MaxValue;
                    distances = new List<double>();
                    break;
                case DistanceMeasureType.Maximum:
                    distance = Double.MinValue;
                    break;
            }

            if( precomputedDistances == null )
            {
                PrecomputeUnoptimizedDistances( distanceType );
            }

            var n = 1; // it means new count
            for( var i = 0; i < templates.Count; i++ )
            {
                for( var j = i+1; j < templates.Count; j++ )
                {
                    var diju = precomputedDistances[new Tuple<int, int>(i, j)];
                    var dijo = templates[i].Distance( templates[j], distanceType, weights );
                    var dij = dijo / diju;

                    switch( distanceProcessing )
                    {
                        case DistanceMeasureType.Summation:
                            distance += dij;
                            break;
                        case DistanceMeasureType.Average:
                            distance += ( dij - distance ) / n;
                            break;
                        case DistanceMeasureType.GeometricAverage:
                            distance += ( Math.Log( dij ) - distance ) / n;
                            break;
                        case DistanceMeasureType.Minimum:
                            distance = dij < distance ? dij : distance;
                            break;
                        case DistanceMeasureType.LimitedAverage:
                        case DistanceMeasureType.Median:
                            distances.Add( dij );
                            break;
                        case DistanceMeasureType.MinimumTimesMedian:
                            distance = dij < distance ? dij : distance;
                            distances.Add( dij );
                            break;
                        case DistanceMeasureType.Maximum:
                            distance = dij > distance ? dij : distance;
                            break;
                        case DistanceMeasureType.AverageWithLeastVariance:
                            distance += ( dij - distance ) / n;
                            distanceSquare += ( dij*dij - distanceSquare ) / n;
                            break;
                    }

                    n++;
                }
            }

            switch( distanceProcessing )
            {
                case DistanceMeasureType.GeometricAverage:
                    return Math.Exp( distance );
                case DistanceMeasureType.LimitedAverage:
                    distances.Sort();
                    var lacount = distances.Count;
                    return distances.Skip( lacount/10 ).Take( 8*lacount/10 ).Average();
                case DistanceMeasureType.Median:
                case DistanceMeasureType.MinimumTimesMedian:
                    distances.Sort();
                    var count = distances.Count;
                    var multiplier = distanceProcessing == DistanceMeasureType.Median ? 1.0 : distance;
                    var median = count % 2 == 0 ?
                        0.5 * distances[count / 2 - 1] + 0.5 * distances[count / 2] :
                        distances[count / 2];
                    return median * multiplier;
                case DistanceMeasureType.AverageWithLeastVariance:
                    var variance = distanceSquare - distance*distance;
                    return distance / ( 0.5 + Math.Sqrt( variance ) ); // 1.0 avoids division by zero, in other words, ideal data with zero variance returns maximal average
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
                Select( t => new { entity = t.Entity, distance = t.Distance( normalized, distance, weights ) } ).
                OrderBy( o => o.distance ).
                Take( candidates ).
                Select( s => new Tuple<Entity, double>( s.entity, s.distance / normalizationDenominator ) );
        }

        public List<double> Distances( Distance distance, Weights weights )
        {
            var distances = new List<double>();
            for( var i = 0; i < templates.Count; i++ )
            {
                for( var j = i+1; j < templates.Count; j++ )
                {
                    distances.Add( templates[i].Distance( templates[j], distance, weights ) );
                }
            }
            return distances;
        }

        private void PerformNormalization( Population denormalized )
        {
            // copy data
            foreach( var template in denormalized.templates )
            {
                templates.Add( new Template( template.Entity, template.Components ));
            }

            // prepare process data
            var templateCount = denormalized.TemplateCount;
            var componentCount = denormalized.ComponentCount;

            normalizerOffset = new double[componentCount];
            normalizerGain = new double[componentCount];
            var min = new double[componentCount];

            for( var j = 0; j < componentCount; j++ )
            {
                normalizerOffset[j] = 0.0;
                normalizerGain[j] = ( Normalization == NormalizationType.None ) || ( Normalization == NormalizationType.Center ) ? 1.0 : 0.0;
                min[j] = double.MaxValue;
            }

            if( Normalization == NormalizationType.None ) // we are done, return
            {
                return;
            }

            // normalize
            // compute means, min, max
            var n = 1; // it means new count
            for( var i = 0; i < templateCount; i++ )
            {
                for( var j = 0; j < componentCount; j++ )
                {
                    var aij = templates[i][j];
                    if( Normalization != NormalizationType.Desquare )
                    {
                        normalizerOffset[j] += ( aij - normalizerOffset[j] ) / n;
                    }

                    if( Normalization == NormalizationType.Standard )
                    {
                        normalizerGain[j] += ( aij*aij - normalizerGain[j] ) / n; // for Normalize normalizer is stdev (sqrt(mean(aij*aij)-mean(aij)*mean(aij))), here mean(aij*aij) is computed
                    }
                    else if( Normalization == NormalizationType.CenterMax )
                    {
                        normalizerGain[j] = Math.Abs( aij ) > normalizerGain[j] ? Math.Abs( aij ) : normalizerGain[j];
                    }
                    else if( Normalization == NormalizationType.CenterRange )
                    {
                        min[j] = aij < min[j] ? aij : min[j];
                        normalizerGain[j] = aij > normalizerGain[j] ? aij : normalizerGain[j];
                    }
                    else if( Normalization == NormalizationType.Desquare )
                    {
                        normalizerGain[j] += ( aij*aij - normalizerGain[j] ) / n; // mean(aij*aij) is computed
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

            // prepare normalization coefficients
            for( var j = 0; j < componentCount; j++ )
            {
                if( Normalization == NormalizationType.Standard )
                {
                    normalizerGain[j] -= normalizerOffset[j]*normalizerOffset[j]; // here mean(aij)*mean(aij) is subtracted
                    normalizerGain[j] = normalizerGain[j] == 0.0 ? 0.0 : 1.0 / Math.Sqrt( normalizerGain[j] ); // for both Normalize and Standardize sqrt must be applied
                }
                else if( Normalization == NormalizationType.CenterMax )
                {
                    normalizerGain[j] += normalizerOffset[j]; // here mean(aij) about which all values were already lessened is subtracted
                    normalizerGain[j] = normalizerGain[j] == 0.0 ? 0.0 : 1.0 / normalizerGain[j];
                }
                else if( Normalization == NormalizationType.CenterRange )
                {
                    normalizerGain[j] -= min[j];
                    normalizerGain[j] = normalizerGain[j] == 0.0 ? 0.0 : 1.0 / normalizerGain[j];
                }
                else if( Normalization == NormalizationType.Desquare )
                {
                    normalizerGain[j] = normalizerGain[j] == 0.0 ? 0.0 : 1.0 / Math.Sqrt( normalizerGain[j] );
                }
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
    }
}
