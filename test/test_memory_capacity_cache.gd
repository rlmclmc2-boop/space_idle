extends SceneTree
# Compare the candidate with the exact pre-change buffer/capacity paths.
class Legacy extends BattleGame:
	func sync_enhancement_buffers() -> void:
		for index in enhancement_buffers.keys():
			var entry := slot_entry("defence",int(index))
			var owner: Dictionary=enhancement_buffer_owners.get(index,{})
			var effect := memory_effect(entry)
			if entry.is_empty() or effect.is_empty() or not is_same(owner.get("entry",{}),entry) or owner.get("key","")!=str(entry.key):
				enhancement_buffers.erase(index)
				enhancement_buffer_owners.erase(index)
			else:
				enhancement_buffers[index]=N.minimum(enhancement_buffers[index],N.multiply(jewel_equipment_stat(entry),float(effect.p4)*int(effect.level)*enhancement_branches.memory_cap_multiplier(self,entry)))

	func enhancement_module_protection_capacity(index: int) -> Variant:
		var entry := slot_entry("defence",index)
		var effect := memory_effect(entry)
		return N.multiply(jewel_equipment_stat(entry),float(effect.p4)*int(effect.level)*enhancement_branches.memory_cap_multiplier(self,entry)) if not effect.is_empty() else 0.0

	func sync_jewel_defence_damage() -> Dictionary:
		# The aggregate player health stays authoritative. This transient allocation
		# records which module is damaged so its repair cannot heal another module.
		# External capacity/health changes reconcile only their delta, preserving
		# existing per-module losses; nothing is persisted as a second health balance.
		var capacities = {}
		for key in ["shield", "armour"]:
			var capacity: Dictionary = jewel_defence_capacity_cache.get(key, {}) if stat_cache_enabled else {}
			if capacity.is_empty():
				var indices: Array = []
				var maxima = {}
				var effects_by_index = {}
				var total = 0.0
				for index in defense_entries().size():
					var entry = slot_entry("defence", index)
					if entry.key != key:
						continue
					indices.append(index)
					var effects = jewel_effects(entry)
					var maximum = jewel_equipment_stat(entry, -1, effects)
					maxima[index] = maximum
					effects_by_index[index] = effects
					total = N.add(total,maximum)
				capacity = {"indices":indices,"maxima":maxima,"effects":effects_by_index,"total":total}
				if stat_cache_enabled:
					jewel_defence_capacity_cache[key] = capacity
			var indices: Array = capacity.indices
			var maxima: Dictionary = capacity.maxima
			var total = capacity.total
			var missing = 0.0
			for index in indices:
				jewel_defence_damage[index] = N.minimum(jewel_defence_damage.get(index,0),maxima[index])
				missing = N.add(missing,jewel_defence_damage[index])
			var expected = N.subtract(total,player[key])
			var increased = N.compare(expected,missing)>0
			var delta = N.subtract(N.maximum(expected,missing),N.minimum(expected,missing))
			for index in indices:
				var previous = jewel_defence_damage[index]
				var weight = N.ratio(N.subtract(maxima[index],previous),N.maximum(0.001,N.subtract(total,missing))) if increased else N.ratio(previous,N.maximum(0.001,missing))
				jewel_defence_damage[index]=N.minimum(maxima[index],N.add(previous,N.multiply(delta,weight)) if increased else N.subtract(previous,N.multiply(delta,weight)))
			capacities[key] = capacity
		return capacities


var failures=0
var checks=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func fixture(legacy:bool)->BattleGame:
	var db=ShipDatabase.new()
	for key in ["shield","armour"]:
		db.equipment[key][0].para1=100
		db.equipment[key][0]["para2" if key=="armour" else "para4"]=0
	db.equipment.shield[0].para2=0.04
	var g:BattleGame=Legacy.new(db,false) if legacy else BattleGame.new(db,false)
	g.profile.cleared=range(1,101);g.rebuild_unlocks()
	g.profile.selectedShip="Heavy_Battleship"
	g.profile.loadout={"weapons":[{"key":"laser","level":150}],"defence":[{"key":"shield","level":150},{"key":"armour","level":150},{"key":"shield","level":150},{"key":"armour","level":150}]}
	g.profile.enhancementLevel=30
	g.profile.resources={"1":1e80,"2":1e80}
	for effect in g.profile.enhancementBranches.defence:
		for node in [1,2,3]:g.profile.enhancementBranches.defence[effect][str(node)]="B"
	g.stat_cache_enabled=true;g.invalidate_stat_cache();g.reset_player()
	g.rng.seed=32501;g.spawn_group();g.state=BattleGame.State.COMBAT
	return g
func state(g)->Dictionary:
	return {"player":g.player.duplicate(true),"buffers":g.enhancement_buffers.duplicate(true),"owners":g.enhancement_buffer_owners.duplicate(true),"damage":g.jewel_defence_damage.duplicate(),"times":g.jewel_defence_times.duplicate(),"deferred":g.enhancement_deferred.duplicate(true),"deferred_tick":g.enhancement_deferred_tick,"deferred_elapsed":g.enhancement_deferred_elapsed,"memory_elapsed":g.enhancement_memory_elapsed,"defense_time":g.enhancement_defense_time,"branches":g.enhancement_branches.defenses.duplicate(true),"reduction":g.enhancement_branches.memory_reduction_remaining,"clear_reduction":g.enhancement_branches.clear_reduction_remaining,"rng":g.rng.state,"hits":g.profile.enhancementHits,"attacks":g.profile.enhancementAttacks,"resources":g.profile.resources.duplicate(true)}
func compare(a,b,label:String)->void:
	check(state(a)==state(b),label+" state/timers/RNG")
	var before=state(b)
	for index in range(-1,5):check(a.enhancement_module_protection_capacity(index)==b.enhancement_module_protection_capacity(index),label+" capacity "+str(index))
	check(a.enhancement_protection_status()==b.enhancement_protection_status(),label+" HUD projection")
	check(before==state(b),label+" read purity")
func _initialize()->void:
	var a=fixture(true);var b=fixture(false)
	compare(a,b,"initial")
	for step in 180:
		for g in [a,b]:
			if step in [6,37,88]:g.hit_player(100.0,step%3,{"source_uid":100})
			g.advance_jewel_repair(1.0/60.0)
		compare(a,b,"repair "+str(step))
	for g in [a,b]:g.record_enhancement_hit()
	compare(a,b,"counter invalidation")
	for g in [a,b]:g.set_enhancement_branch("defence","memory_material",3,"A")
	compare(a,b,"branch invalidation")
	for g in [a,b]:g.set_enhancement_order("defence",["memory_material","adaptation","delayed_damage"])
	compare(a,b,"order invalidation")
	for g in [a,b]:g.upgrade_slot("defence",0,1)
	compare(a,b,"module upgrade")
	for g in [a,b]:
		g.profile.loadout.defence[1].key="shield"
		g.invalidate_stat_cache();g.reset_player()
	compare(a,b,"armour count changed")
	for g in [a,b]:
		g.profile.planets["1"].conquered=true
		g.planet_buildings.sync(g,"1")
		for item in g.profile.planets["1"].buildings.values():item.status="built"
		g.profile.planets["1"].crewId="navigator"
		g.advance_planets(g.planet_duration("1"))
	compare(a,b,"planet payout")
	check(a.profile.crew==b.profile.crew,"all crew payout preserved")
	for g in [a,b]:
		g.assign_crew("engineer","equipment_upgrade","equipment")
		g.add_crew_exp("engineer",g.crew.required_exp(g,int(g.crew.entry(g,"engineer").level)))
	compare(a,b,"crew level effect")
	for g in [a,b]:
		g.db.data.enhance_config.memory_buffer_fraction.value=0.071
		g.db.data.enhance_config.memory_a_bonus.value=0.23
		g.invalidate_stat_cache()
	compare(a,b,"live config reload invalidation")
	for g in [a,b]:
		g.profile.loadout.defence[0].key=""
		g.invalidate_stat_cache();g.apply_refit_health()
	compare(a,b,"empty owner")
	for g in [a,b]:g.stat_cache_enabled=false
	compare(a,b,"direct path")
	# Exercise public invalidation paths after warming both capacity caches.
	a=fixture(true);b=fixture(false)
	# Memory's third branch includes its shared-order threshold. Keep this
	# fixture eligible so the later branch switch really changes and clamps caps.
	var memory_rank: int=a.profile.enhancementOrder.defence.find("memory_material")
	var public_level: int=int(a.db.data.enhance_config.branch_threshold_3.value)+int(a.db.data.enhance_config["threshold_%d" % (memory_rank+1)].value)
	for g in [a,b]:
		g.profile.enhancementLevel=public_level
		g.invalidate_stat_cache();g.reset_player()
	compare(a,b,"public paths warm")
	for g in [a,b]:
		g.profile.jewelFragments=1e40
		check(g.upgrade_enhancement(1)==1,"purchase one enhancement")
	compare(a,b,"purchased enhancement level")
	for g in [a,b]:check(g.equip_slot("defence",1,"shield"),"replace armour with shield")
	compare(a,b,"public armour and shield counts")
	for g in [a,b]:check(g.unequip_slot("defence",2),"remove shield owner")
	compare(a,b,"public unequip")
	for g in [a,b]:check(g.equip_slot("defence",2,"armour"),"replace removed owner")
	compare(a,b,"public equip new owner")
	for g in [a,b]:check(g.switch_ship(g.first_ship()),"switch to smaller hull")
	compare(a,b,"inactive slots excluded")
	for g in [a,b]:check(g.switch_ship("Heavy_Battleship"),"restore larger hull")
	compare(a,b,"active slots restored")
	for g in [a,b]:
		for index in g.defense_entries().size():
			g.enhancement_buffers[index]=g.N.multiply(g.enhancement_module_protection_capacity(index),2)
			g.enhancement_buffer_owners[index]={"entry":g.slot_entry("defence",index),"key":str(g.slot_entry("defence",index).key)}
		check(g.set_enhancement_branch("defence","memory_material",3,"A"),"lower capacity branch")
	compare(a,b,"live buffer clamped after capacity change")
	for g in [a,b]:
		for index in g.defense_entries().size():check(g.N.compare(g.enhancement_buffers.get(index,0),g.enhancement_module_protection_capacity(index))<=0,"buffer respects new cap")
	# Warmed live objects must discard their old capacities on load, not only at construction.
	a.save_enabled=true;a.save_progress();a.save_enabled=false
	for g in [a,b]:
		g.profile.enhancementLevel+=100
		g.invalidate_stat_cache();g.enhancement_protection_status()
		g.load_progress();g.reset_player()
	compare(a,b,"load into warmed objects")
	check(a.profile.enhancementLevel==public_level+1 and b.profile.enhancementLevel==public_level+1,"purchased level survives save/load")
	# Conquest grants an effective enhancement level through the permanent modifier source.
	a=fixture(true);b=fixture(false)
	compare(a,b,"gifted level warm")
	for g in [a,b]:
		g.planet_buildings.sync(g,"1")
		g.profile.planets["1"].buildings.shipyard.status="built"
		var before_bonus=g.enhancement_level_bonus()
		check(g.reforge_planet("1"),"conquer first planet")
		check(g.enhancement_level_bonus()>before_bonus,"conquest grants configured enhancement bonus")
	compare(a,b,"gifted enhancement level")
	print("MEMORY CAPACITY CACHE: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
