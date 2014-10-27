using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using MouseAnalyzer.Statistics;

namespace MouseAnalyzer
{
    static class StrokeFeatureDefinition
    {
        public static bool SPLIT = true;
        public static bool TRANSFORMED = true;

        public enum DataTransform
        {
            None,
            Log,
            HyperLog,
            IHS
        }

        public class MarkerGroupDefinition
        {
            public string Name { get; private set; }
            public bool SplitSigns { get; private set; }
            public bool SplitZero { get; private set; }
            public DataTransform DataTransform { get; private set; }

            public MarkerGroupDefinition( string name, DataTransform transform = DataTransform.None, bool splitSigns = false, bool splitZero = false, double multiplier = 1.0, double auxCoeffA = 1.0, double auxCoeffB = 1.0 )
            {
                Name = name;
                SplitSigns = SPLIT && splitSigns;
                SplitZero = SPLIT && splitZero;
                DataTransform = TRANSFORMED ? transform : DataTransform.None;
                this.multiplier = multiplier;
                this.auxCoeffA = auxCoeffA;
                this.auxCoeffB = auxCoeffB;
            }

            public double Transform( double input )
            {
                double value = input * multiplier;
                switch( DataTransform )
                {
                    case DataTransform.Log:
                        return value <= 0.0 ? 0.0 : Math.Log( value );
                    case DataTransform.HyperLog:
                        return HyperLog.f( value, auxCoeffA, auxCoeffB );
                    case DataTransform.IHS:
                        return Math.Log( value + Math.Sqrt( value*value + 1 ) );
                    case DataTransform.None:
                    default:
                        return value;
                }
            }

            public IEnumerable<double> Transform( IEnumerable<double> input )
            {
                switch( DataTransform )
                {
                    case DataTransform.Log:
                        return input.Select( d => d <= 0.0 ? 0.0 : Math.Log( d * multiplier ) );
                    case DataTransform.HyperLog:
                        return input.Select( d => HyperLog.f( d * multiplier, auxCoeffA, auxCoeffB ) );
                    case DataTransform.IHS:
                        return input.Select( d =>
                        {
                            d = d * multiplier;
                            d = d + Math.Sqrt( d*d + 1 );
                            return Math.Log( d );
                        } );
                    case DataTransform.None:
                    default:
                        return input.Select( d => d * multiplier );
                }
            }

            private double multiplier = 1.0;
            private double auxCoeffA = 1.0;
            private double auxCoeffB = 1.0;
        }

        public class MarkerDefinition
        {
            public MarkerDefinition( MarkerGroupDefinition of, string name, DistributionType distribution, bool histogram = false ) :
                this( of, name, distribution, distribution, distribution, histogram )
            {
            }

            public MarkerDefinition( MarkerGroupDefinition of, string name, DistributionType distribution, DistributionType distributionForSplittedAndTransformed, bool histogram = false ) :
                this( of, name, distribution, distributionForSplittedAndTransformed, distributionForSplittedAndTransformed, histogram )
            {
            }

            public MarkerDefinition( MarkerGroupDefinition of, string name, DistributionType distribution, DistributionType distributionForSplitted, DistributionType distributionForTransformed, bool histogram = false )
            {
                this.of = of;
                HasPositives = true;
                if( of.SplitSigns )
                {
                    HasNegatives = true;
                    PositiveName = of.Name + "+" + ( name=="" ? "" : "." + name );
                    NegativeName = of.Name + "-" + ( name=="" ? "" : "." + name );
                }
                else
                {
                    HasNegatives = false;
                    PositiveName = of.Name + ( name=="" ? "" : "." + name );
                }

                this.distribution = distribution;
                this.distributionForSplitted = distributionForSplitted;
                this.distributionForTransformed = distributionForTransformed;
                this.histogram = histogram;
            }

            public MarkerDefinition( MarkerGroupDefinition of, DistributionType distribution, bool histogram = false ) // for zeros
            {
                this.of = of;
                HasPositives = true;
                HasNegatives = false;
                PositiveName = of.Name + ".0";

                this.distribution = distribution;
                this.distributionForSplitted = distribution;
                this.distributionForTransformed = distribution;
                this.histogram = histogram;
            }

            public bool HasPositives { get; private set; }
            public bool HasNegatives { get; private set; }
            public string PositiveName { get; private set; }
            public string NegativeName { get; private set; }
            public DataTransform DataTransform { get { return of.DataTransform; } }
            public HistogramDefinition HistogramDefinition
            {
                get
                {
                    return histogram ? new HistogramDefinition( 200 ) : null;;
                }
            }

            public DistributionType Distribution
            {
                get
                {
                    if( DataTransform != DataTransform.None )
                    {
                        return distributionForTransformed;
                    }
                    else if( of.SplitSigns )
                    {
                        return distributionForSplitted;
                    }
                    else
                    {
                        return distribution;
                    }
                }
            }

            private MarkerGroupDefinition of;
            private DistributionType distribution;
            private DistributionType distributionForSplitted;
            private DistributionType distributionForTransformed;
            private bool histogram = false;
        }

        public static MarkerGroupDefinition Group( string name )
        {
            MarkerGroupDefinition value;
            return groups.TryGetValue( name, out value ) ? value : null;
        }

        public static MarkerDefinition Marker( string name )
        {
            {
                return markers[name];
            }
        }

        public static IEnumerable<MarkerDefinition> Markers
        {
            get
            {
                return markers.Values;
            }
        }

        static StrokeFeatureDefinition()
        {
            const bool SPLINE = false;

            MarkerGroupDefinition grp;

            if( SPLINE )
            {

            }
            else
            {
                //+@@@@@
                Add( new MarkerDefinition( Add( new MarkerGroupDefinition( "Si", DataTransform.Log ) ), "", DistributionType.None ) ); //**S!!

                grp = Add( new MarkerGroupDefinition( "rSi" ) ); //+@@@@@
                Add( new MarkerDefinition( grp, "A0", DistributionType.Lognormal ) ); //S**-
                Add( new MarkerDefinition( grp, "A2", DistributionType.Gaussian ) );
                Add( new MarkerDefinition( grp, "A4", DistributionType.None ) ); // always 1
                Add( new MarkerDefinition( grp, "AD", DistributionType.Weibull ) );
                Add( new MarkerDefinition( grp, "AS", DistributionType.None ) ); // shall always be 1
                Add( new MarkerDefinition( grp, "L0", DistributionType.Lognormal ) ); //S**-
                Add( new MarkerDefinition( grp, "L2", DistributionType.Gamma ) );
                Add( new MarkerDefinition( grp, "L4", DistributionType.Gamma ) ); //S**-
                Add( new MarkerDefinition( grp, "LD", DistributionType.Gamma ) ); //S**-
                Add( new MarkerDefinition( grp, "LS", DistributionType.Gamma ) );
                Add( new MarkerDefinition( grp, "M0", DistributionType.Gaussian ) ); //S**-
                Add( new MarkerDefinition( grp, "M2", DistributionType.Logistic ) ); //S**-
                Add( new MarkerDefinition( grp, "M4", DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "MD", DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "MS", DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "H0", DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "H2", DistributionType.Weibull ) ); //**S
                Add( new MarkerDefinition( grp, "H4", DistributionType.None ) ); // always 1
                Add( new MarkerDefinition( grp, "HD", DistributionType.Gamma ) ); //**S
                Add( new MarkerDefinition( grp, "HS", DistributionType.Weibull ) ); //**S

                //+@@@@@
                Add( new MarkerDefinition( Add( new MarkerGroupDefinition( "Ti", DataTransform.Log ) ), "", DistributionType.None ) ); //**S!!

                grp = Add( new MarkerGroupDefinition( "CSi", DataTransform.Log, true, true ) ); //+@@@@@
                Add( new MarkerDefinition( grp, DistributionType.None ) );
                Add( new MarkerDefinition( grp, "", DistributionType.Logistic ) ); //S**

                //+@@@@@
                Add( new MarkerDefinition( Add( new MarkerGroupDefinition( "Sd", DataTransform.Log ) ), "", DistributionType.Gaussian ) ); //**S!
                Add( new MarkerDefinition( Add( new MarkerGroupDefinition( "Vd", DataTransform.Log ) ), "", DistributionType.Gaussian ) ); //**S-

                //+@@@@@
                Add( new MarkerDefinition( Add( new MarkerGroupDefinition( "St", DataTransform.Log ) ), "", DistributionType.Gaussian ) ); //****FRED

                //+@@@@@
                Add( new MarkerDefinition( Add( new MarkerGroupDefinition( "Ji", DataTransform.Log ) ), "", DistributionType.Weibull ) ); //**S

                grp = Add( new MarkerGroupDefinition( "X", DataTransform.Log ) ); //+@@@@@
                // Add( new MarkerDefinition( grp, "A0", DistributionType.Gaussian, true ) );
                Add( new MarkerDefinition( grp, "A2", DistributionType.Lognormal, DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "A4", DistributionType.Lognormal, DistributionType.Logistic ) ); //**S!
                Add( new MarkerDefinition( grp, "AD", DistributionType.Lognormal, DistributionType.None ) ); //**S!!
                Add( new MarkerDefinition( grp, "AS", DistributionType.Lognormal, DistributionType.Gaussian ) ); //**S!

                grp = Add( new MarkerGroupDefinition( "Y", DataTransform.Log ) ); //+@@@@@
                // Add( new MarkerDefinition( grp, "A0", DistributionType.Gaussian ) );
                Add( new MarkerDefinition( grp, "A2", DistributionType.Lognormal, DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "A4", DistributionType.Lognormal, DistributionType.Gaussian ) );
                Add( new MarkerDefinition( grp, "AD", DistributionType.Lognormal, DistributionType.None ) ); //**S!!
                Add( new MarkerDefinition( grp, "AS", DistributionType.Lognormal, DistributionType.Gaussian ) );

                grp = Add( new MarkerGroupDefinition( "Cs", DataTransform.Log, true, true ) ); //X@@@@@
                Add( new MarkerDefinition( grp, DistributionType.None ) );
                Add( new MarkerDefinition( grp, "A0", DistributionType.None, DistributionType.Gaussian ) );
                Add( new MarkerDefinition( grp, "A2", DistributionType.Logistic, DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "A4", DistributionType.None, DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "AD", DistributionType.Gamma, DistributionType.Logistic ) );
                Add( new MarkerDefinition( grp, "AS", DistributionType.None, DistributionType.Logistic ) );
                Add( new MarkerDefinition( grp, "L0", DistributionType.None, DistributionType.Gaussian ) );
                Add( new MarkerDefinition( grp, "L2", DistributionType.Logistic, DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "L4", DistributionType.None, DistributionType.Gaussian ) ); //**S-
                Add( new MarkerDefinition( grp, "LD", DistributionType.None, DistributionType.Weibull ) );
                Add( new MarkerDefinition( grp, "LS", DistributionType.None, DistributionType.Weibull ) );
                Add( new MarkerDefinition( grp, "M0", DistributionType.None, DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "M2", DistributionType.Logistic, DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "M4", DistributionType.None, DistributionType.Gaussian ) ); //**S (rud)
                Add( new MarkerDefinition( grp, "MD", DistributionType.None, DistributionType.Rayleigh ) ); //**S
                Add( new MarkerDefinition( grp, "MS", DistributionType.None, DistributionType.Weibull ) ); //**S!
                Add( new MarkerDefinition( grp, "H0", DistributionType.None, DistributionType.Gaussian ) );
                Add( new MarkerDefinition( grp, "H2", DistributionType.Logistic, DistributionType.Gaussian ) );
                Add( new MarkerDefinition( grp, "H4", DistributionType.None, DistributionType.Gaussian ) );
                Add( new MarkerDefinition( grp, "HD", DistributionType.None, DistributionType.Gamma ) ); //**S-
                Add( new MarkerDefinition( grp, "HS", DistributionType.None, DistributionType.Weibull ) ); //**S-

                grp = Add( new MarkerGroupDefinition( "dCs", DataTransform.Log, true, true ) ); //+@@@@@
                Add( new MarkerDefinition( grp, DistributionType.None ) );
                Add( new MarkerDefinition( grp, "A0", DistributionType.None, DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "A2", DistributionType.Logistic, DistributionType.Gaussian ) ); //**S-
                Add( new MarkerDefinition( grp, "A4", DistributionType.None, DistributionType.Logistic ) ); //**S
                Add( new MarkerDefinition( grp, "AD", DistributionType.Gamma, DistributionType.None ) ); //**S!!
                Add( new MarkerDefinition( grp, "AS", DistributionType.None, DistributionType.Logistic ) ); //**S
                Add( new MarkerDefinition( grp, "L0", DistributionType.None, DistributionType.Gaussian ) );
                Add( new MarkerDefinition( grp, "L2", DistributionType.Logistic ) ); //**S!
                Add( new MarkerDefinition( grp, "L4", DistributionType.None, DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "LD", DistributionType.None, DistributionType.None ) ); //**S!!
                Add( new MarkerDefinition( grp, "LS", DistributionType.None, DistributionType.None ) ); //**S!!
                Add( new MarkerDefinition( grp, "M0", DistributionType.None, DistributionType.Gaussian ) ); //**S (rud)
                Add( new MarkerDefinition( grp, "M2", DistributionType.Logistic, DistributionType.Gaussian ) ); //**S! (rud)
                Add( new MarkerDefinition( grp, "M4", DistributionType.None, DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "MD", DistributionType.None, DistributionType.Rayleigh ) );
                Add( new MarkerDefinition( grp, "MS", DistributionType.None, DistributionType.Rayleigh ) ); //**S
                Add( new MarkerDefinition( grp, "H0", DistributionType.None, DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "H2", DistributionType.Logistic, DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "H4", DistributionType.None, DistributionType.Gaussian ) ); //**S-
                Add( new MarkerDefinition( grp, "HD", DistributionType.None, DistributionType.None ) ); //**S!!
                Add( new MarkerDefinition( grp, "HS", DistributionType.None, DistributionType.None ) ); //**S!!

                grp = Add( new MarkerGroupDefinition( "V", DataTransform.Log ) ); //+@@@@@
                Add( new MarkerDefinition( grp, "A0", DistributionType.Gaussian, DistributionType.Logistic ) ); //**S?
                Add( new MarkerDefinition( grp, "A2", DistributionType.Lognormal, DistributionType.Gaussian ) );
                Add( new MarkerDefinition( grp, "A4", DistributionType.Lognormal, DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "AD", DistributionType.Lognormal, DistributionType.Gamma ) );
                Add( new MarkerDefinition( grp, "AS", DistributionType.Lognormal, DistributionType.Gamma ) ); //S**?
                Add( new MarkerDefinition( grp, "L0", DistributionType.Gaussian ) ); //S**
                Add( new MarkerDefinition( grp, "L2", DistributionType.Lognormal, DistributionType.Gaussian ) );
                Add( new MarkerDefinition( grp, "L4", DistributionType.Lognormal, DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "LD", DistributionType.Gaussian, DistributionType.Weibull ) ); //**S
                Add( new MarkerDefinition( grp, "LS", DistributionType.None, DistributionType.Gamma ) ); //**S
                Add( new MarkerDefinition( grp, "M0", DistributionType.Lognormal, DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "M2", DistributionType.Lognormal, DistributionType.Gaussian ) ); //**S!
                Add( new MarkerDefinition( grp, "M4", DistributionType.Lognormal, DistributionType.Gaussian ) ); //**S!
                Add( new MarkerDefinition( grp, "MD", DistributionType.Lognormal, DistributionType.Gamma ) ); //**S?
                Add( new MarkerDefinition( grp, "MS", DistributionType.Gaussian, DistributionType.Gamma ) ); //**S?
                Add( new MarkerDefinition( grp, "H0", DistributionType.None, DistributionType.Logistic ) ); //**S
                Add( new MarkerDefinition( grp, "H2", DistributionType.Lognormal, DistributionType.Gaussian ) );
                Add( new MarkerDefinition( grp, "H4", DistributionType.None, DistributionType.Gaussian ) ); //**S!
                Add( new MarkerDefinition( grp, "HD", DistributionType.None, DistributionType.Weibull ) ); //**S
                Add( new MarkerDefinition( grp, "HS", DistributionType.None, DistributionType.Gamma ) ); //**S!

                grp = Add( new MarkerGroupDefinition( "dV", DataTransform.Log, true, true ) ); //+@@@@@
                Add( new MarkerDefinition( grp, DistributionType.None ) );
                Add( new MarkerDefinition( grp, "A0", DistributionType.Logistic, DistributionType.Logistic ) ); //S**
                Add( new MarkerDefinition( grp, "A2", DistributionType.Logistic, DistributionType.Logistic ) ); //S**-
                Add( new MarkerDefinition( grp, "A4", DistributionType.Gaussian, DistributionType.Logistic ) ); //S**-
                Add( new MarkerDefinition( grp, "AD", DistributionType.Gaussian, DistributionType.None ) ); //S**!!
                Add( new MarkerDefinition( grp, "AS", DistributionType.Weibull, DistributionType.None ) ); //S**!!
                Add( new MarkerDefinition( grp, "L0", DistributionType.Gaussian, DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "L2", DistributionType.Gaussian, DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "L4", DistributionType.Logistic, DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "LD", DistributionType.Gaussian, DistributionType.None ) ); //**S!!
                Add( new MarkerDefinition( grp, "LS", DistributionType.Logistic, DistributionType.None ) ); //**S!!
                Add( new MarkerDefinition( grp, "M0", DistributionType.None, DistributionType.None ) ); //**S!!
                Add( new MarkerDefinition( grp, "M2", DistributionType.Logistic, DistributionType.Gaussian ) ); //**S!
                Add( new MarkerDefinition( grp, "M4", DistributionType.None, DistributionType.Logistic ) );
                Add( new MarkerDefinition( grp, "MD", DistributionType.None ) ); //**S!!
                Add( new MarkerDefinition( grp, "MS", DistributionType.None ) ); //**S!!
                Add( new MarkerDefinition( grp, "H0", DistributionType.None, DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "H2", DistributionType.Logistic, DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "H4", DistributionType.None, DistributionType.Logistic ) ); //**S
                Add( new MarkerDefinition( grp, "HD", DistributionType.None, DistributionType.None ) ); //**S!!
                Add( new MarkerDefinition( grp, "HS", DistributionType.None, DistributionType.Gamma ) ); //**S

                grp = Add( new MarkerGroupDefinition( "d2V", DataTransform.Log, true, true ) ); //+@@@@@
                Add( new MarkerDefinition( grp, DistributionType.None ) );
                Add( new MarkerDefinition( grp, "A0", DistributionType.None, DistributionType.Gaussian ) );
                Add( new MarkerDefinition( grp, "A2", DistributionType.Logistic, DistributionType.Gaussian ) );
                Add( new MarkerDefinition( grp, "A4", DistributionType.None, DistributionType.Gaussian ) ); //**S-
                Add( new MarkerDefinition( grp, "AD", DistributionType.Weibull, DistributionType.Logistic ) ); //**S-
                Add( new MarkerDefinition( grp, "AS", DistributionType.Gamma ) ); //**S
                Add( new MarkerDefinition( grp, "L0", DistributionType.None, DistributionType.Gaussian ) ); //**S-
                Add( new MarkerDefinition( grp, "L2", DistributionType.Gaussian ) );
                Add( new MarkerDefinition( grp, "L4", DistributionType.None, DistributionType.Gaussian ) ); //**S-
                Add( new MarkerDefinition( grp, "LD", DistributionType.None, DistributionType.Weibull ) ); //**S
                Add( new MarkerDefinition( grp, "LS", DistributionType.None, DistributionType.Weibull ) ); //**S
                Add( new MarkerDefinition( grp, "M0", DistributionType.None, DistributionType.Gaussian ) ); //**s
                Add( new MarkerDefinition( grp, "M2", DistributionType.Gaussian ) ); //**S-
                Add( new MarkerDefinition( grp, "M4", DistributionType.None, DistributionType.Gaussian ) ); //**S-
                Add( new MarkerDefinition( grp, "MD", DistributionType.Weibull, DistributionType.Rayleigh ) ); //**S!
                Add( new MarkerDefinition( grp, "MS", DistributionType.None, DistributionType.None ) );  //**S!!
                Add( new MarkerDefinition( grp, "H0", DistributionType.None, DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "H2", DistributionType.Gaussian ) ); //**S-
                Add( new MarkerDefinition( grp, "H4", DistributionType.None, DistributionType.Gaussian ) ); //**S-
                Add( new MarkerDefinition( grp, "HD", DistributionType.None, DistributionType.Weibull ) ); //**S!
                Add( new MarkerDefinition( grp, "HS", DistributionType.None, DistributionType.None ) ); //**S!!

                grp = Add( new MarkerGroupDefinition( "Vn", DataTransform.Log, true, true ) ); //+@@@@@
                Add( new MarkerDefinition( grp, DistributionType.None ) );
                Add( new MarkerDefinition( grp, "A0", DistributionType.Logistic ) ); //S**
                Add( new MarkerDefinition( grp, "A2", DistributionType.Logistic ) ); //S**
                Add( new MarkerDefinition( grp, "A4", DistributionType.Logistic ) ); //S**
                Add( new MarkerDefinition( grp, "AD", DistributionType.Rayleigh ) ); //S**
                Add( new MarkerDefinition( grp, "AS", DistributionType.Rayleigh ) ); //S**
                Add( new MarkerDefinition( grp, "L0", DistributionType.Logistic ) ); //S**-
                Add( new MarkerDefinition( grp, "L2", DistributionType.Logistic ) ); //S**-
                Add( new MarkerDefinition( grp, "L4", DistributionType.Logistic ) ); //S**-
                Add( new MarkerDefinition( grp, "LD", DistributionType.Rayleigh ) ); //S**
                Add( new MarkerDefinition( grp, "LS", DistributionType.Weibull ) ); //S**
                Add( new MarkerDefinition( grp, "M0", DistributionType.Logistic ) ); //S**!
                Add( new MarkerDefinition( grp, "M2", DistributionType.Logistic ) ); //S**!
                Add( new MarkerDefinition( grp, "M4", DistributionType.Logistic ) ); //S**
                Add( new MarkerDefinition( grp, "MD", DistributionType.Weibull ) ); //S**
                Add( new MarkerDefinition( grp, "MS", DistributionType.Weibull ) ); //S**
                Add( new MarkerDefinition( grp, "H0", DistributionType.Logistic ) ); //S**
                Add( new MarkerDefinition( grp, "H2", DistributionType.Logistic ) ); //S**
                Add( new MarkerDefinition( grp, "H4", DistributionType.Logistic ) ); //S**
                Add( new MarkerDefinition( grp, "HD", DistributionType.Weibull ) ); //S**!
                Add( new MarkerDefinition( grp, "HS", DistributionType.Weibull ) ); //S**!

                grp = Add( new MarkerGroupDefinition( "Vfi", DataTransform.Log, true ) ); //+@@@@@
                Add( new MarkerDefinition( grp, "A0", DistributionType.Logistic ) );
                Add( new MarkerDefinition( grp, "A2", DistributionType.Logistic ) );
                Add( new MarkerDefinition( grp, "A4", DistributionType.Logistic ) );
                Add( new MarkerDefinition( grp, "AD", DistributionType.Rayleigh ) );
                Add( new MarkerDefinition( grp, "AS", DistributionType.Rayleigh ) );
                Add( new MarkerDefinition( grp, "L0", DistributionType.Logistic ) );
                Add( new MarkerDefinition( grp, "L2", DistributionType.Logistic ) );
                Add( new MarkerDefinition( grp, "L4", DistributionType.Logistic ) );
                Add( new MarkerDefinition( grp, "LD", DistributionType.Weibull ) ); //S**!
                Add( new MarkerDefinition( grp, "LS", DistributionType.Weibull ) );
                Add( new MarkerDefinition( grp, "M0", DistributionType.Logistic ) ); //S**
                Add( new MarkerDefinition( grp, "M2", DistributionType.Logistic ) );
                Add( new MarkerDefinition( grp, "M4", DistributionType.Logistic ) );
                Add( new MarkerDefinition( grp, "MD", DistributionType.Weibull ) ); //S**
                Add( new MarkerDefinition( grp, "MS", DistributionType.Weibull ) ); //S**-
                Add( new MarkerDefinition( grp, "H0", DistributionType.Logistic ) );
                Add( new MarkerDefinition( grp, "H2", DistributionType.Logistic ) ); //S**-
                Add( new MarkerDefinition( grp, "H4", DistributionType.Logistic ) ); //S**
                Add( new MarkerDefinition( grp, "HD", DistributionType.Weibull ) ); //S**
                Add( new MarkerDefinition( grp, "HS", DistributionType.Weibull ) ); //S**-

                grp = Add( new MarkerGroupDefinition( "W", DataTransform.Log, true, true ) ); //+@@@@@
                Add( new MarkerDefinition( grp, DistributionType.None ) );
                Add( new MarkerDefinition( grp, "A0", DistributionType.None, DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "A2", DistributionType.Logistic, DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "A4", DistributionType.None, DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "AD", DistributionType.Lognormal, DistributionType.Logistic ) ); //**S
                Add( new MarkerDefinition( grp, "AS", DistributionType.Lognormal, DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "L0", DistributionType.None, DistributionType.Gaussian ) );
                Add( new MarkerDefinition( grp, "L2", DistributionType.Logistic, DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "L4", DistributionType.None, DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "LD", DistributionType.Weibull, DistributionType.Weibull ) ); //**S-
                Add( new MarkerDefinition( grp, "LS", DistributionType.Weibull, DistributionType.Weibull ) );
                Add( new MarkerDefinition( grp, "M0", DistributionType.None, DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "M2", DistributionType.Logistic, DistributionType.None ) ); //**S!!
                Add( new MarkerDefinition( grp, "M4", DistributionType.None, DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "MD", DistributionType.Gamma, DistributionType.Rayleigh ) ); //**S
                Add( new MarkerDefinition( grp, "MS", DistributionType.Weibull, DistributionType.Weibull ) ); //**S
                Add( new MarkerDefinition( grp, "H0", DistributionType.None, DistributionType.Gaussian ) );
                Add( new MarkerDefinition( grp, "H2", DistributionType.Logistic, DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "H4", DistributionType.None, DistributionType.Gaussian ) );
                Add( new MarkerDefinition( grp, "HD", DistributionType.Lognormal, DistributionType.Weibull ) ); //**S
                Add( new MarkerDefinition( grp, "HS", DistributionType.Lognormal, DistributionType.Weibull ) );

                grp = Add( new MarkerGroupDefinition( "dW", DataTransform.Log, true, true ) ); //+@@@@@
                Add( new MarkerDefinition( grp, DistributionType.None ) );
                Add( new MarkerDefinition( grp, "A0", DistributionType.None, DistributionType.Gaussian ) );
                Add( new MarkerDefinition( grp, "A2", DistributionType.Logistic, DistributionType.Gaussian ) );
                Add( new MarkerDefinition( grp, "A4", DistributionType.None, DistributionType.None ) ); //**S!!
                Add( new MarkerDefinition( grp, "AD", DistributionType.Lognormal, DistributionType.Logistic ) ); //**S (unclear shape)
                Add( new MarkerDefinition( grp, "AS", DistributionType.Lognormal, DistributionType.Logistic ) ); //**S! (unclear shape)
                Add( new MarkerDefinition( grp, "L0", DistributionType.Gaussian, DistributionType.Gaussian ) );
                Add( new MarkerDefinition( grp, "L2", DistributionType.Logistic, DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "L4", DistributionType.Gaussian, DistributionType.None ) ); //**S!!
                Add( new MarkerDefinition( grp, "LD", DistributionType.None, DistributionType.Rayleigh ) ); //**S!
                Add( new MarkerDefinition( grp, "LS", DistributionType.None, DistributionType.None ) ); //**S!!
                Add( new MarkerDefinition( grp, "M0", DistributionType.None, DistributionType.Gaussian ) ); //**S!
                Add( new MarkerDefinition( grp, "M2", DistributionType.Logistic, DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "M4", DistributionType.None, DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "MD", DistributionType.Lognormal, DistributionType.None ) ); //**S!!
                Add( new MarkerDefinition( grp, "MS", DistributionType.Lognormal, DistributionType.Rayleigh ) );
                Add( new MarkerDefinition( grp, "H0", DistributionType.None, DistributionType.Gaussian ) );
                Add( new MarkerDefinition( grp, "H2", DistributionType.Logistic, DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "H4", DistributionType.None, DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "HD", DistributionType.Lognormal, DistributionType.Rayleigh ) ); //**S
                Add( new MarkerDefinition( grp, "HS", DistributionType.Lognormal, DistributionType.None ) ); //**S!!

                grp = Add( new MarkerGroupDefinition( "Ca", DataTransform.Log, true, true ) ); //+@@@@@
                Add( new MarkerDefinition( grp, DistributionType.None ) );
                Add( new MarkerDefinition( grp, "A0", DistributionType.None, DistributionType.Gaussian ) );
                Add( new MarkerDefinition( grp, "A2", DistributionType.Logistic, DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "A4", DistributionType.None, DistributionType.None ) ); //**S!!
                Add( new MarkerDefinition( grp, "AD", DistributionType.Gamma, DistributionType.Logistic ) ); //**S-
                Add( new MarkerDefinition( grp, "AS", DistributionType.Gamma, DistributionType.Gaussian ) );
                Add( new MarkerDefinition( grp, "L0", DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "L2", DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "L4", DistributionType.Gaussian ) ); //**S!
                Add( new MarkerDefinition( grp, "LD", DistributionType.None, DistributionType.None ) ); //**S!!
                Add( new MarkerDefinition( grp, "LS", DistributionType.None, DistributionType.None ) ); //**S!!
                Add( new MarkerDefinition( grp, "M0", DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "M2", DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "M4", DistributionType.Gaussian ) ); //**S!
                Add( new MarkerDefinition( grp, "MD", DistributionType.Gamma, DistributionType.Logistic ) ); //**S
                Add( new MarkerDefinition( grp, "MS", DistributionType.None, DistributionType.Rayleigh ) ); //**S
                Add( new MarkerDefinition( grp, "H0", DistributionType.Gaussian ) ); //**S!
                Add( new MarkerDefinition( grp, "H2", DistributionType.Logistic, DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "H4", DistributionType.Gaussian ) ); //**S!
                Add( new MarkerDefinition( grp, "HD", DistributionType.Gamma, DistributionType.None ) ); //**S!!
                Add( new MarkerDefinition( grp, "HS", DistributionType.None, DistributionType.None ) ); //**S!!

                grp = Add( new MarkerGroupDefinition( "A", DataTransform.Log ) ); //+@@@@@
                Add( new MarkerDefinition( grp, "A0", DistributionType.Gaussian ) );
                Add( new MarkerDefinition( grp, "A2", DistributionType.Lognormal, DistributionType.Gaussian ) );
                Add( new MarkerDefinition( grp, "A4", DistributionType.Lognormal, DistributionType.Gaussian ) );
                Add( new MarkerDefinition( grp, "AD", DistributionType.Lognormal ) );
                Add( new MarkerDefinition( grp, "AS", DistributionType.Gamma ) );
                Add( new MarkerDefinition( grp, "L0", DistributionType.Gaussian ) );
                Add( new MarkerDefinition( grp, "L2", DistributionType.Gaussian ) );
                Add( new MarkerDefinition( grp, "L4", DistributionType.Gaussian ) );
                Add( new MarkerDefinition( grp, "LD", DistributionType.None ) ); //S**!!
                Add( new MarkerDefinition( grp, "LS", DistributionType.Lognormal, DistributionType.None ) ); //S**!!
                Add( new MarkerDefinition( grp, "M0", DistributionType.Gaussian ) );
                Add( new MarkerDefinition( grp, "M2", DistributionType.Gaussian ) );
                Add( new MarkerDefinition( grp, "M4", DistributionType.Gaussian ) ); //S**- some 
                Add( new MarkerDefinition( grp, "MD", DistributionType.Gamma ) ); //S**
                Add( new MarkerDefinition( grp, "MS", DistributionType.Gamma ) );
                Add( new MarkerDefinition( grp, "H0", DistributionType.Gaussian ) );
                Add( new MarkerDefinition( grp, "H2", DistributionType.Gaussian ) );
                Add( new MarkerDefinition( grp, "H4", DistributionType.Gaussian ) );
                Add( new MarkerDefinition( grp, "HD", DistributionType.None ) ); //S**!!
                Add( new MarkerDefinition( grp, "HS", DistributionType.Weibull ) ); //S**

                grp = Add( new MarkerGroupDefinition( "An", DataTransform.Log, true, true ) ); //+@@@@@
                Add( new MarkerDefinition( grp, DistributionType.None ) );
                Add( new MarkerDefinition( grp, "A0", DistributionType.None, DistributionType.Logistic ) ); //S** positives
                Add( new MarkerDefinition( grp, "A2", DistributionType.Logistic, DistributionType.Logistic ) ); //S** positives
                Add( new MarkerDefinition( grp, "A4", DistributionType.Weibull, DistributionType.Logistic ) ); //S** positive
                Add( new MarkerDefinition( grp, "AD", DistributionType.Weibull, DistributionType.Gamma ) ); //S**!
                Add( new MarkerDefinition( grp, "AS", DistributionType.Weibull, DistributionType.Gamma ) ); //S**!
                Add( new MarkerDefinition( grp, "L0", DistributionType.None, DistributionType.Gaussian ) ); //S**!
                Add( new MarkerDefinition( grp, "L2", DistributionType.Logistic, DistributionType.Logistic ) ); //S**! positives
                Add( new MarkerDefinition( grp, "L4", DistributionType.Weibull, DistributionType.Logistic ) ); //S**! positives
                Add( new MarkerDefinition( grp, "LD", DistributionType.Weibull, DistributionType.None ) ); //S**!!
                Add( new MarkerDefinition( grp, "LS", DistributionType.Weibull, DistributionType.None ) ); //S**!!
                Add( new MarkerDefinition( grp, "M0", DistributionType.None, DistributionType.Logistic ) ); //S** positives
                Add( new MarkerDefinition( grp, "M2", DistributionType.Logistic, DistributionType.Logistic ) ); //S** positives
                Add( new MarkerDefinition( grp, "M4", DistributionType.None, DistributionType.Logistic ) ); //S** positives
                Add( new MarkerDefinition( grp, "MD", DistributionType.Weibull, DistributionType.Rayleigh ) ); //S**
                Add( new MarkerDefinition( grp, "MS", DistributionType.Weibull, DistributionType.Weibull ) ); //S**
                Add( new MarkerDefinition( grp, "H0", DistributionType.None, DistributionType.Logistic ) ); //S**
                Add( new MarkerDefinition( grp, "H2", DistributionType.Logistic, DistributionType.Logistic ) ); //S**!
                Add( new MarkerDefinition( grp, "H4", DistributionType.Logistic, DistributionType.Logistic ) );
                Add( new MarkerDefinition( grp, "HD", DistributionType.Weibull, DistributionType.Logistic ) ); //S**!
                Add( new MarkerDefinition( grp, "HS", DistributionType.Weibull, DistributionType.None ) ); //S**!!

                grp = Add( new MarkerGroupDefinition( "Afi", DataTransform.Log, true, true ) ); //+@@@@@
                Add( new MarkerDefinition( grp, DistributionType.None ) );
                Add( new MarkerDefinition( grp, "A0", DistributionType.None, DistributionType.Gaussian ) );
                Add( new MarkerDefinition( grp, "A2", DistributionType.None, DistributionType.Gaussian ) ); //S**-
                Add( new MarkerDefinition( grp, "A4", DistributionType.None, DistributionType.Gaussian ) );
                Add( new MarkerDefinition( grp, "AD", DistributionType.None, DistributionType.Logistic ) ); //S**!
                Add( new MarkerDefinition( grp, "AS", DistributionType.None, DistributionType.Gaussian ) ); //S**!
                Add( new MarkerDefinition( grp, "L0", DistributionType.None, DistributionType.Gaussian ) ); //S**-
                Add( new MarkerDefinition( grp, "L2", DistributionType.None, DistributionType.Gaussian ) ); //S** positives
                Add( new MarkerDefinition( grp, "L4", DistributionType.None, DistributionType.Gaussian ) ); //S**
                Add( new MarkerDefinition( grp, "LD", DistributionType.Weibull, DistributionType.None ) ); //S**!!
                Add( new MarkerDefinition( grp, "LS", DistributionType.Weibull, DistributionType.None ) ); //S**!!
                Add( new MarkerDefinition( grp, "M0", DistributionType.None, DistributionType.Gaussian ) ); //S**-
                Add( new MarkerDefinition( grp, "M2", DistributionType.Logistic, DistributionType.Logistic ) );
                Add( new MarkerDefinition( grp, "M4", DistributionType.None, DistributionType.None ) ); //**S!!
                Add( new MarkerDefinition( grp, "MD", DistributionType.None, DistributionType.Rayleigh ) ); //**S
                Add( new MarkerDefinition( grp, "MS", DistributionType.None, DistributionType.Weibull ) );
                Add( new MarkerDefinition( grp, "H0", DistributionType.None, DistributionType.Logistic ) ); //**S-
                Add( new MarkerDefinition( grp, "H2", DistributionType.None, DistributionType.Logistic ) ); //**S-
                Add( new MarkerDefinition( grp, "H4", DistributionType.None, DistributionType.Gaussian ) ); //**S
                Add( new MarkerDefinition( grp, "HD", DistributionType.Weibull, DistributionType.Rayleigh ) ); //**S!!
                Add( new MarkerDefinition( grp, "HS", DistributionType.Weibull, DistributionType.None ) ); //**S!!
            }
        }

        private static void Add( MarkerDefinition definition )
        {
            if( definition.Distribution != DistributionType.None )
            {
                markers.Add( definition.PositiveName, definition );
            }
        }

        private static MarkerGroupDefinition Add( MarkerGroupDefinition group )
        {
            groups.Add( group.Name, group );
            return group;
        }

        private static Dictionary<string, MarkerGroupDefinition> groups = new Dictionary<string, MarkerGroupDefinition>();
        private static Dictionary<string, MarkerDefinition> markers = new Dictionary<string, MarkerDefinition>();
    }

    class StrokeFeatureItem : IFeatureItem
    {
        public enum ItemType
        {
            ToClick,
            ToDoubleClick,
            InClick,
            Drag,
            MoveEnded
        }

        private static StrokeFeatureItem tiNull = new StrokeFeatureItem();

        public static StrokeFeatureItem Null()
        {
            return tiNull;
        }

        public StrokeFeatureItem( StrokeFeatureItem.ItemType type, Event.Button? button, List<Event> input )
        {
            bool SMOOTHED = true;

            values["."] = 0.0;

            Type = type;
            Button = button;
            Input = input;
            if( type == ItemType.InClick )
            {
                return; // no processing for this type of item yet, TODO
            }

            var count = 0;
            var sd = 0.0;
            var si = 0.0;
            var ti = 0.0;

            SmootherOutput smoothed = null;
            if( SMOOTHED )
            {
                smoothed = Smoother.Smooth( Smoother.SmoothMethod.Spline, input );
                count = smoothed.X.Count;

                var dx = smoothed.X[count-1] - smoothed.X[0];
                var dy = smoothed.Y[count-1] - smoothed.Y[0];
                sd = Math.Sqrt( dx*dx+dy*dy );
            }
            else
            {
                count = input.Count;

                var dx = input[count-1].X - input[0].X;
                var dy = input[count-1].Y - input[0].Y;
                sd = Math.Sqrt( dx*dx+dy*dy );
            }

            var vxPrev = double.NaN; // needed for ax
            var vyPrev = double.NaN; // needed for ay
            var vfixyPrev = double.NaN; // needed for curvature
            var afixyPrev = double.NaN; // needed for at, an

            var siList = new List<double>();
            var tiList = new List<double>();
            var xList = new List<double>();
            var yList = new List<double>();
            var FcsList = new List<double>();
            var FdcsList = new List<double>();
            var wList = new List<double>();
            var dwList = new List<double>();
            var vList = new List<double>();
            var vfiList = new List<double>();
            var vtList = new List<double>();
            var vnList = new List<double>();
            var dvList = new List<double>();
            var d2vList = new List<double>();
            var aList = new List<double>();
            var afiList = new List<double>();
            var atList = new List<double>();
            var anList = new List<double>();
            var caList = new List<double>();
            for( var i = 1; i < count; i++ )
            {
                double X;
                double Y;
                double dX;
                double dY;
                double dT;
                if( SMOOTHED )
                {
                    X = smoothed.X[i];
                    Y = smoothed.Y[i];
                    dX = smoothed.dX[i];
                    dY = smoothed.dY[i];
                    dT = smoothed.dT[i];
                }
                else
                {
                    X = input[i].X;
                    Y = input[i].Y;
                    dX = input[i].dX;
                    dY = input[i].dY;
                    dT = input[i].dT;
                }

                var ds = Math.Sqrt( dX*dX + dY*dY );
                var dt = dT;
                si += ds; siList.Add( si );
                ti += dt; tiList.Add( ti );

                if( dt > 0.0 && ds > 0.0 )
                {
                    // coordinates
                    xList.Add( X ); //**** FRED
                    yList.Add( Y ); //**** FRED

                    // path curvature -- USED
                    // angular velocity
                    double vfixy = Math.Atan2( dY, dX );
                    double vfitn = double.IsNaN( vfixyPrev ) ? 0.0 : Event.fitn( vfixyPrev, vfixy );
                    if( vfiList.Count > 0 )
                    {
                        var dFiTN = vfitn - vfiList.Last();

                        var fcs = dFiTN / ds;
                        if( FcsList.Count > 0 )
                        {
                            var fpcs = FcsList.Last();
                            FdcsList.Add( ( fcs - fpcs ) / ds ); //**** FRED
                        }
                        FcsList.Add( fcs ); //**** FRED

                        var w = dFiTN / dt;
                        if( wList.Count > 0 )
                        {
                            var wp = wList.Last();
                            dwList.Add( ( w - wp ) / dt ); //****
                        }
                        wList.Add( w ); //**** FRED
                    }

                    // velocity as vector
                    var vx = dX / dt;
                    var vy = dY / dt;
                    var v = Math.Sqrt( vx*vx + vy*vy );
                    if( !double.IsNaN( vfixyPrev ) )
                    {
                        var vn = v * Math.Sin( vfitn );
                        var vt = v * Math.Cos( vfitn );
                        vtList.Add( vt ); //****
                        vnList.Add( vn ); //****

                        vfiList.Add( vfitn ); //**** FRED
                    }
                    vfixyPrev = vfixy;

                    // velocity as scalar
                    if( vList.Count > 0 )
                    {
                        var dv = ( v - vList.Last() ) / dt;
                        if( dvList.Count > 0 )
                        {
                            d2vList.Add( ( dv - dvList.Last() ) / dt ); //**** FRED
                        }
                        dvList.Add( dv ); //**** FRED
                    }
                    vList.Add( v ); //**** FRED

                    // acceleration as vector
                    if( !double.IsNaN( vxPrev ) && !double.IsNaN( vyPrev ) )
                    {
                        var ax = ( vx - vxPrev ) / dt;
                        var ay = ( vy - vyPrev ) / dt;
                        var a = Math.Sqrt( ax*ax + ay*ay );
                        aList.Add( a ); //****

                        var afixy = Math.Atan2( ay, ax );
                        if( !double.IsNaN( afixyPrev ) )
                        {
                            var afi = Event.fitn( afixyPrev, afixy );

                            var an = a * Math.Sin( afi );
                            var at = a * Math.Cos( afi );
                            atList.Add( at ); //****
                            anList.Add( an ); //****

                            if( v > 0.0 && afiList.Count > 0 )
                            {
                                caList.Add( ( afi - afiList.Last() ) / v ); //****
                            }
                            afiList.Add( afi ); //****
                        }
                        afixyPrev = afixy;
                    }
                    vxPrev = vx;
                    vyPrev = vy;
                }
            }

            if( si == 0.0 ) // data is unusable
            {
                return; 
            }
            values["."] = 1.0; // signal data is ok

            IsStraight = vfiList.Select( fi => fi*fi ).Sum() == 0.0;

            var grp = StrokeFeatureDefinition.Group( "Si" ); if( grp != null ) {
                values["Si"] = grp.Transform( si );
            }
            AnalyzeList( "rSi", siList.Select( sii => sii /si ).ToList<double>());

            grp = StrokeFeatureDefinition.Group( "Ti" ); if( grp != null )
            {
                values["Ti"] = grp.Transform( ti );
            }
            grp = StrokeFeatureDefinition.Group( "CSi" ); if( grp != null )
            {
                var lc = FcsList.Count;
                values["CSi.0"] = FcsList.Where( v => v == 0.0 ).Count() / (double)lc;
                values["CSi-"] = grp.Transform( -FcsList.Where( v => v < 0 ).Sum() );
                values["CSi+"] = grp.Transform( +FcsList.Where( v => v > 0 ).Sum() );
            }

            grp = StrokeFeatureDefinition.Group( "Sd" ); if( grp != null )
            {
                values["Sd"] = grp.Transform( sd );
            }
            grp = StrokeFeatureDefinition.Group( "Vd" ); if( grp != null )
            {
                values["Vd"] = grp.Transform( sd / ti );
            }

            grp = StrokeFeatureDefinition.Group( "St" ); if( grp != null )
            {
                values["St"] = grp.Transform( 1.0 - sd / si + 0.000001 );
            }

            // jitter
            grp = StrokeFeatureDefinition.Group( "Ji" ); if( grp != null )
            {
                if( SMOOTHED )
                {
                    var sRaw = input.Select( i => Math.Sqrt( i.dX*i.dX + i.dY*i.dY ) ).Sum();
                    var jitter = sRaw / si;
                    values["Ji"] = grp.Transform( jitter <= 1.0 ? 1.000001 : jitter );
                }
                else
                {
                    values["Ji"] = grp.Transform( 1.0 );
                }
            }

            var xmin = xList.Min();
            AnalyzeList( "X", xList.Select( x => x - xmin == 0 ? 0.000001 : x - xmin ) );

            var ymin = yList.Min();
            AnalyzeList( "Y", yList.Select( y => y - ymin == 0 ? 0.000001 : y - ymin ) );

            AnalyzeList( "Cs", FcsList );

            AnalyzeList( "dCs", FdcsList );

            AnalyzeList( "W", wList );

            AnalyzeList( "dW", dwList );

            AnalyzeList( "Ca", caList );

            AnalyzeList( "V", vList );

            AnalyzeList( "dV", dvList );

            AnalyzeList( "d2V", d2vList );

            AnalyzeList( "Vn", vnList );

            AnalyzeList( "Vfi", vfiList );

            AnalyzeList( "A", aList );

            AnalyzeList( "An", anList );

            AnalyzeList( "Afi", afiList );

            /*
            var vtList = new List<double>();

            var atList = new List<double>();
            */
        }

        public bool IsValid
        {
            get { return values["."] == 1.0; }
        }

        public bool IsStraight
        {
            get; private set;
        }

        public double Value( string name )
        {
            if( values["."] == 0.0 ) // I am a stub and I have no values
            {
                return 0.0;
            }
            else
            {
                return values[name];
            }
        }

        private StrokeFeatureItem()
        {
            values["."] = 0.0;
        }

        private void AnalyzeList( string name, IEnumerable<double> inputlist ) // splitSigns implies splitZero
        {
            var def = StrokeFeatureDefinition.Group( name );
            var c = inputlist.Count();
            if( def == null || c == 0 )
            {
                StoreNaNMarkers( name );
                return;
            }

            IEnumerable<double> zeroSplitted = null;
            if( def.SplitZero )
            {
                values[name + ".0"] = def.SplitZero ? inputlist.Where( i => i == 0.0 ).Count() / (double)c : 0.0;
                zeroSplitted = inputlist.Where( i => i != 0.0 );
            }
            else
            {
                zeroSplitted = inputlist;
            }

            if( def.SplitSigns )
            {
                AnalyzeSplittedList( name, "-", zeroSplitted.Where( i => i < 0.0 ).Select( i => -i ) );
                AnalyzeSplittedList( name, "+", zeroSplitted.Where( i => i > 0.0 ).Select( i => i ) );
            }
            else
            {
                AnalyzeSplittedList( name, "", zeroSplitted );
            }
        }

        private void AnalyzeSplittedList( string groupName, string subgroupName, IEnumerable<double> inputlist )
        {
            var def = StrokeFeatureDefinition.Group( groupName );
            var c = inputlist.Count();
            if( def == null || c == 0 )
            {
                StoreNaNMarkers( groupName + subgroupName );
                return;
            }

            var name = groupName + subgroupName;
            var transformed = def.Transform( inputlist );
            IEnumerable<double> list = transformed;

            c = list.Count();
            if( c < 2 )
            {
                list = transformed;
                c = list.Count();
            }

            var startOfM = c * 25 / 100;
            var startOfH = c * 75 / 100;

            var lowSize = startOfM;
            if( lowSize < 2 )
            {
                lowSize = 2;
            }
            var midSize = c - startOfH + startOfM;
            if( midSize < 2 )
            {
                midSize = c;
                startOfM = 0;
            }
            var hiSize = c - startOfH;
            if( hiSize < 2 )
            {
                hiSize = 2;
            };
            startOfH = c - hiSize; // adjust if needed

            var l = list.Take( lowSize );
            var m = list.Skip( startOfM ).Take( midSize );
            var h = list.Skip( startOfH );

            var a0 = list.Min();
            values[name + ".A2"] = list.Average();
            var a4 = list.Max();
            values[name + ".A0"] = a0;
            values[name + ".A4"] = a4;
            values[name + ".AD"] = Math.Sqrt( list.Variance() );
            values[name + ".AS"] = a4 - a0;

            double l0;
            double l4;
            double m0;
            double m4;
            double h0;
            double h4;
            double ld;
            double hd;

            c = l.Count();
            if( c == 0 )
            {
                l0 = double.NaN; values[name + ".L2"] = double.NaN; l4 = double.NaN;
                ld = double.NaN;
            }
            else
            {
                l0 = l.Min(); values[name + ".L2"] = l.Average(); l4 = l.Max();
                ld = Math.Sqrt( l.Variance() );
            }
            values[name + ".L0"] = l0;
            values[name + ".L4"] = l4;
            values[name + ".LD"] = ld;
            values[name + ".LS"] = l4 - l0;

            c = h.Count();
            if( c == 0 )
            {
                h0 = double.NaN; values[name + ".H2"] = double.NaN; h4 = double.NaN; hd = double.NaN;
            }
            else
            {
                h0 = h.Min(); values[name + ".H2"] = h.Average(); h4 = h.Max();
                hd = Math.Sqrt( h.Variance() );
            }
            values[name + ".H0"] = h0;
            values[name + ".H4"] = h4;
            values[name + ".HD"] = hd;
            values[name + ".HS"] = h4 - h0;

            c = m.Count();
            if( c == 0 )
            {
                m0 = 0.5 * ( l4 + h0 );
                values[name + ".M2"] = m0;
                m4 = m0;
                values[name + ".MD"] = 0.5 * ( ld + hd );
            }
            else
            {
                m0 = m.Min();
                values[name + ".M2"] = m.Average();
                m4 = m.Max();
                values[name + ".MD"] = Math.Sqrt( m.Variance() );
            }
            values[name + ".M0"] = m0;
            values[name + ".M4"] = m4;
            values[name + ".MS"] = m4 - m0;
        }

        private void StoreNaNMarkers( string name )
        {
            values[name + ".A0"] = double.NaN; values[name + ".A2"] = double.NaN; values[name + ".A4"] = double.NaN; values[name + ".AD"] = double.NaN; values[name + ".AS"] = double.NaN;
            values[name + ".L0"] = double.NaN; values[name + ".L2"] = double.NaN; values[name + ".L4"] = double.NaN; values[name + ".LD"] = double.NaN; values[name + ".LS"] = double.NaN;
            values[name + ".M0"] = double.NaN; values[name + ".M2"] = double.NaN; values[name + ".M4"] = double.NaN; values[name + ".MD"] = double.NaN; values[name + ".MS"] = double.NaN;
            values[name + ".H0"] = double.NaN; values[name + ".H2"] = double.NaN; values[name + ".H4"] = double.NaN; values[name + ".HD"] = double.NaN; values[name + ".HS"] = double.NaN;
        }

        public ItemType Type { get; private set; }
        public Event.Button? Button { get; private set; }
        public List<Event> Input { get; private set; }

        Storage values = new Storage();

        private class Storage
        {
            public double this[string name]
            {
                get
                {
                    return values[name];
                }
                set
                {
                    values[name] = value;
                }
            }

            private Dictionary<string, double> values = new Dictionary<string, double>();
        }
    }

    class StrokeFeature : Feature, IFeature<StrokeFeatureItem>
    {
        #region IFeature Members

        public void ComputeMarkers( string computeId, bool cleanupProcessData = true )
        {
            if( _Markers.Count == 0 )
            {
                // ComputeMarkersForItems( computeId, TypedItems.Where( i => i.Si > 0.0 && i.Type == StrokeFeatureItem.ItemType.Drag ), "d" );
                ComputeMarkersForItems( computeId, TypedItems.Where( i => i.IsValid && !i.IsStraight && i.Type == StrokeFeatureItem.ItemType.MoveEnded ), "m" );
                // ComputeMarkersForItems( computeId, TypedItems.Where( i => i.IsValid && i.Type == StrokeFeatureItem.ItemType.ToClick ), "c" );
            }

            if( cleanupProcessData )
            {
                _Items.Clear();
            }
        }

        #endregion

        #region IFeature<StrokeFeatureItem> Members

        public IEnumerable<IFeatureItem> Items
        {
            get { return _Items; }
        }

        public IList<StrokeFeatureItem> TypedItems
        {
            get { return _Items; }
        }

        public bool AddItems( IEnumerable<StrokeFeatureItem> items )
        {
            if( items == null || items.Count() == 0 )
            {
                return false;
            }
            _Items.AddRange( items );
            return true;
        }

        #endregion

        public StrokeFeature( Entity entity ) :
            base( NAME, entity )
        {
            _Items = new List<StrokeFeatureItem>();
        }

        private static string NAME = "StrokeFeature";
        private List<StrokeFeatureItem> _Items { get; set; }

        private void ComputeMarkersForItems( string computeId, IEnumerable<StrokeFeatureItem> items, string namePrefix )
        {
            var nonNull = items.Where( i => i != StrokeFeatureItem.Null() );
            if( nonNull.Count() == 0 )
            {
                return;
            }

            foreach( var def in StrokeFeatureDefinition.Markers )
            {
                IMarkerExtractor extractor = null;
                switch( def.Distribution )
                {
                    case DistributionType.Gamma:
                        extractor = new GammaMarkerExtractor();
                        break;
                    case DistributionType.Gaussian:
                        extractor = new GaussianMarkerExtractor();
                        break;
                    case DistributionType.InverseGaussian:
                        extractor = new InverseGaussianMarkerExtractor();
                        break;
                    case DistributionType.Logistic:
                        extractor = new LogisticMarkerExtractor();
                        break;
                    case DistributionType.Lognormal:
                        extractor = new LognormalMarkerExtractor();
                        break;
                    case DistributionType.Rayleigh:
                        extractor = new RayleighMarkerExtractor();
                        break;
                    case DistributionType.Weibull:
                        extractor = new WeibullMarkerExtractor();
                        break;
                    case DistributionType.Spline:
                        extractor = new SplineMarkerExtractor();
                        break;
                }

                if( def.HasNegatives )
                {
                    _Markers.AddRange( extractor.Extract( computeId, this, nonNull,
                        namePrefix + def.NegativeName,
                        f => ( (StrokeFeatureItem)f ).Value( def.NegativeName ),
                        def.HistogramDefinition ) );
                }
                if( def.HasPositives )
                {
                    _Markers.AddRange( extractor.Extract( computeId, this, nonNull,
                        namePrefix + def.PositiveName,
                        f => ( (StrokeFeatureItem)f ).Value( def.PositiveName ),
                        def.HistogramDefinition ) );
                }
            }
        }
    }

    class StrokeFeatureExtractor : IFeatureExtractor<StrokeFeatureItem>
    {
        private int ends = 0;
        private int totals = 0;

        #region IFeatureExtractor<StrokeFeatureItem> Members

        public IEnumerable<StrokeFeatureItem> AddEvent( Event input, IList<StrokeFeatureItem> previousItems )
        {
            var list = new List<StrokeFeatureItem>();

            if( previousItems == null || previousItems.Count == 0 )
            {
                list.Add( StrokeFeatureItem.Null() );
                buffer = new List<Event>();
            }
            else
            {
                HandleButton( ref list, Event.Button.Left, input );
                HandleButton( ref list, Event.Button.Middle, input );
                HandleButton( ref list, Event.Button.Right, input );
                HandleButton( ref list, Event.Button.B4, input );
                HandleButton( ref list, Event.Button.B5, input );

                totals++;
                if( input.dT >= TIME_THRESHOLD )
                {
                    ends++;
                }

                if( list.Count == 0 && // no button caught,
                    input.dT >= TIME_THRESHOLD ) // so try time or angle criterion
                {
                    if( buffer.Count > LENGTH_THRESHOLD ) // but only we have anything
                    {
                        list.Add( new StrokeFeatureItem( StrokeFeatureItem.ItemType.MoveEnded, null, buffer ) );
                    }
                    buffer = new List<Event>();
                }

                buffer.Add( input );
            }

            return list;
        }

        #endregion

        private void HandleButton( ref List<StrokeFeatureItem> list, Event.Button button, Event input )
        {
            if( input[button] == Event.ButtonState.Press )
            {
                clickedInput[button] = input;
                if( buffer.Count > LENGTH_THRESHOLD ) // but only we have anything
                {
                    list.Add( new StrokeFeatureItem( StrokeFeatureItem.ItemType.ToClick, button, buffer ) );
                }
                buffer = new List<Event>();
            }
            else if( input[button] == Event.ButtonState.DoublePress )
            {
                if( clickedInput[button] != null )
                {
                    if( buffer.Count > LENGTH_THRESHOLD ) // but only we have anything
                    {
                        list.Add( new StrokeFeatureItem( StrokeFeatureItem.ItemType.ToDoubleClick, button, buffer ) );
                    }
                    buffer = new List<Event>();
                }
                clickedInput[button] = input;
            }
            else if( input[button] == Event.ButtonState.Release )
            {
                if( clickedInput.ContainsKey( button ) && clickedInput[button] != null )
                {
                    var dX = input.X - clickedInput[button].X;
                    var dY = input.Y - clickedInput[button].Y;
                    var distance = Math.Sqrt( dX * dX + dY * dY );
                    if( distance > DRAG_MOVEMENT_THRESHOLD )
                    {
                        if( buffer.Count > LENGTH_THRESHOLD ) // but only we have anything
                        {
                            list.Add( new StrokeFeatureItem( StrokeFeatureItem.ItemType.Drag, button, buffer ) );
                        }
                        buffer = new List<Event>();
                    }
                    else
                    {
                        // add whole buffer
                        list.Add( new StrokeFeatureItem( StrokeFeatureItem.ItemType.InClick, button, buffer ) );
                        buffer = new List<Event>();
                    }
                    clickedInput[button] = null;
                }
            }
        }

        private static double DRAG_MOVEMENT_THRESHOLD = 3;
        private static double LENGTH_THRESHOLD = 4; // bigger than
        private static double TIME_THRESHOLD = 32;
        private Dictionary<Event.Button, Event> clickedInput = new Dictionary<Event.Button, Event>();
        private List<Event> buffer;
    }
}
