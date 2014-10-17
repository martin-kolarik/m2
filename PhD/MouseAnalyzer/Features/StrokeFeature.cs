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
        public static bool SINGLESIDED = true;
        public static bool LOGARITHMIC = true;

        public class MarkerGroupDefinition
        {
            public string Name { get; private set; }
            public bool Singlesided { get; private set; }
            public bool Logarithmic { get; private set; }

            public MarkerGroupDefinition( string name, bool singlesided = false, bool logarithmic = false )
            {
                Name = name;
                Singlesided = SINGLESIDED && singlesided;
                Logarithmic = LOGARITHMIC && logarithmic;
            }

            public double Transform( double input )
            {
                double side;
                if( Singlesided )
                {
                    side = Math.Abs( input );
                }
                else
                {
                    side = input;
                }
                if( !Logarithmic )
                {
                    return side;
                }
                else if( side > 0.0 )
                {
                    return Math.Log( side );
                }
                else
                {
                    return double.NaN;
                }
            }

            public IEnumerable<double> Transform( IEnumerable<double> input )
            {
                IEnumerable<double> side = null;
                if( Singlesided )
                {
                    side = input.Select( d => Math.Abs( d ) );
                }
                else
                {
                    side = input;
                }
                if( Logarithmic )
                {
                    return side.Where( d => d > 0 ).Select( d => Math.Log( d ) );
                }
                else
                {
                    return side;
                }
            }
        }

        public class MarkerDefinition
        {
            public MarkerDefinition( MarkerGroupDefinition of, string name, DistributionType distribution, bool histogram = false ) :
                this( of, name, distribution, distribution, distribution, histogram )
            {
            }

            public MarkerDefinition( MarkerGroupDefinition of, string name, DistributionType distribution, DistributionType forSinglesidedAndLogarithmic, bool histogram = false ) :
                this( of, name, distribution, forSinglesidedAndLogarithmic, forSinglesidedAndLogarithmic, histogram )
            {
            }

            public MarkerDefinition( MarkerGroupDefinition of, string name, DistributionType distribution, DistributionType forSinglesided, DistributionType forLogarithmic, bool histogram = false )
            {
                this.of = of;
                Name = of.Name + (name=="" ? "" : "." + name);
                this.distribution = distribution;
                distributionForSinglesided = forSinglesided;
                distributionForLogarithmic = forLogarithmic;
                this.histogram = histogram;
            }

            public string Name { get; private set; }
            public bool Singlesided { get { return of.Singlesided; } }
            public bool Logarithmic { get { return of.Logarithmic; } }
            public HistogramMarker.HistogramDefinition HistogramDefinition
            {
                get
                {
                    return histogram ? new HistogramMarker.HistogramDefinition( 200 ) : null;;
                }
            }

            public DistributionType Distribution
            {
                get
                {
                    if( Logarithmic )
                    {
                        return distributionForLogarithmic;
                    }
                    else if( Singlesided )
                    {
                        return distributionForSinglesided;
                    }
                    else
                    {
                        return distribution;
                    }
                }
            }

            private MarkerGroupDefinition of;
            private DistributionType distribution;
            private DistributionType distributionForSinglesided;
            private DistributionType distributionForLogarithmic;
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
            MarkerGroupDefinition grp;

            //*****
            Add( new MarkerDefinition( Add( new MarkerGroupDefinition("Si") ), "", DistributionType.Lognormal ) );

            //*****
            grp = Add( new MarkerGroupDefinition("rSi") );
            Add( new MarkerDefinition( grp, "A0", DistributionType.Lognormal ) );
            Add( new MarkerDefinition( grp, "A2", DistributionType.Gaussian ) );
            // Add( new MarkerDefinition( grp, "A4", DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "AD", DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "AS", DistributionType.Gaussian, true ) );
            Add( new MarkerDefinition( grp, "L0", DistributionType.Weibull ) );
            Add( new MarkerDefinition( grp, "L2", DistributionType.Gamma ) );
            Add( new MarkerDefinition( grp, "L4", DistributionType.Gamma ) );
            Add( new MarkerDefinition( grp, "LD", DistributionType.Gamma ) );
            // Add( new MarkerDefinition( grp, "LS", DistributionType.Gaussian, true ) );
            Add( new MarkerDefinition( grp, "M0", DistributionType.Gamma ) );
            Add( new MarkerDefinition( grp, "M2", DistributionType.Gaussian ) );
            // Add( new MarkerDefinition( grp, "M4", DistributionType.Gaussian, true ) );
            Add( new MarkerDefinition( grp, "MD", DistributionType.Gamma ) );
            Add( new MarkerDefinition( grp, "MS", DistributionType.Weibull ) );
            Add( new MarkerDefinition( grp, "H0", DistributionType.Weibull ) );
            Add( new MarkerDefinition( grp, "H2", DistributionType.Weibull ) );
            // Add( new MarkerDefinition( grp, "H4", DistributionType.Logistic, true ) );
            Add( new MarkerDefinition( grp, "HD", DistributionType.Gamma ) );
            // Add( new MarkerDefinition( grp, "HS", DistributionType.Gaussian, true ) );

            //*****
            Add( new MarkerDefinition( Add( new MarkerGroupDefinition("Ti") ), "", DistributionType.Lognormal ) );
            Add( new MarkerDefinition( Add( new MarkerGroupDefinition("CSi") ), "", DistributionType.Logistic ) );

            //*****
            Add( new MarkerDefinition( Add( new MarkerGroupDefinition("Sd") ), "", DistributionType.Lognormal ) );
            Add( new MarkerDefinition( Add( new MarkerGroupDefinition("Vd") ), "", DistributionType.Lognormal ) );
            // Add( new MarkerDefinition( Add( new MarkerGroupDefinition("CSd") ), "", DistributionType.Weibull ) );

            //*****
            Add( new MarkerDefinition( Add( new MarkerGroupDefinition("St", false, true ) ), "", DistributionType.Lognormal, DistributionType.Logistic ) ); //****FRED

            grp = Add( new MarkerGroupDefinition("X") ); //*****
            // Add( new MarkerDefinition( grp, "A0", DistributionType.Gaussian, true ) );
            Add( new MarkerDefinition( grp, "A2", DistributionType.Lognormal ) );
            Add( new MarkerDefinition( grp, "A4", DistributionType.Lognormal ) );
            Add( new MarkerDefinition( grp, "AD", DistributionType.Lognormal ) );
            Add( new MarkerDefinition( grp, "AS", DistributionType.Lognormal ) );

            grp = Add( new MarkerGroupDefinition("Y") ); //*****
            // Add( new MarkerDefinition( grp, "A0", DistributionType.Gaussian ) );
            Add( new MarkerDefinition( grp, "A2", DistributionType.Logistic ) );
            Add( new MarkerDefinition( grp, "A4", DistributionType.Lognormal ) );
            Add( new MarkerDefinition( grp, "AD", DistributionType.Lognormal ) );
            Add( new MarkerDefinition( grp, "AS", DistributionType.Lognormal ) );

            grp = Add( new MarkerGroupDefinition("Cs") ); //*****
            // new MarkerDefinition( grp, "A0", DistributionType.Gaussian ),
            Add( new MarkerDefinition( grp, "A2", DistributionType.Logistic ) );
            // new MarkerDefinition( grp, "A4", DistributionType.Gaussian ),
            Add( new MarkerDefinition( grp, "AD", DistributionType.Gamma ) );
            // Add( new MarkerDefinition( grp, "AS", DistributionType.Gaussian, true ) );
            // new MarkerDefinition( grp, "L0", DistributionType.Gaussian ),
            Add( new MarkerDefinition( grp, "L2", DistributionType.Logistic ) );
            // new MarkerDefinition( grp, "CSL4", DistributionType.Gaussian ),
            // Add( new MarkerDefinition( grp, "LD", DistributionType.Gaussian, true ) );
            // new MarkerDefinition( grp, "CSLS", DistributionType.Gaussian ),
            // Add( new MarkerDefinition( grp, "M0", DistributionType.Logistic, true ) );
            Add( new MarkerDefinition( grp, "M2", DistributionType.Logistic ) );
            // Add( new MarkerDefinition( grp, "M4", DistributionType.Logistic, true ) );
            // Add( new MarkerDefinition( grp, "MD", DistributionType.Gaussian, true ) );
            // new MarkerDefinition( grp, "CSMS", DistributionType.Gaussian ),
            // new MarkerDefinition( grp, "CSH0", DistributionType.Logistic ),
            Add( new MarkerDefinition( grp, "H2", DistributionType.Logistic ) );
            // new MarkerDefinition( grp, "CSH4", DistributionType.Gaussian ),
            // Add( new MarkerDefinition( grp, "HD", DistributionType.Gaussian, true ) );
            // new MarkerDefinition( grp, "CSHS", DistributionType.Gaussian ),

            grp = Add( new MarkerGroupDefinition("dCs") ); //*****
            // new MarkerDefinition( grp, "dCSA0", DistributionType.InverseGaussian ),
            Add( new MarkerDefinition( grp, "A2", DistributionType.Logistic ) );
            // new MarkerDefinition( grp, "dCSA4", DistributionType.InverseGaussian ),
            Add( new MarkerDefinition( grp, "AD", DistributionType.Gamma ) );
            // Add( new MarkerDefinition( grp, "AS", DistributionType.Gamma, true ) );
            // new MarkerDefinition( grp, "dCSL0", DistributionType.InverseGaussian ),
            Add( new MarkerDefinition( grp, "L2", DistributionType.Logistic ) );
            // new MarkerDefinition( grp, "dCSL4", DistributionType.InverseGaussian ),
            // Add( new MarkerDefinition( grp, "LD", DistributionType.Gamma, true ) );
            // new MarkerDefinition( grp, "dCSLS", DistributionType.Gamma ),
            // new MarkerDefinition( grp, "dCSM0", DistributionType.InverseGaussian ),
            Add( new MarkerDefinition( grp, "M2", DistributionType.Logistic ) );
            // new MarkerDefinition( grp, "dCSM4", DistributionType.InverseGaussian ),
            // Add( new MarkerDefinition( grp, "MD", DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "MS", DistributionType.Gamma, true ) );
            // new MarkerDefinition( grp, "dCSH0", DistributionType.InverseGaussian ),
            Add( new MarkerDefinition( grp, "H2", DistributionType.Logistic ) );
            // new MarkerDefinition( grp, "dCSH4", DistributionType.Gaussian ),
            // Add( new MarkerDefinition( grp, "HD", DistributionType.Gaussian, true ) );
            // new MarkerDefinition( grp, "dCSHS", DistributionType.Gamma ),

            //*****
            grp = Add( new MarkerGroupDefinition( "V", false, true ) ); //*****
            // Add( new MarkerDefinition( grp, "A0", DistributionType.Gaussian, true ) );
            Add( new MarkerDefinition( grp, "A2", DistributionType.Lognormal, DistributionType.Gaussian ) );
            // Add( new MarkerDefinition( grp, "A4", DistributionType.Lognormal, DistributionType.Gaussian, true ) );
            Add( new MarkerDefinition( grp, "AD", DistributionType.Lognormal, DistributionType.Gaussian ) );
            // Add( new MarkerDefinition( grp, "AS", DistributionType.Lognormal, DistributionType.Gaussian, true ) );
            // new MarkerDefinition( grp, "VL0", DistributionType.Gaussian ),
            Add( new MarkerDefinition( grp, "L2", DistributionType.Lognormal, DistributionType.Gaussian ) );
            // Add( new MarkerDefinition( grp, "L4", DistributionType.Lognormal, DistributionType.Gaussian, true  ) );
            // Add( new MarkerDefinition( grp, "LD", DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "M0", DistributionType.Lognormal, DistributionType.Gaussian, true  ) );
            Add( new MarkerDefinition( grp, "M2", DistributionType.Lognormal, DistributionType.Gaussian ) );
            // Add( new MarkerDefinition( grp, "M4", DistributionType.Lognormal, DistributionType.Gaussian, true  ) );
            Add( new MarkerDefinition( grp, "MD", DistributionType.Lognormal, DistributionType.Gaussian ) );
            // new MarkerDefinition( grp, "VMV", DistributionType.Gaussian ),
            // new MarkerDefinition( grp, "VH0", DistributionType.Gaussian ),
            Add( new MarkerDefinition( grp, "H2", DistributionType.Lognormal, DistributionType.Gaussian ) );
            // new MarkerDefinition( grp, "VH4", DistributionType.Gaussian ),
            // Add( new MarkerDefinition( grp, "HD", DistributionType.Gaussian, true ) );

            //*****
            grp = Add( new MarkerGroupDefinition( "dV" ) ); //*****
            // Add( new MarkerDefinition( grp, "A0", DistributionType.Logistic, true ) );
            Add( new MarkerDefinition( grp, "A2", DistributionType.Logistic ) );
            // Add( new MarkerDefinition( grp, "A4", DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "AD", DistributionType.Gaussian, true ) ); // Lognormal, DistributionType.Logistic ) );
            Add( new MarkerDefinition( grp, "AS", DistributionType.Weibull, DistributionType.Gaussian ) );
            // Add( new MarkerDefinition( grp, "L0", DistributionType.Logistic, true ) );
            Add( new MarkerDefinition( grp, "L2", DistributionType.Logistic ) );
            // Add( new MarkerDefinition( grp, "L4", DistributionType.Logistic, true ) );
            // Add( new MarkerDefinition( grp, "LD", DistributionType.Gaussian, true ) ); // Lognormal, DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "LS", DistributionType.Logistic, true ) );
            // Add( new MarkerDefinition( grp, "M0", DistributionType.Gaussian, true ) );
            Add( new MarkerDefinition( grp, "M2", DistributionType.Logistic ) );
            // Add( new MarkerDefinition( grp, "M4", DistributionType.Gaussian, true ) );
            Add( new MarkerDefinition( grp, "MD", DistributionType.Weibull, DistributionType.Logistic ) );
            Add( new MarkerDefinition( grp, "MS", DistributionType.Weibull ) );
            // Add( new MarkerDefinition( grp, "H0", DistributionType.Logistic, true ) );
            Add( new MarkerDefinition( grp, "H2", DistributionType.Logistic ) );
            // Add( new MarkerDefinition( grp, "H4", DistributionType.Logistic, true ) );
            // Add( new MarkerDefinition( grp, "HD", DistributionType.Gaussian, true ) ); // DistributionType.Weibull, DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "HS", DistributionType.Weibull, DistributionType.Gaussian, true ) );

            //*****
            grp = Add( new MarkerGroupDefinition( "d2V" ) ); //*****
            // Add( new MarkerDefinition( grp, "A0", DistributionType.Logistic, true ) );
            Add( new MarkerDefinition( grp, "A2", DistributionType.Logistic ) );
            // Add( new MarkerDefinition( grp, "A4", DistributionType.Logistic, true ) );
            Add( new MarkerDefinition( grp, "AD", DistributionType.Weibull ) ); // DistributionType.Weibull, DistributionType.Logistic, true ) );
            // Add( new MarkerDefinition( grp, "AS", DistributionType.Weibull, DistributionType.Logistic, true ) );
            // new MarkerDefinition( grp, "d2VL0", DistributionType.Gaussian ),
            Add( new MarkerDefinition( grp, "L2", DistributionType.Gaussian ) );
            // new MarkerDefinition( grp, "d2VL4", DistributionType.Gaussian ),
            // new MarkerDefinition( grp, "d2VLD", DistributionType.Gaussian ),
            // new MarkerDefinition( grp, "d2VLS", DistributionType.Gaussian ),
            // Add( new MarkerDefinition( grp, "M0", DistributionType.Gaussian, true ) );
            Add( new MarkerDefinition( grp, "M2", DistributionType.Gaussian ) );
            // Add( new MarkerDefinition( grp, "M4", DistributionType.Gaussian, true ) );
            Add( new MarkerDefinition( grp, "MD", DistributionType.Weibull ) );
            // Add( new MarkerDefinition( grp, "MS", DistributionType.Gaussian, true ) );
            // new MarkerDefinition( grp, "d2VH0", DistributionType.Gaussian ),
            Add( new MarkerDefinition( grp, "H2", DistributionType.Gaussian ) );
            // new MarkerDefinition( grp, "d2VH4", DistributionType.Gaussian ),
            // new MarkerDefinition( grp, "d2VHD", DistributionType.Gaussian ),
            // new MarkerDefinition( grp, "d2VHS", DistributionType.Gaussian ),

            grp = Add( new MarkerGroupDefinition( "Vn" ) ); //*****
            // Add( new MarkerDefinition( grp, "A0", DistributionType.Gaussian, true ) );
            Add( new MarkerDefinition( grp, "A2", DistributionType.Logistic ) );
            // Add( new MarkerDefinition( grp, "A4", DistributionType.Gaussian, true ) );
            Add( new MarkerDefinition( grp, "AD", DistributionType.Rayleigh ) );
            Add( new MarkerDefinition( grp, "AS", DistributionType.InverseGaussian ) );
            Add( new MarkerDefinition( grp, "L0", DistributionType.Logistic ) );
            Add( new MarkerDefinition( grp, "L2", DistributionType.Logistic ) );
            Add( new MarkerDefinition( grp, "L4", DistributionType.Logistic ) );
            // Add( new MarkerDefinition( grp, "LD", DistributionType.Rayleigh, true ) );
            // Add( new MarkerDefinition( grp, "LS", DistributionType.InverseGaussian, true ) );
            // Add( new MarkerDefinition( grp, "M0", DistributionType.Gaussian, true ) );
            Add( new MarkerDefinition( grp, "M2", DistributionType.Logistic ) );
            // Add( new MarkerDefinition( grp, "M4", DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "MD", DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "MS", DistributionType.Gaussian, true ) );
            Add( new MarkerDefinition( grp, "H0", DistributionType.Logistic ) );
            Add( new MarkerDefinition( grp, "H2", DistributionType.Logistic ) );
            Add( new MarkerDefinition( grp, "H4", DistributionType.Logistic ) );
            // Add( new MarkerDefinition( grp, "HD", DistributionType.Rayleigh, true ) );
            // Add( new MarkerDefinition( grp, "HS", DistributionType.InverseGaussian, true ) );

            grp = Add( new MarkerGroupDefinition( "Vfi" ) ); //*****
            // Add( new MarkerDefinition( grp, "A0", DistributionType.Gaussian, true ) );
            Add( new MarkerDefinition( grp, "A2", DistributionType.Logistic ) );
            // Add( new MarkerDefinition( grp, "A4", DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "AD", DistributionType.Logistic, true ) );
            // Add( new MarkerDefinition( grp, "AS", DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "L0", DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "L2", DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "L4", DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "LD", DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "LS", DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "M0", DistributionType.Gaussian, true ) );
            Add( new MarkerDefinition( grp, "M2", DistributionType.Logistic ) );
            // Add( new MarkerDefinition( grp, "M4", DistributionType.Gaussian, true ) );
            Add( new MarkerDefinition( grp, "MD", DistributionType.Rayleigh ) );
            // Add( new MarkerDefinition( grp, "MS", DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "H0", DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "H2", DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "H4", DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "HD", DistributionType.Gaussian, true ) );
            //  Add( new MarkerDefinition( grp, "HS", DistributionType.Gaussian, true ) );

            grp = Add( new MarkerGroupDefinition( "W" ) ); //*****
            // new MarkerDefinition( grp, "WA0", DistributionType.InverseGaussian ),
            Add( new MarkerDefinition( grp, "A2", DistributionType.Logistic ) );
            // new MarkerDefinition( grp, "WA4", DistributionType.InverseGaussian ),
            Add( new MarkerDefinition( grp, "AD", DistributionType.Gamma ) );
            // new MarkerDefinition( grp, "WAS", DistributionType.Gamma ),
            // new MarkerDefinition( grp, "WL0", DistributionType.InverseGaussian ),
            Add( new MarkerDefinition( grp, "L2", DistributionType.Logistic ) );
            // new MarkerDefinition( grp, "WL4", DistributionType.InverseGaussian ),
            // Add( new MarkerDefinition( grp, "LD", DistributionType.Gaussian, true ) );
            // new MarkerDefinition( grp, "WLS", DistributionType.Gaussian ),
            // new MarkerDefinition( grp, "WM0", DistributionType.InverseGaussian ),
            Add( new MarkerDefinition( grp, "M2", DistributionType.Logistic ) );
            // new MarkerDefinition( grp, "WM4", DistributionType.InverseGaussian ),
            Add( new MarkerDefinition( grp, "MD", DistributionType.Gamma ) );
            // new MarkerDefinition( grp, "WMS", DistributionType.Gamma ),
            // new MarkerDefinition( grp, "WH0", DistributionType.InverseGaussian ),
            Add( new MarkerDefinition( grp, "H2", DistributionType.Logistic ) );
            // new MarkerDefinition( grp, "WH4", DistributionType.InverseGaussian ),
            // Add( new MarkerDefinition( grp, "HD", DistributionType.Gaussian, true ) );
            // new MarkerDefinition( grp, "WHS", DistributionType.Gamma ),

            grp = Add( new MarkerGroupDefinition( "dW" ) ); //*****
            // Add( new MarkerDefinition( grp, "A0", DistributionType.Gaussian, true ) );
            Add( new MarkerDefinition( grp, "A2", DistributionType.Logistic ) );
            // Add( new MarkerDefinition( grp, "A4", DistributionType.InverseGaussian, true ) );
            Add( new MarkerDefinition( grp, "AD", DistributionType.Rayleigh ) );
            Add( new MarkerDefinition( grp, "AS", DistributionType.Rayleigh ) );
            // Add( new MarkerDefinition( grp, "L0", DistributionType.InverseGaussian, true ) );
            Add( new MarkerDefinition( grp, "L2", DistributionType.Logistic ) );
            // Add( new MarkerDefinition( grp, "L4", DistributionType.InverseGaussian, true ) );
            // Add( new MarkerDefinition( grp, "LD", DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "LS", DistributionType.Gamma, true ) );
            // Add( new MarkerDefinition( grp, "M0", DistributionType.InverseGaussian, true ) );
            Add( new MarkerDefinition( grp, "M2", DistributionType.Logistic ) );
            // Add( new MarkerDefinition( grp, "M4", DistributionType.InverseGaussian, true ) );
            // Add( new MarkerDefinition( grp, "MD", DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "MS", DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "H0", DistributionType.Logistic, true ) );
            Add( new MarkerDefinition( grp, "H2", DistributionType.Logistic ) );
            // Add( new MarkerDefinition( grp, "H4", DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "HD", DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "HS", DistributionType.Gamma, true ) );

            grp = Add( new MarkerGroupDefinition( "Ca" ) ); //*****
            // Add( new MarkerDefinition( grp, "A0", DistributionType.Gaussian ) );
            Add( new MarkerDefinition( grp, "A2", DistributionType.Logistic ) );
            // Add( new MarkerDefinition( grp, "A4", DistributionType.Gaussian ) );
            Add( new MarkerDefinition( grp, "AD", DistributionType.Gamma ) );
            Add( new MarkerDefinition( grp, "AS", DistributionType.Gamma ) );
            Add( new MarkerDefinition( grp, "L0", DistributionType.Gaussian ) );
            Add( new MarkerDefinition( grp, "L2", DistributionType.Logistic ) );
            Add( new MarkerDefinition( grp, "L4", DistributionType.Gaussian ) );
            Add( new MarkerDefinition( grp, "LD", DistributionType.Gamma ) );
            // Add( new MarkerDefinition( grp, "LS", DistributionType.Weibull, true ) );
            Add( new MarkerDefinition( grp, "M0", DistributionType.Gaussian ) );
            Add( new MarkerDefinition( grp, "M2", DistributionType.Logistic ) );
            Add( new MarkerDefinition( grp, "M4", DistributionType.Gaussian ) );
            Add( new MarkerDefinition( grp, "MD", DistributionType.Gamma ) );
            // Add( new MarkerDefinition( grp, "MS", DistributionType.Gaussian, true ) );
            Add( new MarkerDefinition( grp, "H0", DistributionType.Gaussian ) );
            Add( new MarkerDefinition( grp, "H2", DistributionType.Logistic ) );
            Add( new MarkerDefinition( grp, "H4", DistributionType.Gaussian ) );
            Add( new MarkerDefinition( grp, "HD", DistributionType.Gamma ) );
            // Add( new MarkerDefinition( grp, "HS", DistributionType.InverseGaussian, true ) );

            grp = Add( new MarkerGroupDefinition( "A", false, true ) ); //*****
            Add( new MarkerDefinition( grp, "A0", DistributionType.Gaussian ) );
            Add( new MarkerDefinition( grp, "A2", DistributionType.Lognormal, DistributionType.Logistic ) );
            Add( new MarkerDefinition( grp, "A4", DistributionType.Lognormal, DistributionType.Logistic ) );
            // Add( new MarkerDefinition( grp, "AD", DistributionType.Lognormal, true ) );
            Add( new MarkerDefinition( grp, "AS", DistributionType.Gaussian ) );
            // Add( new MarkerDefinition( grp, "L0", DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "L2", DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "L4", DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "LD", DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "LS", DistributionType.Lognormal, true ) );
            Add( new MarkerDefinition( grp, "M0", DistributionType.Gaussian ) ); // !! unclear shape
            Add( new MarkerDefinition( grp, "M2", DistributionType.Logistic ) ); // !! unclear shape
            Add( new MarkerDefinition( grp, "M4", DistributionType.Logistic ) );
            // Add( new MarkerDefinition( grp, "MD", DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "MS", DistributionType.Lognormal, true ) );
            // Add( new MarkerDefinition( grp, "H0", DistributionType.Gaussian, true ) );
            Add( new MarkerDefinition( grp, "H2", DistributionType.Logistic ) ); // !! unclear shape
            // Add( new MarkerDefinition( grp, "H4", DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "HD", DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "HS", DistributionType.Lognormal, true ) );

            grp = Add( new MarkerGroupDefinition( "An" ) ); //*****
            // Add( new MarkerDefinition( grp, "A0", DistributionType.Gaussian, true ) );
            Add( new MarkerDefinition( grp, "A2", DistributionType.Logistic ) );
            Add( new MarkerDefinition( grp, "A4", DistributionType.Weibull ) );
            Add( new MarkerDefinition( grp, "AD", DistributionType.Weibull ) );
            Add( new MarkerDefinition( grp, "AS", DistributionType.Weibull ) );
            // Add( new MarkerDefinition( grp, "L0", DistributionType.Gaussian, true ) );
            Add( new MarkerDefinition( grp, "L2", DistributionType.Logistic ) );
            Add( new MarkerDefinition( grp, "L4", DistributionType.Weibull ) );
            Add( new MarkerDefinition( grp, "LD", DistributionType.Weibull ) );
            Add( new MarkerDefinition( grp, "LS", DistributionType.Weibull ) );
            // Add( new MarkerDefinition( grp, "M0", DistributionType.Gaussian, true ) );
            Add( new MarkerDefinition( grp, "M2", DistributionType.Logistic ) );
            // Add( new MarkerDefinition( grp, "M4", DistributionType.Gaussian, true ) );
            Add( new MarkerDefinition( grp, "MD", DistributionType.Weibull ) );
            Add( new MarkerDefinition( grp, "MS", DistributionType.Weibull ) );
            // Add( new MarkerDefinition( grp, "H0", DistributionType.Gaussian, true ) );
            Add( new MarkerDefinition( grp, "H2", DistributionType.Logistic ) );
            Add( new MarkerDefinition( grp, "H4", DistributionType.Logistic ) ); // !! unclear shape, diracs
            Add( new MarkerDefinition( grp, "HD", DistributionType.Weibull ) );
            Add( new MarkerDefinition( grp, "HS", DistributionType.Weibull ) );

            grp = Add( new MarkerGroupDefinition( "Afi" ) ); //*****
            // Add( new MarkerDefinition( grp, "A0", DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "A2", DistributionType.Gaussian ) );
            // Add( new MarkerDefinition( grp, "A4", DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "AD", DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "AS", DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "L0", DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "L2", DistributionType.Logistic, true ) );
            // Add( new MarkerDefinition( grp, "L4", DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "LD", DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "LS", DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "M0", DistributionType.Gaussian, true ) );
            Add( new MarkerDefinition( grp, "M2", DistributionType.Logistic ) );
            // Add( new MarkerDefinition( grp, "M4", DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "MD", DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "MS", DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "H0", DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "H2", DistributionType.Logistic, true ) );
            // Add( new MarkerDefinition( grp, "H4", DistributionType.Logistic, true ) );
            // Add( new MarkerDefinition( grp, "HD", DistributionType.Gaussian, true ) );
            // Add( new MarkerDefinition( grp, "HS", DistributionType.Gaussian, true ) );
        }

        private static void Add( MarkerDefinition definition )
        {
            markers.Add( definition.Name, definition );
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
            const bool SMOOTHED = false;

            values["."] = 0.0;

            Type = type;
            Button = button;
            Input = input;

            var count = 0;
            var sd = 0.0;
            var si = 0.0;
            var ti = 0.0;

            SmootherOutput smoothed = null;
            if( SMOOTHED )
            {
                smoothed = Smoother.Smooth( input );
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
                si += ds;
                ti += dt;
                siList.Add( si );

                if( dt > 0.0 && ds > 0.0 )
                {
                    // coordinates
                    xList.Add( X ); //**** FRED
                    yList.Add( Y ); //**** FRED

                    // path curvature -- USED
                    // angular velocity
                    double vfixy = Math.Atan2( dY, dX );
                    double vfitn = double.IsNaN( vfixyPrev ) ? 0.0 : Event.fitn( vfixyPrev, vfixy );
                    vfixyPrev = vfixy;
                    if( vfiList.Count > 0 )
                    {
                        var dFiTN = vfitn - vfiList.Last();

                        var fcs = dFiTN / ds;
                        if( FcsList.Count > 0 )
                        {
                            var fpcs = FcsList.Last();
                            FdcsList.Add( ( fcs - fpcs ) / ds ); //**** FRED
                        }
                        // if( Math.Abs( fcs ) > 0.0 )
                        // FcsList.Add( -Math.Log( Math.Abs( fcs ) ) ); //**** FRED
                        FcsList.Add( fcs ); //**** FRED

                        var w = dFiTN / dt;
                        if( wList.Count > 0 )
                        {
                            var wp = wList.Last();
                            dwList.Add( ( w - wp ) / dt ); //****
                        }
                        wList.Add( w ); //**** FRED
                    }
                    vfiList.Add( vfitn ); //**** FRED

                    // velocity as vector
                    var vx = dX / dt;
                    var vy = dY / dt;
                    var v = Math.Sqrt( vx*vx + vy*vy );
                    var vn = v * Math.Sin( vfitn );
                    var vt = v * Math.Cos( vfitn );
                    vtList.Add( vt ); //****
                    vnList.Add( vn ); //****

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
                        var afixy = Math.Atan2( ay, ax );
                        var afi = Event.fitn( afixyPrev, afixy );
                        afixyPrev = afixy;

                        var a = Math.Sqrt( ax*ax + ay*ay );
                        var an = a * Math.Sin( afi );
                        var at = a * Math.Cos( afi );
                        aList.Add( a ); //****
                        atList.Add( at ); //****
                        anList.Add( an ); //****

                        if( v > 0.0 && afiList.Count > 0 )
                        {
                            caList.Add( ( afi - afiList.Last() ) / v ); //****
                        }
                        afiList.Add( afi ); //****
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

            var grp = StrokeFeatureDefinition.Group( "Si" ); if( grp != null ) {
                values["Si"] = grp.Transform( si );
            }
            AnalyzeList( "rSi", siList.Select( sii => sii /si ).ToList<double>(), true );

            grp = StrokeFeatureDefinition.Group( "Ti" ); if( grp != null )
            {
                values["Ti"] = grp.Transform( ti );
            }
            grp = StrokeFeatureDefinition.Group( "CSi" ); if( grp != null )
            {
                values["CSi"] = grp.Transform( FcsList.Sum() );
            }

            grp = StrokeFeatureDefinition.Group( "Sd" ); if( grp != null )
            {
                values["Sd"] = grp.Transform( sd );
            }
            grp = StrokeFeatureDefinition.Group( "Vd" ); if( grp != null )
            {
                values["Vd"] = grp.Transform( sd / ti );
            }
            // values["CSd"] = StrokeFeatureDefinition.Group( "CSd" ).Transform( ( si - sd ) / ( 1.0 + sd ) / si ); // TODO separate group

            grp = StrokeFeatureDefinition.Group( "St" ); if( grp != null )
            {
                values["St"] = grp.Transform( 1.0 - sd / si + 0.000001 );
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

            AnalyzeList( "Afi", afiList, true );

            /*
            var vtList = new List<double>();

            var atList = new List<double>();
            */
        }

        public bool IsValid
        {
            get { return values["."] == 1.0; }
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

        private void AnalyzeList( string name, IEnumerable<double> inputlist, bool skipBoundaries = false )
        {
            var def = StrokeFeatureDefinition.Group( name );
            var c = inputlist.Count();
            if( def == null || c == 0 )
            {
                StoreNaNMarkers( name );
                return;
            }

            var transformed = def.Transform( inputlist );
            IEnumerable<double> list = transformed;
            if( skipBoundaries )
            {
                var lbound = transformed.Min();
                var hbound = transformed.Max();
                list = transformed.Where( i => i != lbound && i != hbound );
            }

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
                    if( double.IsNaN( value ) )
                    {
                        throw new Exception();
                    }
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
                ComputeMarkersForItems( computeId, TypedItems.Where( i => i.IsValid && i.Type == StrokeFeatureItem.ItemType.MoveEnded ), "m" );
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
                }

                _Markers.AddRange( extractor.Extract( computeId, this, nonNull,
                    namePrefix + def.Name,
                    f => ( (StrokeFeatureItem)f ).Value( def.Name ),
                    def.HistogramDefinition ) );
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
                    input.dT >= TIME_THRESHOLD ) // so try time criterion
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
                    clickedInput[button] = null;
                }
            }
        }

        private static double DRAG_MOVEMENT_THRESHOLD = 3;
        private static double LENGTH_THRESHOLD = 4;
        private static double TIME_THRESHOLD = 32;
        private Dictionary<Event.Button, Event> clickedInput = new Dictionary<Event.Button, Event>();
        private List<Event> buffer;
    }
}
