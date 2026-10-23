extends BattleGame
## No save/load, scene tree, particles, audio or wall-clock economics in the lab.
# Observe the existing commit result; UI resource notifications are throttled.
# The proposal's validated wallet is the committed target, so later UI callbacks
# cannot contaminate this cost with an unrelated wallet mutation.
class ResearchMetrics extends "res://scripts/progress_runtime.gd":
	func commit_research_advance_result(g,proposal:Dictionary)->Dictionary:
		var costs:Dictionary={}
		if g.metrics!=null:
			for id in proposal.get("paid",[]):costs[id]=N.subtract(g.economy.balance(id),proposal.resources[id])
		var result:Dictionary=super.commit_research_advance_result(g,proposal)
		if result.status=="committed" and g.metrics!=null:g.metrics.spend("research",costs)
		return result

const Execution = preload("res://scripts/execution_contract.gd")
var execution_error := ""
var execution_admission: Dictionary = {}
var execution_inputs: Array = []
var metrics = null
var simulated_time := 0.0
var source_weapon := "unknown"
# Lab-only pending hits. Heap key is projectile tick, then original fire serial.
# Only known stationary-target, single-hit projectiles are eligible. The original
# fire caller retains its shot until tick_projectiles, so jewel metadata is intact.
var simulation_mode := "exact"
var player_power_multiplier := 1.0
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
func admit_execution(force := false) -> bool:
	if not execution_error.is_empty():return false
	var inputs: Array = [simulation_mode,attributes.configuration_inputs(self),enhancement_growth.attacks(),enhancement_growth.hits()]
	if force or inputs!=execution_inputs:
		execution_admission=Execution.lab(self,simulation_mode)
		execution_inputs=inputs.duplicate(true)
		if not execution_admission.ok:execution_error=execution_admission.error
	return execution_error.is_empty()

func _tick_combat_step(dt: float) -> void:
	# Shared progress may change research/equipment before this same combat step.
	if not admit_execution():return
	super._tick_combat_step(dt)

func stat(key: String) -> Variant:
	var value: Variant = super.stat(key)
	return N.multiply(value,player_power_multiplier) if key in ["armour", "shield"] else value

func jewel_attack(index: int, multiplier := 1.0) -> Dictionary:
	var attack := super.jewel_attack(index, multiplier)
	attack.damage = N.multiply(attack.damage,player_power_multiplier)
	return attack

func fire(source: Dictionary, target: Dictionary, weapon: Dictionary, raw, hostile: bool, key: String, offset := Vector2.ZERO, visual_spread := 0.0) -> void:
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
	execution_error="";execution_inputs=[]
	if not admit_execution(true):return false
	var result := super.start(level,loop_mode,checkpoint)
	if result:
		clear_pending_hits()
		execution_error="";execution_inputs=[]
		return admit_execution(true)
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
			if not player_alive():continue
		elif N.compare(shot.target.hp,0)<=0 or not enemies.has(shot.target):continue
		shot.x = item.destination.x
		shot.y = item.destination.y
		projectiles.append(shot)
		fast_resolved += 1
		added = true
	if added:projectiles.sort_custom(func(a,b):return a.serial < b.serial)
	# Reuse impact events, hit functions, death clearing, AOE and gem triggers.
	super.tick_projectiles(dt)

func advance_jewel_repair(dt: float) -> bool:
	repair_cache_active = true
	var repaired := super.advance_jewel_repair(dt)
	repair_cache_active = false
	repair_entries.clear()
	repair_effects.clear()
	repair_stats.clear()
	return repaired

func repair_entry_index(entry: Dictionary) -> int:
	for index in repair_entries.size():
		if same_module(repair_entries[index],entry):return index
	repair_entries.append(entry)
	return repair_entries.size()-1

func jewel_effects(entry: Dictionary) -> Array:
	if not repair_cache_active:return tick_jewel_effects(entry)
	var index := repair_entry_index(entry)
	if not repair_effects.has(index):repair_effects[index] = tick_jewel_effects(entry)
	return repair_effects[index]

func tick_jewel_effects(entry: Dictionary) -> Array:
	if not tick_effects_active:return super.jewel_effects(entry)
	for index in tick_effect_entries.size():
		if same_module(tick_effect_entries[index],entry):return tick_effect_values[index].duplicate(true)
	var value := super.jewel_effects(entry)
	tick_effect_entries.append(entry)
	tick_effect_values.append(value)
	return value.duplicate(true)

func clear_tick_effects() -> void:
	tick_effect_entries.clear()
	tick_effect_values.clear()

func jewel_equipment_stat(entry: Dictionary, level := -1, effects: Variant = null, include_timed_buffs := true, galaxy_equipment := -1.0, galaxy_charge := -1.0) -> Variant:
	if not repair_cache_active or level >= 0 or effects != null or not include_timed_buffs or galaxy_equipment >= 0 or galaxy_charge >= 0:return super.jewel_equipment_stat(entry,level,effects,include_timed_buffs,galaxy_equipment,galaxy_charge)
	var index := repair_entry_index(entry)
	if not repair_stats.has(index):repair_stats[index] = super.jewel_equipment_stat(entry,level)
	return repair_stats[index]

func _init(database: ShipDatabase) -> void:
	super(database,false)
	if not startup_error.is_empty():return
	profile.hightechSavedAt = 0.0
	progress_runtime = ResearchMetrics.new()
	event.connect(observe)

func create_load_candidate(database:ShipDatabase)->BattleGame:
	var candidate=get_script().new(database)
	candidate.simulated_time=simulated_time
	candidate.player_power_multiplier=player_power_multiplier
	candidate.simulation_mode=simulation_mode
	return candidate

func install_loaded_session(candidate:BattleGame)->void:
	super.install_loaded_session(candidate)
	pending_hits.clear();fresh_shots.clear();projectile_tick=0
	repair_cache_active=false;repair_entries.clear();repair_effects.clear();repair_stats.clear()
	tick_effects_active=false;clear_tick_effects()

func economy_time() -> float:
	return simulated_time

func save_progress() -> void:
	pass

func tick(dt: float) -> void:
	if not admit_execution():return
	if paused or commit_effects.active or logical_step_active:return
	# This independent analysis clock substitutes for live wall time.
	if not step_progress.active:
		simulated_time += dt
		advance_resource_history_clock(dt)
		if metrics != null:
			metrics.time = simulated_time
			if state == State.COMBAT:metrics.combat_seconds += dt
	tick_effects_active = true
	super.tick(dt)
	tick_effects_active = false
	clear_tick_effects()

func observe(kind: String, payload: Dictionary) -> void:
	if kind in ["module_changed","ship_changed","jewels_changed","enhancement_changed","upgrade"]:clear_tick_effects()
	if kind in ["projectile_impact","beam_hit"]:
		var shot: Dictionary = payload.shot
		if not shot.hostile:source_weapon = str(shot.entry.key) if shot.get("beam",false) else str(shot.key)
	if metrics != null:
		metrics.current_stage = stage
		metrics.on_event(kind,payload)
		if kind == "state" and state == State.LEVEL_CLEAR:metrics.timeline.discover(self,simulated_time)

func spawn_group(keep_distance := false) -> void:
	if not execution_error.is_empty():return
	execution_error=Execution.encounter(self)
	if not execution_error.is_empty():return
	super.spawn_group(keep_distance)
	if not admit_execution(true):return
	if metrics == null:return
	metrics.born.clear()
	metrics.encounter_start = simulated_time
	for enemy in enemies:
		metrics.born[enemy.uid] = simulated_time
		metrics.spawn_count += 1
		metrics.spawn_hp = N.add(metrics.spawn_hp,enemy.max_hp)
	if is_boss_encounter():metrics.timeline.record("BOSS",simulated_time,stage,{"wave":group_index})

func hit_enemy(enemy: Dictionary, raw, type: int, effects: Array = [], critical: bool = false, context: Dictionary = {}) -> void:
	if not execution_error.is_empty():return
	execution_error=Execution.enemy_state(enemy)
	if not execution_error.is_empty():return
	var before: Variant = enemy.hp
	var weapon := source_weapon
	var boss := is_boss_encounter()
	super.hit_enemy(enemy,raw,type,effects,critical,context)
	if simulation_mode == "fast" and N.compare(before,0)>0 and N.compare(enemy.hp,0)<=0 and boss and targets().is_empty():clear_pending_hits()
	if metrics == null or N.compare(before,0)<=0:return
	metrics.add(metrics.damage,weapon,N.subtract(before,enemy.hp))
	if N.compare(enemy.hp,0)<=0 and metrics.born.has(enemy.uid):
		metrics.ttk_sum += simulated_time-float(metrics.born[enemy.uid])
		metrics.kills += 1
		if not boss:
			metrics.normal_ttk_sum += simulated_time-float(metrics.born[enemy.uid])
			metrics.normal_kills += 1
		metrics.born.erase(enemy.uid)
		if boss and metrics.born.is_empty():
			metrics.boss_kills += 1
			metrics.boss_ttk_sum += simulated_time-metrics.encounter_start

func hit_player(raw, type: int, context: Dictionary = {}) -> void:
	var armour: Variant = player.armour
	var shield: Variant = player.shield
	super.hit_player(raw,type,context)
	if metrics == null:return
	metrics.health_lost = N.add(metrics.health_lost,N.subtract(armour,player.armour))
	metrics.shield_absorbed = N.add(metrics.shield_absorbed,N.subtract(shield,player.shield))
	metrics.received = N.add(metrics.received,N.subtract(N.add(armour,shield),N.add(player.armour,player.shield)))
	metrics.min_health = player.armour if metrics.min_health==null else N.minimum(metrics.min_health,player.armour)
	metrics.min_shield = player.shield if metrics.min_shield==null else N.minimum(metrics.min_shield,player.shield)

func begin_retreat() -> void:
	# All ordinary targets are lost on death; none may hit a reset player later.
	if simulation_mode == "fast":clear_pending_hits()
	if metrics != null and state != State.RETREAT:
		metrics.deaths += 1
		metrics.timeline.record("DEATH",simulated_time,stage,{"wave":group_index})
		if metrics.first_death == null:metrics.first_death = {"time":simulated_time,"stage":stage,"wave":group_index}
		metrics.born.clear()
	super.begin_retreat()

func upgrade_reactor(amount: int) -> bool:
	var before: Variant = economy.balance(str(int(db.config.reactorUraniumId)))
	var result := super.upgrade_reactor(amount)
	if result and metrics != null:
		metrics.spend("reactor",{str(int(db.config.reactorUraniumId)):N.subtract(before,economy.balance(str(int(db.config.reactorUraniumId))))})
		metrics.use("reactor_levels",amount)
	return result

func upgrade_enhancement(count := 1) -> int:
	var before: Variant = economy.balance("jewel")
	var purchased := super.upgrade_enhancement(count)
	if metrics!=null and purchased>0:
		metrics.use("enhancement_levels",purchased)
		metrics.spend("enhancements",{"jewel_fragments":N.subtract(before,economy.balance("jewel"))})
	return purchased

func commit_income_receipt(id:String,earned:Variant,source:String,notices:Array,drop:Dictionary={},manual:=false,production_base:Variant=null)->Dictionary:
	var result:Dictionary=super.commit_income_receipt(id,earned,source,notices,drop,manual,production_base)
	if metrics!=null and id=="jewel" and result.status=="committed":metrics.add(metrics.income,"jewel_fragments",earned)
	return result
