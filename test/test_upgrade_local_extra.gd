extends "res://qa_upgrade_local.gd"
const Bag=preload("res://scripts/drone_inventory.gd")
const Rewards=preload("res://scripts/drone_rewards.gd")
class RefuseHandoff extends "res://scripts/presented_battle_game.gd":
 var refused:=0
 func native_before_configuration_change()->bool:
  refused+=1
  return false
func equip_endless(g)->bool:
 var rng=RandomNumberGenerator.new();rng.seed=419
 var d:Dictionary={}
 for attempt in 4096:
  d=Rewards.create_drone(rng,g.hyperspace.config,"qa:endless","legendary","longLaser",20,"1")
  if d.legendary_effect.effect_id=="endless_beam":break
 if d.legendary_effect.effect_id!="endless_beam" or not Bag.valid_drone(d,g.hyperspace.config):return false
 var bag=Bag.fresh();bag.drones[d.id]=d;bag.warehouse.append(d.id)
 g.profile.hyperspace.inventory=bag;g.profile.hyperspace.unlocked_drones=true
 g.invalidate_stat_cache()
 return g.hyperspace.set_equipped(g,[d.id])
func descriptor(g,projected:Dictionary={})->Dictionary:
 var a=OldCompiler.new().compile(g,"native_low_contract",projected)
 var b=Compiler.new().compile(g,"native_low_contract",projected)
 check(a==b and not b.has("error"),"rich old/new descriptor exact "+str(projected))
 return b
func rich_checks()->void:
 for compiled in [false,true]:
  var a=fixture(OldGame,compiled);var b=fixture(NewGame,compiled)
  check(equip_endless(a) and equip_endless(b),"valid equipped endless drone")
  var before=descriptor(b);check(descriptor(a)==before,"old/new rich baseline")
  var drone=before.weapons.filter(func(w):return w.entry.has("drone_id"))[0]
  check(before.weapons.filter(func(w):return w.endless).map(func(w):return w.slot)==[3],"initial highest endless slot3")
  var projected=descriptor(b,{"weapon_levels":{4:6}})
  check(projected.weapons.filter(func(w):return w.endless).map(func(w):return w.slot)==[4],"projected endless switches slot4")
  var projected_drone=projected.weapons.filter(func(w):return w.entry.has("drone_id"))[0]
  check(projected_drone.entry.level==drone.entry.level+1,"drone derives new same-weapon maximum")
  check(a.admit_native_compiled_execution("native_low_contract") and b.admit_native_compiled_execution("native_low_contract"),"rich native admission")
  check(a.upgrade_slot("weapons",4,3) and b.upgrade_slot("weapons",4,3),"purchase lower slot above highest")
  var after=descriptor(b)
  check(descriptor(a)==after,"rich purchased old/new descriptors")
  check(after.weapons.filter(func(w):return w.endless).map(func(w):return w.slot)==[4],"purchased endless switches slot4")
  check(after.weapons.filter(func(w):return w.entry.has("drone_id"))[0].entry.level==projected_drone.entry.level,"purchased drone level matches projection")
  check(a.profile.resources==b.profile.resources and a.profile.loadout==b.profile.loadout,"rich purchase wallet/levels exact")
  check(clean_kernel(a)==clean_kernel(b),"rich purchased kernel exact")
func invalid_checks()->void:
 for kind in ["growth","range"]:
  var g=fixture(RefuseHandoff,true)
  check(g.admit_native_compiled_execution("native_low_contract"),"invalid fixture initially admitted")
  g.tick(1.0/60)
  check(not g.projectiles.is_empty(),"invalid fixture has already emitted shots")
  if kind=="growth":g.db.config.dmgReduce={"m":1.0,"e":400.0}
  else:g.drone_combat.missile_attacks=-1
  var error=Compiler.new().compile(g,"native_low_contract").get("error","")
  check(not str(error).is_empty(),"invalid descriptor rejected "+kind+" "+str(error))
  var wallet=g.profile.resources.duplicate(true);var levels=g.profile.loadout.duplicate(true)
  var kernel=clean_kernel(g);var shots=scalar_copy(g.projectiles.duplicate(true))
  check(not g.upgrade_equipment_batch("1") and g.refused==1,"invalid batch refuses before debit when handoff unavailable "+kind)
  check(g.profile.resources==wallet and g.profile.loadout==levels,"invalid refusal wallet/levels unchanged "+kind)
  check(clean_kernel(g)==kernel and scalar_copy(g.projectiles)==shots,"invalid refusal emitted shots/kernel unchanged "+kind)
func run()->void:
 rich_checks();invalid_checks()
 var result={"checks":checks,"failures":failures,"scope":"only additional drone/endless/invalid-upgrade-entry checks; no previous99 rerun","handoff":"refusal branch uses explicit unavailable-handoff fixture"}
 FileAccess.open("res://.runtime/upgrade-extra-check.json",FileAccess.WRITE).store_string(JSON.stringify(result))
 print("UPGRADE_EXTRA_CHECK ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
