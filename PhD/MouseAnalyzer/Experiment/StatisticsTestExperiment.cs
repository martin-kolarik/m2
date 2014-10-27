using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using MouseAnalyzer.Statistics;

namespace MouseAnalyzer.Experiment
{
    class StatisticsTestExperiment : IExperiment
    {
        private static double[] binmidpoints = {
            0.0152863207, 0.0458589622, 0.0764316037, 0.1070042451, 0.1375768866, 0.1681495281, 0.1987221695, 0.229294811, 0.2598674525, 0.2904400939,
            0.3210127354, 0.3515853768, 0.3821580183, 0.4127306598, 0.4433033012, 0.4738759427, 0.5044485842, 0.5350212256, 0.5655938671, 0.5961665086,
            0.62673915, 0.6573117915, 0.687884433, 0.7184570744, 0.7490297159, 0.7796023574, 0.8101749988, 0.8407476403, 0.8713202818, 0.9018929232,
            0.9324655647, 0.9630382062, 0.9936108476, 1.0241834891, 1.0547561305, 1.085328772, 1.1159014135, 1.1464740549, 1.1770466964, 1.2076193379,
            1.2381919793, 1.2687646208, 1.2993372623, 1.3299099037, 1.3604825452, 1.3910551867, 1.4216278281, 1.4522004696, 1.4827731111, 1.5133457525,
            1.543918394, 1.5744910355, 1.6050636769, 1.6356363184, 1.6662089599, 1.6967816013, 1.7273542428, 1.7579268842, 1.7884995257, 1.8190721672,
            1.8496448086, 1.8802174501, 1.9107900916, 1.941362733, 1.9719353745, 2.002508016, 2.0330806574, 2.0636532989, 2.0942259404, 2.1247985818,
            2.1553712233, 2.1859438648, 2.2165165062, 2.2470891477, 2.2776617892, 2.3082344306, 2.3388070721, 2.3693797136, 2.399952355, 2.4305249965,
            2.4610976379, 2.4916702794, 2.5222429209, 2.5528155623, 2.5833882038, 2.6139608453, 2.6445334867, 2.6751061282, 2.7056787697, 2.7362514111,
            2.7668240526, 2.7973966941, 2.8279693355, 2.858541977, 2.8891146185, 2.9196872599, 2.9502599014, 2.9808325429, 3.0114051843, 3.0419778258,
            3.0725504673, 3.1031231087, 3.1336957502, 3.1642683916, 3.1948410331, 3.2254136746, 3.255986316, 3.2865589575, 3.317131599, 3.3477042404,
            3.3782768819, 3.4088495234, 3.4394221648, 3.4699948063, 3.5005674478, 3.5311400892, 3.5617127307, 3.5922853722, 3.6228580136, 3.6534306551,
            3.6840032966, 3.714575938, 3.7451485795, 3.775721221, 3.8062938624, 3.8368665039, 3.8674391453, 3.8980117868, 3.9285844283, 3.9591570697,
            3.9897297112, 4.0203023527, 4.0508749941, 4.0814476356, 4.1120202771, 4.1425929185, 4.17316556, 4.2037382015, 4.2343108429, 4.2648834844,
            4.2954561259, 4.3260287673, 4.3566014088, 4.3871740503, 4.4177466917, 4.4483193332, 4.4788919747, 4.5094646161, 4.5400372576, 4.570609899,
            4.6011825405, 4.631755182, 4.6623278234, 4.6929004649, 4.7234731064, 4.7540457478, 4.7846183893, 4.8151910308, 4.8457636722, 4.8763363137,
            4.9069089552, 4.9374815966, 4.9680542381, 4.9986268796, 5.029199521, 5.0597721625, 5.090344804, 5.1209174454, 5.1514900869, 5.1820627284,
            5.2126353698, 5.2432080113, 5.2737806527, 5.3043532942, 5.3349259357, 5.3654985771, 5.3960712186, 5.4266438601, 5.4572165015, 5.487789143,
            5.5183617845, 5.5489344259, 5.5795070674, 5.6100797089, 5.6406523503, 5.6712249918, 5.7017976333, 5.7323702747, 5.7629429162, 5.7935155577,
            5.8240881991, 5.8546608406, 5.885233482, 5.9158061235, 5.946378765, 5.9769514064, 6.0075240479, 6.0380966894, 6.0686693308, 6.0992419723
        };

        private static double[] frequencies = {
            318, 124, 110, 109, 82, 97, 88, 58, 53, 67,
            63, 48, 60, 60, 50, 67, 67, 73, 47, 49,
            54, 43, 53, 45, 61, 36, 65, 42, 44, 52,
            51, 45, 52, 47, 50, 39, 37, 58, 40, 53,
            41, 41, 55, 43, 52, 48, 45, 52, 43, 43,
            24, 37, 52, 52, 47, 54, 36, 49, 39, 30,
            54, 36, 39, 35, 42, 37, 28, 41, 36, 24,
            30, 50, 35, 28, 43, 23, 24, 32, 20, 33,
            28, 24, 28, 19, 16, 16, 14, 16, 18, 23,
            21, 13, 21, 16, 24, 18, 16, 22, 21, 12,
            25, 16, 10, 17, 15, 13, 13, 10, 15, 9,
            8, 7, 8, 10, 14, 15, 10, 3, 10, 7,
            7, 7, 11, 6, 11, 14, 6, 6, 6, 4,
            8, 3, 2, 3, 0, 4, 8, 2, 5, 5,
            5, 4, 1, 2, 3, 3, 3, 4, 4, 2,
            0, 0, 4, 1, 1, 2, 0, 0, 0, 1,
            1, 1, 0, 1, 1, 0, 0, 1, 0, 0,
            0, 0, 0, 2, 0, 0, 1, 0, 0, 0,
            0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 1
        };

        #region IExperiment Members

        public void Perform( string outputFileNameHint = "" )
        {
            var data = new List<double>();

            for( int i = 0; i < binmidpoints.Length; i++ )
            {
                for( int j = 0; j < frequencies[i]; j++ )
                {
                    data.Add( binmidpoints[i] );
                }
            }

            var min = data.Min();
            var max = data.Max();
            var spread = max - min;
            var bw = spread / 200;
            spread = max - min + bw;
            bw = spread / 200;

            var histogramDefinition = new HistogramDefinition( 200 );
            histogramDefinition.SupplyRange( min - bw / 2, max + bw / 2 );
            var histogram = new HistogramMarker( null, null, null, null, null, histogramDefinition, data );

            var nde = new GaussianDatasetEstimate( data, false, 0.0, 0.0 );
            var nhe = new GaussianHistogramEstimate( histogram );

            var lgde = new LogisticDatasetEstimate( data, false );
            var lghe = new LogisticHistogramEstimate( histogram );

            var lnde = new LognormalDatasetEstimate( data, false );
            var lnhe = new LognormalHistogramEstimate( histogram );

            var igde = new InverseGaussianDatasetEstimate( data, false );
            var ighe = new InverseGaussianHistogramEstimate( histogram );

            var wde = new WeibullDatasetEstimate( data, false );
            var whe = new WeibullHistogramEstimate( histogram );

            var gde = new GammaDatasetEstimate( data, false );
            var ghe = new GammaHistogramEstimate( histogram );

            var rde = new RayleighDatasetEstimate( data, false );
            var rhe = new RayleighHistogramEstimate( histogram );

            double[] samples = { 1.0, 2.0, 3.0, 4.0, 5.0, 6.0 };
            double[] ndf = new double[samples.Length];
            double[] nhf = new double[samples.Length];
            double[] lgdf = new double[samples.Length];
            double[] lghf = new double[samples.Length];
            double[] lndf = new double[samples.Length];
            double[] lnhf = new double[samples.Length];
            double[] igdf = new double[samples.Length];
            double[] ighf = new double[samples.Length];
            double[] wdf = new double[samples.Length];
            double[] whf = new double[samples.Length];
            double[] gdf = new double[samples.Length];
            double[] ghf = new double[samples.Length];
            double[] rdf = new double[samples.Length];
            double[] rhf = new double[samples.Length];

            for( int i = 0; i < samples.Length; i++ )
            {
                ndf[i] = nde.f( samples[i] );
                nhf[i] = nhe.f( samples[i] );

                lgdf[i] = lgde.f( samples[i] );
                lghf[i] = lghe.f( samples[i] );

                lndf[i] = lnde.f( samples[i] );
                lnhf[i] = lnhe.f( samples[i] );

                igdf[i] = igde.f( samples[i] );
                ighf[i] = ighe.f( samples[i] );

                wdf[i] = wde.f( samples[i] );
                whf[i] = whe.f( samples[i] );

                gdf[i] = gde.f( samples[i] );
                ghf[i] = ghe.f( samples[i] );

                rdf[i] = rde.f( samples[i] );
                rhf[i] = rhe.f( samples[i] );
            }

            return;
        }

        #endregion
    }
}
