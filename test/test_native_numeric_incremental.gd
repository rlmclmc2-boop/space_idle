extends "res://.runtime/test_native_numeric_upgrade.gd"
const Compiler=preload("res://scripts/native_execution_compiler.gd")
func compare_compile(g,compiler,label:String)->void:
	var levels:Dictionary={}
	for i in g.loadout_entries("weapons").size():levels[i]=int(g.slot_entry("weapons",i).level)+1
	var changes={"weapon_levels":levels,"defence_levels":{0:int(g.slot_entry("defence",0).level)+1}}
	var full=Compiler.new().compile(g,"native_low_contract",changes)
	var incremental=compiler.compile(g,"native_low_contract",changes)
	check(incremental==full,label+": exact full descriptor equality")
	check(g.native_execution.kernel.can_update_configuration(incremental)==g.native_execution.kernel.can_update_configuration(full),label+": same full validation")
func run()->void:
	var g=fixture("missile",true)
	g.native_before_configuration_change();g.projectile_clear();g.missile_queue.clear();g.jewel_repeats.clear()
	g.enemies[0].equipment=[{"name":"laser_mon"}];g.enemies[0].cooldowns=[10.0];g.enemies[0].dmgMultiple=1.0
	g.enemies[0].drops=[{"resourceId":1,"chance":1.0,"amount":2.0}];g.enemies[0].res_ratio=1.0
	var drone={"id":"incremental","weapon":"missile","ultimate":false,"blue_source_bonus":false,"legendary":false,"origin_quality":"blue","level":1,"affixes":[],"hangings":[]}
	g.profile.hyperspace.inventory.drones[drone.id]=drone;g.profile.hyperspace.inventory.equipped=[drone.id]
	g.invalidate_stat_cache();check(g.admit_native_compiled_execution("native_low_contract"),"armed drop/drone fixture")
	var compiler=Compiler.new();compiler.reuse_static=true
	compare_compile(g,compiler,"cold");var builds=compiler.static_builds
	g.tick(0.01);compare_compile(g,compiler,"live state and warm cache")
	check(compiler.static_builds==builds,"unchanged static paths actually exit")
	g.enemies[0].drops[0].amount=3.0;compare_compile(g,compiler,"drop input mutation")
	check(compiler.static_builds>builds,"drop dependency miss rebuilds");builds=compiler.static_builds
	g.enemies[0].dmgMultiple=2.0;compare_compile(g,compiler,"hostile damage dependency mutation")
	check(compiler.static_builds>builds,"hostile dependency miss rebuilds")
	g.enemies[0].shield=1.0;g.enemies[0].shield_updated_at=0.005;g.enemies[0].cooldowns[0]=0.33
	g.profile.enhancementHits+=3;g.profile.enhancementAttacks+=2
	compare_compile(g,compiler,"dynamic health/cooldown/counters")
	g.profile.reactorLevel+=1;g.invalidate_stat_cache();compare_compile(g,compiler,"reactor dependency change")
	g.begin_retreat()
	for enabled in [false,true]:
		g=fixture("missile",true);var owner=g.native_execution;owner.incremental_numeric_batches=enabled
		var events:Array=[]
		var watch=func(kind:String,info:Dictionary):
			if kind in ["upgrade","upgrades_completed","resources_changed"]:events.append([kind,info.duplicate(true)])
		g.event.connect(watch)
		var before=owner.kernel.export_handoff();var rng_before=g.rng.state;var wallet=g.profile.resources.duplicate(true)
		var planned=owner.prepare_numeric_batch(g,"1")
		check(not planned.is_empty(),"batch prevalidated")
		check(g.upgrade_equipment_batch("1"),"batch committed")
		var after=owner.kernel.export_handoff()
		check(before.cooldowns==after.cooldowns and rng_before==g.rng.state and before.flights==after.flights and before.ejections==after.ejections,"old attacks/CD/RNG untouched")
		var expected=wallet.duplicate(true);var upgrades=0
		for e in events:
			if e[0]=="upgrade":
				upgrades+=1
				for id in e[1].cost:expected[id]=g.N.subtract(expected[id],e[1].cost[id])
		check(expected==g.profile.resources and upgrades==planned.planned.size() and events[-1][0]=="upgrades_completed","ordered charges/events preserved")
		g.event.disconnect(watch);g.begin_retreat()
	g=fixture("missile",true);var owner=g.native_execution
	var changed=[false]
	var callback=func(kind:String,_info:Dictionary):
		if kind=="upgrade" and not changed[0]:changed[0]=true;g.notify_configuration_changed()
	g.event.connect(callback)
	check(g.upgrade_equipment_batch("1") and changed[0] and g.native_execution==null,"synchronous configuration callback safely hands off")
	g.event.disconnect(callback)
	g.begin_retreat()
	g=fixture("missile",true);owner=g.native_execution
	var plan=owner.prepare_numeric_batch(g,"1");var before=owner.kernel.export_handoff()
	owner.paused_by_configuration=true
	check(not owner.commit_numeric_batch(g,plan) and owner.kernel.export_handoff()==before,"invalidated owner cannot commit cached plan")
	g.begin_retreat()
	print("NATIVE INCREMENTAL: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
