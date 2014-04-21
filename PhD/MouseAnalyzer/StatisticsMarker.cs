using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer
{
    class StatisticsMarker : IMarker
    {
        public enum Type
        {
            Minimum,
            Average,
            Maximum,
            Median,
            Deviation,
            Variance
        }

        #region IMarker Members

        public string Name { get { return type.ToString(); } }
        public IFeature Feature { get { return feature; } }
        public double Value { get { return value; } }

        #endregion

        private IFeature feature;
        private Type type;
        private double value;

        public StatisticsMarker( IFeature feature, Type type, double value )
        {
            this.feature = feature;
            this.type = type;
            this.value = value;
        }
    }

    class StatisticsMarkerExtractor : IMarkerExtractor
    {
        #region IMarkerExtractor Members

        public IEnumerable<IMarker> Extract( IFeature feature, IEnumerable<IFeatureItem> items, Func<IFeatureItem, double> valueExtractor = null )
        {
            var markers = new List<IMarker>();
            var doubles = items.Select<IFeatureItem, double>( f => valueExtractor( f ) );

            doubles = new double[4] {3,4,5,6};

            // plain values
            markers.Add( new StatisticsMarker( feature, StatisticsMarker.Type.Minimum, doubles.Min() ) );
            var average = doubles.Average();
            markers.Add( new StatisticsMarker( feature, StatisticsMarker.Type.Average, average ) );
            markers.Add( new StatisticsMarker( feature, StatisticsMarker.Type.Maximum, doubles.Max() ) );

            // median
            if( doubles.Count() > 0 )
            {
                var ordered = doubles.OrderBy( d => d );
                markers.Add( new StatisticsMarker( feature, StatisticsMarker.Type.Median, 0.5 * ordered.Skip( ( doubles.Count()-1 ) / 2 ).First() + 0.5 * ordered.Skip( doubles.Count() / 2 ).First() ) );
            }

            // variance and deviation
            var squares = doubles.Select<double, double>( d => d * d ).Average();
            var variance = squares - average * average;
            markers.Add( new StatisticsMarker( feature, StatisticsMarker.Type.Variance, variance ) );
            markers.Add( new StatisticsMarker( feature, StatisticsMarker.Type.Variance, Math.Sqrt( variance ) ) );

            return markers;
        }

        #endregion
    }
}
