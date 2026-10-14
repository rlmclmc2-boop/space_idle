extends SceneTree
const Compiler=preload("res://scripts/native_execution_compiler.gd")
const Handoff=preload("res://scripts/native_execution_handoff.gd")
const Session=preload("res://scripts/native_execution_session.gd")
class MissileGame extends "res://scripts/presented_battle_game.gd":
 var guidance:Variant={"constants":{"stack_multiplier":2.0,"stack_limit_enabled":false,"stack_limit":0,"counting_policy":"first_hit_per_batch_per_target"}}
 var wild:Variant=null
 func hyperspace_totals()->Dictionary:
  var totals=super.hyperspace_totals().duplicate(true)
  if guidance!=null:totals.legendary.precise_guidance=guidance
  if wild!=null:totals.legendary.wild_missile=wild
  return totals
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func actor(uid:int=100,hp:float=1e6)->Dictionary:
 return {"uid":uid,"slot":uid-96,"x":30.0,"y":0.0,"hp":hp,"max_hp":hp,"armourType":2,"shieldType":0,"shield":0.0,"max_shield":0.0,"equipment":[],"cooldowns":[],"drops":[],"res_ratio":1.0}
func world()->Dictionary:
 return {"clock":0.0,"repeat_delay":0.1,"hit_radius":1000.0,"ejection_gap":0.05,"rng_state":418,"resistance":0.5,"requires_missile_legends":true,"precise_guidance":true,"guidance_multiplier":2.0,"guidance_limited":false,"guidance_limit":0,"wild_missile":false,"wild_multiplier":1.0,"wild_period":3,"wild_blast":0.5,"wild_damage_type":1,"missile_attacks":0,"defences":[],"player":{"x":50.0,"y":0.0,"armour":100.0,"shield":100.0},"enemies":[actor()],"weapons":[{"kind":2,"type":1,"slot":0,"source":-1,"hostile":false,"damage":10.0,"factor":1.0,"interval":10.0,"remaining":0.0,"speed":720.0,"charge":-1.0,"ramp":1.0,"maximum":1.0,"salvo":3,"muzzle":Vector2.ZERO,"critical_rate":0.0,"critical_multiplier":2.0,"repeat_probability":0.0,"repeat_multiplier":1.0,"entry":{"key":"missile","level":1},"row":{"cd":10.0,"para1":3,"dmgtype":1}}]}
func step(k,count:int)->void:
 for i in count:
  if not k.advance(0.01):check(false,"advance rejected at "+str(i));return
func fixture():
 var g=MissileGame.new(ShipDatabase.new(),false)
 g.db.equipment.missile[0].dmgtype=1
 g.profile.unlocked=BattleGame.EQUIPMENT.duplicate();g.profile.resources={"1":1e30,"2":1e30}
 g.profile.loadout.weapons[0].key="missile"
 g.profile.loadout.defence=[{"key":"armour","level":1},{"key":"shield","level":1}]
 g.invalidate_stat_cache();g.reset_player();g.state=BattleGame.State.COMBAT
 var a=actor();a.x=286.0;a.y=150.0;g.enemies.assign([a])
 g.cooldowns[g.slot_id("weapons",0)]=0.0
 return g
func _initialize()->void:call_deferred("run")
func run()->void:
 Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 print("CONFIG cap=",Engine.max_fps," vsync=",DisplayServer.window_get_vsync_mode()," display=",DisplayServer.get_name())
 var k=ClassDB.instantiate("SpaceCombatKernel");var d=world()
 d.enemies[0].guidance_layers=2;d.weapons[0].interval=0.5
 check(k.configure(d),"guidance admission");step(k,30)
 check(k.enemy_views()[0].hp==1e6-120 and k.enemy_views()[0].guidance_layers==3,"primary salvo freezes same-target factor and increments once")
 step(k,50)
 check(k.enemy_views()[0].hp==1e6-360 and k.enemy_views()[0].guidance_layers==4,"independent root uses next layer once")
 check(k.metrics().missile_attacks==2,"one missile count per root")
 var observed=k.missile_legend_metrics()
 check(observed.cache_firsts==2 and observed.cache_hits==4 and observed.effective_layer_growth==2 and observed.missile_hits==6,"on-demand native guidance counters")
 check(observed.targets[0].first_factor==4.0 and observed.targets[0].last_factor==8.0 and observed.targets[0].min_factor==4.0 and observed.targets[0].max_factor==8.0,"on-demand per-target first factor extrema")
 d=world();d.weapons[0].repeat_probability=1.0;d.weapons[0].secondary_probability=1.0;d.weapons[0].chain_count=1;d.enemies.append(actor(101));d.hit_radius=0.01
 check(k.configure(d),"derived contexts admission");step(k,1)
 var state=k.export_handoff();var normal=[];var derived=[]
 for row in state.flights+state.ejections:
  var c=row.native_context
  if c.value.trigger_depth==0:normal.append(row)
  else:derived.append(row)
 check(normal.size()==3 and derived.size()==3,"primary and secondary complete salvos retained")
 check(normal.all(func(r):return r.native_context.id==normal[0].native_context.id) and derived.all(func(r):return r.native_context.id==derived[0].native_context.id),"each salvo shares one context")
 check(normal[0].native_context.id!=derived[0].native_context.id and normal[0].instance.id==derived[0].instance.id,"secondary distinct context but shared chain instance")
 step(k,10);state=k.export_handoff()
 var repeat_rows=(state.flights+state.ejections).filter(func(r):return r.instance.id!=normal[0].instance.id)
 check(repeat_rows.size()==3 and repeat_rows.all(func(r):return r.native_context.id==repeat_rows[0].native_context.id),"independent repeat creates one context for all tubes")
 check(repeat_rows[0].native_context.id!=derived[0].native_context.id and repeat_rows[0].native_context.value.chain_allowance,"repeat independent context and chain allowance")
 d=world();d.weapons[0].secondary_probability=1.0;d.weapons[0].chain_count=1;d.enemies.append(actor(101))
 check(k.configure(d),"secondary shared chain admission");step(k,30)
 var chain_births=k.take_feedback().filter(func(e):return e.kind==4)
 check(chain_births.size()==1,"primary and secondary share one actual chain launch allowance")
 d=world();d.weapons[0].repeat_probability=1.0;d.repeat_delay=0.01
 check(k.configure(d),"derived damage admission");step(k,30)
 check(k.enemy_views()[0].guidance_layers==1 and k.enemy_views()[0].hp==1e6-90,"derived salvo gets guidance without adding layers")
 # A distinct root changes layers between later tubes; the derived salvo keeps its first factor.
 d=world();d.weapons[0].repeat_probability=1.0;d.ejection_gap=0.2;d.repeat_delay=0.05
 var second=d.weapons[0].duplicate(true);second.slot=1;second.remaining=0.12;second.salvo=1;second.row.para1=1;second.repeat_probability=0.0;d.weapons.append(second)
 check(k.configure(d),"interleaved roots admission");step(k,60)
 check(k.enemy_views()[0].guidance_layers==2 and k.enemy_views()[0].hp==1e6-110,"later layer change cannot reprice same derived salvo")
 for scenario in [0,1,2]:
  d=world();d.precise_guidance=false;d.wild_missile=true;d.wild_period=0;d.final_encounter=true
  d.enemies[0].hp=12.0 if scenario==0 else 8.0 if scenario==1 else 100.0
  if scenario==2:d.enemies.append(actor(101,4.0))
  d.drop_rules_compiled=true
  for a in d.enemies:a.compiled_drops=[{"chance":1.0,"amount":1.0,"base":1.0,"resource":3}];a.jewel_rolls=0
  check(k.configure(d),"wild death admission "+str(scenario));step(k,3)
  var events=k.take_feedback();var deaths=events.filter(func(e):return e.kind==3);var drops=events.filter(func(e):return e.kind==7)
  check(deaths.size()==1 and drops.size()==1 and k.metrics().deaths==1,"native one death/drop "+str(scenario))
  check(k.metrics().hits==(1 if scenario==1 else 2 if scenario==0 else 3),"wild once-only AoE "+str(scenario))
  observed=k.missile_legend_metrics()
  check(observed.wild_substitutions==1 and observed.wild_blasts==1 and observed.recursion_blocked_entries==(0 if scenario==1 else 1 if scenario==0 else 2),"actual native wild counters "+str(scenario))
  if scenario<2:check(k.metrics().final_cleared,"final clear after unique death "+str(scenario))
  var g=fixture();g.guidance=null;g.enemies[0].hp=d.enemies[0].hp;g.enemies[0].drops=[{"chance":1.0,"amount":1.0,"resourceId":3}]
  if scenario==2:
   var other=actor(101,4.0);other.drops=[{"chance":1.0,"amount":1.0,"resourceId":3}];g.enemies.append(other)
  var explosions=[];g.event.connect(func(kind,payload):
   if kind=="explode":explosions.append(payload.uid))
  var context=g.CombatContext.derive(g.CombatContext.root(1,"module:0","missile"),"wild_missile");context.wild_missile=true;context.blast_fraction=0.5
  g.hit_enemy(g.enemies[0],10.0,1,[],false,context)
  check(explosions.size()==1 and g.drops.size()==1,"Game one death/drop "+str(scenario))
 # Birth substitution consumes one counter and no secondary/repeat random draws.
 d=world();d.wild_missile=true;d.wild_period=0;d.wild_multiplier=7.0;d.weapons[0].repeat_probability=1.0;d.weapons[0].secondary_probability=1.0;d.enemies.append(actor(101))
 check(k.configure(d),"wild substitution admission");step(k,1);state=k.export_handoff()
 check(state.flights.size()+state.ejections.size()==1 and state.repeats.is_empty() and state.missile_attacks==1,"wild replaces entire salvo and excludes repeats/secondary")
 var shot=state.flights[0] if not state.flights.is_empty() else state.ejections[0]
 check(shot.snapshot.damage==70.0 and shot.snapshot.weapon.para1==1 and shot.native_context.value.wild_missile and not shot.native_context.value.has("chain_allowance"),"wild frozen birth and no chain")
 var expected_rng=RandomNumberGenerator.new();expected_rng.state=418;expected_rng.randf()
 check(k.rng_source().state==expected_rng.state,"wild draws critical only")
 d.wild_multiplier=100.0;d.wild_blast=100.0;d.wild_damage_type=2;d.missile_attacks=0
 check(k.update_configuration(d) and k.export_handoff().missile_attacks==1,"config update never resets missile count")
 var transferred=k.export_handoff();shot=transferred.flights[0] if not transferred.flights.is_empty() else transferred.ejections[0]
 check(shot.snapshot.damage==70.0 and shot.native_context.value.blast_fraction==0.5,"in-flight wild retains birth damage/fraction")
 step(k,2)
 check(k.enemy_views()[0].hp==1e6-88 and k.enemy_views()[1].hp==1e6-18 and k.metrics().hits==3,"old wild uses current impact type with frozen damage/fraction and one blast")
 # Cached factors survive configuration changes and cold ownership transfer.
 d=world();d.ejection_gap=0.2;d.enemies[0].guidance_layers=2
 check(k.configure(d),"cached transfer admission");step(k,3)
 var cached=k.export_handoff();var bridge_game=fixture();var bridge_session=Session.new();bridge_session.weapons.assign(d.weapons)
 var bridge=Handoff.new();check(bridge.prepare(bridge_game,bridge_session,cached),"cached transfer prepare")
 check(bridge.missile_queue.size()==2 and is_same(bridge.missile_queue[0].attack.combat_context,bridge.missile_queue[1].attack.combat_context) and bridge.missile_queue[0].attack.combat_context.guidance_factors["100"]==4.0,"handoff retains pre-existing frozen factor and reference")
 d.guidance_multiplier=3.0;d.missile_attacks=0
 check(k.update_configuration(d),"new multiplier admitted with retained factor");step(k,45)
 check(k.enemy_views()[0].hp==1e6-120 and k.enemy_views()[0].guidance_layers==3 and k.metrics().missile_attacks==1,"old salvo multiplier and counter survive config update")
 # Numeric refusals leave queues, counters, HP and RNG unchanged.
 d=world();d.enemies[0].guidance_layers=2;d.weapons[0].damage=1e150;d.hit_radius=0.01
 check(k.configure(d),"retained arithmetic admission");step(k,1);state=k.export_handoff();var rng_before=k.rng_source().state
 d.weapons[0].damage=1.0;d.guidance_multiplier=1e100
 check(not k.can_update_configuration(d) and not k.update_configuration(d),"old raw times new exponent rejected")
 check(k.export_handoff()==state and k.rng_source().state==rng_before,"configuration refusal atomic")
 d=world();d.guidance_multiplier=1e200
 check(k.configure(d),"runtime exponent fixture admission");state=k.export_handoff();rng_before=k.rng_source().state
 check(not k.advance(0.1) and k.export_handoff()==state and k.rng_source().state==rng_before,"step exponent overflow refused before effects")
 var g=fixture();check(g.admit_native_compiled_execution("native_low_contract"),"Game native missile admission")
 g.tick(0.01);var owner=g.native_execution;state=owner.kernel.export_handoff()
 check(state.missile_attacks==1 and state.ejections.size()>0,"Game counter and pending tubes")
 var prepared=Handoff.new();check(prepared.prepare(g,owner,state),"handoff prepare")
 check(prepared.shots.size()>0 and is_same(prepared.patches[0].values.combat_context,prepared.missile_queue[0].attack.combat_context),"handoff restores active and queued shared reference")
 check(owner.handoff_to_legacy(g,"missile_test") and g.native_execution==null and g.drone_combat.missile_attacks==1,"one owner handoff preserves counter")
 check(is_same(g.projectiles[0].combat_context,g.missile_queue[0].attack.combat_context),"committed handoff retains identity")
 # Legacy derived salvo has distinct cache and shared primary chain allowance.
 g=fixture();var entry=g.combat_entry(0);var target=g.enemies[0]
 g.begin_enhancement_attack(0,target);var primary=g.jewel_attack(0)
 var context=g.enhancement_attack_contexts[0];context.derived=true
 var first=g.jewel_attack(0);var next=g.jewel_attack(0)
 check(is_same(first.combat_context,next.combat_context) and not is_same(primary.combat_context,first.combat_context),"Game derived salvo cache shared independently")
 check(first.attack_instance_id==primary.attack_instance_id and first.combat_context.chain_allowance,"Game secondary keeps primary chain instance")
 target.guidance_layers=2;var value=g.guided_missile_damage(target,10.0,first.combat_context);target.guidance_layers=3
 check(value==40.0 and g.guided_missile_damage(target,10.0,next.combat_context)==40.0 and target.guidance_layers==3,"Game derived freezes factor and adds no layer")
 g.finish_enhancement_attack(0)
 print("MISSILE_LEGENDS checks=",checks," failures=",failures)
 quit(1 if failures else 0)
