extends SceneTree
const Compiler=preload("res://scripts/native_execution_compiler.gd")
const Session=preload("res://scripts/native_execution_session.gd")
class ChargeGame extends "res://scripts/presented_battle_game.gd":
 var repeat_chance:=0.0
 var chain_count:=0
 var charge:Variant={"parameters":{"maximum_bonus":2.0},"constants":{"bonus_per_laser":0.25}}
 func hyperspace_totals()->Dictionary:
  var totals=super.hyperspace_totals().duplicate(true)
  totals.repeat_chance=repeat_chance;totals.chain_count=chain_count
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
 var db=ShipDatabase.new();db.ships.Frigate.defenseSlots=2
 var g=ChargeGame.new(db,false);g.stat_cache_enabled=true
 g.profile.unlocked=BattleGame.EQUIPMENT.duplicate();g.economy.credit_many({"1":1e30,"2":1e30})
 var equipment:Dictionary=g.equipment.save_data();equipment.loadout.weapons[0].key="laser"
 equipment.loadout.defence=[{"key":"armour","level":1},{"key":"shield","level":1}]
 check(g.equipment.install_snapshot(equipment,g.db),"current charge equipment installs")
 g.configuration_committed();g.enable_compiled_combat_rules();g.reset_player();g.state=BattleGame.State.COMBAT
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
 var hs:Dictionary=g.hyperspace.save_data();hs.hyperspace.inventory.drones["charge-test"]=drone;hs.hyperspace.inventory.equipped=["charge-test"];hs.hyperspace.inventory.warehouse=["charge-test"]
 check(g.hyperspace.install_snapshot(hs,g.db),"current equipped drone snapshot installs");g.configuration_committed()
 check(compiler.compile(g,"native_low_contract").laser_charge_multiplier==1.0+minf(2.0,0.25*(count+1)),"equipped drone source added")
 check(g.drone_combat.weapon_multiplier(g,"laser")==compiler.compile(g,"native_low_contract").laser_charge_multiplier,"script attack and native compile consume the same laser-charge contribution")
 g.charge.constants.bonus_per_laser=1e308
 check(compiler.compile(g,"native_low_contract").has("error"),"uncapped source product overflow rejected even with finite cap")
 g.charge.constants.bonus_per_laser=0.25
 g.drone_combat.disabled=["charge-test"];g.drone_combat.contribution_revision+=1
 check(compiler.compile(g,"native_low_contract").has("error"),"disabled pending state retains existing admission refusal")
 g.drone_combat.disabled=[];g.drone_combat.contribution_revision+=1
 hs=g.hyperspace.save_data();hs.hyperspace.inventory.sealed={"charge-test":1};hs.hyperspace.inventory.equipped=[]
 check(g.hyperspace.install_snapshot(hs,g.db),"current sealed drone snapshot installs");g.configuration_committed()
 check(compiler.compile(g,"native_low_contract").laser_charge_multiplier==1.0+minf(2.0,0.25*count),"sealed drone excluded")
 hs=g.hyperspace.save_data();hs.hyperspace.inventory.sealed={};hs.hyperspace.inventory.equipped=["charge-test"]
 check(g.hyperspace.install_snapshot(hs,g.db),"current unsealed drone snapshot installs")
 var equipment:Dictionary=g.equipment.save_data();equipment.loadout.weapons[0].key="cannon"
 check(g.equipment.install_snapshot(equipment,g.db),"current main slot fixture changes");g.configuration_committed()
 check(compiler.compile(g,"native_low_contract").laser_charge_multiplier==1.0+minf(2.0,0.25*count),"main slot change updates count")
 hs=g.hyperspace.save_data();hs.hyperspace.inventory.equipped=[]
 check(g.hyperspace.install_snapshot(hs,g.db),"current unequipped snapshot installs");g.configuration_committed()
 check(compiler.compile(g,"native_low_contract").laser_charge_multiplier==1.0+minf(2.0,0.25*(count-1)),"drone removal updates count")
 equipment=g.equipment.save_data();equipment.loadout.weapons[0].key="laser"
 check(g.equipment.install_snapshot(equipment,g.db),"current main slot fixture restores");g.configuration_committed()
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
 check(session.prepare_galaxy_refit(g,{"equipment_value":1.0,"charge_max":1.0}).is_empty() and old.calls==0,"old DLL refit preparation refuses before call")
 check(not session.commit_galaxy_refit(g,{"descriptor":compiled,"ratios":{}}) and old.calls==0,"old DLL refit commit refuses before call")
 check(session.prepare_numeric_batch(g,{"purchases":[]},g.player).is_empty() and old.calls==0,"old DLL batch preparation refuses before call")
 check(not session.commit_numeric_batch(g,{"descriptor":compiled}) and old.calls==0,"old DLL batch commit refuses before call")
 g.charge=null;compiled=compiler.compile(g,"native_low_contract")
 check(compiled.laser_charge_multiplier==1.0 and session.supports_configuration(old,compiled),"removed charge permits old DLL")
 check_shared_birth()
 print("LASER_CHARGE checks=",checks," failures=",failures)
 quit(1 if failures else 0)

func check_shared_birth()->void:
 var g=game_fixture();g.charge=null;g.repeat_chance=1.0;g.chain_count=2
 var compiler=Compiler.new();var compiled:Dictionary=compiler.compile(g,"native_low_contract")
 check(not compiled.has("error"),"drone-only repeat and chain configuration compiles")
 if compiled.has("error"):return
 var birth:Dictionary=compiled.weapons[0]
 check(birth.transfer_effects.any(func(e):return e.kind=="repeat" and e.level==0) and birth.transfer_effects.any(func(e):return e.kind=="hyperspace_chain" and e.chain_targets==2),"native transfer retains the same synthetic repeat and independent chain as script birth")
 var rng_before=g.rng.state;var clock=g.production_time();compiler.compile(g,"native_low_contract")
 check(g.rng.state==rng_before and g.production_time()==clock,"configuration query does not consume randomness or battle time")
 var attack:Dictionary=g.jewel_attack(0)
 check(attack.effects.size()==birth.transfer_effects.size(),"actual script attack consumes all common birth effects")
 for i in birth.transfer_effects.size():
  for key in birth.transfer_effects[i]:check(attack.effects[i][key]==birth.transfer_effects[i][key],"actual script birth field matches native transfer "+str(key))
 g.cooldowns[g.slot_id("weapons",0)]=0.0
 check(g.admit_native_compiled_execution("native_low_contract"),"shared birth admits resident kernel")
 if g.native_execution==null:return
 g.tick(g.LOGICAL_STEP)
 var owner=g.native_execution;var snapshot:Dictionary=owner.kernel.export_handoff()
 check(snapshot.flights.size()>0 and snapshot.repeats.size()>0,"actual native root and repeat exist")
 check(owner.handoff_to_legacy(g,"shared_birth_fixture"),"actual handoff preserves the committed common birth")
 check(not g.jewel_repeats.is_empty() and g.jewel_repeats[0].snapshot.effects.any(func(e):return e.kind=="repeat" and e.level==0) and g.jewel_repeats[0].snapshot.effects.any(func(e):return e.kind=="hyperspace_chain" and e.chain_targets==2),"handoff repeat retains both synthetic repeat and shared chain effects")
 g=game_fixture();g.charge=null;g.profile.cleared=range(1,61);g.rebuild_unlocks()
 var growth:Dictionary=g.enhancement_growth.save_data();growth.enhancementBranches.weapons.proficiency={"1":"A"}
 growth.enhancementBranches.defence.adaptation={"1":"B"}
 check(g.enhancement_growth.install_snapshot(growth),"dormant saved branch choices install")
 g.configuration_committed()
 check(not compiler.compile(g,"native_low_contract").has("error"),"locked inactive branch choices do not falsely block native")
 growth.enhancementLevel=50;check(g.enhancement_growth.install_snapshot(growth),"active branch fixture installs");g.configuration_committed()
 check(compiler.compile(g,"native_low_contract").get("error")=="unsupported_branch","unsupported active branches still reject")
 growth.enhancementBranches.weapons.proficiency={};check(g.enhancement_growth.install_snapshot(growth),"defense-only branch fixture installs");g.configuration_committed()
 check(compiler.compile(g,"native_low_contract").get("error")=="unsupported_branch","unsupported active defense branch still rejects")
 growth.enhancementBranches.defence.adaptation={};growth.enhancementBranches.weapons.repeat={"1":"B","3":"B"}
 check(g.enhancement_growth.install_snapshot(growth),"supported active branch fixture installs");g.chain_count=3;g.configuration_committed()
 compiled=compiler.compile(g,"native_low_contract")
 check(not compiled.has("error"),"supported active branches remain eligible")
 if compiled.has("error"):return
 birth=compiled.weapons[0];attack=g.jewel_attack(0)
 check(birth.chain_count==3+int(g.enhancement_parameter("repeat_b1_targets")) and birth.secondary_probability==g.enhancement_parameter("repeat_b3_probability"),"branch and drone contributions compose once")
 for effect in attack.effects:
  if effect.kind=="repeat":check(effect.chain_targets==birth.chain_count and g.enhancement_branches.repeat_multiplier(effect)==birth.repeat_multiplier,"actual script repeat matches composed native configuration")
