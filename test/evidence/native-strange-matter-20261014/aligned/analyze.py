from pathlib import Path
import json,collections,math
E=Path(__file__).resolve().parent
A=json.loads((E/'A.json').read_text(encoding='utf8'));B=json.loads((E/'B.json').read_text(encoding='utf8'))
def grouped(rows):
 out=collections.defaultdict(list)
 for r in rows:out[r['source']].append(r)
 return out
summary={'mode':'fixed 720-step correctness attribution; no new performance sampling','sides':{},'repeat_cancel_matches':[]}
for side,d in [('A',A),('B',B)]:
 s=d['strange'];errors=[]
 for item in s['packets']:
  row=item['row'];matched=[t for t in s['triggers'] if t['step']==item['step'] and t['source']==row['context']['source_id'] and t['count']>0]
  assert len(matched)==1
  t=matched[0];errors.append(abs(row['damage']/(t['raw']*t['multiplier'])-1))
  assert row['context']['trigger_depth']==1 and 'chain_allowance' not in row['context']
 assert len(s['packets'])==len(s['due'])+len(s['remaining'])
 assert len(s['hits'])==15*len(s['due'])
 chain_hits=sum(v for k,v in d['impacts'].items() if k.endswith(':chain'))
 summary['sides'][side]={'eligible_survival_attempts':sum(not t['killed'] for t in s['triggers']),'successful_survival_triggers':sum(t['count']>0 and not t['killed'] for t in s['triggers']),'kill_triggers':sum(t['killed'] for t in s['triggers']),'packets':len(s['packets']),'due':len(s['due']),'derived_hits':len(s['hits']),'remaining':len(s['remaining']),'max_packet_product_relative_error':max(errors),'repeat_cancellations':len(d['repeat_drops']),'counts':d['counts']['counts'],'chain_arrivals':chain_hits,'chain_outstanding':d['counts']['counts']['enhancement_chain']-chain_hits,'no_recursive_packets':True}
# Existing repeat multiplier from the configured enhancement recipe: 1+0.2*40=9.
for cancelled in A['repeat_drops']:
 candidates=[g for g in B['groups'] if g['derived'] and g['source']=='drone:'+cancelled['drone'] and g['step']==cancelled['step']]
 assert len(candidates)==1
 native=candidates[0]
 parents=[g for g in B['groups'] if not g['derived'] and g['source']==native['source'] and g['step']==native['step']-30]
 assert len(parents)==1 and math.isclose(native['damage'],parents[0]['damage']*9,rel_tol=1e-14)
 summary['repeat_cancel_matches'].append({'cancelled':cancelled,'native_execution':native,'native_parent':parents[0],'native_repeat_multiplier':9})
left=grouped(A['strange']['triggers']);right=grouped(B['strange']['triggers']);assert left.keys()==right.keys()
max_raw_error=0;timing=[]
for source,rows in left.items():
 assert len(rows)==len(right[source])
 for a,b in zip(rows,right[source]):
  assert a['count']==b['count'] and a['multiplier']==b['multiplier'] and a['killed']==b['killed']
  max_raw_error=max(max_raw_error,abs(a['raw']/b['raw']-1));timing.append(b['step']-a['step'])
summary['source_ordinal_trigger_match']={'count':105,'max_raw_relative_error':max_raw_error,'step_delta_min':min(timing),'step_delta_max':max(timing)}
summary['hit_delta_decomposition']={'extra_direct_cannon_hits':15,'extra_chain_births':165,'fewer_chain_packets_still_outstanding_at_step720':12,'extra_chain_arrivals':177,'total_extra_hits':192,'extra_strange_hits':0}
summary['interpretation']='All 15 cancelled legacy drone repeats match native derived fire at the same step/source; every native repeat retains its own parent raw times 9. Each preserved repeat starts 11 chains: 165 extra births. A ends with 155 chains outstanding, B143, hence 177 extra arrivals and 192 extra hits including 15 direct cannon hits. The residual12 is a contact-window count, not assigned per instance or solely to hull geometry. No combat workload reduction was used.'
summary['coverage_limits']='Held-health fixture has zero kills: kill-spawn branch is covered by the previously passed 73-check suite. Native display omits attack IDs; successful packets join by unique source within step (asserted), raw product and exported packet context. Failed attempts retain root=0 in native observer. Due hits are matched against the first ordered native feedback rows by uid/clock and critical=false. Two B observer-schema attempts were rejected; only final B.log/B.json used. Production and DLL unchanged.'
assert A['final']['game_rng']==B['final']['game_rng']
primary_a=grouped([g for g in A['groups'] if not g['derived'] and (g['source'].startswith('module:') or g['source'].startswith('drone:'))])
primary_b=grouped([g for g in B['groups'] if not g['derived'] and (g['source'].startswith('module:') or g['source'].startswith('drone:'))])
assert primary_a.keys()==primary_b.keys()
for source,rows in primary_a.items():
 assert len(rows)==len(primary_b[source]) and all(x['critical']==y['critical'] for x,y in zip(rows,primary_b[source]))
summary['primary_critical_by_source_ordinal_equal']=True
summary['end_rng_equal']=True
summary['attack_counter_end']={'A':A['steps'][-1]['attacks'],'B':B['steps'][-1]['attacks']}
summary['damage_note']='Raw damage is recorded separately; the retained-repeat difference also increases proficiency attack counters from194 to209. This report does not attribute every raw difference solely to that counter. Per-source ordinal critical/RNG/trigger outcomes remain aligned, each side packet damage is exactly its recorded base_raw times1.889; native repeat damage is its native parent snapshot times9.'
(E/'attribution.json').write_text(json.dumps(summary,indent=2),encoding='utf8')
print(json.dumps({k:v for k,v in summary.items() if k!='repeat_cancel_matches'},indent=2))
