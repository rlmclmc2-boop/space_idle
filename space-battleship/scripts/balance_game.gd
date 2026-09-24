extends BattleGame
## No save/load, scene tree, particles, audio or wall-clock economics in the lab.
var metrics = null
var simulated_time := 0.0
var source_weapon := "unknown"
# Lab-only pending hits. Heap key is projectile tick, then original fire serial.
# Only known stationary-target, single-hit projectiles are eligible. The original
# fire caller retains its shot until tick_projectiles, so jewel metadata is intact.
var simulation_mode := "exact"
var pending_hits: Array[Dictionary] = []
var fresh_shots: Array[Dictionary] = []
var projectile_tick := 0
var fast_scheduled := 0
var fast_resolved := 0
var fast_peak := 0
var fast_fallback := 0

# Only the synchronous repair call reads these derived values. That call changes
# health and damage allocation, never equipment, sockets, hit counters or bonuses.
# No value survives the call, so upgrades/charges/research/refits need no invalidation.
var repair_cache_active := false
var repair_entries: Array = []
var repair_effects := {}
var repair_stats := {}
# Effects do not depend on attack/hit counters. Keep originals only within one
# core tick; each caller receives its own copy because jewel_attack adds source.
var tick_effects_active := false
var tick_effect_entries: Array = []
var tick_effect_values: Array = []
# Active assignments and research rates cannot change during this synchronous
# Lab call: its only signal consumer is observe/metrics. Levels/point balances
# still change through the original implementation, including furnace boundaries.
var research_scope := false
var research_rates := {}
var research_active: Array = []

func fire(source: Dictionary, target: Dictionary, weapon: Dictionary, raw: float, hostile: bool, key: String, offset := Vector2.ZERO, visual_spread := 0.0) -> void:
	super.fire(source,target,weapon,raw,hostile,key,offset,visual_spread)
	if simulation_mode == "fast":fresh_shots.append(projectiles.back())

func pending_before(a: Dictionary, b: Dictionary) -> bool:
	return a.due < b.due or (a.due == b.due and a.shot.serial < b.shot.serial)

func push_hit(item: Dictionary) -> void:
	pending_hits.append(item)
	var index := pending_hits.size()-1
	while index > 0:
		var parent := (index-1)/2
		if not pending_before(item,pending_hits[parent]):break
		pending_hits[index] = pending_hits[parent]
		index = parent
	pending_hits[index] = item

func pop_hit() -> Dictionary:
	var result: Dictionary = pending_hits[0]
	var tail: Dictionary = pending_hits.pop_back()
	if pending_hits.is_empty():return result
	var index := 0
	while index*2+1 < pending_hits.size():
		var child := index*2+1
		if child+1 < pending_hits.size() and pending_before(pending_hits[child+1],pending_hits[child]):child += 1
		if not pending_before(pending_hits[child],tail):break
		pending_hits[index] = pending_hits[child]
		index = child
	pending_hits[index] = tail
	return result

func clear_pending_hits() -> void:
	pending_hits.clear()
	fresh_shots.clear()

func start(level: int, loop_mode: bool, checkpoint: Dictionary = {}) -> bool:
	var result := super.start(level,loop_mode,checkpoint)
	if result:clear_pending_hits()
	return result

func leave(next: State) -> void:
	clear_pending_hits()
	super.leave(next)

func tick_projectiles(dt: float) -> void:
	if simulation_mode != "fast":
		super.tick_projectiles(dt)
		return
	projectile_tick += 1
	for shot in fresh_shots:
		var key: String = str(shot.key).replace("_mon", "").replace("-mon", "")
		var eligible: bool = key in ["laser","cannon"] and not shot.get("beam",false) and float(shot.speed)>0 and is_finite(float(shot.speed)) and not shot.target.is_empty() and is_equal_approx(dt,1.0/60.0)
		if not eligible:
			fast_fallback += 1
			continue
		var origin := Vector2(shot.x,shot.y)
		var destination := Vector2(shot.target.x,shot.target.y)
		# Off-screen paths retain the original bounds/lifecycle checks.
		if not Rect2(-32,-32,1504,874).has_point(origin) or not Rect2(-32,-32,1504,874).has_point(destination):
			fast_fallback += 1
			continue
		var travel := origin.distance_to(destination)/float(shot.speed)
		if not is_finite(travel) or travel/dt > 2147483647:
			fast_fallback += 1
			continue
		projectiles.erase(shot)
		push_hit({"due":projectile_tick+maxi(1,int(ceil(travel/dt)))-1,"shot":shot,"destination":destination})
		fast_scheduled += 1
	fresh_shots.clear()
	fast_peak = maxi(fast_peak,pending_hits.size())
	var added := false
	while not pending_hits.is_empty() and int(pending_hits[0].due) <= projectile_tick:
		var item := pop_hit()
		var shot: Dictionary = item.shot
		# Dead/removed targets cannot reacquire for these ordinary projectiles.
		# Their remaining visual flight has no gameplay consumer in the Lab.
		if shot.target.is_empty():continue
		if shot.hostile:
			if shot.target.armour <= 0:continue
		elif shot.target.hp <= 0 or not enemies.has(shot.target):continue
		shot.x = item.destination.x
		shot.y = item.destination.y
		projectiles.append(shot)
		fast_resolved += 1
		added = true
	if added:projectiles.sort_custom(func(a,b):return a.serial < b.serial)
	# Reuse impact events, hit functions, death clearing, AOE and gem triggers.
	super.tick_projectiles(dt)

func research_rate(key: String) -> float:
	if not research_scope:return super.research_rate(key)
	if not research_rates.has(key):research_rates[key] = super.research_rate(key)
	return float(research_rates[key])

func active_research() -> Array:
	return research_active if research_scope else super.active_research()

func advance_hightech(dt: float, real_dt := -1.0, end_time := -1.0) -> void:
	research_active = super.active_research()
	research_scope = true
	super.advance_hightech(dt,real_dt,end_time)
	research_scope = false
	research_rates.clear()
	research_active.clear()

func advance_jewel_repair(dt: float) -> void:
	repair_cache_active = true
	super.advance_jewel_repair(dt)
	repair_cache_active = false
	repair_entries.clear()
	repair_effects.clear()
	repair_stats.clear()

func repair_entry_index(entry: Dictionary) -> int:
	for index in repair_entries.size():
		if is_same(repair_entries[index],entry):return index
	repair_entries.append(entry)
	return repair_entries.size()-1

func jewel_effects(entry: Dictionary) -> Array:
	# Empty sockets have no effects, regardless of capacity or equipment level.
	if entry.get("sockets",[]).is_empty():return []
	if not repair_cache_active:return tick_jewel_effects(entry)
	var index := repair_entry_index(entry)
	if not repair_effects.has(index):repair_effects[index] = tick_jewel_effects(entry)
	return repair_effects[index]

func tick_jewel_effects(entry: Dictionary) -> Array:
	if not tick_effects_active:return super.jewel_effects(entry)
	for index in tick_effect_entries.size():
		if is_same(tick_effect_entries[index],entry):return tick_effect_values[index].duplicate(true)
	var value := super.jewel_effects(entry)
	tick_effect_entries.append(entry)
	tick_effect_values.append(value)
	return value.duplicate(true)

func clear_tick_effects() -> void:
	tick_effect_entries.clear()
	tick_effect_values.clear()

func jewel_equipment_stat(entry: Dictionary, level := -1) -> float:
	if not repair_cache_active or level >= 0:return super.jewel_equipment_stat(entry,level)
	var index := repair_entry_index(entry)
	if not repair_stats.has(index):repair_stats[index] = super.jewel_equipment_stat(entry,level)
	return float(repair_stats[index])

func _init(database: ShipDatabase) -> void:
	super(database,false)
	profile.hightechSavedAt = 0.0
	event.connect(observe)

func economy_time() -> float:
	return simulated_time

func save_progress() -> void:
	pass

func tick(dt: float) -> void:
	if paused:return
	simulated_time += dt
	if metrics != null:
		metrics.time = simulated_time
		if state == State.COMBAT:metrics.combat_seconds += dt
	tick_effects_active = true
	super.tick(dt)
	tick_effects_active = false
	clear_tick_effects()
	if hightech_save_elapsed == 0:prune_resource_samples(simulated_time)

func observe(kind: String, payload: Dictionary) -> void:
	if kind in ["module_changed","ship_changed","jewels_changed","upgrade"]:clear_tick_effects()
	if kind in ["projectile_impact","beam_hit"]:
		var shot: Dictionary = payload.shot
		if not shot.hostile:source_weapon = str(shot.entry.key) if shot.get("beam",false) else str(shot.key)
	if metrics != null:
		metrics.current_stage = stage
		metrics.on_event(kind,payload)
		if kind == "state" and state == State.LEVEL_CLEAR:metrics.timeline.discover(self,simulated_time)

func spawn_group(keep_distance := false) -> void:
	super.spawn_group(keep_distance)
	if metrics == null:return
	metrics.born.clear()
	metrics.encounter_start = simulated_time
	for enemy in enemies:
		metrics.born[enemy.uid] = simulated_time
		metrics.spawn_count += 1
		metrics.spawn_hp += float(enemy.max_hp)
	if is_boss_encounter():metrics.timeline.record("BOSS",simulated_time,stage,{"wave":group_index})

func hit_enemy(enemy: Dictionary, raw: float, type: int, effects: Array = [], critical: bool = false) -> void:
	var before := float(enemy.hp)
	var weapon := source_weapon
	var boss := is_boss_encounter()
	super.hit_enemy(enemy,raw,type,effects,critical)
	if simulation_mode == "fast" and before > 0 and enemy.hp <= 0 and boss and targets().is_empty():clear_pending_hits()
	if metrics == null or before <= 0:return
	metrics.add(metrics.damage,weapon,before-float(enemy.hp))
	if enemy.hp <= 0 and metrics.born.has(enemy.uid):
		metrics.ttk_sum += simulated_time-float(metrics.born[enemy.uid])
		metrics.kills += 1
		if not boss:
			metrics.normal_ttk_sum += simulated_time-float(metrics.born[enemy.uid])
			metrics.normal_kills += 1
		metrics.born.erase(enemy.uid)
		if boss and metrics.born.is_empty():
			metrics.boss_kills += 1
			metrics.boss_ttk_sum += simulated_time-metrics.encounter_start

func hit_player(raw: float, type: int) -> void:
	var armour := float(player.armour)
	var shield := float(player.shield)
	super.hit_player(raw,type)
	if metrics == null:return
	metrics.health_lost += maxf(0,armour-float(player.armour))
	metrics.shield_absorbed += maxf(0,shield-float(player.shield))
	metrics.received += maxf(0,armour+shield-float(player.armour)-float(player.shield))
	metrics.min_health = minf(metrics.min_health,float(player.armour))
	metrics.min_shield = minf(metrics.min_shield,float(player.shield))

func begin_retreat() -> void:
	# All ordinary targets are lost on death; none may hit a reset player later.
	if simulation_mode == "fast":clear_pending_hits()
	if metrics != null and state != State.RETREAT:
		metrics.deaths += 1
		metrics.timeline.record("DEATH",simulated_time,stage,{"wave":group_index})
		if metrics.first_death == null:metrics.first_death = {"time":simulated_time,"stage":stage,"wave":group_index}
		metrics.born.clear()
	super.begin_retreat()

func advance_charge(dt: float) -> void:
	var before: Dictionary = profile.resources.duplicate()
	var cycles := {}
	for key in profile.charge:
		var job := charge_job(key)
		if job.active:cycles[key] = {"count":float(job.count),"level":int(job.level)}
	super.advance_charge(dt)
	if metrics == null:return
	var costs := {}
	for id in before:
		var paid := float(before[id])-float(profile.resources[id])
		if paid > 0:costs[id] = paid
	if not costs.is_empty():metrics.spend("charge",costs)
	for key in cycles:
		var job := charge_job(key)
		var previous: Dictionary = cycles[key]
		var completed := float(job.count)-float(previous.count)
		# Normal 1/60 steps cross at most a few levels. Reuse the actual requirement API.
		var final_level := int(job.level)
		for level in range(int(previous.level),final_level):
			completed += charge_required(key,level)
		if completed > 0:metrics.use("charge_cycles",int(completed))
		if final_level > int(previous.level):metrics.use("charge_levels",final_level-int(previous.level))

func generate_scientist(amount := 1) -> bool:
	var before: Dictionary = profile.resources.duplicate()
	var result := super.generate_scientist(amount)
	if result and metrics != null:
		for id in before:before[id] = float(before[id])-float(profile.resources[id])
		metrics.spend("scientists",before)
		metrics.use("scientists",amount)
	return result

func toggle_charge(key: String) -> bool:
	var result := super.toggle_charge(key)
	if result and metrics != null and charge_job(key).active:metrics.use("charge")
	return result

func generate_jewels_into(inventory: Array, fragments: float, serial: int, random: RandomNumberGenerator) -> Dictionary:
	var result := super.generate_jewels_into(inventory,fragments,serial,random)
	if metrics != null and int(result.serial) > serial:
		metrics.use("jewel_acquired",int(result.serial)-serial)
		metrics.spend("jewels",{"jewel_fragments":fragments-float(result.fragments)})
	return result

func settle_jewel_fragments(amount: float, source: String, ratio := -1.0) -> float:
	var result := super.settle_jewel_fragments(amount,source,ratio)
	if metrics != null:metrics.add(metrics.income,"jewel_fragments",result)
	return result

func combine_all_jewels() -> Dictionary:
	var result := super.combine_all_jewels()
	if metrics != null and result.get("ok",false) and result.get("count",0) > 0:metrics.use("jewel_combine",int(result.count))
	return result

func socket_jewel(category: String, index: int, socket: int, token: int, notify := true) -> bool:
	var result := super.socket_jewel(category,index,socket,token,notify)
	if result and metrics != null:metrics.use("jewel_equip")
	return result
