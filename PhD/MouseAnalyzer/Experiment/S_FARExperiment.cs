using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using MouseAnalyzer.Statistics;

namespace MouseAnalyzer.Experiment
{
    class S_FARExperiment : IExperiment
    {

        #region IExperiment Members

        public void Perform( string outputFileNameHint = "" )
        {
            var CFG_TRAIN = true;
            var CFG_TEST = false;

            var CFG_BAYESES = true;
            var CFG_SAMPLES_PER_ENTITY = 1;
            var CFG_ITEMS_PER_SAMPLE = 1;

            var CFG_EER = !CFG_BAYESES;
            var CFG_RELTARGET = 0.001;
            var CFG_ABSTARGET = CFG_BAYESES ? 0.001 : 0.001;

            var dumper = new CSVDumper();
            
            var entities = DataSources.Get( DataSource.EnvironmentType.ControlledPlain, DataSource.SourceType.API );
            entities.Sort( ( e1, e2 ) => e1.Id.CompareTo( e2.Id ) );

            // probing needs separate entities
            var probeEntities = new List<Lookup.ProbeEntity>();
            foreach( var entity in entities )
            {
                probeEntities.Add( new Lookup.ProbeEntity( entity, DataSource.SourceType.API, entity.Events ) );
            }

            var farSplit = new SplitDefinition()
            {
                Fractions = 2,
                Fraction = 2
            };
            var farAnalyzer = new Analysis.StrokePopulationAnalysis();
            farAnalyzer.Analyze( probeEntities, farSplit, true );

            // create markers from first probe
            var distributionMarkers = probeEntities.First().Markers.Where( m1 => m1 is IDistributionMarker && !m1.Name.StartsWith( "h" ) ).Select( m2 => (IDistributionMarker)m2 );

            // test input data
            var entitiesTrained = new List<Tuple<Entity, Features.Markers>>();

            // training pass
            if( CFG_TRAIN )
            {
                // split dataset to training and FAR probing parts
                var trainingSplit = new SplitDefinition()
                {
                    Fractions = 2,
                    Fraction = 1
                };
                var trainingAnalyzer = new Analysis.StrokePopulationAnalysis();
                trainingAnalyzer.Analyze( entities, trainingSplit );

                // try to determine best markers for each entity
                var results = new List<Tuple<Entity, Features.Markers, IList<EERProgress>>>();
                var selectionRepeatCount = 1;
                for( var s = 0; s < selectionRepeatCount; s++ )
                {
                    foreach( var entity in entities ) // .Where( e => e.Id == "HoMcp" ))
                    {
                        Executor.Queue( () =>
                        {
                            var markers = new Features.Markers();
                            markers.AddMarkers( distributionMarkers );

                            var result = new Tuple<Entity, Features.Markers, IList<EERProgress>>
                            (
                                entity,
                                markers,
                                SelectMarkers( CFG_BAYESES, CFG_EER, markers, entity, probeEntities, CFG_SAMPLES_PER_ENTITY, CFG_ITEMS_PER_SAMPLE, CFG_ABSTARGET, CFG_RELTARGET ) // probeEntities.Where( p => p.Related == entity ).First() )
                            );

                            lock( results )
                            {
                                results.Add( result );
                            }
                        } );
                    }
                }
                Executor.Complete();
                results.Sort( ( r1, r2 ) => r1.Item1.Id.CompareTo( r2.Item1.Id ) );

                var CFGDUMP_DEVELOPMENT = true;
                var CFGDUMP_DETAILS = true;
                var CFGDUMP_DETAILS_BAYESES = true && CFG_BAYESES;
                var CFGDUMP_DETAILS_EER = true && !CFG_BAYESES;
                var CFGDUMP_DETAILS_MATRIX = true;
                var CFGDUMP_DETAILS_GROUP = true;

                dumper.AddContent(
                    ( CFG_BAYESES ? "TRAIN BAYESES " : "TRAIN EER" ) +
                    ", samples/entity = " + CFG_SAMPLES_PER_ENTITY.ToString() +
                    ", items/sample = " + CFG_ITEMS_PER_SAMPLE.ToString(),
                    d =>
                    {
                        Dictionary<Entity, Features.Markers> lastMarkers = new Dictionary<Entity, Features.Markers>();

                        if( CFGDUMP_DEVELOPMENT )
                        {
                            d.Cell( "development" );
                            foreach( var result in results )
                            {
                                d.CellsE( result.Item1.Id + ".name", false, result.Item3.Select( r => (object)r.name ) );
                                d.CellsE( result.Item1.Id + ".eer", false, result.Item3.Select( r => r.eer.Item2.ToString( "G5" ) ) );
                                d.CellsE( result.Item1.Id + ".pby", false, result.Item3.Select( r => r.p.ToString( "G5" ) ) );
                            }
                        }

                        if( CFGDUMP_DETAILS )
                        {
                            List<string> headers = null;
                            List<IEnumerable<object>> columns = null;
                            string previousId = null;

                            foreach( var result in results )
                            {
                                if( !CFGDUMP_DETAILS_GROUP || result.Item1.Id != previousId )
                                {
                                    if( previousId != null )
                                    {
                                        d.Columns( headers, columns );
                                    }
                                    headers = new List<string>();
                                    columns = new List<IEnumerable<object>>();

                                    d.Cell( "" );
                                    d.Cell( result.Item1.Id + " detail" );
                                }

                                headers.Add( "ord *****" );
                                columns.Add( result.Item3.Select( i => (object)i.order ) );
                                headers.Add( "marker" );
                                columns.Add( result.Item3.Select( i => i.name ) );
                                headers.Add( "markerX" );
                                columns.Add( result.Item3.Select( i =>
                                {
                                    var strokeMarkerName = i.name.Substring( 0, i.name.Length-3 ).Remove( 0, 1 );
                                    var item = i.samples.Where( p => p.Item1 == result.Item1 && p.Item3 == 0 ).Select( p => p.Item2 ).First().First();
                                    return ( (StrokeFeatureItem)item ).Value( strokeMarkerName ).ToString( "G5" );
                                } ) );
                                headers.Add( "EERX" );
                                columns.Add( result.Item3.Select( i => i.eer.Item1.ToString( "G5" ) ) );
                                headers.Add( "EERY" );
                                columns.Add( result.Item3.Select( i => i.eer.Item2.ToString( "G5" ) ) );
                                headers.Add( "Pbayes" );
                                columns.Add( result.Item3.Select( i => i.p.ToString( "G5" ) ) );
                                headers.Add( "-" );
                                columns.Add( new List<string>() { "-" } );

                                if( CFGDUMP_DETAILS_BAYESES )
                                {
                                    for( var i = 0; i < result.Item3.Count; i++ )
                                    {
                                        var resultItem = result.Item3[i];
                                        var name = resultItem.name;
                                        var strokeMarkerName = name.Substring( 0, name.Length-3 ).Remove( 0, 1 );

                                        headers.Add( i.ToString( "D2" ) + ".bayeses id" );
                                        headers.Add( i.ToString( "D2" ) + "." + strokeMarkerName + ".X" );
                                        headers.Add( i.ToString( "D2" ) + ".bayeses p" );
                                        headers.Add( "-" );
                                        columns.Add( resultItem.bayeses.Select( b => b.Item1.Id ) );
                                        columns.Add( resultItem.samples.Where( p => p.Item3 == 0 ).SelectMany( p => p.Item2 ).Take( entities.Count ).Select( fi =>
                                        {
                                            return ( (StrokeFeatureItem)fi ).Value( strokeMarkerName ).ToString( "G5" );
                                        } ) );
                                        columns.Add( result.Item3[i].bayeses.Select( b => b.Item2.ToString( "G5" ) ) );
                                        columns.Add( new List<string>() { "-" } );
                                    }
                                }

                                if( CFGDUMP_DETAILS_EER )
                                {
                                    for( var i = 0; i < result.Item3.Count; i++ )
                                    {
                                        headers.Add( i.ToString( "D2" ) + ".fmr S(x)" );
                                        headers.Add( i.ToString( "D2" ) + ".fmr R(y)" );
                                        headers.Add( i.ToString( "D2" ) + ".fnmr S(x)" );
                                        headers.Add( i.ToString( "D2" ) + ".fnmr R(y)" );
                                        headers.Add( "-" );
                                        columns.Add( result.Item3[i].eer.Item3.Select( f => (object)f.Item1 ) );
                                        columns.Add( result.Item3[i].eer.Item3.Select( f => (object)f.Item2 ) );
                                        columns.Add( result.Item3[i].eer.Item4.Select( f => (object)f.Item1 ) );
                                        columns.Add( result.Item3[i].eer.Item4.Select( f => (object)f.Item2 ) );
                                        columns.Add( new List<string>() { "-" } );
                                    }
                                }

                                lastMarkers[result.Item1] = result.Item2;

                                previousId = result.Item1.Id;
                            }

                            // flush last
                            d.Columns( headers, columns );

                            if( CFGDUMP_DETAILS && CFGDUMP_DETAILS_MATRIX )
                            {
                                headers = new List<string>();
                                columns = new List<IEnumerable<object>>();

                                headers.Add( "marker" );
                                columns.Add( lastMarkers.First().Value.Names );

                                foreach( var markers in lastMarkers )
                                {
                                    headers.Add( markers.Key.Id );
                                    columns.Add( markers.Value.Actives.Components.Select( m => m.ToString( "G5" ) ) );
                                }

                                d.Columns( headers, columns );
                            }
                        }
                    } );

                // store values
                foreach( var entity in entities )
                {
                    entitiesTrained.Add( new Tuple<Entity, Features.Markers>( entity, results.Where( r => r.Item1 == entity ).Last().Item2 ) );
                }
                Serialize( "Markers.txt", entitiesTrained );
            }

            if( CFG_TEST )
            {
                var CFG_TEST_REPEATSPERENTITY = 5;
                var CFG_TEST_SAMPLESPERENTITYUPTO = 2;
                var CFG_TEST_ITEMSPERSAMPLEUPTO = 100;

                foreach( var entity in entities )
                {
                    var markers = new Features.Markers();
                    markers.AddMarkers( distributionMarkers );
                    entitiesTrained.Add( new Tuple<Entity, Features.Markers>( entity, markers ) );
                }
                Deserialize( "Markers.txt", ref entitiesTrained );

                var testResults = Test( entitiesTrained, probeEntities, CFG_TEST_REPEATSPERENTITY, CFG_TEST_SAMPLESPERENTITYUPTO, CFG_TEST_ITEMSPERSAMPLEUPTO );

                dumper.AddContent( "TEST EER",
                    d =>
                    {
                        d.Cell( "i/s development" );

                        var headers = new List<string>();
                        var columns = new List<IEnumerable<object>>();

                        for( var i = 1; i <= CFG_TEST_SAMPLESPERENTITYUPTO; i++ )
                        {
                            headers.Add( "s/e = " + i.ToString() + " mean" );
                            headers.Add( "s/e = " + i.ToString() + " dev" );
                            headers.Add( "-" );

                            var means = new List<double>();
                            var deviations = new List<double>();
                            for( var j = 1; j <= CFG_TEST_ITEMSPERSAMPLEUPTO; j++ )
                            {
                                var eers = testResults.Where( r => r.samplesPerEntity == i && r.itemsPerSample == j ).Select( r => r.eer.Item2 );
                                means.Add( eers.Average() );
                                deviations.Add( Math.Sqrt( eers.Variance() ) );
                            }

                            columns.Add( means.Select( mean => mean.ToString( "G5" ) ) );
                            columns.Add( deviations.Select( dev => dev.ToString( "G5" ) ) );
                            columns.Add( new List<string>() { "-" } );
                        }
    
                        d.Columns( headers, columns );

                        d.Cell( "s/e development" );

                        headers = new List<string>();
                        columns = new List<IEnumerable<object>>();

                        for( var i = 1; i <= CFG_TEST_ITEMSPERSAMPLEUPTO; i++ )
                        {
                            headers.Add( "i/s = " + i.ToString() + " mean" );
                            headers.Add( "i/s = " + i.ToString() + " dev" );
                            headers.Add( "-" );

                            var means = new List<double>();
                            var deviations = new List<double>();
                            for( var j = 1; j <= CFG_TEST_SAMPLESPERENTITYUPTO; j++ )
                            {
                                var eers = testResults.Where( r => r.samplesPerEntity == j && r.itemsPerSample == i ).Select( r => r.eer.Item2 );
                                means.Add( eers.Average() );
                                deviations.Add( Math.Sqrt( eers.Variance() ) );
                            }

                            columns.Add( means.Select( mean => mean.ToString( "G5" ) ) );
                            columns.Add( deviations.Select( dev => dev.ToString( "G5" ) ) );
                            columns.Add( new List<string>() { "-" } );
                        }
    
                        d.Columns( headers, columns );
                    }
                );
            }

            dumper.Dump( outputFileNameHint == "" ? "s-f" : outputFileNameHint );
        }

        #endregion

        private List<EERProgress> SelectMarkers( bool BAYESES, bool EER, Features.Markers markers, Entity entity, IEnumerable<Lookup.ProbeEntity> probes, int samplesPerEntity, int itemsPerSample, double absTarget, double relTarget )
        {
            var probesCount = probes.Count();
            var imposters = probesCount - 1;

            var imposterSamples = samplesPerEntity;
            var genuineSamples = samplesPerEntity * imposters; // the same count

            // initialize -- prepare data
            var samples = CreateSamples( entity, probes, genuineSamples, imposterSamples, itemsPerSample, false );

            // clear markers
            for( var i = 0; i < markers.Count; i++ )
            {
                markers.SetActive( i, false );
            }

            List<EERProgress> progress = new List<EERProgress>();
            HashSet<int> used = new HashSet<int>();

            var targetTest0 = double.MaxValue;
            var targetTest1 = double.MaxValue;
            var targetTest2 = double.MaxValue;
            var besteer = new Tuple<double, double, List<Tuple<double, double>>, List<Tuple<double, double>>>( 0.0, double.MaxValue, null, null );
            var bestp = 0.0;
            IEnumerable<Tuple<Entity, double>> bestbayeses = null;

            for( var j = 0; j < markers.Count; j++ )
            {
                var besteeri = -1;
                var bestpi = -1;

                for( var i = 0; i < markers.Count; i++ )
                {
                    if( used.Contains( i ) )
                    {
                        continue;
                    }
                    markers.SetActive( i, true );

                    // preparation of baesian probabilities
                    var priors = ComputePriors( entity, markers, samples );
                    var posteriors = ComputePosteriors( entity, priors, genuineSamples, imposterSamples );

                    // evaluate bayeses
                    /*
                    var tpmine = 0.0;
                    for( var l = 0; l < imposterSamples; l++ )
                    {
                        var tsum = matches.Where( m => m.Item3 == l ).Select( m => m.Item2 ).Sum();
                        var tmine = matches.Where( m => m.Item3 == l && m.Item1 == entity ).Select( m => m.Item2 ).First();
                        tpmine += Math.Log( tmine / tsum );
                    }
                    tpmine /= imposterSamples;
                    tpmine = Math.Exp( tpmine );
                    // var tmine = matches.Where( m => m.Item3 < imposterSamples && m.Item1 == entity ).Select( m => 100.0 * m.Item2 ).Product();
                    // var tpmine = tmine / ttotal;
                    */

                    var ibayeses = posteriors.Where( m => m.Item3 == 0 ).Select( s => new Tuple<Entity, double>( s.Item1, s.Item2 ) );
                    var ipmine = posteriors.Where( m => m.Item3 == 0 && m.Item1 == entity ).Select( m => m.Item2 ).First();

                    var pmine = ipmine;
                    var bayeses = ibayeses;
                    var newBest = false;
                    if( BAYESES )
                    {
                        if( pmine > bestp )
                        {
                            newBest = true;
                            bestp = pmine;
                            bestpi = i;
                            bestbayeses = bayeses;
                        }
                    }

                    // compute eer
                    if( EER || newBest )
                    {
                        var eer = ComputeEER( entity, posteriors );

                        // evaluate eer 
                        if( eer.Item2 < besteer.Item2 )
                        {
                            besteer = eer;
                            besteeri = i;
                            bestbayeses = bayeses; // off topic
                            bestp = pmine; // off topic
                        }
                        else if( newBest )
                        {
                            besteer = eer;
                        }
                    }

                    markers.SetActive( i, false );
                }

                if( BAYESES )
                {
                    if( bestpi == -1 )
                    {
                        break; // nothing found
                    }
                    markers.SetActive( bestpi, true );
                    used.Add( bestpi );

                    progress.Add( new EERProgress()
                    {
                        order = j,
                        index = bestpi,
                        name = markers.IndexToName( bestpi ),
                        p = bestp,
                        bayeses = bestbayeses,
                        samples = samples,

                        eer = besteer,
                    } );

                    targetTest2 = targetTest1;
                    targetTest1 = targetTest0;
                    targetTest0 = 1.0 - bestp;
                }

                if( EER )
                {
                    if( besteeri == -1 )
                    {
                        break; // nothing found
                    }
                    markers.SetActive( besteeri, true );
                    used.Add( besteeri );

                    progress.Add( new EERProgress()
                    {
                        order = j,
                        index = besteeri,
                        name = markers.IndexToName( besteeri ),
                        eer = besteer,
                        p = bestp,

                        bayeses = bestbayeses,
                        samples = samples
                    } );

                    targetTest2 = targetTest1;
                    targetTest1 = targetTest0;
                    targetTest0 = besteer.Item2;
                }

                if( targetTest0 <= absTarget ) // SEARCH STOP CONDITION
                {
                    break;
                }
                else if( Math.Abs( targetTest2 - targetTest1 ) <= relTarget && 
                         Math.Abs( targetTest1 - targetTest0 ) <= relTarget )
                {
                    break;
                }
            }

            return progress;
        }

        private List<Tuple<Entity, IEnumerable<IFeatureItem>, int>> CreateSamples( Entity genuine, IEnumerable<Lookup.ProbeEntity> probes, int genuineSamples, int imposterSamples, int itemsPerSample, bool random )
        {
            var rnd = new Random();
            var inputs = new List<Tuple<Entity, IEnumerable<IFeatureItem>, int>>();

            foreach( var probe in probes )
            {
                var items = probe.Features.Where( f1 => f1 is StrokeFeature ).Select( f2 => (StrokeFeature)f2 ).First().
                            TypedItems.Where( i => i.IsValid && !i.IsStraight && i.Type == StrokeFeatureItem.ItemType.MoveEnded );
                var count = items.Count();
                for( var i = 0; i < (probe.Related == genuine ? genuineSamples : imposterSamples); i++ )
                {
                    IEnumerable<IFeatureItem> selected;
                    if( random )
                    {
                        selected = items.Skip( rnd.Next( count - itemsPerSample ) ).Take( itemsPerSample );
                    }
                    else
                    {
                        selected = items.Skip( 7+i ).Take( itemsPerSample );
                    }
                    inputs.Add( new Tuple<Entity, IEnumerable<IFeatureItem>, int>( probe.Related, selected, i ) );
                }
            }

            return inputs;
        }

        private List<Tuple<Entity, double, int>> ComputePriors( Entity against, Features.Markers markers, List<Tuple<Entity, IEnumerable<IFeatureItem>, int>> samples )
        {
            var priors = new List<Tuple<Entity, double, int>>();
            foreach( var sample in samples )
            {
                var ps = against.Match( markers, sample.Item2, MatchType.DistributionProductPercent, true );
                if( ps.Count != sample.Item2.Count() )
                {
                    throw new Exception();
                }

                var p = ps.Product();

                priors.Add( new Tuple<Entity, double, int>( sample.Item1, p, sample.Item3 ) );
            }

            return priors;
        }

        private List<Tuple<Entity, double, int>> ComputePosteriors( Entity of, List<Tuple<Entity, double, int>> priors, int genuineSamples, int imposterSamples )
        {
            var posteriors = new List<Tuple<Entity, double, int>>();

            for( var k = 0; k < genuineSamples; k++ ) // the loop iterates over all genuineSamples, but for each
                                                      // genuine samples it must re-use imposter set. Thus
                                                      // m.Item3 == k % imposterSamples for imposters
            {
                var set = priors.Where( m => m.Item3 == ( m.Item1 == of ? k : k % imposterSamples ) );
                var sum = set.Select( m => m.Item2 ).Sum();

                set.Where( m => m.Item3 == k ).Select( m => // where limits usage of re-used imposter sets
                {
                    posteriors.Add( new Tuple<Entity, double, int>( m.Item1, m.Item2 / sum, m.Item3 ) );
                    return 0;
                } ).Count();
            }

            return posteriors;
        }

        private Tuple<double, double, List<Tuple<double, double>>, List<Tuple<double, double>>> ComputeEER( Entity of, List<Tuple<Entity, double, int>> similarities )
        {
            // similarities contains samples entries were half is genuine and half are imposters
            // fmr/fnmr can be computed and err can be found
            // var ordered = similarities.OrderBy( s => s.Item2 );
            double eerSamples = similarities.Count / 2;
            var gps = similarities.Where( s => s.Item1 == of ).OrderBy( s => s.Item2 );
            var fnmri = 0;
            var fnmrcdf = gps.Select( gp => new Tuple<double, double>( gp.Item2, fnmri++/eerSamples ) ).ToList();
            fnmrcdf.Insert( 0, new Tuple<double, double>( 0.0, 0.0 ) );
            fnmrcdf.Add( new Tuple<double, double>( 1.0, 1.0 ) );

            var ips = similarities.Where( s => s.Item1 != of ).OrderBy( s => s.Item2 );
            var fmri = eerSamples;
            var fmrcdf = ips.Select( ip => new Tuple<double, double>( ip.Item2, fmri--/eerSamples ) ).ToList();
            fmrcdf.Insert( 0, new Tuple<double, double>( 0.0, 1.0 ) );
            fmrcdf.Add( new Tuple<double, double>( 1.0, 0 ) );

            // lookup for same f value = eer
            var eerx = 0.0;
            var eer = double.MaxValue;
            for( var k = 0; k < eerSamples+2-1; k++ ) // 0 and 1 boundaries are always added (+2) and we are constructing segments (-1)
            {
                bool found = false;
                for( var m = 0; m < eerSamples+2-1; m++ )
                {
                    if( SegmentsIntersects(
                        fnmrcdf[k].Item1, fnmrcdf[k].Item2, fnmrcdf[k+1].Item1, fnmrcdf[k+1].Item2,
                        fmrcdf[m].Item1, fmrcdf[m].Item2, fmrcdf[m+1].Item1, fmrcdf[m+1].Item2,
                        out eerx, out eer ) )
                    {
                        found = true;
                        break;
                    }
                }
                if( found )
                {
                    break;
                }
            }

            return new Tuple<double, double, List<Tuple<double, double>>, List<Tuple<double, double>>>( eerx, eer, fmrcdf, fnmrcdf );
        }

        private List<EERTestItem> Test( List<Tuple<Entity, Features.Markers>> determined, IEnumerable<Lookup.ProbeEntity> probes, int runsPerEntity, int samplesPerEntityUpTo, int itemsPerSampleUpTo )
        {
            var results = new List<EERTestItem>();
            var probesCount = probes.Count();
            var imposters = probesCount - 1;

            foreach( var det in determined )
            {
                for( var run = 0; run < runsPerEntity; run++ )
                {
                    for( var samplesPerEntity = 1; samplesPerEntity <= samplesPerEntityUpTo; samplesPerEntity++ )
                    {
                        var imposterSamples = samplesPerEntity;
                        var genuineSamples = samplesPerEntity * imposters;

                        for( var itemsPerSample = 1; itemsPerSample <= itemsPerSampleUpTo; itemsPerSample++ )
                        {
                            var localDet = det;
                            var localSamplesPerEntity = samplesPerEntity;
                            var localImposterSamples = imposterSamples;
                            var localGenuineSamples = genuineSamples;
                            var localItemsPerSample = itemsPerSample;

                            Executor.Queue( () =>
                            {
                                var samples = CreateSamples( localDet.Item1, probes, localGenuineSamples, localImposterSamples, localItemsPerSample, false );
                                var priors = ComputePriors( localDet.Item1, localDet.Item2, samples );
                                var posteriors = ComputePosteriors( localDet.Item1, priors, localGenuineSamples, localImposterSamples );
                                var eer = ComputeEER( localDet.Item1, posteriors );

                                lock( results )
                                {
                                    results.Add( new EERTestItem()
                                    {
                                        entity = localDet.Item1,
                                        samplesPerEntity = localSamplesPerEntity,
                                        itemsPerSample = localItemsPerSample,
                                        eer = new Tuple<double, double>( eer.Item1, eer.Item2 )
                                    } );
                                }
                            } );
                        }
                    }
                }
            }
            Executor.Complete();

            return results;
        }

        private bool SegmentsIntersects( double x11, double y11, double x12, double y12, // first segment
                                         double x21, double y21, double x22, double y22, // second segment
                                         out double ix, out double iy )
        {
            ix = double.NaN;
            iy = double.NaN;

            // rough test
            if( ( x11 < x12 ? x12 : x11 ) < ( x21 < x22 ? x21 : x22 ) || ( x21 < x22 ? x22 : x21 ) < ( x11 < x12 ? x11 : x12 ) ||
                ( y11 < y12 ? y12 : y11 ) < ( y21 < y22 ? y21 : y22 ) || ( y21 < y22 ? y22 : y21 ) < ( y11 < y12 ? y11 : y12 ) )
            {
                return false;
            }

            // first line
            var dx1 = x12 - x11;
            var dy1 = y12 - y11;
            var a1 = dy1;
            var b1 = -dx1;
            var c1 = dx1 * y11 - dy1 * x11;
            // second line
            var dx2 = x22 - x21;
            var dy2 = y22 - y21;
            var a2 = dy2;
            var b2 = -dx2;
            var c2 = dx2 * y21 - dy2 * x21;
            // ?lines intersect
            if( b1 * a2 - b2 * a1 == 0 )
            {
                return false;
            }
            // intersect point
            var y = ( c2 * a1 - c1 * a2 ) / ( b1 * a2 - b2 * a1 );
            double x;
            if( a1 == 0.0 )
            {
                x = -( c2 + b2 * y ) / a2;
            }
            else
            {
                x = -( c1 + b1 * y ) / a1;
            }

            // point is within limits
            if( dx1 > 0 )
            {
                if( x < x11 || x > x12 ) { return false; }
            }
            else
            {
                if( x > x11 || x < x12 ) { return false; }
            }
            if( dx2 > 0 )
            {
                if( x < x21 || x > x22 ) { return false; }
            }
            else
            {
                if( x > x21 || x < x22 ) { return false; }
            }
            if( dy1 > 0 )
            {
                if( y < y11 || y > y12 ) { return false; }
            }
            else
            {
                if( y > y11 || y < y12 ) { return false; }
            }
            if( dy2 > 0 )
            {
                if( y < y21 || y > y22 ) { return false; }
            }
            else
            {
                if( y > y21 || y < y22 ) { return false; }
            }

            ix = x;
            iy = y;

            return true;
        }

        private void Serialize( string filePath, IEnumerable<Tuple<Entity, Features.Markers>> entitiesTrained )
        {
            using( var fileWriter = new StreamWriter( filePath ) )
            {
                foreach( var et in entitiesTrained )
                {
                    fileWriter.WriteLine( et.Item1.Id + ";;o=" + et.Item2.Serialize() );

                    var markers = et.Item1.Markers;
                    var actives = et.Item2.Actives;
                    for( var active = 0; active < actives.ComponentCount; active++ )
                    {
                        if( actives[active] == 1.0 )
                        {
                            var markerName = et.Item2.IndexToName( active );
                            var marker = (IDistributionMarker)markers.Where( m => m.Name == markerName ).First();
                            fileWriter.WriteLine(
                                et.Item1.Id + ";" + markerName +
                                ";v=" + marker.Estimate.Type.ToString() +
                                "=" + String.Join( ",", marker.ParameterNames ) +
                                "=" + String.Join( ",", marker.ParameterValues ));
                        }
                    }
                }
            }
        }

        private void Deserialize( string filePath, ref List<Tuple<Entity, Features.Markers>> entitiesTrained )
        {
            using( var fileReader = new StreamReader( filePath ) )
            {
                while( !fileReader.EndOfStream )
                {
                    var line = fileReader.ReadLine();
                    var items = line.Split( '=' );
                    var markers = items[0].Split( ';' );

                    if( markers[2] == "o" ) // overview
                    {
                        foreach( var et in entitiesTrained )
                        {
                            if( et.Item1.Id == markers[0] )
                            {
                                et.Item2.Deserialize( items[1] );
                                break;
                            }
                        }
                    }
                    else if( markers[2] == "v" ) // values
                    {
                        var markerName = markers[1];
                        var strokeMarkerName = markerName.Substring( 0, markerName.Length-3 ).Remove( 0, 1 );

                        var type = (DistributionType)Enum.Parse( typeof( DistributionType ), items[1] );
                        var names = items[2].Split( ',', ' ' );
                        var values = items[3].Split( ',', ' ' );

                        var distribution = new DistributionStandaloneMarker( markerName, f => ( (StrokeFeatureItem)f ).Value( strokeMarkerName ), type, names.ToList(), values.ToList() );

                        foreach( var et in entitiesTrained )
                        {
                            if( et.Item1.Id == markers[0] )
                            {
                                et.Item1.AddStandaloneMarker( distribution );
                                break;
                            }
                        }
                    }
                    else
                    {
                        throw new Exception( "Unknown item type" );
                    }
                }
            }
        }

        private class EERProgress
        {
            public List<Tuple<Entity, IEnumerable<IFeatureItem>, int>> samples;

            public int order;
            public int index;
            public string name;

            // eer
            public Tuple<double, double, List<Tuple<double,double>>, List<Tuple<double,double>>> eer;

            // bayes
            public double p;
            public IEnumerable<Tuple<Entity, double>> bayeses;
        }

        private class EERTestItem
        {
            public Entity entity;
            public int samplesPerEntity;
            public int itemsPerSample;
            public Tuple<double, double> eer;
        }
    }
}