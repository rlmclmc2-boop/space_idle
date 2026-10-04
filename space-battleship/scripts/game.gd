class_name BattleGame
extends RefCounted

const CLEAR_ADVANCE_DELAY := 3.0
const MAX_TRAVEL_SECONDS := 3.0

signal event(kind: String, payload: Dictionary)

enum State { MAIN_MENU, LEVEL_SELECT, TRAVEL, COMBAT, LEVEL_CLEAR, DEFEAT, UPGRADE, RETREAT }
const EQUIPMENT := ["armour", "shield", "laser", "missile", "cannon", "longLaser"]
const SAVE_PATH := "user://progress.json"
const SAVE_VERSION := 5
# JSON.parse_string stores numbers as doubles; larger integers cannot round-trip exactly.
const ENHANCEMENT_LEVEL_LIMIT := 9007199254740991
const N = preload("res://scripts/growth_number.gd")
var planet_buildings := preload("res://scripts/planet_buildings.gd").new()
var planet_buffs := preload("res://scripts/planet_buffs.gd").new()
var galaxy := preload("res://scripts/galaxy_system.gd").new()
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
var crew := preload("res://scripts/crew_system.gd").new()
# Synchronous upgrade sweep only; released before returning to the game loop.
var _upgrade_batch := false
var _upgrade_slots: Array = []
var _upgrade_costs: Dictionary = {}
var state: State = State.MAIN_MENU
var stage := 1
var distance := 0.0
var travel_origin := INF
var group_index := 0
var enemies: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var drops: Array[Dictionary] = []
var player: Dictionary = {}
var cooldowns: Dictionary = {}
var since_hit := 100.0
var paused := false
var speed := 1.0
var clear_timer := 0.0
var guard_index := -1
var guard_elapsed := 0.0
var guard_engaged := false
var guard_arrived := false
var first_clear := false
var run_resources := {"1": 0.0, "2": 0.0}
var uid := 0
var projectile_serial := 0
var save_enabled := true
var stat_cache_enabled := false
var stat_cache: Dictionary = {}
var jewel_defence_capacity_cache: Dictionary = {}
var login_chrono_particles := 0.0
var pending_unlocks: Array[String] = []
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
var attack_instance_serial := 0
var jewel_defence_times: Dictionary = {}
var jewel_defence_damage: Dictionary = {}
var jewel_charged: Dictionary = {}
var enhancement_branches := preload("res://scripts/enhancement_branches.gd").new()
var enhancement_attack_contexts: Dictionary = {}
var enhancement_buffers: Dictionary = {}
var enhancement_buffer_owners: Dictionary = {}
var enhancement_memory_elapsed := 0.0
var enhancement_defense_time := 0.0
var enhancement_deferred_elapsed := 0.0
var enhancement_deferred_tick := 0
var enhancement_deferred: Dictionary = {}
# Preserves damage fraction while a capacity temporarily becomes zero during refit.
var refit_health_ratios := {"armour":1.0,"shield":1.0}
var enemy_shield_time := 0.0
var enemy_shield_hit_time := -1.0

# Overridden only by the isolated Debug simulator. Live games retain wall time.
func economy_time() -> float:
	return Time.get_unix_time_from_system()

func _init(database: ShipDatabase, persist := true) -> void:
	db = database
	speed = default_speed()
	save_enabled = persist
	stat_cache_enabled = persist
	rng.randomize()
	profile = fresh_profile()
	crew.attach(self)
	galaxy.load_state(self,{})
	crew.load_state(self, [])
	load_planets({})
	profile.hightechOrder = hightech_slots()
	if persist:
		load_progress()
		save_dirty = true
	reset_player()
	reset_save_timer()

func fresh_profile() -> Dictionary:
	var selected := first_ship()
	var profile := {"version":SAVE_VERSION, "productionElapsed":0.0, "highestLevel":1, "cleared":[], "bossSeen":[], "resources":{"1":ceilf(float(db.defaults.startingIron)),"2":ceilf(float(db.defaults.startingTitanium))}, "unlocked":str(db.config.startEquip).split(","), "loop":false, "selectedShip":selected, "loadout":{}, "moduleVersion":1, "hightechLevels":{}, "hightechVersion":2, "scientists":0, "scientistAssignments":{}, "techPoints":{}, "hightechSavedAt":Time.get_unix_time_from_system(), "furnaceElapsed":0.0, "furnaceIncomePeak":0.0}
	# Initial availability also belongs to unlock; startEquip only selects loadout.
	profile.unlocked = EQUIPMENT.filter(func(key):return db.unlock_level(key) == 0)
	var starting: Array = Array(str(db.config.startEquip).split(",")).filter(func(key):return profile.unlocked.has(key))
	profile.loadout = default_loadout(selected, starting)
	profile.onboarding = {"version":1, "intro":false, "equipped":false, "upgraded":false, "completed":false, "dismissed":false}
	profile.jewels = [] # Empty compatibility projection; no live gem inventory.
	profile.enhancementVersion = 1
	profile.enhancementLevel = 0
	profile.enhancementOrder = default_enhancement_order()
	profile.enhancementBranches = default_enhancement_branches()
	profile.enhancementAttacks = 0
	profile.enhancementHits = 0
	profile.lifetime_max_stage = 1
	profile.seenUnlocks = []
	profile.readUnlocks = []
	profile.jewelFragments = 0.0
	profile.jewelFurnaceElapsed = 0.0
	profile.jewelFurnaceIncomePeak = 0.0
	profile.chronoParticles = 0.0
	profile.reactorLevel = int(db.config.reactorInitialLevel)
	profile.reactorAllocation = {}
	for key in reactor_modules():profile.reactorAllocation[key] = 0
	profile.hyperspace = hyperspace.fresh()
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
		if unlock_available(str(id)):result.append(str(id))
	return result

func tutorial_unlocks() -> Array[String]:
	# Seen notices also retain earned knowledge through a reforge's new run.
	var result: Array[String] = []
	for id in db.data.get("unlock", {}):
		if unlock_available(str(id)) or profile.get("seenUnlocks", []).has(id):result.append(str(id))
	return result

func unread_tutorial_unlocks() -> Array[String]:
	return tutorial_unlocks().filter(func(id):return not profile.get("readUnlocks", []).has(id))

func read_tutorial_unlock(id: String) -> bool:
	if not tutorial_unlocks().has(id) or profile.get("readUnlocks", []).has(id):return false
	profile.readUnlocks.append(id)
	save_dirty = true
	event.emit("tutorial_read", {"id":id})
	return true

func default_loadout(key: String, unlocked: Array) -> Dictionary:
	var loadout := empty_loadout(key)
	var weapons: Array = loadout.weapons
	var defence: Array = loadout.defence
	if not defence.is_empty():defence[0].key="armour"
	for equip_key in unlocked:
		if WEAPON_KEYS.has(str(equip_key)):
			var empty := weapons.find_custom(func(entry):return str(entry.key).is_empty())
			if empty >= 0:
				weapons[empty].key = str(equip_key)
		elif DEFENSE_KEYS.has(str(equip_key)):
			if str(equip_key)=="armour" and not defence.is_empty():continue
			var empty_defence := defence.find_custom(func(entry):return str(entry.key).is_empty())
			if empty_defence >= 0:
				defence[empty_defence].key = str(equip_key)
	return loadout

func empty_loadout(key: String) -> Dictionary:
	var row := db.ship(key)
	var weapons: Array = []
	var defence: Array = []
	for i in range(int(row.get("weaponSlots", 0))):
		weapons.append({"key":"", "level":1})
	for i in range(int(row.get("defenseSlots", 0))):
		defence.append({"key":"", "level":1})
	return {"weapons":weapons, "defence":defence}

func load_progress() -> void:
	var raw = progress_writer.read_progress(SAVE_PATH)
	if raw is Dictionary:load_progress_data(raw)

func load_progress_data(raw: Dictionary) -> void:
	# Also used on an isolated fresh game to validate portable imports.
	# Reject a future/corrupt subsystem before changing any authoritative balance.
	if raw.has("hyperspace") and (not raw.hyperspace is Dictionary or not preload("res://scripts/hyperspace_state.gd").valid(raw.hyperspace,hyperspace.config,db.levels.size()) or not preload("res://scripts/hyperspace_permissions.gd").bindings_valid(raw,db.data,hyperspace.config)):
		hyperspace.last_error="invalid_hyperspace_save"
		return
	invalidate_stat_cache()
	login_chrono_particles = 0.0
	if int(raw.get("version",0)) not in [2,3,4,SAVE_VERSION]:return
	var interval_value = raw.get("saveIntervalMinutes", 1)
	var interval := parse_save_interval(str(interval_value))
	if interval_value is float and is_finite(interval_value) and interval_value >= 1 and interval_value < 9.0e18 and interval_value == floorf(interval_value):interval = int(interval_value)
	if interval > 0:save_interval_minutes = interval
	var saved_at = raw.get("hightechSavedAt", 0.0)
	if (saved_at is int or saved_at is float) and is_finite(float(saved_at)) and saved_at > 0:
		last_successful_save_at = float(saved_at)
	# Legacy identities are accepted only at the save migration boundary.
	if int(raw.get("version",0))<3:
		raw = migrate_planet_ids(raw)
	# Old saves remain quiet; fresh profiles alone opt into first-session guidance.
	profile.onboarding = {"version":1, "intro":false, "equipped":false, "upgraded":false, "completed":true, "dismissed":false}
	if raw.get("onboarding") is Dictionary:
		for key in ["intro", "equipped", "upgraded", "completed", "dismissed"]:
			profile.onboarding[key] = raw.onboarding.get(key, false) == true
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
	for id in ["1", "2"]:
		var value = raw.get("resources", {}).get(id, 0) if raw.get("resources") is Dictionary else 0
		if N.valid(value):
			# Restoring a balance must not mint the remainder of a fractional unit.
			profile.resources[id] = value.duplicate(true) if value is Dictionary else float(value)
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
	rebuild_unlocks()
	load_journey(raw.get("journey", {}))
	# Old saves knew ownership but not notification history. Preserve their pending
	# pages; all other previously owned unlocks have already been experienced.
	var seen_source = raw.get("seenUnlocks", available_unlocks().filter(func(key):return not profile.get("journey",{}).get("pendingUnlocks",[]).has(key)))
	if seen_source is Array:
		for key in seen_source:
			if key is String and not profile.seenUnlocks.has(key):profile.seenUnlocks.append(key)
	if profile.has("journey"):
		profile.journey.pendingUnlocks = profile.journey.get("pendingUnlocks",[]).filter(func(key):return not profile.seenUnlocks.has(key))
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
	var saved_ship := str(raw.get("selectedShip", first_ship()))
	profile.selectedShip = saved_ship if ship_unlocked(saved_ship) else first_ship()
	profile.loadout = default_loadout(profile.selectedShip, profile.unlocked)
	if raw.get("loadout") is Dictionary:
		profile.loadout = raw.loadout.duplicate(true)
	ensure_loadout()
	# Legacy name levels migrate once. Module saves use their own slot levels exclusively.
	if int(raw.get("moduleVersion",0)) < 1:
		for key in EQUIPMENT:
			var entry := first_equipment_entry(key)
			var value = raw.get("levels", {}).get(key, 1) if raw.get("levels") is Dictionary else 1
			if not entry.is_empty():
				var migrated := clampi(int(value),1,db.max_equipment_level(key)) if value is float or value is int else 1
				# Keep any explicit slot investment when a legacy name-level map is older.
				entry.level = maxi(int(entry.level),migrated)
	profile.moduleVersion = 1
	load_jewels(raw)
	load_hightech(raw)
	profile.hightechOrder = hightech_slots()
	galaxy.load_state(self,raw.get("galaxies",{}) if raw.get("galaxies",{}) is Dictionary else {})
	crew.load_state(self, raw.get("crew", []))
	load_reactor(raw)
	load_planets(raw.get("planets", {}))
	galaxy.refresh_unlocks(self)
	var particles = raw.get("chronoParticles", 0)
	profile.chronoParticles = minf(float(particles), chrono_capacity()) if nonnegative_number(particles) else 0.0
	login_chrono_particles = accrue_chrono_particles(raw.get("chronoSavedAt"), Time.get_unix_time_from_system())
	hyperspace.load_state(self,raw.get("hyperspace")) # No offline energy/work accrual.

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
	if cost < 0 or (cost > 0 and float(profile.chronoParticles) <= 0):
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
	var available := maxf(0.0, floorf(chrono_capacity() - float(profile.chronoParticles)))
	var gained := minf(earned, available)
	profile.chronoParticles = minf(chrono_capacity(), float(profile.chronoParticles) + gained)
	return gained

func chrono_affordable_seconds(real_dt: float) -> float:
	var cost := chrono_cost(speed)
	if cost < 0:
		speed = default_speed()
		return real_dt
	if cost == 0:
		return real_dt
	var affordable := minf(real_dt, float(profile.chronoParticles) / cost)
	profile.chronoParticles = maxf(0.0, float(profile.chronoParticles) - affordable * cost)
	return affordable

func nonnegative_number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0

func load_hightech(raw: Dictionary) -> void:
	invalidate_stat_cache()
	raw = raw.duplicate(true)
	if int(raw.get("hightechVersion",0)) != 2:
		for field in ["hightechLevels","hightechResearch","scientists","scientistAssignments","techPoints","furnaceElapsed","jewelFurnaceElapsed","hightechDrops"]:
			raw.erase(field)
	if raw.get("hightechOrder") is Array:
		profile.hightechOrder = raw.hightechOrder.filter(func(key):return key is String)
	for field in ["productionElapsed", "hightechSavedAt", "furnaceElapsed", "jewelFurnaceElapsed", "furnaceIncomePeak", "jewelFurnaceIncomePeak"]:
		if nonnegative_number(raw.get(field)):
			profile[field] = float(raw[field])
	if raw.get("hightechLevels") is Dictionary:
		for key in db.data.get("hightech", {}):
			var value = raw.hightechLevels.get(key, 0)
			if nonnegative_number(value) and float(value) == floorf(float(value)):
				profile.hightechLevels[key] = int(value)
	if nonnegative_number(raw.get("scientists")):
		profile.scientists = int(raw.scientists)
	var available := int(profile.scientists)
	for key in db.data.get("hightech", {}):
		var count = raw.get("scientistAssignments", {}).get(key,0) if raw.get("scientistAssignments") is Dictionary else 0
		if nonnegative_number(count) and hightech_unlocked(key):
			profile.scientistAssignments[key] = mini(int(count),available)
			available -= int(profile.scientistAssignments[key])
		var points = raw.get("techPoints", {}).get(key,0) if raw.get("techPoints") is Dictionary else 0
		if nonnegative_number(points):
			profile.techPoints[key] = float(points)
	if raw.get("resourceSamples") is Array:
		for sample in raw.resourceSamples:
			if sample is Dictionary and nonnegative_number(sample.get("time")) and N.valid(sample.get("amount")) and str(sample.get("id", "")) in ["1", "2", "jewel"] and float(sample.time) <= float(profile.hightechSavedAt) and (float(sample.time) > float(profile.hightechSavedAt) - 60.0 or (nonnegative_number(sample.get("production_time")) and float(sample.production_time)<=production_time() and float(sample.production_time)>production_time()-60.0)):
				# Legacy samples have no reliable source; keep totals but exclude them
				# from furnace input until this short rolling window expires.
				var restored := {"time":float(sample.time), "amount":sample.amount, "production_base":sample.get("production_base",sample.amount), "id":str(sample.id), "origin":str(sample.get("origin", "unknown"))}
				if nonnegative_number(sample.get("production_time")) and float(sample.production_time)<=production_time():restored.production_time=float(sample.production_time)
				resource_samples.append(restored)
	profile.furnaceIncomePeak = furnace_income_peak()
	profile.jewelFurnaceIncomePeak = furnace_income_peak(-1,true)
	if raw.get("hightechDrops") is Array:
		for drop in raw.hightechDrops:
			if drop is Dictionary and nonnegative_number(drop.get("age")) and float(drop.age) < 10 and nonnegative_number(drop.get("amount")) and nonnegative_number(drop.get("x")) and nonnegative_number(drop.get("y")):
				var id := str(drop.get("id","1"))
				if id not in ["1","jewel"]:
					continue
				uid += 1
				var drop_x := float(drop.x)
				var drop_y := float(drop.y)
				if drop_x>BATTLE_SIZE.x:
					var old_x := drop_x
					drop_x=lerpf(70,BATTLE_SIZE.x-70,clampf((drop_y-300.0)/205.0,0,1))
					drop_y=lerpf(250,480,clampf((old_x-440.0)/780.0,0,1))
				var restored := {"uid":uid,"x":clampf(drop_x,30,BATTLE_SIZE.x-30),"y":clampf(drop_y,80,BATTLE_SIZE.y-80),"age":float(drop.age),"id":id,"amount":ceilf(float(drop.amount)),"hightech":true}
				if id == "jewel":
					restored.jewel = true
					restored.jewelRatio = 1.0
				drops.append(restored)

func rebuild_unlocks() -> void:
	profile.highestLevel = 1
	for n in profile.cleared:
		profile.highestLevel = mini(db.levels.size(), maxi(profile.highestLevel, int(n) + 1))
	profile.lifetime_max_stage = maxi(int(profile.get("lifetime_max_stage",1)),int(profile.highestLevel))
	profile.grantedUnlocks = granted_unlocks()
	for key in EQUIPMENT:
		if content_unlocked("equipment", key) and not profile.unlocked.has(key):
			profile.unlocked.append(key)
	if not ship_unlocked(str(profile.get("selectedShip", first_ship()))):
		profile.selectedShip = first_ship()
	ensure_loadout()
	profile.hightechOrder = hightech_slots()
	event.emit("unlocks_changed",{})

func ensure_loadout() -> void:
	invalidate_stat_cache()
	var row := db.ship(str(profile.get("selectedShip", first_ship())))
	if row.is_empty():
		profile.selectedShip = first_ship()
		row = db.ship(profile.selectedShip)
	var base := default_loadout(profile.selectedShip, profile.unlocked)
	var saved: Dictionary = profile.get("loadout", {})
	for category in ["weapons", "defence"]:
		var allowed: Array = WEAPON_KEYS if category == "weapons" else DEFENSE_KEYS
		var count := int(row.get("weaponSlots", 0)) if category == "weapons" else int(row.get("defenseSlots", 0))
		var entries: Array = saved.get(category, []) if saved.get(category, []) is Array else []
		var normalized: Array = []
		for i in range(maxi(count,entries.size())):
			var entry = entries[i] if i < entries.size() and entries[i] is Dictionary else (base[category][i] if i<count else {"key":"","level":1})
			var equip_key := str(entry.get("key", "")) if entry is Dictionary else ""
			var level := int(entry.get("level", 1)) if entry is Dictionary and (entry.get("level", 1) is int or entry.get("level", 1) is float) else 1
			if not equip_key.is_empty() and (not allowed.has(equip_key) or not profile.unlocked.has(equip_key)):
				equip_key = ""
			if slot_equipment_locked(category,i):equip_key="armour"
			var normalized_entry := {"key":equip_key, "level":clampi(level, 1, 2147483647)}
			normalized.append(normalized_entry)
		profile.loadout[category] = normalized

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
	profile.hightechOrder = hightech_slots()
	profile.hightechSavedAt = Time.get_unix_time_from_system()
	prune_resource_samples(float(profile.hightechSavedAt))
	profile.resourceSamples = resource_samples
	profile.chronoSavedAt = float(profile.hightechSavedAt)
	profile.hightechDrops = drops.filter(func(drop):return drop.get("hightech", false))
	return _compose_save_data(profile.duplicate())

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
	saved.saveIntervalMinutes = str(save_interval_minutes)
	saved.galaxies=galaxy.save_data()
	saved.grantedUnlocks = granted_unlocks()
	if state in [State.TRAVEL, State.COMBAT, State.LEVEL_CLEAR, State.RETREAT]:
		# Retreat resumes at its destination, never at the defeated encounter.
		saved.journey = {"stage":stage, "distance":retreat_target if state == State.RETREAT else distance, "groupIndex":group_index, "state":int(state), "guardArrived":guard_arrived, "retreatBossPending":retreat_boss_pending}
		saved.journey.pendingUnlocks = pending_unlocks.duplicate()
	saved.jewels = [] # Retired field stays empty for old save readers.
	saved.loadout = profile.loadout.duplicate(true)
	for category in ["weapons", "defence"]:
		for entry in saved.loadout[category]:
			for field in ["sockets","attacks","hits"]:entry.erase(field)
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
	return profile.loadout.get(category, [])

func active_slot_count(category: String, ship_key := "") -> int:
	return int(db.ship(str(profile.selectedShip) if ship_key.is_empty() else ship_key).get("weaponSlots" if category=="weapons" else "defenseSlots",0)) if category in ["weapons","defence"] else 0

func module_entry(category: String, index: int) -> Dictionary:
	var entries := module_entries(category)
	return entries[index] if index>=0 and index<entries.size() else {}

func loadout_entries(category: String) -> Array:
	# Active view contains references to authoritative modules, never copies of entries.
	return module_entries(category).slice(0,active_slot_count(category))

func module_cost_key(category: String) -> String:
	# Current same-category cost curves are identical; modules retain that existing curve.
	return "laser" if category=="weapons" else "armour"


func weapon_entries() -> Array:
	return loadout_entries("weapons")

func defense_entries() -> Array:
	return loadout_entries("defence")

func stat(key: String) -> Variant:
	if stat_cache_enabled and stat_cache.has(key):
		return stat_cache[key]
	var total = 0.0
	for category in ["weapons", "defence"]:
		for entry in loadout_entries(category):
			if str(entry.get("key", "")) == key:
				total = N.add(total,jewel_equipment_stat(entry))
	if stat_cache_enabled:
		stat_cache[key] = total
	return total

func invalidate_stat_cache() -> void:
	stat_cache.clear()
	jewel_defence_capacity_cache.clear()

func invalidate_equipment_counter(key: String) -> void:
	# Attack/hit counters change only this equipment type's proficiency/adaptation.
	# They do not alter planets, research, crew or the other defence capacity.
	stat_cache.erase(key)
	jewel_defence_capacity_cache.erase(key)

func ship_movement() -> float:
	return float(db.ship(str(profile.get("selectedShip", first_ship()))).get("movement", db.config.movement))

func travel_movement() -> float:
	var groups: Array = db.levels[stage-1].groups
	if group_index >= groups.size():return ship_movement()
	var destination := float(groups[group_index].position)*float(db.levels[stage-1].length)
	var origin := distance if is_inf(travel_origin) else travel_origin
	return maxf(ship_movement(),maxf(0.0,destination-origin)/MAX_TRAVEL_SECONDS)

func ship_name() -> String:
	return UIText.data_text("ship",str(profile.get("selectedShip",first_ship())),"des")

func slot_entry(category: String, index: int) -> Dictionary:
	var entries := loadout_entries(category)
	return entries[index] if index >= 0 and index < entries.size() else {}

func slot_id(category: String, index: int) -> String:
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
	var total := {}
	if levels <= 0 or current + levels > db.max_equipment_level(key):
		return total
	for level in range(current + 1, current + levels + 1):
		var cost := upgrade_cost_for_level(key, level)
		for id in cost:
			total[id] = float(total.get(id, 0)) + float(cost[id])
	return total

func can_upgrade_slot(category: String, index: int, levels := 1) -> bool:
	var entry := slot_entry(category, index)
	if entry.is_empty() or levels<1:
		return false
	var costs := slot_upgrade_cost(category, index, levels)
	return can_afford_upgrade_costs(costs)

func can_afford_upgrade_costs(costs: Dictionary) -> bool:
	if costs.is_empty():
		return false
	for id in costs:
		if not is_finite(float(costs[id])) or N.compare(profile.resources.get(id,0),costs[id])<0:
			return false
	return true

func resources_changed(ids: Array) -> void:
	event.emit("resources_changed",{"ids":ids})

func refund_equipment(key: String, level: int) -> void:
	var refunded := {}
	for target_level in range(2, level + 1):
		for id in upgrade_cost_for_level(key, target_level):
			profile.resources[id] = N.add(profile.resources.get(id,0),upgrade_cost_for_level(key,target_level)[id])
			refunded[id]=true
	if not refunded.is_empty():resources_changed(refunded.keys())

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
			if category=="defence" and is_same(entry,entries[0]) and equip_key!="armour":return false
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
	# Armour is the existing life pool. An allowed zero-armour refit must
	# resolve death, rather than make hostile projectiles ignore a live ship.
	if state in [State.TRAVEL,State.COMBAT,State.LEVEL_CLEAR] and N.compare(player.get("armour",0),0)<=0:
		begin_retreat()
		event.emit("battle_blocked",{"reason":"zero_armour"})

func invalidate_module_attack(index: int) -> void:
	jewel_repeats = jewel_repeats.filter(func(p):return int(p.index)!=index)
	jewel_charged.erase(slot_id("weapons",index))
	for shot in projectiles:
		if shot.get("beam",false) and not shot.hostile and int(shot.mount)==index:shot.dead=true
	var entry := slot_entry("weapons",index)
	if entry.is_empty() or str(entry.key).is_empty():
		cooldowns.erase(slot_id("weapons",index))
	else:
		cooldowns[slot_id("weapons",index)] = float(db.equip(str(entry.key),int(entry.level)).cd)

func slot_equipment_locked(category: String, index: int) -> bool:
	return category=="defence" and index==0

func equip_slot(category: String, index: int, key: String) -> bool:
	if slot_equipment_locked(category,index) and key!="armour":return false
	if category not in ["weapons","defence"]:return false
	var allowed: Array = WEAPON_KEYS if category=="weapons" else DEFENSE_KEYS
	var entry := slot_entry(category,index)
	if entry.is_empty() or not allowed.has(key) or not profile.unlocked.has(key):return false
	if str(entry.key)==key:return true
	capture_refit_health()
	# Replace the entry reference to invalidate old beams/repeats, keeping module assets.
	var module := entry.duplicate(true)
	module.key = key
	profile.loadout[category][index] = module
	invalidate_stat_cache()
	if category=="weapons":invalidate_module_attack(index)
	apply_refit_health()
	save_dirty = true
	event.emit("module_changed",{"slot":slot_id(category,index)})
	return true

func unequip_slot(category: String, index: int) -> bool:
	if slot_equipment_locked(category,index):return false
	var entry := slot_entry(category,index)
	if entry.is_empty() or str(entry.key).is_empty():return false
	capture_refit_health()
	var module := entry.duplicate(true)
	module.key = ""
	profile.loadout[category][index] = module
	invalidate_stat_cache()
	if category=="weapons":invalidate_module_attack(index)
	apply_refit_health()
	save_dirty = true
	event.emit("module_changed",{"slot":slot_id(category,index)})
	return true

func refund_all_equipment() -> void:
	# Retained for explicit legacy callers; normal refit never refunds module growth.
	for category in ["weapons","defence"]:
		for entry in loadout_entries(category):
			if not str(entry.key).is_empty():refund_equipment(str(entry.key),int(entry.level))

func switch_ship(key: String, selected_loadout: Dictionary = {}) -> bool:
	if key==str(profile.selectedShip) or not ship_unlocked(key):return false
	if not selected_loadout.is_empty() and not valid_loadout(key,selected_loadout):return false
	capture_refit_health()
	var old_weapon_count := active_slot_count("weapons")
	profile.selectedShip = key
	hyperspace.fit_hull(self)
	invalidate_stat_cache()
	for category in ["weapons","defence"]:
		var entries := module_entries(category)
		while entries.size()<active_slot_count(category):entries.append({"key":"","level":1})
		if not selected_loadout.is_empty():
			for index in active_slot_count(category):
				var requested: String = selected_loadout[category][index].key
				if str(entries[index].key)!=requested:
					entries[index] = entries[index].duplicate(true)
					entries[index].key = requested
					if category=="weapons":invalidate_module_attack(index)
	for index in range(mini(old_weapon_count,active_slot_count("weapons")),maxi(old_weapon_count,active_slot_count("weapons"))):invalidate_module_attack(index)
	apply_refit_health()
	save_dirty = true
	event.emit("ship_changed",{"key":key})
	return true

func permanent_modifiers() -> Dictionary:
	# Same lifetime as the other stat projections: refits, unlocks, research,
	# planet progress and crew changes invalidate them before dependent reads.
	if not stat_cache_enabled:return planet_buffs.totals(self)
	if not stat_cache.has("planet_modifiers"):
		stat_cache.planet_modifiers = planet_buffs.totals(self)
	return stat_cache.planet_modifiers

func equipment_level_bonus() -> int:
	return int(permanent_modifiers().equipment_level_bonus)

func hightech_level_bonus() -> int:
	return int(permanent_modifiers().hightech_level_bonus)

func charge_free_ratio() -> float:
	return float(permanent_modifiers().charge_free_ratio)

func gem_drop_level_bonus() -> int:
	return int(permanent_modifiers().gem_drop_level_bonus)

func effective_equipment_level(actual: int) -> int:
	return actual+equipment_level_bonus()

func effective_hightech_level(key: String) -> int:
	return hightech_level(key)+hightech_level_bonus() if hightech_unlocked(key) else 0

func permanent_level_text(actual: int, target: String) -> String:
	var bonus := equipment_level_bonus() if target=="equipment" else hightech_level_bonus()
	return UIText.t("planet.level_with_bonus",{"actual":actual,"bonus":bonus}) if bonus!=0 else str(actual)

func permanent_level_tooltip(actual: int, target: String) -> String:
	var bonus := equipment_level_bonus() if target=="equipment" else hightech_level_bonus()
	return UIText.t("planet.level_tooltip",{"actual":actual,"bonus":bonus,"effective":actual+bonus}) if bonus!=0 else ""

func equipment_stat(key: String, level: int) -> Variant:
	# Base equipment values exclude attack/hit counters. Retain their projection
	# across volleys; full stat invalidation covers every modifier/level change.
	var bases: Dictionary = stat_cache.get("equipment_bases",{}) if stat_cache_enabled else {}
	var levels: Dictionary = bases.get(key,{})
	if levels.has(level):return levels[level]
	# Only the ordinary damage/capacity projection reads the effective level.
	var row := db.equip(key, effective_equipment_level(level))
	var value = row.para1 if key in ["armour", "shield"] else row.dmg
	var tech := DENSE_ARMOUR if key in ["armour", "shield"] else ENERGY_FOCUS
	if effective_hightech_level(tech) > 0:
		value = N.ceiling(N.multiply(value,N.power(1.0 + float(db.data.hightech[tech].para1),effective_hightech_level(tech))))
	var reactor_bonus := reactor_multiplier("defence" if key in ["armour", "shield"] else "weapons")
	if reactor_bonus != 1.0:
		value = N.ceiling(N.multiply(value,reactor_bonus))
	if stat_cache_enabled:
		# Bound previews as well as equipped modules; reads never retain entries.
		if levels.size()>=32:levels.clear()
		levels[level]=value
		bases[key]=levels
		stat_cache.equipment_bases=bases
	return value

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

func reactor_energy(level := -1) -> float:
	var actual := int(profile.reactorLevel) if level < 0 else level
	return float(db.config.reactorEnergyBase) * pow(float(db.config.reactorEnergyGrowth), actual - 1) * crew.system_effect(self,"charge_bonus") * galaxy.multiplier("charge_max")

func reactor_capacity() -> int:
	return maxi(0, int(floor(reactor_energy())))

func reactor_upgrade_cost(level := -1) -> float:
	var actual := int(profile.reactorLevel) if level < 0 else level
	return float(db.config.reactorUpgradeBase) * pow(float(db.config.reactorUpgradeGrowth), actual - 1)

func reactor_allocated() -> int:
	var total := 0
	for key in reactor_modules():total += int(profile.reactorAllocation.get(key,0))
	return total

func reactor_effective_ratio(key: String) -> float:
	if not reactor_unlocked() or not reactor_module_unlocked(key):return 0.0
	return float(profile.reactorAllocation.get(key,0))/maxf(1.0,reactor_capacity())+charge_free_ratio()

func reactor_multiplier(key: String) -> float:
	if not reactor_module_unlocked(key):return 1.0
	var allocation := float(profile.reactorAllocation.get(key,0))
	if reactor_unlocked():allocation+=float(reactor_capacity())*charge_free_ratio()
	return 1.0 + pow(float(allocation),float(db.config.reactorBoostExponent)) / float(db.config.reactorPercentScale) if allocation > 0 else 1.0

func reactor_max_upgrades() -> int:
	var budget = profile.resources.get(str(int(db.config.reactorUraniumId)),0)
	var level := int(profile.reactorLevel)
	var count := 0
	while true:
		var cost := reactor_upgrade_cost(level)
		if not is_finite(cost) or cost <= 0 or N.compare(cost,budget)>0:break
		budget = N.subtract(budget,cost)
		level += 1
		count += 1
	return count

func upgrade_reactor(amount: int) -> bool:
	if not reactor_unlocked() or amount <= 0:return false
	var budget = profile.resources.get(str(int(db.config.reactorUraniumId)),0)
	var total := 0.0
	for offset in amount:
		var cost := reactor_upgrade_cost(int(profile.reactorLevel)+offset)
		if not is_finite(cost) or cost <= 0 or N.compare(N.add(total,cost),budget)>0:return false
		total += cost
	profile.resources[str(int(db.config.reactorUraniumId))] = N.subtract(budget,total)
	profile.reactorLevel += amount
	resources_changed([str(int(db.config.reactorUraniumId))])
	save_dirty = true
	event.emit("reactor_changed", {"level":profile.reactorLevel,"cost":total})
	return true

func set_reactor_allocation(key: String, value: float) -> bool:
	if not reactor_unlocked() or not reactor_module_unlocked(key) or not is_finite(value):return false
	var allowed := maxi(0,reactor_capacity() - reactor_allocated() + int(profile.reactorAllocation.get(key,0)))
	var next := clampi(int(floor(value)),0,allowed)
	if next == int(profile.reactorAllocation.get(key,0)):return false
	profile.reactorAllocation[key] = next
	invalidate_stat_cache()
	if key == "defence":
		player.armour = N.minimum(player.armour,stat("armour"))
		player.shield = N.minimum(player.shield,stat("shield"))
		event.emit("equipment_stats",{"category":"defence"})
	elif key == "weapons":event.emit("equipment_stats",{"category":"weapons"})
	save_dirty = true
	event.emit("reactor_changed", {"module":key})
	return true

func equalize_reactor_allocation() -> bool:
	if not reactor_unlocked():return false
	var modules := reactor_available_modules()
	if modules.is_empty():return false
	var share := reactor_capacity()/modules.size()
	var remainder := reactor_capacity()%modules.size()
	var next: Dictionary = profile.reactorAllocation.duplicate()
	for index in modules.size():
		next[modules[index]] = share + (1 if index < remainder else 0)
	if next==profile.reactorAllocation:return false
	profile.reactorAllocation=next
	invalidate_stat_cache()
	player.armour = N.minimum(player.armour,stat("armour"))
	player.shield = N.minimum(player.shield,stat("shield"))
	save_dirty = true
	event.emit("equipment_stats",{"category":"weapons"})
	event.emit("equipment_stats",{"category":"defence"})
	event.emit("reactor_changed", {"equalized":true})
	return true

func load_reactor(raw: Dictionary) -> void:
	invalidate_stat_cache()
	var level = raw.get("reactorLevel")
	if nonnegative_number(level) and level == floorf(float(level)) and level >= int(db.config.reactorInitialLevel):profile.reactorLevel = int(level)
	var saved = raw.get("reactorAllocation")
	if not saved is Dictionary:return
	for key in reactor_modules():profile.reactorAllocation[key] = 0
	for key in reactor_modules():
		var value = saved.get(key)
		if reactor_module_unlocked(key) and nonnegative_number(value):profile.reactorAllocation[key] = mini(int(floor(float(value))),maxi(0,reactor_capacity()-reactor_allocated()))

func hightech_level(key: String) -> int:
	return int(profile.get("hightechLevels", {}).get(key, 0))

func hightech_unlocked(key: String) -> bool:
	if not db.data.get("hightech", {}).has(key):
		return false
	return content_unlocked("hightech", key)

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

func scientist_cost(offset := 0) -> Dictionary:
	var parts := str(db.config.scientistCost).split(",")
	var multiplier := pow(float(parts[0]),int(profile.scientists)+offset)
	var costs := {}
	for entry in Array(parts).slice(1):
		var pair := str(entry).split("|")
		costs[pair[0]] = roundf(float(pair[1])*multiplier)
	return costs

func scientist_purchase(amount := 1) -> Dictionary:
	var total := {}
	var count := 0
	if not db.data.hightech.keys().any(func(key):return hightech_unlocked(key)):
		return {"count":0,"costs":total}
	while amount < 0 or count < amount:
		var costs := scientist_cost(count)
		var paid := false
		for id in costs:
			paid = paid or float(costs[id]) > 0
			if not is_finite(float(costs[id])) or N.compare(N.add(total.get(id,0),costs[id]),profile.resources.get(id,0))>0:
				return {"count":count if amount < 0 else 0,"costs":total}
		# An unbounded free tail has no finite MAX purchase.
		if amount < 0 and not paid:
			return {"count":count,"costs":total}
		for id in costs:
			total[id] = float(total.get(id,0))+float(costs[id])
		count += 1
	return {"count":count,"costs":total}

func can_generate_scientist(amount := 1) -> bool:
	if amount < 0:
		# MAX is available only if its first purchase is affordable and not free.
		var first := scientist_purchase(1)
		return int(first.count)>0 and first.costs.values().any(func(cost):return float(cost)>0)
	return int(scientist_purchase(amount).count)>0

func generate_scientist(amount := 1) -> bool:
	var purchase := scientist_purchase(amount)
	if int(purchase.count)<=0:
		return false
	for id in purchase.costs:
		profile.resources[id] = N.subtract(profile.resources[id],purchase.costs[id])
	profile.scientists += int(purchase.count)
	resources_changed(purchase.costs.keys())
	save_dirty = true
	event.emit("scientists_changed", {"purchased":int(purchase.count)})
	return true

func distribute_scientists() -> bool:
	var keys := hightech_slots().filter(func(key):return not str(key).is_empty())
	if keys.is_empty() or int(profile.scientists)<=0:
		return false
	var next := {}
	var total := int(profile.scientists)
	for i in range(keys.size()):
		next[keys[i]] = total/keys.size() + (1 if i < total%keys.size() else 0)
	if next==profile.scientistAssignments:return false
	profile.scientistAssignments=next
	save_dirty = true
	event.emit("scientists_changed", {})
	return true

func assigned_scientists(key: String) -> int:
	return int(profile.scientistAssignments.get(key,0))

func idle_scientists() -> int:
	var count := int(profile.scientists)
	for key in profile.scientistAssignments:
		count -= assigned_scientists(key)
	return count

func can_research(key: String) -> bool:
	return hightech_unlocked(key) and idle_scientists() > 0

func assign_scientist(key: String, delta: int) -> bool:
	if not hightech_unlocked(key) or delta == 0 or (delta > 0 and idle_scientists() <= 0) or (delta < 0 and assigned_scientists(key) <= 0):
		return false
	profile.scientistAssignments[key] = assigned_scientists(key)+clampi(delta,-assigned_scientists(key),idle_scientists())
	save_dirty = true
	event.emit("scientists_changed", {})
	return true

func add_crew_exp(crew_id: String, amount: float) -> bool:
	return crew.gain_exp(self,crew_id,amount)

func planet_row(id: String) -> Dictionary:
	return db.data.get("planet", {}).get(id, {})

func planet_unlocked(id: String) -> bool:
	var row := planet_row(id)
	return not row.is_empty() and planet_buffs.allows_planet(self, id) and unlock_available(str(row.get("unlockId", "")))

func planet_progress(id: String) -> Dictionary:
	return profile.get("planets", {}).get(id, {})

func crew_exploration(crew_id: String) -> String:
	return planet_buildings.occupied(self,crew_id)

func planet_duration(id: String) -> float:
	return planet_duration_from(planet_row(id), planet_progress(id).get("degree", 0))

func planet_exp_multiplier() -> float:
	var level := clampi(maxi(int(profile.get("lifetime_max_stage",1)),int(profile.highestLevel)), 1, db.levels.size())
	return float(db.levels[level - 1].get("planetExpRatio", 0)) if level > 0 else 0.0

func planet_exp_reward(id: String) -> float:
	if not crew.levels_unlocked(self):return 0.0
	return roundf(float(planet_row(id).get("baseExp", 0)) * planet_exp_multiplier() * galaxy.multiplier("crew_exp"))

func planet_equipment_multiplier() -> Variant:
	if not stat_cache_enabled:return planet_buildings.multiplier(self,"equipment")
	if not stat_cache.has("planet_equipment"):
		stat_cache.planet_equipment = planet_buildings.multiplier(self,"equipment")
	return stat_cache.planet_equipment

func planet_resource_multiplier() -> Variant:
	if not stat_cache_enabled:return planet_buildings.multiplier(self,"refinery")
	if not stat_cache.has("planet_refinery"):
		stat_cache.planet_refinery = planet_buildings.multiplier(self,"refinery")
	return stat_cache.planet_refinery

func migrate_planet_ids(raw: Dictionary) -> Dictionary:
	var migrated := raw.duplicate(true)
	var aliases := {"first":"1"}
	var planets: Dictionary = migrated.get("planets",{}) if migrated.get("planets") is Dictionary else {}
	for old in aliases:
		if planets.has(old):
			if not planets.has(aliases[old]):planets[aliases[old]]=planets[old]
			planets.erase(old)
	for field in ["grantedUnlocks"]:
		if migrated.get(field) is Array:
			for i in migrated[field].size():
				if migrated[field][i]=="planet/first":migrated[field][i]="planet/1"
	if migrated.get("journey") is Dictionary and migrated.journey.get("pendingUnlocks") is Array:
		for i in migrated.journey.pendingUnlocks.size():
			if migrated.journey.pendingUnlocks[i]=="planet/first":migrated.journey.pendingUnlocks[i]="planet/1"
	migrated.planets=planets
	migrated.version=SAVE_VERSION
	return migrated

func load_planets(raw) -> void:
	invalidate_stat_cache()
	profile.planets = {}
	var pending := {}
	for id in db.data.get("planet", {}):
		var item = raw.get(id, {}) if raw is Dictionary else {}
		if not item is Dictionary:item = {}
		var progress: Dictionary = item.duplicate(true)
		progress.degree = item.get("degree",0) if N.valid(item.get("degree",0)) else 0.0
		progress.unlocked = item.get("unlocked",false)==true or unlock_available(str(planet_row(str(id)).get("unlockId","")))
		progress.conquered = item.get("conquered",false)==true
		progress.auto_explore = item.get("auto_explore",false)==true
		progress.crewId = ""
		progress.elapsed = 0.0
		progress.buildings = item.get("buildings",{}).duplicate(true) if item.get("buildings") is Dictionary else {}
		for key in progress.buildings.keys():
			var building = progress.buildings[key]
			if not building is Dictionary:
				progress.buildings.erase(key)
				continue
			building.status = str(building.get("status","locked"))
			if building.status not in ["locked","building","ready","built"]:building.status="locked"
			building.build_progress = building.get("build_progress",0) if N.valid(building.get("build_progress",0)) else 0
			building.crew = []
		profile.planets[id] = progress
		pending[id] = item
		planet_buildings.sync(self,str(id))
	# Restore all occupation through a single capacity check; duplicates stay idle.
	for id in pending:
		var item: Dictionary=pending[id]
		var progress: Dictionary=profile.planets[id]
		var crew_id := str(item.get("crewId",""))
		if planet_unlocked(str(id)) and idle_planet_crew(crew_id):
			progress.crewId=crew_id
			progress.elapsed=minf(float(item.get("elapsed",0)),planet_duration(str(id))) if nonnegative_number(item.get("elapsed")) else 0.0
		for row in planet_buildings.rows(self,str(id)):
			var building: Dictionary=progress.buildings[str(row.id)]
			var old = item.get("buildings",{}).get(str(row.id),item.get("buildings",{}).get(str(row.get("previous_id","")),{})) if item.get("buildings") is Dictionary else {}
			if building.status!="building" or not old is Dictionary or not old.get("crew") is Array:continue
			for member_id in old.crew:
				if building.crew.size()<int(row.extra_crew) and idle_planet_crew(str(member_id)):building.crew.append(str(member_id))
		# Missing preference inherits the unlocked default; explicit false is a choice.
		if not item.has("auto_explore"):progress.auto_explore = planet_buildings.built(self,str(id),"auto_explore")
		# Keep the player's preference even when no crew/facility is available.
		# Actual continuation checks facility availability in advance_planets.

func idle_planet_crew(id: String) -> bool:
	var member := crew.entry(self,id)
	return not member.is_empty() and crew.unlocked(self,id) and str(member.assignmentType).is_empty() and crew_exploration(id).is_empty() and preload("res://scripts/hyperspace_permissions.gd").reserved_crew(profile.hyperspace)!=id

func planet_duration_from(row: Dictionary, degree) -> float:
	var base := float(row.get("baseTime",0))
	var minimum := float(row.get("minTime",5.0))
	if not is_finite(minimum) or minimum <= 0.0:minimum = 5.0
	return maxf(minimum,N.ratio(base*base,N.add(base,degree))) if base>0 else 0.0

func set_planet_auto(id: String, enabled: bool) -> bool:
	if not planet_buildings.built(self,id,"auto_explore"):return false
	profile.planets[id].auto_explore=enabled
	save_dirty = true
	event.emit("planet_changed",{"id":id})
	return true

func can_reforge_planet(id: String) -> bool:
	return planet_unlocked(id) and not planet_progress(id).get("conquered",false) and planet_buildings.built(self,id,"shipyard")

func planet_reforge_start(id: String) -> int:
	return clampi(int(planet_row(id).get("reforgeStartLevel",1)),1,maxi(1,db.levels.size()))

func reforge_planet(id: String,keep_drones: Array=[],claim_stages: Dictionary={}) -> bool:
	if not can_reforge_planet(id):return false
	var next_hyperspace:=hyperspace.reforge_state(self,keep_drones,claim_stages)
	if next_hyperspace.is_empty():return false
	var start_level := planet_reforge_start(id)
	# Prepare the complete replacement before changing any authoritative state.
	var next := fresh_profile()
	next.hyperspace=next_hyperspace
	next.crew = profile.crew.duplicate(true)
	next.crewEquipment = profile.get("crewEquipment",{}).duplicate(true)
	next.planets = profile.planets.duplicate(true)
	next.galaxies = profile.get("galaxies",{})
	next.grantedUnlocks = []
	next.seenUnlocks = profile.get("seenUnlocks",[]).duplicate()
	next.readUnlocks = profile.get("readUnlocks",[]).duplicate()
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
	for planet_id in next.planets:
		next.planets[planet_id].unlocked = planet_unlocked(str(planet_id))
		# Reforge keeps the planet's current exploration assignment and elapsed work.
		# The crew and planet progress are permanent state, so an in-flight trip
		# must continue after the run is rebuilt.
	next.planets[id].conquered=true
	next.lifetime_max_stage=maxi(int(profile.get("lifetime_max_stage",1)),int(profile.highestLevel))
	# Resources are not listed for deletion; preserve their balances.
	next.resources=profile.resources.duplicate(true)
	# Chrono particles are a persistent reserve, independent of run progress.
	next.chronoParticles=profile.chronoParticles
	next.productionElapsed=production_time()
	profile=next
	hyperspace.scheduler.reset()
	crew.reset_schedule(self)
	pending_unlocks.clear()
	resource_samples.clear()
	drops.clear()
	projectiles.clear()
	enemies.clear()
	speed=default_speed()
	auto_gen_elapsed=0.0
	resource_prune_elapsed=0.0
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
	if not planet_unlocked(id) or planet_progress(id).is_empty() or not planet_progress(id).crewId.is_empty():return false
	if not idle_planet_crew(crew_id):return false
	planet_buildings.sync(self,id)
	profile.planets[id].unlocked=true
	profile.planets[id].crewId = crew_id
	profile.planets[id].elapsed = 0.0
	save_dirty = true
	event.emit("planet_changed", {"id":id, "crewId":crew_id})
	return true

func cancel_planet_exploration(id: String) -> bool:
	if planet_progress(id).is_empty() or str(planet_progress(id).crewId).is_empty():return false
	profile.planets[id].crewId = ""
	profile.planets[id].elapsed = 0.0
	save_dirty = true
	event.emit("planet_changed", {"id":id})
	return true

func advance_planets(dt: float) -> void:
	if dt <= 0:return
	for id in profile.planets:
		var progress: Dictionary = profile.planets[id]
		if str(progress.crewId).is_empty():continue
		progress.elapsed += dt
		if progress.elapsed < planet_duration(str(id)):continue
		var member_id := str(progress.crewId)
		planet_buildings.complete(self,str(id))
		progress.crewId = member_id if progress.get("auto_explore",false) and planet_buildings.built(self,str(id),"auto_explore") else ""
		progress.elapsed = 0.0
		invalidate_stat_cache()
		var reward := planet_exp_reward(str(id))
		# Persist the completed trip and its entire crew payout together.
		var persist := save_enabled
		save_enabled = false
		if reward > 0:
			planet_crew_payout_active = true
			if planet_buffs.shares_experience(self,str(id)):
				for member in profile.crew:add_crew_exp(str(member.crewId), reward)
			else:add_crew_exp(member_id, reward)
			planet_crew_payout_active = false
		save_enabled = persist
		save_dirty = true
		event.emit("planet_changed", {"id":id, "crewId":member_id, "reward":reward})

func assign_crew(crew_id: String, assignment_type: String, target_id: String) -> bool:
	return crew.assign(self,crew_id,assignment_type,target_id)

func get_crew_modifier(target_type: String, target_id: String, effect_type: String) -> float:
	return crew.get_modifier(self,target_type,target_id,effect_type)

func dedicated_scientists(key: String) -> int:
	return int(crew.system_effect(self,"tech_ai_per_level")) if hightech_unlocked(key) else 0

func research_rate(key: String, crew_effects: Dictionary = {}) -> float:
	if not hightech_unlocked(key):return 0.0
	# The caller may share these two read-only crew projections while collecting
	# rates. The dictionary never crosses a research event or a simulation step.
	if not crew_effects.has("tech_ai_per_level"):crew_effects.tech_ai_per_level=crew.system_effect(self,"tech_ai_per_level")
	var count := assigned_scientists(key)+int(crew_effects.tech_ai_per_level)
	if count <= 0:return 0.0
	var base := float(db.config.techPointGet)*count
	if not crew_effects.has("tech_speed"):crew_effects.tech_speed=crew.system_effect(self,"tech_speed")
	return (roundf(pow(base,float(db.config.hightechLimit))) if count > 1 else base) * float(crew_effects.tech_speed)

func active_research(rates: Dictionary = {}) -> Array:
	var active: Array = []
	var crew_effects: Dictionary = {}
	for key in db.data.hightech:
		var rate := research_rate(key,crew_effects)
		if not rate > 0:continue
		active.append(key)
		rates[key]=rate
	return active

func advance_hightech(dt: float, real_dt := -1.0, end_time := -1.0) -> void:
	if real_dt < 0:
		real_dt = dt
	if end_time < 0:
		end_time = production_time()
	# All furnace production boundaries use game time; no wall-window speed amplification.
	var wall_per_step := 1.0
	var rates := {}
	var active := active_research(rates)
	# Huge point budgets cannot be settled one level/event at a time.
	# Ignore per-level rounding and use the configured cost series in this regime.
	var bulk := active.any(func(key):return float(profile.techPoints.get(key,0))+float(rates[key])*dt >= 1e20)
	if bulk:
		for key in active:
			advance_hightech_bulk(key,dt)
		# At this scale furnace output uses the end-of-step level (approximate).
		advance_furnace(dt,end_time,wall_per_step)
		return
	# Keep furnace activation at the exact research completion boundary.
	var remaining := maxf(dt,0)
	while remaining > 0:
		var step := remaining
		for key in active:
			step = minf(step,maxf(0,hightech_required(key)-float(profile.techPoints.get(key,0)))/float(rates[key]))
		advance_furnace(step,end_time-(remaining-step)*wall_per_step,wall_per_step)
		remaining -= step
		for key in active:
			profile.techPoints[key] = float(profile.techPoints.get(key,0))+float(rates[key])*step
			var required := hightech_required(key)
			if float(profile.techPoints[key])+0.00000001 >= required:
				profile.techPoints[key] = maxf(0,float(profile.techPoints[key])-required)
				profile.hightechLevels[key] = hightech_level(key)+1
				if key in [DENSE_ARMOUR, ENERGY_FOCUS]:invalidate_stat_cache()
				event.emit("hightech_complete", {"key":key})

func advance_hightech_bulk(key: String, dt: float) -> void:
	var points := minf(float(profile.techPoints.get(key,0))+research_rate(key)*dt,1e308)
	var row: Dictionary = db.data.hightech[key]
	var level := hightech_level(key)
	var growth := float(row.tpCostBase)*float(row.tpCostMutiple)
	var first := float(row.tpCostBase)+growth*level
	var linear := first-growth*0.5
	# Stable quadratic root; sqrt factors avoid overflowing growth * points.
	var root := absf(linear)
	root = sqrt(pow(root/sqrt(maxf(points,1.0)),2)+2.0*growth)*sqrt(maxf(points,1.0))
	var count := floorf(points/(linear*0.5+root*0.5)) if growth > 0 else floorf(points/maxf(1,roundf(first)))
	# Leave headroom for integer conversion and subsequent level increments.
	count = clampf(count,0,maxf(0,9e18-float(level)))
	var spent := count*(first+growth*(count-1)*0.5) if growth > 0 else count*maxf(1,roundf(first))
	if float(row.tpCostMutiple2) > 0:
		# Binary search the monotone series, including ranges crossing the threshold.
		var low := 0
		var high := int(count)
		while low < high:
			var mid := low + ((high-low+1) >> 1)
			if hightech_bulk_cost(key,level,mid) <= points:
				low = mid
			else:
				high = mid-1
		count = float(low)
		spent = hightech_bulk_cost(key,level,low)
	profile.techPoints[key] = maxf(0,points-spent)
	if count > 0:
		profile.hightechLevels[key] = level+int(count)
		if key in [DENSE_ARMOUR, ENERGY_FOCUS]:invalidate_stat_cache()
		event.emit("hightech_complete", {"key":key})

func hightech_bulk_cost(key: String, level: int, count: int) -> float:
	# Bulk settlement retains the existing unrounded approximation at huge budgets.
	if count <= 0:return 0.0
	var row: Dictionary = db.data.hightech[key]
	var growth := float(row.tpCostBase)*float(row.tpCostMutiple)
	var threshold := int(db.config.hightechCostGrowthLevel)
	var linear_count := mini(count,maxi(0,threshold-level+1))
	var total := float(linear_count)*(float(row.tpCostBase)+growth*level+growth*(linear_count-1)*0.5)
	count -= linear_count
	level += linear_count
	if count == 0:return total
	var ratio := 1.0+float(row.tpCostMutiple2)
	var multiplier := pow(ratio,level-threshold)
	var block_cost := float(row.tpCostBase)+growth*level
	var block_growth := growth
	var block_length := 1.0
	var factor := ratio
	var offset := 0.0
	# Sum arithmetic-geometric blocks in O(log count), without cancellation near ratio=1.
	while count > 0:
		if not is_finite(multiplier) or not is_finite(block_cost):return INF
		if count & 1:
			total += multiplier*(block_cost+offset*block_growth)
			if not is_finite(total):return INF
			multiplier *= factor
			offset += block_length
		count >>= 1
		if count == 0:break
		block_cost = (1.0+factor)*block_cost+factor*block_length*block_growth
		block_growth *= 1.0+factor
		block_length *= 2.0
		factor *= factor
	return total

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
		var amount := ceilf(float(settings.amount) * ratio("resRatio"))
		drops.append({"uid":uid,"x":rng.randf_range(70.0,BATTLE_SIZE.x-70.0),"y":0.0,"age":0.0,"id":settings.resource_id,"amount":amount,"speed":settings.speed,"auto_gen":true})

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
			var amount := ceilf(income * float(row.para2) * effective_hightech_level(key) * (1.0 + crew.get_modifier(self,target_type,key,"OUTPUT") + crew.get_modifier(self,target_type,key,"EFFICIENCY")))
			var block := {"uid":uid,"x":rng.randf_range(70,BATTLE_SIZE.x-70),"y":rng.randf_range(250,480),"age":age,"id":"jewel" if jewel_furnace else "1","amount":amount,"hightech":true}
			if jewel_furnace:
				block.jewel = true
				block.jewelRatio = 1.0
			drops.append(block)

func max_shield() -> Variant:
	return stat("shield") if profile.unlocked.has("shield") else 0.0

func reset_player() -> void:
	invalidate_stat_cache()
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
	enhancement_deferred.clear()
	player = {"x":PLAYER_POSITION.x, "y":PLAYER_POSITION.y, "armour":stat("armour"), "shield":max_shield()}
	since_hit = 100

func change_state(next: State) -> void:
	if next != State.COMBAT:
		projectiles = projectiles.filter(func(p): return not p.get("beam", false))
	if next == State.TRAVEL:
		travel_origin = INF
		cooldowns.clear()
		for index in range(weapon_entries().size()):
			var entry: Dictionary = weapon_entries()[index]
			var key := str(entry.key)
			if key.is_empty():
				continue
			var cd := float(player_weapon_row(entry).cd)
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

func advance_after_clear() -> bool:
	if state != State.LEVEL_CLEAR or not pending_unlocks.is_empty():
		return false
	return start(next_stage(), profile.loop and not guard_arrived)

func next_stage() -> int:
	return mini(stage + 1, db.levels.size())

func start(level: int, loop_mode: bool, checkpoint: Dictionary = {}) -> bool:
	if level < 1 or level > int(profile.highestLevel):
		return false
	if N.compare(stat("armour"),0)<=0:
		event.emit("battle_blocked",{"reason":"zero_armour"})
		return false
	settle_drops()
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

func is_active() -> bool:
	return state in [State.TRAVEL, State.COMBAT] and N.compare(player.get("armour",0),0)>0

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

func spawn_group(keep_distance := false) -> void:
	guard_engaged = true
	var encounter: Dictionary = db.levels[stage - 1].groups[group_index]
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
	var placement := preload("res://scripts/enemy_formation.gd").positions(slots,db.enemies,explicit)
	if explicit!=null and placement.is_empty():
		push_error("Encounter rejected: invalid formation_positions")
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
		enemy.hp = ceilf(float(row.health) * ratio("lifeRatio"))
		enemy.max_hp = enemy.hp
		enemy.max_shield = ceilf(float(row.get("shield",0)) * ratio("lifeRatio"))
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
	if is_boss_encounter() and not profile.bossSeen.has(stage):
		profile.bossSeen.append(stage)
		save_dirty = true
	change_state(State.COMBAT)
	event.emit("encounter", {"boss":is_boss_encounter(),"tier":encounter_tier(),"final":is_final_encounter()})

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
	var alive: Array[Dictionary] = []
	for e in enemies:
		if e.hp > 0:
			alive.append(e)
	alive.sort_custom(func(a,b):
		if damage_type != 0:
			var a_resists := enemy_resistance_type(a) == damage_type
			var b_resists := enemy_resistance_type(b) == damage_type
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
	settle_enemy_shield(enemy,enemy_shield_time if enemy_shield_hit_time<0 else enemy_shield_hit_time)
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
	var visuals = preload("res://scripts/ship_visuals.gd")
	return visuals.muzzle(str(profile.selectedShip), index).rotated(-PI/2) * visuals.scale_for(db.ship(str(profile.selectedShip)))

func fire(source: Dictionary, target: Dictionary, weapon: Dictionary, raw, hostile: bool, key: String, offset := Vector2.ZERO, visual_spread := 0.0) -> void:
	var speed_parameter = weapon.para2 if key.begins_with("missile") else weapon.para1
	projectiles.append({"x":float(source.x) + offset.x,"y":float(source.y) + offset.y, "target":target,"damage":raw,"type":int(weapon.dmgtype),"speed":float(speed_parameter)*db.projectile_pixels_per_unit(hostile),"hostile":hostile,"key":key,"dead":false})
	var shot: Dictionary = projectiles.back()
	projectile_serial += 1
	shot.serial = projectile_serial
	shot.source_uid=int(source.get("uid",0))
	shot.direction = Vector2(0,1 if hostile else -1) if key.replace("_mon", "").replace("-mon", "") == "missile" else Vector2(target.x - shot.x, target.y - shot.y).normalized()
	prepare_projectile(shot,source,weapon,visual_spread)
	event.emit("fire", {"x":shot.x,"y":shot.y,"type":int(weapon.dmgtype),"shot":shot,"spread":visual_spread})

func prepare_projectile(_shot: Dictionary, _source: Dictionary, _weapon: Dictionary, _spread: float) -> void:
	pass

# A beam is one persistent projectile per mount; timing belongs to that object.
func long_laser_valid(shot: Dictionary) -> bool:
	if state != State.COMBAT or shot.dead or shot.target.is_empty() or not is_same(shot.target, shot.locked_target):
		return false
	if shot.hostile:
		return enemies.has(shot.source) and shot.source.hp > 0 and is_same(shot.target, player) and N.compare(player.armour,0)>0 and shot.mount < shot.source.equipment.size() and is_same(shot.entry, shot.source.equipment[shot.mount])
	return is_same(shot.source, player) and N.compare(player.armour,0)>0 and enemies.has(shot.target) and shot.target.hp > 0 and is_same(shot.entry, slot_entry("weapons", shot.mount)) and shot.entry.key == "longLaser"

func lock_long_laser(source: Dictionary, weapon: Dictionary, hostile: bool, mount: int, entry: Dictionary, repeated := false, repeat_multiplier := 1.0, repeat_depth := 0, repeat_origin_multiplier := 1.0, inherited_snapshot: Dictionary = {}) -> void:
	for shot in projectiles:
		if shot.get("beam", false) and shot.hostile == hostile and is_same(shot.source, source) and shot.mount == mount and bool(shot.get("repeated",false)) == repeated and int(shot.get("repeat_depth",0))==repeat_depth and long_laser_valid(shot):
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
	fire(source, target, weapon, 0, hostile, "longLaser-mon" if hostile else "longLaser", offset)
	var shot: Dictionary = projectiles.back()
	shot.merge({"beam":true, "repeated":repeated, "repeat_multiplier":repeat_multiplier, "repeat_depth":repeat_depth, "repeat_origin_multiplier":repeat_origin_multiplier, "charged_multiplier":1.0, "locked_target":target, "source":source, "mount":mount, "entry":entry, "elapsed":0.0, "ticks":0, "weapon":weapon, "charge":maxf(0,float(weapon.para3)) if weapon.get("para3") != null else -1.0})
	if not hostile and not repeated:
		var id := slot_id("weapons",mount)
		shot.charged_multiplier = float(jewel_charged.get(id,1.0))
		shot.repeat_origin_multiplier=shot.charged_multiplier
		jewel_charged.erase(id)
	if not hostile:
		if repeated:
			shot.attack_snapshot=inherited_snapshot
			record_enhancement_attack()
		else:
			begin_enhancement_attack(mount,target)
			record_enhancement_attack()
			jewel_attack(mount)
			shot.attack_snapshot=enhancement_attack_contexts[mount].snapshot
			finish_enhancement_attack(mount)
		shot.main_attack_id=shot.attack_snapshot.id
		shot.attack_instance=new_attack_instance(shot.attack_snapshot) if repeated else shot.attack_snapshot.instance
		shot.attack_instance_id=shot.attack_instance.id
		bind_beam_chain(shot)

	event.emit("beam_started", {"shot":shot})

func long_laser_multiplier(weapon: Dictionary, duration: float) -> float:
	return minf(1.0 + (float(weapon.para2) - 1.0) * duration / float(weapon.para1), float(weapon.para2)) if float(weapon.para1) > 0 else float(weapon.para2)

func advance_long_laser(shot: Dictionary, dt: float) -> bool:
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
	var first_hit := float(shot.charge) if float(shot.charge) >= 0 else interval
	var previous_hit_time := enemy_shield_hit_time
	enemy_shield_hit_time=enemy_shield_time-float(shot.elapsed)+due
	shot.ticks += 1
	var duration := due-first_hit if float(shot.charge)>=0 else due
	var multiplier := long_laser_multiplier(weapon, duration)
	event.emit("beam_hit", {"shot":shot})
	if shot.hostile:
		var raw := ceilf(float(weapon.dmg) * float(shot.source.dmgMultiple) * ratio("atkRatio"))
		hit_player(raw * multiplier, int(weapon.dmgtype),{"source_uid":int(shot.source.get("uid",0)),"weapon_key":"longLaser"})
	else:
		enhancement_attack_contexts[int(shot.mount)]={"derived":bool(shot.repeated),"snapshot":shot.attack_snapshot,"instance":shot.attack_instance}
		var boost := float(shot.repeat_multiplier) * float(shot.charged_multiplier)
		if int(shot.ticks)==1 and not shot.repeated:
			queue_jewel_repeats(shot.mount,boost,shot)
		var attack := jewel_attack(shot.mount, multiplier * boost)
		if attack.critical:
			event.emit("critical_impact", {"pos":Vector2(shot.target.x,shot.target.y),"direction":Vector2(shot.target.x-shot.x,shot.target.y-shot.y).normalized()})
		hit_enemy(shot.target,attack.damage,int(weapon.dmgtype),attack.effects,attack.critical)
		launch_enhancement_secondary(int(shot.mount),shot.target,weapon,boost*multiplier,true)
		enhancement_attack_contexts.erase(int(shot.mount))
	if not projectiles.has(shot) or not long_laser_valid(shot):
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
		if shot.dead:break

func tick_shield_beams(pending: Array, dt: float) -> void:
	# Flying rounds and asynchronous chain hops hit at the step boundary. Beam
	# periods can precede it, so merge periods across mounts before those hits.
	var hits: Array[Dictionary] = []
	for index in pending.size():
		var shot: Dictionary = pending[index]
		if not shot.get("beam",false) or not projectiles.has(shot):continue
		if not advance_long_laser(shot,dt):continue
		var weapon: Dictionary = db.enemy_weapon(shot.entry.name) if shot.hostile else shot.attack_snapshot.weapon
		while float(shot.next_hit_at)<=float(shot.elapsed)+0.000000001:
			var due := float(shot.next_hit_at)
			hits.append({"at":enemy_shield_time-float(shot.elapsed)+due,"due":due,"index":index,"shot":shot})
			shot.next_hit_at=due+float(weapon.cd)
	hits.sort_custom(func(a,b):return a.index<b.index if a.at==b.at else a.at<b.at)
	for item in hits:
		var shot: Dictionary = item.shot
		if not projectiles.has(shot) or not long_laser_valid(shot):continue
		apply_long_laser_hit(shot,float(item.due))

func hit_player(raw, type: int, context: Dictionary = {}) -> void:
	record_enhancement_hit() # Exactly once per incoming attack, even if protection absorbs it.
	enhancement_branches.memory_incoming(self,type)
	var modified=N.multiply(raw,enhancement_branches.incoming_multiplier(self,int(context.get("source_uid",0))))
	jewel_hit_player(modified,type)

func begin_retreat() -> void:
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
		if not profile.seenUnlocks.has(key):profile.seenUnlocks.append(key)
	save_dirty = true
	event.emit("state", {"state":state})

func hit_enemy(enemy: Dictionary, raw, type: int, effects: Array = [], critical: bool = false) -> void:
	if enemy.hp <= 0:
		return
	var chain_origin := Vector2(enemy.x,enemy.y)
	for effect in effects:
		var chain:Dictionary=effect.get("chain_state",{})
		if effect.get("chain",false) and not chain.get("used",false) and not effect.get("chain_used",false):
			chain_origin=chain_target_point(enemy);break
	jewel_on_hit(enemy, effects)
	var resistance := float(db.config.dmgReduce)
	for effect in effects:
		if effect.has("enemy_resistance"):resistance=float(effect.enemy_resistance);break
	var incoming = N.multiply(raw,1.0+float(enemy.get("interference",0)))
	var absorbed = 0.0
	if float(enemy.get("max_shield",0))>0:
		incoming=N.maximum(1,incoming)
		var at := maxf(float(enemy.get("shield_updated_at",enemy_shield_time)),enemy_shield_time if enemy_shield_hit_time<0 else enemy_shield_hit_time)
		settle_enemy_shield(enemy,at)
		# A periodic beam hit is a hit, even though the whole beam is one attack.
		enemy.shield_hit_at=at
		if N.compare(enemy.get("shield",0),0)>0:
			var factor := 1.0-resistance if type==int(enemy.get("shieldType",0)) else 1.0
			absorbed=N.minimum(enemy.shield,N.maximum(1,N.multiply(incoming,factor)))
			enemy.shield=N.subtract(enemy.shield,absorbed)
			incoming=N.maximum(0,N.subtract(incoming,N.divide(absorbed,factor))) if factor>0 else 0.0
	var amount = 0.0
	if N.compare(absorbed,0)<=0 or N.compare(incoming,0)>0:
		amount=N.maximum(1,N.ceiling(N.multiply(incoming,1.0-resistance if type==int(enemy.armourType) else 1.0)))
		enemy.hp=N.subtract(enemy.hp,amount)
	amount=N.add(amount,absorbed)
	event.emit("hit", {"x":enemy.x,"y":enemy.y,"amount":amount,"player":false,"type":type,"uid":enemy.uid,"critical":critical})
	if enemy.hp <= 0:
		break_beam_chain_target(enemy)
		if is_final_encounter() and targets().is_empty():
			projectiles.clear()
		event.emit("explode", enemy)
		jewel_kill_drop(enemy)
		for drop in enemy.drops:
			if rng.randf() < float(drop.chance):
				uid += 1
				var multiplier = reactor_multiplier("smelting") if int(drop.resourceId) == 1 else 1.0
				var base_amount = N.ceiling(N.multiply(N.multiply(drop.amount,float(enemy.res_ratio)*multiplier),1.0+float(enemy.get("jewelIron",0)) if int(drop.resourceId)==1 else 1.0))
				var drop_amount = N.ceiling(N.multiply(base_amount,planet_resource_multiplier())) if int(drop.resourceId) in [1,2] else base_amount
				drops.append({"uid":uid,"x":enemy.x,"y":enemy.y+40,"source_uid":enemy.uid,"age":0.0,"id":str(int(drop.resourceId)),"amount":drop_amount,"production_base":base_amount})

		if float(enemy.get("jewelExplosion", 0)) > 0:
			for adjacent in enemies.duplicate():
				if adjacent.hp > 0 and abs(int(adjacent.slot) - int(enemy.slot)) in [1, 2]:
					hit_enemy(adjacent, float(enemy.max_hp) * float(enemy.jewelExplosion), type)

	launch_enhancement_chain(enemy,raw,type,effects,critical,chain_origin)

func collect(drop: Dictionary, manual: bool) -> void:
	if not drops.has(drop):
		return
	if drop.has("jewel"):
		if not jewels_unlocked():
			return
		var core: bool = drop.get("hightech",false)
		if core and not manual and float(drop.get("age",0)) < 10.0:
			return
		drops.erase(drop)
		var amount := float(drop.get("amount",1))
		if core and not manual:
			amount = ceilf(amount * (1.0 - float(db.config.autoCollectReduce)))
		drop.amount = settle_jewel_fragments(amount, "furnace" if core else "drop", 1.0 if core else float(drop.get("jewelRatio", jewel_ratio())))
		enhancement_currency_changed()
		event.emit("jewel_pickup", drop)
		return
	if drop.get("hightech", false) and not manual and float(drop.get("age",0)) < 10.0:
		return
	drops.erase(drop)
	# Auto-collection loss is a separate calculation on the integer drop amount.
	var amount = N.ceiling(N.multiply(drop.amount,1.0 if manual else 1.0 - float(db.config.autoCollectReduce)))
	profile.resources[drop.id] = N.add(profile.resources[drop.id],amount)
	resource_samples.append({"time":economy_time(),"production_time":production_time(),"id":str(drop.id),"amount":amount,"production_base":N.ceiling(N.multiply(drop.get("production_base",drop.amount),1.0 if manual else 1.0-float(db.config.autoCollectReduce))),"origin":"furnace" if drop.get("hightech",false) else "drop"})
	profile.furnaceIncomePeak = furnace_income_peak()
	run_resources[drop.id] = N.add(run_resources[drop.id],amount)
	var info := drop.duplicate()
	info.amount = amount
	info.manual = manual
	event.emit("collect", info)
	save_dirty = true

func settle_drops() -> void:
	for drop in drops.duplicate():
		collect(drop, false)

func collect_near(pos: Vector2, _clicked := false, position_overrides: Dictionary = {}, path_start: Variant = null) -> void:
	if paused:
		return
	for drop in drops.duplicate():
		var drop_pos: Vector2 = position_overrides.get(int(drop.uid),Vector2(drop.x,drop.y))
		var nearest := Geometry2D.get_closest_point_to_segment(drop_pos,path_start,pos) if path_start is Vector2 else pos
		if drop_pos.distance_to(nearest) < 55:
			collect(drop, true)

func clear_level() -> void:
	var previous := available_unlocks()
	first_clear = not profile.cleared.has(stage)
	if first_clear:
		profile.cleared.append(stage)
	rebuild_unlocks()
	for key in available_unlocks():
		if not previous.has(key) and not profile.get("seenUnlocks",[]).has(key) and not pending_unlocks.has(key):
			pending_unlocks.append(key)
	clear_timer = CLEAR_ADVANCE_DELAY
	change_state(State.LEVEL_CLEAR)
	save_dirty = true
	if not pending_unlocks.is_empty():
		event.emit("unlock", {"items":pending_unlocks.duplicate(), "equipment":pending_unlocks.filter(func(id):return db.data.unlock[id].type == "equipment")})

func upgrade_cost_for_level(key: String, level: int) -> Dictionary:
	if _upgrade_batch and _upgrade_costs.get(key,{}).has(level):
		return _upgrade_costs[key][level]
	var cost := db.equipment_cost(key,level)
	if _upgrade_batch:
		if not _upgrade_costs.has(key):_upgrade_costs[key]={}
		_upgrade_costs[key][level]=cost
	return cost

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

func max_upgrade_amount_slot(category: String, index: int) -> int:
	var entry := slot_entry(category,index)
	var key := module_cost_key(category)
	if entry.is_empty():
		return 0
	var available: Dictionary = profile.resources.duplicate()
	var amount := 0
	var current := int(entry.level)
	var level := current + 1
	while level <= db.max_equipment_level(key):
		var costs := upgrade_cost_for_level(key, level)
		var affordable := true
		for id in costs:
			if not is_finite(float(costs[id])) or N.compare(available.get(id,0),costs[id])<0:
				affordable = false
				break
		if not affordable:
			break
		for id in costs:
			available[id] = N.subtract(available.get(id,0),costs[id])
		amount += 1
		level += 1
	return amount

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
	if not can_upgrade_slot(category, index, levels):
		return false
	var entry = slot_entry(category, index)
	var key = str(entry.key)
	var costs = slot_upgrade_cost(category, index, levels)
	for id in costs:
		profile.resources[id] = N.subtract(profile.resources[id],costs[id])
	var before = jewel_equipment_stat(entry)
	profile.loadout[category][index].level = int(entry.level) + levels
	resources_changed(costs.keys())
	invalidate_stat_cache()
	var after = jewel_equipment_stat(entry)
	# Preserve existing damage and cooldowns; upgrading a weapon never heals the ship.
	if key == "armour" and state != State.RETREAT:
		player.armour = N.add(player.armour,N.subtract(after,before))
	elif key == "shield" and state != State.RETREAT:
		player.shield = N.add(player.shield,N.subtract(after,before))
	if _upgrade_batch:
		_upgrade_slots.append(slot_id(category,index))
	else:
		save_dirty = true
	event.emit("upgrade", {"key":key,"slot":slot_id(category,index),"levels":levels,"cost":costs,"batch":_upgrade_batch})
	return true

func upgrade_equipment_batch(mode: String) -> bool:
	if _upgrade_batch:return false
	_upgrade_batch=true
	for category in ["weapons","defence"]:
		for index in loadout_entries(category).size():
			var amount: int=max_upgrade_amount_slot(category,index) if mode=="max" else int(mode)
			if amount>0:upgrade_slot(category,index,amount)
	_upgrade_batch=false
	_upgrade_costs.clear()
	var changed := _upgrade_slots
	_upgrade_slots=[]
	if not changed.is_empty():
		save_dirty = true
		event.emit("upgrades_completed",{"slots":changed})
	return not changed.is_empty()

func upgrade_max(key: String) -> bool:
	var levels := max_upgrade_amount(key)
	return levels > 0 and upgrade(key, levels)

func leave(next: State) -> void:
	settle_drops()
	projectiles.clear()
	enemies.clear()
	paused = false
	change_state(next)

func weapon_cooldown_after_shot(_remaining_before: float, _dt: float, interval: float) -> float:
	# Every multiplier uses the same fixed-step attack schedule as X1.
	return interval

func settle_enemy_shield(enemy: Dictionary, at: float) -> void:
	if float(enemy.hp)<=0 or float(enemy.get("max_shield",0))<=0:return
	var before := float(enemy.get("shield_updated_at",at))
	var ready_at := float(enemy.get("shield_hit_at",at))+float(enemy.get("shieldDelay",0))
	var healing_time := maxf(0,at-ready_at)-maxf(0,before-ready_at)
	if healing_time>0:
		enemy.shield=N.minimum(enemy.max_shield,N.add(enemy.shield,N.multiply(enemy.max_shield,float(enemy.get("shieldRecovery",0))*healing_time)))
	enemy.shield_updated_at=at

func advance_enemy_shields(dt: float) -> void:
	enemy_shield_time+=dt
	for enemy in enemies:settle_enemy_shield(enemy,enemy_shield_time)

func tick(dt: float) -> void:
	if paused:
		return
	profile.productionElapsed=production_time()+dt
	hyperspace.advance(self,dt)
	enhancement_branches.advance_weapons(self,dt)
	advance_planets(dt)
	galaxy.advance(self,dt)
	crew.advance(self,dt)
	advance_auto_gen(dt)
	advance_hightech(dt, dt / maxf(speed, 0.001))
	resource_prune_elapsed += dt / maxf(speed, 0.001)
	if resource_prune_elapsed >= 5.0:
		resource_prune_elapsed = 0
		prune_resource_samples(economy_time())
	for drop in drops.duplicate():
		if drop.get("hightech", false) or drop.get("auto_gen", false):
			continue
		drop.age += dt
		if drop.age >= (2.0 if drop.has("jewel") else float(db.defaults.autoCollectDelay)):
			collect(drop, false)
	if state == State.LEVEL_CLEAR:
		since_hit+=dt
		advance_jewel_repair(dt)
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
			if N.compare(player.armour,0)<=0:
				change_state(State.LEVEL_SELECT)
				event.emit("battle_blocked",{"reason":"zero_armour"})
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
	since_hit += dt
	var defence_jewels := advance_jewel_repair(dt)
	if state==State.RETREAT:return
	advance_jewel_repeats(dt)
	var shield_entry := first_equipment_entry("shield")
	var shield := db.equip("shield", int(shield_entry.level)) if not shield_entry.is_empty() else db.equip("shield", 1)
	if not defence_jewels and since_hit >= float(shield.para3):
		player.shield = N.minimum(max_shield(),N.add(player.shield,N.multiply(max_shield(),float(shield.para2)*dt)))
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
	projectiles = projectiles.filter(func(p): return not p.get("beam", false) or long_laser_valid(p))
	for index in range(weapon_entries().size()):
		var entry: Dictionary = weapon_entries()[index]
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
			var count := int(weapon.para1) if key == "missile" else 1
			if not candidates.is_empty():
				begin_enhancement_attack(index,candidates[0])
				record_enhancement_attack()
			var charged := float(jewel_charged.get(id, 1.0))
			if count > 0 and not candidates.is_empty():
				jewel_charged.erase(id)
			for i in range(count):
				if candidates.is_empty():
					break
				var target := candidates[i % candidates.size()] if key == "missile" else candidates[0]
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
				var raw := ceilf(float(weapon.dmg) * float(enemy.dmgMultiple) * ratio("atkRatio"))
				fire(enemy, player, weapon, raw, true, entry.name, enemy_weapon_offset(enemy, i))
				enemy.cooldowns[i] = weapon_cooldown_after_shot(cooldown_before,dt,float(weapon.cd))
	tick_projectiles(dt)
	for enemy in enemies:settle_enemy_shield(enemy,enemy_shield_time)
	if state == State.COMBAT and not has_alive_enemy():
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

func tick_projectiles(dt: float) -> void:
	# Overrides select pending launches at step start; only this base advances
	# the shield clock, before resolving scheduled periods and boundary hits.
	if state==State.COMBAT:enemy_shield_time+=dt
	var pending := projectiles.duplicate()
	var shield_timing := enemies.any(func(enemy):return float(enemy.get("max_shield",0))>0)
	if shield_timing:tick_shield_beams(pending,dt)
	for index in pending.size():
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
		if advance_custom_projectile(shot,dt):continue
		if shot.get("beam", false):
			if not shield_timing:tick_long_laser(shot, dt)
			continue
		if not shot.target.is_empty():
			var target_dead: bool = N.compare(shot.target.armour,0)<=0 if shot.hostile else shot.target.hp <= 0 or not enemies.has(shot.target)
			if target_dead:
				# Keep the last heading; a missile never acquires a replacement target.
				shot.target = {}
		if not shot.target.is_empty():
			var delta := Vector2(shot.target.x - shot.x, shot.target.y - shot.y)
			var homing: bool = str(shot.key).replace("_mon", "").replace("-mon", "") == "missile"
			if homing:shot.direction = delta.normalized()
			# Ordinary rounds keep their launch direction. A moving target must
			# intersect this step's segment; proximity alone must not bend the shot.
			var along: float = delta.dot(shot.direction)
			var intersects := along>=0 and along<=float(shot.speed)*dt and absf(delta.cross(shot.direction))<=0.5
			if (delta.length() <= shot.speed*dt) if homing else intersects:
				shot.dead = true
				event.emit("projectile_impact", {"shot":shot,"pos":Vector2(shot.target.x,shot.target.y)})
				if shot.hostile:
					hit_player(shot.damage,shot.type,{"source_uid":int(shot.get("source_uid",0)),"weapon_key":str(shot.key)})
				else:
					hit_enemy(shot.target, shot.damage, shot.type, shot.get("jewelEffects", []),shot.get("critical",false))
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
	projectiles = projectiles.filter(func(p): return not p.dead and (not p.get("beam", false) or long_laser_valid(p)))

func advance_custom_projectile(_shot: Dictionary, _dt: float) -> bool:
	return false

# Existing feature identity and fragment currency remain compatible with unlocks and furnace production.
func jewels_unlocked() -> bool:
	return content_unlocked("feature", "jewels")

func load_jewels(raw: Dictionary) -> void:
	# Enhancement schema v1 replaces bag, sockets and per-module history once.
	# Legacy saves retain only their existing fragment balance, with no refund.
	invalidate_stat_cache()
	profile.jewels = []
	profile.jewelFragments = 0.0
	if N.valid(raw.get("jewelFragments")):
		profile.jewelFragments=raw.jewelFragments.duplicate(true) if raw.jewelFragments is Dictionary else float(raw.jewelFragments)
	elif raw.get("jewelFragments") is Dictionary:
		for id in raw.jewelFragments:
			if nonnegative_number(raw.jewelFragments[id]):profile.jewelFragments += float(raw.jewelFragments[id])
	elif nonnegative_number(raw.get("jewelFragments")):
		profile.jewelFragments = float(raw.jewelFragments)
	profile.enhancementVersion = 1
	profile.enhancementLevel = 0
	profile.enhancementOrder = default_enhancement_order()
	profile.enhancementBranches = default_enhancement_branches()
	profile.enhancementAttacks = 0
	profile.enhancementHits = 0
	if int(raw.get("enhancementVersion",0)) == 1 or raw.has("enhancementLevel"):
		for field in ["enhancementLevel", "enhancementAttacks", "enhancementHits"]:
			var value = raw.get(field,0)
			if nonnegative_number(value) and float(value)==floorf(float(value)) and float(value)<9223372036854775807.0 and (field!="enhancementLevel" or float(value)<=ENHANCEMENT_LEVEL_LIMIT):
				profile[field] = int(value)
		var orders = raw.get("enhancementOrder",{})
		if orders is Dictionary:
			for category in ["weapons","defence"]:
				if valid_enhancement_order(category,orders.get(category)):profile.enhancementOrder[category]=orders[category].duplicate()
		var branches = raw.get("enhancementBranches",{})
		if branches is Dictionary:
			for category in default_enhancement_order():
				var effects = branches.get(category,{})
				if not effects is Dictionary:continue
				for effect in default_enhancement_order()[category]:
					var nodes = effects.get(effect,{})
					if not nodes is Dictionary:continue
					for node in ["1","2","3"]:
						if nodes.get(node,"") in ["A","B"]:profile.enhancementBranches[category][effect][node]=nodes[node]

	for category in ["weapons","defence"]:
		for entry in module_entries(category):
			for field in ["sockets","attacks","hits"]:entry.erase(field)

func jewel_ratio() -> float:
	var value = db.levels[clampi(stage-1,0,db.levels.size()-1)].get("jewelRatio",1.0)
	return float(value) if nonnegative_number(value) else 1.0

func jewel_fragment_amount(amount: float, ratio := -1.0) -> float:
	if not nonnegative_number(amount):
		return 0.0
	var result := amount * (jewel_ratio() if ratio < 0 else ratio)
	return snappedf(result,0.01) if nonnegative_number(result) else 0.0

func settle_jewel_fragments(amount: float, source: String, ratio := -1.0) -> float:
	var earned := jewel_fragment_amount(amount * (crew.system_effect(self,"gem_bonus") * reactor_multiplier("condensation") * galaxy.multiplier("gem_fragment") if source=="drop" else 1.0),ratio)
	profile.jewelFragments = N.add(profile.jewelFragments,earned)
	if not profile.jewelFragments is Dictionary:profile.jewelFragments=snappedf(float(profile.jewelFragments),0.01)
	# Production only: refunds must not inflate future income.
	if source in ["drop","furnace"] and earned > 0:
		resource_samples.append({"time":economy_time(),"production_time":production_time(),"id":"jewel","amount":earned,"origin":source})
		profile.jewelFurnaceIncomePeak = furnace_income_peak(-1,true)
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
	if not jewels_unlocked() or rng.randf() >= float(db.config.get("jewelDrop",0)):
		return
	uid += 1
	drops.append({"uid":uid,"x":enemy.x,"y":enemy.y+65,"age":0.0,"jewel":true,"jewelRatio":jewel_ratio(),"id":"jewel","amount":1})

func default_enhancement_order() -> Dictionary:
	return {"weapons":["proficiency","repeat","critical"],"defence":["adaptation","memory_material","delayed_damage"]}

func default_enhancement_branches() -> Dictionary:
	var result := {}
	for category in default_enhancement_order():
		result[category]={}
		for effect in default_enhancement_order()[category]:result[category][effect]={}
	return result

func enhancement_effect_threshold(index: int) -> int:
	return int(enhancement_parameter("threshold_%d" % (index+1))) if index in [0,1,2] else -1

func enhancement_branch_threshold(node: int, category: String, effect: String) -> int:
	if node not in [1,2,3]:return -1
	var index: int=profile.enhancementOrder.get(category,[]).find(effect)
	if index<0:return -1
	return int(enhancement_parameter("branch_threshold_%d" % node)+enhancement_parameter("branch_position_offset_%d" % (index+1)))

func valid_enhancement_branch(category: String, effect: String, node: int) -> bool:
	return default_enhancement_order().has(category) and default_enhancement_order()[category].has(effect) and node in [1,2,3]

func enhancement_branch_unlocked(category: String, effect: String, node: int) -> bool:
	return enhancement_unlocked() and valid_enhancement_branch(category,effect,node) and enhancement_effective_level()>=enhancement_branch_threshold(node,category,effect)

func enhancement_branch_choices(category: String, effect: String) -> Dictionary:
	return profile.enhancementBranches.get(category,{}).get(effect,{}).duplicate()

func enhancement_branch_choice(category: String, effect: String, node: int) -> String:
	return str(profile.enhancementBranches.get(category,{}).get(effect,{}).get(str(node),""))

func set_enhancement_branch(category: String, effect: String, node: int, choice: String) -> bool:
	if not enhancement_branch_unlocked(category,effect,node) or choice not in ["A","B"]:return false
	if enhancement_branch_choice(category,effect,node)==choice:return true
	profile.enhancementBranches[category][effect][str(node)]=choice
	# Selection invalidates projections and only the removed branch's transient buffs.
	invalidate_stat_cache()
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
			result.history=int(profile.enhancementAttacks if effect=="proficiency" else profile.enhancementHits)
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
	return float(db.data.enhance_config[key].value)

func enhancement_unlocked() -> bool:
	return jewels_unlocked()

func enhancement_level() -> int:
	return int(profile.enhancementLevel)

func enhancement_level_bonus() -> int:
	return gem_drop_level_bonus()

func enhancement_effective_level() -> int:
	return enhancement_level() + enhancement_level_bonus()

func enhancement_level_limit() -> int:
	return ENHANCEMENT_LEVEL_LIMIT

func enhancement_at_limit() -> bool:
	return enhancement_level()>=enhancement_level_limit()

func enhancement_cost(target_level := -1) -> Variant:
	var target := enhancement_level()+1 if target_level<0 else target_level
	if target<1:return 0.0
	return N.ceiling(N.multiply(enhancement_parameter("cost_base"),N.power(enhancement_parameter("cost_growth"),target-1)))

func can_upgrade_enhancement() -> bool:
	return enhancement_unlocked() and not enhancement_at_limit() and N.compare(profile.jewelFragments,enhancement_cost())>=0

func enhancement_purchase_cost(count: int) -> Variant:
	if count<=0:return 0.0
	var first = enhancement_cost()
	if count==1:return first
	var growth := enhancement_parameter("cost_growth")
	# Integer authored growth means every level costs whole fragments. Sum the
	# next count levels geometrically, without subtracting large prefix sums or
	# traversing levels. GrowthNumber keeps overflowing powers JSON-safe.
	var factor = float(count) if growth==1.0 else N.divide(N.subtract(N.power(growth,count),1.0),growth-1.0)
	return N.ceiling(N.multiply(first,factor))

func enhancement_max_upgrades(limit := -1) -> int:
	if not enhancement_unlocked():return 0
	var low := 0
	var high := enhancement_level_limit()-enhancement_level()
	if limit>=0:high=mini(high,limit)
	while low<high:
		var middle := low+int((high-low+1)/2)
		if N.compare(profile.jewelFragments,enhancement_purchase_cost(middle))>=0:low=middle
		else:high=middle-1
	return low

func upgrade_enhancement(count := 1) -> int:
	if count==0 or not enhancement_unlocked():return 0
	var purchased := enhancement_max_upgrades(count)
	if purchased>0:
		profile.jewelFragments=N.subtract(profile.jewelFragments,enhancement_purchase_cost(purchased))
		profile.enhancementLevel+=purchased
		invalidate_stat_cache()
		sync_enhancement_buffers()
		save_dirty = true
		event.emit("enhancement_changed", {"purchased":purchased})
		event.emit("jewels_changed", {"slot":"","slots":[]})
		for category in ["weapons","defence"]:event.emit("equipment_stats",{"category":category})
	return purchased

func enhancement_order(category: String) -> Array:
	return profile.enhancementOrder.get(category,[]).duplicate()

func valid_enhancement_order(category: String, value: Variant) -> bool:
	if not value is Array or value.size()!=3 or not default_enhancement_order().has(category):return false
	var remaining: Array = default_enhancement_order()[category].duplicate()
	for kind in value:
		if not kind is String or not remaining.has(kind):return false
		remaining.erase(kind)
	return remaining.is_empty()

func set_enhancement_order(category: String, order: Array) -> bool:
	if not enhancement_unlocked() or not valid_enhancement_order(category,order):return false
	if enhancement_order(category)==order:return true
	profile.enhancementOrder[category]=order.duplicate()
	invalidate_stat_cache()
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
	if not enhancement_unlocked():return 0
	var count := 0
	var shared_level := enhancement_effective_level()
	for index in 3:
		if shared_level>=enhancement_effect_threshold(index):count+=1
	return count

func record_enhancement_attack() -> void:
	profile.enhancementAttacks += 1
	for key in WEAPON_KEYS:invalidate_equipment_counter(key)
	event.emit("equipment_stats",{"category":"weapons"})

func record_enhancement_hit() -> void:
	profile.enhancementHits += 1
	for key in DEFENSE_KEYS:invalidate_equipment_counter(key)
	event.emit("equipment_stats",{"category":"defence"})

func enhancement_currency_changed() -> void:
	save_dirty = true
	event.emit("jewels_changed", {"slot":"","slots":[]}) # Legacy event name retained for currency consumers.

func enhancement_effects(entry: Dictionary) -> Array:
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
	var effect := {"kind":kind,"level":level,"threshold":enhancement_effect_threshold(i),"p2":0.0,"p4":0.0,"p5":0.0}
	match kind:
		"proficiency","adaptation":effect.p2=enhancement_parameter(kind+"_growth")
		"repeat":
			effect.p2=enhancement_parameter("repeat_probability")
			effect.p4=enhancement_parameter("repeat_growth")
		"critical":effect.p4=enhancement_parameter("critical_growth")
		"delayed_damage":effect.p2=enhancement_deferred_fraction()
		"memory_material":
			effect.p2=enhancement_parameter("memory_heal_fraction")
			effect.p4=enhancement_parameter("memory_buffer_fraction")
	return effect

func active_enhancement_effect_count(entry: Dictionary) -> int:
	return available_effect_count(entry)

func _enhancement_effect_index(entry: Dictionary, kind: String) -> int:
	# Scalar membership query; no effect payloads or retained/cross-tick cache.
	if kind.is_empty():return -1
	var count := active_enhancement_effect_count(entry)
	if count<=0:return -1
	var category := "weapons" if WEAPON_KEYS.has(str(entry.key)) else "defence"
	var order: Array = profile.enhancementOrder.get(category,[])
	for i in count:
		if str(order[i])==kind:return i
	return -1

func has_enhancement_effect(entry: Dictionary, kind: String) -> bool:
	return _enhancement_effect_index(entry,kind)>=0

func jewel_effects(entry: Dictionary) -> Array:
	return enhancement_effects(entry)

func jewel_equipment_stat(entry: Dictionary, level := -1, effects: Variant = null, include_timed_buffs := true) -> Variant:
	if str(entry.get("key", "")).is_empty():
		return 0
	var value = equipment_stat(str(entry.key), int(entry.level) if level < 0 else level)
	var projected := entry
	if level>=0:
		projected=entry.duplicate()
		projected.level=level
	for effect in (jewel_effects(projected) if effects == null else effects):
		if effect.kind in ["proficiency", "adaptation"]:
			var count := maxi(1, int(profile.get("enhancementAttacks" if effect.kind == "proficiency" else "enhancementHits", 0)))
			var bonus := roundf(float(effect.p2) * int(effect.level) * log(float(count)) / log(enhancement_parameter("counter_log_base")) * enhancement_parameter("bonus_round_scale")) / enhancement_parameter("bonus_round_scale")
			value = N.ceiling(N.multiply(value,1.0+bonus))
	value=N.multiply(value,enhancement_branches.weapon_multiplier(self,projected,entry,include_timed_buffs) if WEAPON_KEYS.has(str(entry.key)) else enhancement_branches.capacity_multiplier(self,projected))
	var crew_bonus: float
	if stat_cache_enabled and stat_cache.has("crew_equipment"):
		crew_bonus=stat_cache.crew_equipment
	else:
		crew_bonus=crew.system_effect(self,"equip_bonus")
		if stat_cache_enabled:stat_cache.crew_equipment=crew_bonus
	return N.multiply(N.multiply(N.multiply(value,planet_equipment_multiplier()),crew_bonus),galaxy.multiplier("equipment_value"))

func jewel_critical(entry: Dictionary, effects: Variant = null, include_timed_buffs := true) -> Vector2:
	var row := db.equip(str(entry.key), int(entry.level))
	var rate := enhancement_branches.underlying_critical_rate(self,entry,include_timed_buffs)
	if enhancement_branches.active(self,entry,"critical",3,"B"):rate=enhancement_parameter("critical_b3_guaranteed_rate")
	var damage := enhancement_parameter("base_critical_multiplier") + float(row.get("criDmg",0))
	for effect in (jewel_effects(entry) if effects == null else effects):
		if effect.kind=="critical":damage+=float(effect.p4)*int(effect.level)
	return Vector2(clampf(rate,0,1),maxf(0,damage))

func begin_enhancement_attack(index: int, target: Dictionary, derived := false, track_primary := true) -> Dictionary:
	var context := enhancement_branches.begin_attack(self,index,target,derived,track_primary)
	enhancement_attack_contexts[index]=context
	return context

func finish_enhancement_attack(index: int) -> void:
	if enhancement_attack_contexts.has(index):enhancement_branches.finish_attack(self,enhancement_attack_contexts[index])
	enhancement_attack_contexts.erase(index)

func player_weapon_row(entry: Dictionary) -> Dictionary:
	var weapon := db.equip(str(entry.key),int(entry.level))
	weapon.cd=float(weapon.cd)*enhancement_branches.cooldown_multiplier(self,entry)
	return weapon

func jewel_attack(index: int, multiplier := 1.0) -> Dictionary:
	var entry := slot_entry("weapons",index)
	var context: Dictionary=enhancement_attack_contexts.get(index,{})
	if not context.has("snapshot"):
		var effects := jewel_effects(entry)
		var critical := jewel_critical(entry,effects)
		var raw = N.multiply(jewel_equipment_stat(entry,-1,effects),float(context.get("next_multiplier",1.0)))
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
			if enhancement_branches.active(self,entry,"proficiency",3,"B"):effect.enemy_resistance=enhancement_parameter("proficiency_b3_resistance")
			if effect.kind=="repeat" and enhancement_branches.active(self,entry,"repeat",1,"B"):
				effect.chain=true;effect.chain_targets=int(enhancement_parameter("repeat_b1_targets"))
		var secondary := enhancement_branches.active(self,entry,"repeat",3,"B") and rng.randf()<enhancement_parameter("repeat_b3_probability")
		context.snapshot={"id":main_attack_serial,"damage":raw,"effects":effects,"critical":is_critical,"critical_bonus_applied":critical_bonus_applied,"secondary":secondary,"secondary_used":false,"repeats_queued":false,"repeat_plan":plan_attack_repeats(entry,effects),"weapon":player_weapon_row(entry).duplicate(true)}
		context.snapshot.instance=new_attack_instance(context.snapshot)
		context.instance=context.snapshot.instance
	return attack_from_snapshot(context.snapshot,multiplier,context.get("instance",{}))

func attack_from_snapshot(snapshot: Dictionary, multiplier: float, instance: Dictionary = {}) -> Dictionary:
	# A salvo shares one attack instance; independent repeats retain the root roll
	# but receive a fresh instance. Never deep-copy the shared chain state.
	if instance.is_empty():
		if not snapshot.has("instance"):snapshot.instance=new_attack_instance(snapshot)
		instance=snapshot.instance
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
	var allowed := int(enhancement_parameter("repeat_b2_repeats")) if enhancement_branches.active(self,entry,"repeat",2,"B") else 0
	while not frontier.is_empty():
		var parent: Dictionary=frontier.pop_front()
		if int(parent.depth)>allowed:continue
		var pending: Array=[]
		for effect in effects:
			if effect.kind=="repeat" and rng.randf()<enhancement_branches.repeat_probability(self,entry):
				pending.append(1.0+float(effect.p4)*int(effect.level))
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
	if str(slot_entry("weapons",index).key)=="missile":
		offset = player_weapon_offset(index)
	var attack := jewel_attack(index,multiplier)
	launch_player_attack(index,target,weapon,attack,offset,visual_spread,salvo_index,salvo_count)

func launch_player_attack(index: int, target: Dictionary, weapon: Dictionary, attack: Dictionary, offset: Vector2, visual_spread: float, _salvo_index: int = 0, _salvo_count: int = 1) -> void:
	fire(player,target,weapon,attack.damage,false,str(slot_entry("weapons",index).key),offset,visual_spread)
	projectiles.back().main_attack_id = attack.get("main_attack_id",0)
	projectiles.back().attack_instance_id = attack.get("attack_instance_id",0)
	projectiles.back().jewelEffects = attack.effects
	projectiles.back().critical = attack.critical
	projectiles.back().critical_bonus_applied=attack.get("critical_bonus_applied",attack.critical)

func launch_enhancement_secondary(index: int, primary: Dictionary, weapon: Dictionary, multiplier: float, beam_tick := false) -> void:
	var entry := slot_entry("weapons",index)
	var context: Dictionary=enhancement_attack_contexts.get(index,{})
	if context.is_empty() or context.get("derived",false) or not context.has("snapshot"):return
	var snapshot: Dictionary=context.snapshot
	if not snapshot.secondary or snapshot.secondary_used:return
	snapshot.secondary_used=true
	var candidates: Array=targets(int(weapon.dmgtype)).filter(func(enemy):return not is_same(enemy,primary))
	if candidates.is_empty():return
	var target: Dictionary=candidates[0]
	context.derived=true
	if beam_tick:
		var attack := jewel_attack(index,multiplier)
		hit_enemy(target,attack.damage,int(weapon.dmgtype),attack.effects,attack.critical)
	else:
		var count := int(weapon.para1) if str(entry.key)=="missile" else 1
		for i in count:jewel_fire(index,target,weapon,player_weapon_offset(index),multiplier,missile_visual_spread(i,count) if str(entry.key)=="missile" else 0.0,i,count)
	context.derived=false
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

func bind_beam_chain(shot: Dictionary) -> void:
	var chain:Dictionary=shot.attack_instance.chain
	chain.beam=true;chain.used=true;chain.primary=shot.target
	for target in select_chain_targets(shot.target,int(shot.weapon.dmgtype),int(chain.count)):
		chain.links.append({"target":target,"broken":false})

func prune_beam_chain(shot: Dictionary) -> void:
	for link in shot.get("attack_instance",{}).get("chain",{}).get("links",[]):
		if not link.broken and not chain_target_alive(link.target):link.broken=true

func end_beam_chain(shot: Dictionary) -> void:
	var chain:Dictionary=shot.get("attack_instance",{}).get("chain",{})
	if not chain.is_empty():chain.ended=true;chain.links.clear()

func break_beam_chain_target(target: Dictionary) -> void:
	for shot in projectiles:
		if not shot.get("beam",false):continue
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
	var continued:Array=[]
	for source in effects:
		var effect:Dictionary=source.duplicate()
		effect.erase("chain_state")
		effect.chain=false;effect.chain_used=true;continued.append(effect)
	return continued

func launch_enhancement_chain(enemy: Dictionary, raw, type: int, effects: Array, critical: bool, origin := Vector2.INF) -> void:
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
			if not link.broken:hit_enemy(link.target,raw,type,continued,critical)
		return
	if chain.used:return
	chain.used=true;effect.chain_used=true
	var continued:=chain_damage_effects(effects)
	if origin==Vector2.INF:origin=chain_target_point(enemy)
	for target in select_chain_targets(enemy,type,int(chain.count)):
		projectile_serial+=1
		var direction:Vector2=(chain_target_point(target)-origin).normalized()
		if direction.is_zero_approx():direction=Vector2.UP
		# A visible damage carrier starts at the hit, never at a weapon mount.
		var hop:Dictionary={"x":origin.x,"y":origin.y,"target":target,"damage":raw,"type":type,"speed":db.weapon_motion_value("chain_carrier_speed",720.0),"hostile":false,"key":"chain","dead":false,"serial":projectile_serial,"direction":direction,"chain_hop":true,"attack_instance_id":chain.instance_id,"main_attack_id":effect.get("main_attack_id",0),"jewelEffects":continued,"critical":critical,"chain_weapon":effect.get("weapon_key","")}
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
			hit_enemy(shot.target,shot.damage,int(shot.type),shot.jewelEffects,bool(shot.critical))
			return
		shot.direction=(aim-position).normalized()
	var movement:Vector2=shot.direction*float(shot.speed)*dt
	shot.x+=movement.x;shot.y+=movement.y
	if shot.x < -32 or shot.x > BATTLE_SIZE.x+32 or shot.y < -32 or shot.y > BATTLE_SIZE.y+32:shot.dead=true

func queue_jewel_repeats(index: int, multiplier: float, beam: Dictionary = {}) -> void:
	var context: Dictionary=enhancement_attack_contexts.get(index,{})
	if not context.has("snapshot"):return
	var snapshot: Dictionary=context.snapshot
	if snapshot.repeats_queued:return
	snapshot.repeats_queued=true
	var entry := slot_entry("weapons",index)
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
		var entry := slot_entry("weapons", int(pending.index))
		if state != State.COMBAT or not is_same(entry, pending.entry) or str(entry.key).is_empty():
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
	if str(slot_entry("weapons",index).get("key","")) != "longLaser":
		cooldowns[id] = 0.0
	jewel_charged[id] = maxf(float(jewel_charged.get(id,1.0)),multiplier)

func memory_effect(entry: Dictionary) -> Dictionary:
	var index := _enhancement_effect_index(entry,"memory_material")
	return _enhancement_effect("memory_material",index,enhancement_effective_level()) if index>=0 else {}

func sync_enhancement_buffers() -> void:
	for index in enhancement_buffers.keys():
		var entry := slot_entry("defence",int(index))
		var owner: Dictionary=enhancement_buffer_owners.get(index,{})
		# Cached capacity already owns the memory payload. This validation only
		# needs membership; retain the full payload for the uncached calculation.
		var effect := {} if stat_cache_enabled else memory_effect(entry)
		var has_memory := _enhancement_effect_index(entry,"memory_material")>=0 if stat_cache_enabled else not effect.is_empty()
		if entry.is_empty() or not has_memory or not is_same(owner.get("entry",{}),entry) or owner.get("key","")!=str(entry.key):
			enhancement_buffers.erase(index)
			enhancement_buffer_owners.erase(index)
		else:
			var capacity = enhancement_module_protection_capacity(int(index)) if stat_cache_enabled else N.multiply(jewel_equipment_stat(entry),float(effect.p4)*int(effect.level)*enhancement_branches.memory_cap_multiplier(self,entry))
			enhancement_buffers[index]=N.minimum(enhancement_buffers[index],capacity)

func memory_buffer(index: int) -> Variant:
	sync_enhancement_buffers()
	return enhancement_buffers.get(index,0.0)

func enhancement_visible_buffer(index: int, capacity: Variant = null) -> Variant:
	var entry := slot_entry("defence",index)
	var owner: Dictionary=enhancement_buffer_owners.get(index,{})
	if entry.is_empty() or memory_effect(entry).is_empty() or not is_same(owner.get("entry",{}),entry) or owner.get("key","")!=str(entry.key):return 0.0
	return N.minimum(enhancement_buffers.get(index,0),enhancement_module_protection_capacity(index) if capacity == null else capacity)

func enhancement_protection_current() -> Variant:
	var total = 0.0
	for index in defense_entries().size():total=N.add(total,enhancement_visible_buffer(index))
	return total

func enhancement_module_protection_capacity(index: int) -> Variant:
	var entry := slot_entry("defence",index)
	if not stat_cache_enabled:
		var effect := memory_effect(entry)
		return N.multiply(jewel_equipment_stat(entry),float(effect.p4)*int(effect.level)*enhancement_branches.memory_cap_multiplier(self,entry)) if not effect.is_empty() else 0.0
	var key := str(entry.get("key",""))
	if key not in DEFENSE_KEYS:return 0.0
	return _jewel_defence_capacity(key).protection_caps.get(index,0.0)

func enhancement_protection_capacity() -> Variant:
	var total = 0.0
	for entry in defense_entries():
		var effect := memory_effect(entry)
		if not effect.is_empty():total=N.add(total,N.multiply(jewel_equipment_stat(entry),float(effect.p4)*int(effect.level)*enhancement_branches.memory_cap_multiplier(self,entry)))
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
			var row := db.equip(key,int(entry.level))
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
	if N.compare(player.armour,0)<=0:
		event.emit("explode",{"x":player.x,"y":player.y,"boss":true})
		begin_retreat()

func enhancement_deferred_fraction(level := -1) -> float:
	if not enhancement_unlocked():return 0.0
	var current := enhancement_effective_level() if level<0 else level
	if current<=0:return 0.0
	var scale := enhancement_parameter("deferred_percent_scale")
	# Computing the complement with ceil avoids rounding high finite levels to 100%.
	var remaining := maxf(1.0,ceilf(scale/(1.0+enhancement_parameter("deferred_curve_coefficient")*current)))
	return maxf(0.0,(scale-remaining)/scale)

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
	if N.compare(player.armour,0)<=0:
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

func advance_jewel_repair(dt: float) -> bool:
	if paused or dt<=0:return true
	var rest := dt
	while rest>0.000000001:
		var memory_interval := enhancement_parameter("memory_interval")
		var deferred_interval := enhancement_parameter("deferred_interval")
		var step := minf(rest,minf(memory_interval-enhancement_memory_elapsed,deferred_interval-enhancement_deferred_elapsed))
		enhancement_branches.advance_defense(self,step)
		enhancement_defense_time+=step
		enhancement_memory_elapsed+=step
		enhancement_deferred_elapsed+=step
		rest=maxf(0.0,rest-step)
		if enhancement_deferred_elapsed+0.000000001>=deferred_interval:
			enhancement_deferred_elapsed=maxf(0.0,enhancement_deferred_elapsed-deferred_interval)
			advance_enhancement_deferred_tick()
			if state==State.RETREAT:return true
		var memory_ticks := 0
		if enhancement_memory_elapsed+0.000000001>=memory_interval:
			enhancement_memory_elapsed=maxf(0.0,enhancement_memory_elapsed-memory_interval)
			memory_ticks=1
		advance_enhancement_repair_step(step,memory_ticks)
	return true

func advance_enhancement_repair_step(dt: float, ticks: int) -> void:
	var capacities := sync_jewel_defence_damage()
	sync_enhancement_buffers()
	var positive_memory_recovery := false
	for key in ["shield","armour"]:
		for index in capacities[key].indices:
			var entry := slot_entry("defence",index)
			var maximum = capacities[key].maxima[index]
			var elapsed := float(jewel_defence_times.get(index,since_hit-dt))+dt
			jewel_defence_times[index]=elapsed
			if key=="shield":
				var row := db.equip(key,int(entry.level))
				if elapsed>=float(row.para3):
					var recovered = N.minimum(jewel_defence_damage.get(index,0),N.multiply(maximum,float(row.para2)*dt))
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
	# Memory capacity depends on the same equipment, counters, crew, planet and
	# branch selections as the existing defence cache, not live buffers/timers.
	var capacity: Dictionary = jewel_defence_capacity_cache.get(key, {}) if stat_cache_enabled else {}
	if capacity.is_empty():
		var indices: Array = []
		var maxima = {}
		var effects_by_index = {}
		var protection_caps = {}
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
			var protection = 0.0
			if stat_cache_enabled:
				for effect in effects:
					if effect.kind=="memory_material":
						protection=N.multiply(maximum,float(effect.p4)*int(effect.level)*enhancement_branches.memory_cap_multiplier(self,entry))
						break
			protection_caps[index]=protection
			total = N.add(total,maximum)
		capacity = {"indices":indices,"maxima":maxima,"effects":effects_by_index,"total":total,"protection_caps":protection_caps}
		if stat_cache_enabled:
			jewel_defence_capacity_cache[key] = capacity
	return capacity

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

func refresh_crew_level_effects(previous: Dictionary, current: Dictionary) -> void:
	if not crew.levels_unlocked(self):return
	if previous.get("level")==current.get("level") and previous.get("assignmentType")==current.get("assignmentType") and previous.get("targetId")==current.get("targetId"):return
	var kinds := {}
	for member in [previous,current]:
		var job: Dictionary=crew.assignments(self).get(str(member.get("assignmentType","")),{})
		kinds[str(job.get("targetType",""))]=true
	if kinds.has("equipment"):
		invalidate_stat_cache()
		apply_refit_health()
		for category in ["weapons","defence"]:event.emit("equipment_stats",{"category":category})
	if kinds.has("hightech"):event.emit("scientists_changed",{})
	if kinds.has("reactor"):
		var remaining := reactor_capacity()
		for key in reactor_modules():
			profile.reactorAllocation[key]=mini(int(profile.reactorAllocation.get(key,0)),remaining)
			remaining-=int(profile.reactorAllocation[key])
		invalidate_stat_cache()
		apply_refit_health()
		event.emit("reactor_changed",{})
		for category in ["weapons","defence"]:event.emit("equipment_stats",{"category":category})
