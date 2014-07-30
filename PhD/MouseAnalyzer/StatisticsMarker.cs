using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer
{
    class StatisticsMarker : IValueMarker
    {
        public enum Type
        {
            Minimum,
            Average,
            Maximum,
            Median,
            Deviation,
            Variance,
            MdfMinimum,
            MdfAverage,
            MdfMaximum,
            MdfDeviation,
            MdfVariance
        }

        #region IMarker Members

        public string Name { get { return ( featureName == null ? "" : featureName + "." ) + type.ToString(); } }
        public IFeature Feature { get { return feature; } }

        #endregion

        #region IValueMarker Members

        public double Value { get { return value; } }

        #endregion

        private IFeature feature;
        private string featureName;
        private Type type;
        private double value;

        public StatisticsMarker( IFeature feature, string featureName, Type type, double value )
        {
            this.feature = feature;
            this.featureName = featureName;
            this.type = type;
            this.value = value;
        }
    }

    class HistogramMarker : IHistogramMarker
    {
        public enum Type
        {
            Head,
            Body,
            Tail
        }

        #region IMarker Members

        public string Name { get { return ( featureName == null ? "" : featureName + "." ) + "Histogram"; } }
        public IFeature Feature { get { return feature; } }

        #endregion

        #region IHistogramMarker Members

        public int[] Frequencies { get { return frequencies; } }
        public double[] BinMidpoints { get { return binMidpoints; } }

        #endregion

        private IFeature feature;
        private string featureName;
        private Type type;
        private int[] frequencies;
        private double[] binMidpoints;

        public HistogramMarker( IFeature feature, string featureName, Type type, IEnumerable<double> ordered, int bins )
        {
            this.feature = feature;
            this.featureName = featureName;
            this.type = type;
            this.frequencies = new int[bins];
            this.binMidpoints = new double[bins];

            var from = ordered.First();
            var to = ordered.Last();
            var range = to - from;
            foreach( var item in ordered )
            {
                var bin = range==0.0 ? bins : (int)( bins*( item-from )/range );
                ++frequencies[bin==bins ? --bin : bin];
            }

            for( var bin = 0; bin < bins; ++bin )
            {
                binMidpoints[bin] = from + ( bin+0.5 ) * range / bins;
            }
        }
    }

    class StatisticsMarkerExtractor : IMarkerExtractor
    {
        #region IMarkerExtractor Members

        public IEnumerable<IMarker> Extract( IFeature feature, IEnumerable<IFeatureItem> items, string featureName = null, Func<IFeatureItem, double> valueExtractor = null, int bins = 1000 )
        {
            var markers = new List<IMarker>();
            var input = items.Select<IFeatureItem, double>( d => valueExtractor( d ) ).Where( d => !double.IsNaN( d ) );
            var count = input.Count();
            var doubles = input.OrderBy( d => d );
            var average = doubles.Average();

            var head = doubles.Skip( count / 100 ).Take( count * 9 / 100 );
            var modified = doubles.Skip( count / 10 ).Take( count * 8 / 10 );
            var modifiedAverage = modified.Average();
            var tail = doubles.Skip( count * 9 / 10 ).Take( count * 9 / 100 );

            // plain values
            markers.Add( new StatisticsMarker( feature, featureName, StatisticsMarker.Type.Minimum, doubles.First() ) );
            markers.Add( new StatisticsMarker( feature, featureName, StatisticsMarker.Type.MdfMinimum, modified.First() ) );
            markers.Add( new StatisticsMarker( feature, featureName, StatisticsMarker.Type.Average, average ) );
            markers.Add( new StatisticsMarker( feature, featureName, StatisticsMarker.Type.MdfAverage, modifiedAverage ) );
            markers.Add( new StatisticsMarker( feature, featureName, StatisticsMarker.Type.Maximum, doubles.Last() ) );
            markers.Add( new StatisticsMarker( feature, featureName, StatisticsMarker.Type.MdfMaximum, modified.Last() ) );

            // median
            markers.Add( new StatisticsMarker( feature, featureName, StatisticsMarker.Type.Median, 0.5 * doubles.Skip( ( count-1 ) / 2 ).First() + 0.5 * doubles.Skip( count / 2 ).First() ) );

            // variance and deviation
            var squares = doubles.Select<double, double>( d => d * d ).Average();
            var variance = squares - average * average;
            var modifiedSquares = modified.Select<double, double>( d => d * d ).Average();
            var modifiedVariance = modifiedSquares - modifiedAverage * modifiedAverage;
            markers.Add( new StatisticsMarker( feature, featureName, StatisticsMarker.Type.Variance, variance ) );
            markers.Add( new StatisticsMarker( feature, featureName, StatisticsMarker.Type.MdfVariance, modifiedVariance ) );
            markers.Add( new StatisticsMarker( feature, featureName, StatisticsMarker.Type.Deviation, Math.Sqrt( variance ) ) );
            markers.Add( new StatisticsMarker( feature, featureName, StatisticsMarker.Type.MdfDeviation, Math.Sqrt( modifiedVariance ) ) );

            // histograms
            markers.Add( new HistogramMarker( feature, featureName, HistogramMarker.Type.Body, modified, bins ));
            markers.Add( new HistogramMarker( feature, featureName, HistogramMarker.Type.Tail, tail, bins / 11 ) );

            return markers;
        }

        #endregion
    }
}
