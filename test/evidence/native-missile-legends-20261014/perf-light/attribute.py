from pathlib import Path
import json
E=Path(__file__).resolve().parent

def get(n):return json.loads((E/(n+'.json')).read_text(encoding='utf8'))
a,b,pa,pb=[get(n) for n in ['Alegend','Blegend','Aordinary','Bordinary']]
rows={}
for name,d in [('A',a),('B',b)]:
 before=d['state_before']['projectiles'];after=d['state_after']['projectiles'];born=d['events']['fire']+d['events']['enhancement_chain'];impact=d['events']['projectile_impact']
 assert before+born-impact==after
 total_born=d['stress']['counts']['fire']+d['stress']['counts']['enhancement_chain'];total_hits=d['warm_hits']+d['hits'];blast=d['legend_counters_after']['native'].get('recursion_blocked_entries') if d['legend_counters_after']['native'] else d['legend_counters_after']['legacy']['counts']['recursion_blocked_entries']
 total_impacts=total_hits-blast;assert total_born-total_impacts==after
 rows[name]={'sample_start_carriers':before,'sample_births':born,'sample_impacts':impact,'sample_end_carriers':after,'sample_conservation':True,'whole_births':total_born,'whole_impacts':total_impacts,'whole_aoe_hits':blast,'whole_carrier_conservation':True,'game_rng_start':d['state_before']['game_rng'],'game_rng_end':d['state_after']['game_rng'],'drops':d['state_after']['drops'],'enemies_alive':d['enemies_alive']}
for key in ['sample_births','whole_births','game_rng_start','game_rng_end']:assert rows['A'][key]==rows['B'][key]
ca=a['legend_counters_after']['legacy']['counts'];cb=b['legend_counters_after']['native'];extra_cache=cb['cache_hits']-ca['cache_hits'];missing=ca['missile_hits']-cb['missile_hits']
assert ca['cache_firsts']-cb['cache_firsts']==extra_cache+missing
assert missing==rows['B']['sample_end_carriers']-rows['A']['sample_end_carriers']
for key in ['missile_attacks','wild_substitutions','wild_blasts','recursion_blocked_entries','effective_layer_growth']:assert ca[key]==cb[key]
remaining_wild=sum(bool(r.get('native_context',{}).get('value',{}).get('wild_missile',False)) for r in b['state_after']['canonical_kernel']['flights'])
assert remaining_wild==cb['wild_substitutions']-cb['wild_blasts']
def common(v):
 if isinstance(v,dict):
  if v.get('class')=='RandomNumberGenerator':return {'class':v['class'],'state':v['state']}
  return {k:common(x) for k,x in v.items() if k not in ['native_context','missile_attacks']}
 if isinstance(v,list):return [common(x) for x in v]
 return v
ordinary={}
for phase in ['state_before','state_after']:
 left=common(pa[phase]['canonical_kernel']);right=common(pb[phase]['canonical_kernel']);ordinary[phase+'_common_native_state_equal']=left==right
 ordinary[phase+'_game_rng_equal']=pa[phase]['game_rng']==pb[phase]['game_rng']
assert all(ordinary.values())
old=json.loads((E.parent/'perf/Alegend.json').read_text(encoding='utf8'))['missile_audit']
result={'legend_carrier_accounting':rows,'legend_arrival_difference':{'sample_B_impacts_minus_A':rows['B']['sample_impacts']-rows['A']['sample_impacts'],'whole_B_impacts_minus_A':rows['B']['whole_impacts']-rows['A']['whole_impacts'],'B_extra_carriers_at_sample_start':rows['B']['sample_start_carriers']-rows['A']['sample_start_carriers'],'B_extra_carriers_at_sample_end':rows['B']['sample_end_carriers']-rows['A']['sample_end_carriers'],'interpretation':'Aggregate difference closes exactly in still-live carriers, not fewer births, deaths, lost projectiles or fewer wild explosions. No claim assigns the six carriers to a geometry function or individual instance.'},'cache_accounting':{'whole_A_firsts':ca['cache_firsts'],'whole_B_firsts':cb['cache_firsts'],'whole_A_reuses':ca['cache_hits'],'whole_B_reuses':cb['cache_hits'],'additional_reuses':extra_cache,'not_yet_arrived_hits':missing,'first_count_difference_equals_reuse_shift_plus_arrival_difference':True,'interpretation':'Derived-salvo shared cache correction intentionally replaces repeated first evaluations; target 111 carries all 49 additional reuses. Prior detailed coverage and targeted tests verify the context boundary.'},'wild_accounting':{'roots_both':ca['missile_attacks'],'substitutions_both':ca['wild_substitutions'],'detonations_both':ca['wild_blasts'],'remaining_unused_wild_B':remaining_wild,'aoe_hits_both':ca['recursion_blocked_entries'],'targets_per_detonation':15,'effective_layer_growth_both':ca['effective_layer_growth']},'earlier_full_coverage_diagnostic':{'repeat_cancellations_A':len(old['cancelled_repeats']),'ejection_cancellations_A':len(old['cancelled_ejections']),'observation_errors_A':old['errors'],'note':'No cancellation or death occurred in this held-health load; do not attribute this sample difference to known repeat-lifecycle or death-reentry fixes. Death uniqueness was tested separately.'},'ordinary':ordinary,'ordinary_common_projection_exclusions':['native_context','missile_attacks','RandomNumberGenerator.seed metadata (kernel instantiates RNG then assigns the authoritative state; state matches exactly)'],'sampling_runs_added_for_attribution':0}
(E/'attribution.json').write_text(json.dumps(result,indent=2),encoding='utf8');print(json.dumps(result,indent=2))
