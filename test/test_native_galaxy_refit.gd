extends "res://test_native_execution_handoff.gd"
class ChangedDuringShared extends "res://scripts/presented_battle_game.gd":
	var mutation_due:=false
	var mutation_ok:=false
	var mutation_state:Dictionary={}
	var later_shared:=0
	func advance_planets(dt:float)->void:
		super.advance_planets(dt)
		if mutation_due:
			mutation_due=false;mutation_ok=upgrade_slot("defence",1,1)
			mutation_state=native_execution.kernel.export_handoff().duplicate(true)
	func advance_auto_gen(dt:float)->void:
		later_shared+=1;super.advance_auto_gen(dt)
class RefusedLater extends "res://scripts/native_execution_session.gd":
	func handoff_to_legacy(_g:RefCounted,_reason:String)->bool:return false
func refit_fixture(key:String="missile",effect:String="equipment_value",shared_change:bool=false):
	var db=ShipDatabase.new();db.equipment.shield[0].para2=0.0
	var g=ChangedDuringShared.new(db,false) if shared_change else preload("res://scripts/presented_battle_game.gd").new(db,false)
	g.profile.unlocked=BattleGame.EQUIPMENT.duplicate();g.profile.resources={"1":1e30,"2":1e30}
	g.profile.loadout.weapons[0].key=key
	g.profile.loadout.defence=[{"key":"shield","level":10},{"key":"armour","level":10},{"key":"shield","level":10},{"key":"armour","level":10}]
	if true:
		g.profile.enhancementLevel=40;g.profile.cleared=range(1,61);g.profile.highestLevel=61
		g.rebuild_unlocks();g.set_enhancement_branch("weapons","repeat",1,"B")
		if key=="missile":g.set_enhancement_branch("weapons","repeat",3,"B")
	g.invalidate_stat_cache();g.reset_player();g.state=BattleGame.State.COMBAT
	g.enemies.assign([{"uid":100,"slot":4,"x":286.0,"y":150.0,"hp":1e8,"max_hp":1e8,"armourType":1,"shieldType":0,"shield":0.0,"max_shield":0.0,"equipment":[],"cooldowns":[],"drops":[],"res_ratio":1.0},{"uid":101,"slot":3,"x":240.0,"y":150.0,"hp":1e8,"max_hp":1e8,"armourType":1,"shieldType":0,"shield":0.0,"max_shield":0.0,"equipment":[],"cooldowns":[],"drops":[],"res_ratio":1.0}])
	g.cooldowns[g.slot_id("weapons",0)]=0.0
	g.profile.cleared=range(1,101);g.rebuild_unlocks();g.galaxy.refresh_unlocks(g)
	check(g.assign_crew("navigator","galaxy_explore","galaxy_1"),"galaxy assignment before admission")
	var region=g.galaxy.regions.galaxy_1
	var chosen=""
	for build in region.builds.values():
		if build.effect_type==effect:chosen=build.key;break
	check(not chosen.is_empty(),"real effect building exists")
	var slot:Dictionary=region.slots[0]
	slot.type=chosen;slot.planned_type=chosen;slot.status="constructing";slot.level=1;slot.work=region.work_cost();slot.construction=0.01
	region.state.explore_work=region.work_cost();region.refresh_counts();region.sync_map()
	g.galaxy.elapsed_crew.galaxy_1=1
	g.enemies[0].drops=[{"resourceId":1,"chance":1.0,"amount":100000.0}]
	g.profile.reactorLevel=20;g.profile.planets["1"].conquered=true;g.profile.selectedShip="Heavy_Battleship"
	g.invalidate_stat_cache();g.reset_player()
	g.player.armour*=0.6;g.player.shield*=0.6;g.sync_jewel_defence_damage()
	# Deliberately uneven damage: preserving prior loss would fail the refit
	# contract even though aggregate HP could still look correct.
	for layer in ["armour","shield"]:
		var remaining=g.stat(layer)-g.player[layer]
		for i in g.defense_entries().size():
			var entry:Dictionary=g.slot_entry("defence",i)
			if entry.key!=layer:continue
			var loss=minf(remaining,g.jewel_equipment_stat(entry))
			g.jewel_defence_damage[i]=loss;remaining-=loss
	for i in g.defense_entries().size():g.enhancement_buffers[i]=g.jewel_equipment_stat(g.slot_entry("defence",i))*0.1
	var desc=preload("res://scripts/native_execution_compiler.gd").new().compile(g,"native_low_contract")
	if desc.has("error"):printerr("ADMISSION: ",desc)

	check(g.admit_native_compiled_execution("native_low_contract"),"fixture native admission")
	g.tick(1.0/60.0)
	return g

func run()->void:
	for key in ["laser","cannon","missile","longLaser"]:
		var g=refit_fixture(key);var owner=g.native_execution;var k=owner.kernel
		var region=g.galaxy.regions.galaxy_1
		var before=k.export_handoff().duplicate(true);var rng=g.rng.state;var galaxy_rng=region.random.state
		var region_before=region.save_data().duplicate(true)
		var shots=g.projectiles.duplicate();var health=g.player.duplicate();var old_max={"armour":g.stat("armour"),"shield":g.stat("shield")}
		var notices=[];g.event.connect(func(kind,info):
			if kind in ["galaxy_changed","equipment_stats","reactor_changed"]:notices.append(kind))
		g.galaxy.elapsed.galaxy_1=10.0-1.0/60.0
		check(g.prepare_logical_step(1.0/60.0),key+" preflight")
		check(g.native_execution==owner and not g.galaxy.native_refit.is_empty(),key+" supported boundary retains native")
		if g.galaxy.native_refit.is_empty():quit(1);return
		check(k.export_handoff()==before and g.rng.state==rng and region.random.state==galaxy_rng and region.save_data()==region_before,key+" prediction and validation pure")
		check(g.galaxy.advance_region(g,"galaxy_1",10.0,false),key+" commit")
		check(g.native_execution==owner and g.native_handoff_count==0 and region.slots[0].status=="active",key+" actual completion remains native")
		var after=k.export_handoff().duplicate(true)
		for field in ["clock","revision","cooldowns","ejections","repeats","deferred","defence_time","defence_times","memory_elapsed","deferred_elapsed","attack_counter","incoming_counter","projectile_serial","attack_serial","instance_serial"]:
			check(after.get(field)==before.get(field),key+" preserves "+field)
		# Source is the live player row: its HP changes, carrier state must not.
		for i in before.flights.size():
			var lhs:Dictionary=before.flights[i].duplicate(true);var rhs:Dictionary=after.flights[i].duplicate(true)
			lhs.view.erase("source");rhs.view.erase("source")
			check(lhs==rhs,key+" carrier and birth snapshot unchanged")
		check(g.rng.state==rng and shots.size()==g.projectiles.size(),key+" preserves RNG and shots")
		for i in shots.size():check(is_same(shots[i],g.projectiles[i]),key+" same live shot")
		for layer in ["armour","shield"]:
			var ratio:float=health[layer]/old_max[layer] if old_max[layer]>0 else g.refit_health_ratios[layer]
			check(is_equal_approx(g.player[layer],g.stat(layer)*ratio),key+" health ratio "+layer)
			for i in g.defense_entries().size():
				var entry:Dictionary=g.slot_entry("defence",i)
				if entry.key==layer:check(is_equal_approx(g.jewel_defence_damage[i],g.jewel_equipment_stat(entry)*(1.0-ratio)),key+" redistributed module loss")
		check(notices==["equipment_stats","equipment_stats","reactor_changed","galaxy_changed"],key+" notifications exactly once")
		var invalid=preload("res://scripts/native_execution_compiler.gd").new().compile(g,owner.execution_scope)
		invalid.player.armour=0.0
		check(not k.can_refit_configuration(invalid) and not k.refit_configuration(invalid) and k.export_handoff()==after,key+" zero armour rejects without mutation")
		invalid.player.armour=g.player.armour;invalid.weapons[0].entry.level+=1
		check(not k.can_refit_configuration(invalid) and not k.refit_configuration(invalid) and k.export_handoff()==after,key+" shape change rejects without mutation")
		var low=owner.prepare_galaxy_refit(g,{"equipment_value":0.000001,"charge_max":g.galaxy.multiplier("charge_max")})
		check(not low.is_empty(),key+" smaller numeric refit accepted")
		var old_buffers=g.enhancement_buffers.duplicate();var clipped:=false
		check(owner.commit_galaxy_refit(g,low),key+" smaller refit commits")
		for i in low.descriptor.defences.size():
			var cap:float=low.descriptor.defences[i].maximum*low.descriptor.defences[i].memory_cap
			clipped=clipped or float(old_buffers[i])>cap
			check(is_equal_approx(g.enhancement_buffers[i],minf(float(old_buffers[i]),cap)),key+" memory buffer clamped")
		check(clipped,key+" fixture exercises buffer clamp")
		g.begin_retreat()
	var g=refit_fixture("missile","charge_max");var owner=g.native_execution;var region=g.galaxy.regions.galaxy_1
	var old_drop:Dictionary=owner.kernel.enemy_views()[0].compiled_drops[0].duplicate()
	check(g.galaxy.advance_region(g,"galaxy_1",10.0,false),"charge completion commit")
	check(g.native_execution==owner,"charge completion keeps native")
	var current=preload("res://scripts/native_execution_compiler.gd").new().compile(g,owner.execution_scope)
	check(owner.kernel.enemy_views()[0].compiled_drops==current.enemies[0].compiled_drops,"compiled drops match new live reactor configuration")
	check(current.enemies[0].compiled_drops[0].amount>old_drop.amount,"real charge completion increases smelting drop")
	owner.kernel.hit_handle(owner.kernel.actor_handle(100),1e30,1)
	var drops=owner.kernel.take_feedback().filter(func(row):return int(row.kind)==7 and int(row.shot.get("id",-1))==1)
	check(not drops.is_empty(),"death emits resource drop after refit")
	if not drops.is_empty():check(drops[0].shot.amount==current.enemies[0].compiled_drops[0].amount,"death uses updated resource amount")
	g.begin_retreat()
	# A numeric purchase between preflight and the region commit keeps shape,
	# but invalidates old health, factors and drops. It must never be overwritten.
	g=refit_fixture();owner=g.native_execution
	var plan=owner.prepare_galaxy_refit(g,{"equipment_value":1.1,"charge_max":1.0})
	check(not plan.is_empty(),"stale plan initially valid")
	check(g.upgrade_slot("defence",1,1),"real numeric purchase between prepare and commit")
	var updated=owner.kernel.export_handoff().duplicate(true)
	check(not owner.commit_galaxy_refit(g,plan) and owner.kernel.export_handoff()==updated,"old plan rejected without overwriting accepted numeric update")
	g.begin_retreat()
	g=refit_fixture("missile","equipment_value",true);owner=g.native_execution
	g.galaxy.elapsed.galaxy_1=10.0-1.0/60.0
	check(g.prepare_logical_step(1.0/60.0),"stale plan fallback preflight")
	g.mutation_due=true;g.tick(1.0/60.0)
	check(g.mutation_ok and g.native_execution==null and g.native_handoff_count==1,"stale plan safely transfers updated state once")
	check(g.galaxy.regions.galaxy_1.slots[0].status=="active" and not g.paused,"legacy finishes actual refit after stale-plan transfer")
	g.begin_retreat()
	g=refit_fixture("missile","equipment_value",true);owner=g.native_execution
	var refused=RefusedLater.new()
	for field in ["kernel","actor_rows","actor_by_uid","execution_scope","weapons","production_seconds","ticks"]:refused.set(field,owner.get(field))
	g.native_execution=refused;owner=refused
	g.galaxy.elapsed.galaxy_1=10.0-1.0/60.0
	var before_region=g.galaxy.regions.galaxy_1.save_data().duplicate(true)
	check(g.prepare_logical_step(1.0/60.0) and not g.galaxy.native_refit.is_empty(),"late failure starts with a valid plan")
	g.mutation_due=true;g.later_shared=0
	g.tick(1.0/60.0)
	check(g.mutation_ok and owner.advance_blocked and g.paused and g.native_step_phase=="blocked","stale commit plus refused transfer explicitly blocks")
	check(owner.kernel.export_handoff()==g.mutation_state and g.later_shared==0,"late failure executes neither remaining economy nor combat")
	check(g.galaxy.regions.galaxy_1.save_data()==before_region and is_equal_approx(g.galaxy.elapsed.galaxy_1,10.0),"late failure preserves all unconsumed region work")
	var clock=g.production_time();g.paused=false
	check(not g.prepare_logical_step(1.0/60.0) and g.production_time()==clock and owner.kernel.export_handoff()==g.mutation_state,"blocked late failure cannot replay shared work on resume")
	g.begin_retreat()
	print("GALAXY_REFIT_CHECKS ",checks," failures ",failures)
	FileAccess.open("res://.runtime/galaxy-refit-checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures}))
	quit(1 if failures else 0)
