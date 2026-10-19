from pathlib import Path
import copy,gzip,json,statistics,sys
sys.dont_write_bytecode=True
from audit_helpers import differences,fixture_gates,phase_gates
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def raw(p):
    with gzip.open(p,'rt',encoding='utf-8') as f:return json.load(f)
def main():
    out=Path(__file__).resolve().parent;agenda=read(out/'agenda.json');manifest=read(out/'builds/manifest.json')
    pairs=[]
    for entry in agenda['results']:
        folder=out/entry['output'];case=entry['case']
        data={label:raw(folder/(case+'-'+label+'.json.gz')) for label in ['before','after']}
        rows={r['label']:r for r in read(folder/'summary-runs.json')['rows']}
        receipts={label:read(folder/(case+'-'+label+'.receipt.json')) for label in data}
        run_gates={}
        for label,d in data.items():
            rc=receipts[label]
            assert rc['library_sha256']==manifest['dll_sha256']
            assert rc['script_sha256']==manifest['runtime_scripts'][label]
            assert rc['driver_sha256']==manifest['frozen_driver_sha256'] and rc['fixture_sha256']==manifest['fixture_sha256']
            pg=phase_gates(d);fg=fixture_gates(d)
            run_gates[label]={'frozen_run_valid':rows[label]['formal_run_valid'],'phases':pg,'fixture':fg,
                'valid':rows[label]['formal_run_valid'] and pg['pass'] and all(fg.values())}
        b,c=data['before'],data['after']
        matching={k:b.get(k)==c.get(k) for k in ['events','stress','rng_state','warm_steps','sample_steps','warm_fires','fires','warm_hits','hits','purchases','handoffs','sampling_config']}
        states={}
        for endpoint in ['state_before','state_after']:
            x,y=copy.deepcopy(b[endpoint]),copy.deepcopy(c[endpoint])
            for state in [x,y]:state.pop('kernel_hash',None);state['canonical_kernel']['rng'].pop('seed',None)
            states[endpoint]={'raw_equal':b[endpoint]==c[endpoint],'seed_only_projection_equal':x==y,
                'raw_differences':differences(b[endpoint],c[endpoint],endpoint)}
            assert x==y,'Unexpected numerical state difference'
        spans={}
        for key in ['wall','before_main','main','submit','render_wait']:
            x,y=[rows[l]['spans_ms'][key] for l in ['before','after']]
            spans[key]={'before':x,'after':y,'delta_mean_ms':y['mean']-x['mean'],'delta_mean_pct':(y['mean']/x['mean']-1)*100}
        pairs.append({'index':entry['index'],'case':case,'order':entry['order'],'output':entry['output'],
            'run_gates':run_gates,'matching':matching,'states':states,'spans':spans,
            'sampling_event_valid':all(g['valid'] for g in run_gates.values()) and all(matching.values())})
    counts=[];counts_folder=out/'counts'
    if (counts_folder/'summary-runs.json').exists():
        for case in ['laser','missile']:
            d=raw(counts_folder/(case+'-after.json.gz'));qa=d['qa_cache_counts']
            counts.append({'case':case,**qa,'projection_hit_fraction':1-qa['builds']/qa['queries'],
                'warm_steps':d['warm_steps'],'sample_steps':d['sample_steps'],
                'actual_1x_pass':d['actual_1x_pass'],'performance_sample_valid':d['performance_sample_valid'],
                'scope':'QA counters only; not a formal frame time comparison'})
    result={'baseline':manifest['baseline'],'cache_commit':manifest['cache_commit'],'same_DLL':True,'pairs':pairs,
        'all_4_pairs_valid':len(pairs)==4 and all(p['sampling_event_valid'] for p in pairs),
        'summary':{case:{'valid_pairs':sum(p['case']==case and p['sampling_event_valid'] for p in pairs),
            'paired_mean_delta_pct':statistics.mean(p['spans']['wall']['delta_mean_pct'] for p in pairs if p['case']==case and p['sampling_event_valid']),
            'deltas_pct':[p['spans']['wall']['delta_mean_pct'] for p in pairs if p['case']==case]} for case in ['laser','missile']},
        'counts':counts}
    (out/'analysis.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print('CACHE ANALYSIS',result['summary'],'counts',counts,flush=True)
if __name__=='__main__':main()
