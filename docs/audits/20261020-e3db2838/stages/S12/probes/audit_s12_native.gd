extends SceneTree

const I:=preload("res://scripts/reactor_integer.gd")
var checks:=0
var failures:=0

func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)

func fixture()->BattleGame:
	var g=preload("res://scripts/presented_battle_game.gd").new(ShipDatabase.new(),false)
	g.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
	g.profile.cleared=[1]
	g.profile.highestLevel=999
	g.profile.loadout.defence=[{"key":"armour","level":1},{"key":"shield","level":1}]
	g.stat_cache_enabled=true;g.invalidate_stat_cache();g.save_enabled=false;g.reset_player();g.state=BattleGame.State.COMBAT
	g.enemies.assign([{"uid":100,"slot":0,"x":286.0,"y":100.0,"hp":1e8,"max_hp":1e8,"armourType":2,"shieldType":0,"shield":0.0,"max_shield":0.0,"equipment":[],"cooldowns":[],"drops":[],"res_ratio":1.0}])
	var desc=preload("res://scripts/native_execution_compiler.gd").new().compile(g,"native_low_contract")
	check(not desc.has("error"),"finite native descriptor")
	check(not desc.has("error") and g.admit_native_execution(desc),"actual native admission")
	return g

func _initialize()->void:call_deferred("run")

func run()->void:
	check(ClassDB.class_exists("SpaceCombatKernel"),"matching native DLL loaded")
	var ordinary:=fixture()
	ordinary.profile.resources={"1":1e12,"2":1e12}
	var before:Dictionary=ordinary.profile.resources.duplicate(true)
	var price:=ordinary.slot_upgrade_cost("weapons",0)
	check(ordinary.upgrade_slot("weapons",0),"finite native purchase")
	check(ordinary.native_execution!=null,"finite purchase remains native")
	for id in price:check(ordinary.profile.resources[id]==before[id]-float(price[id]),"finite native debit "+id)
	var distant:=fixture()
	distant.profile.resources={"1":{"m":1.0,"e":1000000000.0},"2":{"m":1.0,"e":1000000000.0}}
	check(distant.upgrade_slot("weapons",0),"compact wallet finite stat native purchase")
	check(distant.native_execution!=null and distant.profile.resources["1"].get("v")==3,"sparse wallet leaves finite native owner intact")
	var high:=fixture()
	high.profile.loadout.weapons[0].level=3872
	high.profile.resources={"1":{"m":1.0,"e":400.0},"2":{"m":1.0,"e":400.0}}
	high.profile.hyperspace.materials[high.db.evolution_material_id()]=1000000
	var high_price:=high.slot_upgrade_cost("weapons",0)
	var high_before:Dictionary=high.profile.resources.duplicate(true)
	check(high.upgrade_slot("weapons",0),"high quote hands off then purchases")
	check(high.native_execution==null and high.native_handoff_count==1,"high stat leaves native before purchase")
	for id in high_price:check(I.compare(high.profile.resources[id],I.subtract(I.legacy_integer(high_before[id],16000000),high_price[id]))==0,"handoff exact debit "+id)
	var rejected:=fixture()
	rejected.profile.loadout.weapons[0].level=3872
	rejected.profile.resources={"1":0,"2":0}
	var old_level:=int(rejected.slot_entry("weapons",0).level)
	check(not rejected.upgrade_slot("weapons",0),"unaffordable native quote rejects")
	check(rejected.native_execution!=null and rejected.native_handoff_count==0 and int(rejected.slot_entry("weapons",0).level)==old_level,"reject precedes native handoff and state change")
	var batch:=fixture()
	batch.profile.resources={"1":1e14,"2":1e14}
	batch.profile.hyperspace.materials[batch.db.evolution_material_id()]=1000000
	check(batch.upgrade_equipment_batch("10"),"finite native batch commits")
	check(batch.native_execution!=null,"finite batch keeps native owner")
	var high_batch:=fixture()
	high_batch.profile.loadout.weapons[0].level=3872
	high_batch.profile.resources={"1":{"m":1.0,"e":400.0},"2":{"m":1.0,"e":400.0}}
	high_batch.profile.hyperspace.materials[high_batch.db.evolution_material_id()]=1000000
	check(high_batch.upgrade_equipment_batch("10"),"high batch purchases after handoff")
	check(high_batch.native_execution==null and high_batch.native_handoff_count==1,"high batch hands off before spending")
	var reject_batch:=fixture()
	reject_batch.profile.loadout.weapons[0].level=3872
	reject_batch.profile.resources={"1":0,"2":0}
	var before_batch:Dictionary=reject_batch.profile.duplicate(true)
	check(not reject_batch.upgrade_equipment_batch("10"),"unaffordable native batch rejects")
	check(reject_batch.native_execution!=null and reject_batch.native_handoff_count==0 and reject_batch.profile.resources==before_batch.resources and reject_batch.profile.loadout==before_batch.loadout,"batch reject has no wallet/level/handoff effect")
	var max_budget:=fixture()
	max_budget.db.data.equipment_evolution.interval=1000000000
	max_budget.profile.resources={"1":{"m":1.0,"e":1000000000.0},"2":{"m":1.0,"e":1000000000.0}}
	var before_max=max_budget.profile.duplicate(true)
	check(not max_budget.upgrade_equipment_batch("max"),"native MAX reports synchronous quote budget")
	check(max_budget.native_execution!=null and max_budget.native_handoff_count==0 and max_budget.profile==before_max,"native MAX budget rejects before handoff and wallet effects")
	var oversized:=fixture()
	oversized.profile.resources={"1":{"m":1.0,"e":1000000000.0},"2":{"m":1.0,"e":1000000000.0}}
	oversized.resource_samples.append({"time":oversized.economy_time(),"production_time":oversized.production_time(),"id":"1","amount":1,"origin":"x".repeat(16*1024*1024)})
	var oversized_before=oversized.profile.duplicate(true)
	var oversized_events:Array=[]
	oversized.event.connect(func(kind,payload):oversized_events.append(kind))
	var oversized_debits=oversized.equipment_debits(oversized.slot_upgrade_cost("weapons",0,10))
	check(not oversized_debits.is_empty() and not oversized.equipment_save_fits(oversized_debits,"weapons",0,10),"native size fixture exceeds actual whole-save limit")
	check(not oversized.upgrade_equipment_batch("10"),"native batch rejects oversized save before descriptor")
	check(oversized.native_execution!=null and oversized.native_handoff_count==0 and oversized.profile==oversized_before and oversized_events.is_empty(),"native oversized batch has no purchase, descriptor or event effect")
	print("S12_NATIVE checks=",checks," failures=",failures)
	quit(1 if failures else 0)
