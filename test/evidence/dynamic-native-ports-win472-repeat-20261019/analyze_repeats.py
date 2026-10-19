"""Pair-level analysis; keep failed gates, raw RNG-seed mismatch, and QA separate."""
from pathlib import Path
import argparse,copy,gzip,hashlib,importlib.util,json,math,statistics,sys
sys.dont_write_bytecode=True

def read(path):return json.loads(path.read_text(encoding='utf-8'))
def raw(path):
    with gzip.open(path,'rt',encoding='utf-8') as f:return json.load(f)
def stats(values):
    if not values:return {'n':0}
    n=len(values);mean=statistics.mean(values);sd=statistics.stdev(values) if n>1 else None
    t={1:12.706,2:4.303,3:3.182}.get(n-1)
    return {'n':n,'mean':mean,'median':statistics.median(values),'min':min(values),'max':max(values),
            'positive':sum(x>0 for x in values),'negative':sum(x<0 for x in values),
            'sd':sd,'mean_95pct_t_interval':[mean-t*sd/math.sqrt(n),mean+t*sd/math.sqrt(n)] if t and sd is not None else None,
            'unit':'run pair, not rendered frame; small-n descriptive interval assumptions unverified'}

def main():
    p=argparse.ArgumentParser();p.add_argument('output',nargs='?',type=Path,default=Path(__file__).resolve().parent)
    a=p.parse_args();out=a.output
    prior=out.parent/'dynamic-native-ports-win472-20261019'
    spec=importlib.util.spec_from_file_location('original_audit',prior/'analyze_windows_perf.py')
    audit=importlib.util.module_from_spec(spec);spec.loader.exec_module(audit)
    manifest=read(prior/'builds/manifest.json')
    old={(r['case'],r['label']):r for r in read(prior/'summary-runs.json')['rows']}
    result={'baseline':manifest['baseline'],'candidate':manifest['candidate'],'phases':{}}
    for phase in ['repeats','profile']:
        agenda_path=out/(phase+'-agenda.json')
        if not agenda_path.exists():continue
        agenda=read(agenda_path);pairs=[]
        for entry in agenda['results']:
            case=entry['case'];relative_output=entry['output'].replace('\\','/');folder=out/relative_output
            summaries={(r['case'],r['label']):r for r in read(folder/'summary-runs.json')['rows']}
            data={l:raw(folder/(case+'-'+l+'.json.gz')) for l in ['before','after']}
            receipts={l:read(folder/(case+'-'+l+'.receipt.json')) for l in data}
            b,c=data['before'],data['after'];run_gates={}
            for label,d in data.items():
                log='\n'.join(f.read_text(encoding='utf-8',errors='replace') for f in
                     [folder/(case+'-'+label+'.log'),folder/(case+'-'+label+'.engine.log')] if f.exists())
                gates={'frozen':summaries[case,label]['formal_run_valid'],
                    'phases':audit.phase_gates(d),'fixture':audit.fixture_gates(d),
                    'errors':sorted(set(s for s in log.splitlines() if s.startswith(('ERROR:','SCRIPT ERROR:')))),
                    'driver_original':receipts[label]['driver_sha256']==manifest['frozen_inputs']['perf_driver.gd']['sha256'],
                    'dll_exact':receipts[label]['library_sha256']==manifest['dll_sha256'][label],
                    'source_exact':receipts[label]['script_sha256']==manifest['runtime_changed_scripts'][label],
                    'focus':d['performance_sample_valid'],'actual_1x':d['actual_1x_pass'],
                    'warm_steps':d['warm_steps'],'sample_steps':d['sample_steps']}
                assert gates['dll_exact']
                if phase=='repeats':assert gates['driver_original'] and gates['source_exact']
                else:assert receipts[label]['diagnostic_profile'] and not gates['driver_original']
                gates['valid']=bool(gates['frozen'] and gates['phases']['pass'] and all(gates['fixture'].values()) and not gates['errors'])
                run_gates[label]=gates
            matching={key:b.get(key)==c.get(key) for key in ['events','warm_fires','fires','warm_hits','hits',
                     'warm_purchases','purchases','handoffs','rng_state','sampling_config']}
            matching['stress']=b['stress']==c['stress']
            projection={};full={};differences={}
            for endpoint in ['state_before','state_after']:
                full[endpoint]=b[endpoint]==c[endpoint]
                differences[endpoint]=audit.differences(b[endpoint],c[endpoint],endpoint)
                x,y=copy.deepcopy(b[endpoint]),copy.deepcopy(c[endpoint])
                for d in [x,y]:d.pop('kernel_hash',None);d['canonical_kernel']['rng'].pop('seed',None)
                projection[endpoint]=x==y
            pair={'index':entry['index'],'case':case,'order':entry['order'],'output':relative_output,
                'run_gates':run_gates,'matching':matching,'raw_full_state_equal':full,
                'seed_only_projection_equal':projection,'state_differences':differences,
                'sampling_event_valid':all(g['valid'] for g in run_gates.values()) and all(matching.values()),
                'spans':{},'frames':{l:len(d['frames_us_raw']) for l,d in data.items()},
                'drawcalls_mean':{l:statistics.mean(d['drawcalls_raw']) for l,d in data.items()},
                'primitives_mean':{l:statistics.mean(d['primitives_raw']) for l,d in data.items()}}
            assert all(projection.values()),'Unexpected numeric/state differences beyond raw seed'
            for span in ['wall','before_main','main','submit','render_wait']:
                rb,rc=[summaries[case,l]['spans_ms'][span] for l in ['before','after']]
                pair['spans'][span]={'before':rb,'after':rc,'delta_mean_ms':rc['mean']-rb['mean'],
                    'delta_mean_pct':(rc['mean']/rb['mean']-1)*100,
                    'delta_p95_ms':rc['p95']-rb['p95']}
            if phase=='profile':
                pair['qa']={}
                for label,d in data.items():
                    metrics={}
                    for name,row in d['qa_profile'].items():
                        metrics[name]={**row,'mean_us_per_call':row['us']/row['calls'] if row['calls'] else 0,
                            'ms_per_rendered_frame':row['us']/len(d['frames_us_raw'])/1000,
                            'total_ms':row['us']/1000}
                    pair['qa'][label]={'metrics':metrics,'weapon_rows':d['qa_weapon_rows'],'scope':d['qa_profile_scope']}
                ports=pair['qa']['after']['metrics']['ports_total']
                old_delta=old[case,'after']['spans_ms']['wall']['mean']-old[case,'before']['spans_ms']['wall']['mean']
                pair['qa']['comparison_to_original_observation']={
                    'original_delta_ms':old_delta,
                    'ports_total_ms_per_original_candidate_frame':ports['mean_us_per_call']*480/len(raw(prior/(case+'-after.json.gz'))['frames_us_raw'])/1000,
                    'scope':'Instrumented inclusive timer budget; diagnostic, not a formal speedup/ablation result'}
            pairs.append(pair)
        summaries={}
        for case in ['laser','missile']:
            ps=[p for p in pairs if p['case']==case and p['sampling_event_valid']]
            summaries[case]={'valid_pairs':len(ps),'planned_pairs':sum(p['case']==case for p in pairs),
                'wall_delta_pct':stats([p['spans']['wall']['delta_mean_pct'] for p in ps]),
                'spans_delta_ms':{k:stats([p['spans'][k]['delta_mean_ms'] for p in ps]) for k in ['wall','main','submit','render_wait']},
                'order_groups':{order:stats([p['spans']['wall']['delta_mean_pct'] for p in ps if p['order']==order]) for order in ['AB','BA']}}
        result['phases'][phase]={'pairs':pairs,'summary':summaries,
            'formal_performance_eligible':phase=='repeats',
            'scope':'Uninstrumented original-driver repeats' if phase=='repeats' else 'QA RAM timers; profile frame times are not acceptance samples',
            'all_runs_completed':len(agenda['results'])==len(agenda['schedule']) and all(r['exit_code']==0 for r in agenda['results'])}
    (out/'analysis.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    for phase,value in result['phases'].items():
        for case,row in value['summary'].items():print(phase,case,'valid pairs',row['valid_pairs'],'wall %',row['wall_delta_pct'],flush=True)

if __name__=='__main__':main()
