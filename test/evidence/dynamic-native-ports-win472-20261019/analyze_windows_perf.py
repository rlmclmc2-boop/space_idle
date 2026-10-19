"""Audit frozen Windows raw samples and report paired validity without weakening gates."""
from pathlib import Path
import argparse, datetime, gzip, hashlib, json, statistics

CASES=['mixed','laser','cannon','missile','longLaser']
def load(path):
    with gzip.open(path,'rt',encoding='utf-8') as f:return json.load(f)
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def differences(a,b,path='',out=None):
    if out is None:out=[]
    if a==b:return out
    if isinstance(a,dict) and isinstance(b,dict):
        for key in sorted(set(a)|set(b)):
            if key not in a or key not in b:out.append({'path':path+'/'+key,'before':a.get(key),'after':b.get(key)})
            else:differences(a[key],b[key],path+'/'+key,out)
    elif isinstance(a,list) and isinstance(b,list) and len(a)==len(b):
        for i,(x,y) in enumerate(zip(a,b)):differences(x,y,path+'/'+str(i),out)
    elif len(out)<500:out.append({'path':path,'before':a,'after':b})
    return out
def phase_gates(d):
    phases=d['phases']; frames=d['frames_us_raw']
    lengths={k:len(d[k]) for k in ['phases','frames_us_raw','projectiles_raw','floats_raw',
                                'pending_raw','primitives_raw','drawcalls_raw','frame_trace']}
    negative=[]; partitions=[]
    for i,(r,wall) in enumerate(zip(phases,frames)):
        v=[r['main_begin_us']-r['previous_post_us'],r['main_end_us']-r['main_begin_us'],
           r['pre_draw_us']-r['main_end_us'],r['post_draw_us']-r['pre_draw_us']]
        if min(v)<0:negative.append(i)
        if sum(v)!=wall:partitions.append(i)
    return {'array_lengths':lengths,'lengths_equal':len(set(lengths.values()))==1,
            'negative_phase_frames':negative,'partition_fail_frames':partitions,
            'phase_steps_sum':sum(r['logic_steps'] for r in phases),
            'pass':len(set(lengths.values()))==1 and not negative and not partitions
                and sum(r['logic_steps'] for r in phases)==d['sample_steps']}
def fixture_gates(d):
    c=d['stress']['config']
    return {'layer2':c['layer']==2,'enemies15':c['alive_enemies']==15 and d['enemies_alive']==15,
            'enhancement40':c['enhancement_effective_level']==40,'five_drones':len(c['equipped'])==5,
            'ordinary140':len(c['ordinary'])>0 and all(int(w['level'])==140 for w in c['ordinary'])}
def gpu_summary(path,start,end):
    selected=[]
    for line in path.read_text(encoding='utf-8',errors='replace').splitlines():
        parts=[s.strip() for s in line.split(',')]
        if len(parts)!=7:continue
        try:
            t=datetime.datetime.strptime(parts[0],'%Y/%m/%d %H:%M:%S.%f').astimezone().timestamp()
            if start<=t<=end:selected.append({'unix':t,'gpu_percent':float(parts[3]),
                'memory_controller_percent':float(parts[4]),'memory_MiB':float(parts[5]),
                'power_W':float(parts[6])})
        except (ValueError,IndexError):continue
    return {'samples':len(selected),'scope':'whole NVIDIA device; 100ms polling; sensor update rate may be slower; not GPU frame time',
            'metrics':{k:{'mean':statistics.mean(r[k] for r in selected),'max':max(r[k] for r in selected)}
                       for k in ['gpu_percent','memory_controller_percent','memory_MiB','power_W']} if selected else {}}
def main():
    p=argparse.ArgumentParser();p.add_argument('output',type=Path);a=p.parse_args();out=a.output
    runs=json.loads((out/'summary-runs.json').read_text(encoding='utf-8'))
    by={(r['case'],r['label']):r for r in runs['rows']}
    pairs=[];details={}
    for case in CASES:
        data={label:load(out/(case+'-'+label+'.json.gz')) for label in ['before','after']}
        receipts={label:json.loads((out/(case+'-'+label+'.receipt.json')).read_text(encoding='utf-8')) for label in data}
        local={}
        for label,d in data.items():
            phases=phase_gates(d);fixture=fixture_gates(d)
            configs=[d[k] for k in ['runtime_config_start','sampling_config','runtime_config_end']]
            config_pass=all(c['speed']==1 and c['engine_max_fps']==0 and c['vsync']==0
                and c['time_scale']==1 and c['fixed_logic_hz']==60 and c['stat_cache_enabled']
                and not c['save_enabled'] and c['compiled_rules'] and c['combat_presentation']
                and c['native_active'] and c['retained'] for c in configs)
            engine=d['engine_version']
            engine_pass=(engine['major'],engine['minor'],engine['patch'])==(4,7,2)
            log='\n'.join(p.read_text(encoding='utf-8',errors='replace') for p in
                [out/(case+'-'+label+'.log'),out/(case+'-'+label+'.engine.log')] if p.exists())
            local[label]={'frozen_run_gate':by[case,label]['formal_run_valid'],'phase_gates':phases,
                'fixture_gates':fixture,'runtime_config_pass':config_pass,'engine472':engine_pass,
                'errors':sorted(set(s for s in log.splitlines() if s.startswith(('ERROR:','SCRIPT ERROR:')))),
                'ordinary_active_entries':len(d['stress']['config']['ordinary']),
                'gpu':gpu_summary(out/(case+'-'+label+'.gpu.csv'),d['sample_start_unix'],d['sample_end_unix'])}
            local[label]['valid']=bool(local[label]['frozen_run_gate'] and phases['pass'] and
                all(fixture.values()) and config_pass and engine_pass and not local[label]['errors'])
        b,c=data['before'],data['after']
        same={key:b.get(key)==c.get(key) for key in ['warm_steps','sample_steps','warm_fires','fires',
                'warm_hits','hits','warm_purchases','purchases','handoffs','events','rng_state']}
        same['fixture_config']=b['stress']['config']==c['stress']['config']
        same['stress_events']=b['stress']['counts']==c['stress']['counts']
        same['driver']=receipts['before']['driver_sha256']==receipts['after']['driver_sha256']
        same['fixture_file']=receipts['before']['fixture_sha256']==receipts['after']['fixture_sha256']
        same['runtime_config']=b['sampling_config']==c['sampling_config']
        same['state_before']=b['state_before']==c['state_before']
        same['state_after']=b['state_after']==c['state_after']
        detail={k:differences(b[k],c[k],k) for k in ['state_before','state_after','events','stress'] if b[k]!=c[k]}
        details[case]=detail
        sample_keys=[k for k in same if k not in ['state_before','state_after']]
        projected={}
        for endpoint in ['state_before','state_after']:
            x,y=[json.loads(json.dumps(d[endpoint])) for d in [b,c]]
            for state in [x,y]:
                state.pop('kernel_hash',None)
                state['canonical_kernel']['rng'].pop('seed',None)
            projected[endpoint]=x==y
        pairs.append({'case':case,'runs':local,'matching':same,
            'paired_valid':local['before']['valid'] and local['after']['valid'] and all(same.values()),
            'sampling_event_pair_valid':local['before']['valid'] and local['after']['valid'] and all(same[k] for k in sample_keys),
            'seed_only_projection_diagnostic':{'endpoint_equal':projected,
                'omitted_paths':['canonical_kernel/rng/seed','kernel_hash'],
                'scope':'Additional diagnostic only; raw full-state hash mismatch remains failed'},
            'differences':{span:{metric:{'before':by[case,'before']['spans_ms'][span][metric],
                'after':by[case,'after']['spans_ms'][span][metric],
                'percent':(by[case,'after']['spans_ms'][span][metric]/by[case,'before']['spans_ms'][span][metric]-1)*100}
                for metric in ['mean','p95']} for span in ['wall','before_main','main','submit','render_wait']}})
    result={'baseline':runs['baseline'],'candidate':runs['candidate'],'pairs':pairs,
            'all_five_pairs_valid':all(p['paired_valid'] for p in pairs),
            'all_five_sampling_event_pairs_valid':all(p['sampling_event_pair_valid'] for p in pairs)}
    (out/'validity.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    (out/'state-differences.json').write_text(json.dumps(details,ensure_ascii=False,indent=2),encoding='utf-8')
    for p in pairs:
        d=p['differences']['wall'];print(p['case'],'paired_valid=',p['paired_valid'],
            'sampling_event_pair_valid=',p['sampling_event_pair_valid'],
            'mismatches=',[k for k,v in p['matching'].items() if not v],
            'wall=',round(d['mean']['before'],3),round(d['mean']['after'],3),round(d['mean']['percent'],2),flush=True)
if __name__=='__main__':main()
