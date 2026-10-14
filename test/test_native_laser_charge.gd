extends SceneTree
const Compiler=preload("res://scripts/native_execution_compiler.gd")
const Session=preload("res://scripts/native_execution_session.gd")
class ChargeGame extends "res://scripts/presented_battle_game.gd":
 var charge:Variant={"parameters":{"maximum_bonus":2.0},"constants":{"bonus_per_laser":0.25}}
 func hyperspace_totals()->Dictionary:
  var totals=super.hyperspace_totals().duplicate(true)
  if charge!=null:totals.legendary.laser_charge=charge
  return totals
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
func world()->Dictionary:
 return {"clock":0.0,"rng_state":418,"resistance":0.5,"scatter":true,"scatter_bonus":0.7,"requires_laser_charge":true,"laser_charge_multiplier":1.8,"repeat_delay":0.1,"defences":[],"player":{"x":50.0,"y":0.0,"armour":100.0,"shield":100.0},"enemies":[{"uid":100,"slot":4,"x":10000.0,"y":0.0,"hp":1e9,"max_hp":1e9}],"weapons":[{"kind":0,"type":1,"slot":0,"source":-1,"hostile":false,"damage":10.7,"factor":1.3,"interval":0.5,"remaining":0.0,"speed":10.0,"charge":-1.0,"ramp":1.0,"maximum":1.0,"salvo":1,"muzzle":Vector2.ZERO,"critical_rate":1.0,"critical_multiplier":2.3,"repeat_probability":1.0,"repeat_multiplier":1.2,"entry":{"key":"laser"},"row":{"cd":0.5,"para1":10.0}}]}
func game_fixture():
 var g=ChargeGame.new(ShipDatabase.new(),false)
 g.profile.unlocked=BattleGame.EQUIPMENT.duplicate();g.profile.resources={"1":1e30,"2":1e30}
 g.profile.loadout.weapons[0].key="laser"
 g.profile.loadout.defence=[{"key":"armour","level":1},{"key":"shield","level":1}]
 g.invalidate_stat_cache();g.reset_player();g.state=BattleGame.State.COMBAT
 g.enemies.assign([{"uid":100,"slot":4,"x":286.0,"y":150.0,"hp":1e8,"max_hp":1e8,"armourType":1,"shieldType":0,"shield":0.0,"max_shield":0.0,"equipment":[],"cooldowns":[],"drops":[],"res_ratio":1.0}])
 return g
func _initialize()->void:call_deferred("run")
func run()->void:
 Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 print("CONFIG cap=",Engine.max_fps," vsync=",DisplayServer.window_get_vsync_mode()," headless=",DisplayServer.get_name())
 var k=ClassDB.instantiate("SpaceCombatKernel");var d=world()
 check(k.configure(d),"charge descriptor admitted")
 check(k.advance(1.0/60.0),"charge first step")
 var before=k.export_handoff();var expected=ceil(10.7)*1.3*((1.0+0.7)*1.8)*2.3
 check(before.flights.size()==1 and before.repeats.size()==1,"in-flight plus queued repeat fixture")
 if before.flights.is_empty():quit(1);return
 check(before.flights[0].snapshot.damage==expected,"rounding/scatter/charge/critical grouping exact")
 var snapshot=before.flights[0].snapshot.duplicate(true)
 d.erase("laser_charge_multiplier");d.requires_laser_charge=false
 check(k.update_configuration(d),"remove charge configuration")
 var after=k.export_handoff()
 check(after.flights[0].snapshot==snapshot and after.repeats==before.repeats,"removal preserves flight and queued repeat snapshots")
 for i in 35:check(k.advance(1.0/60.0),"advance at fixed60Hz")
 after=k.export_handoff();var old_count=0;var new_count=0
 for flight in after.flights:
  if flight.snapshot.id==snapshot.id:
   check(flight.snapshot.damage==expected,"old root/repeat damage frozen");old_count+=1
  else:
   check(flight.snapshot.damage==ceil(10.7)*1.3*(1.0+0.7)*2.3,"new roots return to charge1");new_count+=1
 check(old_count>=2 and new_count>0,"both old repeat and new root observed")
 k.cancel();d=world();d.enemies.append({"uid":101,"slot":3,"x":20000.0,"y":0.0,"hp":1e9,"max_hp":1e9})
 check(k.configure(d) and k.advance(1.0/60.0),"multi-target scatter admitted")
 for flight in k.export_handoff().flights:check(flight.snapshot.damage==ceil(10.7)*1.3*1.8*2.3,"multi-target omits single-target bonus")
 for value in [-1.0,0.0,"2",true,INF,NAN]:
  var invalid=world();invalid.laser_charge_multiplier=value
  var previous=k.export_handoff()
  check(not k.configure(invalid) and k.export_handoff()==previous,"invalid multiplier rejects without mutation "+str(value))
 var invalid=world();invalid.erase("laser_charge_multiplier")
 check(not k.configure(invalid),"required multiplier missing rejected")
 invalid=world();invalid.laser_charge_multiplier=1e308;invalid.scatter_bonus=1e308
 check(not k.configure(invalid),"legendary intermediate overflow rejected")
 invalid=world();invalid.laser_charge_multiplier=1e308;invalid.scatter=false
 check(not k.configure(invalid),"damage overflow rejected")
 k.cancel()
 d=world();d.scatter=false;d.weapons[0].damage=1e300;d.weapons[0].factor=1.0;d.weapons[0].critical_multiplier=1.0;d.weapons[0].repeat_multiplier=1.0;d.laser_charge_multiplier=1e6;d.counter_growth=1000.0;d.counter_level=1.0
 check(k.configure(d),"finite current damage admits before future growth boundary")
 before=k.export_handoff()
 check(not k.advance(1.0/60.0) and k.export_handoff()==before,"runtime charge bound rejects untouched step")
 k.cancel()
 var g=game_fixture();var compiler=Compiler.new();var count=g.combat_weapon_entries().filter(func(e):return e.key=="laser").size()
 var compiled=compiler.compile(g,"native_low_contract")
 check(not compiled.has("error") and compiled.laser_charge_multiplier==1.0+minf(2.0,0.25*count),"compiler counts effective main slots")
 var rng=RandomNumberGenerator.new();rng.seed=13
 var drone=preload("res://scripts/drone_rewards.gd").create_drone(rng,g.hyperspace.config,"charge-test","gold","laser",20,"1")
 g.profile.hyperspace.inventory.drones["charge-test"]=drone;g.profile.hyperspace.inventory.equipped=["charge-test"]
 g.invalidate_stat_cache()
 check(compiler.compile(g,"native_low_contract").laser_charge_multiplier==1.0+minf(2.0,0.25*(count+1)),"equipped drone source added")
 g.charge.constants.bonus_per_laser=1e308
 check(compiler.compile(g,"native_low_contract").has("error"),"uncapped source product overflow rejected even with finite cap")
 g.charge.constants.bonus_per_laser=0.25
 g.drone_combat.disabled=["charge-test"];g.invalidate_stat_cache()
 check(compiler.compile(g,"native_low_contract").has("error"),"disabled pending state retains existing admission refusal")
 g.drone_combat.disabled=[]
 g.profile.hyperspace.inventory.sealed=["charge-test"];g.invalidate_stat_cache()
 check(compiler.compile(g,"native_low_contract").laser_charge_multiplier==1.0+minf(2.0,0.25*count),"sealed drone excluded")
 g.profile.hyperspace.inventory.sealed=[];g.profile.loadout.weapons[0].key="cannon";g.invalidate_stat_cache()
 check(compiler.compile(g,"native_low_contract").laser_charge_multiplier==1.0+minf(2.0,0.25*count),"main slot change updates count")
 g.profile.hyperspace.inventory.equipped=[];g.invalidate_stat_cache()
 check(compiler.compile(g,"native_low_contract").laser_charge_multiplier==1.0+minf(2.0,0.25*(count-1)),"drone removal updates count")
 g.profile.loadout.weapons[0].key="laser";g.invalidate_stat_cache()
 var original=g.charge.duplicate(true)
 g.charge.parameters.maximum_bonus=0.1
 check(compiler.compile(g,"native_low_contract").laser_charge_multiplier==1.1,"compiler cap")
 for value in [-1.0,"1",true,INF,NAN]:
  g.charge=original.duplicate(true);g.charge.parameters.maximum_bonus=value
  check(compiler.compile(g,"native_low_contract").has("error"),"invalid maximum rejects "+str(value))
  g.charge=original.duplicate(true);g.charge.constants.bonus_per_laser=value
  check(compiler.compile(g,"native_low_contract").has("error"),"invalid per-source rejects "+str(value))
 for value in [1,{}, {"parameters":[],"constants":{}}, {"parameters":{},"constants":{}}]:
  g.charge=value;check(compiler.compile(g,"native_low_contract").has("error"),"invalid charge shape")
 g.charge=original
 var session=Session.new();var old=OldKernel.new();session.kernel=old;session.execution_scope="native_low_contract"
 check(not session.supports_configuration(old,compiled),"old DLL capability refused")
 check(not session.upgrade_numeric_configuration(g,"weapons",0,1) and old.calls==0,"old DLL upgrade refuses before call")
 check(session.prepare_galaxy_refit(g,{"equipment_value":1.0,"charge_max":1.0}).is_empty() and old.calls==0,"old DLL refit preparation refuses before call")
 check(not session.commit_galaxy_refit(g,{"descriptor":compiled,"ratios":{}}) and old.calls==0,"old DLL refit commit refuses before call")
 check(session.prepare_numeric_batch(g,"1").is_empty() and old.calls==0,"old DLL batch preparation refuses before call")
 check(not session.commit_numeric_batch(g,{"descriptor":compiled}) and old.calls==0,"old DLL batch commit refuses before call")
 g.charge=null;compiled=compiler.compile(g,"native_low_contract")
 check(compiled.laser_charge_multiplier==1.0 and session.supports_configuration(old,compiled),"removed charge permits old DLL")
 print("LASER_CHARGE checks=",checks," failures=",failures)
 quit(1 if failures else 0)
