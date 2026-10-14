extends SceneTree
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
func _initialize()->void:call_deferred("run")
func run()->void:
 Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var k=ClassDB.instantiate("SpaceCombatKernel");var d=world()
 d.enemies[0].guidance_layers=2;d.weapons[0].interval=0.5
 if not k.configure(d):printerr("counter fixture admission failed");quit(1);return
 step(k,80);var observed=k.missile_legend_metrics()
 check(observed.cache_firsts==2 and observed.cache_hits==4 and observed.effective_layer_growth==2 and observed.missile_hits==6,"on-demand native guidance counters")
 check(observed.targets[0].first_factor==4.0 and observed.targets[0].last_factor==8.0 and observed.targets[0].min_factor==4.0 and observed.targets[0].max_factor==8.0,"on-demand per-target first factor extrema")
 for scenario in [0,1,2]:
  d=world();d.precise_guidance=false;d.wild_missile=true;d.wild_period=0;d.final_encounter=true
  d.enemies[0].hp=12.0 if scenario==0 else 8.0 if scenario==1 else 100.0
  if scenario==2:d.enemies.append(actor(101,4.0))
  if not k.configure(d):printerr("wild counter fixture admission failed");quit(1);return
  step(k,3);observed=k.missile_legend_metrics()
  check(observed.wild_substitutions==1 and observed.wild_blasts==1 and observed.recursion_blocked_entries==(0 if scenario==1 else 1 if scenario==0 else 2),"actual native wild counters "+str(scenario))
 print("MISSILE_COUNTERS checks=",checks," failures=",failures)
 quit(1 if failures else 0)
