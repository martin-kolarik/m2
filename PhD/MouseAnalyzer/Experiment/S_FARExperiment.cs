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

        const double CFG_EER_MID_WEIGHT = 1e-3;
        private string DESCRIPTION_STRING;
        private string DESCRIPTION_FILE;

        public void Perform( string outputFileNameHint = "" )
        {
            var CFG_TRAIN = true;
            var CFG_TEST = !CFG_TRAIN;

            var CFG_ENV = DataSource.EnvironmentType.ControlledAccelerated;
            var CFG_SOURCE = DataSource.SourceType.DRV;
            var CFG_RANDOM = false;
            var CFG_SFFS = true;
            var CFG_SFFS_K = 15;
            var CFG_BAYESES = false;
            var CFG_SAMPLES_PER_ENTITY = 1; // 3;
            var CFG_ITEMS_PER_SAMPLE = 50; // 9;
            var CFG_END_STROKE_GAP = 32;

            var CFG_EER = !CFG_BAYESES;
            var CFG_RELTARGET = CFG_BAYESES ? 1E-24 : 1E-12;
            var CFG_ABSTARGET = CFG_BAYESES ? 1E-24 : 1E-12;

            DESCRIPTION_STRING =
                ( CFG_SFFS ? "SFFS-3m" : "SFS" ) + " " + ( CFG_BAYESES ? "BAYESES " : "EER" ) +
                ", samples/entity: " + CFG_SAMPLES_PER_ENTITY.ToString() +
                ", items/sample: " + CFG_ITEMS_PER_SAMPLE.ToString() + 
                ", random: " + CFG_RANDOM.ToString() + 
                ", env: " + CFG_ENV.ToString() + 
                ", source: " + CFG_SOURCE.ToString() + 
                ", endgap: " + CFG_END_STROKE_GAP.ToString(); // ", without L/M/H",

            DESCRIPTION_FILE =
                ( CFG_SFFS ? "SFFS(" : "SFS(" ) + ( CFG_BAYESES ? "B" : "E" ) +
                ")-SE(" + CFG_SAMPLES_PER_ENTITY.ToString() +
                ")-IE(" + CFG_ITEMS_PER_SAMPLE.ToString() + 
                ")-R(" + (CFG_RANDOM ? "1" : "0") + 
                ")-E(" + CFG_ENV.ToString() + 
                ")-S(" + CFG_SOURCE.ToString() + 
                ")-G(" + CFG_END_STROKE_GAP.ToString() +
                ")"; // ", without L/M/H",

            var dumper = new CSVDumper();
            
            var entities = DataSources.Get( CFG_ENV, CFG_SOURCE );
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
            var farAnalyzer = new Analysis.StrokePopulationAnalysis( CFG_END_STROKE_GAP );
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
                var trainingAnalyzer = new Analysis.StrokePopulationAnalysis( CFG_END_STROKE_GAP );
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
                                SelectMarkers( CFG_RANDOM, CFG_SFFS, CFG_SFFS_K, CFG_BAYESES, CFG_EER, markers, entity, probeEntities, CFG_SAMPLES_PER_ENTITY, CFG_ITEMS_PER_SAMPLE, CFG_ABSTARGET, CFG_RELTARGET ) // probeEntities.Where( p => p.Related == entity ).First() )
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

                // prepare grabbing and remembering of best markers
                Dictionary<Entity, Features.Markers> sumMarkers = new Dictionary<Entity, Features.Markers>();
                Dictionary<Entity, Features.Markers> bestMarkers = new Dictionary<Entity, Features.Markers>();
                foreach( var entity in entities )
                {
                    var markers = new Features.Markers();
                    markers.AddMarkers( distributionMarkers );
                    markers.Snapshot = new HashSet<int>(); // clear them
                    sumMarkers[entity] = markers;

                    bestMarkers[entity] = null;
                }
                foreach( var result in results )
                {
                    bestMarkers[result.Item1] = result.Item2;
                    sumMarkers[result.Item1].Or( result.Item2 );
                }

                var CFGDUMP_DEVELOPMENT = true;
                var CFGDUMP_DETAILS = true;
                var CFGDUMP_DETAILS_BAYESES = true && CFG_BAYESES;
                var CFGDUMP_DETAILS_EER = true && !CFG_BAYESES;
                var CFGDUMP_DETAILS_MATRIX = true;
                var CFGDUMP_DETAILS_GROUP = true;
                var CFGDUMP_ONLY_USED = false;

                dumper.AddContent(
                    "TRAIN " + DESCRIPTION_STRING,
                    d =>
                    {
                        if( CFGDUMP_DEVELOPMENT )
                        {
                            d.Cell( "development" );
                            foreach( var result in results )
                            {
                                d.CellsE( result.Item1.Id + ".name", false, result.Item3.Select( r => (object)( r.name + (result.Item2.IsActive( r.index ) ? "*" : "") ) ) );
                                d.CellsE( result.Item1.Id + ".eer", false, result.Item3.Select( r => r.eer == null ? "n/a" : r.eer.Item2.ToString( "G5" ) ) );
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
                                IList<EERProgress> dumped;
                                if( CFGDUMP_ONLY_USED )
                                {
                                    dumped = result.Item3.Where( i => result.Item2.IsActive( i.index ) && i.name.StartsWith( "+" ) ).ToList();
                                }
                                else
                                {
                                    dumped = result.Item3;
                                }

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
                                columns.Add( dumped.Select( i => (object)i.order ) );
                                headers.Add( "marker" );
                                columns.Add( dumped.Select( i => i.name + (result.Item2.IsActive( i.index ) ? "*" : "") ) );
                                headers.Add( "markerX" );
                                columns.Add( dumped.Select( i =>
                                {
                                    var strokeMarkerName = i.name.Substring( 0, i.name.Length-3 ).Remove( 0, 2 );
                                    var item = i.samples.Where( p => p.Item1 == result.Item1 && p.Item3 == 0 ).Select( p => p.Item2 ).First().First();
                                    return ( (StrokeFeatureItem)item ).AllValues( strokeMarkerName );
                                } ) );
                                headers.Add( "EERX" );
                                columns.Add( dumped.Select( i => i.eer == null ? "n/a" : i.eer.Item1.ToString( "G5" ) ) );
                                headers.Add( "EERY" );
                                columns.Add( dumped.Select( i => i.eer == null ? "n/a" : i.eer.Item2.ToString( "G5" ) ) );
                                headers.Add( "Pbayes" );
                                columns.Add( dumped.Select( i => i.p.ToString( "G5" ) ) );
                                headers.Add( "measure" );
                                columns.Add( dumped.Select( i => i.measureM.ToString( "G5" ) + ":" + i.measureP.ToString( "G5" ) + ":" + i.measureD.ToString( "G5" )) );
                                headers.Add( "-" );
                                columns.Add( new List<string>() { "-" } );

                                if( CFGDUMP_DETAILS_BAYESES )
                                {
                                    for( var i = 0; i < dumped.Count; i++ )
                                    {
                                        var resultItem = dumped[i];
                                        var name = resultItem.name;
                                        var strokeMarkerName = name.Substring( 0, name.Length-3 ).Remove( 0, 2 );

                                        headers.Add( i.ToString( "D2" ) + ".bayeses id" );
                                        headers.Add( i.ToString( "D2" ) + "." + strokeMarkerName + ".X" );
                                        headers.Add( i.ToString( "D2" ) + ".bayeses p" );
                                        headers.Add( "-" );
                                        columns.Add( resultItem.bayeses.Select( b => b.Item1.Id ) );
                                        columns.Add( resultItem.samples.Where( p => p.Item3 == 0 ).SelectMany( p => p.Item2 ).Take( entities.Count ).Select( fi =>
                                        {
                                            return ( (StrokeFeatureItem)fi ).AllValues( strokeMarkerName );
                                        } ) );
                                        columns.Add( dumped[i].bayeses.Select( b => b.Item2.ToString( "G5" ) ) );
                                        columns.Add( new List<string>() { "-" } );
                                    }
                                }

                                if( CFGDUMP_DETAILS_EER )
                                {
                                    for( var i = 0; i < dumped.Count; i++ )
                                    {
                                        headers.Add( i.ToString( "D2" ) + ".fmr S(x)" );
                                        headers.Add( i.ToString( "D2" ) + ".fmr R(y)" );
                                        headers.Add( i.ToString( "D2" ) + ".fnmr S(x)" );
                                        headers.Add( i.ToString( "D2" ) + ".fnmr R(y)" );
                                        headers.Add( "-" );
                                        columns.Add( dumped[i].eer.Item3.Select( f => (object)f.Item1 ) );
                                        columns.Add( dumped[i].eer.Item3.Select( f => (object)f.Item2 ) );
                                        columns.Add( dumped[i].eer.Item4.Select( f => (object)f.Item1 ) );
                                        columns.Add( dumped[i].eer.Item4.Select( f => (object)f.Item2 ) );
                                        columns.Add( new List<string>() { "-" } );
                                    }
                                }

                                previousId = result.Item1.Id;
                            }

                            // flush last
                            d.Columns( headers, columns );

                            if( CFGDUMP_DETAILS && CFGDUMP_DETAILS_MATRIX )
                            {
                                headers = new List<string>();
                                columns = new List<IEnumerable<object>>();

                                headers.Add( "best used markers" );
                                columns.Add( bestMarkers.First().Value.Names );

                                foreach( var markers in bestMarkers )
                                {
                                    headers.Add( markers.Key.Id );
                                    columns.Add( markers.Value.Actives.Components.Select( m => m.ToString( "G5" ) ) );
                                }

                                d.Columns( headers, columns );

                                d.Cell( "" );

                                headers = new List<string>();
                                columns = new List<IEnumerable<object>>();

                                headers.Add( "all used markers" );
                                columns.Add( sumMarkers.First().Value.Names );

                                foreach( var markers in sumMarkers )
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
                    entitiesTrained.Add( new Tuple<Entity, Features.Markers>( entity, bestMarkers[entity] ) );
                }
                Serialize( "Markers-" + DESCRIPTION_FILE + ".txt", entitiesTrained );
            }

            if( CFG_TEST )
            {
                var CFG_TEST_REPEATSPERENTITY = 10;
                var CFG_TEST_SAMPLESPERENTITYUPTO = 1;
                var CFG_TEST_ITEMSPERSAMPLEUPTO = 200;

                foreach( var entity in entities )
                {
                    var markers = new Features.Markers();
                    markers.AddMarkers( distributionMarkers );
                    entitiesTrained.Add( new Tuple<Entity, Features.Markers>( entity, markers ) );
                }
                Deserialize( "Markers-" + DESCRIPTION_FILE + ".txt", ref entitiesTrained );

                var testResults = Test( entitiesTrained, probeEntities, CFG_TEST_REPEATSPERENTITY, CFG_TEST_SAMPLESPERENTITYUPTO, CFG_TEST_ITEMSPERSAMPLEUPTO );

                dumper.AddContent( "TEST, TEMPLATE SET: " + DESCRIPTION_STRING + ", TEST SET:" + DESCRIPTION_STRING,
                    d =>
                    {
                        d.Cell( "i/s development overall" );

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

                        d.Cell( "i/s development per entity" );

                        headers = new List<string>();
                        columns = new List<IEnumerable<object>>();

                        foreach( var entity in entities )
                        {
                            for( var i = 1; i <= CFG_TEST_SAMPLESPERENTITYUPTO; i++ )
                            {
                                headers.Add( "s/e = " + i.ToString() + " mean " + entity.Id );
                                headers.Add( "s/e = " + i.ToString() + " dev " + entity.Id );
                                headers.Add( "-" );
                            }
                        }

                        foreach( var entity in entities )
                        {
                            for( var i = 1; i <= CFG_TEST_SAMPLESPERENTITYUPTO; i++ )
                            {
                                var means = new List<double>();
                                var deviations = new List<double>();
                                for( var j = 1; j <= CFG_TEST_ITEMSPERSAMPLEUPTO; j++ )
                                {
                                    var eers = testResults.Where( r => r.samplesPerEntity == i && r.itemsPerSample == j && r.entity == entity ).Select( r => r.eer.Item2 );
                                    means.Add( eers.Average() );
                                    deviations.Add( Math.Sqrt( eers.Variance() ) );
                                }

                                columns.Add( means.Select( mean => mean.ToString( "G5" ) ) );
                                columns.Add( deviations.Select( dev => dev.ToString( "G5" ) ) );
                                columns.Add( new List<string>() { "-" } );
                            }
                        }
    
                        d.Columns( headers, columns );

                        /*
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
                        */
                    }
                );
            }

            dumper.Dump( outputFileNameHint == "" ? (CFG_TRAIN ? "s-f" : "s-ft") : outputFileNameHint );
        }

        #endregion

        private List<EERProgress> SelectMarkers( bool RANDOM, bool _SFFS, int SFFS_K, bool BAYESES, bool EER, Features.Markers markers, Entity entity, IEnumerable<Lookup.ProbeEntity> probes, int samplesPerEntity, int itemsPerSample, double absTarget, double relTarget )
        {
            bool LOGARITHMIC = true;
            bool POSTERIOR_LOGARITHMIC = LOGARITHMIC && BAYESES;

            var probesCount = probes.Count();
            var imposters = probesCount - 1;

            var imposterSamples = samplesPerEntity;
            var genuineSamples = samplesPerEntity * imposters; // the same count

            if( POSTERIOR_LOGARITHMIC )
            {
                absTarget = Math.Log( absTarget );
                relTarget = Math.Log( relTarget );
            }

            // initialize -- prepare data
            var samples = CreateSamples( entity, probes, genuineSamples, imposterSamples, itemsPerSample, RANDOM );

            if( _SFFS )
            {
                return SFFS( BAYESES, EER, LOGARITHMIC, SFFS_K, markers, entity, samples, genuineSamples, imposterSamples, absTarget, relTarget );
            }
            else
            {
                return SFS( BAYESES, EER, LOGARITHMIC, markers, entity, samples, genuineSamples, imposterSamples, absTarget, relTarget );
            }
        }

        private List<EERProgress> SFS(
            bool BAYESES, bool EER, bool LOGARITHMIC,
            Features.Markers markers, Entity entity,
            List<Tuple<Entity, IEnumerable<IFeatureItem>, int>> samples, int genuineSamples, int imposterSamples,
            double absTarget, double relTarget )
        {
            // clear markers
            markers.Snapshot = new HashSet<int>();

            List<EERProgress> progress = new List<EERProgress>();
            HashSet<int> used = new HashSet<int>();

            var targetTest0 = double.MaxValue;
            var targetTest1 = double.MaxValue;
            var targetTest2 = double.MaxValue;
            EERProgress bestStep = null; // global variant

            for( var j = 0; j < markers.Count; j++ )
            {
                var besti = -1;
                // EERProgress bestStep = null; // local variant

                for( var i = 0; i < markers.Count; i++ )
                {
                    if( used.Contains( i ) )
                    {
                        continue;
                    }
                    markers.SetActive( i, true );

                    var newBestStep = Step( BAYESES, EER, LOGARITHMIC, markers, entity, samples, genuineSamples, imposterSamples, bestStep );
                    if( newBestStep != bestStep )
                    {
                        besti = i;
                        bestStep = newBestStep;
                    }

                    markers.SetActive( i, false );
                }

                if( besti == -1 )
                {
                    break; // nothing found
                }
                markers.SetActive( besti, true );
                used.Add( besti );

                // complete step information
                bestStep.order = j;
                bestStep.index = besti;
                bestStep.name = "+" + markers.IndexToName( besti );

                // put it into progres
                progress.Add( bestStep );

                // evaluate end
                if( TestEnd( bestStep.measureM, ref targetTest0, ref targetTest1, ref targetTest2, absTarget, relTarget ) )
                {
                    break;
                }
            }

            return progress;
        }

        private List<EERProgress> SFFS(
            bool BAYESES, bool EER, bool LOGARITHMIC, int SFFS_K, Features.Markers markers, Entity entity,
            List<Tuple<Entity, IEnumerable<IFeatureItem>, int>> samples, int genuineSamples, int imposterSamples,
            double absTarget, double relTarget )
        // by http://books.google.cz/books?id=x5hdbK8bIG0C&dq=sffs+algorithm&hl=cs&source=gbs_navlinks_s
        {
            // clear markers
            markers.Snapshot = new HashSet<int>();

            int n = markers.Count;
            SFFS_K = SFFS_K == -1 ? n : SFFS_K + 1;

            List<EERProgress> progress = new List<EERProgress>();
            HashSet<int>[] bestsets = new HashSet<int>[SFFS_K];
            EERProgress[] bestmeasures = new EERProgress[SFFS_K];
            int order = 1;

            var targetTest0 = double.MaxValue;
            var targetTest1 = double.MaxValue;
            var targetTest2 = double.MaxValue;

            int k = 0;
            while( k < SFFS_K )
            {
                // select the best feature from unused
                EERProgress bestAdded = null;
                var besti = -1;
                for( var i = 0; i < n; i++ )
                {
                    if( markers.IsActive( i ) )
                    {
                        continue;
                    }

                    markers.SetActive( i, true );

                    var newBestAdded = Step( BAYESES, EER, LOGARITHMIC, markers, entity, samples, genuineSamples, imposterSamples, bestAdded );
                    if( newBestAdded != bestAdded )
                    {
                        besti = i;
                        bestAdded = newBestAdded;
                    }

                    markers.SetActive( i, false );
                }
                // k++; // increment is delayed to not to subtract 1 more times

                if( bestsets[k] != null && bestAdded.WorseThan( bestmeasures[k], true ) ) // found result is worse then known one for a given k, restart with this known
                {
                    markers.Snapshot = bestsets[k];
                    k++; // increment is delayed to not to subtract 1 more times
                    continue;
                }

                // found result is better than any know (or is the first), try backtracking
                markers.SetActive( besti, true );
                bestsets[k] = markers.Snapshot;
                bestmeasures[k] = bestAdded;
                k++; // increment is delayed to not to subtract 1 more times

                // complete step information and put it into progress
                bestAdded.order = order++;
                bestAdded.index = besti;
                bestAdded.name = "+" + markers.IndexToName( besti );
                progress.Add( bestAdded );

                // evaluate end
                if( bestAdded.measureM == 0.0 &&
                    TestEnd( bestAdded.measureP + CFG_EER_MID_WEIGHT * bestAdded.measureD, ref targetTest0, ref targetTest1, ref targetTest2, absTarget, relTarget ) )
                {
                    break;
                }

                // prepare premature end
                var breakLoop = false;

                // backtrack repeat until probability increases
                while( k > 2 )
                {
                    EERProgress bestRemoved = null;
                    int worsti = -1;
                    for( var i = 0; i < n; i++ )
                    {
                        if( !markers.IsActive( i ) )
                        {
                            continue;
                        }
                        markers.SetActive( i, false );

                        var newBestStep = Step( BAYESES, EER, LOGARITHMIC, markers, entity, samples, genuineSamples, imposterSamples, bestRemoved );
                        if( newBestStep != bestRemoved )
                        {
                            worsti = i;
                            bestRemoved = newBestStep;
                        }

                        markers.SetActive( i, true );
                    }
                    if( bestRemoved.WorseThan( bestmeasures[k-2], true ) ) // found result is worse than one already known, stop backtracking
                    {
                        break;
                    }

                    // better result found, continue with backtracking
                    k--;
                    markers.SetActive( worsti, false );
                    bestsets[k-1] = markers.Snapshot;
                    bestmeasures[k-1] = bestRemoved;

                    // complete step information and put it into progress
                    bestRemoved.order = order++;
                    bestRemoved.index = worsti;
                    bestRemoved.name = "-" + markers.IndexToName( worsti );
                    progress.Add( bestRemoved );

                    // evaluate end
                    if( bestRemoved.measureM == 0.0 &&
                        TestEnd( bestRemoved.measureP + CFG_EER_MID_WEIGHT * bestRemoved.measureD, ref targetTest0, ref targetTest1, ref targetTest2, absTarget, relTarget ) )
                    {
                        breakLoop = true;
                        break;
                    }
                }

                if( breakLoop )
                {
                    break;
                }
            }

            EERProgress bestmeasure = null;
            var bestp = -1;
            for( var b = 0; b < bestmeasures.Length; b++ )
            {
                if( bestmeasure == null ||
                    bestmeasures[b] != null && bestmeasure.WorseThan( bestmeasures[b] ) )
                {
                    bestmeasure = bestmeasures[b];
                    bestp = b;
                }
            }
            if( bestmeasure != null )
            {
                markers.Snapshot = bestsets[bestp];
                progress.Insert( 0, bestmeasure );
            }

            return progress;
        }
        

        private EERProgress Step(
            bool BAYESES, bool EER, bool LOGARITHMIC, Features.Markers markers, Entity entity,
            List<Tuple<Entity, IEnumerable<IFeatureItem>, int>> samples, int genuineSamples, int imposterSamples,
            EERProgress previousBest )
        {
            if( markers.ActiveCount == 0 )
            {
                return previousBest;
            }

            var POSTERIOR_LOGARITHMIC = LOGARITHMIC && BAYESES;

            // preparation of baesian probabilities
            var priors = ComputePriors( entity, markers, samples, LOGARITHMIC );
            var posteriors = ComputePosteriors( BAYESES, entity, priors, genuineSamples, imposterSamples, LOGARITHMIC, POSTERIOR_LOGARITHMIC );

            // evaluate bayeses
            var ibayeses = posteriors.Where( m => m.Item3 == 0 ).Select( s => new Tuple<Entity, double>( s.Item1, s.Item2 ) );
            var ipmines = posteriors.Where( m => m.Item3 == 0 && m.Item1 == entity ).Select( m => m.Item2 );
            var ipmine = posteriors.Where( m => m.Item3 == 0 && m.Item1 == entity ).Select( m => m.Item2 ).First();

            var pmine = ipmine;
            var bayeses = ibayeses;
            if( BAYESES )
            {
                var minemeasure = BAYESES ? - pmine : 1.0 - pmine; // BAYESES driver LOGARITHMIC_POSTERIORS
                if( previousBest == null || previousBest.WorseThan( minemeasure  ) )
                {
                    return new EERProgress()
                    {
                        measureM = minemeasure,
                        p = POSTERIOR_LOGARITHMIC ? Math.Exp( pmine ) : pmine,
                        bayeses = bayeses,
                        samples = samples
                    };
                }
            }

            // compute eer
            if( EER  )
            {
                var pmines = ipmines.Average();

                // var eer = ComputeEER( entity, posteriors );
                // cdf EER evaluation
                // var measureM = eer.Item2;
                // var measureP = 1 - pmine;
                // var measureD = Math.Abs( eer.Item1 - 0.5 );

                // evaluate EER for BAYESES driven lookup
                // measureM = measureP;

                // compute mean and sigma of fmr/fnmr
                var genuines = posteriors.Where( i => i.Item1 == entity ).Select( i => i.Item2 );
                var gm = genuines.Average();
                var gd = Math.Sqrt( genuines.Variance());
                var impostors = posteriors.Where( i => i.Item1 != entity ).Select( i => i.Item2 );
                var im = impostors.Average();
                var id = Math.Sqrt( impostors.Variance());
                // pdf EER evaluation
                var measureM = 2.0 - ((gm - gd) - (im + id));
                var measureP = 1.0 - pmines;
                var measureD = 0.0;

                // extremes separation
                // measureM = 2.0 - ( genuines.Min() - impostors.Max() );
                
                if( previousBest == null || previousBest.WorseThan( measureM, measureP, measureD ) )
                {
                    var eer = ComputeEER( entity, posteriors );

                    return new EERProgress()
                    {
                        measureM = measureM,
                        measureP = measureP,
                        measureD = measureD,
                        eer = eer,
                        p = pmines,
                        bayeses = bayeses,
                        samples = samples
                    };
                }
            }

            return previousBest;
        }

        private bool TestEnd( double value, ref double targetTest0, ref double targetTest1, ref double targetTest2, double absTarget, double relTarget )
        {
            targetTest2 = targetTest1;
            targetTest1 = targetTest0;
            targetTest0 = value;
            if( targetTest0 <= absTarget ) // SEARCH STOP CONDITION
            {
                return true;
            }
            else if( Math.Abs( targetTest2 - targetTest1 ) <= relTarget && 
                     Math.Abs( targetTest1 - targetTest0 ) <= relTarget )
            {
                return true;
            }
            else
            {
                return false;
            }
        }

        private List<Tuple<Entity, IEnumerable<IFeatureItem>, int>> CreateSamples( Entity genuine, IEnumerable<Lookup.ProbeEntity> probes, int genuineSamples, int imposterSamples, int itemsPerSample, bool random )
        {
            var rnd = new Random( genuine.GetHashCode() * (int)DateTime.Now.ToFileTime() );
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
                        var skip = rnd.Next( count - itemsPerSample );
                        selected = items.Skip( skip ).Take( itemsPerSample );
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

        private List<Tuple<Entity, double, int>> ComputePriors( Entity against, Features.Markers markers, List<Tuple<Entity, IEnumerable<IFeatureItem>, int>> samples, bool logarithmic = false )
        {
            var priors = new List<Tuple<Entity, double, int>>();
            foreach( var sample in samples )
            {
                var ps = against.Match( markers, sample.Item2, logarithmic ? MatchType.DistributionLogProduct : MatchType.DistributionProduct, true );
                if( ps.Count != sample.Item2.Count() )
                {
                    throw new Exception();
                }

                var p = logarithmic ? ps.Sum() : ps.Product();
                if( double.IsPositiveInfinity( p ) )
                {
                    var pp = p;
                }

                priors.Add( new Tuple<Entity, double, int>( sample.Item1, p, sample.Item3 ) );
            }

            return priors;
        }

        private const double MAX_LNEXP = 709.0;

        private List<Tuple<Entity, double, int>> ComputePosteriors( bool BAYESES, Entity of, List<Tuple<Entity, double, int>> priors, int genuineSamples, int imposterSamples, bool logarithmicPriors = false, bool logarithmicPosteriors = false )
        {
            var posteriors = new List<Tuple<Entity, double, int>>();

            for( var k = 0; k < genuineSamples; k++ ) // the loop iterates over all genuineSamples, but for each
                                                      // genuine samples it must re-use impostor set. Thus
                                                      // m.Item3 == k % imposterSamples for imposters
            {
                var set = priors.Where( m => m.Item3 == ( m.Item1 == of ? k : k % imposterSamples ) );

                var normalizedset = set;
                if( logarithmicPriors )
                {
                    var min = set.Select( m => m.Item2 ).Min();
                    var max = set.Select( m => m.Item2 ).Max();
                    var shift = min;
                    var diff = max - min;
                    if( diff > MAX_LNEXP ) // range is too big to be exponentiated, trim low values and normalize big ones
                    {
                        shift = max - 300;
                    }
                    normalizedset = set.Select( m =>
                    {
                        return new Tuple<Entity, double, int>( m.Item1, Math.Exp( m.Item2 - shift ), m.Item3 );
                    } );
                }

                var sum = normalizedset.Select( m => m.Item2 ).Sum();
                if( logarithmicPosteriors )
                {
                    sum = Math.Log( sum );
                }

                normalizedset.Where( m => !BAYESES || m.Item3 == k ).Select( m => // where limits usage of re-used imposter sets
                {
                    var value = logarithmicPosteriors ?
                        Math.Log( m.Item2 ) - sum :
                        m.Item2 / sum;
                    if( double.IsNaN( value ))
                    {
                        var xv = value;
                    }
                    posteriors.Add( new Tuple<Entity, double, int>( m.Item1, value, m.Item3 ) );
                    return 0;
                } ).Count();
            }

            return posteriors;
        }

        private Tuple<double, double, List<Tuple<double, double>>, List<Tuple<double, double>>> ComputeEER( Entity of, List<Tuple<Entity, double, int>> similarities )
        {
            // similarities contains samples entries where a few is genuine and more are imposters
            // fmr/fnmr can be computed and err can be found
            var gps = similarities.Where( s => s.Item1 == of ).OrderBy( s => s.Item2 );
            var genuineCount = gps.Count();
            var fnmri = 0;
            var fnmrcdfAll = gps.Select( gp => new Tuple<double, double>(
                gp.Item2 < 1E-3 ? 0.0 : (1.0-gp.Item2 < 1E-3 ? 1.0 : gp.Item2),
                fnmri++/(double)genuineCount )
            ).ToList();
            List<Tuple<double, double>> fnmrcdf = new List<Tuple<double, double>>();
            var fnmrcdfAllLastIndex = fnmrcdfAll.Count-1;
            for( var i = 0; i <= fnmrcdfAllLastIndex; i++ )
            {
                if( i < fnmrcdfAllLastIndex && fnmrcdfAll[i+1].Item1 == 0.0 )
                {
                    continue;
                }
                else if( i > 0 && fnmrcdfAll[i-1].Item1 == 1.0 )
                {
                    continue;
                }
                else
                {
                    fnmrcdf.Add( fnmrcdfAll[i] );
                }
            }
            if( fnmrcdf[0].Item1 != 0.0 || fnmrcdf[0].Item2 != 0.0 )
            {
                fnmrcdf.Insert( 0, new Tuple<double, double>( 0.0, 0.0 ) );
            }
            var fnmrcdfCount = fnmrcdf.Count;
            if( fnmrcdf[fnmrcdfCount-1].Item1 != 1.0 || fnmrcdf[fnmrcdfCount-1].Item2 != 1.0 )
            {
                fnmrcdf.Add( new Tuple<double, double>( 1.0, 1.0 ) );
            }

            var ips = similarities.Where( s => s.Item1 != of ).OrderBy( s => s.Item2 );
            var impostorCount = ips.Count();
            var fmri = impostorCount;
            var fmrcdfAll = ips.Select( ip => new Tuple<double, double>(
                ip.Item2 < 1E-3 ? 0.0 : (1.0-ip.Item2 < 1E-3 ? 1.0 : ip.Item2),
                --fmri/(double)impostorCount )
            ).ToList();
            List<Tuple<double, double>> fmrcdf = new List<Tuple<double, double>>();
            var fmrcdfAllLastIndex = fmrcdfAll.Count-1;
            for( var i = 0; i <= fmrcdfAllLastIndex; i++ )
            {
                if( i < fmrcdfAllLastIndex && fmrcdfAll[i+1].Item1 == 0.0 )
                {
                    continue;
                }
                else if( i > 0 && fmrcdfAll[i-1].Item1 == 1.0 )
                {
                    continue;
                }
                else
                {
                    fmrcdf.Add( fmrcdfAll[i] );
                }
            }
            if( fmrcdf[0].Item1 != 0.0 || fmrcdf[0].Item2 != 1.0 )
            {
                fmrcdf.Insert( 0, new Tuple<double, double>( 0.0, 1.0 ) );
            }
            var fmrcdfCount = fmrcdf.Count;
            if( fmrcdf[fmrcdfCount-1].Item1 != 1.0 || fmrcdf[fmrcdfCount-1].Item2 != 0.0 )
            {
                fmrcdf.Add( new Tuple<double, double>( 1.0, 0.0 ) );
            }

/*
            var Tfnmrcdfx = new double[] {
0.0,
0.98125749176697785,
1.0,
1.0
};
            var Tfnmrcdfy = new double[] {
0.0,
0.066666666666666666,
0.13333333333333333,
1.0
};
            var Tfmrcdfx = new double[] {
0.0,
0.0,
0.018742508233022141,
1.0
            };
            var Tfmrcdfy = new double[] {
1.0,
0.0088888888888888889,
0.0044444444444444444,
0.0
            };
            fnmrcdf.Clear();
            for( var r = 0; r < Tfnmrcdfx.Length; r++ )
            {
                fnmrcdf.Add( new Tuple<double, double>( Tfnmrcdfx[r], Tfnmrcdfy[r] ) );
            }
            fmrcdf.Clear();
            for( var r = 0; r < Tfmrcdfx.Length; r++ )
            {
                fmrcdf.Add( new Tuple<double, double>( Tfmrcdfx[r], Tfmrcdfy[r] ) );
            }
*/

            // lookup for same f value = eer, starting from left
            var intersects = 0;
            var eerx1 = 0.0;
            var eer1 = double.MaxValue;
            for( var k = 0; k < fnmrcdf.Count-1; k++ )
            {
                var leerx = 0.0;
                var leer = double.MaxValue;
                for( var m = 0; m < fmrcdf.Count-1; m++ )
                {
                    intersects = SegmentsIntersects(
                        fnmrcdf[k].Item1, fnmrcdf[k].Item2, fnmrcdf[k+1].Item1, fnmrcdf[k+1].Item2,
                        fmrcdf[m].Item1, fmrcdf[m].Item2, fmrcdf[m+1].Item1, fmrcdf[m+1].Item2,
                        out leerx, out leer );
                    if( intersects > 0 )
                    {
                        break;
                    }
                }
                if( intersects > 0 )
                {
                    eerx1 = leerx < 0.0 ? 0.0 : leerx;
                    eer1 = leer < 0.0 ? 0.0 : leer;
                    break;
                }
            }

            if( intersects == 0 )
            {
                var fnmrcdfx = fnmrcdf.Select( i => i.Item1 ).ToArray();
                var fnmrcdfy = fnmrcdf.Select( i => i.Item2 ).ToArray();
                var fmrcdfx = fmrcdf.Select( i => i.Item1 ).ToArray();
                var fmrcdfy = fmrcdf.Select( i => i.Item2 ).ToArray();
                var stop = false;
            }

            var eerx2 = 0.0;
            var eer2 = double.MaxValue;
            if( intersects == 2 ) // lines were parallel, use computed midpoint, do not run right-sided pass
            {
                eerx2 = eerx1;
                eer2 = eer1;
            }
            else if( intersects == 1 ) // cross
            {
                intersects = 0;
                for( var k = fnmrcdf.Count-2; k >= 0; k-- )
                {
                    var leerx = 0.0;
                    var leer = double.MaxValue;
                    for( var m = fmrcdf.Count-2; m >= 0; m-- )
                    {
                        intersects = SegmentsIntersects(
                            fnmrcdf[k].Item1, fnmrcdf[k].Item2, fnmrcdf[k+1].Item1, fnmrcdf[k+1].Item2,
                            fmrcdf[m].Item1, fmrcdf[m].Item2, fmrcdf[m+1].Item1, fmrcdf[m+1].Item2,
                            out leerx, out leer );
                        if( intersects > 0 )
                        {
                            break;
                        }
                    }
                    if( intersects > 0 )
                    {
                        eerx2 = leerx < 0.0 ? 0.0 : leerx;
                        eer2 = leer < 0.0 ? 0.0 : leer;
                        break;
                    }
                }
            }

            return new Tuple<double, double, List<Tuple<double, double>>, List<Tuple<double, double>>>(
                0.5*(eerx1+eerx2), 0.5*(eer1+eer2),
                fmrcdf, fnmrcdf
            );
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
                                var samples = CreateSamples( localDet.Item1, probes, localGenuineSamples, localImposterSamples, localItemsPerSample, true );
                                var priors = ComputePriors( localDet.Item1, localDet.Item2, samples, true );
                                var posteriors = ComputePosteriors( false, localDet.Item1, priors, localGenuineSamples, localImposterSamples, true, false );

                                // if( localDet.Item1.Id == "DaBcp" && localItemsPerSample == 7 )
                                // {
                                //     var stop = false;
                                // }

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

        const double EPS = 1e-12;

        private bool Equals( double a, double b )
        {
            return Math.Abs( a - b ) <= EPS;
        }

        private int SegmentsIntersects( double x11, double y11, double x12, double y12, // first segment
                                         double x21, double y21, double x22, double y22, // second segment
                                         out double ix, out double iy )
        // 0 = not found, 1 = cross, 2 = parallel
        {
            ix = double.NaN;
            iy = double.NaN;

            // rough test
            if( ( x11 < x12 ? x12 : x11 ) + EPS < ( x21 < x22 ? x21 : x22 ) || ( x21 < x22 ? x22 : x21 ) + EPS < ( x11 < x12 ? x11 : x12 ) ||
                ( y11 < y12 ? y12 : y11 ) + EPS < ( y21 < y22 ? y21 : y22 ) || ( y21 < y22 ? y22 : y21 ) + EPS < ( y11 < y12 ? y11 : y12 ) )
            {
                return 0;
            }

            // first line
            var dx1 = x12 - x11;
            var dy1 = y12 - y11;
            var a1 = dy1;
            var b1 = -dx1;
            var c1 = dx1 * y11 - dy1 * x11;
            var n1 = Math.Abs( a1 ) < Math.Abs( b1 ) ? Math.Abs( a1 ) : Math.Abs( b1 );
            n1 += EPS; // avoid dividing by zero
            a1 /= n1;
            b1 /= n1;
            c1 /= n1;
            // second line
            var dx2 = x22 - x21;
            var dy2 = y22 - y21;
            var a2 = dy2;
            var b2 = -dx2;
            var c2 = dx2 * y21 - dy2 * x21;
            var n2 = Math.Abs( a2 ) < Math.Abs( b2 ) ? Math.Abs( a2 ) : Math.Abs( b2 );
            n2 += EPS; // avoid dividing by zero
            a2 /= n2;
            b2 /= n2;
            c2 /= n2;
            // are lines parallel?
            if( Equals( b1 * a2 - b2 * a1, 0.0 )) // lines are parallel, test if they are the same
            {
                if( !Equals( c1, c2 ) ) // lines are not the same, they have no common point
                {
                    return 0;
                }

                // lines are the same, take middle of their overlap as an intersection point
                ix = 0.5 * (( x11 < x12 ? x12 : x11 ) + ( x21 < x22 ? x21 : x22 ));
                iy = 0.5 * (( y11 < y12 ? y12 : y11 ) + ( y21 < y22 ? y21 : y22 ));

                return 2;
            }

            // lines are not parallel, compute intersect point
            var y = ( c2 * a1 - c1 * a2 ) / ( b1 * a2 - b2 * a1 );
            if( double.IsNaN( y ) )
            {
                var xx = y;
            }
            double x;
            if( a1 == 0.0 )
            {
                x = -( c2 + b2 * y ) / a2;
            }
            else
            {
                x = -( c1 + b1 * y ) / a1;
            }

            // check if point is within limits
            var xpe = x + EPS;
            var xme = x - EPS;
            if( dx1 > 0 )
            {
                if( xpe < x11 || xme > x12 ) { return 0; }
            }
            else
            {
                if( xme > x11 || xpe < x12 ) { return 0; }
            }
            if( dx2 > 0 )
            {
                if( xpe < x21 || xme > x22 ) { return 0; }
            }
            else
            {
                if( xme > x21 || xpe < x22 ) { return 0; }
            }
            var ype = y + EPS;
            var yme = y - EPS;
            if( dy1 > 0 )
            {
                if( ype < y11 || yme > y12 ) { return 0; }
            }
            else
            {
                if( yme > y11 || ype < y12 ) { return 0; }
            }
            if( dy2 > 0 )
            {
                if( ype < y21 || yme > y22 ) { return 0; }
            }
            else
            {
                if( yme > y21 || ype < y22 ) { return 0; }
            }

            ix = x;
            iy = y;

            return 1;
        }

        private void Serialize( string filePath, IEnumerable<Tuple<Entity, Features.Markers>> entitiesTrained )
        {
            using( var fileWriter = new StreamWriter( filePath ) )
            {
                fileWriter.WriteLine( ";;info=" + DESCRIPTION_STRING );

                foreach( var et in entitiesTrained )
                {
                    fileWriter.WriteLine( et.Item1.Id + ";;o=" + et.Item2.Serialize() );

                    var markers = et.Item1.Markers;
                    var actives = et.Item2.Snapshot;
                    foreach( var active in actives )
                    {
                        var markerName = et.Item2.IndexToName( active );
                        var marker = (IDistributionMarker)markers.Where( m => m.Name == markerName ).First();
                        fileWriter.WriteLine( et.Item1.Id + ";" + markerName + ";v=" + marker.Serialized );
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

                    if( markers[2] == "info" )
                    {
                        // accept
                    }
                    else if( markers[2] == "o" ) // overview
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
                        foreach( var et in entitiesTrained )
                        {
                            if( et.Item1.Id == markers[0] )
                            {
                                var markerName = markers[1];
                                var distribution = new DistributionStandaloneMarker( markerName );
                                distribution.Serialized = items[1];

                                var strokeMarkerName = markerName.Substring( 0, markerName.Length-3 ).Substring( 1 );
                                Func<IFeatureItem, Triple<double>> extractor = ( i ) =>
                                {
                                    var f = (StrokeFeatureItem)i;
                                    return new Triple<double>(
                                        distribution.Distribution.Positive != null ? f.Value( strokeMarkerName + ( distribution.Distribution.Negative != null ? "+" : "" ) ) : double.NaN,
                                        distribution.Distribution.Negative != null ? f.Value( strokeMarkerName + "-" ) : double.NaN,
                                        double.NaN
                                    );
                                };
                                distribution.Extractor = extractor;

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

            // common
            public int order;
            public int index;
            public string name;
            public double measureM;
            public double measureP;
            public double measureD;

            // eer
            public Tuple<double, double, List<Tuple<double,double>>, List<Tuple<double,double>>> eer;

            // bayes
            public double p;
            public IEnumerable<Tuple<Entity, double>> bayeses;

            // helper
            public bool WorseThan( EERProgress comperand, bool alsoEqual = false )
            {
                return WorseThan( comperand.measureM, comperand.measureP, comperand.measureD, alsoEqual );
            }

            public bool WorseThan( double _measureM, double _measureP = 0.0, double _measureD = 0.0, bool alsoEqual = false )
            {
                if( measureM > 0.0 && _measureM > 0.0 )
                {
                    return alsoEqual ? measureM >= _measureM : measureM > _measureM;
                }
                else if( measureM == 0.0 && _measureM > 0.0 )
                {
                    return false;
                }
                else if( measureM > 0.0 && _measureM == 0.0 )
                {
                    return true;
                }

                else
                {
                    var mine = measureP + CFG_EER_MID_WEIGHT * measureD;
                    var foreign = _measureP + CFG_EER_MID_WEIGHT * _measureD;
                    return alsoEqual ? mine >= foreign : mine > foreign;
                }
            }
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
