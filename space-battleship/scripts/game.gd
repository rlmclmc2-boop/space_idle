class_name BattleGame
extends RefCounted

const CLEAR_ADVANCE_DELAY := 3.0
const MAX_TRAVEL_SECONDS := 3.0
const REACTIVE_STACK_LIMIT := 3
const REACTIVE_STACK_REDUCTION := 0.2
const REACTIVE_RESET_SECONDS := 2.2
const REACTIVE_VOLLEY_GAP := 0.16

signal event(kind: String, payload: Dictionary)

enum State { MAIN_MENU, LEVEL_SELECT, TRAVEL, COMBAT, LEVEL_CLEAR, DEFEAT, UPGRADE, RETREAT }
const EQUIPMENT := ["armour", "shield", "laser", "missile", "cannon", "longLaser"]
const SAVE_PATH := "user://progress.json"
const SAVE_VERSION := 10
# JSON.parse_string stores numbers as doubles; larger integers cannot round-trip exactly.
const EnhancementGrowth=preload("res://scripts/enhancement_growth.gd")
var enhancement_growth:=EnhancementGrowth.new()
const N = preload("res://scripts/growth_number.gd")
const ReactorInt = preload("res://scripts/reactor_integer.gd")
const AITech = preload("res://scripts/ai_tech_tree.gd")
var research := AITech.new()
const EquipmentState=preload("res://scripts/equipment_state.gd")
var equipment := EquipmentState.new()
const AttackBirth=preload("res://scripts/attack_birth_configuration.gd")
const CombatContext=preload("res://scripts/combat_context.gd")
const DroneEffects=preload("res://scripts/drone_effect_aggregator.gd")
const RailGeometry=preload("res://scripts/rail_geometry.gd")
var rail_geometry_provider:=Callable()
var rail_target_point_provider:=Callable()
var player_launch_payload: Dictionary={}
var hyperspace_runtime:=preload("res://scripts/hyperspace_runtime.gd").new()
var manual_hyperspace:=preload("res://scripts/hyperspace_manual_session.gd").new()
var drone_combat:=preload("res://scripts/drone_combat_effects.gd").new()
const PlanetState=preload("res://scripts/planet_state.gd")
var planets:=PlanetState.new()
var planet_buildings := preload("res://scripts/planet_buildings.gd").new()
var planet_buffs := preload("res://scripts/planet_buffs.gd").new()
var galaxy := preload("res://scripts/galaxy_system.gd").new()
var galaxy_runtime := preload("res://scripts/galaxy_runtime.gd").new()
var hyperspace := preload("res://scripts/hyperspace_system.gd").new()
const FURNACE := "超时空炼铁炉"
const JEWEL_FURNACE := "宝石熔炼炉"
const ENERGY_FOCUS := "正电子聚焦装置"
const DENSE_ARMOUR := "简并态装甲"
const NUMBER_FORMAT := preload("res://scripts/number_format.gd")
const HIGHTECH_SLOTS_PER_PAGE := 3
const HIGHTECH_MIN_SLOTS := 6
const WEAPON_KEYS := ["laser", "missile", "cannon", "longLaser"]
const DEFENSE_KEYS := ["armour", "shield"]
const BATTLE_SIZE := Vector2(572,696)
const PLAYER_POSITION := Vector2(286,520)
const ENEMY_LINE_LEFT := 66.0
const ENEMY_LINE_SPACING := 440.0 / 9.0
const ENEMY_LINE_Y := 140.0

static func enemy_slot_position(slot: int, columns := 10) -> Vector2:
	if columns == 5:return Vector2(ENEMY_LINE_LEFT+float(slot%5)*110.0,94.0+float(slot/5)*144.0)
	return Vector2(ENEMY_LINE_LEFT + float(slot) * ENEMY_LINE_SPACING,ENEMY_LINE_Y)
var db: ShipDatabase
var profile: Dictionary
var economy := preload("res://scripts/economy_state.gd").new()
var reactor := preload("res://scripts/reactor_state.gd").new()
var crew := preload("res://scripts/crew_system.gd").new()
var state: State = State.MAIN_MENU
var stage := 1
var distance := 0.0
var travel_origin := INF
var group_index := 0
var enemies: Array[Dictionary] = []
# Legacy: complete live shot collection. Native: bound compatibility rows only;
# compact laser inventory/motion belongs to kernel. Native presentation uses
# typed membership; explicit full compatibility requests must check null from
# kernel.projectile_views(). Handoff replaces this with the complete collection.
var projectiles: Array[Dictionary] = []
var native_execution:RefCounted
var native_execution_requested:=false
var native_execution_auto:=false
var native_execution_scope:=""
var native_wave_waiting:=false
var native_step_phase:="idle"
var logical_step_active:=false
var native_step_remaining:=0.0
var native_cancelled_step:=0.0
var native_handoff_count:=0

var drops: Array[Dictionary] = []
var player: Dictionary = {}
var cooldowns: Dictionary = {}
var since_hit := 100.0
var paused := false
var speed := 1.0
const LOGICAL_STEP := 1.0/60.0
const RETURN_DEPARTURE_SECONDS := 1.6
var game_time_remainder := 0.0
var departure_remaining := 0.0
var application_focused := true
var external_time_active := false
var clear_timer := 0.0
var guard_index := -1
var guard_elapsed := 0.0
var guard_engaged := false
var guard_arrived := false
var first_clear := false
var run_resources := {"1": 0.0, "2": 0.0}
var uid := 0
var projectile_serial := 0
var startup_error := ""
var save_enabled := true
var attributes:=preload("res://scripts/attribute_projection.gd").new()
var stat_cache_enabled:bool:
	get:return attributes.enabled
	set(value):attributes.enabled=value
var configuration_revision:=0
var unlock_revision:=0
var _unlock_inputs:Array=[]
var _committed_configuration:Array=[]
var ai_tech_last_resource_notice_ms := 0
var login_chrono_particles := 0.0
var pending_unlocks: Array[String] = []
# Derived tutorial projection belongs to this Game, never to UI controls.
var _tutorial_ids: Array[String] = []
var _tutorial_unread: Array[String] = []
var _tutorial_dirty := true
var _tutorial_read_dirty := true
var _tutorial_revision := 0
var _tutorial_highest := -1
var _tutorial_hyperspace_gate := -1
var _tutorial_db: ShipDatabase
var retreat_from := 0.0
var retreat_target := 0.0
var retreat_elapsed := 0.0
var retreat_boss_pending := false
var rng := RandomNumberGenerator.new()
var resource_prune_elapsed := 0.0
var resource_samples: Array[Dictionary] = []
var auto_gen_elapsed := 0.0
var save_dirty := false
var planet_crew_payout_active := false
var save_interval_minutes := 1
var next_timed_save_at := 0.0
var last_successful_save_at := 0.0
var last_save_error: Error = OK
var progress_writer := preload("res://scripts/progress_writer.gd").new()
var jewel_repeats: Array[Dictionary] = []
var main_attack_serial := 0
var damage_stats=preload("res://scripts/battle_damage_stats.gd").new()
var attack_instance_serial := 0
var jewel_defence_times: Dictionary = {}
var jewel_defence_damage: Dictionary = {}
var jewel_charged: Dictionary = {}
var compiled_combat_rules:RefCounted
var enhancement_branches := preload("res://scripts/enhancement_branches.gd").new()
var enhancement_attack_contexts: Dictionary = {}
var enhancement_buffers: Dictionary = {}
var enhancement_buffer_owners: Dictionary = {}
var enhancement_memory_elapsed := 0.0
var enhancement_defense_time := 0.0
var enhancement_deferred_elapsed := 0.0
var enhancement_deferred_tick := 0
var enhancement_deferred: Dictionary = {}
# A terminal window can interrupt a due settlement after its phase wrapped.
var enhancement_memory_due_pending:=false
var enhancement_deferred_due_pending:=false
# Preserves damage fraction while a capacity temporarily becomes zero during refit.
var refit_health_ratios := {"armour":1.0,"shield":1.0}
var enemy_shield_time := 0.0
var enemy_shield_hit_time := -1.0
# These are a local combat-span mapping, not a second persistent defence clock.
var _legacy_defence_span_active:=false
var _legacy_defence_origin:=0.0
var _legacy_combat_origin:=0.0
var _legacy_combat_end:=0.0

# Overridden only by the isolated Debug simulator. Live games retain wall time.
func economy_time() -> float:
	return Time.get_unix_time_from_system()

func _init(database: ShipDatabase, persist := true) -> void:
	event.connect(_configuration_event)
	db = database
	progress_writer.validation_db = db
	if not preload("res://scripts/hyperspace_config.gd").pack_valid(self):
		startup_error="invalid_hyperspace_config_pack";save_enabled=false;paused=true;profile={}
		push_error(startup_error)
		return
	speed = default_speed()
	save_enabled = persist
	if persist and not progress_writer.acquire_owner():
		# A second process may inspect/play this snapshot, but cannot commit it.
		save_enabled = false
		last_save_error = ERR_ALREADY_IN_USE
	stat_cache_enabled = persist
	rng.randomize()
	profile = fresh_profile()
	reset_equipment()
	enhancement_growth.reset()
	research.reset()
	economy.reset({"1":ceilf(float(db.defaults.startingIron)),"2":ceilf(float(db.defaults.startingTitanium))},hyperspace.config)
	reactor.reset(db.config)
	crew.attach(self)
	galaxy.reset(db)
	crew.reset(self)
	planets.reset(self)
	galaxy_runtime.refresh_unlocks(self)
	profile.hightechOrder = hightech_slots()
	if persist:
		load_progress()
		save_dirty = true
	reset_player()
	reset_save_timer()
	if persist:manual_hyperspace.load_production(self)

func fresh_profile() -> Dictionary:
	var profile := {"version":SAVE_VERSION, "productionElapsed":0.0, "highestLevel":1, "cleared":[], "bossSeen":[], "unlocked":str(db.config.startEquip).split(","), "loop":false, "hightechSavedAt":Time.get_unix_time_from_system()}
	# The retired page still reads these inert values until the new art page lands.
	profile.scientists = 0
	profile.scientistAssignments = {}
	profile.techPoints = {}
	profile.hightechLevels = {}
	# Initial availability also belongs to unlock; startEquip only selects loadout.
	profile.unlocked = EQUIPMENT.filter(func(key):return db.unlock_level(key) == 0)
	profile.onboarding = {"version":1, "intro":false, "equipped":false, "upgraded":false, "completed":false, "dismissed":false, "retreatSeen":false, "pickupSeen":false}
	profile.jewels = [] # Empty compatibility projection; no live gem inventory.
	profile.lifetime_max_stage = 1
	profile.seenUnlocks = []
	profile.readUnlocks = []
	profile.jewelFurnaceElapsed = 0.0
	profile.jewelFurnaceIncomePeak = 0.0
	return profile

func first_ship() -> String:
	return str(db.ships.keys()[0]) if not db.ships.is_empty() else "Frigate"

func ship_unlocked(key: String) -> bool:
	return not db.ship(key).is_empty() and content_unlocked("ship", key)

func unlock_available(id: String) -> bool:
	var row: Dictionary = db.data.get("unlock", {}).get(id, {})
	if row.get("type", "") == "planet" and not planet_buffs.allows_planet(self, str(row.target)):return false
	return unlock_condition_available(id)

func unlock_condition_available(id: String) -> bool:
	var row: Dictionary = db.data.get("unlock", {}).get(id, {})
	if row.is_empty():return false
	if profile.get("grantedUnlocks", []).has(id):return true
	if row.get("type")=="feature" and row.get("target")=="galaxy":
		var definitions: Array=db.data.get("galaxy",{}).values()
		if definitions.is_empty() or not definitions.any(func(definition):return galaxy.condition_met(self,definition)):return false
	var gate := int(row.level)
	if gate == 0:return true
	# Reached-mode preserves the former highestLevel semantics, including gaps.
	if row.get("mode", "cleared") == "reached":
		return int(profile.highestLevel) > gate
	return profile.cleared.has(gate)

func content_unlocked(kind: String, key: String) -> bool:
	return unlock_available(db.unlock_id(kind, key))

func granted_unlocks() -> Array[String]:
	# Keep earned level conditions through reforge even while conquest is pending.
	var result: Array[String] = []
	for id in db.data.get("unlock", {}):
		if unlock_condition_available(str(id)):result.append(str(id))
	return result

func available_unlocks() -> Array[String]:
	var result: Array[String] = []
	for id in db.data.get("unlock", {}):
		# The old scientist/assignment notices do not describe the new factory.
		if str(db.data.unlock[id].get("type", "")) == "hightech":continue
		if unlock_available(str(id)):result.append(str(id))
	return result

func invalidate_tutorial_unlocks() -> void:
	_tutorial_dirty = true
	_tutorial_read_dirty = true

func tutorial_revision() -> int:
	# These scalar gates also cover temporary database ownership and live gate edits.
	var highest := int(profile.highestLevel)
	var gate := int(hyperspace.config.unlock_stage)
	if _tutorial_db != db or highest != _tutorial_highest or gate != _tutorial_hyperspace_gate:
		invalidate_tutorial_unlocks()
		_tutorial_db = db
		_tutorial_highest = highest
		_tutorial_hyperspace_gate = gate
	if _tutorial_dirty:
		_tutorial_ids = _compute_tutorial_unlocks()
		_tutorial_dirty = false
	if _tutorial_read_dirty:
		_tutorial_unread = _tutorial_ids.filter(func(id):return not profile.get("readUnlocks", []).has(id))
		_tutorial_read_dirty = false
		_tutorial_revision += 1
	return _tutorial_revision

func tutorial_unlocks() -> Array[String]:
	tutorial_revision()
	return _tutorial_ids.duplicate()

func _compute_tutorial_unlocks() -> Array[String]:
	# Seen notices also retain earned knowledge through a reforge's new run.
	var result: Array[String] = []
	for id in db.data.get("unlock", {}):
		if str(db.data.unlock[id].get("type", "")) == "hightech":continue
		if unlock_available(str(id)) or profile.get("seenUnlocks", []).has(id):result.append(str(id))
	if hyperspace.is_unlocked(self) or profile.get("seenUnlocks", []).has("hyperspace"):
		if not result.has("hyperspace"):result.append("hyperspace")
	return result

func tutorial_unlock_row(id: String) -> Dictionary:
	if not tutorial_unlocks().has(id):return {}
	if id=="hyperspace":
		return {"type":"feature","target":"hyperspace","title":UIText.t("hyperspace.title"),"desc":UIText.t("tutorial.hyperspace.description")}
	return db.data.get("unlock",{}).get(id,{})

func unread_tutorial_unlocks() -> Array[String]:
	tutorial_revision()
	return _tutorial_unread.duplicate()

func read_tutorial_unlock(id: String) -> bool:
	if not tutorial_unlocks().has(id) or profile.get("readUnlocks", []).has(id):return false
	profile.readUnlocks.append(id)
	_tutorial_read_dirty = true
	if id=="hyperspace" and not profile.seenUnlocks.has(id):profile.seenUnlocks.append(id)
	save_dirty = true
	event.emit("tutorial_read", {"id":id})
	return true

func reset_equipment() -> void:
	var starting: Array = Array(str(db.config.startEquip).split(",")).filter(func(key):return profile.unlocked.has(key))
	equipment.reset(db,first_ship(),starting)

func default_loadout(key: String, unlocked: Array) -> Dictionary:
	return EquipmentState.default_loadout(db,key,unlocked)

func empty_loadout(key: String) -> Dictionary:
	return EquipmentState.empty_loadout(db,key)

static func same_module(a: Dictionary,b: Dictionary) -> bool:
	return EquipmentState.same_source(a,b)

func load_progress() -> void:
	var result := progress_writer.read_progress_result(SAVE_PATH, db)
	if result.status == "loaded":
		load_progress_data(result.data)
		if hyperspace.last_error.is_empty():
			if not progress_writer.owns_progress():return
			# Our OS lock proves a prior import owner is gone even if its PID was reused.
			result.import_active = false
			var recovery_error := progress_writer.finish_loaded_recovery(SAVE_PATH,result)
			if recovery_error != OK:
				# The selected state is live, but unresolved disk recovery must not
				# allow an automatic or manual save to overwrite any evidence.
				startup_error="progress_recovery_pending"
				save_enabled=false
				paused=true
				last_save_error=recovery_error
			return
	elif result.status == "absent":return
	# A rejected existing save must never become an autosaved fresh profile.
	startup_error="invalid_progress_save";save_enabled=false;paused=true;last_save_error=ERR_FILE_CORRUPT

func load_progress_data(raw: Dictionary) -> void:
	var source_db = manual_hyperspace.base_db if manual_hyperspace.active else db
	var prepared: Dictionary = load("res://scripts/save_transfer.gd").new().prepare_data(raw, source_db)
	if not prepared.error.is_empty():
		hyperspace.last_error = "invalid_progress_save"
		return
	raw = prepared.data
	# Reject a future/corrupt subsystem before changing any authoritative balance.
	var validation_db=manual_hyperspace.base_db if manual_hyperspace.active else db
	if raw.has("hyperspace") and (not raw.hyperspace is Dictionary or not preload("res://scripts/hyperspace_state.gd").valid(raw.hyperspace,hyperspace.config,validation_db.levels.size()) or not preload("res://scripts/hyperspace_permissions.gd").bindings_valid(raw,validation_db.data,hyperspace.config)):
		hyperspace.last_error="invalid_hyperspace_save"
		return
	# The challenge receipt is the sole saved return destination. Derive an
	# ordinary fresh journey only after complete validation, before installation.
	var interrupted:Dictionary=raw.hyperspace.active
	if not interrupted.is_empty() and interrupted.status=="started":
		var target:Dictionary=interrupted.return_target
		raw.journey=preload("res://scripts/hyperspace_return_target.gd").checkpoint(target,validation_db)
		raw.loop=target.loop
		if target.loop:
			raw.guardStage=int(target.stage);raw.guardIndex=int(target.guard_index);raw.guardDistance=raw.journey.distance
	var signals_were_blocked := is_blocking_signals()
	set_block_signals(true)
	login_chrono_particles = 0.0
	manual_hyperspace.reset_for_load(self)
	game_time_remainder=0.0;departure_remaining=0.0;resource_prune_elapsed=0.0
	profile = fresh_profile()
	resource_samples.clear()
	pending_unlocks.clear()
	var interval_value = raw.get("saveIntervalMinutes", 1)
	var interval := parse_save_interval(str(interval_value))
	if interval_value is float and is_finite(interval_value) and interval_value >= 1 and interval_value < 9.0e18 and interval_value == floorf(interval_value):interval = int(interval_value)
	if interval > 0:save_interval_minutes = interval
	var saved_at = raw.get("hightechSavedAt", 0.0)
	if (saved_at is int or saved_at is float) and is_finite(float(saved_at)) and saved_at > 0:
		last_successful_save_at = float(saved_at)
	# Old saves remain quiet; fresh profiles alone opt into first-session guidance.
	profile.onboarding = {"version":1, "intro":false, "equipped":false, "upgraded":false, "completed":true, "dismissed":false, "retreatSeen":true, "pickupSeen":true}
	if raw.get("onboarding") is Dictionary:
		for key in ["intro", "equipped", "upgraded", "completed", "dismissed"]:
			profile.onboarding[key] = raw.onboarding.get(key, false) == true
		profile.onboarding.retreatSeen = raw.onboarding.get("retreatSeen",profile.onboarding.completed) == true
		profile.onboarding.pickupSeen = raw.onboarding.get("pickupSeen",profile.onboarding.completed) == true
	profile.lifetime_max_stage = int(raw.get("lifetime_max_stage",raw.get("highestLevel",1)))
	if raw.get("cleared") is Array:
		for n in raw.cleared:
			if (n is float or n is int) and n == int(n) and n >= 1 and n <= db.levels.size() and not profile.cleared.has(int(n)):
				profile.cleared.append(int(n))
	profile.bossSeen = profile.cleared.duplicate()
	if raw.get("bossSeen") is Array:
		for n in raw.bossSeen:
			if (n is float or n is int) and n == int(n) and n >= 1 and n <= db.levels.size() and not profile.bossSeen.has(int(n)):
				profile.bossSeen.append(int(n))
	economy.install_snapshot(raw)
	profile.loop = false
	var death_mode = raw.get("guardDeath", 0)
	profile.guardDeath = int(death_mode) if (death_mode is int or death_mode is float) and death_mode == int(death_mode) and int(death_mode) in [0,1,2] else 0
	profile.grantedUnlocks = []
	if raw.get("grantedUnlocks") is Array:
		for id in raw.grantedUnlocks:
			if id is String and db.data.get("unlock", {}).has(id) and not profile.grantedUnlocks.has(id):
				profile.grantedUnlocks.append(id)
	# Older saves explicitly owned equipment; retain it even if gates are edited.
	if raw.get("unlocked") is Array:
		for key in raw.unlocked:
			if key is String and EQUIPMENT.has(key):
				var id := db.unlock_id("equipment", key)
				if not id.is_empty() and not profile.grantedUnlocks.has(id):profile.grantedUnlocks.append(id)
	# Install every validated domain before any contribution, capacity or schedule reads.
	equipment.install_snapshot(raw,db)
	profile.productionElapsed = float(raw.productionElapsed)
	enhancement_growth.install_snapshot(raw)
	load_hightech(raw)
	crew.install_snapshot(raw,db)
	planets.install_snapshot(raw,db)
	reactor.install_snapshot(raw,db.config)
	hyperspace.install_snapshot(raw,db) # No offline energy/work accrual.
	galaxy.install_snapshot(raw,db)
	galaxy_runtime.reset()
	hyperspace_runtime.reset();hyperspace_runtime.settle_interrupted(self)
	rebuild_unlock_gates()
	profile.hightechOrder = hightech_slots()
	refresh_unlock_revision()
	galaxy_runtime.refresh_unlocks(self)
	configuration_committed()
	# Reconcile against restored contributions; only then establish derived schedules.
	var installed_reactor_revision := reactor.revision
	reactor.reconcile_capacity(reactor_capacity())
	if reactor.revision != installed_reactor_revision:configuration_committed()
	economy.accrue_chrono(0.0, chrono_capacity())
	login_chrono_particles = accrue_chrono_particles(raw.get("chronoSavedAt"), Time.get_unix_time_from_system())
	crew.reset_schedule(self)
	load_journey(raw.get("journey", {}))
	# Old saves knew ownership but not notification history. Preserve their pending
	# pages; all other previously owned unlocks have already been experienced.
	var seen_source = raw.get("seenUnlocks", available_unlocks().filter(func(key):return not profile.get("journey",{}).get("pendingUnlocks",[]).has(key)))
	if seen_source is Array:
		for key in seen_source:
			if key is String and not profile.seenUnlocks.has(key):profile.seenUnlocks.append(key)
	if profile.has("journey"):
		profile.journey.pendingUnlocks = profile.journey.get("pendingUnlocks",[]).filter(func(key):return not profile.seenUnlocks.has(key))
	invalidate_tutorial_unlocks()
	# A notification acknowledgement is not a tutorial read. Old saves backfill
	# earned entries as unread, without replaying notices or granting rewards.
	if raw.get("readUnlocks") is Array:
		for id in raw.readUnlocks:
			if id is String and tutorial_unlocks().has(id) and not profile.readUnlocks.has(id):profile.readUnlocks.append(id)
	var selected = raw.get("loopLevel", 0)
	profile.loopLevel = int(selected) if (selected is int or selected is float) and profile.cleared.has(int(selected)) else 0
	var guard_stage = raw.get("guardStage", 0)
	var saved_index = raw.get("guardIndex", -1)
	var saved_distance = raw.get("guardDistance", -1)
	if raw.get("loop", false) == true and (guard_stage is int or guard_stage is float) and guard_stage == int(guard_stage) and guard_stage >= 1 and guard_stage <= profile.highestLevel:
		if (saved_index is int or saved_index is float) and saved_index == int(saved_index) and saved_index >= 0 and saved_index < db.levels[int(guard_stage)-1].groups.size() and (saved_distance is int or saved_distance is float) and is_finite(float(saved_distance)) and saved_distance >= 0 and saved_distance <= float(db.levels[int(guard_stage)-1].length):
			profile.loop = true
			profile.guardStage = int(guard_stage)
			profile.guardIndex = int(saved_index)
			profile.guardDistance = float(saved_distance)
	invalidate_tutorial_unlocks()
	set_block_signals(signals_were_blocked)

func load_journey(value) -> void:
	if not value is Dictionary:
		return
	for key in ["stage", "groupIndex", "state"]:
		if not nonnegative_number(value.get(key)) or float(value[key]) != floorf(float(value[key])):
			return
	if value.stage < 1 or value.stage > profile.highestLevel:
		return
	var level: Dictionary = db.levels[int(value.stage)-1]
	if not nonnegative_number(value.get("distance")) or value.distance > float(level.length) or value.groupIndex > level.groups.size():
		return
	if not int(value.state) in [State.TRAVEL, State.COMBAT, State.LEVEL_CLEAR, State.RETREAT]:
		return
	if int(value.state) == State.COMBAT and value.groupIndex == 0:
		return
	if int(value.state) == State.LEVEL_CLEAR and (value.groupIndex != level.groups.size() or not profile.cleared.has(int(value.stage))):
		return
	profile.journey = {"stage":int(value.stage), "groupIndex":int(value.groupIndex), "distance":float(value.distance), "state":int(value.state), "guardArrived":value.get("guardArrived") == true, "retreatBossPending":value.get("retreatBossPending") == true}
	profile.journey.pendingUnlocks = []
	if value.get("pendingUnlocks") is Array:
		for key in value.pendingUnlocks:
			if key is String and unlock_available(key) and not profile.journey.pendingUnlocks.has(key):
				profile.journey.pendingUnlocks.append(key)

func resume_progress() -> void:
	var checkpoint: Dictionary = profile.get("journey", {})
	profile.erase("journey")
	if not checkpoint.is_empty():
		start(int(checkpoint.stage), bool(profile.loop), checkpoint)
	else:
		# Old saves retain their previous startup and guard behavior.
		start(int(profile.guardStage) if profile.loop else int(profile.highestLevel), bool(profile.loop))
		if profile.loop:
			resume_guard()
			save_dirty = true

func chrono_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for item in str(db.config.chronoSpeeds).split(","):
		var fields := item.split("|")
		if fields.size() != 2 or not fields[0].is_valid_float() or not fields[1].is_valid_float():
			continue
		var multiplier := float(fields[0])
		var cost := float(fields[1])
		if is_finite(multiplier) and multiplier > 0 and is_finite(cost) and cost >= 0:
			options.append({"multiplier":multiplier,"cost":cost})
	return options

func default_speed() -> float:
	return float(db.config.chronoDefaultSpeed)

func chrono_cost(multiplier: float) -> float:
	for option in chrono_options():
		if is_equal_approx(float(option.multiplier), multiplier):
			return float(option.cost)
	return -1.0

func set_speed(multiplier: float) -> bool:
	var cost := chrono_cost(multiplier)
	if cost < 0 or (cost > 0 and float(economy.balance("chrono")) <= 0):
		return false
	speed = multiplier
	return true

func chrono_capacity() -> float:
	return float(db.config.offlineMax) * 3600.0 * float(db.config.chronoParticlesPerSecond)

func accrue_chrono_particles(saved_at: Variant, now: float) -> float:
	if not nonnegative_number(saved_at):
		return 0.0
	var seconds := clampf(floorf(now - float(saved_at)), 0.0, float(db.config.offlineMax) * 3600.0)
	var earned := maxf(0.0, floorf(seconds * float(db.config.chronoParticlesPerSecond)))
	var available := maxf(0.0, floorf(chrono_capacity() - float(economy.balance("chrono"))))
	var gained := minf(earned, available)
	economy.accrue_chrono(gained, chrono_capacity())
	return gained

func set_application_focused(focused:bool)->void:
	if application_focused==focused:return
	application_focused=focused
	speed=default_speed()

func begin_return_departure()->void:
	departure_remaining=RETURN_DEPARTURE_SECONDS

func consume_external_time(real_dt:float,presentation:Variant=null)->void:
	# Sole live wall-time consumer. tick() remains the domain's logical algorithm
	# for internal event subdivision and deterministic offline analysis.
	if external_time_active or not is_finite(real_dt) or real_dt<0:return
	check_timed_save()
	if paused:return
	external_time_active=true
	if departure_remaining>0:
		var held:=minf(real_dt,departure_remaining)
		departure_remaining=maxf(0.0,departure_remaining-held)
		if departure_remaining<0.0000000001:departure_remaining=0.0
		real_dt=maxf(0.0,real_dt-held)
		if departure_remaining>0 or real_dt<0.0000000001:
			external_time_active=false;return
	if presentation!=null and not presentation.prepare_time_frame():
		# Preserve the existing native materialization guard; a failed preparation
		# must neither spend particles nor silently accumulate more unpaid work.
		paused=true;external_time_active=false;return
	if not application_focused:speed=default_speed()
	var cost:=chrono_cost(speed)
	if cost<0:speed=default_speed();cost=chrono_cost(speed)
	var boosted:=economy.consume_chrono(real_dt,cost)
	var budget:=boosted*speed
	if boosted<real_dt or (cost>0 and economy.balance("chrono")<=0):
		speed=default_speed()
		budget+=(real_dt-boosted)*speed
	advance_resource_history_clock(real_dt)
	if native_cancelled_step>0:
		game_time_remainder=maxf(0.0,game_time_remainder-native_cancelled_step)
		native_cancelled_step=0.0
	game_time_remainder+=budget
	while game_time_remainder+0.0000000001>=LOGICAL_STEP and not paused and departure_remaining<=0:
		if not prepare_logical_step(LOGICAL_STEP):break
		if presentation!=null:presentation.before_time_step(LOGICAL_STEP)
		tick(LOGICAL_STEP)
		var completed:=native_step_phase!="blocked"
		var ready:=true if presentation==null else bool(presentation.after_time_step(completed))
		if not completed:break
		game_time_remainder=maxf(0.0,game_time_remainder-LOGICAL_STEP)
		if not ready:paused=true;break
	if presentation!=null:presentation.publish_time_frame()
	external_time_active=false

func advance_resource_history_clock(seconds:float)->void:
	resource_prune_elapsed+=seconds
	if resource_prune_elapsed>=5.0:
		resource_prune_elapsed=fmod(resource_prune_elapsed,5.0)
		prune_resource_samples(economy_time())


func nonnegative_number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0

func load_hightech(raw: Dictionary) -> void:
	research.install_snapshot(raw,db.data.ai_tech_tree)
	for field in ["productionElapsed", "hightechSavedAt"]:
		if nonnegative_number(raw.get(field)):profile[field] = float(raw[field])
	if raw.get("resourceSamples") is Array:
		for sample in raw.resourceSamples:
			if sample is Dictionary and nonnegative_number(sample.get("time")) and N.valid(sample.get("amount")) and str(sample.get("id", "")) in ["1", "2", "jewel"] and float(sample.time) <= float(profile.hightechSavedAt) and (float(sample.time) > float(profile.hightechSavedAt) - 60.0 or (nonnegative_number(sample.get("production_time")) and float(sample.production_time)<=production_time() and float(sample.production_time)>production_time()-60.0)):
				# Legacy samples have no reliable source; keep totals but exclude them
				# from furnace input until this short rolling window expires.
				var restored := {"time":float(sample.time), "amount":sample.amount, "production_base":sample.get("production_base",sample.amount), "id":str(sample.id), "origin":str(sample.get("origin", "unknown"))}
				if nonnegative_number(sample.get("production_time")) and float(sample.production_time)<=production_time():restored.production_time=float(sample.production_time)
				resource_samples.append(restored)

func read_ai_tech_completion() -> bool:
	if not research.read_completion():return false
	save_dirty = true
	return true

func rebuild_unlock_gates() -> void:
	invalidate_tutorial_unlocks()
	profile.highestLevel = 1
	for n in profile.cleared:
		profile.highestLevel = mini(db.levels.size(), maxi(profile.highestLevel, int(n) + 1))
	profile.lifetime_max_stage = maxi(int(profile.get("lifetime_max_stage",1)),int(profile.highestLevel))
	profile.grantedUnlocks = granted_unlocks()
	for key in EQUIPMENT:
		if content_unlocked("equipment", key) and not profile.unlocked.has(key):
			profile.unlocked.append(key)

func rebuild_unlocks() -> void:
	rebuild_unlock_gates()
	ensure_loadout()
	profile.hightechOrder = hightech_slots()
	event.emit("unlocks_changed",{})

func ensure_loadout() -> void:
	refresh_unlock_revision()
	equipment.reconcile(db,profile.unlocked,first_ship(),ship_unlocked(equipment.selected_ship()))
	configuration_committed()

func save_clock_seconds() -> float:
	# Monotonic elapsed time, independent of game speed, pause and wall-clock edits.
	return float(Time.get_ticks_msec()) / 1000.0

func reset_save_timer() -> void:
	next_timed_save_at = save_clock_seconds() + float(save_interval_minutes) * 60.0

static func parse_save_interval(text: String) -> int:
	var value := text.strip_edges()
	if not value.is_valid_int():return 0
	while value.length() > 1 and value.begins_with("0"):value = value.substr(1)
	if value.length() > 19 or (value.length() == 19 and value > "9223372036854775807"):return 0
	var minutes := value.to_int()
	return minutes if minutes > 0 and str(minutes) == value else 0

func set_save_interval(text: String) -> bool:
	var minutes := parse_save_interval(text)
	if minutes <= 0:return false
	if save_interval_minutes != minutes:
		save_interval_minutes = minutes
		save_dirty = true
		reset_save_timer()
	return true

func check_timed_save() -> void:
	if not save_enabled or save_clock_seconds() < next_timed_save_at:return
	# Schedule from now before trying. Never replay missed periods or retry failure
	# every frame. Manual saves leave this periodic deadline unchanged.
	reset_save_timer()
	save_progress()

func save_progress() -> void:
	# Called only by the real-time deadline or explicit manual save.
	if not save_enabled:return
	save_dirty = true
	var saved := _build_save_data()
	last_save_error = progress_writer.write_progress(JSON.stringify(saved, "\t").to_utf8_buffer())
	if last_save_error != OK:
		event.emit("save_error", {"error":last_save_error})
		return
	save_dirty = false
	last_successful_save_at = float(saved.hightechSavedAt)
	event.emit("save_success", {"at":last_successful_save_at})

func _build_save_data() -> Dictionary:
	prune_resource_samples(Time.get_unix_time_from_system())
	return portable_save_data()

func portable_save_data() -> Dictionary:
	# Export and import backup must leave unsaved runtime progress unchanged.
	var saved := profile.duplicate(true)
	var now := Time.get_unix_time_from_system()
	saved.hightechOrder = hightech_slots()
	saved.hightechSavedAt = now
	saved.resourceSamples = resource_samples.filter(func(sample):return float(sample.time)>now-60.0 or (sample.has("production_time") and float(sample.production_time)>production_time()-60.0)).duplicate(true)
	saved.chronoSavedAt = now
	saved.hightechDrops = drops.filter(func(drop):return drop.get("hightech", false)).duplicate(true)
	return _compose_save_data(saved)

func _compose_save_data(saved: Dictionary) -> Dictionary:
	for retired in ["scientists","scientistAssignments","techPoints","hightechLevels","hightechOrder","hightechDrops"]:saved.erase(retired)
	saved.merge(economy.save_data(), true)
	saved.merge(research.save_data(), true)
	saved.merge(equipment.save_data(), true)
	saved.merge(enhancement_growth.save_data(), true)
	saved.merge(reactor.save_data(), true)
	saved.merge(crew.save_data(), true)
	saved.merge(planets.save_data(), true)
	saved.merge(hyperspace.save_data(),true)
	saved.saveIntervalMinutes = str(save_interval_minutes)
	saved.merge(galaxy.save_data(),true)
	saved.grantedUnlocks = granted_unlocks()
	if state in [State.TRAVEL, State.COMBAT, State.LEVEL_CLEAR, State.RETREAT]:
		# Retreat resumes at its destination, never at the defeated encounter.
		saved.journey = {"stage":stage, "distance":retreat_target if state == State.RETREAT else distance, "groupIndex":group_index, "state":int(state), "guardArrived":guard_arrived, "retreatBossPending":retreat_boss_pending}
		saved.journey.pendingUnlocks = pending_unlocks.duplicate()
	if manual_hyperspace.active:
		saved.erase("journey");saved.loop=manual_hyperspace.return_target.loop
	saved.jewels = [] # Retired field stays empty for old save readers.
	saved.levels = {}
	for key in EQUIPMENT:
		saved.levels[key] = int(first_equipment_entry(key).get("level", 1))
	return saved

func first_equipment_entry(key: String) -> Dictionary:
	for category in ["weapons", "defence"]:
		for entry in loadout_entries(category):
			if str(entry.get("key", "")) == key:
				return entry
	return {}

func module_entries(category: String) -> Array:
	return equipment.entries(category)

func active_slot_count(category: String, ship_key := "") -> int:
	return int(db.ship(equipment.selected_ship() if ship_key.is_empty() else ship_key).get("weaponSlots" if category=="weapons" else "defenseSlots",0)) if category in ["weapons","defence"] else 0

func module_entry(category: String, index: int) -> Dictionary:
	var entries := module_entries(category)
	return entries[index] if index>=0 and index<entries.size() else {}

func loadout_entries(category: String) -> Array:
	# Immutable active view; stable source identities survive numeric upgrades.
	return equipment.entries(category,true)

func module_cost_key(category: String) -> String:
	# Current same-category cost curves are identical; modules retain that existing curve.
	return EquipmentState.cost_key(category)


func weapon_entries() -> Array:
	return loadout_entries("weapons")

func combat_weapon_entries() -> Array:
	return attributes.combat_weapon_entries(self)

func drone_weapon_entry(d: Dictionary, weapon_levels:Dictionary={}) -> Dictionary:
	return attributes.drone_weapon_entry(self,d,weapon_levels)

func projected_combat_entry(index:int,weapon_levels:Dictionary={}) -> Dictionary:
	var entry:Dictionary=combat_entry(index)
	if entry.has("drone_id"):
		return drone_weapon_entry(hyperspace.state.inventory.drones[entry.drone_id],weapon_levels)
	if weapon_levels.has(index):
		entry=entry.duplicate();entry.level=int(weapon_levels[index])
	return entry

func combat_entry(index: int) -> Dictionary:
	var entries:=combat_weapon_entries()
	return entries[index] if index>=0 and index<entries.size() else {}

func defense_entries() -> Array:
	return loadout_entries("defence")

func stat(key: String) -> Variant:
	return attributes.stat(self,key)

func enable_compiled_combat_rules()->void:
	assert(compiled_combat_rules==null)
	compiled_combat_rules=preload("res://scripts/compiled_combat_rules.gd").new()
	compiled_combat_rules.compile(self)
func combat_equipment_row(key:String,level:int)->Dictionary:
	if compiled_combat_rules!=null and not compiled_combat_rules.compiling:
		compiled_combat_rules.compile(self)
		var row:Dictionary=compiled_combat_rules.row(key,level)
		if not row.is_empty():return row
	return db.equip(key,level)
func _configuration_event(kind:String,_info:Dictionary)->void:
	if kind in ["configuration_changed","progress_loaded"]:invalidate_tutorial_unlocks()
func notify_configuration_changed()->void:
	if not native_before_configuration_change():return
	configuration_revision+=1;refresh_unlock_revision();configuration_committed();event.emit("configuration_changed",{})
func enhancement_recipe(entry:Dictionary)->Array:
	if compiled_combat_rules!=null and not compiled_combat_rules.compiling:
		compiled_combat_rules.compile(self)
		return compiled_combat_rules.effects(entry)
	return enhancement_effects(entry)
func enhancement_branch_active(entry:Dictionary,effect:String,node:int,choice:String)->bool:
	if compiled_combat_rules!=null and not compiled_combat_rules.compiling:
		compiled_combat_rules.compile(self)
		return compiled_combat_rules.active(entry,effect,node,choice)
	var category="weapons" if effect in ["proficiency","repeat","critical"] else "defence"
	return not entry.is_empty() and enhancement_branch_choice(category,effect,node)==choice and enhancement_branch_unlocked(category,effect,node) and has_enhancement_effect(entry,effect)

func configuration_committed(native_updated:=false) -> void:
	var inputs:=attributes.configuration_inputs(self)
	if inputs==_committed_configuration:return
	_committed_configuration=inputs
	if native_execution!=null and not native_updated:native_execution.configuration_changed()
	if compiled_combat_rules!=null:compiled_combat_rules.compile(self)

func refresh_unlock_revision()->void:
	var inputs:Array=[profile.highestLevel,profile.cleared.duplicate(),profile.get("grantedUnlocks",[]).duplicate(),profile.unlocked.duplicate()]
	if inputs!=_unlock_inputs:_unlock_inputs=inputs;unlock_revision+=1

func ship_movement() -> float:
	return float(db.ship(equipment.selected_ship()).get("movement", db.config.movement))

func travel_movement() -> float:
	var groups: Array = db.levels[stage-1].groups
	if group_index >= groups.size():return ship_movement()
	var destination := float(groups[group_index].position)*float(db.levels[stage-1].length)
	var origin := distance if is_inf(travel_origin) else travel_origin
	return maxf(ship_movement(),maxf(0.0,destination-origin)/MAX_TRAVEL_SECONDS)

func ship_name() -> String:
	return UIText.data_text("ship",equipment.selected_ship(),"des")

func slot_entry(category: String, index: int) -> Dictionary:
	var entries := loadout_entries(category)
	return entries[index] if index >= 0 and index < entries.size() else {}

func slot_id(category: String, index: int) -> String:
	if category=="weapons" and index>=weapon_entries().size():
		return "drone:"+str(combat_entry(index).get("drone_id","invalid"))
	return "%s_%d" % [category, index]

func first_weapon_index(key: String) -> int:
	for index in range(weapon_entries().size()):
		if str(weapon_entries()[index].key) == key:
			return index
	return -1

func slot_upgrade_cost(category: String, index: int, levels := 1) -> Dictionary:
	var entry := slot_entry(category, index)
	return {} if entry.is_empty() else upgrade_costs_for_level(module_cost_key(category), int(entry.level), levels)

func upgrade_costs_for_level(key: String, current: int, levels: int) -> Dictionary:
	return equipment.costs(db,key,current,levels)

func can_upgrade_slot(category: String, index: int, levels := 1) -> bool:
	var entry := slot_entry(category, index)
	if entry.is_empty() or levels<1:
		return false
	var costs := slot_upgrade_cost(category, index, levels)
	return can_afford_upgrade_costs(costs)

func upgrade_currency(id: String) -> Variant:
	return economy.balance(id)

func can_afford_upgrade_costs(costs: Dictionary) -> bool:
	if costs.is_empty():
		return false
	for id in costs:
		if id==db.evolution_material_id() and not hyperspace.is_unlocked(self):return false
		if not is_finite(float(costs[id])) or N.compare(upgrade_currency(id),costs[id])<0:
			return false
	return economy.can_pay(costs)

func resources_changed(ids: Array) -> void:
	event.emit("resources_changed",{"ids":ids})

func equipment_limit() -> int:
	return maxi(active_slot_count("weapons"),active_slot_count("defence")) # Compatibility: only physical capacity remains.

func equipment_count(key: String) -> int:
	var count := 0
	for category in ["weapons", "defence"]:
		for entry in loadout_entries(category):
			if str(entry.get("key", "")) == key:
				count += 1
	return count

func valid_loadout(key: String, loadout: Dictionary) -> bool:
	if not ship_unlocked(key):
		return false
	var row := db.ship(key)
	var counts := {}
	for category in ["weapons", "defence"]:
		var allowed: Array = WEAPON_KEYS if category == "weapons" else DEFENSE_KEYS
		var expected := int(row.get("weaponSlots", 0)) if category == "weapons" else int(row.get("defenseSlots", 0))
		var entries = loadout.get(category, [])
		if not entries is Array or entries.size() != expected:
			return false
		for entry in entries:
			if not entry is Dictionary:
				return false
			var equip_key := str(entry.get("key", ""))
			if equip_key.is_empty():
				continue
			if not allowed.has(equip_key) or not profile.unlocked.has(equip_key):
				return false
			counts[equip_key] = int(counts.get(equip_key, 0)) + 1
	return true

func capture_refit_health() -> void:
	for key in ["armour","shield"]:
		var maximum = stat(key)
		if N.compare(maximum,0)>0 and player.has(key):
			refit_health_ratios[key] = clampf(N.ratio(player[key],maximum),0,1)

func apply_refit_health() -> void:
	for key in ["armour","shield"]:
		if player.has(key):player[key] = N.multiply(stat(key),float(refit_health_ratios[key]))
	jewel_defence_damage.clear()
	sync_jewel_defence_damage()
	sync_enhancement_buffers()
	enhancement_branches.reconcile(self)
	if state in [State.TRAVEL,State.COMBAT,State.LEVEL_CLEAR] and not player_alive():
		begin_retreat()
		event.emit("battle_blocked",{"reason":"zero_defence"})

func invalidate_module_attack(index: int) -> void:
	# This invalidates a physical module, including dormant slots after a hull change.
	var module_id := "weapons_%d" % index
	jewel_repeats = jewel_repeats.filter(func(p):return int(p.index)!=index)
	jewel_charged.erase(module_id)
	for shot in projectiles:
		if shot.get("beam",false) and not shot.hostile and int(shot.mount)==index:shot.dead=true
	var entry := slot_entry("weapons",index)
	if entry.is_empty() or str(entry.key).is_empty():
		cooldowns.erase(module_id)
	else:
		var cd := float(db.equip(str(entry.key),int(entry.level)).cd)
		# Loadout edits while travelling keep the upcoming encounter's quick salvo.
		if state == State.TRAVEL and str(entry.key) == "missile":
			cd = minf(cd,0.4)
		cooldowns[module_id] = cd

func player_alive() -> bool:
	return N.compare(player.get("armour",0),0)>0 or N.compare(player.get("shield",0),0)>0

func equipment_switch_remaining(category: String, index: int) -> float:
	return equipment.switch_remaining(category,index,production_time())

func slot_equipment_locked(category: String, index: int) -> bool:
	return equipment_switch_remaining(category,index)>0.0

func equip_slot(category: String, index: int, key: String) -> bool:
	if category not in ["weapons","defence"] or slot_entry(category,index).is_empty():return false
	if key not in (WEAPON_KEYS if category=="weapons" else DEFENSE_KEYS) or not profile.unlocked.has(key):return false
	if str(slot_entry(category,index).key)==key:return true
	return commit_loadout_change(equipment.selected_ship(),{category:{index:key}},false)

func unequip_slot(category: String, index: int) -> bool:
	var entry := slot_entry(category,index)
	if entry.is_empty() or str(entry.key).is_empty():return false
	return commit_loadout_change(equipment.selected_ship(),{category:{index:""}},false)

func switch_ship(key: String, selected_loadout: Dictionary = {}) -> bool:
	if key==equipment.selected_ship() or not ship_unlocked(key):return false
	if not selected_loadout.is_empty() and not valid_loadout(key,selected_loadout):return false
	var choices:Dictionary={}
	for category in selected_loadout:
		choices[category]={}
		for index in selected_loadout[category].size():choices[category][index]=str(selected_loadout[category][index].key)
	return commit_loadout_change(key,choices,true)

func commit_loadout_change(ship: String, choices: Dictionary, hull_change: bool) -> bool:
	var plan := equipment.prepare_refit(db,ship,choices,production_time(),float(db.config.equipmentSwitchCooldownSeconds))
	if plan.is_empty():return false
	var drone_plan := hyperspace.prepare_hull_fit(self,ship)
	var requested: Array=plan.modules.weapons.slice(0,active_slot_count("weapons",ship))
	if not hyperspace.equipment_constraints(self,drone_plan.state.inventory.equipped,drone_plan.state.inventory,requested):return false
	if not native_before_configuration_change():return false
	if not equipment.proposal_current(plan) or not hyperspace.hull_fit_current(self,drone_plan):return false
	capture_refit_health()
	var old_weapon_count := active_slot_count("weapons")
	var previous_capacity=reactor_capacity()
	# Both proposals are complete. No callbacks between the two installations.
	equipment.commit_refit(db,plan)
	hyperspace.commit_hull_fit(self,drone_plan)
	configuration_committed()
	var capacity=reactor_capacity()
	reactor.reconcile_capacity(capacity)
	for changed in plan.changed:
		if changed.category=="weapons":invalidate_module_attack(int(changed.index))
	for index in range(mini(old_weapon_count,active_slot_count("weapons")),maxi(old_weapon_count,active_slot_count("weapons"))):invalidate_module_attack(index)
	apply_refit_health()
	save_dirty=true
	if capacity!=previous_capacity:event.emit("reactor_changed",{"capacity":capacity})
	if drone_plan.changed:event.emit("hyperspace_changed",{"reason":"hull_capacity_changed","round_id":hyperspace.state.round_id})
	if hull_change:event.emit("ship_changed",{"key":ship})
	else:
		for changed in plan.changed:event.emit("module_changed",{"slot":slot_id(changed.category,int(changed.index))})
	return true

func permanent_modifiers() -> Dictionary:
	return attributes.permanent_modifiers(self)

func hyperspace_totals() -> Dictionary:
	return attributes.hyperspace_totals(self)

func equipment_level_bonus() -> int:
	return int(permanent_modifiers().equipment_level_bonus)

func charge_free_ratio() -> float:
	return float(permanent_modifiers().charge_free_ratio)

func gem_drop_level_bonus() -> int:
	return int(permanent_modifiers().gem_drop_level_bonus)

func effective_equipment_level(actual: int) -> int:
	return actual+equipment_level_bonus()

func effective_hightech_level(key: String) -> int:
	return hightech_level(key) if hightech_unlocked(key) else 0

func permanent_level_text(actual: int, target: String) -> String:
	var bonus := equipment_level_bonus() if target=="equipment" else 0
	return UIText.t("planet.level_with_bonus",{"actual":actual,"bonus":bonus}) if bonus!=0 else str(actual)

func permanent_level_tooltip(actual: int, target: String) -> String:
	var bonus := equipment_level_bonus() if target=="equipment" else 0
	return UIText.t("planet.level_tooltip",{"actual":actual,"bonus":bonus,"effective":actual+bonus}) if bonus!=0 else ""

func equipment_stat(key: String, level: int, galaxy_charge := -1.0) -> Variant:
	return attributes.equipment_stat(self,key,level,galaxy_charge)

func reactor_modules() -> PackedStringArray:
	return str(db.config.reactorModules).split(",",false)

func reactor_module_unlocked(key: String) -> bool:
	if not reactor_modules().has(key):return false
	var gate := db.unlock_id("reactor_module",key)
	return gate.is_empty() or unlock_available(gate)

func reactor_available_modules() -> PackedStringArray:
	return PackedStringArray(Array(reactor_modules()).filter(func(key):return reactor_module_unlocked(key)))

func reactor_unlocked() -> bool:
	return content_unlocked("feature", "reactor")

func reactor_contributions(galaxy_charge := -1.0) -> Array:
	return attributes.reactor_contributions(self,galaxy_charge)

func reactor_energy(level := -1, galaxy_charge := -1.0) -> Variant:
	return attributes.reactor_energy(self,level,galaxy_charge)

func reactor_capacity(galaxy_charge := -1.0) -> Variant:
	return attributes.reactor_capacity(self,galaxy_charge)

func reactor_upgrade_cost(level := -1) -> Variant:
	return reactor.upgrade_cost(db.config, level)

func reactor_allocated() -> Variant:
	return reactor.allocated()

func reactor_effective_ratio(key: String) -> Variant:
	return attributes.reactor_effective_ratio(self,key)

func reactor_multiplier(key: String, galaxy_charge := -1.0) -> Variant:
	return attributes.reactor_multiplier(self,key,galaxy_charge)

func reactor_max_upgrades() -> int:
	return reactor.max_upgrades(economy.balance(str(int(db.config.reactorUraniumId))), db.config)

func upgrade_reactor(amount: int) -> bool:
	if not reactor_unlocked():return false
	var id := str(int(db.config.reactorUraniumId))
	var quote := reactor.purchase_quote(amount, economy.balance(id), db.config)
	if quote.is_empty():return false
	if not native_before_configuration_change():return false
	if not reactor.purchase_matches(quote):return false
	if not economy.debit({id:quote.cost}):return false
	# No callbacks or fallible work between the two authoritative commits.
	reactor.commit_purchase(quote)
	configuration_committed()
	save_dirty = true
	resources_changed([id])
	event.emit("reactor_changed", {"level":reactor.level(),"cost":quote.cost})
	return true

func set_reactor_allocation(key: String, value: Variant) -> bool:
	if not reactor_unlocked() or not reactor_module_unlocked(key):return false
	var next := reactor.allocation_proposal(key, value, reactor_capacity())
	if next.is_empty():return false
	if not native_before_configuration_change():return false
	reactor.commit_allocation(next)
	configuration_committed()
	if key == "defence":
		player.armour = N.minimum(player.armour,stat("armour"))
		player.shield = N.minimum(player.shield,stat("shield"))
	save_dirty = true
	if key in ["defence", "weapons"]:event.emit("equipment_stats",{"category":key})
	event.emit("reactor_changed", {"module":key})
	return true

func equalize_reactor_allocation() -> bool:
	if not reactor_unlocked():return false
	var next := reactor.equal_allocation(reactor_available_modules(), reactor_capacity())
	if next.is_empty():return false
	if not native_before_configuration_change():return false
	reactor.commit_allocation(next)
	configuration_committed()
	player.armour = N.minimum(player.armour,stat("armour"))
	player.shield = N.minimum(player.shield,stat("shield"))
	save_dirty = true
	event.emit("equipment_stats",{"category":"weapons"})
	event.emit("equipment_stats",{"category":"defence"})
	event.emit("reactor_changed", {"equalized":true})
	return true

func hightech_level(key: String) -> int:
	return research.level(self,key)

func hightech_unlocked(key: String) -> bool:
	if db.data.get("hightech", {}).has(key):return content_unlocked("hightech",key)
	return bool(research.eligibility(self,key).ok)

func ai_tech_factory_unlocked() -> bool:
	return content_unlocked("hightech",FURNACE)

func tech_tree_snapshot() -> Dictionary:
	return research.snapshot(self)

func select_tech(id: String) -> bool:
	if not research.select(self,id):return false
	save_dirty = true
	event.emit("tech_tree_changed",{"reason":"selection","id":id})
	return true

func set_tech_input(resource_id: String, amount: int) -> bool:
	if not research.set_input(self,resource_id,amount):return false
	save_dirty = true
	event.emit("tech_tree_changed",{"reason":"input","resource":resource_id})
	return true

func hightech_slots() -> Array:
	var unlocked: Array = db.data.get("hightech", {}).keys().filter(func(key):return hightech_unlocked(key))
	# Keep an empty slot available and grow by complete visible pages.
	var count := maxi(HIGHTECH_MIN_SLOTS, int(ceilf(float(unlocked.size()+1)/HIGHTECH_SLOTS_PER_PAGE))*HIGHTECH_SLOTS_PER_PAGE)
	var slots: Array = []
	slots.resize(count)
	slots.fill("")
	var stored: Array = profile.get("hightechOrder", [])
	for i in range(mini(stored.size(),count)):
		if unlocked.has(stored[i]) and not slots.has(stored[i]):
			slots[i] = stored[i]
	# New unlocks fill vacancies without shifting the player's existing cards.
	for key in unlocked:
		if not slots.has(key):
			slots[slots.find("")] = key
	return slots

func swap_hightech_slots(source: int, target: int) -> bool:
	var slots := hightech_slots()
	if source < 0 or target < 0 or source >= slots.size() or target >= slots.size() or source == target or slots[source] == "":
		return false
	var key = slots[source]
	slots[source] = slots[target]
	slots[target] = key
	profile.hightechOrder = slots
	save_dirty = true
	return true

func hightech_required(key: String) -> float:
	var row: Dictionary = db.data.hightech[key]
	var level := hightech_level(key)
	var cost := float(row.tpCostBase) * (1.0 + float(row.tpCostMutiple) * level)
	var threshold := int(db.config.hightechCostGrowthLevel)
	if level > threshold:
		cost *= pow(1.0 + float(row.tpCostMutiple2), level - threshold)
	return roundf(cost)

func description_number(value) -> String:
	if value is Dictionary:return N.text(value)
	# Formula literals must retain float precision; compact notation is for the final text only.
	return "%.1f" % value if absf(value)>=9e18 else NUMBER_FORMAT.precise(value)

func hightech_description(key: String, now := -1.0) -> String:
	if effective_hightech_level(key)==0:
		return UIText.t("system.hightech_description.text_01")
	var row: Dictionary = db.data.hightech[key]
	if key == JEWEL_FURNACE:
		var peak := furnace_income_peak(now,true)
		return ui_description(UIText.data_key("hightech",key,"description"),row,effective_hightech_level(key),peak,peak)
	return ui_description(UIText.data_key("hightech",key,"description"),row,effective_hightech_level(key),furnace_income_peak(now) if key==FURNACE else resource_minute_total("1",now),furnace_income_peak(now) if key==FURNACE else resource_minute_total("1",now,true))

func ui_description(text_key: String, row: Dictionary, level: int, minute_income = 0.0, excluded_income = 0.0) -> String:
	var values := {}
	var formulas := UIText.formulas(text_key)
	for i in formulas.size():
		values["effect_%d" % (i+1)] = format_description(row,str(formulas[i]),level,minute_income,excluded_income)
	return UIText.t(text_key,values)

func format_description(row: Dictionary, template: String, level: int, minute_income = 0.0, excluded_income = 0.0) -> String:
	var result := template
	var tokens := RegEx.new()
	tokens.compile("para[0-9]+")
	var braces := RegEx.new()
	braces.compile("\\{([^{}]+)\\}")
	var matches := braces.search_all(result)
	matches.reverse()
	var allowed := RegEx.new()
	allowed.compile("^[0-9. +*/()^\\-]+$")
	var numbers := RegEx.new()
	var numeric_literal := "(?:[0-9]+(?:\\.[0-9]*)?|\\.[0-9]+)(?:[eE][+-]?[0-9]+)?"
	numbers.compile(numeric_literal)
	for block in matches:
		var parts := block.get_string(1).replace("，",",").split(",")
		var options: Array = Array(parts).slice(1).map(func(option):return str(option).strip_edges())
		var formula := str(parts[0])
		var formula_tokens := tokens.search_all(formula)
		formula_tokens.reverse()
		for token in formula_tokens:
			var token_value = row.get(token.get_string())
			var token_replacement := description_number(float(token_value)) if nonnegative_number(token_value) else "？"
			formula = formula.substr(0,token.get_start()) + token_replacement + formula.substr(token.get_end())
		for income_token in ["过去一分钟的铁生成量","过去一分钟的宝石碎片生成量"]:
			formula = formula.replace(income_token,description_number(excluded_income if options.has("不含自身") else minute_income))
		formula = formula.replace("等级",str(level)).replace("lv",str(level)).replace("（","(").replace("）",")")
		var replacement := "？"
		var expression := Expression.new()
		# Expression otherwise uses integer division for literals such as 1/2.
		var literals := numbers.search_all(formula)
		literals.reverse()
		for literal in literals:
			if not literal.get_string().contains(".") and not literal.get_string().to_lower().contains("e"):
				formula = formula.substr(0,literal.get_end()) + ".0" + formula.substr(literal.get_end())
		# Remove complete numeric tokens before checking operators; arbitrary identifiers remain rejected.
		var numeric_only := allowed.search(numbers.sub(formula,"0",true)) != null
		var power := RegEx.new()
		power.compile("(\\([^()^]*\\)|"+numeric_literal+")\\s*\\^\\s*("+numeric_literal+")")
		formula = power.sub(formula,"pow($1,$2)",true)
		if numeric_only and not formula.contains("^") and options.all(func(option):return option in ["向上取整","不含自身","百分比显示","保留两位小数","即100.3%展示为100%","百分比","四舍五入保留整数百分比部分"]) and expression.parse(formula) == OK:
			var value = expression.execute([],null,false,true)
			if not expression.has_execute_failed() and (value is int or value is float) and is_finite(float(value)):
				if options.has("百分比显示") or options.has("百分比"):
					var percent := float(value) * 100.0
					if options.has("四舍五入保留整数百分比部分"):
						replacement = (NUMBER_FORMAT.precise(roundf(percent)) if percent < 1000.0 else NUMBER_FORMAT.compact(roundf(percent))) + "%"
					elif options.has("即100.3%展示为100%"):
						replacement = NUMBER_FORMAT.compact(floorf(percent + 0.00000001)) + "%"
					elif options.has("保留两位小数") and percent < 1000.0:
						replacement = "%.2f%%" % percent
					else:
						replacement = NUMBER_FORMAT.compact(percent) + "%"
				else:
					replacement = NUMBER_FORMAT.compact(ceilf(float(value)) if options.has("向上取整") else float(value))
		result = result.substr(0,block.get_start()) + replacement + result.substr(block.get_end())
	var remaining_tokens := tokens.search_all(result)
	remaining_tokens.reverse()
	for token in remaining_tokens:
		var token_value = row.get(token.get_string())
		var token_replacement := NUMBER_FORMAT.compact(float(token_value)) if nonnegative_number(token_value) else "？"
		result = result.substr(0,token.get_start()) + token_replacement + result.substr(token.get_end())
	return result

func scientist_cost(_offset := 0) -> Dictionary:
	return {}

func scientist_purchase(_amount := 1) -> Dictionary:
	return {"count":0,"costs":{}}

func can_generate_scientist(_amount := 1) -> bool:
	return false

func generate_scientist(_amount := 1) -> bool:
	return false

func distribute_scientists() -> bool:
	return false

func assigned_scientists(_key: String) -> int:
	return 0

func idle_scientists() -> int:
	return 0

func can_research(key: String) -> bool:
	return bool(research.eligibility(self,key).ok)

func assign_scientist(_key: String, _delta: int) -> bool:
	return false
func add_crew_exp(crew_id: String, amount: float) -> bool:
	if not crew.levels_unlocked(self) or not crew.unlocked(self,crew_id):return false
	var plan:=crew.prepare_experience(self,{crew_id:amount})
	if not prepare_crew_commit(plan):return false
	crew.commit(plan);notify_crew_changes(plan.changes)
	return true

func prepare_crew_commit(plan: Dictionary) -> bool:
	if not crew.proposal_current(plan):return false
	if plan.configuration and not native_before_configuration_change():return false
	if not crew.proposal_current(plan):return false
	capture_refit_health()
	return true

func notify_crew_changes(changes: Array) -> void:
	if changes.is_empty():return
	refresh_crew_level_effects(changes)
	save_dirty=true
	for change in changes:event.emit("crew_changed",{"crewId":change.current.crewId,"previous":change.previous,"current":change.current})

func planet_row(id: String) -> Dictionary:
	return db.data.get("planet", {}).get(id, {})

func planet_unlocked(id: String) -> bool:
	var row := planet_row(id)
	return not row.is_empty() and planet_buffs.allows_planet(self, id) and unlock_available(str(row.get("unlockId", "")))

func planet_progress(id: String) -> Dictionary:
	return planets.progress(id)

func crew_exploration(crew_id: String) -> String:
	return planet_buildings.occupied(self,crew_id)

func planet_duration(id: String) -> float:
	return PlanetState.duration(planet_row(id), planet_progress(id).get("degree", 0))

func planet_exp_multiplier() -> float:
	return PlanetState.experience_multiplier(db,int(profile.get("lifetime_max_stage",1)),int(profile.highestLevel))

func planet_exp_reward(id: String) -> float:
	return PlanetState.experience_reward(db,id,crew.levels_unlocked(self),int(profile.get("lifetime_max_stage",1)),int(profile.highestLevel),galaxy.multiplier("crew_exp"))

func planet_equipment_multiplier() -> Variant:
	return attributes.planet_equipment_multiplier(self)

func planet_resource_multiplier() -> Variant:
	return attributes.planet_resource_multiplier(self)

func idle_planet_crew(id: String) -> bool:
	var member := crew.entry(self,id)
	return not member.is_empty() and crew.unlocked(self,id) and str(member.assignmentType).is_empty() and crew_exploration(id).is_empty() and preload("res://scripts/hyperspace_permissions.gd").reserved_crew(hyperspace.state)!=id

func commit_planet_command(plan: Dictionary,payload: Dictionary) -> bool:
	if not planets.proposal_current(plan):return false
	if plan.configuration and not native_before_configuration_change():return false
	if not planets.proposal_current(plan):return false
	planets.commit(plan)
	if plan.configuration:invalidate_tutorial_unlocks();configuration_committed()
	save_dirty=true;event.emit("planet_changed",payload)
	return true

func set_planet_auto(id: String, enabled: bool) -> bool:
	return commit_planet_command(planets.prepare_auto(self,id,enabled),{"id":id})

func activate_planet_building(id: String, building_id: String) -> bool:
	return commit_planet_command(planets.prepare_activation(self,id,building_id),{"id":id,"activated":building_id})

func assign_planet_builder(id: String, building_id: String, crew_id: String) -> bool:
	return commit_planet_command(planets.prepare_builder(self,id,building_id,crew_id),{"id":id})

func can_reforge_planet(id: String) -> bool:
	if manual_hyperspace.active:return false
	return planet_unlocked(id) and not planet_progress(id).get("conquered",false) and planet_buildings.built(self,id,"shipyard")

func planet_reforge_start(id: String) -> int:
	return PlanetState.reforge_start(db,id)

func reforge_planet(id: String,keep_drones: Array=[],claim_stages: Dictionary={}) -> bool:
	if not can_reforge_planet(id):return false
	if not native_before_configuration_change():return false
	var planet_plan:=planets.prepare_conquest(self,id)
	if planet_plan.is_empty():return false
	var hyperspace_plan:=hyperspace.prepare_reforge(self,keep_drones,claim_stages)
	if hyperspace_plan.is_empty():return false
	var start_level := planet_reforge_start(id)
	# Prepare the complete replacement before changing any authoritative state.
	var next := fresh_profile()
	next.grantedUnlocks = []
	next.seenUnlocks = profile.get("seenUnlocks",[]).duplicate()
	next.readUnlocks = profile.get("readUnlocks",[]).duplicate()
	if hyperspace.is_unlocked(self) and not next.seenUnlocks.has("hyperspace"):
		next.seenUnlocks.append("hyperspace")
	for gate_id in available_unlocks():
		var gate: Dictionary = db.data.unlock[gate_id]
		if not next.seenUnlocks.has(gate_id):next.seenUnlocks.append(gate_id)
		if int(gate.level)<=start_level or gate.type in ["crew","planet"] or (gate.type=="feature" and gate.target in ["crew_level","galaxy"]):next.grantedUnlocks.append(gate_id)
	for gate_id in granted_unlocks():
		if db.data.unlock[gate_id].type == "planet" and not next.grantedUnlocks.has(gate_id):next.grantedUnlocks.append(gate_id)
	# Skip earlier stages without granting combat income. Existing unlock rules
	# derive their availability from this new run's progression as usual.
	next.cleared = range(1,start_level)
	next.bossSeen = next.cleared.duplicate()
	next.lifetime_max_stage=maxi(int(profile.get("lifetime_max_stage",1)),int(profile.highestLevel))
	# Ordinary reserves survive reforge; only run fragments/reactor reset.
	next.productionElapsed=production_time()
	profile=next
	hyperspace.commit(hyperspace_plan)
	planets.commit(planet_plan)
	reset_equipment()
	enhancement_growth.reset()
	research.reset()
	economy.reset_run_fragments()
	var empty_wallet := economy.material_wallet()
	for material in empty_wallet.materials:empty_wallet.materials[material]=0
	empty_wallet.ultimate_cores=0
	economy.install_material_wallet(empty_wallet)
	reactor.reset(db.config)
	invalidate_tutorial_unlocks()
	manual_hyperspace.cancel_queue(self,"round_changed")
	hyperspace_runtime.reset()
	crew.reset_schedule(self)
	pending_unlocks.clear()
	resource_samples.clear()
	drops.clear()
	projectiles.clear()
	enemies.clear()
	speed=default_speed()
	auto_gen_elapsed=0.0
	resource_prune_elapsed=0.0
	game_time_remainder=0.0;departure_remaining=0.0
	rebuild_unlocks()
	reset_player()
	var persist := save_enabled
	save_enabled=false
	start(start_level,false)
	save_enabled=persist
	save_dirty = true
	event.emit("planet_reforged",{"id":id})
	return true

func start_planet_exploration(id: String, crew_id: String) -> bool:
	return commit_planet_command(planets.prepare_start(self,id,crew_id),{"id":id,"crewId":crew_id})

func cancel_planet_exploration(id: String) -> bool:
	return commit_planet_command(planets.prepare_cancel(id),{"id":id})

func advance_planets(dt: float) -> void:
	if dt<=0 or not is_finite(dt):return
	for id in planets.all():
		var planet_plan:=planets.prepare_step(self,str(id),dt)
		if planet_plan.is_empty():continue
		if not planet_plan.completed:
			planets.commit(planet_plan);continue
		var reward:=planet_exp_reward(str(id));var rewards: Dictionary={}
		if reward>0:
			if planet_buffs.shares_experience(self,str(id)):
				for member in crew.members():rewards[member.crewId]=reward
			else:rewards[planet_plan.crew_id]=reward
		var crew_plan:=crew.prepare_experience(self,rewards)
		if not crew.proposal_current(crew_plan):return
		if (planet_plan.configuration or crew_plan.configuration) and not native_before_configuration_change():return
		if not planets.proposal_current(planet_plan) or not crew.proposal_current(crew_plan):return
		capture_refit_health()
		planets.commit(planet_plan);crew.commit(crew_plan)
		configuration_committed();save_dirty=true
		planet_crew_payout_active=true
		notify_crew_changes(crew_plan.changes)
		planet_crew_payout_active=false
		event.emit("planet_changed",{"id":id,"crewId":planet_plan.crew_id,"reward":reward})

func assign_crew(crew_id: String, assignment_type: String, target_id: String, upgrade_mode := "") -> bool:
	var plan:=crew.prepare_assignment(self,crew_id,assignment_type,target_id,upgrade_mode)
	if not prepare_crew_commit(plan):return false
	if plan.changes.is_empty():return true
	var previous: Dictionary=plan.changes[0].previous
	if plan.configuration:
		# Earned time belongs to the previous assignment and is settled before transfer.
		if previous.assignmentType=="galaxy_explore" and not galaxy_runtime.flush_pending(self,str(previous.targetId)):return false
		if assignment_type=="galaxy_explore" and not galaxy_runtime.flush_pending(self,target_id):return false
		if not crew.proposal_current(plan) or not crew.can_assign(self,crew_id,assignment_type,target_id):return false
		capture_refit_health()
	crew.commit(plan)
	var started: bool=galaxy.start(target_id) if assignment_type=="galaxy_explore" else false
	notify_crew_changes(plan.changes)
	if started:event.emit("galaxy_changed",{"key":target_id})
	return true

func set_crew_upgrade_mode(crew_id: String, mode: String, assignment := "") -> bool:
	var plan:=crew.prepare_mode(self,crew_id,mode,assignment)
	if not crew.proposal_current(plan):return false
	crew.commit(plan);notify_crew_changes(plan.changes)
	return true

func start_galaxy(key: String) -> bool:
	if not galaxy.start(key):return false
	save_dirty=true;event.emit("galaxy_changed",{"key":key})
	return true

func get_crew_modifier(target_type: String, target_id: String, effect_type: String) -> float:
	return crew.get_modifier(self,target_type,target_id,effect_type)

func dedicated_scientists(_key: String) -> int:
	return 0

func research_rate(_key: String, _crew_effects: Dictionary = {}) -> float:
	return 0.0

func active_research(_rates: Dictionary = {}) -> Array:
	return []

func record_research_income(id: String) -> void:
	var proposal := research.income_peak_proposal(self,id)
	if proposal.is_empty():return
	if proposal.affects_combat and not native_before_configuration_change():return
	if not research.commit_income_peak(proposal):return
	save_dirty = true
	if proposal.affects_combat:
		configuration_committed()
		event.emit("tech_tree_changed",{"reason":"income_peak","id":id})

func advance_hightech(dt: float, _real_dt := -1.0, _end_time := -1.0) -> void:
	var proposal := research.prepare_advance(self,dt)
	if proposal.is_empty():return
	if proposal.completed and not native_before_configuration_change():return
	if not research.proposal_current(proposal):return
	if not economy.commit_research_resources(proposal.resources,proposal.resource_revision):return
	research.commit_advance(proposal)
	save_dirty = true
	if proposal.completed:
		configuration_committed()
		event.emit("hightech_complete",{"key":proposal.id})
	elif proposal.stopped:event.emit("tech_tree_changed",{"reason":"prerequisite_stopped","id":proposal.id})
	var now_ms := Time.get_ticks_msec()
	if not proposal.paid.is_empty() and now_ms-ai_tech_last_resource_notice_ms>=250:
		ai_tech_last_resource_notice_ms=now_ms
		resources_changed(proposal.paid)

func production_time() -> float:
	return float(profile.get("productionElapsed",0.0))

func prune_resource_samples(now: float) -> void:
	# HUD receipts use real time; production inputs use X1 game time.
	var game_now := production_time()
	resource_samples = resource_samples.filter(func(sample):return float(sample.time) > now - 60.0 or (sample.has("production_time") and float(sample.production_time)>game_now-60.0))

func production_minute_total(id: String, at := -1.0) -> Variant:
	var game_now := production_time()
	if at < 0:at=game_now
	var wall_now := economy_time()
	var total = 0.0
	for sample in resource_samples:
		if sample.get("origin","drop")!="drop" or str(sample.id)!=id:continue
		# Old explicit-origin samples keep their remaining X1 window on migration.
		# Their old acceleration history is unavailable; persisted peaks are retained.
		var stamp := float(sample.get("production_time",game_now-(wall_now-float(sample.time))))
		if stamp>at-60.0 and stamp<=at:total=N.add(total,sample.get("production_base",sample.amount))
	return total

func resource_minute_total(id: String, now := -1.0, exclude_furnace := false) -> Variant:
	if now < 0:
		now = economy_time()
	var total = 0.0
	for sample in resource_samples:
		if exclude_furnace and sample.get("origin", "drop") != "drop":
			continue
		if sample.id == id and float(sample.time) > now - 60.0 and float(sample.time) <= now:
			total = N.add(total,sample.get("production_base",sample.amount) if exclude_furnace else sample.amount)
	return total

func furnace_income_peak(now := -1.0, jewel := false) -> float:
	return maxf(float(profile.get("jewelFurnaceIncomePeak" if jewel else "furnaceIncomePeak",0.0)),float(production_minute_total("jewel" if jewel else "1",now)))

func auto_gen_settings() -> Dictionary:
	var raw = db.config.get("autoGenRes", "")
	if not raw is String:
		return {}
	var parts := str(raw).replace("，", ",").split(",")
	if parts.size() != 4:
		return {}
	var interval_text := parts[0].strip_edges()
	var resource_id := parts[1].strip_edges()
	var amount_text := parts[2].strip_edges()
	var speed_text := parts[3].strip_edges()
	if not interval_text.is_valid_float() or not resource_id.is_valid_int() or not amount_text.is_valid_float() or not speed_text.is_valid_float():
		return {}
	var interval := float(interval_text)
	var amount := float(amount_text)
	var speed_value := float(speed_text)
	if interval <= 0 or amount < 0 or speed_value <= 0 or not is_finite(interval) or not is_finite(amount) or not is_finite(speed_value) or not db.data.resources.has(resource_id):
		return {}
	return {"interval":interval,"resource_id":resource_id,"amount":amount,"speed":speed_value}

func advance_auto_gen(dt: float) -> void:
	for drop in drops.duplicate():
		if not drop.get("auto_gen", false):
			continue
		drop.y += float(drop.speed) * dt
		if drop.y >= float(player.y):
			collect(drop, false)
	var settings := auto_gen_settings()
	if not is_active() or settings.is_empty():
		return
	auto_gen_elapsed += dt
	var count := floori(auto_gen_elapsed / float(settings.interval))
	if count <= 0:
		return
	auto_gen_elapsed = fposmod(auto_gen_elapsed, float(settings.interval))
	for _i in range(count):
		uid += 1
		var base_amount := ceilf(float(settings.amount) * ratio("resRatio"))
		var amount = N.ceiling(N.multiply(base_amount,1.0+float(hyperspace_totals().hangings.get("resource_collector",0))))
		drops.append({"uid":uid,"x":rng.randf_range(70.0,BATTLE_SIZE.x-70.0),"y":0.0,"age":0.0,"id":settings.resource_id,"amount":amount,"speed":settings.speed,"auto_gen":true,"production_base":base_amount})

func advance_furnace(dt: float, end_time: float, wall_per_step: float) -> void:
	for drop in drops.duplicate():
		if drop.get("hightech", false):
			drop.age += dt
			if float(drop.age) >= 10.0:
				collect(drop, false)
	for key in [FURNACE,JEWEL_FURNACE]:
		if effective_hightech_level(key) <= 0 or not db.data.get("hightech", {}).has(key):
			continue
		var jewel_furnace: bool = key == JEWEL_FURNACE
		var elapsed_field := "jewelFurnaceElapsed" if jewel_furnace else "furnaceElapsed"
		var row: Dictionary = db.data.hightech[key]
		var target_type := "smelting" if jewel_furnace else "production"
		var interval := float(row.para1) / (1.0 + crew.get_modifier(self,target_type,key,"SPEED"))
		if interval <= 0 or not is_finite(interval):
			continue
		var elapsed := float(profile.get(elapsed_field,0.0)) + dt
		var count := floorf(elapsed / interval)
		profile[elapsed_field] = fposmod(elapsed, interval)
		# Skip expired blocks, with work bounded by the 10-second visible window.
		var visible := mini(int(count), int(ceilf(10.0 / interval)))
		for i in range(visible):
			var age := float(profile[elapsed_field]) + i * interval
			if age >= 10.0:
				break
			uid += 1
			var produced_at := end_time - age * wall_per_step
			var income := furnace_income_peak(produced_at,jewel_furnace)
			profile["jewelFurnaceIncomePeak" if jewel_furnace else "furnaceIncomePeak"] = income
			var amount := ceilf(income * float(row.para2) * effective_hightech_level(key) * (1.0 + crew.get_modifier(self,target_type,key,"OUTPUT") + crew.get_modifier(self,target_type,key,"EFFICIENCY")) * (1.0 if jewel_furnace else 1.0+float(hyperspace_totals().hangings.get("resource_collector",0))))
			var block := {"uid":uid,"x":rng.randf_range(70,BATTLE_SIZE.x-70),"y":rng.randf_range(250,480),"age":age,"id":"jewel" if jewel_furnace else "1","amount":amount,"hightech":true}
			if jewel_furnace:
				block.jewel = true
				block.jewelRatio = 1.0
			drops.append(block)

func max_shield() -> Variant:
	return stat("shield") if profile.unlocked.has("shield") else 0.0

func reset_player() -> void:
	configuration_committed()
	refit_health_ratios = {"armour":1.0,"shield":1.0}
	jewel_repeats.clear()
	jewel_defence_times.clear()
	jewel_defence_damage.clear()
	jewel_charged.clear()
	enhancement_branches.reset()
	enhancement_attack_contexts.clear()
	enhancement_buffers.clear()
	enhancement_buffer_owners.clear()
	enhancement_memory_elapsed=0.0
	enhancement_defense_time=0.0
	enhancement_deferred_elapsed=0.0
	enhancement_deferred_tick=0
	enhancement_memory_due_pending=false;enhancement_deferred_due_pending=false
	enhancement_deferred.clear()
	player = {"x":PLAYER_POSITION.x, "y":PLAYER_POSITION.y, "armour":stat("armour"), "shield":max_shield()}
	since_hit = 100

func change_state(next: State) -> void:
	if native_execution!=null:
		native_execution.cancel(self);native_execution=null
	if next != State.COMBAT:
		projectiles = projectiles.filter(func(p): return not p.get("beam", false) or (next==State.TRAVEL and endless_beam_eligible(p)))
	if next == State.TRAVEL:
		travel_origin = INF
		cooldowns.clear()
		for index in range(combat_weapon_entries().size()):
			var entry: Dictionary = combat_weapon_entries()[index]
			var key := str(entry.key)
			if key.is_empty():
				continue
			var cd := float(player_weapon_row(entry).cd)
			# The quick opening salvo belongs to an encounter, not a refit or target change.
			if key == "missile":
				cd = minf(cd,0.4)
			if cd > 0:
				cooldowns[slot_id("weapons", index)] = cd
	state = next
	event.emit("state", {"state":state})

func select_loop_level(level: int) -> bool:
	if level != stage and not profile.cleared.has(level):
		return false
	profile.loopLevel = level
	return start(level, false)

func toggle_loop() -> void:
	if manual_hyperspace.active:return
	if profile.loop:
		profile.loop = false
		guard_elapsed = 0
		guard_arrived = false
		save_dirty = true
	elif state in [State.TRAVEL, State.COMBAT, State.LEVEL_CLEAR] and not db.levels[stage-1].groups.is_empty():
		guard_index = clampi(group_index if state == State.TRAVEL else group_index-1, 0, db.levels[stage-1].groups.size()-1)
		profile.loop = true
		guard_elapsed = 0
		profile.guardStage = stage
		guard_engaged = not targets().is_empty()
		profile.guardIndex = guard_index
		guard_arrived = state != State.TRAVEL
		profile.guardDistance = distance if guard_arrived else float(db.levels[stage-1].groups[guard_index].position) * float(db.levels[stage-1].length)
		if state == State.LEVEL_CLEAR:
			clear_timer = guard_interval()
		save_dirty = true

func guarding_here() -> bool:
	return profile.loop and guard_arrived

func set_guard_death(mode: int) -> void:
	if mode in [0,1,2]:
		profile.guardDeath = mode
		save_dirty = true

func guard_interval() -> float:
	var encounters: Array = db.levels[stage-1].groups
	var previous := 0.0 if guard_index == 0 else float(encounters[guard_index-1].position)
	var gap := float(encounters[guard_index].position) * float(db.levels[stage-1].length) - previous * float(db.levels[stage-1].length)
	return minf(MAX_TRAVEL_SECONDS,gap / ship_movement() if ship_movement() > 0 else INF)

func respawn_guard() -> void:
	guard_elapsed = 0
	group_index = guard_index
	spawn_group(true)

func resume_guard() -> void:
	retreat_boss_pending = false
	guard_index = int(profile.guardIndex)
	distance = float(profile.guardDistance)
	group_index = guard_index + 1
	guard_elapsed = 0
	guard_engaged = false
	guard_arrived = true
	change_state(State.COMBAT)

func configure_hyperspace_routes(routes: Dictionary) -> bool:
	return manual_hyperspace.configure(self,routes)

func load_hyperspace_routes(binding: Variant=null,candidate: Variant=null) -> bool:
	return manual_hyperspace.load_production(self,binding,candidate)

func request_hyperspace(route:String,level:int)->bool:
	return manual_hyperspace.request(self,route,level)

func cancel_hyperspace_request()->bool:
	return manual_hyperspace.cancel_queue(self)

func start_hyperspace(route: String,level: int) -> bool:
	return manual_hyperspace.start(self,route,level)

func hyperspace_route_view(route:String,crew_id:String="")->Dictionary:
	return hyperspace.route_view(self,route,crew_id)

func start_hyperspace_idle(route:String)->bool:
	return hyperspace_runtime.start_idle(self,route)

func set_hyperspace_auto(route:String,crew_id:String,enabled:bool)->bool:
	return hyperspace_runtime.set_auto(self,enabled,route,hyperspace.current_layer(self,route),crew_id)

func stop_hyperspace_idle(route:String)->bool:
	return hyperspace_runtime.stop_idle(self,route)

func start_hyperspace_challenge(route:String)->bool:
	return manual_hyperspace.start(self,route,hyperspace.current_layer(self,route)+1)

func exit_hyperspace_challenge()->bool:
	return manual_hyperspace.finish(self,false,"user_exit")

func claim_hyperspace(round_id:int=-1,run_id:int=-1)->bool:
	if round_id>=0 and run_id>=0:return hyperspace_runtime.claim(self,round_id,run_id)
	var claimed:=false
	for slot in ["active","idle"]:
		var receipt:Dictionary=hyperspace.state[slot]
		if not receipt.is_empty() and receipt.status=="completed_pending":claimed=hyperspace_runtime.claim(self,int(receipt.round_id),int(receipt.run_id)) or claimed
	return claimed

func hyperspace_material_exchange_quote(source:String,target:String,amount:Variant)->Dictionary:
	return hyperspace.material_exchange_quote(self,source,target,amount)

func exchange_hyperspace_materials(request:Dictionary)->Dictionary:
	return hyperspace_runtime.exchange_materials(self,request)

func advance_after_clear() -> bool:
	if state != State.LEVEL_CLEAR or not pending_unlocks.is_empty():
		return false
	return start(next_stage(), profile.loop and not guard_arrived)

func next_stage() -> int:
	return mini(stage + 1, db.levels.size())

func start(level: int, loop_mode: bool, checkpoint: Dictionary = {}) -> bool:
	if manual_hyperspace.active and not manual_hyperspace.initializing:return false
	if level < 1 or level > (db.levels.size() if manual_hyperspace.initializing else int(profile.highestLevel)):
		return false
	if N.compare(stat("armour"),0)<=0 and N.compare(stat("shield"),0)<=0:
		event.emit("battle_blocked",{"reason":"zero_defence"})
		return false
	reset_sortie(level,loop_mode)
	if not checkpoint.is_empty():
		distance = float(checkpoint.distance)
		group_index = int(checkpoint.groupIndex)
		retreat_boss_pending = bool(checkpoint.retreatBossPending)
		if int(checkpoint.state) == State.LEVEL_CLEAR:
			guard_arrived = profile.loop and checkpoint.guardArrived and stage == int(profile.guardStage)
			clear_timer = guard_interval() if guarding_here() else CLEAR_ADVANCE_DELAY
			pending_unlocks.assign(checkpoint.get("pendingUnlocks", []))
			change_state(State.LEVEL_CLEAR)
		elif profile.loop and checkpoint.guardArrived and stage == int(profile.guardStage):
			resume_guard()
		elif int(checkpoint.state) == State.COMBAT:
			group_index -= 1
			spawn_group(true)
		elif int(checkpoint.state) == State.RETREAT:
			retreat_from = distance
			retreat_target = distance
			retreat_elapsed = 0
			change_state(State.RETREAT)
	save_dirty = true
	return true

func reset_sortie(level:int,loop_mode:bool)->void:
	departure_remaining=0.0
	if native_execution!=null:
		native_execution.cancel(self);native_execution=null
	native_execution_requested=false;native_wave_waiting=false
	settle_drops()
	drone_combat.reset();configuration_committed()
	stage = level
	distance = 0
	group_index = 0
	guard_index = -1
	guard_elapsed = 0
	guard_engaged = false
	guard_arrived = false
	retreat_boss_pending = false
	enemies.clear()
	projectiles.clear()
	cooldowns.clear()
	pending_unlocks.clear()
	reset_player()
	paused = false
	profile.loop = loop_mode
	if loop_mode:
		guard_index = int(profile.get("guardIndex", 0))
	run_resources = {"1":0.0,"2":0.0}
	change_state(State.TRAVEL)
	save_dirty=true

func is_active() -> bool:
	return state in [State.TRAVEL, State.COMBAT] and player_alive()

func ratio(kind: String) -> float:
	return db.ratio(stage, maxi(0, group_index - 1), kind)

func is_final_encounter() -> bool:
	# Completion belongs to the final battle point, independently of enemy tier.
	return group_index > 0 and group_index == db.levels[stage - 1].groups.size()

func encounter_tier() -> String:
	if group_index<=0 or group_index>db.levels[stage-1].groups.size():return "normal"
	var encounter:Dictionary=db.levels[stage-1].groups[group_index-1]
	return str(db.groups[str(int(encounter.id))].get("combatTier","boss" if is_final_encounter() else "normal"))

func is_boss_encounter() -> bool:
	return encounter_tier() in ["boss","ultimate"]

func publish_encounter_geometry() -> void:
	# Persist the chosen encounter leader on its actor. Death and residual shots
	# must not promote escorts or depend on a presentation object's lifetime.
	var leader:Dictionary={}
	if is_boss_encounter():
		for enemy in enemies:
			if leader.is_empty() or int(enemy.size)>int(leader.size):leader=enemy
	for enemy in enemies:
		enemy.encounter_leader=is_same(enemy,leader)
		enemy.hull_scale=(1.65 if encounter_tier()=="ultimate" else 1.35) if enemy.encounter_leader else 1.0

func spawn_group(keep_distance := false) -> void:
	if damage_stats.enabled:damage_stats.clear()
	guard_engaged = true
	var encounter: Dictionary = db.levels[stage - 1].groups[group_index]
	if manual_hyperspace.active and manual_hyperspace.reward_binder!=null:
		var reward_error:String=preload("res://scripts/candidate_rewards.gd").binding_error(str(int(encounter.id)),db.groups,db.enemies,db.levels,stage,float(db.levels[stage-1].resRatio),jewel_ratio())
		if not reward_error.is_empty():
			manual_hyperspace.last_error="space_reward_binding_invalid: "+reward_error
			manual_hyperspace.finish(self,false,"setup_failed");return
	if not keep_distance:
		distance = float(encounter.position) * float(db.levels[stage - 1].length)
	group_index += 1
	if profile.loop and stage == int(profile.guardStage) and group_index == guard_index+1:
		guard_arrived = true
		distance = maxf(distance, float(profile.guardDistance))
		profile.guardDistance = distance
	enemies.clear()
	var source_group:Dictionary=db.groups[str(int(encounter.id))]
	var slots: Array = source_group.slots
	var explicit:Variant=source_group.get("formation_positions",null)
	var placement:Dictionary = manual_hyperspace.positions(self,slots,explicit) if manual_hyperspace.active else preload("res://scripts/enemy_formation.gd").positions(slots,db.enemies,explicit)
	if explicit!=null and placement.is_empty():
		push_error("Encounter rejected: invalid formation_positions")
		if not manual_hyperspace.reject_formation(self,["invalid formation_positions"]):
			change_state(State.RETREAT)
		return
	var formation_columns := 0 if explicit!=null else 5
	for slot in range(slots.size()):
		if slots[slot] == null:
			continue
		var row: Dictionary = db.enemies[str(int(slots[slot]))]
		var enemy := row.duplicate(true)
		uid += 1
		enemy.uid = uid
		enemy.slot = slot
		enemy.formation_columns = formation_columns
		enemy.size_formation = true
		enemy.explicit_formation = explicit!=null
		enemy.formation_count = placement.size()
		var slot_position: Vector2 = placement[slot]
		enemy.x = slot_position.x
		enemy.y = slot_position.y
		enemy.hp = db.enemy_encounter_capacity(row,stage,group_index-1,"health")
		enemy.max_hp = enemy.hp
		enemy.max_shield = db.enemy_encounter_capacity(row,stage,group_index-1,"shield")
		enemy.shield = enemy.max_shield
		enemy.shield_updated_at = enemy_shield_time
		enemy.shield_hit_at = enemy_shield_time
		enemy.res_ratio = ratio("resRatio")
		# Wave tier is independent of hull size and final-wave completion.
		enemy.combat_tier = encounter_tier()
		enemy.boss = enemy.combat_tier in ["boss","ultimate"]
		enemy.cooldowns = []
		for entry in row.equipment:
			enemy.cooldowns.append(float(db.enemy_weapon(entry.name).cd))
		enemies.append(enemy)
	publish_encounter_geometry()
	if not manual_hyperspace.active and is_boss_encounter() and not profile.bossSeen.has(stage):
		profile.bossSeen.append(stage)
		save_dirty = true
	change_state(State.COMBAT)
	event.emit("encounter", {"boss":is_boss_encounter(),"tier":encounter_tier(),"final":is_final_encounter()})

	if native_execution_auto:
		native_execution_requested=false
		admit_native_compiled_execution("native_rich15_layer2")

func boss_info() -> String:
	if not profile.get("bossSeen", []).has(stage) and not profile.cleared.has(stage):
		return UIText.t("system.boss_info.text_01")
	var descriptions: Array[String] = []
	var encounters: Array = db.levels[stage - 1].groups
	if encounters.is_empty():
		return UIText.t("system.boss_info.text_01")
	for id in db.groups[str(int(encounters.back().id))].slots:
		if id == null:
			continue
		var row: Dictionary = db.enemies[str(int(id))]
		if not descriptions.has(UIText.data_text("enemies",str(int(id)),"des")):
			descriptions.append(UIText.data_text("enemies",str(int(id)),"des"))
	return " / ".join(descriptions) if not descriptions.is_empty() else UIText.t("system.boss_info.text_01")

func targets(damage_type: int = 0) -> Array[Dictionary]:
	if native_execution!=null:return native_execution.kernel.target_views(damage_type)
	var alive: Array[Dictionary] = []
	for e in enemies:
		if e.hp > 0:
			if damage_type!=0 and not settle_enemy_shield(e,enemy_shield_time if enemy_shield_hit_time<0 else enemy_shield_hit_time):return []
			alive.append(e)
	var resistance:Dictionary={}
	if compiled_combat_rules!=null and damage_type!=0:
		for enemy in alive:resistance[int(enemy.uid)]=enemy_resistance_type(enemy)
	alive.sort_custom(func(a,b):
		if damage_type != 0:
			var a_resists:bool=(int(resistance[int(a.uid)]) if compiled_combat_rules!=null else enemy_resistance_type(a)) == damage_type
			var b_resists:bool=(int(resistance[int(b.uid)]) if compiled_combat_rules!=null else enemy_resistance_type(b)) == damage_type
			if a_resists != b_resists:
				return not a_resists
		if a.y != b.y:
			return a.y > b.y
		var ac := absf(float(a.slot) - 4.5)
		var bc := absf(float(b.slot) - 4.5)
		return ac < bc if ac != bc else a.slot < b.slot)
	return alive

func has_alive_enemy() -> bool:
	for enemy in enemies:
		if enemy.hp > 0:
			return true
	return false

func enemy_resistance_type(enemy: Dictionary) -> int:
	if not settle_enemy_shield(enemy,enemy_shield_time if enemy_shield_hit_time<0 else enemy_shield_hit_time):return -1
	return int(enemy.get("shieldType",0)) if N.compare(enemy.get("shield",0),0)>0 else int(enemy.armourType)

func reduced_damage(raw, type: int, resistance: int) -> Variant:
	return N.maximum(1, N.ceiling(N.multiply(raw,1.0 - float(db.config.dmgReduce) if type == resistance else 1.0)))

func enemy_weapon_offset(enemy: Dictionary, equipment_index: int) -> Vector2:
	var key: String = enemy.equipment[equipment_index].name
	var count := 0
	var ordinal := 0
	for i in range(enemy.equipment.size()):
		if enemy.equipment[i].name == key:
			if i < equipment_index:
				ordinal += 1
			count += 1
	var visuals = preload("res://scripts/ship_visuals.gd")
	var dimensions: Vector2 = visuals.CANVAS * visuals.enemy_scale_for(enemy)
	# Enemy noses point down, toward the player.
	var launch_y := dimensions.x * 0.45
	if count <= 1:
		return Vector2(0,launch_y)
	# Spread identical mounts across the visible hull, including its wings.
	var half_span := dimensions.y * 0.3
	return Vector2(lerpf(-half_span, half_span, float(ordinal) / float(count - 1)),launch_y)

func player_weapon_offset(index: int) -> Vector2:
	if index>=weapon_entries().size():
		var positions: Array=[Vector2(-60,15),Vector2(60,15),Vector2(-95,50),Vector2(95,50),Vector2(0,-60)]
		return positions[clampi(index-weapon_entries().size(),0,4)]
	var visuals = preload("res://scripts/ship_visuals.gd")
	return visuals.muzzle(equipment.selected_ship(), index).rotated(-PI/2) * visuals.scale_for(db.ship(equipment.selected_ship()))

func fire(source: Dictionary, target: Dictionary, weapon: Dictionary, raw, hostile: bool, key: String, offset := Vector2.ZERO, visual_spread := 0.0) -> void:
	var speed_parameter = weapon.para2 if key.begins_with("missile") else weapon.para1
	projectiles.append({"x":float(source.x) + offset.x,"y":float(source.y) + offset.y, "target":target,"damage":raw,"type":int(weapon.dmgtype),"speed":float(speed_parameter)*db.projectile_pixels_per_unit(hostile),"hostile":hostile,"key":key,"dead":false})
	var shot: Dictionary = projectiles.back()
	projectile_serial += 1
	shot.serial = projectile_serial
	shot.source_uid=int(source.get("uid",0))
	if not hostile and not player_launch_payload.is_empty():shot.merge(player_launch_payload)
	shot.direction = Vector2(0,1 if hostile else -1) if key.replace("_mon", "").replace("-mon", "") == "missile" else Vector2(target.x - shot.x, target.y - shot.y).normalized()
	prepare_projectile(shot,source,weapon,visual_spread)
	event.emit("fire", {"x":shot.x,"y":shot.y,"type":int(weapon.dmgtype),"shot":shot,"spread":visual_spread})

func prepare_projectile(_shot: Dictionary, _source: Dictionary, _weapon: Dictionary, _spread: float) -> void:
	pass

# A beam is one persistent projectile per mount; timing belongs to that object.
func beam_source_valid(shot:Dictionary) -> bool:
	var entry:Dictionary=combat_entry(int(shot.mount))
	# Numeric upgrades replace dictionaries, but do not replace the attack.
	return is_same(shot.source,player) and entry.get("key","")=="longLaser" and shot.entry.get("key","")=="longLaser" and entry.get("drone_id","")==shot.entry.get("drone_id","")

func endless_beam_eligible(shot:Dictionary) -> bool:
	return shot.get("beam",false) and not shot.get("dead",false) and not shot.hostile and not shot.get("repeated",false) and player_alive() and beam_source_valid(shot) and not hyperspace_totals().legendary.get("endless_beam",{}).is_empty() and int(shot.mount)==endless_source_slot()

func await_endless_target(shot:Dictionary) -> void:
	shot.await_target=true
	var chain:Dictionary=shot.attack_instance.chain
	chain.links.clear()
	chain.ended=false

func long_laser_valid(shot: Dictionary) -> bool:
	if shot.get("await_target",false):return false
	if native_execution!=null:
		if state!=State.COMBAT or bool(shot.dead) or shot.target.is_empty():return false
		if bool(shot.hostile):
			var source:Dictionary=shot.get("source",{})
			return not source.is_empty() and float(source.get("hp",0))>0 and is_same(native_execution.actor_by_uid.get(int(source.get("uid",-1)),{}),source) and player_alive()
		return float(shot.target.hp)>0
	if state != State.COMBAT or shot.dead or shot.target.is_empty() or not is_same(shot.target, shot.locked_target):
		return false
	if shot.hostile:
		return enemies.has(shot.source) and shot.source.hp > 0 and is_same(shot.target, player) and player_alive() and shot.mount < shot.source.equipment.size() and is_same(shot.entry, shot.source.equipment[shot.mount])
	return is_same(shot.source, player) and player_alive() and enemies.has(shot.target) and shot.target.hp > 0 and beam_source_valid(shot)

func lock_long_laser(source: Dictionary, weapon: Dictionary, hostile: bool, mount: int, entry: Dictionary, repeated := false, repeat_multiplier := 1.0, repeat_depth := 0, repeat_origin_multiplier := 1.0, inherited_snapshot: Dictionary = {}) -> void:
	for shot in projectiles:
		if shot.get("beam", false) and shot.hostile == hostile and is_same(shot.source, source) and shot.mount == mount and bool(shot.get("repeated",false)) == repeated and int(shot.get("repeat_depth",0))==repeat_depth and (long_laser_valid(shot) or (shot.get("await_target",false) and endless_beam_eligible(shot))):
			return
	var candidates: Array = targets(int(weapon.dmgtype)) if not hostile else []
	var target: Dictionary = player if hostile else (candidates[0] if not candidates.is_empty() else {})
	if not hostile:
		for candidate in candidates:
			if not projectiles.any(func(p):return p.get("beam",false) and not p.hostile and p.mount==mount and long_laser_valid(p) and is_same(p.target,candidate)):
				target = candidate
				break
	if target.is_empty() or float(weapon.cd) <= 0:
		return
	var offset := enemy_weapon_offset(source, mount) if hostile else player_weapon_offset(mount)
	if repeated:
		offset.x += 6.0
	var previous_payload: Dictionary=player_launch_payload
	var launch_snapshot:Dictionary={}
	if not hostile:
		if repeated:
			launch_snapshot=inherited_snapshot
			record_enhancement_attack()
		else:
			begin_enhancement_attack(mount,target)
			record_enhancement_attack()
			jewel_attack(mount)
			launch_snapshot=enhancement_attack_contexts[mount].snapshot
			finish_enhancement_attack(mount)
		player_launch_payload={"entry":entry,"mount":mount,"salvo_ordinal":0,"beam":true,"combat_context":CombatContext.derive_with_chain(launch_snapshot.combat_context,"repeat_or_secondary") if repeated else launch_snapshot.combat_context}
	fire(source, target, weapon, 0, hostile, "longLaser-mon" if hostile else "longLaser", offset)
	player_launch_payload=previous_payload
	var shot: Dictionary = projectiles.back()
	shot.merge({"beam":true, "repeated":repeated, "repeat_multiplier":repeat_multiplier, "repeat_depth":repeat_depth, "repeat_origin_multiplier":repeat_origin_multiplier, "charged_multiplier":1.0, "locked_target":target, "source":source, "mount":mount, "entry":entry, "elapsed":0.0, "ticks":0, "weapon":weapon, "charge":maxf(0,float(weapon.para3)) if weapon.get("para3") != null else -1.0})
	if not hostile and not repeated:
		var id := slot_id("weapons",mount)
		shot.charged_multiplier = float(jewel_charged.get(id,1.0))
		shot.repeat_origin_multiplier=shot.charged_multiplier
		jewel_charged.erase(id)
	if not hostile:
		shot.attack_snapshot=launch_snapshot
		shot.main_attack_id=shot.attack_snapshot.id
		shot.attack_instance=new_attack_instance(shot.attack_snapshot) if repeated else shot.attack_snapshot.instance
		shot.attack_instance_id=shot.attack_instance.id
		shot.endless=endless_beam_eligible(shot)
		bind_beam_chain(shot)

	event.emit("beam_started", {"shot":shot})

func long_laser_multiplier(weapon: Dictionary, duration: float) -> float:
	return minf(1.0 + (float(weapon.para2) - 1.0) * duration / float(weapon.para1), float(weapon.para2)) if float(weapon.para1) > 0 else float(weapon.para2)

func advance_long_laser(shot: Dictionary, dt: float) -> bool:
	shot.endless=endless_beam_eligible(shot)
	if shot.endless and state==State.TRAVEL:
		await_endless_target(shot);return false
	if not long_laser_valid(shot) and shot.endless and state==State.COMBAT:
		var candidates:=targets(int(shot.weapon.dmgtype))
		if candidates.is_empty():
			await_endless_target(shot);return false
		shot.await_target=false;shot.target=candidates[0];shot.locked_target=shot.target
		shot.attack_instance.chain.links.clear();bind_beam_chain(shot,true)
	if not long_laser_valid(shot):
		shot.dead = true
		end_beam_chain(shot)
		return false
	prune_beam_chain(shot)
	var offset := enemy_weapon_offset(shot.source, shot.mount) if shot.hostile else player_weapon_offset(shot.mount)
	if shot.repeated:
		offset.x += 6.0
	shot.x = float(shot.source.x) + offset.x
	shot.y = float(shot.source.y) + offset.y
	shot.elapsed += dt
	var weapon: Dictionary = db.enemy_weapon(shot.entry.name) if shot.hostile else shot.attack_snapshot.weapon
	# Use scheduled hit times, not frame end time, including when a step spans several hits.
	var interval := float(weapon.cd)
	var first_hit := float(shot.charge) if float(shot.charge) >= 0 else interval
	if not shot.has("next_hit_at"):shot.next_hit_at=first_hit
	return true

func apply_long_laser_hit(shot: Dictionary, due: float) -> void:
	var weapon: Dictionary = db.enemy_weapon(shot.entry.name) if shot.hostile else shot.attack_snapshot.weapon
	var interval := float(weapon.cd)
	var previous_hit_time := enemy_shield_hit_time
	enemy_shield_hit_time=enemy_shield_time-float(shot.elapsed)+due
	shot.ticks += 1
	# Charged ramp age is an integer period count. Subtracting absolute times
	# (for example 0.8 - 0.6) can add a spurious point at damage ceiling.
	var duration := float(shot.ticks-1)*interval if float(shot.charge)>=0 else due
	var multiplier := long_laser_multiplier(weapon, duration)
	event.emit("beam_hit", {"shot":shot})
	if shot.hostile:
		var raw := db.enemy_attack_damage(shot.source,weapon,stage,group_index-1)
		hit_player(raw * multiplier, int(weapon.dmgtype),{"source_uid":int(shot.source.get("uid",0)),"weapon_key":"longLaser"})
	else:
		enhancement_attack_contexts[int(shot.mount)]={"derived":bool(shot.repeated),"snapshot":shot.attack_snapshot,"instance":shot.attack_instance}
		var boost := float(shot.repeat_multiplier) * float(shot.charged_multiplier)
		if int(shot.ticks)==1 and not shot.repeated:
			queue_jewel_repeats(shot.mount,boost,shot)
		var attack := jewel_attack(shot.mount, multiplier * boost)
		if attack.critical:
			event.emit("critical_impact", {"pos":Vector2(shot.target.x,shot.target.y),"direction":Vector2(shot.target.x-shot.x,shot.target.y-shot.y).normalized()})
		hit_enemy(shot.target,attack.damage,int(weapon.dmgtype),attack.effects,attack.critical,attack.get("combat_context",{}))
		launch_enhancement_secondary(int(shot.mount),shot.target,weapon,boost*multiplier,true)
		enhancement_attack_contexts.erase(int(shot.mount))
	if not projectiles.has(shot) or not long_laser_valid(shot):
		if projectiles.has(shot) and endless_beam_eligible(shot):await_endless_target(shot)
		else:
			shot.dead = true
			end_beam_chain(shot)
	enemy_shield_hit_time=previous_hit_time

func tick_long_laser(shot: Dictionary, dt: float) -> void:
	if not advance_long_laser(shot,dt):return
	var weapon: Dictionary = db.enemy_weapon(shot.entry.name) if shot.hostile else shot.attack_snapshot.weapon
	while float(shot.next_hit_at)<=float(shot.elapsed)+0.000000001:
		var due := float(shot.next_hit_at)
		shot.next_hit_at=due+float(weapon.cd)
		apply_long_laser_hit(shot,due)
		if shot.dead or shot.get("await_target",false):break

func tick_shield_beams(pending: Array, dt: float) -> void:
	if _legacy_defence_span_active and _legacy_defence_stopped():return
	if state!=State.COMBAT:
		# The combat clock is frozen here: clean up, never schedule past periods.
		for shot in pending:
			if shot.get("beam",false) and projectiles.has(shot):advance_long_laser(shot,0.0)
		return
	# Flying rounds and asynchronous chain hops hit at the step boundary. Beam
	# periods can precede it, so merge periods across mounts before those hits.
	var hits: Array[Dictionary] = []
	var previous_query_time:=enemy_shield_hit_time
	# Rebinding happens at step start, before any scheduled period in this step.
	enemy_shield_hit_time=enemy_shield_time-dt
	for index in pending.size():
		var shot: Dictionary = pending[index]
		if not shot.get("beam",false) or not projectiles.has(shot):continue
		if not advance_long_laser(shot,dt):continue
		var weapon: Dictionary = db.enemy_weapon(shot.entry.name) if shot.hostile else shot.attack_snapshot.weapon
		var due:=float(shot.next_hit_at)
		while due<=float(shot.elapsed)+0.000000001:
			hits.append({"at":enemy_shield_time-float(shot.elapsed)+due,"due":due,"index":index,"shot":shot})
			due+=float(weapon.cd)
	enemy_shield_hit_time=previous_query_time
	hits.sort_custom(func(a,b):return a.index<b.index if a.at==b.at else a.at<b.at)
	for item in hits:
		if not _legacy_advance_defence_to(float(item.at)):return
		var shot: Dictionary = item.shot
		if not projectiles.has(shot) or not long_laser_valid(shot):continue
		var weapon:Dictionary=db.enemy_weapon(shot.entry.name) if shot.hostile else shot.attack_snapshot.weapon
		shot.next_hit_at=float(item.due)+float(weapon.cd)
		apply_long_laser_hit(shot,float(item.due))

func hit_player(raw, type: int, context: Dictionary = {}) -> void:
	if native_execution!=null:
		push_error("legacy executor called during native ownership");return
	record_enhancement_hit() # Incoming attempts count once, including absorption.
	if not context.has("trigger_depth"):
		var root:=CombatContext.root(0,"enemy:"+str(context.get("source_uid",0)),str(context.get("weapon_key","")));root.merge(context);context=root
	var incoming:=drone_combat.incoming(self,raw,context)
	if incoming.absorbed:return
	raw=incoming.damage
	enhancement_branches.memory_incoming(self,type)
	var modified=N.multiply(raw,enhancement_branches.incoming_multiplier(self,int(context.get("source_uid",0))))
	jewel_hit_player(modified,type)

func begin_retreat() -> void:
	if not player_alive():equipment.clear_switches()
	if native_execution!=null:
		native_execution.cancel(self);native_execution=null
	drone_combat.restore_rebuild(self)
	if manual_hyperspace.active:
		manual_hyperspace.finish(self,false,"defeat" if not player_alive() else "user_exit");return
	guard_arrived = false
	guard_elapsed = 0
	guard_engaged = false
	if int(profile.get("guardDeath", 0)) == 0:
		profile.loop = false
	var original_stage := stage
	retreat_boss_pending = false
	retreat_from = distance
	retreat_target = distance - float(db.config.backRange)
	while retreat_target < 0 and stage > 1:
		stage -= 1
		var previous_length := float(db.levels[stage - 1].length)
		retreat_target += previous_length
		retreat_from += previous_length
	retreat_target = maxf(0, retreat_target)
	retreat_elapsed = 0
	enemies.clear()
	cooldowns.clear()
	group_index = 0
	var level: Dictionary = db.levels[stage - 1]
	while group_index < level.groups.size() and float(level.groups[group_index].position)*float(level.length) < retreat_target - 0.001:
		group_index += 1
	if stage < original_stage and group_index == level.groups.size() and group_index > 0:
		group_index -= 1
		retreat_boss_pending = true
	change_state(State.RETREAT)
	event.emit("retreat", {"from":retreat_from,"to":retreat_target})
	save_dirty = true

func acknowledge_unlocks() -> void:
	# One page per item keeps simultaneous unlocks readable without dropping any.
	if not pending_unlocks.is_empty():
		var key: String = pending_unlocks.pop_front()
		if not profile.seenUnlocks.has(key):
			profile.seenUnlocks.append(key)
			invalidate_tutorial_unlocks()
	save_dirty = true
	event.emit("state", {"state":state})

func hit_enemy(enemy: Dictionary, raw, type: int, effects: Array = [], critical: bool = false, context: Dictionary = {}) -> void:
	if native_execution!=null:
		push_error("legacy executor called during native ownership");return
	if enemy.hp <= 0:
		return
	var hit_time:=enemy_shield_time if enemy_shield_hit_time<0 else enemy_shield_hit_time
	# Reject a future ledger before rolls, buffs, counters or damage can mutate.
	if not settle_enemy_shield(enemy,hit_time):return
	if context.is_empty():
		main_attack_serial+=1;context=CombatContext.root(main_attack_serial,"direct","")
	if drone_combat.absorb(self,raw,false):return
	var base_raw=raw
	raw=guided_missile_damage(enemy,raw,context)
	var reactive_stacks := 0
	var reactive_multiplier := 1.0
	if int(enemy.get("reactiveReduction",0)) == 1:
		var volley_at := float(enemy.get("reactive_volley_at",-1.0e100))
		if hit_time > volley_at + REACTIVE_VOLLEY_GAP:
			reactive_stacks = mini(REACTIVE_STACK_LIMIT,int(enemy.get("reactive_stacks",0))+1) if hit_time <= volley_at + REACTIVE_RESET_SECONDS else 0
			enemy.reactive_volley_at = hit_time
			enemy.reactive_stacks = reactive_stacks
		else:
			reactive_stacks = int(enemy.get("reactive_stacks",0))
		reactive_multiplier = 1.0 - REACTIVE_STACK_REDUCTION * reactive_stacks
		enemy.reactive_multiplier = reactive_multiplier
		raw = N.multiply(raw,reactive_multiplier)
	var chain_origin := Vector2(enemy.x,enemy.y)
	for effect in effects:
		var chain:Dictionary=effect.get("chain_state",{})
		if effect.get("chain",false) and not chain.get("used",false) and not effect.get("chain_used",false):
			chain_origin=chain_target_point(enemy);break
	if CombatContext.can_trigger(context):jewel_on_hit(enemy, effects)
	var resistance := float(db.config.dmgReduce)
	for effect in effects:
		if effect.has("enemy_resistance"):resistance=float(effect.enemy_resistance);break
	var incoming = N.multiply(raw,1.0+float(enemy.get("interference",0)))
	var absorbed = 0.0
	var shield_before = enemy.get("shield",0) if damage_stats.enabled else 0
	if float(enemy.get("max_shield",0))>0:
		incoming=N.maximum(1,incoming)
		# A periodic beam hit is a hit, even though the whole beam is one attack.
		enemy.shield_hit_at=hit_time
		if N.compare(enemy.get("shield",0),0)>0:
			var factor := 1.0-resistance if type==int(enemy.get("shieldType",0)) else 1.0
			absorbed=N.minimum(enemy.shield,N.maximum(1,N.multiply(incoming,factor)))
			enemy.shield=N.subtract(enemy.shield,absorbed)
			incoming=N.maximum(0,N.subtract(incoming,N.divide(absorbed,factor))) if factor>0 else 0.0
	var amount = 0.0
	var hp_before = enemy.hp if damage_stats.enabled else 0
	if N.compare(absorbed,0)<=0 or N.compare(incoming,0)>0:
		amount=N.maximum(1,N.ceiling(N.multiply(incoming,1.0-resistance if type==int(enemy.armourType) else 1.0)))
		enemy.hp=N.subtract(enemy.hp,amount)
	if damage_stats.enabled and state==State.COMBAT:
		damage_stats.record(str(context.get("source_id","other")),N.add(N.maximum(0,N.subtract(shield_before,enemy.shield)),N.maximum(0,N.subtract(hp_before,enemy.hp))))
	amount=N.add(amount,absorbed)
	# Only the hit that crosses zero owns death; recursive wild damage settles its own kill.
	var killed_by_hit: bool=N.compare(enemy.hp,0)<=0
	var hit_feedback := {"x":enemy.x,"y":enemy.y,"amount":amount,"player":false,"type":type,"uid":enemy.uid,"critical":critical}
	if int(enemy.get("reactiveReduction",0)) == 1:
		hit_feedback.reactive_stacks = reactive_stacks
		hit_feedback.reactive_multiplier = reactive_multiplier
	event.emit("hit", hit_feedback)
	drone_combat.on_hit(self,enemy,base_raw,context)
	if killed_by_hit:
		enemy.erase("guidance_layers")
		break_beam_chain_target(enemy,hit_time)
		if is_final_encounter() and targets().is_empty():
			projectiles.clear()
		event.emit("explode", enemy)
		jewel_kill_drop(enemy)
		for drop in enemy.drops:
			if rng.randf() < float(drop.chance):
				uid += 1
				var multiplier = reactor_multiplier("smelting") if int(drop.resourceId) == 1 else 1.0
				var drop_factor=N.multiply(float(enemy.res_ratio),multiplier)
				var base_amount = N.ceiling(N.multiply(N.multiply(drop.amount,drop_factor),1.0+float(enemy.get("jewelIron",0)) if int(drop.resourceId)==1 else 1.0))
				var drop_amount = N.ceiling(N.multiply(base_amount,planet_resource_multiplier())) if int(drop.resourceId) in [1,2] else base_amount
				drops.append({"uid":uid,"x":enemy.x,"y":enemy.y+40,"source_uid":enemy.uid,"age":0.0,"id":str(int(drop.resourceId)),"amount":drop_amount,"production_base":base_amount})

		if CombatContext.can_trigger(context) and float(enemy.get("jewelExplosion", 0)) > 0:
			for adjacent in enemies.duplicate():
				if adjacent.hp > 0 and abs(int(adjacent.slot) - int(enemy.slot)) in [1, 2]:
					hit_enemy(adjacent, float(enemy.max_hp) * float(enemy.jewelExplosion), type,[],false,CombatContext.derive(context,"interference_explosion"))

	if CombatContext.can_chain(context):launch_enhancement_chain(enemy,base_raw,type,effects,critical,chain_origin,context)
	if _legacy_defence_span_active:_legacy_defence_stopped()

func freeze_higgs_geometry(shot: Dictionary) -> void:
	if not shot.has("higgs"):return
	var geometry: Dictionary={"origin":Vector2(shot.x,shot.y),"aim":chain_target_point(shot.target),"bounds":BATTLE_SIZE}
	if rail_geometry_provider.is_valid():geometry=rail_geometry_provider.call(shot)
	if geometry.has("full_width"):shot.higgs.full_width=float(geometry.full_width)
	var origin: Vector2=geometry.origin
	var direction: Vector2=(Vector2(geometry.aim)-origin).normalized()
	shot.higgs.origin=origin;shot.higgs.end=RailGeometry.exit_point(origin,direction,geometry.bounds,float(shot.higgs.full_width))
	shot.higgs.points={}
	for target in enemies:
		if N.compare(target.hp,0)>0:shot.higgs.points[str(target.uid)]=rail_target_point_provider.call(target) if rail_target_point_provider.is_valid() else chain_target_point(target)

func advance_higgs_projectile(shot: Dictionary,_dt: float) -> bool:
	if not shot.has("higgs"):return false
	if shot.higgs.get("completed",false):return true
	if not shot.higgs.has("origin"):freeze_higgs_geometry(shot)
	shot.higgs.completed=true
	var origin: Vector2=shot.higgs.origin;var end: Vector2=shot.higgs.end
	var candidates: Array=[]
	for target in enemies:
		if N.compare(target.hp,0)<=0 or shot.higgs.hit_uids.has(str(target.uid)):continue
		var point: Vector2=shot.higgs.points.get(str(target.uid),Vector2.INF)
		if RailGeometry.contains(point,origin,end,float(shot.higgs.full_width)):candidates.append(target)
	candidates.sort_custom(func(a,b):return Vector2(shot.higgs.points[str(a.uid)]).distance_squared_to(origin)<Vector2(shot.higgs.points[str(b.uid)]).distance_squared_to(origin))
	for target in candidates:
		if not projectiles.has(shot):break
		shot.higgs.hit_uids[str(target.uid)]=true
		event.emit("projectile_impact",{"shot":shot,"pos":chain_target_point(target)})
		hit_enemy(target,shot.damage,int(shot.type),shot.get("jewelEffects",[]),bool(shot.get("critical",false)),shot.combat_context)
	shot.dead=true
	return true

func guided_missile_damage(enemy: Dictionary,raw,context: Dictionary) -> Variant:
	if context.get("weapon","")!="missile":return raw
	var effect: Dictionary=hyperspace_totals().legendary.get("precise_guidance",{})
	if effect.is_empty():return raw
	var layers:=int(enemy.get("guidance_layers",0));var constants: Dictionary=effect.constants
	var factors: Dictionary=context.get("guidance_factors",{})
	var key:=str(enemy.uid)
	if not factors.has(key):
		factors[key]=N.power(float(constants.stack_multiplier),layers)
		if CombatContext.can_trigger(context):
			var next:=layers+1
			if constants.stack_limit_enabled:next=mini(next,int(constants.stack_limit))
			enemy.guidance_layers=next
	context.guidance_factors=factors
	return N.multiply(raw,factors[key])

func collect(drop: Dictionary, manual: bool, force := false) -> void:
	if not drops.has(drop):
		return
	if drop.has("jewel"):
		if not jewels_unlocked():
			return
		var core: bool = drop.get("hightech",false)
		if core and not manual and not force and float(drop.get("age",0)) < 10.0:
			return
		drops.erase(drop)
		var amount := float(drop.get("amount",1))
		if core and not manual:
			amount = ceilf(amount * (1.0 - float(db.config.autoCollectReduce)))
		drop.amount = settle_jewel_fragments(amount, "furnace" if core else "drop", 1.0 if core else float(drop.get("jewelRatio", jewel_ratio())))
		enhancement_currency_changed()
		event.emit("jewel_pickup", drop)
		return
	if drop.get("hightech", false) and not manual and not force and float(drop.get("age",0)) < 10.0:
		return
	drops.erase(drop)
	# Auto-collection loss is a separate calculation on the integer drop amount.
	var amount = N.ceiling(N.multiply(drop.amount,1.0 if manual else 1.0 - float(db.config.autoCollectReduce)))
	amount = N.ceiling(N.multiply(amount,research.income_factor(self,"iron_income" if str(drop.id)=="1" else "uranium_income")))
	economy.credit(str(drop.id), amount)
	resource_samples.append({"time":economy_time(),"production_time":production_time(),"id":str(drop.id),"amount":amount,"production_base":N.ceiling(N.multiply(drop.get("production_base",drop.amount),1.0 if manual else 1.0-float(db.config.autoCollectReduce))),"origin":"furnace" if drop.get("hightech",false) else "drop"})
	record_research_income(str(drop.id))
	profile.furnaceIncomePeak = furnace_income_peak()
	run_resources[drop.id] = N.add(run_resources[drop.id],amount)
	var info := drop.duplicate()
	info.amount = amount
	info.manual = manual
	event.emit("collect", info)
	save_dirty = true

func settle_drops(force := false) -> void:
	for drop in drops.duplicate():
		collect(drop, false, force)

func collect_near(pos: Vector2, _clicked := false, position_overrides: Dictionary = {}, path_start: Variant = null) -> void:
	if paused:
		return
	for drop in drops.duplicate():
		var drop_pos: Vector2 = position_overrides.get(int(drop.uid),Vector2(drop.x,drop.y))
		var nearest := Geometry2D.get_closest_point_to_segment(drop_pos,path_start,pos) if path_start is Vector2 else pos
		if drop_pos.distance_to(nearest) < 55:
			collect(drop, true)

func clear_level() -> void:
	equipment.clear_switches()
	drone_combat.restore_rebuild(self)
	if manual_hyperspace.active:
		manual_hyperspace.finish(self,true);return
	var previous := available_unlocks()
	first_clear = not profile.cleared.has(stage)
	if first_clear:
		profile.cleared.append(stage)
	rebuild_unlocks()
	for key in available_unlocks():
		if not previous.has(key) and not profile.get("seenUnlocks",[]).has(key) and not pending_unlocks.has(key):
			pending_unlocks.append(key)
	# A cleared stage settles every remaining drop before its unlock pause.
	settle_drops(true)
	clear_timer = CLEAR_ADVANCE_DELAY
	change_state(State.LEVEL_CLEAR)
	save_dirty = true
	if not pending_unlocks.is_empty():
		event.emit("unlock", {"items":pending_unlocks.duplicate(), "equipment":pending_unlocks.filter(func(id):return db.data.unlock[id].type == "equipment")})

func upgrade_cost_for_level(key: String, level: int) -> Dictionary:
	return equipment.costs(db,key,level-1,1)

func upgrade_cost(key: String, levels := 1) -> Dictionary:
	var entry := first_equipment_entry(key)
	var current := int(entry.level) if not entry.is_empty() else 1
	return upgrade_cost_for_level(key, current + 1) if levels == 1 else upgrade_costs_for_level(key, current, levels)

func upgrade_costs(key: String, levels: int) -> Dictionary:
	var entry := first_equipment_entry(key)
	var current := int(entry.level) if not entry.is_empty() else 1
	return upgrade_costs_for_level(key, current, levels)

func can_upgrade_amount(key: String, levels: int) -> bool:
	var entry := first_equipment_entry(key)
	if entry.is_empty():
		return false
	return can_upgrade_slot("weapons" if WEAPON_KEYS.has(key) else "defence", (weapon_entries() if WEAPON_KEYS.has(key) else defense_entries()).find(entry), levels)

func can_upgrade(key: String, levels := 1) -> bool:
	return can_upgrade_amount(key, levels)

func max_upgrade_amount(key: String) -> int:
	var entry := first_equipment_entry(key)
	if entry.is_empty():
		return 0
	return max_upgrade_amount_slot("weapons" if WEAPON_KEYS.has(key) else "defence", (weapon_entries() if WEAPON_KEYS.has(key) else defense_entries()).find(entry))

func max_upgrade_amount_slot(category: String, index: int, budget:Dictionary={}) -> int:
	var wallet:Dictionary=economy.equipment_balances(db.evolution_material_id()) if budget.is_empty() else budget.duplicate(true)
	if not wallet.has(db.evolution_material_id()):wallet[db.evolution_material_id()]=economy.balance(db.evolution_material_id())
	return int(equipment.maximum(db,category,index,wallet,hyperspace.is_unlocked(self)).amount)

func upgrade(key: String, levels := 1) -> bool:
	var category := "weapons" if WEAPON_KEYS.has(key) else "defence"
	var entries := weapon_entries() if category == "weapons" else defense_entries()
	var index := -1
	for i in range(entries.size()):
		if str(entries[i].key) == key:
			index = i
			break
	return upgrade_slot(category, index, levels)

func upgrade_slot(category: String, index: int, levels := 1) -> bool:
	var plan:=equipment.prepare_upgrades(db,economy.equipment_balances(db.evolution_material_id()),hyperspace.is_unlocked(self),str(levels),{"category":category,"index":index})
	return not plan.is_empty() and commit_equipment_upgrades(plan,false)

func upgrade_equipment_batch(mode: String) -> bool:
	var plan:=equipment.prepare_upgrades(db,economy.equipment_balances(db.evolution_material_id()),hyperspace.is_unlocked(self),mode)
	return not plan.is_empty() and commit_equipment_upgrades(plan,true)

func projected_upgrade_health(plan: Dictionary) -> Dictionary:
	var result:=player.duplicate(true)
	for purchase in plan.purchases:
		var key:String=purchase.before.key
		if purchase.category=="defence" and key in ["armour","shield"] and state!=State.RETREAT:
			result[key]=N.add(result[key],N.subtract(jewel_equipment_stat(purchase.after),jewel_equipment_stat(purchase.before)))
	return result

func commit_equipment_upgrades(plan: Dictionary, batch: bool) -> bool:
	var balance_revision:int=economy.revision
	var next_player:=projected_upgrade_health(plan)
	var native_plan:Dictionary={}
	if native_execution!=null:
		native_plan=native_execution.prepare_numeric_batch(self,plan,next_player)
		if native_plan.is_empty():
			if not native_before_configuration_change():return false
			next_player=projected_upgrade_health(plan)
	if not equipment.proposal_current(plan) or not economy.equipment_proposal_current(plan.wallet,db.evolution_material_id(),balance_revision):return false
	if native_execution!=null and not native_plan.is_empty():
		if not native_execution.commit_numeric_batch(self,native_plan):return false
	# The staged wallet and growth use the same ordered purchase list.
	var paid:=economy.commit_equipment_balances(plan.wallet,db.evolution_material_id(),balance_revision)
	assert(paid,"Equipment wallet changed inside synchronous commit")
	equipment.commit_refit(db,plan)
	for key in ["armour","shield"]:player[key]=next_player[key]
	configuration_committed(not native_plan.is_empty())
	save_dirty=true
	var changed:Array=[];var resource_ids:Array=[];var material_changed:=false
	for purchase in plan.purchases:
		changed.append(slot_id(purchase.category,int(purchase.index)))
		for id in purchase.costs:
			if id==db.evolution_material_id():material_changed=true
			elif not resource_ids.has(id):resource_ids.append(id)
	resources_changed(resource_ids)
	if material_changed:event.emit("hyperspace_changed",{"reason":"equipment_evolution"})
	for purchase in plan.purchases:
		event.emit("upgrade",{"key":purchase.before.key,"slot":slot_id(purchase.category,int(purchase.index)),"levels":purchase.levels,"cost":purchase.costs,"batch":batch})
	if batch:event.emit("upgrades_completed",{"slots":changed})
	return true

func upgrade_max(key: String) -> bool:
	var levels := max_upgrade_amount(key)
	return levels > 0 and upgrade(key, levels)

func leave(next: State) -> void:
	if manual_hyperspace.active:manual_hyperspace.finish(self,false,"user_exit")
	settle_drops()
	projectiles.clear()
	enemies.clear()
	paused = false
	change_state(next)

func weapon_cooldown_after_shot(_remaining_before: float, _dt: float, interval: float) -> float:
	# Every multiplier uses the same fixed-step attack schedule as X1.
	return interval

func settle_enemy_shield(enemy: Dictionary, at: float) -> bool:
	if native_execution!=null:return true
	if float(enemy.hp)<=0 or float(enemy.get("max_shield",0))<=0:return true
	var before := float(enemy.get("shield_updated_at",at))
	if at+0.000000001<before:
		push_error("ENEMY_SHIELD_TIME_CONTRACT uid=%s event=%s ledger=%s"%[enemy.get("uid",-1),at,before])
		return false
	if at<=before:return true
	var ready_at := float(enemy.get("shield_hit_at",at))+float(enemy.get("shieldDelay",0))
	var healing_time := maxf(0,at-ready_at)-maxf(0,before-ready_at)
	if healing_time>0:
		enemy.shield=N.minimum(enemy.max_shield,N.add(enemy.shield,N.multiply(enemy.max_shield,float(enemy.get("shieldRecovery",0))*healing_time)))
	enemy.shield_updated_at=at
	return true

func advance_enemy_shields(dt: float) -> void:
	enemy_shield_time+=dt
	for enemy in enemies:settle_enemy_shield(enemy,enemy_shield_time)

func prepare_logical_step(dt:float)->bool:
	if native_execution!=null and native_execution.advance_blocked:
		native_step_phase="blocked";paused=true;return false
	if galaxy_runtime.prepare_advance(self,dt):return true
	native_step_phase="blocked";paused=true
	return false

func tick(dt: float) -> void:
	if logical_step_active:return
	logical_step_active=true
	_tick_logical_step(dt)
	logical_step_active=false
	if native_step_phase!="blocked":manual_hyperspace.dispatch_queued(self)

func _tick_logical_step(dt: float) -> void:
	if paused:return
	if native_execution!=null and native_execution.advance_blocked:
		paused=true
		push_error("Native combat step remains blocked pending explicit cancellation or successful transfer")
		return
	var native_at_entry=native_execution
	# Presented.tick already advanced motion on a legacy entry. Handoff restores
	# kernel.clock, so restore the captured step endpoint rather than adding twice.
	var motion_step_end:=float(get("motion_clock"))+(dt if native_at_entry!=null else 0.0) if "motion_clock" in self else 0.0
	native_step_phase="shared";native_step_remaining=dt
	# A galaxy refit must transfer before this step changes clocks, income or
	# region work. Failed preparation leaves the complete step in the caller.
	if not prepare_logical_step(dt):return
	advance_shared_clock_and_economy(dt)
	if native_step_phase=="blocked":return
	if native_execution!=null and native_execution.paused_by_configuration:
		native_execution.handoff_to_legacy(self,"configuration_notification")
	# Presented.tick advanced this clock itself on a legacy entry. If a shared
	# callback handed off a native entry, only its unexecuted combat phase remains.
	if native_at_entry!=null and native_execution==null and native_step_remaining>0 and "motion_clock" in self:
		set("motion_clock",motion_step_end)

	if native_wave_waiting and state==State.COMBAT:
		if not advance_jewel_repair(dt):return
		if damage_stats.enabled:damage_stats.advance(dt)
		finish_combat_step(dt)
		if has_alive_enemy():native_wave_waiting=false
		return
	if state==State.COMBAT and native_execution_requested and native_execution==null:
		if not admit_native_compiled_execution(native_execution_scope):
			native_execution_requested=false
			# Cold whole-encounter legacy selection. No native state was installed.
	if native_execution!=null:
		if native_execution.advance(self,dt):
			if damage_stats.enabled:damage_stats.advance(dt)
			native_step_phase="idle";native_step_remaining=0.0
			return
		# A failed transfer retains the owner and the unconsumed combat phase.
		if native_execution!=null:return
		# Successful transfer resumes only combat; shared economy already ran.
		if "motion_clock" in self:set("motion_clock",motion_step_end)
	if damage_stats.enabled and state==State.COMBAT:damage_stats.advance(dt)
	if state == State.LEVEL_CLEAR:
		if not advance_jewel_repair(dt):return
		if state!=State.LEVEL_CLEAR:return
		tick_projectiles(dt)
		if state != State.LEVEL_CLEAR:
			return
		if not pending_unlocks.is_empty():
			return
		clear_timer -= dt
		if clear_timer <= 0:
			if guarding_here():
				respawn_guard()
			else:
				advance_after_clear()
		return
	if state == State.RETREAT:
		tick_projectiles(dt)
		retreat_elapsed += dt
		var duration := clampf(float(db.defaults.get("deathRetreatDuration", 1.2)),0.001,MAX_TRAVEL_SECONDS)
		distance = lerpf(retreat_from, retreat_target, clampf(retreat_elapsed / duration, 0, 1))
		if retreat_elapsed >= duration:
			distance = retreat_target
			reset_player()
			if not player_alive():
				change_state(State.LEVEL_SELECT)
				event.emit("battle_blocked",{"reason":"zero_defence"})
				save_dirty=true
				return
			change_state(State.TRAVEL)
			if profile.loop and int(profile.get("guardDeath", 0)) == 2:
				guard_index = mini(group_index, db.levels[stage-1].groups.size()-1)
				profile.guardStage = stage
				profile.guardIndex = guard_index
				profile.guardDistance = distance
				resume_guard()
				save_dirty = true
		return
	if not is_active():
		return
	if state==State.COMBAT:
		_legacy_begin_defence_span(dt)
		drone_combat.advance_boundary(self,dt)
		if _legacy_defence_stopped():_legacy_end_defence_span();return
	else:
		drone_combat.advance(self,dt)
		if not advance_jewel_repair(dt):return
		if state==State.RETREAT:return
	advance_jewel_repeats(dt)
	if _legacy_defence_span_active and _legacy_defence_stopped():_legacy_end_defence_span();return
	if state == State.TRAVEL:
		tick_projectiles(dt)
		if state != State.TRAVEL:
			return
		if retreat_boss_pending:
			retreat_boss_pending = false
			spawn_group(true)
			return
		if is_inf(travel_origin):travel_origin=distance
		distance += travel_movement() * dt
		var level: Dictionary = db.levels[stage - 1]
		if group_index < level.groups.size() and distance+0.000001 >= float(level.groups[group_index].position)*float(level.length):
			spawn_group()
		return
	projectiles = projectiles.filter(func(p): return not p.get("beam", false) or long_laser_valid(p) or endless_beam_eligible(p))
	for index in range(combat_weapon_entries().size()):
		var entry: Dictionary = combat_weapon_entries()[index]
		var key := str(entry.key)
		if key.is_empty():
			continue
		var weapon := player_weapon_row(entry)
		if float(weapon.cd) <= 0:
			continue
		if key == "longLaser":
			lock_long_laser(player, weapon, false, index, entry)
			continue
		var id := slot_id("weapons", index)
		var remaining := float(cooldowns.get(id, float(weapon.cd)))
		var cooldown_after_step := remaining-dt
		cooldowns[id] = maxf(0, cooldown_after_step)
		if cooldowns[id] <= 0:
			var candidates := targets(int(weapon.dmgtype))
			var scatter: bool=key=="laser" and not hyperspace_totals().legendary.get("scatter_pulse",{}).is_empty()
			var count := ((1 if drone_combat.next_is_wild(self) else int(weapon.para1)) if key == "missile" else candidates.size() if scatter else 1)
			if not candidates.is_empty():
				begin_enhancement_attack(index,candidates[0])
				record_enhancement_attack()
			var charged := float(jewel_charged.get(id, 1.0))
			if count > 0 and not candidates.is_empty():
				jewel_charged.erase(id)
			for i in range(count):
				if candidates.is_empty():
					break
				var target := candidates[i % candidates.size()] if key == "missile" or scatter else candidates[0]
				jewel_fire(index, target, weapon, player_weapon_offset(index), charged, missile_visual_spread(i,count) if key=="missile" else 0.0,i,count)
			if count > 0 and not candidates.is_empty():
				cooldowns[id] = weapon_cooldown_after_shot(remaining,dt,float(weapon.cd))
				launch_enhancement_secondary(index,candidates[0],weapon,charged)
				queue_jewel_repeats(index, charged)
				finish_enhancement_attack(index)
	for enemy in enemies:
		if enemy.hp <= 0:
			continue
		for i in range(enemy.equipment.size()):
			if str(enemy.equipment[i].name).replace("_mon", "").replace("-mon", "") == "longLaser":
				lock_long_laser(enemy, db.enemy_weapon(enemy.equipment[i].name), true, i, enemy.equipment[i])
				continue
			var cooldown_before := float(enemy.cooldowns[i])
			enemy.cooldowns[i] = maxf(0.0,cooldown_before-dt)
			if enemy.cooldowns[i] <= 0:
				var entry: Dictionary = enemy.equipment[i]
				var weapon := db.enemy_weapon(entry.name)
				var raw := db.enemy_attack_damage(enemy,weapon,stage,group_index-1)
				fire(enemy, player, weapon, raw, true, entry.name, enemy_weapon_offset(enemy, i))
				enemy.cooldowns[i] = weapon_cooldown_after_shot(cooldown_before,dt,float(weapon.cd))
	tick_projectiles(dt)
	for enemy in enemies:settle_enemy_shield(enemy,enemy_shield_time)
	finish_combat_step(dt)

func projectile_target_point(shot:Dictionary)->Vector2:
	return Vector2(shot.target.x,shot.target.y)

func tick_projectiles(dt: float) -> void:
	if native_execution!=null:
		push_error("legacy executor called during native ownership");return
	if state==State.COMBAT and not _legacy_defence_span_active:_legacy_begin_defence_span(dt)
	_tick_legacy_projectiles(dt)
	_legacy_end_defence_span()

func _tick_legacy_projectiles(dt: float) -> void:
	# Overrides select pending launches at step start; only this base advances
	# the shield clock, before resolving scheduled periods and boundary hits.
	if state==State.COMBAT or _legacy_defence_span_active:enemy_shield_time+=dt
	var pending := projectiles.duplicate()
	# Player defence needs the same ordered periods even without enemy shields.
	tick_shield_beams(pending,dt)
	if not _legacy_advance_defence_to(enemy_shield_time):return
	for index in pending.size():
		if _legacy_defence_span_active and _legacy_defence_stopped():break
		var shot: Dictionary = pending[index]
		# Usually the live array retains its order for the whole step. Identity at
		# the snapshot index avoids a full membership scan for every flying shot.
		# Hits/signals may clear, replace or reorder it; retain the original check
		# whenever that position no longer holds this exact projectile.
		if (index>=projectiles.size() or not is_same(projectiles[index],shot)) and not projectiles.has(shot):
			continue
		if shot.get("chain_hop",false):
			advance_chain_projectile(shot,dt)
			continue
		if advance_higgs_projectile(shot,dt):continue
		if advance_custom_projectile(shot,dt):continue
		if shot.get("beam", false):continue
		if not shot.target.is_empty():
			var target_dead: bool = not player_alive() if shot.hostile else shot.target.hp <= 0 or not enemies.has(shot.target)
			if target_dead:
				# Keep the last heading; a missile never acquires a replacement target.
				shot.target = {}
		if not shot.target.is_empty():
			var impact_point:Vector2=projectile_target_point(shot)
			var delta := impact_point-Vector2(shot.x,shot.y)
			var homing: bool = str(shot.key).replace("_mon", "").replace("-mon", "") == "missile"
			if homing:shot.direction = delta.normalized()
			# Ordinary rounds keep their launch direction. A moving target must
			# intersect this step's segment; proximity alone must not bend the shot.
			var along: float = delta.dot(shot.direction)
			var intersects := along>=0 and along<=float(shot.speed)*dt and absf(delta.cross(shot.direction))<=0.5
			if shot.has("fixed_screen_step"):
				var ratio:=fixed_ballistic_contact(shot,dt)
				if ratio>=0:
					intersects=ratio<=1.0
					if intersects:impact_point=Vector2(shot.x,shot.y)+Vector2(shot.direction)*float(shot.speed)*dt*ratio
			if (delta.length() <= shot.speed*dt) if homing else intersects:
				shot.dead = true
				event.emit("projectile_impact", {"shot":shot,"pos":impact_point})
				if shot.hostile:
					hit_player(shot.damage,shot.type,{"source_uid":int(shot.get("source_uid",0)),"weapon_key":str(shot.key)})
				else:
					hit_enemy(shot.target, shot.damage, shot.type, shot.get("jewelEffects", []),shot.get("critical",false),shot.get("combat_context",{}))
					# Final-group defeat clears the live array; skip its stale snapshot.
					if projectiles.is_empty():
						return
				continue
		var move: Vector2 = shot.direction * float(shot.speed) * dt
		shot.x += move.x
		shot.y += move.y
		# Include the rendered trail before removing an off-screen projectile.
		if shot.x < -32 or shot.x > BATTLE_SIZE.x+32 or shot.y < -32 or shot.y > BATTLE_SIZE.y+32:
			shot.dead = true
	projectiles = projectiles.filter(func(p): return not p.dead and (not p.get("beam", false) or long_laser_valid(p) or endless_beam_eligible(p)))

func fixed_ballistic_contact(_shot:Dictionary,_dt:float)->float:
	return -1.0

func advance_custom_projectile(_shot: Dictionary, _dt: float) -> bool:
	return false

# Existing feature identity and fragment currency remain compatible with unlocks and furnace production.
func jewels_unlocked() -> bool:
	return content_unlocked("feature", "jewels")

func jewel_ratio() -> float:
	var value = db.levels[clampi(stage-1,0,db.levels.size()-1)].get("jewelRatio",1.0)
	return float(value) if nonnegative_number(value) else 1.0

func jewel_fragment_amount(amount: Variant, ratio := -1.0) -> Variant:
	if not N.valid(amount):
		return 0.0
	var factor: float=jewel_ratio() if ratio < 0 else ratio
	if not amount is Dictionary:
		var ordinary := float(amount)*factor
		if nonnegative_number(ordinary):return snappedf(ordinary,0.01)
	var result=N.multiply(amount,factor)
	if not N.valid(result):return 0.0
	if result is Dictionary:
		# GrowthNumber only keeps a mantissa/exponent outside the float domain;
		# sub-cent underflow is zero, while a huge amount has no visible cents.
		return 0.0 if float(result.e)<-2.0 else result
	return snappedf(float(result),0.01)

func settle_jewel_fragments(amount: float, source: String, ratio := -1.0) -> Variant:
	var production_bonus: float=1.0+float(hyperspace_totals().hangings.get("gem_refiner",0)) if source in ["drop","furnace"] else 1.0
	var reactor_bonus=reactor_multiplier("condensation") if source=="drop" else 1.0
	var gem_factor=N.multiply(N.multiply(crew.system_effect(self,"gem_bonus"),reactor_bonus),galaxy.multiplier("gem_fragment")) if source=="drop" else 1.0
	var input=N.multiply(N.multiply(amount,production_bonus),gem_factor)
	var earned = N.multiply(jewel_fragment_amount(input,ratio),research.income_factor(self,"fragment_income"))
	economy.credit_fragments(earned)
	# Production only: refunds must not inflate future income.
	if source in ["drop","furnace"] and N.compare(earned,0) > 0:
		resource_samples.append({"time":economy_time(),"production_time":production_time(),"id":"jewel","amount":earned,"origin":source})
		record_research_income("jewel")
	event.emit("enhancement_currency", {"amount":earned,"source":source})
	return earned

func pickup_jewel_fragment(_legacy_id := "") -> bool:
	if not jewels_unlocked():
		return false
	settle_jewel_fragments(1.0,"drop")
	enhancement_currency_changed()
	return true

func jewel_kill_drop(enemy: Dictionary) -> void:
	if enemy.get("jewelDropChecked", false):
		return
	enemy.jewelDropChecked = true
	if not jewels_unlocked():return
	var roll_count:int=preload("res://scripts/candidate_rewards.gd").rolls(enemy.get("jewelDropRolls",1))
	if roll_count<0:return
	for roll in roll_count:
		if rng.randf()>=float(db.config.get("jewelDrop",0)):continue
		uid += 1
		drops.append({"uid":uid,"x":enemy.x,"y":enemy.y+65,"age":0.0,"jewel":true,"jewelRatio":jewel_ratio(),"id":"jewel","amount":1})

func default_enhancement_order() -> Dictionary:
	return EnhancementGrowth.default_order()

func default_enhancement_branches() -> Dictionary:
	return EnhancementGrowth.default_branches()

func enhancement_effect_threshold(index: int) -> int:
	return EnhancementGrowth.effect_threshold(db,index)

func enhancement_branch_threshold(node: int, category: String, effect: String) -> int:
	return enhancement_growth.branch_threshold(db,node,category,effect)

func valid_enhancement_branch(category: String, effect: String, node: int) -> bool:
	return EnhancementGrowth.valid_branch(category,effect,node)

func enhancement_branch_unlocked(category: String, effect: String, node: int) -> bool:
	return enhancement_growth.branch_unlocked(db,category,effect,node,enhancement_effective_level(),enhancement_unlocked())

func enhancement_branch_choices(category: String, effect: String) -> Dictionary:
	return enhancement_growth.branch_choices(category,effect)

func enhancement_branch_choice(category: String, effect: String, node: int) -> String:
	return enhancement_growth.branch_choice(category,effect,node)

func set_enhancement_branch(category: String, effect: String, node: int, choice: String) -> bool:
	if not enhancement_branch_unlocked(category,effect,node) or choice not in ["A","B"]:return false
	if enhancement_branch_choice(category,effect,node)==choice:return true
	var plan:=enhancement_growth.prepare_branch(db,category,effect,node,choice,enhancement_effective_level(),enhancement_unlocked())
	if plan.is_empty() or not native_before_configuration_change() or not enhancement_growth.proposal_current(plan):return false
	enhancement_growth.commit_configuration(plan)
	# Selection invalidates projections and only the removed branch's transient buffs.
	configuration_committed()
	enhancement_branches.reconcile(self)
	sync_enhancement_buffers()
	if player.has("armour"):
		player.armour=N.minimum(player.armour,stat("armour"))
		player.shield=N.minimum(player.shield,max_shield())
	save_dirty = true
	event.emit("enhancement_changed",{"category":category,"effect":effect,"node":node,"choice":choice})
	return true

func enhancement_branch_metadata(category: String, effect: String, node: int, choice: String) -> Dictionary:
	if not valid_enhancement_branch(category,effect,node) or choice not in ["A","B"]:return {}
	var prefix := "enhance.branch.%s.%d.%s" % [effect,node,choice]
	var parameters := {}
	if choice=="A":
		match effect:
			"proficiency":parameters.damage_percent=enhancement_parameter("proficiency_a_damage_bonus")*100.0
			"repeat":parameters.probability_percent=enhancement_parameter("repeat_a_probability")*100.0
			"critical":parameters.probability_percent=enhancement_parameter("critical_a_probability")*100.0
			"adaptation":parameters.defence_percent=enhancement_parameter("adaptation_a_capacity_bonus")*100.0
			"memory_material":parameters.bonus_percent=enhancement_parameter("memory_a_bonus")*100.0
			"delayed_damage":parameters.probability_percent=enhancement_parameter("deferred_a_clear_probability")*100.0
	else:
		match effect+str(node):
			"proficiency1":parameters={"interval":enhancement_parameter("proficiency_b1_interval"),"damage_percent":enhancement_parameter("proficiency_b1_growth")*100.0}
			"proficiency2":parameters.reduction_percent=(1.0-enhancement_parameter("proficiency_b2_interval_multiplier"))*100.0
			"proficiency3":parameters.resistance_percent=enhancement_parameter("proficiency_b3_resistance")*100.0
			"repeat1":parameters.extra_targets=int(enhancement_parameter("repeat_b1_targets"))
			"repeat2":parameters.extra_repeats=int(enhancement_parameter("repeat_b2_repeats"))
			"repeat3":parameters.probability_percent=enhancement_parameter("repeat_b3_probability")*100.0
			"critical1":parameters={"attacks":int(enhancement_parameter("critical_b1_attacks")),"damage_percent":enhancement_parameter("critical_b1_damage_bonus")*100.0}
			"critical2":parameters={"probability_percent":enhancement_parameter("critical_b2_probability")*100.0,"damage_percent":enhancement_parameter("critical_b2_damage_bonus")*100.0,"stacks":int(enhancement_parameter("critical_b2_stacks")),"duration":enhancement_parameter("critical_b2_duration")}
			"critical3":parameters.probability_percent=enhancement_parameter("critical_b3_guaranteed_rate")*100.0
			"adaptation1":parameters={"reduction_percent":enhancement_parameter("adaptation_b1_reduction")*100.0,"stacks":int(enhancement_parameter("adaptation_b1_stacks"))}
			"adaptation2":parameters={"interval":enhancement_parameter("adaptation_b2_interval"),"duration":enhancement_parameter("adaptation_b2_duration"),"capacity_percent":enhancement_parameter("adaptation_b2_capacity_multiplier")*100.0}
			"adaptation3":parameters.resistance_percent=clampf(float(db.config.dmgReduce)+enhancement_parameter("adaptation_b3_resistance_bonus"),0,1)*100.0
			"memory_material1":parameters={"probability_percent":enhancement_parameter("memory_b1_probability")*100.0,"reduction_percent":enhancement_parameter("memory_b1_reduction")*100.0,"duration":enhancement_parameter("memory_b1_duration")}
			"memory_material2":parameters={"resistance_percent":enhancement_parameter("memory_b2_resistance")*100.0,"duration":enhancement_parameter("memory_b2_duration"),"lockout":enhancement_parameter("memory_b2_lockout")}
			"memory_material3":parameters={"charge_percent":enhancement_parameter("memory_b3_shield_charge_bonus")*100.0,"capacity_percent":enhancement_parameter("memory_b3_armour_capacity_bonus")*100.0}
			"delayed_damage1":parameters={"reduction_percent":enhancement_parameter("deferred_b1_reduction")*100.0,"duration":enhancement_parameter("deferred_b1_duration")}
			"delayed_damage2":
				parameters.conversion_percent=enhancement_parameter("deferred_b2_probability_conversion")*100.0
				parameters.reduction_percent=enhancement_branches.clear_underlying_probability(self,node,choice)*enhancement_parameter("deferred_b2_probability_conversion")*100.0
			"delayed_damage3":
				parameters.full_probability_percent=enhancement_parameter("deferred_b3_forced_probability")*100.0
				parameters.damage_percent=(1.0-enhancement_branches.clear_underlying_probability(self,node,choice))*enhancement_parameter("deferred_b3_damage_scale")*100.0
	if effect=="memory_material" and node==2 and choice=="B":
		var strengths: Array=defense_entries().filter(func(entry):return not memory_effect(entry).is_empty()).map(func(entry):return enhancement_branches.resistance(self,entry,enhancement_parameter("memory_b2_resistance"))*100.0)
		parameters.resistance_min_percent=strengths.min() if not strengths.is_empty() else parameters.resistance_percent
		parameters.resistance_max_percent=strengths.max() if not strengths.is_empty() else parameters.resistance_percent
		parameters.resistance_percent=parameters.resistance_min_percent
	return {"category":category,"effect":effect,"node":node,"choice":choice,"implemented":true,"selected":enhancement_branch_choice(category,effect,node)==choice,"unlocked":enhancement_branch_unlocked(category,effect,node),"title_text_id":prefix+".title","description_text_id":prefix+".description","parameters":parameters}

func enhancement_effect_runtime(effect: String, entry: Dictionary = {}) -> Dictionary:
	var category := "weapons" if effect in ["proficiency","repeat","critical"] else "defence"
	var eligible: Array=loadout_entries(category).filter(func(candidate):return enhancement_effects(candidate).any(func(value):return value.kind==effect))
	var sample: Dictionary=entry if not entry.is_empty() else (eligible[0] if not eligible.is_empty() else {})
	var active_level := enhancement_effective_level() if has_enhancement_effect(sample,effect) else 0
	var result := {"effect":effect,"effective_level":enhancement_effective_level(),"eligible_modules":eligible.size(),"entry_specific":not entry.is_empty()}
	match effect:
		"proficiency","adaptation":
			result.growth=enhancement_parameter(effect+"_growth") if active_level>0 else 0.0
			result.history=enhancement_growth.history(effect)
			result.history_bonus_percent=enhancement_growth.history_bonus(db,effect,active_level,float(result.growth))*100.0
			result.branch_bonus_percent=enhancement_branches.a_count(self,sample,effect)*enhancement_parameter("proficiency_a_damage_bonus" if effect=="proficiency" else "adaptation_a_capacity_bonus")*100.0
		"repeat":
			result.probability_percent=enhancement_branches.repeat_probability(self,sample)*100.0
			result.damage_percent=enhancement_parameter("repeat_growth")*active_level*100.0
			result.delay=enhancement_parameter("repeat_delay")
		"critical":
			var critical:=jewel_critical(sample) if not sample.is_empty() else Vector2(0,1)
			var base_chance:=enhancement_parameter("base_critical_rate") if active_level>0 else 0.0
			if not sample.is_empty():base_chance+=float(db.equip(str(sample.key),int(sample.level)).get("cri",0))+enhancement_branches.a_count(self,sample,"critical")*enhancement_parameter("critical_a_probability")
			result.base_probability_percent=clampf(base_chance,0,1)*100.0
			result.probability_percent=critical.x*100.0;result.damage_multiplier=critical.y
			result.underlying_probability_percent=enhancement_branches.underlying_critical_rate(self,sample)*100.0 if not sample.is_empty() else 0.0
		"memory_material":
			result.interval=enhancement_parameter("memory_interval")
			result.heal_percent=enhancement_parameter("memory_heal_fraction")*active_level*enhancement_branches.memory_heal_multiplier(self,sample)*100.0
			result.charge_percent=enhancement_parameter("memory_heal_fraction")*active_level*enhancement_branches.memory_charge_multiplier(self,sample)*100.0
			result.capacity_percent=enhancement_parameter("memory_buffer_fraction")*active_level*enhancement_branches.memory_cap_multiplier(self,sample)*100.0
		"delayed_damage":
			result.fraction_percent=enhancement_deferred_fraction(active_level)*100.0;result.duration=enhancement_parameter("deferred_duration");result.interval=enhancement_parameter("deferred_interval")
			result.probability_percent=enhancement_branches.clear_probability(self)*100.0;result.underlying_probability_percent=enhancement_branches.clear_underlying_probability(self)*100.0
	return result

func enhancement_parameter(key: String) -> float:
	if compiled_combat_rules!=null and not compiled_combat_rules.compiling:
		compiled_combat_rules.compile(self)
		return float(compiled_combat_rules.parameters[key])
	return float(db.data.enhance_config[key].value)

func enhancement_unlocked() -> bool:
	return jewels_unlocked()

func enhancement_level() -> int:
	return enhancement_growth.level()

func enhancement_level_bonus() -> int:
	return gem_drop_level_bonus()

func enhancement_effective_level() -> int:
	return enhancement_level() + enhancement_level_bonus()

func enhancement_level_limit() -> int:
	return EnhancementGrowth.LEVEL_LIMIT

func enhancement_at_limit() -> bool:
	return enhancement_level()>=enhancement_level_limit()

func enhancement_cost(target_level := -1) -> Variant:
	return enhancement_growth.cost(db,target_level)

func can_upgrade_enhancement() -> bool:
	return enhancement_unlocked() and not enhancement_at_limit() and N.compare(economy.balance("jewel"),enhancement_cost())>=0

func enhancement_purchase_cost(count: int) -> Variant:
	return enhancement_growth.purchase_cost(db,count)

func enhancement_max_upgrades(limit := -1) -> int:
	return enhancement_growth.max_upgrades(db,economy.balance("jewel"),limit) if enhancement_unlocked() else 0

func upgrade_enhancement(count := 1) -> int:
	if count==0 or not enhancement_unlocked():return 0
	var plan:=enhancement_growth.prepare_upgrade(db,economy.balance("jewel"),count)
	if plan.is_empty():return 0
	var wallet_revision:=economy.revision
	if not native_before_configuration_change():return 0
	if wallet_revision!=economy.revision or not enhancement_growth.proposal_current(plan):return 0
	# The quoted expense and growth are committed without intervening callbacks.
	if not economy.debit({"jewel":plan.cost}):return 0
	enhancement_growth.commit_configuration(plan)
	configuration_committed();sync_enhancement_buffers();save_dirty=true
	event.emit("enhancement_changed", {"purchased":plan.purchased})
	event.emit("jewels_changed", {"slot":"","slots":[]})
	for category in ["weapons","defence"]:event.emit("equipment_stats",{"category":category})
	return int(plan.purchased)

func enhancement_order(category: String) -> Array:
	return enhancement_growth.order(category)

func valid_enhancement_order(category: String, value: Variant) -> bool:
	return EnhancementGrowth.valid_order(category,value)

func set_enhancement_order(category: String, order: Array) -> bool:
	if not enhancement_unlocked() or not valid_enhancement_order(category,order):return false
	if enhancement_order(category)==order:return true
	var plan:=enhancement_growth.prepare_order(category,order)
	if plan.is_empty() or not native_before_configuration_change() or not enhancement_growth.proposal_current(plan):return false
	enhancement_growth.commit_configuration(plan)
	configuration_committed()
	enhancement_branches.reconcile(self)
	sync_enhancement_buffers()
	if player.has("armour"):
		player.armour=N.minimum(player.armour,stat("armour"))
		player.shield=N.minimum(player.shield,max_shield())
	save_dirty = true
	event.emit("enhancement_changed", {"category":category})
	event.emit("jewels_changed", {"slot":"","slots":[]})
	for kind in ["weapons","defence"]:event.emit("equipment_stats",{"category":kind})
	return true

func available_effect_count(entry: Dictionary) -> int:
	var key := str(entry.get("key",""))
	if key not in WEAPON_KEYS and key not in DEFENSE_KEYS:return 0
	return shared_enhancement_effect_count()

func shared_enhancement_effect_count() -> int:
	if compiled_combat_rules!=null and not compiled_combat_rules.compiling:
		compiled_combat_rules.compile(self)
		return compiled_combat_rules.effect_count
	return EnhancementGrowth.effect_count(db,enhancement_effective_level(),enhancement_unlocked())

func record_enhancement_attack() -> void:
	enhancement_growth.record_attack();save_dirty=true
	event.emit("equipment_stats",{"category":"weapons"})

func record_enhancement_hit() -> void:
	enhancement_growth.record_hit();save_dirty=true
	event.emit("equipment_stats",{"category":"defence"})

func commit_enhancement_counters(attacks:int,hits:int,notify:bool=true)->void:
	var changed:=enhancement_growth.commit_combat_counters(attacks,hits)
	if changed.is_empty():return
	save_dirty=true
	if notify:
		for category in changed:event.emit("equipment_stats",{"category":category,"counter_only":true})

func enhancement_currency_changed() -> void:
	save_dirty = true
	event.emit("jewels_changed", {"slot":"","slots":[]}) # Legacy event name retained for currency consumers.

func enhancement_effects(entry: Dictionary) -> Array:
	if compiled_combat_rules!=null and not compiled_combat_rules.compiling:
		compiled_combat_rules.compile(self)
		var copies:Array=[]
		for effect in compiled_combat_rules.effects(entry):copies.append(effect.duplicate(true))
		return copies
	var result: Array = []
	if str(entry.get("key","")).is_empty() or not enhancement_unlocked():return result
	var category := "weapons" if WEAPON_KEYS.has(str(entry.key)) else "defence"
	var order := enhancement_order(category)
	var level := enhancement_effective_level()
	for i in available_effect_count(entry):
		var kind := str(order[i])
		if not kind.is_empty():result.append(_enhancement_effect(kind,i,level))
	return result

func _enhancement_effect(kind: String, i: int, level: int) -> Dictionary:
	return EnhancementGrowth.effect(db,kind,i,level)

func active_enhancement_effect_count(entry: Dictionary) -> int:
	return available_effect_count(entry)

func _enhancement_effect_index(entry: Dictionary, kind: String) -> int:
	if compiled_combat_rules!=null and not compiled_combat_rules.compiling:
		compiled_combat_rules.compile(self)
		return compiled_combat_rules.effect_index(entry,kind)
	# Scalar membership query; no effect payloads or retained/cross-tick cache.
	if kind.is_empty():return -1
	var count := active_enhancement_effect_count(entry)
	if count<=0:return -1
	var category := "weapons" if WEAPON_KEYS.has(str(entry.key)) else "defence"
	var position:=enhancement_growth.order_position(category,kind)
	return position if position>=0 and position<count else -1

func has_enhancement_effect(entry: Dictionary, kind: String) -> bool:
	return _enhancement_effect_index(entry,kind)>=0

func jewel_effects(entry: Dictionary) -> Array:
	return enhancement_effects(entry)

func jewel_equipment_stat(entry: Dictionary, level := -1, effects: Variant = null, include_timed_buffs := true, galaxy_equipment := -1.0, galaxy_charge := -1.0) -> Variant:
	return attributes.jewel_equipment_stat(self,entry,level,effects,include_timed_buffs,galaxy_equipment,galaxy_charge)

func jewel_critical(entry: Dictionary, effects: Variant = null, include_timed_buffs := true, drone_totals: Dictionary = {}) -> Vector2:
	return attributes.jewel_critical(self,entry,effects,include_timed_buffs,drone_totals)

func begin_enhancement_attack(index: int, target: Dictionary, derived := false, track_primary := true) -> Dictionary:
	var context := enhancement_branches.begin_attack(self,index,target,derived,track_primary)
	enhancement_attack_contexts[index]=context
	return context

func finish_enhancement_attack(index: int) -> void:
	if enhancement_attack_contexts.has(index):enhancement_branches.finish_attack(self,enhancement_attack_contexts[index])
	enhancement_attack_contexts.erase(index)

func endless_source_slot(weapon_levels:Dictionary={}) -> int:
	# Ordinary enabled weapon slots only; strict > retains the first tied slot.
	# The compiler supplies projected levels before an atomic numeric upgrade.
	var entries:=weapon_entries()
	var best:=-1
	var best_level:=-1
	for index in entries.size():
		var entry:Dictionary=entries[index]
		if entry.key!="longLaser":continue
		var level:=int(weapon_levels.get(index,entry.level))
		if best<0 or level>best_level:best=index;best_level=level
	return best

func endless_source() -> Dictionary:
	return attributes.endless_source(self)

func player_weapon_row(entry: Dictionary, drone_totals: Dictionary = {}, endless_selected:Variant=null) -> Dictionary:
	return attributes.player_weapon_row(self,entry,drone_totals,endless_selected)

func jewel_attack(index: int, multiplier := 1.0) -> Dictionary:
	var entry := combat_entry(index)
	var context: Dictionary=enhancement_attack_contexts.get(index,{})
	if not context.has("snapshot"):
		var primary_missile: bool=entry.key=="missile" and not context.get("derived",false)
		var wild_substitute: bool=primary_missile and drone_combat.next_is_wild(self)
		if wild_substitute:context.derived=true
		var birth:=AttackBirth.prepare(self,entry,hyperspace_totals())
		var effects:Array=birth.effects
		var critical := jewel_critical(entry,effects)
		var raw = N.multiply(jewel_equipment_stat(entry,-1,effects),float(context.get("next_multiplier",1.0))*drone_combat.weapon_multiplier(self,str(entry.key)))
		var is_critical := rng.randf() < critical.x
		var critical_bonus_applied := is_critical
		if is_critical:
			if enhancement_branches.active(self,entry,"critical",3,"B"):
				critical_bonus_applied=rng.randf()<enhancement_branches.underlying_critical_rate(self,entry)
			if critical_bonus_applied:raw=N.multiply(raw,critical.y)
			if not context.get("derived",false):context.critical=true
		main_attack_serial+=1
		for effect in effects:
			effect.source=index;effect.weapon_key=str(entry.key);effect.main_attack_id=main_attack_serial
		var secondary:bool=not context.get("derived",false) and birth.secondary_enabled and rng.randf()<float(birth.secondary_probability)
		context.snapshot={"id":main_attack_serial,"damage":raw,"effects":effects,"critical":is_critical,"critical_bonus_applied":critical_bonus_applied,"secondary":secondary,"secondary_used":false,"repeats_queued":false,"repeat_plan":[] if context.get("derived",false) else plan_attack_repeats(entry,effects),"weapon":player_weapon_row(entry).duplicate(true)}
		context.snapshot.combat_context=CombatContext.root(main_attack_serial,"drone:"+str(entry.drone_id) if entry.has("drone_id") else "module:%d"%index,str(entry.key))
		if primary_missile:
			var wild: Dictionary=hyperspace_totals().legendary.get("wild_missile",{})
			var substitute: bool=wild_substitute
			drone_combat.missile_attacks+=1
			if substitute:
				context.snapshot.damage=N.multiply(context.snapshot.damage,float(wild.parameters.damage_multiplier))
				context.snapshot.weapon.para1=1
				context.snapshot.combat_context=CombatContext.derive(context.snapshot.combat_context,"wild_missile")
				context.snapshot.combat_context.wild_missile=true;context.snapshot.combat_context.blast_fraction=float(wild.constants.blast_fraction)
				context.derived=true
		context.snapshot.instance=new_attack_instance(context.snapshot)
		context.instance=context.snapshot.instance
	var attack:=attack_from_snapshot(context.snapshot,multiplier,context.get("instance",{}))
	attack.combat_context=context.snapshot.combat_context
	if context.get("derived",false) and CombatContext.can_trigger(context.snapshot.combat_context):
		if entry.key=="missile":
			# A derived salvo freezes guidance once per target, independently of its shared chain instance.
			if not context.has("derived_combat_context"):context.derived_combat_context=CombatContext.derive_with_chain(context.snapshot.combat_context,"repeat_or_secondary")
			attack.combat_context=context.derived_combat_context
		else:attack.combat_context=CombatContext.derive_with_chain(context.snapshot.combat_context,"repeat_or_secondary")
	return attack

func attack_from_snapshot(snapshot: Dictionary, multiplier: float, instance: Dictionary = {}) -> Dictionary:
	# A salvo shares one attack instance; independent repeats retain the root roll
	# but receive a fresh instance. Never deep-copy the shared chain state.
	if instance.is_empty():
		if not snapshot.has("instance"):snapshot.instance=new_attack_instance(snapshot)
		instance=snapshot.instance
	if compiled_combat_rules!=null:
		compiled_combat_rules.bind_instance(snapshot,instance)
		return {"attack_instance_id":instance.id,"main_attack_id":snapshot.id,"damage":N.multiply(snapshot.damage,multiplier),"effects":instance.effects,"critical":snapshot.critical,"critical_bonus_applied":snapshot.critical_bonus_applied}
	var effects: Array=[]
	for source in snapshot.effects:
		var effect: Dictionary=source.duplicate(true)
		if effect.get("chain",false):effect.chain_state=instance.chain
		effects.append(effect)
	return {"attack_instance_id":instance.id,"main_attack_id":snapshot.id,"damage":N.multiply(snapshot.damage,multiplier),"effects":effects,"critical":snapshot.critical,"critical_bonus_applied":snapshot.critical_bonus_applied}

func plan_attack_repeats(entry: Dictionary, effects: Array) -> Array:
	# All bounded generations roll now; delayed execution never rolls again.
	var plan: Array=[]
	var beam_charge := 0.0
	if str(entry.key)=="longLaser":
		var row := player_weapon_row(entry)
		beam_charge=maxf(0,float(row.para3)) if row.get("para3")!=null else float(row.cd)
	var frontier: Array=[{"depth":0,"delay":0.0,"plan_index":-1}]
	var allowed := 0 # A triggered repeat cannot trigger another repeat.
	while not frontier.is_empty():
		var parent: Dictionary=frontier.pop_front()
		if int(parent.depth)>allowed:continue
		var pending: Array=[]
		for effect in effects:
			if effect.kind=="repeat" and rng.randf()<enhancement_branches.repeat_probability(self,entry):
				pending.append(enhancement_branches.repeat_multiplier(effect))
		for i in pending.size():
			var choice := rng.randi_range(i,pending.size()-1)
			var value: float=pending[choice];pending[choice]=pending[i];pending[i]=value
			var node := {"depth":int(parent.depth)+1,"delay":float(parent.delay)+(beam_charge if int(parent.depth)>0 else 0.0)+enhancement_parameter("repeat_delay")*(i+1),"factor":value,"parent":int(parent.plan_index),"plan_index":plan.size()}
			plan.append(node);frontier.append(node)
			if str(entry.key)=="longLaser":break
	return plan

func missile_visual_spread(index: int, count: int) -> float:
	return (float(index)/float(count-1)-0.5)*minf(88.0,float(count-1)*24.0) if count>1 else 0.0

func jewel_fire(index: int, target: Dictionary, weapon: Dictionary, offset: Vector2, multiplier := 1.0, visual_spread := 0.0, salvo_index := 0, salvo_count := 1) -> void:
	# Every player missile path resolves its live mount here, including repeats.
	if str(combat_entry(index).key)=="missile":
		offset = player_weapon_offset(index)
	var attack := jewel_attack(index,multiplier)
	launch_player_attack(index,target,weapon,attack,offset,visual_spread,salvo_index,salvo_count)

func launch_player_attack(index: int, target: Dictionary, weapon: Dictionary, attack: Dictionary, offset: Vector2, visual_spread: float, _salvo_index: int = 0, _salvo_count: int = 1) -> void:
	var previous_payload: Dictionary=player_launch_payload
	var key: String=str(combat_entry(index).key)
	player_launch_payload={"combat_context":attack.get("combat_context",{}),"entry":combat_entry(index),"mount":index,"main_attack_id":attack.get("main_attack_id",0),"attack_instance_id":attack.get("attack_instance_id",0),"jewelEffects":attack.effects,"critical":attack.critical,"critical_bonus_applied":attack.get("critical_bonus_applied",attack.critical),"rail_width_multiplier":1.0,"salvo_ordinal":_salvo_index}
	if key=="cannon" and CombatContext.can_trigger(player_launch_payload.combat_context):
		var higgs: Dictionary=hyperspace_totals().legendary.get("higgs_cannon",{})
		if not higgs.is_empty():
			player_launch_payload.rail_width_multiplier=1.0+float(higgs.parameters.area_bonus)
			player_launch_payload.higgs={"full_width":RailGeometry.width(db.weapon_motion_value("rail_trail_width",28.0),float(player_launch_payload.rail_width_multiplier)),"hit_uids":{}}
	fire(player,target,weapon,attack.damage,false,key,offset,visual_spread)
	player_launch_payload=previous_payload
	projectiles.back().combat_context=attack.get("combat_context",{})
	freeze_higgs_geometry(projectiles.back())
	projectiles.back().main_attack_id = attack.get("main_attack_id",0)
	projectiles.back().attack_instance_id = attack.get("attack_instance_id",0)
	projectiles.back().jewelEffects = attack.effects
	projectiles.back().critical = attack.critical
	projectiles.back().critical_bonus_applied=attack.get("critical_bonus_applied",attack.critical)

func fire_drone_counter(index: int,multiplier: float) -> void:
	var entry:=combat_entry(index);var weapon:=player_weapon_row(entry)
	var candidates:=targets(int(weapon.dmgtype))
	if candidates.is_empty():return
	begin_enhancement_attack(index,candidates[0],true);record_enhancement_attack()
	if entry.key=="longLaser":
		var attack:=jewel_attack(index,multiplier)
		hit_enemy(candidates[0],attack.damage,int(weapon.dmgtype),attack.effects,attack.critical,attack.combat_context)
	else:
		var count:=int(weapon.para1) if entry.key=="missile" else 1
		for i in count:jewel_fire(index,candidates[i%candidates.size()],weapon,player_weapon_offset(index),multiplier,missile_visual_spread(i,count) if entry.key=="missile" else 0.0,i,count)
	finish_enhancement_attack(index)

func launch_enhancement_secondary(index: int, primary: Dictionary, weapon: Dictionary, multiplier: float, beam_tick := false) -> void:
	var entry := combat_entry(index)
	var context: Dictionary=enhancement_attack_contexts.get(index,{})
	if context.is_empty() or context.get("derived",false) or not context.has("snapshot"):return
	var snapshot: Dictionary=context.snapshot
	if not snapshot.secondary or snapshot.secondary_used:return
	snapshot.secondary_used=true
	var candidates: Array=targets(int(weapon.dmgtype)).filter(func(enemy):return not is_same(enemy,primary))
	if candidates.is_empty():return
	var target: Dictionary=candidates[0]
	context.erase("derived_combat_context")
	context.derived=true
	if beam_tick:
		var attack := jewel_attack(index,multiplier)
		hit_enemy(target,attack.damage,int(weapon.dmgtype),attack.effects,attack.critical,attack.get("combat_context",{}))
	else:
		var count := int(weapon.para1) if str(entry.key)=="missile" else 1
		for i in count:jewel_fire(index,target,weapon,player_weapon_offset(index),multiplier,missile_visual_spread(i,count) if str(entry.key)=="missile" else 0.0,i,count)
	context.derived=false
	context.erase("derived_combat_context")
	event.emit("enhancement_secondary",{"source":Vector2(primary.x,primary.y),"target":Vector2(target.x,target.y),"weapon":str(entry.key),"beam":beam_tick})

func new_attack_instance(snapshot: Dictionary) -> Dictionary:
	attack_instance_serial+=1
	var count:=0
	for effect in snapshot.effects:
		if effect.get("chain",false):
			count=int(effect.get("chain_targets",enhancement_parameter("repeat_b1_targets")));break
	return {"id":attack_instance_serial,"chain":{"instance_id":attack_instance_serial,"count":count,"used":false,"beam":false,"ended":false,"links":[]}}

func chain_target_point(target: Dictionary) -> Vector2:
	return Vector2(target.x,target.y)

func chain_target_alive(target: Dictionary) -> bool:
	return not target.is_empty() and N.compare(target.get("hp",0),0)>0 and enemies.any(func(enemy):return is_same(enemy,target))

func select_chain_targets(primary: Dictionary, type: int, count: int) -> Array:
	var result:Array=[]
	if count<=0:return result
	var visited:Dictionary={int(primary.uid):true}
	for target in targets(type):
		if result.size()>=count:break
		if visited.has(int(target.uid)):continue
		visited[int(target.uid)]=true;result.append(target)
	return result

func bind_beam_chain(shot: Dictionary, rebind:=false) -> void:
	var prism: Dictionary=hyperspace_totals().legendary.get("prism_tower",{})
	if not rebind and not shot.get("repeated",false) and not prism.is_empty() and not projectiles.any(func(p):return not is_same(p,shot) and p.get("prism_tower",false) and long_laser_valid(p)):
		shot.prism_tower=true;shot.attack_instance.chain.count=int(prism.constants.nearby_targets)
		if not shot.get("prism_bonus_applied",false):
			shot.prism_bonus_applied=true
			shot.weapon.para2=float(shot.weapon.para2)+float(prism.parameters.maximum_multiplier_bonus)
			shot.attack_snapshot.weapon.para2=float(shot.attack_snapshot.weapon.para2)+float(prism.parameters.maximum_multiplier_bonus)
	var chain:Dictionary=shot.attack_instance.chain
	chain.beam=true;chain.used=true;chain.ended=false;chain.primary=shot.target
	var candidates:=select_chain_targets(shot.target,int(shot.weapon.dmgtype),enemies.size())
	if shot.get("prism_tower",false):candidates.sort_custom(func(a,b):return chain_target_point(a).distance_squared_to(chain_target_point(shot.target))<chain_target_point(b).distance_squared_to(chain_target_point(shot.target)))
	for target in candidates.slice(0,int(chain.count)):
		chain.links.append({"target":target,"broken":false})

func prune_beam_chain(shot: Dictionary) -> void:
	for link in shot.get("attack_instance",{}).get("chain",{}).get("links",[]):
		if not link.broken and not chain_target_alive(link.target):link.broken=true

func end_beam_chain(shot: Dictionary) -> void:
	var chain:Dictionary=shot.get("attack_instance",{}).get("chain",{})
	if not chain.is_empty():chain.ended=true;chain.links.clear()

func break_beam_chain_target(target: Dictionary, at:float=INF) -> void:
	for shot in projectiles:
		if not shot.get("beam",false):continue
		if is_same(shot.target,target) and endless_beam_eligible(shot) and not shot.get("await_target",false):
			# Freeze at the death instant, not the already-projected step end.
			# Preserve links until the killing hit has propagated its chain.
			if is_finite(at):shot.elapsed=maxf(0.0,float(shot.elapsed)-maxf(0.0,enemy_shield_time-at))
			shot.await_target=true
		for link in shot.get("attack_instance",{}).get("chain",{}).get("links",[]):
			if is_same(link.target,target):link.broken=true

func beam_chain_targets(shot: Dictionary) -> Array:
	# Presentation reads this relation; it never selects/rebinds or mutates it.
	var result:Array=[]
	if not projectiles.has(shot) or not long_laser_valid(shot):return result
	var chain:Dictionary=shot.get("attack_instance",{}).get("chain",{})
	if chain.get("ended",false):return result
	for link in chain.get("links",[]):
		if not link.broken and chain_target_alive(link.target):result.append(link.target)
	return result

func chain_damage_effects(effects: Array) -> Array:
	if compiled_combat_rules!=null:
		for effect in effects:
			if effect.has("chain_state") and effect.chain_state.has("continued_effects"):return effect.chain_state.continued_effects
	var continued:Array=[]
	for source in effects:
		var effect:Dictionary=source.duplicate()
		effect.erase("chain_state")
		effect.chain=false;effect.chain_used=true;continued.append(effect)
	return continued

func launch_enhancement_chain(enemy: Dictionary, raw, type: int, effects: Array, critical: bool, origin := Vector2.INF, context: Dictionary = {}) -> void:
	if not CombatContext.can_chain(context):return
	var effect:Dictionary={}
	for candidate in effects:
		if candidate.get("chain",false) and not candidate.get("chain_used",false):effect=candidate;break
	if effect.is_empty():return
	if not effect.has("chain_state"):
		# Compatibility for direct hit payloads; canonical attacks bind this at startup.
		attack_instance_serial+=1
		effect.chain_state={"instance_id":attack_instance_serial,"count":int(effect.get("chain_targets",enhancement_parameter("repeat_b1_targets"))),"used":false,"beam":false,"ended":false,"links":[]}
	var chain:Dictionary=effect.chain_state
	if chain.ended:return
	if chain.beam:
		# Secondary copies share the instance but are not additional beam ticks.
		if not is_same(enemy,chain.primary):return
		var continued:=chain_damage_effects(effects)
		for link in chain.links:
			if not link.broken and not chain_target_alive(link.target):link.broken=true
			if not link.broken:hit_enemy(link.target,raw,type,continued,critical,CombatContext.derive(context,"chain"))
		return
	if chain.used:return
	chain.used=true
	if not effect.is_read_only():effect.chain_used=true
	var continued:=chain_damage_effects(effects)
	if origin==Vector2.INF:origin=chain_target_point(enemy)
	for target in select_chain_targets(enemy,type,int(chain.count)):
		projectile_serial+=1
		var direction:Vector2=(chain_target_point(target)-origin).normalized()
		if direction.is_zero_approx():direction=Vector2.UP
		# A visible damage carrier starts at the hit, never at a weapon mount.
		var hop:Dictionary={"x":origin.x,"y":origin.y,"launch_point":origin,"target":target,"damage":raw,"type":type,"speed":db.weapon_motion_value("chain_carrier_speed",720.0),"hostile":false,"key":"chain","dead":false,"serial":projectile_serial,"direction":direction,"chain_hop":true,"attack_instance_id":chain.instance_id,"main_attack_id":effect.get("main_attack_id",0),"jewelEffects":continued,"critical":critical,"chain_weapon":effect.get("weapon_key",""),"combat_context":CombatContext.derive(context,"chain")}
		projectiles.append(hop)
		event.emit("enhancement_chain",{"source":origin,"target":chain_target_point(target),"weapon":str(effect.get("weapon_key","")),"shot":hop})

func advance_chain_projectile(shot: Dictionary, dt: float) -> void:
	if shot.dead:return
	if not chain_target_alive(shot.target):shot.target={}
	var position:=Vector2(shot.x,shot.y)
	if not shot.target.is_empty():
		var aim:=chain_target_point(shot.target)
		var distance:=position.distance_to(aim)
		if distance<=float(shot.speed)*dt:
			shot.x=aim.x;shot.y=aim.y;shot.dead=true
			event.emit("projectile_impact",{"shot":shot,"pos":aim})
			hit_enemy(shot.target,shot.damage,int(shot.type),shot.jewelEffects,bool(shot.critical),shot.get("combat_context",{}))
			return
		shot.direction=(aim-position).normalized()
	var movement:Vector2=shot.direction*float(shot.speed)*dt
	shot.x+=movement.x;shot.y+=movement.y
	if shot.x < -32 or shot.x > BATTLE_SIZE.x+32 or shot.y < -32 or shot.y > BATTLE_SIZE.y+32:shot.dead=true

func queue_jewel_repeats(index: int, multiplier: float, beam: Dictionary = {}) -> void:
	var context: Dictionary=enhancement_attack_contexts.get(index,{})
	if context.get("derived",false):return
	if not context.has("snapshot"):return
	var snapshot: Dictionary=context.snapshot
	if snapshot.repeats_queued:return
	snapshot.repeats_queued=true
	var entry := combat_entry(index)
	var executions: Array=[]
	for node in snapshot.repeat_plan:
		var execution := {"launched":false}
		var parent: Dictionary=executions[int(node.parent)] if int(node.parent)>=0 else {}
		executions.append(execution)
		var pending := {"index":index,"entry":entry,"remaining":node.delay,"multiplier":multiplier*float(node.factor),"depth":node.depth,"origin_multiplier":multiplier,"snapshot":snapshot,"execution":execution,"parent_execution":parent}
		if not beam.is_empty():pending.beam=beam
		jewel_repeats.append(pending)

func advance_jewel_repeats(dt: float) -> void:
	for pending in jewel_repeats.duplicate():
		pending.remaining -= dt
		if pending.remaining > 0.000000001:
			continue
		jewel_repeats.erase(pending)
		if not pending.parent_execution.is_empty() and not pending.parent_execution.launched:continue
		var entry := combat_entry(int(pending.index))
		if state != State.COMBAT or not same_module(entry, pending.entry) or str(entry.key).is_empty():
			continue
		var weapon: Dictionary=pending.snapshot.weapon
		if pending.has("beam"):
			var source_beam: Dictionary=pending.parent_execution.get("beam",pending.beam)
			if projectiles.has(source_beam) and long_laser_valid(source_beam):
				var serial_before := projectile_serial
				lock_long_laser(player,weapon,false,int(pending.index),entry,true,float(pending.multiplier),int(pending.get("depth",1)),float(pending.get("origin_multiplier",1.0)),pending.snapshot)
				pending.execution.launched=projectile_serial>serial_before
				if pending.execution.launched:pending.execution.beam=projectiles.back()
			continue
		var candidates := targets(int(weapon.dmgtype))
		if candidates.is_empty():
			continue
		pending.execution.launched=true
		# A derived salvo counts as an attack, but never rerolls or consumes root buffs.
		record_enhancement_attack()
		enhancement_attack_contexts[int(pending.index)]={"derived":true,"snapshot":pending.snapshot,"instance":new_attack_instance(pending.snapshot)}
		for n in (int(weapon.para1) if entry.key == "missile" else 1):
			jewel_fire(int(pending.index), candidates[n % candidates.size()], weapon, player_weapon_offset(int(pending.index)), float(pending.multiplier), missile_visual_spread(n,int(weapon.para1)) if entry.key=="missile" else 0.0,n,int(weapon.para1) if entry.key=="missile" else 1)
		launch_enhancement_secondary(int(pending.index),candidates[0],weapon,float(pending.multiplier))
		finish_enhancement_attack(int(pending.index))

func jewel_on_hit(enemy: Dictionary, effects: Array) -> void:
	for effect in effects:
		if effect.get("kind","") == "iron":
			var source := str(effect.get("source", 0))
			var sources: Dictionary = enemy.get("jewelIronSources", {})
			var stacks := int(sources.get(source, 0))
			if stacks < int(effect.p4):
				sources[source] = stacks + 1
				enemy.jewelIronSources = sources
				enemy.jewelIronStacks = int(enemy.get("jewelIronStacks", 0)) + 1
				enemy.jewelIron = float(enemy.get("jewelIron", 0)) + float(effect.p2) * int(effect.level)
		elif effect.get("kind","") == "interference" and rng.randf() < float(effect.p2):
			enemy.interference = maxf(float(enemy.get("interference", 0)), float(effect.p4) * int(effect.level))
			enemy.jewelExplosion = maxf(float(enemy.get("jewelExplosion", 0)), float(effect.p5) * int(effect.level))

func has_defence_jewels() -> bool:
	return true # Per-module defense owns ordinary regeneration and memory uniformly.

func jewel_defence_hit(index: int) -> void:
	jewel_defence_times[index]=0.0

# Charge affects the next attack; an active beam retains its launch snapshot.
func apply_jewel_charge(index: int, multiplier: float) -> void:
	var id := slot_id("weapons",index)
	if str(combat_entry(index).get("key","")) != "longLaser":
		cooldowns[id] = 0.0
	jewel_charged[id] = maxf(float(jewel_charged.get(id,1.0)),multiplier)

func memory_effect(entry: Dictionary) -> Dictionary:
	var index := _enhancement_effect_index(entry,"memory_material")
	return _enhancement_effect("memory_material",index,enhancement_effective_level()) if index>=0 else {}

func sync_enhancement_buffers() -> void:
	for index in enhancement_buffers.keys():
		var entry := slot_entry("defence",int(index))
		var owner: Dictionary=enhancement_buffer_owners.get(index,{})
		var has_memory:=_enhancement_effect_index(entry,"memory_material")>=0
		if entry.is_empty() or not has_memory or not same_module(owner.get("entry",{}),entry) or owner.get("key","")!=str(entry.key):
			enhancement_buffers.erase(index)
			enhancement_buffer_owners.erase(index)
		else:
			var capacity = enhancement_module_protection_capacity(int(index))
			enhancement_buffers[index]=N.minimum(enhancement_buffers[index],capacity)

func memory_buffer(index: int) -> Variant:
	sync_enhancement_buffers()
	return enhancement_buffers.get(index,0.0)

func enhancement_visible_buffer(index: int, capacity: Variant = null) -> Variant:
	var entry := slot_entry("defence",index)
	var owner: Dictionary=enhancement_buffer_owners.get(index,{})
	if entry.is_empty() or memory_effect(entry).is_empty() or not same_module(owner.get("entry",{}),entry) or owner.get("key","")!=str(entry.key):return 0.0
	return N.minimum(enhancement_buffers.get(index,0),enhancement_module_protection_capacity(index) if capacity == null else capacity)

func enhancement_protection_current() -> Variant:
	var total = 0.0
	for index in defense_entries().size():total=N.add(total,enhancement_visible_buffer(index))
	return total

func enhancement_module_protection_capacity(index: int) -> Variant:
	var entry := slot_entry("defence",index)
	var key := str(entry.get("key",""))
	if key not in DEFENSE_KEYS:return 0.0
	return _jewel_defence_capacity(key).protection_caps.get(index,0.0)

func enhancement_protection_capacity() -> Variant:
	var total = 0.0
	for index in defense_entries().size():total=N.add(total,enhancement_module_protection_capacity(index))
	return total

func enhancement_damage_type_mode(type: int) -> String:
	return "energy" if type==1 else "physical" if type==2 else "neutral"

func enhancement_protection_status() -> Dictionary:
	var components: Array=[]
	# This is a synchronous read projection. Reuse each module's capacity and
	# visible balance for the aggregate instead of projecting them again.
	var total_current = 0.0
	var total_capacity = 0.0
	var identities := {}
	var remaining := INF
	var lockout := 0.0
	var cover_current = 0.0
	var cover_remaining := 0.0
	for index in defense_entries().size():
		var data: Dictionary=enhancement_branches.defenses.get(index,{"cover":0.0,"cover_time":0.0,"resistance_type":0,"resistance_time":0.0,"lockout":0.0})
		cover_current=N.add(cover_current,data.cover);cover_remaining=maxf(cover_remaining,float(data.cover_time))
		var capacity=enhancement_module_protection_capacity(index)
		var current=enhancement_visible_buffer(index,capacity)
		total_current=N.add(total_current,current)
		total_capacity=N.add(total_capacity,capacity)
		var type:=int(data.resistance_type) if data.resistance_time>0 and data.lockout<=0 else 0
		var resistance:=enhancement_branches.resistance(self,slot_entry("defence",index),enhancement_parameter("memory_b2_resistance")) if type>0 and enhancement_branches.active(self,slot_entry("defence",index),"memory_material",2,"B") else 0.0
		if resistance<=0:type=0
		components.append({"index":index,"current":current,"capacity":capacity,"type":type,"mode":enhancement_damage_type_mode(type),"resistance":resistance,"remaining":float(data.resistance_time),"lockout":float(data.lockout)})
		lockout=maxf(lockout,float(data.lockout))
		if N.compare(current,0)>0:
			identities["%d:%.6f" % [type,resistance]]={"type":type,"resistance":resistance}
			remaining=minf(remaining,float(data.resistance_time))
	var mode := "neutral"
	var resistance := 0.0
	if identities.size()>1:mode="mixed"
	elif identities.size()==1:
		var identity: Dictionary=identities.values()[0]
		mode=enhancement_damage_type_mode(int(identity.type))
		resistance=float(identity.resistance)
	return {"mode":mode,"current":total_current,"capacity":total_capacity,"resistance":resistance,"remaining":remaining if is_finite(remaining) else 0.0,"lockout":lockout,"components":components,"cover_current":cover_current,"cover_remaining":cover_remaining}

func consume_enhancement_protection(amount, type := 0, already_mitigated := true, feedback: Dictionary = {}) -> Variant:
	# Neutral temporary protection absorbs damage 1:1, before any resistance.
	# Stable module order preserves each contributing module's cap ownership.
	sync_enhancement_buffers()
	var rest = amount
	var indices: Array=enhancement_buffers.keys()
	indices.sort()
	for index in indices:
		if N.compare(rest,0)<=0:break
		var reduction := enhancement_branches.memory_resistance(self,int(index),type) if not already_mitigated else 0.0
		var factor := 1.0-reduction
		if factor<=0 and N.compare(enhancement_buffers[index],0)>0:
			jewel_defence_hit(int(index))
			return 0.0
		var protected = N.minimum(enhancement_buffers[index],N.multiply(rest,factor))
		enhancement_buffers[index]=N.subtract(enhancement_buffers[index],protected)
		if feedback.has("absorbed"):feedback.absorbed=N.add(feedback.absorbed,protected)
		rest=N.subtract(rest,N.divide(protected,maxf(0.001,factor)))
		if N.compare(protected,0)>0:jewel_defence_hit(int(index))
	return rest

func jewel_hit_player(raw, type: int) -> void:
	var capacities := sync_jewel_defence_damage()
	sync_enhancement_buffers()
	since_hit=0.0
	# Every hit on the ship restarts every shield module's delay. Cover, neutral
	# protection and armour can absorb damage, but do not make the hit disappear.
	for index in capacities.shield.indices:
		jewel_defence_hit(index)
	var feedback := {"absorbed":0.0}
	var after_cover = enhancement_branches.consume_cover(self,raw,feedback)
	var rest = consume_enhancement_protection(after_cover,type,false,feedback)
	var loss = 0.0
	# A capped module can leave raw overflow while other shield modules still
	# have room (different resistance/deferral). Redistribute within the shield
	# before touching HP; each non-final pass exhausts at least one module.
	var layers: Array=[]
	for _index in capacities.shield.indices:layers.append("shield")
	layers.append("armour")
	var payments := {"shield":0.0,"armour":0.0}
	var deferred_layers := {"shield":false,"armour":false}
	for key in layers:
		if N.compare(rest,0)<=0:break
		var total = 0.0
		var available := {}
		for index in capacities[key].indices:
			available[index]=N.subtract(capacities[key].maxima[index],jewel_defence_damage.get(index,0))
			total=N.add(total,available[index])
		if N.compare(total,0)<=0:continue
		var incoming = rest
		var spent = 0.0
		var damage = 0.0
		var deferred_any := false
		for index in capacities[key].indices:
			if N.compare(available[index],0)<=0:continue
			var entry := slot_entry("defence",index)
			var row := combat_equipment_row(key,int(entry.level))
			var factor := 1.0-enhancement_branches.resistance(self,entry,float(db.config.dmgReduce)) if type==int(row.dmgtype) else 1.0
			# Only raw damage surviving neutral protection receives body resistance.
			var part = N.multiply(incoming,N.ratio(available[index],total)*factor)
			var delayed_fraction := 0.0
			for effect in enhancement_effects(entry):
				if effect.kind=="delayed_damage":delayed_fraction=float(effect.p2)
			# Capacity constrains the amount actually paid now, not the amount
			# before deferral. Final HP still incurs full overkill before clamping.
			var payable_capacity = N.divide(available[index],1.0-delayed_fraction)
			var taken = part if key=="armour" else N.minimum(payable_capacity,part)
			var delayed = N.multiply(taken,delayed_fraction)
			var immediate = N.subtract(taken,delayed)
			if key=="shield" and N.compare(taken,payable_capacity)>=0:
				immediate=available[index]
				delayed=N.subtract(taken,immediate)
			deferred_any=deferred_any or N.compare(delayed,0)>0
			queue_enhancement_deferred(key,delayed)
			var body = immediate
			jewel_defence_damage[index]=N.add(jewel_defence_damage.get(index,0),body)
			damage=N.add(damage,body)
			spent=N.add(spent,N.multiply(incoming,N.ratio(available[index],total)) if factor<=0 else N.divide(taken,factor))
			if N.compare(taken,0)>0:jewel_defence_hit(index)
		payments[key]=N.add(payments[key],damage)
		deferred_layers[key]=deferred_layers[key] or deferred_any
		rest=N.subtract(incoming,spent)
	# Redistribution is still one incoming hit per body layer. Rounding every
	# pass would overcharge mixed-resistance shields and desync their allocation.
	for key in ["shield","armour"]:
		var rounded = N.minimum(player[key],payments[key] if deferred_layers[key] else N.ceiling(payments[key]))
		player[key]=N.subtract(player[key],rounded)
		loss=N.add(loss,rounded)
	event.emit("hit",{"x":player.x,"y":player.y,"amount":loss,"absorbed":feedback.absorbed,"player":true,"type":type})
	if not player_alive() and not drone_combat.try_rebuild(self):
		event.emit("explode",{"x":player.x,"y":player.y,"boss":true})
		begin_retreat()

func enhancement_deferred_fraction(level := -1) -> float:
	return EnhancementGrowth.deferred_fraction(db,enhancement_effective_level() if level<0 else level) if enhancement_unlocked() else 0.0

func enhancement_deferred_total() -> Variant:
	var total = 0.0
	for due in enhancement_deferred.values():
		for key in ["shield","armour"]:total=N.add(total,due.get(key,0))
	return total

func queue_enhancement_deferred(key: String, amount) -> void:
	if N.compare(amount,0)<=0:return
	var interval := enhancement_parameter("deferred_interval")
	var portions := maxi(1,int(ceil(enhancement_parameter("deferred_duration")/interval)))
	# Absolute game-time buckets: first payment >= one interval after this event.
	# Coalescing shifts each source phase forward by < one interval, never earlier.
	var first := maxi(enhancement_deferred_tick+1,int(ceil((enhancement_defense_time+interval-0.000000001)/interval)))
	var unit = N.divide(amount,portions)
	var remaining = amount
	for i in portions:
		var part = remaining if i==portions-1 else N.minimum(unit,remaining)
		remaining=N.subtract(remaining,part)
		var due: Dictionary=enhancement_deferred.get(first+i,{"shield":0.0,"armour":0.0})
		due[key]=N.add(due[key],part)
		enhancement_deferred[first+i]=due

func apply_enhancement_deferred(_key: String, amount) -> void:
	# This debt was already mitigated at the incoming event; protection and body
	# consume it 1:1 with no new resistance, deferral or incoming-history event.
	var feedback := {"absorbed":0.0}
	var after_cover = enhancement_branches.consume_cover(self,amount,feedback)
	var rest = consume_enhancement_protection(after_cover,0,true,feedback)
	var loss = 0.0
	var layers := ["shield","armour"] # Origin is accounting metadata, not a bypass of current shields.
	for layer in layers:
		if N.compare(rest,0)<=0:break
		var capacities := sync_jewel_defence_damage()
		sync_enhancement_buffers()
		var available := {}
		var total = 0.0
		for index in capacities[layer].indices:
			available[index]=N.subtract(capacities[layer].maxima[index],jewel_defence_damage.get(index,0))
			total=N.add(total,available[index])
		var taken = N.minimum(total,rest)
		var body_loss = 0.0
		for index in capacities[layer].indices:
			if N.compare(total,0)<=0:break
			var part = N.multiply(taken,N.ratio(available[index],total))
			var body = part
			jewel_defence_damage[index]=N.add(jewel_defence_damage.get(index,0),body)
			body_loss=N.add(body_loss,body)
			if N.compare(part,0)>0:jewel_defence_hit(index)
		# Deferred portions remain fractional; round only the displayed hit number.
		player[layer]=0.0 if N.compare(taken,total)>=0 and N.compare(total,0)>0 else N.subtract(player[layer],body_loss)
		loss=N.add(loss,body_loss)
		rest=N.subtract(rest,taken)
	if N.compare(loss,0)>0 or N.compare(feedback.absorbed,0)>0:
		event.emit("hit",{"x":player.x,"y":player.y,"amount":N.ceiling(loss),"absorbed":feedback.absorbed,"player":true,"type":0,"deferred":true})
	if not player_alive() and not drone_combat.try_rebuild(self):
		event.emit("explode",{"x":player.x,"y":player.y,"boss":true})
		begin_retreat()

func advance_enhancement_deferred_tick() -> void:
	enhancement_deferred_tick+=1
	if enhancement_deferred.is_empty():return
	var due: Dictionary=enhancement_deferred.get(enhancement_deferred_tick,{})
	if due.is_empty():return # No clearance roll before a source's first settlement.
	enhancement_deferred.erase(enhancement_deferred_tick)
	for key in ["shield","armour"]:
		if due.has(key):apply_enhancement_deferred(key,due[key])
		if state==State.RETREAT:return
	# One shared chance per active global tick after payment, independent of hit count.
	if rng.randf()<enhancement_branches.clear_probability(self):
		var cleared_amount = enhancement_deferred_total()
		enhancement_deferred.clear()
		if N.compare(cleared_amount,0)>0:enhancement_branches.cleared(self)

func _legacy_begin_defence_span(dt:float)->void:
	_legacy_defence_span_active=true
	_legacy_defence_origin=enhancement_defense_time
	_legacy_combat_origin=enemy_shield_time
	_legacy_combat_end=enemy_shield_time+dt

func _legacy_end_defence_span()->void:
	if not _legacy_defence_span_active:return
	# Terminal events consume the logical tail without replaying defence or hits.
	enemy_shield_time=_legacy_combat_end
	_legacy_defence_span_active=false
	native_step_phase="idle";native_step_remaining=0.0

func _legacy_defence_stopped()->bool:
	if _legacy_defence_span_active and state==State.COMBAT and is_final_encounter() and not has_alive_enemy():
		finish_combat_step(0.0)
	return state==State.RETREAT or not player_alive() or (_legacy_defence_span_active and state!=State.COMBAT)

func _legacy_advance_defence_to(combat_at:float)->bool:
	if not _legacy_defence_span_active:return true
	if _legacy_defence_stopped():return false
	var target:=_legacy_defence_origin+(combat_at-_legacy_combat_origin)
	if target+0.000000001<enhancement_defense_time or combat_at>_legacy_combat_end+0.000000001:
		push_error("PLAYER_DEFENCE_TIME_CONTRACT invalid event cursor");return false
	if not advance_jewel_repair(maxf(0.0,target-enhancement_defense_time)):return false
	return not _legacy_defence_stopped()

func _mark_enhancement_due(memory_interval:float,deferred_interval:float)->void:
	# Phase bookkeeping never performs a payment, recovery pulse or RNG roll.
	if enhancement_deferred_elapsed+0.000000001>=deferred_interval:
		enhancement_deferred_elapsed=maxf(0.0,enhancement_deferred_elapsed-deferred_interval)
		enhancement_deferred_due_pending=true
	if enhancement_memory_elapsed+0.000000001>=memory_interval:
		enhancement_memory_elapsed=maxf(0.0,enhancement_memory_elapsed-memory_interval)
		enhancement_memory_due_pending=true

func _settle_enhancement_due()->void:
	if enhancement_deferred_due_pending:
		enhancement_deferred_due_pending=false
		advance_enhancement_deferred_tick()
		if _legacy_defence_stopped():return
	if enhancement_memory_due_pending:
		enhancement_memory_due_pending=false
		advance_enhancement_repair_step(0.0,1)

func advance_jewel_repair(dt: float) -> bool:
	if paused or dt<0 or state==State.RETREAT or not player_alive():return true
	var memory_interval := enhancement_parameter("memory_interval")
	var deferred_interval := enhancement_parameter("deferred_interval")
	if not is_finite(dt) or memory_interval<=0.000000001 or deferred_interval<=0.000000001 or not is_finite(memory_interval) or not is_finite(deferred_interval) or enhancement_memory_elapsed<0 or enhancement_memory_elapsed>=memory_interval or enhancement_deferred_elapsed<0 or enhancement_deferred_elapsed>=deferred_interval:
		push_error("PLAYER_DEFENCE_TIME_CONTRACT invalid periodic phase")
		return false
	var rest := dt
	while true:
		if enhancement_branches.next_defense_step(self)<0:return false
		if _legacy_defence_span_active and drone_combat.next_incoming_step(self)<0:return false
		var previous_query_time:=enemy_shield_hit_time
		if _legacy_defence_span_active:enemy_shield_hit_time=_legacy_combat_origin+(enhancement_defense_time-_legacy_defence_origin)
		enhancement_branches.advance_defense(self,0.0)
		if _legacy_defence_span_active:drone_combat.advance_incoming(self,0.0)
		if _legacy_defence_stopped():enemy_shield_hit_time=previous_query_time;return true
		_settle_enhancement_due()
		enemy_shield_hit_time=previous_query_time
		if _legacy_defence_stopped():return true
		if rest<=0.000000001:break
		var step := minf(rest,minf(memory_interval-enhancement_memory_elapsed,deferred_interval-enhancement_deferred_elapsed))
		step=minf(step,enhancement_branches.next_defense_step(self))
		if _legacy_defence_span_active:step=minf(step,drone_combat.next_incoming_step(self))
		if step<=0 or not is_finite(step):
			push_error("PLAYER_DEFENCE_TIME_CONTRACT nonprogressing repair piece")
			return false
		enhancement_defense_time+=step
		since_hit+=step
		enhancement_memory_elapsed+=step
		enhancement_deferred_elapsed+=step
		_mark_enhancement_due(memory_interval,deferred_interval)
		rest=maxf(0.0,rest-step)
		# Integrate the elapsed interval before consuming its endpoint events.
		if _legacy_defence_span_active:enemy_shield_hit_time=_legacy_combat_origin+(enhancement_defense_time-_legacy_defence_origin)
		advance_enhancement_repair_step(step,0)
		enhancement_branches.advance_defense(self,step)
		if _legacy_defence_span_active:drone_combat.advance_incoming(self,step)
		if _legacy_defence_stopped():enemy_shield_hit_time=previous_query_time;return true
		_settle_enhancement_due()
		enemy_shield_hit_time=previous_query_time
		if _legacy_defence_stopped():return true
	return true

func advance_enhancement_repair_step(dt: float, ticks: int) -> void:
	var capacities := sync_jewel_defence_damage()
	sync_enhancement_buffers()
	var positive_memory_recovery := false
	for key in ["shield","armour"]:
		for index in capacities[key].indices:
			var entry := slot_entry("defence",index)
			var maximum = capacities[key].maxima[index]
			var previous_elapsed := float(jewel_defence_times.get(index,since_hit-dt))
			var elapsed := previous_elapsed+dt
			jewel_defence_times[index]=elapsed
			if key=="shield":
				var row := combat_equipment_row(key,int(entry.level))
				var healing_dt := maxf(0.0,elapsed-float(row.para3))-maxf(0.0,previous_elapsed-float(row.para3))
				if healing_dt>0:
					var recovered = N.minimum(jewel_defence_damage.get(index,0),N.multiply(maximum,float(row.para2)*healing_dt))
					jewel_defence_damage[index]=N.subtract(jewel_defence_damage.get(index,0),recovered)
					player[key]=N.minimum(capacities[key].total,N.add(player[key],recovered))
			# Ordinary shield repair still runs every step; memory recovery only reads
			# its payload at an actual memory settlement, with unchanged timing.
			if ticks<=0:continue
			var effect := memory_effect(entry)
			if effect.is_empty():continue
			var healing = N.multiply(maximum,float(effect.p2)*int(effect.level)*ticks*enhancement_branches.memory_heal_multiplier(self,entry))
			var recovered = N.minimum(jewel_defence_damage.get(index,0),healing)
			jewel_defence_damage[index]=N.subtract(jewel_defence_damage.get(index,0),recovered)
			player[key]=N.minimum(capacities[key].total,N.add(player[key],recovered))
			var overflow = N.multiply(N.subtract(healing,recovered),enhancement_branches.memory_charge_multiplier(self,entry)/enhancement_branches.memory_heal_multiplier(self,entry))
			var cap = enhancement_module_protection_capacity(index)
			var previous = enhancement_buffers.get(index,0)
			enhancement_buffers[index]=N.minimum(cap,N.add(previous,overflow))
			positive_memory_recovery=positive_memory_recovery or N.compare(recovered,0)>0 or N.compare(enhancement_buffers[index],previous)>0
			enhancement_buffer_owners[index]={"entry":entry,"key":str(entry.key)}
	if ticks>0:enhancement_branches.recovery_pulse(self,positive_memory_recovery)

func _jewel_defence_capacity(key: String) -> Dictionary:
	return attributes._jewel_defence_capacity(self,key)

func sync_jewel_defence_damage() -> Dictionary:
	# The aggregate player health stays authoritative. This transient allocation
	# records which module is damaged so its repair cannot heal another module.
	# External capacity/health changes reconcile only their delta, preserving
	# existing per-module losses; nothing is persisted as a second health balance.
	var capacities = {}
	for key in ["shield", "armour"]:
		var capacity := _jewel_defence_capacity(key)
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

func refresh_crew_level_effects(changes: Array) -> void:
	if not crew.levels_unlocked(self):return
	var kinds: Dictionary={}
	for change in changes:
		var previous: Dictionary=change.previous;var current: Dictionary=change.current
		if previous.level==current.level and previous.assignmentType==current.assignmentType and previous.targetId==current.targetId:continue
		for member in [previous,current]:
			var job: Dictionary=crew.assignments(self).get(str(member.assignmentType),{})
			kinds[str(job.get("targetType",""))]=true
	# Install every affected projection before the first notification.
	if kinds.has("reactor"):reactor.reconcile_capacity(reactor_capacity())
	if kinds.has("equipment") or kinds.has("reactor"):
		configuration_committed();apply_refit_health()
		for category in ["weapons","defence"]:event.emit("equipment_stats",{"category":category})
	if kinds.has("hightech"):event.emit("scientists_changed",{})
	if kinds.has("reactor"):event.emit("reactor_changed",{})

func native_before_configuration_change()->bool:
	return native_execution==null or native_execution.handoff_to_legacy(self,"configuration")


func admit_native_execution(descriptor:Dictionary)->bool:
	if native_execution!=null or state!=State.COMBAT or enhancement_memory_due_pending or enhancement_deferred_due_pending:return false
	var session=preload("res://scripts/native_execution_session.gd").new()
	if not session.admit(self,descriptor):return false
	native_execution=session
	native_execution_requested=true;native_execution_scope=descriptor.execution_scope
	return true


func admit_native_compiled_execution(scope:String)->bool:
	if not projectiles.is_empty() or not jewel_repeats.is_empty() or ("missile_queue" in self and not get("missile_queue").is_empty()):return false

	var descriptor:Dictionary=preload("res://scripts/native_execution_compiler.gd").new().compile(self,scope)
	if descriptor.has("error"):return false
	return admit_native_execution(descriptor)

func projectile_position(shot:Dictionary)->Vector2:
	var lease=shot.get("motion_lease")
	return Vector2(shot.x,shot.y) if lease==null else lease.position()


func projectile_direction(shot:Dictionary)->Vector2:
	var lease=shot.get("motion_lease")
	return Vector2(shot.direction) if lease==null else lease.direction()


func projectile_x(shot:Dictionary)->float:
	var lease=shot.get("motion_lease")
	return float(shot.x) if lease==null else lease.x()


func projectile_y(shot:Dictionary)->float:
	var lease=shot.get("motion_lease")
	return float(shot.y) if lease==null else lease.y()


func projectile_speed(shot:Dictionary)->float:
	var lease=shot.get("motion_lease")
	return float(shot.speed) if lease==null else lease.speed()


func projectile_motion_age(shot:Dictionary,fallback:float=1.0)->float:
	var lease=shot.get("motion_lease")
	return float(shot.get("motion_age",fallback)) if lease==null else lease.age()


func advance_shared_clock_and_economy(dt:float)->void:
	if manual_hyperspace.active:hyperspace.advance_manual(dt)
	profile.productionElapsed=production_time()+dt
	hyperspace_runtime.advance(self,dt)
	if native_execution==null:enhancement_branches.advance_weapons(self,dt)
	advance_planets(dt)
	galaxy_runtime.advance(self,dt)
	if native_step_phase=="blocked":return
	crew.advance(self,dt)
	advance_auto_gen(dt)
	advance_hightech(dt)
	for drop in drops.duplicate():
		if drop.get("hightech", false) or drop.get("auto_gen", false):
			continue
		drop.age += dt
		if drop.age >= (2.0 if drop.has("jewel") else float(db.defaults.autoCollectDelay)):
			collect(drop, false)

func finish_combat_step(dt:float)->void:
	if state == State.COMBAT and not has_alive_enemy():
		drone_combat.restore_rebuild(self)
		equipment.clear_switches()
		save_dirty = true
		if guarding_here():
			if guard_engaged and is_final_encounter():
				guard_engaged = false
				projectiles.clear()
				clear_level()
				clear_timer = guard_interval()
				return
			guard_elapsed += dt
			if guard_elapsed >= guard_interval():
				respawn_guard()
			return
		if is_final_encounter():
			projectiles.clear()
			clear_level()
		else:
			change_state(State.TRAVEL)
			event.emit("wave_clear", {})
	elif state == State.COMBAT:
		guard_elapsed = 0


func projectile_clear()->void:
	projectiles.clear()

func set_damage_stats_enabled(value:bool)->bool:
	if value and native_execution!=null and native_execution.kernel!=null and not native_execution.kernel.has_method("set_damage_stats_enabled"):
		return false
	damage_stats.set_enabled(value)
	if native_execution!=null and native_execution.kernel!=null and native_execution.kernel.has_method("set_damage_stats_enabled"):
		native_execution.kernel.set_damage_stats_enabled(value)
	return true

var combat_presentation:RefCounted
