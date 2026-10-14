extends "res://.runtime/test_native_numeric_upgrade.gd"
const Compiler=preload("res://scripts/native_execution_compiler.gd")
class ObservedCompiler extends "res://scripts/native_execution_compiler.gd":
	var full_calls:=0
	var numeric_calls:=0
	func compile(g,scope:String,upgrade:Dictionary={},galaxy_values:Dictionary={})->Dictionary:
		full_calls+=1
		return super.compile(g,scope,upgrade,galaxy_values)
	func compile_numeric_update(g,template:Dictionary,weapon_levels:Dictionary,defence_levels:Dictionary,affected:Array)->Dictionary:
		numeric_calls+=1
		return super.compile_numeric_update(g,template,weapon_levels,defence_levels,affected)
func compare_plan(g,label:String)->void:
	var owner=g.native_execution
	owner.incremental_numeric_batches=true
	var plan=owner.prepare_numeric_batch(g,"1")
	owner.incremental_numeric_batches=false
	var full=owner.prepare_numeric_batch(g,"1")
	owner.incremental_numeric_batches=true
	check(not plan.is_empty() and not full.is_empty(),label+": plans available")
	# Muzzles are live geometry, not numerical configuration; neither apply path writes them.
	var a:Dictionary=plan.descriptor.duplicate(true);var b:Dictionary=full.descriptor.duplicate(true)
	for rows in [a.weapons,b.weapons]:
		for row in rows:row.erase("muzzle")
	check(a==b,label+": numeric and full descriptors match authoritative context")
	check(owner.kernel.can_update_configuration(a)==owner.kernel.can_update_configuration(b),label+": full validator agrees")
func run()->void:
	var g=fixture("missile",true)
	g.native_before_configuration_change();g.projectile_clear();g.missile_queue.clear();g.jewel_repeats.clear()
	g.enemies[0].equipment=[{"name":"laser_mon"}];g.enemies[0].cooldowns=[10.0];g.enemies[0].dmgMultiple=1.0
	g.enemies[0].drops=[{"resourceId":1,"chance":1.0,"amount":2.0}];g.enemies[0].res_ratio=1.0
	var drone={"id":"numeric","weapon":"missile","ultimate":false,"blue_source_bonus":false,"legendary":false,"origin_quality":"blue","level":1,"affixes":[],"hangings":[]}
	g.profile.hyperspace.inventory.drones[drone.id]=drone;g.profile.hyperspace.inventory.equipped=[drone.id]
	g.invalidate_stat_cache();g.enable_compiled_combat_rules();check(g.admit_native_compiled_execution("native_low_contract"),"armed drop/drone fixture")
	var owner=g.native_execution;var compiler=ObservedCompiler.new();owner.numeric_compiler=compiler
	compare_plan(g,"initial");g.tick(0.01);compare_plan(g,"live dynamic state")
	var before_calls=compiler.full_calls;var builds=g.compiled_combat_rules.builds;var recipes=g.compiled_combat_rules.recipes
	var old_template=owner.numeric_template;var frozen=old_template.duplicate(true);var epoch=g.combat_configuration_epoch
	var events:Array=[]
	var watch=func(kind:String,info:Dictionary):
		if kind in ["upgrade","upgrades_completed","resources_changed"]:events.append([kind,info.duplicate(true)])
	g.event.connect(watch)
	var wallet=g.profile.resources.duplicate(true);var before=owner.kernel.export_handoff();var rng_before=g.rng.state
	check(g.upgrade_equipment_batch("1"),"numeric batch committed")
	check(compiler.full_calls==before_calls and compiler.numeric_calls>0,"cold compile actually exits")
	check(old_template==frozen and owner.numeric_template!=old_template and owner.numeric_template.is_read_only(),"old immutable skeleton unchanged; successful commit publishes replacement")
	check(g.combat_configuration_epoch==epoch and g.compiled_combat_rules.builds==builds and is_same(recipes,g.compiled_combat_rules.recipes),"pure levels preserve configuration epoch and recipes")
	var after=owner.kernel.export_handoff()
	check(before.cooldowns==after.cooldowns and rng_before==g.rng.state and before.flights==after.flights and before.ejections==after.ejections,"old attacks/CD/RNG untouched")
	var expected=wallet.duplicate(true);var upgrades=0
	for e in events:
		if e[0]=="upgrade":
			upgrades+=1
			for id in e[1].cost:expected[id]=g.N.subtract(expected[id],e[1].cost[id])
	check(expected==g.profile.resources and upgrades==g.loadout_entries("weapons").size()+g.loadout_entries("defence").size() and events[-1][0]=="upgrades_completed","ordered charges/events preserved")
	compare_plan(g,"after repeated level change")
	g.event.disconnect(watch)
	g.profile.reactorLevel+=1;g.invalidate_stat_cache();before_calls=compiler.full_calls
	var changed=owner.prepare_numeric_batch(g,"1")
	check(g.combat_configuration_epoch!=epoch and compiler.full_calls==before_calls+1,"nonlevel invalidation selects complete compiler")
	check(not owner.commit_numeric_batch(g,changed),"uncommitted invalidation cannot publish old template")
	g.begin_retreat()
	g=fixture("missile",true);owner=g.native_execution
	var callback_seen=[false];epoch=g.combat_configuration_epoch
	var callback=func(kind:String,_info:Dictionary):
		if kind=="resources_changed" and not callback_seen[0]:
			callback_seen[0]=true;g.invalidate_stat_cache()
	g.event.connect(callback)
	check(g.upgrade_equipment_batch("1") and callback_seen[0] and g.combat_configuration_epoch>epoch and g.native_execution==null,"ordinary callback invalidation is not hidden inside numeric mutation")
	g.event.disconnect(callback);g.begin_retreat()
	var k=ClassDB.instantiate("SpaceCombatKernel")
	var d={"rng_state":417,"player":{"armour":100.0,"shield":10.0,"x":50.0,"y":0.0},"enemies":[{"uid":100,"slot":0,"x":100.0,"y":0.0,"hp":100.0,"max_hp":100.0,"compiled_drops":[]}],"weapons":[],"defences":[{"layer":1,"type":0,"base":100.0,"factor":1.0,"maximum":100.0}],"deferred":{10:{"shield":1.0,"armour":2.0}}}
	check(k.configure(d),"authoritative debt fixture")
	check(k.advance(0.01),"advance current debt fixture")
	var state=k.export_handoff();var context=k.numeric_update_context()
	check(not context.deferred.is_empty() and context.deferred==state.deferred and context.defence_time==state.defence_time,"context reads current native debt and clocks")
	check(k.export_handoff()==state,"context read does not advance or mutate authority")
	print("NATIVE NUMERIC UPDATE: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
