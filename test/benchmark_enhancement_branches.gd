extends SceneTree
# Controlled, paired-seed experiments through the real BattleGame runtime.
# Synthetic fixtures vary inputs only; no save, source table, or player data writes.
const N=preload("res://scripts/growth_number.gd")
const EFFECTS={"weapons":["proficiency","repeat","critical"],"defence":["adaptation","memory_material","delayed_damage"]}
const SEEDS=[107,211,307,401,503,601,701,809]
const REPEAT30_EXTRA_SEEDS=[907,1009,1103,1201,1301,1409,1511,1601]
var rows:Array=[]
var commit="unset"
var started=0
var sample_cache={}
var conservation={}
var penetration_scope={}
var repeat_generations={}
var beam_hooks={}
class ObservedGame extends BattleGame:
 var dealt=0.0
 var sources={}
 var counts={}
 var original_hits=0
 var rolled_crit=0
 var damage_bonus_crit=0
 var clock=0.0
 var incoming_scale=1.0
 var cover_time_active=0.0
 var cover_time_nonempty=0.0
 var cover_absorbed=0.0
 var kills=[]
 var launched_damage=[]
 func _init(database):
  super(database,false)
  event.connect(on_event)
 func on_event(kind,_payload):counts["event_"+kind]=counts.get("event_"+kind,0)+1
 func launch_player_attack(index,target,weapon,attack,offset,visual_spread,salvo_index=0,salvo_count=1):
  launched_damage.append(float(attack.damage))
  counts["projectile_launch"]=counts.get("projectile_launch",0)+1
  super.launch_player_attack(index,target,weapon,attack,offset,visual_spread,salvo_index,salvo_count)
 func hit_enemy(enemy,raw,type,effects=[],critical=false):
  var before=enemy.hp
  super.hit_enemy(enemy,raw,type,effects,critical)
  var actual=float(N.subtract(before,N.maximum(0,enemy.hp)))
  dealt+=actual
  var source="derived"
  for effect in effects:
   if effect.has("source"):source=str(slot_entry("weapons",int(effect.source)).get("key","unknown"));break
  sources[source]=sources.get(source,0.0)+actual
  counts["outgoing_hit"]=counts.get("outgoing_hit",0)+1
  if critical:counts["critical_hit_event"]=counts.get("critical_hit_event",0)+1
  if before>0 and enemy.hp<=0:kills.append(clock)
 func jewel_attack(index,multiplier=1.0):
  var attack=super.jewel_attack(index,multiplier)
  counts["attack_resolution"]=counts.get("attack_resolution",0)+1
  if attack.critical:rolled_crit+=1
  if attack.get("critical_bonus_applied",false):damage_bonus_crit+=1
  return attack
 func begin_enhancement_attack(index,target,derived=false,track_primary=true):
  if not derived:
   var kind="canonical_primary" if track_primary else "canonical_extra_repeat"
   counts[kind]=counts.get(kind,0)+1
  return super.begin_enhancement_attack(index,target,derived,track_primary)
 func finish_enhancement_attack(index):
  var context=enhancement_attack_contexts.get(index,{})
  if context.get("critical",false) and not context.get("derived",false):counts["canonical_critical_event"]=counts.get("canonical_critical_event",0)+1
  super.finish_enhancement_attack(index)
 func cover_total():
  var total=0.0
  for data in enhancement_branches.defenses.values():total+=float(data.cover)
  return total
 func hit_player(raw,type,context={}):
  original_hits+=1
  var before=cover_total()
  super.hit_player(raw,type,context)
  cover_absorbed+=maxf(0.0,before-cover_total())
func _initialize():call_deferred("run")
func fixture(level:int,choices:Dictionary,scenario:Dictionary)->ObservedGame:
 var db=ShipDatabase.new()
 for key in ([] if scenario.get("production",false) else ["laser","cannon","missile","longLaser"]):
  var r=db.equipment[key][0]
  r.dmg=20;r.dmgMulti=0;r.cri=0;r.criDmg=0;r.cd=.25;r.speed=4000
 if not scenario.get("production",false):
  db.equipment.cannon[0].dmg=160;db.equipment.cannon[0].cd=2
  db.equipment.missile[0].dmg=20;db.equipment.missile[0].cd=1;db.equipment.missile[0].para1=4
  db.equipment.longLaser[0].dmg=8;db.equipment.longLaser[0].cd=.1
  db.equipment.longLaser[0].para1=0;db.equipment.longLaser[0].para2=1;db.equipment.longLaser[0].para3=0
  for key in ["armour","shield"]:
   db.equipment[key][0].para1=100
   db.equipment[key][0]["para2" if key=="armour" else "para4"]=0
  db.equipment.shield[0].para2=0
 if scenario.has("cadence"):
  var wr=db.equipment[str(scenario.get("weapon","laser"))][0];wr.cd=float(scenario.cadence);wr.dmg=80*float(scenario.cadence)
 db.config.dmgReduce=.5
 var g=ObservedGame.new(db)
 g.stat_cache_enabled=true
 g.profile.grantedUnlocks=[db.unlock_id("feature","jewels")]
 g.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
 g.profile.enhancementLevel=level
 g.profile.enhancementAttacks=1000;g.profile.enhancementHits=1000
 if scenario.has("mix"):
  for ship_id in db.ships:
   if int(db.ships[ship_id].defenseSlots)>=3:
    g.profile.selectedShip=ship_id;g.profile.grantedUnlocks.append(db.unlock_id("ship",ship_id));break
 g.profile.loadout={"weapons":[{"key":scenario.get("weapon","laser"),"level":150}],"defence":[{"key":"shield","level":150},{"key":"armour","level":150}]}
 if scenario.has("mix"):
  g.profile.loadout.defence=[]
  for token in str(scenario.mix):g.profile.loadout.defence.append({"key":"shield" if token=="s" else "armour","level":150})
 for category in choices:
  for effect in choices[category]:
   for node in choices[category][effect]:
    if not g.set_enhancement_branch(category,effect,int(node),choices[category][effect][node]):push_error("invalid branch fixture")
 if scenario.has("secondary_probability"):
  g.db.data.enhance_config.repeat_b3_probability.value=float(scenario.secondary_probability)
 g.reset_player();g.state=BattleGame.State.COMBAT
 g.spawn_group()
 var template=g.enemies[0].duplicate(true)
 g.enemies.clear()
 for index in int(scenario.get("enemies",1)):
  var e=template.duplicate(true)
  e.uid=100+index;e.slot=index;e.x=200+index*80;e.y=230-index*2
  e.hp=float(scenario.get("hp",maxf(1e12,g.equipment_stat(str(scenario.get("weapon","laser")),150)*(1.0+level*.3)*1e7) if scenario.get("production",false) else 1e12));e.max_hp=e.hp;e.drops=[];e.equipment=[];e.cooldowns=[]
  e.armourType=int(db.equipment[str(scenario.get("weapon","laser"))][0].dmgtype) if scenario.get("resisted",false) else -99
  if scenario.has("ttk_attack_units"):
   e.hp=float(g.equipment_stat(str(scenario.get("weapon","laser")),150))*float(scenario.ttk_attack_units)*(1+g.enhancement_parameter("base_critical_rate")*(g.enhancement_parameter("base_critical_multiplier")+30*g.enhancement_parameter("critical_growth")-1));e.max_hp=e.hp
  if e.x<0 or e.x>BattleGame.BATTLE_SIZE.x or e.y<0 or e.y>BattleGame.BATTLE_SIZE.y:
   push_error("Stationary benchmark enemy is outside actual battlefield: "+JSON.stringify({"position":[e.x,e.y],"bounds":[BattleGame.BATTLE_SIZE.x,BattleGame.BATTLE_SIZE.y],"scenario":scenario}));quit(2)
  assert(e.x>=0 and e.x<=BattleGame.BATTLE_SIZE.x and e.y>=0 and e.y<=BattleGame.BATTLE_SIZE.y,"Stationary benchmark target must be inside the real battlefield")
  g.enemies.append(e)
 g.cooldowns[g.slot_id("weapons",0)]=999 if scenario.has("incoming") and not scenario.get("joint",false) else 0
 return g
func sample(level:int,choices:Dictionary,scenario:Dictionary,seed_value:int,tag:String)->Dictionary:
 var g=fixture(level,choices,scenario)
 g.rng.seed=seed_value
 if scenario.has("precharge"):g.advance_jewel_repair(float(scenario.precharge))
 var duration=float(scenario.get("duration",10))
 var initial_hp=float(g.player.armour+g.player.shield)
 var incoming=0.0
 var last_incoming=-999.0
 var last_swap=-999.0
 var survival=-1.0
 var time=0.0
 for step in int(round(duration*60)):
  time=float(step)/60.0;g.clock=time
  if scenario.has("swap") and time-last_swap>=float(scenario.swap)-.000001:
   last_swap=time
   var e=g.enemies.pop_front();g.enemies.append(e)
   for i in g.enemies.size():g.enemies[i].y=230-i*2
  if scenario.has("incoming") and time>=float(scenario.get("phase",0))-.000001 and time-last_incoming>=float(scenario.get("interval",.25))-.000001:
   last_incoming=time
   var raw=float(scenario.incoming)*(1.0+level*.3)
   incoming+=raw
   var dtype=int(g.db.equipment.shield[0].dmgtype) if scenario.get("typed",false) else -99
   if scenario.get("alternating",false):dtype=int(g.db.equipment["shield" if g.original_hits%2==0 else "armour"][0].dmgtype)
   g.hit_player(raw,dtype,{"source_uid":100+int(g.original_hits)%int(scenario.get("source_count",1)),"weapon_key":"synthetic_incoming"})
  if g.state==BattleGame.State.RETREAT:survival=time;break
  g.tick(1.0/60.0)
  if g.enhancement_branches.defenses.values().any(func(d):return d.cover_time>0):g.cover_time_active+=1.0/60.0
  if g.cover_total()>0:g.cover_time_nonempty+=1.0/60.0
  if g.state==BattleGame.State.RETREAT:survival=time+1.0/60.0;break
  if not g.has_alive_enemy():break
 var observed=time+1.0/60.0
 var remaining=float(g.player.armour+g.player.shield)
 return {"tag":tag,"scenario":scenario.name,"scenario_inputs":scenario,"level":level,"seed":seed_value,"choices":choices,"seconds":observed,"damage":g.dealt,"dps":g.dealt/observed,"ttk":g.kills[-1] if not g.kills.is_empty() else null,"kills":g.kills.size(),"wave_cleared":not g.has_alive_enemy(),"wave_clear_ttk":g.kills[-1] if not g.has_alive_enemy() and not g.kills.is_empty() else null,"survival":survival if survival>=0 else null,"survived_window":survival<0,"initial_body":initial_hp,"remaining_body":remaining,"incoming_raw":incoming,"precharge_seconds":scenario.get("precharge",0),"raw_ehp_until_death":incoming if survival>=0 else null,"raw_ehp_censored_lower_bound":incoming if survival<0 else null,"debt_remaining":float(g.enhancement_deferred_total()),"protection_remaining":float(g.enhancement_protection_current()),"sources":g.sources,"event_counts":g.counts,"incoming_events":g.original_hits,"attacks_added":g.profile.enhancementAttacks-1000,"crit_events":g.rolled_crit,"critical_damage_applied":g.damage_bonus_crit,"cover_duty":g.cover_time_active/observed,"cover_nonempty_duty":g.cover_time_nonempty/observed,"cover_absorbed":g.cover_absorbed}
func choice(category:String,effect:String,pattern:String)->Dictionary:
 if pattern.replace("-","").is_empty():return {}
 var d={category:{effect:{}}}
 for i in pattern.length():
  if pattern[i] in ["A","B"]:d[category][effect][str(i+1)]=pattern[i]
 return d
func output():
 var path=OS.get_environment("ENHANCEMENT_BENCH_OUTPUT")
 if path.is_empty():path="user://enhancement-balance.json"
 var file=FileAccess.open(path,FileAccess.WRITE)
 file.store_string(JSON.stringify({"beam_hooks":beam_hooks,"repeat_generations":repeat_generations,"penetration_scope":penetration_scope,"burst_conservation":conservation,"commit":commit,"engine":Engine.get_version_info().string,"paired_seeds":SEEDS+REPEAT30_EXTRA_SEEDS if OS.get_environment("REPEAT30_SEED_SET")=="16" else REPEAT30_EXTRA_SEEDS if OS.get_environment("REPEAT30_SEED_SET")=="extra" else SEEDS,"actual_seed_counts": "repeat30:see per-scenario rows" if OS.get_environment("ENHANCEMENT_BENCH_STAGE")=="repeat30" else "smoke1/focus4/risk or full2","fixed_initial_attack_history":1000,"fixed_initial_hit_history":1000,"module_levels":150,"simulation":"original exact 1/60 BattleGame.tick","fixture_limits":"synthetic fixed loadout, no economy, stationary target; raw incoming fixtures, no claim of full-game population balance","rows":rows},"\t"))
 print("BALANCE_ROWS=",rows.size()," PATH=",path," WALL_SECONDS=",(Time.get_ticks_msec()-started)/1000.0)
func run():
 started=Time.get_ticks_msec();commit=OS.get_environment("ENHANCEMENT_TESTED_COMMIT")
 var cg=fixture(30,{}, {"name":"oversized_conservation","incoming":1600})
 cg.db.data.enhance_config.deferred_clear_probability.value=0
 var before=float(cg.player.armour+cg.player.shield)
 var raw=before*8
 cg.hit_player(raw,-99,{"source_uid":100})
 var immediate=before-float(cg.player.armour+cg.player.shield)
 var deferred=float(cg.enhancement_deferred_total())
 conservation={"raw_untyped":raw,"body_before":before,"immediate_body_loss":immediate,"deferred_queued":deferred,"difference":raw-immediate-deferred,"passed":absf(raw-immediate-deferred)<.00001,"cleared":0,"memory_or_cover_before":0}
 if not conservation.passed:
  output();push_error("Oversized untyped input is not conserved before any clear: "+JSON.stringify(conservation));quit(2);return
 var pg=fixture(30,choice("weapons","proficiency","--B"),{"name":"penetration_scope","resisted":true})
 pg.profile.loadout.weapons.append({"key":"laser","level":49});pg.invalidate_stat_cache()
 var target=pg.enemies[0];var hp_before=float(target.hp);var resistance_before=int(target.armourType)
 pg.hit_enemy(target,100,int(pg.db.equipment.laser[0].dmgtype),pg.jewel_attack(0).effects,false)
 var eligible=hp_before-float(target.hp);hp_before=float(target.hp)
 pg.hit_enemy(target,100,int(pg.db.equipment.laser[0].dmgtype),pg.jewel_attack(1).effects,false)
 var ineligible=hp_before-float(target.hp)
 var eligible_expected=ceilf(100*(1-pg.enhancement_parameter("proficiency_b3_resistance")))
 var ineligible_expected=ceilf(100*(1-float(pg.db.config.dmgReduce)))
 penetration_scope={"eligible_damage":eligible,"ineligible_same_type_damage":ineligible,"expected_eligible":eligible_expected,"expected_ineligible":ineligible_expected,"enemy_resistance_type_unchanged":int(target.armourType)==resistance_before,"passed":eligible==eligible_expected and ineligible==ineligible_expected and int(target.armourType)==resistance_before}
 if not penetration_scope.passed:
  output();push_error("Penetration leaked across attacking eligibility: "+JSON.stringify(penetration_scope));quit(2);return
 var rg=fixture(30,choice("weapons","repeat","-B-"),{"name":"repeat_generations"})
 rg.db.data.enhance_config.repeat_probability.value=1
 rg.db.data.enhance_config.base_critical_rate.value=0
 rg.invalidate_stat_cache()
 var row=rg.player_weapon_row(rg.slot_entry("weapons",0));var primary=rg.enemies[0]
 rg.begin_enhancement_attack(0,primary);rg.jewel_fire(0,primary,row,Vector2.ZERO);rg.finish_enhancement_attack(0)
 rg.queue_jewel_repeats(0,1)
 rg.advance_jewel_repeats(rg.enhancement_parameter("repeat_delay"))
 rg.advance_jewel_repeats(rg.enhancement_parameter("repeat_delay"))
 var expected_repeat=rg.launched_damage[0]*(1+rg.enhancement_parameter("repeat_growth")*30)
 repeat_generations={"launched_damage":rg.launched_damage,"expected_each_extra":expected_repeat,"remaining_repeats":rg.jewel_repeats.size(),"passed":rg.launched_damage.size()==3 and is_equal_approx(rg.launched_damage[1],expected_repeat) and is_equal_approx(rg.launched_damage[2],expected_repeat) and rg.jewel_repeats.is_empty()}
 if not repeat_generations.passed:
  output();push_error("Repeat generations inherited extra damage or exceeded cap: "+JSON.stringify(repeat_generations));quit(2);return
 var q=RandomNumberGenerator.new();var chosen_seed=0
 var bp=rg.enhancement_parameter("repeat_probability")
 # rg's private forced probability is1; use a fresh table for live default probe.
 var live=fixture(30,{}, {"name":"beam_hook","weapon":"longLaser"})
 bp=live.enhancement_parameter("repeat_probability")
 var ap=bp+live.enhancement_parameter("repeat_a_probability")
 for candidate in range(1,10000):
  q.seed=candidate;var draw=q.randf()
  if draw>=bp and draw<ap:chosen_seed=candidate;break
 var lottery_counts=[]
 for opt in ["---","A--"]:
  var bg=fixture(30,choice("weapons","repeat",opt),{"name":"beam_hook","weapon":"longLaser"})
  bg.rng.seed=chosen_seed;bg.tick(1.0/60.0);lottery_counts.append(bg.jewel_repeats.size())
 var bg2=fixture(30,choice("weapons","repeat","-B-"),{"name":"beam_hook_depth","weapon":"longLaser"})
 bg2.db.data.enhance_config.repeat_probability.value=1;bg2.db.data.enhance_config.base_critical_rate.value=0;bg2.invalidate_stat_cache();bg2.rng.seed=107
 for i in 120:bg2.tick(1.0/60.0)
 var streams=bg2.projectiles.filter(func(p):return p.get("beam",false)).map(func(p):return {"depth":p.get("repeat_depth",0),"multiplier":p.repeat_multiplier})
 beam_hooks={"selected_lottery_seed":chosen_seed,"default_vs_A_pending":lottery_counts,"forced_B20_streams":streams,"passed":lottery_counts==[0,1] and streams.size()==3 and is_equal_approx(float(streams[1].multiplier),1+bg2.enhancement_parameter("repeat_growth")*30) and is_equal_approx(float(streams[2].multiplier),1+bg2.enhancement_parameter("repeat_growth")*30)}
 if not beam_hooks.passed:
  output();push_error("Beam repeat hook missing or recursion contract failed: "+JSON.stringify(beam_hooks));quit(2);return
 if OS.get_environment("ENHANCEMENT_BENCH_STAGE")=="repeat30":
  # Narrow repeat30 paired supplement; other enhancement choices stay fixed.
  var seed_set=OS.get_environment("REPEAT30_SEED_SET")
  var probe_seeds=SEEDS+REPEAT30_EXTRA_SEEDS if seed_set=="16" else REPEAT30_EXTRA_SEEDS if seed_set=="extra" else SEEDS
  var probability=float(OS.get_environment("REPEAT30_PROBABILITY"))
  if probability<=0:probability=.2
  for production in [false,true]:
   for enemy_count in [1,3]:
    if not OS.get_environment("REPEAT30_ENEMIES").is_empty() and enemy_count!=int(OS.get_environment("REPEAT30_ENEMIES")):continue
    for measurement in ["dps","ttk"]:
     var only=OS.get_environment("REPEAT30_MEASUREMENT")
     if not only.is_empty() and measurement!=only:continue
     var scenario={"name":("production_missile" if production else "fast_laser")+"_"+str(enemy_count)+"_"+measurement,"weapon":"missile" if production else "laser","production":production,"enemies":enemy_count,"duration":20 if measurement=="dps" else 45,"secondary_probability":probability,"bounded_targets":true}
     if measurement=="ttk":scenario.ttk_attack_units=1000
     for pattern in ["--A","--B","AAA","AAB"]:
      for seed_value in probe_seeds:
       rows.append(sample(30,choice("weapons","repeat",pattern),scenario,seed_value,"repeat:"+pattern))
      print("REPEAT30_PROGRESS rows=",rows.size()," scenario=",scenario.name," probability=",probability," elapsed=",(Time.get_ticks_msec()-started)/1000.0)
      output()
  output();quit();return
 if OS.get_environment("ENHANCEMENT_BENCH_STAGE")=="corrected_cited":
  var probes=[
  {"level":10,"effect":"proficiency","patterns":["A","B"],"scenario":{"name":"corrected_proficiency10_swap1","duration":10,"enemies":3,"swap":1}},
  {"level":20,"effect":"proficiency","patterns":["-A","-B"],"scenario":{"name":"corrected_proficiency20_swap1","duration":10,"enemies":3,"swap":1}},
  {"level":10,"effect":"repeat","patterns":["A","B"],"scenario":{"name":"corrected_repeat10_missile_multi","duration":10,"weapon":"missile","enemies":3}},
  {"level":20,"effect":"repeat","patterns":["-A","-B"],"scenario":{"name":"corrected_repeat20_missile_multi","duration":10,"weapon":"missile","enemies":3}},
  {"level":10,"effect":"critical","patterns":["A","B"],"scenario":{"name":"corrected_critical10_missile_multi","duration":10,"weapon":"missile","enemies":3}}]
  for probe in probes:
   for pattern in probe.patterns:
    for seed_value in SEEDS.slice(0,4):rows.append(sample(probe.level,choice("weapons",probe.effect,pattern),probe.scenario,seed_value,probe.effect+":"+pattern))
   print("CORRECTION_PROGRESS rows=",rows.size()," scenario=",probe.scenario.name)
   output()
  output();quit();return
 # First risk matrix: incremental A/B choices and specific mixed combos.
 var offence=[{"name":"ttk_short","duration":30,"hp":2500},{"name":"ttk_long","duration":40,"hp":30000},{"name":"focus2","duration":2},{"name":"focus5","duration":5},{"name":"focus10","duration":10},{"name":"focus20","duration":20},{"name":"swap1","duration":10,"enemies":3,"swap":1},{"name":"heavy","duration":10,"weapon":"cannon"},{"name":"beam","duration":10,"weapon":"longLaser"},{"name":"missile_multi","duration":10,"weapon":"missile","enemies":3},{"name":"resisted","duration":10,"resisted":true},{"name":"kill_single","duration":20,"hp":30000}]
 var defence=[{"name":"precharged_burst","duration":10,"incoming":1600,"interval":2,"precharge":2},{"name":"shield_heavy","duration":10,"incoming":50,"interval":.05,"mix":"ssa"},{"name":"armour_heavy","duration":10,"incoming":1600,"interval":2,"mix":"saa"},{"name":"steady_many_sources","duration":10,"incoming":50,"interval":.05,"source_count":4,"enemies":4},{"name":"steady","duration":10,"incoming":50,"interval":.05},{"name":"burst","duration":10,"incoming":1600,"interval":2},{"name":"typed","duration":10,"incoming":100,"interval":.05,"typed":true},{"name":"alternating","duration":10,"incoming":100,"interval":.05,"alternating":true}]
 var stage=OS.get_environment("ENHANCEMENT_BENCH_STAGE")
 for level in ([10] if stage in ["smoke","focus","crossover","delayed_fix"] else [30] if stage in ["production","phase","critical_probe","critical_cadence"] else [20] if stage=="buffer_probe" else [10,20,30]):
  for category in EFFECTS:
   for effect in EFFECTS[category]:
    if stage in ["combos","joint"]:continue
    if stage in ["smoke","focus","crossover"] and effect!="proficiency":continue
    if stage=="phase" and category!="defence":continue
    if stage in ["critical_probe","critical_cadence"] and effect!="critical":continue
    if stage in ["buffer_probe","delayed_fix"] and effect!="delayed_damage":continue
    if stage=="production" and effect not in ["proficiency","critical"]:continue
    if stage=="risks" and effect not in ["proficiency","critical","delayed_damage","adaptation"]:continue
    var scenarios=offence if category=="weapons" else defence
    if stage=="phase":scenarios=[{"name":"memory_precharged_typed","duration":10,"incoming":100,"interval":.05,"precharge":2,"typed":true},{"name":"memory_precharged_alternating","duration":10,"incoming":100,"interval":.05,"precharge":2,"alternating":true},{"name":"cover_phase_on","duration":10,"incoming":1600,"interval":2,"precharge":2,"phase":.5},{"name":"cover_phase_off","duration":10,"incoming":1600,"interval":2,"precharge":2,"phase":1.5}]
    if stage=="buffer_probe":scenarios=[{"name":"precharged_neutral_buffer","duration":10,"incoming":11,"interval":.05,"precharge":2}]
    if stage=="critical_cadence":scenarios=[{"name":"cadence1","duration":10,"cadence":1},{"name":"cadence1_5","duration":10,"cadence":1.5}]
    if stage=="critical_probe":scenarios=[{"name":"focus2","duration":2},{"name":"heavy","duration":10,"weapon":"cannon"}]
    if stage=="crossover":scenarios=[{"name":"focus5","duration":5}]
    if stage=="production":scenarios=[{"name":"production_focus5","duration":5,"production":true},{"name":"production_focus20","duration":20,"production":true},{"name":"production_heavy","duration":10,"weapon":"cannon","production":true},{"name":"production_beam","duration":10,"weapon":"longLaser","production":true},{"name":"production_missile","duration":10,"weapon":"missile","enemies":3,"production":true}]
    var node=int(level/10)
    var patterns=["-".repeat(node),"-".repeat(node-1)+"A","-".repeat(node-1)+"B"]
    if level==30:patterns.append_array(["AAA","AAB","ABA","ABB","BAA","BAB","BBA","BBB"] if effect=="critical" else ["AAA","AAB","ABB","BBB"])
    if stage=="phase":patterns=["---","-A-","-B-"] if effect!="delayed_damage" else ["---","-A-","-B-","AAA","ABB","BBB"]
    if stage=="production":patterns=["---","AAA","BBB"] if effect=="proficiency" else ["BBA","BBB"]
    if stage in ["critical_probe","critical_cadence"]:patterns=["BBA","BBB"]
    for scenario in scenarios:
     if stage=="delayed_fix" and scenario.name not in ["steady","typed","burst"]:continue
     if stage=="production" and effect=="critical" and scenario.name not in ["production_heavy","production_beam"]:continue
     if stage=="phase":
      if effect=="adaptation" and not scenario.name.begins_with("cover_phase"):continue
      if effect=="memory_material" and not scenario.name.begins_with("memory_precharged"):continue
      if effect=="delayed_damage" and scenario.name not in ["cover_phase_off","memory_precharged_typed"]:continue
     if stage=="risks":
      var allowed=["focus2","focus5","focus10","focus20","swap1","ttk_short","ttk_long"] if effect=="proficiency" else ["focus2","heavy","beam","missile_multi"] if effect=="critical" else ["steady","steady_many_sources","typed","alternating"]
      if scenario.name not in allowed:continue
     if stage=="full" and category=="weapons":
      if effect=="proficiency" and level==10:continue
      var allowed=["focus10","swap1","heavy","beam","resisted"] if effect=="proficiency" else ["focus2","beam","missile_multi","kill_single"] if effect=="repeat" else ["focus2","heavy","beam","missile_multi"]
      if scenario.name not in allowed:continue
     if stage=="smoke" and scenario.name!="focus2":continue
     if stage=="focus" and scenario.name not in ["focus2","focus5","focus10","focus20","swap1","ttk_short","ttk_long"]:continue
     for pattern in patterns:
      for seed_value in (SEEDS.slice(0,1) if stage=="smoke" else SEEDS if stage in ["crossover","critical_probe","critical_cadence"] else SEEDS.slice(0,4) if stage in ["focus","phase","buffer_probe","delayed_fix"] else SEEDS.slice(0,2)):
       var choices=choice(category,effect,pattern)
       var cache_key=JSON.stringify([level,choices,scenario,seed_value])
       if not sample_cache.has(cache_key):sample_cache[cache_key]=sample(level,choices,scenario,seed_value,effect+":"+pattern)
       var record=sample_cache[cache_key].duplicate(true);record.tag=effect+":"+pattern
       rows.append(record)
       if rows.size()%24==0:print("BALANCE_PROGRESS rows=",rows.size()," scenario=",scenario.name," elapsed=",(Time.get_ticks_msec()-started)/1000.0)
  output()
 if stage in ["risks","full","combos"]:
  var combos=[{}, {"defence":{"adaptation":{"2":"B"},"memory_material":{"3":"B"}}}, {"defence":{"delayed_damage":{"2":"B","3":"B"},"memory_material":{"3":"B"}}}, {"defence":{"adaptation":{"2":"B","3":"B"},"memory_material":{"2":"B","3":"B"}}}]
  for scenario in defence:
   for i in combos.size():
    for seed_value in SEEDS.slice(0,4):rows.append(sample(30,combos[i],scenario,seed_value,"cross_combo:"+str(i)))
 if stage in ["risks","full","combos"]:
  var offence_combos=[{}, {"weapons":{"proficiency":{"1":"A","2":"A","3":"A"},"repeat":{"1":"A","2":"A","3":"A"},"critical":{"1":"A","2":"A","3":"A"}}}, {"weapons":{"proficiency":{"1":"B","2":"B","3":"B"},"repeat":{"1":"B","2":"B","3":"B"},"critical":{"1":"B","2":"B","3":"B"}}}]
  for scenario in offence:
   if scenario.name not in ["focus5","focus20","swap1","heavy","beam","missile_multi","resisted"]:continue
   for i in offence_combos.size():
    for seed_value in SEEDS.slice(0,2):rows.append(sample(30,offence_combos[i],scenario,seed_value,"weapon_cross_combo:"+str(i)))
 if stage=="joint":
  var aa={"proficiency":{"1":"A","2":"A","3":"A"},"repeat":{"1":"A","2":"A","3":"A"},"critical":{"1":"A","2":"A","3":"A"}}
  var bb={"proficiency":{"1":"B","2":"B","3":"B"},"repeat":{"1":"B","2":"B","3":"B"},"critical":{"1":"B","2":"B","3":"B"}}
  var da={"adaptation":{"1":"A","2":"A","3":"A"},"memory_material":{"1":"A","2":"A","3":"A"},"delayed_damage":{"1":"A","2":"A","3":"A"}}
  var dbb={"adaptation":{"1":"B","2":"B","3":"B"},"memory_material":{"1":"B","2":"B","3":"B"},"delayed_damage":{"1":"B","2":"B","3":"B"}}
  var profiles=[{"weapons":aa,"defence":da},{"weapons":bb,"defence":da},{"weapons":aa,"defence":dbb},{"weapons":bb,"defence":dbb}]
  var cases=[{"name":"joint_focus_single","duration":60,"hp":1e7,"incoming":250,"interval":.05,"precharge":2,"joint":true},{"name":"joint_focus_many_sources","duration":60,"hp":1e7,"incoming":250,"interval":.05,"precharge":2,"joint":true,"enemies":4,"source_count":4},{"name":"joint_swap","duration":60,"hp":1e7,"incoming":250,"interval":.05,"precharge":2,"joint":true,"enemies":3,"source_count":3,"swap":1},{"name":"joint_large_burst_gap","duration":60,"hp":1e7,"incoming":6400,"interval":2,"precharge":2,"joint":true,"phase":1.5}]
  for scenario in cases:
   for i in profiles.size():
    for seed_value in SEEDS.slice(0,2):
     rows.append(sample(30,profiles[i],scenario,seed_value,"joint_profile:"+str(i)))
     output()
 output();quit()
