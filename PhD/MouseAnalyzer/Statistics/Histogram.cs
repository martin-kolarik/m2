using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MouseAnalyzer.Statistics
{
    public class HistogramDefinition
    {
        public enum BinCreationStrategy
        {
            Auto,
            Sparse,
            Predefined
        }

        public BinCreationStrategy Strategy
        {
            get;
            private set;
        }
        public int Bins
        {
            get;
            private set;
        }
        public double[] BinMidpoints
        {
            get;
            private set;
        }
        public double BinWidth
        {
            get;
            private set;
        }

        public HistogramDefinition( int bins )
        {
            Strategy = HistogramDefinition.BinCreationStrategy.Auto;
            Bins = bins;
        }

        public HistogramDefinition( double firstBinMidpoint, double binMidpointSpread, double binWidth, double stopBinMidpoint = double.MaxValue )
        {
            Strategy = HistogramDefinition.BinCreationStrategy.Sparse;
            BinWidth = binWidth;
            BinMidpoints = new double[] { firstBinMidpoint, binMidpointSpread, stopBinMidpoint }; // ugly
        }

        public HistogramDefinition( IEnumerable<double> binMidpoints, double binWidth )
        {
            Strategy = HistogramDefinition.BinCreationStrategy.Predefined;
            Bins = binMidpoints.Count();
            BinWidth = binWidth;
            BinMidpoints = binMidpoints.ToArray();
        }

        public void SupplyRange( double from, double to )
        {
            if( Strategy == HistogramDefinition.BinCreationStrategy.Auto )
            {
                BinWidth = ( to - from ) / Bins;
                BinMidpoints = new double[Bins];
                for( var bin = 0; bin < Bins; ++bin )
                {
                    BinMidpoints[bin] = from + ( bin+0.5 ) * BinWidth;
                }
            }
            else if( Strategy == HistogramDefinition.BinCreationStrategy.Sparse )
            {
                var firstBinMidpoint = BinMidpoints[0]; // ugly
                var binMidpointSpread = BinMidpoints[1];
                var stopBinMidpoint = BinMidpoints[2];
                Bins = (int)( ( stopBinMidpoint - firstBinMidpoint ) / binMidpointSpread ) + 1;
                BinMidpoints = new double[Bins];
                for( var bin = 0; bin < Bins; bin++ )
                {
                    BinMidpoints[bin] = firstBinMidpoint + binMidpointSpread * bin;
                }
            }
        }
    }

    class Histogram
    {
        public int Bins
        {
            get
            {
                return definition.Bins;
            }
        }

        public double[] BinMidpoints
        {
            get
            {
                return definition.BinMidpoints;
            }
        }

        public double BinWidth
        {
            get
            {
                return definition.BinWidth;
            }
        }

        public int[] Frequencies
        {
            get
            {
                return frequencies;
            }
        }

        public Histogram( HistogramDefinition definition, IEnumerable<double> values, double? min = null, double? max = null )
        {
            this.definition = definition;
            this.frequencies = new int[definition.Bins];

            var from = min.HasValue ? min.Value : values.Where( v => !double.IsNegativeInfinity( v ) ).Min();
            var to = max.HasValue ? max.Value : values.Where( v => !double.IsPositiveInfinity( v ) ).Max();

            if( definition.Strategy == HistogramDefinition.BinCreationStrategy.Auto )
            {
                var range = to - from;
                foreach( var item in values )
                {
                    int bin = definition.Bins-1;
                    if( range==0.0 )
                    {
                        // fall down
                    }
                    else if( double.IsNegativeInfinity( item ) )
                    {
                        bin = 0;
                    }
                    else if( double.IsPositiveInfinity( item ) )
                    {
                        // fall down
                    }
                    else
                    {
                        bin = (int)( definition.Bins*( item-from )/range );
                        bin = bin==definition.Bins ? --bin : bin;
                    }
                    ++frequencies[bin];
                }
            }
            else
            {
                var halfWidth = definition.BinWidth / 2.0;
                foreach( var item in values )
                {
                    var bin = 0;
                    foreach( var midpoint in definition.BinMidpoints )
                    {
                        if( item >= midpoint - halfWidth && item <= midpoint + halfWidth )
                        {
                            ++frequencies[bin];
                            break;
                        }
                        ++bin;
                    }
                }
            }
        }

        private HistogramDefinition definition;
        private int[] frequencies;
    }
}
