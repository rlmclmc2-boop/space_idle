"""Summarize paired-seed synthetic enhancement benchmarks without population claims."""
import argparse, collections, json, statistics, pathlib, math
p=argparse.ArgumentParser();p.add_argument('input',type=pathlib.Path);p.add_argument('--output',type=pathlib.Path);a=p.parse_args()
data=json.loads(a.input.read_text());groups=collections.defaultdict(list)
for r in data['rows']:groups[(r['level'],r['scenario'],r['tag'])].append(r)
metrics=['dps','damage','ttk','survival','initial_body','remaining_body','incoming_raw','debt_remaining','protection_remaining','attacks_added','incoming_events','crit_events','critical_damage_applied','raw_ehp_until_death','raw_ehp_censored_lower_bound','cover_duty','cover_nonempty_duty','cover_absorbed']
def aggregate(rows):
    out={'samples':len(rows),'survivors':sum(r['survived_window'] for r in rows),'kills':sum(r['kills'] for r in rows),'metrics':{}}
    for key in metrics:
        xs=[r[key] for r in rows if r.get(key) is not None]
        out['metrics'][key]={'n':len(xs),'mean':statistics.mean(xs) if xs else None,'sd':statistics.stdev(xs) if len(xs)>1 else None,'min':min(xs) if xs else None,'max':max(xs) if xs else None}
    for namespace in ['sources','event_counts']:
        keys=set().union(*(r[namespace] for r in rows));out[namespace]={k:statistics.mean(r[namespace].get(k,0) for r in rows) for k in keys}
    return out
summary=[]
for (level,scenario,tag), rows in sorted(groups.items()):
    entry={'level':level,'scenario':scenario,'tag':tag,**aggregate(rows)}
    effect,pattern=tag.split(':');base=groups.get((level,scenario,effect+':'+'-'*len(pattern)),[])
    if base:
        bases={r['seed']:r for r in base};ratios=[];diffs=[]
        for r in rows:
            b=bases.get(r['seed'])
            if b and b['dps']>0:ratios.append(r['dps']/b['dps']);diffs.append(r['dps']-b['dps'])
        entry['paired_dps_ratio']={'n':len(ratios),'mean':statistics.mean(ratios) if ratios else None,'sd':statistics.stdev(ratios) if len(ratios)>1 else None}
        entry['paired_dps_difference_mean']=statistics.mean(diffs) if diffs else None
    summary.append(entry)
out=a.output or a.input.with_name(a.input.stem+'-summary.json');out.write_text(json.dumps({'commit':data['commit'],'engine':data['engine'],'method':data.get('fixture_limits'),'groups':summary},ensure_ascii=False,indent=2))
print(f'{len(data["rows"])} runtime rows, {len(summary)} groups; summary: {out}')
for s in summary:
    if s['scenario'] in ['focus2','focus5','focus10','focus20','swap1','heavy','beam','resisted','steady','burst','typed','alternating']:
        m=s['metrics'];print(f"L{s['level']:2} {s['scenario']:12} {s['tag']:20} DPS {m['dps']['mean']:10.1f} ({m['dps']['sd'] or 0:.1f} sd), survivors {s['survivors']}/{s['samples']}, body {m['remaining_body']['mean']:.1f}, debt {m['debt_remaining']['mean']:.1f}")
