extends SceneTree
const Compiler=preload("res://scripts/native_execution_compiler.gd")
const Session=preload("res://scripts/native_execution_session.gd")
class EndlessGame extends "res://scripts/presented_battle_game.gd":
 var legacy_calls:=0
 func jewel_attack(index:int,multiplier:=1.0)->Dictionary:
  legacy_calls+=1;return super.jewel_attack(index,multiplier)
 func hit_enemy(enemy:Dictionary,raw,type:int,effects:Array=[],critical:bool=false,context:Dictionary={})->void:
  legacy_calls+=1;super.hit_enemy(enemy,raw,type,effects,critical,context)
 func tick_projectiles(dt:float)->void:
  legacy_calls+=1;super.tick_projectiles(dt)
 var endless:Variant={"parameters":{"maximum_multiplier_bonus":2.0},"constants":{}}
 func hyperspace_totals()->Dictionary:
  var result=super.hyperspace_totals().duplicate(true)
  if endless!=null:result.legendary.endless_beam=endless
  return result
class OldKernel extends RefCounted:
 var calls:=0
 func can_refit_configuration(_d):calls+=1;return true
 func refit_token():calls+=1;return {}
 func update_configuration(_d):calls+=1;return true
 func refit_configuration(_d):calls+=1;return true
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func near(a,b)->bool:return abs(float(a)-float(b))<0.00000001
func actor(uid:int=100,hp:float=1e6)->Dictionary:
 return {"uid":uid,"slot":4 if uid==100 else 0,"x":100.0+uid,"y":0.0,"hp":hp,"max_hp":hp,"armourType":2,"shieldType":0,"shield":0.0,"max_shield":0.0,"equipment":[],"cooldowns":[],"drops":[],"res_ratio":1.0,"shield_updated_at":0.0,"shield_hit_at":-1.0}
func weapon(slot:int=0)->Dictionary:
 return {"endless":slot==0,"kind":3,"type":1,"slot":slot,"source":-1,"hostile":false,"damage":10.0,"factor":1.0,"interval":0.002,"remaining":0.0,"speed":1.0,"charge":0.002,"ramp":1.0,"maximum":1.0,"salvo":1,"muzzle":Vector2.ZERO,"critical_rate":0.0,"critical_multiplier":1.0,"repeat_probability":0.0,"repeat_multiplier":1.0,"entry":{"key":"longLaser","level":1},"row":{"cd":0.002,"para1":1.0,"para2":1.0,"para3":0.002,"dmgtype":1}}
func world()->Dictionary:
 return {"clock":0.0,"rng_state":418,"resistance":0.5,"requires_endless_beam":true,"repeat_delay":0.01,"defences":[],"player":{"x":50.0,"y":0.0,"armour":100000.0,"shield":0.0},"enemies":[actor(),actor(101)],"weapons":[weapon()]}
func flight(k,slot:int=0)->Dictionary:
 for f in k.export_handoff().flights:
  if int(f.weapon_index)==slot and not f.repeated:return f
 return {}
func fixture():
 var g=EndlessGame.new(ShipDatabase.new(),false)
 g.save_enabled=false;g.profile.unlocked=BattleGame.EQUIPMENT.duplicate();g.profile.resources={"1":1e30,"2":1e30}
 for entry in g.profile.loadout.weapons:entry.key=""
 for i in 2:g.profile.loadout.weapons[i].key="longLaser";g.profile.loadout.weapons[i].level=1
 g.profile.loadout.defence=[{"key":"armour","level":1},{"key":"shield","level":1}]
 g.db.equipment.longLaser[0].cd=0.02;g.db.equipment.longLaser[0].para3=0.02
 g.invalidate_stat_cache();g.reset_player();g.state=BattleGame.State.COMBAT;g.enemies.assign([actor(),actor(101)])
 return g
func kernel_timing(other:bool)->void:
 var k=ClassDB.instantiate("SpaceCombatKernel");var d=world();d.enemies[0].hp=10.0
 if other:
  d.weapons[0].damage=1.0;d.weapons[0].charge=0.004;d.weapons[0].row.para3=0.004
  var killer=weapon(1);killer.charge=0.001;killer.row.para3=0.001;d.weapons.append(killer)
 check(k.configure(d) and k.advance(0.001),"timing startup "+str(other))
 var born=flight(k);var id=born.instance.id;k.take_feedback()
 check(k.advance(0.016),"multiple due step "+str(other))
 var f=flight(k);var age=0.001 if other else 0.002
 check(not f.is_empty() and f.await_target and not f.view.dead and near(f.age,age) and near(f.next_hit,0.004) and f.ticks==(0 if other else 1),"death freezes actual age, leaves unexecuted due "+str(other))
 k.take_feedback();check(k.advance(0.004),"retarget step "+str(other))
 f=flight(k)
 check(f.instance.id==id and not f.await_target and f.view.target.uid==101 and f.ticks==(1 if other else 3),"retarget preserves identity and only active-time periods "+str(other))
 var times=[]
 for e in k.take_feedback():
  if int(e.kind)==6 and int(e.shot.mount)==0:times.append(float(e.clock))
 var expected=[0.020,0.022] if other else [0.019,0.021]
 if other:expected=[0.020]
 check(times.size()==expected.size(),"no wait backlog "+str(other)+" "+str(times))
 if times.size()==expected.size():
  for i in times.size():check(near(times[i],expected[i]),"exact resumed damage time "+str(other))
 k.cancel()
func legacy_timing(other:bool)->void:
 var g=fixture();g.endless.parameters.maximum_multiplier_bonus=0.0
 g.enemies[0].hp=10.0
 var row={"dmgtype":1,"cd":0.002,"para1":1.0,"para2":1.0,"para3":0.004 if other else 0.002}
 g.lock_long_laser(g.player,row,false,0,g.combat_entry(0));var beam=g.projectiles.back()
 beam.attack_snapshot.damage=1.0 if other else 10.0;beam.attack_snapshot.effects=[];beam.attack_snapshot.critical=false;beam.attack_snapshot.weapon=row.duplicate();beam.weapon=row.duplicate();beam.next_hit_at=row.para3
 if other:
  var killer_row=row.duplicate();killer_row.para3=0.001
  g.lock_long_laser(g.player,killer_row,false,1,g.combat_entry(1));var killer=g.projectiles.back()
  killer.attack_snapshot.damage=10.0;killer.attack_snapshot.effects=[];killer.attack_snapshot.critical=false;killer.attack_snapshot.weapon=killer_row.duplicate();killer.weapon=killer_row.duplicate();killer.next_hit_at=0.001
 g.enemy_shield_time=0.016;g.tick_shield_beams(g.projectiles.duplicate(),0.016)
 check(beam.await_target and not beam.dead and near(beam.elapsed,0.001 if other else 0.002) and near(beam.next_hit_at,0.004),"legacy actual death clock and unconsumed due "+str(other))
 check(not g.long_laser_valid(beam),"waiting hidden "+str(other))
 var serial=g.main_attack_serial;g.lock_long_laser(g.player,row,false,0,g.combat_entry(0))
 check(g.main_attack_serial==serial,"waiting prevents duplicate startup")
 g.enemy_shield_time=0.020;g.tick_shield_beams(g.projectiles.duplicate(),0.004)
 check(not beam.await_target and beam.target.uid==101 and beam.ticks==(1 if other else 3) and near(beam.next_hit_at,0.006 if other else 0.008),"legacy resumes remaining phase without backlog "+str(other))
 g.begin_retreat();check(g.projectiles.filter(func(p):return p.get("beam",false)).is_empty(),"retreat clears beams")
func index_and_boundaries()->void:
 var k=ClassDB.instantiate("SpaceCombatKernel");var d=world();d.weapons=[];d.enemies=[]
 for i in 4:
  d.enemies.append(actor(100+i));var w=weapon(i);w.endless=false;w.hostile=true;w.source=i;d.weapons.append(w)
 check(k.configure(d) and k.advance(0.001),"four beam indices born")
 for uid in [101,103,102,100]:
  check(k.hit_handle(k.actor_handle(uid),1e8,1) and k.advance(0.001),"swap-pop retire and preflight "+str(uid))
 check(k.projectile_views().is_empty(),"all hostile beams retired")
 k.cancel();k.cancel();check(k.configure(world()) and k.advance(0.001) and k.advance(0.001),"repeat cancel, configure, reused indices")
 var before=k.export_handoff();check(k.commit_handoff(before.revision) and k.configure(world()) and k.advance(0.001),"handoff clears index before reuse")
 d=world();d.final_encounter=true;check(k.configure(d) and k.advance(0.001),"final wipe startup")
 for uid in [100,101]:check(k.hit_handle(k.actor_handle(uid),1e8,1),"final victim "+str(uid))
 check(k.projectile_views().is_empty() and k.advance(0.001),"final wipe empties indices")
 check(k.configure(world()) and k.advance(0.001),"numeric startup")
 before=k.export_handoff();check(not k.advance(1e8) and k.export_handoff()==before,"tick range rejects before mutation")
 d=world();d.weapons[0].charge=1e16
 check(k.configure(d) and k.advance(0.001),"far charge startup")
 before=k.export_handoff();check(not k.advance(0.001) and k.export_handoff()==before,"next_hit precision rejects before mutation")
 k.cancel()
func compiler_and_updates()->void:
 var g=fixture();var c=Compiler.new();var d=c.compile(g,"native_low_contract")
 check(not d.has("error") and d.weapons[0].endless and not d.weapons[1].endless,"first tied ordinary source")
 var projected=c.compile(g,"native_low_contract",{"weapon_levels":{1:2}})
 check(not projected.has("error") and not projected.weapons[0].endless and projected.weapons[1].endless,"projected winner changes")
 var rng=RandomNumberGenerator.new();rng.seed=13
 var drone=preload("res://scripts/drone_rewards.gd").create_drone(rng,g.hyperspace.config,"endless-test","gold","longLaser",20,"1")
 g.profile.hyperspace.inventory.drones["endless-test"]=drone;g.profile.hyperspace.inventory.equipped=["endless-test"];g.invalidate_stat_cache()
 d=c.compile(g,"native_low_contract")
 check(not d.has("error") and d.weapons.filter(func(w):return w.endless).size()==1 and not d.weapons.back().endless,"drone cannot become endless source")
 g.profile.hyperspace.inventory.equipped=[];g.invalidate_stat_cache();d=c.compile(g,"native_low_contract")
 var old=OldKernel.new();var session=Session.new();session.kernel=old;session.execution_scope="native_low_contract"
 var before=g.profile.duplicate(true)
 check(not session.supports_configuration(old,d),"old DLL admission capability")
 check(not session.upgrade_numeric_configuration(g,"weapons",0,1),"old DLL numeric update")
 check(session.prepare_galaxy_refit(g,{"equipment_value":1.0,"charge_max":1.0}).is_empty(),"old DLL refit prepare")
 check(not session.commit_galaxy_refit(g,{"descriptor":d,"ratios":{}}),"old DLL refit commit")
 check(session.prepare_numeric_batch(g,"1").is_empty(),"old DLL batch prepare")
 check(not session.commit_numeric_batch(g,{"descriptor":d}),"old DLL batch commit")
 check(old.calls==0 and g.profile==before,"six gates reject before mutable calls")
 check(g.admit_native_compiled_execution("native_low_contract"),"game native admission")
 var owner=g.native_execution;check(owner.kernel.advance(0.001),"game native beam startup")
 var f=flight(owner.kernel);var snapshot=f.snapshot.duplicate(true);var instance=f.instance.id
 check(owner.upgrade_numeric_configuration(g,"weapons",1,1),"numeric projected update commits")
 g.profile.loadout.weapons[1]=g.profile.loadout.weapons[1].duplicate();g.profile.loadout.weapons[1].level=2;g.native_numeric_update=true;g.invalidate_stat_cache();g.native_numeric_update=false
 var after=flight(owner.kernel)
 check(after.instance.id==instance and after.snapshot==snapshot and after.age==f.age and after.next_hit==f.next_hit and not after.endless and flight(owner.kernel,1).endless,"entry replacement preserves snapshot clock and unique qualification")
 check(owner.handoff_to_legacy(g,"test_endless"),"atomic handoff")
 var b=g.projectiles.filter(func(p):return p.mount==1)[0];var saved_age=b.elapsed;var saved_tick=b.ticks;var saved_next=b.next_hit_at
 g.change_state(BattleGame.State.TRAVEL);g.tick_shield_beams(g.projectiles.duplicate(),1.0)
 check(g.projectiles.size()==1 and is_same(g.projectiles[0],b) and b.elapsed==saved_age and b.ticks==saved_tick and b.next_hit_at==saved_next and b.await_target,"nonfinal travel freezes selected old beam")
 g.enemies.assign([actor(102)]);g.change_state(BattleGame.State.COMBAT);g.enemy_shield_time+=0.001;g.tick_shield_beams(g.projectiles.duplicate(),0.001)
 check(g.projectiles.size()==1 and b.target.uid==102 and not b.await_target and b.ticks==saved_tick,"next wave resumes same beam")
 var copied=g.combat_entry(1).duplicate();g.profile.loadout.weapons[1]=copied;g.invalidate_stat_cache()
 check(g.long_laser_valid(b),"legacy numeric dictionary replacement does not drop old beam")
 g.change_state(BattleGame.State.LEVEL_CLEAR);check(g.projectiles.is_empty(),"clear state removes persistent beam")
func prism_repeat()->void:
 var k=ClassDB.instantiate("SpaceCombatKernel");var d=world();d.prism_count=1;d.prism_bonus=2.0;d.weapons[0].repeat_probability=1.0;d.enemies[0].hp=10.0
 check(k.configure(d) and k.advance(0.001) and k.advance(0.003),"prism endless startup and kill")
 var f=flight(k);check(f.await_target and f.maximum==3.0,"prism maximum frozen on waiting beam")
 check(k.advance(0.003),"prism retarget")
 f=flight(k);check(not f.await_target and f.maximum==3.0 and f.instance.chain.count==1,"rebind does not add prism bonus again")
 check(k.advance(0.02),"repeat due")
 var copies=k.export_handoff().flights.filter(func(r):return r.repeated)
 check(not copies.is_empty() and copies.all(func(r):return not r.endless),"repeat beams never qualify")
 k.cancel()
func final_boundaries()->void:
 var g=fixture();g.profile.loadout.weapons[1].key="";g.invalidate_stat_cache()
 check(g.admit_native_compiled_execution("native_low_contract"),"automatic wave fixture admitted")
 var owner=g.native_execution;g.tick(0.001);var beam=g.projectiles[0]
 for i in 5:g.tick(0.01)
 check(g.native_execution==owner and g.legacy_calls==0,"native residence executes zero old combat callbacks")
 for uid in [100,101]:check(owner.kernel.hit_handle(owner.kernel.actor_handle(uid),1e12,1),"wave victim")
 g.tick(0.001)
 check(g.native_execution==null and g.state==BattleGame.State.TRAVEL and g.projectiles.has(beam) and beam.await_target and not beam.dead,"automatic nonfinal handoff retains waiting beam")
 var age=beam.elapsed;var due=beam.next_hit_at;var ticks=beam.ticks
 g.group_index=g.db.levels[g.stage-1].groups.size()
 for i in 3:g.tick(0.01)
 check(beam.elapsed==age and beam.next_hit_at==due and beam.ticks==ticks,"actual travel ticks freeze clock")
 g.enemies.assign([actor(102)]);g.change_state(BattleGame.State.COMBAT);g.tick(0.001)
 check(g.projectiles.has(beam) and beam.target.uid==102 and not beam.await_target,"post-wave actual tick reuses old beam")
 g.begin_retreat()
 var k=ClassDB.instantiate("SpaceCombatKernel");var d=world()
 check(k.configure(d) and k.advance(0.001),"rejection baseline")
 var before=k.export_handoff()
 for mode in ["multiple","drone","overflow"]:
  var invalid=d.duplicate(true)
  if mode=="multiple":var w=weapon(1);w.endless=true;invalid.weapons.append(w)
  elif mode=="drone":invalid.weapons[0].entry.drone_id="illegal"
  else:invalid.weapons[0].maximum=1e308
  check(not k.configure(invalid) and k.export_handoff()==before,"configuration rejection untouched "+mode)
 check(not k.advance(1e16) and k.export_handoff()==before,"age exact-range rejection untouched")
 k.cancel()
func _initialize()->void:call_deferred("run")
func run()->void:
 Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 for other in [false,true]:kernel_timing(other);legacy_timing(other)
 index_and_boundaries();compiler_and_updates();prism_repeat();final_boundaries()
 print("ENDLESS_BEAM checks=",checks," failures=",failures)
 quit(1 if failures else 0)
