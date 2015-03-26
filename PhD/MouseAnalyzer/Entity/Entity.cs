using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using MouseAnalyzer.Statistics;

namespace MouseAnalyzer
{
    class Entity : IMarkers
    {
        private List<IFeature> features = new List<IFeature>();

        public Entity( string id, DataSource.EnvironmentType environment, DataSource.SourceType source, IList<Event> events )
        {
            Id = id;
            OfEnvironment = environment;
            Source = source;
            Events = events;
        }

        public string Id { get; private set; }
        public DataSource.EnvironmentType OfEnvironment { get; private set; }
        public DataSource.SourceType Source { get; private set; }
        public IList<Event> Events { get; private set; }

        public IEnumerable<IFeature> Features
        {
            get { return features; }
        }

        public IEnumerable<IMarker> Markers
        {
            get
            {
                return standaloneMarkers == null ?
                    Features.SelectMany<IFeature, IMarker>( f => f.Markers ) :
                    standaloneMarkers;
            }
        }

        public void AddFeature( IFeature feature )
        {
            features.Add( feature );
        }

        public void AddStandaloneMarker( IMarker marker )
        {
            if( standaloneMarkers == null )
            {
                standaloneMarkers = new List<IMarker>();
            }
            standaloneMarkers.Add( marker );
        }

        public IList<double> Match( IEnumerable<IMarkers> samples, MatchType matchType, bool normalize = false, bool computeDistanceInsteadOfProximity = false ) // intended to match self.Values to all sample.Values
        {
            switch( matchType )
            {
                case MatchType.DistributionArithmeticAverage:
                case MatchType.DistributionProduct:
                case MatchType.DistributionLogProduct:
                case MatchType.DistributionGeometricAverage:
                    return null;
            }

            var result = new List<double>();
            foreach( var sample in samples )
            {
                var mine = Markers.Where( m1 => m1 is IValueMarker ).Select( m2 => (IValueMarker)m2 ).GetEnumerator();
                var foreign = sample.Markers.Where( m1 => m1 is IValueMarker ).Select( m2 => (IValueMarker)m2 ).GetEnumerator();

                List<double> diffs = new List<double>();
                while( mine.MoveNext() && foreign.MoveNext() )
                {
                    var m = mine.Current.Value;
                    var f = foreign.Current.Value;
                    if( computeDistanceInsteadOfProximity )
                    {
                        diffs.Add( Math.Abs( m - f ) );
                    }
                    else
                    {
                        diffs.Add( Proximity( Math.Abs( m - f ), Math.Abs( m ) ) );
                    }
                }

                var measure = 0.0;
                switch( matchType )
                {
                    case MatchType.ItemArithmeticAverage: // the same as ItemD1Distance
                        measure = diffs.Average();
                        break;
                    case MatchType.ItemProduct:
                        measure = diffs.Where( d1 => d1 != 0.0 ).Product();
                        break;
                    case MatchType.ItemGeometricAverage:
                        measure = diffs.Where( d1 => d1 != 0.0 ).GeometricAverage();
                        break;
                    case MatchType.ItemD2Distance:
                        var squares = diffs.Select( d => d*d );
                        measure = Math.Sqrt( squares.Average() );
                        break;
                }

                result.Add( measure );
            }

            return result;
        }

        public IList<double> Match( Features.Markers drivingMarkers, IEnumerable<IFeatureItem> samples, MatchType matchType, bool adjustForInvalidSampleMarkers = true ) // intended to match self.Distributions to all samples.Values
        {
            switch( matchType )
            {
                case MatchType.DistributionArithmeticAverage:
                case MatchType.DistributionProduct:
                case MatchType.DistributionLogProduct:
                case MatchType.DistributionGeometricAverage:
                    break;
                default:
                    return null;
            }

            var markers = Markers.Where( m1 => ( drivingMarkers == null || m1 is IDistributionMarker && drivingMarkers.IsActive( m1.Name ))).Select( m2 => (IDistributionMarker)m2 );
            var markersCount = markers.Count();

            var result = new List<double>();
            foreach( var sample in samples )
            {
                var measure = 0.0;
                var probabilities = markers.Select( m1 =>
                {
                    var value = m1.Extractor( sample );
                    if( !double.IsNaN( value.Zero ) ) // evaluate only zero
                    {
                        return m1.Distribution.Zero.p( value.Zero );
                    }
                    else if( m1.Distribution.Negative == null ) // marker has no positive/negative split
                    {
                        return m1.Distribution.Positive.p( value.Positive );
                    }
                    else // marker has both negative and positive part
                    {
                        var havePositive = !double.IsNaN( value.Positive );
                        var haveNegative = !double.IsNaN( value.Negative );
                        if( havePositive && haveNegative )
                        {
                            return m1.Distribution.Positive.p( value.Positive ) *
                                   m1.Distribution.Negative.p( value.Negative );
                        }
                        else if( havePositive )
                        {
                            var p = m1.Distribution.Positive.p( value.Positive );
                            return p*p;
                        }
                        else if( haveNegative )
                        {
                            var p = m1.Distribution.Negative.p( value.Negative );
                            return p*p;
                        }
                        else
                        {
                            return double.NaN;
                        }
                    }
                } ).Where( p => !double.IsNaN( p ) );
                var validCount = probabilities.Count();

                if( !adjustForInvalidSampleMarkers && validCount < markersCount )
                {
                    // fall down
                }
                else if( validCount > 0 )
                {
                    switch( matchType )
                    {
                        case MatchType.DistributionArithmeticAverage:
                            measure = probabilities.Average();
                            break;
                        case MatchType.DistributionProduct:
                            measure = probabilities.Product();
                            if( adjustForInvalidSampleMarkers && validCount < markersCount ) // inside if, adjustForInvalidSampleMarkers if always true
                            {
                                measure = Math.Exp( markersCount / validCount * Math.Log( measure + 1E-300 ) );
                            }
                            break;
                        case MatchType.DistributionLogProduct:
                            measure = probabilities.Select( p => Math.Log( p + 1E-300 )).Sum();
                            if( double.IsInfinity( measure ) )
                            {
                                var xm = measure;
                            }
                            if( adjustForInvalidSampleMarkers && validCount < markersCount ) // inside if, adjustForInvalidSampleMarkers if always true
                            {
                                measure = markersCount / validCount * measure;
                            }
                            break;
                        case MatchType.DistributionGeometricAverage:
                            measure = probabilities.GeometricAverage();
                            break;
                    }
                }

                result.Add( measure );
            }

            return result;
        }

        private static double Proximity( double distance, double value )
        {
            return 1.0 / ( 1.0 + distance / ( 1.0 + value ) );
        }

        private List<IMarker> standaloneMarkers;
    }
}
